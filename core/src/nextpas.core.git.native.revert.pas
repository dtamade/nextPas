unit nextpas.core.git.native.revert;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.git.native.base;

{ Revert subfamily: inverse cherry-pick à la `git revert`.
  Reverse first-parent diff (Target→Parent) applied onto HEAD tree,
  new tree built recursively, new commit created with
  `Revert "<subject>"` trailer. }

function GitRevert(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; overload;
function GitRevert(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; overload;

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

function LocalTrim(const S: string): string;
var A, B: Integer;
begin
  A := 1; B := Length(S);
  while (A <= B) and (S[A] <= ' ') do Inc(A);
  while (B >= A) and (S[B] <= ' ') do Dec(B);
  if B < A then Result := '' else Result := Copy(S, A, B - A + 1);
end;

function FirstLine(const AMessage: string): string;
var P: Integer;
begin
  P := Pos(#10, AMessage);
  if P = 0 then Result := LocalTrim(AMessage)
  else Result := LocalTrim(Copy(AMessage, 1, P - 1));
  if Result = '' then Result := '(empty)';
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
  begin J := I;
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
  begin E := ADiffs[I];
    case E.Status of
      gdsAdded:
        begin SetLength(ABaseFlat, Length(ABaseFlat)+1);
          ABaseFlat[High(ABaseFlat)].Path := E.Path;
          ABaseFlat[High(ABaseFlat)].Mode := E.NewMode;
          ABaseFlat[High(ABaseFlat)].Oid := E.NewOid; end;
      gdsModified, gdsTypeChanged:
        begin Idx := FindFlatIndex(ABaseFlat, E.Path);
          if Idx >= 0 then begin ABaseFlat[Idx].Mode := E.NewMode; ABaseFlat[Idx].Oid := E.NewOid; end
          else begin SetLength(ABaseFlat, Length(ABaseFlat)+1);
            ABaseFlat[High(ABaseFlat)].Path := E.Path;
            ABaseFlat[High(ABaseFlat)].Mode := E.NewMode;
            ABaseFlat[High(ABaseFlat)].Oid := E.NewOid; end; end;
      gdsDeleted:
        begin Idx := FindFlatIndex(ABaseFlat, E.Path);
          if Idx >= 0 then begin ABaseFlat[Idx] := ABaseFlat[High(ABaseFlat)]; SetLength(ABaseFlat, Length(ABaseFlat)-1); end; end;
    end;
  end;
  SortFlat(ABaseFlat);
end;

function BuildTreeFromFlat(const AGitDir: string; const AFlat: TFlatArray; const APrefix: string): TGitOid;
var Entries: TGitTreeEntryArray; I, J, K: Integer; Name, SubPrefix: string; SlashPos: Integer; SubFlat: TFlatArray; SubOid: TGitOid; HasSub, Found: Boolean; Added: TGitTreeEntry; Seen: TStringArray;
begin
  SetLength(Entries, 0); SetLength(Seen, 0);
  for I := 0 to High(AFlat) do
  begin
    if (APrefix <> '') and (Pos(APrefix, AFlat[I].Path) <> 1) then Continue;
    Name := Copy(AFlat[I].Path, Length(APrefix)+1, MaxInt);
    if Name = '' then Continue;
    SlashPos := Pos('/', Name);
    if SlashPos > 0 then
    begin Name := Copy(Name, 1, SlashPos-1);
      Found := False; for K := 0 to High(Seen) do if Seen[K] = Name then begin Found := True; Break; end;
      if Found then Continue;
      SetLength(Seen, Length(Seen)+1); Seen[High(Seen)] := Name;
      SubPrefix := APrefix + Name + '/';
      SetLength(SubFlat, 0);
      for J := 0 to High(AFlat) do if Pos(SubPrefix, AFlat[J].Path) = 1 then begin SetLength(SubFlat, Length(SubFlat)+1); SubFlat[High(SubFlat)] := AFlat[J]; end;
      SubOid := BuildTreeFromFlat(AGitDir, SubFlat, SubPrefix);
      Added.Name := Name; Added.Mode := $4000; Added.Oid := SubOid;
      SetLength(Entries, Length(Entries)+1); Entries[High(Entries)] := Added;
    end else
    begin HasSub := False; for K := 0 to High(Entries) do if Entries[K].Name = Name then begin HasSub := True; Break; end;
      if HasSub then Continue;
      Added.Name := Name; Added.Mode := AFlat[I].Mode; Added.Oid := AFlat[I].Oid;
      SetLength(Entries, Length(Entries)+1); Entries[High(Entries)] := Added;
    end;
  end;
  Result := GitWriteTree(AGitDir, Entries);
end;

function GitRevertInternal(const AGitDir, AWorkTree: string; const ATargetOidRaw: TGitOid): TGitOid;
var Repo: TNativeRepository; HeadOid, TargetPeeled, HeadPeeled: TGitOid; HeadInfo, TargetInfo, ParentInfo: TGitCommitInfo; HeadTree, TargetTree, ParentTree: TGitOid; Diffs: TGitDiffArray; BaseFlat: TFlatArray; NewTree: TGitOid; Builder: TGitCommitBuilder; Data: TBytes; Kind: TGitObjectKind; HeadRef, Subject: string;
begin
  if AGitDir = '' then raise EGitError.Create('revert: gitdir empty');
  if AWorkTree = '' then raise EGitError.Create('revert: worktree empty');
  Repo := TNativeRepository.Create(AGitDir);
  try
    HeadOid := GitResolveHead(AGitDir);
    if IsZeroOid(HeadOid) then raise EGitError.Create('revert: HEAD empty');
    HeadPeeled := PeelToCommit(Repo, HeadOid);
    TargetPeeled := PeelToCommit(Repo, ATargetOidRaw);
    Data := Repo.ReadObject(HeadPeeled, Kind);
    if Kind <> gokCommit then raise EGitError.Create('HEAD not commit');
    HeadInfo := GitParseCommit(Data); HeadTree := HeadInfo.Tree;
    Data := Repo.ReadObject(TargetPeeled, Kind);
    if Kind <> gokCommit then raise EGitError.Create('target not commit');
    TargetInfo := GitParseCommit(Data); TargetTree := TargetInfo.Tree;
    if Length(TargetInfo.Parents) = 0 then ParentTree := Default(TGitOid)
    else begin Data := Repo.ReadObject(TargetInfo.Parents[0], Kind);
      if Kind <> gokCommit then raise EGitError.Create('parent not commit');
      ParentInfo := GitParseCommit(Data); ParentTree := ParentInfo.Tree; end;
    // reverse: Target -> Parent
    Diffs := GitDiffTrees(AGitDir, TargetTree, ParentTree);
    if Length(Diffs) = 0 then raise EGitError.Create('revert: nothing to revert');
    BaseFlat := BuildFlat(AGitDir, HeadTree);
    ApplyDiffs(BaseFlat, Diffs);
    NewTree := BuildTreeFromFlat(AGitDir, BaseFlat, '');
    Subject := FirstLine(TargetInfo.Message);
    Builder.Tree := NewTree;
    SetLength(Builder.Parents, 1); Builder.Parents[0] := HeadPeeled;
    Builder.Message := 'Revert "' + Subject + '"' + #10 + #10 + 'This reverts commit ' + GitOidToHex(TargetPeeled) + '.' + #10;
    Builder.AuthorName := TargetInfo.Author.Name; Builder.AuthorEmail := TargetInfo.Author.Email;
    Builder.AuthorUnixTime := TargetInfo.Author.UnixTime; Builder.AuthorTzMinutes := TargetInfo.Author.TzMinutes;
    Builder.CommitterName := TargetInfo.Committer.Name; Builder.CommitterEmail := TargetInfo.Committer.Email;
    Builder.CommitterUnixTime := TargetInfo.Committer.UnixTime; Builder.CommitterTzMinutes := TargetInfo.Committer.TzMinutes;
    Result := GitWriteCommit(AGitDir, Builder);
    HeadRef := GitHeadRefName(AGitDir);
    GitCheckoutCommit(AGitDir, AWorkTree, Result);
    if HeadRef <> '' then
    begin
      if Pos('refs/heads/', HeadRef) = 1 then
      begin ForceDirectories(AGitDir + '/refs/heads');
        WriteFileText(AGitDir + '/' + HeadRef, GitOidToHex(Result) + #10); end
      else WriteFileText(AGitDir + '/HEAD', GitOidToHex(Result) + #10);
    end;
  finally Repo.Free; end;
end;

function GitRevert(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid;
begin Result := GitRevertInternal(AGitDir, AWorkTree, ATargetOid); end;

function GitRevert(const AGitDir, AWorkTree, ATargetRef: string): TGitOid;
var Oid: TGitOid;
begin
  if ATargetRef = '' then raise EGitError.Create('revert: empty ref');
  try Oid := GitRevParse(AGitDir, ATargetRef);
  except Oid := GitResolveRef(AGitDir, ATargetRef); end;
  Result := GitRevertInternal(AGitDir, AWorkTree, Oid);
end;

end.
