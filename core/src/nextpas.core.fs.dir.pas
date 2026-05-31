unit nextpas.core.fs.dir;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.fs.base,
  nextpas.core.fs.intf;

type
  TWalkFunc = function(const APath: string; const AInfo: TFileInfo;
    const AErr: Exception): Boolean;

function FsReadDir(const APath: string): TDirEntryArray;
function FsOpenDir(const APath: string): IDirIterator;
function FsMkdir(const APath: string;
  const APerm: TFilePermission = PermDirDefault): Boolean;
function FsMkdirAll(const APath: string;
  const APerm: TFilePermission = PermDirDefault): Boolean;
function FsRemove(const APath: string): Boolean;
function FsRemoveAll(const APath: string): Boolean;
function FsRename(const AOld, ANew: string): Boolean;
procedure FsWalk(const ARoot: string; const AFunc: TWalkFunc);

implementation

uses
  nextpas.core.fs.errors,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.fs.util;

type
  TDirIterator = class(TInterfacedObject, IDirIterator)
  private
    FHandle: TPlatformDirHandle;
    FCurrent: TDirEntry;
    FName: string;
    FOpen: Boolean;
    FHasEntry: Boolean;
  public
    constructor Create(const APath: string);
    destructor Destroy; override;
    function Next: Boolean;
    function Entry: TDirEntry;
    procedure Close;
  end;

{ TDirIterator }

constructor TDirIterator.Create(const APath: string);
var
  LResult: Int32;
begin
  inherited Create;
  FName := APath;
  LResult := platform_dir_open(PAnsiChar(APath), FHandle);
  if LResult <> 0 then
    RaiseFsError(LResult, 'opendir', APath);
  FOpen := True;
  FHasEntry := False;
end;

destructor TDirIterator.Destroy;
begin
  if FOpen then
    platform_dir_close(FHandle);
  inherited;
end;

function TDirIterator.Next: Boolean;
var
  LPlatEntry: TPlatformDirEntry;
  LResult: Int32;
begin
  if not FOpen then
    Exit(False);
  LResult := platform_dir_read(FHandle, LPlatEntry);
  if LResult <> 0 then
  begin
    FHasEntry := False;
    Result := False;
    { Contract: 0 = entry, 1 = end-of-directory, anything else = errno. }
    if LResult <> 1 then
      RaiseFsError(LResult, 'readdir', FName);
    Exit;
  end;
  FCurrent.Name := StrPas(@LPlatEntry.Name[0]);
  case LPlatEntry.FileType of
    nextpas.core.platform.files.base.ftDirectory:
    begin
      FCurrent.FileType := nextpas.core.fs.base.ftDirectory;
      FCurrent.IsDir := True;
    end;
    nextpas.core.platform.files.base.ftRegular:
    begin
      FCurrent.FileType := nextpas.core.fs.base.ftRegular;
      FCurrent.IsDir := False;
    end;
    nextpas.core.platform.files.base.ftSymlink:
    begin
      FCurrent.FileType := nextpas.core.fs.base.ftSymlink;
      FCurrent.IsDir := False;
    end;
  else
    FCurrent.FileType := nextpas.core.fs.base.ftUnknown;
    FCurrent.IsDir := False;
  end;
  FHasEntry := True;
  Result := True;
end;

function TDirIterator.Entry: TDirEntry;
begin
  Result := FCurrent;
end;

procedure TDirIterator.Close;
begin
  if FOpen then
  begin
    platform_dir_close(FHandle);
    FOpen := False;
  end;
end;

{ Public functions }

function FsOpenDir(const APath: string): IDirIterator;
begin
  Result := TDirIterator.Create(APath);
end;

function FsReadDir(const APath: string): TDirEntryArray;
var
  LIter: IDirIterator;
  LCount: Integer;
begin
  LIter := FsOpenDir(APath);
  LCount := 0;
  Result := nil;
  while LIter.Next do
  begin
    if LCount >= Length(Result) then
    begin
      if Length(Result) = 0 then
        SetLength(Result, 16)
      else
        SetLength(Result, Length(Result) * 2);
    end;
    Result[LCount] := LIter.Entry;
    Inc(LCount);
  end;
  SetLength(Result, LCount);
  LIter.Close;
end;

function FsMkdir(const APath: string; const APerm: TFilePermission): Boolean;
begin
  Result := platform_file_mkdir(PAnsiChar(APath), UInt32(APerm)) = 0;
end;

function FsMkdirAll(const APath: string; const APerm: TFilePermission): Boolean;
begin
  Result := platform_fs_mkdir_p(PAnsiChar(APath), UInt32(APerm)) = 0;
end;

function FsRemove(const APath: string): Boolean;
begin
  if platform_fs_is_dir(PAnsiChar(APath)) then
    Result := platform_file_rmdir(PAnsiChar(APath)) = 0
  else
    Result := platform_file_unlink(PAnsiChar(APath)) = 0;
end;

{ True only for a real directory; a symlink to a directory returns False so
  callers unlink the link instead of recursing into its target. }
function IsRealDir(const APath: string): Boolean;
var
  LStat: TPlatformFileStat;
begin
  if platform_file_lstat(PAnsiChar(APath), LStat) <> 0 then
    Exit(False);
  Result := LStat.FileType = nextpas.core.platform.files.base.ftDirectory;
end;

function FsRemoveAll(const APath: string): Boolean;
var
  LIter: IDirIterator;
  LEntry: TDirEntry;
  LChild: string;
  LOk: Boolean;
begin
  if (APath = '') or (APath = '/') or (APath = '\') then
    Exit(False);
  if not IsRealDir(APath) then
    Exit(platform_file_unlink(PAnsiChar(APath)) = 0);

  LOk := True;
  LIter := FsOpenDir(APath);
  while LIter.Next do
  begin
    LEntry := LIter.Entry;
    if (LEntry.Name = '.') or (LEntry.Name = '..') then
      Continue;
    LChild := APath + '/' + LEntry.Name;
    if IsRealDir(LChild) then
    begin
      if not FsRemoveAll(LChild) then LOk := False;
    end
    else
    begin
      if platform_file_unlink(PAnsiChar(LChild)) <> 0 then LOk := False;
    end;
  end;
  LIter.Close;
  if platform_file_rmdir(PAnsiChar(APath)) <> 0 then LOk := False;
  Result := LOk;
end;

function FsRename(const AOld, ANew: string): Boolean;
begin
  Result := platform_file_rename(PAnsiChar(AOld), PAnsiChar(ANew)) = 0;
end;

procedure FsWalk(const ARoot: string; const AFunc: TWalkFunc);
var
  LInfo: TFileInfo;
  LIter: IDirIterator;
  LEntry: TDirEntry;
  LChild: string;
begin
  try
    LInfo := FsStat(ARoot);
  except
    on E: Exception do
    begin
      LInfo := Default(TFileInfo);
      LInfo.Name := ARoot;
      if not AFunc(ARoot, LInfo, E) then
        Exit;
      Exit;
    end;
  end;

  if not AFunc(ARoot, LInfo, nil) then
    Exit;

  if not LInfo.IsDir then
    Exit;

  LIter := FsOpenDir(ARoot);
  while LIter.Next do
  begin
    LEntry := LIter.Entry;
    if (LEntry.Name = '.') or (LEntry.Name = '..') then
      Continue;
    LChild := ARoot + '/' + LEntry.Name;
    FsWalk(LChild, AFunc);
  end;
  LIter.Close;
end;

end.