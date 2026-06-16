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

function EnvironmentVariables: TStringArray;
function GetEnvironmentVariable(const AName: string): string;
function GetEnv(const AName: string): string; inline;
function TryGetEnv(const AName: string; out AValue: string): Boolean;
function HasEnv(const AName: string): Boolean;
function EnvironmentVariableNamesCaseSensitive: Boolean; inline;
procedure SetEnv(const AName, AValue: string);
procedure UnsetEnv(const AName: string);
function ExpandEnv(const AValue: string): string;

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.platform.env;

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

procedure ValidateEnvValue(const AValue: string);
var
  I: Integer;
begin
  for I := 1 to Length(AValue) do
    if AValue[I] = #0 then
      raise EArgumentError.Create('environment variable value must not contain NUL');
end;

procedure RaiseEnvError(const ACode: Int32; const AOp, AName: string);
begin
  if ACode = 0 then
    Exit;
  raise EIOError.Create(AOp + ' failed (' + IntToStr(ACode) + '): ' + AName);
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
  ValidateEnvName(AName);
  ValidateEnvValue(AValue);
  LN := AName;
  LV := AValue;
  RaiseEnvError(platform_env_set(PAnsiChar(LN), PAnsiChar(LV)), 'setenv', AName);
end;

procedure UnsetEnv(const AName: string);
var
  LN: string;
begin
  ValidateEnvName(AName);
  LN := AName;
  RaiseEnvError(platform_env_unset(PAnsiChar(LN)), 'unsetenv', AName);
end;

function ExpandEnv(const AValue: string): string;
var
  I, LStart: Integer;
  LName: string;
begin
  Result := '';
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
      ValidateEnvName(LName);
      Result := Result + GetEnvironmentVariable(LName);
      Inc(I);
      Continue;
    end;
    Result := Result + AValue[I];
    Inc(I);
  end;
end;

end.
