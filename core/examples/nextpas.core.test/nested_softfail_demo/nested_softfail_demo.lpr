{ nested_softfail_demo — parent + leaf SoftFail layering (v8.21+ Go t.Run)
  =========================================================
  Parent SoftFail is preserved across Ctx.Run; leaf SoftFail marks the leaf.
  Exit 1 expected.
    make -C core/examples/nextpas.core.test/nested_softfail_demo run
}

program nested_softfail_demo;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.test,
  nextpas.core.test.base;

var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LParentMsg, LLeafMsg: string;
begin
  WriteLn('=== nested_softfail_demo (expect fail) ===');
  LSuite := TTestSuite.Create('nested-soft');
  LSuite.TestSubtest('parent',
    procedure(constref Ctx: ITestContext)
    begin
      SoftFail('parent-soft');
      Ctx.Run('leaf', procedure
        begin
          SoftFail('leaf-soft');
        end);
    end);
  if LSuite.RunWithResult(LResult) then
  begin
    WriteLn('nested_softfail_demo-status=unexpected-pass');
    Halt(2);
  end;
  LParentMsg := '';
  LLeafMsg := '';
  for I := 0 to High(LResult.Results) do
  begin
    if LResult.Results[I].Name = 'parent' then
      LParentMsg := LResult.Results[I].Message
    else if LResult.Results[I].Name = 'parent/leaf' then
      LLeafMsg := LResult.Results[I].Message;
  end;
  WriteLn('parent-message=', LParentMsg);
  WriteLn('leaf-message=', LLeafMsg);
  WriteLn('nested_softfail_demo-status=fail-as-expected');
  Halt(1);
end.
