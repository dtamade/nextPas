unit nextpas.core.simd.backend.iface;

{$mode objfpc}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.base;

// =============================================================================
// SIMD Backend Interface Abstraction
// =============================================================================
//
// Purpose:
//   Provides a cleaner abstraction for SIMD backend implementations.
//   Reduces code duplication by grouping operations into logical categories.
//
// Design Goals:
//   1. Single source of truth for operation signatures
//   2. Easier backend implementation via grouped interfaces
//   3. Better cache locality through smaller, focused tables
//   4. Simplified testing via operation group contracts
//
// Usage:
//   Each backend implements TSimdBackendOps and registers via RegisterBackendOps.
//   The dispatch system uses these grouped operations internally.
//
// =============================================================================

type
  // =========================================================================
  // Function Type Definitions - Grouped by Category
  // =========================================================================

  // --- F32x4 Binary Operations ---
  TBinaryOpF32x4 = function(const a, b: TVecF32x4): TVecF32x4;
  TUnaryOpF32x4 = function(const a: TVecF32x4): TVecF32x4;
  TReduceOpF32x4 = function(const a: TVecF32x4): Single;
  TCmpOpF32x4 = function(const a, b: TVecF32x4): TMask4;
  TTernaryOpF32x4 = function(const a, b, c: TVecF32x4): TVecF32x4;

  // --- F32x8 Binary Operations (256-bit) ---
  TBinaryOpF32x8 = function(const a, b: TVecF32x8): TVecF32x8;
  TUnaryOpF32x8 = function(const a: TVecF32x8): TVecF32x8;

  // --- F64x2 Binary Operations ---
  TBinaryOpF64x2 = function(const a, b: TVecF64x2): TVecF64x2;
  TUnaryOpF64x2 = function(const a: TVecF64x2): TVecF64x2;

  // --- F64x4 Binary Operations (256-bit) ---
  TBinaryOpF64x4 = function(const a, b: TVecF64x4): TVecF64x4;

  // --- I32x4 Operations ---
  TBinaryOpI32x4 = function(const a, b: TVecI32x4): TVecI32x4;
  TUnaryOpI32x4 = function(const a: TVecI32x4): TVecI32x4;
  TShiftOpI32x4 = function(const a: TVecI32x4; count: Integer): TVecI32x4;
  TCmpOpI32x4 = function(const a, b: TVecI32x4): TMask4;

  // --- I32x8 Operations (256-bit) ---
  TBinaryOpI32x8 = function(const a, b: TVecI32x8): TVecI32x8;
  TUnaryOpI32x8 = function(const a: TVecI32x8): TVecI32x8;
  TShiftOpI32x8 = function(const a: TVecI32x8; count: Integer): TVecI32x8;
  TCmpOpI32x8 = function(const a, b: TVecI32x8): TMask8;

  // --- I64x2 Operations ---
  TBinaryOpI64x2 = function(const a, b: TVecI64x2): TVecI64x2;
  TUnaryOpI64x2 = function(const a: TVecI64x2): TVecI64x2;

  // --- 512-bit Operations ---
  TBinaryOpF32x16 = function(const a, b: TVecF32x16): TVecF32x16;
  TBinaryOpF64x8 = function(const a, b: TVecF64x8): TVecF64x8;
  TBinaryOpI32x16 = function(const a, b: TVecI32x16): TVecI32x16;
  TUnaryOpI32x16 = function(const a: TVecI32x16): TVecI32x16;
  TShiftOpI32x16 = function(const a: TVecI32x16; count: Integer): TVecI32x16;
  TCmpOpI32x16 = function(const a, b: TVecI32x16): TMask16;

  // --- Memory Operations ---
  TLoadOpF32x4 = function(p: PSingle): TVecF32x4;
  TStoreOpF32x4 = procedure(p: PSingle; const a: TVecF32x4);
  TSplatOpF32x4 = function(value: Single): TVecF32x4;
  TZeroOpF32x4 = function: TVecF32x4;
  TSelectOpF32x4 = function(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
  TExtractOpF32x4 = function(const a: TVecF32x4; index: Integer): Single;
  TInsertOpF32x4 = function(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;

  // --- Vector Math Operations ---
  TDotOpF32x4 = function(const a, b: TVecF32x4): Single;
  TLengthOpF32x4 = function(const a: TVecF32x4): Single;
  TCrossOpF32x3 = function(const a, b: TVecF32x4): TVecF32x4;

  // --- Facade/Memory Buffer Operations ---
  TMemEqualOp = function(a, b: Pointer; len: SizeUInt): LongBool;
  TMemFindByteOp = function(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
  TMemDiffRangeOp = function(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
  TMemCopyOp = procedure(src, dst: Pointer; len: SizeUInt);
  TMemSetOp = procedure(dst: Pointer; len: SizeUInt; value: Byte);
  TMemReverseOp = procedure(p: Pointer; len: SizeUInt);
  TSumBytesOp = function(p: Pointer; len: SizeUInt): UInt64;
  TMinMaxBytesOp = procedure(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
  TCountByteOp = function(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
  TUtf8ValidateOp = function(p: Pointer; len: SizeUInt): Boolean;
  TAsciiIEqualOp = function(a, b: Pointer; len: SizeUInt): Boolean;
  TToLowerAsciiOp = procedure(p: Pointer; len: SizeUInt);
  TToUpperAsciiOp = procedure(p: Pointer; len: SizeUInt);
  TBytesIndexOfOp = function(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;
  TBitsetPopCountOp = function(p: Pointer; byteLen: SizeUInt): SizeUInt;

  // =========================================================================
  // Grouped Operation Records
  // =========================================================================

  // F32x4 Arithmetic Operations
  TArithmeticOpsF32x4 = record
    Add: TBinaryOpF32x4;
    Sub: TBinaryOpF32x4;
    Mul: TBinaryOpF32x4;
    OpDiv: TBinaryOpF32x4;
  end;

  // F32x4 Math Functions
  TMathOpsF32x4 = record
    Abs: TUnaryOpF32x4;
    Sqrt: TUnaryOpF32x4;
    Min: TBinaryOpF32x4;
    Max: TBinaryOpF32x4;
    Fma: TTernaryOpF32x4;
    Rcp: TUnaryOpF32x4;
    Rsqrt: TUnaryOpF32x4;
    Floor: TUnaryOpF32x4;
    Ceil: TUnaryOpF32x4;
    Round: TUnaryOpF32x4;
    Trunc: TUnaryOpF32x4;
    Clamp: TTernaryOpF32x4;
  end;

  // F32x4 Comparison Operations
  TComparisonOpsF32x4 = record
    CmpEq: TCmpOpF32x4;
    CmpLt: TCmpOpF32x4;
    CmpLe: TCmpOpF32x4;
    CmpGt: TCmpOpF32x4;
    CmpGe: TCmpOpF32x4;
    CmpNe: TCmpOpF32x4;
  end;

  // F32x4 Reduction Operations
  TReductionOpsF32x4 = record
    ReduceAdd: TReduceOpF32x4;
    ReduceMin: TReduceOpF32x4;
    ReduceMax: TReduceOpF32x4;
    ReduceMul: TReduceOpF32x4;
  end;

  // F32x4 Memory Operations
  TMemoryOpsF32x4 = record
    Load: TLoadOpF32x4;
    LoadAligned: TLoadOpF32x4;
    Store: TStoreOpF32x4;
    StoreAligned: TStoreOpF32x4;
    Splat: TSplatOpF32x4;
    Zero: TZeroOpF32x4;
    Select: TSelectOpF32x4;
    Extract: TExtractOpF32x4;
    Insert: TInsertOpF32x4;
  end;

  // F32x4 Vector Math
  TVectorMathOpsF32x4 = record
    Dot4: TDotOpF32x4;
    Dot3: TDotOpF32x4;
    Cross3: TCrossOpF32x3;
    Length4: TLengthOpF32x4;
    Length3: TLengthOpF32x4;
    Normalize4: TUnaryOpF32x4;
    Normalize3: TUnaryOpF32x4;
  end;

  // F32x8 Arithmetic Operations (256-bit)
  TArithmeticOpsF32x8 = record
    Add: TBinaryOpF32x8;
    Sub: TBinaryOpF32x8;
    Mul: TBinaryOpF32x8;
    OpDiv: TBinaryOpF32x8;
  end;

  // F64x2 Arithmetic Operations
  TArithmeticOpsF64x2 = record
    Add: TBinaryOpF64x2;
    Sub: TBinaryOpF64x2;
    Mul: TBinaryOpF64x2;
    OpDiv: TBinaryOpF64x2;
  end;

  // F64x4 Arithmetic Operations (256-bit)
  TArithmeticOpsF64x4 = record
    Add: TBinaryOpF64x4;
    Sub: TBinaryOpF64x4;
    Mul: TBinaryOpF64x4;
    OpDiv: TBinaryOpF64x4;
  end;

  // I32x4 Operations
  TArithmeticOpsI32x4 = record
    Add: TBinaryOpI32x4;
    Sub: TBinaryOpI32x4;
    Mul: TBinaryOpI32x4;
  end;

  TBitwiseOpsI32x4 = record
    OpAnd: TBinaryOpI32x4;
    OpOr: TBinaryOpI32x4;
    OpXor: TBinaryOpI32x4;
    OpNot: TUnaryOpI32x4;
    AndNot: TBinaryOpI32x4;
  end;

  TShiftOpsI32x4 = record
    ShiftLeft: TShiftOpI32x4;
    ShiftRight: TShiftOpI32x4;
    ShiftRightArith: TShiftOpI32x4;
  end;

  TComparisonOpsI32x4 = record
    CmpEq: TCmpOpI32x4;
    CmpLt: TCmpOpI32x4;
    CmpGt: TCmpOpI32x4;
  end;

  TMinMaxOpsI32x4 = record
    Min: TBinaryOpI32x4;
    Max: TBinaryOpI32x4;
  end;

  // I32x8 Operations (256-bit)
  TArithmeticOpsI32x8 = record
    Add: TBinaryOpI32x8;
    Sub: TBinaryOpI32x8;
    Mul: TBinaryOpI32x8;
  end;

  TBitwiseOpsI32x8 = record
    OpAnd: TBinaryOpI32x8;
    OpOr: TBinaryOpI32x8;
    OpXor: TBinaryOpI32x8;
    OpNot: TUnaryOpI32x8;
    AndNot: TBinaryOpI32x8;
  end;

  TShiftOpsI32x8 = record
    ShiftLeft: TShiftOpI32x8;
    ShiftRight: TShiftOpI32x8;
    ShiftRightArith: TShiftOpI32x8;
  end;

  TComparisonOpsI32x8 = record
    CmpEq: TCmpOpI32x8;
    CmpLt: TCmpOpI32x8;
    CmpGt: TCmpOpI32x8;
  end;

  TMinMaxOpsI32x8 = record
    Min: TBinaryOpI32x8;
    Max: TBinaryOpI32x8;
  end;

  // I64x2 Operations
  TArithmeticOpsI64x2 = record
    Add: TBinaryOpI64x2;
    Sub: TBinaryOpI64x2;
  end;

  TBitwiseOpsI64x2 = record
    OpAnd: TBinaryOpI64x2;
    OpOr: TBinaryOpI64x2;
    OpXor: TBinaryOpI64x2;
    OpNot: TUnaryOpI64x2;
  end;

  // 512-bit Operations
  TArithmeticOpsF32x16 = record
    Add: TBinaryOpF32x16;
    Sub: TBinaryOpF32x16;
    Mul: TBinaryOpF32x16;
    OpDiv: TBinaryOpF32x16;
  end;

  TArithmeticOpsF64x8 = record
    Add: TBinaryOpF64x8;
    Sub: TBinaryOpF64x8;
    Mul: TBinaryOpF64x8;
    OpDiv: TBinaryOpF64x8;
  end;

  TArithmeticOpsI32x16 = record
    Add: TBinaryOpI32x16;
    Sub: TBinaryOpI32x16;
    Mul: TBinaryOpI32x16;
  end;

  TBitwiseOpsI32x16 = record
    OpAnd: TBinaryOpI32x16;
    OpOr: TBinaryOpI32x16;
    OpXor: TBinaryOpI32x16;
    OpNot: TUnaryOpI32x16;
    AndNot: TBinaryOpI32x16;
  end;

  TShiftOpsI32x16 = record
    ShiftLeft: TShiftOpI32x16;
    ShiftRight: TShiftOpI32x16;
    ShiftRightArith: TShiftOpI32x16;
  end;

  TComparisonOpsI32x16 = record
    CmpEq: TCmpOpI32x16;
    CmpLt: TCmpOpI32x16;
    CmpGt: TCmpOpI32x16;
  end;

  TMinMaxOpsI32x16 = record
    Min: TBinaryOpI32x16;
    Max: TBinaryOpI32x16;
  end;

  // Facade Operations (High-Level Buffer Operations)
  TFacadeOps = record
    MemEqual: TMemEqualOp;
    MemFindByte: TMemFindByteOp;
    MemDiffRange: TMemDiffRangeOp;
    MemCopy: TMemCopyOp;
    MemSet: TMemSetOp;
    MemReverse: TMemReverseOp;
    SumBytes: TSumBytesOp;
    MinMaxBytes: TMinMaxBytesOp;
    CountByte: TCountByteOp;
    Utf8Validate: TUtf8ValidateOp;
    AsciiIEqual: TAsciiIEqualOp;
    ToLowerAscii: TToLowerAsciiOp;
    ToUpperAscii: TToUpperAsciiOp;
    BytesIndexOf: TBytesIndexOfOp;
    BitsetPopCount: TBitsetPopCountOp;
  end;

  // =========================================================================
  // Master Backend Operations Record
  // =========================================================================
  //
  // This replaces the flat TSimdDispatchTable with a hierarchical structure.
  // Benefits:
  //   - Better organization and readability
  //   - Smaller cache footprint for commonly used operations
  //   - Easier to extend with new operation groups
  //   - Clearer documentation of what each backend must implement
  //
  TSimdBackendOps = record
    // Backend identification
    Backend: TSimdBackend;
    BackendInfo: TSimdBackendInfo;

    // 128-bit F32x4 Operations
    ArithmeticF32x4: TArithmeticOpsF32x4;
    MathF32x4: TMathOpsF32x4;
    ComparisonF32x4: TComparisonOpsF32x4;
    ReductionF32x4: TReductionOpsF32x4;
    MemoryF32x4: TMemoryOpsF32x4;
    VectorMathF32x4: TVectorMathOpsF32x4;

    // 256-bit F32x8 Operations
    ArithmeticF32x8: TArithmeticOpsF32x8;

    // 128-bit F64x2 Operations
    ArithmeticF64x2: TArithmeticOpsF64x2;

    // 256-bit F64x4 Operations
    ArithmeticF64x4: TArithmeticOpsF64x4;

    // 128-bit I32x4 Operations
    ArithmeticI32x4: TArithmeticOpsI32x4;
    BitwiseI32x4: TBitwiseOpsI32x4;
    ShiftI32x4: TShiftOpsI32x4;
    ComparisonI32x4: TComparisonOpsI32x4;
    MinMaxI32x4: TMinMaxOpsI32x4;

    // 256-bit I32x8 Operations
    ArithmeticI32x8: TArithmeticOpsI32x8;
    BitwiseI32x8: TBitwiseOpsI32x8;
    ShiftI32x8: TShiftOpsI32x8;
    ComparisonI32x8: TComparisonOpsI32x8;
    MinMaxI32x8: TMinMaxOpsI32x8;

    // 128-bit I64x2 Operations
    ArithmeticI64x2: TArithmeticOpsI64x2;
    BitwiseI64x2: TBitwiseOpsI64x2;

    // 512-bit Operations
    ArithmeticF32x16: TArithmeticOpsF32x16;
    ArithmeticF64x8: TArithmeticOpsF64x8;
    ArithmeticI32x16: TArithmeticOpsI32x16;
    BitwiseI32x16: TBitwiseOpsI32x16;
    ShiftI32x16: TShiftOpsI32x16;
    ComparisonI32x16: TComparisonOpsI32x16;
    MinMaxI32x16: TMinMaxOpsI32x16;

    // High-Level Facade Operations
    Facade: TFacadeOps;
  end;

  PSimdBackendOps = ^TSimdBackendOps;

// =========================================================================
// Helper Functions
// =========================================================================

// Initialize all fields of TSimdBackendOps to nil
procedure ClearBackendOps(var ops: TSimdBackendOps);

// Note: For scalar implementations, use FillScalarOps from
// nextpas.core.simd.backend.adapter - it's the authoritative source.

// Check if an operation group is fully populated (no nil pointers)
function IsArithmeticF32x4Complete(const ops: TArithmeticOpsF32x4): Boolean;
function IsMathF32x4Complete(const ops: TMathOpsF32x4): Boolean;
function IsComparisonF32x4Complete(const ops: TComparisonOpsF32x4): Boolean;
function IsFacadeComplete(const ops: TFacadeOps): Boolean;

// Validate that all required operations are assigned
function ValidateBackendOps(const ops: TSimdBackendOps; out missingOps: string): Boolean;

implementation

procedure ClearBackendOps(var ops: TSimdBackendOps);
begin
  FillChar(ops, SizeOf(TSimdBackendOps), 0);
end;

function IsArithmeticF32x4Complete(const ops: TArithmeticOpsF32x4): Boolean;
begin
  Result := Assigned(ops.Add) and Assigned(ops.Sub) and
            Assigned(ops.Mul) and Assigned(ops.OpDiv);
end;

function IsMathF32x4Complete(const ops: TMathOpsF32x4): Boolean;
begin
  Result := Assigned(ops.Abs) and Assigned(ops.Sqrt) and
            Assigned(ops.Min) and Assigned(ops.Max) and
            Assigned(ops.Floor) and Assigned(ops.Ceil) and
            Assigned(ops.Round) and Assigned(ops.Trunc);
end;

function IsComparisonF32x4Complete(const ops: TComparisonOpsF32x4): Boolean;
begin
  Result := Assigned(ops.CmpEq) and Assigned(ops.CmpLt) and
            Assigned(ops.CmpLe) and Assigned(ops.CmpGt) and
            Assigned(ops.CmpGe) and Assigned(ops.CmpNe);
end;

function IsFacadeComplete(const ops: TFacadeOps): Boolean;
begin
  Result := Assigned(ops.MemEqual) and Assigned(ops.MemFindByte) and
            Assigned(ops.MemCopy) and Assigned(ops.MemSet) and
            Assigned(ops.SumBytes) and Assigned(ops.CountByte);
end;

function ValidateBackendOps(const ops: TSimdBackendOps; out missingOps: string): Boolean;
var
  missing: string;
begin
  missing := '';
  Result := True;

  // Check F32x4 Arithmetic
  if not IsArithmeticF32x4Complete(ops.ArithmeticF32x4) then
  begin
    missing := missing + 'ArithmeticF32x4, ';
    Result := False;
  end;

  // Check F32x4 Comparison
  if not IsComparisonF32x4Complete(ops.ComparisonF32x4) then
  begin
    missing := missing + 'ComparisonF32x4, ';
    Result := False;
  end;

  // Check Facade
  if not IsFacadeComplete(ops.Facade) then
  begin
    missing := missing + 'Facade, ';
    Result := False;
  end;

  // Remove trailing comma and space
  if Length(missing) > 2 then
    SetLength(missing, Length(missing) - 2);

  missingOps := missing;
end;

end.
