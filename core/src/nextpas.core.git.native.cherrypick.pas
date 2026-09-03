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
  nextpas.core.bytes.ops,
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

function LocalCompareStr(const A, B: string): Integer; inline;
var I, L: Integer;
begin
  L := Length(A); if Length(B) < L then L := Length(B);
  for I := 1 to L do if A[I] <> B[I] then Exit(Ord(A[I]) - Ord(B[I]));
  Result := Length(A) - Length(B);
end;

{ SortFlat: O(n log n) quicksort (median-of-3 + tail recursion).
  Replaces prior insertion O(n²). Zero-copy: swaps records, compares
  via inline LocalCompareStr on existing string storage (no alloc). }
procedure QuickSortFlat(var A: TFlatArray; L, R: Integer);
var I, J, M: Integer; Pivot: string; Tmp: TFlatEntry;
begin
  while L < R do
  begin
    M := (L + R) shr 1;
    if LocalCompareStr(A[L].Path, A[M].Path) > 0 then begin Tmp := A[L]; A[L] := A[M]; A[M] := Tmp; end;
    if LocalCompareStr(A[M].Path, A[R].Path) > 0 then begin Tmp := A[M]; A[M] := A[R]; A[R] := Tmp; end;
    if LocalCompareStr(A[L].Path, A[M].Path) > 0 then begin Tmp := A[L]; A[L] := A[M]; A[M] := Tmp; end;
    Pivot := A[M].Path;
    I := L; J := R;
    repeat
      while LocalCompareStr(A[I].Path, Pivot) < 0 do Inc(I);
      while LocalCompareStr(A[J].Path, Pivot) > 0 do Dec(J);
      if I <= J then
      begin
        if I <> J then begin Tmp := A[I]; A[I] := A[J]; A[J] := Tmp; end;
        Inc(I); Dec(J);
      end;
    until I > J;
    if (J - L) < (R - I) then
    begin
      if L < J then QuickSortFlat(A, L, J);
      L := I;
    end else
    begin
      if I < R then QuickSortFlat(A, I, R);
      R := J;
    end;
  end;
end;

procedure SortFlat(var A: TFlatArray); inline;
begin
  if Length(A) < 2 then Exit;
  QuickSortFlat(A, 0, High(A));
end;

{ CollectFlat: amortized O(n) via bytes.ops GrowArrayCapacity single source.
  Previously SetLength(Length+1) per entry → O(n²) copies.
  Zero-copy: string assignment is refcounted move, TGitOid 20B inline copy. }
procedure CollectFlat(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatArray; var ACount, ACap: SizeUInt); overload;
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
      CollectFlat(ARepo, Entries[I].Oid, Full + '/', AOut, ACount, ACap)
    else
    begin
      if ACount >= ACap then
      begin
        ACap := GrowArrayCapacity(ACap, ACount + 1);
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
var Cnt, Cap: SizeUInt;
begin
  Cnt := SizeUInt(Length(AOut)); Cap := Cnt;
  // single source geometric growth holds across recursion via shared Cnt/Cap
  CollectFlat(ARepo, ATreeOid, APrefix, AOut, Cnt, Cap);
  SetLength(AOut, Cnt);
end;

function BuildFlat(const AGitDir: string; const ATreeOid: TGitOid): TFlatArray;
var Repo: TNativeRepository; Cnt, Cap: SizeUInt;
begin
  Result := nil;
  if IsZeroOid(ATreeOid) then Exit;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Cnt := 0; Cap := 0;
    CollectFlat(Repo, ATreeOid, '', Result, Cnt, Cap);
    SetLength(Result, Cnt);
    SortFlat(Result);
  finally
    Repo.Free;
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
  LCap, LCnt: SizeUInt;
  // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source,
  // inline, O(1) amortized, avoids O(n²) SetLength(Length+1) churn; final SetLength trim once
  procedure EnsureFlatCap;
  begin
    if LCnt >= LCap then
    begin
      LCap := GrowArrayCapacity(LCap, LCnt + 1);
      SetLength(ABaseFlat, LCap);
    end;
  end;
begin
  LCnt := SizeUInt(Length(ABaseFlat)); LCap := LCnt;
  // keep spare capacity in underlying array to avoid reallocation per add
  if LCap < LCnt then LCap := LCnt;
  for I := 0 to High(ADiffs) do
  begin
    E := ADiffs[I];
    case E.Status of
      gdsAdded:
        begin
          EnsureFlatCap;
          ABaseFlat[LCnt].Path := E.Path;
          ABaseFlat[LCnt].Mode := E.NewMode;
          ABaseFlat[LCnt].Oid := E.NewOid;
          Inc(LCnt);
        end;
      gdsModified, gdsTypeChanged:
        begin
          Idx := FindFlatIndex(ABaseFlat, E.Path);
          // FindFlatIndex scans up to LCnt valid entries, but array may have cap slack; limit search
          // fallback: linear scan truncated to LCnt to avoid reading uninitialized tail
          if (Idx < 0) or (SizeUInt(Idx) >= LCnt) then
          begin
            // not found within active prefix → append with growth
            EnsureFlatCap;
            ABaseFlat[LCnt].Path := E.Path;
            ABaseFlat[LCnt].Mode := E.NewMode;
            ABaseFlat[LCnt].Oid := E.NewOid;
            Inc(LCnt);
          end else
          begin
            ABaseFlat[Idx].Mode := E.NewMode;
            ABaseFlat[Idx].Oid := E.NewOid;
          end;
        end;
      gdsDeleted:
        begin
          Idx := FindFlatIndex(ABaseFlat, E.Path);
          if (Idx >= 0) and (SizeUInt(Idx) < LCnt) then
          begin
            if SizeUInt(Idx) <> LCnt - 1 then
              ABaseFlat[Idx] := ABaseFlat[LCnt - 1];
            Dec(LCnt);
            // keep capacity for future adds/mods; shrinking via SetLength after loop
            // avoid managed leak: clear tail string ref
            ABaseFlat[LCnt].Path := '';
          end;
        end;
    end;
  end;
  SetLength(ABaseFlat, LCnt);
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
  EntriesCnt, EntriesCap: SizeUInt;
  SeenCnt, SeenCap: SizeUInt;
  SubFlatCnt, SubFlatCap: SizeUInt;
begin
  // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source,
  // inline, O(1) amortized, zero-copy Move for TGitTreeEntry/TFlatEntry,
  // avoids O(n²) SetLength(Length+1) churn on large trees; single trim before write
  Entries := nil; Seen := nil;
  EntriesCnt := 0; EntriesCap := 0;
  SeenCnt := 0; SeenCap := 0;
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
      // dedup dir via SeenCnt prefix (zero-copy string compare)
      Found := False;
      for K := 0 to Pred(SeenCnt) do if Seen[K] = Name then begin Found := True; Break; end;
      if Found then Continue;
      if SeenCnt >= SeenCap then
      begin
        SeenCap := GrowArrayCapacity(SeenCap, SeenCnt + 1);
        SetLength(Seen, SeenCap);
      end;
      Seen[SeenCnt] := Name;
      Inc(SeenCnt);
      // build subflat for this dir: amortized growth
      SubPrefix := APrefix + Name + '/';
      SubFlat := nil; SubFlatCnt := 0; SubFlatCap := 0;
      for J := 0 to High(AFlat) do
        if Pos(SubPrefix, AFlat[J].Path) = 1 then
        begin
          if SubFlatCnt >= SubFlatCap then
          begin
            SubFlatCap := GrowArrayCapacity(SubFlatCap, SubFlatCnt + 1);
            SetLength(SubFlat, SubFlatCap);
          end;
          SubFlat[SubFlatCnt] := AFlat[J];
          Inc(SubFlatCnt);
        end;
      SetLength(SubFlat, SubFlatCnt);
      SubOid := BuildTreeFromFlat(AGitDir, SubFlat, SubPrefix);
      Added.Name := Name;
      Added.Mode := $4000;
      Added.Oid := SubOid;
      if EntriesCnt >= EntriesCap then
      begin
        EntriesCap := GrowArrayCapacity(EntriesCap, EntriesCnt + 1);
        SetLength(Entries, EntriesCap);
      end;
      Entries[EntriesCnt] := Added;
      Inc(EntriesCnt);
    end
    else
    begin
      // file at this level
      if Pos('/', Name) > 0 then Continue;
      // avoid duplicate file (should not happen) – scan up to EntriesCnt
      HasSub := False;
      for K := 0 to Pred(EntriesCnt) do if Entries[K].Name = Name then begin HasSub := True; Break; end;
      if HasSub then Continue;
      Added.Name := Name;
      Added.Mode := AFlat[I].Mode;
      Added.Oid := AFlat[I].Oid;
      if EntriesCnt >= EntriesCap then
      begin
        EntriesCap := GrowArrayCapacity(EntriesCap, EntriesCnt + 1);
        SetLength(Entries, EntriesCap);
      end;
      Entries[EntriesCnt] := Added;
      Inc(EntriesCnt);
    end;
  end;
  SetLength(Entries, EntriesCnt);
  SetLength(Seen, SeenCnt); // trim slack, refcounted strings zero-copy
  if EntriesCnt = 0 then
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
