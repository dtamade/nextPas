# P-a Tier-3 prune 设计备忘（path-limited）

**日期**: 2026-07-19
**Lane**: `mem`
**动作**: **EXECUTED 2026-07-19（Era E / Go-Rust 规模收敛）** — 10 源 + 16 test 已删
**前置**: [INVENTORY-AUDIT-2026-07-17.md](INVENTORY-AUDIT-2026-07-17.md) · [FACADES-SURFACE.md](FACADES-SURFACE.md) · [PARITY-GO-RUST.md](PARITY-GO-RUST.md)
**审批**: mem owner 全权（对标 Go/Rust stdlib 表面规模）

---

## 1. 一句话

P-a 删除与 **Growing / Arena 产品路径功能重叠最重** 的 10 个 Tier-3 `allocator.*` 实验单元及其专属测试目录。
重扫（2026-07-19）确认：**0 个 `core/src` 非 mem 产品引用**；门面 **无** re-export。

---

## 2. 本批范围（P-a）

| # | 单元 | 重叠叙事 | 对应测试目录（须同删） |
|---|------|----------|------------------------|
| 1 | `nextpas.core.mem.allocator.bump` | Arena / bump 生命周期已由 Local/Chunked/Virtual 覆盖 | `test_bump`, `test_bump_allocator` |
| 2 | `nextpas.core.mem.allocator.dual` | 双堆实验；默认双轨是 DefaultHeap/DefaultAllocator | `test_dual` |
| 3 | `nextpas.core.mem.allocator.freelist` | 独立 freelist；Growing TLS free-list 已是产品路径 | `test_freelist` |
| 4 | `nextpas.core.mem.allocator.thread_cache` | 与 Growing `cache.thread` 重叠叙事 | `test_thread_cache` |
| 5 | `nextpas.core.mem.allocator.size_class` | **易混淆**：≠ Growing 内核 `mem.sizeclass` | `test_size_class`, `test_size_class_allocator` |
| 6 | `nextpas.core.mem.allocator.slab` | 与 `pool.slab` / FixedSlab 产品池重叠 | `test_slab`, `test_slab_allocator` |
| 7 | `nextpas.core.mem.allocator.arena2` | 旧 arena 变体；活跃路径是 arena.local/chunked/virtual | `test_arena2` |
| 8 | `nextpas.core.mem.allocator.arena_group` | 组实验；非产品门面 | `test_arena_group` |
| 9 | `nextpas.core.mem.allocator.page` | 页分配实验；mmap/Growing span 已覆盖场景 | `test_page` |
| 10 | `nextpas.core.mem.allocator.stack` | 栈式分配实验；≠ `stack_pool` | `test_stack`, `test_stack_allocator` |

**合计**: 10 源单元 + **16** 测试目录。

### 2.1 明确不在本批

| 项 | 原因 |
|----|------|
| `mem.sizeclass` / `span` / `cache.thread` / `central` | Growing **内核** — 禁止删 |
| `pool.slab` / `pool.fixed_slab` / `stack_pool` | 产品或门面可达池族 |
| `test_slab_pool` / `test_slab_thread_safety` / `test_sizeclass` / `test_stack_pool` / `test_stack_guard` | 测的是 **保留** 单元，勿误删 |
| 门面 Tier-1/2 re-export 收紧 | 属 P-d，高爆炸半径，独立 slice |
| P-b 剩余 Tier-3（prediction/numa/cow/…） | 第二批；先 P-a 验证流程 |
| `blockpool.growable` | 黑名单；可进 P-b，不混 P-a |

---

## 3. 重扫证据（2026-07-19）

方法：对每个目标单元名，扫描 `core/src/*.pas`：

- **non-mem prod refs** = 文件名不以 `nextpas.core.mem` 开头且含单元全名
- **facade** = `nextpas.core.mem.pas` uses 是否出现
- **bench** = `core/benchmarks` / 根 `bench` 文本引用

| 单元 | non-mem | facade | bench 命中 |
|------|---------|--------|------------|
| 上表 1–10 全部 | **0** | **no** | **0** |
| 其余 FACADES Tier-3 黑名单 25 项 | **0** | **no** | （未逐项 bench；执行前再扫） |

`mem` 源单元总数仍约 **107**（与 inventory 一致）。

---

## 4. 执行清单（未来，需总控批准）

按顺序，**一个 path-limited commit 或极短 commit 链**：

1. **冻结窗口**：确认无其它 lane 正在改 `core/src/nextpas.core.mem.allocator.{bump,dual,...}` 与对应 test。
2. **删源**（10 文件）：
   ```text
   core/src/nextpas.core.mem.allocator.bump.pas
   core/src/nextpas.core.mem.allocator.dual.pas
   core/src/nextpas.core.mem.allocator.freelist.pas
   core/src/nextpas.core.mem.allocator.thread_cache.pas
   core/src/nextpas.core.mem.allocator.size_class.pas
   core/src/nextpas.core.mem.allocator.slab.pas
   core/src/nextpas.core.mem.allocator.arena2.pas
   core/src/nextpas.core.mem.allocator.arena_group.pas
   core/src/nextpas.core.mem.allocator.page.pas
   core/src/nextpas.core.mem.allocator.stack.pas
   ```
3. **删测试目录**（16 个，见 §2 表）。模块级 `Makefile` 用 `wildcard test_*`，一般 **无需** 改列表；若有硬编码名单再改。
4. **文档**：
   - 从 [FACADES-SURFACE.md](FACADES-SURFACE.md) Tier-3 黑名单移除已删名（或标注 REMOVED 日期）
   - [INVENTORY-AUDIT](INVENTORY-AUDIT-2026-07-17.md) 或本文件状态 → **EXECUTED**
   - [ARCHITECTURE.md](ARCHITECTURE.md) 若仍列举这些 allocator，删掉对应行
5. **勿动**：`check_usability_docs.sh` 门面规则（删后仍禁止把已删名加回门面即可）
6. **验证**：
   ```bash
   make hygiene
   make lane-focused LANE=mem
   make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix
   # 抽样：Growing / Arena / pool 产品路径仍绿
   make focused FOCUS=core/tests/nextpas.core.mem/test_growing
   make focused FOCUS=core/tests/nextpas.core.mem/test_arena
   make focused FOCUS=core/tests/nextpas.core.mem/test_fixed_slab
   # 或：make -C core/tests/nextpas.core.mem test-fast
   ```
7. **Landing**：从最新 `main` 建 `landing/mem-prune-pa-YYYYMMDD`，**只** cherry-pick 本批；不 raw merge 整支 `mem`。

---

## 5. 风险

| 风险 | 缓解 |
|------|------|
| 误删 `sizeclass` 内核 / `pool.slab` / `stack_pool` | §2.1 白名单；删前 `git grep` 单元全名 |
| 外部仓库/私有代码 `uses` 子单元 | 公开 API 无兼容承诺（Tier-3）；CHANGELOG 记 breaking experimental |
| 测试 Makefile 硬编码 | 执行前 `rg` 模块 Makefile 与 CI 列表 |
| 与 P-d 门面收紧混 commit | **禁止**；P-a 只动黑名单源+测试 |
| 命名混淆 `size_class` vs `sizeclass` | PR 描述与删除清单用 **全单元名** |

---

## 6. 验收标准（执行批）

- [ ] 10 源 + 16 test 目录从树中消失
- [ ] `rg 'allocator\.(bump|dual|freelist|thread_cache|size_class|slab|arena2|arena_group|page|stack)' core/src` 无残留（除文档/archive）
- [ ] `make hygiene` + lane-focused + contract_matrix **PASS**
- [ ] Growing / Arena / FixedSlab 抽样 **PASS**
- [ ] FACADES / ARCHITECTURE 同步
- [ ] Ready 报告：path-limited 文件清单 + 明确「未动门面 Tier-2」

---

## 7. 本会话结论

| 项 | 状态 |
|----|------|
| P-a 菜单可执行性 | **就绪**（0 prod refs） |
| 本会话是否删除 | **是（E2 EXECUTED）** |
| 下一步 | P-b 按需；禁止复活 P-a 单元 |

相关：D9 inventory · ROADMAP 明确不做「无 consumer 的 Phase 29+」· Steady 默认不删、批准后 path-limited 执行。
