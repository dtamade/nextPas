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
  Result := 0;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
    begin
      Result := 0;
      Exit;
    end;
    LOld := atomic_load_64(FState, mo_relaxed);
    if (LOld and STAMPED_LOCK_WRITE_BIT) <> 0 then
    begin
      CpuPause;
      Continue;
    end;
    LNew := LOld + STAMPED_LOCK_READ_UNIT;
    if atomic_compare_exchange_strong_64(FState, LOld, LNew, mo_acq_rel, mo_acquire) then
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
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(0);
  LOld := atomic_load_64(FState, mo_relaxed);
  if (LOld and STAMPED_LOCK_WRITE_BIT) <> 0 then
    Exit(0);
  LNew := LOld + STAMPED_LOCK_READ_UNIT;
  if atomic_compare_exchange_strong_64(FState, LOld, LNew, mo_acq_rel, mo_acquire) then
    Result := LNew
  else
    Result := 0;
end;

function TStampedLock.TryReadLockTimeout(const ATimeoutNs: Int64): Int64;
var
  LStart: TInstant;
  LOld, LNew: Int64;
begin
  Result := 0;
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TStampedLock.TryReadLockTimeout: timeout must be > 0');
  LStart := TInstant.Now;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(0);
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
      Exit(0);
    LOld := atomic_load_64(FState, mo_relaxed);
    if (LOld and STAMPED_LOCK_WRITE_BIT) <> 0 then
    begin
      CpuPause;
      Continue;
    end;
    LNew := LOld + STAMPED_LOCK_READ_UNIT;
    if atomic_compare_exchange_strong_64(FState, LOld, LNew, mo_acq_rel, mo_acquire) then
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
  Result := 0;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
    begin
      Result := 0;
      Exit;
    end;
    LOld := atomic_load_64(FState, mo_relaxed);
    if ((LOld and STAMPED_LOCK_WRITE_BIT) <> 0) or
       ((LOld and STAMPED_LOCK_READERS_MASK) <> 0) then
    begin
      CpuPause;
      Continue;
    end;
    LNew := LOld or STAMPED_LOCK_WRITE_BIT;
    if atomic_compare_exchange_strong_64(FState, LOld, LNew, mo_acq_rel, mo_acquire) then
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
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(0);
  LOld := atomic_load_64(FState, mo_relaxed);
  if ((LOld and STAMPED_LOCK_WRITE_BIT) <> 0) or
     ((LOld and STAMPED_LOCK_READERS_MASK) <> 0) then
    Exit(0);
  LNew := LOld or STAMPED_LOCK_WRITE_BIT;
  if atomic_compare_exchange_strong_64(FState, LOld, LNew, mo_acq_rel, mo_acquire) then
    Result := LNew
  else
    Result := 0;
end;

function TStampedLock.TryWriteLockTimeout(const ATimeoutNs: Int64): Int64;
var
  LStart: TInstant;
  LOld, LNew: Int64;
begin
  Result := 0;
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TStampedLock.TryWriteLockTimeout: timeout must be > 0');
  LStart := TInstant.Now;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(0);
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
      Exit(0);
    LOld := atomic_load_64(FState, mo_relaxed);
    if ((LOld and STAMPED_LOCK_WRITE_BIT) <> 0) or
       ((LOld and STAMPED_LOCK_READERS_MASK) <> 0) then
    begin
      CpuPause;
      Continue;
    end;
    LNew := LOld or STAMPED_LOCK_WRITE_BIT;
    if atomic_compare_exchange_strong_64(FState, LOld, LNew, mo_acq_rel, mo_acquire) then
    begin
      Result := LNew;
      Exit;
    end;
  end;
end;

function TStampedLock.TryOptimisticRead: Int64;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(0);
  Result := atomic_load_64(FState, mo_acquire) and STAMPED_LOCK_VERSION_MASK;
end;

function TStampedLock.Validate(const AStamp: Int64): Boolean;
var
  LCurrent: Int64;
begin
  if AStamp = 0 then
    Exit(False);
  LCurrent := atomic_load_64(FState, mo_acquire);
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
    LState := atomic_load_64(FState, mo_acquire);
    if ((LState and STAMPED_LOCK_WRITE_BIT) <> 0) or
       ((LState and STAMPED_LOCK_READERS_MASK) = 0) or
       ((LState and STAMPED_LOCK_VERSION_MASK) <>
        (AStamp and STAMPED_LOCK_VERSION_MASK)) then
      Exit;
  until atomic_compare_exchange_strong_64(FState, LState, LState - STAMPED_LOCK_READ_UNIT, mo_release, mo_relaxed);
end;

procedure TStampedLock.UnlockWrite(const AStamp: Int64);
var
  LExpected: Int64;
begin
  if (AStamp = 0) or ((AStamp and STAMPED_LOCK_WRITE_BIT) = 0) then
    Exit;
  LExpected := AStamp;
  atomic_compare_exchange_strong_64(FState, LExpected, AStamp + 1, mo_release, mo_relaxed);
end;

procedure TStampedLock.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TStampedLock.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TStampedLock.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TStampedLock.IsReadLocked: Boolean; inline;
var
  LState: Int64;
begin
  LState := atomic_load_64(FState, mo_acquire);
  Result := (LState and STAMPED_LOCK_READERS_MASK) <> 0;
end;

function TStampedLock.IsWriteLocked: Boolean; inline;
begin
  Result := (atomic_load_64(FState, mo_acquire) and STAMPED_LOCK_WRITE_BIT) <> 0;
end;

end.
