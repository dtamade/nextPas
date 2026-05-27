program test_platform_ffi_source_evidence_index;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing;

const
  DOC_PATH_FROM_TEST = '../../../docs/platform-ffi-source-evidence-index.md';
  DOC_PATH_FROM_ROOT = 'core/docs/platform-ffi-source-evidence-index.md';
  DESIGN_CONVENTIONS_PATH_FROM_TEST = '../../../docs/design-conventions.md';
  DESIGN_CONVENTIONS_PATH_FROM_ROOT = 'core/docs/design-conventions.md';
  HOST_GAP_MATRIX_PATH_FROM_TEST = '../../../docs/platform-host-ffi-gap-matrix.md';
  HOST_GAP_MATRIX_PATH_FROM_ROOT = 'core/docs/platform-host-ffi-gap-matrix.md';
  VERIFY_LOCAL_PATH_FROM_TEST = '../../../../build/verify_local.sh';
  VERIFY_LOCAL_PATH_FROM_ROOT = 'build/verify_local.sh';

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

procedure CheckEvidenceDocCoverage(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'platform ffi source evidence index',
    'source evidence doc must have the canonical title');
  CheckTokenPresent(ADoc, 'reference authority, not production dependency',
    'source evidence doc must state the FPC source dependency boundary');
  CheckTokenPresent(ADoc, 'nextpas-owned host base/ffi',
    'source evidence doc must point declarations back to nextPas host owners');
  CheckTokenPresent(ADoc, 'not runtime proof',
    'source evidence doc must not overstate source evidence as runtime proof');

  CheckTokenPresent(ADoc, 'linux', 'source evidence doc must cover Linux');
  CheckTokenPresent(ADoc, 'android', 'source evidence doc must cover Android');
  CheckTokenPresent(ADoc, 'darwin', 'source evidence doc must cover Darwin');
  CheckTokenPresent(ADoc, 'freebsd', 'source evidence doc must cover FreeBSD');
  CheckTokenPresent(ADoc, 'generic unix', 'source evidence doc must cover generic Unix');
  CheckTokenPresent(ADoc, 'windows', 'source evidence doc must cover Windows');

  CheckTokenPresent(ADoc, 'clock_gettime',
    'source evidence doc must cover POSIX clock declarations');
  CheckTokenPresent(ADoc, 'clock_getres',
    'source evidence doc must cover POSIX clock resolution declarations');
  CheckTokenPresent(ADoc, 'timespec',
    'source evidence doc must cover POSIX timespec shape');
  CheckTokenPresent(ADoc, 'mach_absolute_time',
    'source evidence doc must cover Darwin Mach monotonic clock');
  CheckTokenPresent(ADoc, 'mach_timebase_info',
    'source evidence doc must cover Darwin Mach timebase');
  CheckTokenPresent(ADoc, 'queryperformancecounter',
    'source evidence doc must cover Windows QPC declarations');
  CheckTokenPresent(ADoc, 'getsystemtimeasfiletime',
    'source evidence doc must cover Windows FILETIME declarations');

  CheckTokenPresent(ADoc, '__errno_location',
    'source evidence doc must cover Linux/generic Unix errno binding');
  CheckTokenPresent(ADoc, '__error',
    'source evidence doc must cover BSD/Darwin errno binding');
  CheckTokenPresent(ADoc, '__errno',
    'source evidence doc must cover Android errno binding');

  CheckTokenPresent(ADoc, 'pthread_create',
    'source evidence doc must cover pthread lifecycle declarations');
  CheckTokenPresent(ADoc, 'pthread_join',
    'source evidence doc must cover pthread join declarations');
  CheckTokenPresent(ADoc, 'pthread_key_create',
    'source evidence doc must cover pthread TLS declarations');
  CheckTokenPresent(ADoc, 'pthread_mutex_timedlock',
    'source evidence doc must cover pthread mutex timedlock capability');
  CheckTokenPresent(ADoc, 'pthread_condattr_setclock',
    'source evidence doc must cover pthread condattr clock capability');
  CheckTokenPresent(ADoc, 'pthread_threadid_np',
    'source evidence doc must cover Darwin native thread id evidence');
  CheckTokenPresent(ADoc, 'pthread_getthreadid_np',
    'source evidence doc must cover FreeBSD native thread id evidence');
  CheckTokenPresent(ADoc, 'gettid',
    'source evidence doc must cover Linux/Android native thread id evidence');
  CheckTokenPresent(ADoc, '_sc_nprocessors_onln',
    'source evidence doc must cover CPU count sysconf token evidence');

  CheckTokenPresent(ADoc, 'futex',
    'source evidence doc must cover Linux futex declarations');
  CheckTokenPresent(ADoc, 'futex_wait',
    'source evidence doc must cover Linux futex wait token');
  CheckTokenPresent(ADoc, 'futex_wake',
    'source evidence doc must cover Linux futex wake token');
  CheckTokenPresent(ADoc, 'syscall_nr_futex',
    'source evidence doc must cover Linux syscall number evidence');

  CheckTokenPresent(ADoc, 'srwlock',
    'source evidence doc must cover Windows SRWLOCK shape');
  CheckTokenPresent(ADoc, 'condition_variable',
    'source evidence doc must cover Windows CONDITION_VARIABLE shape');
  CheckTokenPresent(ADoc, 'waitonaddress',
    'source evidence doc must cover Windows WaitOnAddress evidence');
  CheckTokenPresent(ADoc, 'createThread',
    'source evidence doc must cover Windows CreateThread evidence');
  CheckTokenPresent(ADoc, 'tlsalloc',
    'source evidence doc must cover Windows TLS evidence');
  CheckTokenPresent(ADoc, 'getsysteminfo',
    'source evidence doc must cover Windows CPU-count evidence');
end;

procedure CheckFpcSourceFamilies(const ADoc: string);
begin
  CheckTokenPresent(ADoc, 'rtl/linux/linux.pp',
    'source evidence doc must cite FPC Linux unit family');
  CheckTokenPresent(ADoc, 'rtl/linux/ptypes.inc',
    'source evidence doc must cite FPC Linux POSIX type family');
  CheckTokenPresent(ADoc, 'rtl/linux/pthread.inc',
    'source evidence doc must cite FPC Linux pthread declarations');
  CheckTokenPresent(ADoc, 'rtl/android',
    'source evidence doc must cite FPC Android source family');
  CheckTokenPresent(ADoc, 'packages/pthreads/src/pthrandroid.inc',
    'source evidence doc must cite FPC Android pthread declarations');
  CheckTokenPresent(ADoc, 'rtl/darwin/ptypes.inc',
    'source evidence doc must cite FPC Darwin POSIX type family');
  CheckTokenPresent(ADoc, 'rtl/darwin/pthread.inc',
    'source evidence doc must cite FPC Darwin pthread declarations');
  CheckTokenPresent(ADoc, 'rtl/freebsd/freebsd.pas',
    'source evidence doc must cite FPC FreeBSD clock declarations');
  CheckTokenPresent(ADoc, 'rtl/freebsd/pthread.inc',
    'source evidence doc must cite FPC FreeBSD pthread declarations');
  CheckTokenPresent(ADoc, 'rtl/unix/initc.pp',
    'source evidence doc must cite FPC generic Unix errno declarations');
  CheckTokenPresent(ADoc, 'rtl/unix/cthreads.pp',
    'source evidence doc must cite FPC generic Unix pthread clock policy');
  CheckTokenPresent(ADoc, 'rtl/win32/windows.pp',
    'source evidence doc must cite FPC Win32 Windows unit');
  CheckTokenPresent(ADoc, 'rtl/win64/windows.pp',
    'source evidence doc must cite FPC Win64 Windows unit');
  CheckTokenPresent(ADoc, 'packages/winunits-base',
    'source evidence doc must cite FPC Windows package family');
  CheckTokenPresent(ADoc, 'os sdk',
    'source evidence doc must mark Windows APIs missing from FPC as OS SDK evidence');
end;

procedure TestSourceEvidenceIndexDocument;
var
  LDoc: string;
begin
  LDoc := ReadSourceFile(ResolveRequiredPath(
    DOC_PATH_FROM_TEST,
    DOC_PATH_FROM_ROOT,
    'platform ffi source evidence index doc must exist'));

  CheckEvidenceDocCoverage(LDoc);
  CheckFpcSourceFamilies(LDoc);
end;

procedure TestSourceEvidenceRouteTruth;
var
  LDesign: string;
  LGapMatrix: string;
  LVerify: string;
begin
  LDesign := ReadSourceFile(ResolveRequiredPath(
    DESIGN_CONVENTIONS_PATH_FROM_TEST,
    DESIGN_CONVENTIONS_PATH_FROM_ROOT,
    'design conventions doc must exist'));
  LGapMatrix := ReadSourceFile(ResolveRequiredPath(
    HOST_GAP_MATRIX_PATH_FROM_TEST,
    HOST_GAP_MATRIX_PATH_FROM_ROOT,
    'platform host gap matrix doc must exist'));
  LVerify := ReadSourceFile(ResolveRequiredPath(
    VERIFY_LOCAL_PATH_FROM_TEST,
    VERIFY_LOCAL_PATH_FROM_ROOT,
    'verify_local route must exist'));

  CheckTokenPresent(LDesign, 'docs/platform-ffi-source-evidence-index.md',
    'design conventions must index the platform ffi source evidence doc');
  CheckTokenPresent(LDesign, 'core-platform-ffi-source-evidence-index-check',
    'design conventions must name the source evidence line token');
  CheckTokenPresent(LDesign, 'coreplatformffisourceevidenceindexcheck',
    'design conventions must name the source evidence envelope token');
  CheckTokenPresent(LDesign, 'fpc source',
    'design conventions must keep the FPC source reference rule visible');

  CheckTokenPresent(LGapMatrix, 'docs/platform-ffi-source-evidence-index.md',
    'host gap matrix must point to the source evidence index');
  CheckTokenPresent(LGapMatrix, 'fpc source evidence',
    'host gap matrix must keep source evidence separate from runtime proof');

  CheckTokenPresent(LVerify, 'require_path core/docs/platform-ffi-source-evidence-index.md',
    'verify_local must require the source evidence doc');
  CheckTokenPresent(LVerify, 'core-platform-ffi-source-evidence-index-check=running',
    'verify_local must run the source evidence focused check');
  CheckTokenPresent(LVerify, 'nextpas\.core\.platform\.ffi_source_evidence_index: 2 total, 2 passed, 0 failed',
    'verify_local must assert the source evidence summary');
  CheckTokenPresent(LVerify, 'coreplatformffisourceevidenceindexcheck',
    'verify_local final envelope must include the source evidence token');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.ffi_source_evidence_index');
  T.Run('platform ffi source evidence index doc is explicit', @TestSourceEvidenceIndexDocument);
  T.Run('platform ffi source evidence route truth stays indexed', @TestSourceEvidenceRouteTruth);
  T.Summary;
end.
