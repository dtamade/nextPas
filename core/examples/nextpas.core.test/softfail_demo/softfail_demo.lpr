{ softfail_demo — intentional SoftFail multi-message join (exit 1 expected)
  =========================================================
  Demonstrates Go t.Error-style SoftFail: body continues, suite fails with
  joined messages. v8.27 also shows SoftCheckEqual(Bool) + SoftCheckNear.
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
      { v8.27: SoftCheck Bool/Near surface in consumer demo }
      SoftCheckEqual(True, False, 'bool soft');
      SoftCheckNear(1.0, 2.0, 1e-9, 'near soft');
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
