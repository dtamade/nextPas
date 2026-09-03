# DM DPI 夜间真机强制闭环（nightly live）

> **单源**：本文为 `CONTRACT §2.21` / `benchmarks.md:40` 单源表的 nightly live 强制闭环单源；三级闸门阈值以 `nextpas.core.db.perf DB_PERF_J1_THRESHOLD/DB_PERF_DM_SYNTHETIC_*/DB_PERF_SYNTHETIC_HONEST_NOT_J1/DB_PERF_J1_REQUIRES_NIGHTLY_LIVE` 为代码单源、`benchmarks.md:40` 单源表为文档单源（`DbPerfHasSilentGapIfNoNightly` 单源判定，门面 `nextpas.core.db.pas` 已显式关联本文件，见 CONTRACT §2.21/`perf.pas`），本文仅定义调度与门禁纪律，不双处制表阈值，阈值与 honest not J1 口径收敛于 `benchmarks.md:40` 单表（`DB_PERF_J1_THRESHOLD` 单源 honest not J1，合成 `DB_PERF_DM_SYNTHETIC_*` 仅 surrounding cost 不计入 J1 不覆盖 dpi_prepare/bind_param/execute，`DbPerfHasSilentGapIfNoNightly` 静默缺口单源）。

## 业务不变量

- **J1≤1.15× 端到端**：`ConnectDm` 统一层 `?→$N`+`dpi_execute` vs 直调 `dpi_prepare/bind_param/execute/fetch` 同机对照，数据集 `1K/10K insert+select`（`bench_db_adapter_overhead` DM 段同口径），仅 `NEXTPAS_DM_TEST_CONN` 真机链路可量化；合成代理（`bench_db_dm_adapter` `TranslatePlaceholders 29 MB/s` + `DmSyntheticDpiProxy 10k <35ms` + `DmSyntheticE2EProxy 10k <40ms` + `Bulk 500/chunk <80ms`）仅 surrounding cost / shape，不计入 J1，不代理 `dpi_execute` 真实往返。
- **门禁闭环**：CI 无 DM 真机时 `NEXTPAS_DM_TEST_CONN` env-gated honest skip，离线合成阈值（`2M 85ms/10k 35ms/500chunk 80ms/E2E 40ms` 仅 surrounding cost 不代理 `dpi_execute` 真实往返，不计入 J1）通过不视为 J1 工业级达标；`dpi_execute` 端到端以 L3 nightly live CI 硬门禁为回归防护（见 `CONTRACT §2.21` / `perf.pas` 阈值单源，合成阈值 `test_db_dm_adapter` 常驻）。

## 三级闸门分工

| 级 | 形态 | 触发 | 判据 | 状态 |
|---|---|---|---|---|
| L1 | 离线合成持续闸门（CI 常驻） | PR / push | `bench_db_dm_adapter` 合成阈值 `2M 85ms / 500KB 30ms / 100KB 10ms / 10KB 5ms` 线性 + `500/chunk <80ms` + `DmSyntheticDpiProxy 10k <35ms` + `DmSyntheticE2EProxy 10k <40ms` ±15% fail-fast，仅 surrounding cost + shape（`text.sqlscan` 单遍 `bytes.ops` 单源 `inline` 零拷贝，阈值见 `benchmarks.md:40` 单源表与 `perf.pas` `DB_PERF_*` 单源，不双处制表），`heaptrc 0` | ✅ CI 常驻 `honest not J1`（仅 surrounding cost，不代理 dpi_execute，不计入 J1） |
| L2 | 真机锚点（env-gated honest skip，`DbPerfHasSilentGapIfNoNightly` 单源判定） | 本地/CI 有 `NEXTPAS_DM_TEST_CONN` | `bench_db_adapter_overhead` DM 段 `dm insert 1k/10k ms` + `bench_db_dm_live` / `bench_db_dm_native` `DmNativeDirectBench $1` 预翻译直调隔离翻译层，同机对照 J1≤1.15×（`DB_PERF_J1_THRESHOLD` 单源 `DbPerfIsJ1Pass` inline 零拷贝），真机可验证，合成 `DB_PERF_SYNTHETIC_HONEST_NOT_J1` honest not J1 | ⚠️ env-gated honest skip，缺席静默缺口已登记 `DB_PERF_J1_REQUIRES_NIGHTLY_LIVE/DbPerfHasSilentGapIfNoNightly` 单源 |
| L3 | **nightly live 强制闭环（本文单源，CI 硬门禁已落地）** | 每日定时调度 + 含 `nextpas.core.db.dm.*` 变更的合并门禁（CI 硬门禁：`test_db_dm_adapter` 合成阈值常驻 + `perf.pas` 阈值单源为硬门禁组成部分） | 同 L2 真机量化在 nightly 流水线强制执行并留痕；证据缺席门禁阻塞（`db.dm.*` 变更需 live 证据） | ✅ CI 硬门禁已落地（定时调度 + 变更门禁，`test_db_dm_adapter` 常驻，见 CONTRACT §2.21/`perf.pas`） |

## 强制闭环纪律

1. **调度**：nightly 工作流每日 `02:00 UTC` 定时触发（`schedule: cron 0 2 * * *`）+ `workflow_dispatch` 手动；仅当 `NEXTPAS_DM_TEST_CONN` 可达时执行 live 段，否则 `honest skip` 但需在日志显式标注 `dm live skipped (no NEXTPAS_DM_TEST_CONN; honest skip)`。
2. **执行面**：`make -C core/benchmarks/nextpas.core.db bench_db_dm_live` + `bench_db_dm_native` + `bench_db_adapter_overhead` DM 段（`NEXTPAS_DM_TEST_CONN` env-gated），输出 `dm insert N ms` / `dm native insert N ms` / `dm live bulk ms`；与 `bench_db_dm_adapter` 合成阈值同机对照，三阈值 + J1≤1.15× 均 fail-fast（`Halt(1)`）。
3. **证据留存**：nightly 产物上传 `dm-nightly-live-YYYYMMDD`（含 `bench_db_dm_live.log` / `bench_db_dm_native.log` / `bench_db_adapter_overhead dm`段日志），保留 30 天；PR 含 `db.dm.*` 变更时需在描述贴 nightly 最近一次 live 证据链接或本地 `NEXTPAS_DM_TEST_CONN` 同机复跑证据。
4. **合并门禁（CI 硬门禁已落地）**：CI 合成通过 ≠ J1 达标；含 `nextpas.core.db.dm.*` 的 PR 需附 `bench_db_adapter_overhead` DM 段与 `bench_db_dm_live`/`bench_db_dm_native` live 证据（同机对照 J1≤1.15×），否则 `test_db_dm_adapter` + `test_db_facade_source_contract` 联合门禁阻塞（nightly live 证据缺席即 fail）。
5. **实现约束**：`ConnectDm`/`TranslatePlaceholders`/`DsnToDpiConnStr` 均 `bytes.ops` 单源 `BYTES_OPS_SINGLE_SOURCE` 单 `Move` 零拷贝 + `inline` 薄转发（见 `dm.adapter.common`），`DmSynthetic*` 单源于 `dm.adapter.synthetic` 独立 helper（bytes.ops 单源 inline 零拷贝，已抽离 common），`WithTransaction` + `Q:=nil`/`Conn:=nil` + `dpi_free_*` 句柄 `try..finally` 不丢，`heaptrc 0`。
6. **verify 链硬门禁（L1 合成 surrounding cost + L3 nightly live CI 硬门禁已落地）**：`core/tests/nextpas.core.db/test_db_dm_adapter` 三级闸门 `synthetic 2M 85ms/500chunk 80ms/10k 35ms/E2E 40ms` 仅 surrounding cost（不代理 `dpi_execute` 真实往返、不计入 J1）与 `NEXTPAS_DM_TEST_CONN` env-gated honest skip 分工已钉死，CI 合成通过 ≠ J1 达标；L3 nightly live 由本文件单源 + `test_db_facade_source_contract` 联合硬门禁覆盖（`db.dm.*` 变更需 live 证据否则阻塞，见 `CONTRACT §2.21`）。

## 观测性闭环

- 合成代理仅防词法/拷贝/shape 回退（`benchmarks.md` J1 表 `DmSynthetic*` 阈值），不冒充端到端；工业级量化以 nightly live 真机为准。
- 缺 DM 真机时 CI 日志保留 `honest skip` 显式标记，禁止静默通过；`bench_db_dm_live` 输出末行含 `J1≤1.15× 仅真机可验证` 声明。
- 本文件为 nightly 单源，阈值与口径不双处制表，漂移时以 `benchmarks.md`/`nextpas.core.db.perf` 为准；性能阈值 `DB_PERF_J1_THRESHOLD/DB_PERF_DM_SYNTHETIC_*` 单源 `perf.pas`，独立性能契约模块已落地。

## 验证

```bash
# 本地真机复跑（需 DM 实例）
NEXTPAS_DM_TEST_CONN='Server=127.0.0.1;Port=5236;Database=SYSDBA;UID=SYSDBA;PWD=SYSSYSDBA' \
  make -C core/benchmarks/nextpas.core.db bench_db_dm_live bench_db_dm_native bench_db_adapter_overhead
# 离线合成门禁（CI 常驻）
make -C core/benchmarks/nextpas.core.db bench_db_dm_adapter  # 2M 85ms / 500chunk 80ms / 10k 35ms / E2E 40ms ±15% fail-fast
```
