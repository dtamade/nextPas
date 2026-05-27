program test_platform_host_abi_wave1;

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

procedure CheckProcessTimevalMmapAndDlOwnerTokens(
  const ABase,
  AFfi,
  AHostName,
  AHostPrefix,
  ARtldLazy,
  ARtldNow,
  ARtldLocal,
  ARtldGlobal: string);
begin
  CheckTokenPresent(ABase, 'pid_t',
    AHostName + ' base must own pid_t');
  CheckTokenPresent(ABase, 'platform_rtld_lazy = int32(' + ARtldLazy + ')',
    AHostName + ' base must own RTLD_LAZY');
  CheckTokenPresent(ABase, 'platform_rtld_now = int32(' + ARtldNow + ')',
    AHostName + ' base must own RTLD_NOW');
  CheckTokenPresent(ABase, 'platform_rtld_local = int32(' + ARtldLocal + ')',
    AHostName + ' base must own RTLD_LOCAL');
  CheckTokenPresent(ABase, 'platform_rtld_global = int32(' + ARtldGlobal + ')',
    AHostName + ' base must own RTLD_GLOBAL');

  CheckTokenPresent(AFfi, 'function ' + AHostPrefix + '_process_id',
    AHostName + ' ffi must expose host-owned process id helper');
  CheckTokenPresent(AFfi, 'function ' + AHostPrefix + '_parent_process_id',
    AHostName + ' ffi must expose host-owned parent process id helper');
  CheckTokenAbsent(AFfi, 'function platform_process_id',
    AHostName + ' ffi must not expose unified-looking process id helper');
  CheckTokenAbsent(AFfi, 'function platform_parent_process_id',
    AHostName + ' ffi must not expose unified-looking parent process id helper');
  CheckTokenPresent(AFfi, 'function platform_mmap',
    AHostName + ' ffi must expose mmap helper');
  CheckTokenPresent(AFfi, 'function platform_munmap',
    AHostName + ' ffi must expose munmap helper');
  CheckTokenPresent(AFfi, 'function platform_mprotect',
    AHostName + ' ffi must expose mprotect helper');
  CheckTokenPresent(AFfi, 'function platform_dlopen',
    AHostName + ' ffi must expose dynamic loader open helper');
  CheckTokenPresent(AFfi, 'function platform_dlsym',
    AHostName + ' ffi must expose dynamic loader symbol helper');
  CheckTokenPresent(AFfi, 'function platform_dlclose',
    AHostName + ' ffi must expose dynamic loader close helper');
  CheckTokenPresent(AFfi, 'function platform_dlerror',
    AHostName + ' ffi must expose dynamic loader error helper');
  CheckTokenPresent(AFfi, 'function dlopen',
    AHostName + ' ffi must own dlopen binding');
  CheckTokenPresent(AFfi, 'function dlsym',
    AHostName + ' ffi must own dlsym binding');
  CheckTokenPresent(AFfi, 'function dlclose',
    AHostName + ' ffi must own dlclose binding');
  CheckTokenPresent(AFfi, 'function dlerror',
    AHostName + ' ffi must own dlerror binding');
end;

procedure CheckProcessTimevalMmapAndDlDocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host abi completeness wave 1',
    'docs must name Platform Host ABI Completeness Wave 1');
  CheckTokenPresent(ADoc, 'process id',
    'docs must include process id scope');
  CheckTokenPresent(ADoc, 'timeval',
    'docs must include timeval scope');
  CheckTokenPresent(ADoc, 'mmap',
    'docs must include mmap scope');
  CheckTokenPresent(ADoc, 'dynamic loader',
    'docs must include dynamic loader scope');
  CheckTokenPresent(ADoc, 'stat/open/fcntl deferred',
    'docs must record the deferred stat/open/fcntl boundary');
  CheckTokenPresent(ADoc, 'getpid',
    'docs must include getpid evidence');
  CheckTokenPresent(ADoc, 'getppid',
    'docs must include getppid evidence');
  CheckTokenPresent(ADoc, 'fpmmap',
    'docs must include FPC fpmmap evidence');
  CheckTokenPresent(ADoc, 'fpmunmap',
    'docs must include FPC fpmunmap evidence');
  CheckTokenPresent(ADoc, 'dlopen',
    'docs must include dlopen evidence');
  CheckTokenPresent(ADoc, 'dlsym',
    'docs must include dlsym evidence');
  CheckTokenPresent(ADoc, 'loadlibrarya',
    'docs must include Windows LoadLibraryA evidence');
  CheckTokenPresent(ADoc, 'getprocaddress',
    'docs must include Windows GetProcAddress evidence');
  CheckTokenPresent(ADoc, 'virtualalloc',
    'docs must include Windows VirtualAlloc evidence');
end;

procedure TestHostAbiWave1SourceTokens;
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

  CheckTokenPresent(LPosixBase, 'timeval = record',
    'posix.base must own shared timeval shape');
  CheckTokenPresent(LPosixBase, 'ptimeval',
    'posix.base must own PTimeVal');
  CheckTokenPresent(LPosixBase, 'platform_posix_prot_read',
    'posix.base must own PROT_READ');
  CheckTokenPresent(LPosixBase, 'platform_posix_map_private',
    'posix.base must own MAP_PRIVATE');
  CheckTokenPresent(LPosixBase, 'platform_posix_map_failed',
    'posix.base must own MAP_FAILED');
  CheckTokenPresent(LPosixFfi, 'function platform_posix_mmap_failed',
    'posix.ffi must own MAP_FAILED helper');
  CheckTokenPresent(LPosixFfi, 'function getpid',
    'posix.ffi must own shared getpid binding');
  CheckTokenPresent(LPosixFfi, 'function getppid',
    'posix.ffi must own shared getppid binding');
  CheckTokenPresent(LPosixFfi, 'function mmap',
    'posix.ffi must own shared mmap binding');
  CheckTokenPresent(LPosixFfi, 'function munmap',
    'posix.ffi must own shared munmap binding');
  CheckTokenPresent(LPosixFfi, 'function mprotect',
    'posix.ffi must own shared mprotect binding');

  CheckProcessTimevalMmapAndDlOwnerTokens(LLinuxBase, LLinuxFfi, 'Linux', 'linux', '1', '2', '0', '$100');
  CheckProcessTimevalMmapAndDlOwnerTokens(LAndroidBase, LAndroidFfi, 'Android', 'android', '1', '2', '0', '$100');
  CheckProcessTimevalMmapAndDlOwnerTokens(LDarwinBase, LDarwinFfi, 'Darwin', 'darwin', '1', '2', '4', '8');
  CheckProcessTimevalMmapAndDlOwnerTokens(LFreeBSDBase, LFreeBSDFfi, 'FreeBSD', 'freebsd', '1', '2', '0', '$100');
  CheckProcessTimevalMmapAndDlOwnerTokens(LUnixBase, LUnixFfi, 'generic Unix', 'unix', '1', '2', '0', '$100');

  CheckTokenPresent(LWindowsBase, 'platform_windows_mem_commit',
    'Windows base must own MEM_COMMIT');
  CheckTokenPresent(LWindowsBase, 'platform_windows_page_readwrite',
    'Windows base must own PAGE_READWRITE');
  CheckTokenPresent(LWindowsBase, 'platform_windows_invalid_handle_value',
    'Windows base must own INVALID_HANDLE_VALUE');
  CheckTokenPresent(LWindowsFfi, 'function getcurrentprocessid',
    'Windows ffi must own GetCurrentProcessId');
  CheckTokenPresent(LWindowsFfi, 'function loadlibrarya',
    'Windows ffi must own LoadLibraryA');
  CheckTokenPresent(LWindowsFfi, 'function getprocaddress',
    'Windows ffi must own GetProcAddress');
  CheckTokenPresent(LWindowsFfi, 'function freelibrary',
    'Windows ffi must own FreeLibrary');
  CheckTokenPresent(LWindowsFfi, 'function virtualalloc',
    'Windows ffi must own VirtualAlloc');
  CheckTokenPresent(LWindowsFfi, 'function virtualfree',
    'Windows ffi must own VirtualFree');
  CheckTokenPresent(LWindowsFfi, 'function virtualprotect',
    'Windows ffi must own VirtualProtect');
end;

procedure TestHostAbiWave1Documented;
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

  CheckProcessTimevalMmapAndDlDocumentTokens(LSourceEvidence);
  CheckProcessTimevalMmapAndDlDocumentTokens(LGapMatrix);
end;

procedure TestHostAbiWave1RouteTruth;
var
  LVerify: string;
begin
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LVerify, 'require_path core/tests/nextpas.core.platform/test_platform_host_abi_wave1/test_platform_host_abi_wave1.lpr',
    'verify_local must require the Wave 1 source-surface test');
  CheckTokenPresent(LVerify, 'core-platform-host-abi-wave1-check=running',
    'verify_local must run the Wave 1 focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_abi_wave1: 3 total, 3 passed, 0 failed',
    'verify_local must assert the Wave 1 summary');
  CheckTokenPresent(LVerify, 'coreplatformhostabiwave1check',
    'verify_local final envelope must include the Wave 1 token');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_abi_wave1');
  T.Run('platform host ABI wave 1 source tokens are owned', @TestHostAbiWave1SourceTokens);
  T.Run('platform host ABI wave 1 evidence is documented', @TestHostAbiWave1Documented);
  T.Run('platform host ABI wave 1 route truth stays indexed', @TestHostAbiWave1RouteTruth);
  T.Summary;
end.
