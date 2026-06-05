# Mem DefaultAllocator, Memory-Map Allocator, and NUMA Audit

## Scope

This note is a read-only subagent audit for the active mem slice.

- Worktree: `codex/mem-api-pool-slab-20260606`
- Allowed output: docs/tests draft only
- Explicitly out of scope: `compiler/**`, `mapped_slab_pool`, `stack_pool`, `allocator.mimalloc`

The goal here is not to land implementation. The goal is to lock the API and
focused-test route for three follow-up batches:

1. `DefaultAllocator` concurrent initialization
2. mmap-backed `IAllocator`
3. NUMA optional capability with explicit no-op fallback

## Current State

### `DefaultAllocator`

`src/nextpas.core.mem.default.pas` is currently just:

- `function DefaultAllocator: IAllocator;`
- forwards to `nextpas.core.mem.allocator.foundation.GetRtlAllocator`

`src/nextpas.core.mem.allocator.rtl_allocator.pas` already does lazy singleton
construction with a critical section and interface anchor:

- `_RTLAllocatorObj`
- `_RTLAllocatorIntf`
- `GRtlAllocLock`

So the public `DefaultAllocator` contract is already small and good. The gap is
not public API breadth. The gap is that the repo still lacks a focused
concurrent cold-start proof for the default path.

### `memory_map`

`src/nextpas.core.mem.memory_map.pas` is currently a mapping object API:

- `TMemoryMap`
- `TSharedMemory`

It is not an allocator seam yet. That is good. It keeps mapping lifetime and
file/shared-memory operations separate from allocator policy.

### NUMA

There is no existing NUMA public surface in `mem` today. That means this batch
still has a clean chance to avoid a misleading "best effort" API.

The repo already uses a strong capability vocabulary elsewhere: publish explicit
capability truth, then expose optional surfaces only when that truth is real.
NUMA should follow that rule.

## 1. DefaultAllocator Concurrent Focused Test Design

### Public API Route

Keep the public surface unchanged:

```pascal
function DefaultAllocator: IAllocator;
```

Do not add backend-selection flags, test-only public setters, or a "thread-safe
variant" helper. The public contract is already correct.

### Internal Route

If the implementation is tightened later, prefer one of these patterns:

1. Reuse a `Once`-style one-time initializer internally.
2. Or mirror the `simd.cpuinfo` atomic state machine pattern:
   `0=init`, `1=running`, `2=done`.

The important contract is:

- one canonical allocator instance
- first concurrent callers all receive that same instance
- failed initialization resets cleanly and allows retry

Do not add a spin-only wait loop. If a waiting path is needed, use the existing
atomic wait/wake style already present in `sync.once` / platform wait-address
helpers.

### Recommended New Focused Test Unit

Create a dedicated test instead of widening `test_mem`:

- `tests/nextpas.core.mem/test_default_allocator/Makefile`
- `tests/nextpas.core.mem/test_default_allocator/test_default_allocator.lpr`

Reason:

- this is a contract about cold-start concurrency, not ordinary allocator usage
- it should stay small, repeatable, and cheap to run

### Recommended Test Cases

#### `TestDefaultAllocatorSingletonOnSingleThread`

Purpose:

- lock the existing basic identity contract before adding concurrency pressure

Checks:

- `DefaultAllocator <> nil`
- repeated calls return the same interface identity
- `Traits.ThreadSafe = True`

#### `TestDefaultAllocatorConcurrentColdStartReturnsSameInstance`

Setup:

- spawn `N` worker threads, for example `8` or `16`
- synchronize the start with a barrier or a start event
- each thread calls `DefaultAllocator` exactly once on the first release
- each thread stores its `IAllocator` into a unique slot

Checks:

- every slot is assigned
- every slot equals slot `0`
- no thread raises

This is the main focused contract.

#### `TestDefaultAllocatorConcurrentUsageAfterColdStart`

Setup:

- after the same concurrent cold start, let each thread run a short
  alloc/realloc/free loop using its captured allocator

Checks:

- no exceptions
- no nil on non-zero allocations
- all threads complete

This is secondary. It proves the published instance is usable after the
contended first access.

### Failure-Retry Proof

If the implementation later switches to a real once/state-machine initializer,
there should also be a failure-retry test. But that should not force a public
test API.

Recommended route:

- keep any factory override seam implementation-only
- or factor the initializer into an internal helper unit
- do not publish `SetDefaultAllocatorFactoryForTests(...)`

Target test name if that seam exists later:

- `TestDefaultAllocatorFailedInitCanRetry`

## 2. mmap-backed IAllocator Minimal Interface and Tests

### Main Recommendation

Do not retrofit `TMemoryMap` itself to implement `IAllocator`.

Keep responsibilities separate:

- `TMemoryMap` remains a mapping object
- allocator behavior lives in a dedicated allocator implementation unit

This avoids coupling file-map lifecycle, flush/resize helpers, and allocator
contracts into one class.

### Recommended Unit Name

Use a backend-style allocator unit, consistent with existing naming:

- `src/nextpas.core.mem.allocator.memory_map_allocator.pas`

This is clearer than overloading `nextpas.core.mem.memory_map`.

### Recommended Minimal Public Shape

For the first slice, keep the public surface narrow:

```pascal
type
  TMemoryMapAllocator = class(TAllocator)
  public
    constructor CreateAnonymous(aReservationSize: UInt64);
  end;

function CreateAnonymousMemoryMapAllocator(aReservationSize: UInt64): IAllocator;
```

Why this is the right minimum:

- it gives an honest mmap-backed allocator path
- it avoids dragging file-backed policy into v1
- it keeps `DefaultAllocator` unchanged
- it avoids pretending that all mapping modes are allocator-ready

### Recommended Semantics

The first version should be honest and small:

- anonymous mapping backed
- `AllocMem` returns zeroed memory
- `GetMem` returns writable memory
- `FreeMem(nil)` remains a no-op
- `ReallocMem` preserves prefix bytes
- allocator tracks enough metadata to free/realloc safely

Do not make the first slice:

- file-backed by default
- shared-memory by default
- a bump allocator with fake `FreeMem`
- a "large allocation only" backend hidden behind `DefaultAllocator`

If file-backed allocation is needed later, add that as an explicit follow-up
factory, not as silent flag growth in the first slice.

### Traits Recommendation

For the first honest version, the expected traits are:

- `ZeroInitialized = True`
- `ThreadSafe = True` only if internal metadata is actually locked
- `HasMemSize = True` only if tracked and returned honestly
- `SupportsAligned = False` unless general aligned allocation is really
  supported, not just page alignment by accident

### Recommended Focused Test Unit

- `tests/nextpas.core.mem/test_memory_map_allocator/Makefile`
- `tests/nextpas.core.mem/test_memory_map_allocator/test_memory_map_allocator.lpr`

Do not merge this into `test_mem`. The behavior is backend-specific.

### Recommended Test Cases

#### `TestAnonymousMemoryMapAllocatorTraits`

Checks:

- allocator creation succeeds
- traits match the intended contract

#### `TestAnonymousMemoryMapAllocatorAllocZeroed`

Checks:

- `AllocMem(32)` returns a block
- all bytes are zero

#### `TestAnonymousMemoryMapAllocatorReallocPreservesPrefix`

Checks:

- write a known byte pattern
- realloc to a larger size
- prefix survives

#### `TestAnonymousMemoryMapAllocatorMultipleAllocationsAreDistinct`

Checks:

- two live allocations do not alias
- both can be written independently

#### `TestAnonymousMemoryMapAllocatorLargeAllocation`

Checks:

- allocation larger than one page succeeds
- free succeeds

#### `TestAnonymousMemoryMapAllocatorNilAndZeroSizeSemantics`

Checks:

- `GetMem(0) = nil`
- `AllocMem(0) = nil`
- `FreeMem(nil)` is safe
- `ReallocMem(nil, size)` allocates
- `ReallocMem(ptr, 0)` frees and returns `nil`

### File-Backed Follow-Up

If a later batch really needs file-backed allocation, add it explicitly as a
second API slice:

```pascal
function OpenFileMemoryMapAllocator(
  const aFileName: string;
  aInitialSize: UInt64
): IAllocator;
```

But do not mix that into the first anonymous-backed allocator batch.

## 3. NUMA Optional Capability and No-Op Fallback

### Main Recommendation

Do not put NUMA behavior into `DefaultAllocator`.

Also do not publish methods that silently degrade to ordinary allocation.

Bad examples that should be avoided:

- "allocate on node X, but silently use default heap if unsupported"
- "interleave if possible, otherwise do nothing and still report success"
- "auto-detect NUMA and change default allocator placement"

That is exactly the half-finished default behavior this batch should reject.

### Recommended Public Shape

Keep NUMA as an optional provider/factory surface, not as a mandatory extension
on every allocator:

```pascal
type
  TNumaAllocatorCapabilities = record
    Available: Boolean;
    SupportsPreferredNode: Boolean;
    SupportsBindNode: Boolean;
    SupportsInterleave: Boolean;
    MaxNodeCount: UInt16;
  end;

  INumaAllocatorProvider = interface
    function Capabilities: TNumaAllocatorCapabilities;
    function TryCreatePreferredNodeAllocator(
      ANode: UInt16;
      out AAllocator: IAllocator
    ): Boolean;
    function TryCreateBoundNodeAllocator(
      ANode: UInt16;
      out AAllocator: IAllocator
    ): Boolean;
    function TryCreateInterleavedAllocator(
      const ANodes: array of UInt16;
      out AAllocator: IAllocator
    ): Boolean;
  end;

function DefaultNumaAllocatorProvider: INumaAllocatorProvider;
```

Why this shape is safer:

- `IAllocator` stays stable
- unsupported NUMA does not fake success
- future Linux/Windows backends can plug in without changing ordinary mem users
- the no-op provider is explicit and inspectable via `Capabilities`

### Recommended Unit Layout

If this line is implemented later, prefer:

- `src/nextpas.core.mem.numa.base.pas`
- `src/nextpas.core.mem.numa.intf.pas`
- `src/nextpas.core.mem.numa.noop.pas`
- `src/nextpas.core.mem.numa.pas`

Then host-specific truth can live below that in platform-owned units later,
without polluting the mem facade first.

### No-Op Fallback Semantics

The fallback provider must be explicit and conservative:

- `Capabilities.Available = False`
- all `Supports* = False`
- every `TryCreate*Allocator(...)` returns `False`
- every failed `Try...` leaves `AAllocator = nil`

Do not add non-`Try` convenience methods in the first public slice. That avoids
an API that must either lie or raise on every unsupported host.

### Recommended Initial Tests

When this public surface is eventually added, the first focused tests should be
pure contract tests for the no-op provider:

- `TestDefaultNumaProviderReportsUnavailable`
- `TestDefaultNumaProviderPreferredNodeReturnsFalseAndNil`
- `TestDefaultNumaProviderBindNodeReturnsFalseAndNil`
- `TestDefaultNumaProviderInterleaveReturnsFalseAndNil`

These should live in a dedicated test unit, for example:

- `tests/nextpas.core.mem/test_numa_provider/Makefile`
- `tests/nextpas.core.mem/test_numa_provider/test_numa_provider.lpr`

## Suggested Batch Order

Recommended order from lowest risk to highest signal:

1. `DefaultAllocator` concurrent focused test
2. `DefaultAllocator` internal once/state-machine tightening if needed
3. anonymous `memory_map_allocator`
4. NUMA no-op provider contract
5. real NUMA backend only after platform truth exists

## Risks

### `DefaultAllocator`

- A test that only checks "no crash" is too weak; it must lock same-instance
  identity under contended first call.
- A public test seam would be permanent API debt.

### mmap-backed allocator

- Turning `TMemoryMap` directly into `IAllocator` would couple unrelated
  responsibilities.
- A bump-only allocator with fake free semantics would repeat the same honesty
  problem this mem cleanup is already trying to remove elsewhere.
- File-backed mode in v1 would enlarge the surface before the anonymous path is
  proven.

### NUMA

- Silent fallback to ordinary allocation would make capability truth impossible
  to reason about.
- Wiring NUMA into `DefaultAllocator` too early would create host-specific,
  hard-to-test global behavior.
