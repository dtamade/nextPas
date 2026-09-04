unit nextpas.core.git.native.revwalk.fetch;

{$I nextpas.core.settings.inc}

{ revwalk 抓取域: 提交单次交付 (图 → 缓存 → 解析) + 隐藏集构建 + 日期裁剪.
  walker/collect/topo 三域经此复用, 本域不依赖 walker, 保持无环.
  依赖: base/hashset/parsecache (revwalk.*) + repo/objmodel/commitgraph. }

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
  { canonical owner is revwalk.base (commitgraph.base carries an identical
    duplicate); explicit alias pins body resolution to the canonical type }
  TGitOidArray = nextpas.core.git.native.revwalk.base.TGitOidArray;

function PassesDateFilter(AWhen, ASince, AUntilTime: Int64): Boolean;
function TryGraphParents(AGraph: TCommitGraph; const AOid: TGitOid;
  out AWhen: Int64; out AParents: TGitOidArray): Boolean;
function TryFetchCommitCached(ARepo: TNativeRepository; AGraph: TCommitGraph;
  ACache: TCommitParseCache; const AOid: TGitOid; out AWhen: Int64;
  out AParents: TGitOidArray): Boolean;
procedure BuildHiddenSet(ARepo: TNativeRepository;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet); overload;
procedure BuildHiddenSet(ARepo: TNativeRepository;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet; ACache: TCommitParseCache); overload;
procedure BuildHiddenSet(ARepo: TNativeRepository; AGraph: TCommitGraph;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet; ACache: TCommitParseCache); overload;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.git.native.objmodel;

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
  AParents := E.Parents; { CoW share, no Copy per CONTRACT single-parse }
  Result := True;
end;

function TryFetchCommitCached(ARepo: TNativeRepository; AGraph: TCommitGraph;
  ACache: TCommitParseCache; const AOid: TGitOid; out AWhen: Int64;
  out AParents: TGitOidArray): Boolean;
var Data: TBytes; Kind: TGitObjectKind; Info: TGitCommitInfo;
begin
  if TryGraphParents(AGraph, AOid, AWhen, AParents) then
  begin
    if ACache <> nil then ACache.Put(AOid, AWhen, AParents);
    Exit(True);
  end;
  if (ACache <> nil) and ACache.TryGet(AOid, AWhen, AParents) then
    Exit(True);
  try
    Data := ARepo.ReadObject(AOid, Kind);
  except
    on E: EGitError do raise;
  end;
  if Kind <> gokCommit then Exit(False);
  Info := GitParseCommit(Data);
  AWhen := Info.Committer.UnixTime;
  AParents := Info.Parents; { CoW share }
  if ACache <> nil then ACache.Put(AOid, AWhen, AParents);
  Result := True;
end;

procedure BuildHiddenSet(ARepo: TNativeRepository;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet); overload;
var TmpCache: TCommitParseCache;
begin
  TmpCache := TCommitParseCache.Create;
  try
    BuildHiddenSet(ARepo, AHides, AFirstParent, AHidden, TmpCache);
  finally
    TmpCache.Free;
  end;
end;

procedure BuildHiddenSet(ARepo: TNativeRepository;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet; ACache: TCommitParseCache); overload;
begin
  BuildHiddenSet(ARepo, nil, AHides, AFirstParent, AHidden, ACache);
end;

procedure BuildHiddenSet(ARepo: TNativeRepository; AGraph: TCommitGraph;
  const AHides: TGitOidArray; AFirstParent: Boolean;
  out AHidden: TGitOidSet; ACache: TCommitParseCache); overload;
var
  Stack: TGitOidArray;
  Oid: TGitOid;
  I: Integer;
  Graph: TCommitGraph;
  OwnsGraph: Boolean;
  GWhen: Int64;
  GParents: TGitOidArray;
  StackCap, StackLen: SizeInt;
  procedure StackPush(const AOid: TGitOid); inline;
  begin
    if StackLen >= StackCap then
    begin
      StackCap := SizeInt(GrowArrayCapacity(SizeUInt(StackCap), SizeUInt(StackLen + 1)));
      SetLength(Stack, StackCap);
    end;
    Stack[StackLen] := AOid;
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
  AHidden := TGitOidSet.Create;
  Graph := AGraph;
  OwnsGraph := False;
  if Graph = nil then
  begin
    try
      if not GitTryLoadCommitGraph(ARepo.GitDir, Graph) then
        Graph := nil;
    except
      Graph := nil;
    end;
    OwnsGraph := Graph <> nil;
  end;
  try
    Stack := nil; StackCap := 0; StackLen := 0;
    for I := 0 to High(AHides) do StackPush(AHides[I]);
    while StackPop(Oid) do
    begin
      if AHidden.Contains(Oid) then
        Continue;
      if not TryFetchCommitCached(ARepo, Graph, ACache, Oid, GWhen, GParents) then
        Continue;
      AHidden.Add(Oid);
      if AFirstParent then
      begin
        if Length(GParents) > 0 then StackPush(GParents[0]);
      end
      else
        for I := 0 to High(GParents) do StackPush(GParents[I]);
    end;
    SetLength(Stack, StackLen);
  finally
    if OwnsGraph and (Graph <> nil) then Graph.Free;
  end;
end;

end.
