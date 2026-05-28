unit nextpas.core.platform.dl;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformLibrary = record
  {$IFDEF NEXTPAS_WINDOWS}
    Handle: PtrUInt;
  {$ELSE}
    Handle: Pointer;
  {$ENDIF}
  end;

const
  PLATFORM_DL_LAZY   = 1;
  PLATFORM_DL_NOW    = 2;
  PLATFORM_DL_GLOBAL = 4;

function platform_dl_open(const APath: PAnsiChar; AFlags: Int32;
  out ALib: TPlatformLibrary): Int32;
function platform_dl_sym(const ALib: TPlatformLibrary;
  const AName: PAnsiChar; out AAddr: Pointer): Int32;
function platform_dl_close(var ALib: TPlatformLibrary): Int32;
function platform_dl_error(ABuf: PAnsiChar; ABufLen: Int32): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  , nextpas.core.platform.linux.ffi
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.base
  , nextpas.core.platform.darwin.ffi
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  , nextpas.core.platform.freebsd.base
  , nextpas.core.platform.freebsd.ffi
{$ENDIF}
  ;

function MapFlags(AFlags: Int32): Int32;
var
  LResult: Int32;
begin
  if (AFlags and PLATFORM_DL_NOW) <> 0 then
    LResult := RTLD_NOW
  else
    LResult := RTLD_LAZY;
  if (AFlags and PLATFORM_DL_GLOBAL) <> 0 then
    LResult := LResult or RTLD_GLOBAL;
  Result := LResult;
end;

function platform_dl_open(const APath: PAnsiChar; AFlags: Int32;
  out ALib: TPlatformLibrary): Int32;
begin
  FillChar(ALib, SizeOf(ALib), 0);
  ALib.Handle := dlopen(APath, MapFlags(AFlags));
  if ALib.Handle = nil then
    Result := 2 // caller uses platform_dl_error for details
  else
    Result := 0;
end;

function platform_dl_sym(const ALib: TPlatformLibrary;
  const AName: PAnsiChar; out AAddr: Pointer): Int32;
begin
  AAddr := nil;
  if ALib.Handle = nil then
    Exit(22); // EINVAL
  dlerror; // clear previous error
  AAddr := dlsym(ALib.Handle, AName);
  if AAddr = nil then
  begin
    if dlerror <> nil then
      Result := 2 // symbol not found
    else
      Result := 0; // symbol genuinely maps to nil (rare but valid)
  end
  else
    Result := 0;
end;

function platform_dl_close(var ALib: TPlatformLibrary): Int32;
begin
  if ALib.Handle = nil then
    Exit(22); // EINVAL
  if dlclose(ALib.Handle) <> 0 then
    Result := platform_get_errno
  else
    Result := 0;
  ALib.Handle := nil;
end;

function platform_dl_error(ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LMsg: PAnsiChar;
  LLen, I: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  LMsg := dlerror;
  if LMsg = nil then
  begin
    ABuf[0] := #0;
    Exit(0);
  end;
  LLen := 0;
  while LMsg[LLen] <> #0 do
    Inc(LLen);
  if LLen >= ABufLen then
    LLen := ABufLen - 1;
  for I := 0 to LLen - 1 do
    ABuf[I] := LMsg[I];
  ABuf[LLen] := #0;
  Result := LLen;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

function platform_dl_open(const APath: PAnsiChar; AFlags: Int32;
  out ALib: TPlatformLibrary): Int32;
begin
  FillChar(ALib, SizeOf(ALib), 0);
  ALib.Handle := PtrUInt(LoadLibraryA(APath));
  if ALib.Handle = 0 then
    Result := Int32(GetLastError)
  else
    Result := 0;
end;

function platform_dl_sym(const ALib: TPlatformLibrary;
  const AName: PAnsiChar; out AAddr: Pointer): Int32;
begin
  AAddr := nil;
  if ALib.Handle = 0 then
    Exit(Int32(87)); // ERROR_INVALID_PARAMETER
  AAddr := Pointer(GetProcAddress(HMODULE(ALib.Handle), AName));
  if AAddr = nil then
    Result := Int32(GetLastError)
  else
    Result := 0;
end;

function platform_dl_close(var ALib: TPlatformLibrary): Int32;
begin
  if ALib.Handle = 0 then
    Exit(Int32(6)); // ERROR_INVALID_HANDLE
  if FreeLibrary(HMODULE(ALib.Handle)) then
    Result := 0
  else
    Result := Int32(GetLastError);
  ALib.Handle := 0;
end;

function platform_dl_error(ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LErr: DWORD;
  LLen: DWORD;
  I: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  LErr := GetLastError;
  if LErr = 0 then
  begin
    ABuf[0] := #0;
    Exit(0);
  end;
  LLen := FormatMessageA(
    FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,
    nil, LErr, 0, ABuf, DWORD(ABufLen), nil);
  if LLen = 0 then
  begin
    ABuf[0] := #0;
    Exit(Int32(LErr));
  end;
  I := Int32(LLen);
  while (I > 0) and ((ABuf[I-1] = #13) or (ABuf[I-1] = #10)) do
    Dec(I);
  ABuf[I] := #0;
  Result := I;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_dl_open(const APath: PAnsiChar; AFlags: Int32;
  out ALib: TPlatformLibrary): Int32;
begin FillChar(ALib, SizeOf(ALib), 0); Result := -1; end;
function platform_dl_sym(const ALib: TPlatformLibrary;
  const AName: PAnsiChar; out AAddr: Pointer): Int32;
begin AAddr := nil; Result := -1; end;
function platform_dl_close(var ALib: TPlatformLibrary): Int32;
begin Result := -1; end;
function platform_dl_error(ABuf: PAnsiChar; ABufLen: Int32): Int32;
begin if ABuf <> nil then ABuf[0] := #0; Result := -1; end;
{$ENDIF}

end.
