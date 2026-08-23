unit nextpas.core.log;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.log.intf,
  { 异步文件落盘（K37）：TChannel<T> 有界阻塞通道承载日志消息，后台线程
    批量刷盘——写 syscall 移出日志调用线程，热路径不卡 IO。 }
  nextpas.core.thread.channel;

type
  TLogLevel = nextpas.core.log.intf.TLogLevel;

  TAttrKind = (akString, akInt, akFloat, akBool);

  TAttr = record
    Key: string;
    Kind: TAttrKind;
    SVal: string;
    IVal: Int64;
    FVal: Double;
    BVal: Boolean;
  end;

  TLogRecord = record
    Level: TLogLevel;
    Message: string;
    TimestampNs: Int64;
    Attrs: array of TAttr;
    AttrCount: Int32;
    Group: string;
  end;

  { 异步文件落盘消息（K37）：TLogRecord + 渲染态（Group/Prefix）。WithAttrs/
    WithGroup 派生 handler 与父共享同一队列，渲染态随消息传递——worker 端按
    消息渲染，child 前缀不丢。lfkFlush 为排空哨兵：Flush 入队阻塞等待其 ack，
    保证「此刻之前全部落盘」。 }
  TLogFileMsgKind = (lfkRecord, lfkFlush);

  TLogFileMsg = record
    Kind: TLogFileMsgKind;
    Rec: TLogRecord;
    Group: string;
    Prefix: array of TAttr;
    PrefixCount: Int32;
    FlushSeq: Int64;   { lfkFlush 专用：ack 序号 }
  end;

  TLogFileChannel = specialize TChannel<TLogFileMsg>;

  ILogHandler = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-FA2345678901}']
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

  {** PLogEvent points into a global 256-slot event pool (see impl).
   *  Slots are allocated under lock and marked busy; Msg/Send releases.
   *  Holding a PLogEvent across statements while other threads log is safe
   *  (core middleware LoggerMiddleware does exactly this): a busy slot can
   *  never be handed to a second holder, so no cross-thread reuse/clear.
   *  FPC threadvar per-thread pools were tried first, but core threads are
   *  bare pthread_create (bypass FPC BeginThread), so threadvar is shared. *}
  PLogEvent = ^TLogEvent;
  TLogEvent = record
  private
    FRec: TLogRecord;
    FHandler: ILogHandler;
    FEnabled: Boolean;
    procedure AddAttr(const AKey: string; AKind: TAttrKind;
      const ASVal: string; AIVal: Int64; AFVal: Double; ABVal: Boolean);
  public
    function Str(const AKey, AVal: string): PLogEvent;
    function Int(const AKey: string; AVal: Int64): PLogEvent;
    function Float(const AKey: string; AVal: Double): PLogEvent;
    function Bool(const AKey: string; AVal: Boolean): PLogEvent;
    function Err(const AErr: string): PLogEvent;
    procedure Msg(const AText: string);
    procedure Send;
  end;

  TLogger = record
  private
    FHandler: ILogHandler;
    FLevel: TLogLevel;
  public
    class function New(const AHandler: ILogHandler; ALevel: TLogLevel = llInfo): TLogger; static;
    function With_(const AKey, AVal: string): TLogger;
    function WithInt(const AKey: string; AVal: Int64): TLogger;
    function WithAttrs(const AAttrs: array of TAttr): TLogger;
    function WithGroup(const AName: string): TLogger;
    function WithLevel(ALevel: TLogLevel): TLogger;
    function AsILogger: ILogger;
    procedure Flush;
    function Enabled(const ALevel: TLogLevel): Boolean; inline;
    function Trace: PLogEvent;
    function Debug: PLogEvent;
    function Info: PLogEvent;
    function Warn: PLogEvent;
    function Error: PLogEvent;
    function Fatal: PLogEvent;
  end;

function AttrStr(const AKey, AVal: string): TAttr; inline;
function AttrInt(const AKey: string; AVal: Int64): TAttr; inline;
function AttrFloat(const AKey: string; AVal: Double): TAttr; inline;
function AttrBool(const AKey: string; AVal: Boolean): TAttr; inline;

{** 控制台着色开关决策：NO_COLOR 环境变量存在且非空即禁用（no-color.org
    约定）；否则仅当 stderr 是终端时着色。重定向/管道（journald、日志
    采集、测试捕获）输出纯文本，机器解析不被 ANSI 转义字节污染。
    TConsoleHandler 构造时求值一次；导出以便消费方与测试对齐同一契约。 }
function LogConsoleColorsEnabled: Boolean;

function NewConsoleHandler(AMinLevel: TLogLevel = llDebug): ILogHandler;
function NewJsonHandler(AMinLevel: TLogLevel = llDebug): ILogHandler;
function NewFileHandler(const APath: string; AMinLevel: TLogLevel = llDebug;
  AMaxBytes: Int64 = 10 * 1024 * 1024; AMaxFiles: Int32 = 5): ILogHandler;
{ json 渲染的文件 handler（K35 反哺）：与 NewJsonHandler 同格式的结构化行
  落盘 + 大小轮转（AMaxBytes/AMaxFiles 同 NewFileHandler 语义），供 json
  模式下日志采集直接读文件（日志系统可采集，无需再经 stdout 重定向）。 }
function NewJsonFileHandler(const APath: string; AMinLevel: TLogLevel = llDebug;
  AMaxBytes: Int64 = 10 * 1024 * 1024; AMaxFiles: Int32 = 5): ILogHandler;
{ 异步文件落盘（K37）：与 NewFileHandler/NewJsonFileHandler 同渲染语义的
  后台批量写变体——有界队列（AQueueCapacity）承载消息，worker 线程攒批刷盘
  （每 cLogFileBatchFlush 条一次 Flush，写 syscall 合并，移出调用线程）；
  队列满 → 同步直写兜底（不丢日志，仅退化为同步）；Flush 阻塞等待排空 ack；
  handler 释放时 Close + join 排空。 }
function NewAsyncFileHandler(const APath: string; AMinLevel: TLogLevel = llDebug;
  AMaxBytes: Int64 = 10 * 1024 * 1024; AMaxFiles: Int32 = 5;
  AQueueCapacity: Int32 = 65536): ILogHandler;
function NewAsyncJsonFileHandler(const APath: string; AMinLevel: TLogLevel = llDebug;
  AMaxBytes: Int64 = 10 * 1024 * 1024; AMaxFiles: Int32 = 5;
  AQueueCapacity: Int32 = 65536): ILogHandler;
function NewMultiHandler(const AHandlers: array of ILogHandler): ILogHandler;

procedure SetDefaultLogger(const ALogger: TLogger);
function DefaultLogger: TLogger;

procedure SetLogContext(ACtx: Pointer);
function GetLogContext: Pointer;

procedure LogTrace(const AMsg: string);
procedure LogDebug(const AMsg: string);
procedure LogInfo(const AMsg: string);
procedure LogWarn(const AMsg: string);
procedure LogError(const AMsg: string);

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.platform.env,
  nextpas.core.platform.console,
  nextpas.core.time.base,
  { 异步文件落盘 worker（K37）：线程基类 + Flush ack 的 mutex/condvar 原语 }
  nextpas.core.thread.base,
  nextpas.core.platform.sync;

const
  LEVEL_NAMES: array[TLogLevel] of string = (
    'TRC', 'DBG', 'INF', 'WRN', 'ERR', 'FTL'
  );
  LEVEL_COLORS: array[TLogLevel] of string = (
    #27'[90m', #27'[36m', #27'[32m', #27'[33m', #27'[31m', #27'[35;1m'
  );
  RESET = #27'[0m';
  DIM = #27'[90m';

{** 内联文件存在检查，避免引入 L2 nextpas.core.fs.util }
function FileExists(const APath: string): Boolean;
var
  LStat: TPlatformFileStat;
begin
  Result := platform_file_stat(PAnsiChar(AnsiString(APath)), LStat) = 0;
end;

{ Attr constructors }

function AttrStr(const AKey, AVal: string): TAttr;
begin
  Result.Key := AKey; Result.Kind := akString; Result.SVal := AVal;
end;

function AttrInt(const AKey: string; AVal: Int64): TAttr;
begin
  Result.Key := AKey; Result.Kind := akInt; Result.IVal := AVal;
end;

function AttrFloat(const AKey: string; AVal: Double): TAttr;
begin
  Result.Key := AKey; Result.Kind := akFloat; Result.FVal := AVal;
end;

function AttrBool(const AKey: string; AVal: Boolean): TAttr;
begin
  Result.Key := AKey; Result.Kind := akBool; Result.BVal := AVal;
end;

{ TLogEvent }

procedure TLogEvent.AddAttr(const AKey: string; AKind: TAttrKind;
  const ASVal: string; AIVal: Int64; AFVal: Double; ABVal: Boolean);
var
  LIdx: Int32;
begin
  LIdx := FRec.AttrCount;
  if LIdx >= Length(FRec.Attrs) then
    SetLength(FRec.Attrs, Length(FRec.Attrs) + 8);
  FRec.Attrs[LIdx].Key := AKey;
  FRec.Attrs[LIdx].Kind := AKind;
  FRec.Attrs[LIdx].SVal := ASVal;
  FRec.Attrs[LIdx].IVal := AIVal;
  FRec.Attrs[LIdx].FVal := AFVal;
  FRec.Attrs[LIdx].BVal := ABVal;
  Inc(FRec.AttrCount);
end;

function TLogEvent.Str(const AKey, AVal: string): PLogEvent;
begin
  if FEnabled then AddAttr(AKey, akString, AVal, 0, 0, False);
  Result := @Self;
end;

function TLogEvent.Int(const AKey: string; AVal: Int64): PLogEvent;
begin
  if FEnabled then AddAttr(AKey, akInt, '', AVal, 0, False);
  Result := @Self;
end;

function TLogEvent.Float(const AKey: string; AVal: Double): PLogEvent;
begin
  if FEnabled then AddAttr(AKey, akFloat, '', 0, AVal, False);
  Result := @Self;
end;

function TLogEvent.Bool(const AKey: string; AVal: Boolean): PLogEvent;
begin
  if FEnabled then AddAttr(AKey, akBool, '', 0, 0, AVal);
  Result := @Self;
end;

function TLogEvent.Err(const AErr: string): PLogEvent;
begin
  if FEnabled then AddAttr('error', akString, AErr, 0, 0, False);
  Result := @Self;
end;

{ 事件池：全局 256 槽 + 锁内分配 + 占用标记。
  原实现（原子自增轮转）在多线程「取槽后跨语句持有」时会被其他线程
  轮转复用同槽清零覆盖，产出拆行/混行（core LoggerMiddleware 即此用法：
  Info 取槽 → ServeHTTP → 跨请求处理 → Msg）。threadvar 每线程池方案在
  core 裸 pthread 线程（绕过 FPC BeginThread）下不隔离，同样失效。
  现改为：NextEventSlot 在锁内扫描空闲槽并标记占用，Msg/Send 后归还，
  同一槽同一时刻只属于一个持有者。256 并发长持有是理论上限，耗尽时
  退化为轮转覆盖（兜底，不阻塞）。 }
var
  GEventPool: array[0..255] of TLogEvent;
  GEventBusy: array[0..255] of Boolean;
  GEventIdx: Int32 = 0;
  GEventLock: TRTLCriticalSection;
  GFinI: Int32; { finalization 清理循环用 }

function NextEventSlot: PLogEvent; inline;
var
  LIdx, LI: Int32;
begin
  EnterCriticalSection(GEventLock);
  try
    LIdx := GEventIdx;
    for LI := 0 to 255 do
    begin
      if not GEventBusy[LIdx] then
      begin
        GEventBusy[LIdx] := True;
        GEventIdx := (LIdx + 1) and 255;
        Exit(@GEventPool[LIdx]);
      end;
      LIdx := (LIdx + 1) and 255;
    end;
    { 全部占用（≥256 并发长持有，极端）：退化为轮转覆盖，保证不阻塞。 }
    LIdx := GEventIdx;
    GEventIdx := (LIdx + 1) and 255;
    Result := @GEventPool[LIdx];
  finally
    LeaveCriticalSection(GEventLock);
  end;
end;

procedure ReleaseEventSlot(const AEvent: PLogEvent); inline;
var
  LIdx: Int32;
begin
  LIdx := Int32((PtrUInt(AEvent) - PtrUInt(@GEventPool[0])) div SizeOf(TLogEvent));
  if (LIdx >= 0) and (LIdx < 256) and GEventBusy[LIdx] then
  begin
    EnterCriticalSection(GEventLock);
    try
      GEventBusy[LIdx] := False;
      { 释放槽内驻留的 managed 引用（FHandler 接口等）：否则空闲槽仍持有
        ILogHandler，导致 handler 引用计数无法归零——TLogger 释放、异步
        落盘 sink 不回收、drain 不触发（文件落盘/轮转依赖时序成竞态）。 }
      Finalize(GEventPool[LIdx]);
    finally
      LeaveCriticalSection(GEventLock);
    end;
  end;
end;

{ 静态只读空槽：level 过滤（disabled）时返回，FEnabled=False 使 Str/Int/
  Msg 全部跳过，既不占用池槽也避免 nil 解引用。全程零写入，多线程共享
  无竞争；TLogEvent 含 managed 字段，静态初始化后字段为默认空值，安全。 }
var
  GNullEvent: TLogEvent;

{ 分配事件槽并初始化。level 未开启（含 nil handler）时不占池槽，返回静态
  只读空槽。启用时取锁内槽并标记占用，调用方在 Msg/Send 后归还。 }
function AllocEventSlot(const ALogger: TLogger; const ALevel: TLogLevel): PLogEvent; inline;
begin
  if not ALogger.Enabled(ALevel) then
  begin
    Result := @GNullEvent;
    Exit;
  end;
  Result := NextEventSlot;
  Finalize(Result^);
  FillChar(Result^, SizeOf(TLogEvent), 0);
  Result^.FHandler := ALogger.FHandler;
  Result^.FEnabled := True;
  Result^.FRec.Level := ALevel;
end;

{ 每线程独立的重入检测计数器（threadvar 自动零初始化） }
threadvar
  GLogDepth: Int32;

procedure TLogEvent.Msg(const AText: string);
begin
  if not FEnabled then Exit;
  FEnabled := False;
  FRec.Message := AText;
  FRec.TimestampNs := TInstant.Now.Elapsed.AsNanoseconds;
  Inc(GLogDepth);
  try
    if GLogDepth > 1 then
      WriteLn(StdErr, '[REENTRANT] ', LEVEL_NAMES[FRec.Level], ' ', AText)
    else
      FHandler.Handle(FRec);
  finally
    Dec(GLogDepth);
    { 归还事件槽：正常与异常路径都释放，避免 256 槽耗尽后退化覆盖。 }
    ReleaseEventSlot(@Self);
  end;
end;

procedure TLogEvent.Send;
begin
  Msg('');
end;

{ TLogger }

class function TLogger.New(const AHandler: ILogHandler; ALevel: TLogLevel): TLogger;
begin
  Result.FHandler := AHandler;
  Result.FLevel := ALevel;
end;

function TLogger.With_(const AKey, AVal: string): TLogger;
begin
  if FHandler = nil then begin Result := Self; Exit; end;
  Result.FHandler := FHandler.WithAttrs([AttrStr(AKey, AVal)]);
  Result.FLevel := FLevel;
end;

function TLogger.WithInt(const AKey: string; AVal: Int64): TLogger;
begin
  if FHandler = nil then begin Result := Self; Exit; end;
  Result.FHandler := FHandler.WithAttrs([AttrInt(AKey, AVal)]);
  Result.FLevel := FLevel;
end;

function TLogger.WithAttrs(const AAttrs: array of TAttr): TLogger;
begin
  if FHandler = nil then begin Result := Self; Exit; end;
  Result.FHandler := FHandler.WithAttrs(AAttrs);
  Result.FLevel := FLevel;
end;

function TLogger.WithGroup(const AName: string): TLogger;
begin
  if FHandler = nil then begin Result := Self; Exit; end;
  Result.FHandler := FHandler.WithGroup(AName);
  Result.FLevel := FLevel;
end;

function TLogger.WithLevel(ALevel: TLogLevel): TLogger;
begin
  Result.FHandler := FHandler;
  Result.FLevel := ALevel;
end;

procedure TLogger.Flush;
begin
  if FHandler <> nil then
    FHandler.Flush;
end;

function TLogger.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := (FHandler <> nil) and (ALevel >= FLevel) and FHandler.Enabled(ALevel);
end;

function TLogger.Trace: PLogEvent;
begin
  Result := AllocEventSlot(Self, llTrace);
end;

function TLogger.Debug: PLogEvent;
begin
  Result := AllocEventSlot(Self, llDebug);
end;

function TLogger.Info: PLogEvent;
begin
  Result := AllocEventSlot(Self, llInfo);
end;

function TLogger.Warn: PLogEvent;
begin
  Result := AllocEventSlot(Self, llWarn);
end;

function TLogger.Error: PLogEvent;
begin
  Result := AllocEventSlot(Self, llError);
end;

function TLogger.Fatal: PLogEvent;
begin
  Result := AllocEventSlot(Self, llFatal);
end;

{ Console Handler }

{ NO_COLOR 约定（no-color.org）：存在且非空即禁用；否则仅 stderr 为终端
  时着色（fd 2——控制台日志写往 StdErr）。重定向/管道输出纯文本。 }
function LogConsoleColorsEnabled: Boolean;
begin
  if platform_env_get_str('NO_COLOR') <> '' then
    Exit(False);
  Result := platform_console_is_terminal(2);
end;

type
  TConsoleHandler = class(TInterfacedObject, ILogHandler)
  private
    FMinLevel: TLogLevel;
    FPrefix: array of TAttr;
    FPrefixCount: Int32;
    FGroup: string;
    FColor: Boolean;
    FLock: TRTLCriticalSection;
  public
    constructor Create(AMinLevel: TLogLevel);
    destructor Destroy; override;
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TConsoleHandler.Create(AMinLevel: TLogLevel);
begin
  inherited Create;
  FMinLevel := AMinLevel;
  FPrefixCount := 0;
  FColor := LogConsoleColorsEnabled;
  InitCriticalSection(FLock);
end;

destructor TConsoleHandler.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

function TConsoleHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure TConsoleHandler.Handle(const ARecord: TLogRecord);
var
  LI: Int32;
  LA: TAttr;
  LKeyPrefix: string;
begin
  EnterCriticalSection(FLock);
  try
    if FGroup <> '' then LKeyPrefix := FGroup + '.' else LKeyPrefix := '';
    if FColor then
      Write(StdErr, LEVEL_COLORS[ARecord.Level], LEVEL_NAMES[ARecord.Level], RESET, ' ')
    else
      Write(StdErr, LEVEL_NAMES[ARecord.Level], ' ');
    if ARecord.Message <> '' then
      Write(StdErr, ARecord.Message);
    for LI := 0 to FPrefixCount - 1 do
    begin
      LA := FPrefix[LI];
      if FColor then
        Write(StdErr, ' ', DIM, LKeyPrefix, LA.Key, '=', RESET)
      else
        Write(StdErr, ' ', LKeyPrefix, LA.Key, '=');
      case LA.Kind of
        akString: Write(StdErr, LA.SVal);
        akInt: Write(StdErr, LA.IVal);
        akFloat: Write(StdErr, LA.FVal:0:2);
        akBool: if LA.BVal then Write(StdErr, 'true') else Write(StdErr, 'false');
      end;
    end;
    for LI := 0 to ARecord.AttrCount - 1 do
    begin
      LA := ARecord.Attrs[LI];
      if FColor then
        Write(StdErr, ' ', DIM, LKeyPrefix, LA.Key, '=', RESET)
      else
        Write(StdErr, ' ', LKeyPrefix, LA.Key, '=');
      case LA.Kind of
        akString: Write(StdErr, LA.SVal);
        akInt: Write(StdErr, LA.IVal);
        akFloat: Write(StdErr, LA.FVal:0:2);
        akBool: if LA.BVal then Write(StdErr, 'true') else Write(StdErr, 'false');
      end;
    end;
    WriteLn(StdErr);
    { FPC TextFile（StdErr）有内部缓冲：锁内多条 Write 可能滞留，flush 时与
      其他线程待冲内容粘行。行尾立即 Flush 保证每行原子完整落盘。 }
    System.Flush(StdErr);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TConsoleHandler.Flush;
begin
  System.Flush(StdErr);
end;

function TConsoleHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var
  LNew: TConsoleHandler;
  LI: Int32;
begin
  LNew := TConsoleHandler.Create(FMinLevel);
  LNew.FGroup := FGroup;
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do
    LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do
    LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

function TConsoleHandler.WithGroup(const AName: string): ILogHandler;
var
  LNew: TConsoleHandler;
  LI: Int32;
begin
  LNew := TConsoleHandler.Create(FMinLevel);
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

{ JSON Handler }

type
  TJsonLogHandler = class(TInterfacedObject, ILogHandler)
  private
    FMinLevel: TLogLevel;
    FPrefix: array of TAttr;
    FPrefixCount: Int32;
    FGroup: string;
    FLock: TRTLCriticalSection;
  public
    constructor Create(AMinLevel: TLogLevel);
    destructor Destroy; override;
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    procedure Flush;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TJsonLogHandler.Create(AMinLevel: TLogLevel);
begin
  inherited Create;
  FMinLevel := AMinLevel;
  FPrefixCount := 0;
  InitCriticalSection(FLock);
end;

destructor TJsonLogHandler.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

function TJsonLogHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure WriteJsonStrTo(var AOut: TextFile; const AStr: string);
var
  LI: Int32;
  LCh: Char;
  LBuf: string;
begin
  LBuf := '"';
  for LI := 1 to Length(AStr) do
  begin
    LCh := AStr[LI];
    case LCh of
      '"': LBuf := LBuf + '\"';
      '\': LBuf := LBuf + '\\';
      #8: LBuf := LBuf + '\b';
      #9: LBuf := LBuf + '\t';
      #10: LBuf := LBuf + '\n';
      #12: LBuf := LBuf + '\f';
      #13: LBuf := LBuf + '\r';
    else
      if LCh < #32 then
        LBuf := LBuf + '\u00' + HexStr(Ord(LCh), 2)
      else
        LBuf := LBuf + LCh;
    end;
  end;
  LBuf := LBuf + '"';
  Write(AOut, LBuf);
end;

procedure WriteJsonAttrTo(var AOut: TextFile; var AFirst: Boolean;
  const AGroup: string; const LA: TAttr);
var LKey: string;
begin
  if not AFirst then Write(AOut, ',');
  AFirst := False;
  if AGroup <> '' then LKey := AGroup + '.' + LA.Key else LKey := LA.Key;
  WriteJsonStrTo(AOut, LKey);
  Write(AOut, ':');
  case LA.Kind of
    akString: WriteJsonStrTo(AOut, LA.SVal);
    akInt: Write(AOut, LA.IVal);
    akFloat: Write(AOut, LA.FVal:0:6);
    akBool: if LA.BVal then Write(AOut, 'true') else Write(AOut, 'false');
  end;
end;

{ 渲染一行 JSON 日志到 AOut（K35 反哺共享：TJsonLogHandler 写 StdErr 与
  TFileHandler json 模式写文件用同一渲染，保证 stdout/落盘行格式完全一致）。 }
procedure WriteJsonRecordTo(var AOut: TextFile; const ARecord: TLogRecord;
  const AGroup: string; const APrefix: array of TAttr; APrefixCount: Int32);
var
  LI: Int32;
  LFirst: Boolean;
begin
  Write(AOut, '{"level":"', LEVEL_NAMES[ARecord.Level], '"');
  if ARecord.Message <> '' then
  begin
    Write(AOut, ',"msg":');
    WriteJsonStrTo(AOut, ARecord.Message);
  end;
  Write(AOut, ',"ts":', ARecord.TimestampNs);
  LFirst := False;
  for LI := 0 to APrefixCount - 1 do
    WriteJsonAttrTo(AOut, LFirst, AGroup, APrefix[LI]);
  for LI := 0 to ARecord.AttrCount - 1 do
    WriteJsonAttrTo(AOut, LFirst, AGroup, ARecord.Attrs[LI]);
  WriteLn(AOut, '}');
end;

procedure TJsonLogHandler.Handle(const ARecord: TLogRecord);
begin
  EnterCriticalSection(FLock);
  try
    WriteJsonRecordTo(StdErr, ARecord, FGroup, FPrefix, FPrefixCount);
    { 与 ConsoleHandler 同理：行尾立即 Flush，避免缓冲滞留与其他线程粘行。 }
    System.Flush(StdErr);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TJsonLogHandler.Flush;
begin
  System.Flush(StdErr);
end;

function TJsonLogHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var
  LNew: TJsonLogHandler;
  LI: Int32;
begin
  LNew := TJsonLogHandler.Create(FMinLevel);
  LNew.FGroup := FGroup;
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do
    LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do
    LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

function TJsonLogHandler.WithGroup(const AName: string): ILogHandler;
var
  LNew: TJsonLogHandler;
  LI: Int32;
begin
  LNew := TJsonLogHandler.Create(FMinLevel);
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

{ Factory }

function NewConsoleHandler(AMinLevel: TLogLevel): ILogHandler;
begin
  Result := TConsoleHandler.Create(AMinLevel);
end;

function NewJsonHandler(AMinLevel: TLogLevel): ILogHandler;
begin
  Result := TJsonLogHandler.Create(AMinLevel);
end;

{ Global }

var
  GDefault: TLogger;
  GDefaultInit: Int32 = 0; { 0=not init, 1=init }
  GDefaultLock: TRTLCriticalSection;
  GLogContext: Pointer = nil;

procedure SetLogContext(ACtx: Pointer);
begin
  EnterCriticalSection(GDefaultLock);
  GLogContext := ACtx;
  LeaveCriticalSection(GDefaultLock);
end;

function GetLogContext: Pointer;
begin
  EnterCriticalSection(GDefaultLock);
  Result := GLogContext;
  LeaveCriticalSection(GDefaultLock);
end;

procedure SetDefaultLogger(const ALogger: TLogger);
begin
  EnterCriticalSection(GDefaultLock);
  try
    GDefault := ALogger;
    GDefaultInit := 1;
  finally
    LeaveCriticalSection(GDefaultLock);
  end;
end;

function DefaultLogger: TLogger;
begin
  if InterlockedCompareExchange(GDefaultInit, GDefaultInit, 1) <> 1 then
  begin
    EnterCriticalSection(GDefaultLock);
    try
      if GDefaultInit = 0 then
      begin
        GDefault := TLogger.New(NewConsoleHandler(llInfo), llInfo);
        GDefaultInit := 1;
      end;
    finally
      LeaveCriticalSection(GDefaultLock);
    end;
  end;
  Result := GDefault;
end;

procedure LogTrace(const AMsg: string);
begin DefaultLogger.Trace^.Msg(AMsg); end;

procedure LogDebug(const AMsg: string);
begin DefaultLogger.Debug^.Msg(AMsg); end;

procedure LogInfo(const AMsg: string);
begin DefaultLogger.Info^.Msg(AMsg); end;

procedure LogWarn(const AMsg: string);
begin DefaultLogger.Warn^.Msg(AMsg); end;

procedure LogError(const AMsg: string);
begin DefaultLogger.Error^.Msg(AMsg); end;

{ TFileHandler }

type
  TFileHandler = class(TInterfacedObject, ILogHandler)
  private
    FPath: string;
    FMinLevel: TLogLevel;
    FMaxBytes: Int64;
    FMaxFiles: Int32;
    FFile: TextFile;
    FCurrentSize: Int64;
    FOpened: Boolean;
    FBroken: Boolean;
    FPrefix: array of TAttr;
    FPrefixCount: Int32;
    FGroup: string;
    FJson: Boolean;
    FLock: TRTLCriticalSection;
    procedure EnsureOpen;
    procedure Rotate;
    { 锁内写一行（轮转 + 渲染 + 尺寸累计，不 Flush）：同步 Handle 与异步
       worker/兜底路径共用同一渲染，行为与格式完全一致。 }
    procedure WriteLine(const AGroup: string;
      const APrefix: array of TAttr; const APrefixCount: Int32;
      const ARecord: TLogRecord);
  public
    constructor Create(const APath: string; AMinLevel: TLogLevel;
      AMaxBytes: Int64; AMaxFiles: Int32; AJson: Boolean = False);
    destructor Destroy; override;
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    { 异步批量写（K37）：不 Flush，攒批由 worker 一次性落 OS（syscall 合并） }
    procedure HandleRaw(const AMsg: TLogFileMsg);
    { 兜底直写（K37）：队列满/关闭时同步写 + 立即 Flush（不丢日志） }
    procedure HandleMsg(const AMsg: TLogFileMsg);
    procedure Flush;
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TFileHandler.Create(const APath: string; AMinLevel: TLogLevel;
  AMaxBytes: Int64; AMaxFiles: Int32; AJson: Boolean);
begin
  inherited Create;
  FPath := APath;
  FMinLevel := AMinLevel;
  FMaxBytes := AMaxBytes;
  FMaxFiles := AMaxFiles;
  FJson := AJson;
  FOpened := False;
  FCurrentSize := 0;
  FPrefixCount := 0;
  InitCriticalSection(FLock);
end;

destructor TFileHandler.Destroy;
begin
  if FOpened then
    System.Close(FFile);
  DoneCriticalSection(FLock);
  inherited;
end;

procedure TFileHandler.EnsureOpen;
begin
  if FBroken or FOpened then Exit;
  try
    AssignFile(FFile, FPath);
    if FileExists(FPath) then
      Append(FFile)
    else
      Rewrite(FFile);
    FOpened := True;
  except
    on E: Exception do
    begin
      FBroken := True;
      WriteLn(StdErr, '[LOG] FileHandler broken: ', E.Message);
    end;
  end;
end;

procedure TFileHandler.Rotate;
var
  LI: Int32;
  LSrc, LDst: string;
begin
  if FOpened then
  begin
    System.Close(FFile);
    FOpened := False;
  end;
  LDst := FPath + '.' + IntToStr(FMaxFiles);
  if FileExists(LDst) then platform_file_unlink(PAnsiChar(LDst));
  for LI := FMaxFiles - 1 downto 1 do
  begin
    LSrc := FPath + '.' + IntToStr(LI);
    LDst := FPath + '.' + IntToStr(LI + 1);
    if FileExists(LSrc) then platform_file_rename(PAnsiChar(LSrc), PAnsiChar(LDst));
  end;
  if FileExists(FPath) then platform_file_rename(PAnsiChar(FPath), PAnsiChar(FPath + '.1'));
  FCurrentSize := 0;
end;

function TFileHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure TFileHandler.WriteLine(const AGroup: string;
  const APrefix: array of TAttr; const APrefixCount: Int32;
  const ARecord: TLogRecord);
var
  LI: Int32;
  LSize: Int64;
  LKeyPrefix: string;
  LAttr: TAttr;
begin
  { 调用者须持 FLock（handle/worker/兜底三路并发安全） }
  if FCurrentSize >= FMaxBytes then Rotate;
  EnsureOpen;
  if not FOpened then Exit;
  if FJson then
  begin
    WriteJsonRecordTo(FFile, ARecord, AGroup, APrefix, APrefixCount);
    { json 行长度以渲染字节量近似（轮转触发只需单调超限，
      不要求字节精确）：level/msg/ts 常量 + 键值与前缀。 }
    LSize := Int64(Length(LEVEL_NAMES[ARecord.Level])) + 8 +
      Int64(Length(ARecord.Message)) + 8 +
      Int64(Length(ARecord.Group));
    for LI := 0 to APrefixCount - 1 do
    begin
      LAttr := APrefix[LI];
      LSize := LSize + Int64(Length(LAttr.Key)) + Int64(Length(LAttr.SVal)) + 12;
    end;
    for LI := 0 to ARecord.AttrCount - 1 do
    begin
      LAttr := ARecord.Attrs[LI];
      LSize := LSize + Int64(Length(LAttr.Key)) + Int64(Length(LAttr.SVal)) + 12;
    end;
    Inc(FCurrentSize, LSize);
    Exit;
  end;
  if AGroup <> '' then LKeyPrefix := AGroup + '.' else LKeyPrefix := '';
  LSize := Int64(Length(LEVEL_NAMES[ARecord.Level])) + 1 + Int64(Length(ARecord.Message));
  Write(FFile, LEVEL_NAMES[ARecord.Level], ' ', ARecord.Message);
  for LI := 0 to APrefixCount - 1 do
  begin
    Write(FFile, ' ', LKeyPrefix, APrefix[LI].Key, '=');
    LSize := LSize + 2 + Int64(Length(LKeyPrefix)) + Int64(Length(APrefix[LI].Key));
    case APrefix[LI].Kind of
      akString: begin Write(FFile, APrefix[LI].SVal); LSize := LSize + Int64(Length(APrefix[LI].SVal)); end;
      akInt: begin Write(FFile, APrefix[LI].IVal); LSize := LSize + 12; end;
      akFloat: begin Write(FFile, APrefix[LI].FVal:0:2); LSize := LSize + 10; end;
      akBool: if APrefix[LI].BVal then begin Write(FFile, 'true'); LSize := LSize + 4; end
              else begin Write(FFile, 'false'); LSize := LSize + 5; end;
    end;
  end;
  for LI := 0 to ARecord.AttrCount - 1 do
  begin
    Write(FFile, ' ', LKeyPrefix, ARecord.Attrs[LI].Key, '=');
    LSize := LSize + 2 + Int64(Length(LKeyPrefix)) + Int64(Length(ARecord.Attrs[LI].Key));
    case ARecord.Attrs[LI].Kind of
      akString: begin Write(FFile, ARecord.Attrs[LI].SVal); LSize := LSize + Int64(Length(ARecord.Attrs[LI].SVal)); end;
      akInt: begin Write(FFile, ARecord.Attrs[LI].IVal); LSize := LSize + 12; end;
      akFloat: begin Write(FFile, ARecord.Attrs[LI].FVal:0:2); LSize := LSize + 10; end;
      akBool: if ARecord.Attrs[LI].BVal then begin Write(FFile, 'true'); LSize := LSize + 4; end
              else begin Write(FFile, 'false'); LSize := LSize + 5; end;
    end;
  end;
  WriteLn(FFile);
  Inc(FCurrentSize, LSize + 1);
end;

procedure TFileHandler.Handle(const ARecord: TLogRecord);
begin
  if FBroken then Exit;
  EnterCriticalSection(FLock);
  try
    if FBroken then Exit;
    try
      WriteLine(FGroup, FPrefix, FPrefixCount, ARecord);
      { 同步路径保持逐行 Flush（实时可见，与既有语义一致） }
      System.Flush(FFile);
    except
      on E: Exception do
      begin
        FBroken := True;
        if FOpened then begin System.Close(FFile); FOpened := False; end;
      end;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TFileHandler.HandleRaw(const AMsg: TLogFileMsg);
begin
  EnterCriticalSection(FLock);
  try
    if FBroken then Exit;
    try
      WriteLine(AMsg.Group, AMsg.Prefix, AMsg.PrefixCount, AMsg.Rec);
    except
      on E: Exception do
      begin
        FBroken := True;
        if FOpened then begin System.Close(FFile); FOpened := False; end;
      end;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TFileHandler.HandleMsg(const AMsg: TLogFileMsg);
begin
  EnterCriticalSection(FLock);
  try
    if FBroken then Exit;
    try
      WriteLine(AMsg.Group, AMsg.Prefix, AMsg.PrefixCount, AMsg.Rec);
      System.Flush(FFile);
    except
      on E: Exception do
      begin
        FBroken := True;
        if FOpened then begin System.Close(FFile); FOpened := False; end;
      end;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TFileHandler.Flush;
begin
  { 与写互斥（worker 攒批/兜底并发场景）：FPC TextFile 内部缓冲无锁，
    并发 Write/Flush 会损坏缓冲状态（实测 Disk Full 伪错误）。 }
  EnterCriticalSection(FLock);
  try
    if FOpened then System.Flush(FFile);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TFileHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var
  LNew: TFileHandler;
  LI: Int32;
begin
  // Note: child shares same path but opens independently (append mode).
  // Rotation tracking is per-instance. For production use with child loggers,
  // prefer MultiHandler with a single FileHandler + ConsoleHandler for children.
  LNew := TFileHandler.Create(FPath, FMinLevel, FMaxBytes, FMaxFiles, FJson);
  LNew.FGroup := FGroup;
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

function TFileHandler.WithGroup(const AName: string): ILogHandler;
var
  LNew: TFileHandler;
  LI: Int32;
begin
  LNew := TFileHandler.Create(FPath, FMinLevel, FMaxBytes, FMaxFiles, FJson);
  SetLength(LNew.FPrefix, FPrefixCount);
  for LI := 0 to FPrefixCount - 1 do LNew.FPrefix[LI] := FPrefix[LI];
  LNew.FPrefixCount := FPrefixCount;
  if FGroup <> '' then
    LNew.FGroup := FGroup + '.' + AName
  else
    LNew.FGroup := AName;
  Result := LNew;
end;

function NewFileHandler(const APath: string; AMinLevel: TLogLevel;
  AMaxBytes: Int64; AMaxFiles: Int32): ILogHandler;
begin
  Result := TFileHandler.Create(APath, AMinLevel, AMaxBytes, AMaxFiles, False);
end;

function NewJsonFileHandler(const APath: string; AMinLevel: TLogLevel;
  AMaxBytes: Int64; AMaxFiles: Int32): ILogHandler;
begin
  Result := TFileHandler.Create(APath, AMinLevel, AMaxBytes, AMaxFiles, True);
end;

{ ===== 异步文件落盘（K37）：TLogFileWorker / TLogFileSink / TAsyncFileHandler ===== }

{ 批量攒批阈值：每 cLogFileBatchFlush 条主动 Flush 一次（写 syscall 合并、
  采集实时性上界 = 阈值条延迟；崩溃丢失窗口同理有界） }
const
  cLogFileBatchFlush = 256;

type
  PPlatformMutex = ^TPlatformMutex;
  PPlatformCondVar = ^TPlatformCondVar;

  { 后台消费线程：记录消息攒批写（不 Flush），遇 lfkFlush 哨兵 → 落盘 + ack
    （FAckMu/FAckCond 由 sink 创建共享，Flush 侧阻塞等 ack）。TChannel 语义：
    Close 后剩余仍可消费（空且 Close 才返回 False）——停机 drain 由 sink
    Shutdown 的 Close + WaitFor 保证，残余记录不丢。 }
  TLogFileWorker = class(TWorkerThread)
  private
    FChannel: TLogFileChannel;
    FIO: TFileHandler;
    FAckMu: PPlatformMutex;        { sink 所有，worker 只 ack }
    FAckCond: PPlatformCondVar;
    FAckSeq: PInt64;               { ^sink.FAckSeq：ack 写共享计数（Flush 侧读） }
  protected
    procedure Execute; override;
  public
    constructor Create(const AChannel: TLogFileChannel;
      const AFileHandler: TFileHandler;
      const AAckMu: PPlatformMutex; const AAckCond: PPlatformCondVar;
      const AAckSeq: PInt64);
  end;

  { 异步落盘共享核心：有界队列 + worker + Flush ack。多个 TAsyncFileHandler
    （WithAttrs/WithGroup 派生）共享同一核心——写序 FIFO 由通道保证、渲染态
    随消息（child 前缀不丢）；引用归零 → Destroy 关通道 + join 排空。 }
  ILogFileSink = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Push(const AMsg: TLogFileMsg);
    procedure Flush;
  end;

  TLogFileSink = class(TInterfacedObject, ILogFileSink)
  private
    FChannel: TLogFileChannel;
    FIO: TFileHandler;
    FWorker: TLogFileWorker;
    FAckMu: TPlatformMutex;
    FAckCond: TPlatformCondVar;
    FAckSeq: Int64;
    FSeqMu: TRTLCriticalSection;
    FFlushSeq: Int64;
  public
    constructor Create(const APath: string; AMinLevel: TLogLevel;
      AMaxBytes: Int64; AMaxFiles: Int32; AJson: Boolean; ACapacity: Int32);
    destructor Destroy; override;
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Push(const AMsg: TLogFileMsg);
    procedure Flush;
  end;

  TAsyncFileHandler = class(TInterfacedObject, ILogHandler)
  private
    FSink: ILogFileSink;   { 接口引用：最后一个 handler 释放 → sink 引用归零
                              → Free（Close + join 排空，停机 drain） }
    FGroup: string;
    FPrefix: array of TAttr;
    FPrefixCount: Int32;
  public
    constructor Create(const ASink: ILogFileSink);
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TLogFileWorker.Create(const AChannel: TLogFileChannel;
  const AFileHandler: TFileHandler;
  const AAckMu: PPlatformMutex; const AAckCond: PPlatformCondVar;
  const AAckSeq: PInt64);
begin
  inherited Create;
  FChannel := AChannel;
  FIO := AFileHandler;
  FAckMu := AAckMu;
  FAckCond := AAckCond;
  FAckSeq := AAckSeq;
end;

procedure TLogFileWorker.Execute;
var
  LMsg: TLogFileMsg;
  LBatch: Int32;
begin
  LBatch := 0;
  try
    while FChannel.Receive(LMsg) do
    begin
      if LMsg.Kind = lfkFlush then
      begin
        FIO.Flush;   { flush 哨兵前的全部记录已写，落 OS }
        platform_mutex_lock(FAckMu^);
        try
          if LMsg.FlushSeq > FAckSeq^ then FAckSeq^ := LMsg.FlushSeq;
          platform_condvar_broadcast(FAckCond^);
        finally
          platform_mutex_unlock(FAckMu^);
        end;
        Continue;
      end;
      FIO.HandleRaw(LMsg);
      Inc(LBatch);
      if LBatch >= cLogFileBatchFlush then
      begin
        FIO.Flush;
        LBatch := 0;
      end;
    end;
  except
    on E: Exception do
    begin
      { 防御：worker 异常即停止（TWorkerThread 捕获保存）——调用方可经
        HasException 观察；队列剩余会转满 → Push 兜底同步直写（不丢）。 }
      WriteLn(StdErr, '[LOG] async file worker exception: ', E.Message);
      raise;
    end;
  end;
end;

constructor TLogFileSink.Create(const APath: string; AMinLevel: TLogLevel;
  AMaxBytes: Int64; AMaxFiles: Int32; AJson: Boolean; ACapacity: Int32);
begin
  inherited Create;
  FChannel := TLogFileChannel.Create(ACapacity);
  FIO := TFileHandler.Create(APath, AMinLevel, AMaxBytes, AMaxFiles, AJson);
  platform_mutex_init(FAckMu);
  platform_condvar_init(FAckCond);
  InitCriticalSection(FSeqMu);
  FWorker := TLogFileWorker.Create(FChannel, FIO, @FAckMu, @FAckCond, @FAckSeq);
  FWorker.Start;
end;

destructor TLogFileSink.Destroy;
begin
  { 停机 drain：Close 后 worker 消费残余（空且 Close 才退出）→ join }
  FChannel.Close;
  FWorker.WaitFor;
  FWorker.Free;
  FChannel.Free;
  FIO.Free;
  platform_mutex_destroy(FAckMu);
  platform_condvar_destroy(FAckCond);
  DoneCriticalSection(FSeqMu);
  inherited Destroy;
end;

function TLogFileSink.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := FIO.Enabled(ALevel);
end;

procedure TLogFileSink.Push(const AMsg: TLogFileMsg);
begin
  { 非阻塞入队（O(1) 锁内拷贝）；满/已关闭 → 同步直写兜底（不丢日志，
    仅退化为同步写 + 每行 Flush）。 }
  if not FChannel.TrySend(AMsg) then
    FIO.HandleMsg(AMsg);
end;

procedure TLogFileSink.Flush;
var
  LMsg: TLogFileMsg;
  LSeq: Int64;
begin
  { 已关闭（Destroy 后防御）：队列已排空、worker 已退出，直接落盘返回 }
  if FChannel.IsClosed then
  begin
    FIO.Flush;
    Exit;
  end;
  EnterCriticalSection(FSeqMu);
  try
    Inc(FFlushSeq);
    LSeq := FFlushSeq;
  finally
    LeaveCriticalSection(FSeqMu);
  end;
  LMsg.Kind := lfkFlush;
  LMsg.FlushSeq := LSeq;
  { 阻塞入队：停机/显式 flush 时队列即便满也须送达（排空语义） }
  FChannel.Send(LMsg);
  platform_mutex_lock(FAckMu);
  try
    while FAckSeq < LSeq do
      platform_condvar_wait(FAckCond, FAckMu);
  finally
    platform_mutex_unlock(FAckMu);
  end;
end;

constructor TAsyncFileHandler.Create(const ASink: ILogFileSink);
begin
  inherited Create;
  FSink := ASink;
  FPrefixCount := 0;
end;

function TAsyncFileHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := FSink.Enabled(ALevel);
end;

procedure TAsyncFileHandler.Handle(const ARecord: TLogRecord);
var
  LMsg: TLogFileMsg;
begin
  LMsg.Kind := lfkRecord;
  LMsg.Rec := ARecord;
  LMsg.Group := FGroup;
  LMsg.Prefix := FPrefix;
  LMsg.PrefixCount := FPrefixCount;
  FSink.Push(LMsg);
end;

procedure TAsyncFileHandler.Flush;
begin
  FSink.Flush;
end;

function TAsyncFileHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var
  LNew: TAsyncFileHandler;
  LI: Int32;
begin
  LNew := TAsyncFileHandler.Create(FSink);
  LNew.FGroup := FGroup;
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

function TAsyncFileHandler.WithGroup(const AName: string): ILogHandler;
var
  LNew: TAsyncFileHandler;
  LI: Int32;
begin
  LNew := TAsyncFileHandler.Create(FSink);
  SetLength(LNew.FPrefix, FPrefixCount);
  for LI := 0 to FPrefixCount - 1 do LNew.FPrefix[LI] := FPrefix[LI];
  LNew.FPrefixCount := FPrefixCount;
  if FGroup <> '' then
    LNew.FGroup := FGroup + '.' + AName
  else
    LNew.FGroup := AName;
  Result := LNew;
end;

function NewAsyncFileHandler(const APath: string; AMinLevel: TLogLevel;
  AMaxBytes: Int64; AMaxFiles: Int32; AQueueCapacity: Int32): ILogHandler;
var
  LSink: TLogFileSink;
begin
  LSink := TLogFileSink.Create(APath, AMinLevel, AMaxBytes, AMaxFiles,
    False, AQueueCapacity);
  { handler 持 sink 引用；最后一个 handler 释放 → sink Destroy（排空+join） }
  Result := TAsyncFileHandler.Create(LSink);
end;

function NewAsyncJsonFileHandler(const APath: string; AMinLevel: TLogLevel;
  AMaxBytes: Int64; AMaxFiles: Int32; AQueueCapacity: Int32): ILogHandler;
var
  LSink: TLogFileSink;
begin
  LSink := TLogFileSink.Create(APath, AMinLevel, AMaxBytes, AMaxFiles,
    True, AQueueCapacity);
  Result := TAsyncFileHandler.Create(LSink);
end;

{ TMultiHandler }

type
  TMultiHandler = class(TInterfacedObject, ILogHandler)
  private
    FHandlers: array of ILogHandler;
    FCount: Int32;
    FLock: TRTLCriticalSection;
  public
    constructor Create(const AHandlers: array of ILogHandler);
    destructor Destroy; override;
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
  end;

constructor TMultiHandler.Create(const AHandlers: array of ILogHandler);
var LI: Int32;
begin
  inherited Create;
  FCount := Length(AHandlers);
  SetLength(FHandlers, FCount);
  for LI := 0 to FCount - 1 do FHandlers[LI] := AHandlers[LI];
  InitCriticalSection(FLock);
end;

destructor TMultiHandler.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

function TMultiHandler.Enabled(const ALevel: TLogLevel): Boolean;
var LI: Int32;
begin
  for LI := 0 to FCount - 1 do
    if FHandlers[LI].Enabled(ALevel) then begin Result := True; Exit; end;
  Result := False;
end;

procedure TMultiHandler.Handle(const ARecord: TLogRecord);
var LI: Int32;
begin
  EnterCriticalSection(FLock);
  try
    for LI := 0 to FCount - 1 do
      if FHandlers[LI].Enabled(ARecord.Level) then
        FHandlers[LI].Handle(ARecord);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TMultiHandler.Flush;
var LI: Int32;
begin
  for LI := 0 to FCount - 1 do FHandlers[LI].Flush;
end;

function TMultiHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var LNew: array of ILogHandler; LI: Int32;
begin
  SetLength(LNew, FCount);
  for LI := 0 to FCount - 1 do LNew[LI] := FHandlers[LI].WithAttrs(AAttrs);
  Result := TMultiHandler.Create(LNew);
end;

function TMultiHandler.WithGroup(const AName: string): ILogHandler;
var LNew: array of ILogHandler; LI: Int32;
begin
  SetLength(LNew, FCount);
  for LI := 0 to FCount - 1 do LNew[LI] := FHandlers[LI].WithGroup(AName);
  Result := TMultiHandler.Create(LNew);
end;

function NewMultiHandler(const AHandlers: array of ILogHandler): ILogHandler;
begin
  Result := TMultiHandler.Create(AHandlers);
end;

{ TLoggerAdapter — bridges TLogger to ILogger interface }

type
  TLoggerAdapter = class(TInterfacedObject, ILogger)
  private
    FLogger: TLogger;
  public
    constructor Create(const ALogger: TLogger);
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Fatal(const AMessage: string);
  end;

constructor TLoggerAdapter.Create(const ALogger: TLogger);
begin
  inherited Create;
  FLogger := ALogger;
end;

procedure TLoggerAdapter.Log(const ALevel: TLogLevel; const AMessage: string);
begin
  case ALevel of
    llTrace: FLogger.Trace^.Msg(AMessage);
    llDebug: FLogger.Debug^.Msg(AMessage);
    llInfo: FLogger.Info^.Msg(AMessage);
    llWarn: FLogger.Warn^.Msg(AMessage);
    llError: FLogger.Error^.Msg(AMessage);
    llFatal: FLogger.Fatal^.Msg(AMessage);
  end;
end;

procedure TLoggerAdapter.Trace(const AMessage: string);
begin FLogger.Trace^.Msg(AMessage); end;

procedure TLoggerAdapter.Debug(const AMessage: string);
begin FLogger.Debug^.Msg(AMessage); end;

procedure TLoggerAdapter.Info(const AMessage: string);
begin FLogger.Info^.Msg(AMessage); end;

procedure TLoggerAdapter.Warn(const AMessage: string);
begin FLogger.Warn^.Msg(AMessage); end;

procedure TLoggerAdapter.Error(const AMessage: string);
begin FLogger.Error^.Msg(AMessage); end;

procedure TLoggerAdapter.Fatal(const AMessage: string);
begin FLogger.Fatal^.Msg(AMessage); end;

function TLogger.AsILogger: ILogger;
begin
  Result := TLoggerAdapter.Create(Self);
end;

initialization
  InitCriticalSection(GDefaultLock);
  InitCriticalSection(GEventLock);

finalization
  { 手动清理全局事件池槽的 managed 字段（静态对象 FPC 不自动 Finalize）。
    正常退出时所有槽均已 Msg 归还，此处幂等清理残留引用。 }
  for GFinI := 0 to High(GEventPool) do
    Finalize(GEventPool[GFinI]);
  DoneCriticalSection(GEventLock);
  DoneCriticalSection(GDefaultLock);
end.
