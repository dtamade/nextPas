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

procedure TestDocsAuthorityPresent;
var
  LPath, LText: string;
begin
  if FileExists('../../../docs/platform/RETURN-SEMANTICS.md') then
    LPath := '../../../docs/platform/RETURN-SEMANTICS.md'
  else
    LPath := 'core/docs/platform/RETURN-SEMANTICS.md';
  Check(FileExists(LPath), 'RETURN-SEMANTICS.md exists');
  LText := LowerCase(FsReadFileText(LPath));
  CheckContains(LText, 'error-code', 'return tiers document error-code');
  CheckContains(LText, 'length', 'return tiers document length');
  CheckContains(LText, 'sentinel', 'return tiers document sentinel');
  CheckContains(LText, 'platform_err_', 'return tiers cite PLATFORM_ERR_*');
  CheckContains(LText, 'paramcount', 'return tiers ban ParamCount');

  if FileExists('../../../docs/platform/ERROR-HANDLING.md') then
    LPath := '../../../docs/platform/ERROR-HANDLING.md'
  else
    LPath := 'core/docs/platform/ERROR-HANDLING.md';
  LText := LowerCase(FsReadFileText(LPath));
  CheckContains(LText, 'platform_err_invalid', 'ERROR-HANDLING lists INVALID');
  CheckContains(LText, '| `platform_err_invalid` | 22 |',
    'ERROR-HANDLING table row INVALID=22');
  CheckContains(LText, 'there is **no** `platform_err_ok`',
    'ERROR-HANDLING forbids PLATFORM_ERR_OK constant');
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
  T.Test('error.pas source has no bare -1 failure exits', @TestErrorMessageSourceNoBareMinusOne);
  T.Test('windows io_close is error-code API', @TestIoCloseIsErrorCodeApi);
  T.Test('resource uses PLATFORM_ERR_* family', @TestResourceUsesPlatformErr);
  T.Test('args runtime host cmdline', @TestArgsRuntime);
  T.Test('docs authority present', @TestDocsAuthorityPresent);
  T.Test('getpid is value/sentinel api', @TestGetpidIsSentinelApi);
  if not T.Run then Halt(1);
end.
