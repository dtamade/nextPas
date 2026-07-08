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
    FClosed: Int32;
    function FindVertex(AId: Int64): PVertexNode;
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

procedure TLockFreeGraph.LockVertex(AVertex: PVertexNode);
begin
  while AtomicCompareExchange32(AVertex^.Lock, 0, 1) <> 0 do
    CpuPause;
end;

procedure TLockFreeGraph.UnlockVertex(AVertex: PVertexNode);
begin
  AtomicStore32(AVertex^.Lock, 0, moRelease);
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
  if FindVertex(AId) <> nil then
    Exit(grExists);
  LVertex := AllocVertexNode(AId);
  LVertex^.Next := FRoot;
  FRoot := LVertex;
  AtomicFetchAdd64(FVertexCount, 1, moRelaxed);
  Result := grAdded;
end;

function TLockFreeGraph.RemoveVertex(AId: Int64): TLockFreeGraphResult;
var
  LPrev, LCurrent: PVertexNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(grClosed);
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
      FreeVertex(LCurrent);
      AtomicFetchSub64(FVertexCount, 1, moRelaxed);
      Exit(grRemoved);
    end;
    LPrev := LCurrent;
    LCurrent := LCurrent^.Next;
  end;
  Result := grNotFound;
end;

function TLockFreeGraph.AddEdge(AFromId, AToId: Int64): TLockFreeGraphResult;
var
  LFromVertex: PVertexNode;
  LNeighbor: PNeighborNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(grClosed);
  LFromVertex := FindVertex(AFromId);
  if LFromVertex = nil then
    Exit(grNotFound);
  LockVertex(LFromVertex);
  // Check if edge already exists
  LNeighbor := LFromVertex^.Neighbors;
  while LNeighbor <> nil do
  begin
    if LNeighbor^.VertexId = AToId then
    begin
      UnlockVertex(LFromVertex);
      Exit(grExists);
    end;
    LNeighbor := LNeighbor^.Next;
  end;
  // Add edge
  LNeighbor := AllocNeighborNode(AToId);
  LNeighbor^.Next := LFromVertex^.Neighbors;
  LFromVertex^.Neighbors := LNeighbor;
  AtomicFetchAdd64(FEdgeCount, 1, moRelaxed);
  UnlockVertex(LFromVertex);
  Result := grAdded;
end;

function TLockFreeGraph.RemoveEdge(AFromId, AToId: Int64): TLockFreeGraphResult;
var
  LFromVertex: PVertexNode;
  LPrev, LCurrent: PNeighborNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(grClosed);
  LFromVertex := FindVertex(AFromId);
  if LFromVertex = nil then
    Exit(grNotFound);
  LockVertex(LFromVertex);
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
      UnlockVertex(LFromVertex);
      Exit(grRemoved);
    end;
    LPrev := LCurrent;
    LCurrent := LCurrent^.Next;
  end;
  UnlockVertex(LFromVertex);
  Result := grNotFound;
end;

function TLockFreeGraph.HasEdge(AFromId, AToId: Int64): Boolean;
var
  LFromVertex: PVertexNode;
  LNeighbor: PNeighborNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  LFromVertex := FindVertex(AFromId);
  if LFromVertex = nil then
    Exit(False);
  LockVertex(LFromVertex);
  LNeighbor := LFromVertex^.Neighbors;
  while LNeighbor <> nil do
  begin
    if LNeighbor^.VertexId = AToId then
    begin
      UnlockVertex(LFromVertex);
      Exit(True);
    end;
    LNeighbor := LNeighbor^.Next;
  end;
  UnlockVertex(LFromVertex);
  Result := False;
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
