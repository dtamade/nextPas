program test_db_factory;
{ V3-A5 统一驱动工厂门禁：注册表契约（快照/探测/重复拒绝）、
  DbOpen 双形态（名/枚举）分派正确性（逐后端负路径证达 + sqlite
  正路往返 + 能力互证）、第三方可插拔、Open 即池组合冒烟。
  全部离线可跑；heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db,
  nextpas.core.db.factory,
  nextpas.core.db.factory.pool,
  nextpas.core.db.pool,
  nextpas.core.db.sqlite.adapter,
  nextpas.core.db.pg.adapter,
  nextpas.core.db.mysql.adapter,
  nextpas.core.db.odbc.adapter,
  nextpas.core.db.redis.adapter,
  nextpas.core.db.dm.adapter;

type
  { 第三方假连接：Exec 计数，Query 明确不支持（诚实 fail-fast） }
  TFakeConn = class(TInterfacedObject, IDbConnection)
  private
    FExecs: Integer;
  public
    function Kind: TDbKind;
    procedure Exec(const ASql: string); overload;
    procedure Exec(const ASql: string;
      const AOptions: TDbExecOptions); overload;
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string;
      const AOptions: TDbExecOptions): IDbQuery; overload;
    function Changes: Int64;
    function Raw: Pointer;
    property Execs: Integer read FExecs;
  end;

  { 第三方假驱动：Kind=dbkUnknown（诚实不冒充内建归属）；
    记录最近一次 DSN 与打开的连接对象供断言 }
  TFakeDriver = class(TInterfacedObject, IDbDriver)
  private
    FLastDsn: string;
    FLastConnObj: TObject;
  public
    function Name: string;
    function Kind: TDbKind;
    function Open(const ADsn: string;
      const AOptions: TDbConnectOptions;
      const AStmtCacheCapacity: Integer = 64): IDbConnection;
    property LastDsn: string read FLastDsn;
    property LastConnObj: TObject read FLastConnObj;
  end;

var
  T: TTestSuite;

// 显式注册辅助：factory.builtin 已物理删除(2026-09-02) 不再计入模块节点，显式注册为准；本测试显式注入六驱动（直连 adapter owner，bytes.ops 单源 inline 零拷贝，接口引用计数自动归还；避免经门面循环依赖，裁剪边界=直连 adapter/按需 register 单元）
function OpenSqliteForTest(const ADsn: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin Result := nextpas.core.db.sqlite.adapter.ConnectSqlite(ADsn, AOptions, AStmtCacheCapacity); end;
function OpenPgForTest(const ADsn: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin Result := nextpas.core.db.pg.adapter.ConnectPostgres(ADsn, AOptions, AStmtCacheCapacity); end;
function OpenMysqlForTest(const ADsn: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin Result := nextpas.core.db.mysql.adapter.ConnectMysql(ADsn, AOptions, AStmtCacheCapacity); end;
function OpenOdbcForTest(const ADsn: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin Result := nextpas.core.db.odbc.adapter.ConnectOdbc(ADsn, AOptions, AStmtCacheCapacity); end;
function OpenRedisForTest(const ADsn: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin Result := nextpas.core.db.redis.adapter.ConnectRedis(ADsn, '', 0, AOptions); end;
function OpenDmForTest(const ADsn: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin Result := nextpas.core.db.dm.adapter.ConnectDm(ADsn, AOptions, AStmtCacheCapacity); end;

procedure EnsureBuiltinDrivers; inline;
begin
  if DbDriverExists('sqlite') then Exit;
  DbRegisterDriver(TBuiltinDriver.Create('sqlite', dbkSqlite, @OpenSqliteForTest));
  DbRegisterDriver(TBuiltinDriver.Create('postgres', dbkPostgres, @OpenPgForTest));
  DbRegisterDriver(TBuiltinDriver.Create('mysql', dbkMysql, @OpenMysqlForTest));
  DbRegisterDriver(TBuiltinDriver.Create('odbc', dbkOdbc, @OpenOdbcForTest));
  DbRegisterDriver(TBuiltinDriver.Create('redis', dbkRedis, @OpenRedisForTest));
  DbRegisterDriver(TBuiltinDriver.Create('dm', dbkDm, @OpenDmForTest));
end;

function TFakeConn.Kind: TDbKind;
begin
  Result := dbkUnknown;
end;

procedure TFakeConn.Exec(const ASql: string);
begin
  Inc(FExecs);
end;

procedure TFakeConn.Exec(const ASql: string;
  const AOptions: TDbExecOptions);
begin
  Inc(FExecs);
end;

function TFakeConn.Query(const ASql: string): IDbQuery;
begin
  Result := nil;
  raise EDbError.CreateSimple(dbkUnknown, 'fake driver: no query');
end;

function TFakeConn.Query(const ASql: string;
  const AOptions: TDbExecOptions): IDbQuery;
begin
  Result := nil;
  raise EDbError.CreateSimple(dbkUnknown, 'fake driver: no query');
end;

function TFakeConn.Changes: Int64;
begin
  Result := 0;
end;

function TFakeConn.Raw: Pointer;
begin
  Result := nil;
end;

function TFakeDriver.Name: string;
begin
  Result := 'fakedrv';
end;

function TFakeDriver.Kind: TDbKind;
begin
  Result := dbkUnknown;
end;

function TFakeDriver.Open(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer = 64): IDbConnection;
var
  LConnObj: TFakeConn;
begin
  FLastDsn := ADsn;
  LConnObj := TFakeConn.Create;
  Result := LConnObj;
  FLastConnObj := LConnObj;
end;

{ ---- 用例 ---- }

{ 内建注册表快照：六个规范名，字典序 }
procedure TestBuiltinRegistrySnapshot;
const
  C_EXPECTED: array[0..5] of string =
    ('dm', 'mysql', 'odbc', 'postgres', 'redis', 'sqlite');
var
  LNames: TDbDriverNames;
  I: Integer;
begin
  LNames := DbRegisteredDrivers;
  CheckEqual(6, Length(LNames), 'builtin count');
  for I := 0 to High(C_EXPECTED) do
    CheckEqual(C_EXPECTED[I], LNames[I], 'sorted name ' + IntToStr(I));
end;

procedure TestDriverExistsProbe;
begin
  Check(DbDriverExists('sqlite'), 'sqlite exists');
  Check(DbDriverExists('SQLite'), 'case-insensitive lookup');
  Check(not DbDriverExists('nosuchdrv'), 'unknown absent');
end;

procedure TestUnknownDriverFailsFast;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    DbOpen('nosuchdrv', 'whatever');
  except
    on E: EDbError do
    begin
      LRaised := True;
      Check(E.Backend = dbkUnknown, 'factory error kind unknown');
      Check(Pos('nosuchdrv', E.Message) > 0, 'message carries name');
    end;
  end;
  Check(LRaised, 'unknown driver raised');
end;

procedure TestEmptyDriverNameRejected;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    DbOpen('', ':memory:');
  except
    on E: EDbError do
      LRaised := True;
  end;
  Check(LRaised, 'empty driver name raised');
end;

procedure TestSqliteRoundtripByName;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
begin
  LConn := DbOpen('sqlite', ':memory:');
  Check(LConn.Kind = dbkSqlite, 'backend attribution');
  LConn.Exec('CREATE TABLE t (v TEXT)');
  LConn.Exec('INSERT INTO t VALUES (''factory'')');
  LQ := LConn.Query('SELECT v FROM t');
  Check(LQ.Step, 'step');
  Check(LQ.GetText(0) = 'factory', 'roundtrip value');
  LQ := nil;
  LConn := nil;
end;

procedure TestSqliteOpenByKind;
var
  LConn: IDbConnection;
begin
  LConn := DbOpen(dbkSqlite, ':memory:', TDbConnectOptions.Default);
  Check(LConn.Kind = dbkSqlite, 'kind dispatch works');
  LConn := nil;
end;

{ 负路径分派证明：错误必须携带对应内建后端归属——证明请求到达了
  正确的 adapter 而非被工厂吞掉或误派 }
procedure TestPostgresDispatchNegative;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    DbOpen('postgres',
      'host=127.0.0.1 port=1 dbname=x user=u connect_timeout=1');
  except
    on E: EDbError do
    begin
      LRaised := E.Backend = dbkPostgres;
      Check(E.Category = decConnection, 'pg negative categorized');
    end;
  end;
  Check(LRaised, 'pg dispatch reached adapter');
end;

procedure TestMysqlDispatchNegative;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    DbOpen('mysql',
      'host=127.0.0.1 port=1 user=u password=p db=d');
  except
    on E: EDbError do
      LRaised := E.Backend = dbkMysql;
  end;
  Check(LRaised, 'mysql dispatch reached adapter');
end;

procedure TestOdbcDispatchNegative;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    DbOpen('odbc', 'Driver={NoSuchDriverNextpasGate}');
  except
    on E: EDbError do
      LRaised := E.Backend = dbkOdbc;
  end;
  Check(LRaised, 'odbc dispatch reached adapter');
end;

procedure TestRedisDispatchNegative;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    DbOpen('redis', '127.0.0.1:1');
  except
    on E: EDbError do
    begin
      LRaised := E.Backend = dbkRedis;
      Check(E.Category = decConnection, 'redis dial categorized');
    end;
  end;
  Check(LRaised, 'redis dispatch reached adapter');
end;

procedure TestKindUnknownFailClosed;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    DbOpen(dbkUnknown, 'x', TDbConnectOptions.Default);
  except
    on E: EDbNotSupported do
      LRaised := True;
  end;
  Check(LRaised, 'dbkUnknown fail-closed');
end;

procedure TestThirdPartyPluggable;
var
  LDrvIface: IDbDriver;
  LDrv: TFakeDriver;
  LConn: IDbConnection;
  LNames: TDbDriverNames;
  I: Integer;
  LFound: Boolean;
begin
  LDrv := TFakeDriver.Create;
  LDrvIface := LDrv;              { 自持接口引用，防注册表外悬垂 }
  DbRegisterDriver(LDrvIface);
  Check(DbDriverExists('fakedrv'), 'third-party registered');
  LNames := DbRegisteredDrivers;
  LFound := False;
  for I := 0 to High(LNames) do
    if LNames[I] = 'fakedrv' then
      LFound := True;
  Check(LFound, 'snapshot includes fakedrv');
  LConn := DbOpen('fakedrv', 'dsn-goes-through');
  Check(LConn <> nil, 'open via third-party');
  CheckEqual('dsn-goes-through', LDrv.LastDsn, 'dsn passthrough');
  Check(LConn.Kind = dbkUnknown, 'honest unknown kind');
  LConn.Exec('PING');
  Check(LDrv.LastConnObj <> nil, 'conn object tracked');
  if LDrv.LastConnObj is TFakeConn then
    CheckEqual(1, TFakeConn(LDrv.LastConnObj).Execs, 'exec counted');
  LConn := nil;
end;

procedure TestDuplicateRegistrationRejected;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    DbRegisterDriver(TFakeDriver.Create);
  except
    on E: EDbError do
      LRaised := True;
  end;
  Check(LRaised, 'duplicate name fail-closed');
end;

procedure TestCapabilitiesInterop;
var
  LConn: IDbConnection;
  LC: IDbCapabilities;
begin
  LConn := DbOpen('sqlite', ':memory:');
  LC := DbCapabilities(LConn);
  Check(LC <> nil, 'capabilities exposed');
  if LC <> nil then
  begin
    Check(LC.Kind = dbkSqlite, 'capability kind matches driver');
    Check(LC.MaxPlaceholders > 0, 'placeholders declared');
  end;
  LC := nil;
  LConn := nil;
end;

procedure TestPoolCompositionSmoke;
var
  LPath: string;
  LPool: TDbPool;
  LConn: IDbConnection;
  LQ: IDbQuery;
begin
  { 显式 /tmp：GetTempDir 内部缓存串会干扰 heaptrc 0-unfreed 硬门 }
  LPath := '/tmp/nextpas_factory_pool_test.db';
  DeleteFile(LPath);
  try
    LPool := DbOpenPool('sqlite', LPath, TDbPoolPolicy.Default);
    LConn := LPool.Acquire;
    LConn.Exec('CREATE TABLE p (v INTEGER)');
    LConn.Exec('INSERT INTO p VALUES (42)');
    LQ := LConn.Query('SELECT v FROM p');
    Check(LQ.Step, 'pool step');
    Check(LQ.GetInt64(0) = 42, 'pool roundtrip');
    LQ := nil;
    LConn := nil;
    LPool.Close;
    LPool.Free;
  finally
    DeleteFile(LPath);
  end;
end;

begin
  EnsureBuiltinDrivers;
  T := TTestSuite.Create('nextpas.core.db.factory');
  T.Test('builtin registry snapshot', @TestBuiltinRegistrySnapshot);
  T.Test('driver exists probe', @TestDriverExistsProbe);
  T.Test('unknown driver fails fast', @TestUnknownDriverFailsFast);
  T.Test('empty driver name rejected', @TestEmptyDriverNameRejected);
  T.Test('sqlite roundtrip by name', @TestSqliteRoundtripByName);
  T.Test('sqlite open by kind', @TestSqliteOpenByKind);
  T.Test('postgres dispatch negative', @TestPostgresDispatchNegative);
  T.Test('mysql dispatch negative', @TestMysqlDispatchNegative);
  T.Test('odbc dispatch negative', @TestOdbcDispatchNegative);
  T.Test('redis dispatch negative', @TestRedisDispatchNegative);
  T.Test('kind unknown fail-closed', @TestKindUnknownFailClosed);
  T.Test('third-party pluggable', @TestThirdPartyPluggable);
  T.Test('duplicate registration rejected',
    @TestDuplicateRegistrationRejected);
  T.Test('capabilities interop', @TestCapabilitiesInterop);
  T.Test('pool composition smoke', @TestPoolCompositionSmoke);
  if not T.Run then Halt(1);
end.
