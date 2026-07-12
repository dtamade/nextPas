unit nextpas.core.lockfree.stampedlock;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

const
  STAMPED_LOCK_READ_SHIFT = 32;
  STAMPED_LOCK_READ_UNIT = Int64(1) shl STAMPED_LOCK_READ_SHIFT;
  STAMPED_LOCK_WRITE_BIT = Int64(1);
  STAMPED_LOCK_VERSION_MASK = Int64($FFFFFFFF);
  STAMPED_LOCK_READERS_MASK = not STAMPED_LOCK_VERSION_MASK;

type
  TLockFreeStampedLockResult = (slLocked, slClosed, slTimeout);

  {** @desc 并发戳锁（StampedLock）
    @details 乐观读锁 + 悲观读写锁，读多写少场景比 RwLock 更高效。
      - ReadLock: 多读者并发，返回 stamp
      - WriteLock: 独占写锁，返回 stamp
      - TryOptimisticRead: 无锁乐观读，返回 stamp，使用后需 Validate
      - Unlock: 释放锁
      适用场景：读多写少、读操作很短的场景。
 * @concurrency Thread-safe (see source for details).
  }
  TStampedLock = class
  private
    FState: Int64;
    FClosed: Int32;
  public
    constructor Create;
    destructor Destroy; override;
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
    function IsClosed: Boolean; inline;
    function IsReadLocked: Boolean; inline;
    function IsWriteLocked: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

constructor TStampedLock.Create;
begin
  inherited Create;
  FState := 2;
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
    if (LOld and STAMPED_LOCK_WRITE_BIT) <> 0 then
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
  if (LOld and STAMPED_LOCK_WRITE_BIT) <> 0 then
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
    if (LOld and STAMPED_LOCK_WRITE_BIT) <> 0 then
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
    if ((LOld and STAMPED_LOCK_WRITE_BIT) <> 0) or
       ((LOld and STAMPED_LOCK_READERS_MASK) <> 0) then
    begin
      CpuPause;
      Continue;
    end;
    LNew := LOld or STAMPED_LOCK_WRITE_BIT;
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
  if ((LOld and STAMPED_LOCK_WRITE_BIT) <> 0) or
     ((LOld and STAMPED_LOCK_READERS_MASK) <> 0) then
    Exit(0);
  LNew := LOld or STAMPED_LOCK_WRITE_BIT;
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
    if ((LOld and STAMPED_LOCK_WRITE_BIT) <> 0) or
       ((LOld and STAMPED_LOCK_READERS_MASK) <> 0) then
    begin
      CpuPause;
      Continue;
    end;
    LNew := LOld or STAMPED_LOCK_WRITE_BIT;
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
  Result := AtomicLoad64(FState, moAcquire) and STAMPED_LOCK_VERSION_MASK;
end;

function TStampedLock.Validate(const AStamp: Int64): Boolean;
var
  LCurrent: Int64;
begin
  if AStamp = 0 then
    Exit(False);
  LCurrent := AtomicLoad64(FState, moAcquire);
  Result := ((LCurrent and STAMPED_LOCK_WRITE_BIT) = 0) and
            ((LCurrent and STAMPED_LOCK_VERSION_MASK) = (AStamp and STAMPED_LOCK_VERSION_MASK));
end;

procedure TStampedLock.UnlockRead(const AStamp: Int64);
var
  LState: Int64;
begin
  if (AStamp = 0) or ((AStamp and STAMPED_LOCK_WRITE_BIT) <> 0) or
     ((AStamp and STAMPED_LOCK_READERS_MASK) = 0) then
    Exit;
  repeat
    LState := AtomicLoad64(FState, moAcquire);
    if ((LState and STAMPED_LOCK_WRITE_BIT) <> 0) or
       ((LState and STAMPED_LOCK_READERS_MASK) = 0) or
       ((LState and STAMPED_LOCK_VERSION_MASK) <>
        (AStamp and STAMPED_LOCK_VERSION_MASK)) then
      Exit;
  until AtomicCompareExchange64(FState, LState,
    LState - STAMPED_LOCK_READ_UNIT, moRelease) = LState;
end;

procedure TStampedLock.UnlockWrite(const AStamp: Int64);
begin
  if (AStamp = 0) or ((AStamp and STAMPED_LOCK_WRITE_BIT) = 0) then
    Exit;
  AtomicCompareExchange64(FState, AStamp, AStamp + 1, moRelease);
end;

procedure TStampedLock.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

destructor TStampedLock.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TStampedLock.IsClosed: Boolean; inline;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TStampedLock.IsReadLocked: Boolean; inline;
var
  LState: Int64;
begin
  LState := AtomicLoad64(FState, moAcquire);
  Result := (LState and STAMPED_LOCK_READERS_MASK) <> 0;
end;

function TStampedLock.IsWriteLocked: Boolean; inline;
begin
  Result := (AtomicLoad64(FState, moAcquire) and STAMPED_LOCK_WRITE_BIT) <> 0;
end;

end.
