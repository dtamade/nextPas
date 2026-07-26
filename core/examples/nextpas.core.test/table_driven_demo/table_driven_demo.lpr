{ table_driven_demo — consumer: TestTable + SoftCheck + TestSubtest
  =========================================================
  Focused example for table-driven tests with Soft diagnostics and
  nested subtests (Go testing table + t.Error + t.Run style).
  Build/run:
    make -C core/examples/nextpas.core.test/table_driven_demo run
}

program table_driven_demo;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.test.base;

function Mul(const A, B: Integer): Integer;
begin
  Result := A * B;
end;

procedure TestMulCase(const AC: TTestCase);
{ Data: "a|b|want" }
var
  P1, P2: Integer;
  LA, LB, LWant: Integer;
begin
  P1 := Pos('|', AC.Data);
  CheckTrue(P1 > 1, 'parse a|b|want');
  P2 := Pos('|', Copy(AC.Data, P1 + 1, Length(AC.Data)));
  CheckTrue(P2 > 0, 'parse b|want');
  P2 := P1 + P2;
  LA := Integer(StrToInt(Copy(AC.Data, 1, P1 - 1)));
  LB := Integer(StrToInt(Copy(AC.Data, P1 + 1, P2 - P1 - 1)));
  LWant := Integer(StrToInt(Copy(AC.Data, P2 + 1, Length(AC.Data) - P2)));
  SoftCheckEqual(Int64(LWant), Int64(Mul(LA, LB)));
  CheckEqual(Int64(LWant), Int64(Mul(LA, LB)), AC.Name);
end;

procedure TestMulSubtests(constref Ctx: ITestContext);
begin
  Ctx.Run('identity', procedure
    begin
      CheckEqual(Int64(7), Int64(Mul(7, 1)));
    end);
  Ctx.Run('zero', procedure
    begin
      SoftCheckEqual(Int64(0), Int64(Mul(0, 99)));
      CheckEqual(Int64(0), Int64(Mul(0, 99)));
    end);
  Ctx.Run('negative', procedure
    begin
      CheckEqual(Int64(-12), Int64(Mul(-3, 4)));
    end);
end;

var
  LSuite: TTestSuite;
  LCases: specialize TArray<TTestCase>;
  I: Integer;
const
  MUL_ROWS: array[0..5] of string = (
    '2|3|6',
    '0|5|0',
    '1|1|1',
    '-2|4|-8',
    '7|0|0',
    '10|10|100'
  );
begin
  WriteLn('=== nextpas.core.test consumer table_driven_demo ===');
  LSuite := TTestSuite.Create('table-driven');

  SetLength(LCases, Length(MUL_ROWS));
  for I := 0 to High(MUL_ROWS) do
  begin
    LCases[I].Name := 'mul-' + IntToStr(I);
    LCases[I].Data := MUL_ROWS[I];
  end;
  LSuite.TestTable('Mul table + SoftCheck', LCases, @TestMulCase);
  LSuite.TestSubtest('Mul nested subtests', @TestMulSubtests);

  if not LSuite.Run then
  begin
    WriteLn('table_driven_demo-status=fail');
    Halt(1);
  end;
  WriteLn('table_driven_demo-status=pass');
end.
