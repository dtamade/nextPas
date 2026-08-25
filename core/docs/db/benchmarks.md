# nextpas.core.db 基准口径册（V3-C4）

> 基准是防回归参考与优化判据，不是营销数字。本文固化每个 bench 的
> 口径（数据集/迭代数/判据），登记最近一次全量采集；任何优化提交
> 必须附同口径复跑对照。

## 复跑方法

```bash
# 离线段（sqlite 全量）
make -C core/benchmarks/nextpas.core.db bench

# 含真机 pg 段（本地实例，test 门 ensure-db 同库）
NEXTPAS_PG_TEST_CONN='host=/var/run/postgresql dbname=nextpas_pg_test user='"$USER" \
  make -C core/benchmarks/nextpas.core.db bench
```

设计约束：bench 目标**不接入根 Makefile verify/test 链**（环境噪声
隔离）；编译不带 heaptrc 插桩（扭曲计时）。

## 采集环境

| 项 | 值 |
|---|---|
| 日期 | 2026-08-25 |
| CPU | Intel Xeon E5-2696 v4 @ 2.20GHz ×44 |
| 内存 | 62 GiB |
| 内核 | Linux 6.12.101+deb13-amd64 |
| 工具链 | FPC 3.3.1 trunk，-O2 |
| PostgreSQL | 17.11（本地 unix socket，同机） |
| sqlite | 系统 libsqlite3（loader 探测绑定） |

## 判据（硬线）

| # | 判据 | 阈值 | 本次 |
|---|---|---|---|
| J1 | 裸驱动开销比：统一层 vs 直调 conn 层 insert+select 耗时比 | **≤1.15×** | ✅（见下，本次噪声内持平） |
| J2 | 池读路径建连数不变式：8 线程锤满 3000 轮，工厂建连数 == MaxReadConnections | 恰好相等 | ✅ opens=4/4 |
| J3 | 大对象流式内存界：128MB blob 流式读写 RSS 峰值增量 | ≤ 数 MB（chunk 级） | ✅ +0.2MB |

## 逐 bench 口径与本次数字

### bench_db_adapter_overhead —— 统一层开销比（J1）

口径：内存库单事务 N 行参数化 INSERT + SUM SELECT 往返；native =
直调 `TSqliteDb`（conn 层），unified = `ConnectSqlite` 适配层；
`Sizes=(1000,10000)` 固定。

| N | native | unified | 比 |
|---|---|---|---|
| 1000 | 2 ms | 2 ms | 1.00× |
| 10000 | 19 ms | 17 ms | 0.89×（噪声内持平） |

结论：适配层开销在测量噪声之下，J1 通过。语句缓存命中后统一层
反而省去重复 prepare。

### bench_db_translate_complexity —— 占位符翻译线性度

口径：`? → $N` 拼接模式对纯文本长度 `(10K, 100K, 500K, 2M)` 单遍
翻译耗时（无真实 SQL 语义，纯扫描成本上界参考）。

| len | ms |
|---|---|
| 10,000 | 1 |
| 100,000 | 5 |
| 500,000 | 21 |
| 2,000,000 | 70 |

线性度成立（≈29 MB/s 量级）；SQL 文本远小于此规模，非热路径。

### bench_db_batch_insert —— 批写入四模式（C4 基线 + C2 array）

口径：N=10000 行、两列参数化 INSERT。autocommit=逐行自动提交；
txloop=手动 BEGIN..COMMIT 包裹逐行；batch=`IDbBatchExecutor`
多语句合并单次往返；array=`IDbArrayBinding` unnest 单语句参数级
批量（V3-C2，绑定/编码计入计时口径）。array 段仅能力后端执行，
sqlite 诚实缺席。

| backend | autocommit | txloop | batch | array |
|---|---|---|---|---|
| sqlite | 34 ms | 18 ms | 23 ms | —（未实现） |
| postgres | 21,830 ms | 526 ms | 174 ms | **29 ms** |

pg 四路阶梯：array 在 batch 之上再 **6.0×**（对 txloop **18×**，对
autocommit **~750×**），稳态 ≈345K 行/s——batch 合并往返但仍解析/
规划 10K 条语句；array 单语句两参数，解析规划各一次 + 服务端 unnest
展开。（2026-08-25 同日四路同采，Xeon E5-2696 v4；array 首轮冷启
42ms，稳态两轮 29/29；历史 C4 采集中 batch 曾录得 190ms，均在登记
噪声带口径内。）

### bench_db_stmt_cache —— 透明语句缓存（INC-3/C1）

口径：point=主键等值查 N_POINT=50,000 次（KEYS=512 键空间）；
scan=范围扫 N_SCAN=2,000 次；cached 模式预热一轮进稳态后计量，
报告命中率。

| workload | backend | nocache | cached | 加速 | hit_rate |
|---|---|---|---|---|---|
| point | sqlite | 230,414 ops/s | 549,450 ops/s | **2.39×** | 1.0000 |
| scan | sqlite | 12,903 ops/s | 14,184 ops/s | 1.10× | — |
| point | pg | 9,904 ops/s | 20,973 ops/s | **2.12×** | — |
| scan | pg | 2,275 ops/s | 3,053 ops/s | 1.34× | — |

### bench_db_blob_stream —— 大对象流式内存界（J3）

口径：128MB blob 写入+读回。materialize=整块 GetBlob 物化；
stream=256KB chunk 流式区间读写（INC-8）。pg 段 64MB lo_* 流。

| mode | blob_mb | RSS 峰值增量 |
|---|---|---|
| materialize | 128 | +256.2 MB |
| stream | 128 | **+0.2 MB** |
| pg-stream(lo_*) | 64 | +0.3 MB |

物化路径峰值 ≈ blob 的 2 倍（读+写各一份），流式恒定 chunk 级——
大 blob 必须走流式接口的消费指引依据。

### bench_db_pool_stress —— 池并发正确性（J2）

口径：read 相位 8 线程 × 3000 轮 Acquire/Exec/Release（策略
MaxReadConnections=4，IdleTimeout/Lifetime 关闭）；writer 相位
4 线程争单写槽（AcquireTimeoutMs=20，busy 计数验证超时路径）。
带 fail-fast 断言：工厂建连数 ≠ 4 即 Halt(1)。

| phase | ops | 耗时 | 吞吐 | 不变式 |
|---|---|---|---|---|
| read(8T) | 24,000 | 269 ms | 89,219 ops/s | opens=4 ✅ |
| writer(4T) | 800 | 7 ms | 114,285 ops/s | busy=0 |

## 登记纪律

- 优化提交引用本文数字时必须注明「同机同口径复跑」并给出前后对照。
- 数字漂移 ±15% 内视为环境噪声（共享机器）；跨过阈值先查环境再谈回归。
- 新增 bench 必须同步扩充本文口径表，缺口径的 bench 视为不存在。
