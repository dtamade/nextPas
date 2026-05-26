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
begin
  LThreadSource := ReadSourceFile(ResolveSourcePath(THREAD_SOURCE_PATH_FROM_TEST, THREAD_SOURCE_PATH_FROM_ROOT));
  LLinuxSource := ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT));
  LDarwinSource := ReadSourceFile(ResolveSourcePath(DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT));
  LAndroidSource := ReadSourceFile(ResolveSourcePath(ANDROID_FFI_SOURCE_PATH_FROM_TEST, ANDROID_FFI_SOURCE_PATH_FROM_ROOT));
  LFreeBSDSource := ReadSourceFile(ResolveSourcePath(FREEBSD_FFI_SOURCE_PATH_FROM_TEST, FREEBSD_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LLinuxSource, 'function gettid',
    'linux.ffi must expose Linux native thread id ABI');
  CheckTokenPresent(LLinuxSource, 'name ''gettid''',
    'linux.ffi must bind the Linux native thread id symbol');
  CheckTokenPresent(LLinuxSource, 'platform_posix_eintr',
    'linux.ffi must expose Linux EINTR for retryable nanosleep');
  CheckTokenPresent(LLinuxSource, 'platform_errno_location',
    'linux.ffi must expose Linux errno binding for retryable nanosleep');

  CheckTokenPresent(LAndroidSource, 'function gettid',
    'android.ffi must expose Android native thread id ABI');
  CheckTokenPresent(LAndroidSource, 'name ''gettid''',
    'android.ffi must bind the Android native thread id symbol');
  CheckTokenPresent(LAndroidSource, 'platform_posix_eintr',
    'android.ffi must expose Android EINTR for retryable nanosleep');
  CheckTokenPresent(LAndroidSource, 'platform_errno_location',
    'android.ffi must expose Android errno binding for retryable nanosleep');

  CheckTokenPresent(LDarwinSource, 'pthread_threadid_np',
    'darwin.ffi must expose macOS native thread id ABI');
  CheckTokenPresent(LDarwinSource, 'platform_posix_eintr',
    'darwin.ffi must expose Darwin EINTR for retryable nanosleep');
  CheckTokenPresent(LDarwinSource, 'platform_errno_location',
    'darwin.ffi must expose Darwin errno binding for retryable nanosleep');
  CheckTokenPresent(LFreeBSDSource, 'pthread_getthreadid_np',
    'freebsd.ffi must expose FreeBSD native thread id ABI');
  CheckTokenPresent(LFreeBSDSource, 'platform_posix_eintr',
    'freebsd.ffi must expose FreeBSD EINTR for retryable nanosleep');
  CheckTokenPresent(LFreeBSDSource, 'platform_errno_location',
    'freebsd.ffi must expose FreeBSD errno binding for retryable nanosleep');

  CheckTokenPresent(LThreadSource, 'function platform_thread_id',
    'platform.thread must continue to expose the thread id contract');
  CheckTokenPresent(LThreadSource, 'gettid',
    'platform.thread must use host native Linux/Android thread id ABI');
  CheckTokenPresent(LThreadSource, 'pthread_threadid_np',
    'platform.thread must use macOS native thread id ABI');
  CheckTokenPresent(LThreadSource, 'pthread_getthreadid_np',
    'platform.thread must use FreeBSD native thread id ABI');
  CheckTokenPresent(LThreadSource, 'platform_posix_eintr',
    'platform.thread must use host-owned EINTR token for nanosleep retry semantics');
  CheckTokenPresent(LThreadSource, 'platform_errno_location',
    'platform.thread must use host-owned errno binding for nanosleep retry semantics');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.thread.host_ffi_surface');
  T.Run('platform.thread uses host-native thread id ffi', @TestPlatformThreadUsesHostThreadIdFFI);
  T.Summary;
end.
