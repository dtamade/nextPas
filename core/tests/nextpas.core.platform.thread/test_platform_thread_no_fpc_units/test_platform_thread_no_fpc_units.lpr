program test_platform_thread_no_fpc_units;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  THREAD_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.thread.base.pas';
  THREAD_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.thread.base.pas';
  THREAD_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.thread.pas';
  THREAD_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.thread.pas';

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
  T := TTestRunner.Create('nextpas.core.platform.thread.no_fpc_units');
  T.Run('No FPC platform units', @TestNoFpcPlatformUnits);
  T.Run('Base has no FPC platform units', @TestBaseNoFpcPlatformUnits);
  T.Summary;
end.
