unit nextpas.core.simd.pipeline.f64;


{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.alloc,
  nextpas.core.simd.arrays.typed;

type
  TSimdF64PipeOp = (
    f64poMulScalar,
    f64poAddScalar,
    f64poLinear,
    f64poAbs,
    f64poNeg,
    f64poSqrt,
    f64poSquare,
    f64poClamp,
    f64poMin,
    f64poMax,
    f64poAddArray,
    f64poMulArray,
    f64poSubArray,
    f64poDivArray
  );

  TSimdF64PipeStep = record
    Op: TSimdF64PipeOp;
    ScalarA: Double;
    ScalarB: Double;
    ArrayPtr: PDouble;
  end;

  TSimdF64Plan = record
  private
    FSteps: array[0..15] of TSimdF64PipeStep;
    FStepCount: Integer;
  public
    procedure Execute(aSrc, aDst: PDouble; aCount: SizeUInt);
    function IsValid: Boolean;
  end;

  TSimdF64Pipeline = record
  private
    FSrc: PDouble;
    FCount: SizeUInt;
    FSteps: array[0..15] of TSimdF64PipeStep;
    FStepCount: Integer;
    procedure AddStep(aOp: TSimdF64PipeOp; aA: Double = 0; aB: Double = 0;
      aPtr: PDouble = nil);
    procedure Optimize;
  public
    class function From(aSrc: PDouble; aCount: SizeUInt): TSimdF64Pipeline; static;
    class function FromArray(const aArr: TSimdF64Array): TSimdF64Pipeline; static;

    function MulScalar(aValue: Double): TSimdF64Pipeline;
    function AddScalar(aValue: Double): TSimdF64Pipeline;
    function SubScalar(aValue: Double): TSimdF64Pipeline;
    function DivScalar(aValue: Double): TSimdF64Pipeline;
    function Linear(aScale, aBias: Double): TSimdF64Pipeline;
    function Abs: TSimdF64Pipeline;
    function Neg: TSimdF64Pipeline;
    function Sqrt: TSimdF64Pipeline;
    function Square: TSimdF64Pipeline;
    function Clamp(aMin, aMax: Double): TSimdF64Pipeline;
    function Min(aValue: Double): TSimdF64Pipeline;
    function Max(aValue: Double): TSimdF64Pipeline;

    function Add(aOther: PDouble): TSimdF64Pipeline;
    function Mul(aOther: PDouble): TSimdF64Pipeline;
    function Sub(aOther: PDouble): TSimdF64Pipeline;
    function Div_(aOther: PDouble): TSimdF64Pipeline;

    function AddArr(const aOther: TSimdF64Array): TSimdF64Pipeline;
    function MulArr(const aOther: TSimdF64Array): TSimdF64Pipeline;
    function SubArr(const aOther: TSimdF64Array): TSimdF64Pipeline;
    function DivArr(const aOther: TSimdF64Array): TSimdF64Pipeline;

    function ReduceSum: Double;
    function ReduceMax: Double;
    function ReduceMin: Double;
    function ReduceMean: Double;
    function ReduceNorm: Double;
    function ReduceDot(aOther: PDouble): Double;
    function ReduceDotArr(const aOther: TSimdF64Array): Double;

    procedure Into(aDst: PDouble);
    procedure IntoArray(var aDst: TSimdF64Array);
    function Eval: TSimdF64Array;
    function StepCount: Integer;
    function Compile: TSimdF64Plan;
  end;

implementation

uses
  nextpas.core.simd;

// --- Scalar helpers for F64 ops not yet in dispatch ---

procedure F64MulScalar(aSrc, aDst: PDouble; aCount: SizeUInt; aVal: Double);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] * aVal;
end;

procedure F64AddScalar(aSrc, aDst: PDouble; aCount: SizeUInt; aVal: Double);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] + aVal;
end;

procedure F64Linear(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] * aScale + aBias;
end;

procedure F64Clamp(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
var i: SizeUInt; v: Double;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i];
    if v < aMin then v := aMin
    else if v > aMax then v := aMax;
    aDst[i] := v;
  end;
end;

// --- Pipeline implementation ---

procedure TSimdF64Pipeline.AddStep(aOp: TSimdF64PipeOp; aA: Double; aB: Double;
  aPtr: PDouble);
begin
  if FStepCount >= 16 then Exit;
  FSteps[FStepCount].Op := aOp;
  FSteps[FStepCount].ScalarA := aA;
  FSteps[FStepCount].ScalarB := aB;
  FSteps[FStepCount].ArrayPtr := aPtr;
  Inc(FStepCount);
end;

class function TSimdF64Pipeline.From(aSrc: PDouble; aCount: SizeUInt): TSimdF64Pipeline;
begin
  Result.FSrc := aSrc;
  Result.FCount := aCount;
  Result.FStepCount := 0;
end;

class function TSimdF64Pipeline.FromArray(const aArr: TSimdF64Array): TSimdF64Pipeline;
begin
  Result.FSrc := aArr.Data;
  Result.FCount := aArr.Count;
  Result.FStepCount := 0;
end;

function TSimdF64Pipeline.MulScalar(aValue: Double): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poMulScalar, aValue); end;

function TSimdF64Pipeline.AddScalar(aValue: Double): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poAddScalar, aValue); end;

function TSimdF64Pipeline.SubScalar(aValue: Double): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poAddScalar, -aValue); end;

function TSimdF64Pipeline.DivScalar(aValue: Double): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poMulScalar, 1.0 / aValue); end;

function TSimdF64Pipeline.Linear(aScale, aBias: Double): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poLinear, aScale, aBias); end;

function TSimdF64Pipeline.Abs: TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poAbs); end;

function TSimdF64Pipeline.Neg: TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poNeg); end;

function TSimdF64Pipeline.Sqrt: TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poSqrt); end;

function TSimdF64Pipeline.Square: TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poSquare); end;

function TSimdF64Pipeline.Clamp(aMin, aMax: Double): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poClamp, aMin, aMax); end;

function TSimdF64Pipeline.Min(aValue: Double): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poMin, aValue); end;

function TSimdF64Pipeline.Max(aValue: Double): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poMax, aValue); end;

function TSimdF64Pipeline.Add(aOther: PDouble): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poAddArray, 0, 0, aOther); end;

function TSimdF64Pipeline.Mul(aOther: PDouble): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poMulArray, 0, 0, aOther); end;

function TSimdF64Pipeline.Sub(aOther: PDouble): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poSubArray, 0, 0, aOther); end;

function TSimdF64Pipeline.Div_(aOther: PDouble): TSimdF64Pipeline;
begin Result := Self; Result.AddStep(f64poDivArray, 0, 0, aOther); end;

function TSimdF64Pipeline.AddArr(const aOther: TSimdF64Array): TSimdF64Pipeline;
begin Result := Add(aOther.Data); end;

function TSimdF64Pipeline.MulArr(const aOther: TSimdF64Array): TSimdF64Pipeline;
begin Result := Mul(aOther.Data); end;

function TSimdF64Pipeline.SubArr(const aOther: TSimdF64Array): TSimdF64Pipeline;
begin Result := Sub(aOther.Data); end;

function TSimdF64Pipeline.DivArr(const aOther: TSimdF64Array): TSimdF64Pipeline;
begin Result := Div_(aOther.Data); end;

function TSimdF64Pipeline.StepCount: Integer;
begin Result := FStepCount; end;

procedure TSimdF64Pipeline.Optimize;
var
  i, j: Integer;
  LNew: array[0..15] of TSimdF64PipeStep;
  LNewCount: Integer;
  LChanged: Boolean;
begin
  if FStepCount = 0 then Exit;
  repeat
    LChanged := False;
    LNewCount := 0;
    FillChar(LNew, SizeOf(LNew), 0);
    i := 0;
    while i < FStepCount do
    begin
      if (FSteps[i].Op = f64poMulScalar) and (FSteps[i].ScalarA = 1.0) then
      begin Inc(i); LChanged := True; Continue; end;
      if (FSteps[i].Op = f64poAddScalar) and (FSteps[i].ScalarA = 0.0) then
      begin Inc(i); LChanged := True; Continue; end;
      if (FSteps[i].Op = f64poLinear) and (FSteps[i].ScalarA = 1.0) and (FSteps[i].ScalarB = 0.0) then
      begin Inc(i); LChanged := True; Continue; end;

      if (i + 1 < FStepCount) then
      begin
        if (FSteps[i].Op = f64poMulScalar) and (FSteps[i+1].Op = f64poAddScalar) then
        begin
          LNew[LNewCount].Op := f64poLinear;
          LNew[LNewCount].ScalarA := FSteps[i].ScalarA;
          LNew[LNewCount].ScalarB := FSteps[i+1].ScalarA;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        if (FSteps[i].Op = f64poAddScalar) and (FSteps[i+1].Op = f64poMulScalar) then
        begin
          LNew[LNewCount].Op := f64poLinear;
          LNew[LNewCount].ScalarA := FSteps[i+1].ScalarA;
          LNew[LNewCount].ScalarB := FSteps[i].ScalarA * FSteps[i+1].ScalarA;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        if (FSteps[i].Op = f64poNeg) and (FSteps[i+1].Op = f64poNeg) then
        begin Inc(i, 2); LChanged := True; Continue; end;
        if (FSteps[i].Op = f64poLinear) and (FSteps[i+1].Op = f64poLinear) then
        begin
          LNew[LNewCount].Op := f64poLinear;
          LNew[LNewCount].ScalarA := FSteps[i].ScalarA * FSteps[i+1].ScalarA;
          LNew[LNewCount].ScalarB := FSteps[i].ScalarB * FSteps[i+1].ScalarA + FSteps[i+1].ScalarB;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        if (FSteps[i].Op = f64poMulScalar) and (FSteps[i+1].Op = f64poMulScalar) then
        begin
          LNew[LNewCount].Op := f64poMulScalar;
          LNew[LNewCount].ScalarA := FSteps[i].ScalarA * FSteps[i+1].ScalarA;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        if (FSteps[i].Op = f64poAddScalar) and (FSteps[i+1].Op = f64poAddScalar) then
        begin
          LNew[LNewCount].Op := f64poAddScalar;
          LNew[LNewCount].ScalarA := FSteps[i].ScalarA + FSteps[i+1].ScalarA;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        if (FSteps[i].Op = f64poClamp) and (FSteps[i+1].Op = f64poClamp) then
        begin
          LNew[LNewCount].Op := f64poClamp;
          if FSteps[i].ScalarA > FSteps[i+1].ScalarA then
            LNew[LNewCount].ScalarA := FSteps[i].ScalarA
          else
            LNew[LNewCount].ScalarA := FSteps[i+1].ScalarA;
          if FSteps[i].ScalarB < FSteps[i+1].ScalarB then
            LNew[LNewCount].ScalarB := FSteps[i].ScalarB
          else
            LNew[LNewCount].ScalarB := FSteps[i+1].ScalarB;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
      end;
      LNew[LNewCount] := FSteps[i];
      Inc(LNewCount);
      Inc(i);
    end;
    for j := 0 to LNewCount - 1 do FSteps[j] := LNew[j];
    FStepCount := LNewCount;
  until not LChanged;
end;

procedure TSimdF64Pipeline.Into(aDst: PDouble);
var
  i: Integer;
  LSrc: PDouble;
begin
  if FCount = 0 then Exit;
  if FStepCount = 0 then
  begin
    Move(FSrc^, aDst^, FCount * SizeOf(Double));
    Exit;
  end;

  Optimize;

  if FStepCount = 0 then
  begin
    Move(FSrc^, aDst^, FCount * SizeOf(Double));
    Exit;
  end;

  LSrc := FSrc;
  for i := 0 to FStepCount - 1 do
  begin
    case FSteps[i].Op of
      f64poMulScalar: ArrayMulScalarF64(LSrc, aDst, FCount, FSteps[i].ScalarA);
      f64poAddScalar: ArrayAddScalarF64(LSrc, aDst, FCount, FSteps[i].ScalarA);
      f64poLinear:    ArrayLinearF64(LSrc, aDst, FCount, FSteps[i].ScalarA, FSteps[i].ScalarB);
      f64poAbs:       ArrayAbsF64(LSrc, aDst, FCount);
      f64poNeg:       ArrayNegF64(LSrc, aDst, FCount);
      f64poSqrt:      ArraySqrtF64(LSrc, aDst, FCount);
      f64poSquare:    ArrayMulF64(LSrc, LSrc, aDst, FCount);
      f64poClamp:     ArrayClampF64(LSrc, aDst, FCount, FSteps[i].ScalarA, FSteps[i].ScalarB);
      f64poMin:       ArrayClampF64(LSrc, aDst, FCount, -1.7976931348623157e308, FSteps[i].ScalarA);
      f64poMax:       ArrayClampF64(LSrc, aDst, FCount, FSteps[i].ScalarA, 1.7976931348623157e308);
      f64poAddArray:  ArrayAddF64(LSrc, FSteps[i].ArrayPtr, aDst, FCount);
      f64poMulArray:  ArrayMulF64(LSrc, FSteps[i].ArrayPtr, aDst, FCount);
      f64poSubArray:  ArraySubF64(LSrc, FSteps[i].ArrayPtr, aDst, FCount);
      f64poDivArray:  ArrayDivF64(LSrc, FSteps[i].ArrayPtr, aDst, FCount);
    end;
    LSrc := aDst;
  end;
end;

procedure TSimdF64Pipeline.IntoArray(var aDst: TSimdF64Array);
begin
  Into(aDst.Data);
end;

function TSimdF64Pipeline.Eval: TSimdF64Array;
begin
  Result := TSimdF64Array.Create(FCount);
  Into(Result.Data);
end;

function TSimdF64Pipeline.ReduceSum: Double;
var LTmp: TSimdF64Array;
begin
  Optimize;
  if FStepCount = 0 then
    Result := nextpas.core.simd.ReduceSumF64(FSrc, FCount)
  else if (FStepCount = 1) and (FSteps[0].Op = f64poSquare) then
    Result := nextpas.core.simd.ReduceDotF64(FSrc, FSrc, FCount)
  else if (FStepCount = 1) and (FSteps[0].Op = f64poMulArray) then
    Result := nextpas.core.simd.ReduceDotF64(FSrc, FSteps[0].ArrayPtr, FCount)
  else if (FStepCount = 1) and (FSteps[0].Op = f64poMulScalar) then
    Result := FSteps[0].ScalarA * nextpas.core.simd.ReduceSumF64(FSrc, FCount)
  else
  begin
    LTmp := TSimdF64Array.Create(FCount);
    Into(LTmp.Data);
    Result := nextpas.core.simd.ReduceSumF64(LTmp.Data, FCount);
    LTmp.Free;
  end;
end;

function TSimdF64Pipeline.ReduceMax: Double;
var LTmp: TSimdF64Array;
begin
  Optimize;
  if FStepCount = 0 then
    Result := nextpas.core.simd.ReduceMaxF64(FSrc, FCount)
  else
  begin
    LTmp := TSimdF64Array.Create(FCount);
    Into(LTmp.Data);
    Result := nextpas.core.simd.ReduceMaxF64(LTmp.Data, FCount);
    LTmp.Free;
  end;
end;

function TSimdF64Pipeline.ReduceMin: Double;
var LTmp: TSimdF64Array;
begin
  Optimize;
  if FStepCount = 0 then
    Result := nextpas.core.simd.ReduceMinF64(FSrc, FCount)
  else
  begin
    LTmp := TSimdF64Array.Create(FCount);
    Into(LTmp.Data);
    Result := nextpas.core.simd.ReduceMinF64(LTmp.Data, FCount);
    LTmp.Free;
  end;
end;

function TSimdF64Pipeline.ReduceDot(aOther: PDouble): Double;
var LTmp: TSimdF64Array;
begin
  Optimize;
  if FStepCount = 0 then
    Result := nextpas.core.simd.ReduceDotF64(FSrc, aOther, FCount)
  else
  begin
    LTmp := TSimdF64Array.Create(FCount);
    Into(LTmp.Data);
    Result := nextpas.core.simd.ReduceDotF64(LTmp.Data, aOther, FCount);
    LTmp.Free;
  end;
end;

function TSimdF64Pipeline.ReduceDotArr(const aOther: TSimdF64Array): Double;
begin
  Result := ReduceDot(aOther.Data);
end;

function TSimdF64Pipeline.ReduceMean: Double;
begin
  if FCount = 0 then Exit(0);
  Result := ReduceSum / FCount;
end;

function TSimdF64Pipeline.ReduceNorm: Double;
var LTmp: TSimdF64Array;
begin
  Optimize;
  if FStepCount = 0 then
    Result := System.Sqrt(nextpas.core.simd.ReduceDotF64(FSrc, FSrc, FCount))
  else
  begin
    LTmp := TSimdF64Array.Create(FCount);
    Into(LTmp.Data);
    Result := System.Sqrt(nextpas.core.simd.ReduceDotF64(LTmp.Data, LTmp.Data, FCount));
    LTmp.Free;
  end;
end;

function TSimdF64Pipeline.Compile: TSimdF64Plan;
var i: Integer;
begin
  Optimize;
  Result.FStepCount := FStepCount;
  for i := 0 to FStepCount - 1 do
    Result.FSteps[i] := FSteps[i];
end;

function TSimdF64Plan.IsValid: Boolean;
begin
  Result := FStepCount > 0;
end;

procedure TSimdF64Plan.Execute(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: Integer;
  LSrc: PDouble;
begin
  if (aCount = 0) or (FStepCount = 0) then
  begin
    if aCount > 0 then Move(aSrc^, aDst^, aCount * SizeOf(Double));
    Exit;
  end;
  LSrc := aSrc;
  for i := 0 to FStepCount - 1 do
  begin
    case FSteps[i].Op of
      f64poMulScalar: ArrayMulScalarF64(LSrc, aDst, aCount, FSteps[i].ScalarA);
      f64poAddScalar: ArrayAddScalarF64(LSrc, aDst, aCount, FSteps[i].ScalarA);
      f64poLinear:    ArrayLinearF64(LSrc, aDst, aCount, FSteps[i].ScalarA, FSteps[i].ScalarB);
      f64poAbs:       ArrayAbsF64(LSrc, aDst, aCount);
      f64poNeg:       ArrayNegF64(LSrc, aDst, aCount);
      f64poSqrt:      ArraySqrtF64(LSrc, aDst, aCount);
      f64poSquare:    ArrayMulF64(LSrc, LSrc, aDst, aCount);
      f64poClamp:     ArrayClampF64(LSrc, aDst, aCount, FSteps[i].ScalarA, FSteps[i].ScalarB);
      f64poMin:       ArrayClampF64(LSrc, aDst, aCount, -1.7976931348623157e308, FSteps[i].ScalarA);
      f64poMax:       ArrayClampF64(LSrc, aDst, aCount, FSteps[i].ScalarA, 1.7976931348623157e308);
      f64poAddArray:  ArrayAddF64(LSrc, FSteps[i].ArrayPtr, aDst, aCount);
      f64poMulArray:  ArrayMulF64(LSrc, FSteps[i].ArrayPtr, aDst, aCount);
      f64poSubArray:  ArraySubF64(LSrc, FSteps[i].ArrayPtr, aDst, aCount);
      f64poDivArray:  ArrayDivF64(LSrc, FSteps[i].ArrayPtr, aDst, aCount);
    end;
    LSrc := aDst;
  end;
end;

end.
