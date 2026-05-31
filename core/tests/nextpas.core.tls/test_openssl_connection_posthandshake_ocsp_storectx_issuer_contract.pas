program test_openssl_connection_posthandshake_ocsp_storectx_issuer_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes, ctypes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.ocsp,
  nextpas.core.tls.x509,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.native_handle,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.ocsp,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.obj,
  nextpas.core.tls.openssl.certificate,
  nextpas.core.tls.openssl.connection;

type
  TOpenSSLConnectionPostHandshakeAccess = class(TOpenSSLConnection)
  private
    FStubPeerCertificate: ISSLCertificate;
  protected
    function DoGetPeerCertificate: ISSLCertificate; override;
  public
    procedure SetStubPeerCertificate(ACert: ISSLCertificate);
  end;

  THTTPPostHookStub = class
  public
    function HandlePost(const AURL, AContentType: string;
      const ABody: TBytes; ATimeoutMs: Integer): TSSLDataResult;
  end;

var
  GLib: ISSLLibrary = nil;
  GLeafCert: ISSLCertificate = nil;
  GIssuerCert: ISSLCertificate = nil;
  GIssuerX509: PX509 = nil;
  GStoreCtxChain: nextpas.core.tls.openssl.base.PSTACK_OF_X509 = nil;
  GStoreCtxFreed: Boolean = False;
  GObservedReleasedBorrowedIssuerUse: Boolean = False;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;

function TOpenSSLConnectionPostHandshakeAccess.DoGetPeerCertificate: ISSLCertificate;
begin
  Result := FStubPeerCertificate;
end;

procedure TOpenSSLConnectionPostHandshakeAccess.SetStubPeerCertificate(ACert: ISSLCertificate);
begin
  FStubPeerCertificate := ACert;
end;

function THTTPPostHookStub.HandlePost(const AURL, AContentType: string;
  const ABody: TBytes; ATimeoutMs: Integer): TSSLDataResult;
var
  LResponse: TBytes;
begin
  SetLength(LResponse, 1);
  LResponse[0] := 1;
  Result := TSSLDataResult.Ok(LResponse);
end;

procedure AssertTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

procedure MarkSkip(const AName, AReason: string);
begin
  Inc(TotalTests);
  Inc(SkippedTests);
  WriteLn('[SKIP] [capability] ', AName, ' - ', AReason);
end;

function StubSSLConnectSuccess(ssl: PSSL): Integer; cdecl;
begin
  Result := 1;
end;

function StubSSLGetVerifyResultOK(const ssl: PSSL): clong; cdecl;
begin
  Result := X509_V_OK;
end;

function StubSSLCTXGetCertStore(const ctx: PSSL_CTX): PX509_STORE; cdecl;
begin
  Result := PX509_STORE(Pointer(PtrUInt(4)));
end;

function StubOCSPRequestNew: POCSP_REQUEST; cdecl;
begin
  Result := POCSP_REQUEST(Pointer(PtrUInt(5)));
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
begin
  Result := POCSP_CERTID(Pointer(PtrUInt(6)));
end;

function StubOCSPRequestAdd0ID(
  req: POCSP_REQUEST;
  cid: POCSP_CERTID
): POCSP_ONEREQ; cdecl;
begin
  Result := POCSP_ONEREQ(Pointer(PtrUInt(7)));
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
  Result := 0;
end;

function StubD2IOCSPResponse(
  a: PPOCSP_RESPONSE;
  const in_: PPByte;
  len: Integer
): POCSP_RESPONSE; cdecl;
begin
  Result := POCSP_RESPONSE(Pointer(PtrUInt(1)));
end;

function StubOCSPResponseStatus(resp: POCSP_RESPONSE): Integer; cdecl;
begin
  Result := OCSP_RESPONSE_STATUS_SUCCESSFUL;
end;

function StubOCSPResponseGet1Basic(resp: POCSP_RESPONSE): POCSP_BASICRESP; cdecl;
begin
  Result := POCSP_BASICRESP(Pointer(PtrUInt(2)));
end;

procedure StubOCSPResponseFree(a: POCSP_RESPONSE); cdecl;
begin
end;

procedure StubOCSPBasicRespFree(a: POCSP_BASICRESP); cdecl;
begin
end;

function StubSkX509NewNull: nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509; cdecl;
begin
  if Assigned(OPENSSL_sk_new_null) then
    Result := nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509(OPENSSL_sk_new_null())
  else
    Result := nil;
end;

function StubSkX509Push(
  st: nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509;
  val: PX509
): Integer; cdecl;
begin
  if Assigned(OPENSSL_sk_push) then
    Result := OPENSSL_sk_push(nextpas.core.tls.openssl.api.stack.POPENSSL_STACK(st), val)
  else
    Result := 0;
end;

function StubSkX509Num(
  const st: nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509
): Integer; cdecl;
begin
  if Assigned(OPENSSL_sk_num) then
    Result := OPENSSL_sk_num(nextpas.core.tls.openssl.api.stack.POPENSSL_STACK(st))
  else
    Result := 0;
end;

function StubSkX509Value(
  const st: nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509;
  i: Integer
): PX509; cdecl;
begin
  if Assigned(OPENSSL_sk_value) then
    Result := PX509(OPENSSL_sk_value(nextpas.core.tls.openssl.api.stack.POPENSSL_STACK(st), i))
  else
    Result := nil;
end;

procedure StubSkX509Free(st: nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509); cdecl;
begin
  if Assigned(OPENSSL_sk_free) then
    OPENSSL_sk_free(nextpas.core.tls.openssl.api.stack.POPENSSL_STACK(st));
end;

function StubOCSPBasicRespVerify(
  bs: POCSP_BASICRESP;
  certs: nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509;
  st: PX509_STORE;
  flags: Cardinal
): Integer; cdecl;
begin
  GObservedReleasedBorrowedIssuerUse :=
    GStoreCtxFreed and
    Assigned(sk_X509_num) and
    Assigned(sk_X509_value) and
    (certs <> nil) and
    (sk_X509_num(certs) > 0) and
    (sk_X509_value(certs, 0) = GIssuerX509);

  Result := 0;
end;

function StubX509StoreCtxNew: PX509_STORE_CTX; cdecl;
begin
  Result := PX509_STORE_CTX(Pointer(PtrUInt(3)));
end;

procedure StubX509StoreCtxFree(ctx: PX509_STORE_CTX); cdecl;
begin
  GStoreCtxFreed := True;
end;

function StubX509StoreCtxInit(
  ctx: PX509_STORE_CTX;
  trust_store: PX509_STORE;
  target: PX509;
  untrusted: nextpas.core.tls.openssl.base.PSTACK_OF_X509
): Integer; cdecl;
begin
  Result := 1;
end;

function StubX509VerifyCert(ctx: PX509_STORE_CTX): Integer; cdecl;
begin
  Result := 1;
end;

function StubX509StoreCtxGet0Chain(
  ctx: PX509_STORE_CTX
): nextpas.core.tls.openssl.base.PSTACK_OF_X509; cdecl;
begin
  Result := GStoreCtxChain;
end;

function BuildCAOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'posthandshake-ocsp-root.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.ValidDays := 30;
  Result.IsCA := True;
end;

function BuildLeafOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'posthandshake-ocsp-leaf.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.ValidDays := 30;
  Result.IsCA := False;
  Result.OCSPResponderURL := 'http://ocsp.posthandshake.contract.test';
end;

procedure AssertLeafCertificateContainsExpectedOCSPURL(
  ACert: ISSLCertificate;
  const AExpectedURL: string
);
var
  LDER: TBytes;
  LParsed: TX509Certificate;
  LURL: string;
begin
  LDER := ACert.SaveToDER;
  if Length(LDER) = 0 then
    raise Exception.Create('leaf certificate DER export is empty');

  LParsed := TX509Certificate.Create;
  try
    LParsed.LoadFromDER(LDER);
    LURL := GetOCSPURLFromCertificate(LParsed);
  finally
    LParsed.Free;
  end;

  if LURL <> AExpectedURL then
    raise Exception.CreateFmt(
      'leaf certificate OCSP URL mismatch: expected %s, got %s',
      [AExpectedURL, LURL]
    );
end;

procedure PreparePostHandshakeOCSPMaterials;
var
  LCAOptions: TCertGenOptions;
  LLeafOptions: TCertGenOptions;
  LCAPEM: string;
  LCAKeyPEM: string;
  LLeafPEM: string;
  LLeafKeyPEM: string;
begin
  if GStoreCtxChain <> nil then
    Exit;

  LCAOptions := BuildCAOptions;
  if not TCertificateUtils.GenerateSelfSigned(LCAOptions, LCAPEM, LCAKeyPEM) then
    raise Exception.Create('failed to generate CA material for post-handshake OCSP contract');

  LLeafOptions := BuildLeafOptions;
  if not TCertificateUtils.GenerateSigned(
    LLeafOptions,
    LCAPEM,
    LCAKeyPEM,
    LLeafPEM,
    LLeafKeyPEM
  ) then
    raise Exception.Create('failed to generate leaf material for post-handshake OCSP contract');

  GLeafCert := TSSLFactory.CreateCertificate(sslOpenSSL);
  if (GLeafCert = nil) or (not GLeafCert.LoadFromPEM(LLeafPEM)) then
    raise Exception.Create('failed to load leaf certificate PEM for post-handshake OCSP contract');

  GIssuerCert := TSSLFactory.CreateCertificate(sslOpenSSL);
  if (GIssuerCert = nil) or (not GIssuerCert.LoadFromPEM(LCAPEM)) then
    raise Exception.Create('failed to load issuer certificate PEM for post-handshake OCSP contract');

  AssertLeafCertificateContainsExpectedOCSPURL(GLeafCert, LLeafOptions.OCSPResponderURL);

  if (not TryGetNativeHandle(GIssuerCert, Pointer(GIssuerX509))) or (GIssuerX509 = nil) then
    raise Exception.Create('failed to obtain issuer native X509 handle for post-handshake OCSP contract');

  if (not Assigned(sk_X509_new_null)) or (not Assigned(sk_X509_push)) then
    raise Exception.Create('stack helpers unavailable for post-handshake OCSP contract');

  GStoreCtxChain := nextpas.core.tls.openssl.base.PSTACK_OF_X509(sk_X509_new_null());
  if GStoreCtxChain = nil then
    raise Exception.Create('failed to allocate X509 stack for post-handshake OCSP contract');

  if sk_X509_push(
       nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509(GStoreCtxChain),
       GIssuerX509
     ) <> 1 then
    raise Exception.Create('failed to push issuer cert into X509 stack for post-handshake OCSP contract');
end;

procedure CleanupPostHandshakeOCSPMaterials;
begin
  if GStoreCtxChain <> nil then
  begin
    if Assigned(sk_X509_free) then
      sk_X509_free(nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509(GStoreCtxChain));
    GStoreCtxChain := nil;
  end;

  GIssuerX509 := nil;
  GIssuerCert := nil;
  GLeafCert := nil;
end;

procedure TestConnectShouldFailClosedWhenPostHandshakeStoreCtxIssuerCannotBeRetained;
var
  LContext: ISSLContext;
  LHTTPHooksAccess: ISSLHttpHooksAccess;
  LHTTPPostHook: THTTPPostHookStub;
  LConn: TOpenSSLConnectionPostHandshakeAccess;
  LRaised: Boolean;
  LConnected: Boolean;
  LDetail: string;
  LOriginalSSLConnect: TSSL_connect;
  LOriginalSSLGetVerifyResult: TSSL_get_verify_result;
  LOriginalSSLCTXGetCertStore: TSSL_CTX_get_cert_store;
  LOriginalOCSPRequestNew: TOCSP_REQUEST_new;
  LOriginalOCSPRequestFree: TOCSP_REQUEST_free;
  LOriginalI2DOCSPRequest: Ti2d_OCSP_REQUEST;
  LOriginalOCSPCertToID: TOCSP_cert_to_id;
  LOriginalOCSPRequestAdd0ID: TOCSP_request_add0_id;
  LOriginalOCSPRequestAdd1Nonce: TOCSP_request_add1_nonce;
  LOriginalOCSPCheckNonce: TOCSP_check_nonce;
  LOriginalD2IOCSPResponse: Td2i_OCSP_RESPONSE;
  LOriginalOCSPResponseStatus: TOCSP_RESPONSE_status;
  LOriginalOCSPResponseGet1Basic: TOCSP_RESPONSE_get1_basic;
  LOriginalOCSPResponseFree: TOCSP_RESPONSE_free;
  LOriginalOCSPBasicRespFree: TOCSP_BASICRESP_free;
  LOriginalOCSPBasicRespVerify: TOCSP_BASICRESP_verify;
  LOriginalSSLGetPeerCertChain: TSSL_get_peer_cert_chain;
  LOriginalSSLGet0VerifiedChain: TSSL_get0_verified_chain;
  LOriginalX509StoreCtxNew: TX509_STORE_CTX_new;
  LOriginalX509StoreCtxFree: TX509_STORE_CTX_free;
  LOriginalX509StoreCtxInit: TX509_STORE_CTX_init;
  LOriginalX509VerifyCert: TX509_verify_cert;
  LOriginalX509StoreCtxGet0Chain: TX509_STORE_CTX_get0_chain;
  LOriginalX509UpRef: TX509_up_ref;
  LOriginalSkX509NewNull: Tsk_X509_new_null;
  LOriginalSkX509Push: Tsk_X509_push;
  LOriginalSkX509Num: Tsk_X509_num;
  LOriginalSkX509Value: Tsk_X509_value;
  LOriginalSkX509Free: Tsk_X509_free;
  LMissingHelpers: string;

  procedure AppendMissing(const AName: string; AAvailable: Boolean);
  begin
    if AAvailable then
      Exit;

    if LMissingHelpers <> '' then
      LMissingHelpers := LMissingHelpers + ', ';
    LMissingHelpers := LMissingHelpers + AName;
  end;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection post-handshake OCSP storectx issuer ownership guard ===');

  if not LoadOpenSSLOCSP(GetCryptoLibHandle) then
  begin
    MarkSkip('openssl connection posthandshake ocsp storectx issuer contract',
      'OCSP module is unavailable');
    Exit;
  end;

  LMissingHelpers := '';
  AppendMissing('SSL_new', Assigned(SSL_new));
  AppendMissing('SSL_set_fd', Assigned(SSL_set_fd));
  AppendMissing('SSL_connect', Assigned(SSL_connect));
  AppendMissing('SSL_get_verify_result', Assigned(SSL_get_verify_result));
  AppendMissing('BIO_new_mem_buf', Assigned(BIO_new_mem_buf));
  AppendMissing('BIO_new', Assigned(BIO_new));
  AppendMissing('BIO_s_mem', Assigned(BIO_s_mem));
  AppendMissing('BIO_free', Assigned(BIO_free));
  AppendMissing('PEM_read_bio_X509', Assigned(PEM_read_bio_X509));
  AppendMissing('OBJ_txt2nid', Assigned(OBJ_txt2nid));
  AppendMissing('sk_X509_new_null/OPENSSL_sk_new_null',
    Assigned(sk_X509_new_null) or Assigned(OPENSSL_sk_new_null));
  AppendMissing('sk_X509_push/OPENSSL_sk_push',
    Assigned(sk_X509_push) or Assigned(OPENSSL_sk_push));
  AppendMissing('sk_X509_num/OPENSSL_sk_num',
    Assigned(sk_X509_num) or Assigned(OPENSSL_sk_num));
  AppendMissing('sk_X509_value/OPENSSL_sk_value',
    Assigned(sk_X509_value) or Assigned(OPENSSL_sk_value));
  AppendMissing('sk_X509_free/OPENSSL_sk_free',
    Assigned(sk_X509_free) or Assigned(OPENSSL_sk_free));

  if LMissingHelpers <> '' then
  begin
    MarkSkip('openssl connection posthandshake ocsp storectx issuer contract',
      'required baseline OpenSSL SSL/PEM/OCSP/stack helpers are unavailable: ' + LMissingHelpers);
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  LContext.SetVerifyMode([sslVerifyPeer]);
  LContext.SetCertVerifyFlags([sslCertVerifyCheckOCSP, sslCertVerifyIgnoreHostname]);

  if not Supports(LContext, ISSLHttpHooksAccess, LHTTPHooksAccess) then
    raise Exception.Create('OpenSSL context does not expose HTTP hook access');

  LHTTPPostHook := THTTPPostHookStub.Create;
  LConn := nil;
  LOriginalSSLConnect := SSL_connect;
  LOriginalSSLGetVerifyResult := SSL_get_verify_result;
  LOriginalSSLCTXGetCertStore := SSL_CTX_get_cert_store;
  LOriginalOCSPRequestNew := OCSP_REQUEST_new;
  LOriginalOCSPRequestFree := OCSP_REQUEST_free;
  LOriginalI2DOCSPRequest := i2d_OCSP_REQUEST;
  LOriginalOCSPCertToID := OCSP_cert_to_id;
  LOriginalOCSPRequestAdd0ID := OCSP_request_add0_id;
  LOriginalOCSPRequestAdd1Nonce := OCSP_request_add1_nonce;
  LOriginalOCSPCheckNonce := OCSP_check_nonce;
  LOriginalD2IOCSPResponse := d2i_OCSP_RESPONSE;
  LOriginalOCSPResponseStatus := OCSP_RESPONSE_status;
  LOriginalOCSPResponseGet1Basic := OCSP_RESPONSE_get1_basic;
  LOriginalOCSPResponseFree := OCSP_RESPONSE_free;
  LOriginalOCSPBasicRespFree := OCSP_BASICRESP_free;
  LOriginalOCSPBasicRespVerify := OCSP_BASICRESP_verify;
  LOriginalSSLGetPeerCertChain := SSL_get_peer_cert_chain;
  LOriginalSSLGet0VerifiedChain := SSL_get0_verified_chain;
  LOriginalX509StoreCtxNew := X509_STORE_CTX_new;
  LOriginalX509StoreCtxFree := X509_STORE_CTX_free;
  LOriginalX509StoreCtxInit := X509_STORE_CTX_init;
  LOriginalX509VerifyCert := X509_verify_cert;
  LOriginalX509StoreCtxGet0Chain := X509_STORE_CTX_get0_chain;
  LOriginalX509UpRef := X509_up_ref;
  LOriginalSkX509NewNull := sk_X509_new_null;
  LOriginalSkX509Push := sk_X509_push;
  LOriginalSkX509Num := sk_X509_num;
  LOriginalSkX509Value := sk_X509_value;
  LOriginalSkX509Free := sk_X509_free;
  try
    if not Assigned(sk_X509_new_null) then
      sk_X509_new_null := @StubSkX509NewNull;
    if not Assigned(sk_X509_push) then
      sk_X509_push := @StubSkX509Push;
    if not Assigned(sk_X509_num) then
      sk_X509_num := @StubSkX509Num;
    if not Assigned(sk_X509_value) then
      sk_X509_value := @StubSkX509Value;
    if not Assigned(sk_X509_free) then
      sk_X509_free := @StubSkX509Free;

    PreparePostHandshakeOCSPMaterials;
    LHTTPHooksAccess.SetHTTPPostCallback(@LHTTPPostHook.HandlePost);

    LConn := TOpenSSLConnectionPostHandshakeAccess.Create(LContext, THandle(0));
    LConn.SetStubPeerCertificate(GLeafCert);

    GStoreCtxFreed := False;
    GObservedReleasedBorrowedIssuerUse := False;

    SSL_connect := @StubSSLConnectSuccess;
    SSL_get_verify_result := @StubSSLGetVerifyResultOK;
    SSL_CTX_get_cert_store := @StubSSLCTXGetCertStore;
    OCSP_REQUEST_new := @StubOCSPRequestNew;
    OCSP_REQUEST_free := @StubOCSPRequestFree;
    i2d_OCSP_REQUEST := @StubI2DOCSPRequest;
    OCSP_cert_to_id := @StubOCSPCertToID;
    OCSP_request_add0_id := @StubOCSPRequestAdd0ID;
    OCSP_request_add1_nonce := @StubOCSPRequestAdd1Nonce;
    OCSP_check_nonce := @StubOCSPCheckNonce;
    d2i_OCSP_RESPONSE := @StubD2IOCSPResponse;
    OCSP_RESPONSE_status := @StubOCSPResponseStatus;
    OCSP_RESPONSE_get1_basic := @StubOCSPResponseGet1Basic;
    OCSP_RESPONSE_free := @StubOCSPResponseFree;
    OCSP_BASICRESP_free := @StubOCSPBasicRespFree;
    OCSP_BASICRESP_verify := @StubOCSPBasicRespVerify;
    SSL_get_peer_cert_chain := nil;
    SSL_get0_verified_chain := nil;
    X509_STORE_CTX_new := @StubX509StoreCtxNew;
    X509_STORE_CTX_free := @StubX509StoreCtxFree;
    X509_STORE_CTX_init := @StubX509StoreCtxInit;
    X509_verify_cert := @StubX509VerifyCert;
    X509_STORE_CTX_get0_chain := @StubX509StoreCtxGet0Chain;
    X509_up_ref := nil;

    LRaised := False;
    LConnected := True;
    LDetail := '';
    try
      LConnected := LConn.Connect;
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(
      'Connect when post-handshake storectx issuer cannot be retained should not raise',
      not LRaised,
      LDetail
    );
    AssertTrue(
      'Connect when post-handshake storectx issuer cannot be retained should fail closed',
      not LConnected,
      'expected Connect to return False when X509_up_ref is unavailable for storectx issuer fallback'
    );
    AssertTrue(
      'Connect when post-handshake storectx issuer cannot be retained should not pass released borrowed issuer downstream',
      not GObservedReleasedBorrowedIssuerUse,
      'observed CheckCertificateStatus after StoreCtx release with borrowed issuer pointer'
    );
  finally
    SSL_connect := LOriginalSSLConnect;
    SSL_get_verify_result := LOriginalSSLGetVerifyResult;
    SSL_CTX_get_cert_store := LOriginalSSLCTXGetCertStore;
    OCSP_REQUEST_new := LOriginalOCSPRequestNew;
    OCSP_REQUEST_free := LOriginalOCSPRequestFree;
    i2d_OCSP_REQUEST := LOriginalI2DOCSPRequest;
    OCSP_cert_to_id := LOriginalOCSPCertToID;
    OCSP_request_add0_id := LOriginalOCSPRequestAdd0ID;
    OCSP_request_add1_nonce := LOriginalOCSPRequestAdd1Nonce;
    OCSP_check_nonce := LOriginalOCSPCheckNonce;
    d2i_OCSP_RESPONSE := LOriginalD2IOCSPResponse;
    OCSP_RESPONSE_status := LOriginalOCSPResponseStatus;
    OCSP_RESPONSE_get1_basic := LOriginalOCSPResponseGet1Basic;
    OCSP_RESPONSE_free := LOriginalOCSPResponseFree;
    OCSP_BASICRESP_free := LOriginalOCSPBasicRespFree;
    OCSP_BASICRESP_verify := LOriginalOCSPBasicRespVerify;
    SSL_get_peer_cert_chain := LOriginalSSLGetPeerCertChain;
    SSL_get0_verified_chain := LOriginalSSLGet0VerifiedChain;
    X509_STORE_CTX_new := LOriginalX509StoreCtxNew;
    X509_STORE_CTX_free := LOriginalX509StoreCtxFree;
    X509_STORE_CTX_init := LOriginalX509StoreCtxInit;
    X509_verify_cert := LOriginalX509VerifyCert;
    X509_STORE_CTX_get0_chain := LOriginalX509StoreCtxGet0Chain;
    X509_up_ref := LOriginalX509UpRef;
    sk_X509_new_null := LOriginalSkX509NewNull;
    sk_X509_push := LOriginalSkX509Push;
    sk_X509_num := LOriginalSkX509Num;
    sk_X509_value := LOriginalSkX509Value;
    sk_X509_free := LOriginalSkX509Free;
    LHTTPHooksAccess.SetHTTPPostCallback(nil);
    if Assigned(LConn) then
      LConn.Free;
    LHTTPPostHook.Free;
    CleanupPostHandshakeOCSPMaterials;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Post-Handshake OCSP StoreCtx Issuer Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection posthandshake ocsp storectx issuer contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      LoadOBJModule(GetCryptoLibHandle);
      if not LoadStackFunctions then
        raise Exception.Create('failed to load stack support');
      if not LoadOpenSSLPEM(GetCryptoLibHandle) then
        raise Exception.Create('failed to load PEM support');
      LoadOpenSSLX509();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestConnectShouldFailClosedWhenPostHandshakeStoreCtxIssuerCannotBeRetained;

    WriteLn;
    WriteLn('========================================');
    WriteLn('Summary');
    WriteLn('========================================');
    WriteLn('Total tests: ', TotalTests);
    WriteLn('Passed: ', PassedTests);
    WriteLn('Failed: ', FailedTests);
    WriteLn('Skipped: ', SkippedTests);

    if FailedTests > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
