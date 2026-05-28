unit nextpas.core.platform.random;

{$I nextpas.core.settings.inc}

interface

function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;

implementation

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.ffi;

function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
var
  LDone: PtrUInt;
  LRet: PtrInt;
begin
  if ALen = 0 then
    Exit(0);
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
uses
  nextpas.core.platform.darwin.ffi;

function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
begin
  if ALen = 0 then
    Exit(0);
  arc4random_buf(ABuf, ALen);
  Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_FREEBSD}
uses
  nextpas.core.platform.freebsd.ffi;

function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
begin
  if ALen = 0 then
    Exit(0);
  arc4random_buf(ABuf, ALen);
  Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
begin
  if ALen = 0 then
    Exit(0);
  if RtlGenRandom(ABuf, DWORD(ALen)) then
    Result := 0
  else
    Result := Int32(GetLastError);
end;
{$ENDIF}

{$IF not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_FREEBSD) and not defined(NEXTPAS_WINDOWS)}
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
begin
  Result := -1;
end;
{$ENDIF}

end.
