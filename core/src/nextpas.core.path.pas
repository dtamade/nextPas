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
procedure PathSplit(const APath: string; out ADir, ABase: string);
function PathExt(const APath: string): string;
function PathChangeExt(const APath, ANewExt: string): string;
function PathIsAbsolute(const APath: string): Boolean;
function PathNormalize(const APath: string): string;
function PathRelative(const ABase, ATarget: string): string;
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

type
  TPathUnaryFunc = function(const APath: PAnsiChar; ABuf: PAnsiChar;
    ABufLen: Int32): Int32;
  TPathBinaryFunc = function(const ALeft, ARight: PAnsiChar;
    ABuf: PAnsiChar; ABufLen: Int32): Int32;
  TPathTernaryFunc = function(const A, B, C: PAnsiChar;
    ABuf: PAnsiChar; ABufLen: Int32): Int32;

function PathStringFromBuffer(const ABuf: PAnsiChar; ALen: Int32): string;
begin
  if ALen > 0 then
    SetString(Result, ABuf, ALen)
  else
    Result := '';
end;

function CallPathUnary(const APath: string; AFunc: TPathUnaryFunc;
  const AFallback: string): string;
var
  LStack: array[0..BUF_SIZE - 1] of AnsiChar;
  LHeap: array of AnsiChar;
  LLen: Int32;
  LBufLen: Int32;
begin
  LLen := AFunc(PAnsiChar(APath), @LStack[0], BUF_SIZE);
  if LLen < 0 then
    Exit(AFallback);
  if LLen < BUF_SIZE then
    Exit(PathStringFromBuffer(@LStack[0], LLen));

  LBufLen := LLen + 1;
  SetLength(LHeap, LBufLen);
  LLen := AFunc(PAnsiChar(APath), @LHeap[0], LBufLen);
  if LLen >= LBufLen then
  begin
    LBufLen := LLen + 1;
    SetLength(LHeap, LBufLen);
    LLen := AFunc(PAnsiChar(APath), @LHeap[0], LBufLen);
  end;
  if LLen < 0 then
    Exit(AFallback);
  if LLen >= LBufLen then
    Exit(AFallback);
  Result := PathStringFromBuffer(@LHeap[0], LLen);
end;

function CallPathBinary(const ALeft, ARight: string; AFunc: TPathBinaryFunc;
  const AFallback: string): string;
var
  LStack: array[0..BUF_SIZE - 1] of AnsiChar;
  LHeap: array of AnsiChar;
  LLen: Int32;
  LBufLen: Int32;
begin
  LLen := AFunc(PAnsiChar(ALeft), PAnsiChar(ARight), @LStack[0], BUF_SIZE);
  if LLen < 0 then
    Exit(AFallback);
  if LLen < BUF_SIZE then
    Exit(PathStringFromBuffer(@LStack[0], LLen));

  LBufLen := LLen + 1;
  SetLength(LHeap, LBufLen);
  LLen := AFunc(PAnsiChar(ALeft), PAnsiChar(ARight), @LHeap[0], LBufLen);
  if LLen >= LBufLen then
  begin
    LBufLen := LLen + 1;
    SetLength(LHeap, LBufLen);
    LLen := AFunc(PAnsiChar(ALeft), PAnsiChar(ARight), @LHeap[0], LBufLen);
  end;
  if LLen < 0 then
    Exit(AFallback);
  if LLen >= LBufLen then
    Exit(AFallback);
  Result := PathStringFromBuffer(@LHeap[0], LLen);
end;

function CallPathTernary(const A, B, C: string; AFunc: TPathTernaryFunc;
  const AFallback: string): string;
var
  LStack: array[0..BUF_SIZE - 1] of AnsiChar;
  LHeap: array of AnsiChar;
  LLen: Int32;
  LBufLen: Int32;
begin
  LLen := AFunc(PAnsiChar(A), PAnsiChar(B), PAnsiChar(C), @LStack[0], BUF_SIZE);
  if LLen < 0 then
    Exit(AFallback);
  if LLen < BUF_SIZE then
    Exit(PathStringFromBuffer(@LStack[0], LLen));

  LBufLen := LLen + 1;
  SetLength(LHeap, LBufLen);
  LLen := AFunc(PAnsiChar(A), PAnsiChar(B), PAnsiChar(C), @LHeap[0], LBufLen);
  if LLen >= LBufLen then
  begin
    LBufLen := LLen + 1;
    SetLength(LHeap, LBufLen);
    LLen := AFunc(PAnsiChar(A), PAnsiChar(B), PAnsiChar(C), @LHeap[0], LBufLen);
  end;
  if LLen < 0 then
    Exit(AFallback);
  if LLen >= LBufLen then
    Exit(AFallback);
  Result := PathStringFromBuffer(@LHeap[0], LLen);
end;

function PathJoin(const ABase, AChild: string): string;
begin
  if (Length(ABase) = 0) and (Length(AChild) = 0) then begin Result := ''; Exit; end;
  if Length(ABase) = 0 then begin Result := AChild; Exit; end;
  if Length(AChild) = 0 then begin Result := ABase; Exit; end;
  Result := CallPathBinary(ABase, AChild, @platform_path_join, ABase + PLATFORM_PATH_SEP + AChild);
end;

function PathJoin3(const A, B, C: string): string;
begin
  if (Length(A) = 0) and (Length(B) = 0) and (Length(C) = 0) then begin Result := ''; Exit; end;
  Result := CallPathTernary(A, B, C, @platform_path_join3, PathJoin(PathJoin(A, B), C));
end;

function PathDir(const APath: string): string;
begin
  if Length(APath) = 0 then begin Result := ''; Exit; end;
  Result := CallPathUnary(APath, @platform_path_dirname, '');
end;

function PathBase(const APath: string): string;
begin
  if Length(APath) = 0 then begin Result := ''; Exit; end;
  Result := CallPathUnary(APath, @platform_path_basename, APath);
end;

procedure PathSplit(const APath: string; out ADir, ABase: string);
begin
  ADir := PathDir(APath);
  ABase := PathBase(APath);
end;

function PathExt(const APath: string): string;
begin
  if Length(APath) = 0 then begin Result := ''; Exit; end;
  Result := CallPathUnary(APath, @platform_path_extension, '');
end;

function PathChangeExt(const APath, ANewExt: string): string;
begin
  if Length(APath) = 0 then begin Result := ''; Exit; end;
  Result := CallPathBinary(APath, ANewExt, @platform_path_change_ext, APath);
end;

function PathIsAbsolute(const APath: string): Boolean;
begin
  if Length(APath) = 0 then begin Result := False; Exit; end;
  Result := platform_path_is_absolute(@APath[1]);
end;

function PathNormalize(const APath: string): string;
begin
  if Length(APath) = 0 then begin Result := ''; Exit; end;
  Result := CallPathUnary(APath, @platform_path_normalize, APath);
end;

function PathRelative(const ABase, ATarget: string): string;
begin
  if Length(ATarget) = 0 then begin Result := '.'; Exit; end;
  Result := CallPathBinary(ABase, ATarget, @platform_path_relative,
    PathNormalize(ATarget));
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
