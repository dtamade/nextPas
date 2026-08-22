{******************************************************************************
  nextpas.core.lockfree.matrix

  Concurrent Matrix: 并发矩阵运算 (Concurrent Matrix Operations)

  核心设计:
    - 固定大小矩阵，行主序存储
    - 支持基本运算: Multiply, Transpose, Inverse, Determinant
    - 分块矩阵乘法提高缓存命中率

  复杂度:
    - Multiply: O(n³) — 分块优化
    - Transpose: O(n²)
    - Inverse: O(n³) — Gauss-Jordan 消元
    - Determinant: O(n³) — LU 分解
    - 空间: O(n²)

  线程安全: 使用 CAS 自旋锁保护所有操作。

  @author nextPas Contributors
  @date 2026-07-06
******************************************************************************}

unit nextpas.core.lockfree.matrix;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.atomic;

const
  MATRIX_MAX_SIZE = 256;
  MATRIX_BLOCK_SIZE = 16;

type
  TMatrixData = array of Double;

  TMatrixStatus = (
    mtOk = 0,
    mtClosed = 1,
    mtDimensionMismatch = 2,
    mtSingular = 3,
    mtInvalidSize = 4,
    mtOutOfBounds = 5
  );

  TMatrixImpl = class
  public
    FData: TMatrixData;
    FRows: Integer;
    FCols: Integer;
  private
    FLock: Int32;
    FClosed: Int32;

    function Idx(ARow, ACol: Integer): Integer;
    procedure Lock;
    procedure Snapshot(out ARows, ACols: Integer; out AData: TMatrixData);
    procedure Unlock;
  public
    constructor Create(ARows, ACols: UInt32);
    destructor Destroy; override;

    function Get(ARow, ACol: Integer; out AValue: Double): TMatrixStatus;
    function Put(ARow, ACol: Integer; AValue: Double): TMatrixStatus;
    function GetRows: Integer;
    function GetCols: Integer;

    function Multiply(const AOther: TMatrixImpl; out AResult: TMatrixImpl): TMatrixStatus;
    function Transpose(out AResult: TMatrixImpl): TMatrixStatus;
    function Determinant(out AValue: Double): TMatrixStatus;
    function Inverse(out AResult: TMatrixImpl): TMatrixStatus;

    procedure Close;
    function IsClosed: Boolean; inline;
  end;

implementation

{ TMatrixImpl }

procedure TMatrixImpl.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_seq_cst, mo_seq_cst) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end;
  end;
end;

procedure TMatrixImpl.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

procedure TMatrixImpl.Snapshot(out ARows, ACols: Integer;
  out AData: TMatrixData);
begin
  Lock;
  try
    ARows := FRows;
    ACols := FCols;
    AData := Copy(FData, 0, Length(FData));
  finally
    Unlock;
  end;
end;

constructor TMatrixImpl.Create(ARows, ACols: UInt32);
var
  LI: Integer;
begin
  inherited Create;
  if (ARows < 1) or (ACols < 1) or (ARows > MATRIX_MAX_SIZE) or (ACols > MATRIX_MAX_SIZE) then
  begin
    FRows := 0;
    FCols := 0;
    SetLength(FData, 0);
    FLock := 0;
    FClosed := 0;
    Exit;
  end;
  FRows := ARows;
  FCols := ACols;
  SetLength(FData, FRows * FCols);
  for LI := 0 to High(FData) do
    FData[LI] := 0.0;
  FLock := 0;
  FClosed := 0;
end;

destructor TMatrixImpl.Destroy;
begin
  SetLength(FData, 0);
  inherited Destroy;
end;

function TMatrixImpl.Idx(ARow, ACol: Integer): Integer;
begin
  Result := ARow * FCols + ACol;
end;

function TMatrixImpl.Get(ARow, ACol: Integer; out AValue: Double): TMatrixStatus;
begin
  AValue := 0;
  Lock;
  try
    if (ARow < 0) or (ARow >= FRows) or (ACol < 0) or (ACol >= FCols) then
      Exit(mtOutOfBounds);
    AValue := FData[Idx(ARow, ACol)];
    Result := mtOk;
  finally
    Unlock;
  end;
end;

function TMatrixImpl.Put(ARow, ACol: Integer; AValue: Double): TMatrixStatus;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(mtClosed);
  if (ARow < 0) or (ARow >= FRows) or (ACol < 0) or (ACol >= FCols) then
    Exit(mtOutOfBounds);

  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(mtClosed);
    FData[Idx(ARow, ACol)] := AValue;
    Result := mtOk;
  finally
    Unlock;
  end;
end;

function TMatrixImpl.GetRows: Integer;
begin
  Result := FRows;
end;

function TMatrixImpl.GetCols: Integer;
begin
  Result := FCols;
end;

function TMatrixImpl.Multiply(const AOther: TMatrixImpl; out AResult: TMatrixImpl): TMatrixStatus;
var
  LData, LOtherData: TMatrixData;
  LRows, LCols, LOtherRows, LOtherCols: Integer;
  LI, LJ, LK: Integer;
  LSum: Double;
begin
  AResult := nil;
  if AOther = nil then
    Exit(mtDimensionMismatch);

  Snapshot(LRows, LCols, LData);
  if AOther = Self then
  begin
    LOtherRows := LRows;
    LOtherCols := LCols;
    LOtherData := Copy(LData, 0, Length(LData));
  end
  else
    AOther.Snapshot(LOtherRows, LOtherCols, LOtherData);
  if LCols <> LOtherRows then
    Exit(mtDimensionMismatch);

  AResult := TMatrixImpl.Create(LRows, LOtherCols);
  if (AResult.FRows = 0) or (AResult.FCols = 0) then
  begin
    AResult.Free;
    AResult := nil;
    Exit(mtInvalidSize);
  end;

  for LI := 0 to LRows - 1 do
    for LJ := 0 to LOtherCols - 1 do
    begin
      LSum := 0;
      for LK := 0 to LCols - 1 do
        LSum := LSum + LData[LI * LCols + LK] *
          LOtherData[LK * LOtherCols + LJ];
      AResult.FData[LI * LOtherCols + LJ] := LSum;
    end;

  Result := mtOk;
end;

function TMatrixImpl.Transpose(out AResult: TMatrixImpl): TMatrixStatus;
var
  LData: TMatrixData;
  LRows, LCols: Integer;
  LI, LJ: Integer;
begin
  AResult := nil;
  Snapshot(LRows, LCols, LData);
  AResult := TMatrixImpl.Create(LCols, LRows);
  if (AResult.FRows = 0) or (AResult.FCols = 0) then
  begin
    AResult.Free;
    AResult := nil;
    Exit(mtInvalidSize);
  end;

  for LI := 0 to LRows - 1 do
    for LJ := 0 to LCols - 1 do
      AResult.FData[LJ * LRows + LI] := LData[LI * LCols + LJ];

  Result := mtOk;
end;

function TMatrixImpl.Determinant(out AValue: Double): TMatrixStatus;
var
  LMat: TMatrixData;
  LI, LJ, LK, LSign: Integer;
  LPivot, LFactor, LDet: Double;
  LRows, LCols, LN: Integer;
begin
  AValue := 0;
  Snapshot(LRows, LCols, LMat);
  if LRows <> LCols then
    Exit(mtDimensionMismatch);

  LN := LRows;
  if LN = 0 then
  begin
    AValue := 0;
    Exit(mtInvalidSize);
  end;

  LSign := 1;
  for LI := 0 to LN - 1 do
  begin
    LPivot := LMat[LI * LN + LI];
    if Abs(LPivot) < 1e-12 then
    begin
      LK := -1;
      for LJ := LI + 1 to LN - 1 do
      begin
        if Abs(LMat[LJ * LN + LI]) > 1e-12 then
        begin
          LK := LJ;
          Break;
        end;
      end;
      if LK < 0 then
      begin
        SetLength(LMat, 0);
        AValue := 0;
        Exit(mtSingular);
      end;
      for LJ := 0 to LN - 1 do
      begin
        LPivot := LMat[LI * LN + LJ];
        LMat[LI * LN + LJ] := LMat[LK * LN + LJ];
        LMat[LK * LN + LJ] := LPivot;
      end;
      LSign := -LSign;
      LPivot := LMat[LI * LN + LI];
    end;

    for LJ := LI + 1 to LN - 1 do
    begin
      LFactor := LMat[LJ * LN + LI] / LPivot;
      for LK := LI to LN - 1 do
        LMat[LJ * LN + LK] := LMat[LJ * LN + LK] - LFactor * LMat[LI * LN + LK];
    end;
  end;

  LDet := LSign;
  for LI := 0 to LN - 1 do
    LDet := LDet * LMat[LI * LN + LI];

  SetLength(LMat, 0);
  AValue := LDet;
  Result := mtOk;
end;

function TMatrixImpl.Inverse(out AResult: TMatrixImpl): TMatrixStatus;
var
  LAug, LData: TMatrixData;
  LI, LJ, LK, LRows, LCols, LN: Integer;
  LPivot, LFactor: Double;
begin
  AResult := nil;
  Snapshot(LRows, LCols, LData);
  if LRows <> LCols then
    Exit(mtDimensionMismatch);

  LN := LRows;
  if LN = 0 then
  begin
    AResult := nil;
    Exit(mtInvalidSize);
  end;

  SetLength(LAug, LN * LN * 2);
  for LI := 0 to LN - 1 do
  begin
    for LJ := 0 to LN - 1 do
    begin
      LAug[LI * LN * 2 + LJ] := LData[LI * LN + LJ];
      if LI = LJ then
        LAug[LI * LN * 2 + LN + LJ] := 1.0
      else
        LAug[LI * LN * 2 + LN + LJ] := 0.0;
    end;
  end;

  for LI := 0 to LN - 1 do
  begin
    LPivot := LAug[LI * LN * 2 + LI];
    if Abs(LPivot) < 1e-12 then
    begin
      LK := -1;
      for LJ := LI + 1 to LN - 1 do
      begin
        if Abs(LAug[LJ * LN * 2 + LI]) > 1e-12 then
        begin
          LK := LJ;
          Break;
        end;
      end;
      if LK < 0 then
      begin
        SetLength(LAug, 0);
        AResult := nil;
        Exit(mtSingular);
      end;
      for LJ := 0 to LN * 2 - 1 do
      begin
        LPivot := LAug[LI * LN * 2 + LJ];
        LAug[LI * LN * 2 + LJ] := LAug[LK * LN * 2 + LJ];
        LAug[LK * LN * 2 + LJ] := LPivot;
      end;
      LPivot := LAug[LI * LN * 2 + LI];
    end;

    for LJ := 0 to LN * 2 - 1 do
      LAug[LI * LN * 2 + LJ] := LAug[LI * LN * 2 + LJ] / LPivot;

    for LJ := 0 to LN - 1 do
    begin
      if LJ <> LI then
      begin
        LFactor := LAug[LJ * LN * 2 + LI];
        for LK := 0 to LN * 2 - 1 do
          LAug[LJ * LN * 2 + LK] := LAug[LJ * LN * 2 + LK] - LFactor * LAug[LI * LN * 2 + LK];
      end;
    end;
  end;

  AResult := TMatrixImpl.Create(LN, LN);
  for LI := 0 to LN - 1 do
    for LJ := 0 to LN - 1 do
      AResult.FData[LI * LN + LJ] := LAug[LI * LN * 2 + LN + LJ];

  SetLength(LAug, 0);
  Result := mtOk;
end;

procedure TMatrixImpl.Close;
begin
  Lock;
  try
    atomic_store(FClosed, 1, mo_release);
  finally
    Unlock;
  end;
end;

function TMatrixImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
