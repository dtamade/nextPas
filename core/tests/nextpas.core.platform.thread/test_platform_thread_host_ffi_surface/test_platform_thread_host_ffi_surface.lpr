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
  CheckTokenPresent(LUnixSource, 'platform_thread_self_token_u64',
    'unix.ffi must expose generic Unix thread self token helper');
  CheckTokenPresent(LUnixSource, 'platform_native_thread_id_u64',
    'unix.ffi must expose generic Unix native thread id helper');
  CheckTokenPresent(LUnixSource, 'platform_cpu_count_i32',
    'unix.ffi must expose generic Unix CPU count helper');
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

  CheckTokenPresent(LThreadSource, 'function platform_thread_id',
    'platform.thread must continue to expose the thread id contract');
  CheckTokenPresent(LThreadSource, 'platform_posix_eintr',
    'platform.thread must use host-owned EINTR token for nanosleep retry semantics');
  CheckTokenPresent(LThreadSource, 'platform_posix_errno_value',
    'platform.thread must use host-owned errno value helper for nanosleep retry semantics');
  CheckTokenPresent(LThreadSource, 'platform_thread_self_token_u64',
    'platform.thread must use host-owned thread self token helper');
  CheckTokenPresent(LThreadSource, 'platform_native_thread_id_u64',
    'platform.thread must use host-owned native thread id helper');
  CheckTokenPresent(LThreadSource, 'platform_cpu_count_i32',
    'platform.thread must use host-owned CPU count helper');
  Check(Pos('platform_errno_location^', LThreadSource) = 0,
    'platform.thread must not dereference errno storage directly in the consumer');
  CheckTokenPresent(LThreadSource, 'windows_current_thread_id_u64',
    'platform.thread must consume Windows current-thread id helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_thread_yield',
    'platform.thread must consume Windows thread yield helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_tls_alloc_key',
    'platform.thread must consume Windows TLS alloc helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_tls_free_key',
    'platform.thread must consume Windows TLS free helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_tls_set_value',
    'platform.thread must consume Windows TLS set helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_tls_get_value',
    'platform.thread must consume Windows TLS get helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_cpu_count_i32',
    'platform.thread must consume Windows CPU count helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_thread_create_handle',
    'platform.thread must consume Windows thread create helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_thread_wait_terminated',
    'platform.thread must consume Windows thread wait helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_thread_close_handle',
    'platform.thread must consume Windows thread close helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_thread_sleep_ns',
    'platform.thread must consume Windows thread sleep helper through windows.ffi');
  CheckTokenPresent(LThreadSource, 'windows_atomic_decrement_i32',
    'platform.thread must consume Windows atomic decrement helper through windows.ffi');
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
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.thread.host_ffi_surface');
  T.Run('platform.thread uses host-native thread id ffi', @TestPlatformThreadUsesHostThreadIdFFI);
  T.Summary;
end.
