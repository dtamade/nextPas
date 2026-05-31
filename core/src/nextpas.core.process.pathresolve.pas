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
function ResolveExecutablePath(const AName: string;
  const AEnv: TStringArray): string;

implementation

uses
  nextpas.core.fs,
  nextpas.core.text.compare;

function ExtractPathFromEnv(const AEnv: TStringArray): string;
var
  I: Integer;
begin
  Result := '/usr/local/bin:/usr/bin:/bin';
  if AEnv = nil then Exit;
  for I := 0 to High(AEnv) do
    if TextStartsWith(AEnv[I], 'PATH=') then
    begin
      Result := Copy(AEnv[I], 6, Length(AEnv[I]) - 5);
      Exit;
    end;
end;

function ResolveExecutablePath(const AName: string;
  const AEnv: TStringArray): string;
var
  LPath, LDir, LCandidate: string;
  LStart, LColon: Integer;
begin
  if Pos('/', AName) > 0 then
    Exit(AName);

  LPath := ExtractPathFromEnv(AEnv);
  LStart := 1;
  while LStart <= Length(LPath) do
  begin
    LColon := LStart;
    while (LColon <= Length(LPath)) and (LPath[LColon] <> ':') do
      Inc(LColon);
    LDir := Copy(LPath, LStart, LColon - LStart);
    if LDir = '' then LDir := '.';
    LCandidate := LDir + '/' + AName;
    if Exists(LCandidate) then
      Exit(LCandidate);
    LStart := LColon + 1;
  end;
  Result := AName;
end;

end.
