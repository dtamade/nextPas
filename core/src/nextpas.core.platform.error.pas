unit nextpas.core.platform.error;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.platform.posix.errno;

{ Portable platform error codes — canonical definitions
 *
 * Error code mapping table:
 *   PLATFORM_ERR_* constants mirror Linux errno numbers for the focused-runtime
 *   host. Non-Linux platforms translate native errors via platform_get_errno.
 *
 *   POSIX errno mapping (ESysE* constants from platform .errno.inc):
 *     ESysENOENT  → PLATFORM_ERR_NOENT        (2)
 *     ESysEPERM   → PLATFORM_ERR_PERM         (1)
 *     ESysEACCES  → PLATFORM_ERR_PERM         (1)
 *     ESysEEXIST  → PLATFORM_ERR_EXIST        (17)
 *     ESysEAGAIN  → PLATFORM_ERR_AGAIN        (11)
 *     ESysEBUSY   → PLATFORM_ERR_BUSY         (16)
 *     ESysEINVAL  → PLATFORM_ERR_INVALID      (22)
 *     ESysENOMEM  → PLATFORM_ERR_NOMEM        (12)
 *     ESysENOSPC  → PLATFORM_ERR_NOSPC        (28)
 *     ESysEIO     → ecIO
 *     ESysEPIPE   → ecIO
 *     ESysEINTR   → ecInterrupted
 *     ESysETIMEDOUT → PLATFORM_ERR_TIMEDOUT   (110)
 *     ESysEOPNOTSUPP → PLATFORM_ERR_UNSUPPORTED (95)
 *
 *   Windows ERROR_* mapping (via platform_map_windows_error_code):
 *     ERROR_FILE_NOT_FOUND → PLATFORM_ERR_NOENT
 *     ERROR_ACCESS_DENIED  → PLATFORM_ERR_PERM
 *     ERROR_DISK_FULL      → PLATFORM_ERR_NOSPC
 *     ERROR_TIMEOUT        → PLATFORM_ERR_TIMEDOUT
 *     WSAEINTR             → PLATFORM_ERR_INTR
 *     WSAETIMEDOUT         → PLATFORM_ERR_TIMEDOUT
 *     unmapped ERROR_*/WSAE* → PLATFORM_ERR_UNKNOWN (never raw passthrough)
 *
 *   Domain codes (not host errno):
 *     PLATFORM_ERR_PATH_TOO_LONG (-7) — client path clamp, not ENAMETOOLONG
 *     PLATFORM_ERR_UNKNOWN (-8) — unmapped host native error
 *}
const
  PLATFORM_ERR_PERM        = 1;     { Operation not permitted }
  PLATFORM_ERR_NOENT       = 2;     { No such file or directory }
  PLATFORM_ERR_INTR        = 4;     { Interrupted system call }
  PLATFORM_ERR_IO          = 5;     { I/O error }
  PLATFORM_ERR_BADF        = 9;     { Bad file descriptor }
  PLATFORM_ERR_AGAIN       = 11;    { Resource temporarily unavailable }
  PLATFORM_ERR_NOMEM       = 12;    { Out of memory }
  PLATFORM_ERR_BUSY        = 16;    { Device or resource busy }
  PLATFORM_ERR_EXIST       = 17;    { File exists }
  PLATFORM_ERR_NOTDIR      = 20;    { Not a directory }
  PLATFORM_ERR_INVALID     = 22;    { Invalid argument }
  PLATFORM_ERR_NOSPC       = 28;    { No space left on device }
  PLATFORM_ERR_PIPE        = 32;    { Broken pipe }
  PLATFORM_ERR_NOSYS       = 38;    { Function not implemented }
  PLATFORM_ERR_UNSUPPORTED = 95;    { Operation not supported }
  PLATFORM_ERR_CONNRESET   = 104;   { Connection reset by peer }
  PLATFORM_ERR_CONNREFUSED = 111;   { Connection refused }
  PLATFORM_ERR_TIMEDOUT    = 110;   { Operation timed out }
  PLATFORM_ERR_PATH_TOO_LONG = -7;  { Domain path limit (PLATFORM_FS_MAX_PATH); not OS ENAMETOOLONG }
  PLATFORM_ERR_UNKNOWN     = -8;   { Host native error could not be mapped to a portable PLATFORM_ERR_* }

  { Aliases for backward compatibility }
  PLATFORM_ERR_ENOENT      = PLATFORM_ERR_NOENT;
  PLATFORM_ERR_EEXIST      = PLATFORM_ERR_EXIST;
  PLATFORM_ERR_ENOTDIR     = PLATFORM_ERR_NOTDIR;
  PLATFORM_ERR_TIMEOUT     = PLATFORM_ERR_TIMEDOUT;
  PLATFORM_ERR_INVALID_HANDLE = PLATFORM_ERR_BADF;

{** @desc 获取平台错误码对应的错误消息
    @param ACode 错误码
    @param ABuf 输出缓冲区
    @param ABufSize 缓冲区大小
    @return 实际写入字节数 *}
function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufSize: Int32): Int32;

{** @desc 获取错误码的错误类别
    @param ACode 错误码
    @return 错误类别枚举 *}
function platform_error_category(ACode: Int32): TErrorCategory;

{** @desc 输出致命错误消息并终止进程
    @param AMsg 错误消息字符串 *}
procedure platform_fatal(const AMsg: PAnsiChar);

{** @desc 输出致命错误消息和错误码并终止进程
    @param AMsg 错误消息字符串
    @param ACode 错误码；Halt 只接收 8-bit 退出码，此处显式做 ACode mod 256 截断 *}
procedure platform_fatal_code(const AMsg: PAnsiChar; ACode: Int32);

{** @desc 获取最后一次平台错误，映射为 PLATFORM_ERR_* 可移植错误码
    POSIX 直接返回 errno（PLATFORM_ERR_* 常量 = Linux errno）。
    Windows 通过 GetLastError() + ERROR_*/WSAE* → PLATFORM_ERR_* 映射。
    @return PLATFORM_ERR_* 错误码，无错误时返回 0 *}
function platform_get_last_error: Int32;

{** @desc 获取最后一次宿主原生错误码（未映射）
    POSIX: errno；Windows: GetLastError。
    不替代 platform_get_last_error 的可移植映射；用于诊断日志。
    @return 宿主原生错误码，无错误时通常为 0 *}
function platform_get_last_os_error: Int32;


{$IFDEF NEXTPAS_WINDOWS}
{** @desc 将 Windows 原生错误码映射为 PLATFORM_ERR_* 可移植错误码 *}

function platform_map_windows_error_code(const AErr: DWORD): Int32;
{$ENDIF}

implementation

{$IF defined(NEXTPAS_UNIX)}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  {$ELSEIF defined(NEXTPAS_MACOS)}
  , nextpas.core.platform.darwin.base
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  , nextpas.core.platform.freebsd.base
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  , nextpas.core.platform.android.base
  {$ELSE}
  , nextpas.core.platform.unix.base
  {$ENDIF}
  ;

function platform_get_last_error: Int32;
begin
  Result := platform_get_errno;
end;

function platform_get_last_os_error: Int32;
begin
  Result := platform_get_errno;
end;


{$ELSEIF defined(NEXTPAS_WINDOWS)}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi
  ;

function platform_map_windows_error_code(const AErr: DWORD): Int32;
begin
  if AErr = 0 then
    Exit(0);
  case AErr of
    ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND: Result := PLATFORM_ERR_NOENT;
    ERROR_ACCESS_DENIED:                        Result := PLATFORM_ERR_PERM;
    ERROR_FILE_EXISTS, ERROR_ALREADY_EXISTS:    Result := PLATFORM_ERR_EXIST;
    ERROR_NOT_ENOUGH_MEMORY, ERROR_OUTOFMEMORY: Result := PLATFORM_ERR_NOMEM;
    ERROR_DISK_FULL:                            Result := PLATFORM_ERR_NOSPC;
    ERROR_INVALID_PARAMETER, ERROR_INVALID_NAME: Result := PLATFORM_ERR_INVALID;
    ERROR_INVALID_HANDLE:                       Result := PLATFORM_ERR_BADF;
    ERROR_NOT_SUPPORTED:                        Result := PLATFORM_ERR_UNSUPPORTED;
    ERROR_BROKEN_PIPE:                          Result := PLATFORM_ERR_PIPE;
    ERROR_TIMEOUT:                              Result := PLATFORM_ERR_TIMEDOUT;
    ERROR_OPERATION_ABORTED:                    Result := PLATFORM_ERR_INTR;
    ERROR_ENVVAR_NOT_FOUND:                     Result := PLATFORM_ERR_NOENT;
    ERROR_NOT_FOUND:                            Result := PLATFORM_ERR_NOENT;
    ERROR_MOD_NOT_FOUND, ERROR_PROC_NOT_FOUND:  Result := PLATFORM_ERR_NOENT;
    ERROR_IO_PENDING:                           Result := PLATFORM_ERR_AGAIN;
    WSAEINTR:                                   Result := PLATFORM_ERR_INTR;
    WSAETIMEDOUT:                               Result := PLATFORM_ERR_TIMEDOUT;
    WSAECONNRESET:                              Result := PLATFORM_ERR_CONNRESET;
    WSAECONNREFUSED:                            Result := PLATFORM_ERR_CONNREFUSED;
    WSAEWOULDBLOCK:                             Result := PLATFORM_ERR_AGAIN;
    WSAENOBUFS:                                 Result := PLATFORM_ERR_NOMEM;
    WSAEADDRINUSE:                              Result := PLATFORM_ERR_EXIST;
    WSAENETUNREACH, WSAEHOSTUNREACH:            Result := PLATFORM_ERR_CONNREFUSED;
    WSAENOTCONN:                                Result := PLATFORM_ERR_CONNREFUSED;
    WSAECONNABORTED:                            Result := PLATFORM_ERR_CONNRESET;
    WSAHOST_NOT_FOUND:                          Result := PLATFORM_ERR_NOENT;
  else
    { Never passthrough raw ERROR_*/WSAE* into the portable code space. }
    Result := PLATFORM_ERR_UNKNOWN;
  end;
end;

function platform_get_last_error: Int32;
var
  LErr: DWORD;
begin
  LErr := GetLastError;
  Result := platform_map_windows_error_code(LErr);
end;

function platform_get_last_os_error: Int32;
begin
  Result := Int32(GetLastError);
end;


{$ENDIF}

function CopyPlatformErrorMessage(const AMessage: PAnsiChar; ABuf: PAnsiChar;
  ABufSize: Int32): Int32;
var
  LLen: Int32;
begin
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);

  LLen := 0;
  while AMessage[LLen] <> #0 do
    Inc(LLen);
  if LLen >= ABufSize then
    LLen := ABufSize - 1;
  if LLen > 0 then
    Move(AMessage^, ABuf^, LLen);
  ABuf[LLen] := #0;
  Result := LLen;
end;

function TryPlatformErrorTokenMessage(ACode: Int32; ABuf: PAnsiChar;
  ABufSize: Int32; out ALen: Int32): Boolean;
begin
  Result := True;
  case ACode of
    PLATFORM_ERR_PERM:
      ALen := CopyPlatformErrorMessage('operation not permitted', ABuf, ABufSize);
    PLATFORM_ERR_NOENT:
      ALen := CopyPlatformErrorMessage('no such file or directory', ABuf, ABufSize);
    PLATFORM_ERR_INTR:
      ALen := CopyPlatformErrorMessage('interrupted system call', ABuf, ABufSize);
    PLATFORM_ERR_IO:
      ALen := CopyPlatformErrorMessage('input/output error', ABuf, ABufSize);
    PLATFORM_ERR_BADF:
      ALen := CopyPlatformErrorMessage('bad file descriptor', ABuf, ABufSize);
    PLATFORM_ERR_AGAIN:
      ALen := CopyPlatformErrorMessage('resource temporarily unavailable', ABuf, ABufSize);
    PLATFORM_ERR_NOMEM:
      ALen := CopyPlatformErrorMessage('out of memory', ABuf, ABufSize);
    PLATFORM_ERR_BUSY:
      ALen := CopyPlatformErrorMessage('device or resource busy', ABuf, ABufSize);
    PLATFORM_ERR_EXIST:
      ALen := CopyPlatformErrorMessage('file already exists', ABuf, ABufSize);
    PLATFORM_ERR_NOTDIR:
      ALen := CopyPlatformErrorMessage('not a directory', ABuf, ABufSize);
    PLATFORM_ERR_INVALID:
      ALen := CopyPlatformErrorMessage('invalid argument', ABuf, ABufSize);
    PLATFORM_ERR_NOSPC:
      ALen := CopyPlatformErrorMessage('no space left on device', ABuf, ABufSize);
    PLATFORM_ERR_PIPE:
      ALen := CopyPlatformErrorMessage('broken pipe', ABuf, ABufSize);
    PLATFORM_ERR_NOSYS:
      ALen := CopyPlatformErrorMessage('function not implemented', ABuf, ABufSize);
    PLATFORM_ERR_UNSUPPORTED:
      ALen := CopyPlatformErrorMessage('operation not supported', ABuf, ABufSize);
    PLATFORM_ERR_CONNRESET:
      ALen := CopyPlatformErrorMessage('connection reset by peer', ABuf, ABufSize);
    PLATFORM_ERR_CONNREFUSED:
      ALen := CopyPlatformErrorMessage('connection refused', ABuf, ABufSize);
    PLATFORM_ERR_TIMEDOUT:
      ALen := CopyPlatformErrorMessage('operation timed out', ABuf, ABufSize);
    PLATFORM_ERR_PATH_TOO_LONG:
      ALen := CopyPlatformErrorMessage('path too long', ABuf, ABufSize);
    PLATFORM_ERR_UNKNOWN:
      ALen := CopyPlatformErrorMessage('unknown platform error', ABuf, ABufSize);
  else
    Result := False;
    ALen := -1;
  end;
end;

{$IFDEF NEXTPAS_UNIX}
function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufSize: Int32): Int32;
var
  LMsg: PAnsiChar;
  LLen: Int32;
begin
  if TryPlatformErrorTokenMessage(ACode, ABuf, ABufSize, Result) then
    Exit;
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  LMsg := strerror(ACode);
  if LMsg = nil then
  begin
    ABuf[0] := #0;
    Exit(PLATFORM_ERR_INVALID);
  end;
  LLen := 0;
  while LMsg[LLen] <> #0 do
    Inc(LLen);
  if LLen >= ABufSize then
    LLen := ABufSize - 1;
  if LLen > 0 then
    Move(LMsg^, ABuf^, LLen);
  ABuf[LLen] := #0;
  Result := LLen;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufSize: Int32): Int32;
var
  LLen: DWORD;
  I: Int32;
begin
  if TryPlatformErrorTokenMessage(ACode, ABuf, ABufSize, Result) then
    Exit;
  if (ABuf = nil) or (ABufSize <= 0) then
    Exit(PLATFORM_ERR_INVALID);
  LLen := FormatMessageA(
    FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,
    nil, DWORD(ACode), 0, ABuf, DWORD(ABufSize), nil);
  if LLen = 0 then
  begin
    ABuf[0] := #0;
    Exit(PLATFORM_ERR_INVALID);
  end;
  // Strip trailing \r\n
  I := Int32(LLen);
  while (I > 0) and ((ABuf[I-1] = #13) or (ABuf[I-1] = #10)) do
    Dec(I);
  ABuf[I] := #0;
  Result := I;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufSize: Int32): Int32;
begin
  if TryPlatformErrorTokenMessage(ACode, ABuf, ABufSize, Result) then
    Exit;
  if ABuf <> nil then ABuf[0] := #0;
  Result := PLATFORM_ERR_UNSUPPORTED;
end;
{$ENDIF}

{**
 * @desc 将平台错误码映射到通用错误分类
 *
 * POSIX 路径：使用 ESysE* 常量（来自 linux.base/darwin.base/freebsd.base 的 .errno.inc）
 *   - ESysENOENT = 文件不存在
 *   - ESysEACCES/EPERM = 权限不足
 *   - ESysEADDRINUSE = 地址已占用
 *   - ESysENETUNREACH/EHOSTUNREACH/ENOTCONN = 网络不可达
 *   - ESysENOMEM/ENOSPC = 资源耗尽
 *   - ESysEINVAL = 无效参数
 *   - ESysEOPNOTSUPP = 操作不支持
 *   - ESysETIMEDOUT = 超时
 *   - ESysEAGAIN/EBUSY = 可重试/资源忙
 *   - ESysEIO = I/O 错误
 *   - ESysEPIPE/ECONNABORTED/ECONNRESET/ECONNREFUSED = 连接错误
 *   - ESysEINTR = 被中断
 *
 * Windows 路径：使用 ERROR_* 和 WSAE* 常量（来自 windows.base）
 *   - ERROR_FILE_NOT_FOUND/PATH_NOT_FOUND 等 = 文件不存在
 *   - ERROR_ACCESS_DENIED = 权限不足
 *
 * PLATFORM_ERR_* 路径：非 Unix/Windows 平台的 fallback 映射
 *}
function platform_error_category(ACode: Int32): TErrorCategory;
begin
  case ACode of
    0:
      Exit(ecNone);
    PLATFORM_ERR_INVALID, PLATFORM_ERR_PATH_TOO_LONG:
      Exit(ecInvalidArgument);
    PLATFORM_ERR_UNKNOWN:
      Exit(ecInternal);
    PLATFORM_ERR_UNSUPPORTED, PLATFORM_ERR_NOSYS:
      Exit(ecNotSupported);
    PLATFORM_ERR_TIMEDOUT:
      Exit(ecTimeout);
    PLATFORM_ERR_AGAIN,
    PLATFORM_ERR_BUSY:
      Exit(ecWouldBlock);
    PLATFORM_ERR_BADF,
    PLATFORM_ERR_IO,
    PLATFORM_ERR_PIPE:
      Exit(ecIO);
    PLATFORM_ERR_NOENT,
    PLATFORM_ERR_NOTDIR:
      Exit(ecNotFound);
    PLATFORM_ERR_EXIST:
      Exit(ecAlreadyExists);
    PLATFORM_ERR_PERM:
      Exit(ecPermission);
    PLATFORM_ERR_NOMEM, PLATFORM_ERR_NOSPC:
      Exit(ecResourceExhausted);
    PLATFORM_ERR_INTR:
      Exit(ecInterrupted);
    PLATFORM_ERR_CONNRESET,
    PLATFORM_ERR_CONNREFUSED:
      Exit(ecIO);
  end;

  case ACode of
    {$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
    ESysENOENT:
      Result := ecNotFound;
    ESysEPERM,
    ESysEACCES:
      Result := ecPermission;
    ESysEEXIST:
      Result := ecAlreadyExists;
    ESysEADDRINUSE:
      Result := ecAlreadyExists;
    ESysENETUNREACH,
    ESysEHOSTUNREACH,
    ESysENOTCONN:
      Result := ecNetwork;
    ESysENOMEM,
    ESysENOSPC:
      Result := ecResourceExhausted;
    ESysEINVAL:
      Result := ecInvalidArgument;
    ESysEOPNOTSUPP:
      Result := ecNotSupported;
    ESysETIMEDOUT:
      Result := ecTimeout;
    ESysEAGAIN,
    ESysEBUSY:
      Result := ecWouldBlock;
    ESysEIO:
      Result := ecIO;
    ESysEPIPE,
    ESysECONNABORTED,
    ESysECONNRESET,
    ESysECONNREFUSED:
      Result := ecIO;
    ESysEINTR:
      Result := ecInterrupted;
    {$ENDIF}
    {$IF defined(NEXTPAS_UNIX) and not (defined(NEXTPAS_LINUX) or defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD))}
    { Android/generic-unix base units export only this errno subset }
    ESysEINVAL:
      Result := ecInvalidArgument;
    ESysEOPNOTSUPP:
      Result := ecNotSupported;
    ESysETIMEDOUT:
      Result := ecTimeout;
    ESysEAGAIN,
    ESysEBUSY:
      Result := ecWouldBlock;
    ESysEINTR:
      Result := ecInterrupted;
    {$ENDIF}
    {$IFDEF NEXTPAS_WINDOWS}
    ERROR_FILE_NOT_FOUND,
    ERROR_PATH_NOT_FOUND,
    ERROR_MOD_NOT_FOUND,
    ERROR_PROC_NOT_FOUND,
    ERROR_ENVVAR_NOT_FOUND,
    ERROR_NOT_FOUND,
    WSAHOST_NOT_FOUND:
      Result := ecNotFound;
    ERROR_ACCESS_DENIED:
      Result := ecPermission;
    ERROR_FILE_EXISTS,
    ERROR_ALREADY_EXISTS,
    WSAEADDRINUSE:
      Result := ecAlreadyExists;
    WSAENETUNREACH,
    WSAEHOSTUNREACH,
    WSAENOTCONN:
      Result := ecNetwork;
    ERROR_NOT_ENOUGH_MEMORY,
    ERROR_DISK_FULL,
    ERROR_OUTOFMEMORY,
    WSAENOBUFS:
      Result := ecResourceExhausted;
    ERROR_INVALID_PARAMETER:
      Result := ecInvalidArgument;
    ERROR_NOT_SUPPORTED:
      Result := ecNotSupported;
    ERROR_TIMEOUT,
    WSAETIMEDOUT:
      Result := ecTimeout;
    WSAEWOULDBLOCK:
      Result := ecWouldBlock;
    ERROR_BROKEN_PIPE,
    WSAECONNABORTED,
    WSAECONNRESET,
    WSAECONNREFUSED:
      Result := ecIO;
    ERROR_OPERATION_ABORTED,
    WSAEINTR:
      Result := ecInterrupted;
    {$ENDIF}
  else
    Result := ecInternal;
  end;
end;

procedure WriteStderr(const S: PAnsiChar; ALen: Int32);
{$IFNDEF NEXTPAS_UNIX}
var
  LWritten: DWORD;
{$ENDIF}
begin
{$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi.write(2, S, ALen);
{$ELSE}
  if ALen > 0 then
    WriteFile(GetStdHandle(STD_ERROR_HANDLE), S, ALen, @LWritten, nil);
{$ENDIF}
end;

procedure platform_fatal(const AMsg: PAnsiChar);
var
  LLen: Int32;
begin
  WriteStderr('fatal: ', 7);
  if AMsg <> nil then
  begin
    LLen := 0;
    while AMsg[LLen] <> #0 do Inc(LLen);
    if LLen > 0 then
      WriteStderr(AMsg, LLen);
  end;
  WriteStderr(PAnsiChar(#10), 1);
  {$IFDEF NEXTPAS_UNIX}
  posix_exit(1);
  {$ELSE}
  ExitProcess(1);
  {$ENDIF}
end;

procedure platform_fatal_code(const AMsg: PAnsiChar; ACode: Int32);
var
  LLen: Int32;
  LBuf: array[0..15] of AnsiChar;
  LCodeLen, I: Int32;
  LVal: UInt32;
begin
  WriteStderr('fatal: ', 7);
  if AMsg <> nil then
  begin
    LLen := 0;
    while AMsg[LLen] <> #0 do Inc(LLen);
    if LLen > 0 then
      WriteStderr(AMsg, LLen);
  end;
  WriteStderr(' (code ', 7);
  if ACode < 0 then
  begin
    WriteStderr('-', 1);
    LVal := UInt32(-ACode);
  end
  else
    LVal := UInt32(ACode);
  LCodeLen := 0;
  repeat
    LBuf[LCodeLen] := AnsiChar(Ord('0') + (LVal mod 10));
    LVal := LVal div 10;
    Inc(LCodeLen);
  until LVal = 0;
  // reverse
  for I := 0 to (LCodeLen div 2) - 1 do
  begin
    LBuf[15] := LBuf[I];
    LBuf[I] := LBuf[LCodeLen - 1 - I];
    LBuf[LCodeLen - 1 - I] := LBuf[15];
  end;
  WriteStderr(@LBuf[0], LCodeLen);
  WriteStderr(')'#10, 2);
  {$IFDEF NEXTPAS_UNIX}
  posix_exit(ACode and $FF);
  {$ELSE}
  ExitProcess(DWORD(ACode and $FF));
  {$ENDIF}
end;

end.
