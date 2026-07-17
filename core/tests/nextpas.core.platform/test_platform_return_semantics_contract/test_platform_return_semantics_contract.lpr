program test_platform_return_semantics_contract;

{ Source + runtime contracts for platform return tiers, PLATFORM_ERR_* namespace,
  FPC RTL isolation on production platform units, and args host-FFI ownership. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.platform.error,
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
  CheckEqual(Int64(-7), Int64(PLATFORM_ERR_PATH_TOO_LONG), 'PATH_TOO_LONG=-7');
  { bare -1 is not a portable PLATFORM_ERR_* value }
  Check(PLATFORM_ERR_INVALID <> -1, 'INVALID is not bare -1');
  Check(PLATFORM_ERR_UNSUPPORTED <> -1, 'UNSUPPORTED is not bare -1');
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

procedure TestProductionUnitsNoFpcRtl;
var
  LNames: array[0..8] of string;
  I: Int32;
  LSrc, LPath: string;
begin
  LNames[0] := 'nextpas.core.platform.args.pas';
  LNames[1] := 'nextpas.core.platform.error.pas';
  LNames[2] := 'nextpas.core.platform.resource.pas';
  LNames[3] := 'nextpas.core.platform.process.pas';
  LNames[4] := 'nextpas.core.platform.files.pas';
  LNames[5] := 'nextpas.core.platform.fs.pas';
  LNames[6] := 'nextpas.core.platform.io.pas';
  LNames[7] := 'nextpas.core.platform.env.pas';
  LNames[8] := 'nextpas.core.platform.console.pas';
  for I := Low(LNames) to High(LNames) do
  begin
    LPath := ResolveSrc(LNames[I]);
    Check(FileExists(LPath), 'source exists: ' + LNames[I]);
    LSrc := ReadLower(LPath);
    CheckAbsent(LSrc, 'sysutils', LNames[I] + ' must not reference SysUtils');
    CheckAbsent(LSrc, 'baseunix', LNames[I] + ' must not reference BaseUnix');
    CheckAbsent(LSrc, '  windows;', LNames[I] + ' no FPC Windows unit');
    CheckAbsent(LSrc, '  windows,', LNames[I] + ' no FPC Windows unit');
    CheckAbsent(LSrc, '  classes;', LNames[I] + ' no Classes');
    CheckAbsent(LSrc, '  classes,', LNames[I] + ' no Classes');
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
  CheckContains(LText, 'error-handling.md',
    'API-REFERENCE points to ERROR-HANDLING authority');
end;

procedure TestGetpidIsSentinelApi;
var
  LPid: Int32;
begin
  LPid := platform_getpid;
  Check(LPid > 0, 'getpid returns positive pid on host');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.return_semantics_contract');
  T.Test('PLATFORM_ERR constants match live authority', @TestErrorConstantsMatchDoc);
  T.Test('error_message is length API (no bare -1)', @TestErrorMessageLengthApi);
  T.Test('args host source no FPC RTL params', @TestArgsHostSourceNoRtl);
  T.Test('production units no FPC SysUtils/BaseUnix/Windows/Classes', @TestProductionUnitsNoFpcRtl);
  T.Test('platform test tree no uses SysUtils/BaseUnix', @TestPlatformTestTreeNoFpcRtlUses);
  T.Test('error.pas source has no bare -1 failure exits', @TestErrorMessageSourceNoBareMinusOne);
  T.Test('windows io_close is error-code API', @TestIoCloseIsErrorCodeApi);
  T.Test('resource uses PLATFORM_ERR_* family', @TestResourceUsesPlatformErr);
  T.Test('args runtime host cmdline', @TestArgsRuntime);
  T.Test('docs authority present', @TestDocsAuthorityPresent);
  T.Test('API-REFERENCE has no phantom PLATFORM_ERR_*', @TestApiReferenceNoPhantomErrors);
  T.Test('getpid is value/sentinel api', @TestGetpidIsSentinelApi);
  if not T.Run then Halt(1);
end.
