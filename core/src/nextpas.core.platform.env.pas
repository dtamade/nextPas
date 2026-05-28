unit nextpas.core.platform.env;

{$I nextpas.core.settings.inc}

interface

function platform_env_get(const AName: PAnsiChar; ABuf: PAnsiChar;
  ABufLen: Int32; out ALen: Int32): Int32;
function platform_env_set(const AName: PAnsiChar;
  const AValue: PAnsiChar): Int32;
function platform_env_unset(const AName: PAnsiChar): Int32;
function platform_env_exists(const AName: PAnsiChar): Boolean;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function platform_env_get(const AName: PAnsiChar; ABuf: PAnsiChar;
  ABufLen: Int32; out ALen: Int32): Int32;
var
  LVal: PAnsiChar;
  I: Int32;
begin
  ALen := 0;
  LVal := getenv(AName);
  if LVal = nil then
    Exit(2); // ENOENT
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
  if setenv(AName, AValue, 1) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_env_unset(const AName: PAnsiChar): Int32;
begin
  if unsetenv(AName) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_env_exists(const AName: PAnsiChar): Boolean;
begin
  Result := getenv(AName) <> nil;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

function platform_env_get(const AName: PAnsiChar; ABuf: PAnsiChar;
  ABufLen: Int32; out ALen: Int32): Int32;
var
  LResult: DWORD;
begin
  ALen := 0;
  if ABuf = nil then
    ABufLen := 0;
  LResult := GetEnvironmentVariableA(AName, ABuf, DWORD(ABufLen));
  if LResult = 0 then
  begin
    if GetLastError = 203 then
      Exit(203); // ERROR_ENVVAR_NOT_FOUND
    Exit(Int32(GetLastError));
  end;
  ALen := Int32(LResult);
  if (ABuf <> nil) and (Int32(LResult) < ABufLen) then
    ABuf[LResult] := #0;
  Result := 0;
end;

function platform_env_set(const AName: PAnsiChar;
  const AValue: PAnsiChar): Int32;
begin
  if SetEnvironmentVariableA(AName, AValue) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_env_unset(const AName: PAnsiChar): Int32;
begin
  if SetEnvironmentVariableA(AName, nil) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;

function platform_env_exists(const AName: PAnsiChar): Boolean;
var
  LBuf: array[0..0] of AnsiChar;
begin
  Result := (GetEnvironmentVariableA(AName, @LBuf[0], 1) > 0) or
            (GetLastError <> 203);
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
{$ENDIF}

end.
