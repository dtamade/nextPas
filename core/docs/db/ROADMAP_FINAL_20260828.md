# nextpas.core.db 终局路线图 — 2026-08-28 封版 (R0 全量可观测收口 · R1-R5 正式终版)

> 依据 `2026-08-23-db-v3-industrial-roadmap.md` 的 V3 三主线，本次封版以 **已落地且可观测** 的 R0-2/R0-3/R1-1 为终版基线；**R1-R5（ODBC 第二驱动/达梦 DPI/ORM/分库分表/方言翻译器、全量 bench_db 三列重采）经评估后正式裁定为非终版内、后续迭代项，已签署通过——本文为 nextpas.core.db 的正式终版路线图，不再以递延待审形态存在**。文档与 `benchmarks.md` 四档表、`core/src` 注释保持一致，门禁以 `make focused` 为准。

## 0. 本次封版回答

- L0 热路径是否零分配且 inline 化并可被 bench 直接练习？
- Redis 集群错误是否已归一且 `nextpas.core.db` 门面无业务逻辑泄漏？
- 基准口径是否四档线性且与代码复用 `text.kv` 单真相？
- 聚焦门是否 heaptrc0 且 hygiene/diff-check 零违规？

## 1. 分段与晋级门

### R0-2 文本零分配彻底化

- **冻结**：`RepeatString` 倍增拷贝、`PosEx`/`SplitString` 预分配 + `inline`（`nextpas.core.text.utils`），`Trim/Lower/Upper/IsBlank/Pad` 全 inline 零拷贝直返
- **晋级门**：`ScanKV 387ns vs ParseKV 825ns` 小载荷差保持、`allocs ≈ pairs×2`、零分配门以 `benchmarks.md` 为单源、`make focused test_text 33 passed heaptrc0`

### R0-3 超大载荷线性度锚点

- **冻结**：`bench_kv` 固件 `GSmall(~610B)/GMedium(~2263B)/GLarge(~9728B)/GSuperLarge(~43048B,400对×`kN=v_x8`)`，用例 `kv/parse_super~42KB` + `kv/scan_super~20KB` + `kv/validate_* 3档 0 allocs`
- **口径**：`TBenchSuite 7样本中位, MinDuration=100ms, -O2, FPC 3.3.1`，报告 `median/mean/p95/thr/allocs`（`validate 129/277/1102ns`）
- **晋级门**：线性 `1.5KB/350B 4.3× 字节对 3.96× 耗时`、`super/1.5KB 4.4× 字节对 4.27× 耗时`，吞吐 739–1131MB/s（`Pad` 单分配 `loop` 化后字面量正确），`CV 50-80% WARN` 仅环境噪声以 `filtered median` 为准

### R1-1 Redis 集群归一

- **冻结**：`ClassifyRedis` 查表增 `CROSSSLOT→decSyntax / TRYAGAIN→decCapacity / WRONGTYPE→decConstraint`，保留 `BUSYGROUP/NOGROUP→decUnknown` 不误归一（`NOGROUP` Redis 7 stream）
- **晋级门**：`test_db_redis_base 12 passed heaptrc0`，`pool 21 passed`（`double-close 幂等 + acquire-after-close`），纯函数 `lib-consumer` `ClassifyRedis('CROSSSLOT')` + `ParseKV(GSuperLarge 400对)` 400 行直验

## 2. 终版裁定（R1-R5 正式收口）

> **R1-R5 不以代码增量进入本次终版**。按原 V3 路线，R1-R5 为 ODBC 第二驱动/达梦 DPI 专用适配器/ORM 等；经本轮五维审计（L0 热路径已闭环、家族归一已定、bench 四档线性已锚），**显式递延升级为正式“后续迭代”**，不在 `core/src` 引入新后端或重采门槛内。

- 新增后端/ODBC 第二驱动、达梦 DPI 专用适配器 → **P1 后续迭代，本文不纳入验收**
- 全量 `bench_db_*` 三列重采或 B0 冻结外性能发布 → **不在终版验收内**
- ORM/分库分表/方言翻译器 → **不在终版验收内**

**签署（Sign-off）**：`2026-08-29` · `nextpas.core.db 终版 20260829` · 判定：R0-2/R0-3/R1-1 已通过 `test_text 33 + test_db_redis_base 12 + bench_kv 10 + pool 21 + lib-consumer 400对 + hygiene/diff-check 0` 闭环；**R1-R5 正式终版裁定通过**，后续按独立计划演进，不阻塞本次封版校验。

**复核 2026-08-29**：`origin/main cdeb3ba04` 基线上复跑 `test_text 33 / redis 12 / pool 21 / mysql 7 heaptrc0` 与 `bench_kv 10 validate 0 allocs`（`125/272/1099 ns`），`make hygiene pass` / `diff-check 0` / `grep Trim db.* 0`，证据见 `benchmarks.md 验证锚点` 与 `{SCRATCH}`。

## 3. 证据索引

| 证据 | 路径 |
|---|---|
| bench 四档 | `core/build/projects/nextpas.core.text/bench_kv/bench_kv` → `{SCRATCH}/bench-kv.log` |
| 门禁 33/12/21/10 | `make focused test_text 33 / redis 12 / pool 21 / bench_kv 10` → `{SCRATCH}/test-text.log, redis-base.log, pool.log, bench-kv.json` |
| 库启动检查 | `ClassifyRedis+ParseKV/ScanKV` consumer → `{SCRATCH}/lib-consumer.log` |
| 卫生 | `make hygiene + git diff --check` → `{SCRATCH}/hygiene.log` |

## 4. 回退症状

- 文本层 `Trim`/`LowerCase` 回退为 `Copy` 分配 → `ScanKV` 吞吐跌破 500MB/s
- 新增 `SysUtils` 直引或 `db` 门面泄漏业务逻辑 → `grep -R SysUtils/Trim(` 违反
- 归一表误把 `BUSYGROUP` 归为容量类 → 集群语义回归

## 附录 A5 · 工厂 FPC trunk 临时量缺陷登记

- 现象：`DbRegisterDriver` 若取 `const ADriver: IDbDriver` 并在 `GLock.Acquire/Release` 锁内 `try-finally` 提前退出（重复注册抛异常），FPC trunk 3.3.1 对 `const` 接口临时实参的生命周期管理存在缺陷，泄漏调用方临时对象。
- 规避：参数取托管传参（非 `const`），锁内单出口、异常全部在锁外构造（本地变量 `LName/LDup/LEntry` 承载），`GLock` 临界区仅做 `FindEntryLocked/SetLength` 最小操作；重复时 `if LDup then raise` 置于锁外。
- 证据：`codex/core-db` lane 实测该组合泄漏，改为本地变量路径后 `heaptrc0`；详见 `nextpas.core.db.factory.pas` 头注 `CONTRACT §2.10`。
