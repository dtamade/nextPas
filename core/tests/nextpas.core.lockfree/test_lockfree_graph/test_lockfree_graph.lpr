program test_lockfree_graph;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.graph,
  nextpas.core.lockfree,
  nextpas.core.test;

procedure TestGraphBasic;
var
  LGraph: TLockFreeGraph;
begin
  LGraph := TLockFreeGraph.Create;
  try
    Check(not LGraph.IsClosed, 'Should not be closed');
    CheckEqual(Int64(0), LGraph.GetVertexCount, 'Vertex count should be 0');
    CheckEqual(Int64(0), LGraph.GetEdgeCount, 'Edge count should be 0');
  finally
    LGraph.Free;
  end;
end;

procedure TestGraphAddVertex;
var
  LGraph: TLockFreeGraph;
  LResult: TLockFreeGraphResult;
begin
  LGraph := TLockFreeGraph.Create;
  try
    LResult := LGraph.AddVertex(1);
    Check(grAdded = LResult, 'Should add vertex');
    CheckEqual(Int64(1), LGraph.GetVertexCount, 'Vertex count should be 1');

    LResult := LGraph.AddVertex(2);
    Check(grAdded = LResult, 'Should add vertex');
    CheckEqual(Int64(2), LGraph.GetVertexCount, 'Vertex count should be 2');

    // Duplicate
    LResult := LGraph.AddVertex(1);
    Check(grExists = LResult, 'Should not add duplicate');
  finally
    LGraph.Free;
  end;
end;

procedure TestGraphRemoveVertex;
var
  LGraph: TLockFreeGraph;
  LResult: TLockFreeGraphResult;
begin
  LGraph := TLockFreeGraph.Create;
  try
    LGraph.AddVertex(1);
    LGraph.AddVertex(2);

    LResult := LGraph.RemoveVertex(1);
    Check(grRemoved = LResult, 'Should remove vertex');
    CheckEqual(Int64(1), LGraph.GetVertexCount, 'Vertex count should be 1');

    LResult := LGraph.RemoveVertex(1);
    Check(grNotFound = LResult, 'Should not find vertex');
  finally
    LGraph.Free;
  end;
end;

procedure TestGraphAddEdge;
var
  LGraph: TLockFreeGraph;
  LResult: TLockFreeGraphResult;
begin
  LGraph := TLockFreeGraph.Create;
  try
    LGraph.AddVertex(1);
    LGraph.AddVertex(2);
    LGraph.AddVertex(3);

    LResult := LGraph.AddEdge(1, 2);
    Check(grAdded = LResult, 'Should add edge');
    CheckEqual(Int64(1), LGraph.GetEdgeCount, 'Edge count should be 1');

    LResult := LGraph.AddEdge(1, 3);
    Check(grAdded = LResult, 'Should add edge');
    CheckEqual(Int64(2), LGraph.GetEdgeCount, 'Edge count should be 2');

    // Duplicate edge
    LResult := LGraph.AddEdge(1, 2);
    Check(grExists = LResult, 'Should not add duplicate edge');

    // Non-existent vertex
    LResult := LGraph.AddEdge(99, 1);
    Check(grNotFound = LResult, 'Should not find vertex');

    LResult := LGraph.AddEdge(1, 99);
    Check(grNotFound = LResult, 'Should reject edge to missing target');
  finally
    LGraph.Free;
  end;
end;

procedure TestGraphRemoveVertexCleansEdges;
var
  LGraph: TLockFreeGraph;
begin
  LGraph := TLockFreeGraph.Create;
  try
    LGraph.AddVertex(1);
    LGraph.AddVertex(2);
    LGraph.AddVertex(3);
    LGraph.AddEdge(1, 2);
    LGraph.AddEdge(2, 3);
    LGraph.AddEdge(3, 2);

    CheckEqual(Int64(3), LGraph.GetEdgeCount, 'Edge count before vertex delete');
    Check(grRemoved = LGraph.RemoveVertex(2), 'Remove vertex with incoming and outgoing edges');
    CheckEqual(Int64(0), LGraph.GetEdgeCount, 'Removing vertex should remove all attached edges');
    Check(not LGraph.HasEdge(1, 2), 'Incoming edge should be removed');
    Check(not LGraph.HasEdge(3, 2), 'Second incoming edge should be removed');
  finally
    LGraph.Free;
  end;
end;

procedure TestGraphRemoveEdge;
var
  LGraph: TLockFreeGraph;
  LResult: TLockFreeGraphResult;
begin
  LGraph := TLockFreeGraph.Create;
  try
    LGraph.AddVertex(1);
    LGraph.AddVertex(2);
    LGraph.AddEdge(1, 2);

    LResult := LGraph.RemoveEdge(1, 2);
    Check(grRemoved = LResult, 'Should remove edge');
    CheckEqual(Int64(0), LGraph.GetEdgeCount, 'Edge count should be 0');

    LResult := LGraph.RemoveEdge(1, 2);
    Check(grNotFound = LResult, 'Should not find edge');
  finally
    LGraph.Free;
  end;
end;

procedure TestGraphHasEdge;
var
  LGraph: TLockFreeGraph;
begin
  LGraph := TLockFreeGraph.Create;
  try
    LGraph.AddVertex(1);
    LGraph.AddVertex(2);
    LGraph.AddVertex(3);
    LGraph.AddEdge(1, 2);

    Check(LGraph.HasEdge(1, 2), 'Should have edge 1->2');
    Check(not LGraph.HasEdge(1, 3), 'Should not have edge 1->3');
    Check(not LGraph.HasEdge(2, 1), 'Should not have edge 2->1');
  finally
    LGraph.Free;
  end;
end;

procedure TestGraphClose;
var
  LGraph: TLockFreeGraph;
  LResult: TLockFreeGraphResult;
begin
  LGraph := TLockFreeGraph.Create;
  try
    LGraph.Close;
    Check(LGraph.IsClosed, 'Should be closed');

    LResult := LGraph.AddVertex(1);
    Check(grClosed = LResult, 'Should return closed');

    LResult := LGraph.AddEdge(1, 2);
    Check(grClosed = LResult, 'Should return closed');
  finally
    LGraph.Free;
  end;
end;

procedure TestGraphClear;
var
  LGraph: TLockFreeGraph;
begin
  LGraph := TLockFreeGraph.Create;
  try
    LGraph.AddVertex(1);
    LGraph.AddVertex(2);
    LGraph.AddEdge(1, 2);
    CheckEqual(Int64(2), LGraph.GetVertexCount, 'Vertex count should be 2');

    LGraph.Clear;
    CheckEqual(Int64(0), LGraph.GetVertexCount, 'Vertex count should be 0');
    CheckEqual(Int64(0), LGraph.GetEdgeCount, 'Edge count should be 0');
  finally
    LGraph.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_graph ===');
  WriteLn;

  TestGraphBasic;
  WriteLn('  + Basic state');

  TestGraphAddVertex;
  WriteLn('  + Add vertex');

  TestGraphRemoveVertex;
  WriteLn('  + Remove vertex');

  TestGraphRemoveVertexCleansEdges;
  WriteLn('  + Remove vertex cleans edges');

  TestGraphAddEdge;
  WriteLn('  + Add edge');

  TestGraphRemoveEdge;
  WriteLn('  + Remove edge');

  TestGraphHasEdge;
  WriteLn('  + Has edge');

  TestGraphClose;
  WriteLn('  + Close semantics');

  TestGraphClear;
  WriteLn('  + Clear');

  WriteLn;
  WriteLn('All graph tests passed!');
end.
