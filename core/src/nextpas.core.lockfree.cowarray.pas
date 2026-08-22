unit nextpas.core.lockfree.cowarray;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

type
  TLockFreeCowArrayResult = (
    cowOk,
    cowClosed,
    cowIndexOutOfRange
  );

  {** @desc 写时复制数组
    @details 读无锁，写时复制整个数组。适合读多写极少的场景。
      - 读操作：直接读取当前数组快照，无需同步
      - 写操作：复制数组 → 修改副本 → CAS 替换指针
      - 线程安全的快照语义
      - 支持索引访问、追加、替换、删除
 * @concurrency Thread-safe (see source for details).
  }
  generic TCopyOnWriteArrayImpl<T> = class
  private type
    PT = ^T;
    TItems = array of T;
    TData = record
      FItems: TItems;
      FCount: Int32;
    end;
    PData = ^TData;
    PRetiredNode = ^TRetiredNode;
    TRetiredNode = record
      Data: PData;
      Next: PRetiredNode;
    end;
  private
    FData: PData;  // current snapshot
    FClosed: Int32;
    FRetired: PRetiredNode;
    FRetiredLock: Int32;
    procedure FreeData(AData: PData);
    function CloneData(AData: PData): PData;
    procedure LockRetired;
    procedure UnlockRetired;
    procedure RetireData(AData: PData);
    procedure ReleaseRetired;
  public
    constructor Create;
    destructor Destroy; override;

    {** 获取元素（读无锁） }
    function Get(AIndex: Int32; out AValue: T): TLockFreeCowArrayResult;
    {** 获取元素数量 }
    function Count: Int32;
    {** 是否为空 }
    function IsEmpty: Boolean;
    {** 追加元素（写时复制） }
    function Append(const AValue: T): TLockFreeCowArrayResult;
    {** 替换元素（写时复制） }
    function SetItem(AIndex: Int32; const AValue: T): TLockFreeCowArrayResult;
    {** 删除指定索引的元素（写时复制） }
    function Delete(AIndex: Int32): TLockFreeCowArrayResult;
    {** 清空所有元素（写时复制） }
    procedure Clear;
    {** 关闭 }
    procedure Close;
    {** 是否已关闭 }
    function IsClosed: Boolean;
    {** 快照：返回当前数组的副本 }
    function Snapshot: TItems;
  end;

implementation

uses
  nextpas.core.errors;

procedure TCopyOnWriteArrayImpl.FreeData(AData: PData);
begin
  if AData <> nil then
    SetLength(AData^.FItems, 0);
  Dispose(AData);
end;

function TCopyOnWriteArrayImpl.CloneData(AData: PData): PData;
var
  I: Int32;
begin
  New(Result);
  Result^.FCount := AData^.FCount;
  SetLength(Result^.FItems, Result^.FCount);
  for I := 0 to Result^.FCount - 1 do
    Result^.FItems[I] := AData^.FItems[I];
end;

constructor TCopyOnWriteArrayImpl.Create;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TCopyOnWriteArray: T must be unmanaged (no string/interface/dynarray)');
  inherited Create;
  New(FData);
  FData^.FCount := 0;
  SetLength(FData^.FItems, 0);
  FClosed := 0;
  FRetired := nil;
  FRetiredLock := 0;
end;

destructor TCopyOnWriteArrayImpl.Destroy;
begin
  FreeData(FData);
  ReleaseRetired;
  inherited Destroy;
end;

procedure TCopyOnWriteArrayImpl.LockRetired;
var
  LCasExpected: Int32;
begin
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FRetiredLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    ThreadSwitch;
  end;
end;

procedure TCopyOnWriteArrayImpl.UnlockRetired;
begin
  atomic_store(FRetiredLock, 0, mo_release);
end;

procedure TCopyOnWriteArrayImpl.RetireData(AData: PData);
var
  LNode: PRetiredNode;
begin
  if AData = nil then
    Exit;
  New(LNode);
  LNode^.Data := AData;
  LockRetired;
  try
    LNode^.Next := FRetired;
    FRetired := LNode;
  finally
    UnlockRetired;
  end;
end;

procedure TCopyOnWriteArrayImpl.ReleaseRetired;
var
  LNode, LNext: PRetiredNode;
begin
  LockRetired;
  try
    LNode := FRetired;
    FRetired := nil;
  finally
    UnlockRetired;
  end;

  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    FreeData(LNode^.Data);
    Dispose(LNode);
    LNode := LNext;
  end;
end;

function TCopyOnWriteArrayImpl.Get(AIndex: Int32; out AValue: T): TLockFreeCowArrayResult;
var
  LData: PData;
begin
  LData := PData(atomic_load(PPointer(@FData)^, mo_acquire));
  if (AIndex < 0) or (AIndex >= LData^.FCount) then
    Exit(cowIndexOutOfRange);
  AValue := LData^.FItems[AIndex];
  Result := cowOk;
end;

function TCopyOnWriteArrayImpl.Count: Int32;
begin
  Result := PData(atomic_load(PPointer(@FData)^, mo_acquire))^.FCount;
end;

function TCopyOnWriteArrayImpl.IsEmpty: Boolean;
begin
  Result := PData(atomic_load(PPointer(@FData)^, mo_acquire))^.FCount = 0;
end;

function TCopyOnWriteArrayImpl.Append(const AValue: T): TLockFreeCowArrayResult;
var
  LOld, LNew: PData;
  LExpected: Pointer;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(cowClosed);
  repeat
    LOld := PData(atomic_load(PPointer(@FData)^, mo_acquire));
    LNew := CloneData(LOld);
    LNew^.FCount := LOld^.FCount + 1;
    SetLength(LNew^.FItems, LNew^.FCount);
    LNew^.FItems[LNew^.FCount - 1] := AValue;
    LExpected := LOld;
    if atomic_compare_exchange_strong(PPointer(@FData)^, LExpected, Pointer(LNew), mo_acq_rel, mo_acquire) then
      Break;
    FreeData(LNew);
  until False;
  RetireData(LOld);
  Result := cowOk;
end;

function TCopyOnWriteArrayImpl.SetItem(AIndex: Int32; const AValue: T): TLockFreeCowArrayResult;
var
  LOld, LNew: PData;
  LExpected: Pointer;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(cowClosed);
  repeat
    LOld := PData(atomic_load(PPointer(@FData)^, mo_acquire));
    if (AIndex < 0) or (AIndex >= LOld^.FCount) then
      Exit(cowIndexOutOfRange);
    LNew := CloneData(LOld);
    LNew^.FItems[AIndex] := AValue;
    LExpected := LOld;
    if atomic_compare_exchange_strong(PPointer(@FData)^, LExpected, Pointer(LNew), mo_acq_rel, mo_acquire) then
      Break;
    FreeData(LNew);
  until False;
  RetireData(LOld);
  Result := cowOk;
end;

function TCopyOnWriteArrayImpl.Delete(AIndex: Int32): TLockFreeCowArrayResult;
var
  LOld, LNew: PData;
  LExpected: Pointer;
  I: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(cowClosed);
  repeat
    LOld := PData(atomic_load(PPointer(@FData)^, mo_acquire));
    if (AIndex < 0) or (AIndex >= LOld^.FCount) then
      Exit(cowIndexOutOfRange);
    New(LNew);
    LNew^.FCount := LOld^.FCount - 1;
    SetLength(LNew^.FItems, LNew^.FCount);
    // Copy elements before deleted index
    for I := 0 to AIndex - 1 do
      LNew^.FItems[I] := LOld^.FItems[I];
    // Copy elements after deleted index
    for I := AIndex to LNew^.FCount - 1 do
      LNew^.FItems[I] := LOld^.FItems[I + 1];
    LExpected := LOld;
    if atomic_compare_exchange_strong(PPointer(@FData)^, LExpected, Pointer(LNew), mo_acq_rel, mo_acquire) then
      Break;
    FreeData(LNew);
  until False;
  RetireData(LOld);
  Result := cowOk;
end;

procedure TCopyOnWriteArrayImpl.Clear;
var
  LOld, LNew: PData;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit;
  New(LNew);
  LNew^.FCount := 0;
  SetLength(LNew^.FItems, 0);
  LOld := PData(atomic_exchange(PPointer(@FData)^, Pointer(LNew), mo_acq_rel));
  RetireData(LOld);
end;

procedure TCopyOnWriteArrayImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TCopyOnWriteArrayImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TCopyOnWriteArrayImpl.Snapshot: TItems;
var
  LData: PData;
  I: Int32;
begin
  LData := PData(atomic_load(PPointer(@FData)^, mo_acquire));
  Result := nil;
  SetLength(Result, LData^.FCount);
  for I := 0 to LData^.FCount - 1 do
    Result[I] := LData^.FItems[I];
end;

end.
