# Task Plan: reflect/marshal dynarray support

## Goal
Implement dynamic array reflection metadata, visitor dispatch, JSON marshal/unmarshal, and heaptrc-verified tests using only FPC RTL dynarray APIs.

## Current Phase
Phase 1

## Phases

### Phase 1: RED tests
- [x] Extend `tests/nextpas.core.json/test_json_marshal/test_json_marshal.lpr` with named dynamic array types and coverage for int, string, record, empty, null, replacement, and round-trip.
- [x] Build test target and confirm the new tests fail before implementation.
- **Status:** complete

### Phase 2: Reflection surface
- [x] Extend `TFieldDef` with element metadata and typeinfo pointer.
- [x] Add `VisitDynArray` to `ITypeVisitor` and `TBaseTypeVisitor`.
- [x] Add `AddDynArrayField` to `ITypeRegistry` and `TTypeRegistry`.
- [x] Dispatch `fkDynArray` in `TTypeRegistry.Visit`.
- **Status:** complete

### Phase 3: RTL wrapper
- [x] Create `src/nextpas.core.reflect.dynarray.pas`.
- [x] Wrap `DynArraySize`, `DynArraySetLength`, `DynArrayClear`, and element pointer arithmetic.
- **Status:** complete

### Phase 4: JSON marshal/unmarshal
- [x] Marshal arrays with `DynArrayGetLength` and per-element primitive/record writing.
- [x] Unmarshal arrays transactionally using a temporary dynarray and rollback on failure.
- [x] Handle JSON null by `DynArrayFree`.
- **Status:** complete

### Phase 5: Interface implementers and verification
- [x] Grep all `ITypeVisitor` implementers and add `VisitDynArray` declarations/implementations as needed.
- [x] Compile and run the JSON marshal test with the requested command.
- [x] Confirm all existing 9 tests still pass and heaptrc reports no leaks.
- [x] Check `git status` and report touched files.
- **Status:** complete

## Decisions
| Decision | Rationale |
|---|---|
| Use user-provided FPC 3.3.1 RTL signatures exactly | Avoid unsafe dynarray header assumptions |
| Use named array TypeInfo in tests | `TypeInfo(array of T)` is explicitly forbidden |
| Make unmarshal fail the whole call only for failed array element conversion | Missing or mismatched field nodes preserve existing behavior by skipping |

## Errors Encountered
| Error | Attempt | Resolution |
|---|---|---|
| `ITypeRegistry` has no `AddDynArrayField` | RED compile of extended JSON test | Expected pre-implementation failure; proceed with reflection API |
