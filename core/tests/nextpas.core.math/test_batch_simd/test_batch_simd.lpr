program test_batch_simd;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.math,
  nextpas.core.math.base,
  nextpas.core.math.batch,
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

procedure TestBatchClampSimdF32_NaN;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
  LNaN: Single;
  LOldMask: TFPUExceptionMask;
begin
  PUInt32(@LNaN)^ := $7FC00000; // canonical quiet NaN
  LInput[0] := LNaN;
  LInput[1] := 5.0;
  LInput[2] := LNaN;
  LInput[3] := -5.0;
  // Mask all FP exceptions during NaN clamp (NaN in SIMD can set status flags)
  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  LCount := BatchClampSimdF32(LInput, 0.0, 10.0, LOutput);
  SetExceptionMask(LOldMask);
  Check(LCount = 4, 'Clamp NaN count');
  // Verify NaN is preserved via bit pattern (exponent=0xFF, mantissa!=0)
  Check((PUInt32(@LOutput[0])^ and $7F800000) = $7F800000, 'Clamp NaN [0] exponent');
  Check((PUInt32(@LOutput[0])^ and $007FFFFF) <> 0, 'Clamp NaN [0] mantissa');
  CheckNear(5.0, LOutput[1], 1e-6, 'Clamp NaN [1]');
  Check((PUInt32(@LOutput[2])^ and $7F800000) = $7F800000, 'Clamp NaN [2] exponent');
  Check((PUInt32(@LOutput[2])^ and $007FFFFF) <> 0, 'Clamp NaN [2] mantissa');
  CheckNear(0.0, LOutput[3], 1e-6, 'Clamp NaN [3]');
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
  LRaised: Boolean;
begin
  LInput[0] := 0.0;
  LInput[1] := 1.0;
  LInput[2] := 2.0;
  LRaised := False;
  try
    BatchSinSimdF32(LInput, LOutput);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Mismatched lengths must raise EArgumentError (strict batch policy)');
end;

procedure TestBatchLogAliasAndTryLn;
var
  LIn, LOutLn, LOutLog: array[0..2] of Single;
  LCount, LTryCount: SizeInt;
  LOk: Boolean;
begin
  LIn[0] := 1.0;
  LIn[1] := 2.718281828;
  LIn[2] := 10.0;
  LCount := BatchLnF32(LIn, LOutLn);
  Check(LCount = 3, 'BatchLnF32 count');
  LCount := BatchLogF32(LIn, LOutLog);
  Check(LCount = 3, 'BatchLogF32 alias count');
  CheckNear(LOutLn[0], LOutLog[0], 1e-6, 'BatchLog alias [0]');
  CheckNear(LOutLn[1], LOutLog[1], 1e-5, 'BatchLog alias [1]');
  CheckNear(LOutLn[2], LOutLog[2], 1e-5, 'BatchLog alias [2]');

  LOk := TryBatchLnF32(LIn, LOutLn, LTryCount);
  Check(LOk and (LTryCount = 3), 'TryBatchLnF32 positive domain');

  LIn[1] := -1.0;
  LOk := TryBatchLnF32(LIn, LOutLn, LTryCount);
  Check((not LOk) and (LTryCount = 0), 'TryBatchLnF32 rejects non-positive');
end;

{ ============================================================================
  Boundary value tests: NaN, Inf, -Inf, 0 for each batch function
  Uses PUInt32 bit-pattern checks for NaN verification
  ============================================================================ }

function IsNaN(const X: Single): Boolean; inline;
begin
  Result := (PUInt32(@X)^ and $7F800000) = $7F800000;
  if Result then
    Result := (PUInt32(@X)^ and $007FFFFF) <> 0;
end;

function IsInf(const X: Single): Boolean; inline;
begin
  Result := PUInt32(@X)^ and $7FFFFFFF = $7F800000;
end;

procedure TestBatchSinSimd_Boundary;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
  LNaN, LPosInf, LNegInf: Single;
  LOldMask: TFPUExceptionMask;
begin
  PUInt32(@LNaN)^ := $7FC00000;       // canonical quiet NaN
  PUInt32(@LPosInf)^ := $7F800000;    // +Inf
  PUInt32(@LNegInf)^ := $FF800000;    // -Inf

  LInput[0] := LNaN;
  LInput[1] := LPosInf;
  LInput[2] := LNegInf;
  LInput[3] := 0.0;

  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  LCount := BatchSinSimdF32(LInput, LOutput);
  SetExceptionMask(LOldMask);

  Check(LCount = 4, 'Sin boundary count');
  Check(IsNaN(LOutput[0]), 'Sin(NaN) = NaN');
  Check(IsNaN(LOutput[1]), 'Sin(+Inf) = NaN');
  Check(IsNaN(LOutput[2]), 'Sin(-Inf) = NaN');
  CheckNear(0.0, LOutput[3], 1e-6, 'Sin(0) = 0');
end;

procedure TestBatchCosSimd_Boundary;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
  LNaN, LPosInf, LNegInf: Single;
  LOldMask: TFPUExceptionMask;
begin
  PUInt32(@LNaN)^ := $7FC00000;
  PUInt32(@LPosInf)^ := $7F800000;
  PUInt32(@LNegInf)^ := $FF800000;

  LInput[0] := LNaN;
  LInput[1] := LPosInf;
  LInput[2] := LNegInf;
  LInput[3] := 0.0;

  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  LCount := BatchCosSimdF32(LInput, LOutput);
  SetExceptionMask(LOldMask);

  Check(LCount = 4, 'Cos boundary count');
  Check(IsNaN(LOutput[0]), 'Cos(NaN) = NaN');
  Check(IsNaN(LOutput[1]), 'Cos(+Inf) = NaN');
  Check(IsNaN(LOutput[2]), 'Cos(-Inf) = NaN');
  CheckNear(1.0, LOutput[3], 1e-6, 'Cos(0) = 1');
end;

procedure TestBatchTanSimd_Boundary;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
  LNaN, LPosInf, LNegInf: Single;
  LOldMask: TFPUExceptionMask;
begin
  PUInt32(@LNaN)^ := $7FC00000;
  PUInt32(@LPosInf)^ := $7F800000;
  PUInt32(@LNegInf)^ := $FF800000;

  LInput[0] := LNaN;
  LInput[1] := LPosInf;
  LInput[2] := LNegInf;
  LInput[3] := 0.0;

  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  LCount := BatchTanSimdF32(LInput, LOutput);
  SetExceptionMask(LOldMask);

  Check(LCount = 4, 'Tan boundary count');
  Check(IsNaN(LOutput[0]), 'Tan(NaN) = NaN');
  Check(IsNaN(LOutput[1]), 'Tan(+Inf) = NaN');
  Check(IsNaN(LOutput[2]), 'Tan(-Inf) = NaN');
  CheckNear(0.0, LOutput[3], 1e-6, 'Tan(0) = 0');
end;

procedure TestBatchExpSimd_Boundary;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
  LNaN, LPosInf, LNegInf: Single;
  LOldMask: TFPUExceptionMask;
begin
  PUInt32(@LNaN)^ := $7FC00000;
  PUInt32(@LPosInf)^ := $7F800000;
  PUInt32(@LNegInf)^ := $FF800000;

  LInput[0] := LNaN;
  LInput[1] := LPosInf;
  LInput[2] := LNegInf;
  LInput[3] := 0.0;

  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  LCount := BatchExpSimdF32(LInput, LOutput);
  SetExceptionMask(LOldMask);

  Check(LCount = 4, 'Exp boundary count');
  Check(IsNaN(LOutput[0]), 'Exp(NaN) = NaN');
  Check(IsInf(LOutput[1]) and (LOutput[1] > 0), 'Exp(+Inf) = +Inf');
  CheckNear(0.0, LOutput[2], 1e-6, 'Exp(-Inf) = 0');
  CheckNear(1.0, LOutput[3], 1e-6, 'Exp(0) = 1');
end;

procedure TestBatchLnSimd_Boundary;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
  LNaN, LPosInf, LNegOne: Single;
  LOldMask: TFPUExceptionMask;
begin
  PUInt32(@LNaN)^ := $7FC00000;
  PUInt32(@LPosInf)^ := $7F800000;
  LNegOne := -1.0;

  LInput[0] := LNaN;
  LInput[1] := LPosInf;
  LInput[2] := 0.0;
  LInput[3] := LNegOne;

  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  LCount := BatchLnSimdF32(LInput, LOutput);
  SetExceptionMask(LOldMask);

  Check(LCount = 4, 'Ln boundary count');
  Check(IsNaN(LOutput[0]), 'Ln(NaN) = NaN');
  Check(IsInf(LOutput[1]) and (LOutput[1] > 0), 'Ln(+Inf) = +Inf');
  Check(IsInf(LOutput[2]) and (LOutput[2] < 0), 'Ln(0) = -Inf');
  Check(IsNaN(LOutput[3]), 'Ln(-1) = NaN');
end;

procedure TestBatchSqrtSimd_Boundary;
var
  LInput: array[0..3] of Single;
  LOutput: array[0..3] of Single;
  LCount: SizeInt;
  LNaN, LPosInf, LNegOne: Single;
  LOldMask: TFPUExceptionMask;
begin
  PUInt32(@LNaN)^ := $7FC00000;
  PUInt32(@LPosInf)^ := $7F800000;
  LNegOne := -1.0;

  LInput[0] := LNaN;
  LInput[1] := LPosInf;
  LInput[2] := LNegOne;
  LInput[3] := 0.0;

  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  LCount := BatchSqrtSimdF32(LInput, LOutput);
  SetExceptionMask(LOldMask);

  Check(LCount = 4, 'Sqrt boundary count');
  Check(IsNaN(LOutput[0]), 'Sqrt(NaN) = NaN');
  Check(IsInf(LOutput[1]) and (LOutput[1] > 0), 'Sqrt(+Inf) = +Inf');
  Check(IsNaN(LOutput[2]), 'Sqrt(-1) = NaN');
  CheckNear(0.0, LOutput[3], 1e-6, 'Sqrt(0) = 0');
end;

procedure TestBatchAbsSimd_Boundary;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..2] of Single;
  LCount: SizeInt;
  LNaN: Single;
  LOldMask: TFPUExceptionMask;
begin
  PUInt32(@LNaN)^ := $7FC00000;

  LInput[0] := LNaN;
  LInput[1] := 0.0;
  LInput[2] := -0.0;

  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  LCount := BatchAbsSimdF32(LInput, LOutput);
  SetExceptionMask(LOldMask);

  Check(LCount = 3, 'Abs boundary count');
  Check(IsNaN(LOutput[0]), 'Abs(NaN) = NaN');
  CheckNear(0.0, LOutput[1], 1e-6, 'Abs(0) = 0');
  CheckNear(0.0, LOutput[2], 1e-6, 'Abs(-0) = 0');
end;

procedure TestBatchNegSimd_Boundary;
var
  LInput: array[0..1] of Single;
  LOutput: array[0..1] of Single;
  LCount: SizeInt;
  LNaN: Single;
  LOldMask: TFPUExceptionMask;
begin
  PUInt32(@LNaN)^ := $7FC00000;

  LInput[0] := LNaN;
  LInput[1] := 0.0;

  LOldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  LCount := BatchNegSimdF32(LInput, LOutput);
  SetExceptionMask(LOldMask);

  Check(LCount = 2, 'Neg boundary count');
  Check(IsNaN(LOutput[0]), 'Neg(NaN) = NaN');
  CheckNear(0.0, LOutput[1], 1e-6, 'Neg(0) = 0');
end;

{ ============================================================================
  F64 batch surface — open-array / count / Array*F64 dispatch
  ============================================================================ }

procedure TestBatchSinSimdF64;
var
  LInput: array[0..3] of Double;
  LOutput: array[0..3] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := PI_VALUE / 2;
  LInput[2] := PI_VALUE;
  LInput[3] := 3 * PI_VALUE / 2;

  LCount := BatchSinSimdF64(LInput, LOutput);
  Check(LCount = 4, 'BatchSinSimdF64 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-12, 'BatchSinSimdF64 [0]');
  CheckNear(1.0, LOutput[1], 1e-12, 'BatchSinSimdF64 [1]');
  CheckNear(0.0, LOutput[2], 1e-12, 'BatchSinSimdF64 [2]');
  CheckNear(-1.0, LOutput[3], 1e-12, 'BatchSinSimdF64 [3]');
end;

procedure TestBatchCosSimdF64;
var
  LInput: array[0..3] of Double;
  LOutput: array[0..3] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := PI_VALUE / 2;
  LInput[2] := PI_VALUE;
  LInput[3] := 3 * PI_VALUE / 2;

  LCount := BatchCosSimdF64(LInput, LOutput);
  Check(LCount = 4, 'BatchCosSimdF64 returns correct count');
  CheckNear(1.0, LOutput[0], 1e-12, 'BatchCosSimdF64 [0]');
  CheckNear(0.0, LOutput[1], 1e-12, 'BatchCosSimdF64 [1]');
  CheckNear(-1.0, LOutput[2], 1e-12, 'BatchCosSimdF64 [2]');
  CheckNear(0.0, LOutput[3], 1e-12, 'BatchCosSimdF64 [3]');
end;

procedure TestBatchTanSimdF64;
var
  LInput: array[0..1] of Double;
  LOutput: array[0..1] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := PI_VALUE / 4;

  LCount := BatchTanSimdF64(LInput, LOutput);
  Check(LCount = 2, 'BatchTanSimdF64 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-12, 'BatchTanSimdF64 [0]');
  CheckNear(1.0, LOutput[1], 1e-12, 'BatchTanSimdF64 [1]');
end;

procedure TestBatchSinCosSimdF64;
var
  LInput: array[0..3] of Double;
  LSinOutput: array[0..3] of Double;
  LCosOutput: array[0..3] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := PI_VALUE / 2;
  LInput[2] := PI_VALUE;
  LInput[3] := 3 * PI_VALUE / 2;

  LCount := BatchSinCosSimdF64(LInput, LSinOutput, LCosOutput);
  Check(LCount = 4, 'BatchSinCosSimdF64 returns correct count');
  CheckNear(0.0, LSinOutput[0], 1e-12, 'BatchSinCosSimdF64 Sin[0]');
  CheckNear(1.0, LSinOutput[1], 1e-12, 'BatchSinCosSimdF64 Sin[1]');
  CheckNear(1.0, LCosOutput[0], 1e-12, 'BatchSinCosSimdF64 Cos[0]');
  CheckNear(0.0, LCosOutput[1], 1e-12, 'BatchSinCosSimdF64 Cos[1]');
end;

procedure TestBatchExpSimdF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := 1.0;
  LInput[2] := 2.0;

  LCount := BatchExpSimdF64(LInput, LOutput);
  Check(LCount = 3, 'BatchExpSimdF64 returns correct count');
  CheckNear(1.0, LOutput[0], 1e-12, 'BatchExpSimdF64 [0]');
  CheckNear(2.718281828459045, LOutput[1], 1e-12, 'BatchExpSimdF64 [1]');
  CheckNear(7.38905609893065, LOutput[2], 1e-12, 'BatchExpSimdF64 [2]');
end;

procedure TestBatchLnSimdF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 2.718281828459045;
  LInput[2] := 7.38905609893065;

  LCount := BatchLnSimdF64(LInput, LOutput);
  Check(LCount = 3, 'BatchLnSimdF64 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-12, 'BatchLnSimdF64 [0]');
  CheckNear(1.0, LOutput[1], 1e-12, 'BatchLnSimdF64 [1]');
  CheckNear(2.0, LOutput[2], 1e-12, 'BatchLnSimdF64 [2]');
end;

procedure TestBatchLog2SimdF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 2.0;
  LInput[2] := 4.0;

  LCount := BatchLog2SimdF64(LInput, LOutput);
  Check(LCount = 3, 'BatchLog2SimdF64 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-12, 'BatchLog2SimdF64 [0]');
  CheckNear(1.0, LOutput[1], 1e-12, 'BatchLog2SimdF64 [1]');
  CheckNear(2.0, LOutput[2], 1e-12, 'BatchLog2SimdF64 [2]');
end;

procedure TestBatchLog10SimdF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 10.0;
  LInput[2] := 100.0;

  LCount := BatchLog10SimdF64(LInput, LOutput);
  Check(LCount = 3, 'BatchLog10SimdF64 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-12, 'BatchLog10SimdF64 [0]');
  CheckNear(1.0, LOutput[1], 1e-12, 'BatchLog10SimdF64 [1]');
  CheckNear(2.0, LOutput[2], 1e-12, 'BatchLog10SimdF64 [2]');
end;

procedure TestBatchSqrtSimdF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 0.0;
  LInput[1] := 4.0;
  LInput[2] := 9.0;

  LCount := BatchSqrtSimdF64(LInput, LOutput);
  Check(LCount = 3, 'BatchSqrtSimdF64 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-12, 'BatchSqrtSimdF64 [0]');
  CheckNear(2.0, LOutput[1], 1e-12, 'BatchSqrtSimdF64 [1]');
  CheckNear(3.0, LOutput[2], 1e-12, 'BatchSqrtSimdF64 [2]');
end;

procedure TestBatchAbsSimdF64;
var
  LInput: array[0..3] of Double;
  LOutput: array[0..3] of Double;
  LCount: SizeInt;
begin
  LInput[0] := -3.0;
  LInput[1] := -1.0;
  LInput[2] := 0.0;
  LInput[3] := 2.0;

  LCount := BatchAbsSimdF64(LInput, LOutput);
  Check(LCount = 4, 'BatchAbsSimdF64 returns correct count');
  CheckNear(3.0, LOutput[0], 1e-12, 'BatchAbsSimdF64 [0]');
  CheckNear(1.0, LOutput[1], 1e-12, 'BatchAbsSimdF64 [1]');
  CheckNear(0.0, LOutput[2], 1e-12, 'BatchAbsSimdF64 [2]');
  CheckNear(2.0, LOutput[3], 1e-12, 'BatchAbsSimdF64 [3]');
end;

procedure TestBatchNegSimdF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 0.0;
  LInput[2] := -2.0;

  LCount := BatchNegSimdF64(LInput, LOutput);
  Check(LCount = 3, 'BatchNegSimdF64 returns correct count');
  CheckNear(-1.0, LOutput[0], 1e-12, 'BatchNegSimdF64 [0]');
  CheckNear(0.0, LOutput[1], 1e-12, 'BatchNegSimdF64 [1]');
  CheckNear(2.0, LOutput[2], 1e-12, 'BatchNegSimdF64 [2]');
end;

procedure TestBatchCeilSimdF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 0.5;
  LInput[1] := 1.2;
  LInput[2] := -0.8;

  LCount := BatchCeilSimdF64(LInput, LOutput);
  Check(LCount = 3, 'BatchCeilSimdF64 returns correct count');
  CheckNear(1.0, LOutput[0], 1e-12, 'BatchCeilSimdF64 [0]');
  CheckNear(2.0, LOutput[1], 1e-12, 'BatchCeilSimdF64 [1]');
  CheckNear(0.0, LOutput[2], 1e-12, 'BatchCeilSimdF64 [2]');
end;

procedure TestBatchFloorSimdF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 0.5;
  LInput[1] := 1.2;
  LInput[2] := -0.8;

  LCount := BatchFloorSimdF64(LInput, LOutput);
  Check(LCount = 3, 'BatchFloorSimdF64 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-12, 'BatchFloorSimdF64 [0]');
  CheckNear(1.0, LOutput[1], 1e-12, 'BatchFloorSimdF64 [1]');
  CheckNear(-1.0, LOutput[2], 1e-12, 'BatchFloorSimdF64 [2]');
end;

procedure TestBatchRoundSimdF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 0.4;
  LInput[1] := 1.2;
  LInput[2] := 1.7;

  LCount := BatchRoundSimdF64(LInput, LOutput);
  Check(LCount = 3, 'BatchRoundSimdF64 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-12, 'BatchRoundSimdF64 [0]');
  CheckNear(1.0, LOutput[1], 1e-12, 'BatchRoundSimdF64 [1]');
  CheckNear(2.0, LOutput[2], 1e-12, 'BatchRoundSimdF64 [2]');
end;

procedure TestBatchTruncSimdF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 0.5;
  LInput[1] := 1.2;
  LInput[2] := -1.7;

  LCount := BatchTruncSimdF64(LInput, LOutput);
  Check(LCount = 3, 'BatchTruncSimdF64 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-12, 'BatchTruncSimdF64 [0]');
  CheckNear(1.0, LOutput[1], 1e-12, 'BatchTruncSimdF64 [1]');
  CheckNear(-1.0, LOutput[2], 1e-12, 'BatchTruncSimdF64 [2]');
end;

procedure TestBatchLerpSimdF64;
var
  LStart: array[0..2] of Double;
  LEnd: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LStart[0] := 0.0; LEnd[0] := 10.0;
  LStart[1] := 5.0; LEnd[1] := 15.0;
  LStart[2] := 10.0; LEnd[2] := 20.0;

  LCount := BatchLerpSimdF64(LStart, LEnd, 0.5, LOutput);
  Check(LCount = 3, 'BatchLerpSimdF64 returns correct count');
  CheckNear(5.0, LOutput[0], 1e-12, 'BatchLerpSimdF64 [0]');
  CheckNear(10.0, LOutput[1], 1e-12, 'BatchLerpSimdF64 [1]');
  CheckNear(15.0, LOutput[2], 1e-12, 'BatchLerpSimdF64 [2]');
end;

procedure TestBatchClampSimdF64;
var
  LInput: array[0..4] of Double;
  LOutput: array[0..4] of Double;
  LCount: SizeInt;
begin
  LInput[0] := -5.0;
  LInput[1] := 0.0;
  LInput[2] := 3.0;
  LInput[3] := 5.0;
  LInput[4] := 10.0;

  LCount := BatchClampSimdF64(LInput, 0.0, 5.0, LOutput);
  Check(LCount = 5, 'BatchClampSimdF64 returns correct count');
  CheckNear(0.0, LOutput[0], 1e-12, 'BatchClampSimdF64 [0]');
  CheckNear(0.0, LOutput[1], 1e-12, 'BatchClampSimdF64 [1]');
  CheckNear(3.0, LOutput[2], 1e-12, 'BatchClampSimdF64 [2]');
  CheckNear(5.0, LOutput[3], 1e-12, 'BatchClampSimdF64 [3]');
  CheckNear(5.0, LOutput[4], 1e-12, 'BatchClampSimdF64 [4]');
end;

procedure TestBatchScaleOffsetSimdF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..2] of Double;
  LCount: SizeInt;
begin
  LInput[0] := 1.0;
  LInput[1] := 2.0;
  LInput[2] := 3.0;

  LCount := BatchScaleOffsetSimdF64(LInput, 2.0, 1.0, LOutput);
  Check(LCount = 3, 'BatchScaleOffsetSimdF64 returns correct count');
  CheckNear(3.0, LOutput[0], 1e-12, 'BatchScaleOffsetSimdF64 [0]');
  CheckNear(5.0, LOutput[1], 1e-12, 'BatchScaleOffsetSimdF64 [1]');
  CheckNear(7.0, LOutput[2], 1e-12, 'BatchScaleOffsetSimdF64 [2]');
end;

procedure TestBatchSinEmptyF64;
var
  LInput: array of Double;
  LOutput: array of Double;
  LCount: SizeInt;
begin
  SetLength(LInput, 0);
  SetLength(LOutput, 0);
  LCount := BatchSinSimdF64(LInput, LOutput);
  Check(LCount = 0, 'Empty F64 input should return 0');
end;

procedure TestBatchSinMismatchedLengthF64;
var
  LInput: array[0..2] of Double;
  LOutput: array[0..0] of Double;
  LRaised: Boolean;
begin
  LInput[0] := 0.0;
  LInput[1] := 1.0;
  LInput[2] := 2.0;
  LRaised := False;
  try
    BatchSinSimdF64(LInput, LOutput);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'F64 mismatched lengths must raise EArgumentError');
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
  T.Test('BatchClampSimdF32 NaN', @TestBatchClampSimdF32_NaN);
  T.Test('BatchScaleOffsetSimdF32', @TestBatchScaleOffsetSimd);
  T.Test('BatchSinSimdF32 Empty', @TestBatchSinEmpty);
  T.Test('BatchSinSimdF32 MismatchedLength', @TestBatchSinMismatchedLength);
  T.Test('BatchLog alias + TryBatchLn', @TestBatchLogAliasAndTryLn);

  // Boundary value tests: NaN, Inf, -Inf, 0
  T.Test('BatchSinSimdF32 Boundary', @TestBatchSinSimd_Boundary);
  T.Test('BatchCosSimdF32 Boundary', @TestBatchCosSimd_Boundary);
  T.Test('BatchTanSimdF32 Boundary', @TestBatchTanSimd_Boundary);
  T.Test('BatchExpSimdF32 Boundary', @TestBatchExpSimd_Boundary);
  T.Test('BatchLnSimdF32 Boundary', @TestBatchLnSimd_Boundary);
  T.Test('BatchSqrtSimdF32 Boundary', @TestBatchSqrtSimd_Boundary);
  T.Test('BatchAbsSimdF32 Boundary', @TestBatchAbsSimd_Boundary);
  T.Test('BatchNegSimdF32 Boundary', @TestBatchNegSimd_Boundary);

  T.Test('BatchSinSimdF64', @TestBatchSinSimdF64);
  T.Test('BatchCosSimdF64', @TestBatchCosSimdF64);
  T.Test('BatchTanSimdF64', @TestBatchTanSimdF64);
  T.Test('BatchSinCosSimdF64', @TestBatchSinCosSimdF64);
  T.Test('BatchExpSimdF64', @TestBatchExpSimdF64);
  T.Test('BatchLnSimdF64', @TestBatchLnSimdF64);
  T.Test('BatchLog2SimdF64', @TestBatchLog2SimdF64);
  T.Test('BatchLog10SimdF64', @TestBatchLog10SimdF64);
  T.Test('BatchSqrtSimdF64', @TestBatchSqrtSimdF64);
  T.Test('BatchAbsSimdF64', @TestBatchAbsSimdF64);
  T.Test('BatchNegSimdF64', @TestBatchNegSimdF64);
  T.Test('BatchCeilSimdF64', @TestBatchCeilSimdF64);
  T.Test('BatchFloorSimdF64', @TestBatchFloorSimdF64);
  T.Test('BatchRoundSimdF64', @TestBatchRoundSimdF64);
  T.Test('BatchTruncSimdF64', @TestBatchTruncSimdF64);
  T.Test('BatchLerpSimdF64', @TestBatchLerpSimdF64);
  T.Test('BatchClampSimdF64', @TestBatchClampSimdF64);
  T.Test('BatchScaleOffsetSimdF64', @TestBatchScaleOffsetSimdF64);
  T.Test('BatchSinSimdF64 Empty', @TestBatchSinEmptyF64);
  T.Test('BatchSinSimdF64 MismatchedLength', @TestBatchSinMismatchedLengthF64);

  if not T.Run then Halt(1);
end.
