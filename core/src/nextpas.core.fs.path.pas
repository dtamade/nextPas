unit nextpas.core.fs.path;

{$I nextpas.core.settings.inc}

interface

function FsPathJoin(const AParts: array of string): string;
function FsPathDir(const APath: string): string;
function FsPathBase(const APath: string): string;
function FsPathExt(const APath: string): string;
function FsPathClean(const APath: string): string;
function FsPathAbs(const APath: string): string;
function FsPathIsAbs(const APath: string): Boolean;

implementation

uses
  nextpas.core.platform.path;

const
  PATH_BUF_SIZE = 1024;

function FsPathJoin(const AParts: array of string): string;
var
  LI, LNeed: Integer;
  LStack: array[0..PATH_BUF_SIZE - 1] of AnsiChar;
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
      @LStack[0], PATH_BUF_SIZE);
    if LNeed < 0 then
      Continue;
    if LNeed < PATH_BUF_SIZE then
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
  LStack: array[0..PATH_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  LNeed := platform_path_dirname(PAnsiChar(APath), @LStack[0], PATH_BUF_SIZE);
  if LNeed <= 0 then
    Exit('.');
  if LNeed < PATH_BUF_SIZE then
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
  LStack: array[0..PATH_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  LNeed := platform_path_basename(PAnsiChar(APath), @LStack[0], PATH_BUF_SIZE);
  if LNeed <= 0 then
    Exit(APath);
  if LNeed < PATH_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_basename(PAnsiChar(APath), @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathExt(const APath: string): string;
var
  LStack: array[0..PATH_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
begin
  LNeed := platform_path_extension(PAnsiChar(APath), @LStack[0], PATH_BUF_SIZE);
  if LNeed <= 0 then
    Exit('');
  SetString(Result, PAnsiChar(@LStack[0]), LNeed);
end;

function FsPathClean(const APath: string): string;
var
  LStack: array[0..PATH_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  if APath = '' then
    Exit('.');
  LNeed := platform_path_normalize(PAnsiChar(APath), @LStack[0], PATH_BUF_SIZE);
  if LNeed <= 0 then
    Exit(APath);
  if LNeed < PATH_BUF_SIZE then
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
  LStack: array[0..PATH_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  LNeed := platform_path_resolve(PAnsiChar(APath), @LStack[0], PATH_BUF_SIZE);
  if LNeed <= 0 then
    Exit(APath);
  if LNeed < PATH_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_resolve(PAnsiChar(APath), @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathIsAbs(const APath: string): Boolean;
begin
  Result := platform_path_is_absolute(PAnsiChar(APath));
end;

end.
