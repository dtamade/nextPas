unit nextpas.core.platform.console;

{$I nextpas.core.settings.inc}

interface

type
  TPlatformConsoleSize = record
    Cols: Int32;
    Rows: Int32;
  end;

  {**
   * @desc raw 模式保存状态的不透明载体。
   *
   * 接口层不暴露宿主 termios 类型；实现层把 @Opaque[0] 转为 PTermios。
   * 128 字节足以容纳各宿主 termios（Linux 60 字节、macOS 更小、Windows
   * 两个 DWORD），留足余量。
   *}
  TPlatformConsoleMode = record
    Opaque: array[0..127] of Byte;
  end;

  { wait_readable 的三态结果 }
  TPlatformConsoleWait = (cwReadable, cwTimeout, cwInterrupted, cwError);

function platform_console_is_terminal(AFd: Int32): Boolean;
function platform_console_get_size(out ASize: TPlatformConsoleSize): Int32;
function platform_console_get_size_fd(AFd: Int32; out ASize: TPlatformConsoleSize): Int32;
function platform_console_enable_ansi: Int32;

{**
 * @desc 进入 raw 模式。保存当前 termios 到 AMode，设置 raw flags。
 * @return 0 成功，非 0 失败（errno 或 -1）
 *}
function platform_console_set_raw(AFd: Int32; out AMode: TPlatformConsoleMode): Int32;

{**
 * @desc 恢复先前由 set_raw 保存的 termios。
 *}
function platform_console_restore_raw(AFd: Int32; const AMode: TPlatformConsoleMode): Int32;

{**
 * @desc 从 fd 读字节，遇 EINTR 自动重试。
 * @return 读取字节数（>=0），出错返回 -1
 *}
function platform_console_read(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;

{**
 * @desc 向 fd 写字节，遇 EINTR 重试、short-write 续写直到全部写完。
 * @return 写入字节数（= ACount 表示全部成功），出错返回 -1
 *}
function platform_console_write(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;

{**
 * @desc 等待 fd 可读，最多 ATimeoutMs 毫秒。
 * @return cwReadable / cwTimeout / cwInterrupted（被信号打断）/ cwError
 * @note 不在内部重试 EINTR——调用方据此消费信号 pending 状态后自行决定重试。
 *}
function platform_console_wait_readable(AFd: Int32; ATimeoutMs: Int32): TPlatformConsoleWait;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
  {$IFDEF NEXTPAS_LINUX}, nextpas.core.platform.linux.base{$ENDIF};

type
  TWinSize = packed record
    ws_row: UInt16;
    ws_col: UInt16;
    ws_xpixel: UInt16;
    ws_ypixel: UInt16;
  end;

const
{$IFDEF NEXTPAS_LINUX}
  TIOCGWINSZ = $5413;
{$ELSE}
  TIOCGWINSZ = $40087468;
{$ENDIF}

function platform_console_is_terminal(AFd: Int32): Boolean;
begin
  Result := isatty(AFd) <> 0;
end;

function platform_console_get_size_fd(AFd: Int32; out ASize: TPlatformConsoleSize): Int32;
var
  LWin: TWinSize;
begin
  ASize.Cols := 0;
  ASize.Rows := 0;
  if ioctl(AFd, TIOCGWINSZ, @LWin) < 0 then
    Exit(platform_get_errno);
  ASize.Cols := Int32(LWin.ws_col);
  ASize.Rows := Int32(LWin.ws_row);
  Result := 0;
end;

function platform_console_get_size(out ASize: TPlatformConsoleSize): Int32;
begin
  Result := platform_console_get_size_fd(1, ASize);
end;

function platform_console_enable_ansi: Int32;
begin
  Result := 0;
end;

{$IFDEF NEXTPAS_LINUX}
const
  CONSOLE_EINTR = 4;   { EINTR，Linux/macOS/BSD 一致 }

function platform_console_set_raw(AFd: Int32; out AMode: TPlatformConsoleMode): Int32;
var
  LSaved, LRaw: TTermios;
begin
  FillChar(AMode, SizeOf(AMode), 0);
  if isatty(AFd) = 0 then Exit(-1);
  if tcgetattr(AFd, @LSaved) <> 0 then Exit(platform_get_errno);
  Move(LSaved, AMode.Opaque[0], SizeOf(TTermios));
  LRaw := LSaved;
  LRaw.c_iflag := LRaw.c_iflag and (not (IGNBRK or BRKINT or PARMRK or ISTRIP
                                         or INLCR or IGNCR or ICRNL or IXON));
  LRaw.c_oflag := LRaw.c_oflag and (not OPOST);
  LRaw.c_lflag := LRaw.c_lflag and (not (ECHO_ or ECHONL or ICANON or ISIG or IEXTEN));
  LRaw.c_cflag := LRaw.c_cflag and (not (CSIZE or PARENB));
  LRaw.c_cflag := LRaw.c_cflag or CS8;
  LRaw.c_cc[VMIN] := 0;
  LRaw.c_cc[VTIME] := 0;
  if tcsetattr(AFd, TCSANOW, @LRaw) <> 0 then Exit(platform_get_errno);
  Result := 0;
end;

function platform_console_restore_raw(AFd: Int32; const AMode: TPlatformConsoleMode): Int32;
var
  LSaved: TTermios;
begin
  Move(AMode.Opaque[0], LSaved, SizeOf(TTermios));
  if tcsetattr(AFd, TCSANOW, @LSaved) <> 0 then Exit(platform_get_errno);
  Result := 0;
end;

function platform_console_read(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
var
  LRc: ssize_t;
begin
  repeat
    LRc := read(AFd, ABuf, ACount);
  until (LRc >= 0) or (platform_get_errno <> CONSOLE_EINTR);
  Result := Int32(LRc);
end;

function platform_console_write(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
var
  LSent, LWrote: Int32;
  LPtr: PByte;
begin
  if ACount <= 0 then Exit(0);
  LPtr := PByte(ABuf);
  LSent := 0;
  while LSent < ACount do
  begin
    LWrote := Int32(write(AFd, @LPtr[LSent], ACount - LSent));
    if LWrote < 0 then
    begin
      if platform_get_errno = CONSOLE_EINTR then Continue;
      Exit(-1);
    end;
    if LWrote = 0 then Exit(-1);
    Inc(LSent, LWrote);
  end;
  Result := LSent;
end;

function platform_console_wait_readable(AFd: Int32; ATimeoutMs: Int32): TPlatformConsoleWait;
var
  LPfd: pollfd;
  LRc: cint;
begin
  LPfd.fd := AFd;
  LPfd.events := POLLIN;
  LPfd.revents := 0;
  LRc := poll(@LPfd, 1, ATimeoutMs);
  if LRc < 0 then
  begin
    if platform_get_errno = CONSOLE_EINTR then
      Exit(cwInterrupted);
    Exit(cwError);
  end;
  if LRc = 0 then Exit(cwTimeout);
  if (LPfd.revents and POLLIN) <> 0 then
    Exit(cwReadable);
  Result := cwError;
end;
{$ELSE}
{ 非 Linux Unix（macOS/FreeBSD 等）：host base 单元尚未就绪，提供诚实 stub。 }
function platform_console_set_raw(AFd: Int32; out AMode: TPlatformConsoleMode): Int32;
begin FillChar(AMode, SizeOf(AMode), 0); Result := -1; end;
function platform_console_restore_raw(AFd: Int32; const AMode: TPlatformConsoleMode): Int32;
begin Result := -1; end;
function platform_console_read(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
begin Result := -1; end;
function platform_console_write(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
begin Result := -1; end;
function platform_console_wait_readable(AFd: Int32; ATimeoutMs: Int32): TPlatformConsoleWait;
begin Result := cwError; end;
{$ENDIF}
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

type
  TConsoleScreenBufferInfo = packed record
    dwSizeX, dwSizeY: Int16;
    dwCursorX, dwCursorY: Int16;
    wAttributes: UInt16;
    srWindowLeft, srWindowTop, srWindowRight, srWindowBottom: Int16;
    dwMaxSizeX, dwMaxSizeY: Int16;
  end;

function WindowsConsoleHandleFromFd(AFd: Int32; out AHandle: HANDLE): Int32;
var
  LStd: DWORD;
begin
  AHandle := nil;
  case AFd of
    0: LStd := STD_INPUT_HANDLE;
    1: LStd := STD_OUTPUT_HANDLE;
    2: LStd := STD_ERROR_HANDLE;
  else
    Exit(Int32(ERROR_INVALID_HANDLE));
  end;
  AHandle := GetStdHandle(LStd);
  if (AHandle = nil) or (AHandle = HANDLE(INVALID_HANDLE_VALUE)) then
    Exit(Int32(GetLastError));
  Result := 0;
end;

function platform_console_is_terminal(AFd: Int32): Boolean;
var
  LHandle: HANDLE;
  LMode: DWORD;
begin
  if WindowsConsoleHandleFromFd(AFd, LHandle) <> 0 then
    Exit(False);
  LMode := 0;
  Result := GetConsoleMode(LHandle, @LMode) <> 0;
end;

function platform_console_get_size(out ASize: TPlatformConsoleSize): Int32;
begin
  Result := platform_console_get_size_fd(1, ASize);
end;

function platform_console_enable_ansi: Int32;
var
  LHandle: HANDLE;
  LMode: DWORD;
begin
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if LHandle <> HANDLE(PtrInt(-1)) then
  begin
    LMode := 0;
    if GetConsoleMode(LHandle, @LMode) <> 0 then
      SetConsoleMode(LHandle, LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
  end;
  LHandle := GetStdHandle(STD_ERROR_HANDLE);
  if LHandle <> HANDLE(PtrInt(-1)) then
  begin
    LMode := 0;
    if GetConsoleMode(LHandle, @LMode) <> 0 then
      SetConsoleMode(LHandle, LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
  end;
  Result := 0;
end;

function platform_console_get_size_fd(AFd: Int32; out ASize: TPlatformConsoleSize): Int32;
var
  LHandle: HANDLE;
  LInfo: TConsoleScreenBufferInfo;
begin
  ASize.Cols := 0;
  ASize.Rows := 0;
  Result := WindowsConsoleHandleFromFd(AFd, LHandle);
  if Result <> 0 then Exit;
  if GetConsoleScreenBufferInfo(LHandle, @LInfo) = 0 then
    Exit(Int32(GetLastError));
  ASize.Cols := Int32(LInfo.srWindowRight - LInfo.srWindowLeft + 1);
  ASize.Rows := Int32(LInfo.srWindowBottom - LInfo.srWindowTop + 1);
  Result := 0;
end;

function platform_console_set_raw(AFd: Int32; out AMode: TPlatformConsoleMode): Int32;
var
  LHandle: HANDLE;
  LSaved, LRaw: DWORD;
begin
  FillChar(AMode, SizeOf(AMode), 0);
  Result := WindowsConsoleHandleFromFd(AFd, LHandle);
  if Result <> 0 then Exit;
  LSaved := 0;
  if GetConsoleMode(LHandle, @LSaved) = 0 then
    Exit(Int32(GetLastError));
  Move(LSaved, AMode.Opaque[0], SizeOf(LSaved));
  LRaw := LSaved;
  LRaw := LRaw and not (ENABLE_LINE_INPUT or ENABLE_ECHO_INPUT or
    ENABLE_PROCESSED_INPUT);
  LRaw := LRaw or ENABLE_VIRTUAL_TERMINAL_INPUT;
  if SetConsoleMode(LHandle, LRaw) = 0 then
    Exit(Int32(GetLastError));
  Result := 0;
end;

function platform_console_restore_raw(AFd: Int32; const AMode: TPlatformConsoleMode): Int32;
var
  LHandle: HANDLE;
  LMode: DWORD;
begin
  Result := WindowsConsoleHandleFromFd(AFd, LHandle);
  if Result <> 0 then Exit;
  Move(AMode.Opaque[0], LMode, SizeOf(LMode));
  if SetConsoleMode(LHandle, LMode) = 0 then
    Exit(Int32(GetLastError));
  Result := 0;
end;

function platform_console_read(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
var
  LHandle: HANDLE;
  LRead: DWORD;
begin
  if ACount <= 0 then Exit(0);
  if ABuf = nil then Exit(-1);
  if WindowsConsoleHandleFromFd(AFd, LHandle) <> 0 then Exit(-1);
  LRead := 0;
  if ReadFile(LHandle, ABuf, DWORD(ACount), @LRead, nil) = 0 then
    Exit(-1);
  Result := Int32(LRead);
end;

function platform_console_write(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
var
  LHandle: HANDLE;
  LSent, LWritten: Int32;
  LPtr: PByte;
  LChunk: DWORD;
begin
  if ACount <= 0 then Exit(0);
  if ABuf = nil then Exit(-1);
  if WindowsConsoleHandleFromFd(AFd, LHandle) <> 0 then Exit(-1);
  LPtr := PByte(ABuf);
  LSent := 0;
  while LSent < ACount do
  begin
    LChunk := 0;
    if WriteFile(LHandle, @LPtr[LSent], DWORD(ACount - LSent), @LChunk, nil) = 0 then
      Exit(-1);
    LWritten := Int32(LChunk);
    if LWritten <= 0 then Exit(-1);
    Inc(LSent, LWritten);
  end;
  Result := LSent;
end;

function platform_console_wait_readable(AFd: Int32; ATimeoutMs: Int32): TPlatformConsoleWait;
var
  LHandle: HANDLE;
  LTimeout: DWORD;
  LWait: DWORD;
begin
  if WindowsConsoleHandleFromFd(AFd, LHandle) <> 0 then
    Exit(cwError);
  if ATimeoutMs < 0 then
    LTimeout := INFINITE
  else
    LTimeout := DWORD(ATimeoutMs);
  LWait := WaitForSingleObject(LHandle, LTimeout);
  case LWait of
    WAIT_OBJECT_0: Result := cwReadable;
    WAIT_TIMEOUT: Result := cwTimeout;
    WAIT_IO_COMPLETION: Result := cwInterrupted;
  else
    Result := cwError;
  end;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_console_is_terminal(AFd: Int32): Boolean;
begin Result := False; end;
function platform_console_get_size(out ASize: TPlatformConsoleSize): Int32;
begin ASize.Cols := 0; ASize.Rows := 0; Result := -1; end;
function platform_console_get_size_fd(AFd: Int32; out ASize: TPlatformConsoleSize): Int32;
begin ASize.Cols := 0; ASize.Rows := 0; Result := -1; end;
function platform_console_enable_ansi: Int32;
begin Result := -1; end;
function platform_console_set_raw(AFd: Int32; out AMode: TPlatformConsoleMode): Int32;
begin FillChar(AMode, SizeOf(AMode), 0); Result := -1; end;
function platform_console_restore_raw(AFd: Int32; const AMode: TPlatformConsoleMode): Int32;
begin Result := -1; end;
function platform_console_read(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
begin Result := -1; end;
function platform_console_write(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
begin Result := -1; end;
function platform_console_wait_readable(AFd: Int32; ATimeoutMs: Int32): TPlatformConsoleWait;
begin Result := cwError; end;
{$ENDIF}

end.
