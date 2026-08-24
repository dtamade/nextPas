unit nextpas.core.db.redis.adapter;

{** @desc IDbConnection/IDbQuery 的 Redis 原生适配器（V3-A5）。

       定位：RESP2 协议原生客户端（无 C 库依赖），键值面映射到统
       一层。命令文本 = 空白分词的命令行（GET key / SET key val），
       ?/?N 占位符替换为独立 bulk 参数——RESP 长度前缀天然二进制
       安全，注入安全由协议构造保证（无转义路径）。

       执行模型：IDbQuery 惰性执行（首个 Step 发命令并解析完整回
       复；后续 Step 只遍历已解析行，无 IO）；Reset 重臂（下次
       Step 重发命令，对齐 odbc Reset 语义）。

       回复 → 行映射（诚实最小面）：array 回复每元素一行；
       simple/bulk/integer 标量一行；null 零行；error 回复在执行点
       抛 EDbError（db.err ClassifyRedis 归一）。单列列名 'reply'。

       事务控制面：MULTI/EXEC/DISCARD 直映。MULTI 期间命令被服务
       端排队，本层透明收到 +QUEUED（消费方读到的是排队标记而非
       结果——Redis 固有语义）；CommitTxn 校验 EXEC 数组内错误元素
       后丢弃载荷（排队命令的实际结果不经统一层暴露）；EXECABORT
       → decTransaction。AImmediate 无对应语义接受为 no-op。

       能力降级矩阵（诚实契约，CONTRACT §2.13 同文）：
         - Savepoints / StmtCacheControl / LargeObjects /
           NativeBool / MultiStatementExec / StatementTimeout：False。
         - BatchExecutor：True——真流水线（一次写 burst + N 读），
           sqlite 式精确到步的错误定位。
         - CaseSensitiveIdentifiers：True（键二进制敏感）。
         - MaxPlaceholders：999 保守下界。

       观测钩子：§2.12 四后端同构接线（attach-catch-up、首个执行窗
       口计时一次、错误类目透传）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.sync,
  nextpas.core.errors,
  nextpas.core.time,
  nextpas.core.net,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.err,
  nextpas.core.db.trace,
  nextpas.core.db.redis.base,
  nextpas.core.db.redis.resp,
  nextpas.core.db.redis.transport;

{ 连接 Redis 并完成握手（AUTH → SELECT）。AAddr 形如
  'host[:port][/db]'；APassword 空 = 不发 AUTH；ADbIndex 0 = 不发
  SELECT。失败抛 EDbError（Backend=dbkRedis）。 }
function ConnectRedis(const AAddr: string): IDbConnection; overload;
function ConnectRedis(const AAddr: string;
  const APassword: string; const ADbIndex: Integer;
  const AOptions: TDbConnectOptions): IDbConnection; overload;

{ 测试/DI 接缝：以注入传输建连（离线门禁用脚本化 transport）；
  握手语义与 ConnectRedis 一致。 }
function ConnectRedisWithTransport(const ATransport: IRedisTransport;
  const APassword: string = ''; const ADbIndex: Integer = 0)
  : IDbConnection;

implementation

const
  C_READ_CHUNK = 4096;

function BytesFromText(const AStr: string): TBytes;
begin
  if Length(AStr) = 0 then
    Exit(nil);
  SetLength(Result, Length(AStr));
  Move(AStr[1], Result[0], Length(AStr));
end;

function RedisCategory(const AErrType: string): TDbErrorCategory;
var
  LCon: TDbConstraintKind;
begin
  ClassifyRedis(AErrType, Result, LCon);
end;

{ ---- 地址解析 ---- }

procedure ParseRedisAddr(const AAddr: string;
  const AOptions: TDbConnectOptions; out AOpts: TDbRedisConnectOptions);
var
  LHostPart, LTail: string;
  LSlash, LColon: Integer;
  LCode: Integer;
begin
  AOpts := TDbRedisConnectOptions.Default;
  AOpts.Host := '';
  AOpts.Port := DB_REDIS_DEFAULT_PORT;
  LHostPart := AAddr;
  LSlash := Pos('/', LHostPart);
  if LSlash > 0 then
  begin
    LTail := Copy(LHostPart, LSlash + 1, MaxInt);
    LHostPart := Copy(LHostPart, 1, LSlash - 1);
    Val(LTail, AOpts.DbIndex, LCode);
    if (LCode <> 0) or (AOpts.DbIndex < 0) then
      raise EDbError.CreateSimple(dbkRedis,
        'invalid db index "/' + LTail + '"');
  end;
  if AOpts.DbIndex > 15 then
    raise EDbError.CreateSimple(dbkRedis,
      'db index out of range (0..15)');
  LColon := Pos(':', LHostPart);
  if LColon > 0 then
  begin
    LTail := Copy(LHostPart, LColon + 1, MaxInt);
    LHostPart := Copy(LHostPart, 1, LColon - 1);
    Val(LTail, LCode, LCode);
    Val(LTail, AOpts.Port, LCode);
    if (LCode <> 0) or (AOpts.Port = 0) then
      raise EDbError.CreateSimple(dbkRedis,
        'invalid port ":' + LTail + '"');
  end;
  AOpts.Host := Trim(LHostPart);
  if AOpts.Host = '' then
    raise EDbError.CreateSimple(dbkRedis, 'empty host');
  { 统一层连接选项映射（advisory）：StatementTimeoutMs 作为 IO
    deadline 上限；BusyTimeoutMs 无对应语义忽略（不冒充）。 }
  if AOptions.StatementTimeoutMs > 0 then
    AOpts.IoTimeoutMs := AOptions.StatementTimeoutMs;
end;

{ ---- 连接对象 ---- }

type
  TDbRedisConnection = class(TInterfacedObject, IDbConnection,
    IDbTxControl, IDbBatchExecutor, IDbCapabilities, IDbTraceControl)
  private
    FTransport: IRedisTransport;
    FLock: INativeMutex;
    FDepth: Integer;
    FBuf: TBytes;          { 接收缓冲（跨 Recv 追加）}
    FTrace: TDbTraceHub;
    procedure Handshake(const APassword: string; const ADbIndex: Integer);
    function LockedExecute(const AArgs: TRespArgs): TRespValue;
    function ReadReply: TRespValue;
  public
    constructor Create(const ATransport: IRedisTransport;
      const APassword: string; const ADbIndex: Integer);
    destructor Destroy; override;

    { IDbTraceControl }
    procedure SetListener(const AListener: IDbTraceListener);
    function HasListener: Boolean;

    function Kind: TDbKind;
    procedure Exec(const ASql: string); overload;
    procedure Exec(const ASql: string;
      const AOptions: TDbExecOptions); overload;
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string;
      const AOptions: TDbExecOptions): IDbQuery; overload;
    function Changes: Int64;
    function Raw: Pointer;

    { IDbTxControl —— MULTI/EXEC/DISCARD 直映 }
    procedure BeginTxn(const AImmediate: Boolean = False);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean;
    function TxDepth: Integer;

    { IDbBatchExecutor —— 真流水线 }
    procedure ExecuteBatch(const ASteps: TDbSqlSteps);

    { IDbCapabilities —— 降级矩阵见单元头注 }
    function ProductName: string;
    function ProductVersion: string;
    function SupportsSavepoints: Boolean;
    function SupportsBatchExecutor: Boolean;
    function SupportsStmtCacheControl: Boolean;
    function SupportsLargeObjects: Boolean;
    function SupportsNativeBool: Boolean;
    function SupportsMultiStatementExec: Boolean;
    function SupportsStatementTimeout: Boolean;
    function CaseSensitiveIdentifiers: Boolean;
    function MaxPlaceholders: Integer;
  end;

type
  TDbRedisQuery = class(TInterfacedObject, IDbQuery)
  private
    FConn: TDbRedisConnection;
    FSql: string;
    FBound: array of TBytes;   { 逻辑号 1..N }
    FTrace: TDbTraceHub;
    FEmitted: Boolean;
    FExecuted: Boolean;
    FReply: TRespValue;
    FRowCount: Integer;
    FRowIdx: Integer;
    FColType: TDbColumnType;
    procedure EnsurePlanBounds(ALogical: Integer);
    procedure ExecuteNow;
    function RowElement: TRespValue;
  public
    constructor Create(AConn: TDbRedisConnection; const ASql: string;
      ATrace: TDbTraceHub);
    destructor Destroy; override;

    procedure BindText(AIndex: Integer; const AValue: string);
    procedure BindInt64(AIndex: Integer; const AValue: Int64);
    procedure BindDouble(AIndex: Integer; const AValue: Double);
    procedure BindBlob(AIndex: Integer; const AValue: TBytes);
    procedure BindNull(AIndex: Integer);

    function Step: Boolean;
    procedure Reset;
    function ColumnCount: Integer;
    function ColumnName(AIndex: Integer): string;
    function ColumnType(AIndex: Integer): TDbColumnType;
    function IsNull(AIndex: Integer): Boolean;
    function GetInt64(AIndex: Integer): Int64;
    function GetDouble(AIndex: Integer): Double;
    function GetText(AIndex: Integer): string;
    function GetBlob(AIndex: Integer): TBytes;
  end;

{ ---- TDbRedisConnection ---- }

procedure BridgeNetError(E: Exception);
begin
  raise EDbError.CreateSimple(dbkRedis,
    'redis connect: ' + E.Message);
end;

function ConnectRedis(const AAddr: string): IDbConnection;
begin
  Result := ConnectRedis(AAddr, '', 0, TDbConnectOptions.Default);
end;

function ConnectRedis(const AAddr: string;
  const APassword: string; const ADbIndex: Integer;
  const AOptions: TDbConnectOptions): IDbConnection;
var
  LOpts: TDbRedisConnectOptions;
  LTransport: IRedisTransport;
begin
  if AAddr = '' then
    raise EDbError.CreateSimple(dbkRedis, 'empty address');
  ParseRedisAddr(AAddr, AOptions, LOpts);
  try
    LTransport := TNetRedisTransport.Create(LOpts);
  except
    on E: ENetworkError do
      BridgeNetError(E);
  end;
  Result := TDbRedisConnection.Create(LTransport, APassword, ADbIndex);
end;

function ConnectRedisWithTransport(const ATransport: IRedisTransport;
  const APassword: string; const ADbIndex: Integer): IDbConnection;
begin
  Result := TDbRedisConnection.Create(ATransport, APassword, ADbIndex);
end;

constructor TDbRedisConnection.Create(const ATransport: IRedisTransport;
  const APassword: string; const ADbIndex: Integer);
begin
  inherited Create;
  FTransport := ATransport;
  FLock := nextpas.core.sync.Mutex;
  FDepth := 0;
  FTrace := TDbTraceHub.Create;
  { OnAcquire 由 SetListener 挂载时补发（§2.12），ctor 不预发 }
  Handshake(APassword, ADbIndex);
end;

destructor TDbRedisConnection.Destroy;
begin
  FTrace.NotifyRelease;   { OnRelease = 连接关闭 }
  FreeAndNil(FTrace);
  if FTransport <> nil then
  begin
    FTransport.Close;
    FTransport := nil;
  end;
  inherited Destroy;
end;

procedure TDbRedisConnection.SetListener(
  const AListener: IDbTraceListener);
begin
  FTrace.SetListener(AListener);
end;

function TDbRedisConnection.HasListener: Boolean;
begin
  Result := FTrace.Active;
end;

procedure TDbRedisConnection.Handshake(const APassword: string;
  const ADbIndex: Integer);
begin
  { 错误回复由 LockedExecute 统一抛（AUTH 失败即建连失败）}
  if APassword <> '' then
    LockedExecute(TRespArgs.Create(
      BytesFromText('AUTH'), BytesFromText(APassword)));
  if ADbIndex <> 0 then
    LockedExecute(TRespArgs.Create(
      BytesFromText('SELECT'),
      BytesFromText(IntToStr(ADbIndex))));
end;

function TDbRedisConnection.ReadReply: TRespValue;
var
  LPos: Integer;
  LN: SizeUInt;
  LNeed: Boolean;
begin
  LPos := 0;
  repeat
    if RespTryParse(FBuf, LPos, Result, LNeed) then
    begin
      { 消费已解析前缀 }
      if LPos < Length(FBuf) then
        Move(FBuf[LPos], FBuf[0], Length(FBuf) - LPos);
      SetLength(FBuf, Length(FBuf) - LPos);
      Exit;
    end;
    if not LNeed then
      break;
    SetLength(FBuf, Length(FBuf) + C_READ_CHUNK);
    LN := FTransport.Recv(@FBuf[Length(FBuf) - C_READ_CHUNK],
      C_READ_CHUNK);
    if LN = 0 then
      raise EDbError.CreateSimple(dbkRedis,
        'redis: connection closed mid-reply');
    if LN < SizeUInt(C_READ_CHUNK) then
      SetLength(FBuf, Length(FBuf) - (C_READ_CHUNK - Integer(LN)));
  until False;
end;

function TDbRedisConnection.LockedExecute(
  const AArgs: TRespArgs): TRespValue;
var
  LFrame: TBytes;
begin
  RespEncodeCommand(AArgs, LFrame);
  FTransport.Send(LFrame);
  Result := ReadReply;
  if Result.Kind = rvkError then
    raise EDbError.CreateFullRedis(RespErrorType(Result.Data),
      RespBytesToStr(Result.Data),
      RedisCategory(RespErrorType(Result.Data)), dckNone);
end;

function TDbRedisConnection.Kind: TDbKind;
begin
  Result := dbkRedis;
end;

procedure TDbRedisConnection.Exec(const ASql: string);
var
  LArgs: TRespArgs;
  LT0: QWord;
  LTimed: Boolean;
begin
  RespPlanCommand(ASql, [], LArgs);
  LT0 := 0;
  LTimed := FTrace.BeginOp(LT0);
  try
    LockedExecute(LArgs);
    if LTimed then
      FTrace.NotifyQuery(LT0, ASql);
  except
    on E: EDbError do
    begin
      if LTimed then
        FTrace.NotifyError(E.Category, ASql);
      raise;
    end;
  end;
end;

procedure TDbRedisConnection.Exec(const ASql: string;
  const AOptions: TDbExecOptions);
begin
  { TimeoutMs advisory：v1 无语句级机制，忽略不报错（§2.13 登记）。
    观测窗口单点在内层 Exec。 }
  Exec(ASql);
end;

function TDbRedisConnection.Query(const ASql: string): IDbQuery;
begin
  Result := TDbRedisQuery.Create(Self, ASql, FTrace);
end;

function TDbRedisConnection.Query(const ASql: string;
  const AOptions: TDbExecOptions): IDbQuery;
begin
  Result := Query(ASql);
end;

function TDbRedisConnection.Changes: Int64;
begin
  Result := 0;   { 键值模型无受影响行数概念（诚实欠奉）}
end;

function TDbRedisConnection.Raw: Pointer;
begin
  Result := nil;   { 无原生句柄可暴露 }
end;

procedure TDbRedisConnection.BeginTxn(const AImmediate: Boolean);
var
  LArgs: TRespArgs;
  LT0: QWord;
  LTimed: Boolean;
begin
  RespPlanCommand('MULTI', [], LArgs);
  LT0 := 0;
  LTimed := FTrace.BeginOp(LT0);
  try
    LockedExecute(LArgs);
    Inc(FDepth);
    if LTimed then
      FTrace.NotifyQuery(LT0, 'MULTI');
  except
    on E: EDbError do
    begin
      if LTimed then
        FTrace.NotifyError(E.Category, 'MULTI');
      raise;
    end;
  end;
end;

procedure TDbRedisConnection.CommitTxn;
var
  LArgs: TRespArgs;
  LR: TRespValue;
  I: Integer;
  LT0: QWord;
  LTimed: Boolean;
begin
  RespPlanCommand('EXEC', [], LArgs);
  LT0 := 0;
  LTimed := FTrace.BeginOp(LT0);
  try
    LR := LockedExecute(LArgs);
    Dec(FDepth);
    if FDepth < 0 then
      FDepth := 0;
    { 排队命令的逐条错误在 EXEC 数组中暴露（post-fact）：
      发现即抛第一条（连接事务态已结束，无需恢复动作）。 }
    if LR.Kind = rvkArray then
      for I := 0 to High(LR.Items) do
        if LR.Items[I].Kind = rvkError then
          raise EDbError.CreateFullRedis(
            RespErrorType(LR.Items[I].Data),
            RespBytesToStr(LR.Items[I].Data),
            RedisCategory(RespErrorType(LR.Items[I].Data)),
            dckNone);
    if LTimed then
      FTrace.NotifyQuery(LT0, 'EXEC');
  except
    on E: EDbError do
    begin
      if LTimed then
        FTrace.NotifyError(E.Category, 'EXEC');
      raise;
    end;
  end;
end;

procedure TDbRedisConnection.RollbackTxn;
var
  LArgs: TRespArgs;
begin
  RespPlanCommand('DISCARD', [], LArgs);
  LockedExecute(LArgs);
  Dec(FDepth);
  if FDepth < 0 then
    FDepth := 0;
end;

function TDbRedisConnection.InTransaction: Boolean;
begin
  Result := FDepth > 0;
end;

function TDbRedisConnection.TxDepth: Integer;
begin
  Result := FDepth;
end;

procedure TDbRedisConnection.ExecuteBatch(const ASteps: TDbSqlSteps);
var
  I: Integer;
  LArgs: TRespArgs;
  LFrames: TBytes;
  LStepFrames: array of TBytes;
  LR: TRespValue;
  LT0: QWord;
  LTimed: Boolean;
begin
  if Length(ASteps) = 0 then
    raise EDbError.CreateSimple(dbkRedis, 'empty batch');
  SetLength(LStepFrames, Length(ASteps));
  for I := 0 to High(ASteps) do
  begin
    RespPlanCommand(ASteps[I], [], LArgs);
    RespEncodeCommand(LArgs, LFrames);
    LStepFrames[I] := LFrames;
  end;
  { 单次写 burst = 流水线关键路径 }
  SetLength(LFrames, 0);
  for I := 0 to High(LStepFrames) do
  begin
    SetLength(LFrames, Length(LFrames) + Length(LStepFrames[I]));
    if Length(LStepFrames[I]) > 0 then
      Move(LStepFrames[I][0], LFrames[Length(LFrames) -
        Length(LStepFrames[I])], Length(LStepFrames[I]));
  end;
  LT0 := 0;
  LTimed := FTrace.BeginOp(LT0);
  try
    FTransport.Send(LFrames);
    for I := 0 to High(ASteps) do
    begin
      LR := ReadReply;
      if LR.Kind = rvkError then
        raise EDbError.CreateFullRedis(
          RespErrorType(LR.Data),
          'batch step ' + IntToStr(I + 1) + ': ' +
          RespBytesToStr(LR.Data),
          RedisCategory(RespErrorType(LR.Data)), dckNone);
    end;
    if LTimed then
      FTrace.NotifyQuery(LT0, 'BATCH x' + IntToStr(Length(ASteps)));
  except
    on E: EDbError do
    begin
      if LTimed then
        FTrace.NotifyError(E.Category, 'BATCH');
      raise;
    end;
  end;
end;

function TDbRedisConnection.ProductName: string;
begin
  Result := 'Redis';
end;

function TDbRedisConnection.ProductVersion: string;
begin
  Result := '';   { v1 不做 INFO 探测（诚实空值）}
end;

function TDbRedisConnection.SupportsSavepoints: Boolean;
begin
  Result := False;
end;

function TDbRedisConnection.SupportsBatchExecutor: Boolean;
begin
  Result := True;
end;

function TDbRedisConnection.SupportsStmtCacheControl: Boolean;
begin
  Result := False;
end;

function TDbRedisConnection.SupportsLargeObjects: Boolean;
begin
  Result := False;
end;

function TDbRedisConnection.SupportsNativeBool: Boolean;
begin
  Result := False;
end;

function TDbRedisConnection.SupportsMultiStatementExec: Boolean;
begin
  Result := False;
end;

function TDbRedisConnection.SupportsStatementTimeout: Boolean;
begin
  Result := False;   { v1：TimeoutMs 忽略，如实登记 }
end;

function TDbRedisConnection.CaseSensitiveIdentifiers: Boolean;
begin
  Result := True;   { 键二进制敏感 }
end;

function TDbRedisConnection.MaxPlaceholders: Integer;
begin
  Result := 999;   { 保守下界，与家族一致 }
end;

{ ---- TDbRedisQuery ---- }

constructor TDbRedisQuery.Create(AConn: TDbRedisConnection;
  const ASql: string; ATrace: TDbTraceHub);
begin
  inherited Create;
  FConn := AConn;
  FSql := ASql;
  FTrace := ATrace;
  FColType := dbcText;
end;

destructor TDbRedisQuery.Destroy;
begin
  FConn := nil;
  inherited Destroy;
end;

procedure TDbRedisQuery.EnsurePlanBounds(ALogical: Integer);
begin
  if ALogical > Length(FBound) then
    SetLength(FBound, ALogical);
end;

procedure TDbRedisQuery.BindText(AIndex: Integer; const AValue: string);
begin
  EnsurePlanBounds(AIndex);
  FBound[AIndex - 1] := BytesFromText(AValue);
end;

procedure TDbRedisQuery.BindInt64(AIndex: Integer; const AValue: Int64);
begin
  BindText(AIndex, IntToStr(AValue));
end;

procedure TDbRedisQuery.BindDouble(AIndex: Integer; const AValue: Double);
begin
  BindText(AIndex, FloatToStr(AValue));
end;

procedure TDbRedisQuery.BindBlob(AIndex: Integer; const AValue: TBytes);
begin
  EnsurePlanBounds(AIndex);
  FBound[AIndex - 1] := AValue;
end;

procedure TDbRedisQuery.BindNull(AIndex: Integer);
begin
  { RESP 参数无 NULL 语义——空 bulk 即诚实表达 }
  EnsurePlanBounds(AIndex);
  FBound[AIndex - 1] := nil;
end;

procedure TDbRedisQuery.ExecuteNow;
var
  LArgs: TRespArgs;
  LT0: QWord;
  LTimed: Boolean;
begin
  RespPlanCommand(FSql, FBound, LArgs);
  LT0 := 0;
  LTimed := (FTrace <> nil) and (not FEmitted) and FTrace.BeginOp(LT0);
  try
    FReply := FConn.LockedExecute(LArgs);
    FExecuted := True;
    if LTimed then
    begin
      FEmitted := True;
      FTrace.NotifyQuery(LT0, FSql);
    end;
  except
    on E: EDbError do
    begin
      if LTimed then
        FTrace.NotifyError(E.Category, FSql);
      raise;
    end;
  end;
  { 行映射 }
  FRowCount := 0;
  FRowIdx := 0;
  case FReply.Kind of
    rvkArray:
      FRowCount := Length(FReply.Items);
    rvkSimple, rvkBulk, rvkInteger:
      FRowCount := 1;
    rvkError, rvkNull:
      ;   { error 在执行点已抛；null 零行 }
  end;
  if FReply.Kind = rvkInteger then
    FColType := dbcInteger
  else
    FColType := dbcText;
end;

function TDbRedisQuery.Step: Boolean;
begin
  if not FExecuted then
    ExecuteNow;
  if FRowIdx >= FRowCount then
    Exit(False);
  Inc(FRowIdx);
  Result := True;
end;

procedure TDbRedisQuery.Reset;
begin
  FExecuted := False;   { 下次 Step 重发命令（对齐 odbc Reset 语义）}
end;

function TDbRedisQuery.ColumnCount: Integer;
begin
  Result := 1;
end;

function TDbRedisQuery.ColumnName(AIndex: Integer): string;
begin
  Result := 'reply';
end;

function TDbRedisQuery.ColumnType(AIndex: Integer): TDbColumnType;
begin
  Result := FColType;
end;

function TDbRedisQuery.RowElement: TRespValue;
begin
  if FReply.Kind = rvkArray then
    Result := FReply.Items[FRowIdx - 1]
  else
    Result := FReply;
end;

function TDbRedisQuery.IsNull(AIndex: Integer): Boolean;
var
  LE: TRespValue;
begin
  LE := RowElement;
  Result := LE.Kind = rvkNull;
end;

function TDbRedisQuery.GetInt64(AIndex: Integer): Int64;
var
  LE: TRespValue;
begin
  LE := RowElement;
  if LE.Kind = rvkInteger then
    Result := LE.Int
  else
    Result := StrToInt64Def(RespValueToText(LE), 0);
end;

function TDbRedisQuery.GetDouble(AIndex: Integer): Double;
begin
  Result := StrToFloatDef(RespValueToText(RowElement), 0);
end;

function TDbRedisQuery.GetText(AIndex: Integer): string;
begin
  Result := RespValueToText(RowElement);
end;

function TDbRedisQuery.GetBlob(AIndex: Integer): TBytes;
var
  LE: TRespValue;
begin
  LE := RowElement;
  if LE.Kind in [rvkBulk, rvkSimple, rvkError] then
    Result := LE.Data
  else
    Result := BytesFromText(RespValueToText(LE));
end;

end.
