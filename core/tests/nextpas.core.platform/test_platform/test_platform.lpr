program test_platform;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform,
  nextpas.core.platform.base,
  nextpas.core.test;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('platform');

  LSuite.Test('OS detection', procedure begin
    {$IFDEF LINUX}
    CheckTrue(CurrentOS = osLinux, 'Should detect Linux');
    CheckEqual('Linux', OSName);
    {$ENDIF}
  end);

  LSuite.Test('CPU detection', procedure begin
    {$IFDEF CPUX86_64}
    CheckTrue(CurrentCPU = cpuX86_64, 'Should detect x86_64');
    CheckEqual('x86_64', CPUName);
    {$ENDIF}
  end);

  LSuite.Test('endianness', procedure begin
    CheckTrue(CurrentEndian = endLittle, 'Should be little-endian');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.platform');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then
    Halt(1);
end.
