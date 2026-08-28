# nextpas.core.db 终局路线图 — 2026-08-28 封版 (R0 全量可观测收口)

> 依据 `2026-08-23-db-v3-industrial-roadmap.md` 的 V3 三主线，本次封版仅收口 **已落地且可观测** 的 R0-2/R0-3/R1-1 子集，剩余 R1-R5 显式递延。文档与 `benchmarks.md` 四档表、`core/src` 注释保持一致，门禁以 `make focused` 为准。

## 0. 本次封版回答

- L0 热路径是否零分配且 inline 化并可被 bench 直接练习？
- Redis 集群错误是否已归一且 `nextpas.core.db` 门面无业务逻辑泄漏？
- 基准口径是否四档线性且与代码复用 `text.kv` 单真相？
- 聚焦门是否 heaptrc0 且 hygiene/diff-check 零违规？

## 1. 分段与晋级门

### R0-2 文本零分配彻底化

- **冻结**：`RepeatString` 倍增拷贝、`PosEx`/`SplitString` 预分配 + `inline`（`nextpas.core.text.utils`），`Trim/Lower/Upper/IsBlank/Pad` 全 inline 零拷贝直返
- **晋级门**：`ScanKV 355ns vs ParseKV 902ns` 小载荷差保持、`allocs ≈ pairs×2`、`Trim(` 在 `db.*` 全族 0 行、`make focused test_text 33 passed heaptrc0`

### R0-3 超大载荷线性度锚点

- **冻结**：`bench_kv` 固件 `GSmall(~610B)/GMedium(~2263B)/GLarge(~9728B)/GSuperLarge(~21440B,400对×`kN=v_x8`)`，用例 `kv/parse_super~5KB` + `kv/scan_super~5KB`
- **口径**：`TBenchSuite 7样本中位, MinDuration=100ms, -O2, FPC 3.3.1`，报告 `median/mean/p95/thr/allocs`
- **晋级门**：线性 `1.5KB/350B 4.3× 字节对 3.97× 耗时`、`super/1.5KB 2.2× 字节对 2.22× 耗时`，吞吐 530–1015MB/s，`CV 50-80% WARN` 仅环境噪声以 `filtered median` 为准

### R1-1 Redis 集群归一

- **冻结**：`ClassifyRedis` 查表增 `CROSSSLOT→decSyntax / TRYAGAIN→decCapacity / WRONGTYPE→decConstraint`，保留 `BUSYGROUP→decUnknown` 不误归一
- **晋级门**：`test_db_redis_base 11 passed heaptrc0`，纯函数 `lib-consumer` `ClassifyRedis('CROSSSLOT')` + `ParseKV(GSuperLarge 400对)` 400 行直验

## 2. 递延与非目标

- 新增后端/ODBC 第二驱动、达梦 DPI 专用适配器
- 全量 `bench_db_*` 三列重采或 B0 冻结外性能发布
- ORM/分库分表/方言翻译器

## 3. 证据索引

| 证据 | 路径 |
|---|---|
| bench 四档 | `core/build/projects/nextpas.core.text/bench_kv/bench_kv` → `{SCRATCH}/bench-kv.log` |
| 门禁 33/11 | `make focused test_text / test_db_redis_base` → `{SCRATCH}/test-text.log, redis-base.log` |
| 库启动检查 | `ClassifyRedis+ParseKV/ScanKV` consumer → `{SCRATCH}/lib-consumer.log` |
| 卫生 | `make hygiene + git diff --check` → `{SCRATCH}/hygiene.log` |

## 4. 回退症状

- 文本层 `Trim`/`LowerCase` 回退为 `Copy` 分配 → `ScanKV` 吞吐跌破 500MB/s
- 新增 `SysUtils` 直引或 `db` 门面泄漏业务逻辑 → `grep -R SysUtils/Trim(` 违反
- 归一表误把 `BUSYGROUP` 归为容量类 → 集群语义回归
