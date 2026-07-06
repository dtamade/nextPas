# Atomic/Lockfree Completion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring `nextpas.core.atomic` and `nextpas.core.lockfree` from the current mid-production state to a complete production-ready foundation with safe reclamation, unbounded MPMC, hazard pointers, SPMC, and verification/benchmark coverage.

**Architecture:** Stabilize the low-level atomic/wait surface first, then add reusable reclamation before any dynamically reclaimed multi-consumer structure. Build unbounded SegQueue on top of EBR, then add Hazard Pointer as a second reclamation primitive, followed by SPMC and low-risk cleanup/bench/docs work.

**Tech Stack:** FreePascal/ObjFPC, `nextpas.core.atomic`, `nextpas.core.lockfree`, `nextpas.core.platform.sync`, heaptrc, existing Makefile test gates.

---

## Current Baseline

Already completed in this worktree:

- `d4c50006d perf(lockfree): downgrade deque IsEmpty/ApproxCount from seq_cst to acquire`
- `2230f90ac perf(lockfree): add cache-line padding to MPMC enqueue/dequeue positions`
- `23840c2b7 feat(atomic): add 64-bit wait/notify support`

Known verified gates:

```bash
make -C core/tests/nextpas.core.atomic/test_atomic clean test
# Expected: 44 total, 44 passed, 0 failed, 0 leaks

make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
# Expected: 46 total, 46 passed, 0 failed, 0 leaks

make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test
# Expected: 11 total, 11 passed, 0 failed, 0 leaks
```

Codex route decision:

1. 64-bit wait fallback补强
2. `fetch_update`
3. EBR
4. SegQueue
5. Hazard Pointer
6. 局部去重
7. SPMC
8. bench/docs 收口

Important technical constraints:

- Do **not** implement runtime-freeing unbounded SegQueue before EBR/HP. Segment unlink without reclamation risks UAF.
- x86 `LOCK AND/OR/XOR` does not return old value; current CAS-loop fetch bitwise RMW is the correct semantic implementation.
- Deque last-item arbitration must keep `moSeqCst` source contract.

---

## Task 1: Strengthen 64-bit wait/notify fallback tests

**Files:**
- Modify: `core/tests/nextpas.core.atomic/test_atomic/test_atomic.lpr`
- Modify: `core/docs/atomic/README.md`
- Verify: `core/src/nextpas.core.platform.sync.pas`

**Step 1: Add source-contract checks for 64-bit platform wait surface**

In `TestAtomicSourceContracts`, add checks that `nextpas.core.platform.sync.pas` exposes and implements:

```pascal
CheckContains(LPlatformSyncSource, 'function platform_wait_address64(AAddr: PInt64; const AExpected: Int64; const ATimeoutNs: Int64): Int32;',
  'platform sync must expose 64-bit wait-address primitive');
CheckContains(LPlatformSyncSource, 'function platform_posix_wait_address_fallback64',
  'POSIX 64-bit wait fallback must use bucket-based condvar path');
CheckContains(LPlatformSyncSource, 'SizeOf(LExpected)',
  'Windows 64-bit wait path must pass 8-byte expected size to WaitOnAddress');
```

**Step 2: Add runtime 64-bit mismatch/timeout/notify smoke test**

Extend `TestAtomicWaitNotify64SurfaceAndBehavior` to cover both signed and unsigned:

```pascal
var
  LUnsigned: UInt64;
...
LUnsigned := UInt64($F0F0F0F0F0F0F0F0);
LRet := atomic_wait(LUnsigned, UInt64(1), 1000000);
CheckEqual(Int64(PLATFORM_ERR_AGAIN), Int64(LRet),
  'atomic_wait(uint64) must return AGAIN on mismatch');
CheckEqual(Int64(0), Int64(atomic_notify_all(LUnsigned)),
  'atomic_notify_all(uint64) should succeed on supported platforms');
```

**Step 3: Add lost-wake ping-pong test**

Add a small 64-bit ping-pong loop using one waiter thread and one notifier thread:

- shared `Int64 LValue64`
- waiter loops `for I := 1 to 1000`, waiting while value is not expected
- notifier stores expected value and calls `atomic_notify_all(LValue64)`
- verify no hang and all iterations observed

Keep loop count modest to avoid CI timeouts.

**Step 4: Document 64-bit wait caveat**

In `core/docs/atomic/README.md`, update `AtomicWait/Notify` section:

- 32-bit uses platform wait-address directly.
- 64-bit uses native Windows WaitOnAddress and bucket-based condvar fallback on Linux/POSIX.
- Linux futex does not provide native 64-bit value compare here.
- `notify_one` on bucket fallback may wake a colliding address; users must always wait in predicate loops.

**Step 5: Run tests**

```bash
make -C core/tests/nextpas.core.atomic/test_atomic clean test
```

Expected:

```text
--- nextpas.core.atomic: 44+ total, all passed, 0 failed ---
0 unfreed memory blocks : 0
```

**Step 6: Commit**

```bash
git add core/tests/nextpas.core.atomic/test_atomic/test_atomic.lpr core/docs/atomic/README.md
git commit -m "test(atomic): strengthen 64-bit wait notify contracts"
```

---

## Task 2: Add atomic fetch_update CAS-loop abstraction

**Files:**
- Modify: `core/src/nextpas.core.atomic.pas`
- Modify: `core/src/nextpas.core.atomic.types.pas`
- Modify: `core/tests/nextpas.core.atomic/test_atomic/test_atomic.lpr`
- Modify: `core/docs/atomic/README.md`

**Design:** Avoid anonymous-function overhead in the hot path by providing small, typed helper forms rather than a general closure callback. Implement two public variants:

1. `atomic_fetch_update_max/min` remains existing specialized API.
2. New generic-looking Pascal API is limited to type-safe records with method names, not callback closure:

```pascal
function atomic_update_if_equal(var aObj: Int32; const AExpected: Int32; const ADesired: Int32; out AObserved: Int32; AOrder: memory_order_t = mo_seq_cst): Boolean; overload;
function atomic_update_if_equal_64(var aObj: Int64; const AExpected: Int64; const ADesired: Int64; out AObserved: Int64; AOrder: memory_order_t = mo_seq_cst): Boolean; overload;
```

This gives callers reusable CAS-loop building blocks without anonymous function allocation.

**Step 1: Write failing tests**

Add `TestAtomicFetchUpdateContract`:

```pascal
procedure TestAtomicFetchUpdateContract;
var
  LValue: Int32;
  LObserved: Int32;
begin
  LValue := 10;
  Check(atomic_update_if_equal(LValue, 10, 20, LObserved, mo_seq_cst),
    'atomic_update_if_equal should succeed on expected value');
  CheckEqual(Int64(10), Int64(LObserved));
  CheckEqual(Int64(20), Int64(LValue));

  Check(not atomic_update_if_equal(LValue, 10, 30, LObserved, mo_seq_cst),
    'atomic_update_if_equal should fail on mismatch');
  CheckEqual(Int64(20), Int64(LObserved));
  CheckEqual(Int64(20), Int64(LValue));
end;
```

Register it near fetch max/min/nand tests.

**Step 2: Implement Int32/UInt32/Int64/UInt64 helpers**

In `nextpas.core.atomic.pas`, add overload declarations near CAS APIs and implementations near CAS helpers. Use existing validated CAS order derivation:

```pascal
function atomic_update_if_equal(var aObj: Int32; const AExpected: Int32; const ADesired: Int32; out AObserved: Int32; AOrder: memory_order_t): Boolean;
begin
  AObserved := AExpected;
  Result := atomic_compare_exchange_strong(aObj, AObserved, ADesired,
    _cas_success_order(AOrder), AtomicCompareExchangeMaxFailureOrder(_cas_success_order(AOrder)));
end;
```

Mirror for unsigned via casts and 64-bit via `_64` CAS.

**Step 3: Add typed methods**

In `nextpas.core.atomic.types.pas`, add methods:

```pascal
function UpdateIfEqual(AExpected: Int32; ADesired: Int32; out AObserved: Int32; AOrder: memory_order_t = mo_seq_cst): Boolean;
```

Mirror for UInt32/Int64/UInt64/ISize/USize.

**Step 4: Run tests**

```bash
make -C core/tests/nextpas.core.atomic/test_atomic clean test
```

Expected: all pass, heaptrc 0 leaks.

**Step 5: Commit**

```bash
git add core/src/nextpas.core.atomic.pas core/src/nextpas.core.atomic.types.pas core/tests/nextpas.core.atomic/test_atomic/test_atomic.lpr core/docs/atomic/README.md
git commit -m "feat(atomic): add typed update-if-equal CAS helpers"
```

---

## Task 3: Add EBR reclamation primitive

**Files:**
- Create: `core/src/nextpas.core.lockfree.ebr.pas`
- Modify: `core/src/nextpas.core.lockfree.pas`
- Modify: `core/docs/lockfree/README.md`
- Modify: `core/tests/nextpas.core.lockfree/test_lockfree/test_lockfree.lpr`
- Modify: `core/tests/nextpas.core.lockfree/test_lockfree/Makefile` only if forced compile target needs new file explicitly

**Public API:**

```pascal
type
  TLockFreeReclaimProc = procedure(AData: Pointer; AUserData: Pointer);

  TEbrDomain = class
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enter;
    procedure Leave;
    procedure Retire(AData: Pointer; AReclaim: TLockFreeReclaimProc; AUserData: Pointer = nil);
    procedure Collect;
    function ActiveCount: PtrUInt;
    function RetiredCount: PtrUInt;
  end;

  TEbrGuard = record
  private
    FDomain: TEbrDomain;
    FActive: Boolean;
  public
    class function Enter(ADomain: TEbrDomain): TEbrGuard; static;
    procedure Leave;
  end;
```

**Implementation approach:**

- P0 EBR is deliberately conservative.
- Maintain atomic `FActiveCount`.
- `Retire` appends retired nodes to a domain-owned list protected by a lightweight mutex/spinlock or existing atomic exchange list.
- `Collect` only reclaims when `FActiveCount = 0`.
- This is not full epoch advancement yet, but is safe and sufficient for SegQueue retirement if collect runs after quiescent windows or periodically.

**Step 1: Write tests first**

Add tests:

```pascal
procedure TestEbrRetireCollect;
procedure TestEbrDefersWhileGuardActive;
procedure TestEbrGuardLeaveIdempotent;
```

Test `Retire` with a reclaim proc that increments an atomic counter.

**Step 2: Implement minimal TEbrDomain**

Use unmanaged internal retired node:

```pascal
type
  PEbrRetiredNode = ^TEbrRetiredNode;
  TEbrRetiredNode = record
    Next: PEbrRetiredNode;
    Data: Pointer;
    Reclaim: TLockFreeReclaimProc;
    UserData: Pointer;
  end;
```

Use atomic exchange to push retired nodes; `Collect` steals list and either reclaims or puts it back if active.

**Step 3: Export from facade**

Add `nextpas.core.lockfree.ebr` to `nextpas.core.lockfree.pas` uses and expose names if needed.

**Step 4: Run tests**

```bash
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test-debug
```

Expected: all pass, 0 leaks.

**Step 5: Commit**

```bash
git add core/src/nextpas.core.lockfree.ebr.pas core/src/nextpas.core.lockfree.pas core/tests/nextpas.core.lockfree/test_lockfree/test_lockfree.lpr core/docs/lockfree/README.md
git commit -m "feat(lockfree): add conservative EBR reclamation domain"
```

---

## Task 4: Add unbounded MPMC SegQueue using EBR

**Files:**
- Create: `core/src/nextpas.core.lockfree.segqueue.pas`
- Modify: `core/src/nextpas.core.lockfree.pas`
- Modify: `core/docs/lockfree/README.md`
- Modify: `core/tests/nextpas.core.lockfree/test_lockfree/test_lockfree.lpr`
- Modify: `core/tests/nextpas.core.lockfree/test_lockfree_stress/test_lockfree_stress.lpr`
- Modify: `core/benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr`

**Data model:**

```pascal
const
  SEGQUEUE_SEGMENT_CAPACITY = 32;

type
  TSegSlot = record
    Sequence: Int64;
    Value: T;
  end;

  PSegment = ^TSegment;
  TSegment = record
    Next: PSegment;
    StartIndex: Int64;
    Slots: array[0..SEGQUEUE_SEGMENT_CAPACITY - 1] of TSegSlot;
  end;
```

Queue fields:

```pascal
FHead: PSegment;
FTail: PSegment;
FEnqueuePos: Int64;
FDequeuePos: Int64;
FClosed: Int32; // optional, only if wait/close API is included
FEbr: TEbrDomain;
```

**API:**

```pascal
generic TSegQueueImpl<T> = class
public
  constructor Create;
  destructor Destroy; override;
  procedure Enqueue(const AValue: T);
  function TryDequeue(out AValue: T): Boolean;
  function IsEmpty: Boolean;
  function ApproxCount: PtrUInt;
end;
```

Do not promise wait/timeout in first SegQueue commit; keep non-blocking.

**Step 1: Single-thread test**

Add test:

```pascal
procedure TestSegQueueBasic;
```

Cover empty, enqueue 1..100, dequeue exactly in FIFO order.

**Step 2: Segment rollover test**

Add test with `SEGQUEUE_SEGMENT_CAPACITY * 4 + 3` items to force segment allocation and retirement.

**Step 3: Implement skeleton and single-thread path**

Implement segment allocation, slot sequence init, enqueue/dequeue linearization.

**Step 4: Add multi-thread exactly-once test**

In stress file, add 4P+4C, 80K messages, consumed bitmap/atomic counts.

**Step 5: Add EBR retirement**

When head segment advances and is detached, call:

```pascal
FEbr.Retire(LOldSegment, @SegQueueReclaimSegment, nil);
FEbr.Collect;
```

Every `Enqueue`/`TryDequeue` enters EBR guard while reading head/tail/next.

**Step 6: Export facade**

In `nextpas.core.lockfree.pas`:

```pascal
uses ..., nextpas.core.lockfree.segqueue;

generic TSegQueue<T> = class(specialize TSegQueueImpl<T>) end;
```

**Step 7: Bench**

Add benchmark case:

- SegQueue 2P+2C unbounded
- compare against bounded MPMC with same message count

**Step 8: Run gates**

```bash
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean run
```

Expected: tests pass, benchmark prints SegQueue scenario.

**Step 9: Commit**

```bash
git add core/src/nextpas.core.lockfree.segqueue.pas core/src/nextpas.core.lockfree.pas core/tests/nextpas.core.lockfree/test_lockfree/test_lockfree.lpr core/tests/nextpas.core.lockfree/test_lockfree_stress/test_lockfree_stress.lpr core/benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr core/docs/lockfree/README.md
git commit -m "feat(lockfree): add EBR-backed unbounded MPMC segqueue"
```

---

## Task 5: Add Hazard Pointer reclamation primitive

**Files:**
- Create: `core/src/nextpas.core.lockfree.hazard.pas`
- Modify: `core/src/nextpas.core.lockfree.pas`
- Modify: `core/tests/nextpas.core.lockfree/test_lockfree/test_lockfree.lpr`
- Modify: `core/docs/lockfree/README.md`

**API:**

```pascal
type
  THazardDomain = class
  public
    constructor Create;
    destructor Destroy; override;
    function Acquire: THazardGuard;
    procedure Retire(AData: Pointer; AReclaim: TLockFreeReclaimProc; AUserData: Pointer = nil);
    procedure Scan;
  end;

  THazardGuard = record
  public
    function Protect(var AAtomicPtr: Pointer): Pointer;
    procedure Clear;
  end;
```

**Implementation:**

- Fixed initial hazard slot array, grow only under domain lock.
- `Protect` loop: load pointer, publish hazard, reload pointer, return when stable.
- `Retire` scans hazards; only reclaim when pointer not present.

**Tests:**

- Protected node is not reclaimed.
- Clear then scan reclaims exactly once.
- Two hazard guards protecting different nodes.
- Retire nil behavior defined as no-op.

**Run:**

```bash
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
```

**Commit:**

```bash
git commit -m "feat(lockfree): add hazard pointer reclamation domain"
```

---

## Task 6: Local cleanup and helper extraction

**Files:**
- Modify: `core/src/nextpas.core.lockfree.base.pas`
- Modify: `core/src/nextpas.core.lockfree.spsc.pas`
- Modify: `core/src/nextpas.core.lockfree.mpmc.pas`
- Modify: `core/src/nextpas.core.lockfree.stack.pas`
- Modify: `core/src/nextpas.core.lockfree.deque.pas`

**Scope:** Only extract clear duplication; no algorithm changes.

Allowed helpers:

```pascal
procedure LockFreeSpinPause(var ASpin: Int32);
type TCacheLinePad = array[0..3] of Int64;
```

Replace local padding arrays with `TCacheLinePad`.

**Tests:**

```bash
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test
```

**Commit:**

```bash
git commit -m "refactor(lockfree): extract shared padding and spin helpers"
```

---

## Task 7: Add bounded SPMC queue

**Files:**
- Create: `core/src/nextpas.core.lockfree.spmc.pas`
- Modify: `core/src/nextpas.core.lockfree.pas`
- Modify: `core/tests/nextpas.core.lockfree/test_lockfree/test_lockfree.lpr`
- Modify: `core/tests/nextpas.core.lockfree/test_lockfree_stress/test_lockfree_stress.lpr`
- Modify: `core/docs/lockfree/README.md`

**Design:** Single producer writes a bounded ring. Multiple consumers claim positions via CAS on `FHead`. Producer owns `FTail` but publishes tail with release store.

**API:**

```pascal
generic TSpmcQueueImpl<T> = class
public
  constructor Create(const ACapacity: PtrUInt);
  function TryEnqueue(const AValue: T): Boolean;
  function TryDequeue(out AValue: T): Boolean;
  function IsEmpty: Boolean;
  function IsFull: Boolean;
  function ApproxCount: PtrUInt;
  function Capacity: PtrUInt;
end;
```

No wait/close in first commit.

**Tests:**

- Basic FIFO single consumer.
- Capacity rounds to power-of-two.
- Full/empty behavior.
- 1 producer + 4 consumers exactly-once stress.

**Commit:**

```bash
git commit -m "feat(lockfree): add bounded SPMC queue"
```

---

## Task 8: Bench and docs finalization

**Files:**
- Modify: `core/benchmarks/nextpas.core.atomic/bench_atomic/bench_atomic.lpr`
- Modify: `core/benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr`
- Modify: `core/docs/atomic/README.md`
- Modify: `core/docs/lockfree/README.md`
- Optional modify: `core/docs/plans/2026-06-14-atomic-lockfree-completion.md`

**Atomic bench additions:**

- `atomic_update_if_equal` success path
- `TAtomicInt64.Wait` timeout=0 path

**Lockfree bench additions:**

- SegQueue 2P+2C
- SPMC 1P+2C
- EBR retire/collect microbenchmark

**Final gates:**

```bash
make hygiene
make -C core/tests/nextpas.core.atomic/test_atomic clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test-forced-compile
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test-debug
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test
make -C core/benchmarks/nextpas.core.atomic/bench_atomic clean run
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean run
git diff --check
git status --short --branch
```

**Commit:**

```bash
git commit -m "docs(lockfree): document reclamation and queue evidence matrix"
```

---

## Execution Notes

- Use Codex as primary implementation/review agent for each task.
- After each task, run the focused tests and commit.
- Do not add managed element support to lockfree containers.
- Do not claim cross-platform runtime readiness without target runtime gates.
- If EBR or HP correctness becomes uncertain, stop and ask Codex for adversarial review before proceeding.
