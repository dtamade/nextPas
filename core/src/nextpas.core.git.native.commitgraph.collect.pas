unit nextpas.core.git.native.commitgraph.collect;

{$I nextpas.core.settings.inc}

{ commit-graph v1 收集域: refs/heads+HEAD+tags 起点扇出 + 全量提交收集 + WriteAll.
  依赖: base/writer/reader/cache (commitgraph.*) + revwalk 收集 + L0-L1 owner. }

interface

uses
  nextpas.core.git.native.commitgraph.base;

function CollectAllCommits(const AGitDir: string): TRawCommitArray;
function GitWriteCommitGraphAll(const AGitDir: string): string;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.base,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.revwalk,
  nextpas.core.git.native.commitgraph.writer,
  nextpas.core.git.native.commitgraph.reader,
  nextpas.core.git.native.commitgraph.cache;

{ ── History.Collect: refs/heads+HEAD+tags fan-out for WriteAll (CollectAllCommits) ── }

procedure CollectRefsRecursive(const ABase, APrefix: string; var AOut: TStringArray);
var
  LCap, LCnt: SizeUInt;
  LNewCap: SizeUInt;
  procedure GrowAndAppend(const AVal: string); inline;
  begin
    // perf: inline + geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), amortized O(1) per append, zero-copy string Move (managed refcount), avoids O(n²) SetLength(Length+1) churn on prune/fetch with many remote branches
    if LCnt >= LCap then
    begin
      LNewCap := GrowArrayCapacity(LCap, LCnt + 1);
      SetLength(AOut, LNewCap);
      LCap := LNewCap;
    end;
    AOut[LCnt] := AVal;
    Inc(LCnt);
  end;
  procedure Recurse(const B, P: string);
  var Ents: TDirEntryArray; I: Integer; Full, Rel: string;
  begin
    Ents := ReadDir(B);
    for I := 0 to High(Ents) do
    begin
      Full := PathJoin([B, Ents[I].Name]);
      Rel := P + '/' + Ents[I].Name;
      if Ents[I].IsDir then
        Recurse(Full, Rel)
      else
        GrowAndAppend(Rel);
    end;
  end;
begin
  // stability: LCnt/LCap capture existing length (re-entrant append), managed strings auto released on exception via AOut refcount; final shrink releases slack, zero leak
  LCnt := SizeUInt(Length(AOut));
  LCap := SizeUInt(Length(AOut));
  Recurse(ABase, APrefix);
  if LCap <> LCnt then
    SetLength(AOut, LCnt);
end;

function ListBranchesRaw(const AGitDir: string): TStringArray;
var Path: string;
begin
  Result := nil;
  Path := PathJoin([AGitDir, 'refs', 'heads']);
  if not DirectoryExists(Path) then Exit;
  CollectRefsRecursive(Path, 'refs/heads', Result);
end;

function ListTagsRaw(const AGitDir: string): TStringArray;
var Path: string;
begin
  Result := nil;
  Path := PathJoin([AGitDir, 'refs', 'tags']);
  if not DirectoryExists(Path) then Exit;
  CollectRefsRecursive(Path, 'refs/tags', Result);
end;

function ListTagOidsRaw(const AGitDir: string): TGitOidArray;
var Ents: TStringArray;
    I: Integer;
    Oid: TGitOid;
    Repo: TNativeRepository;
    Kind: TGitObjectKind;
    Data: TBytes;
    LCnt, LCap, LNewCap: SizeUInt;
begin
  Result := nil;
  LCnt := 0; LCap := 0;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Ents := ListTagsRaw(AGitDir);
    for I := 0 to High(Ents) do
    begin
      try Oid := GitResolveRef(AGitDir, Ents[I]); except Continue; end;
      try
        Data := Repo.ReadObject(Oid, Kind);
        if Kind = gokTag then Oid := GitParseTag(Data).Target;
        Data := Repo.ReadObject(Oid, Kind);
        if Kind <> gokCommit then Continue;
      except Continue; end;
      // perf: inline geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), amortized O(1) per append, zero-copy TGitOid Move (20B) via direct assignment, avoids O(n²) SetLength(Length+1) churn; stability: managed Result auto released on exception, final shrink releases slack
      if LCnt >= LCap then
      begin
        LNewCap := GrowArrayCapacity(LCap, LCnt + 1);
        SetLength(Result, LNewCap);
        LCap := LNewCap;
      end;
      Result[LCnt] := Oid;
      Inc(LCnt);
    end;
    if LCap <> LCnt then
      SetLength(Result, LCnt);
  finally
    Repo.Free;
  end;
end;

function CollectAllCommits(const AGitDir: string): TRawCommitArray;
var Repo: TNativeRepository;
    Starts: TGitOidArray;
    Opt: TGitRevOptions;
    Oids: TGitOidArray;
    I: Integer;
    Kind: TGitObjectKind;
    Data: TBytes;
    Info: TGitCommitInfo;
    Raw: TRawCommit;
    BranchList: TStringArray;
    TagOids: TGitOidArray;
    HeadOid: TGitOid;
    HasHead: Boolean;
    StartsCnt, StartsCap, StartsNewCap: SizeUInt;
function Contains(const AArr: TGitOidArray; const AOid: TGitOid): Boolean;
var K: Integer;
begin
  for K := 0 to High(AArr) do if GitOidSame(AArr[K], AOid) then Exit(True);
  Result := False;
end;
function ContainsStarts(const AOid: TGitOid): Boolean;
var K: Integer;
begin
  // not inline: O(n) scan loop per design-conventions inline red line 2 — I-Cache guard
  // perf: zero-copy OID compare via bytes.ops SpanEqual single source, O(n) scan limited to StartsCnt (not cap), avoids stale slack comparison
  for K := 0 to Integer(StartsCnt) - 1 do if GitOidSame(Starts[K], AOid) then Exit(True);
  Result := False;
end;
procedure AppendStart(const AOid: TGitOid); inline;
begin
  // perf: inline geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), amortized O(1), zero-copy TGitOid Move (20B)
  if StartsCnt >= StartsCap then
  begin
    StartsNewCap := GrowArrayCapacity(StartsCap, StartsCnt + 1);
    SetLength(Starts, StartsNewCap);
    StartsCap := StartsNewCap;
  end;
  Starts[StartsCnt] := AOid;
  Inc(StartsCnt);
end;
begin
  Result := nil;
  Repo := TNativeRepository.Create(AGitDir);
  try
    SetLength(Starts, 0); StartsCnt := 0; StartsCap := 0;
    try
      BranchList := ListBranchesRaw(AGitDir);
      for I := 0 to High(BranchList) do
      begin
        try
          HeadOid := GitResolveRef(AGitDir, BranchList[I]);
          if not ContainsStarts(HeadOid) then AppendStart(HeadOid);
        except end;
      end;
    except end;
    HasHead := False;
    try HeadOid := GitResolveHead(AGitDir); HasHead := True; except HasHead := False; end;
    if HasHead and not ContainsStarts(HeadOid) then AppendStart(HeadOid);
    try
      TagOids := ListTagOidsRaw(AGitDir);
      for I := 0 to High(TagOids) do
        if not ContainsStarts(TagOids[I]) then AppendStart(TagOids[I]);
    except end;
    if StartsCap <> StartsCnt then SetLength(Starts, StartsCnt);
    if Length(Starts) = 0 then Exit;
    Opt := DefaultGitRevOptions;
    Oids := GitCollectCommits(Repo, Starts, -1);
    SetLength(Result, Length(Oids));
    for I := 0 to High(Oids) do
    begin
      Data := Repo.ReadObject(Oids[I], Kind);
      if Kind = gokTag then Data := Repo.ReadObject(GitParseTag(Data).Target, Kind);
      if Kind <> gokCommit then Continue;
      Info := GitParseCommit(Data);
      Raw.Oid := Oids[I];
      Raw.TreeOid := Info.Tree;
      Raw.CommitTime := Info.Committer.UnixTime;
      Raw.Parents := Info.Parents;
      Raw.Generation := 0;
      Result[I] := Raw;
    end;
  finally
    Repo.Free;
  end;
end;

function GitWriteCommitGraphAll(const AGitDir: string): string;
var Raw: TRawCommitArray;
    Data: TBytes;
    Path: string;
    G: TCommitGraph;
begin
  Raw := CollectAllCommits(AGitDir);
  if Length(Raw) = 0 then
    raise EGitError.Create('commit-graph: no commits to write');
  Data := BuildGraphBytes(Raw);
  Path := PathJoin([AGitDir, 'objects', 'info', 'commit-graph']);
  MkdirAll(PathDir(Path), PermDirDefault);
  WriteAtomic(Path, Data);
  InvalidateCommitGraphCache(AGitDir);
  G := TCommitGraph.Create(Data);
  try
    if G.NumCommits <> Cardinal(Length(Raw)) then
      raise EGitError.Create('commit-graph verify: count mismatch');
  finally
    G.Free;
  end;
  if not GitVerifyCommitGraph(AGitDir) then
    raise EGitError.Create('commit-graph verify failed');
  Result := Path;
end;

end.
