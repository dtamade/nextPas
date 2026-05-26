program test_platform_time_no_fpc_units;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  TIME_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.time.pas';
  TIME_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.time.pas';

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

function ResolveTimeSourcePath: string;
begin
  if FileExists(TIME_SOURCE_PATH_FROM_TEST) then
    Exit(TIME_SOURCE_PATH_FROM_TEST);
  if FileExists(TIME_SOURCE_PATH_FROM_ROOT) then
    Exit(TIME_SOURCE_PATH_FROM_ROOT);
  Result := TIME_SOURCE_PATH_FROM_TEST;
end;

procedure CheckTokenAbsent(const ASource, AToken: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, 'platform.time must not reference FPC unit/token: ' + AToken);
end;

procedure TestNoFpcPlatformUnits;
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolveTimeSourcePath);
  CheckTokenAbsent(LSource, 'BaseUnix');
  CheckTokenAbsent(LSource, 'UnixType');
  CheckTokenAbsent(LSource, 'PThreads');
  CheckTokenAbsent(LSource, 'Syscall');
  CheckTokenAbsent(LSource, '  Linux;');
  CheckTokenAbsent(LSource, '  Linux,');
  CheckTokenAbsent(LSource, '  Windows;');
  CheckTokenAbsent(LSource, '  Windows,');
  CheckTokenAbsent(LSource, 'external ''c''');
  CheckTokenAbsent(LSource, 'external ''kernel32''');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.time.no_fpc_units');
  T.Run('No FPC platform units', @TestNoFpcPlatformUnits);
  T.Summary;
end.
