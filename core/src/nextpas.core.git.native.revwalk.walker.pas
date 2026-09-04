unit nextpas.core.git.native.revwalk.walker;

{$I nextpas.core.settings.inc}

{ revwalk 堆遍历器域: committer-date 最大堆游标 + 隐藏集 + 日期裁剪.
  单次交付: 每提交恰一次图/缓存/解析.
  依赖: base/hashset/parsecache (revwalk.*) + repo/objmodel/refs/commitgraph. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.revwalk.base,
  nextpas.core.git.native.revwalk.hashset,
  nextpas.core.git.native.revwalk.parsecache,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.commitgraph;

type
  { canonical owner is git.native.base; explicit alias pins body resolution
    to the canonical type (commitgraph.base/revwalk.base alias here) }
  TGitOidArray = nextpas.core.git.native.revwalk.base.TGitOidArray;

{ ── History.HeapWalker: committer-date max-heap O(log N) pointer moves, bytes.ops single source ── }
type
  TGitRevWalker = class
  private
    FRepo: TNativeRepository; { borrowed, not owned }
    FGraph: TCommitGraph;     { owned, nil when no commit-graph }
    FHeap: array of PWalkEntry;
    FHeapCap: SizeInt;            { geometric capacity for FHeap }
    FHeapLen: SizeInt;            { active heap size }
    FSeen: TGitOidSet;        { owned }
    FHidden: TGitOidSet;      { owned, hide set }
    FParseCache: TCommitParseCache; { owned, exactly-once }
    FBoundary: TGitRevEntryArray;
    FBoundaryCap: SizeInt;
    FBoundaryLen: SizeInt;
    FBoundaryPos: Integer;
    FBoundarySet: TGitOidSet; { O(1) boundary dedup, mirrors BoundarySet in one-shot path }
    FFirstParent: Boolean;
    FSince: Int64;
    FUntilTime: Int64;
    FShowBoundary: Boolean;
    procedure AppendBoundary(const AOid: TGitOid); inline;
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

{ one-shot convenience via walker drain: AMaxCount < 0 means unlimited }
function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.revwalk.fetch;

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
  LNew: PWalkEntry;
begin
  // geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), amortized O(1), zero-copy Move for cap array
  // not inline: loop body + SetLength growth would bloat I-Cache
  // perf: pointer heap, O(log n) single pointer moves (8 bytes), inline cmp, zero managed Move/Finalize/FillChar per level; CoW share for Parents
  // stability: New/Dispose paired via try..finally on exception path
  if FHeapLen >= FHeapCap then
  begin
    FHeapCap := SizeInt(GrowArrayCapacity(SizeUInt(FHeapCap), SizeUInt(FHeapLen + 1)));
    SetLength(FHeap, FHeapCap);
  end;
  New(LNew);
  try
    LNew^ := AEntry;
    I := FHeapLen;
    Inc(FHeapLen);
    while I > 0 do
    begin
      Parent := (I - 1) div 2;
      if FHeap[Parent]^.When >= LNew^.When then
        Break;
      FHeap[I] := FHeap[Parent];
      I := Parent;
    end;
    FHeap[I] := LNew;
  except
    Dispose(LNew);
    raise;
  end;
end;

function TGitRevWalker.HeapPop(out AEntry: TWalkEntry): Boolean;
var
  I, L, R, Best: Integer;
  LLast: PWalkEntry;
begin
  Result := FHeapLen > 0;
  if not Result then
    Exit;
  AEntry := FHeap[0]^;
  Dispose(FHeap[0]);
  Dec(FHeapLen);
  if FHeapLen = 0 then
    Exit;
  // perf: pointer heap sift-down, O(log n) pointer moves, no Finalize/Move/FillChar per level, inline cmp
  LLast := FHeap[FHeapLen];
  FHeap[FHeapLen] := nil;
  I := 0;
  while True do
  begin
    L := 2 * I + 1;
    R := L + 1;
    Best := I;
    if (L < FHeapLen) and (FHeap[L]^.When > FHeap[Best]^.When) then
      Best := L;
    if (R < FHeapLen) and (FHeap[R]^.When > FHeap[Best]^.When) then
      Best := R;
    if Best = I then
      Break;
    FHeap[I] := FHeap[Best];
    I := Best;
  end;
  FHeap[I] := LLast;
end;

procedure TGitRevWalker.AppendBoundary(const AOid: TGitOid); inline;
begin
  if FBoundaryLen >= FBoundaryCap then
  begin
    FBoundaryCap := SizeInt(GrowArrayCapacity(SizeUInt(FBoundaryCap), SizeUInt(FBoundaryLen + 1)));
    SetLength(FBoundary, FBoundaryCap);
  end;
  if (FBoundarySet <> nil) and FBoundarySet.Contains(AOid) then Exit;
  if FBoundarySet = nil then FBoundarySet := TGitOidSet.Create;
  FBoundarySet.Add(AOid);
  FBoundary[FBoundaryLen].Oid := AOid;
  FBoundary[FBoundaryLen].IsBoundary := True;
  Inc(FBoundaryLen);
end;

procedure TGitRevWalker.EnqueueCommit(const AOid: TGitOid);
var
  Entry: TWalkEntry;
  I: Integer;
  GWhen: Int64;
  GParents: TGitOidArray;
  IsNonCommit: Boolean;
  Data: TBytes;
  Kind: TGitObjectKind;
  Info: TGitCommitInfo;
begin
  if FSeen.Contains(AOid) then
    Exit;
  if (FHidden <> nil) and FHidden.Contains(AOid) then
  begin
    if FShowBoundary then
      AppendBoundary(AOid);
    Exit;
  end;
  InitGraph;
  if FParseCache = nil then
    FParseCache := TCommitParseCache.Create;
  // single lookup path: graph -> cache -> inflate/parse, cached exactly-once
  if TryGraphParents(FGraph, AOid, GWhen, GParents) then
  begin
    FParseCache.Put(AOid, GWhen, GParents);
  end
  else if not FParseCache.TryGet(AOid, GWhen, GParents) then
  begin
    Data := FRepo.ReadObject(AOid, Kind);
    if Kind <> gokCommit then
      raise EGitError.Create('revwalk start points at a non-commit object');
    Info := GitParseCommit(Data);
    GWhen := Info.Committer.UnixTime;
    GParents := Info.Parents; { CoW share, no Copy }
    FParseCache.Put(AOid, GWhen, GParents);
  end;
  FSeen.Add(AOid);
  Entry.Oid := AOid;
  Entry.When := GWhen;
  if FFirstParent and (Length(GParents) > 1) then
  begin
    SetLength(Entry.Parents, 1);
    Entry.Parents[0] := GParents[0];
  end
  else
    Entry.Parents := GParents; { CoW share }
  HeapPush(Entry);
end;

procedure TGitRevWalker.EnqueueHidden(const AOid: TGitOid);
var
  Stack: TGitOidArray;
  Cur: TGitOid;
  I: Integer;
  GWhen: Int64;
  GParents: TGitOidArray;
  StackCap, StackLen: SizeInt;
  procedure StackPush(const APushOid: TGitOid); inline;
  begin
    if StackLen >= StackCap then
    begin
      StackCap := SizeInt(GrowArrayCapacity(SizeUInt(StackCap), SizeUInt(StackLen + 1)));
      SetLength(Stack, StackCap);
    end;
    Stack[StackLen] := APushOid;
    Inc(StackLen);
  end;
  function StackPop(out AOid: TGitOid): Boolean; inline;
  begin
    Result := StackLen > 0;
    if not Result then Exit;
    Dec(StackLen);
    AOid := Stack[StackLen];
  end;
begin
  if FHidden = nil then
    FHidden := TGitOidSet.Create;
  InitGraph;
  if FParseCache = nil then
    FParseCache := TCommitParseCache.Create;
  Stack := nil; StackCap := 0; StackLen := 0;
  StackPush(AOid);
  while StackPop(Cur) do
  begin
    if FHidden.Contains(Cur) then
      Continue;
    if not TryFetchCommitCached(FRepo, FGraph, FParseCache, Cur, GWhen, GParents) then
      Continue;
    FHidden.Add(Cur);
    if FFirstParent then
    begin
      if Length(GParents) > 0 then StackPush(GParents[0]);
    end
    else
      for I := 0 to High(GParents) do StackPush(GParents[I]);
  end;
  SetLength(Stack, StackLen);
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
  FHeap := nil;
  FHeapCap := 0;
  FHeapLen := 0;
  FSeen := TGitOidSet.Create;
  FHidden := nil;
  FParseCache := nil;
  FBoundary := nil;
  FBoundaryCap := 0;
  FBoundaryLen := 0;
  FBoundaryPos := 0;
  FBoundarySet := nil;
  FFirstParent := AOptions.FirstParent;
  FSince := AOptions.Since;
  FUntilTime := AOptions.UntilTime;
  FShowBoundary := AOptions.ShowBoundary;
end;

destructor TGitRevWalker.Destroy;
var I: Integer;
begin
  FSeen.Free;
  if FHidden <> nil then
    FHidden.Free;
  if FParseCache <> nil then
    FParseCache.Free;
  if FBoundarySet <> nil then
    FBoundarySet.Free;
  if FGraph <> nil then
    FGraph.Free;
  for I := 0 to FHeapLen - 1 do
    if FHeap[I] <> nil then
      Dispose(FHeap[I]);
  SetLength(FHeap, 0);
  FHeapCap := 0;
  FHeapLen := 0;
  SetLength(FBoundary, 0);
  FBoundaryCap := 0;
  FBoundaryLen := 0;
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
  I: Integer;
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
      // check if parent is hidden -> boundary handling, O(1) via BoundarySet
      IsHidden := (FHidden <> nil) and FHidden.Contains(Entry.Parents[I]);
      if IsHidden and FShowBoundary then
      begin
        if (FBoundarySet = nil) or not FBoundarySet.Contains(Entry.Parents[I]) then
          AppendBoundary(Entry.Parents[I]);
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
  WasBoundary: Boolean;
begin
  // drain heap first, then boundary; O(1) via BoundarySet hash
  WasBoundary := FShowBoundary and (FHeapLen = 0) and (FBoundaryPos < FBoundaryLen);
  if WasBoundary then
  begin
    AEntry.Oid := FBoundary[FBoundaryPos].Oid;
    AEntry.IsBoundary := True;
    Inc(FBoundaryPos);
    Exit(True);
  end;
  if not Next(Oid) then
    Exit(False);
  WasBoundary := (FBoundarySet <> nil) and FBoundarySet.Contains(Oid);
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
  LCount, LCap: SizeInt;
begin
  Result := nil;
  LCount := 0; LCap := 0;
  Walker := TGitRevWalker.Create(ARepo);
  try
    for I := 0 to High(AStarts) do
      Walker.Push(AStarts[I]);
    while ((AMaxCount < 0) or (LCount < AMaxCount))
      and Walker.Next(Oid) do
    begin
      if LCount >= LCap then
      begin
        LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
        SetLength(Result, LCap);
      end;
      Result[LCount] := Oid;
      Inc(LCount);
    end;
    SetLength(Result, LCount);
  finally
    Walker.Free;
  end;
end;

end.
