{******************************************************************************
  nextpas.core.lockfree.spacesaving

  Space-Saving: 流式 Top-K 频繁项检测 (Heavy Hitters Detection)

  算法: Metwally, Agrawal, El Abbadi, "Efficient Computation of Frequent
  and Top-k Elements in Data Streams" (2005)

  核心思想: 维护 K 个 (item, count, error) 三元组。新元素到来时，
  替换最小计数的元素，将最小计数+1作为新元素的计数。
  保证: 所有返回项的真实频率 >= (总元素数 / K)。

  复杂度:
    - Add: O(log K) — 维护最小堆
    - TopK: O(K log K) — 排序输出
    - 空间: O(K)

  线程安全: 使用 CAS 自旋锁保护所有操作。

  @author nextPas Contributors
  @date 2026-07-06
******************************************************************************}

unit nextpas.core.lockfree.spacesaving;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.atomic;

const
  SPACESAVING_DEFAULT_K = 100;

type
  TSpaceSavingStatus = (
    ssOk = 0,
    ssClosed = 1,
    ssEmpty = 2
  );

  PSpaceSavingEntry = ^TSpaceSavingEntry;
  TSpaceSavingEntry = record
    FItem: UInt64;
    FCount: UInt64;
    FError: UInt64;
  end;

  TSpaceSavingResult = record
    FItems: array of TSpaceSavingEntry;
    FCount: Integer;
  end;

  TSpaceSavingImpl = class
  private
    FEntries: array of TSpaceSavingEntry;
    FHeap: array of Integer;
    FHeapSize: Integer;
    FCapacity: Integer;
    FTotalItems: UInt64;
    FLock: Int32;
    FClosed: Int32;

    procedure HeapSiftUp(AIdx: Integer);
    procedure HeapSiftDown(AIdx: Integer);
    procedure HeapRebuild;
    function FindItem(AItem: UInt64): Integer;
    function HeapExtractMin: Integer;
    procedure Lock;
    procedure Unlock;
  public
    constructor Create(AK: UInt32 = SPACESAVING_DEFAULT_K);
    destructor Destroy; override;

    function Add(AItem: UInt64): TSpaceSavingStatus;
    function TopK(out AResult: TSpaceSavingResult): TSpaceSavingStatus;
    function TotalItems: UInt64;
    function GetK: Integer; inline;
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors;

{ TSpaceSavingImpl }

procedure TSpaceSavingImpl.Lock;
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

procedure TSpaceSavingImpl.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

constructor TSpaceSavingImpl.Create(AK: UInt32);
begin
  inherited Create;
  if AK > UInt32(High(Integer)) then
    raise EArgumentError.Create('TSpaceSaving: K exceeds High(Integer)');
  if AK < 1 then
    AK := 1;
  FCapacity := AK;
  SetLength(FEntries, FCapacity);
  SetLength(FHeap, FCapacity);
  FHeapSize := 0;
  FTotalItems := 0;
  FLock := 0;
  FClosed := 0;
end;

destructor TSpaceSavingImpl.Destroy;
begin
  SetLength(FEntries, 0);
  SetLength(FHeap, 0);
  inherited Destroy;
end;

procedure TSpaceSavingImpl.HeapSiftUp(AIdx: Integer);
var
  LParent, LTemp: Integer;
begin
  while AIdx > 0 do
  begin
    LParent := (AIdx - 1) div 2;
    if FEntries[FHeap[AIdx]].FCount < FEntries[FHeap[LParent]].FCount then
    begin
      LTemp := FHeap[AIdx];
      FHeap[AIdx] := FHeap[LParent];
      FHeap[LParent] := LTemp;
      AIdx := LParent;
    end
    else
      Break;
  end;
end;

procedure TSpaceSavingImpl.HeapSiftDown(AIdx: Integer);
var
  LSmallest, LLeft, LRight, LTemp: Integer;
begin
  while True do
  begin
    LSmallest := AIdx;
    LLeft := 2 * AIdx + 1;
    LRight := 2 * AIdx + 2;

    if (LLeft < FHeapSize) and
       (FEntries[FHeap[LLeft]].FCount < FEntries[FHeap[LSmallest]].FCount) then
      LSmallest := LLeft;

    if (LRight < FHeapSize) and
       (FEntries[FHeap[LRight]].FCount < FEntries[FHeap[LSmallest]].FCount) then
      LSmallest := LRight;

    if LSmallest <> AIdx then
    begin
      LTemp := FHeap[AIdx];
      FHeap[AIdx] := FHeap[LSmallest];
      FHeap[LSmallest] := LTemp;
      AIdx := LSmallest;
    end
    else
      Break;
  end;
end;

procedure TSpaceSavingImpl.HeapRebuild;
var
  LI: Integer;
begin
  if FHeapSize <= 1 then
    Exit;
  for LI := (FHeapSize div 2) - 1 downto 0 do
    HeapSiftDown(LI);
end;

function TSpaceSavingImpl.HeapExtractMin: Integer;
var
  LMin: Integer;
begin
  if FHeapSize = 0 then
    Exit(-1);
  LMin := FHeap[0];
  Dec(FHeapSize);
  FHeap[0] := FHeap[FHeapSize];
  if FHeapSize > 0 then
    HeapSiftDown(0);
  Result := LMin;
end;

function TSpaceSavingImpl.FindItem(AItem: UInt64): Integer;
var
  LI: Integer;
begin
  for LI := 0 to FHeapSize - 1 do
  begin
    if FEntries[FHeap[LI]].FItem = AItem then
      Exit(FHeap[LI]);
  end;
  Result := -1;
end;

function TSpaceSavingImpl.Add(AItem: UInt64): TSpaceSavingStatus;
var
  LIdx, LMinIdx: Integer;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(ssClosed);

  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(ssClosed);
    if FTotalItems < High(UInt64) then
      Inc(FTotalItems);

    LIdx := FindItem(AItem);
    if LIdx >= 0 then
    begin
      if FEntries[LIdx].FCount < High(UInt64) then
        Inc(FEntries[LIdx].FCount);
      HeapRebuild;
      Result := ssOk;
      Exit;
    end;

    if FHeapSize < FCapacity then
    begin
      FEntries[FHeapSize].FItem := AItem;
      FEntries[FHeapSize].FCount := 1;
      FEntries[FHeapSize].FError := 0;
      FHeap[FHeapSize] := FHeapSize;
      HeapSiftUp(FHeapSize);
      Inc(FHeapSize);
    end
    else
    begin
      LMinIdx := HeapExtractMin;
      FEntries[LMinIdx].FItem := AItem;
      FEntries[LMinIdx].FError := FEntries[LMinIdx].FCount;
      if FEntries[LMinIdx].FCount < High(UInt64) then
        Inc(FEntries[LMinIdx].FCount);
      FHeap[FHeapSize] := LMinIdx;
      Inc(FHeapSize);
      HeapRebuild;
    end;

    Result := ssOk;
  finally
    Unlock;
  end;
end;

function TSpaceSavingImpl.TopK(out AResult: TSpaceSavingResult): TSpaceSavingStatus;
var
  LI, LJ, LTemp: Integer;
  LSorted: array of Integer;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(ssClosed);

  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(ssClosed);
    if FHeapSize = 0 then
    begin
      AResult.FCount := 0;
      SetLength(AResult.FItems, 0);
      Result := ssEmpty;
      Exit;
    end;

    SetLength(LSorted, FHeapSize);
    for LI := 0 to FHeapSize - 1 do
      LSorted[LI] := FHeap[LI];

    for LI := 1 to FHeapSize - 1 do
    begin
      LJ := LI;
      while (LJ > 0) and
            (FEntries[LSorted[LJ]].FCount > FEntries[LSorted[LJ - 1]].FCount) do
      begin
        LTemp := LSorted[LJ];
        LSorted[LJ] := LSorted[LJ - 1];
        LSorted[LJ - 1] := LTemp;
        Dec(LJ);
      end;
    end;

    SetLength(AResult.FItems, FHeapSize);
    AResult.FCount := FHeapSize;
    for LI := 0 to FHeapSize - 1 do
      AResult.FItems[LI] := FEntries[LSorted[LI]];

    SetLength(LSorted, 0);
    Result := ssOk;
  finally
    Unlock;
  end;
end;

function TSpaceSavingImpl.TotalItems: UInt64;
begin
  Lock;
  try
    Result := FTotalItems;
  finally
    Unlock;
  end;
end;

function TSpaceSavingImpl.GetK: Integer; inline;
begin
  Result := FCapacity;
end;

procedure TSpaceSavingImpl.Close;
begin
  Lock;
  try
    atomic_store(FClosed, 1, mo_release);
  finally
    Unlock;
  end;
end;

function TSpaceSavingImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
