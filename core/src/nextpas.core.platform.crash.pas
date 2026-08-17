unit nextpas.core.platform.crash;

{**
 * nextpas.core.platform.crash - 崩溃信号恢复助手
 *
 * 场景：TUI 程序（gtd888/music888 同款需求）在 alt screen 中崩溃时，
 * 必须在退出前复位终端（退 alt screen / 显光标 / 关鼠标上报），否则
 * 终端残留花屏与隐藏光标。
 *
 * 策略：SIGSEGV/SIGTERM/SIGABRT/SIGBUS 安装复位性 handler（写复位序列
 * 后以 128+sig 退出），SIGPIPE 忽略。handler 只做 FpWrite + Halt，
 * 全程不碰堆分配/锁/异常路径（async-signal-safe）；复位串在安装时
 * 拷入静态缓冲，安装后只读。
 *
 * 非 unix 平台为空实现，调用方可无条件编译。
 *}

{$I nextpas.core.settings.inc}

interface

{** @desc 安装崩溃恢复信号处理器
    @param AResetSequence 终端复位 ANSI 序列（退出 alt screen + 显光标 +
      关鼠标上报）；空串则仅注册 handler、不写终端
    @return True 全部信号安装成功；False 任一安装失败（保持既有处理器不变） *}
function platform_crash_install_handlers(const AResetSequence: string): Boolean;

implementation

{$IFDEF unix}

uses
  BaseUnix;

const
  MAX_RESET_LEN = 64;

var
  GResetBuf: array[0..MAX_RESET_LEN - 1] of AnsiChar;
  GResetLen: SizeInt = 0;

procedure CrashResetHandler(ASig: cint); cdecl;
begin
  { 崩溃恢复尽力而为：不查 FpWrite 返回值；SA_RESETHAND 保证二次
    信号走默认行为直接终止。 }
  if GResetLen > 0 then
    FpWrite(1, @GResetBuf[0], GResetLen);
  Halt(128 + ASig);
end;

function platform_crash_install_handlers(const AResetSequence: string): Boolean;
var
  LAct, LIgnAct: SigActionRec;
  LCopyLen: Integer;
begin
  Result := False;
  { 固化复位串到静态缓冲（handler 读全局指针会碰堆引用计数，不安全） }
  LCopyLen := Length(AResetSequence);
  if LCopyLen > MAX_RESET_LEN then
    LCopyLen := MAX_RESET_LEN;
  if LCopyLen > 0 then
    Move(AResetSequence[1], GResetBuf[0], LCopyLen);
  GResetLen := LCopyLen;

  FillChar(LAct, SizeOf(LAct), 0);
  LAct.sa_handler := SigActionHandler(@CrashResetHandler);
  FpSigEmptySet(LAct.sa_mask);
  LAct.sa_flags := SA_RESETHAND;
  if (FpSigAction(SIGSEGV, @LAct, nil) <> 0) or
     (FpSigAction(SIGTERM, @LAct, nil) <> 0) or
     (FpSigAction(SIGABRT, @LAct, nil) <> 0) or
     (FpSigAction(SIGBUS, @LAct, nil) <> 0) then
    Exit;

  FillChar(LIgnAct, SizeOf(LIgnAct), 0);
  LIgnAct.sa_handler := SigActionHandler(SIG_IGN);
  FpSigEmptySet(LIgnAct.sa_mask);
  if FpSigAction(SIGPIPE, @LIgnAct, nil) <> 0 then
    Exit;

  Result := True;
end;

{$ELSE}

function platform_crash_install_handlers(const AResetSequence: string): Boolean;
begin
  { 非 unix：无 POSIX 信号模型，空实现保持引用方可无条件编译 }
  Result := True;
end;

{$ENDIF}

end.