program test_wolfssl_server_ocsp_stapling_runtime;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes, ctypes, DynLibs,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.factory,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.api,
  nextpas.core.tls.wolfssl.lib,
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
  MIN_WOLFSSL_TLS13_OCSP_EMISSION_MAJOR = 5;
  MIN_WOLFSSL_TLS13_OCSP_EMISSION_MINOR = 9;
  MIN_WOLFSSL_TLS13_OCSP_EMISSION_PATCH = 1;

// INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: this backend-specific
// OCSP stapling runtime file intentionally keeps direct core verify-result
// diagnostics as server-side proof. Generic ISSLCertificateVerification
// owner-path guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

var
  GOriginalWolfSSLSetStatusOCSPResp: TwolfSSL_set_tlsext_status_ocsp_resp = nil;
  GStatusOCSPRespCallCount: Integer = 0;
  GLastWolfSSLSetStatusOCSPRespResult: PtrInt = 0;
  GSkippedEmissionScenarioCount: Integer = 0;

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

function CompareVersionTriple(AMajor, AMinor, APatch: Integer;
  BMajor, BMinor, BPatch: Integer): Integer;
begin
  if AMajor <> BMajor then
    Exit(AMajor - BMajor);
  if AMinor <> BMinor then
    Exit(AMinor - BMinor);
  Result := APatch - BPatch;
end;

function TryExtractVersionTriple(const AText: string; out AMajor, AMinor,
  APatch: Integer): Boolean;
var
  I: Integer;
  LToken: string;
  LParts: TStringList;
begin
  Result := False;
  AMajor := 0;
  AMinor := 0;
  APatch := 0;
  LToken := '';

  for I := 1 to Length(AText) do
  begin
    if AText[I] in ['0'..'9', '.'] then
      LToken := LToken + AText[I]
    else if LToken <> '' then
      Break;
  end;

  while (LToken <> '') and (LToken[Length(LToken)] = '.') do
    Delete(LToken, Length(LToken), 1);

  if LToken = '' then
    Exit;

  LParts := TStringList.Create;
  try
    LParts.StrictDelimiter := True;
    LParts.Delimiter := '.';
    LParts.DelimitedText := LToken;
    if LParts.Count < 3 then
      Exit;

    if not TryStrToInt(LParts[0], AMajor) then
      Exit;
    if not TryStrToInt(LParts[1], AMinor) then
      Exit;
    if not TryStrToInt(LParts[2], APatch) then
      Exit;
  finally
    LParts.Free;
  end;

  Result := True;
end;

function GetWolfSSLRuntimeVersionString: string;
var
  LVersionPtr: PAnsiChar;
begin
  Result := '';
  if not Assigned(wolfSSL_lib_version) then
    Exit;

  LVersionPtr := wolfSSL_lib_version();
  if LVersionPtr <> nil then
    Result := Trim(string(AnsiString(LVersionPtr)));
end;

function HostSupportsWolfSSLTLS13OCSPEmission(out AVersion,
  AReason: string): Boolean;
var
  LMajor, LMinor, LPatch: Integer;
begin
  AVersion := GetWolfSSLRuntimeVersionString;
  if AVersion = '' then
  begin
    AReason := 'wolfSSL_lib_version is unavailable on this host';
    Exit(False);
  end;

  if not TryExtractVersionTriple(AVersion, LMajor, LMinor, LPatch) then
  begin
    AReason := Format('unable to parse wolfSSL runtime version string "%s"',
      [AVersion]);
    Exit(False);
  end;

  Result := CompareVersionTriple(
    LMajor,
    LMinor,
    LPatch,
    MIN_WOLFSSL_TLS13_OCSP_EMISSION_MAJOR,
    MIN_WOLFSSL_TLS13_OCSP_EMISSION_MINOR,
    MIN_WOLFSSL_TLS13_OCSP_EMISSION_PATCH
  ) >= 0;

  if not Result then
    AReason := Format(
      'host wolfSSL %s is below %d.%d.%d; keep TLS 1.3 OCSP stapling emission proof gated until the upstream OCSP_WANT_READ fix is present',
      [
        AVersion,
        MIN_WOLFSSL_TLS13_OCSP_EMISSION_MAJOR,
        MIN_WOLFSSL_TLS13_OCSP_EMISSION_MINOR,
        MIN_WOLFSSL_TLS13_OCSP_EMISSION_PATCH
      ]
    );
end;

function SkipEmissionScenarioIfHostTooOld(const AScenarioName: string): Boolean;
var
  LVersion: string;
  LReason: string;
begin
  Result := not HostSupportsWolfSSLTLS13OCSPEmission(LVersion, LReason);
  if Result then
  begin
    Inc(GSkippedEmissionScenarioCount);
    WriteLn(Format('SKIP: %s - %s', [AScenarioName, LReason]));
  end;
end;

function CountingWolfSSLSetStatusOCSPResp(ssl: PWOLFSSL; resp: PByte;
  len: Integer): PtrInt; cdecl;
begin
  Inc(GStatusOCSPRespCallCount);
  if Assigned(GOriginalWolfSSLSetStatusOCSPResp) then
  begin
    Result := GOriginalWolfSSLSetStatusOCSPResp(ssl, resp, len);
    GLastWolfSSLSetStatusOCSPRespResult := Result;
  end
  else
  begin
    Result := 0;
    GLastWolfSSLSetStatusOCSPRespResult := Result;
  end;
end;

function GetWolfSSLConnectionStatusType(const AConn: ISSLConnection): Integer;
type
  TwolfSSL_get_tlsext_status_type_local = function(ssl: PWOLFSSL): clong; cdecl;
var
  LNativeAccess: ISSLNativeHandleAccess;
  LGetter: TwolfSSL_get_tlsext_status_type_local;
  LHandle: TLibHandle;
begin
  Result := -1;

  LHandle := GetWolfSSLLibraryHandle;
  if LHandle = NilHandle then
    Exit;

  Pointer(LGetter) := GetProcAddress(LHandle, 'wolfSSL_get_tlsext_status_type');
  if not Assigned(LGetter) then
    Exit;

  if Supports(AConn, ISSLNativeHandleAccess, LNativeAccess) and
     (LNativeAccess.GetNativeHandle <> nil) then
    Result := LGetter(PWOLFSSL(LNativeAccess.GetNativeHandle));
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
    FLastWriteError: string;
    FObservedExtraHandshakeTypes: string;
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
    property LastWriteError: string read FLastWriteError;
    property ObservedExtraHandshakeTypes: string read FObservedExtraHandshakeTypes;
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
  FLastWriteError := '';
  FObservedExtraHandshakeTypes := '';
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
  FLastWriteError := '';
  FObservedExtraHandshakeTypes := '';
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
    else
      begin
        if FObservedExtraHandshakeTypes <> '' then
          FObservedExtraHandshakeTypes := FObservedExtraHandshakeTypes + ',';
        FObservedExtraHandshakeTypes := FObservedExtraHandshakeTypes + IntToStr(LType);
      end;
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
    try
      LOldLen := Length(FIncomingWriteBuffer);
      SetLength(FIncomingWriteBuffer, LOldLen + Length(LData));
      Move(LData[0], FIncomingWriteBuffer[LOldLen], Length(LData));

      while TryPopTLSRecord(FIncomingWriteBuffer, LRecord) do
        HandleServerRecord(LRecord);
    except
      on E: Exception do
      begin
        FLastWriteError := E.ClassName + ': ' + E.Message;
        raise;
      end;
    end;
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
  Result := TSSLFactory.CreateContext(sslCtxServer, sslWolfSSL);
  AssertTrue(Result <> nil, 'WolfSSL server context should be created');
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
    .WithBackend(sslWolfSSL)
    .WithTLS13
    .WithVerifyNone
    .WithSessionCache(False)
    .WithCertificate(CERT_FILE)
    .WithPrivateKey(KEY_FILE)
    .WithOCSPStapling(True);

  if AStapledResponseFile <> '' then
    LBuilder := LBuilder.WithServerOCSPStapledResponseFile(AStapledResponseFile);

  Result := LBuilder.BuildServer;
  AssertTrue(Result <> nil, 'Builder should create WolfSSL server context');
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
  if SkipEmissionScenarioIfHostTooOld(
    'WolfSSL direct configured stapled OCSP emission') then
    Exit;

  LStatusCallCountBefore := GStatusOCSPRespCallCount;
  LCtx := NewServerContext;
  AssertTrue(
    Supports(LCtx, ISSLServerOCSPStaplingContext, LStaplingContext),
    'WolfSSL server context should expose public server stapling interface'
  );
  LFixture := ReadFileBytes(OCSP_FIXTURE_FILE);
  AssertTrue(Length(LFixture) > 0, 'OCSP fixture should not be empty');
  LStaplingContext.SetServerStapledOCSPResponse(LFixture);

  LStream := TOfflineStaplingObserveClientStream.Create(True);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'WolfSSL server connection should be created');
    if not LConn.Accept then
      Fail(Format(
        'WolfSSL server accept should succeed when stapled response is configured ' +
        '(state=%s verify=%d/%s conn_status=%d status_call_delta=%d last_set_resp_result=%d)',
        [
          {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
          LConn.GetStateString,
          {$POP}
          LConn.GetVerifyResult,
          LConn.GetVerifyResultString,
          GetWolfSSLConnectionStatusType(LConn),
          GStatusOCSPRespCallCount - LStatusCallCountBefore,
          GLastWolfSSLSetStatusOCSPRespResult
        ]
      ));
    AssertTrue(LStream.ObservedCertificateMessage,
      'Scripted client should observe the Certificate message');
    if not (GStatusOCSPRespCallCount > LStatusCallCountBefore) then
      Fail(Format(
        'WolfSSL server handshake should invoke wolfSSL_set_tlsext_status_ocsp_resp when response is configured and requested ' +
        '(conn_status=%d status_call_delta=%d observed_leaf_stapled=%s extra_handshakes=%s)',
        [
          GetWolfSSLConnectionStatusType(LConn),
          GStatusOCSPRespCallCount - LStatusCallCountBefore,
          BoolToStr(LStream.ObservedCertificateInfo.HasLeafOCSPStapledResponse, True),
          LStream.ObservedExtraHandshakeTypes
        ]
      ));
    if not LStream.ObservedCertificateInfo.HasLeafOCSPStapledResponse then
      Fail(Format(
        'Configured stapled response should be emitted on the leaf CertificateEntry when requested ' +
        '(extra_handshakes=%s)',
        [LStream.ObservedExtraHandshakeTypes]
      ));
    AssertBytesEqual(
      LFixture,
      LStream.ObservedCertificateInfo.LeafOCSPStapledResponse,
      'Emitted stapled response bytes should match configured material'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestServerAcceptsWithoutOCSPConfigurationOrRequest;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TOfflineStaplingObserveClientStream;
begin
  LCtx := NewServerContext;
  LStream := TOfflineStaplingObserveClientStream.Create(False);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'WolfSSL server connection without OCSP should be created');
    if not LConn.Accept then
      Fail(Format(
        'WolfSSL server accept should succeed without OCSP configuration or request ' +
        '(state=%s verify=%d/%s want_read=%s want_write=%s stream_error=%s)',
        [
          {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
          LConn.GetStateString,
          {$POP}
          LConn.GetVerifyResult,
          LConn.GetVerifyResultString,
          BoolToStr(LConn.WantRead, True),
          BoolToStr(LConn.WantWrite, True),
          LStream.LastWriteError
        ]
      ));
    AssertTrue(LStream.ObservedCertificateMessage,
      'Scripted client should observe the Certificate message for baseline WolfSSL stream handshake');
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
    'WolfSSL server context should expose public server stapling interface'
  );
  LFixture := ReadFileBytes(OCSP_FIXTURE_FILE);
  AssertTrue(Length(LFixture) > 0, 'OCSP fixture should not be empty');
  LStaplingContext.SetServerStapledOCSPResponse(LFixture);

  LStream := TOfflineStaplingObserveClientStream.Create(False);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'WolfSSL server connection should be created');
    if not LConn.Accept then
      Fail(Format(
        'WolfSSL server accept should succeed without client status_request ' +
        '(state=%s verify=%d/%s want_read=%s want_write=%s stream_error=%s)',
        [
          {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
          LConn.GetStateString,
          {$POP}
          LConn.GetVerifyResult,
          LConn.GetVerifyResultString,
          BoolToStr(LConn.WantRead, True),
          BoolToStr(LConn.WantWrite, True),
          LStream.LastWriteError
        ]
      ));
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
    AssertTrue(LConn <> nil, 'WolfSSL server connection should be created');
    if not LConn.Accept then
      Fail(Format(
        'WolfSSL server accept should succeed without configured stapled response ' +
        '(state=%s verify=%d/%s want_read=%s want_write=%s stream_error=%s)',
        [
          {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
          LConn.GetStateString,
          {$POP}
          LConn.GetVerifyResult,
          LConn.GetVerifyResultString,
          BoolToStr(LConn.WantRead, True),
          BoolToStr(LConn.WantWrite, True),
          LStream.LastWriteError
        ]
      ));
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

  LStream := TOfflineStaplingObserveClientStream.Create(True);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Builder-built WolfSSL server connection without stapled file should be created');
    if not LConn.Accept then
      Fail(Format(
        'Builder-built WolfSSL server accept should succeed without stapled response file ' +
        '(state=%s verify=%d/%s conn_status=%d)',
        [
          {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
          LConn.GetStateString,
          {$POP}
          LConn.GetVerifyResult,
          LConn.GetVerifyResultString,
          GetWolfSSLConnectionStatusType(LConn)
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
  if SkipEmissionScenarioIfHostTooOld(
    'WolfSSL builder configured stapled OCSP emission') then
    Exit;

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

  LStream := TOfflineStaplingObserveClientStream.Create(True);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Builder-built WolfSSL server connection should be created');
    if not LConn.Accept then
      Fail(Format(
        'Builder-built WolfSSL server accept should succeed with stapled response file ' +
        '(state=%s verify=%d/%s conn_status=%d status_call_delta=%d)',
        [
          {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
          LConn.GetStateString,
          {$POP}
          LConn.GetVerifyResult,
          LConn.GetVerifyResultString,
          GetWolfSSLConnectionStatusType(LConn),
          GStatusOCSPRespCallCount - LStatusCallCountBefore
        ]
      ));
    AssertTrue(LStream.ObservedCertificateMessage,
      'Scripted client should observe the Certificate message');
    if not (GStatusOCSPRespCallCount > LStatusCallCountBefore) then
      Fail(Format(
        'Builder-driven WolfSSL server handshake should invoke wolfSSL_set_tlsext_status_ocsp_resp when response is configured and requested ' +
        '(conn_status=%d status_call_delta=%d observed_leaf_stapled=%s extra_handshakes=%s)',
        [
          GetWolfSSLConnectionStatusType(LConn),
          GStatusOCSPRespCallCount - LStatusCallCountBefore,
          BoolToStr(LStream.ObservedCertificateInfo.HasLeafOCSPStapledResponse, True),
          LStream.ObservedExtraHandshakeTypes
        ]
      ));
    if not LStream.ObservedCertificateInfo.HasLeafOCSPStapledResponse then
      Fail(Format(
        'Builder-driven server context should emit stapled response when requested ' +
        '(extra_handshakes=%s)',
        [LStream.ObservedExtraHandshakeTypes]
      ));
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
  WriteLn('Testing WolfSSL server OCSP stapling runtime...');

  if not TSSLFactory.IsLibraryAvailable(sslWolfSSL) then
  begin
    WriteLn('SKIP: WolfSSL backend not available on this platform');
    Halt(0);
  end;

  AssertTrue(Assigned(TSSLFactory.GetLibraryInstance(sslWolfSSL)),
    'WolfSSL library instance should be available for runtime test');
  AssertTrue(TSSLFactory.GetLibraryInstance(sslWolfSSL).Initialize,
    'WolfSSL library should initialize for runtime test');
  if GetWolfSSLRuntimeVersionString <> '' then
    WriteLn('Host wolfSSL version: ', GetWolfSSLRuntimeVersionString);
  AssertTrue(Assigned(wolfSSL_set_tlsext_status_ocsp_resp),
    'wolfSSL_set_tlsext_status_ocsp_resp should be available for runtime test');

  GOriginalWolfSSLSetStatusOCSPResp := wolfSSL_set_tlsext_status_ocsp_resp;
  wolfSSL_set_tlsext_status_ocsp_resp := @CountingWolfSSLSetStatusOCSPResp;
  try
    TestServerAcceptsWithoutOCSPConfigurationOrRequest;
    TestServerDoesNotEmitStapledOCSPWhenClientDidNotRequestIt;
    TestServerKeepsCertificateEntryUnchangedWithoutStapledMaterial;
    TestServerEmitsConfiguredStapledOCSPWhenRequested;
    TestBuilderBuildServerWithoutStapledOCSPStillAccepts;
    TestBuilderBuildServerLoadsConfiguredStapledOCSPFile;
  finally
    wolfSSL_set_tlsext_status_ocsp_resp := GOriginalWolfSSLSetStatusOCSPResp;
  end;

  if GSkippedEmissionScenarioCount > 0 then
    WriteLn(Format(
      'PASS: WolfSSL server OCSP stapling runtime baseline checks passed (%d emission scenario(s) skipped)',
      [GSkippedEmissionScenarioCount]
    ))
  else
    WriteLn('PASS: WolfSSL server OCSP stapling runtime checks passed');
end.
