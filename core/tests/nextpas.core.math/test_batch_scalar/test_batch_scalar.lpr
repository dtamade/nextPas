program test_batch_scalar;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.math;

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

procedure TestBatchSin;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := PI_VALUE / 2;
  LInput[2] := PI_VALUE;
  LInput[3] := 3 * PI_VALUE / 2;

  LCount := BatchSinF32(LInput, LOutput);
  Check(LCount = 4, 'BatchSinF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchSinF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-6, 'BatchSinF32 [1]');
  CheckNear(0.0, LOutput[2], 1e-6, 'BatchSinF32 [2]');
  CheckNear(-1.0, LOutput[3], 1e-6, 'BatchSinF32 [3]');
end;

procedure TestBatchCos;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := PI_VALUE / 2;
  LInput[2] := PI_VALUE;
  LInput[3] := 3 * PI_VALUE / 2;

  LCount := BatchCosF32(LInput, LOutput);
  Check(LCount = 4, 'BatchCosF32 returns correct count');
  CheckNear(1.0, LOutput[0], 1e-6, 'BatchCosF32 [0]');
  CheckNear(0.0, LOutput[1], 1e-6, 'BatchCosF32 [1]');
  CheckNear(-1.0, LOutput[2], 1e-6, 'BatchCosF32 [2]');
  CheckNear(0.0, LOutput[3], 1e-6, 'BatchCosF32 [3]');
end;

procedure TestBatchExp;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := 1.0;
  LInput[2] := 2.0;

  LCount := BatchExpF32(LInput, LOutput);
  Check(LCount = 3, 'BatchExpF32 returns correct count');
  CheckNear(1.0, LOutput[0], 1e-6, 'BatchExpF32 [0]');
  CheckNear(2.718281828, LOutput[1], 1e-5, 'BatchExpF32 [1]');
  CheckNear(7.389056099, LOutput[2], 1e-5, 'BatchExpF32 [2]');
end;

procedure TestBatchLn;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 2.718281828;
  LInput[2] := 7.389056099;

  LCount := BatchLnF32(LInput, LOutput);
  Check(LCount = 3, 'BatchLnF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchLnF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-5, 'BatchLnF32 [1]');
  CheckNear(2.0, LOutput[2], 1e-5, 'BatchLnF32 [2]');
end;

procedure TestBatchSqrt;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := 1.0;
  LInput[2] := 4.0;

  LCount := BatchSqrtF32(LInput, LOutput);
  Check(LCount = 3, 'BatchSqrtF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchSqrtF32 [0]');
  CheckNear(1.0, LOutput[1], 1e-6, 'BatchSqrtF32 [1]');
  CheckNear(2.0, LOutput[2], 1e-6, 'BatchSqrtF32 [2]');
end;

procedure TestBatchAbs;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := -3.0;
  LInput[1] := 0.0;
  LInput[2] := 5.0;

  LCount := BatchAbsF32(LInput, LOutput);
  Check(LCount = 3, 'BatchAbsF32 returns correct count');
  CheckNear(3.0, LOutput[0], 1e-6, 'BatchAbsF32 [0]');
  CheckNear(0.0, LOutput[1], 1e-6, 'BatchAbsF32 [1]');
  CheckNear(5.0, LOutput[2], 1e-6, 'BatchAbsF32 [2]');
end;

procedure TestBatchNeg;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := -3.0;
  LInput[1] := 0.0;
  LInput[2] := 5.0;

  LCount := BatchNegF32(LInput, LOutput);
  Check(LCount = 3, 'BatchNegF32 returns correct count');
  CheckNear(3.0, LOutput[0], 1e-6, 'BatchNegF32 [0]');
  CheckNear(0.0, LOutput[1], 1e-6, 'BatchNegF32 [1]');
  CheckNear(-5.0, LOutput[2], 1e-6, 'BatchNegF32 [2]');
end;

procedure TestBatchClamp;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
begin
  LInput[0] := -5.0;
  LInput[1] := 0.0;
  LInput[2] := 5.0;
  LInput[3] := 15.0;

  LCount := BatchClampF32(LInput, 0.0, 10.0, LOutput);
  Check(LCount = 4, 'BatchClampF32 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-6, 'BatchClampF32 [0]');
  CheckNear(0.0, LOutput[1], 1e-6, 'BatchClampF32 [1]');
  CheckNear(5.0, LOutput[2], 1e-6, 'BatchClampF32 [2]');
  CheckNear(10.0, LOutput[3], 1e-6, 'BatchClampF32 [3]');
end;

procedure TestBatchLerp;
var
  LStart, LEnd: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LStart[0] := 0.0;
  LStart[1] := 10.0;
  LStart[2] := -5.0;
  LEnd[0] := 100.0;
  LEnd[1] := 20.0;
  LEnd[2] := 5.0;

  LCount := BatchLerpF32(LStart, LEnd, 0.5, LOutput);
  Check(LCount = 3, 'BatchLerpF32 returns correct count');
  CheckNear(50.0, LOutput[0], 1e-6, 'BatchLerpF32 [0]');
  CheckNear(15.0, LOutput[1], 1e-6, 'BatchLerpF32 [1]');
  CheckNear(0.0, LOutput[2], 1e-6, 'BatchLerpF32 [2]');
end;

procedure TestBatchScaleOffset;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 2.0;
  LInput[2] := 3.0;

  LCount := BatchScaleOffsetF32(LInput, 2.0, 1.0, LOutput);
  Check(LCount = 3, 'BatchScaleOffsetF32 returns correct count');
  CheckNear(3.0, LOutput[0], 1e-6, 'BatchScaleOffsetF32 [0]');
  CheckNear(5.0, LOutput[1], 1e-6, 'BatchScaleOffsetF32 [1]');
  CheckNear(7.0, LOutput[2], 1e-6, 'BatchScaleOffsetF32 [2]');
end;

procedure TestBatchEmpty;
var
  LInput, LOutput: array[0..0] of Single;
  LCount: SizeInt;
begin
  LCount := BatchSinF32([], LOutput);
  Check(LCount = 0, 'BatchSinF32 handles empty arrays');
end;

procedure TestBatchMismatchedLength;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..1] of Single;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := 1.0;
  LInput[2] := 2.0;

  LCount := BatchSinF32(LInput, LOutput);
  Check(LCount = 2, 'BatchSinF32 handles mismatched lengths');
end;

begin
  T := TTestSuite.Create('nextpas.core.math.batch');

  T.Test('BatchSinF32', @TestBatchSin);
  T.Test('BatchCosF32', @TestBatchCos);
  T.Test('BatchExpF32', @TestBatchExp);
  T.Test('BatchLnF32', @TestBatchLn);
  T.Test('BatchSqrtF32', @TestBatchSqrt);
  T.Test('BatchAbsF32', @TestBatchAbs);
  T.Test('BatchNegF32', @TestBatchNeg);
  T.Test('BatchClampF32', @TestBatchClamp);
  T.Test('BatchLerpF32', @TestBatchLerp);
  T.Test('BatchScaleOffsetF32', @TestBatchScaleOffset);
  T.Test('BatchEmpty', @TestBatchEmpty);
  T.Test('BatchMismatchedLength', @TestBatchMismatchedLength);

  if not T.Run then Halt(1);
end.
