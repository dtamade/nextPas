unit nextpas.core.os.env;

{$I nextpas.core.settings.inc}

interface

function GetEnvironmentVariable(const AName: string): string;
function GetEnv(const AName: string): string; inline;
function HasEnv(const AName: string): Boolean;
procedure SetEnv(const AName, AValue: string);
procedure UnsetEnv(const AName: string);

implementation

{$IFDEF NEXTPAS_UNIX}
function c_getenv(name: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'getenv';
function c_setenv(name: PAnsiChar; value: PAnsiChar; overwrite: Int32): Int32; cdecl; external 'c' name 'setenv';
function c_unsetenv(name: PAnsiChar): Int32; cdecl; external 'c' name 'unsetenv';
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.ffi;
{$ENDIF}

function GetEnvironmentVariable(const AName: string): string;
var
  LName: string;
  P: PAnsiChar;
  {$IFDEF NEXTPAS_WINDOWS}
  LBuf: array[0..4095] of AnsiChar;
  LLen: DWORD;
  {$ENDIF}
begin
  LName := AName;
  {$IFDEF NEXTPAS_UNIX}
  P := c_getenv(PAnsiChar(LName));
  if P <> nil then
    Result := string(P)
  else
    Result := '';
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  LLen := GetEnvironmentVariableA(PAnsiChar(LName), @LBuf[0], SizeOf(LBuf));
  if (LLen > 0) and (LLen < SizeOf(LBuf)) then
    SetString(Result, @LBuf[0], LLen)
  else
    Result := '';
  {$ENDIF}
end;

function GetEnv(const AName: string): string;
begin
  Result := GetEnvironmentVariable(AName);
end;

function HasEnv(const AName: string): Boolean;
var
  LName: string;
  P: PAnsiChar;
  {$IFDEF NEXTPAS_WINDOWS}
  LBuf: array[0..0] of AnsiChar;
  LLen: DWORD;
  {$ENDIF}
begin
  LName := AName;
  {$IFDEF NEXTPAS_UNIX}
  P := c_getenv(PAnsiChar(LName));
  Result := P <> nil;
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  LLen := GetEnvironmentVariableA(PAnsiChar(LName), @LBuf[0], 0);
  Result := LLen > 0;
  {$ENDIF}
end;

procedure SetEnv(const AName, AValue: string);
var LN, LV: string;
begin
  LN := AName;
  LV := AValue;
  {$IFDEF NEXTPAS_UNIX}
  c_setenv(PAnsiChar(LN), PAnsiChar(LV), 1);
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  SetEnvironmentVariableA(PAnsiChar(LN), PAnsiChar(LV));
  {$ENDIF}
end;

procedure UnsetEnv(const AName: string);
var LN: string;
begin
  LN := AName;
  {$IFDEF NEXTPAS_UNIX}
  c_unsetenv(PAnsiChar(LN));
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  SetEnvironmentVariableA(PAnsiChar(LN), nil);
  {$ENDIF}
end;

end.
