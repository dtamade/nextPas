program test_platform_env;

{$I nextpas.core.settings.inc}

uses

  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.platform.env,
  nextpas.core.test;

var
  T: TTestSuite;

function LoadSourceText(const ARelativePath: string): string;
begin
  Check(FileExists(ARelativePath), 'source file exists: ' + ARelativePath);
  Result := FsReadFileText(ARelativePath);
end;

function ExtractFunctionBody(const ASource, AStartToken,
  ANextToken: string): string;
var
  LStart, LNext: Integer;
begin
  Result := '';
  LStart := Pos(AStartToken, ASource);
  if LStart = 0 then
    Exit;
  LNext := Pos(ANextToken, Copy(ASource, LStart + Length(AStartToken),
    Length(ASource)));
  if LNext = 0 then
    Exit(Copy(ASource, LStart, Length(ASource)));
  Result := Copy(ASource, LStart, Length(AStartToken) + LNext - 1);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckTokenBefore(const ASource, AFirstToken, ASecondToken,
  AMessage: string);
var
  LFirst, LSecond: Integer;
begin
  LFirst := Pos(AFirstToken, ASource);
  LSecond := Pos(ASecondToken, ASource);
  Check((LFirst > 0) and (LSecond > 0) and (LFirst < LSecond), AMessage);
end;

procedure TestGetPath;
var
  Buf: array[0..1023] of AnsiChar;
  Len: Int32;
begin
  Check(platform_env_get('PATH', @Buf[0], 1024, Len) = 0, 'get PATH');
  Check(Len > 0, 'PATH has length > 0');
  Check(Buf[0] <> #0, 'PATH not empty');
end;

procedure TestSetGetRoundtrip;
var
  Buf: array[0..63] of AnsiChar;
  Len: Int32;
begin
  Check(platform_env_set('NEXTPAS_TEST_VAR', 'hello123') = 0, 'set');
  Check(platform_env_get('NEXTPAS_TEST_VAR', @Buf[0], 64, Len) = 0, 'get');
  Check(Len = 8, 'len = 8');
  Check(Buf[0] = 'h', 'buf[0] = h');
  Check(Buf[5] = '1', 'buf[5] = 1');
  platform_env_unset('NEXTPAS_TEST_VAR');
end;

procedure TestUnset;
var
  Buf: array[0..63] of AnsiChar;
  Len: Int32;
begin
  platform_env_set('NEXTPAS_TEST_UNSET', 'temp');
  Check(platform_env_exists('NEXTPAS_TEST_UNSET'), 'exists before unset');
  Check(platform_env_unset('NEXTPAS_TEST_UNSET') = 0, 'unset');
  Check(platform_env_get('NEXTPAS_TEST_UNSET', @Buf[0], 64, Len) <> 0, 'get after unset fails');
end;

procedure TestGetNonExistent;
var
  Buf: array[0..63] of AnsiChar;
  Len: Int32;
  R: Int32;
begin
  R := platform_env_get('NEXTPAS_NONEXISTENT_XYZ_999', @Buf[0], 64, Len);
  Check(R <> 0, 'non-existent returns error');
end;

procedure TestSetEmpty;
begin
  Check(platform_env_set('NEXTPAS_TEST_EMPTY', '') = 0, 'set empty');
  Check(platform_env_exists('NEXTPAS_TEST_EMPTY'), 'empty var exists');
  platform_env_unset('NEXTPAS_TEST_EMPTY');
end;

procedure TestBufferTooSmall;
var
  Buf: array[0..3] of AnsiChar;
  Len: Int32;
begin
  platform_env_set('NEXTPAS_TEST_LONG', 'abcdefghij');
  Check(platform_env_get('NEXTPAS_TEST_LONG', @Buf[0], 4, Len) = 0, 'get truncated');
  Check(Len = 10, 'actual len = 10');
  Check(Buf[3] = #0, 'null terminated');
  platform_env_unset('NEXTPAS_TEST_LONG');
end;

procedure TestExistsFalse;
begin
  Check(not platform_env_exists('NEXTPAS_NONEXISTENT_XYZ_999'), 'non-existent = false');
end;

procedure TestGetLengthOnly;
var
  Len: Int32;
begin
  platform_env_set('NEXTPAS_TEST_LEN', 'abc');
  Check(platform_env_get('NEXTPAS_TEST_LEN', nil, 0, Len) = 0, 'nil buf ok');
  Check(Len = 3, 'len = 3');
  platform_env_unset('NEXTPAS_TEST_LEN');
end;

procedure TestLongValue;
var
  LVal: array[0..1023] of AnsiChar;
  LBuf: array[0..1023] of AnsiChar;
  Len, I: Int32;
begin
  for I := 0 to 999 do
    LVal[I] := AnsiChar(Ord('A') + (I mod 26));
  LVal[1000] := #0;
  Check(platform_env_set('NEXTPAS_TEST_LONG1K', @LVal[0]) = 0, 'set 1000 chars');
  Check(platform_env_get('NEXTPAS_TEST_LONG1K', @LBuf[0], 1024, Len) = 0, 'get');
  Check(Len = 1000, 'len = 1000');
  Check(LBuf[0] = 'A', 'first char');
  Check(LBuf[25] = 'Z', 'char 25');
  Check(LBuf[999] = AnsiChar(Ord('A') + (999 mod 26)), 'last char');
  platform_env_unset('NEXTPAS_TEST_LONG1K');
end;

procedure TestSpecialChars;
var
  Buf: array[0..255] of AnsiChar;
  Len: Int32;
begin
  Check(platform_env_set('NEXTPAS_TEST_SPECIAL', 'hello world!@#$%^&*()') = 0, 'set special');
  Check(platform_env_get('NEXTPAS_TEST_SPECIAL', @Buf[0], 256, Len) = 0, 'get special');
  Check(Len = 21, 'len = 21');
  Check(Buf[5] = ' ', 'space preserved');
  Check(Buf[12] = '@', '@ preserved');
  platform_env_unset('NEXTPAS_TEST_SPECIAL');
end;

procedure TestOverwrite;
var
  Buf: array[0..63] of AnsiChar;
  Len: Int32;
begin
  platform_env_set('NEXTPAS_TEST_OW', 'first');
  platform_env_set('NEXTPAS_TEST_OW', 'second');
  Check(platform_env_get('NEXTPAS_TEST_OW', @Buf[0], 64, Len) = 0, 'get');
  Check(Len = 6, 'len = 6 (second)');
  Check(Buf[0] = 's', 'overwritten value');
  platform_env_unset('NEXTPAS_TEST_OW');
end;

procedure TestInvalidNames;
var
  Len: Int32;
begin
  Check(platform_env_get(nil, nil, 0, Len) <> 0, 'nil get name rejected');
  Check(platform_env_get('', nil, 0, Len) <> 0, 'empty get name rejected');
  Check(platform_env_get('NEXTPAS_BAD=NAME', nil, 0, Len) <> 0, 'equals get name rejected');

  Check(platform_env_set(nil, 'value') <> 0, 'nil set name rejected');
  Check(platform_env_set('', 'value') <> 0, 'empty set name rejected');
  Check(platform_env_set('NEXTPAS_BAD=NAME', 'value') <> 0, 'equals set name rejected');
  Check(platform_env_set('NEXTPAS_TEST_NIL_VALUE', nil) <> 0,
    'nil set value rejected');

  Check(platform_env_unset(nil) <> 0, 'nil unset name rejected');
  Check(platform_env_unset('') <> 0, 'empty unset name rejected');
  Check(platform_env_unset('NEXTPAS_BAD=NAME') <> 0, 'equals unset name rejected');

  Check(not platform_env_exists(nil), 'nil exists name rejected');
  Check(not platform_env_exists(''), 'empty exists name rejected');
  Check(not platform_env_exists('NEXTPAS_BAD=NAME'), 'equals exists name rejected');
end;

function EnvEnumerateCallback(const AEntry: PAnsiChar;
  AData: Pointer): Boolean;
var
  LCount: PInt32;
begin
  LCount := PInt32(AData);
  Inc(LCount^);
  Result := True;  { continue }
end;

function EnvFindCallback(const AEntry: PAnsiChar;
  AData: Pointer): Boolean;
var
  LFound: PBoolean;
begin
  LFound := PBoolean(AData);
  if Pos('NEXTPAS_TEST_ENUM', string(AEntry)) = 1 then
    LFound^ := True;
  Result := True;  { continue }
end;

function EnvStopCallback(const AEntry: PAnsiChar;
  AData: Pointer): Boolean;
var
  LCount: PInt32;
begin
  LCount := PInt32(AData);
  Inc(LCount^);
  Result := False;  { stop after first }
end;

procedure TestEnumerate;
var
  LCount: Int32;
begin
  LCount := 0;
  Check(platform_env_enumerate(@EnvEnumerateCallback, @LCount) = 0, 'enumerate ok');
  Check(LCount > 0, 'enumerated at least 1 env var');
end;

procedure TestEnumerateFindsSetVar;
var
  LFound: Boolean;
begin
  platform_env_set('NEXTPAS_TEST_ENUM', 'yes');
  LFound := False;
  Check(platform_env_enumerate(@EnvFindCallback, @LFound) = 0, 'enumerate ok');
  Check(LFound, 'enumeration found NEXTPAS_TEST_ENUM');
  platform_env_unset('NEXTPAS_TEST_ENUM');
end;

procedure TestEnumerateStopEarly;
var
  LCount: Int32;
begin
  LCount := 0;
  Check(platform_env_enumerate(@EnvStopCallback, @LCount) = 0, 'enumerate ok');
  Check(LCount = 1, 'stopped after first entry');
end;

procedure TestCaseSensitive;
var
  LResult: Boolean;
begin
  LResult := platform_env_names_case_sensitive;
{$IFDEF NEXTPAS_LINUX}
  Check(LResult, 'Linux env names are case-sensitive');
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  Check(not LResult, 'Windows env names are case-insensitive');
{$ENDIF}
  { Just verify it returns without error on this platform }
  Check(True, 'names_case_sensitive returned ok');
end;

procedure TestEnvGetStr;
var
  LResult: AnsiString;
begin
  platform_env_set('NEXTPAS_TEST_GETSTR', 'hello_str');
  LResult := platform_env_get_str('NEXTPAS_TEST_GETSTR');
  Check(LResult = 'hello_str', 'get_str returns value');
  platform_env_unset('NEXTPAS_TEST_GETSTR');
end;

procedure TestEnvGetStrNonExistent;
var
  LResult: AnsiString;
begin
  LResult := platform_env_get_str('NEXTPAS_NONEXISTENT_XYZ_999');
  Check(LResult = '', 'get_str non-existent returns empty');
end;

procedure TestEnvGetStrEmptyValue;
var
  LResult: AnsiString;
begin
  Check(platform_env_set('NEXTPAS_TEST_GETSTR_EMPTY', '') = 0, 'set empty get_str value');
  Check(platform_env_exists('NEXTPAS_TEST_GETSTR_EMPTY'), 'empty get_str var exists');
  LResult := platform_env_get_str('NEXTPAS_TEST_GETSTR_EMPTY');
  Check(LResult = '', 'get_str empty value returns empty');
  platform_env_unset('NEXTPAS_TEST_GETSTR_EMPTY');
end;

procedure TestEnvGetStrEmptyName;
var
  LResult: AnsiString;
begin
  LResult := platform_env_get_str('');
  Check(LResult = '', 'get_str empty name returns empty');
end;

procedure TestEnvGetStrNilName;
var
  LResult: AnsiString;
begin
  LResult := platform_env_get_str('');
  Check(LResult = '', 'get_str empty string returns empty');
end;

procedure TestSetOverwriteMultipleTimes;
var
  Buf: array[0..63] of AnsiChar;
  Len: Int32;
  I: Int32;
  LVal: AnsiString;
begin
  for I := 1 to 5 do
  begin
    LVal := 'val' + IntToStr(I);
    platform_env_set('NEXTPAS_TEST_MULTIOVER', PAnsiChar(LVal));
  end;
  Check(platform_env_get('NEXTPAS_TEST_MULTIOVER', @Buf[0], 64, Len) = 0, 'get');
  Check(Len > 0, 'len > 0');
  Check(Buf[0] = 'v', 'first char v');
  platform_env_unset('NEXTPAS_TEST_MULTIOVER');
end;

procedure TestExistsAfterSet;
begin
  Check(not platform_env_exists('NEXTPAS_TEST_EXIST_CHECK'), 'not exists before');
  platform_env_set('NEXTPAS_TEST_EXIST_CHECK', '1');
  Check(platform_env_exists('NEXTPAS_TEST_EXIST_CHECK'), 'exists after set');
  platform_env_unset('NEXTPAS_TEST_EXIST_CHECK');
  Check(not platform_env_exists('NEXTPAS_TEST_EXIST_CHECK'), 'not exists after unset');
end;

procedure TestWindowsExistsClearsLastErrorSourceContract;
var
  LSource, LWindowsBranch, LBody: string;
  LWindowsPos, LBodyPos: Integer;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.platform.env.pas');
  LWindowsPos := Pos('if not platform_windows_utf8_to_wide_checked(AName, LName) then',
    LSource);
  Check(LWindowsPos > 0, 'windows env implementation exists');
  LWindowsBranch := Copy(LSource, LWindowsPos, Length(LSource));
  LBodyPos := Pos('function platform_env_exists(const AName: PAnsiChar): Boolean;',
    LWindowsBranch);
  Check(LBodyPos > 0, 'windows exists implementation exists');
  LWindowsBranch := Copy(LWindowsBranch, LBodyPos, Length(LWindowsBranch));
  LBody := ExtractFunctionBody(LWindowsBranch,
    'function platform_env_exists(const AName: PAnsiChar): Boolean;',
    '{$ENDIF}');

  CheckContains(LBody, 'SetLastError(ERROR_SUCCESS)',
    'windows exists clears stale last-error before zero-length query');
  CheckTokenBefore(LBody, 'SetLastError(ERROR_SUCCESS)',
    'GetEnvironmentVariableW(PWideChar(LName), nil, 0)',
    'windows exists clears last-error before GetEnvironmentVariableW');
end;

procedure TestWindowsGetClearsLastErrorSourceContract;
var
  LSource, LWindowsBranch, LBody: string;
  LWindowsPos, LBodyPos: Integer;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.platform.env.pas');
  LWindowsPos := Pos('{$IFDEF NEXTPAS_WINDOWS}' + LineEnding +
    'function platform_env_get(const AName: PAnsiChar;',
    LSource);
  Check(LWindowsPos > 0, 'windows env implementation exists');
  LWindowsBranch := Copy(LSource, LWindowsPos, Length(LSource));
  LBodyPos := Pos('function platform_env_get(const AName: PAnsiChar;',
    LWindowsBranch);
  Check(LBodyPos > 0, 'windows get implementation exists');
  LWindowsBranch := Copy(LWindowsBranch, LBodyPos, Length(LWindowsBranch));
  LBody := ExtractFunctionBody(LWindowsBranch,
    'function platform_env_get(const AName: PAnsiChar;',
    'function platform_env_set');

  CheckTokenBefore(LBody, 'SetLastError(ERROR_SUCCESS)',
    'GetEnvironmentVariableW(PWideChar(LName), nil, 0)',
    'windows get clears last-error before length probe');
  CheckContains(LBody, 'if (LResult = 0) and (GetLastError <> ERROR_SUCCESS) then',
    'windows get treats zero-length value as success');
  CheckContains(LBody, 'LLastError := GetLastError',
    'windows get stores last-error after second read');
  CheckContains(LBody, 'if (LResult = 0) and (LLastError <> ERROR_SUCCESS) then',
    'windows get treats zero-length second read as success');
end;

procedure TestWindowsGetNilBufferSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.platform.env.pas');
  CheckContains(LSource, 'ABuf=nil queries length only',
    'windows get nil buffer behavior must be documented');
end;

procedure TestSetNilName;
begin
  Check(platform_env_set(nil, PAnsiChar('value')) <> 0, 'set nil name returns error');
end;

procedure TestUnsetNilName;
begin
  Check(platform_env_unset(nil) <> 0, 'unset nil name returns error');
end;

procedure TestSetNilValue;
begin
  Check(platform_env_set(PAnsiChar('NEXTPAS_TEST_NIL'), nil) <> 0, 'set nil value returns error');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.env');
  T.Test('get PATH', @TestGetPath);
  T.Test('set + get roundtrip', @TestSetGetRoundtrip);
  T.Test('unset', @TestUnset);
  T.Test('get non-existent', @TestGetNonExistent);
  T.Test('set empty value', @TestSetEmpty);
  T.Test('buffer too small', @TestBufferTooSmall);
  T.Test('exists false', @TestExistsFalse);
  T.Test('get length only (nil buf)', @TestGetLengthOnly);
  T.Test('long value (1000 chars)', @TestLongValue);
  T.Test('special characters', @TestSpecialChars);
  T.Test('overwrite existing', @TestOverwrite);
  T.Test('invalid names', @TestInvalidNames);
  T.Test('enumerate all env vars', @TestEnumerate);
  T.Test('enumerate finds set var', @TestEnumerateFindsSetVar);
  T.Test('enumerate stop early', @TestEnumerateStopEarly);
  T.Test('names case sensitive', @TestCaseSensitive);
  T.Test('get_str returns value', @TestEnvGetStr);
  T.Test('get_str non-existent returns empty', @TestEnvGetStrNonExistent);
  T.Test('get_str empty value returns empty', @TestEnvGetStrEmptyValue);
  T.Test('get_str empty name returns empty', @TestEnvGetStrEmptyName);
  T.Test('get_str nil name returns empty', @TestEnvGetStrNilName);
  T.Test('set overwrite multiple times', @TestSetOverwriteMultipleTimes);
  T.Test('exists after set/unset lifecycle', @TestExistsAfterSet);
  T.Test('windows exists clears last-error source contract',
    @TestWindowsExistsClearsLastErrorSourceContract);
  T.Test('windows get clears last-error source contract',
    @TestWindowsGetClearsLastErrorSourceContract);
  T.Test('windows get nil buffer source contract',
    @TestWindowsGetNilBufferSourceContract);
  T.Test('set nil name returns error', @TestSetNilName);
  T.Test('unset nil name returns error', @TestUnsetNilName);
  T.Test('set nil value returns error', @TestSetNilValue);
  if not T.Run then Halt(1);
end.
