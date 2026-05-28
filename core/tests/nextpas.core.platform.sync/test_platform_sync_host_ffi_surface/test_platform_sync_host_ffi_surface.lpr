program test_platform_sync_host_ffi_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  SYNC_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.sync.base.pas';
  SYNC_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.sync.base.pas';
  SYNC_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.sync.pas';
  SYNC_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.sync.pas';
  POSIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';
  LINUX_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.base.pas';
  LINUX_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.base.pas';
  LINUX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.ffi.pas';
  LINUX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.ffi.pas';
  DARWIN_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.base.pas';
  DARWIN_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.base.pas';
  ANDROID_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.base.pas';
  ANDROID_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.base.pas';
  FREEBSD_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.base.pas';
  FREEBSD_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.base.pas';
  UNIX_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.unix.base.pas';
  UNIX_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.unix.base.pas';
  WINDOWS_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.base.pas';
  WINDOWS_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.base.pas';
  WINDOWS_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.ffi.pas';
  WINDOWS_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.ffi.pas';

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

procedure CheckTokenPresent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckTokenAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure CheckRawFFIUnit(const ASource, ALabel: string);
begin
  CheckTokenPresent(ASource, 'external ''',
    ALabel + ' must expose raw external declarations');
  CheckTokenAbsent(ASource, ' inline',
    ALabel + ' must not expose inline helpers');
  CheckTokenAbsent(ASource, 'begin' + #10,
    ALabel + ' must not contain helper bodies');
end;

procedure CheckPThreadStorageBase(const ASource, AHostLabel: string);
begin
  CheckTokenPresent(ASource, 'platform_pthread_mutex_size',
    AHostLabel + ' base must own pthread mutex storage size');
  CheckTokenPresent(ASource, 'platform_pthread_rwlock_size',
    AHostLabel + ' base must own pthread rwlock storage size');
  CheckTokenPresent(ASource, 'platform_pthread_condvar_size',
    AHostLabel + ' base must own pthread condvar storage size');
  CheckTokenPresent(ASource, 'platform_posix_etimedout',
    AHostLabel + ' base must own POSIX timeout error token');
end;

procedure TestPlatformSyncRawFFIBoundary;
var
  LSyncBaseSource: string;
  LSyncSource: string;
  LPosixFfiSource: string;
  LLinuxBaseSource: string;
  LLinuxFfiSource: string;
  LDarwinBaseSource: string;
  LAndroidBaseSource: string;
  LFreeBSDBaseSource: string;
  LUnixBaseSource: string;
  LWindowsBaseSource: string;
  LWindowsFfiSource: string;
begin
  LSyncBaseSource := ReadSourceFile(ResolveSourcePath(SYNC_BASE_SOURCE_PATH_FROM_TEST, SYNC_BASE_SOURCE_PATH_FROM_ROOT));
  LSyncSource := ReadSourceFile(ResolveSourcePath(SYNC_SOURCE_PATH_FROM_TEST, SYNC_SOURCE_PATH_FROM_ROOT));
  LPosixFfiSource := ReadSourceFile(ResolveSourcePath(POSIX_FFI_SOURCE_PATH_FROM_TEST, POSIX_FFI_SOURCE_PATH_FROM_ROOT));
  LLinuxBaseSource := ReadSourceFile(ResolveSourcePath(LINUX_BASE_SOURCE_PATH_FROM_TEST, LINUX_BASE_SOURCE_PATH_FROM_ROOT));
  LLinuxFfiSource := ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT));
  LDarwinBaseSource := ReadSourceFile(ResolveSourcePath(DARWIN_BASE_SOURCE_PATH_FROM_TEST, DARWIN_BASE_SOURCE_PATH_FROM_ROOT));
  LAndroidBaseSource := ReadSourceFile(ResolveSourcePath(ANDROID_BASE_SOURCE_PATH_FROM_TEST, ANDROID_BASE_SOURCE_PATH_FROM_ROOT));
  LFreeBSDBaseSource := ReadSourceFile(ResolveSourcePath(FREEBSD_BASE_SOURCE_PATH_FROM_TEST, FREEBSD_BASE_SOURCE_PATH_FROM_ROOT));
  LUnixBaseSource := ReadSourceFile(ResolveSourcePath(UNIX_BASE_SOURCE_PATH_FROM_TEST, UNIX_BASE_SOURCE_PATH_FROM_ROOT));
  LWindowsBaseSource := ReadSourceFile(ResolveSourcePath(WINDOWS_BASE_SOURCE_PATH_FROM_TEST, WINDOWS_BASE_SOURCE_PATH_FROM_ROOT));
  LWindowsFfiSource := ReadSourceFile(ResolveSourcePath(WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LSyncBaseSource, 'tplatformmutex = record',
    'platform.sync.base must own public mutex opaque record');
  CheckTokenPresent(LSyncBaseSource, 'platform_mutex_errorcheck',
    'platform.sync.base must own public mutex kind tokens');
  CheckTokenPresent(LSyncBaseSource, 'platform_err_timeout',
    'platform.sync.base must own public sync timeout error');
  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.sync.base',
    'platform.sync must re-export public sync base');

  CheckRawFFIUnit(LPosixFfiSource, 'posix.ffi');
  CheckTokenPresent(LPosixFfiSource, 'pthread_mutex_init',
    'posix.ffi must own raw pthread mutex declarations');
  CheckTokenPresent(LPosixFfiSource, 'pthread_rwlock_init',
    'posix.ffi must own raw pthread rwlock declarations');
  CheckTokenPresent(LPosixFfiSource, 'pthread_cond_timedwait',
    'posix.ffi must own raw pthread condvar declarations');
  CheckTokenAbsent(LPosixFfiSource, 'platform_posix_pthread_',
    'posix.ffi must not own POSIX pthread wrapper helpers');
  CheckTokenAbsent(LPosixFfiSource, 'platform_posix_clock_',
    'posix.ffi must not own POSIX clock wrapper helpers');

  CheckPThreadStorageBase(LLinuxBaseSource, 'linux');
  CheckPThreadStorageBase(LDarwinBaseSource, 'darwin');
  CheckPThreadStorageBase(LAndroidBaseSource, 'android');
  CheckPThreadStorageBase(LFreeBSDBaseSource, 'freebsd');
  CheckPThreadStorageBase(LUnixBaseSource, 'unix');

  CheckRawFFIUnit(LLinuxFfiSource, 'linux.ffi');
  CheckTokenPresent(LLinuxFfiSource, 'function linux_syscall',
    'linux.ffi must own raw syscall binding');
  CheckTokenPresent(LLinuxBaseSource, 'linux_syscall_futex',
    'linux.base must own futex syscall number');
  CheckTokenPresent(LLinuxBaseSource, 'futex_wait',
    'linux.base must own FUTEX_WAIT token');
  CheckTokenPresent(LLinuxBaseSource, 'futex_wake',
    'linux.base must own FUTEX_WAKE token');
  CheckTokenAbsent(LLinuxFfiSource, 'linux_futex_wait_i32',
    'linux.ffi must not own futex wrapper helpers');
  CheckTokenAbsent(LLinuxFfiSource, 'linux_errno_value',
    'linux.ffi must not own errno value helper');

  CheckTokenPresent(LWindowsBaseSource, 'platform_windows_mutex_size',
    'windows.base must own Windows mutex storage size');
  CheckTokenPresent(LWindowsBaseSource, 'platform_windows_rwlock_size',
    'windows.base must own Windows rwlock storage size');
  CheckTokenPresent(LWindowsBaseSource, 'platform_windows_condvar_size',
    'windows.base must own Windows condvar storage size');
  CheckTokenPresent(LWindowsBaseSource, 'error_timeout',
    'windows.base must own Windows timeout token');
  CheckRawFFIUnit(LWindowsFfiSource, 'windows.ffi');
  CheckTokenPresent(LWindowsFfiSource, 'initializesrwlock',
    'windows.ffi must own raw SRWLOCK declarations');
  CheckTokenPresent(LWindowsFfiSource, 'sleepconditionvariablesrw',
    'windows.ffi must own raw condition-variable declaration');
  CheckTokenPresent(LWindowsFfiSource, 'waitonaddress',
    'windows.ffi must own raw WaitOnAddress declaration');
  CheckTokenAbsent(LWindowsFfiSource, 'windows_mutex_',
    'windows.ffi must not own sync wrapper helpers');
  CheckTokenAbsent(LWindowsFfiSource, 'windows_wait_address_i32',
    'windows.ffi must not own wait-address wrapper helpers');

  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.posix.ffi',
    'platform.sync must consume raw POSIX ffi');
  CheckTokenPresent(LSyncSource, 'pthread_mutexattr_init',
    'platform.sync must own pthread mutex initialization wrapper logic');
  CheckTokenPresent(LSyncSource, 'pthread_condattr_init',
    'platform.sync must own pthread condvar initialization wrapper logic');
  CheckTokenPresent(LSyncSource, 'pthread_rwlock_unlock',
    'platform.sync must own pthread rwlock unlock wrapping');
  CheckTokenPresent(LSyncSource, 'linux_syscall(',
    'platform.sync must own Linux futex syscall wrapping');
  CheckTokenPresent(LSyncSource, 'platform_linux_futex_wait_i32',
    'platform.sync must own Linux futex wait wrapper');
  CheckTokenPresent(LSyncSource, 'initializesrwlock',
    'platform.sync must own Windows SRWLOCK wrapper logic');
  CheckTokenPresent(LSyncSource, 'sleepconditionvariablesrw',
    'platform.sync must own Windows condvar wrapper logic');
  CheckTokenPresent(LSyncSource, 'waitonaddress',
    'platform.sync must own Windows wait-address wrapper logic');
  CheckTokenPresent(LSyncSource, 'platform_sync_validate_wait_address',
    'platform.sync must validate public wait-address inputs before raw API calls');
  CheckTokenAbsent(LSyncSource, 'result := windows_mutex_init',
    'platform.sync must not call removed windows.ffi mutex helpers');
  CheckTokenAbsent(LSyncSource, 'result := linux_futex_wait_i32',
    'platform.sync must not call removed linux.ffi futex helpers');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.host_ffi_surface');
  T.Run('platform.sync keeps raw ffi below unified wrappers', @TestPlatformSyncRawFFIBoundary);
  T.Summary;
end.
