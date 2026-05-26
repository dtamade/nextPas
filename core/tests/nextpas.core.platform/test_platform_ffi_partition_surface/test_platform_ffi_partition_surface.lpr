program test_platform_ffi_partition_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  POSIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';
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

procedure TestPlatformFFIPartition;
var
  LPosixSource: string;
  LLinuxSource: string;
  LDarwinSource: string;
  LAndroidSource: string;
  LFreeBSDSource: string;
  LUnixSource: string;
begin
  LPosixSource := ReadSourceFile(ResolveSourcePath(POSIX_FFI_SOURCE_PATH_FROM_TEST, POSIX_FFI_SOURCE_PATH_FROM_ROOT));
  LLinuxSource := ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT));
  LDarwinSource := ReadSourceFile(ResolveSourcePath(DARWIN_FFI_SOURCE_PATH_FROM_TEST, DARWIN_FFI_SOURCE_PATH_FROM_ROOT));
  LAndroidSource := ReadSourceFile(ResolveSourcePath(ANDROID_FFI_SOURCE_PATH_FROM_TEST, ANDROID_FFI_SOURCE_PATH_FROM_ROOT));
  LFreeBSDSource := ReadSourceFile(ResolveSourcePath(FREEBSD_FFI_SOURCE_PATH_FROM_TEST, FREEBSD_FFI_SOURCE_PATH_FROM_ROOT));
  LUnixSource := ReadSourceFile(ResolveSourcePath(UNIX_FFI_SOURCE_PATH_FROM_TEST, UNIX_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LPosixSource, 'clock_gettime',
    'posix.ffi must continue to own shared POSIX function declarations');
  CheckTokenPresent(LPosixSource, 'pthread_create',
    'posix.ffi must continue to own shared pthread function declarations');
  CheckTokenAbsent(LPosixSource, 'posix_eagain',
    'posix.ffi must not keep per-host errno constants after ffi partitioning');
  CheckTokenAbsent(LPosixSource, '_sc_nprocessors_onln',
    'posix.ffi must not keep per-host sysconf ids after ffi partitioning');
  CheckTokenAbsent(LPosixSource, 'function posix_errno_location',
    'posix.ffi must not keep per-host errno symbol bindings after ffi partitioning');

  CheckTokenPresent(LLinuxSource, 'platform_clock_monotonic_id',
    'linux.ffi must expose Linux clock ids');
  CheckTokenPresent(LLinuxSource, 'platform_posix_etimedout',
    'linux.ffi must expose Linux errno constants');
  CheckTokenPresent(LLinuxSource, 'function platform_errno_location',
    'linux.ffi must expose Linux errno binding');

  CheckTokenPresent(LDarwinSource, 'platform_clock_monotonic_id',
    'darwin.ffi must expose Darwin clock ids');
  CheckTokenPresent(LDarwinSource, 'platform_posix_etimedout',
    'darwin.ffi must expose Darwin errno constants');
  CheckTokenPresent(LDarwinSource, 'function platform_errno_location',
    'darwin.ffi must expose Darwin errno binding');

  CheckTokenPresent(LAndroidSource, 'platform_clock_monotonic_id',
    'android.ffi must expose Android clock ids');
  CheckTokenPresent(LAndroidSource, 'platform_posix_etimedout',
    'android.ffi must expose Android errno constants');
  CheckTokenPresent(LAndroidSource, 'function platform_errno_location',
    'android.ffi must expose Android errno binding');

  CheckTokenPresent(LFreeBSDSource, 'platform_clock_monotonic_id',
    'freebsd.ffi must expose FreeBSD clock ids');
  CheckTokenPresent(LFreeBSDSource, 'platform_posix_etimedout',
    'freebsd.ffi must expose FreeBSD errno constants');
  CheckTokenPresent(LFreeBSDSource, 'function platform_errno_location',
    'freebsd.ffi must expose FreeBSD errno binding');

  CheckTokenPresent(LUnixSource, 'platform_clock_monotonic_id',
    'unix.ffi must expose generic Unix clock ids');
  CheckTokenPresent(LUnixSource, 'platform_posix_etimedout',
    'unix.ffi must expose generic Unix errno constants');
  CheckTokenPresent(LUnixSource, 'function platform_errno_location',
    'unix.ffi must expose generic Unix errno binding');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.ffi_partition_surface');
  T.Run('platform ffi is partitioned by host', @TestPlatformFFIPartition);
  T.Summary;
end.
