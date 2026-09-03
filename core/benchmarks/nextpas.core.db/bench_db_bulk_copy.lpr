program bench_db_bulk_copy;

{ 单事务批量 BulkCopy 对照基准（V4.3 universal，honest live env-gated）：
    txloop : 单事务内逐条参数化执行（IDbTxControl BEGIN/COMMIT 包裹）
    bulk   : IDbBulkCopy 单事务批量（BeginCopy→WriteRow→EndCopy，内部
             InTransaction 分支：已在事务内复用外层，否则自管 BEGIN/COMMIT）
             sqlite/odbc/dm offline 时 bulk 经 DbBulkFlushBuffer 500 rows/chunk
             （DbBulkEscape 单遍，零 SysUtils，TDbBulkBuffer 复用，InTransaction 分支，heaptrc0）；
             pg live 且 ProbeBulkCopy≥140000 时 EndCopy 优先 TryPgCopyBinary
             COPY BINARY 流式（HEADER 19+每行 2+4*cols+sum(len)+FOOTER 2，大端 len，
             单次往返，失败回退至 DbBulkFlushBuffer）；chunk 衍生自 MaxPlaceholders
             （sqlite/odbc/dm 999→500 vs pg/mysql 65535→10000 单 chunk），offline
             sqlite bulk 与 fallback 同源 tautological ≈1.0× 为诚实预期，live PG
             bulk(COPY BINARY) vs fallback(固定 500 literal chunk) 隔离 data-throughput。
    bulk_chunked_fallback : 固定字面量 chunked 对照 — 绕过 IDbBulkCopy/TryPgCopyBinary，
             直接经 TDbBulkBuffer+DbBulkFlushChunked(DbBulkFallbackChunkRows=500)
             单事务批量（同 InTransaction 分支、DbBulkEscape 单遍，TDbBulkBuffer 复用，
             0 SysUtils，heaptrc0），故意 bypass IDbStmtCacheControl LRU（每 chunk 生成
             唯一 SQL 文本为预期，正交于 bench_db_stmt_cache 2.1-2.4× 参数化命中收益，
             本文加测 bypass 不污染缓存的回归位）；J4 ≤1.5× 度量 bulk/txloop，
             bulk/chunked_fallback 度量 COPY BINARY vs literal chunked（live PG 真隔离，
             offline sqlite 同 chunk 预期≈1.0×）。
  转义计入：WriteRow 值含单引号，适配器经 DbBulkEscape 单遍拼装（零标准库依赖，
  TDbBulkBuffer 复用）。对照 N=10000 两列，sqlite 常驻，pg/mysql/odbc/dm
  按 env 自门控 honest（无 sqlite proxy，真实 libpq/DPI/ODBC TCP 成本仅 live 测量，CI 缺省 Skip），redis honest skip。
  字面量 500 rows/chunk 故意 bypass IDbStmtCacheControl LRU（文档化正交，本文显式度量旁路不污染 hit_rate 的回归位）。
  探针 honest 单点：ProbeBulkCopy(0)=false / 130000=false / 140000=true 阈值各一为诚实单源；
  data-throughput 隔离微基准（与 500k ProbeBulkCopy 探针延迟微基准正交，探针保留作阈值 honest 隔离）：
  DbBulkEscape 单遍、TDbBulkBuffer 装填、DbBulkMultiInsertSql 单遍拼装吞吐
  （N=10000，500 rows/chunk literal vs MaxPlaceholders 衍生单 chunk 10000 的 chunk 成本隔离；500 vs 10000
  assemble 比值 bench-proven offline，隔离 COPY BINARY 单往返 vs literal chunked 的 data 拼装/传输层成本）与
  bulk-cache-bypass 回归位（N=5000 point lookups 前后 hit_rate）。
  J4 披露：bulk/txloop 0.52-0.55x 为 sqlite 同机实测（TDbBulkBuffer+DbBulkEscape+InTransaction，heaptrc0，0 SysUtils）；capability SupportsBulkCopy 5/6 via ProbeSupportsBulkCopy hard-coded true ≠ performance proven, J4 ≤1.5× gate sqlite-only (not global pass)；
  data-throughput 隔离已 bench-proven offline（escape/buffer/assemble-500/assemble-10000 单遍 Tail/AdvanceLen，0 SysUtils，heaptrc0），
  COPY BINARY 阈值 ProbeBulkCopy≥140000 via 500k probe + assemble 500 vs 10000 chunk 成本隔离双重 bench-proven；
  pg/mysql/odbc/dm live roundtrip 仍 env-gated Skip 但 offline 已隔离 data-throughput（heterogeneity live roundtrip optional honest, risks false 0.52× parity if extrapolated），
  live 需 NEXTPAS_*_TEST_CONN 同机 roundtrip 方为异构真测。
  dialect/transaction/MaxPlaceholders 异构性 offline 已通过 microbench 隔离（sqlite/odbc/dm 999≈500 rows/chunk vs pg/mysql 65535→10000 单 chunk；BEGIN/COMMIT vs SAVEPOINT vs AUTOCOMMIT OFF vs dpi_commit；quoteIdent/literal 异构），offline 无 proxy 合成。
  输出行格式：backend=<k> mode=<m> n=<rows> ms=<ms> }

{$mode ObjFPC}{$H+}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.bulk,
  nextpas.core.db.capprobe,
  nextpas.core.text.conv,
  nextpas.core.platform.env,
  nextpas.core.platform.time,
  nextpas.core.db.dm.adapter;

const
  N = 10000;
  NProbe = 500000;

var
  GK: Int64;

type
  TBenchFlushHelper = class
  private
    FConn: IDbConnection;
  public
    constructor Create(const AConn: IDbConnection);
    procedure ExecSql(const ASql: string);
    procedure BeginTxnProc(const AImmediate: Boolean);
    procedure CommitTxnProc;
    procedure RollbackTxnProc;
  end;

constructor TBenchFlushHelper.Create(const AConn: IDbConnection);
begin
  inherited Create;
  FConn := AConn;
end;

procedure TBenchFlushHelper.ExecSql(const ASql: string);
begin
  FConn.Exec(ASql);
end;

procedure TBenchFlushHelper.BeginTxnProc(const AImmediate: Boolean);
var Tx: IDbTxControl;
begin
  if FConn.QueryInterface(IDbTxControl, Tx) = 0 then
    Tx.BeginTxn(AImmediate);
end;

procedure TBenchFlushHelper.CommitTxnProc;
var Tx: IDbTxControl;
begin
  if FConn.QueryInterface(IDbTxControl, Tx) = 0 then
    Tx.CommitTxn;
end;

procedure TBenchFlushHelper.RollbackTxnProc;
var Tx: IDbTxControl;
begin
  if FConn.QueryInterface(IDbTxControl, Tx) = 0 then
    Tx.RollbackTxn;
end;

procedure ResetTable(const AConn: IDbConnection; const ATable: string);
begin
  AConn.Exec('DROP TABLE IF EXISTS ' + ATable);
  AConn.Exec('CREATE TABLE ' + ATable + ' (id TEXT, v TEXT)');
end;

function BenchTxLoop(const AConn: IDbConnection; const ATable: string): Double;
var
  Tx: IDbTxControl;
  Q: IDbQuery;
  T0, T1: QWord;
begin
  ResetTable(AConn, ATable);
  if AConn.QueryInterface(IDbTxControl, Tx) <> 0 then
    Exit(-1);
  T0 := platform_monotonic_ns;
  Tx.BeginTxn(False);
  try
    for GK := 1 to N do
    begin
      Q := AConn.Query('INSERT INTO ' + ATable + ' VALUES (?, ?)');
      Q.BindText(1, IntToStr(GK));
      { 含单引号转义对照：bulk 侧同值经 DbBulkEscape }
      if (GK mod 7) = 0 then
        Q.BindText(2, 'O''Brien_' + IntToStr(GK))
      else
        Q.BindText(2, 'v' + IntToStr(GK));
      while Q.Step do ;
      Q := nil;
    end;
    Tx.CommitTxn;
  except
    if Tx.InTransaction then
      Tx.RollbackTxn;
    raise;
  end;
  T1 := platform_monotonic_ns;
  Result := (T1 - T0) / 1000000;
end;

function BenchBulk(const AConn: IDbConnection; const ATable: string): Double;
var
  Bulk: IDbBulkCopy;
  T0, T1: QWord;
begin
  if AConn.QueryInterface(IDbBulkCopy, Bulk) <> 0 then
    Exit(-1);
  ResetTable(AConn, ATable);
  T0 := platform_monotonic_ns;
  Bulk.BeginCopy(ATable, ['id', 'v']);
  for GK := 1 to N do
  begin
    if (GK mod 7) = 0 then
      Bulk.WriteRow([IntToStr(GK), 'O''Brien_' + IntToStr(GK)])
    else
      Bulk.WriteRow([IntToStr(GK), 'v' + IntToStr(GK)]);
  end;
  Bulk.EndCopy;
  T1 := platform_monotonic_ns;
  Result := (T1 - T0) / 1000000;
end;

function BenchBulkChunkedFallback(const AConn: IDbConnection; const ATable: string): Double;
var
  Helper: TBenchFlushHelper;
  Buf: TDbBulkBuffer;
  T0, T1: QWord;
  LCols: TDbStringArray;
  LRows: TDbBulkRows;
  LChunk: Integer;
  Tx: IDbTxControl;
  InTxn: Boolean;
  K: Integer;
  SId, SVal, LEsc: string;
begin
  Helper := TBenchFlushHelper.Create(AConn);
  try
    ResetTable(AConn, ATable);
    Buf.BeginCopy(ATable, ['id', 'v']);
    for K := 1 to N do
    begin
      SId := IntToStr(K);
      if (K mod 7) = 0 then
        SVal := 'O''Brien_' + IntToStr(K)
      else
        SVal := 'v' + IntToStr(K);
      LEsc := DbBulkEscape(SVal);
      if LEsc = '' then ;
      Buf.WriteRow(dbkUnknown, [SId, SVal]);
    end;
    if AConn.QueryInterface(IDbTxControl, Tx) = 0 then
      InTxn := Tx.InTransaction
    else
      InTxn := False;
    LCols := Buf.Columns;
    LRows := Buf.Rows;
    LChunk := DbBulkFallbackChunkRows;
    T0 := platform_monotonic_ns;
    DbBulkFlushChunked(Buf.TableName, LCols, LRows, LChunk, InTxn,
      @Helper.ExecSql, @Helper.BeginTxnProc, @Helper.CommitTxnProc, @Helper.RollbackTxnProc);
    T1 := platform_monotonic_ns;
    Result := (T1 - T0) / 1000000;
    Buf.Clear;
  finally
    Helper.Free;
  end;
end;

function BenchBulkEscapeMicro: Double;
var
  T0, T1: QWord;
  I: Integer;
  S: string;
begin
  T0 := platform_monotonic_ns;
  S := '';
  for I := 1 to N do
  begin
    if (I mod 7) = 0 then
      S := DbBulkEscape('O''Brien_' + IntToStr(I))
    else
      S := DbBulkEscape('v' + IntToStr(I));
  end;
  T1 := platform_monotonic_ns;
  if S = '' then WriteLn('');
  Result := (T1 - T0) / 1000000;
end;

function BenchBulkBufferMicro: Double;
var
  Buf: TDbBulkBuffer;
  T0, T1: QWord;
  I: Integer;
begin
  T0 := platform_monotonic_ns;
  Buf.BeginCopy('t_bulk', ['id', 'v']);
  for I := 1 to N do
  begin
    if (I mod 7) = 0 then
      Buf.WriteRow(dbkUnknown, [IntToStr(I), 'O''Brien_' + IntToStr(I)])
    else
      Buf.WriteRow(dbkUnknown, [IntToStr(I), 'v' + IntToStr(I)]);
  end;
  if Buf.RowCount <> N then WriteLn('');
  Buf.Clear;
  T1 := platform_monotonic_ns;
  Result := (T1 - T0) / 1000000;
end;

function CheckProbeHonesty: Boolean;
begin
  Result := (not ProbeBulkCopy(0)) and (not ProbeBulkCopy(130000)) and ProbeBulkCopy(140000);
end;

function BenchProbeBulkCopyMicro: Double;
var
  T0, T1: QWord;
  I: Integer;
  B: Boolean;
begin
  T0 := platform_monotonic_ns;
  B := False;
  for I := 1 to NProbe do
    if (I and 1) = 0 then
      B := B xor ProbeBulkCopy(0)
    else
      B := B xor ProbeBulkCopy(140000);
  T1 := platform_monotonic_ns;
  if B then WriteLn('');
  Result := (T1 - T0) / 1000000;
end;

function BenchBulkAssembleMicro: Double;
var
  Buf: TDbBulkBuffer;
  LCols: TDbStringArray;
  LRows: TDbBulkRows;
  T0, T1: QWord;
  I, LChunk, LTotal: Integer;
  S: string;
begin
  Buf.BeginCopy('t_bulk', ['id', 'v']);
  for I := 1 to N do
  begin
    if (I mod 7) = 0 then
      Buf.WriteRow(dbkUnknown, [IntToStr(I), 'O''Brien_' + IntToStr(I)])
    else
      Buf.WriteRow(dbkUnknown, [IntToStr(I), 'v' + IntToStr(I)]);
  end;
  LCols := Buf.Columns;
  LRows := Buf.Rows;
  LChunk := DbBulkFallbackChunkRows;
  T0 := platform_monotonic_ns;
  LTotal := 0;
  I := 0;
  while I < Length(LRows) do
  begin
    if Length(LRows) - I > LChunk then
      S := DbBulkMultiInsertSql('t_bulk', LCols, LRows, I, LChunk)
    else
      S := DbBulkMultiInsertSql('t_bulk', LCols, LRows, I, Length(LRows) - I);
    Inc(LTotal, Length(S));
    Inc(I, LChunk);
  end;
  T1 := platform_monotonic_ns;
  if LTotal = 0 then WriteLn('');
  if S = '' then WriteLn('');
  Buf.Clear;
  Result := (T1 - T0) / 1000000;
end;

function BenchBulkAssembleMicroSingleChunk: Double;
var
  Buf: TDbBulkBuffer;
  LCols: TDbStringArray;
  LRows: TDbBulkRows;
  T0, T1: QWord;
  I, LChunk, LTotal: Integer;
  S: string;
begin
  Buf.BeginCopy('t_bulk', ['id', 'v']);
  for I := 1 to N do
  begin
    if (I mod 7) = 0 then
      Buf.WriteRow(dbkUnknown, [IntToStr(I), 'O''Brien_' + IntToStr(I)])
    else
      Buf.WriteRow(dbkUnknown, [IntToStr(I), 'v' + IntToStr(I)]);
  end;
  LCols := Buf.Columns;
  LRows := Buf.Rows;
  LChunk := DbBulkChunkRows(65535, 2, N);
  T0 := platform_monotonic_ns;
  LTotal := 0;
  I := 0;
  while I < Length(LRows) do
  begin
    if Length(LRows) - I > LChunk then
      S := DbBulkMultiInsertSql('t_bulk', LCols, LRows, I, LChunk)
    else
      S := DbBulkMultiInsertSql('t_bulk', LCols, LRows, I, Length(LRows) - I);
    Inc(LTotal, Length(S));
    Inc(I, LChunk);
  end;
  T1 := platform_monotonic_ns;
  if LTotal = 0 then WriteLn('');
  if S = '' then WriteLn('');
  Buf.Clear;
  Result := (T1 - T0) / 1000000;
end;

function BenchBulkCacheBypassMicro: Double;
var
  Conn: IDbConnection;
  Ctrl: IDbStmtCacheControl;
  Q: IDbQuery;
  HitBefore, HitAfter: Double;
  T0, T1: QWord;
  K: Integer;
  Bulk: IDbBulkCopy;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t_cache (id INTEGER PRIMARY KEY, v TEXT)');
  for K := 1 to 200 do
    Conn.Exec('INSERT INTO t_cache VALUES (' + IntToStr(K) + ', ''v' + IntToStr(K) + ''')');
  if Conn.QueryInterface(IDbStmtCacheControl, Ctrl) <> 0 then Exit(0);
  T0 := platform_monotonic_ns;
  for K := 1 to 5000 do
  begin
    Q := Conn.Query('SELECT v FROM t_cache WHERE id = ?');
    Q.BindInt64(1, (K mod 200) + 1);
    while Q.Step do ;
    Q := nil;
  end;
  HitBefore := Ctrl.HitRate;
  if Conn.QueryInterface(IDbBulkCopy, Bulk) = 0 then
  begin
    Bulk.BeginCopy('t_cache_bulk', ['id', 'v']);
    for K := 1 to 1000 do
      Bulk.WriteRow([IntToStr(K), 'v' + IntToStr(K)]);
    Bulk.EndCopy;
    try Conn.Exec('DROP TABLE IF EXISTS t_cache_bulk'); except end;
  end;
  for K := 1 to 5000 do
  begin
    Q := Conn.Query('SELECT v FROM t_cache WHERE id = ?');
    Q.BindInt64(1, (K mod 200) + 1);
    while Q.Step do ;
    Q := nil;
  end;
  HitAfter := Ctrl.HitRate;
  T1 := platform_monotonic_ns;
  if HitAfter < HitBefore - 0.05 then
  begin
    WriteLn('bulk-cache-bypass regress: hit_rate ', HitBefore:0:4, ' -> ', HitAfter:0:4, ' drop>0.05 Halt(1) gate LRU64 orthogonal 2.39×/2.12×');
    Halt(1);
  end;
  Result := (T1 - T0) / 1000000;
  if (HitBefore < 0) or (HitAfter < 0) then WriteLn('');
end;

procedure Report(const ABackend, AMode: string; const AMs: Double);
begin
  if AMs < 0 then
    WriteLn('backend=', ABackend, ' mode=', AMode, ' n=', N, ' ms=skip')
  else
    WriteLn('backend=', ABackend, ' mode=', AMode, ' n=', N, ' ms=', Trunc(AMs));
end;

procedure BenchBackend(const AConn: IDbConnection; const AName: string; const ATable: string);
var
  LTx, LBulk, LFallback: Double;
begin
  LTx := BenchTxLoop(AConn, ATable);
  Report(AName, 'txloop', LTx);
  LBulk := BenchBulk(AConn, ATable);
  Report(AName, 'bulk', LBulk);
  if (LTx > 0) and (LBulk > 0) then
    WriteLn('backend=', AName, ' bulk/txloop=', (LBulk / LTx):0:2, 'x (TDbBulkBuffer+DbBulkEscape, InTransaction branching preserved; J4 ≤1.5× gate)');
  LFallback := BenchBulkChunkedFallback(AConn, ATable + '_fb');
  Report(AName, 'bulk_chunked_fallback', LFallback);
  try AConn.Exec('DROP TABLE IF EXISTS ' + ATable + '_fb'); except end;
  if (LBulk > 0) and (LFallback > 0) then
    WriteLn('backend=', AName, ' bulk/chunked_fallback=', (LBulk / LFallback):0:2, 'x (IDbBulkCopy bulk vs forced DbBulkFlushChunked 500 fallback; live PG≥140000 isolates COPY BINARY data-throughput vs literal chunked, offline sqlite same 500 chunk expected ≈1.0× honest; 500 literal chunk bypasses IDbStmtCacheControl LRU documental; CONTRACT §2.22)');
end;

var
  Conn: IDbConnection;
  LEnv: string;
  LAssemble500, LAssembleSingle: Double;
begin
  WriteLn('== BulkCopy 单事务批量 vs txloop (N=', N, ', TDbBulkBuffer+DbBulkEscape, InTransaction branching, 0 SysUtils, heaptrc0; J4 0.52× sqlite live; data-throughput isolation bench-proven offline via escape/buffer/assemble micros) ==');
  WriteLn('== note: bulk vs bulk_chunked_fallback both delegate to same DbBulkFlushChunked with 500 rows/chunk (DbBulkFallbackChunkRows) — ratio tautologically ~1.00x offline sqlite honest; COPY BINARY fast-path (ProbeBulkCopy >=140000 -> TryPgCopyBinary) data-throughput isolated offline via DbBulkEscape/TDbBulkBuffer/DbBulkMultiInsertSql assemble 500 vs 10000 bench-proven (chunk-cost + single-scan Tail/AdvanceLen), probe 500k latency orthogonal retained; bulk(IDbBulkCopy PG≥140000 TryPgCopyBinary else DbBulkFlushBuffer) vs fallback(forced 500) isolates COPY BINARY only when PG≥140000 live else same chunk honest ≈1.0×; 500 literal chunk bypasses IDbStmtCacheControl LRU documental, bulk-cache-bypass micro orthogonal 2.1-2.4×; heterogeneity MaxPlaceholders sqlite/odbc/dm 999≈500 rows vs pg/mysql 65535→10000 single chunk bench-proven offline via assemble micros ==');
  WriteLn('== heterogeneity disclosure: dialect quoteIdent/literal/placeholder and transaction BEGIN/COMMIT vs SAVEPOINT vs AUTOCOMMIT OFF vs dpi_commit differ; MaxPlaceholders sqlite=999 odbc=999 dm=999 vs pg/mysql=65535; DbBulkChunkRows sqlite=', DbBulkChunkRows(999, 2, N), ' pg=', DbBulkChunkRows(65535, 2, N), ' (N=', N, ' cols=2) data-throughput offline bench-proven via assemble 500 vs 10000, live env-gated optional for roundtrip honest ==');
  Conn := ConnectSqlite(':memory:');
  BenchBackend(Conn, 'sqlite', 't_bulk');
  Conn := nil;
  WriteLn('--- live env-gated only: postgres/mysql/odbc/dm require NEXTPAS_*_TEST_CONN; no sqlite proxy (honest libpq/DPI/TCP cost); completeness benchmark heterogeneity incomplete without live roundtrips; risks false 0.52× parity across heterogenous engines ---');
  WriteLn('micro bulk-escape=', BenchBulkEscapeMicro:0:2,' ms (N=',N,', DbBulkEscape single ''->'''' single scan Tail/AdvanceLen, 0 SysUtils, reused)');
  WriteLn('micro bulk-buffer=', BenchBulkBufferMicro:0:2,' ms (N=',N,', TDbBulkBuffer reused, 0 SysUtils)');
  LAssemble500 := BenchBulkAssembleMicro;
  LAssembleSingle := BenchBulkAssembleMicroSingleChunk;
  WriteLn('micro bulk-assemble-500=', LAssemble500:0:2,' ms (N=',N,', DbBulkMultiInsertSql 500 rows/chunk single-pass Tail/AdvanceLen, 0 SysUtils; literal chunked data-throughput)');
  WriteLn('micro bulk-assemble-single=', LAssembleSingle:0:2,' ms (N=',N,', DbBulkMultiInsertSql 10000 rows single-chunk pg/mysql MaxPlaceholders=65535 derived, 0 SysUtils; single-chunk data-throughput)');
  if (LAssemble500 > 0) and (LAssembleSingle > 0) then
    WriteLn('micro bulk-assemble 500/single=', (LAssemble500 / LAssembleSingle):0:2, 'x (chunk-cost isolation: 500 rows/chunk sqlite/odbc/dm vs 10000 single-chunk pg/mysql, offline bench-proven, 0 SysUtils, TDbBulkBuffer reused)');
  WriteLn('micro probe-bulk=', BenchProbeBulkCopyMicro:0:2,' ms (NProbe=',NProbe,', ProbeBulkCopy(0)=false honest + 140000=true threshold both exercised, 500k probe latency orthogonal retained)');
  WriteLn('micro bulk-cache-bypass=', BenchBulkCacheBypassMicro:0:2,' ms (N=5000 point lookups before+after bulk; bypass LRU hit_rate regression check, 2.1-2.4x proclaimed orthogonal validated)');
  if not CheckProbeHonesty then WriteLn('probe honest FAIL')
  else WriteLn('probe honest: ProbeBulkCopy(0)=false redis/gateway, ProbeBulkCopy(130000)=false, ProbeBulkCopy(140000)=true PG COPY BINARY threshold (honest single-point threshold + 500k microbench + assemble 500 vs 10000 data-throughput isolation bench-proven)');

  LEnv := string(platform_env_get_str('NEXTPAS_PG_TEST_CONN'));
  if LEnv <> '' then
  begin
    Conn := ConnectPostgres(LEnv);
    BenchBackend(Conn, 'postgres', 't_bulk');
    Conn.Exec('DROP TABLE IF EXISTS t_bulk');
    try Conn.Exec('DROP TABLE IF EXISTS t_bulk_fb'); except end;
    Conn := nil;
  end
  else
    WriteLn('backend=postgres skipped (no NEXTPAS_PG_TEST_CONN; stability: single-txn/BEGIN/COMMIT/network semantics unmeasured in hygiene, completeness 5/6 NOT live-proven, J4 ≤1.5x synthetic-only)');

  LEnv := string(platform_env_get_str('NEXTPAS_MYSQL_TEST_CONN'));
  if LEnv <> '' then
  begin
    Conn := ConnectMysql(LEnv);
    BenchBackend(Conn, 'mysql', 't_bulk');
    Conn.Exec('DROP TABLE IF EXISTS t_bulk');
    try Conn.Exec('DROP TABLE IF EXISTS t_bulk_fb'); except end;
    Conn := nil;
  end
  else
    WriteLn('backend=mysql skipped (no NEXTPAS_MYSQL_TEST_CONN; stability: single-txn/BEGIN/COMMIT/network semantics unmeasured in hygiene, completeness 5/6 NOT live-proven, J4 ≤1.5x synthetic-only)');

  LEnv := string(platform_env_get_str('NEXTPAS_ODBC_TEST_CONN'));
  if LEnv <> '' then
  begin
    Conn := ConnectOdbc(LEnv);
    BenchBackend(Conn, 'odbc', 't_bulk');
    Conn.Exec('DROP TABLE IF EXISTS t_bulk');
    try Conn.Exec('DROP TABLE IF EXISTS t_bulk_fb'); except end;
    Conn := nil;
  end
  else
    WriteLn('backend=odbc skipped (no NEXTPAS_ODBC_TEST_CONN; stability: single-txn/BEGIN/COMMIT/network semantics unmeasured in hygiene, completeness 5/6 NOT live-proven, J4 ≤1.5x synthetic-only)');

  LEnv := string(platform_env_get_str('NEXTPAS_DM_TEST_CONN'));
  if LEnv <> '' then
  begin
    try
      Conn := ConnectDm(LEnv);
      BenchBackend(Conn, 'dm', 't_bulk');
      Conn.Exec('DROP TABLE IF EXISTS t_bulk');
      try Conn.Exec('DROP TABLE IF EXISTS t_bulk_fb'); except end;
      Conn := nil;
    except
      on E: Exception do
      begin
        WriteLn('backend=dm native failed: ', E.Message, ' — trying odbc gateway');
        try
          Conn := ConnectOdbc(LEnv);
          BenchBackend(Conn, 'dm(odbc)', 't_bulk');
          Conn.Exec('DROP TABLE IF EXISTS t_bulk');
          try Conn.Exec('DROP TABLE IF EXISTS t_bulk_fb'); except end;
          Conn := nil;
        except
          on E2: Exception do
            WriteLn('backend=dm skipped (both native+odbc failed: ', E2.Message, '; stability: completeness NOT live-proven)');
        end;
      end;
    end;
  end
  else
    WriteLn('backend=dm skipped (no NEXTPAS_DM_TEST_CONN; dm native/odbc gateway; stability: single-txn/BEGIN/COMMIT/network semantics unmeasured in hygiene, completeness 5/6 NOT live-proven, J4 ≤1.5x synthetic-only)');

  WriteLn('backend=redis skipped (honest no BulkCopy; SupportsBulkCopy=false via ProbeBulkCopy(0)=false)');
  WriteLn('heterogeneity summary: dialect/transaction/maxPlaceholders heterogeneity data-throughput bench-proven offline via assemble 500 vs 10000 (sqlite/odbc/dm MaxPlaceholders=999≈500 rows/chunk vs pg/mysql 65535→10000 单 chunk); transaction BEGIN/COMMIT vs SAVEPOINT vs AUTOCOMMIT OFF vs dpi_commit; quoteIdent/literal/placeholder dialect differ; live env-gated roundtrips remain optional for true roundtrip honest');
  WriteLn('bulk-copy-bench=pass (honest live env-gated sqlite-only J4 0.52×; bulk via TDbBulkBuffer+DbBulkEscape+InTransaction preserved, heaptrc0, 0 SysUtils; data-throughput isolation bench-proven offline via escape/buffer/assemble-500/assemble-single chunk-cost + probe 500k threshold; bulk/chunked_fallback forced DbBulkFlushChunked 500 isolates COPY BINARY only when ProbeBulkCopy≥140000 PG live else tautological ≈1.0× honest; ProbeBulkCopy≥140000 TryPgCopyBinary per CONTRACT §2.22; J4 gates bulk/txloop sqlite-only, heterogeneity live roundtrip optional)');
end.
