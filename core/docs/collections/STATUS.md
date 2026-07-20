# nextpas.core.collections — 状态

**更新日期**：2026-07-20
**阶段**：**Landed / 维护 idle**
**分支 / worktree**：`collections` / `.worktrees/collections`

## 已完成（历史目标树）

| 目标 | 状态 | 摘要 |
|------|------|------|
| G-ARCH | 完成 | Stack/Set 身份收敛；MakeXxx 工厂；IList Unchecked 清理；接口形状审查 |
| G-CORRECT | 完成 | VecDeque/RBTree 等关键 bug 修复 |
| G-TESTED | 完成 | 全容器 focused suites；heaptrc 零泄漏路径；错误路径 |
| G-PERF | 完成 | introsort、三路分区、VecDeque Rotate、HashMap 负载 0.75 等 |
| G-BENCH | 完成 | `core/benchmarks/nextpas.core.collections/*` 与跨语言对比 |

公共接口语义按 **软冻结** 管理。

## 已进 main 的交付

| 项 | SHA / 状态 |
|----|------------|
| 功能 Swiss 收敛 + 契约 | `1f7cae0de` **Landed** |
| P0 文档/契约卫生 + ROADMAP | `0125831c9` **Landed** |
| P1 facade MakeXxx 烟雾 29/29 | `3ce508865` **Landed** |

## 默认实现事实

- `MakeMap` / `MakeHashMap` / Builder → Swiss
- HashSet / MultiMap / MultiSet / LruCache / LinkedHash* → Swiss
- OA `THashMap` 保留专家/TLS 直构
- 泛型接口：门面 + 对应 `*.intf`（FPC 3.3.1）
- 全部 public `MakeXxx` 在 `test_facade` 有最小烟雾探针

## 明确不做

- 为「接口更小」批量删能力方法
- 按行数机械 `.inc` 拆文件
- open generic 门面 alias / 第二套 interface 身份
- 无 bench 证据的哈希算法替换
- 跨模块顺手重构（除非 contract 阻塞）

## 权威文档

- [`CONTRACT.md`](CONTRACT.md) · [`README.md`](README.md) · [`ROADMAP.md`](ROADMAP.md)
- [`PERF-HASHSET.md`](PERF-HASHSET.md) · [`CONSUMERS.md`](CONSUMERS.md)
- [`OWNERSHIP-AUDIT.md`](OWNERSHIP-AUDIT.md) · [`READY.md`](READY.md)

## 后续

**维护 idle。** 队列与观察点见 [`ROADMAP.md`](ROADMAP.md)（P0/P1 已完成；P2+ 仅有触发时）。

- 消费者/bug 驱动 → P2
- TLS 迁工厂 Swiss → **跨 lane，不排期**

## 验证入口

```sh
git fetch origin main   # 改代码前 behind 须为 0
make focused FOCUS=core/tests/nextpas.core.collections/test_facade
make hygiene
```
