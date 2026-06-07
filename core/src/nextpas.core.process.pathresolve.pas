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
 *
 * @return 找到的完整路径，或原始 AName（如果未找到）
 *
 * @note 如果 AName 包含 '/'，直接返回不搜索
 * @note 如果 AEnv 为 nil，使用默认 PATH
 *}
function CommandPathHasDirectoryPart(const AName: string): Boolean;
function ResolveExecutablePath(const AName: string;
  const AEnv: TStringArray): string;

implementation

uses
  nextpas.core.text.compare,
  nextpas.core.platform.fs
  {$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.ffi
  {$ENDIF}
  ;

const
{$IFDEF NEXTPAS_WINDOWS}
  PROCESS_PATH_LIST_SEP = ';';
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
{$IFDEF NEXTPAS_UNIX}
  Result := access(PAnsiChar(APath), 1{X_OK}) = 0;
{$ELSE}
  Result := platform_fs_is_file(PAnsiChar(APath));
{$ENDIF}
end;

function IsPathEnvPair(const AValue: string): Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := TextStartsWithI(AValue, 'PATH=');
{$ELSE}
  Result := TextStartsWith(AValue, 'PATH=');
{$ENDIF}
end;

function ExtractPathFromEnv(const AEnv: TStringArray): string;
var
  I: Integer;
begin
  Result := '/usr/local/bin:/usr/bin:/bin';
  if AEnv = nil then Exit;
  for I := 0 to High(AEnv) do
    if IsPathEnvPair(AEnv[I]) then
      Result := Copy(AEnv[I], 6, Length(AEnv[I]) - 5);
end;

function ResolveExecutablePath(const AName: string;
  const AEnv: TStringArray): string;
var
  LPath, LDir, LCandidate: string;
  LStart, LColon: Integer;
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
    LCandidate := LDir + '/' + AName;
    if IsExecutableCandidate(LCandidate) then
      Exit(LCandidate);
    LStart := LColon + 1;
  end;
  Result := AName;
end;

end.
