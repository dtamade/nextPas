unit nextpas.core.git.native.diff;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Diff subfamily: tree-to-tree comparison (flattened path map).
  Status mirrors `git diff --name-status` for Added/Modified/Deleted/
  TypeChanged; rename detection intentionally omitted ( статус hashsig
  path is status-only). Trees are flattened recursively, sorted
  lexicographically, then merged. }

type
  TGitDiffStatus = (gdsAdded, gdsModified, gdsDeleted, gdsTypeChanged);

  TGitDiffEntry = record
    Path: string;
    OldOid: TGitOid;
    NewOid: TGitOid;
    OldMode: Cardinal;
    NewMode: Cardinal;
    Status: TGitDiffStatus;
  end;
  TGitDiffArray = array of TGitDiffEntry;

function GitDiffTrees(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TGitDiffArray;
function GitDiffCommits(const AGitDir: string; const AOldCommit, ANewCommit: TGitOid): TGitDiffArray;
function GitDiffRefs(const AGitDir, AOldRef, ANewRef: string): TGitDiffArray;
function GitDiffNameStatus(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TStringArray;
function GitDiffStatSummary(const AGitDir: string; const AOldTree, ANewTree: TGitOid): string;

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
  nextpas.core.git.native.push,
  nextpas.core.git.native.common;

type
  TFlatEntry = record
    Path: string;
    Mode: Cardinal;
    Oid: TGitOid;
  end;
  TFlatArray = array of TFlatEntry;

function FileTypeCategory(AMode: Cardinal): Integer; inline;
begin
  // 0=regular 100644, 1=exec 100755, 2=symlink 120000, 3=gitlink 160000, 4=dir (not in flat)
  case AMode of
    $81A4: Result := 0;
    $81ED: Result := 1;
    $A000: Result := 2;
    $E000: Result := 3;
    $4000: Result := 4;
  else
    Result := 0;
  end;
end;

function LocalCompareStr(const A, B: string): Integer; inline;
var PA, PB: Pointer;
begin
  // single source: base.utils CompareBytesOrdered (PByte+Len zero-copy, inline) — same source as bytes.ops SpanCompare, sorting/merge unified dispatch
  if Length(A) = 0 then PA := nil else PA := @A[1];
  if Length(B) = 0 then PB := nil else PB := @B[1];
  Result := CompareBytesOrdered(PA, PB, SizeUInt(Length(A)), SizeUInt(Length(B)));
end;

function CompareFlat(const A, B: TFlatEntry; AData: Pointer): SizeInt; inline;
begin
  // single source compare: LocalCompareStr -> base.utils CompareBytesOrdered (PByte+Len zero-copy, inline) == bytes.ops SpanCompare; unified with DiffFlat merge path
  Result := SizeInt(LocalCompareStr(A.Path, B.Path));
end;

{ SortFlat: single-source dispatch via collections.algorithms Sort<TFlatEntry> (IntroSort+HeapSort fallback).
  Replaces hand-rolled QuickSortFlat I-Cache copy; zero-copy compare via inline CompareFlat/LocalCompareStr on existing string storage (PByte+Len view, no alloc); inline forwarder ensures no extra call overhead; shares I-Cache with status path sorts (SortPathOids/SortStrings) and SortU32 via collections.arr.sort single family, merge path also uses same LocalCompareStr. }
procedure SortFlat(var A: TFlatArray); inline;
begin
  if Length(A) < 2 then Exit;
  specialize Sort<TFlatEntry>(A, @CompareFlat, nil);
end;

{ CollectFlat: amortized O(n) via bytes.ops GrowArrayCapacity single source.
  Previously SetLength(AOut,Length+1) per entry → O(n²) copies.
  Zero-copy: string assignment is refcounted move, TGitOid 20B inline copy via direct assignment. }
procedure CollectFlat(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatArray; var ACount, ACap: Integer); overload;
var
  Kind: TGitObjectKind;
  Data: TBytes;
  Entries: TGitTreeEntryArray;
  I: Integer;
  Full: string;
begin
  if GitOidIsZero(ATreeOid) then Exit;
  Data := ARepo.ReadObject(ATreeOid, Kind);
  if Kind <> gokTree then
    raise EGitError.CreateFmt('object %s is not a tree', [GitOidToHex(ATreeOid)]);
  Entries := GitParseTree(Data);
  for I := 0 to High(Entries) do
  begin
    Full := APrefix + Entries[I].Name;
    if Entries[I].Mode = $4000 then
      CollectFlat(ARepo, Entries[I].Oid, Full + '/', AOut, ACount, ACap)
    else
    begin
      if ACount >= ACap then
      begin
        // perf: amortized geometric growth single source via bytes.ops GrowArrayCapacity (BYTES_BUILDER_MIN_GROW + *2), inline, O(1) amortized per append, zero-copy TGitOid Move via direct assignment, avoids O(n²) SetLength(Length+1) churn
        ACap := Integer(GrowArrayCapacity(SizeUInt(ACap), SizeUInt(ACount + 1)));
        SetLength(AOut, ACap);
      end;
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
  CollectFlat(ARepo, ATreeOid, APrefix, AOut, Cnt, Cap);
  SetLength(AOut, Cnt);
end;

function BuildFlat(const AGitDir: string; const ATreeOid: TGitOid): TFlatArray;
var Repo: TNativeRepository; Cnt, Cap: Integer;
begin
  Result := nil;
  if GitOidIsZero(ATreeOid) then Exit;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Cnt := 0; Cap := 0;
    CollectFlat(Repo, ATreeOid, '', Result, Cnt, Cap);
    SetLength(Result, Cnt);
  finally
    Repo.Free;
  end;
  SortFlat(Result);
end;

// PeelToTree reused from nextpas.core.git.native.common (single source)

function PeelCommitOrTree(const AGitDir: string; const AOid: TGitOid): TGitOid;
var Repo: TNativeRepository;
begin
  Repo := TNativeRepository.Create(AGitDir);
  try
    Result := GitPeelToTree(Repo, AOid);
  finally
    Repo.Free;
  end;
end;

{ DiffFlat: prealloc upper-bound LenOld+LenNew → single alloc then trim.
  Previously SetLength(Result,Length+1) per diff → O(n²). }
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
        // unchanged, skip
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

function GitDiffTrees(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TGitDiffArray;
var
  OldFlat, NewFlat: TFlatArray;
begin
  OldFlat := BuildFlat(AGitDir, AOldTree);
  NewFlat := BuildFlat(AGitDir, ANewTree);
  Result := DiffFlat(OldFlat, NewFlat);
end;

function GitDiffCommits(const AGitDir: string; const AOldCommit, ANewCommit: TGitOid): TGitDiffArray;
var
  OldTree, NewTree: TGitOid;
begin
  OldTree := PeelCommitOrTree(AGitDir, AOldCommit);
  NewTree := PeelCommitOrTree(AGitDir, ANewCommit);
  Result := GitDiffTrees(AGitDir, OldTree, NewTree);
end;

function ResolveOid(const AGitDir, ARef: string): TGitOid;
begin
  if ARef = '' then
    raise EGitError.Create('diff: empty ref');
  try
    Result := GitRevParse(AGitDir, ARef);
  except
    Result := GitResolveRef(AGitDir, ARef);
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
    gdsTypeChanged: Result := 'T';
  else Result := '?';
  end;
end;

function GitDiffNameStatus(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TStringArray;
var
  Diff: TGitDiffArray;
  I: Integer;
begin
  Diff := GitDiffTrees(AGitDir, AOldTree, ANewTree);
  SetLength(Result, Length(Diff));
  for I := 0 to High(Diff) do
    Result[I] := StatusChar(Diff[I].Status) + #9 + Diff[I].Path;
end;

function GitDiffStatSummary(const AGitDir: string; const AOldTree, ANewTree: TGitOid): string;
var Diff: TGitDiffArray; A, M, D, T: Integer; I: Integer;
begin
  Diff := GitDiffTrees(AGitDir, AOldTree, ANewTree);
  A := 0; M := 0; D := 0; T := 0;
  for I := 0 to High(Diff) do
    case Diff[I].Status of
      gdsAdded: Inc(A);
      gdsModified: Inc(M);
      gdsDeleted: Inc(D);
      gdsTypeChanged: Inc(T);
    end;
  Result := IntToStr(Length(Diff)) + ' files changed';
  if A > 0 then Result := Result + ', ' + IntToStr(A) + ' insertions';
  if D > 0 then Result := Result + ', ' + IntToStr(D) + ' deletions';
  if (M > 0) or (T > 0) then Result := Result + ' (' + IntToStr(M) + ' modified, ' + IntToStr(T) + ' type)';
end;

end.
