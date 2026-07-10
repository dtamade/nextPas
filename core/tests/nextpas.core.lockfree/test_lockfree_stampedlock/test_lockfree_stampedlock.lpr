program test_lockfree_stampedlock;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.stampedlock,
  nextpas.core.lockfree,
  nextpas.core.test;

procedure TestStampedLockBasic;
var
  LLock: TStampedLock;
begin
  LLock := TStampedLock.Create;
  try
    Check(not LLock.IsClosed, 'Should not be closed');
    Check(not LLock.IsReadLocked, 'Should not be read locked');
    Check(not LLock.IsWriteLocked, 'Should not be write locked');
  finally
    LLock.Free;
  end;
end;

procedure TestStampedLockReadWrite;
var
  LLock: TStampedLock;
  LStamp: Int64;
begin
  LLock := TStampedLock.Create;
  try
    // Read lock
    LStamp := LLock.ReadLock;
    Check(LStamp <> 0, 'ReadLock should return non-zero stamp');
    Check(LLock.IsReadLocked, 'Should be read locked');
    Check(not LLock.IsWriteLocked, 'Should not be write locked');

    // Unlock read
    LLock.UnlockRead(LStamp);
    Check(not LLock.IsReadLocked, 'Should not be read locked');

    // Write lock
    LStamp := LLock.WriteLock;
    Check(LStamp <> 0, 'WriteLock should return non-zero stamp');
    Check(LLock.IsWriteLocked, 'Should be write locked');
    Check(not LLock.IsReadLocked, 'Should not be read locked when write locked');

    // Unlock write
    LLock.UnlockWrite(LStamp);
    Check(not LLock.IsWriteLocked, 'Should not be write locked');
  finally
    LLock.Free;
  end;
end;

procedure TestStampedLockMultipleReaders;
var
  LLock: TStampedLock;
  LStamp1, LStamp2, LStamp3: Int64;
begin
  LLock := TStampedLock.Create;
  try
    LStamp1 := LLock.ReadLock;
    LStamp2 := LLock.ReadLock;
    LStamp3 := LLock.ReadLock;
    Check(LLock.IsReadLocked, 'Should be read locked');

    LLock.UnlockRead(LStamp1);
    LLock.UnlockRead(LStamp2);
    LLock.UnlockRead(LStamp3);
    Check(not LLock.IsReadLocked, 'Should not be read locked');
  finally
    LLock.Free;
  end;
end;

procedure TestStampedLockOptimisticRead;
var
  LLock: TStampedLock;
  LStamp, LWriteStamp: Int64;
begin
  LLock := TStampedLock.Create;
  try
    // Optimistic read when unlocked
    LStamp := LLock.TryOptimisticRead;
    Check(LStamp <> 0, 'Optimistic read should return non-zero stamp');
    Check(LLock.Validate(LStamp), 'Stamp should be valid when no writes');

    // Write lock invalidates optimistic stamp
    LStamp := LLock.TryOptimisticRead;
    LWriteStamp := LLock.WriteLock;
    Check(not LLock.Validate(LStamp), 'Stamp should be invalid after write');
    LLock.UnlockWrite(LWriteStamp);

    // New optimistic read after write
    LStamp := LLock.TryOptimisticRead;
    Check(LLock.Validate(LStamp), 'New stamp should be valid');
  finally
    LLock.Free;
  end;
end;

procedure TestStampedLockInvalidUnlocksDoNotCorruptState;
var
  LLock: TStampedLock;
  LReadStamp, LWriteStamp: Int64;
begin
  LLock := TStampedLock.Create;
  try
    LWriteStamp := LLock.WriteLock;
    LLock.UnlockWrite(LWriteStamp + 2);
    Check(LLock.IsWriteLocked, 'Wrong write stamp must not release the lock');
    LLock.UnlockWrite(LWriteStamp);
    Check(not LLock.IsWriteLocked, 'Correct write stamp must release the lock');
    LLock.UnlockWrite(LWriteStamp);
    Check(not LLock.IsWriteLocked, 'Repeated write unlock must be a no-op');

    LReadStamp := LLock.ReadLock;
    LLock.UnlockRead(1);
    Check(LLock.IsReadLocked, 'Wrong read stamp must not decrement the reader count');
    LLock.UnlockRead(LReadStamp);
    Check(not LLock.IsReadLocked, 'Correct read stamp must release the reader');
    LLock.UnlockRead(LReadStamp);
    Check(not LLock.IsReadLocked, 'Repeated read unlock must not underflow the reader count');
  finally
    LLock.Free;
  end;
end;

procedure TestStampedLockTryWrite;
var
  LLock: TStampedLock;
  LStamp: Int64;
begin
  LLock := TStampedLock.Create;
  try
    LStamp := LLock.TryWriteLock;
    Check(LStamp <> 0, 'TryWriteLock should succeed');

    // Cannot get write lock when write locked
    Check(LLock.TryWriteLock = 0, 'TryWriteLock should fail when write locked');

    LLock.UnlockWrite(LStamp);
    LStamp := LLock.TryWriteLock;
    Check(LStamp <> 0, 'TryWriteLock should succeed after unlock');
    LLock.UnlockWrite(LStamp);
  finally
    LLock.Free;
  end;
end;

procedure TestStampedLockTryRead;
var
  LLock: TStampedLock;
  LStamp: Int64;
begin
  LLock := TStampedLock.Create;
  try
    LStamp := LLock.TryReadLock;
    Check(LStamp <> 0, 'TryReadLock should succeed');
    LLock.UnlockRead(LStamp);

    // Write lock blocks read
    LStamp := LLock.WriteLock;
    Check(LLock.TryReadLock = 0, 'TryReadLock should fail when write locked');
    LLock.UnlockWrite(LStamp);
  finally
    LLock.Free;
  end;
end;

procedure TestStampedLockWriterBlockedByReader;
var
  LLock: TStampedLock;
  LReadStamp: Int64;
  LWriteStamp: Int64;
begin
  LLock := TStampedLock.Create;
  try
    LReadStamp := LLock.ReadLock;
    Check(LReadStamp <> 0, 'Read lock must succeed');
    Check(LLock.TryWriteLock = 0, 'Writer must not acquire while a reader is active');
    LLock.UnlockRead(LReadStamp);
    LWriteStamp := LLock.TryWriteLock;
    Check(LWriteStamp <> 0, 'Writer should acquire after last reader leaves');
    LLock.UnlockWrite(LWriteStamp);
  finally
    LLock.Free;
  end;
end;

procedure TestStampedLockClose;
var
  LLock: TStampedLock;
begin
  LLock := TStampedLock.Create;
  try
    LLock.Close;
    Check(LLock.IsClosed, 'Should be closed');

    // Lock operations should return 0
    Check(LLock.ReadLock = 0, 'ReadLock should return 0 when closed');
    Check(LLock.WriteLock = 0, 'WriteLock should return 0 when closed');
    Check(LLock.TryReadLock = 0, 'TryReadLock should return 0 when closed');
    Check(LLock.TryWriteLock = 0, 'TryWriteLock should return 0 when closed');
  finally
    LLock.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_stampedlock ===');
  WriteLn;

  TestStampedLockBasic;
  WriteLn('  + Basic state');

  TestStampedLockReadWrite;
  WriteLn('  + Read/Write lock');

  TestStampedLockMultipleReaders;
  WriteLn('  + Multiple readers');

  TestStampedLockOptimisticRead;
  WriteLn('  + Optimistic read');

  TestStampedLockTryWrite;
  WriteLn('  + TryWriteLock');

  TestStampedLockTryRead;
  WriteLn('  + TryReadLock');

  TestStampedLockWriterBlockedByReader;
  WriteLn('  + Writer blocked by reader');

  TestStampedLockInvalidUnlocksDoNotCorruptState;
  WriteLn('  + Invalid unlocks preserve state');

  TestStampedLockClose;
  WriteLn('  + Close semantics');

  WriteLn;
  WriteLn('All stamped lock tests passed!');
end.
