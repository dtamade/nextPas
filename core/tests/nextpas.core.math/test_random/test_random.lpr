{
  test_random.lpr
  Tests for nextpas.core.math.random
}
program test_random;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.math.scalar,
  nextpas.core.math.random;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure AssertTrue(const ATestName: string; ACondition: Boolean);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('  PASS: ', ATestName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', ATestName);
  end;
end;

procedure AssertFloatEq(const ATestName: string; const AActual, AExpected, AEpsilon: Double);
begin
  Inc(GTestCount);
  if Abs(AActual - AExpected) <= AEpsilon then
  begin
    Inc(GPassCount);
    WriteLn('  PASS: ', ATestName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', ATestName, ' expected=', AExpected:8:4, ' actual=', AActual:8:4);
  end;
end;

procedure TestDeterminism;
var
  LState1, LState2: TRandomState;
  LVal1, LVal2: UInt64;
  I: Integer;
begin
  WriteLn('TestDeterminism');
  LState1 := RandomCreate(42);
  LState2 := RandomCreate(42);

  for I := 0 to 99 do
  begin
    LVal1 := RandomInt(LState1);
    LVal2 := RandomInt(LState2);
    AssertTrue('determinism step ' + IntToStr(I), LVal1 = LVal2);
  end;
end;

procedure TestRange;
var
  LState: TRandomState;
  LVal: Int64;
  I: Integer;
  LAllInRange: Boolean;
begin
  WriteLn('TestRange');
  LState := RandomCreate(123);
  LAllInRange := True;

  for I := 0 to 999 do
  begin
    LVal := RandomIntRange(LState, 10, 20);
    if (LVal < 10) or (LVal > 20) then
      LAllInRange := False;
  end;
  AssertTrue('range 10-20 all in range', LAllInRange);

  LState := RandomCreate(456);
  LAllInRange := True;
  for I := 0 to 999 do
  begin
    LVal := RandomIntRange(LState, -100, 100);
    if (LVal < -100) or (LVal > 100) then
      LAllInRange := False;
  end;
  AssertTrue('range -100 to 100 all in range', LAllInRange);
end;

procedure TestFloatRange;
var
  LState: TRandomState;
  LVal: Single;
  I: Integer;
  LAllInRange: Boolean;
begin
  WriteLn('TestFloatRange');
  LState := RandomCreate(789);
  LAllInRange := True;

  for I := 0 to 999 do
  begin
    LVal := RandomFloat(LState);
    if (LVal < 0.0) or (LVal > 1.0) then
      LAllInRange := False;
  end;
  AssertTrue('float 0-1 all in range', LAllInRange);

  LState := RandomCreate(101);
  LAllInRange := True;
  for I := 0 to 999 do
  begin
    LVal := RandomFloatRange(LState, -10.0, 10.0);
    if (LVal < -10.0) or (LVal > 10.0) then
      LAllInRange := False;
  end;
  AssertTrue('float range -10 to 10 all in range', LAllInRange);
end;

procedure TestBool;
var
  LState: TRandomState;
  LTrueCount, I: Integer;
begin
  WriteLn('TestBool');
  LState := RandomCreate(111);
  LTrueCount := 0;

  for I := 0 to 999 do
  begin
    if RandomBool(LState) then
      Inc(LTrueCount);
  end;
  // Should be roughly 50% true (allow 40-60%)
  AssertTrue('bool distribution', (LTrueCount > 400) and (LTrueCount < 600));
end;

procedure TestGaussian;
var
  LState: TRandomState;
  LSum, LSumSqr, LMean, LVariance: Double;
  LVal: Double;
  I: Integer;
begin
  WriteLn('TestGaussian');
  LState := RandomCreate(222);
  LSum := 0.0;
  LSumSqr := 0.0;

  for I := 0 to 9999 do
  begin
    LVal := RandomGaussian(LState);
    LSum := LSum + LVal;
    LSumSqr := LSumSqr + LVal * LVal;
  end;

  LMean := LSum / 10000.0;
  LVariance := (LSumSqr / 10000.0) - (LMean * LMean);

  // Mean should be close to 0, variance close to 1
  AssertFloatEq('gaussian mean', LMean, 0.0, 0.1);
  AssertFloatEq('gaussian variance', LVariance, 1.0, 0.2);
end;

procedure TestCircle;
var
  LState: TRandomState;
  LPoint: TPoint2f;
  LLen: Single;
  I: Integer;
begin
  WriteLn('TestCircle');
  LState := RandomCreate(333);

  for I := 0 to 99 do
  begin
    LPoint := RandomPointOnCircle(LState);
    LLen := Sqrt(LPoint.X * LPoint.X + LPoint.Y * LPoint.Y);
    AssertFloatEq('circle radius ' + IntToStr(I), LLen, 1.0, 0.001);
  end;
end;

procedure TestSphere;
var
  LState: TRandomState;
  LPoint: TPoint3f;
  LLen: Single;
  I: Integer;
begin
  WriteLn('TestSphere');
  LState := RandomCreate(444);

  for I := 0 to 99 do
  begin
    LPoint := RandomPointOnSphere(LState);
    LLen := Sqrt(LPoint.X * LPoint.X + LPoint.Y * LPoint.Y + LPoint.Z * LPoint.Z);
    AssertFloatEq('sphere radius ' + IntToStr(I), LLen, 1.0, 0.001);
  end;
end;

procedure TestChoice;
var
  LState: TRandomState;
  LCounts: array[0..4] of Integer;
  LChoice: Integer;
  I: Integer;
begin
  WriteLn('TestChoice');
  LState := RandomCreate(555);

  for I := 0 to 4 do
    LCounts[I] := 0;

  for I := 0 to 9999 do
  begin
    LChoice := RandomChoice(LState, 5);
    AssertTrue('choice in range', (LChoice >= 0) and (LChoice < 5));
    Inc(LCounts[LChoice]);
  end;

  // Each choice should get roughly 20% (allow 15-25%)
  for I := 0 to 4 do
    AssertTrue('choice ' + IntToStr(I) + ' distribution', (LCounts[I] > 1500) and (LCounts[I] < 2500));
end;

begin
  WriteLn('=== nextpas.core.math.random tests ===');
  WriteLn;

  TestDeterminism;
  TestRange;
  TestFloatRange;
  TestBool;
  TestGaussian;
  TestCircle;
  TestSphere;
  TestChoice;

  WriteLn;
  WriteLn('Tests: ', GTestCount, ' | Pass: ', GPassCount, ' | Fail: ', GFailCount);
  if GFailCount > 0 then
  begin
    WriteLn('*** FAILURES DETECTED ***');
    Halt(1);
  end
  else
    WriteLn('All tests passed!');
end.
