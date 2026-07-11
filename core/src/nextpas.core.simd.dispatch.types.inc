// === Dispatch Table Sub-Record Types ===
// Modular organization of TSimdDispatchTable into logical groups

// 1. Core Vector Operations - F32x4 (128-bit)
TSimdVecF32x4Ops = record
  // Arithmetic
  Add: function(const a, b: TVecF32x4): TVecF32x4;
  Sub: function(const a, b: TVecF32x4): TVecF32x4;
  Mul: function(const a, b: TVecF32x4): TVecF32x4;
  Divide: function(const a, b: TVecF32x4): TVecF32x4;
  Neg: function(const a: TVecF32x4): TVecF32x4;
  Abs: function(const a: TVecF32x4): TVecF32x4;
  Sqrt: function(const a: TVecF32x4): TVecF32x4;
  // Min/Max/Clamp
  Min: function(const a, b: TVecF32x4): TVecF32x4;
  Max: function(const a, b: TVecF32x4): TVecF32x4;
  Clamp: function(const a, minVal, maxVal: TVecF32x4): TVecF32x4;
  // FMA
  Fma: function(const a, b, c: TVecF32x4): TVecF32x4;
  // Rounding
  Floor: function(const a: TVecF32x4): TVecF32x4;
  Ceil: function(const a: TVecF32x4): TVecF32x4;
  Round: function(const a: TVecF32x4): TVecF32x4;
  Trunc: function(const a: TVecF32x4): TVecF32x4;
  // Extended math
  Rcp: function(const a: TVecF32x4): TVecF32x4;
  Rsqrt: function(const a: TVecF32x4): TVecF32x4;
  // Comparison
  CmpEq: function(const a, b: TVecF32x4): TMask4;
  CmpLt: function(const a, b: TVecF32x4): TMask4;
  CmpLe: function(const a, b: TVecF32x4): TMask4;
  CmpGt: function(const a, b: TVecF32x4): TMask4;
  CmpGe: function(const a, b: TVecF32x4): TMask4;
  CmpNe: function(const a, b: TVecF32x4): TMask4;
  // 3D/4D Vector math
  Dot4: function(const a, b: TVecF32x4): Single;
  Dot3: function(const a, b: TVecF32x4): Single;
  Cross3: function(const a, b: TVecF32x4): TVecF32x4;
  Length4: function(const a: TVecF32x4): Single;
  Length3: function(const a: TVecF32x4): Single;
  Normalize4: function(const a: TVecF32x4): TVecF32x4;
  Normalize3: function(const a: TVecF32x4): TVecF32x4;
  // Reduction
  ReduceAdd: function(const a: TVecF32x4): Single;
  ReduceMin: function(const a: TVecF32x4): Single;
  ReduceMax: function(const a: TVecF32x4): Single;
  ReduceMul: function(const a: TVecF32x4): Single;
  // Memory
  Load: function(p: PSingle): TVecF32x4;
  LoadAligned: function(p: PSingle): TVecF32x4;
  Store: procedure(p: PSingle; const a: TVecF32x4);
  StoreAligned: procedure(p: PSingle; const a: TVecF32x4);
  // Utility
  Splat: function(value: Single): TVecF32x4;
  Zero: function: TVecF32x4;
  Make: function(x, y, z, w: Single): TVecF32x4;
  Select: function(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
  Extract: function(const a: TVecF32x4; index: Integer): Single;
  Insert: function(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;
end;

// 2. Core Vector Operations - F64x2 (128-bit)
TSimdVecF64x2Ops = record
  // Arithmetic
  Add: function(const a, b: TVecF64x2): TVecF64x2;
  Sub: function(const a, b: TVecF64x2): TVecF64x2;
  Mul: function(const a, b: TVecF64x2): TVecF64x2;
  Divide: function(const a, b: TVecF64x2): TVecF64x2;
  Neg: function(const a: TVecF64x2): TVecF64x2;
  Abs: function(const a: TVecF64x2): TVecF64x2;
  Sqrt: function(const a: TVecF64x2): TVecF64x2;
  // Min/Max/Clamp
  Min: function(const a, b: TVecF64x2): TVecF64x2;
  Max: function(const a, b: TVecF64x2): TVecF64x2;
  Clamp: function(const a, minVal, maxVal: TVecF64x2): TVecF64x2;
  // FMA
  Fma: function(const a, b, c: TVecF64x2): TVecF64x2;
  // Rounding
  Floor: function(const a: TVecF64x2): TVecF64x2;
  Ceil: function(const a: TVecF64x2): TVecF64x2;
  Round: function(const a: TVecF64x2): TVecF64x2;
  Trunc: function(const a: TVecF64x2): TVecF64x2;
  // Comparison
  CmpEq: function(const a, b: TVecF64x2): TMask2;
  CmpLt: function(const a, b: TVecF64x2): TMask2;
  CmpLe: function(const a, b: TVecF64x2): TMask2;
  CmpGt: function(const a, b: TVecF64x2): TMask2;
  CmpGe: function(const a, b: TVecF64x2): TMask2;
  CmpNe: function(const a, b: TVecF64x2): TMask2;
  // Dot product
  Dot: function(const a, b: TVecF64x2): Double;
  // Reduction
  ReduceAdd: function(const a: TVecF64x2): Double;
  ReduceMin: function(const a: TVecF64x2): Double;
  ReduceMax: function(const a: TVecF64x2): Double;
  ReduceMul: function(const a: TVecF64x2): Double;
  // Memory
  Load: function(p: PDouble): TVecF64x2;
  LoadAligned: function(p: PDouble): TVecF64x2;
  Store: procedure(p: PDouble; const a: TVecF64x2);
  StoreAligned: procedure(p: PDouble; const a: TVecF64x2);
  // Utility
  Splat: function(value: Double): TVecF64x2;
  Zero: function: TVecF64x2;
  Make: function(x, y: Double): TVecF64x2;
  Select: function(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;
  Extract: function(const a: TVecF64x2; index: Integer): Double;
  Insert: function(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
end;

// 3. Core Vector Operations - I32x4 (128-bit)
TSimdVecI32x4Ops = record
  // Arithmetic
  Add: function(const a, b: TVecI32x4): TVecI32x4;
  Sub: function(const a, b: TVecI32x4): TVecI32x4;
  Mul: function(const a, b: TVecI32x4): TVecI32x4;
  Neg: function(const a: TVecI32x4): TVecI32x4;
  // Bitwise
  BitAnd: function(const a, b: TVecI32x4): TVecI32x4;
  BitOr: function(const a, b: TVecI32x4): TVecI32x4;
  BitXor: function(const a, b: TVecI32x4): TVecI32x4;
  BitNot: function(const a: TVecI32x4): TVecI32x4;
  BitAndNot: function(const a, b: TVecI32x4): TVecI32x4;
  // Shift
  ShiftLeft: function(const a: TVecI32x4; count: Integer): TVecI32x4;
  ShiftRight: function(const a: TVecI32x4; count: Integer): TVecI32x4;
  ShiftRightArith: function(const a: TVecI32x4; count: Integer): TVecI32x4;
  // Comparison
  CmpEq: function(const a, b: TVecI32x4): TMask4;
  CmpLt: function(const a, b: TVecI32x4): TMask4;
  CmpGt: function(const a, b: TVecI32x4): TMask4;
  CmpLe: function(const a, b: TVecI32x4): TMask4;
  CmpGe: function(const a, b: TVecI32x4): TMask4;
  CmpNe: function(const a, b: TVecI32x4): TMask4;
  // Min/Max
  Min: function(const a, b: TVecI32x4): TVecI32x4;
  Max: function(const a, b: TVecI32x4): TVecI32x4;
  // Memory
  Load: function(p: PInt32): TVecI32x4;
  LoadAligned: function(p: PInt32): TVecI32x4;
  Store: procedure(p: PInt32; const a: TVecI32x4);
  StoreAligned: procedure(p: PInt32; const a: TVecI32x4);
  // Utility
  Splat: function(value: Int32): TVecI32x4;
  Zero: function: TVecI32x4;
  Make: function(x, y, z, w: Int32): TVecI32x4;
  Select: function(const mask: TMask4; const a, b: TVecI32x4): TVecI32x4;
  Extract: function(const a: TVecI32x4; index: Integer): Int32;
  Insert: function(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
end;

// 4. Memory Operations
TSimdMemoryOps = record
  // Byte-level operations
  Equal: function(a, b: Pointer; len: SizeUInt): LongBool;
  FindByte: function(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
  DiffRange: function(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
  Copy: procedure(src, dst: Pointer; len: SizeUInt);
  Fill: procedure(dst: Pointer; len: SizeUInt; value: Byte);
  Reverse: procedure(p: Pointer; len: SizeUInt);
  // Aggregate operations
  SumBytes: function(p: Pointer; len: SizeUInt): UInt64;
  MinMaxBytes: procedure(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
  CountByte: function(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
  // String operations
  Utf8Validate: function(p: Pointer; len: SizeUInt): Boolean;
  AsciiIEqual: function(a, b: Pointer; len: SizeUInt): Boolean;
  ToLowerAscii: procedure(p: Pointer; len: SizeUInt);
  ToUpperAscii: procedure(p: Pointer; len: SizeUInt);
  BytesIndexOf: function(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;
  // Bitset operations
  BitsetPopCount: function(p: Pointer; len: SizeUInt): SizeUInt;
end;

// 5. Mask Operations
TSimdMaskOps = record
  // TMask2 (2 elements)
  Mask2All: function(mask: TMask2): Boolean;
  Mask2Any: function(mask: TMask2): Boolean;
  Mask2None: function(mask: TMask2): Boolean;
  Mask2PopCount: function(mask: TMask2): Integer;
  Mask2FirstSet: function(mask: TMask2): Integer;
  // TMask4 (4 elements)
  Mask4All: function(mask: TMask4): Boolean;
  Mask4Any: function(mask: TMask4): Boolean;
  Mask4None: function(mask: TMask4): Boolean;
  Mask4PopCount: function(mask: TMask4): Integer;
  Mask4FirstSet: function(mask: TMask4): Integer;
  // TMask8 (8 elements)
  Mask8All: function(mask: TMask8): Boolean;
  Mask8Any: function(mask: TMask8): Boolean;
  Mask8None: function(mask: TMask8): Boolean;
  Mask8PopCount: function(mask: TMask8): Integer;
  Mask8FirstSet: function(mask: TMask8): Integer;
  // TMask16 (16 elements)
  Mask16All: function(mask: TMask16): Boolean;
  Mask16Any: function(mask: TMask16): Boolean;
  Mask16None: function(mask: TMask16): Boolean;
  Mask16PopCount: function(mask: TMask16): Integer;
  Mask16FirstSet: function(mask: TMask16): Integer;
end;

// 6. Batch Array Operations - F32
TSimdBatchF32Ops = record
  // Basic arithmetic
  ArrayAdd: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  ArraySub: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  ArrayMul: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  ArrayDiv: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  // Min/Max
  ArrayMin: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  ArrayMax: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  // Unary
  ArrayAbs: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayNeg: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArraySqrt: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  // Extended
  ArrayRcp: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayRsqrt: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayRcpRefine: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayRsqrtRefine: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  // Scalar operations
  ArrayAddScalar: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
  ArrayMulScalar: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
  // Clamp
  ArrayClamp: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
  // FMA
  ArrayFma: procedure(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
  // AXPY
  ArrayAxpy: procedure(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
  // Reduction
  ReduceSum: function(aSrc: PSingle; aCount: SizeUInt): Single;
  ReduceDot: function(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
  ReduceMin: function(aSrc: PSingle; aCount: SizeUInt): Single;
  ReduceMax: function(aSrc: PSingle; aCount: SizeUInt): Single;
  // Transcendental
  ArrayExp: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayLog: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayPow: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
  ArraySin: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayCos: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayTan: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArraySinCos: procedure(aSrc, aSinDst, aCosDst: PSingle; aCount: SizeUInt);
  ArrayLog2: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayLog10: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayAtan2: procedure(aY, aX, aDst: PSingle; aCount: SizeUInt);
  ArrayHypot: procedure(aX, aY, aDst: PSingle; aCount: SizeUInt);
  // Rounding
  ArrayCeil: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayFloor: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayRound: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayTrunc: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayFract: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  // Interpolation
  ArrayLerp: procedure(aStart, aEnd, aDst: PSingle; aCount: SizeUInt; aT: Single);
  // Utility
  ArrayMod: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aDivisor: Single);
  ArraySign: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayStep: procedure(aEdge, aSrc, aDst: PSingle; aCount: SizeUInt);
  ArraySmoothstep: procedure(aEdge0, aEdge1, aSrc, aDst: PSingle; aCount: SizeUInt);
  // Fused
  ArrayLinear: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
  ArrayAbsDiff: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  ArrayReLU: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
  ArrayNorm: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single);
  ArrayLinearReLU: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
end;

// 7. Batch Array Operations - F64
TSimdBatchF64Ops = record
  // Basic arithmetic
  ArrayAdd: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  ArraySub: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  ArrayMul: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  ArrayDiv: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  // Min/Max
  ArrayMin: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  ArrayMax: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  // Unary
  ArrayAbs: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayNeg: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArraySqrt: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  // Scalar operations
  ArrayMulScalar: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
  ArrayAddScalar: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
  // Clamp
  ArrayClamp: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
  // Linear
  ArrayLinear: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
  // FMA
  ArrayFma: procedure(aA, aB, aC, aDst: PDouble; aCount: SizeUInt);
  // AXPY
  ArrayAxpy: procedure(aAlpha: Double; aX, aY, aDst: PDouble; aCount: SizeUInt);
  // Reduction
  ReduceSum: function(aSrc: PDouble; aCount: SizeUInt): Double;
  ReduceDot: function(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
  ReduceMin: function(aSrc: PDouble; aCount: SizeUInt): Double;
  ReduceMax: function(aSrc: PDouble; aCount: SizeUInt): Double;
  // Transcendental
  ArraySin: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayCos: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArraySinCos: procedure(aSrc, aSinDst, aCosDst: PDouble; aCount: SizeUInt);
  ArrayExp: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayLog: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayLog2: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayLog10: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayCeil: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayFloor: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayRound: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayTrunc: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  // Extended
  ArrayTan: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArraySign: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayFract: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayMod: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aDivisor: Double);
  ArrayPow: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aExponent: Double);
  ArrayLerp: procedure(aStart, aEnd, aDst: PDouble; aCount: SizeUInt; aT: Double);
  ArrayReLU: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayAbsDiff: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  ArrayNorm: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aMean, aInvStd: Double);
  ArrayLinearReLU: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
  ArrayStep: procedure(aEdge, aSrc, aDst: PDouble; aCount: SizeUInt);
  ArraySmoothstep: procedure(aEdge0, aEdge1, aSrc, aDst: PDouble; aCount: SizeUInt);
  ArrayAtan2: procedure(aY, aX, aDst: PDouble; aCount: SizeUInt);
  ArrayHypot: procedure(aX, aY, aDst: PDouble; aCount: SizeUInt);
end;

// 8. Batch Array Operations - Integer (I32, I16, I8, U32, U16, U8, I64, U64)
TSimdBatchIntegerOps = record
  // I32
  ArrayAddI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
  ArraySubI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
  ArrayAndI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
  ArrayOrI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
  ArrayXorI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
  ArrayShlI32: procedure(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
  ArrayShrI32: procedure(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
  // I16
  ArrayAddI16: procedure(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
  ArraySubI16: procedure(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
  ArrayMulI16: procedure(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
  ArrayAndI16: procedure(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
  ArrayOrI16: procedure(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
  ArrayXorI16: procedure(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
  ArrayPackSatI32toI16: procedure(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt);
  // I8
  ArrayAddI8: procedure(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
  ArraySubI8: procedure(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
  ArrayMulI8: procedure(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
  ArrayAndI8: procedure(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
  ArrayOrI8: procedure(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
  ArrayXorI8: procedure(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
  // U32
  ArrayAddU32: procedure(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
  ArraySubU32: procedure(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
  ArrayMulU32: procedure(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
  ArrayAndU32: procedure(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
  ArrayOrU32: procedure(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
  ArrayXorU32: procedure(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
  // U16
  ArrayAddU16: procedure(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
  ArraySubU16: procedure(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
  ArrayMulU16: procedure(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
  ArrayAndU16: procedure(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
  ArrayOrU16: procedure(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
  ArrayXorU16: procedure(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
  // U8
  ArrayAddU8: procedure(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
  ArraySubU8: procedure(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
  ArrayMulU8: procedure(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
  ArrayAndU8: procedure(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
  ArrayOrU8: procedure(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
  ArrayXorU8: procedure(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
  // I64
  ArrayAddI64: procedure(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
  ArraySubI64: procedure(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
  ArrayMulI64: procedure(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
  ArrayAndI64: procedure(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
  ArrayOrI64: procedure(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
  ArrayXorI64: procedure(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
  // U64
  ArrayAddU64: procedure(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
  ArraySubU64: procedure(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
  ArrayMulU64: procedure(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
  ArrayAndU64: procedure(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
  ArrayOrU64: procedure(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
  ArrayXorU64: procedure(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
  // Type conversion
  ArrayF32toI32: procedure(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt);
  ArrayI32toF32: procedure(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt);
end;
