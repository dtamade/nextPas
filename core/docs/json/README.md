# nextpas.core.json

High-performance JSON parser and serializer with zero-copy value access.

## API

### Parsing

```pascal
uses nextpas.core.json;

var Doc: IJsonDocument;
Doc := JsonParse('{"name":"Alice","age":30}');
if not Doc.HasError then
  WriteLn(Doc.Root.ObjectGet('name').AsStr.ToString);
// Auto-released when Doc goes out of scope
```

- `JsonParse(AInput)` — parse string or TStringView, returns refcounted IJsonDocument
- `JsonParseWith(AInput, AAllocator)` — parse with custom allocator (arena/pool)

### Serialization

- `Doc.Stringify` — compact JSON output
- `Doc.StringifyPretty(AIndent)` — indented output (default 2 spaces)
- `JsonStringify(AValue)` — serialize any TJsonValue subtree

### Value Access (TJsonValue)

Zero-allocation record view (8 bytes). Chain calls freely:

```pascal
Doc.Root.ObjectGet('user').ObjectGet('name').AsStr.ToString
Doc.Root.ObjectGet('items').ArrayGet(0).AsInt
```

Type checks: `IsNull`, `IsBool`, `IsInt`, `IsReal`, `IsStr`, `IsArray`, `IsObject`
Accessors: `AsBool`, `AsInt`, `AsFloat`, `AsStr`
Containers: `ArrayLen`, `ArrayGet`, `ObjectGet`, `ObjectHas`, `ObjectLen`, `ObjectKeyAt`, `ObjectValueAt`

Invalid access returns safe defaults (0, empty, false) — no exceptions.

### Marshal / Unmarshal

```pascal
uses nextpas.core.json.marshal;

JsonMarshal(Registry, @TypeDef, @MyRecord)    // record -> JSON string
JsonUnmarshal(Registry, @TypeDef, Value, @Rec) // JSON value -> record
JsonUnmarshalStr(Registry, @TypeDef, Str, @Rec) // JSON string -> record
```

Requires type registry from `nextpas.core.reflect`.

## Supported Types

- Null, Boolean, Integer (Int64), Float (Double), String
- Arrays (heterogeneous), Objects (string keys)
- Numbers: full Int64 range, IEEE 754 doubles, scientific notation

## Performance

- SIMD-accelerated structural scanning (SSE2/AVX2/NEON)
- Zero-copy string views for unescaped strings
- Object key hash index (auto-built for objects >= 16 keys)
- Arena allocator support for bulk parsing workloads

## Known Limitations

- Max nesting depth: 512
- Object keys must be strings (per RFC 8259)
- Duplicate keys: last value wins in hash lookup, all preserved in iteration
- Large integer overflow silently promotes to Double

## Failure and lifetime contract

`TryJsonParse` returns `False` on parse failure and still assigns a diagnostic document.

`TJsonError` exposes `Message`, `Line`, `Column`, and `Offset`.

Malformed string diagnostics point at the offending byte.

Keep the owning `IJsonDocument` alive while any `TJsonValue` is still in use.
