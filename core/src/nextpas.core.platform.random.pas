unit nextpas.core.platform.random;

{$I nextpas.core.settings.inc}

interface

function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;

implementation

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_MACOS}
uses
  nextpas.core.platform.darwin.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_FREEBSD}
uses
  nextpas.core.platform.freebsd.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;
{$ENDIF}

function platform_random_check_request(ABuf: Pointer; ALen: PtrUInt; out AResult: Int32): Boolean; inline;
begin
  if ALen = 0 then
  begin
    AResult := 0;
    Exit(True);
  end;
  if ABuf = nil then
  begin
    AResult := -1;
    Exit(True);
  end;
  Result := False;
end;

{$IFDEF NEXTPAS_LINUX}
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
var
  LCheck: Int32;
  LDone: PtrUInt;
  LRet: PtrInt;
begin
  if platform_random_check_request(ABuf, ALen, LCheck) then
    Exit(LCheck);
  LDone := 0;
  while LDone < ALen do
  begin
    LRet := PtrInt(getrandom(Pointer(PtrUInt(ABuf) + LDone), ALen - LDone, 0));
    if LRet < 0 then
      Exit(platform_get_errno);
    Inc(LDone, PtrUInt(LRet));
  end;
  Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_MACOS}
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
var
  LCheck: Int32;
begin
  if platform_random_check_request(ABuf, ALen, LCheck) then
    Exit(LCheck);
  arc4random_buf(ABuf, ALen);
  Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_FREEBSD}
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
var
  LCheck: Int32;
begin
  if platform_random_check_request(ABuf, ALen, LCheck) then
    Exit(LCheck);
  arc4random_buf(ABuf, ALen);
  Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
var
  LCheck: Int32;
begin
  if platform_random_check_request(ABuf, ALen, LCheck) then
    Exit(LCheck);
  if RtlGenRandom(ABuf, DWORD(ALen)) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;
{$ENDIF}

{$IF not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_FREEBSD) and not defined(NEXTPAS_WINDOWS)}
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
var
  LCheck: Int32;
begin
  if platform_random_check_request(ABuf, ALen, LCheck) then
    Exit(LCheck);
  Result := -1;
end;
{$ENDIF}

end.
