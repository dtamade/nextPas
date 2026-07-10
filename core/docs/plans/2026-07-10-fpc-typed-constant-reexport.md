# FPC Typed Constant Re-export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the `math.base`, `math.trig`, and root math constant entry points while making `math.base` the only literal owner and making the other two surfaces compile-time aliases.

**Architecture:** Declare canonical values as ordinary constants whose expressions are explicitly converted to `Double`, for example `PI_VALUE = Double(3.14159265358979323846)`. This preserves `Double` type and bit semantics while allowing qualified ordinary-constant aliases in `math.trig` and the root facade. Source-contract tests lock the owner and alias declarations so typed constants or copied literals cannot return unnoticed.

**Tech Stack:** Free Pascal 3.3.1, Object Pascal units, `nextpas.core.test`, Python API-surface gate, GNU Make.

---

### Task 1: Lock compile-time behavior with failing Pascal tests

**Files:**
- Modify: `core/tests/nextpas.core.math/test_scalar/test_scalar.lpr`
- Modify: `core/tests/nextpas.core.math/test_trig/test_trig.lpr`
- Modify: `core/tests/nextpas.core.math/test_facade/test_facade.lpr`

- [x] **Step 1: Add local ordinary constants from every public entry point**

Add compile-time declarations such as:

```pascal
const
  BASE_PI_COMPILE_TIME = nextpas.core.math.base.PI_VALUE;
  TRIG_PI_COMPILE_TIME = nextpas.core.math.trig.PI_VALUE;
  FACADE_PI_COMPILE_TIME = nextpas.core.math.PI_VALUE;
```

Cover all constants exposed by each surface, then use the local constants in existing runtime checks and verify `SizeOf(...) = SizeOf(Double)`.

- [x] **Step 2: Run each focused project and verify RED**

Run:

```sh
make -C core/tests/nextpas.core.math/test_scalar clean test
make -C core/tests/nextpas.core.math/test_trig clean test
make -C core/tests/nextpas.core.math/test_facade clean test
```

Expected: each compile fails with `Illegal expression` because its public source is still a typed constant.

### Task 2: Lock canonical ownership in the API-surface gate

**Files:**
- Modify: `core/tests/nextpas.core.math/test_api_surface/test_api_surface.py`

- [x] **Step 1: Teach the public-constant parser the two supported ordinary forms**

Recognize explicit-Double owner declarations and qualified base aliases:

```pascal
PI_VALUE = Double(3.14159265358979323846);
PI_VALUE = nextpas.core.math.base.PI_VALUE;
```

Retain the normalized initializer in the parsed constant so the gate can distinguish canonical values from aliases.

- [x] **Step 2: Change the expected ownership map**

Require `math.base` to contain each `Double(literal)` declaration. Require `math.trig` and the root facade to contain only the matching `nextpas.core.math.base.<NAME>` initializer.

- [x] **Step 3: Extend self-tests and verify the gate is RED against production source**

Run:

```sh
make -C core/tests/nextpas.core.math/test_api_surface clean test
```

Expected: parser self-tests pass, then the source scan reports canonical/alias drift in the current typed declarations.

### Task 3: Implement ordinary Double constants and aliases

**Files:**
- Modify: `core/src/nextpas.core.math.base.pas`
- Modify: `core/src/nextpas.core.math.trig.pas`
- Modify: `core/src/nextpas.core.math.pas`

- [x] **Step 1: Convert canonical values without changing bits**

Use explicit conversions in `math.base`:

```pascal
const
  PI_VALUE = Double(3.14159265358979323846);
  TWO_PI = Double(6.28318530717958647692);
  HALF_PI = Double(1.57079632679489661923);
  QUARTER_PI = Double(0.78539816339744830962);
  DEG_TO_RAD = Double(0.01745329251994329577);
  RAD_TO_DEG = Double(57.2957795130823208768);
```

- [x] **Step 2: Alias the trig constants**

Add `nextpas.core.math.base` to the interface `uses` clause and declare:

```pascal
const
  PI_VALUE = nextpas.core.math.base.PI_VALUE;
  TWO_PI = nextpas.core.math.base.TWO_PI;
  HALF_PI = nextpas.core.math.base.HALF_PI;
```

- [x] **Step 3: Alias the root facade constants**

Keep the existing base import and replace all five copied literals with qualified aliases to `math.base`.

- [x] **Step 4: Run the four focused projects and verify GREEN**

Run the scalar, trig, facade, and API-surface project commands from Tasks 1 and 2. Expected: all pass with no compiler errors.

### Task 4: Record the stable constant ownership rule

**Files:**
- Modify: `core/docs/math/API.md`
- Modify: `core/docs/math/CONTRACT.md`
- Modify: `core/docs/math/FINAL_API_MIGRATION_DESIGN.md`
- Modify: `core/docs/math/README.md`

- [x] **Step 1: Document the public behavior**

State that the constants are compile-time `Double` values, `math.base` owns their literals, and `math.trig` plus the root facade expose compile-time aliases.

- [x] **Step 2: Verify documentation markers through the API-surface gate**

Run:

```sh
make -C core/tests/nextpas.core.math/test_api_surface clean test
```

Expected: pass.

### Task 5: Run the verification envelope

**Files:**
- Verify only; no new files.

- [x] **Step 1: Run the module gate**

```sh
make focused FOCUS=core/tests/nextpas.core.math
```

Expected: all configured math projects pass.

- [x] **Step 2: Run repository hygiene checks**

```sh
git diff --check
make hygiene
git status --short --branch
```

Expected: no whitespace errors, hygiene passes, and only the planned math source, test, documentation, and plan files are tracked changes.
