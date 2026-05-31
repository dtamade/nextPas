program test_args;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.args,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestEmptyParse;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', 'desc');
  LA.ParseFrom([]);
  CheckEqual(Int64(0), Int64(LA.PositionalCount), 'no positionals');
  LA.Free;
end;

procedure TestFlag;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', 'verbose');
  LA.ParseFrom(['--verbose']);
  Check(LA.GetBool('verbose'), 'verbose = true');
  Check(LA.IsPresent('verbose'), 'verbose present');
  LA.Free;
end;

procedure TestFlagShort;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', 'verbose');
  LA.ParseFrom(['-v']);
  Check(LA.GetBool('verbose'), '-v = true');
  LA.Free;
end;

procedure TestFlagDefault;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', 'verbose');
  LA.ParseFrom([]);
  Check(not LA.GetBool('verbose'), 'default = false');
  Check(not LA.IsPresent('verbose'), 'not present');
  LA.Free;
end;

procedure TestStringOption;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddString('output', 'o', 'output file', 'default.txt');
  LA.ParseFrom(['--output', 'result.txt']);
  CheckEqual('result.txt', LA.GetString('output'), 'output = result.txt');
  LA.Free;
end;

procedure TestStringOptionEquals;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddString('output', 'o', 'output file', '');
  LA.ParseFrom(['--output=file.bin']);
  CheckEqual('file.bin', LA.GetString('output'), 'output = file.bin');
  LA.Free;
end;

procedure TestIntOption;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddInt('port', 'p', 'port', 8080);
  LA.ParseFrom(['--port', '9090']);
  CheckEqual(Int64(9090), LA.GetInt('port'), 'port = 9090');
  LA.Free;
end;

procedure TestIntDefault;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddInt('port', 'p', 'port', 8080);
  LA.ParseFrom([]);
  CheckEqual(Int64(8080), LA.GetInt('port'), 'default = 8080');
  LA.Free;
end;

procedure TestPositionals;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', '');
  LA.ParseFrom(['-v', 'file1.txt', 'file2.txt']);
  Check(LA.GetBool('verbose'), 'verbose');
  CheckEqual(Int64(2), Int64(LA.PositionalCount), '2 positionals');
  CheckEqual('file1.txt', LA.Positional(0), 'pos 0');
  CheckEqual('file2.txt', LA.Positional(1), 'pos 1');
  LA.Free;
end;

procedure TestDoubleDash;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', '');
  LA.ParseFrom(['--', '--verbose', '-v']);
  Check(not LA.GetBool('verbose'), 'verbose not set');
  CheckEqual(Int64(2), Int64(LA.PositionalCount), '2 positionals after --');
  CheckEqual('--verbose', LA.Positional(0), 'pos 0 = --verbose');
  LA.Free;
end;

procedure TestUnknownOptionRaises;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LGot := False;
  try
    LA.ParseFrom(['--unknown']);
  except
    on EArgParseError do LGot := True;
  end;
  Check(LGot, 'unknown option raises EArgParseError');
  LA.Free;
end;

procedure TestMissingValueRaises;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LA.AddString('output', 'o', '', '');
  LGot := False;
  try
    LA.ParseFrom(['--output']);
  except
    on EArgParseError do LGot := True;
  end;
  Check(LGot, 'missing value raises EArgParseError');
  LA.Free;
end;

procedure TestInvalidIntRaises;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LA.AddInt('port', 'p', '', 0);
  LGot := False;
  try
    LA.ParseFrom(['--port', 'abc']);
  except
    on EArgParseError do LGot := True;
  end;
  Check(LGot, 'invalid int raises EArgParseError');
  LA.Free;
end;

procedure TestTryParseFalse;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  Check(not LA.TryParseFrom(['--unknown']), 'TryParse returns false');
  LA.Free;
end;

procedure TestMixed;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('nextpas', 'NextPas compiler');
  LA.AddFlag('verbose', 'v', 'verbose');
  LA.AddString('output', 'o', 'output', 'a.out');
  LA.AddInt('opt-level', 'O', 'optimization', 2);
  LA.ParseFrom(['-v', '--output', 'main', '-O', '3', 'input.pas']);
  Check(LA.GetBool('verbose'), 'verbose');
  CheckEqual('main', LA.GetString('output'), 'output');
  CheckEqual(Int64(3), LA.GetInt('opt-level'), 'opt-level');
  CheckEqual(Int64(1), Int64(LA.PositionalCount), '1 positional');
  CheckEqual('input.pas', LA.Positional(0), 'input file');
  LA.Free;
end;

procedure TestHelpText;
var
  LA: TArgParser;
  LHelp: string;
begin
  LA := TArgParser.Create('myapp', 'My application');
  LA.AddFlag('verbose', 'v', 'Enable verbose');
  LA.AddString('config', 'c', 'Config file', '/etc/app.toml');
  LA.AddInt('port', 'p', 'Port number', 443);
  LHelp := LA.HelpText;
  Check(Pos('Usage:', LHelp) > 0, 'has Usage');
  Check(Pos('--verbose', LHelp) > 0, 'has --verbose');
  Check(Pos('--config', LHelp) > 0, 'has --config');
  LA.Free;
end;

procedure TestParseResetState;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', '');
  LA.AddInt('port', 'p', '', 80);
  LA.ParseFrom(['--verbose', '--port', '9090']);
  Check(LA.GetBool('verbose'), 'first parse verbose');
  CheckEqual(Int64(9090), LA.GetInt('port'), 'first parse port');
  LA.ParseFrom([]);
  Check(not LA.GetBool('verbose'), 'second parse verbose reset');
  CheckEqual(Int64(80), LA.GetInt('port'), 'second parse port reset to default');
  Check(not LA.IsPresent('verbose'), 'second parse not present');
  LA.Free;
end;

procedure TestFlagRejectsValue;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', '');
  LGot := False;
  try
    LA.ParseFrom(['--verbose=yes']);
  except
    on EArgParseError do LGot := True;
  end;
  Check(LGot, '--verbose=yes raises EArgParseError');
  LA.Free;
end;

begin
  T := TTestRunner.Create('nextpas.core.args');
  T.Run('empty parse', @TestEmptyParse);
  T.Run('flag', @TestFlag);
  T.Run('flag short', @TestFlagShort);
  T.Run('flag default', @TestFlagDefault);
  T.Run('string option', @TestStringOption);
  T.Run('string option =', @TestStringOptionEquals);
  T.Run('int option', @TestIntOption);
  T.Run('int default', @TestIntDefault);
  T.Run('positionals', @TestPositionals);
  T.Run('double dash', @TestDoubleDash);
  T.Run('unknown raises', @TestUnknownOptionRaises);
  T.Run('missing value raises', @TestMissingValueRaises);
  T.Run('invalid int raises', @TestInvalidIntRaises);
  T.Run('TryParse false', @TestTryParseFalse);
  T.Run('mixed', @TestMixed);
  T.Run('help text', @TestHelpText);
  T.Run('parse reset state', @TestParseResetState);
  T.Run('flag rejects value', @TestFlagRejectsValue);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
