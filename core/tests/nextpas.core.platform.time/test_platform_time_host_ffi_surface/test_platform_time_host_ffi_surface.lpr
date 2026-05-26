program test_platform_time_host_ffi_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  TIME_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.time.pas';
  TIME_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.time.pas';
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

procedure TestPlatformTimeUsesHostClockFFI;
var
  LTimeSource: string;
  LPosixSource: string;
  LDarwinSource: string;
  LWindowsSource: string;
begin
  LTimeSource := ReadSourceFile(ResolveSourcePath(TIME_SOURCE_PATH_FROM_TEST, TIME_SOURCE_PATH_FROM_ROOT));
  LPosixSource := ReadSourceFile(ResolveSourcePath(POSIX_FFI_SOURCE_PATH_FROM_TEST, POSIX_FFI_SOURCE_PATH_FROM_ROOT));
  LDarwinSource := ReadSourceFile(ResolveSourcePath(DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT));
  LWindowsSource := ReadSourceFile(ResolveSourcePath(WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LPosixSource, 'timespec',
    'posix.ffi must expose timespec for platform.time');
  CheckTokenPresent(LPosixSource, 'clock_gettime',
    'posix.ffi must expose clock_gettime for platform.time');
  CheckTokenPresent(LPosixSource, 'clock_getres',
    'posix.ffi must expose clock_getres for platform.time');

  CheckTokenPresent(LDarwinSource, 'mach_absolute_time',
    'darwin.ffi must expose mach_absolute_time for platform.time');
  CheckTokenPresent(LDarwinSource, 'mach_timebase_info',
    'darwin.ffi must expose mach_timebase_info for platform.time');

  CheckTokenPresent(LWindowsSource, 'queryperformancefrequency',
    'windows.ffi must expose QueryPerformanceFrequency for platform.time');
  CheckTokenPresent(LWindowsSource, 'queryperformancecounter',
    'windows.ffi must expose QueryPerformanceCounter for platform.time');
  CheckTokenPresent(LWindowsSource, 'getsystemtimeasfiletime',
    'windows.ffi must expose GetSystemTimeAsFileTime for platform.time');

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
  CheckTokenPresent(LTimeSource, 'platform_clock_monotonic_id',
    'platform.time must consume host-owned monotonic clock ids');
  CheckTokenPresent(LTimeSource, 'platform_clock_realtime_id',
    'platform.time must consume host-owned realtime clock ids');
  CheckTokenPresent(LTimeSource, 'clock_gettime',
    'platform.time must call POSIX clock_gettime through posix.ffi');
  CheckTokenPresent(LTimeSource, 'clock_getres',
    'platform.time must call POSIX clock_getres through posix.ffi');
  CheckTokenPresent(LTimeSource, 'mach_absolute_time',
    'platform.time must call mach_absolute_time through darwin.ffi');
  CheckTokenPresent(LTimeSource, 'mach_timebase_info',
    'platform.time must call mach_timebase_info through darwin.ffi');
  CheckTokenPresent(LTimeSource, 'queryperformancefrequency',
    'platform.time must call QueryPerformanceFrequency through windows.ffi');
  CheckTokenPresent(LTimeSource, 'queryperformancecounter',
    'platform.time must call QueryPerformanceCounter through windows.ffi');
  CheckTokenPresent(LTimeSource, 'getsystemtimeasfiletime',
    'platform.time must call GetSystemTimeAsFileTime through windows.ffi');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.time.host_ffi_surface');
  T.Run('platform.time uses host clock ffi', @TestPlatformTimeUsesHostClockFFI);
  T.Summary;
end.
