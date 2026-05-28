program test_platform_host_abi_wave3_stat;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.linux.base,
  nextpas.core.platform.windows.base;

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

procedure CheckWave3DocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host abi completeness wave 3',
    'docs must name Platform Host ABI Completeness Wave 3');
  CheckTokenPresent(ADoc, 'file status abi raw inventory',
    'docs must identify the file status ABI raw inventory scope');
  CheckTokenPresent(ADoc, 'statx',
    'docs must include Linux statx evidence');
  CheckTokenPresent(ADoc, '__xstat',
    'docs must include Linux __xstat evidence');
  CheckTokenPresent(ADoc, '$inode64',
    'docs must include Darwin INODE64 stat evidence');
  CheckTokenPresent(ADoc, 'getfileattributesexa',
    'docs must include Windows GetFileAttributesExA evidence');
  CheckTokenPresent(ADoc, 'getfileinformationbyhandle',
    'docs must include Windows GetFileInformationByHandle evidence');
  CheckTokenPresent(ADoc, 'posix stat record remains deferred',
    'docs must keep unsafe shared POSIX stat record import deferred');
end;

procedure TestHostAbiWave3StatRecordLayouts;
begin
  CheckEqual(Int64(16), Int64(SizeOf(TPlatformLinuxStatxTimestamp)),
    'Linux statx timestamp must match FPC/kernel ABI size');
  CheckEqual(Int64(256), Int64(SizeOf(TPlatformLinuxStatx)),
    'Linux statx record must match FPC/kernel ABI size');
  CheckEqual(Int64(4), Int64(SizeOf(GET_FILEEX_INFO_LEVELS)),
    'GET_FILEEX_INFO_LEVELS must be ABI-sized as a 32-bit Windows enum');
  CheckEqual(Int64(36), Int64(SizeOf(WIN32_FILE_ATTRIBUTE_DATA)),
    'WIN32_FILE_ATTRIBUTE_DATA must match FPC/kernel32 ABI size');
  CheckEqual(Int64(52), Int64(SizeOf(BY_HANDLE_FILE_INFORMATION)),
    'BY_HANDLE_FILE_INFORMATION must match FPC/kernel32 ABI size');
end;

procedure TestHostAbiWave3StatSourceTokens;
var
  LPosixBase: string;
  LPosixFfi: string;
  LLinuxBase: string;
  LLinuxFfi: string;
  LWindowsBase: string;
  LWindowsFfi: string;
begin
  LPosixBase := ReadSourceFile(ResolveRequiredPath(POSIX_BASE_PATH_FROM_TEST, POSIX_BASE_PATH_FROM_ROOT, 'posix base must exist'));
  LPosixFfi := ReadSourceFile(ResolveRequiredPath(POSIX_FFI_PATH_FROM_TEST, POSIX_FFI_PATH_FROM_ROOT, 'posix ffi must exist'));
  LLinuxBase := ReadSourceFile(ResolveRequiredPath(LINUX_BASE_PATH_FROM_TEST, LINUX_BASE_PATH_FROM_ROOT, 'linux base must exist'));
  LLinuxFfi := ReadSourceFile(ResolveRequiredPath(LINUX_FFI_PATH_FROM_TEST, LINUX_FFI_PATH_FROM_ROOT, 'linux ffi must exist'));
  LWindowsBase := ReadSourceFile(ResolveRequiredPath(WINDOWS_BASE_PATH_FROM_TEST, WINDOWS_BASE_PATH_FROM_ROOT, 'windows base must exist'));
  LWindowsFfi := ReadSourceFile(ResolveRequiredPath(WINDOWS_FFI_PATH_FROM_TEST, WINDOWS_FFI_PATH_FROM_ROOT, 'windows ffi must exist'));

  CheckTokenAbsent(LPosixBase, 'tplatformstat',
    'posix.base must not own a shared POSIX stat record before host layouts are proven');
  CheckTokenAbsent(LPosixFfi, 'function stat(',
    'posix.ffi must not expose unsafe shared stat binding');
  CheckTokenAbsent(LPosixFfi, 'function lstat(',
    'posix.ffi must not expose unsafe shared lstat binding');
  CheckTokenAbsent(LPosixFfi, 'function fstat(',
    'posix.ffi must not expose unsafe shared fstat binding');

  CheckTokenPresent(LLinuxBase, 'tplatformlinuxstatxtimestamp',
    'linux.base must own Linux statx timestamp record');
  CheckTokenPresent(LLinuxBase, 'tplatformlinuxstatx',
    'linux.base must own Linux statx record');
  CheckTokenPresent(LLinuxBase, 'platform_linux_statx_basic_stats',
    'linux.base must own STATX_BASIC_STATS');
  CheckTokenPresent(LLinuxBase, 'platform_linux_at_fdcwd',
    'linux.base must own AT_FDCWD');
  CheckTokenPresent(LLinuxBase, 'platform_linux_at_symlink_nofollow',
    'linux.base must own AT_SYMLINK_NOFOLLOW');
  CheckTokenPresent(LLinuxBase, 'platform_linux_at_empty_path',
    'linux.base must own AT_EMPTY_PATH');
  CheckTokenPresent(LLinuxBase, 'linux_syscall_statx',
    'linux.base must own Linux statx syscall number token');
  CheckTokenPresent(LLinuxFfi, 'function syscall',
    'linux.ffi must own raw syscall binding for statx');
  CheckTokenAbsent(LLinuxFfi, 'function linux_syscall',
    'linux.ffi raw syscall declaration must not repeat the host prefix');
  CheckTokenAbsent(LLinuxFfi, 'function linux_statx',
    'linux.ffi must not expose Linux statx syscall helper');
  CheckTokenAbsent(LLinuxFfi, 'function linux_statx_path_basic',
    'linux.ffi must not expose Linux path statx helper');
  CheckTokenAbsent(LLinuxFfi, 'function linux_statx_fd_basic',
    'linux.ffi must not expose Linux fd statx helper');

  CheckTokenPresent(LWindowsBase, 'get_fileex_info_levels',
    'windows.base must own GET_FILEEX_INFO_LEVELS');
  CheckTokenPresent(LWindowsBase, 'getfileexinfostandard',
    'windows.base must own GetFileExInfoStandard');
  CheckTokenPresent(LWindowsBase, 'win32_file_attribute_data',
    'windows.base must own WIN32_FILE_ATTRIBUTE_DATA');
  CheckTokenPresent(LWindowsBase, 'by_handle_file_information',
    'windows.base must own BY_HANDLE_FILE_INFORMATION');
  CheckTokenPresent(LWindowsBase, 'platform_windows_file_attribute_directory',
    'windows.base must own FILE_ATTRIBUTE_DIRECTORY');
  CheckTokenPresent(LWindowsBase, 'platform_windows_file_attribute_reparse_point',
    'windows.base must own FILE_ATTRIBUTE_REPARSE_POINT');
  CheckTokenPresent(LWindowsFfi, 'function getfileattributesexa',
    'windows.ffi must own GetFileAttributesExA binding');
  CheckTokenPresent(LWindowsFfi, 'function getfileattributesexw',
    'windows.ffi must own GetFileAttributesExW binding');
  CheckTokenPresent(LWindowsFfi, 'function getfileinformationbyhandle',
    'windows.ffi must own GetFileInformationByHandle binding');
  CheckTokenAbsent(LWindowsFfi, 'function windows_get_file_attributes_ex_a',
    'windows.ffi must not expose ANSI file attribute helper');
  CheckTokenAbsent(LWindowsFfi, 'function windows_get_file_attributes_ex_w',
    'windows.ffi must not expose wide file attribute helper');
  CheckTokenAbsent(LWindowsFfi, 'function windows_get_file_information_by_handle',
    'windows.ffi must not expose handle information helper');
end;

procedure TestHostAbiWave3StatEvidenceDocumented;
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

  CheckWave3DocumentTokens(LSourceEvidence);
  CheckWave3DocumentTokens(LGapMatrix);
end;

procedure TestHostAbiWave3StatRouteTruth;
var
  LVerify: string;
begin
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LVerify, 'require_path core/tests/nextpas.core.platform/test_platform_host_abi_wave3_stat/test_platform_host_abi_wave3_stat.lpr',
    'verify_local must require the Wave 3 file status ABI source-surface test');
  CheckTokenPresent(LVerify, 'core-platform-host-abi-wave3-stat-check=running',
    'verify_local must run the Wave 3 file status ABI focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_abi_wave3_stat: 5 total, 5 passed, 0 failed',
    'verify_local must assert the Wave 3 file status ABI summary');
  CheckTokenPresent(LVerify, 'coreplatformhostabiwave3statcheck',
    'verify_local final envelope must include the Wave 3 file status ABI token');
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
    'Wave 3 must not introduce a feature-specific platform.file.ffi owner: ' + LFeatureFileFfiPath);

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

  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'linux_statx',
    'platform.time/sync/thread must not consume Wave 3 Linux statx raw ABI');
  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'getfileattributesex',
    'platform.time/sync/thread must not consume Wave 3 Windows file-attribute raw ABI');
  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'getfileinformationbyhandle',
    'platform.time/sync/thread must not consume Wave 3 Windows handle-info raw ABI');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_abi_wave3_stat');
  T.Run('platform host ABI wave 3 file status source tokens are owned', @TestHostAbiWave3StatSourceTokens);
  T.Run('platform host ABI wave 3 file status records match ABI sizes', @TestHostAbiWave3StatRecordLayouts);
  T.Run('platform host ABI wave 3 file status evidence is documented', @TestHostAbiWave3StatEvidenceDocumented);
  T.Run('platform host ABI wave 3 file status route truth stays indexed', @TestHostAbiWave3StatRouteTruth);
  T.Run('platform host ABI wave 3 keeps feature-specific file ffi absent', @TestFeatureSpecificFileFfiStillAbsent);
  T.Summary;
end.
