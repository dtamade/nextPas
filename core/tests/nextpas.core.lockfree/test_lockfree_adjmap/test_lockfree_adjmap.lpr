program test_lockfree_adjmap;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.adjmap,
  nextpas.core.test;

procedure TestAdjMapBasic;
var
  LMap: TAdjMapImpl;
begin
  LMap := TAdjMapImpl.Create(16);
  try
    CheckEqual(Ord(amOk), Ord(LMap.AddVertex(1)));
    CheckEqual(Ord(amOk), Ord(LMap.AddVertex(2)));
    CheckEqual(Ord(amOk), Ord(LMap.AddVertex(3)));

    CheckEqual(Ord(amOk), Ord(LMap.AddEdge(1, 2, 10)));
    CheckEqual(Ord(amOk), Ord(LMap.AddEdge(2, 3, 20)));
    CheckEqual(Ord(amOk), Ord(LMap.AddEdge(1, 3, 50)));

    CheckEqual(3, LMap.GetVertexCount);
    CheckEqual(3, LMap.GetEdgeCount);

    { Duplicate vertex }
    CheckEqual(Ord(amVertexExists), Ord(LMap.AddVertex(1)));
  finally
    LMap.Free;
  end;
end;

procedure TestAdjMapDijkstra;
var
  LMap: TAdjMapImpl;
  LResult: TPathResult;
begin
  LMap := TAdjMapImpl.Create(16);
  try
    { Graph: 1 --10--> 2 --20--> 3, 1 --50--> 3 }
    LMap.AddVertex(1);
    LMap.AddVertex(2);
    LMap.AddVertex(3);
    LMap.AddVertex(4);
    LMap.AddEdge(1, 2, 10);
    LMap.AddEdge(2, 3, 20);
    LMap.AddEdge(1, 3, 50);
    LMap.AddEdge(3, 4, 5);

    { Shortest path 1->3: via 2 = 30 }
    CheckEqual(Ord(amOk), Ord(LMap.Dijkstra(1, 3, LResult)));
    CheckEqual(Int64(30), LResult.FDistance);
    Check(LResult.FPathLen = 3, 'Path should be 1->2->3');
    Check(LResult.FPath[0] = 1, 'First node should be 1');
    Check(LResult.FPath[1] = 2, 'Second node should be 2');
    Check(LResult.FPath[2] = 3, 'Third node should be 3');
    SetLength(LResult.FPath, 0);

    { Shortest path 1->4: 1->2->3->4 = 35 }
    CheckEqual(Ord(amOk), Ord(LMap.Dijkstra(1, 4, LResult)));
    CheckEqual(Int64(35), LResult.FDistance);
    Check(LResult.FPathLen = 4, 'Path should be 1->2->3->4');
    SetLength(LResult.FPath, 0);
  finally
    LMap.Free;
  end;
end;

procedure TestAdjMapNoPath;
var
  LMap: TAdjMapImpl;
  LResult: TPathResult;
begin
  LMap := TAdjMapImpl.Create(16);
  try
    LMap.AddVertex(1);
    LMap.AddVertex(2);
    LMap.AddVertex(3);
    LMap.AddEdge(1, 2, 10);
    { No edge from 2 to 3 }
    CheckEqual(Ord(amNoPath), Ord(LMap.Dijkstra(1, 3, LResult)));
    SetLength(LResult.FPath, 0);
  finally
    LMap.Free;
  end;
end;

procedure TestAdjMapRemoveEdge;
var
  LMap: TAdjMapImpl;
begin
  LMap := TAdjMapImpl.Create(16);
  try
    LMap.AddVertex(1);
    LMap.AddVertex(2);
    LMap.AddEdge(1, 2, 10);
    CheckEqual(1, LMap.GetEdgeCount);

    CheckEqual(Ord(amOk), Ord(LMap.RemoveEdge(1, 2)));
    CheckEqual(0, LMap.GetEdgeCount);

    CheckEqual(Ord(amEdgeNotFound), Ord(LMap.RemoveEdge(1, 2)));
  finally
    LMap.Free;
  end;
end;

procedure TestAdjMapClose;
var
  LMap: TAdjMapImpl;
begin
  LMap := TAdjMapImpl.Create(16);
  try
    LMap.AddVertex(1);
    LMap.Close;
    Check(LMap.IsClosed, 'Should be closed');
    CheckEqual(Ord(amClosed), Ord(LMap.AddVertex(2)));
  finally
    LMap.Free;
  end;
end;

procedure TestAdjMapLargeWeights;
var
  LMap: TAdjMapImpl;
  LResult: TPathResult;
begin
  LMap := TAdjMapImpl.Create(8);
  try
    LMap.AddVertex(1);
    LMap.AddVertex(2);
    LMap.AddVertex(3);
    LMap.AddEdge(1, 2, 3000000000);
    LMap.AddEdge(2, 3, 5);
    LMap.AddEdge(1, 3, 4000000000);

    CheckEqual(Ord(amOk), Ord(LMap.Dijkstra(1, 3, LResult)));
    CheckEqual(Int64(3000000005), LResult.FDistance);
    Check(LResult.FPathLen = 3, 'Large-weight path should still choose 1->2->3');
    SetLength(LResult.FPath, 0);
  finally
    LMap.Free;
  end;
end;

procedure TestAdjMapInvalidWeightAndOverflow;
var
  LMap: TAdjMapImpl;
  LResult: TPathResult;
begin
  LMap := TAdjMapImpl.Create(8);
  try
    LMap.AddVertex(1);
    LMap.AddVertex(2);
    LMap.AddVertex(3);
    CheckEqual(Ord(amInvalidWeight), Ord(LMap.AddEdge(1, 2, -1)));
    CheckEqual(0, LMap.GetEdgeCount);

    LMap.AddEdge(1, 2, High(Int64) div 2 - 5);
    LMap.AddEdge(2, 3, High(Int64) - 10);
    LResult.FPathLen := 2;
    LResult.FDistance := 123;
    SetLength(LResult.FPath, 2);
    CheckEqual(Ord(amDistanceOverflow),
      Ord(LMap.Dijkstra(1, 3, LResult)));
    Check(LResult.FPathLen = 0, 'Overflow clears path length');
    Check(LResult.FDistance = -1, 'Overflow clears distance');
    Check(Length(LResult.FPath) = 0, 'Overflow clears path storage');
  finally
    SetLength(LResult.FPath, 0);
    LMap.Free;
  end;
end;

procedure TestAdjMapBoundaryResults;
var
  LMap: TAdjMapImpl;
  LResult: TPathResult;
begin
  LMap := TAdjMapImpl.Create(4);
  try
    LMap.AddVertex(7);
    CheckEqual(Ord(amOk), Ord(LMap.Dijkstra(7, 7, LResult)));
    Check(LResult.FPathLen = 1, 'Source-to-self path has one vertex');
    Check(LResult.FDistance = 0, 'Source-to-self distance is zero');
    SetLength(LResult.FPath, 0);

    LResult.FPathLen := 1;
    LResult.FDistance := 99;
    SetLength(LResult.FPath, 1);
    CheckEqual(Ord(amVertexNotFound), Ord(LMap.Dijkstra(8, 7, LResult)));
    Check(LResult.FPathLen = 0, 'Missing source clears path length');
    Check(LResult.FDistance = -1, 'Missing source clears distance');
    Check(Length(LResult.FPath) = 0, 'Missing source clears path storage');
  finally
    SetLength(LResult.FPath, 0);
    LMap.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_adjmap ===');
  WriteLn;

  TestAdjMapBasic;
  WriteLn('  + Basic vertex/edge');

  TestAdjMapDijkstra;
  WriteLn('  + Dijkstra shortest path');

  TestAdjMapNoPath;
  WriteLn('  + No path');

  TestAdjMapRemoveEdge;
  WriteLn('  + Remove edge');

  TestAdjMapLargeWeights;
  WriteLn('  + Large weights');

  TestAdjMapInvalidWeightAndOverflow;
  WriteLn('  + Invalid weight and overflow');

  TestAdjMapBoundaryResults;
  WriteLn('  + Boundary results');

  TestAdjMapClose;
  WriteLn('  + Close semantics');

  WriteLn;
  WriteLn('All AdjMap tests passed!');
end.
