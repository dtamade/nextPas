program bench_log;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.log.intf, nextpas.core.log,
  nextpas.core.fs;
type
  TNullHandler = class(TInterfacedObject, ILogHandler)
  private FMinLevel: TLogLevel;
  public
    constructor Create(AMinLevel: TLogLevel);
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;
constructor TNullHandler.Create(AMinLevel: TLogLevel); begin inherited Create; FMinLevel := AMinLevel; end;
function TNullHandler.Enabled(const ALevel: TLogLevel): Boolean; begin Result := ALevel >= FMinLevel; end;
procedure TNullHandler.Handle(const ARecord: TLogRecord); begin end;
procedure TNullHandler.Flush; begin end;
function TNullHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler; begin Result := Self; end;
function TNullHandler.WithGroup(const AName: string): ILogHandler; begin Result := Self; end;
var GSink: UInt64 = 0;
procedure BenchLogDisabled(const ACtx: IBenchContext);
var LL: TLogger;
begin
  LL := TLogger.New(TNullHandler.Create(llInfo), llInfo);
  if LL.Enabled(llDebug) then
    LL.Debug^.Msg('test');
  GSink := GSink xor 1;
end;
procedure BenchLogNull(const ACtx: IBenchContext);
var LL: TLogger;
begin
  LL := TLogger.New(TNullHandler.Create(llDebug), llDebug);
  LL.Debug^.Msg('benchmark message');
  GSink := GSink xor 2;
end;
procedure BenchLogWithAttrs(const ACtx: IBenchContext);
var LL: TLogger;
begin
  LL := TLogger.New(TNullHandler.Create(llDebug), llDebug);
  LL.With_('key', 'value').Info^.Msg('msg');
  GSink := GSink xor 3;
end;
var LResults: IBenchResults;
begin
  LResults := TBenchSuite.Create('log')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Disabled/null', @BenchLogDisabled).Add('Simple/null', @BenchLogNull).Add('WithAttrs/null', @BenchLogWithAttrs)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-log.json');
end.
