program test_platform_sync_posix_surface;

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

procedure CheckTokenPresent(const ASource: string; const AToken: string; const AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure TestSyncExposesGenericPosixSurface;
var
  LSource: string;
begin
  LSource := ReadSourceFile(ResolveSyncSourcePath);
  CheckTokenPresent(LSource, 'nextpas_platform_sync_force_posix_wait_fallback',
    'platform.sync must expose a force selector for host-side POSIX fallback verification');
  CheckTokenPresent(LSource, 'nextpas_unix',
    'platform.sync must expose a generic Unix branch beyond Linux-only sync support');
  CheckTokenPresent(LSource, 'posix_wait_bucket_count',
    'platform.sync must declare a POSIX wait bucket fallback for address-wait emulation');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.posix_surface');
  T.Run('platform.sync exposes generic POSIX surface', @TestSyncExposesGenericPosixSurface);
  T.Summary;
end.
