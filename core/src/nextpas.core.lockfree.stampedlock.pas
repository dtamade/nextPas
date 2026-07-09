unit nextpas.core.lockfree.stampedlock;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

const
  STAMPED_LOCK_READ_SHIFT = 32;
  STAMPED_LOCK_READ_UNIT = Int64(1) shl STAMPED_LOCK_READ_SHIFT;
  STAMPED_LOCK_WRITE_LOCKED = Int64(-1);
  STAMPED_LOCK_READERS_MASK = Int64($FFFFFFFF00000000);

type
  TLockFreeStampedLockResult = (slLocked, slClosed, slTimeout);

  {** @desc 并发戳锁（StampedLock）
    @details 乐观读锁 + 悲观读写锁，读多写少场景比 RwLock 更高效。
      - ReadLock: 多读者并发，返回 stamp
      - WriteLock: 独占写锁，返回 stamp
      - TryOptimisticRead: 无锁乐观读，返回 stamp，使用后需 Validate
      - Unlock: 释放锁
      适用场景：读多写少、读操作很短的场景。
  }
  TStampedLock = class
  private
    FState: Int64;
    FClosed: Int32;
  public
    constructor Create;
    function ReadLock: Int64;
    function TryReadLock: Int64;
    function TryReadLockTimeout(const ATimeoutNs: Int64): Int64;
    function WriteLock: Int64;
    function TryWriteLock: Int64;
    function TryWriteLockTimeout(const ATimeoutNs: Int64): Int64;
    function TryOptimisticRead: Int64;
    function Validate(const AStamp: Int64): Boolean;
    procedure UnlockRead(const AStamp: Int64);
    procedure UnlockWrite(const AStamp: Int64);
    procedure Close;
    function IsClosed: Boolean;
    function IsReadLocked: Boolean;
    function IsWriteLocked: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

constructor TStampedLock.Create;
begin
  inherited Create;
  FState := 0;
  FClosed := 0;
end;

function TStampedLock.ReadLock: Int64;
var
  LOld, LNew: Int64;
begin
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
    begin
      Result := 0;
      Exit;
    end;
    LOld := AtomicLoad64(FState, moRelaxed);
    if LOld < 0 then
    begin
      CpuPause;
      Continue;
    end;
    LNew := LOld + STAMPED_LOCK_READ_UNIT;
    if AtomicCompareExchange64(FState, LOld, LNew, moAcqRel) = LOld then
    begin
      Result := LNew;
      Exit;
    end;
  end;
end;

function TStampedLock.TryReadLock: Int64;
var
  LOld, LNew: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(0);
  LOld := AtomicLoad64(FState, moRelaxed);
  if LOld < 0 then
    Exit(0);
  LNew := LOld + STAMPED_LOCK_READ_UNIT;
  if AtomicCompareExchange64(FState, LOld, LNew, moAcqRel) = LOld then
    Result := LNew
  else
    Result := 0;
end;

function TStampedLock.TryReadLockTimeout(const ATimeoutNs: Int64): Int64;
var
  LStart: TInstant;
  LOld, LNew: Int64;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TStampedLock.TryReadLockTimeout: timeout must be > 0');
  LStart := TInstant.Now;
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(0);
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
      Exit(0);
    LOld := AtomicLoad64(FState, moRelaxed);
    if LOld < 0 then
    begin
      CpuPause;
      Continue;
    end;
    LNew := LOld + STAMPED_LOCK_READ_UNIT;
    if AtomicCompareExchange64(FState, LOld, LNew, moAcqRel) = LOld then
    begin
      Result := LNew;
      Exit;
    end;
  end;
end;

function TStampedLock.WriteLock: Int64;
var
  LOld, LNew: Int64;
begin
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
    begin
      Result := 0;
      Exit;
    end;
    LOld := AtomicLoad64(FState, moRelaxed);
    if (LOld and $FFFFFFFF) <> 0 then
    begin
      CpuPause;
      Continue;
    end;
    LNew := (LOld + STAMPED_LOCK_READ_UNIT) or STAMPED_LOCK_WRITE_LOCKED;
    if AtomicCompareExchange64(FState, LOld, LNew, moAcqRel) = LOld then
    begin
      Result := LNew;
      Exit;
    end;
  end;
end;

function TStampedLock.TryWriteLock: Int64;
var
  LOld, LNew: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(0);
  LOld := AtomicLoad64(FState, moRelaxed);
  if (LOld and $FFFFFFFF) <> 0 then
    Exit(0);
  LNew := (LOld + STAMPED_LOCK_READ_UNIT) or STAMPED_LOCK_WRITE_LOCKED;
  if AtomicCompareExchange64(FState, LOld, LNew, moAcqRel) = LOld then
    Result := LNew
  else
    Result := 0;
end;

function TStampedLock.TryWriteLockTimeout(const ATimeoutNs: Int64): Int64;
var
  LStart: TInstant;
  LOld, LNew: Int64;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TStampedLock.TryWriteLockTimeout: timeout must be > 0');
  LStart := TInstant.Now;
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(0);
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
      Exit(0);
    LOld := AtomicLoad64(FState, moRelaxed);
    if (LOld and $FFFFFFFF) <> 0 then
    begin
      CpuPause;
      Continue;
    end;
    LNew := (LOld + STAMPED_LOCK_READ_UNIT) or STAMPED_LOCK_WRITE_LOCKED;
    if AtomicCompareExchange64(FState, LOld, LNew, moAcqRel) = LOld then
    begin
      Result := LNew;
      Exit;
    end;
  end;
end;

function TStampedLock.TryOptimisticRead: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(0);
  Result := AtomicLoad64(FState, moAcquire) and STAMPED_LOCK_READERS_MASK;
  if Result = 0 then
    Result := 1;
end;

function TStampedLock.Validate(const AStamp: Int64): Boolean;
var
  LCurrent: Int64;
begin
  if AStamp = 0 then
    Exit(False);
  LCurrent := AtomicLoad64(FState, moAcquire);
  Result := (LCurrent and STAMPED_LOCK_READERS_MASK) = (AStamp and STAMPED_LOCK_READERS_MASK);
end;

procedure TStampedLock.UnlockRead(const AStamp: Int64);
begin
  if AStamp = 0 then
    Exit;
  AtomicFetchSub64(FState, STAMPED_LOCK_READ_UNIT, moRelease);
end;

procedure TStampedLock.UnlockWrite(const AStamp: Int64);
begin
  if AStamp = 0 then
    Exit;
  AtomicFetchSub64(FState, STAMPED_LOCK_READ_UNIT + STAMPED_LOCK_WRITE_LOCKED, moRelease);
end;

procedure TStampedLock.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TStampedLock.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TStampedLock.IsReadLocked: Boolean;
var
  LState: Int64;
begin
  LState := AtomicLoad64(FState, moAcquire);
  Result := (LState > 0) and ((LState and $FFFFFFFF) = 0);
end;

function TStampedLock.IsWriteLocked: Boolean;
begin
  Result := (AtomicLoad64(FState, moAcquire) and $FFFFFFFF) <> 0;
end;

end.
