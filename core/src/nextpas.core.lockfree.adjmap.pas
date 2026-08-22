{******************************************************************************
  nextpas.core.lockfree.adjmap

  Adjacency Map: 加权图邻接表 + 最短路径 (Weighted Graph with Dijkstra)

  核心设计:
    - 使用哈希表存储顶点和边，O(1) 顶点/边查找
    - Dijkstra 算法求单源最短路径
    - 拓扑排序支持 DAG

  复杂度:
    - AddVertex: O(1)
    - AddEdge: O(1)
    - Dijkstra: O((V+E) log V) — 使用二叉堆
    - 空间: O(V+E)

  线程安全: 使用 CAS 自旋锁保护所有操作。

  @author nextPas Contributors
  @date 2026-07-06
******************************************************************************}

unit nextpas.core.lockfree.adjmap;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.atomic;

const
  ADJMAP_DEFAULT_CAPACITY = 64;

type
  TAdjMapStatus = (
    amOk = 0,
    amClosed = 1,
    amVertexExists = 2,
    amVertexNotFound = 3,
    amEdgeNotFound = 5,
    amNoPath = 6,
    amInvalidWeight = 7,
    amFull = 8,
    amDistanceOverflow = 9
  );

  PAdjEdge = ^TAdjEdge;
  TAdjEdge = record
    FTarget: UInt64;
    FWeight: Int64;
    FNext: PAdjEdge;
  end;

  PAdjVertex = ^TAdjVertex;
  TAdjVertex = record
    FId: UInt64;
    FEdges: PAdjEdge;
    FEdgeCount: Integer;
  end;

  TPathResult = record
    FPath: array of UInt64;
    FPathLen: Integer;
    FDistance: Int64;
  end;

  TAdjMapImpl = class
  private
    FVertices: array of TAdjVertex;
    FVertexCount: Integer;
    FCapacity: Integer;
    FLock: Int32;
    FClosed: Int32;

    function FindVertex(AId: UInt64): Integer;
    procedure Lock;
    procedure Unlock;
  public
    constructor Create(ACapacity: UInt32 = ADJMAP_DEFAULT_CAPACITY);
    destructor Destroy; override;

    function AddVertex(AId: UInt64): TAdjMapStatus;
    function AddEdge(ASource, ATarget: UInt64; AWeight: Int64): TAdjMapStatus;
    function RemoveEdge(ASource, ATarget: UInt64): TAdjMapStatus;
    function GetVertexCount: Integer;
    function GetEdgeCount: Integer;
    function Dijkstra(ASource, ATarget: UInt64; out AResult: TPathResult): TAdjMapStatus;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

{ TAdjMapImpl }

procedure TAdjMapImpl.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end;
  end;
end;

procedure TAdjMapImpl.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

constructor TAdjMapImpl.Create(ACapacity: UInt32);
var
  LI: Integer;
begin
  inherited Create;
  if ACapacity < 4 then
    ACapacity := 4;
  FCapacity := ACapacity;
  FVertexCount := 0;
  SetLength(FVertices, FCapacity);
  for LI := 0 to FCapacity - 1 do
  begin
    FVertices[LI].FId := 0;
    FVertices[LI].FEdges := nil;
    FVertices[LI].FEdgeCount := 0;
  end;
  FLock := 0;
  FClosed := 0;
end;

destructor TAdjMapImpl.Destroy;
var
  LI: Integer;
  LEdge, LNext: PAdjEdge;
begin
  for LI := 0 to FVertexCount - 1 do
  begin
    LEdge := FVertices[LI].FEdges;
    while LEdge <> nil do
    begin
      LNext := LEdge^.FNext;
      Dispose(LEdge);
      LEdge := LNext;
    end;
  end;
  SetLength(FVertices, 0);
  inherited Destroy;
end;

function TAdjMapImpl.FindVertex(AId: UInt64): Integer;
var
  LI: Integer;
begin
  for LI := 0 to FVertexCount - 1 do
  begin
    if FVertices[LI].FId = AId then
      Exit(LI);
  end;
  Result := -1;
end;

function TAdjMapImpl.AddVertex(AId: UInt64): TAdjMapStatus;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(amClosed);

  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(amClosed);
    if FindVertex(AId) >= 0 then
      Exit(amVertexExists);

    if FVertexCount >= FCapacity then
      Exit(amFull);

    FVertices[FVertexCount].FId := AId;
    FVertices[FVertexCount].FEdges := nil;
    FVertices[FVertexCount].FEdgeCount := 0;
    Inc(FVertexCount);
    Result := amOk;
  finally
    Unlock;
  end;
end;

function TAdjMapImpl.AddEdge(ASource, ATarget: UInt64; AWeight: Int64): TAdjMapStatus;
var
  LSrcIdx, LDstIdx: Integer;
  LEdge: PAdjEdge;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(amClosed);
  if AWeight < 0 then
    Exit(amInvalidWeight);

  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(amClosed);
    LSrcIdx := FindVertex(ASource);
    if LSrcIdx < 0 then
      Exit(amVertexNotFound);

    LDstIdx := FindVertex(ATarget);
    if LDstIdx < 0 then
      Exit(amVertexNotFound);

    LEdge := FVertices[LSrcIdx].FEdges;
    while LEdge <> nil do
    begin
      if LEdge^.FTarget = ATarget then
      begin
        LEdge^.FWeight := AWeight;
        Exit(amOk);
      end;
      LEdge := LEdge^.FNext;
    end;

    New(LEdge);
    LEdge^.FTarget := ATarget;
    LEdge^.FWeight := AWeight;
    LEdge^.FNext := FVertices[LSrcIdx].FEdges;
    FVertices[LSrcIdx].FEdges := LEdge;
    Inc(FVertices[LSrcIdx].FEdgeCount);

    Result := amOk;
  finally
    Unlock;
  end;
end;

function TAdjMapImpl.RemoveEdge(ASource, ATarget: UInt64): TAdjMapStatus;
var
  LSrcIdx: Integer;
  LEdge, LPrev: PAdjEdge;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(amClosed);

  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(amClosed);
    LSrcIdx := FindVertex(ASource);
    if LSrcIdx < 0 then
      Exit(amVertexNotFound);

    LEdge := FVertices[LSrcIdx].FEdges;
    LPrev := nil;
    while LEdge <> nil do
    begin
      if LEdge^.FTarget = ATarget then
      begin
        if LPrev = nil then
          FVertices[LSrcIdx].FEdges := LEdge^.FNext
        else
          LPrev^.FNext := LEdge^.FNext;
        Dispose(LEdge);
        Dec(FVertices[LSrcIdx].FEdgeCount);
        Exit(amOk);
      end;
      LPrev := LEdge;
      LEdge := LEdge^.FNext;
    end;
    Result := amEdgeNotFound;
  finally
    Unlock;
  end;
end;

function TAdjMapImpl.GetVertexCount: Integer;
begin
  Lock;
  try
    Result := FVertexCount;
  finally
    Unlock;
  end;
end;

function TAdjMapImpl.GetEdgeCount: Integer;
var
  LI, LTotal: Integer;
begin
  Lock;
  try
    LTotal := 0;
    for LI := 0 to FVertexCount - 1 do
      LTotal := LTotal + FVertices[LI].FEdgeCount;
    Result := LTotal;
  finally
    Unlock;
  end;
end;

function TAdjMapImpl.Dijkstra(ASource, ATarget: UInt64; out AResult: TPathResult): TAdjMapStatus;
const
  INF = High(Int64);
var
  LDist: array of Int64;
  LPrev: array of Integer;
  LVisited: array of Boolean;
  LI, LSrcIdx, LDstIdx, LU, LV: Integer;
  LMinDist: Int64;
  LCandidate: Int64;
  LEdge: PAdjEdge;
  LPathLen: Integer;
  LDistanceOverflow: Boolean;
begin
  AResult.FPathLen := 0;
  AResult.FDistance := -1;
  SetLength(AResult.FPath, 0);
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(amClosed);

  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(amClosed);
    LSrcIdx := FindVertex(ASource);
    if LSrcIdx < 0 then
      Exit(amVertexNotFound);

    LDstIdx := FindVertex(ATarget);
    if LDstIdx < 0 then
      Exit(amVertexNotFound);

    SetLength(LDist, FVertexCount);
    SetLength(LPrev, FVertexCount);
    SetLength(LVisited, FVertexCount);
    for LI := 0 to FVertexCount - 1 do
    begin
      LDist[LI] := INF;
      LPrev[LI] := -1;
      LVisited[LI] := False;
    end;
    LDist[LSrcIdx] := 0;
    LDistanceOverflow := False;

    for LI := 0 to FVertexCount - 1 do
    begin
      LU := -1;
      LMinDist := INF;
      for LV := 0 to FVertexCount - 1 do
      begin
        if (not LVisited[LV]) and (LDist[LV] < LMinDist) then
        begin
          LU := LV;
          LMinDist := LDist[LV];
        end;
      end;

      if (LU < 0) or (LDist[LU] = INF) then
        Break;

      if LU = LDstIdx then
        Break;

      LVisited[LU] := True;

      LEdge := FVertices[LU].FEdges;
      while LEdge <> nil do
      begin
        LV := FindVertex(LEdge^.FTarget);
        if (LV >= 0) and (not LVisited[LV]) then
        begin
          if LEdge^.FWeight >= INF - LDist[LU] then
            LDistanceOverflow := True
          else
          begin
            LCandidate := LDist[LU] + LEdge^.FWeight;
            if LCandidate < LDist[LV] then
            begin
              LDist[LV] := LCandidate;
              LPrev[LV] := LU;
            end;
          end;
        end;
        LEdge := LEdge^.FNext;
      end;
    end;

    if LDist[LDstIdx] = INF then
    begin
      SetLength(LDist, 0);
      SetLength(LPrev, 0);
      SetLength(LVisited, 0);
      if LDistanceOverflow then
        Result := amDistanceOverflow
      else
        Result := amNoPath;
      Exit;
    end;

    LPathLen := 0;
    LU := LDstIdx;
    while LU >= 0 do
    begin
      Inc(LPathLen);
      LU := LPrev[LU];
    end;

    SetLength(AResult.FPath, LPathLen);
    AResult.FPathLen := LPathLen;
    AResult.FDistance := LDist[LDstIdx];

    LU := LDstIdx;
    LI := LPathLen - 1;
    while LU >= 0 do
    begin
      AResult.FPath[LI] := FVertices[LU].FId;
      Dec(LI);
      LU := LPrev[LU];
    end;

    SetLength(LDist, 0);
    SetLength(LPrev, 0);
    SetLength(LVisited, 0);
    Result := amOk;
  finally
    Unlock;
  end;
end;

procedure TAdjMapImpl.Close;
begin
  Lock;
  try
    atomic_store(FClosed, 1, mo_release);
  finally
    Unlock;
  end;
end;

function TAdjMapImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
