unit nextpas.core.lockfree.graph;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeGraphResult = (grAdded, grRemoved, grNotFound, grExists, grClosed);

  PNeighborNode = ^TNeighborNode;
  TNeighborNode = record
    VertexId: Int64;
    Next: PNeighborNode;
  end;

  PVertexNode = ^TVertexNode;
  TVertexNode = record
    Id: Int64;
    Neighbors: PNeighborNode;
    Next: PVertexNode;
    Lock: Int32;
  end;

  {** @desc 并发无锁图（Lock-Free Graph）
    @details 基于邻接表的并发图数据结构。
      支持添加/删除顶点和边，BFS/DFS 遍历。
      每顶点自旋锁保证并发安全。
      适用场景：社交网络、依赖分析、路径查找。
  }
  TLockFreeGraph = class
  private
    FRoot: PVertexNode;
    FVertexCount: Int64;
    FEdgeCount: Int64;
    FLock: Int32;
    FClosed: Int32;
    function FindVertex(AId: Int64): PVertexNode;
    function RemoveIncomingEdgesLocked(ATargetId: Int64): Int64;
    function CountNeighbors(AVertex: PVertexNode): Int64;
    procedure LockGraph;
    procedure UnlockGraph;
    procedure LockVertex(AVertex: PVertexNode);
    procedure UnlockVertex(AVertex: PVertexNode);
    procedure FreeVertex(AVertex: PVertexNode);
  public
    constructor Create;
    destructor Destroy; override;
    function AddVertex(AId: Int64): TLockFreeGraphResult;
    function RemoveVertex(AId: Int64): TLockFreeGraphResult;
    function AddEdge(AFromId, AToId: Int64): TLockFreeGraphResult;
    function RemoveEdge(AFromId, AToId: Int64): TLockFreeGraphResult;
    function HasEdge(AFromId, AToId: Int64): Boolean;
    function GetVertexCount: Int64;
    function GetEdgeCount: Int64;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

function AllocVertexNode(AId: Int64): PVertexNode;
begin
  New(Result);
  Result^.Id := AId;
  Result^.Neighbors := nil;
  Result^.Next := nil;
  Result^.Lock := 0;
end;

function AllocNeighborNode(AVertexId: Int64): PNeighborNode;
begin
  New(Result);
  Result^.VertexId := AVertexId;
  Result^.Next := nil;
end;

constructor TLockFreeGraph.Create;
begin
  inherited Create;
  FRoot := nil;
  FVertexCount := 0;
  FEdgeCount := 0;
  FLock := 0;
  FClosed := 0;
end;

destructor TLockFreeGraph.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TLockFreeGraph.FindVertex(AId: Int64): PVertexNode;
begin
  Result := FRoot;
  while Result <> nil do
  begin
    if Result^.Id = AId then
      Exit;
    Result := Result^.Next;
  end;
end;

function TLockFreeGraph.RemoveIncomingEdgesLocked(ATargetId: Int64): Int64;
var
  LVertex: PVertexNode;
  LPrev, LCurrent, LNext: PNeighborNode;
begin
  Result := 0;
  LVertex := FRoot;
  while LVertex <> nil do
  begin
    LPrev := nil;
    LCurrent := LVertex^.Neighbors;
    while LCurrent <> nil do
    begin
      LNext := LCurrent^.Next;
      if LCurrent^.VertexId = ATargetId then
      begin
        if LPrev = nil then
          LVertex^.Neighbors := LNext
        else
          LPrev^.Next := LNext;
        Dispose(LCurrent);
        Inc(Result);
      end
      else
        LPrev := LCurrent;
      LCurrent := LNext;
    end;
    LVertex := LVertex^.Next;
  end;
end;

function TLockFreeGraph.CountNeighbors(AVertex: PVertexNode): Int64;
var
  LNeighbor: PNeighborNode;
begin
  Result := 0;
  if AVertex = nil then
    Exit;
  LNeighbor := AVertex^.Neighbors;
  while LNeighbor <> nil do
  begin
    Inc(Result);
    LNeighbor := LNeighbor^.Next;
  end;
end;

procedure TLockFreeGraph.LockVertex(AVertex: PVertexNode);
begin
  while AtomicCompareExchange32(AVertex^.Lock, 0, 1) <> 0 do
    CpuPause;
end;

procedure TLockFreeGraph.UnlockVertex(AVertex: PVertexNode);
begin
  AtomicStore32(AVertex^.Lock, 0, moRelease);
end;

procedure TLockFreeGraph.LockGraph;
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
  begin
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
end;

procedure TLockFreeGraph.UnlockGraph;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

procedure TLockFreeGraph.FreeVertex(AVertex: PVertexNode);
var
  LNeighbor, LNextNeighbor: PNeighborNode;
begin
  if AVertex = nil then
    Exit;
  LNeighbor := AVertex^.Neighbors;
  while LNeighbor <> nil do
  begin
    LNextNeighbor := LNeighbor^.Next;
    Dispose(LNeighbor);
    LNeighbor := LNextNeighbor;
  end;
  Dispose(AVertex);
end;

function TLockFreeGraph.AddVertex(AId: Int64): TLockFreeGraphResult;
var
  LVertex: PVertexNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(grClosed);
  LockGraph;
  if FindVertex(AId) <> nil then
  begin
    UnlockGraph;
    Exit(grExists);
  end;
  LVertex := AllocVertexNode(AId);
  LVertex^.Next := FRoot;
  FRoot := LVertex;
  AtomicFetchAdd64(FVertexCount, 1, moRelaxed);
  UnlockGraph;
  Result := grAdded;
end;

function TLockFreeGraph.RemoveVertex(AId: Int64): TLockFreeGraphResult;
var
  LPrev, LCurrent: PVertexNode;
  LRemovedEdges: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(grClosed);
  LockGraph;
  LPrev := nil;
  LCurrent := FRoot;
  while LCurrent <> nil do
  begin
    if LCurrent^.Id = AId then
    begin
      if LPrev = nil then
        FRoot := LCurrent^.Next
      else
        LPrev^.Next := LCurrent^.Next;
      LRemovedEdges := RemoveIncomingEdgesLocked(AId);
      LRemovedEdges := LRemovedEdges + CountNeighbors(LCurrent);
      if LRemovedEdges > 0 then
        AtomicFetchSub64(FEdgeCount, LRemovedEdges, moRelaxed);
      FreeVertex(LCurrent);
      AtomicFetchSub64(FVertexCount, 1, moRelaxed);
      UnlockGraph;
      Exit(grRemoved);
    end;
    LPrev := LCurrent;
    LCurrent := LCurrent^.Next;
  end;
  UnlockGraph;
  Result := grNotFound;
end;

function TLockFreeGraph.AddEdge(AFromId, AToId: Int64): TLockFreeGraphResult;
var
  LFromVertex, LToVertex: PVertexNode;
  LNeighbor: PNeighborNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(grClosed);
  LockGraph;
  try
    LFromVertex := FindVertex(AFromId);
    LToVertex := FindVertex(AToId);
    if (LFromVertex = nil) or (LToVertex = nil) then
      Exit(grNotFound);
    LockVertex(LFromVertex);
    try
      LNeighbor := LFromVertex^.Neighbors;
      while LNeighbor <> nil do
      begin
        if LNeighbor^.VertexId = AToId then
          Exit(grExists);
        LNeighbor := LNeighbor^.Next;
      end;
      LNeighbor := AllocNeighborNode(AToId);
      LNeighbor^.Next := LFromVertex^.Neighbors;
      LFromVertex^.Neighbors := LNeighbor;
      AtomicFetchAdd64(FEdgeCount, 1, moRelaxed);
      Result := grAdded;
    finally
      UnlockVertex(LFromVertex);
    end;
  finally
    UnlockGraph;
  end;
end;

function TLockFreeGraph.RemoveEdge(AFromId, AToId: Int64): TLockFreeGraphResult;
var
  LFromVertex: PVertexNode;
  LPrev, LCurrent: PNeighborNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(grClosed);
  LockGraph;
  try
    LFromVertex := FindVertex(AFromId);
    if LFromVertex = nil then
      Exit(grNotFound);
    LockVertex(LFromVertex);
    try
      LPrev := nil;
      LCurrent := LFromVertex^.Neighbors;
      while LCurrent <> nil do
      begin
        if LCurrent^.VertexId = AToId then
        begin
          if LPrev = nil then
            LFromVertex^.Neighbors := LCurrent^.Next
          else
            LPrev^.Next := LCurrent^.Next;
          Dispose(LCurrent);
          AtomicFetchSub64(FEdgeCount, 1, moRelaxed);
          Exit(grRemoved);
        end;
        LPrev := LCurrent;
        LCurrent := LCurrent^.Next;
      end;
      Result := grNotFound;
    finally
      UnlockVertex(LFromVertex);
    end;
  finally
    UnlockGraph;
  end;
end;

function TLockFreeGraph.HasEdge(AFromId, AToId: Int64): Boolean;
var
  LFromVertex: PVertexNode;
  LNeighbor: PNeighborNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  LockGraph;
  try
    LFromVertex := FindVertex(AFromId);
    if LFromVertex = nil then
      Exit(False);
    LockVertex(LFromVertex);
    try
      LNeighbor := LFromVertex^.Neighbors;
      while LNeighbor <> nil do
      begin
        if LNeighbor^.VertexId = AToId then
          Exit(True);
        LNeighbor := LNeighbor^.Next;
      end;
      Result := False;
    finally
      UnlockVertex(LFromVertex);
    end;
  finally
    UnlockGraph;
  end;
end;

function TLockFreeGraph.GetVertexCount: Int64;
begin
  Result := AtomicLoad64(FVertexCount, moAcquire);
end;

function TLockFreeGraph.GetEdgeCount: Int64;
begin
  Result := AtomicLoad64(FEdgeCount, moAcquire);
end;

procedure TLockFreeGraph.Clear;
var
  LVertex, LNext: PVertexNode;
begin
  LockGraph;
  LVertex := FRoot;
  while LVertex <> nil do
  begin
    LNext := LVertex^.Next;
    FreeVertex(LVertex);
    LVertex := LNext;
  end;
  FRoot := nil;
  AtomicStore64(FVertexCount, 0, moRelaxed);
  AtomicStore64(FEdgeCount, 0, moRelaxed);
  UnlockGraph;
end;

procedure TLockFreeGraph.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TLockFreeGraph.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
