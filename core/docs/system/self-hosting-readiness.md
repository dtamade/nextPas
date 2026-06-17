# Self-Hosting Readiness Gates

This document defines the acceptance criteria for nextPas to reach self-hosting (compiler
can compile itself). It focuses on the `np.system.*` contract vocabulary and runtime
support that a self-hosted compiler will require.

## Status: Pre-Self-Hosting

The compiler currently uses FPC as the stage0 host compiler. All `np.system.*` contracts
are documented but runtime execution is deferred for most of them. This document records:

1. What must work before self-hosting can succeed
2. How to detect RTTI divergence between FPC host RTTI and nextPas RTTI
3. The minimum unit lifecycle implementation path
4. Owner assignments for each gate

## Gate 1: RTTI Shape Consistency

### Problem

`TypeInfo(T)` and `GetTypeKind(K)` are currently compile-truth imports from the host FPC
RTTI. When nextPas compiles itself, the RTTI metadata will be emitted by nextPas's own
compiler, which may produce a different layout than FPC's `TypInfo` unit.

Consumers that depend on `TTypeKind` values for dispatch include:
- `nextpas.core.collections.element_manager.pas` — uses `GetTypeKind(T)` for managed element dispatch
- `nextpas.core.collections.hashmap.swiss.pas` — uses `GetTypeKind(K)` for key specialization

If the nextPas RTTI `TTypeKind` enum values diverge from FPC's, these consumers will
dispatch incorrectly without any compile-time or runtime diagnostic.

### Detection Strategy

**Regression test suite**: Before self-hosting, add a standalone test that:

1. Creates a small Pascal program with every `TTypeKind` value
2. Compiles it with FPC and records the expected type kind mappings
3. Compiles the same program with nextPas and compares the emitted kind values
4. Fails if any `TTypeKind` value diverges

```pascal
// Proposed: test_rtti_kind_suite.pas
procedure AssertTTypeKindValue(Expected: TTypeKind; const AName: string);
begin
  if TypeInfo(Expected) <> TypeInfo(...) then
    Halt(1);
end;
```

**Collections consumer guard**: In each collections unit that uses `GetTypeKind(T)`,
add a static assertion that TTypeKind values match expectations:

```pascal
// Current collections code (example)
case GetTypeKind(K) of
  tkInteger: ...
  tkAString: ...
```

→ Must be guarded by a regression test that verifies each `tk*` value.

### Owner
- **Test design**: `nextpas.core.system` (this document defines the strategy)
- **Compiler RTTI emitter**: `compiler/backend` (must produce FPC-compatible `TTypeKind` values)
- **Collections guard tests**: `nextpas.core.collections`
- **Integration verification**: `tests/compiler` (pass/fail fixtures)

### Acceptance Criteria

- [ ] A `TTypeKind` value stability test exists and passes under both FPC and nextPas
- [ ] Collections `GetTypeKind` dispatch does not silently diverge

---

## Gate 2: Unit Lifecycle Execution

### Problem

Unit initialization (`np.system.unit_init`) and finalization (`np.system.unit_fini`)
contracts are documented but have no semantic seed in the compiler. The compiler's
`UnitGraph` resolves unit dependencies but does not generate initialization/finalization
call sequences.

Currently, any program that uses multiple units will execute unit initialization
through the host FPC runtime (stage0), not through a nextPas-owned lifecycle driver.

### Minimum Implementation Path

The minimum unit lifecycle implementation requires:

#### Step 1: Compiler UnitGraph Consumption
- **What**: The compiler already has `TUnitGraph` with resolved dependency edges.
  It must traverse the graph in topological order and emit HIR nodes for each unit's
  initialization/finalization body.
- **File**: `compiler/sema/np_semantic_analyzer.pas` or `compiler/ir/np_hir_builder.pas`
- **New HIR nodes**: `unit-init-runtime`, `unit-fini-runtime` (similar to existing
  `halt-call-runtime`, `raise-runtime` nodes)
- **Output**: HIR intrinsic calls with unit name as operand

#### Step 2: HIR Contract Seeding
- **What**: `SeedRuntimeContracts` must be extended to seed
  `np.system.unit_init` / `np.system.unit_fini` for each resolved unit
  in the dependency graph.
- **File**: `compiler/sema/np_semantic_analyzer.pas`
- **Current**: Only seeds `process_init` / `process_fini` at the program root level.
- **Extension**: After `SeedRuntimeContracts`, iterate `FUnitGraph` and seed
  init/fini for each non-root unit.

#### Step 3: LLVM Emission
- **What**: Add LLVM helper definitions for unit init/fini calls, or use inline
  function calls to unit-scoped initialization symbols.
- **File**: `compiler/ir/np_hir_llvm_emitter.pas`
- **New helpers**: `@np_unit_init`, `@np_unit_fini` (or direct call to unit-level
  symbols emitted by the backend)

#### Step 4: Runtime Driver
- **What**: Provide a `_start` implementation that calls unit initializations
  before `main` and unit finalizations after.
- **File**: `rtl/core/system/System.pas` or a new entry point file
- **Current**: `_start` is emitted by the LLVM emitter for halt-based programs.
- **Extension**: `_start` calls `@np_unit_init` for all units in dependency order,
  then calls `main`, then calls `@np_unit_fini` in reverse order.

### Owner
- **Compiler**: `compiler/sema` (UnitGraph consumption + HIR seeding)
- **Compiler**: `compiler/ir` (LLVM helper emission for unit init/fini)
- **Runtime**: `rtl/core/system` (runtime driver entry point)
- **Contracts**: `nextpas.core.system` (contract vocabulary owner)

### Acceptance Criteria

- [ ] `UnitGraph` consumption generates HIR nodes for each resolved unit
- [ ] `np.system.unit_init` / `np.system.unit_fini` are seeded for multi-unit programs
- [ ] LLVM emitter generates correct init/fini call sequences
- [ ] A multi-unit program (e.g., `hello_with_units.pas`) runs with correct init ordering

---

## Gate 3: Process Lifecycle Runtime Execution

### Problem

`np.system.process_init` and `np.system.process_fini` have semantic seed proof but
no runtime execution. The compiler emits these as HIR nodes, but no code is generated
to call environment setup/teardown routines.

### Current State

- Semantic seeds exist: `SeedRuntimeContracts` in `np_semantic_analyzer.pas`
- Integration smoke via `verify_local.sh` proves compiler → LLVM → executable for
  halt-based programs
- No runtime execution of `process_init` / `process_fini` beyond the inline syscall

### Minimum Path

The `_start` entry point must be extended to:
1. Call `np.system.process_init` before entering `main`
2. Call `np.system.process_fini` after `main` exits

### Owner
- **Runtime**: `rtl/core/system/System.pas` or the `_start` LLVM helper

### Acceptance Criteria

- [ ] Programs compiled with nextPas execute `process_init` at startup
- [ ] Programs compiled with nextPas execute `process_fini` at shutdown
- [ ] Exit code is preserved through the shutdown sequence

---

## Gate 4: Heap Manager Integration

### Problem

Allocation (`@np_alloc`) and deallocation (`@np_free`) are currently backend-private
LLVM helpers embedded in the emitted IR. They do not route through
`np.system.heap_alloc` / `np.system.heap_free` contract names and do not delegate to
`nextpas.core.mem`.

### Current State

- `@np_alloc` and `@np_free` are defined in `np_hir_llvm_emitter.pas` as internal helpers
- They use `mmap`/`munmap` directly (Linux x86_64)
- No integration with `nextpas.core.mem` allocator interface
- Contract coverage table documents this as "Contract name in docs, impl helpers in backend"

### Minimum Path

Before self-hosting, the allocation helpers must either:
1. Be replaced with calls to `nextpas.core.mem` allocator routines
2. Or be documented as a temporary implementation that will be replaced

### Owner
- **Runtime memory**: `nextpas.core.mem`
- **LLVM emitter**: `compiler/ir`
- **Contracts**: `nextpas.core.system`

### Acceptance Criteria

- [ ] `@np_alloc` / `@np_free` are either delegating to `nextpas.core.mem` or
  explicitly documented as temporary for self-hosting bootstrap

---

## Gate 5: Exception Unwind

### Problem

Exception helpers (`@np_try_push`, `@np_try_pop`, `@np_raise`, etc.) are backend-private
LLVM helpers with no runtime exception object model. They use `setjmp`/`longjmp` semantics
via inline assembly.

### Current State

- Contract names exist (`np.system.exception_*`) in `lifecycle-contracts.md`
- Source-contract checks verify helper existence
- No runtime exception object layout is defined
- No unwinder integration exists

### Minimum Path

For self-hosting bootstrap, the current `setjmp`/`longjmp` approach is sufficient as long
as exception semantics work correctly for try/except/finally blocks. A full unwinder
integration can be deferred.

### Owner
- **Exception lowering**: `compiler/ir` / `compiler/backend`
- **Contracts**: `nextpas.core.system`

### Acceptance Criteria

- [ ] `try/except/finally` blocks work in compiler source code
- [ ] Exception object creation and access work in compiler source code

---

## Gate Summary

| Gate | Priority | Owner | Effort | Current Status |
|------|----------|-------|--------|----------------|
| 0: system.classes Facade | **Blocker** (global) | system | Medium | **New — unblocks TLS/HTTP/fs/io** |
| 1: RTTI Shape | Critical | compiler + collections | Medium | Pre-work (test design) |
| 2: Unit Lifecycle | Critical | compiler + rtl | High | Deferred (no seed) |
| 3: Process Lifecycle | Important | rtl | Medium | Semantic seed only |
| 4: Heap Manager | Important | mem + compiler | Medium | Backend-private |
| 5: Exception Unwind | Normal | compiler | Low | Backend-private, works |

### Gate 0: Why It's the Cross-Line Compatibility Bottleneck

`nextpas.core.system.classes` provides the `TStream` inheritance chain
(`TStream`, `THandleStream`, `TMemoryStream`, `TStringStream`,
`TSeekOrigin`). The facade **already exists** as a thin re-export of FPC
`Classes` types, following the same pattern as `system.typinfo` and
`system.sysutils`.

The stream-core surface is live. What's missing is the file-text-compat surface
(`TFileStream`, `fm*` constants, `TStringList`), which blocks 19+ TLS files
and compiler/toolchain paths.

Gate 0 strategy: **Phase 1 — validate existing stream-core facade** with
source-contract gate + unit tests. **Phase 2 — decide on file-text-compat
extension** (expand facade vs wait for pure Pascal io module).

| Blocked module | Blocked type | Current status |
|---------------|-------------|----------------|
| TLS | `TSSLStream` (inherits from `TStream`) | stream-core live ✅, file-compat missing ❌ |
| TLS | `TFileStream`, `TStringList` (19+ files) | waiting for Gate 0b file-compat decision |
| HTTP | `THttpStream`, `TResponseStream` | stream-core live ✅ |
| fs | `TFileStream` | waiting for Gate 0b |
| io | `TBytesStream` | NOT system.classes — owner is `io.memory` |
| compiler/toolchain | `TFileStream`, `TStringList` | bootstrap itself is a file-compat consumer |

See `docs/plans/bootstrap-line-spec.md` Gate 0 for detailed task breakdown.

---

## Monitoring

These gates should be reviewed quarterly. Update `goal-tree.md` and this document as
each gate progresses toward completion. The first gate to close (Gate 5, exception unwind)
is already partially covered by the `test_hir_exception` test suite.

## Gate 2: Unit Lifecycle — 验证结果 (2026-06-18)

**状态: FAIL** (全部 4 项验收标准未满足)

| 验收标准 | 状态 |
|----------|------|
| UnitGraph → HIR nodes for each resolved unit | 未实现 |
| np.system.unit_init/unit_fini seeded for multi-unit programs | 未实现 |
| LLVM emitter generates init/fini call sequences | 未实现 |
| Multi-unit program runs with correct init ordering via nextPas | 未实现 |

**已有基础**:
- Lexer 解析 initialization/finalization 关键字 ✅
- Green tree 解析器解析 init/fini sections ✅
- 契约常量 NPSYSTEM_UNIT_INIT/FINI 已定义 ✅
- 文档契约已完整登记 ✅

**缺口 (按实现顺序)**:
1. SeedRuntimeContracts 扩展: 遍历 FUnitGraph，为每个 unit seed unit_init/unit_fini
2. HIR 层: 新增 unit-init-runtime/unit-fini-runtime 节点类型
3. LLVM emitter: @np_unit_init/@np_unit_fini helper
4. Runtime: _start 驱动器（main 前拓扑序 init，main 后逆序 fini）
5. 端到端测试（非 FPC 依赖的 nextPas 编译器运行时测试）
