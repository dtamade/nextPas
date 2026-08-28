# nextpas.core.db 基准口径册（V3-C8）

> 基准是防回归参考与优化判据，不是营销数字。本文固化每个 bench 的
> 口径（数据集/迭代数/判据），登记最近一次全量采集；任何优化提交
> 必须附同口径复跑对照。

## 复跑方法

```bash
# 离线段（sqlite 全量）
make -C core/benchmarks/nextpas.core.db bench

# 含真机 pg/mysql 段（本地实例，test 门 ensure-db 同库）
NEXTPAS_PG_TEST_CONN='host=/var/run/postgresql dbname=nextpas_pg_test user='"$USER" \
  NEXTPAS_MYSQL_TEST_CONN='host=127.0.0.1 port=53307 user=root password=Test123@abc db=testdb' \
  make -C core/benchmarks/nextpas.core.db bench
# mysql 段仅 adapter_overhead 默认启用（batch/bulk 10k 行回环 TCP ~3.6s，不进默认批）
```

设计约束：bench 目标**不接入根 Makefile verify/test 链**（环境噪声
隔离）；编译不带 heaptrc 插桩（扭曲计时）。

## 采集环境

| 项 | 值 |
|---|---|
| 日期 | 2026-08-28 在册；db 段 2026-08-25，text.kv 段 2026-08-28 |
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

| N | native | unified | 比 | mysql (via libmariadb 112B, TCP 回环) |
|---|---|---|---|---|
| 1000 | 2 ms | 2 ms | 1.00× | 337 ms |
| 10000 | 19 ms | 17 ms | 0.89×（噪声内持平） | 3599 ms |

结论：sqlite 适配层开销在测量噪声之下，J1 通过。mysql 回环 TCP 往返
约 0.34 ms/行（10k 行 3.6s），属网络/协议栈成本而非适配层开销——
同口径 `adapter_overhead` 已区分 `native/unified`（内存）与 `mysql`
（网络）三列，避免误比。语句缓存命中后统一层反而省去重复 prepare。

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

### bench_db_async —— 异步挂载开销比（V3-B6 / INC-4）

口径：`SELECT 1` 单飞往返，sync 直调 vs `TDbAsyncExecutor.Submit`
+ WaitFor。计时 `platform_monotonic_ns`；sqlite N=20,000、pg N=2,000，
各预热 100 次；报告均值 / P50 / P99 / max。三轮采集（同机同口径），
pg 第二轮受同机负载噪声影响如实保留。

| backend | sync mean | async mean | 比值 | 固定挂载成本 |
|---|---|---|---|---|
| sqlite :memory: | 1.4–1.7 µs | 16.6–18.0 µs | 10.6–11.6× | ~15–17 µs |
| pg 真机 | 47.6–54.4 µs | 63.4–112.5 µs | 1.23–2.36× | ~12–19 µs |

P99：sqlite 3.8→32.9µs；pg 105.9→116.9µs（噪声轮 614.9µs）。

**结论与使用指引**（CONTRACT §2.17 同步成文）：异步挂载的每次往返
成本 = 两次跨线程唤醒的固定值（~15–20µs），不随负载变化。操作本身
耗时与此同量级时（内存库微查询），倍数放大是物理事实而非实现缺陷
——此类负载不要异步挂载。适用域是长查询/阻塞场景的主线程让出与
取消能力：真机 pg 取消 50M 行聚合 ~200ms 内中断（自然完成秒级）。
>20% 劣化回退条款的评估结论见路线图 B6 回填。

### bench_db_listen —— LISTEN/NOTIFY 投递面（V3-B7）

口径：latency = 单条 NOTIFY → Receive 醒来的端到端耗时（含发送往返
与泵节拍），双泵节拍对照（默认 50ms / 5ms），N=400 各预热 20；
throughput = 分批流水 NOTIFY（100 条/Exec × 20 批，载荷逐条唯一——
同事务同频道同载荷服务端去重只投一条），DroppedCount ≠ 0 即 Halt(1)。
pg 真机段自门控。

| 段 | 指标 | 本次（2026-08-26，Xeon E5-2696 v4，pg 17 本机 socket） |
|---|---|---|
| latency tick=50ms | mean / p99 / max | 50.12 ms / 50.21 ms / 50.26 ms |
| latency tick=5ms | mean / p99 / max | 5.11 ms / 5.20 ms / 5.22 ms |
| throughput（tick=50ms） | 稳态消费 | 2,000 条 / 204 ms ≈ **9,800 条/s**，0 丢弃 |

结论："延迟上界 ≈ 泵节拍 + RTT"契约成立且 p99 紧贴节拍（分布由节拍
主导，无长尾）；节拍降档延迟近线性下移——PQsocket + 平台轮询器
升级若立项，以本表为升级前基线对照。

### bench_db_pool_stress —— 池并发正确性（J2）

口径：read 相位 8 线程 × 3000 轮 Acquire/Exec/Release（策略
MaxReadConnections=4，IdleTimeout/Lifetime 关闭）；writer 相位
4 线程争单写槽（AcquireTimeoutMs=20，busy 计数验证超时路径）。
带 fail-fast 断言：工厂建连数 ≠ 4 即 Halt(1)。

| phase | ops | 耗时 | 吞吐 | 不变式 |
|---|---|---|---|---|
| read(8T) | 24,000 | 269 ms | 89,219 ops/s | opens=4 ✅ |
| writer(4T) | 800 | 7 ms | 114,285 ops/s | busy=0 |

### bench_text_kv —— L0 共享 KV 词法内核（text.kv）

口径：`nextpas.core.text.kv.ParseKV/ScanKV` 单遍 `key=value` 扫描
（分隔符空格或 `;`，`'/"/{}` 包裹），零 `TextBuilder`，`O(n)` 线性；
四档负载 small~80B（MySQL 真实 DSN）、medium~350B（20 对 + 含 `@/=` 引号）、large~1.5KB
（100 对）、super~42KB（~400 对/42KB，400×`kN=v×8;`）；`TBenchSuite` 7 样本取中位，`MinDuration=100ms, MinSamples=7`，
报告 `bytes_per_op/allocs_per_op`。编译 `-O2`，对照 `FPC 3.3.1`。

> 在册数字：2026-08-28 19:30 复采（400对 super=43048B，shared box）；后续新增 DSN 复用方（DM/ODBC）以此为线性度基线。

| workload | bytes | median | mean | p95 | thr(median) | allocs |
|---|---|---|---|---|---|---|
| kv/parse_small~80B | 610 | 825 ns | 1021 ns | 1791 ns | 739 MB/s | 15 |
| kv/parse_medium~350B | 2263 | 2502 ns | 3175 ns | 5795 ns | 904 MB/s | 49 |
| kv/parse_large~1.5KB | 9728 | 9930 ns | 12682 ns | 23581 ns | 979 MB/s | 207 |
| kv/parse_super~5KB | 43048 | 42462 ns | 61614 ns | 135494 ns | 1013 MB/s | 809 |
| kv/scan_small~80B | 322 | 387 ns | 567 ns | 1275 ns | 832 MB/s | 13 |
| kv/scan_large~1.5KB | 4032 | 3760 ns | 6715 ns | 18255 ns | 1072 MB/s | 201 |
| kv/scan_super~5KB | 20232 | 17877 ns | 29402 ns | 74793 ns | 1131 MB/s | 801 |
| kv/validate_small~80B | 0 | 129 ns | 134 ns | 155 ns | — | 0 |
| kv/validate_medium~350B | 0 | 277 ns | 280 ns | 285 ns | — | 0 |
| kv/validate_large~1.5KB | 0 | 1102 ns | 1134 ns | 1151 ns | — | 0 |

结论：吞吐 739–1131 MB/s 量级，`large/medium/small` 均摊 ≈ 1–3 ns/byte，
线性 `O(n)` 成立（`1.5KB/350B ≈ 4.3×` 字节、`9930/2502 ≈ 3.96×` 耗时；
`super ~43KB/9.7KB ≈ 4.4×` 字节、`42462/9930 ≈ 4.27×` 耗时，`ScanKV` 同步线性 —
本表为 `in-process TBenchSuite` 静稳窗口在册，供 `R0-3` 超大 DSN 线性度回归锚点；
扫描在 shared box 上 `CV≈50–80% WARN` 为环境噪声常态，以 `filtered median` 为准）。
`ScanKV` 零分配回调查表比 `ParseKV` 数组装箱快约 50–60%（small 387ns
vs 825ns），供热路径回调复用。allocs ≈ pairs×2 + 固定开销，印证零
中间 `Builder`。复用面：`db.mysql/pg/odbc dsn` + `db.redis addr` +
`db.factory driver名` 均已零分配化（`ValidateKV` 真零分配前置 `empty`
免 `Trim` 拷贝、非法单遍 `fail-fast` 不触达 `libpq/libmysql/odbc`；
`redis` host 去 `Trim` 双拷贝、`factory` 去 `LowerCase(Trim)` 双拷贝；
`Val(LTail,LCode,LCode)` 冗余清理），`ODBC` 分号+花括号
（`Driver={DM8 ODBC DRIVER};`）同源复用，`DM` 等同形态 DSN 零新增词法
——`text.kv` 现为 **MySQL/PG/ODBC/DM 四形态 + factory/redis 零分配**
统一底座，`bench_text_kv` 为性能锚点（零分配不变量以本表为准，`core/src/nextpas.core.db.*` 家族 `Trim(` 2 行收敛至 `text.utils` 单源——`factory NormalizeLowerTrim` + `redis Trim`，29 门离线基线：26 db + 3 text）。

> **口径显式化**：本表 `bytes` = `TBenchSuite` 的 `bytes_per_op`（见 `build/bench-kv.json`），非 `Length(GSuperLarge)` 实串长度；`GSuperLarge` 实串 `Length≈7383B`（400×`kN=v_x8;` 去尾空格），而 `bytes_per_op 43048B` 为 `bench` 侧统计口径（含框架 `bytes` 计数），二者差异为口径所致，非回归。归一路径：`factory`/`redis` 统一走 `nextpas.core.text.utils.NormalizeLowerTrim` 单源（`core/src/nextpas.core.db.*` 保持 `Trim(` 0 行）。

> **ValidateKV 微 bench**（S5b）：`bench_kv` 新增 `kv/validate_small/medium/large` 三用例，覆盖 `ValidateKV` 零分配校验路径（`allocs 0`，`bytes` 同档），与 `parse/scan` 同表对照，供 `ScanKV` 复用前后不变量锚点。

> 复跑噪声对照（2026-08-28 09:15 同机）：small median 797ns/mean 984ns
> 持平，medium mean 9831ns（×3.1）、large mean 60971ns（×4.9）同步膨胀，
> 与既往 `bench_db_async` 共享机器负载取证一致（调度/往返敏感、纯计算
> 稳定），不判回归；静稳窗口重采以本表为准。

### bench_db_stmt_cache 表注

2026-08-26 复采中 pg cached point 跨过 ±15% 带（−23%），环境取证与
裁决见文末「复采记录」。

## 复采记录（2026-08-26）

全量同机同口径复采（Xeon E5-2696 v4，pg 17 本机 socket，FPC 3.3.1
-O2），逐项对照 2026-08-25 基线。

**噪声带内（±15%），基线维持**：adapter_overhead（J1 持平）、
translate_complexity（线性度成立）、batch_insert pg 四路（autocommit
22,360 / txloop 571 / batch 166 / array 32 ms，对基线 +2.4% / +8.6% /
−4.6% / +10.3%）、blob_stream（stream +0.2 MB）、pool_stress
（opens=4、busy=0）、stmt_cache sqlite 两路（nocache +5.9%、cached
−7.1%，hit_rate=1.0000）、listen 双节拍（50.13 ms / 5.12 ms，吞吐
9,847 条/s 零丢弃，与在册同量级）。

**跨过阈值项与裁决**：

- stmt_cache pg point cached：16,165 ops/s 对在册 20,973（−23%）；
  同轮 nocache 仅 −3.9%。取证：路径源码未变（git）、libpq/PG 版本
  未变（dpkg.log 无升级记录）、纯计算指标（sqlite 点查 sync 1.4µs）
  不动；而 IPC 往返地板整体抬高——bench_db_async pg sync SELECT 1
  均值 56–60µs（在册 47.6–54.4）、sqlite 异步固定挂载成本 ~23–26µs
  （在册 ~15–17）。多处调度/往返敏感指标同步抬升而计算路径纹丝
  不动，归因共享机器共租负载（复采窗口 load≈8–11 持续，另有外部
  进程每 60s 对集群做健康探测）。基线维持为参考；静默窗口复测若
  pg cached 仍 ≤17K 再立回归案。
- bench_db_async 比值段：sqlite 16.8–19.2×（在册 10.6–11.6×）即上
  款同一地板抬升的调度侧写，非实现回归；pg 比值 1.27–1.82× 在册
  区间内。

**附带事件（已收口）**：bench_db_async 高负载下间歇 AV@RIP=0（约
2/6 次，本轮复采首次暴露）。根因（gdb 回溯 + valgrind + 生命周期
插桩链式定位）：`TDbAsyncExecutor.Submit` 的句柄唯一接口引用寄存
于 op 记录字段，而 FPC 类指针不保活（构造贷返还后 rc=0），worker
可在 Submit 取回 Result 前完成执行+finalize+Dispose 整个周期并触
发析构——消费方拿到已释放内存。修复：本地 `LHeld: IDbAsyncHandle`
首个接口引用先行持有（单元头时序不变式 b 成文）；test_db_async 增
设 5 万次微工作体高频提交回归段。修复后 solo ×10、focused 门禁
13/13（heaptrc 分配释放精确平衡）、bench 四轮、gdb 连续二十轮猎捕
全部干净。本记录 async 数字采自修复后轮次。

## 登记纪律

- 优化提交引用本文数字时必须注明「同机同口径复跑」并给出前后对照。
- 数字漂移 ±15% 内视为环境噪声（共享机器）；跨过阈值先查环境再谈回归。
- 新增 bench 必须同步扩充本文口径表，缺口径的 bench 视为不存在。

## 验证锚点 2026-08-29 — 同步至 main 3a23647bd（perf(time) Digits/TimeBucketKey O(n) + perf(bytes) Bytes↔String 单源化 + window 3.8 + tlspas P-384）

- 聚焦门：`test_text 33` / `test_bytes 35` / `test_db_redis_base 12` / `test_db_pool_v2 21` / `test_db_mysql_adapter 7` / `test_git_native 114` / `test_time_bucket 7` / `test_multipart 13` 均 `heaptrc 0`（见 `{SCRATCH}/test_*.log`，`3a23647` 复跑 33/35/12/21/7/114/7/13 绿，含 time.bucket 单分配 + bytes 单源 + window 3.8）
- 基准：`bench_kv 10`（`validate 0 allocs/bytes 0`，在册 `129/277/1102 ns` 静稳中位，当前 `123/354/1130 ns` 紧贴在册，`0 allocs` 不变量稳，`build/bench-kv.json` 10 executed，见 `{SCRATCH}/bench-kv.json`）
- 卫生：`make hygiene pass` / `git diff --check 0` / `db.* Trim( 2 行 text.utils 单源` + `git.native Hex/Bytes/fetch + bytes.ops 单源`（见 `{SCRATCH}/hygiene.log` / `grep_*.log`）
