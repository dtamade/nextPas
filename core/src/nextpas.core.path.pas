unit nextpas.core.path;

{$I nextpas.core.settings.inc}

interface

{** High-level path manipulation — string-based wrappers over platform.path.
 *  All functions work with UTF-8 strings and handle both / and \ separators.
 *  Equivalent to SysUtils.ExtractFilePath/ExtractFileName/ChangeFileExt etc.
 *
 *  Implementation delegates to nextpas.core.fs.path which owns the
 *  platform_path_* calls. This unit exists for SysUtils compatibility
 *  and for callers that want a path-only facade without pulling in fs. *}

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
function ExtractFilePath(const AFileName: string): string;
function ExtractFileName(const AFileName: string): string; inline;
function ExtractFileExt(const AFileName: string): string; inline;
function ChangeFileExt(const AFileName, AExt: string): string; inline;

implementation

uses
  nextpas.core.platform.path,
  nextpas.core.fs.path;

function PathJoin(const ABase, AChild: string): string;
begin
  Result := FsPathJoin([ABase, AChild]);
end;

function PathJoin3(const A, B, C: string): string;
begin
  Result := FsPathJoin([A, B, C]);
end;

function PathDir(const APath: string): string;
begin
  if APath = '' then
    Exit('');
  Result := FsPathDir(APath);
  if Result = '.' then
    Result := '';
end;

function PathBase(const APath: string): string;
begin
  Result := FsPathBase(APath);
end;

procedure PathSplit(const APath: string; out ADir, ABase: string);
begin
  if APath = '' then
  begin
    ADir := '';
    ABase := '';
    Exit;
  end;
  FsPathSplit(APath, ADir, ABase);
  if ADir = '.' then
    ADir := '';
end;

function PathExt(const APath: string): string;
begin
  Result := FsPathExt(APath);
end;

function PathChangeExt(const APath, ANewExt: string): string;
begin
  Result := FsPathChangeExt(APath, ANewExt);
end;

function PathIsAbsolute(const APath: string): Boolean;
begin
  Result := FsPathIsAbs(APath);
end;

function PathNormalize(const APath: string): string;
begin
  if APath = '' then
    Exit('');
  Result := FsPathClean(APath);
end;

function PathRelative(const ABase, ATarget: string): string;
begin
  if ATarget = '' then
    Exit('.');
  Result := FsPathRelative(ABase, ATarget);
end;

function PathHasExt(const APath: string): Boolean;
begin
  Result := FsPathExt(APath) <> '';
end;

function PathWithoutExt(const APath: string): string;
begin
  Result := FsPathWithoutExt(APath);
end;

{ SysUtils-compatible aliases }

function ExtractFilePath(const AFileName: string): string;
var
  LDir: string;
begin
  LDir := FsPathDir(AFileName);
  if LDir = '.' then
    Exit('');
  if (LDir <> '') and (LDir[Length(LDir)] <> '/') and (LDir[Length(LDir)] <> '\') then
    Result := LDir + PLATFORM_PATH_SEP
  else
    Result := LDir;
end;

function ExtractFileName(const AFileName: string): string;
begin
  Result := FsPathBase(AFileName);
end;

function ExtractFileExt(const AFileName: string): string;
begin
  Result := FsPathExt(AFileName);
end;

function ChangeFileExt(const AFileName, AExt: string): string;
begin
  Result := FsPathChangeExt(AFileName, AExt);
end;

end.
