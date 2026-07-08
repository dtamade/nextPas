program test_lockfree_rwlock;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.rwlock,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

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

begin
  WriteLn('=== test_lockfree_rwlock ===');
  WriteLn;

  TestRwLockBasic;
  WriteLn('  + Basic read/write lock');

  TestRwLockClose;
  WriteLn('  + Close semantics');

  TestRwLockWriteLock;
  WriteLn('  + Write lock');

  WriteLn;
  WriteLn('All rwlock tests passed!');
end.
