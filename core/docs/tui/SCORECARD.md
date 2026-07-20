# tui Scorecard

**状态**: **Maintenance Idle** · Phase E2 Synchronized Update（2026-07-20）
**权威入口**: `core/tests/nextpas.core.tui/scorecard/`
**对标纲领**: [PARITY-GO-RUST.md](PARITY-GO-RUST.md) · [ROADMAP.md](ROADMAP.md)

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
| SC6 | Parse focus CSI I/O | kind=evFocus；正确性（可不记 ns） |
| SC7 | Wide CJK cell width | lead Width=2 + skip tail |
| SC8 | Truecolor env-attested profile | truecolor/24bit Verified; absent not |
| SC9 | Overlay merge | transparent passthrough + overwrite |
| SC10 | SGR mouse parse | CSI `<` down + scroll-up kinds |
| SC11 | Bracketed paste | CSI 200~ → evPaste；201~ 吞掉 |
| SC12 | Kitty flags-reply Verified | CSI `? 5 u` → Verified；`? 0 u` not |
| SC13 | Bracketed paste session | opt-in emits `2004h`；default off |
| SC14 | HorizontalSplit 3 | 面积守恒 + 左右固定宽 |
| SC15 | Input resilience | incomplete CSI NeedMore；非法字节后恢复 |
| SC16 | Diff single-cell bound | 1 cell dirty → patches>0 且 ≪ 全量 |
| SC17 | Backend mouse alt modes | Enter `1003h`/`1006h`；Leave 先 disable 再 `1049l` |
| SC18 | ResizeEvent helpers | kind/dims/IsResize |
| SC19 | Percentage VSplit 50/50 | 高度和 + 面积守恒 |
| SC20 | SGR truecolor FG | `CSI 38;2;r;g;b m` |
| SC21 | DrawPatches adjacent | 一次 MoveTo + 共享 SGR + AB |
| SC22 | Ratio VSplit | 1:3 + fill 面积守恒 |
| SC23 | SGR indexed FG/BG | `38;5;200` + named green bg |
| SC24 | DrawPatches style change | reapply SGR 无多余 MoveTo |
| SC25 | FocusManager Tab | Tab 前进 / Shift+Tab 后退 |
| SC26 | Keybind BindKey+HandleKey | Enter 绑定触发 action |
| SC27 | FrameBudget | BeginFrame 后 not over 16ms |
| SC28 | Synchronized update DECSET 2026 | backend h/l；EndFrame 包裹；opt-out |

规则：

- CI/focused 以正确性 + 可复现为主；**不**对 ns/op 设硬阈值。
- 禁止为 SC1 优化破坏输入正确性或 layout 契约。
- 跨语言绝对 ns 仅作说明；ops 语义必须一致。
- nextPas Diff 比较完整 `TCell`（40B）；Go/Rust 对照为 **1-byte ch 简化核**——不可当「快于 ratatui」营销。
- Layout/Overlay Go/Rust 为几何/字节 stub；Pascal 用真实 nextPas API。
- **禁止**无失败模式新增 SC28+（见 ROADMAP Phase F / PARITY 冻结策略）。

---

## 本机快照（2026-07-20，Phase E1 · `RELEASE=1`）

**Host**: Linux 6.12.74+deb13+1-amd64 x86_64 · FPC 3.3.1 · **无 heaptrc**（发布口径）

| ID | Subject | ns/op | ops | ok |
|----|---------|------:|----:|:--:|
| SC1 | diff_identical | 29576 | 2000 | Y |
| SC2 | diff_dirty10 | 35934 | 2000 | Y |
| SC3a | parse_ascii | 36 | 50000 | Y |
| SC3b | parse_csi_up | 44 | 50000 | Y |
| SC5 | frame_empty | 3647 | 500 | Y |
| SC4a–SC27a | correctness gates | — | 1 | Y |

相对 16 ms 帧预算：SC1/SC2 约 30–36 µs（约 **0.2%** 帧时）。

### `bench_go_rust compare`（同机，简化核 · E1）

| Op | nextPas | Go stub | Rust stub |
|----|--------:|--------:|----------:|
| DiffIdentical 200×50 | 26.4 µs | 7.9 µs | 10.2 µs |
| DiffDirty10 200×50 | 36.2 µs | 7.3 µs | 9.2 µs |
| ParseAscii | 36 ns | ~0.9 ns | ~1.2 ns |
| ParseCsiUp | 44 ns | ~1.1 ns | ~1.9 ns |
| LayoutVSplit3 | 293 ns (real) | ~2.6 ns (geom stub) | ~1.0 ns (geom stub) |
| LayoutHSplit3 | 419 ns (real) | ~2.2 ns (geom stub) | ~1.6 ns (geom stub) |
| OverlayMerge 40×12 | 516 ns (real) | 214 ns (byte stub) | 504 ns (byte stub) |

说明：nextPas 路径含完整 cell / 真实 ParseOne / 真实 layout·overlay；Go/Rust 为简化核 + anti-DCE。差距符合「完整库 vs 微核」，**不是**「慢于 Go/Rust 生产 TUI」的结论。

### Phase C2 Wine pure-path（E1 同批证据）

| Suite | 结果 |
|-------|------|
| `test_tui_buffer_wine` | 12/12，0 leak |
| `test_tui_color_wine` | 12/12，0 leak |
| `test_tui_input_wine` | 12/12，0 leak |
