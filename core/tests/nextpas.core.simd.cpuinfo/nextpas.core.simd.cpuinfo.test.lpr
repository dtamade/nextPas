program nextpas.core.simd.cpuinfo.test;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  nextpas.core.thread.init,
  {$ENDIF}
  Classes, SysUtils,
  fpcunit, consoletestrunner, testregistry,
  nextpas.core.simd.cpuinfo.testcase,
  nextpas.core.simd.cpuinfo.lazy.testcase
  ;

var
  LApplication: TSuiteRunner;

begin
  DefaultFormat := fPlain;
  DefaultRunAllTests := True;

  {$IFDEF SIMD_RISCV_AVAILABLE}
  // RISC-V/qemu user-mode workaround: avoid teardown path that intermittently AVs
  // after successful execution in consoletestrunner.
  LApplication := TSuiteRunner.Create(nil);
  LApplication.Initialize;
  LApplication.Title := 'nextpas.core.simd.cpuinfo tests';
  LApplication.Run;
  Halt(ExitCode);
  {$ELSE}
  LApplication := TSuiteRunner.Create(nil);
  try
    LApplication.Initialize;
    LApplication.Title := 'nextpas.core.simd.cpuinfo tests';
    LApplication.Run;
  finally
    LApplication.Free;
  end;
  {$ENDIF}
end.
