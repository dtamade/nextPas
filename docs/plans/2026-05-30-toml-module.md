# nextpas.core.toml Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a production-grade TOML v1.0 parser/serializer for the nextPas core library, replacing the ad-hoc parser in `compiler/frontend/np_package_manifest.pas`.

**Architecture:** Two-layer API mirroring `nextpas.core.json.*` — bottom layer is zero-alloc records (`TTomlDocument`, `TTomlWriter`) for hot paths; top layer is reference-counted interfaces (`ITomlDocument`, `ITomlBuilder`) for ergonomic use. Parser builds a flat node array with embedded keys; values are accessed via `TTomlValue` borrowing views (12 bytes: doc pointer + node index). SIMD-accelerated whitespace/comment skipping via `text.scan`. Node layout is 40 bytes with embedded key TStringView to avoid separate key nodes.

**Tech Stack:** Free Pascal (objfpc mode), `nextpas.core.text.*` utilities, `nextpas.core.simd.vec16`, `nextpas.core.mem.intf` (IAllocator), `nextpas.core.testing` (TTestRunner).

**TOML v1.0 Feature Coverage:**
- Basic/literal/multi-line strings
- Integers (dec/hex/oct/bin with _ separators)
- Floats (dec with _ separators, inf, nan)
- Booleans
- Offset/local datetime, local date, local time
- Arrays (homogeneous type enforcement)
- Inline tables
- Standard tables `[table]` / dotted keys `a.b.c`
- Array tables `[[array]]`
- Comments `# ...`

**File Structure (following design-conventions.md §2):**

```
src/nextpas.core.toml.base.pas      ← TTomlNodeKind, TTomlNode, TTomlDateTime, TTomlError, constants
src/nextpas.core.toml.parser.pas    ← TTomlDocument (底层 record, Init/Done/Parse)
src/nextpas.core.toml.value.pas     ← TTomlValue (12-byte borrowing view accessor)
src/nextpas.core.toml.writer.pas    ← TTomlWriter (底层 record serializer)
src/nextpas.core.toml.builder.pas   ← ITomlBuilder + TTomlBuilderImpl (高层 interface)
src/nextpas.core.toml.pas           ← ITomlDocument + TomlParse/TomlStringify facade
```

**Dependency Graph:**

```
base ← parser ← value ← facade(toml.pas)
base ← writer ← builder
         ↑
       facade uses all
```

---

## Phase 1: Base Types

### Task 1.1: Create toml.base.pas — node types and datetime

**Files:**
- Create: `src/nextpas.core.toml.base.pas`
- Create: `tests/nextpas.core.toml/test_toml_base/test_toml_base.lpr`
- Create: `tests/nextpas.core.toml/test_toml_base/Makefile`

**Design Decisions:**
- `TTomlNode` embeds `Key: TStringView` (16 bytes) directly — avoids separate key nodes, saves 1 allocation per table entry vs JSON's key-node approach
- `TTomlDateTime` uses packed 14-byte layout with `Flags: Byte` to encode HasDate/HasTime/HasOffset/Kind
- Node size target: 40 bytes (8 header + 16 key + 16 variant)
- Enum prefix `tnk` (toml node kind), `tdk` (toml datetime kind) — matches JSON's `jnk` pattern

**Step 1: Write test**

```pascal
program test_toml_base;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.text.view,
  nextpas.core.toml.base,
  nextpas.core.testing;
var
  T: TTestRunner;

procedure TestNodeKindEnum;
begin
  Check(Ord(tnkString) = 0, 'tnkString = 0');
  Check(Ord(tnkInt) = 1, 'tnkInt = 1');
  Check(Ord(tnkFloat) = 2, 'tnkFloat = 2');
  Check(Ord(tnkBool) = 3, 'tnkBool = 3');
  Check(Ord(tnkDateTime) = 4, 'tnkDateTime = 4');
  Check(Ord(tnkArray) = 5, 'tnkArray = 5');
  Check(Ord(tnkTable) = 6, 'tnkTable = 6');
end;

procedure TestDateTimeCreate;
var
  LDT: TTomlDateTime;
begin
  LDT := TomlDateTime(2024, 1, 15, 10, 30, 0, 0);
  CheckEqual(Int64(2024), Int64(LDT.Year), 'year');
  CheckEqual(Int64(1), Int64(LDT.Month), 'month');
  CheckEqual(Int64(15), Int64(LDT.Day), 'day');
  CheckEqual(Int64(10), Int64(LDT.Hour), 'hour');
  CheckEqual(Int64(30), Int64(LDT.Minute), 'minute');
  CheckEqual(Int64(0), Int64(LDT.Second), 'second');
  Check(LDT.HasDate, 'has date');
  Check(LDT.HasTime, 'has time');
  Check(not LDT.HasOffset, 'no offset');
  Check(LDT.Kind = tdkLocalDateTime, 'kind = local datetime');
end;

procedure TestDateTimeOffset;
var
  LDT: TTomlDateTime;
begin
  LDT := TomlDateTimeWithOffset(2024, 1, 15, 10, 30, 0, 0, 540);
  Check(LDT.HasOffset, 'has offset');
  CheckEqual(Int64(540), Int64(LDT.OffsetMinutes), 'offset +09:00');
  Check(LDT.Kind = tdkOffsetDateTime, 'kind = offset datetime');
end;

procedure TestDateOnly;
var
  LDT: TTomlDateTime;
begin
  LDT := TomlDate(2024, 1, 15);
  Check(LDT.HasDate, 'has date');
  Check(not LDT.HasTime, 'no time');
  Check(not LDT.HasOffset, 'no offset');
  Check(LDT.Kind = tdkLocalDate, 'kind = local date');
end;

procedure TestTimeOnly;
var
  LDT: TTomlDateTime;
begin
  LDT := TomlTime(10, 30, 0, 0);
  Check(not LDT.HasDate, 'no date');
  Check(LDT.HasTime, 'has time');
  Check(not LDT.HasOffset, 'no offset');
  Check(LDT.Kind = tdkLocalTime, 'kind = local time');
end;

procedure TestNodeSize;
begin
  Check(SizeOf(TTomlNode) <= 48, 'node <= 48 bytes');
  Check(SizeOf(TTomlDateTime) <= 16, 'datetime <= 16 bytes');
end;

procedure TestNodeNoneConstant;
begin
  CheckEqual(Int64($FFFFFFFF), Int64(TOML_NODE_NONE), 'TOML_NODE_NONE');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml.base');
  T.Run('node kind enum', @TestNodeKindEnum);
  T.Run('datetime create', @TestDateTimeCreate);
  T.Run('datetime offset', @TestDateTimeOffset);
  T.Run('date only', @TestDateOnly);
  T.Run('time only', @TestTimeOnly);
  T.Run('node size', @TestNodeSize);
  T.Run('node none constant', @TestNodeNoneConstant);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
```

**Step 2: Run test — expect FAIL (unit not found)**

**Step 3: Write implementation**

```pascal
unit nextpas.core.toml.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

type
  TTomlNodeKind = (
    tnkString,
    tnkInt,
    tnkFloat,
    tnkBool,
    tnkDateTime,
    tnkArray,
    tnkTable
  );

  TTomlDateTimeKind = (
    tdkOffsetDateTime,
    tdkLocalDateTime,
    tdkLocalDate,
    tdkLocalTime
  );

  { Packed 14-byte datetime. Flags byte encodes HasDate/HasTime/HasOffset/Kind. }
  TTomlDateTime = packed record
    Year: UInt16;
    Month: Byte;
    Day: Byte;
    Hour: Byte;
    Minute: Byte;
    Second: Byte;
    Flags: Byte;
    Nanosecond: UInt32;
    OffsetMinutes: Int16;
    function HasDate: Boolean; inline;
    function HasTime: Boolean; inline;
    function HasOffset: Boolean; inline;
    function Kind: TTomlDateTimeKind; inline;
  end;

  TTomlNode = record
    Kind: TTomlNodeKind;
    Next: UInt32;
    Key: TStringView;
    case Byte of
      0: (BoolVal: Boolean);
      1: (IntVal: Int64);
      2: (FloatVal: Double);
      3: (Str: TStringView);
      4: (DT: TTomlDateTime);
      5: (Container: record
            FirstChild: UInt32;
            Count: UInt32;
          end);
  end;
  PTomlNode = ^TTomlNode;

  TTomlError = record
    Message: TStringView;
    Line: UInt32;
    Col: UInt32;
    Offset: SizeUInt;
  end;

const
  TOML_NODE_NONE = UInt32($FFFFFFFF);

  TOML_DT_FLAG_HAS_DATE   = Byte(1);
  TOML_DT_FLAG_HAS_TIME   = Byte(2);
  TOML_DT_FLAG_HAS_OFFSET = Byte(4);
  TOML_DT_KIND_SHIFT      = 4;

function TomlDateTime(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32): TTomlDateTime;
function TomlDateTimeWithOffset(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32; AOffsetMinutes: Int16): TTomlDateTime;
function TomlDate(AYear: UInt16; AMonth, ADay: Byte): TTomlDateTime;
function TomlTime(AHour, AMinute, ASecond: Byte; ANanosecond: UInt32): TTomlDateTime;

implementation

function TTomlDateTime.HasDate: Boolean;
begin
  Result := (Flags and TOML_DT_FLAG_HAS_DATE) <> 0;
end;

function TTomlDateTime.HasTime: Boolean;
begin
  Result := (Flags and TOML_DT_FLAG_HAS_TIME) <> 0;
end;

function TTomlDateTime.HasOffset: Boolean;
begin
  Result := (Flags and TOML_DT_FLAG_HAS_OFFSET) <> 0;
end;

function TTomlDateTime.Kind: TTomlDateTimeKind;
begin
  Result := TTomlDateTimeKind((Flags shr TOML_DT_KIND_SHIFT) and $03);
end;

function TomlDateTime(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32): TTomlDateTime;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Year := AYear;
  Result.Month := AMonth;
  Result.Day := ADay;
  Result.Hour := AHour;
  Result.Minute := AMinute;
  Result.Second := ASecond;
  Result.Nanosecond := ANanosecond;
  Result.Flags := TOML_DT_FLAG_HAS_DATE or TOML_DT_FLAG_HAS_TIME
    or (Byte(Ord(tdkLocalDateTime)) shl TOML_DT_KIND_SHIFT);
  Result.OffsetMinutes := 0;
end;

function TomlDateTimeWithOffset(AYear: UInt16; AMonth, ADay, AHour, AMinute, ASecond: Byte;
  ANanosecond: UInt32; AOffsetMinutes: Int16): TTomlDateTime;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Year := AYear;
  Result.Month := AMonth;
  Result.Day := ADay;
  Result.Hour := AHour;
  Result.Minute := AMinute;
  Result.Second := ASecond;
  Result.Nanosecond := ANanosecond;
  Result.OffsetMinutes := AOffsetMinutes;
  Result.Flags := TOML_DT_FLAG_HAS_DATE or TOML_DT_FLAG_HAS_TIME or TOML_DT_FLAG_HAS_OFFSET
    or (Byte(Ord(tdkOffsetDateTime)) shl TOML_DT_KIND_SHIFT);
end;

function TomlDate(AYear: UInt16; AMonth, ADay: Byte): TTomlDateTime;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Year := AYear;
  Result.Month := AMonth;
  Result.Day := ADay;
  Result.Flags := TOML_DT_FLAG_HAS_DATE
    or (Byte(Ord(tdkLocalDate)) shl TOML_DT_KIND_SHIFT);
end;

function TomlTime(AHour, AMinute, ASecond: Byte; ANanosecond: UInt32): TTomlDateTime;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Hour := AHour;
  Result.Minute := AMinute;
  Result.Second := ASecond;
  Result.Nanosecond := ANanosecond;
  Result.Flags := TOML_DT_FLAG_HAS_TIME
    or (Byte(Ord(tdkLocalTime)) shl TOML_DT_KIND_SHIFT);
end;

end.
```

**Step 4: Run test — expect PASS**

Run: `cd tests/nextpas.core.toml/test_toml_base && make run`

**Step 5: Verify no memory leaks**

Run: `cd tests/nextpas.core.toml/test_toml_base && make run` (with `-gh` heaptrc flag)

**Step 6: Commit**

```bash
git add src/nextpas.core.toml.base.pas tests/nextpas.core.toml/
git commit -m "feat(toml): add base types — TTomlNodeKind, TTomlNode, TTomlDateTime"
```

---

## Phase 2: Parser Core

### Task 2.1: TTomlDocument skeleton — Init/Done/Parse with simple bare key-value pairs

**Files:**
- Create: `src/nextpas.core.toml.parser.pas`
- Create: `tests/nextpas.core.toml/test_toml_parser/test_toml_parser.lpr`
- Create: `tests/nextpas.core.toml/test_toml_parser/Makefile`

**Design:**
- `TTomlDocument` is a record with `Init(IAllocator)` / `Done` / `Parse(TStringView): Boolean`
- Flat node array (like TJsonDocument), root is always node 0 (tnkTable)
- Parser state tracks line/col for error reporting
- First iteration: parse `key = "string"`, `key = 123`, `key = true/false`

**Test covers:**
- Empty input → empty root table
- Single string key-value
- Single integer key-value
- Single boolean key-value
- Multiple key-value pairs
- Comments ignored
- Error on duplicate keys
- Error on invalid syntax

### Task 2.2: Quoted keys and string values

**Extends parser to handle:**
- Basic quoted keys `"key with spaces"`
- Literal quoted keys `'key'`
- Basic string values with escape sequences
- Literal string values (no escapes)
- Multi-line basic strings `""" ... """`
- Multi-line literal strings `''' ... '''`

### Task 2.3: Number parsing (all bases)

**Extends parser to handle:**
- Decimal integers with `_` separators
- Hexadecimal `0x1A2B`
- Octal `0o755`
- Binary `0b1101`
- Float with `_` separators
- `inf`, `+inf`, `-inf`
- `nan`, `+nan`, `-nan`
- Exponent notation `1e10`, `5e+22`

### Task 2.4: DateTime parsing

**Extends parser to handle:**
- Offset datetime: `1979-05-27T07:32:00Z`, `1979-05-27T07:32:00+09:00`
- Local datetime: `1979-05-27T07:32:00`
- Local date: `1979-05-27`
- Local time: `07:32:00`, `07:32:00.999999`
- Space separator (T or space): `1979-05-27 07:32:00`

### Task 2.5: Arrays and inline tables

**Extends parser to handle:**
- Arrays: `[1, 2, 3]`, `["a", "b"]`
- Nested arrays: `[[1, 2], [3, 4]]`
- Mixed-type rejection (TOML v1.0 requires homogeneous arrays)
- Trailing commas allowed
- Multi-line arrays
- Inline tables: `{name = "Tom", age = 30}`
- Nested inline tables

### Task 2.6: Standard tables and dotted keys

**Extends parser to handle:**
- `[table]` headers
- `[a.b.c]` dotted table headers
- Dotted keys: `a.b.c = "value"` (creates implicit intermediate tables)
- Super-table definition after sub-table
- Error on redefining existing keys
- Error on redefining tables as values

### Task 2.7: Array tables

**Extends parser to handle:**
- `[[products]]` array table headers
- Multiple `[[products]]` entries create array elements
- Nested array tables `[[fruits.varieties]]`
- Error on mixing `[table]` and `[[table]]` for same key

---

## Phase 3: Value Accessor

### Task 3.1: TTomlValue borrowing view

**Files:**
- Create: `src/nextpas.core.toml.value.pas`
- Create: `tests/nextpas.core.toml/test_toml_value/test_toml_value.lpr`
- Create: `tests/nextpas.core.toml/test_toml_value/Makefile`

**Design:**
- 12-byte record: `FDoc: ^TTomlDocument; FIdx: UInt32`
- Safe defaults for invalid access (0, empty, false)
- Chain-friendly: `Doc.Root.Get('server').Get('port').AsInt`

**API:**
```pascal
TTomlValue = record
  function IsValid: Boolean;
  function Kind: TTomlNodeKind;
  function IsStr: Boolean;
  function IsInt: Boolean;
  function IsFloat: Boolean;
  function IsBool: Boolean;
  function IsDateTime: Boolean;
  function IsArray: Boolean;
  function IsTable: Boolean;
  function AsStr: TStringView;
  function AsInt: Int64;
  function AsFloat: Double;
  function AsBool: Boolean;
  function AsDateTime: TTomlDateTime;
  function Get(const AKey: TStringView): TTomlValue; overload;
  function Get(const AKey: string): TTomlValue; overload;
  function Has(const AKey: string): Boolean;
  function TableLen: UInt32;
  function TableKeyAt(AIndex: UInt32): TStringView;
  function TableValueAt(AIndex: UInt32): TTomlValue;
  function ArrayLen: UInt32;
  function ArrayGet(AIndex: UInt32): TTomlValue;
end;
```

---

## Phase 4: Writer (Serializer)

### Task 4.1: TTomlWriter — streaming TOML serializer

**Files:**
- Create: `src/nextpas.core.toml.writer.pas`
- Create: `tests/nextpas.core.toml/test_toml_writer/test_toml_writer.lpr`
- Create: `tests/nextpas.core.toml/test_toml_writer/Makefile`

**Design:**
- Zero-alloc record, writes to TStringBuilder
- Tracks current table path for `[table]` headers
- Handles newlines, indentation, comments

**API:**
```pascal
TTomlWriter = record
  procedure Init(var ABuilder: TStringBuilder);
  procedure BeginTable(const AKey: string);
  procedure BeginArrayTable(const AKey: string);
  procedure Key(const AKey: string);
  procedure Str(const AValue: string);
  procedure Int(const AValue: Int64);
  procedure Float(const AValue: Double);
  procedure Bool(const AValue: Boolean);
  procedure DateTime(const AValue: TTomlDateTime);
  procedure BeginInlineTable;
  procedure EndInlineTable;
  procedure BeginArray;
  procedure EndArray;
  procedure Comment(const AText: string);
  procedure Newline;
end;
```

**Test covers:**
- Simple key-value pairs
- Table headers
- Array table headers
- Inline tables
- Arrays (single-line and multi-line)
- All value types (string escaping, number formatting, datetime ISO 8601)
- Comments
- Round-trip: parse → write → parse → compare

---

## Phase 5: Builder (High-Level Interface)

### Task 5.1: ITomlBuilder — ergonomic TOML construction

**Files:**
- Create: `src/nextpas.core.toml.builder.pas`
- Create: `tests/nextpas.core.toml/test_toml_builder/test_toml_builder.lpr`
- Create: `tests/nextpas.core.toml/test_toml_builder/Makefile`

**Design:**
- Interface wraps TTomlWriter + TStringBuilder
- Auto-released via COM refcount
- Factory function: `TomlBuilder: ITomlBuilder`

**API:**
```pascal
ITomlBuilder = interface
  procedure BeginTable(const AKey: string);
  procedure BeginArrayTable(const AKey: string);
  procedure Key(const AKey: string);
  procedure Str(const AValue: string);
  procedure Int(const AValue: Int64);
  procedure Float(const AValue: Double);
  procedure Bool(const AValue: Boolean);
  procedure DateTime(const AValue: TTomlDateTime);
  procedure BeginInlineTable;
  procedure EndInlineTable;
  procedure BeginArray;
  procedure EndArray;
  procedure Comment(const AText: string);
  function ToString: string;
end;

function TomlBuilder: ITomlBuilder;
```

---

## Phase 6: Facade

### Task 6.1: ITomlDocument + TomlParse facade

**Files:**
- Create: `src/nextpas.core.toml.pas`
- Create: `tests/nextpas.core.toml/test_toml_facade/test_toml_facade.lpr`
- Create: `tests/nextpas.core.toml/test_toml_facade/Makefile`

**Design:**
- `ITomlDocument` interface with `Root: TTomlValue`, `HasError`, `Error`, `Stringify`
- Factory: `TomlParse(string): ITomlDocument`
- Factory: `TomlParseWith(string, IAllocator): ITomlDocument`
- Convenience: `TomlStringify(TTomlValue): string`

**API:**
```pascal
ITomlDocument = interface
  function Root: TTomlValue;
  function HasError: Boolean;
  function Error: TTomlError;
  function Stringify: string;
end;

function TomlParse(const AInput: string): ITomlDocument;
function TomlParseWith(const AInput: string; const AAllocator: IAllocator): ITomlDocument;
function TomlStringify(const AValue: TTomlValue): string;
```

**Test covers:**
- Parse and access via high-level API
- Auto-release (no leaks)
- Error reporting
- Round-trip: parse → stringify → parse → compare
- Real-world TOML: `nextpas.package.toml` format

---

## Phase 7: Integration & Compliance

### Task 7.1: TOML v1.0 compliance test suite

**Files:**
- Create: `tests/nextpas.core.toml/test_toml_compliance/test_toml_compliance.lpr`
- Create: `tests/nextpas.core.toml/test_toml_compliance/Makefile`

**Covers:**
- All valid TOML v1.0 examples from spec
- All invalid TOML that must be rejected
- Edge cases: empty tables, deeply nested, large files
- Unicode in keys and values
- Boundary values (Int64 min/max, float precision)

### Task 7.2: Memory leak verification

Run all tests with heaptrc (`-gh`) and verify 0 unfreed blocks.

---

## Phase 8: Benchmarks

### Task 8.1: Benchmark suite

**Files:**
- Create: `benchmarks/nextpas.core.toml/bench_toml_parse/bench_toml_parse.lpr`
- Create: `benchmarks/nextpas.core.toml/bench_toml_parse/Makefile`
- Create: `benchmarks/nextpas.core.toml/bench_toml_parse/compare_go/`
- Create: `benchmarks/nextpas.core.toml/bench_toml_parse/compare_rust/`

**Benchmark scenarios:**
- Small config (10 keys) — parse throughput
- Medium config (100 keys, nested tables) — parse throughput
- Large config (1000+ keys) — parse throughput
- Writer throughput
- Round-trip (parse + stringify)

**Comparison targets:**
- Go: `github.com/BurntSushi/toml`
- Rust: `toml` crate

---

## Execution Order

1. Phase 1 (base types) — foundation, must be solid
2. Phase 2 (parser) — incremental, task by task
3. Phase 3 (value accessor) — depends on parser
4. Phase 4 (writer) — independent of parser, can parallel
5. Phase 5 (builder) — depends on writer
6. Phase 6 (facade) — integrates all
7. Phase 7 (compliance) — validation
8. Phase 8 (benchmarks) — last, after correctness proven

Each phase ends with: git commit + /codex review + heaptrc verification.
