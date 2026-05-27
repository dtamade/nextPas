program test_platform_sync_host_ffi_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
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

procedure CheckPosixSyncHelperSet(const ASource, AHostLabel: string);
begin
  CheckTokenPresent(ASource, 'platform_posix_errno_value_from_location',
    AHostLabel + ' must delegate errno-value load to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_pthread_mutex_size',
    AHostLabel + ' must expose pthread mutex storage size for sync');
  CheckTokenPresent(ASource, 'platform_pthread_rwlock_size',
    AHostLabel + ' must expose pthread rwlock storage size for sync');
  CheckTokenPresent(ASource, 'platform_pthread_condvar_size',
    AHostLabel + ' must expose pthread condvar storage size for sync');
  CheckTokenPresent(ASource, 'tplatformpthreadmutexalign',
    AHostLabel + ' must expose pthread mutex align carrier type for sync');
  CheckTokenPresent(ASource, 'tplatformpthreadrwlockalign',
    AHostLabel + ' must expose pthread rwlock align carrier type for sync');
  CheckTokenPresent(ASource, 'tplatformpthreadcondvaralign',
    AHostLabel + ' must expose pthread condvar align carrier type for sync');
  CheckTokenPresent(ASource, 'platform_pthread_timeout_clock_now',
    AHostLabel + ' must expose pthread timeout clock helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_timeout_deadline_after_ns',
    AHostLabel + ' must expose pthread timeout deadline helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_timeout_remaining_ns_u64',
    AHostLabel + ' must expose pthread timeout remaining helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_mutex_init',
    AHostLabel + ' must expose pthread mutex init helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_mutex_init_platform_kind',
    AHostLabel + ' must expose pthread mutex init helper for public kind contract');
  CheckTokenPresent(ASource, 'platform_posix_pthread_mutex_init_kind',
    AHostLabel + ' must delegate pthread mutex attr-init glue to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_mutex_init_public_kind',
    AHostLabel + ' must delegate public mutex kind projection to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_pthread_mutex_destroy',
    AHostLabel + ' must expose pthread mutex destroy helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_mutex_lock',
    AHostLabel + ' must expose pthread mutex lock helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_mutex_trylock',
    AHostLabel + ' must expose pthread mutex trylock helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_mutex_unlock',
    AHostLabel + ' must expose pthread mutex unlock helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_rwlock_init',
    AHostLabel + ' must expose pthread rwlock init helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_rwlock_destroy',
    AHostLabel + ' must expose pthread rwlock destroy helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_rwlock_rdlock',
    AHostLabel + ' must expose pthread rwlock read-lock helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_rwlock_tryrdlock',
    AHostLabel + ' must expose pthread rwlock try-read-lock helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_rwlock_wrlock',
    AHostLabel + ' must expose pthread rwlock write-lock helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_rwlock_trywrlock',
    AHostLabel + ' must expose pthread rwlock try-write-lock helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_rwlock_rdunlock',
    AHostLabel + ' must expose pthread rwlock read-unlock helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_rwlock_wrunlock',
    AHostLabel + ' must expose pthread rwlock write-unlock helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_condvar_init',
    AHostLabel + ' must expose pthread condvar init helper for sync');
  CheckTokenPresent(ASource, 'platform_posix_pthread_condvar_init_with_clock',
    AHostLabel + ' must delegate pthread condvar attr-init glue to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_pthread_condvar_destroy',
    AHostLabel + ' must expose pthread condvar destroy helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_condvar_wait',
    AHostLabel + ' must expose pthread condvar wait helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_condvar_timedwait_abs',
    AHostLabel + ' must expose pthread condvar timedwait helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_condvar_signal',
    AHostLabel + ' must expose pthread condvar signal helper for sync');
  CheckTokenPresent(ASource, 'platform_pthread_condvar_broadcast',
    AHostLabel + ' must expose pthread condvar broadcast helper for sync');
  CheckTokenPresent(ASource, 'platform_posix_clock_now',
    AHostLabel + ' must delegate timeout clock reads to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_clock_deadline_after_ns',
    AHostLabel + ' must delegate timeout deadline creation to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_clock_deadline_remaining_ns_u64',
    AHostLabel + ' must delegate timeout remaining checks to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_mutex_destroy',
    AHostLabel + ' must delegate pthread mutex destroy to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_mutex_lock',
    AHostLabel + ' must delegate pthread mutex lock to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_mutex_trylock',
    AHostLabel + ' must delegate pthread mutex trylock to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_mutex_unlock',
    AHostLabel + ' must delegate pthread mutex unlock to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_rwlock_init',
    AHostLabel + ' must delegate pthread rwlock init to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_rwlock_destroy',
    AHostLabel + ' must delegate pthread rwlock destroy to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_rwlock_rdlock',
    AHostLabel + ' must delegate pthread rwlock read-lock to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_rwlock_tryrdlock',
    AHostLabel + ' must delegate pthread rwlock try-read-lock to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_rwlock_wrlock',
    AHostLabel + ' must delegate pthread rwlock write-lock to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_rwlock_trywrlock',
    AHostLabel + ' must delegate pthread rwlock try-write-lock to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_rwlock_unlock',
    AHostLabel + ' must delegate pthread rwlock unlock to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_condvar_destroy',
    AHostLabel + ' must delegate pthread condvar destroy to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_condvar_wait',
    AHostLabel + ' must delegate pthread condvar wait to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_condvar_timedwait_abs',
    AHostLabel + ' must delegate pthread condvar timedwait to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_condvar_signal',
    AHostLabel + ' must delegate pthread condvar signal to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_condvar_broadcast',
    AHostLabel + ' must delegate pthread condvar broadcast to shared posix.ffi');
  Check(Pos('pthread_mutexattr_init(', ASource) = 0,
    AHostLabel + ' must not keep raw pthread mutexattr init glue after shared posix ownerization');
  Check(Pos('pthread_mutexattr_settype(', ASource) = 0,
    AHostLabel + ' must not keep raw pthread mutexattr settype glue after shared posix ownerization');
  Check(Pos('pthread_mutexattr_destroy(', ASource) = 0,
    AHostLabel + ' must not keep raw pthread mutexattr destroy glue after shared posix ownerization');
  Check(Pos('pthread_condattr_init(', ASource) = 0,
    AHostLabel + ' must not keep raw pthread condattr init glue after shared posix ownerization');
  Check(Pos('pthread_condattr_destroy(', ASource) = 0,
    AHostLabel + ' must not keep raw pthread condattr destroy glue after shared posix ownerization');
  Check(Pos('pthread_cond_init(', ASource) = 0,
    AHostLabel + ' must not keep raw pthread condvar init glue after shared posix ownerization');
  Check(Pos('result := platform_errno_location^;', ASource) = 0,
    AHostLabel + ' must not keep a local errno-value load body after shared posix ownerization');
  Check(Pos('case akind of', ASource) = 0,
    AHostLabel + ' must not keep a local public mutex kind mapping body after shared posix ownerization');
end;

procedure TestPlatformSyncUsesHostFFISurface;
var
  LSyncSource: string;
  LLinuxSource: string;
  LDarwinSource: string;
  LAndroidSource: string;
  LFreeBSDSource: string;
  LUnixSource: string;
  LWindowsSource: string;
begin
  LSyncSource := ReadSourceFile(ResolveSourcePath(SYNC_SOURCE_PATH_FROM_TEST, SYNC_SOURCE_PATH_FROM_ROOT));
  LLinuxSource := ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT));
  LDarwinSource := ReadSourceFile(ResolveSourcePath(DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT));
  LAndroidSource := ReadSourceFile(ResolveSourcePath(ANDROID_FFI_SOURCE_PATH_FROM_TEST, ANDROID_FFI_SOURCE_PATH_FROM_ROOT));
  LFreeBSDSource := ReadSourceFile(ResolveSourcePath(FREEBSD_FFI_SOURCE_PATH_FROM_TEST, FREEBSD_FFI_SOURCE_PATH_FROM_ROOT));
  LUnixSource := ReadSourceFile(ResolveSourcePath(UNIX_FFI_SOURCE_PATH_FROM_TEST, UNIX_FFI_SOURCE_PATH_FROM_ROOT));
  LWindowsSource := ReadSourceFile(ResolveSourcePath(WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LLinuxSource, 'function linux_syscall',
    'linux.ffi must expose the Linux futex syscall binding');
  CheckTokenPresent(LLinuxSource, 'linux_syscall_futex',
    'linux.ffi must expose the Linux futex syscall number');
  CheckTokenPresent(LLinuxSource, 'futex_wait',
    'linux.ffi must expose FUTEX_WAIT');
  CheckTokenPresent(LLinuxSource, 'futex_wake',
    'linux.ffi must expose FUTEX_WAKE');
  CheckTokenPresent(LLinuxSource, 'platform_posix_errno_value',
    'linux.ffi must expose Linux errno value helper for sync');
  CheckTokenPresent(LLinuxSource, 'linux_futex_wait_i32',
    'linux.ffi must expose Linux futex wait helper for sync');
  CheckTokenPresent(LLinuxSource, 'linux_futex_wake_one_i32',
    'linux.ffi must expose Linux futex wake-one helper for sync');
  CheckTokenPresent(LLinuxSource, 'linux_futex_wake_all_i32',
    'linux.ffi must expose Linux futex wake-all helper for sync');
  CheckPosixSyncHelperSet(LLinuxSource, 'linux.ffi');

  CheckTokenPresent(LDarwinSource, 'platform_posix_errno_value',
    'darwin.ffi must expose Darwin errno value helper for sync');
  CheckPosixSyncHelperSet(LDarwinSource, 'darwin.ffi');
  CheckTokenPresent(LAndroidSource, 'platform_posix_errno_value',
    'android.ffi must expose Android errno value helper for sync');
  CheckPosixSyncHelperSet(LAndroidSource, 'android.ffi');
  CheckTokenPresent(LFreeBSDSource, 'platform_posix_errno_value',
    'freebsd.ffi must expose FreeBSD errno value helper for sync');
  CheckPosixSyncHelperSet(LFreeBSDSource, 'freebsd.ffi');
  CheckTokenPresent(LUnixSource, 'platform_posix_errno_value',
    'unix.ffi must expose generic Unix errno value helper for sync');
  CheckPosixSyncHelperSet(LUnixSource, 'unix.ffi');

  CheckTokenPresent(LWindowsSource, 'waitonaddress',
    'windows.ffi must expose WaitOnAddress');
  CheckTokenPresent(LWindowsSource, 'wakebyaddresssingle',
    'windows.ffi must expose WakeByAddressSingle');
  CheckTokenPresent(LWindowsSource, 'wakebyaddressall',
    'windows.ffi must expose WakeByAddressAll');
  CheckTokenPresent(LWindowsSource, 'getlasterror',
    'windows.ffi must expose GetLastError for sync error mapping');
  CheckTokenPresent(LWindowsSource, 'windows_timeout_ns_to_ms',
    'windows.ffi must expose Windows wait timeout conversion policy');
  CheckTokenPresent(LWindowsSource, 'windows_last_error_i32',
    'windows.ffi must expose Windows last-error conversion helper');
  CheckTokenPresent(LWindowsSource, 'windows_last_error_is_timeout',
    'windows.ffi must expose Windows timeout-result semantics');
  CheckTokenPresent(LWindowsSource, 'windows_error_i32_is_timeout',
    'windows.ffi must expose an Int32 timeout classifier helper');
  CheckTokenPresent(LWindowsSource, 'windows_mutex_init',
    'windows.ffi must expose Windows mutex init helper');
  CheckTokenPresent(LWindowsSource, 'windows_mutex_lock',
    'windows.ffi must expose Windows mutex lock helper');
  CheckTokenPresent(LWindowsSource, 'windows_mutex_trylock',
    'windows.ffi must expose Windows mutex trylock helper');
  CheckTokenPresent(LWindowsSource, 'windows_mutex_unlock',
    'windows.ffi must expose Windows mutex unlock helper');
  CheckTokenPresent(LWindowsSource, 'windows_rwlock_init',
    'windows.ffi must expose Windows rwlock init helper');
  CheckTokenPresent(LWindowsSource, 'windows_rwlock_rdlock',
    'windows.ffi must expose Windows rwlock read-lock helper');
  CheckTokenPresent(LWindowsSource, 'windows_rwlock_tryrdlock',
    'windows.ffi must expose Windows rwlock try-read-lock helper');
  CheckTokenPresent(LWindowsSource, 'windows_rwlock_wrlock',
    'windows.ffi must expose Windows rwlock write-lock helper');
  CheckTokenPresent(LWindowsSource, 'windows_rwlock_trywrlock',
    'windows.ffi must expose Windows rwlock try-write-lock helper');
  CheckTokenPresent(LWindowsSource, 'windows_rwlock_rdunlock',
    'windows.ffi must expose Windows rwlock read-unlock helper');
  CheckTokenPresent(LWindowsSource, 'windows_rwlock_wrunlock',
    'windows.ffi must expose Windows rwlock write-unlock helper');
  CheckTokenPresent(LWindowsSource, 'windows_condvar_init',
    'windows.ffi must expose Windows condvar init helper');
  CheckTokenPresent(LWindowsSource, 'windows_condvar_wait',
    'windows.ffi must expose Windows condvar wait helper');
  CheckTokenPresent(LWindowsSource, 'windows_condvar_timedwait_ms',
    'windows.ffi must expose Windows condvar timedwait helper');
  CheckTokenPresent(LWindowsSource, 'windows_condvar_timedwait_ns',
    'windows.ffi must expose Windows condvar timedwait helper with ns timeout input');
  CheckTokenPresent(LWindowsSource, 'windows_condvar_timedwait_timeout_result',
    'windows.ffi must expose Windows condvar timedwait helper that maps timeout semantics for sync');
  CheckTokenPresent(LWindowsSource, 'windows_condvar_signal',
    'windows.ffi must expose Windows condvar signal helper');
  CheckTokenPresent(LWindowsSource, 'windows_condvar_broadcast',
    'windows.ffi must expose Windows condvar broadcast helper');
  CheckTokenPresent(LWindowsSource, 'windows_wait_address_i32',
    'windows.ffi must expose Windows wait-address helper');
  CheckTokenPresent(LWindowsSource, 'windows_wait_address_i32_timeout_ns',
    'windows.ffi must expose Windows wait-address helper with ns timeout input');
  CheckTokenPresent(LWindowsSource, 'windows_wait_address_i32_timeout_result',
    'windows.ffi must expose Windows wait-address helper that maps timeout semantics for sync');
  CheckTokenPresent(LWindowsSource, 'windows_wake_address_single',
    'windows.ffi must expose Windows wake-address-single helper');
  CheckTokenPresent(LWindowsSource, 'windows_wake_address_all',
    'windows.ffi must expose Windows wake-address-all helper');
  CheckTokenPresent(LWindowsSource, 'platform_windows_mutex_size',
    'windows.ffi must expose Windows mutex storage size for sync');
  CheckTokenPresent(LWindowsSource, 'platform_windows_rwlock_size',
    'windows.ffi must expose Windows rwlock storage size for sync');
  CheckTokenPresent(LWindowsSource, 'platform_windows_condvar_size',
    'windows.ffi must expose Windows condvar storage size for sync');
  CheckTokenPresent(LWindowsSource, 'tplatformwindowsmutexalign',
    'windows.ffi must expose Windows mutex align carrier type for sync');
  CheckTokenPresent(LWindowsSource, 'tplatformwindowsrwlockalign',
    'windows.ffi must expose Windows rwlock align carrier type for sync');
  CheckTokenPresent(LWindowsSource, 'tplatformwindowscondvaralign',
    'windows.ffi must expose Windows condvar align carrier type for sync');

  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.linux.ffi',
    'platform.sync must use linux.ffi for Linux futex bindings');
  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.windows.ffi',
    'platform.sync must use windows.ffi for Windows wait-address bindings');
  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.android.ffi',
    'platform.sync must use android.ffi for Android host-owned errno/clock ids');
  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.darwin.ffi',
    'platform.sync must use darwin.ffi for Darwin host-owned errno/clock ids');
  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.freebsd.ffi',
    'platform.sync must use freebsd.ffi for FreeBSD host-owned errno/clock ids');
  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.unix.ffi',
    'platform.sync must use unix.ffi for generic Unix host-owned errno/clock ids');

  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_init_platform_kind',
    'platform.sync must consume host-owned pthread mutex init helper for public kind contract');
  CheckTokenPresent(LSyncSource, 'platform_pthread_timeout_deadline_after_ns',
    'platform.sync must consume host-owned pthread timeout deadline helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_timeout_remaining_ns_u64',
    'platform.sync must consume host-owned pthread timeout remaining helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_init',
    'platform.sync must consume host-owned pthread mutex init helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_destroy',
    'platform.sync must consume host-owned pthread mutex destroy helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_lock',
    'platform.sync must consume host-owned pthread mutex lock helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_trylock',
    'platform.sync must consume host-owned pthread mutex trylock helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_unlock',
    'platform.sync must consume host-owned pthread mutex unlock helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_rwlock_init',
    'platform.sync must consume host-owned pthread rwlock init helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_rwlock_destroy',
    'platform.sync must consume host-owned pthread rwlock destroy helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_rwlock_rdlock',
    'platform.sync must consume host-owned pthread rwlock read-lock helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_rwlock_tryrdlock',
    'platform.sync must consume host-owned pthread rwlock try-read-lock helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_rwlock_wrlock',
    'platform.sync must consume host-owned pthread rwlock write-lock helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_rwlock_trywrlock',
    'platform.sync must consume host-owned pthread rwlock try-write-lock helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_rwlock_rdunlock',
    'platform.sync must consume host-owned pthread rwlock read-unlock helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_rwlock_wrunlock',
    'platform.sync must consume host-owned pthread rwlock write-unlock helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_condvar_init',
    'platform.sync must consume host-owned pthread condvar init helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_condvar_destroy',
    'platform.sync must consume host-owned pthread condvar destroy helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_condvar_wait',
    'platform.sync must consume host-owned pthread condvar wait helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_condvar_timedwait_abs',
    'platform.sync must consume host-owned pthread condvar timedwait helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_condvar_signal',
    'platform.sync must consume host-owned pthread condvar signal helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_condvar_broadcast',
    'platform.sync must consume host-owned pthread condvar broadcast helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_yield',
    'platform.sync must consume host-owned pthread yield helper');
  CheckTokenPresent(LSyncSource, 'linux_futex_wait_i32',
    'platform.sync must consume Linux futex wait helper through linux.ffi');
  CheckTokenPresent(LSyncSource, 'linux_futex_wake_one_i32',
    'platform.sync must consume Linux futex wake-one helper through linux.ffi');
  CheckTokenPresent(LSyncSource, 'linux_futex_wake_all_i32',
    'platform.sync must consume Linux futex wake-all helper through linux.ffi');
  CheckTokenPresent(LSyncSource, 'windows_mutex_init',
    'platform.sync must consume Windows mutex init helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_mutex_lock',
    'platform.sync must consume Windows mutex lock helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_mutex_trylock',
    'platform.sync must consume Windows mutex trylock helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_mutex_unlock',
    'platform.sync must consume Windows mutex unlock helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_rwlock_init',
    'platform.sync must consume Windows rwlock init helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_rwlock_rdlock',
    'platform.sync must consume Windows rwlock read-lock helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_rwlock_tryrdlock',
    'platform.sync must consume Windows rwlock try-read-lock helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_rwlock_wrlock',
    'platform.sync must consume Windows rwlock write-lock helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_rwlock_trywrlock',
    'platform.sync must consume Windows rwlock try-write-lock helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_rwlock_rdunlock',
    'platform.sync must consume Windows rwlock read-unlock helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_rwlock_wrunlock',
    'platform.sync must consume Windows rwlock write-unlock helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_condvar_init',
    'platform.sync must consume Windows condvar init helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_condvar_wait',
    'platform.sync must consume Windows condvar wait helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_condvar_timedwait_timeout_result',
    'platform.sync must consume Windows condvar timedwait timeout-mapping helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_condvar_signal',
    'platform.sync must consume Windows condvar signal helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_condvar_broadcast',
    'platform.sync must consume Windows condvar broadcast helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_wait_address_i32_timeout_result',
    'platform.sync must consume Windows wait-address timeout-mapping helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_wake_address_single',
    'platform.sync must consume Windows wake-address-single helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_wake_address_all',
    'platform.sync must consume Windows wake-address-all helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_size',
    'platform.sync must consume host-owned pthread mutex storage size');
  CheckTokenPresent(LSyncSource, 'platform_pthread_rwlock_size',
    'platform.sync must consume host-owned pthread rwlock storage size');
  CheckTokenPresent(LSyncSource, 'platform_pthread_condvar_size',
    'platform.sync must consume host-owned pthread condvar storage size');
  CheckTokenPresent(LSyncSource, 'platform_windows_mutex_size',
    'platform.sync must consume host-owned Windows mutex storage size');
  CheckTokenPresent(LSyncSource, 'platform_windows_rwlock_size',
    'platform.sync must consume host-owned Windows rwlock storage size');
  CheckTokenPresent(LSyncSource, 'platform_windows_condvar_size',
    'platform.sync must consume host-owned Windows condvar storage size');
  CheckTokenPresent(LSyncSource, 'tplatformmutexalign',
    'platform.sync must consume host-owned mutex align carrier type');
  CheckTokenPresent(LSyncSource, 'tplatformrwlockalign',
    'platform.sync must consume host-owned rwlock align carrier type');
  CheckTokenPresent(LSyncSource, 'tplatformcondvaralign',
    'platform.sync must consume host-owned condvar align carrier type');
  Check(Pos('platform_posix_errno_value', LSyncSource) = 0,
    'platform.sync must not keep raw errno helper usage in the Unix consumer');
  Check(Pos('platform_errno_location^', LSyncSource) = 0,
    'platform.sync must not dereference errno storage directly in the consumer');
  Check(Pos('function platform_posix_mutex_kind', LSyncSource) = 0,
    'platform.sync must not keep a local pthread mutex kind mapper in the Unix consumer');
  Check(Pos('platform_pthread_mutex_normal_kind', LSyncSource) = 0,
    'platform.sync must not keep raw pthread mutex normal numbering in the Unix consumer');
  Check(Pos('platform_pthread_mutex_recursive_kind', LSyncSource) = 0,
    'platform.sync must not keep raw pthread mutex recursive numbering in the Unix consumer');
  Check(Pos('platform_pthread_mutex_errorcheck_kind', LSyncSource) = 0,
    'platform.sync must not keep raw pthread mutex errorcheck numbering in the Unix consumer');
  Check(Pos('procedure platform_posix_add_timeout', LSyncSource) = 0,
    'platform.sync must not keep local POSIX timespec deadline arithmetic');
  Check(Pos('function platform_posix_timespec_to_ns', LSyncSource) = 0,
    'platform.sync must not keep local POSIX timespec-to-ns arithmetic');
  Check(Pos('function platform_posix_remaining_ns', LSyncSource) = 0,
    'platform.sync must not keep local POSIX remaining-time arithmetic');
  Check(Pos('function platform_posix_now(', LSyncSource) = 0,
    'platform.sync must not keep a local pthread timeout-clock read helper');
  Check(Pos('getlasterror', LSyncSource) = 0,
    'platform.sync must not call GetLastError directly in the Windows consumer');
  Check(Pos('error_timeout', LSyncSource) = 0,
    'platform.sync must not keep a raw Windows timeout-result token');
  Check(Pos('function platform_timeout_ns_to_ms', LSyncSource) = 0,
    'platform.sync must not keep a local Windows timeout conversion helper');
  Check(Pos('windows_timeout_ns_to_ms', LSyncSource) = 0,
    'platform.sync must not keep the raw Windows timeout-ms helper in the consumer');
  Check(Pos('windows_last_error_is_timeout', LSyncSource) = 0,
    'platform.sync must not keep the raw Windows DWORD timeout classifier in the consumer');
  Check(Pos('windows_error_i32_is_timeout', LSyncSource) = 0,
    'platform.sync must not keep the Int32 Windows timeout classifier in the consumer');
  Check(Pos('windows_condvar_timedwait_ns', LSyncSource) = 0,
    'platform.sync must not keep the raw Windows condvar timedwait helper in the consumer');
  Check(Pos('windows_wait_address_i32_timeout_ns', LSyncSource) = 0,
    'platform.sync must not keep the raw Windows wait-address timeout helper in the consumer');
  Check(Pos(': dword', LSyncSource) = 0,
    'platform.sync must not keep raw DWORD temporaries in the Windows consumer');
  Check(Pos('linux_syscall', LSyncSource) = 0,
    'platform.sync must not call linux_syscall directly in the Linux consumer');
  Check(Pos('futex_wait or futex_private_flag', LSyncSource) = 0,
    'platform.sync must not assemble raw FUTEX_WAIT operations in the Linux consumer');
  Check(Pos('futex_wake or futex_private_flag', LSyncSource) = 0,
    'platform.sync must not assemble raw FUTEX_WAKE operations in the Linux consumer');
  Check(Pos('clock_gettime(', LSyncSource) = 0,
    'platform.sync must not call clock_gettime directly in the Unix consumer');
  Check(Pos('platform_posix_timespec_add_ns', LSyncSource) = 0,
    'platform.sync must not build timeout deadlines from shared POSIX arithmetic in the consumer');
  Check(Pos('platform_posix_timespec_remaining_ns_u64', LSyncSource) = 0,
    'platform.sync must not compute timeout remaining time from shared POSIX arithmetic in the consumer');
  Check(Pos('platform_pthread_timeout_clock_now', LSyncSource) = 0,
    'platform.sync must not read the pthread timeout clock directly in the consumer');
  Check(Pos('pthread_mutexattr_init(', LSyncSource) = 0,
    'platform.sync must not call pthread_mutexattr_init directly in the Unix consumer');
  Check(Pos('pthread_mutexattr_settype(', LSyncSource) = 0,
    'platform.sync must not call pthread_mutexattr_settype directly in the Unix consumer');
  Check(Pos('pthread_mutexattr_destroy(', LSyncSource) = 0,
    'platform.sync must not call pthread_mutexattr_destroy directly in the Unix consumer');
  Check(Pos('platform_posix_map_error(pthread_mutex_init(', LSyncSource) = 0,
    'platform.sync must not call pthread_mutex_init directly in the Unix consumer');
  Check(Pos('platform_posix_map_error(pthread_mutex_destroy(', LSyncSource) = 0,
    'platform.sync must not call pthread_mutex_destroy directly in the Unix consumer');
  Check(Pos('platform_posix_map_error(pthread_mutex_lock(', LSyncSource) = 0,
    'platform.sync must not call pthread_mutex_lock directly in the Unix consumer');
  Check(Pos('platform_posix_map_error(pthread_mutex_trylock(', LSyncSource) = 0,
    'platform.sync must not call pthread_mutex_trylock directly in the Unix consumer');
  Check(Pos('platform_posix_map_error(pthread_mutex_unlock(', LSyncSource) = 0,
    'platform.sync must not call pthread_mutex_unlock directly in the Unix consumer');
  Check(Pos('platform_posix_map_error(pthread_rwlock_init(', LSyncSource) = 0,
    'platform.sync must not call pthread_rwlock_init directly in the Unix consumer');
  Check(Pos('platform_posix_map_error(pthread_rwlock_destroy(', LSyncSource) = 0,
    'platform.sync must not call pthread_rwlock_destroy directly in the Unix consumer');
  Check(Pos('platform_posix_map_error(pthread_rwlock_rdlock(', LSyncSource) = 0,
    'platform.sync must not call pthread_rwlock_rdlock directly in the Unix consumer');
  Check(Pos('platform_posix_map_error(pthread_rwlock_tryrdlock(', LSyncSource) = 0,
    'platform.sync must not call pthread_rwlock_tryrdlock directly in the Unix consumer');
  Check(Pos('platform_posix_map_error(pthread_rwlock_wrlock(', LSyncSource) = 0,
    'platform.sync must not call pthread_rwlock_wrlock directly in the Unix consumer');
  Check(Pos('platform_posix_map_error(pthread_rwlock_trywrlock(', LSyncSource) = 0,
    'platform.sync must not call pthread_rwlock_trywrlock directly in the Unix consumer');
  Check(Pos('pthread_rwlock_unlock(', LSyncSource) = 0,
    'platform.sync must not call pthread_rwlock_unlock directly in the Unix consumer');
  Check(Pos('pthread_condattr_init(', LSyncSource) = 0,
    'platform.sync must not call pthread_condattr_init directly in the Unix consumer');
  Check(Pos('pthread_condattr_destroy(', LSyncSource) = 0,
    'platform.sync must not call pthread_condattr_destroy directly in the Unix consumer');
  Check(Pos('platform_pthread_condattr_setclock(', LSyncSource) = 0,
    'platform.sync must not call pthread condattr setclock binding directly in the Unix consumer');
  Check(Pos('pthread_cond_init(', LSyncSource) = 0,
    'platform.sync must not call pthread_cond_init directly in the Unix consumer');
  Check(Pos('pthread_cond_destroy(', LSyncSource) = 0,
    'platform.sync must not call pthread_cond_destroy directly in the Unix consumer');
  Check(Pos('pthread_cond_wait(', LSyncSource) = 0,
    'platform.sync must not call pthread_cond_wait directly in the Unix consumer');
  Check(Pos('pthread_cond_timedwait(', LSyncSource) = 0,
    'platform.sync must not call pthread_cond_timedwait directly in the Unix consumer');
  Check(Pos('pthread_cond_signal(', LSyncSource) = 0,
    'platform.sync must not call pthread_cond_signal directly in the Unix consumer');
  Check(Pos('pthread_cond_broadcast(', LSyncSource) = 0,
    'platform.sync must not call pthread_cond_broadcast directly in the Unix consumer');
  Check(Pos('sched_yield', LSyncSource) = 0,
    'platform.sync must not call sched_yield directly in the Unix consumer');
  Check(Pos('sizeof(pthread_mutex_t)', LSyncSource) = 0,
    'platform.sync must not size raw pthread_mutex_t storage in the Unix consumer');
  Check(Pos('sizeof(pthread_rwlock_t)', LSyncSource) = 0,
    'platform.sync must not size raw pthread_rwlock_t storage in the Unix consumer');
  Check(Pos('sizeof(pthread_cond_t)', LSyncSource) = 0,
    'platform.sync must not size raw pthread_cond_t storage in the Unix consumer');
  Check(Pos('sizeof(srwlock)', LSyncSource) = 0,
    'platform.sync must not size raw SRWLOCK storage in the Windows consumer');
  Check(Pos('sizeof(condition_variable)', LSyncSource) = 0,
    'platform.sync must not size raw CONDITION_VARIABLE storage in the Windows consumer');
  Check(Pos('falign: uint64', LSyncSource) = 0,
    'platform.sync must not keep a generic UInt64 align fallback in the consumer');
  Check(Pos('initializesrwlock', LSyncSource) = 0,
    'platform.sync must not call InitializeSRWLock directly in the Windows consumer');
  Check(Pos('acquiresrwlockexclusive', LSyncSource) = 0,
    'platform.sync must not call AcquireSRWLockExclusive directly in the Windows consumer');
  Check(Pos('tryacquiresrwlockexclusive', LSyncSource) = 0,
    'platform.sync must not call TryAcquireSRWLockExclusive directly in the Windows consumer');
  Check(Pos('releasesrwlockexclusive', LSyncSource) = 0,
    'platform.sync must not call ReleaseSRWLockExclusive directly in the Windows consumer');
  Check(Pos('acquiresrwlockshared', LSyncSource) = 0,
    'platform.sync must not call AcquireSRWLockShared directly in the Windows consumer');
  Check(Pos('tryacquiresrwlockshared', LSyncSource) = 0,
    'platform.sync must not call TryAcquireSRWLockShared directly in the Windows consumer');
  Check(Pos('releasesrwlockshared', LSyncSource) = 0,
    'platform.sync must not call ReleaseSRWLockShared directly in the Windows consumer');
  Check(Pos('sleepconditionvariablesrw', LSyncSource) = 0,
    'platform.sync must not call SleepConditionVariableSRW directly in the Windows consumer');
  Check(Pos('wakeconditionvariable', LSyncSource) = 0,
    'platform.sync must not call WakeConditionVariable directly in the Windows consumer');
  Check(Pos('wakeallconditionvariable', LSyncSource) = 0,
    'platform.sync must not call WakeAllConditionVariable directly in the Windows consumer');
  Check(Pos('waitonaddress', LSyncSource) = 0,
    'platform.sync must not call WaitOnAddress directly in the Windows consumer');
  Check(Pos('wakebyaddresssingle', LSyncSource) = 0,
    'platform.sync must not call WakeByAddressSingle directly in the Windows consumer');
  Check(Pos('wakebyaddressall', LSyncSource) = 0,
    'platform.sync must not call WakeByAddressAll directly in the Windows consumer');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.host_ffi_surface');
  T.Run('platform.sync uses host ffi surface', @TestPlatformSyncUsesHostFFISurface);
  T.Summary;
end.
