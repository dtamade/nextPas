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

  CheckTokenPresent(LDarwinSource, 'platform_posix_errno_value',
    'darwin.ffi must expose Darwin errno value helper for sync');
  CheckTokenPresent(LAndroidSource, 'platform_posix_errno_value',
    'android.ffi must expose Android errno value helper for sync');
  CheckTokenPresent(LFreeBSDSource, 'platform_posix_errno_value',
    'freebsd.ffi must expose FreeBSD errno value helper for sync');
  CheckTokenPresent(LUnixSource, 'platform_posix_errno_value',
    'unix.ffi must expose generic Unix errno value helper for sync');

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
  CheckTokenPresent(LWindowsSource, 'windows_condvar_signal',
    'windows.ffi must expose Windows condvar signal helper');
  CheckTokenPresent(LWindowsSource, 'windows_condvar_broadcast',
    'windows.ffi must expose Windows condvar broadcast helper');
  CheckTokenPresent(LWindowsSource, 'windows_wait_address_i32',
    'windows.ffi must expose Windows wait-address helper');
  CheckTokenPresent(LWindowsSource, 'windows_wake_address_single',
    'windows.ffi must expose Windows wake-address-single helper');
  CheckTokenPresent(LWindowsSource, 'windows_wake_address_all',
    'windows.ffi must expose Windows wake-address-all helper');

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

  CheckTokenPresent(LSyncSource, 'platform_posix_errno_value',
    'platform.sync must consume host-owned errno value helper');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_normal_kind',
    'platform.sync must consume host-owned pthread mutex normal numbering');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_recursive_kind',
    'platform.sync must consume host-owned pthread mutex recursive numbering');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_errorcheck_kind',
    'platform.sync must consume host-owned pthread mutex errorcheck numbering');
  CheckTokenPresent(LSyncSource, 'platform_pthread_condattr_setclock_supported',
    'platform.sync must consume host-owned pthread condattr clock capability');
  CheckTokenPresent(LSyncSource, 'platform_pthread_condattr_setclock',
    'platform.sync must consume host-owned pthread condattr clock binding');
  CheckTokenPresent(LSyncSource, 'platform_pthread_timeout_clock_id',
    'platform.sync must consume host-owned pthread timeout clock policy');
  CheckTokenPresent(LSyncSource, 'linux_futex_wait_i32',
    'platform.sync must consume Linux futex wait helper through linux.ffi');
  CheckTokenPresent(LSyncSource, 'linux_futex_wake_one_i32',
    'platform.sync must consume Linux futex wake-one helper through linux.ffi');
  CheckTokenPresent(LSyncSource, 'linux_futex_wake_all_i32',
    'platform.sync must consume Linux futex wake-all helper through linux.ffi');
  CheckTokenPresent(LSyncSource, 'windows_timeout_ns_to_ms',
    'platform.sync must consume Windows wait timeout conversion through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_last_error_is_timeout',
    'platform.sync must consume Windows timeout-result semantics through windows.ffi');
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
  CheckTokenPresent(LSyncSource, 'windows_condvar_timedwait_ms',
    'platform.sync must consume Windows condvar timedwait helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_condvar_signal',
    'platform.sync must consume Windows condvar signal helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_condvar_broadcast',
    'platform.sync must consume Windows condvar broadcast helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_wait_address_i32',
    'platform.sync must consume Windows wait-address helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_wake_address_single',
    'platform.sync must consume Windows wake-address-single helper through windows.ffi');
  CheckTokenPresent(LSyncSource, 'windows_wake_address_all',
    'platform.sync must consume Windows wake-address-all helper through windows.ffi');
  Check(Pos('platform_errno_location^', LSyncSource) = 0,
    'platform.sync must not dereference errno storage directly in the consumer');
  Check(Pos('getlasterror', LSyncSource) = 0,
    'platform.sync must not call GetLastError directly in the Windows consumer');
  Check(Pos('error_timeout', LSyncSource) = 0,
    'platform.sync must not keep a raw Windows timeout-result token');
  Check(Pos('function platform_timeout_ns_to_ms', LSyncSource) = 0,
    'platform.sync must not keep a local Windows timeout conversion helper');
  Check(Pos('linux_syscall', LSyncSource) = 0,
    'platform.sync must not call linux_syscall directly in the Linux consumer');
  Check(Pos('futex_wait or futex_private_flag', LSyncSource) = 0,
    'platform.sync must not assemble raw FUTEX_WAIT operations in the Linux consumer');
  Check(Pos('futex_wake or futex_private_flag', LSyncSource) = 0,
    'platform.sync must not assemble raw FUTEX_WAKE operations in the Linux consumer');
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
