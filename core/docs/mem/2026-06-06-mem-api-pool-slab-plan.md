# Mem API, Pool/Arena, and Mapped Slab Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge allocator interfaces, remove `TArena`/`TPool` name ambiguity with compatibility aliases, and make `TMappedSlabPool.FreeBlock` perform real free/reuse.

**Architecture:** The canonical allocator contract moves to `nextpas.core.mem.intf`; old allocator units become aliases and implementation holders. Arena/pool records get explicit stable names while legacy names remain aliases. Mapped slab uses mapped-memory page descriptors, mapped block headers, and relative-offset free lists.

**Tech Stack:** Free Pascal 3.3.1, ObjFPC, nextpas.core L0 mem units, per-test Makefiles with heaptrc.

---

## Files

Modify:

- `src/nextpas.core.mem.intf.pas`
- `src/nextpas.core.mem.allocator.base.pas`
- `src/nextpas.core.mem.allocator.pas`
- `src/nextpas.core.mem.alloc.pas`
- `src/nextpas.core.mem.adapter.pas`
- `src/nextpas.core.mem.arena.pas`
- `src/nextpas.core.mem.blockpool.pas`
- `src/nextpas.core.mem.pool.pas`
- `src/nextpas.core.mem.pas`
- `src/nextpas.core.mem.mapped_slab_pool.pas`
- `tests/nextpas.core.mem/test_contracts/test_contracts.lpr`
- `tests/nextpas.core.mem/test_mem/test_mem.lpr`
- `tests/nextpas.core.mem/test_arena/test_arena.lpr`
- `tests/nextpas.core.mem/test_arena_class/test_arena_class.lpr`
- `tests/nextpas.core.mem/test_pool/test_pool.lpr`
- `task_plan.md`
- `findings.md`
- `progress.md`

Create:

- `tests/nextpas.core.mem/test_mapped_slab_pool/Makefile`
- `tests/nextpas.core.mem/test_mapped_slab_pool/test_mapped_slab_pool.lpr`

## Task 1: Allocator Contract RED

- [ ] **Step 1: Write failing canonical alias tests**

Add tests to `tests/nextpas.core.mem/test_contracts/test_contracts.lpr`:

```pascal
procedure TestCanonicalAllocatorSurface;
var
  LAllocator: nextpas.core.mem.intf.IAllocator;
  LTraits: nextpas.core.mem.intf.TAllocatorTraits;
  LPtr: Pointer;
begin
  LAllocator := GetRtlAllocator as nextpas.core.mem.intf.IAllocator;
  LTraits := LAllocator.Traits;
  Check(LTraits.ThreadSafe, 'canonical allocator exposes traits');
  LPtr := LAllocator.GetMem(16);
  try
    Check(LPtr <> nil, 'canonical allocator exposes GetMem');
  finally
    LAllocator.FreeMem(LPtr);
  end;
end;
```

Also assert assignment identity:

```pascal
procedure TestAllocatorAliasesAreCanonical;
var
  LCanonical: nextpas.core.mem.intf.IAllocator;
  LFacade: nextpas.core.mem.allocator.IAllocator;
begin
  LFacade := GetRtlAllocator;
  LCanonical := LFacade as nextpas.core.mem.intf.IAllocator;
  Check(LCanonical <> nil, 'allocator facade alias should be canonical');
end;
```

- [ ] **Step 2: Verify RED**

Run:

```bash
make -C tests/nextpas.core.mem/test_contracts clean test
```

Expected: compile fails because `nextpas.core.mem.intf.IAllocator` does not expose `Traits`, `GetMem`, or `FreeMem`.

## Task 2: Allocator Contract GREEN

- [ ] **Step 1: Move allocator traits and full interface to `mem.intf`**

Implement `TAllocatorTraits` and the full `IAllocator` surface in `src/nextpas.core.mem.intf.pas`.

- [ ] **Step 2: Convert `allocator.base` to alias**

Replace the duplicate interface declaration with:

```pascal
type
  TAllocatorTraits = nextpas.core.mem.intf.TAllocatorTraits;
  IAllocator = nextpas.core.mem.intf.IAllocator;
```

Keep `TAllocator` in `allocator.base` as the abstract implementation class.

- [ ] **Step 3: Keep facade aliases compiling**

Verify `src/nextpas.core.mem.allocator.pas` and `src/nextpas.core.mem.pas` export the canonical interface and traits.

- [ ] **Step 4: Verify GREEN**

Run:

```bash
make -C tests/nextpas.core.mem/test_contracts clean test
make -C tests/nextpas.core.mem/test_mem clean test
```

Expected: both pass with heaptrc zero leaks.

## Task 3: IAlloc Compatibility Documentation And Tests

- [ ] **Step 1: Add adapter round-trip tests**

In `test_contracts`, add:

```pascal
procedure TestAllocatorAdapterRoundTrip;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LAlloc: IAlloc;
  LRoundTrip: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
begin
  LAllocator := GetRtlAllocator;
  LAlloc := WrapAsAlloc(LAllocator);
  LRoundTrip := WrapAsAllocator(LAlloc);
  LPtr := LRoundTrip.GetMem(24);
  try
    Check(LPtr <> nil, 'adapter round trip should allocate');
  finally
    LRoundTrip.FreeMem(LPtr);
  end;
end;
```

- [ ] **Step 2: Update comments**

Update `src/nextpas.core.mem.alloc.pas` and `src/nextpas.core.mem.adapter.pas` comments so `IAlloc` is described as layout/result compatibility, not the successor main API.

- [ ] **Step 3: Verify**

Run:

```bash
make -C tests/nextpas.core.mem/test_contracts clean test
```

Expected: pass with heaptrc zero leaks.

## Task 4: Arena/Pool Naming RED

- [ ] **Step 1: Update record arena tests to explicit name**

In `test_arena`, change main variables to `TLocalArena` and add one alias smoke:

```pascal
procedure TestArenaLegacyAlias;
var
  LA: TArena;
begin
  LA.Init(64);
  try
    Check(LA.Alloc(8) <> nil, 'legacy TArena alias remains usable');
  finally
    LA.Done;
  end;
end;
```

- [ ] **Step 2: Update class arena tests to explicit name**

In `test_arena_class`, change main variables to `TFixedArena` and keep one `TArena` alias smoke.

- [ ] **Step 3: Update pool tests to explicit name**

In `test_pool`, change main variables to `TLocalBlockPool` and keep one `TPool` alias smoke.

- [ ] **Step 4: Verify RED**

Run:

```bash
make -C tests/nextpas.core.mem/test_arena clean test
make -C tests/nextpas.core.mem/test_arena_class clean test
make -C tests/nextpas.core.mem/test_pool clean test
```

Expected: compile fails for missing `TLocalArena`, `TFixedArena`, or `TLocalBlockPool`.

## Task 5: Arena/Pool Naming GREEN

- [ ] **Step 1: Introduce stable record arena name**

In `src/nextpas.core.mem.arena.pas`:

```pascal
type
  TLocalArena = record
    ...
  end;
  TArena = TLocalArena;
```

Rename implementation method receivers from `TArena` to `TLocalArena`.

- [ ] **Step 2: Introduce stable record pool name**

In `src/nextpas.core.mem.pool.pas`:

```pascal
type
  TLocalBlockPool = record
    ...
  end;
  TPool = TLocalBlockPool;
```

Rename implementation method receivers from `TPool` to `TLocalBlockPool`.

- [ ] **Step 3: Introduce stable block arena class name**

In `src/nextpas.core.mem.blockpool.pas`:

```pascal
type
  TFixedArena = class(TInterfacedObject, IArena)
    ...
  end;
  TArena = TFixedArena;
```

Rename implementation method receivers from `TArena` to `TFixedArena`.

- [ ] **Step 4: Update facade aliases**

In `src/nextpas.core.mem.pas`, export:

```pascal
type
  TLocalArena = nextpas.core.mem.arena.TLocalArena;
  TLocalBlockPool = nextpas.core.mem.pool.TLocalBlockPool;
  TArena = TLocalArena;
  TPool = TLocalBlockPool;
```

- [ ] **Step 5: Verify GREEN**

Run:

```bash
make -C tests/nextpas.core.mem/test_arena clean test
make -C tests/nextpas.core.mem/test_arena_class clean test
make -C tests/nextpas.core.mem/test_pool clean test
make -C tests/nextpas.core.mem/test_mem clean test
```

Expected: pass with heaptrc zero leaks.

## Task 6: Mapped Slab RED

- [ ] **Step 1: Create mapped slab test project**

Create `tests/nextpas.core.mem/test_mapped_slab_pool/Makefile` following existing mem test Makefile style.

- [ ] **Step 2: Write failing reuse and safety tests**

Create `test_mapped_slab_pool.lpr` with tests:

```pascal
procedure TestFreeReusesSameSizeBlock;
var
  LPool: TMappedSlabPool;
  LP1, LP2: Pointer;
begin
  LPool := TMappedSlabPool.Create;
  try
    Check(LPool.CreateAnonymous(4096, 4096, 256), 'create anonymous pool');
    LP1 := LPool.Alloc(64);
    Check(LP1 <> nil, 'first alloc');
    LPool.FreeBlock(LP1);
    LP2 := LPool.Alloc(64);
    Check(LP2 = LP1, 'free should make block reusable');
  finally
    LPool.Free;
  end;
end;
```

Add tests for:

```pascal
LPool.FreeBlock(LP1);
CheckRaises(EAllocError, procedure begin LPool.FreeBlock(LP1); end);
CheckRaises(EAllocError, procedure begin LPool.FreeBlock(@LocalByte); end);
LPool.Reset;
```

Also add mixed-size and stale-pointer RED tests:

```pascal
LP1 := LPool.Alloc(1024);
LP2 := LPool.Alloc(2048);
LP3 := LPool.Alloc(2048);
Check((PtrUInt(LP1) + 1024 <= PtrUInt(LP2)) or (PtrUInt(LP2) + 2048 <= PtrUInt(LP1)), 'mixed-size blocks must not overlap');
Check((PtrUInt(LP2) + 2048 <= PtrUInt(LP3)) or (PtrUInt(LP3) + 2048 <= PtrUInt(LP2)), 'same-size blocks must not overlap');
LPool.Reset;
CheckRaises(EAllocError, procedure begin LPool.FreeBlock(LP1); end);
```

- [ ] **Step 3: Verify RED**

Run:

```bash
make -C tests/nextpas.core.mem/test_mapped_slab_pool clean test
```

Expected: reuse test fails because `FreeBlock` only increments `TotalFrees`, and safety tests fail because invalid/double free is not detected.

## Task 7: Mapped Slab GREEN

- [ ] **Step 1: Add page descriptor type and constants**

Add to `src/nextpas.core.mem.mapped_slab_pool.pas` implementation type section:

```pascal
const
  MAPPED_SLAB_PAGE_EMPTY = 0;
  MAPPED_SLAB_PAGE_ACTIVE = 1;
  MAPPED_SLAB_INVALID_OFFSET = High(UInt64);
  MAPPED_SLAB_BLOCK_MAGIC = $424B4C53; // 'SLKB'
  MAPPED_SLAB_BLOCK_FREE = 0;
  MAPPED_SLAB_BLOCK_ALLOCATED = 1;

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

- [ ] **Step 2: Add helpers**

Implement helpers:

```pascal
function AlignPayloadSize(aSize: UInt64): UInt32;
function PageDescriptor(aPageIndex: UInt32): PMappedSlabPage;
function PageBase(aPageIndex: UInt32): PByte;
procedure InitializePage(aPageIndex: UInt32; aBlockSize: UInt32);
function PopBlock(aPageIndex: UInt32): Pointer;
procedure PushBlock(aPageIndex: UInt32; aBlock: PMappedSlabBlock);
function FindPageForAlloc(aBlockSize: UInt32; out aPageIndex: UInt32): Boolean;
function FindPointerBlock(aPtr: Pointer; out aPageIndex: UInt32; out aBlock: PMappedSlabBlock): Boolean;
function OffsetOfBlock(aBlock: PMappedSlabBlock): UInt64;
function BlockFromOffset(aOffset: UInt64): PMappedSlabBlock;
```

- [ ] **Step 3: Replace `Alloc`**

Make `Alloc`:

```pascal
LPayloadSize := AlignPayloadSize(aSize);
LBlockSize := SizeOf(TMappedSlabBlock) + LPayloadSize;
if not FindPageForAlloc(LBlockSize, LPageIndex) then
  FailedAllocs += 1
else
  Result := PopBlock(LPageIndex);
```

- [ ] **Step 4: Replace `FreeBlock`**

Make `FreeBlock`:

```pascal
if aPtr = nil then Exit;
if not FindPointerBlock(aPtr, LPageIndex, LBlock) then
  raise EAllocError.Create(aeInvalidLayout, 'TMappedSlabPool.FreeBlock: pointer does not belong to pool');
if LBlock^.State <> MAPPED_SLAB_BLOCK_ALLOCATED then
  raise EAllocError.Create(aeInvalidLayout, 'TMappedSlabPool.FreeBlock: double free');
PushBlock(LPageIndex, LBlock);
Inc(Header.TotalFrees);
```

- [ ] **Step 5: Reset descriptors**

Ensure `Reset` zeroes descriptors and stats. After reset, allocation should rebuild pages from scratch.

- [ ] **Step 6: Verify GREEN**

Run:

```bash
make -C tests/nextpas.core.mem/test_mapped_slab_pool clean test
make -C tests/nextpas.core.mem/test_contracts clean test
make -C tests/nextpas.core.mem/test_mem clean test
```

Expected: pass with heaptrc zero leaks.

## Task 8: Final Focused Verification And Review

- [ ] **Step 1: Run all focused mem gates**

```bash
make -C tests/nextpas.core.mem/test_contracts clean test
make -C tests/nextpas.core.mem/test_mem clean test
make -C tests/nextpas.core.mem/test_arena clean test
make -C tests/nextpas.core.mem/test_arena_class clean test
make -C tests/nextpas.core.mem/test_pool clean test
make -C tests/nextpas.core.mem/test_blockpool clean test
make -C tests/nextpas.core.mem/test_oom clean test
make -C tests/nextpas.core.mem/test_mapped_slab_pool clean test
git diff --check
git status --short --branch
```

- [ ] **Step 2: Run read-only review**

Ask a subagent/codex reviewer to inspect only changed files for:

- duplicate allocator contracts
- broken compatibility aliases
- mapped slab invalid pointer/double-free behavior
- leak evidence
- accidental non-mem changes

- [ ] **Step 3: Commit**

```bash
git add src/nextpas.core.mem*.pas tests/nextpas.core.mem docs/plans/2026-06-06-mem-api-pool-slab-design.md docs/plans/2026-06-06-mem-api-pool-slab-plan.md task_plan.md findings.md progress.md
git commit -m "refactor(mem): converge allocator and pool APIs"
```
