program test_platform_host_abi_wave6_process;

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

  POSIX_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';
  LINUX_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.ffi.pas';
  LINUX_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.ffi.pas';
  ANDROID_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.ffi.pas';
  ANDROID_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.ffi.pas';
  DARWIN_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.ffi.pas';
  DARWIN_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.ffi.pas';
  FREEBSD_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.ffi.pas';
  FREEBSD_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.ffi.pas';
  UNIX_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.unix.ffi.pas';
  UNIX_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.unix.ffi.pas';
  WINDOWS_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.base.pas';
  WINDOWS_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.base.pas';
  WINDOWS_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.ffi.pas';
  WINDOWS_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.ffi.pas';
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

procedure CheckPosixProcessOwnerDoesNotLeakUnifiedNames(
  const AFfi,
  AHostName: string);
begin
  CheckTokenAbsent(AFfi, 'platform_process_fork',
    AHostName + ' ffi must not expose unified-looking process fork helper');
  CheckTokenAbsent(AFfi, 'platform_process_execve',
    AHostName + ' ffi must not expose unified-looking process execve helper');
  CheckTokenAbsent(AFfi, 'platform_process_waitpid',
    AHostName + ' ffi must not expose unified-looking process waitpid helper');
  CheckTokenAbsent(AFfi, 'platform_process_exit',
    AHostName + ' ffi must not expose unified-looking process exit helper');
  CheckTokenAbsent(AFfi, 'platform_process_kill',
    AHostName + ' ffi must not expose unified-looking process kill helper');
end;

procedure CheckWave6DocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host abi completeness wave 6',
    'docs must name Platform Host ABI Completeness Wave 6');
  CheckTokenPresent(ADoc, 'process-control raw abi',
    'docs must identify the process-control raw ABI scope');
  CheckTokenPresent(ADoc, 'fork',
    'docs must include POSIX fork evidence');
  CheckTokenPresent(ADoc, 'execve',
    'docs must include POSIX execve evidence');
  CheckTokenPresent(ADoc, 'waitpid',
    'docs must include POSIX waitpid evidence');
  CheckTokenPresent(ADoc, '_exit',
    'docs must include POSIX _exit evidence');
  CheckTokenPresent(ADoc, 'kill',
    'docs must include POSIX kill evidence');
  CheckTokenPresent(ADoc, 'createprocessa',
    'docs must include Windows CreateProcessA evidence');
  CheckTokenPresent(ADoc, 'process_information',
    'docs must include Windows PROCESS_INFORMATION evidence');
  CheckTokenPresent(ADoc, 'startupinfow',
    'docs must include Windows STARTUPINFOW evidence');
  CheckTokenPresent(ADoc, 'platform.process contract',
    'docs must keep Wave 6 outside a public platform.process contract');
  CheckTokenPresent(ADoc, 'platform_process_*',
    'docs must record that host ffi must not leak unified process helper names');
end;

procedure TestHostAbiWave6PosixProcessSourceTokens;
var
  LPosixFfi: string;
  LLinuxFfi: string;
  LAndroidFfi: string;
  LDarwinFfi: string;
  LFreeBSDFfi: string;
  LUnixFfi: string;
begin
  LPosixFfi := ReadSourceFile(ResolveRequiredPath(POSIX_FFI_PATH_FROM_TEST, POSIX_FFI_PATH_FROM_ROOT, 'posix ffi must exist'));
  LLinuxFfi := ReadSourceFile(ResolveRequiredPath(LINUX_FFI_PATH_FROM_TEST, LINUX_FFI_PATH_FROM_ROOT, 'linux ffi must exist'));
  LAndroidFfi := ReadSourceFile(ResolveRequiredPath(ANDROID_FFI_PATH_FROM_TEST, ANDROID_FFI_PATH_FROM_ROOT, 'android ffi must exist'));
  LDarwinFfi := ReadSourceFile(ResolveRequiredPath(DARWIN_FFI_PATH_FROM_TEST, DARWIN_FFI_PATH_FROM_ROOT, 'darwin ffi must exist'));
  LFreeBSDFfi := ReadSourceFile(ResolveRequiredPath(FREEBSD_FFI_PATH_FROM_TEST, FREEBSD_FFI_PATH_FROM_ROOT, 'freebsd ffi must exist'));
  LUnixFfi := ReadSourceFile(ResolveRequiredPath(UNIX_FFI_PATH_FROM_TEST, UNIX_FFI_PATH_FROM_ROOT, 'generic unix ffi must exist'));

  CheckTokenPresent(LPosixFfi, 'function fork',
    'posix.ffi must own POSIX fork binding');
  CheckTokenPresent(LPosixFfi, 'function execve',
    'posix.ffi must own POSIX execve binding');
  CheckTokenPresent(LPosixFfi, 'function waitpid',
    'posix.ffi must own POSIX waitpid binding');
  CheckTokenPresent(LPosixFfi, 'external ''c'' name ''_exit''',
    'posix.ffi must own POSIX _exit binding');
  CheckTokenPresent(LPosixFfi, 'function kill',
    'posix.ffi must own POSIX kill binding');
  CheckTokenAbsent(LPosixFfi, 'platform_posix_process_fork',
    'posix.ffi must keep Wave 6 as raw POSIX process ABI only');
  CheckTokenAbsent(LPosixFfi, 'platform_posix_process_execve',
    'posix.ffi must keep Wave 6 as raw POSIX process ABI only');
  CheckTokenAbsent(LPosixFfi, 'platform_posix_process_waitpid',
    'posix.ffi must keep Wave 6 as raw POSIX process ABI only');
  CheckTokenAbsent(LPosixFfi, 'platform_posix_process_exit',
    'posix.ffi must keep Wave 6 as raw POSIX process ABI only');
  CheckTokenAbsent(LPosixFfi, 'platform_posix_process_kill',
    'posix.ffi must keep Wave 6 as raw POSIX process ABI only');

  CheckPosixProcessOwnerDoesNotLeakUnifiedNames(LLinuxFfi, 'Linux');
  CheckPosixProcessOwnerDoesNotLeakUnifiedNames(LAndroidFfi, 'Android');
  CheckPosixProcessOwnerDoesNotLeakUnifiedNames(LDarwinFfi, 'Darwin');
  CheckPosixProcessOwnerDoesNotLeakUnifiedNames(LFreeBSDFfi, 'FreeBSD');
  CheckPosixProcessOwnerDoesNotLeakUnifiedNames(LUnixFfi, 'generic Unix');
end;

procedure TestHostAbiWave6WindowsProcessSourceTokens;
var
  LWindowsBase: string;
  LWindowsFfi: string;
begin
  LWindowsBase := ReadSourceFile(ResolveRequiredPath(WINDOWS_BASE_PATH_FROM_TEST, WINDOWS_BASE_PATH_FROM_ROOT, 'windows base must exist'));
  LWindowsFfi := ReadSourceFile(ResolveRequiredPath(WINDOWS_FFI_PATH_FROM_TEST, WINDOWS_FFI_PATH_FROM_ROOT, 'windows ffi must exist'));

  CheckTokenPresent(LWindowsBase, 'process_information',
    'windows.base must own PROCESS_INFORMATION layout');
  CheckTokenPresent(LWindowsBase, 'startupinfoa',
    'windows.base must own STARTUPINFOA layout');
  CheckTokenPresent(LWindowsBase, 'startupinfow',
    'windows.base must own STARTUPINFOW layout');
  CheckTokenPresent(LWindowsBase, 'security_attributes',
    'windows.base must own SECURITY_ATTRIBUTES layout used by CreateProcess');
  CheckTokenPresent(LWindowsBase, 'winbool',
    'windows.base must own FPC Windows WINBOOL alias');
  CheckTokenPresent(LWindowsBase, 'lpvoid',
    'windows.base must own FPC Windows LPVOID alias');
  CheckTokenPresent(LWindowsBase, 'platform_windows_create_new_console',
    'windows.base must own process creation flags');
  CheckTokenPresent(LWindowsBase, 'platform_windows_create_unicode_environment',
    'windows.base must own CREATE_UNICODE_ENVIRONMENT token');

  CheckTokenPresent(LWindowsFfi, 'function createprocessa',
    'windows.ffi must own CreateProcessA binding');
  CheckTokenPresent(LWindowsFfi, 'function createprocessw',
    'windows.ffi must own CreateProcessW binding');
  CheckTokenPresent(LWindowsFfi, 'procedure getstartupinfoa',
    'windows.ffi must own GetStartupInfoA binding');
  CheckTokenPresent(LWindowsFfi, 'procedure getstartupinfow',
    'windows.ffi must own GetStartupInfoW binding');
  CheckTokenPresent(LWindowsFfi, 'function terminateprocess',
    'windows.ffi must own TerminateProcess binding');
  CheckTokenPresent(LWindowsFfi, 'function getexitcodeprocess',
    'windows.ffi must own GetExitCodeProcess binding');
  CheckTokenPresent(LWindowsFfi, 'procedure exitprocess',
    'windows.ffi must own ExitProcess binding');
  CheckTokenPresent(LWindowsFfi, 'lpsecurity_attributes',
    'windows.ffi must use FPC CreateProcess security attributes alias');
  CheckTokenAbsent(LWindowsFfi, 'windows_create_process_a',
    'windows.ffi must not add non-FPC CreateProcess wrapper in raw import wave');
  CheckTokenAbsent(LWindowsFfi, 'windows_create_process_w',
    'windows.ffi must not add non-FPC CreateProcess wrapper in raw import wave');
  CheckTokenAbsent(LWindowsFfi, 'windows_get_exit_code_process',
    'windows.ffi must not add non-FPC exit-code wrapper in raw import wave');
end;

procedure TestHostAbiWave6ProcessEvidenceDocumented;
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

  CheckWave6DocumentTokens(LSourceEvidence);
  CheckWave6DocumentTokens(LGapMatrix);
end;

procedure TestHostAbiWave6ProcessRouteTruth;
var
  LVerify: string;
begin
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LVerify, 'require_path core/tests/nextpas.core.platform/test_platform_host_abi_wave6_process/test_platform_host_abi_wave6_process.lpr',
    'verify_local must require the Wave 6 process ABI source-surface test');
  CheckTokenPresent(LVerify, 'core-platform-host-abi-wave6-process-check=running',
    'verify_local must run the Wave 6 process ABI focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_abi_wave6_process: 5 total, 5 passed, 0 failed',
    'verify_local must assert the Wave 6 process ABI summary');
  CheckTokenPresent(LVerify, 'coreplatformhostabiwave6processcheck',
    'verify_local final envelope must include the Wave 6 process ABI token');
end;

procedure TestFeatureSpecificProcessFfiStillAbsent;
var
  LFeatureProcessPath: string;
  LFeatureProcessFfiPath: string;
  LPlatformTime: string;
  LPlatformSync: string;
  LPlatformThread: string;
begin
  LFeatureProcessPath := ResolvePath(PLATFORM_PROCESS_PATH_FROM_TEST, PLATFORM_PROCESS_PATH_FROM_ROOT);
  Check(not FileExists(LFeatureProcessPath),
    'Wave 6 must not introduce a public platform.process contract: ' + LFeatureProcessPath);
  LFeatureProcessFfiPath := ResolvePath(PLATFORM_PROCESS_FFI_PATH_FROM_TEST, PLATFORM_PROCESS_FFI_PATH_FROM_ROOT);
  Check(not FileExists(LFeatureProcessFfiPath),
    'Wave 6 must not introduce a feature-specific platform.process.ffi owner: ' + LFeatureProcessFfiPath);

  LPlatformTime := ReadSourceFile(ResolveRequiredPath(
    PLATFORM_TIME_PATH_FROM_TEST,
    PLATFORM_TIME_PATH_FROM_ROOT,
    'platform.time must exist'));
  LPlatformSync := ReadSourceFile(ResolveRequiredPath(
    PLATFORM_SYNC_PATH_FROM_TEST,
    PLATFORM_SYNC_PATH_FROM_ROOT,
    'platform.sync must exist'));
  LPlatformThread := ReadSourceFile(ResolveRequiredPath(
    PLATFORM_THREAD_PATH_FROM_TEST,
    PLATFORM_THREAD_PATH_FROM_ROOT,
    'platform.thread must exist'));

  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'platform_process_fork',
    'platform.time/sync/thread must not consume Wave 6 POSIX process raw ABI');
  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'windows_create_process',
    'platform.time/sync/thread must not consume Wave 6 Windows process raw ABI');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_abi_wave6_process');
  T.Run('platform host ABI wave 6 POSIX process source tokens are owned', @TestHostAbiWave6PosixProcessSourceTokens);
  T.Run('platform host ABI wave 6 Windows process source tokens are owned', @TestHostAbiWave6WindowsProcessSourceTokens);
  T.Run('platform host ABI wave 6 process evidence is documented', @TestHostAbiWave6ProcessEvidenceDocumented);
  T.Run('platform host ABI wave 6 process route truth stays indexed', @TestHostAbiWave6ProcessRouteTruth);
  T.Run('platform host ABI wave 6 keeps feature-specific process ffi absent', @TestFeatureSpecificProcessFfiStillAbsent);
  T.Summary;
end.
