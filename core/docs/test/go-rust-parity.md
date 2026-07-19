# nextpas.core.test — Go / Rust 质量与规模对标

**Owner**: test lane（全权）
**当前版本**: **v8.11a**
**最后更新**: 2026-07-19

---

## 1. 对标什么

对齐 **工程标准**（不是 API 长得像 Go）：

| 维度 | Go | Rust | nextPas |
|------|-----|------|---------|
| 公开 API 测试 | 导出有测 | 同左 | **source-contract 零裸奔** |
| 诊断 | cmp / testify | pretty_assertions / insta | ColorDiff + Snapshot 契约 |
| 并行/竞态 | t.Parallel / -race | 串行默认 | RunParallel + 原子压力测 |
| Prop/Fuzz | testing.F + 第三方 | proptest | 内置 + 可计数套件 |
| 规模 | 上千级自测 | 同左 | **≥1500 可计数过程** |
| 失败语义 | Error 可继续 / Fatal 停 | panic | **Check = Fatal**（raise） |

---

## 2. 当前基线

| 指标 | 值 |
|------|-----|
| 套件 | **18**（api + runner source-contract） |
| 可计数过程 | **≥1500**（排除 stress 10K 空） |
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

### 暂缓

- IExpectation 类型拆分
- SoftFail API（破坏性；文档钉死 Check=Fatal）
- TSAN / 编译器覆盖率插桩

---

## 4. 门禁

```bash
make -C core/tests/nextpas.core.test/<suite> clean test
make hygiene
make -C core/tests/nextpas.core.test clean test   # 17/17
```


## 并行用户责任（可测）

| 误用 | 期望 |
|------|------|
| 跨线程用同一 `TMock` | fail `not thread-safe` |
| 在 worker 线程 `RegisterStub`/`RegisterFixture` | raise `main thread` |
| 并行测试内改 `GStubRegistry` 语义 | 禁止；仅 Setup 主线程注册 |
