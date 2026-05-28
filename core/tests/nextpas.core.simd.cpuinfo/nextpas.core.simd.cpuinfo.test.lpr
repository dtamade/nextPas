program nextpas.core.simd.cpuinfo.test;

{$mode objfpc}{$H+}
{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils,
  fpcunit, consoletestrunner, testregistry,
  nextpas.core.simd.cpuinfo.testcase,
  nextpas.core.simd.cpuinfo.lazy.testcase
  ;

var
  LApplication: TTestRunner;

begin
  DefaultFormat := fPlain;
  DefaultRunAllTests := True;

  {$IFDEF SIMD_RISCV_AVAILABLE}
  // RISC-V/qemu user-mode workaround: avoid teardown path that intermittently AVs
  // after successful execution in consoletestrunner.
  LApplication := TTestRunner.Create(nil);
  LApplication.Initialize;
  LApplication.Title := 'nextpas.core.simd.cpuinfo tests';
  LApplication.Run;
  Halt(ExitCode);
  {$ELSE}
  LApplication := TTestRunner.Create(nil);
  try
    LApplication.Initialize;
    LApplication.Title := 'nextpas.core.simd.cpuinfo tests';
    LApplication.Run;
  finally
    LApplication.Free;
  end;
  {$ENDIF}
end.
