# nextpas.core.test 可用性修复实施规划

**规划日期**: 2026-07-05
**前置文档**: research-report-2026-07-05.md
**总工作量**: ~4 天（含测试 + 文档）

---

## 里程碑

### M1: P1 安全加固 (Day 1)
**目标**: 消除 API 陷阱和线程安全防护缺陷

| 任务 | 文件 | 改动 | 测试 |
|------|------|------|------|
| E-01a: With* 方法添加 deprecated 警告 | runner.pas | 6 处 `deprecated` | 编译验证警告 |
| E-01b: README 推荐直接修改方法 | README.md | 新增 "推荐用法" 段落 | — |
| E-06: Assert → 运行时检查 | runner.pas | 2 处 Assert→if-raise | test_advanced 编译验证 |
| E-05: GExecState finalization 安全网 | base.pas | 1 处 finalization 增强 | test_runner 编译验证 |

**验收标准**:
- `make -C core/tests/nextpas.core.test test_runner test` 全绿
- `make -C core/tests/nextpas.core.test test_advanced test` 全绿
- With* 使用处产生编译警告

---

### M2: P2 API 统一 (Day 2)
**目标**: 消除命名不一致和 API 膨胀

| 任务 | 文件 | 改动 | 测试 |
|------|------|------|------|
| E-02: ShouldFail ADummy 重载 deprecated | runner.pas + facade | 2 处 deprecated | test_runner 编译验证 |
| E-03: CheckEqualMsg deprecated | check.pas + facade | 4 处 deprecated | test_assertions 编译验证 |
| E-04: TTestConfigBuilder 新增 | config.pas + facade | 新增 ~80 行 | 新增 config builder 测试 |

**验收标准**:
- `make -C core/tests/nextpas.core.test test` 全绿
- deprecated 方法编译产生警告
- TTestConfigBuilder 可用

---

### M3: P3 功能增强 (Day 3)
**目标**: 补全缺失 API 和修复小逻辑缺陷

| 任务 | 文件 | 改动 | 测试 |
|------|------|------|------|
| E-07: RunnerConfig 合并逻辑 | runner.pas | ~20 行修改 | test_runner 验证 |
| E-08: CheckNaN/ExpectNaN 新增 | check.pas + expect.pas + facade | ~60 行新增 | 新增 6 个 NaN 测试 |
| E-09: Mock When API | mock.pas | ~100 行新增 | 新增 8 个 Mock 测试 |
| E-11: 文件:行号 格式改进 | base.pas (FormatTestLocation) | ~10 行修改 | test_diagnostics 验证 |
| E-13: 并行子测试文档标注 | README.md | 1 行 | — |

**验收标准**:
- `make -C core/tests/nextpas.core.test test` 全绿
- CheckNaN/ExpectNaN 可用
- Mock.When 可用

---

### M4: P3 质量加固 (Day 4)
**目标**: 自测试套件 + Benchmark 基线

| 任务 | 文件 | 改动 | 测试 |
|------|------|------|------|
| E-10: test_selftest 套件 | 新增 test_selftest/ | ~200 行 | 自身即测试 |
| E-12: Benchmark 基线对比 | runner.pas + cli.pas + output.pas | ~150 行 | test_runner 新增 |

**验收标准**:
- `make -C core/tests/nextpas.core.test/test_selftest test` 全绿
- `--benchsave` / `--benchcompare` 可用

---

## 依赖关系

```
M1 (Day 1) ──→ M2 (Day 2) ──→ M3 (Day 3) ──→ M4 (Day 4)
  E-01          E-02          E-07          E-10
  E-06          E-03          E-08          E-12
  E-05          E-04          E-09
                              E-11
                              E-13
```

M1→M2→M3→M4 严格串行（每个 milestone 依赖前一个的代码状态）。
M3 内部 E-07/E-08/E-09/E-11/E-13 可并行。

---

## 风险缓解

| 风险 | 缓解措施 |
|------|---------|
| deprecated 警告污染 CI 输出 | 使用 `{$WARN SYMBOL_DEPRECATED OFF}` 在 facade 中抑制 |
| Config builder 与现有 SetDefault* 冲突 | builder 仅作为补充 API，不替代现有 |
| Mock When 改变 GetReturn 语义 | 新增独立方法，不修改现有 GetReturn |
| 输出格式改变影响 snapshot 测试 | 新增格式选项，保留默认行为不变 |

---

## 回滚策略

每个 Milestone 完成后运行完整测试套件：
```bash
make -C core/tests/nextpas.core.test test
```

如果任何测试回归，立即回滚该 Milestone 的所有改动。
