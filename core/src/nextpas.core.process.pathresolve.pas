unit nextpas.core.process.pathresolve;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base;

{**
 * ResolveExecutablePath
 *
 * @desc 在 PATH 中搜索可执行文件（类似 Go 的 exec.LookPath）
 *
 * @params
 *   AName  可执行文件名（如 'fpc'）或绝对/相对路径
 *   AEnv   环境变量数组（KEY=VALUE 格式），用于提取 PATH
 *   ASearchBase 相对 PATH 项的存在性检查基准目录，通常是子进程工作目录
 *
 * @return 找到的完整路径，或原始 AName（如果未找到）
 *
 * @note 如果 AName 已包含目录部分，直接返回不搜索
 * @note 调用方只在 custom env 模式下调用；AEnv 未提供 PATH 时不做隐式 fallback
 *}
function CommandPathHasDirectoryPart(const AName: string): Boolean;
function ResolveExecutablePath(const AName: string;
  const AEnv: TStringArray; const ASearchBase: string = ''): string;

implementation

uses
  nextpas.core.platform.fs;

uses
  nextpas.core.text.compare,
  nextpas.core.platform.env,
  nextpas.core.platform.fs,
  nextpas.core.platform.path;

const
  PATH_ENV_PREFIX = 'PATH=';
  PATHEXT_ENV_PREFIX = 'PATHEXT=';
{$IFDEF NEXTPAS_WINDOWS}
  PATHEXT_ENV_PREFIX = 'PATHEXT=';
  PROCESS_PATH_LIST_SEP = ';';
  PROCESS_PATH_EXT_SEP = ';';
{$ELSE}
  PROCESS_PATH_LIST_SEP = ':';
{$ENDIF}

function CommandPathHasDirectoryPart(const AName: string): Boolean;
begin
  Result := Pos('/', AName) > 0;
{$IFDEF NEXTPAS_WINDOWS}
  Result := Result or (Pos('\', AName) > 0) or
    ((Length(AName) >= 2) and (AName[2] = ':'));
{$ENDIF}
end;

function IsExecutableCandidate(const APath: string): Boolean;
begin
  if APath = '' then
    Exit(False);
  Result := platform_fs_is_executable(PAnsiChar(APath));
end;

function IsPathEnvPair(const AValue: string): Boolean;
begin
  if platform_env_names_case_sensitive then
    Result := TextStartsWith(AValue, PATH_ENV_PREFIX)
  else
    Result := TextStartsWithI(AValue, PATH_ENV_PREFIX);
end;

function IsPathExtEnvPair(const AValue: string): Boolean;
begin
  if platform_env_names_case_sensitive then
    Result := TextStartsWith(AValue, PATHEXT_ENV_PREFIX)
  else
    Result := TextStartsWithI(AValue, PATHEXT_ENV_PREFIX);
end;

function HasFileExtension(const AName: string): Boolean;
var
  I: Integer;
begin
  for I := Length(AName) downto 1 do
  begin
    if (AName[I] = '.') and (I < Length(AName)) then
      Exit(True);
    if (AName[I] = '/') or (AName[I] = '\') then
      Break;
  end;
  Result := False;
end;

function JoinProcessPath(const ABase, AChild: string): string;
begin
  if ABase = '' then
    Exit(AChild);
  if AChild = '' then
    Exit(ABase);
  if (ABase[Length(ABase)] = PLATFORM_PATH_SEP) or
    (ABase[Length(ABase)] = PLATFORM_PATH_ALT_SEP) then
    Result := ABase + AChild
  else
    Result := ABase + PLATFORM_PATH_SEP + AChild;
end;

function ExtractPathFromEnv(const AEnv: TStringArray): string;
var
  I: Integer;
begin
  Result := '';
  if AEnv = nil then Exit;
  for I := 0 to High(AEnv) do
    if IsPathEnvPair(AEnv[I]) then
      Result := Copy(AEnv[I], Length(PATH_ENV_PREFIX) + 1,
        Length(AEnv[I]) - Length(PATH_ENV_PREFIX));
end;

function ExtractPathExtFromEnv(const AEnv: TStringArray): string;
var
  I: Integer;
begin
  Result := '';
  if AEnv = nil then Exit;
  for I := 0 to High(AEnv) do
    if IsPathExtEnvPair(AEnv[I]) then
      Result := Copy(AEnv[I], Length(PATHEXT_ENV_PREFIX) + 1,
        Length(AEnv[I]) - Length(PATHEXT_ENV_PREFIX));
end;

function SearchCheckPath(const ASearchBase, AExecCandidate: string): string;
begin
  if (ASearchBase = '') or
    platform_path_is_absolute(PAnsiChar(AExecCandidate)) then
    Exit(AExecCandidate);
  Result := JoinProcessPath(ASearchBase, AExecCandidate);
end;

function TryExecutableCandidate(const ASearchBase, AExecCandidate: string;
  out AResolvedCandidate: string): Boolean;
var
  LCheckPath: string;
begin
  LCheckPath := SearchCheckPath(ASearchBase, AExecCandidate);
  Result := IsExecutableCandidate(LCheckPath);
  if Result then
    AResolvedCandidate := AExecCandidate
  else
    AResolvedCandidate := '';
end;

function AppendWindowsPathExtCandidate(const AName, AExt: string): string;
begin
  Result := AName + AExt;
end;

function ResolveExecutablePath(const AName: string;
  const AEnv: TStringArray; const ASearchBase: string): string;
var
  LPath, LDir, LCandidate, LResolved: string;
  LStart, LColon: Integer;
{$IFDEF NEXTPAS_WINDOWS}
  LPathExt, LExt: string;
  LExtStart, LExtEnd: Integer;
{$ENDIF}
begin
  if CommandPathHasDirectoryPart(AName) then
    Exit(AName);

  LPath := ExtractPathFromEnv(AEnv);
  LStart := 1;
  while LStart <= Length(LPath) do
  begin
    LColon := LStart;
    while (LColon <= Length(LPath)) and
      (LPath[LColon] <> PROCESS_PATH_LIST_SEP) do
      Inc(LColon);
    LDir := Copy(LPath, LStart, LColon - LStart);
    if LDir = '' then LDir := '.';
    LCandidate := JoinProcessPath(LDir, AName);
    if TryExecutableCandidate(ASearchBase, LCandidate, LResolved) then
      Exit(LResolved);
{$IFDEF NEXTPAS_WINDOWS}
    if not HasFileExtension(AName) then
    begin
      LPathExt := ExtractPathExtFromEnv(AEnv);
      LExtStart := 1;
      while LExtStart <= Length(LPathExt) do
      begin
        LExtEnd := LExtStart;
        while (LExtEnd <= Length(LPathExt)) and
          (LPathExt[LExtEnd] <> PROCESS_PATH_EXT_SEP) do
          Inc(LExtEnd);
        LExt := Copy(LPathExt, LExtStart, LExtEnd - LExtStart);
        if LExt <> '' then
        begin
          if LExt[1] <> '.' then
            LExt := '.' + LExt;
          LCandidate := JoinProcessPath(LDir,
            AppendWindowsPathExtCandidate(AName, LExt));
          if TryExecutableCandidate(ASearchBase, LCandidate, LResolved) then
            Exit(LResolved);
        end;
        LExtStart := LExtEnd + 1;
      end;
    end;
{$ENDIF}
    LStart := LColon + 1;
  end;
  Result := AName;
end;

end.
