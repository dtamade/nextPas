# Compiler Sprint Plan

```
PROJECT:   nextPas Compiler Improvement
DATE:      2026-07-05
VERSION:   1.0
ROLE:      AI-readable execution plan for compiler developers
STATUS:    Ready for Sprint 1
```

---

## 0. QUICK REFERENCE

### Gate Commands
```bash
make test TEST_FILTER=compiler-pass     # MUST PASS: 34/34
make test TEST_FILTER=compiler-fail     # MUST MATCH snapshot
make hygiene                             # no stray artifacts
scripts/rebuild-compiler.sh             # MUST succeed
```

### Key Files
| File | Lines | Role |
|------|-------|------|
| `compiler/sema/np_semantic_analyzer.pas` | 12,255 | GOD CLASS — 279 methods, main target |
| `compiler/ir/np_hir_builder.pas` | 7,092 | HIR construction (passive) |
| `compiler/syntax/np_green_tree.pas` | 5,379 | AST data structure |
| `compiler/sema/np_semantic_model.pas` | 1,526 | Symbol table, type table |
| `compiler/frontend/np_compilation_session.pas` | 2,554 | Compilation entry point |

### Stdlib Modules Available (compiler does NOT use them yet)
| Module | Provides | Replaces |
|--------|----------|----------|
| `nextpas.core.collections.hashmap` | `THashMap<K,V>` | `array of T` + `SameText` O(n) lookup |
| `nextpas.core.collections.vec` | `TVec<T>` | `array of T` + `SetLength+1` |
| `nextpas.core.mem.arena` | `TFastArena` (64.8ns/alloc) | `TGreenNode = class` heap allocation |
| `nextpas.core.text.view` | `TStringView` | string copy in comparisons |

### Current Metrics
| Metric | Value |
|--------|-------|
| Production LOC | 49,667 (31 files) |
| Test LOC | 10,289 (29 files) |
| `SameText` calls | 647 |
| `for` loops on arrays | 404 |
| `SetLength +1` sites | 145 |
| String concatenations | 1,125 |
| Test/production ratio | 0.21x |

---

## 1. COMPILER PIPELINE (how it works today)

```
INPUT: Source File (.pas)
  │
  ├─[1] LEXER: np_lexer.pas (1,679 lines)
  │     TLexerResult.LexSource → array of TToken
  │
  ├─[2] PREPROCESSOR: np_preprocessor.pas (835 lines)
  │     TPreprocessor.EmitToken → filters {$IFDEF} blocks
  │     TDefineTable.IndexOf: O(n) per lookup  ← PROBLEM
  │
  ├─[3] GREEN TREE PARSER: np_green_tree.pas (5,379 lines)
  │     TGreenNode = class  ← heap alloc per token ← PROBLEM
  │     TGreenTree → TAstFacade (189 lines)
  │
  ├─[4] UNIT RESOLVER: np_unit_resolver.pas (855 lines)
  │     Builds dependency graph → topological sort (Kahn)
  │
  ├─[5] SEMANTIC ANALYZER: np_semantic_analyzer.pas (12,255 lines) ← GOD CLASS
  │     TSemanticAnalyzer.Analyze:
  │       WalkDeclarations       → type/symbol registration
  │       WalkAssignmentStatements→ procedure body analysis
  │       WalkHaltCalls          → exit point analysis
  │       SeedFunctionBodies     → codegen entry
  │       PreRegisterFunctionReturnTypes
  │       SeedUnitLifecycleBodies
  │     All lookups: O(n) SameText  ← PROBLEM
  │     All arrays: SetLength+1     ← PROBLEM
  │
  ├─[6] HIR BUILDER: np_hir_builder.pas (7,092 lines)
  │     THIRBuilder.Build  ← ONLY runs if NEXTPAS_HIR_DUMP=1 ← PROBLEM
  │     Blob* methods: 284 calls (suspected legacy)
  │
  ├─[7] LLVM EMITTER: np_hir_llvm_emitter.pas (1,856 lines)
  │     String concatenation to emit LLVM IR  ← PROBLEM
  │
  ├─[8] BACKEND PLAN: np_backend_plan.pas (636 lines)
  │     Metadata only, no codegen logic
  │
  └─[9] TOOLCHAIN: np_toolchain_*.pas
        External clang/linker invocation
```

---

## 2. SPRINT 1: STDLIB ADOPTION (5 days)

### GOAL
Replace hand-rolled data structures with stdlib equivalents.
**No architecture changes. Each change is independent and revertible.**

---

### S1.1 — Replace O(n) lookups with THashMap (Day 1)

**FILE**: `compiler/sema/np_semantic_model.pas`

**CURRENT STATE** — every lookup is O(n):
```
Line 1076: function TSemanticModel.FindTypeByName      → for I:=0 to Length(FTypes)-1 do SameText(...)
Line 1086: function TSemanticModel.FindSymbolByName     → for I:=0 to Length(FSymbols)-1 do SameText(...)
Line 1272: function TSemanticModel.LookupConstValue    → for I:=0 to Length(FConstValues)-1 do SameText(...)
Line 1396: function TSemanticModel.GetTypeMetaByName   → for I:=0 to Length(FTypeMeta)-1 do SameText(...)
Line 1410: function TSemanticModel.GetFieldMetaByName  → for I.. for J.. do SameText(...)  [O(n×m)]
Line 1429: function TSemanticModel.GetVmtSlotByName    → for I.. for J.. do SameText(...)  [O(n×m)]
```

**TARGET STATE**:
```pascal
// Add to implementation uses:
uses nextpas.core.collections.hashmap;

// Add fields to TSemanticModel:
FTypeIndex: THashMap<string, LongInt>;      // name → TypeId
FSymbolIndex: THashMap<string, LongInt>;    // name → SymbolId
FConstIndex: THashMap<string, Int64>;       // name → value
FTypeMetaIndex: THashMap<string, LongInt>;  // name → index into FTypeMetadataEntries

// Rewrite lookups:
function TSemanticModel.FindTypeByName(const AName: string): LongInt;
begin
  if not FTypeIndex.TryGetValue(AName, Result) then
    Result := 0;
end;
```

**VALIDATION**:
```bash
make test TEST_FILTER=compiler-pass   # MUST: 34/34
```

**RISK**: LOW. Interface unchanged. Only implementation changes.

---

### S1.2 — Replace SetLength+1 with TVec (Day 2)

**FILES**: `compiler/sema/np_semantic_analyzer.pas`, `compiler/ir/np_hir_builder.pas`

**CURRENT STATE** — 145 sites of `SetLength(arr, Length(arr)+1)`:
```
sema/np_semantic_analyzer.pas:
  Line 662:  SetLength(AItems, NextIndex + 1);
  Line 1171: SetLength(FProcedureBodies, NextIndex + 1);
  Line 2381: SetLength(SeenTypeIds, Length(SeenTypeIds) + 1);
  Line 3082: SetLength(ACandidates, Length(ACandidates) + 1);
  Line 3632: SetLength(Result, Length(Result) + 1);
  Line 4060: SetLength(FInliningStack, NextIndex + 1);
  Line 6466: SetLength(Meta.Fields, Length(Meta.Fields) + 1);
  Line 6613: SetLength(Meta.VmtSlots, Meta.VmtCount + 1);
  ... (25 sites in sema alone)

ir/np_hir_builder.pas:
  Line 318:  SetLength(Values, Count + 16);   // already uses growth factor!
  Line 1574: SetLength(Instr.Operands, Length(...) + 1);
  ... (16 sites)
```

**TARGET STATE**:
```pascal
uses nextpas.core.collections.vec;

// Before:
var FProcedureBodies: array of TProcedureBodyEntry;
SetLength(FProcedureBodies, Length(FProcedureBodies) + 1);
FProcedureBodies[High(FProcedureBodies)].Name := AName;

// After:
var FProcedureBodies: TVec<TProcedureBodyEntry>;
FProcedureBodies.Add(Entry);  // capacity doubles internally
```

**PRIORITY ORDER** (replace most-frequently-grown first):
1. `FProcedureBodies` — grows once per procedure
2. `Meta.Fields` — grows once per class field
3. `Meta.VmtSlots` — grows once per virtual method
4. `FBlockNames` / `FBlockIds` — grows once per basic block

**VALIDATION**:
```bash
make test TEST_FILTER=compiler-pass
scripts/rebuild-compiler.sh
```

**RISK**: LOW. TVec has similar interface to dynamic array. Main change: `arr[I]` stays, `SetLength(arr, N)` becomes `arr.Reserve(N)` or removed.

---

### S1.3 — Green Tree Arena Allocation (Day 3-4)

**FILE**: `compiler/syntax/np_green_tree.pas`

**CURRENT STATE**:
```pascal
TGreenNode = class        // heap allocation per AST node
  FNodeKind: TGreenNodeKind;
  FText: string;
  FChildren: array of TGreenNode;
end;
```
Medium source file (5000 tokens) → 5000 × `TGreenNode.Create` → 5000 heap allocations.

**TARGET STATE**:
```pascal
uses nextpas.core.mem.arena;

TGreenTree = class
private
  FArena: IArena;          // all nodes allocated here
  FRootNode: TGreenNode;
public
  constructor Create;
  destructor Destroy;      // FArena.Reset → all nodes freed at once
end;
```

**OPTION A** (simpler): Keep `TGreenNode = class` but override `NewInstance` to use Arena.
**OPTION B** (cleaner): Convert `TGreenNode` to `record` with arena-backed dynamic arrays.

**VALIDATION**:
```bash
make test TEST_FILTER=compiler-pass
heaptrc ./build/stage2-test/nextpas build <test_file>
# EXPECT: heap allocations drop from 5000+ to ~10
```

**RISK**: MEDIUM. If too complex, skip S1.3. S1.1+S1.2 already deliver significant improvement.

---

### S1.4 — Measure & Document (Day 5)

```bash
# BEFORE/AFTER comparison
echo "=== BEFORE ===" > sprint1_bench.txt
time scripts/rebuild-compiler.sh >> sprint1_bench.txt 2>&1

# ... apply S1.1-S1.3 ...

echo "=== AFTER ===" >> sprint1_bench.txt
time scripts/rebuild-compiler.sh >> sprint1_bench.txt 2>&1

# Memory
heaptrc ./build/stage2-test/nextpas build <large_module>
```

**SPRINT 1 DONE CHECKLIST**:
- [ ] `make test TEST_FILTER=compiler-pass` → 34/34
- [ ] `make test TEST_FILTER=compiler-fail` → snapshot matches
- [ ] `scripts/rebuild-compiler.sh` → succeeds
- [ ] `make hygiene` → clean
- [ ] Update `docs/plans/debt-roadmap.md` — mark completed items
- [ ] Update `docs/plans/goal-tree.md` — add progress entry

---

## 3. SPRINT 2: SEMA SPLIT (10 days)

### GOAL
Break `TSemanticAnalyzer` (279 methods, 12,255 lines) into 5-6 independent modules.
**Move code only. Zero behavior changes.**

### TSemanticAnalyzer Field Map (grouped by responsibility)

```
CATEGORY: COMPILATION STATE (6 fields)
  FRootAst, FUnitGraph, FDiagnostics, FRootFileId, FNoFold, FModel

CATEGORY: PROCEDURE BODIES (4 fields)
  FProcedureBodies, FCompilerProcNames, FCompilerProcCount, FPendingSignatures

CATEGORY: STRING OWNERSHIP (15 fields)
  FRuntimeStrVarNames, FOwnedRuntimeStrVarNames, FBorrowedRuntimeStrVarNames,
  FOwnedStringReturnFuncNames, FPendingStringTempNames, FPendingStringTempSources,
  FCurrentRetVarName, FCurrentOwnedStringReturn, ...

CATEGORY: TYPE/VARIABLE REGISTRY (12 fields)
  FClassVarNames, FClassVarTypes, FRecordVarNames, FRecordVarTypes,
  FPointerVarNames, FPointerVarTypes, FVarParamNames, FPtrReturnFuncs,
  FPtrReturnTypes, FManagedRecordVarNames, FManagedRecordVarTypes, ...

CATEGORY: GENERICS (5 fields)
  FGenericWorkQueue, FGenericWorkCount, FGenericCacheKeys, FGenericCacheTypeIds, ...

CATEGORY: CODE GENERATION (8 fields)
  FRuntimeVarNames, FRuntimeArrVarNames, FBorrowedRuntimeArrVarNames,
  FBlockLabelCounter, FCurrentBlockTerminated, FBreakLabels, FContinueLabels, ...

CATEGORY: BUILTINS (2 fields)
  FBuiltinProcedures, FImportedUnitTrees, FImportedUnitOwners
```

### Split Sequence

```
S2.1 (0.5d) → np_sema_builtins        (~500 lines)  RISK: VERY LOW
S2.2 (1.0d) → np_sema_string_ownership (~2000 lines) RISK: LOW
S2.3 (2.0d) → np_sema_overload        (~1500 lines) RISK: MEDIUM
S2.4 (3.0d) → np_sema_hir_lowering    (~3000 lines) RISK: MEDIUM
S2.5 (2.0d) → np_sema_type_check      (~1500 lines) RISK: HIGH
S2.6 (1.5d) → np_semantic_analyzer    (~3700 lines) RISK: MEDIUM (remaining)
```

---

### S2.1 — Extract Builtins Registry (0.5 day)

**TARGET**: Create `compiler/sema/np_sema_builtins.pas`

**WHAT TO MOVE**:
```
Current location: np_semantic_analyzer.pas
  Field:  FBuiltinProcedures: TNameSet;
  Method: IsBuiltinProcedure (uses FBuiltinProcedures)
  Registration: SeedFunctionBodies contains ~150 NameSetAdd calls
```

**TARGET**:
```pascal
unit np_sema_builtins;

interface
uses np_sema_name_set;

type
  TBuiltinRegistry = class
  private
    FNames: TNameSet;
  public
    constructor Create;
    function IsBuiltin(const AName: string): Boolean;
  end;

implementation
constructor TBuiltinRegistry.Create;
begin
  FNames := TNameSet.Create;
  // Move all 150+ NameSetAdd calls here
  NameSetAdd(FNames, 'Write');
  NameSetAdd(FNames, 'WriteLn');
  // ...
end;
```

**VALIDATION**: `make test TEST_FILTER=compiler-pass` → 34/34

---

### S2.2 — Extract String Ownership (1 day)

**TARGET**: Create `compiler/sema/np_sema_string_ownership.pas`

**CURRENT**: `np_sema_string_ops.inc` (2,243 lines) is included into TSemanticAnalyzer. Shares all 60+ fields.

**WHAT TO MOVE**:
```
Fields (15):
  FRuntimeStrVarNames, FOwnedRuntimeStrVarNames, FBorrowedRuntimeStrVarNames,
  FOwnedStringReturnFuncNames, FPendingStringTempNames, FPendingStringTempSources,
  FCurrentRetVarName, FCurrentOwnedStringReturn, ...

Methods (~50):
  RegisterOwnedRuntimeStrVar, IsOwnedRuntimeStrVar, IsOwnedStringReturnFunc,
  DeclReturnsString, FunctionCallReturnsString, AssignmentOwnsStringReturn,
  CallArgumentOwnsStringReturn, ScanOwnedStringReturnConsumers,
  EmitOwnedStringWriteTemp, ... (all string ownership methods)
```

**TARGET**:
```pascal
unit np_sema_string_ownership;

type
  TStringOwnershipAnalyzer = class
  private
    // 15 fields moved here
  public
    procedure ScanOwnedStringReturnConsumers(...);
    function AssignmentOwnsStringReturn(...): Boolean;
    // ... all 50 methods
  end;
```

**VALIDATION**: `make test TEST_FILTER=compiler-pass` → 34/34

---

### S2.3 — Extract Overload Resolution (2 days)

**TARGET**: Create `compiler/sema/np_sema_overload.pas`

**CURRENT**: `LookupCallBindingDeclaration` is the most complex single method in sema. Contains 14 `{ Permissive: ... }` compromises.

**WHAT TO MOVE**:
```
Methods:
  LookupCallBindingDeclaration (line 1280, ~470 lines)
  LookupOverload (line 1262)
  HasOverload (line 1251)
  GetParamSignature (line 876)
  GetParamIdentitySignature (line 962)
  GetSubstitutedParamSignature (line 1004)
  DeclAcceptsArgCount (line 832)
  DeclParamSignatureMatchesArgs (line 843)
  ... related helper methods
```

**TARGET**:
```pascal
unit np_sema_overload;

type
  TOverloadResolver = class
  private
    FModel: TSemanticModel;
    FProcedureBodies: TVec<TProcedureBodyEntry>;  // from S1.2
  public
    function Resolve(const AName: string; AArgs: TTypeIdArray): TOverloadResult;
  end;
```

**BONUS**: Once extracted, `TOverloadResolver` can be unit-tested independently.

**VALIDATION**: `make test TEST_FILTER=compiler-pass` → 34/34

---

### S2.4 — Extract HIR Lowering (3 days)

**TARGET**: Create `compiler/sema/np_sema_hir_lowering.pas`

**CURRENT**: `np_sema_runtime_expr.inc` (3,345 lines) included into TSemanticAnalyzer.

**WHAT TO MOVE**:
```
Methods:
  BuildRuntimeScalarHirExpr
  BuildRuntimeArrayElementAddressHirExpr
  BuildRuntimeArrayElementHirExpr
  EncodeRuntimeIntExprFold
  BuildRecordBaseAddressExpr
  BuildClassBaseAddressExpr
  BuildClassFieldTargetExpr
  BuildTargetAddressExpr
  BuildByRefArgumentAddressExpr
  AttachStatementCallExpr
  LowerRuntimeIfStatement
  LowerRuntimeWhileStatement
  LowerRuntimeForStatement
  LowerRuntimeTryFinallyStatement
  ... (~40 methods)
```

**VALIDATION**: `make test TEST_FILTER=compiler-pass` → 34/34

---

### S2.5 — Extract Type Checking (2 days)

**TARGET**: Create `compiler/sema/np_sema_type_check.pas`

**WHAT TO MOVE**:
```
Methods:
  TypeIdForVariable
  TypeIdForMemberReceiver
  TryResolveTypeNameMemberCallTarget
  TypeSymbolForTypeId
  ClassTypeHasKnownNonMethodMember
  ResolveTypeId, ResolveTypeIdForOwner
  FindSymbolByName, FindSymbolByNameAndType
  TypeMetaSize, TypeMetaIsRecord, TypeMetaIsClass, TypeMetaIsInterface
  TypeMetaFieldIndex, TypeMetaFieldIsStr, TypeMetaFieldIsPtr
  TypeMetaVmtSlot, TypeMetaVmtCount
  TypeMetaParentClass
  TypeSignatureForTypeId
  ... (~30 methods)
```

**VALIDATION**: `make test TEST_FILTER=compiler-pass` → 34/34

---

### S2.6 — Clean Up Remaining (1.5 days)

After S2.1-S2.5, `np_semantic_analyzer.pas` contains ~3,700 lines of orchestration code:
- `Analyze` main loop
- `WalkDeclarations`, `WalkAssignmentStatements`, `WalkHaltCalls`
- `SeedFunctionBodies`, `SeedUnitLifecycleBodies`
- Remaining coordination methods

**TARGET SIZE**: <4,000 lines, <80 methods

**VALIDATION**: `make test TEST_FILTER=compiler-pass` + `scripts/rebuild-compiler.sh`

---

## 4. SPRINT 3: CAPABILITY COMPLETION (15 days)

### S3.1 — Clean Permissive Overload (3 days)

**DEPENDS ON**: S2.3 (overload resolver extracted)

**CURRENT**: 14 sites in `LookupCallBindingDeclaration`:
```
Line 1495: { Permissive: pick first exact match instead of failing }
Line 1502: { Permissive: pick first compatible match instead of failing }
Line 1531: { Permissive: pick first signature match instead of failing }
Line 1594: { Permissive: pick first direct import exact match }
Line 1613: { Permissive: pick first direct import compatible match }
Line 1704: { Permissive: pick first imported exact match }
Line 1711: { Permissive: pick first imported compatible match }
Line 1724: { Permissive: pick first imported signature match }
Line 3156: { Permissive: pick first exact match for method calls }
Line 3169: { Permissive: pick first compatible match for method calls }
Line 3235: { Permissive: pick first same-owner match }
Line 3290: { Permissive: pick first best match for method calls }
Line 3840: { Permissive: suppress ambiguous-overload errors for C8 pass }
Line 3947: { Permissive: suppress ambiguous-overload errors for C8 pass }
```

**TARGET**: Standard overload resolution:
1. Exact match → select
2. Type promotion match → select best
3. Multiple ambiguous candidates → report error (not pick first)

**VALIDATION**:
```bash
make test TEST_FILTER=compiler-pass   # existing must pass
make test TEST_FILTER=compiler-fail   # new ambiguous-overload errors expected
# C8 scan: any module that relied on permissive behavior will need fixes
```

---

### S3.2 — Incremental Compilation (5 days)

**DEPENDS ON**: S1.1 (THashMap in SemanticModel)

**PLAN**:
1. `TSemanticModel` → serialize to `.npb` binary cache file
2. Dependency fingerprint = `hash(source) + hash(all uses)`
3. Fingerprint match → load `.npb`, skip lex+parse+sema

**TARGET PERFORMANCE**:
| Scenario | Before | After |
|----------|--------|-------|
| 67 units, cold | 6.4s | 6.4s |
| 67 units, warm | 6.4s | **<1s** |
| 158 units, cold | 16s | 16s |
| 158 units, warm | 16s | **<3s** |

---

### S3.3 — HIR Optimization Passes (5 days)

**CURRENT**: HIR → LLVM IR is 1:1 translation. 0 optimization passes.

**PASSES TO ADD**:
1. **Constant Folding**: `Add(Const(1), Const(2))` → `Const(3)`
2. **Dead Block Elimination**: remove unreachable basic blocks
3. **Strength Reduction**: `Mul(X, Const(2))` → `Shl(X, Const(1))`

---

### S3.4 — Sema Unit Tests (2 days)

**DEPENDS ON**: S2.1-S2.5 (modules independently testable)

**CURRENT**: `np_semantic_analyzer.pas` (12,255 lines) has **0 direct unit tests**.

**TARGET**: Each extracted module gets ≥5 unit tests:
```
compiler/tests/
├── test_sema_builtins.pas          → ≥5 tests
├── test_sema_string_ownership.pas  → ≥5 tests
├── test_sema_overload.pas          → ≥10 tests (high value)
├── test_sema_hir_lowering.pas      → ≥5 tests
└── test_sema_type_check.pas        → ≥5 tests
```

---

## 5. PER-SPRINT CHECKLIST

Copy this block at the end of each sprint and check all items:

```markdown
## Sprint N Completion Checklist

### Gates
- [ ] `make test TEST_FILTER=compiler-pass` → 34/34
- [ ] `make test TEST_FILTER=compiler-fail` → snapshot matches
- [ ] `scripts/rebuild-compiler.sh` → succeeds
- [ ] `make hygiene` → clean

### Performance (compare to sprint start)
- [ ] `time scripts/rebuild-compiler.sh` recorded
- [ ] heaptrc report recorded (if Arena changes)

### Documentation
- [ ] `docs/plans/debt-roadmap.md` — mark completed items
- [ ] `docs/plans/goal-tree.md` — add progress entry
- [ ] `docs/plans/compiler-sprint-plan.md` — update status

### Git
- [ ] All changes committed with descriptive messages
- [ ] `git log --oneline -5` reviewed
```

---

## 6. RISK MITIGATION

| Risk | Probability | Impact | Mitigation |
|------|-----------|--------|------------|
| S1.3 Arena too complex | Medium | Low | Skip S1.3, S1.1+S1.2 sufficient |
| S2 split introduces bugs | Medium | High | Each step runs full gate; git bisect if needed |
| THashMap slower than array for small N | Low | Medium | Benchmark; keep array for N<20 if needed |
| Permissive cleanup breaks modules | High | Medium | C8 scan first, quantify impact, fix incrementally |
| Stdlib API changes during sprint | Low | High | Pin stdlib version; compiler is first customer |

---

## 7. REFERENCE DOCUMENTS

| Document | Use When |
|----------|----------|
| `docs/plans/compiler-architecture-critique.md` | Understanding WHY these changes matter |
| `docs/plans/compiler-findings.md` | Detailed 36 findings with line numbers |
| `docs/plans/debt-roadmap.md` | Full tech debt kanban |
| `docs/plans/goal-tree.md` | Project master map |
| `compiler/CLAUDE.md` | Compiler engineering governance |
| `docs/plans/selfhost-roadmap.md` | Bootstrap history and remaining work |

---

*This plan is a living document. Update after each sprint.*
*Last updated: 2026-07-05*
