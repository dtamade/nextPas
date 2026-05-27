program test_platform_ffi_partition_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  POSIX_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.base.pas';
  POSIX_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.base.pas';
  POSIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';
  LINUX_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.base.pas';
  LINUX_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.base.pas';
  LINUX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.ffi.pas';
  LINUX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.ffi.pas';
  DARWIN_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.base.pas';
  DARWIN_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.base.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.ffi.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.ffi.pas';
  ANDROID_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.base.pas';
  ANDROID_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.base.pas';
  ANDROID_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.ffi.pas';
  ANDROID_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.ffi.pas';
  FREEBSD_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.base.pas';
  FREEBSD_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.base.pas';
  FREEBSD_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.ffi.pas';
  FREEBSD_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.ffi.pas';
  UNIX_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.unix.base.pas';
  UNIX_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.unix.base.pas';
  UNIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.unix.ffi.pas';
  UNIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.unix.ffi.pas';
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

function ResolveRequiredSourcePath(
  const APathFromTest,
  APathFromRoot,
  AMessage: string): string;
begin
  Result := ResolveSourcePath(APathFromTest, APathFromRoot);
  Check(FileExists(Result), AMessage + ': ' + Result);
end;

procedure CheckTokenPresent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckTokenAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure TestPlatformFFIPartition;
var
  LPosixBaseSource: string;
  LPosixSource: string;
  LLinuxBaseSource: string;
  LLinuxSource: string;
  LDarwinBaseSource: string;
  LDarwinSource: string;
  LAndroidBaseSource: string;
  LAndroidSource: string;
  LFreeBSDBaseSource: string;
  LFreeBSDSource: string;
  LUnixBaseSource: string;
  LUnixSource: string;
  LWindowsBaseSource: string;
  LWindowsSource: string;
begin
  LPosixBaseSource := ReadSourceFile(ResolveRequiredSourcePath(
    POSIX_BASE_SOURCE_PATH_FROM_TEST, POSIX_BASE_SOURCE_PATH_FROM_ROOT,
    'posix.base file must exist as the shared POSIX ABI shape owner'));
  LPosixSource := ReadSourceFile(ResolveRequiredSourcePath(
    POSIX_FFI_SOURCE_PATH_FROM_TEST, POSIX_FFI_SOURCE_PATH_FROM_ROOT,
    'posix.ffi file must exist as the shared POSIX external owner'));
  LLinuxBaseSource := ReadSourceFile(ResolveRequiredSourcePath(
    LINUX_BASE_SOURCE_PATH_FROM_TEST, LINUX_BASE_SOURCE_PATH_FROM_ROOT,
    'linux.base file must exist as the Linux host truth owner'));
  LLinuxSource := ReadSourceFile(ResolveRequiredSourcePath(
    LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT,
    'linux.ffi file must exist as the Linux external owner'));
  LDarwinBaseSource := ReadSourceFile(ResolveRequiredSourcePath(
    DARWIN_BASE_SOURCE_PATH_FROM_TEST, DARWIN_BASE_SOURCE_PATH_FROM_ROOT,
    'darwin.base file must exist as the Darwin host truth owner'));
  LDarwinSource := ReadSourceFile(ResolveRequiredSourcePath(
    DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT,
    'darwin.ffi file must exist as the Darwin external owner'));
  LAndroidBaseSource := ReadSourceFile(ResolveRequiredSourcePath(
    ANDROID_BASE_SOURCE_PATH_FROM_TEST, ANDROID_BASE_SOURCE_PATH_FROM_ROOT,
    'android.base file must exist as the Android host truth owner'));
  LAndroidSource := ReadSourceFile(ResolveRequiredSourcePath(
    ANDROID_FFI_SOURCE_PATH_FROM_TEST, ANDROID_FFI_SOURCE_PATH_FROM_ROOT,
    'android.ffi file must exist as the Android external owner'));
  LFreeBSDBaseSource := ReadSourceFile(ResolveRequiredSourcePath(
    FREEBSD_BASE_SOURCE_PATH_FROM_TEST, FREEBSD_BASE_SOURCE_PATH_FROM_ROOT,
    'freebsd.base file must exist as the FreeBSD host truth owner'));
  LFreeBSDSource := ReadSourceFile(ResolveRequiredSourcePath(
    FREEBSD_FFI_SOURCE_PATH_FROM_TEST, FREEBSD_FFI_SOURCE_PATH_FROM_ROOT,
    'freebsd.ffi file must exist as the FreeBSD external owner'));
  LUnixBaseSource := ReadSourceFile(ResolveRequiredSourcePath(
    UNIX_BASE_SOURCE_PATH_FROM_TEST, UNIX_BASE_SOURCE_PATH_FROM_ROOT,
    'unix.base file must exist as the generic Unix host truth owner'));
  LUnixSource := ReadSourceFile(ResolveRequiredSourcePath(
    UNIX_FFI_SOURCE_PATH_FROM_TEST, UNIX_FFI_SOURCE_PATH_FROM_ROOT,
    'unix.ffi file must exist as the generic Unix external owner'));
  LWindowsBaseSource := ReadSourceFile(ResolveRequiredSourcePath(
    WINDOWS_BASE_SOURCE_PATH_FROM_TEST, WINDOWS_BASE_SOURCE_PATH_FROM_ROOT,
    'windows.base file must exist as the Windows host truth owner'));
  LWindowsSource := ReadSourceFile(ResolveRequiredSourcePath(
    WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT,
    'windows.ffi file must exist as the Windows external owner'));

  CheckTokenPresent(LPosixSource, 'nextpas.core.platform.posix.base',
    'posix.ffi must consume posix.base');
  CheckTokenPresent(LLinuxSource, 'nextpas.core.platform.linux.base',
    'linux.ffi must consume linux.base');
  CheckTokenPresent(LDarwinSource, 'nextpas.core.platform.darwin.base',
    'darwin.ffi must consume darwin.base');
  CheckTokenPresent(LAndroidSource, 'nextpas.core.platform.android.base',
    'android.ffi must consume android.base');
  CheckTokenPresent(LFreeBSDSource, 'nextpas.core.platform.freebsd.base',
    'freebsd.ffi must consume freebsd.base');
  CheckTokenPresent(LUnixSource, 'nextpas.core.platform.unix.base',
    'unix.ffi must consume unix.base');
  CheckTokenPresent(LWindowsSource, 'nextpas.core.platform.windows.base',
    'windows.ffi must consume windows.base');

  CheckTokenPresent(LPosixBaseSource, 'timespec',
    'posix.base must own shared POSIX timespec shape');
  CheckTokenPresent(LPosixBaseSource, 'pthread_t',
    'posix.base must own shared POSIX pthread token shape');
  CheckTokenPresent(LPosixBaseSource, 'pthread_mutex_t',
    'posix.base must own shared POSIX pthread mutex shape');
  CheckTokenPresent(LPosixSource, 'clock_gettime',
    'posix.ffi must continue to own shared POSIX function declarations');
  CheckTokenPresent(LPosixSource, 'pthread_create',
    'posix.ffi must continue to own shared pthread function declarations');
  CheckTokenAbsent(LPosixSource, 'posix_eagain',
    'posix.ffi must not keep per-host errno constants after ffi partitioning');
  CheckTokenAbsent(LPosixSource, '_sc_nprocessors_onln',
    'posix.ffi must not keep per-host sysconf ids after ffi partitioning');
  CheckTokenAbsent(LPosixSource, 'function posix_errno_location',
    'posix.ffi must not keep per-host errno symbol bindings after ffi partitioning');
  CheckTokenAbsent(LPosixSource, 'pthread_mutex_normal',
    'posix.ffi must not keep per-host pthread mutex kind numbering after ffi partitioning');
  CheckTokenAbsent(LPosixSource, 'pthread_mutex_recursive',
    'posix.ffi must not keep per-host pthread mutex recursive numbering after ffi partitioning');
  CheckTokenAbsent(LPosixSource, 'pthread_mutex_errorcheck',
    'posix.ffi must not keep per-host pthread mutex errorcheck numbering after ffi partitioning');
  CheckTokenAbsent(LPosixSource, 'function pthread_condattr_setclock',
    'posix.ffi must not keep host-specific pthread condattr clock capability after ffi partitioning');

  CheckTokenPresent(LLinuxBaseSource, 'platform_clock_monotonic_id',
    'linux.base must expose Linux clock ids');
  CheckTokenPresent(LLinuxBaseSource, 'platform_posix_etimedout',
    'linux.base must expose Linux errno constants');
  CheckTokenPresent(LLinuxBaseSource, 'platform_posix_eintr',
    'linux.base must expose Linux EINTR for retryable sleep semantics');
  CheckTokenPresent(LLinuxBaseSource, 'tplatformpthreadtokenalign',
    'linux.base must expose Linux pthread token align carrier');
  CheckTokenPresent(LLinuxSource, 'function platform_errno_location',
    'linux.ffi must expose Linux errno binding');
  CheckTokenPresent(LLinuxBaseSource, 'platform_pthread_mutex_normal_kind',
    'linux.base must expose Linux pthread mutex kind numbering');
  CheckTokenPresent(LLinuxBaseSource, 'platform_pthread_condattr_setclock_supported',
    'linux.base must expose Linux pthread condattr clock capability');
  CheckTokenPresent(LLinuxSource, 'function platform_pthread_condattr_setclock',
    'linux.ffi must expose Linux pthread condattr clock binding');
  CheckTokenPresent(LLinuxBaseSource, 'platform_pthread_timeout_clock_id',
    'linux.base must expose Linux pthread timeout clock policy');

  CheckTokenPresent(LDarwinBaseSource, 'platform_clock_monotonic_id',
    'darwin.base must expose Darwin clock ids');
  CheckTokenPresent(LDarwinBaseSource, 'platform_posix_etimedout',
    'darwin.base must expose Darwin errno constants');
  CheckTokenPresent(LDarwinBaseSource, 'platform_posix_eintr',
    'darwin.base must expose Darwin EINTR for retryable sleep semantics');
  CheckTokenPresent(LDarwinBaseSource, 'mach_timebase_info_data_t',
    'darwin.base must expose Darwin mach timebase record');
  CheckTokenPresent(LDarwinBaseSource, 'tplatformpthreadtokenalign',
    'darwin.base must expose Darwin pthread token align carrier');
  CheckTokenPresent(LDarwinSource, 'function platform_errno_location',
    'darwin.ffi must expose Darwin errno binding');
  CheckTokenPresent(LDarwinBaseSource, 'platform_pthread_mutex_normal_kind',
    'darwin.base must expose Darwin pthread mutex kind numbering');
  CheckTokenPresent(LDarwinBaseSource, 'platform_pthread_condattr_setclock_supported',
    'darwin.base must expose Darwin pthread condattr clock capability');
  CheckTokenPresent(LDarwinSource, 'function platform_pthread_condattr_setclock',
    'darwin.ffi must expose Darwin pthread condattr clock binding or stub');
  CheckTokenPresent(LDarwinBaseSource, 'platform_pthread_timeout_clock_id',
    'darwin.base must expose Darwin pthread timeout clock policy');

  CheckTokenPresent(LAndroidBaseSource, 'platform_clock_monotonic_id',
    'android.base must expose Android clock ids');
  CheckTokenPresent(LAndroidBaseSource, 'platform_posix_etimedout',
    'android.base must expose Android errno constants');
  CheckTokenPresent(LAndroidBaseSource, 'platform_posix_eintr',
    'android.base must expose Android EINTR for retryable sleep semantics');
  CheckTokenPresent(LAndroidBaseSource, 'tplatformpthreadtokenalign',
    'android.base must expose Android pthread token align carrier');
  CheckTokenPresent(LAndroidSource, 'function platform_errno_location',
    'android.ffi must expose Android errno binding');
  CheckTokenPresent(LAndroidBaseSource, 'platform_pthread_mutex_normal_kind',
    'android.base must expose Android pthread mutex kind numbering');
  CheckTokenPresent(LAndroidBaseSource, 'platform_pthread_condattr_setclock_supported',
    'android.base must expose Android pthread condattr clock capability');
  CheckTokenPresent(LAndroidSource, 'function platform_pthread_condattr_setclock',
    'android.ffi must expose Android pthread condattr clock binding');
  CheckTokenPresent(LAndroidBaseSource, 'platform_pthread_timeout_clock_id',
    'android.base must expose Android pthread timeout clock policy');

  CheckTokenPresent(LFreeBSDBaseSource, 'platform_clock_monotonic_id',
    'freebsd.base must expose FreeBSD clock ids');
  CheckTokenPresent(LFreeBSDBaseSource, 'platform_posix_etimedout',
    'freebsd.base must expose FreeBSD errno constants');
  CheckTokenPresent(LFreeBSDBaseSource, 'platform_posix_eintr',
    'freebsd.base must expose FreeBSD EINTR for retryable sleep semantics');
  CheckTokenPresent(LFreeBSDBaseSource, 'tplatformpthreadtokenalign',
    'freebsd.base must expose FreeBSD pthread token align carrier');
  CheckTokenPresent(LFreeBSDSource, 'function platform_errno_location',
    'freebsd.ffi must expose FreeBSD errno binding');
  CheckTokenPresent(LFreeBSDBaseSource, 'platform_pthread_mutex_normal_kind',
    'freebsd.base must expose FreeBSD pthread mutex kind numbering');
  CheckTokenPresent(LFreeBSDBaseSource, 'platform_pthread_condattr_setclock_supported',
    'freebsd.base must expose FreeBSD pthread condattr clock capability');
  CheckTokenPresent(LFreeBSDSource, 'function platform_pthread_condattr_setclock',
    'freebsd.ffi must expose FreeBSD pthread condattr clock binding');
  CheckTokenPresent(LFreeBSDBaseSource, 'platform_pthread_timeout_clock_id',
    'freebsd.base must expose FreeBSD pthread timeout clock policy');

  CheckTokenPresent(LUnixBaseSource, 'platform_clock_monotonic_id',
    'unix.base must expose generic Unix clock ids');
  CheckTokenPresent(LUnixBaseSource, 'platform_posix_etimedout',
    'unix.base must expose generic Unix errno constants');
  CheckTokenPresent(LUnixBaseSource, 'platform_posix_eintr',
    'unix.base must expose generic Unix EINTR for retryable sleep semantics');
  CheckTokenPresent(LUnixBaseSource, 'tplatformpthreadtokenalign',
    'unix.base must expose generic Unix pthread token align carrier');
  CheckTokenPresent(LUnixSource, 'function platform_errno_location',
    'unix.ffi must expose generic Unix errno binding');
  CheckTokenPresent(LUnixBaseSource, 'platform_pthread_mutex_normal_kind',
    'unix.base must expose generic Unix pthread mutex kind numbering');
  CheckTokenPresent(LUnixBaseSource, 'platform_pthread_condattr_setclock_supported',
    'unix.base must expose generic Unix pthread condattr clock capability');
  CheckTokenPresent(LUnixSource, 'function platform_pthread_condattr_setclock',
    'unix.ffi must expose generic Unix pthread condattr clock binding');
  CheckTokenPresent(LUnixBaseSource, 'platform_pthread_timeout_clock_id',
    'unix.base must expose generic Unix pthread timeout clock policy');

  CheckTokenPresent(LWindowsBaseSource, 'dword',
    'windows.base must expose Windows DWORD ABI scalar');
  CheckTokenPresent(LWindowsBaseSource, 'handle',
    'windows.base must expose Windows HANDLE ABI scalar');
  CheckTokenPresent(LWindowsBaseSource, 'filetime',
    'windows.base must expose Windows FILETIME record');
  CheckTokenPresent(LWindowsBaseSource, 'system_info',
    'windows.base must expose Windows SYSTEM_INFO record');
  CheckTokenPresent(LWindowsBaseSource, 'tplatformwindowsthreadstate',
    'windows.base must expose Windows thread state carrier');
  CheckTokenPresent(LWindowsBaseSource, 'platform_windows_mutex_size',
    'windows.base must expose Windows sync storage size token');
  CheckTokenPresent(LWindowsBaseSource, 'windows_filetime_unix_epoch_offset_100ns',
    'windows.base must expose Windows FILETIME epoch token');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.ffi_partition_surface');
  T.Run('platform ffi is partitioned by host', @TestPlatformFFIPartition);
  T.Summary;
end.
