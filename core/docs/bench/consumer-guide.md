# nextpas.core.bench 消费侧指南

面向 **在模块里写基准测试** 的同事（HTTP / collections / text / …），而不是框架内核开发者。

权威 API 表见 [README.md](README.md)；目标树见 [goal-tree.md](goal-tree.md)。

## 1. 最小可运行配方

```pascal
program bench_foo;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.bench,
  nextpas.core.time.base;

procedure BenchHotPath(const ACtx: IBenchContext);
begin
  { 只放被测逻辑；setup 用 ResetTimer 排除 }
  ACtx.SetBytes(1024);  { 可选：吞吐 }
end;

var
  LResults: IBenchResults;
begin
  LResults := TBenchSuite.Create('Foo')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Foo/HotPath', @BenchHotPath)
    .Run;

  WriteLn(LResults.PrintToConsole);
  LResults.SaveToJSON('build/bench-foo.json');
end.
```

- **禁止** `uses SysUtils` / `Classes` 等 FPC RTL（项目隔离约束）；`WriteLn` 用 System 内建即可。
- 目录：`nextpas.core.fs.ForceDirectories('build')`；JSON 落到 `build/`。
- 防优化：`BenchBlackBoxInt64` / `BenchBlackBoxPtr` / `BenchBlackBoxBytes`（见 README Canonical）；热点路径末尾调用，避免 DCE。
- 用户控制循环优先 **`AddLoopWithContext`**，不要用无 context 的 `AddLoop` 还指望 `SetBytes`。
- **`core/benchmarks/nextpas.core.*` 禁止** `uses SysUtils/Classes/...`（`platform-comparison` 对照除外）；门禁见 `scripts/bench-contract-check.sh` C9。

## 2. 命名约定

使用 **`Domain/Op`** 或 **`Type/N=size`**，方便分组 API：

| 好 | 差 |
|----|-----|
| `HashMap/Get/hit` | `bench1` |
| `Sort/Quick/1k` | `test` |
| `JSON/Parse/4KB` | `json` |

`GetGroups` / `To*_Grouped` 按**首个 `/` 前**分组。

## 3. 常用 Builder

| 方法 | 何时用 |
|------|--------|
| `Add` / `AddWithSetup` | 默认；需要 setup/teardown 时用后者 |
| `AddRange` | 参数化 N |
| `AddParallel` | 多线程吞吐（注意 memtrack 限制） |
| `SetFilter('Sort*')` | 只跑子集；`*` 可跨 `/`（bench.base.GlobMatch） |
| `EnableMemoryTracking` | 看 B/op、allocs/op |
| `CollectRawSamples` | 要箱线图 / 高级分布 |

## 4. 结果怎么用（读侧）

跑完得到 `IBenchResults`：

```pascal
LResults.PrintToConsole;
LResults.ToJSON;                    { CI 工件 }
LFiltered := LResults.FilterByPrefix('HashMap/');
LGroups := LResults.GetGroups;
if LResults.HasRegression(1.10) then Halt(1);
```

更多：`GetFastest` / `GetSummaryStats` / `CompareGroups` / `ToMatrixJSON` —— 见 `test_bench_results_api`。

## 5. 基线与回归

1. 本地：`SaveBaseline(Path)` / `LoadBaseline`
2. CI：先跑模块 gate，再对业务 bench 二进制做阈值比较
3. 模板：`core/docs/bench/ci-gate.sh`（模块测试 smoke）

## 6. 仓库布局约定

| 路径 | 用途 |
|------|------|
| `core/benchmarks/nextpas.core.<mod>/` | 模块正式 micro-bench（推荐） |
| `core/examples/bench/` | 框架用法示例（quick_start、ci_integration…） |
| `core/examples/nextpas.core.bench/` | demo_basic / memtrack / xlang |
| `bench/<track>/` | 跨语言 scorecard 竞技场（Pascal+Go 等；**新 track 放这里**） |
| 仓库根 `arrayops/` 等 | 历史散落 micro；**不推荐**新增大目录到根 |

## 7. 验证

```bash
# 框架仍绿
make -C core/tests/nextpas.core.bench clean test

# 结果 API 专项
make -C core/tests/nextpas.core.bench/test_bench_results_api clean test

# 模块 harness smoke
make -C core/benchmarks/nextpas.core.bench clean test
```

## 8. 示例入口

| 文件 | 学什么 |
|------|--------|
| `core/examples/bench/quick_start.pas` | Fluent + lambda |
| `core/examples/bench/ci_integration.pas` | 基线 / 回归 |
| `core/examples/bench/custom_metrics.pas` | 自定义指标 |
| `core/benchmarks/nextpas.core.hash/bench_hash/` | 真实模块 bench |

对照表：[consumer-checklist.md](consumer-checklist.md)（**22** 模块抽检；C3 模板见该文）。

## 8b. 轻量跨语言子集重跑

```bash
# 仓库根一键 smoke
make bench-scorecard-smoke

# 列出 / 全量 / 部分 / TSV 摘要
bash core/docs/bench/scripts/run-scorecard-subset.sh --list
bash core/docs/bench/scripts/run-scorecard-subset.sh
bash core/docs/bench/scripts/run-scorecard-subset.sh --tracks boolsum,inttohex
bash core/docs/bench/scripts/run-scorecard-subset.sh --tracks inttohex --summary
```

清单：`scorecard-tracks.txt`。数字表：`scorecard-subset-2026-07-19.md`。

## 9. 不要做的事

- 在 hot path 里 `WriteLn` / 日志
- 把 setup 算进计时（用 `ResetTimer` / `StopTimer`）
- 依赖未文档化的内部类型
- 继续向 `IBenchResults` 要求新「便利方法」（**API 冻结**）——优先组合现有 Filter/Get*
