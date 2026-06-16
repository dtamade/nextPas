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

{** @desc 连接两个路径片段 *}
function PathJoin(const ABase, AChild: string): string;
{** @desc 连接三个路径片段 *}
function PathJoin3(const A, B, C: string): string;
{** @desc 返回路径的目录部分（空路径返回空字符串） *}
function PathDir(const APath: string): string;
{** @desc 返回路径的文件名部分（含扩展名） *}
function PathBase(const APath: string): string;
{** @desc 分离路径为目录和文件名两部分 *}
procedure PathSplit(const APath: string; out ADir, ABase: string);
{** @desc 返回文件扩展名（含点号） *}
function PathExt(const APath: string): string;
{** @desc 替换文件扩展名 *}
function PathChangeExt(const APath, ANewExt: string): string;
{** @desc 判断路径是否为绝对路径 *}
function PathIsAbsolute(const APath: string): Boolean;
{** @desc 规范化路径（解析 . 和 ..，去除多余分隔符） *}
function PathNormalize(const APath: string): string;
{** @desc 计算从 ABase 到 ATarget 的相对路径 *}
function PathRelative(const ABase, ATarget: string): string;
{** @desc 检查路径是否包含文件扩展名 *}
function PathHasExt(const APath: string): Boolean;
{** @desc 返回去除扩展名后的路径 *}
function PathWithoutExt(const APath: string): string;

{ SysUtils-compatible aliases }
{** @desc 提取文件路径的目录部分（SysUtils 兼容，末尾带分隔符） *}
function ExtractFilePath(const AFileName: string): string;
{** @desc 提取文件名部分（SysUtils 兼容） *}
function ExtractFileName(const AFileName: string): string; inline;
{** @desc 提取文件扩展名（SysUtils 兼容） *}
function ExtractFileExt(const AFileName: string): string; inline;
{** @desc 替换文件扩展名（SysUtils 兼容） *}
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
