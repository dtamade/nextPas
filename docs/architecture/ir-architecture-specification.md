---
title: nextPas IR Architecture Specification
version: 0.1.0
status: draft
date: 2026-05-20
---

# nextPas IR Architecture Specification

## 1. Vision

nextPas aims to be one of the best compilers in the Object Pascal ecosystem.
The IR architecture is the foundation that enables:

- **Correctness**: Every transformation preserves program semantics
- **Performance**: Standard optimization passes (DCE, CSE, LICM, devirtualization)
- **Extensibility**: New language features don't require pipeline rewrites
- **Compilation speed**: Incremental compilation at function granularity
- **Diagnostics**: Rich error messages with source location tracking

## 2. Pipeline Overview

```
Source → Lexer → GreenCST → AST Facade → Sema
                                            ↓
                                    HIR (Typed SSA CFG)
                                            ↓
                                    [HIR Passes: const fold, devirt, generic mono]
                                            ↓
                                    MIR (Erased SSA CFG)
                                            ↓
                                    [MIR Passes: DCE, CSE, LICM, refcount insert]
                                            ↓
                                    LLVM IR Emission
                                            ↓
                                    opt → llc → ld → executable
```

## 3. HIR: High-Level Intermediate Representation

### 3.1 Purpose

HIR is the **canonical representation of Pascal semantics**. It preserves:
- Full type information (classes, interfaces, generics, variant records)
- Source location for every operation
- Ownership/lifetime annotations for managed types
- Exception flow (exceptional edges to landingpads)

### 3.2 Structure

HIR is a **typed SSA CFG** (not a tree). Each function is a graph of basic blocks.
Each basic block contains a sequence of instructions ending with a terminator.

```pascal
THIRModule = class
  Functions: array of THIRFunction;
  Types: THIRTypeTable;
  Globals: array of THIRGlobal;
  Constants: array of THIRConstant;
end;

THIRFunction = class
  Name: string;
  Signature: THIRFuncType;
  Blocks: array of THIRBlock;
  EntryBlock: THIRBlockId;
  Params: array of THIRParam;
end;

THIRBlock = class
  Id: THIRBlockId;
  Instrs: array of THIRInstr;
  Terminator: THIRTerminator;
  Preds: array of THIRBlockId;
  Succs: array of THIRBlockId;
end;
```

### 3.3 Instructions

Instructions are **structured records**, not strings. Each instruction:
- Has a unique result value (SSA)
- Has typed operands (references to other values)
- Has source location metadata
- Knows its parent block

```pascal
THIRInstrKind = (
  // Memory
  hikAlloca,          // %v = alloca T
  hikLoad,            // %v = load T, ptr %addr
  hikStore,           // store T %val, ptr %addr
  hikGetFieldPtr,     // %v = getfieldptr %base, field_index

  // Arithmetic
  hikAdd, hikSub, hikMul, hikDiv, hikMod,
  hikNeg, hikNot,
  hikAnd, hikOr, hikXor, hikShl, hikShr,

  // Comparison
  hikCmpEq, hikCmpNe, hikCmpLt, hikCmpLe, hikCmpGt, hikCmpGe,

  // Conversion
  hikTrunc, hikZext, hikSext, hikBitcast,
  hikIntToFloat, hikFloatToInt,

  // Calls
  hikCall,            // %v = call @func(args...)
  hikVirtCall,        // %v = vcall %obj, vtable_index(args...)
  hikIntfCall,        // %v = intfcall %intf, method_index(args...)
  hikIntrinsic,       // %v = intrinsic @name(args...)

  // Aggregate
  hikInsertField,     // %v = insertfield %agg, field_index, %val
  hikExtractField,    // %v = extractfield %agg, field_index

  // Pascal-specific intrinsics (lowered to MIR calls)
  hikStrConcat,       // %v = str_concat %a, %b
  hikStrLength,       // %v = str_length %s
  hikDynArrayResize,  // dynarray_resize %arr, %newlen
  hikRefCountInc,     // refcount_inc %obj
  hikRefCountDec,     // refcount_dec %obj
  hikClassCreate,     // %v = class_create T
  hikClassDestroy,    // class_destroy %obj

  // Phi
  hikPhi              // %v = phi [%v1, %bb1], [%v2, %bb2], ...
);

THIRTerminatorKind = (
  htkReturn,          // return %val  |  return void
  htkBranch,          // br %bb
  htkCondBranch,      // br %cond, %then_bb, %else_bb
  htkSwitch,          // switch %val, [cases...], %default_bb
  htkUnreachable,     // unreachable
  htkInvoke,          // invoke @func(...) to %normal unwind %except
  htkResume           // resume %exception
);
```

### 3.4 Type System

```pascal
THIRTypeKind = (
  // Scalars
  htkBool,
  htkInt,             // parameterized: bit_width + signed
  htkFloat,           // f32, f64, f80
  htkChar,            // ansi (1 byte) or wide (2 bytes)

  // Composite
  htkArray,           // static array: [Low..High] of ElemType
  htkDynArray,        // dynamic array: runtime-managed
  htkString,          // ShortString | AnsiString | UnicodeString
  htkSet,             // set of ordinal
  htkRecord,          // record with fields
  htkVariantRecord,   // record with variant part

  // OOP
  htkClass,           // class with VMT
  htkInterface,       // COM-style interface
  htkClassRef,        // class of T

  // Callable
  htkFunc,            // function/procedure type
  htkMethodRef,       // method reference / closure

  // Pointer
  htkPointer,         // ^T
  htkUntypedPtr,      // Pointer

  // Special
  htkVoid,
  htkGenericParam     // unresolved generic (pre-monomorphization only)
);
```

### 3.5 Key Invariants

1. **Type completeness**: Every value has a resolved HIR type
2. **SSA dominance**: Every use is dominated by its definition
3. **Scope correctness**: Variable lifetimes don't escape their scope region
4. **Exception edges**: Every potentially-throwing op has exceptional successor
5. **No unresolved generics**: All generics monomorphized before HIR emission

## 4. MIR: Machine-Level Intermediate Representation

### 4.1 Purpose

MIR is the **optimization workhorse**. It:
- Erases Pascal-specific semantics (no classes, no interfaces)
- Preserves only machine-relevant type information
- Is the target for standard optimization passes
- Translates directly to LLVM IR

### 4.2 Type System (Minimal)

```pascal
TMIRTypeKind = (
  mtkVoid,
  mtkInt,             // i1, i8, i16, i32, i64
  mtkFloat,           // f32, f64, f80
  mtkPtr,             // opaque pointer (matches LLVM opaque ptr)
  mtkStruct,          // {field1, field2, ...} — flat memory layout
  mtkArray            // [N x T] — fixed-size array
);
```

### 4.3 Operations

MIR operations are **three-address code** in strict SSA form:

```pascal
TMIROpKind = (
  // Memory
  mokAlloca, mokLoad, mokStore, mokGEP,
  mokMemcpy, mokMemset,

  // Arithmetic (integer)
  mokAdd, mokSub, mokMul, mokSDiv, mokUDiv, mokSRem, mokURem,
  mokAnd, mokOr, mokXor, mokShl, mokLShr, mokAShr,

  // Arithmetic (float)
  mokFAdd, mokFSub, mokFMul, mokFDiv,

  // Comparison
  mokICmp, mokFCmp,

  // Conversion
  mokTrunc, mokZExt, mokSExt, mokBitcast,
  mokSIToFP, mokFPToSI, mokPtrToInt, mokIntToPtr,

  // Aggregate
  mokInsertValue, mokExtractValue,

  // Call
  mokCall, mokIndirectCall,

  // Phi
  mokPhi
);

TMIRTermKind = (
  mtkRet, mtkBr, mtkCondBr, mtkSwitch,
  mtkUnreachable, mtkInvoke, mtkResume
);
```

### 4.4 Key Invariants

1. **Strict SSA**: Each virtual register defined exactly once
2. **Type consistency**: Operand types match operator expectations
3. **CFG completeness**: Every block ends with terminator, no fall-through
4. **Explicit memory**: All memory access through load/store
5. **ABI correctness**: Call arguments match target calling convention

## 5. HIR → MIR Lowering

The lowering pass transforms Pascal semantics into machine operations:

| HIR Concept | MIR Expansion |
|-------------|---------------|
| Virtual method call | Load VMT ptr → GEP to slot → indirect call |
| Interface call | Load intf table → GEP to slot → indirect call |
| String concat | Call @np_str_concat intrinsic |
| Dynamic array resize | Call @np_dynarray_resize intrinsic |
| Exception try/except | Invoke + landingpad + resume |
| Class creation | Call @np_object_alloc → call constructor |
| Refcount inc/dec | Call @np_refcount_inc / @np_refcount_dec |
| Record copy | Memcpy or field-by-field copy |
| Set operations | Bitwise AND/OR/XOR on integer bitmask |

## 6. Optimization Passes

### HIR-Level Passes (Pascal-aware)
- Constant folding (integer, string, set)
- Devirtualization (when class type is known)
- Generic monomorphization
- Inline expansion (small functions)
- Dead code elimination (unreachable branches)

### MIR-Level Passes (Target-independent)
- Dead code elimination (unused values)
- Common subexpression elimination
- Loop invariant code motion
- Refcount insertion and elision
- Tail call optimization
- Strength reduction

## 7. Migration Plan

### Phase 1: Define HIR Data Structures
- Implement THIRModule, THIRFunction, THIRBlock, THIRInstr
- Implement HIR type system
- Write HIR printer (textual representation)
- Write HIR verifier
- **Gate**: HIR structures compile, printer produces readable output

### Phase 2: HIR Emission from Sema
- Sema emits HIR instead of flat TypedHIR array
- Adapter layer converts HIR → old MIR format
- Move constant folding to HIR pass
- **Gate**: All 16 existing LLVM gate tests pass via adapter

### Phase 3: New MIR + LLVM Emitter
- Implement new MIR with proper types and SSA
- Write HIR → MIR lowering
- Write MIR → LLVM IR emitter
- Run new and old paths in parallel, diff outputs
- **Gate**: New path produces semantically equivalent LLVM IR

### Phase 4: Remove Legacy Path
- Delete old TypedHIR, old MIR, old codegen
- Add optimization passes on new MIR
- **Gate**: All tests pass on new path, old code deleted

## 8. Design Principles

1. **Structured over strings**: No string-encoded operation arguments
2. **Types are first-class**: Every value carries type information
3. **Passes are composable**: Each pass has clear input/output contract
4. **Verification is cheap**: O(n) verifier runs after every pass in debug
5. **Metadata is separate**: Source locations in side tables, not in IR nodes
6. **Use-def chains**: Every value knows its users (enables trivial DCE)
7. **Intrinsics over special nodes**: Runtime operations are intrinsic calls
