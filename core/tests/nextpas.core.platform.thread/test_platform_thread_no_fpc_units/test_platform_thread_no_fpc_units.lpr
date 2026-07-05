program test_platform_thread_no_fpc_units;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.test;

const
  THREAD_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.thread.base.pas';
  THREAD_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.thread.base.pas';
  THREAD_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.thread.pas';
  THREAD_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.thread.pas';

var
  T: TTestSuite;

function ReadSourceFile(const APath: string): string;
begin
  Result := LowerCase(FsReadFileText(APath));
end;

procedure CheckTokenAbsent(const ASource, AToken: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, 'platform.thread must not reference FPC unit/token: ' + AToken);
end;

function ResolveSourcePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

procedure CheckNoFpcPlatformTokens(const ASource: string);
begin
  CheckTokenAbsent(ASource, 'BaseUnix');
  CheckTokenAbsent(ASource, 'UnixType');
  CheckTokenAbsent(ASource, 'TThreadID(');
  CheckTokenAbsent(ASource, 'FpNanoSleep');
  CheckTokenAbsent(ASource, ': THandle');
  CheckTokenAbsent(ASource, ': TSystemInfo');
  CheckTokenAbsent(ASource, '@AProc');
  CheckTokenAbsent(ASource, '  PThreads;');
  CheckTokenAbsent(ASource, '  PThreads,');
  CheckTokenAbsent(ASource, '  Linux;');
  CheckTokenAbsent(ASource, '  Linux,');
  CheckTokenAbsent(ASource, '  Windows;');
  CheckTokenAbsent(ASource, '  Windows,');
end;

procedure TestNoFpcPlatformUnits;
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolveSourcePath(THREAD_SOURCE_PATH_FROM_TEST, THREAD_SOURCE_PATH_FROM_ROOT));
  CheckNoFpcPlatformTokens(LSource);
end;

procedure TestBaseNoFpcPlatformUnits;
var
  LSourcePath: string;
  LSource: string;
begin
  LSourcePath := ResolveSourcePath(THREAD_BASE_SOURCE_PATH_FROM_TEST, THREAD_BASE_SOURCE_PATH_FROM_ROOT);
  Check(FileExists(LSourcePath), 'platform.thread.base source must exist for no-FPC guard: ' + LSourcePath);
  LSource := ReadSourceFile(LSourcePath);
  CheckNoFpcPlatformTokens(LSource);
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.thread.no_fpc_units');
  T.Test('No FPC platform units', @TestNoFpcPlatformUnits);
  T.Test('Base has no FPC platform units', @TestBaseNoFpcPlatformUnits);
  if not T.Run then Halt(1);
end.
