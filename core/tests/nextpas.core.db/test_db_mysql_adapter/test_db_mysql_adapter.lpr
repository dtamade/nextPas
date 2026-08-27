program test_db_mysql_adapter;

{ V3-A2 MySQL 适配器契约测试：
    1 ClassifyMy 归一表：约束双码位/事务/超时/鉴权/语法/连接族/
      容量特例/协议乱序欠归一/SQLSTATE 类兜底
    2 DSN 解析：全字段、缺省值、引号值含空格@、socket、未知键 fail-fast
    3 占位符槽位计划：顺序恒等 / ?N 重排重写 / 字面量·反引号·三种注释隔离
    4 WriteBindSlot 双方言字节级钉死：公共前四指针、buffer_type 偏移
      与宽度分叉（Oracle 68B/1B vs MariaDB 100B/4B）、is_unsigned、多槽隔离
    5 负连接归一：不存在 socket → EDbError(dbkMysql, decConnection)
    6 TDbKind 枚举序号稳定契约（dbkMysql = 尾部追加 3）
    7 真机冒烟（NEXTPAS_MYSQL_TEST_CONN 门控，缺席即 Skip）：
      roundtrip/列类型四分类/savepoint 回滚/能力自述
    8 大文本与截断（同门控）：超长插入 1406→decConstraint + 1024 字节
      Text 经 fetch_column 重取完整回取（>256 翻倍策略）
  1-6 全部离线可跑，7-8 live 门控。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.err,
  nextpas.core.db.mysql.base,
  nextpas.core.db.mysql.ffi,
  nextpas.core.db.mysql.adapter;

var
  T: TTestSuite;

{ ===== 1 ===== }

procedure ExpectMy(const ACode: Integer; const ASqlState: string;
  const ACat: TDbErrorCategory; const ADck: TDbConstraintKind;
  const ATag: string);
var
  LCat: TDbErrorCategory;
  LDck: TDbConstraintKind;
begin
  ClassifyMy(ACode, ASqlState, LCat, LDck);
  Check(LCat = ACat, ATag + ': category got ' + IntToStr(Ord(LCat)));
  Check(LDck = ADck, ATag + ': constraint got ' + IntToStr(Ord(LDck)));
end;

procedure TestClassifyMyTable;
begin
  { 约束族双码位 }
  ExpectMy(DB_MYSQL_ER_DUP_ENTRY, '23000', decConstraint, dckUnique,
    'dup-entry');
  ExpectMy(DB_MYSQL_ER_DUP_KEY, '23000', decConstraint, dckUnique,
    'dup-key');
  ExpectMy(DB_MYSQL_ER_BAD_NULL_ERROR, '23000', decConstraint, dckNotNull,
    'not-null');
  ExpectMy(DB_MYSQL_ER_NO_REFERENCED_ROW_2, '23000', decConstraint,
    dckForeignKey, 'fk-child');
  ExpectMy(DB_MYSQL_ER_ROW_IS_REFERENCED_2, '23000', decConstraint,
    dckForeignKey, 'fk-parent');
  ExpectMy(DB_MYSQL_ER_CHECK_CONSTRAINT_VIOLATED, '45000', decConstraint,
    dckCheck, 'check');
  ExpectMy(DB_MYSQL_ER_TRUNCATED_WRONG_VALUE, 'HY000', decConstraint,
    dckNone, 'truncated-wrong-value 1366');
  ExpectMy(DB_MYSQL_ER_DATA_TOO_LONG, '22001', decConstraint, dckNone,
    'data-too-long 1406');
  ExpectMy(DB_MYSQL_ER_CANT_CREATE_TABLE, 'HY000', decCapacity, dckNone,
    'cant-create-table 1005');
  ExpectMy(DB_MYSQL_ER_BAD_DB_ERROR, 'HY000', decConnection, dckNone,
    'bad-db 1049');
  ExpectMy(DB_MYSQL_ER_UNKNOWN_ERROR, 'HY000', decCapacity, dckNone,
    'unknown-error 1105');
  { 事务/超时 }
  ExpectMy(DB_MYSQL_ER_LOCK_DEADLOCK, '40001', decTransaction, dckNone,
    'deadlock');
  ExpectMy(DB_MYSQL_ER_LOCK_WAIT_TIMEOUT, 'HY000', decTimeout, dckNone,
    'lock-timeout');
  ExpectMy(DB_MYSQL_ER_QUERY_TIMEOUT, 'HY000', decTimeout, dckNone,
    'query-timeout');
  { 鉴权/语法 }
  ExpectMy(DB_MYSQL_ER_ACCESS_DENIED_ERROR, '28000', decAuth, dckNone,
    'auth');
  ExpectMy(DB_MYSQL_ER_PARSE_ERROR, '42000', decSyntax, dckNone, 'parse');
  ExpectMy(DB_MYSQL_ER_NO_SUCH_TABLE, '42S02', decSyntax, dckNone,
    'no-such-table');
  { 连接族与特例 }
  ExpectMy(CR_SERVER_GONE_ERROR, '08S01', decConnection, dckNone,
    'server-gone');
  ExpectMy(2003, '', decConnection, dckNone, 'conn-host');
  ExpectMy(CR_OUT_OF_MEMORY, 'HY001', decCapacity, dckNone, 'oom');
  ExpectMy(CR_COMMANDS_OUT_OF_SYNC, '2014', decUnknown, dckNone,
    'out-of-sync under-normalized');
  { 未识别码：SQLSTATE 类前缀兜底 }
  ExpectMy(99999, '23777', decConstraint, dckNone, 'fallback-23');
  ExpectMy(99999, '08999', decConnection, dckNone, 'fallback-08');
  { 完全未知 }
  ExpectMy(99999, 'XY000', decUnknown, dckNone, 'fully-unknown');
end;

{ ===== 2 ===== }

procedure TestDsnParsing;
var
  D: TDbMysqlDsnParts;
begin
  D := ParseMySqlDsn('host=db.local port=3307 user=root password=p@ss db=app');
  CheckEqual('db.local', D.Host, 'host');
  CheckEqual(3307, Int64(D.Port), 'port');
  CheckEqual('root', D.User, 'user');
  CheckEqual('p@ss', D.Password, 'password');
  CheckEqual('app', D.Database, 'db');

  D := ParseMySqlDsn('');
  CheckEqual('127.0.0.1', D.Host, 'default host');
  CheckEqual(3306, Int64(D.Port), 'default port');

  D := ParseMySqlDsn('password=''p@ss wd'' host=h');
  CheckEqual('p@ss wd', D.Password, 'quoted value keeps spaces/@');
  CheckEqual('h', D.Host, 'token after quoted value');

  D := ParseMySqlDsn('SOCKET=/run/mysqld.sock USER=u');
  CheckEqual('/run/mysqld.sock', D.Socket, 'keys are case-insensitive');

  try
    ParseMySqlDsn('boguskey=v');
    Check(False, 'unknown key must fail-fast');
  except
    on E: EDbError do
      Check(E.Backend = dbkMysql, 'unknown key raises dbkMysql error');
  end;
end;

{ ===== 3 ===== }

procedure TestPlaceholderSlotPlan;
var
  LOut: string;
  LSlots: TIntArray;
  LN: Integer;
begin
  LN := TranslatePlaceholdersMy('SELECT * FROM t WHERE a = ? AND b = ?',
    LOut, LSlots);
  CheckEqual(2, Int64(LN), 'sequential count');
  CheckEqual(Int64(1), Int64(LSlots[0]), 'slot0 logical');
  CheckEqual(Int64(2), Int64(LSlots[1]), 'slot1 logical');
  Check(Pos('?', LOut) > 0, '? preserved');

  LN := TranslatePlaceholdersMy('SELECT ?2 AS b, ?1 AS a', LOut, LSlots);
  CheckEqual(2, Int64(LN), 'explicit count');
  CheckEqual('SELECT ? AS b, ? AS a', LOut, '?N rewritten to plain ?');
  CheckEqual(Int64(2), Int64(LSlots[0]), '?2 maps to logical 2');
  CheckEqual(Int64(1), Int64(LSlots[1]), '?1 maps to logical 1');

  LN := TranslatePlaceholdersMy(
    'SELECT ''what?'' AS s, `col?name` FROM t /* q? */ WHERE x = ?1 AND y = ?1',
    LOut, LSlots);
  CheckEqual(2, Int64(LN), 'literal/backtick/comment ? ignored; reuse counts');
  CheckEqual(Int64(1), Int64(LSlots[0]), 'reuse slot0');
  CheckEqual(Int64(1), Int64(LSlots[1]), 'reuse slot1');

  LN := TranslatePlaceholdersMy('-- hint ?'#10'# also ?'#10'SELECT ?',
    LOut, LSlots);
  CheckEqual(1, Int64(LN), '-- and # line comments isolate ?');
end;

{ ===== 4 ===== }

procedure TestWriteBindSlotBothFlavors;
var
  LBlock: Pointer;
  LBuf: array[0..7] of Byte;
  LLen: QWord;
  LNullFlag: Boolean;
begin
  LLen := 42;
  FillChar(LBuf, SizeOf(LBuf), $AB);

  { Oracle 布局 }
  GetMem(LBlock, 2 * SIZE_MYSQL_BIND_MYSQL);
  try
    FillChar(LBlock^, SizeUInt(2 * SIZE_MYSQL_BIND_MYSQL), 0);
    WriteBindSlot(LBlock, 0, SIZE_MYSQL_BIND_MYSQL, MYSQL_TYPE_LONGLONG,
      @LBuf[0], SizeOf(LBuf), nil, nil, @LLen, False);
    Check(PPointer(LBlock)^ = @LLen, 'oracle: length@0');
    Check(PPointer(PByte(LBlock) + 16)^ = @LBuf[0], 'oracle: buffer@16');
    Check(PQWord(PByte(LBlock) + 40)^ = QWord(SizeOf(LBuf)),
      'oracle: buffer_length@40');
    Check((PByte(LBlock) + 68)^ = Byte(MYSQL_TYPE_LONGLONG),
      'oracle: buffer_type@68 as 1 byte');
    Check((PByte(LBlock) + 70)^ = 0, 'oracle: is_unsigned@70 off');
    { 第二槽零值隔离：槽 0 写入不污染槽 1 }
    Check(PQWord(PByte(LBlock) + SIZE_MYSQL_BIND_MYSQL + 40)^ = 0,
      'oracle: slot1 untouched');

    FillChar(LBlock^, SizeUInt(2 * SIZE_MYSQL_BIND_MYSQL), 0);
    WriteBindSlot(LBlock, 1, SIZE_MYSQL_BIND_MYSQL, MYSQL_TYPE_VAR_STRING,
      @LBuf[0], SizeOf(LBuf), nil, nil, @LLen, True);
    Check((PByte(LBlock) + SIZE_MYSQL_BIND_MYSQL + 68)^ =
      Byte(MYSQL_TYPE_VAR_STRING), 'oracle: slot1 type written at own base');
    Check((PByte(LBlock) + SIZE_MYSQL_BIND_MYSQL + 70)^ = 1,
      'oracle: is_unsigned set');
  finally
    FreeMem(LBlock);
  end;

  { MariaDB 布局 — 112 字节，实测偏移 64/96/101（见 ffi.pas） }
  GetMem(LBlock, 2 * SIZE_MYSQL_BIND_MARIADB);
  try
    FillChar(LBlock^, SizeUInt(2 * SIZE_MYSQL_BIND_MARIADB), 0);
    LNullFlag := False;
    WriteBindSlot(LBlock, 0, SIZE_MYSQL_BIND_MARIADB,
      MYSQL_TYPE_LONGLONG, @LBuf[0], SizeOf(LBuf), @LNullFlag, nil,
      @LLen, False);
    Check(PPointer(LBlock)^ = @LLen, 'mariadb: length@0 shared prefix');
    Check(PPointer(PByte(LBlock) + 8)^ = @LNullFlag,
      'mariadb: is_null@8 shared prefix');
    Check(PQWord(PByte(LBlock) + 64)^ = QWord(SizeOf(LBuf)),
      'mariadb: buffer_length@64');
    Check(PCardinal(PByte(LBlock) + 96)^ = MYSQL_TYPE_LONGLONG,
      'mariadb: buffer_type@96 as 4-byte enum');
    Check((PByte(LBlock) + 101)^ = 0, 'mariadb: is_unsigned@101 off');

    FillChar(LBlock^, SizeUInt(2 * SIZE_MYSQL_BIND_MARIADB), 0);
    WriteBindSlot(LBlock, 0, SIZE_MYSQL_BIND_MARIADB, MYSQL_TYPE_NULL,
      nil, 0, @LNullFlag, nil, @LLen, False);
    Check(PCardinal(PByte(LBlock) + 96)^ = MYSQL_TYPE_NULL,
      'mariadb: null param type');
    Check(PPointer(PByte(LBlock) + 8)^ = @LNullFlag,
      'mariadb: null flag pointer set');
  finally
    FreeMem(LBlock);
  end;
end;

{ ===== 5 ===== }

procedure TestNegativeConnectNormalized;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    ConnectMysql('socket=/nonexistent/np-a2-test.sock user=nextpas');
  except
    on E: EDbError do
    begin
      LRaised := True;
      Check(E.Backend = dbkMysql, 'backend = dbkMysql');
      Check(E.Category = decConnection,
        'negative connect normalizes to decConnection, got ' +
        IntToStr(Ord(E.Category)));
      Check(E.Message <> '', 'message carries mysql diagnostics');
      Check(Length(E.SqlState) <= 5, 'sqlstate length legal');
    end;
  end;
  Check(LRaised, 'negative connect raises');
end;

{ ===== 6 ===== }

procedure TestDbkMysqlOrdinalStable;
begin
  { 尾部追加契约：既有消费方 switch 序号不被扰动 }
  CheckEqual(Int64(0), Int64(Ord(dbkUnknown)), 'ordinal unknown');
  CheckEqual(Int64(1), Int64(Ord(dbkSqlite)), 'ordinal sqlite');
  CheckEqual(Int64(2), Int64(Ord(dbkPostgres)), 'ordinal postgres');
  CheckEqual(Int64(3), Int64(Ord(dbkMysql)), 'ordinal mysql tail-appended');
  CheckEqual(Int64(4), Int64(Ord(dbkOdbc)), 'ordinal odbc tail-appended (A4)');
end;

{ ===== 7 ===== }

procedure TestLiveRoundtripSmoke;
var
  LEnv: string;
  Conn: IDbConnection;
  Q: IDbQuery;
  LBlob, LBlobBack: TBytes;
  LSp: IDbSavepointControl;
  LCap: IDbCapabilities;
  LOpts: TDbExecOptions;
begin
  LEnv := GetEnvironmentVariable('NEXTPAS_MYSQL_TEST_CONN');
  if LEnv = '' then
    Skip('no NEXTPAS_MYSQL_TEST_CONN (live smoke skipped)');
  Conn := ConnectMysql(LEnv);
  try
    Check(Conn.Kind = dbkMysql, 'live: kind');
    Conn.Exec('DROP TABLE IF EXISTS t_my_adapter');
    Conn.Exec('CREATE TABLE t_my_adapter (' +
      'id INT NOT NULL PRIMARY KEY, name VARCHAR(64), ' +
      'score DOUBLE, data VARBINARY(32))');

    { 参数化插入走 prepared stmt }
    SetLength(LBlob, 3);
    LBlob[0] := 1; LBlob[1] := 2; LBlob[2] := 3;
    WithTransaction(Conn, procedure
    begin
      Q := Conn.Query(
        'INSERT INTO t_my_adapter VALUES (?1, ?2, ?3, ?4)');
      try
        Q.BindInt64(1, 1);
        Q.BindText(2, 'alice');
        Q.BindDouble(3, 2.5);
        Q.BindBlob(4, LBlob);
        Check(not Q.Step, 'insert yields no rows');
      finally
        Q := nil;
      end;
    end);

    Q := Conn.Query(
      'SELECT id, name, score, data FROM t_my_adapter WHERE id = ?');
    try
      Q.BindInt64(1, 1);
      Check(Q.Step, 'live: row present');
      Check(Q.ColumnCount = 4, 'live: column count');
      CheckEqual(Int64(Ord(dbcInteger)), Int64(Ord(Q.ColumnType(0))),
        'live: int col type');
      CheckEqual(Int64(Ord(dbcText)), Int64(Ord(Q.ColumnType(1))),
        'live: text col type');
      CheckEqual(Int64(Ord(dbcFloat)), Int64(Ord(Q.ColumnType(2))),
        'live: float col type');
      CheckEqual(Int64(Ord(dbcBlob)), Int64(Ord(Q.ColumnType(3))),
        'live: blob col type');
      CheckEqual(Int64(1), Q.GetInt64(0), 'live: int roundtrip');
      CheckEqual('alice', Q.GetText(1), 'live: text roundtrip');
      Check(Abs(Q.GetDouble(2) - 2.5) < 1e-9, 'live: double roundtrip');
      LBlobBack := Q.GetBlob(3);
      Check(Length(LBlobBack) = 3, 'live: blob length');
      Check((Length(LBlobBack) = 3) and (LBlobBack[2] = 3),
        'live: blob content');
      Check(not Q.IsNull(1), 'live: non-null via IsNull');
      Check(not Q.Step, 'live: single row');
    finally
      Q := nil;
    end;

    { savepoint 回滚语义 }
    LSp := Conn as IDbSavepointControl;
    WithTransaction(Conn, procedure
    begin
      LSp.Savepoint('sp_a2');
      Conn.Exec('DELETE FROM t_my_adapter');
      LSp.RollbackTo('sp_a2');
    end);
    Q := Conn.Query('SELECT COUNT(*) FROM t_my_adapter');
    try
      Check(Q.Step, 'savepoint: count row');
      CheckEqual(Int64(1), Q.GetInt64(0), 'savepoint: rollback kept row');
    finally
      Q := nil;
    end;

    { V3-B2 查询级选项：Exec(opts)/Query(opts) advisory 冒烟——
      Oracle ≥8.0 经 max_execution_time 真实应用，MariaDB/旧服务端
      静默忽略（能力矩阵登记），两者都不得报错 }
    LOpts := TDbExecOptions.Default;
    LOpts.TimeoutMs := 5000;
    Conn.Exec('SELECT 1', LOpts);
    Q := Conn.Query('SELECT 1', LOpts);
    try
      Check(Q.Step, 'live/execopts: query-with-opts accepted');
    finally
      Q := nil;
    end;

    { V3-B1 能力自述（真机段）：静态值 + 契约互证 }
    LCap := DbCapabilities(Conn);
    Check(LCap <> nil, 'live/caps: present');
    if LCap <> nil then
    begin
      CheckEqual(Int64(Ord(dbkMysql)), Int64(Ord(LCap.Kind)),
        'live/caps: kind');
      Check((LCap.ProductName = 'MySQL') or (LCap.ProductName = 'MariaDB'),
        'live/caps: product name by flavor: ' + LCap.ProductName);
      Check(LCap.ProductVersion <> '', 'live/caps: version non-empty');
      Check(LCap.SupportsSavepoints and LCap.SupportsBatchExecutor and
        LCap.SupportsMultiStatementExec, 'live/caps: core faces true');
      Check(not LCap.SupportsStmtCacheControl,
        'live/caps: stmt cache not yet wired');
      Check(not LCap.SupportsLargeObjects, 'live/caps: no lo face');
      Check(not LCap.SupportsNativeBool, 'live/caps: TINYINT(1) convention');
      Check(not LCap.CaseSensitiveIdentifiers,
        'live/caps: column names insensitive');

      { 语句超时能力：MariaDB 确定不支持（max_statement_time 未接）；
        Oracle 库由建连期按 server 版本定格，此处不重复解析版本串 }
      if LCap.ProductName = 'MariaDB' then
        Check(not LCap.SupportsStatementTimeout,
          'live/caps: mariadb statement timeout honestly unsupported');
    end;

    Conn.Exec('DROP TABLE IF EXISTS t_my_adapter');
  finally
    Conn := nil;
  end;
end;

procedure TestLiveTruncationAndLargeText;
var
  LEnv: string;
  Conn: IDbConnection;
  Q: IDbQuery;
  LLong: string;
  LGot: string;
  LRaised: Boolean;
begin
  LEnv := GetEnvironmentVariable('NEXTPAS_MYSQL_TEST_CONN');
  if LEnv = '' then
    Skip('no NEXTPAS_MYSQL_TEST_CONN (live truncation skipped)');
  Conn := ConnectMysql(LEnv);
  try
    { 超长截断 → 1406/1366 归一 decConstraint（STRICT_TRANS_TABLES 默认开启） }
    Conn.Exec('DROP TABLE IF EXISTS t_my_trunc');
    Conn.Exec('CREATE TABLE t_my_trunc (id INT PRIMARY KEY, s VARCHAR(5))');
    Conn.Exec('DELETE FROM t_my_trunc');
    LRaised := False;
    try
      Q := Conn.Query('INSERT INTO t_my_trunc VALUES (?, ?)');
      try
        Q.BindInt64(1, 1);
        Q.BindText(2, '1234567890'); { 10 chars > 5, expect 1406 }
        Q.Step;
      finally
        Q := nil;
      end;
    except
      on E: EDbError do
      begin
        LRaised := True;
        Check(E.Category = decConstraint,
          'truncation maps to decConstraint, got ' + IntToStr(Ord(E.Category)));
        Check((E.BackendCode = 1406) or (E.BackendCode = 1366),
          'truncation code 1406/1366, got ' + IntToStr(E.BackendCode));
      end;
    end;
    Check(LRaised, 'overlong insert raises decConstraint');

    { 大文本 fetch 截断重取：> MY_BUF_INITIAL(256) 经 fetch_column 完整回取 }
    Conn.Exec('DROP TABLE IF EXISTS t_my_big');
    Conn.Exec('CREATE TABLE t_my_big (id INT PRIMARY KEY, t TEXT)');
    LLong := StringOfChar('x', 1024);
    Q := Conn.Query('INSERT INTO t_my_big VALUES (?, ?)');
    try
      Q.BindInt64(1, 1);
      Q.BindText(2, LLong);
      Q.Step;
    finally
      Q := nil;
    end;
    Q := Conn.Query('SELECT t FROM t_my_big WHERE id = ?');
    try
      Q.BindInt64(1, 1);
      Check(Q.Step, 'big text row present');
      CheckEqual(Int64(Ord(dbcText)), Int64(Ord(Q.ColumnType(0))), 'big text type');
      LGot := Q.GetText(0);
      CheckEqual(Int64(Length(LLong)), Int64(Length(LGot)), 'big text length via refetch');
      Check(LGot = LLong, 'big text content via refetch');
    finally
      Q := nil;
    end;
    Conn.Exec('DROP TABLE IF EXISTS t_my_trunc');
    Conn.Exec('DROP TABLE IF EXISTS t_my_big');
  finally
    Conn := nil;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.db.mysql.adapter');
  T.Test('ClassifyMy normalization table', @TestClassifyMyTable);
  T.Test('dsn parsing', @TestDsnParsing);
  T.Test('placeholder slot plan', @TestPlaceholderSlotPlan);
  T.Test('bind marshaling both flavors', @TestWriteBindSlotBothFlavors);
  T.Test('negative connect normalized', @TestNegativeConnectNormalized);
  T.Test('TDbKind ordinal stable', @TestDbkMysqlOrdinalStable);
  T.Test('live roundtrip smoke', @TestLiveRoundtripSmoke);
  T.Test('live truncation and large-text refetch', @TestLiveTruncationAndLargeText);
  if not T.Run then Halt(1);
end.
