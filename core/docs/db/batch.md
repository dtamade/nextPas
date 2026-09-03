# nextpas.core.db — 批量与流分册（batch）

**模块路径**：`core/src/nextpas.core.db.batch*.pas`（`batch`/`batch.strategy`，`batch` 单源收敛 §2.9 大对象流与 §2.16 数组批量）
**层级**：L2 基础设施（仅依赖 L0-L1，严格单向 L0-L2，无上向；见 `CONTRACT.md §1`）
**Owner**：core-db lane
**单源**：本册为 `CONTRACT.md §2.9` + `§2.16` 单源分册，细节沉至本册，索引与分治不变量仍以 `CONTRACT.md` 为准；`capprobe`/`intf`/`base` 仍单源 `CONTRACT.md §2.10`。
**最后更新**：2026-09-02（匠心修复：家族布局表极简瘦身，`inline`/`bytes.ops` 零拷贝证据抽至本册，母册 <500 行薄索引）

---

## 1. 定向

`nextpas.core.db.batch` 是 L2 统一批量/流工厂，收敛 `IDbBlobStream` 大对象流分面（`§2.9`）与数组批量三面（`§2.16`）统一探测与自适应择优，文档不变量与实现复用缺口已对齐。

- **复用 bytes.ops 单源**：`DbBatch*` 统一探测与 `DbBatchWriteRows` 闭环经 `bytes.ops` 单源单 `Move` 零拷贝（`BATCH_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE` 编译期钉死），不自建副本；`TDbBatchFlushHelper` 单源桥接 `BulkCopy>BatchExecutor>BulkFlush` 三择优（见 `nextpas.core.db.batch.pas` 单元头注）。
- **性能**：`DbBatchSupportsBulkCopy/DbBatchSupportsArrayBinding/DbBatchSupportsBatchExecutor/DbBatchTryBulkCopy/DbBatchTryArrayBinding/DbBatchTryLargeObject/DbBatchTryRowBlob/DbBatchTryBatchExecutor/DbBatchProbeArrayBinding` 均为 `inline` 薄转发至 `capprobe`/`intf` 单源（零拷贝，接口引用计数自动归还）；`DbBatchWriteRows` 自适应路由 `DbBatchStrategyPick` 单源（`batch.strategy`），`BulkCopy` 单事务批量行复制经 `TDbBatchFlushHelper` 单源桥接（`BulkCopy>BatchExecutor>BulkFlush` 三择优），单遍 `bytes.ops` 单 `Move` 零拷贝（见 `batch` 单元）。
- **稳定性**：统一批量写入单事务语义（失败全回滚，空表无操作），接口引用计数自动归还；`TDbBatchFlushHelper` 栈 object 零堆，`try..finally` 置 `nil` 归还不丢；流面 `IDbBlobStream` 接口释放即关闭，`BulkCopy.AbortCopy` 异常路径 `try..except` 不丢。

## 2. 契约（CONTRACT §2.9 单源：大对象流 INC-8）

统一流面 `IDbBlobStream`（Read/Write/Seek/Size，接口释放即关闭），开启能力按存储模型分面，消费方经 `QueryInterface` 探测（已收敛至本册统一流工厂附面，经 `DbBatchTryRowBlob`/`DbBatchTryLargeObject`/`DbBatchBlobSupports` `inline` 薄转发单源探测，复用 `bytes.ops` 单源 `inline` 零拷贝，接口引用计数自动归还，见本册 §1）：

- **sqlite（IDbRowBlobControl）**：`OpenRowBlob(table, column, rowid, readwrite)` 定长模型——Size 即单元字节数，写越过末尾抛错（`zeroblob(N)` 预留）；句柄 2GB 上限，行更新/schema 变更须重新 Open。
- **pg（IDbLargeObjectControl）**：OID 模型，事务耦合不对称且强制：CreateLO/OpenLO 要求活动事务，UnlinkLO 要求事务外（`libpq` 自管 BEGIN/END），两向 `fail-fast`，消费方以 `WithTransaction` 包裹读写、事务外删除。
- **内存判据**：流式路径 RSS 恒定（128MB blob 实测增量 0.2MB，见 `benchmarks.md §bench_db_blob_stream`）；`GetBlob` 保留为小 blob 便捷路径。
- **统一工厂**：本册已落地 `L2` 统一批量/流工厂（收敛本节 `IDbBlobStream` 分面与 §2.16 数组批量且 `DbBatchWriteRows` 已闭环 `BulkCopy>BatchExecutor>BulkFlush` 三择优 `TDbBatchFlushHelper` 单源桥接，见 §3 与 `batch` 单元头注；性能 `bytes.ops` 单源 `inline` 零拷贝，稳定性接口自动归还不丢）。

## 3. 契约（CONTRACT §2.16 单源：参数级批量绑定 V3-C2）

单 SQL 每 `?` 绑列数组，一次展开 N 行（pg `unnest` 单次往返，10K 行 `array 29ms vs batch 174ms 6.0×` 见 `benchmarks.md:102`，与 `IDbBatchExecutor` 正交；**PG大批量 MUST 走 array**）。探测 `DbArrayBinding(Q)`（`IDbQuery`，`nil`=未支持），`SupportsArrayBinding⇔接口` 互证（已收敛至本册统一批量工厂，`IDbBulkCopy`/`IDbBatchExecutor`/`IDbArrayBinding` 三面经 `DbBatch*` `inline` 薄转发统一探测，复用 `bytes.ops` 单源 `inline` 零拷贝，接口自动归还不丢；`SupportsArrayBinding True` 仍仅 pg，`SupportsBulkCopy` 见 §2.10 `batch` 正交；`DbBulkFallbackChunkRows=500` 故意绕过 `LRU64` 已以对比基线诚实对照见 `benchmarks.md §bench_db_bulk_copy`）：

- **契约**：`?::type[]` cast 消费方显式；`BeginBind` 必填，全客户端 `fail-fast`（缺/负/长不等/复绑/NUL）；`Step` 强全绑定防 `unnest(NULL)` 零行，混绑 `last-wins`；`NULL` 掩码 `True`=NULL；编码 `int64/bool t-f/Schubfach double/文本 "\""` 转义；`Reset` 重执行正交；先探能力再构方言 `SQL`，`pg=True` 其余 `False` 诚实缺席。**PG大批量强制路径（防6×误用）**：`Kind=dbkPostgres` 且 `N≥500` 时 **MUST** 走 `IDbArrayBinding` unnest 单语句路径（`bench_db_batch_insert` 10K array 29ms vs batch 174ms **6.0×**/txloop 18×），禁止误用 `IDbBatchExecutor` 逐语句合并；判定 `DbBatchShouldUseArrayBinding(Cap, N) inline` 零拷贝（`batch.strategy` 单源 `bytes.ops BYTES_OPS_SINGLE_SOURCE`，接口自动归还，缺能力先反哺 owner `pg.adapter`），门禁 `test_db_array_bind` 钉死；`BulkFlush 500行/chunk` 故意绕过 `IDbStmtCacheControl LRU64` 已以 `bench_db_bulk_copy` `bulk-assemble 500 vs 10000` 单遍拼装 + `bulk-cache-bypass` 5000点查 `hit_rate` 零丢对比基线对照（`2.1-2.4×` 缓存收益正交不污染，`heaptrc 0`）。
- **统一工厂**：本册提供 `DbBatchSupportsArray/DbBatchSupportsBulkCopy/DbBatchExecute` 薄转发 + `DbBatchWriteRows` 已闭环（`BulkCopy>BatchExecutor>BulkFlush` 三择优，`TDbBatchFlushHelper` 单源桥接，`bytes.ops` 单源单 `Move` 零拷贝，接口自动归还，文档不变量与实现复用缺口已对齐），批量与流已同册统一（见 `batch` 单元头注）。

## 4. 依赖与分治不变量

- L2 基础设施：`nextpas.core.db.batch` 仅依赖 L0-L1（`base`/`intf`/`bulk`/`bytes.ops`），无上向；`batch.strategy` 独立策略单源（`DbBatchStrategyPick` 纯函数），`batch` 仅路由执行，复用与单测隔离已分治。
- 业务以 `CONTRACT` 为准、缺能力先反哺 `owner`（批量能力反哺 `nextpas.core.db.batch`，文本/字节反哺 `text.*`/`bytes.ops` 单源）。
- 复用 `bytes.ops` 单源 `inline` 零拷贝证据见 `batch`/`batch.strategy` 单元头注与 `benchmarks.md §bench_db_batch_insert/bench_db_blob_stream`；`batch` 门面仅 `inline` 薄转发至 `capprobe`/`intf` 单源，零直连跨叶重复。

## 5. 门禁

```bash
make focused FOCUS=core/tests/nextpas.core.db/test_db_bulk_copy   # BulkCopy 路径
make focused FOCUS=core/tests/nextpas.core.db/test_db_array_bind  # ArrayBinding 路径
make focused FOCUS=core/tests/nextpas.core.db/test_db_largeobject # 大对象流
```

每个 `gate` 含 `heaptrc 0 unfreed` 硬门禁；`Supports*⇔接口` 互证见 `test_db_conformance`。
