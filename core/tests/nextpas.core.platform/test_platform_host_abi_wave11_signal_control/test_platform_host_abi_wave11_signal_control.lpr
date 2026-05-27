program test_platform_host_abi_wave11_signal_control;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  SOURCE_EVIDENCE_PATH_FROM_TEST = '../../../docs/platform-ffi-source-evidence-index.md';
  SOURCE_EVIDENCE_PATH_FROM_ROOT = 'core/docs/platform-ffi-source-evidence-index.md';
  HOST_GAP_MATRIX_PATH_FROM_TEST = '../../../docs/platform-host-ffi-gap-matrix.md';
  HOST_GAP_MATRIX_PATH_FROM_ROOT = 'core/docs/platform-host-ffi-gap-matrix.md';
  GOAL_TREE_PATH_FROM_TEST = '../../../../docs/architecture/nextpas-goal-tree.md';
  GOAL_TREE_PATH_FROM_ROOT = 'docs/architecture/nextpas-goal-tree.md';
  VERIFY_LOCAL_PATH_FROM_TEST = '../../../../build/verify_local.sh';
  VERIFY_LOCAL_PATH_FROM_ROOT = 'build/verify_local.sh';

  POSIX_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.base.pas';
  POSIX_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.base.pas';
  POSIX_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';
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
  PLATFORM_SIGNAL_PATH_FROM_TEST = '../../../src/nextpas.core.platform.signal.pas';
  PLATFORM_SIGNAL_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.signal.pas';
  PLATFORM_SIGNAL_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.signal.ffi.pas';
  PLATFORM_SIGNAL_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.signal.ffi.pas';
  PLATFORM_PROCESS_PATH_FROM_TEST = '../../../src/nextpas.core.platform.process.pas';
  PLATFORM_PROCESS_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.process.pas';
  PLATFORM_PROCESS_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.process.ffi.pas';
  PLATFORM_PROCESS_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.process.ffi.pas';
  PLATFORM_TIME_PATH_FROM_TEST = '../../../src/nextpas.core.platform.time.pas';
  PLATFORM_TIME_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.time.pas';
  PLATFORM_SYNC_PATH_FROM_TEST = '../../../src/nextpas.core.platform.sync.pas';
  PLATFORM_SYNC_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.sync.pas';
  PLATFORM_THREAD_PATH_FROM_TEST = '../../../src/nextpas.core.platform.thread.pas';
  PLATFORM_THREAD_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.thread.pas';

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

procedure CheckWave11DocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host abi completeness wave 11',
    'docs must name Platform Host ABI Completeness Wave 11');
  CheckTokenPresent(ADoc, 'posix signal-control',
    'docs must identify Wave 11 POSIX signal-control scope');
  CheckTokenPresent(ADoc, 'rtl/linux/signal.inc',
    'docs must include Linux signal record evidence');
  CheckTokenPresent(ADoc, 'rtl/linux/ossysc.inc',
    'docs must include Linux rt_sigaction route evidence');
  CheckTokenPresent(ADoc, 'rtl/android/x86_64/sysnr.inc',
    'docs must include Android x86_64 signal syscall evidence');
  CheckTokenPresent(ADoc, 'rtl/android/aarch64/sysnr.inc',
    'docs must include Android aarch64 signal syscall evidence');
  CheckTokenPresent(ADoc, 'rtl/darwin/signal.inc',
    'docs must include Darwin signal record evidence');
  CheckTokenPresent(ADoc, 'rtl/freebsd/signal.inc',
    'docs must include FreeBSD signal record evidence');
  CheckTokenPresent(ADoc, 'rtl/unix/oscdeclh.inc',
    'docs must include Unix libc sigaction evidence');
  CheckTokenPresent(ADoc, 'rtl/unix/gensigset.inc',
    'docs must include shared sigset arithmetic evidence');
  CheckTokenPresent(ADoc, 'no public platform.signal contract',
    'docs must keep public platform.signal deferred');
end;

procedure TestSharedPosixSignalControlStaysDeferred;
var
  LPosixBase: string;
  LPosixFfi: string;
begin
  LPosixBase := ReadSourceFile(ResolveRequiredPath(POSIX_BASE_PATH_FROM_TEST, POSIX_BASE_PATH_FROM_ROOT, 'posix base must exist'));
  LPosixFfi := ReadSourceFile(ResolveRequiredPath(POSIX_FFI_PATH_FROM_TEST, POSIX_FFI_PATH_FROM_ROOT, 'posix ffi must exist'));

  CheckTokenAbsent(LPosixBase, 'tplatformposixsignalset',
    'posix.base must not invent a shared POSIX signal set record');
  CheckTokenAbsent(LPosixBase, 'tplatformposixsigaction',
    'posix.base must not invent a shared POSIX sigaction record');
  CheckTokenAbsent(LPosixFfi, 'function sigaction',
    'posix.ffi must not expose a shared sigaction binding');
  CheckTokenAbsent(LPosixFfi, 'function sigprocmask',
    'posix.ffi must not expose a shared sigprocmask binding');
  CheckTokenAbsent(LPosixFfi, 'function platform_signal_',
    'posix.ffi must not expose a public-looking platform.signal contract');
end;

procedure CheckSignalBaseTokens(const ASource, AHostName: string);
begin
  CheckTokenPresent(ASource, 'platform_signal_action_siginfo',
    AHostName + ' base must own SA_SIGINFO');
  CheckTokenPresent(ASource, 'platform_signal_action_restart',
    AHostName + ' base must own SA_RESTART');
  CheckTokenPresent(ASource, 'platform_signal_mask_block',
    AHostName + ' base must own SIG_BLOCK');
  CheckTokenPresent(ASource, 'platform_signal_mask_unblock',
    AHostName + ' base must own SIG_UNBLOCK');
  CheckTokenPresent(ASource, 'platform_signal_mask_setmask',
    AHostName + ' base must own SIG_SETMASK');
  CheckTokenPresent(ASource, 'tplatform' + LowerCase(AHostName) + 'sigaction',
    AHostName + ' base must own host sigaction record');
  CheckTokenPresent(ASource, 'pplatform' + LowerCase(AHostName) + 'sigaction',
    AHostName + ' base must own host sigaction pointer');
  CheckTokenPresent(ASource, 'tplatform' + LowerCase(AHostName) + 'signalset',
    AHostName + ' base must own host signal set record');
  CheckTokenPresent(ASource, 'pplatform' + LowerCase(AHostName) + 'signalset',
    AHostName + ' base must own host signal set pointer');
end;

procedure TestLinuxAndAndroidSignalControlOwners;
var
  LLinuxBase: string;
  LLinuxFfi: string;
  LAndroidBase: string;
  LAndroidFfi: string;
begin
  LLinuxBase := ReadSourceFile(ResolveRequiredPath(LINUX_BASE_PATH_FROM_TEST, LINUX_BASE_PATH_FROM_ROOT, 'linux base must exist'));
  LLinuxFfi := ReadSourceFile(ResolveRequiredPath(LINUX_FFI_PATH_FROM_TEST, LINUX_FFI_PATH_FROM_ROOT, 'linux ffi must exist'));
  LAndroidBase := ReadSourceFile(ResolveRequiredPath(ANDROID_BASE_PATH_FROM_TEST, ANDROID_BASE_PATH_FROM_ROOT, 'android base must exist'));
  LAndroidFfi := ReadSourceFile(ResolveRequiredPath(ANDROID_FFI_PATH_FROM_TEST, ANDROID_FFI_PATH_FROM_ROOT, 'android ffi must exist'));

  CheckSignalBaseTokens(LLinuxBase, 'Linux');
  CheckTokenPresent(LLinuxBase, 'linux_syscall_rt_sigaction',
    'linux.base must own Linux rt_sigaction syscall number');
  CheckTokenPresent(LLinuxBase, 'linux_syscall_rt_sigprocmask',
    'linux.base must own Linux rt_sigprocmask syscall number');
  CheckTokenPresent(LLinuxFfi, 'function linux_rt_sigaction',
    'linux.ffi must own Linux rt_sigaction syscall projection');
  CheckTokenPresent(LLinuxFfi, 'function linux_rt_sigprocmask',
    'linux.ffi must own Linux rt_sigprocmask syscall projection');

  CheckSignalBaseTokens(LAndroidBase, 'Android');
  CheckTokenPresent(LAndroidBase, 'android_syscall_rt_sigaction',
    'android.base must own Android rt_sigaction syscall number');
  CheckTokenPresent(LAndroidBase, 'android_syscall_rt_sigprocmask',
    'android.base must own Android rt_sigprocmask syscall number');
  CheckTokenPresent(LAndroidFfi, 'function android_rt_sigaction',
    'android.ffi must own Android rt_sigaction syscall projection');
  CheckTokenPresent(LAndroidFfi, 'function android_rt_sigprocmask',
    'android.ffi must own Android rt_sigprocmask syscall projection');
end;

procedure TestDarwinAndFreeBSDSignalControlOwners;
var
  LDarwinBase: string;
  LDarwinFfi: string;
  LFreeBSDBase: string;
  LFreeBSDFfi: string;
begin
  LDarwinBase := ReadSourceFile(ResolveRequiredPath(DARWIN_BASE_PATH_FROM_TEST, DARWIN_BASE_PATH_FROM_ROOT, 'darwin base must exist'));
  LDarwinFfi := ReadSourceFile(ResolveRequiredPath(DARWIN_FFI_PATH_FROM_TEST, DARWIN_FFI_PATH_FROM_ROOT, 'darwin ffi must exist'));
  LFreeBSDBase := ReadSourceFile(ResolveRequiredPath(FREEBSD_BASE_PATH_FROM_TEST, FREEBSD_BASE_PATH_FROM_ROOT, 'freebsd base must exist'));
  LFreeBSDFfi := ReadSourceFile(ResolveRequiredPath(FREEBSD_FFI_PATH_FROM_TEST, FREEBSD_FFI_PATH_FROM_ROOT, 'freebsd ffi must exist'));

  CheckSignalBaseTokens(LDarwinBase, 'Darwin');
  CheckTokenPresent(LDarwinFfi, 'function darwin_sigaction',
    'darwin.ffi must own Darwin sigaction libc binding');
  CheckTokenPresent(LDarwinFfi, 'function darwin_sigprocmask',
    'darwin.ffi must own Darwin sigprocmask libc binding');
  CheckTokenPresent(LDarwinFfi, 'function darwin_pthread_sigmask',
    'darwin.ffi must own Darwin pthread_sigmask binding');
  CheckTokenPresent(LDarwinFfi, 'external ''c'' name ''pthread_sigmask''',
    'darwin.ffi must mirror FPC Darwin pthread_sigmask libc binding');
  CheckTokenPresent(LDarwinFfi, 'external ''c'' name ''pthread_sigmask''',
    'darwin.ffi must follow FPC Darwin pthread_sigmask libc binding');

  CheckSignalBaseTokens(LFreeBSDBase, 'FreeBSD');
  CheckTokenPresent(LFreeBSDFfi, 'function freebsd_sigaction',
    'freebsd.ffi must own FreeBSD sigaction libc binding');
  CheckTokenPresent(LFreeBSDFfi, 'function freebsd_sigprocmask',
    'freebsd.ffi must own FreeBSD sigprocmask libc binding');
  CheckTokenPresent(LFreeBSDFfi, 'function freebsd_pthread_sigmask',
    'freebsd.ffi must own FreeBSD pthread_sigmask binding');
end;

procedure TestGenericUnixSignalControlStaysConservative;
var
  LUnixBase: string;
  LUnixFfi: string;
begin
  LUnixBase := ReadSourceFile(ResolveRequiredPath(UNIX_BASE_PATH_FROM_TEST, UNIX_BASE_PATH_FROM_ROOT, 'generic unix base must exist'));
  LUnixFfi := ReadSourceFile(ResolveRequiredPath(UNIX_FFI_PATH_FROM_TEST, UNIX_FFI_PATH_FROM_ROOT, 'generic unix ffi must exist'));

  CheckTokenPresent(LUnixBase, 'tplatformunixsigaction',
    'generic Unix base may carry a conservative libc sigaction record');
  CheckTokenPresent(LUnixFfi, 'function unix_sigaction',
    'generic Unix ffi must own conservative libc sigaction binding');
  CheckTokenPresent(LUnixFfi, 'function unix_sigprocmask',
    'generic Unix ffi must own conservative libc sigprocmask binding');
  CheckTokenAbsent(LUnixFfi, 'rt_sigaction',
    'generic Unix ffi must not invent a Linux syscall route');
end;

procedure TestHostAbiWave11SignalControlEvidenceDocumented;
var
  LSourceEvidence: string;
  LGapMatrix: string;
  LGoalTree: string;
begin
  LSourceEvidence := ReadSourceFile(ResolveRequiredPath(SOURCE_EVIDENCE_PATH_FROM_TEST, SOURCE_EVIDENCE_PATH_FROM_ROOT, 'source evidence index doc must exist'));
  LGapMatrix := ReadSourceFile(ResolveRequiredPath(HOST_GAP_MATRIX_PATH_FROM_TEST, HOST_GAP_MATRIX_PATH_FROM_ROOT, 'host gap matrix doc must exist'));
  LGoalTree := ReadSourceFile(ResolveRequiredPath(GOAL_TREE_PATH_FROM_TEST, GOAL_TREE_PATH_FROM_ROOT, 'goal tree doc must exist'));

  CheckWave11DocumentTokens(LSourceEvidence);
  CheckWave11DocumentTokens(LGapMatrix);
  CheckTokenPresent(LGoalTree, 'platform host abi completeness wave 11',
    'goal tree must route the current platform ABI wave');
  CheckTokenPresent(LGoalTree, 'posix signal-control',
    'goal tree must name the Wave 11 platform ABI scope');
end;

procedure TestHostAbiWave11SignalControlRouteTruth;
var
  LVerify: string;
begin
  LVerify := ReadSourceFile(ResolveRequiredPath(VERIFY_LOCAL_PATH_FROM_TEST, VERIFY_LOCAL_PATH_FROM_ROOT, 'verify_local route must exist'));

  CheckTokenPresent(LVerify, 'require_path core/tests/nextpas.core.platform/test_platform_host_abi_wave11_signal_control/test_platform_host_abi_wave11_signal_control.lpr',
    'verify_local must require the Wave 11 signal-control source-surface test');
  CheckTokenPresent(LVerify, 'core-platform-host-abi-wave11-signal-control-check=running',
    'verify_local must run the Wave 11 signal-control focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_abi_wave11_signal_control: 7 total, 7 passed, 0 failed',
    'verify_local must assert the Wave 11 signal-control pass summary');
  CheckTokenPresent(LVerify, 'coreplatformhostabiwave11signalcontrolcheck',
    'verify_local final envelope must include the Wave 11 signal-control token');
end;

procedure TestFeatureSpecificSignalAndProcessFfiStillAbsent;
var
  LFeatureSignalPath: string;
  LFeatureSignalFfiPath: string;
  LFeatureProcessPath: string;
  LFeatureProcessFfiPath: string;
  LPlatformTime: string;
  LPlatformSync: string;
  LPlatformThread: string;
begin
  LFeatureSignalPath := ResolvePath(PLATFORM_SIGNAL_PATH_FROM_TEST, PLATFORM_SIGNAL_PATH_FROM_ROOT);
  LFeatureSignalFfiPath := ResolvePath(PLATFORM_SIGNAL_FFI_PATH_FROM_TEST, PLATFORM_SIGNAL_FFI_PATH_FROM_ROOT);
  LFeatureProcessPath := ResolvePath(PLATFORM_PROCESS_PATH_FROM_TEST, PLATFORM_PROCESS_PATH_FROM_ROOT);
  LFeatureProcessFfiPath := ResolvePath(PLATFORM_PROCESS_FFI_PATH_FROM_TEST, PLATFORM_PROCESS_FFI_PATH_FROM_ROOT);
  Check(not FileExists(LFeatureSignalPath),
    'Wave 11 must not introduce a public platform.signal contract: ' + LFeatureSignalPath);
  Check(not FileExists(LFeatureSignalFfiPath),
    'Wave 11 must not introduce a feature-specific platform.signal.ffi owner: ' + LFeatureSignalFfiPath);
  Check(not FileExists(LFeatureProcessPath),
    'Wave 11 must not introduce a public platform.process contract: ' + LFeatureProcessPath);
  Check(not FileExists(LFeatureProcessFfiPath),
    'Wave 11 must not introduce a feature-specific platform.process.ffi owner: ' + LFeatureProcessFfiPath);

  LPlatformTime := ReadSourceFile(ResolveRequiredPath(PLATFORM_TIME_PATH_FROM_TEST, PLATFORM_TIME_PATH_FROM_ROOT, 'platform.time must exist'));
  LPlatformSync := ReadSourceFile(ResolveRequiredPath(PLATFORM_SYNC_PATH_FROM_TEST, PLATFORM_SYNC_PATH_FROM_ROOT, 'platform.sync must exist'));
  LPlatformThread := ReadSourceFile(ResolveRequiredPath(PLATFORM_THREAD_PATH_FROM_TEST, PLATFORM_THREAD_PATH_FROM_ROOT, 'platform.thread must exist'));

  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'sigaction',
    'platform.time/sync/thread must not consume Wave 11 raw sigaction ABI');
  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'sigprocmask',
    'platform.time/sync/thread must not consume Wave 11 raw sigprocmask ABI');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_abi_wave11_signal_control');
  T.Run('platform host ABI wave 11 keeps shared POSIX signal-control deferred', @TestSharedPosixSignalControlStaysDeferred);
  T.Run('platform host ABI wave 11 Linux and Android signal-control owners are present', @TestLinuxAndAndroidSignalControlOwners);
  T.Run('platform host ABI wave 11 Darwin and FreeBSD signal-control owners are present', @TestDarwinAndFreeBSDSignalControlOwners);
  T.Run('platform host ABI wave 11 generic Unix signal-control remains conservative', @TestGenericUnixSignalControlStaysConservative);
  T.Run('platform host ABI wave 11 signal-control evidence is documented', @TestHostAbiWave11SignalControlEvidenceDocumented);
  T.Run('platform host ABI wave 11 signal-control route truth stays indexed', @TestHostAbiWave11SignalControlRouteTruth);
  T.Run('platform host ABI wave 11 keeps feature-specific signal/process ffi absent', @TestFeatureSpecificSignalAndProcessFfiStillAbsent);
  T.Summary;
end.
