# nextpas.core.git — 历史契约（history）

**模块路径**：`core/src/nextpas.core.git.native.{revwalk,commitgraph,reflog,revparse,log,describe,diff,blame,mergebase,show,shortlog,catfile,cherrypick,revert}.pas` + `nextpas.core.git.native.history.{traversal,query,ops}.pas` 3 分片 + `nextpas.core.git.native.history.pas` umbrella
**层级**：L2（L0-L1: base, bytes, text, fs, io；依赖 objects 域 `repo/objmodel/pack`）
**Owner**：git lane
**不变量域**：历史遍历与查询（revwalk / commit-graph / 日志 / 差异 / 归因 / 合并基）

## 1. 范围与阈值
- 源聚合：14 单元 + 3 分片 + 1 umbrella（`native.history`），按不变量域预拆：`traversal`（revwalk/commitgraph/reflog/revparse，4 单元，<210 行）`query`（log/describe/diff/blame/mergebase/show，6 单元，<260 行）`ops`（shortlog/catfile/cherrypick/revert，4 单元，<180 行）；umbrella 为薄索引 <80 行（总 CONTRACT 阈 <380 行，umbrella 自身零转发仅 `deprecated TGitOid` BC 别名，总门面指 umbrella 档位 <600，已移除 46 inline 全量转发）；新代码一律分片直引（`history.traversal / query / ops`）以维持复用度与极简网关，umbrella 仅 BC 索引；历史层不自建对象/压缩，仅复用 owner（bytes.ops 单源）。
- Commit-graph 单文件 `nextpas.core.git.native.commitgraph.pas` 约 1320 行超 `design-conventions §2` 800 行软阈，属**历史域内聚例外**（reader+writer+cache+collect 共享 CGPH/OIDF/OIDL/CDAT/EDGE 不变量与 mmap owner）；已加内部 region 标记 Cache/Reader/Writer/Collect 以保分层可审计性，拆分会稀释 ownership 并引入 double-cache / 合入冲突，故保留单文件，演进见 §6。

## 2. 不变量
- Revwalk：committer-date 降序游标 + topo 序一次性规划（LIFO 就绪栈复刻 `REV_SORT_IN_GRAPH_ORDER`），first-parent / hide+boundary / since-until（0=无界，仅裁剪发射仍遍历父链），每提交恰一次 `ReadObject+Parse`，commit-graph 透明加速（命中免 inflate/parse）。
- Commit-graph v1：`CGPH + OIDF/OIDL/CDAT/EDGE + 尾 SHA-1`，fanout 累积 + OID 排序 + 36B/CDAT + EDGE 溢出，`Build/Write/WriteAll/Verify/Invalidate` 3 块无 GDA2 最小闭合；`Write*` 经 `WriteAtomic` 原子落盘 + 内存/文件双重 Verify + Invalidate；`TryLoad` 经 `Stat.mtime+size` 缓存 `IMappedFile` 零堆复制 `MmapOpen`（`Cap=16` 8→16 半减多仓 thrash，`PByte` 零拷贝 via `io.mapped`，`bytes.ops` 单源，OS page-reclaimable，`inline` O(1) Seq touch + O(Cap) victim 扫描 trivial 16×UInt64 <30ns 无线性搬移/接口拷贝抖动，波动门禁见 §3）；`WriteAll` 聚合 `refs/heads+HEAD+tags` 起止；对齐 `git commit-graph write/verify`。
- Diff/Blame：扁平化递归 + 字典排序 + 归并（Added/Modified/Deleted/TypeChanged，零重命名，peel 16 层）；blame 经 LCS 行 diff + head-vs-each 最老匹配，线性史，对齐 `git blame --porcelain`；blame `ComputeMatches` 阈值 `BLAME_HIRSCHBERG_CELLS_LIMIT=1M`（was 10M in native-reference-map）Hirschberg精确 LCS vs 哈希回退 `O(N log N+M log U)`，1M边界经 `bench_git Blame/*` + `test_git_native` 回归基线双重覆盖（1k×1k Hirschberg ~3ms vs fallback ~0.8ms，2k×2k/3k×3k 回退5×更快，避免 `C * n*m` 放大；大文件 `3k×3k=9M` 回退 `O(N log N)` 排序开销经 `TestBlameLargeFileFallback` 3000×3000 回归基线锁定（fallback ~6-8ms vs Hirschberg ~27ms 3-4×，排序 `BlameQuickSort` + `BlameFindLine` 二分 `O(N log N+M log U)`，单源 `HashString` FNV-1a + `bytes.ops GrowArrayCapacity`，无 `N*2` Table  spike），LcsForwardReuse 零拷贝 swap 消除 `Move` 双缓冲 `O(m)` Bulk Copy，复用 `bytes.ops GrowArrayCapacity` 单源，`inline` 热路径零分配，`not inline` 守 I-Cache 红线）；`Delta/Apply|ApplyReuse:inline` 复用 `bytes.ops` `GitApplyDeltaInto` + `GReuseBuf` 单源（`TByteSpan` 零拷贝）。
- Log/Describe/Show/Shortlog/Catfile/Cherry-pick/Revert：`rev-parse` 剥离 16 层 + `revwalk` date 序聚合，对齐 `git log/show/shortlog/cat-file/cherry-pick/revert` 黄金。

## 3. 性能契约（复用 bytes.ops 单源）
- `Delta/Apply|ApplyReuse:inline` ≤5 µs/op（≥200 Kop/sec），`TByteSpan` 零拷贝 + 复用缓冲，不触 `SysUtils`；`Revwalk` 单次交付，零重复解析。
- `CommitGraph/CacheHit|Miss`：`Cap=16` LRU `O(1)` touch + `O(Cap)` victim 扫描 <30ns，`PByte` 零拷贝 `IMappedFile` via `io.mapped`，`bytes.ops` 单源；多仓并发 8-repo 命中率门禁 `bench_git CommitGraph/CacheHit (mmap hit <5µs)` vs `CacheMiss (mmap rebuild + verify <50µs)`，波动门禁 10-15% jitter + `10@200ms` 双锚（提交态 baseline.json + 绝对 SLO），超 `2×CV` 且 `ratio>1.10`（CV>10% 则 >1.15）判回归，避免多仓频繁驱逐重建 mmap 放大。
- `Blame/ComputeMatches`: Hirschberg `≤3ms/1M cells (1k×1k exact LCS, zero-copy swap, reused buffers via bytes.ops GrowArrayCapacity, not inline per red line 2)` vs fallback `≤0.8ms/1M (sorted dedup O(N log N+M log U), HashString single source FNV-1a, bytes.ops GrowArrayCapacity)`，大文件 `3k×3k=9M → fallback 6-8ms vs Hirschberg 27ms (3-4×, 2k×2k=4M fallback 2.1ms vs Hirschberg 12ms 5×)`；阈值 `BLAME_HIRSCHBERG_CELLS_LIMIT=1M` 避免 `C * n*m` 跨提交放大，`bench_git Blame/ComputeMatches:1k×1k/2k×2k/3k×3k` + `test_git_native` blame黄金覆盖阈值边沿（1000×1000 exact vs 1001×1000 fallback）+ 大文件 `3000×3000` 回归基线 `TestBlameLargeFileFallback`（排序 `O(N log N)` 开销锁定，单源 `HashString` + `bytes.ops`，无 Table spike，零拷贝）+ `head-vs-each` blob-cache 零重复 LCS。
- 抖动余量 10-15%，同机 `-O3 -Xs` 无 heaptrc 中位数，绝对阈值 + 基线双锚（见总 CONTRACT §7 的 Go/Rust A/B 归一）。

## 4. 稳定性
- `TCommitGraph`/`TPackFile` 析构释放；`revwalk` 队列 `try..finally`；`cherry-pick/revert` 经 `checkout` 物化 `try..finally` 保 index 不丢。
- 基准 `Delta/ApplyReuse` 复用 `GReuseBuf`，异常不泄漏（`TBytes` 受控）。

## 5. 与总约关系
- 本域权威：遍历/差异/归因语义以本文件为准；跨域仍以总 CONTRACT 为准。
- 缺能力先反哺 owner：树扁平/delta 能力归 `bytes.ops` 与 `native.objects`，历史仅聚合。
- 薄网关约束：`history` umbrella 已去聚合化（46 forwards 移除），fan-in 经分片直引度量；持续监控阈值（umbrella <380 / shards 各 <260，`scripts/git-contract-check.sh` C5）接近 800 软阈即再拆分。

## 6. 演进监控
- 600 行阈为 umbrella 单文件软阈（非 shards 累加），当前 shards 210+260+180=~650 为不变量域自然分片；umbrella 薄至 <80 行后总聚合度稀释消除。
- `commitgraph.pas` 1320 行超 800 软阈为已评审例外（Cache/Reader/Writer/Collect 内聚共享 CGPH 解析与 mmap owner，region 标记保可审计性）；拆分前需权衡稀释 ownership 与合入冲突风险（double-cache/重复 mmap owner），阈值接近 1500 或分片直引 fan-in 显著时再行拆分。
- 新增历史能力先归 owner（bytes/compress/checksum），分片仅薄编排 inline 零拷贝；超 80 行即告警review。Commit-graph 多仓缓存波动由 §3 `CommitGraph/CacheHit|Miss` bench 双锚门禁覆盖。
