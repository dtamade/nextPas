program test_toml_parser;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.mem.default,
  nextpas.core.toml.base,
  nextpas.core.toml.parser,
  nextpas.core.testing;

var
  T: TTestRunner;

function MustParse(const AToml: string): TTomlDocument;
begin
  Result.Init(DefaultAllocator);
  if not Result.Parse(TStringView.FromStr(AToml)) then
  begin
    WriteLn('  Parse error: ', Result.Error.Message.ToString,
      ' at line ', Result.Error.Line, ' col ', Result.Error.Col);
    Result.Done;
    Fail('parse failed');
  end;
end;

function MustReject(const AToml: string): Boolean;
var
  LDoc: TTomlDocument;
begin
  LDoc.Init(DefaultAllocator);
  Result := not LDoc.Parse(TStringView.FromStr(AToml));
  LDoc.Done;
end;

procedure TestEmptyInput;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('');
  Check(LDoc.Root <> TOML_NODE_NONE, 'root exists');
  Check(LDoc.Node(LDoc.Root)^.Kind = tnkTable, 'root is table');
  CheckEqual(Int64(0), Int64(LDoc.Node(LDoc.Root)^.Container.Count), 'empty');
  LDoc.Done;
end;

procedure TestCommentsOnly;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('# this is a comment' + #10 + '# another comment' + #10);
  CheckEqual(Int64(0), Int64(LDoc.Node(LDoc.Root)^.Container.Count), 'empty');
  LDoc.Done;
end;

procedure TestCommentControlCharacters;
var
  LDoc: TTomlDocument;
begin
  CheckRejectsAt('key = 1 # bad ' + #1 + #10,
    'control char in comment', 'inline comment raw C0', 14, 1, 15);
  CheckRejectsAt('# bad ' + #27 + #10,
    'control char in comment', 'standalone comment raw C0', 6, 1, 7);

  LDoc := MustParse('# tab' + #9 + 'comment' + #13#10 + 'key = 1 # ok');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count),
    'tab and CRLF comments accepted');
  LDoc.Done;
end;

procedure TestSimpleString;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('name = "Alice"');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), 'one entry');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LChild <> TOML_NODE_NONE, 'child exists');
  Check(LDoc.Node(LChild)^.Kind = tnkString, 'is string');
  Check(LDoc.Node(LChild)^.Key.Equals(TStringView.Create(PAnsiChar('name'), 4)), 'key = name');
  Check(LDoc.Node(LChild)^.Str.Equals(TStringView.Create(PAnsiChar('Alice'), 5)), 'val = Alice');
  LDoc.Done;
end;

procedure TestSimpleInteger;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('port = 8080');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64(8080), LDoc.Node(LChild)^.IntVal, 'val = 8080');
  LDoc.Done;
end;

procedure TestNegativeInteger;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('offset = -7');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64(-7), LDoc.Node(LChild)^.IntVal, 'val = -7');
  LDoc.Done;
end;

procedure TestHexInteger;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('color = 0xff0000');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64($FF0000), LDoc.Node(LChild)^.IntVal, 'val = 0xff0000');
  LDoc.Done;
end;

procedure TestOctInteger;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('perm = 0o755');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64(493), LDoc.Node(LChild)^.IntVal, 'val = 0o755 = 493');
  LDoc.Done;
end;

procedure TestBinInteger;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('flags = 0b11010110');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64(214), LDoc.Node(LChild)^.IntVal, 'val = 0b11010110 = 214');
  LDoc.Done;
end;

procedure TestIntegerWithUnderscores;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('big = 1_000_000');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkInt, 'is int');
  CheckEqual(Int64(1000000), LDoc.Node(LChild)^.IntVal, 'val = 1000000');
  LDoc.Done;
end;

procedure TestFloat;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('pi = 3.14159');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkFloat, 'is float');
  Check(Abs(LDoc.Node(LChild)^.FloatVal - 3.14159) < 1e-10, 'val ~ 3.14159');
  LDoc.Done;
end;

procedure TestFloatExponent;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('sci = 5e+22');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkFloat, 'is float');
  Check(LDoc.Node(LChild)^.FloatVal > 4.9e22, 'val ~ 5e22');
  LDoc.Done;
end;

procedure TestFloatInf;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('x = inf');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkFloat, 'is float');
  Check(LDoc.Node(LChild)^.FloatVal = 1.0/0.0, 'val = +inf');
  LDoc.Done;
end;

procedure TestFloatNegInf;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('x = -inf');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkFloat, 'is float');
  Check(LDoc.Node(LChild)^.FloatVal = -1.0/0.0, 'val = -inf');
  LDoc.Done;
end;

procedure TestFloatNan;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
  LBits: QWord;
begin
  LDoc := MustParse('x = nan');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkFloat, 'is float');
  Move(LDoc.Node(LChild)^.FloatVal, LBits, 8);
  Check((LBits and QWord($7FF0000000000000)) = QWord($7FF0000000000000), 'exponent all 1s');
  Check((LBits and QWord($000FFFFFFFFFFFFF)) <> 0, 'mantissa non-zero (NaN)');
  LDoc.Done;
end;

procedure TestBoolTrue;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('enabled = true');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkBool, 'is bool');
  Check(LDoc.Node(LChild)^.BoolVal = True, 'val = true');
  LDoc.Done;
end;

procedure TestBoolFalse;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('debug = false');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkBool, 'is bool');
  Check(LDoc.Node(LChild)^.BoolVal = False, 'val = false');
  LDoc.Done;
end;

procedure TestMultipleKeys;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('a = 1' + #10 + 'b = 2' + #10 + 'c = 3');
  CheckEqual(Int64(3), Int64(LDoc.Node(LDoc.Root)^.Container.Count), '3 entries');
  LDoc.Done;
end;

procedure TestTable;
var
  LDoc: TTomlDocument;
  LChild, LSubChild: UInt32;
begin
  LDoc := MustParse('[server]' + #10 + 'host = "localhost"' + #10 + 'port = 8080');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), '1 table');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkTable, 'is table');
  Check(LDoc.Node(LChild)^.Key.Equals(TStringView.Create(PAnsiChar('server'), 6)), 'key = server');
  CheckEqual(Int64(2), Int64(LDoc.Node(LChild)^.Container.Count), '2 entries in table');
  LSubChild := LDoc.Node(LChild)^.Container.FirstChild;
  Check(LDoc.Node(LSubChild)^.Kind = tnkString, 'host is string');
  LDoc.Done;
end;

procedure TestNestedTable;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('[a.b.c]' + #10 + 'key = "deep"');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), '1 top-level');
  LDoc.Done;
end;

procedure TestDottedKey;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('a.b.c = "value"');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), '1 top-level (a)');
  LDoc.Done;
end;

procedure TestArray;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('nums = [1, 2, 3]');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkArray, 'is array');
  CheckEqual(Int64(3), Int64(LDoc.Node(LChild)^.Container.Count), '3 elements');
  LDoc.Done;
end;

procedure TestInlineTable;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('point = {x = 1, y = 2}');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkTable, 'is table');
  CheckEqual(Int64(2), Int64(LDoc.Node(LChild)^.Container.Count), '2 entries');
  LDoc.Done;
end;

procedure TestLiteralString;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('path = ''C:\Users\admin''');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkString, 'is string');
  Check(LDoc.Node(LChild)^.Str.Equals(
    TStringView.Create(PAnsiChar('C:\Users\admin'), 14)), 'literal no escape');
  LDoc.Done;
end;

procedure TestEscapedString;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('msg = "hello\nworld"');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkString, 'is string');
  Check(LDoc.Node(LChild)^.Str.Equals(
    TStringView.Create(PAnsiChar('hello' + #10 + 'world'), 11)), 'escaped newline');
  LDoc.Done;
end;

procedure TestQuotedKey;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('"key with spaces" = "value"');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Key.Equals(
    TStringView.Create(PAnsiChar('key with spaces'), 15)), 'quoted key');
  LDoc.Done;
end;

procedure TestDateTimeOffset;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
  LDT: TTomlDateTime;
begin
  LDoc := MustParse('dt = 1979-05-27T07:32:00Z');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkDateTime, 'is datetime');
  LDT := LDoc.Node(LChild)^.DT;
  CheckEqual(Int64(1979), Int64(LDT.Year), 'year');
  CheckEqual(Int64(5), Int64(LDT.Month), 'month');
  CheckEqual(Int64(27), Int64(LDT.Day), 'day');
  CheckEqual(Int64(7), Int64(LDT.Hour), 'hour');
  CheckEqual(Int64(32), Int64(LDT.Minute), 'minute');
  Check(LDT.HasOffset, 'has offset');
  CheckEqual(Int64(0), Int64(LDT.OffsetMinutes), 'offset = 0 (Z)');
  Check(LDT.Kind = tdkOffsetDateTime, 'kind = offset');
  LDoc.Done;
end;

procedure TestLocalDate;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
  LDT: TTomlDateTime;
begin
  LDoc := MustParse('d = 2024-01-15');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkDateTime, 'is datetime');
  LDT := LDoc.Node(LChild)^.DT;
  Check(LDT.HasDate, 'has date');
  Check(not LDT.HasTime, 'no time');
  Check(LDT.Kind = tdkLocalDate, 'kind = local date');
  LDoc.Done;
end;

procedure TestLocalTime;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
  LDT: TTomlDateTime;
begin
  LDoc := MustParse('t = 07:32:00');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkDateTime, 'is datetime');
  LDT := LDoc.Node(LChild)^.DT;
  Check(not LDT.HasDate, 'no date');
  Check(LDT.HasTime, 'has time');
  Check(LDT.Kind = tdkLocalTime, 'kind = local time');
  LDoc.Done;
end;

procedure TestArrayTable;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('[[products]]' + #10 + 'name = "Hammer"' + #10 +
    '[[products]]' + #10 + 'name = "Nail"');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkArray, 'is array');
  CheckEqual(Int64(2), Int64(LDoc.Node(LChild)^.Container.Count), '2 elements');
  LDoc.Done;
end;

procedure TestDuplicateKeyReject;
begin
  Check(MustReject('a = 1' + #10 + 'a = 2'), 'duplicate key rejected');
end;

procedure TestTrailingCommaArray;
var
  LDoc: TTomlDocument;
  LChild: UInt32;
begin
  LDoc := MustParse('a = [1, 2, 3,]');
  LChild := LDoc.Node(LDoc.Root)^.Container.FirstChild;
  Check(LDoc.Node(LChild)^.Kind = tnkArray, 'is array');
  CheckEqual(Int64(3), Int64(LDoc.Node(LChild)^.Container.Count), '3 elements');
  LDoc.Done;
end;

procedure TestCommentAfterValue;
var
  LDoc: TTomlDocument;
begin
  LDoc := MustParse('key = "value" # this is a comment');
  CheckEqual(Int64(1), Int64(LDoc.Node(LDoc.Root)^.Container.Count), '1 entry');
  LDoc.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.toml.parser');
  T.Run('empty input', @TestEmptyInput);
  T.Run('comments only', @TestCommentsOnly);
  T.Run('comment control characters', @TestCommentControlCharacters);
  T.Run('simple string', @TestSimpleString);
  T.Run('simple integer', @TestSimpleInteger);
  T.Run('negative integer', @TestNegativeInteger);
  T.Run('hex integer', @TestHexInteger);
  T.Run('oct integer', @TestOctInteger);
  T.Run('bin integer', @TestBinInteger);
  T.Run('integer underscores', @TestIntegerWithUnderscores);
  T.Run('float', @TestFloat);
  T.Run('float exponent', @TestFloatExponent);
  T.Run('float inf', @TestFloatInf);
  T.Run('float -inf', @TestFloatNegInf);
  T.Run('float nan', @TestFloatNan);
  T.Run('bool true', @TestBoolTrue);
  T.Run('bool false', @TestBoolFalse);
  T.Run('multiple keys', @TestMultipleKeys);
  T.Run('table', @TestTable);
  T.Run('nested table', @TestNestedTable);
  T.Run('dotted key', @TestDottedKey);
  T.Run('array', @TestArray);
  T.Run('inline table', @TestInlineTable);
  T.Run('literal string', @TestLiteralString);
  T.Run('escaped string', @TestEscapedString);
  T.Run('quoted key', @TestQuotedKey);
  T.Run('datetime offset', @TestDateTimeOffset);
  T.Run('local date', @TestLocalDate);
  T.Run('local time', @TestLocalTime);
  T.Run('array table', @TestArrayTable);
  T.Run('duplicate key reject', @TestDuplicateKeyReject);
  T.Run('trailing comma array', @TestTrailingCommaArray);
  T.Run('comment after value', @TestCommentAfterValue);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
