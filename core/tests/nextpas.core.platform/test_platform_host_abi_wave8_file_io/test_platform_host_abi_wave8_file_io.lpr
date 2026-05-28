program test_platform_host_abi_wave8_file_io;

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
  PLATFORM_FILE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.file.pas';
  PLATFORM_FILE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.file.pas';
  PLATFORM_FILE_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.file.ffi.pas';
  PLATFORM_FILE_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.file.ffi.pas';

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

procedure CheckPosixHostFileIoTokens(
  const ABase,
  AFfi,
  AHostName: string);
begin
  CheckTokenPresent(ABase, 'platform_seek_set = int32(0)',
    AHostName + ' base must own SEEK_SET');
  CheckTokenPresent(ABase, 'platform_seek_current = int32(1)',
    AHostName + ' base must own SEEK_CUR');
  CheckTokenPresent(ABase, 'platform_seek_end = int32(2)',
    AHostName + ' base must own SEEK_END');

  CheckTokenAbsent(AFfi, 'function platform_file_read',
    AHostName + ' ffi must not expose delegated read helper');
  CheckTokenAbsent(AFfi, 'function platform_file_write',
    AHostName + ' ffi must not expose delegated write helper');
  CheckTokenAbsent(AFfi, 'function platform_file_seek',
    AHostName + ' ffi must not expose delegated seek helper');
  CheckTokenAbsent(AFfi, 'function platform_file_sync',
    AHostName + ' ffi must not expose delegated fsync helper');
  CheckTokenAbsent(AFfi, 'function platform_file_truncate',
    AHostName + ' ffi must not expose delegated ftruncate helper');
end;

procedure TestHostAbiWave8PosixFileIoSourceTokens;
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

  CheckTokenPresent(LPosixBase, 'size_t = ptruint',
    'posix.base must own POSIX size_t scalar');
  CheckTokenPresent(LPosixBase, 'ssize_t = ptrint',
    'posix.base must own POSIX ssize_t scalar');
  CheckTokenPresent(LPosixBase, 'off_t = int64',
    'posix.base must own POSIX off_t scalar');
  CheckTokenPresent(LPosixBase, 'tplatformfileoffset = off_t',
    'posix.base must expose nextPas file offset alias');

  CheckTokenPresent(LPosixFfi, 'function read',
    'posix.ffi must own read binding');
  CheckTokenPresent(LPosixFfi, 'function write',
    'posix.ffi must own write binding');
  CheckTokenPresent(LPosixFfi, 'function lseek',
    'posix.ffi must own lseek binding');
  CheckTokenPresent(LPosixFfi, 'function fsync',
    'posix.ffi must own fsync binding');
  CheckTokenPresent(LPosixFfi, 'function ftruncate',
    'posix.ffi must own ftruncate binding');
  CheckTokenAbsent(LPosixFfi, 'function platform_posix_read',
    'posix.ffi must not expose shared POSIX read helper');
  CheckTokenAbsent(LPosixFfi, 'function platform_posix_write',
    'posix.ffi must not expose shared POSIX write helper');
  CheckTokenAbsent(LPosixFfi, 'function platform_posix_seek',
    'posix.ffi must not expose shared POSIX seek helper');
  CheckTokenAbsent(LPosixFfi, 'function platform_posix_sync',
    'posix.ffi must not expose shared POSIX fsync helper');
  CheckTokenAbsent(LPosixFfi, 'function platform_posix_truncate',
    'posix.ffi must not expose shared POSIX ftruncate helper');

  CheckPosixHostFileIoTokens(LLinuxBase, LLinuxFfi, 'Linux');
  CheckPosixHostFileIoTokens(LAndroidBase, LAndroidFfi, 'Android');
  CheckPosixHostFileIoTokens(LDarwinBase, LDarwinFfi, 'Darwin');
  CheckPosixHostFileIoTokens(LFreeBSDBase, LFreeBSDFfi, 'FreeBSD');
  CheckPosixHostFileIoTokens(LUnixBase, LUnixFfi, 'generic Unix');
end;

procedure TestHostAbiWave8WindowsFileIoSourceTokens;
var
  LWindowsBase: string;
  LWindowsFfi: string;
begin
  LWindowsBase := ReadSourceFile(ResolveRequiredPath(WINDOWS_BASE_PATH_FROM_TEST, WINDOWS_BASE_PATH_FROM_ROOT, 'windows base must exist'));
  LWindowsFfi := ReadSourceFile(ResolveRequiredPath(WINDOWS_FFI_PATH_FROM_TEST, WINDOWS_FFI_PATH_FROM_ROOT, 'windows ffi must exist'));

  CheckTokenPresent(LWindowsBase, 'long = int32',
    'windows.base must own FPC LONG alias');
  CheckTokenPresent(LWindowsBase, 'plong = ^long',
    'windows.base must own FPC PLONG alias');
  CheckTokenPresent(LWindowsBase, 'pint64 = ^int64',
    'windows.base must own FPC PINT64 alias');
  CheckTokenPresent(LWindowsBase, 'large_integer = record',
    'windows.base must own FPC LARGE_INTEGER layout');
  CheckTokenPresent(LWindowsBase, 'file_begin = dword(0)',
    'windows.base must own FILE_BEGIN');
  CheckTokenPresent(LWindowsBase, 'file_current = dword(1)',
    'windows.base must own FILE_CURRENT');
  CheckTokenPresent(LWindowsBase, 'file_end = dword(2)',
    'windows.base must own FILE_END');
  CheckTokenPresent(LWindowsBase, 'invalid_set_file_pointer = dword($ffffffff)',
    'windows.base must own INVALID_SET_FILE_POINTER');

  CheckTokenPresent(LWindowsFfi, 'function getfilesize',
    'windows.ffi must own GetFileSize binding');
  CheckTokenPresent(LWindowsFfi, 'function flushfilebuffers',
    'windows.ffi must own FlushFileBuffers binding');
  CheckTokenPresent(LWindowsFfi, 'function setendoffile',
    'windows.ffi must own SetEndOfFile binding');
  CheckTokenPresent(LWindowsFfi, 'function setfilepointer',
    'windows.ffi must own SetFilePointer binding');
  CheckTokenPresent(LWindowsFfi, 'function getfilesizeex',
    'windows.ffi must own GetFileSizeEx binding');
  CheckTokenPresent(LWindowsFfi, 'function setfilepointerex',
    'windows.ffi must own SetFilePointerEx binding');
  CheckTokenAbsent(LWindowsFfi, 'function windows_get_file_size',
    'windows.ffi must not expose thin GetFileSize helper');
  CheckTokenAbsent(LWindowsFfi, 'function windows_get_file_size_ex',
    'windows.ffi must not expose thin GetFileSizeEx helper');
  CheckTokenAbsent(LWindowsFfi, 'function windows_set_file_pointer',
    'windows.ffi must not expose thin SetFilePointer helper');
  CheckTokenAbsent(LWindowsFfi, 'function windows_set_file_pointer_ex',
    'windows.ffi must not expose thin SetFilePointerEx helper');
  CheckTokenAbsent(LWindowsFfi, 'function windows_flush_file_buffers',
    'windows.ffi must not expose thin FlushFileBuffers helper');
  CheckTokenAbsent(LWindowsFfi, 'function windows_set_end_of_file',
    'windows.ffi must not expose thin SetEndOfFile helper');
end;

procedure CheckWave8DocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host abi completeness wave 8',
    'docs must name Platform Host ABI Completeness Wave 8');
  CheckTokenPresent(ADoc, 'file i/o continuation',
    'docs must identify the file I/O continuation scope');
  CheckTokenPresent(ADoc, 'read',
    'docs must include read evidence');
  CheckTokenPresent(ADoc, 'write',
    'docs must include write evidence');
  CheckTokenPresent(ADoc, 'lseek',
    'docs must include lseek evidence');
  CheckTokenPresent(ADoc, 'fsync',
    'docs must include fsync evidence');
  CheckTokenPresent(ADoc, 'ftruncate',
    'docs must include ftruncate evidence');
  CheckTokenPresent(ADoc, 'seek_set',
    'docs must include SEEK_SET evidence');
  CheckTokenPresent(ADoc, 'flushfilebuffers',
    'docs must include Windows FlushFileBuffers evidence');
  CheckTokenPresent(ADoc, 'setfilepointerex',
    'docs must include Windows SetFilePointerEx evidence');
  CheckTokenPresent(ADoc, 'setendoffile',
    'docs must include Windows SetEndOfFile evidence');
end;

procedure TestHostAbiWave8FileIoEvidenceDocumented;
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

  CheckWave8DocumentTokens(LSourceEvidence);
  CheckWave8DocumentTokens(LGapMatrix);
end;

procedure TestHostAbiWave8FileIoRouteTruth;
var
  LVerify: string;
begin
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LVerify, 'require_path core/tests/nextpas.core.platform/test_platform_host_abi_wave8_file_io/test_platform_host_abi_wave8_file_io.lpr',
    'verify_local must require the Wave 8 file I/O ABI source-surface test');
  CheckTokenPresent(LVerify, 'core-platform-host-abi-wave8-file-io-check=running',
    'verify_local must run the Wave 8 file I/O ABI focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_abi_wave8_file_io: 5 total, 5 passed, 0 failed',
    'verify_local must assert the Wave 8 file I/O ABI summary');
  CheckTokenPresent(LVerify, 'coreplatformhostabiwave8fileiocheck',
    'verify_local final envelope must include the Wave 8 file I/O ABI token');
end;

procedure TestFeatureSpecificFileFfiStillAbsent;
var
  LFeatureFilePath: string;
  LFeatureFileFfiPath: string;
begin
  LFeatureFilePath := ResolvePath(PLATFORM_FILE_PATH_FROM_TEST, PLATFORM_FILE_PATH_FROM_ROOT);
  Check(not FileExists(LFeatureFilePath),
    'Wave 8 must not introduce a public platform.file contract: ' + LFeatureFilePath);
  LFeatureFileFfiPath := ResolvePath(PLATFORM_FILE_FFI_PATH_FROM_TEST, PLATFORM_FILE_FFI_PATH_FROM_ROOT);
  Check(not FileExists(LFeatureFileFfiPath),
    'Wave 8 must not introduce a feature-specific platform.file.ffi owner: ' + LFeatureFileFfiPath);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_abi_wave8_file_io');
  T.Run('platform host ABI wave 8 POSIX file I/O source tokens are owned', @TestHostAbiWave8PosixFileIoSourceTokens);
  T.Run('platform host ABI wave 8 Windows file I/O source tokens are owned', @TestHostAbiWave8WindowsFileIoSourceTokens);
  T.Run('platform host ABI wave 8 file I/O evidence is documented', @TestHostAbiWave8FileIoEvidenceDocumented);
  T.Run('platform host ABI wave 8 file I/O route truth stays indexed', @TestHostAbiWave8FileIoRouteTruth);
  T.Run('platform host ABI wave 8 keeps feature-specific file ffi absent', @TestFeatureSpecificFileFfiStillAbsent);
  T.Summary;
end.
