program test_platform_env;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.env,
  nextpas.core.testing;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.platform.env');
  T.Run('get PATH', @TestGetPath);
  T.Run('set + get roundtrip', @TestSetGetRoundtrip);
  T.Run('unset', @TestUnset);
  T.Run('get non-existent', @TestGetNonExistent);
  T.Run('set empty value', @TestSetEmpty);
  T.Run('buffer too small', @TestBufferTooSmall);
  T.Run('exists false', @TestExistsFalse);
  T.Run('get length only (nil buf)', @TestGetLengthOnly);
  T.Run('long value (1000 chars)', @TestLongValue);
  T.Run('special characters', @TestSpecialChars);
  T.Run('overwrite existing', @TestOverwrite);
  T.Run('invalid names', @TestInvalidNames);
  T.Summary;
end.
