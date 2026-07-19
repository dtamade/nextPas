# tui × Go / Rust 对标纲领（Wave Q）

**状态**: Active（2026-07-19）
**Owner**: tui lane
**活入口**: [SCORECARD.md](SCORECARD.md) · [BENCHMARK.md](BENCHMARK.md) · [CONTRACT.md](CONTRACT.md)

原则：对标的是 **stdlib / 生产级 TUI 库的质量与可证测量**，不是 widget 数量或营销 ns。

---

## 1. 对标对象（公平口径）

| 维度 | Rust | Go | nextpas.core.tui |
|------|------|-----|------------------|
| 渲染模型 | ratatui immediate-mode | bubbletea (Elm) / tview retained | **ratatui 对齐**：`IWidget` + 外部 state |
| 终端 I/O | crossterm / termion | tcell | `TTerminal` + ANSI + platform |
| 热路径 | buffer diff、输入解析、layout | 同左 | buffer / input / layout / frame |
| 测量 | criterion 或自写 micro | testing.B / 自写 | scorecard + `bench_go_rust` |
| 契约 | 文档 + 强测试 | 文档 + 强测试 | CONTRACT + scorecard 门禁 |

### 可比（做）

1. **Buffer diff** — 200×50 相同 / 10 脏行（同方法论 cell 扫描）
2. **ParseOne** — ASCII / CSI 箭头（同方法论字节解析）
3. **Layout** — 固定 constraint 切分正确性
4. **正确性语料** — 残缺 CSI、非法字节恢复、宽字符边角

### 不可比（禁止假胜）

- 真 tty 端到端 FPS（环境噪声）
- bubbletea 消息循环 vs immediate render
- 完整 ratatui/crossterm 全库 feature 横比而不写清 ops 语义
- Rust 被 DCE 掉的 0 ns/op

对照 harness 使用 **同算法简化核**（非完整第三方 crate），避免版本噪声；文档必须写「简化核」而非「快于 ratatui 全库」。

---

## 2. 成功标准（Wave Q1）

| ID | 标准 | 证据 |
|----|------|------|
| **Q1** | 本纲领存在且口径清晰 | 本文 |
| **Q2** | SC1–SC5 可复现门禁 | `core/tests/nextpas.core.tui/scorecard` |
| **Q3** | 交叉语言同方法论 micro | `bench_go_rust` `make compare` |
| **Q4** | 输入韧性语料 | `test_tui_input` 加厚 |
| **Q5** | core facade 密度底线 | `test_tui_widget_clear` / `intf` ≥12 |
| **Q6** | 文档同步 | SCORECARD / BENCHMARK / CONTRACT 1.5 |

---

## 3. 命令

```bash
# 权威 nextPas 门禁数字（默认 heaptrc；发布数字加 RELEASE=1）
make focused FOCUS=core/tests/nextpas.core.tui/scorecard
make -C core/tests/nextpas.core.tui/scorecard clean test RELEASE=1

# 交叉语言对照
make -C core/benchmarks/nextpas.core.tui/bench_go_rust compare

# 正确性
make focused FOCUS=core/tests/nextpas.core.tui/test_tui_input
make focused FOCUS=core/tests/nextpas.core.tui/test_tui_widget_clear
make focused FOCUS=core/tests/nextpas.core.tui/test_tui_widget_intf

./scripts/tui-contract-check.sh
```

---

## 4. Wave 状态

| Wave | 内容 | 状态 |
|------|------|------|
| Q1 | PARITY / SCORECARD / bench_go_rust | **Done** |
| Q2 | Kitty `CSI ? u` → Verified | **Done** |
| Q3 | 稀疏 widget ≥16 | **Done** |
| Q4 | Wine smoke input/buffer/color | **Done** |
| Q5 | DECSET 1004 focus + 核心 suite 密度 | **本批** |
| Q6 | facade 晋升策略 | 后续 |
| Q7 | 完整 ratatui/crossterm crate 对照 | 后续 |
