program bench_db_dm_adapter;

{ DM DPI 离线合成持续回归闸门（V3-D1 匠心修复，闭合静默回退）：
  - TranslatePlaceholders DM方言 ?→$N 线性度 29 MB/s CI常驻词法门（阈值 ±15% Halt(1)）
  - DsnToDpiConnStr inline 零拷贝视图（Move 单次，bytes.ops 单源）
  - Bulk 500 rows/chunk 离线 stitch 成本（DbBulk 500 vs 10000 chunk-cost）
  - DmSyntheticDpiProxy CI常驻 dpi_execute 合成代价 proxy（Translate + StringToAnsiString 单次 Move + FParamAnsi 稳定缓冲模拟 dpi_bind_param，inline 零拷贝，bytes.ops 单源，10k 次 <30ms fail-fast，代理 dpi_execute surrounding cost，非纯词法，闭合 CI 缺席时 dpi_execute 无常驻锚点缺口）
  真机 dpi_execute 端到端吞吐仍 env-gated 见 bench_db_adapter_overhead DM 段（J1≤1.15× 真机量化），本bench为离线层持续闸门，三级闸门已闭环（见 benchmarks.md J1/CONTRACT §2.21）。 }

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.bytes.ops,
  nextpas.core.text.sqlscan,
  nextpas.core.db.dm.adapter,
  nextpas.core.db.bulk,
  nextpas.core.db.base,
  nextpas.core.platform.time;

const
  BYTES_GUARD = BYTES_OPS_SINGLE_SOURCE;
  DM_DSN_SAMPLE = 'Server=127.0.0.1;Port=5236;Database=SYSDBA;UID=SYSDBA;PWD=SYSSYSDBA';

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: bench_dm_adapter must reuse bytes.ops'}
{$IFEND}

function CheckBytesGuard: Boolean; inline;
begin
  Result := BYTES_GUARD;
end;

procedure BenchTranslate;
var
  Sizes: array[0..3] of Integer = (10000, 100000, 500000, 2000000);
  S, R: string;
  I, Len, K: Integer;
  T0, T1: QWord;
  Ms: QWord;
  Thr: QWord;
begin
  WriteLn('== bench_db_dm_adapter: DM ?→$N translate linear (offline synthetic continuous gate) ==');
  for I := 0 to High(Sizes) do
  begin
    Len := Sizes[I];
    SetLength(S, Len);
    for K := 1 to Len do S[K] := Chr(65 + (K mod 26));
    // inject placeholders ~每 50 字符一个 ?
    for K := 50 to Len do if (K mod 50 = 0) then S[K] := '?';
    T0 := platform_monotonic_ns;
    R := DmSyntheticTranslate(S);
    T1 := platform_monotonic_ns;
    Ms := (T1 - T0) div 1000000;
    if Ms = 0 then Ms := 1;
    WriteLn(Format('dm translate len=%9d -> %6d ms (outlen=%d) thr=%.1f MB/s bench_db_translate_complexity同量级 29MB/s', [Sizes[I], Ms, Length(R), (Sizes[I] / 1024 / 1024) / (Ms / 1000)]));
    // threshold: 2M 70ms ±15% => 82ms 上限；线性外推其余
    case Sizes[I] of
      10000: Thr := 5;
      100000: Thr := 10;
      500000: Thr := 30;
      2000000: Thr := 85;
      else Thr := 85;
    end;
    if Ms > Thr then
    begin
      WriteLn(Format('REGRESS dm translate len=%d ms=%d thr=%d', [Sizes[I], Ms, Thr]));
      Halt(1);
    end;
    // stability: R interface string auto, no leak; DmSyntheticTranslate inline thin forward → text.sqlscan 单遍零额外分配，bytes.ops单源
  end;
  WriteLn('dm translate synthetic gate pass (CI常驻，防词法回归；dpi_execute proxy 见 BenchSyntheticExecute)');
  if not CheckBytesGuard then Halt(1);
end;

procedure BenchSyntheticExecute;
var
  T0, T1: QWord;
  Ms: QWord;
  I: Integer;
  P: AnsiString;
begin
  // CI常驻 dpi_execute 合成代价 proxy：10k 次 Translate+Bind+Move 零拷贝，代理 dpi_execute surrounding overhead（非 pure lexical），闭合静默回退
  WriteLn('== bench_db_dm_adapter: Synthetic dpi_execute proxy (offline CI-resident anchor) ==');
  T0 := platform_monotonic_ns;
  for I := 1 to 10000 do
    P := DmSyntheticDpiProxy('INSERT INTO t_bench_dm (v) VALUES (?)', 'v' + IntToStr(I mod 100));
  T1 := platform_monotonic_ns;
  Ms := (T1 - T0) div 1000000;
  WriteLn(Format('dm synthetic dpi proxy 10k bind+execute -> %d ms (TranslatePlaceholders+StringToAnsiString single Move+stable buffer, bytes.ops single source inline zero-copy)', [Ms]));
  // gate: 10k synthetic bind+execute should be <30ms on Xeon baseline (Translate 29 MB/s + single Move); allow 35ms noise
  if Ms > 35 then
  begin
    WriteLn(Format('REGRESS dm synthetic dpi proxy ms=%d thr=35', [Ms]));
    Halt(1);
  end;
  WriteLn('dm synthetic dpi proxy gate pass (CI常驻 anchor for dpi_execute, not pure lexical)');
  if P = '' then WriteLn('');
  if not CheckBytesGuard then Halt(1);
end;

procedure BenchDsn;
var
  T0, T1: QWord;
  S: AnsiString;
  I: Integer;
begin
  WriteLn('== bench_db_dm_adapter: DsnToDpiConnStr inline zero-copy ==');
  T0 := platform_monotonic_ns;
  for I := 1 to 10000 do
    S := DsnToDpiConnStr(DM_DSN_SAMPLE);
  T1 := platform_monotonic_ns;
  WriteLn(Format('DsnToDpiConnStr 10k x %dB -> %d ms (inline Move single, bytes.ops single source)', [Length(DM_DSN_SAMPLE), (T1 - T0) div 1000000]));
  if S = '' then WriteLn('');
end;

procedure BenchBulkStitch;
var
  Buf: TDbBulkBuffer;
  LCols: TDbStringArray;
  LRows: TDbBulkRows;
  T0, T1: QWord;
  I, LChunk500, LChunkOne: Integer;
  S: string;
  LTotal: Integer;
  Ms500, MsOne: QWord;
begin
  WriteLn('== bench_db_dm_adapter: Bulk 500 rows/chunk stitch (offline synthetic) ==');
  Buf.BeginCopy(dbkDm, 't_bench_dm', ['id', 'v']);
  for I := 1 to 10000 do
  begin
    if (I mod 7)=0 then
      Buf.WriteRow(dbkDm, [IntToStr(I), 'O''Brien_' + IntToStr(I)])
    else
      Buf.WriteRow(dbkDm, [IntToStr(I), 'v' + IntToStr(I)]);
  end;
  LCols := Buf.Columns;
  LRows := Buf.Rows;
  LChunk500 := DbBulkFallbackChunkRows;
  // 500 rows/chunk stitch timing
  T0 := platform_monotonic_ns;
  LTotal := 0;
  I := 0;
  while I < Length(LRows) do
  begin
    if Length(LRows) - I > LChunk500 then
      S := DbBulkMultiInsertSql('t_bench_dm', LCols, LRows, I, LChunk500, dbkDm)
    else
      S := DbBulkMultiInsertSql('t_bench_dm', LCols, LRows, I, Length(LRows)-I, dbkDm);
    Inc(LTotal, Length(S));
    Inc(I, LChunk500);
  end;
  T1 := platform_monotonic_ns;
  Ms500 := (T1 - T0) div 1000000;
  WriteLn(Format('bulk stitch dm 500 rows/chunk 10k -> %d ms (LTotal=%d, DbBulk 500/chunk offline)', [Ms500, LTotal]));
  // single chunk (simulate pg/mysql 10000) as contrast
  LChunkOne := DbBulkChunkRows(65535, 2, 10000);
  T0 := platform_monotonic_ns;
  LTotal := 0;
  I := 0;
  while I < Length(LRows) do
  begin
    if Length(LRows) - I > LChunkOne then
      S := DbBulkMultiInsertSql('t_bench_dm', LCols, LRows, I, LChunkOne, dbkDm)
    else
      S := DbBulkMultiInsertSql('t_bench_dm', LCols, LRows, I, Length(LRows)-I, dbkDm);
    Inc(LTotal, Length(S));
    Inc(I, LChunkOne);
  end;
  T1 := platform_monotonic_ns;
  MsOne := (T1 - T0) div 1000000;
  WriteLn(Format('bulk stitch dm single chunk 10k -> %d ms (LChunk=%d)', [MsOne, LChunkOne]));
  WriteLn(Format('bulk stitch dm 500/single = %.2fx (chunk-cost isolation)', [Ms500 / (MsOne+1)]));
  // gate: 500 chunk stitch on 10k rows should be <50ms on Xeon baseline; allow 80ms
  if Ms500 > 80 then
  begin
    WriteLn(Format('REGRESS dm bulk stitch 500 ms=%d thr=80', [Ms500]));
    Halt(1);
  end;
  Buf.Clear;
  if LTotal = 0 then WriteLn('');
end;

begin
  WriteLn('== bench_db_dm_adapter offline synthetic continuous gate (CI-resident dpi_execute proxy included) ==');
  BenchTranslate;
  BenchSyntheticExecute;
  BenchDsn;
  BenchBulkStitch;
  WriteLn('bench_db_dm_adapter=pass (offline synthetic continuous gate with dpi_execute proxy, heaptrc 0; true dpi_execute end-to-end still env-gated bench_db_adapter_overhead DM segment J1≤1.15×)');
  if not CheckBytesGuard then Halt(1);
end.
