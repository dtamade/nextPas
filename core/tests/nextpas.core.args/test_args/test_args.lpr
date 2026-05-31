program test_args;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.args,
  nextpas.core.testing;

var
  T: TTestRunner;

{ === Basic flag/string/int (existing coverage) === }

procedure TestEmptyParse;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', 'desc');
  LA.SetAutoHelp(False);
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

{ === Error paths === }

procedure TestUnknownOptionRaises;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LA.SetAutoHelp(False);
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
  LA.SetAutoHelp(False);
  Check(not LA.TryParseFrom(['--unknown']), 'TryParse returns false');
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

{ === NEW: StringList (repeatable) === }

procedure TestStringListSingle;
var
  LA: TArgParser;
  LList: TStringArray;
begin
  LA := TArgParser.Create('test', '');
  LA.AddStringList('include', 'I', 'include path');
  LA.ParseFrom(['-I', '/usr/include']);
  LList := LA.GetStringList('include');
  CheckEqual(Int64(1), Int64(Length(LList)), '1 item');
  CheckEqual('/usr/include', LList[0], 'item 0');
  LA.Free;
end;

procedure TestStringListMultiple;
var
  LA: TArgParser;
  LList: TStringArray;
begin
  LA := TArgParser.Create('test', '');
  LA.AddStringList('include', 'I', 'include path');
  LA.ParseFrom(['-I', '/a', '-I', '/b', '--include', '/c']);
  LList := LA.GetStringList('include');
  CheckEqual(Int64(3), Int64(Length(LList)), '3 items');
  CheckEqual('/a', LList[0], 'item 0');
  CheckEqual('/b', LList[1], 'item 1');
  CheckEqual('/c', LList[2], 'item 2');
  LA.Free;
end;

procedure TestStringListEquals;
var
  LA: TArgParser;
  LList: TStringArray;
begin
  LA := TArgParser.Create('test', '');
  LA.AddStringList('define', 'D', 'define');
  LA.ParseFrom(['--define=FOO', '--define=BAR']);
  LList := LA.GetStringList('define');
  CheckEqual(Int64(2), Int64(Length(LList)), '2 items');
  CheckEqual('FOO', LList[0], 'item 0');
  CheckEqual('BAR', LList[1], 'item 1');
  LA.Free;
end;

procedure TestStringListReset;
var
  LA: TArgParser;
  LList: TStringArray;
begin
  LA := TArgParser.Create('test', '');
  LA.AddStringList('include', 'I', '');
  LA.ParseFrom(['-I', '/a', '-I', '/b']);
  LA.ParseFrom(['-I', '/c']);
  LList := LA.GetStringList('include');
  CheckEqual(Int64(1), Int64(Length(LList)), 'reset to 1 item');
  CheckEqual('/c', LList[0], 'only /c');
  LA.Free;
end;
// PLACEHOLDER_TEST_CONTINUE

{ === NEW: Required flags === }

procedure TestRequiredStringPresent;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddRequiredString('target', 't', 'target triple');
  LA.ParseFrom(['--target', 'x86_64-linux']);
  CheckEqual('x86_64-linux', LA.GetString('target'), 'target value');
  LA.Free;
end;

procedure TestRequiredStringMissing;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LA.AddRequiredString('target', 't', 'target triple');
  LGot := False;
  try
    LA.ParseFrom([]);
  except
    on EArgParseError do LGot := True;
  end;
  Check(LGot, 'missing required raises');
  LA.Free;
end;

{ === NEW: Required positional === }

procedure TestRequiredPositionalPresent;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddPositional('input', 'input file', True);
  LA.ParseFrom(['main.pas']);
  CheckEqual('main.pas', LA.Positional(0), 'positional 0');
  LA.Free;
end;

procedure TestRequiredPositionalMissing;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LA.AddPositional('input', 'input file', True);
  LGot := False;
  try
    LA.ParseFrom([]);
  except
    on EArgParseError do LGot := True;
  end;
  Check(LGot, 'missing required positional raises');
  LA.Free;
end;

procedure TestOptionalPositional;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddPositional('input', 'input file', False);
  LA.ParseFrom([]);
  CheckEqual(Int64(0), Int64(LA.PositionalCount), 'no positionals ok');
  LA.Free;
end;

{ === NEW: Choices === }

procedure TestChoiceValid;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddChoice('target', 't', 'target', ['x86_64', 'aarch64', 'wasm32'], 'x86_64');
  LA.ParseFrom(['--target', 'aarch64']);
  CheckEqual('aarch64', LA.GetString('target'), 'choice = aarch64');
  LA.Free;
end;

procedure TestChoiceDefault;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddChoice('target', 't', 'target', ['x86_64', 'aarch64'], 'x86_64');
  LA.ParseFrom([]);
  CheckEqual('x86_64', LA.GetString('target'), 'default = x86_64');
  LA.Free;
end;

procedure TestChoiceInvalid;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LA.AddChoice('target', 't', 'target', ['x86_64', 'aarch64'], 'x86_64');
  LGot := False;
  try
    LA.ParseFrom(['--target', 'mips']);
  except
    on EArgParseError do LGot := True;
  end;
  Check(LGot, 'invalid choice raises');
  LA.Free;
end;

procedure TestChoiceShort;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddChoice('mode', 'm', 'mode', ['debug', 'release'], 'debug');
  LA.ParseFrom(['-m', 'release']);
  CheckEqual('release', LA.GetString('mode'), 'short choice');
  LA.Free;
end;

procedure TestChoiceEquals;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddChoice('mode', 'm', 'mode', ['debug', 'release'], 'debug');
  LA.ParseFrom(['--mode=release']);
  CheckEqual('release', LA.GetString('mode'), 'equals choice');
  LA.Free;
end;
// PLACEHOLDER_TEST_CONTINUE_2

{ === NEW: Short flag cluster === }

procedure TestClusterFlags;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', '');
  LA.AddFlag('debug', 'd', '');
  LA.AddFlag('force', 'f', '');
  LA.ParseFrom(['-vdf']);
  Check(LA.GetBool('verbose'), 'v in cluster');
  Check(LA.GetBool('debug'), 'd in cluster');
  Check(LA.GetBool('force'), 'f in cluster');
  LA.Free;
end;

procedure TestClusterWithValue;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', '');
  LA.AddInt('opt-level', 'O', '', 0);
  LA.ParseFrom(['-vO3']);
  Check(LA.GetBool('verbose'), 'v in cluster');
  CheckEqual(Int64(3), LA.GetInt('opt-level'), 'O3 from cluster');
  LA.Free;
end;

procedure TestClusterWithStringValue;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', '');
  LA.AddString('output', 'o', '', '');
  LA.ParseFrom(['-vo', 'file.txt']);
  Check(LA.GetBool('verbose'), 'v in cluster');
  CheckEqual('file.txt', LA.GetString('output'), 'o gets next arg');
  LA.Free;
end;

procedure TestClusterWithInlineString;
var
  LA: TArgParser;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', '');
  LA.AddString('output', 'o', '', '');
  LA.ParseFrom(['-vofile.txt']);
  Check(LA.GetBool('verbose'), 'v in cluster');
  CheckEqual('file.txt', LA.GetString('output'), 'o inline value');
  LA.Free;
end;

{ === NEW: Duplicate detection === }

procedure TestDuplicateNameRaises;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', '');
  LGot := False;
  try
    LA.AddString('verbose', 'x', '', '');
  except
    on EArgParseError do LGot := True;
  end;
  Check(LGot, 'duplicate name raises');
  LA.Free;
end;

procedure TestDuplicateShortRaises;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LA.AddFlag('verbose', 'v', '');
  LGot := False;
  try
    LA.AddFlag('version', 'v', '');
  except
    on EArgParseError do LGot := True;
  end;
  Check(LGot, 'duplicate short raises');
  LA.Free;
end;

{ === NEW: Auto --help / --version === }

procedure TestAutoHelp;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', 'A test app');
  LA.AddFlag('verbose', 'v', '');
  LGot := False;
  try
    LA.ParseFrom(['--help']);
  except
    on EArgHelp do LGot := True;
  end;
  Check(LGot, '--help raises EArgHelp');
  LA.Free;
end;

procedure TestAutoHelpShort;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LGot := False;
  try
    LA.ParseFrom(['-h']);
  except
    on EArgHelp do LGot := True;
  end;
  Check(LGot, '-h raises EArgHelp');
  LA.Free;
end;

procedure TestAutoVersion;
var
  LA: TArgParser;
  LGot: Boolean;
  LMsg: string;
begin
  LA := TArgParser.Create('test', '');
  LA.SetVersion('1.2.3');
  LGot := False;
  LMsg := '';
  try
    LA.ParseFrom(['--version']);
  except
    on E: EArgVersion do
    begin
      LGot := True;
      LMsg := E.Message;
    end;
  end;
  Check(LGot, '--version raises EArgVersion');
  CheckEqual('1.2.3', LMsg, 'version message');
  LA.Free;
end;

procedure TestAutoHelpDisabled;
var
  LA: TArgParser;
  LGot: Boolean;
begin
  LA := TArgParser.Create('test', '');
  LA.SetAutoHelp(False);
  LGot := False;
  try
    LA.ParseFrom(['--help']);
  except
    on EArgParseError do LGot := True;
  end;
  Check(LGot, 'disabled help -> unknown option');
  LA.Free;
end;

{ === Mixed: compiler-like scenario === }

procedure TestCompilerScenario;
var
  LA: TArgParser;
  LIncludes: TStringArray;
begin
  LA := TArgParser.Create('nextpas', 'NextPas compiler');
  LA.SetAutoHelp(False);
  LA.AddFlag('verbose', 'v', 'verbose output');
  LA.AddChoice('target', 't', 'target triple', ['x86_64', 'aarch64', 'wasm32'], 'x86_64');
  LA.AddInt('opt-level', 'O', 'optimization level', 2);
  LA.AddStringList('include', 'I', 'include path');
  LA.AddRequiredString('output', 'o', 'output file');
  LA.AddPositional('input', 'input file', True);
  LA.ParseFrom(['-vO3', '-I', '/usr/include', '-I', '/opt/lib',
    '--target=aarch64', '-o', 'main', 'input.pas']);
  Check(LA.GetBool('verbose'), 'verbose');
  CheckEqual(Int64(3), LA.GetInt('opt-level'), 'O3');
  CheckEqual('aarch64', LA.GetString('target'), 'target');
  CheckEqual('main', LA.GetString('output'), 'output');
  CheckEqual('input.pas', LA.Positional(0), 'input file');
  LIncludes := LA.GetStringList('include');
  CheckEqual(Int64(2), Int64(Length(LIncludes)), '2 includes');
  CheckEqual('/usr/include', LIncludes[0], 'include 0');
  CheckEqual('/opt/lib', LIncludes[1], 'include 1');
  LA.Free;
end;

{ === HelpText format === }

procedure TestHelpTextFormat;
var
  LA: TArgParser;
  LHelp: string;
begin
  LA := TArgParser.Create('myapp', 'My application');
  LA.AddFlag('verbose', 'v', 'Enable verbose');
  LA.AddString('config', 'c', 'Config file', '/etc/app.toml');
  LA.AddInt('port', 'p', 'Port number', 443);
  LA.AddChoice('mode', 'm', 'Run mode', ['debug', 'release'], 'debug');
  LA.AddStringList('include', 'I', 'Include paths');
  LA.AddRequiredString('output', 'o', 'Output file');
  LA.AddPositional('input', 'input file', True);
  LA.AddPositional('extra', 'extra files', False);
  LHelp := LA.HelpText;
  Check(Pos('Usage:', LHelp) > 0, 'has Usage');
  Check(Pos('<input>', LHelp) > 0, 'has required positional');
  Check(Pos('[extra]', LHelp) > 0, 'has optional positional');
  Check(Pos('--verbose', LHelp) > 0, 'has --verbose');
  Check(Pos('--config', LHelp) > 0, 'has --config');
  Check(Pos('(required)', LHelp) > 0, 'has required marker');
  Check(Pos('<string>...', LHelp) > 0, 'has stringlist marker');
  Check(Pos('debug, release', LHelp) > 0, 'has choices');
  LA.Free;
end;

begin
  T := TTestRunner.Create('nextpas.core.args');
  { Basic }
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
  { Errors }
  T.Run('unknown raises', @TestUnknownOptionRaises);
  T.Run('missing value raises', @TestMissingValueRaises);
  T.Run('invalid int raises', @TestInvalidIntRaises);
  T.Run('TryParse false', @TestTryParseFalse);
  T.Run('flag rejects value', @TestFlagRejectsValue);
  T.Run('parse reset state', @TestParseResetState);
  { StringList }
  T.Run('stringlist single', @TestStringListSingle);
  T.Run('stringlist multiple', @TestStringListMultiple);
  T.Run('stringlist equals', @TestStringListEquals);
  T.Run('stringlist reset', @TestStringListReset);
  { Required }
  T.Run('required string present', @TestRequiredStringPresent);
  T.Run('required string missing', @TestRequiredStringMissing);
  T.Run('required positional present', @TestRequiredPositionalPresent);
  T.Run('required positional missing', @TestRequiredPositionalMissing);
  T.Run('optional positional', @TestOptionalPositional);
  { Choices }
  T.Run('choice valid', @TestChoiceValid);
  T.Run('choice default', @TestChoiceDefault);
  T.Run('choice invalid', @TestChoiceInvalid);
  T.Run('choice short', @TestChoiceShort);
  T.Run('choice equals', @TestChoiceEquals);
  { Cluster }
  T.Run('cluster flags', @TestClusterFlags);
  T.Run('cluster with int value', @TestClusterWithValue);
  T.Run('cluster with string value', @TestClusterWithStringValue);
  T.Run('cluster inline string', @TestClusterWithInlineString);
  { Duplicate detection }
  T.Run('duplicate name raises', @TestDuplicateNameRaises);
  T.Run('duplicate short raises', @TestDuplicateShortRaises);
  { Auto help/version }
  T.Run('auto help', @TestAutoHelp);
  T.Run('auto help short', @TestAutoHelpShort);
  T.Run('auto version', @TestAutoVersion);
  T.Run('auto help disabled', @TestAutoHelpDisabled);
  { Integration }
  T.Run('compiler scenario', @TestCompilerScenario);
  T.Run('help text format', @TestHelpTextFormat);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
