program test_freepascal_resumed_session_hostname_binding;

{**
 * Regression test for CVE-style hostname verification bypass via session
 * resumption. Verifies that a resumed TLS 1.3 session rejects connections
 * when the target server name differs from the name bound at session creation.
 *}

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.serverhello,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.crypto.x25519,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.appschedule,
  nextpas.core.tls.crypto.hash,
  nextpas.core.tls.freepascal.session;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Pass(const AMessage: string);
begin
  WriteLn('[PASS] ', AMessage);
  Inc(GPassCount);
end;

procedure Fail(const AMessage: string);
begin
  WriteLn('[FAIL] ', AMessage);
  Inc(GFailCount);
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Pass(AMessage)
  else
    Fail(AMessage);
end;

type
  TOfflineHandshakeMode = (ohmInitial, ohmResumed);

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);
  Result := True;
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

procedure AppendVector16(var ADest: TBytes; const AValue: TBytes);
begin
  AppendUInt16(ADest, Word(Length(AValue)));
  AppendBytes(ADest, AValue);
end;

function HashTranscriptForSuite(ACipherSuite: Word; const ATranscriptData: TBytes): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(SHA256(ATranscriptData));
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(SHA384(ATranscriptData));
  SetLength(Result, 0);
end;

function BuildEncryptedExtensionsMessage: TBytes;
var
  LBody: TBytes;
begin
  SetLength(LBody, 0);
  AppendUInt16(LBody, 0);
  SetLength(Result, 0);
  AppendByte(Result, TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildFinishedMessage(
  ACipherSuite: Word;
  const AServerHandshakeTrafficSecret: TBytes;
  const ATranscriptData: TBytes
): TBytes;
var
  LVerifyData: TBytes;
begin
  LVerifyData := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    ACipherSuite,
    AServerHandshakeTrafficSecret,
    HashTranscriptForSuite(ACipherSuite, ATranscriptData)
  );
  SetLength(Result, 0);
  AppendByte(Result, TLS_HANDSHAKE_TYPE_FINISHED);
  AppendUInt24(Result, Length(LVerifyData));
  AppendBytes(Result, LVerifyData);
end;

function BuildNewSessionTicketMessage(
  ATicketLifetime: Cardinal;
  ATicketAgeAdd: Cardinal;
  const ATicketNonce: TBytes;
  const ATicket: TBytes;
  AMaxEarlyDataSize: Cardinal = 0
): TBytes;
var
  LBody: TBytes;
  LExtensions: TBytes;
begin
  SetLength(LBody, 0);
  AppendByte(LBody, Byte((ATicketLifetime shr 24) and $FF));
  AppendByte(LBody, Byte((ATicketLifetime shr 16) and $FF));
  AppendByte(LBody, Byte((ATicketLifetime shr 8) and $FF));
  AppendByte(LBody, Byte(ATicketLifetime and $FF));
  AppendByte(LBody, Byte((ATicketAgeAdd shr 24) and $FF));
  AppendByte(LBody, Byte((ATicketAgeAdd shr 16) and $FF));
  AppendByte(LBody, Byte((ATicketAgeAdd shr 8) and $FF));
  AppendByte(LBody, Byte(ATicketAgeAdd and $FF));
  AppendByte(LBody, Byte(Length(ATicketNonce)));
  AppendBytes(LBody, ATicketNonce);
  AppendVector16(LBody, ATicket);
  SetLength(LExtensions, 0);
  if AMaxEarlyDataSize > 0 then
  begin
    AppendUInt16(LExtensions, TLS_EXTENSION_EARLY_DATA);
    AppendUInt16(LExtensions, 4);
    AppendByte(LExtensions, Byte((AMaxEarlyDataSize shr 24) and $FF));
    AppendByte(LExtensions, Byte((AMaxEarlyDataSize shr 16) and $FF));
    AppendByte(LExtensions, Byte((AMaxEarlyDataSize shr 8) and $FF));
    AppendByte(LExtensions, Byte(AMaxEarlyDataSize and $FF));
  end;
  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);
  SetLength(Result, 0);
  AppendByte(Result, TLS_HANDSHAKE_TYPE_NEW_SESSION_TICKET);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildServerHelloWithSelectedPSK(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  ASelectedIdentity: Word
): TBytes;
var
  LBody: TBytes;
  LExtensions: TBytes;
  LExt: TBytes;
  LRandom: TBytes;
begin
  SetLength(LRandom, 32);
  FillChar(LRandom[0], Length(LRandom), $66);
  SetLength(LExtensions, 0);

  SetLength(LExt, 0);
  AppendUInt16(LExt, TLS_EXTENSION_SUPPORTED_VERSIONS);
  AppendUInt16(LExt, 2);
  AppendUInt16(LExt, TLS13_VERSION);
  AppendBytes(LExtensions, LExt);

  SetLength(LExt, 0);
  AppendUInt16(LExt, TLS_EXTENSION_KEY_SHARE);
  AppendUInt16(LExt, Word(4 + Length(AServerKeyShare)));
  AppendUInt16(LExt, TLS13_GROUP_X25519);
  AppendUInt16(LExt, Word(Length(AServerKeyShare)));
  AppendBytes(LExt, AServerKeyShare);
  AppendBytes(LExtensions, LExt);

  SetLength(LExt, 0);
  AppendUInt16(LExt, TLS_EXTENSION_PRE_SHARED_KEY);
  AppendUInt16(LExt, 2);
  AppendUInt16(LExt, ASelectedIdentity);
  AppendBytes(LExtensions, LExt);

  SetLength(LBody, 0);
  AppendUInt16(LBody, TLS_LEGACY_VERSION);
  AppendBytes(LBody, LRandom);
  AppendByte(LBody, Byte(Length(ALegacySessionID)));
  AppendBytes(LBody, ALegacySessionID);
  AppendUInt16(LBody, ACipherSuite);
  AppendByte(LBody, 0);
  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  SetLength(Result, 0);
  AppendByte(Result, TLS_HANDSHAKE_TYPE_SERVER_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

type
  TOfflineTLS13ServerStream = class(TStream)
  private
    FMode: TOfflineHandshakeMode;
    FCipherSuite: Word;
    FReadBuffer: TBytes;
    FReadPosition: Int64;
    FWriteStage: Integer;
    FTranscriptData: TBytes;
    FServerPrivateKey: TBytes;
    FServerPublicKey: TBytes;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FApplicationSecrets: TTLS13ApplicationSecrets;
    FPendingSession: IFreePascalResumptionSession;

    procedure Enqueue(const AData: TBytes);
    procedure HandleClientHello(const AData: TBytes);
    procedure HandleClientFinished(const AData: TBytes);
  public
    constructor CreateInitial(ACipherSuite: Word);
    constructor CreateResumed(const ASession: ISSLSession);

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TOfflineTLS13ServerStream.CreateInitial(ACipherSuite: Word);
begin
  inherited Create;
  FMode := ohmInitial;
  FCipherSuite := ACipherSuite;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  FWriteStage := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  InitTLS13ApplicationSecrets(FApplicationSecrets);
  FPendingSession := nil;
end;

constructor TOfflineTLS13ServerStream.CreateResumed(const ASession: ISSLSession);
begin
  CreateInitial(TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  FMode := ohmResumed;
  FPendingSession := ASession as IFreePascalResumptionSession;
end;

procedure TOfflineTLS13ServerStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then Exit;
  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TOfflineTLS13ServerStream.HandleClientHello(const AData: TBytes);
var
  LHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LServerHello: TBytes;
  LServerHelloRecord: TBytes;
  LEncryptedExtensions: TBytes;
  LServerFinished: TBytes;
  LFlight: TBytes;
  LInnerPlaintext: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LSharedSecret: TBytes;
  LKeyShareError: string;
begin
  if not TryExtractHandshakePayloadFromRecord(AData, LHandshake) then
    raise Exception.Create('Failed to extract ClientHello from record');
  if not TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LKeyShareError) then
    raise Exception.Create('Failed to parse ClientHello: ' + LKeyShareError);
  if not LInfo.HasKeyShare then
    raise Exception.Create('ClientHello missing key_share');

  if FMode = ohmResumed then
  begin
    if not LInfo.HasPreSharedKey then
      raise Exception.Create('Resumed ClientHello missing pre_shared_key');
    if not BytesEqual(LInfo.FirstPSKIdentity, FPendingSession.GetTicket) then
      raise Exception.Create('Resumed ClientHello PSK identity mismatch');
  end;

  GenerateX25519KeyPair(FServerPrivateKey, FServerPublicKey);
  LSharedSecret := X25519ComputeSharedSecret(FServerPrivateKey, LInfo.PeerKeyShare);

  if FMode = ohmResumed then
    LServerHello := BuildServerHelloWithSelectedPSK(
      LInfo.LegacySessionID, FCipherSuite, FServerPublicKey, 0)
  else
    LServerHello := BuildTLS13ServerHelloHandshake(
      LInfo.LegacySessionID, FCipherSuite, FServerPublicKey);
  LServerHelloRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LServerHello);
  Enqueue(LServerHelloRecord);

  SetLength(FTranscriptData, Length(LHandshake) + Length(LServerHello));
  Move(LHandshake[0], FTranscriptData[0], Length(LHandshake));
  Move(LServerHello[0], FTranscriptData[Length(LHandshake)], Length(LServerHello));

  if FMode = ohmResumed then
  begin
    if not TryDeriveTLS13HandshakeSecretsWithPSK(
      FCipherSuite, LSharedSecret, FTranscriptData,
      FPendingSession.GetResumptionPSK, FHandshakeSecrets, LKeyShareError
    ) then
      raise Exception.Create('Failed to derive resumed handshake secrets: ' + LKeyShareError);
  end
  else
  begin
    if not TryDeriveTLS13HandshakeSecrets(
      FCipherSuite, LSharedSecret, FTranscriptData, FHandshakeSecrets, LKeyShareError
    ) then
      raise Exception.Create('Failed to derive handshake secrets: ' + LKeyShareError);
  end;

  LEncryptedExtensions := BuildEncryptedExtensionsMessage;
  AppendBytes(FTranscriptData, LEncryptedExtensions);

  LServerFinished := BuildFinishedMessage(
    FCipherSuite, FHandshakeSecrets.ServerHandshakeTrafficSecret, FTranscriptData);

  SetLength(LFlight, 0);
  AppendBytes(LFlight, LEncryptedExtensions);
  AppendBytes(LFlight, LServerFinished);
  LInnerPlaintext := BuildTLS13InnerPlaintext(LFlight, TLS_CONTENT_TYPE_HANDSHAKE);

  if not TryTLS13AEADEncrypt(
    FCipherSuite, FHandshakeSecrets.ServerHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ServerHandshakeIV, 0),
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FCipherSuite))),
    LInnerPlaintext, LEncrypted, LKeyShareError
  ) then
    raise Exception.Create('Failed to encrypt server handshake flight: ' + LKeyShareError);

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  Enqueue(LRecord);
  AppendBytes(FTranscriptData, LServerFinished);
  FWriteStage := 1;
end;

procedure TOfflineTLS13ServerStream.HandleClientFinished(const AData: TBytes);
var
  LHeader: TTLSRecordHeader;
  LPayload: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LError: string;
  LVerifyData: TBytes;
  LFinishedMessage: TBytes;
  LTicketMessage: TBytes;
  LAppPlaintext: TBytes;
  LAppEncrypted: TBytes;
  LAppRecord: TBytes;
begin
  if not ParseTLSRecordHeader(AData, LHeader) then
    raise Exception.Create('Failed to parse client Finished record');
  if Length(AData) < 5 + LHeader.Length then
    raise Exception.Create('Client Finished record payload is truncated');
  SetLength(LPayload, LHeader.Length);
  if LHeader.Length > 0 then
    Move(AData[5], LPayload[0], LHeader.Length);

  if not TryTLS13AEADDecrypt(
    FCipherSuite, FHandshakeSecrets.ClientHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, 0),
    BuildTLS13RecordAAD(LHeader.Length),
    LPayload, LPlaintext, LError
  ) then
    raise Exception.Create('Failed to decrypt client Finished: ' + LError);

  if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
    raise Exception.Create('Invalid TLSInnerPlaintext for client Finished');
  if LInnerContentType <> TLS_CONTENT_TYPE_HANDSHAKE then
    raise Exception.Create('Client Finished record carried wrong inner content type');
  if (Length(LInnerFragment) < 4) or (LInnerFragment[0] <> TLS_HANDSHAKE_TYPE_FINISHED) then
    raise Exception.Create('Client Finished handshake missing');

  SetLength(LVerifyData, Length(LInnerFragment) - 4);
  if Length(LVerifyData) > 0 then
    Move(LInnerFragment[4], LVerifyData[0], Length(LVerifyData));
  if not TLS13VerifyFinishedForCipherSuite(
    FCipherSuite, FHandshakeSecrets.ClientHandshakeTrafficSecret,
    HashTranscriptForSuite(FCipherSuite, FTranscriptData), LVerifyData
  ) then
    raise Exception.Create('Client Finished verification failed');
  LFinishedMessage := LInnerFragment;

  { Derive application secrets BEFORE appending Client Finished to transcript
    because RFC 8446 requires Transcript-Hash(CH..SF) only. }
  if not TryDeriveTLS13ApplicationSecrets(
    FCipherSuite, FHandshakeSecrets.HandshakeSecret,
    FTranscriptData, FApplicationSecrets, LError
  ) then
    raise Exception.Create('Failed to derive application secrets: ' + LError);

  AppendBytes(FTranscriptData, LFinishedMessage);

  if FMode = ohmInitial then
  begin
    LTicketMessage := BuildNewSessionTicketMessage(
      7200, $11223344, [$01, $02, $03], [$AA, $BB, $CC, $DD, $EE, $FF], 16384);
    LAppPlaintext := BuildTLS13InnerPlaintext(LTicketMessage, TLS_CONTENT_TYPE_HANDSHAKE);
    if not TryTLS13AEADEncrypt(
      FCipherSuite, FApplicationSecrets.ServerApplicationKey,
      BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, 0),
      BuildTLS13RecordAAD(Word(Length(LAppPlaintext) + TLS13AEADTagLength(FCipherSuite))),
      LAppPlaintext, LAppEncrypted, LError
    ) then
      raise Exception.Create('Failed to encrypt NewSessionTicket: ' + LError);
    LAppRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LAppEncrypted);
    Enqueue(LAppRecord);

    LAppPlaintext := BuildTLS13InnerPlaintext([$50, $4F, $4E, $47], TLS_CONTENT_TYPE_APPLICATION_DATA);
    if not TryTLS13AEADEncrypt(
      FCipherSuite, FApplicationSecrets.ServerApplicationKey,
      BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, 1),
      BuildTLS13RecordAAD(Word(Length(LAppPlaintext) + TLS13AEADTagLength(FCipherSuite))),
      LAppPlaintext, LAppEncrypted, LError
    ) then
      raise Exception.Create('Failed to encrypt app data: ' + LError);
    LAppRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LAppEncrypted);
    Enqueue(LAppRecord);
  end;

  FWriteStage := 2;
end;

function TOfflineTLS13ServerStream.Read(var Buffer; Count: Longint): Longint;
var
  LAvailable: Int64;
begin
  if Count <= 0 then Exit(0);
  LAvailable := Length(FReadBuffer) - FReadPosition;
  if LAvailable <= 0 then Exit(0);
  if Count > LAvailable then
    Result := Longint(LAvailable)
  else
    Result := Count;
  Move(FReadBuffer[Integer(FReadPosition)], Buffer, Result);
  Inc(FReadPosition, Result);
end;

function TOfflineTLS13ServerStream.Write(const Buffer; Count: Longint): Longint;
var
  LData: TBytes;
begin
  SetLength(LData, Count);
  if Count > 0 then
    Move(Buffer, LData[0], Count);
  case FWriteStage of
    0: HandleClientHello(LData);
    1: HandleClientFinished(LData);
  end;
  Result := Count;
end;

function TOfflineTLS13ServerStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FReadPosition := Offset;
    soCurrent: Inc(FReadPosition, Offset);
    soEnd: FReadPosition := Length(FReadBuffer) + Offset;
  end;
  Result := FReadPosition;
end;

{ Helper: establish initial session with a given server name }
function EstablishSession(const AServerName: string): ISSLSession;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LResumption: ISSLSessionResumption;
  LStream: TOfflineTLS13ServerStream;
  LBuf: array[0..15] of Byte;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LCtx.SetVerifyMode([]);

  LStream := TOfflineTLS13ServerStream.CreateInitial(TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  try
    LConn := LCtx.CreateConnection(LStream);
    (LConn as ISSLClientConnection).SetServerName(AServerName);
    if not LConn.Connect then
      raise Exception.Create('Initial handshake failed for ' + AServerName);
    LConn.Read(LBuf, SizeOf(LBuf));
    if not Supports(LConn, ISSLSessionResumption, LResumption) then
      raise Exception.Create('Connection does not support ISSLSessionResumption');
    Result := LResumption.GetSession;
    if Result = nil then
      raise Exception.Create('No session captured for ' + AServerName);
  finally
    LStream.Free;
  end;
end;

{ Test 1: Resumed session with same hostname should succeed }
procedure TestResumedSessionSameHostnameSucceeds;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LResumption: ISSLSessionResumption;
  LStream: TOfflineTLS13ServerStream;
  LSession: ISSLSession;
begin
  WriteLn('=== Test 1: Resumed session with same hostname succeeds ===');

  LSession := EstablishSession('example.com');

  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LCtx.SetVerifyMode([sslVerifyPeer]);

  LStream := TOfflineTLS13ServerStream.CreateResumed(LSession);
  try
    LConn := LCtx.CreateConnection(LStream);
    Supports(LConn, ISSLSessionResumption, LResumption);
    LResumption.SetSession(LSession);
    (LConn as ISSLClientConnection).SetServerName('example.com');

    Check(LConn.Connect,
      'Resumed session with same hostname should succeed');
    Check(LResumption.IsSessionReused,
      'Session should be reported as reused');
  finally
    LStream.Free;
  end;
end;

{ Test 2: Resumed session with different hostname should FAIL }
procedure TestResumedSessionDifferentHostnameFails;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LResumption: ISSLSessionResumption;
  LStream: TOfflineTLS13ServerStream;
  LSession: ISSLSession;
begin
  WriteLn('=== Test 2: Resumed session with different hostname fails ===');

  LSession := EstablishSession('legit.example.com');

  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LCtx.SetVerifyMode([sslVerifyPeer]);

  LStream := TOfflineTLS13ServerStream.CreateResumed(LSession);
  try
    LConn := LCtx.CreateConnection(LStream);
    Supports(LConn, ISSLSessionResumption, LResumption);
    LResumption.SetSession(LSession);
    { Attack scenario: use ticket from legit.example.com to connect to evil.example.com }
    (LConn as ISSLClientConnection).SetServerName('evil.example.com');

    Check(not LConn.Connect,
      'Resumed session with different hostname MUST fail (hostname binding check)');
  finally
    LStream.Free;
  end;
end;

{ Test 3: Resumed session with hostname verification disabled should succeed }
procedure TestResumedSessionHostnameIgnoredSucceeds;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LResumption: ISSLSessionResumption;
  LStream: TOfflineTLS13ServerStream;
  LSession: ISSLSession;
begin
  WriteLn('=== Test 3: Resumed session with hostname verification disabled succeeds ===');

  LSession := EstablishSession('server-a.example.com');

  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LCtx.SetVerifyMode([sslVerifyPeer]);
  LCtx.SetCertVerifyFlags(LCtx.GetCertVerifyFlags + [sslCertVerifyIgnoreHostname]);

  LStream := TOfflineTLS13ServerStream.CreateResumed(LSession);
  try
    LConn := LCtx.CreateConnection(LStream);
    Supports(LConn, ISSLSessionResumption, LResumption);
    LResumption.SetSession(LSession);
    (LConn as ISSLClientConnection).SetServerName('server-b.example.com');

    Check(LConn.Connect,
      'Resumed session with sslCertVerifyIgnoreHostname should succeed even with different hostname');
  finally
    LStream.Free;
  end;
end;

{ Test 4: Resumed session with case-insensitive same hostname should succeed }
procedure TestResumedSessionCaseInsensitiveHostnameSucceeds;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LResumption: ISSLSessionResumption;
  LStream: TOfflineTLS13ServerStream;
  LSession: ISSLSession;
begin
  WriteLn('=== Test 4: Resumed session with case-insensitive same hostname succeeds ===');

  LSession := EstablishSession('Example.COM');

  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LCtx.SetVerifyMode([sslVerifyPeer]);

  LStream := TOfflineTLS13ServerStream.CreateResumed(LSession);
  try
    LConn := LCtx.CreateConnection(LStream);
    Supports(LConn, ISSLSessionResumption, LResumption);
    LResumption.SetSession(LSession);
    (LConn as ISSLClientConnection).SetServerName('example.com');

    Check(LConn.Connect,
      'Resumed session with case-different but same hostname should succeed');
  finally
    LStream.Free;
  end;
end;

begin
  WriteLn('Testing FreePascal resumed session hostname binding (security regression)...');
  WriteLn;

  TestResumedSessionSameHostnameSucceeds;
  WriteLn;
  TestResumedSessionDifferentHostnameFails;
  WriteLn;
  TestResumedSessionHostnameIgnoredSucceeds;
  WriteLn;
  TestResumedSessionCaseInsensitiveHostnameSucceeds;
  WriteLn;

  WriteLn;
  WriteLn(Format('--- Results: %d passed, %d failed ---', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1)
  else
    WriteLn('All hostname binding security checks passed.');
end.
