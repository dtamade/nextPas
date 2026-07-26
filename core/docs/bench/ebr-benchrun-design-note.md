# EBR × BenchRun 设计备忘（未立项）

**状态**：备忘 only · **明确不实现（F-23 Deferred-closed）** · 2026-07-20 / 确认 2026-07-26
**相关**：`goal-tree.md`；`nextpas.core.lockfree.ebr`（`TEbrDomain`）；现有 `TBenchRun`（原子结果收集）

---

## 1. 动机（为何有人会提）

- 并行 / 高并发采样时，临时节点与结果槽的回收若与 epoch-based reclamation 对齐，可减少「延迟 free」与悬垂读窗口的 ad-hoc 方案。
- 仓库已有 `TEbrDomain`（lockfree）与 `TBenchRun`（bench 侧无锁收集），自然会问：是否要做 **EBR 感知的 Bench 执行器**。

---

## 2. 现状（不要写偏）

| 组件 | 状态 |
|------|------|
| `TBenchSuite` / `TBenchRunner` | 生产路径；API 冻结策略下不宜大拆 |
| `TBenchRun` | 已有线程安全原子结果收集（**不是** EBR） |
| `TEbrDomain` | 在 **lockfree** 模块；bench micro 仅测 `Retire` 路径 |
| 本仓库 | **无** `BenchRun`+EBR 融合执行器 |

---

## 3. 非目标（本备忘与当前 bench lane）

- 不改 `IBenchSuite` / 公共 Fluent API
- 不拆 `bench.pas` 大文件
- 不替换 `TBenchRunner` 为默认路径
- 不把 lockfree EBR 搬进 L1 bench 依赖图（跨层需单独 ADR）

---

## 4. 若将来开独立 lane：最小设计清单

1. **问题陈述**：EBR 要解决的具体失败模式（用现有 `TBenchRun` 无法表达的哪一类）。
2. **所有权**：EBR domain 谁 Create/Destroy；与 suite 生命周期关系。
3. **与 `TBenchRun` 关系**：扩展 vs 旁路实现；禁止双路径语义分叉。
4. **API 面**：是否新类型、是否可选配置（默认关）。
5. **失败语义**：retire 失败、epoch 卡死、超时。
6. **测试门**：单测 + 并行 heaptrc + 不拖慢 `bench-module-test` 默认路径。
7. **退出标准**：Ready 报告含 focused gate + 文档 + 不破坏消费侧 **22** 模块 checklist。

---

## 5. 打开条件

- 总控或架构评审 **明确授权** 独立 lane（非 bench 消费侧维护顺手开）。
- 否则维持 **推迟**：见 `goal-tree.md` 未来候选。

---

## 6. 相关入口

- 消费侧：[consumer-checklist.md](consumer-checklist.md)（**22** 模块）
- 框架入口：[README.md](README.md)
- lockfree EBR 实现：`core/src/nextpas.core.lockfree.ebr.pas`
