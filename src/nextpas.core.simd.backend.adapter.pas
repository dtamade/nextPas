unit nextpas.core.simd.backend.adapter;

{$mode objfpc}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.backend.iface,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.backend.priority;

// =============================================================================
// SIMD Backend Adapter
// =============================================================================
//
// Purpose:
//   Provides bidirectional conversion between:
//   - Legacy TSimdDispatchTable (flat, 100+ fields)
//   - New TSimdBackendOps (hierarchical, grouped)
//
// Migration Strategy:
//   1. Existing backends continue using TSimdDispatchTable (no changes needed)
//   2. New backends can implement TSimdBackendOps (cleaner)
//   3. Adapter converts between them transparently
//   4. Gradual migration: convert one backend at a time
//
// This allows parallel development without breaking existing code!
//
// =============================================================================

// Convert new TSimdBackendOps to legacy TSimdDispatchTable
// Use this when registering a backend implemented with new interface
procedure BackendOpsToDispatchTable(const ops: TSimdBackendOps; out table: TSimdDispatchTable);

// Convert legacy TSimdDispatchTable to new TSimdBackendOps
// Use this to access legacy backends via new interface
procedure DispatchTableToBackendOps(const table: TSimdDispatchTable; out ops: TSimdBackendOps);

// Register a backend using the new TSimdBackendOps interface
// Internally converts to TSimdDispatchTable for compatibility
procedure RegisterBackendOps(backend: TSimdBackend; const ops: TSimdBackendOps);

// Get backend operations in new format (converts from internal dispatch table)
function GetBackendOps(backend: TSimdBackend): TSimdBackendOps;

// Check if a backend is registered (wrapper for compatibility)
function IsBackendOpsRegistered(backend: TSimdBackend): Boolean;

// Fill TSimdBackendOps with scalar implementations (complete version)
// This is the authoritative source for scalar function assignments
procedure FillScalarOps(var ops: TSimdBackendOps);

implementation

uses
  nextpas.core.simd.scalar;

procedure BackendOpsToDispatchTable(const ops: TSimdBackendOps; out table: TSimdDispatchTable);
begin
  // Safety baseline: start from complete scalar table to avoid nil slots.
  // Backend-specific mappings below selectively override accelerated paths.
  table := Default(TSimdDispatchTable);
  FillBaseDispatchTable(table);

  // Copy backend info
  table.Backend := ops.Backend;
  table.BackendInfo := ops.BackendInfo;
  {$DEFINE NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}
  {$I nextpas.core.simd.backend.adapter.map.inc}
  {$UNDEF NEXTPAS_SIMD_BACKEND_ADAPTER_FORWARD}

end;

procedure DispatchTableToBackendOps(const table: TSimdDispatchTable; out ops: TSimdBackendOps);
begin
  // Explicitly initialize managed fields to keep strict zero-hint build policy.
  ops := Default(TSimdBackendOps);

  // Copy backend info
  ops.Backend := table.Backend;
  ops.BackendInfo := table.BackendInfo;
  {$DEFINE NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}
  {$I nextpas.core.simd.backend.adapter.map.inc}
  {$UNDEF NEXTPAS_SIMD_BACKEND_ADAPTER_BACKWARD}

end;

procedure RegisterBackendOps(backend: TSimdBackend; const ops: TSimdBackendOps);
var
  table: TSimdDispatchTable;
begin
  // Convert new format to legacy format
  BackendOpsToDispatchTable(ops, table);
  table.Backend := backend;
  table.BackendInfo.Backend := backend;
  // Register using existing system
  RegisterBackend(backend, table);
end;

function GetBackendOps(backend: TSimdBackend): TSimdBackendOps;
var
  LTable: TSimdDispatchTable;
  LCanonicalInfo: TSimdBackendInfo;
begin
  Result := Default(TSimdBackendOps);

  if TryGetRegisteredBackendDispatchTable(backend, LTable) then
  begin
    DispatchTableToBackendOps(LTable, Result);
    Result.Backend := backend;
    Result.BackendInfo.Backend := backend;
    if (Result.BackendInfo.Name = '') or (Result.BackendInfo.Description = '') then
    begin
      LCanonicalInfo := GetBackendInfo(backend);
      if Result.BackendInfo.Name = '' then
        Result.BackendInfo.Name := LCanonicalInfo.Name;
      if Result.BackendInfo.Description = '' then
        Result.BackendInfo.Description := LCanonicalInfo.Description;
    end;
  end
  else
  begin
    ClearBackendOps(Result);
    Result.Backend := backend;
    Result.BackendInfo := GetBackendInfo(backend);
  end;
end;

function IsBackendOpsRegistered(backend: TSimdBackend): Boolean;
begin
  Result := IsBackendRegistered(backend);
end;

procedure FillScalarOps(var ops: TSimdBackendOps);
begin
  // Initialize to zeros first
  ClearBackendOps(ops);

  // Set backend info
  ops.Backend := sbScalar;
  ops.BackendInfo.Backend := sbScalar;
  ops.BackendInfo.Name := 'Scalar';
  ops.BackendInfo.Description := 'Pure scalar reference implementation';
  ops.BackendInfo.Capabilities := [scBasicArithmetic, scComparison, scMathFunctions, scReduction, scLoadStore];
  ops.BackendInfo.Available := True;
  ops.BackendInfo.Priority := GetSimdBackendPriorityValue(sbScalar);

  // === F32x4 Arithmetic ===
  ops.ArithmeticF32x4.Add := @ScalarAddF32x4;
  ops.ArithmeticF32x4.Sub := @ScalarSubF32x4;
  ops.ArithmeticF32x4.Mul := @ScalarMulF32x4;
  ops.ArithmeticF32x4.OpDiv := @ScalarDivF32x4;

  // === F32x8 Arithmetic ===
  ops.ArithmeticF32x8.Add := @ScalarAddF32x8;
  ops.ArithmeticF32x8.Sub := @ScalarSubF32x8;
  ops.ArithmeticF32x8.Mul := @ScalarMulF32x8;
  ops.ArithmeticF32x8.OpDiv := @ScalarDivF32x8;

  // === F64x2 Arithmetic ===
  ops.ArithmeticF64x2.Add := @ScalarAddF64x2;
  ops.ArithmeticF64x2.Sub := @ScalarSubF64x2;
  ops.ArithmeticF64x2.Mul := @ScalarMulF64x2;
  ops.ArithmeticF64x2.OpDiv := @ScalarDivF64x2;

  // === F64x4 Arithmetic ===
  ops.ArithmeticF64x4.Add := @ScalarAddF64x4;
  ops.ArithmeticF64x4.Sub := @ScalarSubF64x4;
  ops.ArithmeticF64x4.Mul := @ScalarMulF64x4;
  ops.ArithmeticF64x4.OpDiv := @ScalarDivF64x4;

  // === I32x4 Arithmetic ===
  ops.ArithmeticI32x4.Add := @ScalarAddI32x4;
  ops.ArithmeticI32x4.Sub := @ScalarSubI32x4;
  ops.ArithmeticI32x4.Mul := @ScalarMulI32x4;

  // === I32x4 Bitwise ===
  ops.BitwiseI32x4.OpAnd := @ScalarAndI32x4;
  ops.BitwiseI32x4.OpOr := @ScalarOrI32x4;
  ops.BitwiseI32x4.OpXor := @ScalarXorI32x4;
  ops.BitwiseI32x4.OpNot := @ScalarNotI32x4;
  ops.BitwiseI32x4.AndNot := @ScalarAndNotI32x4;

  // === I32x4 Shift ===
  ops.ShiftI32x4.ShiftLeft := @ScalarShiftLeftI32x4;
  ops.ShiftI32x4.ShiftRight := @ScalarShiftRightI32x4;
  ops.ShiftI32x4.ShiftRightArith := @ScalarShiftRightArithI32x4;

  // === I32x4 Comparison ===
  ops.ComparisonI32x4.CmpEq := @ScalarCmpEqI32x4;
  ops.ComparisonI32x4.CmpLt := @ScalarCmpLtI32x4;
  ops.ComparisonI32x4.CmpGt := @ScalarCmpGtI32x4;

  // === I32x4 MinMax ===
  ops.MinMaxI32x4.Min := @ScalarMinI32x4;
  ops.MinMaxI32x4.Max := @ScalarMaxI32x4;

  // === I64x2 Arithmetic ===
  ops.ArithmeticI64x2.Add := @ScalarAddI64x2;
  ops.ArithmeticI64x2.Sub := @ScalarSubI64x2;

  // === I64x2 Bitwise ===
  ops.BitwiseI64x2.OpAnd := @ScalarAndI64x2;
  ops.BitwiseI64x2.OpOr := @ScalarOrI64x2;
  ops.BitwiseI64x2.OpXor := @ScalarXorI64x2;
  ops.BitwiseI64x2.OpNot := @ScalarNotI64x2;

  // === I32x8 Arithmetic ===
  ops.ArithmeticI32x8.Add := @ScalarAddI32x8;
  ops.ArithmeticI32x8.Sub := @ScalarSubI32x8;
  ops.ArithmeticI32x8.Mul := @ScalarMulI32x8;

  // === I32x8 Bitwise ===
  ops.BitwiseI32x8.OpAnd := @ScalarAndI32x8;
  ops.BitwiseI32x8.OpOr := @ScalarOrI32x8;
  ops.BitwiseI32x8.OpXor := @ScalarXorI32x8;
  ops.BitwiseI32x8.OpNot := @ScalarNotI32x8;
  ops.BitwiseI32x8.AndNot := @ScalarAndNotI32x8;

  // === I32x8 Shift ===
  ops.ShiftI32x8.ShiftLeft := @ScalarShiftLeftI32x8;
  ops.ShiftI32x8.ShiftRight := @ScalarShiftRightI32x8;
  ops.ShiftI32x8.ShiftRightArith := @ScalarShiftRightArithI32x8;

  // === I32x8 Comparison ===
  ops.ComparisonI32x8.CmpEq := @ScalarCmpEqI32x8;
  ops.ComparisonI32x8.CmpLt := @ScalarCmpLtI32x8;
  ops.ComparisonI32x8.CmpGt := @ScalarCmpGtI32x8;

  // === I32x8 MinMax ===
  ops.MinMaxI32x8.Min := @ScalarMinI32x8;
  ops.MinMaxI32x8.Max := @ScalarMaxI32x8;

  // === F32x16 Arithmetic (512-bit) ===
  ops.ArithmeticF32x16.Add := @ScalarAddF32x16;
  ops.ArithmeticF32x16.Sub := @ScalarSubF32x16;
  ops.ArithmeticF32x16.Mul := @ScalarMulF32x16;
  ops.ArithmeticF32x16.OpDiv := @ScalarDivF32x16;

  // === F64x8 Arithmetic (512-bit) ===
  ops.ArithmeticF64x8.Add := @ScalarAddF64x8;
  ops.ArithmeticF64x8.Sub := @ScalarSubF64x8;
  ops.ArithmeticF64x8.Mul := @ScalarMulF64x8;
  ops.ArithmeticF64x8.OpDiv := @ScalarDivF64x8;

  // === I32x16 Arithmetic (512-bit) ===
  ops.ArithmeticI32x16.Add := @ScalarAddI32x16;
  ops.ArithmeticI32x16.Sub := @ScalarSubI32x16;
  ops.ArithmeticI32x16.Mul := @ScalarMulI32x16;

  // === I32x16 Bitwise ===
  ops.BitwiseI32x16.OpAnd := @ScalarAndI32x16;
  ops.BitwiseI32x16.OpOr := @ScalarOrI32x16;
  ops.BitwiseI32x16.OpXor := @ScalarXorI32x16;
  ops.BitwiseI32x16.OpNot := @ScalarNotI32x16;
  ops.BitwiseI32x16.AndNot := @ScalarAndNotI32x16;

  // === I32x16 Shift ===
  ops.ShiftI32x16.ShiftLeft := @ScalarShiftLeftI32x16;
  ops.ShiftI32x16.ShiftRight := @ScalarShiftRightI32x16;
  ops.ShiftI32x16.ShiftRightArith := @ScalarShiftRightArithI32x16;

  // === I32x16 Comparison ===
  ops.ComparisonI32x16.CmpEq := @ScalarCmpEqI32x16;
  ops.ComparisonI32x16.CmpLt := @ScalarCmpLtI32x16;
  ops.ComparisonI32x16.CmpGt := @ScalarCmpGtI32x16;

  // === I32x16 MinMax ===
  ops.MinMaxI32x16.Min := @ScalarMinI32x16;
  ops.MinMaxI32x16.Max := @ScalarMaxI32x16;

  // === F32x4 Comparison ===
  ops.ComparisonF32x4.CmpEq := @ScalarCmpEqF32x4;
  ops.ComparisonF32x4.CmpLt := @ScalarCmpLtF32x4;
  ops.ComparisonF32x4.CmpLe := @ScalarCmpLeF32x4;
  ops.ComparisonF32x4.CmpGt := @ScalarCmpGtF32x4;
  ops.ComparisonF32x4.CmpGe := @ScalarCmpGeF32x4;
  ops.ComparisonF32x4.CmpNe := @ScalarCmpNeF32x4;

  // === F32x4 Math ===
  ops.MathF32x4.Abs := @ScalarAbsF32x4;
  ops.MathF32x4.Sqrt := @ScalarSqrtF32x4;
  ops.MathF32x4.Min := @ScalarMinF32x4;
  ops.MathF32x4.Max := @ScalarMaxF32x4;
  ops.MathF32x4.Fma := @ScalarFmaF32x4;
  ops.MathF32x4.Rcp := @ScalarRcpF32x4;
  ops.MathF32x4.Rsqrt := @ScalarRsqrtF32x4;
  ops.MathF32x4.Floor := @ScalarFloorF32x4;
  ops.MathF32x4.Ceil := @ScalarCeilF32x4;
  ops.MathF32x4.Round := @ScalarRoundF32x4;
  ops.MathF32x4.Trunc := @ScalarTruncF32x4;
  ops.MathF32x4.Clamp := @ScalarClampF32x4;

  // === F32x4 Vector Math ===
  ops.VectorMathF32x4.Dot4 := @ScalarDotF32x4;
  ops.VectorMathF32x4.Dot3 := @ScalarDotF32x3;
  ops.VectorMathF32x4.Cross3 := @ScalarCrossF32x3;
  ops.VectorMathF32x4.Length4 := @ScalarLengthF32x4;
  ops.VectorMathF32x4.Length3 := @ScalarLengthF32x3;
  ops.VectorMathF32x4.Normalize4 := @ScalarNormalizeF32x4;
  ops.VectorMathF32x4.Normalize3 := @ScalarNormalizeF32x3;

  // === F32x4 Reduction ===
  ops.ReductionF32x4.ReduceAdd := @ScalarReduceAddF32x4;
  ops.ReductionF32x4.ReduceMin := @ScalarReduceMinF32x4;
  ops.ReductionF32x4.ReduceMax := @ScalarReduceMaxF32x4;
  ops.ReductionF32x4.ReduceMul := @ScalarReduceMulF32x4;

  // === F32x4 Memory Operations ===
  ops.MemoryF32x4.Load := @ScalarLoadF32x4;
  ops.MemoryF32x4.LoadAligned := @ScalarLoadF32x4Aligned;
  ops.MemoryF32x4.Store := @ScalarStoreF32x4;
  ops.MemoryF32x4.StoreAligned := @ScalarStoreF32x4Aligned;
  ops.MemoryF32x4.Splat := @ScalarSplatF32x4;
  ops.MemoryF32x4.Zero := @ScalarZeroF32x4;
  ops.MemoryF32x4.Select := @ScalarSelectF32x4;
  ops.MemoryF32x4.Extract := @ScalarExtractF32x4;
  ops.MemoryF32x4.Insert := @ScalarInsertF32x4;

  // === Facade Operations ===
  ops.Facade.MemEqual := @MemEqual_Scalar;
  ops.Facade.MemFindByte := @MemFindByte_Scalar;
  ops.Facade.MemDiffRange := @MemDiffRange_Scalar;
  ops.Facade.MemCopy := @MemCopy_Scalar;
  ops.Facade.MemSet := @MemSet_Scalar;
  ops.Facade.MemReverse := @MemReverse_Scalar;
  ops.Facade.SumBytes := @SumBytes_Scalar;
  ops.Facade.MinMaxBytes := @MinMaxBytes_Scalar;
  ops.Facade.CountByte := @CountByte_Scalar;
  ops.Facade.Utf8Validate := @Utf8Validate_Scalar;
  ops.Facade.AsciiIEqual := @AsciiIEqual_Scalar;
  ops.Facade.ToLowerAscii := @ToLowerAscii_Scalar;
  ops.Facade.ToUpperAscii := @ToUpperAscii_Scalar;
  ops.Facade.BytesIndexOf := @BytesIndexOf_Scalar;
  ops.Facade.BitsetPopCount := @BitsetPopCount_Scalar;
end;

end.
