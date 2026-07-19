# tui Scorecard

**状态**: Wave Q1 Active
**权威入口**: `core/tests/nextpas.core.tui/scorecard/`
**对标纲领**: [PARITY-GO-RUST.md](PARITY-GO-RUST.md)

Ready 报告的热路径证据以本 Scorecard 为准；历史 smoke 数字见 [BENCHMARK.md](BENCHMARK.md)。
Go/Rust 同方法论对照：

```bash
make -C core/benchmarks/nextpas.core.tui/bench_go_rust compare
```

---

## 运行

```bash
# focused gate（含 heaptrc）
make focused FOCUS=core/tests/nextpas.core.tui/scorecard

# 发布用数字（关闭 heaptrc，更接近生产）
make -C core/tests/nextpas.core.tui/scorecard clean test RELEASE=1
```

---

## 场景

| ID | 场景 | 断言 / 指标 |
|----|------|-------------|
| SC1 | Diff 200×50 相同 | patches=0；ns/op |
| SC2 | Diff 200×50 10 脏行 | patches>0 且 < 全量；ns/op |
| SC3 | ParseOne ASCII / CSI 箭头 batch | kind 正确；ns/op |
| SC4 | VerticalSplit 3 + Grid 4×4 | 区域不重叠、面积守恒 |
| SC5 | Frame Begin/End 空帧（test runtime） | 成功完成；heaptrc 0 |

规则：

- CI/focused 以正确性 + 可复现为主；**不**对 ns/op 设硬阈值。
- 禁止为 SC1 优化破坏输入正确性或 layout 契约。
- 跨语言绝对 ns 仅作说明；ops 语义必须一致。
- nextPas Diff 比较完整 `TCell`（40B）；Go/Rust 对照为 **1-byte ch 简化核**——不可当「快于 ratatui」营销。

---

## 本机快照（2026-07-19）

**Host**: Linux 6.12.74+deb13+1-amd64 x86_64 · FPC 3.3.1 · heaptrc focused scorecard

| ID | Subject | ns/op | ops | ok |
|----|---------|------:|----:|:--:|
| SC1 | diff_identical | 25659 | 2000 | Y |
| SC2 | diff_dirty10 | 38539 | 2000 | Y |
| SC3a | parse_ascii | 37 | 50000 | Y |
| SC3b | parse_csi_up | 44 | 50000 | Y |
| SC4a | vsplit3 | — | 1 | Y |
| SC4b | grid4x4 | — | 1 | Y |
| SC5 | frame_empty | 3729 | 500 | Y |

### `bench_go_rust compare`（同机，简化核）

| Op | nextPas (full TCell / ParseOne) | Go (1B cell / stub) | Rust (1B cell / stub) |
|----|--------------------------------:|--------------------:|----------------------:|
| DiffIdentical 200×50 | ~25.9 µs | ~8.2 µs | ~9.5 µs |
| DiffDirty10 200×50 | ~35.7 µs | ~8.4 µs | ~9.1 µs |
| ParseAscii | ~36 ns | ~1.2 ns | ~1.2 ns |
| ParseCsiUp | ~44 ns | ~1.5 ns | ~1.7 ns |

说明：nextPas 路径含完整 cell 相等与真实 `ParseOne`；Go/Rust 为字节级简化核 + anti-DCE。差距符合「完整库 vs 微核」，**不是**“慢于 Go/Rust 生产 TUI”的结论。
