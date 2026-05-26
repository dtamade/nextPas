program test_platform_thread_no_fpc_units;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  THREAD_SOURCE_PATH = '../../../src/nextpas.core.platform.thread.pas';

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

procedure TestNoFpcPlatformUnits;
var
  LSource: string;
begin
  LSource := ReadSourceFile(THREAD_SOURCE_PATH);
  CheckTokenAbsent(LSource, 'BaseUnix');
  CheckTokenAbsent(LSource, 'UnixType');
  CheckTokenAbsent(LSource, 'TThreadID(');
  CheckTokenAbsent(LSource, 'FpNanoSleep');
  CheckTokenAbsent(LSource, ': THandle');
  CheckTokenAbsent(LSource, ': TSystemInfo');
  CheckTokenAbsent(LSource, '@AProc');
  CheckTokenAbsent(LSource, '  PThreads;');
  CheckTokenAbsent(LSource, '  PThreads,');
  CheckTokenAbsent(LSource, '  Linux;');
  CheckTokenAbsent(LSource, '  Linux,');
  CheckTokenAbsent(LSource, '  Windows;');
  CheckTokenAbsent(LSource, '  Windows,');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.thread.no_fpc_units');
  T.Run('No FPC platform units', @TestNoFpcPlatformUnits);
  T.Summary;
end.
