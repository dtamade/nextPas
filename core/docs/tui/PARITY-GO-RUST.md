# tui × Go / Rust 对标纲领（Wave Q）

**状态**: **Maintenance Idle**（2026-07-20）— 完整阶段图见 [ROADMAP.md](ROADMAP.md)
**Owner**: tui lane
**活入口**: [ROADMAP.md](ROADMAP.md) · [SCORECARD.md](SCORECARD.md) · [BENCHMARK.md](BENCHMARK.md) · [CONTRACT.md](CONTRACT.md)

原则：对标的是 **stdlib / 生产级 TUI 库的质量与可证测量**，不是 widget 数量或营销 ns。

### SC 冻结策略（Maintenance Idle）

- 默认 **不** 新增 SC 行，除非：可证失败模式，或 ROADMAP 维度缺口
- Q1–Q15 + M1 + Phase B **完成**；**禁止**开放 Q 波
- 默认只接：回归 / 泄漏 / 平台绿 / **已批准**单点晋升（见 ROADMAP B3 候选表）

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
| Q7 | Truecolor env-attested Verified + 更多 suite 密度 | **Done** |
| Q8 | 门面契约 + SC8 + Wine 加厚 | **Done** |
| Q9 | 分层 facade + stress + SC9 overlay | **Done** (`main@027e9255a`+) |
| Q10 | SC10–SC11 + DECSET 2004 paste + 密度收口 + 晋升策略 | **Done** (`main@5c7fc6dcc`+) |
| Q11 | SC12–SC13 + bench layout/overlay + tier facade ≥12 | **Done** (`main@3a55fc4b6`+) |
| Q12 | SC14–16 hsplit/resilience/diff bound + 质量矩阵 | **Done** (`main@3e783f6c0`+) |
| Q13 | SC17–19 backend/resize/pct + examples multi-demo | **Done** (`main@31e3e6853`+) |
| Q14 | SC20–22 SGR/DrawPatches/ratio + contract C7 | **Done** (`main@3eb99d877`+) |
| Q15 | SC23–25 indexed SGR / style-change / focus Tab + C7 | **Done** (`main@17b18c4c8`+) |
| M1 | Maintenance：SC26–27 + reject scrollview/modal + C8 | **Done** (`main@c06f621a8`+) |
| Phase B | scrollview+modal → ext；B3 停止再晋升 | **Done**（B1 `main@d0009c00f`+） |
| 当前 | **Maintenance Idle**（见 ROADMAP） | Active |
| Idle 单点 | `dialog` → ext | **本批**；split/select 仍 full 按需 |
| 可选 | Truecolor DA / crate / Windows console | 不阻塞 Idle |

## 5. 质量维度 → 证据（对标 go/rust）

| 维度 | go/rust 关注点 | nextPas 证据 |
|------|----------------|--------------|
| Buffer diff | 脏区扫描 / 不全量退化 | SC1–SC2, SC16；bench Diff* |
| Input parse | CSI 正确 + 韧性 | SC3, SC6, SC10–11, SC15；`test_tui_input` |
| Layout | 面积守恒 V/H / % / ratio | SC4, SC14, SC19, SC22；bench Layout* |
| Protocol | Kitty / focus / paste / truecolor | SC8, SC12–13；CONTRACT §5 |
| Backend emit | DECSET 会话序列 | SC17；`test_tui_backend` |
| SGR emit | RGB + indexed FG/BG | SC20, SC23；`test_tui_ansi` |
| DrawPatches | 复用 + 样式切换 | SC21, SC24 |
| Widget focus | Tab 循环 | SC25；`test_tui_focus` |
| Keybind | 绑定 + 派发 | **SC26**；`test_tui_keybind` |
| Frame budget | 帧时预算 | **SC27**；`test_tui_frame_budget` |
| Resize | 尺寸事件契约 | SC18 |
| Wide text | CJK cell width | SC7 |
| Overlay | transparent merge | SC9；bench OverlayMerge |
| Facade tiers | 分层 API 契约 | core/ext/experimental ≥12；**C8 reject** |
| Examples | app-first 教学路径 | `test_tui_examples` ≥7 |
| Frame path | 空帧生命周期 | SC5 |
| 文档/门禁对齐 | 防漂移 | C7 + **C8** |

## 6. Facade 晋升准入标准

将 full-only widget 晋升到 `ext`（或 core）前必须同时满足：

1. 测试密度 ≥16 且 focused 0 leak
2. 无 experimental 协议硬依赖（image/clipboard 等）
3. 语义稳定 ≥1 波次，CONTRACT 有对应条目
4. 有 core reject 夹具证明不泄漏进 default facade（若目标是 ext）
5. 产品确认

### 晋升就绪证据

| 候选 | 密度 | experimental | core reject | ext 导出 | 产品确认 |
|------|------|--------------|-------------|----------|----------|
| scrollview | 23 | 否 | `rejects_scrollview` | **Phase B1 已导出** | Done |
| modal | 16 | 否 | `rejects_modal` | **Phase B1 已导出** | Done |
| dialog | 17 | 否 | `rejects_dialog` | **Idle 单点已导出** | Done |

见 [TIER_REGISTRY.md](TIER_REGISTRY.md)。
