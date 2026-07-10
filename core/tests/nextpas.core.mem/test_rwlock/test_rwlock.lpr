program test_rwlock;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.mem.rwlock;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestInitDone;
var
  LRwLock: TMemRwLock;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRwLock.Init;
  LRwLock.Done;
  Check(True, 'Init/Done should not crash');
end;

procedure TestReadLockUnlock;
var
  LRwLock: TMemRwLock;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRwLock.Init;
  try
    LRwLock.AcquireRead;
    LRwLock.ReleaseRead;
    Check(True, 'AcquireRead/ReleaseRead should not crash');
  finally
    LRwLock.Done;
  end;
end;

procedure TestWriteLockUnlock;
var
  LRwLock: TMemRwLock;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRwLock.Init;
  try
    LRwLock.AcquireWrite;
    LRwLock.ReleaseWrite;
    Check(True, 'AcquireWrite/ReleaseWrite should not crash');
  finally
    LRwLock.Done;
  end;
end;

procedure TestDoubleInit;
var
  LRwLock: TMemRwLock;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRwLock.Init;
  LRwLock.Init; { Second init should be no-op }
  LRwLock.Done;
  Check(True, 'Double Init should be safe');
end;

procedure TestDoubleDone;
var
  LRwLock: TMemRwLock;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRwLock.Init;
  LRwLock.Done;
  LRwLock.Done; { Second done should be no-op }
  Check(True, 'Double Done should be safe');
end;

procedure TestMultipleReadWriteCycles;
var
  LRwLock: TMemRwLock;
  LI: Integer;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRwLock.Init;
  try
    for LI := 1 to 100 do
    begin
      LRwLock.AcquireRead;
      LRwLock.ReleaseRead;
      LRwLock.AcquireWrite;
      LRwLock.ReleaseWrite;
    end;
    Check(True, '100 read/write cycles should work');
  finally
    LRwLock.Done;
  end;
end;

procedure TestMultipleReaders;
var
  LRwLock: TMemRwLock;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRwLock.Init;
  try
    { Multiple concurrent readers should be allowed }
    LRwLock.AcquireRead;
    LRwLock.AcquireRead;
    LRwLock.ReleaseRead;
    LRwLock.ReleaseRead;
    Check(True, 'Multiple readers should be allowed');
  finally
    LRwLock.Done;
  end;
end;

procedure TestAcquireReadWithoutInitRaises;
var
  LRwLock: TMemRwLock;
  LRaised: Boolean;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRaised := False;
  try
    LRwLock.AcquireRead;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'AcquireRead on uninitialized rwlock should raise');
end;

procedure TestAcquireWriteWithoutInitRaises;
var
  LRwLock: TMemRwLock;
  LRaised: Boolean;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRaised := False;
  try
    LRwLock.AcquireWrite;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'AcquireWrite on uninitialized rwlock should raise');
end;

begin
  T := TTestSuite.Create('test_rwlock');
  T.Test('InitDone', @TestInitDone);
  T.Test('ReadLockUnlock', @TestReadLockUnlock);
  T.Test('WriteLockUnlock', @TestWriteLockUnlock);
  T.Test('DoubleInit', @TestDoubleInit);
  T.Test('DoubleDone', @TestDoubleDone);
  T.Test('MultipleReadWriteCycles', @TestMultipleReadWriteCycles);
  T.Test('MultipleReaders', @TestMultipleReaders);
  T.Test('AcquireReadWithoutInitRaises', @TestAcquireReadWithoutInitRaises);
  T.Test('AcquireWriteWithoutInitRaises', @TestAcquireWriteWithoutInitRaises);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
