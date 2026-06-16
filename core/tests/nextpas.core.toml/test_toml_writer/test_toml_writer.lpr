program test_toml_writer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.errors,
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.toml.base,
  nextpas.core.toml.writer,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure CheckRawPathRejected(var W: TTomlWriter; const AFormattedPath: string;
  const AMessage: string; const AArrayTable: Boolean);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    if AArrayTable then
      W.BeginArrayTableRaw(AFormattedPath)
    else
      W.BeginTableRaw(AFormattedPath);
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, AMessage);
end;

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

procedure TestBeginTableRawRejectsInvalidPath;
var
  B: TStringBuilder;
  W: TTomlWriter;
begin
  B.Init(256); W.Init(B);
  try
    W.Key('before'); W.Int(1);
    CheckRawPathRejected(W, '', 'BeginTableRaw rejects empty path', False);
    CheckRawPathRejected(W, 'server' + #10 + 'bad',
      'BeginTableRaw rejects newline', False);
    CheckRawPathRejected(W, 'server]bad',
      'BeginTableRaw rejects closing bracket', False);
    CheckRawPathRejected(W, '"server]bad',
      'BeginTableRaw rejects unterminated quoted key with closing bracket',
      False);
    CheckRawPathRejected(W, 'server' + #1 + 'bad',
      'BeginTableRaw rejects control char', False);
    CheckRawPathRejected(W, 'server' + #127 + 'bad',
      'BeginTableRaw rejects DEL control char', False);
    W.BeginTableRaw('server.valid');
    W.Key('after'); W.Bool(True);
    CheckEqual('before = 1' + #10 + '[server.valid]' + #10 +
      'after = true' + #10, B.ToString,
      'rejected BeginTableRaw leaves writer usable');
  finally
    B.Done;
  end;
end;

procedure TestBeginTableRawAllowsClosingBracketInsideQuotedKey;
var
  B: TStringBuilder;
  W: TTomlWriter;
begin
  B.Init(256); W.Init(B);
  try
    W.BeginTableRaw('"server]name".valid');
    W.Key('after'); W.Bool(True);
    CheckEqual('["server]name".valid]' + #10 + 'after = true' + #10,
      B.ToString, 'BeginTableRaw allows closing bracket inside quoted key');
  finally
    B.Done;
  end;
end;

procedure TestBeginArrayTableRawRejectsInvalidPath;
var
  B: TStringBuilder;
  W: TTomlWriter;
begin
  B.Init(256); W.Init(B);
  try
    W.Key('before'); W.Int(1);
    CheckRawPathRejected(W, '', 'BeginArrayTableRaw rejects empty path', True);
    CheckRawPathRejected(W, 'products' + #10 + 'bad',
      'BeginArrayTableRaw rejects newline', True);
    CheckRawPathRejected(W, 'products]bad',
      'BeginArrayTableRaw rejects closing bracket', True);
    CheckRawPathRejected(W, '''products]bad',
      'BeginArrayTableRaw rejects unterminated quoted key with closing bracket',
      True);
    CheckRawPathRejected(W, 'products' + #1 + 'bad',
      'BeginArrayTableRaw rejects control char', True);
    CheckRawPathRejected(W, 'products' + #127 + 'bad',
      'BeginArrayTableRaw rejects DEL control char', True);
    W.BeginArrayTableRaw('products.valid');
    W.Key('after'); W.Str('ok');
    CheckEqual('before = 1' + #10 + '[[products.valid]]' + #10 +
      'after = "ok"' + #10, B.ToString,
      'rejected BeginArrayTableRaw leaves writer usable');
  finally
    B.Done;
  end;
end;

procedure TestBeginArrayTableRawAllowsClosingBracketInsideQuotedKey;
var
  B: TStringBuilder;
  W: TTomlWriter;
begin
  B.Init(256); W.Init(B);
  try
    W.BeginArrayTableRaw('"product]name".valid');
    W.Key('after'); W.Str('ok');
    CheckEqual('[["product]name".valid]]' + #10 + 'after = "ok"' + #10,
      B.ToString,
      'BeginArrayTableRaw allows closing bracket inside quoted key');
  finally
    B.Done;
  end;
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

procedure TestMultilineComment;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(128); W.Init(B);
  W.Comment('first' + #10 + 'second' + #13#10 + 'third');
  W.Key('x'); W.Int(1);
  CheckEqual('# first' + #10 + '# second' + #10 + '# third' + #10 +
    'x = 1' + #10, B.ToString, 'multiline comment');
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

procedure TestLocalDatePadsYear;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('d'); W.DateTime(TomlDate(9, 1, 2));
  CheckEqual('d = 0009-01-02' + #10, B.ToString, 'local date pads year');
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

procedure TestNewline;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('a'); W.Int(1);
  W.Newline;
  W.Key('b'); W.Int(2);
  CheckEqual('a = 1' + #10 + #10 + 'b = 2' + #10, B.ToString, 'newline');
  B.Done;
end;

procedure TestKeyStringView;
var B: TStringBuilder; W: TTomlWriter; LView: TStringView;
begin
  B.Init(64); W.Init(B);
  LView := TStringView.Create(PAnsiChar('mykey'), 5);
  W.Key(LView); W.Int(99);
  CheckEqual('mykey = 99' + #10, B.ToString, 'key TStringView');
  B.Done;
end;

procedure TestStrStringView;
var B: TStringBuilder; W: TTomlWriter; LView: TStringView;
begin
  B.Init(64); W.Init(B);
  LView := TStringView.Create(PAnsiChar('hello'), 5);
  W.Key('msg'); W.Str(LView);
  CheckEqual('msg = "hello"' + #10, B.ToString, 'str TStringView');
  B.Done;
end;

procedure TestNestedArray;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.Init(B);
  W.Key('m');
  W.BeginArray;
    W.BeginArray; W.Int(1); W.Int(2); W.EndArray;
    W.BeginArray; W.Int(3); W.Int(4); W.EndArray;
  W.EndArray;
  CheckEqual('m = [[1, 2], [3, 4]]' + #10, B.ToString, 'nested array');
  B.Done;
end;

procedure TestPrettyArray;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(64); W.InitPretty(B, 2);
  W.Key('nums');
  W.BeginArray;
  W.Int(1); W.Int(2); W.Int(3);
  W.EndArray;
  CheckEqual('nums = [' + #10 + '  1,' + #10 + '  2,' + #10 + '  3' + #10 + ']' + #10,
    B.ToString, 'pretty array');
  B.Done;
end;

procedure TestPrettyNestedArray;
var B: TStringBuilder; W: TTomlWriter;
begin
  B.Init(128); W.InitPretty(B, 2);
  W.Key('m');
  W.BeginArray;
    W.BeginArray; W.Int(1); W.Int(2); W.EndArray;
    W.BeginArray; W.Int(3); W.Int(4); W.EndArray;
  W.EndArray;
  CheckEqual('m = [' + #10 +
    '  [' + #10 + '    1,' + #10 + '    2' + #10 + '  ],' + #10 +
    '  [' + #10 + '    3,' + #10 + '    4' + #10 + '  ]' + #10 +
    ']' + #10,
    B.ToString, 'pretty nested');
  B.Done;
end;

procedure TestEndArrayRejectsUnmatchedContainer;
var
  B: TStringBuilder;
  W: TTomlWriter;
  LRaised: Boolean;
begin
  B.Init(64); W.Init(B);
  try
    W.Key('name'); W.Str('Alice');
    LRaised := False;
    try
      W.EndArray;
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'unmatched EndArray raises EInvalidOperationError');
    CheckEqual('name = "Alice"' + #10, B.ToString,
      'unmatched EndArray leaves output unchanged');
  finally
    B.Done;
  end;
end;

procedure TestEndInlineTableRejectsUnmatchedContainer;
var
  B: TStringBuilder;
  W: TTomlWriter;
  LRaised: Boolean;
begin
  B.Init(64); W.Init(B);
  try
    W.Key('name'); W.Str('Alice');
    LRaised := False;
    try
      W.EndInlineTable;
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'unmatched EndInlineTable raises EInvalidOperationError');
    CheckEqual('name = "Alice"' + #10, B.ToString,
      'unmatched EndInlineTable leaves output unchanged');
  finally
    B.Done;
  end;
end;

procedure TestMismatchedInlineContainerEndIsRejected;
var
  B: TStringBuilder;
  W: TTomlWriter;
  LRaised: Boolean;
begin
  B.Init(64); W.Init(B);
  try
    W.Key('point');
    W.BeginInlineTable;
    LRaised := False;
    try
      W.EndArray;
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'EndArray rejects open inline table');
    W.Key('x'); W.Int(1);
    W.EndInlineTable;
    CheckEqual('point = { x = 1 }' + #10, B.ToString,
      'mismatched end leaves inline table usable');
  finally
    B.Done;
  end;
end;

procedure TestKeyInsideArrayIsRejected;
var
  B: TStringBuilder;
  W: TTomlWriter;
  LRaised: Boolean;
begin
  B.Init(64); W.Init(B);
  try
    W.Key('items');
    W.BeginArray;
    W.Int(1);
    LRaised := False;
    try
      W.Key('bad');
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'Key inside array raises EInvalidOperationError');
    W.Int(2);
    W.EndArray;
    CheckEqual('items = [1, 2]' + #10, B.ToString,
      'rejected array key leaves array usable');
  finally
    B.Done;
  end;
end;

procedure TestKeyStringViewInsideArrayIsRejected;
var
  B: TStringBuilder;
  W: TTomlWriter;
  LKey: TStringView;
  LRaised: Boolean;
begin
  B.Init(64); W.Init(B);
  try
    W.Key('items');
    W.BeginArray;
    W.Str('ok');
    LKey := TStringView.Create(PAnsiChar('bad'), 3);
    LRaised := False;
    try
      W.Key(LKey);
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'Key(TStringView) inside array raises EInvalidOperationError');
    W.Str('still-ok');
    W.EndArray;
    CheckEqual('items = ["ok", "still-ok"]' + #10, B.ToString,
      'rejected array TStringView key leaves array usable');
  finally
    B.Done;
  end;
end;

procedure TestTableHeaderInsideArrayIsRejected;
var
  B: TStringBuilder;
  W: TTomlWriter;
  LRaised: Boolean;
begin
  B.Init(64); W.Init(B);
  try
    W.Key('items');
    W.BeginArray;
    W.Int(1);
    LRaised := False;
    try
      W.BeginTable('bad');
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'BeginTable inside array raises EInvalidOperationError');
    W.Int(2);
    W.EndArray;
    CheckEqual('items = [1, 2]' + #10, B.ToString,
      'rejected table header leaves array usable');
  finally
    B.Done;
  end;
end;

procedure TestArrayTableHeaderInsideArrayIsRejected;
var
  B: TStringBuilder;
  W: TTomlWriter;
  LRaised: Boolean;
begin
  B.Init(64); W.Init(B);
  try
    W.Key('items');
    W.BeginArray;
    W.Int(1);
    LRaised := False;
    try
      W.BeginArrayTable('bad');
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'BeginArrayTable inside array raises EInvalidOperationError');
    W.Int(2);
    W.EndArray;
    CheckEqual('items = [1, 2]' + #10, B.ToString,
      'rejected array table header leaves array usable');
  finally
    B.Done;
  end;
end;

procedure TestInlineContainerStackOverflowIsRejected;
var
  B: TStringBuilder;
  W: TTomlWriter;
  LI: Int32;
  LRaised: Boolean;
begin
  B.Init(1024); W.Init(B);
  try
    W.Key('nested');
    for LI := 1 to 128 do
      W.BeginArray;
    LRaised := False;
    try
      W.BeginArray;
    except
      on E: EResourceExhaustedError do
        LRaised := True;
    end;
    Check(LRaised, 'inline container overflow raises EResourceExhaustedError');
    for LI := 1 to 128 do
      W.EndArray;
    CheckEqual('nested = ' + StringOfChar('[', 128) + StringOfChar(']', 128) + #10,
      B.ToString, 'overflow leaves existing stack balanced');
  finally
    B.Done;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.toml.writer');
  T.Run('simple key-value', @TestSimpleKeyValue);
  T.Run('integer', @TestInteger);
  T.Run('float', @TestFloat);
  T.Run('bool', @TestBool);
  T.Run('table header', @TestTableHeader);
  T.Run('array table header', @TestArrayTableHeader);
  T.Run('BeginTableRaw invalid path rejected',
    @TestBeginTableRawRejectsInvalidPath);
  T.Run('BeginTableRaw quoted closing bracket allowed',
    @TestBeginTableRawAllowsClosingBracketInsideQuotedKey);
  T.Run('BeginArrayTableRaw invalid path rejected',
    @TestBeginArrayTableRawRejectsInvalidPath);
  T.Run('BeginArrayTableRaw quoted closing bracket allowed',
    @TestBeginArrayTableRawAllowsClosingBracketInsideQuotedKey);
  T.Run('inline table', @TestInlineTable);
  T.Run('array', @TestArray);
  T.Run('escaped string', @TestEscapedString);
  T.Run('quoted key', @TestQuotedKey);
  T.Run('comment', @TestComment);
  T.Run('multiline comment', @TestMultilineComment);
  T.Run('datetime offset Z', @TestDateTimeOffset);
  T.Run('datetime +09:00', @TestDateTimePositiveOffset);
  T.Run('local date', @TestLocalDate);
  T.Run('local date pads year', @TestLocalDatePadsYear);
  T.Run('local time', @TestLocalTime);
  T.Run('newline', @TestNewline);
  T.Run('key TStringView', @TestKeyStringView);
  T.Run('str TStringView', @TestStrStringView);
  T.Run('nested array', @TestNestedArray);
  T.Run('pretty array', @TestPrettyArray);
  T.Run('pretty nested array', @TestPrettyNestedArray);
  T.Run('unmatched EndArray rejected', @TestEndArrayRejectsUnmatchedContainer);
  T.Run('unmatched EndInlineTable rejected', @TestEndInlineTableRejectsUnmatchedContainer);
  T.Run('mismatched inline container end rejected', @TestMismatchedInlineContainerEndIsRejected);
  T.Run('Key inside array rejected', @TestKeyInsideArrayIsRejected);
  T.Run('Key TStringView inside array rejected',
    @TestKeyStringViewInsideArrayIsRejected);
  T.Run('table header inside array rejected',
    @TestTableHeaderInsideArrayIsRejected);
  T.Run('array table header inside array rejected',
    @TestArrayTableHeaderInsideArrayIsRejected);
  T.Run('inline container stack overflow rejected', @TestInlineContainerStackOverflowIsRejected);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
