program test_toml_writer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.toml.base,
  nextpas.core.toml.writer,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestSimpleKeyValue;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('name'); W.Str('Alice');
  CheckEqual('name = "Alice"' + #10, B.ToString, 'simple kv');
  B.Done;
end;

procedure TestInteger;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('port'); W.Int(8080);
  CheckEqual('port = 8080' + #10, B.ToString, 'integer');
  B.Done;
end;

procedure TestFloat;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('pi'); W.Float(3.14);
  CheckEqual('pi = 3.14' + #10, B.ToString, 'float');
  B.Done;
end;

procedure TestBool;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('enabled'); W.Bool(True);
  W.Key('debug'); W.Bool(False);
  CheckEqual('enabled = true' + #10 + 'debug = false' + #10, B.ToString, 'bool');
  B.Done;
end;

procedure TestTableHeader;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.BeginTable('server');
  W.Key('host'); W.Str('localhost');
  CheckEqual('[server]' + #10 + 'host = "localhost"' + #10, B.ToString, 'table');
  B.Done;
end;

procedure TestArrayTableHeader;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.BeginArrayTable('products');
  W.Key('name'); W.Str('Hammer');
  CheckEqual('[[products]]' + #10 + 'name = "Hammer"' + #10, B.ToString, 'array table');
  B.Done;
end;

procedure TestInlineTable;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('point');
  W.BeginInlineTable;
  W.Key('x'); W.Int(1);
  W.Key('y'); W.Int(2);
  W.EndInlineTable;
  CheckEqual('point = { x = 1, y = 2 }' + #10, B.ToString, 'inline table');
  B.Done;
end;

procedure TestArray;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('nums');
  W.BeginArray;
  W.Int(1); W.Int(2); W.Int(3);
  W.EndArray;
  CheckEqual('nums = [1, 2, 3]' + #10, B.ToString, 'array');
  B.Done;
end;

procedure TestEscapedString;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('msg'); W.Str('hello' + #10 + 'world');
  CheckEqual('msg = "hello\nworld"' + #10, B.ToString, 'escaped');
  B.Done;
end;

procedure TestQuotedKey;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('key with spaces'); W.Int(1);
  CheckEqual('"key with spaces" = 1' + #10, B.ToString, 'quoted key');
  B.Done;
end;

procedure TestComment;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Comment('This is a comment');
  W.Key('x'); W.Int(1);
  CheckEqual('# This is a comment' + #10 + 'x = 1' + #10, B.ToString, 'comment');
  B.Done;
end;

procedure TestDateTimeOffset;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('dt'); W.DateTime(TomlDateTimeWithOffset(1979, 5, 27, 7, 32, 0, 0, 0));
  CheckEqual('dt = 1979-05-27T07:32:00Z' + #10, B.ToString, 'datetime Z');
  B.Done;
end;

procedure TestDateTimePositiveOffset;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('dt'); W.DateTime(TomlDateTimeWithOffset(2024, 6, 15, 14, 0, 0, 0, 540));
  CheckEqual('dt = 2024-06-15T14:00:00+09:00' + #10, B.ToString, 'datetime +09:00');
  B.Done;
end;

procedure TestLocalDate;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('d'); W.DateTime(TomlDate(2024, 1, 15));
  CheckEqual('d = 2024-01-15' + #10, B.ToString, 'local date');
  B.Done;
end;

procedure TestLocalTime;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('t'); W.DateTime(TomlTime(7, 32, 0, 0));
  CheckEqual('t = 07:32:00' + #10, B.ToString, 'local time');
  B.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.toml.writer');
  T.Run('simple key-value', @TestSimpleKeyValue);
  T.Run('integer', @TestInteger);
  T.Run('float', @TestFloat);
  T.Run('bool', @TestBool);
  T.Run('table header', @TestTableHeader);
  T.Run('array table header', @TestArrayTableHeader);
  T.Run('inline table', @TestInlineTable);
  T.Run('array', @TestArray);
  T.Run('escaped string', @TestEscapedString);
  T.Run('quoted key', @TestQuotedKey);
  T.Run('comment', @TestComment);
  T.Run('datetime offset Z', @TestDateTimeOffset);
  T.Run('datetime +09:00', @TestDateTimePositiveOffset);
  T.Run('local date', @TestLocalDate);
  T.Run('local time', @TestLocalTime);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
