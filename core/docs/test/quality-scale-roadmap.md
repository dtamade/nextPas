# nextpas.core.test — Go/Rust 质量与规模路线图

**Owner**: test lane（`.worktrees/test`）— **全权**  
**北极星**: 对标 **Go `testing` + 工程门禁** / **Rust 测试工程纪律** 的**质量与规模**，不是 API 化妆。  
**当前基线**: **v8.26**（SCALE≥6500 质量跃迁）  
**最后更新**: 2026-07-21  

---

## 1. 北极星（可量化）

| 指标 | 当前 (v8.25) | 近中期目标 | 对标意图 |
|------|--------------|------------|----------|
| 可计数过程 `SCALE_MIN` | **6500**（v8.26 门） | **7500 → 9000** | Go 大模块自测体量 |
| fail-path 占比 | **≥35%** 硬门 | 维持 **≥35%** | 有意义负路径，非绿灌水 |
| low-signal 占比 | **≤40%** 硬门 | 收紧 **≤25%** | 反 identity/meta 灌水 |
| 公开 API 裸奔 | Check*/To*/runner 门禁 | **扩大到 Soft* 全名 + runner 报告字段** | 导出必有测 |
| Soft 语义 | Fatal/Soft 分离 + 高频 Soft | Soft 高频再扩 + Soft 消息 golden | Go `t.Error` vs `t.Fatal` |
| 并行/竞态 | 契约 + 原子压力 + TimeoutWorkerLeaks | 再加「误用必 fail」表 + 压力可计数 | Go `-race` 意图（无 TSAN） |
| 子测试 | nested Soft + TestSubtest | 深嵌套/聚合消息契约表 | Go `t.Run` |
| 诊断 | ColorDiff / Snapshot / Soft ColorDiff | Soft/Check 失败 golden 扩库 | pretty_assertions / insta |
| 缓存诚实 | ComputeKey stop 字段 | 字段名单 + 行为表持续锁 | `go test` cache 意图 |
| 编译器透明 | sink platform + Discovery backend | nextpas backend stub 契约（空实现可注入） | 双编译器 |

### 明确不做（本路线图）

| 项 | 原因 |
|----|------|
| IExpectation 类型拆分落地 | v9 breaking；另开 RFC |
| Soft 1:1 镜像全部 Check* | 维护爆炸；只做高频+可测 |
| TSAN 一体化 | 工具链阻塞 |
| 编译器 coverage 插桩 | 等 nextpas 编译器 |
| 跨 OS perf 硬门禁 | 软策略已够；防 flaky |
| raw-merge test → main | path-limited + ff only |

---

## 2. 已完成阶段（摘要）

| 版本 | 主题 | 质量/规模贡献 |
|------|------|----------------|
| v8.8–v8.15 | 门禁、golden、CLI、规模爬升 | 工程骨架 |
| v8.16–v8.20 | SoftFail、fail-path、规模 3k–4.5k | Go Error/Fatal 语义 |
| v8.21–v8.22 | Nested Soft、ComputeKey 诚实、scale≥5500 | t.Run 分层 + cache |
| v8.23 | Soft ColorDiff + Soft 高频 | 诊断对齐 + Soft 可用面 |
| v8.24 | platform sink + Discovery backend | 编译器透明边角 |
| **v8.25** | TimeoutWorkerLeaks + low-signal 门 | 并行可观测 + 反灌水 |
| **v8.26** | 灭 identity + SCALE≥6500 + 三门收紧 | 质量跃迁 **done** |

---

## 3. 后续任务树（全权执行序列）

原则：每版 **一个主题** + **可测验收** + path-limited land；数字抬升必须绑定**新契约/新 fail-path**，禁止 identity 灌水。

```
v8.26  规模质量跃迁（替换 identity + SCALE≥6500）  ✅
v8.27  Soft 第二波 + Soft 诊断 golden              ← next
v8.28  Runner/Subtest/CLI 深度（Go testing 行为）
v8.29  并行竞态与 Mock 误用密度
v8.30  Prop/Fuzz/Snapshot 工程密度 + SCALE≥7500
v8.31+ 收紧 low-signal≤25%；消费者示例；CI 默认 contracts
v9     （另拍板）IExpectation 拆分 / SoftExpect
```

---

### v8.26 — 规模质量跃迁（**done**）

| ID | 任务 | 状态 |
|----|------|------|
| B51 | config identity → fingerprint fail-path 500 | **done** |
| B52 | diagnostics 去 identity；equal 1800 + notequal 400 | **done** |
| B53 | lifecycle 160 / Soft assertions 200 / advanced Soft 120 | **done** |
| B54 | SCALE 6500 / fail-path 35% / low-signal 40% | **done** |
| B55 | per-suite fail-path/low-signal breakdown | **done** |

---

### v8.27 — Soft 第二波 + 诊断 golden（P0 下一刀）

**目标**: Soft 更接近 Go「任意多 Error 后汇总」。

| ID | 任务 | 验收 |
|----|------|------|
| B56 | Soft 高频再扩：`SoftCheckNil`/`SoftCheckNotNil`、`SoftCheckEmpty`（string）、`SoftCheckContainsCI`（可选） | api source-contract 含新名 |
| B57 | Soft 失败消息 **golden**（TAP/JSON 或 diagnostics exact 表） | FAIL_ON_CREATE 可过 |
| B58 | Soft + MaxFailures / FailFast 交叉表再钉（并行+串行） | runner/parallel 契约 |
| B59 | Soft 消息 join 在含 ColorDiff 换行时的 **稳定契约**（文档 + 测） | 不 flaky |
| B60 | `softfail_demo` 扩一则 Bool/Near 示例（或新 demo） | examples 可 run |

---

### v8.28 — Runner / Subtest / CLI ≈ Go testing（P1）

**目标**: 行为密度对齐 `go test` 用户预期。

| ID | 任务 | 验收 |
|----|------|------|
| B61 | 深嵌套 `TestSubtest`（≥3 层）失败聚合 + Soft 分层 exact | subtests 表 |
| B62 | hierarchical filter 负路径表扩（`Parent/Sub/*`、brace） | output/runner |
| B63 | CLI：`--count` / `--short` / `--failfast` / `--failures-max` 交叉表 | ApplyCLIArgsFrom 表 |
| B64 | `t.Helper` 意图：IsFrameworkFrame 过滤契约（栈顶不含 test.* 内部） | base/diagnostics |
| B65 | Skip / ShortSkip 在 table+parallel 下计数 exact | parallel/lifecycle |

---

### v8.29 — 并行竞态与 Mock 误用密度（P1）

**目标**: 无 TSAN 下最大化「误用必红」。

| ID | 任务 | 验收 |
|----|------|------|
| B66 | 并行原子计数/Expect 风暴再加 **可计数** fail-path 变体 | parallel scale↑ |
| B67 | Mock：跨线程 + Verify 次数 + InOrder 负路径表加厚 | mock fail-path |
| B68 | RegisterStub/Fixture 非主线程 **消息 exact** 表 | runner contracts |
| B69 | TimeoutWorkerLeaks：可控 stuck 路径（若可安全模拟）或文档+计数只读契约 | 不 flaky CI |
| B70 | `TestSeq` 与 parallel 可见性契约再钉 | parallel |

---

### v8.30 — Prop/Fuzz/Snapshot 工程密度 + SCALE≥7500（P1）

| ID | 任务 | 验收 |
|----|------|------|
| B71 | Prop shrink 确定性种子表 + ExpectFail 消息 | prop |
| B72 | Fuzz corpus 读写边界 + 空/坏语料 | prop |
| B73 | Snapshot：create/update/mismatch/ColorDiff 表再扩 | assertions |
| B74 | `SCALE_MIN=7500`；low-signal **≤25%** | scale 三门 |
| B75 | 消费者：`table_driven_demo` 或扩 smoke_suite（Table+Soft+Subtest） | examples |

---

### v8.31+ — 巩固与 CI 默认（P2）

| ID | 任务 | 验收 |
|----|------|------|
| B76 | 仓库 CI 文档默认 `make -C core/tests/nextpas.core.test contracts` | docs |
| B77 | `LOW_SIGNAL_MAX_RATIO=0.25` 默认 | scale |
| B78 | `SCALE_MIN=9000` 仅当 fail-path≥35% 且 low-signal≤25% | 条件抬门 |
| B79 | nextpas Discovery backend **stub 单元测试**（返回空/固定名表） | discovery |
| B80 | 全量 19/19 + demos 作为 release checklist 固化进 README | docs |

---

## 4. 每版执行纪律（不变）

1. 仅 `.worktrees/test` 开发  
2. 每版结束：`make hygiene` + `make -C core/tests/nextpas.core.test contracts` + 相关 suite + demos  
3. path-limited landing worktree → 祖先检查 → `git push origin HEAD:main`（无 force）  
4. Ready 报告：SHA、文件清单、scale 三数字、禁止带入清单  
5. 跨模块仅最小必要（如 Makefile clean），单独列出  

---

## 5. 决策表（全权默认）

| 冲突 | 默认选择 |
|------|----------|
| 抬 SCALE vs 质量 | **先质量**（契约/fail-path），再抬 MIN |
| 新 Soft API vs 更多 Soft 测 | **先测满现有 Soft**，再扩 1–3 个高频 API |
| 并行 flaky vs 覆盖 | 可 flaky 的 stuck 线程 **不做默认 CI 硬门**；只做计数/WARNING |
| 文档 vs 代码 | 同版同步 CONTRACT + go-rust-parity 批次状态 |
| v9 拆接口 | **不进 v8.x**；用户明确拍板再开 |

---

## 6. 立即下一刀（默认开工序）

**v8.27** Soft 第二波 + golden（B56–B60）。

---

## 7. 状态汇报模板

- **Ready**: 版本、HEAD、scale 三门数字、改动路径、验证命令、land SHA  
- **Blocked**: 条件、已尝试、需谁决策（仅 v9/TSAN/coverage 类）  
- **Landed**: origin tip、祖先检查、marker  

---

*本文件为 test lane 活动路线图权威之一；稳定契约仍以 `CONTRACT.md` 为准。批次勾选同步 `go-rust-parity.md`。*
