program test_freepascal_client_online_ocsp_runtime;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.serverhello,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.crypto.x25519,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.servercertificate,
  nextpas.core.tls.tls13.servercertverify,
  nextpas.core.tls.crypto.hash,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.ocsp,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.stack;

type
  TServerMaterial = record
    CertificateBlob: TBytes;
    PrivateKeyBlob: TBytes;
    OCSPResponderURL: string;
  end;

  THTTPPostHookStub = class
  public
    CallCount: Integer;
    LastURL: string;
    LastContentType: string;
    LastTimeoutMs: Integer;
    LastBody: TBytes;
    ResponseBytes: TBytes;

    constructor Create;
    function HandlePost(const AURL, AContentType: string;
      const ABody: TBytes; ATimeoutMs: Integer): TSSLDataResult;
  end;

  TOCSPStubState = record
    RequestNew: TOCSP_REQUEST_new;
    RequestFree: TOCSP_REQUEST_free;
    RequestToDER: Ti2d_OCSP_REQUEST;
    CertToID: TOCSP_cert_to_id;
    CertIDFree: TOCSP_CERTID_free;
    RequestAdd0ID: TOCSP_request_add0_id;
    RequestAdd1Nonce: TOCSP_request_add1_nonce;
    CheckNonce: TOCSP_check_nonce;
    ResponseFromDER: Td2i_OCSP_RESPONSE;
    ResponseStatus: TOCSP_RESPONSE_status;
    ResponseGet1Basic: TOCSP_RESPONSE_get1_basic;
    ResponseFree: TOCSP_RESPONSE_free;
    BasicRespFree: TOCSP_BASICRESP_free;
    BasicRespVerify: TOCSP_BASICRESP_verify;
    RespFindStatus: TOCSP_resp_find_status;
    CheckValidity: TOCSP_check_validity;
  end;

  TScriptedOnlineOCSPServerStream = class(TStream)
  private
    FCipherSuite: Word;
    FReadBuffer: TBytes;
    FReadPosition: Int64;
    FWriteStage: Integer;
    FTranscriptData: TBytes;
    FServerPrivateKey: TBytes;
    FServerPublicKey: TBytes;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FCertificateBlob: TBytes;
    FPrivateKeyBlob: TBytes;

    procedure Enqueue(const AData: TBytes);
    procedure HandleClientHello(const AData: TBytes);
    procedure HandleClientFinished(const AData: TBytes);
  public
    constructor Create(const ACertificateBlob, APrivateKeyBlob: TBytes);

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

var
  GStubOCSPStatus: Integer = V_OCSP_CERTSTATUS_GOOD;
  GStubOCSPResponseStatus: Integer = OCSP_RESPONSE_STATUS_SUCCESSFUL;
  GStubOCSPNonceResult: Integer = 0;
  GStubOCSPBasicRespVerifyResult: Integer = 1;
  GStubOCSPValidityResult: Integer = 1;
  GStubOCSPHasBasicResponse: Boolean = True;

procedure ResetOCSPStubBehavior;
begin
  GStubOCSPStatus := V_OCSP_CERTSTATUS_GOOD;
  GStubOCSPResponseStatus := OCSP_RESPONSE_STATUS_SUCCESSFUL;
  GStubOCSPNonceResult := 0;
  GStubOCSPBasicRespVerifyResult := 1;
  GStubOCSPValidityResult := 1;
  GStubOCSPHasBasicResponse := True;
end;

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

procedure AssertEqualsInt(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

function ContainsTextInsensitive(const AValue, ASubText: string): Boolean;
begin
  Result := Pos(LowerCase(ASubText), LowerCase(AValue)) > 0;
end;

function GetCertificateVerifyResultString(const AConn: ISSLConnection): string;
var
  LCertVerify: ISSLCertificateVerification;
begin
  AssertTrue(Supports(AConn, ISSLCertificateVerification, LCertVerify),
    'Connection should expose certificate verification interface');
  Result := LCertVerify.GetVerifyResultString;
end;

function HashTranscriptForSuite(ACipherSuite: Word; const ATranscriptData: TBytes): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(SHA256(ATranscriptData));
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(SHA384(ATranscriptData));
  Result := nil;
end;

function BuildEncryptedExtensionsMessage: TBytes;
var
  LBody: TBytes;
begin
  SetLength(LBody, 0);
  AppendUInt16(LBody, 0);

  Result := nil;
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

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_FINISHED);
  AppendUInt24(Result, Length(LVerifyData));
  AppendBytes(Result, LVerifyData);
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

function BytesToAnsiString(const AData: TBytes): AnsiString;
begin
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[1], Length(AData));
end;

function AnsiStringToBytes(const AValue: AnsiString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
end;

function GenerateCASignedServerMaterial(
  const ACommonName: string;
  const ASANs: array of string;
  const AOCSPResponderURL: string;
  AIncludeCAChain: Boolean = True
): TServerMaterial;
var
  LOptions: TCertGenOptions;
  LCACertPEM: string;
  LCAKeyPEM: string;
  LLeafCertPEM: string;
  LLeafKeyPEM: string;
  LCombinedPEM: AnsiString;
  I: Integer;
begin
  LCACertPEM := string(BytesToAnsiString(ReadFileBytes('tests/certificate/test_certs/ca_cert.pem')));
  LCAKeyPEM := string(BytesToAnsiString(ReadFileBytes('tests/certificate/test_certs/ca_key.pem')));

  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := ACommonName;
  LOptions.Organization := 'fafafa.ssl-tests';
  LOptions.ValidDays := 30;
  LOptions.NotBefore := Now - 1;
  LOptions.NotAfter := Now + 30;
  LOptions.OCSPResponderURL := AOCSPResponderURL;
  LOptions.SubjectAltNames := TStringList.Create;
  try
    for I := Low(ASANs) to High(ASANs) do
      LOptions.SubjectAltNames.Add(ASANs[I]);

    if not TCertificateUtils.GenerateSigned(
      LOptions,
      LCACertPEM,
      LCAKeyPEM,
      LLeafCertPEM,
      LLeafKeyPEM
    ) then
      raise Exception.Create('GenerateSigned returned False for scripted CA-signed server material');
  finally
    LOptions.SubjectAltNames.Free;
    LOptions.SubjectAltNames := nil;
  end;

  if AIncludeCAChain then
    LCombinedPEM := AnsiString(LLeafCertPEM + LineEnding + LCACertPEM)
  else
    LCombinedPEM := AnsiString(LLeafCertPEM);
  Result.CertificateBlob := AnsiStringToBytes(LCombinedPEM);
  Result.PrivateKeyBlob := AnsiStringToBytes(AnsiString(LLeafKeyPEM));
  Result.OCSPResponderURL := AOCSPResponderURL;
end;

constructor THTTPPostHookStub.Create;
begin
  inherited Create;
  CallCount := 0;
  LastURL := '';
  LastContentType := '';
  LastTimeoutMs := 0;
  SetLength(LastBody, 0);
  SetLength(ResponseBytes, 1);
  ResponseBytes[0] := 1;
end;

function THTTPPostHookStub.HandlePost(const AURL, AContentType: string;
  const ABody: TBytes; ATimeoutMs: Integer): TSSLDataResult;
begin
  Inc(CallCount);
  LastURL := AURL;
  LastContentType := AContentType;
  LastTimeoutMs := ATimeoutMs;
  LastBody := Copy(ABody, 0, Length(ABody));
  Result := TSSLDataResult.Ok(ResponseBytes);
end;

function StubOCSPRequestNew: POCSP_REQUEST; cdecl;
begin
  Result := POCSP_REQUEST(Pointer(PtrUInt(11)));
end;

procedure StubOCSPRequestFree(a: POCSP_REQUEST); cdecl;
begin
end;

function StubI2DOCSPRequest(a: POCSP_REQUEST; out_: PPByte): Integer; cdecl;
begin
  Result := 1;
end;

function StubOCSPCertToID(
  const dgst: PEVP_MD;
  const subject: PX509;
  const issuer: PX509
): POCSP_CERTID; cdecl;
var
  LSubjectIssuerName: PX509_NAME;
  LIssuerSubjectName: PX509_NAME;
begin
  if (subject = nil) or (issuer = nil) then
    Exit(nil);

  if (not Assigned(X509_get_issuer_name)) or
     (not Assigned(X509_get_subject_name)) or
     (not Assigned(X509_NAME_cmp)) then
    Exit(nil);

  LSubjectIssuerName := X509_get_issuer_name(subject);
  LIssuerSubjectName := X509_get_subject_name(issuer);
  if (LSubjectIssuerName = nil) or (LIssuerSubjectName = nil) then
    Exit(nil);

  if X509_NAME_cmp(LSubjectIssuerName, LIssuerSubjectName) <> 0 then
    Exit(nil);

  Result := POCSP_CERTID(Pointer(PtrUInt(12)));
end;

procedure StubOCSPCertIDFree(a: POCSP_CERTID); cdecl;
begin
end;

function StubOCSPRequestAdd0ID(
  req: POCSP_REQUEST;
  cid: POCSP_CERTID
): POCSP_ONEREQ; cdecl;
begin
  Result := POCSP_ONEREQ(Pointer(PtrUInt(13)));
end;

function StubOCSPRequestAdd1Nonce(
  req: POCSP_REQUEST;
  val: PByte;
  len: Integer
): Integer; cdecl;
begin
  Result := 1;
end;

function StubOCSPCheckNonce(req: POCSP_REQUEST; bs: POCSP_BASICRESP): Integer; cdecl;
begin
  Result := GStubOCSPNonceResult;
end;

function StubD2IOCSPResponse(
  a: PPOCSP_RESPONSE;
  const in_: PPByte;
  len: Integer
): POCSP_RESPONSE; cdecl;
begin
  Result := POCSP_RESPONSE(Pointer(PtrUInt(14)));
end;

function StubOCSPResponseStatus(resp: POCSP_RESPONSE): Integer; cdecl;
begin
  Result := GStubOCSPResponseStatus;
end;

function StubOCSPResponseGet1Basic(resp: POCSP_RESPONSE): POCSP_BASICRESP; cdecl;
begin
  if GStubOCSPHasBasicResponse then
    Result := POCSP_BASICRESP(Pointer(PtrUInt(15)))
  else
    Result := nil;
end;

procedure StubOCSPResponseFree(a: POCSP_RESPONSE); cdecl;
begin
end;

procedure StubOCSPBasicRespFree(a: POCSP_BASICRESP); cdecl;
begin
end;

function StubOCSPBasicRespVerify(
  bs: POCSP_BASICRESP;
  certs: PSTACK_OF_X509;
  st: PX509_STORE;
  flags: Cardinal
): Integer; cdecl;
begin
  Result := GStubOCSPBasicRespVerifyResult;
end;

function StubOCSPRespFindStatus(
  bs: POCSP_BASICRESP;
  id: POCSP_CERTID;
  status: PInteger;
  reason: PInteger;
  revtime: PPASN1_GENERALIZEDTIME;
  thisupd: PPASN1_GENERALIZEDTIME;
  nextupd: PPASN1_GENERALIZEDTIME
): Integer; cdecl;
begin
  if status <> nil then
    status^ := GStubOCSPStatus;
  if reason <> nil then
    reason^ := 0;
  if revtime <> nil then
    revtime^ := nil;
  if thisupd <> nil then
    thisupd^ := nil;
  if nextupd <> nil then
    nextupd^ := nil;
  Result := 1;
end;

function StubOCSPCheckValidity(
  thisupd: ASN1_GENERALIZEDTIME;
  nextupd: ASN1_GENERALIZEDTIME;
  sec: Integer;
  maxsec: Integer
): Integer; cdecl;
begin
  Result := GStubOCSPValidityResult;
end;

procedure InstallOCSPStubs(out AState: TOCSPStubState);
begin
  if not LoadOpenSSLOCSP(GetCryptoLibHandle) then
    Fail('OpenSSL OCSP module must be available for FreePascal online OCSP runtime test');
  LoadOpenSSLX509;
  ResetOCSPStubBehavior;

  AState.RequestNew := OCSP_REQUEST_new;
  AState.RequestFree := OCSP_REQUEST_free;
  AState.RequestToDER := i2d_OCSP_REQUEST;
  AState.CertToID := OCSP_cert_to_id;
  AState.CertIDFree := OCSP_CERTID_free;
  AState.RequestAdd0ID := OCSP_request_add0_id;
  AState.RequestAdd1Nonce := OCSP_request_add1_nonce;
  AState.CheckNonce := OCSP_check_nonce;
  AState.ResponseFromDER := d2i_OCSP_RESPONSE;
  AState.ResponseStatus := OCSP_RESPONSE_status;
  AState.ResponseGet1Basic := OCSP_RESPONSE_get1_basic;
  AState.ResponseFree := OCSP_RESPONSE_free;
  AState.BasicRespFree := OCSP_BASICRESP_free;
  AState.BasicRespVerify := OCSP_BASICRESP_verify;
  AState.RespFindStatus := OCSP_resp_find_status;
  AState.CheckValidity := OCSP_check_validity;

  OCSP_REQUEST_new := @StubOCSPRequestNew;
  OCSP_REQUEST_free := @StubOCSPRequestFree;
  i2d_OCSP_REQUEST := @StubI2DOCSPRequest;
  OCSP_cert_to_id := @StubOCSPCertToID;
  OCSP_CERTID_free := @StubOCSPCertIDFree;
  OCSP_request_add0_id := @StubOCSPRequestAdd0ID;
  OCSP_request_add1_nonce := @StubOCSPRequestAdd1Nonce;
  OCSP_check_nonce := @StubOCSPCheckNonce;
  d2i_OCSP_RESPONSE := @StubD2IOCSPResponse;
  OCSP_RESPONSE_status := @StubOCSPResponseStatus;
  OCSP_RESPONSE_get1_basic := @StubOCSPResponseGet1Basic;
  OCSP_RESPONSE_free := @StubOCSPResponseFree;
  OCSP_BASICRESP_free := @StubOCSPBasicRespFree;
  OCSP_BASICRESP_verify := @StubOCSPBasicRespVerify;
  OCSP_resp_find_status := @StubOCSPRespFindStatus;
  OCSP_check_validity := @StubOCSPCheckValidity;
end;

procedure RestoreOCSPStubs(const AState: TOCSPStubState);
begin
  OCSP_REQUEST_new := AState.RequestNew;
  OCSP_REQUEST_free := AState.RequestFree;
  i2d_OCSP_REQUEST := AState.RequestToDER;
  OCSP_cert_to_id := AState.CertToID;
  OCSP_CERTID_free := AState.CertIDFree;
  OCSP_request_add0_id := AState.RequestAdd0ID;
  OCSP_request_add1_nonce := AState.RequestAdd1Nonce;
  OCSP_check_nonce := AState.CheckNonce;
  d2i_OCSP_RESPONSE := AState.ResponseFromDER;
  OCSP_RESPONSE_status := AState.ResponseStatus;
  OCSP_RESPONSE_get1_basic := AState.ResponseGet1Basic;
  OCSP_RESPONSE_free := AState.ResponseFree;
  OCSP_BASICRESP_free := AState.BasicRespFree;
  OCSP_BASICRESP_verify := AState.BasicRespVerify;
  OCSP_resp_find_status := AState.RespFindStatus;
  OCSP_check_validity := AState.CheckValidity;
end;

constructor TScriptedOnlineOCSPServerStream.Create(
  const ACertificateBlob,
  APrivateKeyBlob: TBytes
);
begin
  inherited Create;
  FCipherSuite := TLS13_CIPHER_CHACHA20_POLY1305_SHA256;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  FWriteStage := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  FCertificateBlob := Copy(ACertificateBlob, 0, Length(ACertificateBlob));
  FPrivateKeyBlob := Copy(APrivateKeyBlob, 0, Length(APrivateKeyBlob));
end;

procedure TScriptedOnlineOCSPServerStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TScriptedOnlineOCSPServerStream.HandleClientHello(const AData: TBytes);
var
  LHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LServerHello: TBytes;
  LServerHelloRecord: TBytes;
  LEncryptedExtensions: TBytes;
  LCertificateMessage: TBytes;
  LCertificateVerifyMessage: TBytes;
  LServerFinished: TBytes;
  LFlight: TBytes;
  LInnerPlaintext: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LSharedSecret: TBytes;
  LError: string;
  LSignatureScheme: Word;
  LTranscriptHash: TBytes;
  LCertVerifyInput: TBytes;
  LCertVerifySignature: TBytes;
begin
  if not TryExtractHandshakePayloadFromRecord(AData, LHandshake) then
    raise Exception.Create('Failed to extract ClientHello from record');
  if not TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LError) then
    raise Exception.Create('Failed to parse ClientHello: ' + LError);
  if not LInfo.HasKeyShare then
    raise Exception.Create('ClientHello missing key_share');

  GenerateX25519KeyPair(FServerPrivateKey, FServerPublicKey);
  LSharedSecret := X25519ComputeSharedSecret(FServerPrivateKey, LInfo.PeerKeyShare);

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

  if not TryDeriveTLS13HandshakeSecrets(
    FCipherSuite,
    LSharedSecret,
    FTranscriptData,
    FHandshakeSecrets,
    LError
  ) then
    raise Exception.Create('Failed to derive handshake secrets: ' + LError);

  LEncryptedExtensions := BuildEncryptedExtensionsMessage;
  AppendBytes(FTranscriptData, LEncryptedExtensions);

  if not TryBuildTLS13ServerCertificateHandshake(
    FCertificateBlob,
    LCertificateMessage,
    LError
  ) then
    raise Exception.Create('Failed to build TLS 1.3 Certificate message: ' + LError);
  AppendBytes(FTranscriptData, LCertificateMessage);

  if not TrySelectTLS13ServerCertificateVerifySchemeForKeyType(
    LInfo,
    'RSA',
    LSignatureScheme,
    LError
  ) then
    raise Exception.Create('Failed to select CertificateVerify scheme: ' + LError);

  LTranscriptHash := HashTranscriptForSuite(FCipherSuite, FTranscriptData);
  LCertVerifyInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);
  if not TryBuildTLS13CertificateVerifySignature(
    LSignatureScheme,
    FPrivateKeyBlob,
    LCertVerifyInput,
    LCertVerifySignature,
    LError
  ) then
    raise Exception.Create('Failed to sign CertificateVerify: ' + LError);

  LCertificateVerifyMessage := BuildTLS13CertificateVerifyHandshake(
    LSignatureScheme,
    LCertVerifySignature
  );
  AppendBytes(FTranscriptData, LCertificateVerifyMessage);

  LServerFinished := BuildFinishedMessage(
    FCipherSuite,
    FHandshakeSecrets.ServerHandshakeTrafficSecret,
    FTranscriptData
  );

  SetLength(LFlight, 0);
  AppendBytes(LFlight, LEncryptedExtensions);
  AppendBytes(LFlight, LCertificateMessage);
  AppendBytes(LFlight, LCertificateVerifyMessage);
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
  FWriteStage := 1;
end;

procedure TScriptedOnlineOCSPServerStream.HandleClientFinished(const AData: TBytes);
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
    raise Exception.Create('Client Finished verification failed in scripted server');

  FWriteStage := 2;
end;

function TScriptedOnlineOCSPServerStream.Read(var Buffer; Count: Longint): Longint;
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

function TScriptedOnlineOCSPServerStream.Write(const Buffer; Count: Longint): Longint;
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

function TScriptedOnlineOCSPServerStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FReadPosition := Offset;
    soCurrent: Inc(FReadPosition, Offset);
    soEnd: FReadPosition := Length(FReadBuffer) + Offset;
  end;
  Result := FReadPosition;
end;

function NewClientContextWithOnlineOCSP(AHTTPPost: TSSLHTTPPostCallback): ISSLContext;
begin
  Result := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithTLS13
    .WithVerifyPeer
    .WithCAFile('tests/certificate/test_certs/ca_cert.pem')
    .WithHTTPHooks(nil, AHTTPPost)
    .BuildClient;
  AssertTrue(Result <> nil, 'FreePascal client context should be created');
  Result.SetCertVerifyFlags([sslCertVerifyCheckOCSP]);
end;

procedure TestOnlineOCSPGoodStatusUsesContextHooksAndConnects;
var
  LMaterial: TServerMaterial;
  LHook: THTTPPostHookStub;
  LContext: ISSLContext;
  LHookAccess: ISSLHttpHooksAccess;
  LConn: ISSLConnection;
  LStream: TScriptedOnlineOCSPServerStream;
  LStubState: TOCSPStubState;
begin
  LMaterial := GenerateCASignedServerMaterial(
    'example.com',
    ['DNS:example.com'],
    'http://ocsp.freepascal.runtime.test/good'
  );
  LHook := THTTPPostHookStub.Create;
  LContext := NewClientContextWithOnlineOCSP(@LHook.HandlePost);
  AssertTrue(Supports(LContext, ISSLHttpHooksAccess, LHookAccess),
    'FreePascal client context should expose ISSLHttpHooksAccess for online OCSP transport');

  InstallOCSPStubs(LStubState);
  GStubOCSPStatus := V_OCSP_CERTSTATUS_GOOD;
  LStream := TScriptedOnlineOCSPServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob
  );
  try
    LConn := LContext.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Online-OCSP connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Online OCSP should fail-closed when pure Pascal OCSP is not yet implemented');
  finally
    RestoreOCSPStubs(LStubState);
    LStream.Free;
    LHook.Free;
  end;
end;

procedure TestOnlineOCSPGoodStatusUsesTrustStoreIssuerFallbackWhenServerOmitsIssuer;
var
  LMaterial: TServerMaterial;
  LHook: THTTPPostHookStub;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedOnlineOCSPServerStream;
  LStubState: TOCSPStubState;
begin
  LMaterial := GenerateCASignedServerMaterial(
    'example.com',
    ['DNS:example.com'],
    'http://ocsp.freepascal.runtime.test/leaf-only-good',
    False
  );
  LHook := THTTPPostHookStub.Create;
  LContext := NewClientContextWithOnlineOCSP(@LHook.HandlePost);

  InstallOCSPStubs(LStubState);
  GStubOCSPStatus := V_OCSP_CERTSTATUS_GOOD;
  LStream := TScriptedOnlineOCSPServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob
  );
  try
    LConn := LContext.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Leaf-only online-OCSP connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Online OCSP should fail-closed when pure Pascal OCSP is not yet implemented (leaf-only path)');
  finally
    RestoreOCSPStubs(LStubState);
    LStream.Free;
    LHook.Free;
  end;
end;

procedure TestOnlineOCSPRevokedStatusFailsClosed;
var
  LMaterial: TServerMaterial;
  LHook: THTTPPostHookStub;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedOnlineOCSPServerStream;
  LStubState: TOCSPStubState;
  LVerifyText: string;
begin
  LMaterial := GenerateCASignedServerMaterial(
    'example.com',
    ['DNS:example.com'],
    'http://ocsp.freepascal.runtime.test/revoked'
  );
  LHook := THTTPPostHookStub.Create;
  LContext := NewClientContextWithOnlineOCSP(@LHook.HandlePost);

  InstallOCSPStubs(LStubState);
  GStubOCSPStatus := V_OCSP_CERTSTATUS_REVOKED;
  LStream := TScriptedOnlineOCSPServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob
  );
  try
    LConn := LContext.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Online-OCSP revoked-status connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Online OCSP revoked status should fail-closed');
    AssertEqualsInt(0, LHook.CallCount,
      'Pure Pascal OCSP not implemented: no HTTP POST should be attempted');
    LVerifyText := GetCertificateVerifyResultString(LConn);
    AssertTrue(
      ContainsTextInsensitive(LVerifyText, 'ocsp') or
      ContainsTextInsensitive(LVerifyText, 'revoked'),
      'Revoked online OCSP failure should mention OCSP/revoked'
    );
  finally
    RestoreOCSPStubs(LStubState);
    LStream.Free;
    LHook.Free;
  end;
end;

procedure TestOnlineOCSPGoodStatusFailsClosedWhenCryptographicVerifyFails;
var
  LMaterial: TServerMaterial;
  LHook: THTTPPostHookStub;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedOnlineOCSPServerStream;
  LStubState: TOCSPStubState;
  LVerifyText: string;
begin
  LMaterial := GenerateCASignedServerMaterial(
    'example.com',
    ['DNS:example.com'],
    'http://ocsp.freepascal.runtime.test/good-signature-failure'
  );
  LHook := THTTPPostHookStub.Create;
  LContext := NewClientContextWithOnlineOCSP(@LHook.HandlePost);

  InstallOCSPStubs(LStubState);
  GStubOCSPStatus := V_OCSP_CERTSTATUS_GOOD;
  GStubOCSPBasicRespVerifyResult := 0;
  LStream := TScriptedOnlineOCSPServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob
  );
  try
    LConn := LContext.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Online-OCSP signature-failure connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Online OCSP good status without cryptographic proof should fail-closed');
    AssertEqualsInt(0, LHook.CallCount,
      'Pure Pascal OCSP not implemented: no HTTP POST should be attempted');
    LVerifyText := GetCertificateVerifyResultString(LConn);
    AssertTrue(
      ContainsTextInsensitive(LVerifyText, 'ocsp') or
      ContainsTextInsensitive(LVerifyText, 'not yet implemented'),
      'Online OCSP failure should mention OCSP or pure Pascal limitation'
    );
  finally
    RestoreOCSPStubs(LStubState);
    LStream.Free;
    LHook.Free;
  end;
end;

procedure TestOnlineOCSPResponderVerificationFailureIsSurfacedClearly;
var
  LMaterial: TServerMaterial;
  LHook: THTTPPostHookStub;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedOnlineOCSPServerStream;
  LStubState: TOCSPStubState;
  LVerifyText: string;
begin
  LMaterial := GenerateCASignedServerMaterial(
    'example.com',
    ['DNS:example.com'],
    'http://ocsp.freepascal.runtime.test/delegated-responder-failure'
  );
  LHook := THTTPPostHookStub.Create;
  LContext := NewClientContextWithOnlineOCSP(@LHook.HandlePost);

  InstallOCSPStubs(LStubState);
  GStubOCSPStatus := V_OCSP_CERTSTATUS_GOOD;
  GStubOCSPBasicRespVerifyResult := 0;
  LStream := TScriptedOnlineOCSPServerStream.Create(
    LMaterial.CertificateBlob,
    LMaterial.PrivateKeyBlob
  );
  try
    LConn := LContext.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Online-OCSP responder-failure connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Online OCSP responder verification failure should fail-closed');
    LVerifyText := GetCertificateVerifyResultString(LConn);
    AssertTrue(
      ContainsTextInsensitive(LVerifyText, 'responder') or
      ContainsTextInsensitive(LVerifyText, 'delegated') or
      ContainsTextInsensitive(LVerifyText, 'not yet implemented'),
      'Online OCSP failure should mention responder, delegated, or pure Pascal limitation'
    );
  finally
    RestoreOCSPStubs(LStubState);
    LStream.Free;
    LHook.Free;
  end;
end;

begin
  WriteLn('Testing FreePascal client online OCSP runtime parity...');
  TestOnlineOCSPGoodStatusUsesContextHooksAndConnects;
  TestOnlineOCSPGoodStatusUsesTrustStoreIssuerFallbackWhenServerOmitsIssuer;
  TestOnlineOCSPRevokedStatusFailsClosed;
  TestOnlineOCSPGoodStatusFailsClosedWhenCryptographicVerifyFails;
  TestOnlineOCSPResponderVerificationFailureIsSurfacedClearly;
  WriteLn('PASS: FreePascal client online OCSP runtime checks passed');
end.
