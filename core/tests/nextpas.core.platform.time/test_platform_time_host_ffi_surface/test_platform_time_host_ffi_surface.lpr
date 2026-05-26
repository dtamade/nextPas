program test_platform_time_host_ffi_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  TIME_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.time.pas';
  TIME_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.time.pas';
  LINUX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.ffi.pas';
  LINUX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.ffi.pas';
  ANDROID_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.ffi.pas';
  ANDROID_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.ffi.pas';
  FREEBSD_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.ffi.pas';
  FREEBSD_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.ffi.pas';
  UNIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.unix.ffi.pas';
  UNIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.unix.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.ffi.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.ffi.pas';
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

procedure CheckPosixClockHelperSet(const ASource, AHostLabel: string);
begin
  CheckTokenPresent(ASource, 'platform_clock_monotonic_now',
    AHostLabel + ' must expose host monotonic clock helper for platform.time');
  CheckTokenPresent(ASource, 'platform_clock_realtime_now',
    AHostLabel + ' must expose host realtime clock helper for platform.time');
  CheckTokenPresent(ASource, 'platform_clock_monotonic_getres',
    AHostLabel + ' must expose host monotonic clock resolution helper for platform.time');
  CheckTokenPresent(ASource, 'platform_clock_monotonic_ns_u64',
    AHostLabel + ' must expose host-owned monotonic nanosecond helper for platform.time');
  CheckTokenPresent(ASource, 'platform_clock_realtime_ns_u64',
    AHostLabel + ' must expose host-owned realtime nanosecond helper for platform.time');
  CheckTokenPresent(ASource, 'platform_clock_monotonic_resolution_ns_u64',
    AHostLabel + ' must expose host-owned monotonic resolution nanosecond helper for platform.time');
end;

procedure TestPlatformTimeUsesHostClockFFI;
var
  LTimeSource: string;
  LLinuxSource: string;
  LAndroidSource: string;
  LFreeBSDSource: string;
  LUnixSource: string;
  LPosixSource: string;
  LDarwinSource: string;
  LWindowsSource: string;
begin
  LTimeSource := ReadSourceFile(ResolveSourcePath(TIME_SOURCE_PATH_FROM_TEST, TIME_SOURCE_PATH_FROM_ROOT));
  LLinuxSource := ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT));
  LAndroidSource := ReadSourceFile(ResolveSourcePath(ANDROID_FFI_SOURCE_PATH_FROM_TEST, ANDROID_FFI_SOURCE_PATH_FROM_ROOT));
  LFreeBSDSource := ReadSourceFile(ResolveSourcePath(FREEBSD_FFI_SOURCE_PATH_FROM_TEST, FREEBSD_FFI_SOURCE_PATH_FROM_ROOT));
  LUnixSource := ReadSourceFile(ResolveSourcePath(UNIX_FFI_SOURCE_PATH_FROM_TEST, UNIX_FFI_SOURCE_PATH_FROM_ROOT));
  LPosixSource := ReadSourceFile(ResolveSourcePath(POSIX_FFI_SOURCE_PATH_FROM_TEST, POSIX_FFI_SOURCE_PATH_FROM_ROOT));
  LDarwinSource := ReadSourceFile(ResolveSourcePath(DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT));
  LWindowsSource := ReadSourceFile(ResolveSourcePath(WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LPosixSource, 'timespec',
    'posix.ffi must expose timespec for platform.time');
  CheckTokenPresent(LPosixSource, 'clock_gettime',
    'posix.ffi must expose clock_gettime for platform.time');
  CheckTokenPresent(LPosixSource, 'clock_getres',
    'posix.ffi must expose clock_getres for platform.time');
  CheckPosixClockHelperSet(LLinuxSource, 'linux.ffi');
  CheckPosixClockHelperSet(LAndroidSource, 'android.ffi');
  CheckPosixClockHelperSet(LFreeBSDSource, 'freebsd.ffi');
  CheckPosixClockHelperSet(LUnixSource, 'unix.ffi');
  CheckPosixClockHelperSet(LDarwinSource, 'darwin.ffi');

  CheckTokenPresent(LDarwinSource, 'mach_absolute_time',
    'darwin.ffi must expose mach_absolute_time for platform.time');
  CheckTokenPresent(LDarwinSource, 'mach_timebase_info',
    'darwin.ffi must expose mach_timebase_info for platform.time');
  CheckTokenPresent(LDarwinSource, 'darwin_mach_monotonic_ns',
    'darwin.ffi must expose Darwin monotonic clock helper for platform.time');
  CheckTokenPresent(LDarwinSource, 'darwin_mach_monotonic_resolution_ns',
    'darwin.ffi must expose Darwin monotonic resolution helper for platform.time');

  CheckTokenPresent(LWindowsSource, 'queryperformancefrequency',
    'windows.ffi must expose QueryPerformanceFrequency for platform.time');
  CheckTokenPresent(LWindowsSource, 'queryperformancecounter',
    'windows.ffi must expose QueryPerformanceCounter for platform.time');
  CheckTokenPresent(LWindowsSource, 'getsystemtimeasfiletime',
    'windows.ffi must expose GetSystemTimeAsFileTime for platform.time');
  CheckTokenPresent(LWindowsSource, 'windows_qpc_frequency_u64',
    'windows.ffi must expose Windows QPC frequency helper for platform.time');
  CheckTokenPresent(LWindowsSource, 'windows_qpc_counter_u64',
    'windows.ffi must expose Windows QPC counter helper for platform.time');
  CheckTokenPresent(LWindowsSource, 'windows_filetime_now_unix_ns',
    'windows.ffi must expose Windows FILETIME realtime helper for platform.time');
  CheckTokenPresent(LWindowsSource, 'windows_filetime_unix_epoch_offset_100ns',
    'windows.ffi must own the FILETIME unix epoch offset token for platform.time');
  CheckTokenPresent(LWindowsSource, 'windows_filetime_nanoseconds_per_tick',
    'windows.ffi must own the FILETIME tick size token for platform.time');
  CheckTokenPresent(LWindowsSource, 'platform_clock_monotonic_ns_u64',
    'windows.ffi must expose host-owned monotonic nanosecond helper for platform.time');
  CheckTokenPresent(LWindowsSource, 'platform_clock_realtime_ns_u64',
    'windows.ffi must expose host-owned realtime nanosecond helper for platform.time');
  CheckTokenPresent(LWindowsSource, 'platform_clock_monotonic_resolution_ns_u64',
    'windows.ffi must expose host-owned monotonic resolution nanosecond helper for platform.time');

  CheckTokenPresent(LTimeSource, 'nextpas.core.platform.posix.ffi',
    'platform.time must use shared POSIX ffi declarations');
  CheckTokenPresent(LTimeSource, 'nextpas.core.platform.linux.ffi',
    'platform.time must bind Linux host-owned clock ids through linux.ffi');
  CheckTokenPresent(LTimeSource, 'nextpas.core.platform.darwin.ffi',
    'platform.time must bind Darwin host-owned clock ids through darwin.ffi');
  CheckTokenPresent(LTimeSource, 'nextpas.core.platform.android.ffi',
    'platform.time must bind Android host-owned clock ids through android.ffi');
  CheckTokenPresent(LTimeSource, 'nextpas.core.platform.freebsd.ffi',
    'platform.time must bind FreeBSD host-owned clock ids through freebsd.ffi');
  CheckTokenPresent(LTimeSource, 'nextpas.core.platform.unix.ffi',
    'platform.time must bind generic Unix host-owned clock ids through unix.ffi');
  CheckTokenPresent(LTimeSource, 'nextpas.core.platform.windows.ffi',
    'platform.time must bind Windows clock APIs through windows.ffi');
  CheckTokenPresent(LTimeSource, 'platform_clock_monotonic_ns_u64',
    'platform.time must consume host-owned monotonic nanosecond helper');
  CheckTokenPresent(LTimeSource, 'platform_clock_realtime_ns_u64',
    'platform.time must consume host-owned realtime nanosecond helper');
  CheckTokenPresent(LTimeSource, 'platform_clock_monotonic_resolution_ns_u64',
    'platform.time must consume host-owned monotonic resolution nanosecond helper');
  Check(Pos('mach_absolute_time(', LTimeSource) = 0,
    'platform.time must not call mach_absolute_time directly in the consumer');
  Check(Pos('mach_timebase_info(', LTimeSource) = 0,
    'platform.time must not call mach_timebase_info directly in the consumer');
  Check(Pos('queryperformancefrequency(', LTimeSource) = 0,
    'platform.time must not call QueryPerformanceFrequency directly in the consumer');
  Check(Pos('queryperformancecounter(', LTimeSource) = 0,
    'platform.time must not call QueryPerformanceCounter directly in the consumer');
  Check(Pos('getsystemtimeasfiletime(', LTimeSource) = 0,
    'platform.time must not call GetSystemTimeAsFileTime directly in the consumer');
  Check(Pos('clock_gettime(', LTimeSource) = 0,
    'platform.time must not call clock_gettime directly in the consumer');
  Check(Pos('clock_getres(', LTimeSource) = 0,
    'platform.time must not call clock_getres directly in the consumer');
  Check(Pos('platform_clock_monotonic_now', LTimeSource) = 0,
    'platform.time must not consume raw host monotonic timespec helpers in the consumer');
  Check(Pos('platform_clock_realtime_now', LTimeSource) = 0,
    'platform.time must not consume raw host realtime timespec helpers in the consumer');
  Check(Pos('platform_clock_monotonic_getres', LTimeSource) = 0,
    'platform.time must not consume raw host monotonic resolution timespec helpers in the consumer');
  Check(Pos('platform_clock_monotonic_id', LTimeSource) = 0,
    'platform.time must not consume raw host monotonic clock ids in the consumer');
  Check(Pos('platform_clock_realtime_id', LTimeSource) = 0,
    'platform.time must not consume raw host realtime clock ids in the consumer');
  Check(Pos('darwin_mach_monotonic_ns', LTimeSource) = 0,
    'platform.time must not consume Darwin raw monotonic helper directly in the consumer');
  Check(Pos('darwin_mach_monotonic_resolution_ns', LTimeSource) = 0,
    'platform.time must not consume Darwin raw monotonic resolution helper directly in the consumer');
  Check(Pos('windows_qpc_frequency_u64', LTimeSource) = 0,
    'platform.time must not consume Windows QPC frequency helper directly in the consumer');
  Check(Pos('windows_qpc_counter_u64', LTimeSource) = 0,
    'platform.time must not consume Windows QPC counter helper directly in the consumer');
  Check(Pos('windows_filetime_now_unix_ns', LTimeSource) = 0,
    'platform.time must not consume Windows FILETIME realtime helper directly in the consumer');
  Check(Pos('windows_filetime_unix_epoch_offset_100ns', LTimeSource) = 0,
    'platform.time must not consume raw FILETIME epoch offset tokens in the consumer');
  Check(Pos('windows_filetime_nanoseconds_per_tick', LTimeSource) = 0,
    'platform.time must not consume raw FILETIME tick size tokens in the consumer');
  Check(Pos('116444736000000000', LTimeSource) = 0,
    'platform.time must not keep a raw Windows FILETIME epoch offset literal');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.time.host_ffi_surface');
  T.Run('platform.time uses host clock ffi', @TestPlatformTimeUsesHostClockFFI);
  T.Summary;
end.
