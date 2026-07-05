# bench 模块可用性改进实施规划

**日期**: 2026-07-05
**调研报告**: `docs/usability-audit-research.md`
**策略**: B（全面修复，19/19 findings）

---

## 里程碑规划

### M1: 接口语义修正 (F-01, F-02, F-03, F-13)
- 依赖: 无
- 预计: 2h
- 验证: 现有测试全通过 + 新增测试

### M2: API 一致性 (F-04, F-05, F-06, F-07)
- 依赖: 无
- 预计: 1.5h
- 验证: 现有测试全通过

### M3: 错误提示 + 边界条件 (F-08, F-09, F-10, F-11, F-12)
- 依赖: 无
- 预计: 2h
- 验证: 现有测试全通过 + 新增 timeout 测试

### M4: 并发安全 + 性能 (F-16, F-17, F-18, F-19)
- 依赖: 无
- 预计: 2.5h
- 验证: 现有测试全通过 + heaptrc 0 leaks

### M5: 测试覆盖 (F-14, F-15)
- 依赖: M3 (timeout 变更)
- 预计: 1.5h
- 验证: 新增测试全通过

---

## 依赖关系图

```
M1 (接口语义) ──┐
M2 (API 一致性) ─┤── 无依赖，可并行
M3 (错误提示)   ─┤
M4 (并发+性能)  ─┘
                │
                ▼
          M5 (测试覆盖) ← 依赖 M3 的 timeout 变更
```

---

## 每个 Milestone 的具体改动

### M1: 接口语义修正

| Finding | 文件 | 改动 |
|---------|------|------|
| F-01 | intf.pas, bench.pas, runner.pas | 新增 `TBenchLoopContextFunc` 类型 + `AddLoopWithContext` 方法 + `ExecuteLoopEntry` 分支 |
| F-02 | intf.pas | `CompareTwoResults` 文档标注 "ANameA=current, ANameB=baseline" |
| F-03 | intf.pas | `TBenchBaseline` 添加 `@deprecated` 注释 |
| F-13 | stats.pas, bench.pas | `GeometricMean` 非正 ratio 返回 `NaN`，报告层显示 "N/A" |

新增测试:
- `TestAddLoopWithContext` (integration)
- `TestGeometricMean_NaN` (stats)

### M2: API 一致性

| Finding | 文件 | 改动 |
|---------|------|------|
| F-04 | intf.pas, bench.pas | 每个 Add*Baseline 方法添加使用场景文档 |
| F-05 | intf.pas, base.pas, bench.pas | `SetTimeout` 参数 `Cardinal` → `Int64` |
| F-06 | intf.pas | `SetFilter` 文档标注 glob 支持 |
| F-07 | base.pas | `TBenchConfig.TimeoutMs` 类型统一为 `Int64` |

### M3: 错误提示 + 边界条件

| Finding | 文件 | 改动 |
|---------|------|------|
| F-08 | stats.pas | 已有文档，无需改动 |
| F-09 | bench.pas | `GetByName` 异常消息添加可用名称列表 |
| F-10 | bench.pas | 保持警告，可选增加 `HasWarnings` |
| F-11 | runner.pas | `CollectEntrySamples` 增加 timeout 检查 |
| F-12 | stats.advanced.pas | BootstrapCI 种子增加全局计数器 |

新增测试:
- `TestTimeout_Combined` (integration)

### M4: 并发安全 + 性能

| Finding | 文件 | 改动 |
|---------|------|------|
| F-16 | runner.pas | `RunOne` 入口增加 `GBridgeRunner` 并发断言 |
| F-17 | stats.pas | 新增 `ComputePercentiles` 单遍扫描函数 |
| F-18 | baseline.pas | 增加 `Clone` 深拷贝方法 |
| F-19 | memtrack.pas | 调研 FPC `InterlockedAdd64` 支持，如支持则替换 CAS |

### M5: 测试覆盖

| Finding | 文件 | 改动 |
|---------|------|------|
| F-14 | test_bench_integration | 新增 `TestTimeout_Combined` |
| F-15 | test_bench_parallel | 新增 `TestThreadCount1` |

---

## 验证标准

每个 Milestone 完成后:
1. `make -C core/tests/nextpas.core.bench clean test` — 全通过
2. heaptrc 0 leaks
3. `git diff --check` — 无空白错误
4. contract gate 全通过

最终合并前:
1. 全部 14+ 测试套件通过
2. 0 failed / 0 leaks
3. 无新增 compiler warnings
4. `make hygiene` 通过
