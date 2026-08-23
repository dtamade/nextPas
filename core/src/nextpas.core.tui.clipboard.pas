unit nextpas.core.tui.clipboard;

// OS clipboard access for TUI applications.
//
// Supports four methods:
//   cmOSC52    — terminal escape sequence (works over SSH)
//   cmExternal — pipe to xclip/xsel/pbcopy/wl-copy
//   cmWin32    — native Win32 clipboard (Windows, user32)
//   cmNone     — no clipboard available
//
// Detect() probes the environment and picks the best available method.
// POSIX priority: external tool > OSC52 —— 外部工具直连系统剪贴板,
// 双向真实可达;OSC52 是单向(仅复制)且依赖外层终端支持(Terminator、
// gnome-terminal 等不识别 → 静默失败),只作无工具时(SSH 场景)兜底。

{$I nextpas.core.settings.inc}


interface

type
  { cmOSC52 保持首成员:零初始化记录语义与旧版一致(零值 = cmOSC52) }
  TClipboardMethod = (cmOSC52, cmExternal, cmWin32, cmNone);

const
  { 外部剪贴板命令(wl-copy/xclip/xsel/pb*)整体限时毫秒数。
    挂死场景(死 X socket、SSH X11 转发卡顿)会冻住 TUI——老版
    grok-switch clipboard.go 的 clipboardCLITimeout=400ms 同款上限;
    超时一律 SIGKILL,不冻 UI、不留孤儿进程 }
  CLIP_CLI_TIMEOUT_MS = 400;

type
  TClipboard = record
    Method: TClipboardMethod;
    ExternalTool: AnsiString;
    { 刀 k53（code888 反哺）：直接终端是 tmux pane（TMUX 环境变量非空）
      时为 True —— cmOSC52 发射走 DCS passthrough 信封，穿透 tmux
      到达外层终端剪贴板（锚 grok-build clipboard.rs osc52_sequence；
      仅当 tmux 是 IMMEDIATE 终端时正确——编辑器 :terminal 内层模拟器
      是 libvterm，信封会渲染成可见垃圾，code888 顶层应用无此场景） }
    TmuxPassthrough: Boolean;

    class function Detect: TClipboard; static;
    { POSIX 侧通道决策(纯函数,可单测):外部工具优先,OSC52 兜底,
      全无 → cmNone。Detect 收集环境布尔后委托此函数 }
    class function PickPosixMethod(AHasTool, AOSC52Terminal, ATmux: Boolean): TClipboardMethod; static;
    function Copy(const Text: AnsiString): Boolean;
    function Paste: AnsiString;
    function GetOSC52Copy(const Text: AnsiString): AnsiString;
  end;

{ OSC52 复制序列构造（纯函数）。ATmuxPassthrough=False →
  ESC]52;c;<b64>ST（现款）；True → tmux DCS passthrough 信封
  ESC Ptmux; ESC(翻倍) ESC]52;c;<b64>BEL ST——内层以 BEL 终止
  （信封内 ST 的 ESC 需再翻倍，BEL 更简单可靠；锚 grok 逐字节）。 }
function Osc52Sequence(const Text: AnsiString;
  ATmuxPassthrough: Boolean): AnsiString;

implementation

uses
  nextpas.core.platform.console,
  nextpas.core.platform.env,
  nextpas.core.platform.which,
  nextpas.core.platform.process,
  nextpas.core.platform.process.base
  {$IFDEF NEXTPAS_UNIX}
    , nextpas.core.platform.posix.base       { TPollFd/POLLIN:限时捕获管道轮询 }
    , nextpas.core.platform                  { platform_monotonic_ns:截止时钟 }
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
    , nextpas.core.platform.windows.base
    , nextpas.core.platform.windows.ffi
    , nextpas.core.platform.windows.utf16
  {$ENDIF};


// ---------- Base64 encoder (self-contained) ----------

const
  Base64Chars: array[0..63] of Char =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function Base64Encode(const Input: AnsiString): AnsiString;
var
  Len, I, O: Integer;
  B0, B1, B2: Byte;
begin
  Len := Length(Input);
  if Len = 0 then begin Result := ''; Exit; end;
  SetLength(Result, ((Len + 2) div 3) * 4);
  O := 1;
  I := 1;
  while I <= Len - 2 do
  begin
    B0 := Ord(Input[I]);
    B1 := Ord(Input[I + 1]);
    B2 := Ord(Input[I + 2]);
    Result[O]     := Base64Chars[B0 shr 2];
    Result[O + 1] := Base64Chars[((B0 and $03) shl 4) or (B1 shr 4)];
    Result[O + 2] := Base64Chars[((B1 and $0F) shl 2) or (B2 shr 6)];
    Result[O + 3] := Base64Chars[B2 and $3F];
    Inc(I, 3);
    Inc(O, 4);
  end;
  // Handle remaining 1 or 2 bytes
  if I = Len then
  begin
    B0 := Ord(Input[I]);
    Result[O]     := Base64Chars[B0 shr 2];
    Result[O + 1] := Base64Chars[(B0 and $03) shl 4];
    Result[O + 2] := '=';
    Result[O + 3] := '=';
  end
  else if I = Len - 1 then
  begin
    B0 := Ord(Input[I]);
    B1 := Ord(Input[I + 1]);
    Result[O]     := Base64Chars[B0 shr 2];
    Result[O + 1] := Base64Chars[((B0 and $03) shl 4) or (B1 shr 4)];
    Result[O + 2] := Base64Chars[(B1 and $0F) shl 2];
    Result[O + 3] := '=';
  end;
end;

// ---------- Helpers ----------

function ToolExists(const Name: AnsiString): Boolean;
var
  LBuf: array[0..1023] of AnsiChar;
begin
  Result := platform_which(PAnsiChar(Name), @LBuf[0], 1024) >= 0;
end;

function IsOSC52Terminal: Boolean;
var
  TermProg, Term: AnsiString;
begin
  TermProg := platform_env_get_str('TERM_PROGRAM');
  Term := platform_env_get_str('TERM');
  // Known OSC 52 supporters
  if (TermProg = 'iTerm.app') or (TermProg = 'iTerm2') or
     (TermProg = 'kitty') or (TermProg = 'alacritty') or
     (TermProg = 'WezTerm') then
  begin
    Result := True;
    Exit;
  end;
  // tmux and screen pass through OSC 52
  if (Pos('tmux', Term) > 0) or (Pos('screen', Term) > 0) then
  begin
    Result := True;
    Exit;
  end;
  Result := False;
end;

function FindExternalTool: AnsiString;
begin
  // Check Wayland first
  if platform_env_get_str('WAYLAND_DISPLAY') <> '' then
  begin
    if ToolExists('wl-copy') then begin Result := 'wl-copy'; Exit; end;
  end;
  // X11
  if platform_env_get_str('DISPLAY') <> '' then
  begin
    if ToolExists('xclip') then begin Result := 'xclip'; Exit; end;
    if ToolExists('xsel') then begin Result := 'xsel'; Exit; end;
  end;
  // macOS
  if ToolExists('pbcopy') then begin Result := 'pbcopy'; Exit; end;
  Result := '';
end;

{ Run a tool with stdin redirected: write AInput to its stdin, return True on
  success.  Uses platform_process_create_piped so no FPC RTL process units. }
function RunWithStdin(const AToolPath: AnsiString;
  const AArgs: array of PAnsiChar;
  const AInput: AnsiString): Boolean;
var
  LProc: TPlatformProcess;
  LPipes: TPlatformProcessPipes;
  LArgv: array[0..7] of PAnsiChar;
  LI, LWritten, LCount: Integer;
  LResult: TPlatformProcessResult;
  LErr: Int32;
begin
  Result := False;
  // Build nil-terminated argv
  LCount := Length(AArgs);
  if LCount > 7 then LCount := 7;
  for LI := 0 to LCount - 1 do
    LArgv[LI] := AArgs[LI];
  LArgv[LCount] := nil;

  { 必须显式声明管道选项,否则 create_piped 只初始化 StdinWrite:=-1,
    写入直接失败(曾导致 xclip 路径 Copy 永远返回 False) }
  LErr := platform_process_create_piped(
    PAnsiChar(AToolPath), @LArgv[0], nil,
    [poRedirectStdin, poCaptureStdout, poCaptureStderr],
    LProc, LPipes);
  if LErr <> 0 then Exit;
  try
    // Write input to stdin
    if Length(AInput) > 0 then
    begin
      if (platform_process_write_stdin_ex(
        LPipes.StdinWrite, @AInput[1], Length(AInput), LWritten) <> 0) or
        (LWritten <> Length(AInput)) then Exit;
    end;
    // Close stdin to signal EOF
    platform_process_close_handle(LPipes.StdinWrite);
    // Wait for process — 限时 + 超时 SIGKILL:外部命令挂死(死 X socket/
    // SSH X11 卡顿)会冻住 TUI,老版 grok-switch clipboard.go 同款 400ms 上限
    if platform_process_wait(LProc, LResult, CLIP_CLI_TIMEOUT_MS) <> 0 then
    begin
      platform_process_kill(LProc);
      platform_process_wait(LProc, LResult, 200);
      Exit;
    end;
    Result := LResult.IsSuccess;
  finally
    platform_process_close_handle(LPipes.StdinWrite);
    platform_process_close_handle(LPipes.StdoutRead);
    platform_process_close_handle(LPipes.StderrRead);
  end;
end;

{ Run a tool and capture its stdout.  Returns the captured text.
  POSIX 限时版:platform_process_run 无超时参数,粘贴路径若遇挂死的
  xclip -o(死 X socket)会永久冻住 TUI —— poll 带截止时钟读管道,
  超时 SIGKILL。语义与旧实现一致:退出码 0 且有输出才返回内容。 }
{$IFDEF NEXTPAS_UNIX}
function RunCaptureStdout(const AToolPath: AnsiString;
  const AArgs: array of PAnsiChar): AnsiString;
var
  LProc: TPlatformProcess;
  LPipes: TPlatformProcessPipes;
  LArgv: array[0..7] of PAnsiChar;
  LI, LCount: Int32;
  LFd: TPollFd;
  LChunk: array[0..1023] of AnsiChar;
  LN, LErr: Int32;
  LResult: TPlatformProcessResult;
  LDeadline, LNow: UInt64;
  LRemainMs: Int32;
begin
  Result := '';
  // Build nil-terminated argv
  LCount := Length(AArgs);
  if LCount > 7 then LCount := 7;
  for LI := 0 to LCount - 1 do
    LArgv[LI] := AArgs[LI];
  LArgv[LCount] := nil;

  if platform_process_create_piped(
    PAnsiChar(AToolPath), @LArgv[0], nil,
    [poCaptureStdout, poCaptureStderr],
    LProc, LPipes) <> 0 then Exit;
  try
    LDeadline := platform_monotonic_ns +
      UInt64(CLIP_CLI_TIMEOUT_MS) * 1000000;
    while True do
    begin
      LNow := platform_monotonic_ns;
      if LNow >= LDeadline then
      begin
        platform_process_kill(LProc);
        platform_process_wait(LProc, LResult, 200);
        Exit('');
      end;
      LRemainMs := (LDeadline - LNow) div 1000000;
      if LRemainMs < 1 then LRemainMs := 1;
      LFd.fd := LPipes.StdoutRead;
      LFd.events := POLLIN;
      LFd.revents := 0;
      { 就绪数 0=本段超时(下轮循环判截止),<0=poll 错误(放弃) }
      if platform_io_poll(@LFd, 1, LRemainMs) <= 0 then Continue;
      LErr := platform_process_read_stdout_ex(LPipes.StdoutRead,
        @LChunk[0], SizeOf(LChunk), LN);
      if LErr <> 0 then Break;
      if LN <= 0 then Break;                    { EOF:子进程输出完毕 }
      SetLength(Result, Length(Result) + LN);
      Move(LChunk[0], Result[Length(Result) - LN + 1], LN);
    end;
    { 输出收完等退出码:同样限时 }
    if platform_process_wait(LProc, LResult, CLIP_CLI_TIMEOUT_MS) <> 0 then
    begin
      platform_process_kill(LProc);
      platform_process_wait(LProc, LResult, 200);
      Exit('');
    end;
    if (not LResult.IsSuccess) or (Length(Result) = 0) then
      Result := '';
  finally
    platform_process_close_handle(LPipes.StdinWrite);
    platform_process_close_handle(LPipes.StdoutRead);
    platform_process_close_handle(LPipes.StderrRead);
  end;
end;
{$ENDIF}

{ Windows 兜底版:cmExternal 在 Windows 上不可达(Detect 恒 cmWin32),
  仅保证单元可编译;无超时是可接受的死代码 }
{$IFDEF NEXTPAS_WINDOWS}
function RunCaptureStdout(const AToolPath: AnsiString;
  const AArgs: array of PAnsiChar): AnsiString;
var
  LBuf: array[0..8191] of AnsiChar;
  LArgv: array[0..7] of PAnsiChar;
  LI, LCount: Integer;
  LOutLen, LExitCode: Int32;
begin
  Result := '';
  LCount := Length(AArgs);
  if LCount > 7 then LCount := 7;
  for LI := 0 to LCount - 1 do
    LArgv[LI] := AArgs[LI];
  LArgv[LCount] := nil;

  if platform_process_run(
    PAnsiChar(AToolPath), @LArgv[0], nil,
    @LBuf[0], 8192, LOutLen, LExitCode) = 0 then
  begin
    if (LExitCode = 0) and (LOutLen > 0) then
      SetString(Result, @LBuf[0], LOutLen);
  end;
end;
{$ENDIF}

{ Build a tool path from the tool name.  Returns empty string if not found. }
function ResolveToolPath(const ATool: AnsiString): AnsiString;
var
  LBuf: array[0..1023] of AnsiChar;
  LLen: Int32;
begin
  LLen := platform_which(PAnsiChar(ATool), @LBuf[0], 1024);
  if LLen >= 0 then
    SetString(Result, @LBuf[0], LLen)
  else
    Result := '';
end;

{$IFDEF NEXTPAS_WINDOWS}
const
  GMEM_MOVEABLE  = DWORD($0002);
  CF_UNICODETEXT = UINT($000D);

{ Win32 原生写剪贴板:UTF-8 → UTF-16 → CF_UNICODETEXT。
  成功后 HMem 所有权移交系统(不得 GlobalFree);失败路径自清理 }
function Win32SetClipboardText(const AText: AnsiString): Boolean;
var
  LWide: UnicodeString;
  LHMem, LHSet: HANDLE;
  PLock: Pointer;
  LBytes: PtrUInt;
begin
  Result := False;
  if AText = '' then Exit;
  if not platform_windows_utf8_to_wide_checked(PAnsiChar(AText), LWide) then Exit;
  LBytes := (Length(LWide) + 1) * SizeOf(WideChar);
  LHMem := GlobalAlloc(GMEM_MOVEABLE, LBytes);
  if LHMem = nil then Exit;
  PLock := GlobalLock(LHMem);
  if PLock = nil then
  begin
    GlobalFree(LHMem);
    Exit;
  end;
  Move(PWideChar(LWide)^, PLock^, LBytes);
  GlobalUnlock(LHMem);
  { 剪贴板可能被其他进程短暂占用:OpenClipboard 失败即放弃(无重试,
    与外部工具路径同等语义——失败由调用方 toast 反馈) }
  if not OpenClipboard(nil) then
  begin
    GlobalFree(LHMem);
    Exit;
  end;
  try
    EmptyClipboard;
    LHSet := SetClipboardData(CF_UNICODETEXT, LHMem);
    if LHSet <> nil then
      Result := True
    else
      GlobalFree(LHMem);
  finally
    CloseClipboard;
  end;
end;

{ Win32 原生读剪贴板:CF_UNICODETEXT → UTF-8;无文本格式返回空 }
function Win32GetClipboardText: AnsiString;
var
  LHMem: HANDLE;
  PLock: PWideChar;
begin
  Result := '';
  if not OpenClipboard(nil) then Exit;
  try
    LHMem := GetClipboardData(CF_UNICODETEXT);
    if LHMem = nil then Exit;
    PLock := PWideChar(GlobalLock(LHMem));
    if PLock <> nil then
    try
      Result := platform_windows_wide_to_utf8(PLock);
    finally
      GlobalUnlock(LHMem);
    end;
  finally
    CloseClipboard;
  end;
end;
{$ENDIF}

// ---------- TClipboard ----------

class function TClipboard.PickPosixMethod(AHasTool, AOSC52Terminal,
  ATmux: Boolean): TClipboardMethod;
begin
  { 外部工具直连系统剪贴板,复制/粘贴双向真实可达 → 首选 }
  if AHasTool then Exit(cmExternal);
  { 无工具时 OSC52 兜底(SSH 场景);tmux pane 走 DCS passthrough 信封 }
  if AOSC52Terminal or ATmux then Exit(cmOSC52);
  Result := cmNone;
end;

class function TClipboard.Detect: TClipboard;
var
  Tool: AnsiString;
begin
  Result.Method := cmNone;
  Result.ExternalTool := '';
  Result.TmuxPassthrough := platform_env_get_str('TMUX') <> '';

  {$IFDEF NEXTPAS_WINDOWS}
  { Win32 原生剪贴板:不依赖终端对 OSC52 的支持(conhost/老版 Windows
    Terminal 均可用),复制粘贴双向真实可达 → Windows 上唯一正解 }
  Result.Method := cmWin32;
  Exit;
  {$ENDIF}

  Tool := FindExternalTool;
  Result.Method := PickPosixMethod(Tool <> '', IsOSC52Terminal,
    Result.TmuxPassthrough);
  Result.ExternalTool := Tool;
end;

function Osc52Sequence(const Text: AnsiString;
  ATmuxPassthrough: Boolean): AnsiString;
var
  Encoded: AnsiString;
begin
  Encoded := Base64Encode(Text);
  if ATmuxPassthrough then
    // DCS passthrough: ESC Ptmux ; ESC(escaped) OSC52(BEL) ST
    Result := #27'Ptmux;'#27#27']52;c;' + Encoded + #7#27'\'
  else
    // ESC ] 52 ; c ; <base64> ESC backslash
    Result := #27']52;c;' + Encoded + #27'\';
end;

function TClipboard.GetOSC52Copy(const Text: AnsiString): AnsiString;
begin
  Result := Osc52Sequence(Text, False);
end;

function TClipboard.Copy(const Text: AnsiString): Boolean;
var
  Seq, LPath: AnsiString;
  Written: Int32;
  PSeq: PAnsiChar;
  LRemaining: Integer;
begin
  Result := False;
  case Method of
    cmOSC52:
    begin
      Seq := Osc52Sequence(Text, TmuxPassthrough);
      { 转义序列必须整条落流:短写补齐重试。半截 OSC52 会被终端当普通
        字符渲染(老版序列问题同类),且未闭合的解析态还会吞掉后续帧输出 }
      LRemaining := Length(Seq);
      PSeq := nil;
      if LRemaining > 0 then
        PSeq := @Seq[1];
      while (LRemaining > 0) and (PSeq <> nil) do
      begin
        Written := platform_console_write(1, Pointer(PSeq), LRemaining);
        if Written <= 0 then Break;
        Inc(PSeq, Written);
        Dec(LRemaining, Written);
      end;
      Result := (LRemaining = 0);
    end;
    cmExternal:
    begin
      LPath := ResolveToolPath(ExternalTool);
      if LPath = '' then Exit;
      if ExternalTool = 'xclip' then
        Result := RunWithStdin(LPath,
          [PAnsiChar('xclip'), PAnsiChar('-selection'), PAnsiChar('clipboard'), nil], Text)
      else if ExternalTool = 'xsel' then
        Result := RunWithStdin(LPath,
          [PAnsiChar('xsel'), PAnsiChar('--clipboard'), PAnsiChar('--input'), nil], Text)
      else if ExternalTool = 'pbcopy' then
        Result := RunWithStdin(LPath, [PAnsiChar('pbcopy'), nil], Text)
      else if ExternalTool = 'wl-copy' then
        Result := RunWithStdin(LPath, [PAnsiChar('wl-copy'), nil], Text);
    end;
    cmNone:
      Result := False;
    {$IFDEF NEXTPAS_WINDOWS}
    cmWin32:
      Result := Win32SetClipboardText(Text);
    {$ENDIF}
  end;
end;

function TClipboard.Paste: AnsiString;
var
  LPath: AnsiString;
begin
  Result := '';
  case Method of
    cmOSC52:
      Result := '';
    cmExternal:
    begin
      LPath := ResolveToolPath(ExternalTool);
      if LPath = '' then Exit;
      if ExternalTool = 'xclip' then
        Result := RunCaptureStdout(LPath,
          [PAnsiChar('xclip'), PAnsiChar('-selection'), PAnsiChar('clipboard'), PAnsiChar('-o'), nil])
      else if ExternalTool = 'xsel' then
        Result := RunCaptureStdout(LPath,
          [PAnsiChar('xsel'), PAnsiChar('--clipboard'), PAnsiChar('--output'), nil])
      else if ExternalTool = 'pbcopy' then
        Result := RunCaptureStdout(LPath, [PAnsiChar('pbpaste'), nil])
      else if ExternalTool = 'wl-copy' then
        Result := RunCaptureStdout(LPath, [PAnsiChar('wl-paste'), nil]);
    end;
    cmNone:
      Result := '';
    {$IFDEF NEXTPAS_WINDOWS}
    cmWin32:
      Result := Win32GetClipboardText;
    {$ENDIF}
  end;
end;

end.
