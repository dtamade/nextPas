program test_openssl_connection_peer_certificate_surface;

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
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.native_handle,
  nextpas.core.tls.openssl.x509.chain,
  nextpas.core.tls.openssl.connection;

var
  GLib: ISSLLibrary = nil;
  GLeafFixture: ISSLCertificate = nil;
  GIssuerFixture: ISSLCertificate = nil;
  GLeafX509: PX509 = nil;
  GIssuerX509: PX509 = nil;
  GPeerChain: PSTACK_OF_X509 = nil;
  GOriginalSSLGetPeerCertificate: TSSL_get_peer_certificate = nil;
  GOriginalSSLGetPeerCertChain: TSSL_get_peer_cert_chain = nil;
  GOriginalSkX509Num: Tsk_X509_num = nil;
  GOriginalSkX509Value: Tsk_X509_value = nil;

// INTENTIONAL_CORE_SURFACE: this backend proof file intentionally keeps direct
// core GetPeerCertificateChain coverage as runtime proof. Generic
// ISSLCertificateVerification owner-path guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

procedure Skip(const AMessage: string);
begin
  WriteLn('[SKIP] ', AMessage);
  Halt(0);
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

function RequireX509Handle(const ACert: ISSLCertificate): PX509;
var
  LHandle: Pointer;
begin
  if ACert = nil then
    raise Exception.Create('fixture certificate is nil');

  if not TryGetNativeHandle(ACert, LHandle) then
    raise Exception.Create('fixture certificate did not expose a native handle');

  Result := PX509(LHandle);
  if Result = nil then
    raise Exception.Create('fixture certificate returned a nil PX509 handle');
end;

function NewChain: PSTACK_OF_X509;
begin
  Result := PSTACK_OF_X509(CreateStack);
  if Result = nil then
    raise Exception.Create('CreateStack returned nil');
end;

procedure FreeChain(AChain: PSTACK_OF_X509);
begin
  if AChain <> nil then
    FreeStack(POPENSSL_STACK(AChain));
end;

procedure PushCert(AChain: PSTACK_OF_X509; AX509: PX509);
begin
  if (AChain = nil) or (AX509 = nil) then
    raise Exception.Create('PushCert received nil input');

  if not PushToStack(POPENSSL_STACK(AChain), AX509) then
    raise Exception.Create('PushToStack failed');
end;

procedure LoadFixtureCertificates;
begin
  GLeafFixture := TSSLFactory.CreateCertificate(sslOpenSSL);
  AssertTrue(GLeafFixture <> nil, 'OpenSSL leaf fixture certificate should be created');
  AssertTrue(
    GLeafFixture.LoadFromFile('tests/certificate/test_certs/signer_cert.pem'),
    'OpenSSL leaf fixture certificate should load'
  );

  GIssuerFixture := TSSLFactory.CreateCertificate(sslOpenSSL);
  AssertTrue(GIssuerFixture <> nil, 'OpenSSL issuer fixture certificate should be created');
  AssertTrue(
    GIssuerFixture.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'),
    'OpenSSL issuer fixture certificate should load'
  );

  GLeafX509 := RequireX509Handle(GLeafFixture);
  GIssuerX509 := RequireX509Handle(GIssuerFixture);
end;

procedure BuildPeerChain;
begin
  FreeChain(GPeerChain);
  GPeerChain := NewChain;
  PushCert(GPeerChain, GLeafX509);
  PushCert(GPeerChain, GIssuerX509);
end;

function StubSSLGetPeerCertificate(const ssl: PSSL): PX509; cdecl;
begin
  if (ssl = nil) or (GLeafX509 = nil) or (not Assigned(X509_up_ref)) then
    Exit(nil);

  X509_up_ref(GLeafX509);
  Result := GLeafX509;
end;

function StubSSLGetPeerCertChain(const ssl: PSSL): nextpas.core.tls.openssl.base.PSTACK_OF_X509; cdecl;
begin
  if (ssl = nil) or (GPeerChain = nil) then
    Exit(nil);

  Result := GPeerChain;
end;

function StubSkX509Num(const st: nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509): Integer; cdecl;
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

procedure RestorePeerCertificateAPIs;
begin
  SSL_get_peer_certificate := GOriginalSSLGetPeerCertificate;
  SSL_get_peer_cert_chain := GOriginalSSLGetPeerCertChain;
  sk_X509_num := GOriginalSkX509Num;
  sk_X509_value := GOriginalSkX509Value;
end;

procedure OverridePeerCertificateAPIs;
begin
  GOriginalSSLGetPeerCertificate := SSL_get_peer_certificate;
  GOriginalSSLGetPeerCertChain := SSL_get_peer_cert_chain;
  GOriginalSkX509Num := sk_X509_num;
  GOriginalSkX509Value := sk_X509_value;

  SSL_get_peer_certificate := @StubSSLGetPeerCertificate;
  SSL_get_peer_cert_chain := @StubSSLGetPeerCertChain;
  sk_X509_num := @StubSkX509Num;
  sk_X509_value := @StubSkX509Value;
end;

procedure WarmupStreamConnectionConstructor(AContext: ISSLContext);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LConn := TOpenSSLConnection.Create(AContext, LStream);
    if LConn = nil then
      raise Exception.Create('stream connection constructor warmup returned nil');
  finally
    LConn.Free;
    LStream.Free;
  end;
end;

procedure TestPeerCertificateIssuerLinkSurface;
var
  LContext: ISSLContext;
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
  LPeerCert: ISSLCertificate;
  LIssuerFromPeerCert: ISSLCertificate;
  LChain: TSSLCertificateArray;
begin
  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(X509_up_ref)) or
     (not Assigned(X509_free)) then
    Skip('required baseline OpenSSL SSL/BIO/X509 helpers are unavailable');

  LoadFixtureCertificates;
  BuildPeerChain;

  LContext := GLib.CreateContext(sslCtxClient);
  AssertTrue(LContext <> nil, 'OpenSSL client context should be created');

  WarmupStreamConnectionConstructor(LContext);

  LStream := TMemoryStream.Create;
  LConn := nil;
  OverridePeerCertificateAPIs;
  try
    LConn := TOpenSSLConnection.Create(LContext, LStream);

    LPeerCert := LConn.GetPeerCertificate;
    AssertTrue(LPeerCert <> nil,
      'OpenSSL peer leaf certificate should be exposed when peer certificate exists');
    AssertTrue(
      SameText(LPeerCert.GetFingerprintSHA256, GLeafFixture.GetFingerprintSHA256),
      'OpenSSL peer leaf certificate should match the scripted leaf fixture'
    );

    LIssuerFromPeerCert := LPeerCert.GetIssuerCertificate;
    AssertTrue(LIssuerFromPeerCert <> nil,
      'OpenSSL peer leaf certificate should preserve issuer link');
    AssertTrue(
      (LIssuerFromPeerCert <> nil) and
      SameText(LIssuerFromPeerCert.GetFingerprintSHA256, GIssuerFixture.GetFingerprintSHA256),
      'OpenSSL peer leaf issuer link should match the scripted issuer fixture'
    );

    LChain := LConn.GetPeerCertificateChain;
    AssertEqualsInt(2, Length(LChain),
      'OpenSSL peer chain surface should materialize the scripted leaf and issuer entries');
    AssertTrue(LChain[0] <> nil, 'OpenSSL peer chain leaf entry should not be nil');
    AssertTrue(LChain[1] <> nil, 'OpenSSL peer chain issuer entry should not be nil');
    AssertTrue(
      SameText(LChain[0].GetFingerprintSHA256, GLeafFixture.GetFingerprintSHA256),
      'OpenSSL peer chain leaf entry should match the scripted leaf fixture'
    );
    AssertTrue(
      SameText(LChain[1].GetFingerprintSHA256, GIssuerFixture.GetFingerprintSHA256),
      'OpenSSL peer chain issuer entry should match the scripted issuer fixture'
    );
    AssertTrue(LChain[0].GetIssuerCertificate <> nil,
      'OpenSSL peer chain leaf entry should preserve issuer link');
    AssertTrue(
      (LChain[0].GetIssuerCertificate <> nil) and
      SameText(LChain[0].GetIssuerCertificate.GetFingerprintSHA256, GIssuerFixture.GetFingerprintSHA256),
      'OpenSSL peer chain leaf issuer link should match the scripted issuer fixture'
    );
    AssertTrue(LChain[1].GetIssuerCertificate = nil,
      'OpenSSL peer chain issuer entry should not invent a higher issuer link');
  finally
    RestorePeerCertificateAPIs;
    LConn.Free;
    LStream.Free;
    FreeChain(GPeerChain);
    GPeerChain := nil;
  end;
end;

begin
  WriteLn('Testing OpenSSL client peer certificate surface...');

  if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
    Skip('OpenSSL backend not available on this platform');

  GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if (GLib = nil) or (not GLib.Initialize) then
    Skip('OpenSSL runtime unavailable; peer certificate surface test skipped');

  try
    LoadOpenSSLCore();
    LoadOpenSSLBIO();
    if not LoadOpenSSLSSL then
      Skip('OpenSSL SSL module unavailable; peer certificate surface test skipped');
    LoadOpenSSLX509();
    if not LoadStackFunctions then
      Skip('OpenSSL stack helpers unavailable; peer certificate surface test skipped');

    TestPeerCertificateIssuerLinkSurface;
    WriteLn('PASS: OpenSSL client peer certificate surface contract passed');
  finally
    FreeChain(GPeerChain);
    GPeerChain := nil;
    GLib.Finalize;
  end;
end.
