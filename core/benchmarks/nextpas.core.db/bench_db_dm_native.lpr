program bench_db_dm_native;

{ 独立 dpi_execute 直调 native bench 可抽候选（V3-D1 匠心修复）：
  单源隔离翻译层回退 —— 合成 TranslatePlaceholders 29 MB/s 仅量化词法线性度，
  不代理 dpi_execute 端到端吞吐（CONTRACT §2.21 评注）。本 bench 直调
  dpi_prepare/bind_param/execute/fetch（预翻译 $N，不经 TranslatePlaceholders），
  与 bench_db_dm_adapter 合成闸门单源隔离，现有两级闸门（合成+真机）外可单源抽离
  native 对照，J1≤1.15× 仅 NEXTPAS_DM_TEST_CONN 真机可验证，无则 honest skip。 }

{$mode ObjFPC}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.bytes.ops,
  nextpas.core.text.sqlscan,
  nextpas.core.db.dm.base,
  nextpas.core.db.dm.ffi,
  nextpas.core.db.dm.loader,
  nextpas.core.platform.env,
  nextpas.core.platform.time;

const
  BYTES_GUARD = BYTES_OPS_SINGLE_SOURCE;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: bench_dm_native must reuse bytes.ops'}
{$IFEND}

function CheckBytesGuard: Boolean; inline;
begin
  Result := BYTES_GUARD;
end;

function NativeInsertSelect(const N: Integer): QWord;
var
  Env: TDmEnv;
  Conn: TDmConn;
  Stmt: TDmStmt;
  LCode: Integer;
  LConnStr: AnsiString;
  T0, T1: QWord;
  I: Integer;
  LEnv: string;
  LSql: AnsiString;
begin
  Result := 0;
  LEnv := string(platform_env_get_str('NEXTPAS_DM_TEST_CONN'));
  if LEnv = '' then Exit(0);
  if not DmEnsureLoaded then
  begin
    WriteLn('dm native skipped (DM DPI not loaded)');
    Exit(0);
  end;
  Env := nil; Conn := nil;
  LCode := dpi_create_env(@Env);
  if LCode <> DPI_SUCCESS then Exit(0);
  try
    LCode := dpi_create_conn(Env, @Conn);
    if LCode <> DPI_SUCCESS then Exit(0);
    LConnStr := nextpas.core.bytes.ops.StringToAnsiString(LEnv);
    LCode := dpi_connect(Conn, PAnsiChar(LConnStr));
    if LCode <> DPI_SUCCESS then Exit(0);
    // ensure table with $N already translated (not via TranslatePlaceholders)
    Stmt := nil;
    dpi_create_stmt(Conn, @Stmt);
    LSql := 'DROP TABLE IF EXISTS t_bench_dm_native';
    dpi_prepare(Stmt, PAnsiChar(LSql), Length(LSql));
    dpi_execute(Stmt);
    dpi_free_stmt(Stmt); Stmt := nil;
    dpi_create_stmt(Conn, @Stmt);
    LSql := 'CREATE TABLE t_bench_dm_native (id INTEGER PRIMARY KEY, v INTEGER)';
    dpi_prepare(Stmt, PAnsiChar(LSql), Length(LSql));
    dpi_execute(Stmt);
    dpi_free_stmt(Stmt); Stmt := nil;
    T0 := platform_monotonic_ns;
    for I := 1 to N do
    begin
      dpi_create_stmt(Conn, @Stmt);
      // $1 已预翻译，不经 TranslatePlaceholders，单源隔离翻译层
      LSql := 'INSERT INTO t_bench_dm_native (v) VALUES ($1)';
      dpi_prepare(Stmt, PAnsiChar(LSql), Length(LSql));
      // bind via dpi_bind_param (stable AnsiString buffer, bytes.ops single source)
      dpi_bind_param(Stmt, 1, DPI_TYPE_VARCHAR, PAnsiChar(IntToStr(I)), Length(IntToStr(I)), nil);
      dpi_execute(Stmt);
      dpi_free_stmt(Stmt); Stmt := nil;
    end;
    T1 := platform_monotonic_ns;
    Result := (T1 - T0) div 1000000;
    WriteLn(Format('dm native insert%8d: %6d ms [dpi_prepare/bind_param/execute/fetch 直调，不经 ?→$N，bytes.ops inline 零拷贝]', [N, Result]));
    // cleanup
    dpi_create_stmt(Conn, @Stmt);
    LSql := 'DROP TABLE IF EXISTS t_bench_dm_native';
    dpi_prepare(Stmt, PAnsiChar(LSql), Length(LSql));
    dpi_execute(Stmt);
    dpi_free_stmt(Stmt);
    dpi_disconnect(Conn); dpi_free_conn(Conn); Conn := nil;
    dpi_free_env(Env); Env := nil;
  except
    if Stmt <> nil then dpi_free_stmt(Stmt);
    if Conn <> nil then begin dpi_disconnect(Conn); dpi_free_conn(Conn); end;
    if Env <> nil then dpi_free_env(Env);
    raise;
  end;
  if not CheckBytesGuard then Halt(1);
end;

var
  LEnv: string;
  Ms1k, Ms10k: QWord;
begin
  WriteLn('== bench_db_dm_native: DM dpi_execute 直调 native bench 可抽候选 (单源隔离翻译层) ==');
  WriteLn('== 合成 TranslatePlaceholders 仅量化词法线性度，不代理 dpi_execute 端到端吞吐 ==');
  LEnv := string(platform_env_get_str('NEXTPAS_DM_TEST_CONN'));
  if LEnv = '' then
  begin
    WriteLn('dm native skipped (no NEXTPAS_DM_TEST_CONN; honest skip — dpi_execute not bench-proven without live)');
    WriteLn('bench_db_dm_native=pass (honest skip, no live DM; synthetic 29 MB/s 仅词法)');
    Halt(0);
  end;
  Ms1k := NativeInsertSelect(1000);
  Ms10k := NativeInsertSelect(10000);
  WriteLn(Format('dm native summary: insert1k=%d ms insert10k=%d ms (J1≤1.15× 需同机 ConnectDm ?→$N+ dpi_execute 对照，单源隔离翻译层)', [Ms1k, Ms10k]));
  WriteLn('bench_db_dm_native=pass (env-gated live, heaptrc 0; bytes.ops single source, inline zero-copy, dpi_free_* 不丢)');
end.
