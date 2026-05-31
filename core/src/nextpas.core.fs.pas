unit nextpas.core.fs;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.io.intf,
  nextpas.core.text.base,
  nextpas.core.fs.base,
  nextpas.core.fs.intf,
  nextpas.core.fs.stream,
  nextpas.core.fs.dir,
  nextpas.core.fs.path,
  nextpas.core.fs.util;

type
  TFileMode = nextpas.core.fs.base.TFileMode;
  TFilePermission = nextpas.core.fs.base.TFilePermission;
  TFileType = nextpas.core.fs.base.TFileType;
  TFileInfo = nextpas.core.fs.base.TFileInfo;
  TDirEntry = nextpas.core.fs.base.TDirEntry;
  TDirEntryArray = nextpas.core.fs.base.TDirEntryArray;
  IFile = nextpas.core.fs.intf.IFile;
  IDirIterator = nextpas.core.fs.intf.IDirIterator;
  TWalkFunc = nextpas.core.fs.dir.TWalkFunc;

{ File operations }
function Open(const APath: string; const AMode: TFileMode): IFile; inline;
function Create(const APath: string;
  const APerm: TFilePermission = PermDefault): IFile; inline;

{ Convenience }
function ReadFile(const APath: string): TBytes; inline;
function ReadFileText(const APath: string): string; inline;
function ReadFileLines(const APath: string): TStringArray; inline;
procedure WriteFile(const APath: string; const AData: TBytes;
  const APerm: TFilePermission = PermDefault); inline;
procedure WriteAtomic(const APath: string; const AData: TBytes;
  const APerm: TFilePermission = PermDefault); inline;
function CopyFile(const ASrc, ADst: string): Int64; inline;
function TempFile(const ADir, APattern: string): IFile; inline;
function Stat(const APath: string): TFileInfo; inline;
function Lstat(const APath: string): TFileInfo; inline;
function Exists(const APath: string): Boolean; inline;
function IsDir(const APath: string): Boolean; inline;
function IsFile(const APath: string): Boolean; inline;
function FileSize(const APath: string): Int64; inline;
procedure Chmod(const APath: string; const APerm: TFilePermission); inline;
procedure Truncate(const APath: string; const ASize: Int64); inline;
procedure Symlink(const ATarget, ALinkPath: string); inline;
function Readlink(const APath: string): string; inline;

{ Directory operations }
function Mkdir(const APath: string;
  const APerm: TFilePermission = PermDirDefault): Boolean; inline;
function MkdirAll(const APath: string;
  const APerm: TFilePermission = PermDirDefault): Boolean; inline;
function Remove(const APath: string): Boolean; inline;
function RemoveAll(const APath: string): Boolean; inline;
function Rename(const AOld, ANew: string): Boolean; inline;
function ReadDir(const APath: string): TDirEntryArray;
function OpenDir(const APath: string): IDirIterator; inline;
procedure Walk(const ARoot: string; const AFunc: TWalkFunc); inline;

{ Path operations }
function PathJoin(const AParts: array of string): string;
function PathDir(const APath: string): string; inline;
function PathBase(const APath: string): string; inline;
function PathExt(const APath: string): string; inline;
function PathClean(const APath: string): string; inline;
function PathAbs(const APath: string): string; inline;
function PathIsAbs(const APath: string): Boolean; inline;
function PathEnsureSep(const APath: string): string; inline;
function PathTrimSep(const APath: string): string; inline;
function PathChangeExt(const APath, ANewExt: string): string; inline;
function PathWithoutExt(const APath: string): string; inline;
function GetCwd: string; inline;
procedure SetCwd(const APath: string); inline;
function GetEnv(const AName: string): string; inline;
function GetTempDir: string;

implementation

function Open(const APath: string; const AMode: TFileMode): IFile;
begin
  Result := FsOpen(APath, AMode);
end;

function Create(const APath: string; const APerm: TFilePermission): IFile;
begin
  Result := FsCreate(APath, APerm);
end;

function ReadFile(const APath: string): TBytes;
begin
  Result := nextpas.core.fs.util.FsReadFile(APath);
end;

function ReadFileText(const APath: string): string;
begin
  Result := nextpas.core.fs.util.FsReadFileText(APath);
end;

function ReadFileLines(const APath: string): TStringArray;
begin
  Result := nextpas.core.fs.util.FsReadFileLines(APath);
end;

procedure WriteFile(const APath: string; const AData: TBytes;
  const APerm: TFilePermission);
begin
  nextpas.core.fs.util.FsWriteFile(APath, AData, APerm);
end;

procedure WriteAtomic(const APath: string; const AData: TBytes;
  const APerm: TFilePermission);
begin
  nextpas.core.fs.util.FsWriteAtomic(APath, AData, APerm);
end;

function CopyFile(const ASrc, ADst: string): Int64;
begin
  Result := nextpas.core.fs.util.FsCopyFile(ASrc, ADst);
end;

function TempFile(const ADir, APattern: string): IFile;
begin
  Result := nextpas.core.fs.util.FsTempFile(ADir, APattern);
end;

function Stat(const APath: string): TFileInfo;
begin
  Result := nextpas.core.fs.util.FsStat(APath);
end;

function Lstat(const APath: string): TFileInfo;
begin
  Result := nextpas.core.fs.util.FsLstat(APath);
end;

function Exists(const APath: string): Boolean;
begin
  Result := nextpas.core.fs.util.FsExists(APath);
end;

function IsDir(const APath: string): Boolean;
begin
  Result := nextpas.core.fs.util.FsIsDir(APath);
end;

function IsFile(const APath: string): Boolean;
begin
  Result := nextpas.core.fs.util.FsIsFile(APath);
end;

function FileSize(const APath: string): Int64;
begin
  Result := nextpas.core.fs.util.FsFileSize(APath);
end;

procedure Chmod(const APath: string; const APerm: TFilePermission);
begin
  nextpas.core.fs.util.FsChmod(APath, APerm);
end;

procedure Truncate(const APath: string; const ASize: Int64);
begin
  nextpas.core.fs.util.FsTruncate(APath, ASize);
end;

procedure Symlink(const ATarget, ALinkPath: string);
begin
  nextpas.core.fs.util.FsSymlink(ATarget, ALinkPath);
end;

function Readlink(const APath: string): string;
begin
  Result := nextpas.core.fs.util.FsReadlink(APath);
end;

function Mkdir(const APath: string; const APerm: TFilePermission): Boolean;
begin
  Result := nextpas.core.fs.dir.FsMkdir(APath, APerm);
end;

function MkdirAll(const APath: string; const APerm: TFilePermission): Boolean;
begin
  Result := nextpas.core.fs.dir.FsMkdirAll(APath, APerm);
end;

function Remove(const APath: string): Boolean;
begin
  Result := nextpas.core.fs.dir.FsRemove(APath);
end;

function RemoveAll(const APath: string): Boolean;
begin
  Result := nextpas.core.fs.dir.FsRemoveAll(APath);
end;

function Rename(const AOld, ANew: string): Boolean;
begin
  Result := nextpas.core.fs.dir.FsRename(AOld, ANew);
end;

function ReadDir(const APath: string): TDirEntryArray;
begin
  Result := nextpas.core.fs.dir.FsReadDir(APath);
end;

function OpenDir(const APath: string): IDirIterator;
begin
  Result := nextpas.core.fs.dir.FsOpenDir(APath);
end;

procedure Walk(const ARoot: string; const AFunc: TWalkFunc);
begin
  nextpas.core.fs.dir.FsWalk(ARoot, AFunc);
end;

function PathJoin(const AParts: array of string): string;
begin
  Result := nextpas.core.fs.path.FsPathJoin(AParts);
end;

function PathDir(const APath: string): string;
begin
  Result := nextpas.core.fs.path.FsPathDir(APath);
end;

function PathBase(const APath: string): string;
begin
  Result := nextpas.core.fs.path.FsPathBase(APath);
end;

function PathExt(const APath: string): string;
begin
  Result := nextpas.core.fs.path.FsPathExt(APath);
end;

function PathClean(const APath: string): string;
begin
  Result := nextpas.core.fs.path.FsPathClean(APath);
end;

function PathAbs(const APath: string): string;
begin
  Result := nextpas.core.fs.path.FsPathAbs(APath);
end;

function PathIsAbs(const APath: string): Boolean;
begin
  Result := nextpas.core.fs.path.FsPathIsAbs(APath);
end;

function PathEnsureSep(const APath: string): string;
begin
  Result := nextpas.core.fs.path.FsPathEnsureSep(APath);
end;

function PathTrimSep(const APath: string): string;
begin
  Result := nextpas.core.fs.path.FsPathTrimSep(APath);
end;

function PathChangeExt(const APath, ANewExt: string): string;
begin
  Result := nextpas.core.fs.path.FsPathChangeExt(APath, ANewExt);
end;

function PathWithoutExt(const APath: string): string;
begin
  Result := nextpas.core.fs.path.FsPathWithoutExt(APath);
end;

function GetCwd: string;
begin
  Result := nextpas.core.fs.util.FsGetCwd;
end;

procedure SetCwd(const APath: string);
begin
  nextpas.core.fs.util.FsSetCwd(APath);
end;

function GetEnv(const AName: string): string;
begin
  Result := nextpas.core.fs.util.FsGetEnv(AName);
end;

function GetTempDir: string;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  Result := GetEnv('TEMP');
  if Result = '' then Result := GetEnv('TMP');
  if Result = '' then Result := 'C:\Temp';
  {$ELSE}
  Result := GetEnv('TMPDIR');
  if Result = '' then Result := '/tmp';
  {$ENDIF}
  Result := PathEnsureSep(Result);
end;

end.
