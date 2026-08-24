program test_db_odbc_adapter;

{ V3-A4 ODBC 适配器契约测试：
    1 GetInfo 常量词汇钉死（InfoType 数值 + SQL_IC_*/SQL_TC_* 结果
      词汇，防手抄错值；出处微软 ODBC SDK 头）
    2 ClassifyOdbc 归一表：约束细分精确码 / 管理器族 IM*/HY* /
      ISO 类前缀兜底 / 欠归一保持 unknown（纯离线）
    3 占位符槽位计划：顺序 ? 直通、?N 显式编号、字面量/双引号/
      方括号标识符/行注释/块注释内 ? 不计（纯离线）
    4 空 DSN fail-fast（不触库）
    5 负连接归一（真库管理器路径）：bogus DSN → 统一 EDbError，
      Backend=dbkOdbc、SqlState=IM*、Category=decConnection；
      循环多轮验证工厂异常路径句柄零泄漏（heaptrc 兜底）
    6 能力降级矩阵自洽（真库）：SupportsSavepoints=False ⇔ 无
      IDbSavepointControl、BatchExecutor=True ⇔ 接口在（B1 互证）
   live 段需真实 ODBC 数据源（NEXTPAS_ODBC_TEST_CONN），缺省静默跳过；
   含 CRUD/事务回滚/批执行/>4KB 文本截断重取往返。
  本门禁在仅有驱动管理器（unixODBC）而无任何驱动的环境即可全绿。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.err,
  nextpas.core.db,
  nextpas.core.db.odbc.base,
  nextpas.core.db.odbc.adapter;

var
  T: TTestSuite;

{ ===== 1 ===== }

procedure TestGetInfoConstants;
begin
  { InfoType 数值（sql.h/sqlext.h 微软官方值） }
  CheckEqual(Int64(SQL_DRIVER_NAME), Int64(6), 'info driver-name=6');
  CheckEqual(Int64(SQL_DRIVER_VER), Int64(7), 'info driver-ver=7');
  CheckEqual(Int64(SQL_DBMS_NAME), Int64(17), 'info dbms-name=17');
  CheckEqual(Int64(SQL_DBMS_VER), Int64(18), 'info dbms-ver=18');
  CheckEqual(Int64(SQL_IDENTIFIER_CASE), Int64(28),
    'info identifier-case=28');
  CheckEqual(Int64(SQL_IDENTIFIER_QUOTE_CHAR), Int64(29),
    'info identifier-quote-char=29');
  CheckEqual(Int64(SQL_TXN_CAPABLE), Int64(46), 'info txn-capable=46');
  CheckEqual(Int64(SQL_GETDATA_EXTENSIONS), Int64(81),
    'info getdata-extensions=81');

  { 标识符大小写词汇 }
  CheckEqual(Int64(SQL_IC_UPPER), Int64(1), 'ic upper=1');
  CheckEqual(Int64(SQL_IC_LOWER), Int64(2), 'ic lower=2');
  CheckEqual(Int64(SQL_IC_SENSITIVE), Int64(3), 'ic sensitive=3');
  CheckEqual(Int64(SQL_IC_MIXED), Int64(4), 'ic mixed=4');

  { 事务支持范围词汇——注意 TC_ALL=2 位于 DDL_COMMIT(3) 之前 }
  CheckEqual(Int64(SQL_TC_NONE), Int64(0), 'tc none=0');
  CheckEqual(Int64(SQL_TC_DML), Int64(1), 'tc dml=1');
  CheckEqual(Int64(SQL_TC_ALL), Int64(2), 'tc all=2');
  CheckEqual(Int64(SQL_TC_DDL_COMMIT), Int64(3), 'tc ddl-commit=3');
  CheckEqual(Int64(SQL_TC_DDL_IGNORE), Int64(4), 'tc ddl-ignore=4');

  { GetData 放宽位 }
  CheckEqual(Int64(SQL_GD_ANY_COLUMN), Int64($1), 'gd any-column=$1');
  CheckEqual(Int64(SQL_GD_ANY_ORDER), Int64($2), 'gd any-order=$2');
end;

{ ===== 2 ===== }

procedure ExpectCategory(const AState: string;
  const ACategory: TDbErrorCategory; const ATag: string);
var
  LCat: TDbErrorCategory;
  LCon: TDbConstraintKind;
begin
  ClassifyOdbc(AState, LCat, LCon);
  Check(LCat = ACategory,
    ATag + ': expected cat=' + IntToStr(Ord(ACategory)) +
    ' got ' + IntToStr(Ord(LCat)));
end;

procedure TestClassifyOdbcTable;
var
  LCat: TDbErrorCategory;
  LCon: TDbConstraintKind;
begin
  { 约束族精确细分（与 pg 同构子码）}
  ClassifyOdbc('23505', LCat, LCon);
  Check((LCat = decConstraint) and (LCon = dckUnique), '23505 unique');
  ClassifyOdbc('23503', LCat, LCon);
  Check((LCat = decConstraint) and (LCon = dckForeignKey), '23503 fk');
  ClassifyOdbc('23502', LCat, LCon);
  Check((LCat = decConstraint) and (LCon = dckNotNull), '23502 notnull');
  ClassifyOdbc('23514', LCat, LCon);
  Check((LCat = decConstraint) and (LCon = dckCheck), '23514 check');
  ClassifyOdbc('23000', LCat, LCon);
  Check((LCat = decConstraint) and (LCon = dckNone), '23000 generic');

  { 管理器/驱动族精确钉死 }
  ExpectCategory('IM002', decConnection, 'IM002 datasource-not-found');
  ExpectCategory('IM003', decConnection, 'IM003 driver-load-failed');
  ExpectCategory('IM001', decNotSupported, 'IM001 driver-no-function');
  ExpectCategory('HYC00', decNotSupported, 'HYC00 optional-feature');
  ExpectCategory('HY001', decCapacity, 'HY001 mem-alloc');
  ExpectCategory('HY013', decCapacity, 'HY013 mem-mgmt');
  ExpectCategory('HYT00', decTimeout, 'HYT00 timeout-expired');
  ExpectCategory('HYT01', decTimeout, 'HYT01 conn-timeout');
  ExpectCategory('HY008', decTimeout, 'HY008 canceled');

  { ISO SQLSTATE 类前缀兜底 }
  ExpectCategory('08001', decConnection, '08 client-unable-to-connect');
  ExpectCategory('08S01', decConnection, '08 comm-link-failure');
  ExpectCategory('28000', decAuth, '28 invalid-auth');
  ExpectCategory('42000', decSyntax, '42 syntax');
  ExpectCategory('42601', decSyntax, '42 pg-syntax-passthrough');
  ExpectCategory('25000', decTransaction, '25 invalid-txn-state');
  ExpectCategory('25503', decTransaction, '25 txn-state-variant');
  ExpectCategory('40000', decTransaction, '40 txn-rollback');
  ExpectCategory('0A000', decNotSupported, '0A feature-not-supported');
  ExpectCategory('53100', decCapacity, '53 disk-full');
  ExpectCategory('54000', decCapacity, '54 program-limit');
  ExpectCategory('58000', decConnection, '58 system-error');

  { 高频精确码优先于类前缀 }
  ExpectCategory('40001', decTransaction, '40001 serialization');
  ExpectCategory('57014', decTimeout, '57014 query-canceled');

  { 欠归一：数据异常/编程错误族宁可 unknown 不错归一 }
  ExpectCategory('22001', decUnknown, '22 data-exception unknown');
  ExpectCategory('HY010', decUnknown, 'HY10 func-sequence unknown');
  ExpectCategory('HY092', decUnknown, 'HY092 invalid-attr unknown');

  { 边界输入 }
  ClassifyOdbc('', LCat, LCon);
  Check((LCat = decUnknown) and (LCon = dckNone), 'empty state unknown');
  ClassifyOdbc('X', LCat, LCon);
  Check(LCat = decUnknown, 'short state unknown');
end;

{ D 线收口：flavor 感知细化（HY000+1062 缺口回归钉死） }
procedure ExpectEx(const AState: string; const ANative: Integer;
  const AMyFlavor: Boolean; const ACategory: TDbErrorCategory;
  const AConstraint: TDbConstraintKind; const ATag: string);
var
  LCat: TDbErrorCategory;
  LCon: TDbConstraintKind;
begin
  ClassifyOdbcEx(AState, ANative, AMyFlavor, LCat, LCon);
  Check((LCat = ACategory) and (LCon = AConstraint),
    ATag + ': expected cat=' + IntToStr(Ord(ACategory)) + '/con=' +
    IntToStr(Ord(AConstraint)) + ' got cat=' + IntToStr(Ord(LCat)) +
    '/con=' + IntToStr(Ord(LCon)));
end;

procedure TestClassifyOdbcExFlavor;
begin
  { 头条缺口：MySQL 系驱动 HY000+1062 → unique 约束 }
  ExpectEx('HY000', 1062, True, decConstraint, dckUnique,
    'my HY000+1062 dup-entry');

  { MySQL 码位表全族采纳（基础欠归一时）}
  ExpectEx('HY000', 1022, True, decConstraint, dckUnique,
    'my 1022 dup-key');
  ExpectEx('HY000', 1216, True, decConstraint, dckForeignKey,
    'my 1216 fk-child');
  ExpectEx('HY000', 1451, True, decConstraint, dckForeignKey,
    'my 1451 fk-parent');
  ExpectEx('HY000', 1048, True, decConstraint, dckNotNull,
    'my 1048 notnull');
  ExpectEx('HY000', 3819, True, decConstraint, dckCheck,
    'my 3819 check');
  ExpectEx('HY000', 1213, True, decTransaction, dckNone,
    'my 1213 deadlock');
  ExpectEx('HY000', 1205, True, decTimeout, dckNone,
    'my 1205 lock-wait-timeout');
  ExpectEx('HY000', 3024, True, decTimeout, dckNone,
    'my 3024 max-exec-time');
  ExpectEx('HY000', 1045, True, decAuth, dckNone,
    'my 1045 access-denied');
  ExpectEx('HY000', 1064, True, decSyntax, dckNone,
    'my 1064 parse-error');
  ExpectEx('HY000', 1146, True, decSyntax, dckNone,
    'my 1146 no-such-table');
  ExpectEx('HY000', 1235, True, decNotSupported, dckNone,
    'my 1235 not-supported-yet');
  ExpectEx('HY000', 2008, True, decCapacity, dckNone,
    'my CR 2008 out-of-memory');

  { 同类泛约束只补细分：ISO 23000 泛码 + 码位 → unique }
  ExpectEx('23000', 1062, True, decConstraint, dckUnique,
    'my 23000+1062 refine kind');

  { 永不矛盾：精确 SQLSTATE 分类不被码位覆盖 }
  ExpectEx('23505', 999999, True, decConstraint, dckUnique,
    'exact state wins over native');
  ExpectEx('40001', 1213, True, decTransaction, dckNone,
    'serialization stays, no downgrade');

  { flavor 关闭：行为与旧 ClassifyOdbc 完全一致（达梦/GBase 路径）}
  ExpectEx('HY000', 1062, False, decUnknown, dckNone,
    'no-flavor keeps under-classified');

  { flavor 开但码位不可识别：维持欠归一 }
  ExpectEx('HY000', 999999, True, decUnknown, dckNone,
    'unknown native code ignored');
  ExpectEx('HY000', -6607, True, decUnknown, dckNone,
    'negative foreign code ignored');
  ExpectEx('HY000', 0, True, decUnknown, dckNone,
    'zero native code no-op');
end;

{ ===== 3 ===== }

procedure ExpectSlots(const ASql: string; const AExpectCount: Integer;
  const AExpectSlots: array of Integer; const ATag: string);
var
  LRewritten: string;
  LSlots: TIntArray;
  I: Integer;
  LOk: Boolean;
begin
  CheckEqual(Int64(TranslatePlaceholdersOdbc(ASql, LRewritten, LSlots)),
    Int64(AExpectCount), ATag + ': slot count');
  LOk := Length(LSlots) = Length(AExpectSlots);
  if LOk then
    for I := 0 to High(AExpectSlots) do
      if LSlots[I] <> AExpectSlots[I] then
        LOk := False;
  Check(LOk, ATag + ': logical mapping');
end;

procedure TestPlaceholderPlan;
var
  LRewritten: string;
  LSlots: TIntArray;
begin
  { 顺序 ? 直通 }
  CheckEqual(Int64(TranslatePlaceholdersOdbc(
    'SELECT * FROM t WHERE a = ? AND b = ?', LRewritten, LSlots)),
    Int64(2), 'plain two placeholders');
  Check(Pos('?', LRewritten) > 0, 'rewritten keeps ? markers');

  { ?N 显式编号 → 顺序 ? + 逻辑映射 }
  ExpectSlots('INSERT INTO t VALUES (?2, ?1)', 2, [2, 1],
    'explicit numbering');

  { 字面量/标识符/注释内的 ? 不计 }
  ExpectSlots('SELECT ''a?b'' FROM t WHERE x = ?', 1, [1], 'string literal');
  ExpectSlots('SELECT "col?" FROM t WHERE x = ?', 1, [1], 'dq identifier');
  ExpectSlots('SELECT [col?] FROM t WHERE x = ?', 1, [1], 'bracket ident');
  ExpectSlots('-- hint ? here'#10'SELECT 1 WHERE x = ?', 1, [1],
    'line comment');
  ExpectSlots('/* block ? */ SELECT 1 WHERE x = ?', 1, [1],
    'block comment');

  { 混合：Seq 只对裸 ? 递增（与 pg/mysql 同构），显式 ?N 不推进。
    注意：重复逻辑号的执行层复用三后端一致不支持——服务端参数计数
    = 占位符数，未绑定物理槽一律 fail-fast（登记路线图缺口账本）}
  ExpectSlots('VALUES (?3, ?, ?1, ?)', 4, [3, 1, 1, 2], 'mixed ordering');
  ExpectSlots('VALUES (?, ?1)', 2, [1, 1], 'duplicate logical mapping');

  { 无占位符 }
  CheckEqual(Int64(TranslatePlaceholdersOdbc('SELECT 1', LRewritten,
    LSlots)), Int64(0), 'no placeholders');
end;

{ ===== 4 ===== }

procedure TestEmptyDsnFailFast;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    ConnectOdbc('');
    Check(False, 'empty dsn must raise');
  except
    on E: EDbError do
    begin
      LRaised := True;
      Check(E.Backend = dbkOdbc, 'empty dsn: backend dbkOdbc');
      Check(E.Category = decUnknown, 'empty dsn: unified-layer error');
    end;
  end;
  Check(LRaised, 'empty dsn raises');
end;

{ ===== 5 ===== }

procedure TestNegativeConnectNormalized;
var
  I: Integer;
  LRaised: Boolean;
begin
  { 真库管理器路径：unixODBC 对未知 DSN 报 IM002。
    循环多轮同时验证工厂异常路径的句柄清理（heaptrc 兜底）。 }
  for I := 1 to 8 do
  begin
    LRaised := False;
    try
      ConnectOdbc('DSN=no_such_dsn_nextpas');
      Check(False, 'bogus dsn must raise (round ' + IntToStr(I) + ')');
    except
      on E: EDbError do
      begin
        LRaised := True;
        Check(E.Backend = dbkOdbc, 'bogus dsn: backend dbkOdbc');
        Check(Pos('IM', E.SqlState) = 1,
          'bogus dsn: manager state IM*, got: ' + E.SqlState);
        Check(E.Category = decConnection,
          'bogus dsn: normalized decConnection');
        Check(E.Message <> '', 'bogus dsn: message carried');
      end;
    end;
    if not LRaised then
      Break;
  end;
  Check(LRaised, 'negative connect raised at least once');
end;

{ ===== live（env 门控）===== }

procedure TestLiveRoundtripAndCapabilities;
var
  LConnStr: string;
  Conn: IDbConnection;
  Q: IDbQuery;
  LCap: IDbCapabilities;
  LSp: IDbSavepointControl;
  LBatch: IDbBatchExecutor;
  LTx: IDbTxControl;
  LBig, LBack: string;
  LOpts: TDbExecOptions;
  I: Integer;
begin
  LConnStr := GetEnvironmentVariable('NEXTPAS_ODBC_TEST_CONN');
  if LConnStr = '' then
    Skip('no NEXTPAS_ODBC_TEST_CONN (live roundtrip skipped)');
  Conn := ConnectOdbc(LConnStr);
  Check(Conn.Kind = dbkOdbc, 'live: kind');
    Conn.Exec('DROP TABLE t_np_odbc_adapter');

    { 能力矩阵互证（B1 契约）：布尔项与可选接口存在性一致 }
    LCap := DbCapabilities(Conn);
    Check(LCap <> nil, 'live: capabilities exposed');
    if LCap <> nil then
    begin
      Check(LCap.Kind = dbkOdbc, 'live: capabilities kind');
      Check(LCap.SupportsSavepoints = False, 'live: savepoints false');
      LSp := nil;
      Supports(Conn, IDbSavepointControl, LSp);
      Check(LSp = nil,
        'live: no IDbSavepointControl (interlock with False)');
      Check(LCap.SupportsBatchExecutor = True, 'live: batch true');
      LBatch := nil;
      Supports(Conn, IDbBatchExecutor, LBatch);
      Check(LBatch <> nil,
        'live: IDbBatchExecutor present (interlock with True)');
    end;

    { DDL + 参数化 CRUD }
    Conn.Exec('CREATE TABLE t_np_odbc_adapter (' +
      'id INT NOT NULL PRIMARY KEY, name VARCHAR(8000), score DOUBLE)');
    Q := Conn.Query(
      'INSERT INTO t_np_odbc_adapter VALUES (?, ?, ?)');
    Q.BindInt64(1, 1);
    Q.BindText(2, 'alpha');
    Q.BindDouble(3, 1.5);
    Check(Q.Step = False, 'live: insert has no rows');
    Q := nil;
    Q := Conn.Query(
      'INSERT INTO t_np_odbc_adapter VALUES (?, ?, ?)');
    Q.BindInt64(1, 2);
    Q.BindNull(2);
    Q.BindInt64(3, 42);
    Check(Q.Step = False, 'live: insert 2 ok');
    Q := nil;

    Q := Conn.Query(
      'SELECT id, name, score FROM t_np_odbc_adapter WHERE id = ?');
    Q.BindInt64(1, 1);
    Check(Q.Step, 'live: select row');
    CheckEqual(Int64(Q.GetInt64(0)), Int64(1), 'live: int col');
    Check(Q.GetText(1) = 'alpha', 'live: text col');
    Check(Q.ColumnCount = 3, 'live: column count');
    Q := nil;

    { NULL 语义 }
    Q := Conn.Query(
      'SELECT name FROM t_np_odbc_adapter WHERE id = ?');
    Q.BindInt64(1, 2);
    Check(Q.Step, 'live: null row present');
    Check(Q.IsNull(0), 'live: null detected');
    Check(Q.GetText(0) = '', 'live: null reads empty');
    Q := nil;

    { >4KB 文本截断重取（GetData 整值替换假设的实证；同时覆盖
      LONGVARCHAR 参数绑定路径）}
    LBig := '';
    for I := 1 to 2100 do
      LBig := LBig + 'np';
    Check(Length(LBig) > 4000, 'live: payload > threshold');
    Q := Conn.Query(
      'UPDATE t_np_odbc_adapter SET name = ? WHERE id = ?');
    Q.BindText(1, LBig);
    Q.BindInt64(2, 1);
    Q.Step;
    Q := nil;
    Q := Conn.Query('SELECT name FROM t_np_odbc_adapter WHERE id = ?');
    Q.BindInt64(1, 1);
    Check(Q.Step, 'live: big text row');
    LBack := Q.GetText(0);
    CheckEqual(Int64(Length(LBack)), Int64(Length(LBig)),
      'live: big text length survives truncation retry');
    Check(LBack = LBig, 'live: big text content intact');
    Q := nil;

    { 事务回滚语义 }
    LTx := nil;
    Supports(Conn, IDbTxControl, LTx);
    Check(LTx <> nil, 'live: tx control present');
    if LTx <> nil then
    begin
      LTx.BeginTxn;
      Check(LTx.InTransaction, 'live: in txn after begin');
      Conn.Exec('DELETE FROM t_np_odbc_adapter');
      LTx.RollbackTxn;
      Check(LTx.InTransaction = False, 'live: txn closed after rollback');
      Q := Conn.Query('SELECT COUNT(*) FROM t_np_odbc_adapter');
      Check(Q.Step, 'live: count row');
      Check(Q.GetInt64(0) >= 1, 'live: rollback restored rows');
      Q := nil;
      LTx.BeginTxn;
      LTx.CommitTxn;
      Check(LTx.InTransaction = False, 'live: commit closes txn');
    end;

    { 批执行：单事务原子性 }
    if LBatch <> nil then
      LBatch.ExecuteBatch(TDbSqlSteps.Create(
        'DELETE FROM t_np_odbc_adapter WHERE id = 99',
        'INSERT INTO t_np_odbc_adapter (id) VALUES (99)'));

    { V3-B2 查询级选项：语句级 SQL_ATTR_QUERY_TIMEOUT 路径冒烟
      （真实超时触发依赖驱动的秒粒度计时器，通用性不足不入门禁；
      此处钉住 advisory 接受与正常往返不劣化）}
    LOpts := TDbExecOptions.Default;
    LOpts.TimeoutMs := 5000;
    Conn.Exec('SELECT COUNT(*) FROM t_np_odbc_adapter', LOpts);
    Q := Conn.Query('SELECT id FROM t_np_odbc_adapter WHERE id = ?',
      LOpts);
    Q.BindInt64(1, 1);
    Check(Q.Step, 'live: exec-opts roundtrip intact');
    Q := nil;

    Conn.Exec('DROP TABLE t_np_odbc_adapter');
  Conn := nil;   { 显式断开再入 heaptrc 检查点 }
end;

begin
  T := TTestSuite.Create('nextpas.core.db.odbc.adapter');
  T.Test('getinfo constants', @TestGetInfoConstants);
  T.Test('classify table', @TestClassifyOdbcTable);
  T.Test('classify ex flavor', @TestClassifyOdbcExFlavor);
  T.Test('placeholder plan', @TestPlaceholderPlan);
  T.Test('empty dsn fail-fast', @TestEmptyDsnFailFast);
  T.Test('negative connect normalized', @TestNegativeConnectNormalized);
  T.Test('live roundtrip and capabilities', @TestLiveRoundtripAndCapabilities);
  if not T.Run then Halt(1);
end.
