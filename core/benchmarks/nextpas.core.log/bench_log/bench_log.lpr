program bench_log;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base, nextpas.core.log.intf, nextpas.core.log;
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
begin LL := TLogger.Create(TNullHandler.Create(lvInfo)); if LL.Enabled(lvDebug) then LL.Log(lvDebug, 'test'); LL.Free; end;
procedure BenchLogNull(const ACtx: IBenchContext);
var LL: TLogger;
begin LL := TLogger.Create(TNullHandler.Create(lvDebug)); LL.Log(lvDebug, 'benchmark message'); LL.Free; end;
procedure BenchLogWithAttrs(const ACtx: IBenchContext);
var LL: TLogger;
begin LL := TLogger.Create(TNullHandler.Create(lvDebug)); LL.With(['key', 'value']).Log(lvInfo, 'msg'); LL.Free; end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('log');
  LSuite.Add('Disabled/null', @BenchLogDisabled).Add('Simple/null', @BenchLogNull).Add('WithAttrs/null', @BenchLogWithAttrs);
  WriteLn(LSuite.Run.PrintToConsole);
end.
