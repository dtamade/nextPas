program test_platform_host_abi_wave4_paths;

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

procedure CheckPosixPathOwnerTokens(
  const ABase,
  AFfi,
  AHostName: string);
begin
  CheckTokenPresent(ABase, 'platform_access_exists = int32(0)',
    AHostName + ' base must own F_OK');
  CheckTokenPresent(ABase, 'platform_access_execute = int32(1)',
    AHostName + ' base must own X_OK');
  CheckTokenPresent(ABase, 'platform_access_write = int32(2)',
    AHostName + ' base must own W_OK');
  CheckTokenPresent(ABase, 'platform_access_read = int32(4)',
    AHostName + ' base must own R_OK');

  CheckTokenAbsent(AFfi, 'function platform_directory_create',
    AHostName + ' ffi must not expose directory create helper');
  CheckTokenAbsent(AFfi, 'function platform_directory_remove',
    AHostName + ' ffi must not expose directory remove helper');
  CheckTokenAbsent(AFfi, 'function platform_path_unlink',
    AHostName + ' ffi must not expose path unlink helper');
  CheckTokenAbsent(AFfi, 'function platform_path_rename',
    AHostName + ' ffi must not expose path rename helper');
  CheckTokenAbsent(AFfi, 'function platform_path_access',
    AHostName + ' ffi must not expose path access helper');
  CheckTokenAbsent(AFfi, 'function platform_path_get_current_directory',
    AHostName + ' ffi must not expose get-current-directory helper');
  CheckTokenAbsent(AFfi, 'function platform_path_set_current_directory',
    AHostName + ' ffi must not expose set-current-directory helper');
end;

procedure CheckWave4DocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host abi completeness wave 4',
    'docs must name Platform Host ABI Completeness Wave 4');
  CheckTokenPresent(ADoc, 'directory/path abi raw inventory',
    'docs must identify the directory/path ABI raw inventory scope');
  CheckTokenPresent(ADoc, 'mkdir',
    'docs must include POSIX mkdir evidence');
  CheckTokenPresent(ADoc, 'getcwd',
    'docs must include POSIX getcwd evidence');
  CheckTokenPresent(ADoc, 'f_ok',
    'docs must include POSIX F_OK evidence');
  CheckTokenPresent(ADoc, 'createdirectorya',
    'docs must include Windows CreateDirectoryA evidence');
  CheckTokenPresent(ADoc, 'deletefilew',
    'docs must include Windows DeleteFileW evidence');
  CheckTokenPresent(ADoc, 'getfullpathnamew',
    'docs must include Windows GetFullPathNameW evidence');
  CheckTokenPresent(ADoc, 'no public platform.file contract',
    'docs must keep Wave 4 outside a public platform.file contract');
end;

procedure TestHostAbiWave4PosixPathSourceTokens;
var
  LPosixFfi: string;
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
begin
  LPosixFfi := ReadSourceFile(ResolveRequiredPath(POSIX_FFI_PATH_FROM_TEST, POSIX_FFI_PATH_FROM_ROOT, 'posix ffi must exist'));
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

  CheckTokenPresent(LPosixFfi, 'function mkdir',
    'posix.ffi must own POSIX mkdir binding');
  CheckTokenPresent(LPosixFfi, 'function rmdir',
    'posix.ffi must own POSIX rmdir binding');
  CheckTokenPresent(LPosixFfi, 'function unlink',
    'posix.ffi must own POSIX unlink binding');
  CheckTokenPresent(LPosixFfi, 'function rename',
    'posix.ffi must own POSIX rename binding');
  CheckTokenPresent(LPosixFfi, 'function access',
    'posix.ffi must own POSIX access binding');
  CheckTokenPresent(LPosixFfi, 'function getcwd',
    'posix.ffi must own POSIX getcwd binding');
  CheckTokenPresent(LPosixFfi, 'function chdir',
    'posix.ffi must own POSIX chdir binding');
  CheckTokenAbsent(LPosixFfi, 'function platform_posix_directory_create',
    'posix.ffi must not expose shared directory create helper');
  CheckTokenAbsent(LPosixFfi, 'function platform_posix_path_get_current_directory',
    'posix.ffi must not expose shared get-current-directory helper');

  CheckPosixPathOwnerTokens(LLinuxBase, LLinuxFfi, 'Linux');
  CheckPosixPathOwnerTokens(LAndroidBase, LAndroidFfi, 'Android');
  CheckPosixPathOwnerTokens(LDarwinBase, LDarwinFfi, 'Darwin');
  CheckPosixPathOwnerTokens(LFreeBSDBase, LFreeBSDFfi, 'FreeBSD');
  CheckPosixPathOwnerTokens(LUnixBase, LUnixFfi, 'generic Unix');
end;

procedure TestHostAbiWave4WindowsPathSourceTokens;
var
  LWindowsBase: string;
  LWindowsFfi: string;
begin
  LWindowsBase := ReadSourceFile(ResolveRequiredPath(WINDOWS_BASE_PATH_FROM_TEST, WINDOWS_BASE_PATH_FROM_ROOT, 'windows base must exist'));
  LWindowsFfi := ReadSourceFile(ResolveRequiredPath(WINDOWS_FFI_PATH_FROM_TEST, WINDOWS_FFI_PATH_FROM_ROOT, 'windows ffi must exist'));

  CheckTokenPresent(LWindowsBase, 'lpstr = pansichar',
    'windows.base must own LPSTR alias');
  CheckTokenPresent(LWindowsBase, 'lpwstr = pwidechar',
    'windows.base must own LPWSTR alias');
  CheckTokenPresent(LWindowsBase, 'plpstr = ^lpstr',
    'windows.base must own PLPSTR alias');
  CheckTokenPresent(LWindowsBase, 'plpwstr = ^lpwstr',
    'windows.base must own PLPWSTR alias');

  CheckTokenPresent(LWindowsFfi, 'function createdirectorya',
    'windows.ffi must own CreateDirectoryA binding');
  CheckTokenPresent(LWindowsFfi, 'function createdirectoryw',
    'windows.ffi must own CreateDirectoryW binding');
  CheckTokenPresent(LWindowsFfi, 'function removedirectorya',
    'windows.ffi must own RemoveDirectoryA binding');
  CheckTokenPresent(LWindowsFfi, 'function removedirectoryw',
    'windows.ffi must own RemoveDirectoryW binding');
  CheckTokenPresent(LWindowsFfi, 'function deletefilea',
    'windows.ffi must own DeleteFileA binding');
  CheckTokenPresent(LWindowsFfi, 'function deletefilew',
    'windows.ffi must own DeleteFileW binding');
  CheckTokenPresent(LWindowsFfi, 'function movefilea',
    'windows.ffi must own MoveFileA binding');
  CheckTokenPresent(LWindowsFfi, 'function movefilew',
    'windows.ffi must own MoveFileW binding');
  CheckTokenPresent(LWindowsFfi, 'function getcurrentdirectorya',
    'windows.ffi must own GetCurrentDirectoryA binding');
  CheckTokenPresent(LWindowsFfi, 'function getcurrentdirectoryw',
    'windows.ffi must own GetCurrentDirectoryW binding');
  CheckTokenPresent(LWindowsFfi, 'function setcurrentdirectorya',
    'windows.ffi must own SetCurrentDirectoryA binding');
  CheckTokenPresent(LWindowsFfi, 'function setcurrentdirectoryw',
    'windows.ffi must own SetCurrentDirectoryW binding');
  CheckTokenPresent(LWindowsFfi, 'function getfullpathnamea',
    'windows.ffi must own GetFullPathNameA binding');
  CheckTokenPresent(LWindowsFfi, 'function getfullpathnamew',
    'windows.ffi must own GetFullPathNameW binding');
  CheckTokenAbsent(LWindowsFfi, 'function windows_create_directory_a',
    'windows.ffi must not expose ANSI CreateDirectory helper');
  CheckTokenAbsent(LWindowsFfi, 'function windows_get_full_path_name_w',
    'windows.ffi must not expose wide GetFullPathName helper');
end;

procedure TestHostAbiWave4PathEvidenceDocumented;
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

  CheckWave4DocumentTokens(LSourceEvidence);
  CheckWave4DocumentTokens(LGapMatrix);
end;

procedure TestHostAbiWave4PathRouteTruth;
var
  LVerify: string;
begin
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LVerify, 'require_path core/tests/nextpas.core.platform/test_platform_host_abi_wave4_paths/test_platform_host_abi_wave4_paths.lpr',
    'verify_local must require the Wave 4 directory/path ABI source-surface test');
  CheckTokenPresent(LVerify, 'core-platform-host-abi-wave4-paths-check=running',
    'verify_local must run the Wave 4 directory/path ABI focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_abi_wave4_paths: 5 total, 5 passed, 0 failed',
    'verify_local must assert the Wave 4 directory/path ABI summary');
  CheckTokenPresent(LVerify, 'coreplatformhostabiwave4pathscheck',
    'verify_local final envelope must include the Wave 4 directory/path ABI token');
end;

procedure TestFeatureSpecificFileFfiStillAbsent;
var
  LFeatureFileFfiPath: string;
  LPlatformTime: string;
  LPlatformSync: string;
  LPlatformThread: string;
begin
  LFeatureFileFfiPath := ResolvePath(PLATFORM_FILE_FFI_PATH_FROM_TEST, PLATFORM_FILE_FFI_PATH_FROM_ROOT);
  Check(not FileExists(LFeatureFileFfiPath),
    'Wave 4 must not introduce a feature-specific platform.file.ffi owner: ' + LFeatureFileFfiPath);

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

  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'platform_path_get_current_directory',
    'platform.time/sync/thread must not consume Wave 4 path raw ABI');
  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'windows_create_directory',
    'platform.time/sync/thread must not consume Wave 4 Windows directory raw ABI');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_abi_wave4_paths');
  T.Run('platform host ABI wave 4 POSIX path source tokens are owned', @TestHostAbiWave4PosixPathSourceTokens);
  T.Run('platform host ABI wave 4 Windows path source tokens are owned', @TestHostAbiWave4WindowsPathSourceTokens);
  T.Run('platform host ABI wave 4 path evidence is documented', @TestHostAbiWave4PathEvidenceDocumented);
  T.Run('platform host ABI wave 4 path route truth stays indexed', @TestHostAbiWave4PathRouteTruth);
  T.Run('platform host ABI wave 4 keeps feature-specific file ffi absent', @TestFeatureSpecificFileFfiStillAbsent);
  T.Summary;
end.
