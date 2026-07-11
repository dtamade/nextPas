unit nextpas.core.platform.console;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.errno;

{ POSIX raw/read/write/wait support is Linux-only; Windows uses a separate
  standard-handle implementation; macOS/FreeBSD return PLATFORM_ERR_UNSUPPORTED
  or cwError for raw/read/write/wait. }

type
  {** @desc 控制台尺寸结构体 *}
  TPlatformConsoleSize = record
    Cols: Int32;
    Rows: Int32;
    {** @desc 检查尺寸是否有效（大于 0）
        @return True 如果尺寸有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查尺寸是否无效（任一维度为 0）
        @return True 如果尺寸无效 *}
    function IsInvalid: Boolean; inline;
    {** @desc 检查尺寸是否为空
        @return True 如果行或列为 0 *}
    function IsEmpty: Boolean; inline;
    {** @desc 计算总单元格数
        @return Cols * Rows *}
    function CellCount: Int32; inline;
  end;

const
  { ANSI color codes - foreground }
  PLATFORM_CONSOLE_FG_BLACK   = #27'[30m';
  PLATFORM_CONSOLE_FG_RED     = #27'[31m';
  PLATFORM_CONSOLE_FG_GREEN   = #27'[32m';
  PLATFORM_CONSOLE_FG_YELLOW  = #27'[33m';
  PLATFORM_CONSOLE_FG_BLUE    = #27'[34m';
  PLATFORM_CONSOLE_FG_MAGENTA = #27'[35m';
  PLATFORM_CONSOLE_FG_CYAN    = #27'[36m';
  PLATFORM_CONSOLE_FG_WHITE   = #27'[37m';
  PLATFORM_CONSOLE_FG_DEFAULT = #27'[39m';

  { ANSI color codes - background }
  PLATFORM_CONSOLE_BG_BLACK   = #27'[40m';
  PLATFORM_CONSOLE_BG_RED     = #27'[41m';
  PLATFORM_CONSOLE_BG_GREEN   = #27'[42m';
  PLATFORM_CONSOLE_BG_YELLOW  = #27'[43m';
  PLATFORM_CONSOLE_BG_BLUE    = #27'[44m';
  PLATFORM_CONSOLE_BG_MAGENTA = #27'[45m';
  PLATFORM_CONSOLE_BG_CYAN    = #27'[46m';
  PLATFORM_CONSOLE_BG_WHITE   = #27'[47m';
  PLATFORM_CONSOLE_BG_DEFAULT = #27'[49m';

  { ANSI style codes }
  PLATFORM_CONSOLE_BOLD       = #27'[1m';
  PLATFORM_CONSOLE_DIM        = #27'[2m';
  PLATFORM_CONSOLE_ITALIC     = #27'[3m';
  PLATFORM_CONSOLE_UNDERLINE  = #27'[4m';
  PLATFORM_CONSOLE_BLINK      = #27'[5m';
  PLATFORM_CONSOLE_REVERSE    = #27'[7m';
  PLATFORM_CONSOLE_STRIKETHROUGH = #27'[9m';
  PLATFORM_CONSOLE_RESET      = #27'[0m';

  { ANSI cursor control }
  PLATFORM_CONSOLE_CURSOR_HIDE     = #27'[?25l';
  PLATFORM_CONSOLE_CURSOR_SHOW     = #27'[?25h';
  PLATFORM_CURSOR_SAVE             = #27'[s';
  PLATFORM_CURSOR_RESTORE          = #27'[u';

type
  {** @desc raw 模式保存状态的不透明载体
      @note 接口层不暴露宿主 termios 类型；实现层把 Opaque[0] 转为 PTermios
      @note 128 字节足以容纳各宿主 termios（Linux 60 字节、macOS 更小、Windows 两个 DWORD） *}
  TPlatformConsoleMode = record
    Opaque: array[0..127] of Byte;
  end;

  {** @desc wait_readable 的三态结果 *}
  TPlatformConsoleWait = (cwReadable, cwTimeout, cwInterrupted, cwError);

{** @desc 检查文件描述符是否为终端
    @param AFd 文件描述符
    @return True 是终端 *}
function platform_console_is_terminal(AFd: Int32): Boolean;

{** @desc 获取控制台尺寸（stdout）
    @param ASize 输出控制台尺寸
    @return 0 成功，否则返回错误码 *}
function platform_console_get_size(out ASize: TPlatformConsoleSize): Int32;

{** @desc 获取控制台尺寸（指定文件描述符）
    @param AFd 文件描述符
    @param ASize 输出控制台尺寸
    @return 0 成功，否则返回错误码 *}
function platform_console_get_size_fd(AFd: Int32; out ASize: TPlatformConsoleSize): Int32;

{** @desc 启用 ANSI 转义序列支持（Windows）
    @return 0 成功，否则返回错误码 *}
function platform_console_enable_ansi: Int32;

{** @desc 进入 raw 模式
    @param AFd 文件描述符
    @param AMode 输出保存的状态
    @return 0 成功，否则返回错误码 *}
function platform_console_set_raw(AFd: Int32; out AMode: TPlatformConsoleMode): Int32;

{** @desc 恢复先前由 set_raw 保存的终端状态
    @param AFd 文件描述符
    @param AMode 保存的状态
    @return 0 成功，否则返回错误码 *}
function platform_console_restore_raw(AFd: Int32; const AMode: TPlatformConsoleMode): Int32;

{** @desc 从文件描述符读取字节（遇 EINTR 自动重试）
    @param AFd 文件描述符
    @param ABuf 输出缓冲区
    @param ACount 请求字节数
    @return 读取字节数，-1 失败 *}
function platform_console_read(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;

{** @desc 向文件描述符写入字节（遇 EINTR 重试、short-write 续写）
    @param AFd 文件描述符
    @param ABuf 写入缓冲区
    @param ACount 写入字节数
    @return 写入字节数，-1 失败 *}
function platform_console_write(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;

{** @desc 等待文件描述符可读
    @param AFd 文件描述符
    @param ATimeoutMs 超时时间（毫秒）
    @return TPlatformConsoleWait 结果枚举 *}
function platform_console_wait_readable(AFd: Int32; ATimeoutMs: Int64): TPlatformConsoleWait;

{ Console convenience functions }

{** @desc 向 stdout 写入字符串
    @param AStr 字符串指针
    @param ALen 字符串长度
    @return 写入字节数，-1 失败 *}
function platform_console_write_str(AStr: PAnsiChar; ALen: Int32): Int32;

{** @desc 向 stdout 写入带颜色的字符串
    @param AStr 字符串指针
    @param ALen 字符串长度
    @param AFg 前景色 ANSI 代码
    @return 写入字节数，-1 失败 *}
function platform_console_write_colored(AStr: PAnsiChar; ALen: Int32;
  const AFg: AnsiString): Int32;

{** @desc 移动光标到指定位置
    @param ACol 列号（从 0 开始）
    @param ARow 行号（从 0 开始）
    @return 0 成功，否则返回错误码 *}
function platform_console_cursor_move(ACol, ARow: Int32): Int32;

{** @desc 清除当前行
    @return 0 成功，否则返回错误码 *}
function platform_console_clear_line: Int32;

{** @desc 清除屏幕
    @return 0 成功，否则返回错误码 *}
function platform_console_clear_screen: Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.posix.helpers
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

function TPlatformConsoleSize.IsValid: Boolean;
begin
  Result := (Cols > 0) and (Rows > 0);
end;

function TPlatformConsoleSize.IsInvalid: Boolean;
begin
  Result := (Cols = 0) or (Rows = 0);
end;

function TPlatformConsoleSize.IsEmpty: Boolean;
begin
  Result := (Cols = 0) or (Rows = 0);
end;

function TPlatformConsoleSize.CellCount: Int32;
begin
  Result := Cols * Rows;
end;

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
  Result := PosixCheck(ioctl(AFd, TIOCGWINSZ, @LWin));
  if Result = 0 then
  begin
    ASize.Cols := Int32(LWin.ws_col);
    ASize.Rows := Int32(LWin.ws_row);
  end;
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
  if isatty(AFd) = 0 then Exit(PLATFORM_ERR_INVALID);
  Result := PosixCheck(tcgetattr(AFd, @LSaved));
  if Result <> 0 then Exit;
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
  Result := PosixCheck(tcsetattr(AFd, TCSANOW, @LRaw));
end;

function platform_console_restore_raw(AFd: Int32; const AMode: TPlatformConsoleMode): Int32;
var
  LSaved: TTermios;
begin
  Move(AMode.Opaque[0], LSaved, SizeOf(TTermios));
  Result := PosixCheck(tcsetattr(AFd, TCSANOW, @LSaved));
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
      Exit(platform_get_errno);
    end;
    if LWrote = 0 then Exit(PLATFORM_ERR_IO);
    Inc(LSent, LWrote);
  end;
  Result := LSent;
end;

function platform_console_wait_readable(AFd: Int32; ATimeoutMs: Int64): TPlatformConsoleWait;
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

function platform_console_write_str(AStr: PAnsiChar; ALen: Int32): Int32;
begin
  if (AStr = nil) or (ALen <= 0) then
    Exit(0);
  Result := platform_console_write(1, AStr, ALen);
end;

function platform_console_write_colored(AStr: PAnsiChar; ALen: Int32;
  const AFg: AnsiString): Int32;
var
  LTotal, LWritten: Int32;
begin
  LTotal := 0;
  { Write foreground color }
  if Length(AFg) > 0 then
  begin
    LWritten := platform_console_write(1, PAnsiChar(AFg), Length(AFg));
    if LWritten < 0 then Exit(LWritten);
    Inc(LTotal, LWritten);
  end;
  { Write text }
  if (AStr <> nil) and (ALen > 0) then
  begin
    LWritten := platform_console_write(1, AStr, ALen);
    if LWritten < 0 then Exit(LWritten);
    Inc(LTotal, LWritten);
  end;
  { Write reset }
  LWritten := platform_console_write(1, PAnsiChar(PLATFORM_CONSOLE_RESET), Length(PLATFORM_CONSOLE_RESET));
  if LWritten < 0 then Exit(LWritten);
  Inc(LTotal, LWritten);
  Result := LTotal;
end;

function platform_console_cursor_move(ACol, ARow: Int32): Int32;
var
  LBuf: array[0..31] of AnsiChar;
  LLen: Int32;
begin
  { ESC[row;colH - cursor position (1-based) }
  LLen := 0;
  LBuf[LLen] := #27; Inc(LLen);
  LBuf[LLen] := '['; Inc(LLen);
  { Convert row to string }
  if ARow >= 10 then
  begin
    LBuf[LLen] := AnsiChar(Ord('0') + (ARow + 1) div 10); Inc(LLen);
    LBuf[LLen] := AnsiChar(Ord('0') + (ARow + 1) mod 10); Inc(LLen);
  end
  else
  begin
    LBuf[LLen] := AnsiChar(Ord('0') + ARow + 1); Inc(LLen);
  end;
  LBuf[LLen] := ';'; Inc(LLen);
  { Convert col to string }
  if ACol >= 10 then
  begin
    LBuf[LLen] := AnsiChar(Ord('0') + (ACol + 1) div 10); Inc(LLen);
    LBuf[LLen] := AnsiChar(Ord('0') + (ACol + 1) mod 10); Inc(LLen);
  end
  else
  begin
    LBuf[LLen] := AnsiChar(Ord('0') + ACol + 1); Inc(LLen);
  end;
  LBuf[LLen] := 'H'; Inc(LLen);
  Result := platform_console_write(1, @LBuf[0], LLen);
end;

function platform_console_clear_line: Int32;
const
  CLEAR_LINE = #27'[2K';
begin
  Result := platform_console_write(1, PAnsiChar(CLEAR_LINE), 3);
end;

function platform_console_clear_screen: Int32;
const
  CLEAR_SCREEN = #27'[2J';
begin
  Result := platform_console_write(1, PAnsiChar(CLEAR_SCREEN), 4);
end;
{$ELSE}
{ 非 Linux Unix（macOS/FreeBSD 等）：host base 单元尚未就绪，提供诚实 stub。 }
function platform_console_set_raw(AFd: Int32; out AMode: TPlatformConsoleMode): Int32;
begin FillChar(AMode, SizeOf(AMode), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_restore_raw(AFd: Int32; const AMode: TPlatformConsoleMode): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_read(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_write(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_wait_readable(AFd: Int32; ATimeoutMs: Int64): TPlatformConsoleWait;
begin Result := cwError; end;
function platform_console_write_str(AStr: PAnsiChar; ALen: Int32): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_write_colored(AStr: PAnsiChar; ALen: Int32;
  const AFg: AnsiString): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_cursor_move(ACol, ARow: Int32): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_clear_line: Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_clear_screen: Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
{$ENDIF}
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.error,
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

function TPlatformConsoleSize.IsValid: Boolean;
begin
  Result := (Cols > 0) and (Rows > 0);
end;

function TPlatformConsoleSize.IsInvalid: Boolean;
begin
  Result := (Cols = 0) or (Rows = 0);
end;

function TPlatformConsoleSize.IsEmpty: Boolean;
begin
  Result := (Cols = 0) or (Rows = 0);
end;

function TPlatformConsoleSize.CellCount: Int32;
begin
  Result := Cols * Rows;
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
    Exit(PLATFORM_ERR_BADF);
  end;
  AHandle := GetStdHandle(LStd);
  if (AHandle = nil) or (AHandle = HANDLE(INVALID_HANDLE_VALUE)) then
    Exit(platform_get_last_error);
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
  Result := GetConsoleMode(LHandle, @LMode) <> False;
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
    if GetConsoleMode(LHandle, @LMode) then
      SetConsoleMode(LHandle, LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING);
  end;
  LHandle := GetStdHandle(STD_ERROR_HANDLE);
  if LHandle <> HANDLE(PtrInt(-1)) then
  begin
    LMode := 0;
    if GetConsoleMode(LHandle, @LMode) then
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
  if not GetConsoleScreenBufferInfo(LHandle, @LInfo) then
    Exit(platform_get_last_error);
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
  if not GetConsoleMode(LHandle, @LSaved) then
    Exit(platform_get_last_error);
  Move(LSaved, AMode.Opaque[0], SizeOf(LSaved));
  LRaw := LSaved;
  LRaw := LRaw and not (ENABLE_LINE_INPUT or ENABLE_ECHO_INPUT or
    ENABLE_PROCESSED_INPUT);
  LRaw := LRaw or ENABLE_VIRTUAL_TERMINAL_INPUT;
  if not SetConsoleMode(LHandle, LRaw) then
    Exit(platform_get_last_error);
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
  if not SetConsoleMode(LHandle, LMode) then
    Exit(platform_get_last_error);
  Result := 0;
end;

function platform_console_read(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
var
  LHandle: HANDLE;
  LRead: DWORD;
begin
  if ACount <= 0 then Exit(0);
  if ABuf = nil then Exit(PLATFORM_ERR_INVALID);
  if WindowsConsoleHandleFromFd(AFd, LHandle) <> 0 then Exit(PLATFORM_ERR_INVALID_HANDLE);
  LRead := 0;
  if not ReadFile(LHandle, ABuf, DWORD(ACount), @LRead, nil) then
    Exit(platform_get_errno);
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
  if ABuf = nil then Exit(PLATFORM_ERR_INVALID);
  if WindowsConsoleHandleFromFd(AFd, LHandle) <> 0 then Exit(PLATFORM_ERR_INVALID_HANDLE);
  LPtr := PByte(ABuf);
  LSent := 0;
  while LSent < ACount do
  begin
    LChunk := 0;
    if not WriteFile(LHandle, @LPtr[LSent], DWORD(ACount - LSent), @LChunk, nil) then
      Exit(platform_get_errno);
    LWritten := Int32(LChunk);
    if LWritten <= 0 then Exit(platform_get_errno);
    Inc(LSent, LWritten);
  end;
  Result := LSent;
end;

function platform_console_wait_readable(AFd: Int32; ATimeoutMs: Int64): TPlatformConsoleWait;
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

function platform_console_write_str(AStr: PAnsiChar; ALen: Int32): Int32;
begin
  if (AStr = nil) or (ALen <= 0) then
    Exit(0);
  Result := platform_console_write(1, AStr, ALen);
end;

function platform_console_write_colored(AStr: PAnsiChar; ALen: Int32;
  const AFg: AnsiString): Int32;
var
  LTotal, LWritten: Int32;
begin
  LTotal := 0;
  { Write foreground color }
  if Length(AFg) > 0 then
  begin
    LWritten := platform_console_write(1, PAnsiChar(AFg), Length(AFg));
    if LWritten < 0 then Exit(LWritten);
    Inc(LTotal, LWritten);
  end;
  { Write text }
  if (AStr <> nil) and (ALen > 0) then
  begin
    LWritten := platform_console_write(1, AStr, ALen);
    if LWritten < 0 then Exit(LWritten);
    Inc(LTotal, LWritten);
  end;
  { Write reset }
  LWritten := platform_console_write(1, PAnsiChar(PLATFORM_CONSOLE_RESET), Length(PLATFORM_CONSOLE_RESET));
  if LWritten < 0 then Exit(LWritten);
  Inc(LTotal, LWritten);
  Result := LTotal;
end;

function platform_console_cursor_move(ACol, ARow: Int32): Int32;
var
  LBuf: array[0..31] of AnsiChar;
  LLen: Int32;
begin
  { ESC[row;colH - cursor position (1-based) }
  LLen := 0;
  LBuf[LLen] := #27; Inc(LLen);
  LBuf[LLen] := '['; Inc(LLen);
  { Convert row to string }
  if ARow >= 10 then
  begin
    LBuf[LLen] := AnsiChar(Ord('0') + (ARow + 1) div 10); Inc(LLen);
    LBuf[LLen] := AnsiChar(Ord('0') + (ARow + 1) mod 10); Inc(LLen);
  end
  else
  begin
    LBuf[LLen] := AnsiChar(Ord('0') + ARow + 1); Inc(LLen);
  end;
  LBuf[LLen] := ';'; Inc(LLen);
  { Convert col to string }
  if ACol >= 10 then
  begin
    LBuf[LLen] := AnsiChar(Ord('0') + (ACol + 1) div 10); Inc(LLen);
    LBuf[LLen] := AnsiChar(Ord('0') + (ACol + 1) mod 10); Inc(LLen);
  end
  else
  begin
    LBuf[LLen] := AnsiChar(Ord('0') + ACol + 1); Inc(LLen);
  end;
  LBuf[LLen] := 'H'; Inc(LLen);
  Result := platform_console_write(1, @LBuf[0], LLen);
end;

function platform_console_clear_line: Int32;
const
  CLEAR_LINE = #27'[2K';
begin
  Result := platform_console_write(1, PAnsiChar(CLEAR_LINE), 3);
end;

function platform_console_clear_screen: Int32;
const
  CLEAR_SCREEN = #27'[2J';
begin
  Result := platform_console_write(1, PAnsiChar(CLEAR_SCREEN), 4);
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function TPlatformConsoleSize.IsValid: Boolean;
begin Result := (Cols > 0) and (Rows > 0); end;
function TPlatformConsoleSize.IsEmpty: Boolean;
begin Result := (Cols = 0) or (Rows = 0); end;
function TPlatformConsoleSize.CellCount: Int32;
begin Result := Cols * Rows; end;
function platform_console_is_terminal(AFd: Int32): Boolean;
begin Result := False; end;
function platform_console_get_size(out ASize: TPlatformConsoleSize): Int32;
begin ASize.Cols := 0; ASize.Rows := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_get_size_fd(AFd: Int32; out ASize: TPlatformConsoleSize): Int32;
begin ASize.Cols := 0; ASize.Rows := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_enable_ansi: Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_set_raw(AFd: Int32; out AMode: TPlatformConsoleMode): Int32;
begin FillChar(AMode, SizeOf(AMode), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_restore_raw(AFd: Int32; const AMode: TPlatformConsoleMode): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_read(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_write(AFd: Int32; ABuf: Pointer; ACount: Int32): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_wait_readable(AFd: Int32; ATimeoutMs: Int64): TPlatformConsoleWait;
begin Result := cwError; end;
function platform_console_write_str(AStr: PAnsiChar; ALen: Int32): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_write_colored(AStr: PAnsiChar; ALen: Int32;
  const AFg: AnsiString): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_cursor_move(ACol, ARow: Int32): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_clear_line: Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_console_clear_screen: Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
{$ENDIF}

end.
