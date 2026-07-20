# nextpas.core.tui 完整开发地图

**状态**: Active map（2026-07-20）  
**Owner**: tui lane  
**权威**: 本文件；质量门禁细节见 [PARITY-GO-RUST.md](PARITY-GO-RUST.md) · [SCORECARD.md](SCORECARD.md) · [CONTRACT.md](CONTRACT.md)

---

## 0. 为什么需要地图

| 现象 | 根因 |
|------|------|
| Q1→M1 连续「再加 2 个 SC」 | 把 **质量门禁加厚** 当成了 **模块开发本身** |
| 感觉「大海无边」 | 没有写清 **Done 定义** 与 **禁止再做的事** |
| 对标 go/rust | 应是 **可证正确 + 诚实测量 + 分层 API**，不是无限 feature 横比 |

**结论**：能力层大体齐备；质量 Q 线已达标可冻结；剩余工作是 **有限、可编号、可退出** 的阶段，不是无尽 SC。

---

## 1. 北极星（什么叫 tui Done）

### 1.1 产品定位

| 项 | 定义 |
|----|------|
| 层级 | L3 immediate-mode TUI（ratatui 风格：`IWidget` + 外部 state） |
| 默认入口 | `nextpas.core.tui` = 终端正确性最小闭包 |
| 应用入口 | `nextpas.core.tui.ext` = `TApp` + Screens + 稳定运行时 |
| 实验 | `experimental` = 图像/clipboard 等波动协议 |
| 迁移 | `full` = 宽目录兼容伞，**不是**长期目标 API |

### 1.2 对标 go/rust 的「质量 Done」（不是 feature Done）

与 **ratatui / crossterm / tcell** 公平对齐的只有：

1. **正确性可证** — 输入韧性、布局守恒、diff 边界、SGR/DECSET、焦点/键绑定  
2. **测量诚实** — scorecard 权威；`bench_go_rust` = **简化核** 非假胜  
3. **分层诚实** — core/ext/experimental 边界可测（含 reject）  
4. **可维护** — 契约脚本 C7/C8 防文档/门禁漂移  

**不算 Done 条件（可选 / 禁止假完成）**：

- 完整 ratatui crate 性能广告  
- 无 TTY 的 Truecolor DA「真查询」  
- 把 full 里 30+ widget 全部晋升到 ext  
- Windows 真控制台端到端 FPS  

### 1.3 模块 Done 清单（总出口）

当且仅当下列 **全部** 满足 → **Maintenance Idle**（长期只修 bug / 收 PR）：

| # | 出口标准 | 当前 |
|---|----------|------|
| D1 | 四层 facade 与 TIER_REGISTRY 一致，core 无 app/协议泄漏 | **已满足** |
| D2 | Scorecard SC1–SC27 全绿 + C7/C8 全绿（focused 0 leak） | **已满足**（M1） |
| D3 | 全部 widget 有专属 suite（基础 ≥16，其余 ≥12） | **已满足**（40/40） |
| D4 | 7 demos 教学路径契约（app-first） | **已满足** |
| D5 | `ext` 覆盖稳定应用最小集：TApp + 布局 + scroll/modal 级视口 | **已满足**（Phase B1：scrollview+modal → ext） |
| D6 | 本 ROADMAP 权威存在；PARITY = Maintenance（B 完成后 → Idle） | **地图已满足**；Idle 在 B3/B4 收尾后 |
| D7 | 无 P0 正确性 bug 挂账（或有 issue + 复现测） | **默认满足** |

**D5 是唯一拦路「产品形状」项**；其余质量门禁已齐。

---

## 2. 当前坐标（2026-07-20）

| 资产 | 规模 / 状态 |
|------|-------------|
| 源文件 | 81 `nextpas.core.tui*.pas` |
| Widget | 40 家族，均有 `test_tui_widget_*` |
| 测试目录 | ~98 |
| Examples | 7 demos + examples 契约 |
| Benches | `bench_go_rust` + diff/input/layout/render |
| Scorecard | **SC1–SC27**（38 rows） |
| 契约脚本 | C1–C6 + **C7** 文档对齐 + **C8** core reject |
| 质量线 | Q1–Q15 + M1 **完成** @ `main`（见 archive tags） |

### 2.1 分层

```
core         终端正确性：buffer/diff/input/ansi/terminal + 8 基础 widget
ext          TApp/screens/task/theme/panel/focus/keybind/frame_budget/anim
experimental image/sixel/clipboard
full         core+ext+experimental + ~30 advanced widgets（迁移伞）
```

### 2.2 历史 Q 线（归档，禁止无地图延伸）

| 段 | 实质 |
|----|------|
| Q1–Q6 | 测量脚手架、Kitty、稀疏、Wine、Focus |
| Q7–Q11 | Truecolor env、facade 密度、overlay、paste 2004、bench |
| Q12–Q15 | 输入韧性、后端序列、examples、SGR/DrawPatches、focus Tab |
| M1 | Keybind/FrameBudget + reject + C8 + 冻结策略 |

**禁止**：再开「Q16 再加两个 SC」而无本图阶段号。

---

## 3. 能力全景（Done / Partial / Out）

### 3.1 终端与渲染（core）

| 能力 | 状态 | 证据 |
|------|------|------|
| 双缓冲 + Diff | Done | SC1/2/16 |
| 输入 + 韧性 | Done | SC3/10/11/15 |
| Layout V/H/%/ratio/grid | Done | SC4/14/19/22 |
| Overlay | Done | SC9 |
| SGR / DrawPatches | Done | SC20/21/23/24 |
| DECSET mouse/focus/paste/Kitty | Done | SC6/12/13/17 |
| Truecolor env-attested | Done | SC8 |
| Truecolor DA 真查询 | **Out** | 可选未来 |
| Windows 真 console TUI | **Out** | 挂 platform |
| CJK width | Done | SC7 |

### 3.2 应用运行时（ext）

| 能力 | 状态 |
|------|------|
| TApp + ScreenStack / Task / Theme / Panel | Done |
| Focus / Keybind / FrameBudget | Done（SC25–27） |
| scrollview / modal 在 ext | **Done**（Phase B1） |

### 3.3 experimental / full

| 项 | 策略 |
|----|------|
| image/clipboard | 永不默认进 core |
| full 30+ widgets | 迁移兼容；**不**作为「必须全部进 ext」的 Done 条件 |

---

## 4. 剩余航线（有限阶段）

### Phase A — 质量基线 — **DONE**

Q1–M1。退出：D1–D4 + SC1–SC27 + C7/C8。

### Phase B — Facade 诚实与稳定应用集 — **B1/B2 进行中**

| 步骤 | 内容 | 退出 |
|------|------|------|
| B1 | scrollview + modal → **ext 导出** | **本波实施** |
| B2 | CONTRACT / WIDGET_CATALOG / TIER_REGISTRY 同步 | **本波实施** |
| B3 | 评估下一批稳定候选（**最多 3 个**） | 待后续 |
| B4 | full 标 migration-only | README 已强调；可再收紧 |

**不做**：一次搬空 full；core 塞 TApp。  
**B 完成后**：D5 满足 → 可进 Phase F Idle。

### Phase C — 平台（可选，不阻塞 B）

| 项 | 说明 |
|----|------|
| C2 Wine pure-path | 保持现有 wine suites |
| C3/C4 Windows/macOS 真机 | 挂 platform CI，非 tui 独有阻塞 |

### Phase D — 协议（可选）

Truecolor DA / 图像协议：仅 experimental 内演进。

### Phase E — 测量纪律（持续轻量）

- scorecard 权威正确性，**不对 ns 设硬阈值**  
- bench 简化核禁止假胜营销  
- 重大变更后 `RELEASE=1` 刷新快照  

### Phase F — Maintenance Idle — **总终点**

D1–D6 满足后：

1. PARITY → **Maintenance Idle**  
2. 默认只接：回归、泄漏、平台绿、已批准小幅晋升  
3. 新 SC 必须附失败场景 + 维度缺口  
4. 不再开开放式「对标 go/rust Qxx」波次  

---

## 5. 从现在起的顺序

```
[DONE] Phase A (Q1–M1)
   ↓
[DONE] ROADMAP 落地
   ↓
[本波] Phase B1–B2：scrollview+modal → ext
   ↓
[可选] B3 评估 0–3 个稳定 widget
   ↓
[Idle] Phase F；C/D/E 按需
```

Worktree：始终 `.worktrees/tui`，path-limited land。

---

## 6. 命令速查

```bash
make focused FOCUS=core/tests/nextpas.core.tui/scorecard
make -C core/benchmarks/nextpas.core.tui/bench_go_rust compare
./scripts/tui-contract-check.sh
```

---

## 7. 一句话

**tui 不是无边大海**：Phase A 质量基线已完成；剩余主线是 **B（ext 稳定集）→ F（Idle）**；可选平台/协议；**不是 SC28**。
