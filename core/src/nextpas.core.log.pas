unit nextpas.core.log;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.log.intf;

type
  TLogLevel = nextpas.core.log.intf.TLogLevel;
  ILogger = nextpas.core.log.intf.ILogger;

  TLogField = record
    Key: string;
    Value: string;
  end;

  TLogRecord = record
    Level: TLogLevel;
    Message: string;
    TimestampNs: Int64;
    Fields: array of TLogField;
    FieldCount: Int32;
  end;

  ILogHandler = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-FA2345678901}']
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
    procedure Close;
  end;

function LogConsole(ALevel: TLogLevel = llInfo): ILogger;
function LogWith(const AHandler: ILogHandler; ALevel: TLogLevel = llInfo): ILogger;

procedure LogSetDefault(const ALogger: ILogger);
function LogDefault: ILogger;

procedure LogTrace(const AMsg: string);
procedure LogDebug(const AMsg: string);
procedure LogInfo(const AMsg: string);
procedure LogWarn(const AMsg: string);
procedure LogError(const AMsg: string);
procedure LogFatal(const AMsg: string);

implementation

uses
  SysUtils,
  nextpas.core.time.base;

const
  LOG_LEVEL_NAMES: array[TLogLevel] of string = (
    'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'
  );
  LOG_LEVEL_COLORS: array[TLogLevel] of string = (
    #27'[90m', #27'[36m', #27'[32m', #27'[33m', #27'[31m', #27'[35m'
  );
  COLOR_RESET = #27'[0m';

type
  { TConsoleHandler — colored stderr output }
  TConsoleHandler = class(TInterfacedObject, ILogHandler)
  public
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
    procedure Close;
  end;

  { TStructuredLogger — multi-handler logger with level filtering }
  TStructuredLogger = class(TInterfacedObject, ILogger)
  private
    FLevel: TLogLevel;
    FHandlers: array of ILogHandler;
    FHandlerCount: Int32;
    FFields: array of TLogField;
    FFieldCount: Int32;
  public
    constructor Create(ALevel: TLogLevel);
    procedure AddHandler(const AHandler: ILogHandler);
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Fatal(const AMessage: string);
  end;

var
  GDefaultLogger: ILogger = nil;

{ TConsoleHandler }

procedure TConsoleHandler.Handle(const ARecord: TLogRecord);
var
  LI: Int32;
begin
  Write(StdErr, LOG_LEVEL_COLORS[ARecord.Level]);
  Write(StdErr, LOG_LEVEL_NAMES[ARecord.Level]);
  Write(StdErr, COLOR_RESET);
  Write(StdErr, ' ');
  Write(StdErr, ARecord.Message);
  for LI := 0 to ARecord.FieldCount - 1 do
  begin
    Write(StdErr, ' ');
    Write(StdErr, ARecord.Fields[LI].Key);
    Write(StdErr, '=');
    Write(StdErr, ARecord.Fields[LI].Value);
  end;
  WriteLn(StdErr);
end;

procedure TConsoleHandler.Flush;
begin
  System.Flush(StdErr);
end;

procedure TConsoleHandler.Close;
begin
end;

{ TStructuredLogger }

constructor TStructuredLogger.Create(ALevel: TLogLevel);
begin
  inherited Create;
  FLevel := ALevel;
  FHandlerCount := 0;
  FFieldCount := 0;
  SetLength(FHandlers, 4);
  SetLength(FFields, 8);
end;

procedure TStructuredLogger.AddHandler(const AHandler: ILogHandler);
begin
  if FHandlerCount >= Length(FHandlers) then
    SetLength(FHandlers, Length(FHandlers) * 2);
  FHandlers[FHandlerCount] := AHandler;
  Inc(FHandlerCount);
end;

procedure TStructuredLogger.Log(const ALevel: TLogLevel; const AMessage: string);
var
  LRec: TLogRecord;
  LI: Int32;
begin
  if ALevel < FLevel then Exit;
  LRec.Level := ALevel;
  LRec.Message := AMessage;
  LRec.TimestampNs := TInstant.Now.Elapsed.AsNanoseconds;
  SetLength(LRec.Fields, FFieldCount);
  LRec.FieldCount := FFieldCount;
  for LI := 0 to FFieldCount - 1 do
    LRec.Fields[LI] := FFields[LI];
  for LI := 0 to FHandlerCount - 1 do
    FHandlers[LI].Handle(LRec);
end;

procedure TStructuredLogger.Trace(const AMessage: string);
begin Log(llTrace, AMessage); end;

procedure TStructuredLogger.Debug(const AMessage: string);
begin Log(llDebug, AMessage); end;

procedure TStructuredLogger.Info(const AMessage: string);
begin Log(llInfo, AMessage); end;

procedure TStructuredLogger.Warn(const AMessage: string);
begin Log(llWarn, AMessage); end;

procedure TStructuredLogger.Error(const AMessage: string);
begin Log(llError, AMessage); end;

procedure TStructuredLogger.Fatal(const AMessage: string);
begin Log(llFatal, AMessage); end;

{ Factory functions }

function LogConsole(ALevel: TLogLevel): ILogger;
var
  LL: TStructuredLogger;
begin
  LL := TStructuredLogger.Create(ALevel);
  LL.AddHandler(TConsoleHandler.Create);
  Result := LL;
end;

function LogWith(const AHandler: ILogHandler; ALevel: TLogLevel): ILogger;
var
  LL: TStructuredLogger;
begin
  LL := TStructuredLogger.Create(ALevel);
  LL.AddHandler(AHandler);
  Result := LL;
end;

procedure LogSetDefault(const ALogger: ILogger);
begin
  GDefaultLogger := ALogger;
end;

function LogDefault: ILogger;
begin
  if GDefaultLogger = nil then
    GDefaultLogger := LogConsole(llInfo);
  Result := GDefaultLogger;
end;

procedure LogTrace(const AMsg: string);
begin LogDefault.Trace(AMsg); end;

procedure LogDebug(const AMsg: string);
begin LogDefault.Debug(AMsg); end;

procedure LogInfo(const AMsg: string);
begin LogDefault.Info(AMsg); end;

procedure LogWarn(const AMsg: string);
begin LogDefault.Warn(AMsg); end;

procedure LogError(const AMsg: string);
begin LogDefault.Error(AMsg); end;

procedure LogFatal(const AMsg: string);
begin LogDefault.Fatal(AMsg); end;

end.
