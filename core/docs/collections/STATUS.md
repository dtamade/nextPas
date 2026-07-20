# nextpas.core.collections — 状态

**更新日期**：2026-07-20
**阶段**：**Landed** — 稳定维护
**分支 / worktree**：`collections` / `.worktrees/collections`（与 `main` 同步后维护）

## 已完成（历史目标树）

| 目标 | 状态 | 摘要 |
|------|------|------|
| G-ARCH | 完成 | Stack/Set 身份收敛；MakeXxx 工厂；IList Unchecked 清理；接口形状审查 |
| G-CORRECT | 完成 | VecDeque/RBTree 等关键 bug 修复 |
| G-TESTED | 完成 | 全容器 focused suites；heaptrc 零泄漏路径；错误路径 |
| G-PERF | 完成 | introsort、三路分区、VecDeque Rotate、HashMap 负载 0.75 等 |
| G-BENCH | 完成 | `core/benchmarks/nextpas.core.collections/*` 与跨语言对比 |

公共接口语义按 **软冻结** 管理。

## 本轮交付（已进 main）

| 阶段 | 内容 | 状态 |
|------|------|------|
| Wave 0–1 | 契约真相；MakeMap/MakeSet | **Landed** |
| Wave 2 | 机械 `.inc` 拆文件 | **取消** |
| Wave 3 / D–E | 默认哈希族 Swiss 收敛 | **Landed** |
| Phase A–C | Swiss 契约补洞；bench；职责审计 | **Landed** |
| Landing | `1f7cae0de` path-limited ff → `origin/main` | **Landed** |

**Landing commit**：`1f7cae0de` — `feat(collections): Swiss default map family and contract truth`

## 默认实现事实

- `MakeMap` / `MakeHashMap` / Builder → Swiss
- HashSet / MultiMap / MultiSet / LruCache / LinkedHash* → Swiss
- OA `THashMap` 保留专家/TLS 直构
- 泛型接口：门面 + 对应 `*.intf`（FPC 3.3.1）

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

维护队列与优先级见 **[`ROADMAP.md`](ROADMAP.md)**（P0 文档卫生 → P1 facade 探针 → 有触发才 P2/P3）。

- 消费者/bug 驱动修复（P2）
- TLS 是否改用工厂 Swiss：**跨 lane，本模块不排期**

## 验证入口

```sh
make focused FOCUS=core/tests/nextpas.core.collections/test_facade
make hygiene
```
