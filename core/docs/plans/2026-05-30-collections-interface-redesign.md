# Collections Interface Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix critical bugs, align all new containers (BTreeMap/BTreeSet/ConcurrentHashMap/SwissTable) with the framework's interface-based architecture, achieve 100% API test coverage.

**Architecture:** Dual-surface design — concrete classes for maximum performance, semantic interfaces for facade/DI. Adapter pattern for SwissTable→IHashMap. Independent IConcurrentMap (not extending IHashMap) for thread-safe containers.

**Tech Stack:** FreePascal generics, TGenericCollection base, IRWLock, SIMD SwissTable

---

## Phase 0: Critical Bug Fixes (correctness first)

### Task 0.1: Fix ConcurrentHashMap nil hash crash

**Problem:** `SegmentIndex` unconditionally calls `FHash(AKey)` but `AHash` defaults to nil. Also, custom hash/equals are not forwarded to internal SwissTable segments.

**Files:**
- Modify: `src/nextpas.core.collections.concurrent.hashmap.pas`
- Test: `tests/nextpas.core.collections/test_concurrent_hashmap/test_concurrent_hashmap.lpr`

**Step 1: Write failing test — nil hash crash**

Add test that creates ConcurrentHashMap with default hash (nil) for Integer key:
```pascal
procedure TestDefaultHash;
var M: TIntConcMap; v: Integer;
begin
  // Create without explicit hash — should use built-in hash
  M := TIntConcMap.Create(nil, nil);
  try
    M.Put(42, 420);
    Check(M.TryGetValue(42, v), 'get 42');
    CheckEqual(Int64(420), Int64(v), 'val 42');
  finally M.Free; end;
end;
```

**Step 2: Run test — expect crash (SIGSEGV calling nil function)**

**Step 3: Fix — add default hash using GetTypeKind specialization**

In `SegmentIndex`:
```pascal
function TConcurrentHashMap.SegmentIndex(const AKey: K): SizeUInt;
var LHash: UInt32;
begin
  if Assigned(FHash) then
    LHash := FHash(AKey)
  else
    LHash := InlineHashMix32(UInt32(PtrUInt(@AKey)^));
  Result := (LHash shr 28) and CONCURRENT_SEGMENT_MASK;
end;
```

Better: use the same `GetTypeKind` specialization as SwissTable.KeyHash for built-in default.

**Step 4: Run test — expect PASS**

**Step 5: Commit**
```
fix(collections): ConcurrentHashMap handle nil hash with built-in default
```

---

### Task 0.2: Fix BTreeSet.Add return value

**Problem:** `ITreeSet.Add` returns Boolean (false if already exists), but `TBTreeSet.Add` is `procedure`.

**Files:**
- Modify: `src/nextpas.core.collections.btree.pas` (TBTreeSet.Add signature + impl)
- Test: `tests/nextpas.core.collections/test_btreemap/test_btreemap.lpr`

**Step 1: Write failing test**
```pascal
procedure TestBTreeSetAddReturn;
var S: TIntBTreeSet;
begin
  S := TIntBTreeSet.Create(@CmpInt);
  try
    Check(S.Add(1), 'first add returns true');
    Check(not S.Add(1), 'duplicate add returns false');
    CheckEqual(Int64(1), Int64(S.Count), 'count still 1');
  finally S.Free; end;
end;
```

**Step 2: Fix — change Add to function returning Boolean**
```pascal
function TBTreeSet.Add(const AItem: T): Boolean;
var LOldCount: SizeUInt;
begin
  LOldCount := FInner.Count;
  FInner.Put(AItem, 0);
  Result := FInner.Count > LOldCount;
end;
```

**Step 3: Run test — PASS**

**Step 4: Commit**
```
fix(collections): BTreeSet.Add returns Boolean (ITreeSet contract)
```

---

### Task 0.3: Add BTreeMap.Add and AddOrAssign (ITreeMap parity)

**Problem:** ITreeMap requires `Add` (insert-only, returns Boolean) and `AddOrAssign`. BTreeMap only has `Put`.

**Files:**
- Modify: `src/nextpas.core.collections.btree.pas`
- Test: `tests/nextpas.core.collections/test_btreemap/test_btreemap.lpr`

**Step 1: Add methods**
```pascal
function Add(const AKey: K; const AValue: V): Boolean;
function AddOrAssign(const AKey: K; const AValue: V): Boolean;
```

Implementation:
```pascal
function TBTreeMap.Add(const AKey: K; const AValue: V): Boolean;
begin
  if ContainsKey(AKey) then Exit(False);
  Put(AKey, AValue);
  Result := True;
end;

function TBTreeMap.AddOrAssign(const AKey: K; const AValue: V): Boolean;
var LOldCount: SizeUInt;
begin
  LOldCount := FCount;
  Put(AKey, AValue);
  Result := FCount > LOldCount;
end;
```

**Step 2: Test + Commit**

---

## Phase 1: Interface Definitions

### Task 1.1: Define IBTreeMap<K,V> interface

**Files:**
- Create: `src/nextpas.core.collections.btree.intf.pas`

```pascal
unit nextpas.core.collections.btree.intf;
interface
uses
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.treemap.base;

type
  generic IBTreeMap<K, V> = interface(specialize IGenericCollection<specialize TMapEntry<K, V>>)
  ['{...GUID...}']
    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    function Add(const AKey: K; const AValue: V): Boolean;
    function AddOrAssign(const AKey: K; const AValue: V): Boolean;
    procedure Put(const AKey: K; const AValue: V);
    function Get(const AKey: K): V;
    function Remove(const AKey: K): Boolean;
    procedure Clear;

    // Ordered operations
    function LowerBound(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
    function UpperBound(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
    function Floor(const AKey: K; out AFoundKey: K; out AValue: V): Boolean;
    function Min(out AKey: K; out AValue: V): Boolean;
    function Max(out AKey: K; out AValue: V): Boolean;
    function PopMin(out AKey: K; out AValue: V): Boolean;
    function PopMax(out AKey: K; out AValue: V): Boolean;

    // Order-statistic (B-tree specific)
    function Rank(const AKey: K): SizeUInt;
    function Select(ARank: SizeUInt; out AKey: K; out AValue: V): Boolean;

    // Traversal
    procedure ForEach(ACallback: specialize TKeyValueCallback<K, V>);
    procedure Range(const ALo, AHi: K; ACallback: specialize TKeyValueCallback<K, V>);

    function GetCount: SizeUInt;
    function IsEmpty: Boolean;
    property Count: SizeUInt read GetCount;
  end;
```

### Task 1.2: Define IConcurrentMap<K,V> interface

**Files:**
- Create: `src/nextpas.core.collections.concurrent.map.intf.pas`

```pascal
generic IConcurrentMap<K, V> = interface
['{...GUID...}']
  function TryGetValue(const AKey: K; out AValue: V): Boolean;
  function ContainsKey(const AKey: K): Boolean;
  procedure Put(const AKey: K; const AValue: V);
  function PutIfAbsent(const AKey: K; const AValue: V): Boolean;
  function Remove(const AKey: K): Boolean;
  function GetOrInsert(const AKey: K; const ADefault: V): V;
  procedure Clear;
  function GetCount: SizeUInt;
  function IsEmpty: Boolean;
  property Count: SizeUInt read GetCount;
end;
```

### Task 1.3: Define IBTreeSet<T> interface

**Files:**
- Create: `src/nextpas.core.collections.btree.set.intf.pas`

---

## Phase 2: Make TBTreeMap implement IBTreeMap

### Task 2.1: TBTreeMap inherits TGenericCollection + implements IBTreeMap

This requires:
- Change class declaration to inherit TGenericCollection
- Implement DoIterMoveNext/DoIterGetCurrent/DoIterReset
- Implement all IBTreeMap methods (most already exist)
- Adjust ForEach callback signature to match TKeyValueCallback

### Task 2.2: Full test suite for IBTreeMap contract

Every method in IBTreeMap gets at least one test. Target: 25+ tests.

---

## Phase 3: TSwissHashMap adapter

### Task 3.1: Create TSwissHashMap<K,V> implementing IHashMap

Wraps TSwissTable internally. Inherits TGenericCollection for iteration.

### Task 3.2: Add MakeSwissHashMap to facade

### Task 3.3: Run existing IHashMap contract tests against TSwissHashMap

---

## Phase 4: Naming standardization + API gaps

### Task 4.1: Standardize bound semantics
- LowerBound = first key >= query (C++ STL)
- UpperBound = first key > query
- Floor = last key <= query
- Ceiling = alias of LowerBound

### Task 4.2: Fill SwissTable API gaps
- Add, Reserve, GetOrInsert, GetOrInsertWith, ModifyOrInsert

### Task 4.3: Fill ConcurrentHashMap API gaps
- TryUpdate/Replace, ComputeIfAbsent, ComputeIfPresent

---

## Phase 5: Full test coverage + benchmark

### Task 5.1: BTreeSet independent test suite (15+ tests)
### Task 5.2: ConcurrentHashMap full API test suite (15+ tests)
### Task 5.3: SwissTable full API test suite (15+ tests)
### Task 5.4: Final benchmark round (FPC RTL / Go / Rust)

---

## Execution Order

```
P0.1 → P0.2 → P0.3 → commit "fix: critical bugs"
P1.1 → P1.2 → P1.3 → commit "feat: interface definitions"
P2.1 → P2.2 → commit "feat: BTreeMap implements IBTreeMap"
P3.1 → P3.2 → P3.3 → commit "feat: TSwissHashMap adapter"
P4.1 → P4.2 → P4.3 → commit "refactor: naming + API gaps"
P5.1 → P5.2 → P5.3 → P5.4 → commit "test: full coverage + benchmark"
```

## Verification Gate (each phase)

- All tests pass: `find tests/ -name "test_*" -executable -exec {} \; | grep "0 failed"`
- Zero leaks: all heaptrc reports `0 unfreed memory blocks`
- No regression: existing 398 tests still pass
