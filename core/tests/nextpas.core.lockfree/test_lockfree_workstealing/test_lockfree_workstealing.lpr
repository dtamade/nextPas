program test_lockfree_workstealing;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.workstealing,
  nextpas.core.lockfree,
  nextpas.core.test;

procedure TestWorkStealingBasic;
var
  LPool: TWorkStealingPool;
begin
  LPool := TWorkStealingPool.Create(4);
  try
    Check(not LPool.IsClosed, 'Should not be closed');
    CheckEqual(Int64(4), LPool.GetWorkerCount, 'Worker count should be 4');
  finally
    LPool.Free;
  end;
end;

procedure TestWorkStealingSubmit;
var
  LPool: TWorkStealingPool;
begin
  LPool := TWorkStealingPool.Create(2);
  try
    Check(LPool.Submit(nil, nil), 'Should submit');
  finally
    LPool.Free;
  end;
end;

procedure TestWorkStealingSteal;
var
  LPool: TWorkStealingPool;
  LTask: TWorkStealingTask;
  LData: Pointer;
  LResult: TLockFreeWorkStealingResult;
begin
  LPool := TWorkStealingPool.Create(2);
  try
    LResult := LPool.Steal(LTask, LData);
    Check(wsEmpty = LResult, 'Should be empty');
  finally
    LPool.Free;
  end;
end;

procedure TestWorkStealingClose;
var
  LPool: TWorkStealingPool;
  LTask: TWorkStealingTask;
  LData: Pointer;
  LResult: TLockFreeWorkStealingResult;
begin
  LPool := TWorkStealingPool.Create(2);
  try
    LPool.Close;
    Check(LPool.IsClosed, 'Should be closed');

    Check(not LPool.Submit(nil, nil), 'Should not submit');

    LResult := LPool.Steal(LTask, LData);
    Check(wsClosed = LResult, 'Should return closed');
  finally
    LPool.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_workstealing ===');
  WriteLn;

  TestWorkStealingBasic;
  WriteLn('  + Basic state');

  TestWorkStealingSubmit;
  WriteLn('  + Submit');

  TestWorkStealingSteal;
  WriteLn('  + Steal');

  TestWorkStealingClose;
  WriteLn('  + Close semantics');

  WriteLn;
  WriteLn('All work stealing pool tests passed!');
end.
