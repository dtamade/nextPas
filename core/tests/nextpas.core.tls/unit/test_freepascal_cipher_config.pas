program test_freepascal_cipher_config;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.context,
  nextpas.core.tls.freepascal.context.material,
  nextpas.core.tls.tls12.wire,
  nextpas.core.tls.tls13.wire;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

procedure TestTLS12CipherListParsing;
var
  LContext: TFreePascalContext;
  LSuites: TFreePascalCipherSuiteList;
begin
  WriteLn('TestTLS12CipherListParsing');
  LContext := TFreePascalContext.Create(nil, sslCtxClient);
  try
    LContext.SetCipherList(
      'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384'
    );
    LSuites := LContext.GetConfiguredCipherSuites12;

    Check(Length(LSuites) = 2, 'TLS 1.2 configured suite count');
    Check(LSuites[0] = TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
      'TLS 1.2 RSA AES128-GCM suite parsed');
    Check(LSuites[1] = TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
      'TLS 1.2 ECDSA AES256-GCM suite parsed');
  finally
    LContext.Free;
  end;
end;

procedure TestTLS13CipherSuitesParsing;
var
  LContext: TFreePascalContext;
  LSuites: TFreePascalCipherSuiteList;
begin
  WriteLn('TestTLS13CipherSuitesParsing');
  LContext := TFreePascalContext.Create(nil, sslCtxClient);
  try
    LContext.SetCipherSuites('TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384');
    LSuites := LContext.GetConfiguredCipherSuites13;

    Check(Length(LSuites) = 2, 'TLS 1.3 configured suite count');
    Check(LSuites[0] = TLS13_CIPHER_AES_128_GCM_SHA256,
      'TLS 1.3 AES128-GCM suite parsed');
    Check(LSuites[1] = TLS13_CIPHER_AES_256_GCM_SHA384,
      'TLS 1.3 AES256-GCM suite parsed');
  finally
    LContext.Free;
  end;
end;

procedure TestWhitespaceAndAliases;
var
  LContext: TFreePascalContext;
  LSuites: TFreePascalCipherSuiteList;
begin
  WriteLn('TestWhitespaceAndAliases');
  LContext := TFreePascalContext.Create(nil, sslCtxClient);
  try
    LContext.SetCipherList(' TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 ');
    LSuites := LContext.GetConfiguredCipherSuites12;
    Check((Length(LSuites) = 1) and
      (LSuites[0] = TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384),
      'TLS 1.2 official alias and whitespace parsed');

    LContext.SetCipherSuites(' aes_128_gcm_sha256 ');
    LSuites := LContext.GetConfiguredCipherSuites13;
    Check((Length(LSuites) = 1) and
      (LSuites[0] = TLS13_CIPHER_AES_128_GCM_SHA256),
      'TLS 1.3 short alias and case-insensitive parsing');
  finally
    LContext.Free;
  end;
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestTLS12CipherListParsing;
  TestTLS13CipherSuitesParsing;
  TestWhitespaceAndAliases;

  WriteLn;
  WriteLn('FreePascal cipher config tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
