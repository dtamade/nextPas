program test_platform_sync_l0_boundary;

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
  Check(Pos(LowerCase(AToken), ASource) = 0, ALabel + ' must not reference L1 sync API token: ' + AToken);
end;

procedure CheckL0OnlySource(const ALabel: string; const APathFromTest: string; const APathFromRoot: string);
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolvePath(APathFromTest, APathFromRoot));
  CheckTokenAbsent(LSource, 'nextpas.core.sync', ALabel);
  CheckTokenAbsent(LSource, 'TMutex', ALabel);
  CheckTokenAbsent(LSource, 'TRWLock', ALabel);
  CheckTokenAbsent(LSource, 'TCondVar', ALabel);
  CheckTokenAbsent(LSource, 'TSemaphore', ALabel);
  CheckTokenAbsent(LSource, 'Semaphore', ALabel);
  CheckTokenAbsent(LSource, 'Monitor', ALabel);
end;

procedure TestPlatformSyncSourceStaysL0;
begin
  CheckL0OnlySource(
    'platform.sync source',
    '../../../src/nextpas.core.platform.sync.pas',
    'core/src/nextpas.core.platform.sync.pas');
end;

procedure TestPlatformSyncBaseStaysL0;
begin
  CheckL0OnlySource(
    'platform.sync.base source',
    '../../../src/nextpas.core.platform.sync.base.pas',
    'core/src/nextpas.core.platform.sync.base.pas');
end;

procedure TestPlatformSyncExampleStaysL0;
begin
  CheckL0OnlySource(
    'platform.sync example',
    '../../../examples/nextpas.core.platform.sync/platform_sync_basics/platform_sync_basics.lpr',
    'core/examples/nextpas.core.platform.sync/platform_sync_basics/platform_sync_basics.lpr');
end;

procedure TestPlatformSyncBenchmarkStaysL0;
begin
  CheckL0OnlySource(
    'platform.sync benchmark',
    '../../../benchmarks/nextpas.core.platform.sync/bench_platform_sync/bench_platform_sync.lpr',
    'core/benchmarks/nextpas.core.platform.sync/bench_platform_sync/bench_platform_sync.lpr');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.l0_boundary');
  T.Run('platform.sync source stays L0', @TestPlatformSyncSourceStaysL0);
  T.Run('platform.sync.base source stays L0', @TestPlatformSyncBaseStaysL0);
  T.Run('platform.sync example stays L0', @TestPlatformSyncExampleStaysL0);
  T.Run('platform.sync benchmark stays L0', @TestPlatformSyncBenchmarkStaysL0);
  T.Summary;
end.
