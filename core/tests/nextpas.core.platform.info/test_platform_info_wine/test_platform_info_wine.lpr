program test_platform_info_wine;

{ Wine runtime evidence for platform.info on Windows. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.platform.info,
  nextpas.core.platform.base;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

{ 1. CurrentOS returns Windows }
procedure TestCurrentOS;
begin
  Check(CurrentOS = TOSKind.osWindows, 'CurrentOS should be Windows');
end;

{ 2. CurrentCPU is x86_64 on Wine }
procedure TestCurrentCPU;
begin
  Check(CurrentCPU = TCPUArch.cpuX86_64, 'CurrentCPU should be x86_64');
end;

{ 3. CurrentEndian is little-endian }
procedure TestCurrentEndian;
begin
  Check(CurrentEndian = TEndianness.endLittle, 'CurrentEndian should be little');
end;

{ 4. OSName returns non-empty string }
procedure TestOSName;
var
  LName: string;
begin
  LName := OSName;
  Check(Length(LName) > 0, 'OSName should not be empty');
end;

{ 5. CPUName returns non-empty string }
procedure TestCPUName;
var
  LName: string;
begin
  LName := CPUName;
  Check(Length(LName) > 0, 'CPUName should not be empty');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.platform.info.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Test('CurrentOS is Windows', @TestCurrentOS);
  T.Test('CurrentCPU is x86_64', @TestCurrentCPU);
  T.Test('CurrentEndian is little', @TestCurrentEndian);
  T.Test('OSName not empty', @TestOSName);
  T.Test('CPUName not empty', @TestCPUName);
  {$ELSE}
  T.Test('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  if not T.Run then Halt(1);
end.
