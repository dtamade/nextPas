unit nextpas.core.simd.linalg;


{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.alloc,
  nextpas.core.simd.arrays.typed;

type
  TSimdF32Matrix = record
  private
    FData: PSingle;
    FRows: SizeUInt;
    FCols: SizeUInt;
    FRowStride: NativeInt;
    FOwned: Boolean;
  public
    class function Create(aRows, aCols: SizeUInt): TSimdF32Matrix; static;
    class function Zeros(aRows, aCols: SizeUInt): TSimdF32Matrix; static;
    class function Identity(aSize: SizeUInt): TSimdF32Matrix; static;
    class function Wrap(aData: PSingle; aRows, aCols: SizeUInt): TSimdF32Matrix; static;
    procedure Free;

    function Row(aRow: SizeUInt): TSimdF32Array;
    function Col(aCol: SizeUInt): TSimdF32Array;
    function Get(aRow, aCol: SizeUInt): Single; inline;
    procedure Put(aRow, aCol: SizeUInt; aValue: Single); inline;

    function Transpose: TSimdF32Matrix;
    function Clone: TSimdF32Matrix;
    function Diag: TSimdF32Array;
    class function FromDiag(const aDiag: TSimdF32Array): TSimdF32Matrix; static;

    property Data: PSingle read FData;
    property Rows: SizeUInt read FRows;
    property Cols: SizeUInt read FCols;
    property RowStride: NativeInt read FRowStride;
  end;

procedure GemvF32(aAlpha: Single; const aA: TSimdF32Matrix;
  const aX: TSimdF32Array; aBeta: Single; var aY: TSimdF32Array);

procedure GemmF32(aAlpha: Single; const aA, aB: TSimdF32Matrix;
  aBeta: Single; var aC: TSimdF32Matrix);

function MatVecMulF32(const aA: TSimdF32Matrix; const aX: TSimdF32Array): TSimdF32Array;

function MatMulF32(const aA, aB: TSimdF32Matrix): TSimdF32Matrix;
function MatAddF32(const aA, aB: TSimdF32Matrix): TSimdF32Matrix;
function MatSubF32(const aA, aB: TSimdF32Matrix): TSimdF32Matrix;
function MatScaleF32(const aA: TSimdF32Matrix; aScalar: Single): TSimdF32Matrix;
function MatTraceF32(const aA: TSimdF32Matrix): Single;
function MatFrobeniusNormF32(const aA: TSimdF32Matrix): Single;

function LUDecomposeF32(const aA: TSimdF32Matrix; var aL, aU: TSimdF32Matrix): Boolean;
function SolveLinearF32(const aA: TSimdF32Matrix; const aB: TSimdF32Array): TSimdF32Array;
function MatInverseF32(const aA: TSimdF32Matrix): TSimdF32Matrix;
function MatDeterminantF32(const aA: TSimdF32Matrix): Single;
function OuterProductF32(const aU, aV: TSimdF32Array): TSimdF32Matrix;
function MatHadamardF32(const aA, aB: TSimdF32Matrix): TSimdF32Matrix;
function MatSumRowsF32(const aA: TSimdF32Matrix): TSimdF32Array;
function MatSumColsF32(const aA: TSimdF32Matrix): TSimdF32Array;
function MatMaxRowsF32(const aA: TSimdF32Matrix): TSimdF32Array;
procedure MatArgMaxRowsF32(const aA: TSimdF32Matrix; aIndices: PInt32);

type
  TSimdF64Matrix = record
  private
    FData: PDouble;
    FRows: SizeUInt;
    FCols: SizeUInt;
    FRowStride: NativeInt;
    FOwned: Boolean;
  public
    class function Create(aRows, aCols: SizeUInt): TSimdF64Matrix; static;
    class function Zeros(aRows, aCols: SizeUInt): TSimdF64Matrix; static;
    class function Identity(aSize: SizeUInt): TSimdF64Matrix; static;
    class function Wrap(aData: PDouble; aRows, aCols: SizeUInt): TSimdF64Matrix; static;
    procedure Free;

    function Row(aRow: SizeUInt): TSimdF64Array;
    function Get(aRow, aCol: SizeUInt): Double; inline;
    procedure Put(aRow, aCol: SizeUInt; aValue: Double); inline;

    function Transpose: TSimdF64Matrix;
    function Clone: TSimdF64Matrix;

    property Data: PDouble read FData;
    property Rows: SizeUInt read FRows;
    property Cols: SizeUInt read FCols;
    property RowStride: NativeInt read FRowStride;
  end;

function MatMulF64(const aA, aB: TSimdF64Matrix): TSimdF64Matrix;
function MatAddF64(const aA, aB: TSimdF64Matrix): TSimdF64Matrix;
function MatScaleF64(const aA: TSimdF64Matrix; aScalar: Double): TSimdF64Matrix;
function MatVecMulF64(const aA: TSimdF64Matrix; const aX: TSimdF64Array): TSimdF64Array;
function MatTraceF64(const aA: TSimdF64Matrix): Double;
function MatFrobeniusNormF64(const aA: TSimdF64Matrix): Double;

implementation

uses
  nextpas.core.simd,
  nextpas.core.simd.linalg.gemm;

class function TSimdF32Matrix.Create(aRows, aCols: SizeUInt): TSimdF32Matrix;
begin
  Result.FRows := aRows;
  Result.FCols := aCols;
  Result.FRowStride := aCols;
  Result.FOwned := True;
  Result.FData := PSingle(SimdAlloc(aRows * aCols * SizeOf(Single)));
end;

class function TSimdF32Matrix.Zeros(aRows, aCols: SizeUInt): TSimdF32Matrix;
begin
  Result := TSimdF32Matrix.Create(aRows, aCols);
  FillChar(Result.FData^, aRows * aCols * SizeOf(Single), 0);
end;

class function TSimdF32Matrix.Identity(aSize: SizeUInt): TSimdF32Matrix;
var i: SizeUInt;
begin
  Result := TSimdF32Matrix.Zeros(aSize, aSize);
  if aSize = 0 then Exit;
  for i := 0 to aSize - 1 do
    Result.FData[i * aSize + i] := 1.0;
end;

class function TSimdF32Matrix.Wrap(aData: PSingle; aRows, aCols: SizeUInt): TSimdF32Matrix;
begin
  Result.FData := aData;
  Result.FRows := aRows;
  Result.FCols := aCols;
  Result.FRowStride := aCols;
  Result.FOwned := False;
end;

procedure TSimdF32Matrix.Free;
begin
  if FOwned and (FData <> nil) then SimdFree(FData);
  FData := nil; FRows := 0; FCols := 0;
end;

function TSimdF32Matrix.Row(aRow: SizeUInt): TSimdF32Array;
begin
  Result := TSimdF32Array.Wrap(@FData[aRow * FRowStride], FCols);
end;

function TSimdF32Matrix.Col(aCol: SizeUInt): TSimdF32Array;
begin
  Result := TSimdF32Array.WrapStrided(@FData[aCol], FRows, FRowStride);
end;

function TSimdF32Matrix.Get(aRow, aCol: SizeUInt): Single;
begin
  Result := FData[aRow * FRowStride + aCol];
end;

procedure TSimdF32Matrix.Put(aRow, aCol: SizeUInt; aValue: Single);
begin
  FData[aRow * FRowStride + aCol] := aValue;
end;

function TSimdF32Matrix.Transpose: TSimdF32Matrix;
var r, c: SizeUInt;
begin
  Result := TSimdF32Matrix.Create(FCols, FRows);
  if (FRows = 0) or (FCols = 0) then Exit;
  for r := 0 to FRows - 1 do
    for c := 0 to FCols - 1 do
      Result.FData[c * FRows + r] := FData[r * FRowStride + c];
end;

function TSimdF32Matrix.Clone: TSimdF32Matrix;
var r: SizeUInt;
begin
  Result := TSimdF32Matrix.Create(FRows, FCols);
  if (FRows = 0) or (FCols = 0) then Exit;
  if SizeUInt(FRowStride) = FCols then
    Move(FData^, Result.FData^, FRows * FCols * SizeOf(Single))
  else
    for r := 0 to FRows - 1 do
      Move(FData[r * FRowStride], Result.FData[r * FCols], FCols * SizeOf(Single));
end;

function TSimdF32Matrix.Diag: TSimdF32Array;
var i, n: SizeUInt;
begin
  if FRows < FCols then n := FRows else n := FCols;
  Result := TSimdF32Array.Create(n);
  if n = 0 then Exit;
  for i := 0 to n - 1 do
    Result.Data[i] := FData[i * FRowStride + i];
end;

class function TSimdF32Matrix.FromDiag(const aDiag: TSimdF32Array): TSimdF32Matrix;
var i: SizeUInt;
begin
  Result := TSimdF32Matrix.Zeros(aDiag.Count, aDiag.Count);
  if aDiag.Count = 0 then Exit;
  for i := 0 to aDiag.Count - 1 do
    Result.FData[i * Result.FRowStride + i] := aDiag.Data[i * aDiag.Stride];
end;

procedure GemvF32(aAlpha: Single; const aA: TSimdF32Matrix;
  const aX: TSimdF32Array; aBeta: Single; var aY: TSimdF32Array);
var
  r: SizeUInt;
  LRow: TSimdF32Array;
  LDot: Single;
begin
  if aA.Rows = 0 then Exit;
  if (aAlpha = 1.0) and (aBeta = 0.0) then
  begin
    for r := 0 to aA.Rows - 1 do
    begin
      LRow := aA.Row(r);
      aY.Data[r] := LRow.Dot(aX);
    end;
  end
  else
  begin
    for r := 0 to aA.Rows - 1 do
    begin
      LRow := aA.Row(r);
      LDot := LRow.Dot(aX);
      aY.Data[r] := aAlpha * LDot + aBeta * aY.Data[r];
    end;
  end;
end;

procedure GemmF32(aAlpha: Single; const aA, aB: TSimdF32Matrix;
  aBeta: Single; var aC: TSimdF32Matrix);
var
  r, c: SizeUInt;
  LRowA: TSimdF32Array;
  LDot: Single;
  LBt: TSimdF32Matrix;
begin
  if (aA.Rows = 0) or (aA.Cols = 0) or (aB.Cols = 0) then Exit;

  // Fast path: large matrices with simple alpha=1, beta=0 and contiguous layout
  if (aA.Rows >= GEMM_MR) and (aB.Cols >= GEMM_NR) and (aA.Cols >= 8) and
     (aAlpha = 1.0) and (aBeta = 0.0) and
     (SizeUInt(aA.RowStride) = aA.Cols) and
     (SizeUInt(aB.RowStride) = aB.Cols) and
     (SizeUInt(aC.RowStride) = aC.Cols) then
  begin
    GemmBlockedF32(aA.Data, aB.Data, aC.Data,
      aA.Rows, aB.Cols, aA.Cols, aA.Cols, aB.Cols, aC.Cols);
    Exit;
  end;

  // Fallback: transpose-based ReduceDotF32 path
  if aA.Cols >= 8 then
  begin
    LBt := aB.Transpose;
    if (aAlpha = 1.0) and (aBeta = 0.0) then
    begin
      for r := 0 to aA.Rows - 1 do
      begin
        LRowA := aA.Row(r);
        for c := 0 to aB.Cols - 1 do
          aC.Data[r * aC.RowStride + c] := ReduceDotF32(@LRowA.Data[0], @LBt.Data[c * LBt.RowStride], aA.Cols);
      end;
    end
    else
    begin
      for r := 0 to aA.Rows - 1 do
      begin
        LRowA := aA.Row(r);
        for c := 0 to aB.Cols - 1 do
        begin
          LDot := ReduceDotF32(@LRowA.Data[0], @LBt.Data[c * LBt.RowStride], aA.Cols);
          aC.Data[r * aC.RowStride + c] := aAlpha * LDot + aBeta * aC.Data[r * aC.RowStride + c];
        end;
      end;
    end;
    LBt.Free;
  end
  else
  begin
    if (aAlpha = 1.0) and (aBeta = 0.0) then
    begin
      for r := 0 to aA.Rows - 1 do
      begin
        LRowA := aA.Row(r);
        for c := 0 to aB.Cols - 1 do
          aC.Data[r * aC.RowStride + c] := LRowA.Dot(aB.Col(c));
      end;
    end
    else
    begin
      for r := 0 to aA.Rows - 1 do
      begin
        LRowA := aA.Row(r);
        for c := 0 to aB.Cols - 1 do
        begin
          LDot := LRowA.Dot(aB.Col(c));
          aC.Data[r * aC.RowStride + c] := aAlpha * LDot + aBeta * aC.Data[r * aC.RowStride + c];
        end;
      end;
    end;
  end;
end;

function MatVecMulF32(const aA: TSimdF32Matrix; const aX: TSimdF32Array): TSimdF32Array;
begin
  Result := TSimdF32Array.Zeros(aA.Rows);
  GemvF32(1.0, aA, aX, 0.0, Result);
end;


function MatMulF32(const aA, aB: TSimdF32Matrix): TSimdF32Matrix;
begin
  Result := TSimdF32Matrix.Zeros(aA.Rows, aB.Cols);
  GemmF32(1.0, aA, aB, 0.0, Result);
end;

function MatAddF32(const aA, aB: TSimdF32Matrix): TSimdF32Matrix;
var r: SizeUInt; LTotal: SizeUInt;
begin
  Result := TSimdF32Matrix.Create(aA.Rows, aA.Cols);
  if (aA.Rows = 0) or (aA.Cols = 0) then Exit;
  LTotal := aA.Rows * aA.Cols;
  if (SizeUInt(aA.RowStride) = aA.Cols) and (SizeUInt(aB.RowStride) = aB.Cols) then
    ArrayAddF32(aA.Data, aB.Data, Result.Data, LTotal)
  else
    for r := 0 to aA.Rows - 1 do
      ArrayAddF32(@aA.Data[r * aA.RowStride], @aB.Data[r * aB.RowStride],
        @Result.Data[r * Result.RowStride], aA.Cols);
end;

function MatSubF32(const aA, aB: TSimdF32Matrix): TSimdF32Matrix;
var r: SizeUInt; LTotal: SizeUInt;
begin
  Result := TSimdF32Matrix.Create(aA.Rows, aA.Cols);
  if (aA.Rows = 0) or (aA.Cols = 0) then Exit;
  LTotal := aA.Rows * aA.Cols;
  if (SizeUInt(aA.RowStride) = aA.Cols) and (SizeUInt(aB.RowStride) = aB.Cols) then
    ArraySubF32(aA.Data, aB.Data, Result.Data, LTotal)
  else
    for r := 0 to aA.Rows - 1 do
      ArraySubF32(@aA.Data[r * aA.RowStride], @aB.Data[r * aB.RowStride],
        @Result.Data[r * Result.RowStride], aA.Cols);
end;

function MatScaleF32(const aA: TSimdF32Matrix; aScalar: Single): TSimdF32Matrix;
var r: SizeUInt; LTotal: SizeUInt;
begin
  Result := TSimdF32Matrix.Create(aA.Rows, aA.Cols);
  if (aA.Rows = 0) or (aA.Cols = 0) then Exit;
  LTotal := aA.Rows * aA.Cols;
  if SizeUInt(aA.RowStride) = aA.Cols then
    ArrayMulScalarF32(aA.Data, Result.Data, LTotal, aScalar)
  else
    for r := 0 to aA.Rows - 1 do
      ArrayMulScalarF32(@aA.Data[r * aA.RowStride],
        @Result.Data[r * Result.RowStride], aA.Cols, aScalar);
end;

function MatTraceF32(const aA: TSimdF32Matrix): Single;
var i, n: SizeUInt;
begin
  Result := 0;
  if aA.Rows < aA.Cols then n := aA.Rows else n := aA.Cols;
  if n = 0 then Exit;
  for i := 0 to n - 1 do
    Result := Result + aA.Data[i * aA.RowStride + i];
end;

function MatFrobeniusNormF32(const aA: TSimdF32Matrix): Single;
var r: SizeUInt; LSum: Single;
begin
  if (aA.Rows = 0) or (aA.Cols = 0) then begin Result := 0; Exit; end;
  if SizeUInt(aA.RowStride) = aA.Cols then
    Result := System.Sqrt(ReduceDotF32(aA.Data, aA.Data, aA.Rows * aA.Cols))
  else
  begin
    LSum := 0;
    for r := 0 to aA.Rows - 1 do
      LSum := LSum + ReduceDotF32(@aA.Data[r * aA.RowStride], @aA.Data[r * aA.RowStride], aA.Cols);
    Result := System.Sqrt(LSum);
  end;
end;

function LUDecomposeF32(const aA: TSimdF32Matrix; var aL, aU: TSimdF32Matrix): Boolean;
var
  i, j, k, n: Integer;
  LSum: Single;
begin
  if (aA.Rows = 0) or (aA.Rows <> aA.Cols) or
    (aA.Rows > SizeUInt(High(Integer))) then Exit(False);
  n := Integer(aA.Rows);
  aL := TSimdF32Matrix.Zeros(aA.Rows, aA.Cols);
  aU := TSimdF32Matrix.Zeros(aA.Rows, aA.Cols);

  for i := 0 to n - 1 do
  begin
    for k := i to n - 1 do
    begin
      LSum := 0;
      for j := 0 to i - 1 do
        LSum := LSum + aL.Get(i, j) * aU.Get(j, k);
      aU.Put(i, k, aA.Get(i, k) - LSum);
    end;
    if aU.Get(i, i) = 0 then
    begin
      aL.Free; aU.Free;
      Exit(False);
    end;
    aL.Put(i, i, 1.0);
    for k := i + 1 to n - 1 do
    begin
      LSum := 0;
      for j := 0 to i - 1 do
        LSum := LSum + aL.Get(k, j) * aU.Get(j, i);
      aL.Put(k, i, (aA.Get(k, i) - LSum) / aU.Get(i, i));
    end;
  end;
  Result := True;
end;

function SolveLinearF32(const aA: TSimdF32Matrix; const aB: TSimdF32Array): TSimdF32Array;
var
  L, U: TSimdF32Matrix;
  Y: TSimdF32Array;
  n, i, j: Integer;
  LSum: Single;
begin
  Result := Default(TSimdF32Array);
  if (aA.Rows = 0) or (aA.Rows <> aA.Cols) or
    (aB.Count <> aA.Rows) or (aA.Rows > SizeUInt(High(Integer))) then Exit;
  n := Integer(aA.Rows);
  if not LUDecomposeF32(aA, L, U) then Exit;

  Result := TSimdF32Array.Create(aA.Rows);
  Y := TSimdF32Array.Create(aA.Rows);
  for i := 0 to n - 1 do
  begin
    LSum := 0;
    for j := 0 to i - 1 do
      LSum := LSum + L.Get(i, j) * Y.Data[j];
    Y.Data[i] := aB.Data[i] - LSum;
  end;

  for i := n - 1 downto 0 do
  begin
    LSum := 0;
    for j := i + 1 to n - 1 do
      LSum := LSum + U.Get(i, j) * Result.Data[j];
    if U.Get(i, i) = 0 then begin Result.Data[i] := 0; continue; end;
    Result.Data[i] := (Y.Data[i] - LSum) / U.Get(i, i);
  end;

  Y.Free; L.Free; U.Free;
end;

function MatInverseF32(const aA: TSimdF32Matrix): TSimdF32Matrix;
var
  L, U: TSimdF32Matrix;
  i, j, k, n: Integer;
  LSum: Single;
  LY: PSingle;
begin
  Result := Default(TSimdF32Matrix);
  if (aA.Rows = 0) or (aA.Rows <> aA.Cols) or
    (aA.Rows > SizeUInt(High(Integer))) then Exit;
  n := Integer(aA.Rows);
  if not LUDecomposeF32(aA, L, U) then Exit;

  Result := TSimdF32Matrix.Create(aA.Rows, aA.Rows);
  LY := PSingle(SimdAlloc(SizeUInt(n) * SizeOf(Single)));

  for i := 0 to n - 1 do
  begin
    for j := 0 to n - 1 do
    begin
      LSum := 0;
      for k := 0 to j - 1 do
        LSum := LSum + L.Get(j, k) * LY[k];
      if j = i then LY[j] := 1.0 - LSum
      else LY[j] := -LSum;
    end;
    for j := n - 1 downto 0 do
    begin
      LSum := 0;
      for k := j + 1 to n - 1 do
        LSum := LSum + U.Get(j, k) * Result.Get(k, i);
      if U.Get(j, j) = 0 then Result.Put(j, i, 0)
      else Result.Put(j, i, (LY[j] - LSum) / U.Get(j, j));
    end;
  end;

  SimdFree(LY);
  L.Free; U.Free;
end;

function MatDeterminantF32(const aA: TSimdF32Matrix): Single;
var
  L, U: TSimdF32Matrix;
  i: Integer;
begin
  if not LUDecomposeF32(aA, L, U) then Exit(0);
  Result := 1.0;
  for i := 0 to Integer(aA.Rows) - 1 do
    Result := Result * U.Get(i, i);
  L.Free; U.Free;
end;

function OuterProductF32(const aU, aV: TSimdF32Array): TSimdF32Matrix;
var r, c: SizeUInt;
    LVData: PSingle;
    LNeedFree: Boolean;
begin
  Result := TSimdF32Matrix.Create(aU.Count, aV.Count);
  if (aU.Count = 0) or (aV.Count = 0) then Exit;
  if aV.IsContiguous then
  begin
    LVData := aV.Data;
    LNeedFree := False;
  end
  else
  begin
    LVData := PSingle(SimdAlloc(aV.Count * SizeOf(Single)));
    for c := 0 to aV.Count - 1 do
      LVData[c] := aV.Data[c * aV.Stride];
    LNeedFree := True;
  end;
  for r := 0 to aU.Count - 1 do
    ArrayMulScalarF32(LVData, @Result.Data[r * Result.RowStride], aV.Count, aU.Data[r * aU.Stride]);
  if LNeedFree then SimdFree(LVData);
end;

function MatHadamardF32(const aA, aB: TSimdF32Matrix): TSimdF32Matrix;
var r: SizeUInt;
begin
  Result := TSimdF32Matrix.Create(aA.Rows, aA.Cols);
  if (aA.Rows = 0) or (aA.Cols = 0) then Exit;
  if (SizeUInt(aA.RowStride) = aA.Cols) and (SizeUInt(aB.RowStride) = aB.Cols) then
    ArrayMulF32(aA.Data, aB.Data, Result.Data, aA.Rows * aA.Cols)
  else
    for r := 0 to aA.Rows - 1 do
      ArrayMulF32(@aA.Data[r * aA.RowStride], @aB.Data[r * aB.RowStride],
        @Result.Data[r * Result.RowStride], aA.Cols);
end;

function MatSumRowsF32(const aA: TSimdF32Matrix): TSimdF32Array;
var r: SizeUInt;
begin
  Result := TSimdF32Array.Create(aA.Rows);
  if aA.Rows = 0 then Exit;
  for r := 0 to aA.Rows - 1 do
    Result.Data[r] := ReduceSumF32(@aA.Data[r * aA.RowStride], aA.Cols);
end;

function MatSumColsF32(const aA: TSimdF32Matrix): TSimdF32Array;
var r: SizeUInt;
begin
  Result := TSimdF32Array.Zeros(aA.Cols);
  if (aA.Rows = 0) or (aA.Cols = 0) then Exit;
  for r := 0 to aA.Rows - 1 do
    ArrayAddF32(Result.Data, @aA.Data[r * aA.RowStride], Result.Data, aA.Cols);
end;

function MatMaxRowsF32(const aA: TSimdF32Matrix): TSimdF32Array;
var r: SizeUInt;
begin
  Result := TSimdF32Array.Create(aA.Rows);
  if aA.Rows = 0 then Exit;
  for r := 0 to aA.Rows - 1 do
    Result.Data[r] := ReduceMaxF32(@aA.Data[r * aA.RowStride], aA.Cols);
end;

procedure MatArgMaxRowsF32(const aA: TSimdF32Matrix; aIndices: PInt32);
var r, c: SizeUInt;
    LMax: Single;
    LIdx: Int32;
    LRow: PSingle;
begin
  if (aA.Rows = 0) or (aA.Cols = 0) then Exit;
  for r := 0 to aA.Rows - 1 do
  begin
    LRow := @aA.Data[r * aA.RowStride];
    LMax := LRow[0];
    LIdx := 0;
    for c := 1 to aA.Cols - 1 do
      if LRow[c] > LMax then begin LMax := LRow[c]; LIdx := Int32(c); end;
    aIndices[r] := LIdx;
  end;
end;

// ============================================================================
// TSimdF64Matrix Implementation
// ============================================================================

class function TSimdF64Matrix.Create(aRows, aCols: SizeUInt): TSimdF64Matrix;
begin
  Result.FRows := aRows;
  Result.FCols := aCols;
  Result.FRowStride := aCols;
  Result.FOwned := True;
  Result.FData := PDouble(SimdAlloc(aRows * aCols * SizeOf(Double)));
end;

class function TSimdF64Matrix.Zeros(aRows, aCols: SizeUInt): TSimdF64Matrix;
begin
  Result := TSimdF64Matrix.Create(aRows, aCols);
  FillChar(Result.FData^, aRows * aCols * SizeOf(Double), 0);
end;

class function TSimdF64Matrix.Identity(aSize: SizeUInt): TSimdF64Matrix;
var i: SizeUInt;
begin
  Result := TSimdF64Matrix.Zeros(aSize, aSize);
  if aSize = 0 then Exit;
  for i := 0 to aSize - 1 do
    Result.FData[i * aSize + i] := 1.0;
end;

class function TSimdF64Matrix.Wrap(aData: PDouble; aRows, aCols: SizeUInt): TSimdF64Matrix;
begin
  Result.FData := aData;
  Result.FRows := aRows;
  Result.FCols := aCols;
  Result.FRowStride := aCols;
  Result.FOwned := False;
end;

procedure TSimdF64Matrix.Free;
begin
  if FOwned and (FData <> nil) then SimdFree(FData);
  FData := nil; FRows := 0; FCols := 0;
end;

function TSimdF64Matrix.Row(aRow: SizeUInt): TSimdF64Array;
begin
  Result := TSimdF64Array.Wrap(@FData[aRow * FRowStride], FCols);
end;

function TSimdF64Matrix.Get(aRow, aCol: SizeUInt): Double;
begin
  Result := FData[aRow * FRowStride + aCol];
end;

procedure TSimdF64Matrix.Put(aRow, aCol: SizeUInt; aValue: Double);
begin
  FData[aRow * FRowStride + aCol] := aValue;
end;

function TSimdF64Matrix.Transpose: TSimdF64Matrix;
var r, c: SizeUInt;
begin
  Result := TSimdF64Matrix.Create(FCols, FRows);
  if (FRows = 0) or (FCols = 0) then Exit;
  for r := 0 to FRows - 1 do
    for c := 0 to FCols - 1 do
      Result.FData[c * FRows + r] := FData[r * FRowStride + c];
end;

function TSimdF64Matrix.Clone: TSimdF64Matrix;
begin
  Result := TSimdF64Matrix.Create(FRows, FCols);
  if (FRows = 0) or (FCols = 0) then Exit;
  Move(FData^, Result.FData^, FRows * FCols * SizeOf(Double));
end;

function MatMulF64(const aA, aB: TSimdF64Matrix): TSimdF64Matrix;
var
  r, c: SizeUInt;
  LBt: TSimdF64Matrix;
  LDot: Double;
begin
  Result := TSimdF64Matrix.Zeros(aA.Rows, aB.Cols);
  if (aA.Rows = 0) or (aA.Cols = 0) or (aB.Cols = 0) then Exit;
  LBt := aB.Transpose;
  for r := 0 to aA.Rows - 1 do
    for c := 0 to aB.Cols - 1 do
    begin
      LDot := ReduceDotF64(@aA.Data[r * aA.RowStride], @LBt.Data[c * LBt.RowStride], aA.Cols);
      Result.Data[r * Result.RowStride + c] := LDot;
    end;
  LBt.Free;
end;

function MatAddF64(const aA, aB: TSimdF64Matrix): TSimdF64Matrix;
begin
  Result := TSimdF64Matrix.Create(aA.Rows, aA.Cols);
  if (aA.Rows = 0) or (aA.Cols = 0) then Exit;
  ArrayAddF64(aA.Data, aB.Data, Result.Data, aA.Rows * aA.Cols);
end;

function MatScaleF64(const aA: TSimdF64Matrix; aScalar: Double): TSimdF64Matrix;
begin
  Result := TSimdF64Matrix.Create(aA.Rows, aA.Cols);
  if (aA.Rows = 0) or (aA.Cols = 0) then Exit;
  ArrayMulScalarF64(aA.Data, Result.Data, aA.Rows * aA.Cols, aScalar);
end;

function MatVecMulF64(const aA: TSimdF64Matrix; const aX: TSimdF64Array): TSimdF64Array;
var r: SizeUInt;
begin
  Result := TSimdF64Array.Zeros(aA.Rows);
  if aA.Rows = 0 then Exit;
  for r := 0 to aA.Rows - 1 do
    Result.Data[r] := ReduceDotF64(@aA.Data[r * aA.RowStride], aX.Data, aA.Cols);
end;

function MatTraceF64(const aA: TSimdF64Matrix): Double;
var i, n: SizeUInt;
begin
  Result := 0;
  if aA.Rows < aA.Cols then n := aA.Rows else n := aA.Cols;
  if n = 0 then Exit;
  for i := 0 to n - 1 do
    Result := Result + aA.Data[i * aA.RowStride + i];
end;

function MatFrobeniusNormF64(const aA: TSimdF64Matrix): Double;
begin
  if (aA.Rows = 0) or (aA.Cols = 0) then begin Result := 0; Exit; end;
  Result := System.Sqrt(ReduceDotF64(aA.Data, aA.Data, aA.Rows * aA.Cols));
end;

end.
