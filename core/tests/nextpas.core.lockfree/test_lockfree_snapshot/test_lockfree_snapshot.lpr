program test_lockfree_snapshot;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.snapshot,
  nextpas.core.lockfree,
  nextpas.core.test;

procedure TestSnapshotBasic;
var
  LSnap: TSnapshotIsolationImpl;
begin
  LSnap := TSnapshotIsolationImpl.Create;
  try
    Check(not LSnap.IsClosed, 'Should not be closed');
    CheckEqual(Int64(0), LSnap.GetCurrentTimestamp, 'Initial timestamp should be 0');
  finally
    LSnap.Free;
  end;
end;

procedure TestSnapshotBegin;
var
  LSnap: TSnapshotIsolationImpl;
  LTs1, LTs2: Int64;
begin
  LSnap := TSnapshotIsolationImpl.Create;
  try
    LTs1 := LSnap.BeginSnapshot;
    Check(LTs1 >= 0, 'First snapshot should have non-negative timestamp');

    LTs2 := LSnap.BeginSnapshot;
    Check(LTs2 > LTs1, 'Second snapshot should have higher timestamp');
  finally
    LSnap.Free;
  end;
end;

procedure TestSnapshotWriteRead;
var
  LSnap: TSnapshotIsolationImpl;
  LTs: Int64;
  LValue: AnsiString;
  LResult: TSnapshotResult;
begin
  LSnap := TSnapshotIsolationImpl.Create;
  try
    LTs := LSnap.BeginSnapshot;

    // Write
    LResult := LSnap.Write('key', '42', LTs);
    Check(srCommitted = LResult, 'Write should commit');

    // Read at same timestamp should find the value
    LResult := LSnap.Read('key', LTs, LValue);
    Check(srCommitted = LResult, 'Read should find committed value');
    CheckEqual('42', LValue, 'Read value should match written value');

    // Read at earlier timestamp should not find it
    LResult := LSnap.Read('key', LTs - 1, LValue);
    Check(srNotFound = LResult, 'Read at earlier timestamp should return not found');
  finally
    LSnap.Free;
  end;
end;

procedure TestSnapshotWriteConflict;
var
  LSnap: TSnapshotIsolationImpl;
  LTs1, LTs2: Int64;
  LResult: TSnapshotResult;
begin
  LSnap := TSnapshotIsolationImpl.Create;
  try
    LTs1 := LSnap.BeginSnapshot;
    LTs2 := LSnap.BeginSnapshot;

    // First write at ts1
    LResult := LSnap.Write('key', 'first', LTs1);
    Check(srCommitted = LResult, 'First write should commit');

    // Second write at ts2 should conflict (ts1 < ts2, but ts1 already wrote)
    // Actually ts2 > ts1, so ts2's write should succeed (overwrites)
    LResult := LSnap.Write('key', 'second', LTs2);
    Check(srCommitted = LResult, 'Later write should commit (no conflict)');

    // Now try writing at an earlier timestamp - should conflict
    LResult := LSnap.Write('key', 'old', LTs1);
    Check(srConflict = LResult, 'Earlier write should conflict');
  finally
    LSnap.Free;
  end;
end;

procedure TestSnapshotCommit;
var
  LSnap: TSnapshotIsolationImpl;
  LTs: Int64;
  LResult: TSnapshotResult;
begin
  LSnap := TSnapshotIsolationImpl.Create;
  try
    LTs := LSnap.BeginSnapshot;
    LResult := LSnap.Commit(LTs);
    Check(srCommitted = LResult, 'Should commit');
  finally
    LSnap.Free;
  end;
end;

procedure TestSnapshotAbort;
var
  LSnap: TSnapshotIsolationImpl;
  LTs: Int64;
  LResult: TSnapshotResult;
begin
  LSnap := TSnapshotIsolationImpl.Create;
  try
    LTs := LSnap.BeginSnapshot;
    LResult := LSnap.Abort(LTs);
    Check(srAborted = LResult, 'Should abort');
  finally
    LSnap.Free;
  end;
end;

procedure TestSnapshotClose;
var
  LSnap: TSnapshotIsolationImpl;
begin
  LSnap := TSnapshotIsolationImpl.Create;
  try
    LSnap.Close;
    Check(LSnap.IsClosed, 'Should be closed');

    CheckEqual(Int64(-1), LSnap.BeginSnapshot, 'Should return -1');
  finally
    LSnap.Free;
  end;
end;

procedure TestSnapshotMultipleKeys;
var
  LSnap: TSnapshotIsolationImpl;
  LTs: Int64;
  LValue: AnsiString;
  LResult: TSnapshotResult;
begin
  LSnap := TSnapshotIsolationImpl.Create;
  try
    LTs := LSnap.BeginSnapshot;

    // Write multiple keys
    Check(srCommitted = LSnap.Write('a', '1', LTs), 'Write a');
    Check(srCommitted = LSnap.Write('b', '2', LTs), 'Write b');
    Check(srCommitted = LSnap.Write('c', '3', LTs), 'Write c');

    // Read all back
    LResult := LSnap.Read('a', LTs, LValue);
    Check(srCommitted = LResult, 'Read a');
    CheckEqual('1', LValue, 'Value a');

    LResult := LSnap.Read('b', LTs, LValue);
    Check(srCommitted = LResult, 'Read b');
    CheckEqual('2', LValue, 'Value b');

    LResult := LSnap.Read('c', LTs, LValue);
    Check(srCommitted = LResult, 'Read c');
    CheckEqual('3', LValue, 'Value c');

    // Non-existent key
    LResult := LSnap.Read('d', LTs, LValue);
    Check(srNotFound = LResult, 'Read non-existent');
  finally
    LSnap.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_snapshot ===');
  WriteLn;

  TestSnapshotBasic;
  WriteLn('  + Basic state');

  TestSnapshotBegin;
  WriteLn('  + Begin snapshot');

  TestSnapshotWriteRead;
  WriteLn('  + Write/Read');

  TestSnapshotWriteConflict;
  WriteLn('  + Write conflict detection');

  TestSnapshotCommit;
  WriteLn('  + Commit');

  TestSnapshotAbort;
  WriteLn('  + Abort');

  TestSnapshotClose;
  WriteLn('  + Close semantics');

  TestSnapshotMultipleKeys;
  WriteLn('  + Multiple keys');

  WriteLn;
  WriteLn('All snapshot isolation tests passed!');
end.
