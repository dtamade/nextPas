program test_db_odbc_base;

{ V3-A3 ODBC base/ffi/loader 契约测试：
    1 常量词汇：返回码/句柄类型/C 绑定类型偏移算术（纯离线）
    2 加载幂等：EnsureLoaded 二次调用无副作用，库名非空
    3 ENV 句柄生命周期（真库）：Alloc→SetEnvAttr(OV_ODBC3)→Free
    4 DBC 句柄生命周期（真库）：Alloc/SetConnectAttr/Free；未连接时
      管理器层属性存储合法
    5 诊断归一（真库）：bogus DSN 连接失败 → SQLGetDiagRec 取得 IM*
      SQLSTATE → OdbcRaise 抛 EDbOdbcError 带 SqlState
    6 无效句柄防御：FreeHandle(nil) 返回 SQL_INVALID_HANDLE 不崩溃
    7 EndTran 未连接容错：错误路径可诊断、不泄漏不崩溃
    live 段需真实 ODBC 数据源（NEXTPAS_ODBC_TEST_CONN），缺省静默跳过。
  本门禁在仅有驱动管理器（unixODBC）而无任何驱动的环境即可全绿。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.db.odbc.base,
  nextpas.core.db.odbc.ffi,
  nextpas.core.db.odbc.loader;

var
  T: TTestSuite;

{ ===== 1 ===== }

procedure TestConstantVocabulary;
begin
  { 返回码 }
  CheckEqual(Int64(SQL_SUCCESS), Int64(0), 'retcode success');
  CheckEqual(Int64(SQL_SUCCESS_WITH_INFO), Int64(1), 'retcode with-info');
  CheckEqual(Int64(SQL_NO_DATA), Int64(100), 'retcode no-data');
  CheckEqual(Int64(SQL_ERROR), Int64(-1), 'retcode error');
  CheckEqual(Int64(SQL_INVALID_HANDLE), Int64(-2), 'retcode invalid-handle');

  { 句柄类型 }
  CheckEqual(Int64(SQL_HANDLE_ENV), Int64(1), 'handle env');
  CheckEqual(Int64(SQL_HANDLE_DBC), Int64(2), 'handle dbc');
  CheckEqual(Int64(SQL_HANDLE_STMT), Int64(3), 'handle stmt');

  { C 类型 = 基型 + offset（sql.h 算术，防手抄错值） }
  CheckEqual(Int64(SQL_C_CHAR), Int64(1), 'c-type char');
  CheckEqual(Int64(SQL_C_SLONG), Int64(-16), 'c-type slong');
  CheckEqual(Int64(SQL_C_ULONG), Int64(-18), 'c-type ulong');
  CheckEqual(Int64(SQL_C_SBIGINT), Int64(-25), 'c-type sbigint');
  CheckEqual(Int64(SQL_C_UBIGINT), Int64(-27), 'c-type ubigint');
  CheckEqual(Int64(SQL_C_STINYINT), Int64(-26), 'c-type stinyint');

  { 长度指示符 }
  CheckEqual(Int64(SQL_NULL_DATA), Int64(-1), 'len null-data');
  CheckEqual(Int64(SQL_NTS), Int64(-3), 'len nts');

  { ABI 尺寸假设（LP64） }
  CheckEqual(Int64(SizeOf(SmallInt)), Int64(2), 'abi sqlreturn=2bytes');
  CheckEqual(Int64(SizeOf(Integer)), Int64(4), 'abi sqlinteger=4bytes');
  CheckEqual(Int64(SizeOf(Int64)), Int64(8), 'abi sqllen=8bytes');
end;

{ ===== 2 ===== }

procedure TestLoaderIdempotent;
var
  LName1: string;
begin
  OdbcEnsureLoaded;
  LName1 := OdbcLibraryName;
  Check(LName1 <> '', 'loader: library name recorded');
  OdbcEnsureLoaded;                      { 幂等 }
  Check(OdbcLibraryName = LName1, 'loader: idempotent, same library');
  Check(OdbcLoaded, 'loader: loaded flag set');
end;

{ ===== 3 ===== }

procedure TestEnvHandleLifecycle;
var
  LEnv: Pointer;
  LRC: SmallInt;
begin
  OdbcEnsureLoaded;
  LEnv := nil;
  LRC := sql_allocHandle(SQL_HANDLE_ENV, nil, LEnv);
  if LRC <> SQL_SUCCESS then
    OdbcRaise(SQL_HANDLE_ENV, nil, LRC, 'alloc env');
  try
    Check(LEnv <> nil, 'env: handle allocated');
    LRC := sql_setEnvAttr(LEnv, SQL_ATTR_ODBC_VERSION,
      Pointer(PtrInt(SQL_OV_ODBC3)), 0);
    if (LRC <> SQL_SUCCESS) and (LRC <> SQL_SUCCESS_WITH_INFO) then
      OdbcRaise(SQL_HANDLE_ENV, LEnv, LRC, 'set odbc3 version');
  finally
    LRC := sql_freeHandle(SQL_HANDLE_ENV, LEnv);
    CheckEqual(Int64(LRC), Int64(SQL_SUCCESS), 'env: free returns success');
  end;
end;

{ ===== 4 ===== }

procedure TestDbcHandleLifecycle;
var
  LEnv: Pointer;
  LDbc: Pointer;
  LRC: SmallInt;
begin
  OdbcEnsureLoaded;
  LEnv := nil;
  LDbc := nil;
  if sql_allocHandle(SQL_HANDLE_ENV, nil, LEnv) <> SQL_SUCCESS then
    Check(False, 'env alloc failed');
  try
    sql_setEnvAttr(LEnv, SQL_ATTR_ODBC_VERSION,
      Pointer(PtrInt(SQL_OV_ODBC3)), 0);
    LRC := sql_allocHandle(SQL_HANDLE_DBC, LEnv, LDbc);
    if LRC <> SQL_SUCCESS then
      OdbcRaise(SQL_HANDLE_ENV, LEnv, LRC, 'alloc dbc');
    try
      Check(LDbc <> nil, 'dbc: handle allocated');
      { 未连接 DBC 上设管理器层属性：unixODBC 先存后转发 }
      LRC := sql_setConnectAttr(LDbc, SQL_ATTR_LOGIN_TIMEOUT,
        Pointer(PtrInt(5)), 0);
      Check((LRC = SQL_SUCCESS) or (LRC = SQL_SUCCESS_WITH_INFO),
        Format('dbc: login timeout attr accepted on unconnected dbc (%d)',
          [LRC]));
    finally
      LRC := sql_freeHandle(SQL_HANDLE_DBC, LDbc);
      CheckEqual(Int64(LRC), Int64(SQL_SUCCESS), 'dbc: free returns success');
    end;
  finally
    sql_freeHandle(SQL_HANDLE_ENV, LEnv);
  end;
end;

{ ===== 5 ===== }

procedure TestDiagnosticsRealPath;
var
  LEnv: Pointer;
  LDbc: Pointer;
  LRC: SmallInt;
  LDummyOut: SmallInt;
  LRaised: Boolean;
begin
  OdbcEnsureLoaded;
  LEnv := nil;
  LDbc := nil;
  if sql_allocHandle(SQL_HANDLE_ENV, nil, LEnv) <> SQL_SUCCESS then
    Check(False, 'env alloc failed');
  try
    sql_setEnvAttr(LEnv, SQL_ATTR_ODBC_VERSION,
      Pointer(PtrInt(SQL_OV_ODBC3)), 0);
    sql_allocHandle(SQL_HANDLE_DBC, LEnv, LDbc);
    try
      LRaised := False;
      try
        LRC := sql_driverConnect(LDbc, nil, 'DSN=no_such_dsn_nextpas',
          SQL_NTS, nil, 0, LDummyOut, SQL_DRIVER_NOPROMPT);
        if LRC <> SQL_SUCCESS then
          OdbcRaise(SQL_HANDLE_DBC, LDbc, LRC, 'driverconnect bogus dsn');
        Check(False, 'bogus dsn connect should not succeed');
      except
        on E: EDbOdbcError do
        begin
          LRaised := True;
          Check(Pos('IM', E.SqlState) = 1,
            'diag: manager-level state prefix IM, got: ' + E.SqlState);
          Check(E.Message <> '', 'diag: message carried');
        end;
      end;
      Check(LRaised, 'diag: bogus dsn raised EDbOdbcError');
    finally
      sql_freeHandle(SQL_HANDLE_DBC, LDbc);
    end;
  finally
    sql_freeHandle(SQL_HANDLE_ENV, LEnv);
  end;
end;

{ ===== 6 ===== }

procedure TestInvalidHandleDefense;
var
  LRC: SmallInt;
begin
  OdbcEnsureLoaded;
  LRC := sql_freeHandle(SQL_HANDLE_STMT, nil);
  CheckEqual(Int64(LRC), Int64(SQL_INVALID_HANDLE),
    'defense: free(nil stmt) = invalid handle');
  LRC := sql_fetch(nil);
  CheckEqual(Int64(LRC), Int64(SQL_INVALID_HANDLE),
    'defense: fetch(nil) = invalid handle');
end;

{ ===== 7 ===== }

procedure TestEndTranUnconnectedTolerant;
var
  LEnv: Pointer;
  LDbc: Pointer;
  LRC: SmallInt;
  LDiag: TOdbcDiagRecs;
begin
  OdbcEnsureLoaded;
  LEnv := nil;
  LDbc := nil;
  if sql_allocHandle(SQL_HANDLE_ENV, nil, LEnv) <> SQL_SUCCESS then
    Check(False, 'env alloc failed');
  try
    sql_setEnvAttr(LEnv, SQL_ATTR_ODBC_VERSION,
      Pointer(PtrInt(SQL_OV_ODBC3)), 0);
    if sql_allocHandle(SQL_HANDLE_DBC, LEnv, LDbc) <> SQL_SUCCESS then
      Check(False, 'dbc alloc failed');
    try
      LRC := sql_endTran(SQL_HANDLE_DBC, LDbc, SQL_COMMIT);
      Check((LRC = SQL_ERROR) or (LRC = SQL_INVALID_HANDLE) or
        (LRC = SQL_SUCCESS) or (LRC = SQL_SUCCESS_WITH_INFO),
        'endtran: retcode in known set');
      if (LRC = SQL_ERROR) or (LRC = SQL_SUCCESS_WITH_INFO) then
      begin
        LDiag := OdbcDiag(SQL_HANDLE_DBC, LDbc);
        Check(Length(LDiag) > 0,
          'endtran: error/info path yields diagnostics');
      end;
    finally
      sql_freeHandle(SQL_HANDLE_DBC, LDbc);
    end;
  finally
    sql_freeHandle(SQL_HANDLE_ENV, LEnv);
  end;
end;

{ ===== live（env 门控）===== }

procedure TestLiveDsnSmoke;
var
  LConnStr: string;
  LEnv: Pointer;
  LDbc: Pointer;
  LStmt: Pointer;
  LOutLen: SmallInt;
  LCols: SmallInt;
  LInd: Int64;
  LBuf: array[0..63] of AnsiChar;
  LRC: SmallInt;
begin
  LConnStr := GetEnvironmentVariable('NEXTPAS_ODBC_TEST_CONN');
  if LConnStr = '' then
    Skip('no NEXTPAS_ODBC_TEST_CONN (live dsn smoke skipped)');
  OdbcEnsureLoaded;
  LEnv := nil;
  LDbc := nil;
  LStmt := nil;
  if sql_allocHandle(SQL_HANDLE_ENV, nil, LEnv) <> SQL_SUCCESS then
    Check(False, 'env alloc failed');
  try
    sql_setEnvAttr(LEnv, SQL_ATTR_ODBC_VERSION,
      Pointer(PtrInt(SQL_OV_ODBC3)), 0);
    LRC := sql_allocHandle(SQL_HANDLE_DBC, LEnv, LDbc);
    if LRC <> SQL_SUCCESS then
      OdbcRaise(SQL_HANDLE_ENV, LEnv, LRC, 'live: alloc dbc');
    try
      LRC := sql_driverConnect(LDbc, nil, PAnsiChar(AnsiString(LConnStr)),
        SQL_NTS, nil, 0, LOutLen, SQL_DRIVER_NOPROMPT);
      if LRC <> SQL_SUCCESS then
        OdbcRaise(SQL_HANDLE_DBC, LDbc, LRC, 'live: driverconnect');
      LRC := sql_allocHandle(SQL_HANDLE_STMT, LDbc, LStmt);
      if LRC <> SQL_SUCCESS then
        OdbcRaise(SQL_HANDLE_DBC, LDbc, LRC, 'live: alloc stmt');
      try
        LRC := sql_execDirect(LStmt, 'SELECT 1', SQL_NTS);
        if LRC <> SQL_SUCCESS then
          OdbcRaise(SQL_HANDLE_STMT, LStmt, LRC, 'live: select 1');
        LRC := sql_numResultCols(LStmt, LCols);
        Check((LRC = SQL_SUCCESS) and (LCols >= 1), 'live: one column');
        CheckEqual(Int64(sql_fetch(LStmt)), Int64(SQL_SUCCESS),
          'live: fetch row');
        FillChar(LBuf, SizeOf(LBuf), 0);
        LRC := sql_getData(LStmt, 1, SQL_C_CHAR, @LBuf[0],
          SizeOf(LBuf), LInd);
        CheckEqual(Int64(LRC), Int64(SQL_SUCCESS), 'live: getdata ok');
        Check(Pos('1', StrPas(PAnsiChar(@LBuf[0]))) = 1,
          'live: value is 1, got: ' + StrPas(PAnsiChar(@LBuf[0])));
      finally
        sql_freeHandle(SQL_HANDLE_STMT, LStmt);
      end;
      LRC := sql_disconnect(LDbc);
      CheckEqual(Int64(LRC), Int64(SQL_SUCCESS), 'live: disconnect');
    finally
      sql_freeHandle(SQL_HANDLE_DBC, LDbc);
    end;
  finally
    sql_freeHandle(SQL_HANDLE_ENV, LEnv);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.db.odbc.base');
  T.Test('constant vocabulary', @TestConstantVocabulary);
  T.Test('loader idempotent', @TestLoaderIdempotent);
  T.Test('env handle lifecycle', @TestEnvHandleLifecycle);
  T.Test('dbc handle lifecycle', @TestDbcHandleLifecycle);
  T.Test('diagnostics real path', @TestDiagnosticsRealPath);
  T.Test('invalid handle defense', @TestInvalidHandleDefense);
  T.Test('endtran unconnected tolerant', @TestEndTranUnconnectedTolerant);
  T.Test('live dsn smoke', @TestLiveDsnSmoke);
  if not T.Run then Halt(1);
end.
