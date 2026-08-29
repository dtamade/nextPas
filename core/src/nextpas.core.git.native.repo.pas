unit nextpas.core.git.native.repo;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.git.native.base,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.pack,
  nextpas.core.git.native.refs;

{ Repository-level object access: loose store first, then all discovered
  packfiles under objects/pack. Read-only slice; no index/worktree yet. }

type
  TNativeRepository = class
  private
    FGitDir: string;
    FPacks: array of TPackFile;
    function GetPackCount: Integer;
    function GetPack(AIndex: Integer): TPackFile;
    procedure LoadPacks;
  public
    constructor Create(const AGitDirOrWorkDir: string);
    destructor Destroy; override;
    function HasObject(const AOid: TGitOid): Boolean;
    function ReadObject(const AOid: TGitOid;
      out AKind: TGitObjectKind): TBytes;
    property GitDir: string read FGitDir;
    property PackCount: Integer read GetPackCount;
    property Packs[AIndex: Integer]: TPackFile read GetPack;
  end;

implementation

procedure TNativeRepository.LoadPacks;
var
  IdxPaths: TStringArray;
  I, Count: Integer;
  IdxPath, PackPath: string;
begin
  SetLength(FPacks, 0);
  if not DirectoryExists(PathJoin2(FGitDir, 'objects')) then
    Exit;
  IdxPaths := Glob(PathJoin2(FGitDir, PathJoin(['objects', 'pack'])),
    '*.idx');
  for I := 0 to Length(IdxPaths) - 1 do
  begin
    IdxPath := IdxPaths[I];
    if Length(IdxPath) < 5 then
      Continue;
    PackPath := Copy(IdxPath, 1, Length(IdxPath) - 4) + '.pack';
    if not FileExists(PackPath) then
      Continue;
    Count := Length(FPacks);
    SetLength(FPacks, Count + 1);
    FPacks[Count] := TPackFile.Create(IdxPath, PackPath);
  end;
end;

constructor TNativeRepository.Create(const AGitDirOrWorkDir: string);
begin
  inherited Create;
  if IsGitDirShape(AGitDirOrWorkDir) then
    FGitDir := AGitDirOrWorkDir
  else if not GitTryDiscoverGitDir(AGitDirOrWorkDir, FGitDir) then
    raise EGitError.CreateFmt(
      'not a git repository (or any parent): %s', [AGitDirOrWorkDir]);
  LoadPacks;
end;

destructor TNativeRepository.Destroy;
var
  I: Integer;
begin
  for I := 0 to Length(FPacks) - 1 do
    FPacks[I].Free;
  FPacks := nil;
  inherited Destroy;
end;

function TNativeRepository.GetPackCount: Integer;
begin
  Result := Length(FPacks);
end;

function TNativeRepository.GetPack(AIndex: Integer): TPackFile;
begin
  if (AIndex < 0) or (AIndex >= Length(FPacks)) then
    raise EGitError.Create('pack index out of range');
  Result := FPacks[AIndex];
end;

function TNativeRepository.HasObject(const AOid: TGitOid): Boolean;
var
  I: Integer;
begin
  if GitLooseExists(FGitDir, AOid) then
    Exit(True);
  for I := 0 to Length(FPacks) - 1 do
    if FPacks[I].Contains(AOid) then
      Exit(True);
  Result := False;
end;

function TNativeRepository.ReadObject(const AOid: TGitOid;
  out AKind: TGitObjectKind): TBytes;
var
  I: Integer;
begin
  if GitLooseExists(FGitDir, AOid) then
    Exit(GitLooseRead(FGitDir, AOid, AKind));
  for I := 0 to Length(FPacks) - 1 do
    if FPacks[I].Contains(AOid) then
      Exit(FPacks[I].ReadObject(AOid, AKind));
  raise EGitError.CreateFmt('object %s not found in repository %s',
    [GitOidToHex(AOid), FGitDir]);
end;

end.
