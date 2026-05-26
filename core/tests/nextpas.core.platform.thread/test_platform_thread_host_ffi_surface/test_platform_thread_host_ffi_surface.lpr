program test_platform_thread_host_ffi_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  THREAD_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.thread.pas';
  THREAD_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.thread.pas';
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

procedure CheckSharedPosixThreadDelegation(const ASource, AHostLabel: string);
begin
  CheckTokenPresent(ASource, 'platform_posix_thread_self_token_u64',
    AHostLabel + ' must delegate pthread self-token projection to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_sysconf_positive_i32',
    AHostLabel + ' must delegate sysconf positive projection to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_create_handle',
    AHostLabel + ' must delegate pthread create glue to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_join_handle',
    AHostLabel + ' must delegate pthread join glue to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_detach_handle',
    AHostLabel + ' must delegate pthread detach glue to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_yield',
    AHostLabel + ' must delegate pthread yield glue to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_sleep_ns',
    AHostLabel + ' must delegate pthread sleep glue to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_tls_create',
    AHostLabel + ' must delegate pthread TLS create glue to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_tls_destroy',
    AHostLabel + ' must delegate pthread TLS destroy glue to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_tls_set',
    AHostLabel + ' must delegate pthread TLS set glue to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_pthread_tls_get',
    AHostLabel + ' must delegate pthread TLS get glue to shared posix.ffi');
end;

procedure TestPlatformThreadUsesHostThreadIdFFI;
var
  LThreadSource: string;
  LLinuxSource: string;
  LDarwinSource: string;
  LAndroidSource: string;
  LFreeBSDSource: string;
  LUnixSource: string;
  LWindowsSource: string;
begin
  LThreadSource := ReadSourceFile(ResolveSourcePath(THREAD_SOURCE_PATH_FROM_TEST, THREAD_SOURCE_PATH_FROM_ROOT));
  LLinuxSource := ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT));
  LDarwinSource := ReadSourceFile(ResolveSourcePath(DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT));
  LAndroidSource := ReadSourceFile(ResolveSourcePath(ANDROID_FFI_SOURCE_PATH_FROM_TEST, ANDROID_FFI_SOURCE_PATH_FROM_ROOT));
  LFreeBSDSource := ReadSourceFile(ResolveSourcePath(FREEBSD_FFI_SOURCE_PATH_FROM_TEST, FREEBSD_FFI_SOURCE_PATH_FROM_ROOT));
  LUnixSource := ReadSourceFile(ResolveSourcePath(UNIX_FFI_SOURCE_PATH_FROM_TEST, UNIX_FFI_SOURCE_PATH_FROM_ROOT));
  LWindowsSource := ReadSourceFile(ResolveSourcePath(WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LLinuxSource, 'function gettid',
    'linux.ffi must expose Linux native thread id ABI');
  CheckTokenPresent(LLinuxSource, 'name ''gettid''',
    'linux.ffi must bind the Linux native thread id symbol');
  CheckTokenPresent(LLinuxSource, 'platform_posix_eintr',
    'linux.ffi must expose Linux EINTR for retryable nanosleep');
  CheckTokenPresent(LLinuxSource, 'platform_errno_location',
    'linux.ffi must expose Linux errno binding for retryable nanosleep');
  CheckTokenPresent(LLinuxSource, 'platform_posix_errno_value',
    'linux.ffi must expose Linux errno value helper for retryable nanosleep');
  CheckTokenPresent(LLinuxSource, 'platform_thread_self_token_u64',
    'linux.ffi must expose Linux thread self token helper');
  CheckTokenPresent(LLinuxSource, 'platform_native_thread_id_u64',
    'linux.ffi must expose Linux native thread id helper');
  CheckTokenPresent(LLinuxSource, 'platform_cpu_count_i32',
    'linux.ffi must expose Linux CPU count helper');
  CheckTokenPresent(LLinuxSource, 'platform_pthread_create_handle',
    'linux.ffi must expose Linux pthread create helper');
  CheckTokenPresent(LLinuxSource, 'platform_pthread_join_handle',
    'linux.ffi must expose Linux pthread join helper');
  CheckTokenPresent(LLinuxSource, 'platform_pthread_detach_handle',
    'linux.ffi must expose Linux pthread detach helper');
  CheckTokenPresent(LLinuxSource, 'platform_pthread_yield',
    'linux.ffi must expose Linux pthread yield helper');
  CheckTokenPresent(LLinuxSource, 'platform_pthread_sleep_ns',
    'linux.ffi must expose Linux pthread sleep helper');
  CheckTokenPresent(LLinuxSource, 'platform_pthread_tls_create',
    'linux.ffi must expose Linux pthread TLS create helper');
  CheckTokenPresent(LLinuxSource, 'platform_pthread_tls_destroy',
    'linux.ffi must expose Linux pthread TLS destroy helper');
  CheckTokenPresent(LLinuxSource, 'platform_pthread_tls_set',
    'linux.ffi must expose Linux pthread TLS set helper');
  CheckTokenPresent(LLinuxSource, 'platform_pthread_tls_get',
    'linux.ffi must expose Linux pthread TLS get helper');
  CheckTokenPresent(LLinuxSource, 'platform_pthread_token_size',
    'linux.ffi must expose Linux pthread token storage size');
  CheckTokenPresent(LLinuxSource, 'tplatformpthreadtokenalign',
    'linux.ffi must expose Linux pthread token align carrier type');
  CheckSharedPosixThreadDelegation(LLinuxSource, 'linux.ffi');

  CheckTokenPresent(LAndroidSource, 'function gettid',
    'android.ffi must expose Android native thread id ABI');
  CheckTokenPresent(LAndroidSource, 'name ''gettid''',
    'android.ffi must bind the Android native thread id symbol');
  CheckTokenPresent(LAndroidSource, 'platform_posix_eintr',
    'android.ffi must expose Android EINTR for retryable nanosleep');
  CheckTokenPresent(LAndroidSource, 'platform_errno_location',
    'android.ffi must expose Android errno binding for retryable nanosleep');
  CheckTokenPresent(LAndroidSource, 'platform_posix_errno_value',
    'android.ffi must expose Android errno value helper for retryable nanosleep');
  CheckTokenPresent(LAndroidSource, 'platform_thread_self_token_u64',
    'android.ffi must expose Android thread self token helper');
  CheckTokenPresent(LAndroidSource, 'platform_native_thread_id_u64',
    'android.ffi must expose Android native thread id helper');
  CheckTokenPresent(LAndroidSource, 'platform_cpu_count_i32',
    'android.ffi must expose Android CPU count helper');
  CheckTokenPresent(LAndroidSource, 'platform_pthread_create_handle',
    'android.ffi must expose Android pthread create helper');
  CheckTokenPresent(LAndroidSource, 'platform_pthread_join_handle',
    'android.ffi must expose Android pthread join helper');
  CheckTokenPresent(LAndroidSource, 'platform_pthread_detach_handle',
    'android.ffi must expose Android pthread detach helper');
  CheckTokenPresent(LAndroidSource, 'platform_pthread_yield',
    'android.ffi must expose Android pthread yield helper');
  CheckTokenPresent(LAndroidSource, 'platform_pthread_sleep_ns',
    'android.ffi must expose Android pthread sleep helper');
  CheckTokenPresent(LAndroidSource, 'platform_pthread_tls_create',
    'android.ffi must expose Android pthread TLS create helper');
  CheckTokenPresent(LAndroidSource, 'platform_pthread_tls_destroy',
    'android.ffi must expose Android pthread TLS destroy helper');
  CheckTokenPresent(LAndroidSource, 'platform_pthread_tls_set',
    'android.ffi must expose Android pthread TLS set helper');
  CheckTokenPresent(LAndroidSource, 'platform_pthread_tls_get',
    'android.ffi must expose Android pthread TLS get helper');
  CheckTokenPresent(LAndroidSource, 'platform_pthread_token_size',
    'android.ffi must expose Android pthread token storage size');
  CheckTokenPresent(LAndroidSource, 'tplatformpthreadtokenalign',
    'android.ffi must expose Android pthread token align carrier type');
  CheckSharedPosixThreadDelegation(LAndroidSource, 'android.ffi');

  CheckTokenPresent(LDarwinSource, 'pthread_threadid_np',
    'darwin.ffi must expose macOS native thread id ABI');
  CheckTokenPresent(LDarwinSource, 'platform_posix_eintr',
    'darwin.ffi must expose Darwin EINTR for retryable nanosleep');
  CheckTokenPresent(LDarwinSource, 'platform_errno_location',
    'darwin.ffi must expose Darwin errno binding for retryable nanosleep');
  CheckTokenPresent(LDarwinSource, 'platform_posix_errno_value',
    'darwin.ffi must expose Darwin errno value helper for retryable nanosleep');
  CheckTokenPresent(LDarwinSource, 'platform_thread_self_token_u64',
    'darwin.ffi must expose Darwin thread self token helper');
  CheckTokenPresent(LDarwinSource, 'platform_native_thread_id_u64',
    'darwin.ffi must expose Darwin native thread id helper');
  CheckTokenPresent(LDarwinSource, 'platform_cpu_count_i32',
    'darwin.ffi must expose Darwin CPU count helper');
  CheckTokenPresent(LDarwinSource, 'platform_pthread_create_handle',
    'darwin.ffi must expose Darwin pthread create helper');
  CheckTokenPresent(LDarwinSource, 'platform_pthread_join_handle',
    'darwin.ffi must expose Darwin pthread join helper');
  CheckTokenPresent(LDarwinSource, 'platform_pthread_detach_handle',
    'darwin.ffi must expose Darwin pthread detach helper');
  CheckTokenPresent(LDarwinSource, 'platform_pthread_yield',
    'darwin.ffi must expose Darwin pthread yield helper');
  CheckTokenPresent(LDarwinSource, 'platform_pthread_sleep_ns',
    'darwin.ffi must expose Darwin pthread sleep helper');
  CheckTokenPresent(LDarwinSource, 'platform_pthread_tls_create',
    'darwin.ffi must expose Darwin pthread TLS create helper');
  CheckTokenPresent(LDarwinSource, 'platform_pthread_tls_destroy',
    'darwin.ffi must expose Darwin pthread TLS destroy helper');
  CheckTokenPresent(LDarwinSource, 'platform_pthread_tls_set',
    'darwin.ffi must expose Darwin pthread TLS set helper');
  CheckTokenPresent(LDarwinSource, 'platform_pthread_tls_get',
    'darwin.ffi must expose Darwin pthread TLS get helper');
  CheckTokenPresent(LDarwinSource, 'platform_pthread_token_size',
    'darwin.ffi must expose Darwin pthread token storage size');
  CheckTokenPresent(LDarwinSource, 'tplatformpthreadtokenalign',
    'darwin.ffi must expose Darwin pthread token align carrier type');
  CheckSharedPosixThreadDelegation(LDarwinSource, 'darwin.ffi');
  CheckTokenPresent(LFreeBSDSource, 'pthread_getthreadid_np',
    'freebsd.ffi must expose FreeBSD native thread id ABI');
  CheckTokenPresent(LFreeBSDSource, 'platform_posix_eintr',
    'freebsd.ffi must expose FreeBSD EINTR for retryable nanosleep');
  CheckTokenPresent(LFreeBSDSource, 'platform_errno_location',
    'freebsd.ffi must expose FreeBSD errno binding for retryable nanosleep');
  CheckTokenPresent(LFreeBSDSource, 'platform_posix_errno_value',
    'freebsd.ffi must expose FreeBSD errno value helper for retryable nanosleep');
  CheckTokenPresent(LFreeBSDSource, 'platform_thread_self_token_u64',
    'freebsd.ffi must expose FreeBSD thread self token helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_native_thread_id_u64',
    'freebsd.ffi must expose FreeBSD native thread id helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_cpu_count_i32',
    'freebsd.ffi must expose FreeBSD CPU count helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_pthread_create_handle',
    'freebsd.ffi must expose FreeBSD pthread create helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_pthread_join_handle',
    'freebsd.ffi must expose FreeBSD pthread join helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_pthread_detach_handle',
    'freebsd.ffi must expose FreeBSD pthread detach helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_pthread_yield',
    'freebsd.ffi must expose FreeBSD pthread yield helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_pthread_sleep_ns',
    'freebsd.ffi must expose FreeBSD pthread sleep helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_pthread_tls_create',
    'freebsd.ffi must expose FreeBSD pthread TLS create helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_pthread_tls_destroy',
    'freebsd.ffi must expose FreeBSD pthread TLS destroy helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_pthread_tls_set',
    'freebsd.ffi must expose FreeBSD pthread TLS set helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_pthread_tls_get',
    'freebsd.ffi must expose FreeBSD pthread TLS get helper');
  CheckTokenPresent(LFreeBSDSource, 'platform_pthread_token_size',
    'freebsd.ffi must expose FreeBSD pthread token storage size');
  CheckTokenPresent(LFreeBSDSource, 'tplatformpthreadtokenalign',
    'freebsd.ffi must expose FreeBSD pthread token align carrier type');
  CheckSharedPosixThreadDelegation(LFreeBSDSource, 'freebsd.ffi');
  CheckTokenPresent(LUnixSource, 'platform_thread_self_token_u64',
    'unix.ffi must expose generic Unix thread self token helper');
  CheckTokenPresent(LUnixSource, 'platform_native_thread_id_u64',
    'unix.ffi must expose generic Unix native thread id helper');
  CheckTokenPresent(LUnixSource, 'platform_cpu_count_i32',
    'unix.ffi must expose generic Unix CPU count helper');
  CheckTokenPresent(LUnixSource, 'platform_pthread_create_handle',
    'unix.ffi must expose generic Unix pthread create helper');
  CheckTokenPresent(LUnixSource, 'platform_pthread_join_handle',
    'unix.ffi must expose generic Unix pthread join helper');
  CheckTokenPresent(LUnixSource, 'platform_pthread_detach_handle',
    'unix.ffi must expose generic Unix pthread detach helper');
  CheckTokenPresent(LUnixSource, 'platform_pthread_yield',
    'unix.ffi must expose generic Unix pthread yield helper');
  CheckTokenPresent(LUnixSource, 'platform_pthread_sleep_ns',
    'unix.ffi must expose generic Unix pthread sleep helper');
  CheckTokenPresent(LUnixSource, 'platform_pthread_tls_create',
    'unix.ffi must expose generic Unix pthread TLS create helper');
  CheckTokenPresent(LUnixSource, 'platform_pthread_tls_destroy',
    'unix.ffi must expose generic Unix pthread TLS destroy helper');
  CheckTokenPresent(LUnixSource, 'platform_pthread_tls_set',
    'unix.ffi must expose generic Unix pthread TLS set helper');
  CheckTokenPresent(LUnixSource, 'platform_pthread_tls_get',
    'unix.ffi must expose generic Unix pthread TLS get helper');
  CheckTokenPresent(LUnixSource, 'platform_pthread_token_size',
    'unix.ffi must expose generic Unix pthread token storage size');
  CheckTokenPresent(LUnixSource, 'tplatformpthreadtokenalign',
    'unix.ffi must expose generic Unix pthread token align carrier type');
  CheckSharedPosixThreadDelegation(LUnixSource, 'unix.ffi');
  CheckTokenPresent(LWindowsSource, 'windows_sleep_ns_to_ms',
    'windows.ffi must expose Windows sleep timeout conversion policy');
  CheckTokenPresent(LWindowsSource, 'windows_last_error_i32',
    'windows.ffi must expose Windows last-error conversion helper');
  CheckTokenPresent(LWindowsSource, 'windows_wait_for_single_object_is_signaled',
    'windows.ffi must expose Windows wait-result success semantics');
  CheckTokenPresent(LWindowsSource, 'windows_current_thread_id_u64',
    'windows.ffi must expose Windows current-thread id helper');
  CheckTokenPresent(LWindowsSource, 'windows_thread_yield',
    'windows.ffi must expose Windows thread yield helper');
  CheckTokenPresent(LWindowsSource, 'tplatformwindowsthreadproc',
    'windows.ffi must expose a Windows user-thread proc carrier type');
  CheckTokenPresent(LWindowsSource, 'pplatformwindowsthreadstate',
    'windows.ffi must expose a Windows thread state pointer type');
  CheckTokenPresent(LWindowsSource, 'tplatformwindowsthreadstate',
    'windows.ffi must expose a Windows thread state carrier record');
  CheckTokenPresent(LWindowsSource, 'windows_tls_alloc_key',
    'windows.ffi must expose Windows TLS alloc helper');
  CheckTokenPresent(LWindowsSource, 'windows_tls_free_key',
    'windows.ffi must expose Windows TLS free helper');
  CheckTokenPresent(LWindowsSource, 'windows_tls_set_value',
    'windows.ffi must expose Windows TLS set helper');
  CheckTokenPresent(LWindowsSource, 'windows_tls_get_value',
    'windows.ffi must expose Windows TLS get helper');
  CheckTokenPresent(LWindowsSource, 'windows_cpu_count_i32',
    'windows.ffi must expose Windows CPU count helper');
  CheckTokenPresent(LWindowsSource, 'windows_thread_create_handle',
    'windows.ffi must expose Windows thread create helper');
  CheckTokenPresent(LWindowsSource, 'windows_thread_wait_terminated',
    'windows.ffi must expose Windows thread wait helper');
  CheckTokenPresent(LWindowsSource, 'windows_thread_close_handle',
    'windows.ffi must expose Windows thread close helper');
  CheckTokenPresent(LWindowsSource, 'windows_thread_sleep_ns',
    'windows.ffi must expose Windows thread sleep helper');
  CheckTokenPresent(LWindowsSource, 'windows_atomic_decrement_i32',
    'windows.ffi must expose Windows atomic decrement helper');
  CheckTokenPresent(LWindowsSource, 'windows_thread_state_create',
    'windows.ffi must expose a Windows thread-state create helper');
  CheckTokenPresent(LWindowsSource, 'windows_thread_state_join',
    'windows.ffi must expose a Windows thread-state join helper');
  CheckTokenPresent(LWindowsSource, 'windows_thread_state_detach',
    'windows.ffi must expose a Windows thread-state detach helper');
  CheckTokenPresent(LWindowsSource, 'windows_tls_create_platform_key',
    'windows.ffi must expose a platform-neutral Windows TLS create helper');
  CheckTokenPresent(LWindowsSource, 'windows_tls_destroy_platform_key',
    'windows.ffi must expose a platform-neutral Windows TLS destroy helper');
  CheckTokenPresent(LWindowsSource, 'windows_tls_set_platform_key',
    'windows.ffi must expose a platform-neutral Windows TLS set helper');
  CheckTokenPresent(LWindowsSource, 'windows_tls_get_platform_key',
    'windows.ffi must expose a platform-neutral Windows TLS get helper');

  CheckTokenPresent(LThreadSource, 'function platform_thread_id',
    'platform.thread must continue to expose the thread id contract');
  CheckTokenPresent(LThreadSource, 'platform_thread_self_token_u64',
    'platform.thread must use host-owned thread self token helper');
  CheckTokenPresent(LThreadSource, 'platform_native_thread_id_u64',
    'platform.thread must use host-owned native thread id helper');
  CheckTokenPresent(LThreadSource, 'platform_cpu_count_i32',
    'platform.thread must use host-owned CPU count helper');
  CheckTokenPresent(LThreadSource, 'platform_pthread_create_handle',
    'platform.thread must consume host-owned pthread create helper');
  CheckTokenPresent(LThreadSource, 'platform_pthread_join_handle',
    'platform.thread must consume host-owned pthread join helper');
  CheckTokenPresent(LThreadSource, 'platform_pthread_detach_handle',
    'platform.thread must consume host-owned pthread detach helper');
  CheckTokenPresent(LThreadSource, 'platform_pthread_yield',
    'platform.thread must consume host-owned pthread yield helper');
  CheckTokenPresent(LThreadSource, 'platform_pthread_sleep_ns',
    'platform.thread must consume host-owned pthread sleep helper');
  CheckTokenPresent(LThreadSource, 'platform_pthread_tls_create',
    'platform.thread must consume host-owned pthread TLS create helper');
  CheckTokenPresent(LThreadSource, 'platform_pthread_tls_destroy',
    'platform.thread must consume host-owned pthread TLS destroy helper');
  CheckTokenPresent(LThreadSource, 'platform_pthread_tls_set',
    'platform.thread must consume host-owned pthread TLS set helper');
  CheckTokenPresent(LThreadSource, 'platform_pthread_tls_get',
    'platform.thread must consume host-owned pthread TLS get helper');
  CheckTokenPresent(LThreadSource, 'platform_pthread_token_size',
    'platform.thread must consume host-owned pthread token storage size');
  CheckTokenPresent(LThreadSource, 'tplatformpthreadtokenalign',
    'platform.thread must consume host-owned pthread token align carrier');
  Check(Pos('platform_posix_eintr', LThreadSource) = 0,
    'platform.thread must not keep raw EINTR retry semantics in the Unix consumer');
  Check(Pos('platform_posix_errno_value', LThreadSource) = 0,
    'platform.thread must not keep raw errno read helper usage in the Unix consumer');
  Check(Pos('platform_errno_location^', LThreadSource) = 0,
    'platform.thread must not dereference errno storage directly in the consumer');
  CheckTokenPresent(LThreadSource, 'windows_current_thread_id_u64',
    'platform.thread must consume Windows current-thread id helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_thread_yield',
    'platform.thread must consume Windows thread yield helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'pplatformwindowsthreadstate',
    'platform.thread must consume the Windows thread state type through windows.ffi');
  CheckTokenPresent(LThreadSource, 'tplatformwindowsthreadproc',
    'platform.thread must consume the Windows user-thread proc carrier through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_thread_state_create',
    'platform.thread must consume the Windows thread-state create helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_thread_state_join',
    'platform.thread must consume the Windows thread-state join helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_thread_state_detach',
    'platform.thread must consume the Windows thread-state detach helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_tls_create_platform_key',
    'platform.thread must consume the platform-neutral Windows TLS create helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_tls_destroy_platform_key',
    'platform.thread must consume the platform-neutral Windows TLS destroy helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_tls_set_platform_key',
    'platform.thread must consume the platform-neutral Windows TLS set helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_tls_get_platform_key',
    'platform.thread must consume the platform-neutral Windows TLS get helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_cpu_count_i32',
    'platform.thread must consume Windows CPU count helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_thread_sleep_ns',
    'platform.thread must consume Windows thread sleep helper through windows.ffi');
  Check(Pos('getlasterror', LThreadSource) = 0,
    'platform.thread must not call GetLastError directly in the Windows consumer');
  Check(Pos('wait_object_0', LThreadSource) = 0,
    'platform.thread must not keep a raw WaitForSingleObject success token');
  Check(Pos('$ffffffff', LThreadSource) = 0,
    'platform.thread must not keep a raw Windows sleep saturation literal');
  Check(Pos('getcurrentthreadid', LThreadSource) = 0,
    'platform.thread must not call GetCurrentThreadId directly in the Windows consumer');
  Check(Pos('switchtothread', LThreadSource) = 0,
    'platform.thread must not call SwitchToThread directly in the Windows consumer');
  Check(Pos('tlsalloc', LThreadSource) = 0,
    'platform.thread must not call TlsAlloc directly in the Windows consumer');
  Check(Pos('tlsfree', LThreadSource) = 0,
    'platform.thread must not call TlsFree directly in the Windows consumer');
  Check(Pos('tlssetvalue', LThreadSource) = 0,
    'platform.thread must not call TlsSetValue directly in the Windows consumer');
  Check(Pos('tlsgetvalue', LThreadSource) = 0,
    'platform.thread must not call TlsGetValue directly in the Windows consumer');
  Check(Pos('getsysteminfo', LThreadSource) = 0,
    'platform.thread must not call GetSystemInfo directly in the Windows consumer');
  Check(Pos('createthread', LThreadSource) = 0,
    'platform.thread must not call CreateThread directly in the Windows consumer');
  Check(Pos('waitforsingleobject', LThreadSource) = 0,
    'platform.thread must not call WaitForSingleObject directly in the Windows consumer');
  Check(Pos('closehandle', LThreadSource) = 0,
    'platform.thread must not call CloseHandle directly in the Windows consumer');
  Check(Pos('sleep(lms)', LThreadSource) = 0,
    'platform.thread must not call Sleep directly in the Windows consumer');
  Check(Pos('interlockeddecrement', LThreadSource) = 0,
    'platform.thread must not call InterlockedDecrement directly in the Windows consumer');
  Check(Pos('windows_tls_alloc_key', LThreadSource) = 0,
    'platform.thread must not keep the raw Windows TLS alloc helper in the consumer');
  Check(Pos('windows_tls_free_key', LThreadSource) = 0,
    'platform.thread must not keep the raw Windows TLS free helper in the consumer');
  Check(Pos('windows_tls_set_value', LThreadSource) = 0,
    'platform.thread must not keep the raw Windows TLS set helper in the consumer');
  Check(Pos('windows_tls_get_value', LThreadSource) = 0,
    'platform.thread must not keep the raw Windows TLS get helper in the consumer');
  Check(Pos('windows_thread_create_handle', LThreadSource) = 0,
    'platform.thread must not keep the raw Windows thread-create helper in the consumer');
  Check(Pos('windows_thread_wait_terminated', LThreadSource) = 0,
    'platform.thread must not keep the raw Windows thread-wait helper in the consumer');
  Check(Pos('windows_thread_close_handle', LThreadSource) = 0,
    'platform.thread must not keep the raw Windows thread-close helper in the consumer');
  Check(Pos('windows_atomic_decrement_i32', LThreadSource) = 0,
    'platform.thread must not keep the raw Windows atomic decrement helper in the consumer');
  Check(Pos('handle: handle', LThreadSource) = 0,
    'platform.thread must not keep raw HANDLE fields in the Windows consumer');
  Check(Pos(': dword', LThreadSource) = 0,
    'platform.thread must not keep raw DWORD types in the Windows consumer');
  Check(Pos('stdcall', LThreadSource) = 0,
    'platform.thread must not keep a raw stdcall Windows entry thunk in the consumer');
  Check(Pos('pthread_create(', LThreadSource) = 0,
    'platform.thread must not call pthread_create directly in the Unix consumer');
  Check(Pos('pthread_join(', LThreadSource) = 0,
    'platform.thread must not call pthread_join directly in the Unix consumer');
  Check(Pos('pthread_detach(', LThreadSource) = 0,
    'platform.thread must not call pthread_detach directly in the Unix consumer');
  Check(Pos('pthread_key_create(', LThreadSource) = 0,
    'platform.thread must not call pthread_key_create directly in the Unix consumer');
  Check(Pos('pthread_key_delete(', LThreadSource) = 0,
    'platform.thread must not call pthread_key_delete directly in the Unix consumer');
  Check(Pos('pthread_setspecific(', LThreadSource) = 0,
    'platform.thread must not call pthread_setspecific directly in the Unix consumer');
  Check(Pos('pthread_getspecific(', LThreadSource) = 0,
    'platform.thread must not call pthread_getspecific directly in the Unix consumer');
  Check(Pos('sched_yield', LThreadSource) = 0,
    'platform.thread must not call sched_yield directly in the Unix consumer');
  Check(Pos('nanosleep(', LThreadSource) = 0,
    'platform.thread must not call nanosleep directly in the Unix consumer');
  Check(Pos('pthread_self', LThreadSource) = 0,
    'platform.thread must not call pthread_self directly in the Unix consumer');
  Check(Pos('sysconf(', LThreadSource) = 0,
    'platform.thread must not call sysconf directly in the Unix consumer');
  Check(Pos('gettid', LThreadSource) = 0,
    'platform.thread must not call gettid directly in the consumer');
  Check(Pos('pthread_threadid_np', LThreadSource) = 0,
    'platform.thread must not call pthread_threadid_np directly in the consumer');
  Check(Pos('pthread_getthreadid_np', LThreadSource) = 0,
    'platform.thread must not call pthread_getthreadid_np directly in the consumer');
  Check(Pos('thread: pthread_t', LThreadSource) = 0,
    'platform.thread must not keep raw pthread_t thread storage in the Unix consumer');
  Check(Pos('ppthreadtoken', LThreadSource) = 0,
    'platform.thread must not reintroduce raw pthread_t pointer aliases in the Unix consumer');
  Check(Pos('falign: ptruint', LThreadSource) = 0,
    'platform.thread must not keep a generic PtrUInt align fallback in the Unix consumer');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.thread.host_ffi_surface');
  T.Run('platform.thread uses host-native thread id ffi', @TestPlatformThreadUsesHostThreadIdFFI);
  T.Summary;
end.
