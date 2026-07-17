unit nextpas.core.platform.random;

{$I nextpas.core.settings.inc}

interface

{** @desc 生成加密安全的随机字节
    @param ABuf 输出缓冲区
    @param ALen 需要的随机字节数
    @return 0 成功，PLATFORM_ERR_* 错误码 *}
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;

{** @desc 生成随机 UInt64 值（便捷函数）
    @return 随机 64 位无符号整数 *}
function platform_random_u64: UInt64;

implementation

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.errno,
  nextpas.core.platform.linux.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_MACOS}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.darwin.ffi,
  nextpas.core.platform.posix.errno;
{$ENDIF}

{$IFDEF NEXTPAS_FREEBSD}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.freebsd.ffi,
  nextpas.core.platform.posix.errno;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.error,
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
    AResult := PLATFORM_ERR_INVALID;
    Exit(True);
  end;
  Result := False;
end;

function platform_random_u64: UInt64;
begin
  if platform_random_bytes(@Result, SizeOf(Result)) <> 0 then
    Result := 0;
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
    { getrandom(flags=0) blocks until sufficient entropy is available;
      on early boot this may stall indefinitely. Non-critical paths
      should use GRND_NONBLOCK and fall back to /dev/urandom. }
    if LRet < 0 then
      Exit(platform_get_errno);
    if LRet = 0 then
      Exit(PLATFORM_ERR_IO);
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
  LDone: PtrUInt;
  LChunk: DWORD;
begin
  if platform_random_check_request(ABuf, ALen, LCheck) then
    Exit(LCheck);
  LDone := 0;
  while LDone < ALen do
  begin
    if ALen - LDone > PtrUInt(High(DWORD)) then
      LChunk := High(DWORD)
    else
      LChunk := DWORD(ALen - LDone);
    if not RtlGenRandom(Pointer(PtrUInt(ABuf) + LDone), LChunk) then
      Exit(platform_get_last_error);
    Inc(LDone, PtrUInt(LChunk));
  end;
  Result := 0;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_LINUX) and not defined(NEXTPAS_MACOS) and not defined(NEXTPAS_FREEBSD) and not defined(NEXTPAS_WINDOWS)}
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
var
  LCheck: Int32;
begin
  if platform_random_check_request(ABuf, ALen, LCheck) then
    Exit(LCheck);
  Result := PLATFORM_ERR_UNSUPPORTED;
end;
{$ENDIF}

end.
