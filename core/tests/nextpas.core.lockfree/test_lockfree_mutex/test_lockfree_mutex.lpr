program test_lockfree_mutex;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.mutex,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

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

begin
  WriteLn('=== test_lockfree_mutex ===');
  WriteLn;

  TestMutexBasic;
  WriteLn('  + Basic lock/unlock');

  TestMutexClose;
  WriteLn('  + Close semantics');

  TestMutexLock;
  WriteLn('  + Lock');

  WriteLn;
  WriteLn('All mutex tests passed!');
end.
