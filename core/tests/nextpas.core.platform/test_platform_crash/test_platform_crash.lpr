program test_platform_crash;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.platform.crash
{$IFDEF unix}
  , BaseUnix
{$ENDIF}
  ;

var
  T: TTestSuite;

const
  RESET_SEQ = #27'[?1049l'#27'[?25h'#27'[?1003l'#27'[?1006l'#10;

procedure TestInstallReturnsTrue;
begin
  Check(platform_crash_install_handlers(RESET_SEQ),
    'install with reset sequence should succeed');
end;

procedure TestInstallIdempotent;
begin
  { 重复安装应幂等（先装再装都成功，不破坏既有处理器状态机） }
  Check(platform_crash_install_handlers(RESET_SEQ),
    'reinstall after first install should succeed');
end;

procedure TestEmptySequenceAllowed;
begin
  { 空复位串：仅注册 handler 不写终端（调用方不想复位时用） }
  Check(platform_crash_install_handlers(''),
    'install with empty sequence should succeed');
end;

{$IFDEF unix}
procedure TestTerminateExitCode;
var
  LPid: TPid;
  LStatus: cint;
begin
  { 子进程安装后自杀（SIGTERM=15）：handler 应写复位串并 Halt(128+15)=143。
    复位串用空串，避免子进程把序列写进测试 stdout 污染输出。 }
  LPid := FpFork;
  if LPid = 0 then
  begin
    if not platform_crash_install_handlers('') then
      Halt(99);
    FpKill(FpGetpid, SIGTERM);
    Halt(0);   { 不应到达：handler 已 Halt }
  end;
  Check(LPid > 0, 'fork should succeed');
  if LPid > 0 then
  begin
    FpWaitPid(LPid, @LStatus, 0);
    Check((LStatus shr 8) and $FF = 128 + 15,
      'terminated child should exit with 128+SIGTERM');
  end;
end;
{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.platform.crash');
  T.Test('install returns true', @TestInstallReturnsTrue);
  T.Test('reinstall is idempotent', @TestInstallIdempotent);
  T.Test('empty sequence allowed', @TestEmptySequenceAllowed);
{$IFDEF unix}
  T.Test('terminated child exits 128+SIGTERM', @TestTerminateExitCode);
{$ENDIF}
  if not T.Run then Halt(1);
end.