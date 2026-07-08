program test_batch_simd;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.math.base,
  nextpas.core.math.batch.simd;

var
  T: TTestSuite;

procedure CheckNear(const AExpected, AActual, AEpsilon: Double; const AMessage: string);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0.0 then
    LDelta := -LDelta;
  Check(LDelta <= AEpsilon, AMessage);
end;

procedure TestBatchSinSimd;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := PI_VALUE / 2;
  LInput[2] := PI_VALUE;
  LInput[3] := 3 * PI_VALUE / 2;

  LCount := BatchSinSimdF32(LInput, LOutput);
  Check(LCount = 4, 'BatchSinSimdF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchSinSimdF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-6, 'BatchSinSimdF32 [1]');
  CheckNear(0.0, LOutput[2], 1e-6, 'BatchSinSimdF32 [2]');
  CheckNear(-1.0, LOutput[3], 1e-6, 'BatchSinSimdF32 [3]');
end;

procedure TestBatchCosSimd;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := PI_VALUE / 2;
  LInput[2] := PI_VALUE;
  LInput[3] := 3 * PI_VALUE / 2;

  LCount := BatchCosSimdF32(LInput, LOutput);
  Check(LCount = 4, 'BatchCosSimdF32 returns correct count');
  CheckNear(1.0, LOutput[0], 1e-6, 'BatchCosSimdF32 [0]');
  CheckNear(0.0, LOutput[1], 1e-6, 'BatchCosSimdF32 [1]');
  CheckNear(-1.0, LOutput[2], 1e-6, 'BatchCosSimdF32 [2]');
  CheckNear(0.0, LOutput[3], 1e-6, 'BatchCosSimdF32 [3]');
end;

procedure TestBatchTanSimd;
var
  LInput: array[0..1] of Single;
  LOutput: array[0..1] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := PI_VALUE / 4;

  LCount := BatchTanSimdF32(LInput, LOutput);
  Check(LCount = 2, 'BatchTanSimdF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchTanSimdF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-6, 'BatchTanSimdF32 [1]');
end;

procedure TestBatchSinCosSimd;
var
  LInput: array[0..3] of Single;
  LSinOutput: array[0..3] of Single;
  LCosOutput: array[0..3] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := PI_VALUE / 2;
  LInput[2] := PI_VALUE;
  LInput[3] := 3 * PI_VALUE / 2;

  LCount := BatchSinCosSimdF32(LInput, LSinOutput, LCosOutput);
  Check(LCount = 4, 'BatchSinCosSimdF32 returns correct count');
  CheckNear(0.0, LSinOutput[0], 1e-6, 'BatchSinCosSimdF32 Sin[0]');
  CheckNear(1.0, LSinOutput[1], 1e-6, 'BatchSinCosSimdF32 Sin[1]');
  CheckNear(1.0, LCosOutput[0], 1e-6, 'BatchSinCosSimdF32 Cos[0]');
  CheckNear(0.0, LCosOutput[1], 1e-6, 'BatchSinCosSimdF32 Cos[1]');
end;

procedure TestBatchExpSimd;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := 1.0;
  LInput[2] := 2.0;

  LCount := BatchExpSimdF32(LInput, LOutput);
  Check(LCount = 3, 'BatchExpSimdF32 returns correct count');
  CheckNear(1.0, LOutput[0], 1e-6, 'BatchExpSimdF32 [0]');
  CheckNear(2.718281828, LOutput[1], 1e-5, 'BatchExpSimdF32 [1]');
  CheckNear(7.389056099, LOutput[2], 1e-5, 'BatchExpSimdF32 [2]');
end;

procedure TestBatchLnSimd;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 2.718281828;
  LInput[2] := 7.389056099;

  LCount := BatchLnSimdF32(LInput, LOutput);
  Check(LCount = 3, 'BatchLnSimdF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchLnSimdF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-5, 'BatchLnSimdF32 [1]');
  CheckNear(2.0, LOutput[2], 1e-5, 'BatchLnSimdF32 [2]');
end;

procedure TestBatchLog2Simd;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 2.0;
  LInput[2] := 4.0;

  LCount := BatchLog2SimdF32(LInput, LOutput);
  Check(LCount = 3, 'BatchLog2SimdF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchLog2SimdF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-6, 'BatchLog2SimdF32 [1]');
  CheckNear(2.0, LOutput[2], 1e-6, 'BatchLog2SimdF32 [2]');
end;

procedure TestBatchLog10Simd;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 10.0;
  LInput[2] := 100.0;

  LCount := BatchLog10SimdF32(LInput, LOutput);
  Check(LCount = 3, 'BatchLog10SimdF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchLog10SimdF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-6, 'BatchLog10SimdF32 [1]');
  CheckNear(2.0, LOutput[2], 1e-6, 'BatchLog10SimdF32 [2]');
end;

procedure TestBatchSqrtSimd;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := 4.0;
  LInput[2] := 9.0;

  LCount := BatchSqrtSimdF32(LInput, LOutput);
  Check(LCount = 3, 'BatchSqrtSimdF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchSqrtSimdF32 [0]');
  CheckNear(2.0, LOutput[1], 1e-6, 'BatchSqrtSimdF32 [1]');
  CheckNear(3.0, LOutput[2], 1e-6, 'BatchSqrtSimdF32 [2]');
end;

procedure TestBatchAbsSimd;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
begin
  LInput[0] := -3.0;
  LInput[1] := -1.0;
  LInput[2] := 0.0;
  LInput[3] := 2.0;

  LCount := BatchAbsSimdF32(LInput, LOutput);
  Check(LCount = 4, 'BatchAbsSimdF32 returns correct count');
  CheckNear(3.0, LOutput[0], 1e-6, 'BatchAbsSimdF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-6, 'BatchAbsSimdF32 [1]');
  CheckNear(0.0, LOutput[2], 1e-6, 'BatchAbsSimdF32 [2]');
  CheckNear(2.0, LOutput[3], 1e-6, 'BatchAbsSimdF32 [3]');
end;

procedure TestBatchNegSimd;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 0.0;
  LInput[2] := -2.0;

  LCount := BatchNegSimdF32(LInput, LOutput);
  Check(LCount = 3, 'BatchNegSimdF32 returns correct count');
  CheckNear(-1.0, LOutput[0], 1e-6, 'BatchNegSimdF32 [0]');
  CheckNear(0.0, LOutput[1], 1e-6, 'BatchNegSimdF32 [1]');
  CheckNear(2.0, LOutput[2], 1e-6, 'BatchNegSimdF32 [2]');
end;

procedure TestBatchCeilSimd;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.5;
  LInput[1] := 1.2;
  LInput[2] := -0.8;

  LCount := BatchCeilSimdF32(LInput, LOutput);
  Check(LCount = 3, 'BatchCeilSimdF32 returns correct count');
  CheckNear(1.0, LOutput[0], 1e-6, 'BatchCeilSimdF32 [0]');
  CheckNear(2.0, LOutput[1], 1e-6, 'BatchCeilSimdF32 [1]');
  CheckNear(0.0, LOutput[2], 1e-6, 'BatchCeilSimdF32 [2]');
end;

procedure TestBatchFloorSimd;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.5;
  LInput[1] := 1.2;
  LInput[2] := -0.8;

  LCount := BatchFloorSimdF32(LInput, LOutput);
  Check(LCount = 3, 'BatchFloorSimdF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchFloorSimdF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-6, 'BatchFloorSimdF32 [1]');
  CheckNear(-1.0, LOutput[2], 1e-6, 'BatchFloorSimdF32 [2]');
end;

procedure TestBatchRoundSimd;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.4;
  LInput[1] := 1.2;
  LInput[2] := 1.7;

  LCount := BatchRoundSimdF32(LInput, LOutput);
  Check(LCount = 3, 'BatchRoundSimdF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchRoundSimdF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-6, 'BatchRoundSimdF32 [1]');
  CheckNear(2.0, LOutput[2], 1e-6, 'BatchRoundSimdF32 [2]');
end;

procedure TestBatchTruncSimd;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.5;
  LInput[1] := 1.2;
  LInput[2] := -1.7;

  LCount := BatchTruncSimdF32(LInput, LOutput);
  Check(LCount = 3, 'BatchTruncSimdF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchTruncSimdF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-6, 'BatchTruncSimdF32 [1]');
  CheckNear(-1.0, LOutput[2], 1e-6, 'BatchTruncSimdF32 [2]');
end;

procedure TestBatchLerpSimd;
var
  LStart: array[0..2] of Single;
  LEnd: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LStart[0] := 0.0; LEnd[0] := 10.0;
  LStart[1] := 5.0; LEnd[1] := 15.0;
  LStart[2] := 10.0; LEnd[2] := 20.0;

  LCount := BatchLerpSimdF32(LStart, LEnd, 0.5, LOutput);
  Check(LCount = 3, 'BatchLerpSimdF32 returns correct count');
  CheckNear(5.0, LOutput[0], 1e-6, 'BatchLerpSimdF32 [0]');
  CheckNear(10.0, LOutput[1], 1e-6, 'BatchLerpSimdF32 [1]');
  CheckNear(15.0, LOutput[2], 1e-6, 'BatchLerpSimdF32 [2]');
end;

procedure TestBatchClampSimd;
var
  LInput: array[0..4] of Single;
  LOutput: array[0..4] of Single;
  LCount: SizeInt;
begin
  LInput[0] := -5.0;
  LInput[1] := 0.0;
  LInput[2] := 3.0;
  LInput[3] := 5.0;
  LInput[4] := 10.0;

  LCount := BatchClampSimdF32(LInput, 0.0, 5.0, LOutput);
  Check(LCount = 5, 'BatchClampSimdF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchClampSimdF32 [0]');
  CheckNear(0.0, LOutput[1], 1e-6, 'BatchClampSimdF32 [1]');
  CheckNear(3.0, LOutput[2], 1e-6, 'BatchClampSimdF32 [2]');
  CheckNear(5.0, LOutput[3], 1e-6, 'BatchClampSimdF32 [3]');
  CheckNear(5.0, LOutput[4], 1e-6, 'BatchClampSimdF32 [4]');
end;

procedure TestBatchScaleOffsetSimd;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 2.0;
  LInput[2] := 3.0;

  LCount := BatchScaleOffsetSimdF32(LInput, 2.0, 1.0, LOutput);
  Check(LCount = 3, 'BatchScaleOffsetSimdF32 returns correct count');
  CheckNear(3.0, LOutput[0], 1e-6, 'BatchScaleOffsetSimdF32 [0]');
  CheckNear(5.0, LOutput[1], 1e-6, 'BatchScaleOffsetSimdF32 [1]');
  CheckNear(7.0, LOutput[2], 1e-6, 'BatchScaleOffsetSimdF32 [2]');
end;

procedure TestBatchSinEmpty;
var
  LInput: array of Single;
  LOutput: array of Single;
  LCount: SizeInt;
begin
  SetLength(LInput, 0);
  SetLength(LOutput, 0);
  LCount := BatchSinSimdF32(LInput, LOutput);
  Check(LCount = 0, 'Empty input should return 0');
end;

procedure TestBatchSinMismatchedLength;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..0] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := 1.0;
  LInput[2] := 2.0;

  LCount := BatchSinSimdF32(LInput, LOutput);
  Check(LCount = 1, 'Should return min length');
end;

begin
  T := TTestSuite.Create('nextpas.core.math.batch.simd');

  T.Test('BatchSinSimdF32', @TestBatchSinSimd);
  T.Test('BatchCosSimdF32', @TestBatchCosSimd);
  T.Test('BatchTanSimdF32', @TestBatchTanSimd);
  T.Test('BatchSinCosSimdF32', @TestBatchSinCosSimd);
  T.Test('BatchExpSimdF32', @TestBatchExpSimd);
  T.Test('BatchLnSimdF32', @TestBatchLnSimd);
  T.Test('BatchLog2SimdF32', @TestBatchLog2Simd);
  T.Test('BatchLog10SimdF32', @TestBatchLog10Simd);
  T.Test('BatchSqrtSimdF32', @TestBatchSqrtSimd);
  T.Test('BatchAbsSimdF32', @TestBatchAbsSimd);
  T.Test('BatchNegSimdF32', @TestBatchNegSimd);
  T.Test('BatchCeilSimdF32', @TestBatchCeilSimd);
  T.Test('BatchFloorSimdF32', @TestBatchFloorSimd);
  T.Test('BatchRoundSimdF32', @TestBatchRoundSimd);
  T.Test('BatchTruncSimdF32', @TestBatchTruncSimd);
  T.Test('BatchLerpSimdF32', @TestBatchLerpSimd);
  T.Test('BatchClampSimdF32', @TestBatchClampSimd);
  T.Test('BatchScaleOffsetSimdF32', @TestBatchScaleOffsetSimd);
  T.Test('BatchSinSimdF32 Empty', @TestBatchSinEmpty);
  T.Test('BatchSinSimdF32 MismatchedLength', @TestBatchSinMismatchedLength);

  if not T.Run then Halt(1);
end.
