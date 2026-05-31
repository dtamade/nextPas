program test_backend_selector_minimum_score_filtering;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.backend.selector,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.freepascal.lib;

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

procedure Test_MinSecurityScore_FiltersOutZeroScoreBackends;
var
  LRequirements: TSSLRequirements;
  LResults: TSSLBackendMatchArray;
begin
  TestHeader('Test 1: Minimum Security Score Filters Zero-Score Backends');

  LRequirements := CreateDefaultRequirements(optBalanced);
  LRequirements.MinSecurityScore := 95;

  LResults := SelectBestBackends(LRequirements, 10);

  Assert(Length(LResults) = 0,
    'SelectBestBackends excludes backends that fail minimum security score');
end;

begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Backend Selector Minimum Score Filtering Test Suite');
  WriteLn('═══════════════════════════════════════════════════════════');

  try
    Test_MinSecurityScore_FiltersOutZeroScoreBackends;

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
      ExitCode := 0;
    end
    else
    begin
      WriteLn('  ✗ SOME TESTS FAILED!');
      ExitCode := 1;
    end;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
