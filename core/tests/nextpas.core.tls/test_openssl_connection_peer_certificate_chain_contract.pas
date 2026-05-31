program test_openssl_connection_peer_certificate_chain_contract;

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
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.connection;

var
  GLib: ISSLLibrary = nil;
  GStubPeerChainCert: PX509 = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;

// INTENTIONAL_CORE_SURFACE: this backend proof file intentionally keeps direct
// core GetPeerCertificateChain coverage as runtime proof. Generic
// ISSLCertificateVerification owner-path guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

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

function StubSSLGetPeerCertChainNonNil(
  const ssl: PSSL
): nextpas.core.tls.openssl.base.PSTACK_OF_X509; cdecl;
begin
  Result := nextpas.core.tls.openssl.base.PSTACK_OF_X509(Pointer(PtrUInt(1)));
end;

function StubSkX509NumOne(
  const st: nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509
): Integer; cdecl;
begin
  Result := 1;
end;

function StubSkX509ValueRealCert(
  const st: nextpas.core.tls.openssl.api.stack.PSTACK_OF_X509;
  i: Integer
): PX509; cdecl;
begin
  Result := GStubPeerChainCert;
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
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

procedure AssertPeerCertificateChainSafeDegrade(const AName: string; AContext: ISSLContext);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
  LRaised: Boolean;
  LChain: TSSLCertificateArray;
  LDetail: string;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LConn := TOpenSSLConnection.Create(AContext, LStream);

    LRaised := False;
    LChain := nil;
    LDetail := '';
    try
      LChain := LConn.GetPeerCertificateChain;
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should return an empty array',
      Length(LChain) = 0,
      'expected GetPeerCertificateChain to preserve its empty-array contract');
  finally
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

procedure TestGetPeerCertificateChainShouldDegradeSafelyWhenHelpersAreUnavailable;
var
  LContext: ISSLContext;
  LOriginalSSLGetPeerCertChain: TSSL_get_peer_cert_chain;
  LOriginalSkX509Num: Tsk_X509_num;
  LOriginalSkX509Value: Tsk_X509_value;
  LOriginalX509UpRef: TX509_up_ref;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection peer certificate chain guard ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(X509_new)) or
     (not Assigned(X509_free)) then
  begin
    MarkSkip('openssl connection peer certificate chain contract',
      'required baseline OpenSSL SSL/BIO/X509 helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);

  LOriginalSSLGetPeerCertChain := SSL_get_peer_cert_chain;
  LOriginalSkX509Num := sk_X509_num;
  LOriginalSkX509Value := sk_X509_value;
  LOriginalX509UpRef := X509_up_ref;
  try
    SSL_get_peer_cert_chain := nil;
    sk_X509_num := LOriginalSkX509Num;
    sk_X509_value := LOriginalSkX509Value;
    X509_up_ref := LOriginalX509UpRef;
    AssertPeerCertificateChainSafeDegrade(
      'GetPeerCertificateChain when SSL_get_peer_cert_chain is unavailable',
      LContext
    );

    SSL_get_peer_cert_chain := @StubSSLGetPeerCertChainNonNil;
    sk_X509_num := nil;
    sk_X509_value := LOriginalSkX509Value;
    X509_up_ref := LOriginalX509UpRef;
    AssertPeerCertificateChainSafeDegrade(
      'GetPeerCertificateChain when sk_X509_num is unavailable',
      LContext
    );

    SSL_get_peer_cert_chain := @StubSSLGetPeerCertChainNonNil;
    sk_X509_num := @StubSkX509NumOne;
    sk_X509_value := nil;
    X509_up_ref := LOriginalX509UpRef;
    AssertPeerCertificateChainSafeDegrade(
      'GetPeerCertificateChain when sk_X509_value is unavailable',
      LContext
    );

    GStubPeerChainCert := X509_new();
    if GStubPeerChainCert = nil then
      raise Exception.Create('failed to allocate temporary X509 for peer-chain contract');
    try
      SSL_get_peer_cert_chain := @StubSSLGetPeerCertChainNonNil;
      sk_X509_num := @StubSkX509NumOne;
      sk_X509_value := @StubSkX509ValueRealCert;
      X509_up_ref := nil;
      AssertPeerCertificateChainSafeDegrade(
        'GetPeerCertificateChain when X509_up_ref is unavailable',
        LContext
      );
    finally
      X509_up_ref := LOriginalX509UpRef;
      if GStubPeerChainCert <> nil then
        X509_free(GStubPeerChainCert);
      GStubPeerChainCert := nil;
    end;
  finally
    SSL_get_peer_cert_chain := LOriginalSSLGetPeerCertChain;
    sk_X509_num := LOriginalSkX509Num;
    sk_X509_value := LOriginalSkX509Value;
    X509_up_ref := LOriginalX509UpRef;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Peer Certificate Chain Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection peer certificate chain contract',
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
      TestGetPeerCertificateChainShouldDegradeSafelyWhenHelpersAreUnavailable;

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
