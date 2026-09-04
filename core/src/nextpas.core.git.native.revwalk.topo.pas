unit nextpas.core.git.native.revwalk.topo;

{$I nextpas.core.settings.inc}

{ revwalk 拓扑序域: 可达子图缓冲 + LIFO 就绪栈发射 (children 先于 parents).
  依赖: base/walker/hashset/parsecache (revwalk.*) + repo/commitgraph. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.revwalk.base,
  nextpas.core.git.native.repo;

type
  { canonical owner is git.native.base; explicit alias pins body resolution
    to the canonical type (commitgraph.base/revwalk.base alias here) }
  TGitOidArray = nextpas.core.git.native.revwalk.base.TGitOidArray;

{ one-shot topological order (children always precede parents, ready set
  drained LIFO exactly like git's default --topo-order): buffers the
  reachable subgraph, so it costs one read+parse per reachable commit up
  front. AMaxCount < 0 means unlimited. }
function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload;
function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload;
function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.git.native.base,
  nextpas.core.git.native.commitgraph,
  nextpas.core.git.native.revwalk.hashset,
  nextpas.core.git.native.revwalk.parsecache,
  nextpas.core.git.native.revwalk.fetch;

{ ── History.Topo: O(E log V) edge parse via SpanCompare binary search, MergeSort O(V log V) ── }
{ ── topological order ───────────────────────────────────────────────────── }

type
  TTopoNode = record
    Oid: TGitOid;
    When: Int64;
    Parents: TGitOidArray;
    ChildCount: SizeInt; { children inside the reachable set }
  end;
  TTopoNodes = array of TTopoNode;
  TNodeIndexArray = array of Integer;

{ stable merge sort of node indices by oid bytes; single shared scratch
  perf: PByte zero-copy window via bytes.ops SpanCopy single source (no managed Move, inline) }
procedure TopoSortRange(var AOrder: TNodeIndexArray;
  var AScratch: TNodeIndexArray; const ANodes: TTopoNodes;
  ALow, AHigh: Integer);
var
  Mid, I, J, K: Integer;
  LBytes: SizeUInt;
begin
  if ALow >= AHigh then
    Exit;
  Mid := (ALow + AHigh) div 2;
  TopoSortRange(AOrder, AScratch, ANodes, ALow, Mid);
  TopoSortRange(AOrder, AScratch, ANodes, Mid + 1, AHigh);
  LBytes := SizeUInt(SizeInt(AHigh - ALow + 1) * SizeOf(Integer));
  // PByte zero-copy view: single Move via bytes.ops SpanCopy single source
  SpanCopy(TByteSpan.Create(@AScratch[ALow], LBytes),
           TByteSpan.Create(@AOrder[ALow], LBytes));
  I := ALow;
  J := Mid + 1;
  K := ALow;
  while (I <= Mid) and (J <= AHigh) do
  begin
    if OidLess(ANodes[AOrder[J]].Oid, ANodes[AOrder[I]].Oid) then
    begin
      AScratch[K] := AOrder[J];
      Inc(J);
    end
    else
    begin
      AScratch[K] := AOrder[I];
      Inc(I);
    end;
    Inc(K);
  end;
  while I <= Mid do
  begin
    AScratch[K] := AOrder[I];
    Inc(I);
    Inc(K);
  end;
  while J <= AHigh do
  begin
    AScratch[K] := AOrder[J];
    Inc(J);
    Inc(K);
  end;
  // PByte zero-copy view back via bytes.ops single source
  SpanCopy(TByteSpan.Create(@AOrder[ALow], LBytes),
           TByteSpan.Create(@AScratch[ALow], LBytes));
end;

{ binary search over the sorted permutation; -1 when absent }
function TopoNodeIndexOf(const AOid: TGitOid; const AOrder: TNodeIndexArray;
  const ANodes: TTopoNodes): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  Result := -1;
  Lo := 0;
  Hi := High(AOrder);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if GitOidSame(ANodes[AOrder[Mid]].Oid, AOid) then
      Exit(AOrder[Mid]);
    if OidLess(ANodes[AOrder[Mid]].Oid, AOid) then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
end;

{ ascending by commit time, stable merge sort O(n log n), mirrors TopoSortRange
  perf: PByte zero-copy via bytes.ops SpanCopy single source }
procedure TopoSortTipsMerge(var ATips: TNodeIndexArray; var AScratch: TNodeIndexArray; const ANodes: TTopoNodes; ALow, AHigh: Integer);
var Mid, I, J, K: Integer; LBytes: SizeUInt;
begin
  if ALow >= AHigh then Exit;
  Mid := (ALow + AHigh) div 2;
  TopoSortTipsMerge(ATips, AScratch, ANodes, ALow, Mid);
  TopoSortTipsMerge(ATips, AScratch, ANodes, Mid + 1, AHigh);
  LBytes := SizeUInt(SizeInt(AHigh - ALow + 1) * SizeOf(Integer));
  SpanCopy(TByteSpan.Create(@AScratch[ALow], LBytes), TByteSpan.Create(@ATips[ALow], LBytes));
  I := ALow; J := Mid + 1; K := ALow;
  while (I <= Mid) and (J <= AHigh) do
  begin
    if ANodes[AScratch[J]].When < ANodes[AScratch[I]].When then
    begin AScratch[K] := AScratch[J]; Inc(J); end
    else
    begin AScratch[K] := AScratch[I]; Inc(I); end;
    Inc(K);
  end;
  while I <= Mid do begin AScratch[K] := AScratch[I]; Inc(I); Inc(K); end;
  while J <= AHigh do begin AScratch[K] := AScratch[J]; Inc(J); Inc(K); end;
  SpanCopy(TByteSpan.Create(@ATips[ALow], LBytes), TByteSpan.Create(@AScratch[ALow], LBytes));
end;

procedure TopoSortTips(var ATips: TNodeIndexArray; const ANodes: TTopoNodes);
var Scratch: TNodeIndexArray;
begin
  if Length(ATips) <= 1 then Exit;
  SetLength(Scratch, Length(ATips));
  TopoSortTipsMerge(ATips, Scratch, ANodes, 0, High(ATips));
end;

function TopoStackPop(var AStack: TNodeIndexArray): Integer;
begin
  Result := -1;
  if Length(AStack) = 0 then
    Exit;
  Result := AStack[High(AStack)];
  SetLength(AStack, High(AStack));
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray;
var
  Nodes: TTopoNodes;
  Order, Scratch, Ready: TNodeIndexArray;
  Seen: TGitOidSet;
  Stack: TGitOidArray;
  Oid: TGitOid;
  I, J, NodeIdx, ParentIdx: Integer;
  Graph: TCommitGraph;
  ParseCache: TCommitParseCache;
  GWhen: Int64;
  GParents: TGitOidArray;
  StackCap, StackLen, NodesLen: SizeInt;
  ResCap, ResCount, ReadyCap, ReadyLen: SizeInt;
  OidMap: TOidIndexMap;
begin
  Result := nil;
  Seen := TGitOidSet.Create;
  Graph := nil;
  ParseCache := TCommitParseCache.Create;
  Nodes := nil;
  NodesLen := 0;
  try
    try if not GitTryLoadCommitGraph(ARepo.GitDir, Graph) then Graph := nil; except Graph := nil; end;
    { phase 1: discover the full reachable set, parsing each commit once }
    Stack := nil; StackCap := 0; StackLen := 0; ResCount := 0; ResCap := 0; ReadyCap := 0; ReadyLen := 0; Ready := nil;
    for I := 0 to High(AStarts) do
    begin
      if StackLen >= StackCap then
      begin StackCap := SizeInt(GrowArrayCapacity(SizeUInt(StackCap), SizeUInt(StackLen + 1))); SetLength(Stack, StackCap); end;
      Stack[StackLen] := AStarts[I]; Inc(StackLen);
    end;
    while StackLen > 0 do
    begin
      Dec(StackLen); Oid := Stack[StackLen];
      if Seen.Contains(Oid) then
        Continue;
      if not TryFetchCommitCached(ARepo, Graph, ParseCache, Oid, GWhen, GParents) then
        raise EGitError.Create('topo walk start points at a non-commit object');
      Seen.Add(Oid);
      if NodesLen >= Length(Nodes) then
      begin
        // geometric growth via bytes.ops, amortized O(1)
        SetLength(Nodes, SizeInt(GrowArrayCapacity(SizeUInt(Length(Nodes)), SizeUInt(NodesLen + 1))));
      end;
      NodeIdx := NodesLen;
      Inc(NodesLen);
      Nodes[NodeIdx].Oid := Oid;
      Nodes[NodeIdx].When := GWhen;
      Nodes[NodeIdx].Parents := GParents; { CoW }
      Nodes[NodeIdx].ChildCount := 0;
      for J := 0 to High(GParents) do
      begin
        if StackLen >= StackCap then
        begin StackCap := SizeInt(GrowArrayCapacity(SizeUInt(StackCap), SizeUInt(StackLen + 1))); SetLength(Stack, StackCap); end;
        Stack[StackLen] := GParents[J]; Inc(StackLen);
      end;
    end;
    SetLength(Stack, StackLen);
    SetLength(Nodes, NodesLen);

    { phase 2: count each node's children within the set; O(E) via hash index }
    SetLength(Order, Length(Nodes));
    for I := 0 to High(Nodes) do
      Order[I] := I;
    if Length(Nodes) > 1 then
    begin
      SetLength(Scratch, Length(Nodes));
      TopoSortRange(Order, Scratch, Nodes, 0, High(Nodes));
    end;
    OidMap := TOidIndexMap.Create;
    try
      for I := 0 to High(Nodes) do
        OidMap.Add(Nodes[I].Oid, I);
      for I := 0 to High(Nodes) do
        for J := 0 to High(Nodes[I].Parents) do
        begin
          if not OidMap.TryGet(Nodes[I].Parents[J], ParentIdx) then
            raise EGitError.Create('topo walk lost a reachable parent');
          Inc(Nodes[ParentIdx].ChildCount);
        end;

      { phase 3: emit through a LIFO ready stack - git's default topo sort
      (REV_SORT_IN_GRAPH_ORDER). Initial tips are stacked oldest-first so
      the newest pops first; afterwards the last-listed newly-ready parent
      pops before its siblings. }
    // Ready LIFO geometric growth via bytes.ops, amortized O(1)
    for I := 0 to High(Nodes) do
      if Nodes[I].ChildCount = 0 then
      begin
        if ReadyLen >= ReadyCap then
        begin
          ReadyCap := SizeInt(GrowArrayCapacity(SizeUInt(ReadyCap), SizeUInt(ReadyLen + 1)));
          SetLength(Ready, ReadyCap);
        end;
        Ready[ReadyLen] := I;
        Inc(ReadyLen);
      end;
    SetLength(Ready, ReadyLen);
    TopoSortTips(Ready, Nodes);
    ReadyCap := Length(Ready);
    Result := nil; ResCount:=0; ResCap:=0;
    while True do
    begin
      if (AMaxCount >= 0) and (ResCount >= AMaxCount) then
        Break;
      // inline LIFO pop, amortized O(1)
      if ReadyLen = 0 then
        NodeIdx := -1
      else
      begin
        Dec(ReadyLen);
        NodeIdx := Ready[ReadyLen];
      end;
      if NodeIdx < 0 then
        Break;
      if ResCount >= ResCap then
      begin ResCap := SizeInt(GrowArrayCapacity(SizeUInt(ResCap), SizeUInt(ResCount + 1))); SetLength(Result, ResCap); end;
      Result[ResCount] := Nodes[NodeIdx].Oid;
      Inc(ResCount);
      for J := 0 to High(Nodes[NodeIdx].Parents) do
      begin
        if not OidMap.TryGet(Nodes[NodeIdx].Parents[J], ParentIdx) then Continue;
        Dec(Nodes[ParentIdx].ChildCount);
        if Nodes[ParentIdx].ChildCount = 0 then
        begin
          // geometric Ready growth via bytes.ops
          if ReadyLen >= ReadyCap then
          begin
            ReadyCap := SizeInt(GrowArrayCapacity(SizeUInt(ReadyCap), SizeUInt(ReadyLen + 1)));
            SetLength(Ready, ReadyCap);
          end;
          Ready[ReadyLen] := ParentIdx;
          Inc(ReadyLen);
        end;
      end;
    end;
    SetLength(Result, ResCount);
    SetLength(Ready, ReadyLen);
    finally OidMap.Free; end;
  finally
    Seen.Free;
    ParseCache.Free;
    if Graph <> nil then Graph.Free;
  end;
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray;
var
  E: TGitRevEntryArray;
  I: Integer;
  LCount, LCap: SizeInt;
begin
  Result := nil;
  LCount:=0; LCap:=0;
  E := GitTopoOrderCommitsWithBoundary(ARepo, AStarts, AHides, AOptions, AMaxCount);
  for I := 0 to High(E) do
    if not E[I].IsBoundary then
    begin
      if LCount >= LCap then
      begin LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1))); SetLength(Result, LCap); end;
      Result[LCount] := E[I].Oid;
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;
var
  Hidden: TGitOidSet;
  Nodes: TTopoNodes;
  Order, Scratch, Ready: TNodeIndexArray;
  Seen: TGitOidSet;
  Stack: TGitOidArray;
  Oid: TGitOid;
  I, J, NodeIdx, ParentIdx: Integer;
  BoundarySet: TGitOidSet;
  OidMap: TOidIndexMap;
  BoundaryList: TGitOidArray;
  Emitted: Integer;
  DateFiltered: array of Boolean;
  Graph: TCommitGraph;
  GWhen: Int64;
  GParents: TGitOidArray;
  ParseCache: TCommitParseCache;
  StackCap, StackLen: SizeInt;
  BndCount, BndCap, ResCount, ResCap, ReadyCap, ReadyLen: SizeInt;
  NodesLen: SizeInt;
  procedure PushStack(const AOid: TGitOid); inline;
  begin
    if StackLen >= StackCap then
    begin StackCap := SizeInt(GrowArrayCapacity(SizeUInt(StackCap), SizeUInt(StackLen + 1))); SetLength(Stack, StackCap); end;
    Stack[StackLen] := AOid; Inc(StackLen);
  end;
  function PopStack(out AOid: TGitOid): Boolean; inline;
  begin Result:= StackLen>0; if not Result then Exit; Dec(StackLen); AOid:=Stack[StackLen]; end;
  procedure AppendBoundary(const AOid: TGitOid);
  begin
    if BndCount >= BndCap then
    begin BndCap := SizeInt(GrowArrayCapacity(SizeUInt(BndCap), SizeUInt(BndCount + 1))); SetLength(BoundaryList, BndCap); end;
    BoundaryList[BndCount] := AOid; Inc(BndCount);
  end;
  procedure AppendResult(const AOid: TGitOid; AIsBoundary: Boolean);
  begin
    if ResCount >= ResCap then
    begin ResCap := SizeInt(GrowArrayCapacity(SizeUInt(ResCap), SizeUInt(ResCount + 1))); SetLength(Result, ResCap); end;
    Result[ResCount].Oid := AOid; Result[ResCount].IsBoundary := AIsBoundary; Inc(ResCount);
  end;
begin
  Result := nil; ResCount:=0; ResCap:=0; BndCount:=0; BndCap:=0; BoundaryList:=nil; StackCap:=0; StackLen:=0; ReadyCap:=0; ReadyLen:=0; Ready:=nil; Nodes:=nil; NodesLen:=0;
  Graph := nil;
  ParseCache := TCommitParseCache.Create;
  try
    if not GitTryLoadCommitGraph(ARepo.GitDir, Graph) then
      Graph := nil;
  except
    Graph := nil;
  end;
  Hidden := nil;
  if Length(AHides) > 0 then
    BuildHiddenSet(ARepo, Graph, AHides, AOptions.FirstParent, Hidden, ParseCache);
  Seen := TGitOidSet.Create;
  BoundarySet := TGitOidSet.Create;
  try
    // phase 1: discover reachable from starts, stopping at hidden boundary
    Stack := nil;
    for I := 0 to High(AStarts) do PushStack(AStarts[I]);
    while PopStack(Oid) do
    begin
      if Seen.Contains(Oid) then
        Continue;
      if (Hidden <> nil) and Hidden.Contains(Oid) then
      begin
        if AOptions.ShowBoundary and not BoundarySet.Contains(Oid) then
        begin
          BoundarySet.Add(Oid);
          AppendBoundary(Oid);
        end;
        Continue;
      end;
      try
        if not TryFetchCommitCached(ARepo, Graph, ParseCache, Oid, GWhen, GParents) then
          raise EGitError.Create('topo walk start points at a non-commit object');
      except
        on E: EGitError do
        begin
          // missing object in shallow clone: skip; non-commit start already raised above and will propagate
          // distinguish: TryFetch raise for missing vs explicit raise for non-commit
          // if Got==false case already raised, re-raise
          if Pos('non-commit', E.Message) > 0 then raise;
          Continue;
        end;
      end;
      Seen.Add(Oid);
      if NodesLen >= Length(Nodes) then
      begin
        // geometric growth via bytes.ops, amortized O(1)
        SetLength(Nodes, SizeInt(GrowArrayCapacity(SizeUInt(Length(Nodes)), SizeUInt(NodesLen + 1))));
      end;
      NodeIdx := NodesLen;
      Inc(NodesLen);
      Nodes[NodeIdx].Oid := Oid;
      Nodes[NodeIdx].When := GWhen;
      if AOptions.FirstParent then
      begin
        if Length(GParents) > 0 then
        begin
          SetLength(Nodes[NodeIdx].Parents, 1);
          Nodes[NodeIdx].Parents[0] := GParents[0];
        end
        else
          SetLength(Nodes[NodeIdx].Parents, 0);
      end
      else
        Nodes[NodeIdx].Parents := GParents; { CoW }
      Nodes[NodeIdx].ChildCount := 0;
      for J := 0 to High(Nodes[NodeIdx].Parents) do
      begin
        // if parent is hidden, collect boundary and do not traverse
        if (Hidden <> nil) and Hidden.Contains(Nodes[NodeIdx].Parents[J]) then
        begin
          if AOptions.ShowBoundary and not BoundarySet.Contains(Nodes[NodeIdx].Parents[J]) then
          begin
            BoundarySet.Add(Nodes[NodeIdx].Parents[J]);
            AppendBoundary(Nodes[NodeIdx].Parents[J]);
          end;
          Continue;
        end;
        PushStack(Nodes[NodeIdx].Parents[J]);
      end;
    end;
    SetLength(Stack, StackLen);
    SetLength(BoundaryList, BndCount);
    SetLength(Nodes, NodesLen);
    if Length(Nodes) = 0 then
    begin
      // only boundaries
      if AOptions.ShowBoundary then
      begin
        for I := 0 to High(BoundaryList) do
        begin
          if (AMaxCount >= 0) and (ResCount >= AMaxCount) then
            Break;
          AppendResult(BoundaryList[I], True);
        end;
        SetLength(Result, ResCount);
      end;
      Exit;
    end;
    // phase 2: child counts among included nodes only, O(E) via hash
    SetLength(Order, Length(Nodes));
    for I := 0 to High(Nodes) do
      Order[I] := I;
    if Length(Nodes) > 1 then
    begin
      SetLength(Scratch, Length(Nodes));
      TopoSortRange(Order, Scratch, Nodes, 0, High(Nodes));
    end;
    OidMap := TOidIndexMap.Create;
    try
      for I := 0 to High(Nodes) do
        OidMap.Add(Nodes[I].Oid, I);
      for I := 0 to High(Nodes) do
        for J := 0 to High(Nodes[I].Parents) do
        begin
          if not OidMap.TryGet(Nodes[I].Parents[J], ParentIdx) then
            Continue;
          Inc(Nodes[ParentIdx].ChildCount);
        end;
      // prepare date filter flags
    SetLength(DateFiltered, Length(Nodes));
    for I := 0 to High(Nodes) do
      DateFiltered[I] := not PassesDateFilter(Nodes[I].When, AOptions.Since, AOptions.UntilTime);
    // phase 3: LIFO ready stack
    // Ready LIFO geometric growth via bytes.ops, amortized O(1)
    for I := 0 to High(Nodes) do
      if Nodes[I].ChildCount = 0 then
      begin
        if ReadyLen >= ReadyCap then
        begin
          ReadyCap := SizeInt(GrowArrayCapacity(SizeUInt(ReadyCap), SizeUInt(ReadyLen + 1)));
          SetLength(Ready, ReadyCap);
        end;
        Ready[ReadyLen] := I;
        Inc(ReadyLen);
      end;
    SetLength(Ready, ReadyLen);
    TopoSortTips(Ready, Nodes);
    ReadyCap := Length(Ready);
    Emitted := 0;
    while True do
    begin
      if (AMaxCount >= 0) and (ResCount >= AMaxCount) and (Emitted >= AMaxCount) then
        Break;
      // inline LIFO pop, amortized O(1)
      if ReadyLen = 0 then
        NodeIdx := -1
      else
      begin
        Dec(ReadyLen);
        NodeIdx := Ready[ReadyLen];
      end;
      if NodeIdx < 0 then
        Break;
      if not DateFiltered[NodeIdx] then
      begin
        if (AMaxCount < 0) or (Emitted < AMaxCount) then
        begin
          AppendResult(Nodes[NodeIdx].Oid, False);
          Inc(Emitted);
        end;
      end;
      for J := 0 to High(Nodes[NodeIdx].Parents) do
      begin
        if not OidMap.TryGet(Nodes[NodeIdx].Parents[J], ParentIdx) then
          Continue;
        Dec(Nodes[ParentIdx].ChildCount);
        if Nodes[ParentIdx].ChildCount = 0 then
        begin
          // geometric Ready growth via bytes.ops
          if ReadyLen >= ReadyCap then
          begin
            ReadyCap := SizeInt(GrowArrayCapacity(SizeUInt(ReadyCap), SizeUInt(ReadyLen + 1)));
            SetLength(Ready, ReadyCap);
          end;
          Ready[ReadyLen] := ParentIdx;
          Inc(ReadyLen);
        end;
      end;
    end;
    SetLength(Ready, ReadyLen);
    finally OidMap.Free; end;
    if AOptions.ShowBoundary then
    begin
      for I := 0 to High(BoundaryList) do
      begin
        if (AMaxCount >= 0) and (ResCount >= AMaxCount) then
          Break;
        if (AOptions.Since <> 0) or (AOptions.UntilTime <> 0) then
        begin
          // reuse parse cache / graph to avoid extra inflate
          try
            if TryFetchCommitCached(ARepo, Graph, ParseCache, BoundaryList[I], GWhen, GParents) then
            begin
              if not PassesDateFilter(GWhen, AOptions.Since, AOptions.UntilTime) then
                Continue;
            end;
          except
          end;
        end;
        AppendResult(BoundaryList[I], True);
      end;
    end;
    SetLength(Result, ResCount);
    SetLength(BoundaryList, BndCount);
  finally
    Seen.Free;
    BoundarySet.Free;
    ParseCache.Free;
    if Hidden <> nil then
      Hidden.Free;
    if Graph <> nil then
      Graph.Free;
  end;
end;

end.
