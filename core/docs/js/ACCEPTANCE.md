# nextpas.core.js 验收标准契约

**Owner**：`codex/core-js`
**关联**：`CONTRACT.md`（冻结面）、`ROADMAP.md`（里程碑）、`TESTING.md`（方法）、`AI_GUIDE.md`（执行纪律）
**版本**：1.0
**最后更新**：2026-08-30

> 本文档是**唯一验收依据**。任何“完成”声明必须以本契约的证据链为准，禁止口头完成。

---

## 1. Definition of Done（通用）

单个 slice（文档或源码批次）视为完成，当且仅当：

| # | 条件 | 证据 |
|---|------|------|
| D1 | 变更有明确输入（`REVIEW`/`ROADMAP` 条目或 issue） | commit message 引用 |
| D2 | 契约与实现一致（`CONTRACT` 已更新或无需更新） | `git diff` 对照 |
| D3 | 有直接 focused 测试或文档审查 | `make focused` 或 `make hygiene` 输出 |
| D4 | 无泄漏（heaptrc 0 或文档无代码） | `heaptrc` 日志 |
| D5 | 无风格/卫生Debt（`git diff --check` 0 + `make hygiene` pass） | 命令输出 |
| D6 | 提交为单逻辑单元，可回滚 | `git show --stat` |
| D7 | 若涉 AI 生成，符合 `AI_GUIDE` 审查清单 | `AI_GUIDE` 勾选 |

---

## 2. 门禁矩阵（按里程碑）

### M0 — 文档冻结（当前验收）

| 门禁 | 要求 | 命令 | 证据 |
|------|------|------|------|
| G-M0-1 | 18 份文档齐全（`README+CONTRACT+DESIGN+GOAL_TREE+PARITY+WEBVIEW_LINK+REVIEW+ROADMAP+ACCEPTANCE+AI_GUIDE+TESTING+SECURITY+BENCHMARKS+GAME888_BORROW+FAQ+DECISIONS+SIXDIM_REVIEW+CHANGELOG`） | `ls core/docs/js/*.md \| wc -l` | 18 |
| G-M0-2 | REVIEW H1–H3 清零 | 人工审查 REVIEW.md | H1–H3 已补 ROADMAP/ACCEPTANCE/AI_GUIDE |
| G-M0-3 | 无 TODO/FIXME/产物 | `grep -R TODO core/docs/js` + `make hygiene` | 0 + pass |
| G-M0-4 | 文档交叉引用闭环 | 人工审查 README 索引 | 12 份互链 |

### M1 — 假后端可用

| 门禁 | 要求 | 命令 | 证据 |
|------|------|------|------|
| G-M1-1 | `test_js_base` 全绿 + heaptrc 0 | `make focused FOCUS=core/tests/nextpas.core.js/test_js_base` | AllPassed |
| G-M1-2 | `test_js_fake` 全绿 + heaptrc 0（40+ 用例，见 TESTING §3） | `make focused FOCUS=core/tests/nextpas.core.js/test_js_fake` | AllPassed |
| G-M1-3 | `source-contract` pass（INV-1/INV-2/层级，含 `grep -R "quickjs\|v8" core/src/nextpas.core.js.base.pas` 0 命中）+ 单单元行数 ≤500/800 阈值抽样 `wc -l core/src/nextpas.core.js*.pas` | `python3 core/tests/architecture/check_source_contracts.py` + `wc -l` | pass + ≤500/800 |
| G-M1-4 | `demo_js` 可编译运行 | `make -C core/examples/nextpas.core.js/demo_js run` | exit 0 |
| G-M1-5 | `fpc -vh` 0 hint | `fpc -vh` | 0 |

### M2 — QuickJS 真链路

| 门禁 | 要求 | 命令 | 证据 |
|------|------|------|------|
| G-M2-1 | `test_js_quickjs_runtime` 探测到即绿，无库时 SKIP（`NEXTPAS_JS_QUICKJS_REQUIRED=1` 强制 fail） | `make focused FOCUS=core/tests/nextpas.core.js/test_js_quickjs_runtime` | AllPassed 或 SKIP |
| G-M2-2 | `bench_eval` 可编译运行（`nextpas.core.bench` 框架） | `make -C core/benchmarks/nextpas.core.js/bench_eval run` | ns/op 输出 |
| G-M2-3 |  loader 三名探测矩阵测试 | 同 G-M2-1 | 含探测名表 |

### M3 — 联动与加固

| 门禁 | 要求 | 命令 | 证据 |
|------|------|------|------|
| G-M3-1 | webview 13 门 + js 3 门双绿 | `make focused FOCUS=core/tests/nextpas.core.webview` + js | 全绿 |
| G-M3-2 | `bench_eval` 基线落库（`BENCHMARKS.md` 对齐） | `bench_eval` 输出 | 基线入库 |
| G-M3-3 | 悬垂/超时/循环引用 + `Close` 幂等 + `INV→用例` 映射全绿 | `test_js_fake` 扩展（见 `TESTING §3` 映射） | AllPassed |

### M4 — 纯 Pascal 后端（S3，`js.pure`）

| 门禁 | 要求 | 命令 | 证据 |
|------|------|------|------|
| G-M4-1 | `test_js_pure_runtime` 恒绿（零 so），同 `test_js_fake` 40+ 用例矩阵全绿 | `make focused FOCUS=core/tests/nextpas.core.js/test_js_pure_runtime` | AllPassed + heaptrc 0 |
| G-M4-2 | `source-contract` 纯后端零 FFI：`grep -R "platform\.dl" core/src/nextpas.core.js.pure.pas` 0 命中 | `check_source_contracts.py` | pass |
| G-M4-3 | `js.base/js.intf` 零改动（`git diff --stat` 无 `js.base/intf`），仅 `+js.pure` + `TJsBackendKind` 尾部 `jsbkPure` | `git diff` | 零改动证明 |
| G-M4-4 | `bench_eval` 对 `jsbkPure` 同口径 `ns/op+p50/p99+B/op` | `bench_eval` | 基线对齐 |

### M5 — 1.0 冻结（Production Ready）

| 门禁 | 要求 |
|------|------|
| G-P1 | M3 全绿 + 至少 1 个真实消费方（如 `webview.fake.js` 或 `template` 预编译）+ M4 纯后端门禁（若已触发） |
| G-P2 | CONTRACT 1.0 冻结 + CHANGELOG + 迁移指南 |
| G-P3 | `PARITY-go-rust` 基准对照已刷新（含纯/QuickJS 双基线实测） |
| G-P4 | `core-module-registry.md` 晋升 `focused-runtime`（或更高） |

---

## 3. 证据链

每个验收批次必须产出：

```
证据包/
  git-show-stat.txt         # git show --stat HEAD
  hygiene.log               # make hygiene 输出
  focused-heaptrc.log       # heaptrc 0 证据
  source-contract.log       # check_source_contracts.py 输出（若涉）
  bench.log                 # bench_eval 输出（若涉）
```

证据包随 `Ready` 报告提交，禁止“口头绿”。

---

## 4. 回归策略

| 触发 | 动作 |
|------|------|
| 契约变更（`CONTRACT` 改） | 必跑 `test_js_fake` + `test_js_pure_runtime`（若有） + `source-contract` + `bench_eval` 回归 |
| 错误语义变更 | 必补边界/失败路径用例（`TESTING §4`） |
| 内存/句柄生命周期变更 | 必跑 heaptrc + 追踪分配器（`TESTING §5`） |
| 跨模块变更（`webview.fake.js`） | 必跑双方 focused gate（`AGENTS.md` 跨模块纪律） |

---

## 5. 版本晋升规则

| 事件 | 版本动作 | 要求 |
|------|----------|------|
| 文档补课 | 0.3→0.4 | REVIEW H1–H3 清零 |
| M1 完成 | 0.4→0.5 | G-M1 全绿 |
| M2–M3 完成 | 0.5→0.9 | G-M2/G-M3 全绿 |
| 1.0 冻结 | 0.9→1.0 | G-P 全绿 + semver 冻结（见 CONTRACT §13） |

---

## 6. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-30 | 1.0 | 首版：DoD + 门禁矩阵 + 证据链 + 晋升规则 |

