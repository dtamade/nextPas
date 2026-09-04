unit nextpas.core.git.native.revwalk.collect;

{$I nextpas.core.settings.inc}

{ revwalk 收集域: 日期序一次收集, 每提交恰一次解析.
  边界版自带堆与隐藏集; 单游标版归 walker 域.
  依赖: base/fetch/hashset/parsecache (revwalk.*) + repo/commitgraph. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.revwalk.base,
  nextpas.core.git.native.repo;

type
  { canonical owner is git.native.base; explicit alias pins body resolution
    to the canonical type (commitgraph.base/revwalk.base alias here) }
  TGitOidArray = nextpas.core.git.native.revwalk.base.TGitOidArray;

{ one-shot convenience with hides/options: AMaxCount < 0 means unlimited }
function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray;
function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
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

{ ── History.Collect: date-order collect, single-parse per commit ── }
function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray;
var
  E: TGitRevEntryArray;
  I: Integer;
  LCount, LCap: SizeInt;
begin
  Result := nil;
  E := GitCollectCommitsWithBoundary(ARepo, AStarts, AHides, AOptions, AMaxCount);
  LCount := 0; LCap := 0;
  for I := 0 to High(E) do
    if not E[I].IsBoundary then
    begin
      if LCount >= LCap then
      begin
        LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
        SetLength(Result, LCap);
      end;
      Result[LCount] := E[I].Oid;
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;
var
  Hidden: TGitOidSet;
  Seen: TGitOidSet;
  Heap: array of PWalkEntry;
  HeapCap: SizeInt;
  HeapLen: SizeInt;
  BoundarySet: TGitOidSet;
  BoundaryList: TGitOidArray;
  Graph: TCommitGraph;
  ParseCache: TCommitParseCache;
  ResCount, ResCap: SizeInt;
  BndCount, BndCap: SizeInt;

  procedure HeapPushLocal(const AEntry: TWalkEntry);
  var
    I, Parent: Integer;
    LNew: PWalkEntry;
  begin
    // geometric growth via bytes.ops GrowArrayCapacity single source, amortized O(1), zero-copy Move for cap array
    // not inline: loop body + SetLength growth would bloat I-Cache per red-line 2
    // stability: New/Dispose paired via try..finally
    if HeapLen >= HeapCap then
    begin
      HeapCap := SizeInt(GrowArrayCapacity(SizeUInt(HeapCap), SizeUInt(HeapLen + 1)));
      SetLength(Heap, HeapCap);
    end;
    New(LNew);
    try
      LNew^ := AEntry;
      I := HeapLen;
      Inc(HeapLen);
      while I > 0 do
      begin
        Parent := (I - 1) div 2;
        if Heap[Parent]^.When >= LNew^.When then
          Break;
        Heap[I] := Heap[Parent];
        I := Parent;
      end;
      Heap[I] := LNew;
    except
      Dispose(LNew);
      raise;
    end;
  end;

  function HeapPopLocal(out AEntry: TWalkEntry): Boolean;
  var
    I, L, R, Best: Integer;
    LLast: PWalkEntry;
  begin
    Result := HeapLen > 0;
    if not Result then
      Exit;
    AEntry := Heap[0]^;
    Dispose(Heap[0]);
    Dec(HeapLen);
    if HeapLen = 0 then
      Exit;
    // perf: pointer heap sift-down, O(log n) pointer moves, no Finalize/Move/FillChar per level
    LLast := Heap[HeapLen];
    Heap[HeapLen] := nil;
    I := 0;
    while True do
    begin
      L := 2 * I + 1;
      R := L + 1;
      Best := I;
      if (L < HeapLen) and (Heap[L]^.When > Heap[Best]^.When) then
        Best := L;
      if (R < HeapLen) and (Heap[R]^.When > Heap[Best]^.When) then
        Best := R;
      if Best = I then
        Break;
      Heap[I] := Heap[Best];
      I := Best;
    end;
    Heap[I] := LLast;
  end;

  procedure EnqueueIfNeeded(const AOid: TGitOid);
  var
    Entry: TWalkEntry;
    GWhen: Int64;
    GParents: TGitOidArray;
    Got: Boolean;
  begin
    if Seen.Contains(AOid) then
      Exit;
    if (Hidden <> nil) and Hidden.Contains(AOid) then
      Exit;
    try
      Got := TryFetchCommitCached(ARepo, Graph, ParseCache, AOid, GWhen, GParents);
    except
      Exit;
    end;
    if not Got then
      raise EGitError.Create('revwalk start points at a non-commit object');
    Seen.Add(AOid);
    Entry.Oid := AOid;
    Entry.When := GWhen;
    Entry.Parents := GParents; { CoW share }
    HeapPushLocal(Entry);
  end;

  procedure AppendBoundary(const AOid: TGitOid);
  begin
    if BndCount >= BndCap then
    begin
      BndCap := SizeInt(GrowArrayCapacity(SizeUInt(BndCap), SizeUInt(BndCount + 1)));
      SetLength(BoundaryList, BndCap);
    end;
    BoundaryList[BndCount] := AOid;
    Inc(BndCount);
  end;

  procedure AppendResult(const AOid: TGitOid; AIsBoundary: Boolean);
  begin
    if ResCount >= ResCap then
    begin
      ResCap := SizeInt(GrowArrayCapacity(SizeUInt(ResCap), SizeUInt(ResCount + 1)));
      SetLength(Result, ResCap);
    end;
    Result[ResCount].Oid := AOid;
    Result[ResCount].IsBoundary := AIsBoundary;
    Inc(ResCount);
  end;

var
  I: Integer;
  Entry: TWalkEntry;
  Emitted: Integer;
  ParentOid: TGitOid;
begin
  Result := nil;
  ResCount := 0; ResCap := 0;
  BndCount := 0; BndCap := 0;
  Heap := nil; HeapCap := 0; HeapLen := 0;
  BoundaryList := nil;
  Graph := nil;
  ParseCache := TCommitParseCache.Create;
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
      BuildHiddenSet(ARepo, Graph, AHides, AOptions.FirstParent, Hidden, ParseCache);
    // seed heap with starts that are not hidden
    {Heap already nil/cap 0/len 0}
    for I := 0 to High(AStarts) do
    begin
      if (Hidden <> nil) and Hidden.Contains(AStarts[I]) then
      begin
        if AOptions.ShowBoundary and not BoundarySet.Contains(AStarts[I]) then
        begin
          BoundarySet.Add(AStarts[I]);
          AppendBoundary(AStarts[I]);
        end;
        Continue;
      end;
      try
        EnqueueIfNeeded(AStarts[I]);
      except
        // missing start remains fatal via EnqueueIfNeeded raise
        raise;
      end;
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
            AppendBoundary(ParentOid);
          end;
          Continue;
        end;
        EnqueueIfNeeded(ParentOid);
      end;
      if not PassesDateFilter(Entry.When, AOptions.Since, AOptions.UntilTime) then
        Continue;
      if (AMaxCount >= 0) and (Emitted >= AMaxCount) then
        Break;
      AppendResult(Entry.Oid, False);
      Inc(Emitted);
    end;
    SetLength(BoundaryList, BndCount);
    // append boundary entries after main list, preserving discovery order
    if AOptions.ShowBoundary then
    begin
      for I := 0 to High(BoundaryList) do
      begin
        if (AMaxCount >= 0) and (ResCount >= AMaxCount) then
          Break;
        AppendResult(BoundaryList[I], True);
      end;
    end;
    SetLength(Result, ResCount);
    SetLength(BoundaryList, BndCount);
  finally
    // stability: dispose leftover pointer heap entries, no managed leak on early MaxCount break
    for I := 0 to HeapLen - 1 do
      if Heap[I] <> nil then
        Dispose(Heap[I]);
    SetLength(Heap, 0);
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
