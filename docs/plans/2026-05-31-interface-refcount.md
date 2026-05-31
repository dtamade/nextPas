# Interface Reference Counting — Phase 1 Implementation Plan

> **Goal:** Automatic AddRef/Release for interface variables. When refcount reaches 0, free the object.

## Architecture (from Codex review)

- Object header: `[size:8][magic:8][refcount:8][obj...]` (obj = raw + 24)
- `np_intf_addref(ptr %obj)`: if non-null, increment refcount
- `np_intf_release(ptr %obj)`: decrement, if 0 call free
- Interface var has shadow `$obj` alloca for refcount tracking
- Sema emits `intf-addref-runtime` / `intf-release-runtime` HIR nodes
- HIR builder inserts release at function epilog

## Implementation Steps

### Step 1: Modify object header (emitter)
- `np_object_alloc`: change +16 to +24, init refcount=0 at offset 16
- Object pointer = raw + 24 (was raw + 16)

### Step 2: Add runtime helpers (emitter)
- `np_intf_addref`: load refcount at obj-8, increment, store
- `np_intf_release`: load refcount at obj-8, decrement, if 0 free

### Step 3: Sema changes
- After intf-adjust-runtime, emit intf-addref-runtime
- Track interface local vars for scope-exit release

### Step 4: HIR builder
- Process intf-addref-runtime / intf-release-runtime nodes
- Function epilog: release all interface locals

### Step 5: Tests
- Basic interface refcount (create + use + exit)
- Reassignment (old released, new addref'd)
- nil assignment (release)

## Risk: Header size change breaks all 96 tests
Mitigation: Only np_object_alloc offset changes. All field access uses
slot indices relative to obj pointer, which remains stable.
