# nextpas.core.toml Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a TOML v1.0 parser/serializer for the nextPas core library, replacing the ad-hoc parser in `compiler/frontend/np_package_manifest.pas`.

**Architecture:** Two-layer API mirroring `nextpas.core.json.*` — bottom layer is zero-alloc records (`TTomlDocument`, `TTomlWriter`) for hot paths; top layer is reference-counted interfaces (`ITomlDocument`, `ITomlBuilder`) for ergonomic use. Parser builds a flat node array; values are accessed via `TTomlValue` borrowing views. SIMD-accelerated whitespace/comment skipping via `text.scan`.

**Tech Stack:** Free Pascal (objfpc mode), `nextpas.core.text.*` utilities, `nextpas.core.simd.vec16`, `nextpas.core.mem.intf` (IAllocator), `nextpas.core.testing` (TTestRunner).

---

## Phase 1: Types & Node Layout

### Task 1: Define TTomlNodeKind and TTomlDateTime

**Files:**
- Create: `src/nextpas.core.toml.types.pas`
- Test: `tests/nextpas.core.toml/test_toml_types/test_toml_types.lpr`
- Test: `tests/nextpas.core.toml/test_toml_types/Makefile`

**Step 1: Write the test file**

```pascal
program test_toml_types;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.toml.types,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestNodeKindValues;
begin
  Check(Ord(tnkString) > 0, 'tnkString defined');
  Check(Ord(tnkInt) > 0, 'tnkInt defined');
  Check(Ord(tnkFloat) > 0, 'tnkFloat defined');
  Check(Ord(tnkBool) > 0, 'tnkBool defined');
  Check(Ord(tnkDateTime) > 0, 'tnkDateTime defined');
  Check(Ord(tnkArray) > 0, 'tnkArray defined');
  Check(Ord(tnkTable) > 0, 'tnkTable defined');
end;

procedure TestDateTimeRecord;
var DT: TTomlDateTime;
begin
  DT := Default(TTomlDateTime);
  DT.Year := 2024;
  DT.Month := 1;
  DT.Day := 15;
  DT.Hour := 10;
  DT.Minute := 30;
  DT.Second := 0;
  DT.HasDate := True;
  DT.HasTime := True;
  DT.HasOffset := False;
  CheckEqual(Int64(2024), Int64(DT.Year), 'year');
  CheckEqual(Int64(1), Int64(DT.Month), 'month');
  CheckEqual(Int64(15), Int64(DT.Day), 'day');
  CheckEqual(Int64(10), Int64(DT.Hour), 'hour');
  CheckEqual(Int64(30), Int64(DT.Minute), 'minute');
  Check(DT.HasDate, 'has date');
  Check(DT.HasTime, 'has time');
  Check(not DT.HasOffset, 'no offset');
end;

procedure TestNodeSize;
begin
  Check(SizeOf(TTomlNode) <= 32, 'node fits 32 bytes');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml.types');
  T.Run('node kind values', @TestNodeKindValues);
  T.Run('datetime record', @TestDateTimeRecord);
  T.Run('node size', @TestNodeSize);
  T.Summary;
end.
```

**Step 2: Run test to verify it fails**

Run: `cd tests/nextpas.core.toml/test_toml_types && make run`
Expected: FAIL — unit `nextpas.core.toml.types` not found

**Step 3: Write the implementation**

```pascal
unit nextpas.core.toml.types;

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

  TTomlDateTime = record
    Year: UInt16;
    Month: Byte;
    Day: Byte;
    Hour: Byte;
    Minute: Byte;
    Second: Byte;
    Nanosecond: UInt32;
    OffsetMinutes: Int16;
    HasDate: Boolean;
    HasTime: Boolean;
    HasOffset: Boolean;
    Kind: TTomlDateTimeKind;
  end;

  TTomlNode = record
    Kind: TTomlNodeKind;
    KeyStart: UInt32;
    KeyLen: UInt16;
    Next: UInt32;
    case Byte of
      0: (BoolVal: Boolean);
      1: (IntVal: Int64);
      2: (FloatVal: Double);
      3: (Str: TStringView);
      4: (DateTime: TTomlDateTime);
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

implementation

end.
```

**Step 4: Run test to verify it passes**

Run: `cd tests/nextpas.core.toml/test_toml_types && make run`
Expected: PASS — all 3 tests green

**Step 5: Commit**

```bash
git add src/nextpas.core.toml.types.pas tests/nextpas.core.toml/
git commit -m "feat(toml): add types unit — TTomlNodeKind, TTomlNode, TTomlDateTime"
```

---

## Phase 2: Parser Core

### Task 2: TTomlDocument skeleton + simple key-value parsing

**Files:**
- Create: `src/nextpas.core.toml.parser.pas`
- Test: `tests/nextpas.core.toml/test_toml_parser/test_toml_parser.lpr`
- Test: `tests/nextpas.core.toml/test_toml_parser/Makefile`

**Step 1: Write the test file**

<!-- PLACEHOLDER_TASK2_TESTS -->
