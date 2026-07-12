unit nextpas.core.lockfree.fenwick;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TFenwickResult = (fwOk, fwOutOfBounds, fwClosed);

  {** @desc 并发 Fenwick 树 (二叉索引树)
    @details 支持 O(log n) 前缀和查询和单点更新。
      适用于统计、排名、频率计数等场景。
 * @concurrency Thread-safe (see source for details).
  }
  TConcurrentFenwickTree = class
  private
    FData: array of Int64;
    FSize: Int32;
    FClosed: Int32;
    FLock: Int32;
    procedure Lock;
    procedure Unlock;
    function LowBit(AValue: Int32): Int32;
  public
    constructor Create(ASize: Int32);
    destructor Destroy; override;
    function Update(AIndex: Int32; ADelta: Int64): TFenwickResult;
    function PrefixSum(AIndex: Int32; out ASum: Int64): TFenwickResult;
    function RangeSum(ALeft, ARight: Int32; out ASum: Int64): TFenwickResult;
    function GetValue(AIndex: Int32; out AValue: Int64): TFenwickResult;
    function GetSize: Int32; inline;
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TConcurrentFenwickTree.Create(ASize: Int32);
begin
  if ASize <= 0 then
    raise EArgumentError.Create('TConcurrentFenwickTree: size must be > 0');
  inherited Create;
  FSize := ASize;
  FClosed := 0;
  FLock := 0;
  SetLength(FData, ASize + 1);
end;

destructor TConcurrentFenwickTree.Destroy;
begin
  FData := nil;
  inherited Destroy;
end;

procedure TConcurrentFenwickTree.Lock;
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
  begin
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end;
  end;
end;

procedure TConcurrentFenwickTree.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TConcurrentFenwickTree.LowBit(AValue: Int32): Int32;
begin
  Result := AValue and (-AValue);
end;

function TConcurrentFenwickTree.Update(AIndex: Int32; ADelta: Int64): TFenwickResult;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(fwClosed);
  if (AIndex < 1) or (AIndex > FSize) then
    Exit(fwOutOfBounds);
  Lock;
  try
    while AIndex <= FSize do
    begin
      FData[AIndex] := FData[AIndex] + ADelta;
      AIndex := AIndex + LowBit(AIndex);
    end;
  finally
    Unlock;
  end;
  Result := fwOk;
end;

function TConcurrentFenwickTree.PrefixSum(AIndex: Int32; out ASum: Int64): TFenwickResult;
var
  LSum: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
  begin
    ASum := 0;
    Exit(fwClosed);
  end;
  if (AIndex < 0) or (AIndex > FSize) then
  begin
    ASum := 0;
    Exit(fwOutOfBounds);
  end;
  LSum := 0;
  Lock;
  try
    while AIndex > 0 do
    begin
      LSum := LSum + FData[AIndex];
      AIndex := AIndex - LowBit(AIndex);
    end;
  finally
    Unlock;
  end;
  ASum := LSum;
  Result := fwOk;
end;

function TConcurrentFenwickTree.RangeSum(ALeft, ARight: Int32; out ASum: Int64): TFenwickResult;
var
  LLeftSum, LRightSum: Int64;
  LRes: TFenwickResult;
begin
  if ALeft > ARight then
  begin
    ASum := 0;
    Exit(fwOutOfBounds);
  end;
  LRes := PrefixSum(ARight, LRightSum);
  if LRes <> fwOk then
  begin
    ASum := 0;
    Exit(LRes);
  end;
  LRes := PrefixSum(ALeft - 1, LLeftSum);
  if LRes <> fwOk then
  begin
    ASum := 0;
    Exit(LRes);
  end;
  ASum := LRightSum - LLeftSum;
  Result := fwOk;
end;

function TConcurrentFenwickTree.GetValue(AIndex: Int32; out AValue: Int64): TFenwickResult;
var
  LSum1, LSum2: Int64;
begin
  if (AIndex < 1) or (AIndex > FSize) then
  begin
    AValue := 0;
    Exit(fwOutOfBounds);
  end;
  PrefixSum(AIndex, LSum1);
  PrefixSum(AIndex - 1, LSum2);
  AValue := LSum1 - LSum2;
  Result := fwOk;
end;

function TConcurrentFenwickTree.GetSize: Int32; inline;
begin
  Result := FSize;
end;

procedure TConcurrentFenwickTree.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentFenwickTree.IsClosed: Boolean; inline;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
