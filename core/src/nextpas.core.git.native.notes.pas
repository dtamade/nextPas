unit nextpas.core.git.native.notes;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Notes subfamily: refs/notes/* is a commit whose tree maps target
  object hex → note blob. Reader handles both flat (name = 40 hex)
  and fanout (xx/yy… with slashes) transparently; writer always
  emits a flat, sorted tree (git reads both, flat is simpler and
  byte-exact under GitWriteTree). }

type
  TGitNoteEntry = record
    Target: TGitOid;
    NoteOid: TGitOid;
    Content: TBytes;
  end;
  TGitNoteArray = array of TGitNoteEntry;

const
  GitNotesDefaultRef = 'refs/notes/commits';

function GitNotesRefExists(const AGitDir, ARefName: string): Boolean; overload;
function GitNotesRefExists(const AGitDir: string): Boolean; overload;
function GitNotesList(const AGitDir, ARefName: string): TGitNoteArray; overload;
function GitNotesList(const AGitDir: string): TGitNoteArray; overload;
function GitNotesGet(const AGitDir: string; const ATarget: TGitOid): TBytes; overload;
function GitNotesGet(const AGitDir, ARefName: string; const ATarget: TGitOid): TBytes; overload;
function GitNotesGetStr(const AGitDir: string; const ATarget: TGitOid): string; overload;
function GitNotesGetStr(const AGitDir, ARefName: string; const ATarget: TGitOid): string; overload;
function GitNotesExists(const AGitDir: string; const ATarget: TGitOid): Boolean; overload;
function GitNotesExists(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean; overload;
function GitNotesAdd(const AGitDir: string; const ATarget: TGitOid; const ANote: string): TGitOid; overload;
function GitNotesAdd(const AGitDir, ARefName: string; const ATarget: TGitOid; const ANote: string): TGitOid; overload;
function GitNotesAddBytes(const AGitDir, ARefName: string; const ATarget: TGitOid; const AData: TBytes): TGitOid;
function GitNotesRemove(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean; overload;
function GitNotesRemove(const AGitDir: string; const ATarget: TGitOid): Boolean; overload;

implementation

uses
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.write,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.config;

function NotesRefPath(const AGitDir, ARef: string): string;
var Clean: string;
begin
  Clean := ARef;
  if (Length(Clean)>0) and (Clean[1]='/') then Delete(Clean,1,1);
  Result := PathJoin([AGitDir, Clean]);
end;

function GitNotesRefExists(const AGitDir, ARefName: string): Boolean;
begin
  try
    GitResolveRef(AGitDir, ARefName);
    Result := True;
  except
    Result := False;
  end;
end;

function GitNotesRefExists(const AGitDir: string): Boolean;
begin
  Result := GitNotesRefExists(AGitDir, GitNotesDefaultRef);
end;

procedure CollectNotesRecursive(ARepo: TNativeRepository; const ATreeOid: TGitOid;
  const APrefix: string; var AOut: TGitNoteArray);
var
  Data: TBytes;
  Kind: TGitObjectKind;
  Entries: TGitTreeEntryArray;
  I, J: Integer;
  Full, Clean: string;
  BlobData: TBytes;
  BlobKind: TGitObjectKind;
begin
  Data := ARepo.ReadObject(ATreeOid, Kind);
  if Kind <> gokTree then Exit;
  Entries := GitParseTree(Data);
  for I := 0 to High(Entries) do
  begin
    if Entries[I].Mode = $4000 then
      CollectNotesRecursive(ARepo, Entries[I].Oid, APrefix + Entries[I].Name + '/', AOut)
    else
    begin
      Full := APrefix + Entries[I].Name;
      Clean := '';
      for J := 1 to Length(Full) do if Full[J] <> '/' then Clean := Clean + Full[J];
      if (Length(Clean)=40) and GitOidIsValidHex(Clean) then
      begin
        SetLength(AOut, Length(AOut)+1);
        AOut[High(AOut)].Target := GitOidFromHex(Clean);
        AOut[High(AOut)].NoteOid := Entries[I].Oid;
        try
          BlobData := ARepo.ReadObject(Entries[I].Oid, BlobKind);
          if BlobKind = gokBlob then AOut[High(AOut)].Content := BlobData
          else AOut[High(AOut)].Content := nil;
        except
          AOut[High(AOut)].Content := nil;
        end;
      end;
    end;
  end;
end;

function NotesTreeOidForRef(const AGitDir, ARef: string; out ATreeOid: TGitOid; out ACommitOid: TGitOid): Boolean;
var
  Repo: TNativeRepository;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
begin
  Result := False;
  try
    ACommitOid := GitResolveRef(AGitDir, ARef);
  except
    Exit(False);
  end;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Data := Repo.ReadObject(ACommitOid, Kind);
    while Kind = gokTag do
    begin
      Data := Repo.ReadObject(GitParseTag(Data).Target, Kind);
    end;
    if Kind <> gokCommit then Exit(False);
    Info := GitParseCommit(Data);
    ATreeOid := Info.Tree;
    Result := True;
  finally
    Repo.Free;
  end;
end;

function GitNotesList(const AGitDir, ARefName: string): TGitNoteArray;
var
  TreeOid, CommitOid: TGitOid;
  Repo: TNativeRepository;
  Has: Boolean;
begin
  Result := nil;
  Has := NotesTreeOidForRef(AGitDir, ARefName, TreeOid, CommitOid);
  if not Has then Exit;
  Repo := TNativeRepository.Create(AGitDir);
  try
    CollectNotesRecursive(Repo, TreeOid, '', Result);
  finally
    Repo.Free;
  end;
end;

function GitNotesList(const AGitDir: string): TGitNoteArray;
begin
  Result := GitNotesList(AGitDir, GitNotesDefaultRef);
end;

function GitNotesGet(const AGitDir, ARefName: string; const ATarget: TGitOid): TBytes;
var
  List: TGitNoteArray;
  Hex: string;
  I: Integer;
begin
  Hex := LowerCase(GitOidToHex(ATarget));
  List := GitNotesList(AGitDir, ARefName);
  for I := 0 to High(List) do
    if LowerCase(GitOidToHex(List[I].Target)) = Hex then
      Exit(List[I].Content);
  raise EGitError.CreateFmt('note not found for %s', [Hex]);
end;

function GitNotesGet(const AGitDir: string; const ATarget: TGitOid): TBytes;
begin
  Result := GitNotesGet(AGitDir, GitNotesDefaultRef, ATarget);
end;

function GitNotesGetStr(const AGitDir, ARefName: string; const ATarget: TGitOid): string;
var
  B: TBytes;
begin
  B := GitNotesGet(AGitDir, ARefName, ATarget);
  Result := GitBytesToString(B);
end;

function GitNotesGetStr(const AGitDir: string; const ATarget: TGitOid): string;
begin
  Result := GitNotesGetStr(AGitDir, GitNotesDefaultRef, ATarget);
end;

function GitNotesExists(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean;
var
  List: TGitNoteArray;
  Hex: string;
  I: Integer;
begin
  Hex := LowerCase(GitOidToHex(ATarget));
  List := GitNotesList(AGitDir, ARefName);
  for I := 0 to High(List) do
    if LowerCase(GitOidToHex(List[I].Target)) = Hex then Exit(True);
  Result := False;
end;

function GitNotesExists(const AGitDir: string; const ATarget: TGitOid): Boolean;
begin
  Result := GitNotesExists(AGitDir, GitNotesDefaultRef, ATarget);
end;

function LoadNotesMap(const AGitDir, ARef: string; out AMap: TGitNoteArray; out AOldCommit: TGitOid; out AHasOld: Boolean): Boolean;
var
  TreeOid: TGitOid;
begin
  AHasOld := NotesTreeOidForRef(AGitDir, ARef, TreeOid, AOldCommit);
  if AHasOld then AMap := GitNotesList(AGitDir, ARef)
  else begin AMap := nil; AOldCommit := Default(TGitOid); end;
  Result := True;
end;

function BuildNotesTree(const AGitDir: string; const AMap: TGitNoteArray): TGitOid;
var
  Entries: TGitTreeEntryArray;
  I: Integer;
begin
  SetLength(Entries, Length(AMap));
  for I := 0 to High(AMap) do
  begin
    Entries[I].Mode := $81A4;
    Entries[I].Name := LowerCase(GitOidToHex(AMap[I].Target));
    Entries[I].Oid := AMap[I].NoteOid;
  end;
  Result := GitWriteTree(AGitDir, Entries);
end;

function NotesSignature(const AGitDir: string): TGitSignature;
var
  Cfg: TGitConfig;
  N,E: string;
  HeadOid: TGitOid;
  Repo: TNativeRepository;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
begin
  Cfg := GitReadConfig(AGitDir);
  try N := GitConfigGet(Cfg, 'user.name'); except N := ''; end;
  try E := GitConfigGet(Cfg, 'user.email'); except E := ''; end;
  if (N<>'') and (E<>'') then
  begin
    Result.Name := N; Result.Email := E; Result.UnixTime := 1700000000; Result.TzMinutes := 0; Exit;
  end;
  // fallback to HEAD committer
  try
    HeadOid := GitResolveHead(AGitDir);
    Repo := TNativeRepository.Create(AGitDir);
    try
      Data := Repo.ReadObject(HeadOid, Kind);
      while Kind=gokTag do Data := Repo.ReadObject(GitParseTag(Data).Target, Kind);
      if Kind=gokCommit then
      begin
        Info := GitParseCommit(Data);
        Result := Info.Committer; Exit;
      end;
    finally Repo.Free; end;
  except end;
  Result.Name := 'Test Er'; Result.Email := 'test@example.com'; Result.UnixTime := 1700000000; Result.TzMinutes := 0;
end;

function GitNotesAddBytes(const AGitDir, ARefName: string; const ATarget: TGitOid; const AData: TBytes): TGitOid;
var
  Map: TGitNoteArray;
  OldCommit: TGitOid;
  HasOld: Boolean;
  BlobOid: TGitOid;
  Hex: string;
  I, Pos: Integer;
  Found: Boolean;
  NewTree: TGitOid;
  Builder: TGitCommitBuilder;
  Sig: TGitSignature;
begin
  if AGitDir='' then raise EGitError.Create('notes add: gitdir empty');
  Hex := LowerCase(GitOidToHex(ATarget));
  if not GitOidIsValidHex(Hex) then raise EGitError.Create('notes add: invalid target oid');
  LoadNotesMap(AGitDir, ARefName, Map, OldCommit, HasOld);
  BlobOid := GitWriteBlob(AGitDir, AData);
  Found := False;
  Pos := -1;
  for I := 0 to High(Map) do
    if LowerCase(GitOidToHex(Map[I].Target))=Hex then
    begin Found:=True; Pos:=I; Break; end;
  if Found then
    Map[Pos].NoteOid := BlobOid
  else
  begin
    SetLength(Map, Length(Map)+1);
    Map[High(Map)].Target := ATarget;
    Map[High(Map)].NoteOid := BlobOid;
  end;
  // also need to ensure map entries have Content for rebuild? Not needed.
  NewTree := BuildNotesTree(AGitDir, Map);
  Sig := NotesSignature(AGitDir);
  Builder := Default(TGitCommitBuilder);
  Builder.Tree := NewTree;
  if HasOld then
  begin
    SetLength(Builder.Parents,1);
    Builder.Parents[0] := OldCommit;
  end else SetLength(Builder.Parents,0);
  Builder.AuthorName := Sig.Name; Builder.AuthorEmail := Sig.Email;
  Builder.AuthorUnixTime := Sig.UnixTime; Builder.AuthorTzMinutes := Sig.TzMinutes;
  Builder.CommitterName := Sig.Name; Builder.CommitterEmail := Sig.Email;
  Builder.CommitterUnixTime := Sig.UnixTime; Builder.CommitterTzMinutes := Sig.TzMinutes;
  Builder.Message := 'Notes added by ''git notes add'''#10;
  Result := GitWriteCommit(AGitDir, Builder);
  // update ref
  MkdirAll(PathDir(NotesRefPath(AGitDir, ARefName)), PermDirDefault);
  WriteFileText(NotesRefPath(AGitDir, ARefName), GitOidToHex(Result)+#10);
end;

function GitNotesAdd(const AGitDir, ARefName: string; const ATarget: TGitOid; const ANote: string): TGitOid;
begin
  Result := GitNotesAddBytes(AGitDir, ARefName, ATarget, GitStringToBytes(ANote));
end;

function GitNotesAdd(const AGitDir: string; const ATarget: TGitOid; const ANote: string): TGitOid;
begin
  Result := GitNotesAdd(AGitDir, GitNotesDefaultRef, ATarget, ANote);
end;

function GitNotesRemove(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean;
var
  Map: TGitNoteArray;
  OldCommit: TGitOid;
  HasOld: Boolean;
  Hex: string;
  I: Integer;
  NewTree: TGitOid;
  Builder: TGitCommitBuilder;
  Sig: TGitSignature;
  NewCommit: TGitOid;
  NewMap: TGitNoteArray;
begin
  Result := False;
  Hex := LowerCase(GitOidToHex(ATarget));
  LoadNotesMap(AGitDir, ARefName, Map, OldCommit, HasOld);
  if not HasOld then Exit(False);
  SetLength(NewMap, 0);
  for I := 0 to High(Map) do
    if LowerCase(GitOidToHex(Map[I].Target))<>Hex then
    begin
      SetLength(NewMap, Length(NewMap)+1);
      NewMap[High(NewMap)] := Map[I];
    end else Result := True;
  if not Result then Exit(False);
  if Length(NewMap)=0 then
  begin
    // no notes left: remove ref? git notes remove would delete ref when empty? Keep empty tree commit? We remove ref for simplicity
    Remove(NotesRefPath(AGitDir, ARefName));
    Exit(True);
  end;
  NewTree := BuildNotesTree(AGitDir, NewMap);
  Sig := NotesSignature(AGitDir);
  Builder := Default(TGitCommitBuilder);
  Builder.Tree := NewTree;
  SetLength(Builder.Parents,1);
  Builder.Parents[0] := OldCommit;
  Builder.AuthorName := Sig.Name; Builder.AuthorEmail := Sig.Email;
  Builder.AuthorUnixTime := Sig.UnixTime; Builder.AuthorTzMinutes := Sig.TzMinutes;
  Builder.CommitterName := Sig.Name; Builder.CommitterEmail := Sig.Email;
  Builder.CommitterUnixTime := Sig.UnixTime; Builder.CommitterTzMinutes := Sig.TzMinutes;
  Builder.Message := 'Notes removed by ''git notes remove'''#10;
  NewCommit := GitWriteCommit(AGitDir, Builder);
  WriteFileText(NotesRefPath(AGitDir, ARefName), GitOidToHex(NewCommit)+#10);
end;

function GitNotesRemove(const AGitDir: string; const ATarget: TGitOid): Boolean;
begin
  Result := GitNotesRemove(AGitDir, GitNotesDefaultRef, ATarget);
end;

end.
