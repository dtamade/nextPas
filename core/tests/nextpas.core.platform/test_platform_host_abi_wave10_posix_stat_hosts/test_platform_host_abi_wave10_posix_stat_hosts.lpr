program test_platform_host_abi_wave10_posix_stat_hosts;

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
  UNIX_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.unix.base.pas';
  UNIX_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.unix.base.pas';
  UNIX_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.unix.ffi.pas';
  UNIX_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.unix.ffi.pas';

  DARWIN_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.base.pas';
  DARWIN_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.base.pas';
  DARWIN_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.darwin.ffi.pas';
  DARWIN_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.darwin.ffi.pas';
  FREEBSD_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.base.pas';
  FREEBSD_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.base.pas';
  FREEBSD_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.freebsd.ffi.pas';
  FREEBSD_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.freebsd.ffi.pas';
  ANDROID_BASE_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.base.pas';
  ANDROID_BASE_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.base.pas';
  ANDROID_FFI_PATH_FROM_TEST = '../../../src/nextpas.core.platform.android.ffi.pas';
  ANDROID_FFI_PATH_FROM_ROOT = 'core/src/nextpas.core.platform.android.ffi.pas';

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

procedure CheckWave10DocumentTokens(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform host abi completeness wave 10',
    'docs must name Platform Host ABI Completeness Wave 10');
  CheckTokenPresent(ADoc, 'darwin / freebsd / android traditional stat',
    'docs must identify Wave 10 host stat scope');
  CheckTokenPresent(ADoc, 'rtl/bsd/ostypes.inc',
    'docs must include BSD/Darwin stat record evidence');
  CheckTokenPresent(ADoc, 'rtl/darwin/ptypes.inc',
    'docs must include Darwin scalar evidence');
  CheckTokenPresent(ADoc, 'rtl/freebsd/ptypes.inc',
    'docs must include FreeBSD scalar evidence');
  CheckTokenPresent(ADoc, 'rtl/unix/oscdeclh.inc',
    'docs must include Unix stat symbol suffix evidence');
  CheckTokenPresent(ADoc, '$INODE64',
    'docs must include Darwin inode64 symbol policy');
  CheckTokenPresent(ADoc, 'rtl/android/Makefile',
    'docs must include Android include ownership evidence');
  CheckTokenPresent(ADoc, 'rtl/android/x86_64/sysnr.inc',
    'docs must include Android x86_64 syscall evidence');
  CheckTokenPresent(ADoc, 'rtl/android/aarch64/sysnr.inc',
    'docs must include Android aarch64 syscall evidence');
  CheckTokenPresent(ADoc, 'rtl/linux/ossysc.inc',
    'docs must include Android stat syscall route evidence');
  CheckTokenPresent(ADoc, 'rtl/linux/bunxsysc.inc',
    'docs must include Android lstat syscall route evidence');
  CheckTokenPresent(ADoc, 'generic unix remains deferred',
    'docs must keep generic Unix stat deferred');
end;

procedure TestDarwinStatHostOwnerTokens;
var
  LDarwinBase: string;
  LDarwinFfi: string;
begin
  LDarwinBase := ReadSourceFile(ResolveRequiredPath(
    DARWIN_BASE_PATH_FROM_TEST,
    DARWIN_BASE_PATH_FROM_ROOT,
    'darwin base must exist'));
  LDarwinFfi := ReadSourceFile(ResolveRequiredPath(
    DARWIN_FFI_PATH_FROM_TEST,
    DARWIN_FFI_PATH_FROM_ROOT,
    'darwin ffi must exist'));

  CheckTokenPresent(LDarwinBase, 'tplatformdarwinstat = record',
    'darwin.base must own the Darwin stat record');
  CheckTokenPresent(LDarwinBase, 'pplatformdarwinstat = ^tplatformdarwinstat',
    'darwin.base must own the Darwin stat pointer');
  CheckTokenPresent(LDarwinBase, 'st_birthtime',
    'darwin.base must preserve Darwin birth time field');
  CheckTokenPresent(LDarwinBase, 'st_birthtimensec',
    'darwin.base must preserve Darwin birth time nanosecond field');
  CheckTokenPresent(LDarwinBase, 'st_qspare',
    'darwin.base must preserve Darwin spare fields');

  CheckTokenPresent(LDarwinFfi, 'function stat',
    'darwin.ffi must own Darwin stat binding');
  CheckTokenPresent(LDarwinFfi, 'function lstat',
    'darwin.ffi must own Darwin lstat binding');
  CheckTokenPresent(LDarwinFfi, 'function fstat',
    'darwin.ffi must own Darwin fstat binding');
  CheckTokenAbsent(LDarwinFfi, 'function darwin_',
    'darwin.ffi raw declarations must not repeat the host prefix');
  CheckTokenPresent(LDarwinFfi, 'name ''stat$inode64''',
    'darwin.ffi must use Darwin stat$INODE64 symbol');
  CheckTokenPresent(LDarwinFfi, 'name ''lstat$inode64''',
    'darwin.ffi must use Darwin lstat$INODE64 symbol');
  CheckTokenPresent(LDarwinFfi, 'name ''fstat$inode64''',
    'darwin.ffi must use Darwin fstat$INODE64 symbol');
  CheckTokenAbsent(LDarwinFfi, 'function darwin_stat_path',
    'darwin.ffi must not expose Darwin stat path helper');
  CheckTokenAbsent(LDarwinFfi, 'function darwin_lstat_path',
    'darwin.ffi must not expose Darwin lstat path helper');
  CheckTokenAbsent(LDarwinFfi, 'function darwin_fstat_fd',
    'darwin.ffi must not expose Darwin fstat fd helper');
end;

procedure TestFreeBSDStatHostOwnerTokens;
var
  LFreeBSDBase: string;
  LFreeBSDFfi: string;
begin
  LFreeBSDBase := ReadSourceFile(ResolveRequiredPath(
    FREEBSD_BASE_PATH_FROM_TEST,
    FREEBSD_BASE_PATH_FROM_ROOT,
    'freebsd base must exist'));
  LFreeBSDFfi := ReadSourceFile(ResolveRequiredPath(
    FREEBSD_FFI_PATH_FROM_TEST,
    FREEBSD_FFI_PATH_FROM_ROOT,
    'freebsd ffi must exist'));

  CheckTokenPresent(LFreeBSDBase, 'tplatformfreebsdstat = record',
    'freebsd.base must own the FreeBSD stat record');
  CheckTokenPresent(LFreeBSDBase, 'pplatformfreebsdstat = ^tplatformfreebsdstat',
    'freebsd.base must own the FreeBSD stat pointer');
  CheckTokenPresent(LFreeBSDBase, 'st_padding0',
    'freebsd.base must preserve FreeBSD stat padding');
  CheckTokenPresent(LFreeBSDBase, 'st_birthtime',
    'freebsd.base must preserve FreeBSD birth time field');
  CheckTokenPresent(LFreeBSDBase, 'st_spare',
    'freebsd.base must preserve FreeBSD spare fields');

  CheckTokenPresent(LFreeBSDFfi, 'function stat',
    'freebsd.ffi must own FreeBSD stat binding');
  CheckTokenPresent(LFreeBSDFfi, 'function lstat',
    'freebsd.ffi must own FreeBSD lstat binding');
  CheckTokenPresent(LFreeBSDFfi, 'function fstat',
    'freebsd.ffi must own FreeBSD fstat binding');
  CheckTokenAbsent(LFreeBSDFfi, 'function freebsd_',
    'freebsd.ffi raw declarations must not repeat the host prefix');
  CheckTokenPresent(LFreeBSDFfi, 'name ''stat''',
    'freebsd.ffi must use FreeBSD stat symbol');
  CheckTokenPresent(LFreeBSDFfi, 'name ''lstat''',
    'freebsd.ffi must use FreeBSD lstat symbol');
  CheckTokenPresent(LFreeBSDFfi, 'name ''fstat''',
    'freebsd.ffi must use FreeBSD fstat symbol');
  CheckTokenAbsent(LFreeBSDFfi, 'function freebsd_stat_path',
    'freebsd.ffi must not expose FreeBSD stat path helper');
  CheckTokenAbsent(LFreeBSDFfi, 'function freebsd_lstat_path',
    'freebsd.ffi must not expose FreeBSD lstat path helper');
  CheckTokenAbsent(LFreeBSDFfi, 'function freebsd_fstat_fd',
    'freebsd.ffi must not expose FreeBSD fstat fd helper');
end;

procedure TestAndroidStatHostOwnerTokens;
var
  LAndroidBase: string;
  LAndroidFfi: string;
begin
  LAndroidBase := ReadSourceFile(ResolveRequiredPath(
    ANDROID_BASE_PATH_FROM_TEST,
    ANDROID_BASE_PATH_FROM_ROOT,
    'android base must exist'));
  LAndroidFfi := ReadSourceFile(ResolveRequiredPath(
    ANDROID_FFI_PATH_FROM_TEST,
    ANDROID_FFI_PATH_FROM_ROOT,
    'android ffi must exist'));

  CheckTokenPresent(LAndroidBase, 'tplatformandroidstat = record',
    'android.base must own the Android stat record');
  CheckTokenPresent(LAndroidBase, 'pplatformandroidstat = ^tplatformandroidstat',
    'android.base must own the Android stat pointer');
  CheckTokenPresent(LAndroidBase, 'st_atime_nsec',
    'android.base must preserve Android/Linux stat nanosecond fields');
  CheckTokenPresent(LAndroidBase, 'platform_android_at_fdcwd',
    'android.base must own Android AT_FDCWD');
  CheckTokenPresent(LAndroidBase, 'platform_android_at_symlink_nofollow',
    'android.base must own Android AT_SYMLINK_NOFOLLOW');
  CheckTokenPresent(LAndroidBase, 'android_syscall_newfstatat',
    'android.base must own Android newfstatat syscall number');
  CheckTokenPresent(LAndroidBase, 'android_syscall_fstat',
    'android.base must own Android fstat syscall number');

  CheckTokenPresent(LAndroidFfi, 'function syscall',
    'android.ffi must own Android syscall binding');
  CheckTokenAbsent(LAndroidFfi, 'function android_',
    'android.ffi raw declarations must not repeat the host prefix');
  CheckTokenAbsent(LAndroidFfi, 'function android_newfstatat',
    'android.ffi must not expose Android newfstatat helper');
  CheckTokenAbsent(LAndroidFfi, 'function android_fstat',
    'android.ffi must not expose Android fstat helper');
  CheckTokenAbsent(LAndroidFfi, 'function android_stat_path',
    'android.ffi must not expose Android stat path helper');
  CheckTokenAbsent(LAndroidFfi, 'function android_lstat_path',
    'android.ffi must not expose Android lstat path helper');
  CheckTokenAbsent(LAndroidFfi, 'function android_fstat_fd',
    'android.ffi must not expose Android fstat fd helper');
  CheckTokenAbsent(LAndroidFfi, '__xstat',
    'android.ffi must not use Linux glibc __xstat wrappers');
  CheckTokenAbsent(LAndroidFfi, '__lxstat',
    'android.ffi must not use Linux glibc __lxstat wrappers');
  CheckTokenAbsent(LAndroidFfi, '__fxstat',
    'android.ffi must not use Linux glibc __fxstat wrappers');
end;

procedure TestSharedAndGenericUnixStatStillDeferred;
var
  LPosixBase: string;
  LPosixFfi: string;
  LUnixBase: string;
  LUnixFfi: string;
begin
  LPosixBase := ReadSourceFile(ResolveRequiredPath(
    POSIX_BASE_PATH_FROM_TEST,
    POSIX_BASE_PATH_FROM_ROOT,
    'posix base must exist'));
  LPosixFfi := ReadSourceFile(ResolveRequiredPath(
    POSIX_FFI_PATH_FROM_TEST,
    POSIX_FFI_PATH_FROM_ROOT,
    'posix ffi must exist'));
  LUnixBase := ReadSourceFile(ResolveRequiredPath(
    UNIX_BASE_PATH_FROM_TEST,
    UNIX_BASE_PATH_FROM_ROOT,
    'generic unix base must exist'));
  LUnixFfi := ReadSourceFile(ResolveRequiredPath(
    UNIX_FFI_PATH_FROM_TEST,
    UNIX_FFI_PATH_FROM_ROOT,
    'generic unix ffi must exist'));

  CheckTokenAbsent(LPosixBase, 'tplatformstat',
    'posix.base must not own a shared POSIX stat record');
  CheckTokenAbsent(LPosixFfi, 'function stat(',
    'posix.ffi must not expose a shared stat binding');
  CheckTokenAbsent(LPosixFfi, 'function lstat(',
    'posix.ffi must not expose a shared lstat binding');
  CheckTokenAbsent(LPosixFfi, 'function fstat(',
    'posix.ffi must not expose a shared fstat binding');
  CheckTokenAbsent(LUnixBase, 'tplatformunixstat',
    'generic unix base must not invent a stat record');
  CheckTokenAbsent(LUnixFfi, 'function unix_stat',
    'generic unix ffi must keep stat deferred');
end;

procedure TestHostAbiWave10PosixStatHostsEvidenceDocumented;
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

  CheckWave10DocumentTokens(LSourceEvidence);
  CheckWave10DocumentTokens(LGapMatrix);
end;

procedure TestHostAbiWave10PosixStatHostsRouteTruth;
var
  LVerify: string;
begin
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LVerify, 'require_path core/tests/nextpas.core.platform/test_platform_host_abi_wave10_posix_stat_hosts/test_platform_host_abi_wave10_posix_stat_hosts.lpr',
    'verify_local must require the Wave 10 POSIX stat hosts source-surface test');
  CheckTokenPresent(LVerify, 'core-platform-host-abi-wave10-posix-stat-hosts-check=running',
    'verify_local must run the Wave 10 POSIX stat hosts focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.host_abi_wave10_posix_stat_hosts: 7 total, 7 passed, 0 failed',
    'verify_local must assert the Wave 10 POSIX stat hosts pass summary');
  CheckTokenPresent(LVerify, 'coreplatformhostabiwave10posixstathostscheck',
    'verify_local final envelope must include the Wave 10 POSIX stat hosts token');
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
    'Wave 10 must not introduce a public platform.file contract: ' + LFeatureFilePath);
  Check(not FileExists(LFeatureFileFfiPath),
    'Wave 10 must not introduce a feature-specific platform.file.ffi owner: ' + LFeatureFileFfiPath);

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

  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'function darwin_stat',
    'platform.time/sync/thread must not consume Wave 10 Darwin stat raw ABI');
  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'function freebsd_stat',
    'platform.time/sync/thread must not consume Wave 10 FreeBSD stat raw ABI');
  CheckTokenAbsent(LPlatformTime + LPlatformSync + LPlatformThread, 'android_syscall_newfstatat',
    'platform.time/sync/thread must not consume Wave 10 Android stat raw ABI');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.host_abi_wave10_posix_stat_hosts');
  T.Run('platform host ABI wave 10 Darwin stat source tokens are owned', @TestDarwinStatHostOwnerTokens);
  T.Run('platform host ABI wave 10 FreeBSD stat source tokens are owned', @TestFreeBSDStatHostOwnerTokens);
  T.Run('platform host ABI wave 10 Android stat source tokens are owned', @TestAndroidStatHostOwnerTokens);
  T.Run('platform host ABI wave 10 keeps shared and generic Unix stat deferred', @TestSharedAndGenericUnixStatStillDeferred);
  T.Run('platform host ABI wave 10 POSIX stat host evidence is documented', @TestHostAbiWave10PosixStatHostsEvidenceDocumented);
  T.Run('platform host ABI wave 10 POSIX stat host route truth stays indexed', @TestHostAbiWave10PosixStatHostsRouteTruth);
  T.Run('platform host ABI wave 10 keeps feature-specific file ffi absent', @TestFeatureSpecificFileFfiStillAbsent);
  T.Summary;
end.
