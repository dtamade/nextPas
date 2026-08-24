program test_db_redis_adapter;

{ V3-A5 Redis 统一层适配器契约测试（脚本化传输，纯离线）：
    1 建连握手顺序：AUTH → SELECT 帧序钉死；错误回复即建连失败
    2 Exec 占位符命令：bulk 参数二进制安全；+OK 回复消费；
      trace OnQuery 单窗口单发
    3 Query 行映射：标量 bulk 一行 / :integer 列型 / 数组逐元素行 /
      null 零行 / 错误回复执行点抛（类目透传 + OnError）
    4 Reset 重臂：重发命令（发送次数递增）
    5 MULTI/EXEC/DISCARD：排队标记透明 / EXEC 数组内错误元素
      post-fact 抛 / 回滚深度归零
    6 批流水线：单次写 burst + N 读；精确到步错误定位
    7 能力矩阵自洽（B1 互证）与 TDbKind
    8 trace acquire/release 1:1 配对（控制接口强引用先清）
   live 段需真实 Redis（NEXTPAS_REDIS_TEST_CONN=host[:port][/db]），
   缺省静默跳过：PING/SET/GET/DEL 往返。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.err,
  nextpas.core.db.trace,
  nextpas.core.db,
  nextpas.core.db.redis.base,
  nextpas.core.db.redis.resp,
  nextpas.core.db.redis.transport,
  nextpas.core.db.redis.adapter;

var
  T: TTestSuite;

{ 本地记录式监听器（对齐 test_db_trace 范式；计数 + 事件留存）}
type
  TRecordingListener = class(TInterfacedObject, IDbTraceListener)
  private
    FAcquires, FReleases: Integer;
    FQueries, FErrors: Integer;
    FLastQuery, FLastError: string;
  public
    procedure OnAcquire;
    procedure OnRelease;
    procedure OnQuery(const ADurationMs: Int64; const ASqlSummary: string);
    procedure OnError(const ACategory: TDbErrorCategory;
      const ASqlSummary: string);
    property Acquires: Integer read FAcquires;
    property Releases: Integer read FReleases;
    property QueryCount: Integer read FQueries;
    property ErrorCount: Integer read FErrors;
    property LastQuery: string read FLastQuery;
    property LastError: string read FLastError;
  end;

procedure TRecordingListener.OnAcquire;
begin
  Inc(FAcquires);
end;

procedure TRecordingListener.OnRelease;
begin
  Inc(FReleases);
end;

procedure TRecordingListener.OnQuery(const ADurationMs: Int64;
  const ASqlSummary: string);
begin
  Inc(FQueries);
  FLastQuery := ASqlSummary;
end;

procedure TRecordingListener.OnError(const ACategory: TDbErrorCategory;
  const ASqlSummary: string);
begin
  Inc(FErrors);
  FLastError := ASqlSummary;
end;

function SToB(const AStr: string): TBytes;
begin
  SetLength(Result, Length(AStr));
  if AStr <> '' then
    Move(AStr[1], Result[0], Length(AStr));
end;

{ ===== 脚本化传输 ===== }

type
  TScriptedTransport = class(TInterfacedObject, IRedisTransport)
  private
    FReplies: array of TBytes;   { 每次完整回复一帧 }
    FReplyIdx: Integer;
  public
    FSends: array of string;     { 记录每次 Send 的可打印帧 }
    constructor Create;
    procedure Script(const AReply: string);
    destructor Destroy; override;
    procedure Send(const ABuf: TBytes);
    function Recv(ABuf: Pointer; AMax: Integer): Integer;
    procedure Close;
    function SendCount: Integer;
  end;

constructor TScriptedTransport.Create;
begin
  inherited Create;
end;

destructor TScriptedTransport.Destroy;
begin
  inherited Destroy;
end;

procedure TScriptedTransport.Script(const AReply: string);
begin
  SetLength(FReplies, Length(FReplies) + 1);
  FReplies[High(FReplies)] := SToB(AReply);
end;

procedure TScriptedTransport.Send(const ABuf: TBytes);
var
  LS: string;
begin
  if Length(ABuf) > 0 then
    SetString(LS, PAnsiChar(@ABuf[0]), Length(ABuf))
  else
    LS := '';
  SetLength(FSends, Length(FSends) + 1);
  FSends[High(FSends)] := LS;
end;

function TScriptedTransport.Recv(ABuf: Pointer; AMax: Integer): Integer;
var
  L: Integer;
begin
  if FReplyIdx > High(FReplies) then
    Exit(0);   { 脚本耗尽 = 模拟挂起前断连，测试应已结束 }
  L := Length(FReplies[FReplyIdx]);
  if L > AMax then
    L := AMax;
  if L > 0 then
    Move(FReplies[FReplyIdx][0], ABuf^, L);
  Inc(FReplyIdx);
  Result := L;
end;

procedure TScriptedTransport.Close;
begin
end;

function TScriptedTransport.SendCount: Integer;
begin
  Result := Length(FSends);
end;

{ ===== 辅助 ===== }

function MakeConn(AScripted: TScriptedTransport): IDbConnection;
begin
  Result := ConnectRedisWithTransport(AScripted);
end;

function LastSend(ATrans: TScriptedTransport): string;
begin
  Result := ATrans.FSends[ATrans.SendCount - 1];
end;

{ ===== 1 ===== }

procedure TestHandshakeOrder;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
begin
  { 无密码无 db：零握手帧 }
  LTrans := TScriptedTransport.Create;
    LTrans.Script('+OK'#13#10);   { 供后续可能的消费 }
    LConn := MakeConn(LTrans);
    CheckEqual(Int64(LTrans.SendCount), 0, 'no handshake frames');
    Check(LConn.Kind = dbkRedis, 'kind redis');
    LConn := nil;

end;

procedure TestHandshakeAuthSelect;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
begin
  { AUTH → SELECT 帧序 }
  LTrans := TScriptedTransport.Create;
    LTrans.Script('+OK'#13#10);   { AUTH }
    LTrans.Script('+OK'#13#10);   { SELECT }
    LConn := ConnectRedisWithTransport(LTrans, 'secret', 2);
    CheckEqual(Int64(LTrans.SendCount), 2, 'two handshake frames');
    Check(Pos('$4'#13#10'AUTH'#13#10'$6'#13#10'secret'#13#10,
      LTrans.FSends[0]) > 0, 'AUTH frame');
    Check(Pos('$6'#13#10'SELECT'#13#10'$1'#13#10'2'#13#10,
      LTrans.FSends[1]) > 0, 'SELECT frame');
    LConn := nil;

end;

procedure TestHandshakeErrorFails;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
  LRaised: Boolean;
begin
  LRaised := False;
  LTrans := TScriptedTransport.Create;
    LTrans.Script('-WRONGPASS invalid username-password'#13#10);
    try
      LConn := ConnectRedisWithTransport(LTrans, 'bad', 0);
    except
      on E: EDbError do
      begin
        LRaised := True;
        Check(E.Backend = dbkRedis, 'handshake err backend');
        Check(E.SqlState = 'WRONGPASS', 'handshake err type');
        Check(E.Category = decAuth, 'handshake err category');
      end;
    end;
    Check(LRaised, 'wrongpass raises');
    LConn := nil;

end;

{ ===== 2 ===== }

procedure TestExecPlaceholdersAndTrace;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
  LQ: IDbQuery;
  LTC: IDbTraceControl;
  LRec: TRecordingListener;
begin
  LTrans := TScriptedTransport.Create;
    LRec := TRecordingListener.Create;
    LConn := MakeConn(LTrans);
    LTrans.Script('+OK'#13#10);
    LConn.Exec('SET np:key np:value');
    Check(Pos('$6'#13#10'np:key'#13#10, LastSend(LTrans)) > 0,
      'exec sends command words');

    { 占位符：值独立成 bulk 参数（二进制安全）}
    LQ := LConn.Query('SET ? ?');
    LQ.BindText(1, 'k'#13#10'q');   { 载荷含 CRLF }
    LQ.BindText(2, 'v"1');
    LTrans.Script('+OK'#13#10);
    Check(LQ.Step, 'exec-style query yields row for +OK');
    Check(Pos('$4'#13#10'k'#13#10'q'#13#10, LastSend(LTrans)) > 0,
      'placeholder arg binary-safe frame');
    LQ := nil;

    { trace：挂监听补发 Acquire；一次 Exec 一个 OnQuery }
    Supports(LConn, IDbTraceControl, LTC);
    LTC.SetListener(LRec);
    Check(LRec.Acquires = 1, 'attach fires catch-up acquire');
    LTrans.Script('+OK'#13#10);
    LConn.Exec('PING');
    Check(LRec.QueryCount = 1, 'trace one query event');

    LTrans.Script('-ERR unknown command ''NOPE'''#13#10);
    try
      LConn.Exec('NOPE');
      Check(False, 'exec error should raise');
    except
      on E: EDbError do
      begin
        Check((E.SqlState = 'ERR') and (E.Category = decSyntax),
          'exec error normalized');
        Check(LRec.ErrorCount = 1, 'trace error event');
        Check(LRec.LastError = 'NOPE', 'trace error sql summary');
        Check(LRec.QueryCount = 1, 'trace no query on error');
      end;
    end;
    LTC := nil;
    LConn := nil;

end;

{ ===== 3 ===== }

procedure TestQueryRowMapping;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
  LQ: IDbQuery;
begin
  LTrans := TScriptedTransport.Create;
    LConn := MakeConn(LTrans);

    { 标量 bulk：一行文本 }
    LTrans.Script('$5'#13#10'hello'#13#10);
    LQ := LConn.Query('GET k');
    Check(LQ.Step, 'scalar step1');
    Check(not LQ.Step, 'scalar single row');
    Check((LQ.ColumnCount = 1) and (LQ.GetText(0) = 'hello'),
      'scalar text value');
    Check(LQ.ColumnType(0) = dbcText, 'scalar col type');
    LQ := nil;

    { integer 回复：列型 integer }
    LTrans.Script(':42'#13#10);
    LQ := LConn.Query('DEL k');
    Check(LQ.Step, 'step');
    Check((LQ.ColumnType(0) = dbcInteger) and (LQ.GetInt64(0) = 42),
      'integer reply row');
    LQ := nil;

    { null：零行 }
    LTrans.Script('$-1'#13#10);
    LQ := LConn.Query('GET missing');
    Check(not LQ.Step, 'null reply zero rows');
    LQ := nil;

    { 数组：每元素一行 }
    LTrans.Script('*3'#13#10'$1'#13#10'a'#13#10'$1'#13#10'b'#13#10 +
      ':3'#13#10);
    LQ := LConn.Query('LRANGE k 0 -1');
    Check(LQ.Step, 'step');  Check(LQ.GetText(0) = 'a', 'array row1');
    Check(LQ.Step, 'step');  Check(LQ.GetText(0) = 'b', 'array row2');
    Check(LQ.Step, 'step');  Check(LQ.GetInt64(0) = 3, 'array row3 int text');
    Check(not LQ.Step, 'array exhausted');
    LQ := nil;

    LConn := nil;

end;

{ ===== 4 ===== }

procedure TestResetRearms;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
  LQ: IDbQuery;
  LSentBefore: Integer;
begin
  LTrans := TScriptedTransport.Create;
    LConn := MakeConn(LTrans);
    LQ := LConn.Query('GET k');
    LTrans.Script('$2'#13#10'v1'#13#10);
    Check(LQ.Step, 'step');
    LSentBefore := LTrans.SendCount;
    LQ.Reset;
    LTrans.Script('$2'#13#10'v1'#13#10);
    Check(LQ.Step, 'reset re-executes');
    Check(LTrans.SendCount = LSentBefore + 1, 'reset resent command');
    LQ := nil;
    LConn := nil;

end;

{ ===== 5 ===== }

procedure TestTransactions;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
  LTx: IDbTxControl;
begin
  LTrans := TScriptedTransport.Create;
    LConn := MakeConn(LTrans);
    Supports(LConn, IDbTxControl, LTx);
    Check(LTx <> nil, 'tx control present');

    LTrans.Script('+OK'#13#10);            { MULTI }
    LTx.BeginTxn;
    Check(LTx.InTransaction, 'in txn after MULTI');
    Check(Pos('MULTI', LastSend(LTrans)) > 0, 'MULTI sent');

    LTrans.Script('+QUEUED'#13#10);        { 排队标记 }
    LConn.Exec('SET k v');

    LTrans.Script('*2'#13#10'+OK'#13#10':1'#13#10);   { EXEC }
    LTx.CommitTxn;
    Check(not LTx.InTransaction, 'txn closed after EXEC');
    Check(Pos('$4'#13#10'EXEC'#13#10, LastSend(LTrans)) > 0,
      'EXEC sent');

    { EXEC 数组内错误元素 post-fact 抛 }
    LTrans.Script('+OK'#13#10);
    LTx.BeginTxn;
    LTrans.Script('*1'#13#10'-READONLY You can''t write'#13#10);
    try
      LTx.CommitTxn;
      Check(False, 'exec array error should raise');
    except
      on E: EDbError do
      begin
        Check((E.SqlState = 'READONLY') and
          (E.Category = decConnection), 'exec element normalized');
      end;
    end;

    LTrans.Script('+OK'#13#10);
    LTx.BeginTxn;
    LTrans.Script('+OK'#13#10);
    LTx.RollbackTxn;
    Check(not LTx.InTransaction, 'discard closes txn');
    Check(Pos('DISCARD', LastSend(LTrans)) > 0, 'DISCARD sent');

    LTx := nil;
    LConn := nil;

end;

{ ===== 6 ===== }

procedure TestBatchPipeline;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
  LB: IDbBatchExecutor;
  LSteps: TDbSqlSteps;
begin
  LTrans := TScriptedTransport.Create;
    LConn := MakeConn(LTrans);
    Supports(LConn, IDbBatchExecutor, LB);
    Check(LB <> nil, 'batch executor present');

    SetLength(LSteps, 3);
    LSteps[0] := 'SET a 1';
    LSteps[1] := 'INCR a';
    LSteps[2] := 'GET a';
    LTrans.Script('+OK'#13#10);
    LTrans.Script(':2'#13#10);
    LTrans.Script('$1'#13#10'2'#13#10);
    LB.ExecuteBatch(LSteps);
    CheckEqual(Int64(LTrans.SendCount), 1, 'single write burst');

    { 第三步错误 → 精确步定位 }
    LTrans.Script('+OK'#13#10);
    LTrans.Script('+OK'#13#10);
    LTrans.Script('-ERR unknown command ''X'''#13#10);
    try
      LB.ExecuteBatch(LSteps);
      Check(False, 'batch error should raise');
    except
      on E: EDbError do
      begin
        Check(Pos('batch step 3', E.Message) > 0,
          'batch error step located');
        Check(E.Category = decSyntax, 'batch error category');
      end;
    end;

    LConn := nil;

end;

{ ===== 7 ===== }

procedure TestCapabilitiesMatrix;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
  LC: IDbCapabilities;
  LSp: IDbSavepointControl;
begin
  LTrans := TScriptedTransport.Create;
    LConn := MakeConn(LTrans);
    Supports(LConn, IDbCapabilities, LC);
    Check(LC <> nil, 'capabilities present');
    Check(LC.Kind = dbkRedis, 'cap kind');
    Check(not LC.SupportsSavepoints, 'cap savepoints false');
    Check(LC.SupportsBatchExecutor, 'cap batch true');
    Check(not LC.SupportsStmtCacheControl, 'cap stmtcache false');
    Check(not LC.SupportsLargeObjects, 'cap largeobjects false');
    Check(not LC.SupportsNativeBool, 'cap nativebool false');
    Check(not LC.SupportsMultiStatementExec, 'cap multistmt false');
    Check(not LC.SupportsStatementTimeout, 'cap stmtimeout false');
    Check(LC.CaseSensitiveIdentifiers, 'cap case-sensitive keys');
    CheckEqual(Int64(LC.MaxPlaceholders), 999, 'cap max placeholders');

    { B1 互证：布尔声明 ⇔ 接口存在性 }
    Supports(LConn, IDbSavepointControl, LSp);
    Check((LC.SupportsSavepoints = False) = (LSp = nil),
      'savepoints bool/interface mutual proof');

    LConn := nil;

end;

{ ===== 8 ===== }

procedure TestTracePairing;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
  LTC: IDbTraceControl;
  LRec: TRecordingListener;
  LRecI: IDbTraceListener;   { 自持生命周期：hub 释放后仍可读计数 }
begin
  { attach-catch-up：挂载补发 Acquire；连接释放补发 Release，
    严格 1:1（§2.12）。控制接口持强引用，必须先清再断连接引用。 }
  LTrans := TScriptedTransport.Create;
    LConn := MakeConn(LTrans);
    LRec := TRecordingListener.Create;
    LRecI := LRec;
    Supports(LConn, IDbTraceControl, LTC);
    LTC.SetListener(LRecI);
    CheckEqual(Int64(LRec.Acquires), Int64(1), 'pair attach acquire');
    LTC := nil;
    LConn := nil;
    CheckEqual(Int64(LRec.Acquires), Int64(1), 'pair acquire total');
    CheckEqual(Int64(LRec.Releases), Int64(1), 'pair release total');

end;

function ConnPingWorks(AConn: IDbConnection): Boolean;
var
  LQ: IDbQuery;
begin
  LQ := AConn.Query('PING');
  Result := LQ.Step and (LQ.GetText(0) = 'PONG');
  LQ := nil;
end;

{ ===== A5.1：INFO 版本探测（seam 显式开启）===== }

procedure TestInfoProbeSurfacesVersion;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
  LC: IDbCapabilities;
begin
  LTrans := TScriptedTransport.Create;
  LTrans.Script('$39'#13#10'# Server'#13#10'redis_version:7.2.4'#13#10 +
    'os:Linux'#13#10);
  LConn := ConnectRedisWithTransport(LTrans, '', 0, True);
  Supports(LConn, IDbCapabilities, LC);
  Check(LC.ProductVersion = '7.2.4', 'probed version surfaced');

  { 探测后连接仍可用 }
  LTrans.Script('+OK'#13#10);
  LConn.Exec('PING');
  LConn := nil;
end;

procedure TestInfoProbeValkeyFallbackAndTolerant;
var
  LTrans: TScriptedTransport;
  LConn: IDbConnection;
  LC: IDbCapabilities;
begin
  { valkey 回退键 }
  LTrans := TScriptedTransport.Create;
  LTrans.Script('$20'#13#10'valkey_version:8.0.0'#13#10);
  LConn := ConnectRedisWithTransport(LTrans, '', 0, True);
  Supports(LConn, IDbCapabilities, LC);
  Check(LC.ProductVersion = '8.0.0', 'valkey fallback version');
  LConn := nil;

  { 探测失败保守降级：错误回复吞掉，版本空，连接可用 }
  LTrans := TScriptedTransport.Create;
  LTrans.Script('-ERR unknown command ''INFO'''#13#10);
  LConn := ConnectRedisWithTransport(LTrans, '', 0, True);
  Supports(LConn, IDbCapabilities, LC);
  Check(LC.ProductVersion = '', 'probe failure keeps empty');
  LTrans.Script('+PONG'#13#10);
  Check(ConnPingWorks(LConn), 'conn usable after failed probe');
  LConn := nil;
end;

{ ===== A5.1b：TLS 变体 ===== }

procedure TestTlsNegativePathOffline;
var
  LOpts: TDbRedisConnectOptions;
  LRaised: Boolean;
begin
  { 离线可跑：UseTls 指向不可达端点 → TLSDial 失败桥接为统一
    EDbError(dbkRedis)，不漏裸 net/tls 异常 }
  LOpts := TDbRedisConnectOptions.Default;
  LOpts.UseTls := True;
  LRaised := False;
  try
    ConnectRedis('127.0.0.1:1', LOpts);
  except
    on E: EDbError do
    begin
      LRaised := (E.Backend = dbkRedis);
      Check(E.Category = decConnection, 'tls negative categorized');
    end;
  end;
  Check(LRaised, 'tls dial failure bridges to EDbError');
end;

{ ===== live（env 门控）===== }

procedure TestLiveRoundtrip;
const
  C_KEY = 'nextpas_redis_gate_probe';
var
  LEnv, LAddr: string;
  LConn: IDbConnection;
  LQ: IDbQuery;
begin
  LEnv := GetEnvironmentVariable('NEXTPAS_REDIS_TEST_CONN');
  if LEnv = '' then
  begin
    Writeln('[live] NEXTPAS_REDIS_TEST_CONN not set - skipped');
    Exit;
  end;
  LAddr := LEnv;
  LConn := ConnectRedis(LAddr);

  LConn.Exec('PING');
  LQ := LConn.Query('PING');
  Check(LQ.Step, 'step');
  Check(LQ.GetText(0) = 'PONG', 'live PONG');
  LQ := nil;

  LQ := LConn.Query('SET ? ?');
  LQ.BindText(1, C_KEY);
  LQ.BindText(2, 'gate-value');
  Check(LQ.Step, 'step');
  LQ := nil;

  LQ := LConn.Query('GET ?');
  LQ.BindText(1, C_KEY);
  Check(LQ.Step, 'step');
  Check(LQ.GetText(0) = 'gate-value', 'live GET roundtrip');
  LQ := nil;

  LConn.Exec('DEL ' + C_KEY);
  LConn := nil;
end;

procedure TestLiveTlsRoundtrip;
var
  LEnv, LAddr, LPwd: string;
  LOpts: TDbRedisConnectOptions;
  LConn: IDbConnection;
  LQ: IDbQuery;
begin
  LEnv := GetEnvironmentVariable('NEXTPAS_REDIS_TEST_TLS_CONN');
  if LEnv = '' then
  begin
    Writeln('[live-tls] NEXTPAS_REDIS_TEST_TLS_CONN not set - skipped');
    Exit;
  end;
  LAddr := LEnv;
  LPwd := GetEnvironmentVariable('NEXTPAS_REDIS_TEST_TLS_PASSWORD');
  LOpts := TDbRedisConnectOptions.Default;
  LOpts.UseTls := True;
  LOpts.Password := LPwd;
  LConn := ConnectRedis(LAddr, LOpts);
  LQ := LConn.Query('PING');
  Assert(LQ.Step);
  Check(LQ.GetText(0) = 'PONG', 'live-tls PONG');
  LQ := nil;
  LConn := nil;
end;

begin
  T := TTestSuite.Create('nextpas.core.db.redis.adapter');
  T.Test('handshake order', @TestHandshakeOrder);
  T.Test('handshake auth select', @TestHandshakeAuthSelect);
  T.Test('handshake error fails', @TestHandshakeErrorFails);
  T.Test('exec placeholders and trace', @TestExecPlaceholdersAndTrace);
  T.Test('query row mapping', @TestQueryRowMapping);
  T.Test('reset rearm', @TestResetRearms);
  T.Test('transactions', @TestTransactions);
  T.Test('batch pipeline', @TestBatchPipeline);
  T.Test('capabilities matrix', @TestCapabilitiesMatrix);
  T.Test('trace pairing', @TestTracePairing);
  T.Test('info probe surfaces version', @TestInfoProbeSurfacesVersion);
  T.Test('info probe valkey fallback and tolerant', @TestInfoProbeValkeyFallbackAndTolerant);
  T.Test('tls negative path offline', @TestTlsNegativePathOffline);
  T.Test('live roundtrip', @TestLiveRoundtrip);
  T.Test('live tls roundtrip', @TestLiveTlsRoundtrip);
  if not T.Run then Halt(1);
end.
