program test_platform_thread_l0_boundary;

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
  Check(Pos(LowerCase(AToken), ASource) = 0, ALabel + ' must not reference L1 thread API token: ' + AToken);
end;

procedure CheckL0OnlySource(const ALabel: string; const APathFromTest: string; const APathFromRoot: string);
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolvePath(APathFromTest, APathFromRoot));
  CheckTokenAbsent(LSource, 'nextpas.core.thread', ALabel);
  CheckTokenAbsent(LSource, 'TThreadPool', ALabel);
  CheckTokenAbsent(LSource, 'ThreadPool', ALabel);
  CheckTokenAbsent(LSource, 'TChannel', ALabel);
  CheckTokenAbsent(LSource, 'Channel', ALabel);
  CheckTokenAbsent(LSource, 'Future', ALabel);
  CheckTokenAbsent(LSource, 'Scheduler', ALabel);
  CheckTokenAbsent(LSource, 'Task', ALabel);
end;

procedure TestPlatformThreadSourceStaysL0;
begin
  CheckL0OnlySource(
    'platform.thread source',
    '../../../src/nextpas.core.platform.thread.pas',
    'core/src/nextpas.core.platform.thread.pas');
end;

procedure TestPlatformThreadExampleStaysL0;
begin
  CheckL0OnlySource(
    'platform.thread example',
    '../../../examples/nextpas.core.platform.thread/platform_thread_lifecycle/platform_thread_lifecycle.lpr',
    'core/examples/nextpas.core.platform.thread/platform_thread_lifecycle/platform_thread_lifecycle.lpr');
end;

procedure TestPlatformThreadBenchmarkStaysL0;
begin
  CheckL0OnlySource(
    'platform.thread benchmark',
    '../../../benchmarks/nextpas.core.platform.thread/bench_platform_thread_lifecycle/bench_platform_thread_lifecycle.lpr',
    'core/benchmarks/nextpas.core.platform.thread/bench_platform_thread_lifecycle/bench_platform_thread_lifecycle.lpr');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.thread.l0_boundary');
  T.Run('platform.thread source stays L0', @TestPlatformThreadSourceStaysL0);
  T.Run('platform.thread example stays L0', @TestPlatformThreadExampleStaysL0);
  T.Run('platform.thread benchmark stays L0', @TestPlatformThreadBenchmarkStaysL0);
  T.Summary;
end.
