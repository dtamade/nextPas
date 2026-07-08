unit nextpas.core.lockfree.sortedset;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

type
  TLockFreeSortedSetResult = (
    ssetOk,
    ssetNotFound,
    ssetExists
  );

  {** @desc 并发有序集合
    @details 基于有序数组实现的并发有序集合。
      - 支持 Insert/Remove/Contains/Count
      - 有序存储，二分查找
      - 写时复制，读无锁
      - 适用场景：排行榜、时间线索引、小规模有序集合
  }
  generic TConcurrentSortedSetImpl<T> = class
  private type
    TItems = array of T;
    TData = record
      FItems: TItems;
      FCount: Int32;
    end;
    PData = ^TData;
  private
    FData: PData;
    FLock: Int32;

    procedure FreeData(AData: PData);
    function BinarySearch(AData: PData; const AValue: T; out AIdx: Int32): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    {** 插入元素（如果已存在则忽略） }
    function Insert(const AValue: T): TLockFreeSortedSetResult;
    {** 删除元素 }
    function Remove(const AValue: T): TLockFreeSortedSetResult;
    {** 是否包含元素 }
    function Contains(const AValue: T): Boolean;
    {** 元素数量 }
    function Count: Int32;
    {** 是否为空 }
    function IsEmpty: Boolean;
  end;

implementation

procedure TConcurrentSortedSetImpl.FreeData(AData: PData);
begin
  if AData <> nil then
    SetLength(AData^.FItems, 0);
  Dispose(AData);
end;

function TConcurrentSortedSetImpl.BinarySearch(AData: PData; const AValue: T; out AIdx: Int32): Boolean;
var
  L, R, M: Int32;
begin
  Result := False;
  L := 0;
  R := AData^.FCount - 1;
  while L <= R do
  begin
    M := (L + R) div 2;
    if AData^.FItems[M] = AValue then
    begin
      AIdx := M;
      Exit(True);
    end
    else if AData^.FItems[M] < AValue then
      L := M + 1
    else
      R := M - 1;
  end;
  AIdx := L;
end;

constructor TConcurrentSortedSetImpl.Create;
begin
  inherited Create;
  New(FData);
  FData^.FCount := 0;
  SetLength(FData^.FItems, 0);
  FLock := 0;
end;

destructor TConcurrentSortedSetImpl.Destroy;
begin
  FreeData(FData);
  inherited Destroy;
end;

function TConcurrentSortedSetImpl.Insert(const AValue: T): TLockFreeSortedSetResult;
var
  LOld, LNew: PData;
  LIdx, I: Int32;
begin
  // Spin lock for write
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
    ;
  LOld := PData(AtomicLoadPtr(Pointer(FData), moAcquire));
  if BinarySearch(LOld, AValue, LIdx) then
  begin
    AtomicStore32(FLock, 0, moRelease);
    Exit(ssetExists);
  end;
  // Create new snapshot
  New(LNew);
  LNew^.FCount := LOld^.FCount + 1;
  SetLength(LNew^.FItems, LNew^.FCount);
  // Copy before insertion point
  for I := 0 to LIdx - 1 do
    LNew^.FItems[I] := LOld^.FItems[I];
  // Insert new element
  LNew^.FItems[LIdx] := AValue;
  // Copy after insertion point
  for I := LIdx + 1 to LNew^.FCount - 1 do
    LNew^.FItems[I] := LOld^.FItems[I - 1];
  // Swap
  AtomicStorePtr(Pointer(FData), LNew, moRelease);
  FreeData(LOld);
  AtomicStore32(FLock, 0, moRelease);
  Result := ssetOk;
end;

function TConcurrentSortedSetImpl.Remove(const AValue: T): TLockFreeSortedSetResult;
var
  LOld, LNew: PData;
  LIdx, I: Int32;
begin
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
    ;
  LOld := PData(AtomicLoadPtr(Pointer(FData), moAcquire));
  if not BinarySearch(LOld, AValue, LIdx) then
  begin
    AtomicStore32(FLock, 0, moRelease);
    Exit(ssetNotFound);
  end;
  // Create new snapshot without the element
  New(LNew);
  LNew^.FCount := LOld^.FCount - 1;
  SetLength(LNew^.FItems, LNew^.FCount);
  for I := 0 to LIdx - 1 do
    LNew^.FItems[I] := LOld^.FItems[I];
  for I := LIdx to LNew^.FCount - 1 do
    LNew^.FItems[I] := LOld^.FItems[I + 1];
  AtomicStorePtr(Pointer(FData), LNew, moRelease);
  FreeData(LOld);
  AtomicStore32(FLock, 0, moRelease);
  Result := ssetOk;
end;

function TConcurrentSortedSetImpl.Contains(const AValue: T): Boolean;
var
  LData: PData;
  LIdx: Int32;
begin
  LData := PData(AtomicLoadPtr(Pointer(FData), moAcquire));
  Result := BinarySearch(LData, AValue, LIdx);
end;

function TConcurrentSortedSetImpl.Count: Int32;
begin
  Result := PData(AtomicLoadPtr(Pointer(FData), moAcquire))^.FCount;
end;

function TConcurrentSortedSetImpl.IsEmpty: Boolean;
begin
  Result := PData(AtomicLoadPtr(Pointer(FData), moAcquire))^.FCount = 0;
end;

end.
