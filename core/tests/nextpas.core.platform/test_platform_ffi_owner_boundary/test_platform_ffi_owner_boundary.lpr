program test_platform_ffi_owner_boundary;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  SOURCE_DIR_FROM_TEST = '../../../src';
  SOURCE_DIR_FROM_ROOT = 'core/src';
  PLATFORM_TIME_HELPERS_TEST_FROM_TEST = '../../nextpas.core.platform.time/test_platform_time_helpers/test_platform_time_helpers.lpr';
  PLATFORM_TIME_HELPERS_TEST_FROM_ROOT = 'core/tests/nextpas.core.platform.time/test_platform_time_helpers/test_platform_time_helpers.lpr';
  PLATFORM_SYNC_BEHAVIOR_TEST_FROM_TEST = '../../nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr';
  PLATFORM_SYNC_BEHAVIOR_TEST_FROM_ROOT = 'core/tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr';
  PLATFORM_THREAD_BEHAVIOR_TEST_FROM_TEST = '../../nextpas.core.platform.thread/test_platform_thread/test_platform_thread.lpr';
  PLATFORM_THREAD_BEHAVIOR_TEST_FROM_ROOT = 'core/tests/nextpas.core.platform.thread/test_platform_thread/test_platform_thread.lpr';

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

function ResolveSourceDir: string;
begin
  if DirectoryExists(SOURCE_DIR_FROM_TEST) then
    Exit(SOURCE_DIR_FROM_TEST);
  if DirectoryExists(SOURCE_DIR_FROM_ROOT) then
    Exit(SOURCE_DIR_FROM_ROOT);
  Result := SOURCE_DIR_FROM_TEST;
end;

function ResolvePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

procedure CheckTokenPresent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckTokenAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure CheckNoSyntheticHostPrefixedRawNames(
  const ASource,
  AFileName: string);
begin
  if AFileName = 'nextpas.core.platform.linux.ffi.pas' then
  begin
    CheckTokenAbsent(ASource, 'function linux_',
      'linux.ffi raw declarations must not repeat the host prefix');
    CheckTokenAbsent(ASource, 'procedure linux_',
      'linux.ffi raw declarations must not repeat the host prefix');
  end
  else if AFileName = 'nextpas.core.platform.android.ffi.pas' then
  begin
    CheckTokenAbsent(ASource, 'function android_',
      'android.ffi raw declarations must not repeat the host prefix');
    CheckTokenAbsent(ASource, 'procedure android_',
      'android.ffi raw declarations must not repeat the host prefix');
  end
  else if AFileName = 'nextpas.core.platform.darwin.ffi.pas' then
  begin
    CheckTokenAbsent(ASource, 'function darwin_',
      'darwin.ffi raw declarations must not repeat the host prefix');
    CheckTokenAbsent(ASource, 'procedure darwin_',
      'darwin.ffi raw declarations must not repeat the host prefix');
  end
  else if AFileName = 'nextpas.core.platform.freebsd.ffi.pas' then
  begin
    CheckTokenAbsent(ASource, 'function freebsd_',
      'freebsd.ffi raw declarations must not repeat the host prefix');
    CheckTokenAbsent(ASource, 'procedure freebsd_',
      'freebsd.ffi raw declarations must not repeat the host prefix');
  end
  else if AFileName = 'nextpas.core.platform.unix.ffi.pas' then
  begin
    CheckTokenAbsent(ASource, 'function unix_',
      'unix.ffi raw declarations must not repeat the host prefix');
    CheckTokenAbsent(ASource, 'procedure unix_',
      'unix.ffi raw declarations must not repeat the host prefix');
  end;
end;

procedure CheckBehaviorTestHasNoHostFFI(const APath, AName: string);
var
  LSource: string;
begin
  LSource := ReadSourceFile(APath);
  CheckTokenAbsent(LSource, 'nextpas.core.platform.posix.ffi',
    AName + ' behavior test must not import shared POSIX ffi');
  CheckTokenAbsent(LSource, 'nextpas.core.platform.linux.ffi',
    AName + ' behavior test must not import Linux ffi');
  CheckTokenAbsent(LSource, 'nextpas.core.platform.darwin.ffi',
    AName + ' behavior test must not import Darwin ffi');
  CheckTokenAbsent(LSource, 'nextpas.core.platform.android.ffi',
    AName + ' behavior test must not import Android ffi');
  CheckTokenAbsent(LSource, 'nextpas.core.platform.freebsd.ffi',
    AName + ' behavior test must not import FreeBSD ffi');
  CheckTokenAbsent(LSource, 'nextpas.core.platform.unix.ffi',
    AName + ' behavior test must not import generic Unix ffi');
  CheckTokenAbsent(LSource, 'nextpas.core.platform.windows.ffi',
    AName + ' behavior test must not import Windows ffi');
  CheckTokenAbsent(LSource, 'pthread_create(',
    AName + ' behavior test must not create threads through raw pthread');
  CheckTokenAbsent(LSource, 'pthread_join(',
    AName + ' behavior test must not join threads through raw pthread');
  CheckTokenAbsent(LSource, 'gettid',
    AName + ' behavior test must not use raw native thread-id syscall as oracle');
end;

procedure TestPlatformFFIOwnerBoundary;
var
  LSearch: TSearchRec;
  LSourceDir: string;
  LPath: string;
  LFileName: string;
  LSource: string;
  LFoundPlatform: Boolean;
  LFoundPlatformBase: Boolean;
  LFoundPlatformInfo: Boolean;
  LFoundPlatformTime: Boolean;
  LFoundPlatformTimeBase: Boolean;
  LFoundPlatformTimeHost: Boolean;
  LFoundPlatformThread: Boolean;
  LFoundPlatformThreadBase: Boolean;
  LFoundPlatformSync: Boolean;
  LFoundPlatformSyncBase: Boolean;
  LFoundPosixBase: Boolean;
  LFoundPosixFfi: Boolean;
  LFoundPosixMath: Boolean;
  LFoundLinuxBase: Boolean;
  LFoundLinuxFfi: Boolean;
  LFoundDarwinBase: Boolean;
  LFoundDarwinFfi: Boolean;
  LFoundAndroidBase: Boolean;
  LFoundAndroidFfi: Boolean;
  LFoundFreeBSDBase: Boolean;
  LFoundFreeBSDFfi: Boolean;
  LFoundUnixBase: Boolean;
  LFoundUnixFfi: Boolean;
  LFoundWindowsBase: Boolean;
  LFoundWindowsFfi: Boolean;
  LNonFfiCount: Integer;
  LFfiCount: Integer;
begin
  LSourceDir := ResolveSourceDir;
  LFoundPlatform := False;
  LFoundPlatformBase := False;
  LFoundPlatformInfo := False;
  LFoundPlatformTime := False;
  LFoundPlatformTimeBase := False;
  LFoundPlatformTimeHost := False;
  LFoundPlatformThread := False;
  LFoundPlatformThreadBase := False;
  LFoundPlatformSync := False;
  LFoundPlatformSyncBase := False;
  LFoundPosixBase := False;
  LFoundPosixFfi := False;
  LFoundPosixMath := False;
  LFoundLinuxBase := False;
  LFoundLinuxFfi := False;
  LFoundDarwinBase := False;
  LFoundDarwinFfi := False;
  LFoundAndroidBase := False;
  LFoundAndroidFfi := False;
  LFoundFreeBSDBase := False;
  LFoundFreeBSDFfi := False;
  LFoundUnixBase := False;
  LFoundUnixFfi := False;
  LFoundWindowsBase := False;
  LFoundWindowsFfi := False;
  LNonFfiCount := 0;
  LFfiCount := 0;

  Check(FindFirst(IncludeTrailingPathDelimiter(LSourceDir) + 'nextpas.core.platform*.pas', faAnyFile, LSearch) = 0,
    'platform source audit must locate nextpas.core.platform*.pas under: ' + LSourceDir);
  try
    repeat
      if (LSearch.Attr and faDirectory) <> 0 then
        Continue;

      LFileName := LowerCase(LSearch.Name);
      LPath := IncludeTrailingPathDelimiter(LSourceDir) + LSearch.Name;

      if LFileName = 'nextpas.core.platform.sync.windows.ffi.pas' then
        Check(False, 'platform ffi must stay host-owned, not module-split: ' + LSearch.Name);

      if LFileName = 'nextpas.core.platform.pas' then
        LFoundPlatform := True
      else if LFileName = 'nextpas.core.platform.base.pas' then
        LFoundPlatformBase := True
      else if LFileName = 'nextpas.core.platform.info.pas' then
        LFoundPlatformInfo := True
      else if LFileName = 'nextpas.core.platform.time.pas' then
        LFoundPlatformTime := True
      else if LFileName = 'nextpas.core.platform.time.base.pas' then
        LFoundPlatformTimeBase := True
      else if LFileName = 'nextpas.core.platform.time.host.pas' then
        LFoundPlatformTimeHost := True
      else if LFileName = 'nextpas.core.platform.thread.pas' then
        LFoundPlatformThread := True
      else if LFileName = 'nextpas.core.platform.thread.base.pas' then
        LFoundPlatformThreadBase := True
      else if LFileName = 'nextpas.core.platform.sync.pas' then
        LFoundPlatformSync := True
      else if LFileName = 'nextpas.core.platform.sync.base.pas' then
        LFoundPlatformSyncBase := True
      else if LFileName = 'nextpas.core.platform.posix.base.pas' then
        LFoundPosixBase := True
      else if LFileName = 'nextpas.core.platform.posix.ffi.pas' then
        LFoundPosixFfi := True
      else if LFileName = 'nextpas.core.platform.posix.math.pas' then
        LFoundPosixMath := True
      else if LFileName = 'nextpas.core.platform.linux.base.pas' then
        LFoundLinuxBase := True
      else if LFileName = 'nextpas.core.platform.linux.ffi.pas' then
        LFoundLinuxFfi := True
      else if LFileName = 'nextpas.core.platform.darwin.base.pas' then
        LFoundDarwinBase := True
      else if LFileName = 'nextpas.core.platform.darwin.ffi.pas' then
        LFoundDarwinFfi := True
      else if LFileName = 'nextpas.core.platform.android.base.pas' then
        LFoundAndroidBase := True
      else if LFileName = 'nextpas.core.platform.android.ffi.pas' then
        LFoundAndroidFfi := True
      else if LFileName = 'nextpas.core.platform.freebsd.base.pas' then
        LFoundFreeBSDBase := True
      else if LFileName = 'nextpas.core.platform.freebsd.ffi.pas' then
        LFoundFreeBSDFfi := True
      else if LFileName = 'nextpas.core.platform.unix.base.pas' then
        LFoundUnixBase := True
      else if LFileName = 'nextpas.core.platform.unix.ffi.pas' then
        LFoundUnixFfi := True
      else if LFileName = 'nextpas.core.platform.windows.base.pas' then
        LFoundWindowsBase := True
      else if LFileName = 'nextpas.core.platform.windows.ffi.pas' then
        LFoundWindowsFfi := True;

      LSource := ReadSourceFile(LPath);
      if Pos('.ffi.pas', LFileName) > 0 then
      begin
        Inc(LFfiCount);
        CheckTokenPresent(LSource, 'external ''',
          'platform ffi unit must own external declarations: ' + LSearch.Name);
        CheckTokenAbsent(LSource, ' inline',
          'platform ffi unit must not contain inline helper declarations or implementations: ' + LSearch.Name);
        CheckTokenAbsent(LSource, 'implementation' + #10 + 'uses',
          'platform ffi unit implementation must not import helper dependencies: ' + LSearch.Name);
        CheckTokenAbsent(LSource, 'begin' + #10,
          'platform ffi unit must stay raw ABI declarations only, without helper bodies: ' + LSearch.Name);
        CheckNoSyntheticHostPrefixedRawNames(LSource, LFileName);
      end
      else
      begin
        Inc(LNonFfiCount);
        CheckTokenAbsent(LSource, 'external ''',
          'non-ffi platform unit must not declare external ABI directly: ' + LSearch.Name);
      end;
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;

  Check(LNonFfiCount >= 19, 'platform source audit must see the core non-ffi units, host base units, feature base units, and helper-only math units');
  Check(LFfiCount >= 7, 'platform source audit must see the host/shared ffi owner units');

  Check(LFoundPlatform, 'platform source audit must include nextpas.core.platform.pas');
  Check(LFoundPlatformBase, 'platform source audit must include nextpas.core.platform.base.pas');
  Check(LFoundPlatformInfo, 'platform source audit must include nextpas.core.platform.info.pas');
  Check(LFoundPlatformTime, 'platform source audit must include nextpas.core.platform.time.pas');
  Check(LFoundPlatformTimeBase, 'platform source audit must include nextpas.core.platform.time.base.pas');
  Check(LFoundPlatformTimeHost, 'platform source audit must include nextpas.core.platform.time.host.pas');
  Check(LFoundPlatformThread, 'platform source audit must include nextpas.core.platform.thread.pas');
  Check(LFoundPlatformThreadBase, 'platform source audit must include nextpas.core.platform.thread.base.pas');
  Check(LFoundPlatformSync, 'platform source audit must include nextpas.core.platform.sync.pas');
  Check(LFoundPlatformSyncBase, 'platform source audit must include nextpas.core.platform.sync.base.pas');
  Check(LFoundPosixBase, 'platform source audit must include nextpas.core.platform.posix.base.pas');
  Check(LFoundPosixFfi, 'platform source audit must include nextpas.core.platform.posix.ffi.pas');
  Check(LFoundPosixMath, 'platform source audit must include nextpas.core.platform.posix.math.pas');
  Check(LFoundLinuxBase, 'platform source audit must include nextpas.core.platform.linux.base.pas');
  Check(LFoundLinuxFfi, 'platform source audit must include nextpas.core.platform.linux.ffi.pas');
  Check(LFoundDarwinBase, 'platform source audit must include nextpas.core.platform.darwin.base.pas');
  Check(LFoundDarwinFfi, 'platform source audit must include nextpas.core.platform.darwin.ffi.pas');
  Check(LFoundAndroidBase, 'platform source audit must include nextpas.core.platform.android.base.pas');
  Check(LFoundAndroidFfi, 'platform source audit must include nextpas.core.platform.android.ffi.pas');
  Check(LFoundFreeBSDBase, 'platform source audit must include nextpas.core.platform.freebsd.base.pas');
  Check(LFoundFreeBSDFfi, 'platform source audit must include nextpas.core.platform.freebsd.ffi.pas');
  Check(LFoundUnixBase, 'platform source audit must include nextpas.core.platform.unix.base.pas');
  Check(LFoundUnixFfi, 'platform source audit must include nextpas.core.platform.unix.ffi.pas');
  Check(LFoundWindowsBase, 'platform source audit must include nextpas.core.platform.windows.base.pas');
  Check(LFoundWindowsFfi, 'platform source audit must include nextpas.core.platform.windows.ffi.pas');
end;

procedure TestPlatformBehaviorTestsStayOnAbstractAPI;
begin
  CheckBehaviorTestHasNoHostFFI(
    ResolvePath(PLATFORM_TIME_HELPERS_TEST_FROM_TEST, PLATFORM_TIME_HELPERS_TEST_FROM_ROOT),
    'platform.time');
  CheckBehaviorTestHasNoHostFFI(
    ResolvePath(PLATFORM_SYNC_BEHAVIOR_TEST_FROM_TEST, PLATFORM_SYNC_BEHAVIOR_TEST_FROM_ROOT),
    'platform.sync');
  CheckBehaviorTestHasNoHostFFI(
    ResolvePath(PLATFORM_THREAD_BEHAVIOR_TEST_FROM_TEST, PLATFORM_THREAD_BEHAVIOR_TEST_FROM_ROOT),
    'platform.thread');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.ffi_owner_boundary');
  T.Run('platform ffi ownership stays in ffi units', @TestPlatformFFIOwnerBoundary);
  T.Run('platform behavior tests stay on abstract APIs', @TestPlatformBehaviorTestsStayOnAbstractAPI);
  T.Summary;
end.
