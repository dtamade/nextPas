unit nextpas.core.simd.pipeline;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.alloc,
  nextpas.core.simd.arrays.typed;

type
  TSimdPipeOp = (
    poMulScalar,
    poAddScalar,
    poLinear,
    poReLU,
    poAbs,
    poNeg,
    poExp,
    poLog,
    poSqrt,
    poSin,
    poCos,
    poSigmoid,
    poClamp,
    poRcp,
    poSiLU,
    poLeakyReLU,
    poMin,
    poMax,
    poTanh,
    poSquare,
    poPow,
    poAddArray,
    poMulArray,
    poSubArray,
    poDivArray,
    poFma,
    poLinearReLU,
    poLinearClamp,
    poAbsDiff,
    poAxpy,
    poFmaFused
  );

  TSimdPipeStep = record
    Op: TSimdPipeOp;
    ScalarA: Single;
    ScalarB: Single;
    ArrayPtr: PSingle;
    ArrayPtr2: PSingle;
  end;

  TSimdF32Plan = record
  private
    FSteps: array[0..15] of TSimdPipeStep;
    FStepCount: Integer;
  public
    procedure Execute(aSrc, aDst: PSingle; aCount: SizeUInt);
    function IsValid: Boolean;
  end;

  TSimdF32Pipeline = record
  private
    FSrc: PSingle;
    FCount: SizeUInt;
    FSteps: array[0..15] of TSimdPipeStep;
    FStepCount: Integer;
    procedure AddStep(aOp: TSimdPipeOp; aA: Single = 0; aB: Single = 0; aPtr: PSingle = nil);
    procedure Optimize;
  public
    class function From(aSrc: PSingle; aCount: SizeUInt): TSimdF32Pipeline; static;
    class function FromArray(const aArr: TSimdF32Array): TSimdF32Pipeline; static;

    function MulScalar(aValue: Single): TSimdF32Pipeline;
    function AddScalar(aValue: Single): TSimdF32Pipeline;
    function SubScalar(aValue: Single): TSimdF32Pipeline;
    function DivScalar(aValue: Single): TSimdF32Pipeline;
    function Linear(aScale, aBias: Single): TSimdF32Pipeline;
    function ReLU: TSimdF32Pipeline;
    function Abs: TSimdF32Pipeline;
    function Neg: TSimdF32Pipeline;
    function Exp: TSimdF32Pipeline;
    function Log: TSimdF32Pipeline;
    function Sqrt: TSimdF32Pipeline;
    function Sin: TSimdF32Pipeline;
    function Cos: TSimdF32Pipeline;
    function Sigmoid: TSimdF32Pipeline;
    function Clamp(aMin, aMax: Single): TSimdF32Pipeline;
    function Rcp: TSimdF32Pipeline;
    function SiLU: TSimdF32Pipeline;
    function LeakyReLU(aAlpha: Single = 0.01): TSimdF32Pipeline;
    function Min(aValue: Single): TSimdF32Pipeline;
    function Max(aValue: Single): TSimdF32Pipeline;
    function Tanh: TSimdF32Pipeline;
    function Square: TSimdF32Pipeline;
    function Pow(aExponent: Single): TSimdF32Pipeline;

    function Add(aOther: PSingle): TSimdF32Pipeline;
    function Mul(aOther: PSingle): TSimdF32Pipeline;
    function Sub(aOther: PSingle): TSimdF32Pipeline;
    function Div_(aOther: PSingle): TSimdF32Pipeline;
    function Fma(aMul, aAdd: PSingle): TSimdF32Pipeline;

    function AddArr(const aOther: TSimdF32Array): TSimdF32Pipeline;
    function MulArr(const aOther: TSimdF32Array): TSimdF32Pipeline;
    function SubArr(const aOther: TSimdF32Array): TSimdF32Pipeline;
    function DivArr(const aOther: TSimdF32Array): TSimdF32Pipeline;
    function FmaArr(const aMul, aAdd: TSimdF32Array): TSimdF32Pipeline;

    function ReduceSum: Single;
    function ReduceMax: Single;
    function ReduceMin: Single;
    function ReduceMean: Single;
    function ReduceNorm: Single;
    function ReduceDot(aOther: PSingle): Single;
    function ReduceDotArr(const aOther: TSimdF32Array): Single;

    procedure Into(aDst: PSingle);
    procedure IntoArray(var aDst: TSimdF32Array);
    function Eval: TSimdF32Array;
    function StepCount: Integer;
    function Compile: TSimdF32Plan;
  end;

implementation

uses
  nextpas.core.simd,
  nextpas.core.simd.nn;

procedure PipeLeakyReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aAlpha: Single);
begin
  if aCount = 0 then Exit;
  LeakyReLUF32(aSrc, aDst, aCount, aAlpha);
end;

procedure PipeMinScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aVal: Single);
begin
  if aCount = 0 then Exit;
  ArrayClampF32(aSrc, aDst, aCount, -3.4028235e38, aVal);
end;

procedure PipeMaxScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aVal: Single);
begin
  if aCount = 0 then Exit;
  ArrayClampF32(aSrc, aDst, aCount, aVal, 3.4028235e38);
end;

procedure PipeTanhF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  TanhF32(aSrc, aDst, aCount);
end;

procedure PipeLinearReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
begin
  ArrayLinearReLUF32(aSrc, aDst, aCount, aScale, aBias);
end;

procedure PipeLinearClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias, aMin, aMax: Single);
begin
  ArrayLinearF32(aSrc, aDst, aCount, aScale, aBias);
  ArrayClampF32(aDst, aDst, aCount, aMin, aMax);
end;

procedure PipeAbsDiffF32(aSrc, aOther, aDst: PSingle; aCount: SizeUInt);
begin
  ArrayAbsDiffF32(aSrc, aOther, aDst, aCount);
end;

procedure PipeAxpyF32(aSrc, aY, aDst: PSingle; aCount: SizeUInt; aAlpha: Single);
begin
  ArrayAxpyF32(aAlpha, aSrc, aY, aDst, aCount);
end;

procedure TSimdF32Pipeline.AddStep(aOp: TSimdPipeOp; aA: Single; aB: Single; aPtr: PSingle);
begin
  if FStepCount >= 16 then Exit;
  FSteps[FStepCount].Op := aOp;
  FSteps[FStepCount].ScalarA := aA;
  FSteps[FStepCount].ScalarB := aB;
  FSteps[FStepCount].ArrayPtr := aPtr;
  FSteps[FStepCount].ArrayPtr2 := nil;
  Inc(FStepCount);
end;

class function TSimdF32Pipeline.From(aSrc: PSingle; aCount: SizeUInt): TSimdF32Pipeline;
begin
  Result.FSrc := aSrc;
  Result.FCount := aCount;
  Result.FStepCount := 0;
end;

class function TSimdF32Pipeline.FromArray(const aArr: TSimdF32Array): TSimdF32Pipeline;
begin
  Result.FSrc := aArr.Data;
  Result.FCount := aArr.Count;
  Result.FStepCount := 0;
end;

function TSimdF32Pipeline.MulScalar(aValue: Single): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poMulScalar, aValue);
end;

function TSimdF32Pipeline.AddScalar(aValue: Single): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poAddScalar, aValue);
end;

function TSimdF32Pipeline.SubScalar(aValue: Single): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poAddScalar, -aValue);
end;

function TSimdF32Pipeline.DivScalar(aValue: Single): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poMulScalar, 1.0 / aValue);
end;

function TSimdF32Pipeline.Linear(aScale, aBias: Single): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poLinear, aScale, aBias);
end;

function TSimdF32Pipeline.ReLU: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poReLU);
end;

function TSimdF32Pipeline.Abs: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poAbs);
end;

function TSimdF32Pipeline.Neg: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poNeg);
end;

function TSimdF32Pipeline.Exp: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poExp);
end;

function TSimdF32Pipeline.Log: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poLog);
end;

function TSimdF32Pipeline.Sqrt: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poSqrt);
end;

function TSimdF32Pipeline.Sin: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poSin);
end;

function TSimdF32Pipeline.Cos: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poCos);
end;

function TSimdF32Pipeline.Sigmoid: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poSigmoid);
end;

function TSimdF32Pipeline.Clamp(aMin, aMax: Single): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poClamp, aMin, aMax);
end;

function TSimdF32Pipeline.Rcp: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poRcp);
end;

function TSimdF32Pipeline.SiLU: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poSiLU);
end;

function TSimdF32Pipeline.LeakyReLU(aAlpha: Single): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poLeakyReLU, aAlpha);
end;

function TSimdF32Pipeline.Min(aValue: Single): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poMin, aValue);
end;

function TSimdF32Pipeline.Max(aValue: Single): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poMax, aValue);
end;

function TSimdF32Pipeline.Tanh: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poTanh);
end;

function TSimdF32Pipeline.Square: TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poSquare);
end;

function TSimdF32Pipeline.Pow(aExponent: Single): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poPow, aExponent);
end;

function TSimdF32Pipeline.Add(aOther: PSingle): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poAddArray, 0, 0, aOther);
end;

function TSimdF32Pipeline.Mul(aOther: PSingle): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poMulArray, 0, 0, aOther);
end;

function TSimdF32Pipeline.Sub(aOther: PSingle): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poSubArray, 0, 0, aOther);
end;

function TSimdF32Pipeline.Div_(aOther: PSingle): TSimdF32Pipeline;
begin
  Result := Self;
  Result.AddStep(poDivArray, 0, 0, aOther);
end;

function TSimdF32Pipeline.Fma(aMul, aAdd: PSingle): TSimdF32Pipeline;
begin
  Result := Self;
  if Result.FStepCount >= 16 then Exit;
  Result.FSteps[Result.FStepCount].Op := poFmaFused;
  Result.FSteps[Result.FStepCount].ScalarA := 0;
  Result.FSteps[Result.FStepCount].ScalarB := 0;
  Result.FSteps[Result.FStepCount].ArrayPtr := aMul;
  Result.FSteps[Result.FStepCount].ArrayPtr2 := aAdd;
  Inc(Result.FStepCount);
end;

function TSimdF32Pipeline.AddArr(const aOther: TSimdF32Array): TSimdF32Pipeline;
begin
  Result := Add(aOther.Data);
end;

function TSimdF32Pipeline.MulArr(const aOther: TSimdF32Array): TSimdF32Pipeline;
begin
  Result := Mul(aOther.Data);
end;

function TSimdF32Pipeline.SubArr(const aOther: TSimdF32Array): TSimdF32Pipeline;
begin
  Result := Sub(aOther.Data);
end;

function TSimdF32Pipeline.DivArr(const aOther: TSimdF32Array): TSimdF32Pipeline;
begin
  Result := Div_(aOther.Data);
end;

function TSimdF32Pipeline.FmaArr(const aMul, aAdd: TSimdF32Array): TSimdF32Pipeline;
begin
  Result := Fma(aMul.Data, aAdd.Data);
end;

function TSimdF32Pipeline.StepCount: Integer;
begin
  Result := FStepCount;
end;

procedure TSimdF32Pipeline.Optimize;
var
  i, j: Integer;
  LNew: array[0..15] of TSimdPipeStep;
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
      // Identity elimination: skip no-op steps
      if (FSteps[i].Op = poMulScalar) and (FSteps[i].ScalarA = 1.0) then
      begin Inc(i); LChanged := True; Continue; end;
      if (FSteps[i].Op = poAddScalar) and (FSteps[i].ScalarA = 0.0) then
      begin Inc(i); LChanged := True; Continue; end;
      if (FSteps[i].Op = poLinear) and (FSteps[i].ScalarA = 1.0) and (FSteps[i].ScalarB = 0.0) then
      begin Inc(i); LChanged := True; Continue; end;

      if (i + 1 < FStepCount) then
      begin
        // MulScalar + AddScalar → Linear
        if (FSteps[i].Op = poMulScalar) and (FSteps[i+1].Op = poAddScalar) then
        begin
          LNew[LNewCount].Op := poLinear;
          LNew[LNewCount].ScalarA := FSteps[i].ScalarA;
          LNew[LNewCount].ScalarB := FSteps[i+1].ScalarA;
          LNew[LNewCount].ArrayPtr := nil;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // AddScalar + MulScalar → Linear: (x+b)*a = x*a + b*a
        if (FSteps[i].Op = poAddScalar) and (FSteps[i+1].Op = poMulScalar) then
        begin
          LNew[LNewCount].Op := poLinear;
          LNew[LNewCount].ScalarA := FSteps[i+1].ScalarA;
          LNew[LNewCount].ScalarB := FSteps[i].ScalarA * FSteps[i+1].ScalarA;
          LNew[LNewCount].ArrayPtr := nil;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // Neg + MulScalar → MulScalar(-a)
        if (FSteps[i].Op = poNeg) and (FSteps[i+1].Op = poMulScalar) then
        begin
          LNew[LNewCount].Op := poMulScalar;
          LNew[LNewCount].ScalarA := -FSteps[i+1].ScalarA;
          LNew[LNewCount].ArrayPtr := nil;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // Neg + AddScalar → Linear(-1, b)
        if (FSteps[i].Op = poNeg) and (FSteps[i+1].Op = poAddScalar) then
        begin
          LNew[LNewCount].Op := poLinear;
          LNew[LNewCount].ScalarA := -1.0;
          LNew[LNewCount].ScalarB := FSteps[i+1].ScalarA;
          LNew[LNewCount].ArrayPtr := nil;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // Neg + Neg → identity (remove both)
        if (FSteps[i].Op = poNeg) and (FSteps[i+1].Op = poNeg) then
        begin
          Inc(i, 2); LChanged := True; Continue;
        end;
        // Linear + Linear → Linear (affine composition)
        if (FSteps[i].Op = poLinear) and (FSteps[i+1].Op = poLinear) then
        begin
          LNew[LNewCount].Op := poLinear;
          LNew[LNewCount].ScalarA := FSteps[i].ScalarA * FSteps[i+1].ScalarA;
          LNew[LNewCount].ScalarB := FSteps[i].ScalarB * FSteps[i+1].ScalarA + FSteps[i+1].ScalarB;
          LNew[LNewCount].ArrayPtr := nil;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // MulScalar + MulScalar → MulScalar
        if (FSteps[i].Op = poMulScalar) and (FSteps[i+1].Op = poMulScalar) then
        begin
          LNew[LNewCount].Op := poMulScalar;
          LNew[LNewCount].ScalarA := FSteps[i].ScalarA * FSteps[i+1].ScalarA;
          LNew[LNewCount].ArrayPtr := nil;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // AddScalar + AddScalar → AddScalar
        if (FSteps[i].Op = poAddScalar) and (FSteps[i+1].Op = poAddScalar) then
        begin
          LNew[LNewCount].Op := poAddScalar;
          LNew[LNewCount].ScalarA := FSteps[i].ScalarA + FSteps[i+1].ScalarA;
          LNew[LNewCount].ArrayPtr := nil;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // Linear + ReLU → LinearReLU
        if (FSteps[i].Op = poLinear) and (FSteps[i+1].Op = poReLU) then
        begin
          LNew[LNewCount].Op := poLinearReLU;
          LNew[LNewCount].ScalarA := FSteps[i].ScalarA;
          LNew[LNewCount].ScalarB := FSteps[i].ScalarB;
          LNew[LNewCount].ArrayPtr := nil;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // SubArray + Abs → AbsDiff
        if (FSteps[i].Op = poSubArray) and (FSteps[i+1].Op = poAbs) then
        begin
          LNew[LNewCount].Op := poAbsDiff;
          LNew[LNewCount].ScalarA := 0;
          LNew[LNewCount].ScalarB := 0;
          LNew[LNewCount].ArrayPtr := FSteps[i].ArrayPtr;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // MulScalar + AddArray → Axpy (alpha*X + Y)
        if (FSteps[i].Op = poMulScalar) and (FSteps[i+1].Op = poAddArray) then
        begin
          LNew[LNewCount].Op := poAxpy;
          LNew[LNewCount].ScalarA := FSteps[i].ScalarA;
          LNew[LNewCount].ScalarB := 0;
          LNew[LNewCount].ArrayPtr := FSteps[i+1].ArrayPtr;
          LNew[LNewCount].ArrayPtr2 := nil;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // MulArray + AddArray → FmaFused (X*A + B)
        if (FSteps[i].Op = poFma) and (FSteps[i+1].Op = poAddArray) then
        begin
          LNew[LNewCount].Op := poFmaFused;
          LNew[LNewCount].ScalarA := 0;
          LNew[LNewCount].ScalarB := 0;
          LNew[LNewCount].ArrayPtr := FSteps[i].ArrayPtr;
          LNew[LNewCount].ArrayPtr2 := FSteps[i+1].ArrayPtr;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // MulScalar + ReLU → LinearReLU(a, 0)
        if (FSteps[i].Op = poMulScalar) and (FSteps[i+1].Op = poReLU) then
        begin
          LNew[LNewCount].Op := poLinearReLU;
          LNew[LNewCount].ScalarA := FSteps[i].ScalarA;
          LNew[LNewCount].ScalarB := 0;
          LNew[LNewCount].ArrayPtr := nil;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // AddScalar + ReLU → LinearReLU(1, b)
        if (FSteps[i].Op = poAddScalar) and (FSteps[i+1].Op = poReLU) then
        begin
          LNew[LNewCount].Op := poLinearReLU;
          LNew[LNewCount].ScalarA := 1.0;
          LNew[LNewCount].ScalarB := FSteps[i].ScalarA;
          LNew[LNewCount].ArrayPtr := nil;
          Inc(LNewCount); Inc(i, 2); LChanged := True; Continue;
        end;
        // Clamp + Clamp → Clamp (intersect intervals)
        if (FSteps[i].Op = poClamp) and (FSteps[i+1].Op = poClamp) then
        begin
          LNew[LNewCount].Op := poClamp;
          if FSteps[i].ScalarA > FSteps[i+1].ScalarA then
            LNew[LNewCount].ScalarA := FSteps[i].ScalarA
          else
            LNew[LNewCount].ScalarA := FSteps[i+1].ScalarA;
          if FSteps[i].ScalarB < FSteps[i+1].ScalarB then
            LNew[LNewCount].ScalarB := FSteps[i].ScalarB
          else
            LNew[LNewCount].ScalarB := FSteps[i+1].ScalarB;
          LNew[LNewCount].ArrayPtr := nil;
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

procedure TSimdF32Pipeline.Into(aDst: PSingle);
var
  i: Integer;
  LSrc: PSingle;
begin
  if FCount = 0 then Exit;
  if FStepCount = 0 then
  begin
    Move(FSrc^, aDst^, FCount * SizeOf(Single));
    Exit;
  end;

  Optimize;

  if FStepCount = 0 then
  begin
    Move(FSrc^, aDst^, FCount * SizeOf(Single));
    Exit;
  end;

  LSrc := FSrc;
  for i := 0 to FStepCount - 1 do
  begin
    case FSteps[i].Op of
      poMulScalar:  ArrayMulScalarF32(LSrc, aDst, FCount, FSteps[i].ScalarA);
      poAddScalar:  ArrayAddScalarF32(LSrc, aDst, FCount, FSteps[i].ScalarA);
      poLinear:     ArrayLinearF32(LSrc, aDst, FCount, FSteps[i].ScalarA, FSteps[i].ScalarB);
      poReLU:       ArrayReLUF32(LSrc, aDst, FCount);
      poAbs:        ArrayAbsF32(LSrc, aDst, FCount);
      poNeg:        ArrayNegF32(LSrc, aDst, FCount);
      poExp:        ArrayExpF32(LSrc, aDst, FCount);
      poLog:        ArrayLogF32(LSrc, aDst, FCount);
      poSqrt:       ArraySqrtF32(LSrc, aDst, FCount);
      poSin:        ArraySinF32(LSrc, aDst, FCount);
      poCos:        ArrayCosF32(LSrc, aDst, FCount);
      poSigmoid:    SigmoidF32(LSrc, aDst, FCount);
      poClamp:      ArrayClampF32(LSrc, aDst, FCount, FSteps[i].ScalarA, FSteps[i].ScalarB);
      poRcp:        ArrayRcpF32(LSrc, aDst, FCount);
      poSiLU:       SiLUF32(LSrc, aDst, FCount);
      poLeakyReLU:  PipeLeakyReLUF32(LSrc, aDst, FCount, FSteps[i].ScalarA);
      poMin:        PipeMinScalarF32(LSrc, aDst, FCount, FSteps[i].ScalarA);
      poMax:        PipeMaxScalarF32(LSrc, aDst, FCount, FSteps[i].ScalarA);
      poTanh:       PipeTanhF32(LSrc, aDst, FCount);
      poSquare:     ArrayMulF32(LSrc, LSrc, aDst, FCount);
      poPow:        ArrayPowF32(LSrc, aDst, FCount, FSteps[i].ScalarA);
      poAddArray:   ArrayAddF32(LSrc, FSteps[i].ArrayPtr, aDst, FCount);
      poMulArray:   ArrayMulF32(LSrc, FSteps[i].ArrayPtr, aDst, FCount);
      poSubArray:   ArraySubF32(LSrc, FSteps[i].ArrayPtr, aDst, FCount);
      poDivArray:   ArrayDivF32(LSrc, FSteps[i].ArrayPtr, aDst, FCount);
      poFma:        ArrayMulF32(LSrc, FSteps[i].ArrayPtr, aDst, FCount);
      poFmaFused:   ArrayFmaF32(LSrc, FSteps[i].ArrayPtr, FSteps[i].ArrayPtr2, aDst, FCount);
      poLinearReLU: PipeLinearReLUF32(LSrc, aDst, FCount, FSteps[i].ScalarA, FSteps[i].ScalarB);
      poLinearClamp: PipeLinearClampF32(LSrc, aDst, FCount, FSteps[i].ScalarA, FSteps[i].ScalarB, 0, 0);
      poAbsDiff:    PipeAbsDiffF32(LSrc, FSteps[i].ArrayPtr, aDst, FCount);
      poAxpy:       PipeAxpyF32(LSrc, FSteps[i].ArrayPtr, aDst, FCount, FSteps[i].ScalarA);
    end;
    LSrc := aDst;
  end;
end;

procedure TSimdF32Pipeline.IntoArray(var aDst: TSimdF32Array);
begin
  Into(aDst.Data);
end;

function TSimdF32Pipeline.Eval: TSimdF32Array;
begin
  Result := TSimdF32Array.Create(FCount);
  Into(Result.Data);
end;

function TSimdF32Pipeline.Compile: TSimdF32Plan;
var i: Integer;
begin
  Optimize;
  Result.FStepCount := FStepCount;
  for i := 0 to FStepCount - 1 do
    Result.FSteps[i] := FSteps[i];
end;

function TSimdF32Plan.IsValid: Boolean;
begin
  Result := FStepCount > 0;
end;

procedure TSimdF32Plan.Execute(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  i: Integer;
  LSrc: PSingle;
begin
  if (aCount = 0) or (FStepCount = 0) then
  begin
    if aCount > 0 then Move(aSrc^, aDst^, aCount * SizeOf(Single));
    Exit;
  end;
  LSrc := aSrc;
  for i := 0 to FStepCount - 1 do
  begin
    case FSteps[i].Op of
      poMulScalar:  ArrayMulScalarF32(LSrc, aDst, aCount, FSteps[i].ScalarA);
      poAddScalar:  ArrayAddScalarF32(LSrc, aDst, aCount, FSteps[i].ScalarA);
      poLinear:     ArrayLinearF32(LSrc, aDst, aCount, FSteps[i].ScalarA, FSteps[i].ScalarB);
      poReLU:       ArrayReLUF32(LSrc, aDst, aCount);
      poAbs:        ArrayAbsF32(LSrc, aDst, aCount);
      poNeg:        ArrayNegF32(LSrc, aDst, aCount);
      poExp:        ArrayExpF32(LSrc, aDst, aCount);
      poLog:        ArrayLogF32(LSrc, aDst, aCount);
      poSqrt:       ArraySqrtF32(LSrc, aDst, aCount);
      poSin:        ArraySinF32(LSrc, aDst, aCount);
      poCos:        ArrayCosF32(LSrc, aDst, aCount);
      poSigmoid:    SigmoidF32(LSrc, aDst, aCount);
      poClamp:      ArrayClampF32(LSrc, aDst, aCount, FSteps[i].ScalarA, FSteps[i].ScalarB);
      poRcp:        ArrayRcpF32(LSrc, aDst, aCount);
      poSiLU:       SiLUF32(LSrc, aDst, aCount);
      poLeakyReLU:  PipeLeakyReLUF32(LSrc, aDst, aCount, FSteps[i].ScalarA);
      poMin:        PipeMinScalarF32(LSrc, aDst, aCount, FSteps[i].ScalarA);
      poMax:        PipeMaxScalarF32(LSrc, aDst, aCount, FSteps[i].ScalarA);
      poTanh:       PipeTanhF32(LSrc, aDst, aCount);
      poSquare:     ArrayMulF32(LSrc, LSrc, aDst, aCount);
      poPow:        ArrayPowF32(LSrc, aDst, aCount, FSteps[i].ScalarA);
      poAddArray:   ArrayAddF32(LSrc, FSteps[i].ArrayPtr, aDst, aCount);
      poMulArray:   ArrayMulF32(LSrc, FSteps[i].ArrayPtr, aDst, aCount);
      poSubArray:   ArraySubF32(LSrc, FSteps[i].ArrayPtr, aDst, aCount);
      poDivArray:   ArrayDivF32(LSrc, FSteps[i].ArrayPtr, aDst, aCount);
      poFma:        ArrayMulF32(LSrc, FSteps[i].ArrayPtr, aDst, aCount);
      poFmaFused:   ArrayFmaF32(LSrc, FSteps[i].ArrayPtr, FSteps[i].ArrayPtr2, aDst, aCount);
      poLinearReLU: PipeLinearReLUF32(LSrc, aDst, aCount, FSteps[i].ScalarA, FSteps[i].ScalarB);
      poLinearClamp: PipeLinearClampF32(LSrc, aDst, aCount, FSteps[i].ScalarA, FSteps[i].ScalarB, 0, 0);
      poAbsDiff:    PipeAbsDiffF32(LSrc, FSteps[i].ArrayPtr, aDst, aCount);
      poAxpy:       PipeAxpyF32(LSrc, FSteps[i].ArrayPtr, aDst, aCount, FSteps[i].ScalarA);
    end;
    LSrc := aDst;
  end;
end;

function TSimdF32Pipeline.ReduceSum: Single;
var LTmp: TSimdF32Array;
begin
  Optimize;
  if FStepCount = 0 then
    Result := nextpas.core.simd.ReduceSumF32(FSrc, FCount)
  else if (FStepCount = 1) and (FSteps[0].Op = poSquare) then
    Result := nextpas.core.simd.ReduceDotF32(FSrc, FSrc, FCount)
  else if (FStepCount = 1) and (FSteps[0].Op = poMulArray) then
    Result := nextpas.core.simd.ReduceDotF32(FSrc, FSteps[0].ArrayPtr, FCount)
  else if (FStepCount = 1) and (FSteps[0].Op = poMulScalar) then
    Result := FSteps[0].ScalarA * nextpas.core.simd.ReduceSumF32(FSrc, FCount)
  else
  begin
    LTmp := TSimdF32Array.Create(FCount);
    Into(LTmp.Data);
    Result := nextpas.core.simd.ReduceSumF32(LTmp.Data, FCount);
    LTmp.Free;
  end;
end;

function TSimdF32Pipeline.ReduceMax: Single;
var LTmp: TSimdF32Array;
begin
  Optimize;
  if FStepCount = 0 then
    Result := nextpas.core.simd.ReduceMaxF32(FSrc, FCount)
  else
  begin
    LTmp := TSimdF32Array.Create(FCount);
    Into(LTmp.Data);
    Result := nextpas.core.simd.ReduceMaxF32(LTmp.Data, FCount);
    LTmp.Free;
  end;
end;

function TSimdF32Pipeline.ReduceMin: Single;
var LTmp: TSimdF32Array;
begin
  Optimize;
  if FStepCount = 0 then
    Result := nextpas.core.simd.ReduceMinF32(FSrc, FCount)
  else
  begin
    LTmp := TSimdF32Array.Create(FCount);
    Into(LTmp.Data);
    Result := nextpas.core.simd.ReduceMinF32(LTmp.Data, FCount);
    LTmp.Free;
  end;
end;

function TSimdF32Pipeline.ReduceDot(aOther: PSingle): Single;
var LTmp: TSimdF32Array;
begin
  Optimize;
  if FStepCount = 0 then
    Result := nextpas.core.simd.ReduceDotF32(FSrc, aOther, FCount)
  else
  begin
    LTmp := TSimdF32Array.Create(FCount);
    Into(LTmp.Data);
    Result := nextpas.core.simd.ReduceDotF32(LTmp.Data, aOther, FCount);
    LTmp.Free;
  end;
end;

function TSimdF32Pipeline.ReduceDotArr(const aOther: TSimdF32Array): Single;
begin
  Result := ReduceDot(aOther.Data);
end;

function TSimdF32Pipeline.ReduceMean: Single;
begin
  if FCount = 0 then Exit(0);
  Result := ReduceSum / FCount;
end;

function TSimdF32Pipeline.ReduceNorm: Single;
var LTmp: TSimdF32Array;
begin
  Optimize;
  if FStepCount = 0 then
    Result := System.Sqrt(nextpas.core.simd.ReduceDotF32(FSrc, FSrc, FCount))
  else
  begin
    LTmp := TSimdF32Array.Create(FCount);
    Into(LTmp.Data);
    Result := System.Sqrt(nextpas.core.simd.ReduceDotF32(LTmp.Data, LTmp.Data, FCount));
    LTmp.Free;
  end;
end;

end.
