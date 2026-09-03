program test_db_mysql;

{ V3-A1 MySQL 基础三件套契约测试（base/ffi/loader）：
    1 库加载与符号解析：候选表首个命中者绑定，客户端版本可读
    2 方言识别：库名含 mariadb 则 flavor=mfMariadb，否则 mfMysql
    3 幂等加载：二次 EnsureLoaded 不换库不重绑
    4 负连接路径：init/options/real_connect(不存在 socket)/errno 落在
      CR_* 客户端错误族 + 消息非空 + SQLSTATE 长度合法，close 干净
    5 EMySqlError 三元组往返（code/sqlstate/message）
    6 ABI 声明尺寸钉死：MYSQL_FIELD=128、双方言 BIND=72/120，防漂移
    7 stmt 生命周期：未连服句柄上 init/close 纯客户端分配即可用
  全部用例无需运行中的 MySQL/MariaDB 服务；真机 conformance 随 A2
  adapter 经 NEXTPAS_MYSQL_TEST_CONN 门控。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db.mysql.base,
  nextpas.core.db.mysql.ffi,
  nextpas.core.db.mysql.loader;

var
  T: TTestSuite;
  GName: string;

{ 对不存在 socket 发起真实负连接，收集诊断三元组后干净关闭。
  不依赖任何服务器：失败发生在客户端传输层。 }
procedure CollectNegativeDiagnostics(out AErrno: Cardinal;
  out AMsg, ASqlState: string);
var
  H: TMysql;
begin
  AErrno := 0;
  AMsg := '';
  ASqlState := '';
  H := my_init(nil);
  if H = nil then
  begin
    Check(False, 'mysql_init returned nil');
    Exit;
  end;
  try
    if my_realConnect(H, nil, 'nextpas', '', '', 0,
      '/nonexistent/np-mysql-test.sock', 0) <> nil then
      Check(False, 'connect to nonexistent socket unexpectedly succeeded');
    AErrno := my_errno(H);
    AMsg := string(AnsiString(my_error(H)));
    ASqlState := string(AnsiString(my_sqlstate(H)));
  finally
    my_close(H);
  end;
end;

{ ===== 1 ===== }

procedure TestLoadAndResolveSymbols;
begin
  MySqlEnsureLoaded;
  Check(MySqlLoaded, 'loader reports loaded');
  GName := MySqlLibraryName;
  Check(GName <> '', 'library name recorded');
  Check(Pos('.so', GName) > 0, 'library name is a soname: ' + GName);
  Check(MySqlClientVersion > 0, 'client version positive');
end;

{ ===== 2 ===== }

procedure TestFlavorDetectionConsistent;
var
  F: TMysqlFlavor;
begin
  MySqlEnsureLoaded;
  F := MySqlFlavor;
  Check(F in [mfMysql, mfMariadb], 'flavor detected (not unknown)');
  if Pos('mariadb', GName) > 0 then
    Check(F = mfMariadb, 'mariadb soname implies mfMariadb')
  else
    Check(F = mfMysql, 'non-mariadb soname implies mfMysql');
end;

{ ===== 3 ===== }

procedure TestIdempotentLoad;
var
  LName: string;
begin
  MySqlEnsureLoaded;
  LName := MySqlLibraryName;
  MySqlEnsureLoaded;
  Check(MySqlLibraryName = LName, 'second load keeps same library');
  Check(MySqlClientVersion > 0, 'symbols still bound after re-entry');
end;

{ ===== 4 ===== }

procedure TestFailedConnectClientErrorFamily;
var
  LErrno: Cardinal;
  LMsg: string;
  LSs: string;
begin
  MySqlEnsureLoaded;
  CollectNegativeDiagnostics(LErrno, LMsg, LSs);
  Check((LErrno >= CR_MIN_ERROR) and (LErrno <= CR_MAX_ERROR),
    'negative connect lands in CR_* client family, got ' + IntToStr(LErrno));
  Check(LErrno <> CR_UNKNOWN_ERROR, 'error code is specific, not unknown');
  Check(LMsg <> '', 'mysql_error text non-empty');
  Check(Length(LSs) <= 5, 'sqlstate length legal');
end;

{ ===== 5 ===== }

procedure TestMySqlErrorTripleRoundtrip;
var
  LRaised: Boolean;
  LBare: EMySqlError;
begin
  LRaised := False;
  try
    raise EMySqlError.Create('deadlock simulated', ER_LOCK_DEADLOCK, '40001');
  except
    on E: EMySqlError do
    begin
      LRaised := True;
      CheckEqual(Int64(ER_LOCK_DEADLOCK), Int64(E.ErrorCode), 'code roundtrip');
      CheckEqual('40001', E.SqlState, 'sqlstate roundtrip');
      CheckEqual('deadlock simulated', E.Message, 'message roundtrip');
    end;
  end;
  Check(LRaised, 'EMySqlError raised and caught as itself');
  { 异常对象非引用计数：不 raise 的实例须手动释放，防孤儿 }
  LBare := EMySqlError.Create('bare');
  try
    CheckEqual(Int64(0), Int64(LBare.ErrorCode), 'default code is zero');
  finally
    LBare.Free;
  end;
end;

{ ===== 6 ===== }

procedure TestAbiDeclarationSizesPinned;
begin
  CheckEqual(Int64(SizeOf(TMysqlFieldRec)), Int64(128),
    'sizeof MYSQL_FIELD mirror = 128');
  CheckEqual(Int64(SizeOf(TMysqlBindMysql)), Int64(SIZE_MYSQL_BIND_MYSQL),
    'sizeof Oracle BIND mirror');
  CheckEqual(Int64(SizeOf(TMysqlBindMariadb)), Int64(SIZE_MYSQL_BIND_MARIADB),
    'sizeof MariaDB BIND mirror');
end;

{ ===== 7 ===== }

procedure TestStmtLifecycleWithoutServer;
var
  H: TMysql;
  S: TMysqlStmt;
begin
  MySqlEnsureLoaded;
  H := my_init(nil);
  if H = nil then
  begin
    Check(False, 'mysql_init returned nil');
    Exit;
  end;
  try
    S := my_stmtInit(H);
    if S = nil then
    begin
      Check(False, 'mysql_stmt_init returned nil');
      Exit;
    end;
    try
      { 未连服务器：param_count 走纯客户端元数据，应为 0 }
      Check(my_stmtParamCount(S) = 0, 'fresh stmt has zero params');
      { prepare 需发 COM_STMT_PREPARE 到服务器，无传输必败且 errno 落在
        客户端错误族——两家方言一致的确定性路径 }
      Check(my_stmtPrepare(S, 'SELECT 1', 8) <> 0,
        'prepare on unconnected handle fails');
      Check(my_stmtErrno(S) >= CR_MIN_ERROR, 'stmt errno in client family');
    finally
      { close 返回值两家对未 prepare stmt 行为不同，不作断言；只保证释放 }
      my_stmtClose(S);
    end;
  finally
    my_close(H);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.db.mysql.loader');
  T.Test('load and resolve symbols', @TestLoadAndResolveSymbols);
  T.Test('flavor detection consistent', @TestFlavorDetectionConsistent);
  T.Test('idempotent load', @TestIdempotentLoad);
  T.Test('failed connect yields client error family',
    @TestFailedConnectClientErrorFamily);
  T.Test('EMySqlError triple roundtrip', @TestMySqlErrorTripleRoundtrip);
  T.Test('ABI declaration sizes pinned', @TestAbiDeclarationSizesPinned);
  T.Test('stmt lifecycle without server', @TestStmtLifecycleWithoutServer);
  if not T.Run then Halt(1);
end.
