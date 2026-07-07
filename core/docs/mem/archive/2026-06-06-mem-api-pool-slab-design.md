# Mem API, Pool/Arena, and Mapped Slab Convergence Design

## Goal

Make `nextpas.core.mem` a clear L0 foundation: one primary allocator contract, unambiguous arena/pool names, and no slab API that pretends to free memory while only updating counters.

## Current Problems

There are three allocator contracts:

- `nextpas.core.mem.intf.IAllocator` is minimal and already exported by `nextpas.core.mem`.
- `nextpas.core.mem.allocator.base.IAllocator` extends the minimal interface and is exported by `nextpas.core.mem.allocator`.
- `nextpas.core.mem.alloc.IAlloc` uses `TMemLayout`, `TAllocResult`, and capability objects.

There are also two `TArena` names with different kinds and lifecycles:

- `nextpas.core.mem.arena.TArena` is a record with manual `Init/Done`.
- `nextpas.core.mem.blockpool.TArena` is a class implementing `IArena`.

`TPool` has the same issue at the facade level:

- `nextpas.core.mem.pool.TPool` is a record helper.
- Pool submodules expose multiple class implementations (`TFixedPool`, `TFixedSlabPool`, `TSlabPool`, concurrent/sharded variants).

`TMappedSlabPool.FreeBlock` currently increments `TotalFrees` only, with no ownership validation, no free list, no double-free detection, and no reuse.

## Final Public Shape

The primary allocator interface will be `nextpas.core.mem.intf.IAllocator`.

`IAllocator` should include the allocator operations needed by the rest of the framework:

```pascal
type
  TAllocatorTraits = record
    ZeroInitialized: Boolean;
    ThreadSafe: Boolean;
    HasMemSize: Boolean;
    SupportsAligned: Boolean;
  end;

  IAllocator = interface
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits;
  end;
```

Compatibility aliases:

```pascal
type
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TAllocatorTraits = nextpas.core.mem.intf.TAllocatorTraits;
```

These aliases stay in `nextpas.core.mem.allocator.base` and `nextpas.core.mem.allocator`.

`IAlloc` stays source-compatible for existing layout/result users, but it is no longer described as the next main API. It becomes an advanced compatibility layer with adapters:

- `WrapAsAlloc(IAllocator): IAlloc` stays as the legacy outlet for existing
  layout/result consumers.
- `WrapAsAllocator(IAlloc): IAllocator` stays only as a deprecated inbound
  bridge for compatibility implementations.

## Naming Convergence

Stable names:

```pascal
// nextpas.core.mem.arena
TLocalArena = record ... end;
TArena = TLocalArena; // compatibility alias

// nextpas.core.mem.pool
TLocalBlockPool = record ... end;
TPool = TLocalBlockPool; // compatibility alias

// nextpas.core.mem.blockpool
TFixedArena = class(TInterfacedObject, IArena) ... end;
TArena = TFixedArena; // compatibility alias
```

The facade `nextpas.core.mem` should export the explicit names first:

```pascal
type
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TLocalArena = nextpas.core.mem.arena.TLocalArena;
  TLocalBlockPool = nextpas.core.mem.pool.TLocalBlockPool;
  TArena = TLocalArena;          // compatibility
  TPool = TLocalBlockPool;       // compatibility
```

This avoids breaking old consumers immediately while making new code self-documenting.

## Mapped Slab Free/Reuse

`TMappedSlabPool` will become a real page-local size-class allocator.

Each mapped page gets one descriptor in the existing 32-byte descriptor area:

```pascal
type
  PMappedSlabPage = ^TMappedSlabPage;
  TMappedSlabPage = packed record
    State: UInt32;
    BlockSize: UInt32;
    BlockCount: UInt32;
    FreeHeadOffset: UInt64;
    FreeCount: UInt32;
    UsedCount: UInt32;
    Generation: UInt32;
  end;
```

Each allocated block has a mapped-memory header immediately before the returned payload:

```pascal
type
  PMappedSlabBlock = ^TMappedSlabBlock;
  TMappedSlabBlock = packed record
    Magic: UInt32;
    State: UInt32;
    PageIndex: UInt32;
    BlockSize: UInt32;
    RequestedSize: UInt32;
    Generation: UInt32;
    NextFreeOffset: UInt64;
  end;
```

Free-list links use offsets relative to `FDataArea`, never raw pointers. That keeps file/shared mappings structurally valid after reopen or in a different process address space.

Allocation rounds requested size up to at least `SizeOf(UInt64)` and 8-byte alignment, adds the block header, then either reuses an existing page with matching `BlockSize` and `FreeCount > 0`, or initializes an empty page for that size class. The existing mixed-size linear offset algorithm is replaced because it can overlap allocations from different size classes.

`FreeBlock` must:

- Ignore `nil`.
- Reject pointers outside the mapped data payload range.
- Reject pointers that do not point at the start of a mapped block payload.
- Reject pointers from an uninitialized page.
- Reject stale pointers after `Reset`.
- Reject double frees by checking the mapped block state.
- Push the block onto the page's free list using relative offsets.
- Update `FreeCount`, `UsedCount`, `UsedPages`, and `TotalFrees` consistently.

This is not yet a highly optimized slab allocator. It is deliberately simple, correct, testable, and honest. Benchmark and SIMD-oriented tuning happen in the final benchmark round.

## Testing Strategy

Extend existing tests:

- `test_contracts`: canonical `IAllocator` aliases and adapter round-trip.
- `test_mem`: facade exposes the canonical full allocator surface.
- `test_arena`: `TLocalArena` stable name and `TArena` compatibility alias.
- `test_arena_class`: `TFixedArena` stable name and `TArena` compatibility alias.
- `test_pool`: `TLocalBlockPool` stable name and `TPool` compatibility alias.

Add new test:

- `tests/nextpas.core.mem/test_mapped_slab_pool/test_mapped_slab_pool.lpr`

Mapped slab tests:

- anonymous pool create/is valid/stats
- freed block is reused by the next same-size allocation
- mixed-size allocations do not overlap
- double free raises an allocation error
- external pointer free raises an allocation error
- cross-pool free raises an allocation error
- stale pointer after reset raises an allocation error
- reset clears free lists and stats
- heaptrc reports zero leaks

## Migration Path

Stage 1:

- Add canonical names and aliases.
- Keep all old public names compiling.
- Add tests proving alias identity and facade visibility.
- Implement real mapped slab reuse.

Stage 2:

- Update internal callers to prefer explicit names.
- Remove misleading comments that describe `IAlloc` as the successor API.
- Keep adapters for downstream compatibility.

Stage 3:

- After downstream consumers migrate, decide whether to deprecate legacy `TArena`/`TPool` aliases and `IAlloc` facade exposure.
- Run benchmark comparison against FPC RTL, Go, and Rust in the final benchmark round.

## Non-Goals

- No compiler work.
- No full repository test sweep in this first implementation batch.
- No benchmark implementation in this round.
- No broad allocator performance rewrite beyond the mapped slab correctness fix.
