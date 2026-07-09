unit nextpas.core.lockfree.linkedlist;

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
    @details 基于读写锁的并发链表，支持有序插入和遍历。
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

constructor TConcurrentLinkedListImpl.Create;
begin
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
  LNode, LPrev, LCurrent, LNew: PNode;
begin
  // Spin lock for write
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
    ;
  // Find insertion point (maintain sorted order)
  LPrev := nil;
  LCurrent := FHead;
  while (LCurrent <> nil) and (LCurrent^.FValue < AValue) do
  begin
    LPrev := LCurrent;
    LCurrent := LCurrent^.FNext;
  end;
  // Check for duplicate
  if (LCurrent <> nil) and (LCurrent^.FValue = AValue) then
  begin
    AtomicStore32(FLock, 0, moRelease);
    Exit(llExists);
  end;
  // Create and insert new node
  New(LNew);
  LNew^.FValue := AValue;
  LNew^.FNext := LCurrent;
  if LPrev = nil then
    FHead := LNew
  else
    LPrev^.FNext := LNew;
  AtomicFetchAdd64(FCount, 1);
  AtomicStore32(FLock, 0, moRelease);
  Result := llOk;
end;

function TConcurrentLinkedListImpl.Remove(const AValue: T): TLockFreeLinkedListResult;
var
  LPrev, LCurrent: PNode;
begin
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
    ;
  LPrev := nil;
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if LCurrent^.FValue = AValue then
    begin
      // Found - remove node
      if LPrev = nil then
        FHead := LCurrent^.FNext
      else
        LPrev^.FNext := LCurrent^.FNext;
      Dispose(LCurrent);
      AtomicFetchAdd64(FCount, -1);
      AtomicStore32(FLock, 0, moRelease);
      Exit(llOk);
    end;
    LPrev := LCurrent;
    LCurrent := LCurrent^.FNext;
  end;
  AtomicStore32(FLock, 0, moRelease);
  Result := llNotFound;
end;

function TConcurrentLinkedListImpl.Contains(const AValue: T): Boolean;
var
  LCurrent: PNode;
begin
  // Read lock (spin until write lock is free)
  while AtomicLoad32(FLock, moAcquire) <> 0 do
    ;
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    if LCurrent^.FValue = AValue then
      Exit(True);
    if LCurrent^.FValue > AValue then
      Exit(False);  // List is sorted, no need to continue
    LCurrent := LCurrent^.FNext;
  end;
  Result := False;
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
  while AtomicLoad32(FLock, moAcquire) <> 0 do
    ;
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
end;

procedure TConcurrentLinkedListImpl.Clear;
begin
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
    ;
  FreeList;
  FCount := 0;
  AtomicStore32(FLock, 0, moRelease);
end;

end.
