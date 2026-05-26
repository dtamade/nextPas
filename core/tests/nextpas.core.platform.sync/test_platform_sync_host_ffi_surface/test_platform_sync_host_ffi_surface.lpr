program test_platform_sync_host_ffi_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  SYNC_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.sync.pas';
  SYNC_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.sync.pas';
  LINUX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.ffi.pas';
  LINUX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.ffi.pas';
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

procedure TestPlatformSyncUsesHostFFISurface;
var
  LSyncSource: string;
  LLinuxSource: string;
  LWindowsSource: string;
begin
  LSyncSource := ReadSourceFile(ResolveSourcePath(SYNC_SOURCE_PATH_FROM_TEST, SYNC_SOURCE_PATH_FROM_ROOT));
  LLinuxSource := ReadSourceFile(ResolveSourcePath(LINUX_FFI_SOURCE_PATH_FROM_TEST, LINUX_FFI_SOURCE_PATH_FROM_ROOT));
  LWindowsSource := ReadSourceFile(ResolveSourcePath(WINDOWS_FFI_SOURCE_PATH_FROM_TEST, WINDOWS_FFI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LLinuxSource, 'function linux_syscall',
    'linux.ffi must expose the Linux futex syscall binding');
  CheckTokenPresent(LLinuxSource, 'linux_syscall_futex',
    'linux.ffi must expose the Linux futex syscall number');
  CheckTokenPresent(LLinuxSource, 'futex_wait',
    'linux.ffi must expose FUTEX_WAIT');
  CheckTokenPresent(LLinuxSource, 'futex_wake',
    'linux.ffi must expose FUTEX_WAKE');

  CheckTokenPresent(LWindowsSource, 'waitonaddress',
    'windows.ffi must expose WaitOnAddress');
  CheckTokenPresent(LWindowsSource, 'wakebyaddresssingle',
    'windows.ffi must expose WakeByAddressSingle');
  CheckTokenPresent(LWindowsSource, 'wakebyaddressall',
    'windows.ffi must expose WakeByAddressAll');
  CheckTokenPresent(LWindowsSource, 'getlasterror',
    'windows.ffi must expose GetLastError for sync error mapping');

  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.linux.ffi',
    'platform.sync must use linux.ffi for Linux futex bindings');
  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.windows.ffi',
    'platform.sync must use windows.ffi for Windows wait-address bindings');
  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.android.ffi',
    'platform.sync must use android.ffi for Android host-owned errno/clock ids');
  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.darwin.ffi',
    'platform.sync must use darwin.ffi for Darwin host-owned errno/clock ids');
  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.freebsd.ffi',
    'platform.sync must use freebsd.ffi for FreeBSD host-owned errno/clock ids');
  CheckTokenPresent(LSyncSource, 'nextpas.core.platform.unix.ffi',
    'platform.sync must use unix.ffi for generic Unix host-owned errno/clock ids');

  CheckTokenPresent(LSyncSource, 'platform_errno_location',
    'platform.sync must consume host-owned errno bindings');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_normal_kind',
    'platform.sync must consume host-owned pthread mutex normal numbering');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_recursive_kind',
    'platform.sync must consume host-owned pthread mutex recursive numbering');
  CheckTokenPresent(LSyncSource, 'platform_pthread_mutex_errorcheck_kind',
    'platform.sync must consume host-owned pthread mutex errorcheck numbering');
  CheckTokenPresent(LSyncSource, 'platform_pthread_condattr_setclock_supported',
    'platform.sync must consume host-owned pthread condattr clock capability');
  CheckTokenPresent(LSyncSource, 'platform_pthread_condattr_setclock',
    'platform.sync must consume host-owned pthread condattr clock binding');
  CheckTokenPresent(LSyncSource, 'platform_pthread_timeout_clock_id',
    'platform.sync must consume host-owned pthread timeout clock policy');
  CheckTokenPresent(LSyncSource, 'linux_syscall',
    'platform.sync must consume linux futex bindings through linux.ffi');
  CheckTokenPresent(LSyncSource, 'waitonaddress',
    'platform.sync must consume WaitOnAddress through windows.ffi');
  CheckTokenPresent(LSyncSource, 'wakebyaddresssingle',
    'platform.sync must consume WakeByAddressSingle through windows.ffi');
  CheckTokenPresent(LSyncSource, 'wakebyaddressall',
    'platform.sync must consume WakeByAddressAll through windows.ffi');
  CheckTokenPresent(LSyncSource, 'getlasterror',
    'platform.sync must consume GetLastError through windows.ffi');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.host_ffi_surface');
  T.Run('platform.sync uses host ffi surface', @TestPlatformSyncUsesHostFFISurface);
  T.Summary;
end.
