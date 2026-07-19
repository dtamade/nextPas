# SCORECARD 子集快照（2026-07-19）

轻量 Pascal vs Go 对照；**不是**全量 `bench/SCORECARD.md` 刷新。

| 项 | 值 |
|----|-----|
| 机器 | Linux x86_64, Intel Xeon E5-2696 v4 @ 2.20GHz, 44 threads |
| Pascal | FPC 3.3.1 `-O3`，`-Fu core/src` |
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

## 说明

- 仅选无 Rust `target/` 的轻量 track，避免 hygiene 污染。
- 编译产物已清理；勿把 `bench/*` 二进制提交进 git。
- 与 2026-07-02 总表方向一致：若干微基准 Pascal 可明显快于 Go。
