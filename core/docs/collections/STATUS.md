# nextpas.core.collections — 状态

**更新日期**：2026-07-20
**阶段**：稳定维护 + 正确性/性能收敛（landing candidate）
**分支 / worktree**：`collections` / `.worktrees/collections`

## 已完成（历史目标树）

| 目标 | 状态 | 摘要 |
|------|------|------|
| G-ARCH | 完成 | Stack/Set 身份收敛；MakeXxx 工厂；IList Unchecked 清理；接口形状审查 |
| G-CORRECT | 完成 | VecDeque/RBTree 等关键 bug 修复 |
| G-TESTED | 完成 | 全容器 focused suites；heaptrc 零泄漏路径；错误路径 |
| G-PERF | 完成 | introsort、三路分区、VecDeque Rotate、HashMap 负载 0.75 等 |
| G-BENCH | 完成 | `core/benchmarks/nextpas.core.collections/*` 与跨语言对比 |

公共接口语义按 **软冻结** 管理：不随意改行为；允许补齐 public 工厂与文档；实现层可优化。

## 本 lane 交付

| 阶段 | 内容 | 状态 |
|------|------|------|
| Wave 0 | 同步 main；CONTRACT/README；STATUS | **完成** |
| Wave 1 | `MakeMap`/`MakeSet`；HashMap 默认 Swiss 文档 | **完成** |
| Wave 2 | 大文件 `.inc` 机械拆分 | **取消**（无实质收益；vecdeque 保持单文件） |
| Wave 3 | HashSet Swiss 后端 | **完成** |
| Phase A | Swiss abstract 补洞、消费者审计 | **完成** |
| Phase B | `bench_set` 数字落盘 | **完成**（PERF-HASHSET.md） |
| Phase C | 真职责审计（非按行数拆文件） | **完成**（OWNERSHIP-AUDIT.md） |
| Phase D–E | Multi*/Lru/LinkedHash/Builder → Swiss | **完成** |
| Ready | rebase 最新 main；历史去噪；landing candidate | **完成** |

## 明确不做

- 为「接口更小」批量删能力方法
- 按行数机械 `.inc` 拆文件
- open generic 门面 alias / 第二套 interface 身份
- 无 bench 证据的哈希算法替换
- 跨模块顺手重构（除非 contract 阻塞）

## 权威文档

- 契约：[`CONTRACT.md`](CONTRACT.md)
- 导航：[`README.md`](README.md)
- 性能：[`PERF-HASHSET.md`](PERF-HASHSET.md)
- 消费者：[`CONSUMERS.md`](CONSUMERS.md)
- 职责：[`OWNERSHIP-AUDIT.md`](OWNERSHIP-AUDIT.md)
- 根目录 `task_plan.collections.md` 等：**历史记录**，已 supersede

## 验证入口

```sh
make focused FOCUS=core/tests/nextpas.core.collections/test_facade
make hygiene
git diff --check
```
