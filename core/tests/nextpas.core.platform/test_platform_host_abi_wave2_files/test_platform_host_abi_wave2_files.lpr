program test_platform_host_abi_wave2_files;

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

procedure CheckPosixFileOwnerTokens(
  const ABase,
  AFfi,
  AHostName,
  ACreate,
  AExclusive,
  ATruncate,
  AAppend: string);
begin
  CheckTokenPresent(ABase, 'platform_open_read_only = int32(0)',
    AHostName + ' base must own O_RDONLY');
  CheckTokenPresent(ABase, 'platform_open_write_only = int32(1)',
    AHostName + ' base must own O_WRONLY');
  CheckTokenPresent(ABase, 'platform_open_read_write = int32(2)',
    AHostName + ' base must own O_RDWR');
  CheckTokenPresent(ABase, 'platform_open_create = int32(' + ACreate + ')',
    AHostName + ' base must own O_CREAT');
  CheckTokenPresent(ABase, 'platform_open_exclusive = int32(' + AExclusive + ')',
    AHostName + ' base must own O_EXCL');
  CheckTokenPresent(ABase, 'platform_open_truncate = int32(' + ATruncate + ')',
    AHostName + ' base must own O_TRUNC');
  CheckTokenPresent(ABase, 'platform_open_append = int32(' + AAppend + ')',
    AHostName + ' base must own O_APPEND');
  CheckTokenPresent(ABase, 'platform_fcntl_dup_fd = int32(0)',
    AHostName + ' base must own F_DUPFD');
  CheckTokenPresent(ABase, 'platform_fcntl_get_fd = int32(1)',
    AHostName + ' base must own F_GETFD');
  CheckTokenPresent(ABase, 'platform_fcntl_set_fd = int32(2)',
    AHostName + ' base must own F_SETFD');
  CheckTokenPresent(ABase, 'platform_fcntl_get_flags = int32(3)',
    AHostName + ' base must own F_GETFL');
  CheckTokenPresent(ABase, 'platform_fcntl_set_flags = int32(4)',
    AHostName + ' base must own F_SETFL');
  CheckTokenPresent(ABase, 'platform_fcntl_fd_cloexec = int32(1)',
    AHostName + ' base must own FD_CLOEXEC');

  CheckTokenPresent(AFfi, 'function platform_file_open',
    AHostName + ' ffi must expose platform_file_open helper');
  CheckTokenPresent(AFfi, 'function platform_file_close',
    AHostName + ' ffi must expose platform_file_close helper');
  CheckTokenPresent(AFfi, 'function platform_file_fcntl',
    AHostName + ' ffi must expose platform_file_fcntl helper');
  CheckTokenPresent(AFfi, 'function platform_file_fcntl_i32',
    AHostName + ' ffi must expose platform_file_fcntl_i32 helper');
end;

procedure CheckWave2DocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host abi completeness wave 2',
    'docs must name Platform Host ABI Completeness Wave 2');
  CheckTokenPresent(ADoc, 'file abi raw inventory',
    'docs must identify the file ABI raw inventory scope');
  CheckTokenPresent(ADoc, 'open',
    'docs must include open evidence');
  CheckTokenPresent(ADoc, 'close',
    'docs must include close evidence');
  CheckTokenPresent(ADoc, 'fcntl',
    'docs must include fcntl evidence');
  CheckTokenPresent(ADoc, 'createfilea',
    'docs must include Windows CreateFileA evidence');
  CheckTokenPresent(ADoc, 'readfile',
    'docs must include Windows ReadFile evidence');
  CheckTokenPresent(ADoc, 'writefile',
    'docs must include Windows WriteFile evidence');
  CheckTokenPresent(ADoc, 'stat remains deferred',
    'docs must keep stat deferred in Wave 2');
end;

procedure TestHostAbiWave2FileSourceTokens;
var
  LPosixBase: string;
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
  LWindowsBase: string;
  LWindowsFfi: string;
begin
  LPosixBase := ReadSourceFile(ResolveRequiredPath(POSIX_BASE_PATH_FROM_TEST, POSIX_BASE_PATH_FROM_ROOT, 'posix base must exist'));
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
  LWindowsBase := ReadSourceFile(ResolveRequiredPath(WINDOWS_BASE_PATH_FROM_TEST, WINDOWS_BASE_PATH_FROM_ROOT, 'windows base must exist'));
  LWindowsFfi := ReadSourceFile(ResolveRequiredPath(WINDOWS_FFI_PATH_FROM_TEST, WINDOWS_FFI_PATH_FROM_ROOT, 'windows ffi must exist'));

  CheckTokenPresent(LPosixBase, 'tplatformfiledescriptor = int32',
    'posix.base must own shared POSIX file descriptor scalar');
  CheckTokenPresent(LPosixBase, 'platform_file_mode_default',
    'posix.base must own a default file create mode token');
  CheckTokenPresent(LPosixFfi, 'function platform_posix_open',
    'posix.ffi must expose shared POSIX open helper');
  CheckTokenPresent(LPosixFfi, 'function platform_posix_close',
    'posix.ffi must expose shared POSIX close helper');
  CheckTokenPresent(LPosixFfi, 'function platform_posix_fcntl',
    'posix.ffi must expose shared POSIX fcntl helper');
  CheckTokenPresent(LPosixFfi, 'function platform_posix_fcntl_i32',
    'posix.ffi must expose shared POSIX fcntl helper with integer argument');
  CheckTokenPresent(LPosixFfi, 'function open',
    'posix.ffi must own open binding');
  CheckTokenPresent(LPosixFfi, 'function close',
    'posix.ffi must own close binding');
  CheckTokenPresent(LPosixFfi, 'function fcntl',
    'posix.ffi must own fcntl binding');

  CheckPosixFileOwnerTokens(LLinuxBase, LLinuxFfi, 'Linux', '$40', '$80', '$200', '$400');
  CheckTokenPresent(LLinuxBase, 'platform_open_close_on_exec = int32($80000)',
    'Linux base must own O_CLOEXEC');
  CheckPosixFileOwnerTokens(LAndroidBase, LAndroidFfi, 'Android', '$40', '$80', '$200', '$400');
  CheckTokenPresent(LAndroidBase, 'platform_open_close_on_exec = int32($80000)',
    'Android base must own O_CLOEXEC');
  CheckPosixFileOwnerTokens(LDarwinBase, LDarwinFfi, 'Darwin', '$100', '$400', '$200', '$8');
  CheckPosixFileOwnerTokens(LFreeBSDBase, LFreeBSDFfi, 'FreeBSD', '$200', '$800', '$400', '$8');
  CheckPosixFileOwnerTokens(LUnixBase, LUnixFfi, 'generic Unix', '$100', '$400', '$200', '$8');

  CheckTokenPresent(LWindowsBase, 'platform_windows_generic_read',
    'Windows base must own GENERIC_READ');
  CheckTokenPresent(LWindowsBase, 'platform_windows_file_share_read',
    'Windows base must own FILE_SHARE_READ');
  CheckTokenPresent(LWindowsBase, 'platform_windows_create_always',
    'Windows base must own CREATE_ALWAYS');
  CheckTokenPresent(LWindowsBase, 'platform_windows_open_existing',
    'Windows base must own OPEN_EXISTING');
  CheckTokenPresent(LWindowsBase, 'platform_windows_file_attribute_normal',
    'Windows base must own FILE_ATTRIBUTE_NORMAL');
  CheckTokenPresent(LWindowsFfi, 'function createfilea',
    'Windows ffi must own CreateFileA binding');
  CheckTokenPresent(LWindowsFfi, 'function createfilew',
    'Windows ffi must own CreateFileW binding');
  CheckTokenPresent(LWindowsFfi, 'function readfile',
    'Windows ffi must own ReadFile binding');
  CheckTokenPresent(LWindowsFfi, 'function writefile',
    'Windows ffi must own WriteFile binding');
  CheckTokenPresent(LWindowsFfi, 'function windows_create_file_a',
    'Windows ffi must expose ANSI CreateFile helper');
  CheckTokenPresent(LWindowsFfi, 'function windows_create_file_w',
    'Windows ffi must expose wide CreateFile helper');
  CheckTokenPresent(LWindowsFfi, 'function windows_read_file',
    'Windows ffi must expose read helper');
  CheckTokenPresent(LWindowsFfi, 'function windows_write_file',
    'Windows ffi must expose write helper');
  CheckTokenPresent(LWindowsFfi, 'function windows_file_close_handle',
    'Windows ffi must expose file close helper using existing CloseHandle owner');
end;

procedure TestHostAbiWave2FileEvidenceDocumented;
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

  CheckWave2DocumentTokens(LSourceEvidence);
  CheckWave2DocumentTokens(LGapMatrix);
end;

procedure TestHostAbiWave2FileRouteTruth;
var
  LVerify: string;
begin
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LVerify, 'require_path core/tests/nextpas.core.platform/test_platform_host_abi_wave2_files/test_platform_host_abi_wave2_files.lpr',
    'verify_local must require the Wave 2 file ABI source-surface test');
  CheckTokenPresent(LVerify, 'core-platform-host-abi-wave2-files-check=running',
    'verify_local must run the Wave 2 file ABI focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_abi_wave2_files: 4 total, 4 passed, 0 failed',
    'verify_local must assert the Wave 2 file ABI summary');
  CheckTokenPresent(LVerify, 'coreplatformhostabiwave2filescheck',
    'verify_local final envelope must include the Wave 2 file ABI token');
end;

procedure TestFeatureSpecificFileFfiStillAbsent;
var
  LPosixFfi: string;
  LLinuxFfi: string;
  LWindowsFfi: string;
begin
  LPosixFfi := ReadSourceFile(ResolveRequiredPath(POSIX_FFI_PATH_FROM_TEST, POSIX_FFI_PATH_FROM_ROOT, 'posix ffi must exist'));
  LLinuxFfi := ReadSourceFile(ResolveRequiredPath(LINUX_FFI_PATH_FROM_TEST, LINUX_FFI_PATH_FROM_ROOT, 'linux ffi must exist'));
  LWindowsFfi := ReadSourceFile(ResolveRequiredPath(WINDOWS_FFI_PATH_FROM_TEST, WINDOWS_FFI_PATH_FROM_ROOT, 'windows ffi must exist'));

  CheckTokenAbsent(LPosixFfi + LLinuxFfi + LWindowsFfi, 'nextpas.core.platform.file.ffi',
    'Wave 2 must not introduce a feature-specific platform.file.ffi owner');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_abi_wave2_files');
  T.Run('platform host ABI wave 2 file source tokens are owned', @TestHostAbiWave2FileSourceTokens);
  T.Run('platform host ABI wave 2 file evidence is documented', @TestHostAbiWave2FileEvidenceDocumented);
  T.Run('platform host ABI wave 2 file route truth stays indexed', @TestHostAbiWave2FileRouteTruth);
  T.Run('platform host ABI wave 2 keeps feature-specific file ffi absent', @TestFeatureSpecificFileFfiStillAbsent);
  T.Summary;
end.
