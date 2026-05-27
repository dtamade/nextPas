program test_platform_sync_posix_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  SYNC_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.sync.base.pas';
  SYNC_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.sync.base.pas';
  SYNC_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.sync.pas';
  SYNC_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.sync.pas';
  LINUX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.ffi.pas';
  LINUX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.ffi.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.ffi.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.ffi.pas';
  ANDROID_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.ffi.pas';
  ANDROID_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.ffi.pas';
  FREEBSD_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.ffi.pas';
  FREEBSD_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.ffi.pas';
  UNIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.unix.ffi.pas';
  UNIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.unix.ffi.pas';
  WINDOWS_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.ffi.pas';
  WINDOWS_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.ffi.pas';
  SYNC_BEHAVIOR_TEST_PATH_FROM_TEST = '../test_platform_sync/test_platform_sync.lpr';
  SYNC_BEHAVIOR_TEST_PATH_FROM_ROOT = 'core/tests/nextpas.core.platform.sync/test_platform_sync/test_platform_sync.lpr';

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

function ResolveSourcePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

procedure CheckTokenPresent(const ASource: string; const AToken: string; const AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckTokenAbsent(const ASource: string; const AToken: string; const AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure CheckHostFfiDoesNotOwnWaitBucketPolicy(const ASource, AHostName: string);
begin
  CheckTokenAbsent(ASource, 'posix_wait_bucket_count',
    AHostName + ' ffi must not own platform.sync wait-bucket policy');
  CheckTokenAbsent(ASource, 'tposixwaitbucket',
    AHostName + ' ffi must not own platform.sync wait-bucket state');
  CheckTokenAbsent(ASource, 'platform_posix_wait_address_fallback',
    AHostName + ' ffi must not own platform.sync POSIX wait-address fallback');
  CheckTokenAbsent(ASource, 'platform_posix_wait_address_released',
    AHostName + ' ffi must not own platform.sync wait-bucket release policy');
end;

procedure TestSyncExposesGenericPosixSurface;
var
  LSource: string;
  LBaseSource: string;
  LBehaviorTestSource: string;
begin
  LSource := ReadSourceFile(ResolveSyncSourcePath);
  LBaseSource := ReadSourceFile(ResolveSourcePath(SYNC_BASE_SOURCE_PATH_FROM_TEST, SYNC_BASE_SOURCE_PATH_FROM_ROOT));
  LBehaviorTestSource := ReadSourceFile(
    ResolveSourcePath(SYNC_BEHAVIOR_TEST_PATH_FROM_TEST, SYNC_BEHAVIOR_TEST_PATH_FROM_ROOT));
  CheckTokenPresent(LSource, 'nextpas_platform_sync_force_posix_wait_fallback',
    'platform.sync must expose a force selector for host-side POSIX fallback verification');
  CheckTokenPresent(LSource, 'nextpas_unix',
    'platform.sync must expose a generic Unix branch beyond Linux-only sync support');
  CheckTokenPresent(LSource, 'posix_wait_bucket_count',
    'platform.sync must declare a POSIX wait bucket fallback for address-wait emulation');
  CheckTokenPresent(LSource, 'platform_posix_wait_address_released',
    'platform.sync must own the wait-bucket release predicate instead of hiding policy inside host ffi');
  CheckTokenPresent(LBaseSource, 'platform_mutex_size   = platform_pthread_mutex_size',
    'platform.sync.base must derive POSIX mutex storage from the host pthread base owner token');
  CheckTokenPresent(LBaseSource, 'platform_rwlock_size  = platform_pthread_rwlock_size',
    'platform.sync.base must derive POSIX rwlock storage from the host pthread base owner token');
  CheckTokenPresent(LBaseSource, 'platform_condvar_size = platform_pthread_condvar_size',
    'platform.sync.base must derive POSIX condvar storage from the host pthread base owner token');
  CheckTokenPresent(LBaseSource, 'platform_mutex_size   = platform_windows_mutex_size',
    'platform.sync.base must derive Windows mutex storage from the windows base owner token');
  CheckTokenPresent(LBaseSource, 'platform_rwlock_size  = platform_windows_rwlock_size',
    'platform.sync.base must derive Windows rwlock storage from the windows base owner token');
  CheckTokenPresent(LBaseSource, 'platform_condvar_size = platform_windows_condvar_size',
    'platform.sync.base must derive Windows condvar storage from the windows base owner token');
  CheckTokenPresent(LBehaviorTestSource, 'platform_wait_address32(nil',
    'platform.sync behavior tests must cover nil wait-address public API');
  CheckTokenPresent(LBehaviorTestSource, 'platform_wake_address_one(nil',
    'platform.sync behavior tests must cover nil wake-one public API');
  CheckTokenPresent(LBehaviorTestSource, 'platform_wake_address_all(nil',
    'platform.sync behavior tests must cover nil wake-all public API');
  CheckHostFfiDoesNotOwnWaitBucketPolicy(
    ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT)),
    'linux');
  CheckHostFfiDoesNotOwnWaitBucketPolicy(
    ReadSourceFile(ResolveSourcePath(DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT)),
    'darwin');
  CheckHostFfiDoesNotOwnWaitBucketPolicy(
    ReadSourceFile(ResolveSourcePath(ANDROID_FFI_SOURCE_PATH_FROM_TEST, ANDROID_FFI_SOURCE_PATH_FROM_ROOT)),
    'android');
  CheckHostFfiDoesNotOwnWaitBucketPolicy(
    ReadSourceFile(ResolveSourcePath(FREEBSD_FFI_SOURCE_PATH_FROM_TEST, FREEBSD_FFI_SOURCE_PATH_FROM_ROOT)),
    'freebsd');
  CheckHostFfiDoesNotOwnWaitBucketPolicy(
    ReadSourceFile(ResolveSourcePath(UNIX_FFI_SOURCE_PATH_FROM_TEST, UNIX_FFI_SOURCE_PATH_FROM_ROOT)),
    'unix');
  CheckHostFfiDoesNotOwnWaitBucketPolicy(
    ReadSourceFile(ResolveSourcePath(WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT)),
    'windows');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.posix_surface');
  T.Run('platform.sync exposes generic POSIX surface', @TestSyncExposesGenericPosixSurface);
  T.Summary;
end.
