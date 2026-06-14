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
  nextpas.core.platform.path,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.fs.util,
  nextpas.core.fs.path;

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
var
  LResult: Int32;
begin
  if FOpen then
  begin
    LResult := platform_dir_close(FHandle);
    FOpen := False;
    if LResult <> 0 then
      RaiseFsError(LResult, 'closedir', FName);
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
var
  LResult: Int32;
begin
  LResult := platform_file_mkdir(PAnsiChar(APath), UInt32(APerm));
  if LResult <> 0 then
    RaiseFsError(LResult, 'mkdir', APath);
  Result := True;
end;

function FsMkdirAll(const APath: string; const APerm: TFilePermission): Boolean;
var
  LResult: Int32;
begin
  LResult := platform_fs_mkdir_p(PAnsiChar(APath), UInt32(APerm));
  if LResult <> 0 then
    RaiseFsError(LResult, 'mkdirall', APath);
  Result := True;
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

function IsUnsafeRemoveAllRoot(const APath: string): Boolean;
var
  LClean: string;
begin
  if APath = '' then
    Exit(True);
  LClean := FsPathClean(APath);
  Result := platform_path_is_root(PAnsiChar(LClean));
end;

function JoinChildPath(const ADir, AName: string): string;
begin
  Result := FsPathJoin([ADir, AName]);
end;

function FsRemove(const APath: string): Boolean;
var
  LStat: TPlatformFileStat;
  LResult: Int32;
begin
  LResult := platform_file_lstat(PAnsiChar(APath), LStat);
  if LResult <> 0 then
    RaiseFsError(LResult, 'lstat', APath);

  if LStat.FileType = nextpas.core.platform.files.base.ftDirectory then
    LResult := platform_file_rmdir(PAnsiChar(APath))
  else
    LResult := platform_file_unlink(PAnsiChar(APath));
  if LResult <> 0 then
    RaiseFsError(LResult, 'remove', APath);
  Result := True;
end;

function FsRemoveAll(const APath: string): Boolean;
var
  LIter: IDirIterator;
  LEntry: TDirEntry;
  LChild: string;
  LResult: Int32;
begin
  if IsUnsafeRemoveAllRoot(APath) then
    raise EInvalidOperationError.Create('removeall refused unsafe root: ' + APath);
  if not IsRealDir(APath) then
  begin
    LResult := platform_file_unlink(PAnsiChar(APath));
    if LResult <> 0 then
      RaiseFsError(LResult, 'removeall', APath);
    Exit(True);
  end;

  LIter := FsOpenDir(APath);
  while LIter.Next do
  begin
    LEntry := LIter.Entry;
    if (LEntry.Name = '.') or (LEntry.Name = '..') then
      Continue;
    LChild := JoinChildPath(APath, LEntry.Name);
    if IsRealDir(LChild) then
    begin
      FsRemoveAll(LChild);
    end
    else
    begin
      LResult := platform_file_unlink(PAnsiChar(LChild));
      if LResult <> 0 then
        RaiseFsError(LResult, 'removeall', LChild);
    end;
  end;
  LIter.Close;
  LResult := platform_file_rmdir(PAnsiChar(APath));
  if LResult <> 0 then
    RaiseFsError(LResult, 'removeall', APath);
  Result := True;
end;

function FsRename(const AOld, ANew: string): Boolean;
var
  LResult: Int32;
begin
  LResult := platform_file_rename(PAnsiChar(AOld), PAnsiChar(ANew));
  if LResult <> 0 then
    RaiseFsError(LResult, 'rename', AOld);
  Result := True;
end;

procedure FsWalk(const ARoot: string; const AFunc: TWalkFunc);
const
  MAX_WALK_DEPTH = 256;

  procedure ReportWalkError(const APath: string; const AErr: Exception);
  var
    LInfo: TFileInfo;
  begin
    LInfo := Default(TFileInfo);
    LInfo.Name := APath;
    AFunc(APath, LInfo, AErr);
  end;

  procedure DoWalk(const APath: string; ADepth: Int32);
  var
    LInfo: TFileInfo;
    LIter: IDirIterator;
    LEntry: TDirEntry;
    LChild: string;
  begin
    if ADepth > MAX_WALK_DEPTH then
      Exit;
    try
      LInfo := FsLstat(APath);
    except
      on E: Exception do
      begin
        ReportWalkError(APath, E);
        Exit;
      end;
    end;

    if not AFunc(APath, LInfo, nil) then
      Exit;

    if not LInfo.IsDir then
      Exit;

    try
      LIter := FsOpenDir(APath);
    except
      on E: Exception do
      begin
        ReportWalkError(APath, E);
        Exit;
      end;
    end;

    try
      try
        while LIter.Next do
        begin
          LEntry := LIter.Entry;
          if (LEntry.Name = '.') or (LEntry.Name = '..') then
            Continue;
          LChild := JoinChildPath(APath, LEntry.Name);
          DoWalk(LChild, ADepth + 1);
        end;
      except
        on E: Exception do
          ReportWalkError(APath, E);
      end;
    finally
      try
        LIter.Close;
      except
        on E: Exception do
          ReportWalkError(APath, E);
      end;
    end;
  end;

begin
  DoWalk(ARoot, 0);
end;

end.
