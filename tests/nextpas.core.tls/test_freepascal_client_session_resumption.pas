program test_freepascal_client_session_resumption;

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

type
  TOfflineHandshakeMode = (ohmInitial, ohmResumed);

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertEqualsInt(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

procedure AssertConnectionInfo(
  const ALabel: string;
  const AInfo: TSSLConnectionInfo;
  ACipherSuite: Word;
  AExpectedKeySize: Integer;
  AExpectedResumed: Boolean;
  const AExpectedSessionId: string
);
begin
  AssertTrue(AInfo.ProtocolVersion = sslProtocolTLS13,
    ALabel + ' connection info should report TLS 1.3');
  AssertEqualsInt(ACipherSuite, AInfo.CipherSuiteId,
    ALabel + ' connection info should derive the negotiated cipher-suite id');
  AssertTrue(AInfo.KeySize = AExpectedKeySize,
    ALabel + ' connection info should derive the negotiated key size');
  AssertTrue(AInfo.MacSize = 16,
    ALabel + ' connection info should derive the AEAD tag length');
  AssertTrue(AInfo.ServerName = 'example.com',
    ALabel + ' connection info should mirror the configured server name');
  AssertTrue(AInfo.IsResumed = AExpectedResumed,
    ALabel + ' connection info should mirror the session reuse state');
  AssertTrue(AInfo.SessionId = AExpectedSessionId,
    ALabel + ' connection info should mirror the active session identifier');
end;

function CaptureConnectionInfo(const ALabel: string; AConn: ISSLConnection): TSSLConnectionInfo;
var
  LConnInfoAccess: ISSLConnectionInfo;
begin
  AssertTrue(Supports(AConn, ISSLConnectionInfo, LConnInfoAccess),
    ALabel + ' connection should expose ISSLConnectionInfo');
  Result := LConnInfoAccess.GetConnectionInfo;
end;

function CaptureSelectedALPN(const ALabel: string; AConn: ISSLConnection): string;
var
  LConnInfoAccess: ISSLConnectionInfo;
begin
  AssertTrue(Supports(AConn, ISSLConnectionInfo, LConnInfoAccess),
    ALabel + ' connection should expose ISSLConnectionInfo');
  Result := LConnInfoAccess.GetSelectedALPNProtocol;
end;

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
  Result := nil;
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

  Result := nil;
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

  Result := nil;
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

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_SERVER_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

type
  TOfflineTLS13ServerStream = class(TStream)
  private
    FMode: TOfflineHandshakeMode;
    FCipherSuite: Word;
    FSelectedALPNProtocol: string;
    FReadBuffer: TBytes;
    FReadPosition: Int64;
    FWriteStage: Integer;
    FTranscriptData: TBytes;
    FServerPrivateKey: TBytes;
    FServerPublicKey: TBytes;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FApplicationSecrets: TTLS13ApplicationSecrets;
    FPendingSession: IFreePascalResumptionSession;
    FObservedPskClientHello: Boolean;
    FObservedTicketIdentityMatch: Boolean;

    procedure Enqueue(const AData: TBytes);
    procedure HandleClientHello(const AData: TBytes);
    procedure HandleClientFinished(const AData: TBytes);
  public
    constructor CreateInitial(ACipherSuite: Word; const ASelectedALPNProtocol: string = '');
    constructor CreateResumed(const ASession: ISSLSession; const ASelectedALPNProtocol: string = '');

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;

    property ObservedPskClientHello: Boolean read FObservedPskClientHello;
    property ObservedTicketIdentityMatch: Boolean read FObservedTicketIdentityMatch;
  end;

function BuildEncryptedExtensionsMessage(const ASelectedALPNProtocol: string = ''): TBytes;
var
  LBody: TBytes;
  LExtensions: TBytes;
  LALPN: TBytes;
  LALPNList: TBytes;
begin
  SetLength(LExtensions, 0);
  if ASelectedALPNProtocol <> '' then
  begin
    SetLength(LALPN, Length(ASelectedALPNProtocol));
    if Length(ASelectedALPNProtocol) > 0 then
      Move(ASelectedALPNProtocol[1], LALPN[0], Length(ASelectedALPNProtocol));

    SetLength(LALPNList, 0);
    AppendByte(LALPNList, Byte(Length(LALPN)));
    AppendBytes(LALPNList, LALPN);

    SetLength(LBody, 0);
    AppendUInt16(LBody, Word(Length(LALPNList)));
    AppendBytes(LBody, LALPNList);
    AppendUInt16(LExtensions, TLS_EXTENSION_ALPN);
    AppendUInt16(LExtensions, Word(Length(LBody)));
    AppendBytes(LExtensions, LBody);
  end;

  SetLength(LBody, 0);
  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

constructor TOfflineTLS13ServerStream.CreateInitial(ACipherSuite: Word; const ASelectedALPNProtocol: string);
begin
  inherited Create;
  FMode := ohmInitial;
  FCipherSuite := ACipherSuite;
  FSelectedALPNProtocol := ASelectedALPNProtocol;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  FWriteStage := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  InitTLS13ApplicationSecrets(FApplicationSecrets);
  FPendingSession := nil;
  FObservedPskClientHello := False;
  FObservedTicketIdentityMatch := False;
end;

constructor TOfflineTLS13ServerStream.CreateResumed(const ASession: ISSLSession; const ASelectedALPNProtocol: string);
begin
  CreateInitial(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, ASelectedALPNProtocol);
  FMode := ohmResumed;
  FPendingSession := ASession as IFreePascalResumptionSession;
end;

procedure TOfflineTLS13ServerStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

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
  if (FSelectedALPNProtocol <> '') and
    (not TLS13ClientHelloOffersALPNProtocol(LInfo, FSelectedALPNProtocol)) then
    raise Exception.Create('ClientHello missing expected ALPN offer');

  if FMode = ohmResumed then
  begin
    FObservedPskClientHello := LInfo.HasPreSharedKey;
    if not FObservedPskClientHello then
      raise Exception.Create('Resumed ClientHello missing pre_shared_key');
    FObservedTicketIdentityMatch := BytesEqual(LInfo.FirstPSKIdentity, FPendingSession.GetTicket);
    if not FObservedTicketIdentityMatch then
      raise Exception.Create('Resumed ClientHello PSK identity mismatch');
  end;

  GenerateX25519KeyPair(FServerPrivateKey, FServerPublicKey);
  LSharedSecret := X25519ComputeSharedSecret(FServerPrivateKey, LInfo.PeerKeyShare);

  if FMode = ohmResumed then
    LServerHello := BuildServerHelloWithSelectedPSK(
      LInfo.LegacySessionID,
      FCipherSuite,
      FServerPublicKey,
      0
    )
  else
    LServerHello := BuildTLS13ServerHelloHandshake(
      LInfo.LegacySessionID,
      FCipherSuite,
      FServerPublicKey
    );
  LServerHelloRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LServerHello);
  Enqueue(LServerHelloRecord);

  SetLength(FTranscriptData, Length(LHandshake) + Length(LServerHello));
  Move(LHandshake[0], FTranscriptData[0], Length(LHandshake));
  Move(LServerHello[0], FTranscriptData[Length(LHandshake)], Length(LServerHello));

  if FMode = ohmResumed then
  begin
    if not TryDeriveTLS13HandshakeSecretsWithPSK(
      FCipherSuite,
      LSharedSecret,
      FTranscriptData,
      FPendingSession.GetResumptionPSK,
      FHandshakeSecrets,
      LKeyShareError
    ) then
      raise Exception.Create('Failed to derive resumed handshake secrets: ' + LKeyShareError);
  end
  else
  begin
    if not TryDeriveTLS13HandshakeSecrets(
      FCipherSuite,
      LSharedSecret,
      FTranscriptData,
      FHandshakeSecrets,
      LKeyShareError
    ) then
      raise Exception.Create('Failed to derive handshake secrets: ' + LKeyShareError);
  end;

  LEncryptedExtensions := BuildEncryptedExtensionsMessage(FSelectedALPNProtocol);
  AppendBytes(FTranscriptData, LEncryptedExtensions);

  LServerFinished := BuildFinishedMessage(
    FCipherSuite,
    FHandshakeSecrets.ServerHandshakeTrafficSecret,
    FTranscriptData
  );

  SetLength(LFlight, 0);
  AppendBytes(LFlight, LEncryptedExtensions);
  AppendBytes(LFlight, LServerFinished);
  LInnerPlaintext := BuildTLS13InnerPlaintext(LFlight, TLS_CONTENT_TYPE_HANDSHAKE);

  if not TryTLS13AEADEncrypt(
    FCipherSuite,
    FHandshakeSecrets.ServerHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ServerHandshakeIV, 0),
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FCipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LKeyShareError
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
  LTicketRecord: TBytes;
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
    FCipherSuite,
    FHandshakeSecrets.ClientHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, 0),
    BuildTLS13RecordAAD(LHeader.Length),
    LPayload,
    LPlaintext,
    LError
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
    FCipherSuite,
    FHandshakeSecrets.ClientHandshakeTrafficSecret,
    HashTranscriptForSuite(FCipherSuite, FTranscriptData),
    LVerifyData
  ) then
    raise Exception.Create('Client Finished verification failed in offline server');
  LFinishedMessage := LInnerFragment;

  { Derive application secrets BEFORE appending Client Finished to transcript
    because RFC 8446 requires Transcript-Hash(CH..SF) only. }
  if not TryDeriveTLS13ApplicationSecrets(
    FCipherSuite,
    FHandshakeSecrets.HandshakeSecret,
    FTranscriptData,
    FApplicationSecrets,
    LError
  ) then
    raise Exception.Create('Failed to derive application secrets: ' + LError);

  AppendBytes(FTranscriptData, LFinishedMessage);

  if FMode = ohmInitial then
  begin
    LTicketMessage := BuildNewSessionTicketMessage(
      7200,
      $11223344,
      [$01, $02, $03],
      [$AA, $BB, $CC, $DD, $EE, $FF],
      16384
    );
    LAppPlaintext := BuildTLS13InnerPlaintext(LTicketMessage, TLS_CONTENT_TYPE_HANDSHAKE);
    if not TryTLS13AEADEncrypt(
      FCipherSuite,
      FApplicationSecrets.ServerApplicationKey,
      BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, 0),
      BuildTLS13RecordAAD(Word(Length(LAppPlaintext) + TLS13AEADTagLength(FCipherSuite))),
      LAppPlaintext,
      LAppEncrypted,
      LError
    ) then
      raise Exception.Create('Failed to encrypt NewSessionTicket record: ' + LError);
    LTicketRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LAppEncrypted);
    Enqueue(LTicketRecord);

    LAppPlaintext := BuildTLS13InnerPlaintext([$50, $4F, $4E, $47], TLS_CONTENT_TYPE_APPLICATION_DATA);
    if not TryTLS13AEADEncrypt(
      FCipherSuite,
      FApplicationSecrets.ServerApplicationKey,
      BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, 1),
      BuildTLS13RecordAAD(Word(Length(LAppPlaintext) + TLS13AEADTagLength(FCipherSuite))),
      LAppPlaintext,
      LAppEncrypted,
      LError
    ) then
      raise Exception.Create('Failed to encrypt application data record: ' + LError);
    LAppRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LAppEncrypted);
    Enqueue(LAppRecord);
  end;

  FWriteStage := 2;
end;

function TOfflineTLS13ServerStream.Read(var Buffer; Count: Longint): Longint;
var
  LAvailable: Int64;
begin
  if Count <= 0 then
    Exit(0);

  LAvailable := Length(FReadBuffer) - FReadPosition;
  if LAvailable <= 0 then
    Exit(0);

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
  LOffset, LRecLen: Integer;
begin
  SetLength(LData, Count);
  if Count > 0 then
    Move(Buffer, LData[0], Count);

  case FWriteStage of
    0: HandleClientHello(LData);
    1:
      begin
        LOffset := 0;
        while LOffset + 5 <= Length(LData) do
        begin
          LRecLen := (Integer(LData[LOffset + 3]) shl 8) or Integer(LData[LOffset + 4]);
          if LData[LOffset] = $17 then
          begin
            HandleClientFinished(Copy(LData, LOffset, 5 + LRecLen));
            Break;
          end;
          Inc(LOffset, 5 + LRecLen);
        end;
      end;
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

procedure TestOfflineSessionCaptureAndResume;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LConn1: ISSLConnection;
  LConn2: ISSLConnection;
  LResumption1: ISSLSessionResumption;
  LResumption2: ISSLSessionResumption;
  LInfo: TSSLConnectionInfo;
  LStream1: TOfflineTLS13ServerStream;
  LStream2: TOfflineTLS13ServerStream;
  LSession: ISSLSession;
  LSessionInfo: IFreePascalResumptionSession;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
  LSerialized: TBytes;
begin
  LCtx1 := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx1 <> nil, 'Initial FreePascal client context should be created');
  LCtx1.SetPreferredVersion(sslProtocolTLS13);
  LCtx1.SetVerifyMode([]);

  LStream1 := TOfflineTLS13ServerStream.CreateInitial(TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  try
    LConn1 := LCtx1.CreateConnection(LStream1);
    AssertTrue(LConn1 <> nil, 'Initial connection should be created');
    (LConn1 as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn1.Connect, 'Initial offline TLS 1.3 handshake should succeed');
    AssertTrue(LConn1.GetProtocolVersion = sslProtocolTLS13,
      'Initial offline handshake should negotiate TLS 1.3');
    AssertTrue(LConn1.GetCipherName = 'TLS_CHACHA20_POLY1305_SHA256',
      'Initial offline handshake should negotiate CHACHA20');
    AssertTrue(Supports(LConn1, ISSLSessionResumption, LResumption1),
      'Initial connection should expose ISSLSessionResumption');
    AssertTrue(not LResumption1.IsSessionReused,
      'Initial handshake must not report session reuse');

    LRead := LConn1.Read(LBuf, SizeOf(LBuf));
    AssertEqualsInt(4, LRead, 'Reading post-handshake app data should return 4 bytes');
    AssertTrue((LBuf[0] = $50) and (LBuf[1] = $4F) and (LBuf[2] = $4E) and (LBuf[3] = $47),
      'Offline app data should be PONG');

    LSession := LResumption1.GetSession;
    AssertTrue(LSession <> nil, 'GetSession should return resumable session after NewSessionTicket');
    AssertTrue(LSession.IsResumable, 'Captured session should be resumable');
    AssertTrue(Supports(LSession, IFreePascalResumptionSession, LSessionInfo),
      'Captured session should expose FreePascal resumption internals');
    AssertTrue(Length(LSessionInfo.GetTicket) > 0, 'Captured session ticket should not be empty');
    AssertTrue(Length(LSessionInfo.GetResumptionPSK) > 0, 'Captured session PSK should not be empty');
    AssertEqualsInt(16384, LSessionInfo.GetMaxEarlyDataSize,
      'Captured session should preserve max_early_data_size from NewSessionTicket');
    LSerialized := LSession.Serialize;
    AssertTrue(Length(LSerialized) > 0, 'Captured session should serialize to non-empty bytes');
    LInfo := CaptureConnectionInfo('Initial handshake', LConn1);
    AssertConnectionInfo(
      'Initial handshake',
      LInfo,
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      256,
      False,
      LSession.GetID
    );
  finally
    LStream1.Free;
  end;

  LCtx2 := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx2 <> nil, 'Resumed FreePascal client context should be created');
  LCtx2.SetPreferredVersion(sslProtocolTLS13);
  LCtx2.SetVerifyMode([]);

  LStream2 := TOfflineTLS13ServerStream.CreateResumed(LSession);
  try
    LConn2 := LCtx2.CreateConnection(LStream2);
    AssertTrue(LConn2 <> nil, 'Resumed connection should be created');
    AssertTrue(Supports(LConn2, ISSLSessionResumption, LResumption2),
      'Resumed connection should expose ISSLSessionResumption');
    LResumption2.SetSession(LSession);
    (LConn2 as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn2.Connect, 'Resumed offline TLS 1.3 handshake should succeed');
    AssertTrue(LResumption2.IsSessionReused, 'Resumed handshake should report session reuse');
    AssertTrue(LStream2.ObservedPskClientHello,
      'Resumed client handshake should send pre_shared_key in ClientHello');
    AssertTrue(LStream2.ObservedTicketIdentityMatch,
      'Resumed ClientHello identity should match previous ticket');
    LInfo := CaptureConnectionInfo('Resumed handshake', LConn2);
    AssertConnectionInfo(
      'Resumed handshake',
      LInfo,
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      256,
      True,
      LSession.GetID
    );
  finally
    LStream2.Free;
  end;
end;

procedure TestResumedSessionSkipsRequiredCertificateTransparency;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LConn1: ISSLConnection;
  LConn2: ISSLConnection;
  LResumption1: ISSLSessionResumption;
  LResumption2: ISSLSessionResumption;
  LStream1: TOfflineTLS13ServerStream;
  LStream2: TOfflineTLS13ServerStream;
  LSession: ISSLSession;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx1 := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx1 <> nil, 'Initial CT-boundary context should be created');
  LCtx1.SetPreferredVersion(sslProtocolTLS13);
  LCtx1.SetVerifyMode([]);

  LStream1 := TOfflineTLS13ServerStream.CreateInitial(TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  try
    LConn1 := LCtx1.CreateConnection(LStream1);
    AssertTrue(LConn1 <> nil, 'Initial CT-boundary connection should be created');
    (LConn1 as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn1.Connect, 'Initial offline handshake should succeed before CT boundary check');
    LRead := LConn1.Read(LBuf, SizeOf(LBuf));
    AssertEqualsInt(4, LRead, 'Initial handshake should still read post-handshake app data');
    AssertTrue(Supports(LConn1, ISSLSessionResumption, LResumption1),
      'Initial CT-boundary connection should expose ISSLSessionResumption');
    LSession := LResumption1.GetSession;
    AssertTrue(LSession <> nil, 'Initial handshake should still capture a resumable session');
  finally
    LStream1.Free;
  end;

  LCtx2 := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx2 <> nil, 'Resumed CT-boundary context should be created');
  LCtx2.SetPreferredVersion(sslProtocolTLS13);
  LCtx2.SetVerifyMode([sslVerifyPeer]);
  LCtx2.SetOptions(LCtx2.GetOptions + [ssoRequireCertificateTransparency]);

  LStream2 := TOfflineTLS13ServerStream.CreateResumed(LSession);
  try
    LConn2 := LCtx2.CreateConnection(LStream2);
    AssertTrue(LConn2 <> nil, 'Resumed CT-boundary connection should be created');
    AssertTrue(Supports(LConn2, ISSLSessionResumption, LResumption2),
      'Resumed CT-boundary connection should expose ISSLSessionResumption');
    LResumption2.SetSession(LSession);
    (LConn2 as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn2.Connect,
      'CT required should not block resumed TLS 1.3 handshakes without certificate/SCT flight');
    AssertTrue(LResumption2.IsSessionReused,
      'CT-boundary resumed handshake should still report session reuse');
    AssertTrue(LStream2.ObservedPskClientHello,
      'CT-boundary resumed handshake should still send pre_shared_key');
    AssertTrue(LStream2.ObservedTicketIdentityMatch,
      'CT-boundary resumed handshake should still use the previous ticket identity');
  finally
    LStream2.Free;
  end;
end;

procedure TestResumedSessionSkipsRequiredOCSPStapling;
var
  LCtx1: ISSLContext;
  LCtx2: ISSLContext;
  LConn1: ISSLConnection;
  LConn2: ISSLConnection;
  LResumption1: ISSLSessionResumption;
  LResumption2: ISSLSessionResumption;
  LStream1: TOfflineTLS13ServerStream;
  LStream2: TOfflineTLS13ServerStream;
  LSession: ISSLSession;
  LBuf: array[0..15] of Byte;
  LRead: Integer;
begin
  LCtx1 := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx1 <> nil, 'Initial OCSP-boundary context should be created');
  LCtx1.SetPreferredVersion(sslProtocolTLS13);
  LCtx1.SetVerifyMode([]);

  LStream1 := TOfflineTLS13ServerStream.CreateInitial(TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  try
    LConn1 := LCtx1.CreateConnection(LStream1);
    AssertTrue(LConn1 <> nil, 'Initial OCSP-boundary connection should be created');
    (LConn1 as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn1.Connect, 'Initial offline handshake should succeed before OCSP boundary check');
    LRead := LConn1.Read(LBuf, SizeOf(LBuf));
    AssertEqualsInt(4, LRead, 'Initial handshake should still read post-handshake app data');
    AssertTrue(Supports(LConn1, ISSLSessionResumption, LResumption1),
      'Initial OCSP-boundary connection should expose ISSLSessionResumption');
    LSession := LResumption1.GetSession;
    AssertTrue(LSession <> nil, 'Initial handshake should still capture a resumable session');
  finally
    LStream1.Free;
  end;

  LCtx2 := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx2 <> nil, 'Resumed OCSP-boundary context should be created');
  LCtx2.SetPreferredVersion(sslProtocolTLS13);
  LCtx2.SetVerifyMode([sslVerifyPeer]);
  LCtx2.SetOptions(LCtx2.GetOptions + [ssoRequireOCSPStapling]);

  LStream2 := TOfflineTLS13ServerStream.CreateResumed(LSession);
  try
    LConn2 := LCtx2.CreateConnection(LStream2);
    AssertTrue(LConn2 <> nil, 'Resumed OCSP-boundary connection should be created');
    AssertTrue(Supports(LConn2, ISSLSessionResumption, LResumption2),
      'Resumed OCSP-boundary connection should expose ISSLSessionResumption');
    LResumption2.SetSession(LSession);
    (LConn2 as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn2.Connect,
      'Required OCSP stapling should not block resumed TLS 1.3 handshakes without certificate/stapled-response flight');
    AssertTrue(LResumption2.IsSessionReused,
      'OCSP-boundary resumed handshake should still report session reuse');
    AssertTrue(LStream2.ObservedPskClientHello,
      'OCSP-boundary resumed handshake should still send pre_shared_key');
    AssertTrue(LStream2.ObservedTicketIdentityMatch,
      'OCSP-boundary resumed handshake should still use the previous ticket identity');
  finally
    LStream2.Free;
  end;
end;

procedure TestALPNAndSNISelection;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LInfo: TSSLConnectionInfo;
  LStream: TOfflineTLS13ServerStream;
  LCtxNoOverlap: ISSLContext;
  LConnNoOverlap: ISSLConnection;
  LInfoNoOverlap: TSSLConnectionInfo;
  LStreamNoOverlap: TOfflineTLS13ServerStream;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx <> nil, 'ALPN client context should be created');
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LCtx.SetVerifyMode([]);
  LCtx.SetALPNProtocols('h2,http/1.1');

  LStream := TOfflineTLS13ServerStream.CreateInitial(
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
    'http/1.1'
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'ALPN client connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect, 'ALPN client handshake should succeed');
    AssertTrue(CaptureSelectedALPN('ALPN handshake', LConn) = 'http/1.1',
      'Client connection should record the negotiated ALPN');
    LInfo := CaptureConnectionInfo('ALPN handshake', LConn);
    AssertTrue(LInfo.ALPNProtocol = 'http/1.1',
      'Connection info should mirror the negotiated ALPN');
    AssertTrue(LInfo.ServerName = 'example.com',
      'Connection info should mirror the configured server name');
  finally
    LStream.Free;
  end;

  LCtxNoOverlap := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtxNoOverlap <> nil, 'ALPN no-overlap context should be created');
  LCtxNoOverlap.SetPreferredVersion(sslProtocolTLS13);
  LCtxNoOverlap.SetVerifyMode([]);
  LCtxNoOverlap.SetALPNProtocols('spdy/3');

  LStreamNoOverlap := TOfflineTLS13ServerStream.CreateInitial(
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
    ''
  );
  try
    LConnNoOverlap := LCtxNoOverlap.CreateConnection(LStreamNoOverlap);
    AssertTrue(LConnNoOverlap <> nil, 'ALPN no-overlap connection should be created');
    (LConnNoOverlap as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConnNoOverlap.Connect, 'ALPN no-overlap handshake should still succeed');
    AssertTrue(CaptureSelectedALPN('ALPN no-overlap handshake', LConnNoOverlap) = '',
      'Client connection should leave ALPN empty when the server does not select one');
    LInfoNoOverlap := CaptureConnectionInfo('ALPN no-overlap handshake', LConnNoOverlap);
    AssertTrue(LInfoNoOverlap.ALPNProtocol = '',
      'Connection info should leave ALPN empty when the server does not select one');
    AssertTrue(LInfoNoOverlap.ServerName = 'example.com',
      'Connection info should still mirror the configured server name');
  finally
    LStreamNoOverlap.Free;
  end;
end;

begin
  WriteLn('Testing FreePascal client session resumption contract...');

  TestOfflineSessionCaptureAndResume;
  TestResumedSessionSkipsRequiredCertificateTransparency;
  TestResumedSessionSkipsRequiredOCSPStapling;
  TestALPNAndSNISelection;

  WriteLn('✅ FreePascal client session resumption checks passed');
end.
