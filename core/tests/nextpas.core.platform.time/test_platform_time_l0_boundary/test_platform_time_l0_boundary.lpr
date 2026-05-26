program test_platform_time_l0_boundary;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

var
  T: TTestRunner;

function ReadSourceFile(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LowerCase(LLine) + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolvePath(const APathFromTest: string; const APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

procedure CheckTokenAbsent(const ASource: string; const AToken: string; const ALabel: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, ALabel + ' must not reference L1 time API token: ' + AToken);
end;

procedure CheckL0OnlySource(const ALabel: string; const APathFromTest: string; const APathFromRoot: string);
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolvePath(APathFromTest, APathFromRoot));
  CheckTokenAbsent(LSource, 'nextpas.core.time', ALabel);
  CheckTokenAbsent(LSource, 'TStopwatch', ALabel);
  CheckTokenAbsent(LSource, 'Stopwatch', ALabel);
  CheckTokenAbsent(LSource, 'TDuration', ALabel);
  CheckTokenAbsent(LSource, 'Duration', ALabel);
  CheckTokenAbsent(LSource, 'TInstant', ALabel);
  CheckTokenAbsent(LSource, 'Instant', ALabel);
  CheckTokenAbsent(LSource, 'Timer', ALabel);
end;

procedure TestPlatformTimeSourceStaysL0;
begin
  CheckL0OnlySource(
    'platform.time source',
    '../../../src/nextpas.core.platform.time.pas',
    'core/src/nextpas.core.platform.time.pas');
end;

procedure TestPlatformTimeFacadeStaysL0;
begin
  CheckL0OnlySource(
    'platform facade',
    '../../../src/nextpas.core.platform.pas',
    'core/src/nextpas.core.platform.pas');
end;

procedure TestPlatformTimeExampleStaysL0;
begin
  CheckL0OnlySource(
    'platform.time example',
    '../../../examples/nextpas.core.platform.time/platform_time_clock/platform_time_clock.lpr',
    'core/examples/nextpas.core.platform.time/platform_time_clock/platform_time_clock.lpr');
end;

procedure TestPlatformTimeBenchmarkStaysL0;
begin
  CheckL0OnlySource(
    'platform.time benchmark',
    '../../../benchmarks/nextpas.core.platform.time/bench_platform_time_clock/bench_platform_time_clock.lpr',
    'core/benchmarks/nextpas.core.platform.time/bench_platform_time_clock/bench_platform_time_clock.lpr');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.time.l0_boundary');
  T.Run('platform.time source stays L0', @TestPlatformTimeSourceStaysL0);
  T.Run('platform facade stays L0', @TestPlatformTimeFacadeStaysL0);
  T.Run('platform.time example stays L0', @TestPlatformTimeExampleStaysL0);
  T.Run('platform.time benchmark stays L0', @TestPlatformTimeBenchmarkStaysL0);
  T.Summary;
end.
