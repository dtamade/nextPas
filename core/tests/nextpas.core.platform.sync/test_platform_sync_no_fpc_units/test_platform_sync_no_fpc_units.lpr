program test_platform_sync_no_fpc_units;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
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

function ResolveSyncSourcePath: string;
begin
  if FileExists(SYNC_SOURCE_PATH_FROM_TEST) then
    Exit(SYNC_SOURCE_PATH_FROM_TEST);
  if FileExists(SYNC_SOURCE_PATH_FROM_ROOT) then
    Exit(SYNC_SOURCE_PATH_FROM_ROOT);
  Result := SYNC_SOURCE_PATH_FROM_TEST;
end;

procedure CheckTokenAbsent(const ASource, AToken: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, 'platform.sync must not reference FPC unit/token: ' + AToken);
end;

procedure TestNoFpcPlatformUnits;
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolveSyncSourcePath);
  CheckTokenAbsent(LSource, 'BaseUnix');
  CheckTokenAbsent(LSource, 'UnixType');
  CheckTokenAbsent(LSource, 'PThreads');
  CheckTokenAbsent(LSource, '  Syscall;');
  CheckTokenAbsent(LSource, '  Syscall,');
  CheckTokenAbsent(LSource, '  Linux;');
  CheckTokenAbsent(LSource, '  Linux,');
  CheckTokenAbsent(LSource, '  Windows;');
  CheckTokenAbsent(LSource, '  Windows,');
  CheckTokenAbsent(LSource, 'external ''c''');
  CheckTokenAbsent(LSource, 'external ''kernel32''');
  CheckTokenAbsent(LSource, 'nextpas.core.platform.sync.windows.ffi');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.no_fpc_units');
  T.Run('No FPC platform units', @TestNoFpcPlatformUnits);
  T.Summary;
end.
