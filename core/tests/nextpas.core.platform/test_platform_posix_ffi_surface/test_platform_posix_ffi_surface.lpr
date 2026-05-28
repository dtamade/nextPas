program test_platform_posix_ffi_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  POSIX_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.base.pas';
  POSIX_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.base.pas';
  POSIX_FFI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';
  POSIX_MATH_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.math.pas';
  POSIX_MATH_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.math.pas';

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

procedure TestPosixFFIExposesTargetMatrix;
var
  LBaseSource: string;
  LSource: string;
  LMathSource: string;
begin
  LBaseSource := ReadSourceFile(ResolveSourcePath(
    POSIX_BASE_SOURCE_PATH_FROM_TEST,
    POSIX_BASE_SOURCE_PATH_FROM_ROOT));
  LSource := ReadSourceFile(ResolveSourcePath(
    POSIX_FFI_SOURCE_PATH_FROM_TEST,
    POSIX_FFI_SOURCE_PATH_FROM_ROOT));
  LMathSource := ReadSourceFile(ResolveSourcePath(
    POSIX_MATH_SOURCE_PATH_FROM_TEST,
    POSIX_MATH_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LSource, 'nextpas.core.platform.posix.base',
    'posix.ffi must consume shared POSIX base ABI shapes');
  CheckTokenAbsent(LSource, 'nextpas.core.platform.posix.math',
    'posix.ffi must not consume helper-only POSIX math');
  CheckTokenPresent(LBaseSource, 'nextpas_android',
    'posix.base must carry an Android-specific pthread ABI branch');
  CheckTokenPresent(LBaseSource, 'nextpas_freebsd',
    'posix.base must carry a FreeBSD-specific pthread ABI branch');
  CheckTokenPresent(LBaseSource, 'nextpas_macos',
    'posix.base must carry a macOS-specific pthread ABI branch');

  CheckTokenPresent(LBaseSource, 'pthread_rwlockattr_t',
    'posix.base must declare pthread rwlock attribute storage');
  CheckTokenPresent(LBaseSource, 'array[0..199] of byte',
    'posix.base must preserve the macOS rwlock opaque size');
  CheckTokenPresent(LBaseSource, 'pthread_mutex_t = pointer;',
    'posix.base must model FreeBSD pthread mutex handles as pointers');
  CheckTokenPresent(LBaseSource, 'pthread_cond_t = pointer;',
    'posix.base must model FreeBSD pthread condvar handles as pointers');
  CheckTokenPresent(LBaseSource, 'pthread_rwlock_t = pointer;',
    'posix.base must model FreeBSD pthread rwlock handles as pointers');
  CheckTokenPresent(LBaseSource, 'pthread_mutexattr_t = ptrint;',
    'posix.base must model Android pthread mutex attributes as long-sized values');
  CheckTokenPresent(LBaseSource, 'pthread_mutexattr_t = int32;',
    'posix.base must model Linux pthread mutex attributes as 32-bit values');
  CheckTokenPresent(LMathSource, 'platform_posix_timespec_to_ns_u64',
    'posix.math must expose shared timespec-to-ns conversion for platform consumers');
  CheckTokenPresent(LMathSource, 'platform_posix_timespec_add_ns',
    'posix.math must expose shared timespec deadline arithmetic for platform consumers');
  CheckTokenPresent(LMathSource, 'platform_posix_timespec_remaining_ns_u64',
    'posix.math must expose shared timespec remaining-time arithmetic for platform consumers');
  CheckTokenAbsent(LSource, 'function platform_posix_timespec_to_ns_u64',
    'posix.ffi must not own pure timespec-to-ns math after posix.math split');
  CheckTokenAbsent(LSource, 'procedure platform_posix_timespec_add_ns',
    'posix.ffi must not own pure timespec deadline arithmetic after posix.math split');
  CheckTokenAbsent(LSource, 'function platform_posix_timespec_remaining_ns_u64',
    'posix.ffi must not own pure timespec remaining arithmetic after posix.math split');
  CheckTokenAbsent(LSource, 'platform_posix_thread_self_token_u64',
    'posix.ffi must not expose shared pthread self-token projection');
  CheckTokenAbsent(LSource, 'platform_posix_sysconf_positive_i32',
    'posix.ffi must not expose shared positive sysconf projection');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_create_handle',
    'posix.ffi must not expose shared pthread create helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_join_handle',
    'posix.ffi must not expose shared pthread join helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_detach_handle',
    'posix.ffi must not expose shared pthread detach helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_yield',
    'posix.ffi must not expose shared pthread yield helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_sleep_ns',
    'posix.ffi must not expose shared pthread sleep helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_tls_create',
    'posix.ffi must not expose shared pthread TLS create helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_tls_destroy',
    'posix.ffi must not expose shared pthread TLS destroy helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_tls_set',
    'posix.ffi must not expose shared pthread TLS set helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_tls_get',
    'posix.ffi must not expose shared pthread TLS get helper');
  CheckTokenAbsent(LSource, 'platform_posix_clock_now',
    'posix.ffi must not expose shared POSIX clock read helper');
  CheckTokenAbsent(LSource, 'platform_posix_clock_getres',
    'posix.ffi must not expose shared POSIX clock resolution helper');
  CheckTokenAbsent(LSource, 'platform_posix_clock_ns_u64',
    'posix.ffi must not expose shared POSIX clock nanosecond helper');
  CheckTokenAbsent(LSource, 'platform_posix_clock_resolution_ns_u64',
    'posix.ffi must not expose shared POSIX clock resolution-ns helper');
  CheckTokenAbsent(LSource, 'platform_posix_clock_deadline_after_ns',
    'posix.ffi must not expose shared POSIX clock deadline helper');
  CheckTokenAbsent(LSource, 'platform_posix_clock_deadline_remaining_ns_u64',
    'posix.ffi must not expose shared POSIX clock remaining-before-deadline helper');
  CheckTokenAbsent(LSource, 'platform_posix_errno_value_from_location',
    'posix.ffi must not expose shared POSIX errno-value load helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_mutex_destroy',
    'posix.ffi must not expose shared pthread mutex destroy helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_mutex_init_kind',
    'posix.ffi must not expose shared pthread mutex init-with-kind helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_mutex_init_public_kind',
    'posix.ffi must not expose shared pthread mutex init-with-public-kind helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_mutex_lock',
    'posix.ffi must not expose shared pthread mutex lock helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_mutex_trylock',
    'posix.ffi must not expose shared pthread mutex trylock helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_mutex_timedlock_abs',
    'posix.ffi must not expose shared pthread mutex timed-lock helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_mutex_unlock',
    'posix.ffi must not expose shared pthread mutex unlock helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_rwlock_init',
    'posix.ffi must not expose shared pthread rwlock init helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_rwlock_destroy',
    'posix.ffi must not expose shared pthread rwlock destroy helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_rwlock_rdlock',
    'posix.ffi must not expose shared pthread rwlock read-lock helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_rwlock_tryrdlock',
    'posix.ffi must not expose shared pthread rwlock try-read-lock helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_rwlock_wrlock',
    'posix.ffi must not expose shared pthread rwlock write-lock helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_rwlock_trywrlock',
    'posix.ffi must not expose shared pthread rwlock try-write-lock helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_rwlock_unlock',
    'posix.ffi must not expose shared pthread rwlock unlock helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_condvar_destroy',
    'posix.ffi must not expose shared pthread condvar destroy helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_condvar_wait',
    'posix.ffi must not expose shared pthread condvar wait helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_condvar_init_with_clock',
    'posix.ffi must not expose shared pthread condvar init-with-timeout-clock helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_condvar_timedwait_abs',
    'posix.ffi must not expose shared pthread condvar timedwait helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_condvar_signal',
    'posix.ffi must not expose shared pthread condvar signal helper');
  CheckTokenAbsent(LSource, 'platform_posix_pthread_condvar_broadcast',
    'posix.ffi must not expose shared pthread condvar broadcast helper');
  CheckTokenAbsent(LSource, 'pthread_mutex_errorcheck',
    'posix.ffi must not keep per-host pthread mutex kind numbering');
  CheckTokenAbsent(LSource, 'pthread_mutex_recursive',
    'posix.ffi must not keep per-host pthread mutex kind numbering');
  CheckTokenAbsent(LSource, 'pthread_mutex_normal',
    'posix.ffi must not keep per-host pthread mutex kind numbering');
  CheckTokenAbsent(LSource, 'function pthread_condattr_setclock',
    'posix.ffi must not keep host-specific pthread condattr clock binding');
  CheckTokenPresent(LSource, 'function pthread_mutex_timedlock',
    'posix.ffi must declare pthread_mutex_timedlock where FPC pthread sources prove the ABI');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.posix_ffi_surface');
  T.Run('platform.posix.ffi exposes target matrix', @TestPosixFFIExposesTargetMatrix);
  T.Summary;
end.
