program test_platform_host_abi_wave9_linux_stat;

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
  POSIX_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.posix.ffi.pas';
  POSIX_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.posix.ffi.pas';
  LINUX_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.base.pas';
  LINUX_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.base.pas';
  LINUX_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.linux.ffi.pas';
  LINUX_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.linux.ffi.pas';
  PLATFORM_FILE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.file.pas';
  PLATFORM_FILE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.file.pas';
  PLATFORM_FILE_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.file.ffi.pas';
  PLATFORM_FILE_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.file.ffi.pas';
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

procedure CheckWave9DocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host abi completeness wave 9',
    'docs must name Platform Host ABI Completeness Wave 9');
  CheckTokenPresent(ADoc, 'linux traditional stat',
    'docs must identify Linux traditional stat scope');
  CheckTokenPresent(ADoc, 'rtl/linux/ostypes.inc',
    'docs must include Linux _STAT_VER evidence');
  CheckTokenPresent(ADoc, 'rtl/linux/x86_64/stat.inc',
    'docs must include Linux x86_64 stat record evidence');
  CheckTokenPresent(ADoc, 'rtl/linux/aarch64/stat.inc',
    'docs must include Linux aarch64 stat record evidence');
  CheckTokenPresent(ADoc, 'rtl/linux/osmacro.inc',
    'docs must include Linux osmacro stat wrapper evidence');
  CheckTokenPresent(ADoc, '__xstat',
    'docs must include __xstat evidence');
  CheckTokenPresent(ADoc, '__lxstat',
    'docs must include __lxstat evidence');
  CheckTokenPresent(ADoc, '__fxstat',
    'docs must include __fxstat evidence');
end;

procedure TestHostAbiWave9LinuxStatSourceTokens;
var
  LLinuxBase: string;
  LLinuxFfi: string;
begin
  LLinuxBase := ReadSourceFile(ResolveRequiredPath(
    LINUX_BASE_PATH_FROM_TEST,
    LINUX_BASE_PATH_FROM_ROOT,
    'linux base must exist'));
  LLinuxFfi := ReadSourceFile(ResolveRequiredPath(
    LINUX_FFI_PATH_FROM_TEST,
    LINUX_FFI_PATH_FROM_ROOT,
    'linux ffi must exist'));

  CheckTokenPresent(LLinuxBase, 'tplatformlinuxstat = record',
    'linux.base must own the Linux traditional stat record');
  CheckTokenPresent(LLinuxBase, 'pplatformlinuxstat = ^tplatformlinuxstat',
    'linux.base must own the Linux traditional stat pointer');
  CheckTokenPresent(LLinuxBase, 'platform_linux_stat_version',
    'linux.base must own the FPC _STAT_VER projection');
  CheckTokenPresent(LLinuxBase, 'st_atime_nsec',
    'linux.base must preserve Linux stat nanosecond fields');
  CheckTokenPresent(LLinuxBase, 'st_mtime_nsec',
    'linux.base must preserve Linux stat mtime nanosecond field');
  CheckTokenPresent(LLinuxBase, 'st_ctime_nsec',
    'linux.base must preserve Linux stat ctime nanosecond field');

  CheckTokenPresent(LLinuxFfi, 'function __xstat',
    'linux.ffi must own __xstat binding');
  CheckTokenPresent(LLinuxFfi, 'function __lxstat',
    'linux.ffi must own __lxstat binding');
  CheckTokenPresent(LLinuxFfi, 'function __fxstat',
    'linux.ffi must own __fxstat binding');
  CheckTokenAbsent(LLinuxFfi, 'function linux_xstat',
    'linux.ffi __xstat declaration must not repeat the host prefix');
  CheckTokenAbsent(LLinuxFfi, 'function linux_lxstat',
    'linux.ffi __lxstat declaration must not repeat the host prefix');
  CheckTokenAbsent(LLinuxFfi, 'function linux_fxstat',
    'linux.ffi __fxstat declaration must not repeat the host prefix');
  CheckTokenAbsent(LLinuxFfi, 'function linux_stat_path',
    'linux.ffi must not expose Linux stat path helper');
  CheckTokenAbsent(LLinuxFfi, 'function linux_lstat_path',
    'linux.ffi must not expose Linux lstat path helper');
  CheckTokenAbsent(LLinuxFfi, 'function linux_fstat_fd',
    'linux.ffi must not expose Linux fstat fd helper');
end;

procedure TestSharedPosixStatStillDeferred;
var
  LPosixBase: string;
  LPosixFfi: string;
begin
  LPosixBase := ReadSourceFile(ResolveRequiredPath(
    POSIX_BASE_PATH_FROM_TEST,
    POSIX_BASE_PATH_FROM_ROOT,
    'posix base must exist'));
  LPosixFfi := ReadSourceFile(ResolveRequiredPath(
    POSIX_FFI_PATH_FROM_TEST,
    POSIX_FFI_PATH_FROM_ROOT,
    'posix ffi must exist'));

  CheckTokenAbsent(LPosixBase, 'tplatformstat',
    'posix.base must not own a shared POSIX stat record');
  CheckTokenAbsent(LPosixFfi, 'function stat(',
    'posix.ffi must not expose a shared stat binding');
  CheckTokenAbsent(LPosixFfi, 'function lstat(',
    'posix.ffi must not expose a shared lstat binding');
  CheckTokenAbsent(LPosixFfi, 'function fstat(',
    'posix.ffi must not expose a shared fstat binding');
end;

procedure TestHostAbiWave9LinuxStatEvidenceDocumented;
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

  CheckWave9DocumentTokens(LSourceEvidence);
  CheckWave9DocumentTokens(LGapMatrix);
end;

procedure TestHostAbiWave9LinuxStatRouteTruth;
var
  LVerify: string;
begin
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LVerify, 'require_path core/tests/nextpas.core.platform/test_platform_host_abi_wave9_linux_stat/test_platform_host_abi_wave9_linux_stat.lpr',
    'verify_local must require the Wave 9 Linux stat source-surface test');
  CheckTokenPresent(LVerify, 'core-platform-host-abi-wave9-linux-stat-check=running',
    'verify_local must run the Wave 9 Linux stat focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_abi_wave9_linux_stat: 5 total, 5 passed, 0 failed',
    'verify_local must assert the Wave 9 Linux stat pass summary');
  CheckTokenPresent(LVerify, 'coreplatformhostabiwave9linuxstatcheck',
    'verify_local final envelope must include the Wave 9 Linux stat token');
end;

procedure TestFeatureSpecificFileFfiStillAbsent;
var
  LFeatureFilePath: string;
  LFeatureFileFfiPath: string;
  LPlatformTime: string;
  LPlatformSync: string;
  LPlatformThread: string;
begin
  LFeatureFilePath := ResolvePath(PLATFORM_FILE_PATH_FROM_TEST, PLATFORM_FILE_PATH_FROM_ROOT);
  LFeatureFileFfiPath := ResolvePath(PLATFORM_FILE_FFI_PATH_FROM_TEST, PLATFORM_FILE_FFI_PATH_FROM_ROOT);
  Check(not FileExists(LFeatureFilePath),
    'Wave 9 must not introduce a public platform.file contract: ' + LFeatureFilePath);
  Check(not FileExists(LFeatureFileFfiPath),
    'Wave 9 must not introduce a feature-specific platform.file.ffi owner: ' + LFeatureFileFfiPath);

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

  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'linux_xstat',
    'platform.time/sync/thread must not consume Wave 9 Linux stat raw ABI');
  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'linux_lxstat',
    'platform.time/sync/thread must not consume Wave 9 Linux lstat raw ABI');
  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'linux_fxstat',
    'platform.time/sync/thread must not consume Wave 9 Linux fstat raw ABI');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_abi_wave9_linux_stat');
  T.Run('platform host ABI wave 9 Linux stat source tokens are owned', @TestHostAbiWave9LinuxStatSourceTokens);
  T.Run('platform host ABI wave 9 keeps shared POSIX stat deferred', @TestSharedPosixStatStillDeferred);
  T.Run('platform host ABI wave 9 Linux stat evidence is documented', @TestHostAbiWave9LinuxStatEvidenceDocumented);
  T.Run('platform host ABI wave 9 Linux stat route truth stays indexed', @TestHostAbiWave9LinuxStatRouteTruth);
  T.Run('platform host ABI wave 9 keeps feature-specific file ffi absent', @TestFeatureSpecificFileFfiStillAbsent);
  T.Summary;
end.
