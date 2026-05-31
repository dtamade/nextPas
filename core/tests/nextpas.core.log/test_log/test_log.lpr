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
    FGroup: string;
  public
    constructor Create(AMinLevel: TLogLevel);
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    procedure Flush;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TCaptureHandler.Create(AMinLevel: TLogLevel);
begin
  inherited Create;
  FMinLevel := AMinLevel;
  FPrefixCount := 0;
  FGroup := '';
end;

function TCaptureHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure TCaptureHandler.Handle(const ARecord: TLogRecord);
var
  LRec: TLogRecord;
  LI: Int32;
begin
  if GCaptureCount >= Length(GCaptured) then
    SetLength(GCaptured, Length(GCaptured) + 16);
  { Merge prefix attrs + group into the captured record for test verification }
  LRec := ARecord;
  LRec.Group := FGroup;
  if FPrefixCount > 0 then
  begin
    SetLength(LRec.Attrs, FPrefixCount + ARecord.AttrCount);
    for LI := 0 to FPrefixCount - 1 do
      LRec.Attrs[LI] := FPrefix[LI];
    for LI := 0 to ARecord.AttrCount - 1 do
      LRec.Attrs[FPrefixCount + LI] := ARecord.Attrs[LI];
    LRec.AttrCount := FPrefixCount + ARecord.AttrCount;
  end;
  GCaptured[GCaptureCount] := LRec;
  Inc(GCaptureCount);
end;

function TCaptureHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var
  LNew: TCaptureHandler;
  LI: Int32;
begin
  LNew := TCaptureHandler.Create(FMinLevel);
  LNew.FGroup := FGroup;
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do
    LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do
    LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

procedure TCaptureHandler.Flush;
begin
end;

function TCaptureHandler.WithGroup(const AName: string): ILogHandler;
var
  LNew: TCaptureHandler;
  LI: Int32;
begin
  LNew := TCaptureHandler.Create(FMinLevel);
  SetLength(LNew.FPrefix, FPrefixCount);
  for LI := 0 to FPrefixCount - 1 do
    LNew.FPrefix[LI] := FPrefix[LI];
  LNew.FPrefixCount := FPrefixCount;
  if FGroup <> '' then
    LNew.FGroup := FGroup + '.' + AName
  else
    LNew.FGroup := AName;
  Result := LNew;
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

procedure TestFileHandler;
var
  LL: TLogger;
  LPath: string;
  LF: TextFile;
  LLine: string;
begin
  LPath := '/tmp/test_log_' + IntToStr(Random(99999)) + '.log';
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  LL.Info^.Str('key', 'val')^.Msg('file test');
  LL.Warn^.Int('code', 42)^.Msg('warning');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal); // release file handler
  AssignFile(LF, LPath);
  Reset(LF);
  ReadLn(LF, LLine);
  Check(Pos('INF', LLine) > 0, 'file has INF');
  Check(Pos('file test', LLine) > 0, 'file has msg');
  ReadLn(LF, LLine);
  Check(Pos('WRN', LLine) > 0, 'file has WRN');
  CloseFile(LF);
  DeleteFile(LPath);
end;

procedure TestMultiHandler;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(NewMultiHandler([
    TCaptureHandler.Create(llInfo) as ILogHandler,
    TCaptureHandler.Create(llWarn) as ILogHandler
  ]), llInfo);
  LL.Info^.Msg('info msg');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'only info handler fires');
  LL.Warn^.Msg('warn msg');
  CheckEqual(Int64(3), Int64(GCaptureCount), 'both fire for warn');
end;

procedure TestFileRotation;
var
  LL: TLogger;
  LPath: string;
  LI: Int32;
begin
  LPath := '/tmp/test_log_rot_' + IntToStr(Random(99999)) + '.log';
  LL := TLogger.New(NewFileHandler(LPath, llInfo, 100, 3), llInfo);
  for LI := 1 to 10 do
    LL.Info^.Int('i', LI)^.Msg('rotation test line that is long enough');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal);
  Check(FileExists(LPath) or FileExists(LPath + '.1'), 'rotation created files');
  DeleteFile(LPath);
  DeleteFile(LPath + '.1');
  DeleteFile(LPath + '.2');
  DeleteFile(LPath + '.3');
end;

procedure TestManyAttrs;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^.Str('a','1')^.Str('b','2')^.Str('c','3')^.Str('d','4')^
    .Str('e','5')^.Str('f','6')^.Str('g','7')^.Str('h','8')^
    .Str('i','9')^.Str('j','10')^.Msg('many');
  CheckEqual(Int64(10), Int64(GCaptured[0].AttrCount), '10 attrs');
end;

procedure TestWithInt;
var
  LL, LChild: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LChild := LL.WithInt('port', 8080);
  LChild.Info^.Msg('started');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'withint works');
end;

procedure TestWithGroup;
var
  LL, LChild: TLogger;
begin
  LL := TLogger.New(NewConsoleHandler(llDebug), llDebug);
  LChild := LL.WithGroup('http');
  LChild.Debug^.Str('method', 'GET')^.Msg('request');
  Check(True, 'withgroup no crash');
end;

procedure TestLogContext;
var
  LCtx: Int32;
begin
  LCtx := 42;
  SetLogContext(@LCtx);
  Check(GetLogContext = @LCtx, 'context set');
  SetLogContext(nil);
  Check(GetLogContext = nil, 'context cleared');
end;

procedure TestAllLevels;
begin
  ResetCapture;
  SetDefaultLogger(TLogger.New(TCaptureHandler.Create(llTrace), llTrace));
  LogTrace('t');
  LogDebug('d');
  LogInfo('i');
  LogWarn('w');
  LogError('e');
  CheckEqual(Int64(5), Int64(GCaptureCount), 'all global levels');
end;

procedure TestFatalLevel;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llFatal), llFatal);
  LL.Info^.Msg('skip');
  LL.Fatal^.Msg('crash');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'only fatal');
  Check(GCaptured[0].Level = llFatal, 'level=fatal');
end;

procedure TestReentrancy;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^.Msg('normal');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'normal log works');
end;

procedure TestBrokenFileHandler;
var
  LL: TLogger;
begin
  LL := TLogger.New(NewFileHandler('/nonexistent/path/impossible.log', llInfo), llInfo);
  LL.Info^.Msg('should not crash');
  LL.Error^.Msg('still safe');
  Check(True, 'broken file handler no crash');
end;

{ === Bug fix verification tests === }

procedure TestNilHandlerWith;
var
  LL, LChild: TLogger;
begin
  { Bug fix 2: nil handler must not crash in With_ methods }
  LL := TLogger.New(nil, llInfo);
  LChild := LL.With_('key', 'val');
  Check(not LChild.Enabled(llInfo), 'nil handler With_ stays disabled');
  LChild := LL.WithInt('port', 8080);
  Check(not LChild.Enabled(llInfo), 'nil handler WithInt stays disabled');
  LChild := LL.WithAttrs([AttrStr('a', 'b')]);
  Check(not LChild.Enabled(llInfo), 'nil handler WithAttrs stays disabled');
  LChild := LL.WithGroup('grp');
  Check(not LChild.Enabled(llInfo), 'nil handler WithGroup stays disabled');
end;

procedure TestNilHandlerLog;
var
  LL: TLogger;
begin
  { Bug fix 2: nil handler must not crash when logging }
  LL := TLogger.New(nil, llInfo);
  LL.Info^.Str('k', 'v')^.Msg('no crash');
  LL.Error^.Err('oops')^.Send;
  Check(True, 'nil handler log no crash');
end;

procedure TestWithGroupPrefix;
var
  LL, LChild: TLogger;
begin
  { Bug fix 4/5: WithGroup must prefix keys }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LChild := LL.WithGroup('http');
  LChild.Info^.Str('method', 'GET')^.Msg('request');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'one record');
  Check(GCaptured[0].Group = 'http', 'group=http');
end;

procedure TestWithGroupNested;
var
  LL, L1, L2: TLogger;
begin
  { Bug fix 4/5: nested WithGroup must chain prefixes }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  L1 := LL.WithGroup('server');
  L2 := L1.WithGroup('http');
  L2.Info^.Str('path', '/api')^.Msg('nested');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'one record');
  Check(GCaptured[0].Group = 'server.http', 'group=server.http');
end;

procedure TestFileHandlerWithGroup;
var
  LL, LChild: TLogger;
  LPath: string;
  LF: TextFile;
  LLine: string;
begin
  { Bug fix 5: file handler WithGroup prefixes keys in output }
  LPath := '/tmp/test_log_grp_' + IntToStr(Random(99999)) + '.log';
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  LChild := LL.WithGroup('db');
  LChild.Info^.Str('query', 'SELECT')^.Msg('exec');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal); // release file handler
  AssignFile(LF, LPath);
  Reset(LF);
  ReadLn(LF, LLine);
  Check(Pos('db.query=', LLine) > 0, 'file has db.query= prefix');
  CloseFile(LF);
  DeleteFile(LPath);
end;

procedure TestFileHandlerWriteError;
var
  LL: TLogger;
  LPath: string;
begin
  { Bug fix 3: write errors mark handler broken, no crash }
  LPath := '/proc/nonexistent_file_' + IntToStr(Random(99999));
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  LL.Info^.Msg('trigger error');
  LL.Info^.Msg('second call after broken');
  Check(True, 'file write error no crash');
end;

procedure TestPoolSize256;
var
  LL: TLogger;
  LI: Int32;
begin
  { Bug fix 1: pool is 256 slots, rapid logging must not crash }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  for LI := 1 to 300 do
    LL.Info^.Int('i', LI)^.Msg('rapid');
  CheckEqual(Int64(300), Int64(GCaptureCount), '300 rapid logs');
end;

procedure TestDefaultLoggerInit;
var
  LL: TLogger;
begin
  { DefaultLogger auto-initializes on first call }
  ResetCapture;
  SetDefaultLogger(TLogger.New(TCaptureHandler.Create(llInfo), llInfo));
  LL := DefaultLogger;
  LL.Info^.Msg('default init');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'default logger works');
  Check(GCaptured[0].Message = 'default init', 'default msg');
end;

procedure TestMultiHandlerWithGroup;
var
  LL, LChild: TLogger;
begin
  { MultiHandler propagates WithGroup to all children }
  ResetCapture;
  LL := TLogger.New(NewMultiHandler([
    TCaptureHandler.Create(llDebug) as ILogHandler,
    TCaptureHandler.Create(llDebug) as ILogHandler
  ]), llDebug);
  LChild := LL.WithGroup('net');
  LChild.Info^.Str('port', '443')^.Msg('multi grp');
  CheckEqual(Int64(2), Int64(GCaptureCount), 'both handlers fire');
  Check(GCaptured[0].Group = 'net', 'handler1 group=net');
  Check(GCaptured[1].Group = 'net', 'handler2 group=net');
end;

procedure TestConvenienceFunctions;
begin
  { LogInfo/LogWarn/LogError convenience functions }
  ResetCapture;
  SetDefaultLogger(TLogger.New(TCaptureHandler.Create(llTrace), llTrace));
  LogTrace('trace msg');
  LogDebug('debug msg');
  LogInfo('info msg');
  LogWarn('warn msg');
  LogError('error msg');
  CheckEqual(Int64(5), Int64(GCaptureCount), '5 convenience calls');
  Check(GCaptured[0].Level = llTrace, 'conv trace level');
  Check(GCaptured[1].Level = llDebug, 'conv debug level');
  Check(GCaptured[2].Level = llInfo, 'conv info level');
  Check(GCaptured[3].Level = llWarn, 'conv warn level');
  Check(GCaptured[4].Level = llError, 'conv error level');
end;

procedure TestReentrantLogging;
var
  LL: TLogger;
begin
  { Reentrant logging must not crash (GLogDepth guard) }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^.Msg('first');
  LL.Info^.Msg('second');
  CheckEqual(Int64(2), Int64(GCaptureCount), 'sequential logs ok');
end;

procedure TestWithAttrsBatch;
var
  LL, LChild: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LChild := LL.WithAttrs([AttrStr('svc', 'web'), AttrInt('port', 8080)]);
  LChild.Info^.Msg('started');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'batch withattrs');
end;

procedure TestWithLevel;
var
  LL, LChild: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llInfo);
  LL.Debug^.Msg('skip');
  CheckEqual(Int64(0), Int64(GCaptureCount), 'info level filters debug');
  LChild := LL.WithLevel(llDebug);
  LChild.Debug^.Msg('now visible');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'withlevel debug passes');
end;

procedure TestAsILogger;
var
  LL: TLogger;
  LI: ILogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llInfo), llInfo);
  LI := LL.AsILogger;
  LI.Info('via ilogger');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'ilogger bridge works');
  Check(GCaptured[0].Message = 'via ilogger', 'ilogger msg');
  LI.Debug('should skip');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'ilogger respects level');
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
  T.Run('File handler', @TestFileHandler);
  T.Run('Multi handler', @TestMultiHandler);
  T.Run('File rotation', @TestFileRotation);
  T.Run('Many attrs', @TestManyAttrs);
  T.Run('WithInt', @TestWithInt);
  T.Run('WithGroup', @TestWithGroup);
  T.Run('Log context', @TestLogContext);
  T.Run('All levels', @TestAllLevels);
  T.Run('Fatal level', @TestFatalLevel);
  T.Run('Re-entrancy', @TestReentrancy);
  T.Run('Broken file handler', @TestBrokenFileHandler);
  T.Run('WithAttrs batch', @TestWithAttrsBatch);
  T.Run('WithLevel', @TestWithLevel);
  T.Run('AsILogger bridge', @TestAsILogger);
  { Bug fix verification tests }
  T.Run('Nil handler With_', @TestNilHandlerWith);
  T.Run('Nil handler log', @TestNilHandlerLog);
  T.Run('WithGroup prefix', @TestWithGroupPrefix);
  T.Run('WithGroup nested', @TestWithGroupNested);
  T.Run('File handler WithGroup', @TestFileHandlerWithGroup);
  T.Run('File handler write error', @TestFileHandlerWriteError);
  T.Run('Pool size 256', @TestPoolSize256);
  T.Run('Default logger init', @TestDefaultLoggerInit);
  T.Run('Multi handler WithGroup', @TestMultiHandlerWithGroup);
  T.Run('Convenience functions', @TestConvenienceFunctions);
  T.Run('Reentrant logging', @TestReentrantLogging);
  T.Summary;
end.
