program test_batch_config;

{$mode objfpc}{$H+}

{**
 * Test suite for Phase 2.2.2 - Batch Configuration
 *
 * Tests the batch configuration functionality:
 * 1. Apply - Execute configuration procedure unconditionally
 * 2. ApplyPreset - Merge configuration from another builder
 * 3. Pipe - Functional pipeline style (alias for Apply)
 *}

uses
  SysUtils,
  fpjson, jsonparser,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.freepascal.lib;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;
  GConfigExecuted: Boolean = False;
  GExecutionCount: Integer = 0;

function CreateRuntimeBuilder: ISSLContextBuilder;
begin
  Result := TSSLContextBuilder.Create.WithBackend(sslFreePascal);
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

function ParseBuilderJSON(ABuilder: ISSLContextBuilder): TJSONObject;
begin
  Result := TJSONObject(GetJSON(ABuilder.ExportToJSON));
end;

{ Global config procedures for testing }

procedure SetConfigFlag(ABuilder: ISSLContextBuilder);
begin
  GConfigExecuted := True;
  ABuilder.WithVerifyNone;
end;

procedure IncrementCounter(ABuilder: ISSLContextBuilder);
begin
  Inc(GExecutionCount);
end;

procedure SetCipherList(ABuilder: ISSLContextBuilder);
begin
  ABuilder.WithCipherList('ECDHE+AESGCM');
end;

procedure SetSessionTimeout(ABuilder: ISSLContextBuilder);
begin
  ABuilder.WithSessionTimeout(7200);
end;

procedure ConfigureDevEnvironment(ABuilder: ISSLContextBuilder);
begin
  ABuilder
    .WithVerifyNone
    .WithSessionCache(False);
end;

procedure ConfigureProdEnvironment(ABuilder: ISSLContextBuilder);
begin
  ABuilder
    .WithVerifyPeer
    .WithSessionCache(True);
end;

{ Test 1: Apply executes config procedure }
procedure Test_Apply_ExecutesConfig;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 1: Apply Executes Config Procedure');

  GConfigExecuted := False;
  LBuilder := TSSLContextBuilder.Create
    .Apply(@SetConfigFlag);

  Assert(GConfigExecuted, 'Apply executes config procedure');
end;

{ Test 2: Apply with nil config does not crash }
procedure Test_Apply_NilConfig;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 2: Apply With Nil Config');

  try
    LBuilder := TSSLContextBuilder.Create
      .Apply(nil);

    Assert(True, 'Apply with nil config does not crash');
  except
    Assert(False, 'Apply with nil config crashed');
  end;
end;

{ Test 3: Apply supports method chaining }
procedure Test_Apply_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 3: Apply Supports Method Chaining');

  LBuilder := TSSLContextBuilder.Create
    .Apply(@SetCipherList)
    .WithSessionTimeout(3600);

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('3600', LJSON) > 0) and (Pos('ECDHE+AESGCM', LJSON) > 0),
    'Method chaining works after Apply');
end;

{ Test 4: Apply modifies builder configuration }
procedure Test_Apply_ModifiesConfig;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 4: Apply Modifies Builder Configuration');

  LBuilder := TSSLContextBuilder.Create
    .Apply(@SetSessionTimeout);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('7200', LJSON) > 0, 'Apply modifies builder configuration');
end;

{ Test 5: Multiple Apply calls }
procedure Test_Multiple_Apply;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 5: Multiple Apply Calls');

  GExecutionCount := 0;
  LBuilder := TSSLContextBuilder.Create
    .Apply(@IncrementCounter)
    .Apply(@IncrementCounter)
    .Apply(@IncrementCounter);

  Assert(GExecutionCount = 3, 'Multiple Apply calls execute correctly');
end;

{ Test 6: ApplyPreset merges configuration }
procedure Test_ApplyPreset_Merges;
var
  LBuilder, LPreset: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 6: ApplyPreset Merges Configuration');

  LPreset := TSSLContextBuilder.Create
    .WithSessionTimeout(9999)
    .WithCipherList('CUSTOM-CIPHER');

  LBuilder := TSSLContextBuilder.Create
    .ApplyPreset(LPreset);

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('9999', LJSON) > 0) and (Pos('CUSTOM-CIPHER', LJSON) > 0),
    'ApplyPreset merges configuration from preset');
end;

{ Test 7: ApplyPreset with nil does not crash }
procedure Test_ApplyPreset_Nil;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 7: ApplyPreset With Nil Preset');

  try
    LBuilder := TSSLContextBuilder.Create
      .ApplyPreset(nil);

    Assert(True, 'ApplyPreset with nil does not crash');
  except
    Assert(False, 'ApplyPreset with nil crashed');
  end;
end;

{ Test 8: ApplyPreset supports method chaining }
procedure Test_ApplyPreset_Chaining;
var
  LBuilder, LPreset: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 8: ApplyPreset Supports Method Chaining');

  LPreset := TSSLContextBuilder.Create
    .WithSessionTimeout(5000);

  LBuilder := TSSLContextBuilder.Create
    .ApplyPreset(LPreset)
    .WithVerifyNone;

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('5000', LJSON) > 0, 'Method chaining works after ApplyPreset');
end;

{ Test 9: ApplyPreset with Production preset }
procedure Test_ApplyPreset_WithProduction;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 9: ApplyPreset With Production Preset');

  LBuilder := TSSLContextBuilder.Create
    .ApplyPreset(TSSLContextBuilder.Production);

  LJSON := LBuilder.ExportToJSON;

  // Production preset should have session cache enabled
  Assert(Pos('session_cache_enabled', LJSON) > 0,
    'ApplyPreset works with Production preset');
end;

{ Test 10: ApplyPreset overrides configuration }
procedure Test_ApplyPreset_Overrides;
var
  LBuilder, LPreset: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 10: ApplyPreset Overrides Configuration');

  LPreset := TSSLContextBuilder.Create
    .WithSessionTimeout(8888);

  LBuilder := TSSLContextBuilder.Create
    .WithSessionTimeout(1111)
    .ApplyPreset(LPreset);

  LJSON := LBuilder.ExportToJSON;

  // Preset should override original value
  Assert(Pos('8888', LJSON) > 0, 'ApplyPreset overrides existing configuration');
end;

{ Test 11: Pipe behaves like Apply }
procedure Test_Pipe_BehavesLikeApply;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 11: Pipe Behaves Like Apply');

  GConfigExecuted := False;
  LBuilder := TSSLContextBuilder.Create
    .Pipe(@SetConfigFlag);

  Assert(GConfigExecuted, 'Pipe executes config procedure like Apply');
end;

{ Test 12: Pipe supports method chaining }
procedure Test_Pipe_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 12: Pipe Supports Method Chaining');

  LBuilder := TSSLContextBuilder.Create
    .Pipe(@SetCipherList)
    .WithSessionTimeout(4444);

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('4444', LJSON) > 0) and (Pos('ECDHE+AESGCM', LJSON) > 0),
    'Method chaining works after Pipe');
end;

{ Test 13: Multiple Pipe calls (pipeline) }
procedure Test_Pipe_Pipeline;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 13: Multiple Pipe Calls (Pipeline)');

  GExecutionCount := 0;
  LBuilder := TSSLContextBuilder.Create
    .Pipe(@IncrementCounter)
    .Pipe(@IncrementCounter)
    .Pipe(@IncrementCounter)
    .Pipe(@IncrementCounter);

  Assert(GExecutionCount = 4, 'Pipe creates functional pipeline');
end;

{ Test 14: Combining Apply with other methods }
procedure Test_Apply_WithConditional;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 14: Combining Apply With Conditional');

  LBuilder := TSSLContextBuilder.Create
    .Apply(@ConfigureDevEnvironment)
    .When(True, @SetCipherList);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('ECDHE+AESGCM', LJSON) > 0,
    'Apply works with conditional methods');
end;

{ Test 15: Combining ApplyPreset with presets }
procedure Test_ApplyPreset_WithDevelopment;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 15: Combining ApplyPreset With Development');

  LBuilder := TSSLContextBuilder.Development
    .ApplyPreset(TSSLContextBuilder.Create.WithSessionTimeout(6666));

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('6666', LJSON) > 0,
    'ApplyPreset works with preset builders');
end;

{ Test 16: Build context after batch configuration }
procedure Test_BuildAfterBatch;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 16: Build Context After Batch Configuration');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test.local', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuilder := CreateRuntimeBuilder
    .Apply(@ConfigureProdEnvironment)
    .WithCertificatePEM(LCert)
    .WithPrivateKeyPEM(LKey);

  LResult := LBuilder.TryBuildServer(LContext);

  Assert(LResult.IsOk, 'Can build context after batch configuration');
end;

{ Test 17: Apply and Pipe are equivalent }
procedure Test_Apply_Pipe_Equivalent;
var
  LBuilder1, LBuilder2: ISSLContextBuilder;
  LJSON1, LJSON2: string;
begin
  TestHeader('Test 17: Apply And Pipe Are Equivalent');

  LBuilder1 := TSSLContextBuilder.Create
    .Apply(@SetSessionTimeout);

  LBuilder2 := TSSLContextBuilder.Create
    .Pipe(@SetSessionTimeout);

  LJSON1 := LBuilder1.ExportToJSON;
  LJSON2 := LBuilder2.ExportToJSON;

  Assert((Pos('7200', LJSON1) > 0) and (Pos('7200', LJSON2) > 0),
    'Apply and Pipe produce equivalent results');
end;

{ Test 18: Complex batch configuration pipeline }
procedure Test_Complex_Pipeline;
var
  LBuilder, LPreset: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 18: Complex Batch Configuration Pipeline');

  LPreset := TSSLContextBuilder.Create
    .WithSessionTimeout(3333);

  LBuilder := TSSLContextBuilder.Production
    .Apply(@ConfigureDevEnvironment)
    .ApplyPreset(LPreset)
    .Pipe(@SetCipherList);

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('3333', LJSON) > 0) and (Pos('ECDHE+AESGCM', LJSON) > 0),
    'Complex pipeline executes all steps correctly');
end;

{ Test 19: ApplyPreset file sources clear stale PEM state }
procedure Test_ApplyPreset_FileSources_ClearStalePEMState;
var
  LBuilder, LPreset: ISSLContextBuilder;
  LObj: TJSONObject;
begin
  TestHeader('Test 19: ApplyPreset File Sources Clear Stale PEM State');

  LPreset := TSSLContextBuilder.Create
    .WithCertificate('/tmp/preset-cert-file.pem')
    .WithPrivateKey('/tmp/preset-private-key.pem');

  LBuilder := TSSLContextBuilder.Create
    .WithCertificatePEM('stale-builder-cert-pem')
    .WithPrivateKeyPEM('stale-builder-private-key-pem')
    .ApplyPreset(LPreset);

  LObj := ParseBuilderJSON(LBuilder);
  try
    Assert(LObj.Strings['certificate_file'] = '/tmp/preset-cert-file.pem',
      'ApplyPreset keeps preset certificate_file export-visible');
    Assert(LObj.Strings['certificate_pem'] = '',
      'ApplyPreset(certificate_file) clears stale certificate_pem state');
    Assert(LObj.Strings['private_key_file'] = '/tmp/preset-private-key.pem',
      'ApplyPreset keeps preset private_key_file export-visible');
    Assert(LObj.Strings['private_key_pem'] = '',
      'ApplyPreset(private_key_file) clears stale private_key_pem state');
  finally
    LObj.Free;
  end;
end;

{ Test 20: ApplyPreset PEM sources clear stale file state }
procedure Test_ApplyPreset_PEMSources_ClearStaleFileState;
var
  LBuilder, LPreset: ISSLContextBuilder;
  LObj: TJSONObject;
begin
  TestHeader('Test 20: ApplyPreset PEM Sources Clear Stale File State');

  LPreset := TSSLContextBuilder.Create
    .WithCertificatePEM('preset-certificate-pem')
    .WithPrivateKeyPEM('preset-private-key-pem');

  LBuilder := TSSLContextBuilder.Create
    .WithCertificate('/tmp/stale-builder-cert-file.pem')
    .WithPrivateKey('/tmp/stale-builder-private-key.pem')
    .ApplyPreset(LPreset);

  LObj := ParseBuilderJSON(LBuilder);
  try
    Assert(LObj.Strings['certificate_file'] = '',
      'ApplyPreset(certificate_pem) clears stale certificate_file state');
    Assert(LObj.Strings['certificate_pem'] = 'preset-certificate-pem',
      'ApplyPreset keeps preset certificate_pem export-visible');
    Assert(LObj.Strings['private_key_file'] = '',
      'ApplyPreset(private_key_pem) clears stale private_key_file state');
    Assert(LObj.Strings['private_key_pem'] = 'preset-private-key-pem',
      'ApplyPreset keeps preset private_key_pem export-visible');
  finally
    LObj.Free;
  end;
end;

{ Main Test Runner }
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Phase 2.2.2 Batch Configuration Test Suite');
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn;
  WriteLn('Testing batch configuration methods:');
  WriteLn('  1. Apply - Execute configuration procedure');
  WriteLn('  2. ApplyPreset - Merge configuration from builder');
  WriteLn('  3. Pipe - Functional pipeline style');
  WriteLn;

  try
    // Run all tests
    Test_Apply_ExecutesConfig;
    Test_Apply_NilConfig;
    Test_Apply_Chaining;
    Test_Apply_ModifiesConfig;
    Test_Multiple_Apply;
    Test_ApplyPreset_Merges;
    Test_ApplyPreset_Nil;
    Test_ApplyPreset_Chaining;
    Test_ApplyPreset_WithProduction;
    Test_ApplyPreset_Overrides;
    Test_Pipe_BehavesLikeApply;
    Test_Pipe_Chaining;
    Test_Pipe_Pipeline;
    Test_Apply_WithConditional;
    Test_ApplyPreset_WithDevelopment;
    Test_BuildAfterBatch;
    Test_Apply_Pipe_Equivalent;
    Test_Complex_Pipeline;
    Test_ApplyPreset_FileSources_ClearStalePEMState;
    Test_ApplyPreset_PEMSources_ClearStaleFileState;

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
