unit nextpas.core.git.native.checkout;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Pure-Pascal worktree checkout (object layer → filesystem + index).

  Counterpart of `checkout.c` / `unpack-trees.c` for the single-tree
  fast path used by `git clone` and detached checkout. It materializes
  an arbitrary tree into a worktree, reconciles type changes
  (file ↔ directory ↔ symlink ↔ gitlink), prunes orphaned paths left
  by a previous checkout, preserves executable bits, and builds a
  v2 index so that `git status --porcelain` is clean without hashing.

  All operations are filesystem-local; no network. The pack/loose
  store is accessed exclusively through `TNativeRepository`. }

procedure GitCheckoutTree(const AGitDir, AWorkTree: string; const ATreeOid: TGitOid);
procedure GitCheckoutHead(const AGitDir, AWorkTree: string);
function GitCheckoutCommit(const AGitDir, AWorkTree: string; const ACommitOid: TGitOid): TGitOid;
function GitCheckoutRef(const AGitDir, AWorkTree, ARefName: string): TGitOid;

implementation

uses
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.index,
  nextpas.core.git.native.util;

const
  CModeTree    = $4000;
  CModeExec    = $81ED;
  CModeSymlink = $A000;
  CModeGitlink = $E000;

function EffectiveGitDir(const AGitDir: string): string;
var C: string;
begin
  if IsGitDirShape(AGitDir) then Exit(AGitDir);
  C:=PathJoin2(AGitDir,'commondir');
  if FileExists(C) then
  begin
    Result:=GitTrimSpaces(ReadFileText(C));
    if not PathIsAbsolute(Result) then Result:=PathClean(PathJoin2(AGitDir, Result))
    else Result:=PathClean(Result);
    Exit(Result);
  end;
  Result:=AGitDir;
end;

function PathOrdCompare(const AA, AB: string): Integer;
var I, MinLen: SizeInt;
begin
  if Length(AA) < Length(AB) then MinLen := Length(AA) else MinLen := Length(AB);
  for I := 1 to MinLen do
  begin
    if Ord(AA[I]) <> Ord(AB[I]) then Exit(Ord(AA[I]) - Ord(AB[I]));
  end;
  Result := Length(AA) - Length(AB);
end;

procedure SortStrings(var A: TStringArray);
  procedure MergeSort(var Items, Tmp: TStringArray; L, R: Integer);
  var M, I, J, K: Integer;
  begin
    if L >= R then Exit;
    M := (L + R) div 2;
    MergeSort(Items, Tmp, L, M);
    MergeSort(Items, Tmp, M + 1, R);
    I := L; J := M + 1;
    for K := L to R do
    begin
      if (I <= M) and ((J > R) or (PathOrdCompare(Items[I], Items[J]) <= 0)) then
      begin Tmp[K] := Items[I]; Inc(I); end
      else
      begin Tmp[K] := Items[J]; Inc(J); end;
    end;
    for K := L to R do Items[K] := Tmp[K];
  end;
var Tmp: TStringArray;
begin
  if Length(A) < 2 then Exit;
  SetLength(Tmp, Length(A));
  MergeSort(A, Tmp, 0, Length(A) - 1);
end;

function SortedContains(const A: TStringArray; const S: string): Boolean;
var L, R, M, C: Integer;
begin
  L := 0; R := Length(A) - 1;
  while L <= R do
  begin
    M := (L + R) div 2;
    C := PathOrdCompare(A[M], S);
    if C = 0 then Exit(True);
    if C < 0 then L := M + 1 else R := M - 1;
  end;
  Result := False;
end;

procedure EnsureParentDir(const AFilePath: string);
var D: string;
begin
  D := PathDir(AFilePath);
  if D <> '' then MkdirAll(D, PermDirDefault);
end;

function IsDirEmpty(const APath: string): Boolean;
var Ents: TDirEntryArray;
begin
  if not DirectoryExists(APath) then Exit(True);
  Ents := ReadDir(APath);
  Result := Length(Ents) = 0;
end;

procedure CollectEntriesRecursive(ARepo: TNativeRepository; const ATreeOid: TGitOid;
  const AWorkTree, APrefix: string; var AEntries: TGitIndexEntryArray);
var TreeData: TBytes;
    Kind: TGitObjectKind;
    TreeEnts: TGitTreeEntryArray;
    I: Integer;
    FullPath, FilePath, Target: string;
    BlobData: TBytes;
    BlobKind: TGitObjectKind;
    Info: TFileInfo;
    Idx: TGitIndexEntry;
    Sec, NSec: UInt64;
    EntCount: Integer;
begin
  TreeData := ARepo.ReadObject(ATreeOid, Kind);
  if Kind <> gokTree then
    raise EGitError.CreateFmt('checkout: oid %s is not a tree', [GitOidToHex(ATreeOid)]);
  TreeEnts := GitParseTree(TreeData);
  for I := 0 to High(TreeEnts) do
  begin
    FullPath := APrefix + TreeEnts[I].Name;
    if TreeEnts[I].Mode = CModeTree then
    begin
      FilePath := PathJoin([AWorkTree, FullPath]);
      if FileExists(FilePath) or IsSymlink(FilePath) then
        RemoveAll(FilePath);
      MkdirAll(FilePath, PermDirDefault);
      CollectEntriesRecursive(ARepo, TreeEnts[I].Oid, AWorkTree, FullPath + '/', AEntries);
    end
    else
    begin
      FilePath := PathJoin([AWorkTree, FullPath]);
      if IsDir(FilePath) then
        RemoveAll(FilePath);
      EnsureParentDir(FilePath);
      BlobData := ARepo.ReadObject(TreeEnts[I].Oid, BlobKind);
      if TreeEnts[I].Mode = CModeSymlink then
      begin
        Target := GitBytesToString(BlobData);
        if FileExists(FilePath) or IsSymlink(FilePath) or DirectoryExists(FilePath) then
          RemoveAll(FilePath);
        Symlink(Target, FilePath);
      end
      else if TreeEnts[I].Mode = CModeGitlink then
      begin
        { placeholder: no filesystem object }
      end
      else
      begin
        WriteFile(FilePath, BlobData);
        if TreeEnts[I].Mode = CModeExec then
          try Chmod(FilePath, $1ED) except end
        else
          try Chmod(FilePath, $1A4) except end;
      end;

      Idx := Default(TGitIndexEntry);
      Idx.Path := FullPath;
      Idx.Mode := TreeEnts[I].Mode;
      Idx.Oid := TreeEnts[I].Oid;
      Idx.Stage := 0;
      if TreeEnts[I].Mode = CModeGitlink then Idx.Size := 0 else Idx.Size := Cardinal(Length(BlobData));
      Idx.AssumeValid := False;
      Idx.SkipWorktree := False;
      Idx.IntentToAdd := False;
      Idx.Dev := 0; Idx.Ino := 0; Idx.UID := 0; Idx.GID := 0;
      try
        if TreeEnts[I].Mode = CModeSymlink then Info := Lstat(FilePath)
        else if TreeEnts[I].Mode = CModeGitlink then
        begin Info := Default(TFileInfo); Info.ModTime := 0; end
        else Info := Stat(FilePath);
        Sec := UInt64(Info.ModTime) div 1000000000;
        NSec := UInt64(Info.ModTime) mod 1000000000;
        if Info.ModTime = 0 then begin Sec := 0; NSec := 0; end;
        Idx.MTimeSec := Cardinal(Sec); Idx.MTimeNSec := Cardinal(NSec);
        Idx.CTimeSec := Cardinal(Sec); Idx.CTimeNSec := Cardinal(NSec);
      except
        Idx.MTimeSec := 0; Idx.MTimeNSec := 0; Idx.CTimeSec := 0; Idx.CTimeNSec := 0;
      end;
      EntCount := Length(AEntries);
      SetLength(AEntries, EntCount + 1);
      AEntries[EntCount] := Idx;
    end;
  end;
end;

procedure PruneWorkTree(const AWorkTree: string; const AEntries: TGitIndexEntryArray);
var Expected: TStringArray;
    Sorted: TStringArray;
    I: Integer;
  procedure WalkPrune(const ADir, APrefix: string);
  var Ents: TDirEntryArray;
      E: TDirEntry;
      Full, Rel: string;
  begin
    Ents := ReadDir(ADir);
    for E in Ents do
    begin
      if (APrefix = '') and (E.Name = '.git') then Continue;
      Full := PathJoin([ADir, E.Name]);
      Rel := APrefix + E.Name;
      if E.IsDir then
      begin
        WalkPrune(Full, Rel + '/');
        try
          if IsDirEmpty(Full) then Remove(Full);
        except
        end;
      end
      else
      begin
        if not SortedContains(Sorted, Rel) then
        try RemoveAll(Full); except end;
      end;
    end;
  end;
begin
  SetLength(Expected, 0);
  for I := 0 to High(AEntries) do
    if AEntries[I].Mode <> CModeGitlink then
    begin
      SetLength(Expected, Length(Expected) + 1);
      Expected[High(Expected)] := AEntries[I].Path;
    end;
  Sorted := Copy(Expected, 0, Length(Expected));
  SortStrings(Sorted);
  WalkPrune(AWorkTree, '');
end;

function PeelToCommit(ARepo: TNativeRepository; AOid: TGitOid; AKind: TGitObjectKind): TGitOid;
var Data: TBytes;
    TagInfo: TGitTagInfo;
begin
  Result := AOid;
  while AKind = gokTag do
  begin
    Data := ARepo.ReadObject(Result, AKind);
    TagInfo := GitParseTag(Data);
    Result := TagInfo.Target;
    Data := ARepo.ReadObject(Result, AKind);
    if AKind = gokCommit then Exit;
    { allow tag → tag chains }
  end;
  if AKind <> gokCommit then
    raise EGitError.CreateFmt('checkout: oid %s is not a commit', [GitOidToHex(AOid)]);
end;

procedure DoCheckoutTree(const AGitDir, AWorkTree: string; const ATreeOid: TGitOid);
var Repo: TNativeRepository;
    Entries: TGitIndexEntryArray;
    Eff: string;
begin
  if AGitDir = '' then raise EGitError.Create('checkout: gitdir empty');
  if AWorkTree = '' then raise EGitError.Create('checkout: worktree empty');
  if IsGitDirShape(AGitDir) or FileExists(PathJoin2(AGitDir,'commondir')) then Eff:=EffectiveGitDir(AGitDir)
  else raise EGitError.CreateFmt('checkout: not a git dir %s', [AGitDir]);
  if not DirectoryExists(AWorkTree) then MkdirAll(AWorkTree, PermDirDefault);
  Repo := TNativeRepository.Create(Eff);
  try
    Entries := nil;
    CollectEntriesRecursive(Repo, ATreeOid, AWorkTree, '', Entries);
    PruneWorkTree(AWorkTree, Entries);
    GitWriteIndex(AGitDir, Entries, 2);
  finally
    Repo.Free;
  end;
end;

procedure GitCheckoutTree(const AGitDir, AWorkTree: string; const ATreeOid: TGitOid);
begin
  DoCheckoutTree(AGitDir, AWorkTree, ATreeOid);
end;

procedure GitCheckoutHead(const AGitDir, AWorkTree: string);
var Repo: TNativeRepository;
    HeadOid: TGitOid;
    Kind: TGitObjectKind;
    Data: TBytes;
    Info: TGitCommitInfo;
    TreeOid: TGitOid;
    Peeled: TGitOid;
begin
  Repo := TNativeRepository.Create(EffectiveGitDir(AGitDir));
  try
    HeadOid := GitResolveHead(AGitDir);
    Data := Repo.ReadObject(HeadOid, Kind);
    if Kind = gokTag then
      Peeled := PeelToCommit(Repo, HeadOid, Kind)
    else
      Peeled := HeadOid;
    Data := Repo.ReadObject(Peeled, Kind);
    if Kind <> gokCommit then
      raise EGitError.CreateFmt('checkout head: %s is not a commit', [GitOidToHex(Peeled)]);
    Info := GitParseCommit(Data);
    TreeOid := Info.Tree;
  finally
    Repo.Free;
  end;
  DoCheckoutTree(AGitDir, AWorkTree, TreeOid);
end;

function GitCheckoutCommit(const AGitDir, AWorkTree: string; const ACommitOid: TGitOid): TGitOid;
var Repo: TNativeRepository;
    Kind: TGitObjectKind;
    Data: TBytes;
    Info: TGitCommitInfo;
    TreeOid: TGitOid;
    Peeled: TGitOid;
begin
  Repo := TNativeRepository.Create(EffectiveGitDir(AGitDir));
  try
    Data := Repo.ReadObject(ACommitOid, Kind);
    Peeled := PeelToCommit(Repo, ACommitOid, Kind);
    Data := Repo.ReadObject(Peeled, Kind);
    Info := GitParseCommit(Data);
    TreeOid := Info.Tree;
    Result := Peeled;
  finally
    Repo.Free;
  end;
  DoCheckoutTree(AGitDir, AWorkTree, TreeOid);
end;

function GitCheckoutRef(const AGitDir, AWorkTree, ARefName: string): TGitOid;
var Oid: TGitOid;
    Kind: TGitObjectKind;
    Repo: TNativeRepository;
begin
  Oid := GitResolveRef(AGitDir, ARefName);
  Repo := TNativeRepository.Create(EffectiveGitDir(AGitDir));
  try
    try
      Repo.ReadObject(Oid, Kind);
    except
      Kind := gokCommit;
    end;
  finally
    Repo.Free;
  end;
  Result := GitCheckoutCommit(AGitDir, AWorkTree, Oid);
  { update HEAD symref when checking out a branch }
  if Copy(ARefName, 1, 11) = 'refs/heads/' then
    WriteFileText(PathJoin([AGitDir, 'HEAD']), 'ref: ' + ARefName + #10)
  else if ARefName = 'HEAD' then
  else
    WriteFileText(PathJoin([AGitDir, 'HEAD']), GitOidToHex(Result) + #10);
end;

end.
