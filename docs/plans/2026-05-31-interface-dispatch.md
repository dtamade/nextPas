# Interface Polymorphic Dispatch Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement COM-compatible interface dispatch for nextPas LLVM backend — enabling polymorphic interface method calls, `as`/`is` type queries, and interface variable semantics.

**Architecture:** Full COM-compatible approach (FPC/Delphi style). Interface variables are pointer-sized, pointing to an interface slot inside the object. Each slot holds a pointer to a static Interface Method Table (IMT). Method calls go through thunks that adjust `self` from interface-slot-pointer back to object base, then tail-call the real method. ITable enables runtime `is`/`as` queries.

**Tech Stack:** Pascal (compiler), LLVM IR (output), freestanding x86_64

---

## Memory Layout

```
Object instance:
┌──────────────────────────────────────────────┐
│ slot[0]: VMT pointer                         │
│ slot[1..N]: fields                           │
│ slot[N+1]: intf_slot_0 → @Class_IMT_IFoo    │
│ slot[N+2]: intf_slot_1 → @Class_IMT_IBar    │
└──────────────────────────────────────────────┘

Interface variable = ptr to intf_slot_N (inside object)

Method call: intf_var → load IMT ptr → load fn[index] → call fn(intf_var)
Thunk: sub self, offset → tail call real_method(adjusted_self)
```

## Phase 1: Polymorphic Interface Dispatch (7 tasks)

### Task 1: Extend TypeMetadata for Interface Slot Offsets

Register interface slot offsets in class metadata so HIR builder knows where each interface's slot lives in the object layout.

### Task 2: Generate Static IMT Globals

For each (class, interface) pair, emit a constant array of function pointers (thunks) as a global in LLVM IR.

### Task 3: Generate Thunk Functions

For each (class, interface, method) triple, emit a thunk function that adjusts `self` and tail-calls the real implementation.

### Task 4: Initialize Interface Slots in Constructor

After object allocation, store IMT pointers into the interface slots.

### Task 5: Emit Class-to-Interface Conversion

When assigning a class variable to an interface variable, emit a GEP to the interface slot.

### Task 6: Emit Interface Method Call via IMT

Replace direct interface method calls with load-load-call pattern through the IMT.

### Task 7: Implement `is`/`as` for Interfaces

Add ITable to class metadata, implement runtime `is` check and `as` cast.

---

## Phase 2: Reference Counting (deferred)

- AddRef/Release in interface assignment
- _Release in interface variable scope exit
- IInterface/IUnknown base methods

## Phase 3: Interface Delegation (deferred)

- `implements` keyword
- Delegating interface methods to a field

---

## Design Decisions (from Codex review)

1. **Interface slots after fields** — offset is class-specific, matches FPC
2. **Thunks use `musttail call`** — compiles to `sub + jmp`, zero overhead
3. **Interface inheritance** — IBar extends IFoo: one IMT slot satisfies both, ITable has entries for both IIDs pointing to same offset
4. **Performance** — interface call = 2 loads + indirect call (same as C++ virtual through base)
5. **No libc dependency** — all runtime helpers are freestanding LLVM IR
