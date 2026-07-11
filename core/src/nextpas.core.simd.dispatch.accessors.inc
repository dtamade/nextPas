// === Dispatch Table Accessor Helpers ===
// These records provide sub-record access to the flat dispatch table
// They are zero-cost wrappers that reinterpret the flat fields as organized sub-records

type
  // Helper to access F32x4 operations as a sub-record
  TF32x4Accessor = record
  private
    FTable: PSimdDispatchTable;
  public
    constructor Create(aTable: PSimdDispatchTable);
    function Add(const a, b: TVecF32x4): TVecF32x4; inline;
    function Sub(const a, b: TVecF32x4): TVecF32x4; inline;
    function Mul(const a, b: TVecF32x4): TVecF32x4; inline;
    function Divide(const a, b: TVecF32x4): TVecF32x4; inline;
    function Neg(const a: TVecF32x4): TVecF32x4; inline;
    function Abs(const a: TVecF32x4): TVecF32x4; inline;
    function Sqrt(const a: TVecF32x4): TVecF32x4; inline;
    function Min(const a, b: TVecF32x4): TVecF32x4; inline;
    function Max(const a, b: TVecF32x4): TVecF32x4; inline;
    function Clamp(const a, minVal, maxVal: TVecF32x4): TVecF32x4; inline;
    function Fma(const a, b, c: TVecF32x4): TVecF32x4; inline;
    function Floor(const a: TVecF32x4): TVecF32x4; inline;
    function Ceil(const a: TVecF32x4): TVecF32x4; inline;
    function Round(const a: TVecF32x4): TVecF32x4; inline;
    function Trunc(const a: TVecF32x4): TVecF32x4; inline;
    function Rcp(const a: TVecF32x4): TVecF32x4; inline;
    function Rsqrt(const a: TVecF32x4): TVecF32x4; inline;
    function CmpEq(const a, b: TVecF32x4): TMask4; inline;
    function CmpLt(const a, b: TVecF32x4): TMask4; inline;
    function CmpLe(const a, b: TVecF32x4): TMask4; inline;
    function CmpGt(const a, b: TVecF32x4): TMask4; inline;
    function CmpGe(const a, b: TVecF32x4): TMask4; inline;
    function CmpNe(const a, b: TVecF32x4): TMask4; inline;
    function Dot4(const a, b: TVecF32x4): Single; inline;
    function Dot3(const a, b: TVecF32x4): Single; inline;
    function Cross3(const a, b: TVecF32x4): TVecF32x4; inline;
    function Length4(const a: TVecF32x4): Single; inline;
    function Length3(const a: TVecF32x4): Single; inline;
    function Normalize4(const a: TVecF32x4): TVecF32x4; inline;
    function Normalize3(const a: TVecF32x4): TVecF32x4; inline;
    function ReduceAdd(const a: TVecF32x4): Single; inline;
    function ReduceMin(const a: TVecF32x4): Single; inline;
    function ReduceMax(const a: TVecF32x4): Single; inline;
    function ReduceMul(const a: TVecF32x4): Single; inline;
    function Load(p: PSingle): TVecF32x4; inline;
    function LoadAligned(p: PSingle): TVecF32x4; inline;
    procedure Store(p: PSingle; const a: TVecF32x4); inline;
    procedure StoreAligned(p: PSingle; const a: TVecF32x4); inline;
    function Splat(value: Single): TVecF32x4; inline;
    function Zero: TVecF32x4; inline;
    function Make(x, y, z, w: Single): TVecF32x4; inline;
    function Select(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4; inline;
    function Extract(const a: TVecF32x4; index: Integer): Single; inline;
    function Insert(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4; inline;
  end;

  // Helper to access F64x2 operations as a sub-record
  TF64x2Accessor = record
  private
    FTable: PSimdDispatchTable;
  public
    constructor Create(aTable: PSimdDispatchTable);
    function Add(const a, b: TVecF64x2): TVecF64x2; inline;
    function Sub(const a, b: TVecF64x2): TVecF64x2; inline;
    function Mul(const a, b: TVecF64x2): TVecF64x2; inline;
    function Divide(const a, b: TVecF64x2): TVecF64x2; inline;
    function Neg(const a: TVecF64x2): TVecF64x2; inline;
    function Abs(const a: TVecF64x2): TVecF64x2; inline;
    function Sqrt(const a: TVecF64x2): TVecF64x2; inline;
    function Min(const a, b: TVecF64x2): TVecF64x2; inline;
    function Max(const a, b: TVecF64x2): TVecF64x2; inline;
    function Clamp(const a, minVal, maxVal: TVecF64x2): TVecF64x2; inline;
    function Fma(const a, b, c: TVecF64x2): TVecF64x2; inline;
    function Floor(const a: TVecF64x2): TVecF64x2; inline;
    function Ceil(const a: TVecF64x2): TVecF64x2; inline;
    function Round(const a: TVecF64x2): TVecF64x2; inline;
    function Trunc(const a: TVecF64x2): TVecF64x2; inline;
    function CmpEq(const a, b: TVecF64x2): TMask2; inline;
    function CmpLt(const a, b: TVecF64x2): TMask2; inline;
    function CmpLe(const a, b: TVecF64x2): TMask2; inline;
    function CmpGt(const a, b: TVecF64x2): TMask2; inline;
    function CmpGe(const a, b: TVecF64x2): TMask2; inline;
    function CmpNe(const a, b: TVecF64x2): TMask2; inline;
    function Dot(const a, b: TVecF64x2): Double; inline;
    function ReduceAdd(const a: TVecF64x2): Double; inline;
    function ReduceMin(const a: TVecF64x2): Double; inline;
    function ReduceMax(const a: TVecF64x2): Double; inline;
    function ReduceMul(const a: TVecF64x2): Double; inline;
    function Load(p: PDouble): TVecF64x2; inline;
    function LoadAligned(p: PDouble): TVecF64x2; inline;
    procedure Store(p: PDouble; const a: TVecF64x2); inline;
    procedure StoreAligned(p: PDouble; const a: TVecF64x2); inline;
    function Splat(value: Double): TVecF64x2; inline;
    function Zero: TVecF64x2; inline;
    function Make(x, y: Double): TVecF64x2; inline;
    function Select(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2; inline;
    function Extract(const a: TVecF64x2; index: Integer): Double; inline;
    function Insert(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2; inline;
  end;

  // Helper to access Memory operations as a sub-record
  TMemoryAccessor = record
  private
    FTable: PSimdDispatchTable;
  public
    constructor Create(aTable: PSimdDispatchTable);
    function Equal(a, b: Pointer; len: SizeUInt): LongBool; inline;
    function FindByte(p: Pointer; len: SizeUInt; value: Byte): PtrInt; inline;
    function DiffRange(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean; inline;
    procedure Copy(src, dst: Pointer; len: SizeUInt); inline;
    procedure Fill(dst: Pointer; len: SizeUInt; value: Byte); inline;
    procedure Reverse(p: Pointer; len: SizeUInt); inline;
    function SumBytes(p: Pointer; len: SizeUInt): UInt64; inline;
    procedure MinMaxBytes(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte); inline;
    function CountByte(p: Pointer; len: SizeUInt; value: Byte): SizeUInt; inline;
    function Utf8Validate(p: Pointer; len: SizeUInt): Boolean; inline;
    function AsciiIEqual(a, b: Pointer; len: SizeUInt): Boolean; inline;
    procedure ToLowerAscii(p: Pointer; len: SizeUInt); inline;
    procedure ToUpperAscii(p: Pointer; len: SizeUInt); inline;
    function BytesIndexOf(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt; inline;
    function BitsetPopCount(p: Pointer; len: SizeUInt): SizeUInt; inline;
  end;

  // Helper to access Batch F32 operations as a sub-record
  TBatchF32Accessor = record
  private
    FTable: PSimdDispatchTable;
  public
    constructor Create(aTable: PSimdDispatchTable);
    procedure ArrayAdd(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArraySub(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayMul(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayDiv(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayMin(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayMax(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayAbs(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayNeg(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArraySqrt(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayRcp(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayRsqrt(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayAddScalar(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); inline;
    procedure ArrayMulScalar(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); inline;
    procedure ArrayClamp(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single); inline;
    procedure ArrayFma(aA, aB, aC, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayAxpy(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt); inline;
    function ReduceSum(aSrc: PSingle; aCount: SizeUInt): Single; inline;
    function ReduceDot(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single; inline;
    function ReduceMin(aSrc: PSingle; aCount: SizeUInt): Single; inline;
    function ReduceMax(aSrc: PSingle; aCount: SizeUInt): Single; inline;
    procedure ArrayExp(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayLog(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayPow(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single); inline;
    procedure ArraySin(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayCos(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayTan(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArraySinCos(aSrc, aSinDst, aCosDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayLog2(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayLog10(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayAtan2(aY, aX, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayHypot(aX, aY, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayCeil(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayFloor(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayRound(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayTrunc(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayFract(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayLerp(aStart, aEnd, aDst: PSingle; aCount: SizeUInt; aT: Single); inline;
    procedure ArrayMod(aSrc, aDst: PSingle; aCount: SizeUInt; aDivisor: Single); inline;
    procedure ArraySign(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayStep(aEdge, aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArraySmoothstep(aEdge0, aEdge1, aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayLinear(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single); inline;
    procedure ArrayAbsDiff(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayReLU(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
    procedure ArrayNorm(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single); inline;
    procedure ArrayLinearReLU(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single); inline;
  end;

  // Helper to access Batch F64 operations as a sub-record
  TBatchF64Accessor = record
  private
    FTable: PSimdDispatchTable;
  public
    constructor Create(aTable: PSimdDispatchTable);
    procedure ArrayAdd(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArraySub(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayMul(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayDiv(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayMin(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayMax(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayAbs(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayNeg(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArraySqrt(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayMulScalar(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); inline;
    procedure ArrayAddScalar(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); inline;
    procedure ArrayClamp(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double); inline;
    procedure ArrayLinear(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double); inline;
    procedure ArrayFma(aA, aB, aC, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayAxpy(aAlpha: Double; aX, aY, aDst: PDouble; aCount: SizeUInt); inline;
    function ReduceSum(aSrc: PDouble; aCount: SizeUInt): Double; inline;
    function ReduceDot(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double; inline;
    function ReduceMin(aSrc: PDouble; aCount: SizeUInt): Double; inline;
    function ReduceMax(aSrc: PDouble; aCount: SizeUInt): Double; inline;
    procedure ArraySin(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayCos(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArraySinCos(aSrc, aSinDst, aCosDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayExp(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayLog(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayLog2(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayLog10(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayCeil(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayFloor(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayRound(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayTrunc(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayTan(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArraySign(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayFract(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayMod(aSrc, aDst: PDouble; aCount: SizeUInt; aDivisor: Double); inline;
    procedure ArrayPow(aSrc, aDst: PDouble; aCount: SizeUInt; aExponent: Double); inline;
    procedure ArrayLerp(aStart, aEnd, aDst: PDouble; aCount: SizeUInt; aT: Double); inline;
    procedure ArrayReLU(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayAbsDiff(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayNorm(aSrc, aDst: PDouble; aCount: SizeUInt; aMean, aInvStd: Double); inline;
    procedure ArrayLinearReLU(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double); inline;
    procedure ArrayStep(aEdge, aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArraySmoothstep(aEdge0, aEdge1, aSrc, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayAtan2(aY, aX, aDst: PDouble; aCount: SizeUInt); inline;
    procedure ArrayHypot(aX, aY, aDst: PDouble; aCount: SizeUInt); inline;
  end;

  // Helper to access I32x4 operations as a sub-record
  TI32x4Accessor = record
  private
    FTable: PSimdDispatchTable;
  public
    constructor Create(aTable: PSimdDispatchTable);
    function Add(const a, b: TVecI32x4): TVecI32x4; inline;
    function Sub(const a, b: TVecI32x4): TVecI32x4; inline;
    function Mul(const a, b: TVecI32x4): TVecI32x4; inline;
    function Neg(const a: TVecI32x4): TVecI32x4; inline;
    function BitAnd(const a, b: TVecI32x4): TVecI32x4; inline;
    function BitOr(const a, b: TVecI32x4): TVecI32x4; inline;
    function BitXor(const a, b: TVecI32x4): TVecI32x4; inline;
    function BitNot(const a: TVecI32x4): TVecI32x4; inline;
    function BitAndNot(const a, b: TVecI32x4): TVecI32x4; inline;
    function ShiftLeft(const a: TVecI32x4; count: Integer): TVecI32x4; inline;
    function ShiftRight(const a: TVecI32x4; count: Integer): TVecI32x4; inline;
    function ShiftRightArith(const a: TVecI32x4; count: Integer): TVecI32x4; inline;
    function CmpEq(const a, b: TVecI32x4): TMask4; inline;
    function CmpLt(const a, b: TVecI32x4): TMask4; inline;
    function CmpGt(const a, b: TVecI32x4): TMask4; inline;
    function CmpLe(const a, b: TVecI32x4): TMask4; inline;
    function CmpGe(const a, b: TVecI32x4): TMask4; inline;
    function CmpNe(const a, b: TVecI32x4): TMask4; inline;
    function Min(const a, b: TVecI32x4): TVecI32x4; inline;
    function Max(const a, b: TVecI32x4): TVecI32x4; inline;
    function Load(p: PInt32): TVecI32x4; inline;
    function LoadAligned(p: PInt32): TVecI32x4; inline;
    procedure Store(p: PInt32; const a: TVecI32x4); inline;
    procedure StoreAligned(p: PInt32; const a: TVecI32x4); inline;
    function Splat(value: Int32): TVecI32x4; inline;
    function Zero: TVecI32x4; inline;
    function Make(x, y, z, w: Int32): TVecI32x4; inline;
    function Select(const mask: TMask4; const a, b: TVecI32x4): TVecI32x4; inline;
    function Extract(const a: TVecI32x4; index: Integer): Int32; inline;
    function Insert(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4; inline;
  end;

  // Helper to access Mask operations as a sub-record
  TMaskAccessor = record
  private
    FTable: PSimdDispatchTable;
  public
    constructor Create(aTable: PSimdDispatchTable);
    function Mask2All(mask: TMask2): Boolean; inline;
    function Mask2Any(mask: TMask2): Boolean; inline;
    function Mask2None(mask: TMask2): Boolean; inline;
    function Mask2PopCount(mask: TMask2): Integer; inline;
    function Mask2FirstSet(mask: TMask2): Integer; inline;
    function Mask4All(mask: TMask4): Boolean; inline;
    function Mask4Any(mask: TMask4): Boolean; inline;
    function Mask4None(mask: TMask4): Boolean; inline;
    function Mask4PopCount(mask: TMask4): Integer; inline;
    function Mask4FirstSet(mask: TMask4): Integer; inline;
    function Mask8All(mask: TMask8): Boolean; inline;
    function Mask8Any(mask: TMask8): Boolean; inline;
    function Mask8None(mask: TMask8): Boolean; inline;
    function Mask8PopCount(mask: TMask8): Integer; inline;
    function Mask8FirstSet(mask: TMask8): Integer; inline;
    function Mask16All(mask: TMask16): Boolean; inline;
    function Mask16Any(mask: TMask16): Boolean; inline;
    function Mask16None(mask: TMask16): Boolean; inline;
    function Mask16PopCount(mask: TMask16): Integer; inline;
    function Mask16FirstSet(mask: TMask16): Integer; inline;
  end;

  // Helper to access Batch Integer operations as a sub-record
  TBatchIntegerAccessor = record
  private
    FTable: PSimdDispatchTable;
  public
    constructor Create(aTable: PSimdDispatchTable);
    procedure ArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
    procedure ArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
    procedure ArrayAndI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
    procedure ArrayOrI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
    procedure ArrayXorI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
    procedure ArrayShlI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer); inline;
    procedure ArrayShrI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer); inline;
    procedure ArrayAddI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
    procedure ArraySubI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
    procedure ArrayMulI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
    procedure ArrayAndI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
    procedure ArrayOrI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
    procedure ArrayXorI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
    procedure ArrayPackSatI32toI16(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt); inline;
    procedure ArrayAddI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
    procedure ArraySubI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
    procedure ArrayMulI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
    procedure ArrayAndI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
    procedure ArrayOrI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
    procedure ArrayXorI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
    procedure ArrayAddU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
    procedure ArraySubU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
    procedure ArrayMulU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
    procedure ArrayAndU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
    procedure ArrayOrU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
    procedure ArrayXorU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
    procedure ArrayAddU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
    procedure ArraySubU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
    procedure ArrayMulU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
    procedure ArrayAndU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
    procedure ArrayOrU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
    procedure ArrayXorU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
    procedure ArrayAddU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
    procedure ArraySubU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
    procedure ArrayMulU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
    procedure ArrayAndU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
    procedure ArrayOrU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
    procedure ArrayXorU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
    procedure ArrayAddI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
    procedure ArraySubI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
    procedure ArrayMulI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
    procedure ArrayAndI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
    procedure ArrayOrI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
    procedure ArrayXorI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
    procedure ArrayAddU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
    procedure ArraySubU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
    procedure ArrayMulU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
    procedure ArrayAndU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
    procedure ArrayOrU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
    procedure ArrayXorU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
    procedure ArrayF32toI32(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt); inline;
    procedure ArrayI32toF32(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt); inline;
  end;
