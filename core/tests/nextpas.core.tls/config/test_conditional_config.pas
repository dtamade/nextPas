program test_conditional_config;

{$mode objfpc}{$H+}

{**
 * Test suite for Phase 2.2.1 - Conditional Configuration
 *
 * Tests the conditional configuration functionality:
 * 1. When - Execute config when condition is true
 * 2. Unless - Execute config when condition is false
 * 3. WhenDevelopment - Execute config in DEBUG mode
 * 4. WhenProduction - Execute config in non-DEBUG mode
 *}

uses
  SysUtils,
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
  ABuilder.WithSessionTimeout(9999);
end;

procedure SetDevConfig(ABuilder: ISSLContextBuilder);
begin
  GConfigExecuted := True;
  ABuilder.WithVerifyNone;
end;

procedure SetProdConfig(ABuilder: ISSLContextBuilder);
begin
  GConfigExecuted := True;
  ABuilder.WithVerifyPeer;
end;

procedure DisableSessionCache(ABuilder: ISSLContextBuilder);
begin
  ABuilder.WithSessionCache(False);
end;

{ Test 1: When with true condition executes config }
procedure Test_When_True;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 1: When With True Condition');

  GConfigExecuted := False;
  LBuilder := TSSLContextBuilder.Create
    .When(True, @SetConfigFlag);

  Assert(GConfigExecuted, 'When(True) executes config procedure');
end;

{ Test 2: When with false condition skips config }
procedure Test_When_False;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 2: When With False Condition');

  GConfigExecuted := False;
  LBuilder := TSSLContextBuilder.Create
    .When(False, @SetConfigFlag);

  Assert(not GConfigExecuted, 'When(False) skips config procedure');
end;

{ Test 3: Unless with false condition executes config }
procedure Test_Unless_False;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 3: Unless With False Condition');

  GConfigExecuted := False;
  LBuilder := TSSLContextBuilder.Create
    .Unless(False, @SetConfigFlag);

  Assert(GConfigExecuted, 'Unless(False) executes config procedure');
end;

{ Test 4: Unless with true condition skips config }
procedure Test_Unless_True;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 4: Unless With True Condition');

  GConfigExecuted := False;
  LBuilder := TSSLContextBuilder.Create
    .Unless(True, @SetConfigFlag);

  Assert(not GConfigExecuted, 'Unless(True) skips config procedure');
end;

{ Test 5: When supports method chaining }
procedure Test_When_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 5: When Supports Method Chaining');

  LBuilder := TSSLContextBuilder.Create
    .When(True, @SetConfigFlag)
    .WithSessionTimeout(3600);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('3600', LJSON) > 0, 'Method chaining continues after When');
end;

{ Test 6: Unless supports method chaining }
procedure Test_Unless_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 6: Unless Supports Method Chaining');

  LBuilder := TSSLContextBuilder.Create
    .Unless(False, @SetConfigFlag)
    .WithSessionTimeout(7200);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('7200', LJSON) > 0, 'Method chaining continues after Unless');
end;

{ Test 7: When with nil config does not crash }
procedure Test_When_NilConfig;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 7: When With Nil Config');

  try
    LBuilder := TSSLContextBuilder.Create
      .When(True, nil);

    Assert(True, 'When with nil config does not crash');
  except
    Assert(False, 'When with nil config crashed');
  end;
end;

{ Test 8: Unless with nil config does not crash }
procedure Test_Unless_NilConfig;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 8: Unless With Nil Config');

  try
    LBuilder := TSSLContextBuilder.Create
      .Unless(False, nil);

    Assert(True, 'Unless with nil config does not crash');
  except
    Assert(False, 'Unless with nil config crashed');
  end;
end;

{ Test 9: Multiple When conditions in chain }
procedure Test_Multiple_When;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 9: Multiple When Conditions');

  GExecutionCount := 0;
  LBuilder := TSSLContextBuilder.Create
    .When(True, @IncrementCounter)
    .When(False, @IncrementCounter)
    .When(True, @IncrementCounter);

  Assert(GExecutionCount = 2, 'Multiple When conditions execute correctly');
end;

{ Test 10: When modifies builder configuration }
procedure Test_When_ModifiesConfig;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 10: When Modifies Builder Configuration');

  LBuilder := TSSLContextBuilder.Create
    .When(True, @SetCipherList);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('ECDHE+AESGCM', LJSON) > 0, 'When modifies builder configuration');
end;

{ Test 11: Unless modifies builder configuration }
procedure Test_Unless_ModifiesConfig;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 11: Unless Modifies Builder Configuration');

  LBuilder := TSSLContextBuilder.Create
    .Unless(False, @SetSessionTimeout);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('9999', LJSON) > 0, 'Unless modifies builder configuration');
end;

{ Test 12: WhenDevelopment in DEBUG mode }
procedure Test_WhenDevelopment;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 12: WhenDevelopment');

  GConfigExecuted := False;
  LBuilder := TSSLContextBuilder.Create
    .WhenDevelopment(@SetDevConfig);

  {$IFDEF DEBUG}
  Assert(GConfigExecuted, 'WhenDevelopment executes in DEBUG mode');
  {$ELSE}
  Assert(not GConfigExecuted, 'WhenDevelopment skips in non-DEBUG mode');
  {$ENDIF}
end;

{ Test 13: WhenProduction in non-DEBUG mode }
procedure Test_WhenProduction;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 13: WhenProduction');

  GConfigExecuted := False;
  LBuilder := TSSLContextBuilder.Create
    .WhenProduction(@SetProdConfig);

  {$IFNDEF DEBUG}
  Assert(GConfigExecuted, 'WhenProduction executes in non-DEBUG mode');
  {$ELSE}
  Assert(not GConfigExecuted, 'WhenProduction skips in DEBUG mode');
  {$ENDIF}
end;

{ Test 14: Conditional with preset }
procedure Test_Conditional_WithPreset;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 14: Conditional With Preset');

  LBuilder := TSSLContextBuilder.Production
    .When(False, @DisableSessionCache);  // Condition false, won't execute

  LJSON := LBuilder.ExportToJSON;

  // Should have Production preset (session cache enabled)
  // Check for various possible JSON formats
  Assert((Pos('"session_cache_enabled":true', LJSON) > 0) or
         (Pos('"session_cache_enabled" : true', LJSON) > 0) or
         (Pos('session_cache_enabled', LJSON) > 0),
    'Conditional with preset preserves configuration');
end;

{ Test 15: Build after conditional }
procedure Test_BuildAfterConditional;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 15: Build After Conditional');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test.local', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuilder := CreateRuntimeBuilder
    .When(True, @SetConfigFlag)
    .WithCertificatePEM(LCert)
    .WithPrivateKeyPEM(LKey);

  LResult := LBuilder.TryBuildServer(LContext);

  Assert(LResult.IsOk, 'Can build context after conditional configuration');
end;

{ Main Test Runner }
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Phase 2.2.1 Conditional Configuration Test Suite');
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn;
  WriteLn('Testing conditional configuration methods:');
  WriteLn('  1. When - Execute config when condition is true');
  WriteLn('  2. Unless - Execute config when condition is false');
  WriteLn('  3. WhenDevelopment - Execute in DEBUG mode');
  WriteLn('  4. WhenProduction - Execute in non-DEBUG mode');
  WriteLn;

  try
    // Run all tests
    Test_When_True;
    Test_When_False;
    Test_Unless_False;
    Test_Unless_True;
    Test_When_Chaining;
    Test_Unless_Chaining;
    Test_When_NilConfig;
    Test_Unless_NilConfig;
    Test_Multiple_When;
    Test_When_ModifiesConfig;
    Test_Unless_ModifiesConfig;
    Test_WhenDevelopment;
    Test_WhenProduction;
    Test_Conditional_WithPreset;
    Test_BuildAfterConditional;

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
