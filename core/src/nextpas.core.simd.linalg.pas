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

// Matrix decompositions (Phase 11)
function QRDecomposeF32(const aA: TSimdF32Matrix;
  var aQ, aR: TSimdF32Matrix): Boolean;
function CholeskyDecomposeF32(const aA: TSimdF32Matrix;
  var aL: TSimdF32Matrix): Boolean;
function SVDDecomposeF32(const aA: TSimdF32Matrix;
  var aU, aSigma: TSimdF32Matrix; var aVt: TSimdF32Matrix): Boolean;
function MatRankF32(const aA: TSimdF32Matrix): SizeUInt;
function MatPseudoInverseF32(const aA: TSimdF32Matrix): TSimdF32Matrix;

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
  Math,
  nextpas.core.simd,
  nextpas.core.simd.linalg.gemm,
  {$IFDEF SIMD_X86_AVAILABLE}
  nextpas.core.simd.linalg.gemm.sse2.blocked,
  {$ENDIF}
  nextpas.core.simd.cpuinfo;

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
    if HasAVX2 then
      GemmBlockedF32(aA.Data, aB.Data, aC.Data,
        aA.Rows, aB.Cols, aA.Cols, aA.Cols, aB.Cols, aC.Cols)
    {$IFDEF SIMD_X86_AVAILABLE}
    else
      GemmBlockedF32_SSE2(aA.Data, aB.Data, aC.Data,
        aA.Rows, aB.Cols, aA.Cols, aA.Cols, aB.Cols, aC.Cols)
    {$ENDIF}
    ;
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

  if (aA.Rows >= GEMM_MR_F64) and (aB.Cols >= GEMM_NR_F64) and (aA.Cols >= 4) and
     (SizeUInt(aA.RowStride) = aA.Cols) and
     (SizeUInt(aB.RowStride) = aB.Cols) and
     (SizeUInt(Result.RowStride) = Result.Cols) then
  begin
    if HasAVX2 then
      GemmBlockedF64(aA.Data, aB.Data, Result.Data,
        aA.Rows, aB.Cols, aA.Cols, aA.Cols, aB.Cols, Result.Cols)
    {$IFDEF SIMD_X86_AVAILABLE}
    else
      GemmBlockedF64_SSE2(aA.Data, aB.Data, Result.Data,
        aA.Rows, aB.Cols, aA.Cols, aA.Cols, aB.Cols, Result.Cols)
    {$ENDIF}
    ;
    Exit;
  end;

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

// ============================================================================
// Matrix Decompositions (Phase 11)
// ============================================================================

function QRDecomposeF32(const aA: TSimdF32Matrix;
  var aQ, aR: TSimdF32Matrix): Boolean;
var
  m, n, k, i, j, p: Integer;
  LNorm, LDot: Single;
begin
  Result := False;
  if (aA.Rows = 0) or (aA.Cols = 0) or
    (aA.Rows > SizeUInt(High(Integer))) or (aA.Cols > SizeUInt(High(Integer))) then Exit;
  m := Integer(aA.Rows);
  n := Integer(aA.Cols);
  k := m;
  if n < k then k := n;

  // Q is m×m, R is m×n
  aQ := TSimdF32Matrix.Zeros(m, m);
  aR := TSimdF32Matrix.Zeros(m, n);

  // Copy A to Q (first n columns)
  for j := 0 to n - 1 do
    for i := 0 to m - 1 do
      aQ.Put(i, j, aA.Get(i, j));

  // Modified Gram-Schmidt on first k columns
  for j := 0 to k - 1 do
  begin
    // Subtract projections onto previous Q columns
    for p := 0 to j - 1 do
    begin
      LDot := 0;
      for i := 0 to m - 1 do
        LDot := LDot + aQ.Get(i, p) * aQ.Get(i, j);
      aR.Put(p, j, LDot);
      for i := 0 to m - 1 do
        aQ.Put(i, j, aQ.Get(i, j) - LDot * aQ.Get(i, p));
    end;

    // Normalize
    LNorm := 0;
    for i := 0 to m - 1 do
      LNorm := LNorm + aQ.Get(i, j) * aQ.Get(i, j);
    LNorm := System.Sqrt(LNorm);
    aR.Put(j, j, LNorm);

    if LNorm > 1e-10 then
      for i := 0 to m - 1 do
        aQ.Put(i, j, aQ.Get(i, j) / LNorm);
  end;

  // Fill remaining columns of Q with orthonormal vectors
  // Use standard basis vectors and orthogonalize against existing Q columns
  for j := k to m - 1 do
  begin
    // Start with standard basis vector e_j
    for i := 0 to m - 1 do
      aQ.Put(i, j, 0.0);
    aQ.Put(j, j, 1.0);

    // Orthogonalize against previous Q columns
    for p := 0 to j - 1 do
    begin
      LDot := 0;
      for i := 0 to m - 1 do
        LDot := LDot + aQ.Get(i, p) * aQ.Get(i, j);
      for i := 0 to m - 1 do
        aQ.Put(i, j, aQ.Get(i, j) - LDot * aQ.Get(i, p));
    end;

    // Normalize
    LNorm := 0;
    for i := 0 to m - 1 do
      LNorm := LNorm + aQ.Get(i, j) * aQ.Get(i, j);
    LNorm := System.Sqrt(LNorm);
    if LNorm > 1e-10 then
      for i := 0 to m - 1 do
        aQ.Put(i, j, aQ.Get(i, j) / LNorm);
  end;

  // Fill remaining R columns for rectangular A (when n > k)
  if n > k then
    for j := k to n - 1 do
      for p := 0 to k - 1 do
      begin
        LDot := 0;
        for i := 0 to m - 1 do
          LDot := LDot + aQ.Get(i, p) * aA.Get(i, j);
        aR.Put(p, j, LDot);
      end;

  Result := True;
end;

function CholeskyDecomposeF32(const aA: TSimdF32Matrix;
  var aL: TSimdF32Matrix): Boolean;
var
  n, i, j, k: Integer;
  LSum: Single;
begin
  Result := False;
  if (aA.Rows = 0) or (aA.Rows <> aA.Cols) or
    (aA.Rows > SizeUInt(High(Integer))) then Exit;
  n := Integer(aA.Rows);
  aL := TSimdF32Matrix.Zeros(n, n);

  for i := 0 to n - 1 do
  begin
    for j := 0 to i do
    begin
      LSum := 0;
      for k := 0 to j - 1 do
        LSum := LSum + aL.Get(i, k) * aL.Get(j, k);

      if i = j then
      begin
        LSum := aA.Get(i, i) - LSum;
        if LSum <= 0 then
        begin
          aL.Free;
          Exit(False); // Not positive definite
        end;
        aL.Put(i, j, System.Sqrt(LSum));
      end
      else
        aL.Put(i, j, (aA.Get(i, j) - LSum) / aL.Get(j, j));
    end;
  end;
  Result := True;
end;

function SVDDecomposeF32(const aA: TSimdF32Matrix;
  var aU, aSigma: TSimdF32Matrix; var aVt: TSimdF32Matrix): Boolean;
var
  m, n, k, i, j, p, q, iter, maxIter: Integer;
  LTheta, LCos, LSin, LTemp, LApq, LApp, LAqq, LSum: Single;
  LU, LV, LSigma, LAtA: TSimdF32Matrix;
  LConverged: Boolean;
begin
  Result := False;
  if (aA.Rows = 0) or (aA.Cols = 0) or
    (aA.Rows > SizeUInt(High(Integer))) or (aA.Cols > SizeUInt(High(Integer))) then Exit;
  m := Integer(aA.Rows);
  n := Integer(aA.Cols);
  k := m;
  if n < k then k := n;

  // For small matrices, use A^T A eigenvalue decomposition
  // SVD: A = U * Sigma * V^T
  // A^T A = V * Sigma^2 * V^T (eigenvalue decomposition)
  // U = A * V * Sigma^(-1)

  // Step 1: Compute A^T A (n x n)
  LAtA := TSimdF32Matrix.Zeros(n, n);
  for i := 0 to n - 1 do
    for j := 0 to n - 1 do
    begin
      LSum := 0;
      for p := 0 to m - 1 do
        LSum := LSum + aA.Get(p, i) * aA.Get(p, j);
      LAtA.Put(i, j, LSum);
    end;

  // Step 2: Eigenvalue decomposition of A^T A using Jacobi
  LV := TSimdF32Matrix.Identity(n);
  maxIter := 100;
  for iter := 0 to maxIter - 1 do
  begin
    LConverged := True;
    for p := 0 to n - 2 do
    begin
      for q := p + 1 to n - 1 do
      begin
        LApp := LAtA.Get(p, p);
        LApq := LAtA.Get(p, q);
        LAqq := LAtA.Get(q, q);

        if Abs(LApq) < 1e-10 then Continue;
        LConverged := False;

        if Abs(LApp - LAqq) < 1e-10 then
          LTheta := PI / 4
        else
          LTheta := 0.5 * Math.ArcTan2(2 * LApq, LApp - LAqq);

        LCos := Cos(LTheta);
        LSin := Sin(LTheta);

        // Apply rotation to A^T A
        for i := 0 to n - 1 do
        begin
          LTemp := LAtA.Get(i, p);
          LAtA.Put(i, p, LCos * LTemp - LSin * LAtA.Get(i, q));
          LAtA.Put(i, q, LSin * LTemp + LCos * LAtA.Get(i, q));
        end;
        for i := 0 to n - 1 do
        begin
          LTemp := LAtA.Get(p, i);
          LAtA.Put(p, i, LCos * LTemp - LSin * LAtA.Get(q, i));
          LAtA.Put(q, i, LSin * LTemp + LCos * LAtA.Get(q, i));
        end;

        // Apply rotation to V
        for i := 0 to n - 1 do
        begin
          LTemp := LV.Get(i, p);
          LV.Put(i, p, LCos * LTemp - LSin * LV.Get(i, q));
          LV.Put(i, q, LSin * LTemp + LCos * LV.Get(i, q));
        end;
      end;
    end;
    if LConverged then Break;
  end;

  // Step 3: Extract singular values (sqrt of eigenvalues)
  LSigma := TSimdF32Matrix.Zeros(k, 1);
  for i := 0 to k - 1 do
  begin
    LTemp := LAtA.Get(i, i);
    if LTemp < 0 then LTemp := 0; // Numerical stability
    LSigma.Put(i, 0, System.Sqrt(LTemp));
  end;

  // Step 4: Sort singular values in descending order
  for i := 0 to k - 2 do
    for j := i + 1 to k - 1 do
      if LSigma.Get(i, 0) < LSigma.Get(j, 0) then
      begin
        // Swap singular values
        LTemp := LSigma.Get(i, 0);
        LSigma.Put(i, 0, LSigma.Get(j, 0));
        LSigma.Put(j, 0, LTemp);

        // Swap columns of V
        for iter := 0 to n - 1 do
        begin
          LTemp := LV.Get(iter, i);
          LV.Put(iter, i, LV.Get(iter, j));
          LV.Put(iter, j, LTemp);
        end;
      end;

  // Step 5: Compute U = A * V * Sigma^(-1)
  LU := TSimdF32Matrix.Zeros(m, k);
  for i := 0 to m - 1 do
    for j := 0 to k - 1 do
    begin
      if LSigma.Get(j, 0) > 1e-10 then
      begin
        LSum := 0;
        for p := 0 to n - 1 do
          LSum := LSum + aA.Get(i, p) * LV.Get(p, j);
        LU.Put(i, j, LSum / LSigma.Get(j, 0));
      end
      else
        LU.Put(i, j, 0);
    end;

  // Orthogonalize U columns (Gram-Schmidt)
  for j := 0 to k - 1 do
  begin
    for p := 0 to j - 1 do
    begin
      LSum := 0;
      for i := 0 to m - 1 do
        LSum := LSum + LU.Get(i, p) * LU.Get(i, j);
      for i := 0 to m - 1 do
        LU.Put(i, j, LU.Get(i, j) - LSum * LU.Get(i, p));
    end;
    LSum := 0;
    for i := 0 to m - 1 do
      LSum := LSum + LU.Get(i, j) * LU.Get(i, j);
    LSum := System.Sqrt(LSum);
    if LSum > 1e-10 then
      for i := 0 to m - 1 do
        LU.Put(i, j, LU.Get(i, j) / LSum);
  end;

  aU := LU;
  aSigma := LSigma;
  aVt := LV.Transpose;
  LV.Free;
  LAtA.Free;
  Result := True;
end;

function MatRankF32(const aA: TSimdF32Matrix): SizeUInt;
var
  U, S, Vt: TSimdF32Matrix;
  k, i: Integer;
  LMaxVal: Single;
begin
  Result := 0;
  if (aA.Rows = 0) or (aA.Cols = 0) then Exit;

  if not SVDDecomposeF32(aA, U, S, Vt) then Exit;
  k := Integer(S.Rows);
  if k = 0 then begin U.Free; S.Free; Vt.Free; Exit; end;

  // Find max singular value for threshold
  LMaxVal := S.Get(0, 0);
  for i := 1 to k - 1 do
    if S.Get(i, 0) > LMaxVal then LMaxVal := S.Get(i, 0);

  // Count singular values above threshold
  for i := 0 to k - 1 do
    if S.Get(i, 0) > LMaxVal * 1e-6 then
      Inc(Result);

  U.Free; S.Free; Vt.Free;
end;

function MatPseudoInverseF32(const aA: TSimdF32Matrix): TSimdF32Matrix;
var
  U, S, Vt: TSimdF32Matrix;
  m, n, k, i, j: Integer;
  LThreshold: Single;
begin
  Result := Default(TSimdF32Matrix);
  if (aA.Rows = 0) or (aA.Cols = 0) then Exit;

  if not SVDDecomposeF32(aA, U, S, Vt) then Exit;
  m := Integer(aA.Rows);
  n := Integer(aA.Cols);
  k := Integer(S.Rows);
  if k = 0 then begin U.Free; S.Free; Vt.Free; Exit; end;

  // Threshold for singular values
  LThreshold := S.Get(0, 0) * 1e-6;

  // Compute V * S^+ * U^T
  Result := TSimdF32Matrix.Zeros(n, m);
  for i := 0 to k - 1 do
  begin
    if S.Get(i, 0) > LThreshold then
    begin
      // Add (1/s_i) * v_i * u_i^T to result
      for j := 0 to n - 1 do
        for k := 0 to m - 1 do
          Result.Put(j, k, Result.Get(j, k) +
            Vt.Get(i, j) * U.Get(k, i) / S.Get(i, 0));
    end;
  end;

  U.Free; S.Free; Vt.Free;
end;

end.
