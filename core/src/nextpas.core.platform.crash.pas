unit nextpas.core.platform.crash;

{**
 * nextpas.core.platform.crash - 崩溃信号恢复助手
 *
 * 场景：TUI 程序（gtd888/music888 同款需求）在 alt screen 中崩溃时，
 * 必须在退出前复位终端（退 alt screen / 显光标 / 关鼠标上报），否则
 * 终端残留花屏与隐藏光标。
 *
 * 策略：SIGSEGV/SIGTERM/SIGABRT/SIGBUS 安装复位性 handler（写复位序列
 * 后以 128+sig 退出，SA_RESETHAND 二次信号走默认终止），SIGPIPE 忽略。
 * handler 只做 write(2) + Halt，全程不碰堆分配/锁/异常路径
 * （async-signal-safe）；复位串在安装时拷入静态缓冲，安装后只读。
 * 信号安装经 nextpas.core.platform.signal（不直接依赖 BaseUnix）。
 *
 * 非 unix 平台为空实现，调用方可无条件编译。
 *}

{$I nextpas.core.settings.inc}

interface

{** @desc 安装崩溃恢复信号处理器
    @param AResetSequence 终端复位 ANSI 序列（退出 alt screen + 显光标 +
      关鼠标上报）；空串则仅注册 handler、不写终端
    @return True 全部信号安装成功；False 任一安装失败
      （已成功安装的信号不回滚，与既有行为一致） *}
function platform_crash_install_handlers(const AResetSequence: string): Boolean;

implementation

{$IFDEF unix}

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.signal;

const
  MAX_RESET_LEN = 64;

var
  GResetBuf: array[0..MAX_RESET_LEN - 1] of AnsiChar;
  GResetLen: SizeInt = 0;

procedure CrashResetHandler(ASig: Int32); cdecl;
begin
  { 崩溃恢复尽力而为：不查 write 返回值；安装旗标 PLATFORM_SA_RESETHAND
    保证二次信号走默认行为直接终止。write(2) 为 async-signal-safe。 }
  if GResetLen > 0 then
    write(TPlatformFileDescriptor(1), @GResetBuf[0], SizeUInt(GResetLen));
  Halt(128 + ASig);
end;

function platform_crash_install_handlers(const AResetSequence: string): Boolean;
var
  LCopyLen: Integer;
  LFail: Boolean;
begin
  Result := False;
  { 固化复位串到静态缓冲（handler 读全局指针会碰堆引用计数，不安全） }
  LCopyLen := Length(AResetSequence);
  if LCopyLen > MAX_RESET_LEN then
    LCopyLen := MAX_RESET_LEN;
  if LCopyLen > 0 then
    Move(AResetSequence[1], GResetBuf[0], LCopyLen);
  GResetLen := LCopyLen;

  { 崩溃族一次性 handler：RESETHAND 使二次信号走默认行为直接终止。
    逐个安装；任一失败置 LFail，已成功者不回滚。 }
  LFail := False;
  if platform_signal_set_flags(PLATFORM_SIGSEGV, @CrashResetHandler,
       PLATFORM_SA_RESETHAND) <> 0 then
    LFail := True;
  if platform_signal_set_flags(PLATFORM_SIGTERM, @CrashResetHandler,
       PLATFORM_SA_RESETHAND) <> 0 then
    LFail := True;
  if platform_signal_set_flags(PLATFORM_SIGABRT, @CrashResetHandler,
       PLATFORM_SA_RESETHAND) <> 0 then
    LFail := True;
  if platform_signal_set_flags(PLATFORM_SIGBUS, @CrashResetHandler,
       PLATFORM_SA_RESETHAND) <> 0 then
    LFail := True;

  { SIGPIPE 忽略：管道对端关闭不致进程终止 }
  if platform_signal_ignore(PLATFORM_SIGPIPE) <> 0 then
    LFail := True;

  Result := not LFail;
end;

{$ELSE}

function platform_crash_install_handlers(const AResetSequence: string): Boolean;
begin
  { 非 unix：无 POSIX 信号模型，空实现保持引用方可无条件编译 }
  Result := True;
end;

{$ENDIF}

end.