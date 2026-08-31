# nextpas.core.collections — 状态

**更新日期**：2026-08-31
**阶段**：**Landed / 维护 idle**（可用性 Waves 0–6 已进 main）
**分支 / worktree**：`landing/perfection-16` / `.worktrees/landing-perfection-16`
**Landing SHA**：`9023f0765`

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

## 可用性 Waves（本 lane 本轮）

| Wave | 内容 | 状态 |
|------|------|------|
| 0 | rebase + facade 基线 | 完成 |
| 1 | 测试去掉 SysUtils/Classes；`test_source_contracts` | 完成 |
| 2 | README 决策树 / 5 分钟路径；MakeHashMap=Swiss 叙事 | 完成 |
| 3 | `TMemAllocator` 统一；`MakeTreeSet(compare)`；HashMix→base；FIterIdx 删除 | 完成 |
| 4 | `ERRORS.md` + 异常文案/类型对齐 | 完成 |
| 5 | `benchmarks/.../Makefile` | 完成 |
| 6 | 全 suite + hygiene + landing | **Landed** `9023f0765` |

## 明确不做

- 为「接口更小」批量删能力方法
- 按行数机械 `.inc` 拆文件
- open generic 门面 alias / 第二套 interface 身份
- 无 bench 证据的哈希算法替换
- TLS 改工厂（跨 lane）
- 跨模块顺手重构（除非 contract 阻塞）

## 权威文档

- [`CONTRACT.md`](CONTRACT.md) · [`README.md`](README.md) · [`ROADMAP.md`](ROADMAP.md)
- [`PERF-HASHSET.md`](PERF-HASHSET.md) · [`CONSUMERS.md`](CONSUMERS.md)
- [`OWNERSHIP-AUDIT.md`](OWNERSHIP-AUDIT.md) · [`READY.md`](READY.md)

## 后续

**维护 idle。** 队列与观察点见 [`ROADMAP.md`](ROADMAP.md)。

已追加可用性切片（评估后续）：

- 空容器 → `EEmptyCollection` + examples（`3c4784695`）
- `CORE-API.md` + Ensure 对照 + 有序 map 选型表（`fb1ead4d8`）
- `capacity_ensure` example + PERF-HASHSET 同机重跑（本提交）

仍仅触发时做：

- 消费者/bug 驱动 hardening
- TLS 迁工厂 Swiss → **跨 lane，不排期**

## 验证入口

```sh
git fetch origin main   # 改代码前 behind 须为 0
make focused FOCUS=core/tests/nextpas.core.collections/test_facade
make hygiene
```
