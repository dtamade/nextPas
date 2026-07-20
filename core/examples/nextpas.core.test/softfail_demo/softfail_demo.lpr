{ softfail_demo — intentional SoftFail multi-message join (exit 1 expected)
  =========================================================
  Demonstrates Go t.Error-style SoftFail: body continues, suite fails with
  joined messages "a; b; c".
  Build/run (expect non-zero exit):
    make -C core/examples/nextpas.core.test/softfail_demo run
}

program softfail_demo;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.test,
  nextpas.core.test.base;

var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  WriteLn('=== nextpas.core.test softfail_demo (expect fail) ===');
  LSuite := TTestSuite.Create('soft-demo');
  LSuite.Test('multi soft', procedure
    begin
      SoftFail('alpha');
      SoftFail('beta');
      SoftFail('gamma');
      { body continues after SoftFail }
      SoftCheckTrue(True);
    end);
  if LSuite.RunWithResult(LResult) then
  begin
    WriteLn('softfail_demo-status=unexpected-pass');
    Halt(2);
  end;
  WriteLn('message=', LResult.Results[0].Message);
  WriteLn('softfail_demo-status=fail-as-expected');
  { exit 1: consumers should treat SoftFail as suite failure }
  Halt(1);
end.
