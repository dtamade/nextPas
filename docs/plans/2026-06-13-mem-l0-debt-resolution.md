# 2026-06-13 mem L0 debt resolution

> **For Claude:** 本计划经 Codex 严格架构审查后定稿。所有代码修改须通过 Codex 执行。

**Goal:** Resolve the remaining mem L0 dependency debt without normalizing the wrong owner boundary.

**Architecture:** mem L0 debt 不是纯实现问题，而是 owner-boundary 决策问题。必须先在架构层面划定"什么该留在 L0 mem、什么应迁出"，再分阶段收债。当前 `platform.mmap` 已有 ready seam，而 `secure` 缺 platform 对应层，因此 mapped family 可先做、secure 必须后做。

**Tech Stack:** Pascal (FPC 3.3.1), nextpas.core L0/L1, nextpas.core.platform

---

## Architecture Decision

This plan makes the following architectural calls up front:

1. `nextpas.core.mem.intf.IAllocator` and narrow allocator behavior remain the mem core.
2. `platform.mmap` is the correct owner for raw mapping and shared-memory host semantics.
3. `allocator.memory_map_allocator` and anonymous mapping-backed allocation may remain in `mem`.
4. File-backed/shared-memory convenience APIs and mapped IPC/data-structure surfaces are not default L0 allocator-core behavior.
5. `mapped_ring_buffer*` should not be treated as long-term L0 mem surface. Preferred destination is a higher owner, most likely an L1 mapped-io family.
6. `mapped_slab_pool` must be treated as two concerns:
   - anonymous mapped allocator backend that may stay in `mem`
   - file/shared/persistent manager surface that should not be normalized as L0 core
7. `mem.secure` cannot be cleaned by helper replacement alone; it needs a minimal platform-owned secure-memory seam first.

## Current Live Debt

The live gate is `core/tests/nextpas.core.mem/test_l0_dependency_boundaries/check_mem_l0_dependencies.sh`.

Current allowlisted debt entries: **0** (all resolved ✅)

Original 8 debt entries — all closed:

| # | Debt | Phase | Commit |
|---|------|-------|--------|
| 6 | `pool.fixed.pas -> nextpas.core.text.conv` | Phase 1 | `21d4de0b9` |
| 1 | `mapped_ring_buffer.pas -> nextpas.core.fs.util` | Phase 2 | `210a308c5` |
| 4 | `mapped_slab_pool.pas -> nextpas.core.fs.util` | Phase 2 | `b5968ac1a` |
| 5 | `mapped_slab_pool.pas -> nextpas.core.text.conv` | Phase 2 | `b5968ac1a` |
| 2 | `mapped_ring_buffer.sharded.pas -> SyncObjs` | Phase 2 | `9482dd0e8` |
| 3 | `mapped_ring_buffer.sharded.pas -> nextpas.core.text.conv` | Phase 2 | `9482dd0e8` |
| 7 | `secure.pas -> BaseUnix` | Phase 3 | `928efb418` |
| 8 | `secure.pas -> Windows` | Phase 3 | `928efb418` |

---

## Phase 1: Truth Lock And Low-Risk In-Mem Debt

### Purpose

Remove only the debt items that are clearly local hygiene and clearly belong inside `mem`.

### In Scope

- `core/src/nextpas.core.mem.pool.fixed.pas`
- `core/src/nextpas.core.mem.mapped_ring_buffer.sharded.pas` — only if cleanup stays strictly local
- `core/docs/mem/README.md`
- `core/tests/nextpas.core.mem/test_l0_dependency_boundaries/**`
- minimal focused test additions only where needed to protect a narrow rewrite

### Out Of Scope

- no `IAllocator` contract changes
- no `DefaultAllocator` behavior changes
- no `memory_map` owner reshaping
- no `secure` seam work
- no mapped-family relocation

### Target Debt Reduction

Required:
- `pool.fixed.pas -> nextpas.core.text.conv`

Optional in same phase only if still narrow:
- `mapped_ring_buffer.sharded.pas -> SyncObjs`
- `mapped_ring_buffer.sharded.pas -> nextpas.core.text.conv`

### Rationale

- `pool.fixed` is the smallest, clearest in-mem debt item.
- `mapped_ring_buffer.sharded` helper cleanup is acceptable only if done as a tiny local hygiene slice, not as a statement that `mapped_ring_buffer` stays in L0 forever.

### Required Verification

Always:
- `make -C core/tests/nextpas.core.mem/test_l0_dependency_boundaries test`
- `git diff --check`
- `make hygiene`

For `pool.fixed`:
- `make -C core/tests/nextpas.core.mem/test_pool clean test`
- `make -C core/tests/nextpas.core.mem/test_oom clean test`

For `mapped_ring_buffer.sharded` if touched:
- add the smallest compile/behavior gate needed before cleanup
- do not build a large mem-only ring-buffer test suite before Phase 2 ownership work is approved

### Exit Criteria

- debt count reduced by at least 1
- no new higher-layer dependency
- README debt count and live gate truth match
- no cross-module changes

---

## Phase 2: Mapped Family Owner-Boundary Execution

### Purpose

Resolve the mapped-family debt by owner truth, not by cosmetic helper cleanup.

### In Scope

- `core/src/nextpas.core.mem.memory_map.pas`
- `core/src/nextpas.core.mem.allocator.memory_map_allocator.pas`
- `core/src/nextpas.core.mem.mapped_slab_pool.pas`
- `core/src/nextpas.core.mem.mapped_ring_buffer.pas`
- `core/src/nextpas.core.mem.mapped_ring_buffer.sharded.pas`
- `core/src/nextpas.core.platform.mmap.pas`
- `core/src/nextpas.core.io.mapped.pas`
- minimal doc updates under `core/docs/mem/` and `core/docs/plans/`

### Architecture Rule

Do not spend this phase trying to make `mapped_ring_buffer*` look like honest L0 mem code.

Preferred direction:
- keep anonymous mapping-backed allocation in `mem`
- keep raw host mapping/shared-memory ownership in `platform.mmap`
- move file/shared mapped data-structure surfaces out of L0 mem
- if relocation cannot be completed narrowly, stop at `Needs Review`

### Required Split

`mapped_slab_pool` must be reviewed as two surfaces:

1. anonymous mapped allocator path:
   may stay in `mem` if it remains allocator-honest

2. file/shared manager path:
   should move behind higher ownership or stop at review

### Required Consumer Awareness

If `memory_map` public surface moves or shrinks, replay the existing consumer:
- `core/src/nextpas.core.io.mapped.pas`

### Target Debt Reduction

Primary:
- `mapped_ring_buffer.pas -> nextpas.core.fs.util`
- `mapped_slab_pool.pas -> nextpas.core.fs.util`
- `mapped_slab_pool.pas -> nextpas.core.text.conv`

Conditional:
- `mapped_ring_buffer*` debt only if the owner decision for that surface is explicitly approved

### Required Verification

Always:
- `make -C core/tests/nextpas.core.mem/test_l0_dependency_boundaries test`
- `git diff --check`
- `make hygiene`

Mapped allocator/path:
- `make -C core/tests/nextpas.core.mem/test_memory_map_compile_gate clean test`
- `make -C core/tests/nextpas.core.mem/test_memory_map_allocator clean test`

Mapped slab:
- `make -C core/tests/nextpas.core.mem/test_mapped_slab_pool clean test`

Mapped consumer replay:
- `make -C core/tests/nextpas.core.io/test_io_flow clean test`

If `IAllocator`-visible behavior changes at all:
- `make -C core/tests/nextpas.core.collections/test_vec clean test`
- `make -C core/tests/nextpas.core.json/test_json_facade clean test`
- `make -C core/tests/nextpas.core.toml/test_toml_facade clean test`

### Exit Criteria

- mapped-family debt is reduced only along an explicit owner-boundary path
- `io.mapped` still works
- no false claim that file/shared mapped IPC is "now honest L0 mem"
- if migration scope expands, report `Needs Review` instead of forcing completion

---

## Phase 3: Secure-Memory Seam

### Purpose

Resolve `mem.secure` only after introducing the minimal platform-owned primitive it needs.

### In Scope

- `core/src/nextpas.core.mem.secure.pas`
- one new minimal platform-owned unit or seam
- minimal consumer-facing updates only if required
- focused tests for secure-zero behavior and consumer replay

### Architecture Rule

Do not add a broad "secure memory framework" to platform.

Allowed shape:
- a tiny primitive such as `platform_secure_zero(...)`
- optional later expansion only if a real consumer requires page-lock/protection APIs

Disallowed shape:
- a wide platform security abstraction batch
- mixing page-protection, guarded heaps, and allocator redesign into the same slice

### Why This Is Last

- platform currently has `mmap` ownership ready for mapped work
- platform does not currently have a secure-memory seam
- `mem.secure` has broad TLS/crypto consumers, so the blast radius is larger than Phase 1 and usually larger than the narrow mapped-helper cleanup

### Target Debt Reduction

Required:
- `secure.pas -> BaseUnix`
- `secure.pas -> Windows`

### Required Verification

Always:
- `make -C core/tests/nextpas.core.mem/test_l0_dependency_boundaries test`
- `git diff --check`
- `make hygiene`

Secure behavior:
- create or extract a mem-focused secure-zero gate from the existing secure-zero assertions
- reuse the existing TLS-side secure-zero expectations as consumer proof

Consumer replay:
- run at least one focused TLS/crypto consumer gate that exercises `SecureZero*`

### Exit Criteria

- `mem.secure` no longer directly uses host units
- the replacement seam is minimal and platform-owned
- TLS/crypto consumer behavior still passes
- no oversized platform public-surface expansion

---

## Priority Order Summary

Correct implementation order:

1. **Phase 1**: truth lock + `pool.fixed` narrow cleanup (and optionally `mapped_ring_buffer.sharded` local hygiene)
2. **Phase 2**: mapped-family owner-boundary execution using existing `platform.mmap` ownership
3. **Phase 3**: secure-memory seam as a separate, explicit platform capability slice

**Do not invert steps 2 and 3.** Platform already has `mmap` for mapped work; it does not yet have a secure-memory seam. Trying to do secure first would either expand platform inappropriately or produce a half-clean result.

## What Not To Claim

- do not claim mem is clean because the allowlist shrinks
- do not claim `mapped_ring_buffer` is valid L0 mem just because helper imports are gone
- do not claim `secure` is solved by replacing `Windows/BaseUnix` with another direct host shim
- do not run broad cross-repo sweeps unless the touched surface really crosses public allocator contracts

## Ready / Needs Review Rule

Report `Ready` only when:
- the slice stayed within its approved owner boundary
- focused gates passed
- no hidden cross-module drift was introduced

Report `Needs Review` when:
- `mapped_ring_buffer*` relocation becomes the real work
- `mapped_slab_pool` file/shared modes cannot stay honest inside `mem`
- `secure` requires a nontrivial new platform surface