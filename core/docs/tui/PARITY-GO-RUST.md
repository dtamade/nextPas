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

## 2. 质量里程碑（Q1–Q6）

| Wave | 标准 | 证据 |
|------|------|------|
| Q1 | PARITY + SCORECARD + bench_go_rust | docs + scorecard + compare |
| Q2 | Kitty Verified | CONTRACT 1.6 + terminal tests |
| Q3 | 稀疏 widget ≥16 | widget suites |
| Q4 | Wine smoke pure path | `test_tui_*_wine` |
| Q5 | Focus reporting + core density | CONTRACT 1.7 |
| Q6 | SC6/SC7 门禁 + ext 运行时密度 ≥12 | scorecard SC6–SC7 + theme/… |

原则：可测正确性 + 热路径门禁 + 文档诚实；禁止假胜 ns。


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
| Q1–Q5 | 测量脚手架 / Kitty / 稀疏 / Wine / Focus | **Done** (`main@a96e3813e`+) |
| Q6 | Scorecard SC6–SC7 + ext/core 密度 | **Done** |
| Q7 | Truecolor env-attested Verified + 更多 suite 密度 | **本批** |
| Q8 | facade 晋升策略 | 后续 |
| Q9 | 完整 ratatui/crossterm crate 对照 | 后续 |
| Q10 | Truecolor DA 查询（非 env-attested） | 后续 |
