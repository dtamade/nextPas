program test_platform;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform,
  nextpas.core.platform.base;

begin
  WriteLn('=== nextpas.core.platform tests ===');

  WriteLn('OS: ', OSName);
  WriteLn('CPU: ', CPUName);

  {$IFDEF LINUX}
  Assert(CurrentOS = osLinux, 'Should detect Linux');
  Assert(OSName = 'Linux');
  {$ENDIF}

  {$IFDEF CPUX86_64}
  Assert(CurrentCPU = cpuX86_64, 'Should detect x86_64');
  Assert(CPUName = 'x86_64');
  {$ENDIF}

  Assert(CurrentEndian = endLittle, 'Should be little-endian');

  WriteLn('PASS: all platform tests passed');
end.
