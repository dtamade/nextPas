unit nextpas.core.platform.env;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc 环境变量枚举回调函数
      @param AEntry 当前条目（NAME=VALUE 格式）
      @param AData 用户数据指针
      @return True 继续枚举，False 停止 *}
  TPlatformEnvEnumerateCallback = function(const AEntry: PAnsiChar;
    AData: Pointer): Boolean;

{** @desc 获取环境变量值
    @param AName 变量名
    @param ABuf 输出缓冲区（可为 nil 仅查询长度）
    @param ABufSize 缓冲区大小
    @param ALen 输出实际长度
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_env_get(const AName: PAnsiChar; ABuf: PAnsiChar;
  ABufSize: Int32; out ALen: Int32): Int32;

{** @desc 设置环境变量
    @param AName 变量名
    @param AValue 变量值
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_env_set(const AName: PAnsiChar;
  const AValue: PAnsiChar): Int32;

{** @desc 删除环境变量
    @param AName 变量名
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_env_unset(const AName: PAnsiChar): Int32;

{** @desc 检查环境变量是否存在
    @param AName 变量名
    @return True 存在 *}
function platform_env_exists(const AName: PAnsiChar): Boolean;

{** @desc 枚举所有环境变量
    @param ACallback 回调函数
    @param AData 用户数据指针
    @return 0 完成，PLATFORM_ERR_* 错误码 *}
function platform_env_enumerate(ACallback: TPlatformEnvEnumerateCallback;
  AData: Pointer): Int32;

{** @desc 环境变量名是否区分大小写（Linux/macOS: True, Windows: False）
    @return True 区分大小写 *}
function platform_env_names_case_sensitive: Boolean;

{** @desc 获取环境变量值（字符串便捷版）
    @param AName 变量名
    @return 变量值，不存在返回空字符串 *}
function platform_env_get_str(const AName: AnsiString): AnsiString;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.posix.helpers;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi,
  nextpas.core.platform.windows.utf16;
{$ENDIF}

function platform_env_name_valid(const AName: PAnsiChar): Boolean;
var
  I: Int32;
begin
  if (AName = nil) or (AName[0] = #0) then
    Exit(False);
  I := 0;
  while AName[I] <> #0 do
  begin
    if AName[I] = '=' then
      Exit(False);
    Inc(I);
  end;
  Result := True;
end;

{$IFDEF NEXTPAS_UNIX}
function platform_env_get(const AName: PAnsiChar; ABuf: PAnsiChar;
  ABufSize: Int32; out ALen: Int32): Int32;
var
  LVal: PAnsiChar;
  I: Int32;
begin
  ALen := 0;
  if not platform_env_name_valid(AName) then
    Exit(PLATFORM_ERR_INVALID);
  LVal := getenv(AName);
  if LVal = nil then
    Exit(PLATFORM_ERR_NOENT);
  while LVal[ALen] <> #0 do
    Inc(ALen);
  if (ABuf <> nil) and (ABufSize > 0) then
  begin
    I := ALen;
    if I >= ABufSize then
      I := ABufSize - 1;
    if I > 0 then
      Move(LVal^, ABuf^, I);
    ABuf[I] := #0;
  end;
  Result := 0;
end;

function platform_env_set(const AName: PAnsiChar;
  const AValue: PAnsiChar): Int32;
begin
  if (not platform_env_name_valid(AName)) or (AValue = nil) then
    Exit(PLATFORM_ERR_INVALID);
  Result := PosixCheck(setenv(AName, AValue, 1));
end;

function platform_env_unset(const AName: PAnsiChar): Int32;
begin
  if not platform_env_name_valid(AName) then
    Exit(PLATFORM_ERR_INVALID);
  Result := PosixCheck(unsetenv(AName));
end;

function platform_env_exists(const AName: PAnsiChar): Boolean;
begin
  if not platform_env_name_valid(AName) then
    Exit(False);
  Result := getenv(AName) <> nil;
end;

function platform_env_enumerate(ACallback: TPlatformEnvEnumerateCallback;
  AData: Pointer): Int32;
var
  LCur: PPAnsiChar;
begin
  if not Assigned(ACallback) then
    Exit(PLATFORM_ERR_INVALID);
  LCur := environ;
  if LCur = nil then
    Exit(0);
  while LCur^ <> nil do
  begin
    if not ACallback(LCur^, AData) then
      Break;
    Inc(LCur);
  end;
  Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_env_get(const AName: PAnsiChar; ABuf: PAnsiChar;
  ABufSize: Int32; out ALen: Int32): Int32;
var
  LName: UnicodeString;
  LValue: array of WideChar;
  LResult: DWORD;
  LLastError: DWORD;
  LUtf8: AnsiString;
begin
  ALen := 0;
  if ABuf = nil then
    ABufSize := 0;
  if not platform_env_name_valid(AName) then
    Exit(Int32(ERROR_INVALID_NAME));
  if not platform_windows_utf8_to_wide_checked(AName, LName) then
    Exit(Int32(ERROR_INVALID_NAME));

  SetLastError(ERROR_SUCCESS);
  LResult := GetEnvironmentVariableW(PWideChar(LName), nil, 0);
  if (LResult = 0) and (GetLastError <> ERROR_SUCCESS) then
  begin
    if GetLastError = ERROR_ENVVAR_NOT_FOUND then
      Exit(Int32(ERROR_ENVVAR_NOT_FOUND));
    Exit(Int32(GetLastError));
  end;

  SetLength(LValue, LResult + 1);
  SetLastError(ERROR_SUCCESS);
  LResult := GetEnvironmentVariableW(PWideChar(LName), @LValue[0],
    DWORD(Length(LValue)));
  LLastError := GetLastError;
  if (LResult = 0) and (LLastError <> ERROR_SUCCESS) then
    Exit(Int32(LLastError));
  LValue[LResult] := #0;
  if not platform_windows_wide_to_utf8_checked(@LValue[0], LUtf8) then
    Exit(Int32(ERROR_INVALID_NAME));
  ALen := platform_windows_copy_utf8_to_buffer(LUtf8, ABuf, ABufSize);
  Result := 0;
end;

function platform_env_set(const AName: PAnsiChar;
  const AValue: PAnsiChar): Int32;
var
  LName: UnicodeString;
  LValue: UnicodeString;
begin
  if (not platform_env_name_valid(AName)) or (AValue = nil) then
    Exit(Int32(ERROR_INVALID_NAME));
  if not platform_windows_utf8_to_wide_checked(AName, LName) then
    Exit(Int32(ERROR_INVALID_NAME));
  if not platform_windows_utf8_to_wide_checked(AValue, LValue) then
    Exit(Int32(ERROR_INVALID_NAME));
  if SetEnvironmentVariableW(PWideChar(LName), PWideChar(LValue)) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_env_unset(const AName: PAnsiChar): Int32;
var
  LName: UnicodeString;
begin
  if not platform_env_name_valid(AName) then
    Exit(Int32(ERROR_INVALID_NAME));
  if not platform_windows_utf8_to_wide_checked(AName, LName) then
    Exit(Int32(ERROR_INVALID_NAME));
  if SetEnvironmentVariableW(PWideChar(LName), nil) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_env_exists(const AName: PAnsiChar): Boolean;
var
  LName: UnicodeString;
begin
  if not platform_env_name_valid(AName) then
    Exit(False);
  if not platform_windows_utf8_to_wide_checked(AName, LName) then
    Exit(False);
  SetLastError(ERROR_SUCCESS);
  Result := (GetEnvironmentVariableW(PWideChar(LName), nil, 0) > 0) or
            (GetLastError <> ERROR_ENVVAR_NOT_FOUND);
end;

function platform_env_enumerate(ACallback: TPlatformEnvEnumerateCallback;
  AData: Pointer): Int32;
var
  LBlock: LPWSTR;
  LCur: PWideChar;
  LUtf8: AnsiString;
begin
  if not Assigned(ACallback) then
    Exit(Int32(ERROR_INVALID_PARAMETER));

  LBlock := GetEnvironmentStringsW;
  if LBlock = nil then
    Exit(Int32(GetLastError));
  try
    LCur := PWideChar(LBlock);
    while LCur^ <> #0 do
    begin
      if not platform_windows_wide_to_utf8_checked(LCur, LUtf8) then
        Exit(Int32(ERROR_INVALID_DATA));
      if not ACallback(PAnsiChar(LUtf8), AData) then
        Break;
      Inc(LCur, Length(UnicodeString(LCur)) + 1);
    end;
    Result := 0;
  finally
    FreeEnvironmentStringsW(LBlock);
  end;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_env_get(const AName: PAnsiChar; ABuf: PAnsiChar;
  ABufSize: Int32; out ALen: Int32): Int32;
begin ALen := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_env_set(const AName: PAnsiChar;
  const AValue: PAnsiChar): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_env_unset(const AName: PAnsiChar): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_env_exists(const AName: PAnsiChar): Boolean;
begin Result := False; end;
function platform_env_enumerate(ACallback: TPlatformEnvEnumerateCallback;
  AData: Pointer): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
{$ENDIF}

function platform_env_names_case_sensitive: Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := False;
{$ELSE}
  Result := True;
{$ENDIF}
end;

function platform_env_get_str(const AName: AnsiString): AnsiString;
var
  LBuf: array[0..4095] of AnsiChar;
  LLen: Int32;
  LRet: Int32;
begin
  Result := '';
  if Length(AName) = 0 then Exit;
  LRet := platform_env_get(@AName[1], @LBuf[0], SizeOf(LBuf), LLen);
  if (LRet = 0) and (LLen > 0) then
  begin
    SetLength(Result, LLen);
    Move(LBuf[0], Result[1], LLen);
  end;
end;

end.
