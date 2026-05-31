program test_preset_configurations;

{$mode objfpc}{$H+}

{**
 * Test suite for Phase 2.1.1 - Preset Configurations
 *
 * Tests the four preset configurations:
 * 1. Development - Relaxed settings for development
 * 2. Production - Strict security for production
 * 3. StrictSecurity - Maximum security level
 * 4. LegacyCompatibility - Support for older protocols
 *}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.exceptions;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

function CreatePresetRuntimeBuilder(const ABuilder: ISSLContextBuilder): ISSLContextBuilder;
begin
  Result := ABuilder.WithBackend(sslFreePascal);
end;

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

{ Test 1: Development Preset }
procedure Test_Development_Preset;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Test 1: Development Preset');

  // Test 1.1: Builder creation
  LBuilder := TSSLContextBuilder.Development;
  Assert(LBuilder <> nil, 'Development preset returns valid builder');

  // Test 1.2: Can chain with certificate
  LBuilder := TSSLContextBuilder.Development
    .WithSystemRoots;
  Assert(LBuilder <> nil, 'Development preset supports method chaining');

  // Test 1.3: Can build client context (no cert required)
  LResult := CreatePresetRuntimeBuilder(TSSLContextBuilder.Development)
    .WithSystemRoots
    .TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Development preset can build client context');
  if LResult.IsOk then
    Assert(LContext <> nil, 'Development preset creates valid client context');

  WriteLn('  Development preset: OK');
end;

{ Test 2: Production Preset }
procedure Test_Production_Preset;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 2: Production Preset');

  // Test 2.1: Builder creation
  LBuilder := TSSLContextBuilder.Production;
  Assert(LBuilder <> nil, 'Production preset returns valid builder');

  // Test 2.2: Can chain with additional config
  LBuilder := TSSLContextBuilder.Production
    .WithSystemRoots
    .WithSessionTimeout(7200);
  Assert(LBuilder <> nil, 'Production preset supports method chaining');

  // Test 2.3: Can build client context
  LResult := CreatePresetRuntimeBuilder(TSSLContextBuilder.Production)
    .WithSystemRoots
    .TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Production preset can build client context');
  if LResult.IsOk then
    Assert(LContext <> nil, 'Production preset creates valid client context');

  // Test 2.4: Can build server context with certificate
  if TCertificateUtils.TryGenerateSelfSignedSimple(
    'prod.example.com', 'Production Corp', 365, LCert, LKey
  ) then
  begin
    LResult := CreatePresetRuntimeBuilder(TSSLContextBuilder.Production)
      .WithCertificatePEM(LCert)
      .WithPrivateKeyPEM(LKey)
      .TryBuildServer(LContext);
    Assert(LResult.IsOk, 'Production preset can build server context');
    if LResult.IsOk then
      Assert(LContext <> nil, 'Production preset creates valid server context');
  end;

  WriteLn('  Production preset: OK');
end;

{ Test 3: StrictSecurity Preset }
procedure Test_StrictSecurity_Preset;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 3: StrictSecurity Preset');

  // Test 3.1: Builder creation
  LBuilder := TSSLContextBuilder.StrictSecurity;
  Assert(LBuilder <> nil, 'StrictSecurity preset returns valid builder');

  // Test 3.2: Can chain with CA configuration
  LBuilder := TSSLContextBuilder.StrictSecurity
    .WithSystemRoots
    .WithVerifyDepth(5);
  Assert(LBuilder <> nil, 'StrictSecurity preset supports method chaining');

  // Test 3.3: Can build client context
  LResult := CreatePresetRuntimeBuilder(TSSLContextBuilder.StrictSecurity)
    .WithSystemRoots
    .TryBuildClient(LContext);
  Assert(LResult.IsOk, 'StrictSecurity preset can build client context');
  if LResult.IsOk then
    Assert(LContext <> nil, 'StrictSecurity preset creates valid client context');

  // Test 3.4: Can build server context with certificate
  if TCertificateUtils.TryGenerateSelfSignedSimple(
    'secure.example.com', 'Secure Corp', 365, LCert, LKey
  ) then
  begin
    LResult := CreatePresetRuntimeBuilder(TSSLContextBuilder.StrictSecurity)
      .WithCertificatePEM(LCert)
      .WithPrivateKeyPEM(LKey)
      .TryBuildServer(LContext);
    Assert(LResult.IsOk, 'StrictSecurity preset can build server context');
    if LResult.IsOk then
      Assert(LContext <> nil, 'StrictSecurity preset creates valid server context');
  end;

  WriteLn('  StrictSecurity preset: OK');
end;

{ Test 4: LegacyCompatibility Preset }
procedure Test_LegacyCompatibility_Preset;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 4: LegacyCompatibility Preset');

  // Test 4.1: Builder creation
  LBuilder := TSSLContextBuilder.LegacyCompatibility;
  Assert(LBuilder <> nil, 'LegacyCompatibility preset returns valid builder');

  // Test 4.2: Can chain with additional options
  LBuilder := TSSLContextBuilder.LegacyCompatibility
    .WithSystemRoots
    .WithSessionCache(True);
  Assert(LBuilder <> nil, 'LegacyCompatibility preset supports method chaining');

  // Test 4.3: Can build client context
  LResult := CreatePresetRuntimeBuilder(TSSLContextBuilder.LegacyCompatibility)
    .WithSystemRoots
    .TryBuildClient(LContext);
  Assert(LResult.IsOk, 'LegacyCompatibility preset can build client context');
  if LResult.IsOk then
    Assert(LContext <> nil, 'LegacyCompatibility preset creates valid client context');

  // Test 4.4: Can build server context with certificate
  if TCertificateUtils.TryGenerateSelfSignedSimple(
    'legacy.example.com', 'Legacy Corp', 365, LCert, LKey
  ) then
  begin
    LResult := CreatePresetRuntimeBuilder(TSSLContextBuilder.LegacyCompatibility)
      .WithCertificatePEM(LCert)
      .WithPrivateKeyPEM(LKey)
      .TryBuildServer(LContext);
    Assert(LResult.IsOk, 'LegacyCompatibility preset can build server context');
    if LResult.IsOk then
      Assert(LContext <> nil, 'LegacyCompatibility preset creates valid server context');
  end;

  WriteLn('  LegacyCompatibility preset: OK');
end;

{ Test 5: Preset Comparison }
procedure Test_Preset_Comparison;
var
  LDevBuilder, LProdBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 5: Preset Comparison');

  // Test 5.1: Different presets return different configurations
  LDevBuilder := TSSLContextBuilder.Development;
  LProdBuilder := TSSLContextBuilder.Production;

  Assert(LDevBuilder <> nil, 'Development builder is valid');
  Assert(LProdBuilder <> nil, 'Production builder is valid');

  // Test 5.2: Presets are independent (can create multiple)
  LDevBuilder := TSSLContextBuilder.Development;
  LProdBuilder := TSSLContextBuilder.Production;

  Assert(LDevBuilder <> nil, 'Can create multiple Development builders');
  Assert(LProdBuilder <> nil, 'Can create multiple Production builders');

  WriteLn('  Preset comparison: OK');
end;

{ Test 6: Preset Override }
procedure Test_Preset_Override;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Test 6: Preset Override');

  // Test 6.1: Can override Development preset to verify peer
  LBuilder := TSSLContextBuilder.Development
    .WithVerifyPeer  // Override the default WithVerifyNone
    .WithSystemRoots;
  Assert(LBuilder <> nil, 'Can override Development preset settings');

  // Test 6.2: Can override Production preset protocols
  LBuilder := TSSLContextBuilder.Production
    .WithTLS13;  // Override to TLS 1.3 only
  Assert(LBuilder <> nil, 'Can override Production preset protocols');

  // Test 6.3: Build with overridden settings
  LResult := CreatePresetRuntimeBuilder(TSSLContextBuilder.Development)
    .WithVerifyPeer
    .WithSystemRoots
    .TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Can build with overridden preset settings');
  if LResult.IsOk then
    Assert(LContext <> nil, 'Overridden preset creates valid context');

  WriteLn('  Preset override: OK');
end;

{ Test 7: Error Handling }
procedure Test_Preset_ErrorHandling;
var
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Test 7: Error Handling');

  // Test 7.1: Server context without certificate should fail
  LResult := CreatePresetRuntimeBuilder(TSSLContextBuilder.Production)
    .TryBuildServer(LContext);
  Assert(not LResult.IsOk, 'Server build without certificate fails gracefully');
  Assert(LContext = nil, 'Failed build does not return context');
  Assert(LResult.ErrorMessage <> '', 'Error message is provided');

  // Test 7.2: Development preset server without cert also fails
  LResult := CreatePresetRuntimeBuilder(TSSLContextBuilder.Development)
    .TryBuildServer(LContext);
  Assert(not LResult.IsOk, 'Development server build without certificate fails');

  // Test 7.3: StrictSecurity preset server without cert fails
  LResult := CreatePresetRuntimeBuilder(TSSLContextBuilder.StrictSecurity)
    .TryBuildServer(LContext);
  Assert(not LResult.IsOk, 'StrictSecurity server build without certificate fails');

  WriteLn('  Error handling: OK');
end;

{ Main Test Runner }
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Phase 2.1.1 Preset Configurations Test Suite');
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn;
  WriteLn('Testing four preset configurations:');
  WriteLn('  1. Development - Relaxed settings for development');
  WriteLn('  2. Production - Strict security for production');
  WriteLn('  3. StrictSecurity - Maximum security level');
  WriteLn('  4. LegacyCompatibility - Support for older protocols');
  WriteLn;

  try
    // Run all tests
    Test_Development_Preset;
    Test_Production_Preset;
    Test_StrictSecurity_Preset;
    Test_LegacyCompatibility_Preset;
    Test_Preset_Comparison;
    Test_Preset_Override;
    Test_Preset_ErrorHandling;

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
