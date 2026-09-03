program test_props;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.base,
  nextpas.core.fs,
  nextpas.core.props, nextpas.core.text.conv;

var
  T: TTestSuite;

procedure TestParseBasic;
var
  LP: TPropsArray;
begin
  LP := ParseKeyValueText('key1=value1' + #10 + 'key2=value2');
  CheckEqual(Int64(2), Int64(Length(LP)), '2 entries');
  Check(LP[0].Key = 'key1', 'key1');
  Check(LP[0].Value = 'value1', 'value1');
  Check(LP[1].Key = 'key2', 'key2');
  Check(LP[1].Value = 'value2', 'value2');
end;

procedure TestParseComments;
var
  LP: TPropsArray;
begin
  LP := ParseKeyValueText('# comment' + #10 + 'key=val' + #10 + '; another comment');
  CheckEqual(Int64(1), Int64(Length(LP)), 'comments skipped');
  Check(LP[0].Key = 'key', 'key');
end;

procedure TestParseEmptyLines;
var
  LP: TPropsArray;
begin
  LP := ParseKeyValueText('' + #10 + 'a=1' + #10 + '' + #10 + 'b=2' + #10);
  CheckEqual(Int64(2), Int64(Length(LP)), 'empty lines skipped');
end;

procedure TestParseTrimming;
var
  LP: TPropsArray;
begin
  LP := ParseKeyValueText('  key  =  value  ');
  CheckEqual(Int64(1), Int64(Length(LP)), '1 entry');
  Check(LP[0].Key = 'key', 'key trimmed');
  Check(LP[0].Value = 'value', 'value trimmed');
end;

procedure TestParseNoValue;
var
  LP: TPropsArray;
begin
  LP := ParseKeyValueText('key_only');
  CheckEqual(Int64(1), Int64(Length(LP)), 'key without =');
  Check(LP[0].Key = 'key_only', 'key');
  Check(LP[0].Value = '', 'empty value');
end;

procedure TestParseCustomSep;
var
  LP: TPropsArray;
begin
  LP := ParseKeyValueText('key:value', ':');
  CheckEqual(Int64(1), Int64(Length(LP)), 'colon sep');
  Check(LP[0].Key = 'key', 'key');
  Check(LP[0].Value = 'value', 'value');
end;

procedure TestPropsGet;
var
  LP: TPropsArray;
begin
  LP := ParseKeyValueText('host=localhost' + #10 + 'port=8080');
  Check(PropsGet(LP, 'host') = 'localhost', 'get host');
  Check(PropsGet(LP, 'port') = '8080', 'get port');
  Check(PropsGet(LP, 'missing', 'default') = 'default', 'get default');
end;

procedure TestPropsHas;
var
  LP: TPropsArray;
begin
  LP := ParseKeyValueText('exists=yes');
  Check(PropsHas(LP, 'exists'), 'has exists');
  Check(not PropsHas(LP, 'nope'), 'not has nope');
end;

procedure TestReadWriteFile;
var
  LPath: string;
  LP: TPropsArray;
begin
  LPath := '/tmp/test_props_' + IntToStr(Random(99999)) + '.env';
  SetLength(LP, 2);
  LP[0].Key := 'DB_HOST'; LP[0].Value := 'localhost';
  LP[1].Key := 'DB_PORT'; LP[1].Value := '5432';
  WriteKeyValueFile(LPath, LP);
  LP := ReadKeyValueFile(LPath);
  CheckEqual(Int64(2), Int64(Length(LP)), 'read back 2');
  Check(PropsGet(LP, 'DB_HOST') = 'localhost', 'DB_HOST');
  Check(PropsGet(LP, 'DB_PORT') = '5432', 'DB_PORT');
  DeleteFile(LPath);
end;

procedure TestParseCRLF;
var
  LP: TPropsArray;
begin
  LP := ParseKeyValueText('a=1' + #13#10 + 'b=2' + #13#10);
  CheckEqual(Int64(2), Int64(Length(LP)), 'CRLF');
  Check(LP[0].Value = '1', 'crlf val1');
  Check(LP[1].Value = '2', 'crlf val2');
end;

procedure TestParseValueWithEquals;
var
  LP: TPropsArray;
begin
  LP := ParseKeyValueText('url=http://host:8080/path?a=1&b=2');
  CheckEqual(Int64(1), Int64(Length(LP)), 'value with =');
  Check(LP[0].Key = 'url', 'key');
  Check(LP[0].Value = 'http://host:8080/path?a=1&b=2', 'value preserved');
end;

begin
  T := TTestSuite.Create('nextpas.core.props');
  T.Test('Parse basic', @TestParseBasic);
  T.Test('Parse comments', @TestParseComments);
  T.Test('Parse empty lines', @TestParseEmptyLines);
  T.Test('Parse trimming', @TestParseTrimming);
  T.Test('Parse no value', @TestParseNoValue);
  T.Test('Parse custom sep', @TestParseCustomSep);
  T.Test('PropsGet', @TestPropsGet);
  T.Test('PropsHas', @TestPropsHas);
  T.Test('Read/Write file', @TestReadWriteFile);
  T.Test('Parse CRLF', @TestParseCRLF);
  T.Test('Value with equals', @TestParseValueWithEquals);
  if not T.Run then Halt(1);
end.
