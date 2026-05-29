program nextpas.core.simd.test_highlevel_api;

{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.alloc,
  nextpas.core.simd.arrays.typed,
  nextpas.core.simd.pipeline;

var
  g_Checks: Integer = 0;
  g_Fails: Integer = 0;

procedure Check(const aName: string; aExpected, aActual: Double; aTol: Double = 1e-3);
begin
  Inc(g_Checks);
  if System.Abs(aExpected - aActual) > aTol * (System.Abs(aExpected) + 1e-6) then
  begin
    WriteLn('[FAIL] ', aName, ': expected ', aExpected:0:6, ' got ', aActual:0:6);
    Inc(g_Fails);
  end;
end;

procedure CheckBool(const aName: string; aOK: Boolean);
begin
  Inc(g_Checks);
  if not aOK then begin WriteLn('[FAIL] ', aName); Inc(g_Fails); end;
end;

procedure TestSimdAlloc;
var
  p: Pointer;
begin
  p := SimdAlloc(256);
  CheckBool('SimdAlloc <> nil', p <> nil);
  CheckBool('SimdAlloc 32-aligned', (PtrUInt(p) mod 32) = 0);
  SimdFree(p);

  p := SimdAlloc(64, sa64);
  CheckBool('SimdAlloc64 <> nil', p <> nil);
  CheckBool('SimdAlloc64 64-aligned', (PtrUInt(p) mod 64) = 0);
  SimdFree(p);

  p := SimdAlloc(128);
  p := SimdRealloc(p, 256);
  CheckBool('SimdRealloc <> nil', p <> nil);
  SimdFree(p);

  WriteLn('  SimdAlloc: OK');
end;

procedure TestTypedArray;
var
  A, B, C: TSimdF32Array;
  i: Integer;
begin
  A := TSimdF32Array.Create(8);
  for i := 0 to 7 do A.Data[i] := i + 1;
  CheckBool('Create count=8', A.Count = 8);
  CheckBool('Create data<>nil', A.Data <> nil);
  Check('Create[0]', 1, A.Data[0]);

  B := TSimdF32Array.Zeros(4);
  Check('Zeros[0]', 0, B.Data[0]);
  CheckBool('Zeros count=4', B.Count = 4);

  C := A + A;
  Check('Operator+[0]', 2, C.Data[0]);
  Check('Operator+[7]', 16, C.Data[7]);
  C.Free;

  C := A * 2.0;
  Check('Operator*scalar[2]', 6, C.Data[2]);
  C.Free;

  Check('Dot(A,A)', 204, A.Dot(A));
  Check('Sum', 36, A.Sum);
  Check('Mean', 4.5, A.Mean);
  Check('Norm', System.Sqrt(204), A.Norm, 0.01);
  CheckBool('Variance>0', A.Variance > 0);

  C := A / 2.0;
  Check('Operator/[0]', 0.5, C.Data[0]);
  Check('Operator/[7]', 4.0, C.Data[7]);
  C.Free;

  A.Fill(7.0);
  Check('Fill[0]', 7, A.Data[0]);
  Check('Fill[7]', 7, A.Data[7]);

  A.Free; B.Free;
  WriteLn('  TypedArray: OK');
end;

procedure TestPipeline;
var
  Src: array[0..7] of Single;
  Dst: array[0..7] of Single;
  Arr, Res: TSimdF32Array;
  i: Integer;
begin
  for i := 0 to 7 do Src[i] := i + 1;

  TSimdF32Pipeline.From(@Src[0], 8)
    .MulScalar(2.0)
    .AddScalar(1.0)
    .Into(@Dst[0]);
  Check('Pipeline MulAdd[0]', 3, Dst[0]);
  Check('Pipeline MulAdd[7]', 17, Dst[7]);

  TSimdF32Pipeline.From(@Src[0], 8)
    .Linear(3.0, -1.0)
    .Into(@Dst[0]);
  Check('Pipeline Linear[0]', 2, Dst[0]);
  Check('Pipeline Linear[4]', 14, Dst[4]);

  TSimdF32Pipeline.From(@Src[0], 8)
    .Neg
    .Into(@Dst[0]);
  Check('Pipeline Neg[0]', -1, Dst[0]);

  TSimdF32Pipeline.From(@Src[0], 8)
    .Abs
    .Into(@Dst[0]);
  Check('Pipeline Abs[0]', 1, Dst[0]);

  for i := 0 to 7 do Src[i] := i - 4;
  TSimdF32Pipeline.From(@Src[0], 8)
    .ReLU
    .Into(@Dst[0]);
  Check('Pipeline ReLU[-4]', 0, Dst[0]);
  Check('Pipeline ReLU[3]', 3, Dst[7]);

  for i := 0 to 7 do Src[i] := i - 4;
  TSimdF32Pipeline.From(@Src[0], 8)
    .Clamp(-1, 2)
    .Into(@Dst[0]);
  Check('Pipeline Clamp[-4]→-1', -1, Dst[0]);
  Check('Pipeline Clamp[3]→2', 2, Dst[7]);

  for i := 0 to 7 do Src[i] := 1;
  TSimdF32Pipeline.From(@Src[0], 8)
    .Exp
    .Into(@Dst[0]);
  Check('Pipeline Exp(1)', 2.718, Dst[0], 0.01);

  for i := 0 to 7 do Src[i] := 1;
  TSimdF32Pipeline.From(@Src[0], 8)
    .Log
    .Into(@Dst[0]);
  Check('Pipeline Log(1)', 0, Dst[0], 0.01);

  for i := 0 to 7 do Src[i] := 4;
  TSimdF32Pipeline.From(@Src[0], 8)
    .Sqrt
    .Into(@Dst[0]);
  Check('Pipeline Sqrt(4)', 2, Dst[0]);

  TSimdF32Pipeline.From(@Src[0], 8)
    .Sigmoid
    .Into(@Dst[0]);
  CheckBool('Pipeline Sigmoid(4)>0.9', Dst[0] > 0.9);

  Arr := TSimdF32Array.Create(4);
  for i := 0 to 3 do Arr.Data[i] := (i + 1) * 10;
  Res := TSimdF32Pipeline.FromArray(Arr)
    .MulScalar(0.1)
    .Eval;
  Check('Pipeline Eval[0]', 1, Res.Data[0]);
  Check('Pipeline Eval[3]', 4, Res.Data[3]);
  Res.Free; Arr.Free;

  WriteLn('  Pipeline: OK');
end;

procedure TestPipelineAdvanced;
var
  A, B, C: array[0..7] of Single;
  Dst: array[0..7] of Single;
  i: Integer;
  LSum, LMax, LMin, LDot: Single;
  P: TSimdF32Pipeline;
begin
  for i := 0 to 7 do begin A[i] := i + 1; B[i] := 2; C[i] := 10; end;

  TSimdF32Pipeline.From(@A[0], 8).Add(@B[0]).Into(@Dst[0]);
  Check('Add(arr)[0]', 3, Dst[0]);
  Check('Add(arr)[7]', 10, Dst[7]);

  TSimdF32Pipeline.From(@A[0], 8).Mul(@B[0]).Into(@Dst[0]);
  Check('Mul(arr)[0]', 2, Dst[0]);
  Check('Mul(arr)[7]', 16, Dst[7]);

  TSimdF32Pipeline.From(@A[0], 8).Sub(@B[0]).Into(@Dst[0]);
  Check('Sub(arr)[0]', -1, Dst[0]);
  Check('Sub(arr)[7]', 6, Dst[7]);

  TSimdF32Pipeline.From(@A[0], 8).Mul(@B[0]).Add(@C[0]).Into(@Dst[0]);
  Check('A*B+C[0]', 12, Dst[0]);
  Check('A*B+C[7]', 26, Dst[7]);

  LSum := TSimdF32Pipeline.From(@A[0], 8).ReduceSum;
  Check('ReduceSum', 36, LSum);

  LSum := TSimdF32Pipeline.From(@A[0], 8).MulScalar(2).ReduceSum;
  Check('MulScalar(2).ReduceSum', 72, LSum);

  // Mul(arr).ReduceSum = dot product (zero-alloc fast path)
  LSum := TSimdF32Pipeline.From(@A[0], 8).Mul(@B[0]).ReduceSum;
  Check('Mul(arr).ReduceSum=dot', 72, LSum);

  LMax := TSimdF32Pipeline.From(@A[0], 8).ReduceMax;
  Check('ReduceMax', 8, LMax);
  LMin := TSimdF32Pipeline.From(@A[0], 8).ReduceMin;
  Check('ReduceMin', 1, LMin);

  LDot := TSimdF32Pipeline.From(@A[0], 8).ReduceDot(@B[0]);
  Check('ReduceDot', 72, LDot);

  // ReduceMean: mean([1..8]) = 4.5
  LSum := TSimdF32Pipeline.From(@A[0], 8).ReduceMean;
  Check('ReduceMean', 4.5, LSum);

  // ReduceNorm: norm([3,4]) = 5
  A[0] := 3; A[1] := 4;
  LSum := TSimdF32Pipeline.From(@A[0], 2).ReduceNorm;
  Check('ReduceNorm', 5, LSum);
  for i := 0 to 7 do A[i] := i + 1;

  for i := 0 to 7 do A[i] := i - 4;
  TSimdF32Pipeline.From(@A[0], 8).LeakyReLU(0.1).Into(@Dst[0]);
  Check('LeakyReLU[-4]', -0.4, Dst[0], 0.01);
  Check('LeakyReLU[3]', 3, Dst[7]);

  for i := 0 to 7 do A[i] := i + 1;
  TSimdF32Pipeline.From(@A[0], 8).Min(5).Into(@Dst[0]);
  Check('Min(5)[0]', 1, Dst[0]);
  Check('Min(5)[7]', 5, Dst[7]);

  TSimdF32Pipeline.From(@A[0], 8).Max(5).Into(@Dst[0]);
  Check('Max(5)[0]', 5, Dst[0]);
  Check('Max(5)[7]', 8, Dst[7]);

  TSimdF32Pipeline.From(@A[0], 4).Square.Into(@Dst[0]);
  Check('Square[0]', 1, Dst[0]);
  Check('Square[2]', 9, Dst[2]);

  A[0] := 0;
  TSimdF32Pipeline.From(@A[0], 1).Tanh.Into(@Dst[0]);
  Check('Tanh(0)', 0, Dst[0], 0.01);

  for i := 0 to 3 do A[i] := 2;
  TSimdF32Pipeline.From(@A[0], 4).Pow(3).Into(@Dst[0]);
  Check('Pow(2,3)', 8, Dst[0]);

  for i := 0 to 7 do A[i] := i + 1;
  P := TSimdF32Pipeline.From(@A[0], 8).MulScalar(2).MulScalar(3);
  P.Into(@Dst[0]);
  Check('Fusion Mul*Mul[0]', 6, Dst[0]);
  Check('Fusion Mul*Mul[7]', 48, Dst[7]);

  P := TSimdF32Pipeline.From(@A[0], 8).AddScalar(5).AddScalar(3);
  P.Into(@Dst[0]);
  Check('Fusion Add+Add[0]', 9, Dst[0]);

  P := TSimdF32Pipeline.From(@A[0], 8).MulScalar(2).AddScalar(1);
  P.Into(@Dst[0]);
  Check('Fusion Mul+Add→Linear[0]', 3, Dst[0]);
  Check('Fusion Mul+Add→Linear[7]', 17, Dst[7]);

  WriteLn('  Pipeline Advanced: OK');
end;

procedure TestFusionPatterns;
var
  A, B: array[0..7] of Single;
  Dst: array[0..7] of Single;
  i: Integer;
  P: TSimdF32Pipeline;
begin
  for i := 0 to 7 do begin A[i] := i + 1; B[i] := (i + 1) * 10; end;

  // Linear + ReLU → LinearReLU (single pass)
  // Linear(2, -10): 2*1-10=-8, 2*5-10=0, 2*6-10=2
  P := TSimdF32Pipeline.From(@A[0], 8).Linear(2, -10).ReLU;
  P.Into(@Dst[0]);
  Check('LinearReLU[0] (2*1-10→0)', 0, Dst[0]);
  Check('LinearReLU[5] (2*6-10=2)', 2, Dst[5]);
  Check('LinearReLU[7] (2*8-10=6)', 6, Dst[7]);
  CheckBool('LinearReLU fused to 1 step', P.StepCount = 1);

  // Sub + Abs → AbsDiff (single pass)
  for i := 0 to 7 do B[i] := 5;
  P := TSimdF32Pipeline.From(@A[0], 8).Sub(@B[0]).Abs;
  P.Into(@Dst[0]);
  Check('AbsDiff[0] |1-5|=4', 4, Dst[0]);
  Check('AbsDiff[4] |5-5|=0', 0, Dst[4]);
  Check('AbsDiff[7] |8-5|=3', 3, Dst[7]);
  CheckBool('AbsDiff fused to 1 step', P.StepCount = 1);

  // MulScalar + AddArray → Axpy (alpha*X + Y)
  for i := 0 to 7 do B[i] := 100;
  P := TSimdF32Pipeline.From(@A[0], 8).MulScalar(3).Add(@B[0]);
  P.Into(@Dst[0]);
  Check('Axpy[0] 3*1+100=103', 103, Dst[0]);
  Check('Axpy[7] 3*8+100=124', 124, Dst[7]);
  CheckBool('Axpy fused to 1 step', P.StepCount = 1);

  // Clamp + Clamp → intersect
  P := TSimdF32Pipeline.From(@A[0], 8).Clamp(-10, 6).Clamp(2, 100);
  P.Into(@Dst[0]);
  Check('Clamp∩[0] clamp(1,2,6)=2', 2, Dst[0]);
  Check('Clamp∩[5] clamp(6,2,6)=6', 6, Dst[5]);
  Check('Clamp∩[7] clamp(8,2,6)=6', 6, Dst[7]);
  CheckBool('Clamp∩ fused to 1 step', P.StepCount = 1);

  // MulScalar + ReLU → LinearReLU(a, 0)
  for i := 0 to 7 do A[i] := i - 4;
  P := TSimdF32Pipeline.From(@A[0], 8).MulScalar(2).ReLU;
  P.Into(@Dst[0]);
  Check('MulReLU[0] max(2*(-4),0)=0', 0, Dst[0]);
  Check('MulReLU[5] max(2*1,0)=2', 2, Dst[5]);
  Check('MulReLU[7] max(2*3,0)=6', 6, Dst[7]);
  CheckBool('MulScalar+ReLU fused to 1 step', P.StepCount = 1);

  // AddScalar + ReLU → LinearReLU(1, b)
  P := TSimdF32Pipeline.From(@A[0], 8).AddScalar(3).ReLU;
  P.Into(@Dst[0]);
  Check('AddReLU[0] max(-4+3,0)=0', 0, Dst[0]);
  Check('AddReLU[5] max(1+3,0)=4', 4, Dst[5]);
  Check('AddReLU[7] max(3+3,0)=6', 6, Dst[7]);
  CheckBool('AddScalar+ReLU fused to 1 step', P.StepCount = 1);

  // Fixed-point iteration: MulScalar*3 → single Linear
  // Mul(2) + Mul(3) + Add(5) → first pass: Mul(6) + Add(5) → second pass: Linear(6,5)
  for i := 0 to 7 do A[i] := i + 1;
  P := TSimdF32Pipeline.From(@A[0], 8).MulScalar(2).MulScalar(3).AddScalar(5);
  P.Into(@Dst[0]);
  Check('3-step fusion[0] 2*3*1+5=11', 11, Dst[0]);
  Check('3-step fusion[7] 6*8+5=53', 53, Dst[7]);
  CheckBool('3-step fused to 1 step', P.StepCount = 1);

  WriteLn('  Fusion Patterns: OK');
end;

procedure TestCompiledPlan;
var
  A, Dst: array[0..7] of Single;
  Plan: TSimdF32Plan;
  i: Integer;
begin
  for i := 0 to 7 do A[i] := i + 1;

  Plan := TSimdF32Pipeline.From(nil, 0)
    .Linear(2.0, -1.0)
    .ReLU
    .Compile;

  CheckBool('Plan.IsValid', Plan.IsValid);

  Plan.Execute(@A[0], @Dst[0], 8);
  Check('Plan Linear+ReLU[0] max(2*1-1,0)=1', 1, Dst[0]);
  Check('Plan Linear+ReLU[7] max(2*8-1,0)=15', 15, Dst[7]);

  Plan.Execute(@A[0], @Dst[0], 4);
  Check('Plan reuse[0]', 1, Dst[0]);
  Check('Plan reuse[3]', 7, Dst[3]);

  Plan := TSimdF32Pipeline.From(nil, 0)
    .MulScalar(3)
    .MulScalar(2)
    .AddScalar(10)
    .Compile;
  Plan.Execute(@A[0], @Dst[0], 8);
  Check('Plan chained[0] 6*1+10=16', 16, Dst[0]);
  Check('Plan chained[7] 6*8+10=58', 58, Dst[7]);

  WriteLn('  Compiled Plan: OK');
end;

procedure TestTypedArrayExtended;
var
  a, b: TSimdF32Array;
  ls: TSimdF32Array;
begin
  a := TSimdF32Array.Create(5);
  a.Data[0] := 3; a.Data[1] := 1; a.Data[2] := 7; a.Data[3] := 2; a.Data[4] := 5;

  Check('ArgMax', 2, a.ArgMax);
  Check('ArgMin', 1, a.ArgMin);
  Check('Median', 3, a.Median);
  Check('StdDev > 0', 1, Ord(a.StdDev > 0));

  b := a.Clone;
  Check('Clone[0]', 3, b.Data[0]);
  Check('Clone[4]', 5, b.Data[4]);
  b.Free;

  b := a.Reversed;
  Check('Reversed[0]', 5, b.Data[0]);
  Check('Reversed[4]', 3, b.Data[4]);
  b.Free;

  b := a.Sorted;
  Check('Sorted[0]', 1, b.Data[0]);
  Check('Sorted[4]', 7, b.Data[4]);
  b.Free;

  // Diff: [3,1,7,2,5] → [-2,6,-5,3]
  b := a.Diff;
  CheckBool('Diff count=4', b.Count = 4);
  Check('Diff[0]', -2, b.Data[0]);
  Check('Diff[1]', 6, b.Data[1]);
  Check('Diff[2]', -5, b.Data[2]);
  Check('Diff[3]', 3, b.Data[3]);
  b.Free;

  // CumSum: [3,1,7,2,5] → [3,4,11,13,18]
  b := a.CumSum;
  CheckBool('CumSum count=5', b.Count = 5);
  Check('CumSum[0]', 3, b.Data[0]);
  Check('CumSum[1]', 4, b.Data[1]);
  Check('CumSum[2]', 11, b.Data[2]);
  Check('CumSum[4]', 18, b.Data[4]);
  b.Free;

  // Concat: [3,1,7,2,5] ++ [10,20] → [3,1,7,2,5,10,20]
  b := TSimdF32Array.Create(2);
  b.Data[0] := 10; b.Data[1] := 20;
  ls := a.Concat(b);
  CheckBool('Concat count=7', ls.Count = 7);
  Check('Concat[0]', 3, ls.Data[0]);
  Check('Concat[4]', 5, ls.Data[4]);
  Check('Concat[5]', 10, ls.Data[5]);
  Check('Concat[6]', 20, ls.Data[6]);
  ls.Free; b.Free;

  a.Free;

  ls := TSimdF32Array.Linspace(5, 0, 4);
  Check('Linspace[0]', 0, ls.Data[0]);
  Check('Linspace[2]', 2, ls.Data[2]);
  Check('Linspace[4]', 4, ls.Data[4]);
  ls.Free;

  WriteLn('  TypedArray Extended: OK');
end;

procedure TestStridedOps;
var
  raw: array[0..9] of Single;
  strided, result_arr: TSimdF32Array;
  i: Integer;
begin
  // Create a strided view: elements at indices 0,2,4,6,8 → values 0,2,4,6,8
  for i := 0 to 9 do raw[i] := i;
  strided := TSimdF32Array.WrapStrided(@raw[0], 5, 2);

  // Abs on strided (was returning all zeros before fix)
  for i := 0 to 9 do raw[i] := -(i);
  result_arr := strided.Abs;
  Check('Strided.Abs[0]', 0, result_arr.Data[0]);
  Check('Strided.Abs[1]', 2, result_arr.Data[1]);
  Check('Strided.Abs[2]', 4, result_arr.Data[2]);
  result_arr.Free;

  // Clamped on strided (was just copying without clamp before fix)
  for i := 0 to 9 do raw[i] := i;
  result_arr := strided.Clamped(1, 5);
  Check('Strided.Clamped[0]', 1, result_arr.Data[0]);
  Check('Strided.Clamped[2]', 4, result_arr.Data[2]);
  Check('Strided.Clamped[4]', 5, result_arr.Data[4]);
  result_arr.Free;

  // operator* on strided (was ignoring stride before fix)
  for i := 0 to 9 do raw[i] := i + 1;
  result_arr := strided * strided;
  Check('Strided*Strided[0]', 1, result_arr.Data[0]);
  Check('Strided*Strided[1]', 9, result_arr.Data[1]);
  Check('Strided*Strided[2]', 25, result_arr.Data[2]);
  result_arr.Free;

  WriteLn('  Strided Ops: OK');
end;

begin
  WriteLn('[High-Level API Tests — SimdAlloc + TypedArray + Pipeline]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestSimdAlloc;
  TestTypedArray;
  TestTypedArrayExtended;
  TestStridedOps;
  TestPipeline;
  TestPipelineAdvanced;
  TestFusionPatterns;
  TestCompiledPlan;

  WriteLn('');
  WriteLn('[SUMMARY] checks=', g_Checks, ' failures=', g_Fails);
  if g_Fails > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
