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
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse;

type
  TFlatEntry = record
    Path: string;
    Mode: Cardinal;
    Oid: TGitOid;
  end;
  TFlatArray = array of TFlatEntry;

function IsZeroOid(const AOid: TGitOid): Boolean; inline;
var I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do if AOid.Bytes[I] <> 0 then Exit(False);
  Result := True;
end;

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
var I, L: Integer;
begin
  L := Length(A);
  if Length(B) < L then L := Length(B);
  for I := 1 to L do
    if A[I] <> B[I] then Exit(Ord(A[I]) - Ord(B[I]));
  Result := Length(A) - Length(B);
end;

procedure SortFlat(var A: TFlatArray);
  procedure MergeSort(var AItems: TFlatArray; var ATemp: TFlatArray; ALo, AHi: Integer);
  var
    Mid, I, J, K: Integer;
  begin
    if ALo >= AHi then
      Exit;
    Mid := (ALo + AHi) div 2;
    MergeSort(AItems, ATemp, ALo, Mid);
    MergeSort(AItems, ATemp, Mid + 1, AHi);
    I := ALo;
    J := Mid + 1;
    for K := ALo to AHi do
    begin
      if (I <= Mid) and ((J > AHi) or (LocalCompareStr(AItems[I].Path, AItems[J].Path) <= 0)) then
      begin
        ATemp[K] := AItems[I];
        Inc(I);
      end
      else
      begin
        ATemp[K] := AItems[J];
        Inc(J);
      end;
    end;
    for K := ALo to AHi do
      AItems[K] := ATemp[K];
  end;
var
  Temp: TFlatArray;
begin
  if Length(A) < 2 then
    Exit;
  SetLength(Temp, Length(A));
  MergeSort(A, Temp, 0, High(A));
end;

function CountFlatEntries(ARepo: TNativeRepository; const ATreeOid: TGitOid): SizeInt;
var
  Kind: TGitObjectKind;
  Data: TBytes;
  Entries: TGitTreeEntryArray;
  I: Integer;
begin
  Result := 0;
  if IsZeroOid(ATreeOid) then Exit;
  Data := ARepo.ReadObject(ATreeOid, Kind);
  if Kind <> gokTree then
    raise EGitError.CreateFmt('object %s is not a tree', [GitOidToHex(ATreeOid)]);
  Entries := GitParseTree(Data);
  for I := 0 to High(Entries) do
    if Entries[I].Mode = $4000 then
      Result := Result + CountFlatEntries(ARepo, Entries[I].Oid)
    else
      Inc(Result);
end;

procedure FillFlatEntries(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatArray; var APos: SizeInt);
var
  Kind: TGitObjectKind;
  Data: TBytes;
  Entries: TGitTreeEntryArray;
  I: Integer;
  Full: string;
begin
  if IsZeroOid(ATreeOid) then Exit;
  Data := ARepo.ReadObject(ATreeOid, Kind);
  if Kind <> gokTree then
    raise EGitError.CreateFmt('object %s is not a tree', [GitOidToHex(ATreeOid)]);
  Entries := GitParseTree(Data);
  for I := 0 to High(Entries) do
  begin
    Full := APrefix + Entries[I].Name;
    if Entries[I].Mode = $4000 then
      FillFlatEntries(ARepo, Entries[I].Oid, Full + '/', AOut, APos)
    else
    begin
      AOut[APos].Path := Full;
      AOut[APos].Mode := Entries[I].Mode;
      AOut[APos].Oid := Entries[I].Oid;
      Inc(APos);
    end;
  end;
end;

procedure CollectFlat(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatArray);
var
  Total: SizeInt;
  Pos: SizeInt;
begin
  if IsZeroOid(ATreeOid) then Exit;
  Total := CountFlatEntries(ARepo, ATreeOid);
  if Total = 0 then Exit;
  Pos := Length(AOut);
  SetLength(AOut, Pos + Total);
  FillFlatEntries(ARepo, ATreeOid, APrefix, AOut, Pos);
end;

function BuildFlat(const AGitDir: string; const ATreeOid: TGitOid): TFlatArray;
var
  Repo: TNativeRepository;
  Total: SizeInt;
  Pos: SizeInt;
begin
  Result := nil;
  if IsZeroOid(ATreeOid) then Exit;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Total := CountFlatEntries(Repo, ATreeOid);
    SetLength(Result, Total);
    Pos := 0;
    if Total > 0 then
      FillFlatEntries(Repo, ATreeOid, '', Result, Pos);
  finally
    Repo.Free;
  end;
  SortFlat(Result);
end;

function PeelToTree(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  TagInfo: TGitTagInfo;
  Depth: Integer;
begin
  Result := AOid;
  Depth := 0;
  while Depth < 16 do
  begin
    Data := ARepo.ReadObject(Result, Kind);
    if Kind = gokCommit then
    begin
      Info := GitParseCommit(Data);
      Result := Info.Tree;
      Exit;
    end
    else if Kind = gokTag then
    begin
      TagInfo := GitParseTag(Data);
      Result := TagInfo.Target;
      Inc(Depth);
    end
    else if Kind = gokTree then
      Exit
    else
      raise EGitError.CreateFmt('object %s is not commit/tree/tag', [GitOidToHex(AOid)]);
  end;
  raise EGitError.Create('peel too deep');
end;

function PeelCommitOrTree(const AGitDir: string; const AOid: TGitOid): TGitOid;
var Repo: TNativeRepository;
begin
  Repo := TNativeRepository.Create(AGitDir);
  try
    Result := PeelToTree(Repo, AOid);
  finally
    Repo.Free;
  end;
end;

function DiffFlat(const AOld, ANew: TFlatArray): TGitDiffArray;
var
  I, J: Integer;
  Cmp: Integer;
  E: TGitDiffEntry;
begin
  Result := nil;
  I := 0; J := 0;
  while (I < Length(AOld)) or (J < Length(ANew)) do
  begin
    if I >= Length(AOld) then Cmp := 1
    else if J >= Length(ANew) then Cmp := -1
    else Cmp := LocalCompareStr(AOld[I].Path, ANew[J].Path);
    if Cmp = 0 then
    begin
      // same path: compare oid/mode
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
        SetLength(Result, Length(Result)+1);
        Result[High(Result)] := E;
      end
      else
      begin
        E.Path := AOld[I].Path;
        E.OldOid := AOld[I].Oid; E.NewOid := ANew[J].Oid;
        E.OldMode := AOld[I].Mode; E.NewMode := ANew[J].Mode;
        E.Status := gdsModified;
        SetLength(Result, Length(Result)+1);
        Result[High(Result)] := E;
      end;
      Inc(I); Inc(J);
    end
    else if Cmp < 0 then
    begin
      // old only -> deleted
      E.Path := AOld[I].Path;
      E.OldOid := AOld[I].Oid; E.NewOid := Default(TGitOid);
      E.OldMode := AOld[I].Mode; E.NewMode := 0;
      E.Status := gdsDeleted;
      SetLength(Result, Length(Result)+1);
      Result[High(Result)] := E;
      Inc(I);
    end
    else
    begin
      // new only -> added
      E.Path := ANew[J].Path;
      E.OldOid := Default(TGitOid); E.NewOid := ANew[J].Oid;
      E.OldMode := 0; E.NewMode := ANew[J].Mode;
      E.Status := gdsAdded;
      SetLength(Result, Length(Result)+1);
      Result[High(Result)] := E;
      Inc(J);
    end;
  end;
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

function StatusChar(AStatus: TGitDiffStatus): Char;
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
