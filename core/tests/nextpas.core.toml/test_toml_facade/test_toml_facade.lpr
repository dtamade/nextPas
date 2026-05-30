program test_toml_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.toml.base,
  nextpas.core.toml.value,
  nextpas.core.toml.builder,
  nextpas.core.toml,
  nextpas.core.testing;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.toml (facade)');
  T.Run('parse simple', @TestParseSimple);
  T.Run('parse nested', @TestParseNested);
  T.Run('parse error', @TestParseError);
  T.Run('auto release', @TestAutoRelease);
  T.Run('builder', @TestBuilder);
  T.Run('builder table', @TestBuilderTable);
  T.Run('stringify', @TestStringify);
  T.Run('real-world config', @TestRealWorldConfig);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
