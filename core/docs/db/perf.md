# nextpas.core.db — 性能契约分册（perf）

**模块路径**：`core/src/nextpas.core.db.perf.pas`（独立性能契约单源）
**层级**：L2 基础设施（仅依赖 L0-L1 `bytes.ops`，无上向；见 `CONTRACT.md §1`）
**Owner**：core-db lane
**单源**：本册为 `CONTRACT §2.21` 阈值与 `benchmarks.md:40` 单源表之索引分册，文档级阈值以 `perf.pas DB_PERF_J1_THRESHOLD/DB_PERF_DM_SYNTHETIC_*` 为代码单源，`benchmarks.md:40` 为文档单源（`DbPerfHasSilentGapIfNoNightly` 单源判定），本文仅承载诚实口径与性能证据，不双处制表阈值。
**最后更新**：2026-09-02（匠心修复：家族布局表极简瘦身，`inline`/`bytes.ops` 零拷贝证据抽至本册，母册 <500 行薄索引）

---

## 1. 定向

`nextpas.core.db.perf` 是 L2 独立性能契约单源，收敛 DM DPI 原生路径 J1 与合成闸门阈值（`DB_PERF_J1_THRESHOLD/DB_PERF_DM_SYNTHETIC_*`），三级闸门见 `nightly-live.md` 单源。

- **复用 bytes.ops 单源**：`PERF_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE` 编译期钉死（`BYTES_OPS_SINGLE_SOURCE` 单源，见 `perf.pas` 头注），不自建副本。
- **性能**：`DbPerfIsJ1Pass/DbPerfSyntheticPass/DbPerfRequiresNightlyLive/DbPerfIsSyntheticHonestNotJ1/DbPerfHasSilentGapIfNoNightly/DbPerfShouldBlockCiIfSilentGap` 均为 `inline` 常量比对零拷贝（`DB_PERF_J1_THRESHOLD/DB_PERF_DM_SYNTHETIC_*` 单源，单 `Move` 复用，见 `perf.pas`）。
- **稳定性**：纯常量无资源，句柄不丢；`DbPerfShouldBlockCiIfSilentGap` 复用 `DbPerfHasSilentGapIfNoNightly` 单源闭环，缺证据即阻塞（L3 CI硬门禁）。

## 2. 契约（CONTRACT §2.21 与 benchmarks.md:40 单源）

- **J1≤1.15× 仅 `NEXTPAS_DM_TEST_CONN` 真机可量化**，CI 合成仅 `surrounding cost honest not J1` 不计入 J1（`DB_PERF_J1_THRESHOLD=1.15` 单源 `nextpas.core.db.perf` `DbPerfIsJ1Pass` `inline` 零拷贝 `honest not J1`，仅真机端到端，合成不覆盖 `dpi_prepare/bind_param/execute`；口径以 `benchmarks.md:40` 单源表为准，见 `perf.pas`/`benchmarks.md:40` 单源）。
- **合成闸门仅 surrounding cost**：`DB_PERF_DM_SYNTHETIC_2M_MS=85` / `500K=30` / `100K=10` / `10K=5` / `500CHUNK_10K=80` / `DPI_PROXY_10K=35` / `E2E_10K=40` 均仅 surrounding cost，`±15% fail-fast`，不代理 `dpi_execute` 真实往返，不计入 J1（`DB_PERF_SYNTHETIC_HONEST_NOT_J1=True` 单源，见 `nightly-live.md` L1）。
- **三级闸门**：L1 离线合成持续闸门 CI 常驻（仅 surrounding cost + shape，`heaptrc 0`，`test_db_dm_adapter`） + L2 真机锚点 env-gated `honest skip`（`bench_db_adapter_overhead` DM 段 + `bench_db_dm_live`/`bench_db_dm_native`） + L3 nightly live 强制闭环 CI 硬门禁（每日 02:00 UTC 定时 + 含 `db.dm.*` 变更合并门禁，需 live 证据否则阻塞，见 `nightly-live.md` 单源）。
- **静默缺口**：缺 nightly live 时 `dpi_execute` 端到端无回归防护属已登记静默缺口（`DB_PERF_J1_REQUIRES_NIGHTLY_LIVE=True` + `DbPerfHasSilentGapIfNoNightly` 单源判定，`DbPerfShouldBlockCiIfSilentGap` CI硬门禁闭环同语义，见 `nightly-live.md` L3；`perf.pas` 为代码单源，`benchmarks.md:40` 为文档单源；CI 日常合成通过≠J1达标，含 `db.dm.*` 变更无live证据视为阻塞）。

## 3. 依赖与分治不变量

- L2 基础设施：`nextpas.core.db.perf` 仅依赖 L0-L1（`bytes.ops`），无上向，无同层循环；阈值单源于 `perf.pas`，`CONTRACT`/`benchmarks`/`nightly-live` 仅索引不双处制表防漂移。
- 业务以 `CONTRACT` 为准、缺能力先反哺 `owner`（性能能力反哺 `nextpas.core.db.perf`，字节反哺 `bytes.ops` 单源）。
- 复用 `bytes.ops` 单源 `inline` 零拷贝证据见 `perf.pas` 单元头注与 `benchmarks.md §bench_db_dm_adapter/bench_db_adapter_overhead`。

## 4. 门禁

```bash
make focused FOCUS=core/tests/nextpas.core.db/test_db_dm_adapter   # 合成闸门（仅 surrounding cost honest not J1，CI 常驻）
# 真机锚点 env-gated honest skip：
NEXTPAS_DM_TEST_CONN='Server=127.0.0.1;Port=5236;Database=SYSDBA;UID=SYSDBA;PWD=SYSSYSDBA' \
  make -C core/benchmarks/nextpas.core.db bench_db_dm_live bench_db_dm_native bench_db_adapter_overhead
# nightly live 见 nightly-live.md 单源（L3 CI 硬门禁）
```

含 `heaptrc 0` 硬门禁；`J1≤1.15×` 仅 nightly live 真机可量化，CI 合成 `honest not J1`（`DbPerfIsSyntheticHonestNotJ1` 单源），缺 nightly live 静默缺口 `DbPerfHasSilentGapIfNoNightly`/`DbPerfShouldBlockCiIfSilentGap` 单源闭环判定（L3 CI硬门禁）。
