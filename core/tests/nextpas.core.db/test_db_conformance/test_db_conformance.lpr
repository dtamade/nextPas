program test_db_conformance;

{ V2-S1 一致性契约套件：同一套行为用例在两后端逐字复跑。
  覆盖面（每项都钉住 CONTRACT.md 已成文契约）：
    1  类型往返（int64 边界/double/unicode 文本/含 0x00 blob）
    2  NULL 语义（IsNull 先行、Get* 零值静默、BindNull 往返）
    3  列元数据（计数/列名不区分大小写比较/类型映射）
    4  约束归一（unique/notnull/check/fk；PK 按后端原生细分）
    5  语法错误归一（decSyntax 两后端一致）
    6  字面量保真（引号转义/分号/? 与注释记号在字面量内不被翻译）
    7  事务语义（提交持久/回滚撤销/嵌套计数/外层回滚全清）
    8  savepoint 部分回滚（内层失败只撤内层）
    9  迁移（应用/幂等/版本读取/乱序拒绝）
   10  Changes 计数

  sqlite 段总是执行；pg 段需要本地 PostgreSQL（Makefile ensure-db）。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db,
  nextpas.core.db.factory,
  nextpas.core.db.sqlite.adapter,
  nextpas.core.db.pg.adapter,
  nextpas.core.db.mysql.adapter,
  nextpas.core.db.odbc.adapter,
  nextpas.core.db.redis.adapter,
  nextpas.core.db.dm.adapter,
  nextpas.core.db.err,
  nextpas.core.db.tx,
  nextpas.core.db.migrate;

var
  GEnsuredConf: Boolean = False;
  T: TTestSuite;

function OpenSqliteC(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := ConnectSqlite(ADsn, AOptions); end;
function OpenPgC(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := ConnectPostgres(ADsn, AOptions); end;
function OpenMysqlC(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := ConnectMysql(ADsn, AOptions); end;
function OpenOdbcC(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := ConnectOdbc(ADsn, AOptions); end;
function OpenRedisC(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := ConnectRedis(ADsn, '', 0, AOptions); end;
function OpenDmC(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := ConnectDm(ADsn, AOptions); end;
procedure EnsureBuiltinConf; inline;
begin
  if GEnsuredConf then Exit;
  if not DbDriverExists('sqlite') then DbRegisterDriver(TBuiltinDriver.Create('sqlite', dbkSqlite, @OpenSqliteC));
  if not DbDriverExists('postgres') then DbRegisterDriver(TBuiltinDriver.Create('postgres', dbkPostgres, @OpenPgC));
  if not DbDriverExists('mysql') then DbRegisterDriver(TBuiltinDriver.Create('mysql', dbkMysql, @OpenMysqlC));
  if not DbDriverExists('odbc') then DbRegisterDriver(TBuiltinDriver.Create('odbc', dbkOdbc, @OpenOdbcC));
  if not DbDriverExists('redis') then DbRegisterDriver(TBuiltinDriver.Create('redis', dbkRedis, @OpenRedisC));
  if not DbDriverExists('dm') then DbRegisterDriver(TBuiltinDriver.Create('dm', dbkDm, @OpenDmC));
  GEnsuredConf := True;
end;

{ ==== 共享断言助手 ==== }

procedure ExpectCategory(const AConn: IDbConnection; const ASql: string;
  const AExpected: TDbErrorCategory; const ALabel: string);
var
  Caught: Boolean;
begin
  Caught := False;
  try
    AConn.Exec(ASql);
  except
    on E: EDbError do
    begin
      Caught := True;
      Check(E.Category = AExpected,
        ALabel + ': category = ' + IntToStr(Ord(AExpected)));
    end;
  end;
  Check(Caught, ALabel + ': raised as EDbError');
end;

function ScalarInt(const AConn: IDbConnection; const ASql: string): Int64;
var
  Q: IDbQuery;
begin
  Q := AConn.Query(ASql);
  Check(Q.Step, 'scalar: row present');
  Result := Q.GetInt64(0);
end;

{ ==== 1. 类型往返 ==== }

procedure RunTypeRoundtrip(const AConn: IDbConnection; const P: string);
var
  Q: IDbQuery;
  LB, LBOut: TBytes;
const
  LO64: Int64 = Low(Int64);
  HI64: Int64 = High(Int64);
  { 浮点字面量在 x86_64 FPC 默认 Extended(80bit)，直接与 Double 比较会
    因多余精度失败——期望值必须先落成 Double 类型常量 }
  E_VAL: Double = -2.718281828459045;
begin
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_rt');
  if AConn.Kind = dbkSqlite then
    AConn.Exec('CREATE TABLE ' + P + '_rt (i BIGINT, f REAL, s TEXT, b BLOB)')
  else
    AConn.Exec('CREATE TABLE ' + P + '_rt (i BIGINT, f DOUBLE PRECISION, ' +
      's TEXT, b BYTEA)');
  Q := AConn.Query('INSERT INTO ' + P + '_rt (i, f, s, b) VALUES (?, ?, ?, ?)');
  LB := TBytes.Create($00, $FF, $80, $41);
  Q.BindInt64(1, HI64);
  Q.BindDouble(2, -2.718281828459045);
  Q.BindText(3, 'héllo-世界-🚀');
  Q.BindBlob(4, LB);
  while Q.Step do ;
  Q := nil;
  Q := AConn.Query('INSERT INTO ' + P + '_rt (i, f, s, b) VALUES (?, ?, ?, ?)');
  Q.BindInt64(1, LO64);
  Q.BindDouble(2, 0.0);
  Q.BindText(3, '');
  while Q.Step do ;
  Q := nil;

  Q := AConn.Query('SELECT i, f, s, b FROM ' + P + '_rt ORDER BY i ASC');
  Check(Q.Step, P + '/rt: low row');
  Check(Q.GetInt64(0) = LO64, P + '/rt: int64 low');
  Check(Q.Step, P + '/rt: high row');
  Check(Q.ColumnCount = 4, P + '/rt: column count');
  Check(Q.GetInt64(0) = HI64, P + '/rt: int64 high');
  Check(Q.GetDouble(1) = E_VAL, P + '/rt: double bits');
  Check(Q.GetText(2) = 'héllo-世界-🚀', P + '/rt: unicode text');
  LBOut := Q.GetBlob(3);
  Check(Length(LBOut) = 4, P + '/rt: blob length');
  Check((LBOut[0] = $00) and (LBOut[1] = $FF) and (LBOut[3] = $41),
    P + '/rt: blob bytes incl 0x00');
  Q := nil;
  AConn.Exec('DROP TABLE ' + P + '_rt');

  { bool 列类型精化（INC-6）：声明/原生布尔 → dbcBool；值读经
    GetInt64 归一 1/0（pg 文本协议 't'/'f' 由适配器翻译）；NULL 行级
    信号优先于声明类型。DDL 两引擎通用。 }
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_rtb');
  AConn.Exec('CREATE TABLE ' + P + '_rtb (id INTEGER PRIMARY KEY, bo BOOLEAN)');
  Q := AConn.Query('INSERT INTO ' + P + '_rtb (id, bo) VALUES (?, ?)');
  Q.BindInt64(1, 1); Q.BindInt64(2, 1);
  while Q.Step do ;
  Q := nil;
  Q := AConn.Query('INSERT INTO ' + P + '_rtb (id, bo) VALUES (?, ?)');
  Q.BindInt64(1, 2); Q.BindInt64(2, 0);
  while Q.Step do ;
  Q := nil;
  Q := AConn.Query('INSERT INTO ' + P + '_rtb (id, bo) VALUES (?, ?)');
  Q.BindInt64(1, 3); Q.BindNull(2);
  while Q.Step do ;
  Q := nil;

  Q := AConn.Query('SELECT bo FROM ' + P + '_rtb ORDER BY id ASC');
  Check(Q.Step, P + '/rtb: true row');
  Check(Q.ColumnType(0) = dbcBool, P + '/rtb: declared/native bool is dbcBool');
  Check(Q.GetInt64(0) = 1, P + '/rtb: true reads as 1');
  Check(Q.Step, P + '/rtb: false row');
  Check(Q.ColumnType(0) = dbcBool, P + '/rtb: false row keeps column type');
  Check(Q.GetInt64(0) = 0, P + '/rtb: false reads as 0');
  Check(Q.Step, P + '/rtb: null row');
  Check(Q.ColumnType(0) = dbcNull, P + '/rtb: null value reports dbcNull');
  Check(Q.IsNull(0), P + '/rtb: null value flags IsNull');
  Q := nil;
  AConn.Exec('DROP TABLE ' + P + '_rtb');
end;

{ ==== 2. NULL 语义 ==== }

procedure RunNullSuite(const AConn: IDbConnection; const P: string);
var
  Q: IDbQuery;
begin
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_nul');
  AConn.Exec('CREATE TABLE ' + P + '_nul (i INTEGER, s TEXT)');
  { NULL 参数绑定 }
  Q := AConn.Query('INSERT INTO ' + P + '_nul (i, s) VALUES (?, ?)');
  Q.BindNull(1);
  Q.BindNull(2);
  while Q.Step do ;
  Q := nil;
  { 非空空串与 NULL 的区分 }
  Q := AConn.Query('INSERT INTO ' + P + '_nul (i, s) VALUES (0, '''')');
  while Q.Step do ;
  Q := nil;

  Q := AConn.Query('SELECT i, s FROM ' + P + '_nul WHERE i IS NULL');
  { NULL 行 }
  Check(Q.Step, P + '/null: null row');
  Check(Q.IsNull(0) and Q.IsNull(1), P + '/null: IsNull true');
  Check(Q.GetInt64(0) = 0, P + '/null: GetInt64 zero-value');
  Check(Q.GetText(1) = '', P + '/null: GetText zero-value');
  Check(not Q.Step, P + '/null: single null row');
  Q := nil;
  { 空串行：非 NULL 但文本为空 }
  Q := AConn.Query('SELECT s FROM ' + P + '_nul WHERE s IS NOT NULL');
  Check(Q.Step, P + '/null: empty-string row');
  Check(not Q.IsNull(0), P + '/null: empty string not null');
  Check(Q.GetText(0) = '', P + '/null: empty string reads back');
  Q := nil;
  AConn.Exec('DROP TABLE ' + P + '_nul');
end;

{ ==== 3. 列元数据 ==== }

procedure RunMetaSuite(const AConn: IDbConnection; const P: string);
var
  Q: IDbQuery;
begin
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_meta');
  if AConn.Kind = dbkSqlite then
    AConn.Exec('CREATE TABLE ' + P + '_meta (Id INTEGER, Name TEXT, Score REAL)')
  else
    AConn.Exec('CREATE TABLE ' + P + '_meta (Id INTEGER, Name TEXT, ' +
      'Score DOUBLE PRECISION)');
  AConn.Exec('INSERT INTO ' + P + '_meta VALUES (1, ''x'', 2.5)');
  Q := AConn.Query('SELECT Id, Name, Score FROM ' + P + '_meta');
  { 元数据契约：首次 Step 后可靠（含空结果集）——pg 结果描述随执行
    产生，prepare 阶段不可读 }
  Check(Q.Step, P + '/meta: row present');
  Check(Q.ColumnCount = 3, P + '/meta: count');
  { 列名大小写不保留是跨后端契约（pg 折叠小写），一律不区分大小写比较 }
  Check(SameText(Q.ColumnName(0), 'Id'), P + '/meta: col0 name');
  Check(SameText(Q.ColumnName(1), 'Name'), P + '/meta: col1 name');
  Check(Q.ColumnType(0) = dbcInteger, P + '/meta: int type');
  Check(Q.ColumnType(1) = dbcText, P + '/meta: text type');
  Check(Q.ColumnType(2) = dbcFloat, P + '/meta: float type');
  Q := nil;
  AConn.Exec('DROP TABLE ' + P + '_meta');
end;

{ ==== 4. 约束归一 ==== }

procedure ExpectConstraint(const AConn: IDbConnection; const ASql: string;
  const AExpected: TDbConstraintKind; const ALabel: string);
var
  Caught: Boolean;
begin
  Caught := False;
  try
    AConn.Exec(ASql);
  except
    on E: EDbError do
    begin
      Caught := True;
      Check(E.Category = decConstraint, ALabel + ': decConstraint');
      Check(E.Constraint = AExpected,
        ALabel + ': kind = ' + IntToStr(Ord(AExpected)));
    end;
  end;
  Check(Caught, ALabel + ': EDbError raised');
end;

procedure RunConstraintSuite(const AConn: IDbConnection; const P: string);
var
  LRaised: Boolean;
begin
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_u');
  AConn.Exec('CREATE TABLE ' + P + '_u (code TEXT UNIQUE)');
  AConn.Exec('INSERT INTO ' + P + '_u VALUES (''a'')');
  ExpectConstraint(AConn, 'INSERT INTO ' + P + '_u VALUES (''a'')',
    dckUnique, P + '/unique');

  { G5 定位字段：pg 从 libpq 诊断字段可得即填表名；
    sqlite extended code 不携带定位信息，保持空串（欠归一不错归一） }
  LRaised := False;
  try
    AConn.Exec('INSERT INTO ' + P + '_u VALUES (''a'')');
  except
    on E: EDbError do
    begin
      LRaised := True;
      if AConn.Kind = dbkPostgres then
        Check(E.TableName = P + '_u', P + '/loc: pg table name populated')
      else
        Check(E.TableName = '', P + '/loc: sqlite stays empty honestly');
    end;
  end;
  Check(LRaised, P + '/loc: duplicate raised for inspection');

  { NOT NULL }
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_nn');
  AConn.Exec('CREATE TABLE ' + P + '_nn (v TEXT NOT NULL)');
  ExpectConstraint(AConn, 'INSERT INTO ' + P + '_nn VALUES (NULL)',
    dckNotNull, P + '/notnull');

  { CHECK }
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_ck');
  AConn.Exec('CREATE TABLE ' + P + '_ck (v INTEGER CHECK (v >= 0))');
  ExpectConstraint(AConn, 'INSERT INTO ' + P + '_ck VALUES (-5)',
    dckCheck, P + '/check');

  { FK（sqlite 外键强制是会话开关） }
  if AConn.Kind = dbkSqlite then
    AConn.Exec('PRAGMA foreign_keys = ON');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_child');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_parent');
  AConn.Exec('CREATE TABLE ' + P + '_parent (id INTEGER PRIMARY KEY)');
  AConn.Exec('CREATE TABLE ' + P + '_child (' +
    'pid INTEGER REFERENCES ' + P + '_parent(id))');
  ExpectConstraint(AConn, 'INSERT INTO ' + P + '_child VALUES (999)',
    dckForeignKey, P + '/fk');

  { PK 细分按后端原生分类：sqlite 有独立子码，pg 折叠进 unique_violation }
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_pk');
  AConn.Exec('CREATE TABLE ' + P + '_pk (id INTEGER PRIMARY KEY)');
  AConn.Exec('INSERT INTO ' + P + '_pk VALUES (1)');
  if AConn.Kind = dbkSqlite then
    ExpectConstraint(AConn, 'INSERT INTO ' + P + '_pk VALUES (1)',
      dckPrimaryKey, P + '/pk')
  else
    ExpectConstraint(AConn, 'INSERT INTO ' + P + '_pk VALUES (1)',
      dckUnique, P + '/pk');

  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_u');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_nn');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_ck');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_pk');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_child');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_parent');
end;

{ ==== 5. 语法错误归一 ==== }

procedure RunSyntaxSuite(const AConn: IDbConnection; const P: string);
begin
  { 语法分类按后端能力如实分档：pg 的 SQLSTATE '42' 类可判 decSyntax；
    sqlite 无细粒度码（code 1 混杂语法/缺表），宁欠归一保持 decUnknown。
    差异已在 CONTRACT 登记，消费方跨后端只依赖 decConstraint/decTimeout
    等可靠类目。 }
  if AConn.Kind = dbkSqlite then
    ExpectCategory(AConn, 'SELEC 1', decUnknown, P + '/syntax')
  else
    ExpectCategory(AConn, 'SELEC 1', decSyntax, P + '/syntax');
end;

{ ==== 6. 字面量保真 ==== }

procedure RunLiteralSuite(const AConn: IDbConnection; const P: string);
var
  Q: IDbQuery;
  LSrc: string;
begin
  { 引号转义 + 分号 + '?' + 注释记号全部位于字面量内：
    pg 翻译器必须原样保留（占位符扫描跳过字面量） }
  LSrc := 'it''s ok? ; -- not-a-comment /* neither */ done';
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_lit');
  AConn.Exec('CREATE TABLE ' + P + '_lit (s TEXT)');
  Q := AConn.Query(
    'INSERT INTO ' + P + '_lit VALUES (''' + StringReplace(
      LSrc, '''', '''''', [rfReplaceAll]) + ''')');
  while Q.Step do ;
  Q := nil;
  Q := AConn.Query('SELECT s FROM ' + P + '_lit');
  Check(Q.Step, P + '/literal: row');
  Check(Q.GetText(0) = LSrc, P + '/literal: exact fidelity');
  Q := nil;
  AConn.Exec('DROP TABLE ' + P + '_lit');
end;

{ ==== 7. 事务语义 ==== }

procedure RunTxSuite(const AConn: IDbConnection; const P: string);
begin
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_tx');
  AConn.Exec('CREATE TABLE ' + P + '_tx (tag TEXT)');

  { 提交持久 }
  WithTransaction(AConn, procedure
  begin
    AConn.Exec('INSERT INTO ' + P + '_tx VALUES (''committed'')');
  end);
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_tx') = 1,
    P + '/tx: commit persists');

  { 回滚撤销 }
  try
    WithTransaction(AConn, procedure
    begin
      AConn.Exec('INSERT INTO ' + P + '_tx VALUES (''rolled-back'')');
      raise ENextPasError.Create(P + ' rollback trigger');
    end);
  except
    on E: ENextPasError do ;
  end;
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_tx') = 1,
    P + '/tx: rollback undoes');

  { 嵌套（V2-S2 savepoint 契约）：内层失败真正只撤销内层写入，
    外层捕获异常继续，最终提交的持久化状态如实反映部分回滚 }
  WithTransaction(AConn, procedure
  begin
    AConn.Exec('INSERT INTO ' + P + '_tx VALUES (''outer-keep'')');
    try
      WithTransaction(AConn, procedure
      begin
        AConn.Exec('INSERT INTO ' + P + '_tx VALUES (''inner-doomed'')');
        raise ENextPasError.Create(P + ' inner boom');
      end);
    except
      on E: ENextPasError do ;   { 捕获后外层继续：内层写入已撤销 }
    end;
    AConn.Exec('INSERT INTO ' + P + '_tx VALUES (''after-inner'')');
  end);
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_tx ' +
    'WHERE tag IN (''outer-keep'', ''after-inner'')') = 2,
    P + '/tx: outer writes survive inner failure');
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_tx ' +
    'WHERE tag = ''inner-doomed''') = 0,
    P + '/tx: inner failure undid only the inner write');

  { 三层嵌套：中层失败撤销中层与其后全部更深层（savepoint 栈语义），
    仅外层保留 }
  WithTransaction(AConn, procedure
  begin
    AConn.Exec('INSERT INTO ' + P + '_tx VALUES (''lv1-keep'')');
    try
      WithTransaction(AConn, procedure
      begin
        WithTransaction(AConn, procedure
        begin
          AConn.Exec('INSERT INTO ' + P + '_tx VALUES (''lv3-swallowed'')');
        end);
        AConn.Exec('INSERT INTO ' + P + '_tx VALUES (''lv2-doomed'')');
        raise ENextPasError.Create(P + ' mid boom');
      end);
    except
      on E: ENextPasError do ;   { 捕获后外层继续 }
    end;
    AConn.Exec('INSERT INTO ' + P + '_tx VALUES (''lv1-after'')');
  end);
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_tx ' +
    'WHERE tag IN (''lv1-keep'', ''lv1-after'')') = 2,
    P + '/tx: mid-level rollback keeps only the outer scope');
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_tx ' +
    'WHERE tag IN (''lv2-doomed'', ''lv3-swallowed'')') = 0,
    P + '/tx: deeper savepoints die with mid-level rollback');

  { 外层失败：包括已 RELEASE 的内层在内的全部撤销 }
  try
    WithTransaction(AConn, procedure
    begin
      AConn.Exec('INSERT INTO ' + P + '_tx VALUES (''doomed'')');
      raise ENextPasError.Create(P + ' outer boom');
    end);
  except
    on E: ENextPasError do ;
  end;
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_tx ' +
    'WHERE tag = ''doomed''') = 0,
    P + '/tx: outer rollback wipes its own writes');

  AConn.Exec('DROP TABLE ' + P + '_tx');
end;

{ ==== 8. savepoint 部分回滚 ==== }

procedure RunSavepointSuite(const AConn: IDbConnection; const P: string);
var
  Sp: IDbSavepointControl;
begin
  if AConn.QueryInterface(IDbSavepointControl, Sp) <> 0 then
  begin
    Check(False, P + ': savepoint capability available');
    Exit;
  end;
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_sp');
  AConn.Exec('CREATE TABLE ' + P + '_sp (tag TEXT)');
  WithTransaction(AConn, procedure
  begin
    AConn.Exec('INSERT INTO ' + P + '_sp VALUES (''keep'')');
    Sp.Savepoint('inner1');
    try
      AConn.Exec('INSERT INTO ' + P + '_sp VALUES (''doomed'')');
      raise ENextPasError.Create(P + ' inner boom');
    except
      Sp.RollbackTo('inner1');
      Sp.ReleaseTo('inner1');
    end;
  end);
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_sp WHERE tag = ''keep''') = 1,
    P + '/sp: keep survives');
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_sp') = 1,
    P + '/sp: partial rollback only undid inner');
  AConn.Exec('DROP TABLE ' + P + '_sp');
end;

{ ==== 8b. 批执行 ==== }

procedure RunBatchSuite(const AConn: IDbConnection; const P: string);
var
  Bx: IDbBatchExecutor;
  Steps: TDbSqlSteps;
begin
  if AConn.QueryInterface(IDbBatchExecutor, Bx) <> 0 then
  begin
    Check(False, P + ': batch capability available');
    Exit;
  end;

  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_bt');
  AConn.Exec('CREATE TABLE ' + P + '_bt (id INTEGER PRIMARY KEY, tag TEXT)');

  { 成功：三步全落 }
  Steps := TDbSqlSteps.Create(
    'INSERT INTO ' + P + '_bt VALUES (1, ''a'')',
    'INSERT INTO ' + P + '_bt VALUES (2, ''b'')',
    'INSERT INTO ' + P + '_bt VALUES (3, ''c'')');
  Bx.ExecuteBatch(Steps);
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_bt') = 3,
    P + '/batch: three steps land');

  { 原子性：第三步违约，整批回滚，新行一个不留 }
  Steps := TDbSqlSteps.Create(
    'INSERT INTO ' + P + '_bt VALUES (10, ''x1'')',
    'INSERT INTO ' + P + '_bt VALUES (11, ''x2'')',
    'INSERT INTO ' + P + '_bt VALUES (2, ''dup-pk'')');
  try
    Bx.ExecuteBatch(Steps);
    Check(False, P + '/batch: violation raised');
  except
    on E: EDbError do
      Check(E.Category = decConstraint, P + '/batch: raises constraint error');
  end;
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_bt WHERE id >= 10') = 0,
    P + '/batch: atomic rollback');

  { 空批 = 无操作成功 }
  Bx.ExecuteBatch(nil);
  Check(True, P + '/batch: empty steps no-op');

  { 嵌套：外层回滚连批内写入一起撤销 }
  try
    WithTransaction(AConn, procedure
    begin
      Steps := TDbSqlSteps.Create(
        'INSERT INTO ' + P + '_bt VALUES (20, ''nested'')');
      Bx.ExecuteBatch(Steps);
      raise ENextPasError.Create(P + ' outer boom');
    end);
  except
    on E: ENextPasError do ;
  end;
  Check(ScalarInt(AConn, 'SELECT COUNT(*) FROM ' + P + '_bt WHERE id >= 20') = 0,
    P + '/batch: nested batch rolls back with outer');

  AConn.Exec('DROP TABLE ' + P + '_bt');
end;

{ ==== 9. 迁移 ==== }

procedure RunMigrateSuite(const AConn: IDbConnection; const P: string);
var
  Migs: TDbMigrations;
  NApplied: Integer;
begin
  AConn.Exec('DROP TABLE IF EXISTS schema_migrations');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_m1');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_m2');
  Migs := MakeMigrations([
    TDbMigration.Create(1, ['CREATE TABLE ' + P + '_m1 (id INTEGER PRIMARY KEY)']),
    TDbMigration.Create(2, ['CREATE TABLE ' + P + '_m2 (v TEXT)'])
  ]);
  NApplied := Migrate(AConn, Migs);
  Check(NApplied = 2, P + '/mig: two batches applied');
  Check(MigrationVersion(AConn) = 2, P + '/mig: version = 2');
  NApplied := Migrate(AConn, Migs);
  Check(NApplied = 0, P + '/mig: idempotent rerun applies nothing');

  { 已应用版本不在列表中 = 拒绝（库超前于代码） }
  Migs := MakeMigrations([TDbMigration.Create(9,
    ['CREATE TABLE ' + P + '_m9 (x INTEGER)'])]);
  try
    Migrate(AConn, Migs);
    Check(False, P + '/mig: stale list rejected');
  except
    on E: EDbMigrateError do
      Check(True, P + '/mig: stale list rejected');
  end;
  AConn.Exec('DROP TABLE IF EXISTS schema_migrations');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_m1');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_m2');
end;

{ ==== 10. Changes 计数 ==== }

procedure RunChangesSuite(const AConn: IDbConnection; const P: string);
begin
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_chg');
  AConn.Exec('CREATE TABLE ' + P + '_chg (v INTEGER)');
  AConn.Exec('INSERT INTO ' + P + '_chg VALUES (1)');
  AConn.Exec('INSERT INTO ' + P + '_chg VALUES (2)');
  AConn.Exec('UPDATE ' + P + '_chg SET v = 3 WHERE v <= 2');
  Check(AConn.Changes = 2, P + '/changes: update counted 2');
  AConn.Exec('DELETE FROM ' + P + '_chg');
  Check(AConn.Changes = 2, P + '/changes: delete counted 2');
  AConn.Exec('DROP TABLE ' + P + '_chg');
end;

{ ==== 11. 能力矩阵自述（V3-B1）==== }

procedure RunCapabilitySuite(const AConn: IDbConnection; const P: string);
var
  Cap: IDbCapabilities;
  LBatch: IDbBatchExecutor;
  LCache: IDbStmtCacheControl;
  LLO: IDbLargeObjectControl;
  LSp: IDbSavepointControl;
  LArrQ: IDbQuery;
  LArr: IDbArrayBinding;
  LBulk: IDbBulkCopy;
  LHas: Boolean;
begin
  Cap := DbCapabilities(AConn);
  if Cap = nil then
  begin
    Check(False, P + '/caps: adapter must implement IDbCapabilities');
    Exit;
  end;
  Check(Cap.ProductName <> '', P + '/caps: product name non-empty');
  Check(Cap.ProductVersion <> '', P + '/caps: product version non-empty');
  CheckEqual(Int64(Ord(AConn.Kind)), Int64(Ord(Cap.Kind)),
    P + '/caps: kind matches connection');

  { 契约互证：布尔声明 ⇔ 可选接口 QueryInterface 存在性
    （db.intf IDbCapabilities 注记；钉死防声明漂移） }
  LHas := Supports(AConn, IDbBatchExecutor, LBatch);
  Check(LHas = Cap.SupportsBatchExecutor,
    P + '/caps: batch flag ⇔ interface presence');
  LHas := Supports(AConn, IDbStmtCacheControl, LCache);
  Check(LHas = Cap.SupportsStmtCacheControl,
    P + '/caps: stmt-cache flag ⇔ interface presence');
  LHas := Supports(AConn, IDbLargeObjectControl, LLO);
  Check(LHas = Cap.SupportsLargeObjects,
    P + '/caps: large-object flag ⇔ interface presence');
  LHas := Supports(AConn, IDbSavepointControl, LSp);
  Check(LHas = Cap.SupportsSavepoints,
    P + '/caps: savepoint flag ⇔ interface presence');
  { V3-C2：数组绑定探测对象是 IDbQuery（构造即探测，不触服务端） }
  LArrQ := AConn.Query('SELECT 1');
  Supports(LArrQ, IDbArrayBinding, LArr);
  Check((LArr <> nil) = Cap.SupportsArrayBinding,
    P + '/caps: array-binding flag ⇔ query probe presence');
  LArrQ := nil;
  LHas := Supports(AConn, IDbBulkCopy, LBulk);
  Check(LHas = Cap.SupportsBulkCopy,
    P + '/caps: bulk-copy flag ⇔ interface presence');

  { 行为验证：声明支持 savepoints ⇒ 探针保存点真实可用 }
  if Cap.SupportsSavepoints then
    WithTransaction(AConn, procedure
    begin
      LSp.Savepoint(P + '_cap_probe');
      AConn.Exec('SELECT 1');
      LSp.RollbackTo(P + '_cap_probe');
    end);
end;

{ ==== 12. 查询级选项（V3-B2）==== }

procedure RunExecOptionsSuite(const AConn: IDbConnection; const P: string);
var
  Q: IDbQuery;
  LOpts: TDbExecOptions;
begin
  { advisory 契约：任意后端接受非零 TimeoutMs 都不得报错——是否真实
    生效由各后端门禁/能力矩阵钉死（CONTRACT §2.6/§2.11）。 }
  LOpts := TDbExecOptions.Default;
  CheckEqual(Int64(LOpts.TimeoutMs), Int64(0), P + '/execopts: default zero');
  LOpts.TimeoutMs := 5000;
  AConn.Exec('SELECT 1', LOpts);
  Q := AConn.Query('SELECT 1', LOpts);
  Check(Q.Step, P + '/execopts: query-with-opts accepted');
  Q := nil;
end;

{ ==== 总控：单连接全量复跑 ==== }

procedure RunConformance(const AConn: IDbConnection; const P: string);
begin
  RunTypeRoundtrip(AConn, P);
  RunNullSuite(AConn, P);
  RunMetaSuite(AConn, P);
  RunConstraintSuite(AConn, P);
  RunSyntaxSuite(AConn, P);
  RunLiteralSuite(AConn, P);
  RunTxSuite(AConn, P);
  RunSavepointSuite(AConn, P);
  RunBatchSuite(AConn, P);
  RunMigrateSuite(AConn, P);
  RunChangesSuite(AConn, P);
  RunCapabilitySuite(AConn, P);
  RunExecOptionsSuite(AConn, P);
end;

procedure TestSqliteBackend;
var
  Conn, BConn, LConn: IDbConnection;
  Q: IDbQuery;
  Opts: TDbConnectOptions;
  LRaised: Boolean;
  LPath: string;
  Cap: IDbCapabilities;
begin
  Conn := ConnectSqlite(':memory:');
  RunConformance(Conn, 'sq');

  { V3-B1 sqlite 能力自述静态钉子 }
  Cap := DbCapabilities(Conn);
  Check(Cap <> nil, 'sqlite/caps: present');
  if Cap <> nil then
  begin
    CheckEqual('SQLite', Cap.ProductName, 'sqlite/caps: product name');
    Check(Cap.SupportsSavepoints and Cap.SupportsBatchExecutor and
      Cap.SupportsStmtCacheControl,
      'sqlite/caps: savepoints+batch+stmt-cache true');
    Check(not Cap.SupportsLargeObjects, 'sqlite/caps: no lo_* face');
    Check(not Cap.SupportsNativeBool, 'sqlite/caps: bool by affinity');
    Check(Cap.SupportsMultiStatementExec, 'sqlite/caps: multi-statement exec');
    Check(not Cap.SupportsStatementTimeout,
      'sqlite/caps: statement timeout honestly unsupported');
    Check(Cap.CaseSensitiveIdentifiers,
      'sqlite/caps: identifiers preserve case');
    CheckEqual(Int64(999), Int64(Cap.MaxPlaceholders),
      'sqlite/caps: conservative placeholder floor');
  end;

  { INC-7：busy_timeout 锁等待上限。文件库双连接争用：持锁者
    BEGIN IMMEDIATE 不提交，等待方超时后 SQLITE_BUSY 归一 decTimeout。
    （:memory: 每连接独立库无法争用，故用临时文件库。） }
  Opts := TDbConnectOptions.Default;
  Opts.BusyTimeoutMs := 50;
  LPath := GetEnvironmentVariable('TMPDIR');
  if LPath = '' then
    LPath := '/tmp';
  LPath := LPath + '/np_conf_busy_' + IntToStr(GetProcessID) + '.db';
  DeleteFile(LPath);
  BConn := ConnectSqlite(LPath, Opts);
  Q := BConn.Query('PRAGMA busy_timeout');
  Check(Q.Step and (Q.GetInt64(0) = 50),
    'sqlite/timeout: option applied as pragma value');
  Q := nil;
  LConn := ConnectSqlite(LPath);
  LConn.Exec('CREATE TABLE t_b (v INTEGER)');
  LConn.Exec('BEGIN IMMEDIATE');
  LConn.Exec('INSERT INTO t_b VALUES (1)');
  LRaised := False;
  try
    BConn.Exec('INSERT INTO t_b VALUES (2)');
  except
    on E: EDbError do
      LRaised := E.Category = decTimeout;
  end;
  Check(LRaised,
    'sqlite/timeout: busy contention surfaces as decTimeout');
  LConn.Exec('ROLLBACK');
  LConn := nil;
  BConn := nil;
  DeleteFile(LPath);
end;

procedure TestPgBackend;
var
  Conn, TConn: IDbConnection;
  Q: IDbQuery;
  Opts: TDbConnectOptions;
  LOpts: TDbExecOptions;
  LRaised: Boolean;
  LShown: string;
  Cap: IDbCapabilities;
begin
  if GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN') = '' then
  begin
    WriteLn('pg section skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectPostgres(GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN'));
  RunConformance(Conn, 't_conf_pg');

  { V3-B1 pg 能力自述静态钉子 }
  Cap := DbCapabilities(Conn);
  Check(Cap <> nil, 'pg/caps: present');
  if Cap <> nil then
  begin
    CheckEqual('PostgreSQL', Cap.ProductName, 'pg/caps: product name');
    Check(Cap.SupportsSavepoints and Cap.SupportsBatchExecutor and
      Cap.SupportsStmtCacheControl and Cap.SupportsLargeObjects,
      'pg/caps: savepoints+batch+stmt-cache+lo true');
    Check(Cap.SupportsNativeBool, 'pg/caps: native bool OID16');
    Check(Cap.SupportsMultiStatementExec, 'pg/caps: multi-statement exec');
    Check(Cap.SupportsStatementTimeout,
      'pg/caps: session statement_timeout supported');
    Check(not Cap.CaseSensitiveIdentifiers,
      'pg/caps: unquoted identifiers fold to lowercase');
    CheckEqual(Int64(65535), Int64(Cap.MaxPlaceholders),
      'pg/caps: extended-protocol placeholder limit');
  end;

  { INC-7：statement_timeout 会话级生效，触发归一 decTimeout
    （SQLSTATE 57014）。专用连接，不污染主套件连接。 }
  Opts := TDbConnectOptions.Default;
  Opts.StatementTimeoutMs := 100;
  TConn := ConnectPostgres(GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN'), Opts);
  LRaised := False;
  try
    TConn.Exec('SELECT pg_sleep(1)');
  except
    on E: EDbError do
      LRaised := E.Category = decTimeout;
  end;
  Check(LRaised, 'pg/timeout: statement_timeout surfaces as decTimeout');

  { V3-B2 查询级超时（真机）：Exec(opts) 同步窗口包裹 + Query(opts)
    存活期窗口，超时归一 decTimeout，结束后会话值恢复原值 }
  LOpts := TDbExecOptions.Default;
  LOpts.TimeoutMs := 100;
  LRaised := False;
  try
    Conn.Exec('SELECT pg_sleep(1)', LOpts);
  except
    on E: EDbError do
      LRaised := E.Category = decTimeout;
  end;
  Check(LRaised, 'pg/exectimeout: exec-level timeout decTimeout');
  Q := Conn.Query('SHOW statement_timeout');
  Check(Q.Step and (Q.GetText(0) = '0'),
    'pg/exectimeout: session restored after exec, got "' +
    Q.GetText(0) + '"');
  Q := nil;

  Q := nil;
  LRaised := False;
  try
    Q := Conn.Query('SELECT pg_sleep(1)', LOpts);
    while Q.Step do ;
    Check(False, 'pg/querytimeout: must raise');
  except
    on E: EDbError do
      LRaised := E.Category = decTimeout;
  end;
  Check(LRaised, 'pg/querytimeout: query-level timeout decTimeout');
  Q := nil;   { 触发析构恢复 }
  Q := Conn.Query('SHOW statement_timeout');
  Check(Q.Step and (Q.GetText(0) = '0'),
    'pg/querytimeout: session restored after release');
  Q := nil;
end;

procedure TestMysqlBackend;
var
  Conn: IDbConnection;
  Cap: IDbCapabilities;
begin
  if GetEnvironmentVariable('NEXTPAS_MYSQL_TEST_CONN') = '' then
  begin
    WriteLn('mysql section skipped (NEXTPAS_MYSQL_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectMysql(GetEnvironmentVariable('NEXTPAS_MYSQL_TEST_CONN'));
  RunConformance(Conn, 't_conf_my');
  Cap := DbCapabilities(Conn);
  Check(Cap <> nil, 'mysql/caps: present');
  if Cap <> nil then
  begin
    Check(Cap.SupportsSavepoints and Cap.SupportsBatchExecutor,
      'mysql/caps: savepoints+batch true');
    Check(Cap.SupportsStmtCacheControl, 'mysql/caps: stmt-cache true');
    Check(not Cap.SupportsLargeObjects, 'mysql/caps: no lo');
    Check(not Cap.SupportsArrayBinding, 'mysql/caps: no array binding');
    Check(not Cap.SupportsNativeBool, 'mysql/caps: no native bool');
    Check(Cap.SupportsMultiStatementExec, 'mysql/caps: multi-stmt true');
    CheckEqual(Int64(65535), Int64(Cap.MaxPlaceholders),
      'mysql/caps: placeholder limit');
  end;
end;

procedure TestOdbcBackend;
var
  Conn: IDbConnection;
  Cap: IDbCapabilities;
begin
  if GetEnvironmentVariable('NEXTPAS_ODBC_TEST_CONN') = '' then
  begin
    WriteLn('odbc section skipped (NEXTPAS_ODBC_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectOdbc(GetEnvironmentVariable('NEXTPAS_ODBC_TEST_CONN'));
  RunConformance(Conn, 't_conf_od');
  Cap := DbCapabilities(Conn);
  Check(Cap <> nil, 'odbc/caps: present');
  if Cap <> nil then
  begin
    Check(not Cap.SupportsSavepoints, 'odbc/caps: savepoints false honest');
    Check(Cap.SupportsBatchExecutor, 'odbc/caps: batch true');
    Check(Cap.SupportsStmtCacheControl, 'odbc/caps: stmt-cache true');
    Check(Cap.SupportsStatementTimeout, 'odbc/caps: statement timeout true');
    CheckEqual(Int64(999), Int64(Cap.MaxPlaceholders),
      'odbc/caps: conservative placeholder floor');
  end;
end;

procedure TestDmBackend;
var
  Conn: IDbConnection;
  Cap: IDbCapabilities;
begin
  if GetEnvironmentVariable('NEXTPAS_DM_TEST_CONN') = '' then
  begin
    WriteLn('dm section skipped (NEXTPAS_DM_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectDm(GetEnvironmentVariable('NEXTPAS_DM_TEST_CONN'));
  RunConformance(Conn, 't_conf_dm');
  Cap := DbCapabilities(Conn);
  Check(Cap <> nil, 'dm/caps: present');
  if Cap <> nil then
  begin
    CheckEqual('DM', Cap.ProductName, 'dm/caps: product name');
    Check(Cap.SupportsSavepoints, 'dm/caps: savepoints true (native)');
    Check(Cap.SupportsBatchExecutor, 'dm/caps: batch true');
    Check(Cap.SupportsStmtCacheControl, 'dm/caps: stmt-cache true');
    Check(not Cap.SupportsLargeObjects, 'dm/caps: no lo v1');
    Check(not Cap.SupportsArrayBinding, 'dm/caps: no array binding v1');
    CheckEqual(Int64(999), Int64(Cap.MaxPlaceholders),
      'dm/caps: conservative placeholder floor');
  end;
end;

begin
  EnsureBuiltinConf;
  T := TTestSuite.Create('nextpas.core.db.conformance');
  T.Test('sqlite backend', @TestSqliteBackend);
  T.Test('postgres backend', @TestPgBackend);
  T.Test('mysql backend', @TestMysqlBackend);
  T.Test('odbc backend', @TestOdbcBackend);
  T.Test('dm backend', @TestDmBackend);
  if not T.Run then Halt(1);
end.
