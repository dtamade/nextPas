program test_lockfree_dag;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.atomic,
  nextpas.core.lockfree.dag;

var
  GDag: TConcurrentDAG;
  GPassed, GFailed: Int32;

type
  PDagEdgeCtx = ^TDagEdgeCtx;
  TDagEdgeCtx = record
    Dag: TConcurrentDAG;
    FromId, ToId: Int64;
    Ready, Start: PInt32;
    EdgeResult: TDagResult;
  end;

procedure InitDagEdgeCtx(out ACtx: TDagEdgeCtx; ADag: TConcurrentDAG;
  AFromId, AToId: Int64; AReady, AStart: PInt32);
begin
  ACtx.Dag := ADag;
  ACtx.FromId := AFromId;
  ACtx.ToId := AToId;
  ACtx.Ready := AReady;
  ACtx.Start := AStart;
end;

function DagEdgeProc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PDagEdgeCtx;
begin
  LCtx := PDagEdgeCtx(AArg);
  atomic_fetch_add(LCtx^.Ready^, 1, mo_acq_rel);
  while atomic_load(LCtx^.Start^, mo_acquire) = 0 do
    CpuPause;
  LCtx^.EdgeResult := LCtx^.Dag.AddEdge(LCtx^.FromId, LCtx^.ToId);
  Result := nil;
end;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure TestAddNode;
begin
  WriteLn('--- TestAddNode ---');
  GDag := TConcurrentDAG.Create;
  try
    Check(GDag.AddNode(1) = dagOk, 'Add node 1');
    Check(GDag.AddNode(2) = dagOk, 'Add node 2');
    Check(GDag.AddNode(1) = dagExists, 'Duplicate node');
    Check(GDag.GetNodeCount = 2, 'Node count = 2');
  finally
    GDag.Free;
  end;
end;

procedure TestRemoveNode;
begin
  WriteLn('--- TestRemoveNode ---');
  GDag := TConcurrentDAG.Create;
  try
    GDag.AddNode(1);
    GDag.AddNode(2);
    GDag.AddNode(3);
    GDag.AddEdge(1, 2);
    GDag.AddEdge(1, 3);
    Check(GDag.RemoveNode(1) = dagOk, 'Remove node 1');
    Check(GDag.GetNodeCount = 2, 'Node count = 2');
    Check(GDag.GetEdgeCount = 0, 'Edges removed with node');
    Check(GDag.RemoveNode(99) = dagNotFound, 'Remove nonexistent');
  finally
    GDag.Free;
  end;
end;

procedure TestAddEdge;
begin
  WriteLn('--- TestAddEdge ---');
  GDag := TConcurrentDAG.Create;
  try
    GDag.AddNode(1);
    GDag.AddNode(2);
    GDag.AddNode(3);
    Check(GDag.AddEdge(1, 2) = dagOk, 'Add edge 1->2');
    Check(GDag.AddEdge(1, 3) = dagOk, 'Add edge 1->3');
    Check(GDag.AddEdge(1, 2) = dagExists, 'Duplicate edge');
    Check(GDag.AddEdge(1, 99) = dagNotFound, 'Edge to nonexistent');
    Check(GDag.GetEdgeCount = 2, 'Edge count = 2');
  finally
    GDag.Free;
  end;
end;

procedure TestRemoveEdge;
begin
  WriteLn('--- TestRemoveEdge ---');
  GDag := TConcurrentDAG.Create;
  try
    GDag.AddNode(1);
    GDag.AddNode(2);
    GDag.AddEdge(1, 2);
    Check(GDag.RemoveEdge(1, 2) = dagOk, 'Remove edge 1->2');
    Check(GDag.GetEdgeCount = 0, 'Edge count = 0');
    Check(GDag.RemoveEdge(1, 2) = dagNotFound, 'Remove nonexistent edge');
  finally
    GDag.Free;
  end;
end;

procedure TestHasEdge;
begin
  WriteLn('--- TestHasEdge ---');
  GDag := TConcurrentDAG.Create;
  try
    GDag.AddNode(1);
    GDag.AddNode(2);
    GDag.AddEdge(1, 2);
    Check(GDag.HasEdge(1, 2), 'Has edge 1->2');
    Check(not GDag.HasEdge(2, 1), 'No edge 2->1');
    Check(not GDag.HasEdge(1, 99), 'No edge to nonexistent');
  finally
    GDag.Free;
  end;
end;

procedure TestDegree;
begin
  WriteLn('--- TestDegree ---');
  GDag := TConcurrentDAG.Create;
  try
    GDag.AddNode(1);
    GDag.AddNode(2);
    GDag.AddNode(3);
    GDag.AddEdge(1, 2);
    GDag.AddEdge(1, 3);
    GDag.AddEdge(2, 3);
    Check(GDag.InDegree(1) = 0, 'InDegree(1) = 0');
    Check(GDag.InDegree(2) = 1, 'InDegree(2) = 1');
    Check(GDag.InDegree(3) = 2, 'InDegree(3) = 2');
    Check(GDag.OutDegree(1) = 2, 'OutDegree(1) = 2');
    Check(GDag.OutDegree(3) = 0, 'OutDegree(3) = 0');
  finally
    GDag.Free;
  end;
end;

procedure TestTopologicalSort;
var
  LSorted: array[0..9] of Int64;
  LCount: Int32;
begin
  WriteLn('--- TestTopologicalSort ---');
  GDag := TConcurrentDAG.Create;
  try
    { 1 -> 2 -> 3 -> 4 }
    GDag.AddNode(1);
    GDag.AddNode(2);
    GDag.AddNode(3);
    GDag.AddNode(4);
    GDag.AddEdge(1, 2);
    GDag.AddEdge(2, 3);
    GDag.AddEdge(3, 4);
    LCount := GDag.TopologicalSort(LSorted);
    Check(LCount = 4, 'Sort count = 4');
    Check(LSorted[0] = 1, 'First is 1');
    Check(LSorted[3] = 4, 'Last is 4');
  finally
    GDag.Free;
  end;
end;

procedure TestTopologicalSortWithSmallBuffer;
var
  LSorted: array[0..1] of Int64;
  LCount: Int32;
begin
  WriteLn('--- TestTopologicalSortWithSmallBuffer ---');
  GDag := TConcurrentDAG.Create;
  try
    GDag.AddNode(1);
    GDag.AddNode(2);
    GDag.AddNode(3);
    GDag.AddEdge(1, 2);
    GDag.AddEdge(2, 3);
    LCount := GDag.TopologicalSort(LSorted);
    Check(LCount = 2, 'Small buffer receives a valid topological prefix');
    Check((LSorted[0] = 1) and (LSorted[1] = 2),
      'Small-buffer prefix preserves dependency order');
  finally
    GDag.Free;
  end;
end;

procedure TestEmptySingleAndSelfLoopBoundaries;
var
  LSorted: array[0..0] of Int64;
begin
  WriteLn('--- TestEmptySingleAndSelfLoopBoundaries ---');
  GDag := TConcurrentDAG.Create;
  try
    Check(GDag.TopologicalSort(LSorted) = 0,
      'Empty DAG has an empty topological order');
    Check(not GDag.HasCycle, 'Empty DAG has no cycle');
    Check(GDag.AddNode(7) = dagOk, 'Add single node');
    Check(GDag.AddEdge(7, 7) = dagCycle, 'Reject self-loop');
    Check(GDag.TopologicalSort(LSorted) = 1,
      'Single node has one-item topological order');
    Check(LSorted[0] = 7, 'Single-node order contains the node');
    Check(not GDag.HasCycle, 'Rejected self-loop leaves DAG acyclic');
  finally
    GDag.Free;
  end;
end;

procedure TestConcurrentOppositeEdgesCannotCreateCycle;
const
  CHAIN_LENGTH = 64;
  ATTEMPTS = 20;
var
  LAttempt, LI: Int32;
  LReady, LStart: Int32;
  LForwardRec, LReverseRec: TPlatformThreadRecord;
  LForwardCtx, LReverseCtx: TDagEdgeCtx;
  LSafe: Boolean;
begin
  WriteLn('--- TestConcurrentOppositeEdgesCannotCreateCycle ---');
  LSafe := True;
  for LAttempt := 1 to ATTEMPTS do
  begin
    GDag := TConcurrentDAG.Create;
    try
      for LI := 1 to CHAIN_LENGTH do
      begin
        GDag.AddNode(LI);
        GDag.AddNode(1000 + LI);
      end;
      for LI := 1 to CHAIN_LENGTH - 1 do
      begin
        GDag.AddEdge(LI, LI + 1);
        GDag.AddEdge(1000 + LI, 1001 + LI);
      end;

      LReady := 0;
      LStart := 0;
      InitDagEdgeCtx(LForwardCtx, GDag, 1, 1001, @LReady, @LStart);
      InitDagEdgeCtx(LReverseCtx, GDag, 1001, 1, @LReady, @LStart);
      Check(platform_thread_spawn(LForwardRec, @DagEdgeProc,
        @LForwardCtx) = 0, 'spawn forward edge worker');
      Check(platform_thread_spawn(LReverseRec, @DagEdgeProc,
        @LReverseCtx) = 0, 'spawn reverse edge worker');
      while atomic_load(LReady, mo_acquire) <> 2 do
        CpuPause;
      atomic_store(LStart, 1, mo_release);
      Check(platform_thread_wait(LForwardRec) = 0, 'join forward edge worker');
      Check(platform_thread_wait(LReverseRec) = 0, 'join reverse edge worker');

      if (LForwardCtx.EdgeResult = dagOk) and
         (LReverseCtx.EdgeResult = dagOk) then
        LSafe := False;
      if GDag.HasCycle then
        LSafe := False;
    finally
      GDag.Free;
    end;
    if not LSafe then
      Break;
  end;
  Check(LSafe, 'Opposite concurrent edges preserve the DAG invariant');
end;

procedure TestNoCycle;
begin
  WriteLn('--- TestNoCycle ---');
  GDag := TConcurrentDAG.Create;
  try
    GDag.AddNode(1);
    GDag.AddNode(2);
    GDag.AddNode(3);
    GDag.AddEdge(1, 2);
    GDag.AddEdge(2, 3);
    Check(not GDag.HasCycle, 'No cycle in DAG');
  finally
    GDag.Free;
  end;
end;

procedure TestCycleRejected;
begin
  WriteLn('--- TestCycleRejected ---');
  GDag := TConcurrentDAG.Create;
  try
    GDag.AddNode(1);
    GDag.AddNode(2);
    GDag.AddNode(3);
    Check(GDag.AddEdge(1, 2) = dagOk, 'Add edge 1->2');
    Check(GDag.AddEdge(2, 3) = dagOk, 'Add edge 2->3');
    Check(GDag.AddEdge(3, 1) = dagCycle, 'Reject edge that creates cycle');
    Check(not GDag.HasCycle, 'Graph remains acyclic');
  finally
    GDag.Free;
  end;
end;

procedure TestRemoveNodeUpdatesInDegree;
begin
  WriteLn('--- TestRemoveNodeUpdatesInDegree ---');
  GDag := TConcurrentDAG.Create;
  try
    GDag.AddNode(1);
    GDag.AddNode(2);
    GDag.AddNode(3);
    GDag.AddEdge(1, 2);
    GDag.AddEdge(2, 3);
    Check(GDag.InDegree(3) = 1, 'Node 3 starts with indegree 1');
    Check(GDag.RemoveNode(2) = dagOk, 'Remove middle node');
    Check(GDag.InDegree(3) = 0, 'Removing source should decrement target indegree');
  finally
    GDag.Free;
  end;
end;

procedure TestClear;
begin
  WriteLn('--- TestClear ---');
  GDag := TConcurrentDAG.Create;
  try
    GDag.AddNode(1);
    GDag.AddNode(2);
    GDag.AddEdge(1, 2);
    GDag.Clear;
    Check(GDag.GetNodeCount = 0, 'Cleared node count');
    Check(GDag.GetEdgeCount = 0, 'Cleared edge count');
  finally
    GDag.Free;
  end;
end;

procedure TestClose;
begin
  WriteLn('--- TestClose ---');
  GDag := TConcurrentDAG.Create;
  try
    GDag.AddNode(1);
    GDag.Close;
    Check(GDag.IsClosed, 'Is closed');
    Check(GDag.AddNode(2) = dagClosed, 'Add after close fails');
  finally
    GDag.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_dag ===');
  GPassed := 0;
  GFailed := 0;
  TestAddNode;
  TestRemoveNode;
  TestAddEdge;
  TestRemoveEdge;
  TestHasEdge;
  TestDegree;
  TestTopologicalSort;
  TestTopologicalSortWithSmallBuffer;
  TestEmptySingleAndSelfLoopBoundaries;
  TestConcurrentOppositeEdgesCannotCreateCycle;
  TestNoCycle;
  TestCycleRejected;
  TestRemoveNodeUpdatesInDegree;
  TestClear;
  TestClose;
  WriteLn;
  WriteLn('Results: ', GPassed, ' passed, ', GFailed, ' failed');
  if GFailed > 0 then
    Halt(1);
end.
