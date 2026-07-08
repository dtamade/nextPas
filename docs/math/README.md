# nextpas.core.math

> Detailed behavior contracts live in `API.md`; this README stays compact.

## Overview

The `nextpas.core.math` module provides mathematical functions and types for the nextPas runtime library.

## Features

- **Vector types**: TVec2f, TVec3f, TVec4f (and double precision variants)
- **Matrix types**: TMat3f, TMat4f (and double precision variants)
- **Quaternion types**: TQuatf, TQuatd
- **Batch operations**: SIMD-optimized batch vector and scalar operations
- **Trigonometric functions**: Sin, Cos, Tan, ArcSin, ArcCos, ArcTan2
- **Exponential/Logarithmic**: Exp, Ln, Log2, Log10, Power
- **Statistical functions**: Sum, Mean, Variance, StdDev
- **Interpolation**: Lerp, SmoothStep, easing functions
- **Random number generation**: TRandomState, TRandomGen, TNoiseGen

## Usage

```pascal
uses
  nextpas.core.math;

var
  LVec: TVec3f;
  LMat: TMat4f;
begin
  LVec := TVec3f.Create(1.0, 2.0, 3.0);
  LMat := TMat4f.Identity;
  // ...
end.
```

## Batch Operations

Batch operations process arrays of values efficiently using SIMD optimizations:

```pascal
var
  LInput: array[0..99] of Single;
  LOutput: array[0..99] of Single;
begin
  // Fill LInput...
  BatchSinF32(LInput, LOutput);
  // LOutput now contains sine of each element
end.
```

## M8 remains partial until host trig link evidence and SIMD cutover decisions are resolved.
