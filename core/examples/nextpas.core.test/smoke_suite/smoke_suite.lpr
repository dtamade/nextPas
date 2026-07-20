{ smoke_suite — minimal consumer of nextpas.core.test
  =========================================================
  Demonstrates the happy-path API a third-party suite needs:
    - TTestSuite + named tests
    - Check* (Fatal) assertions
    - SoftFail / SoftCheck* (continue-on-fail, Go t.Error style)
    - TestTable parameterized cases
    - TestSubtest nesting (Go t.Run style)
  Build/run:
    make -C core/examples/nextpas.core.test/smoke_suite run
}

program smoke_suite;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.test.base;

{ ── Pure helpers under test ──────────────────────────────────────────────── }

function Add(const A, B: Integer): Integer;
begin
  Result := A + B;
end;

function Clamp(const AValue, AMin, AMax: Integer): Integer;
begin
  if AValue < AMin then
    Result := AMin
  else if AValue > AMax then
    Result := AMax
  else
    Result := AValue;
end;

{ Parse "v|min|max|want" without SysUtils Split. }
function ParseClampCase(const AData: string; out AValue, AMin, AMax, AWant: Integer): Boolean;
var
  P1, P2, P3: Integer;
begin
  Result := False;
  P1 := Pos('|', AData);
  if P1 < 2 then
    Exit;
  P2 := Pos('|', Copy(AData, P1 + 1, Length(AData)));
  if P2 < 1 then
    Exit;
  P2 := P1 + P2;
  P3 := Pos('|', Copy(AData, P2 + 1, Length(AData)));
  if P3 < 1 then
    Exit;
  P3 := P2 + P3;
  AValue := Integer(StrToInt(Copy(AData, 1, P1 - 1)));
  AMin := Integer(StrToInt(Copy(AData, P1 + 1, P2 - P1 - 1)));
  AMax := Integer(StrToInt(Copy(AData, P2 + 1, P3 - P2 - 1)));
  AWant := Integer(StrToInt(Copy(AData, P3 + 1, Length(AData) - P3)));
  Result := True;
end;

{ ── Tests ────────────────────────────────────────────────────────────────── }

procedure TestAddBasic;
begin
  CheckEqual(Int64(4), Int64(Add(2, 2)));
  CheckEqual(Int64(0), Int64(Add(-1, 1)));
end;

procedure TestSoftDiagnostics;
{ SoftFail continues; SoftCheck* records without raising.
  Happy path only soft-passes so the example suite stays green. }
begin
  SoftCheckEqual(Int64(1), Int64(1));
  SoftCheckTrue(True, 'always true');
  SoftCheckFalse(False, 'always false');
  SoftCheckContains('hello world', 'world');
  CheckTrue(True, 'fatal path still available alongside Soft*');
end;

procedure TestClampCase(const AC: TTestCase);
var
  LValue, LMin, LMax, LWant: Integer;
begin
  CheckTrue(ParseClampCase(AC.Data, LValue, LMin, LMax, LWant),
    'parse clamp case: ' + AC.Data);
  CheckEqual(Int64(LWant), Int64(Clamp(LValue, LMin, LMax)), AC.Name);
end;

procedure TestNestedSubtests(constref Ctx: ITestContext);
begin
  Ctx.Run('zero', procedure
    begin
      CheckEqual(Int64(0), Int64(Clamp(0, 0, 10)));
    end);
  Ctx.Run('mid', procedure
    begin
      CheckEqual(Int64(5), Int64(Clamp(5, 0, 10)));
    end);
  Ctx.Run('high', procedure
    begin
      CheckEqual(Int64(10), Int64(Clamp(99, 0, 10)));
    end);
end;

{ ── Main ─────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LCases: specialize TArray<TTestCase>;
  I: Integer;
const
  CLAMP_ROWS: array[0..5] of string = (
    '0|0|10|0',
    '5|0|10|5',
    '10|0|10|10',
    '-1|0|10|0',
    '11|0|10|10',
    '7|7|7|7'
  );
begin
  WriteLn('=== nextpas.core.test consumer smoke_suite ===');
  LSuite := TTestSuite.Create('smoke');

  LSuite.Test('Add basic', @TestAddBasic);
  LSuite.Test('Soft diagnostics happy path', @TestSoftDiagnostics);
  LSuite.TestSubtest('Nested subtests', @TestNestedSubtests);

  SetLength(LCases, Length(CLAMP_ROWS));
  for I := 0 to High(CLAMP_ROWS) do
  begin
    LCases[I].Name := 'clamp-' + IntToStr(I);
    LCases[I].Data := CLAMP_ROWS[I];
  end;
  LSuite.TestTable('Clamp table', LCases, @TestClampCase);

  if not LSuite.Run then
  begin
    WriteLn('smoke_suite-status=fail');
    Halt(1);
  end;
  WriteLn('smoke_suite-status=pass');
end.
