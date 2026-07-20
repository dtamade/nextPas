# HashSet / Set 性能快照

**日期**：2026-07-20
**后端**：`THashSet` → `TSwissHashMap<K,Byte>`（Wave 3）
**机器**：Linux x86_64，44 cores，FPC 3.3.1
**编译**：`fpc -MObjFPC -Sh -Sg -O2`（无 heaptrc）
**入口**：`core/benchmarks/nextpas.core.collections/bench_set/bench_set.lpr`
**N**：100000

## 本机结果（median / mean）

| 操作 | iters | mean | median | ops/s (mean) | CV |
|------|-------|------|--------|--------------|-----|
| HashSet.Add | 100 | 12.39 ms | 12.35 ms | ~80 | 2.2% |
| HashSet.Contains(hit) | 253 | 4.02 ms | 4.00 ms | ~248 | 2.5% |
| HashSet.Contains(miss) | 329 | 3.18 ms | 3.15 ms | ~314 | 3.4% |
| TreeSet.Add | 100 | 35.30 ms | 35.30 ms | ~28 | 1.2% |
| TreeSet.Contains | 100 | 17.05 ms | 17.05 ms | ~58 | 0.9% |
| BTreeSet.Add | 100 | 19.53 ms | 19.47 ms | ~51 | — |
| BTreeSet.Contains | 100 | 14.51 ms | 14.50 ms | ~68 | — |

## 对照说明

- 历史 `task_plan` 曾记（另一台/旧路径）HashSet Add Swiss I32 ≈ **4.57 ms** vs Rust 5.31 ms。
  **不可与本表直接比绝对数字**（机型、FPC 选项、bench 框架、是否含 Create/Free 循环均可能不同）。
- 本 `BenchHashSetAdd` 在每次 iteration 内 **Create + N×Add + Free**，是吞吐型整表构建，不是单次 Add 微计时。
- 相对同机：HashSet.Add 约为 TreeSet.Add 的 **~2.8×** 快；Contains(hit) 约为 TreeSet.Contains 的 **~4.2×** 快。

## 复现

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
BD=core/build/projects/nextpas.core.collections/bench_set
mkdir -p "$BD"
find core/src -maxdepth 1 -type f \( -name '*.ppu' -o -name '*.o' \) -delete
fpc -MObjFPC -Sh -Sg -O2 -Fucore/src -Ficore/src -FU"$BD" -FE"$BD" \
  core/benchmarks/nextpas.core.collections/bench_set/bench_set.lpr
"$BD/bench_set"
```

可选：同目录 `compare_go` / `compare_rust` 同机对照（未强制本轮跑通）。
