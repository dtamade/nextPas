unit nextpas.core.git.native.cherrypick;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.git.native.base;

{ Cherry-pick subfamily: apply commit diff à la `git cherry-pick`.
  First-parent diff applied onto HEAD tree via flat map,
  new tree built recursively, new commit created. }

function GitCherryPick(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; overload;
function GitCherryPick(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; overload;

implementation

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.write,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.diff,
  nextpas.core.git.native.checkout;

function IsZeroOid(const AOid: TGitOid): Boolean;
var I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do if AOid.Bytes[I] <> 0 then Exit(False);
  Result := True;
end;

function PeelToCommit(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var Kind: TGitObjectKind; Data: TBytes; TagInfo: TGitTagInfo; Depth: Integer;
begin
  Result := AOid; Depth := 0;
  while Depth < 16 do
  begin
    Data := ARepo.ReadObject(Result, Kind);
    if Kind = gokTag then
    begin TagInfo := GitParseTag(Data); Result := TagInfo.Target; Inc(Depth); end
    else if Kind = gokCommit then Exit
    else raise EGitError.CreateFmt('ref does not point to commit: %s', [GitOidToHex(AOid)]);
  end;
  raise EGitError.Create('tag peel too deep');
end;

type
  TFlatEntry = record
    Path: string;
    Mode: Cardinal;
    Oid: TGitOid;
  end;
  TFlatArray = array of TFlatEntry;

procedure CollectFlat(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatArray);
var Kind: TGitObjectKind; Data: TBytes; Entries: TGitTreeEntryArray; I: Integer; Full: string;
begin
  if IsZeroOid(ATreeOid) then Exit;
  Data := ARepo.ReadObject(ATreeOid, Kind);
  if Kind <> gokTree then raise EGitError.CreateFmt('object %s is not a tree', [GitOidToHex(ATreeOid)]);
  Entries := GitParseTree(Data);
  for I := 0 to High(Entries) do
  begin
    Full := APrefix + Entries[I].Name;
    if Entries[I].Mode = $4000 then
      CollectFlat(ARepo, Entries[I].Oid, Full + '/', AOut)
    else
    begin
      SetLength(AOut, Length(AOut)+1);
      AOut[High(AOut)].Path := Full;
      AOut[High(AOut)].Mode := Entries[I].Mode;
      AOut[High(AOut)].Oid := Entries[I].Oid;
    end;
  end;
end;

function BuildFlat(const AGitDir: string; const ATreeOid: TGitOid): TFlatArray;
var Repo: TNativeRepository;
begin
  Result := nil;
  if IsZeroOid(ATreeOid) then Exit;
  Repo := TNativeRepository.Create(AGitDir);
  try
    CollectFlat(Repo, ATreeOid, '', Result);
  finally
    Repo.Free;
  end;
end;

function LocalCompareStr(const A, B: string): Integer;
var I, L: Integer;
begin
  L := Length(A); if Length(B) < L then L := Length(B);
  for I := 1 to L do if A[I] <> B[I] then Exit(Ord(A[I]) - Ord(B[I]));
  Result := Length(A) - Length(B);
end;

procedure SortFlat(var A: TFlatArray);
var I, J: Integer; T: TFlatEntry;
begin
  for I := 1 to High(A) do
  begin
    J := I;
    while (J > 0) and (LocalCompareStr(A[J-1].Path, A[J].Path) > 0) do
    begin T := A[J-1]; A[J-1] := A[J]; A[J] := T; Dec(J); end;
  end;
end;

function FindFlatIndex(const A: TFlatArray; const APath: string): Integer;
var I: Integer;
begin
  for I := 0 to High(A) do if A[I].Path = APath then Exit(I);
  Result := -1;
end;

procedure ApplyDiffs(var ABaseFlat: TFlatArray; const ADiffs: TGitDiffArray);
var I, Idx: Integer; E: TGitDiffEntry;
begin
  for I := 0 to High(ADiffs) do
  begin
    E := ADiffs[I];
    case E.Status of
      gdsAdded:
        begin
          SetLength(ABaseFlat, Length(ABaseFlat)+1);
          ABaseFlat[High(ABaseFlat)].Path := E.Path;
          ABaseFlat[High(ABaseFlat)].Mode := E.NewMode;
          ABaseFlat[High(ABaseFlat)].Oid := E.NewOid;
        end;
      gdsModified, gdsTypeChanged:
        begin
          Idx := FindFlatIndex(ABaseFlat, E.Path);
          if Idx >= 0 then
          begin
            ABaseFlat[Idx].Mode := E.NewMode;
            ABaseFlat[Idx].Oid := E.NewOid;
          end
          else
          begin
            SetLength(ABaseFlat, Length(ABaseFlat)+1);
            ABaseFlat[High(ABaseFlat)].Path := E.Path;
            ABaseFlat[High(ABaseFlat)].Mode := E.NewMode;
            ABaseFlat[High(ABaseFlat)].Oid := E.NewOid;
          end;
        end;
      gdsDeleted:
        begin
          Idx := FindFlatIndex(ABaseFlat, E.Path);
          if Idx >= 0 then
          begin
            ABaseFlat[Idx] := ABaseFlat[High(ABaseFlat)];
            SetLength(ABaseFlat, Length(ABaseFlat)-1);
          end;
        end;
    end;
  end;
  SortFlat(ABaseFlat);
end;

function BuildTreeFromFlat(const AGitDir: string; const AFlat: TFlatArray; const APrefix: string): TGitOid;
var
  Entries: TGitTreeEntryArray;
  I, J: Integer;
  Name: string;
  SlashPos: Integer;
  SubPrefix: string;
  SubFlat: TFlatArray;
  SubOid: TGitOid;
  HasSub: Boolean;
  Added: TGitTreeEntry;
  Seen: TStringArray;
  K: Integer;
  Found: Boolean;
begin
  // collect direct children under APrefix
  SetLength(Entries, 0);
  SetLength(Seen, 0);
  for I := 0 to High(AFlat) do
  begin
    if (APrefix <> '') and (Pos(APrefix, AFlat[I].Path) <> 1) then Continue;
    Name := Copy(AFlat[I].Path, Length(APrefix)+1, MaxInt);
    if Name = '' then Continue;
    SlashPos := Pos('/', Name);
    if SlashPos > 0 then
    begin
      // directory
      Name := Copy(Name, 1, SlashPos-1);
      // dedup dir
      Found := False;
      for K := 0 to High(Seen) do if Seen[K] = Name then begin Found := True; Break; end;
      if Found then Continue;
      SetLength(Seen, Length(Seen)+1);
      Seen[High(Seen)] := Name;
      // build subflat for this dir
      SubPrefix := APrefix + Name + '/';
      SetLength(SubFlat, 0);
      for J := 0 to High(AFlat) do
        if Pos(SubPrefix, AFlat[J].Path) = 1 then
        begin
          SetLength(SubFlat, Length(SubFlat)+1);
          SubFlat[High(SubFlat)] := AFlat[J];
        end;
      SubOid := BuildTreeFromFlat(AGitDir, SubFlat, SubPrefix);
      Added.Name := Name;
      Added.Mode := $4000;
      Added.Oid := SubOid;
      SetLength(Entries, Length(Entries)+1);
      Entries[High(Entries)] := Added;
    end
    else
    begin
      // file at this level
      if Pos('/', Name) > 0 then Continue;
      // avoid duplicate file (should not happen)
      HasSub := False;
      for K := 0 to High(Entries) do if Entries[K].Name = Name then begin HasSub := True; Break; end;
      if HasSub then Continue;
      Added.Name := Name;
      Added.Mode := AFlat[I].Mode;
      Added.Oid := AFlat[I].Oid;
      SetLength(Entries, Length(Entries)+1);
      Entries[High(Entries)] := Added;
    end;
  end;
  if Length(Entries) = 0 then
  begin
    // empty tree: git writes empty tree with known oid 4b825dc642cb6eb9a060e54bf8d69288fbee4904
    // but we will write it via GitWriteTree which handles empty
  end;
  Result := GitWriteTree(AGitDir, Entries);
end;

function GitCherryPickInternal(const AGitDir, AWorkTree: string; const ATargetOidRaw: TGitOid): TGitOid;
var
  Repo: TNativeRepository;
  HeadOid, TargetOid, TargetPeeled, HeadPeeled: TGitOid;
  HeadInfo, TargetInfo, ParentInfo: TGitCommitInfo;
  HeadTree, TargetTree, ParentTree: TGitOid;
  Diffs: TGitDiffArray;
  BaseFlat: TFlatArray;
  NewTree: TGitOid;
  Builder: TGitCommitBuilder;
  Data: TBytes;
  Kind: TGitObjectKind;
  Sig: TGitSignature;
  HeadRef: string;
begin
  if AGitDir = '' then raise EGitError.Create('cherry-pick: gitdir empty');
  if AWorkTree = '' then raise EGitError.Create('cherry-pick: worktree empty');
  Repo := TNativeRepository.Create(AGitDir);
  try
    HeadOid := GitResolveHead(AGitDir);
    if IsZeroOid(HeadOid) then raise EGitError.Create('cherry-pick: HEAD empty');
    HeadPeeled := PeelToCommit(Repo, HeadOid);
    TargetPeeled := PeelToCommit(Repo, ATargetOidRaw);
    if GitOidSame(HeadPeeled, TargetPeeled) then raise EGitError.Create('cherry-pick: already at target');

    Data := Repo.ReadObject(HeadPeeled, Kind);
    if Kind <> gokCommit then raise EGitError.Create('HEAD not commit');
    HeadInfo := GitParseCommit(Data);
    HeadTree := HeadInfo.Tree;

    Data := Repo.ReadObject(TargetPeeled, Kind);
    if Kind <> gokCommit then raise EGitError.Create('target not commit');
    TargetInfo := GitParseCommit(Data);
    TargetTree := TargetInfo.Tree;

    if Length(TargetInfo.Parents) = 0 then
      ParentTree := Default(TGitOid) // root diff
    else
    begin
      Data := Repo.ReadObject(TargetInfo.Parents[0], Kind);
      if Kind <> gokCommit then raise EGitError.Create('parent not commit');
      ParentInfo := GitParseCommit(Data);
      ParentTree := ParentInfo.Tree;
    end;

    Diffs := GitDiffTrees(AGitDir, ParentTree, TargetTree);
    if Length(Diffs) = 0 then raise EGitError.Create('cherry-pick: nothing to apply');

    BaseFlat := BuildFlat(AGitDir, HeadTree);
    ApplyDiffs(BaseFlat, Diffs);
    NewTree := BuildTreeFromFlat(AGitDir, BaseFlat, '');

    // build commit: parent HEAD, tree new, message original + cherry-picked trailer
    Builder.Tree := NewTree;
    SetLength(Builder.Parents, 1);
    Builder.Parents[0] := HeadPeeled;
    Builder.Message := TargetInfo.Message + #10 + '(cherry picked from commit ' + GitOidToHex(TargetPeeled) + ')' + #10;
    Builder.AuthorName := TargetInfo.Author.Name;
    Builder.AuthorEmail := TargetInfo.Author.Email;
    Builder.AuthorUnixTime := TargetInfo.Author.UnixTime;
    Builder.AuthorTzMinutes := TargetInfo.Author.TzMinutes;
    Builder.CommitterName := TargetInfo.Committer.Name;
    Builder.CommitterEmail := TargetInfo.Committer.Email;
    Builder.CommitterUnixTime := TargetInfo.Committer.UnixTime;
    Builder.CommitterTzMinutes := TargetInfo.Committer.TzMinutes;
    // try to get config committer
    try
      // GitWriteCommit internally will use config if builder committer empty? Actually builder provides both.
      // We keep target committer for simplicity.
    except
    end;

    Result := GitWriteCommit(AGitDir, Builder);

    // update HEAD ref and checkout
    HeadRef := GitHeadRefName(AGitDir);
    if HeadRef <> '' then
    begin
      // update branch file
      // use refs write: create loose ref
      // reuse branch logic via file write
      // Simple: write file .git/refs/heads/<branch> or .git/HEAD if detached
      if HeadRef = 'HEAD' then
      begin
        // detached
        // write HEAD directly
        // Use refs helper? write file
        // For simplicity write .git/HEAD as detached oid
        // But we can just use GitCheckoutCommit to update worktree and then update ref via file
      end;
    end;
    // Use checkout to materialize new tree and update index
    GitCheckoutCommit(AGitDir, AWorkTree, Result);
    // update current branch or detached HEAD file
    if HeadRef <> '' then
    begin
      if Pos('refs/heads/', HeadRef) = 1 then
      begin
        ForceDirectories(AGitDir + '/refs/heads');
        // handle nested branches: ensure parent dirs
        // simple: create all needed via loop
        WriteFileText(AGitDir + '/' + HeadRef, GitOidToHex(Result) + #10);
      end
      else
      begin
        WriteFileText(AGitDir + '/HEAD', GitOidToHex(Result) + #10);
      end;
    end;
  finally
    Repo.Free;
  end;
end;

function GitCherryPick(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid;
begin
  Result := GitCherryPickInternal(AGitDir, AWorkTree, ATargetOid);
end;

function GitCherryPick(const AGitDir, AWorkTree, ATargetRef: string): TGitOid;
var Oid: TGitOid;
begin
  if ATargetRef = '' then raise EGitError.Create('cherry-pick: empty ref');
  try Oid := GitRevParse(AGitDir, ATargetRef);
  except Oid := GitResolveRef(AGitDir, ATargetRef); end;
  Result := GitCherryPickInternal(AGitDir, AWorkTree, Oid);
end;

end.
