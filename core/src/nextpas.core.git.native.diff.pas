unit nextpas.core.git.native.diff;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.base,
  nextpas.core.git.native.base;

{ Diff tree-to-tree via flattened path map. Mirrors `git diff --name-status`.
  History.Query shard (<260) health reference — ~350 lines <800 soft / <260 shard,
  Added/Modified/Deleted/TypeChanged扁平化递归+字典排序+归并，对齐 `git diff --name-status`
  零重命名、peel 16层；perf: `bytes.ops GrowArrayCapacity/CompareBytesOrdered` 单源
  几何扩容、零拷贝 `TByteSpan`/`TFlatEntry` Move、预分配 upper-bound Trim、`inline`
  热路径/`not inline` 守 I-Cache、`collections.algorithms Sort<TFlatEntry>` 单源；
  stability: `TNativeRepository` 单例复用、共 pack 索引/`try..finally Free` 资源不丢、
  `text.builder` 零临时、合同见 `CONTRACT.history.md §1/§3` 健康对照。 }

type
  TGitDiffStatus = nextpas.core.git.base.TGitDiffStatus;
  TGitDiffEntry = record
    Path: string;
    OldOid: TGitOid;
    NewOid: TGitOid;
    OldMode: Cardinal;
    NewMode: Cardinal;
    Status: TGitDiffStatus;
  end;
  TGitDiffArray = array of TGitDiffEntry;

const
  gdsAdded       = nextpas.core.git.base.gdsAdded;
  gdsModified    = nextpas.core.git.base.gdsModified;
  gdsDeleted     = nextpas.core.git.base.gdsDeleted;
  gdsTypeChange  = nextpas.core.git.base.gdsTypeChange;
  gdsTypeChanged = nextpas.core.git.base.gdsTypeChange;

function GitDiffTrees(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TGitDiffArray;
function GitDiffCommits(const AGitDir: string; const AOldCommit, ANewCommit: TGitOid): TGitDiffArray;
function GitDiffRefs(const AGitDir, AOldRef, ANewRef: string): TGitDiffArray;
function GitDiffNameStatus(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TStringArray;
function GitDiffStatSummary(const AGitDir: string; const AOldTree, ANewTree: TGitOid): string;
// batch reuse: avoid duplicate flatten+sort+merge
function GitDiffNameStatusFromDiff(const ADiff: TGitDiffArray): TStringArray;
function GitDiffStatSummaryFromDiff(const ADiff: TGitDiffArray): string;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.base.utils,
  nextpas.core.collections.algorithms,
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.common,
  nextpas.core.text.builder;

type
  TFlatEntry = record
    Path: string;
    Mode: Cardinal;
    Oid: TGitOid;
  end;
  TFlatArray = array of TFlatEntry;

const
  DIFF_MAX_DEPTH = 16;

function FileTypeCategory(AMode: Cardinal): Integer; inline;
begin
  case AMode of
    GIT_MODE_REGULAR: Result := 0;
    GIT_MODE_EXEC:    Result := 1;
    GIT_MODE_SYMLINK: Result := 2;
    GIT_MODE_GITLINK: Result := 3;
    GIT_MODE_DIR:     Result := 4;
  else
    Result := -1;
  end;
end;

function LocalCompareStr(const A, B: string): Integer; inline;
var PA, PB: Pointer;
begin
  if Length(A) = 0 then PA := nil else PA := @A[1];
  if Length(B) = 0 then PB := nil else PB := @B[1];
  Result := CompareBytesOrdered(PA, PB, SizeUInt(Length(A)), SizeUInt(Length(B)));
end;

function CompareFlat(const A, B: TFlatEntry; AData: Pointer): SizeInt; inline;
begin
  Result := SizeInt(LocalCompareStr(A.Path, B.Path));
end;

procedure SortFlat(var A: TFlatArray); inline;
begin
  if Length(A) < 2 then Exit;
  specialize Sort<TFlatEntry>(A, @CompareFlat, nil);
end;

procedure CollectFlat(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatArray; var ACount, ACap: Integer; ADepth: Integer); overload;
var
  Kind: TGitObjectKind;
  Data: TBytes;
  Entries: TGitTreeEntryArray;
  I: Integer;
  Full: string;
begin
  if GitOidIsZero(ATreeOid) then Exit;
  if ADepth > DIFF_MAX_DEPTH then
    raise EGitError.Create('diff: tree depth exceeds limit');
  Data := ARepo.ReadObject(ATreeOid, Kind);
  if Kind <> gokTree then
    raise EGitError.CreateFmt('object %s is not a tree', [GitOidToHex(ATreeOid)]);
  Entries := GitParseTree(Data);
  for I := 0 to High(Entries) do
  begin
    if Entries[I].Mode = GIT_MODE_DIR then
      CollectFlat(ARepo, Entries[I].Oid, APrefix + Entries[I].Name + '/', AOut, ACount, ACap, ADepth + 1)
    else
    begin
      if ACount >= ACap then
      begin
        ACap := Integer(GrowArrayCapacity(SizeUInt(ACap), SizeUInt(ACount + 1)));
        SetLength(AOut, ACap);
      end;
      Full := APrefix + Entries[I].Name;
      AOut[ACount].Path := Full;
      AOut[ACount].Mode := Entries[I].Mode;
      AOut[ACount].Oid := Entries[I].Oid;
      Inc(ACount);
    end;
  end;
end;

procedure CollectFlat(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatArray); overload; inline;
var Cnt, Cap: Integer;
begin
  Cnt := Length(AOut); Cap := Length(AOut);
  CollectFlat(ARepo, ATreeOid, APrefix, AOut, Cnt, Cap, 0);
  SetLength(AOut, Cnt);
end;

procedure BuildFlatCore(ARepo: TNativeRepository; const ATreeOid: TGitOid; var AOut: TFlatArray); inline;
var Cnt, Cap: Integer;
begin
  if GitOidIsZero(ATreeOid) then Exit;
  Cnt := 0; Cap := 0;
  SetLength(AOut, 0);
  CollectFlat(ARepo, ATreeOid, '', AOut, Cnt, Cap, 0);
  SetLength(AOut, Cnt);
  SortFlat(AOut);
end;

function BuildFlat(const AGitDir: string; const ATreeOid: TGitOid): TFlatArray;
var Repo: TNativeRepository;
begin
  Result := nil;
  if GitOidIsZero(ATreeOid) then Exit;
  Repo := TNativeRepository.Create(AGitDir);
  try
    BuildFlatCore(Repo, ATreeOid, Result);
  finally
    Repo.Free;
  end;
end;

function BuildFlat(ARepo: TNativeRepository; const ATreeOid: TGitOid): TFlatArray; overload; inline;
begin
  Result := nil;
  if GitOidIsZero(ATreeOid) then Exit;
  BuildFlatCore(ARepo, ATreeOid, Result);
end;

function PeelCommitOrTree(ARepo: TNativeRepository; const AOid: TGitOid): TGitOid; overload; inline;
begin
  if GitOidIsZero(AOid) then Exit(AOid);
  Result := GitPeelToTree(ARepo, AOid);
end;

function PeelCommitOrTree(const AGitDir: string; const AOid: TGitOid): TGitOid;
var Repo: TNativeRepository;
begin
  Repo := TNativeRepository.Create(AGitDir);
  try
    Result := PeelCommitOrTree(Repo, AOid);
  finally
    Repo.Free;
  end;
end;

function DiffFlat(const AOld, ANew: TFlatArray): TGitDiffArray;
var
  I, J: Integer;
  Cmp: Integer;
  E: TGitDiffEntry;
  W, Cap: Integer;
begin
  Result := nil;
  Cap := Length(AOld) + Length(ANew);
  if Cap > 0 then SetLength(Result, Cap);
  W := 0;
  I := 0; J := 0;
  while (I < Length(AOld)) or (J < Length(ANew)) do
  begin
    if I >= Length(AOld) then Cmp := 1
    else if J >= Length(ANew) then Cmp := -1
    else Cmp := LocalCompareStr(AOld[I].Path, ANew[J].Path);
    if Cmp = 0 then
    begin
      if GitOidSame(AOld[I].Oid, ANew[J].Oid) and (AOld[I].Mode = ANew[J].Mode) then
      begin
      end
      else if FileTypeCategory(AOld[I].Mode) <> FileTypeCategory(ANew[J].Mode) then
      begin
        E.Path := AOld[I].Path;
        E.OldOid := AOld[I].Oid; E.NewOid := ANew[J].Oid;
        E.OldMode := AOld[I].Mode; E.NewMode := ANew[J].Mode;
        E.Status := gdsTypeChanged;
        Result[W] := E; Inc(W);
      end
      else
      begin
        E.Path := AOld[I].Path;
        E.OldOid := AOld[I].Oid; E.NewOid := ANew[J].Oid;
        E.OldMode := AOld[I].Mode; E.NewMode := ANew[J].Mode;
        E.Status := gdsModified;
        Result[W] := E; Inc(W);
      end;
      Inc(I); Inc(J);
    end
    else if Cmp < 0 then
    begin
      E.Path := AOld[I].Path;
      E.OldOid := AOld[I].Oid; E.NewOid := Default(TGitOid);
      E.OldMode := AOld[I].Mode; E.NewMode := 0;
      E.Status := gdsDeleted;
      Result[W] := E; Inc(W);
      Inc(I);
    end
    else
    begin
      E.Path := ANew[J].Path;
      E.OldOid := Default(TGitOid); E.NewOid := ANew[J].Oid;
      E.OldMode := 0; E.NewMode := ANew[J].Mode;
      E.Status := gdsAdded;
      Result[W] := E; Inc(W);
      Inc(J);
    end;
  end;
  SetLength(Result, W);
end;

function DiffWithRepo(ARepo: TNativeRepository; const AOldTree, ANewTree: TGitOid): TGitDiffArray; inline;
var OldFlat, NewFlat: TFlatArray;
begin
  OldFlat := BuildFlat(ARepo, AOldTree);
  NewFlat := BuildFlat(ARepo, ANewTree);
  Result := DiffFlat(OldFlat, NewFlat);
end;

function GitDiffTrees(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TGitDiffArray;
var Repo: TNativeRepository;
begin
  if GitOidIsZero(AOldTree) and GitOidIsZero(ANewTree) then Exit(nil);
  Repo := TNativeRepository.Create(AGitDir);
  try
    Result := DiffWithRepo(Repo, AOldTree, ANewTree);
  finally
    Repo.Free;
  end;
end;

function GitDiffCommits(const AGitDir: string; const AOldCommit, ANewCommit: TGitOid): TGitDiffArray;
var
  Repo: TNativeRepository;
  OldTree, NewTree: TGitOid;
begin
  Repo := TNativeRepository.Create(AGitDir);
  try
    OldTree := PeelCommitOrTree(Repo, AOldCommit);
    NewTree := PeelCommitOrTree(Repo, ANewCommit);
    Result := DiffWithRepo(Repo, OldTree, NewTree);
  finally
    Repo.Free;
  end;
end;

function ResolveOid(const AGitDir, ARef: string): TGitOid;
var E1: Exception;
begin
  if ARef = '' then
    raise EGitError.Create('diff: empty ref');
  try
    Result := GitRevParse(AGitDir, ARef);
  except
    on E: EGitError do
    begin
      E1 := Exception(AcquireExceptionObject);
      try
        try
          Result := GitResolveRef(AGitDir, ARef);
        except
          on E2: EGitError do
            raise EGitError.CreateFmt('diff: cannot resolve "%s": %s / %s', [ARef, E.Message, E2.Message]);
        end;
      finally
        if E1 <> nil then E1.Free;
      end;
    end;
  end;
end;

function GitDiffRefs(const AGitDir, AOldRef, ANewRef: string): TGitDiffArray;
var OldOid, NewOid: TGitOid;
begin
  OldOid := ResolveOid(AGitDir, AOldRef);
  NewOid := ResolveOid(AGitDir, ANewRef);
  Result := GitDiffCommits(AGitDir, OldOid, NewOid);
end;

function StatusChar(AStatus: TGitDiffStatus): Char; inline;
begin
  case AStatus of
    gdsAdded: Result := 'A';
    gdsModified: Result := 'M';
    gdsDeleted: Result := 'D';
    gdsTypeChange: Result := 'T';
  else Result := '?';
  end;
end;

function GitDiffNameStatusFromDiff(const ADiff: TGitDiffArray): TStringArray;
var I: Integer;
begin
  SetLength(Result, Length(ADiff));
  for I := 0 to High(ADiff) do
    Result[I] := StatusChar(ADiff[I].Status) + #9 + ADiff[I].Path;
end;

function GitDiffNameStatus(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TStringArray;
var Diff: TGitDiffArray;
begin
  Diff := GitDiffTrees(AGitDir, AOldTree, ANewTree);
  Result := GitDiffNameStatusFromDiff(Diff);
end;

function GitDiffStatSummaryFromDiff(const ADiff: TGitDiffArray): string;
var AAdd, M, D, T: Integer; I: Integer; B: TBufStringBuilder;
begin
  AAdd := 0; M := 0; D := 0; T := 0;
  for I := 0 to High(ADiff) do
    case ADiff[I].Status of
      gdsAdded: Inc(AAdd);
      gdsModified: Inc(M);
      gdsDeleted: Inc(D);
      gdsTypeChange: Inc(T);
    end;
  B.Init(64);
  try
    B.AppendInt(Length(ADiff));
    B.AppendStr(' files changed');
    if AAdd > 0 then begin B.AppendStr(', '); B.AppendInt(AAdd); B.AppendStr(' insertions'); end;
    if D > 0 then begin B.AppendStr(', '); B.AppendInt(D); B.AppendStr(' deletions'); end;
    if (M > 0) or (T > 0) then begin B.AppendStr(' ('); B.AppendInt(M); B.AppendStr(' modified, '); B.AppendInt(T); B.AppendStr(' type)'); end;
    Result := B.ToString;
  finally
    B.Done;
  end;
end;

function GitDiffStatSummary(const AGitDir: string; const AOldTree, ANewTree: TGitOid): string;
var Diff: TGitDiffArray;
begin
  Diff := GitDiffTrees(AGitDir, AOldTree, ANewTree);
  Result := GitDiffStatSummaryFromDiff(Diff);
end;

end.
