program test_freepascal_client_certificate_flight_requirements;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.serverhello,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.crypto.x25519,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.encoding,
  nextpas.core.crypto.hash,
  nextpas.core.tls.freepascal.session,
  nextpas.core.tls.freepascal.lib;
type
  TScriptedHandshakeMode = (shmFullWithoutCertificate, shmResumedWithoutCertificate);

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

function BytesOf(const AValue: AnsiString): TBytes;
begin
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
end;

function BuildManualSession(const ALabel: AnsiString): ISSLSession;
var
  LSession: TFreePascalSession;
  LTicket: TBytes;
  LPSK: TBytes;
begin
  LSession := TFreePascalSession.Create;
  LTicket := BytesOf('ticket-' + ALabel);
  LPSK := BytesOf('0123456789abcdef0123456789abcdef');
  LSession.ConfigureResumption(
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
    'TLS_CHACHA20_POLY1305_SHA256',
    [$01, $02, $03],
    LTicket,
    LPSK,
    7200,
    $01020304,
    DateTimeNow,
    7200,
    0
  );
  LSession.BoundServerName := 'example.com';
  Result := LSession;
end;

type
  TScriptedServerFlightStream = class(TInterfacedObject, IStream)
  private
    FMode: TScriptedHandshakeMode;
    FCipherSuite: Word;
    FReadBuffer: TBytes;
    FReadPosition: Int64;
    FWriteStage: Integer;
    FTranscriptData: TBytes;
    FServerPrivateKey: TBytes;
    FServerPublicKey: TBytes;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FPendingSession: IFreePascalResumptionSession;
    FObservedPskClientHello: Boolean;

    procedure Enqueue(const AData: TBytes);
    procedure HandleClientHello(const AData: TBytes);
    procedure HandleClientFinished(const AData: TBytes);
  public
    constructor CreateFullHandshake;
    constructor CreateResumed(const ASession: ISSLSession);

    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);

    property ObservedPskClientHello: Boolean read FObservedPskClientHello;
  end;

constructor TScriptedServerFlightStream.CreateFullHandshake;
begin
  inherited Create;
  FMode := shmFullWithoutCertificate;
  FCipherSuite := TLS13_CIPHER_CHACHA20_POLY1305_SHA256;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  FWriteStage := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  FPendingSession := nil;
  FObservedPskClientHello := False;
end;

constructor TScriptedServerFlightStream.CreateResumed(const ASession: ISSLSession);
begin
  CreateFullHandshake;
  FMode := shmResumedWithoutCertificate;
  if not Supports(ASession, IFreePascalResumptionSession, FPendingSession) then
    raise Exception.Create('Resumed scripted stream requires FreePascal resumption session');
end;

procedure TScriptedServerFlightStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TScriptedServerFlightStream.HandleClientHello(const AData: TBytes);
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
  LDecrypted: TBytes;
  LError: string;
begin
  if not TryExtractHandshakePayloadFromRecord(AData, LHandshake) then
    raise Exception.Create('Failed to extract ClientHello from record');
  if not TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LError) then
    raise Exception.Create('Failed to parse ClientHello: ' + LError);
  if not LInfo.HasKeyShare then
    raise Exception.Create('ClientHello missing key_share');

  if FMode = shmResumedWithoutCertificate then
  begin
    FObservedPskClientHello := LInfo.HasPreSharedKey;
    if not FObservedPskClientHello then
      raise Exception.Create('Resumed ClientHello missing pre_shared_key');
    if not BytesEqual(LInfo.FirstPSKIdentity, FPendingSession.GetTicket) then
      raise Exception.Create('Resumed ClientHello PSK identity mismatch');
  end;

  GenerateX25519KeyPair(FServerPrivateKey, FServerPublicKey);
  LSharedSecret := X25519ComputeSharedSecret(FServerPrivateKey, LInfo.PeerKeyShare);

  if FMode = shmResumedWithoutCertificate then
    LServerHello := BuildTLS13ServerHelloHandshakeWithSelectedPSK(
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

  if FMode = shmResumedWithoutCertificate then
  begin
    if not TryDeriveTLS13HandshakeSecretsWithPSK(
      FCipherSuite,
      LSharedSecret,
      FTranscriptData,
      FPendingSession.GetResumptionPSK,
      FHandshakeSecrets,
      LError
    ) then
      raise Exception.Create('Failed to derive resumed handshake secrets: ' + LError);
  end
  else
  begin
    if not TryDeriveTLS13HandshakeSecrets(
      FCipherSuite,
      LSharedSecret,
      FTranscriptData,
      FHandshakeSecrets,
      LError
    ) then
      raise Exception.Create('Failed to derive handshake secrets: ' + LError);
  end;

  LEncryptedExtensions := BuildEncryptedExtensionsMessage;
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
    LError
  ) then
    raise Exception.Create('Failed to encrypt server handshake flight: ' + LError);

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  Enqueue(LRecord);
  AppendBytes(FTranscriptData, LServerFinished);

  // DEBUG: self-check server flight encryption round-trip
  if TryTLS13AEADDecrypt(
    FCipherSuite,
    FHandshakeSecrets.ServerHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ServerHandshakeIV, 0),
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FCipherSuite))),
    LEncrypted,
    LDecrypted,
    LError
  ) then
    WriteLn('DEBUG self-check: server flight decrypts OK')
  else
    WriteLn('DEBUG self-check FAIL: ', LError);

  FWriteStage := 1;
end;

procedure TScriptedServerFlightStream.HandleClientFinished(const AData: TBytes);
var
  LHeader: TTLSRecordHeader;
  LPayload: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LError: string;
  LVerifyData: TBytes;
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
  begin
    WriteLn('DEBUG Client Finished record: type=', LHeader.ContentType, ' len=', LHeader.Length);
    WriteLn('DEBUG payload hex: ', TEncodingUtils.BytesToHex(LPayload));
    WriteLn('DEBUG key hex: ', TEncodingUtils.BytesToHex(FHandshakeSecrets.ClientHandshakeKey));
    WriteLn('DEBUG iv hex: ', TEncodingUtils.BytesToHex(FHandshakeSecrets.ClientHandshakeIV));
    WriteLn('DEBUG transcript len: ', Length(FTranscriptData), ' hex: ', TEncodingUtils.BytesToHex(FTranscriptData));
    raise Exception.Create('Failed to decrypt client Finished: ' + LError);
  end;

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
    raise Exception.Create('Client Finished verification failed in scripted server');

  FWriteStage := 2;
end;

function TScriptedServerFlightStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: Int64;
begin
  WriteLn('DEBUG Read called: count=', ACount, ' pos=', FReadPosition, ' buflen=', Length(FReadBuffer));
  if ACount = 0 then
    Exit(0);

  LAvailable := Length(FReadBuffer) - FReadPosition;
  if LAvailable <= 0 then
    Exit(0);

  if SizeUInt(LAvailable) > ACount then
    Result := ACount
  else
    Result := SizeUInt(LAvailable);

  Move(FReadBuffer[FReadPosition], ABuf, Result);
  Inc(FReadPosition, Result);
end;

function TScriptedServerFlightStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LData: TBytes;
begin
  WriteLn('DEBUG Write called: count=', ACount, ' stage=', FWriteStage);
  SetLength(LData, ACount);
  if ACount > 0 then
    Move(ABuf, LData[0], ACount);

  case FWriteStage of
    0: HandleClientHello(LData);
    1: HandleClientFinished(LData);
  end;

  Result := ACount;
end;

function TScriptedServerFlightStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  WriteLn('DEBUG Seek called: offset=', AOffset, ' origin=', Ord(AOrigin));
  case AOrigin of
    soBeginning: FReadPosition := AOffset;
    soCurrent: Inc(FReadPosition, AOffset);
    soEnd: FReadPosition := Length(FReadBuffer) + AOffset;
  end;
  Result := FReadPosition;
end;

procedure TScriptedServerFlightStream.Close;
begin
end;

function TScriptedServerFlightStream.GetSize: Int64;
begin
  Result := Length(FReadBuffer);
end;

function TScriptedServerFlightStream.GetPosition: Int64;
begin
  Result := FReadPosition;
end;

procedure TScriptedServerFlightStream.SetPosition(const AValue: Int64);
begin
  FReadPosition := AValue;
end;

procedure TestFullHandshakeRequiresCertificateFlight;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LCertVerify: ISSLCertificateVerification;
  LStream: IStream;
  LVerifyText: string;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx <> nil, 'FreePascal client context should be created');
  LCtx.SetPreferredVersion(sslProtocolTLS13);

  LStream := TScriptedServerFlightStream.CreateFullHandshake;
  LConn := LCtx.CreateConnection(LStream);
  AssertTrue(LConn <> nil, 'Full-handshake connection should be created');
  (LConn as ISSLClientConnection).SetServerName('example.com');

  AssertTrue(not LConn.Connect,
    'Full handshake without Certificate/CertificateVerify should fail');
  AssertTrue(Supports(LConn, ISSLCertificateVerification, LCertVerify),
    'Full-handshake connection should expose certificate verification interface');
  LVerifyText := LowerCase(LCertVerify.GetVerifyResultString);
  AssertTrue(Pos('certificate', LVerifyText) > 0,
    'Failure should mention missing certificate flight');
end;

procedure TestResumedHandshakeStillAllowsCertificateOmission;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LResumption: ISSLSessionResumption;
  LStream: IStream;
  LScripted: TScriptedServerFlightStream;
  LSession: ISSLSession;
begin
  LSession := BuildManualSession('resumed-no-cert');

  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx <> nil, 'Resumed FreePascal client context should be created');
  LCtx.SetPreferredVersion(sslProtocolTLS13);

  LScripted := TScriptedServerFlightStream.CreateResumed(LSession);
  LStream := LScripted;
  LConn := LCtx.CreateConnection(LStream);
  AssertTrue(LConn <> nil, 'Resumed connection should be created');
  AssertTrue(Supports(LConn, ISSLSessionResumption, LResumption),
    'Resumed connection should expose ISSLSessionResumption');
  LResumption.SetSession(LSession);
  (LConn as ISSLClientConnection).SetServerName('example.com');

  AssertTrue(LConn.Connect,
    'Resumed PSK handshake should still succeed without Certificate/CertificateVerify');
  AssertTrue(LResumption.IsSessionReused,
    'Resumed PSK handshake should report session reuse');
  AssertTrue(LScripted.ObservedPskClientHello,
    'Resumed PSK handshake should send pre_shared_key in ClientHello');
end;

begin
  WriteLn('Testing FreePascal client certificate-flight requirements...');

  TestFullHandshakeRequiresCertificateFlight;
  TestResumedHandshakeStillAllowsCertificateOmission;

  WriteLn('✅ FreePascal client certificate-flight checks passed');
end.
