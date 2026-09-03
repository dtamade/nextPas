unit nextpas.core.db.redis.adapter;

{** @desc IDbConnection 的 Redis 原生适配器（RESP2 流水线/MULTI 直映，惰性 Query/Reset，单列 'reply'）。 *}
{** 能力降级与观测同构见 CONTRACT §2.12/§2.13；命令分词/回复映射/事务语义详实现（单源以 CONTRACT 为准）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.text.utils,
  nextpas.core.text.conv,
  nextpas.core.bytes.ops,
  nextpas.core.time,
  nextpas.core.net,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.err,
  nextpas.core.db.trace,
  nextpas.core.db.redis.base,
  nextpas.core.db.redis.resp,
  nextpas.core.db.redis.transport;

const
  REDIS_ADAPTER_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;

{$I nextpas.core.bytes.ops.single_source.inc}

{ 连接 Redis 并完成握手（AUTH → SELECT → INFO 探测）。AAddr 形如
  'host[:port][/db]'；APassword 空 = 不发 AUTH；ADbIndex 0 = 不发
  SELECT；INFO server 版本探测 best-effort（对齐 odbc 能力探测惯例：
  失败保守降级不破坏建连）。失败抛 EDbError（Backend=dbkRedis）。 }
function ConnectRedis(const AAddr: string): IDbConnection; overload;
function ConnectRedis(const AAddr: string;
  const APassword: string; const ADbIndex: Integer;
  const AOptions: TDbConnectOptions): IDbConnection; overload;

{ 选项重载：AOptions 携带 UseTls/TlsServerName/Password 等扩展面；
  地址串仍解析 host[:port][/db]，非空字段覆盖。 }
function ConnectRedis(const AAddr: string;
  const AOptions: TDbRedisConnectOptions): IDbConnection; overload;

{ 测试/DI 接缝：以注入传输建连（离线门禁用脚本化 transport）；
  握手语义与 ConnectRedis 一致；AProbeInfo=true 时执行 INFO 探测。 }
function ConnectRedisWithTransport(const ATransport: IRedisTransport;
  const APassword: string = ''; const ADbIndex: Integer = 0;
  const AProbeInfo: Boolean = False): IDbConnection;



implementation

uses
  nextpas.core.db.redis.addr,
  nextpas.core.db.redis.pipeline,
  nextpas.core.db.redis.recv,
  nextpas.core.text.conv,
  nextpas.core.text.number;

{ 单源分治：地址/流水线/接收缓冲已抽 addr/pipeline/recv（CONTRACT §2.13）；DB_REDIS_READ_* 单源，bytes.ops 单源零拷贝。 }

{ ---- 连接对象 ---- }

type
  TDbRedisConnection = class(TInterfacedObject, IDbConnection,
    IDbTxControl, IDbBatchExecutor, IDbCapabilities, IDbTraceControl)
  private
    FTransport: IRedisTransport;
    FRing: TRedisRecvBuffer;
    FDepth: Integer;
    FTrace: TDbTraceHub;
    FProductVersion: string;   { INFO server 探测（best-effort，可空）}
    procedure Handshake(const APassword: string; const ADbIndex: Integer);
    procedure ProbeInfo;
    function LockedExecute(const AArgs: TRespArgs): TRespValue;
    function ReadReply: TRespValue; inline;
  public
    constructor Create(const ATransport: IRedisTransport;
      const APassword: string; const ADbIndex: Integer;
      const AProbeInfo: Boolean);
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
    function SupportsArrayBinding: Boolean;
    function SupportsNativeBool: Boolean;
    function SupportsMultiStatementExec: Boolean;
    function SupportsStatementTimeout: Boolean;
    function CaseSensitiveIdentifiers: Boolean;
    function MaxPlaceholders: Integer;
    function ServerVersion: Integer;
    function SupportsNativeVector: Boolean;
    function SupportsJsonPath: Boolean;
    function SupportsRangeTypes: Boolean;
    function SupportsBulkCopy: Boolean;
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
  { 传输层拨号失败（TCP/TLS）语义上是连接类错误；ErrType 槽放
    'NET' 标记非服务端回复、源自本地传输栈 }
  raise NewDbErrorRedis('NET',
    'redis connect: ' + E.Message, decConnection, dckNone);
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
  LOpts.ProbeInfo := True;   { 真实建连默认探测版本 }
  try
    LTransport := NewNetRedisTransport(LOpts);
  except
    { net/tls 异常族统一桥接（ENetworkError/TlsException 均为
      ENextPasError 后代，保留原文仅换类型）}
    on E: Exception do
      BridgeNetError(E);
  end;
  Result := TDbRedisConnection.Create(LTransport, APassword, ADbIndex,
    LOpts.ProbeInfo);
end;

function ConnectRedis(const AAddr: string;
  const AOptions: TDbRedisConnectOptions): IDbConnection;
var
  LConnOpts: TDbConnectOptions;
  LOpts: TDbRedisConnectOptions;
begin
  if AAddr = '' then
    raise EDbError.CreateSimple(dbkRedis, 'empty address');
  LConnOpts := TDbConnectOptions.Default;
  ParseRedisAddr(AAddr, LConnOpts, LOpts);
  if AOptions.Password <> '' then
    LOpts.Password := AOptions.Password;
  LOpts.UseTls := AOptions.UseTls;
  if AOptions.TlsServerName <> '' then
    LOpts.TlsServerName := AOptions.TlsServerName;
  LOpts.ProbeInfo := True;
  try
    Result := TDbRedisConnection.Create(NewNetRedisTransport(LOpts),
      LOpts.Password, LOpts.DbIndex, True);
  except
    on E: Exception do
      BridgeNetError(E);
  end;
end;

function ConnectRedisWithTransport(const ATransport: IRedisTransport;
  const APassword: string; const ADbIndex: Integer;
  const AProbeInfo: Boolean): IDbConnection;
begin
  Result := TDbRedisConnection.Create(ATransport, APassword, ADbIndex,
    AProbeInfo);
end;

constructor TDbRedisConnection.Create(const ATransport: IRedisTransport;
  const APassword: string; const ADbIndex: Integer;
  const AProbeInfo: Boolean);
begin
  inherited Create;
  FTransport := ATransport;
  FRing := TRedisRecvBuffer.Create(FTransport);
  FDepth := 0;
  FTrace := TDbTraceHub.Create;
  { OnAcquire 由 SetListener 挂载时补发（§2.12），ctor 不预发 }
  Handshake(APassword, ADbIndex);
  if AProbeInfo then
    ProbeInfo;
end;

destructor TDbRedisConnection.Destroy;
begin
  FTrace.NotifyRelease;   { OnRelease = 连接关闭 }
  FreeAndNil(FTrace);
  FreeAndNil(FRing);
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
var
  LHasAuth, LHasSelect: Boolean;
  LArgsAuth, LArgsSelect: TRespArgs;
  LLenAuth, LLenSelect, LTotal: SizeUInt;
  LBuf: TBytes;
  LR: TRespValue;
begin
  // perf: handshake batch 复用 pipeline 批量零拷贝路径 (CONTRACT §2.13)
  // dual AUTH+SELECT 单次burst Send + 逐条 ReadReply，消除2×RTT与2次syscall/分配；
  // 复用 bytes.ops 单源 (BYTES_OPS_SINGLE_SOURCE, BytesFromText->StringToBytes 单Move, RespEncodeCommandLength inline阈值 + RespEncodeCommandInto 单遍Move直写), redis.resp 单源编解码, db.redis.pipeline 单源分块思想零二次拷贝
  // bytes.ops single source + redis.pipeline zero-copy slice Send(@Buf,Len) 无每帧临时 LFrame
  // stability: try..finally 资源释放不丢 (LBuf/SetLength + Args清零), error Kind=rvkError 按 LockedExecute 同映射 (RedisCategory/RespErrorType->decAuth/decSyntax) 顺序读保证SELECT错误不掩盖AUTH错误
  LHasAuth := APassword <> '';
  LHasSelect := ADbIndex <> 0;
  if not LHasAuth and not LHasSelect then
    Exit;
  if LHasAuth xor LHasSelect then
  begin
    if LHasAuth then
      LockedExecute(TRespArgs.Create(
        BytesFromText('AUTH'), BytesFromText(APassword)))
    else
      LockedExecute(TRespArgs.Create(
        BytesFromText('SELECT'),
        BytesFromText(nextpas.core.text.conv.IntToStr(Int64(ADbIndex)))));
    Exit;
  end;
  // dual pipeline path — pipeline 批量零拷贝 (resp Length+Into 直写单缓冲, 单次 Send slice)
  LArgsAuth := TRespArgs.Create(BytesFromText('AUTH'), BytesFromText(APassword));
  LArgsSelect := TRespArgs.Create(
    BytesFromText('SELECT'),
    BytesFromText(nextpas.core.text.conv.IntToStr(Int64(ADbIndex))));
  LLenAuth := RespEncodeCommandLength(LArgsAuth);
  LLenSelect := RespEncodeCommandLength(LArgsSelect);
  LTotal := LLenAuth + LLenSelect;
  SetLength(LBuf, LTotal);
  try
    if LLenAuth > 0 then
      RespEncodeCommandInto(LArgsAuth, PByte(@LBuf[0]));
    if LLenSelect > 0 then
      RespEncodeCommandInto(LArgsSelect, PByte(@LBuf[LLenAuth]));
    FTransport.Send(PByte(@LBuf[0]), LTotal);
    LR := ReadReply;
    if LR.Kind = rvkError then
      raise NewDbErrorRedis(RespErrorType(LR.Data),
        RespBytesToStr(LR.Data),
        RedisCategory(RespErrorType(LR.Data)), dckNone);
    LR := ReadReply;
    if LR.Kind = rvkError then
      raise NewDbErrorRedis(RespErrorType(LR.Data),
        RespBytesToStr(LR.Data),
        RedisCategory(RespErrorType(LR.Data)), dckNone);
  finally
    SetLength(LBuf, 0);
    SetLength(LArgsAuth, 0);
    SetLength(LArgsSelect, 0);
  end;
end;

procedure TDbRedisConnection.ProbeInfo;
var
  LR: TRespValue;
  LV: string;
begin
  { best-effort（odbc ProbeCapabilities 同惯例）：探测失败保守降级，
    不让诊断性查询破坏建连 }
  try
    LR := LockedExecute(TRespArgs.Create(
      BytesFromText('INFO'), BytesFromText('server')));
    if LR.Kind in [rvkBulk, rvkSimple] then
    begin
      LV := RespInfoFieldValue(LR.Data, 'redis_version');
      if LV = '' then
        LV := RespInfoFieldValue(LR.Data, 'valkey_version');
      FProductVersion := LV;
    end;
  except
    on E: EDbError do
      FProductVersion := '';
  end;
end;

function TDbRedisConnection.ReadReply: TRespValue; inline;
begin
  // delegate to recv ring buffer single source (bytes.ops zero-copy, amortized Move)
  Result := FRing.ReadReply;
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
    raise NewDbErrorRedis(RespErrorType(Result.Data),
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
          raise NewDbErrorRedis(
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
begin
  // 体积分治：流水线见 pipeline 单源 bytes.ops/text.conv 零拷贝（CONTRACT §2.13）
  RedisExecuteBatch(FTransport, ASteps, FTrace, Self.ReadReply);
end;

function TDbRedisConnection.ProductName: string;
begin
  Result := 'Redis';
end;

function TDbRedisConnection.ProductVersion: string;
begin
  Result := FProductVersion;   { INFO server 探测；失败保守空值 }
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

function TDbRedisConnection.SupportsArrayBinding: Boolean;
begin
  Result := False;   { v1 未实现参数级批量绑定（诚实契约） }
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

function TDbRedisConnection.ServerVersion: Integer;
begin
  Result := 0;
end;

function TDbRedisConnection.SupportsNativeVector: Boolean;
begin
  Result := False;
end;

function TDbRedisConnection.SupportsJsonPath: Boolean;
begin
  Result := False;
end;

function TDbRedisConnection.SupportsRangeTypes: Boolean;
begin
  Result := False;
end;

function TDbRedisConnection.SupportsBulkCopy: Boolean;
begin
  Result := False;
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
var
  LBuf: array[0..31] of AnsiChar;
  LLen: Int32;
begin
  // not inline per red line 1+2: stack buffer + SetLength+Move single alloc must not be inline (I-Cache copy bloat); single Move zero-copy via bytes.ops single source shape (BYTES_OPS_SINGLE_SOURCE), no intermediate string
  LLen := nextpas.core.text.number.IntToBuffer(AValue, @LBuf[0]);
  EnsurePlanBounds(AIndex);
  SetLength(FBound[AIndex - 1], LLen);
  if LLen > 0 then
    Move(LBuf[0], FBound[AIndex - 1][0], LLen);
end;

procedure TDbRedisQuery.BindDouble(AIndex: Integer; const AValue: Double);
var
  LBuf: array[0..31] of AnsiChar;
  LLen: Int32;
begin
  // not inline per red line 1+2: FloatToBuffer stack buffer + single alloc Move must not be inline; single Move zero-copy via bytes.ops single source shape (BYTES_OPS_SINGLE_SOURCE), no intermediate string/SetString
  LLen := nextpas.core.text.number.FloatToBuffer(AValue, @LBuf[0]);
  EnsurePlanBounds(AIndex);
  SetLength(FBound[AIndex - 1], LLen);
  if LLen > 0 then
    Move(LBuf[0], FBound[AIndex - 1][0], LLen);
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
