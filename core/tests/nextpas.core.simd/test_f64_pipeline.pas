program test_f64_pipeline;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.arrays.typed,
  nextpas.core.simd.pipeline.f64;

var
  LData: array[0..7] of Double;
  LOut: array[0..7] of Double;
  LOther: array[0..7] of Double;
  LPipe: TSimdF64Pipeline;
  LSum, LExpected: Double;
  i: Integer;
  LPass: Integer;
  LFail: Integer;

procedure Check(const aName: string; aGot, aExpect: Double; aTol: Double = 1e-10);
begin
  if System.Abs(aGot - aExpect) <= aTol then
  begin
    Inc(LPass);
  end
  else
  begin
    WriteLn('  FAIL ', aName, ': got=', aGot:0:12, ' expect=', aExpect:0:12);
    Inc(LFail);
  end;
end;

begin
  LPass := 0;
  LFail := 0;

  for i := 0 to 7 do LData[i] := i + 1.0;
  for i := 0 to 7 do LOther[i] := (i + 1.0) * 0.5;

  // Test MulScalar
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe.MulScalar(2.0).Into(@LOut[0]);
  for i := 0 to 7 do Check('MulScalar[' + IntToStr(i) + ']', LOut[i], LData[i] * 2.0);

  // Test AddScalar
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe.AddScalar(10.0).Into(@LOut[0]);
  for i := 0 to 7 do Check('AddScalar[' + IntToStr(i) + ']', LOut[i], LData[i] + 10.0);

  // Test Linear (MulScalar + AddScalar fusion)
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe.MulScalar(3.0).AddScalar(1.0).Into(@LOut[0]);
  for i := 0 to 7 do Check('Linear[' + IntToStr(i) + ']', LOut[i], LData[i] * 3.0 + 1.0);

  // Test Neg
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe.Neg.Into(@LOut[0]);
  for i := 0 to 7 do Check('Neg[' + IntToStr(i) + ']', LOut[i], -LData[i]);

  // Test Abs after Neg
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe.Neg.Abs.Into(@LOut[0]);
  for i := 0 to 7 do Check('Neg+Abs[' + IntToStr(i) + ']', LOut[i], LData[i]);

  // Test Square
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe.Square.Into(@LOut[0]);
  for i := 0 to 7 do Check('Square[' + IntToStr(i) + ']', LOut[i], LData[i] * LData[i]);

  // Test Sqrt
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe.Sqrt.Into(@LOut[0]);
  for i := 0 to 7 do Check('Sqrt[' + IntToStr(i) + ']', LOut[i], System.Sqrt(LData[i]), 1e-6);

  // Test Clamp
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe.Clamp(3.0, 6.0).Into(@LOut[0]);
  for i := 0 to 7 do
  begin
    LExpected := LData[i];
    if LExpected < 3.0 then LExpected := 3.0;
    if LExpected > 6.0 then LExpected := 6.0;
    Check('Clamp[' + IntToStr(i) + ']', LOut[i], LExpected);
  end;

  // Test Add array
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe.Add(@LOther[0]).Into(@LOut[0]);
  for i := 0 to 7 do Check('Add[' + IntToStr(i) + ']', LOut[i], LData[i] + LOther[i]);

  // Test Mul array
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe.Mul(@LOther[0]).Into(@LOut[0]);
  for i := 0 to 7 do Check('Mul[' + IntToStr(i) + ']', LOut[i], LData[i] * LOther[i]);

  // Test ReduceSum
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LSum := LPipe.ReduceSum;
  LExpected := 0;
  for i := 0 to 7 do LExpected := LExpected + LData[i];
  Check('ReduceSum', LSum, LExpected);

  // Test ReduceSum with MulScalar (fast path: scalar * sum)
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LSum := LPipe.MulScalar(2.0).ReduceSum;
  Check('ReduceSum(MulScalar)', LSum, LExpected * 2.0);

  // Test ReduceSum with Square (fast path: dot product)
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LSum := LPipe.Square.ReduceSum;
  LExpected := 0;
  for i := 0 to 7 do LExpected := LExpected + LData[i] * LData[i];
  Check('ReduceSum(Square)', LSum, LExpected);

  // Test ReduceDot
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LSum := LPipe.ReduceDot(@LOther[0]);
  LExpected := 0;
  for i := 0 to 7 do LExpected := LExpected + LData[i] * LOther[i];
  Check('ReduceDot', LSum, LExpected);

  // Test ReduceMin/Max
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  Check('ReduceMin', LPipe.ReduceMin, 1.0);
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  Check('ReduceMax', LPipe.ReduceMax, 8.0);

  // Test ReduceNorm
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LExpected := 0;
  for i := 0 to 7 do LExpected := LExpected + LData[i] * LData[i];
  LExpected := System.Sqrt(LExpected);
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  Check('ReduceNorm', LPipe.ReduceNorm, LExpected, 1e-6);

  // Test optimization: Neg+Neg = identity (verified via result)
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe.Neg.Neg.Into(@LOut[0]);
  for i := 0 to 7 do Check('Neg+Neg[' + IntToStr(i) + ']', LOut[i], LData[i]);

  // Test optimization: MulScalar(1) = identity
  LPipe := TSimdF64Pipeline.From(@LData[0], 8);
  LPipe := LPipe.MulScalar(1.0);
  LPipe.Into(@LOut[0]);
  for i := 0 to 7 do Check('MulScalar(1)[' + IntToStr(i) + ']', LOut[i], LData[i]);

  WriteLn('Tests run: ', LPass + LFail);
  WriteLn('Passed: ', LPass);
  WriteLn('Failed: ', LFail);
  if LFail = 0 then
    WriteLn('All tests passed!')
  else
    Halt(1);
end.
