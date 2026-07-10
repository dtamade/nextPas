program test_lockfree_dag;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
  nextpas.core.lockfree.dag;

var
  GDag: TConcurrentDAG;
  GPassed, GFailed: Int32;

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
