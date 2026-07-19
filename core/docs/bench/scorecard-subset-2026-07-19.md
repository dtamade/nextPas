# SCORECARD 子集快照（2026-07-19）

轻量 Pascal vs Go 对照；**不是**全量 `bench/SCORECARD.md` 刷新。

| 项 | 值 |
|----|-----|
| 机器 | Linux x86_64, Intel Xeon E5-2696 v4 @ 2.20GHz, 44 threads |
| Pascal | FPC 3.3.1 `-O3`，`-Fu core/src`，产物落 `/tmp` |
| Go | `go test -bench=. -benchtime=1s -count=1` |
| 全量 SCORECARD | 仍以 **2026-07-02** 为基线（未全量重跑） |

## boolsum（1M bools）

| Op | Pascal | Go | Pascal/Go |
|----|--------|-----|-----------|
| BoolSum (Ord path) | 482 µs/op | 878 µs/op | **1.82× 更快** ✓ |
| BoolSumIf | 825 µs/op | — | Go 仅一条 BenchmarkBoolSum |

## fncall（Ackermann）

| Op | Pascal | Go | Pascal/Go |
|----|--------|-----|-----------|
| Ackermann(3,5) | 74.6 µs/op | 245 µs/op | **3.28× 更快** ✓ |
| Ackermann(3,6) | 292 µs/op | 981 µs/op | **3.36× 更快** ✓ |

## shortstr

| Op | Pascal | Go | 说明 |
|----|--------|-----|------|
| Copy/100K | 668 µs/op | 259 µs/op | Go 更快 ~2.6× |
| Append/1K | 10.9 µs/op | 2.08 ms/op | **Pascal ~191×** ✓ |
| Compare/100K | 1.94 ms/op | 15.9 ms/op | **Pascal ~8.2×** ✓ |

## recops

| Op | Pascal | Go | 说明 |
|----|--------|-----|------|
| RecFilter | 110 ms/op | 43.6 ms/op | Go 更快 ~2.5× |
| RecCopy | 32.7 ms/op | 37.2 ms/op | **Pascal ~1.14×** ✓ |
| RecFieldSum | 12.8 ms/op | 3.96 ms/op | Go 更快 ~3.2× |
| RecBuild | 36.6 ms/op | 76.5 ms/op | **Pascal ~2.1×** ✓ |

## inttohex（每轮 500 次转换）

| Op | Pascal | Go (strconv) | Go (Sprintf) |
|----|--------|--------------|--------------|
| Hex64/500 | 54.4 µs/op | 41.9 µs/op | 185 µs/op |
| Hex32/500 | 22.8 µs/op | 23.1 µs/op | 104 µs/op |

相对 `strconv`：32 位持平/略优，64 位略慢；相对 `Sprintf` 均明显更快。

## bitfield（2026-07-20 追加）

| Op | Pascal | Go | 说明 |
|----|--------|-----|------|
| PopCount/64K | 52.6 µs/op | 44.6 µs/op | Go 略快 ~1.2× |
| SetRange/64K×1K | 66.2 ms/op | 306 ms/op | **Pascal ~4.6×** ✓ |
| TestRange/64K×1K | 54.5 ms/op | 175 ms/op | **Pascal ~3.2×** ✓ |

## packed（2026-07-20；Go 为 `go run` 自管计时）

| Op | Pascal | Go | 说明 |
|----|--------|-----|------|
| PackedCopy/100K | 500 µs/op | 321 µs/op | Go 更快 ~1.6× |
| PackedMove/100K | 264 µs/op | 275 µs/op | 持平/Pascal 略优 |
| PackedUpdate/100K | 228 µs/op | 245 µs/op | 持平/Pascal 略优 |
| PackedFilter/100K | 137 µs/op | 166 µs/op | **Pascal ~1.2×** ✓ |
| PackedCompact/100K | 458 µs/op | 265 µs/op | Go 更快 ~1.7× |

## nativeset（2026-07-20）

| Op | Pascal | Go | 说明 |
|----|--------|-----|------|
| Membership/256K | 792 µs/op | 7.35 ms/op | **Pascal ~9.3×** ✓ |
| Intersection/100K | 254 µs/op | ~12.8 s/op* | Pascal 数量级领先 |
| Union/100K | 260 µs/op | ~12.4 s/op* | Pascal 数量级领先 |

\* Go 侧 map 实现与 Pascal native set 工作量可能不完全等价，解读时注意。

## bitscan（2026-07-20；脚本重跑）

| Op | Pascal | Go (`go run`) | 说明 |
|----|--------|---------------|------|
| BsfQWord/100K | 97.2 µs/op | 81.1 µs/op | Go 略快 ~1.2× |
| BsrQWord/100K | 95.7 µs/op | 123 µs/op | **Pascal ~1.3×** ✓ |
| BsfBsr/100K | 133 µs/op | 202 µs/op | **Pascal ~1.5×** ✓ |
| ByteSwap/100K | 64.9 µs/op | 285 µs/op | **Pascal ~4.4×** ✓ |

## 如何重跑

```bash
bash core/docs/bench/scripts/run-scorecard-subset.sh --list
bash core/docs/bench/scripts/run-scorecard-subset.sh
bash core/docs/bench/scripts/run-scorecard-subset.sh --tracks bitfield,nativeset
```

清单：`scorecard-tracks.txt`。脚本将 Pascal/Go 输出打到 stdout，产物在 `$TMPDIR/nextpas-scorecard-*`（退出清理）。

## 说明

- 仅选无 Rust `target/` 的轻量 track，避免 hygiene 污染。
- 编译产物应落在 `/tmp` 或 `build/`，勿提交进 git。
- 子集共 **9** 类 track：boolsum / fncall / shortstr / recops / inttohex / bitfield / packed / nativeset / bitscan。
