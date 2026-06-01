# Findings: reflect/marshal dynarray support

## Requirements
- Add dynamic array metadata to `TFieldDef`.
- Extend visitor and registry APIs with dynamic array support.
- Wrap RTL dynarray functions without manually touching headers.
- Marshal and unmarshal JSON arrays for primitive and record elements.
- Preserve transaction semantics during unmarshal.
- Extend existing JSON marshal tests and verify heaptrc zero leaks.

## Research Findings
- `fkDynArray` already exists in `TFieldKind`, but `TFieldDef` does not yet store element metadata or typeinfo.
- `ITypeVisitor` currently has no dynamic array method; the main concrete visitors inherit from `TBaseTypeVisitor`.
- `TTypeRegistry.Visit` already does centralized per-kind dispatch, so `fkDynArray` should be added there.
- `TJsonWriter` already supports `BeginArray` and `EndArray`; nested record marshal can reuse `FRegistry.Visit`.
- `TJsonValue` supports `IsArray`, `ArrayLen`, and `ArrayGet`.
- Current JSON marshal test has 9 tests covering simple, nested, missing fields, and round-trip behavior.

## Implementation Notes
- Dynamic array field pointers must be treated as `PPointer` pointing to the dynarray variable.
- Array data pointer is `AArrayPtr^`; element pointer is `PtrUInt(AArrayPtr^) + Index * ElementSize`.
- `DynArrayClear` should be used for both old field values and temporary rollback arrays.

## Issues Encountered
| Issue | Resolution |
|---|---|
| Existing planning files described a previous log review | Replaced them with this task's plan/findings/progress |

## Resources
- `src/nextpas.core.reflect.base.pas`
- `src/nextpas.core.reflect.intf.pas`
- `src/nextpas.core.reflect.pas`
- `src/nextpas.core.reflect.dynarray.pas`
- `src/nextpas.core.json.marshal.pas`
- `src/nextpas.core.reflect.marshal.pas`
- `tests/nextpas.core.json/test_json_marshal/test_json_marshal.lpr`
