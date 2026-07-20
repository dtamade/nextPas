# blockpool.growable — KEEP 决策（G3）

**日期**: 2026-07-20  
**状态**: **KEEP**（源保留 · 不进门面）  
**关联**: [FACADES-SURFACE.md](FACADES-SURFACE.md) · [PRUNE-P-b-DESIGN-2026-07-19.md](PRUNE-P-b-DESIGN-2026-07-19.md) · [ROADMAP.md](ROADMAP.md) §4d

---

## 1. 结论（唯一权威）

| 项 | 决定 |
|----|------|
| 单元 | `nextpas.core.mem.blockpool.growable` |
| 主要类型 | `TGrowingBlockPool` / `TGrowingBlockPoolConfig` |
| **源文件** | **保留** |
| **门面 re-export** | **禁止**（Tier-3 / Experimental 黑名单） |
| 删除 / 并入 sharded | **禁止**，除非独立设计 + 替代 sharded 依赖 |

---

## 2. 为何 KEEP

1. **生产依赖**: `nextpas.core.mem.blockpool.sharded` `uses` growable（分片池增长后端）。  
2. **测试依赖**: `test_growing_block_pool` / sharded 相关套件触达该单元。  
3. **P-b 已明示保留**: 剪枝 15 个 Tier-3 allocator 时 **故意** 留下 growable。  
4. **非博物馆条目**: 有命名内部 consumer，不是无引用实验代码。

---

## 3. 为何不进门面

- 默认产品路径用 `TBlockPool` / fixed slab / sizeclass；可增长块池是 **实现细节 + 高级变体**。  
- 可发现性：`uses nextpas.core.mem.blockpool.growable` 或经 sharded 间接使用。  
- 与 F3/G2 一致：冷门/变体不挡 `nextpas.core.mem` 入口。

---

## 4. 反模式（勿做）

| 动作 | 原因 |
|------|------|
| 为「减文件数」删 growable | 破坏 sharded |
| 未迁移 sharded 就 inline 进 sharded | 大重构，另开设计 |
| 把门面 uses 加回 growable | 违反 FACADES-SURFACE |
| 与 P-a/P-b 已删单元混谈「复活」 | growable 从未删除 |

---

## 5. 将来若要变

须单独 slice，至少证明：

1. sharded 不再依赖 growable（或同 commit 迁移）。  
2. 测试覆盖不降。  
3. 门面/文档同步。  

在此之前：**KEEP**。
