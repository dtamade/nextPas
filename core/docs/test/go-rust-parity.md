# nextpas.core.test — Go / Rust 质量与规模对标

**Owner**: test lane（全权）
**当前版本**: **v8.24**
**最后更新**: 2026-07-21

---

## 1. 对标什么

对齐 **工程标准**（不是 API 长得像 Go）：

| 维度 | Go | Rust | nextPas |
|------|-----|------|---------|
| 公开 API 测试 | 导出有测 | 同左 | **source-contract 零裸奔** |
| 诊断 | cmp / testify | pretty_assertions / insta | ColorDiff + Snapshot 契约 |
| 并行/竞态 | t.Parallel / -race | 串行默认 | RunParallel + 原子压力测 |
| Prop/Fuzz | testing.F + 第三方 | proptest | 内置 + 可计数套件 |
| 规模 | 上千级自测 | 同左 | **≥5500 可计数过程 + fail-path≥30%** |
| 失败语义 | Error 可继续 / Fatal 停 | panic | **Check=Fatal**；**SoftFail** opt-in；Soft string=ColorDiff；高频 Soft Bool/Bytes/Near |

---

## 2. 当前基线

| 指标 | 值 |
|------|-----|
| 套件 | **19**（+ scale report） |
| 可计数过程 | **≥5500**（scale report；SCALE_MIN 默认 5500；FAIL_PATH_MIN_RATIO 默认 0.30） |
| Check*/To* 门禁 | 56 + 52 全引用 |
| Runner 门禁 | TestSeq/RunParallel/报告 API 等 23 项 |

---

## 3. 批次状态

| 批次 | 状态 |
|------|------|
| B1–B4 v8.8 | **done + main** |
| B5 v8.9a 有意义规模 | **done** |
| B6 Helper/Check=Fatal 文档 | **done** |
| B7 runner 门禁 | **done** |
| B8 v8.10 mock隔离/perf阈值/output深契约 | **done** |
| B9 v8.11a 危险并发契约 | **done** |
| B10 v8.11b Runner/Lifecycle 深度 | **done** |
| B11 v8.11c 规模报表+golden+≥1800 | **done** |
| B12 v8.12a 薄套件+边界收口 | **done** |
| B13 v8.12b 报告+门禁≥2000 | **done** |
| B14 v8.12c shrink+≥2500 | **done** |
| B15 v8.13a ApplyCLIArgsFrom | **done** |
| B16 v8.13b perf 软跨机策略 | **done** |
| B18 v8.14a 门禁诚实化 | **done** |
| B19 v8.14b report golden 入库 | **done** |
| B20 v8.14c subtests 深度 | **done** |
| B21 v8.15 CI golden + contracts 门禁 | **done** |
| B22 v8.16 SoftFail opt-in | **done** |
| B23–B24 v8.17 SoftFail 完成度 | **done** |
| B26 v8.18 薄套件加厚 | **done** |
| B27 v8.18 规模≥3000 + fail-path 硬门禁 | **done** |
| B28 v8.18 消费者 smoke_suite 示例 | **done** |
| B29 v8.19 SoftFail exact + golden | **done** |
| B30 v8.19 lifecycle/parallel/prop fail-path | **done** |
| B31 v8.19 tls e2e Makefile clean（跨模块） | **done** |
| B32 v8.19 SCALE_MIN=4000 | **done** |
| B33 v8.20 subtest SoftFail exact | **done** |
| B34 v8.20 CLI/MaxFailures + SoftFail contracts | **done** |
| B35 v8.20 softfail_demo | **done** |
| B36 v8.20 SCALE_MIN=4500 | **done** |
| B37 v8.21 Nested SoftFail 分层（产品） | **done** |
| B38 v8.21 Cache 指纹表 | **done** |
| B39 v8.21 薄套件加厚 | **done** |
| B40 v8.21 SCALE_MIN=5000 | **done** |
| B41 v8.22 ComputeKey stop 语义 | **done** |
| B42 v8.22 SoftFail parallel/outside/PushPop | **done** |
| B43 v8.22 thin + nested demo | **done** |
| B44 v8.22 SCALE_MIN=5500 | **done** |
| B45 v8.23 Soft ColorDiff + Soft 高频 (Bool/TBytes/Near) | **done** |
| B46 v8.23 ComputeKey field source-contract + Soft 矩阵文档 | **done** |
| B47 v8.24 sink → platform_console_write (no System.Write*) | **done** |
| B48 v8.24 ITestDiscoveryBackend + FPC VMT default + inject | **done** |

### 暂缓 / 阻塞

- IExpectation 类型拆分（v9 breaking）
- TSAN（无 FPC 一体化路径）
- 编译器 coverage 插桩（等 nextpas 编译器）
- 跨 OS perf **硬**门禁入库（软策略已做：PERF_SKIP / host baseline）

---

## 4. 门禁

```bash
make -C core/tests/nextpas.core.test/<suite> clean test
make -C core/tests/nextpas.core.test contracts   # api + runner source-contract + scale
make hygiene
make -C core/tests/nextpas.core.test clean test   # 19/19
# CI goldens: NEXTPAS_SNAPSHOT_FAIL_ON_CREATE=1
```


## 并行用户责任（可测）

| 误用 | 期望 |
|------|------|
| 跨线程用同一 `TMock` | fail `not thread-safe` |
| 在 worker 线程 `RegisterStub`/`RegisterFixture` | raise `main thread` |
| 并行测试内改 `GStubRegistry` 语义 | 禁止；仅 Setup 主线程注册 |


## Scale report

```bash
make -C core/tests/nextpas.core.test/test_scale_report test
# SCALE_MIN=5500 FAIL_PATH_MIN_RATIO=0.30 (defaults)
```

消费者示例：

```bash
make -C core/examples/nextpas.core.test/smoke_suite run
# SoftFail multi-message (expect exit 1 + join):
make -C core/examples/nextpas.core.test/softfail_demo run
# Nested SoftFail layering (expect exit 1):
make -C core/examples/nextpas.core.test/nested_softfail_demo run
```



## perf 策略

| 项 | 策略 |
|----|------|
| CI | **可选**（`test_perf_bench` / `perf-regression-check.sh`） |
| 阈值 | 默认 **+30%**（宽松防 flaky） |
| 跨机基线 | **不强制入库**；本机生成 `perf-baseline.json` 后对比 |
| 目标 | 对标 benchstat 意图，非硬性能 SLA |


## Scale 计数规则（v8.14）

可计数过程 =
1. `.Test('…')` 登记
2. `.TestSubtest('…')` 登记（Go `t.Run`）
3. `SetLength(cases, N)` + 邻近 `TestTable` → +N
4. `Append*Case(` 每次 +1

排除：`test_stress`、shell source-contract、`test_perf_bench`、`test_scale_report` 自身。


## Report goldens（仓内）

```
core/tests/nextpas.core.test/test_output/goldens/
  report.json  report.tap  report.xml
```

更新：在 suite 目录执行 `NEXTPAS_UPDATE_SNAPSHOTS=1 make test`。
Parallel 下 `TestSubtest` 仍 serial-only（skip + 消息契约）。
