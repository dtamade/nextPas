program test_platform_thread_l0_boundary;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.test;

var
  T: TTestSuite;

function ReadSourceFile(const APath: string): string;
begin
  Result := LowerCase(FsReadFileText(APath));
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

procedure TestPlatformThreadBaseStaysL0;
begin
  CheckL0OnlySource(
    'platform.thread.base source',
    '../../../src/nextpas.core.platform.thread.base.pas',
    'core/src/nextpas.core.platform.thread.base.pas');
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
  T := TTestSuite.Create('nextpas.core.platform.thread.l0_boundary');
  T.Test('platform.thread source stays L0', @TestPlatformThreadSourceStaysL0);
  T.Test('platform.thread.base source stays L0', @TestPlatformThreadBaseStaysL0);
  T.Test('platform.thread example stays L0', @TestPlatformThreadExampleStaysL0);
  T.Test('platform.thread benchmark stays L0', @TestPlatformThreadBenchmarkStaysL0);
  if not T.Run then Halt(1);
end.
