{******************************************************************************
  nextpas.core.lockfree.deque_lf

  Concurrent Deque — double-ended queue with spin-lock protection.

  Design:
  - Array-based circular buffer for O(1) push/pop at both ends
  - Spin lock for thread safety (NOT lock-free — name is historical)
  - Automatic capacity doubling when full
  - PushLeft/PushRight/PopLeft/PopRight

  Note: Despite the "lock-free" prefix (historical naming), this module uses
  a spin lock for mutual exclusion. For true lock-free deque, see collections.deque.

  2026-07-06  Phase 4
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.deque_lf;

interface

uses
  nextpas.core.errors;

const
  DEQUE_DEFAULT_CAPACITY = 64;

type
  TDequeResult = (
    dqOk,
    dqEmpty,
    dqFull
  );

  {**
   * 无锁双端队列。
   *
   * 基于循环数组实现，支持两端 O(1) 操作。
   * 使用 spin lock 保证线程安全。
   *
   * @constraints
   *   - TValue 必须是 AnsiString
   *   - 自动扩容
   *}
  {** @concurrency Thread-safe (see source for details). }
  TLockFreeDeque = class
  private
    FData: array of AnsiString;
    FCapacity: Int32;
    FHead: Int32;    { index of first element }
    FTail: Int32;    { index after last element }
    FCount: Int32;
    FLock: Int32;

    procedure Grow;
    procedure AcquireLock;
    procedure ReleaseLock;
    function IncIdx(AIdx, ADelta: Int32): Int32;
    function DecIdx(AIdx, ADelta: Int32): Int32;

  public
    constructor Create(ACapacity: Int32 = DEQUE_DEFAULT_CAPACITY);
    destructor Destroy; override;

    { 从左端推入 }
    function PushLeft(const AValue: AnsiString): TDequeResult;

    { 从右端推入 }
    function PushRight(const AValue: AnsiString): TDequeResult;

    { 从左端弹出 }
    function PopLeft(out AValue: AnsiString): TDequeResult;

    { 从右端弹出 }
    function PopRight(out AValue: AnsiString): TDequeResult;

    { 查看左端元素 }
    function PeekLeft(out AValue: AnsiString): TDequeResult;

    { 查看右端元素 }
    function PeekRight(out AValue: AnsiString): TDequeResult;

    { 元素数量 }
    function Count: Int32;

    { 检查是否为空 }
    function IsEmpty: Boolean;

    { 清空 }
    procedure Clear;
  end;

implementation

uses
  nextpas.core.mem,
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.lockfree.base;

constructor TLockFreeDeque.Create(ACapacity: Int32);
begin
  if ACapacity <= 0 then
    raise EArgumentError.Create('TLockFreeDeque: capacity must be > 0');
  inherited Create;
  FCapacity := ACapacity;
  SetLength(FData, FCapacity);
  FHead := 0;
  FTail := 0;
  FCount := 0;
  FLock := 0;
end;

destructor TLockFreeDeque.Destroy;
begin
  Clear;
  SetLength(FData, 0);
  inherited Destroy;
end;

procedure TLockFreeDeque.AcquireLock;
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

procedure TLockFreeDeque.ReleaseLock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TLockFreeDeque.IncIdx(AIdx, ADelta: Int32): Int32;
begin
  Result := (AIdx + ADelta) mod FCapacity;
end;

function TLockFreeDeque.DecIdx(AIdx, ADelta: Int32): Int32;
begin
  Result := (AIdx - ADelta + FCapacity) mod FCapacity;
end;

procedure TLockFreeDeque.Grow;
var
  LNewCap, I, LIdx: Int32;
  LNewData: array of AnsiString;
begin
  if FCapacity > High(Int32) div 2 then
    raise EOutOfMemoryError.Create(FormatAllocErrorMsg('LockFree', 'Grow', 'TLockFreeDeque.Grow: capacity overflow'));
  LNewCap := FCapacity * 2;
  SetLength(LNewData, LNewCap);
  { Copy elements in order }
  LIdx := FHead;
  for I := 0 to FCount - 1 do
  begin
    LNewData[I] := FData[LIdx];
    LIdx := IncIdx(LIdx, 1);
  end;
  SetLength(FData, 0);
  FData := LNewData;
  FCapacity := LNewCap;
  FHead := 0;
  FTail := FCount;
end;

function TLockFreeDeque.PushLeft(const AValue: AnsiString): TDequeResult;
begin
  AcquireLock;
  try
    if FCount >= FCapacity then
      Grow;
    FHead := DecIdx(FHead, 1);
    FData[FHead] := AValue;
    Inc(FCount);
    Result := dqOk;
  finally
    ReleaseLock;
  end;
end;

function TLockFreeDeque.PushRight(const AValue: AnsiString): TDequeResult;
begin
  AcquireLock;
  try
    if FCount >= FCapacity then
      Grow;
    FData[FTail] := AValue;
    FTail := IncIdx(FTail, 1);
    Inc(FCount);
    Result := dqOk;
  finally
    ReleaseLock;
  end;
end;

function TLockFreeDeque.PopLeft(out AValue: AnsiString): TDequeResult;
begin
  AcquireLock;
  try
    if FCount = 0 then
    begin
      AValue := '';
      Result := dqEmpty;
      Exit;
    end;
    AValue := FData[FHead];
    FData[FHead] := '';
    FHead := IncIdx(FHead, 1);
    Dec(FCount);
    Result := dqOk;
  finally
    ReleaseLock;
  end;
end;

function TLockFreeDeque.PopRight(out AValue: AnsiString): TDequeResult;
begin
  AcquireLock;
  try
    if FCount = 0 then
    begin
      AValue := '';
      Result := dqEmpty;
      Exit;
    end;
    FTail := DecIdx(FTail, 1);
    AValue := FData[FTail];
    FData[FTail] := '';
    Dec(FCount);
    Result := dqOk;
  finally
    ReleaseLock;
  end;
end;

function TLockFreeDeque.PeekLeft(out AValue: AnsiString): TDequeResult;
begin
  AcquireLock;
  try
    if FCount = 0 then
    begin
      AValue := '';
      Result := dqEmpty;
      Exit;
    end;
    AValue := FData[FHead];
    Result := dqOk;
  finally
    ReleaseLock;
  end;
end;

function TLockFreeDeque.PeekRight(out AValue: AnsiString): TDequeResult;
begin
  AcquireLock;
  try
    if FCount = 0 then
    begin
      AValue := '';
      Result := dqEmpty;
      Exit;
    end;
    AValue := FData[DecIdx(FTail, 1)];
    Result := dqOk;
  finally
    ReleaseLock;
  end;
end;

function TLockFreeDeque.Count: Int32;
begin
  AcquireLock;
  try
    Result := FCount;
  finally
    ReleaseLock;
  end;
end;

function TLockFreeDeque.IsEmpty: Boolean;
begin
  AcquireLock;
  try
    Result := FCount = 0;
  finally
    ReleaseLock;
  end;
end;

procedure TLockFreeDeque.Clear;
var
  I: Int32;
begin
  AcquireLock;
  try
    for I := 0 to FCapacity - 1 do
      FData[I] := '';
    FHead := 0;
    FTail := 0;
    FCount := 0;
  finally
    ReleaseLock;
  end;
end;

end.
