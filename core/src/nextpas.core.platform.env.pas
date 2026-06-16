unit nextpas.core.platform.env;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformEnvEnumerateCallback = function(const AEntry: PAnsiChar;
    AData: Pointer): Boolean;

function platform_env_get(const AName: PAnsiChar; ABuf: PAnsiChar;
  ABufLen: Int32; out ALen: Int32): Int32;
function platform_env_set(const AName: PAnsiChar;
  const AValue: PAnsiChar): Int32;
function platform_env_unset(const AName: PAnsiChar): Int32;
function platform_env_exists(const AName: PAnsiChar): Boolean;
function platform_env_enumerate(ACallback: TPlatformEnvEnumerateCallback;
  AData: Pointer): Int32;
function platform_env_names_case_sensitive: Boolean;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.error;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
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
  ABufLen: Int32; out ALen: Int32): Int32;
var
  LVal: PAnsiChar;
  I: Int32;
begin
  ALen := 0;
  if not platform_env_name_valid(AName) then
    Exit(PLATFORM_ERR_INVALID);
  LVal := getenv(AName);
  if LVal = nil then
    Exit(PLATFORM_ERR_ENOENT);
  while LVal[ALen] <> #0 do
    Inc(ALen);
  if (ABuf <> nil) and (ABufLen > 0) then
  begin
    I := ALen;
    if I >= ABufLen then
      I := ABufLen - 1;
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
  if setenv(AName, AValue, 1) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_env_unset(const AName: PAnsiChar): Int32;
begin
  if not platform_env_name_valid(AName) then
    Exit(PLATFORM_ERR_INVALID);
  if unsetenv(AName) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
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
  ABufLen: Int32; out ALen: Int32): Int32;
var
  LName: UnicodeString;
  LValue: array of WideChar;
  LResult: DWORD;
  LLastError: DWORD;
  LUtf8: AnsiString;
begin
  ALen := 0;
  if ABuf = nil then
    ABufLen := 0;
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
  ALen := platform_windows_copy_utf8_to_buffer(LUtf8, ABuf, ABufLen);
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
  ABufLen: Int32; out ALen: Int32): Int32;
begin ALen := 0; Result := -1; end;
function platform_env_set(const AName: PAnsiChar;
  const AValue: PAnsiChar): Int32;
begin Result := -1; end;
function platform_env_unset(const AName: PAnsiChar): Int32;
begin Result := -1; end;
function platform_env_exists(const AName: PAnsiChar): Boolean;
begin Result := False; end;
function platform_env_enumerate(ACallback: TPlatformEnvEnumerateCallback;
  AData: Pointer): Int32;
begin Result := -1; end;
{$ENDIF}

function platform_env_names_case_sensitive: Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := False;
{$ELSE}
  Result := True;
{$ENDIF}
end;

end.
