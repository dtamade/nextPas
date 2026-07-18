# mem Inventory 审计（可删 / 可归档清单）

**日期**: 2026-07-17
**范围**: `core/src/nextpas.core.mem*.pas`（107 单元）
**动作**: **只出清单，不删代码、不改 Makefile、不移测试**
**方法**: 对每个单元统计 `core/src/` 下 **非 mem** 文件是否出现单元名；对照 [FACADES-SURFACE.md](FACADES-SURFACE.md) Tier-3 黑名单与门面 `uses`

**原则**:

- 「可删」= **无产品 consumer** 且已在 Tier-3 黑名单 / 实验位 → 可作 **未来 breaking prune 候选**
- 「可归档」= 文档/历史 phase，不是源码
- **有门面 re-export 但无直接 prod uses** ≠ 可删（仍是产品表面）
- 删除必须：总控批准 + 同步测试目录 + FACADES 更新 + path-limited land

---

## 1. 总览

| 桶 | 数量 | 含义 |
|----|------|------|
| 有 `core/src` 非 mem consumer | **18** | 保留；产品依赖 |
| 门面 re-export、无直接 prod file uses | **~50** | 保留；经门面可达 |
| Tier-3 黑名单、无 prod consumer | **26** | **首选 prune 候选** |
| 非黑名单、非门面、无 prod | **4** | 次级候选 / 内部实现 |
| Growing 内核 / 内部 | **~9** | 保留（span/central/sizeclass…） |

源文件约 **107**；产品真正「被上层直接 uses」的子集远小于此。这与 STDLIB 计划「能力过度、缺纪律」结论一致，Steady 下 **不扩张** 比 **不删除** 更重要。

---

## 2. 有产品 consumer（禁止当垃圾删）

| 单元族 | 示例 consumer |
|--------|----------------|
| `nextpas.core.mem` 门面 | 大量 L1+ 模块 |
| `mem.intf` / `mem.default` / `mem.allocator(.base)` | collections / xml / json / yaml / http |
| `mem.secure` | tls |
| `mem.utils` | collections / text |
| `mem.arena*` / `allocator.arena` / `allocator.growing` | http.mem / compiler.mem |
| `mem.memory_map` / `mapped_slab_pool` | io.mapped.* |
| `mem.mutex` | io.mapped.ring_buffer.sharded |

---

## 3. 可删候选 A — Tier-3 黑名单、无 prod consumer（首选）

下列单元在 FACADES Tier-3 黑名单中，且 **本机扫描无任何 `core/src` 非 mem 引用**（`refs` 仅测试/自身或 0）。
**均有对应 `core/tests/nextpas.core.mem/test_*` 目录** — 删源必须同删/迁测试。

| 单元 | 备注 |
|------|------|
| `allocator.prediction` | 实验预测器 |
| `allocator.numa` | NUMA 路由 |
| `allocator.replay` | 回放 |
| `allocator.huge_page` | 大页 |
| `allocator.watermark` | 水位 |
| `allocator.sliding` | 滑动窗 |
| `allocator.thread_cache` | 与 Growing TLS 重叠叙事 |
| `allocator.mapped_file` | 映射文件分配器实验 |
| `allocator.arena2` | 旧 arena 变体 |
| `allocator.arena_group` | 组 |
| `allocator.bitmap` | 位图分配器 |
| `allocator.bump` | bump（Arena 已覆盖场景） |
| `allocator.cascade` | 级联 |
| `allocator.coalesce` | 合并 |
| `allocator.compact` | 压缩 |
| `allocator.cow` | COW |
| `allocator.dual` | 双堆实验 |
| `allocator.freelist` | 独立 freelist |
| `allocator.group` | 组 |
| `allocator.page` | 页分配器 |
| `allocator.pool2` | 池变体 |
| `allocator.prefix` | 前缀 |
| `allocator.size_class` | 与 Growing sizeclass **不同单元**；易混淆 |
| `allocator.slab` | 与 `pool.slab` 叙事重叠 |
| `allocator.stack` | 栈式分配器实验 |
| `blockpool.growable` | 黑名单；内部偶发 refs |

**建议姿态**: 标 `experimental/` 子树或整批删除二选一；**不要**单个悄悄删。优先批 1：与 Growing/Arena **功能完全重叠** 的 bump/dual/freelist/thread_cache/size_class/slab(allocator)。

---

## 4. 可删候选 B — 非黑名单、无门面、无 prod（次级）

| 单元 | 建议 |
|------|------|
| `allocator.mimalloc.loader` | 被 `allocator.mimalloc` 使用 → **不可单独删**；随 mimalloc 保留 |
| `pool.fixed.growable` | 无 prod；可进黑名单或 prune 批 |
| `pool.fixed_slab.nginx` | 实现细节单元；随 fixed_slab 保留除非拆实现 |
| `pool.object_pool` | 无 prod consumer；泛型池 — **有生态价值则保留并考虑门面**；否则 prune 候选 |

---

## 5. 内部实现 — 勿删

| 单元 | 角色 |
|------|------|
| `sizeclass` / `span` / `cache.thread` / `central` / `shuffle` | Growing 内核 |
| `default` / `debug_wrap` / `growing` / `growing_ia` | 双轨默认路径 |
| `pressure` / `registry` / `stack_guard` / `watermark`（mem 根） | 零/低 refs：先 **审计是否死代码** 再决定；**本清单不主张立即删** |

`mem.pressure` / `mem.registry` / `mem.watermark`（非 allocator.watermark）refs≈0：标为 **需二次打开文件确认**，可能是未接线实验。

---

## 6. 门面仍胖 — 非「可删」但可「收紧」

门面 `uses` 仍含大量 Tier-1/2 包装器（tracking/sentinel/guard/logging/…）与 pool 族。
FACADES 规则：**本批不大规模删除既有 Tier-2 re-export**。

| 动作 | 何时 |
|------|------|
| 收紧门面 uses | 独立 breaking slice + 更新 FACADES + guardrails |
| 把冷门包装器降为子单元-only | 同上；先有命名 consumer 反馈 |

**不要**把 §3 Tier-3 删除与门面收紧混在一个 commit。

---

## 7. 文档 / 档案（可归档，非源码）

已在 [archive/](archive/) 的时代 A ROADMAP\* 保持勿当待办。
根 `core/docs/mem/` 仍有历史履历（可继续留，或以后再挪 archive）：

| 文档 | 建议 |
|------|------|
| `USABILITY-AUDIT.md` 等 SUPERSEDED | 已标明；可选移 archive |
| `mem-findings*.md` / `P03-*.md` / `TEST_COVERAGE_*` | 历史 findings；**勿当活 backlog** |
| `API.md` | 长百科；冲突以 README/API-GUIDE 为准（已写） |

---

## 8. 若总控批准 prune：建议批次

| 批 | 内容 | 风险 |
|----|------|------|
| **P-a** | §3 中与 Growing/Arena 重叠最重的 8–10 个 allocator.\* | 中：测试目录多，需 hygiene |
| **P-b** | 剩余 §3 Tier-3 | 中 |
| **P-c** | §4 `pool.object_pool` / `fixed.growable`（确认无计划后） | 低–中 |
| **P-d** | 门面 Tier-2 收紧 | **高**（外部 `uses nextpas.core.mem` 符号） |

每批：`make hygiene` + `make lane-focused LANE=mem` + 相关 test 目录删除后 full mem tests 抽样。

---

## 9. 结论

- **产品路径不依赖** 绝大多数 Tier-3 实验分配器。
- **Steady 默认不删**；本文件是批准后的执行菜单。
- 当前更大收益是 **禁止新增长**，不是急删 26 个文件。

相关：[FACADES-SURFACE.md](FACADES-SURFACE.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [ROADMAP.md](ROADMAP.md) D9
