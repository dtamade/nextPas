program test_platform_sync_no_fpc_units;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  SYNC_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.sync.base.pas';
  SYNC_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.sync.base.pas';
  SYNC_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.sync.pas';
  SYNC_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.sync.pas';

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

function ResolveSourcePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

procedure CheckTokenAbsent(const ALabel, ASource, AToken: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0,
    ALabel + ' must not reference FPC unit/token: ' + AToken);
end;

procedure CheckNoFpcPlatformUnits(const ALabel: string; const ASource: string);
begin
  CheckTokenAbsent(ALabel, ASource, 'BaseUnix');
  CheckTokenAbsent(ALabel, ASource, 'UnixType');
  CheckTokenAbsent(ALabel, ASource, 'PThreads');
  CheckTokenAbsent(ALabel, ASource, '  Syscall;');
  CheckTokenAbsent(ALabel, ASource, '  Syscall,');
  CheckTokenAbsent(ALabel, ASource, '  Linux;');
  CheckTokenAbsent(ALabel, ASource, '  Linux,');
  CheckTokenAbsent(ALabel, ASource, '  Windows;');
  CheckTokenAbsent(ALabel, ASource, '  Windows,');
  CheckTokenAbsent(ALabel, ASource, 'external ''c''');
  CheckTokenAbsent(ALabel, ASource, 'external ''kernel32''');
  CheckTokenAbsent(ALabel, ASource, 'nextpas.core.platform.sync.windows.ffi');
end;

procedure TestNoFpcPlatformUnits;
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolveSourcePath(SYNC_SOURCE_PATH_FROM_TEST, SYNC_SOURCE_PATH_FROM_ROOT));
  CheckNoFpcPlatformUnits('platform.sync', LSource);
end;

procedure TestBaseNoFpcPlatformUnits;
var
  LSource: string;
begin
  Check(FileExists(ResolveSourcePath(SYNC_BASE_SOURCE_PATH_FROM_TEST, SYNC_BASE_SOURCE_PATH_FROM_ROOT)),
    'platform.sync.base source must exist for no-FPC guard');
  LSource := ReadSourceFile(ResolveSourcePath(SYNC_BASE_SOURCE_PATH_FROM_TEST, SYNC_BASE_SOURCE_PATH_FROM_ROOT));
  CheckNoFpcPlatformUnits('platform.sync.base', LSource);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.no_fpc_units');
  T.Run('No FPC platform units', @TestNoFpcPlatformUnits);
  T.Run('Base no FPC platform units', @TestBaseNoFpcPlatformUnits);
  T.Summary;
end.
