unit nextpas.core.simd.arrays.typed;


{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.mathutil, nextpas.core.simd.alloc;

type
  TSimdF32Array = record
  private
    FData: PSingle;
    FCount: SizeUInt;
    FOwned: Boolean;
    FStride: NativeInt;
  public
    class function Zeros(aCount: SizeUInt): TSimdF32Array; static;
    class function Ones(aCount: SizeUInt): TSimdF32Array; static;
    class function Create(aCount: SizeUInt): TSimdF32Array; static;
    class function Ramp(aCount: SizeUInt; aStart: Single = 0; aStep: Single = 1): TSimdF32Array; static;
    class function Linspace(aCount: SizeUInt; aStart, aEnd: Single): TSimdF32Array; static;
    class function Wrap(aData: PSingle; aCount: SizeUInt): TSimdF32Array; static;
    class function WrapStrided(aData: PSingle; aCount: SizeUInt; aStride: NativeInt): TSimdF32Array; static;
    class function FromData(aData: PSingle; aCount: SizeUInt): TSimdF32Array; static;
    procedure Free;

    function Slice(aStart, aCount: SizeUInt): TSimdF32Array;
    function Strided(aStride: NativeInt): TSimdF32Array;
    function IsContiguous: Boolean; inline;

    function Sum: Single;
    function Min: Single;
    function Max: Single;
    function ArgMin: SizeUInt;
    function ArgMax: SizeUInt;
    function Dot(const aOther: TSimdF32Array): Single;
    function Mean: Single;
    function Norm: Single;
    function Variance: Single;
    function StdDev: Single;
    function Median: Single;
    function Normalized: TSimdF32Array;
    function Abs: TSimdF32Array;
    function Negated: TSimdF32Array;
    function Reversed: TSimdF32Array;
    function Sorted: TSimdF32Array;
    function Clamped(aMin, aMax: Single): TSimdF32Array;
    function Diff: TSimdF32Array;
    function CumSum: TSimdF32Array;
    function Concat(const aOther: TSimdF32Array): TSimdF32Array;

    procedure AddInto(const aOther: TSimdF32Array; var aDst: TSimdF32Array);
    procedure SubInto(const aOther: TSimdF32Array; var aDst: TSimdF32Array);
    procedure MulInto(const aOther: TSimdF32Array; var aDst: TSimdF32Array);
    procedure MulScalarInto(aScalar: Single; var aDst: TSimdF32Array);
    procedure LinearInto(aScale, aBias: Single; var aDst: TSimdF32Array);
    procedure ReLUInto(var aDst: TSimdF32Array);
    procedure ExpInto(var aDst: TSimdF32Array);
    procedure Fill(aValue: Single);
    procedure CopyFrom(const aOther: TSimdF32Array);
    function Clone: TSimdF32Array;
    function HasNaN: Boolean;
    function HasInf: Boolean;
    procedure Scale(aFactor: Single);
    procedure AddScalarInPlace(aValue: Single);

    property Data: PSingle read FData;
    property Count: SizeUInt read FCount;
    property Stride: NativeInt read FStride;
  end;

operator + (const a, b: TSimdF32Array): TSimdF32Array;
operator - (const a, b: TSimdF32Array): TSimdF32Array;
operator * (const a: TSimdF32Array; s: Single): TSimdF32Array;
operator * (s: Single; const a: TSimdF32Array): TSimdF32Array;
operator * (const a, b: TSimdF32Array): TSimdF32Array;
operator / (const a: TSimdF32Array; s: Single): TSimdF32Array;

type
  TSimdF64Array = record
  private
    FData: PDouble;
    FCount: SizeUInt;
    FOwned: Boolean;
    FStride: NativeInt;
  public
    class function Zeros(aCount: SizeUInt): TSimdF64Array; static;
    class function Create(aCount: SizeUInt): TSimdF64Array; static;
    class function Ones(aCount: SizeUInt): TSimdF64Array; static;
    class function Ramp(aCount: SizeUInt; aStart: Double = 0; aStep: Double = 1): TSimdF64Array; static;
    class function Linspace(aCount: SizeUInt; aStart, aEnd: Double): TSimdF64Array; static;
    class function Wrap(aData: PDouble; aCount: SizeUInt): TSimdF64Array; static;
    class function WrapStrided(aData: PDouble; aCount: SizeUInt; aStride: NativeInt): TSimdF64Array; static;
    procedure Free;
    function Slice(aStart, aCount: SizeUInt): TSimdF64Array;
    function IsContiguous: Boolean; inline;
    function Sum: Double;
    function Min: Double;
    function Max: Double;
    function Dot(const aOther: TSimdF64Array): Double;
    function Mean: Double;
    function Norm: Double;
    function Variance: Double;
    function StdDev: Double;
    function Clone: TSimdF64Array;
    function Abs: TSimdF64Array;
    function Negated: TSimdF64Array;
    function Clamped(aMin, aMax: Double): TSimdF64Array;
    function Normalized: TSimdF64Array;
    procedure Fill(aValue: Double);
    procedure Scale(aFactor: Double);
    procedure AddInto(const aOther: TSimdF64Array; var aDst: TSimdF64Array);
    procedure SubInto(const aOther: TSimdF64Array; var aDst: TSimdF64Array);
    procedure MulInto(const aOther: TSimdF64Array; var aDst: TSimdF64Array);
    property Data: PDouble read FData;
    property Count: SizeUInt read FCount;
    property Stride: NativeInt read FStride;
  end;

operator + (const a, b: TSimdF64Array): TSimdF64Array;
operator - (const a, b: TSimdF64Array): TSimdF64Array;
operator * (const a: TSimdF64Array; s: Double): TSimdF64Array;
operator * (s: Double; const a: TSimdF64Array): TSimdF64Array;
operator / (const a: TSimdF64Array; s: Double): TSimdF64Array;

type
  TSimdI32Array = record
  private
    FData: PInt32;
    FCount: SizeUInt;
    FOwned: Boolean;
    FStride: NativeInt;
  public
    class function Zeros(aCount: SizeUInt): TSimdI32Array; static;
    class function Create(aCount: SizeUInt): TSimdI32Array; static;
    class function Wrap(aData: PInt32; aCount: SizeUInt): TSimdI32Array; static;
    procedure Free;
    function Slice(aStart, aCount: SizeUInt): TSimdI32Array;
    function IsContiguous: Boolean; inline;
    function Sum: Int64;
    procedure AddInto(const aOther: TSimdI32Array; var aDst: TSimdI32Array);
    procedure SubInto(const aOther: TSimdI32Array; var aDst: TSimdI32Array);
    procedure AndInto(const aOther: TSimdI32Array; var aDst: TSimdI32Array);
    procedure OrInto(const aOther: TSimdI32Array; var aDst: TSimdI32Array);
    procedure XorInto(const aOther: TSimdI32Array; var aDst: TSimdI32Array);
    procedure ShlInto(aShift: Integer; var aDst: TSimdI32Array);
    procedure ShrInto(aShift: Integer; var aDst: TSimdI32Array);
    property Data: PInt32 read FData;
    property Count: SizeUInt read FCount;
    property Stride: NativeInt read FStride;
  end;

operator + (const a, b: TSimdI32Array): TSimdI32Array;
operator - (const a, b: TSimdI32Array): TSimdI32Array;

implementation

uses
  nextpas.core.simd;

class function TSimdF32Array.Create(aCount: SizeUInt): TSimdF32Array;
begin
  Result.FCount := aCount;
  Result.FStride := 1;
  Result.FOwned := True;
  Result.FData := PSingle(SimdAlloc(aCount * SizeOf(Single)));
end;

class function TSimdF32Array.Zeros(aCount: SizeUInt): TSimdF32Array;
begin
  Result := TSimdF32Array.Create(aCount);
  FillChar(Result.FData^, aCount * SizeOf(Single), 0);
end;

class function TSimdF32Array.Ones(aCount: SizeUInt): TSimdF32Array;
var i: SizeUInt;
begin
  Result := TSimdF32Array.Create(aCount);
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    Result.FData[i] := 1.0;
end;

class function TSimdF32Array.Ramp(aCount: SizeUInt; aStart: Single; aStep: Single): TSimdF32Array;
var i: SizeUInt;
begin
  Result := TSimdF32Array.Create(aCount);
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    Result.FData[i] := aStart + i * aStep;
end;

class function TSimdF32Array.Linspace(aCount: SizeUInt; aStart, aEnd: Single): TSimdF32Array;
var LStep: Single;
begin
  if aCount <= 1 then
  begin
    Result := TSimdF32Array.Create(aCount);
    if aCount = 1 then Result.FData[0] := aStart;
    Exit;
  end;
  LStep := (aEnd - aStart) / (aCount - 1);
  Result := Ramp(aCount, aStart, LStep);
  Result.FData[aCount - 1] := aEnd;
end;

class function TSimdF32Array.Wrap(aData: PSingle; aCount: SizeUInt): TSimdF32Array;
begin
  Result.FData := aData;
  Result.FCount := aCount;
  Result.FStride := 1;
  Result.FOwned := False;
end;

class function TSimdF32Array.WrapStrided(aData: PSingle; aCount: SizeUInt; aStride: NativeInt): TSimdF32Array;
begin
  Result.FData := aData;
  Result.FCount := aCount;
  Result.FStride := aStride;
  Result.FOwned := False;
end;

class function TSimdF32Array.FromData(aData: PSingle; aCount: SizeUInt): TSimdF32Array;
begin
  Result := TSimdF32Array.Create(aCount);
  if aCount > 0 then
    Move(aData^, Result.FData^, aCount * SizeOf(Single));
end;

procedure TSimdF32Array.Free;
begin
  if FOwned and (FData <> nil) then
    SimdFree(FData);
  FData := nil;
  FCount := 0;
end;

function TSimdF32Array.Slice(aStart, aCount: SizeUInt): TSimdF32Array;
begin
  Result.FData := @FData[aStart * FStride];
  Result.FCount := aCount;
  Result.FStride := FStride;
  Result.FOwned := False;
end;

function TSimdF32Array.Strided(aStride: NativeInt): TSimdF32Array;
begin
  Result.FData := FData;
  Result.FCount := FCount div SizeUInt(aStride);
  Result.FStride := FStride * aStride;
  Result.FOwned := False;
end;

function TSimdF32Array.IsContiguous: Boolean;
begin
  Result := FStride = 1;
end;

function TSimdF32Array.Sum: Single;
var i: SizeUInt;
begin
  if FCount = 0 then begin Result := 0; Exit; end;
  if IsContiguous then
    Result := ReduceSumF32(FData, FCount)
  else
  begin
    Result := 0;
    for i := 0 to FCount - 1 do
      Result := Result + FData[i * FStride];
  end;
end;

function TSimdF32Array.Min: Single;
var i: SizeUInt;
begin
  if FCount = 0 then begin Result := 0; Exit; end;
  if IsContiguous then
    Result := ReduceMinF32(FData, FCount)
  else
  begin
    Result := FData[0];
    for i := 1 to FCount - 1 do
      if FData[i * FStride] < Result then
        Result := FData[i * FStride];
  end;
end;

function TSimdF32Array.Max: Single;
var i: SizeUInt;
begin
  if FCount = 0 then begin Result := 0; Exit; end;
  if IsContiguous then
    Result := ReduceMaxF32(FData, FCount)
  else
  begin
    Result := FData[0];
    for i := 1 to FCount - 1 do
      if FData[i * FStride] > Result then
        Result := FData[i * FStride];
  end;
end;

function TSimdF32Array.ArgMin: SizeUInt;
var i: SizeUInt; LMin: Single;
begin
  Result := 0;
  if FCount = 0 then Exit;
  LMin := FData[0];
  for i := 1 to FCount - 1 do
    if FData[i * FStride] < LMin then
    begin
      LMin := FData[i * FStride];
      Result := i;
    end;
end;

function TSimdF32Array.ArgMax: SizeUInt;
var i: SizeUInt; LMax: Single;
begin
  Result := 0;
  if FCount = 0 then Exit;
  LMax := FData[0];
  for i := 1 to FCount - 1 do
    if FData[i * FStride] > LMax then
    begin
      LMax := FData[i * FStride];
      Result := i;
    end;
end;

function TSimdF32Array.Dot(const aOther: TSimdF32Array): Single;
var i: SizeUInt;
begin
  if FCount = 0 then begin Result := 0; Exit; end;
  if IsContiguous and aOther.IsContiguous then
    Result := ReduceDotF32(FData, aOther.FData, FCount)
  else
  begin
    Result := 0;
    for i := 0 to FCount - 1 do
      Result := Result + FData[i * FStride] * aOther.FData[i * aOther.FStride];
  end;
end;

function TSimdF32Array.Mean: Single;
begin
  if FCount = 0 then Exit(0);
  Result := Sum / FCount;
end;

function TSimdF32Array.Norm: Single;
begin
  Result := System.Sqrt(Dot(Self));
end;

function TSimdF32Array.Variance: Single;
var LMean, LDot: Single;
begin
  if FCount <= 1 then Exit(0);
  LMean := Mean;
  LDot := Dot(Self);
  Result := LDot / FCount - LMean * LMean;
  if Result < 0 then Result := 0;
end;

function TSimdF32Array.StdDev: Single;
begin
  Result := System.Sqrt(Variance);
end;

function TSimdF32Array.Median: Single;
var LSorted: TSimdF32Array;
begin
  if FCount = 0 then Exit(0);
  LSorted := Sorted;
  if FCount mod 2 = 1 then
    Result := LSorted.FData[FCount div 2]
  else
    Result := (LSorted.FData[FCount div 2 - 1] + LSorted.FData[FCount div 2]) * 0.5;
  LSorted.Free;
end;

function TSimdF32Array.Normalized: TSimdF32Array;
var LNorm: Single;
begin
  Result := TSimdF32Array.Create(FCount);
  LNorm := Norm;
  if LNorm > 0 then
    MulScalarInto(1.0 / LNorm, Result)
  else
    Result.Fill(0);
end;

function TSimdF32Array.Abs: TSimdF32Array;
var i: SizeUInt;
begin
  Result := TSimdF32Array.Create(FCount);
  if FCount = 0 then Exit;
  if IsContiguous then
    ArrayAbsF32(FData, Result.FData, FCount)
  else
    for i := 0 to FCount - 1 do
      Result.FData[i] := System.Abs(FData[i * FStride]);
end;

function TSimdF32Array.Negated: TSimdF32Array;
begin
  Result := TSimdF32Array.Create(FCount);
  if FCount = 0 then Exit;
  if IsContiguous then
    ArrayNegF32(FData, Result.FData, FCount)
  else
    MulScalarInto(-1.0, Result);
end;

function TSimdF32Array.Reversed: TSimdF32Array;
var i: SizeUInt;
begin
  Result := TSimdF32Array.Create(FCount);
  if FCount = 0 then Exit;
  for i := 0 to FCount - 1 do
    Result.FData[i] := FData[(FCount - 1 - i) * FStride];
end;

function TSimdF32Array.Sorted: TSimdF32Array;

  procedure InsertionSort(arr: PSingle; lo, hi: Integer);
  var i, j: Integer; key: Single;
  begin
    for i := lo + 1 to hi do
    begin
      key := arr[i];
      j := i - 1;
      while (j >= lo) and (arr[j] > key) do
      begin
        arr[j + 1] := arr[j];
        Dec(j);
      end;
      arr[j + 1] := key;
    end;
  end;

  procedure QSort(arr: PSingle; lo, hi: Integer);
  var i, j: Integer; pivot, tmp: Single;
  begin
    if hi - lo < 16 then begin InsertionSort(arr, lo, hi); Exit; end;
    pivot := arr[(lo + hi) div 2];
    i := lo; j := hi;
    while i <= j do
    begin
      while arr[i] < pivot do Inc(i);
      while arr[j] > pivot do Dec(j);
      if i <= j then
      begin
        tmp := arr[i]; arr[i] := arr[j]; arr[j] := tmp;
        Inc(i); Dec(j);
      end;
    end;
    if lo < j then QSort(arr, lo, j);
    if i < hi then QSort(arr, i, hi);
  end;

var i: SizeUInt;
begin
  Result := TSimdF32Array.Create(FCount);
  if FCount = 0 then Exit;
  if IsContiguous then
    Move(FData^, Result.FData^, FCount * SizeOf(Single))
  else
    for i := 0 to FCount - 1 do
      Result.FData[i] := FData[i * FStride];
  QSort(Result.FData, 0, Integer(FCount) - 1);
end;

function TSimdF32Array.Clamped(aMin, aMax: Single): TSimdF32Array;
var i: SizeUInt;
begin
  Result := TSimdF32Array.Create(FCount);
  if FCount = 0 then Exit;
  if IsContiguous then
    ArrayClampF32(FData, Result.FData, FCount, aMin, aMax)
  else
  begin
    for i := 0 to FCount - 1 do
      Result.FData[i] := FData[i * FStride];
    ArrayClampF32(Result.FData, Result.FData, FCount, aMin, aMax);
  end;
end;

function TSimdF32Array.Diff: TSimdF32Array;
var i: SizeUInt;
begin
  if FCount <= 1 then begin Result := TSimdF32Array.Create(0); Exit; end;
  Result := TSimdF32Array.Create(FCount - 1);
  if IsContiguous then
    ArraySubF32(@FData[1], @FData[0], Result.FData, FCount - 1)
  else
    for i := 0 to FCount - 2 do
      Result.FData[i] := FData[(i + 1) * FStride] - FData[i * FStride];
end;

function TSimdF32Array.CumSum: TSimdF32Array;
var i: SizeUInt;
begin
  Result := TSimdF32Array.Create(FCount);
  if FCount = 0 then Exit;
  Result.FData[0] := FData[0];
  for i := 1 to FCount - 1 do
    Result.FData[i] := Result.FData[i - 1] + FData[i * FStride];
end;

function TSimdF32Array.Concat(const aOther: TSimdF32Array): TSimdF32Array;
var i: SizeUInt;
begin
  Result := TSimdF32Array.Create(FCount + aOther.Count);
  if FCount > 0 then
  begin
    if IsContiguous then
      Move(FData^, Result.FData^, FCount * SizeOf(Single))
    else
      for i := 0 to FCount - 1 do
        Result.FData[i] := FData[i * FStride];
  end;
  if aOther.Count > 0 then
  begin
    if aOther.IsContiguous then
      Move(aOther.Data^, Result.FData[FCount], aOther.Count * SizeOf(Single))
    else
      for i := 0 to aOther.Count - 1 do
        Result.FData[FCount + i] := aOther.Data[i * aOther.Stride];
  end;
end;

procedure TSimdF32Array.Fill(aValue: Single);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous then
  begin
    for i := 0 to FCount - 1 do FData[i] := aValue;
  end
  else
    for i := 0 to FCount - 1 do FData[i * FStride] := aValue;
end;

procedure TSimdF32Array.CopyFrom(const aOther: TSimdF32Array);
begin
  if IsContiguous and aOther.IsContiguous and (FCount = aOther.FCount) then
    Move(aOther.FData^, FData^, FCount * SizeOf(Single));
end;

function TSimdF32Array.Clone: TSimdF32Array;
var i: SizeUInt;
begin
  Result := TSimdF32Array.Create(FCount);
  if FCount = 0 then Exit;
  if IsContiguous then
    Move(FData^, Result.FData^, FCount * SizeOf(Single))
  else
    for i := 0 to FCount - 1 do
      Result.FData[i] := FData[i * FStride];
end;

function TSimdF32Array.HasNaN: Boolean;
var i: SizeUInt;
begin
  Result := False;
  if FCount = 0 then Exit;
  for i := 0 to FCount - 1 do
    if FData[i * FStride] <> FData[i * FStride] then Exit(True);
end;

function TSimdF32Array.HasInf: Boolean;
var i: SizeUInt; v: Single;
begin
  Result := False;
  if FCount = 0 then Exit;
  for i := 0 to FCount - 1 do
  begin
    v := FData[i * FStride];
    if (v = SimdInfinity) or (v = SimdNegInfinity) then Exit(True);
  end;
end;

procedure TSimdF32Array.Scale(aFactor: Single);
begin
  if (FCount = 0) or not IsContiguous then Exit;
  ArrayMulScalarF32(FData, FData, FCount, aFactor);
end;

procedure TSimdF32Array.AddScalarInPlace(aValue: Single);
begin
  if (FCount = 0) or not IsContiguous then Exit;
  ArrayAddScalarF32(FData, FData, FCount, aValue);
end;

procedure TSimdF32Array.AddInto(const aOther: TSimdF32Array; var aDst: TSimdF32Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aOther.IsContiguous and aDst.IsContiguous then
    ArrayAddF32(FData, aOther.FData, aDst.FData, FCount)
  else
  begin
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] + aOther.FData[i * aOther.FStride];
  end;
end;

procedure TSimdF32Array.SubInto(const aOther: TSimdF32Array; var aDst: TSimdF32Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aOther.IsContiguous and aDst.IsContiguous then
    ArraySubF32(FData, aOther.FData, aDst.FData, FCount)
  else
  begin
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] - aOther.FData[i * aOther.FStride];
  end;
end;

procedure TSimdF32Array.MulInto(const aOther: TSimdF32Array; var aDst: TSimdF32Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aOther.IsContiguous and aDst.IsContiguous then
    ArrayMulF32(FData, aOther.FData, aDst.FData, FCount)
  else
  begin
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] * aOther.FData[i * aOther.FStride];
  end;
end;

procedure TSimdF32Array.MulScalarInto(aScalar: Single; var aDst: TSimdF32Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aDst.IsContiguous then
    ArrayMulScalarF32(FData, aDst.FData, FCount, aScalar)
  else
  begin
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] * aScalar;
  end;
end;

procedure TSimdF32Array.LinearInto(aScale, aBias: Single; var aDst: TSimdF32Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aDst.IsContiguous then
    ArrayLinearF32(FData, aDst.FData, FCount, aScale, aBias)
  else
  begin
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] * aScale + aBias;
  end;
end;

procedure TSimdF32Array.ReLUInto(var aDst: TSimdF32Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aDst.IsContiguous then
    ArrayReLUF32(FData, aDst.FData, FCount)
  else
  begin
    for i := 0 to FCount - 1 do
      if FData[i * FStride] > 0 then
        aDst.FData[i * aDst.FStride] := FData[i * FStride]
      else
        aDst.FData[i * aDst.FStride] := 0;
  end;
end;

procedure TSimdF32Array.ExpInto(var aDst: TSimdF32Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aDst.IsContiguous then
    ArrayExpF32(FData, aDst.FData, FCount)
  else
  begin

    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := Single(System.Exp(FData[i * FStride]));
  end;
end;

operator + (const a, b: TSimdF32Array): TSimdF32Array;
begin
  Result := TSimdF32Array.Create(a.Count);
  a.AddInto(b, Result);
end;

operator - (const a, b: TSimdF32Array): TSimdF32Array;
var i: SizeUInt;
begin
  Result := TSimdF32Array.Create(a.Count);
  if a.Count = 0 then Exit;
  if a.IsContiguous and b.IsContiguous and Result.IsContiguous then
    ArraySubF32(a.Data, b.Data, Result.FData, a.Count)
  else
  begin

    for i := 0 to a.Count - 1 do
      Result.FData[i] := a.Data[i * a.Stride] - b.Data[i * b.Stride];
  end;
end;

operator * (const a: TSimdF32Array; s: Single): TSimdF32Array;
begin
  Result := TSimdF32Array.Create(a.Count);
  a.MulScalarInto(s, Result);
end;

operator * (s: Single; const a: TSimdF32Array): TSimdF32Array;
begin
  Result := TSimdF32Array.Create(a.Count);
  a.MulScalarInto(s, Result);
end;

operator * (const a, b: TSimdF32Array): TSimdF32Array;
var i: SizeUInt;
begin
  Result := TSimdF32Array.Create(a.Count);
  if a.Count = 0 then Exit;
  if a.IsContiguous and b.IsContiguous then
    ArrayMulF32(a.Data, b.Data, Result.Data, a.Count)
  else
    for i := 0 to a.Count - 1 do
      Result.FData[i] := a.Data[i * a.Stride] * b.Data[i * b.Stride];
end;

operator / (const a: TSimdF32Array; s: Single): TSimdF32Array;
begin
  Result := TSimdF32Array.Create(a.Count);
  a.MulScalarInto(1.0 / s, Result);
end;

// === TSimdF64Array Implementation ===

class function TSimdF64Array.Create(aCount: SizeUInt): TSimdF64Array;
begin
  Result.FCount := aCount;
  Result.FStride := 1;
  Result.FOwned := True;
  Result.FData := PDouble(SimdAlloc(aCount * SizeOf(Double)));
end;

class function TSimdF64Array.Zeros(aCount: SizeUInt): TSimdF64Array;
begin
  Result := TSimdF64Array.Create(aCount);
  FillChar(Result.FData^, aCount * SizeOf(Double), 0);
end;

class function TSimdF64Array.Wrap(aData: PDouble; aCount: SizeUInt): TSimdF64Array;
begin
  Result.FData := aData; Result.FCount := aCount; Result.FStride := 1; Result.FOwned := False;
end;

class function TSimdF64Array.WrapStrided(aData: PDouble; aCount: SizeUInt; aStride: NativeInt): TSimdF64Array;
begin
  Result.FData := aData; Result.FCount := aCount; Result.FStride := aStride; Result.FOwned := False;
end;

procedure TSimdF64Array.Free;
begin
  if FOwned and (FData <> nil) then SimdFree(FData);
  FData := nil; FCount := 0;
end;

function TSimdF64Array.Slice(aStart, aCount: SizeUInt): TSimdF64Array;
begin
  Result.FData := @FData[aStart * FStride]; Result.FCount := aCount; Result.FStride := FStride; Result.FOwned := False;
end;

function TSimdF64Array.IsContiguous: Boolean;
begin Result := FStride = 1; end;

function TSimdF64Array.Sum: Double;
var i: SizeUInt;
begin
  if FCount = 0 then begin Result := 0; Exit; end;
  if IsContiguous then
    Result := ReduceSumF64(FData, FCount)
  else begin
    Result := 0;
    for i := 0 to FCount - 1 do Result := Result + FData[i * FStride];
  end;
end;

function TSimdF64Array.Min: Double;
var i: SizeUInt;
begin
  if FCount = 0 then begin Result := 0; Exit; end;
  if IsContiguous then
    Result := ReduceMinF64(FData, FCount)
  else begin
    Result := FData[0];
    for i := 1 to FCount - 1 do
      if FData[i * FStride] < Result then Result := FData[i * FStride];
  end;
end;

function TSimdF64Array.Max: Double;
var i: SizeUInt;
begin
  if FCount = 0 then begin Result := 0; Exit; end;
  if IsContiguous then
    Result := ReduceMaxF64(FData, FCount)
  else begin
    Result := FData[0];
    for i := 1 to FCount - 1 do
      if FData[i * FStride] > Result then Result := FData[i * FStride];
  end;
end;

function TSimdF64Array.Dot(const aOther: TSimdF64Array): Double;
var i: SizeUInt;
begin
  if FCount = 0 then begin Result := 0; Exit; end;
  if IsContiguous and aOther.IsContiguous then
    Result := ReduceDotF64(FData, aOther.FData, FCount)
  else begin
    Result := 0;
    for i := 0 to FCount - 1 do
      Result := Result + FData[i * FStride] * aOther.FData[i * aOther.FStride];
  end;
end;

function TSimdF64Array.Mean: Double;
begin
  if FCount = 0 then Exit(0);
  Result := Sum / FCount;
end;

// === TSimdI32Array Implementation ===

class function TSimdI32Array.Create(aCount: SizeUInt): TSimdI32Array;
begin
  Result.FCount := aCount; Result.FStride := 1; Result.FOwned := True;
  Result.FData := PInt32(SimdAlloc(aCount * SizeOf(Int32)));
end;

class function TSimdI32Array.Zeros(aCount: SizeUInt): TSimdI32Array;
begin
  Result := TSimdI32Array.Create(aCount);
  FillChar(Result.FData^, aCount * SizeOf(Int32), 0);
end;

class function TSimdI32Array.Wrap(aData: PInt32; aCount: SizeUInt): TSimdI32Array;
begin
  Result.FData := aData; Result.FCount := aCount; Result.FStride := 1; Result.FOwned := False;
end;

procedure TSimdI32Array.Free;
begin
  if FOwned and (FData <> nil) then SimdFree(FData);
  FData := nil; FCount := 0;
end;

function TSimdI32Array.Slice(aStart, aCount: SizeUInt): TSimdI32Array;
begin
  Result.FData := @FData[aStart * FStride]; Result.FCount := aCount; Result.FStride := FStride; Result.FOwned := False;
end;

function TSimdI32Array.IsContiguous: Boolean;
begin Result := FStride = 1; end;

function TSimdI32Array.Sum: Int64;
var i: SizeUInt;
begin
  Result := 0;
  if FCount = 0 then Exit;
  for i := 0 to FCount - 1 do
    Result := Result + FData[i * FStride];
end;

operator + (const a, b: TSimdI32Array): TSimdI32Array;
var i: SizeUInt;
begin
  Result := TSimdI32Array.Create(a.Count);
  if a.Count = 0 then Exit;
  if a.IsContiguous and b.IsContiguous then
    ArrayAddI32(a.Data, b.Data, Result.FData, a.Count)
  else
    for i := 0 to a.Count - 1 do
      Result.FData[i] := a.Data[i * a.Stride] + b.Data[i * b.Stride];
end;

operator - (const a, b: TSimdI32Array): TSimdI32Array;
var i: SizeUInt;
begin
  Result := TSimdI32Array.Create(a.Count);
  if a.Count = 0 then Exit;
  if a.IsContiguous and b.IsContiguous then
    ArraySubI32(a.Data, b.Data, Result.FData, a.Count)
  else
    for i := 0 to a.Count - 1 do
      Result.FData[i] := a.Data[i * a.Stride] - b.Data[i * b.Stride];
end;

procedure TSimdF64Array.AddInto(const aOther: TSimdF64Array; var aDst: TSimdF64Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aOther.IsContiguous and aDst.IsContiguous then
    ArrayAddF64(FData, aOther.FData, aDst.FData, FCount)
  else
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] + aOther.FData[i * aOther.FStride];
end;

procedure TSimdF64Array.SubInto(const aOther: TSimdF64Array; var aDst: TSimdF64Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aOther.IsContiguous and aDst.IsContiguous then
    ArraySubF64(FData, aOther.FData, aDst.FData, FCount)
  else
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] - aOther.FData[i * aOther.FStride];
end;

procedure TSimdF64Array.MulInto(const aOther: TSimdF64Array; var aDst: TSimdF64Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aOther.IsContiguous and aDst.IsContiguous then
    ArrayMulF64(FData, aOther.FData, aDst.FData, FCount)
  else
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] * aOther.FData[i * aOther.FStride];
end;

class function TSimdF64Array.Ones(aCount: SizeUInt): TSimdF64Array;
var i: SizeUInt;
begin
  Result := TSimdF64Array.Create(aCount);
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do Result.FData[i] := 1.0;
end;

class function TSimdF64Array.Ramp(aCount: SizeUInt; aStart: Double; aStep: Double): TSimdF64Array;
var i: SizeUInt;
begin
  Result := TSimdF64Array.Create(aCount);
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do Result.FData[i] := aStart + i * aStep;
end;

class function TSimdF64Array.Linspace(aCount: SizeUInt; aStart, aEnd: Double): TSimdF64Array;
var i: SizeUInt; LStep: Double;
begin
  Result := TSimdF64Array.Create(aCount);
  if aCount <= 1 then begin if aCount = 1 then Result.FData[0] := aStart; Exit; end;
  LStep := (aEnd - aStart) / (aCount - 1);
  for i := 0 to aCount - 1 do Result.FData[i] := aStart + i * LStep;
end;

function TSimdF64Array.Norm: Double;
begin
  if FCount = 0 then begin Result := 0; Exit; end;
  if IsContiguous then
    Result := System.Sqrt(ReduceDotF64(FData, FData, FCount))
  else
    Result := System.Sqrt(Dot(Self));
end;

function TSimdF64Array.Variance: Double;
var LMean, LVar: Double;
begin
  if FCount = 0 then begin Result := 0; Exit; end;
  LMean := Mean;
  if IsContiguous then
    LVar := ReduceDotF64(FData, FData, FCount) / FCount - LMean * LMean
  else
    LVar := Dot(Self) / FCount - LMean * LMean;
  if LVar < 0 then LVar := 0;
  Result := LVar;
end;

function TSimdF64Array.StdDev: Double;
begin
  Result := System.Sqrt(Variance);
end;

function TSimdF64Array.Clone: TSimdF64Array;
var i: SizeUInt;
begin
  Result := TSimdF64Array.Create(FCount);
  if FCount = 0 then Exit;
  if IsContiguous then
    Move(FData^, Result.FData^, FCount * SizeOf(Double))
  else
    for i := 0 to FCount - 1 do
      Result.FData[i] := FData[i * FStride];
end;

function TSimdF64Array.Abs: TSimdF64Array;
var i: SizeUInt;
begin
  Result := TSimdF64Array.Create(FCount);
  if FCount = 0 then Exit;
  if IsContiguous then
    ArrayAbsF64(FData, Result.FData, FCount)
  else
    for i := 0 to FCount - 1 do
      Result.FData[i] := System.Abs(FData[i * FStride]);
end;

function TSimdF64Array.Negated: TSimdF64Array;
var i: SizeUInt;
begin
  Result := TSimdF64Array.Create(FCount);
  if FCount = 0 then Exit;
  if IsContiguous then
    ArrayNegF64(FData, Result.FData, FCount)
  else
    for i := 0 to FCount - 1 do
      Result.FData[i] := -FData[i * FStride];
end;

function TSimdF64Array.Clamped(aMin, aMax: Double): TSimdF64Array;
var i: SizeUInt; v: Double;
begin
  Result := TSimdF64Array.Create(FCount);
  if FCount = 0 then Exit;
  if IsContiguous then
    ArrayClampF64(FData, Result.FData, FCount, aMin, aMax)
  else
    for i := 0 to FCount - 1 do
    begin
      v := FData[i * FStride];
      if v < aMin then v := aMin else if v > aMax then v := aMax;
      Result.FData[i] := v;
    end;
end;

function TSimdF64Array.Normalized: TSimdF64Array;
var LNorm: Double;
begin
  Result := TSimdF64Array.Create(FCount);
  if FCount = 0 then Exit;
  LNorm := Norm;
  if LNorm = 0 then begin FillChar(Result.FData^, FCount * SizeOf(Double), 0); Exit; end;
  if IsContiguous then
    ArrayMulScalarF64(FData, Result.FData, FCount, 1.0 / LNorm)
  else begin
    Result := Clone;
    ArrayMulScalarF64(Result.FData, Result.FData, FCount, 1.0 / LNorm);
  end;
end;

procedure TSimdF64Array.Fill(aValue: Double);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  for i := 0 to FCount - 1 do FData[i * FStride] := aValue;
end;

procedure TSimdF64Array.Scale(aFactor: Double);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous then
    ArrayMulScalarF64(FData, FData, FCount, aFactor)
  else
    for i := 0 to FCount - 1 do FData[i * FStride] := FData[i * FStride] * aFactor;
end;

operator + (const a, b: TSimdF64Array): TSimdF64Array;
begin
  Result := TSimdF64Array.Create(a.Count);
  if a.Count = 0 then Exit;
  a.AddInto(b, Result);
end;

operator - (const a, b: TSimdF64Array): TSimdF64Array;
begin
  Result := TSimdF64Array.Create(a.Count);
  if a.Count = 0 then Exit;
  a.SubInto(b, Result);
end;

operator * (const a: TSimdF64Array; s: Double): TSimdF64Array;
begin
  Result := TSimdF64Array.Create(a.Count);
  if a.Count = 0 then Exit;
  if a.IsContiguous then
    ArrayMulScalarF64(a.Data, Result.Data, a.Count, s)
  else begin
    Result := a.Clone;
    ArrayMulScalarF64(Result.Data, Result.Data, a.Count, s);
  end;
end;

operator * (s: Double; const a: TSimdF64Array): TSimdF64Array;
begin
  Result := a * s;
end;

operator / (const a: TSimdF64Array; s: Double): TSimdF64Array;
begin
  Result := a * (1.0 / s);
end;

// I32 transforms
procedure TSimdI32Array.AddInto(const aOther: TSimdI32Array; var aDst: TSimdI32Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aOther.IsContiguous and aDst.IsContiguous then
    ArrayAddI32(FData, aOther.FData, aDst.FData, FCount)
  else
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] + aOther.FData[i * aOther.FStride];
end;

procedure TSimdI32Array.SubInto(const aOther: TSimdI32Array; var aDst: TSimdI32Array);
var i: SizeUInt;
begin
  if FCount = 0 then Exit;
  if IsContiguous and aOther.IsContiguous and aDst.IsContiguous then
    ArraySubI32(FData, aOther.FData, aDst.FData, FCount)
  else
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] - aOther.FData[i * aOther.FStride];
end;

procedure TSimdI32Array.AndInto(const aOther: TSimdI32Array; var aDst: TSimdI32Array);
var i: SizeUInt;
begin
  if IsContiguous and aOther.IsContiguous and aDst.IsContiguous then
    ArrayAndI32(FData, aOther.FData, aDst.FData, FCount)
  else
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] and aOther.FData[i * aOther.FStride];
end;

procedure TSimdI32Array.OrInto(const aOther: TSimdI32Array; var aDst: TSimdI32Array);
var i: SizeUInt;
begin
  if IsContiguous and aOther.IsContiguous and aDst.IsContiguous then
    ArrayOrI32(FData, aOther.FData, aDst.FData, FCount)
  else
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] or aOther.FData[i * aOther.FStride];
end;

procedure TSimdI32Array.XorInto(const aOther: TSimdI32Array; var aDst: TSimdI32Array);
var i: SizeUInt;
begin
  if IsContiguous and aOther.IsContiguous and aDst.IsContiguous then
    ArrayXorI32(FData, aOther.FData, aDst.FData, FCount)
  else
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] xor aOther.FData[i * aOther.FStride];
end;

procedure TSimdI32Array.ShlInto(aShift: Integer; var aDst: TSimdI32Array);
var i: SizeUInt;
begin
  if IsContiguous and aDst.IsContiguous then
    ArrayShlI32(FData, aDst.FData, FCount, aShift)
  else
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := FData[i * FStride] shl aShift;
end;

procedure TSimdI32Array.ShrInto(aShift: Integer; var aDst: TSimdI32Array);
var i: SizeUInt;
begin
  if IsContiguous and aDst.IsContiguous then
    ArrayShrI32(FData, aDst.FData, FCount, aShift)
  else
    for i := 0 to FCount - 1 do
      aDst.FData[i * aDst.FStride] := SarLongint(FData[i * FStride], aShift);
end;

end.
