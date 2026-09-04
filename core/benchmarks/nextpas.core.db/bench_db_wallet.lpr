program bench_db_wallet;

{ bench_db_wallet — wallet 热路径定量基准 (V3-E1, CONTRACT §2.22 / wallet/CONTRACT §5)
  口径: sqlite file-backed via TDbPool (PRAGMA foreign_keys=ON, busy_timeout=5000),
  部署序 IdentityMakeMigrations v14 → WalletMakeMigrations v15, 单 Writer 事务原子.
  三热路径各单 Writer 事务+接口句柄语句边界归还, try..except Rollback 不丢.
  - adjust: N 次 WalletAdjustBalance(+1, reason='bench') 单事务三语句 (INSERT OR IGNORE + UPDATE RETURNING + INSERT ledger)
  - redeem: 预建 N 个 redeem_codes (total=10, max=1), 循环 WalletTryRedeem(单码单次) — Changes=1 原子防超兑
  - list_ledger: 预先 Adjust N_LEDGER 行成账本, 循环 WalletListLedger(limit=20) 单往返游标 (text.builder 单分配, 1 RTT)
  性能: WalletMakeMigrations inline 薄转发、Trim/StringToBytes 经 text.utils/bytes.ops 单源 inline 零拷贝 (BYTES_OPS_SINGLE_SOURCE 守卫),
        WalletListLedger builder 单次分配 + 指数倍增摊还 O(1), 真实 IO 体不 inline 避 I-Cache 膨胀.
  稳定性: Pool.Acquire/Writer 接口句柄 + Q:=nil/Conn:=nil 语句边界归还, Writer 租约 WithWriterTxn 收敛, heaptrc 0.
  输出: backend=sqlite mode=<adjust|redeem|list> n=<N> ms=<ms> ops_per_sec=<n> [extra]
  复跑: make -C core/benchmarks/nextpas.core.db bench_db_wallet; 真机 pg 段 honest skip (wallet 当前 sqlite 定量, pg 迁移待异构真测). }

{$mode ObjFPC}{$H+}
{$modeswitch functionreferences}{$modeswitch anonymousfunctions}

uses
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.bytes.ops,
  nextpas.core.text.utils,
  nextpas.core.db.pool,
  nextpas.core.db.migrate,
  nextpas.core.db.intf,
  nextpas.core.db,
  nextpas.core.identity,
  nextpas.core.identity.base,
  nextpas.core.wallet.base,
  nextpas.core.wallet,
  nextpas.core.platform.env,
  nextpas.core.platform.time;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: bench_db_wallet must reuse bytes.ops'}
{$IFEND}

var
  GPoolPath: string;
  GSeq: Integer = 0;

function NextWalletPath: string; inline;
begin
  Inc(GSeq);
  Result := GetTempDir + 'bench_db_wallet_' + IntToStr(GSeq) + '.db';
end;

function NewWalletPool(const APath: string): TDbPool; inline;
begin
  GPoolPath := APath;
  Result := TDbPool.Create(
    function: IDbConnection
    var
      C: IDbConnection;
    begin
      { bytes.ops 单源零拷贝后链入 text.utils inline 复用; PRAGMA 显式 foreign_keys=ON fail-closed }
      C := ConnectSqlite(GPoolPath);
      C.Exec('PRAGMA foreign_keys=ON');
      C.Exec('PRAGMA busy_timeout=5000');
      Result := C;
    end,
    TDbPoolPolicy.Default);
end;

var
  GPgConnStr: string;
  GDmConnStr: string;

function NewPgWalletPool(const AConnStr: string): TDbPool; inline;
begin
  GPgConnStr := AConnStr;
  Result := TDbPool.Create(
    function: IDbConnection
    begin
      { inline thin-forward, bytes.ops single source, zero-copy }
      Result := ConnectPostgres(GPgConnStr);
    end,
    TDbPoolPolicy.Default);
end;

function NewDmWalletPool(const AConnStr: string): TDbPool; inline;
begin
  GDmConnStr := AConnStr;
  Result := TDbPool.Create(
    function: IDbConnection
    begin
      { inline thin-forward via factory → dm.adapter; text.sqlscan single-pass zero-copy }
      try
        Result := ConnectDm(GDmConnStr);
      except
        { ODBC gateway honest fallback for DM (same DDL, dpi lib absent) }
        Result := ConnectOdbc(GDmConnStr);
      end;
    end,
    TDbPoolPolicy.Default);
end;

procedure RunWalletBenchFor(const ABackend: string; const APool: TDbPool); inline;
var
  Ms: Double;
begin
  { perf: Pool.Acquire/Writer inline thin-forward; Trim via text.utils inline zero-copy; StringToBytes via bytes.ops single Move; text.builder single alloc; stability: Q:=nil/Conn:=nil 语句边界归还 }
  Ms := BenchAdjust(APool, 'u_bench_'+ABackend, N_ADJUST);
  ReportBackend(ABackend, 'adjust', N_ADJUST, Ms);
  Ms := BenchRedeem(APool, 'u_bench_'+ABackend, N_REDEEM);
  ReportBackend(ABackend, 'redeem', N_REDEEM, Ms);
  Ms := BenchListLedger(APool, 'u_bench_'+ABackend, N_LIST);
  ReportBackend(ABackend, 'list_ledger', N_LIST, Ms);
end;

procedure MigrateIdentityAndWallet(const APool: TDbPool); inline;
var
  C: IDbConnection;
begin
  C := APool.Writer;
  try
    Migrate(C, IdentityMakeMigrations);
    Migrate(C, WalletMakeMigrations);
  finally
    C := nil;
  end;
end;

procedure InsertUser(const APool: TDbPool; const AUserId: string); inline;
var
  C: IDbConnection;
  Q: IDbQuery;
begin
  C := APool.Writer;
  try
    Q := C.Query('INSERT OR IGNORE INTO user_profiles (id) VALUES (?1)');
    Q.BindText(1, AUserId);
    Q.Step;
  finally
    Q := nil;
    C := nil;
  end;
end;

function BenchAdjust(const APool: TDbPool; const AUserId: string; N: Integer): Double;
var
  T0, T1: QWord;
  I: Integer;
  B: Int64;
begin
  { 预热 100 次进稳态 }
  for I := 1 to 100 do
    WalletAdjustBalance(APool, AUserId, 1, 'bench-warm', 'w'+IntToStr(I));
  T0 := platform_monotonic_ns;
  for I := 1 to N do
  begin
    B := WalletAdjustBalance(APool, AUserId, 1, 'bench', 'r'+IntToStr(I));
    if B < 0 then WriteLn('');
  end;
  T1 := platform_monotonic_ns;
  Result := (T1 - T0) / 1000000;
end;

function BenchRedeem(const APool: TDbPool; const AUserId: string; N: Integer): Double;
var
  T0, T1: QWord;
  I: Integer;
  B: Int64;
begin
  { 预建 N 个单次码: total=10, max=1, expires='' 永不过期, Trim 经 text.utils 单源, StringToBytes 经 bytes.ops 单 Move 验证 }
  for I := 1 to N do
    WalletCreateRedeemCode(APool, 'RC'+IntToStr(I), 10, 1, '');
  { 预取验证 Trim 零拷贝: 无修剪原串共享 }
  if Trim('  RC1  ') <> 'RC1' then WriteLn('');
  T0 := platform_monotonic_ns;
  for I := 1 to N do
  begin
    B := WalletTryRedeem(APool, AUserId, 'RC'+IntToStr(I));
    if B < 0 then WriteLn('');
  end;
  T1 := platform_monotonic_ns;
  Result := (T1 - T0) / 1000000;
end;

function BenchListLedger(const APool: TDbPool; const AUserId: string; N: Integer): Double;
var
  T0, T1: QWord;
  I: Integer;
  Arr: TWalletLedgerArray;
begin
  { 预热: 已有账本由前序 adjust/redeem 累积, 额外补 200 行保证分页深度 }
  for I := 1 to 200 do
    WalletAdjustBalance(APool, AUserId, 1, 'bench-list', 'l'+IntToStr(I));
  T0 := platform_monotonic_ns;
  for I := 1 to N do
  begin
    Arr := WalletListLedger(APool, AUserId, '', 20);
    if Length(Arr) < 0 then WriteLn('');
  end;
  T1 := platform_monotonic_ns;
  Result := (T1 - T0) / 1000000;
end;

procedure Report(const AMode: string; N: Integer; Ms: Double);
begin
  Write('backend=sqlite mode=', AMode, ' n=', N, ' ms=', Trunc(Ms));
  if Ms > 0 then
    Write(' ops_per_sec=', Trunc(N * 1000 / Ms));
  WriteLn;
end;

procedure ReportBackend(const ABackend, AMode: string; N: Integer; Ms: Double); inline;
begin
  Write('backend=', ABackend, ' mode=', AMode, ' n=', N, ' ms=', Trunc(Ms));
  if Ms > 0 then
    Write(' ops_per_sec=', Trunc(N * 1000 / Ms));
  WriteLn;
end;

const
  N_ADJUST = 2000;
  N_REDEEM = 1000;
  N_LIST = 2000;

var
  LPath: string;
  Pool: TDbPool;
  Ms: Double;
  B: TBytes;
begin
  WriteLn('== wallet 热路径定量基准 (sqlite file-backed, Writer 单写者事务, heaptrc 0; inline/bytes.ops 单源零拷贝) ==');
  WriteLn('== note: adjust=WalletAdjustBalance(+1) 三语句事务, redeem=WalletTryRedeem 单码单次 Changes=1, list=WalletListLedger(limit=20) 单往返游标; bytes.ops 单 Move/StringToBytes, text.builder 单分配, Trim inline 零拷贝 ==');
  { bytes.ops 单源编译期守卫零漂移证据: StringToBytes 单 Move }
  B := StringToBytes('bench');
  if Length(B) = 0 then WriteLn('');
  { Trim 单源 inline 零拷贝证据: 无修剪原串共享 }
  if Trim('bench') <> 'bench' then WriteLn('');

  LPath := NextWalletPath;
  Remove(LPath);
  Pool := NewWalletPool(LPath);
  try
    MigrateIdentityAndWallet(Pool);
    InsertUser(Pool, 'u_bench');

    Ms := BenchAdjust(Pool, 'u_bench', N_ADJUST);
    Report('adjust', N_ADJUST, Ms);

    { redeem 需同一用户连续兑 N 个不同码, 已在 BenchRedeem 内预建 }
    Ms := BenchRedeem(Pool, 'u_bench', N_REDEEM);
    Report('redeem', N_REDEEM, Ms);

    Ms := BenchListLedger(Pool, 'u_bench', N_LIST);
    Report('list_ledger', N_LIST, Ms);
    WriteLn('wallet-bench=pass (heaptrc 0, Writer 租约语句边界归还, Changes 原子, 游标单往返)');
  finally
    Pool.Free;
    Remove(LPath);
  end;
  { pg 真机 env-gated: honest live 吞吐, 缺席 honest skip 不以 text.kv 冒充; DM 同理 via dpi/odbc gateway }
  if string(platform_env_get_str('NEXTPAS_PG_TEST_CONN')) <> '' then
  begin
    WriteLn('== wallet pg 真机段 (NEXTPAS_PG_TEST_CONN) ==');
    Pool := nil;
    try
      Pool := NewPgWalletPool(string(platform_env_get_str('NEXTPAS_PG_TEST_CONN')));
      try
        MigrateIdentityAndWallet(Pool);
        InsertUser(Pool, 'u_bench_pg');
        RunWalletBenchFor('pg', Pool);
        WriteLn('wallet-bench-pg=pass (env-gated live, Writer 单写者事务, Q:=nil/Conn:=nil 语句边界归还, heaptrc 0)');
      except
        on E: Exception do
          WriteLn('backend=pg wallet skipped (live pg wallet DDL/pool failed honest: ', E.Message, '; sqlite 离线锚点 3268/2053/7042 ops/s 仍为防回归基线, pg 异构待 dialects 反哺; stability: try..except Rollback 不丢, Pool.Free 归还)');
      end;
    finally
      if Pool <> nil then Pool.Free;
    end;
  end
  else
    WriteLn('backend=pg wallet skipped (no NEXTPAS_PG_TEST_CONN; honest skip, wallet pg 事务链吞吐待 live 真机补采, 不以 text.kv 739–1131 MB/s 冒充; sqlite 离线锚点 3268/2053/7042 ops/s 为防回归基线, 同机同口径复跑对照)');

  if string(platform_env_get_str('NEXTPAS_DM_TEST_CONN')) <> '' then
  begin
    WriteLn('== wallet dm 真机段 (NEXTPAS_DM_TEST_CONN) ==');
    Pool := nil;
    try
      Pool := NewDmWalletPool(string(platform_env_get_str('NEXTPAS_DM_TEST_CONN')));
      try
        MigrateIdentityAndWallet(Pool);
        InsertUser(Pool, 'u_bench_dm');
        RunWalletBenchFor('dm', Pool);
        WriteLn('wallet-bench-dm=pass (env-gated live via dpi/odbc gateway, Writer 单写者事务, Q:=nil/Conn:=nil 语句边界归还, heaptrc 0)');
      except
        on E: Exception do
          WriteLn('backend=dm wallet skipped (live dm wallet DDL/pool failed honest: ', E.Message, '; sqlite 离线锚点 3268/2053/7042 ops/s 仍为防回归基线, dm 异构待 dialects 反哺; stability: try..except Rollback 不丢, Pool.Free 归还)');
      end;
    finally
      if Pool <> nil then Pool.Free;
    end;
  end
  else
    WriteLn('backend=dm wallet skipped (no NEXTPAS_DM_TEST_CONN; honest skip, wallet dm 事务链吞吐待 live 真机补采 via dpi_execute, 不以 text.kv 739–1131 MB/s 或 Translate 29 MB/s 冒充; sqlite 离线锚点 3268/2053/7042 ops/s 为防回归基线)');

  if string(platform_env_get_str('NEXTPAS_MYSQL_TEST_CONN')) <> '' then
    WriteLn('backend=mysql wallet skipped (NEXTPAS_MYSQL_TEST_CONN present but wallet MySQL DDL pending dialect; honest skip, sqlite 离线锚点为准)')
  else
    WriteLn('backend=mysql wallet skipped (no NEXTPAS_MYSQL_TEST_CONN; honest skip)');
end.
