program test_args;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.args,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestEmptyParse;
var A: TArgParser;
begin
  A.Init('test', 'desc');
  Check(A.ParseFrom([]), 'empty parse ok');
  CheckEqual(Int64(0), Int64(A.PositionalCount), 'no positionals');
end;

procedure TestFlag;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddFlag('verbose', 'v', 'verbose');
  Check(A.ParseFrom(['--verbose']), 'parse ok');
  Check(A.GetBool('verbose'), 'verbose = true');
  Check(A.IsPresent('verbose'), 'verbose present');
end;

procedure TestFlagShort;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddFlag('verbose', 'v', 'verbose');
  Check(A.ParseFrom(['-v']), 'parse ok');
  Check(A.GetBool('verbose'), '-v = true');
end;

procedure TestFlagDefault;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddFlag('verbose', 'v', 'verbose');
  Check(A.ParseFrom([]), 'parse ok');
  Check(not A.GetBool('verbose'), 'default = false');
  Check(not A.IsPresent('verbose'), 'not present');
end;

procedure TestStringOption;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddString('output', 'o', 'output file', 'default.txt');
  Check(A.ParseFrom(['--output', 'result.txt']), 'parse ok');
  CheckEqual('result.txt', A.GetString('output'), 'output = result.txt');
end;

procedure TestStringOptionEquals;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddString('output', 'o', 'output file', '');
  Check(A.ParseFrom(['--output=file.bin']), 'parse ok');
  CheckEqual('file.bin', A.GetString('output'), 'output = file.bin');
end;

procedure TestStringShort;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddString('output', 'o', 'output', '');
  Check(A.ParseFrom(['-o', 'out.txt']), 'parse ok');
  CheckEqual('out.txt', A.GetString('output'), '-o out.txt');
end;

procedure TestIntOption;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddInt('port', 'p', 'port', 8080);
  Check(A.ParseFrom(['--port', '9090']), 'parse ok');
  CheckEqual(Int64(9090), A.GetInt('port'), 'port = 9090');
end;

procedure TestIntDefault;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddInt('port', 'p', 'port', 8080);
  Check(A.ParseFrom([]), 'parse ok');
  CheckEqual(Int64(8080), A.GetInt('port'), 'default = 8080');
end;

procedure TestPositionals;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddFlag('verbose', 'v', '');
  Check(A.ParseFrom(['-v', 'file1.txt', 'file2.txt']), 'parse ok');
  Check(A.GetBool('verbose'), 'verbose');
  CheckEqual(Int64(2), Int64(A.PositionalCount), '2 positionals');
  CheckEqual('file1.txt', A.Positional(0), 'pos 0');
  CheckEqual('file2.txt', A.Positional(1), 'pos 1');
end;

procedure TestDoubleDash;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddFlag('verbose', 'v', '');
  Check(A.ParseFrom(['--', '--verbose', '-v']), 'parse ok');
  Check(not A.GetBool('verbose'), 'verbose not set');
  CheckEqual(Int64(2), Int64(A.PositionalCount), '2 positionals after --');
  CheckEqual('--verbose', A.Positional(0), 'pos 0 = --verbose');
end;

procedure TestUnknownOption;
var A: TArgParser;
begin
  A.Init('test', '');
  Check(not A.ParseFrom(['--unknown']), 'parse fails');
  Check(A.HasError, 'has error');
  Check(Pos('unknown', A.Error) > 0, 'error mentions unknown');
end;

procedure TestMissingValue;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddString('output', 'o', '', '');
  Check(not A.ParseFrom(['--output']), 'parse fails');
  Check(A.HasError, 'has error');
  Check(Pos('requires', A.Error) > 0, 'error mentions requires');
end;

procedure TestInvalidInt;
var A: TArgParser;
begin
  A.Init('test', '');
  A.AddInt('port', 'p', '', 0);
  Check(not A.ParseFrom(['--port', 'abc']), 'parse fails');
  Check(A.HasError, 'has error');
  Check(Pos('invalid integer', A.Error) > 0, 'error mentions invalid');
end;

procedure TestMixed;
var A: TArgParser;
begin
  A.Init('nextpas', 'NextPas compiler');
  A.AddFlag('verbose', 'v', 'verbose');
  A.AddString('output', 'o', 'output', 'a.out');
  A.AddInt('opt-level', 'O', 'optimization', 2);
  Check(A.ParseFrom(['-v', '--output', 'main', '-O', '3', 'input.pas']), 'parse ok');
  Check(A.GetBool('verbose'), 'verbose');
  CheckEqual('main', A.GetString('output'), 'output');
  CheckEqual(Int64(3), A.GetInt('opt-level'), 'opt-level');
  CheckEqual(Int64(1), Int64(A.PositionalCount), '1 positional');
  CheckEqual('input.pas', A.Positional(0), 'input file');
end;

procedure TestHelpText;
var A: TArgParser;
begin
  A.Init('myapp', 'My application');
  A.AddFlag('verbose', 'v', 'Enable verbose');
  A.AddString('config', 'c', 'Config file', '/etc/app.toml');
  A.AddInt('port', 'p', 'Port number', 443);
  Check(Pos('Usage:', A.HelpText) > 0, 'has Usage');
  Check(Pos('--verbose', A.HelpText) > 0, 'has --verbose');
  Check(Pos('--config', A.HelpText) > 0, 'has --config');
  Check(Pos('443', A.HelpText) > 0, 'has default 443');
end;

procedure TestGetNonexistent;
var A: TArgParser;
begin
  A.Init('test', '');
  A.ParseFrom([]);
  CheckEqual('', A.GetString('nope'), 'nonexistent string = empty');
  CheckEqual(Int64(0), A.GetInt('nope'), 'nonexistent int = 0');
  Check(not A.GetBool('nope'), 'nonexistent bool = false');
  CheckEqual('', A.Positional(99), 'out of bounds positional = empty');
end;

begin
  T := TTestRunner.Create('nextpas.core.args');
  T.Run('empty parse', @TestEmptyParse);
  T.Run('flag', @TestFlag);
  T.Run('flag short', @TestFlagShort);
  T.Run('flag default', @TestFlagDefault);
  T.Run('string option', @TestStringOption);
  T.Run('string option =', @TestStringOptionEquals);
  T.Run('string short', @TestStringShort);
  T.Run('int option', @TestIntOption);
  T.Run('int default', @TestIntDefault);
  T.Run('positionals', @TestPositionals);
  T.Run('double dash', @TestDoubleDash);
  T.Run('unknown option', @TestUnknownOption);
  T.Run('missing value', @TestMissingValue);
  T.Run('invalid int', @TestInvalidInt);
  T.Run('mixed', @TestMixed);
  T.Run('help text', @TestHelpText);
  T.Run('get nonexistent', @TestGetNonexistent);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
