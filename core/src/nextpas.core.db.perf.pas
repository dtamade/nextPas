unit nextpas.core.db.perf;
{**
 * @desc L2 性能契约单源：J1 与合成闸门阈值及批量基线（阈值/批量单源，口径见 benchmarks.md:40,106，三级闸门见 nightly-live.md 与 CONTRACT §2.21）。
 *  J1≤1.15× 仅 NEXTPAS_DM_TEST_CONN 真机可量化；CI 合成仅 surrounding cost 不计入 J1（honest not J1），不覆盖 dpi_prepare/bind_param/execute 真实往返。
 *  缺 nightly live 时 dpi_execute 端到端无回归防护属已登记静默缺口（DB_PERF_J1_REQUIRES_NIGHTLY_LIVE/DB_PERF_SYNTHETIC_HONEST_NOT_J1 已显式登记，DbPerfHasSilentGapIfNoNightly 单源判定）；L3 nightly live CI 硬门禁闭环（每日02:00 UTC + db.dm.*变更需live证据否则阻塞，见nightly-live.md），CI 日常合成通过≠J1达标。
 *  文档级阈值/批量以本单元 DB_PERF_J1_THRESHOLD/DB_PERF_DM_SYNTHETIC_*/DB_PERF_BATCH_PG_* 为单源，CONTRACT/benchmarks/nightly-live/batch 仅索引不双处制表防漂移（字面仅展示，真源本单元）。
 *  依赖：仅 L0-L1（bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE），无上向。
 *  性能：常量 inline 零拷贝单 Move 复用（bytes.ops 单源）；稳定性：纯常量无资源，句柄不丢。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops;

const
  PERF_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;
  PERF_BYTES_SINGLE_SOURCE_VERSION = BYTES_OPS_SINGLE_SOURCE_VERSION;

{$I nextpas.core.bytes.ops.single_source.inc}

const
  DB_PERF_J1_THRESHOLD = 1.15; // J1 业务不变量，仅 NEXTPAS_DM_TEST_CONN 真机可量化（honest not 合成，CI 合成不覆盖 dpi_prepare/bind_param/execute 往返）
  DB_PERF_SYNTHETIC_HONEST_NOT_J1 = True; // 合成仅 surrounding cost，不计入 J1（honest not J1 单源）
  DB_PERF_J1_REQUIRES_NIGHTLY_LIVE = True; // J1 需 nightly live L3 硬门禁，否则 dpi_execute 端到端静默缺口（DbPerfHasSilentGapIfNoNightly 单源判定）
  // CI 常驻合成闸门仅 surrounding cost（不代理 dpi_execute 真实往返，±15% fail-fast，阈值单源本单元，文档仅索引防漂移）
  DB_PERF_DM_SYNTHETIC_2M_MS = 85; // 2M 词法线性 29MB/s 合成 surrounding cost（阈值单源本单元，文档单源 benchmarks.md:40，不双处制表）
  DB_PERF_DM_SYNTHETIC_500K_MS = 30; // 500K 合成 surrounding cost（单源本单元，文档单源 benchmarks.md:40）
  DB_PERF_DM_SYNTHETIC_100K_MS = 10; // 100K 合成 surrounding cost（单源本单元，文档单源 benchmarks.md:40）
  DB_PERF_DM_SYNTHETIC_10K_MS = 5; // 10K 合成 surrounding cost（单源本单元，文档单源 benchmarks.md:40）
  DB_PERF_DM_SYNTHETIC_500CHUNK_10K_MS = 80; // 500行/chunk stitch surrounding cost（单源本单元，文档单源 benchmarks.md:40）
  DB_PERF_DM_SYNTHETIC_DPI_PROXY_10K_MS = 35; // DmSyntheticDpiProxy 10k surrounding cost（单源本单元，文档单源 benchmarks.md:40）
  DB_PERF_DM_SYNTHETIC_E2E_10K_MS = 40; // DmSyntheticE2EProxy 10k shape surrounding cost（单源本单元，文档单源 benchmarks.md:40）
  // 批量 10K 四模式基线（bench_db_batch_insert 同口径 2026-08-25 Xeon E5-2696 v4；array 29ms vs batch 174ms 6.0×/txloop 18× 已量化，见 benchmarks.md:106 文档单源；代码单源本单元，CONTRACT/batch.md 仅索引不双处制表，字面仅展示真源本单元）
  DB_PERF_BATCH_PG_AUTOCOMMIT_MS = 21830; // pg autocommit 10K 基线（单源本单元，文档单源 benchmarks.md:106）
  DB_PERF_BATCH_PG_TXLOOP_MS = 526; // pg txloop 10K 基线（单源本单元，文档单源 benchmarks.md:106）
  DB_PERF_BATCH_PG_BATCH_MS = 174; // pg batch 10K 基线（单源本单元，文档单源 benchmarks.md:106）
  DB_PERF_BATCH_PG_ARRAY_MS = 29; // pg array 10K 基线 6.0× vs batch（单源本单元，文档单源 benchmarks.md:106）

function DbPerfIsJ1Pass(const ARatio: Double): Boolean; inline; // perf: inline 常量比对零拷贝（DB_PERF_J1_THRESHOLD 单源），bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE
function DbPerfSyntheticPass(const A2M, AChunk, ADpiProxy, AE2E: QWord): Boolean; inline; // perf: inline 四阈值比对零拷贝（DB_PERF_DM_SYNTHETIC_* 单源），bytes.ops 单源单 Move 复用
function DbPerfRequiresNightlyLive: Boolean; inline; // perf: inline 常量转发零拷贝（DB_PERF_J1_REQUIRES_NIGHTLY_LIVE 单源）
function DbPerfIsSyntheticHonestNotJ1: Boolean; inline; // perf: inline 常量转发零拷贝（DB_PERF_SYNTHETIC_HONEST_NOT_J1 单源，honest not J1）
function DbPerfHasSilentGapIfNoNightly(const AHasNightly: Boolean): Boolean; inline; // perf: inline 静默缺口单源判定零拷贝（DB_PERF_J1_REQUIRES_NIGHTLY_LIVE and honest not J1 and not AHasNightly），稳定性纯函数无资源
function DbPerfShouldBlockCiIfSilentGap(const AHasNightlyEvidence: Boolean): Boolean; inline; // perf: inline CI硬门禁闭环判定零拷贝（同DbPerfHasSilentGapIfNoNightly，缺nightly live时dpi_execute无回归防护需阻塞，见nightly-live.md L3），bytes.ops单源

implementation

function DbPerfIsJ1Pass(const ARatio: Double): Boolean; inline;
begin
  Result := ARatio <= DB_PERF_J1_THRESHOLD;
end;

function DbPerfSyntheticPass(const A2M, AChunk, ADpiProxy, AE2E: QWord): Boolean; inline;
begin
  Result := (A2M <= DB_PERF_DM_SYNTHETIC_2M_MS)
    and (AChunk <= DB_PERF_DM_SYNTHETIC_500CHUNK_10K_MS)
    and (ADpiProxy <= DB_PERF_DM_SYNTHETIC_DPI_PROXY_10K_MS)
    and (AE2E <= DB_PERF_DM_SYNTHETIC_E2E_10K_MS);
end;

function DbPerfRequiresNightlyLive: Boolean; inline;
begin
  Result := DB_PERF_J1_REQUIRES_NIGHTLY_LIVE;
end;

function DbPerfIsSyntheticHonestNotJ1: Boolean; inline;
begin
  Result := DB_PERF_SYNTHETIC_HONEST_NOT_J1;
end;

function DbPerfHasSilentGapIfNoNightly(const AHasNightly: Boolean): Boolean; inline;
begin
  // 稳定性：纯函数无句柄无资源；性能：inline 常量比对零拷贝单源判定（DB_PERF_J1_REQUIRES_NIGHTLY_LIVE honest not J1 单源）
  Result := DB_PERF_J1_REQUIRES_NIGHTLY_LIVE and DB_PERF_SYNTHETIC_HONEST_NOT_J1 and not AHasNightly;
end;

function DbPerfShouldBlockCiIfSilentGap(const AHasNightlyEvidence: Boolean): Boolean; inline;
begin
  // 稳定性：纯函数无句柄无资源；性能：inline 常量比对零拷贝单源闭环（DB_PERF_J1_REQUIRES_NIGHTLY_LIVE+honest not J1 单源，复用DbPerfHasSilentGapIfNoNightly语义，缺证据即阻塞，见nightly-live.md L3 CI硬门禁）
  Result := DbPerfHasSilentGapIfNoNightly(AHasNightlyEvidence);
end;

end.
