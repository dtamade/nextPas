unit nextpas.core.lockfree.dag;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TDagResult = (dagOk, dagNotFound, dagExists, dagCycle, dagClosed);

  PDagEdge = ^TDagEdge;
  TDagEdge = record
    TargetId: Int64;
    Next: PDagEdge;
  end;

  PDagNode = ^TDagNode;
  TDagNode = record
    Id: Int64;
    InCount: Int32;
    OutEdges: PDagEdge;
    Next: PDagNode;
    Lock: Int32;
  end;

  TDagTopoCallback = reference to procedure(AId: Int64);

  {** @desc 有向无环图（DAG）
    @details 基于邻接表的并发有向无环图。
      支持拓扑排序、环检测、路径查找。
      每节点自旋锁保证并发安全。
      适用场景：依赖解析、任务调度、构建系统。
  }
  TConcurrentDAG = class
  private
    FRoot: PDagNode;
    FNodeCount: Int64;
    FEdgeCount: Int64;
    FLock: Int32;
    FClosed: Int32;
    function FindNode(AId: Int64): PDagNode;
    function HasPathLocked(AStartId, ATargetId: Int64): Boolean;
    function RemoveIncomingEdgesLocked(ATargetId: Int64): Int64;
    procedure LockDag;
    procedure UnlockDag;
    procedure LockNode(ANode: PDagNode);
    procedure UnlockNode(ANode: PDagNode);
    procedure FreeNode(ANode: PDagNode);
    function HasCycleDFS(AId: Int64; var AVisited, AStack: array of Int64;
      var AVisitedCount, AStackCount: Int32): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function AddNode(AId: Int64): TDagResult;
    function RemoveNode(AId: Int64): TDagResult;
    function AddEdge(AFromId, AToId: Int64): TDagResult;
    function RemoveEdge(AFromId, AToId: Int64): TDagResult;
    function HasEdge(AFromId, AToId: Int64): Boolean;
    function GetNodeCount: Int64;
    function GetEdgeCount: Int64;
    function InDegree(AId: Int64): Int32;
    function OutDegree(AId: Int64): Int32;
    { Returns -1 if the stored graph contains a cycle. }
    function TopologicalSort(out ASorted: array of Int64): Int32;
    function HasCycle: Boolean;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.atomic;

function AllocDagNode(AId: Int64): PDagNode;
begin
  New(Result);
  Result^.Id := AId;
  Result^.InCount := 0;
  Result^.OutEdges := nil;
  Result^.Next := nil;
  Result^.Lock := 0;
end;

function AllocDagEdge(ATargetId: Int64): PDagEdge;
begin
  New(Result);
  Result^.TargetId := ATargetId;
  Result^.Next := nil;
end;

constructor TConcurrentDAG.Create;
begin
  inherited Create;
  FRoot := nil;
  FNodeCount := 0;
  FEdgeCount := 0;
  FLock := 0;
  FClosed := 0;
end;

destructor TConcurrentDAG.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TConcurrentDAG.FindNode(AId: Int64): PDagNode;
begin
  Result := FRoot;
  while Result <> nil do
  begin
    if Result^.Id = AId then
      Exit;
    Result := Result^.Next;
  end;
end;

function TConcurrentDAG.HasPathLocked(AStartId, ATargetId: Int64): Boolean;
var
  LVisited: array of Int64;
  LStack: array of Int64;
  LVisitedCount, LStackCount: Int32;

  function AlreadySeen(AId: Int64; const AItems: array of Int64; ACount: Int32): Boolean;
  var
    LI: Int32;
  begin
    for LI := 0 to ACount - 1 do
      if AItems[LI] = AId then
        Exit(True);
    Result := False;
  end;

  function Visit(AId: Int64): Boolean;
  var
    LNode: PDagNode;
    LEdge: PDagEdge;
  begin
    if AId = ATargetId then
      Exit(True);
    if AlreadySeen(AId, LVisited, LVisitedCount) then
      Exit(False);
    LVisited[LVisitedCount] := AId;
    Inc(LVisitedCount);
    LNode := FindNode(AId);
    if LNode = nil then
      Exit(False);
    LStack[LStackCount] := AId;
    Inc(LStackCount);
    LEdge := LNode^.OutEdges;
    while LEdge <> nil do
    begin
      if Visit(LEdge^.TargetId) then
        Exit(True);
      LEdge := LEdge^.Next;
    end;
    Dec(LStackCount);
    Result := False;
  end;

begin
  SetLength(LVisited, AtomicLoad64(FNodeCount, moAcquire));
  SetLength(LStack, Length(LVisited));
  LVisitedCount := 0;
  LStackCount := 0;
  Result := Visit(AStartId);
end;

function TConcurrentDAG.RemoveIncomingEdgesLocked(ATargetId: Int64): Int64;
var
  LNode: PDagNode;
  LPrevEdge, LEdge, LNextEdge: PDagEdge;
begin
  Result := 0;
  LNode := FRoot;
  while LNode <> nil do
  begin
    LPrevEdge := nil;
    LEdge := LNode^.OutEdges;
    while LEdge <> nil do
    begin
      LNextEdge := LEdge^.Next;
      if LEdge^.TargetId = ATargetId then
      begin
        if LPrevEdge = nil then
          LNode^.OutEdges := LNextEdge
        else
          LPrevEdge^.Next := LNextEdge;
        Dispose(LEdge);
        Inc(Result);
      end
      else
        LPrevEdge := LEdge;
      LEdge := LNextEdge;
    end;
    LNode := LNode^.Next;
  end;
end;

procedure TConcurrentDAG.LockNode(ANode: PDagNode);
begin
  while AtomicCompareExchange32(ANode^.Lock, 0, 1) <> 0 do
    CpuPause;
end;

procedure TConcurrentDAG.UnlockNode(ANode: PDagNode);
begin
  AtomicStore32(ANode^.Lock, 0, moRelease);
end;

procedure TConcurrentDAG.LockDag;
begin
  while AtomicCompareExchange32(FLock, 0, 1) <> 0 do
    CpuPause;
end;

procedure TConcurrentDAG.UnlockDag;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

procedure TConcurrentDAG.FreeNode(ANode: PDagNode);
var
  LEdge, LNext: PDagEdge;
begin
  if ANode = nil then
    Exit;
  LEdge := ANode^.OutEdges;
  while LEdge <> nil do
  begin
    LNext := LEdge^.Next;
    Dispose(LEdge);
    LEdge := LNext;
  end;
  Dispose(ANode);
end;

function TConcurrentDAG.AddNode(AId: Int64): TDagResult;
var
  LNode: PDagNode;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(dagClosed);
  LockDag;
  if FindNode(AId) <> nil then
  begin
    UnlockDag;
    Exit(dagExists);
  end;
  LNode := AllocDagNode(AId);
  LNode^.Next := FRoot;
  FRoot := LNode;
  AtomicFetchAdd64(FNodeCount, 1, moRelaxed);
  UnlockDag;
  Result := dagOk;
end;

function TConcurrentDAG.RemoveNode(AId: Int64): TDagResult;
var
  LPrev, LCurrent: PDagNode;
  LTarget: PDagNode;
  LEdge, LNextEdge: PDagEdge;
  LRemovedEdges: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(dagClosed);
  LockDag;
  { Remove node from list }
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
      LEdge := LCurrent^.OutEdges;
      while LEdge <> nil do
      begin
        LNextEdge := LEdge^.Next;
        LTarget := FindNode(LEdge^.TargetId);
        if LTarget <> nil then
          AtomicFetchSub32(LTarget^.InCount, 1, moRelaxed);
        Inc(LRemovedEdges);
        Dispose(LEdge);
        LEdge := LNextEdge;
      end;
      if LRemovedEdges > 0 then
        AtomicFetchSub64(FEdgeCount, LRemovedEdges, moRelaxed);
      LCurrent^.OutEdges := nil;
      Dispose(LCurrent);
      AtomicFetchSub64(FNodeCount, 1, moRelaxed);
      UnlockDag;
      Exit(dagOk);
    end;
    LPrev := LCurrent;
    LCurrent := LCurrent^.Next;
  end;
  UnlockDag;
  Result := dagNotFound;
end;

function TConcurrentDAG.AddEdge(AFromId, AToId: Int64): TDagResult;
var
  LFrom, LTo: PDagNode;
  LEdge: PDagEdge;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(dagClosed);
  LockDag;
  try
    LFrom := FindNode(AFromId);
    if LFrom = nil then
      Exit(dagNotFound);
    LTo := FindNode(AToId);
    if LTo = nil then
      Exit(dagNotFound);
    LockNode(LFrom);
    try
      LEdge := LFrom^.OutEdges;
      while LEdge <> nil do
      begin
        if LEdge^.TargetId = AToId then
          Exit(dagExists);
        LEdge := LEdge^.Next;
      end;
      if (AFromId = AToId) or HasPathLocked(AToId, AFromId) then
        Exit(dagCycle);
      LEdge := AllocDagEdge(AToId);
      LEdge^.Next := LFrom^.OutEdges;
      LFrom^.OutEdges := LEdge;
      AtomicFetchAdd32(LTo^.InCount, 1, moRelaxed);
      AtomicFetchAdd64(FEdgeCount, 1, moRelaxed);
      Result := dagOk;
    finally
      UnlockNode(LFrom);
    end;
  finally
    UnlockDag;
  end;
end;

function TConcurrentDAG.RemoveEdge(AFromId, AToId: Int64): TDagResult;
var
  LFrom, LTo: PDagNode;
  LPrev, LCurrent: PDagEdge;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(dagClosed);
  LockDag;
  try
    LFrom := FindNode(AFromId);
    if LFrom = nil then
      Exit(dagNotFound);
    LTo := FindNode(AToId);
    if LTo = nil then
      Exit(dagNotFound);
    LockNode(LFrom);
    try
      LPrev := nil;
      LCurrent := LFrom^.OutEdges;
      while LCurrent <> nil do
      begin
        if LCurrent^.TargetId = AToId then
        begin
          if LPrev = nil then
            LFrom^.OutEdges := LCurrent^.Next
          else
            LPrev^.Next := LCurrent^.Next;
          AtomicFetchSub32(LTo^.InCount, 1, moRelaxed);
          AtomicFetchSub64(FEdgeCount, 1, moRelaxed);
          Dispose(LCurrent);
          Exit(dagOk);
        end;
        LPrev := LCurrent;
        LCurrent := LCurrent^.Next;
      end;
      Result := dagNotFound;
    finally
      UnlockNode(LFrom);
    end;
  finally
    UnlockDag;
  end;
end;

function TConcurrentDAG.HasEdge(AFromId, AToId: Int64): Boolean;
var
  LFrom: PDagNode;
  LEdge: PDagEdge;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  LockDag;
  try
    LFrom := FindNode(AFromId);
    if LFrom = nil then
      Exit(False);
    LockNode(LFrom);
    try
      LEdge := LFrom^.OutEdges;
      while LEdge <> nil do
      begin
        if LEdge^.TargetId = AToId then
          Exit(True);
        LEdge := LEdge^.Next;
      end;
      Result := False;
    finally
      UnlockNode(LFrom);
    end;
  finally
    UnlockDag;
  end;
end;

function TConcurrentDAG.GetNodeCount: Int64;
begin
  Result := AtomicLoad64(FNodeCount, moAcquire);
end;

function TConcurrentDAG.GetEdgeCount: Int64;
begin
  Result := AtomicLoad64(FEdgeCount, moAcquire);
end;

function TConcurrentDAG.InDegree(AId: Int64): Int32;
var
  LNode: PDagNode;
begin
  LockDag;
  try
    LNode := FindNode(AId);
    if LNode = nil then
      Exit(-1);
    Result := AtomicLoad32(LNode^.InCount, moAcquire);
  finally
    UnlockDag;
  end;
end;

function TConcurrentDAG.OutDegree(AId: Int64): Int32;
var
  LNode: PDagNode;
  LEdge: PDagEdge;
begin
  LockDag;
  try
    LNode := FindNode(AId);
    if LNode = nil then
      Exit(-1);
    Result := 0;
    LockNode(LNode);
    try
      LEdge := LNode^.OutEdges;
      while LEdge <> nil do
      begin
        Inc(Result);
        LEdge := LEdge^.Next;
      end;
    finally
      UnlockNode(LNode);
    end;
  finally
    UnlockDag;
  end;
end;

function TConcurrentDAG.TopologicalSort(out ASorted: array of Int64): Int32;
var
  LInDeg: array of Int32;
  LIds: array of Int64;
  LOrder: array of Int64;
  LCount, LProcessed, LWriteCount, LI: Int32;
  LNode: PDagNode;
  LEdge: PDagEdge;
  LQueue: array of Int64;
  LQHead, LQTail: Int32;
  LCurrent: Int64;
begin
  LockDag;
  try
    LCount := FNodeCount;
    if LCount <= 0 then
      Exit(0);
    SetLength(LInDeg, LCount);
    SetLength(LIds, LCount);
    SetLength(LOrder, LCount);
    SetLength(LQueue, LCount);

    LI := 0;
    LNode := FRoot;
    while (LNode <> nil) and (LI < LCount) do
    begin
      LIds[LI] := LNode^.Id;
      LInDeg[LI] := LNode^.InCount;
      Inc(LI);
      LNode := LNode^.Next;
    end;
    LCount := LI;

    LQHead := 0;
    LQTail := 0;
    for LI := 0 to LCount - 1 do
      if LInDeg[LI] = 0 then
      begin
        LQueue[LQTail] := LIds[LI];
        Inc(LQTail);
      end;

    LProcessed := 0;
    while LQHead < LQTail do
    begin
      LCurrent := LQueue[LQHead];
      Inc(LQHead);
      LOrder[LProcessed] := LCurrent;
      Inc(LProcessed);
      LNode := FindNode(LCurrent);
      if LNode <> nil then
      begin
        LEdge := LNode^.OutEdges;
        while LEdge <> nil do
        begin
          for LI := 0 to LCount - 1 do
            if LIds[LI] = LEdge^.TargetId then
            begin
              Dec(LInDeg[LI]);
              if LInDeg[LI] = 0 then
              begin
                LQueue[LQTail] := LIds[LI];
                Inc(LQTail);
              end;
              Break;
            end;
          LEdge := LEdge^.Next;
        end;
      end;
    end;

    if LProcessed <> LCount then
      Exit(-1);
    LWriteCount := LProcessed;
    if LWriteCount > Length(ASorted) then
      LWriteCount := Length(ASorted);
    for LI := 0 to LWriteCount - 1 do
      ASorted[LI] := LOrder[LI];
    Result := LWriteCount;
  finally
    UnlockDag;
  end;
end;

function TConcurrentDAG.HasCycleDFS(AId: Int64; var AVisited, AStack: array of Int64;
  var AVisitedCount, AStackCount: Int32): Boolean;
var
  LNode: PDagNode;
  LEdge: PDagEdge;
  LI: Int32;
  LInStack: Boolean;
begin
  { Mark as visited and add to stack }
  AVisited[AVisitedCount] := AId;
  Inc(AVisitedCount);
  AStack[AStackCount] := AId;
  Inc(AStackCount);
  LNode := FindNode(AId);
  if LNode = nil then
  begin
    Dec(AStackCount);
    Exit(False);
  end;
  LockNode(LNode);
  LEdge := LNode^.OutEdges;
  while LEdge <> nil do
  begin
    { Check if target is in current stack (cycle) }
    LInStack := False;
    for LI := 0 to AStackCount - 1 do
      if AStack[LI] = LEdge^.TargetId then
      begin
        LInStack := True;
        Break;
      end;
    if LInStack then
    begin
      UnlockNode(LNode);
      Exit(True);
    end;
    { Check if not visited, recurse }
    LInStack := False;
    for LI := 0 to AVisitedCount - 1 do
      if AVisited[LI] = LEdge^.TargetId then
      begin
        LInStack := True;
        Break;
      end;
    if not LInStack then
      if HasCycleDFS(LEdge^.TargetId, AVisited, AStack, AVisitedCount, AStackCount) then
      begin
        UnlockNode(LNode);
        Exit(True);
      end;
    LEdge := LEdge^.Next;
  end;
  UnlockNode(LNode);
  Dec(AStackCount);
  Result := False;
end;

function TConcurrentDAG.HasCycle: Boolean;
var
  LVisited, LStack: array of Int64;
  LVisitedCount, LStackCount: Int32;
  LCount: Int64;
  LNode: PDagNode;
  LI: Int32;
  LAlreadyVisited: Boolean;
begin
  LockDag;
  try
    LCount := FNodeCount;
    if LCount = 0 then
      Exit(False);
    SetLength(LVisited, LCount);
    SetLength(LStack, LCount);
    LVisitedCount := 0;
    LStackCount := 0;
    LNode := FRoot;
    while LNode <> nil do
    begin
      LAlreadyVisited := False;
      for LI := 0 to LVisitedCount - 1 do
        if LVisited[LI] = LNode^.Id then
        begin
          LAlreadyVisited := True;
          Break;
        end;
      if not LAlreadyVisited then
        if HasCycleDFS(LNode^.Id, LVisited, LStack, LVisitedCount,
          LStackCount) then
          Exit(True);
      LNode := LNode^.Next;
    end;
    Result := False;
  finally
    UnlockDag;
  end;
end;

procedure TConcurrentDAG.Clear;
var
  LNode, LNext: PDagNode;
begin
  LockDag;
  LNode := FRoot;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    FreeNode(LNode);
    LNode := LNext;
  end;
  FRoot := nil;
  AtomicStore64(FNodeCount, 0, moRelaxed);
  AtomicStore64(FEdgeCount, 0, moRelaxed);
  UnlockDag;
end;

procedure TConcurrentDAG.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentDAG.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
