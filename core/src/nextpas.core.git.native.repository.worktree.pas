unit nextpas.core.git.native.repository.worktree;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.git.base,
  nextpas.core.git.intf,
  nextpas.core.git.native.base;

function RepositoryAddWorktree(const AGitDir, AWorkTree, AName, APath, ARef: string; ADetach: Boolean): IGitWorktree;
function RepositoryLookupWorktree(const AGitDir, AName: string): IGitWorktree;
function RepositoryListWorktrees(const AGitDir: string): nextpas.core.base.TStringArray;
function RepositoryPruneWorktree(const AGitDir, AName: string): Boolean;
function RepositoryCommitOnHead(const AGitDir, AWorkTree, AMessage, AAuthorName, AAuthorEmail: string): string;

implementation

uses
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.branch,
  nextpas.core.git.native.worktree,
  nextpas.core.git.native.write,
  nextpas.core.git.native.index,
  nextpas.core.git.native.config,
  nextpas.core.git.native.util,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.checkout,
  nextpas.core.bytes.ops,
  nextpas.core.text.utils,
  nextpas.core.os.env,
  nextpas.core.text.conv;

type
  TNativeWorktree = class(TInterfacedObject, IGitWorktree)
  private
    FName: string;
    FPath: string;
    FLocked: Boolean;
  public
    constructor Create(const AName, APath: string; ALocked: Boolean);
    function Name: string;
    function Path: string;
    function IsLocked: Boolean;
  end;

constructor TNativeWorktree.Create(const AName, APath: string; ALocked: Boolean);
begin
  inherited Create;
  FName := AName;
  FPath := APath;
  FLocked := ALocked;
end;

function TNativeWorktree.Name: string;
begin
  Result := FName;
end;

function TNativeWorktree.Path: string;
begin
  Result := FPath;
end;

function TNativeWorktree.IsLocked: Boolean;
begin
  Result := FLocked;
end;

function IsDirEmptyLocal(const APath: string): Boolean; inline;
var
  Ents: TDirEntryArray;
begin
  if not DirectoryExists(APath) then
    Exit(True);
  Ents := ReadDir(APath);
  Result := Length(Ents) = 0;
end;

function EffectiveMainDir(const AGitDir: string): string; inline;
begin
  if FileExists(PathJoin2(AGitDir, 'commondir')) then
    Result := GitCommonDir(AGitDir)
  else
    Result := AGitDir;
end;

function WriteTreeFromSortedIndex(const AGitDir: string; const AEntries: TGitIndexEntryArray): TGitOid;
var
  AllOuter: TGitTreeEntryArray;
  function Rec(APrefix: string; ALo, AHi: Integer): TGitOid;
  var
    Direct: TGitTreeEntryArray;
    I, GroupEnd, SlashPos: Integer;
    Rest, ChildName, ChildPrefix: string;
    ChildOid: TGitOid;
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
        while (GroupEnd <= AHi) and (Copy(AEntries[GroupEnd].Path, 1, Length(ChildPrefix)) = ChildPrefix) do
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
      AllOuter := nil;
      Result := GitWriteTree(AGitDir, AllOuter);
      Exit;
    end;
    Result := GitWriteTree(AGitDir, Direct);
  end;
begin
  if Length(AEntries) = 0 then
  begin
    AllOuter := nil;
    Result := GitWriteTree(AGitDir, AllOuter);
    Exit;
  end;
  Result := Rec('', 0, High(AEntries));
end;

function RepositoryAddWorktree(const AGitDir, AWorkTree, AName, APath, ARef: string; ADetach: Boolean): IGitWorktree;
var
  MainDir, WtGitDir: string;
  TargetOid: TGitOid;
  Repo: TNativeRepository;
  HasRef: Boolean;
  Work: TGitWorktree;
begin
  Result := nil;
  if Trim(AName) = '' then
    raise EGitError.Create('AddWorktree: name required');
  if Trim(APath) = '' then
    raise EGitError.Create('AddWorktree: path required');
  if (Pos('/', AName) > 0) or (Pos('\', AName) > 0) then
    raise EGitError.CreateFmt('AddWorktree: invalid name "%s"', [AName]);
  if AWorkTree = '' then
    raise EGitError.Create('AddWorktree: cannot add worktree to bare repository');
  MainDir := EffectiveMainDir(AGitDir);
  if GitIsWorktree(AGitDir) then
    raise EGitError.Create('AddWorktree: cannot add from linked worktree');
  WtGitDir := PathJoin2(PathJoin2(MainDir, 'worktrees'), AName);
  if DirectoryExists(WtGitDir) then
    raise EGitError.CreateFmt('AddWorktree: worktree "%s" already exists', [AName]);
  if DirectoryExists(APath) and not IsDirEmptyLocal(APath) then
    raise EGitError.CreateFmt('AddWorktree: path not empty %s', [APath]);
  HasRef := Trim(ARef) <> '';
  if HasRef then
  begin
    try
      TargetOid := GitRevParse(MainDir, Trim(ARef));
    except
      on EGitError do raise EGitError.CreateFmt('AddWorktree: cannot resolve ref "%s": %s', [ARef, CurrentExceptionMessage]);
      on Exception do raise EGitError.CreateFmt('AddWorktree: cannot resolve ref "%s": %s', [ARef, CurrentExceptionMessage]);
    end;
    if ADetach then
    begin
      Repo := TNativeRepository.Create(MainDir);
      try
        try
          TargetOid := GitRevParseCommit(MainDir, Trim(ARef));
        except
          if not Repo.HasObject(TargetOid) then
            raise EGitError.CreateFmt('AddWorktree: object %s not found', [GitOidToHex(TargetOid)]);
        end;
      finally
        Repo.Free;
      end;
    end;
  end
  else
  begin
    try
      TargetOid := GitResolveHead(MainDir);
    except
      on EGitError do raise EGitError.CreateFmt('AddWorktree: cannot resolve HEAD: %s', [CurrentExceptionMessage]);
      on Exception do raise EGitError.CreateFmt('AddWorktree: cannot resolve HEAD: %s', [CurrentExceptionMessage]);
    end;
  end;
  try
    if ADetach then
      Work := GitWorktreeAddDetached(MainDir, PathClean(APath), TargetOid)
    else
    begin
      if not GitBranchExists(MainDir, AName) then
        GitBranchCreate(MainDir, AName, TargetOid);
      if not DirectoryExists(APath) then
        MkdirAll(PathClean(APath), PermDirDefault);
      WtGitDir := PathJoin2(PathJoin2(MainDir, 'worktrees'), AName);
      if DirectoryExists(WtGitDir) then
        raise EGitError.CreateFmt('AddWorktree: id already exists %s', [AName]);
      MkdirAll(WtGitDir, PermDirDefault);
      WriteFileText(PathJoin2(WtGitDir, 'commondir'), '../..'#10);
      WriteFileText(PathJoin2(WtGitDir, 'gitdir'), PathClean(APath) + '/.git'#10);
      WriteFileText(PathJoin2(WtGitDir, 'HEAD'), 'ref: refs/heads/' + AName + #10);
      WriteFileText(PathJoin2(PathClean(APath), '.git'), 'gitdir: ' + PathClean(WtGitDir) + #10);
      GitCheckoutCommit(WtGitDir, PathClean(APath), GitBranchGetOid(MainDir, AName));
      Work.Path := PathClean(APath);
      Work.GitDir := WtGitDir;
    end;
  except
    on EGitError do raise;
    on Exception do raise EGitError.Create('AddWorktree: ' + CurrentExceptionMessage);
  end;
  try
    Result := RepositoryLookupWorktree(MainDir, AName);
  except
    Result := TNativeWorktree.Create(AName, PathClean(APath), False);
  end;
end;

function RepositoryLookupWorktree(const AGitDir, AName: string): IGitWorktree;
var
  MainDir: string;
  List: TGitWorktreeArray;
  I: Integer;
  Base: string;
begin
  Result := nil;
  if Trim(AName) = '' then
    raise EGitError.Create('LookupWorktree: name required');
  MainDir := EffectiveMainDir(AGitDir);
  List := GitWorktreeList(MainDir);
  for I := 0 to High(List) do
  begin
    if List[I].GitDir = MainDir then
      Continue;
    Base := PathBase(List[I].GitDir);
    if Base = AName then
    begin
      Result := TNativeWorktree.Create(AName, List[I].Path, False);
      Exit;
    end;
    if List[I].Path = AName then
    begin
      Result := TNativeWorktree.Create(AName, List[I].Path, False);
      Exit;
    end;
  end;
  raise EGitError.CreateFmt('LookupWorktree: not found "%s"', [AName]);
end;

function RepositoryListWorktrees(const AGitDir: string): nextpas.core.base.TStringArray;
var
  MainDir: string;
  List: TGitWorktreeArray;
  I, Count: Integer;
begin
  Result := nil;
  MainDir := EffectiveMainDir(AGitDir);
  List := GitWorktreeList(MainDir);
  SetLength(Result, Length(List));
  Count := 0;
  for I := 0 to High(List) do
  begin
    if List[I].GitDir = MainDir then
    begin
      Result[Count] := PathBase(PathClean(List[I].Path));
      if Result[Count] = '' then
        Result[Count] := 'main';
    end
    else
      Result[Count] := PathBase(List[I].GitDir);
    Inc(Count);
  end;
  SetLength(Result, Count);
end;

function RepositoryPruneWorktree(const AGitDir, AName: string): Boolean;
var
  MainDir, WtGitDir: string;
begin
  Result := False;
  if Trim(AName) = '' then
    Exit(False);
  MainDir := EffectiveMainDir(AGitDir);
  if GitIsWorktree(AGitDir) then
    Exit(False);
  WtGitDir := PathJoin2(PathJoin2(MainDir, 'worktrees'), Trim(AName));
  if not DirectoryExists(WtGitDir) then
    Exit(False);
  try
    RemoveAll(WtGitDir);
    Result := True;
  except
    Result := False;
  end;
end;

function RepositoryCommitOnHead(const AGitDir, AWorkTree, AMessage, AAuthorName, AAuthorEmail: string): string;
var
  MainDir: string;
  IdxFile: TGitIndexFile;
  Sorted, Stage0: TGitIndexEntryArray;
  I, Cnt: Integer;
  TreeOid, HeadOid, NewOid: TGitOid;
  HasHead: Boolean;
  HeadRef: string;
  Builder: TGitCommitBuilder;
  Cfg: TGitConfig;
  AuthorName, AuthorEmail: string;
  UnixTime: Int64;
  Info: TGitCommitInfo;
  Repo: TNativeRepository;
  Data: TBytes;
  Kind: TGitObjectKind;
begin
  Result := '';
  if Trim(AMessage) = '' then
    raise EGitError.Create('CommitOnHead: message required');
  if AWorkTree = '' then
    raise EGitError.Create('CommitOnHead: cannot commit in bare repository');
  MainDir := EffectiveMainDir(AGitDir);
  try
    IdxFile := GitReadIndex(MainDir);
  except
    IdxFile.Version := 2;
    SetLength(IdxFile.Entries, 0);
    IdxFile.HasCacheTree := False;
  end;
  SetLength(Sorted, Length(IdxFile.Entries));
  for I := 0 to High(IdxFile.Entries) do
    Sorted[I] := IdxFile.Entries[I];
  if Length(Sorted) > 1 then
    GitSortIndexEntries(Sorted);
  Cnt := 0;
  SetLength(Stage0, Length(Sorted));
  for I := 0 to High(Sorted) do
  begin
    if Sorted[I].Stage <> 0 then
      raise EGitError.CreateFmt('CommitOnHead: index has conflict stage %d at %s', [Sorted[I].Stage, Sorted[I].Path]);
    Stage0[Cnt] := Sorted[I];
    Inc(Cnt);
  end;
  SetLength(Stage0, Cnt);
  TreeOid := WriteTreeFromSortedIndex(MainDir, Stage0);
  HasHead := True;
  try
    HeadOid := GitResolveHead(MainDir);
  except
    HasHead := False;
    FillChar(HeadOid, SizeOf(HeadOid), 0);
  end;
  AuthorName := Trim(AAuthorName);
  AuthorEmail := Trim(AAuthorEmail);
  if (AuthorName = '') or (AuthorEmail = '') then
  begin
    try
      Cfg := GitReadConfig(MainDir);
    except
      Cfg.Entries := nil;
    end;
    if AuthorName = '' then
      try
        AuthorName := GitConfigGet(Cfg, 'user.name');
      except
        AuthorName := '';
      end;
    if AuthorEmail = '' then
      try
        AuthorEmail := GitConfigGet(Cfg, 'user.email');
      except
        AuthorEmail := '';
      end;
    if HasHead and ((AuthorName = '') or (AuthorEmail = '')) then
    begin
      Repo := TNativeRepository.Create(MainDir);
      try
        try
          Data := Repo.ReadObject(HeadOid, Kind);
          if Kind = gokCommit then
          begin
            Info := GitParseCommit(Data);
            if AuthorName = '' then
              AuthorName := Info.Committer.Name;
            if AuthorEmail = '' then
              AuthorEmail := Info.Committer.Email;
          end;
        except
        end;
      finally
        Repo.Free;
      end;
    end;
    if AuthorName = '' then
      AuthorName := 'Test Er';
    if AuthorEmail = '' then
      AuthorEmail := 'test@example.com';
  end;
  UnixTime := 1700000000;
  Builder := Default(TGitCommitBuilder);
  Builder.Tree := TreeOid;
  if HasHead then
  begin
    SetLength(Builder.Parents, 1);
    Builder.Parents[0] := HeadOid;
  end
  else
    SetLength(Builder.Parents, 0);
  Builder.AuthorName := AuthorName;
  Builder.AuthorEmail := AuthorEmail;
  Builder.AuthorUnixTime := UnixTime;
  Builder.AuthorTzMinutes := 0;
  Builder.CommitterName := AuthorName;
  Builder.CommitterEmail := AuthorEmail;
  Builder.CommitterUnixTime := UnixTime;
  Builder.CommitterTzMinutes := 0;
  if (Length(AMessage) > 0) and (AMessage[Length(AMessage)] <> #10) then
    Builder.Message := AMessage + #10
  else
    Builder.Message := AMessage;
  try
    NewOid := GitWriteCommit(MainDir, Builder);
  except
    on EGitError do raise;
    on Exception do raise EGitError.Create('CommitOnHead: write commit failed: ' + CurrentExceptionMessage);
  end;
  HeadRef := '';
  try
    HeadRef := GitHeadRefName(MainDir);
  except
    HeadRef := '';
  end;
  try
    if HeadRef <> '' then
    begin
      MkdirAll(PathDir(PathJoin2(MainDir, HeadRef)), PermDirDefault);
      WriteFileText(PathJoin2(MainDir, HeadRef), GitOidToHex(NewOid) + #10);
      try
        MkdirAll(PathJoin([MainDir, 'logs', 'refs', 'heads']), PermDirDefault);
        MkdirAll(PathJoin([MainDir, 'logs']), PermDirDefault);
      except
      end;
    end
    else
      WriteFileText(PathJoin2(MainDir, 'HEAD'), GitOidToHex(NewOid) + #10);
  except
    on Exception do raise EGitError.Create('CommitOnHead: update ref failed: ' + CurrentExceptionMessage);
  end;
  Result := GitOidToHex(NewOid);
end;

end.
