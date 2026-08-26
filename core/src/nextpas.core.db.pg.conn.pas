unit nextpas.core.db.pg.conn;

{** @desc PostgreSQL L2 implementation: friendly facade over libpq
       (loaded via nextpas.core.db.pg.loader).
       - TPgConn: open/close, Exec (multi-statement DDL/DML), prepared
         parameterized queries, Changes, server/lib versions.
       - TPgQuery: prepared statement lifecycle (bind 1-based, step,
         columns 0-based), mirroring TSqliteQuery's shape.
       - EPgError: carries SQLSTATE / severity / detail.
       Text is UTF-8. One connection = one serialized writer; libpq is
       not thread-safe per connection, keep each TPgConn on one thread
       (the owning application's db layer serializes writers). *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.db.pg.base,
  nextpas.core.db.pg.ffi,
  nextpas.core.db.pg.loader,
  nextpas.core.db.sqlscan;

type
  TPgConn = class;

  {** @desc A parameterized, executed query (all rows buffered).
       Parameter count is derived from the SQL ($N placeholders, with
       string literals and comments skipped) and passed explicitly to
       PQexecParams — libpq reports no parameter count from PQprepare on
       unnamed statements, so type inference is handed to the server.
       Bind parameters 1-based; columns 0-based. Step advances the row
       cursor; Get* reads the current row (NULL -> 0 / ''). *}
  TPgQuery = class
  private
    FConn: TPgConn;
    FSql: string;
    FRes: PGresult;
    FRow: Integer;        { -1 = not executed }
    FRows: Integer;
    FCols: Integer;
    FParamCount: Integer;
    FParamStorage: array of string;    { keeps bound value memory alive }
    FParamValues: array of PAnsiChar;  { pointer array handed to libpq }
    { 已绑定 Blob 的参数索引（1-based）；ExecuteOnce 对这些 $N 追加
      ::bytea cast（文本协议下二进制经 hex 字面量传入）。 }
    FCastIdx: array of Integer;
    FExecuted: Boolean;
    procedure ExecuteOnce;
    { V3-C1 服务端 prepared 路径 }
    procedure PrepareNamed(const AName, ASql: string);
    procedure ExecutePrepared(const AName: string);
    procedure AddCastIndex(const AIndex: Integer);
  public
    constructor Create(const AConn: TPgConn; const ASql: string);
    destructor Destroy; override;

    procedure BindText(const AIndex: Integer; const AValue: string);
    procedure BindInt64(const AIndex: Integer; const AValue: Int64);
    procedure BindDouble(const AIndex: Integer; const AValue: Double);
    { 二进制参数：hex 文本（\x…）+ ::bytea cast，服务端按 bytea 解析。 }
    procedure BindBlob(const AIndex: Integer; const AValue: TBytes);
    procedure BindNull(const AIndex: Integer);

    function Step: Boolean;
    procedure Reset;
    function ColumnCount: Integer;
    function ColumnName(const AIndex: Integer): string;
    { SQL 中扫描到的参数个数（$N 占位符；V3-C2 数组绑定全覆盖
      检查与索引越界校验用）。 }
    function ParamCount: Integer;
    { 结果列的 PostgreSQL 类型 OID（PQftype；未执行时返回 0）。 }
    function ColumnFieldOid(const AIndex: Integer): Cardinal;
    function IsNull(const AIndex: Integer): Boolean;
    function GetInt64(const AIndex: Integer): Int64;
    function GetDouble(const AIndex: Integer): Double;
    function GetText(const AIndex: Integer): string;
    { bytea 列读取（hex 输出解码）；非 \x 前缀 fail-closed 抛错。 }
    function GetBlob(const AIndex: Integer): TBytes;
  end;

  {** @desc PostgreSQL connection. Open with PgOpen (or Create) — the
       first open triggers libpq.so.5 loading. Exec runs multi-statement
       SQL; transactions are caller-managed via Exec('BEGIN'/'COMMIT'/
       'ROLLBACK') exactly like the sqlite module. No connection pool:
       that stays in the consuming application's db layer. *}
  TPgPreparedEntry = record
    Sql: string;              { bytea cast 后的规范形（缓存键） }
    Name: string;             { 服务端 prepared statement 名 }
  end;

  TPgConn = class
  private
    FConn: PGconn;
    FLastCmdTuples: Int64;
    { V3-C1 服务端 prepared statement 注册表（LRU 顺序 = 数组序，
      头最旧）。容量 <=0 = 关闭直通。单连接单逻辑线程（CONTRACT
      §2.1），无需并发防护。PREPARE 是事务性的：事务回滚会撤销
      服务端语句，靠执行期 26000 自愈重建；驱逐 DEALLOCATE 同样
      事务性，靠 prepare 期 42P05 自愈兜底。 }
    FStmtCapacity: Integer;
    FStmts: array of TPgPreparedEntry;
    FStmtSeq: Integer;        { 名字单调递增不复用 }
    FStmtHits: Int64;
    FStmtMisses: Int64;
    procedure CheckResultStatus(const ARes: PGresult);
  public
    constructor Create(const AConnInfo: string;
      const AStmtCacheCapacity: Integer = 0);
    destructor Destroy; override;

    procedure Exec(const ASql: string);
    function Query(const ASql: string): TPgQuery;
    function Changes: Int64;
    function Version: string;
    function ServerVersion: Integer;
    function ErrorMessage: string;
    { SHOW <name> 单行单列原文读回（V3-B2 查询级超时恢复用）}
    function ShowVar(const AName: string): string;
    { 原生 PGconn*——供大对象 fastpath（lo_*）等直接 ffi 面
      （对齐 TSqliteDb.Handle 先例） }
    property Handle: PGconn read FConn;

    { ---- V3-C1 语句缓存内部面（TPgQuery 与适配器使用） ---- }
    function LookupPrepared(const ASql: string): string;
    function NextPreparedName: string;
    procedure RegisterPrepared(const ASql, AName: string);
    procedure ForgetPrepared(const ASql: string);
    procedure EvictPreparedIfFull;
    procedure ClearPrepared;
    function PreparedCount: Integer;
    function PreparedHitRate: Double;
  end;

{ Open a PostgreSQL connection. AConnInfo uses libpq key=value syntax,
  e.g. 'host=/var/run/postgresql dbname=myapp user=app'. Raises EPgError
  on load or connect failure. }
function PgOpen(const AConnInfo: string): TPgConn;


implementation

uses
  nextpas.core.encoding.base,
  nextpas.core.encoding.hex,
  nextpas.core.exception,
  nextpas.core.text.builder;

{ ===== helpers ===== }

function ErrField(const ARes: PGresult; const AFieldCode: Integer): string;
var
  LP: PAnsiChar;
begin
  LP := pq_resultErrorField(ARes, AFieldCode);
  if LP = nil then
    Result := ''
  else
    Result := string(AnsiString(LP));
end;

procedure RaiseResultError(const ARes: PGresult);
var
  LMsg: string;
begin
  LMsg := string(AnsiString(pq_resultErrorMessage(ARes)));
  if LMsg = '' then
    LMsg := 'PostgreSQL 执行失败';
  raise EPgError.Create(LMsg, ErrField(ARes, PG_DIAG_SQLSTATE),
    ErrField(ARes, PG_DIAG_SEVERITY), ErrField(ARes, PG_DIAG_DETAIL),
    ErrField(ARes, PG_DIAG_SCHEMA_NAME), ErrField(ARes, PG_DIAG_TABLE_NAME),
    ErrField(ARes, PG_DIAG_COLUMN_NAME));
end;

{** @desc Maximum $N parameter index referenced by ASql, skipping single-
       quoted string literals ('' escapes), double-quoted identifiers,
       line comments (--) and block comments (/* */). 0 = no parameters.
       Dollar-quoted bodies ($$ ... $$) are not used by this module's
       repository SQL; a '$$' in a literal would count, which is
       acceptable for controlled SQL. *}
function MaxParamIndex(const ASql: string): Integer;
begin
  { V3-C6：词法扫描收敛至 db.sqlscan 共享引擎（行为逐字节兼容） }
  Result := SqlScanMaxPlaceholderIndex(ASql, DBSQLSCAN_PG, '$');
end;

{** @desc 对 ASql 中列出的 $N 参数追加 ::bytea cast。扫描状态机与
       MaxParamIndex 完全一致（跳过字面量/注释），保证索引对齐；
       dollar-quote 体不识别——与 MaxParamIndex 同一受控边界。 *}
function AppendByteaCasts(const ASql: string;
  const AIndexes: array of Integer): string;
begin
  { V3-C6：词法扫描收敛至 db.sqlscan 共享引擎（行为逐字节兼容） }
  Result := SqlScanDecorate(ASql, DBSQLSCAN_PG, '$', AIndexes,
    '::bytea');
end;

{ ===== TPgConn ===== }

constructor TPgConn.Create(const AConnInfo: string;
  const AStmtCacheCapacity: Integer);
begin
  inherited Create;
  PgEnsureLoaded;
  FStmtCapacity := AStmtCacheCapacity;
  FConn := pq_connectdb(PAnsiChar(AnsiString(AConnInfo)));
  if FConn = nil then
    raise EPgError.Create('PQconnectdb 返回空连接（内存不足）');
  if pq_status(FConn) <> CONNECTION_OK then
  begin
    try
      { 建连失败恒为连接类：SQLSTATE 08000（connection_exception，
        libpq 细分码 08001/08006 需服务端协商后才有，此处拿不到——
        用 ISO 通用码保证 ClassifyPg 落 decConnection） }
      raise EPgError.Create(
        string(AnsiString(pq_errorMessage(FConn))),
        '08000', 'ERROR', '');
    finally
      pq_finish(FConn);
      FConn := nil;
    end;
  end;
end;

destructor TPgConn.Destroy;
begin
  { 服务端 prepared statements 随会话结束自动消亡，无需显式 DEALLOCATE }
  if FConn <> nil then
    pq_finish(FConn);
  inherited;
end;

{ ===== V3-C1 语句缓存内部面 ===== }

function TPgConn.LookupPrepared(const ASql: string): string;
var
  I: Integer;
begin
  for I := 0 to High(FStmts) do
    if FStmts[I].Sql = ASql then
    begin
      Result := FStmts[I].Name;
      Inc(FStmtHits);
      Exit;
    end;
  Result := '';
  Inc(FStmtMisses);
end;

function TPgConn.NextPreparedName: string;
begin
  Inc(FStmtSeq);
  Result := 'np_db_stmt_' + IntToStr(FStmtSeq);
end;

procedure TPgConn.RegisterPrepared(const ASql, AName: string);
begin
  SetLength(FStmts, Length(FStmts) + 1);
  FStmts[High(FStmts)].Sql := ASql;
  FStmts[High(FStmts)].Name := AName;
end;

procedure TPgConn.ForgetPrepared(const ASql: string);
var
  I, K: Integer;
begin
  for I := 0 to High(FStmts) do
    if FStmts[I].Sql = ASql then
    begin
      for K := I to High(FStmts) - 1 do
        FStmts[K] := FStmts[K + 1];
      SetLength(FStmts, Length(FStmts) - 1);
      Exit;
    end;
end;

procedure TPgConn.EvictPreparedIfFull;
begin
  if (FStmtCapacity <= 0) or (Length(FStmts) <= FStmtCapacity) then
    Exit;
  { 头 = 最旧；DEALLOCATE 与 PREPARE 同为事务性——若驱逐发生在
    回滚的事务内，服务端语句复活而登记已删，后续 prepare 撞 42P05
    由 prepare 侧自愈兜底。 }
  Exec('DEALLOCATE ' + FStmts[0].Name);
  ForgetPrepared(FStmts[0].Sql);
end;

procedure TPgConn.ClearPrepared;
begin
  if Length(FStmts) > 0 then
    Exec('DEALLOCATE ALL');
  SetLength(FStmts, 0);
  FStmtHits := 0;
  FStmtMisses := 0;
end;

function TPgConn.PreparedCount: Integer;
begin
  Result := Length(FStmts);
end;

function TPgConn.PreparedHitRate: Double;
begin
  if FStmtHits + FStmtMisses = 0 then
    Exit(0.0);
  Result := FStmtHits / (FStmtHits + FStmtMisses);
end;

procedure TPgConn.CheckResultStatus(const ARes: PGresult);
var
  LStatus: Integer;
begin
  if ARes = nil then
    raise EPgError.Create('PostgreSQL 返回空结果');
  LStatus := pq_resultStatus(ARes);
  if not (LStatus in [PGRES_EMPTY_QUERY, PGRES_COMMAND_OK, PGRES_TUPLES_OK]) then
    RaiseResultError(ARes);
  FLastCmdTuples := StrToInt64Def(string(AnsiString(pq_cmdTuples(ARes))), 0);
end;

procedure TPgConn.Exec(const ASql: string);
var
  LRes: PGresult;
begin
  LRes := pq_exec(FConn, PAnsiChar(AnsiString(ASql)));
  try
    CheckResultStatus(LRes);
  finally
    pq_clear(LRes);
  end;
end;

function TPgConn.Query(const ASql: string): TPgQuery;
begin
  Result := TPgQuery.Create(Self, ASql);
end;

function TPgConn.Changes: Int64;
begin
  Result := FLastCmdTuples;
end;

function TPgConn.Version: string;
begin
  Result := IntToStr(pq_libVersion());
end;

function TPgConn.ServerVersion: Integer;
begin
  Result := pq_serverVersion(FConn);
end;

function TPgConn.ErrorMessage: string;
begin
  Result := string(AnsiString(pq_errorMessage(FConn)));
end;

function TPgConn.ShowVar(const AName: string): string;
var
  LRes: PGresult;
begin
  { SHOW <name> 单行单列原文读回（V3-B2 查询级超时恢复用）。
    PAnsiChar 转串一律 AnsiPtrToStr（硬边界纪律，不引 FPC RTL）。 }
  LRes := pq_exec(FConn, PAnsiChar(AnsiString('SHOW ' + AName)));
  try
    CheckResultStatus(LRes);
    if (pq_ntuples(LRes) < 1) or (pq_nfields(LRes) < 1) then
      raise EPgError.Create('SHOW ' + AName + ': empty result');
    Result := AnsiPtrToStr(pq_getvalue(LRes, 0, 0));
  finally
    pq_clear(LRes);
  end;
end;

function PgOpen(const AConnInfo: string): TPgConn;
begin
  Result := TPgConn.Create(AConnInfo);
end;

{ ===== TPgQuery ===== }

constructor TPgQuery.Create(const AConn: TPgConn; const ASql: string);
begin
  inherited Create;
  PgEnsureLoaded;
  FConn := AConn;
  FSql := ASql;
  FParamCount := MaxParamIndex(ASql);
  SetLength(FParamStorage, FParamCount);
  SetLength(FParamValues, FParamCount);
  FRow := -1;
end;

destructor TPgQuery.Destroy;
begin
  if FRes <> nil then
    pq_clear(FRes);
  inherited;
end;

procedure TPgQuery.BindText(const AIndex: Integer; const AValue: string);
begin
  if (AIndex < 1) or (AIndex > FParamCount) then
    raise EPgError.CreateFmt('绑定参数 %d 越界（共 %d 个占位符）', [AIndex, FParamCount]);
  FParamStorage[AIndex - 1] := AValue;
  FParamValues[AIndex - 1] := PAnsiChar(AnsiString(FParamStorage[AIndex - 1]));
end;

procedure TPgQuery.BindInt64(const AIndex: Integer; const AValue: Int64);
begin
  BindText(AIndex, IntToStr(AValue));
end;

procedure TPgQuery.BindDouble(const AIndex: Integer; const AValue: Double);
begin
  BindText(AIndex, FloatToStr(AValue));
end;

procedure TPgQuery.AddCastIndex(const AIndex: Integer);
var
  I: Integer;
begin
  for I := 0 to High(FCastIdx) do
    if FCastIdx[I] = AIndex then
      Exit;
  SetLength(FCastIdx, Length(FCastIdx) + 1);
  FCastIdx[High(FCastIdx)] := AIndex;
end;

procedure TPgQuery.BindBlob(const AIndex: Integer; const AValue: TBytes);
begin
  if (AIndex < 1) or (AIndex > FParamCount) then
    raise EPgError.CreateFmt('绑定参数 %d 越界（共 %d 个占位符）', [AIndex, FParamCount]);
  FParamStorage[AIndex - 1] := '\x' + HexEncode(AValue, hcLower);
  FParamValues[AIndex - 1] := PAnsiChar(AnsiString(FParamStorage[AIndex - 1]));
  AddCastIndex(AIndex);
end;

procedure TPgQuery.BindNull(const AIndex: Integer);
begin
  if (AIndex < 1) or (AIndex > FParamCount) then
    raise EPgError.CreateFmt('绑定参数 %d 越界（共 %d 个占位符）', [AIndex, FParamCount]);
  FParamStorage[AIndex - 1] := '';
  FParamValues[AIndex - 1] := nil;   { nil pointer = SQL NULL in text format }
end;

procedure TPgQuery.PrepareNamed(const AName, ASql: string);
var
  LRes: PGresult;
begin
  LRes := pq_prepare(FConn.FConn, PAnsiChar(AnsiString(AName)),
    PAnsiChar(AnsiString(ASql)), FParamCount, nil);
  try
    FConn.CheckResultStatus(LRes);
  finally
    pq_clear(LRes);
  end;
end;

procedure TPgQuery.ExecutePrepared(const AName: string);
var
  LRes: PGresult;
begin
  LRes := pq_execPrepared(FConn.FConn, PAnsiChar(AnsiString(AName)),
    FParamCount, PPAnsiChar(@FParamValues[0]), nil, nil, 0);
  try
    FConn.CheckResultStatus(LRes);
    FRows := pq_ntuples(LRes);
    FCols := pq_nfields(LRes);
    FRes := LRes;
  except
    pq_clear(LRes);
    raise;
  end;
  FRow := -1;
  FExecuted := True;
end;

procedure TPgQuery.ExecuteOnce;
var
  LRes: PGresult;
  LCmd: string;
  LName: string;
begin
  if Length(FCastIdx) > 0 then
    LCmd := AppendByteaCasts(FSql, FCastIdx)
  else
    LCmd := FSql;

  { V3-C1 语句缓存：仅参数化语句入缓存（无参 DDL/DML 解析收益小、
    形态多变，直通）。键 = cast 后规范形——同一 SQL 不同绑定形态
    （blob ::bytea cast 有无）自然分键，防撞名错配。
    自愈双保险：执行期 26000（PREPARE 随事务回滚被撤销/外部
    DEALLOCATE）→ 忘登记、换新名重建（本次命中计数已付，统计失真
    方向无害）；prepare 期 42P05（驱逐 DEALLOCATE 发生在已回滚事务
    内致服务端语句复活）→ 先 DEALLOCATE 再重试。 }
  if (FParamCount > 0) and (FConn.FStmtCapacity > 0) then
  begin
    LName := FConn.LookupPrepared(LCmd);
    if LName <> '' then
    begin
      try
        ExecutePrepared(LName);
        Exit;
      except
        on E: EPgError do
        begin
          if E.SqlState <> '26000' then
            raise;
          FConn.ForgetPrepared(LCmd);
          LName := FConn.NextPreparedName;
        end;
      end;
    end
    else
      LName := FConn.NextPreparedName;
    try
      PrepareNamed(LName, LCmd);
    except
      on E: EPgError do
      begin
        if E.SqlState <> '42P05' then
          raise;
        FConn.Exec('DEALLOCATE ' + LName);
        PrepareNamed(LName, LCmd);
      end;
    end;
    FConn.RegisterPrepared(LCmd, LName);
    FConn.EvictPreparedIfFull;
    ExecutePrepared(LName);
    Exit;
  end;

  if FParamCount = 0 then
    LRes := pq_execParams(FConn.FConn, PAnsiChar(AnsiString(LCmd)), 0, nil, nil, nil, nil, 0)
  else
    LRes := pq_execParams(FConn.FConn, PAnsiChar(AnsiString(LCmd)), FParamCount, nil,
      PPAnsiChar(@FParamValues[0]), nil, nil, 0);
  try
    FConn.CheckResultStatus(LRes);
    FRows := pq_ntuples(LRes);
    FCols := pq_nfields(LRes);
    FRes := LRes;
  except
    pq_clear(LRes);
    raise;
  end;
  FRow := -1;
  FExecuted := True;
end;

function TPgQuery.Step: Boolean;
begin
  if not FExecuted then
    ExecuteOnce;
  if FRows = 0 then
    Exit(False);
  Inc(FRow);
  Result := FRow < FRows;
end;

procedure TPgQuery.Reset;
begin
  if FRes <> nil then
  begin
    pq_clear(FRes);
    FRes := nil;
  end;
  FRow := -1;
  FRows := 0;
  FCols := 0;
  FExecuted := False;
end;

function TPgQuery.ColumnCount: Integer;
begin
  if FRes = nil then
    Exit(0);
  Result := pq_nfields(FRes);
end;

function TPgQuery.ParamCount: Integer;
begin
  Result := FParamCount;
end;

function TPgQuery.ColumnName(const AIndex: Integer): string;
begin
  if FRes = nil then
    Exit('');
  Result := string(AnsiString(pq_fname(FRes, AIndex)));
end;

function TPgQuery.ColumnFieldOid(const AIndex: Integer): Cardinal;
begin
  if FRes = nil then
    Exit(0);
  Result := pq_ftype(FRes, AIndex);
end;

function TPgQuery.IsNull(const AIndex: Integer): Boolean;
begin
  if (FRes = nil) or (FRow < 0) or (FRow >= FRows) then
    Exit(True);
  Result := pq_getisnull(FRes, FRow, AIndex) <> 0;
end;

function TPgQuery.GetText(const AIndex: Integer): string;
var
  LP: PAnsiChar;
  LL: Integer;
begin
  if IsNull(AIndex) then
    Exit('');
  LP := pq_getvalue(FRes, FRow, AIndex);
  LL := pq_getlength(FRes, FRow, AIndex);
  SetString(Result, LP, LL);
end;

function TPgQuery.GetInt64(const AIndex: Integer): Int64;
var
  LS: string;
begin
  if IsNull(AIndex) then
    Exit(0);
  LS := GetText(AIndex);
  if not TryStrToInt64(LS, Result) then
    raise EPgError.CreateFmt('列 %d 不是合法的 int64 值: "%s"', [AIndex, LS]);
end;

function TPgQuery.GetDouble(const AIndex: Integer): Double;
var
  LS: string;
begin
  if IsNull(AIndex) then
    Exit(0);
  LS := GetText(AIndex);
  if not TryStrToFloat(LS, Result) then
    raise EPgError.CreateFmt('列 %d 不是合法的 double 值: "%s"', [AIndex, LS]);
end;

function TPgQuery.GetBlob(const AIndex: Integer): TBytes;
var
  LS: string;
begin
  if IsNull(AIndex) then
    Exit(nil);
  LS := GetText(AIndex);
  if (Length(LS) >= 2) and (LS[1] = '\') and (LS[2] = 'x') then
  begin
    { HexDecode 对非法输入抛 EConvertError；包装回本模块边界错误类型 }
    try
      Result := HexDecode(Copy(LS, 3, Length(LS) - 2));
    except
      on E: EConvertError do
        raise EPgError.CreateFmt('列 %d bytea hex 解码失败: %s', [AIndex, E.Message]);
    end;
  end
  else
    raise EPgError.CreateFmt('列 %d 不是 bytea hex 输出，无法按 Blob 读取', [AIndex]);
end;

end.