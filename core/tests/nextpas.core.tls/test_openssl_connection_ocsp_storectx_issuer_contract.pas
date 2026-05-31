program test_openssl_connection_ocsp_storectx_issuer_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.ocsp,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.certificate,
  nextpas.core.tls.openssl.connection;

// INTENTIONAL_OCSP_CORE_SURFACE: this OpenSSL-specific contract file
// intentionally keeps direct core OCSP compatibility-surface coverage
// as backend proof for storectx-issuer fail-closed behavior. Ordinary
// ISSLOCSPStapling owner-path guidance is frozen elsewhere.

type
  TOpenSSLConnectionOCSPAccess = class(TOpenSSLConnection)
  private
    FStubOCSPResponse: TBytes;
    FStubPeerCertificate: ISSLCertificate;
  protected
    function DoGetOCSPResponse: TBytes; override;
    function DoGetPeerCertificate: ISSLCertificate; override;
  public
    procedure SetStubOCSPResponse(const AData: TBytes);
    procedure SetStubPeerCertificate(ACert: ISSLCertificate);
  end;

const
  MBSTRING_ASC_VALUE = $1001;

var
  GLib: ISSLLibrary = nil;
  GLeafX509: PX509 = nil;
  GIssuerX509: PX509 = nil;
  GStoreCtxChain: nextpas.core.tls.openssl.base.PSTACK_OF_X509 = nil;
  GStoreCtxFreed: Boolean = False;
  GObservedReleasedBorrowedIssuerUse: Boolean = False;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;

function TOpenSSLConnectionOCSPAccess.DoGetOCSPResponse: TBytes;
begin
  Result := Copy(FStubOCSPResponse);
end;

function TOpenSSLConnectionOCSPAccess.DoGetPeerCertificate: ISSLCertificate;
begin
  Result := FStubPeerCertificate;
end;

procedure TOpenSSLConnectionOCSPAccess.SetStubOCSPResponse(const AData: TBytes);
begin
  FStubOCSPResponse := Copy(AData);
end;

procedure TOpenSSLConnectionOCSPAccess.SetStubPeerCertificate(ACert: ISSLCertificate);
begin
  FStubPeerCertificate := ACert;
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

function BuildX509Name(const ACN: string): PX509_NAME;
var
  LCN: AnsiString;
begin
  Result := nil;

  if (not Assigned(X509_NAME_new)) or
     (not Assigned(X509_NAME_add_entry_by_txt)) then
    Exit;

  Result := X509_NAME_new();
  if Result = nil then
    Exit;

  LCN := AnsiString(ACN);
  if X509_NAME_add_entry_by_txt(Result, 'CN', MBSTRING_ASC_VALUE,
       PByte(PAnsiChar(LCN)), -1, -1, 0) <> 1 then
  begin
    if Assigned(X509_NAME_free) then
      X509_NAME_free(Result);
    Result := nil;
  end;
end;

function BuildMinimalCertificate(const ASubjectCN, AIssuerCN: string): PX509;
var
  LSubjectName: PX509_NAME;
  LIssuerName: PX509_NAME;
begin
  Result := nil;

  if (not Assigned(X509_new)) or
     (not Assigned(X509_free)) or
     (not Assigned(X509_set_subject_name)) or
     (not Assigned(X509_set_issuer_name)) then
    Exit;

  Result := X509_new();
  if Result = nil then
    Exit;

  LSubjectName := BuildX509Name(ASubjectCN);
  LIssuerName := BuildX509Name(AIssuerCN);
  if (LSubjectName = nil) or (LIssuerName = nil) then
  begin
    if LSubjectName <> nil then
      X509_NAME_free(LSubjectName);
    if LIssuerName <> nil then
      X509_NAME_free(LIssuerName);
    X509_free(Result);
    Result := nil;
    Exit;
  end;

  try
    if (X509_set_subject_name(Result, LSubjectName) <> 1) or
       (X509_set_issuer_name(Result, LIssuerName) <> 1) then
    begin
      X509_free(Result);
      Result := nil;
    end;
  finally
    X509_NAME_free(LSubjectName);
    X509_NAME_free(LIssuerName);
  end;
end;

function BuildPeerCertificateInterface(AX509: PX509): ISSLCertificate;
begin
  Result := TOpenSSLCertificate.Create(AX509, False);
end;

procedure PrepareStoreCtxIssuerChain;
begin
  if GStoreCtxChain <> nil then
    Exit;

  GLeafX509 := BuildMinimalCertificate('leaf.example.test', 'issuer.example.test');
  GIssuerX509 := BuildMinimalCertificate('issuer.example.test', 'issuer.example.test');
  if (GLeafX509 = nil) or (GIssuerX509 = nil) then
    raise Exception.Create('failed to build minimal X509 certificates for OCSP ownership contract');

  if (not Assigned(sk_X509_new_null)) or (not Assigned(sk_X509_push)) then
    raise Exception.Create('stack helpers unavailable for OCSP ownership contract');

  GStoreCtxChain := nextpas.core.tls.openssl.base.PSTACK_OF_X509(sk_X509_new_null());
  if GStoreCtxChain = nil then
    raise Exception.Create('failed to allocate X509 stack for OCSP ownership contract');

  if sk_X509_push(
       nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509(GStoreCtxChain),
       GIssuerX509
     ) <> 1 then
    raise Exception.Create('failed to push issuer cert into X509 stack');
end;

procedure CleanupStoreCtxIssuerChain;
begin
  if GStoreCtxChain <> nil then
  begin
    if Assigned(sk_X509_free) then
      sk_X509_free(nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509(GStoreCtxChain));
    GStoreCtxChain := nil;
  end;

  if (GIssuerX509 <> nil) and Assigned(X509_free) then
  begin
    X509_free(GIssuerX509);
    GIssuerX509 := nil;
  end;

  if (GLeafX509 <> nil) and Assigned(X509_free) then
  begin
    X509_free(GLeafX509);
    GLeafX509 := nil;
  end;
end;

procedure TestIsOCSPResponseVerifiedShouldFailClosedWhenStoreCtxIssuerCannotBeRetained;
var
  LContext: ISSLContext;
  LStream: TMemoryStream;
  LConn: TOpenSSLConnectionOCSPAccess;
  LPeerCert: ISSLCertificate;
  LRaised: Boolean;
  LVerified: Boolean;
  LDetail: string;
  LStubResponse: TBytes;
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
begin
  WriteLn;
  WriteLn('=== OpenSSL connection OCSP storectx issuer ownership guard ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(X509_new)) or
     (not Assigned(X509_free)) or
     (not Assigned(X509_NAME_new)) or
     (not Assigned(X509_NAME_add_entry_by_txt)) or
     (not Assigned(X509_set_subject_name)) or
     (not Assigned(X509_set_issuer_name)) or
     ((not Assigned(sk_X509_new_null)) and (not Assigned(OPENSSL_sk_new_null))) or
     ((not Assigned(sk_X509_push)) and (not Assigned(OPENSSL_sk_push))) or
     ((not Assigned(sk_X509_num)) and (not Assigned(OPENSSL_sk_num))) or
     ((not Assigned(sk_X509_value)) and (not Assigned(OPENSSL_sk_value))) or
     ((not Assigned(sk_X509_free)) and (not Assigned(OPENSSL_sk_free))) then
  begin
    MarkSkip('openssl connection ocsp storectx issuer contract',
      'required baseline OpenSSL SSL/BIO/X509/stack helpers are unavailable');
    Exit;
  end;

  if not LoadOpenSSLOCSP(GetCryptoLibHandle) then
  begin
    MarkSkip('openssl connection ocsp storectx issuer contract',
      'OCSP module is unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  LStream := TMemoryStream.Create;
  LConn := nil;
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

    PrepareStoreCtxIssuerChain;
    LPeerCert := BuildPeerCertificateInterface(GLeafX509);

    LConn := TOpenSSLConnectionOCSPAccess.Create(LContext, LStream);
    SetLength(LStubResponse, 1);
    LStubResponse[0] := 1;
    LConn.SetStubOCSPResponse(LStubResponse);
    LConn.SetStubPeerCertificate(LPeerCert);

    GStoreCtxFreed := False;
    GObservedReleasedBorrowedIssuerUse := False;

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
    LVerified := True;
    LDetail := '';
    try
      {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
      LVerified := LConn.IsOCSPResponseVerified;
      {$POP}
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(
      'IsOCSPResponseVerified when storectx fallback issuer cannot be retained should not raise',
      not LRaised,
      LDetail
    );
    AssertTrue(
      'IsOCSPResponseVerified when storectx fallback issuer cannot be retained should fail closed',
      not LVerified,
      'expected OCSP verification to fail closed when X509_up_ref is unavailable'
    );
    AssertTrue(
      'IsOCSPResponseVerified when storectx fallback issuer cannot be retained should not pass released borrowed issuer downstream',
      not GObservedReleasedBorrowedIssuerUse,
      'observed downstream OCSP verification after StoreCtx release with borrowed issuer pointer'
    );
  finally
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
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
    LPeerCert := nil;
    CleanupStoreCtxIssuerChain;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection OCSP StoreCtx Issuer Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection ocsp storectx issuer contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
      LoadOpenSSLX509();
      LoadStackFunctions();
    end;

    if SkippedTests = 0 then
      TestIsOCSPResponseVerifiedShouldFailClosedWhenStoreCtxIssuerCannotBeRetained;

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
