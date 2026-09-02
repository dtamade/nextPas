# nextpas.core.js 现代 AI 开发规范

**Owner**：`codex/core-js`
**关联**：`AGENTS.md` / `core/AGENTS.md` / `ai-collaboration-discipline.md` / `worktree-integration-runbook.md` / `ACCEPTANCE.md`
**版本**：1.0
**最后更新**：2026-08-30

> 本规范将 `nextPas` 的 AI 协作纪律落到 `js` 模块的具体执行。不遵守本规范的 AI 生成代码视为未完成。

---

## 1. 原则

| 原则 | 含义 |
|------|------|
| **人类定契约，AI 填实现** | `CONTRACT.md` 与 `ACCEPTANCE.md` 由人类冻结，AI 不得擅自放宽门禁 |
| **证据先于断言** | 任何“完成/修复/通过”必须先有命令输出（`verification-before-completion`） |
| **单 lane 单 worktree** | `codex/core-js` 独占 `.worktrees/core-js`，禁止多 AI 同改 `js.*`（`ai-collaboration-discipline.md §1`） |
| **小步快验** | 每 1–2 文件即 `make focused` + `make hygiene`，禁止攒大包 |

---

## 2. Agent 工作流（`js` 落地）

```
人类：冻结 CONTRACT/ACCEPTANCE/ROADMAP
  ↓
Agent-Plan：读 design-conventions + js/*.md + 标杆 http/tui，做只读审计（不写码）
  ↓
Agent-Implement：按 ROADMAP 里程碑，每 slice 一个 subagent（`dispatching-parallel-agents`）
  ↓
Agent-Review：独立 reviewer agent 按本规范 §5 清单审查
  ↓
Agent-Verify：执行 ACCEPTANCE 门禁矩阵，产出证据包
  ↓
人类：批准 Ready / 要求返工
```

**Worktree 纪律**（`worktree-integration-runbook.md`）：

```bash
git worktree add .worktrees/core-js -b codex/core-js main
cd .worktrees/core-js
# 仅在此 worktree 落码，主 checkout 只做集成
git add -- core/docs/js/xxx.md core/src/nextpas.core.js.xxx.pas
git diff --cached --name-only  # 必须 path-limited
git diff --check
make hygiene
```

禁止：`git add .` / `git commit -a` / `git reset --hard` / 主 checkout 直接改 `js.*`。

---

## 3. 提示词纪律

| 规则 | 要求 |
|------|------|
| 模板化 | 所有 AI 任务使用 `core/docs/js/prompts/*.md` 模板（若无则用 `AGENTS.md` Authority Map） |
| 可复现 | 提示词与模型版本写入 `task_plan.md`，同输入应同输出（温度 0） |
| 上下文最小化 | 仅注入 `CONTRACT`/`DESIGN`/`TESTING` 必要片段，禁止全仓库灌入 |
| 变更可追溯 | AI 生成的每段代码/测试在 commit message 标注 `Co-Authored-By: AI` + 提示词摘要 |

---

## 4. 代码生成规范

| 项 | 规则 |
|----|------|
| 风格 | 严格 `design-conventions §1/§13`（dotted 小写、`T/I/E` 前缀、`A/L/F` 变量、`{$mode ObjFPC}{$H+}`） |
| 分层 | 遵守 `L2 只依赖 L0–L1`，`js` 不 `uses webview/http/tui`（`CONTRACT §9` 源契约扫描） |
| FFI | `*.ffi` 只含 `cdecl external`，`loader` 唯一 `platform.dl`（`CONTRACT INV-2`） |
| 错误 | 默认异常 + `TryXxx` 分叉，不引入 `Result<T,E>`（`design-conventions §4`） |
| 注释 | `{** @desc @params @return @note}`，禁止 `@complexity/@usage` 重标签 |
| 体积 | 单单元 >800 行必拆；`js.intf` 三职责 >500 行拆 `js.value/host`（`SIXDIM M-1/M-2`） |

---

## 5. AI 代码审查清单（生成后必检）

| # | 检查项 | 失败判据 |
|---|--------|----------|
| C1 | 分层合规 | `uses` 闭包含 `L3` 或 `platform.dl` 在非 loader |
| C2 | FFI 纯度 | `*.ffi` 含 `begin`/`implementation` 逻辑 |
| C3 | 枚举稳定 | `TJsBackendKind` 非尾部追加 |
| C4 | 线程亲和 | `Eval` 未做创建线程校验 |
| C5 | 悬垂安全 | `TJsValue` 未 `IsValid` 守卫 |
| C6 | 闭包循环 | `SetHostFunction` 捕获 `IJsContext` 未弱引用 |
| C7 | 序列化/复用 | 手写转义而非 `json` owner；手写路径归一而非 `fs.path`；自造 `platform.dl` 外的 dl |
| C8 | 风格 | `+=`/`COPERATORS`/`Tab`/`大写单元名` |
| C9 | 测试覆盖 | 公共 API 无边界/失败路径用例 |
| C10 | 复用与反哺 | 在 `js` 内重复造轮子/低质量性能代码而未反哺 owner（`json/text/mem/fs.path/bench/test`）；发现 owner 缺口未提 `core` 反哺 PR |
| C11 | 证据 | 无 `heaptrc 0` 或 `make hygiene` 输出即声称完成 |

---

## 6. 验证前置（Verification Before Completion）

任何 `Ready` 前必须执行（`verification-before-completion` skill）：

```bash
make hygiene
make focused FOCUS=core/tests/nextpas.core.js/test_js_fake
make focused FOCUS=core/tests/nextpas.core.js/test_js_base
python3 core/tests/architecture/check_source_contracts.py
# 若涉 quickjs：NEXTPAS_JS_QUICKJS_REQUIRED=1 make focused FOCUS=core/tests/nextpas.core.js/test_js_quickjs_runtime
```

未执行或未贴输出即声称“通过”视为违规。

---

## 7. 测试生成规范

| 规则 | 要求 |
|------|------|
| 框架 | 必须 `nextpas.core.test`（`TTestSuite + TSuiteRunner`），禁止手写 runner（`design-conventions §12`） |
| 覆盖 | 公共 API、错误语义、内存/句柄生命周期必覆盖边界与失败路径（`TESTING.md §4`） |
| 变异 | AI 生成测试需经变异测试（mutation）抽检，存活变异 >20% 即返工 |
| 基准 | 必须 `nextpas.core.bench`，禁止 `GetTickCount64` 自计时（`design-conventions §12`） |

---

## 8. 文档即代码

| 规则 | 要求 |
|------|------|
| 双向追踪 | 源码改 `CONTRACT` 必改，反之亦然；`README` 索引必须包含新增文档 |
| 版本 | 每份文档 `版本` 与 `最后更新` 必填，变更入 `变更记录` |
| 腐烂检测 | 每次 `make focused` 前跑 `grep -R "TODO\|FIXME" core/docs/js` 0 命中 |

---

## 9. 人机协作边界

| 决策 | 归属 |
|------|------|
| 契约冻结/放宽 | 人类 |
| 里程碑排期 | 人类 |
| 实现细节/测试用例 | AI 可生成，人类审查 |
| 跨模块协作（`webview.fake.js` 归属 `webview` 家族） | `codex/core-js` 提 PR，`codex/core-webview` 审查（`SIXDIM M-4` 受控跨模块） |
| 验收通过 | 人类基于证据包判定 |

---

## 10. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首版：agent 工作流 + 提示词 + 审查清单 + 验证前置 |

