program test_lockfree_mutex;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.lockfree.mutex,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

type
  PMutexThreadArgs = ^TMutexThreadArgs;
  TMutexThreadArgs = record
    Mutex: TConcurrentMutex;
  end;

function NonOwnerUnlockThread(AData: Pointer): PtrInt;
var
  LArgs: PMutexThreadArgs;
begin
  LArgs := PMutexThreadArgs(AData);
  LArgs^.Mutex.Unlock;
  Result := 0;
end;

procedure TestMutexBasic;
var
  LMutex: TConcurrentMutex;
begin
  LMutex := TConcurrentMutex.Create;
  try
    // Initial state
    Check(not LMutex.IsClosed, 'Mutex should not be closed');
    Check(not LMutex.IsLocked, 'Mutex should not be locked');

    // Lock
    Check(LMutex.TryLock, 'Should lock');
    Check(LMutex.IsLocked, 'Mutex should be locked');

    // Cannot lock again
    Check(not LMutex.TryLock, 'Should not lock when already locked');

    // Unlock
    LMutex.Unlock;
    Check(not LMutex.IsLocked, 'Mutex should not be locked');

    // Can lock again
    Check(LMutex.TryLock, 'Should lock after unlock');
    LMutex.Unlock;
  finally
    LMutex.Free;
  end;
end;

procedure TestMutexClose;
var
  LMutex: TConcurrentMutex;
begin
  LMutex := TConcurrentMutex.Create;
  try
    LMutex.TryLock;
    LMutex.Close;
    Check(LMutex.IsClosed, 'Mutex should be closed');

    // Can still unlock
    LMutex.Unlock;

    // Cannot lock after close
    Check(not LMutex.TryLock, 'Should not lock after close');
  finally
    LMutex.Free;
  end;
end;

procedure TestMutexLock;
var
  LMutex: TConcurrentMutex;
begin
  LMutex := TConcurrentMutex.Create;
  try
    Check(LMutex.Lock, 'Should lock');
    Check(LMutex.IsLocked, 'Mutex should be locked');

    LMutex.Unlock;
    Check(not LMutex.IsLocked, 'Mutex should not be locked');
  finally
    LMutex.Free;
  end;
end;

procedure TestMutexRejectsNonOwnerUnlock;
var
  LMutex: TConcurrentMutex;
  LArgs: TMutexThreadArgs;
  LThread: TThreadID;
begin
  LMutex := TConcurrentMutex.Create;
  try
    Check(LMutex.Lock, 'Owner thread should acquire mutex');
    LArgs.Mutex := LMutex;
    LThread := BeginThread(@NonOwnerUnlockThread, @LArgs);
    WaitForThreadTerminate(LThread, 5000);

    Check(LMutex.IsLocked, 'Non-owner Unlock must not release mutex');
    LMutex.Unlock;
    Check(not LMutex.IsLocked, 'Owner Unlock should release mutex');
  finally
    LMutex.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_mutex ===');
  WriteLn;

  TestMutexBasic;
  WriteLn('  + Basic lock/unlock');

  TestMutexClose;
  WriteLn('  + Close semantics');

  TestMutexLock;
  WriteLn('  + Lock');

  TestMutexRejectsNonOwnerUnlock;
  WriteLn('  + Non-owner unlock rejected');

  WriteLn;
  WriteLn('All mutex tests passed!');
end.
