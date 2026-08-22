unit nextpas.core.tui.clipboard;

// OS clipboard access for TUI applications.
//
// Supports three methods:
//   cmOSC52    — terminal escape sequence (works over SSH)
//   cmExternal — pipe to xclip/xsel/pbcopy/wl-copy
//   cmNone     — no clipboard available
//
// Detect() probes the environment and picks the best available method.

{$I nextpas.core.settings.inc}


interface

type
  TClipboardMethod = (cmOSC52, cmExternal, cmNone);

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
  nextpas.core.platform.process.base;


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
    // Wait for process
    if platform_process_wait(LProc, LResult, 5000) <> 0 then Exit;
    Result := LResult.IsSuccess;
  finally
    platform_process_close_handle(LPipes.StdinWrite);
    platform_process_close_handle(LPipes.StdoutRead);
    platform_process_close_handle(LPipes.StderrRead);
  end;
end;

{ Run a tool and capture its stdout.  Returns the captured text. }
function RunCaptureStdout(const AToolPath: AnsiString;
  const AArgs: array of PAnsiChar): AnsiString;
var
  LBuf: array[0..8191] of AnsiChar;
  LArgv: array[0..7] of PAnsiChar;
  LI, LCount: Integer;
  LOutLen, LExitCode: Int32;
begin
  Result := '';
  // Build nil-terminated argv
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

// ---------- TClipboard ----------

class function TClipboard.Detect: TClipboard;
var
  Tool: AnsiString;
begin
  Result.Method := cmNone;
  Result.ExternalTool := '';
  Result.TmuxPassthrough := platform_env_get_str('TMUX') <> '';

  if IsOSC52Terminal then
  begin
    Result.Method := cmOSC52;
    Exit;
  end;

  Tool := FindExternalTool;
  if Tool <> '' then
  begin
    Result.Method := cmExternal;
    Result.ExternalTool := Tool;
    Exit;
  end;
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
begin
  Result := False;
  case Method of
    cmOSC52:
    begin
      Seq := Osc52Sequence(Text, TmuxPassthrough);
      Written := platform_console_write(1, @Seq[1], Length(Seq));
      Result := (Written = Length(Seq));
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
  end;
end;

end.
