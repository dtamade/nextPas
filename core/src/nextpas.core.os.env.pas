unit nextpas.core.os.env;

{**
 * nextpas.core.os.env — Environment variable access
 *
 * @note Thread safety: this module is NOT thread-safe, consistent with the
 *       C standard library (POSIX.1 does not require getenv/setenv to be
 *       thread-safe). Callers that access environment variables from multiple
 *       threads must provide their own synchronization.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base;

{** @desc 返回所有环境变量，格式为 "NAME=VALUE" 字符串数组 *}
function EnvironmentVariables: TStringArray;
{** @desc 返回所有环境变量名（不含值）*}
function EnvKeys: TStringArray;
{** @desc 获取环境变量值，不存在返回空字符串 *}
function GetEnvironmentVariable(const AName: string): string;
{** @desc 获取环境变量值（GetEnvironmentVariable 的简写） *}
function GetEnv(const AName: string): string; inline;
{**
 * @desc 尝试获取环境变量值
 *
 * @params
 *   AName   环境变量名
 *   AValue  输出值
 *
 * @return 存在返回 true，不存在返回 false
 *}
function TryGetEnv(const AName: string; out AValue: string): Boolean;
{** @desc 检查环境变量是否存在 *}
function HasEnv(const AName: string): Boolean;
{** @desc 返回环境变量名是否区分大小写 *}
function EnvironmentVariableNamesCaseSensitive: Boolean; inline;
{** @desc 设置环境变量 *}
procedure SetEnv(const AName, AValue: string);
{** @desc 获取环境变量值，不存在时返回默认值 *}
function GetEnvDefault(const AName, ADefault: string): string;
{** @desc 删除环境变量 *}
procedure UnsetEnv(const AName: string);
{**
 * @desc 清除当前进程全部环境变量（对齐 Go os.Clearenv）
 * @note 非线程安全；对 EnvKeys 快照逐个 unset（跳过含 '=' / NUL 的异常名）
 * @note 比 UnsetEnv 宽松：不强制可移植名，以便真正清空进程环境
 *}
procedure ClearEnv;
{**
 * @desc 展开字符串中的环境变量引用
 *
 * @params
 *   AValue  包含 $VAR 或 $VAR 引用的字符串
 *
 * @note 支持 $NAME 和 $NAME 两种语法
 * @note 未定义的变量展开为空字符串
 *}
function ExpandEnv(const AValue: string): string;
{**
 * @desc 展开字符串中的环境变量引用（未定义的变量用默认值替代）
 *
 * @params
 *   AValue    包含 $VAR 或 $VAR 引用的字符串
 *   ADefault  未定义变量的替代值
 *
 * @note 支持 $NAME 和 $NAME 两种语法
 * @note 未定义的变量展开为 ADefault（而非空字符串）
 *}
function ExpandEnvWithDefault(const AValue, ADefault: string): string;
{**
 * @desc 展开字符串中的环境变量引用（未定义的变量抛出异常）
 *
 * @params
 *   AValue  包含 $VAR 或 $VAR 引用的字符串
 *
 * @note 支持 $NAME 和 $NAME 两种语法
 * @note 未定义的变量会抛出 EArgumentError
 * @note 适用于配置文件等需要严格环境变量的场景
 *}
function ExpandEnvStrict(const AValue: string): string;
{** @desc 获取用户主目录
 *
 * @return 主目录路径（Unix: $HOME, Windows: %USERPROFILE%）
 *
 * @note 环境变量不存在时返回空字符串
 *}
function UserHomeDir: string;
{** @desc 获取用户缓存目录
 *
 * @params
 *   AAppName  可选应用名；非空时拼接到缓存根目录下
 *
 * @return Unix: $XDG_CACHE_HOME 或 $HOME/.cache；Windows: %LOCALAPPDATA%
 *
 * @note 根目录环境变量不存在时返回空字符串
 *}
function UserCacheDir(const AAppName: string = ''): string;
{** @desc 获取用户配置目录
 *
 * @params
 *   AAppName  可选应用名；非空时拼接到配置根目录下
 *
 * @return Unix: $XDG_CONFIG_HOME 或 $HOME/.config；Windows: %APPDATA%
 *
 * @note 根目录环境变量不存在时返回空字符串
 *}
function UserConfigDir(const AAppName: string = ''): string;
{** @desc 获取用户数据目录
 *
 * @params
 *   AAppName  可选应用名；非空时拼接到数据根目录下
 *
 * @return Unix: $XDG_DATA_HOME 或 $HOME/.local/share；Windows: %LOCALAPPDATA%
 *
 * @note 根目录环境变量不存在时返回空字符串
 *}
function UserDataDir(const AAppName: string = ''): string;
{** @desc 获取用户状态目录
 *
 * @params
 *   AAppName  可选应用名；非空时拼接到状态根目录下
 *
 * @return Unix: $XDG_STATE_HOME 或 $HOME/.local/state；Windows: %LOCALAPPDATA%
 *
 * @note 根目录环境变量不存在时返回空字符串
 *}
function UserStateDir(const AAppName: string = ''): string;

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.text.builder,
  nextpas.core.platform.env,
  nextpas.core.platform.error;

type
  TExpandMode = (emLoose, emDefault, emStrict);

type
  PStringArray = ^TStringArray;

procedure ValidateEnvName(const AName: string);
var
  I: Integer;
begin
  if AName = '' then
    raise EArgumentError.Create('environment variable name must not be empty');
  if Pos('=', AName) > 0 then
    raise EArgumentError.Create('environment variable name must not contain "="');
  for I := 1 to Length(AName) do
    if AName[I] = #0 then
      raise EArgumentError.Create('environment variable name must not contain NUL');
end;

{ Portable name for SetEnv/UnsetEnv/Expand placeholders: [A-Za-z_][A-Za-z0-9_]*.
  GetEnv/TryGetEnv/HasEnv only use ValidateEnvName (may read odd existing names). }
procedure ValidatePortableEnvName(const AName: string);
var
  I: Integer;
  C: Char;
begin
  ValidateEnvName(AName);
  C := AName[1];
  if not (((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or (C = '_')) then
    raise EArgumentError.Create(
      'environment variable name must start with letter or underscore: ' + AName);
  for I := 2 to Length(AName) do
  begin
    C := AName[I];
    if not (((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or
      ((C >= '0') and (C <= '9')) or (C = '_')) then
      raise EArgumentError.Create(
        'environment variable name must be [A-Za-z_][A-Za-z0-9_]*: ' + AName);
  end;
end;

procedure ValidateEnvValue(const AValue: string);
var
  I: Integer;
begin
  for I := 1 to Length(AValue) do
    if AValue[I] = #0 then
      raise EArgumentError.Create('environment variable value must not contain NUL');
end;

procedure RaiseEnvError(const ACode: Int32; const AOp, AName: string);
var
  LBuf: array[0..255] of AnsiChar;
  LMsg: string;
begin
  if ACode = 0 then
    Exit;
  LMsg := AOp + ' failed (' + IntToStr(ACode) + '): ' + AName;
  if platform_error_message(ACode, @LBuf[0], SizeOf(LBuf)) > 0 then
    LMsg := LMsg + ' — ' + string(PAnsiChar(@LBuf[0]));
  raise EIOError.Create(LMsg);
end;

function CollectEnvEntry(const AEntry: PAnsiChar; AData: Pointer): Boolean;
var
  LValues: PStringArray;
  LCount: Integer;
begin
  LValues := PStringArray(AData);
  LCount := Length(LValues^);
  SetLength(LValues^, LCount + 1);
  LValues^[LCount] := string(AEntry);
  Result := True;
end;

function EnvironmentVariables: TStringArray;
var
  LValues: TStringArray;
begin
  SetLength(LValues, 0);
  RaiseEnvError(platform_env_enumerate(@CollectEnvEntry, @LValues),
    'environment enumeration', '');
  Result := LValues;
end;

function EnvKeys: TStringArray;
var
  LAll: TStringArray;
  I, P, LCount: Integer;
begin
  Result := nil;
  LAll := EnvironmentVariables;
  SetLength(Result, Length(LAll));
  LCount := 0;
  for I := 0 to High(LAll) do
  begin
    P := Pos('=', LAll[I]);
    if P > 1 then
    begin
      Result[LCount] := Copy(LAll[I], 1, P - 1);
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

function GetEnvironmentVariable(const AName: string): string;
begin
  if not TryGetEnv(AName, Result) then
    Result := '';
end;

function TryGetEnv(const AName: string; out AValue: string): Boolean;
var
  LName: string;
  LBuf: array of AnsiChar;
  LLen: Int32;
begin
  Result := False;
  AValue := '';
  ValidateEnvName(AName);
  LName := AName;
  repeat
    if platform_env_get(PAnsiChar(LName), nil, 0, LLen) <> 0 then
      Exit;
    if LLen <= 0 then
    begin
      Result := True;
      Exit;
    end;
    SetLength(LBuf, LLen + 1);
    if platform_env_get(PAnsiChar(LName), @LBuf[0], Length(LBuf), LLen) <> 0 then
      Exit;
    if LLen >= Length(LBuf) then
      Continue;
    SetString(AValue, @LBuf[0], LLen);
    Result := True;
    Exit;
  until False;
end;

function GetEnv(const AName: string): string;
begin
  Result := GetEnvironmentVariable(AName);
end;

function HasEnv(const AName: string): Boolean;
var
  LName: string;
begin
  ValidateEnvName(AName);
  LName := AName;
  Result := platform_env_exists(PAnsiChar(LName));
end;

function EnvironmentVariableNamesCaseSensitive: Boolean;
begin
  Result := platform_env_names_case_sensitive;
end;

procedure SetEnv(const AName, AValue: string);
var
  LN, LV: string;
begin
  ValidatePortableEnvName(AName);
  ValidateEnvValue(AValue);
  LN := AName;
  LV := AValue;
  RaiseEnvError(platform_env_set(PAnsiChar(LN), PAnsiChar(LV)), 'setenv', AName);
end;

function GetEnvDefault(const AName, ADefault: string): string;
begin
  if not TryGetEnv(AName, Result) then
    Result := ADefault;
end;

procedure UnsetEnv(const AName: string);
var
  LN: string;
begin
  ValidatePortableEnvName(AName);
  LN := AName;
  RaiseEnvError(platform_env_unset(PAnsiChar(LN)), 'unsetenv', AName);
end;

procedure ClearEnv;
var
  LKeys: TStringArray;
  I: Integer;
  LN: string;
begin
  LKeys := EnvKeys;
  for I := 0 to High(LKeys) do
  begin
    LN := LKeys[I];
    if LN = '' then
      Continue;
    if (Pos('=', LN) > 0) or (Pos(#0, LN) > 0) then
      Continue;
    { Best-effort: ignore platform errors so one bad key does not abort clear. }
    platform_env_unset(PAnsiChar(LN));
  end;
end;

function ExpandEnvInternal(const AValue, ADefault: string;
  const AMode: TExpandMode): string;
var
  I, LStart: Integer;
  LName, LResolved: string;
  LBuilder: TBufStringBuilder;

  procedure AppendResolvedOrMode(const AVarName: string);
  begin
    if TryGetEnv(AVarName, LResolved) then
      LBuilder.AppendStr(LResolved)
    else
      case AMode of
        emLoose: ;
        emDefault: LBuilder.AppendStr(ADefault);
        emStrict:
          raise EArgumentError.Create(
            'undefined environment variable: ' + AVarName);
      end;
  end;

begin
  LBuilder.Init(Length(AValue));
  try
    I := 1;
    while I <= Length(AValue) do
    begin
      if (AValue[I] = '$') and (I < Length(AValue)) and (AValue[I + 1] = '{') then
      begin
        LStart := I + 2;
        I := LStart;
        while (I <= Length(AValue)) and (AValue[I] <> '}') do
          Inc(I);
        if I > Length(AValue) then
          raise EArgumentError.Create(
            'unterminated ${...} in environment expansion');
        LName := Copy(AValue, LStart, I - LStart);
        ValidatePortableEnvName(LName);
        AppendResolvedOrMode(LName);
        Inc(I);
        Continue;
      end
      else if (AValue[I] = '$') and (I < Length(AValue)) then
      begin
        LStart := I + 1;
        I := LStart;
        while (I <= Length(AValue)) and
          (AValue[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
          Inc(I);
        if I = LStart then
          LBuilder.AppendChar('$')
        else
        begin
          LName := Copy(AValue, LStart, I - LStart);
          ValidatePortableEnvName(LName);
          AppendResolvedOrMode(LName);
        end;
        Continue;
      end
      else if AValue[I] = '%' then
      begin
        { Windows-style %NAME% — NAME must be non-empty [A-Za-z0-9_] }
        LStart := I + 1;
        I := LStart;
        while (I <= Length(AValue)) and
          (AValue[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
          Inc(I);
        if (I > LStart) and (I <= Length(AValue)) and (AValue[I] = '%') then
        begin
          LName := Copy(AValue, LStart, I - LStart);
          ValidatePortableEnvName(LName);
          AppendResolvedOrMode(LName);
          Inc(I);
          Continue;
        end;
        { Not a valid %NAME% — emit literal '%' and rescan from next char }
        LBuilder.AppendChar('%');
        I := LStart;
        Continue;
      end
      else
      begin
        LBuilder.AppendChar(AValue[I]);
        Inc(I);
      end;
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function ExpandEnv(const AValue: string): string;
begin
  Result := ExpandEnvInternal(AValue, '', emLoose);
end;

function ExpandEnvWithDefault(const AValue, ADefault: string): string;
begin
  Result := ExpandEnvInternal(AValue, ADefault, emDefault);
end;

function ExpandEnvStrict(const AValue: string): string;
begin
  Result := ExpandEnvInternal(AValue, '', emStrict);
end;

function JoinUserDir(const ABase, AAppName: string): string;
begin
  if (ABase = '') or (AAppName = '') then
    Exit(ABase);
{$IFDEF NEXTPAS_WINDOWS}
  if (ABase[Length(ABase)] = '\') or (ABase[Length(ABase)] = '/') then
    Result := ABase + AAppName
  else
    Result := ABase + '\' + AAppName;
{$ELSE}
  if ABase[Length(ABase)] = '/' then
    Result := ABase + AAppName
  else
    Result := ABase + '/' + AAppName;
{$ENDIF}
end;

function UserHomeDir: string;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := GetEnv('USERPROFILE');
{$ELSE}
  Result := GetEnv('HOME');
{$ENDIF}
end;

function UserCacheDir(const AAppName: string): string;
var
  LHome: string;
  LXdg: string = '';
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := GetEnv('LOCALAPPDATA');
{$ELSE}
  if TryGetEnv('XDG_CACHE_HOME', LXdg) and (LXdg <> '') then
    Result := LXdg
  else
  begin
    LHome := GetEnv('HOME');
    if LHome <> '' then
      Result := LHome + '/.cache'
    else
      Result := '';
  end;
{$ENDIF}
  Result := JoinUserDir(Result, AAppName);
end;

function UserConfigDir(const AAppName: string): string;
var
  LHome: string;
  LXdg: string = '';
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := GetEnv('APPDATA');
{$ELSE}
  if TryGetEnv('XDG_CONFIG_HOME', LXdg) and (LXdg <> '') then
    Result := LXdg
  else
  begin
    LHome := GetEnv('HOME');
    if LHome <> '' then
      Result := LHome + '/.config'
    else
      Result := '';
  end;
{$ENDIF}
  Result := JoinUserDir(Result, AAppName);
end;

function UserDataDir(const AAppName: string): string;
var
  LHome: string;
  LXdg: string = '';
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := GetEnv('LOCALAPPDATA');
{$ELSE}
  if TryGetEnv('XDG_DATA_HOME', LXdg) and (LXdg <> '') then
    Result := LXdg
  else
  begin
    LHome := GetEnv('HOME');
    if LHome <> '' then
      Result := LHome + '/.local/share'
    else
      Result := '';
  end;
{$ENDIF}
  Result := JoinUserDir(Result, AAppName);
end;

function UserStateDir(const AAppName: string): string;
var
  LHome: string;
  LXdg: string = '';
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := GetEnv('LOCALAPPDATA');
{$ELSE}
  if TryGetEnv('XDG_STATE_HOME', LXdg) and (LXdg <> '') then
    Result := LXdg
  else
  begin
    LHome := GetEnv('HOME');
    if LHome <> '' then
      Result := LHome + '/.local/state'
    else
      Result := '';
  end;
{$ENDIF}
  Result := JoinUserDir(Result, AAppName);
end;

end.
