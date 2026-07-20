# HashSet / Set 性能快照

**日期**：2026-07-21（同机重跑，可用性 P2-C）
**后端**：`THashSet` → `TSwissHashMap<K,Byte>`
**机器**：Linux x86_64，44 cores（`nproc=44`），FPC 3.3.1
**主机**：dtamade，kernel 6.12.74+deb13+1-amd64
**编译**：`make -C core/benchmarks/nextpas.core.collections bench-set`（`-O3 -Xs`，无 heaptrc）
**入口**：`core/benchmarks/nextpas.core.collections/bench_set/bench_set.lpr`
**N**：100000
**Landing 对照 SHA**：`fb1ead4d8` 附近 main tip（重跑时）

## 本机结果（2026-07-21）

表内 **mean / median** 取 bench 统计段；**ops/s** 取 mean 吞吐。

| 操作 | iters | mean | median | ops/s (mean) | CV |
|------|-------|------|--------|--------------|-----|
| HashSet.Add | 100 | 12.21 ms | 12.21 ms | ~81 | 2.4% |
| HashSet.Contains(hit) | 266 | 3.89 ms | 3.87 ms | ~257 | 2.0% |
| HashSet.Contains(miss) | 327 | 3.14 ms | 3.12 ms | ~318 | 3.4% |
| TreeSet.Add | 100 | 38.41 ms | 37.62 ms | ~26 | 4.6% |
| TreeSet.Contains | 100 | 18.19 ms | 18.07 ms | ~54 | 2.6% |
| BTreeSet.Add | 100 | 21.69 ms | 21.01 ms | ~46 | — |
| BTreeSet.Contains | 100 | 14.83 ms | 14.56 ms | ~67 | — |

### 相对同机（本轮）

| 对比 | 比值（mean） |
|------|----------------|
| TreeSet.Add / HashSet.Add | **~3.1×**（HashSet 更快） |
| TreeSet.Contains / HashSet.Contains(hit) | **~4.7×** |
| BTreeSet.Add / HashSet.Add | **~1.8×** |
| BTreeSet.Contains / HashSet.Contains(hit) | **~3.8×** |

### 与 2026-07-20 快照

| 操作 | 2026-07-20 mean | 2026-07-21 mean | 备注 |
|------|-----------------|-----------------|------|
| HashSet.Add | 12.39 ms | 12.21 ms | 同机量级一致（~1%） |
| HashSet.Contains(hit) | 4.02 ms | 3.89 ms | 一致 |
| TreeSet.Add | 35.30 ms | 38.41 ms | 有噪声；CV 4.6% |

**结论**：Swiss-backed HashSet 相对 TreeSet 的优势仍成立；绝对数字仅用于同机对照，勿跨机硬比。

## 对照说明

- 历史 `task_plan` 曾记（另一台/旧路径）HashSet Add Swiss I32 ≈ **4.57 ms** vs Rust 5.31 ms。
  **不可与本表直接比绝对数字**（机型、FPC 选项、bench 框架、是否含 Create/Free 循环均可能不同）。
- 本 `BenchHashSetAdd` 在每次 iteration 内 **Create + N×Add + Free**，是吞吐型整表构建，不是单次 Add 微计时。

## 复现

推荐 Makefile 入口（产物进 `core/build/`）：

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/benchmarks/nextpas.core.collections bench-set
core/build/projects/nextpas.core.collections/bench_set/bench_set
```

手写编译（与 Makefile 接近；`-O2` 会与 `-O3` 数字略有差异）：

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
BD=core/build/projects/nextpas.core.collections/bench_set
mkdir -p "$BD"
fpc -MObjFPC -Sh -Sg -O3 -Xs -Fucore/src -Ficore/src -FU"$BD" -FE"$BD" \
  core/benchmarks/nextpas.core.collections/bench_set/bench_set.lpr
"$BD/bench_set"
```

可选：同目录 `compare_go` / `compare_rust` 同机对照（未强制本轮跑通）。
