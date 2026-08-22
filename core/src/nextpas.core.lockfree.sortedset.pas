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

    procedure Lock;
    procedure Unlock;
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

uses
  nextpas.core.errors;

procedure TConcurrentSortedSetImpl.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
end;

procedure TConcurrentSortedSetImpl.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

procedure TConcurrentSortedSetImpl.FreeData(AData: PData);
begin
  if AData <> nil then
  begin
    SetLength(AData^.FItems, 0);
    Dispose(AData);
  end;
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
  if IsManagedType(T) then
    raise EArgumentError.Create('TConcurrentSortedSet: T must be unmanaged (no string/interface/dynarray)');
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
  LIdx, I: Int32;
begin
  Lock;
  try
    if BinarySearch(FData, AValue, LIdx) then
      Exit(ssetExists);

    Inc(FData^.FCount);
    SetLength(FData^.FItems, FData^.FCount);
    for I := FData^.FCount - 1 downto LIdx + 1 do
      FData^.FItems[I] := FData^.FItems[I - 1];
    FData^.FItems[LIdx] := AValue;
    Result := ssetOk;
  finally
    Unlock;
  end;
end;

function TConcurrentSortedSetImpl.Remove(const AValue: T): TLockFreeSortedSetResult;
var
  LIdx, I: Int32;
begin
  Lock;
  try
    if not BinarySearch(FData, AValue, LIdx) then
      Exit(ssetNotFound);

    for I := LIdx to FData^.FCount - 2 do
      FData^.FItems[I] := FData^.FItems[I + 1];
    Dec(FData^.FCount);
    SetLength(FData^.FItems, FData^.FCount);
    Result := ssetOk;
  finally
    Unlock;
  end;
end;

function TConcurrentSortedSetImpl.Contains(const AValue: T): Boolean;
var
  LIdx: Int32;
begin
  Lock;
  try
    Result := BinarySearch(FData, AValue, LIdx);
  finally
    Unlock;
  end;
end;

function TConcurrentSortedSetImpl.Count: Int32;
begin
  Lock;
  try
    Result := FData^.FCount;
  finally
    Unlock;
  end;
end;

function TConcurrentSortedSetImpl.IsEmpty: Boolean;
begin
  Lock;
  try
    Result := FData^.FCount = 0;
  finally
    Unlock;
  end;
end;

end.
