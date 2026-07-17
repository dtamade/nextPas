program test_platform_return_semantics_contract;

{ Source + runtime contracts for platform return tiers, PLATFORM_ERR_* namespace,
  FPC RTL isolation on production platform units, and args host-FFI ownership. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.fs.glob,
  nextpas.core.path,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.platform.error,
  nextpas.core.platform.fmt,
  nextpas.core.platform.dl,
  nextpas.core.platform.args,
  nextpas.core.platform.resource,
  nextpas.core.platform.resource.base,
  nextpas.core.platform.process,
  nextpas.core.test;

const
  SRC_ROOT_FROM_TEST = '../../../src/';
  SRC_ROOT_FROM_REPO = 'core/src/';

var
  T: TTestSuite;

function ResolveSrc(const AName: string): string;
begin
  if FileExists(SRC_ROOT_FROM_TEST + AName) then
    Exit(SRC_ROOT_FROM_TEST + AName);
  if FileExists(SRC_ROOT_FROM_REPO + AName) then
    Exit(SRC_ROOT_FROM_REPO + AName);
  Result := SRC_ROOT_FROM_TEST + AName;
end;

function ReadLower(const APath: string): string;
begin
  Result := LowerCase(FsReadFileText(APath));
end;

function ReadRaw(const APath: string): string;
begin
  Result := FsReadFileText(APath);
end;

procedure CheckContains(const ASource, AToken, AMsg: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMsg + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMsg: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMsg + ': ' + AToken);
end;

procedure TestErrorConstantsMatchDoc;
begin
  CheckEqual(Int64(1), Int64(PLATFORM_ERR_PERM), 'PERM=1');
  CheckEqual(Int64(2), Int64(PLATFORM_ERR_NOENT), 'NOENT=2');
  CheckEqual(Int64(4), Int64(PLATFORM_ERR_INTR), 'INTR=4');
  CheckEqual(Int64(5), Int64(PLATFORM_ERR_IO), 'IO=5');
  CheckEqual(Int64(9), Int64(PLATFORM_ERR_BADF), 'BADF=9');
  CheckEqual(Int64(11), Int64(PLATFORM_ERR_AGAIN), 'AGAIN=11');
  CheckEqual(Int64(12), Int64(PLATFORM_ERR_NOMEM), 'NOMEM=12');
  CheckEqual(Int64(16), Int64(PLATFORM_ERR_BUSY), 'BUSY=16');
  CheckEqual(Int64(17), Int64(PLATFORM_ERR_EXIST), 'EXIST=17');
  CheckEqual(Int64(20), Int64(PLATFORM_ERR_NOTDIR), 'NOTDIR=20');
  CheckEqual(Int64(22), Int64(PLATFORM_ERR_INVALID), 'INVALID=22');
  CheckEqual(Int64(28), Int64(PLATFORM_ERR_NOSPC), 'NOSPC=28');
  CheckEqual(Int64(32), Int64(PLATFORM_ERR_PIPE), 'PIPE=32');
  CheckEqual(Int64(38), Int64(PLATFORM_ERR_NOSYS), 'NOSYS=38');
  CheckEqual(Int64(95), Int64(PLATFORM_ERR_UNSUPPORTED), 'UNSUPPORTED=95');
  CheckEqual(Int64(104), Int64(PLATFORM_ERR_CONNRESET), 'CONNRESET=104');
  CheckEqual(Int64(110), Int64(PLATFORM_ERR_TIMEDOUT), 'TIMEDOUT=110');
  CheckEqual(Int64(111), Int64(PLATFORM_ERR_CONNREFUSED), 'CONNREFUSED=111');
  CheckEqual(Int64(-7), Int64(PLATFORM_ERR_PATH_TOO_LONG), 'PATH_TOO_LONG=-7 domain clamp');
  CheckEqual(Int64(-8), Int64(PLATFORM_ERR_UNKNOWN), 'UNKNOWN=-8');
  { bare -1 is not a portable PLATFORM_ERR_* value }
  Check(PLATFORM_ERR_INVALID <> -1, 'INVALID is not bare -1');
  Check(PLATFORM_ERR_UNSUPPORTED <> -1, 'UNSUPPORTED is not bare -1');
  Check(PLATFORM_ERR_UNKNOWN <> -1, 'UNKNOWN is not bare -1');
  Check(PLATFORM_ERR_PATH_TOO_LONG <> 36, 'PATH_TOO_LONG is not ENAMETOOLONG 36');
end;

procedure TestErrorMessageLengthApi;
var
  LBuf: array[0..127] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(PLATFORM_ERR_INVALID, @LBuf[0], SizeOf(LBuf));
  Check(R > 0, 'known code returns length > 0');
  Check(LBuf[0] <> #0, 'known code writes message');

  R := platform_error_message(PLATFORM_ERR_NOENT, nil, 64);
  Check(R = PLATFORM_ERR_INVALID, 'nil buf is PLATFORM_ERR_INVALID not -1');
  Check(R <> -1, 'nil buf is not bare -1');

  R := platform_error_message(PLATFORM_ERR_NOENT, @LBuf[0], 0);
  Check(R = PLATFORM_ERR_INVALID, 'zero size is PLATFORM_ERR_INVALID');
  Check(R <> -1, 'zero size is not bare -1');
end;

procedure TestArgsHostSourceNoRtl;
var
  LSrc: string;
begin
  LSrc := ReadLower(ResolveSrc('nextpas.core.platform.args.pas'));
  CheckAbsent(LSrc, 'paramcount', 'args must not use ParamCount');
  CheckAbsent(LSrc, 'paramstr', 'args must not use ParamStr');
  CheckAbsent(LSrc, 'sysutils', 'args must not use SysUtils');
  CheckAbsent(LSrc, 'baseunix', 'args must not use BaseUnix');
  CheckContains(LSrc, '/proc/self/cmdline', 'unix args reads host cmdline');
end;

function ResolveSrcRoot: string;
begin
  if DirectoryExists(SRC_ROOT_FROM_TEST) then
    Exit(SRC_ROOT_FROM_TEST);
  if DirectoryExists(SRC_ROOT_FROM_REPO) then
    Exit(SRC_ROOT_FROM_REPO);
  Result := SRC_ROOT_FROM_TEST;
end;

procedure AssertNoBareFpcRtlInSource(const APath, ALabel: string);
var
  LSrc: string;
begin
  Check(FileExists(APath), 'source exists: ' + ALabel);
  LSrc := ReadLower(APath);
  { bare unit names only — nextpas.core.platform.windows.* is legal }
  Check(Pos('sysutils,', LSrc) = 0, ALabel + ' no SysUtils,');
  Check(Pos('sysutils;', LSrc) = 0, ALabel + ' no SysUtils;');
  Check(Pos('baseunix,', LSrc) = 0, ALabel + ' no BaseUnix,');
  Check(Pos('baseunix;', LSrc) = 0, ALabel + ' no BaseUnix;');
  Check(Pos('  windows;', LSrc) = 0, ALabel + ' no bare Windows;');
  Check(Pos('  windows,', LSrc) = 0, ALabel + ' no bare Windows,');
  Check(Pos('  classes;', LSrc) = 0, ALabel + ' no Classes;');
  Check(Pos('  classes,', LSrc) = 0, ALabel + ' no Classes,');
  Check(Pos('  unix;', LSrc) = 0, ALabel + ' no bare Unix;');
  Check(Pos('  unix,', LSrc) = 0, ALabel + ' no bare Unix,');
  Check(Pos('  ctypes;', LSrc) = 0, ALabel + ' no bare ctypes;');
  Check(Pos('  ctypes,', LSrc) = 0, ALabel + ' no bare ctypes,');
end;

procedure TestProductionUnitsNoFpcRtl;
var
  LRoot: string;
  LFiles: TStringArray;
  I: Int32;
  LName: string;
begin
  LRoot := ResolveSrcRoot;
  LFiles := FsGlob(LRoot, 'nextpas.core.platform*.pas');
  Check(Length(LFiles) >= 40, 'expected full platform production unit set');
  for I := 0 to High(LFiles) do
  begin
    LName := ExtractFileName(LFiles[I]);
    AssertNoBareFpcRtlInSource(LFiles[I], LName);
  end;
end;

function ResolveTestPath(const AFromTest, AFromRoot: string): string;
begin
  if FileExists(AFromTest) then
    Exit(AFromTest);
  if FileExists(AFromRoot) then
    Exit(AFromRoot);
  Result := AFromTest;
end;

procedure CheckTestSourceNoFpcRtlUses(const AFromTest, AFromRoot, ALabel: string);
var
  LPath, LSrc: string;
begin
  LPath := ResolveTestPath(AFromTest, AFromRoot);
  Check(FileExists(LPath), 'test source exists: ' + ALabel);
  LSrc := LowerCase(FsReadFileText(LPath));
  { ban uses-clause style references }
  Check(Pos('sysutils,', LSrc) = 0, ALabel + ' must not uses SysUtils,');
  Check(Pos('sysutils;', LSrc) = 0, ALabel + ' must not uses SysUtils;');
  Check(Pos('baseunix,', LSrc) = 0, ALabel + ' must not uses BaseUnix,');
  Check(Pos('baseunix;', LSrc) = 0, ALabel + ' must not uses BaseUnix;');
  Check(Pos('sysutils.', LSrc) = 0, ALabel + ' must not call SysUtils.*');
  Check(Pos('baseunix.', LSrc) = 0, ALabel + ' must not call BaseUnix.*');
end;

procedure TestPlatformTestTreeNoFpcRtlUses;
begin
  { previously offending wine/windows harnesses — must stay clean }
  CheckTestSourceNoFpcRtlUses(
    '../test_platform_linux_modern/test_platform_linux_modern.lpr',
    'core/tests/nextpas.core.platform/test_platform_linux_modern/test_platform_linux_modern.lpr',
    'linux_modern');
  CheckTestSourceNoFpcRtlUses(
    '../../nextpas.core.platform.args/test_platform_args_wine/test_platform_args_wine.lpr',
    'core/tests/nextpas.core.platform.args/test_platform_args_wine/test_platform_args_wine.lpr',
    'args_wine');
  CheckTestSourceNoFpcRtlUses(
    '../../nextpas.core.platform.console/test_platform_console_wine/test_platform_console_wine.lpr',
    'core/tests/nextpas.core.platform.console/test_platform_console_wine/test_platform_console_wine.lpr',
    'console_wine');
  CheckTestSourceNoFpcRtlUses(
    '../../nextpas.core.platform.memory/test_platform_memory_wine/test_platform_memory_wine.lpr',
    'core/tests/nextpas.core.platform.memory/test_platform_memory_wine/test_platform_memory_wine.lpr',
    'memory_wine');
  CheckTestSourceNoFpcRtlUses(
    '../../nextpas.core.platform.pty/test_platform_pty_wine/test_platform_pty_wine.lpr',
    'core/tests/nextpas.core.platform.pty/test_platform_pty_wine/test_platform_pty_wine.lpr',
    'pty_wine');
  CheckTestSourceNoFpcRtlUses(
    '../../nextpas.core.platform.resource/test_platform_resource_wine/test_platform_resource_wine.lpr',
    'core/tests/nextpas.core.platform.resource/test_platform_resource_wine/test_platform_resource_wine.lpr',
    'resource_wine');
  CheckTestSourceNoFpcRtlUses(
    '../../nextpas.core.platform.signal/test_platform_signal_wine/test_platform_signal_wine.lpr',
    'core/tests/nextpas.core.platform.signal/test_platform_signal_wine/test_platform_signal_wine.lpr',
    'signal_wine');
  CheckTestSourceNoFpcRtlUses(
    '../../nextpas.core.platform.signal/test_platform_windows_signal_contract/test_platform_windows_signal_contract.lpr',
    'core/tests/nextpas.core.platform.signal/test_platform_windows_signal_contract/test_platform_windows_signal_contract.lpr',
    'windows_signal_contract');
  CheckTestSourceNoFpcRtlUses(
    '../../nextpas.core.platform.socket/test_platform_socket_windows_real/test_platform_socket_windows_real.lpr',
    'core/tests/nextpas.core.platform.socket/test_platform_socket_windows_real/test_platform_socket_windows_real.lpr',
    'socket_windows_real');
  CheckTestSourceNoFpcRtlUses(
    '../test_platform_io_windows_real/test_platform_io_windows_real.lpr',
    'core/tests/nextpas.core.platform/test_platform_io_windows_real/test_platform_io_windows_real.lpr',
    'io_windows_real');
  CheckTestSourceNoFpcRtlUses(
    '../test_platform_windows_utf16_contract/test_platform_windows_utf16_contract.lpr',
    'core/tests/nextpas.core.platform/test_platform_windows_utf16_contract/test_platform_windows_utf16_contract.lpr',
    'windows_utf16_contract');
  CheckTestSourceNoFpcRtlUses(
    '../test_platform_wine_ci_matrix_contract/test_platform_wine_ci_matrix_contract.lpr',
    'core/tests/nextpas.core.platform/test_platform_wine_ci_matrix_contract/test_platform_wine_ci_matrix_contract.lpr',
    'wine_ci_matrix_contract');
  CheckTestSourceNoFpcRtlUses(
    '../../nextpas.core.platform.watch/test_platform_watch_wine/test_platform_watch_wine.lpr',
    'core/tests/nextpas.core.platform.watch/test_platform_watch_wine/test_platform_watch_wine.lpr',
    'watch_wine');
end;

procedure TestErrorMessageSourceNoBareMinusOne;
var
  LSrc: string;
begin
  LSrc := ReadRaw(ResolveSrc('nextpas.core.platform.error.pas'));
  Check(Pos('Exit(-1)', LSrc) = 0, 'error.pas must not Exit(-1)');
  Check(Pos('Result := -1', LSrc) = 0, 'error.pas must not Result := -1');
  Check(Pos('Result := Int32(AErr)', LSrc) = 0,
    'Windows map must not passthrough raw ERROR_* via Int32(AErr)');
  Check(Pos('PLATFORM_ERR_UNKNOWN', LSrc) > 0, 'error.pas defines PLATFORM_ERR_UNKNOWN');
  Check(Pos('Result := PLATFORM_ERR_UNKNOWN', LSrc) > 0,
    'Windows map else assigns PLATFORM_ERR_UNKNOWN');
end;

procedure TestUnknownErrorPortable;
var
  LBuf: array[0..127] of AnsiChar;
  R: Int32;
begin
  CheckEqual(Int64(-8), Int64(PLATFORM_ERR_UNKNOWN), 'UNKNOWN constant -8');
  R := platform_error_message(PLATFORM_ERR_UNKNOWN, @LBuf[0], SizeOf(LBuf));
  Check(R > 0, 'UNKNOWN has portable message length');
  Check(Pos('unknown', LowerCase(LBuf)) > 0, 'UNKNOWN message mentions unknown');
  Check(platform_error_category(PLATFORM_ERR_UNKNOWN) = ecInternal,
    'UNKNOWN category is ecInternal');
end;

procedure TestPathTooLongDomainNotEnametoolog;
var
  LBuf: array[0..127] of AnsiChar;
  R: Int32;
begin
  CheckEqual(Int64(-7), Int64(PLATFORM_ERR_PATH_TOO_LONG), 'PATH_TOO_LONG stays -7');
  R := platform_error_message(PLATFORM_ERR_PATH_TOO_LONG, @LBuf[0], SizeOf(LBuf));
  Check(R > 0, 'PATH_TOO_LONG message length');
  Check(Pos('path too long', LowerCase(LBuf)) > 0, 'PATH_TOO_LONG message');
  Check(platform_error_category(PLATFORM_ERR_PATH_TOO_LONG) = ecInvalidArgument,
    'PATH_TOO_LONG is ecInvalidArgument');
end;

procedure TestIoCloseIsErrorCodeApi;
var
  LSrc: string;
  LSnippet: string;
  LPos: SizeInt;
begin
  LSrc := ReadRaw(ResolveSrc('nextpas.core.platform.process.pas'));
  { Prefer the Windows implementation: CloseHandle + platform_get_last_error }
  LPos := Pos('function platform_io_close(AFd: PtrInt): Int32;'#10'begin'#10'  if AFd < 0 then'#10'    Exit(0);'#10'  if CloseHandle', LSrc);
  if LPos = 0 then
    LPos := Pos('if CloseHandle(HANDLE(PtrUInt(AFd))) then', LSrc);
  Check(LPos > 0, 'windows platform_io_close CloseHandle path present');
  LSnippet := Copy(LSrc, LPos, 350);
  Check(Pos('Result := -1', LSnippet) = 0,
    'windows platform_io_close must not return bare -1');
  Check(Pos('platform_get_last_error', LSnippet) > 0,
    'windows platform_io_close maps via platform_get_last_error');
end;

procedure TestResourceUsesPlatformErr;
var
  LSrc: string;
  LLimit: TPlatformResourceLimit;
  LBad: TPlatformResourceLimitKind;
  R: Int32;
begin
  LSrc := ReadLower(ResolveSrc('nextpas.core.platform.resource.pas'));
  CheckAbsent(LSrc, 'platform_resource_error_',
    'resource must not invent PLATFORM_RESOURCE_ERROR_*');
  CheckContains(LSrc, 'platform_err_', 'resource docs/code use PLATFORM_ERR_*');

  R := platform_resource_get_limit(prlkOpenFiles, LLimit);
  Check(R = 0, 'resource get_limit succeeds with 0');
  FillChar(LBad, SizeOf(LBad), $FF);
  R := platform_resource_get_limit(LBad, LLimit);
  Check(R = PLATFORM_ERR_INVALID, 'invalid kind is PLATFORM_ERR_INVALID');
  Check(R <> -1, 'invalid kind is not bare -1');
end;

procedure TestArgsRuntime;
var
  LBuf: array[0..511] of AnsiChar;
  R: Int32;
begin
  Check(platform_args_count >= 0, 'args_count >= 0');
  R := platform_args_get(0, @LBuf[0], SizeOf(LBuf));
  Check(R > 0, 'arg0 length > 0');
  Check(LBuf[0] <> #0, 'arg0 non-empty');
  R := platform_args_get(-1, @LBuf[0], SizeOf(LBuf));
  Check(R = PLATFORM_ERR_INVALID, 'bad index is PLATFORM_ERR_INVALID');
  R := platform_args_exe_path(@LBuf[0], SizeOf(LBuf));
  Check(R > 0, 'exe_path length > 0');
end;

function ResolveDocs(const AName: string): string;
begin
  if FileExists('../../../docs/platform/' + AName) then
    Exit('../../../docs/platform/' + AName);
  if FileExists('core/docs/platform/' + AName) then
    Exit('core/docs/platform/' + AName);
  Result := '../../../docs/platform/' + AName;
end;

procedure TestDocsAuthorityPresent;
var
  LPath, LText: string;
begin
  LPath := ResolveDocs('RETURN-SEMANTICS.md');
  Check(FileExists(LPath), 'RETURN-SEMANTICS.md exists');
  LText := LowerCase(FsReadFileText(LPath));
  CheckContains(LText, 'error-code', 'return tiers document error-code');
  CheckContains(LText, 'length', 'return tiers document length');
  CheckContains(LText, 'sentinel', 'return tiers document sentinel');
  CheckContains(LText, 'platform_err_', 'return tiers cite PLATFORM_ERR_*');
  CheckContains(LText, 'paramcount', 'return tiers ban ParamCount');

  LPath := ResolveDocs('ERROR-HANDLING.md');
  LText := LowerCase(FsReadFileText(LPath));
  CheckContains(LText, 'platform_err_invalid', 'ERROR-HANDLING lists INVALID');
  CheckContains(LText, '| `platform_err_invalid` | 22 |',
    'ERROR-HANDLING table row INVALID=22');
  CheckContains(LText, 'there is **no** `platform_err_ok`',
    'ERROR-HANDLING forbids PLATFORM_ERR_OK constant');
  CheckContains(LText, 'platform_err_unknown',
    'ERROR-HANDLING lists PLATFORM_ERR_UNKNOWN');
  CheckContains(LText, '| `platform_err_unknown` | -8 |',
    'ERROR-HANDLING table row UNKNOWN=-8');
  CheckContains(LText, 'never raw',
    'ERROR-HANDLING forbids raw ERROR_* passthrough');
  CheckContains(LText, 'not os `enametoolong`',
    'ERROR-HANDLING documents PATH_TOO_LONG domain rationale');
end;

procedure TestApiReferenceNoPhantomErrors;
var
  LPath, LText: string;
begin
  { API-REFERENCE is in README Authority; it must not invent error names.
    Live table lives in ERROR-HANDLING.md / error.pas. }
  LPath := ResolveDocs('API-REFERENCE.md');
  Check(FileExists(LPath), 'API-REFERENCE.md exists');
  LText := LowerCase(FsReadFileText(LPath));

  CheckAbsent(LText, 'platform_err_ok',
    'API-REFERENCE must not invent PLATFORM_ERR_OK');
  CheckAbsent(LText, 'platform_err_not_found',
    'API-REFERENCE must not invent PLATFORM_ERR_NOT_FOUND');
  CheckAbsent(LText, 'platform_err_exists',
    'API-REFERENCE must not invent PLATFORM_ERR_EXISTS');
  CheckAbsent(LText, 'platform_err_access',
    'API-REFERENCE must not invent PLATFORM_ERR_ACCESS');
  CheckAbsent(LText, 'platform_err_full',
    'API-REFERENCE must not invent PLATFORM_ERR_FULL');
  CheckAbsent(LText, 'platform_err_aborted',
    'API-REFERENCE must not invent PLATFORM_ERR_ABORTED');
  CheckAbsent(LText, 'platform_err_network',
    'API-REFERENCE must not invent PLATFORM_ERR_NETWORK');

  CheckContains(LText, 'platform_err_noent',
    'API-REFERENCE lists live PLATFORM_ERR_NOENT');
  CheckContains(LText, 'platform_err_exist',
    'API-REFERENCE lists live PLATFORM_ERR_EXIST');
  CheckContains(LText, 'platform_err_invalid',
    'API-REFERENCE lists live PLATFORM_ERR_INVALID');
  CheckContains(LText, 'platform_err_unsupported',
    'API-REFERENCE lists live PLATFORM_ERR_UNSUPPORTED');
  CheckContains(LText, 'platform_err_nospc',
    'API-REFERENCE lists live PLATFORM_ERR_NOSPC');
  CheckContains(LText, 'platform_err_unknown',
    'API-REFERENCE lists live PLATFORM_ERR_UNKNOWN');
  CheckContains(LText, 'error-handling.md',
    'API-REFERENCE points to ERROR-HANDLING authority');
end;

procedure TestDualApiDeprecationSignals;
var
  LProc, LRet, LEx: string;
begin
  LProc := LowerCase(ReadRaw(ResolveSrc('nextpas.core.platform.process.pas')));
  Check(Pos('transitional dual-api', LProc) > 0,
    'process.pas marks platform_io_* as transitional dual-API');
  Check(Pos('prefer platform.files', LProc) > 0,
    'process.pas points new code to platform.files / *_ex');

  LRet := LowerCase(FsReadFileText(ResolveDocs('RETURN-SEMANTICS.md')));
  Check(Pos('transitional', LRet) > 0, 'RETURN-SEMANTICS documents transitional io helpers');
  Check(Pos('platform_io_read', LRet) > 0, 'RETURN-SEMANTICS names platform_io_read');
  Check(Pos('dual api', LRet) > 0, 'RETURN-SEMANTICS has Dual API section');
  Check(Pos('whitelist', LRet) > 0, 'RETURN-SEMANTICS documents dual-IO whitelist');
  Check(Pos('platform_io_poll', LRet) > 0, 'RETURN-SEMANTICS allows process.pipe poll');

  LEx := LowerCase(FsReadFileText(ResolveDocs('EXAMPLES.md')));
  { ban uses-clause style SysUtils, allow the ban rule text itself }
  Check(Pos('sysutils,', LEx) = 0, 'EXAMPLES.md must not uses SysUtils,');
  Check(Pos('sysutils;', LEx) = 0, 'EXAMPLES.md must not uses SysUtils;');
  Check(Pos('禁止', LEx) > 0, 'EXAMPLES.md has ban rule text');
  Check(Pos('sysutils', LEx) > 0, 'EXAMPLES.md ban rule names SysUtils');
  Check(Pos('fileio', LEx) = 0, 'EXAMPLES.md must not reference ghost unit fileio');
  Check(Pos('platform_net_', LEx) = 0, 'EXAMPLES.md must not use ghost platform_net_*');
  Check(Pos('platform.files', LEx) > 0, 'EXAMPLES.md uses live platform.files');

  { BEST-PRACTICES must not reintroduce ghosts; point to live files/socket }
  LEx := LowerCase(FsReadFileText(ResolveDocs('BEST-PRACTICES.md')));
  Check(Pos('platform_net_', LEx) = 0, 'BEST-PRACTICES no platform_net_*');
  { ghost type was TPlatformFile alone; live types are TPlatformFileHandle/Stat/... }
  Check(Pos('tplatformfile;', LEx) = 0, 'BEST-PRACTICES no bare TPlatformFile ghost type');
  Check(Pos('platform_invalid_handle', LEx) = 0, 'BEST-PRACTICES no PLATFORM_INVALID_HANDLE ghost');
  Check(Pos('platform_file_open', LEx) > 0, 'BEST-PRACTICES uses live platform_file_open');
  Check(Pos('fomreadonly', LEx) > 0, 'BEST-PRACTICES uses fomReadOnly mode enum');
  Check(Pos('tplatformfilehandle', LEx) > 0, 'BEST-PRACTICES uses live TPlatformFileHandle');
  Check(Pos('platform_socket_create', LEx) > 0, 'BEST-PRACTICES uses live socket create');
end;

procedure TestOutInitOnSpawnSource;
var
  LSrc: string;
begin
  LSrc := ReadRaw(ResolveSrc('nextpas.core.platform.process.pas'));
  { failure paths for spawn / unsupported stubs zero out-params }
  Check(Pos('FillChar(AProc, SizeOf(AProc), 0)', LSrc) > 0,
    'spawn paths FillChar AProc out-param');
  Check(Pos('AReadHandle := -1', LSrc) > 0,
    'pipe create failure/unsupported sets read handle sentinel');
  Check(Pos('AWriteHandle := -1', LSrc) > 0,
    'pipe create failure/unsupported sets write handle sentinel');
end;

procedure TestOutInitFilesAndSocket;
var
  LFiles, LSock: string;
begin
  LFiles := ReadRaw(ResolveSrc('nextpas.core.platform.files.pas'));
  Check(Pos('AHandle.Value := -1', LFiles) > 0,
    'files open_ex initializes AHandle to invalid before work');
  Check(Pos('ABytesRead := 0', LFiles) > 0,
    'files read initializes ABytesRead out-param');
  Check(Pos('ANewPos := -1', LFiles) > 0,
    'files seek initializes ANewPos sentinel before work');
  Check(Pos('FillChar(AStat, SizeOf(AStat), 0)', LFiles) > 0,
    'files stat zero-initializes AStat out-param');
  { unsupported stubs must out-init too (RETURN §13) }
  Check(Pos('AHandle.Value := -1; Result := PLATFORM_ERR_UNSUPPORTED', LFiles) > 0,
    'files open unsupported stub sets AHandle sentinel');

  LSock := ReadRaw(ResolveSrc('nextpas.core.platform.socket.pas'));
  Check(Pos('ASocket.Value := -1', LSock) > 0,
    'socket create unsupported/failure sets socket sentinel');
  Check(Pos('AClient.Value := -1', LSock) > 0,
    'socket accept unsupported stub sets AClient sentinel');
  Check(Pos('ASocket1.Value := -1', LSock) > 0,
    'socket_pair failure/unsupported sets ASocket1 sentinel');
end;

procedure TestContractTableLiveNames;
var
  LContract, LRet: string;
begin
  LContract := LowerCase(FsReadFileText(ResolveDocs('CONTRACT.md')));
  Check(Pos('platform_resource_get_limit', LContract) > 0,
    'CONTRACT names live resource_get_limit');
  Check(Pos('platform_pipe_create', LContract) > 0,
    'CONTRACT names live pipe_create');
  Check(Pos('platform_realtime_ns', LContract) > 0,
    'CONTRACT names live realtime_ns');
  Check(Pos('platform_fs_copy_file', LContract) > 0,
    'CONTRACT names live fs_copy_file');
  Check(Pos('platform_fmt_snprintf', LContract) = 0,
    'CONTRACT has no ghost fmt_snprintf');
  Check(Pos('platform_pipe_open', LContract) = 0,
    'CONTRACT has no ghost pipe_open');
  Check(Pos('platform_wallclock_ns', LContract) = 0,
    'CONTRACT has no ghost wallclock_ns');
  Check(Pos('platform_fs_glob', LContract) = 0,
    'CONTRACT has no ghost fs_glob');

  LRet := LowerCase(FsReadFileText(ResolveDocs('RETURN-SEMANTICS.md')));
  Check(Pos('platform_str_find', LRet) > 0,
    'RETURN documents str_find as index value-sentinel');
end;

procedure TestDlErrorAndLengthContracts;
var
  LDl, LRet: string;
  LBuf: array[0..7] of AnsiChar;
  R: Int32;
begin
  LDl := ReadRaw(ResolveSrc('nextpas.core.platform.dl.pas'));
  Check(Pos('Exit(PLATFORM_ERR_INVALID)', LDl) > 0,
    'dl_error uses PLATFORM_ERR_INVALID for bad buffer');
  Check(Pos('Exit(-1)', LDl) = 0, 'dl.pas has no bare Exit(-1)');

  R := platform_dl_error(nil, 256);
  Check(R = PLATFORM_ERR_INVALID, 'dl_error nil buffer is PLATFORM_ERR_INVALID');
  R := platform_dl_error(@LBuf[0], 0);
  Check(R = PLATFORM_ERR_INVALID, 'dl_error zero size is PLATFORM_ERR_INVALID');

  LRet := LowerCase(FsReadFileText(ResolveDocs('RETURN-SEMANTICS.md')));
  Check(Pos('platform_dl_error', LRet) > 0, 'RETURN documents dl_error length tier');
  Check(Pos('out-init', LRet) > 0, 'RETURN documents out-init rule');
end;

procedure TestErrorCodeApisNoBareMinusOneStub;
var
  LFiles, LSock, LErr: string;
begin
  { focused error-code modules: no Result := -1 stubs }
  LFiles := ReadRaw(ResolveSrc('nextpas.core.platform.files.pas'));
  Check(Pos('Result := -1', LFiles) = 0, 'files.pas no Result := -1');
  LSock := ReadRaw(ResolveSrc('nextpas.core.platform.socket.pas'));
  Check(Pos('Result := -1', LSock) = 0, 'socket.pas no Result := -1');
  LErr := ReadRaw(ResolveSrc('nextpas.core.platform.error.pas'));
  Check(Pos('Result := -1', LErr) = 0, 'error.pas no Result := -1');
end;

procedure TestShortAliasAndParseContracts;
var
  LFs, LFmt, LRet: string;
  LVal: Int64;
  R: Int32;
begin
  LFs := ReadRaw(ResolveSrc('nextpas.core.platform.fs.pas'));
  Check(Pos('PLATFORM_FS_SHORT_READ_ERROR = PLATFORM_ERR_IO', LFs) > 0,
    'SHORT_READ aliases PLATFORM_ERR_IO');
  Check(Pos('PLATFORM_FS_SHORT_WRITE_ERROR = PLATFORM_ERR_IO', LFs) > 0,
    'SHORT_WRITE aliases PLATFORM_ERR_IO');
  Check(Pos('PLATFORM_FS_SHORT_READ_ERROR = -6', LFs) = 0,
    'SHORT_READ no longer parallel -6');
  Check(Pos('PLATFORM_FS_SHORT_WRITE_ERROR = -5', LFs) = 0,
    'SHORT_WRITE no longer parallel -5');

  LFmt := ReadRaw(ResolveSrc('nextpas.core.platform.fmt.pas'));
  Check(Pos('function platform_parse_int', LFmt) > 0, 'parse_int present');
  { runtime: parse failure is INVALID not bare -1 }
  R := platform_parse_int(PAnsiChar(''), 0, LVal);
  Check(R = PLATFORM_ERR_INVALID, 'parse empty is PLATFORM_ERR_INVALID');
  Check(R <> -1, 'parse empty is not bare -1');

  LRet := LowerCase(FsReadFileText(ResolveDocs('RETURN-SEMANTICS.md')));
  Check(Pos('platform_parse_', LRet) > 0, 'RETURN documents parse error-code');
  Check(Pos('platform_err_io', LRet) > 0, 'RETURN documents SHORT→IO');
end;

procedure TestGetpidIsSentinelApi;
var
  LPid: Int32;
begin
  LPid := platform_getpid;
  Check(LPid > 0, 'getpid returns positive pid on host');
end;

procedure TestQuickstartLivePatterns;
var
  LQ: string;
begin
  LQ := LowerCase(FsReadFileText(ResolveDocs('QUICKSTART.md')));
  Check(Pos('platform_file_open', LQ) > 0, 'QUICKSTART uses platform_file_open');
  Check(Pos('fomreadonly', LQ) > 0, 'QUICKSTART uses fomReadOnly');
  Check(Pos('platform_file_read', LQ) > 0, 'QUICKSTART uses platform_file_read');
  Check(Pos('platform_file_close', LQ) > 0, 'QUICKSTART uses platform_file_close');
  Check(Pos('platform_err_', LQ) > 0, 'QUICKSTART mentions PLATFORM_ERR_*');
  Check(Pos('platform_net_', LQ) = 0, 'QUICKSTART has no ghost platform_net_*');
  Check(Pos('fileio', LQ) = 0, 'QUICKSTART has no ghost fileio');
end;

procedure TestLastOsErrorSideChannel;
var
  LSrc, LErrDoc, LRet, LApi: string;
  LOs, LMapped: Int32;
begin
  LSrc := ReadRaw(ResolveSrc('nextpas.core.platform.error.pas'));
  Check(Pos('function platform_get_last_os_error: Int32;', LSrc) > 0,
    'error.pas declares platform_get_last_os_error');

  LOs := platform_get_last_os_error;
  LMapped := platform_get_last_error;
  Check(LOs >= 0, 'Linux/raw os error is non-negative host code');
  { both callable; values need not match after mapping on Windows }
  Check(LMapped >= -8, 'get_last_error returns portable or host-local code');

  LErrDoc := LowerCase(FsReadFileText(ResolveDocs('ERROR-HANDLING.md')));
  Check(Pos('platform_get_last_os_error', LErrDoc) > 0,
    'ERROR-HANDLING documents platform_get_last_os_error');
  Check(Pos('won''t do this wave', LErrDoc) = 0,
    'ERROR-HANDLING no longer says Won''t do this wave for raw OS');

  LRet := LowerCase(FsReadFileText(ResolveDocs('RETURN-SEMANTICS.md')));
  Check(Pos('platform_get_last_os_error', LRet) > 0,
    'RETURN-SEMANTICS documents raw OS side-channel');

  LApi := LowerCase(FsReadFileText(ResolveDocs('API-REFERENCE.md')));
  Check(Pos('platform_get_last_os_error', LApi) > 0,
    'API-REFERENCE lists platform_get_last_os_error');
end;

procedure TestDualIoConsumerWhitelist;
var
  LRoot: string;
  LFiles: TStringArray;
  I: Int32;
  LName, LSrc: string;
  LPipe: string;
begin
  LRoot := ResolveSrcRoot;
  LFiles := FsGlob(LRoot, 'nextpas.core.*.pas');
  Check(Length(LFiles) > 50, 'expected broad core/src scan');
  for I := 0 to High(LFiles) do
  begin
    LName := ExtractFileName(LFiles[I]);
    { dual-IO owner may define and use all symbols }
    if LName = 'nextpas.core.platform.process.pas' then
      Continue;
    LSrc := LowerCase(FsReadFileText(LFiles[I]));
    if LName = 'nextpas.core.process.pipe.pas' then
    begin
      Check(Pos('platform_io_read(', LSrc) = 0,
        'process.pipe must not call platform_io_read');
      Check(Pos('platform_io_write(', LSrc) = 0,
        'process.pipe must not call platform_io_write');
      Check(Pos('platform_io_close(', LSrc) = 0,
        'process.pipe must not call platform_io_close');
      Check(Pos('platform_io_poll(', LSrc) > 0,
        'process.pipe may still call platform_io_poll for drain');
      Check(Pos('platform_file_read', LSrc) > 0,
        'process.pipe routes read via platform.files');
      Continue;
    end;
    Check(Pos('platform_io_read(', LSrc) = 0,
      LName + ' must not call platform_io_read');
    Check(Pos('platform_io_write(', LSrc) = 0,
      LName + ' must not call platform_io_write');
    Check(Pos('platform_io_poll(', LSrc) = 0,
      LName + ' must not call platform_io_poll');
  end;

  LPipe := LowerCase(FsReadFileText(ResolveDocs('residual-roadmap.md')));
  Check(Pos('platform_io_poll', LPipe) > 0,
    'residual-roadmap documents dual-IO whitelist');
  Check(Pos('lt4', LPipe) > 0, 'residual-roadmap registers LT4');
end;

procedure TestResidualRoadmapFreeze;
var
  LRoad, LGoal, LReadme, LUsab: string;
begin
  LRoad := LowerCase(FsReadFileText(ResolveDocs('residual-roadmap.md')));
  Check(Pos('8.21', LRoad) > 0, 'residual-roadmap freezes 8.21');
  Check(Pos('lt0', LRoad) > 0, 'residual-roadmap has LT0');
  Check(Pos('lt3', LRoad) > 0, 'residual-roadmap has LT3');
  Check(Pos('maintenance', LRoad) > 0, 'residual-roadmap maintenance stance');

  LGoal := LowerCase(FsReadFileText(ResolveDocs('goal-tree.md')));
  Check(Pos('residual-roadmap', LGoal) > 0, 'goal-tree points residual-roadmap');
  Check(Pos('maintenance baseline 8.21', LGoal) > 0,
    'goal-tree states maintenance baseline 8.21');

  LReadme := LowerCase(FsReadFileText(ResolveDocs('README.md')));
  Check(Pos('residual-roadmap.md', LReadme) > 0, 'README links residual-roadmap');
  Check(Pos('test_platform_docs_live_patterns', LReadme) > 0,
    'README lists docs live patterns gate');

  LUsab := LowerCase(FsReadFileText(ResolveDocs('USABILITY-ASSESSMENT.md')));
  Check(Pos('maintenance baseline', LUsab) > 0, 'USABILITY maintenance banner');
  Check(Pos('8.21', LUsab) > 0, 'USABILITY banner score 8.21');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.return_semantics_contract');
  T.Test('PLATFORM_ERR constants match live authority', @TestErrorConstantsMatchDoc);
  T.Test('error_message is length API (no bare -1)', @TestErrorMessageLengthApi);
  T.Test('args host source no FPC RTL params', @TestArgsHostSourceNoRtl);
  T.Test('production units no FPC SysUtils/BaseUnix/Windows/Classes', @TestProductionUnitsNoFpcRtl);
  T.Test('platform test tree no uses SysUtils/BaseUnix', @TestPlatformTestTreeNoFpcRtlUses);
  T.Test('error.pas source has no bare -1 failure exits', @TestErrorMessageSourceNoBareMinusOne);
  T.Test('UNKNOWN portable code + message + category', @TestUnknownErrorPortable);
  T.Test('PATH_TOO_LONG stays domain -7', @TestPathTooLongDomainNotEnametoolog);
  T.Test('dual-API deprecation signals + EXAMPLES no SysUtils', @TestDualApiDeprecationSignals);
  T.Test('out-init on spawn/pipe source contracts', @TestOutInitOnSpawnSource);
  T.Test('out-init files open + socket create', @TestOutInitFilesAndSocket);
  T.Test('CONTRACT table live API names + str_find', @TestContractTableLiveNames);
  T.Test('dl_error INVALID + length contracts', @TestDlErrorAndLengthContracts);
  T.Test('error-code modules no bare Result := -1', @TestErrorCodeApisNoBareMinusOneStub);
  T.Test('SHORT alias IO + parse INVALID contracts', @TestShortAliasAndParseContracts);
  T.Test('windows io_close is error-code API', @TestIoCloseIsErrorCodeApi);
  T.Test('resource uses PLATFORM_ERR_* family', @TestResourceUsesPlatformErr);
  T.Test('args runtime host cmdline', @TestArgsRuntime);
  T.Test('docs authority present', @TestDocsAuthorityPresent);
  T.Test('API-REFERENCE has no phantom PLATFORM_ERR_*', @TestApiReferenceNoPhantomErrors);
  T.Test('getpid is value/sentinel api', @TestGetpidIsSentinelApi);
  T.Test('QUICKSTART live API patterns', @TestQuickstartLivePatterns);
  T.Test('last_os_error side-channel + docs', @TestLastOsErrorSideChannel);
  T.Test('dual-IO production consumer whitelist', @TestDualIoConsumerWhitelist);
  T.Test('residual roadmap freeze', @TestResidualRoadmapFreeze);
  if not T.Run then Halt(1);
end.
