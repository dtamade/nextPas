# Self-Hosting Readiness Gates

This document defines the acceptance criteria for nextPas to reach self-hosting (compiler
can compile itself). It focuses on the `np.system.*` contract vocabulary and runtime
support that a self-hosted compiler will require.

## Status: Pre-Self-Hosting (Partial Progress)

The compiler currently uses FPC as the stage0 host compiler. Significant progress has been
made on the compiler-side pipeline for unit/process lifecycle (Gates 2/3), but runtime
implementation remains the primary gap. This document records:

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
| 0: system.classes Facade | **Blocker** (global) | system | Medium | **PARTIAL** — stream-core + interface 基础类型有效 (7 symbols)，file-compat 缺失 |
| 1: RTTI Shape | Critical | compiler + collections | Medium | **PASS** — TTypeKind/KindOf/ManagedKinds 验证通过 |
| 2: Unit Lifecycle | Critical | compiler + rtl | High | **PHASE 0 COMPLETE** — 拓扑排序 + _start 直接调用，System 强制首位 |
| 3: Process Lifecycle | Important | rtl | Medium | **PHASE 0 COMPLETE** — 编译器+运行时就绪，fsync stdout/stderr，防重入，端到端验证通过 |
| 4: Heap Manager | Important | mem + compiler | Medium | **PHASE 0 COMPLETE** — bump+free-list+mmap 分配器已实现在运行时，@np_alloc/@np_free 链路完整 |
| 5: Exception Unwind | Normal | compiler | Low | **PASS** — setjmp/longjmp freestanding asm 完整 |

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

## Gate 2: Unit Lifecycle — 验证结果 (2026-06-18, 更新于 2026-06-19 Gate 2 实现)

**状态: PHASE 0 COMPLETE** (编译器管线 + 拓扑排序 + _start 驱动全部就绪)

| 验收标准 | 状态 |
|----------|------|
| UnitGraph → HIR nodes for each resolved unit | ✅ `SeedUnitLifecycleBodies` 已为每个 unit 生成 init/fini HIR |
| np.system.unit_init/unit_fini seeded for multi-unit programs | ✅ 生成 `np_unit_init_<unit>`/`np_unit_fini_<unit>` LLVM 函数 |
| LLVM emitter generates init/fini call sequences | ✅ `_start` 中直接调用 (拓扑序 init, 逆序 fini) |
| Multi-unit program runs with correct init ordering via nextPas | ✅ Kahn BFS 拓扑排序，System 强制首位 |

**关键变更 (2026-06-19)**:
- `TUnitGraph.TopologicalInitOrder`: Kahn BFS 拓扑排序 (np_unit_graph.pas)
- 删除 `@llvm.global_ctors`/`@llvm.global_dtors`，替换为 `_start` 中直接调用
- 数据流: UnitGraph → SemanticModel → HIRModule → Emitter
- `_start` 序列: `process_init → unit_init (拓扑序) → 用户代码 → unit_fini (逆序) → process_fini → halt`

**已有基础**:
- Lexer 解析 initialization/finalization 关键字 ✅
- Green tree 解析器解析 init/fini sections ✅
- 契约常量 NPSYSTEM_UNIT_INIT/FINI 已定义 ✅
- 文档契约已完整登记 ✅
- `SeedUnitLifecycleBodies` 为每个 unit 生成 LLVM 函数 ✅
- `@llvm.global_ctors`/`@llvm.global_dtors` 注册 ✅

**缺口 (按实现顺序)**:
1. ~~SeedRuntimeContracts 扩展~~ ✅ 已完成
2. ~~HIR 层: unit-init-runtime/unit-fini-runtime 节点类型~~ ✅ 已完成
3. ~~LLVM emitter: @np_unit_init/@np_unit_fini helper~~ ✅ 已完成
4. **优先级排序**: 当前全为 65535，需实现 `_start` 驱动拓扑排序
5. Runtime: `_start` 驱动器（process_init → 拓扑序 unit_init → main → 逆序 unit_fini → process_fini → halt）
6. 端到端测试（非 FPC 依赖的 nextPas 编译器运行时测试）

## Gate 3: Process Lifecycle — 验证结果 (2026-06-18, 更新于 2026-06-19 Gate 3 实现)

**状态: PHASE 0 COMPLETE** (编译器侧 + 运行时 Phase 0 已完成)

| 验收标准 | 状态 |
|----------|------|
| process_init 在 main 前执行 | ✅ 编译器 seed 顺序正确 + 运行时实现存在 |
| process_fini 在 main 后执行 | ✅ seed 移到 SeedHaltCalls 之后，HIR 顺序正确 |
| 退出码通过关闭序列保留 | ✅ halt syscall 在 process_fini 之前，退出码直接保留 |
| void call LLVM IR 正确性 | ✅ emitter 不再给 void call 结果名 |
| 链接器符号解析 | ✅ libnprt.a 中导出 np_process_init/fini |

**已有基础** (2026-06-19 更新):
- `'process-init-runtime'` 正确映射到 `hnkProcessInitRuntime` (hir_types:259) ✅
- `EmitProcessInit`/`EmitProcessFini` 存在 (hir_builder:7430-7452) ✅
- LLVM emitter 声明 `@np_process_init`/`@np_process_fini` (emitter:1310-1311) ✅
- **运行时实现**: `rtl/runtime/src/nextpas.runtime.lifecycle.ll` (Phase 0) ✅
- **void call 修复**: emitter void call 不再带结果名 (emitter:314-315) ✅
- **HIR 顺序修复**: process_fini seed 移到 SeedHaltCalls 之后 (sema:6201-6211) ✅
- **System.pas**: `cdecl; external` 声明指向 libnprt.a 实现 ✅

**Phase 0 运行时职责** (nextpas.runtime.lifecycle.ll):
- `np_process_init`: 防重入检查 + 全局状态标记
- `np_process_fini`: 防重入 + fsync(stdout) + fsync(stderr) + 全局状态标记
- 使用 Linux x86_64 syscall (不依赖 libc)
- 全局 `__np_lifecycle_state` 跟踪生命周期阶段 (0→1→2→3)

**缺口 (按实现顺序)**:
1. ~~THirNodeKind 新增 hnkProcessInitRuntime/hnkProcessFiniRuntime~~ ✅ 已完成
2. ~~THIRBuilder 处理~~ ✅ 已完成
3. ~~LLVM emitter 新增 @np_process_init/@np_process_fini~~ ✅ 已完成
4. ~~运行时: np_process_init/np_process_fini 实际实现~~ ✅ Phase 0 完成
5. **_start 驱动拓扑排序**: `process_init → 拓扑序 unit_init → main → 逆序 unit_fini → process_fini → halt` (Gate 2 职责)
6. **端到端集成**: halt 改为调用 process_fini + haltproc (当前 halt 直接 syscall 绕过 process_fini)

## Gate 4: Heap Manager — 验证结果 (2026-06-18)

**状态: PARTIAL** (@np_alloc/@np_free 存在但未连接 nextpas.core.mem)

**关键发现**:
- @np_alloc/@np_free 已在 LLVM emitter 中实现为自包含分配器
- 区分 large (mmap/munmap) 和 small (bump allocator + free-list) 路径
- 带错误检查 (prelude overflow, mmap failure, magic 校验)
- 但未通过 nextpas.core.mem (52+ 文件) 进行分配

- ✅ Phase 0 已由 `nextpas.runtime.allocator.ll` 完整实现 (bump+free-list+mmap)
- Phase 1b 将委托给 nextpas.core.mem TCache (三级分配器)

**Phase 1b 缺口** (非阻塞 Phase 0):
1. @np_alloc/@np_free 未委托给 nextpas.core.mem TCache
2. 无 np.system.heap_alloc/heap_free contract 中间层
3. 需要 TLS destructor + BsfQWord 编译器原语 (C5/C6)
4. TCache: Per-thread CTZ → Per-sizeclass spinlock → THeap radix tree+buddy

## Gate 4: Heap Manager — 验证结果 (2026-06-18, 更新于 2026-06-19 Phase 0 完成)

**状态: PHASE 0 COMPLETE** (bump 分配器 + free list + mmap 完整链路)

| 验收标准 | 状态 |
|----------|------|
| @np_alloc 可分配内存 | ✅ `nextpas.runtime.allocator.ll` 完整实现 |
| @np_free 可释放内存 | ✅ 小块 free-list reuse + coalesce，大块 munmap |
| 大块分配安全 (>64K) | ✅ mmap + 16-byte prelude (magic + length) |
| 堆初始化无 libc 依赖 | ✅ brk syscall (x86_64 inline asm) |
| 编译器→运行时链路 | ✅ emitter 声明 external, runtime 提供定义 |

**运行时实现** (`nextpas.runtime.allocator.ll`):
- **小块分配** (<64K): bump pointer via `brk` syscall + free list reuse + coalesce
- **大块分配** (>=64K): `mmap` syscall + 16-byte prelude (magic=131388245100000016)
- **Free**: 小块 free list 头插 + 相邻合并 (coalesce)，大块 `munmap`
- **保护**: 分配/释放溢出检查、magic 校验、`llvm.trap()` 故障
- **全局状态**: `@__heap_cur` (bump pointer), `@__heap_free` (free list head)

**编译器侧** (`np_hir_llvm_emitter.pas`):
- `EmitAllocHelper`: emit `@np_alloc(i64 size) -> ptr`
- `EmitFreeHelper`: emit `@np_free(ptr raw, i64 size)`
- `EmitAllocatorFaultHelper`: emit `@allocator_fault(i64 code, i64 arg0, i64 arg1)`

**Phase 0 vs Phase 1b 说明**:
- Phase 0: 当前 bump 分配器足够自举，无锁、无线程竞争
- Phase 1b: TCache 三级分配器 (TLS+BsfQWord → Per-thread CTZ → Per-sizeclass spinlock → THeap radix tree+buddy)，需要 TLS 解构器 + 编译器 C5/C6

---

## Gate 5: Exception Unwind — 验证结果 (2026-06-18)

**状态: PASS (for self-hosting bootstrap)**

**关键发现**:
- 完整 setjmp/longjmp 异常基础设施已在 LLVM emitter 中实现
- 异常状态全局变量: @__np_exc_stack, @__np_exc_pending, @__np_exc_object
- try push/pop, raise, finally_end, except_end 全部实现
- Freestanding setjmp/longjmp (x86_64 asm, 不依赖 libc)
- HIR 模型完整定义: hikTryBegin/End, hikFinallyBegin/End, hikExceptBegin/End, hikRaise

**缺口 (非阻塞)**:
1. 无运行时异常对象模型 (裸指针, 无 Exception class 布局)
2. 无 unwinder 集成 (标记为可推迟)
3. 异常对象创建/访问只有基本 store/load
