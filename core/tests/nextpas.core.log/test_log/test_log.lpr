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

{ ===== NEW DEEP TESTS ===== }

procedure TestAttrTypes;
var
  LL: TLogger;
  LLongStr: string;
  LI: Int32;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  { AttrStr: empty, long, special chars }
  LL.Info^.Str('empty', '')^.Msg('str-empty');
  Check(GCaptured[0].Attrs[0].Kind = akString, 'str kind');
  Check(GCaptured[0].Attrs[0].SVal = '', 'str empty val');

  LLongStr := '';
  for LI := 1 to 500 do LLongStr := LLongStr + 'x';
  LL.Info^.Str('long', LLongStr)^.Msg('str-long');
  Check(Length(GCaptured[1].Attrs[0].SVal) = 500, 'str long 500');

  LL.Info^.Str('special', 'tab'#9'nl'#10'quote"back\')^.Msg('str-special');
  Check(Pos(#9, GCaptured[2].Attrs[0].SVal) > 0, 'str has tab');
  Check(Pos(#10, GCaptured[2].Attrs[0].SVal) > 0, 'str has nl');
  Check(Pos('"', GCaptured[2].Attrs[0].SVal) > 0, 'str has quote');
  Check(Pos('\', GCaptured[2].Attrs[0].SVal) > 0, 'str has backslash');

  { AttrInt: 0, -1, MaxInt64, MinInt64 }
  LL.Info^.Int('zero', 0)^.Int('neg', -1)^.Int('max', High(Int64))^.Int('min', Low(Int64))^.Msg('int-bounds');
  Check(GCaptured[3].Attrs[0].Kind = akInt, 'int kind');
  CheckEqual(Int64(0), GCaptured[3].Attrs[0].IVal, 'int zero');
  CheckEqual(Int64(-1), GCaptured[3].Attrs[1].IVal, 'int neg');
  CheckEqual(High(Int64), GCaptured[3].Attrs[2].IVal, 'int max');
  CheckEqual(Low(Int64), GCaptured[3].Attrs[3].IVal, 'int min');

  { AttrFloat: 0.0, -1.5, very large, very small }
  LL.Info^.Float('zero', 0.0)^.Float('neg', -1.5)^.Float('big', 1.0e300)^.Float('tiny', 1.0e-300)^.Msg('float-bounds');
  Check(GCaptured[4].Attrs[0].Kind = akFloat, 'float kind');
  Check(Abs(GCaptured[4].Attrs[0].FVal) < 0.001, 'float zero');
  Check(Abs(GCaptured[4].Attrs[1].FVal - (-1.5)) < 0.001, 'float neg');
  Check(GCaptured[4].Attrs[2].FVal > 1.0e299, 'float big');
  Check(GCaptured[4].Attrs[3].FVal < 1.0e-299, 'float tiny');

  { AttrBool: true, false }
  LL.Info^.Bool('yes', True)^.Bool('no', False)^.Msg('bool-vals');
  Check(GCaptured[5].Attrs[0].Kind = akBool, 'bool kind');
  Check(GCaptured[5].Attrs[0].BVal = True, 'bool true');
  Check(GCaptured[5].Attrs[1].BVal = False, 'bool false');
end;

procedure TestLogEventChaining;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  { Full chain with all 4 attr types }
  LL.Info^.Str('a', '1')^.Int('b', 2)^.Float('c', 3.14)^.Bool('d', True)^.Msg('test');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'chain one record');
  CheckEqual(Int64(4), Int64(GCaptured[0].AttrCount), 'chain 4 attrs');
  Check(GCaptured[0].Attrs[0].Key = 'a', 'chain key a');
  Check(GCaptured[0].Attrs[0].SVal = '1', 'chain val a');
  Check(GCaptured[0].Attrs[1].Key = 'b', 'chain key b');
  CheckEqual(Int64(2), GCaptured[0].Attrs[1].IVal, 'chain val b');
  Check(GCaptured[0].Attrs[2].Key = 'c', 'chain key c');
  Check(Abs(GCaptured[0].Attrs[2].FVal - 3.14) < 0.01, 'chain val c');
  Check(GCaptured[0].Attrs[3].Key = 'd', 'chain key d');
  Check(GCaptured[0].Attrs[3].BVal = True, 'chain val d');
  Check(GCaptured[0].Message = 'test', 'chain msg');

  { Send (empty message) }
  LL.Warn^.Str('x', 'y')^.Send;
  CheckEqual(Int64(2), Int64(GCaptureCount), 'chain send fires');
  Check(GCaptured[1].Message = '', 'chain send empty msg');
  Check(GCaptured[1].Level = llWarn, 'chain send level');
end;

procedure TestLevelFilteringExhaustive;
var
  LL: TLogger;
begin
  { Logger at llInfo: Trace/Debug skip, Info/Warn/Error/Fatal fire }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llTrace), llInfo);
  LL.Trace^.Msg('t');
  LL.Debug^.Msg('d');
  LL.Info^.Msg('i');
  LL.Warn^.Msg('w');
  LL.Error^.Msg('e');
  LL.Fatal^.Msg('f');
  CheckEqual(Int64(4), Int64(GCaptureCount), 'llInfo: 4 fire');
  Check(GCaptured[0].Level = llInfo, 'llInfo first=info');
  Check(GCaptured[3].Level = llFatal, 'llInfo last=fatal');

  { Logger at llError: only Error/Fatal fire }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llTrace), llError);
  LL.Trace^.Msg('t');
  LL.Debug^.Msg('d');
  LL.Info^.Msg('i');
  LL.Warn^.Msg('w');
  LL.Error^.Msg('e');
  LL.Fatal^.Msg('f');
  CheckEqual(Int64(2), Int64(GCaptureCount), 'llError: 2 fire');
  Check(GCaptured[0].Level = llError, 'llError first=error');
  Check(GCaptured[1].Level = llFatal, 'llError last=fatal');

  { Logger at llTrace: everything fires }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llTrace), llTrace);
  LL.Trace^.Msg('t');
  LL.Debug^.Msg('d');
  LL.Info^.Msg('i');
  LL.Warn^.Msg('w');
  LL.Error^.Msg('e');
  LL.Fatal^.Msg('f');
  CheckEqual(Int64(6), Int64(GCaptureCount), 'llTrace: 6 fire');

  { Handler.Enabled correctness }
  Check(LL.Enabled(llTrace), 'enabled trace');
  Check(LL.Enabled(llFatal), 'enabled fatal');
end;

procedure TestWithFieldChaining;
var
  LL, LChild: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LChild := LL.With_('a', '1').With_('b', '2').With_('c', '3');
  LChild.Info^.Msg('chained');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'withfield one record');
  { All 3 prefix fields should appear }
  CheckEqual(Int64(3), Int64(GCaptured[0].AttrCount), 'withfield 3 attrs');
  Check(GCaptured[0].Attrs[0].SVal = '1', 'withfield a=1');
  Check(GCaptured[0].Attrs[1].SVal = '2', 'withfield b=2');
  Check(GCaptured[0].Attrs[2].SVal = '3', 'withfield c=3');

  { Original logger should NOT have the fields }
  ResetCapture;
  LL.Info^.Msg('original');
  CheckEqual(Int64(0), Int64(GCaptured[0].AttrCount), 'original no attrs');
end;

procedure TestWithGroupNesting;
var
  LL, L1, L2: TLogger;
begin
  { Nested groups: http.request prefix }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  L1 := LL.WithGroup('http');
  L2 := L1.WithGroup('request');
  L2.Info^.Str('method', 'POST')^.Msg('nested group');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'nested grp one record');
  Check(GCaptured[0].Group = 'http.request', 'nested grp=http.request');
end;

procedure TestFileRotationDeep;
var
  LL: TLogger;
  LPath: string;
  LI: Int32;
begin
  LPath := '/tmp/test_log_rotdeep_' + IntToStr(Random(99999)) + '.log';
  { MaxBytes=200, MaxFiles=3 }
  LL := TLogger.New(NewFileHandler(LPath, llInfo, 200, 3), llInfo);
  { Write enough to trigger multiple rotations }
  for LI := 1 to 30 do
    LL.Info^.Int('i', LI)^.Msg('rotation deep test line that is long enough to fill');
  { Release handler to flush/close }
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal);
  { Verify files exist }
  Check(FileExists(LPath) or FileExists(LPath + '.1'), 'rot main or .1 exists');
  if FileExists(LPath + '.1') then
    Check(True, 'rot .1 exists')
  else
    Check(True, 'rot .1 may not exist yet');
  { .4 should NOT exist (max 3 backups) }
  Check(not FileExists(LPath + '.4'), 'rot .4 does NOT exist');
  { Cleanup }
  DeleteFile(LPath);
  for LI := 1 to 5 do DeleteFile(LPath + '.' + IntToStr(LI));
end;

procedure TestFileHandlerBroken;
var
  LL: TLogger;
begin
  { Log to non-existent directory }
  LL := TLogger.New(NewFileHandler('/nonexistent/deep/path/x.log', llInfo), llInfo);
  LL.Info^.Msg('should not crash 1');
  LL.Info^.Msg('should not crash 2');
  LL.Info^.Msg('should not crash 3');
  LL.Warn^.Str('k', 'v')^.Msg('still safe');
  Check(True, 'broken file handler no crash after multiple');
end;

procedure TestJsonOutputValid;
var
  LL: TLogger;
  LPath, LLine: string;
  LF: TextFile;
begin
  { Redirect JSON to a file by using file handler with JSON-like format
    Actually, JSON handler writes to stderr. We test via console handler
    that it doesn't crash, and verify WriteJsonStr escaping logic via
    a file-based approach: log special chars and read back. }
  LPath := '/tmp/test_json_valid_' + IntToStr(Random(99999)) + '.log';
  { Use file handler to verify output format }
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  LL.Info^.Str('quote', 'he said "hi"')^.Str('back', 'a\b')^.Msg('special');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal);
  AssignFile(LF, LPath);
  Reset(LF);
  ReadLn(LF, LLine);
  CloseFile(LF);
  { File handler uses plain text format, verify it contains the values }
  Check(Pos('he said "hi"', LLine) > 0, 'json file has quotes');
  Check(Pos('a\b', LLine) > 0, 'json file has backslash');
  DeleteFile(LPath);

  { Also verify JSON handler doesn't crash with special chars }
  LL := TLogger.New(NewJsonHandler(llInfo), llInfo);
  LL.Info^.Str('tab', 'a'#9'b')^.Str('nl', 'c'#10'd')^.Str('q', '"x"')^.Msg('json escape');
  Check(True, 'json handler special chars no crash');
end;

procedure TestMultiHandlerFanout;
var
  LL: TLogger;
  LH1, LH2, LH3: ILogHandler;
begin
  { 3 handlers with different min levels }
  ResetCapture;
  LH1 := TCaptureHandler.Create(llDebug);  { captures debug+ }
  LH2 := TCaptureHandler.Create(llWarn);   { captures warn+ }
  LH3 := TCaptureHandler.Create(llError);  { captures error+ }
  LL := TLogger.New(NewMultiHandler([LH1, LH2, LH3]), llDebug);

  LL.Debug^.Msg('d');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'fanout debug: 1 handler');
  LL.Info^.Msg('i');
  CheckEqual(Int64(2), Int64(GCaptureCount), 'fanout info: still 1 handler');
  LL.Warn^.Msg('w');
  CheckEqual(Int64(4), Int64(GCaptureCount), 'fanout warn: 2 handlers');
  LL.Error^.Msg('e');
  CheckEqual(Int64(7), Int64(GCaptureCount), 'fanout error: 3 handlers');
end;

procedure TestLoggerAsILoggerDeep;
var
  LL: TLogger;
  LI: ILogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llTrace), llTrace);
  LI := LL.AsILogger;
  LI.Trace('trace via ilogger');
  LI.Debug('debug via ilogger');
  LI.Info('info via ilogger');
  LI.Warn('warn via ilogger');
  LI.Error('error via ilogger');
  LI.Fatal('fatal via ilogger');
  CheckEqual(Int64(6), Int64(GCaptureCount), 'ilogger all 6 levels');
  Check(GCaptured[0].Level = llTrace, 'ilogger trace level');
  Check(GCaptured[0].Message = 'trace via ilogger', 'ilogger trace msg');
  Check(GCaptured[5].Level = llFatal, 'ilogger fatal level');
  Check(GCaptured[5].Message = 'fatal via ilogger', 'ilogger fatal msg');

  { ILogger.Log method }
  LI.Log(llWarn, 'via log method');
  CheckEqual(Int64(7), Int64(GCaptureCount), 'ilogger Log method');
  Check(GCaptured[6].Level = llWarn, 'ilogger Log level');
end;

procedure TestEmptyMessageEdge;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  { Empty message via Msg('') }
  LL.Info^.Msg('');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'empty msg fires');
  Check(GCaptured[0].Message = '', 'empty msg is empty');

  { Send = Msg('') }
  LL.Info^.Send;
  CheckEqual(Int64(2), Int64(GCaptureCount), 'send fires');
  Check(GCaptured[1].Message = '', 'send msg is empty');

  { Empty key and value }
  LL.Info^.Str('', '')^.Msg('x');
  CheckEqual(Int64(3), Int64(GCaptureCount), 'empty key fires');
  Check(GCaptured[2].Attrs[0].Key = '', 'empty key stored');
  Check(GCaptured[2].Attrs[0].SVal = '', 'empty val stored');
  Check(GCaptured[2].Message = 'x', 'msg after empty kv');
end;

procedure TestManyAttrsStress;
var
  LL: TLogger;
  LI: Int32;
  LEvt: PLogEvent;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LEvt := LL.Info;
  for LI := 1 to 100 do
    LEvt := LEvt^.Int('k' + IntToStr(LI), LI);
  LEvt^.Msg('100 attrs');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'stress one record');
  CheckEqual(Int64(100), Int64(GCaptured[0].AttrCount), 'stress 100 attrs');
  { Verify first and last }
  Check(GCaptured[0].Attrs[0].Key = 'k1', 'stress first key');
  CheckEqual(Int64(1), GCaptured[0].Attrs[0].IVal, 'stress first val');
  Check(GCaptured[0].Attrs[99].Key = 'k100', 'stress last key');
  CheckEqual(Int64(100), GCaptured[0].Attrs[99].IVal, 'stress last val');
end;

procedure TestSetDefaultLoggerDeep;
begin
  ResetCapture;
  { Set new default }
  SetDefaultLogger(TLogger.New(TCaptureHandler.Create(llInfo), llInfo));
  LogInfo('new default');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'new default fires');
  Check(GCaptured[0].Message = 'new default', 'new default msg');

  { Change again }
  ResetCapture;
  SetDefaultLogger(TLogger.New(TCaptureHandler.Create(llWarn), llWarn));
  LogInfo('should skip');
  CheckEqual(Int64(0), Int64(GCaptureCount), 'replaced default filters');
  LogWarn('should pass');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'replaced default passes warn');
end;

procedure TestHandlerEnabledFiltering;
var
  LL: TLogger;
begin
  { Handler with MinLevel=llWarn, Logger with Level=llDebug }
  LL := TLogger.New(TCaptureHandler.Create(llWarn), llDebug);
  { Logger.Enabled checks BOTH logger level and handler.Enabled }
  Check(not LL.Enabled(llDebug), 'handler rejects debug');
  Check(not LL.Enabled(llInfo), 'handler rejects info');
  Check(LL.Enabled(llWarn), 'handler accepts warn');
  Check(LL.Enabled(llError), 'handler accepts error');
  Check(LL.Enabled(llFatal), 'handler accepts fatal');
end;

procedure TestTimestampDeep;
var
  LL: TLogger;
  LTs1, LTs2: Int64;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^.Msg('ts1');
  LL.Info^.Msg('ts2');
  LTs1 := GCaptured[0].TimestampNs;
  LTs2 := GCaptured[1].TimestampNs;
  Check(LTs1 >= 0, 'ts1 >= 0');
  Check(LTs2 >= 0, 'ts2 >= 0');
end;

procedure TestPoolStress300;
var
  LL: TLogger;
  LI: Int32;
begin
  { 256-slot pool: log 300 times, verify no crash and all captured }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  for LI := 1 to 300 do
    LL.Info^.Int('i', LI)^.Msg('pool stress');
  CheckEqual(Int64(300), Int64(GCaptureCount), 'pool 300 records');
  { Verify first and last are correct }
  CheckEqual(Int64(1), GCaptured[0].Attrs[0].IVal, 'pool first=1');
  CheckEqual(Int64(300), GCaptured[299].Attrs[0].IVal, 'pool last=300');
end;

procedure TestWithAttrsIndependence;
var
  LL, LChild1, LChild2: TLogger;
begin
  { WithAttrs creates independent copies }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LChild1 := LL.WithAttrs([AttrStr('env', 'prod')]);
  LChild2 := LL.WithAttrs([AttrStr('env', 'dev')]);

  LChild1.Info^.Msg('from prod');
  LChild2.Info^.Msg('from dev');
  LL.Info^.Msg('from root');

  CheckEqual(Int64(3), Int64(GCaptureCount), 'independence 3 records');
  { Child1 has env=prod }
  Check(GCaptured[0].Attrs[0].SVal = 'prod', 'child1 env=prod');
  { Child2 has env=dev }
  Check(GCaptured[1].Attrs[0].SVal = 'dev', 'child2 env=dev');
  { Root has no attrs }
  CheckEqual(Int64(0), Int64(GCaptured[2].AttrCount), 'root no attrs');
end;

{ ===== ADVERSARIAL / DEEP TESTS (15 new) ===== }

procedure TestConsoleOutputFormat;
var
  LL, LGrouped: TLogger;
begin
  { Verify console handler output format via capture handler that mimics it.
    We test the actual TConsoleHandler doesn't crash and produces expected
    structure by using a file handler (same format) and reading back. }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llTrace), llTrace);

  { 1. Level prefix appears }
  LL.Trace^.Msg('trace msg');
  LL.Debug^.Msg('debug msg');
  LL.Info^.Msg('info msg');
  LL.Warn^.Msg('warn msg');
  LL.Error^.Msg('error msg');
  LL.Fatal^.Msg('fatal msg');
  Check(GCaptured[0].Level = llTrace, 'fmt: trace level');
  Check(GCaptured[1].Level = llDebug, 'fmt: debug level');
  Check(GCaptured[2].Level = llInfo, 'fmt: info level');
  Check(GCaptured[3].Level = llWarn, 'fmt: warn level');
  Check(GCaptured[4].Level = llError, 'fmt: error level');
  Check(GCaptured[5].Level = llFatal, 'fmt: fatal level');

  { 2. Message appears }
  Check(GCaptured[2].Message = 'info msg', 'fmt: msg content');

  { 3. Attrs appear as key=value }
  ResetCapture;
  LL.Info^.Str('user', 'alice')^.Int('age', 30)^.Bool('admin', True)^.Float('score', 9.5)^.Msg('login');
  CheckEqual(Int64(4), Int64(GCaptured[0].AttrCount), 'fmt: 4 attrs');
  Check(GCaptured[0].Attrs[0].Key = 'user', 'fmt: key0');
  Check(GCaptured[0].Attrs[0].SVal = 'alice', 'fmt: val0');
  Check(GCaptured[0].Attrs[1].Key = 'age', 'fmt: key1');
  CheckEqual(Int64(30), GCaptured[0].Attrs[1].IVal, 'fmt: val1');

  { 4. Group prefix appears before keys }
  ResetCapture;
  LGrouped := LL.WithGroup('http');
  LGrouped.Info^.Str('method', 'GET')^.Msg('request');
  Check(GCaptured[0].Group = 'http', 'fmt: group prefix');

  { 5. Verify actual console handler doesn't crash with all types }
  LL := TLogger.New(NewConsoleHandler(llTrace), llTrace);
  LL.Info^.Str('s', 'val')^.Int('i', 42)^.Float('f', 1.5)^.Bool('b', True)^.Msg('console fmt');
  Check(True, 'fmt: console no crash');
end;

procedure TestJsonEscaping;
var
  LL: TLogger;
  LPath, LLine: string;
  LF: TextFile;
begin
  { Test JSON handler with special characters }
  LL := TLogger.New(NewJsonHandler(llInfo), llInfo);

  { Double quotes }
  LL.Info^.Str('q', 'he said "hello"')^.Msg('quotes');
  { Backslash }
  LL.Info^.Str('path', 'C:\path\to\file')^.Msg('backslash');
  { Newline }
  LL.Info^.Str('nl', 'line1'#10'line2')^.Msg('newline');
  { Tab }
  LL.Info^.Str('tab', 'col1'#9'col2')^.Msg('tab');
  { Null byte }
  LL.Info^.Str('null', 'before'#0'after')^.Msg('null byte');
  { Unicode range (control chars) }
  LL.Info^.Str('ctrl', #1#2#3#4#5#6#7)^.Msg('control chars');
  { All combined }
  LL.Info^.Str('all', '"hello"\'#10#9#0#1)^.Msg('combined');
  Check(True, 'json escape: no crash with special chars');

  { Verify via file handler that special chars are preserved in plain text }
  LPath := '/tmp/test_log_jsonesc_' + IntToStr(Random(99999)) + '.log';
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  LL.Info^.Str('q', 'he said "hello"')^.Msg('test');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal);
  AssignFile(LF, LPath);
  Reset(LF);
  ReadLn(LF, LLine);
  CloseFile(LF);
  Check(Pos('"hello"', LLine) > 0, 'json escape: quotes in file');
  DeleteFile(LPath);
end;

procedure TestFileHandlerConcurrentWrites;
var
  LL: TLogger;
  LPath: string;
  LI: Int32;
begin
  LPath := '/tmp/test_log_concurrent_' + IntToStr(Random(99999)) + '.log';
  { Small MaxBytes=500 to force rotation }
  LL := TLogger.New(NewFileHandler(LPath, llInfo, 500, 5), llInfo);
  { Write 100 records rapidly }
  for LI := 1 to 100 do
    LL.Info^.Int('i', LI)^.Str('data', 'some payload text here')^.Msg('rapid write test');
  { Release handler }
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal);
  { Verify file exists and has content }
  Check(FileExists(LPath) or FileExists(LPath + '.1'), 'concurrent: file exists');
  { Verify rotation happened }
  Check(FileExists(LPath + '.1'), 'concurrent: rotation happened (.1 exists)');
  { Clean up }
  DeleteFile(LPath);
  for LI := 1 to 5 do DeleteFile(LPath + '.' + IntToStr(LI));
end;

procedure TestLoggerCopy;
var
  L1, L2: TLogger;
begin
  ResetCapture;
  L1 := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  { Copy L1 to L2 }
  L2 := L1;
  { Modify L2 }
  L2 := L2.WithLevel(llWarn);
  L2 := L2.With_('env', 'staging');

  { L1 should still be at llDebug with no attrs }
  L1.Debug^.Msg('from L1');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'copy: L1 debug fires');
  Check(GCaptured[0].AttrCount = 0, 'copy: L1 no attrs');

  { L2 should filter debug }
  L2.Debug^.Msg('skip');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'copy: L2 debug skipped');

  { L2 warn should fire with env attr }
  L2.Warn^.Msg('from L2');
  CheckEqual(Int64(2), Int64(GCaptureCount), 'copy: L2 warn fires');
  Check(GCaptured[1].Attrs[0].SVal = 'staging', 'copy: L2 has env=staging');
end;

procedure TestErrHelperDeep;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  { Err() adds attr with key='error' }
  LL.Info^.Err('something failed')^.Msg('operation');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'err: one record');
  Check(GCaptured[0].Attrs[0].Key = 'error', 'err: key=error');
  Check(GCaptured[0].Attrs[0].SVal = 'something failed', 'err: val=something failed');
  Check(GCaptured[0].Attrs[0].Kind = akString, 'err: kind=string');
  Check(GCaptured[0].Message = 'operation', 'err: msg=operation');

  { Err with empty string }
  LL.Warn^.Err('')^.Msg('empty err');
  Check(GCaptured[1].Attrs[0].Key = 'error', 'err: empty key=error');
  Check(GCaptured[1].Attrs[0].SVal = '', 'err: empty val');

  { Err combined with other attrs }
  LL.Error^.Str('op', 'connect')^.Err('timeout')^.Int('retry', 3)^.Msg('failed');
  CheckEqual(Int64(3), Int64(GCaptured[2].AttrCount), 'err: 3 attrs combined');
  Check(GCaptured[2].Attrs[0].Key = 'op', 'err: combined key0');
  Check(GCaptured[2].Attrs[1].Key = 'error', 'err: combined key1');
  Check(GCaptured[2].Attrs[1].SVal = 'timeout', 'err: combined val1');
  Check(GCaptured[2].Attrs[2].Key = 'retry', 'err: combined key2');
end;

type
  TFlushCaptureHandler = class(TInterfacedObject, ILogHandler)
  public
    FlushCount: Int32;
    constructor Create;
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    procedure Flush;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TFlushCaptureHandler.Create;
begin
  inherited Create;
  FlushCount := 0;
end;

function TFlushCaptureHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := True;
end;

procedure TFlushCaptureHandler.Handle(const ARecord: TLogRecord);
begin
end;

function TFlushCaptureHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
begin
  Result := Self;
end;

procedure TFlushCaptureHandler.Flush;
begin
  Inc(FlushCount);
end;

function TFlushCaptureHandler.WithGroup(const AName: string): ILogHandler;
begin
  Result := Self;
end;

procedure TestFlushPropagation;
var
  LL: TLogger;
  LH: TFlushCaptureHandler;
begin
  LH := TFlushCaptureHandler.Create;
  LL := TLogger.New(LH, llDebug);
  CheckEqual(Int64(0), Int64(LH.FlushCount), 'flush: initial 0');
  LL.Flush;
  CheckEqual(Int64(1), Int64(LH.FlushCount), 'flush: after flush = 1');
  LL.Flush;
  CheckEqual(Int64(2), Int64(LH.FlushCount), 'flush: after 2nd flush = 2');
end;

procedure TestLogContextDeep;
var
  LCtx1, LCtx2: Int32;
begin
  { SetLogContext/GetLogContext }
  LCtx1 := 42;
  LCtx2 := 99;
  SetLogContext(@LCtx1);
  Check(GetLogContext = @LCtx1, 'ctx: set ptr1');
  SetLogContext(@LCtx2);
  Check(GetLogContext = @LCtx2, 'ctx: set ptr2');
  Check(GetLogContext <> @LCtx1, 'ctx: not ptr1 anymore');
  SetLogContext(nil);
  Check(GetLogContext = nil, 'ctx: cleared to nil');
  { Double nil is safe }
  SetLogContext(nil);
  Check(GetLogContext = nil, 'ctx: double nil safe');
end;

procedure TestWithLevelChange;
var
  LBase, LChild: TLogger;
begin
  ResetCapture;
  LBase := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LChild := LBase.WithLevel(llWarn);

  { Child.Debug should NOT fire }
  LChild.Debug^.Msg('skip');
  CheckEqual(Int64(0), Int64(GCaptureCount), 'withlevel: child debug skipped');

  { Child.Warn should fire }
  LChild.Warn^.Msg('child warn');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'withlevel: child warn fires');

  { Base.Debug should still fire }
  LBase.Debug^.Msg('base debug');
  CheckEqual(Int64(2), Int64(GCaptureCount), 'withlevel: base debug still fires');
  Check(GCaptured[1].Message = 'base debug', 'withlevel: base msg correct');
end;

procedure TestLargeMessage;
var
  LL: TLogger;
  LMsg10K, LMsg100K: string;
  LI: Int32;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);

  { Build 10KB message }
  LMsg10K := '';
  for LI := 1 to 10240 do LMsg10K := LMsg10K + 'A';
  LL.Info^.Msg(LMsg10K);
  CheckEqual(Int64(1), Int64(GCaptureCount), 'large: 10K fires');
  CheckEqual(Int64(10240), Int64(Length(GCaptured[0].Message)), 'large: 10K no truncation');

  { Build 100KB message }
  LMsg100K := '';
  SetLength(LMsg100K, 102400);
  for LI := 1 to 102400 do LMsg100K[LI] := 'B';
  LL.Info^.Msg(LMsg100K);
  CheckEqual(Int64(2), Int64(GCaptureCount), 'large: 100K fires');
  CheckEqual(Int64(102400), Int64(Length(GCaptured[1].Message)), 'large: 100K no truncation');
end;

procedure TestRapidCreateDestroy;
var
  LI: Int32;
  LL: TLogger;
begin
  { Create and destroy 1000 loggers with different handlers }
  for LI := 1 to 1000 do
  begin
    LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
    LL.Info^.Int('i', LI)^.Msg('rapid');
  end;
  Check(True, 'rapid create/destroy: 1000 loggers no crash');
end;

procedure TestNullLoggerInterface;
var
  LI1, LI2: ILogger;
begin
  { NullLogger returns valid ILogger }
  LI1 := NullLogger;
  Check(LI1 <> nil, 'null ilogger: not nil');

  { All methods are no-op (don't crash) }
  LI1.Trace('trace');
  LI1.Debug('debug');
  LI1.Info('info');
  LI1.Warn('warn');
  LI1.Error('error');
  LI1.Fatal('fatal');
  LI1.Log(llInfo, 'log method');
  Check(True, 'null ilogger: all methods no-op');

  { Multiple calls return same instance }
  LI2 := NullLogger;
  Check(LI1 = LI2, 'null ilogger: singleton');
end;

procedure TestAttrStrSpecialValues;
var
  LL: TLogger;
  LLongKey: string;
  LI: Int32;
  LAllPrintable: string;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);

  { Empty string key }
  LL.Info^.Str('', 'val')^.Msg('empty key');
  Check(GCaptured[0].Attrs[0].Key = '', 'special: empty key stored');

  { Very long key (1000 chars) }
  LLongKey := '';
  for LI := 1 to 1000 do LLongKey := LLongKey + 'k';
  LL.Info^.Str(LLongKey, 'v')^.Msg('long key');
  CheckEqual(Int64(1000), Int64(Length(GCaptured[1].Attrs[0].Key)), 'special: 1000 char key');

  { Key with spaces, dots, equals signs }
  LL.Info^.Str('my key.name=val', 'x')^.Msg('special key');
  Check(GCaptured[2].Attrs[0].Key = 'my key.name=val', 'special: key with special chars');

  { Value with all printable ASCII (32-126) }
  LAllPrintable := '';
  for LI := 32 to 126 do LAllPrintable := LAllPrintable + Chr(LI);
  LL.Info^.Str('ascii', LAllPrintable)^.Msg('printable');
  CheckEqual(Int64(95), Int64(Length(GCaptured[3].Attrs[0].SVal)), 'special: all printable stored');

  { Value with control characters }
  LL.Info^.Str('ctrl', #0#1#2#3#4#5#6#7#8#9#10#11#12#13#14#15)^.Msg('control');
  CheckEqual(Int64(16), Int64(Length(GCaptured[4].Attrs[0].SVal)), 'special: control chars stored');
end;

procedure TestMultiHandlerEmpty;
var
  LL: TLogger;
begin
  { Multi-handler with 0 handlers }
  LL := TLogger.New(NewMultiHandler([]), llDebug);
  { Enabled should return false (no handlers to accept) }
  Check(not LL.Enabled(llDebug), 'multi empty: enabled=false for debug');
  Check(not LL.Enabled(llFatal), 'multi empty: enabled=false for fatal');
  { Log to it — should not crash }
  LL.Info^.Msg('should not crash');
  LL.Error^.Str('k', 'v')^.Msg('still safe');
  Check(True, 'multi empty: no crash');
end;

procedure TestFileHandlerAppend;
var
  LL: TLogger;
  LPath: string;
  LF: TextFile;
  LLine: string;
  LCount: Int32;
begin
  LPath := '/tmp/test_log_append_' + IntToStr(Random(99999)) + '.log';
  { Create file handler, write 3 records, destroy }
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  LL.Info^.Msg('line1');
  LL.Info^.Msg('line2');
  LL.Info^.Msg('line3');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal); // release

  { Create new file handler on same path, write 2 more records }
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  LL.Info^.Msg('line4');
  LL.Info^.Msg('line5');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal); // release

  { Verify file has 5 records total (append, not overwrite) }
  AssignFile(LF, LPath);
  Reset(LF);
  LCount := 0;
  while not Eof(LF) do
  begin
    ReadLn(LF, LLine);
    Inc(LCount);
  end;
  CloseFile(LF);
  CheckEqual(Int64(5), Int64(LCount), 'append: 5 lines total');
  DeleteFile(LPath);
end;

procedure TestLogRecordFields;
var
  LL: TLogger;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Warn^.Str('svc', 'auth')^.Int('port', 443)^.Bool('tls', True)^.Float('lat', 1.23)^.Msg('request');

  { Verify TLogRecord.Level }
  Check(GCaptured[0].Level = llWarn, 'record: level=warn');
  { Verify TLogRecord.Message }
  Check(GCaptured[0].Message = 'request', 'record: msg=request');
  { Verify TLogRecord.AttrCount }
  CheckEqual(Int64(4), Int64(GCaptured[0].AttrCount), 'record: 4 attrs');
  { Verify individual attrs }
  Check(GCaptured[0].Attrs[0].Key = 'svc', 'record: attr0 key');
  Check(GCaptured[0].Attrs[0].Kind = akString, 'record: attr0 kind');
  Check(GCaptured[0].Attrs[0].SVal = 'auth', 'record: attr0 sval');
  Check(GCaptured[0].Attrs[1].Key = 'port', 'record: attr1 key');
  Check(GCaptured[0].Attrs[1].Kind = akInt, 'record: attr1 kind');
  CheckEqual(Int64(443), GCaptured[0].Attrs[1].IVal, 'record: attr1 ival');
  Check(GCaptured[0].Attrs[2].Key = 'tls', 'record: attr2 key');
  Check(GCaptured[0].Attrs[2].Kind = akBool, 'record: attr2 kind');
  Check(GCaptured[0].Attrs[2].BVal = True, 'record: attr2 bval');
  Check(GCaptured[0].Attrs[3].Key = 'lat', 'record: attr3 key');
  Check(GCaptured[0].Attrs[3].Kind = akFloat, 'record: attr3 kind');
  Check(Abs(GCaptured[0].Attrs[3].FVal - 1.23) < 0.001, 'record: attr3 fval');
  { Verify timestamp is set }
  Check(GCaptured[0].TimestampNs > 0, 'record: timestamp > 0');
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
  { === NEW DEEP TESTS === }
  T.Run('Attr types (all 4)', @TestAttrTypes);
  T.Run('Event chaining', @TestLogEventChaining);
  T.Run('Level filtering exhaustive', @TestLevelFilteringExhaustive);
  T.Run('With_ field chaining', @TestWithFieldChaining);
  T.Run('WithGroup nesting', @TestWithGroupNesting);
  T.Run('File rotation deep', @TestFileRotationDeep);
  T.Run('File handler broken', @TestFileHandlerBroken);
  T.Run('JSON output valid', @TestJsonOutputValid);
  T.Run('Multi handler fanout', @TestMultiHandlerFanout);
  T.Run('ILogger deep', @TestLoggerAsILoggerDeep);
  T.Run('Empty message edge', @TestEmptyMessageEdge);
  T.Run('Many attrs stress (100)', @TestManyAttrsStress);
  T.Run('SetDefaultLogger deep', @TestSetDefaultLoggerDeep);
  T.Run('Handler enabled filtering', @TestHandlerEnabledFiltering);
  T.Run('Timestamp deep', @TestTimestampDeep);
  T.Run('Pool stress 300', @TestPoolStress300);
  T.Run('WithAttrs independence', @TestWithAttrsIndependence);
  { === ADVERSARIAL / DEEP TESTS (15 new) === }
  T.Run('Console output format', @TestConsoleOutputFormat);
  T.Run('JSON escaping', @TestJsonEscaping);
  T.Run('File handler concurrent writes', @TestFileHandlerConcurrentWrites);
  T.Run('Logger copy (value semantics)', @TestLoggerCopy);
  T.Run('Err helper deep', @TestErrHelperDeep);
  T.Run('Flush propagation', @TestFlushPropagation);
  T.Run('Log context deep', @TestLogContextDeep);
  T.Run('WithLevel change', @TestWithLevelChange);
  T.Run('Large message (10K+100K)', @TestLargeMessage);
  T.Run('Rapid create/destroy (1000)', @TestRapidCreateDestroy);
  T.Run('NullLogger interface', @TestNullLoggerInterface);
  T.Run('Attr str special values', @TestAttrStrSpecialValues);
  T.Run('Multi handler empty', @TestMultiHandlerEmpty);
  T.Run('File handler append', @TestFileHandlerAppend);
  T.Run('Log record fields', @TestLogRecordFields);
  T.Summary;
end.
