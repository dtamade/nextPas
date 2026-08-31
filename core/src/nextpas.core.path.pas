unit nextpas.core.path;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

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
{** @desc PathIsAbsolute 别名（与 fs.PathIsAbs 对称） *}
function PathIsAbs(const APath: string): Boolean; inline;
{** @desc 判断路径是否为相对路径 *}
function PathIsRelative(const APath: string): Boolean; inline;
{** @desc 规范化路径（解析 . 和 ..，去除多余分隔符） *}
function PathNormalize(const APath: string): string;
{** @desc 计算从 ABase 到 ATarget 的相对路径 *}
function PathRelative(const ABase, ATarget: string): string;
{** @desc 检查路径是否包含文件扩展名 *}
function PathHasExt(const APath: string): Boolean;
{** @desc 返回去除扩展名后的路径 *}
function PathWithoutExt(const APath: string): string;
{** @desc glob 模式匹配（* 匹配任意非分隔符序列，? 匹配单字符，[a-z] 字符类） *}
function PathMatch(const APattern, AName: string): Boolean;
{** @desc 连接多个路径片段 *}
function PathJoinN(const AParts: array of string): string;
{** @desc 规范化路径（PathNormalize 的 Go 风格别名） *}
function PathClean(const APath: string): string; inline;
{** @desc 将路径中的 '\' 转为 '/'（对齐 Go filepath.ToSlash） *}
function PathToSlash(const APath: string): string;
{** @desc 将路径中的 '/' 转为平台分隔符（对齐 Go filepath.FromSlash） *}
function PathFromSlash(const APath: string): string;
{** @desc 按 PATH 列表分隔符拆分（Unix ':' / Windows ';'；对齐 filepath.SplitList） *}
function PathSplitList(const AList: string): TStringArray;
{** @desc 卷名/盘符（Windows "C:"；Linux 空；对齐 filepath.VolumeName 子集） *}
function PathVolume(const APath: string): string;
{** @desc 文件名去掉最后一段扩展名（对齐 Rust Path::file_stem；无扩展名则整段 base） *}
function PathFileStem(const APath: string): string;
{**
 * @desc 若 APath 以 APrefix 为前缀则去掉前缀，否则返回空串
 * @note 前缀匹配后若下一项是分隔符则一并去掉；APath=APrefix 返回 '.'
 *}
function PathStripPrefix(const APath, APrefix: string): string;

{ SysUtils-compatible aliases }

const
  {** 平台目录分隔符（Linux: '/', Windows: '\'） *}
  {$IFDEF NEXTPAS_WINDOWS}
  DirectorySeparator = '\';
  PathListSeparator = ';';
  LineEnding = #13#10;
  {$ELSE}
  DirectorySeparator = '/';
  PathListSeparator = ':';
  LineEnding = #10;
  {$ENDIF}

{** @desc 提取文件路径的目录部分（SysUtils 兼容，末尾带分隔符） *}
function ExtractFilePath(const AFileName: string): string;
{** @desc 提取文件路径的目录部分（SysUtils 兼容，末尾不带分隔符）。
  注意：与 FPC SysUtils 行为一致 — ExtractFileDir 去除尾部分隔符，ExtractFilePath 保留。
  根目录 '/' 例外：ExtractFileDir('/') 返回 '/'。 *}
function ExtractFileDir(const AFileName: string): string;
{** @desc 提取文件名部分（SysUtils 兼容） *}
function ExtractFileName(const AFileName: string): string; inline;
{** @desc 提取文件扩展名（SysUtils 兼容） *}
function ExtractFileExt(const AFileName: string): string; inline;
{** @desc 提取驱动器号（SysUtils 兼容，Linux 总返回空） *}
function ExtractFileDrive(const AFileName: string): string;
{** @desc 替换文件扩展名（SysUtils 兼容） *}
function ChangeFileExt(const AFileName, AExt: string): string; inline;
{** @desc 确保路径末尾有路径分隔符（SysUtils 兼容） *}
function IncludeTrailingPathDelimiter(const APath: string): string;
{** @desc 去除路径末尾的路径分隔符（SysUtils 兼容） *}
function ExcludeTrailingPathDelimiter(const APath: string): string;
{** @desc 转为绝对路径（SysUtils 兼容；委托 FsPathAbs，依赖 cwd，非纯字符串） *}
function ExpandFileName(const APath: string): string;

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
  { Bare filename only: SysUtils empty dir. Keep '.' for './x' etc. }
  if (Result = '.') and (Pos('/', APath) = 0) and (Pos('\', APath) = 0) then
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
  if (ADir = '.') and (Pos('/', APath) = 0) and (Pos('\', APath) = 0) then
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

function PathIsAbs(const APath: string): Boolean;
begin
  Result := PathIsAbsolute(APath);
end;

function PathIsRelative(const APath: string): Boolean;
begin
  Result := not FsPathIsAbs(APath);
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

function PathMatch(const APattern, AName: string): Boolean;
begin
  Result := FsPathMatch(APattern, AName);
end;

function PathJoinN(const AParts: array of string): string;
begin
  Result := FsPathJoin(AParts);
end;

function PathClean(const APath: string): string;
begin
  Result := PathNormalize(APath);
end;

function PathToSlash(const APath: string): string;
var
  I: Integer;
begin
  Result := APath;
  for I := 1 to Length(Result) do
    if Result[I] = '\' then
      Result[I] := '/';
end;

function PathFromSlash(const APath: string): string;
{$IFDEF NEXTPAS_WINDOWS}
var
  I: Integer;
{$ENDIF}
begin
  Result := APath;
  {$IFDEF NEXTPAS_WINDOWS}
  for I := 1 to Length(Result) do
    if Result[I] = '/' then
      Result[I] := '\';
  {$ELSE}
  { Unix: FromSlash is identity for '/' paths; still normalize nothing extra. }
  {$ENDIF}
end;

function PathSplitList(const AList: string): TStringArray;
var
  I, LStart, LCount, LLen: Integer;
  C: Char;
begin
  Result := nil;
  LLen := Length(AList);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  LCount := 1;
  for I := 1 to LLen do
    if AList[I] = PathListSeparator then
      Inc(LCount);
  SetLength(Result, LCount);
  LStart := 1;
  LCount := 0;
  for I := 1 to LLen do
  begin
    C := AList[I];
    if C = PathListSeparator then
    begin
      Result[LCount] := Copy(AList, LStart, I - LStart);
      Inc(LCount);
      LStart := I + 1;
    end;
  end;
  Result[LCount] := Copy(AList, LStart, LLen - LStart + 1);
end;

function PathVolume(const APath: string): string;
begin
  Result := ExtractFileDrive(APath);
end;

function PathFileStem(const APath: string): string;
var
  LBase, LExt: string;
begin
  LBase := PathBase(APath);
  if LBase = '' then
    Exit('');
  LExt := PathExt(LBase);
  if LExt = '' then
    Exit(LBase);
  Result := Copy(LBase, 1, Length(LBase) - Length(LExt));
end;

function PathStripPrefix(const APath, APrefix: string): string;
var
  LPath, LPref: string;
  LLen: Integer;
begin
  Result := '';
  if APrefix = '' then
    Exit(APath);
  LPath := PathToSlash(APath);
  LPref := PathToSlash(APrefix);
  if LPref[Length(LPref)] = '/' then
    SetLength(LPref, Length(LPref) - 1);
  LLen := Length(LPref);
  if LLen = 0 then
    Exit(APath);
  if LPath = LPref then
    Exit('.');
  if Length(LPath) <= LLen then
    Exit('');
  if Copy(LPath, 1, LLen) <> LPref then
    Exit('');
  if (LPath[LLen + 1] <> '/') and (LPath[LLen + 1] <> '\') then
    Exit('');
  Result := Copy(LPath, LLen + 2, Length(LPath) - LLen - 1);
  if Result = '' then
    Result := '.';
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

function ExtractFileDir(const AFileName: string): string;
begin
  Result := ExtractFilePath(AFileName);
  { FPC ExtractFileDir removes trailing separator, ExtractFilePath keeps it }
  { P3-3 fix: Don't remove separator for root path '/' }
  if (Result <> '') and (Result[Length(Result)] = '/') and (Length(Result) > 1) then
    SetLength(Result, Length(Result) - 1);
end;

function ExtractFileName(const AFileName: string): string;
begin
  Result := FsPathBase(AFileName);
end;

function ExtractFileExt(const AFileName: string): string;
begin
  Result := FsPathExt(AFileName);
end;

function ExtractFileDrive(const AFileName: string): string;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  if (Length(AFileName) >= 2) and (AFileName[2] = ':') then
    Result := Copy(AFileName, 1, 2)
  else
    Result := '';
  {$ELSE}
  Result := '';
  {$ENDIF}
end;

function ChangeFileExt(const AFileName, AExt: string): string;
begin
  Result := FsPathChangeExt(AFileName, AExt);
end;

function IncludeTrailingPathDelimiter(const APath: string): string;
begin
  Result := FsPathEnsureSep(APath);
end;

function ExcludeTrailingPathDelimiter(const APath: string): string;
begin
  Result := FsPathTrimSep(APath);
end;

function ExpandFileName(const APath: string): string;
begin
  Result := FsPathAbs(APath);
end;

end.
