program bench_log;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.log.intf,
  nextpas.core.log;

const
  ITERS = 1000000;
  ITERS_IO = 100000;

procedure Bench(const AName: string; const AIters: Int64; const AElapsed: TDuration);
var
  LNs: Int64;
  LNsPerOp: Double;
begin
  LNs := AElapsed.AsNanoseconds;
  if AIters > 0 then
    LNsPerOp := LNs / AIters
  else
    LNsPerOp := 0;
  WriteLn(Format('  %-40s %10d iters  %8.2f ms  %8.1f ns/op',
    [AName, AIters, LNs / 1000000.0, LNsPerOp]));
end;

{ TNullHandler — no-op handler for measuring pure logging overhead }

type
  TNullHandler = class(TInterfacedObject, ILogHandler)
  private
    FMinLevel: TLogLevel;
  public
    constructor Create(AMinLevel: TLogLevel);
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TNullHandler.Create(AMinLevel: TLogLevel);
begin
  inherited Create;
  FMinLevel := AMinLevel;
end;

function TNullHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure TNullHandler.Handle(const ARecord: TLogRecord);
begin
  { intentionally empty — measures pure logging overhead }
end;

procedure TNullHandler.Flush;
begin
end;

function TNullHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
begin
  Result := Self;
end;

function TNullHandler.WithGroup(const AName: string): ILogHandler;
begin
  Result := Self;
end;

{ Benchmarks }

procedure BenchLogDisabled;
var
  LL: TLogger;
  LI: Int32;
  LStart: TInstant;
begin
  { Log at level below threshold — should be near-zero cost }
  LL := TLogger.New(TNullHandler.Create(llError), llError);
  LStart := TInstant.Now;
  for LI := 1 to ITERS do
    LL.Debug^.Str('key', 'value')^.Msg('disabled');
  Bench('Disabled (below threshold)', ITERS, LStart.Elapsed);
end;

procedure BenchLogSimple;
var
  LL: TLogger;
  LI: Int32;
  LStart: TInstant;
begin
  { Simple message to null handler }
  LL := TLogger.New(TNullHandler.Create(llDebug), llDebug);
  LStart := TInstant.Now;
  for LI := 1 to ITERS do
    LL.Info^.Msg('hello');
  Bench('Simple Msg (null handler)', ITERS, LStart.Elapsed);
end;

{ PLACEHOLDER_BENCH_REST }

procedure BenchLogWithAttrs;
var
  LL: TLogger;
  LI: Int32;
  LStart: TInstant;
begin
  { Message with multiple attrs to null handler }
  LL := TLogger.New(TNullHandler.Create(llDebug), llDebug);
  LStart := TInstant.Now;
  for LI := 1 to ITERS do
    LL.Info^.Str('key', 'value')^.Int('count', 42)^.Bool('ok', True)^.Msg('test');
  Bench('WithAttrs Str+Int+Bool (null)', ITERS, LStart.Elapsed);
end;

procedure BenchLogConsole;
var
  LL: TLogger;
  LI: Int32;
  LStart: TInstant;
begin
  { Console handler writing to stderr (redirected to /dev/null by caller) }
  LL := TLogger.New(NewConsoleHandler(llDebug), llDebug);
  LStart := TInstant.Now;
  for LI := 1 to ITERS_IO do
    LL.Info^.Str('key', 'value')^.Msg('console bench');
  Bench('Console handler (stderr)', ITERS_IO, LStart.Elapsed);
end;

procedure BenchLogJson;
var
  LL: TLogger;
  LI: Int32;
  LStart: TInstant;
begin
  { JSON handler writing to stderr (redirected to /dev/null by caller) }
  LL := TLogger.New(NewJsonHandler(llDebug), llDebug);
  LStart := TInstant.Now;
  for LI := 1 to ITERS_IO do
    LL.Info^.Str('key', 'value')^.Int('n', 42)^.Msg('json bench');
  Bench('JSON handler (stderr)', ITERS_IO, LStart.Elapsed);
end;

procedure BenchLogFile;
var
  LL: TLogger;
  LI: Int32;
  LStart: TInstant;
  LPath: string;
begin
  LPath := '/tmp/bench_log_' + IntToStr(GetProcessID) + '.txt';
  LL := TLogger.New(NewFileHandler(LPath, llDebug), llDebug);
  LStart := TInstant.Now;
  for LI := 1 to ITERS_IO do
    LL.Info^.Str('key', 'value')^.Int('n', LI)^.Msg('file bench');
  Bench('File handler (/tmp)', ITERS_IO, LStart.Elapsed);
  { Release handler and cleanup }
  LL := TLogger.New(TNullHandler.Create(llFatal), llFatal);
  DeleteFile(LPath);
end;

begin
  WriteLn('=== nextpas.core.log benchmarks ===');
  WriteLn('');

  BenchLogDisabled;
  BenchLogSimple;
  BenchLogWithAttrs;
  BenchLogConsole;
  BenchLogJson;
  BenchLogFile;

  WriteLn('');
  WriteLn('Done.');
end.
