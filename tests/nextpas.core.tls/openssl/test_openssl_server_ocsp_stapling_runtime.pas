program test_openssl_server_ocsp_stapling_runtime;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes, ctypes,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.tls13.x25519,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.servercertificate,
  nextpas.core.tls.crypto.hash;

const
  OCSP_FIXTURE_FILE = 'tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der';
  CERT_FILE = 'tests/certificate/test_certs/signer_cert.pem';
  KEY_FILE = 'tests/certificate/test_certs/signer_key.pem';

// INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: this backend-specific
// OCSP stapling runtime file intentionally keeps direct core verify-result
// diagnostics as server-side proof. Generic ISSLCertificateVerification
// owner-path guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

var
  GOriginalSSLSetStatusOCSPResp: TSSL_set_tlsext_status_ocsp_resp = nil;
  GStatusOCSPRespCallCount: Integer = 0;

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
    Fail(Format('%s (expected_len=%d actual_len=%d)',
      [AMessage, Length(AExpected), Length(AActual)]));

  for I := 0 to High(AExpected) do
    if AExpected[I] <> AActual[I] then
      Fail(Format('%s (first_diff=%d)', [AMessage, I]));
end;

function HashTranscriptForSuite(ACipherSuite: Word;
  const ATranscriptData: TBytes): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(SHA256(ATranscriptData));
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(SHA384(ATranscriptData));
  SetLength(Result, 0);
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

function TryPopTLSRecord(var ABuffer: TBytes; out ARecord: TBytes): Boolean;
var
  LHeader: TTLSRecordHeader;
  LTotalLen: Integer;
  LRemainLen: Integer;
  LTemp: TBytes;
begin
  SetLength(ARecord, 0);
  Result := False;

  if Length(ABuffer) < 5 then
    Exit;

  if not ParseTLSRecordHeader(ABuffer, LHeader) then
    Exit;

  LTotalLen := 5 + LHeader.Length;
  if Length(ABuffer) < LTotalLen then
    Exit;

  SetLength(ARecord, LTotalLen);
  Move(ABuffer[0], ARecord[0], LTotalLen);

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
  SetLength(Result, 0);
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LStream.Free;
  end;
end;

function CountingSSLSetStatusOCSPResp(ssl: PSSL; resp: PByte; len: clong): clong; cdecl;
begin
  Inc(GStatusOCSPRespCallCount);
  if Assigned(GOriginalSSLSetStatusOCSPResp) then
    Result := GOriginalSSLSetStatusOCSPResp(ssl, resp, len)
  else
    Result := 0;
end;

function GetOpenSSLContextStatusType(const ACtx: ISSLContext): Integer;
var
  LNativeAccess: ISSLNativeHandleAccess;
begin
  Result := -1;

  if not Assigned(SSL_CTX_get_tlsext_status_type) then
    Exit;

  if Supports(ACtx, ISSLNativeHandleAccess, LNativeAccess) and
     (LNativeAccess.GetNativeHandle <> nil) then
    Result := SSL_CTX_get_tlsext_status_type(PSSL_CTX(LNativeAccess.GetNativeHandle));
end;

function GetOpenSSLConnectionStatusType(const AConn: ISSLConnection): Integer;
var
  LNativeAccess: ISSLNativeHandleAccess;
begin
  Result := -1;

  if not Assigned(SSL_get_tlsext_status_type) then
    Exit;

  if Supports(AConn, ISSLNativeHandleAccess, LNativeAccess) and
     (LNativeAccess.GetNativeHandle <> nil) then
    Result := SSL_get_tlsext_status_type(PSSL(LNativeAccess.GetNativeHandle));
end;

type
  TOfflineStaplingObserveClientStream = class(TStream)
  private
    FRequestStapling: Boolean;
    FReadBuffer: TBytes;
    FReadPosition: Int64;
    FClientPrivateKey: TBytes;
    FClientPublicKey: TBytes;
    FClientHelloHandshake: TBytes;
    FTranscriptData: TBytes;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FNegotiatedCipherSuite: Word;
    FObservedCertificateMessage: Boolean;
    FObservedCertificateInfo: TTLS13ServerCertificateInfo;
    FIncomingWriteBuffer: TBytes;
    FPendingServerHandshakeBytes: TBytes;
    FHandshakeStage: Integer;
    FServerHandshakeRecordSeq: QWord;
    FClientHandshakeRecordSeq: QWord;
    FObservedCertificateVerify: Boolean;
    FObservedServerFinished: Boolean;

    procedure Enqueue(const AData: TBytes);
    procedure PrepareClientHello;
    procedure HandleServerHello(const AData: TBytes);
    procedure HandleServerHandshakeRecord(const AData: TBytes);
    procedure SendClientFinished;
    procedure HandleServerRecord(const AData: TBytes);
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
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  FNegotiatedCipherSuite := 0;
  FObservedCertificateMessage := False;
  FillChar(FObservedCertificateInfo, SizeOf(FObservedCertificateInfo), 0);
  SetLength(FIncomingWriteBuffer, 0);
  SetLength(FPendingServerHandshakeBytes, 0);
  FHandshakeStage := 0;
  FServerHandshakeRecordSeq := 0;
  FClientHandshakeRecordSeq := 0;
  FObservedCertificateVerify := False;
  FObservedServerFinished := False;
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
  SetLength(FIncomingWriteBuffer, 0);
  SetLength(FPendingServerHandshakeBytes, 0);
  FHandshakeStage := 0;
  FServerHandshakeRecordSeq := 0;
  FClientHandshakeRecordSeq := 0;
  FObservedCertificateVerify := False;
  FObservedServerFinished := False;

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

procedure TOfflineStaplingObserveClientStream.SendClientFinished;
var
  LVerifyData: TBytes;
  LClientFinished: TBytes;
  LInnerPlaintext: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LError: string;
begin
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
    BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, FClientHandshakeRecordSeq),
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) +
      TLS13AEADTagLength(FNegotiatedCipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
    raise Exception.Create('Failed to encrypt scripted client Finished: ' + LError);

  Inc(FClientHandshakeRecordSeq);
  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  Enqueue(LRecord);
  AppendHandshakeBytes(FTranscriptData, LClientFinished);
end;

procedure TOfflineStaplingObserveClientStream.HandleServerHandshakeRecord(const AData: TBytes);
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
begin
  if not ParseTLSRecordHeader(AData, LHeader) then
    raise Exception.Create('Failed to parse encrypted server handshake record header');
  if Length(AData) < 5 + LHeader.Length then
    raise Exception.Create('Encrypted server handshake record is truncated');

  SetLength(LPayload, LHeader.Length);
  if LHeader.Length > 0 then
    Move(AData[5], LPayload[0], LHeader.Length);

  if not TryTLS13AEADDecrypt(
    FNegotiatedCipherSuite,
    FHandshakeSecrets.ServerHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ServerHandshakeIV, FServerHandshakeRecordSeq),
    BuildTLS13RecordAAD(LHeader.Length),
    LPayload,
    LPlaintext,
    LError
  ) then
    raise Exception.Create('Failed to decrypt server handshake record: ' + LError);
  Inc(FServerHandshakeRecordSeq);

  if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
    raise Exception.Create('Invalid TLSInnerPlaintext in server handshake record');
  if LInnerContentType <> TLS_CONTENT_TYPE_HANDSHAKE then
    raise Exception.Create('Server handshake record should carry handshake content');

  AppendHandshakeBytes(FPendingServerHandshakeBytes, LInnerFragment);
  LBuffer := FPendingServerHandshakeBytes;
  while TryPopHandshakeMessage(LBuffer, LMessage) do
  begin
    LType := LMessage[0];
    case LType of
      TLS_HANDSHAKE_TYPE_CERTIFICATE:
        begin
          FObservedCertificateMessage := True;
          if not TryParseTLS13ServerCertificateHandshakeInfo(
            LMessage,
            FObservedCertificateInfo,
            LError
          ) then
            raise Exception.Create('Failed to parse server Certificate message: ' + LError);
        end;
      TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY:
        FObservedCertificateVerify := True;
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
      FObservedServerFinished := True;
      SendClientFinished;
    end
    else
      AppendHandshakeBytes(FTranscriptData, LMessage);
  end;
  FPendingServerHandshakeBytes := LBuffer;
end;

procedure TOfflineStaplingObserveClientStream.HandleServerRecord(const AData: TBytes);
var
  LHeader: TTLSRecordHeader;
begin
  if not ParseTLSRecordHeader(AData, LHeader) then
    raise Exception.Create('Failed to parse TLS record header from server write');

  case LHeader.ContentType of
    TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC:
      Exit;
    TLS_CONTENT_TYPE_HANDSHAKE:
      begin
        if FHandshakeStage <> 0 then
          raise Exception.Create('Unexpected extra handshake record from server');
        HandleServerHello(AData);
        FHandshakeStage := 1;
      end;
    TLS_CONTENT_TYPE_APPLICATION_DATA:
      begin
        if FHandshakeStage = 0 then
          raise Exception.Create('Encrypted handshake flight arrived before ServerHello');
        if FHandshakeStage = 1 then
        begin
          HandleServerHandshakeRecord(AData);
          if FObservedServerFinished then
            FHandshakeStage := 2;
        end;
      end;
  else
    raise Exception.CreateFmt('Unexpected server record content type: %d',
      [LHeader.ContentType]);
  end;
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
  LRecord: TBytes;
  LOldLen: Integer;
begin
  SetLength(LData, Count);
  if Count > 0 then
    Move(Buffer, LData[0], Count);

  if Length(LData) > 0 then
  begin
    LOldLen := Length(FIncomingWriteBuffer);
    SetLength(FIncomingWriteBuffer, LOldLen + Length(LData));
    Move(LData[0], FIncomingWriteBuffer[LOldLen], Length(LData));

    while TryPopTLSRecord(FIncomingWriteBuffer, LRecord) do
      HandleServerRecord(LRecord);
  end;

  Result := Count;
end;

function TOfflineStaplingObserveClientStream.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
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
  Result := TSSLFactory.CreateContext(sslCtxServer, sslOpenSSL);
  AssertTrue(Result <> nil, 'OpenSSL server context should be created');
  Result.SetPreferredVersion(sslProtocolTLS13);
  Result.SetSessionCacheMode(False);
  Result.SetVerifyMode([]);
  Result.LoadCertificate(CERT_FILE);
  Result.LoadPrivateKey(KEY_FILE);
end;

function NewServerContextFromBuilder(const AStapledResponseFile: string = ''): ISSLContext;
var
  LBuilder: ISSLContextBuilder;
begin
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslOpenSSL)
    .WithTLS13
    .WithVerifyNone
    .WithSessionCache(False)
    .WithCertificate(CERT_FILE)
    .WithPrivateKey(KEY_FILE)
    .WithOCSPStapling(True);

  if AStapledResponseFile <> '' then
    LBuilder := LBuilder.WithServerOCSPStapledResponseFile(AStapledResponseFile);

  Result := LBuilder.BuildServer;
  AssertTrue(Result <> nil, 'Builder should create OpenSSL server context');
end;

procedure TestServerEmitsConfiguredStapledOCSPWhenRequested;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TOfflineStaplingObserveClientStream;
  LFixture: TBytes;
  LStaplingContext: ISSLServerOCSPStaplingContext;
  LStatusCallCountBefore: Integer;
begin
  LStatusCallCountBefore := GStatusOCSPRespCallCount;
  LCtx := NewServerContext;
  AssertTrue(
    Supports(LCtx, ISSLServerOCSPStaplingContext, LStaplingContext),
    'OpenSSL server context should expose public server stapling interface'
  );
  LFixture := ReadFileBytes(OCSP_FIXTURE_FILE);
  AssertTrue(Length(LFixture) > 0, 'OCSP fixture should not be empty');
  LStaplingContext.SetServerStapledOCSPResponse(LFixture);

  LStream := TOfflineStaplingObserveClientStream.Create(True);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'OpenSSL server connection should be created');
    AssertTrue(LConn.Accept,
      'OpenSSL server accept should succeed when stapled response is configured');
    AssertTrue(LStream.ObservedCertificateMessage,
      'Scripted client should observe the Certificate message');
    AssertTrue(
      GStatusOCSPRespCallCount > LStatusCallCountBefore,
      'OpenSSL server handshake should invoke SSL_set_tlsext_status_ocsp_resp when response is configured and requested'
    );
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
    'OpenSSL server context should expose public server stapling interface'
  );
  LFixture := ReadFileBytes(OCSP_FIXTURE_FILE);
  AssertTrue(Length(LFixture) > 0, 'OCSP fixture should not be empty');
  LStaplingContext.SetServerStapledOCSPResponse(LFixture);

  LStream := TOfflineStaplingObserveClientStream.Create(False);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'OpenSSL server connection should be created');
    AssertTrue(LConn.Accept,
      'OpenSSL server accept should succeed without client status_request');
    AssertTrue(LStream.ObservedCertificateMessage,
      'Scripted client should observe the Certificate message');
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
    AssertTrue(LConn <> nil, 'OpenSSL server connection should be created');
    AssertTrue(LConn.Accept,
      'OpenSSL server accept should succeed without configured stapled response');
    AssertTrue(LStream.ObservedCertificateMessage,
      'Scripted client should observe the Certificate message');
    AssertTrue(
      not LStream.ObservedCertificateInfo.HasLeafOCSPStapledResponse,
      'Server should keep CertificateEntry unchanged when stapled response is not configured'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestBuilderBuildServerWithoutStapledOCSPStillAccepts;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TOfflineStaplingObserveClientStream;
begin
  LCtx := NewServerContextFromBuilder;
  AssertTrue(
    GetOpenSSLContextStatusType(LCtx) <> TLSEXT_STATUSTYPE_ocsp,
    'Builder without stapled OCSP file should not enable OCSP status type on the native context'
  );

  LStream := TOfflineStaplingObserveClientStream.Create(True);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Builder-built server connection without stapled file should be created');
    if not LConn.Accept then
      Fail(Format(
        'Builder-built server accept should succeed without stapled response file ' +
        '(state=%s verify=%s ctx_status=%d conn_status=%d)',
        [
          {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
          LConn.GetStateString,
          {$POP}
          LConn.GetVerifyResultString,
          GetOpenSSLContextStatusType(LCtx),
          GetOpenSSLConnectionStatusType(LConn)
        ]
      ));
    AssertTrue(LStream.ObservedCertificateMessage,
      'Scripted client should observe the Certificate message for builder-built context without stapled file');
    AssertTrue(
      not LStream.ObservedCertificateInfo.HasLeafOCSPStapledResponse,
      'Builder-built context without stapled file should not emit stapled response'
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
  LStatusCallCountBefore: Integer;
begin
  LStatusCallCountBefore := GStatusOCSPRespCallCount;
  LFixtureFile := OCSP_FIXTURE_FILE;
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
  AssertTrue(
    GetOpenSSLContextStatusType(LCtx) = TLSEXT_STATUSTYPE_ocsp,
    'BuildServer should set native OpenSSL context status type when stapled OCSP response is configured'
  );

  LStream := TOfflineStaplingObserveClientStream.Create(True);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Builder-built server connection should be created');
    if not LConn.Accept then
      Fail(Format(
        'Builder-built server accept should succeed with stapled response file ' +
        '(state=%s verify=%s ctx_status=%d conn_status=%d status_call_delta=%d)',
        [
          {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
          LConn.GetStateString,
          {$POP}
          LConn.GetVerifyResultString,
          GetOpenSSLContextStatusType(LCtx),
          GetOpenSSLConnectionStatusType(LConn),
          GStatusOCSPRespCallCount - LStatusCallCountBefore
        ]
      ));
    AssertTrue(LStream.ObservedCertificateMessage,
      'Scripted client should observe the Certificate message');
    AssertTrue(
      GStatusOCSPRespCallCount > LStatusCallCountBefore,
      'Builder-driven OpenSSL server handshake should invoke SSL_set_tlsext_status_ocsp_resp when response is configured and requested'
    );
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
  WriteLn('Testing OpenSSL server OCSP stapling runtime...');

  if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
  begin
    WriteLn('SKIP: OpenSSL backend not available on this platform');
    Halt(0);
  end;

  AssertTrue(Assigned(TSSLFactory.GetLibraryInstance(sslOpenSSL)),
    'OpenSSL library instance should be available for runtime test');
  AssertTrue(TSSLFactory.GetLibraryInstance(sslOpenSSL).Initialize,
    'OpenSSL library should initialize for runtime test');
  AssertTrue(Assigned(SSL_set_tlsext_status_ocsp_resp),
    'SSL_set_tlsext_status_ocsp_resp should be available for runtime test');

  GOriginalSSLSetStatusOCSPResp := SSL_set_tlsext_status_ocsp_resp;
  SSL_set_tlsext_status_ocsp_resp := @CountingSSLSetStatusOCSPResp;
  try
    TestServerEmitsConfiguredStapledOCSPWhenRequested;
    TestServerDoesNotEmitStapledOCSPWhenClientDidNotRequestIt;
    TestServerKeepsCertificateEntryUnchangedWithoutStapledMaterial;
    TestBuilderBuildServerWithoutStapledOCSPStillAccepts;
    TestBuilderBuildServerLoadsConfiguredStapledOCSPFile;
  finally
    SSL_set_tlsext_status_ocsp_resp := GOriginalSSLSetStatusOCSPResp;
  end;

  WriteLn('PASS: OpenSSL server OCSP stapling runtime checks passed');
end.
