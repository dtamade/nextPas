program test_platform_info;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.base,
  nextpas.core.platform.info,
  nextpas.core.testing;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.platform.info');
  T.Run('CurrentOS', @TestCurrentOS);
  T.Run('CurrentCPU', @TestCurrentCPU);
  T.Run('Endianness', @TestEndian);
  T.Run('OSName', @TestOSName);
  T.Run('CPUName', @TestCPUName);
  T.Summary;
end.
