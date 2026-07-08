# nextpas.core.math API Reference

> Detailed behavior contracts live in `API.md`; this README stays compact.

## Batch Operations

### Batch Vector Operations

#### BatchDot
```pascal
function BatchDot(const ALeft, ARight: array of TVec2f;
                  var AResults: array of Single): SizeInt;
function BatchDot(const ALeft, ARight: array of TVec3f;
                  var AResults: array of Single): SizeInt;
function BatchDot(const ALeft, ARight: array of TVec4f;
                  var AResults: array of Single): SizeInt;
```
Computes dot product of corresponding vectors in arrays.

#### BatchNormalize
```pascal
function BatchNormalize(var AVectors: array of TVec2f): SizeInt;
function BatchNormalize(var AVectors: array of TVec3f): SizeInt;
function BatchNormalize(var AVectors: array of TVec4f): SizeInt;
function BatchNormalize(const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt;
```
Normalizes vectors to unit length (in-place or with output).

#### BatchTransform
```pascal
function BatchTransform(const AMatrix: TMat3f;
                        const ASource: array of TVec2f;
                        var ADest: array of TVec2f): SizeInt;
function BatchTransform(const AMatrix: TMat4f;
                        const ASource: array of TVec3f;
                        var ADest: array of TVec3f): SizeInt;
```
Transforms vectors by a matrix.

#### BatchLerp
```pascal
function BatchLerp(const AStart, AEnd: array of TVec3f;
                   const AT: Single;
                   var ADest: array of TVec3f): SizeInt;
```
Linearly interpolates between vector arrays.

#### BatchClamp
```pascal
function BatchClamp(const AVectors: array of TVec3f;
                    const AMin, AMax: TVec3f;
                    var ADest: array of TVec3f): SizeInt;
```
Clamps vectors to [min, max] range.

### Batch Scalar Operations

#### BatchSinF32
```pascal
function BatchSinF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
```
Computes sine of each element (angles in radians).

#### BatchCosF32
```pascal
function BatchCosF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
```
Computes cosine of each element (angles in radians).

#### BatchTanF32
```pascal
function BatchTanF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
```
Computes tangent of each element (angles in radians).

#### BatchExpF32
```pascal
function BatchExpF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
```
Computes e^x for each element.

#### BatchLnF32
```pascal
function BatchLnF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
```
Computes natural logarithm for each element.

#### BatchLog10F32
```pascal
function BatchLog10F32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
```
Computes base-10 logarithm for each element.

#### BatchLog2F32
```pascal
function BatchLog2F32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
```
Computes base-2 logarithm for each element.

#### BatchSqrtF32
```pascal
function BatchSqrtF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
```
Computes square root for each element.

#### BatchAbsF32
```pascal
function BatchAbsF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
```
Computes absolute value for each element.

#### BatchNegF32
```pascal
function BatchNegF32(const AInput: array of Single;
                    var AOutput: array of Single): SizeInt;
```
Negates each element.

#### BatchCeilF32
```pascal
function BatchCeilF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
```
Computes ceiling for each element.

#### BatchFloorF32
```pascal
function BatchFloorF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
```
Computes floor for each element.

#### BatchRoundF32
```pascal
function BatchRoundF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
```
Rounds each element to nearest integer.

#### BatchTruncF32
```pascal
function BatchTruncF32(const AInput: array of Single;
                      var AOutput: array of Single): SizeInt;
```
Truncates each element toward zero.

#### BatchLerpF32
```pascal
function BatchLerpF32(const AStart, AEnd: array of Single;
                      const AT: Single;
                      var AOutput: array of Single): SizeInt;
```
Linearly interpolates between arrays: `start + t * (end - start)`.

#### BatchClampF32
```pascal
function BatchClampF32(const AInput: array of Single;
                       const AMin, AMax: Single;
                       var AOutput: array of Single): SizeInt;
```
Clamps each element to [min, max] range.

#### BatchScaleOffsetF32
```pascal
function BatchScaleOffsetF32(const AInput: array of Single;
                             const AScale, AOffset: Single;
                             var AOutput: array of Single): SizeInt;
```
Computes `input * scale + offset` for each element.

### SIMD Batch Operations

`nextpas.core.math.batch.simd` provides SIMD-optimized variants of the scalar batch operations above.
These use SSE/AVX intrinsics via `nextpas.core.simd` for 4-wide F32 processing, with scalar fallback
for remaining elements when the count is not a multiple of 4.

SIMD batch functions mirror the scalar batch signatures exactly:

#### BatchSinSimdF32 / BatchCosSimdF32 / BatchTanSimdF32
```pascal
function BatchSinSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchCosSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchTanSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
```
SIMD-ready trigonometric batch operations.

#### BatchSinCosSimdF32
```pascal
function BatchSinCosSimdF32(const AInput: array of Single;
                            var ASinOutput, ACosOutput: array of Single): SizeInt;
```
Computes both sin and cos in a single pass, writing to two output arrays.

#### BatchExpSimdF32 / BatchLnSimdF32 / BatchLog2SimdF32 / BatchLog10SimdF32
```pascal
function BatchExpSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchLnSimdF32(const AInput: array of Single;
                        var AOutput: array of Single): SizeInt;
function BatchLog2SimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
function BatchLog10SimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
```
SIMD-ready exponential and logarithmic batch operations.

#### BatchSqrtSimdF32 / BatchAbsSimdF32 / BatchNegSimdF32
```pascal
function BatchSqrtSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
function BatchAbsSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchNegSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
```
SIMD-ready sqrt (SQRTPS), abs (ANDPS sign mask), and negation (XORPS sign mask).

#### BatchCeilSimdF32 / BatchFloorSimdF32 / BatchRoundSimdF32 / BatchTruncSimdF32
```pascal
function BatchCeilSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
function BatchFloorSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
function BatchRoundSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
function BatchTruncSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
```
SIMD-ready rounding operations using SSE4.1 ROUNDPS.

#### BatchLerpSimdF32
```pascal
function BatchLerpSimdF32(const AStart, AEnd: array of Single;
                          const AT: Single;
                          var AOutput: array of Single): SizeInt;
```
SIMD-ready linear interpolation using FMA: `fma(t, b-a, a)`.

#### BatchClampSimdF32 / BatchScaleOffsetSimdF32
```pascal
function BatchClampSimdF32(const AInput: array of Single;
                           const AMin, AMax: Single;
                           var AOutput: array of Single): SizeInt;
function BatchScaleOffsetSimdF32(const AInput: array of Single;
                                 const AScale, AOffset: Single;
                                 var AOutput: array of Single): SizeInt;
```
SIMD-ready clamp (MINPS+MAXPS) and scale+offset (FMA).

**Note:** The SIMD suffix signals the dispatch path; the public facade `nextpas.core.math` does not
re-export these functions. They are available through direct import of `nextpas.core.math.batch.simd`.

## Vector Types

### TVec2f
2D vector with Single precision. Fields: X, Y.

### TVec3f
3D vector with Single precision. Fields: X, Y, Z.

### TVec4f
4D vector with Single precision. Fields: X, Y, Z, W.

### TVec2d, TVec3d, TVec4d
Double precision variants.

## Matrix Types

### TMat3f
3x3 matrix with Single precision.

### TMat4f
4x4 matrix with Single precision.

### TMat3d, TMat4d
Double precision variants.

## Quaternion Types

### TQuatf
Quaternion with Single precision. Fields: X, Y, Z, W.

### TQuatd
Double precision variant.

## Constants

### PI_VALUE
```pascal
PI_VALUE: Double = 3.14159265358979323846;
```

### TWO_PI
```pascal
TWO_PI: Double = 6.28318530717958647692;
```

### HALF_PI
```pascal
HALF_PI: Double = 1.57079632679489661923;
```

### DEG_TO_RAD
```pascal
DEG_TO_RAD: Double = 0.01745329251994329577;
```

### RAD_TO_DEG
```pascal
RAD_TO_DEG: Double = 57.2957795130823208768;
```
