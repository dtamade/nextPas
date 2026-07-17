program test_lockfree_rwlock;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.lockfree.rwlock,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

type
  PRwLockWriterArgs = ^TRwLockWriterArgs;
  TRwLockWriterArgs = record
    Lock: TConcurrentRwLock;
    Started: PInt32;
    Acquired: PInt32;
  end;

function WriterThread(AData: Pointer): PtrInt;
var
  LArgs: PRwLockWriterArgs;
begin
  LArgs := PRwLockWriterArgs(AData);
  AtomicStore32(LArgs^.Started^, 1, moRelease);
  if LArgs^.Lock.WriteLock then
  begin
    AtomicStore32(LArgs^.Acquired^, 1, moRelease);
    LArgs^.Lock.WriteUnlock;
  end;
  Result := 0;
end;

procedure TestRwLockBasic;
var
  LRwLock: TConcurrentRwLock;
begin
  LRwLock := TConcurrentRwLock.Create;
  try
    // Initial state
    Check(not LRwLock.IsClosed, 'RwLock should not be closed');
    Check(not LRwLock.IsWriteLocked, 'RwLock should not be write locked');
    CheckEqual(Int32(0), LRwLock.ReaderCount);

    // Read lock
    Check(LRwLock.TryReadLock, 'Should read lock');
    CheckEqual(Int32(1), LRwLock.ReaderCount);

    // Can read lock again
    Check(LRwLock.TryReadLock, 'Should read lock again');
    CheckEqual(Int32(2), LRwLock.ReaderCount);

    // Cannot write lock when readers exist
    Check(not LRwLock.TryWriteLock, 'Should not write lock when readers exist');

    // Read unlock
    LRwLock.ReadUnlock;
    CheckEqual(Int32(1), LRwLock.ReaderCount);

    LRwLock.ReadUnlock;
    CheckEqual(Int32(0), LRwLock.ReaderCount);

    // Now can write lock
    Check(LRwLock.TryWriteLock, 'Should write lock');
    Check(LRwLock.IsWriteLocked, 'RwLock should be write locked');

    // Cannot read lock when write locked
    Check(not LRwLock.TryReadLock, 'Should not read lock when write locked');

    // Write unlock
    LRwLock.WriteUnlock;
    Check(not LRwLock.IsWriteLocked, 'RwLock should not be write locked');
  finally
    LRwLock.Free;
  end;
end;

procedure TestRwLockClose;
var
  LRwLock: TConcurrentRwLock;
begin
  LRwLock := TConcurrentRwLock.Create;
  try
    LRwLock.TryReadLock;
    LRwLock.Close;
    Check(LRwLock.IsClosed, 'RwLock should be closed');

    // Can still unlock
    LRwLock.ReadUnlock;

    // Cannot lock after close
    Check(not LRwLock.TryReadLock, 'Should not read lock after close');
    Check(not LRwLock.TryWriteLock, 'Should not write lock after close');
  finally
    LRwLock.Free;
  end;
end;

procedure TestRwLockWriteLock;
var
  LRwLock: TConcurrentRwLock;
begin
  LRwLock := TConcurrentRwLock.Create;
  try
    Check(LRwLock.WriteLock, 'Should write lock');
    Check(LRwLock.IsWriteLocked, 'RwLock should be write locked');

    // Cannot read lock when write locked
    Check(not LRwLock.TryReadLock, 'Should not read lock when write locked');

    LRwLock.WriteUnlock;
    Check(not LRwLock.IsWriteLocked, 'RwLock should not be write locked');
  finally
    LRwLock.Free;
  end;
end;

procedure TestRwLockWriterPendingBlocksNewReaders;
var
  LRwLock: TConcurrentRwLock;
  LStarted: Int32;
  LAcquired: Int32;
  LArgs: TRwLockWriterArgs;
  LThread: TThreadID;
  LSpin: Integer;
begin
  LRwLock := TConcurrentRwLock.Create;
  LStarted := 0;
  LAcquired := 0;
  try
    Check(LRwLock.ReadLock, 'Reader should acquire initial lock');
    LArgs.Lock := LRwLock;
    LArgs.Started := @LStarted;
    LArgs.Acquired := @LAcquired;
    LThread := BeginThread(@WriterThread, @LArgs);

    LSpin := 0;
    while (AtomicLoad32(LStarted, moAcquire) = 0) and (LSpin < 1000000) do
    begin
      CpuPause;
      Inc(LSpin);
    end;

    for LSpin := 1 to 256 do
      CpuPause;

    Check(not LRwLock.TryReadLock, 'New readers must not bypass a waiting writer');
    CheckEqual(Int32(0), AtomicLoad32(LAcquired, moAcquire), 'Writer must still be pending while reader holds lock');

    LRwLock.ReadUnlock;

    LSpin := 0;
    while (AtomicLoad32(LAcquired, moAcquire) = 0) and (LSpin < 1000000) do
    begin
      CpuPause;
      Inc(LSpin);
    end;
    CheckEqual(Int32(1), AtomicLoad32(LAcquired, moAcquire), 'Writer should acquire once readers drain');
    WaitForThreadTerminate(LThread, 5000);
  finally
    LRwLock.Free;
  end;
end;

procedure TestRwLockInvalidUnlocksDoNotUnderflow;
var
  LRwLock: TConcurrentRwLock;
begin
  LRwLock := TConcurrentRwLock.Create;
  try
    LRwLock.ReadUnlock;
    CheckEqual(Int32(0), LRwLock.ReaderCount,
      'ReadUnlock without a reader must not underflow state');
    Check(LRwLock.TryWriteLock, 'Invalid read unlock must not create a phantom writer');
    LRwLock.WriteUnlock;
    LRwLock.WriteUnlock;
    Check(not LRwLock.IsWriteLocked, 'Repeated write unlock must leave the lock unlocked');
  finally
    LRwLock.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_rwlock ===');
  WriteLn;

  TestRwLockBasic;
  WriteLn('  + Basic read/write lock');

  TestRwLockClose;
  WriteLn('  + Close semantics');

  TestRwLockWriteLock;
  WriteLn('  + Write lock');

  TestRwLockWriterPendingBlocksNewReaders;
  WriteLn('  + Writer pending blocks new readers');

  TestRwLockInvalidUnlocksDoNotUnderflow;
  WriteLn('  + Invalid unlocks preserve state');

  WriteLn;
  WriteLn('All rwlock tests passed!');
end.
