unit nextpas.core.path;

{$I nextpas.core.settings.inc}

interface

{** High-level path manipulation — string-based wrappers over platform.path.
 *  All functions work with UTF-8 strings and handle both / and \ separators.
 *  Equivalent to SysUtils.ExtractFilePath/ExtractFileName/ChangeFileExt etc. *}

function PathJoin(const ABase, AChild: string): string;
function PathJoin3(const A, B, C: string): string;
function PathDir(const APath: string): string;
function PathBase(const APath: string): string;
function PathExt(const APath: string): string;
function PathChangeExt(const APath, ANewExt: string): string;
function PathIsAbsolute(const APath: string): Boolean;
function PathNormalize(const APath: string): string;
function PathHasExt(const APath: string): Boolean;
function PathWithoutExt(const APath: string): string;

{ SysUtils-compatible aliases }
function ExtractFilePath(const AFileName: string): string; inline;
function ExtractFileName(const AFileName: string): string; inline;
function ExtractFileExt(const AFileName: string): string; inline;
function ChangeFileExt(const AFileName, AExt: string): string; inline;

implementation

uses
  nextpas.core.platform.path;

const
  BUF_SIZE = 4096;

function PathJoin(const ABase, AChild: string): string;
var
  LBuf: array[0..BUF_SIZE - 1] of AnsiChar;
  LLen: Int32;
begin
  if (Length(ABase) = 0) and (Length(AChild) = 0) then begin Result := ''; Exit; end;
  if Length(ABase) = 0 then begin Result := AChild; Exit; end;
  if Length(AChild) = 0 then begin Result := ABase; Exit; end;
  LLen := platform_path_join(@ABase[1], @AChild[1], @LBuf[0], BUF_SIZE);
  if LLen > 0 then
    SetString(Result, @LBuf[0], LLen)
  else
    Result := ABase + '/' + AChild;
end;

function PathJoin3(const A, B, C: string): string;
var
  LBuf: array[0..BUF_SIZE - 1] of AnsiChar;
  LLen: Int32;
begin
  if (Length(A) = 0) and (Length(B) = 0) and (Length(C) = 0) then begin Result := ''; Exit; end;
  LLen := platform_path_join3(@A[1], @B[1], @C[1], @LBuf[0], BUF_SIZE);
  if LLen > 0 then
    SetString(Result, @LBuf[0], LLen)
  else
    Result := PathJoin(PathJoin(A, B), C);
end;

function PathDir(const APath: string): string;
var
  LBuf: array[0..BUF_SIZE - 1] of AnsiChar;
  LLen: Int32;
begin
  if Length(APath) = 0 then begin Result := ''; Exit; end;
  LLen := platform_path_dirname(@APath[1], @LBuf[0], BUF_SIZE);
  if LLen > 0 then
    SetString(Result, @LBuf[0], LLen)
  else
    Result := '';
end;

function PathBase(const APath: string): string;
var
  LBuf: array[0..BUF_SIZE - 1] of AnsiChar;
  LLen: Int32;
begin
  if Length(APath) = 0 then begin Result := ''; Exit; end;
  LLen := platform_path_basename(@APath[1], @LBuf[0], BUF_SIZE);
  if LLen > 0 then
    SetString(Result, @LBuf[0], LLen)
  else
    Result := APath;
end;

function PathExt(const APath: string): string;
var
  LBuf: array[0..BUF_SIZE - 1] of AnsiChar;
  LLen: Int32;
begin
  if Length(APath) = 0 then begin Result := ''; Exit; end;
  LLen := platform_path_extension(@APath[1], @LBuf[0], BUF_SIZE);
  if LLen > 0 then
    SetString(Result, @LBuf[0], LLen)
  else
    Result := '';
end;

function PathChangeExt(const APath, ANewExt: string): string;
var
  LBuf: array[0..BUF_SIZE - 1] of AnsiChar;
  LLen: Int32;
begin
  if Length(APath) = 0 then begin Result := ''; Exit; end;
  LLen := platform_path_change_ext(@APath[1], @ANewExt[1], @LBuf[0], BUF_SIZE);
  if LLen > 0 then
    SetString(Result, @LBuf[0], LLen)
  else
    Result := APath;
end;

function PathIsAbsolute(const APath: string): Boolean;
begin
  if Length(APath) = 0 then begin Result := False; Exit; end;
  Result := platform_path_is_absolute(@APath[1]);
end;

function PathNormalize(const APath: string): string;
var
  LBuf: array[0..BUF_SIZE - 1] of AnsiChar;
  LLen: Int32;
begin
  if Length(APath) = 0 then begin Result := ''; Exit; end;
  LLen := platform_path_normalize(@APath[1], @LBuf[0], BUF_SIZE);
  if LLen > 0 then
    SetString(Result, @LBuf[0], LLen)
  else
    Result := APath;
end;

function PathHasExt(const APath: string): Boolean;
begin
  Result := PathExt(APath) <> '';
end;

function PathWithoutExt(const APath: string): string;
begin
  Result := PathChangeExt(APath, '');
end;

{ SysUtils-compatible aliases }

function ExtractFilePath(const AFileName: string): string;
var
  LDir: string;
begin
  LDir := PathDir(AFileName);
  if (Length(LDir) > 0) and (LDir[Length(LDir)] <> '/') and (LDir[Length(LDir)] <> '\') then
    Result := LDir + PLATFORM_PATH_SEP
  else
    Result := LDir;
end;

function ExtractFileName(const AFileName: string): string;
begin
  Result := PathBase(AFileName);
end;

function ExtractFileExt(const AFileName: string): string;
begin
  Result := PathExt(AFileName);
end;

function ChangeFileExt(const AFileName, AExt: string): string;
begin
  Result := PathChangeExt(AFileName, AExt);
end;

end.
