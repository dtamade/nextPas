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

  CheckTokenPresent(LAndroidSource, 'function gettid',
    'android.ffi must expose Android native thread id ABI');
  CheckTokenPresent(LAndroidSource, 'name ''gettid''',
    'android.ffi must bind the Android native thread id symbol');

  CheckTokenPresent(LDarwinSource, 'pthread_threadid_np',
    'darwin.ffi must expose macOS native thread id ABI');
  CheckTokenPresent(LFreeBSDSource, 'pthread_getthreadid_np',
    'freebsd.ffi must expose FreeBSD native thread id ABI');

  CheckTokenPresent(LThreadSource, 'function platform_thread_id',
    'platform.thread must continue to expose the thread id contract');
  CheckTokenPresent(LThreadSource, 'gettid',
    'platform.thread must use host native Linux/Android thread id ABI');
  CheckTokenPresent(LThreadSource, 'pthread_threadid_np',
    'platform.thread must use macOS native thread id ABI');
  CheckTokenPresent(LThreadSource, 'pthread_getthreadid_np',
    'platform.thread must use FreeBSD native thread id ABI');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.thread.host_ffi_surface');
  T.Run('platform.thread uses host-native thread id ffi', @TestPlatformThreadUsesHostThreadIdFFI);
  T.Summary;
end.
