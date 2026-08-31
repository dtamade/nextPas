# nextpas.core.js 开发路线图

**Owner**：`codex/core-js` lane
**层级**：L2
**关联**：`CONTRACT.md`（冻结面）、`ACCEPTANCE.md`（验收）、`GOAL_TREE.md`（目标树）、`REVIEW.md`（差距）
**版本**：1.0（S0 定版，随实现滚动，M3b 均值与纯族 481 行阈值550内体量同步，与 CONTRACT 1.0/BENCHMARKS 1.4 对齐，18 份对齐）
**最后更新**：2026-08-31

---

## 0. 导航

- 目标树（阶段语义）：`GOAL_TREE.md` — S0–S5 的“是什么、为什么”
- 本路线图（执行语义）：本文 — “何时、谁做、交付什么、依赖什么、如何验收”
- 验收（门禁语义）：`ACCEPTANCE.md` — Definition of Done + 证据链
- AI 执行规范：`AI_GUIDE.md` — agent 工作流与验证纪律

---

## 1. 里程碑总览

| 里程碑 | 名称 | 目标 | 交付物 | 依赖 | 退出条件（Exit Criteria） | 工期 | 人力 |
|--------|------|------|--------|------|---------------------------|------|------|
| **M0** | S0 文档冻结 | 可评审、可排期 | 18 份文档（6+6+GAME888/FAQ/DECISIONS/CHANGELOG/SIXDIM/具像化） | 无 | REVIEW H1–H3 清零 + SIXDIM P0 6 项清零 + `make hygiene` pass + 本 ROADMAP 定版 | 1 批次（已交付 0.6） | 1 lane |
| **M1** | S1 假后端可用 | CI 零依赖绿 | `js.base/intf/fake/pas` + `test_js_base/fake` + `demo_js` | `json`, `bench`, `test` | ACCEPTANCE S1 DoD 全绿（见 ACCEPTANCE §3） | 1–2 周 | 1 人 |
| **M2** | S1 QuickJS 真链路 | 本地真 JS 语义 | `js.quickjs.ffi/loader/quickjs` + `test_js_quickjs_runtime` + `bench_eval` 骨架 | `platform.dl`, `libquickjs` | M1 + `quickjs_runtime` 探测到即绿 + `bench_eval` 可跑 | 1–2 周 | 1 人 |
| **M3** | S2 联动与加固 | 被 webview 间接回归 | `webview.fake.js` 适配（活在 webview 家族，`SIXDIM M-4`） + `json` 互通全量 + 超时/悬垂加固 | `webview`, `json` | webview 13 门 + js 3 门双绿 + `bench_eval` 基线落库 | 1 周 | 1 人 + webview reviewer |
| **M4** | S3 后端扩展（**纯 Pas 保证**） | 零 so / 高性能可选 | `js.js888`（`jsbkJs888` 尾部追加，零 FFI/零 dl，`js.intf` 零改动）或 `jsbkV8` | 性能/闭环需求触发 | `test_js_js888_runtime` 恒绿 + `test_js_fake` 同矩阵全绿 + 枚举稳定性回归 + `bench_eval` 对纯同口径 | 按触发另排 | 1 人 |
| **M5** | 1.0 冻结 | 生产级 | CONTRACT 1.0 + `CHANGELOG`/`PARITY` 刷新 + 迁移指南 | M3 + 至少 1 个真实消费方 | ACCEPTANCE Production DoD（见 §5） | 1 周 | 1 人 |

> M4 为条件里程碑（Deferred 触发前不排期）；M0–M3 为必达路径。

---

## 2. 详细计划（M0–M3 必达）

### M0 — S0 文档冻结（当前）

| 项 | 内容 |
|----|------|
| 输入 | `REVIEW.md` H1–H3 + N1–N7 |
| 活动 | 补齐 ROADMAP/ACCEPTANCE/AI_GUIDE/TESTING/SECURITY/BENCHMARKS；将现有 6 份升级到 0.4 |
| 产出 | 12 份文档定版，`git log` 可追溯 |
| 风险 | 文档与源码脱节 → 缓解：每份文档设 `最后更新` 与 `版本`，源码落地时以 `ACCEPTANCE` 证据链校验 |
| 工期 | 1 批次（本文即交付） |

### M1 — S1 假后端可用

| 项 | 内容 |
|----|------|
| 源码 | `nextpas.core.js.base.pas`（≤200 行）、`js.intf.pas`（≤350 行）、`js.fake.pas`（≤550 行，含 fs/thread 集成）、`js.pas` 门面（≤80 行）；纯族 `pure.base` 481 行阈值550内 + `js.js888/v8/chakra` 各 ~119 行（单单元 <550，阈值内，M3b 均值实测 660ns） |
| 测试 | `test_js_base`（选项/枚举/错误族）、`test_js_fake`（契约全量 40+ 用例，见 TESTING §3） |
| 示例 | `demo_js`（`1+2`/`echo`/`JSON` 三段） |
| 基准 | `bench_eval` 骨架（可编译，未落基线，M3b 均值已刷新 5 后端矩阵 645/660/631/660/SKIP） |
| 风险 | `TJsValue` 借用语义误用 → 缓解：`IsValid` + `TryAs*` + `TESTING` 悬垂矩阵 |

### M2 — S1 QuickJS 真链路

| 项 | 内容 |
|----|------|
| 源码 | `js.quickjs.ffi.pas`（`cdecl` 指针类型，无 `external`）、`js.quickjs.loader.pas`（`platform.dl` 8 名跨平台探测，≤250 行）、`js.quickjs.pas`（≤600 行） |
| 测试 | `test_js_quickjs_runtime`（`1+2`/`JSON`/`超时`/`webview 桥 dry-run`），无库时 SKIP |
| 基准 | `bench_eval` 可跑，输出 `ns/op`（未冻结） |
| 风险 | `libquickjs` 多名跨平台差异 → 缓解：loader 8 名跨平台探测 + `JsBackendAvailable` 矩阵测试 |

### M3 — S2 联动与加固

| 项 | 内容 |
|----|------|
| 源码 | `webview.fake.js` 适配（活在 `webview` 家族，`uses js.intf`）、`json` 互通补齐 |
| 测试 | webview `test_webview_*` 间接回归 + js 悬垂/超时精确性加固 |
| 基准 | `bench_eval` 基线落库（`README` 与 `BENCHMARKS.md` 对齐） |
| 风险 | 循环引用（`Context` ↔ 宿主闭包） → 缓解：弱引用文档 + `fake` 用例 + `AI_GUIDE` 审查清单 |

---

## 3. 依赖图

```
M0 (文档)
 └─→ M1 (base/intf/fake) ─→ M2 (ffi/loader/quickjs) ─→ M3 (联动/基准)
                              └─→ M4 (js.js888/V8, 条件)
                                            └─→ M5 (1.0 冻结)
```

- 外部依赖：`json`（M1）、`platform.dl`（M2）、`webview`（M3）
- 内部依赖：`base(后端无关) ← intf(不透明) ← {fake, ffi←loader←quickjs, pure.base(481 行阈值550内)←{js888,v8,chakra}(各~119 行,零ffi)} ← 门面`（CONTRACT §1；纯族 481 行阈值550内，与 fake 同约束，`js.intf` 零改动）

---

## 4. 资源与并行策略

| 策略 | 说明 |
|------|------|
| 单 lane 单 worktree | `codex/core-js` 独占 `.worktrees/core-js`，禁止多 AI 同改 `js.*`（见 `ai-collaboration-discipline.md` §1） |
| 文档与源码串行 | M0 冻结后才进 M1 源码，避免文档-源码双向漂移 |
| 测试与基准并行 | M1 的 `test_js_fake` 与 `bench_eval` 骨架可并行（不同目录） |
| 跨模块协作 | M3 的 `webview.fake.js` 由 `codex/core-js` 提 PR，`codex/core-webview` 审查（受控跨模块，见 `AGENTS.md` 跨模块纪律） |

---

## 5. 风险登记簿

| 风险 | 概率 | 影响 | 缓解 | 触发 |
|------|------|------|------|------|
| QuickJS 上游停更 | 中 | 高 | `QuickJS-NG` 同 ABI 探测 + `js.js888` 兜底 | M2 探测失败 |
| `TJsValue` 悬垂误用 | 高 | 中 | `IsValid`/`TryAs*` + TESTING 悬垂矩阵 | M1 测试 |
| 宿主闭包循环引用 | 中 | 中 | 弱引用文档 + 审查清单 | M1/M3 |
| `libquickjs` 多版本差异 | 高 | 低 | 三名探测 + 矩阵测试 | M2 |
| 文档腐烂 | 高 | 高 | AI_GUIDE 文档即代码 + 源码-文档双向追踪 | 每次提交 |

---

## 6. 版本与发布

| 版本 | 对应里程碑 | 语义 |
|------|------------|------|
| 0.3 | M0 前 | 骨架 |
| 0.4 | M0 冻结 | 12 份文档生产级 |
| 0.5 | M1 | 假后端可用 |
| 0.8 | M4 | `js.js888` 零摩擦落地（`jsbkJs888` 尾部，`js.intf` 零改动，纯族 338 行阈值内） |
| 0.9 | M2–M3 | 真链路+联动（M3b 基准 5 后端 179/633/1089/962/SKIP 落库） |
| 0.10 | M3b均值 | 文档完整性修复（BENCHMARKS 1.4 均值 ~660ns / B/op 18/176 + pure.base 481 行阈值550内统一） |
| 1.0 | M5 | 生产级冻结（semver，见 CONTRACT §13） |

---

## 7. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首版：M0–M5 里程碑 + 依赖 + 风险 |
| 2026-08-31 | 1.1 | M3b 同步：BENCHMARKS 5 后端矩阵刷新（179/633/1089/962/SKIP）+ Value/ops 同步 + 纯族 338 行体量阈值内（CONTRACT/BENCHMARKS 对齐） |
| 2026-08-31 | 1.2 | 0.9 对齐：CONTRACT 0.8→0.9/PARITY 0.7→0.9/WEBVIEW 0.7→0.9/SIXDIM 0.6→0.9 四份联动，pure.base 复用 `JsPureFindHost/ValidateHostName` 消 QuickJS 克隆，18 份闭环 |
| 2026-08-31 | 1.3 | 0.10 文档完整性修复：BENCHMARKS 1.4 同步实测均值 ~660ns（645/660/631/660）/ host ~1.5µs 加权 / B/op 18/176 + pure.base 481 行阈值550内统一，18 份对齐 |
| 2026-08-31 | 1.0 | 冻结候选：距1.0仅文档版本滞后，CONTRACT/DESIGN 0.10→1.0，BENCHMARKS 1.4 保持，其余引用同步 1.0，18份对齐 |

