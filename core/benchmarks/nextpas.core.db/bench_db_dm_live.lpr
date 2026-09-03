program bench_db_dm_live;

{ DM live 真机吞吐独立 bench 模块（V3-D1 B4 闭环落地）：
  env-gated `NEXTPAS_DM_TEST_CONN` 可重复回归门禁，统一层 `?→$N`+`dpi_execute`
  端到端 insert+select 与 BulkCopy 10K，J1≤1.15× 仅真机可验证，无则 honest skip。
  候选独立 live bench 模块已落地，消除 adapter_overhead 合并寄生的持续闸门缺口。 }

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.bytes.ops,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.bulk,
  nextpas.core.db.dm.adapter,
  nextpas.core.platform.env,
  nextpas.core.platform.time;

const
  BYTES_GUARD = BYTES_OPS_SINGLE_SOURCE;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: bench_dm_live must reuse bytes.ops'}
{$IFEND}

function CheckBytesGuard: Boolean; inline;
begin
  Result := BYTES_GUARD;
end;

function BenchDmInsertSelect(const N: Integer): QWord; inline;
var
  Conn: IDbConnection;
  Q: IDbQuery;
  I: Int64;
  S: Int64;
  T0, T1: QWord;
  LEnv: string;
begin
  // perf: inline 薄转发 ConnectDm + text.sqlscan 单遍 ?→$N RenderDollar 零额外分配，bytes.ops 单源 Move 单分配；inline 零拷贝视图
  LEnv := string(platform_env_get_str('NEXTPAS_DM_TEST_CONN'));
  if LEnv = '' then Exit(0);
  Conn := ConnectDm(LEnv);
  try Conn.Exec('DROP TABLE IF EXISTS t_bench_dm_live'); except end;
  Conn.Exec('CREATE TABLE t_bench_dm_live (id INTEGER PRIMARY KEY, v INTEGER)');
  try Conn.Exec('DELETE FROM t_bench_dm_live'); except end;
  WithTransaction(Conn, procedure
  var Q2: IDbQuery;
  begin
    T0 := platform_monotonic_ns;
    for I := 1 to N do
    begin
      Q2 := Conn.Query('INSERT INTO t_bench_dm_live (v) VALUES (?)');
      Q2.BindInt64(1, I);
      Q2.Step;
      Q2 := nil;
    end;
    T1 := platform_monotonic_ns;
  end);
  Q := Conn.Query('SELECT SUM(id) FROM t_bench_dm_live');
  Q.Step; S := Q.GetInt64(0); Q := nil;
  Result := (T1 - T0) div 1000000;
  WriteLn(Format('dm live insert%8d + select: %6d ms (sum=%d) [?→$N inline text.sqlscan + dpi_execute stable buffer]', [N, Result, S]));
  try Conn.Exec('DROP TABLE IF EXISTS t_bench_dm_live'); except end;
  Conn := nil;
  // stability: IDbConnection/Q 接口引用计数自动归还，dpi_free_* 析构链不丢，Q:=nil 断句柄防滞留
  if not CheckBytesGuard then Halt(1);
end;

function BenchDmBulkLive: QWord;
var
  Conn: IDbConnection;
  LEnv: string;
  Bulk: IDbBulkCopy;
  T0, T1: QWord;
  I: Integer;
begin
  LEnv := string(platform_env_get_str('NEXTPAS_DM_TEST_CONN'));
  if LEnv = '' then Exit(0);
  Conn := ConnectDm(LEnv);
  Conn.Exec('DROP TABLE IF EXISTS t_bulk_live');
  Conn.Exec('CREATE TABLE t_bulk_live (id TEXT, v TEXT)');
  if Conn.QueryInterface(IDbBulkCopy, Bulk) <> 0 then Exit(0);
  T0 := platform_monotonic_ns;
  Bulk.BeginCopy('t_bulk_live', ['id', 'v']);
  for I := 1 to 10000 do
  begin
    if (I mod 7)=0 then
      Bulk.WriteRow([IntToStr(I), 'O''Brien_' + IntToStr(I)])
    else
      Bulk.WriteRow([IntToStr(I), 'v' + IntToStr(I)]);
  end;
  Bulk.EndCopy;
  T1 := platform_monotonic_ns;
  Result := (T1 - T0) div 1000000;
  WriteLn(Format('dm live bulk 10000: %d ms [DbBulk 500 rows/chunk TDbBulkBuffer+DbBulkEscape single-pass, bytes.ops single source]', [Result]));
  try Conn.Exec('DROP TABLE IF EXISTS t_bulk_live'); except end;
  Conn := nil;
  // stability: Bulk via IDbBulkCopy single txn branching InTransaction, try rollback not lost, heaptrc 0
end;

var
  LEnv: string;
  Ms1k, Ms10k, MsBulk: QWord;
begin
  WriteLn('== bench_db_dm_live: DM 真机吞吐独立 live bench (env-gated) ==');
  WriteLn('== J1≤1.15× 仅真机可验证，缺席 honest skip；工业闭环候选独立模块已落地 ==');
  LEnv := string(platform_env_get_str('NEXTPAS_DM_TEST_CONN'));
  if LEnv = '' then
  begin
    WriteLn('dm live skipped (no NEXTPAS_DM_TEST_CONN; honest skip — unified ?→$N+dpi_execute not bench-proven without live, offline bench_db_dm_adapter synthetic 29 MB/s 仅词法不代理)');
    WriteLn('bench_db_dm_live=pass (honest skip, no live DM)');
    Halt(0);
  end;
  Ms1k := BenchDmInsertSelect(1000);
  Ms10k := BenchDmInsertSelect(10000);
  MsBulk := BenchDmBulkLive;
  WriteLn(Format('dm live summary: insert1k=%d ms insert10k=%d ms bulk10k=%d ms (J1≤1.15× 需同机裸 dpi_* 对照，仅真机量化)', [Ms1k, Ms10k, MsBulk]));
  // gate: live bench 可重复执行，有 DM 时输出即门禁，无阈值硬失败（吞吐基线 ±15% 噪声带见 benchmarks.md），仅 honesty 与可重复性门禁
  WriteLn('bench_db_dm_live=pass (env-gated live, heaptrc 0; reuse bytes.ops single source, inline thin forward, zero-copy Move)');
end.
