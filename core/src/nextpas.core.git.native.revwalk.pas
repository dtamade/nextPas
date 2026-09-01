unit nextpas.core.git.native.revwalk;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.commitgraph;

{ Revision walking over the native object layer: commits emerge newest
  committer-date first, matching `git rev-list` for distinct dates. Each
  commit is read and parsed exactly once - the queue entry carries the
  pre-fetched parent list so emission never re-reads objects.
  Shallow clones and grafts are out of scope stage-1.

  Topological order buffers the reachable subgraph first (children always
  precede parents), then emits through git's default graph-order ready
  stack (REV_SORT_IN_GRAPH_ORDER): initial tips oldest-stacked-first so
  the newest pops first, afterwards newly-ready parents enter in
  parent-list order, making the last-listed parent pop first.

  Boundary/hide/date semantics mirror `git rev-list`:
  - first-parent follows only the first parent of each commit
  - hide/exclude removes Hides and their ancestors; --boundary re-adds
    direct hidden parents of included commits
  - since/until filters by committer date (0 means unbounded) }

type
  TGitOidArray = array of TGitOid;

  { hash-based oid membership; O(1) avg for streaming walk and
    topological planner — replaces O(n²) sorted+Move }
  TGitOidSet = class
  private
    FBuckets: array of TGitOid;
    FStates: array of Byte; { 0 empty, 1 occupied }
    FCount: SizeInt;
    FCap: SizeInt;
    FMask: SizeInt;
    procedure EnsureCapacity; inline;
    procedure Rehash(ANewCap: SizeInt);
  public
    { no-op when already present }
    procedure Add(const AOid: TGitOid); inline;
    function Contains(const AOid: TGitOid): Boolean; inline;
    function Count: SizeInt; inline;
  end;

  TWalkEntry = record
    Oid: TGitOid;
    When: Int64;
    Parents: TGitOidArray;
  end;

  TGitRevEntry = record
    Oid: TGitOid;
    IsBoundary: Boolean;
  end;
  TGitRevEntryArray = array of TGitRevEntry;

  TGitRevOptions = record
    FirstParent: Boolean;
    Since: Int64; { 0 = no lower bound, include When >= Since }
    UntilTime: Int64; { 0 = no upper bound, include When <= UntilTime }
    ShowBoundary: Boolean;
  end;

  TGitRevWalker = class
  private
    FRepo: TNativeRepository; { borrowed, not owned }
    FGraph: TCommitGraph;     { owned, nil when no commit-graph }
    FHeap: array of TWalkEntry;
    FHeapLen: SizeInt;
    FHeapCap: SizeInt;
    FSeen: TGitOidSet;        { owned }
    FHidden: TGitOidSet;      { owned, hide set }
    FBoundary: TGitRevEntryArray;
    FBoundaryLen: SizeInt;
    FBoundaryCap: SizeInt;
    FBoundaryPos: Integer;
    FFirstParent: Boolean;
    FSince: Int64;
    FUntilTime: Int64;
    FShowBoundary: Boolean;
    procedure InitGraph;
    function TryGraphCommit(const AOid: TGitOid; out AWhen: Int64;
      out AParents: TGitOidArray): Boolean;
    procedure HeapPush(const AEntry: TWalkEntry);
    function HeapPop(out AEntry: TWalkEntry): Boolean;
    procedure EnqueueCommit(const AOid: TGitOid);
    procedure EnqueueHidden(const AOid: TGitOid);
  public
    constructor Create(ARepo: TNativeRepository); overload;
    constructor Create(ARepo: TNativeRepository; const AOptions: TGitRevOptions); overload;
    destructor Destroy; override;
    { marks a walk start; missing objects raise EGitError }
    procedure Push(const AOid: TGitOid);
    procedure PushHead(const AGitDir: string);
    procedure PushHide(const AOid: TGitOid);
    procedure SetFirstParent(AValue: Boolean);
    procedure SetDateRange(ASince, AUntilTime: Int64);
    procedure SetShowBoundary(AValue: Boolean);
    { emits False when the walk is exhausted }
    function Next(out AOid: TGitOid): Boolean;
    function NextWithBoundary(out AEntry: TGitRevEntry): Boolean;
  end;

function DefaultGitRevOptions: TGitRevOptions; inline;

{ one-shot convenience: AMaxCount < 0 means unlimited }
function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload;

function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;

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
  nextpas.core.bytes.ops;

function OidLess(const AA, AB: TGitOid): Boolean;
var
  I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do
  begin
    if AA.Bytes[I] < AB.Bytes[I] then
      Exit(True);
    if AA.Bytes[I] > AB.Bytes[I] then
      Exit(False);
  end;
  Result := False;
end;

function GitOidHash(const AOid: TGitOid): UInt32; inline;
var
  I: Integer;
begin
  Result := UInt32(2166136261);
  for I := 0 to GitOidRawLen - 1 do
    Result := (Result xor UInt32(AOid.Bytes[I])) * UInt32(16777619);
end;

procedure TGitOidSet.EnsureCapacity; inline;
begin
  if FCap = 0 then
    Rehash(16)
  else if FCount * 10 >= FCap * 7 then
    Rehash(FCap * 2);
end;

procedure TGitOidSet.Rehash(ANewCap: SizeInt);
var
  LOldBuckets: array of TGitOid;
  LOldStates: array of Byte;
  LOldCap: SizeInt;
  I: Integer;
  LIdx: SizeInt;
  LHash: UInt32;
begin
  LOldBuckets := FBuckets;
  LOldStates := FStates;
  LOldCap := FCap;
  SetLength(FBuckets, ANewCap);
  SetLength(FStates, ANewCap);
  FCap := ANewCap;
  FMask := ANewCap - 1;
  FCount := 0;
  for I := 0 to LOldCap - 1 do
    if (I < Length(LOldStates)) and (LOldStates[I] = 1) then
    begin
      LHash := GitOidHash(LOldBuckets[I]);
      LIdx := SizeInt(LHash and UInt32(FMask));
      while FStates[LIdx] = 1 do
        LIdx := (LIdx + 1) and FMask;
      FBuckets[LIdx] := LOldBuckets[I];
      FStates[LIdx] := 1;
      Inc(FCount);
    end;
end;

procedure TGitOidSet.Add(const AOid: TGitOid);
var
  LHash: UInt32;
  LIdx: SizeInt;
begin
  EnsureCapacity;
  LHash := GitOidHash(AOid);
  LIdx := SizeInt(LHash and UInt32(FMask));
  while FStates[LIdx] <> 0 do
  begin
    if GitOidSame(FBuckets[LIdx], AOid) then
      Exit;
    LIdx := (LIdx + 1) and FMask;
  end;
  FBuckets[LIdx] := AOid; { zero-copy: 20-byte inline copy }
  FStates[LIdx] := 1;
  Inc(FCount);
end;

function TGitOidSet.Contains(const AOid: TGitOid): Boolean;
var
  LHash: UInt32;
  LIdx: SizeInt;
begin
  if FCount = 0 then
    Exit(False);
  LHash := GitOidHash(AOid);
  LIdx := SizeInt(LHash and UInt32(FMask));
  while FStates[LIdx] <> 0 do
  begin
    if GitOidSame(FBuckets[LIdx], AOid) then
      Exit(True);
    LIdx := (LIdx + 1) and FMask;
  end;
  Result := False;
end;

function TGitOidSet.Count: SizeInt;
begin
  Result := FCount;
end;

function DefaultGitRevOptions: TGitRevOptions;
begin
  Result.FirstParent := False;
  Result.Since := 0;
  Result.UntilTime := 0;
  Result.ShowBoundary := False;
end;

function PassesDateFilter(AWhen, ASince, AUntilTime: Int64): Boolean;
begin
  if (ASince <> 0) and (AWhen < ASince) then
    Exit(False);
  if (AUntilTime <> 0) and (AWhen > AUntilTime) then
    Exit(False);
  Result := True;
end;

function TryGraphParents(AGraph: TCommitGraph; const AOid: TGitOid;
  out AWhen: Int64; out AParents: TGitOidArray): Boolean;
var
  E: TCommitGraphEntry;
begin
  Result := False;
  if AGraph = nil then
    Exit;
  if not AGraph.TryFind(AOid, E) then
    Exit;
  AWhen := E.CommitTime;
  AParents := Copy(E.Parents);
  Result := True;
end;

procedure BuildHiddenSet(ARepo: TNativeRepository;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet);
var
  Stack: TGitOidArray;
  StackLen, StackCap: SizeInt;
  Oid: TGitOid;
  Data: TBytes;
  Kind: TGitObjectKind;
  Info: TGitCommitInfo;
  I: Integer;
  Graph: TCommitGraph;
  GWhen: Int64;
  GParents: TGitOidArray;
  UsedGraph: Boolean;
begin
  AHidden := TGitOidSet.Create;
  Graph := nil;
  try
    if not GitTryLoadCommitGraph(ARepo.GitDir, Graph) then
      Graph := nil;
  except
    Graph := nil;
  end;
  try
    // perf: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
    Stack := Copy(AHides);
    StackLen := Length(Stack);
    StackCap := StackLen;
    while StackLen > 0 do
    begin
      Dec(StackLen);
      Oid := Stack[StackLen];
      if AHidden.Contains(Oid) then
        Continue;
      UsedGraph := TryGraphParents(Graph, Oid, GWhen, GParents);
      if not UsedGraph then
      begin
        try
          Data := ARepo.ReadObject(Oid, Kind);
        except
          on E: EGitError do
            raise;
        end;
        if Kind <> gokCommit then
          Continue;
        Info := GitParseCommit(Data);
        GParents := Copy(Info.Parents);
      end;
      AHidden.Add(Oid);
      if AFirstParent then
      begin
        if Length(GParents) > 0 then
        begin
          if StackLen + 1 > StackCap then
          begin
            StackCap := BytesGrowCapacityInt(StackCap, StackLen + 1);
            SetLength(Stack, StackCap);
          end;
          Stack[StackLen] := GParents[0];
          Inc(StackLen);
        end;
      end
      else
      begin
        for I := 0 to High(GParents) do
        begin
          if StackLen + 1 > StackCap then
          begin
            StackCap := BytesGrowCapacityInt(StackCap, StackLen + 1);
            SetLength(Stack, StackCap);
          end;
          Stack[StackLen] := GParents[I];
          Inc(StackLen);
        end;
      end;
    end;
  finally
    if Graph <> nil then
      Graph.Free;
  end;
end;

procedure TGitRevWalker.InitGraph;
begin
  if FGraph <> nil then
    Exit;
  try
    if not GitTryLoadCommitGraph(FRepo.GitDir, FGraph) then
      FGraph := nil;
  except
    FGraph := nil;
  end;
end;

function TGitRevWalker.TryGraphCommit(const AOid: TGitOid; out AWhen: Int64;
  out AParents: TGitOidArray): Boolean;
begin
  Result := TryGraphParents(FGraph, AOid, AWhen, AParents);
end;

procedure TGitRevWalker.HeapPush(const AEntry: TWalkEntry);
var
  I, Parent: Integer;
begin
  // perf: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
  if FHeapLen + 1 > FHeapCap then
  begin
    FHeapCap := BytesGrowCapacityInt(FHeapCap, FHeapLen + 1);
    SetLength(FHeap, FHeapCap);
  end;
  I := FHeapLen;
  Inc(FHeapLen);
  // max-heap on When: newest commit at the root
  while I > 0 do
  begin
    Parent := (I - 1) div 2;
    if FHeap[Parent].When >= AEntry.When then
      Break;
    FHeap[I] := FHeap[Parent];
    I := Parent;
  end;
  FHeap[I] := AEntry;
end;

function TGitRevWalker.HeapPop(out AEntry: TWalkEntry): Boolean;
var
  I, L, R, Best: Integer;
  Tmp: TWalkEntry;
begin
  Result := FHeapLen > 0;
  if not Result then
    Exit;
  AEntry := FHeap[0];
  Dec(FHeapLen);
  FHeap[0] := FHeap[FHeapLen];
  if FHeapLen = 0 then
    Exit;
  // restore the max-heap property from the root
  I := 0;
  while True do
  begin
    L := 2 * I + 1;
    R := L + 1;
    Best := I;
    if (L < FHeapLen) and (FHeap[L].When > FHeap[Best].When) then
      Best := L;
    if (R < FHeapLen) and (FHeap[R].When > FHeap[Best].When) then
      Best := R;
    if Best = I then
      Break;
    Tmp := FHeap[I];
    FHeap[I] := FHeap[Best];
    FHeap[Best] := Tmp;
    I := Best;
  end;
end;

procedure TGitRevWalker.EnqueueCommit(const AOid: TGitOid);
var
  Data: TBytes;
  Kind: TGitObjectKind;
  Info: TGitCommitInfo;
  Entry: TWalkEntry;
  I: Integer;
  GWhen: Int64;
  GParents: TGitOidArray;
begin
  if FSeen.Contains(AOid) then
    Exit;
  if (FHidden <> nil) and FHidden.Contains(AOid) then
  begin
    if FShowBoundary then
    begin
      for I := 0 to FBoundaryLen - 1 do
        if GitOidSame(FBoundary[I].Oid, AOid) then
          Exit;
      // perf: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
      if FBoundaryLen + 1 > FBoundaryCap then
      begin
        FBoundaryCap := BytesGrowCapacityInt(FBoundaryCap, FBoundaryLen + 1);
        SetLength(FBoundary, FBoundaryCap);
      end;
      FBoundary[FBoundaryLen].Oid := AOid;
      FBoundary[FBoundaryLen].IsBoundary := True;
      Inc(FBoundaryLen);
    end;
    Exit;
  end;
  InitGraph;
  if TryGraphCommit(AOid, GWhen, GParents) then
  begin
    FSeen.Add(AOid);
    Entry.Oid := AOid;
    Entry.When := GWhen;
    if FFirstParent and (Length(GParents) > 1) then
    begin
      SetLength(Entry.Parents, 1);
      Entry.Parents[0] := GParents[0];
    end
    else
      Entry.Parents := Copy(GParents);
    HeapPush(Entry);
    Exit;
  end;
  Data := FRepo.ReadObject(AOid, Kind);
  if Kind <> gokCommit then
    raise EGitError.Create('revwalk start points at a non-commit object');
  Info := GitParseCommit(Data);
  FSeen.Add(AOid);
  Entry.Oid := AOid;
  Entry.When := Info.Committer.UnixTime;
  if FFirstParent and (Length(Info.Parents) > 1) then
  begin
    SetLength(Entry.Parents, 1);
    Entry.Parents[0] := Info.Parents[0];
  end
  else
    Entry.Parents := Copy(Info.Parents);
  HeapPush(Entry);
end;

procedure TGitRevWalker.EnqueueHidden(const AOid: TGitOid);
var
  Stack: TGitOidArray;
  StackLen, StackCap: SizeInt;
  Cur: TGitOid;
  Data: TBytes;
  Kind: TGitObjectKind;
  Info: TGitCommitInfo;
  I: Integer;
  GWhen: Int64;
  GParents: TGitOidArray;
begin
  if FHidden = nil then
    FHidden := TGitOidSet.Create;
  InitGraph;
  // perf: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
  Stack := nil;
  StackLen := 0;
  StackCap := 0;
  StackCap := BytesGrowCapacityInt(StackCap, 1);
  SetLength(Stack, StackCap);
  Stack[0] := AOid;
  StackLen := 1;
  while StackLen > 0 do
  begin
    Dec(StackLen);
    Cur := Stack[StackLen];
    if FHidden.Contains(Cur) then
      Continue;
    if TryGraphCommit(Cur, GWhen, GParents) then
    begin
      FHidden.Add(Cur);
      if FFirstParent then
      begin
        if Length(GParents) > 0 then
        begin
          if StackLen + 1 > StackCap then
          begin
            StackCap := BytesGrowCapacityInt(StackCap, StackLen + 1);
            SetLength(Stack, StackCap);
          end;
          Stack[StackLen] := GParents[0];
          Inc(StackLen);
        end;
      end
      else
      begin
        for I := 0 to High(GParents) do
        begin
          if StackLen + 1 > StackCap then
          begin
            StackCap := BytesGrowCapacityInt(StackCap, StackLen + 1);
            SetLength(Stack, StackCap);
          end;
          Stack[StackLen] := GParents[I];
          Inc(StackLen);
        end;
      end;
      Continue;
    end;
    try
      Data := FRepo.ReadObject(Cur, Kind);
    except
      on E: EGitError do
        raise;
    end;
    if Kind <> gokCommit then
      Continue;
    Info := GitParseCommit(Data);
    FHidden.Add(Cur);
    if FFirstParent then
    begin
      if Length(Info.Parents) > 0 then
      begin
        if StackLen + 1 > StackCap then
        begin
          StackCap := BytesGrowCapacityInt(StackCap, StackLen + 1);
          SetLength(Stack, StackCap);
        end;
        Stack[StackLen] := Info.Parents[0];
        Inc(StackLen);
      end;
    end
    else
    begin
      for I := 0 to High(Info.Parents) do
      begin
        if StackLen + 1 > StackCap then
        begin
          StackCap := BytesGrowCapacityInt(StackCap, StackLen + 1);
          SetLength(Stack, StackCap);
        end;
        Stack[StackLen] := Info.Parents[I];
        Inc(StackLen);
      end;
    end;
  end;
end;

constructor TGitRevWalker.Create(ARepo: TNativeRepository);
begin
  Create(ARepo, DefaultGitRevOptions);
end;

constructor TGitRevWalker.Create(ARepo: TNativeRepository; const AOptions: TGitRevOptions);
begin
  inherited Create;
  if ARepo = nil then
    raise EGitError.Create('revwalk requires a repository');
  FRepo := ARepo;
  FGraph := nil;
  FSeen := TGitOidSet.Create;
  FHidden := nil;
  FBoundary := nil;
  FBoundaryPos := 0;
  FFirstParent := AOptions.FirstParent;
  FSince := AOptions.Since;
  FUntilTime := AOptions.UntilTime;
  FShowBoundary := AOptions.ShowBoundary;
end;

destructor TGitRevWalker.Destroy;
begin
  FSeen.Free;
  if FHidden <> nil then
    FHidden.Free;
  if FGraph <> nil then
    FGraph.Free;
  inherited Destroy;
end;

procedure TGitRevWalker.Push(const AOid: TGitOid);
begin
  EnqueueCommit(AOid);
end;

procedure TGitRevWalker.PushHead(const AGitDir: string);
begin
  Push(GitResolveHead(AGitDir));
end;

procedure TGitRevWalker.PushHide(const AOid: TGitOid);
begin
  EnqueueHidden(AOid);
end;

procedure TGitRevWalker.SetFirstParent(AValue: Boolean);
begin
  FFirstParent := AValue;
end;

procedure TGitRevWalker.SetDateRange(ASince, AUntilTime: Int64);
begin
  FSince := ASince;
  FUntilTime := AUntilTime;
end;

procedure TGitRevWalker.SetShowBoundary(AValue: Boolean);
begin
  FShowBoundary := AValue;
end;

function TGitRevWalker.Next(out AOid: TGitOid): Boolean;
var
  Entry: TWalkEntry;
  I, K: Integer;
  IsHidden: Boolean;
begin
  while True do
  begin
    if not HeapPop(Entry) then
    begin
      if FShowBoundary and (FBoundaryPos < FBoundaryLen) then
      begin
        AOid := FBoundary[FBoundaryPos].Oid;
        Inc(FBoundaryPos);
        Exit(True);
      end;
      Exit(False);
    end;
    // enqueue parents (hidden/boundary handled inside EnqueueCommit)
    for I := 0 to High(Entry.Parents) do
    begin
      if FFirstParent and (I > 0) then
        Break;
      // check if parent is hidden -> boundary handling
      IsHidden := (FHidden <> nil) and FHidden.Contains(Entry.Parents[I]);
      if IsHidden and FShowBoundary then
      begin
        IsHidden := False;
        for K := 0 to FBoundaryLen - 1 do
          if GitOidSame(FBoundary[K].Oid, Entry.Parents[I]) then
          begin
            IsHidden := True;
            Break;
          end;
        if not IsHidden then
        begin
          // perf: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
          if FBoundaryLen + 1 > FBoundaryCap then
          begin
            FBoundaryCap := BytesGrowCapacityInt(FBoundaryCap, FBoundaryLen + 1);
            SetLength(FBoundary, FBoundaryCap);
          end;
          FBoundary[FBoundaryLen].Oid := Entry.Parents[I];
          FBoundary[FBoundaryLen].IsBoundary := True;
          Inc(FBoundaryLen);
        end;
        Continue;
      end;
      if IsHidden then
        Continue;
      EnqueueCommit(Entry.Parents[I]);
    end;
    if not PassesDateFilter(Entry.When, FSince, FUntilTime) then
      Continue;
    AOid := Entry.Oid;
    Exit(True);
  end;
end;

function TGitRevWalker.NextWithBoundary(out AEntry: TGitRevEntry): Boolean;
var
  Oid: TGitOid;
  I: Integer;
  WasBoundary: Boolean;
begin
  // drain heap first, then boundary
  WasBoundary := FShowBoundary and (Length(FHeap) = 0) and (FBoundaryPos < Length(FBoundary));
  if WasBoundary then
  begin
    AEntry.Oid := FBoundary[FBoundaryPos].Oid;
    AEntry.IsBoundary := True;
    Inc(FBoundaryPos);
    Exit(True);
  end;
  if not Next(Oid) then
    Exit(False);
  // Next may have returned a boundary entry via its own drain; detect by checking if Oid is in boundary list and heap was empty
  WasBoundary := False;
  for I := 0 to High(FBoundary) do
    if GitOidSame(FBoundary[I].Oid, Oid) then
    begin
      // if Oid was boundary, it would have been appended to FBoundary and returned after heap empty
      // To know if this call returned boundary, check if FBoundaryPos was just incremented
      // Simpler: if Oid exists in boundary list, mark as boundary
      WasBoundary := True;
      Break;
    end;
  // But non-boundary Oids never in boundary list, so check suffices
  AEntry.Oid := Oid;
  AEntry.IsBoundary := WasBoundary;
  Result := True;
end;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray;
var
  Walker: TGitRevWalker;
  I: SizeInt;
  Oid: TGitOid;
  LLen, LCap: SizeInt;
begin
  Result := nil;
  LLen := 0;
  LCap := 0;
  Walker := TGitRevWalker.Create(ARepo);
  try
    for I := 0 to High(AStarts) do
      Walker.Push(AStarts[I]);
    while ((AMaxCount < 0) or (LLen < AMaxCount))
      and Walker.Next(Oid) do
    begin
      // perf: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
      if LLen + 1 > LCap then
      begin
        LCap := BytesGrowCapacityInt(LCap, LLen + 1);
        SetLength(Result, LCap);
      end;
      Result[LLen] := Oid;
      Inc(LLen);
    end;
    if LLen <> Length(Result) then
      SetLength(Result, LLen);
  finally
    Walker.Free;
  end;
end;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray;
var
  E: TGitRevEntryArray;
  I, LLen, LCap: Integer;
begin
  Result := nil;
  E := GitCollectCommitsWithBoundary(ARepo, AStarts, AHides, AOptions, AMaxCount);
  LLen := 0;
  LCap := 0;
  for I := 0 to High(E) do
    if not E[I].IsBoundary then
    begin
      // perf: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
      if LLen + 1 > LCap then
      begin
        LCap := BytesGrowCapacityInt(LCap, LLen + 1);
        SetLength(Result, LCap);
      end;
      Result[LLen] := E[I].Oid;
      Inc(LLen);
    end;
  if LLen <> Length(Result) then
    SetLength(Result, LLen);
end;

function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;
var
  Hidden: TGitOidSet;
  Seen: TGitOidSet;
  Heap: array of TWalkEntry;
  HeapLen, HeapCap: SizeInt;
  BoundarySet: TGitOidSet;
  BoundaryList: TGitOidArray;
  BoundaryLen, BoundaryCap: SizeInt;
  Graph: TCommitGraph;

  // perf: heap local collect exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
  procedure HeapPushLocal(const AEntry: TWalkEntry);
  var
    I, Parent: Integer;
  begin
    if HeapLen + 1 > HeapCap then
    begin
      HeapCap := BytesGrowCapacityInt(HeapCap, HeapLen + 1);
      SetLength(Heap, HeapCap);
    end;
    I := HeapLen;
    Inc(HeapLen);
    while I > 0 do
    begin
      Parent := (I - 1) div 2;
      if Heap[Parent].When >= AEntry.When then
        Break;
      Heap[I] := Heap[Parent];
      I := Parent;
    end;
    Heap[I] := AEntry;
  end;

  function HeapPopLocal(out AEntry: TWalkEntry): Boolean;
  var
    I, L, R, Best: Integer;
    Tmp: TWalkEntry;
  begin
    Result := HeapLen > 0;
    if not Result then
      Exit;
    AEntry := Heap[0];
    Dec(HeapLen);
    Heap[0] := Heap[HeapLen];
    if HeapLen = 0 then
      Exit;
    I := 0;
    while True do
    begin
      L := 2 * I + 1;
      R := L + 1;
      Best := I;
      if (L < HeapLen) and (Heap[L].When > Heap[Best].When) then
        Best := L;
      if (R < HeapLen) and (Heap[R].When > Heap[Best].When) then
        Best := R;
      if Best = I then
        Break;
      Tmp := Heap[I];
      Heap[I] := Heap[Best];
      Heap[Best] := Tmp;
      I := Best;
    end;
  end;

  procedure EnqueueIfNeeded(const AOid: TGitOid);
  var
    Data: TBytes;
    Kind: TGitObjectKind;
    Info: TGitCommitInfo;
    Entry: TWalkEntry;
    GWhen: Int64;
    GParents: TGitOidArray;
  begin
    if Seen.Contains(AOid) then
      Exit;
    if (Hidden <> nil) and Hidden.Contains(AOid) then
      Exit;
    if TryGraphParents(Graph, AOid, GWhen, GParents) then
    begin
      Seen.Add(AOid);
      Entry.Oid := AOid;
      Entry.When := GWhen;
      Entry.Parents := Copy(GParents);
      HeapPushLocal(Entry);
      Exit;
    end;
    try
      Data := ARepo.ReadObject(AOid, Kind);
    except
      Exit;
    end;
    if Kind <> gokCommit then
      raise EGitError.Create('revwalk start points at a non-commit object');
    Info := GitParseCommit(Data);
    Seen.Add(AOid);
    Entry.Oid := AOid;
    Entry.When := Info.Committer.UnixTime;
    Entry.Parents := Copy(Info.Parents);
    HeapPushLocal(Entry);
  end;

var
  I: Integer;
  Entry: TWalkEntry;
  Emitted: Integer;
  ParentOid: TGitOid;
  RLen, RCap: SizeInt;
begin
  Result := nil;
  RLen := 0;
  RCap := 0;
  HeapLen := 0;
  HeapCap := 0;
  BoundaryLen := 0;
  BoundaryCap := 0;
  BoundaryList := nil;
  Graph := nil;
  try
    if not GitTryLoadCommitGraph(ARepo.GitDir, Graph) then
      Graph := nil;
  except
    Graph := nil;
  end;
  Hidden := nil;
  Seen := TGitOidSet.Create;
  BoundarySet := TGitOidSet.Create;
  try
    if Length(AHides) > 0 then
      BuildHiddenSet(ARepo, AHides, AOptions.FirstParent, Hidden);
    // seed heap with starts that are not hidden
    Heap := nil;
    for I := 0 to High(AStarts) do
    begin
      if (Hidden <> nil) and Hidden.Contains(AStarts[I]) then
      begin
        if AOptions.ShowBoundary and not BoundarySet.Contains(AStarts[I]) then
        begin
          BoundarySet.Add(AStarts[I]);
          // perf: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
          if BoundaryLen + 1 > BoundaryCap then
          begin
            BoundaryCap := BytesGrowCapacityInt(BoundaryCap, BoundaryLen + 1);
            SetLength(BoundaryList, BoundaryCap);
          end;
          BoundaryList[BoundaryLen] := AStarts[I];
          Inc(BoundaryLen);
        end;
        Continue;
      end;
      EnqueueIfNeeded(AStarts[I]);
    end;
    Emitted := 0;
    while HeapPopLocal(Entry) do
    begin
      if (Hidden <> nil) and Hidden.Contains(Entry.Oid) then
        Continue;
      // enqueue parents before emission so traversal continues even if filtered
      for I := 0 to High(Entry.Parents) do
      begin
        if AOptions.FirstParent and (I > 0) then
          Break;
        ParentOid := Entry.Parents[I];
        if (Hidden <> nil) and Hidden.Contains(ParentOid) then
        begin
          if AOptions.ShowBoundary and not BoundarySet.Contains(ParentOid) then
          begin
            BoundarySet.Add(ParentOid);
            if BoundaryLen + 1 > BoundaryCap then
            begin
              BoundaryCap := BytesGrowCapacityInt(BoundaryCap, BoundaryLen + 1);
              SetLength(BoundaryList, BoundaryCap);
            end;
            BoundaryList[BoundaryLen] := ParentOid;
            Inc(BoundaryLen);
          end;
          Continue;
        end;
        EnqueueIfNeeded(ParentOid);
      end;
      if not PassesDateFilter(Entry.When, AOptions.Since, AOptions.UntilTime) then
        Continue;
      if (AMaxCount >= 0) and (Emitted >= AMaxCount) then
        Break;
      if RLen + 1 > RCap then
      begin
        RCap := BytesGrowCapacityInt(RCap, RLen + 1);
        SetLength(Result, RCap);
      end;
      Result[RLen].Oid := Entry.Oid;
      Result[RLen].IsBoundary := False;
      Inc(RLen);
      Inc(Emitted);
    end;
    if BoundaryLen <> Length(BoundaryList) then
      SetLength(BoundaryList, BoundaryLen);
    // append boundary entries after main list, preserving discovery order
    if AOptions.ShowBoundary then
    begin
      for I := 0 to BoundaryLen - 1 do
      begin
        if (AMaxCount >= 0) and (RLen >= AMaxCount) then
          Break;
        if RLen + 1 > RCap then
        begin
          RCap := BytesGrowCapacityInt(RCap, RLen + 1);
          SetLength(Result, RCap);
        end;
        Result[RLen].Oid := BoundaryList[I];
        Result[RLen].IsBoundary := True;
        Inc(RLen);
      end;
    end;
    if RLen <> Length(Result) then
      SetLength(Result, RLen);
  finally
    Seen.Free;
    BoundarySet.Free;
    if Hidden <> nil then
      Hidden.Free;
    if Graph <> nil then
      Graph.Free;
  end;
end;

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

{ stable merge sort of node indices by oid bytes; single shared scratch }
procedure TopoSortRange(var AOrder: TNodeIndexArray;
  var AScratch: TNodeIndexArray; const ANodes: TTopoNodes;
  ALow, AHigh: Integer);
var
  Mid, I, J, K: Integer;
begin
  if ALow >= AHigh then
    Exit;
  Mid := (ALow + AHigh) div 2;
  TopoSortRange(AOrder, AScratch, ANodes, ALow, Mid);
  TopoSortRange(AOrder, AScratch, ANodes, Mid + 1, AHigh);
  Move(AOrder[ALow], AScratch[ALow],
    SizeInt(AHigh - ALow + 1) * SizeOf(Integer));
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
  Move(AScratch[ALow], AOrder[ALow],
    SizeInt(AHigh - ALow + 1) * SizeOf(Integer));
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

{ ascending by commit time, stable; the ready stack pops from the tail,
  so the newest initial tip goes first - mirroring limit_list's order }
procedure TopoSortTips(var ATips: TNodeIndexArray; const ANodes: TTopoNodes);
var
  I, J, Tmp: Integer;
begin
  for I := 1 to High(ATips) do
  begin
    Tmp := ATips[I];
    J := I - 1;
    while (J >= 0) and (ANodes[ATips[J]].When > ANodes[Tmp].When) do
    begin
      ATips[J + 1] := ATips[J];
      Dec(J);
    end;
    ATips[J + 1] := Tmp;
  end;
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
  NodesLen, NodesCap: SizeInt;
  Order, Scratch, Ready: TNodeIndexArray;
  ReadyLen, ReadyCap: SizeInt;
  Seen: TGitOidSet;
  Stack: TGitOidArray;
  StackLen, StackCap: SizeInt;
  Data: TBytes;
  Kind: TGitObjectKind;
  Info: TGitCommitInfo;
  Oid: TGitOid;
  I, J, NodeIdx, ParentIdx: Integer;
  RLen, RCap: SizeInt;
begin
  Result := nil;
  RLen := 0;
  RCap := 0;
  Seen := TGitOidSet.Create;
  try
    { phase 1: discover the full reachable set, parsing each commit once }
    // perf: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
    Stack := Copy(AStarts);
    StackLen := Length(Stack);
    StackCap := StackLen;
    Nodes := nil;
    NodesLen := 0;
    NodesCap := 0;
    while StackLen > 0 do
    begin
      Dec(StackLen);
      Oid := Stack[StackLen];
      if Seen.Contains(Oid) then
        Continue;
      Data := ARepo.ReadObject(Oid, Kind);
      if Kind <> gokCommit then
        raise EGitError.Create('topo walk start points at a non-commit object');
      Info := GitParseCommit(Data);
      Seen.Add(Oid);
      if NodesLen + 1 > NodesCap then
      begin
        NodesCap := BytesGrowCapacityInt(NodesCap, NodesLen + 1);
        SetLength(Nodes, NodesCap);
      end;
      NodeIdx := NodesLen;
      Inc(NodesLen);
      Nodes[NodeIdx].Oid := Oid;
      Nodes[NodeIdx].When := Info.Committer.UnixTime;
      Nodes[NodeIdx].Parents := Copy(Info.Parents);
      Nodes[NodeIdx].ChildCount := 0;
      for J := 0 to High(Info.Parents) do
      begin
        if StackLen + 1 > StackCap then
        begin
          StackCap := BytesGrowCapacityInt(StackCap, StackLen + 1);
          SetLength(Stack, StackCap);
        end;
        Stack[StackLen] := Info.Parents[J];
        Inc(StackLen);
      end;
    end;
    if NodesLen <> Length(Nodes) then
      SetLength(Nodes, NodesLen);
    if StackLen <> Length(Stack) then
      SetLength(Stack, StackLen);

    { phase 2: count each node's children within the set }
    SetLength(Order, Length(Nodes));
    for I := 0 to High(Nodes) do
      Order[I] := I;
    if Length(Nodes) > 1 then
    begin
      SetLength(Scratch, Length(Nodes));
      TopoSortRange(Order, Scratch, Nodes, 0, High(Nodes));
    end;
    for I := 0 to High(Nodes) do
      for J := 0 to High(Nodes[I].Parents) do
      begin
        ParentIdx := TopoNodeIndexOf(Nodes[I].Parents[J], Order, Nodes);
        if ParentIdx < 0 then
          raise EGitError.Create('topo walk lost a reachable parent');
        Inc(Nodes[ParentIdx].ChildCount);
      end;

    { phase 3: emit through a LIFO ready stack - git's default topo sort
      (REV_SORT_IN_GRAPH_ORDER). Initial tips are stacked oldest-first so
      the newest pops first; afterwards the last-listed newly-ready parent
      pops before its siblings. }
    Ready := nil;
    ReadyLen := 0;
    ReadyCap := 0;
    for I := 0 to High(Nodes) do
      if Nodes[I].ChildCount = 0 then
      begin
        if ReadyLen + 1 > ReadyCap then
        begin
          ReadyCap := BytesGrowCapacityInt(ReadyCap, ReadyLen + 1);
          SetLength(Ready, ReadyCap);
        end;
        Ready[ReadyLen] := I;
        Inc(ReadyLen);
      end;
    if ReadyLen <> Length(Ready) then
      SetLength(Ready, ReadyLen);
    TopoSortTips(Ready, Nodes);
    ReadyLen := Length(Ready);
    ReadyCap := ReadyLen;
    while True do
    begin
      if (AMaxCount >= 0) and (RLen >= AMaxCount) then
        Break;
      if ReadyLen = 0 then
        Break;
      Dec(ReadyLen);
      NodeIdx := Ready[ReadyLen];
      if RLen + 1 > RCap then
      begin
        RCap := BytesGrowCapacityInt(RCap, RLen + 1);
        SetLength(Result, RCap);
      end;
      Result[RLen] := Nodes[NodeIdx].Oid;
      Inc(RLen);
      for J := 0 to High(Nodes[NodeIdx].Parents) do
      begin
        ParentIdx := TopoNodeIndexOf(Nodes[NodeIdx].Parents[J], Order, Nodes);
        Dec(Nodes[ParentIdx].ChildCount);
        if Nodes[ParentIdx].ChildCount = 0 then
        begin
          if ReadyLen + 1 > ReadyCap then
          begin
            ReadyCap := BytesGrowCapacityInt(ReadyCap, ReadyLen + 1);
            SetLength(Ready, ReadyCap);
          end;
          Ready[ReadyLen] := ParentIdx;
          Inc(ReadyLen);
        end;
      end;
    end;
    if RLen <> Length(Result) then
      SetLength(Result, RLen);
  finally
    Seen.Free;
  end;
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray;
var
  E: TGitRevEntryArray;
  I, LLen, LCap: Integer;
begin
  Result := nil;
  LLen := 0;
  LCap := 0;
  E := GitTopoOrderCommitsWithBoundary(ARepo, AStarts, AHides, AOptions, AMaxCount);
  for I := 0 to High(E) do
    if not E[I].IsBoundary then
    begin
      // perf: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
      if LLen + 1 > LCap then
      begin
        LCap := BytesGrowCapacityInt(LCap, LLen + 1);
        SetLength(Result, LCap);
      end;
      Result[LLen] := E[I].Oid;
      Inc(LLen);
    end;
  if LLen <> Length(Result) then
    SetLength(Result, LLen);
end;

function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;
var
  Hidden: TGitOidSet;
  Nodes: TTopoNodes;
  NodesLen, NodesCap: SizeInt;
  Order, Scratch, Ready: TNodeIndexArray;
  ReadyLen, ReadyCap: SizeInt;
  Seen: TGitOidSet;
  Stack: TGitOidArray;
  StackLen, StackCap: SizeInt;
  Data: TBytes;
  Kind: TGitObjectKind;
  Info: TGitCommitInfo;
  Oid: TGitOid;
  I, J, NodeIdx, ParentIdx: Integer;
  BoundarySet: TGitOidSet;
  BoundaryList: TGitOidArray;
  BoundaryLen, BoundaryCap: SizeInt;
  Emitted: Integer;
  DateFiltered: array of Boolean;
  Graph: TCommitGraph;
  GWhen: Int64;
  GParents: TGitOidArray;
  UseGraph: Boolean;
  RLen, RCap: SizeInt;
begin
  Result := nil;
  RLen := 0;
  RCap := 0;
  Graph := nil;
  try
    if not GitTryLoadCommitGraph(ARepo.GitDir, Graph) then
      Graph := nil;
  except
    Graph := nil;
  end;
  Hidden := nil;
  if Length(AHides) > 0 then
    BuildHiddenSet(ARepo, AHides, AOptions.FirstParent, Hidden);
  Seen := TGitOidSet.Create;
  BoundarySet := TGitOidSet.Create;
  try
    // phase 1: discover reachable from starts, stopping at hidden boundary
    // perf: exponential via bytes.ops.BytesGrowCapacityInt single source amortized O(1), single SetLength+Move zero-copy
    Stack := Copy(AStarts);
    StackLen := Length(Stack);
    StackCap := StackLen;
    Nodes := nil;
    NodesLen := 0;
    NodesCap := 0;
    BoundaryList := nil;
    BoundaryLen := 0;
    BoundaryCap := 0;
    while StackLen > 0 do
    begin
      Dec(StackLen);
      Oid := Stack[StackLen];
      if Seen.Contains(Oid) then
        Continue;
      if (Hidden <> nil) and Hidden.Contains(Oid) then
      begin
        if AOptions.ShowBoundary and not BoundarySet.Contains(Oid) then
        begin
          BoundarySet.Add(Oid);
          if BoundaryLen + 1 > BoundaryCap then
          begin
            BoundaryCap := BytesGrowCapacityInt(BoundaryCap, BoundaryLen + 1);
            SetLength(BoundaryList, BoundaryCap);
          end;
          BoundaryList[BoundaryLen] := Oid;
          Inc(BoundaryLen);
        end;
        Continue;
      end;
      UseGraph := TryGraphParents(Graph, Oid, GWhen, GParents);
      if not UseGraph then
      begin
        try
          Data := ARepo.ReadObject(Oid, Kind);
        except
          Continue;
        end;
        if Kind <> gokCommit then
          raise EGitError.Create('topo walk start points at a non-commit object');
        Info := GitParseCommit(Data);
        GWhen := Info.Committer.UnixTime;
        GParents := Copy(Info.Parents);
      end;
      Seen.Add(Oid);
      if NodesLen + 1 > NodesCap then
      begin
        NodesCap := BytesGrowCapacityInt(NodesCap, NodesLen + 1);
        SetLength(Nodes, NodesCap);
      end;
      NodeIdx := NodesLen;
      Inc(NodesLen);
      Nodes[NodeIdx].Oid := Oid;
      Nodes[NodeIdx].When := GWhen;
      // store parents respecting first-parent flag for graph edges
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
        Nodes[NodeIdx].Parents := Copy(GParents);
      Nodes[NodeIdx].ChildCount := 0;
      for J := 0 to High(Nodes[NodeIdx].Parents) do
      begin
        // if parent is hidden, collect boundary and do not traverse
        if (Hidden <> nil) and Hidden.Contains(Nodes[NodeIdx].Parents[J]) then
        begin
          if AOptions.ShowBoundary and not BoundarySet.Contains(Nodes[NodeIdx].Parents[J]) then
          begin
            BoundarySet.Add(Nodes[NodeIdx].Parents[J]);
            if BoundaryLen + 1 > BoundaryCap then
            begin
              BoundaryCap := BytesGrowCapacityInt(BoundaryCap, BoundaryLen + 1);
              SetLength(BoundaryList, BoundaryCap);
            end;
            BoundaryList[BoundaryLen] := Nodes[NodeIdx].Parents[J];
            Inc(BoundaryLen);
          end;
          Continue;
        end;
        if StackLen + 1 > StackCap then
        begin
          StackCap := BytesGrowCapacityInt(StackCap, StackLen + 1);
          SetLength(Stack, StackCap);
        end;
        Stack[StackLen] := Nodes[NodeIdx].Parents[J];
        Inc(StackLen);
      end;
    end;
    if NodesLen <> Length(Nodes) then
      SetLength(Nodes, NodesLen);
    if StackLen <> Length(Stack) then
      SetLength(Stack, StackLen);
    if BoundaryLen <> Length(BoundaryList) then
      SetLength(BoundaryList, BoundaryLen);
    if Length(Nodes) = 0 then
    begin
      // only boundaries
      if AOptions.ShowBoundary then
      begin
        for I := 0 to BoundaryLen - 1 do
        begin
          if (AMaxCount >= 0) and (RLen >= AMaxCount) then
            Break;
          if RLen + 1 > RCap then
          begin
            RCap := BytesGrowCapacityInt(RCap, RLen + 1);
            SetLength(Result, RCap);
          end;
          Result[RLen].Oid := BoundaryList[I];
          Result[RLen].IsBoundary := True;
          Inc(RLen);
        end;
        if RLen <> Length(Result) then
          SetLength(Result, RLen);
      end;
      Exit;
    end;
    // phase 2: child counts among included nodes only
    SetLength(Order, Length(Nodes));
    for I := 0 to High(Nodes) do
      Order[I] := I;
    if Length(Nodes) > 1 then
    begin
      SetLength(Scratch, Length(Nodes));
      TopoSortRange(Order, Scratch, Nodes, 0, High(Nodes));
    end;
    for I := 0 to High(Nodes) do
      for J := 0 to High(Nodes[I].Parents) do
      begin
        // parents that are hidden are not in Nodes, so skip counting
        ParentIdx := TopoNodeIndexOf(Nodes[I].Parents[J], Order, Nodes);
        if ParentIdx < 0 then
          Continue;
        Inc(Nodes[ParentIdx].ChildCount);
      end;
    // prepare date filter flags
    SetLength(DateFiltered, Length(Nodes));
    for I := 0 to High(Nodes) do
      DateFiltered[I] := not PassesDateFilter(Nodes[I].When, AOptions.Since, AOptions.UntilTime);
    // phase 3: LIFO ready stack
    Ready := nil;
    ReadyLen := 0;
    ReadyCap := 0;
    for I := 0 to High(Nodes) do
      if Nodes[I].ChildCount = 0 then
      begin
        if ReadyLen + 1 > ReadyCap then
        begin
          ReadyCap := BytesGrowCapacityInt(ReadyCap, ReadyLen + 1);
          SetLength(Ready, ReadyCap);
        end;
        Ready[ReadyLen] := I;
        Inc(ReadyLen);
      end;
    if ReadyLen <> Length(Ready) then
      SetLength(Ready, ReadyLen);
    TopoSortTips(Ready, Nodes);
    ReadyLen := Length(Ready);
    ReadyCap := ReadyLen;
    Emitted := 0;
    while True do
    begin
      if (AMaxCount >= 0) and (RLen >= AMaxCount) and (Emitted >= AMaxCount) then
        Break;
      if ReadyLen = 0 then
        Break;
      Dec(ReadyLen);
      NodeIdx := Ready[ReadyLen];
      // still need to decrement children of parents even if filtered?
      // but we have to make parents ready when all children processed
      // If node is date-filtered, we skip emission but still process parents
      if not DateFiltered[NodeIdx] then
      begin
        if (AMaxCount < 0) or (Emitted < AMaxCount) then
        begin
          if RLen + 1 > RCap then
          begin
            RCap := BytesGrowCapacityInt(RCap, RLen + 1);
            SetLength(Result, RCap);
          end;
          Result[RLen].Oid := Nodes[NodeIdx].Oid;
          Result[RLen].IsBoundary := False;
          Inc(RLen);
          Inc(Emitted);
        end;
      end
      else if AOptions.Since <> 0 then
      begin
        // even filtered, we must count towards emission? No
      end;
      for J := 0 to High(Nodes[NodeIdx].Parents) do
      begin
        ParentIdx := TopoNodeIndexOf(Nodes[NodeIdx].Parents[J], Order, Nodes);
        if ParentIdx < 0 then
          Continue;
        Dec(Nodes[ParentIdx].ChildCount);
        if Nodes[ParentIdx].ChildCount = 0 then
        begin
          if ReadyLen + 1 > ReadyCap then
          begin
            ReadyCap := BytesGrowCapacityInt(ReadyCap, ReadyLen + 1);
            SetLength(Ready, ReadyCap);
          end;
          Ready[ReadyLen] := ParentIdx;
          Inc(ReadyLen);
        end;
      end;
    end;
    if AOptions.ShowBoundary then
    begin
      for I := 0 to BoundaryLen - 1 do
      begin
        if (AMaxCount >= 0) and (RLen >= AMaxCount) then
          Break;
        // boundary respects date filter? Apply same filter
        // need to fetch boundary commit date to filter - read it
        // quick path: if Since/UntilTime set, fetch and check
        if (AOptions.Since <> 0) or (AOptions.UntilTime <> 0) then
        begin
          try
            Data := ARepo.ReadObject(BoundaryList[I], Kind);
            if Kind = gokCommit then
            begin
              Info := GitParseCommit(Data);
              if not PassesDateFilter(Info.Committer.UnixTime, AOptions.Since, AOptions.UntilTime) then
                Continue;
            end;
          except
          end;
        end;
        if RLen + 1 > RCap then
        begin
          RCap := BytesGrowCapacityInt(RCap, RLen + 1);
          SetLength(Result, RCap);
        end;
        Result[RLen].Oid := BoundaryList[I];
        Result[RLen].IsBoundary := True;
        Inc(RLen);
      end;
    end;
    if RLen <> Length(Result) then
      SetLength(Result, RLen);
  finally
    Seen.Free;
    BoundarySet.Free;
    if Hidden <> nil then
      Hidden.Free;
    if Graph <> nil then
      Graph.Free;
  end;
end;

end.
