program test_platform_time_host_ffi_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  TIME_FACADE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.time.pas';
  TIME_FACADE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.time.pas';
  TIME_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.time.base.pas';
  TIME_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.time.base.pas';
  TIME_HOST_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.time.host.pas';
  TIME_HOST_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.time.host.pas';
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
  POSIX_MATH_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.math.pas';
  POSIX_MATH_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.math.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.ffi.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.ffi.pas';
  WINDOWS_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.ffi.pas';
  WINDOWS_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.ffi.pas';
  WINDOWS_MATH_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.math.pas';
  WINDOWS_MATH_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.math.pas';

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

function CountToken(const ASource, AToken: string): Integer;
var
  LFoundAt: SizeInt;
  LSlice: string;
  LToken: string;
begin
  Result := 0;
  LSlice := ASource;
  LToken := LowerCase(AToken);
  repeat
  begin
    LFoundAt := Pos(LToken, LSlice);
    if LFoundAt = 0 then
      Exit;
    Inc(Result);
    Delete(LSlice, 1, LFoundAt + Length(LToken) - 1);
  end;
  until False;
end;

procedure CheckPosixClockHelperSet(
  const ASource, AHostLabel: string;
  const ARequireSharedResolutionProjection: Boolean);
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
  CheckTokenPresent(ASource, 'platform_posix_clock_now',
    AHostLabel + ' must delegate raw POSIX clock reads to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_clock_getres',
    AHostLabel + ' must delegate raw POSIX clock resolution reads to shared posix.ffi');
  CheckTokenPresent(ASource, 'platform_posix_clock_ns_u64',
    AHostLabel + ' must delegate POSIX realtime ns projection to shared posix.ffi');
  if ARequireSharedResolutionProjection then
    CheckTokenPresent(ASource, 'platform_posix_clock_resolution_ns_u64',
      AHostLabel + ' must delegate POSIX resolution projection to shared posix.ffi');
end;

procedure TestPlatformTimeUsesHostClockFFI;
var
  LTimeFacadeSource: string;
  LTimeBaseSource: string;
  LTimeHostSource: string;
  LLinuxSource: string;
  LAndroidSource: string;
  LFreeBSDSource: string;
  LUnixSource: string;
  LPosixSource: string;
  LPosixMathSource: string;
  LDarwinSource: string;
  LWindowsSource: string;
  LWindowsMathSource: string;
begin
  LTimeFacadeSource := ReadSourceFile(ResolveSourcePath(TIME_FACADE_SOURCE_PATH_FROM_TEST, TIME_FACADE_SOURCE_PATH_FROM_ROOT));
  LTimeBaseSource := ReadSourceFile(ResolveSourcePath(TIME_BASE_SOURCE_PATH_FROM_TEST, TIME_BASE_SOURCE_PATH_FROM_ROOT));
  LTimeHostSource := ReadSourceFile(ResolveSourcePath(TIME_HOST_SOURCE_PATH_FROM_TEST, TIME_HOST_SOURCE_PATH_FROM_ROOT));
  LLinuxSource := ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT));
  LAndroidSource := ReadSourceFile(ResolveSourcePath(ANDROID_FFI_SOURCE_PATH_FROM_TEST, ANDROID_FFI_SOURCE_PATH_FROM_ROOT));
  LFreeBSDSource := ReadSourceFile(ResolveSourcePath(FREEBSD_FFI_SOURCE_PATH_FROM_TEST, FREEBSD_FFI_SOURCE_PATH_FROM_ROOT));
  LUnixSource := ReadSourceFile(ResolveSourcePath(UNIX_FFI_SOURCE_PATH_FROM_TEST, UNIX_FFI_SOURCE_PATH_FROM_ROOT));
  LPosixSource := ReadSourceFile(ResolveSourcePath(POSIX_FFI_SOURCE_PATH_FROM_TEST, POSIX_FFI_SOURCE_PATH_FROM_ROOT));
  LPosixMathSource := ReadSourceFile(ResolveSourcePath(POSIX_MATH_SOURCE_PATH_FROM_TEST, POSIX_MATH_SOURCE_PATH_FROM_ROOT));
  LDarwinSource := ReadSourceFile(ResolveSourcePath(DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT));
  LWindowsSource := ReadSourceFile(ResolveSourcePath(WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT));
  LWindowsMathSource := ReadSourceFile(ResolveSourcePath(WINDOWS_MATH_SOURCE_PATH_FROM_TEST, WINDOWS_MATH_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LPosixSource, 'timespec',
    'posix.ffi must expose timespec for platform.time');
  CheckTokenPresent(LPosixSource, 'clock_gettime',
    'posix.ffi must expose clock_gettime for platform.time');
  CheckTokenPresent(LPosixSource, 'clock_getres',
    'posix.ffi must expose clock_getres for platform.time');
  CheckTokenPresent(LPosixSource, 'nextpas.core.platform.posix.math',
    'posix.ffi must delegate pure POSIX timespec math through helper-only posix.math');
  CheckTokenPresent(LPosixMathSource, 'platform_posix_timespec_to_ns_u64',
    'posix.math must expose shared timespec conversion helper for platform.time');
  CheckPosixClockHelperSet(LLinuxSource, 'linux.ffi', True);
  CheckPosixClockHelperSet(LAndroidSource, 'android.ffi', True);
  CheckPosixClockHelperSet(LFreeBSDSource, 'freebsd.ffi', True);
  CheckPosixClockHelperSet(LUnixSource, 'unix.ffi', True);
  CheckPosixClockHelperSet(LDarwinSource, 'darwin.ffi', False);

  CheckTokenPresent(LDarwinSource, 'mach_absolute_time',
    'darwin.ffi must expose mach_absolute_time for platform.time');
  CheckTokenPresent(LDarwinSource, 'mach_timebase_info',
    'darwin.ffi must expose mach_timebase_info for platform.time');
  CheckTokenPresent(LDarwinSource, 'darwin_mach_monotonic_ns',
    'darwin.ffi must expose Darwin monotonic clock helper for platform.time');
  CheckTokenPresent(LDarwinSource, 'darwin_mach_monotonic_resolution_ns',
    'darwin.ffi must expose Darwin monotonic resolution helper for platform.time');

  CheckTokenPresent(LWindowsMathSource, 'windows_qpc_to_ns',
    'windows.math must expose pure Windows QPC nanosecond conversion helper for platform.time');
  CheckTokenPresent(LWindowsMathSource, 'windows_qpc_resolution_ns',
    'windows.math must expose pure Windows QPC resolution helper for platform.time');

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
  CheckTokenPresent(LWindowsSource, 'windows_qpc_to_ns',
    'windows.ffi must expose Windows QPC nanosecond conversion helper for platform.time');
  CheckTokenPresent(LWindowsSource, 'windows_qpc_resolution_ns',
    'windows.ffi must expose Windows QPC resolution conversion helper for platform.time');
  CheckTokenPresent(LWindowsSource, 'nextpas.core.platform.windows.math',
    'windows.ffi must delegate pure QPC conversion math through helper-only windows.math');
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

  CheckTokenPresent(LTimeBaseSource, 'tplatformtimenanoseconds',
    'platform.time.base must define the public nanosecond carrier type');
  CheckTokenPresent(LTimeBaseSource, 'tplatformcountervalue',
    'platform.time.base must define the public counter-value carrier type');
  CheckTokenPresent(LTimeBaseSource, 'tplatformcounterfrequency',
    'platform.time.base must define the public counter-frequency carrier type');

  CheckTokenPresent(LTimeFacadeSource, 'nextpas.core.platform.time.base',
    'platform.time facade must re-export platform.time.base');
  CheckTokenAbsent(LTimeFacadeSource, 'nextpas.core.platform.time.intf',
    'platform.time has no Pascal interface contract, so facade must not use platform.time.intf');
  CheckTokenAbsent(LTimeFacadeSource, 'iplatformtimesource',
    'platform.time has no Pascal interface contract, so facade must not re-export IPlatformTimeSource');
  CheckTokenPresent(LTimeFacadeSource, 'nextpas.core.platform.time.host',
    'platform.time facade must delegate to platform.time.host');
  CheckTokenPresent(LTimeFacadeSource, 'tplatformtimenanoseconds = nextpas.core.platform.time.base.tplatformtimenanoseconds',
    'platform.time facade must re-export the public nanosecond carrier type');
  CheckTokenPresent(LTimeFacadeSource, 'result := nextpas.core.platform.time.host.platform_monotonic_ns;',
    'platform.time facade must forward monotonic clock API to platform.time.host');
  CheckTokenPresent(LTimeFacadeSource, 'result := nextpas.core.platform.time.host.platform_realtime_ns;',
    'platform.time facade must forward realtime clock API to platform.time.host');
  CheckTokenPresent(LTimeFacadeSource, 'result := nextpas.core.platform.time.host.platform_monotonic_resolution_ns;',
    'platform.time facade must forward clock resolution API to platform.time.host');
  CheckTokenPresent(LTimeFacadeSource, 'result := nextpas.core.platform.time.host.platform_qpc_to_ns(acounter, afrequency);',
    'platform.time facade must forward QPC conversion API to platform.time.host');
  CheckTokenPresent(LTimeFacadeSource, 'result := nextpas.core.platform.time.host.platform_resolution_from_frequency_ns(afrequency);',
    'platform.time facade must forward frequency-resolution conversion API to platform.time.host');
  CheckTokenPresent(LTimeFacadeSource, 'result := nextpas.core.platform.time.host.platform_timespec_to_ns(asec, ansec);',
    'platform.time facade must forward timespec conversion API to platform.time.host');

  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.posix.ffi',
    'platform.time.host must use shared POSIX ffi declarations for Unix clock owners');
  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.posix.math',
    'platform.time.host must use helper-only posix.math for pure timespec conversion');
  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.linux.ffi',
    'platform.time.host must bind Linux host-owned clock ids through linux.ffi');
  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.darwin.ffi',
    'platform.time.host must bind Darwin host-owned clock ids through darwin.ffi');
  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.android.ffi',
    'platform.time.host must bind Android host-owned clock ids through android.ffi');
  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.freebsd.ffi',
    'platform.time.host must bind FreeBSD host-owned clock ids through freebsd.ffi');
  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.unix.ffi',
    'platform.time.host must bind generic Unix host-owned clock ids through unix.ffi');
  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.windows.ffi',
    'platform.time.host must bind Windows clock APIs through windows.ffi');
  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.windows.math',
    'platform.time.host must use helper-only windows.math for pure QPC math on non-Windows hosts');
  CheckTokenPresent(LTimeHostSource, 'platform_clock_monotonic_ns_u64',
    'platform.time.host must consume host-owned monotonic nanosecond helper');
  CheckTokenPresent(LTimeHostSource, 'platform_clock_realtime_ns_u64',
    'platform.time.host must consume host-owned realtime nanosecond helper');
  CheckTokenPresent(LTimeHostSource, 'platform_clock_monotonic_resolution_ns_u64',
    'platform.time.host must consume host-owned monotonic resolution nanosecond helper');
  CheckTokenPresent(LTimeHostSource, 'windows_qpc_to_ns',
    'platform.time.host must consume Windows QPC nanosecond conversion helper through windows.ffi');
  CheckTokenPresent(LTimeHostSource, 'windows_qpc_resolution_ns',
    'platform.time.host must consume Windows QPC resolution helper through windows.ffi');
  CheckTokenPresent(LTimeHostSource, 'platform_posix_timespec_to_ns_u64',
    'platform.time.host must consume shared POSIX timespec conversion helper through posix.math');
  Check(Pos('{$ifdef nextpas_unix}', LTimeHostSource) < Pos('nextpas.core.platform.posix.ffi', LTimeHostSource),
    'platform.time.host must only pull posix.ffi inside the Unix host-ffi branch');
  Check(CountToken(LTimeHostSource, 'result := platform_clock_monotonic_ns_u64;') = 1,
    'platform.time.host must keep a single host-ffi monotonic body');
  Check(CountToken(LTimeHostSource, 'result := platform_clock_realtime_ns_u64;') = 1,
    'platform.time.host must keep a single host-ffi realtime body');
  Check(CountToken(LTimeHostSource, 'result := platform_clock_monotonic_resolution_ns_u64;') = 1,
    'platform.time.host must keep a single host-ffi monotonic-resolution body');
  Check(Pos('mach_absolute_time(', LTimeHostSource) = 0,
    'platform.time.host must not call mach_absolute_time directly in the consumer');
  Check(Pos('mach_timebase_info(', LTimeHostSource) = 0,
    'platform.time.host must not call mach_timebase_info directly in the consumer');
  Check(Pos('queryperformancefrequency(', LTimeHostSource) = 0,
    'platform.time.host must not call QueryPerformanceFrequency directly in the consumer');
  Check(Pos('queryperformancecounter(', LTimeHostSource) = 0,
    'platform.time.host must not call QueryPerformanceCounter directly in the consumer');
  Check(Pos('getsystemtimeasfiletime(', LTimeHostSource) = 0,
    'platform.time.host must not call GetSystemTimeAsFileTime directly in the consumer');
  Check(Pos('clock_gettime(', LTimeHostSource) = 0,
    'platform.time.host must not call clock_gettime directly in the consumer');
  Check(Pos('clock_getres(', LTimeHostSource) = 0,
    'platform.time.host must not call clock_getres directly in the consumer');
  Check(Pos('platform_clock_monotonic_now', LTimeHostSource) = 0,
    'platform.time.host must not consume raw host monotonic timespec helpers in the consumer');
  Check(Pos('platform_clock_realtime_now', LTimeHostSource) = 0,
    'platform.time.host must not consume raw host realtime timespec helpers in the consumer');
  Check(Pos('platform_clock_monotonic_getres', LTimeHostSource) = 0,
    'platform.time.host must not consume raw host monotonic resolution timespec helpers in the consumer');
  Check(Pos('platform_clock_monotonic_id', LTimeHostSource) = 0,
    'platform.time.host must not consume raw host monotonic clock ids in the consumer');
  Check(Pos('platform_clock_realtime_id', LTimeHostSource) = 0,
    'platform.time.host must not consume raw host realtime clock ids in the consumer');
  Check(Pos('darwin_mach_monotonic_ns', LTimeHostSource) = 0,
    'platform.time.host must not consume Darwin raw monotonic helper directly in the consumer');
  Check(Pos('darwin_mach_monotonic_resolution_ns', LTimeHostSource) = 0,
    'platform.time.host must not consume Darwin raw monotonic resolution helper directly in the consumer');
  Check(Pos('windows_qpc_frequency_u64', LTimeHostSource) = 0,
    'platform.time.host must not consume Windows QPC frequency helper directly in the consumer');
  Check(Pos('windows_qpc_counter_u64', LTimeHostSource) = 0,
    'platform.time.host must not consume Windows QPC counter helper directly in the consumer');
  Check(Pos('windows_filetime_now_unix_ns', LTimeHostSource) = 0,
    'platform.time.host must not consume Windows FILETIME realtime helper directly in the consumer');
  Check(Pos('windows_filetime_unix_epoch_offset_100ns', LTimeHostSource) = 0,
    'platform.time.host must not consume raw FILETIME epoch offset tokens in the consumer');
  Check(Pos('windows_filetime_nanoseconds_per_tick', LTimeHostSource) = 0,
    'platform.time.host must not consume raw FILETIME tick size tokens in the consumer');
  Check(Pos('function platform_mul_div_floor', LTimeHostSource) = 0,
    'platform.time.host must not keep a local multiply-divide helper after ffi ownerization');
  Check(Pos('function platform_scale_units', LTimeHostSource) = 0,
    'platform.time.host must not keep a local unit-scaling helper after ffi ownerization');
  Check(Pos('nanoseconds_per_second', LTimeHostSource) = 0,
    'platform.time.host must not keep a local nanoseconds-per-second helper constant after ffi ownerization');
  Check(Pos('116444736000000000', LTimeHostSource) = 0,
    'platform.time.host must not keep a raw Windows FILETIME epoch offset literal');
  Check(Pos('nextpas.core.platform.posix.ffi', LTimeFacadeSource) = 0,
    'platform.time facade must not bind shared POSIX ffi directly');
  Check(Pos('nextpas.core.platform.linux.ffi', LTimeFacadeSource) = 0,
    'platform.time facade must not bind Linux host ffi directly');
  Check(Pos('nextpas.core.platform.darwin.ffi', LTimeFacadeSource) = 0,
    'platform.time facade must not bind Darwin host ffi directly');
  Check(Pos('nextpas.core.platform.android.ffi', LTimeFacadeSource) = 0,
    'platform.time facade must not bind Android host ffi directly');
  Check(Pos('nextpas.core.platform.freebsd.ffi', LTimeFacadeSource) = 0,
    'platform.time facade must not bind FreeBSD host ffi directly');
  Check(Pos('nextpas.core.platform.unix.ffi', LTimeFacadeSource) = 0,
    'platform.time facade must not bind generic Unix host ffi directly');
  Check(Pos('nextpas.core.platform.windows.ffi', LTimeFacadeSource) = 0,
    'platform.time facade must not bind Windows host ffi directly');
  Check(Pos('nextpas.core.platform.windows.math', LTimeFacadeSource) = 0,
    'platform.time facade must not bind helper-only windows.math directly');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.time.host_ffi_surface');
  T.Run('platform.time uses host clock ffi', @TestPlatformTimeUsesHostClockFFI);
  T.Summary;
end.
