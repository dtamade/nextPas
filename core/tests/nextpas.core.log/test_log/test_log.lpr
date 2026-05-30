program test_log;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.log.intf,
  nextpas.core.log;

var
  T: TTestRunner;
  GCaptured: array of TLogRecord;
  GCaptureCount: Int32;

type
  TCaptureHandler = class(TInterfacedObject, ILogHandler)
  private
    FMinLevel: TLogLevel;
    FPrefix: array of TAttr;
    FPrefixCount: Int32;
  public
    constructor Create(AMinLevel: TLogLevel);
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(var ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TCaptureHandler.Create(AMinLevel: TLogLevel);
begin
  inherited Create;
  FMinLevel := AMinLevel;
  FPrefixCount := 0;
end;

function TCaptureHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure TCaptureHandler.Handle(var ARecord: TLogRecord);
begin
  if GCaptureCount >= Length(GCaptured) then
    SetLength(GCaptured, Length(GCaptured) + 16);
  GCaptured[GCaptureCount] := ARecord;
  Inc(GCaptureCount);
end;

function TCaptureHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var
  LNew: TCaptureHandler;
  LI: Int32;
begin
  LNew := TCaptureHandler.Create(FMinLevel);
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do
    LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do
    LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

function TCaptureHandler.WithGroup(const AName: string): ILogHandler;
begin
  Result := Self;
end;

procedure ResetCapture;
begin
  GCaptureCount := 0;
  SetLength(GCaptured, 32);
end;

procedure TestEventBuilder;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^.Str('user', 'alice')^.Int('age', 30)^.Msg('login');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'one record');
  Check(GCaptured[0].Message = 'login', 'msg=login');
  Check(GCaptured[0].Level = llInfo, 'level=info');
  CheckEqual(Int64(2), Int64(GCaptured[0].AttrCount), '2 attrs');
  Check(GCaptured[0].Attrs[0].Key = 'user', 'key0=user');
  Check(GCaptured[0].Attrs[0].SVal = 'alice', 'val0=alice');
  Check(GCaptured[0].Attrs[1].Key = 'age', 'key1=age');
  CheckEqual(Int64(30), GCaptured[0].Attrs[1].IVal, 'val1=30');
end;

procedure TestLevelFiltering;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llWarn), llWarn);
  LL.Debug^.Msg('skip');
  LL.Info^.Msg('skip');
  LL.Warn^.Msg('keep');
  LL.Error^.Msg('keep');
  CheckEqual(Int64(2), Int64(GCaptureCount), 'only warn+error');
end;

procedure TestChildLogger;
var
  LL, LChild: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LChild := LL.With_('service', 'auth');
  LChild.Info^.Str('action', 'login')^.Msg('ok');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'one record');
end;

procedure TestTimestamp;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^.Msg('ts');
  Check(GCaptured[0].TimestampNs > 0, 'timestamp > 0');
end;

procedure TestBoolFloat;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^.Bool('ok', True)^.Float('lat', 3.14)^.Msg('test');
  CheckEqual(Int64(2), Int64(GCaptured[0].AttrCount), '2 attrs');
  Check(GCaptured[0].Attrs[0].BVal = True, 'bool=true');
  Check(Abs(GCaptured[0].Attrs[1].FVal - 3.14) < 0.01, 'float=3.14');
end;

procedure TestErrHelper;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Error^.Err('connection refused')^.Msg('failed');
  Check(GCaptured[0].Attrs[0].Key = 'error', 'err key');
  Check(GCaptured[0].Attrs[0].SVal = 'connection refused', 'err val');
end;

procedure TestSend;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^.Str('k', 'v')^.Send;
  CheckEqual(Int64(1), Int64(GCaptureCount), 'send works');
  Check(GCaptured[0].Message = '', 'empty msg');
end;

procedure TestConsoleHandler;
var
  LL: TLogger;
begin
  LL := TLogger.New(NewConsoleHandler(llError), llError);
  LL.Error^.Str('test', 'console')^.Msg('error output');
  Check(True, 'console no crash');
end;

procedure TestJsonHandler;
var
  LL: TLogger;
begin
  LL := TLogger.New(NewJsonHandler(llInfo), llInfo);
  LL.Info^.Str('key', 'val')^.Int('n', 42)^.Msg('json test');
  Check(True, 'json no crash');
end;

procedure TestGlobalLogger;
begin
  ResetCapture;
  SetDefaultLogger(TLogger.New(TCaptureHandler.Create(llInfo), llInfo));
  LogInfo('global test');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'global works');
  Check(GCaptured[0].Message = 'global test', 'global msg');
end;

procedure TestDisabledNoAlloc;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llError), llError);
  LL.Debug^.Str('expensive', 'computation')^.Msg('skip');
  CheckEqual(Int64(0), Int64(GCaptureCount), 'disabled = no handle');
end;

procedure TestNullLogger;
var
  LL: ILogger;
begin
  LL := NullLogger;
  LL.Info('no crash');
  LL.Error('still fine');
  Check(True, 'null logger safe');
end;

begin
  T := TTestRunner.Create('nextpas.core.log');
  T.Run('Event builder', @TestEventBuilder);
  T.Run('Level filtering', @TestLevelFiltering);
  T.Run('Child logger', @TestChildLogger);
  T.Run('Timestamp', @TestTimestamp);
  T.Run('Bool/Float attrs', @TestBoolFloat);
  T.Run('Err helper', @TestErrHelper);
  T.Run('Send (no msg)', @TestSend);
  T.Run('Console handler', @TestConsoleHandler);
  T.Run('JSON handler', @TestJsonHandler);
  T.Run('Global logger', @TestGlobalLogger);
  T.Run('Disabled no alloc', @TestDisabledNoAlloc);
  T.Run('Null logger', @TestNullLogger);
  T.Summary;
end.
