program test_platform_host_abi_wave5_env;

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
  WINDOWS_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.windows.ffi.pas';
  WINDOWS_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.windows.ffi.pas';
  PLATFORM_ENV_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.env.ffi.pas';
  PLATFORM_ENV_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.env.ffi.pas';
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

procedure CheckPosixEnvironmentOwnerTokens(
  const AFfi,
  AHostName: string);
begin
  CheckTokenPresent(AFfi, 'function platform_environment_get',
    AHostName + ' ffi must expose environment get helper');
  CheckTokenPresent(AFfi, 'function platform_environment_set',
    AHostName + ' ffi must expose environment set helper');
  CheckTokenPresent(AFfi, 'function platform_environment_unset',
    AHostName + ' ffi must expose environment unset helper');
  CheckTokenPresent(AFfi, 'function platform_environment_put',
    AHostName + ' ffi must expose environment put helper');
end;

procedure CheckWave5DocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host abi completeness wave 5',
    'docs must name Platform Host ABI Completeness Wave 5');
  CheckTokenPresent(ADoc, 'environment abi raw inventory',
    'docs must identify the environment ABI raw inventory scope');
  CheckTokenPresent(ADoc, 'getenv',
    'docs must include POSIX getenv evidence');
  CheckTokenPresent(ADoc, 'setenv',
    'docs must include POSIX setenv fallback evidence');
  CheckTokenPresent(ADoc, 'unsetenv',
    'docs must include POSIX unsetenv fallback evidence');
  CheckTokenPresent(ADoc, 'putenv',
    'docs must include POSIX putenv fallback evidence');
  CheckTokenPresent(ADoc, 'posix libc/header fallback',
    'docs must mark mutating POSIX environment APIs as header fallback');
  CheckTokenPresent(ADoc, 'getenvironmentvariablea',
    'docs must include Windows GetEnvironmentVariableA evidence');
  CheckTokenPresent(ADoc, 'freeenvironmentstringsw',
    'docs must include Windows FreeEnvironmentStringsW evidence');
  CheckTokenPresent(ADoc, 'expandenvironmentstringsw',
    'docs must include Windows ExpandEnvironmentStringsW evidence');
  CheckTokenPresent(ADoc, 'no public platform.env contract',
    'docs must keep Wave 5 outside a public platform.env contract');
end;

procedure TestHostAbiWave5PosixEnvironmentSourceTokens;
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

  CheckTokenPresent(LPosixFfi, 'function getenv',
    'posix.ffi must own POSIX getenv binding');
  CheckTokenPresent(LPosixFfi, 'function setenv',
    'posix.ffi must own POSIX setenv binding');
  CheckTokenPresent(LPosixFfi, 'function unsetenv',
    'posix.ffi must own POSIX unsetenv binding');
  CheckTokenPresent(LPosixFfi, 'function putenv',
    'posix.ffi must own POSIX putenv binding');
  CheckTokenPresent(LPosixFfi, 'function platform_posix_environment_get',
    'posix.ffi must expose shared environment get helper');
  CheckTokenPresent(LPosixFfi, 'function platform_posix_environment_set',
    'posix.ffi must expose shared environment set helper');
  CheckTokenPresent(LPosixFfi, 'function platform_posix_environment_unset',
    'posix.ffi must expose shared environment unset helper');
  CheckTokenPresent(LPosixFfi, 'function platform_posix_environment_put',
    'posix.ffi must expose shared environment put helper');

  CheckPosixEnvironmentOwnerTokens(LLinuxFfi, 'Linux');
  CheckPosixEnvironmentOwnerTokens(LAndroidFfi, 'Android');
  CheckPosixEnvironmentOwnerTokens(LDarwinFfi, 'Darwin');
  CheckPosixEnvironmentOwnerTokens(LFreeBSDFfi, 'FreeBSD');
  CheckPosixEnvironmentOwnerTokens(LUnixFfi, 'generic Unix');
end;

procedure TestHostAbiWave5WindowsEnvironmentSourceTokens;
var
  LWindowsFfi: string;
begin
  LWindowsFfi := ReadSourceFile(ResolveRequiredPath(WINDOWS_FFI_PATH_FROM_TEST, WINDOWS_FFI_PATH_FROM_ROOT, 'windows ffi must exist'));

  CheckTokenPresent(LWindowsFfi, 'function getenvironmentvariablea',
    'windows.ffi must own GetEnvironmentVariableA binding');
  CheckTokenPresent(LWindowsFfi, 'function getenvironmentvariablew',
    'windows.ffi must own GetEnvironmentVariableW binding');
  CheckTokenPresent(LWindowsFfi, 'function setenvironmentvariablea',
    'windows.ffi must own SetEnvironmentVariableA binding');
  CheckTokenPresent(LWindowsFfi, 'function setenvironmentvariablew',
    'windows.ffi must own SetEnvironmentVariableW binding');
  CheckTokenPresent(LWindowsFfi, 'function getenvironmentstringsa',
    'windows.ffi must own GetEnvironmentStringsA binding');
  CheckTokenPresent(LWindowsFfi, 'function getenvironmentstringsw',
    'windows.ffi must own GetEnvironmentStringsW binding');
  CheckTokenPresent(LWindowsFfi, 'function freeenvironmentstringsa',
    'windows.ffi must own FreeEnvironmentStringsA binding');
  CheckTokenPresent(LWindowsFfi, 'function freeenvironmentstringsw',
    'windows.ffi must own FreeEnvironmentStringsW binding');
  CheckTokenPresent(LWindowsFfi, 'function expandenvironmentstringsa',
    'windows.ffi must own ExpandEnvironmentStringsA binding');
  CheckTokenPresent(LWindowsFfi, 'function expandenvironmentstringsw',
    'windows.ffi must own ExpandEnvironmentStringsW binding');
  CheckTokenPresent(LWindowsFfi, 'function windows_get_environment_variable_a',
    'windows.ffi must expose ANSI environment get helper');
  CheckTokenPresent(LWindowsFfi, 'function windows_set_environment_variable_w',
    'windows.ffi must expose wide environment set helper');
  CheckTokenPresent(LWindowsFfi, 'function windows_expand_environment_strings_w',
    'windows.ffi must expose wide environment expansion helper');
end;

procedure TestHostAbiWave5EnvironmentEvidenceDocumented;
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

  CheckWave5DocumentTokens(LSourceEvidence);
  CheckWave5DocumentTokens(LGapMatrix);
end;

procedure TestHostAbiWave5EnvironmentRouteTruth;
var
  LVerify: string;
begin
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LVerify, 'require_path core/tests/nextpas.core.platform/test_platform_host_abi_wave5_env/test_platform_host_abi_wave5_env.lpr',
    'verify_local must require the Wave 5 environment ABI source-surface test');
  CheckTokenPresent(LVerify, 'core-platform-host-abi-wave5-env-check=running',
    'verify_local must run the Wave 5 environment ABI focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_abi_wave5_env: 5 total, 5 passed, 0 failed',
    'verify_local must assert the Wave 5 environment ABI summary');
  CheckTokenPresent(LVerify, 'coreplatformhostabiwave5envcheck',
    'verify_local final envelope must include the Wave 5 environment ABI token');
end;

procedure TestFeatureSpecificEnvironmentFfiStillAbsent;
var
  LFeatureEnvFfiPath: string;
  LFeatureProcessFfiPath: string;
  LPlatformTime: string;
  LPlatformSync: string;
  LPlatformThread: string;
begin
  LFeatureEnvFfiPath := ResolvePath(PLATFORM_ENV_FFI_PATH_FROM_TEST, PLATFORM_ENV_FFI_PATH_FROM_ROOT);
  Check(not FileExists(LFeatureEnvFfiPath),
    'Wave 5 must not introduce a feature-specific platform.env.ffi owner: ' + LFeatureEnvFfiPath);
  LFeatureProcessFfiPath := ResolvePath(PLATFORM_PROCESS_FFI_PATH_FROM_TEST, PLATFORM_PROCESS_FFI_PATH_FROM_ROOT);
  Check(not FileExists(LFeatureProcessFfiPath),
    'Wave 5 must not introduce a feature-specific platform.process.ffi owner: ' + LFeatureProcessFfiPath);

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

  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'platform_environment_get',
    'platform.time/sync/thread must not consume Wave 5 environment raw ABI');
  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'windows_get_environment_variable',
    'platform.time/sync/thread must not consume Wave 5 Windows environment raw ABI');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_abi_wave5_env');
  T.Run('platform host ABI wave 5 POSIX environment source tokens are owned', @TestHostAbiWave5PosixEnvironmentSourceTokens);
  T.Run('platform host ABI wave 5 Windows environment source tokens are owned', @TestHostAbiWave5WindowsEnvironmentSourceTokens);
  T.Run('platform host ABI wave 5 environment evidence is documented', @TestHostAbiWave5EnvironmentEvidenceDocumented);
  T.Run('platform host ABI wave 5 environment route truth stays indexed', @TestHostAbiWave5EnvironmentRouteTruth);
  T.Run('platform host ABI wave 5 keeps feature-specific environment ffi absent', @TestFeatureSpecificEnvironmentFfiStillAbsent);
  T.Summary;
end.
