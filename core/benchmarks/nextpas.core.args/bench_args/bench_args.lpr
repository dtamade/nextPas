program bench_args;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.args;

var
  B: TBenchRunner;

procedure BenchParseEmpty(aIters: Int64);
var
  LIt: Int64;
  LP: TArgParser;
begin
  for LIt := 1 to aIters do
  begin
    LP := TArgParser.Create('test', '');
    LP.SetAutoHelp(False);
    LP.ParseFrom([]);
    LP.Free;
  end;
end;

procedure BenchParseFlags(aIters: Int64);
var
  LIt: Int64;
  LP: TArgParser;
begin
  for LIt := 1 to aIters do
  begin
    LP := TArgParser.Create('test', '');
    LP.SetAutoHelp(False);
    LP.AddFlag('verbose', 'v', '');
    LP.AddFlag('debug', 'd', '');
    LP.AddFlag('force', 'f', '');
    LP.AddFlag('quiet', 'q', '');
    LP.AddFlag('recursive', 'r', '');
    LP.ParseFrom(['-v', '-d', '-f', '-q', '-r']);
    LP.Free;
  end;
end;

procedure BenchParseMixed(aIters: Int64);
var
  LIt: Int64;
  LP: TArgParser;
begin
  for LIt := 1 to aIters do
  begin
    LP := TArgParser.Create('nextpas', '');
    LP.SetAutoHelp(False);
    LP.AddFlag('verbose', 'v', '');
    LP.AddString('output', 'o', '', 'a.out');
    LP.AddInt('opt-level', 'O', '', 2);
    LP.AddChoice('target', 't', '', ['x86_64', 'aarch64', 'wasm32'], 'x86_64');
    LP.AddPositional('input', '', True);
    LP.ParseFrom(['-v', '--output', 'main', '-O', '3', '--target=aarch64', 'input.pas']);
    LP.Free;
  end;
end;

procedure BenchParseStringList(aIters: Int64);
var
  LIt: Int64;
  LP: TArgParser;
begin
  for LIt := 1 to aIters do
  begin
    LP := TArgParser.Create('test', '');
    LP.SetAutoHelp(False);
    LP.AddStringList('include', 'I', '');
    LP.ParseFrom(['-I', '/a', '-I', '/b', '-I', '/c', '-I', '/d', '-I', '/e',
                   '-I', '/f', '-I', '/g', '-I', '/h', '-I', '/i', '-I', '/j']);
    LP.Free;
  end;
end;

procedure BenchParseCluster(aIters: Int64);
var
  LIt: Int64;
  LP: TArgParser;
begin
  for LIt := 1 to aIters do
  begin
    LP := TArgParser.Create('test', '');
    LP.SetAutoHelp(False);
    LP.AddFlag('verbose', 'v', '');
    LP.AddFlag('debug', 'd', '');
    LP.AddFlag('force', 'f', '');
    LP.AddInt('opt-level', 'O', '', 0);
    LP.ParseFrom(['-vdfO3']);
    LP.Free;
  end;
end;

procedure BenchSubcommand(aIters: Int64);
var
  LIt: Int64;
  LA: TArgApp;
  LI: Integer;
const
  CMDS: array[0..9] of string = (
    'build', 'run', 'test', 'fmt', 'lint',
    'doc', 'clean', 'install', 'publish', 'check');
begin
  for LIt := 1 to aIters do
  begin
    LA := TArgApp.Create('tool', '', '1.0');
    for LI := 0 to 9 do
      LA.AddCommand(CMDS[LI], '');
    try
      LA.RunFrom(['check']);
    except
    end;
    LA.Free;
  end;
end;

procedure BenchHelpGen(aIters: Int64);
var
  LIt: Int64;
  LP: TArgParser;
  LS: string;
begin
  LP := TArgParser.Create('nextpas', 'NextPas Compiler');
  LP.AddFlag('verbose', 'v', 'Enable verbose output');
  LP.AddFlag('debug', 'd', 'Debug mode');
  LP.AddString('output', 'o', 'Output file', 'a.out');
  LP.AddInt('opt-level', 'O', 'Optimization level', 2);
  LP.AddChoice('target', 't', 'Target', ['x86_64', 'aarch64', 'wasm32'], 'x86_64');
  LP.AddStringList('include', 'I', 'Include path');
  LP.AddRequiredString('config', 'c', 'Config file');
  LP.AddPositional('input', 'Input file', True);
  LP.AddPositional('extra', 'Extra files', False);
  for LIt := 1 to aIters do
    LS := LP.HelpText;
  LP.Free;
  if LS = '' then ;
end;

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.args benchmark ===');
  WriteLn;
  B.Run('ParseEmpty', @BenchParseEmpty);
  B.Run('ParseFlags(5)', @BenchParseFlags);
  B.Run('ParseMixed(compiler-like)', @BenchParseMixed);
  B.Run('ParseStringList(10x-I)', @BenchParseStringList);
  B.Run('ParseCluster(-vdfO3)', @BenchParseCluster);
  B.Run('SubcommandDispatch(10cmds)', @BenchSubcommand);
  B.Run('HelpGeneration', @BenchHelpGen);
  WriteLn;
  B.Summary;
  B.Free;
end.
