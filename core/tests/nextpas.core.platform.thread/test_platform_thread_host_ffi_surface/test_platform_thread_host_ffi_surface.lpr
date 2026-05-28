program test_platform_thread_host_ffi_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  THREAD_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.thread.base.pas';
  THREAD_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.thread.base.pas';
  THREAD_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.thread.pas';
  THREAD_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.thread.pas';
  POSIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';
  LINUX_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.base.pas';
  LINUX_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.base.pas';
  LINUX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.ffi.pas';
  LINUX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.ffi.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.ffi.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.ffi.pas';
  ANDROID_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.ffi.pas';
  ANDROID_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.ffi.pas';
  FREEBSD_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.ffi.pas';
  FREEBSD_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.ffi.pas';
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

procedure TestPlatformThreadRawFFIBoundary;
var
  LThreadBaseSource: string;
  LThreadSource: string;
  LPosixFfiSource: string;
  LLinuxBaseSource: string;
  LLinuxFfiSource: string;
  LDarwinFfiSource: string;
  LAndroidFfiSource: string;
  LFreeBSDFfiSource: string;
  LWindowsBaseSource: string;
  LWindowsFfiSource: string;
begin
  LThreadBaseSource := ReadSourceFile(ResolveSourcePath(THREAD_BASE_SOURCE_PATH_FROM_TEST, THREAD_BASE_SOURCE_PATH_FROM_ROOT));
  LThreadSource := ReadSourceFile(ResolveSourcePath(THREAD_SOURCE_PATH_FROM_TEST, THREAD_SOURCE_PATH_FROM_ROOT));
  LPosixFfiSource := ReadSourceFile(ResolveSourcePath(POSIX_FFI_SOURCE_PATH_FROM_TEST, POSIX_FFI_SOURCE_PATH_FROM_ROOT));
  LLinuxBaseSource := ReadSourceFile(ResolveSourcePath(LINUX_BASE_SOURCE_PATH_FROM_TEST, LINUX_BASE_SOURCE_PATH_FROM_ROOT));
  LLinuxFfiSource := ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT));
  LDarwinFfiSource := ReadSourceFile(ResolveSourcePath(DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT));
  LAndroidFfiSource := ReadSourceFile(ResolveSourcePath(ANDROID_FFI_SOURCE_PATH_FROM_TEST, ANDROID_FFI_SOURCE_PATH_FROM_ROOT));
  LFreeBSDFfiSource := ReadSourceFile(ResolveSourcePath(FREEBSD_FFI_SOURCE_PATH_FROM_TEST, FREEBSD_FFI_SOURCE_PATH_FROM_ROOT));
  LWindowsBaseSource := ReadSourceFile(ResolveSourcePath(WINDOWS_BASE_SOURCE_PATH_FROM_TEST, WINDOWS_BASE_SOURCE_PATH_FROM_ROOT));
  LWindowsFfiSource := ReadSourceFile(ResolveSourcePath(WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LThreadBaseSource, 'tplatformthreadhandle = pointer',
    'platform.thread.base must own public thread handle carrier');
  CheckTokenPresent(LThreadBaseSource, 'tplatformthreadproc = function(aarg: pointer): pointer; cdecl',
    'platform.thread.base must own public thread proc carrier');
  CheckTokenPresent(LThreadSource, 'nextpas.core.platform.thread.base',
    'platform.thread must re-export public thread base');

  CheckTokenPresent(LLinuxBaseSource, 'pplatformpthreadstate',
    'linux.base must own pthread state carrier');
  CheckTokenPresent(LLinuxBaseSource, 'platform_pthread_token_size',
    'linux.base must own pthread token storage size');
  CheckRawFFIUnit(LPosixFfiSource, 'posix.ffi');
  CheckTokenPresent(LPosixFfiSource, 'pthread_create',
    'posix.ffi must own raw pthread_create declaration');
  CheckTokenPresent(LPosixFfiSource, 'pthread_join',
    'posix.ffi must own raw pthread_join declaration');
  CheckTokenPresent(LPosixFfiSource, 'pthread_key_create',
    'posix.ffi must own raw pthread TLS declarations');
  CheckTokenPresent(LPosixFfiSource, 'nanosleep',
    'posix.ffi must own raw nanosleep declaration');
  CheckTokenPresent(LPosixFfiSource, 'sysconf',
    'posix.ffi must own raw sysconf declaration');
  CheckTokenAbsent(LPosixFfiSource, 'platform_posix_pthread_',
    'posix.ffi must not own pthread wrapper helpers');
  CheckTokenAbsent(LPosixFfiSource, 'platform_posix_thread_self_token',
    'posix.ffi must not own thread-token wrappers');

  CheckRawFFIUnit(LLinuxFfiSource, 'linux.ffi');
  CheckRawFFIUnit(LAndroidFfiSource, 'android.ffi');
  CheckRawFFIUnit(LDarwinFfiSource, 'darwin.ffi');
  CheckRawFFIUnit(LFreeBSDFfiSource, 'freebsd.ffi');
  CheckTokenPresent(LLinuxFfiSource, 'function gettid',
    'linux.ffi must own raw gettid declaration');
  CheckTokenPresent(LAndroidFfiSource, 'function gettid',
    'android.ffi must own raw gettid declaration');
  CheckTokenPresent(LDarwinFfiSource, 'pthread_threadid_np',
    'darwin.ffi must own raw pthread_threadid_np declaration');
  CheckTokenPresent(LFreeBSDFfiSource, 'pthread_getthreadid_np',
    'freebsd.ffi must own raw pthread_getthreadid_np declaration');
  CheckTokenAbsent(LLinuxFfiSource, 'linux_pthread_state_create',
    'linux.ffi must not own pthread state wrappers');
  CheckTokenAbsent(LLinuxFfiSource, 'linux_thread_self_token_u64',
    'linux.ffi must not own thread self-token wrappers');
  CheckTokenAbsent(LLinuxFfiSource, 'linux_cpu_count_i32',
    'linux.ffi must not own CPU-count wrappers');

  CheckTokenPresent(LWindowsBaseSource, 'tplatformwindowsthreadstate',
    'windows.base must own Windows thread state carrier');
  CheckRawFFIUnit(LWindowsFfiSource, 'windows.ffi');
  CheckTokenPresent(LWindowsFfiSource, 'createthread',
    'windows.ffi must own raw CreateThread declaration');
  CheckTokenPresent(LWindowsFfiSource, 'waitforsingleobject',
    'windows.ffi must own raw WaitForSingleObject declaration');
  CheckTokenPresent(LWindowsFfiSource, 'getcurrentthreadid',
    'windows.ffi must own raw GetCurrentThreadId declaration');
  CheckTokenPresent(LWindowsFfiSource, 'tlsalloc',
    'windows.ffi must own raw TLS declarations');
  CheckTokenAbsent(LWindowsFfiSource, 'windows_thread_state_create',
    'windows.ffi must not own thread state wrappers');
  CheckTokenAbsent(LWindowsFfiSource, 'windows_tls_create_platform_key',
    'windows.ffi must not own TLS wrapper helpers');

  CheckTokenPresent(LThreadSource, 'pthread_create(',
    'platform.thread must own POSIX pthread create wrapper logic');
  CheckTokenPresent(LThreadSource, 'pthread_join(',
    'platform.thread must own POSIX pthread join wrapper logic');
  CheckTokenPresent(LThreadSource, 'nanosleep(',
    'platform.thread must own POSIX sleep wrapper logic');
  CheckTokenPresent(LThreadSource, 'sysconf(',
    'platform.thread must own POSIX CPU-count wrapper logic');
  CheckTokenPresent(LThreadSource, 'gettid',
    'platform.thread must own Linux/Android native id wrapper logic');
  CheckTokenPresent(LThreadSource, 'createthread',
    'platform.thread must own Windows thread create wrapper logic');
  CheckTokenPresent(LThreadSource, 'waitforsingleobject',
    'platform.thread must own Windows join wrapper logic');
  CheckTokenPresent(LThreadSource, 'tlsalloc',
    'platform.thread must own Windows TLS wrapper logic');
  CheckTokenAbsent(LThreadSource, 'linux_pthread_state_create',
    'platform.thread must not call removed Linux ffi state helper');
  CheckTokenAbsent(LThreadSource, 'windows_thread_state_create',
    'platform.thread must not call removed Windows ffi state helper');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.thread.host_ffi_surface');
  T.Run('platform.thread keeps raw ffi below unified wrappers', @TestPlatformThreadRawFFIBoundary);
  T.Summary;
end.
