# C6-G Hidden-Prelude Allocator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first hidden-prelude mmap-backed large-allocation family to the compiler allocator while preserving the existing 24-byte object header ABI, direct `@np_alloc` payload contract, and small-family brk/free-list/coalesce behavior.

**Architecture:** Freeze the new allocator-family contract in tests before touching production code. First extend LLVM source contracts so alloc/free size-domain changes, threshold-first free gating, mmap/munmap, hidden prelude, and allocator-fault trap paths are all explicit. Then add focused runtime smokes for a direct large payload allocation and a large object destructor/free path. Only after both RED layers fail for the right reasons should production code move to allocator constants, allocator-fault helper, large-family mmap/munmap, and object free size-contract fixes.

**Tech Stack:** Free Pascal, compiler HIR LLVM emitter, stage0 LLVM smoke flow, `build/verify_local.sh`, focused HIR contract binaries

---

### Task 1: Freeze C6-G RED source contracts

**Files:**
- Modify: `tests/hir/test_hir_object_free_contract.pas`
- Modify: `tests/hir/test_hir_class_alloc_contract.pas`
- Test: `build/verify_local.sh`

- [ ] **Step 1: Extend the object-free LLVM contract to demand the new alloc/free size domain**

Add checks for:

```pascal
ReleaseBoundaryAllocSizePos := FindAfter(
  '%alloc.size = add i64 %size, 24', LlvmText, ReleaseBoundaryMagicStorePos);
ReleaseBoundaryFreeCallPos := FindAfter(
  'call void @np_free(ptr %raw, i64 %alloc.size)', LlvmText,
  ReleaseBoundaryAllocSizePos);
```

This freezes the reviewed contract that `@np_object_release_valid` passes allocator request size, not payload size.

- [ ] **Step 2: Extend the object-free LLVM contract to demand large-family alloc shape**

Add checks for:

```pascal
AllocLargeThresholdPos := FindAfter(
  '%alloc.is.large = icmp uge i64 %size, 65536', LlvmText, FreeListGlobalPos);
AllocLargeBranchPos := FindAfter(
  'br i1 %alloc.is.large, label %alloc.large, label %free.scan',
  LlvmText, AllocLargeThresholdPos);
AllocMappedSizePos := FindAfter(
  '%alloc.mapped.raw = add i64 %size, 16', LlvmText, AllocLargeBranchPos);
AllocMappedRoundPos := FindAfter(
  '%alloc.mapped.len = and i64 %alloc.mapped.plusmask, -4096',
  LlvmText, AllocMappedSizePos);
AllocMmapCallPos := FindAfter('syscall', LlvmText, AllocMappedRoundPos);
AllocPreludeMagicPos := FindAfter(
  'store i64 131388245100000016, ptr %alloc.large.base', LlvmText,
  AllocMmapCallPos);
AllocPreludeLenPos := FindAfter(
  'store i64 %alloc.mapped.len, ptr %alloc.large.lenp', LlvmText,
  AllocPreludeMagicPos);
AllocLargeReturnPos := FindAfter('ret ptr %alloc.payload', LlvmText,
  AllocPreludeLenPos);
```

The exact helper names can differ, but the test must freeze all seven reviewed properties: threshold gate, page-rounded mapped length, mmap, prelude magic write, prelude length write, payload return, and no mutation of the small free-list entry path.

- [ ] **Step 3: Extend the object-free LLVM contract to demand threshold-first free gating**

Add checks for:

```pascal
FreeLargeThresholdPos := FindAfter(
  '%free.is.large = icmp uge i64 %size, 65536', LlvmText,
  ReleaseBoundaryFreeHelperPos);
FreeLargeBranchPos := FindAfter(
  'br i1 %free.is.large, label %free.large, label %free.small',
  LlvmText, FreeLargeThresholdPos);
FreePreludeBasePos := FindAfter(
  '%free.large.base = getelementptr i8, ptr %raw, i64 -16', LlvmText,
  FreeLargeBranchPos);
```

Then assert that `FreePreludeBasePos` appears after the threshold branch, never before it.

- [ ] **Step 4: Extend the object-free LLVM contract to demand stored-length munmap and allocator-fault trap paths**

Add checks for:

```pascal
FreeLargeMagicLoadPos := FindAfter('%free.large.magic = load i64, ptr %free.large.base',
  LlvmText, FreePreludeBasePos);
FreeLargeLenLoadPos := FindAfter('%free.large.len = load i64, ptr %free.large.lenp',
  LlvmText, FreeLargeMagicLoadPos);
FreeMunmapCallPos := FindAfter('syscall', LlvmText, FreeLargeLenLoadPos);
AllocatorFaultHelperPos := FindAfter(
  'define internal void @np_allocator_fault(i64 %code, i64 %arg0, i64 %arg1)',
  LlvmText, FreeMunmapCallPos);
AllocatorFaultTrapPos := FindAfter('call void @llvm.trap()', LlvmText,
  AllocatorFaultHelperPos);
```

The contract must also assert that the existing small-family top reclaim and restart-scan coalesce strings are still present.

- [ ] **Step 5: Extend the class-alloc LLVM contract to keep the 24-byte object ABI frozen**

Keep the current assertions and add one more explicit large-family compatibility assertion:

```pascal
if Pos('%obj = getelementptr i8, ptr %raw, i64 24', LlvmText) = 0 then
  Fail('missing-hir-class-alloc-payload-pointer');
```

This confirms that even after alloc-family changes, object payload remains `raw + 24`.

- [ ] **Step 6: Run the focused HIR contracts and verify RED**

Run:

```bash
fpc -Fucompiler/sema -Fucompiler/syntax -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/hir-object-free-red -FUbuild/.tmp/hir-object-free-red tests/hir/test_hir_object_free_contract.pas && build/.tmp/hir-object-free-red/test_hir_object_free_contract
fpc -Fucompiler/sema -Fucompiler/syntax -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/hir-class-alloc-red -FUbuild/.tmp/hir-class-alloc-red tests/hir/test_hir_class_alloc_contract.pas && build/.tmp/hir-class-alloc-red/test_hir_class_alloc_contract
```

Expected: at least `test_hir_object_free_contract` FAILS on the first missing C6-G source-contract condition, ideally the new alloc/free size-domain or large-branch assertion.

### Task 2: Freeze C6-G RED runtime smokes

**Files:**
- Create: `examples/smoke/llvm_large_alloc_payload.pas`
- Create: `examples/smoke/llvm_large_object_free.pas`
- Modify: `build/verify_local.sh`

- [ ] **Step 1: Add the direct large-allocation smoke source**

Create:

```pascal
program llvm_large_alloc_payload;

{$mode objfpc}{$H+}

var
  Buf: PByte;
  I: NativeInt;
begin
  GetMem(Buf, 65536);
  Buf[0] := 17;
  Buf[65535] := 29;
  I := Buf[0] + Buf[65535];
  FreeMem(Buf);
  Halt(I - 46);
end.
```

This is the first direct-payload smoke: it forces a threshold-sized allocation, writes first and last bytes, then frees through the ordinary allocator-owned runtime path.

- [ ] **Step 2: Add the large-object destructor/free smoke source**

Create:

```pascal
program llvm_large_object_free;

{$mode objfpc}{$H+}

type
  TLarge = class
  private
    FPad: array[0..70000] of Byte;
  public
    destructor Destroy; override;
  end;

var
  Obj: TLarge;
  ExitCode: Integer;

destructor TLarge.Destroy;
begin
  FPad[0] := 1;
  FPad[70000] := 2;
  inherited Destroy;
end;

begin
  ExitCode := 42;
  Obj := TLarge.Create;
  Obj.Free;
  Halt(ExitCode);
end.
```

The goal is not to prove fancy object semantics; it is to prove that a large object still follows the destroy/free path and that the object block ABI remains valid enough to survive `raw + 24`.

- [ ] **Step 3: Add focused verify-local hooks for the two new smokes**

Add focused sections to `build/verify_local.sh` for:

```bash
llvm-large-alloc-payload-program
llvm-large-object-free-program
```

Each section should build the smoke through stage0 LLVM, run the artifact, and assert the expected exit code.

- [ ] **Step 4: Run the two new smokes and verify RED**

Run:

```bash
./build/verify_local.sh
```

Expected: at least one new C6-G smoke FAILS before implementation, either at compile time or runtime, because the allocator still has no large-family mmap/prelude path.

### Task 3: Implement the minimal C6-G allocator

**Files:**
- Modify: `compiler/ir/np_hir_llvm_emitter.pas`
- Modify: `tests/hir/test_hir_object_free_contract.pas`
- Modify: `tests/hir/test_hir_class_alloc_contract.pas`
- Modify: `build/verify_local.sh`
- Modify: `examples/smoke/llvm_large_alloc_payload.pas`
- Modify: `examples/smoke/llvm_large_object_free.pas`

- [ ] **Step 1: Add allocator-private constants and allocator-fault helper**
- [ ] **Step 2: Change `@np_object_release_valid` to pass `%alloc.size = %size + 24`**
- [ ] **Step 3: Add `@np_alloc` large-family mmap path with hidden prelude**
- [ ] **Step 4: Add `@np_free` threshold-first large-family munmap path**
- [ ] **Step 5: Audit every `@np_free` caller for the new size contract**
- [ ] **Step 6: Run focused HIR contracts and both focused smokes to verify GREEN**

### Task 4: Close out C6-G

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

- [ ] **Step 1: Run the full closeout gates**

Run:

```bash
git diff --check
make hygiene
./build/verify_local.sh
```

- [ ] **Step 2: Record verification evidence and dirty-file scope**
- [ ] **Step 3: Prepare a Ready report only after all focused/runtime/full gates pass**
