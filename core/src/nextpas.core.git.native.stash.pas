unit nextpas.core.git.native.stash;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.git.native.base,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.reflog;

{ Stash list reader + push builder built on top of the reflog layer.

  Git stores stashes as commits reachable from refs/stash and logs
  each push in logs/refs/stash. `git stash list` is the reflog for
  that ref in reverse (newest-first) with the usual "stash@{N}: ..."
  decoration. The native stash subfamily exposes the same view without
  invoking git: read logs/refs/stash, reverse, and surface the new-oid,
  committer signature and message. An absent logs/refs/stash (no stashes)
  yields an empty array; a corrupt reflog line raises EGitError.

  GitStashPush builds a stash commit natively: index tree + working tree
  trees are written as loose objects, index/stash commits are created
  with parents [HEAD] / [HEAD,index], reflog appended to logs/refs/stash,
  ref refs/stash updated, and worktree reset to HEAD via checkout. }

type
  TGitStashEntry = record
    Oid: TGitOid;
    Committer: TGitSignature;
    Message: string;
  end;
  TGitStashArray = array of TGitStashEntry;

function GitStashExists(const AGitDir: string): Boolean;
function GitStashCount(const AGitDir: string): Integer;
function GitStashList(const AGitDir: string): TGitStashArray;
function GitStashAt(const AGitDir: string; AIndex: Integer): TGitStashEntry;
function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string;
  AIncludeUntracked: Boolean): TGitOid;
function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string): TGitOid; overload;
function GitStashApply(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid;
function GitStashApply(const AGitDir, AWorkTree: string): TGitOid; overload;
procedure GitStashDrop(const AGitDir: string; AIndex: Integer); overload;
procedure GitStashDrop(const AGitDir: string); overload;
function GitStashPop(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid;
function GitStashPop(const AGitDir, AWorkTree: string): TGitOid; overload;
procedure GitStashClear(const AGitDir: string);

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.write,
  nextpas.core.git.native.index,
  nextpas.core.git.native.config,
  nextpas.core.git.native.checkout,
  nextpas.core.git.native.status;

function GitStashExists(const AGitDir: string): Boolean;
begin
  Result := GitReflogExists(AGitDir, 'refs/stash');
end;

function GitStashList(const AGitDir: string): TGitStashArray;
var
  Log: TGitReflog;
  I, N: Integer;
begin
  Result := nil;
  Log := GitReadReflog(AGitDir, 'refs/stash');
  N := Length(Log);
  SetLength(Result, N);
  for I := 0 to N - 1 do
  begin
    Result[I].Oid := Log[N - 1 - I].NewOid;
    Result[I].Committer := Log[N - 1 - I].Committer;
    Result[I].Message := Log[N - 1 - I].Message;
  end;
end;

function GitStashCount(const AGitDir: string): Integer;
begin
  Result := Length(GitStashList(AGitDir));
end;

function GitStashAt(const AGitDir: string; AIndex: Integer): TGitStashEntry;
var
  List: TGitStashArray;
begin
  List := GitStashList(AGitDir);
  if (AIndex < 0) or (AIndex >= Length(List)) then
    raise EGitError.CreateFmt('stash index %d out of range', [AIndex]);
  Result := List[AIndex];
end;

{ ── helpers for stash push ─────────────────────────────────────────────── }

function TwoDigits(AValue: Integer): string;
begin
  if AValue < 10 then Exit('0' + IntToStr(AValue));
  Result := IntToStr(AValue);
end;

function FormatTz(AOffsetMin: Integer): string;
var
  SignCh: Char;
  AbsMin: Integer;
begin
  SignCh := '+';
  AbsMin := AOffsetMin;
  if AbsMin < 0 then
  begin
    SignCh := '-';
    AbsMin := -AbsMin;
  end;
  Result := SignCh + TwoDigits(AbsMin div 60) + TwoDigits(AbsMin mod 60);
end;

function SignatureToString(const ASig: TGitSignature): string;
begin
  Result := ASig.Name + ' <' + ASig.Email + '> '
    + IntToStr(ASig.UnixTime) + ' ' + FormatTz(ASig.TzMinutes);
end;

function BranchNameFromHead(const AGitDir: string): string;
var
  RefName: string;
begin
  try
    RefName := GitHeadRefName(AGitDir);
  except
    Exit('HEAD');
  end;
  if Copy(RefName, 1, 11) = 'refs/heads/' then
    Result := Copy(RefName, 12, MaxInt)
  else
    Result := RefName;
end;

function LoadHeadCommitInfo(const AGitDir: string; out AHeadOid: TGitOid;
  out AInfo: TGitCommitInfo): Boolean;
var
  Repo: TNativeRepository;
  Kind: TGitObjectKind;
  Data: TBytes;
begin
  Result := False;
  try
    AHeadOid := GitResolveHead(AGitDir);
  except
    Exit(False);
  end;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Data := Repo.ReadObject(AHeadOid, Kind);
    // peel tag to commit if HEAD points to tag
    while Kind = gokTag do
    begin
      AInfo := Default(TGitCommitInfo);
      // parse tag to get target
      Data := Repo.ReadObject(GitParseTag(Data).Target, Kind);
    end;
    if Kind <> gokCommit then Exit(False);
    AInfo := GitParseCommit(Data);
  finally
    Repo.Free;
  end;
  Result := True;
end;

function GetStashSignature(const AGitDir: string; const AHeadInfo: TGitCommitInfo): TGitSignature;
var
  Cfg: TGitConfig;
  N, E: string;
begin
  Cfg := GitReadConfig(AGitDir);
  try
    N := GitConfigGet(Cfg, 'user.name');
  except
    N := '';
  end;
  try
    E := GitConfigGet(Cfg, 'user.email');
  except
    E := '';
  end;
  if N = '' then N := AHeadInfo.Committer.Name;
  if E = '' then E := AHeadInfo.Committer.Email;
  if N = '' then N := 'Test Er';
  if E = '' then E := 'test@example.com';
  Result.Name := N;
  Result.Email := E;
  Result.UnixTime := AHeadInfo.Committer.UnixTime + 1;
  if Result.UnixTime <= 0 then Result.UnixTime := 1700000000;
  Result.TzMinutes := AHeadInfo.Committer.TzMinutes;
end;

function SortedIndexEntries(const AFile: TGitIndexFile): TGitIndexEntryArray;
var
  I: Integer;
begin
  SetLength(Result, Length(AFile.Entries));
  for I := 0 to High(AFile.Entries) do Result[I] := AFile.Entries[I];
  GitSortIndexEntries(Result);
end;

function PathOrdCompare(const AA, AB: string): Integer;
var I, Ml: SizeInt;
begin
  if Length(AA) < Length(AB) then Ml := Length(AA) else Ml := Length(AB);
  for I := 1 to Ml do
    if Ord(AA[I]) <> Ord(AB[I]) then Exit(Ord(AA[I]) - Ord(AB[I]));
  Result := Length(AA) - Length(AB);
end;

function WriteTreeFromSortedIndex(const AGitDir: string;
  const AEntries: TGitIndexEntryArray): TGitOid;
var
  AllOuter: TGitTreeEntryArray;

  function Rec(APrefix: string; ALo, AHi: Integer): TGitOid;
  var
    Direct: TGitTreeEntryArray;
    I, GroupEnd, SlashPos: Integer;
    Rest, ChildName, ChildPrefix: string;
    ChildOid: TGitOid;
    All: TGitTreeEntryArray;
  begin
    Direct := nil;
    I := ALo;
    while I <= AHi do
    begin
      Rest := Copy(AEntries[I].Path, Length(APrefix) + 1, MaxInt);
      SlashPos := Pos('/', Rest);
      if SlashPos = 0 then
      begin
        SetLength(Direct, Length(Direct) + 1);
        Direct[High(Direct)].Mode := AEntries[I].Mode;
        Direct[High(Direct)].Name := Rest;
        Direct[High(Direct)].Oid := AEntries[I].Oid;
        Inc(I);
      end
      else
      begin
        ChildName := Copy(Rest, 1, SlashPos - 1);
        ChildPrefix := APrefix + ChildName + '/';
        GroupEnd := I;
        while (GroupEnd <= AHi) and
          (Copy(AEntries[GroupEnd].Path, 1, Length(ChildPrefix)) = ChildPrefix) do
          Inc(GroupEnd);
        ChildOid := Rec(ChildPrefix, I, GroupEnd - 1);
        SetLength(Direct, Length(Direct) + 1);
        Direct[High(Direct)].Mode := $4000;
        Direct[High(Direct)].Name := ChildName;
        Direct[High(Direct)].Oid := ChildOid;
        I := GroupEnd;
      end;
    end;
    if Length(Direct) = 0 then
    begin
      // empty tree: well-known empty tree oid
      All := nil;
      Result := GitWriteTree(AGitDir, All);
      Exit;
    end;
    All := Direct;
    Result := GitWriteTree(AGitDir, All);
  end;

begin
  if Length(AEntries) = 0 then
  begin
    AllOuter := nil;
    Result := GitWriteTree(AGitDir, AllOuter);
    Exit;
  end;
  // entries must be sorted bytewise
  Result := Rec('', 0, High(AEntries));
end;

function BuildWorkingEntries(const AGitDir, AWorkTree: string;
  const ASortedIndex: TGitIndexEntryArray;
  AIncludeUntracked: Boolean): TGitIndexEntryArray;
var
  St: TGitNativeStatusArray;
  I: Integer;
  WorkMap: array of TGitIndexEntry;
  Entry: TGitIndexEntry;
  FilePath: string;
  Data: TBytes;
  Oid: TGitOid;
begin
  // start from sorted index
  SetLength(WorkMap, Length(ASortedIndex));
  for I := 0 to High(ASortedIndex) do WorkMap[I] := ASortedIndex[I];
  Result := nil;
  // we need status to find untracked if requested, and to know deletions
  // Instead of relying solely on status, scan worktree existence for tracked files
  for I := 0 to High(WorkMap) do
  begin
    FilePath := PathJoin([AWorkTree, WorkMap[I].Path]);
    if not FileExists(FilePath) and not IsSymlink(FilePath) and not DirectoryExists(FilePath) then
    begin
      // deleted in worktree -> omit
      Continue;
    end;
    if IsSymlink(FilePath) then
    begin
      // keep symlink as is (read link target would be needed for correct blob)
      // For now keep index oid
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := WorkMap[I];
      Continue;
    end;
    if DirectoryExists(FilePath) then
    begin
      // type change dir -> omit? keep original is wrong but rare
      Continue;
    end;
    // regular file: hash worktree content and compare
    try
      Data := ReadFile(FilePath);
    except
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := WorkMap[I];
      Continue;
    end;
    Oid := GitHashObject(gokBlob, Data);
    if GitOidSame(Oid, WorkMap[I].Oid) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := WorkMap[I];
    end
    else
    begin
      Oid := GitLooseWrite(AGitDir, gokBlob, Data);
      Entry := WorkMap[I];
      Entry.Oid := Oid;
      Entry.Size := Cardinal(Length(Data));
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Entry;
    end;
  end;
  if AIncludeUntracked then
  begin
    St := GitCollectStatus(AGitDir, AWorkTree, True);
    for I := 0 to High(St) do
      if St[I].WorkCode = gscUntracked then
      begin
        FilePath := PathJoin([AWorkTree, St[I].Path]);
        if DirectoryExists(FilePath) then Continue;
        if not FileExists(FilePath) then Continue;
        try Data := ReadFile(FilePath); except Continue; end;
        Oid := GitLooseWrite(AGitDir, gokBlob, Data);
        Entry := Default(TGitIndexEntry);
        Entry.Path := St[I].Path;
        Entry.Mode := $81A4;
        Entry.Oid := Oid;
        Entry.Size := Cardinal(Length(Data));
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Entry;
      end;
  end;
  if Length(Result) > 1 then
    GitSortIndexEntries(Result);
end;

function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string;
  AIncludeUntracked: Boolean): TGitOid;
var
  HeadOid, IndexTreeOid, WorkTreeOid, IndexCommitOid, StashOid, OldOid, ZeroOid: TGitOid;
  HeadInfo: TGitCommitInfo;
  HasHead: Boolean;
  IdxFile: TGitIndexFile;
  SortedIdx: TGitIndexEntryArray;
  WorkingEntries: TGitIndexEntryArray;
  Sig: TGitSignature;
  Branch: string;
  StashMsg, IdxMsg: string;
  NeedIndexCommit: Boolean;
  Builder: TGitCommitBuilder;
  ReflogPath, RefPath, OldHex, NewHex, Line: string;
  LogData: TBytes;
  ShortHead: string;
begin
  if AGitDir = '' then raise EGitError.Create('stash push: gitdir empty');
  if AWorkTree = '' then raise EGitError.Create('stash push: worktree empty');
  if not IsGitDirShape(AGitDir) then raise EGitError.CreateFmt('stash push: not a git dir %s', [AGitDir]);
  HasHead := LoadHeadCommitInfo(AGitDir, HeadOid, HeadInfo);
  if not HasHead then
    raise EGitError.Create('stash push: no HEAD commit');
  // check changes via status
  if Length(GitCollectStatus(AGitDir, AWorkTree, AIncludeUntracked)) = 0 then
    raise EGitError.Create('No local changes to save');
  // index tree
  try
    IdxFile := GitReadIndex(AGitDir);
    SortedIdx := SortedIndexEntries(IdxFile);
  except
    SortedIdx := nil;
  end;
  if Length(SortedIdx) = 0 then
    IndexTreeOid := GitHashObject(gokTree, nil)
  else
    IndexTreeOid := WriteTreeFromSortedIndex(AGitDir, SortedIdx);
  // need to ensure empty tree object exists if needed (writeTree already writes)
  // working tree oid
  WorkingEntries := BuildWorkingEntries(AGitDir, AWorkTree, SortedIdx, AIncludeUntracked);
  if Length(WorkingEntries) = 0 then
    WorkTreeOid := GitHashObject(gokTree, nil)
  else
    WorkTreeOid := WriteTreeFromSortedIndex(AGitDir, WorkingEntries);

  Sig := GetStashSignature(AGitDir, HeadInfo);
  Branch := BranchNameFromHead(AGitDir);
  ShortHead := Copy(GitOidToHex(HeadOid), 1, 7);
  if AMessage <> '' then
    StashMsg := 'On ' + Branch + ': ' + AMessage
  else
    StashMsg := 'WIP on ' + Branch + ': ' + ShortHead + ' ' + Trim(HeadInfo.Message);
  // decide if index commit needed (index tree != HEAD tree)
  NeedIndexCommit := not GitOidSame(IndexTreeOid, HeadInfo.Tree);
  // Also if index commit would be same as work tree, no need for separate index commit?
  // Keep git logic: create index commit only when index differs from HEAD
  // and working differs from index? Simpler: when index != HEAD tree, create it
  IndexCommitOid := Default(TGitOid);
  if NeedIndexCommit then
  begin
    IdxMsg := 'index on ' + Branch + ': ' + ShortHead + ' ' + Trim(HeadInfo.Message);
    Builder := Default(TGitCommitBuilder);
    Builder.Tree := IndexTreeOid;
    SetLength(Builder.Parents, 1);
    Builder.Parents[0] := HeadOid;
    Builder.AuthorName := Sig.Name;
    Builder.AuthorEmail := Sig.Email;
    Builder.AuthorUnixTime := Sig.UnixTime;
    Builder.AuthorTzMinutes := Sig.TzMinutes;
    Builder.CommitterName := Sig.Name;
    Builder.CommitterEmail := Sig.Email;
    Builder.CommitterUnixTime := Sig.UnixTime;
    Builder.CommitterTzMinutes := Sig.TzMinutes;
    Builder.Message := IdxMsg + #10;
    IndexCommitOid := GitWriteCommit(AGitDir, Builder);
  end;
  // stash commit
  Builder := Default(TGitCommitBuilder);
  Builder.Tree := WorkTreeOid;
  if NeedIndexCommit then
  begin
    SetLength(Builder.Parents, 2);
    Builder.Parents[0] := HeadOid;
    Builder.Parents[1] := IndexCommitOid;
  end
  else
  begin
    SetLength(Builder.Parents, 1);
    Builder.Parents[0] := HeadOid;
  end;
  Builder.AuthorName := Sig.Name;
  Builder.AuthorEmail := Sig.Email;
  Builder.AuthorUnixTime := Sig.UnixTime;
  Builder.AuthorTzMinutes := Sig.TzMinutes;
  Builder.CommitterName := Sig.Name;
  Builder.CommitterEmail := Sig.Email;
  Builder.CommitterUnixTime := Sig.UnixTime;
  Builder.CommitterTzMinutes := Sig.TzMinutes;
  Builder.Message := StashMsg + #10;
  StashOid := GitWriteCommit(AGitDir, Builder);

  // update reflog and ref
  ZeroOid := Default(TGitOid);
  try
    OldOid := GitResolveRef(AGitDir, 'refs/stash');
  except
    OldOid := ZeroOid;
  end;
  OldHex := GitOidToHex(OldOid);
  // if refs/stash missing, old is zero
  if GitOidSame(OldOid, ZeroOid) then
    OldHex := StringOfChar('0', 40);
  NewHex := GitOidToHex(StashOid);
  // ensure directories
  MkdirAll(PathJoin([AGitDir, 'logs', 'refs']), PermDirDefault);
  MkdirAll(PathJoin([AGitDir, 'refs']), PermDirDefault);
  ReflogPath := GitReflogPath(AGitDir, 'refs/stash');
  MkdirAll(PathDir(ReflogPath), PermDirDefault);
  Line := OldHex + ' ' + NewHex + ' ' + SignatureToString(Sig) + #9 + StashMsg + #10;
  // append
  if FileExists(ReflogPath) then
  begin
    LogData := ReadFile(ReflogPath);
    SetLength(LogData, Length(LogData) + Length(Line));
    Move(Line[1], LogData[Length(LogData) - Length(Line)], Length(Line));
    WriteFile(ReflogPath, LogData, PermDefault);
  end
  else
    WriteFileText(ReflogPath, Line);
  RefPath := PathJoin([AGitDir, 'refs', 'stash']);
  WriteFileText(RefPath, NewHex + #10);
  // reset worktree to HEAD
  GitCheckoutTree(AGitDir, AWorkTree, HeadInfo.Tree);
  Result := StashOid;
end;

function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string): TGitOid;
begin
  Result := GitStashPush(AGitDir, AWorkTree, AMessage, False);
end;

function GitStashApply(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid;
var
  List: TGitStashArray;
  Oid: TGitOid;
  Repo: TNativeRepository;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
begin
  if AGitDir = '' then raise EGitError.Create('stash apply: gitdir empty');
  if AWorkTree = '' then raise EGitError.Create('stash apply: worktree empty');
  List := GitStashList(AGitDir);
  if (AIndex < 0) or (AIndex >= Length(List)) then
    raise EGitError.CreateFmt('stash index %d out of range', [AIndex]);
  Oid := List[AIndex].Oid;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Data := Repo.ReadObject(Oid, Kind);
    if Kind <> gokCommit then
      raise EGitError.CreateFmt('stash %d oid %s is not a commit', [AIndex, GitOidToHex(Oid)]);
    Info := GitParseCommit(Data);
    // checkout the stash working tree; index will be set to match it (simplified)
    GitCheckoutTree(AGitDir, AWorkTree, Info.Tree);
  finally
    Repo.Free;
  end;
  Result := Oid;
end;

function GitStashApply(const AGitDir, AWorkTree: string): TGitOid;
begin
  Result := GitStashApply(AGitDir, AWorkTree, 0);
end;

procedure GitStashDrop(const AGitDir: string; AIndex: Integer);
var
  Log: TGitReflog;
  N, RemovePos, I, J: Integer;
  NewLog: TGitReflog;
  ReflogPath, RefPath: string;
  S: string;
  Data: TBytes;
begin
  if AGitDir = '' then raise EGitError.Create('stash drop: gitdir empty');
  Log := GitReadReflog(AGitDir, 'refs/stash');
  N := Length(Log);
  if (AIndex < 0) or (AIndex >= N) then
    raise EGitError.CreateFmt('stash index %d out of range', [AIndex]);
  // list is reverse of log: list[0]=log[N-1]; so remove log[N-1-AIndex]
  RemovePos := N - 1 - AIndex;
  SetLength(NewLog, N - 1);
  J := 0;
  for I := 0 to N - 1 do
    if I <> RemovePos then
    begin
      NewLog[J] := Log[I];
      Inc(J);
    end;
  ReflogPath := GitReflogPath(AGitDir, 'refs/stash');
  RefPath := PathJoin([AGitDir, 'refs', 'stash']);
  if Length(NewLog) = 0 then
  begin
    if FileExists(ReflogPath) then Remove(ReflogPath);
    if FileExists(RefPath) then Remove(RefPath);
    // prune empty logs/refs dir if needed
    Exit;
  end;
  // rebuild file content: old new sig TAB msg LF
  S := '';
  for I := 0 to High(NewLog) do
  begin
    S := S + GitOidToHex(NewLog[I].OldOid) + ' ' + GitOidToHex(NewLog[I].NewOid) + ' '
      + SignatureToString(NewLog[I].Committer) + #9 + NewLog[I].Message + #10;
  end;
  Data := nil;
  SetLength(Data, Length(S));
  if Length(S) > 0 then Move(S[1], Data[0], Length(S));
  MkdirAll(PathDir(ReflogPath), PermDirDefault);
  WriteFile(ReflogPath, Data, PermDefault);
  WriteFileText(RefPath, GitOidToHex(NewLog[High(NewLog)].NewOid) + #10);
end;

procedure GitStashDrop(const AGitDir: string);
begin
  GitStashDrop(AGitDir, 0);
end;

function GitStashPop(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid;
begin
  Result := GitStashApply(AGitDir, AWorkTree, AIndex);
  GitStashDrop(AGitDir, AIndex);
end;

function GitStashPop(const AGitDir, AWorkTree: string): TGitOid;
begin
  Result := GitStashPop(AGitDir, AWorkTree, 0);
end;

procedure GitStashClear(const AGitDir: string);
var
  ReflogPath, RefPath: string;
begin
  if AGitDir = '' then raise EGitError.Create('stash clear: gitdir empty');
  ReflogPath := GitReflogPath(AGitDir, 'refs/stash');
  RefPath := PathJoin([AGitDir, 'refs', 'stash']);
  if FileExists(ReflogPath) then Remove(ReflogPath);
  if FileExists(RefPath) then Remove(RefPath);
end;

end.
