program test_platform_host_gap_matrix;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  DOC_PATH_FROM_TEST = '../../../docs/platform-host-ffi-gap-matrix.md';
  DOC_PATH_FROM_ROOT = 'core/docs/platform-host-ffi-gap-matrix.md';
  DESIGN_CONVENTIONS_PATH_FROM_TEST = '../../../docs/design-conventions.md';
  DESIGN_CONVENTIONS_PATH_FROM_ROOT = 'core/docs/design-conventions.md';
  VERIFY_LOCAL_PATH_FROM_TEST = '../../../../build/verify_local.sh';
  VERIFY_LOCAL_PATH_FROM_ROOT = 'build/verify_local.sh';

  LINUX_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.base.pas';
  LINUX_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.base.pas';
  LINUX_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.ffi.pas';
  LINUX_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.ffi.pas';
  ANDROID_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.base.pas';
  ANDROID_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.base.pas';
  ANDROID_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.ffi.pas';
  ANDROID_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.ffi.pas';
  DARWIN_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.base.pas';
  DARWIN_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.base.pas';
  DARWIN_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.ffi.pas';
  DARWIN_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.ffi.pas';
  FREEBSD_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.base.pas';
  FREEBSD_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.base.pas';
  FREEBSD_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.ffi.pas';
  FREEBSD_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.ffi.pas';
  UNIX_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.unix.base.pas';
  UNIX_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.unix.base.pas';
  UNIX_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.unix.ffi.pas';
  UNIX_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.unix.ffi.pas';
  WINDOWS_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.base.pas';
  WINDOWS_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.base.pas';
  WINDOWS_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.ffi.pas';
  WINDOWS_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.ffi.pas';

  PLATFORM_TIME_FFI_FROM_TEST = '../../../src/nextpas.core.platform.time.ffi.pas';
  PLATFORM_TIME_FFI_FROM_ROOT = 'core/src/nextpas.core.platform.time.ffi.pas';
  PLATFORM_SYNC_FFI_FROM_TEST = '../../../src/nextpas.core.platform.sync.ffi.pas';
  PLATFORM_SYNC_FFI_FROM_ROOT = 'core/src/nextpas.core.platform.sync.ffi.pas';
  PLATFORM_THREAD_FFI_FROM_TEST = '../../../src/nextpas.core.platform.thread.ffi.pas';
  PLATFORM_THREAD_FFI_FROM_ROOT = 'core/src/nextpas.core.platform.thread.ffi.pas';

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

function ResolvePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

function ResolveRequiredPath(
  const APathFromTest,
  APathFromRoot,
  AMessage: string): string;
begin
  Result := ResolvePath(APathFromTest, APathFromRoot);
  Check(FileExists(Result), AMessage + ': ' + Result);
end;

procedure CheckTokenPresent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckTokenAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure CheckDocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host ffi gap matrix',
    'host gap matrix doc must have the canonical title');
  CheckTokenPresent(ADoc, 'host base/ffi ownership matrix',
    'host gap matrix doc must name the ownership matrix');
  CheckTokenPresent(ADoc, 'linux', 'host gap matrix doc must include Linux');
  CheckTokenPresent(ADoc, 'android', 'host gap matrix doc must include Android');
  CheckTokenPresent(ADoc, 'darwin', 'host gap matrix doc must include Darwin');
  CheckTokenPresent(ADoc, 'freebsd', 'host gap matrix doc must include FreeBSD');
  CheckTokenPresent(ADoc, 'generic unix', 'host gap matrix doc must include generic Unix');
  CheckTokenPresent(ADoc, 'windows', 'host gap matrix doc must include Windows');
  CheckTokenPresent(ADoc, 'clock', 'host gap matrix doc must include clock coverage');
  CheckTokenPresent(ADoc, 'errno', 'host gap matrix doc must include errno coverage');
  CheckTokenPresent(ADoc, 'cpu count', 'host gap matrix doc must include CPU count coverage');
  CheckTokenPresent(ADoc, 'native thread id', 'host gap matrix doc must include native thread id coverage');
  CheckTokenPresent(ADoc, 'thread lifecycle', 'host gap matrix doc must include thread lifecycle coverage');
  CheckTokenPresent(ADoc, 'tls', 'host gap matrix doc must include TLS coverage');
  CheckTokenPresent(ADoc, 'pthread sync', 'host gap matrix doc must include pthread sync coverage');
  CheckTokenPresent(ADoc, 'timeout capability', 'host gap matrix doc must include timeout capability coverage');
  CheckTokenPresent(ADoc, 'windows kernel32 path', 'host gap matrix doc must identify Windows kernel32 path');
  CheckTokenPresent(ADoc, 'source-surface guard',
    'host gap matrix doc must describe the verification boundary');
  CheckTokenPresent(ADoc, 'not runtime proof',
    'host gap matrix doc must not overstate compile/source evidence as runtime proof');
end;

procedure CheckKnownGapDocumented(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform_pthread_condattr_setclock_supported = 0',
    'host gap matrix doc must record Darwin condattr setclock gap');
  CheckTokenPresent(ADoc, 'platform_pthread_mutex_timedlock_supported = 0',
    'host gap matrix doc must record unsupported mutex timedlock gaps');
  CheckTokenPresent(ADoc, 'platform_sysconf_nprocessors_onln = -1',
    'host gap matrix doc must record generic Unix CPU-count fallback gap');
  CheckTokenPresent(ADoc, 'platform_posix_thread_self_token_u64',
    'host gap matrix doc must record generic Unix native thread-id fallback');
  CheckTokenPresent(ADoc, 'waitonaddress',
    'host gap matrix doc must record Windows wait-address ownership');
  CheckTokenPresent(ADoc, 'queryperformancecounter',
    'host gap matrix doc must record Windows QPC ownership');
  CheckTokenPresent(ADoc, 'getsystemtimeasfiletime',
    'host gap matrix doc must record Windows FILETIME ownership');
end;

procedure CheckHostBaseTokens(
  const ASource,
  AHostName,
  AClockRealtime,
  AClockMonotonic,
  ASysconf,
  ACondAttrSetClock,
  AMutexTimedLock: string);
begin
  CheckTokenPresent(ASource, 'platform_clock_realtime_id = int32(' + AClockRealtime + ')',
    AHostName + ' base must own realtime clock id');
  CheckTokenPresent(ASource, 'platform_clock_monotonic_id = int32(' + AClockMonotonic + ')',
    AHostName + ' base must own monotonic clock id');
  CheckTokenPresent(ASource, 'platform_sysconf_nprocessors_onln = int32(' + ASysconf + ')',
    AHostName + ' base must own CPU-count sysconf id or fallback token');
  CheckTokenPresent(ASource, 'platform_pthread_condattr_setclock_supported = ' + ACondAttrSetClock,
    AHostName + ' base must own condattr setclock capability');
  CheckTokenPresent(ASource, 'platform_pthread_mutex_timedlock_supported = ' + AMutexTimedLock,
    AHostName + ' base must own mutex timedlock capability');
  CheckTokenPresent(ASource, 'platform_pthread_timeout_clock_id',
    AHostName + ' base must own pthread timeout clock policy');
  CheckTokenPresent(ASource, 'platform_posix_etimedout',
    AHostName + ' base must own ETIMEDOUT value');
  CheckTokenPresent(ASource, 'tplatformpthreadtokenalign',
    AHostName + ' base must own pthread token align carrier');
  CheckTokenPresent(ASource, 'pplatformpthreadstate',
    AHostName + ' base must own pthread state carrier');
end;

procedure CheckPosixHostFfiTokens(
  const ASource,
  AHostName,
  AHostPrefix: string);
begin
  CheckTokenPresent(ASource, AHostPrefix + '_errno_location',
    AHostName + ' ffi must own errno binding');
  CheckTokenPresent(ASource, AHostPrefix + '_clock_monotonic_ns_u64',
    AHostName + ' ffi must expose platform clock monotonic helper');
  CheckTokenPresent(ASource, AHostPrefix + '_clock_realtime_ns_u64',
    AHostName + ' ffi must expose platform clock realtime helper');
  CheckTokenPresent(ASource, AHostPrefix + '_clock_monotonic_resolution_ns_u64',
    AHostName + ' ffi must expose platform clock resolution helper');
  CheckTokenPresent(ASource, AHostPrefix + '_native_thread_id_u64',
    AHostName + ' ffi must expose native thread id helper');
  CheckTokenPresent(ASource, AHostPrefix + '_cpu_count_i32',
    AHostName + ' ffi must expose CPU count helper');
  CheckTokenPresent(ASource, AHostPrefix + '_pthread_state_create',
    AHostName + ' ffi must expose thread state create helper');
  CheckTokenPresent(ASource, AHostPrefix + '_pthread_tls_create',
    AHostName + ' ffi must expose TLS create helper');
  CheckTokenPresent(ASource, AHostPrefix + '_pthread_mutex_timedlock_abs',
    AHostName + ' ffi must expose mutex timedlock helper or unsupported stub');
  CheckTokenPresent(ASource, AHostPrefix + '_pthread_sync_result',
    AHostName + ' ffi must own pthread error classification wrapper');
end;

procedure TestHostGapMatrixDocument;
var
  LDocPath: string;
  LDoc: string;
begin
  LDocPath := ResolveRequiredPath(
    DOC_PATH_FROM_TEST,
    DOC_PATH_FROM_ROOT,
    'platform host ffi gap matrix doc must exist');
  LDoc := ReadSourceFile(LDocPath);

  CheckDocumentTokens(LDoc);
  CheckKnownGapDocumented(LDoc);
end;

procedure TestHostSourceTokensMatchMatrix;
var
  LLinuxBase: string;
  LLinuxFfi: string;
  LAndroidBase: string;
  LAndroidFfi: string;
  LDarwinBase: string;
  LDarwinFfi: string;
  LFreeBSDBase: string;
  LFreeBSDFfi: string;
  LUnixBase: string;
  LUnixFfi: string;
  LWindowsBase: string;
  LWindowsFfi: string;
begin
  LLinuxBase := ReadSourceFile(ResolveRequiredPath(LINUX_BASE_PATH_FROM_TEST, LINUX_BASE_PATH_FROM_ROOT, 'linux base must exist'));
  LLinuxFfi := ReadSourceFile(ResolveRequiredPath(LINUX_FFI_PATH_FROM_TEST, LINUX_FFI_PATH_FROM_ROOT, 'linux ffi must exist'));
  LAndroidBase := ReadSourceFile(ResolveRequiredPath(ANDROID_BASE_PATH_FROM_TEST, ANDROID_BASE_PATH_FROM_ROOT, 'android base must exist'));
  LAndroidFfi := ReadSourceFile(ResolveRequiredPath(ANDROID_FFI_PATH_FROM_TEST, ANDROID_FFI_PATH_FROM_ROOT, 'android ffi must exist'));
  LDarwinBase := ReadSourceFile(ResolveRequiredPath(DARWIN_BASE_PATH_FROM_TEST, DARWIN_BASE_PATH_FROM_ROOT, 'darwin base must exist'));
  LDarwinFfi := ReadSourceFile(ResolveRequiredPath(DARWIN_FFI_PATH_FROM_TEST, DARWIN_FFI_PATH_FROM_ROOT, 'darwin ffi must exist'));
  LFreeBSDBase := ReadSourceFile(ResolveRequiredPath(FREEBSD_BASE_PATH_FROM_TEST, FREEBSD_BASE_PATH_FROM_ROOT, 'freebsd base must exist'));
  LFreeBSDFfi := ReadSourceFile(ResolveRequiredPath(FREEBSD_FFI_PATH_FROM_TEST, FREEBSD_FFI_PATH_FROM_ROOT, 'freebsd ffi must exist'));
  LUnixBase := ReadSourceFile(ResolveRequiredPath(UNIX_BASE_PATH_FROM_TEST, UNIX_BASE_PATH_FROM_ROOT, 'generic unix base must exist'));
  LUnixFfi := ReadSourceFile(ResolveRequiredPath(UNIX_FFI_PATH_FROM_TEST, UNIX_FFI_PATH_FROM_ROOT, 'generic unix ffi must exist'));
  LWindowsBase := ReadSourceFile(ResolveRequiredPath(WINDOWS_BASE_PATH_FROM_TEST, WINDOWS_BASE_PATH_FROM_ROOT, 'windows base must exist'));
  LWindowsFfi := ReadSourceFile(ResolveRequiredPath(WINDOWS_FFI_PATH_FROM_TEST, WINDOWS_FFI_PATH_FROM_ROOT, 'windows ffi must exist'));

  CheckHostBaseTokens(LLinuxBase, 'Linux', '0', '1', '84', '1', '1');
  CheckPosixHostFfiTokens(LLinuxFfi, 'Linux', 'linux');
  CheckTokenAbsent(LLinuxFfi, 'function platform_pthread_',
    'Linux ffi must not expose unified-looking platform_pthread helper names');
  CheckTokenAbsent(LLinuxFfi, 'function platform_clock_',
    'Linux ffi must not expose unified-looking platform_clock helper names');
  CheckTokenPresent(LLinuxFfi, 'linux_syscall',
    'Linux ffi must own syscall binding');
  CheckTokenPresent(LLinuxFfi, 'linux_futex_wait_i32',
    'Linux ffi must own futex wait helper');
  CheckTokenPresent(LLinuxFfi, 'gettid',
    'Linux ffi must own native gettid binding');

  CheckHostBaseTokens(LAndroidBase, 'Android', '0', '1', '97', '1', '1');
  CheckPosixHostFfiTokens(LAndroidFfi, 'Android', 'platform');
  CheckTokenPresent(LAndroidFfi, 'gettid',
    'Android ffi must own native gettid binding');

  CheckHostBaseTokens(LDarwinBase, 'Darwin', '0', '1', '58', '0', '0');
  CheckPosixHostFfiTokens(LDarwinFfi, 'Darwin', 'platform');
  CheckTokenPresent(LDarwinBase, 'mach_timebase_info_data_t',
    'Darwin base must own mach timebase record');
  CheckTokenPresent(LDarwinFfi, 'mach_absolute_time',
    'Darwin ffi must own mach absolute time binding');
  CheckTokenPresent(LDarwinFfi, 'pthread_threadid_np',
    'Darwin ffi must own native thread id binding');
  CheckTokenPresent(LDarwinFfi, 'platform_posix_enotsup',
    'Darwin ffi must return host ENOTSUP for unsupported timedlock');

  CheckHostBaseTokens(LFreeBSDBase, 'FreeBSD', '0', '4', '58', '1', '1');
  CheckPosixHostFfiTokens(LFreeBSDFfi, 'FreeBSD', 'platform');
  CheckTokenPresent(LFreeBSDFfi, 'pthread_getthreadid_np',
    'FreeBSD ffi must own native thread id binding');

  CheckHostBaseTokens(LUnixBase, 'generic Unix', '0', '1', '-1', '1', '0');
  CheckPosixHostFfiTokens(LUnixFfi, 'generic Unix', 'platform');
  CheckTokenPresent(LUnixFfi, 'result := platform_thread_self_token_u64;',
    'generic Unix ffi must document native thread id fallback');
  CheckTokenPresent(LUnixFfi, 'platform_posix_sysconf_positive_i32(platform_sysconf_nprocessors_onln)',
    'generic Unix ffi must route CPU count through explicit fallback sysconf token');
  CheckTokenPresent(LUnixFfi, 'platform_posix_enotsup',
    'generic Unix ffi must return host ENOTSUP for unsupported timedlock');

  CheckTokenPresent(LWindowsBase, 'srwlock',
    'Windows base must own SRWLOCK shape');
  CheckTokenPresent(LWindowsBase, 'condition_variable',
    'Windows base must own CONDITION_VARIABLE shape');
  CheckTokenPresent(LWindowsBase, 'filetime = record',
    'Windows base must own FILETIME shape');
  CheckTokenPresent(LWindowsBase, 'system_info = record',
    'Windows base must own SYSTEM_INFO shape');
  CheckTokenPresent(LWindowsBase, 'windows_filetime_unix_epoch_offset_100ns',
    'Windows base must own FILETIME epoch offset');
  CheckTokenPresent(LWindowsFfi, 'waitonaddress',
    'Windows ffi must own WaitOnAddress binding');
  CheckTokenPresent(LWindowsFfi, 'initializeconditionvariable',
    'Windows ffi must own condition variable binding');
  CheckTokenPresent(LWindowsFfi, 'queryperformancecounter',
    'Windows ffi must own QPC binding');
  CheckTokenPresent(LWindowsFfi, 'getsystemtimeasfiletime',
    'Windows ffi must own FILETIME binding');
  CheckTokenPresent(LWindowsFfi, 'getcurrentthreadid',
    'Windows ffi must own native thread id binding');
  CheckTokenPresent(LWindowsFfi, 'tlsalloc',
    'Windows ffi must own TLS binding');
  CheckTokenPresent(LWindowsFfi, 'getsysteminfo',
    'Windows ffi must own CPU count binding');
end;

procedure TestFeatureFFIStaysAbsent;
begin
  Check(not FileExists(ResolvePath(PLATFORM_TIME_FFI_FROM_TEST, PLATFORM_TIME_FFI_FROM_ROOT)),
    'platform.time must not regain a feature-specific ffi unit');
  Check(not FileExists(ResolvePath(PLATFORM_SYNC_FFI_FROM_TEST, PLATFORM_SYNC_FFI_FROM_ROOT)),
    'platform.sync must not regain a feature-specific ffi unit');
  Check(not FileExists(ResolvePath(PLATFORM_THREAD_FFI_FROM_TEST, PLATFORM_THREAD_FFI_FROM_ROOT)),
    'platform.thread must not gain a feature-specific ffi unit');
end;

procedure TestRouteTruthStaysIndexed;
var
  LDesign: string;
  LVerify: string;
begin
  LDesign := ReadSourceFile(ResolveRequiredPath(
    DESIGN_CONVENTIONS_PATH_FROM_TEST,
    DESIGN_CONVENTIONS_PATH_FROM_ROOT,
    'design conventions doc must exist'));
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LDesign, 'docs/platform-host-ffi-gap-matrix.md',
    'design conventions must index the host gap matrix doc');
  CheckTokenPresent(LDesign, 'core-platform-host-gap-matrix-check',
    'design conventions must name the host gap matrix line token');
  CheckTokenPresent(LDesign, 'coreplatformhostgapmatrixcheck',
    'design conventions must name the host gap matrix envelope token');
  CheckTokenPresent(LDesign, 'build/verify_local.sh',
    'design conventions must identify the official local route');

  CheckTokenPresent(LVerify, 'require_path core/docs/platform-host-ffi-gap-matrix.md',
    'verify_local must require the host gap matrix doc');
  CheckTokenPresent(LVerify, 'core-platform-host-gap-matrix-check=running',
    'verify_local must run the host gap matrix focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_gap_matrix: 4 total, 4 passed, 0 failed',
    'verify_local must assert the host gap matrix summary');
  CheckTokenPresent(LVerify, 'coreplatformhostgapmatrixcheck',
    'verify_local final envelope must include the host gap matrix token');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_gap_matrix');
  T.Run('platform host gap matrix doc is explicit', @TestHostGapMatrixDocument);
  T.Run('platform host source tokens match gap matrix', @TestHostSourceTokensMatchMatrix);
  T.Run('platform feature ffi units stay absent', @TestFeatureFFIStaysAbsent);
  T.Run('platform host gap matrix route truth stays indexed', @TestRouteTruthStaysIndexed);
  T.Summary;
end.
