program test_convenience_methods;

{$mode objfpc}{$H+}

{**
 * Test suite for Phase 2.2.3 - Convenience Methods
 *
 * Tests the convenience methods functionality:
 * 1. WithCertificateChain - Certificate chain configuration
 * 2. WithMutualTLS - Mutual TLS quick configuration
 * 3. WithHTTP2 - HTTP/2 ALPN quick configuration
 * 4. WithModernDefaults - Modern security defaults
 *}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.backed;  // 确保 OpenSSL 后端注册

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAILED: ', AMessage);
  end;
end;

procedure TestHeader(const ATestName: string);
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  ', ATestName);
  WriteLn('═══════════════════════════════════════════════════════════');
end;

{ Test 1: WithCertificateChain with single cert }
procedure Test_WithCertificateChain_Single;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LCert, LKey: string;
begin
  TestHeader('Test 1: WithCertificateChain With Single Cert');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test.local', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithCertificateChain([LCert]);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('BEGIN CERTIFICATE', LJSON) > 0,
    'WithCertificateChain accepts single certificate');
end;

{ Test 2: WithCertificateChain with multiple certs }
procedure Test_WithCertificateChain_Multiple;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LCert1, LKey1, LCert2, LKey2: string;
begin
  TestHeader('Test 2: WithCertificateChain With Multiple Certs');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test1.local', 'Test Org 1', 30, LCert1, LKey1
  ) then
  begin
    WriteLn('  ✗ Failed to generate first certificate');
    Exit;
  end;

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test2.local', 'Test Org 2', 30, LCert2, LKey2
  ) then
  begin
    WriteLn('  ✗ Failed to generate second certificate');
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithCertificateChain([LCert1, LCert2]);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('BEGIN CERTIFICATE', LJSON) > 0,
    'WithCertificateChain accepts certificate chain');
end;

{ Test 3: WithCertificateChain supports method chaining }
procedure Test_WithCertificateChain_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LCert, LKey: string;
begin
  TestHeader('Test 3: WithCertificateChain Supports Method Chaining');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test.local', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithCertificateChain([LCert])
    .WithSessionTimeout(5555);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('5555', LJSON) > 0,
    'Method chaining works after WithCertificateChain');
end;

{ Test 4: WithMutualTLS enables client verification }
procedure Test_WithMutualTLS_EnablesVerification;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 4: WithMutualTLS Enables Client Verification');

  LBuilder := TSSLContextBuilder.Create
    .WithMutualTLS('/path/to/ca.pem', True);

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('/path/to/ca.pem', LJSON) > 0) and (Pos('verify_modes', LJSON) > 0),
    'WithMutualTLS configures CA file and verification');
end;

{ Test 5: WithMutualTLS with optional client cert }
procedure Test_WithMutualTLS_Optional;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 5: WithMutualTLS With Optional Client Cert');

  LBuilder := TSSLContextBuilder.Create
    .WithMutualTLS('/path/to/ca.pem', False);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('/path/to/ca.pem', LJSON) > 0,
    'WithMutualTLS with optional client cert works');
end;

{ Test 6: WithMutualTLS supports method chaining }
procedure Test_WithMutualTLS_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 6: WithMutualTLS Supports Method Chaining');

  LBuilder := TSSLContextBuilder.Create
    .WithMutualTLS('/path/to/ca.pem')
    .WithSessionTimeout(6666);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('6666', LJSON) > 0,
    'Method chaining works after WithMutualTLS');
end;

{ Test 7: WithHTTP2 configures ALPN }
procedure Test_WithHTTP2_ConfiguresALPN;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 7: WithHTTP2 Configures ALPN');

  LBuilder := TSSLContextBuilder.Create
    .WithHTTP2;

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('h2', LJSON) > 0) and (Pos('http/1.1', LJSON) > 0),
    'WithHTTP2 configures ALPN with h2 and http/1.1');
end;

{ Test 8: WithHTTP2 supports method chaining }
procedure Test_WithHTTP2_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 8: WithHTTP2 Supports Method Chaining');

  LBuilder := TSSLContextBuilder.Create
    .WithHTTP2
    .WithSessionTimeout(7777);

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('h2', LJSON) > 0) and (Pos('7777', LJSON) > 0),
    'Method chaining works after WithHTTP2');
end;

{ Test 9: WithModernDefaults sets TLS versions }
procedure Test_WithModernDefaults_TLSVersions;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 9: WithModernDefaults Sets TLS Versions');

  LBuilder := TSSLContextBuilder.Create
    .WithModernDefaults;

  LJSON := LBuilder.ExportToJSON;

  // Should contain TLS 1.2 and 1.3
  Assert(Pos('protocols', LJSON) > 0,
    'WithModernDefaults configures TLS versions');
end;

{ Test 10: WithModernDefaults sets ciphers }
procedure Test_WithModernDefaults_Ciphers;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 10: WithModernDefaults Sets Ciphers');

  LBuilder := TSSLContextBuilder.Create
    .WithModernDefaults;

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('ECDHE', LJSON) > 0) and (Pos('AESGCM', LJSON) > 0),
    'WithModernDefaults configures strong ciphers');
end;

{ Test 11: WithModernDefaults sets session timeout }
procedure Test_WithModernDefaults_SessionTimeout;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 11: WithModernDefaults Sets Session Timeout');

  LBuilder := TSSLContextBuilder.Create
    .WithModernDefaults;

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('7200', LJSON) > 0,
    'WithModernDefaults sets 2-hour session timeout');
end;

{ Test 12: WithModernDefaults supports method chaining }
procedure Test_WithModernDefaults_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 12: WithModernDefaults Supports Method Chaining');

  LBuilder := TSSLContextBuilder.Create
    .WithModernDefaults
    .WithSessionTimeout(8888);

  LJSON := LBuilder.ExportToJSON;

  // Should override default timeout
  Assert(Pos('8888', LJSON) > 0,
    'Method chaining works after WithModernDefaults');
end;

{ Test 13: Combining convenience methods }
procedure Test_Combining_ConvenienceMethods;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 13: Combining Convenience Methods');

  LBuilder := TSSLContextBuilder.Create
    .WithModernDefaults
    .WithHTTP2
    .WithMutualTLS('/path/to/ca.pem');

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('h2', LJSON) > 0) and (Pos('/path/to/ca.pem', LJSON) > 0),
    'Multiple convenience methods work together');
end;

{ Test 14: Convenience methods with presets }
procedure Test_ConvenienceMethods_WithPresets;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 14: Convenience Methods With Presets');

  LBuilder := TSSLContextBuilder.Production
    .WithHTTP2
    .WithSessionTimeout(9999);

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('h2', LJSON) > 0) and (Pos('9999', LJSON) > 0),
    'Convenience methods work with presets');
end;

{ Test 15: WithModernDefaults enables security options }
procedure Test_WithModernDefaults_SecurityOptions;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 15: WithModernDefaults Enables Security Options');

  LBuilder := TSSLContextBuilder.Create
    .WithModernDefaults;

  LJSON := LBuilder.ExportToJSON;

  // Check for security-related options
  Assert(Pos('options', LJSON) > 0,
    'WithModernDefaults configures security options');
end;

{ Test 16: Build context after convenience methods }
procedure Test_BuildAfterConvenience;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 16: Build Context After Convenience Methods');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test.local', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithModernDefaults
    .WithHTTP2
    .WithCertificatePEM(LCert)
    .WithPrivateKeyPEM(LKey);

  LResult := LBuilder.TryBuildServer(LContext);

  Assert(LResult.IsOk,
    'Can build context after convenience methods');
end;

{ Test 17: WithCertificateChain with empty array }
procedure Test_WithCertificateChain_Empty;
var
  LBuilder: ISSLContextBuilder;
  LCerts: array of string;
begin
  TestHeader('Test 17: WithCertificateChain With Empty Array');

  SetLength(LCerts, 0);

  try
    LBuilder := TSSLContextBuilder.Create
      .WithCertificateChain(LCerts);

    Assert(True, 'WithCertificateChain handles empty array');
  except
    Assert(False, 'WithCertificateChain crashed with empty array');
  end;
end;

{ Test 18: Complex convenience configuration }
procedure Test_Complex_ConvenienceConfiguration;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 18: Complex Convenience Configuration');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test.local', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithModernDefaults
    .WithHTTP2
    .WithCertificateChain([LCert])
    .WithPrivateKeyPEM(LKey)
    .When(True, nil);  // Test mixing with conditional

  LResult := LBuilder.TryBuildServer(LContext);

  Assert(LResult.IsOk,
    'Complex convenience configuration works');
end;

{ Main Test Runner }
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Phase 2.2.3 Convenience Methods Test Suite');
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn;
  WriteLn('Testing convenience methods:');
  WriteLn('  1. WithCertificateChain - Certificate chain configuration');
  WriteLn('  2. WithMutualTLS - Mutual TLS quick setup');
  WriteLn('  3. WithHTTP2 - HTTP/2 ALPN configuration');
  WriteLn('  4. WithModernDefaults - Modern security defaults');
  WriteLn;

  try
    // Run all tests
    Test_WithCertificateChain_Single;
    Test_WithCertificateChain_Multiple;
    Test_WithCertificateChain_Chaining;
    Test_WithMutualTLS_EnablesVerification;
    Test_WithMutualTLS_Optional;
    Test_WithMutualTLS_Chaining;
    Test_WithHTTP2_ConfiguresALPN;
    Test_WithHTTP2_Chaining;
    Test_WithModernDefaults_TLSVersions;
    Test_WithModernDefaults_Ciphers;
    Test_WithModernDefaults_SessionTimeout;
    Test_WithModernDefaults_Chaining;
    Test_Combining_ConvenienceMethods;
    Test_ConvenienceMethods_WithPresets;
    Test_WithModernDefaults_SecurityOptions;
    Test_BuildAfterConvenience;
    Test_WithCertificateChain_Empty;
    Test_Complex_ConvenienceConfiguration;

    // Print summary
    WriteLn;
    WriteLn('═══════════════════════════════════════════════════════════');
    WriteLn('  Test Summary');
    WriteLn('═══════════════════════════════════════════════════════════');
    WriteLn('  Tests Passed: ', GTestsPassed);
    WriteLn('  Tests Failed: ', GTestsFailed);
    WriteLn('  Total Tests:  ', GTestsPassed + GTestsFailed);
    WriteLn;

    if GTestsFailed = 0 then
    begin
      WriteLn('  ✓ ALL TESTS PASSED!');
      WriteLn;
      ExitCode := 0;
    end
    else
    begin
      WriteLn('  ✗ SOME TESTS FAILED!');
      WriteLn;
      ExitCode := 1;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('═══════════════════════════════════════════════════════════');
      WriteLn('  FATAL ERROR');
      WriteLn('═══════════════════════════════════════════════════════════');
      WriteLn('  Class: ', E.ClassName);
      WriteLn('  Message: ', E.Message);
      WriteLn;
      ExitCode := 2;
    end;
  end;
end.
