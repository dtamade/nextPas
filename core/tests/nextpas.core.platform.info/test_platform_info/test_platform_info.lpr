program test_platform_info;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.base,
  nextpas.core.platform.info,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestCurrentOS;
begin
{$IFDEF NEXTPAS_LINUX}
  Check(CurrentOS = osLinux, 'CurrentOS = osLinux');
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  Check(CurrentOS = osMacOS, 'CurrentOS = osMacOS');
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  Check(CurrentOS = osFreeBSD, 'CurrentOS = osFreeBSD');
{$ENDIF}
  Check(CurrentOS <> osUnknown, 'OS is known');
end;

procedure TestCurrentCPU;
begin
{$IFDEF NEXTPAS_X86_64}
  Check(CurrentCPU = cpuX86_64, 'CurrentCPU = cpuX86_64');
{$ENDIF}
{$IFDEF NEXTPAS_AARCH64}
  Check(CurrentCPU = cpuAArch64, 'CurrentCPU = cpuAArch64');
{$ENDIF}
  Check(CurrentCPU <> cpuUnknown, 'CPU is known');
end;

procedure TestEndian;
begin
  Check(CurrentEndian = endLittle, 'little endian');
end;

procedure TestOSName;
var
  S: string;
begin
  S := OSName;
  Check(Length(S) > 0, 'OSName not empty');
  Check(S <> 'Unknown', 'OSName is known');
end;

procedure TestCPUName;
var
  S: string;
begin
  S := CPUName;
  Check(Length(S) > 0, 'CPUName not empty');
  Check(S <> 'Unknown', 'CPUName is known');
end;

procedure TestOSNameMatchesCurrentOS;
var
  LName: string;
begin
  LName := OSName;
  case CurrentOS of
    osLinux: Check(LName = 'Linux', 'OSName matches Linux');
    osMacOS: Check(LName = 'macOS', 'OSName matches macOS');
    osFreeBSD: Check(LName = 'FreeBSD', 'OSName matches FreeBSD');
    osWindows: Check(LName = 'Windows', 'OSName matches Windows');
    osAndroid: Check(LName = 'Android', 'OSName matches Android');
    osUnix: Check(LName = 'Unix', 'OSName matches Unix');
  else
    Check(False, 'Unknown OS kind');
  end;
end;

procedure TestCPUNameMatchesCurrentCPU;
var
  LName: string;
begin
  LName := CPUName;
  case CurrentCPU of
    cpuX86_64: Check(LName = 'x86_64', 'CPUName matches x86_64');
    cpuAArch64: Check(LName = 'aarch64', 'CPUName matches aarch64');
    cpuRISCV64: Check(LName = 'riscv64', 'CPUName matches riscv64');
    cpuARM32: Check(LName = 'arm', 'CPUName matches arm');
    cpuUnknown: Check(LName = 'Unknown', 'CPUName matches Unknown');
  else
    Check(False, 'Unknown CPU arch');
  end;
end;

procedure TestOSAndCPUAreConstexpr;
begin
  { These are inline functions — verify they return consistent values across calls }
  Check(CurrentOS = CurrentOS, 'CurrentOS is stable');
  Check(CurrentCPU = CurrentCPU, 'CurrentCPU is stable');
  Check(CurrentEndian = CurrentEndian, 'CurrentEndian is stable');
end;

procedure TestOSNameNoEmpty;
var
  I: Int32;
  S: string;
begin
  S := OSName;
  for I := 1 to Length(S) do
    Check(S[I] <> #0, 'OSName has no embedded nulls');
end;

procedure TestCPUNameNoEmpty;
var
  I: Int32;
  S: string;
begin
  S := CPUName;
  for I := 1 to Length(S) do
    Check(S[I] <> #0, 'CPUName has no embedded nulls');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.info');
  T.Test('CurrentOS', @TestCurrentOS);
  T.Test('CurrentCPU', @TestCurrentCPU);
  T.Test('Endianness', @TestEndian);
  T.Test('OSName', @TestOSName);
  T.Test('CPUName', @TestCPUName);
  T.Test('OSName matches CurrentOS', @TestOSNameMatchesCurrentOS);
  T.Test('CPUName matches CurrentCPU', @TestCPUNameMatchesCurrentCPU);
  T.Test('OS/CPU/Endian are stable', @TestOSAndCPUAreConstexpr);
  T.Test('OSName has no embedded nulls', @TestOSNameNoEmpty);
  T.Test('CPUName has no embedded nulls', @TestCPUNameNoEmpty);
  if not T.Run then Halt(1);
end.
