program test_mutex;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.mem.mutex;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestInitDone;
var
  LMutex: TMemMutex;
begin
  FillChar(LMutex, SizeOf(LMutex), 0);
  LMutex.Init;
  LMutex.Done;
  Check(True, 'Init/Done should not crash');
end;

procedure TestAcquireRelease;
var
  LMutex: TMemMutex;
begin
  FillChar(LMutex, SizeOf(LMutex), 0);
  LMutex.Init;
  try
    LMutex.Acquire;
    LMutex.Release;
    Check(True, 'Acquire/Release should not crash');
  finally
    LMutex.Done;
  end;
end;

procedure TestDoubleInit;
var
  LMutex: TMemMutex;
begin
  FillChar(LMutex, SizeOf(LMutex), 0);
  LMutex.Init;
  LMutex.Init; { Second init should be no-op }
  LMutex.Done;
  Check(True, 'Double Init should be safe');
end;

procedure TestDoubleDone;
var
  LMutex: TMemMutex;
begin
  FillChar(LMutex, SizeOf(LMutex), 0);
  LMutex.Init;
  LMutex.Done;
  LMutex.Done; { Second done should be no-op }
  Check(True, 'Double Done should be safe');
end;

procedure TestMultipleAcquireRelease;
var
  LMutex: TMemMutex;
  LI: Integer;
begin
  FillChar(LMutex, SizeOf(LMutex), 0);
  LMutex.Init;
  try
    for LI := 1 to 100 do
    begin
      LMutex.Acquire;
      LMutex.Release;
    end;
    Check(True, '100 acquire/release cycles should work');
  finally
    LMutex.Done;
  end;
end;

procedure TestAcquireWithoutInitRaises;
var
  LMutex: TMemMutex;
  LRaised: Boolean;
begin
  FillChar(LMutex, SizeOf(LMutex), 0);
  LRaised := False;
  try
    LMutex.Acquire;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'Acquire on uninitialized mutex should raise');
end;

procedure TestDoneWithoutInitNoOp;
var
  LMutex: TMemMutex;
begin
  FillChar(LMutex, SizeOf(LMutex), 0);
  LMutex.Done; { Should be no-op }
  Check(True, 'Done on uninitialized mutex should be no-op');
end;

begin
  T := TTestSuite.Create('test_mutex');
  T.Test('InitDone', @TestInitDone);
  T.Test('AcquireRelease', @TestAcquireRelease);
  T.Test('DoubleInit', @TestDoubleInit);
  T.Test('DoubleDone', @TestDoubleDone);
  T.Test('MultipleAcquireRelease', @TestMultipleAcquireRelease);
  T.Test('AcquireWithoutInitRaises', @TestAcquireWithoutInitRaises);
  T.Test('DoneWithoutInitNoOp', @TestDoneWithoutInitNoOp);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
