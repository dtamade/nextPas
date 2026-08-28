unit nextpas.core.git.native.worktree;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.git.native.base,
  nextpas.core.git.native.refs;

{ Worktree subfamily: list + add/remove for linked worktrees.

  Layout mirrors `git worktree`:
  - main `.git/worktrees/<id>/` with `commondir` (`../..`), `gitdir`
    (absolute to `<worktree>/.git`) and `HEAD`
  - linked worktree carries only a `.git` file `gitdir: <path>`

  `GitWorktreeAdd` creates a new linked worktree on a (new or existing)
  branch and checks out its tree; `AddDetached` creates a detached
  worktree; `Remove` unregisters and deletes the worktree directory. }

type
  TGitWorktree = record
    Path: string;
    GitDir: string;
    CommonDir: string;
    HeadRef: string;
    IsDetached: Boolean;
    DetachedOid: TGitOid;
  end;
  TGitWorktreeArray = array of TGitWorktree;

function GitCommonDir(const AGitDir: string): string;
function GitWorktreeList(const AGitDir: string): TGitWorktreeArray;
function GitWorktreeCount(const AGitDir: string): Integer;
function GitIsWorktree(const AGitDir: string): Boolean;

function GitWorktreeAdd(const AGitDir, AWorkTreePath, ABranchName: string): TGitWorktree; overload;
function GitWorktreeAddDetached(const AGitDir, AWorkTreePath: string; const AOid: TGitOid): TGitWorktree;
procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string); overload;
procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string; AForce: Boolean); overload;

implementation

uses
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.checkout;

function TrimSpaces(const S: string): string;
var
  L, R: Integer;
begin
  L := 1;
  R := Length(S);
  while (L <= R) and (S[L] <= ' ') do Inc(L);
  while (R >= L) and (S[R] <= ' ') do Dec(R);
  if R < L then Exit('');
  Result := Copy(S, L, R - L + 1);
end;

function IsZeroOidLocal(const AOid: TGitOid): Boolean;
var I: Integer;
begin
  for I:=0 to GitOidRawLen-1 do if AOid.Bytes[I]<>0 then Exit(False);
  Result:=True;
end;

function BaseNameOf(const APath: string): string;
var P: Integer;
begin
  P:=Length(APath);
  while (P>0) and (APath[P]<>'/') do Dec(P);
  Result:=Copy(APath,P+1,MaxInt);
  if Result='' then Result:='worktree';
end;

function IsDirEmptyLocal(const APath: string): Boolean;
var Ents: TDirEntryArray;
begin
  if not DirectoryExists(APath) then Exit(True);
  Ents:=ReadDir(APath);
  Result:=Length(Ents)=0;
end;

function EnsureBranch(const AMainDir: string; const ABranch: string; const AFallbackOid: TGitOid): TGitOid;
var RefPath: string;
begin
  RefPath:=PathJoin2(PathJoin2(AMainDir,'refs/heads'), ABranch);
  if FileExists(RefPath) then
  begin
    Result:=GitResolveRef(AMainDir, 'refs/heads/'+ABranch);
    Exit;
  end;
  MkdirAll(PathDir(RefPath), PermDirDefault);
  WriteFileText(RefPath, GitOidToHex(AFallbackOid)+#10);
  Result:=AFallbackOid;
end;

function GitCommonDir(const AGitDir: string): string;
var
  C: string;
begin
  C := PathJoin2(AGitDir, 'commondir');
  if FileExists(C) then
  begin
    Result := TrimSpaces(ReadFileText(C));
    if not PathIsAbsolute(Result) then
      Result := PathClean(PathJoin2(AGitDir, Result))
    else
      Result := PathClean(Result);
    if not DirectoryExists(Result) then
      raise EGitError.CreateFmt('worktree commondir not found: %s', [Result]);
    Exit(Result);
  end;
  Result := AGitDir;
end;

function GitIsWorktree(const AGitDir: string): Boolean;
begin
  Result := FileExists(PathJoin2(AGitDir, 'commondir'));
end;

function ResolveMainDir(const AGitDir: string): string;
begin
  if GitIsWorktree(AGitDir) then
    Result := GitCommonDir(AGitDir)
  else
    Result := AGitDir;
end;

function ReadHeadInfo(const AGitDir: string; out ARef: string; out ADetached: Boolean; out AOid: TGitOid): Boolean;
var
  T: string;
begin
  Result := False;
  ARef := '';
  ADetached := False;
  FillChar(AOid, SizeOf(AOid), 0);
  T := TrimSpaces(ReadFileText(PathJoin2(AGitDir, 'HEAD')));
  if T = '' then
    raise EGitError.CreateFmt('worktree HEAD missing in %s', [AGitDir]);
  if Copy(T, 1, 5) = 'ref: ' then
  begin
    ARef := TrimSpaces(Copy(T, 6, MaxInt));
    ADetached := False;
    Exit(True);
  end;
  if not GitOidIsValidHex(T) then
    raise EGitError.CreateFmt('worktree HEAD corrupt in %s: %s', [AGitDir, T]);
  AOid := GitOidFromHex(T);
  ARef := '';
  ADetached := True;
  Result := True;
end;

function WorktreeFromGitDir(const AWorkGitDir, ACommonDir: string; const APathHint: string): TGitWorktree;
var
  G, P: string;
  Ref: string;
  Det: Boolean;
  Oid: TGitOid;
begin
  Result := Default(TGitWorktree);
  Result.GitDir := AWorkGitDir;
  Result.CommonDir := ACommonDir;
  if APathHint <> '' then
    Result.Path := APathHint
  else
  begin
    G := PathJoin2(AWorkGitDir, 'gitdir');
    if FileExists(G) then
    begin
      P := TrimSpaces(ReadFileText(G));
      if P <> '' then
        Result.Path := PathDir(P)
      else
        Result.Path := '';
    end;
    if Result.Path = '' then
      Result.Path := PathDir(AWorkGitDir);
  end;
  ReadHeadInfo(AWorkGitDir, Ref, Det, Oid);
  Result.HeadRef := Ref;
  Result.IsDetached := Det;
  Result.DetachedOid := Oid;
end;

function MainWorktree(const AMainDir: string): TGitWorktree;
var
  Ref: string;
  Det: Boolean;
  Oid: TGitOid;
  GFile: string;
  Target: string;
begin
  Result := Default(TGitWorktree);
  Result.GitDir := AMainDir;
  Result.CommonDir := AMainDir;
  GFile := PathJoin2(AMainDir, 'commondir');
  if FileExists(GFile) then
    Result.CommonDir := GitCommonDir(AMainDir);
  ReadHeadInfo(AMainDir, Ref, Det, Oid);
  Result.HeadRef := Ref;
  Result.IsDetached := Det;
  Result.DetachedOid := Oid;
  Target := PathDir(AMainDir);
  if (Length(Target) >= 4) and (Copy(Target, Length(Target) - 3, 4) = '/.git') then
    Target := Copy(Target, 1, Length(Target) - 5);
  Result.Path := Target;
  if Result.Path = '' then
    Result.Path := AMainDir;
end;

function GitWorktreeList(const AGitDir: string): TGitWorktreeArray;
var
  MainDir, WtRoot: string;
  Entries: TStringArray;
  DirEntries: TDirEntryArray;
  I, J, N: Integer;
  WtGitDir, Common: string;
  Info: TGitWorktree;
  GitDirFile: string;
begin
  Result := nil;
  if not DirectoryExists(AGitDir) then
    raise EGitError.CreateFmt('git dir not found: %s', [AGitDir]);
  MainDir := ResolveMainDir(AGitDir);
  Common := MainDir;
  SetLength(Result, 1);
  Result[0] := MainWorktree(MainDir);
  WtRoot := PathJoin2(MainDir, 'worktrees');
  if not DirectoryExists(WtRoot) then
    Exit;
  DirEntries := ReadDir(WtRoot);
  SetLength(Entries, 0);
  for J := 0 to High(DirEntries) do
  begin
    if (DirEntries[J].Name = '.') or (DirEntries[J].Name = '..') then
      Continue;
    if not DirEntries[J].IsDir then
      Continue;
    SetLength(Entries, Length(Entries) + 1);
    Entries[High(Entries)] := DirEntries[J].Name;
  end;
  for I := 0 to High(Entries) do
  begin
    WtGitDir := PathJoin2(WtRoot, Entries[I]);
    if not DirectoryExists(WtGitDir) then
      Continue;
    if not FileExists(PathJoin2(WtGitDir, 'HEAD')) then
      Continue;
    if not FileExists(PathJoin2(WtGitDir, 'commondir')) then
      Continue;
    GitDirFile := PathJoin2(WtGitDir, 'gitdir');
    if not FileExists(GitDirFile) then
      Continue;
    Info := WorktreeFromGitDir(WtGitDir, Common, '');
    if Info.Path = '' then
      Continue;
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := Info;
  end;
end;

function GitWorktreeCount(const AGitDir: string): Integer;
begin
  Result := Length(GitWorktreeList(AGitDir));
end;

function GitWorktreeAdd(const AGitDir, AWorkTreePath, ABranchName: string): TGitWorktree;
var MainDir, WtId, LinkedGitDir, BranchRef: string;
    Repo: TNativeRepository;
    HeadOid, TargetOid, BranchOid: TGitOid;
    Kind: TGitObjectKind;
    Data: TBytes;
begin
  if AGitDir='' then raise EGitError.Create('worktree add: gitdir empty');
  if AWorkTreePath='' then raise EGitError.Create('worktree add: worktree path empty');
  if ABranchName='' then raise EGitError.Create('worktree add: branch empty');
  MainDir:=ResolveMainDir(AGitDir);
  if GitIsWorktree(AGitDir) then raise EGitError.Create('worktree add: cannot add from linked worktree');
  if DirectoryExists(AWorkTreePath) and not IsDirEmptyLocal(AWorkTreePath) then
    raise EGitError.CreateFmt('worktree add: path not empty %s', [AWorkTreePath]);
  if not DirectoryExists(AWorkTreePath) then MkdirAll(AWorkTreePath, PermDirDefault);
  WtId:=BaseNameOf(AWorkTreePath);
  LinkedGitDir:=PathJoin2(PathJoin2(MainDir,'worktrees'), WtId);
  if DirectoryExists(LinkedGitDir) then raise EGitError.CreateFmt('worktree add: id already exists %s', [WtId]);
  // resolve target commit (HEAD)
  Repo:=TNativeRepository.Create(MainDir);
  try
    HeadOid:=GitResolveHead(MainDir);
    Data:=Repo.ReadObject(HeadOid, Kind);
    if Kind=gokCommit then TargetOid:=HeadOid
    else
    begin
      while Kind=gokTag do
      begin
        Data:=Repo.ReadObject(HeadOid, Kind);
        HeadOid:=GitParseTag(Data).Target;
        Data:=Repo.ReadObject(HeadOid, Kind);
      end;
      TargetOid:=HeadOid;
    end;
    BranchOid:=EnsureBranch(MainDir, ABranchName, TargetOid);
  finally
    Repo.Free;
  end;
  MkdirAll(LinkedGitDir, PermDirDefault);
  WriteFileText(PathJoin2(LinkedGitDir,'commondir'), '../..'#10);
  WriteFileText(PathJoin2(LinkedGitDir,'gitdir'), PathClean(AWorkTreePath)+'/.git'#10);
  BranchRef:='refs/heads/'+ABranchName;
  WriteFileText(PathJoin2(LinkedGitDir,'HEAD'), 'ref: '+BranchRef+#10);
  WriteFileText(PathJoin2(AWorkTreePath,'.git'), 'gitdir: '+PathClean(LinkedGitDir)+#10);
  // checkout branch tree into new worktree
  GitCheckoutCommit(LinkedGitDir, AWorkTreePath, BranchOid);
  Result:=WorktreeFromGitDir(LinkedGitDir, MainDir, AWorkTreePath);
end;

function GitWorktreeAddDetached(const AGitDir, AWorkTreePath: string; const AOid: TGitOid): TGitWorktree;
var MainDir, WtId, LinkedGitDir: string;
begin
  if AGitDir='' then raise EGitError.Create('worktree add detached: gitdir empty');
  if AWorkTreePath='' then raise EGitError.Create('worktree add detached: path empty');
  if IsZeroOidLocal(AOid) then raise EGitError.Create('worktree add detached: oid zero');
  MainDir:=ResolveMainDir(AGitDir);
  if GitIsWorktree(AGitDir) then raise EGitError.Create('worktree add detached: cannot add from linked');
  if DirectoryExists(AWorkTreePath) and not IsDirEmptyLocal(AWorkTreePath) then
    raise EGitError.CreateFmt('worktree add detached: path not empty %s', [AWorkTreePath]);
  if not DirectoryExists(AWorkTreePath) then MkdirAll(AWorkTreePath, PermDirDefault);
  WtId:=BaseNameOf(AWorkTreePath);
  LinkedGitDir:=PathJoin2(PathJoin2(MainDir,'worktrees'), WtId);
  if DirectoryExists(LinkedGitDir) then raise EGitError.CreateFmt('worktree add: id exists %s', [WtId]);
  MkdirAll(LinkedGitDir, PermDirDefault);
  WriteFileText(PathJoin2(LinkedGitDir,'commondir'), '../..'#10);
  WriteFileText(PathJoin2(LinkedGitDir,'gitdir'), PathClean(AWorkTreePath)+'/.git'#10);
  WriteFileText(PathJoin2(LinkedGitDir,'HEAD'), GitOidToHex(AOid)+#10);
  WriteFileText(PathJoin2(AWorkTreePath,'.git'), 'gitdir: '+PathClean(LinkedGitDir)+#10);
  GitCheckoutCommit(LinkedGitDir, AWorkTreePath, AOid);
  Result:=WorktreeFromGitDir(LinkedGitDir, MainDir, AWorkTreePath);
end;

procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string);
begin
  GitWorktreeRemove(AGitDir, AWorkTreePath, False);
end;

procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string; AForce: Boolean);
var MainDir, WtId, LinkedGitDir, CleanPath: string;
begin
  if AGitDir='' then raise EGitError.Create('worktree remove: gitdir empty');
  if AWorkTreePath='' then raise EGitError.Create('worktree remove: path empty');
  MainDir:=ResolveMainDir(AGitDir);
  CleanPath:=PathClean(AWorkTreePath);
  WtId:=BaseNameOf(CleanPath);
  LinkedGitDir:=PathJoin2(PathJoin2(MainDir,'worktrees'), WtId);
  if not DirectoryExists(LinkedGitDir) then
    raise EGitError.CreateFmt('worktree remove: not found %s', [AWorkTreePath]);
  if FileExists(PathJoin2(CleanPath,'.git')) then
  begin
    try RemoveAll(CleanPath); except if not AForce then raise; end;
  end
  else if DirectoryExists(CleanPath) and not IsDirEmptyLocal(CleanPath) and not AForce then
    raise EGitError.CreateFmt('worktree remove: path not empty and no .git %s', [AWorkTreePath]);
  try RemoveAll(LinkedGitDir); except if not AForce then raise; end;
end;

end.
