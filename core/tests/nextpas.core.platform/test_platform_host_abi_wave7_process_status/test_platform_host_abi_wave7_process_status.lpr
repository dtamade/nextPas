program test_platform_host_abi_wave7_process_status;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  SOURCE_EVIDENCE_PATH_FROM_TEST = '../../../docs/platform-ffi-source-evidence-index.md';
  SOURCE_EVIDENCE_PATH_FROM_ROOT = 'core/docs/platform-ffi-source-evidence-index.md';
  HOST_GAP_MATRIX_PATH_FROM_TEST = '../../../docs/platform-host-ffi-gap-matrix.md';
  HOST_GAP_MATRIX_PATH_FROM_ROOT = 'core/docs/platform-host-ffi-gap-matrix.md';
  VERIFY_LOCAL_PATH_FROM_TEST = '../../../../build/verify_local.sh';
  VERIFY_LOCAL_PATH_FROM_ROOT = 'build/verify_local.sh';

  POSIX_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.base.pas';
  POSIX_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.base.pas';
  POSIX_MATH_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.math.pas';
  POSIX_MATH_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.math.pas';
  LINUX_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.base.pas';
  LINUX_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.base.pas';
  ANDROID_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.base.pas';
  ANDROID_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.base.pas';
  DARWIN_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.base.pas';
  DARWIN_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.base.pas';
  FREEBSD_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.base.pas';
  FREEBSD_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.base.pas';
  UNIX_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.unix.base.pas';
  UNIX_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.unix.base.pas';
  WINDOWS_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.base.pas';
  WINDOWS_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.base.pas';
  PLATFORM_PROCESS_PATH_FROM_TEST = '../../../src/nextpas.core.platform.process.pas';
  PLATFORM_PROCESS_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.process.pas';
  PLATFORM_PROCESS_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.process.ffi.pas';
  PLATFORM_PROCESS_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.process.ffi.pas';

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

procedure CheckPosixHostWaitAndSignalTokens(
  const ASource,
  AHostName,
  AChildSignal: string);
begin
  CheckTokenPresent(ASource, 'platform_wait_nohang = int32(1)',
    AHostName + ' base must own WNOHANG token');
  CheckTokenPresent(ASource, 'platform_wait_untraced = int32(2)',
    AHostName + ' base must own WUNTRACED token');
  CheckTokenPresent(ASource, 'platform_signal_hangup = int32(1)',
    AHostName + ' base must own SIGHUP token');
  CheckTokenPresent(ASource, 'platform_signal_interrupt = int32(2)',
    AHostName + ' base must own SIGINT token');
  CheckTokenPresent(ASource, 'platform_signal_kill = int32(9)',
    AHostName + ' base must own SIGKILL token');
  CheckTokenPresent(ASource, 'platform_signal_terminate = int32(15)',
    AHostName + ' base must own SIGTERM token');
  CheckTokenPresent(ASource, 'platform_signal_child = int32(' + AChildSignal + ')',
    AHostName + ' base must own host-specific SIGCHLD token');
end;

procedure TestHostAbiWave7PosixStatusSourceTokens;
var
  LPosixBase: string;
  LPosixMath: string;
  LLinuxBase: string;
  LAndroidBase: string;
  LDarwinBase: string;
  LFreeBSDBase: string;
  LUnixBase: string;
begin
  LPosixBase := ReadSourceFile(ResolveRequiredPath(POSIX_BASE_PATH_FROM_TEST, POSIX_BASE_PATH_FROM_ROOT, 'posix base must exist'));
  LPosixMath := ReadSourceFile(ResolveRequiredPath(POSIX_MATH_PATH_FROM_TEST, POSIX_MATH_PATH_FROM_ROOT, 'posix math must exist'));
  LLinuxBase := ReadSourceFile(ResolveRequiredPath(LINUX_BASE_PATH_FROM_TEST, LINUX_BASE_PATH_FROM_ROOT, 'linux base must exist'));
  LAndroidBase := ReadSourceFile(ResolveRequiredPath(ANDROID_BASE_PATH_FROM_TEST, ANDROID_BASE_PATH_FROM_ROOT, 'android base must exist'));
  LDarwinBase := ReadSourceFile(ResolveRequiredPath(DARWIN_BASE_PATH_FROM_TEST, DARWIN_BASE_PATH_FROM_ROOT, 'darwin base must exist'));
  LFreeBSDBase := ReadSourceFile(ResolveRequiredPath(FREEBSD_BASE_PATH_FROM_TEST, FREEBSD_BASE_PATH_FROM_ROOT, 'freebsd base must exist'));
  LUnixBase := ReadSourceFile(ResolveRequiredPath(UNIX_BASE_PATH_FROM_TEST, UNIX_BASE_PATH_FROM_ROOT, 'generic unix base must exist'));

  CheckTokenPresent(LPosixBase, 'platform_wait_core_flag = int32($80)',
    'posix.base must own FPC WCOREFLAG token');
  CheckTokenPresent(LPosixMath, 'platform_posix_wait_exit_status',
    'posix.math must own WEXITSTATUS macro projection');
  CheckTokenPresent(LPosixMath, 'platform_posix_wait_term_signal',
    'posix.math must own WTERMSIG macro projection');
  CheckTokenPresent(LPosixMath, 'platform_posix_wait_stop_signal',
    'posix.math must own WSTOPSIG macro projection');
  CheckTokenPresent(LPosixMath, 'platform_posix_wait_if_exited',
    'posix.math must own WIFEXITED macro projection');
  CheckTokenPresent(LPosixMath, 'platform_posix_wait_if_signaled',
    'posix.math must own WIFSIGNALED macro projection');
  CheckTokenPresent(LPosixMath, 'platform_posix_wait_if_stopped',
    'posix.math must own WIFSTOPPED macro projection');
  CheckTokenPresent(LPosixMath, 'platform_posix_wait_core_dumped',
    'posix.math must own WCOREDUMP macro projection');
  CheckTokenPresent(LPosixMath, 'platform_posix_wait_exit_code',
    'posix.math must own W_EXITCODE macro projection');
  CheckTokenPresent(LPosixMath, 'platform_posix_wait_stop_code',
    'posix.math must own W_STOPCODE macro projection');

  CheckPosixHostWaitAndSignalTokens(LLinuxBase, 'Linux', '17');
  CheckPosixHostWaitAndSignalTokens(LAndroidBase, 'Android', '17');
  CheckPosixHostWaitAndSignalTokens(LDarwinBase, 'Darwin', '20');
  CheckPosixHostWaitAndSignalTokens(LFreeBSDBase, 'FreeBSD', '20');
  CheckPosixHostWaitAndSignalTokens(LUnixBase, 'generic Unix', '17');
end;

procedure TestHostAbiWave7WindowsStatusSourceTokens;
var
  LWindowsBase: string;
begin
  LWindowsBase := ReadSourceFile(ResolveRequiredPath(
    WINDOWS_BASE_PATH_FROM_TEST,
    WINDOWS_BASE_PATH_FROM_ROOT,
    'windows base must exist'));

  CheckTokenPresent(LWindowsBase, 'wait_timeout = dword($102)',
    'windows.base must own WAIT_TIMEOUT token');
  CheckTokenPresent(LWindowsBase, 'wait_failed = dword($ffffffff)',
    'windows.base must own WAIT_FAILED token');
  CheckTokenPresent(LWindowsBase, 'still_active = dword($103)',
    'windows.base must own STILL_ACTIVE token');
  CheckTokenPresent(LWindowsBase, 'synchronize = dword($100000)',
    'windows.base must own SYNCHRONIZE token');
  CheckTokenPresent(LWindowsBase, 'process_terminate = dword($0001)',
    'windows.base must own PROCESS_TERMINATE token');
  CheckTokenPresent(LWindowsBase, 'duplicate_same_access = dword(2)',
    'windows.base must own DUPLICATE_SAME_ACCESS token');
end;

procedure CheckWave7DocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host abi completeness wave 7',
    'docs must name Platform Host ABI Completeness Wave 7');
  CheckTokenPresent(ADoc, 'process wait-status',
    'docs must identify the process wait-status raw ABI scope');
  CheckTokenPresent(ADoc, 'wnohang',
    'docs must include WNOHANG evidence');
  CheckTokenPresent(ADoc, 'wuntraced',
    'docs must include WUNTRACED evidence');
  CheckTokenPresent(ADoc, 'wexitstatus',
    'docs must include WEXITSTATUS evidence');
  CheckTokenPresent(ADoc, 'wifstopped',
    'docs must include WIFSTOPPED evidence');
  CheckTokenPresent(ADoc, 'sigchld',
    'docs must include host-specific SIGCHLD evidence');
  CheckTokenPresent(ADoc, 'wait_timeout',
    'docs must include Windows WAIT_TIMEOUT evidence');
  CheckTokenPresent(ADoc, 'wait_failed',
    'docs must include Windows WAIT_FAILED evidence');
  CheckTokenPresent(ADoc, 'still_active',
    'docs must include Windows STILL_ACTIVE evidence');
  CheckTokenPresent(ADoc, 'process_terminate',
    'docs must include Windows PROCESS_TERMINATE evidence');
end;

procedure TestHostAbiWave7ProcessStatusEvidenceDocumented;
var
  LSourceEvidence: string;
  LGapMatrix: string;
begin
  LSourceEvidence := ReadSourceFile(ResolveRequiredPath(
    SOURCE_EVIDENCE_PATH_FROM_TEST,
    SOURCE_EVIDENCE_PATH_FROM_ROOT,
    'source evidence index doc must exist'));
  LGapMatrix := ReadSourceFile(ResolveRequiredPath(
    HOST_GAP_MATRIX_PATH_FROM_TEST,
    HOST_GAP_MATRIX_PATH_FROM_ROOT,
    'host gap matrix doc must exist'));

  CheckWave7DocumentTokens(LSourceEvidence);
  CheckWave7DocumentTokens(LGapMatrix);
end;

procedure TestHostAbiWave7ProcessStatusRouteTruth;
var
  LVerify: string;
begin
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LVerify, 'require_path core/tests/nextpas.core.platform/test_platform_host_abi_wave7_process_status/test_platform_host_abi_wave7_process_status.lpr',
    'verify_local must require the Wave 7 process status ABI source-surface test');
  CheckTokenPresent(LVerify, 'core-platform-host-abi-wave7-process-status-check=running',
    'verify_local must run the Wave 7 process status ABI focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_abi_wave7_process_status: 5 total, 5 passed, 0 failed',
    'verify_local must assert the Wave 7 process status ABI summary');
  CheckTokenPresent(LVerify, 'coreplatformhostabiwave7processstatuscheck',
    'verify_local final envelope must include the Wave 7 process status ABI token');
end;

procedure TestFeatureSpecificProcessFfiStillAbsent;
var
  LFeatureProcessPath: string;
  LFeatureProcessFfiPath: string;
begin
  LFeatureProcessPath := ResolvePath(PLATFORM_PROCESS_PATH_FROM_TEST, PLATFORM_PROCESS_PATH_FROM_ROOT);
  Check(not FileExists(LFeatureProcessPath),
    'Wave 7 must not introduce a public platform.process contract: ' + LFeatureProcessPath);
  LFeatureProcessFfiPath := ResolvePath(PLATFORM_PROCESS_FFI_PATH_FROM_TEST, PLATFORM_PROCESS_FFI_PATH_FROM_ROOT);
  Check(not FileExists(LFeatureProcessFfiPath),
    'Wave 7 must not introduce a feature-specific platform.process.ffi owner: ' + LFeatureProcessFfiPath);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_abi_wave7_process_status');
  T.Run('platform host ABI wave 7 POSIX status source tokens are owned', @TestHostAbiWave7PosixStatusSourceTokens);
  T.Run('platform host ABI wave 7 Windows status source tokens are owned', @TestHostAbiWave7WindowsStatusSourceTokens);
  T.Run('platform host ABI wave 7 process status evidence is documented', @TestHostAbiWave7ProcessStatusEvidenceDocumented);
  T.Run('platform host ABI wave 7 process status route truth stays indexed', @TestHostAbiWave7ProcessStatusRouteTruth);
  T.Run('platform host ABI wave 7 keeps feature-specific process ffi absent', @TestFeatureSpecificProcessFfiStillAbsent);
  T.Summary;
end.
