# nextpas.core.test — Go / Rust 质量与规模对标

**Owner**: test lane（全权）
**基线版本**: v8.7（已 land）
**目标里程碑**: **v8.8** 起按批次推进
**最后更新**: 2026-07-19

---

## 1. 对标什么

不是「把 API 做成 Go 样子」，而是对齐 **工程标准**：

| 维度 | Go 参考 | Rust 参考 | nextPas 目标 |
|------|---------|-----------|--------------|
| 公开 API 测试 | 每个导出符号有正/负路径 | 同左 | **零裸奔公开断言 API** |
| 诊断质量 | `cmp.Diff` / testify | `pretty_assertions` / `insta` | 失败消息可定位、可 diff |
| 子测试 / 表驱动 | `t.Run` / table | 有限 | 已有；规模继续堆 |
| 并行 / 竞态 | `t.Parallel` / `-race` | 串行默认 | `RunParallel` + 竞态类 stress |
| 属性 / Fuzz | `testing/F` + 第三方 | proptest | 已有 Prop/Fuzz；套件可计数 |
| 快照 | 第三方 | insta | CheckSnapshot / ToMatchSnapshot |
| 性能门禁 | benchstat | criterion | test_perf_bench |
| 自测规模 | 框架 + 生态上千级 | 同左 | **≥1500 可计数过程**（分批爬升） |

---

## 2. 当前基线（实测）

| 指标 | 值 |
|------|-----|
| 框架源码 | ~17k LOC / 17 `.pas` |
| 自测套件 | 16 |
| 约测试过程 | ~930（不含 stress 10K 展开） |
| Check* 公开名 | ~56 |
| Expect To* | ~52 |
| v8.7 缺口 | CheckOneOf* / CheckInstanceOf 在 `test_assertions` **无引用**；ToMatchSnapshot 在 `test_expect` **无引用** |

---

## 3. 里程碑批次

### Batch B1 — v8.8a「零裸奔 API」（本批）

| 切片 | 内容 | 聚焦门禁 |
|------|------|----------|
| B1.1 | 路线图本文档 | — |
| B1.2 | CheckOneOf*/CheckInstanceOf 正负路径 + 空集/nil | `test_assertions` |
| B1.3 | ToMatchSnapshot 创建/匹配/失配 | `test_expect` |
| B1.4 | source-contract：公开 Check*/To* 必须在自测中出现 | `test_api_source_contracts` |
| B1.5 | 全量 16/16 + hygiene + CONTRACT 版本 | 全量 |

**成功标准**: 无公开 Check*/To* 在自测中 0 引用；聚焦 + 全量绿。

### Batch B2 — v8.8b「诊断与可观测」（下一里程碑）

- 多行 unified diff 对齐 go-cmp 可读性（在现有 StringDiff/彩色 diff 上增强）
- Snapshot fail-on-create / update 路径单测完整
- diagnostics 套件扩大失败消息契约（关键子串稳定）

### Batch B3 — v8.8c「规模爬升」

- test_prop 纳入可计数 TTestSuite 注册（或并行计数器）
- discovery / diagnostics / subtests 过程数倍增
- 目标合计 **≥1200** 可计数过程

### Batch B4 — v8.8d「竞态与压力」

- 对标 `-race` 意图：共享状态误用可失败、并行 hook 压力
- stress 增加有断言的竞态场景（非仅 10K 空测试）

### 暂缓（明确不做）

- `IExpectation` 类型拆分（P3 / v9）
- 编译器插桩覆盖率（需 LLVM/后端）
- 把断言做成零开销内联宏（语言限制；保持可观测性优先）

---

## 4. 质量门禁（强制）

每切片：

```bash
make focused FOCUS=core/tests/nextpas.core.test/<suite>
# 或 make -C core/tests/nextpas.core.test/<suite> clean test
```

里程碑收尾：

```bash
make hygiene
make -C core/tests/nextpas.core.test clean test   # 16/16
```

证据：命令 + exit 0 + 摘要行。无证据不宣称完成。

---

## 5. 状态

| 批次 | 状态 |
|------|------|
| B1 v8.8a 零裸奔 API | **done**（已 land main） |
| B2 v8.8b 诊断质量 | **done**（已 land main） |
| B3 v8.8c 规模爬升 | **done**（prop 可计数 + table bulk ≥1200） |
| B4 v8.8d 竞态/压力 | **done**（原子计数 / TestSeq / Expect 风暴 / stress 并行） |
