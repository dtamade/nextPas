unit nextpas.core.lockfree.linkedlist;
{**
 * @desc Concurrent Linked List with per-list spin lock.
 *
 * @details Ordered linked list with spin lock protection:
 *   - Insert: ordered insertion (maintains ascending order)
 *   - Remove: delete specified value
 *   - Contains: check if value exists
 *   - ForEach: iterate all elements
 *
 * @concurrency Thread-safe for multiple readers and writers:
 *   - Contains/ForEach: shared read access
 *   - Insert/Remove/Clear: exclusive write lock
 *
 * @see Linked List — dynamic ordered collection
 * @see Concurrent collections — thread-safe list implementations
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

type
  TLockFreeLinkedListResult = (
    llOk,
    llNotFound,
    llExists,
    llClosed
  );

  TForEachCallback = procedure(AIdx: Int32; const AValue: Pointer);

  {** @desc 并发链表
    @details 基于自旋锁的并发链表，支持有序插入和遍历。
      - Insert: 有序插入（保持升序）
      - Remove: 删除指定值
      - Contains: 查找是否包含
      - ForEach: 遍历所有元素
      - 适用场景：有序列表、事件队列、消息队列
  }
  generic TConcurrentLinkedListImpl<T> = class
  private type
    PNode = ^TNode;
    TNode = record
      FValue: T;
      FNext: PNode;
    end;
  private
    FHead: PNode;
    FCount: Int64;
    FLock: Int32;

    procedure FreeList;
    procedure LockList;
    procedure UnlockList;
  public
    constructor Create;
    destructor Destroy; override;

    {** 有序插入（保持升序） }
    function Insert(const AValue: T): TLockFreeLinkedListResult;
    {** 删除指定值 }
    function Remove(const AValue: T): TLockFreeLinkedListResult;
    {** 是否包含指定值 }
    function Contains(const AValue: T): Boolean;
    {** 元素数量 }
    function Count: Int64;
    {** 是否为空 }
    function IsEmpty: Boolean;
    {** 获取指定索引的元素 }
    function Get(AIndex: Int32; out AValue: T): Boolean;
    {** 清空所有元素 }
    procedure Clear;
  end;

implementation

uses
  nextpas.core.errors;

procedure TConcurrentLinkedListImpl.FreeList;
var
  LNode, LNext: PNode;
begin
  LNode := FHead;
  while LNode <> nil do
  begin
    LNext := LNode^.FNext;
    Dispose(LNode);
    LNode := LNext;
  end;
  FHead := nil;
end;

procedure TConcurrentLinkedListImpl.LockList;
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
    end
    else
      CpuPause;
  end;
end;

procedure TConcurrentLinkedListImpl.UnlockList;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

constructor TConcurrentLinkedListImpl.Create;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TConcurrentLinkedList: T must be unmanaged (no string/interface/dynarray)');
  inherited Create;
  FHead := nil;
  FCount := 0;
  FLock := 0;
end;

destructor TConcurrentLinkedListImpl.Destroy;
begin
  FreeList;
  inherited Destroy;
end;

function TConcurrentLinkedListImpl.Insert(const AValue: T): TLockFreeLinkedListResult;
var
  LPrev, LCurrent, LNew: PNode;
begin
  LockList;
  try
    LPrev := nil;
    LCurrent := FHead;
    while (LCurrent <> nil) and (LCurrent^.FValue < AValue) do
    begin
      LPrev := LCurrent;
      LCurrent := LCurrent^.FNext;
    end;
    if (LCurrent <> nil) and (LCurrent^.FValue = AValue) then
      Exit(llExists);
    New(LNew);
    LNew^.FValue := AValue;
    LNew^.FNext := LCurrent;
    if LPrev = nil then
      FHead := LNew
    else
      LPrev^.FNext := LNew;
    AtomicFetchAdd64(FCount, 1);
    Result := llOk;
  finally
    UnlockList;
  end;
end;

function TConcurrentLinkedListImpl.Remove(const AValue: T): TLockFreeLinkedListResult;
var
  LPrev, LCurrent: PNode;
begin
  LockList;
  try
    LPrev := nil;
    LCurrent := FHead;
    while LCurrent <> nil do
    begin
      if LCurrent^.FValue = AValue then
      begin
        if LPrev = nil then
          FHead := LCurrent^.FNext
        else
          LPrev^.FNext := LCurrent^.FNext;
        Dispose(LCurrent);
        AtomicFetchAdd64(FCount, -1);
        Exit(llOk);
      end;
      LPrev := LCurrent;
      LCurrent := LCurrent^.FNext;
    end;
    Result := llNotFound;
  finally
    UnlockList;
  end;
end;

function TConcurrentLinkedListImpl.Contains(const AValue: T): Boolean;
var
  LCurrent: PNode;
begin
  LockList;
  try
    LCurrent := FHead;
    while LCurrent <> nil do
    begin
      if LCurrent^.FValue = AValue then
        Exit(True);
      if LCurrent^.FValue > AValue then
        Exit(False);
      LCurrent := LCurrent^.FNext;
    end;
    Result := False;
  finally
    UnlockList;
  end;
end;

function TConcurrentLinkedListImpl.Count: Int64;
begin
  Result := AtomicLoad64(FCount, moRelaxed);
end;

function TConcurrentLinkedListImpl.IsEmpty: Boolean;
begin
  Result := AtomicLoad64(FCount, moRelaxed) = 0;
end;

function TConcurrentLinkedListImpl.Get(AIndex: Int32; out AValue: T): Boolean;
var
  LCurrent: PNode;
  I: Int32;
begin
  AValue := Default(T);
  if AIndex < 0 then
    Exit(False);
  LockList;
  try
    LCurrent := FHead;
    I := 0;
    while LCurrent <> nil do
    begin
      if I = AIndex then
      begin
        AValue := LCurrent^.FValue;
        Exit(True);
      end;
      Inc(I);
      LCurrent := LCurrent^.FNext;
    end;
    Result := False;
  finally
    UnlockList;
  end;
end;

procedure TConcurrentLinkedListImpl.Clear;
begin
  LockList;
  try
    FreeList;
    AtomicStore64(FCount, 0, moRelease);
  finally
    UnlockList;
  end;
end;

end.
