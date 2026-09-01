# nextpas.core.git — 历史契约（history）

**模块路径**：`core/src/nextpas.core.git.native.{revwalk,commitgraph,reflog,revparse,log,describe,diff,blame,mergebase,show,shortlog,catfile,cherrypick,revert}.pas` + `nextpas.core.git.native.history.pas` 门面
**层级**：L2（L0-L1: base, bytes, text, fs, io；依赖 objects 域 `repo/objmodel/pack`）
**Owner**：git lane
**不变量域**：历史遍历与查询（revwalk / commit-graph / 日志 / 差异 / 归因 / 合并基）

## 1. 范围与阈值
- 源聚合：14 单元 + 1 门面 shard（`native.history`），单 shard 单次交付门面，超阈即再分片；历史层不自建对象/压缩，仅复用 owner。

## 2. 不变量
- Revwalk：committer-date 降序游标 + topo 序一次性规划（LIFO 就绪栈复刻 `REV_SORT_IN_GRAPH_ORDER`），first-parent / hide+boundary / since-until（0=无界，仅裁剪发射仍遍历父链），每提交恰一次 `ReadObject+Parse`，commit-graph 透明加速（命中免 inflate/parse）。
- Commit-graph v1：`CGPH + OIDF/OIDL/CDAT/EDGE + 尾 SHA-1`，fanout 累积 + OID 排序 + 36B/CDAT + EDGE 溢出，`Build/Write/WriteAll/Verify/Invalidate` 3 块无 GDA2 最小闭合；`Write*` 经 `WriteAtomic` 原子落盘 + 内存/文件双重 Verify + Invalidate；`TryLoad` 经 `Stat.mtime+size` 缓存 `TBytes` 零重复 `ReadFile`；`WriteAll` 聚合 `refs/heads+HEAD+tags` 起止；对齐 `git commit-graph write/verify`。
- Diff/Blame：扁平化递归 + 字典排序 + 归并（Added/Modified/Deleted/TypeChanged，零重命名，peel 16 层）；blame 经 LCS 行 diff + head-vs-each 最老匹配，线性史，对齐 `git blame --porcelain`；`Delta/Apply|ApplyReuse:inline` 复用 `bytes.ops` `GitApplyDeltaInto` + `GReuseBuf` 单源（`TByteSpan` 零拷贝）。
- Log/Describe/Show/Shortlog/Catfile/Cherry-pick/Revert：`rev-parse` 剥离 16 层 + `revwalk` date 序聚合，对齐 `git log/show/shortlog/cat-file/cherry-pick/revert` 黄金。

## 3. 性能契约（复用 bytes.ops 单源）
- `Delta/Apply|ApplyReuse:inline` ≤5 µs/op（≥200 Kop/sec），`TByteSpan` 零拷贝 + 复用缓冲，不触 `SysUtils`；`Revwalk` 单次交付，零重复解析。
- 抖动余量 10-15%，同机 `-O3 -Xs` 无 heaptrc 中位数，绝对阈值 + 基线双锚（见总 CONTRACT §7 的 Go/Rust A/B 归一）。

## 4. 稳定性
- `TCommitGraph`/`TPackFile` 析构释放；`revwalk` 队列 `try..finally`；`cherry-pick/revert` 经 `checkout` 物化 `try..finally` 保 index 不丢。
- 基准 `Delta/ApplyReuse` 复用 `GReuseBuf`，异常不泄漏（`TBytes` 受控）。

## 5. 与总约关系
- 本域权威：遍历/差异/归因语义以本文件为准；跨域仍以总 CONTRACT 为准。
- 缺能力先反哺 owner：树扁平/delta 能力归 `bytes.ops` 与 `native.objects`，历史仅聚合。
