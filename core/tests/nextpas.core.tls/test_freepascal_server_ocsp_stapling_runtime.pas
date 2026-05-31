program test_freepascal_server_ocsp_stapling_runtime;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.factory,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.crypto.x25519,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.servercertificate,
  nextpas.core.tls.crypto.hash;

procedure Fail(const AMessage: string);
begin
  WriteLn('FAIL: ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
var
  I: Integer;
begin
  if Length(AExpected) <> Length(AActual) then
    Fail(Format('%s (expected_len=%d actual_len=%d)', [AMessage, Length(AExpected), Length(AActual)]));

  for I := 0 to High(AExpected) do
    if AExpected[I] <> AActual[I] then
      Fail(Format('%s (first_diff=%d)', [AMessage, I]));
end;

function HashTranscriptForSuite(ACipherSuite: Word; const ATranscriptData: TBytes): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(SHA256(ATranscriptData));
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(SHA384(ATranscriptData));
  Result := nil;
end;

procedure AppendHandshakeBytes(var ADest: TBytes; const ASource: TBytes);
var
  LOldLen, LAppendLen: Integer;
begin
  LAppendLen := Length(ASource);
  if LAppendLen = 0 then
    Exit;

  LOldLen := Length(ADest);
  SetLength(ADest, LOldLen + LAppendLen);
  Move(ASource[0], ADest[LOldLen], LAppendLen);
end;

function TryPopHandshakeMessage(var ABuffer: TBytes; out AMessage: TBytes): Boolean;
var
  LMsgLen: Cardinal;
  LTotalLen: Integer;
  LRemainLen: Integer;
  LTemp: TBytes;
begin
  SetLength(AMessage, 0);
  Result := False;

  if Length(ABuffer) < 4 then
    Exit;

  LMsgLen := ReadUInt24(ABuffer, 1);
  if LMsgLen > Cardinal(High(Integer) - 4) then
    Exit;

  LTotalLen := 4 + Integer(LMsgLen);
  if Length(ABuffer) < LTotalLen then
    Exit;

  SetLength(AMessage, LTotalLen);
  Move(ABuffer[0], AMessage[0], LTotalLen);

  LRemainLen := Length(ABuffer) - LTotalLen;
  if LRemainLen > 0 then
  begin
    SetLength(LTemp, LRemainLen);
    Move(ABuffer[LTotalLen], LTemp[0], LRemainLen);
    ABuffer := LTemp;
  end
  else
    SetLength(ABuffer, 0);

  Result := True;
end;

function ReadFileBytes(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  Result := nil;
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LStream.Free;
  end;
end;

type
  TOfflineStaplingObserveClientStream = class(TStream)
  private
    FRequestStapling: Boolean;
    FReadBuffer: TBytes;
    FReadPosition: Int64;
    FWriteStage: Integer;
    FClientPrivateKey: TBytes;
    FClientPublicKey: TBytes;
    FClientHelloHandshake: TBytes;
    FTranscriptData: TBytes;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FNegotiatedCipherSuite: Word;
    FObservedCertificateMessage: Boolean;
    FObservedCertificateInfo: TTLS13ServerCertificateInfo;

    procedure Enqueue(const AData: TBytes);
    procedure PrepareClientHello;
    procedure HandleServerHello(const AData: TBytes);
    procedure HandleServerHandshakeFlight(const AData: TBytes);
  public
    constructor Create(ARequestStapling: Boolean);

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;

    property ObservedCertificateMessage: Boolean read FObservedCertificateMessage;
    property ObservedCertificateInfo: TTLS13ServerCertificateInfo read FObservedCertificateInfo;
  end;

constructor TOfflineStaplingObserveClientStream.Create(ARequestStapling: Boolean);
begin
  inherited Create;
  FRequestStapling := ARequestStapling;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  FWriteStage := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  FNegotiatedCipherSuite := 0;
  FObservedCertificateMessage := False;
  FillChar(FObservedCertificateInfo, SizeOf(FObservedCertificateInfo), 0);
  PrepareClientHello;
end;

procedure TOfflineStaplingObserveClientStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TOfflineStaplingObserveClientStream.PrepareClientHello;
var
  LRecord: TBytes;
begin
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  SetLength(FTranscriptData, 0);
  FObservedCertificateMessage := False;
  FillChar(FObservedCertificateInfo, SizeOf(FObservedCertificateInfo), 0);

  GenerateX25519KeyPair(FClientPrivateKey, FClientPublicKey);
  FClientHelloHandshake := BuildTLS13ClientHelloHandshake(
    'localhost',
    '',
    FClientPublicKey,
    FRequestStapling
  );
  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, FClientHelloHandshake);
  Enqueue(LRecord);
end;

procedure TOfflineStaplingObserveClientStream.HandleServerHello(const AData: TBytes);
var
  LHandshake: TBytes;
  LInfo: TTLS13ServerHelloInfo;
  LSharedSecret: TBytes;
  LError: string;
begin
  if not TryExtractHandshakePayloadFromRecord(AData, LHandshake) then
    raise Exception.Create('Failed to extract ServerHello handshake payload');
  if not TryParseServerHelloFromHandshake(LHandshake, LInfo) then
    raise Exception.Create('Failed to parse ServerHello');
  if not LInfo.Valid then
    raise Exception.Create('Parsed ServerHello should be valid');
  if not LInfo.HasKeyShare then
    raise Exception.Create('ServerHello missing key_share');

  FNegotiatedCipherSuite := LInfo.SelectedCipherSuite;
  LSharedSecret := X25519ComputeSharedSecret(FClientPrivateKey, LInfo.PeerKeyShare);

  SetLength(FTranscriptData, Length(FClientHelloHandshake) + Length(LHandshake));
  Move(FClientHelloHandshake[0], FTranscriptData[0], Length(FClientHelloHandshake));
  Move(LHandshake[0], FTranscriptData[Length(FClientHelloHandshake)], Length(LHandshake));

  if not TryDeriveTLS13HandshakeSecrets(
    FNegotiatedCipherSuite,
    LSharedSecret,
    FTranscriptData,
    FHandshakeSecrets,
    LError
  ) then
    raise Exception.Create('Failed to derive handshake secrets: ' + LError);
end;

procedure TOfflineStaplingObserveClientStream.HandleServerHandshakeFlight(const AData: TBytes);
var
  LHeader: TTLSRecordHeader;
  LPayload: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LError: string;
  LBuffer: TBytes;
  LMessage: TBytes;
  LType: Byte;
  LVerifyData: TBytes;
  LTranscriptHash: TBytes;
  LClientFinished: TBytes;
  LInnerPlaintext: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LSawFinished: Boolean;
  LSawCertificate: Boolean;
  LSawCertificateVerify: Boolean;
begin
  if not ParseTLSRecordHeader(AData, LHeader) then
    raise Exception.Create('Failed to parse encrypted server handshake header');
  if Length(AData) < 5 + LHeader.Length then
    raise Exception.Create('Encrypted server handshake record is truncated');

  SetLength(LPayload, LHeader.Length);
  if LHeader.Length > 0 then
    Move(AData[5], LPayload[0], LHeader.Length);

  if not TryTLS13AEADDecrypt(
    FNegotiatedCipherSuite,
    FHandshakeSecrets.ServerHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ServerHandshakeIV, 0),
    BuildTLS13RecordAAD(LHeader.Length),
    LPayload,
    LPlaintext,
    LError
  ) then
    raise Exception.Create('Failed to decrypt server handshake flight: ' + LError);

  if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
    raise Exception.Create('Invalid TLSInnerPlaintext in server handshake flight');
  if LInnerContentType <> TLS_CONTENT_TYPE_HANDSHAKE then
    raise Exception.Create('Server handshake flight should carry handshake content');

  LBuffer := LInnerFragment;
  LSawFinished := False;
  LSawCertificate := False;
  LSawCertificateVerify := False;
  while TryPopHandshakeMessage(LBuffer, LMessage) do
  begin
    LType := LMessage[0];
    case LType of
      TLS_HANDSHAKE_TYPE_CERTIFICATE:
        begin
          LSawCertificate := True;
          FObservedCertificateMessage := True;
          if not TryParseTLS13ServerCertificateHandshakeInfo(
            LMessage,
            FObservedCertificateInfo,
            LError
          ) then
            raise Exception.Create('Failed to parse server Certificate message: ' + LError);
        end;
      TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY:
        LSawCertificateVerify := True;
    end;

    if LType = TLS_HANDSHAKE_TYPE_FINISHED then
    begin
      SetLength(LVerifyData, Length(LMessage) - 4);
      if Length(LVerifyData) > 0 then
        Move(LMessage[4], LVerifyData[0], Length(LVerifyData));

      LTranscriptHash := HashTranscriptForSuite(FNegotiatedCipherSuite, FTranscriptData);
      if not TLS13VerifyFinishedForCipherSuite(
        FNegotiatedCipherSuite,
        FHandshakeSecrets.ServerHandshakeTrafficSecret,
        LTranscriptHash,
        LVerifyData
      ) then
        raise Exception.Create('Server Finished verification failed in scripted client');

      AppendHandshakeBytes(FTranscriptData, LMessage);
      LSawFinished := True;
    end
    else
      AppendHandshakeBytes(FTranscriptData, LMessage);
  end;

  if not LSawFinished then
    raise Exception.Create('Server handshake flight should include Finished');
  if not LSawCertificate then
    raise Exception.Create('Initial server handshake should include Certificate');
  if not LSawCertificateVerify then
    raise Exception.Create('Initial server handshake should include CertificateVerify');

  LVerifyData := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    FNegotiatedCipherSuite,
    FHandshakeSecrets.ClientHandshakeTrafficSecret,
    HashTranscriptForSuite(FNegotiatedCipherSuite, FTranscriptData)
  );

  SetLength(LClientFinished, 0);
  AppendByte(LClientFinished, TLS_HANDSHAKE_TYPE_FINISHED);
  AppendUInt24(LClientFinished, Length(LVerifyData));
  AppendBytes(LClientFinished, LVerifyData);

  LInnerPlaintext := BuildTLS13InnerPlaintext(LClientFinished, TLS_CONTENT_TYPE_HANDSHAKE);
  if not TryTLS13AEADEncrypt(
    FNegotiatedCipherSuite,
    FHandshakeSecrets.ClientHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, 0),
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FNegotiatedCipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
    raise Exception.Create('Failed to encrypt scripted client Finished: ' + LError);

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  Enqueue(LRecord);
  AppendHandshakeBytes(FTranscriptData, LClientFinished);
end;

function TOfflineStaplingObserveClientStream.Read(var Buffer; Count: Longint): Longint;
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

function TOfflineStaplingObserveClientStream.Write(const Buffer; Count: Longint): Longint;
var
  LData: TBytes;
begin
  SetLength(LData, Count);
  if Count > 0 then
    Move(Buffer, LData[0], Count);

  case FWriteStage of
    0:
      begin
        HandleServerHello(LData);
        FWriteStage := 1;
      end;
    1:
      begin
        HandleServerHandshakeFlight(LData);
        FWriteStage := 2;
      end;
  end;

  Result := Count;
end;

function TOfflineStaplingObserveClientStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FReadPosition := Offset;
    soCurrent: Inc(FReadPosition, Offset);
    soEnd: FReadPosition := Length(FReadBuffer) + Offset;
  end;
  Result := FReadPosition;
end;

function NewServerContext: ISSLContext;
begin
  Result := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(Result <> nil, 'FreePascal server context should be created');
  Result.SetPreferredVersion(sslProtocolTLS13);
  Result.SetSessionCacheMode(False);
  Result.LoadCertificate('tests/certificate/test_certs/signer_cert.pem');
  Result.LoadPrivateKey('tests/certificate/test_certs/signer_key.pem');
end;

function NewServerContextFromBuilder(const AStapledResponseFile: string = ''): ISSLContext;
var
  LBuilder: ISSLContextBuilder;
begin
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithTLS13
    .WithSessionCache(False)
    .WithCertificate('tests/certificate/test_certs/signer_cert.pem')
    .WithPrivateKey('tests/certificate/test_certs/signer_key.pem');

  if AStapledResponseFile <> '' then
    LBuilder := LBuilder.WithServerOCSPStapledResponseFile(AStapledResponseFile);

  Result := LBuilder.BuildServer;
  AssertTrue(Result <> nil, 'Builder should create FreePascal server context');
end;

procedure TestServerEmitsConfiguredStapledOCSPWhenRequested;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TOfflineStaplingObserveClientStream;
  LFixture: TBytes;
  LStaplingContext: ISSLServerOCSPStaplingContext;
begin
  LCtx := NewServerContext;
  AssertTrue(
    Supports(LCtx, ISSLServerOCSPStaplingContext, LStaplingContext),
    'FreePascal server context should expose public server stapling interface'
  );
  LFixture := ReadFileBytes('tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der');
  AssertTrue(Length(LFixture) > 0, 'OCSP fixture should not be empty');
  LStaplingContext.SetServerStapledOCSPResponse(LFixture);

  LStream := TOfflineStaplingObserveClientStream.Create(True);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Server connection should be created');
    AssertTrue(LConn.Accept, 'Server accept should succeed when stapled response is configured');
    AssertTrue(LStream.ObservedCertificateMessage, 'Scripted client should observe the Certificate message');
    AssertTrue(
      LStream.ObservedCertificateInfo.HasLeafOCSPStapledResponse,
      'Configured stapled response should be emitted on the leaf CertificateEntry when requested'
    );
    AssertBytesEqual(
      LFixture,
      LStream.ObservedCertificateInfo.LeafOCSPStapledResponse,
      'Emitted stapled response bytes should match configured material'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestServerDoesNotEmitStapledOCSPWhenClientDidNotRequestIt;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TOfflineStaplingObserveClientStream;
  LFixture: TBytes;
  LStaplingContext: ISSLServerOCSPStaplingContext;
begin
  LCtx := NewServerContext;
  AssertTrue(
    Supports(LCtx, ISSLServerOCSPStaplingContext, LStaplingContext),
    'FreePascal server context should expose public server stapling interface'
  );
  LFixture := ReadFileBytes('tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der');
  AssertTrue(Length(LFixture) > 0, 'OCSP fixture should not be empty');
  LStaplingContext.SetServerStapledOCSPResponse(LFixture);

  LStream := TOfflineStaplingObserveClientStream.Create(False);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Server connection should be created');
    AssertTrue(LConn.Accept, 'Server accept should succeed without client status_request');
    AssertTrue(LStream.ObservedCertificateMessage, 'Scripted client should observe the Certificate message');
    AssertTrue(
      not LStream.ObservedCertificateInfo.HasLeafOCSPStapledResponse,
      'Server must not emit stapled response when client did not request status_request'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestServerKeepsCertificateEntryUnchangedWithoutStapledMaterial;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TOfflineStaplingObserveClientStream;
begin
  LCtx := NewServerContext;
  LStream := TOfflineStaplingObserveClientStream.Create(True);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Server connection should be created');
    AssertTrue(LConn.Accept, 'Server accept should succeed without configured stapled response');
    AssertTrue(LStream.ObservedCertificateMessage, 'Scripted client should observe the Certificate message');
    AssertTrue(
      not LStream.ObservedCertificateInfo.HasLeafOCSPStapledResponse,
      'Server should keep CertificateEntry unchanged when stapled response is not configured'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestBuilderBuildServerLoadsConfiguredStapledOCSPFile;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TOfflineStaplingObserveClientStream;
  LFixture: TBytes;
  LStaplingContext: ISSLServerOCSPStaplingContext;
  LFixtureFile: string;
begin
  LFixtureFile := 'tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der';
  LFixture := ReadFileBytes(LFixtureFile);
  AssertTrue(Length(LFixture) > 0, 'OCSP fixture should not be empty');

  LCtx := NewServerContextFromBuilder(LFixtureFile);
  AssertTrue(
    Supports(LCtx, ISSLServerOCSPStaplingContext, LStaplingContext),
    'BuildServer should expose public server stapling interface'
  );
  AssertTrue(LStaplingContext.HasServerStapledOCSPResponse,
    'BuildServer should load configured stapled OCSP response file into context');
  AssertBytesEqual(
    LFixture,
    LStaplingContext.GetServerStapledOCSPResponse,
    'BuildServer should load configured stapled OCSP response bytes from file'
  );

  LStream := TOfflineStaplingObserveClientStream.Create(True);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Builder-built server connection should be created');
    AssertTrue(LConn.Accept, 'Builder-built server accept should succeed with stapled response file');
    AssertTrue(LStream.ObservedCertificateMessage, 'Scripted client should observe the Certificate message');
    AssertTrue(
      LStream.ObservedCertificateInfo.HasLeafOCSPStapledResponse,
      'Builder-driven server context should emit stapled response when requested'
    );
    AssertBytesEqual(
      LFixture,
      LStream.ObservedCertificateInfo.LeafOCSPStapledResponse,
      'Builder-driven emitted stapled response bytes should match configured file contents'
    );
  finally
    LStream.Free;
  end;
end;

begin
  WriteLn('Testing FreePascal server OCSP stapling issuance runtime...');

  TestServerEmitsConfiguredStapledOCSPWhenRequested;
  TestServerDoesNotEmitStapledOCSPWhenClientDidNotRequestIt;
  TestServerKeepsCertificateEntryUnchangedWithoutStapledMaterial;
  TestBuilderBuildServerLoadsConfiguredStapledOCSPFile;

  WriteLn('PASS: FreePascal server OCSP stapling issuance runtime checks passed');
end.
