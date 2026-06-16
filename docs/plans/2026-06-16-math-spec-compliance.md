# Math Module Spec Compliance Fix Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring all 13 math module files into full compliance with `core/docs/design-conventions.md`

**Architecture:** Fix in dependency order: base types first → implementations → facade → tests. Each commit is one logical unit.

**Tech Stack:** FPC 3.3.1, `{$I nextpas.core.settings.inc}`, `{** ... *}` JavaDoc comments

---

## Priority 1: Structural Fixes (Task 1-4)

### Task 1: Create `nextpas.core.math.base.pas` — Shared Constants

**Why:** `PI_VALUE`, `TWO_PI`, `HALF_PI`, `DEG_TO_RAD`, `RAD_TO_DEG` belong in a shared base unit, not scattered in `scalar.pas`.

**Files:**
- Create: `core/src/nextpas.core.math.base.pas`
- Modify: `core/src/nextpas.core.math.scalar.pas` (remove constants, `uses math.base`)
- Modify: `core/src/nextpas.core.math.trig.pas` (change `uses scalar` → `uses math.base` for constants)
- Modify: `core/src/nextpas.core.math.easing.pas` (change `uses scalar` → `uses math.base` for constants)

**Step 1: Create math.base.pas**

```pascal
unit nextpas.core.math.base;

{$I nextpas.core.settings.inc}

interface

{ TPoint2f - 2D single-precision point }
type
  TPoint2f = record
    X, Y: Single;
  end;

{ TPoint3f - 3D single-precision point }
  TPoint3f = record
    X, Y, Z: Single;
  end;

const
  { Mathematical constants }
  PI_VALUE    = 3.14159265358979323846;
  TWO_PI      = 6.28318530717958647692;
  HALF_PI     = 1.57079632679489661923;
  QUARTER_PI  = 0.78539816339744830962;

  { Degree/radian conversion constants }
  DEG_TO_RAD  = 0.01745329251994329577;
  RAD_TO_DEG  = 57.2957795130823208768;

implementation

end.
```

**Step 2: Update scalar.pas — remove constants, add `uses math.base`**

In `nextpas.core.math.scalar.pas`, interface section:
- Add `nextpas.core.math.base` to uses
- Remove the const block (PI_VALUE through RAD_TO_DEG)

**Step 3: Update trig.pas — use math.base for constants**

In `nextpas.core.math.trig.pas`, interface section:
- Change `uses nextpas.core.math.scalar` → `uses nextpas.core.math.base`
- Keep `uses nextpas.core.math.scalar` only if trig needs scalar functions

**Step 4: Update easing.pas — use math.base for constants**

In `nextpas.core.math.easing.pas`, interface section:
- Change `uses nextpas.core.math.scalar, nextpas.core.math.trig` → `uses nextpas.core.math.base, nextpas.core.math.trig`

**Step 5: Run tests to verify**

```bash
make -C core/tests/nextpas.core.math clean test
```

**Step 6: Commit**

```bash
git add -A
git commit -m "refactor(math): extract shared constants to math.base"
```

---

### Task 2: Fix `TRandomState.Seed` → `FSeed`

**Why:** Field names must use `F` prefix per design-conventions Section 13.

**Files:**
- Modify: `core/src/nextpas.core.math.random.pas`
- Modify: `core/tests/nextpas.core.math/test_random/test_random.lpr`

**Step 1: Fix random.pas**

Replace all `AState.Seed` with `AState.FSeed` (approx 6 occurrences).

**Step 2: Remove TPoint2f/TPoint3f from random.pas**

Since Task 1 created them in math.base.pas:
- Remove TPoint2f/TPoint3f type declarations from random.pas
- Add `nextpas.core.math.base` to uses

**Step 3: Run tests**

```bash
make -C core/tests/nextpas.core.math/test_random clean test
```

**Step 4: Commit**

```bash
git add -A
git commit -m "fix(math): rename TRandomState.Seed to FSeed, move point types to math.base"
```

---

### Task 3: Fix Compiler Directives

**Why:** All files must use `{$I nextpas.core.settings.inc}` instead of raw `{$mode ObjFPC}{$H+}`.

**Files:**
- Modify: `core/src/nextpas.core.math.transform.pas` (line 7)
- Modify: `core/src/nextpas.core.math.easing.pas` (line 7)
- Modify: `core/src/nextpas.core.math.random.pas` (line 7)

**Step 1: Replace in each file**

```pascal
// Before:
{$mode ObjFPC}{$H+}

// After:
{$I nextpas.core.settings.inc}
```

**Step 2: Run all math tests**

```bash
make -C core/tests/nextpas.core.math clean test
```

**Step 3: Commit**

```bash
git add -A
git commit -m "fix(math): use settings.inc consistently in transform/easing/random"
```

---

### Task 4: Fix Vec Constants Naming

**Why:** `Vec2fZero`, `Mat3fIdentity` etc. are standalone functions, not constants. BUT `VECF2_ZERO` style would be wrong for functions. The audit was partially wrong — these ARE functions, not constants. Keep as-is.

**Action:** No change needed. Skip this task.

---

## Priority 2: API Visibility & Facade (Task 5-6)

### Task 5: Expose Hidden Functions in scalar.pas

**Why:** `RoundTo`, `Sum`, `SumInt`, `Mean`, `Variance`, `StdDev` etc. are only in implementation — external code cannot call them.

**Files:**
- Modify: `core/src/nextpas.core.math.scalar.pas` (add to interface)
- Modify: `core/src/nextpas.core.math.pas` (add facade re-exports)

**Step 1: Add declarations to scalar.pas interface section**

Add these function declarations after existing interface declarations:

```pascal
{ Statistics }
function Sum(const AValues: array of Double): Double;
function SumInt(const AValues: array of Int64): Int64;
function Mean(const AValues: array of Double): Double;
function Variance(const AValues: array of Double): Double;
function PopnVariance(const AValues: array of Double): Double;
function StdDev(const AValues: array of Double): Double;
function PopnStdDev(const AValues: array of Double): Double;
function TotalVariance(const AValues: array of Double): Double;
function RoundTo(const AValue: Double; const ADigit: Integer): Double;
```

**Step 2: Run existing tests to verify no breakage**

```bash
make -C core/tests/nextpas.core.math/test_scalar clean test
```

**Step 3: Commit**

```bash
git add -A
git commit -m "feat(math): expose statistics functions in scalar.pas interface"
```

---

### Task 6: Add Missing Facade Re-exports

**Why:** `uses nextpas.core.math` should give access to key types and functions from all sub-modules.

**Files:**
- Modify: `core/src/nextpas.core.math.pas`

**Step 1: Add type re-exports to facade interface section**

Add after existing uses:

```pascal
type
  { Re-export vec types }
  TVec2f = nextpas.core.math.vec.base.TVec2f;
  TVec2d = nextpas.core.math.vec.base.TVec2d;
  TVec3f = nextpas.core.math.vec.base.TVec3f;
  TVec3d = nextpas.core.math.vec.base.TVec3d;
  TVec4f = nextpas.core.math.vec.base.TVec4f;
  TVec4d = nextpas.core.math.vec.base.TVec4d;

  { Re-export mat types }
  TMat3f = nextpas.core.math.mat.base.TMat3f;
  TMat3d = nextpas.core.math.mat.base.TMat3d;
  TMat4f = nextpas.core.math.mat.base.TMat4f;
  TMat4d = nextpas.core.math.mat.base.TMat4d;

  { Re-export quat types }
  TQuatf = nextpas.core.math.quat.base.TQuatf;
  TQuatd = nextpas.core.math.quat.base.TQuatd;

  { Re-export random types }
  TRandomState = nextpas.core.math.random.TRandomState;
  TPoint2f = nextpas.core.math.base.TPoint2f;
  TPoint3f = nextpas.core.math.base.TPoint3f;
```

**Step 2: Add key function re-exports**

```pascal
{ Re-export vec constructors }
function Vec2f(AX, AY: Single): TVec2f; inline;
function Vec3f(AX, AY, AZ: Single): TVec3f; inline;
function Vec4f(AX, AY, AZ, AW: Single): TVec4f; inline;
// ... etc for Vec2d/3d/4d

{ Re-export mat identity/zero }
function Mat3fIdentity: TMat3f; inline;
function Mat4fIdentity: TMat4f; inline;
function Mat3fZero: TMat3f; inline;
function Mat4fZero: TMat4f; inline;
// ... etc for double variants

{ Re-export quat constructors }
function Quatf(AX, AY, AZ, AW: Single): TQuatf; inline;
function Quatd(AX, AY, AZ, AW: Double): TQuatd; inline;
function QuatfIdentity: TQuatf; inline;
function QuatdIdentity: TQuatd; inline;

{ Re-export random }
function RandomCreate(ASeed: UInt64): TRandomState; inline;
```

**Step 3: Add implementations (inline forwarding)**

**Step 4: Run facade test + all tests**

```bash
make -C core/tests/nextpas.core.math/test_facade clean test
make -C core/tests/nextpas.core.math clean test
```

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(math): complete facade re-exports for all sub-modules"
```

---

## Priority 3: Documentation (Task 7-11)

### Task 7: Add JavaDoc to `math.scalar.pas`

**Why:** Design-conventions Section 10 requires `{** ... *}` comments on all public APIs.

**Files:**
- Modify: `core/src/nextpas.core.math.scalar.pas`

**Step 1: Add comments to key function groups**

Add `{** ... *}` blocks before each function group:
- `IsAddOverflow/IsMulOverflow`
- `Min/Max/Clamp`
- `Lerp/InverseLerp/Wrap/SmoothStep`
- `Floor/Ceil/Round/Trunc/Frac`
- `Abs/Sign/IsNaN/IsInfinite`
- `FloatEquals/FloatIsZero`
- `DegToRad/RadToDeg`
- `GCD/LCM/Hypot/Fmod`
- `Sum/Mean/Variance/StdDev` (once exposed)

**Step 2: Run tests (no behavior change)**

```bash
make -C core/tests/nextpas.core.math/test_scalar clean test
```

**Step 3: Commit**

```bash
git add -A
git commit -m "docs(math): add JavaDoc comments to scalar.pas public API"
```

---

### Task 8: Add JavaDoc to `math.trig.pas`

**Files:**
- Modify: `core/src/nextpas.core.math.trig.pas`

**Step 1: Fix partition comment style**

Replace:
```pascal
// === Hyperbolic functions ===
```
With:
```pascal
{ Hyperbolic functions }
```

**Step 2: Add `{** ... *}` to public functions**

**Step 3: Commit**

```bash
git add -A
git commit -m "docs(math): add JavaDoc comments to trig.pas, fix partition style"
```

---

### Task 9: Add JavaDoc to `math.vec.base.pas`

**Files:**
- Modify: `core/src/nextpas.core.math.vec.base.pas`

**Step 1: Add type comments**

```pascal
{ TVec2f - 2D single-precision vector }
TVec2f = record
```

**Step 2: Add method comments**

```pascal
{**
 * @desc Returns the length (magnitude) of this vector
 * @return Euclidean length as Single
 *}
function Length: Single;
```

**Step 3: Commit**

---

### Task 10: Add JavaDoc to `math.mat.base.pas` and `math.quat.base.pas`

Same pattern as Task 9.

---

### Task 11: Add JavaDoc to `math.transform.pas`, `math.easing.pas`, `math.random.pas`

Same pattern. Transform and easing functions are self-explanatory but still need lightweight comments.

---

## Priority 4: Test Coverage (Task 12-14)

### Task 12: Add Tests for Exposed Statistics Functions

**Files:**
- Create/Modify: `core/tests/nextpas.core.math/test_scalar/test_scalar.lpr`

**Step 1: Add tests for Sum, Mean, Variance, StdDev**

Test with known data sets:
- `Sum([1,2,3,4,5]) = 15`
- `Mean([1,2,3,4,5]) = 3.0`
- `Variance([2,4,4,4,5,5,7,9]) = 4.0` (population)

**Step 2: Run with heaptrc**

```bash
make -C core/tests/nextpas.core.math/test_scalar clean test
```

**Step 3: Commit**

---

### Task 13: Verify API Surface Test

**Files:**
- Modify: `core/tests/nextpas.core.math/test_api_surface/test_api_surface.py`

**Step 1: Update CONSUMER_FACING_UNITS if needed**

Ensure `math.base` is in the list.

**Step 2: Run surface test**

```bash
make -C core/tests/nextpas.core.math/test_api_surface clean test
```

**Step 3: Commit**

---

### Task 14: Full Integration Test

**Step 1: Run all math tests**

```bash
make -C core/tests/nextpas.core.math clean test
```

**Step 2: Run hygiene check**

```bash
make hygiene
```

**Step 3: Run git diff check**

```bash
git diff --check
```

**Step 4: Final commit if needed**

---

## Execution Order Summary

| Task | Description | Priority | Dependencies |
|------|-------------|----------|--------------|
| 1 | Create math.base.pas | High | None |
| 2 | Fix TRandomState.Seed | High | Task 1 |
| 3 | Fix compiler directives | High | None |
| 4 | Fix vec constants naming | - | Skip (false positive) |
| 5 | Expose hidden scalar functions | Medium | None |
| 6 | Complete facade re-exports | High | Task 1, 5 |
| 7 | JavaDoc scalar.pas | Medium | Task 5 |
| 8 | JavaDoc trig.pas | Medium | None |
| 9 | JavaDoc vec.base.pas | Medium | None |
| 10 | JavaDoc mat/quat.base.pas | Medium | None |
| 11 | JavaDoc transform/easing/random | Low | None |
| 12 | Tests for statistics | Medium | Task 5 |
| 13 | API surface update | Medium | Task 1 |
| 14 | Full integration test | High | All |

## Verification Cadence

After each task:
```bash
make -C core/tests/nextpas.core.math clean test
git diff --check
git status --short
```

Final verification:
```bash
make -C core/tests/nextpas.core.math clean test
make -C core/tests/nextpas.core.math/test_api_surface clean test
make hygiene
git diff --check
```
