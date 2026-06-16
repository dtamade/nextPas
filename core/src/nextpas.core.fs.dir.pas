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
  nextpas.core.fs.path,
  nextpas.core.text.conv;

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

{ FsWalk bridge types — unit-level so WalkCallback can be a plain function }

type
  PFsWalkBridge = ^TFsWalkBridge;
  TFsWalkBridge = record
    Callback: TWalkFunc;
  end;

function MapPlatformFileType(AFT: nextpas.core.platform.files.base.TPlatformFileType
  ): nextpas.core.fs.base.TFileType;
begin
  case AFT of
    nextpas.core.platform.files.base.ftRegular:
      Result := nextpas.core.fs.base.ftRegular;
    nextpas.core.platform.files.base.ftDirectory:
      Result := nextpas.core.fs.base.ftDirectory;
    nextpas.core.platform.files.base.ftSymlink:
      Result := nextpas.core.fs.base.ftSymlink;
    nextpas.core.platform.files.base.ftCharDevice:
      Result := nextpas.core.fs.base.ftCharDevice;
    nextpas.core.platform.files.base.ftBlockDevice:
      Result := nextpas.core.fs.base.ftBlockDevice;
    nextpas.core.platform.files.base.ftFifo:
      Result := nextpas.core.fs.base.ftFifo;
    nextpas.core.platform.files.base.ftSocket:
      Result := nextpas.core.fs.base.ftSocket;
  else
    Result := nextpas.core.fs.base.ftUnknown;
  end;
end;

function BuildWalkInfo(const AEntry: TPlatformWalkEntry): TFileInfo;
var
  LPath: string;
begin
  if AEntry.PathLen > 0 then
    SetString(LPath, AEntry.Path, AEntry.PathLen)
  else
    LPath := '';
  Result := Default(TFileInfo);
  Result.Name := LPath;
  Result.FileType := MapPlatformFileType(AEntry.FileType);
  Result.IsDir := AEntry.FileType = nextpas.core.platform.files.base.ftDirectory;
  Result.IsSymlink := AEntry.FileType = nextpas.core.platform.files.base.ftSymlink;
end;

function FsWalkPlatformCallback(const AEntry: TPlatformWalkEntry;
  AUserData: Pointer): TPlatformWalkAction;
var
  LBridge: PFsWalkBridge;
  LPath: string;
  LInfo: TFileInfo;
  LErr: Exception;
  LKeepGoing: Boolean;
begin
  LBridge := PFsWalkBridge(AUserData);
  SetString(LPath, AEntry.Path, AEntry.PathLen);

  if AEntry.ErrorCode <> 0 then
  begin
    LInfo := Default(TFileInfo);
    LInfo.Name := LPath;
    LErr := EIOError.Create('walk error (' +
      IntToStr(AEntry.ErrorCode) + '): ' + LPath);
    try
      LKeepGoing := LBridge^.Callback(LPath, LInfo, LErr);
    finally
      LErr.Free;
    end;
    if not LKeepGoing then
      Exit(pwaStop);
    if AEntry.FileType = nextpas.core.platform.files.base.ftDirectory then
      Exit(pwaSkipSubtree);
    Exit(pwaContinue);
  end;

  LInfo := BuildWalkInfo(AEntry);
  if not LBridge^.Callback(LPath, LInfo, nil) then
    Exit(pwaStop);
  Result := pwaContinue;
end;

procedure FsWalk(const ARoot: string; const AFunc: TWalkFunc);
var
  LBridge: TFsWalkBridge;
  LResult: Int32;
begin
  LBridge.Callback := AFunc;
  LResult := platform_fs_walk(PAnsiChar(ARoot), @FsWalkPlatformCallback,
    @LBridge, False{no follow symlinks});
  if (LResult <> PLATFORM_WALK_COMPLETED) and
     (LResult <> PLATFORM_WALK_STOPPED) then
    RaiseFsError(LResult, 'walk', ARoot);
end;

end.
