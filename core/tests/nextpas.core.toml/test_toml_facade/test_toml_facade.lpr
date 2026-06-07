program test_toml_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.mem.default,
  nextpas.core.mem.intf,
  nextpas.core.toml.base,
  nextpas.core.toml.value,
  nextpas.core.toml.builder,
  nextpas.core.toml,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure CheckParseErrorMessage(const ASource, AExpectedMessage,
  ACaseName: string);
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse(ASource);
  Check(LDoc.HasError, ACaseName + ' has error');
  CheckEqual(AExpectedMessage, LDoc.Error.Message.ToString,
    ACaseName + ' diagnostic message');
end;

procedure TestParseSimple;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('name = "Alice"' + #10 + 'age = 30');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('name').AsStr.Equals(
    TStringView.Create(PAnsiChar('Alice'), 5)), 'name = Alice');
  CheckEqual(Int64(30), LDoc.Root.Get('age').AsInt, 'age = 30');
end;

procedure TestParseNested;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('[database]' + #10 + 'host = "localhost"' + #10 + 'port = 5432');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('database').Get('host').AsStr.Equals(
    TStringView.Create(PAnsiChar('localhost'), 9)), 'host');
  CheckEqual(Int64(5432), LDoc.Root.Get('database').Get('port').AsInt, 'port');
end;

procedure TestParseError;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('= invalid');
  Check(LDoc.HasError, 'has error');
  Check(LDoc.Error.Line > 0, 'error has line');
end;

procedure TestTryTomlParseSuccess;
var
  LDoc: ITomlDocument;
begin
  Check(TryTomlParse('answer = 42', LDoc), 'try parse success');
  Check(LDoc <> nil, 'doc assigned');
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(42), LDoc.Root.Get('answer').AsInt, 'answer = 42');
end;

procedure TestTryTomlParseFailureReturnsDiagnosticDoc;
var
  LDoc: ITomlDocument;
begin
  Check(not TryTomlParse('= invalid', LDoc), 'try parse failure');
  Check(LDoc <> nil, 'diagnostic doc assigned');
  Check(LDoc.HasError, 'diagnostic doc has error');
end;

procedure TestParseUnexpectedEndOfInputPosition;
var
  LDoc: ITomlDocument;
  LErr: TTomlError;
begin
  LDoc := TomlParse('key = ');
  Check(LDoc.HasError, 'has eof error');
  LErr := LDoc.Error;
  CheckEqual('unexpected end of input', LErr.Message.ToString,
    'diagnostic message');
  CheckEqual(Int64(6), Int64(LErr.Offset), 'diagnostic byte offset');
  CheckEqual(Int64(1), Int64(LErr.Line), 'diagnostic line');
  CheckEqual(Int64(7), Int64(LErr.Col), 'diagnostic column');
end;

procedure TestParseInvalidEscapeDiagnosticMessage;
begin
  CheckParseErrorMessage('s = "\q"', 'invalid escape sequence',
    'invalid escape');
end;

procedure TestParseSignedBasePrefixDiagnosticMessage;
begin
  CheckParseErrorMessage('n = +0x10',
    'sign not allowed with base prefix', 'signed base prefix');
end;

procedure TestParseFractionalSecondsDiagnosticMessage;
begin
  CheckParseErrorMessage('dt = 1979-05-27T07:32:00.Z',
    'fractional seconds need at least 1 digit', 'fractional seconds');
end;

procedure TestAutoRelease;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse('x = 1');
  CheckEqual(Int64(1), LDoc.Root.Get('x').AsInt, 'x = 1');
  LDoc := nil;
  Check(True, 'no crash after release');
end;

procedure TestBuilder;
var
  LB: ITomlBuilder;
  LDoc: ITomlDocument;
begin
  LB := TomlBuilder;
  LB.Key('name'); LB.Str('Bob');
  LB.Key('age'); LB.Int(25);
  LDoc := TomlParse(LB.ToString);
  Check(not LDoc.HasError, 'round-trip no error');
  Check(LDoc.Root.Get('name').AsStr.Equals(
    TStringView.Create(PAnsiChar('Bob'), 3)), 'name = Bob');
  CheckEqual(Int64(25), LDoc.Root.Get('age').AsInt, 'age = 25');
end;

procedure TestBuilderTable;
var
  LB: ITomlBuilder;
  LDoc: ITomlDocument;
begin
  LB := TomlBuilder;
  LB.BeginTable('server');
  LB.Key('host'); LB.Str('0.0.0.0');
  LB.Key('port'); LB.Int(443);
  LDoc := TomlParse(LB.ToString);
  Check(not LDoc.HasError, 'no error');
  CheckEqual(Int64(443), LDoc.Root.Get('server').Get('port').AsInt, 'port = 443');
end;

procedure TestStringify;
var
  LDoc: ITomlDocument;
  LStr: string;
begin
  LDoc := TomlParse('name = "Alice"' + #10 + 'age = 30');
  LStr := LDoc.Stringify;
  Check(Length(LStr) > 0, 'stringify not empty');
  Check(Pos('name', LStr) > 0, 'contains name');
  Check(Pos('Alice', LStr) > 0, 'contains Alice');
end;

procedure TestRealWorldConfig;
var
  LDoc: ITomlDocument;
const
  CONFIG =
    '[package]' + #10 +
    'name = "my-app"' + #10 +
    'version = "1.0.0"' + #10 +
    'authors = ["Alice", "Bob"]' + #10 +
    '' + #10 +
    '[dependencies]' + #10 +
    'http = "^2.0"' + #10 +
    'json = "^1.5"' + #10;
begin
  LDoc := TomlParse(CONFIG);
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('package').Get('name').AsStr.Equals(
    TStringView.Create(PAnsiChar('my-app'), 6)), 'package.name');
  CheckEqual(Int64(2), LDoc.Root.Get('package').Get('authors').ArrayLen, '2 authors');
  Check(LDoc.Root.Get('dependencies').Has('http'), 'has http dep');
end;

procedure TestBuilderAllTypes;
var
  LB: ITomlBuilder;
  LDoc: ITomlDocument;
begin
  LB := TomlBuilder;
  LB.Key('s'); LB.Str('hello');
  LB.Key('i'); LB.Int(42);
  LB.Key('f'); LB.Float(3.14);
  LB.Key('b'); LB.Bool(True);
  LB.Key('dt'); LB.DateTime(TomlDateTimeWithOffset(2024, 1, 15, 10, 30, 0, 0, 0));
  LB.Key('arr');
  LB.BeginArray; LB.Int(1); LB.Int(2); LB.Int(3); LB.EndArray;
  LB.Key('tbl');
  LB.BeginInlineTable; LB.Key('x'); LB.Int(1); LB.EndInlineTable;
  LB.Comment('a comment');
  LB.Newline;
  LDoc := TomlParse(LB.ToString);
  Check(not LDoc.HasError, 'all types parse ok');
  CheckEqual(Int64(42), LDoc.Root.Get('i').AsInt, 'int');
  Check(LDoc.Root.Get('b').AsBool, 'bool');
  CheckEqual(Int64(3), LDoc.Root.Get('arr').ArrayLen, 'array len');
  Check(LDoc.Root.Get('tbl').IsTable, 'inline table');
end;

procedure TestBuilderArrayTable;
var
  LB: ITomlBuilder;
  LDoc: ITomlDocument;
begin
  LB := TomlBuilder;
  LB.BeginArrayTable('items');
  LB.Key('name'); LB.Str('first');
  LB.BeginArrayTable('items');
  LB.Key('name'); LB.Str('second');
  LDoc := TomlParse(LB.ToString);
  Check(not LDoc.HasError, 'array table parse ok');
  CheckEqual(Int64(2), LDoc.Root.Get('items').ArrayLen, '2 items');
end;

procedure TestBuilderAsViewLen;
var
  LB: ITomlBuilder;
begin
  LB := TomlBuilder(128);
  LB.Key('x'); LB.Int(1);
  Check(LB.Len > 0, 'Len > 0');
  Check(LB.AsView.Len = LB.Len, 'AsView.Len = Len');
  Check(Length(LB.ToString) > 0, 'ToString not empty');
end;

procedure TestParseWith;
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParseWith('key = "value"', DefaultAllocator);
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.Get('key').AsStr.Equals(
    TStringView.Create(PAnsiChar('value'), 5)), 'key = value');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml (facade)');
  T.Run('parse simple', @TestParseSimple);
  T.Run('parse nested', @TestParseNested);
  T.Run('parse error', @TestParseError);
  T.Run('TryTomlParse success', @TestTryTomlParseSuccess);
  T.Run('TryTomlParse failure returns diagnostic doc', @TestTryTomlParseFailureReturnsDiagnosticDoc);
  T.Run('parse unexpected end of input position',
    @TestParseUnexpectedEndOfInputPosition);
  T.Run('parse invalid escape diagnostic message',
    @TestParseInvalidEscapeDiagnosticMessage);
  T.Run('parse signed base prefix diagnostic message',
    @TestParseSignedBasePrefixDiagnosticMessage);
  T.Run('parse fractional seconds diagnostic message',
    @TestParseFractionalSecondsDiagnosticMessage);
  T.Run('auto release', @TestAutoRelease);
  T.Run('builder', @TestBuilder);
  T.Run('builder table', @TestBuilderTable);
  T.Run('stringify', @TestStringify);
  T.Run('real-world config', @TestRealWorldConfig);
  T.Run('builder all types', @TestBuilderAllTypes);
  T.Run('builder array table', @TestBuilderArrayTable);
  T.Run('builder AsView/Len', @TestBuilderAsViewLen);
  T.Run('TomlParseWith', @TestParseWith);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
