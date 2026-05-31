program test_sni_resolver;
{$mode ObjFPC}{$H+}
uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.sni.resolver;

var GPass: Integer = 0; GFail: Integer = 0;

procedure Check(C: Boolean; const N: string);
begin if C then begin WriteLn('  [PASS] ', N); Inc(GPass); end else begin WriteLn('  [FAIL] ', N); Inc(GFail); end; end;

var
  LResolver: TSSLSNICertificateResolver;
  LHello: TSSLClientHelloInfo;
  LCred: ISSLServerCredential;
  LResult: TSSLOperationResult;
begin
  WriteLn('=== SNI Certificate Resolver Tests ===');
  WriteLn;

  LResolver := TSSLSNICertificateResolver.Create;
  try
    LResolver.AddHost('api.example.com', 'API_CERT_PEM', 'API_KEY_PEM');
    LResolver.AddHost('www.example.com', 'WWW_CERT_PEM', 'WWW_KEY_PEM');
    LResolver.AddHost('*.test.com', 'WILD_CERT_PEM', 'WILD_KEY_PEM');
    LResolver.SetDefault('DEFAULT_CERT_PEM', 'DEFAULT_KEY_PEM');

    WriteLn('--- Exact match ---');
    LHello.ServerName := 'api.example.com';
    LResult := LResolver.ResolveServerCredential(LHello, LCred);
    Check(LResult.IsOk, 'api.example.com resolves');
    Check(LCred.GetCertificateChainPEM = 'API_CERT_PEM', 'correct cert for api');

    LHello.ServerName := 'www.example.com';
    LResult := LResolver.ResolveServerCredential(LHello, LCred);
    Check(LResult.IsOk, 'www.example.com resolves');
    Check(LCred.GetCertificateChainPEM = 'WWW_CERT_PEM', 'correct cert for www');

    WriteLn('--- Wildcard match ---');
    LHello.ServerName := 'foo.test.com';
    LResult := LResolver.ResolveServerCredential(LHello, LCred);
    Check(LResult.IsOk, 'foo.test.com matches *.test.com');
    Check(LCred.GetCertificateChainPEM = 'WILD_CERT_PEM', 'correct wildcard cert');

    WriteLn('--- Default fallback ---');
    LHello.ServerName := 'unknown.org';
    LResult := LResolver.ResolveServerCredential(LHello, LCred);
    Check(LResult.IsOk, 'unknown.org falls back to default');
    Check(LCred.GetCertificateChainPEM = 'DEFAULT_CERT_PEM', 'correct default cert');

    WriteLn('--- Case insensitive ---');
    LHello.ServerName := 'API.EXAMPLE.COM';
    LResult := LResolver.ResolveServerCredential(LHello, LCred);
    Check(LResult.IsOk, 'case insensitive match');

    WriteLn('--- No default, no match ---');
    LResolver.Free;
    LResolver := TSSLSNICertificateResolver.Create;
    LResolver.AddHost('only.com', 'ONLY_CERT', 'ONLY_KEY');
    LHello.ServerName := 'other.com';
    LResult := LResolver.ResolveServerCredential(LHello, LCred);
    Check(LResult.IsErr, 'no match without default returns error');
  finally
    LResolver.Free;
  end;

  // Hostile wildcard tests
  LResolver := TSSLSNICertificateResolver.Create;
  try
    LResolver.AddHost('*.example.com', 'WILD_CERT', 'WILD_KEY');

    WriteLn('--- Wildcard security ---');
    // Multi-label should NOT match *.example.com
    LHello.ServerName := 'a.b.example.com';
    LResult := LResolver.ResolveServerCredential(LHello, LCred);
    Check(LResult.IsErr, 'multi-label a.b.example.com rejected by *.example.com');

    // Exact domain should NOT match (*.example.com != example.com)
    LHello.ServerName := 'example.com';
    LResult := LResolver.ResolveServerCredential(LHello, LCred);
    Check(LResult.IsErr, 'bare example.com rejected by *.example.com');

    // Single label SHOULD match
    LHello.ServerName := 'www.example.com';
    LResult := LResolver.ResolveServerCredential(LHello, LCred);
    Check(LResult.IsOk, 'www.example.com matches *.example.com');

    // Suffix attack: notexample.com should NOT match
    LHello.ServerName := 'notexample.com';
    LResult := LResolver.ResolveServerCredential(LHello, LCred);
    Check(LResult.IsErr, 'notexample.com rejected (suffix attack)');
  finally
    LResolver.Free;
  end;

  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then Halt(1);
end.
