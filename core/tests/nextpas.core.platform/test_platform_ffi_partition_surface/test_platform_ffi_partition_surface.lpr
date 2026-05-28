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
    ALabel + ' must own raw external declarations');
  CheckTokenAbsent(ASource, ' inline',
    ALabel + ' must not own inline helper declarations');
  CheckTokenAbsent(ASource, 'implementation' + #10 + 'uses',
    ALabel + ' must not own implementation helper imports');
  CheckTokenAbsent(ASource, 'begin' + #10,
    ALabel + ' must not own helper bodies');
end;

procedure CheckHostPartition(
  const ABaseSource,
  AFfiSource,
  AHostLabel,
  ABaseToken,
  AFfiToken: string);
begin
  CheckTokenPresent(ABaseSource, ABaseToken,
    AHostLabel + ' base must own host ABI data token');
  CheckTokenPresent(AFfiSource, AFfiToken,
    AHostLabel + ' ffi must own host raw external token');
  CheckRawFFIUnit(AFfiSource, AHostLabel + '.ffi');
end;

procedure TestPlatformFFIPartition;
var
  LPosixBaseSource: string;
  LPosixFfiSource: string;
  LLinuxBaseSource: string;
  LLinuxFfiSource: string;
  LDarwinBaseSource: string;
  LDarwinFfiSource: string;
  LAndroidBaseSource: string;
  LAndroidFfiSource: string;
  LFreeBSDBaseSource: string;
  LFreeBSDFfiSource: string;
  LUnixBaseSource: string;
  LUnixFfiSource: string;
  LWindowsBaseSource: string;
  LWindowsFfiSource: string;
begin
  LPosixBaseSource := ReadSourceFile(ResolveSourcePath(POSIX_BASE_SOURCE_PATH_FROM_TEST, POSIX_BASE_SOURCE_PATH_FROM_ROOT));
  LPosixFfiSource := ReadSourceFile(ResolveSourcePath(POSIX_FFI_SOURCE_PATH_FROM_TEST, POSIX_FFI_SOURCE_PATH_FROM_ROOT));
  LLinuxBaseSource := ReadSourceFile(ResolveSourcePath(LINUX_BASE_SOURCE_PATH_FROM_TEST, LINUX_BASE_SOURCE_PATH_FROM_ROOT));
  LLinuxFfiSource := ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT));
  LDarwinBaseSource := ReadSourceFile(ResolveSourcePath(DARWIN_BASE_SOURCE_PATH_FROM_TEST, DARWIN_BASE_SOURCE_PATH_FROM_ROOT));
  LDarwinFfiSource := ReadSourceFile(ResolveSourcePath(DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT));
  LAndroidBaseSource := ReadSourceFile(ResolveSourcePath(ANDROID_BASE_SOURCE_PATH_FROM_TEST, ANDROID_BASE_SOURCE_PATH_FROM_ROOT));
  LAndroidFfiSource := ReadSourceFile(ResolveSourcePath(ANDROID_FFI_SOURCE_PATH_FROM_TEST, ANDROID_FFI_SOURCE_PATH_FROM_ROOT));
  LFreeBSDBaseSource := ReadSourceFile(ResolveSourcePath(FREEBSD_BASE_SOURCE_PATH_FROM_TEST, FREEBSD_BASE_SOURCE_PATH_FROM_ROOT));
  LFreeBSDFfiSource := ReadSourceFile(ResolveSourcePath(FREEBSD_FFI_SOURCE_PATH_FROM_TEST, FREEBSD_FFI_SOURCE_PATH_FROM_ROOT));
  LUnixBaseSource := ReadSourceFile(ResolveSourcePath(UNIX_BASE_SOURCE_PATH_FROM_TEST, UNIX_BASE_SOURCE_PATH_FROM_ROOT));
  LUnixFfiSource := ReadSourceFile(ResolveSourcePath(UNIX_FFI_SOURCE_PATH_FROM_TEST, UNIX_FFI_SOURCE_PATH_FROM_ROOT));
  LWindowsBaseSource := ReadSourceFile(ResolveSourcePath(WINDOWS_BASE_SOURCE_PATH_FROM_TEST, WINDOWS_BASE_SOURCE_PATH_FROM_ROOT));
  LWindowsFfiSource := ReadSourceFile(ResolveSourcePath(WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LPosixBaseSource, 'timespec',
    'posix.base must own shared POSIX record shapes');
  CheckTokenPresent(LPosixBaseSource, 'pthread_mutex_t',
    'posix.base must own shared pthread opaque shapes');
  CheckRawFFIUnit(LPosixFfiSource, 'posix.ffi');
  CheckTokenPresent(LPosixFfiSource, 'clock_gettime',
    'posix.ffi must own shared POSIX clock external declaration');
  CheckTokenPresent(LPosixFfiSource, 'pthread_create',
    'posix.ffi must own shared POSIX pthread external declaration');
  CheckTokenAbsent(LPosixFfiSource, 'platform_posix_pthread_',
    'posix.ffi must not own shared POSIX pthread wrappers');

  CheckHostPartition(LLinuxBaseSource, LLinuxFfiSource, 'linux',
    'linux_syscall_futex', 'function linux_syscall');
  CheckHostPartition(LDarwinBaseSource, LDarwinFfiSource, 'darwin',
    'mach_timebase_info_data_t', 'mach_absolute_time');
  CheckHostPartition(LAndroidBaseSource, LAndroidFfiSource, 'android',
    'platform_clock_monotonic_id', 'function gettid');
  CheckHostPartition(LFreeBSDBaseSource, LFreeBSDFfiSource, 'freebsd',
    'platform_clock_monotonic_id', 'pthread_getthreadid_np');
  CheckHostPartition(LUnixBaseSource, LUnixFfiSource, 'unix',
    'platform_clock_monotonic_id', 'function unix_errno_location');
  CheckHostPartition(LWindowsBaseSource, LWindowsFfiSource, 'windows',
    'windows_filetime_unix_epoch_offset_100ns', 'queryperformancecounter');

  CheckTokenPresent(LLinuxBaseSource, 'platform_posix_eintr',
    'linux.base must own Linux POSIX errno tokens');
  CheckTokenPresent(LWindowsBaseSource, 'wait_object_0',
    'windows.base must own Windows wait result tokens');
  CheckTokenAbsent(LLinuxFfiSource, 'linux_errno_value',
    'linux.ffi must not own errno value helper');
  CheckTokenAbsent(LWindowsFfiSource, 'windows_last_error_i32',
    'windows.ffi must not own last-error helper');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.ffi_partition_surface');
  T.Run('platform ffi is partitioned by host as raw declarations', @TestPlatformFFIPartition);
  T.Summary;
end.
