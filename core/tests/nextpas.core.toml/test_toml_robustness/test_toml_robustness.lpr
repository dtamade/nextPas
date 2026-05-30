program test_toml_robustness;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.view,
  nextpas.core.toml.base,
  nextpas.core.toml.value,
  nextpas.core.toml,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestDeepNestedArrays;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := 'x = ';
  for LI := 1 to 200 do
    LInput := LInput + '[';
  for LI := 1 to 200 do
    LInput := LInput + ']';
  LDoc := TomlParse(LInput);
  Check(LDoc.HasError, 'deep nested arrays rejected');
end;

procedure TestDeepNestedInlineTables;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := 'x = ';
  for LI := 1 to 200 do
    LInput := LInput + '{a = ';
  LInput := LInput + '1';
  for LI := 1 to 200 do
    LInput := LInput + '}';
  LDoc := TomlParse(LInput);
  Check(LDoc.HasError, 'deep nested inline tables rejected');
end;

procedure TestEmptyInput;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('');
  Check(not LDoc.HasError, 'empty input ok');
  CheckEqual(Int64(0), Int64(LDoc.Root.TableLen), 'empty root');
end;

procedure TestOnlyWhitespace;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('   ' + #10 + '  ' + #9 + #10);
  Check(not LDoc.HasError, 'whitespace only ok');
end;

procedure TestOnlyComments;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('# comment 1' + #10 + '# comment 2' + #10 + '# comment 3');
  Check(not LDoc.HasError, 'comments only ok');
end;

procedure TestVeryLongKey;
var
  LDoc: ITomlDocument;
  LKey: string;
  LI: Integer;
begin
  LKey := '';
  for LI := 1 to 1000 do
    LKey := LKey + 'a';
  LDoc := TomlParse(LKey + ' = 1');
  Check(not LDoc.HasError, 'long key accepted');
  CheckEqual(Int64(1), LDoc.Root.Get(LKey).AsInt, 'long key value');
end;

procedure TestVeryLongString;
var
  LDoc: ITomlDocument;
  LVal: string;
  LI: Integer;
begin
  LVal := '';
  for LI := 1 to 10000 do
    LVal := LVal + 'x';
  LDoc := TomlParse('s = "' + LVal + '"');
  Check(not LDoc.HasError, 'long string accepted');
  CheckEqual(Int64(10000), Int64(LDoc.Root.Get('s').AsStr.Len), 'long string len');
end;

procedure TestManyKeys;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 1000 do
    LInput := LInput + 'key_' + IntToStr(LI) + ' = ' + IntToStr(LI) + #10;
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '1000 keys accepted');
  CheckEqual(Int64(1000), Int64(LDoc.Root.TableLen), '1000 keys count');
  CheckEqual(Int64(500), LDoc.Root.Get('key_500').AsInt, 'key_500 = 500');
end;

procedure TestNullBytesInString;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('s = "abc' + #0 + 'def"');
  Check(LDoc.HasError, 'null byte in string rejected');
end;

procedure TestControlCharsInBareKey;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse(#1 + ' = 1');
  Check(LDoc.HasError, 'control char in bare key rejected');
end;

procedure TestUnterminatedString;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('s = "unterminated');
  Check(LDoc.HasError, 'unterminated string rejected');
end;

procedure TestUnterminatedMultiLineString;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('s = """unterminated');
  Check(LDoc.HasError, 'unterminated multi-line string rejected');
end;

procedure TestUnterminatedArray;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a = [1, 2, 3');
  Check(LDoc.HasError, 'unterminated array rejected');
end;

procedure TestUnterminatedInlineTable;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('t = {x = 1');
  Check(LDoc.HasError, 'unterminated inline table rejected');
end;

procedure TestMissingEquals;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('key value');
  Check(LDoc.HasError, 'missing equals rejected');
end;

procedure TestKeyOnly;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('key =');
  Check(LDoc.HasError, 'key without value rejected');
end;

procedure TestTableHeaderOnly;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[table]');
  Check(not LDoc.HasError, 'empty table ok');
  Check(LDoc.Root.Get('table').IsTable, 'table exists');
end;

procedure TestMaxInt64;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 9223372036854775807');
  Check(not LDoc.HasError, 'max int64 ok');
  CheckEqual(Int64(9223372036854775807), LDoc.Root.Get('x').AsInt, 'max int64');
end;

procedure TestMinInt64;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = -9223372036854775808');
  Check(not LDoc.HasError, 'min int64 ok');
  CheckEqual(Int64(-9223372036854775808), LDoc.Root.Get('x').AsInt, 'min int64');
end;

procedure TestCRLFLineEndings;
var LDoc: ITomlDocument;
begin
  LDoc := TomlParse('a = 1' + #13#10 + 'b = 2' + #13#10);
  Check(not LDoc.HasError, 'CRLF ok');
  CheckEqual(Int64(1), LDoc.Root.Get('a').AsInt, 'a = 1');
  CheckEqual(Int64(2), LDoc.Root.Get('b').AsInt, 'b = 2');
end;

procedure TestModerateNesting;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := 'x = ';
  for LI := 1 to 50 do
    LInput := LInput + '[';
  LInput := LInput + '1';
  for LI := 1 to 50 do
    LInput := LInput + ']';
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '50-deep nesting ok');
end;

procedure TestHashIndex500;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + 'item_' + IntToStr(LI) + ' = ' + IntToStr(LI * 10) + #10;
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, '500 keys ok');
  CheckEqual(Int64(500), Int64(LDoc.Root.TableLen), '500 keys count');
  CheckEqual(Int64(10), LDoc.Root.Get('item_1').AsInt, 'first key');
  CheckEqual(Int64(2500), LDoc.Root.Get('item_250').AsInt, 'middle key');
  CheckEqual(Int64(5000), LDoc.Root.Get('item_500').AsInt, 'last key');
end;

procedure TestHashIndexDupDetect;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 300 do
    LInput := LInput + 'k_' + IntToStr(LI) + ' = ' + IntToStr(LI) + #10;
  LInput := LInput + 'k_150 = 999' + #10;
  LDoc := TomlParse(LInput);
  Check(LDoc.HasError, 'duplicate key detected with hash index');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml robustness');
  T.Run('deep nested arrays', @TestDeepNestedArrays);
  T.Run('deep nested inline tables', @TestDeepNestedInlineTables);
  T.Run('empty input', @TestEmptyInput);
  T.Run('only whitespace', @TestOnlyWhitespace);
  T.Run('only comments', @TestOnlyComments);
  T.Run('very long key', @TestVeryLongKey);
  T.Run('very long string', @TestVeryLongString);
  T.Run('many keys (1000)', @TestManyKeys);
  T.Run('null bytes in string', @TestNullBytesInString);
  T.Run('control chars in bare key', @TestControlCharsInBareKey);
  T.Run('unterminated string', @TestUnterminatedString);
  T.Run('unterminated multi-line string', @TestUnterminatedMultiLineString);
  T.Run('unterminated array', @TestUnterminatedArray);
  T.Run('unterminated inline table', @TestUnterminatedInlineTable);
  T.Run('missing equals', @TestMissingEquals);
  T.Run('key without value', @TestKeyOnly);
  T.Run('table header only', @TestTableHeaderOnly);
  T.Run('max int64', @TestMaxInt64);
  T.Run('min int64', @TestMinInt64);
  T.Run('CRLF line endings', @TestCRLFLineEndings);
  T.Run('moderate nesting (50)', @TestModerateNesting);
  T.Run('hash index (500 keys)', @TestHashIndex500);
  T.Run('hash index dup detect', @TestHashIndexDupDetect);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
