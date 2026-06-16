unit nextpas.core.fs.path;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.path,
  nextpas.core.fs.util;

const
  PathDelim = PLATFORM_PATH_SEP;
  PathSep = PathDelim;

function FsPathJoin(const AParts: array of string): string;
function FsPathDir(const APath: string): string;
function FsPathBase(const APath: string): string;
procedure FsPathSplit(const APath: string; out ADir, ABase: string);
function FsPathExt(const APath: string): string;
function FsPathClean(const APath: string): string;
function FsPathAbs(const APath: string): string;
function FsPathIsAbs(const APath: string): Boolean;
function FsPathRelative(const ABase, ATarget: string): string;
function FsPathEnsureSep(const APath: string): string;
function FsPathTrimSep(const APath: string): string;
function FsPathChangeExt(const APath, ANewExt: string): string;
function FsPathWithoutExt(const APath: string): string;
function FsSameFileName(const A, B: string): Boolean;

implementation

const
  FS_PATH_STACK_BUF_SIZE = 1024;

function FsPathJoin(const AParts: array of string): string;
var
  LI, LNeed: Integer;
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LHeap: array of AnsiChar;
  LBase: string;
begin
  if Length(AParts) = 0 then
    Exit('');
  Result := AParts[0];
  for LI := 1 to High(AParts) do
  begin
    LBase := Result;
    LNeed := platform_path_join(PAnsiChar(LBase), PAnsiChar(AParts[LI]),
      @LStack[0], FS_PATH_STACK_BUF_SIZE);
    if LNeed < 0 then
      Continue;
    if LNeed < FS_PATH_STACK_BUF_SIZE then
      SetString(Result, PAnsiChar(@LStack[0]), LNeed)
    else
    begin
      SetLength(LHeap, LNeed + 1);
      platform_path_join(PAnsiChar(LBase), PAnsiChar(AParts[LI]),
        @LHeap[0], Length(LHeap));
      SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
    end;
  end;
end;

function FsPathDir(const APath: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  LNeed := platform_path_dirname(PAnsiChar(APath), @LStack[0],
    FS_PATH_STACK_BUF_SIZE);
  if LNeed <= 0 then
    Exit('.');
  if LNeed < FS_PATH_STACK_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_dirname(PAnsiChar(APath), @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathBase(const APath: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  LNeed := platform_path_basename(PAnsiChar(APath), @LStack[0],
    FS_PATH_STACK_BUF_SIZE);
  if LNeed <= 0 then
    Exit(APath);
  if LNeed < FS_PATH_STACK_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_basename(PAnsiChar(APath), @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

procedure FsPathSplit(const APath: string; out ADir, ABase: string);
begin
  ADir := FsPathDir(APath);
  ABase := FsPathBase(APath);
end;

function FsPathExt(const APath: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  LNeed := platform_path_extension(PAnsiChar(APath), @LStack[0],
    FS_PATH_STACK_BUF_SIZE);
  if LNeed <= 0 then
    Exit('');
  if LNeed < FS_PATH_STACK_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_extension(PAnsiChar(APath), @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathClean(const APath: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  if APath = '' then
    Exit('.');
  LNeed := platform_path_normalize(PAnsiChar(APath), @LStack[0],
    FS_PATH_STACK_BUF_SIZE);
  if LNeed <= 0 then
    Exit(APath);
  if LNeed < FS_PATH_STACK_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_normalize(PAnsiChar(APath), @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathAbs(const APath: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
  LCwd: string;
begin
  if APath = '' then Exit('');
  LNeed := platform_path_resolve(PAnsiChar(APath), @LStack[0],
    FS_PATH_STACK_BUF_SIZE);
  if LNeed > 0 then
  begin
    if LNeed < FS_PATH_STACK_BUF_SIZE then
    begin
      SetString(Result, PAnsiChar(@LStack[0]), LNeed);
      Exit;
    end;
    SetLength(LHeap, LNeed + 1);
    platform_path_resolve(PAnsiChar(APath), @LHeap[0], Length(LHeap));
    SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
    Exit;
  end;
  if FsPathIsAbs(APath) then
    Result := FsPathClean(APath)
  else
  begin
    LCwd := FsGetCwd;
    Result := FsPathClean(LCwd + PLATFORM_PATH_SEP + APath);
  end;
end;

function FsPathIsAbs(const APath: string): Boolean;
begin
  Result := platform_path_is_absolute(PAnsiChar(APath));
end;

function FsPathRelative(const ABase, ATarget: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  LNeed := platform_path_relative(PAnsiChar(ABase), PAnsiChar(ATarget),
    @LStack[0], FS_PATH_STACK_BUF_SIZE);
  if LNeed < 0 then
    Exit(FsPathClean(ATarget));
  if LNeed < FS_PATH_STACK_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_relative(PAnsiChar(ABase), PAnsiChar(ATarget),
    @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathEnsureSep(const APath: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  LNeed := platform_path_ensure_sep(PAnsiChar(APath), @LStack[0],
    FS_PATH_STACK_BUF_SIZE);
  if LNeed < 0 then
    Exit(APath);
  if LNeed < FS_PATH_STACK_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_ensure_sep(PAnsiChar(APath), @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathTrimSep(const APath: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  LNeed := platform_path_trim_sep(PAnsiChar(APath), @LStack[0],
    FS_PATH_STACK_BUF_SIZE);
  if LNeed < 0 then
    Exit(APath);
  if LNeed < FS_PATH_STACK_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_trim_sep(PAnsiChar(APath), @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathChangeExt(const APath, ANewExt: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  if APath = '' then
    Exit('');
  LNeed := platform_path_change_ext(PAnsiChar(APath), PAnsiChar(ANewExt),
    @LStack[0], FS_PATH_STACK_BUF_SIZE);
  if LNeed < 0 then
    Exit(APath);
  if LNeed < FS_PATH_STACK_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_change_ext(PAnsiChar(APath), PAnsiChar(ANewExt),
    @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathWithoutExt(const APath: string): string;
begin
  Result := FsPathChangeExt(APath, '');
end;

function FsSameFileName(const A, B: string): Boolean;
begin
  Result := platform_path_same_file_name(PAnsiChar(A), PAnsiChar(B));
end;

end.
