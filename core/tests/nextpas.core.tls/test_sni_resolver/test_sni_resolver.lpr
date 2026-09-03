program test_sni_resolver;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tls.base,
  nextpas.core.tls.sni.resolver,
  nextpas.core.test;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('tls.sni_resolver');

  LSuite.Test('exact match', procedure
  var LResolver: TSSLSNICertificateResolver; LHello: TSSLClientHelloInfo;
    LCred: ISSLServerCredential; LResult: TSSLOperationResult;
  begin
    LResolver := TSSLSNICertificateResolver.Create;
    try
      LResolver.AddHost('api.example.com', 'API_CERT_PEM', 'API_KEY_PEM');
      LResolver.AddHost('www.example.com', 'WWW_CERT_PEM', 'WWW_KEY_PEM');
      LHello.ServerName := 'api.example.com';
      LResult := LResolver.ResolveServerCredential(LHello, LCred);
      CheckTrue(LResult.IsOk);
      CheckEqual('API_CERT_PEM', LCred.GetCertificateChainPEM);
      LHello.ServerName := 'www.example.com';
      LResult := LResolver.ResolveServerCredential(LHello, LCred);
      CheckTrue(LResult.IsOk);
      CheckEqual('WWW_CERT_PEM', LCred.GetCertificateChainPEM);
    finally LResolver.Free; end;
  end);

  LSuite.Test('wildcard match', procedure
  var LResolver: TSSLSNICertificateResolver; LHello: TSSLClientHelloInfo;
    LCred: ISSLServerCredential; LResult: TSSLOperationResult;
  begin
    LResolver := TSSLSNICertificateResolver.Create;
    try
      LResolver.AddHost('*.test.com', 'WILD_CERT_PEM', 'WILD_KEY_PEM');
      LHello.ServerName := 'foo.test.com';
      LResult := LResolver.ResolveServerCredential(LHello, LCred);
      CheckTrue(LResult.IsOk);
      CheckEqual('WILD_CERT_PEM', LCred.GetCertificateChainPEM);
    finally LResolver.Free; end;
  end);

  LSuite.Test('default fallback', procedure
  var LResolver: TSSLSNICertificateResolver; LHello: TSSLClientHelloInfo;
    LCred: ISSLServerCredential; LResult: TSSLOperationResult;
  begin
    LResolver := TSSLSNICertificateResolver.Create;
    try
      LResolver.AddHost('api.example.com', 'API_CERT', 'API_KEY');
      LResolver.SetDefault('DEFAULT_CERT_PEM', 'DEFAULT_KEY_PEM');
      LHello.ServerName := 'unknown.org';
      LResult := LResolver.ResolveServerCredential(LHello, LCred);
      CheckTrue(LResult.IsOk);
      CheckEqual('DEFAULT_CERT_PEM', LCred.GetCertificateChainPEM);
    finally LResolver.Free; end;
  end);

  LSuite.Test('case insensitive', procedure
  var LResolver: TSSLSNICertificateResolver; LHello: TSSLClientHelloInfo;
    LCred: ISSLServerCredential; LResult: TSSLOperationResult;
  begin
    LResolver := TSSLSNICertificateResolver.Create;
    try
      LResolver.AddHost('api.example.com', 'API_CERT', 'API_KEY');
      LHello.ServerName := 'API.EXAMPLE.COM';
      LResult := LResolver.ResolveServerCredential(LHello, LCred);
      CheckTrue(LResult.IsOk);
    finally LResolver.Free; end;
  end);

  LSuite.Test('no default no match', procedure
  var LResolver: TSSLSNICertificateResolver; LHello: TSSLClientHelloInfo;
    LCred: ISSLServerCredential; LResult: TSSLOperationResult;
  begin
    LResolver := TSSLSNICertificateResolver.Create;
    try
      LResolver.AddHost('only.com', 'ONLY_CERT', 'ONLY_KEY');
      LHello.ServerName := 'other.com';
      LResult := LResolver.ResolveServerCredential(LHello, LCred);
      CheckTrue(LResult.IsErr);
    finally LResolver.Free; end;
  end);

  LSuite.Test('wildcard security', procedure
  var LResolver: TSSLSNICertificateResolver; LHello: TSSLClientHelloInfo;
    LCred: ISSLServerCredential; LResult: TSSLOperationResult;
  begin
    LResolver := TSSLSNICertificateResolver.Create;
    try
      LResolver.AddHost('*.example.com', 'WILD_CERT', 'WILD_KEY');
      LHello.ServerName := 'a.b.example.com';
      LResult := LResolver.ResolveServerCredential(LHello, LCred);
      CheckTrue(LResult.IsErr);
      LHello.ServerName := 'example.com';
      LResult := LResolver.ResolveServerCredential(LHello, LCred);
      CheckTrue(LResult.IsErr);
      LHello.ServerName := 'www.example.com';
      LResult := LResolver.ResolveServerCredential(LHello, LCred);
      CheckTrue(LResult.IsOk);
      LHello.ServerName := 'notexample.com';
      LResult := LResolver.ResolveServerCredential(LHello, LCred);
      CheckTrue(LResult.IsErr);
    finally LResolver.Free; end;
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.tls.sni_resolver');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
