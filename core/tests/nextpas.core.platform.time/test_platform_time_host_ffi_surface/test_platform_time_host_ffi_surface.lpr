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
  POSIX_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.base.pas';
  POSIX_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.base.pas';
  POSIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';
  POSIX_MATH_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.math.pas';
  POSIX_MATH_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.math.pas';
  LINUX_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.base.pas';
  LINUX_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.base.pas';
  LINUX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.ffi.pas';
  LINUX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.ffi.pas';
  ANDROID_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.base.pas';
  ANDROID_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.base.pas';
  ANDROID_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.ffi.pas';
  ANDROID_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.ffi.pas';
  DARWIN_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.base.pas';
  DARWIN_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.base.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.ffi.pas';
  DARWIN_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.ffi.pas';
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

procedure CheckRawFFIUnit(const ASource, ALabel: string);
begin
  CheckTokenPresent(ASource, 'external ''',
    ALabel + ' must expose raw external declarations');
  CheckTokenAbsent(ASource, ' inline',
    ALabel + ' must not expose inline helper declarations');
  CheckTokenAbsent(ASource, 'implementation' + #10 + 'uses',
    ALabel + ' implementation must not import helper dependencies');
  CheckTokenAbsent(ASource, 'begin' + #10,
    ALabel + ' must not contain helper bodies');
end;

procedure CheckHostClockBase(const ASource, AHostLabel: string);
begin
  CheckTokenPresent(ASource, 'platform_clock_monotonic_id',
    AHostLabel + ' base must own monotonic clock id');
  CheckTokenPresent(ASource, 'platform_clock_realtime_id',
    AHostLabel + ' base must own realtime clock id');
end;

procedure CheckNoClockHelpersInFFI(const ASource, AHostLabel: string);
begin
  CheckTokenAbsent(ASource, '_clock_monotonic_ns_u64',
    AHostLabel + ' ffi must not own nanosecond clock wrappers');
  CheckTokenAbsent(ASource, '_clock_realtime_ns_u64',
    AHostLabel + ' ffi must not own realtime clock wrappers');
  CheckTokenAbsent(ASource, '_clock_monotonic_resolution_ns_u64',
    AHostLabel + ' ffi must not own resolution clock wrappers');
  CheckTokenAbsent(ASource, 'platform_posix_clock_',
    AHostLabel + ' ffi must not own shared POSIX clock helpers');
  CheckTokenAbsent(ASource, 'function platform_clock_',
    AHostLabel + ' ffi must not expose unified-looking platform clock helpers');
end;

procedure TestPlatformTimeRawFFIBoundary;
var
  LTimeFacadeSource: string;
  LTimeBaseSource: string;
  LTimeHostSource: string;
  LPosixBaseSource: string;
  LPosixFfiSource: string;
  LPosixMathSource: string;
  LLinuxBaseSource: string;
  LLinuxFfiSource: string;
  LAndroidBaseSource: string;
  LAndroidFfiSource: string;
  LDarwinBaseSource: string;
  LDarwinFfiSource: string;
  LFreeBSDBaseSource: string;
  LFreeBSDFfiSource: string;
  LUnixBaseSource: string;
  LUnixFfiSource: string;
  LWindowsBaseSource: string;
  LWindowsFfiSource: string;
  LWindowsMathSource: string;
begin
  LTimeFacadeSource := ReadSourceFile(ResolveSourcePath(TIME_FACADE_SOURCE_PATH_FROM_TEST, TIME_FACADE_SOURCE_PATH_FROM_ROOT));
  LTimeBaseSource := ReadSourceFile(ResolveSourcePath(TIME_BASE_SOURCE_PATH_FROM_TEST, TIME_BASE_SOURCE_PATH_FROM_ROOT));
  LTimeHostSource := ReadSourceFile(ResolveSourcePath(TIME_HOST_SOURCE_PATH_FROM_TEST, TIME_HOST_SOURCE_PATH_FROM_ROOT));
  LPosixBaseSource := ReadSourceFile(ResolveSourcePath(POSIX_BASE_SOURCE_PATH_FROM_TEST, POSIX_BASE_SOURCE_PATH_FROM_ROOT));
  LPosixFfiSource := ReadSourceFile(ResolveSourcePath(POSIX_FFI_SOURCE_PATH_FROM_TEST, POSIX_FFI_SOURCE_PATH_FROM_ROOT));
  LPosixMathSource := ReadSourceFile(ResolveSourcePath(POSIX_MATH_SOURCE_PATH_FROM_TEST, POSIX_MATH_SOURCE_PATH_FROM_ROOT));
  LLinuxBaseSource := ReadSourceFile(ResolveSourcePath(LINUX_BASE_SOURCE_PATH_FROM_TEST, LINUX_BASE_SOURCE_PATH_FROM_ROOT));
  LLinuxFfiSource := ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT));
  LAndroidBaseSource := ReadSourceFile(ResolveSourcePath(ANDROID_BASE_SOURCE_PATH_FROM_TEST, ANDROID_BASE_SOURCE_PATH_FROM_ROOT));
  LAndroidFfiSource := ReadSourceFile(ResolveSourcePath(ANDROID_FFI_SOURCE_PATH_FROM_TEST, ANDROID_FFI_SOURCE_PATH_FROM_ROOT));
  LDarwinBaseSource := ReadSourceFile(ResolveSourcePath(DARWIN_BASE_SOURCE_PATH_FROM_TEST, DARWIN_BASE_SOURCE_PATH_FROM_ROOT));
  LDarwinFfiSource := ReadSourceFile(ResolveSourcePath(DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT));
  LFreeBSDBaseSource := ReadSourceFile(ResolveSourcePath(FREEBSD_BASE_SOURCE_PATH_FROM_TEST, FREEBSD_BASE_SOURCE_PATH_FROM_ROOT));
  LFreeBSDFfiSource := ReadSourceFile(ResolveSourcePath(FREEBSD_FFI_SOURCE_PATH_FROM_TEST, FREEBSD_FFI_SOURCE_PATH_FROM_ROOT));
  LUnixBaseSource := ReadSourceFile(ResolveSourcePath(UNIX_BASE_SOURCE_PATH_FROM_TEST, UNIX_BASE_SOURCE_PATH_FROM_ROOT));
  LUnixFfiSource := ReadSourceFile(ResolveSourcePath(UNIX_FFI_SOURCE_PATH_FROM_TEST, UNIX_FFI_SOURCE_PATH_FROM_ROOT));
  LWindowsBaseSource := ReadSourceFile(ResolveSourcePath(WINDOWS_BASE_SOURCE_PATH_FROM_TEST, WINDOWS_BASE_SOURCE_PATH_FROM_ROOT));
  LWindowsFfiSource := ReadSourceFile(ResolveSourcePath(WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT));
  LWindowsMathSource := ReadSourceFile(ResolveSourcePath(WINDOWS_MATH_SOURCE_PATH_FROM_TEST, WINDOWS_MATH_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LTimeBaseSource, 'tplatformtimenanoseconds',
    'platform.time.base must own public nanosecond carrier type');
  CheckTokenPresent(LTimeBaseSource, 'tplatformcountervalue',
    'platform.time.base must own public counter value carrier type');
  CheckTokenPresent(LTimeFacadeSource, 'nextpas.core.platform.time.base',
    'platform.time facade must re-export platform.time.base');
  CheckTokenPresent(LTimeFacadeSource, 'nextpas.core.platform.time.host',
    'platform.time facade must delegate to platform.time.host');
  CheckTokenAbsent(LTimeFacadeSource, '.ffi',
    'platform.time facade must not import host ffi directly');

  CheckTokenPresent(LPosixBaseSource, 'timespec',
    'posix.base must own shared POSIX timespec shape');
  CheckRawFFIUnit(LPosixFfiSource, 'posix.ffi');
  CheckTokenPresent(LPosixFfiSource, 'function clock_gettime',
    'posix.ffi must own raw clock_gettime declaration');
  CheckTokenPresent(LPosixFfiSource, 'function clock_getres',
    'posix.ffi must own raw clock_getres declaration');
  CheckNoClockHelpersInFFI(LPosixFfiSource, 'posix');
  CheckTokenPresent(LPosixMathSource, 'platform_posix_timespec_to_ns_u64',
    'posix.math must own pure timespec conversion');

  CheckHostClockBase(LLinuxBaseSource, 'linux');
  CheckHostClockBase(LAndroidBaseSource, 'android');
  CheckHostClockBase(LDarwinBaseSource, 'darwin');
  CheckHostClockBase(LFreeBSDBaseSource, 'freebsd');
  CheckHostClockBase(LUnixBaseSource, 'unix');
  CheckRawFFIUnit(LLinuxFfiSource, 'linux.ffi');
  CheckRawFFIUnit(LAndroidFfiSource, 'android.ffi');
  CheckRawFFIUnit(LDarwinFfiSource, 'darwin.ffi');
  CheckRawFFIUnit(LFreeBSDFfiSource, 'freebsd.ffi');
  CheckRawFFIUnit(LUnixFfiSource, 'unix.ffi');
  CheckNoClockHelpersInFFI(LLinuxFfiSource, 'linux');
  CheckNoClockHelpersInFFI(LAndroidFfiSource, 'android');
  CheckNoClockHelpersInFFI(LDarwinFfiSource, 'darwin');
  CheckNoClockHelpersInFFI(LFreeBSDFfiSource, 'freebsd');
  CheckNoClockHelpersInFFI(LUnixFfiSource, 'unix');
  CheckTokenPresent(LDarwinFfiSource, 'mach_absolute_time',
    'darwin.ffi must own raw mach_absolute_time declaration');
  CheckTokenPresent(LDarwinFfiSource, 'mach_timebase_info',
    'darwin.ffi must own raw mach_timebase_info declaration');

  CheckRawFFIUnit(LWindowsFfiSource, 'windows.ffi');
  CheckTokenPresent(LWindowsBaseSource, 'windows_filetime_unix_epoch_offset_100ns',
    'windows.base must own FILETIME epoch token');
  CheckTokenPresent(LWindowsBaseSource, 'windows_filetime_nanoseconds_per_tick',
    'windows.base must own FILETIME tick token');
  CheckTokenPresent(LWindowsFfiSource, 'queryperformancefrequency',
    'windows.ffi must own raw QueryPerformanceFrequency declaration');
  CheckTokenPresent(LWindowsFfiSource, 'queryperformancecounter',
    'windows.ffi must own raw QueryPerformanceCounter declaration');
  CheckTokenPresent(LWindowsFfiSource, 'getsystemtimeasfiletime',
    'windows.ffi must own raw GetSystemTimeAsFileTime declaration');
  CheckNoClockHelpersInFFI(LWindowsFfiSource, 'windows');
  CheckTokenPresent(LWindowsMathSource, 'windows_qpc_to_ns',
    'windows.math must own pure QPC conversion');

  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.posix.ffi',
    'platform.time.host must consume raw shared POSIX ffi');
  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.posix.math',
    'platform.time.host must consume POSIX pure math helpers');
  CheckTokenPresent(LTimeHostSource, 'nextpas.core.platform.windows.math',
    'platform.time.host must consume Windows pure math helpers');
  CheckTokenPresent(LTimeHostSource, 'clock_gettime(',
    'platform.time.host must directly wrap raw clock_gettime');
  CheckTokenPresent(LTimeHostSource, 'clock_getres(',
    'platform.time.host must directly wrap raw clock_getres');
  CheckTokenPresent(LTimeHostSource, 'mach_absolute_time',
    'platform.time.host must directly wrap Darwin raw clock API');
  CheckTokenPresent(LTimeHostSource, 'queryperformancecounter',
    'platform.time.host must directly wrap Windows raw counter API');
  CheckTokenPresent(LTimeHostSource, 'getsystemtimeasfiletime',
    'platform.time.host must directly wrap Windows raw realtime API');
  CheckTokenAbsent(LTimeHostSource, 'linux_clock_monotonic_ns_u64',
    'platform.time.host must not consume old Linux ffi clock helper');
  CheckTokenAbsent(LTimeHostSource, 'windows_clock_monotonic_ns_u64',
    'platform.time.host must not consume old Windows ffi clock helper');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.time.host_ffi_surface');
  T.Run('platform.time keeps raw ffi below unified wrappers', @TestPlatformTimeRawFFIBoundary);
  T.Summary;
end.
