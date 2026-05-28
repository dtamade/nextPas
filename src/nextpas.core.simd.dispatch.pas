unit nextpas.core.simd.dispatch;

{$mode objfpc}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.cpuinfo;

// === Dispatch System ===

// Initialize the dispatch system (called automatically)
procedure InitializeDispatch;

// Get current active backend
function GetActiveBackend: TSimdBackend;

// Force a specific backend (for testing)
// 添加安全性检查 - 如果后端不可用则回退到 Scalar
procedure SetActiveBackend(backend: TSimdBackend);

// Try to set a specific backend, returns True if successful
// 新增函数 - 允许调用者检查是否成功
function TrySetActiveBackend(backend: TSimdBackend): Boolean;

// Low-level compatibility alias for cpuinfo.IsBackendSupportedOnCPU.
// New public call sites should prefer nextpas.core.simd.cpuinfo.
function IsBackendAvailableOnCPU(backend: TSimdBackend): Boolean;

// Check if a backend is both CPU-supported and dispatchable in this binary.
function IsBackendDispatchable(backend: TSimdBackend): Boolean;

// Enumerate backends that can actually be selected by dispatch.
function GetDispatchableBackends: TSimdBackendArray;

// Get the best backend that is both CPU-supported and dispatchable.
function GetBestDispatchableBackend: TSimdBackend;

// Reset to automatic backend selection
procedure ResetToAutomaticBackend;

// === SIMD Vector ASM Feature Toggle ===
// SIMD vector ASM implementations are enabled by default.
// To disable at compile-time, define SIMD_VECTOR_ASM_DISABLED.
// To disable at runtime, call SetVectorAsmEnabled(False).
function IsVectorAsmEnabled: Boolean;
procedure SetVectorAsmEnabled(enabled: Boolean);

// === Dispatch Change Hook ===
// Used by higher-level facades to bind a fast access path once per (re)initialization.
{$I nextpas.core.simd.dispatch.hooks.intf.inc}

// === Backend Rebuilder Registration ===
// Register per-backend rebuild callbacks so feature toggles (e.g. vector asm)
// can rebuild backend tables after initialization.
type
  TBackendRebuilder = procedure;

// Rebuilder callbacks should be registration-only and idempotent.
procedure RegisterBackendRebuilder(backend: TSimdBackend; rebuilder: TBackendRebuilder);

// === Function Dispatch Tables ===
type
  // Dispatch table for all SIMD operations.
  // This is a stable in-repo dispatch contract for nextpas.core itself, but not
  // a public binary ABI: BackendInfo carries managed string fields.
  TSimdDispatchTable = record
    // Backend information
    Backend: TSimdBackend;
    BackendInfo: TSimdBackendInfo;
    
    // Arithmetic operations - F32x4
    AddF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    SubF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    MulF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    DivF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    
    // Arithmetic operations - F32x8
    AddF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    SubF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    MulF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    DivF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    
    // Arithmetic operations - F64x2
    AddF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    SubF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    MulF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    DivF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    
    // Arithmetic operations - I32x4
    AddI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    SubI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    MulI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    // Bitwise operations - I32x4
    AndI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    OrI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    XorI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    NotI32x4: function(const a: TVecI32x4): TVecI32x4;
    AndNotI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    // Shift operations - I32x4
    ShiftLeftI32x4: function(const a: TVecI32x4; count: Integer): TVecI32x4;
    ShiftRightI32x4: function(const a: TVecI32x4; count: Integer): TVecI32x4;
    ShiftRightArithI32x4: function(const a: TVecI32x4; count: Integer): TVecI32x4;
    // Comparison operations - I32x4
    CmpEqI32x4: function(const a, b: TVecI32x4): TMask4;
    CmpLtI32x4: function(const a, b: TVecI32x4): TMask4;
    CmpGtI32x4: function(const a, b: TVecI32x4): TMask4;
    CmpLeI32x4: function(const a, b: TVecI32x4): TMask4;
    CmpGeI32x4: function(const a, b: TVecI32x4): TMask4;
    CmpNeI32x4: function(const a, b: TVecI32x4): TMask4;
    // Min/Max operations - I32x4
    MinI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    MaxI32x4: function(const a, b: TVecI32x4): TVecI32x4;

    // Arithmetic operations - I64x2 (P1.3)
    AddI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    SubI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    AndI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    OrI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    XorI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    NotI64x2: function(const a: TVecI64x2): TVecI64x2;
    AndNotI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    ShiftLeftI64x2: function(const a: TVecI64x2; count: Integer): TVecI64x2;
    ShiftRightI64x2: function(const a: TVecI64x2; count: Integer): TVecI64x2;
    ShiftRightArithI64x2: function(const a: TVecI64x2; count: Integer): TVecI64x2;
    // Comparison operations - I64x2
    CmpEqI64x2: function(const a, b: TVecI64x2): TMask2;
    CmpLtI64x2: function(const a, b: TVecI64x2): TMask2;
    CmpGtI64x2: function(const a, b: TVecI64x2): TMask2;
    CmpLeI64x2: function(const a, b: TVecI64x2): TMask2;
    CmpGeI64x2: function(const a, b: TVecI64x2): TMask2;
    CmpNeI64x2: function(const a, b: TVecI64x2): TMask2;
    MinI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    MaxI64x2: function(const a, b: TVecI64x2): TVecI64x2;

    // Arithmetic operations - U64x2
    AddU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    SubU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    AndU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    OrU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    XorU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    NotU64x2: function(const a: TVecU64x2): TVecU64x2;
    AndNotU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    CmpEqU64x2: function(const a, b: TVecU64x2): TMask2;
    CmpLtU64x2: function(const a, b: TVecU64x2): TMask2;
    CmpGtU64x2: function(const a, b: TVecU64x2): TMask2;
    MinU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    MaxU64x2: function(const a, b: TVecU64x2): TVecU64x2;

    // Arithmetic operations - F64x4 (256-bit AVX)
    AddF64x4: function(const a, b: TVecF64x4): TVecF64x4;
    SubF64x4: function(const a, b: TVecF64x4): TVecF64x4;
    MulF64x4: function(const a, b: TVecF64x4): TVecF64x4;
    DivF64x4: function(const a, b: TVecF64x4): TVecF64x4;

    // Arithmetic operations - I32x8 (256-bit AVX)
    AddI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    SubI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    MulI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    AndI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    OrI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    XorI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    NotI32x8: function(const a: TVecI32x8): TVecI32x8;
    AndNotI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    // Shift operations - I32x8
    ShiftLeftI32x8: function(const a: TVecI32x8; count: Integer): TVecI32x8;
    ShiftRightI32x8: function(const a: TVecI32x8; count: Integer): TVecI32x8;
    ShiftRightArithI32x8: function(const a: TVecI32x8; count: Integer): TVecI32x8;
    // Comparison operations - I32x8
    CmpEqI32x8: function(const a, b: TVecI32x8): TMask8;
    CmpLtI32x8: function(const a, b: TVecI32x8): TMask8;
    CmpGtI32x8: function(const a, b: TVecI32x8): TMask8;
    CmpLeI32x8: function(const a, b: TVecI32x8): TMask8;
    CmpGeI32x8: function(const a, b: TVecI32x8): TMask8;
    CmpNeI32x8: function(const a, b: TVecI32x8): TMask8;
    // Min/Max operations - I32x8
    MinI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    MaxI32x8: function(const a, b: TVecI32x8): TVecI32x8;

    // I64x4 Operations (256-bit AVX2)
    AddI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    SubI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    AndI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    OrI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    XorI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    NotI64x4: function(const a: TVecI64x4): TVecI64x4;
    AndNotI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    ShiftLeftI64x4: function(const a: TVecI64x4; count: Integer): TVecI64x4;
    ShiftRightI64x4: function(const a: TVecI64x4; count: Integer): TVecI64x4;
    ShiftRightArithI64x4: function(const a: TVecI64x4; count: Integer): TVecI64x4;
    CmpEqI64x4: function(const a, b: TVecI64x4): TMask4;
    CmpLtI64x4: function(const a, b: TVecI64x4): TMask4;
    CmpGtI64x4: function(const a, b: TVecI64x4): TMask4;
    CmpLeI64x4: function(const a, b: TVecI64x4): TMask4;
    CmpGeI64x4: function(const a, b: TVecI64x4): TMask4;
    CmpNeI64x4: function(const a, b: TVecI64x4): TMask4;
    // I64x4 Utility operations
    LoadI64x4: function(p: PInt64): TVecI64x4;
    StoreI64x4: procedure(p: PInt64; const a: TVecI64x4);
    SplatI64x4: function(value: Int64): TVecI64x4;
    ZeroI64x4: function: TVecI64x4;

    // U32x8 Operations (256-bit AVX2)
    AddU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    SubU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    MulU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    AndU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    OrU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    XorU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    NotU32x8: function(const a: TVecU32x8): TVecU32x8;
    AndNotU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    ShiftLeftU32x8: function(const a: TVecU32x8; count: Integer): TVecU32x8;
    ShiftRightU32x8: function(const a: TVecU32x8; count: Integer): TVecU32x8;
    CmpEqU32x8: function(const a, b: TVecU32x8): TMask8;
    CmpLtU32x8: function(const a, b: TVecU32x8): TMask8;
    CmpGtU32x8: function(const a, b: TVecU32x8): TMask8;
    CmpLeU32x8: function(const a, b: TVecU32x8): TMask8;
    CmpGeU32x8: function(const a, b: TVecU32x8): TMask8;
    CmpNeU32x8: function(const a, b: TVecU32x8): TMask8;
    MinU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    MaxU32x8: function(const a, b: TVecU32x8): TVecU32x8;

    // U64x4 Operations (256-bit AVX2)
    AddU64x4: function(const a, b: TVecU64x4): TVecU64x4;
    SubU64x4: function(const a, b: TVecU64x4): TVecU64x4;
    AndU64x4: function(const a, b: TVecU64x4): TVecU64x4;
    OrU64x4: function(const a, b: TVecU64x4): TVecU64x4;
    XorU64x4: function(const a, b: TVecU64x4): TVecU64x4;
    NotU64x4: function(const a: TVecU64x4): TVecU64x4;
    ShiftLeftU64x4: function(const a: TVecU64x4; count: Integer): TVecU64x4;
    ShiftRightU64x4: function(const a: TVecU64x4; count: Integer): TVecU64x4;
    CmpEqU64x4: function(const a, b: TVecU64x4): TMask4;
    CmpLtU64x4: function(const a, b: TVecU64x4): TMask4;
    CmpGtU64x4: function(const a, b: TVecU64x4): TMask4;
    CmpLeU64x4: function(const a, b: TVecU64x4): TMask4;
    CmpGeU64x4: function(const a, b: TVecU64x4): TMask4;
    CmpNeU64x4: function(const a, b: TVecU64x4): TMask4;

    // F64x4 Extended Math
    RcpF64x4: function(const a: TVecF64x4): TVecF64x4;

    // Arithmetic operations - I32x16 (512-bit AVX-512)
    AddI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    SubI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    MulI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    AndI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    OrI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    XorI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    NotI32x16: function(const a: TVecI32x16): TVecI32x16;
    AndNotI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    // Shift operations - I32x16
    ShiftLeftI32x16: function(const a: TVecI32x16; count: Integer): TVecI32x16;
    ShiftRightI32x16: function(const a: TVecI32x16; count: Integer): TVecI32x16;
    ShiftRightArithI32x16: function(const a: TVecI32x16; count: Integer): TVecI32x16;
    // Comparison operations - I32x16
    CmpEqI32x16: function(const a, b: TVecI32x16): TMask16;
    CmpLtI32x16: function(const a, b: TVecI32x16): TMask16;
    CmpGtI32x16: function(const a, b: TVecI32x16): TMask16;
    CmpLeI32x16: function(const a, b: TVecI32x16): TMask16;
    CmpGeI32x16: function(const a, b: TVecI32x16): TMask16;
    CmpNeI32x16: function(const a, b: TVecI32x16): TMask16;
    // Min/Max operations - I32x16
    MinI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    MaxI32x16: function(const a, b: TVecI32x16): TVecI32x16;

    // Arithmetic operations - I64x8 (512-bit AVX-512)
    AddI64x8: function(const a, b: TVecI64x8): TVecI64x8;
    SubI64x8: function(const a, b: TVecI64x8): TVecI64x8;
    // Bitwise operations - I64x8
    AndI64x8: function(const a, b: TVecI64x8): TVecI64x8;
    OrI64x8: function(const a, b: TVecI64x8): TVecI64x8;
    XorI64x8: function(const a, b: TVecI64x8): TVecI64x8;
    NotI64x8: function(const a: TVecI64x8): TVecI64x8;
    // Comparison operations - I64x8
    CmpEqI64x8: function(const a, b: TVecI64x8): TMask8;
    CmpLtI64x8: function(const a, b: TVecI64x8): TMask8;
    CmpGtI64x8: function(const a, b: TVecI64x8): TMask8;
    CmpLeI64x8: function(const a, b: TVecI64x8): TMask8;
    CmpGeI64x8: function(const a, b: TVecI64x8): TMask8;
    CmpNeI64x8: function(const a, b: TVecI64x8): TMask8;

    // Arithmetic operations - U32x16 (512-bit)
    AddU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    SubU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    MulU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    AndU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    OrU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    XorU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    NotU32x16: function(const a: TVecU32x16): TVecU32x16;
    AndNotU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    ShiftLeftU32x16: function(const a: TVecU32x16; count: Integer): TVecU32x16;
    ShiftRightU32x16: function(const a: TVecU32x16; count: Integer): TVecU32x16;
    CmpEqU32x16: function(const a, b: TVecU32x16): TMask16;
    CmpLtU32x16: function(const a, b: TVecU32x16): TMask16;
    CmpGtU32x16: function(const a, b: TVecU32x16): TMask16;
    CmpLeU32x16: function(const a, b: TVecU32x16): TMask16;
    CmpGeU32x16: function(const a, b: TVecU32x16): TMask16;
    CmpNeU32x16: function(const a, b: TVecU32x16): TMask16;
    MinU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    MaxU32x16: function(const a, b: TVecU32x16): TVecU32x16;

    // Arithmetic operations - U64x8 (512-bit)
    AddU64x8: function(const a, b: TVecU64x8): TVecU64x8;
    SubU64x8: function(const a, b: TVecU64x8): TVecU64x8;
    AndU64x8: function(const a, b: TVecU64x8): TVecU64x8;
    OrU64x8: function(const a, b: TVecU64x8): TVecU64x8;
    XorU64x8: function(const a, b: TVecU64x8): TVecU64x8;
    NotU64x8: function(const a: TVecU64x8): TVecU64x8;
    ShiftLeftU64x8: function(const a: TVecU64x8; count: Integer): TVecU64x8;
    ShiftRightU64x8: function(const a: TVecU64x8; count: Integer): TVecU64x8;
    CmpEqU64x8: function(const a, b: TVecU64x8): TMask8;
    CmpLtU64x8: function(const a, b: TVecU64x8): TMask8;
    CmpGtU64x8: function(const a, b: TVecU64x8): TMask8;
    CmpLeU64x8: function(const a, b: TVecU64x8): TMask8;
    CmpGeU64x8: function(const a, b: TVecU64x8): TMask8;
    CmpNeU64x8: function(const a, b: TVecU64x8): TMask8;

    // Arithmetic operations - I16x32 (512-bit)
    AddI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    SubI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    AndI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    OrI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    XorI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    NotI16x32: function(const a: TVecI16x32): TVecI16x32;
    AndNotI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    ShiftLeftI16x32: function(const a: TVecI16x32; count: Integer): TVecI16x32;
    ShiftRightI16x32: function(const a: TVecI16x32; count: Integer): TVecI16x32;
    ShiftRightArithI16x32: function(const a: TVecI16x32; count: Integer): TVecI16x32;
    CmpEqI16x32: function(const a, b: TVecI16x32): TMask32;
    CmpLtI16x32: function(const a, b: TVecI16x32): TMask32;
    CmpGtI16x32: function(const a, b: TVecI16x32): TMask32;
    MinI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    MaxI16x32: function(const a, b: TVecI16x32): TVecI16x32;

    // Arithmetic operations - I8x64 (512-bit)
    AddI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    SubI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    AndI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    OrI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    XorI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    NotI8x64: function(const a: TVecI8x64): TVecI8x64;
    AndNotI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    CmpEqI8x64: function(const a, b: TVecI8x64): TMask64;
    CmpLtI8x64: function(const a, b: TVecI8x64): TMask64;
    CmpGtI8x64: function(const a, b: TVecI8x64): TMask64;
    MinI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    MaxI8x64: function(const a, b: TVecI8x64): TVecI8x64;

    // Arithmetic operations - U8x64 (512-bit)
    AddU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    SubU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    AndU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    OrU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    XorU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    NotU8x64: function(const a: TVecU8x64): TVecU8x64;
    CmpEqU8x64: function(const a, b: TVecU8x64): TMask64;
    CmpLtU8x64: function(const a, b: TVecU8x64): TMask64;
    CmpGtU8x64: function(const a, b: TVecU8x64): TMask64;
    MinU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    MaxU8x64: function(const a, b: TVecU8x64): TVecU8x64;

    // Arithmetic operations - F32x16 (512-bit AVX-512)
    AddF32x16: function(const a, b: TVecF32x16): TVecF32x16;
    SubF32x16: function(const a, b: TVecF32x16): TVecF32x16;
    MulF32x16: function(const a, b: TVecF32x16): TVecF32x16;
    DivF32x16: function(const a, b: TVecF32x16): TVecF32x16;

    // Arithmetic operations - F64x8 (512-bit AVX-512)
    AddF64x8: function(const a, b: TVecF64x8): TVecF64x8;
    SubF64x8: function(const a, b: TVecF64x8): TVecF64x8;
    MulF64x8: function(const a, b: TVecF64x8): TVecF64x8;
    DivF64x8: function(const a, b: TVecF64x8): TVecF64x8;

    // Comparison operations
    CmpEqF32x4: function(const a, b: TVecF32x4): TMask4;
    CmpLtF32x4: function(const a, b: TVecF32x4): TMask4;
    CmpLeF32x4: function(const a, b: TVecF32x4): TMask4;
    CmpGtF32x4: function(const a, b: TVecF32x4): TMask4;
    CmpGeF32x4: function(const a, b: TVecF32x4): TMask4;
    CmpNeF32x4: function(const a, b: TVecF32x4): TMask4;

    // F64x2 比较操作 - 修复派发缺失
    CmpEqF64x2: function(const a, b: TVecF64x2): TMask2;
    CmpLtF64x2: function(const a, b: TVecF64x2): TMask2;
    CmpLeF64x2: function(const a, b: TVecF64x2): TMask2;
    CmpGtF64x2: function(const a, b: TVecF64x2): TMask2;
    CmpGeF64x2: function(const a, b: TVecF64x2): TMask2;
    CmpNeF64x2: function(const a, b: TVecF64x2): TMask2;

    // 512-bit floating-point comparisons
    // F32x16 (512-bit)
    CmpEqF32x16: function(const a, b: TVecF32x16): TMask16;
    CmpLtF32x16: function(const a, b: TVecF32x16): TMask16;
    CmpLeF32x16: function(const a, b: TVecF32x16): TMask16;
    CmpGtF32x16: function(const a, b: TVecF32x16): TMask16;
    CmpGeF32x16: function(const a, b: TVecF32x16): TMask16;
    CmpNeF32x16: function(const a, b: TVecF32x16): TMask16;
    // F64x8 (512-bit)
    CmpEqF64x8: function(const a, b: TVecF64x8): TMask8;
    CmpLtF64x8: function(const a, b: TVecF64x8): TMask8;
    CmpLeF64x8: function(const a, b: TVecF64x8): TMask8;
    CmpGtF64x8: function(const a, b: TVecF64x8): TMask8;
    CmpGeF64x8: function(const a, b: TVecF64x8): TMask8;
    CmpNeF64x8: function(const a, b: TVecF64x8): TMask8;

    // 256-bit floating-point comparisons
    // F32x8 (256-bit)
    CmpEqF32x8: function(const a, b: TVecF32x8): TMask8;
    CmpLtF32x8: function(const a, b: TVecF32x8): TMask8;
    CmpLeF32x8: function(const a, b: TVecF32x8): TMask8;
    CmpGtF32x8: function(const a, b: TVecF32x8): TMask8;
    CmpGeF32x8: function(const a, b: TVecF32x8): TMask8;
    CmpNeF32x8: function(const a, b: TVecF32x8): TMask8;
    // F64x4 (256-bit)
    CmpEqF64x4: function(const a, b: TVecF64x4): TMask4;
    CmpLtF64x4: function(const a, b: TVecF64x4): TMask4;
    CmpLeF64x4: function(const a, b: TVecF64x4): TMask4;
    CmpGtF64x4: function(const a, b: TVecF64x4): TMask4;
    CmpGeF64x4: function(const a, b: TVecF64x4): TMask4;
    CmpNeF64x4: function(const a, b: TVecF64x4): TMask4;

    // Math functions
    AbsF32x4: function(const a: TVecF32x4): TVecF32x4;
    SqrtF32x4: function(const a: TVecF32x4): TVecF32x4;
    MinF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    MaxF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    
    // Extended math functions
    FmaF32x4: function(const a, b, c: TVecF32x4): TVecF32x4;   // a*b+c
    RcpF32x4: function(const a: TVecF32x4): TVecF32x4;          // 1/x (approximate)
    RsqrtF32x4: function(const a: TVecF32x4): TVecF32x4;        // 1/sqrt(x) (approximate)
    FloorF32x4: function(const a: TVecF32x4): TVecF32x4;
    CeilF32x4: function(const a: TVecF32x4): TVecF32x4;
    RoundF32x4: function(const a: TVecF32x4): TVecF32x4;
    TruncF32x4: function(const a: TVecF32x4): TVecF32x4;
    ClampF32x4: function(const a, minVal, maxVal: TVecF32x4): TVecF32x4;

    // Wide vector extended math functions
    // F64x2 (128-bit)
    FmaF64x2: function(const a, b, c: TVecF64x2): TVecF64x2;
    FloorF64x2: function(const a: TVecF64x2): TVecF64x2;
    CeilF64x2: function(const a: TVecF64x2): TVecF64x2;
    RoundF64x2: function(const a: TVecF64x2): TVecF64x2;
    TruncF64x2: function(const a: TVecF64x2): TVecF64x2;
    // F64x2 math functions
    AbsF64x2: function(const a: TVecF64x2): TVecF64x2;
    SqrtF64x2: function(const a: TVecF64x2): TVecF64x2;
    MinF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    MaxF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    ClampF64x2: function(const a, minVal, maxVal: TVecF64x2): TVecF64x2;
    // F32x8 (256-bit)
    FmaF32x8: function(const a, b, c: TVecF32x8): TVecF32x8;
    FloorF32x8: function(const a: TVecF32x8): TVecF32x8;
    CeilF32x8: function(const a: TVecF32x8): TVecF32x8;
    RoundF32x8: function(const a: TVecF32x8): TVecF32x8;
    TruncF32x8: function(const a: TVecF32x8): TVecF32x8;
    // F32x8 math functions
    AbsF32x8: function(const a: TVecF32x8): TVecF32x8;
    SqrtF32x8: function(const a: TVecF32x8): TVecF32x8;
    MinF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    MaxF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    ClampF32x8: function(const a, minVal, maxVal: TVecF32x8): TVecF32x8;
    // F64x4 (256-bit)
    FmaF64x4: function(const a, b, c: TVecF64x4): TVecF64x4;
    FloorF64x4: function(const a: TVecF64x4): TVecF64x4;
    CeilF64x4: function(const a: TVecF64x4): TVecF64x4;
    RoundF64x4: function(const a: TVecF64x4): TVecF64x4;
    TruncF64x4: function(const a: TVecF64x4): TVecF64x4;
    // F32x16 (512-bit)
    FmaF32x16: function(const a, b, c: TVecF32x16): TVecF32x16;
    FloorF32x16: function(const a: TVecF32x16): TVecF32x16;
    CeilF32x16: function(const a: TVecF32x16): TVecF32x16;
    RoundF32x16: function(const a: TVecF32x16): TVecF32x16;
    TruncF32x16: function(const a: TVecF32x16): TVecF32x16;
    // F64x8 (512-bit)
    FmaF64x8: function(const a, b, c: TVecF64x8): TVecF64x8;
    FloorF64x8: function(const a: TVecF64x8): TVecF64x8;
    CeilF64x8: function(const a: TVecF64x8): TVecF64x8;
    RoundF64x8: function(const a: TVecF64x8): TVecF64x8;
    TruncF64x8: function(const a: TVecF64x8): TVecF64x8;
    // F64x4 math functions
    AbsF64x4: function(const a: TVecF64x4): TVecF64x4;
    SqrtF64x4: function(const a: TVecF64x4): TVecF64x4;
    MinF64x4: function(const a, b: TVecF64x4): TVecF64x4;
    MaxF64x4: function(const a, b: TVecF64x4): TVecF64x4;
    ClampF64x4: function(const a, minVal, maxVal: TVecF64x4): TVecF64x4;

    // 512-bit float math functions
    // F32x16 (512-bit)
    AbsF32x16: function(const a: TVecF32x16): TVecF32x16;
    SqrtF32x16: function(const a: TVecF32x16): TVecF32x16;
    MinF32x16: function(const a, b: TVecF32x16): TVecF32x16;
    MaxF32x16: function(const a, b: TVecF32x16): TVecF32x16;
    ClampF32x16: function(const a, minVal, maxVal: TVecF32x16): TVecF32x16;
    // F64x8 (512-bit)
    AbsF64x8: function(const a: TVecF64x8): TVecF64x8;
    SqrtF64x8: function(const a: TVecF64x8): TVecF64x8;
    MinF64x8: function(const a, b: TVecF64x8): TVecF64x8;
    MaxF64x8: function(const a, b: TVecF64x8): TVecF64x8;
    ClampF64x8: function(const a, minVal, maxVal: TVecF64x8): TVecF64x8;

    // 3D/4D Vector math
    DotF32x4: function(const a, b: TVecF32x4): Single;          // Dot product (4 elements)
    DotF32x3: function(const a, b: TVecF32x4): Single;          // Dot product (3 elements)
    CrossF32x3: function(const a, b: TVecF32x4): TVecF32x4;     // Cross product (uses x,y,z)
    LengthF32x4: function(const a: TVecF32x4): Single;          // Length (4 elements)
    LengthF32x3: function(const a: TVecF32x4): Single;          // Length (3 elements)
    NormalizeF32x4: function(const a: TVecF32x4): TVecF32x4;    // Normalize (4 elements)
    NormalizeF32x3: function(const a: TVecF32x4): TVecF32x4;    // Normalize (3 elements, w=0)

    // FMA-optimized Dot Product Functions
    DotF32x8: function(const a, b: TVecF32x8): Single;          // Dot product (8 elements)
    DotF64x2: function(const a, b: TVecF64x2): Double;          // Dot product (2 elements)
    DotF64x4: function(const a, b: TVecF64x4): Double;          // Dot product (4 elements)
    
    // Reduction operations
    ReduceAddF32x4: function(const a: TVecF32x4): Single;
    ReduceMinF32x4: function(const a: TVecF32x4): Single;
    ReduceMaxF32x4: function(const a: TVecF32x4): Single;
    ReduceMulF32x4: function(const a: TVecF32x4): Single;
    // Wide vector reduction operations
    // F64x2 (128-bit)
    ReduceAddF64x2: function(const a: TVecF64x2): Double;
    ReduceMinF64x2: function(const a: TVecF64x2): Double;
    ReduceMaxF64x2: function(const a: TVecF64x2): Double;
    ReduceMulF64x2: function(const a: TVecF64x2): Double;
    // F32x8 (256-bit)
    ReduceAddF32x8: function(const a: TVecF32x8): Single;
    ReduceMinF32x8: function(const a: TVecF32x8): Single;
    ReduceMaxF32x8: function(const a: TVecF32x8): Single;
    ReduceMulF32x8: function(const a: TVecF32x8): Single;
    // F64x4 (256-bit)
    ReduceAddF64x4: function(const a: TVecF64x4): Double;
    ReduceMinF64x4: function(const a: TVecF64x4): Double;
    ReduceMaxF64x4: function(const a: TVecF64x4): Double;
    ReduceMulF64x4: function(const a: TVecF64x4): Double;
    // F32x16 (512-bit)
    ReduceAddF32x16: function(const a: TVecF32x16): Single;
    ReduceMinF32x16: function(const a: TVecF32x16): Single;
    ReduceMaxF32x16: function(const a: TVecF32x16): Single;
    ReduceMulF32x16: function(const a: TVecF32x16): Single;
    // F64x8 (512-bit)
    ReduceAddF64x8: function(const a: TVecF64x8): Double;
    ReduceMinF64x8: function(const a: TVecF64x8): Double;
    ReduceMaxF64x8: function(const a: TVecF64x8): Double;
    ReduceMulF64x8: function(const a: TVecF64x8): Double;
    
    // Memory operations
    LoadF32x4: function(p: PSingle): TVecF32x4;
    LoadF32x4Aligned: function(p: PSingle): TVecF32x4;
    StoreF32x4: procedure(p: PSingle; const a: TVecF32x4);
    StoreF32x4Aligned: procedure(p: PSingle; const a: TVecF32x4);
    
    // Utility operations
    SplatF32x4: function(value: Single): TVecF32x4;
    ZeroF32x4: function: TVecF32x4;
    SelectF32x4: function(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
    ExtractF32x4: function(const a: TVecF32x4; index: Integer): Single;
    InsertF32x4: function(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;

    // Extract/Insert Lane Operations
    // F64x2 (128-bit)
    ExtractF64x2: function(const a: TVecF64x2; index: Integer): Double;
    InsertF64x2: function(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
    // I32x4 (128-bit)
    ExtractI32x4: function(const a: TVecI32x4; index: Integer): Int32;
    InsertI32x4: function(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
    // I64x2 (128-bit)
    ExtractI64x2: function(const a: TVecI64x2; index: Integer): Int64;
    InsertI64x2: function(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2;
    // F32x8 (256-bit)
    ExtractF32x8: function(const a: TVecF32x8; index: Integer): Single;
    InsertF32x8: function(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;
    // F64x4 (256-bit)
    ExtractF64x4: function(const a: TVecF64x4; index: Integer): Double;
    InsertF64x4: function(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;
    // I32x8 (256-bit)
    ExtractI32x8: function(const a: TVecI32x8; index: Integer): Int32;
    InsertI32x8: function(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
    // I64x4 (256-bit)
    ExtractI64x4: function(const a: TVecI64x4; index: Integer): Int64;
    InsertI64x4: function(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
    // F32x16 (512-bit)
    ExtractF32x16: function(const a: TVecF32x16; index: Integer): Single;
    InsertF32x16: function(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
    // I32x16 (512-bit)
    ExtractI32x16: function(const a: TVecI32x16; index: Integer): Int32;
    InsertI32x16: function(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;

    // Wide vector Load/Store/Splat/Zero
    // F64x2 (128-bit)
    LoadF64x2: function(p: PDouble): TVecF64x2;
    StoreF64x2: procedure(p: PDouble; const a: TVecF64x2);
    SplatF64x2: function(value: Double): TVecF64x2;
    ZeroF64x2: function: TVecF64x2;
    // F32x8 (256-bit)
    LoadF32x8: function(p: PSingle): TVecF32x8;
    StoreF32x8: procedure(p: PSingle; const a: TVecF32x8);
    SplatF32x8: function(value: Single): TVecF32x8;
    ZeroF32x8: function: TVecF32x8;
    // F64x4 (256-bit)
    LoadF64x4: function(p: PDouble): TVecF64x4;
    StoreF64x4: procedure(p: PDouble; const a: TVecF64x4);
    SplatF64x4: function(value: Double): TVecF64x4;
    ZeroF64x4: function: TVecF64x4;
    // F32x16 (512-bit)
    LoadF32x16: function(p: PSingle): TVecF32x16;
    StoreF32x16: procedure(p: PSingle; const a: TVecF32x16);
    SplatF32x16: function(value: Single): TVecF32x16;
    ZeroF32x16: function: TVecF32x16;
    // F64x8 (512-bit)
    LoadF64x8: function(p: PDouble): TVecF64x8;
    StoreF64x8: procedure(p: PDouble; const a: TVecF64x8);
    SplatF64x8: function(value: Double): TVecF64x8;
    ZeroF64x8: function: TVecF64x8;

    // === Facade Functions (High-Level API) ===
    // Memory operations
    MemEqual: function(a, b: Pointer; len: SizeUInt): LongBool;
    MemFindByte: function(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
    MemDiffRange: function(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
    MemCopy: procedure(src, dst: Pointer; len: SizeUInt);
    MemSet: procedure(dst: Pointer; len: SizeUInt; value: Byte);
    MemReverse: procedure(p: Pointer; len: SizeUInt);
    
    // Statistics functions
    SumBytes: function(p: Pointer; len: SizeUInt): UInt64;
    MinMaxBytes: procedure(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
    CountByte: function(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
    
    // Text processing functions
    Utf8Validate: function(p: Pointer; len: SizeUInt): Boolean;
    AsciiIEqual: function(a, b: Pointer; len: SizeUInt): Boolean;
    ToLowerAscii: procedure(p: Pointer; len: SizeUInt);
    ToUpperAscii: procedure(p: Pointer; len: SizeUInt);
    
    // Search functions
    BytesIndexOf: function(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;
    
    // Bitset functions
    BitsetPopCount: function(p: Pointer; byteLen: SizeUInt): SizeUInt;

    // Saturating Arithmetic (音视频处理必需)
    // 有符号饱和 (I8: [-128, 127], I16: [-32768, 32767])
    I8x16SatAdd: function(const a, b: TVecI8x16): TVecI8x16;
    I8x16SatSub: function(const a, b: TVecI8x16): TVecI8x16;
    I16x8SatAdd: function(const a, b: TVecI16x8): TVecI16x8;
    I16x8SatSub: function(const a, b: TVecI16x8): TVecI16x8;
    // 无符号饱和 (U8: [0, 255], U16: [0, 65535])
    U8x16SatAdd: function(const a, b: TVecU8x16): TVecU8x16;
    U8x16SatSub: function(const a, b: TVecU8x16): TVecU8x16;
    U16x8SatAdd: function(const a, b: TVecU16x8): TVecU16x8;
    U16x8SatSub: function(const a, b: TVecU16x8): TVecU16x8;

    // I16x8 完整操作 (8×Int16)
    AddI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    SubI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    MulI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    AndI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    OrI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    XorI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    NotI16x8: function(const a: TVecI16x8): TVecI16x8;
    AndNotI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    ShiftLeftI16x8: function(const a: TVecI16x8; count: Integer): TVecI16x8;
    ShiftRightI16x8: function(const a: TVecI16x8; count: Integer): TVecI16x8;
    ShiftRightArithI16x8: function(const a: TVecI16x8; count: Integer): TVecI16x8;
    CmpEqI16x8: function(const a, b: TVecI16x8): TMask8;
    CmpLtI16x8: function(const a, b: TVecI16x8): TMask8;
    CmpGtI16x8: function(const a, b: TVecI16x8): TMask8;
    CmpLeI16x8: function(const a, b: TVecI16x8): TMask8;  // Le/Ge/Ne for narrow integers
    CmpGeI16x8: function(const a, b: TVecI16x8): TMask8;
    CmpNeI16x8: function(const a, b: TVecI16x8): TMask8;
    MinI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    MaxI16x8: function(const a, b: TVecI16x8): TVecI16x8;

    // I8x16 完整操作 (16×Int8)
    AddI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    SubI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    AndI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    OrI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    XorI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    NotI8x16: function(const a: TVecI8x16): TVecI8x16;
    CmpEqI8x16: function(const a, b: TVecI8x16): TMask16;
    CmpLtI8x16: function(const a, b: TVecI8x16): TMask16;
    CmpGtI8x16: function(const a, b: TVecI8x16): TMask16;
    CmpLeI8x16: function(const a, b: TVecI8x16): TMask16;  // Le/Ge/Ne for narrow integers
    CmpGeI8x16: function(const a, b: TVecI8x16): TMask16;
    CmpNeI8x16: function(const a, b: TVecI8x16): TMask16;
    MinI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    MaxI8x16: function(const a, b: TVecI8x16): TVecI8x16;

    // U32x4 完整操作 (4×UInt32)
    AddU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    SubU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    MulU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    AndU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    OrU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    XorU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    NotU32x4: function(const a: TVecU32x4): TVecU32x4;
    AndNotU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    ShiftLeftU32x4: function(const a: TVecU32x4; count: Integer): TVecU32x4;
    ShiftRightU32x4: function(const a: TVecU32x4; count: Integer): TVecU32x4;
    CmpEqU32x4: function(const a, b: TVecU32x4): TMask4;
    CmpLtU32x4: function(const a, b: TVecU32x4): TMask4;
    CmpGtU32x4: function(const a, b: TVecU32x4): TMask4;
    CmpLeU32x4: function(const a, b: TVecU32x4): TMask4;
    CmpGeU32x4: function(const a, b: TVecU32x4): TMask4;
    MinU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    MaxU32x4: function(const a, b: TVecU32x4): TVecU32x4;

    // U16x8 完整操作 (8×UInt16)
    AddU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    SubU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    MulU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    AndU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    OrU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    XorU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    NotU16x8: function(const a: TVecU16x8): TVecU16x8;
    ShiftLeftU16x8: function(const a: TVecU16x8; count: Integer): TVecU16x8;
    ShiftRightU16x8: function(const a: TVecU16x8; count: Integer): TVecU16x8;
    CmpEqU16x8: function(const a, b: TVecU16x8): TMask8;
    CmpLtU16x8: function(const a, b: TVecU16x8): TMask8;
    CmpGtU16x8: function(const a, b: TVecU16x8): TMask8;
    CmpLeU16x8: function(const a, b: TVecU16x8): TMask8;  // Le/Ge/Ne for narrow integers
    CmpGeU16x8: function(const a, b: TVecU16x8): TMask8;
    CmpNeU16x8: function(const a, b: TVecU16x8): TMask8;
    MinU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    MaxU16x8: function(const a, b: TVecU16x8): TVecU16x8;

    // U8x16 完整操作 (16×UInt8)
    AddU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    SubU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    AndU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    OrU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    XorU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    NotU8x16: function(const a: TVecU8x16): TVecU8x16;
    CmpEqU8x16: function(const a, b: TVecU8x16): TMask16;
    CmpLtU8x16: function(const a, b: TVecU8x16): TMask16;
    CmpGtU8x16: function(const a, b: TVecU8x16): TMask16;
    CmpLeU8x16: function(const a, b: TVecU8x16): TMask16;  // Le/Ge/Ne for narrow integers
    CmpGeU8x16: function(const a, b: TVecU8x16): TMask16;
    CmpNeU8x16: function(const a, b: TVecU8x16): TMask16;
    MinU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    MaxU8x16: function(const a, b: TVecU8x16): TVecU8x16;

    // Mask 类型操作 (条件分支优化)
    // TMask2 操作 (2 元素)
    Mask2All: function(mask: TMask2): Boolean;
    Mask2Any: function(mask: TMask2): Boolean;
    Mask2None: function(mask: TMask2): Boolean;
    Mask2PopCount: function(mask: TMask2): Integer;
    Mask2FirstSet: function(mask: TMask2): Integer;  // -1 if none
    // TMask4 操作 (4 元素)
    Mask4All: function(mask: TMask4): Boolean;
    Mask4Any: function(mask: TMask4): Boolean;
    Mask4None: function(mask: TMask4): Boolean;
    Mask4PopCount: function(mask: TMask4): Integer;
    Mask4FirstSet: function(mask: TMask4): Integer;  // -1 if none
    // TMask8 操作 (8 元素)
    Mask8All: function(mask: TMask8): Boolean;
    Mask8Any: function(mask: TMask8): Boolean;
    Mask8None: function(mask: TMask8): Boolean;
    Mask8PopCount: function(mask: TMask8): Integer;
    Mask8FirstSet: function(mask: TMask8): Integer;  // -1 if none
    // TMask16 操作 (16 元素)
    Mask16All: function(mask: TMask16): Boolean;
    Mask16Any: function(mask: TMask16): Boolean;
    Mask16None: function(mask: TMask16): Boolean;
    Mask16PopCount: function(mask: TMask16): Integer;
    Mask16FirstSet: function(mask: TMask16): Integer;  // -1 if none

    // F64x2 Select 操作
    SelectF64x2: function(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;

    // 512-bit Select operations
    SelectF32x16: function(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
    SelectF64x8: function(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;

    // 缺失的 Select 操作 (条件选择: mask ? a : b)
    SelectI32x4: function(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4;
    SelectF32x8: function(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;
    SelectF64x4: function(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;

    // Narrow integer AndNot fast-path (PANDN semantics: (NOT a) AND b)
    AndNotI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    AndNotU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    AndNotU8x16: function(const a, b: TVecU8x16): TVecU8x16;

    // === Batch Array Operations (O(1) dispatch, internal loop) ===
    ArrayAddF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArraySubF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayMulF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayDivF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayMinF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayMaxF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayAbsF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayNegF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArraySqrtF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayRcpF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayRsqrtF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayRcpRefineF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayRsqrtRefineF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayAddScalarF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
    ArrayMulScalarF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
    ArrayClampF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
    ArrayFmaF32: procedure(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
    ArrayAxpyF32: procedure(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
    ReduceSumF32: function(aSrc: PSingle; aCount: SizeUInt): Single;
    ReduceDotF32: function(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
    ReduceMinF32: function(aSrc: PSingle; aCount: SizeUInt): Single;
    ReduceMaxF32: function(aSrc: PSingle; aCount: SizeUInt): Single;

    // === Batch Array Operations - F64 ===
    ArrayAddF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
    ArraySubF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
    ArrayMulF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
    ArrayDivF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
    ReduceSumF64: function(aSrc: PDouble; aCount: SizeUInt): Double;
    ReduceDotF64: function(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
    ReduceMinF64: function(aSrc: PDouble; aCount: SizeUInt): Double;
    ReduceMaxF64: function(aSrc: PDouble; aCount: SizeUInt): Double;
    ArrayAbsF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
    ArrayNegF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
    ArraySqrtF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
    ArrayMulScalarF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
    ArrayAddScalarF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
    ArrayClampF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
    ArrayLinearF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);

    // === Batch Array Operations - Transcendental F32 ===
    ArrayExpF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayLogF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayPowF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
    ArraySinF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayCosF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);

    // === Batch Array Operations - Integer ===
    ArrayAddI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
    ArraySubI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
    ArrayMulI16: procedure(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
    ArrayPackSatI32toI16: procedure(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt);

    // === Batch Array Operations - Type Conversion ===
    ArrayF32toI32: procedure(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt);
    ArrayI32toF32: procedure(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt);

    // === Batch Array Operations - Bitwise (I32) ===
    ArrayAndI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
    ArrayOrI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
    ArrayXorI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
    ArrayShlI32: procedure(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
    ArrayShrI32: procedure(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);

    // === Fused Batch Operations (single-pass, reduced memory traffic) ===
    ArrayLinearF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
    ArrayAbsDiffF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayReLUF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayNormF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single);
    ArrayLinearReLUF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
  end;

// Pointer to dispatch table
type
  PSimdDispatchTable = ^TSimdDispatchTable;

// Get current dispatch table
function GetDispatchTable: PSimdDispatchTable; inline;

// === Backend Registration ===

// Register a backend implementation
procedure RegisterBackend(backend: TSimdBackend; const dispatchTable: TSimdDispatchTable);

// Check if backend is registered
function IsBackendRegistered(backend: TSimdBackend): Boolean;

// Get backend info
function GetBackendInfo(backend: TSimdBackend): TSimdBackendInfo;

// Return a stable pointer to the published backend name text.
// The returned pointer stays valid until process finalization.
function GetBackendNameTextPtr(backend: TSimdBackend): PAnsiChar;

// Return a stable pointer to the published backend description text.
// The returned pointer stays valid until process finalization.
function GetBackendDescriptionTextPtr(backend: TSimdBackend): PAnsiChar;

// Get a copy of a registered backend's dispatch table.
// Useful for diagnostics/tests (e.g. validating wiring on machines without that CPU feature).
// Returns False and clears `dispatchTable` if the backend is not registered.
function TryGetRegisteredBackendDispatchTable(backend: TSimdBackend; out dispatchTable: TSimdDispatchTable): Boolean;

// === Dispatch Table Helpers ===

{**
 * FillBaseDispatchTable
 *
 * @desc
 *   Fills a dispatch table with scalar reference implementations for all operations.
 *   This provides a complete baseline that SIMD backends can override selectively.
 *   填充派发表，使用标量参考实现作为所有操作的基础。
 *   为 SIMD 后端提供完整的基线，以便它们可以选择性地覆盖。
 *
 * @note
 *   Call this before setting backend-specific implementations.
 *   Backend info is NOT set by this function - caller must set it.
 *   在设置后端特定实现之前调用此函数。
 *   此函数不设置后端信息 - 调用者必须自行设置。
 *}
procedure FillBaseDispatchTable(var dispatchTable: TSimdDispatchTable);

{**
 * CloneDispatchTable
 *
 * @desc
 *   Clones a dispatch table from an already registered backend.
 *   This allows tier backends (SSE3/SSSE3/SSE4.1/SSE4.2) to inherit
 *   implementations from a lower tier (SSE2) instead of starting from scalar.
 *   从已注册的后端克隆派发表。
 *   这允许 tier 后端（SSE3/SSSE3/SSE4.1/SSE4.2）从低级后端（SSE2）
 *   继承实现，而不是从标量基线开始。
 *
 * @param fromBackend
 *   The backend to clone from. Must be already registered.
 *   要克隆的源后端。必须已注册。
 *
 * @param dispatchTable
 *   The dispatch table to fill with cloned implementations.
 *   要填充克隆实现的派发表。
 *
 * @returns
 *   True if clone succeeded (source backend was registered), False otherwise.
 *   如果克隆成功（源后端已注册）返回 True，否则返回 False。
 *
 * @note
 *   If the source backend is not registered, falls back to FillBaseDispatchTable.
 *   Backend info is NOT copied - caller must set it appropriately.
 *   如果源后端未注册，回退到 FillBaseDispatchTable。
 *   后端信息不会被复制 - 调用者必须自行设置。
 *}
function CloneDispatchTable(fromBackend: TSimdBackend; var dispatchTable: TSimdDispatchTable): Boolean;

implementation

uses
  SysUtils,
  nextpas.core.simd.scalar,
  nextpas.core.atomic,
  nextpas.core.simd.backend.priority; // atomic_thread_fence (MemoryBarrier replacement)

type
  PSimdDispatchPublishedState = ^TSimdDispatchPublishedState;
  TSimdDispatchPublishedState = record
    NextOwned: PSimdDispatchPublishedState;
    Table: TSimdDispatchTable;
  end;

const
  SIMD_MAX_CONTROL_PLANE_RESTORE_ATTEMPTS = 8;

var
  // Current active dispatch table
  g_CurrentDispatch: PSimdDispatchTable;
  g_CurrentDispatchStatePtr: Pointer = nil;
  g_CurrentDispatchOwnedHead: PSimdDispatchPublishedState = nil;
  g_BackendDispatchStatePtrs: array[TSimdBackend] of Pointer;
  
  // Registered backend dispatch tables
  g_BackendTables: array[TSimdBackend] of TSimdDispatchTable;
  g_BackendRegistered: array[TSimdBackend] of Boolean;
  g_DefaultBackendNames: array[TSimdBackend] of AnsiString;
  g_DefaultBackendDescriptions: array[TSimdBackend] of AnsiString;
  
  // Initialization state
  g_DispatchInitialized: Boolean = False;
  g_DispatchState: LongInt = 0;  // 0=未初始化, 1=初始化中, 2=已完成
  g_ForcedBackend: TSimdBackend;
  g_BackendForced: Boolean = False;

  // Feature toggles
  // 默认启用 SIMD 向量操作
  // 如需禁用，编译时定义 SIMD_VECTOR_ASM_DISABLED
  // 0 = disabled, 1 = enabled
  {$IFNDEF SIMD_VECTOR_ASM_DISABLED}
  g_VectorAsmEnabledState: LongInt = 1;
  {$ELSE}
  g_VectorAsmEnabledState: LongInt = 0;
  {$ENDIF}

  // Serialize runtime toggle writers so backend rebuild is single-threaded.
  g_VectorAsmToggleLock: TRTLCriticalSection;

  // Serialize hook list mutation without holding the lock during callbacks.
  g_DispatchHooksLock: TRTLCriticalSection;

  // Dispatch change hooks (e.g., for direct-dispatch fast path binding)
  g_DispatchChangedHooks: array of TSimdDispatchChangedHook;

  // Optional per-backend callback to rebuild dispatch tables when runtime feature
  // toggles change (e.g. vector-asm on/off).
  g_BackendRebuilders: array[TSimdBackend] of TBackendRebuilder;

  // Batch control-plane rebuilds (for example vector-asm toggles) should not
  // let each intermediate RegisterBackend call re-select a transient active
  // backend. Reinitialize once after the batch completes instead.
  g_RegisterBackendReinitializeSuspendDepth: LongInt = 0;

  // Readers that see g_DispatchState=0 during a control-plane batch rebuild
  // must not initialize against the half-rebuilt backend set.
  g_DispatchBatchRebuildState: LongInt = 0;
  g_DispatchControlPlaneInitialized: Boolean = False;

// === Initialization ===

function DefaultBackendName(const aBackend: TSimdBackend): string; inline;
begin
  Result := '';
  case aBackend of
    sbScalar: Result := 'Scalar';
    sbSSE2: Result := 'SSE2';
    sbSSE3: Result := 'SSE3';
    sbSSSE3: Result := 'SSSE3';
    sbSSE41: Result := 'SSE4.1';
    sbSSE42: Result := 'SSE4.2';
    sbAVX2: Result := 'AVX2';
    sbAVX512: Result := 'AVX-512';
    sbNEON: Result := 'NEON';
    sbRISCVV: Result := 'RISC-V V';
  end;
end;

function DefaultBackendDescription(const aBackend: TSimdBackend): string; inline;
begin
  Result := '';
  case aBackend of
    sbScalar: Result := 'Pure scalar reference implementation';
    sbSSE2: Result := 'x86-64 SSE2 SIMD implementation';
    sbSSE3: Result := 'x86-64 SSE3 SIMD implementation';
    sbSSSE3: Result := 'x86-64 SSSE3 SIMD implementation';
    sbSSE41: Result := 'x86-64 SSE4.1 SIMD implementation';
    sbSSE42: Result := 'x86-64 SSE4.2 SIMD implementation';
    sbAVX2: Result := 'x86-64 AVX2 SIMD implementation';
    sbAVX512: Result := 'x86-64 AVX-512 SIMD implementation';
    sbNEON: Result := 'ARM NEON 128-bit SIMD';
    sbRISCVV: Result := 'RISC-V Vector Extension (RVV)';
  end;
end;

procedure InitializeDefaultBackendTexts;
var
  LBackend: TSimdBackend;
begin
  for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
  begin
    g_DefaultBackendNames[LBackend] := AnsiString(DefaultBackendName(LBackend));
    g_DefaultBackendDescriptions[LBackend] := AnsiString(DefaultBackendDescription(LBackend));
  end;
end;

procedure EnsureDispatchControlPlaneInitialized;
begin
  if g_DispatchControlPlaneInitialized then
    Exit;

  InitializeDefaultBackendTexts;
  g_VectorAsmToggleLock := Default(TRTLCriticalSection);
  g_DispatchHooksLock := Default(TRTLCriticalSection);
  InitCriticalSection(g_VectorAsmToggleLock);
  InitCriticalSection(g_DispatchHooksLock);
  g_DispatchControlPlaneInitialized := True;
end;

procedure EnsureUniqueBackendInfoText(var aInfo: TSimdBackendInfo); inline;
begin
  if aInfo.Name <> '' then
    UniqueString(aInfo.Name);
  if aInfo.Description <> '' then
    UniqueString(aInfo.Description);
end;

function GetCurrentDispatchPublishedState: PSimdDispatchPublishedState; inline;
begin
  Result := PSimdDispatchPublishedState(atomic_load(g_CurrentDispatchStatePtr, mo_acquire));
end;

function GetCurrentPublishedDispatchTable: PSimdDispatchTable; inline;
var
  LState: PSimdDispatchPublishedState;
begin
  LState := GetCurrentDispatchPublishedState;
  if LState <> nil then
    Result := @LState^.Table
  else
    Result := nil;
end;

function GetPublishedBackendDispatchState(const aBackend: TSimdBackend): PSimdDispatchPublishedState; inline;
begin
  Result := PSimdDispatchPublishedState(atomic_load(g_BackendDispatchStatePtrs[aBackend], mo_acquire));
end;

function GetPublishedBackendDispatchTable(const aBackend: TSimdBackend): PSimdDispatchTable; inline;
var
  LState: PSimdDispatchPublishedState;
begin
  LState := GetPublishedBackendDispatchState(aBackend);
  if LState <> nil then
    Result := @LState^.Table
  else
    Result := nil;
end;

function CreateDispatchPublishedState: PSimdDispatchPublishedState;
begin
  New(Result);
  FillChar(Result^, SizeOf(Result^), 0);
  Result^.NextOwned := g_CurrentDispatchOwnedHead;
  g_CurrentDispatchOwnedHead := Result;
end;

function DispatchTableMetadataEquals(const aLeft, aRight: TSimdDispatchTable): Boolean; inline;
begin
  Result := (aLeft.Backend = aRight.Backend) and
    (aLeft.BackendInfo.Backend = aRight.BackendInfo.Backend) and
    (aLeft.BackendInfo.Name = aRight.BackendInfo.Name) and
    (aLeft.BackendInfo.Description = aRight.BackendInfo.Description) and
    (aLeft.BackendInfo.Available = aRight.BackendInfo.Available) and
    (aLeft.BackendInfo.Priority = aRight.BackendInfo.Priority) and
    (aLeft.BackendInfo.Capabilities = aRight.BackendInfo.Capabilities);
end;

function DispatchTableSlotPointersEqual(const aLeft, aRight: TSimdDispatchTable): Boolean;
var
  LOffset: PtrUInt;
  LSize: SizeUInt;
  LLeftSlots: PByte;
  LRightSlots: PByte;
begin
  {$PUSH}{$WARN 4055 OFF} // pointer-sized offset math over immutable dispatch snapshots
  LOffset := PtrUInt(@aLeft.AddF32x4) - PtrUInt(@aLeft);
  LLeftSlots := PByte(PtrUInt(@aLeft) + LOffset);
  LRightSlots := PByte(PtrUInt(@aRight) + LOffset);
  {$POP}
  LSize := SizeOf(TSimdDispatchTable) - LOffset;
  if LSize = 0 then
    Exit(True);
  Result := CompareByte(LLeftSlots^, LRightSlots^, LSize) = 0;
end;

function DispatchTablesEquivalent(const aLeft, aRight: TSimdDispatchTable): Boolean; inline;
begin
  Result := DispatchTableMetadataEquals(aLeft, aRight) and
    DispatchTableSlotPointersEqual(aLeft, aRight);
end;

function FindPublishedDispatchStateByTable(
  const aDispatchTable: TSimdDispatchTable): PSimdDispatchPublishedState;
begin
  Result := g_CurrentDispatchOwnedHead;
  while Result <> nil do
  begin
    if DispatchTablesEquivalent(Result^.Table, aDispatchTable) then
      Exit;
    Result := Result^.NextOwned;
  end;
end;

procedure PublishBackendDispatchTable(const aBackend: TSimdBackend; const aDispatchTable: TSimdDispatchTable);
var
  LState: PSimdDispatchPublishedState;
begin
  LState := FindPublishedDispatchStateByTable(aDispatchTable);
  if LState = nil then
  begin
    LState := CreateDispatchPublishedState;
    LState^.Table := aDispatchTable;
  end;
  atomic_store(g_BackendDispatchStatePtrs[aBackend], Pointer(LState), mo_release);
end;

procedure PublishCurrentDispatchState(const aState: PSimdDispatchPublishedState);
begin
  if aState = nil then
  begin
    g_CurrentDispatch := nil;
    atomic_store(g_CurrentDispatchStatePtr, nil, mo_release);
    Exit;
  end;

  // The active/current dispatch view does not need its own cloned publication:
  // the selected backend snapshot is already immutable and process-owned.
  g_CurrentDispatch := @aState^.Table;
  atomic_store(g_CurrentDispatchStatePtr, Pointer(aState), mo_release);
end;

procedure FinalizeDispatchPublishedStates;
var
  LState: PSimdDispatchPublishedState;
  LNext: PSimdDispatchPublishedState;
begin
  atomic_store(g_CurrentDispatchStatePtr, nil, mo_release);
  g_CurrentDispatch := nil;
  LState := g_CurrentDispatchOwnedHead;
  g_CurrentDispatchOwnedHead := nil;
  while LState <> nil do
  begin
    LNext := LState^.NextOwned;
    Dispose(LState);
    LState := LNext;
  end;
end;

function IsBackendMarkedAvailableForDispatch(backend: TSimdBackend): Boolean; inline;
var
  LDispatchTable: PSimdDispatchTable;
begin
  // Scalar is always usable.
  if backend = sbScalar then
    Exit(True);

  // Observe registration + published backend snapshot with a single read barrier.
  ReadBarrier;
  if not g_BackendRegistered[backend] then
    Exit(False);

  LDispatchTable := GetPublishedBackendDispatchTable(backend);
  Result := (LDispatchTable <> nil) and LDispatchTable^.BackendInfo.Available;
end;

{$I nextpas.core.simd.dispatch.hooks.impl.inc}

procedure RebuildBackendsAfterFeatureToggle(const aReinitializeDispatch: Boolean);
var
  LBackend: TSimdBackend;
  LRebuilder: TBackendRebuilder;
begin
  InterlockedExchange(g_DispatchBatchRebuildState, 1);
  InterlockedIncrement(g_RegisterBackendReinitializeSuspendDepth);
  try
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
    begin
      LRebuilder := g_BackendRebuilders[LBackend];
      if Assigned(LRebuilder) then
        LRebuilder;
    end;
  finally
    InterlockedDecrement(g_RegisterBackendReinitializeSuspendDepth);
    WriteBarrier;
    InterlockedExchange(g_DispatchBatchRebuildState, 0);
  end;

  // Ensure best-backend selection is recalculated once rebuilders finish.
  g_DispatchInitialized := False;
  InterlockedExchange(g_DispatchState, 0);
  atomic_thread_fence(mo_seq_cst);
  if aReinitializeDispatch then
    InitializeDispatch;
end;

// Thread-safe dispatch initialization using atomic operations
procedure DoInitializeDispatch;
var
  LBestBackend: TSimdBackend;
  LBackend: TSimdBackend;
  LBestDispatchState: PSimdDispatchPublishedState;
  LCandidateDispatchState: PSimdDispatchPublishedState;
  LBackendSupportedOnCPU: array[TSimdBackend] of Boolean;
  LIndex: Integer;
  LOldState: LongInt;
begin
  // 快速路径: 已完成初始化
  if g_DispatchState = 2 then
    Exit;

  while InterlockedCompareExchange(g_DispatchBatchRebuildState, 0, 0) <> 0 do
  begin
    ReadBarrier;
    ThreadSwitch;
  end;

  LOldState := InterlockedCompareExchange(g_DispatchState, 1, 0);
  if LOldState = 0 then
  begin
    // 我们是第一个初始化者
    // Note: Do NOT reset g_BackendRegistered here!
    // Backends register themselves during unit initialization,
    // and we don't want to lose that registration.

    // Precompute CPU/OS capability once, then use O(1) lookup during selection.
    for LBackend := Low(TSimdBackend) to High(TSimdBackend) do
      LBackendSupportedOnCPU[LBackend] := IsBackendAvailableOnCPU(LBackend);

    // Find best available backend
    if g_BackendForced then
    begin
      LBestBackend := g_ForcedBackend;
      LBestDispatchState := nil;

      // Forced backend must be:
      // - registered in this binary
      // - available on current CPU/OS (cpuinfo)
      // - marked available by the backend implementation (BackendInfo.Available)
      if LBestBackend <> sbScalar then
      begin
        if not LBackendSupportedOnCPU[LBestBackend] then
          LBestBackend := sbScalar
        else
        begin
          LBestDispatchState := GetPublishedBackendDispatchState(LBestBackend);
          if (LBestDispatchState = nil) or
             (not LBestDispatchState^.Table.BackendInfo.Available) then
            LBestBackend := sbScalar;
        end;
      end;

      if LBestBackend = sbScalar then
        LBestDispatchState := GetPublishedBackendDispatchState(sbScalar);
    end
    else
    begin
      LBestBackend := sbScalar;
      LBestDispatchState := GetPublishedBackendDispatchState(sbScalar);

      for LIndex := Low(SIMD_BACKEND_PRIORITY_ORDER) to High(SIMD_BACKEND_PRIORITY_ORDER) do
      begin
        LBackend := SIMD_BACKEND_PRIORITY_ORDER[LIndex];
        if LBackendSupportedOnCPU[LBackend] then
        begin
          LCandidateDispatchState := GetPublishedBackendDispatchState(LBackend);
          if (LCandidateDispatchState <> nil) and
             LCandidateDispatchState^.Table.BackendInfo.Available then
          begin
            LBestBackend := LBackend;
            LBestDispatchState := LCandidateDispatchState;
            Break;
          end;
        end;
      end;
    end;

    // Publish the exact backend snapshot selected above so readers never observe
    // a newer backend-state rewrite under the same backend id.
    if LBestDispatchState <> nil then
    begin
      PublishCurrentDispatchState(LBestDispatchState);
    end
    else
    begin
      PublishCurrentDispatchState(nil);
    end;

    g_DispatchInitialized := True;
    WriteBarrier;
    InterlockedExchange(g_DispatchState, 2);

    // Notify listeners after dispatch state is fully published.
    NotifyDispatchChangedHooks;
  end
  else if LOldState = 1 then
  begin
    // 另一个线程正在初始化，自旋等待
    while g_DispatchState <> 2 do
    begin
      ReadBarrier;
      ThreadSwitch;
    end;
  end;
  // LOldState = 2: 已完成，直接返回
end;

procedure InitializeDispatch;
begin
  // Always call DoInitializeDispatch - it has its own guard
  DoInitializeDispatch;
end;

function MatchesControlPlaneIntentLocked(const aExpectForced: Boolean;
  const aExpectedBackend: TSimdBackend): Boolean; inline;
begin
  Result := (g_BackendForced = aExpectForced) and
    ((not aExpectForced) or (g_ForcedBackend = aExpectedBackend));
end;

procedure ApplyControlPlaneIntentLocked(const aExpectForced: Boolean;
  const aExpectedBackend: TSimdBackend); inline;
begin
  g_BackendForced := aExpectForced;
  if aExpectForced then
    g_ForcedBackend := aExpectedBackend
  else
    g_ForcedBackend := sbScalar;
  WriteBarrier;
end;

procedure ReinitializeDispatchLocked; inline;
begin
  g_DispatchInitialized := False;
  InterlockedExchange(g_DispatchState, 0);
  atomic_thread_fence(mo_seq_cst);
  InitializeDispatch;
end;

function RestoreControlPlaneIntentUntilStableLocked(const aExpectForced: Boolean;
  const aExpectedBackend: TSimdBackend): Boolean;
var
  LAttempt: Integer;
begin
  for LAttempt := 1 to SIMD_MAX_CONTROL_PLANE_RESTORE_ATTEMPTS do
  begin
    ApplyControlPlaneIntentLocked(aExpectForced, aExpectedBackend);
    ReinitializeDispatchLocked;
    ReadBarrier;
    if MatchesControlPlaneIntentLocked(aExpectForced, aExpectedBackend) then
      Exit(True);
  end;

  Result := False;
end;

// === Public Interface ===

function GetActiveBackend: TSimdBackend;
var
  LDispatch: PSimdDispatchTable;
begin
  InitializeDispatch;
  LDispatch := GetCurrentPublishedDispatchTable;
  if LDispatch <> nil then
    Result := LDispatch^.Backend
  else
    Result := sbScalar;
end;

// Check if a backend is available on current CPU
function IsBackendAvailableOnCPU(backend: TSimdBackend): Boolean;
begin
  // Delegate to cpuinfo facade (O(1) predicate, no temporary array allocation).
  Result := nextpas.core.simd.cpuinfo.IsBackendSupportedOnCPU(backend);
end;

function IsBackendDispatchable(backend: TSimdBackend): Boolean;
begin
  Result := IsBackendMarkedAvailableForDispatch(backend) and IsBackendAvailableOnCPU(backend);
end;

function GetDispatchableBackends: TSimdBackendArray;
var
  LBackend: TSimdBackend;
  LCount: Integer;
begin
  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    Result := nil;
    SetLength(Result, Length(SIMD_BACKEND_PRIORITY_ORDER));
    LCount := 0;
    for LBackend in SIMD_BACKEND_PRIORITY_ORDER do
    begin
      if IsBackendDispatchable(LBackend) then
      begin
        Result[LCount] := LBackend;
        Inc(LCount);
      end;
    end;
    SetLength(Result, LCount);
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

function GetBestDispatchableBackend: TSimdBackend;
var
  LBackend: TSimdBackend;
begin
  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    for LBackend in SIMD_BACKEND_PRIORITY_ORDER do
      if IsBackendDispatchable(LBackend) then
        Exit(LBackend);

    Result := sbScalar;
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

function TrySetActiveBackendInternal(backend: TSimdBackend; out aAttemptedSelection: Boolean): Boolean;
var
  LDispatch: PSimdDispatchTable;
  LAutomaticIntentStable: Boolean;
  LPreviousBackendForced: Boolean;
  LPreviousForcedBackend: TSimdBackend;
  LForcedIntentStable: Boolean;
begin
  aAttemptedSelection := False;
  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    // Fast fail on backends that are not registered or not wired available.
    if not IsBackendMarkedAvailableForDispatch(backend) then
      Exit(False);

    // CPU/OS capability gate (independent from dispatch-table wiring gate).
    if not IsBackendAvailableOnCPU(backend) then
      Exit(False);

    aAttemptedSelection := True;
    LPreviousBackendForced := g_BackendForced;
    LPreviousForcedBackend := g_ForcedBackend;

    // Backend is valid, force it
    ApplyControlPlaneIntentLocked(True, backend);
    ReinitializeDispatchLocked;
    ReadBarrier;
    LDispatch := GetCurrentPublishedDispatchTable;
    Result := (LDispatch <> nil) and (LDispatch^.Backend = backend);
    if not Result then
    begin
      // A failed TrySetActiveBackend must not leave a stale forced-selection
      // intent behind; otherwise later re-register/rebuild events can revive a
      // backend that this call already reported as not successfully selected.
      // It also must not leave the active dispatch stuck on the transient
      // scalar fallback chosen during the failed forced-selection attempt.
      LAutomaticIntentStable := RestoreControlPlaneIntentUntilStableLocked(False, sbScalar);
      ReadBarrier;
      LDispatch := GetCurrentPublishedDispatchTable;
      Result := (LDispatch <> nil) and (LDispatch^.Backend = backend);
      if Result then
      begin
        // Rollback-time automatic selection may already have reselected the
        // requested backend before this API returns. Preserve the success
        // contract by restoring forced intent as well, so later backend
        // re-register/rebuild events cannot drift to a higher-priority backend.
        LForcedIntentStable := False;
        if RestoreControlPlaneIntentUntilStableLocked(True, backend) then
        begin
          ReadBarrier;
          LDispatch := GetCurrentPublishedDispatchTable;
          LForcedIntentStable := (LDispatch <> nil) and (LDispatch^.Backend = backend) and
            MatchesControlPlaneIntentLocked(True, backend);
        end;

        Result := LForcedIntentStable;
        if not Result then
        begin
          // Once forced-intent stabilization itself exhausts the bounded
          // restore budget, report failure and return to the caller's pre-call
          // stable intent instead of leaking the transient late-force state.
          if LPreviousBackendForced then
          begin
            if not RestoreControlPlaneIntentUntilStableLocked(True, LPreviousForcedBackend) then
            begin
              ApplyControlPlaneIntentLocked(True, LPreviousForcedBackend);
              ReinitializeDispatchLocked;
            end;
          end
          else if not RestoreControlPlaneIntentUntilStableLocked(False, sbScalar) then
          begin
            ApplyControlPlaneIntentLocked(False, sbScalar);
            ReinitializeDispatchLocked;
          end;
        end;
      end
      else if LPreviousBackendForced then
      begin
        // A failed switch must not destroy the caller's previously established
        // forced-selection intent. Restore both the control-plane intent and
        // the published dispatch snapshot to the pre-call forced backend.
        if not RestoreControlPlaneIntentUntilStableLocked(True, LPreviousForcedBackend) then
        begin
          // If repeated late-force mutations spend the bounded rollback budget,
          // issue one last explicit restore to the caller's pre-call forced
          // backend after the mutation storm has exhausted itself.
          ApplyControlPlaneIntentLocked(True, LPreviousForcedBackend);
          ReinitializeDispatchLocked;
        end;
      end
      else if not LAutomaticIntentStable then
      begin
        // Mirror the previous-forced post-cap closeout for automatic callers:
        // once repeated late-force mutations have spent the bounded restore
        // budget, perform one last explicit automatic restore before returning.
        ApplyControlPlaneIntentLocked(False, sbScalar);
        ReinitializeDispatchLocked;
      end;
    end;
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

// TrySetActiveBackend - returns True if backend was successfully set
function TrySetActiveBackend(backend: TSimdBackend): Boolean;
var
  LAttemptedSelection: Boolean;
begin
  Result := TrySetActiveBackendInternal(backend, LAttemptedSelection);
end;

// SetActiveBackend - now with safety check, falls back to Scalar if unavailable
procedure SetActiveBackend(backend: TSimdBackend);
var
  LAttemptedSelection: Boolean;
begin
  // Try to set the requested backend
  if TrySetActiveBackendInternal(backend, LAttemptedSelection) then
    Exit;

  // Only precondition-unavailable requests should silently degrade to Scalar.
  // If the backend was initially selectable but failed later during hook-driven
  // rebuild/rollback, preserve the state that TrySetActiveBackend already
  // restored instead of clobbering it with a scalar forced-selection.
  if not LAttemptedSelection then
    TrySetActiveBackend(sbScalar);
end;

procedure ResetToAutomaticBackend;
begin
  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    if not RestoreControlPlaneIntentUntilStableLocked(False, sbScalar) then
    begin
      // If repeated late-force mutations exhaust the bounded restore helper,
      // issue one final explicit automatic closeout before returning.
      ApplyControlPlaneIntentLocked(False, sbScalar);
      ReinitializeDispatchLocked;
    end;
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

function IsVectorAsmEnabled: Boolean;
begin
  Result := InterlockedCompareExchange(g_VectorAsmEnabledState, 0, 0) <> 0;
end;

// ⚠️ THREAD SAFETY: runtime toggling rebuilds backend tables.
// Call this only in controlled phases (startup/tests), not concurrently with
// hot SIMD traffic from worker threads.
procedure SetVectorAsmEnabled(enabled: Boolean);
var
  LExpectedState: LongInt;
  LCurrentState: LongInt;
  LDispatchWasInitialized: Boolean;
  LPreviousBackendForced: Boolean;
  LPreviousForcedBackend: TSimdBackend;
begin
  if enabled then
    LExpectedState := 1
  else
    LExpectedState := 0;

  // Fast path for stable state without taking lock.
  if InterlockedCompareExchange(g_VectorAsmEnabledState, LExpectedState, LExpectedState) = LExpectedState then
    Exit;

  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    // Re-check after acquiring lock (another writer may have already updated).
    LCurrentState := InterlockedCompareExchange(g_VectorAsmEnabledState, LExpectedState, LExpectedState);
    if LCurrentState = LExpectedState then
      Exit;

    LDispatchWasInitialized := g_DispatchState <> 0;
    LPreviousBackendForced := g_BackendForced;
    LPreviousForcedBackend := g_ForcedBackend;

    InterlockedExchange(g_VectorAsmEnabledState, LExpectedState);
    WriteBarrier;

    // Backend tables are published during unit initialization, so a pre-init
    // runtime toggle still needs to rebuild their Available/capability view.
    RebuildBackendsAfterFeatureToggle(LDispatchWasInitialized);

    if LDispatchWasInitialized then
    begin
      ReadBarrier;
      if (g_BackendForced <> LPreviousBackendForced) or
         (LPreviousBackendForced and (g_ForcedBackend <> LPreviousForcedBackend)) then
      begin
        // A feature toggle should preserve the caller's pre-existing
        // forced-vs-automatic selection intent. Late dispatch hooks may
        // temporarily reset or replace it during notification, so reapply the
        // original control-plane mode before returning.
        if not RestoreControlPlaneIntentUntilStableLocked(LPreviousBackendForced, LPreviousForcedBackend) then
        begin
          ApplyControlPlaneIntentLocked(LPreviousBackendForced, LPreviousForcedBackend);
          ReinitializeDispatchLocked;
        end;
      end;
    end;
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

function GetDispatchTable: PSimdDispatchTable; inline;
begin
  if g_DispatchState <> 2 then
    InitializeDispatch
  else
    ReadBarrier;
  Result := GetCurrentPublishedDispatchTable;
end;

// === Backend Registration ===

procedure RegisterBackend(backend: TSimdBackend; const dispatchTable: TSimdDispatchTable);
var
  LCanonicalTable: TSimdDispatchTable;
  LShouldReinitialize: Boolean;
  LPreviousBackendForced: Boolean;
  LPreviousForcedBackend: TSimdBackend;
begin
  EnsureDispatchControlPlaneInitialized;
  EnterCriticalSection(g_VectorAsmToggleLock);
  try
    // RegisterBackend mutates managed-string metadata, published dispatch-state
    // ownership lists, and dispatch selection state. Serialize all control-plane
    // writers so concurrent re-register tests cannot tear record assignment or
    // corrupt the owned published-state chain.
    LCanonicalTable := dispatchTable;
    LCanonicalTable.Backend := backend;
    LCanonicalTable.BackendInfo.Backend := backend;
    LCanonicalTable.BackendInfo.Priority := GetSimdBackendPriorityValue(backend);
    if backend = sbScalar then
      LCanonicalTable.BackendInfo.Available := True;
    if LCanonicalTable.BackendInfo.Name = '' then
      LCanonicalTable.BackendInfo.Name := DefaultBackendName(backend);
    if LCanonicalTable.BackendInfo.Description = '' then
      LCanonicalTable.BackendInfo.Description := DefaultBackendDescription(backend);
    EnsureUniqueBackendInfoText(LCanonicalTable.BackendInfo);
    LPreviousBackendForced := g_BackendForced;
    LPreviousForcedBackend := g_ForcedBackend;

    g_BackendTables[backend] := LCanonicalTable;
    PublishBackendDispatchTable(backend, LCanonicalTable);
    WriteBarrier;  // Ensure published snapshot is visible before marking as registered
    g_BackendRegistered[backend] := True;
    WriteBarrier;  // Ensure registration is visible before clearing initialized flag

    // Re-select immediately only after dispatch has already been initialized.
    LShouldReinitialize := (g_DispatchState = 2) and
      (InterlockedCompareExchange(g_RegisterBackendReinitializeSuspendDepth, 0, 0) = 0);
    g_DispatchInitialized := False;
    InterlockedExchange(g_DispatchState, 0);  // Reset atomic state
    atomic_thread_fence(mo_seq_cst); // Full barrier before re-initialization
    if LShouldReinitialize then
    begin
      InitializeDispatch;
      ReadBarrier;
      if (g_BackendForced <> LPreviousBackendForced) or
         (LPreviousBackendForced and (g_ForcedBackend <> LPreviousForcedBackend)) then
      begin
        // RegisterBackend is a data/control publication helper, not a
        // user-visible control-plane selection API. If a dispatch-changed hook
        // mutates forced-vs-automatic mode during notification, restore the
        // caller's pre-call intent before returning.
        if not RestoreControlPlaneIntentUntilStableLocked(LPreviousBackendForced, LPreviousForcedBackend) then
        begin
          ApplyControlPlaneIntentLocked(LPreviousBackendForced, LPreviousForcedBackend);
          ReinitializeDispatchLocked;
        end;
      end;
    end;
  finally
    LeaveCriticalSection(g_VectorAsmToggleLock);
  end;
end;

function IsBackendRegistered(backend: TSimdBackend): Boolean;
begin
  ReadBarrier;
  Result := g_BackendRegistered[backend];
end;

function GetBackendInfo(backend: TSimdBackend): TSimdBackendInfo;
var
  LDispatchTable: PSimdDispatchTable;
begin
  Result := Default(TSimdBackendInfo);

  // Ensure consistent view of registration flag and published table contents.
  ReadBarrier;
  if g_BackendRegistered[backend] then
  begin
    LDispatchTable := GetPublishedBackendDispatchTable(backend);
    if LDispatchTable <> nil then
      Result := LDispatchTable^.BackendInfo
    else
      Result.Backend := backend;
    Result.Priority := GetSimdBackendPriorityValue(backend);
  end
  else
  begin
    // Preserve canonical metadata for unregistered backends too so dispatch and
    // public ABI text getters do not drift apart.
    Result.Backend := backend;
    Result.Available := False;
    Result.Priority := GetSimdBackendPriorityValue(backend);
  end;

  Result.Backend := backend;
  Result.Priority := GetSimdBackendPriorityValue(backend);
  if Result.Name = '' then
    Result.Name := DefaultBackendName(backend);
  if Result.Description = '' then
    Result.Description := DefaultBackendDescription(backend);
  EnsureUniqueBackendInfoText(Result);
end;

function GetBackendNameTextPtr(backend: TSimdBackend): PAnsiChar;
var
  LDispatchTable: PSimdDispatchTable;
begin
  ReadBarrier;
  if g_BackendRegistered[backend] then
  begin
    LDispatchTable := GetPublishedBackendDispatchTable(backend);
    if (LDispatchTable <> nil) and (LDispatchTable^.BackendInfo.Name <> '') then
      Exit(PAnsiChar(LDispatchTable^.BackendInfo.Name));
  end;
  Result := PAnsiChar(g_DefaultBackendNames[backend]);
end;

function GetBackendDescriptionTextPtr(backend: TSimdBackend): PAnsiChar;
var
  LDispatchTable: PSimdDispatchTable;
begin
  ReadBarrier;
  if g_BackendRegistered[backend] then
  begin
    LDispatchTable := GetPublishedBackendDispatchTable(backend);
    if (LDispatchTable <> nil) and (LDispatchTable^.BackendInfo.Description <> '') then
      Exit(PAnsiChar(LDispatchTable^.BackendInfo.Description));
  end;
  Result := PAnsiChar(g_DefaultBackendDescriptions[backend]);
end;

function TryGetRegisteredBackendDispatchTable(backend: TSimdBackend; out dispatchTable: TSimdDispatchTable): Boolean;
var
  LPublishedTable: PSimdDispatchTable;
begin
  dispatchTable := Default(TSimdDispatchTable);

  // Ensure we see a consistent snapshot of the registration + published table.
  ReadBarrier;

  if g_BackendRegistered[backend] then
  begin
    LPublishedTable := GetPublishedBackendDispatchTable(backend);
    if LPublishedTable <> nil then
    begin
      dispatchTable := LPublishedTable^;
      Exit(True);
    end;
  end;

  Result := False;
end;

procedure RegisterBackendRebuilder(backend: TSimdBackend; rebuilder: TBackendRebuilder);
begin
  g_BackendRebuilders[backend] := rebuilder;
  WriteBarrier;
end;

// === Dispatch Table Helpers ===

procedure FillBaseDispatchTable(var dispatchTable: TSimdDispatchTable);
begin
  // Initialize dispatch table to zeros
  FillChar(dispatchTable, SizeOf(TSimdDispatchTable), 0);

  // Note: Backend and BackendInfo are NOT set here - caller must set them.

  // === F32x4 Arithmetic ===
  dispatchTable.AddF32x4 := @ScalarAddF32x4;
  dispatchTable.SubF32x4 := @ScalarSubF32x4;
  dispatchTable.MulF32x4 := @ScalarMulF32x4;
  dispatchTable.DivF32x4 := @ScalarDivF32x4;

  // === F32x8 Arithmetic ===
  dispatchTable.AddF32x8 := @ScalarAddF32x8;
  dispatchTable.SubF32x8 := @ScalarSubF32x8;
  dispatchTable.MulF32x8 := @ScalarMulF32x8;
  dispatchTable.DivF32x8 := @ScalarDivF32x8;

  // === F64x2 Arithmetic ===
  dispatchTable.AddF64x2 := @ScalarAddF64x2;
  dispatchTable.SubF64x2 := @ScalarSubF64x2;
  dispatchTable.MulF64x2 := @ScalarMulF64x2;
  dispatchTable.DivF64x2 := @ScalarDivF64x2;

  // === I32x4 Arithmetic ===
  dispatchTable.AddI32x4 := @ScalarAddI32x4;
  dispatchTable.SubI32x4 := @ScalarSubI32x4;
  dispatchTable.MulI32x4 := @ScalarMulI32x4;

  // === I32x4 Bitwise ===
  dispatchTable.AndI32x4 := @ScalarAndI32x4;
  dispatchTable.OrI32x4 := @ScalarOrI32x4;
  dispatchTable.XorI32x4 := @ScalarXorI32x4;
  dispatchTable.NotI32x4 := @ScalarNotI32x4;
  dispatchTable.AndNotI32x4 := @ScalarAndNotI32x4;

  // === I32x4 Shift ===
  dispatchTable.ShiftLeftI32x4 := @ScalarShiftLeftI32x4;
  dispatchTable.ShiftRightI32x4 := @ScalarShiftRightI32x4;
  dispatchTable.ShiftRightArithI32x4 := @ScalarShiftRightArithI32x4;

  // === I32x4 Comparison ===
  dispatchTable.CmpEqI32x4 := @ScalarCmpEqI32x4;
  dispatchTable.CmpLtI32x4 := @ScalarCmpLtI32x4;
  dispatchTable.CmpGtI32x4 := @ScalarCmpGtI32x4;
  dispatchTable.CmpLeI32x4 := @ScalarCmpLeI32x4;
  dispatchTable.CmpGeI32x4 := @ScalarCmpGeI32x4;
  dispatchTable.CmpNeI32x4 := @ScalarCmpNeI32x4;

  // === I32x4 MinMax ===
  dispatchTable.MinI32x4 := @ScalarMinI32x4;
  dispatchTable.MaxI32x4 := @ScalarMaxI32x4;

  // === I64x2 Arithmetic ===
  dispatchTable.AddI64x2 := @ScalarAddI64x2;
  dispatchTable.SubI64x2 := @ScalarSubI64x2;

  // === I64x2 Bitwise ===
  dispatchTable.AndI64x2 := @ScalarAndI64x2;
  dispatchTable.OrI64x2 := @ScalarOrI64x2;
  dispatchTable.XorI64x2 := @ScalarXorI64x2;
  dispatchTable.NotI64x2 := @ScalarNotI64x2;
  dispatchTable.AndNotI64x2 := @ScalarAndNotI64x2;
  dispatchTable.ShiftLeftI64x2 := @ScalarShiftLeftI64x2;
  dispatchTable.ShiftRightI64x2 := @ScalarShiftRightI64x2;
  dispatchTable.ShiftRightArithI64x2 := @ScalarShiftRightArithI64x2;

  // === I64x2 Comparison ===
  dispatchTable.CmpEqI64x2 := @ScalarCmpEqI64x2;
  dispatchTable.CmpLtI64x2 := @ScalarCmpLtI64x2;
  dispatchTable.CmpGtI64x2 := @ScalarCmpGtI64x2;
  dispatchTable.CmpLeI64x2 := @ScalarCmpLeI64x2;
  dispatchTable.CmpGeI64x2 := @ScalarCmpGeI64x2;
  dispatchTable.CmpNeI64x2 := @ScalarCmpNeI64x2;
  dispatchTable.MinI64x2 := @ScalarMinI64x2;
  dispatchTable.MaxI64x2 := @ScalarMaxI64x2;

  // === U64x2 Operations ===
  dispatchTable.AddU64x2 := @ScalarAddU64x2;
  dispatchTable.SubU64x2 := @ScalarSubU64x2;
  dispatchTable.AndU64x2 := @ScalarAndU64x2;
  dispatchTable.OrU64x2 := @ScalarOrU64x2;
  dispatchTable.XorU64x2 := @ScalarXorU64x2;
  dispatchTable.NotU64x2 := @ScalarNotU64x2;
  dispatchTable.AndNotU64x2 := @ScalarAndNotU64x2;
  dispatchTable.CmpEqU64x2 := @ScalarCmpEqU64x2;
  dispatchTable.CmpLtU64x2 := @ScalarCmpLtU64x2;
  dispatchTable.CmpGtU64x2 := @ScalarCmpGtU64x2;
  dispatchTable.MinU64x2 := @ScalarMinU64x2;
  dispatchTable.MaxU64x2 := @ScalarMaxU64x2;

  // === U32x8 Operations (256-bit AVX2) ===
  dispatchTable.AddU32x8 := @ScalarAddU32x8;
  dispatchTable.SubU32x8 := @ScalarSubU32x8;
  dispatchTable.MulU32x8 := @ScalarMulU32x8;
  dispatchTable.AndU32x8 := @ScalarAndU32x8;
  dispatchTable.OrU32x8 := @ScalarOrU32x8;
  dispatchTable.XorU32x8 := @ScalarXorU32x8;
  dispatchTable.NotU32x8 := @ScalarNotU32x8;
  dispatchTable.AndNotU32x8 := @ScalarAndNotU32x8;
  dispatchTable.ShiftLeftU32x8 := @ScalarShiftLeftU32x8;
  dispatchTable.ShiftRightU32x8 := @ScalarShiftRightU32x8;
  dispatchTable.CmpEqU32x8 := @ScalarCmpEqU32x8;
  dispatchTable.CmpLtU32x8 := @ScalarCmpLtU32x8;
  dispatchTable.CmpGtU32x8 := @ScalarCmpGtU32x8;
  dispatchTable.CmpLeU32x8 := @ScalarCmpLeU32x8;
  dispatchTable.CmpGeU32x8 := @ScalarCmpGeU32x8;
  dispatchTable.CmpNeU32x8 := @ScalarCmpNeU32x8;
  dispatchTable.MinU32x8 := @ScalarMinU32x8;
  dispatchTable.MaxU32x8 := @ScalarMaxU32x8;

  // === I64x4 Operations (256-bit AVX2) ===
  // I64x4 Arithmetic
  dispatchTable.AddI64x4 := @ScalarAddI64x4;
  dispatchTable.SubI64x4 := @ScalarSubI64x4;
  // I64x4 Bitwise
  dispatchTable.AndI64x4 := @ScalarAndI64x4;
  dispatchTable.OrI64x4 := @ScalarOrI64x4;
  dispatchTable.XorI64x4 := @ScalarXorI64x4;
  dispatchTable.NotI64x4 := @ScalarNotI64x4;
  dispatchTable.AndNotI64x4 := @ScalarAndNotI64x4;
  // I64x4 Shift
  dispatchTable.ShiftLeftI64x4 := @ScalarShiftLeftI64x4;
  dispatchTable.ShiftRightI64x4 := @ScalarShiftRightI64x4;
  dispatchTable.ShiftRightArithI64x4 := @ScalarShiftRightArithI64x4;
  // I64x4 Comparison
  dispatchTable.CmpEqI64x4 := @ScalarCmpEqI64x4;
  dispatchTable.CmpLtI64x4 := @ScalarCmpLtI64x4;
  dispatchTable.CmpGtI64x4 := @ScalarCmpGtI64x4;
  dispatchTable.CmpLeI64x4 := @ScalarCmpLeI64x4;
  dispatchTable.CmpGeI64x4 := @ScalarCmpGeI64x4;
  dispatchTable.CmpNeI64x4 := @ScalarCmpNeI64x4;
  // I64x4 Utility
  dispatchTable.LoadI64x4 := @ScalarLoadI64x4;
  dispatchTable.StoreI64x4 := @ScalarStoreI64x4;
  dispatchTable.SplatI64x4 := @ScalarSplatI64x4;
  dispatchTable.ZeroI64x4 := @ScalarZeroI64x4;

  // === U64x4 Operations (256-bit AVX2) ===
  // U64x4 Arithmetic
  dispatchTable.AddU64x4 := @ScalarAddU64x4;
  dispatchTable.SubU64x4 := @ScalarSubU64x4;
  // U64x4 Bitwise
  dispatchTable.AndU64x4 := @ScalarAndU64x4;
  dispatchTable.OrU64x4 := @ScalarOrU64x4;
  dispatchTable.XorU64x4 := @ScalarXorU64x4;
  dispatchTable.NotU64x4 := @ScalarNotU64x4;
  // U64x4 Shift
  dispatchTable.ShiftLeftU64x4 := @ScalarShiftLeftU64x4;
  dispatchTable.ShiftRightU64x4 := @ScalarShiftRightU64x4;
  // U64x4 Comparison (unsigned)
  dispatchTable.CmpEqU64x4 := @ScalarCmpEqU64x4;
  dispatchTable.CmpLtU64x4 := @ScalarCmpLtU64x4;
  dispatchTable.CmpGtU64x4 := @ScalarCmpGtU64x4;
  dispatchTable.CmpLeU64x4 := @ScalarCmpLeU64x4;
  dispatchTable.CmpGeU64x4 := @ScalarCmpGeU64x4;
  dispatchTable.CmpNeU64x4 := @ScalarCmpNeU64x4;

  // === F64x4 Arithmetic (256-bit) ===
  dispatchTable.AddF64x4 := @ScalarAddF64x4;
  dispatchTable.SubF64x4 := @ScalarSubF64x4;
  dispatchTable.MulF64x4 := @ScalarMulF64x4;
  dispatchTable.DivF64x4 := @ScalarDivF64x4;
  dispatchTable.RcpF64x4 := @ScalarRcpF64x4;

  // === I32x8 Arithmetic (256-bit) ===
  dispatchTable.AddI32x8 := @ScalarAddI32x8;
  dispatchTable.SubI32x8 := @ScalarSubI32x8;
  dispatchTable.MulI32x8 := @ScalarMulI32x8;

  // === I32x8 Bitwise ===
  dispatchTable.AndI32x8 := @ScalarAndI32x8;
  dispatchTable.OrI32x8 := @ScalarOrI32x8;
  dispatchTable.XorI32x8 := @ScalarXorI32x8;
  dispatchTable.NotI32x8 := @ScalarNotI32x8;
  dispatchTable.AndNotI32x8 := @ScalarAndNotI32x8;

  // === I32x8 Shift ===
  dispatchTable.ShiftLeftI32x8 := @ScalarShiftLeftI32x8;
  dispatchTable.ShiftRightI32x8 := @ScalarShiftRightI32x8;
  dispatchTable.ShiftRightArithI32x8 := @ScalarShiftRightArithI32x8;

  // === I32x8 Comparison ===
  dispatchTable.CmpEqI32x8 := @ScalarCmpEqI32x8;
  dispatchTable.CmpLtI32x8 := @ScalarCmpLtI32x8;
  dispatchTable.CmpGtI32x8 := @ScalarCmpGtI32x8;
  dispatchTable.CmpLeI32x8 := @ScalarCmpLeI32x8;
  dispatchTable.CmpGeI32x8 := @ScalarCmpGeI32x8;
  dispatchTable.CmpNeI32x8 := @ScalarCmpNeI32x8;

  // === I32x8 MinMax ===
  dispatchTable.MinI32x8 := @ScalarMinI32x8;
  dispatchTable.MaxI32x8 := @ScalarMaxI32x8;

  // === F32x16 Arithmetic (512-bit) ===
  dispatchTable.AddF32x16 := @ScalarAddF32x16;
  dispatchTable.SubF32x16 := @ScalarSubF32x16;
  dispatchTable.MulF32x16 := @ScalarMulF32x16;
  dispatchTable.DivF32x16 := @ScalarDivF32x16;

  // === F64x8 Arithmetic (512-bit) ===
  dispatchTable.AddF64x8 := @ScalarAddF64x8;
  dispatchTable.SubF64x8 := @ScalarSubF64x8;
  dispatchTable.MulF64x8 := @ScalarMulF64x8;
  dispatchTable.DivF64x8 := @ScalarDivF64x8;

  // === I32x16 Arithmetic (512-bit) ===
  dispatchTable.AddI32x16 := @ScalarAddI32x16;
  dispatchTable.SubI32x16 := @ScalarSubI32x16;
  dispatchTable.MulI32x16 := @ScalarMulI32x16;

  // === I32x16 Bitwise ===
  dispatchTable.AndI32x16 := @ScalarAndI32x16;
  dispatchTable.OrI32x16 := @ScalarOrI32x16;
  dispatchTable.XorI32x16 := @ScalarXorI32x16;
  dispatchTable.NotI32x16 := @ScalarNotI32x16;
  dispatchTable.AndNotI32x16 := @ScalarAndNotI32x16;

  // === I32x16 Shift ===
  dispatchTable.ShiftLeftI32x16 := @ScalarShiftLeftI32x16;
  dispatchTable.ShiftRightI32x16 := @ScalarShiftRightI32x16;
  dispatchTable.ShiftRightArithI32x16 := @ScalarShiftRightArithI32x16;

  // === I32x16 Comparison ===
  dispatchTable.CmpEqI32x16 := @ScalarCmpEqI32x16;
  dispatchTable.CmpLtI32x16 := @ScalarCmpLtI32x16;
  dispatchTable.CmpGtI32x16 := @ScalarCmpGtI32x16;
  dispatchTable.CmpLeI32x16 := @ScalarCmpLeI32x16;
  dispatchTable.CmpGeI32x16 := @ScalarCmpGeI32x16;
  dispatchTable.CmpNeI32x16 := @ScalarCmpNeI32x16;

  // === I32x16 MinMax ===
  dispatchTable.MinI32x16 := @ScalarMinI32x16;
  dispatchTable.MaxI32x16 := @ScalarMaxI32x16;

  // === I64x8 Arithmetic/Bitwise/Comparison (512-bit) ===
  dispatchTable.AddI64x8 := @ScalarAddI64x8;
  dispatchTable.SubI64x8 := @ScalarSubI64x8;
  dispatchTable.AndI64x8 := @ScalarAndI64x8;
  dispatchTable.OrI64x8 := @ScalarOrI64x8;
  dispatchTable.XorI64x8 := @ScalarXorI64x8;
  dispatchTable.NotI64x8 := @ScalarNotI64x8;
  dispatchTable.CmpEqI64x8 := @ScalarCmpEqI64x8;
  dispatchTable.CmpLtI64x8 := @ScalarCmpLtI64x8;
  dispatchTable.CmpGtI64x8 := @ScalarCmpGtI64x8;
  dispatchTable.CmpLeI64x8 := @ScalarCmpLeI64x8;
  dispatchTable.CmpGeI64x8 := @ScalarCmpGeI64x8;
  dispatchTable.CmpNeI64x8 := @ScalarCmpNeI64x8;

  // === U32x16 Arithmetic/Bitwise/Shift/Comparison/MinMax (512-bit) ===
  dispatchTable.AddU32x16 := @ScalarAddU32x16;
  dispatchTable.SubU32x16 := @ScalarSubU32x16;
  dispatchTable.MulU32x16 := @ScalarMulU32x16;
  dispatchTable.AndU32x16 := @ScalarAndU32x16;
  dispatchTable.OrU32x16 := @ScalarOrU32x16;
  dispatchTable.XorU32x16 := @ScalarXorU32x16;
  dispatchTable.NotU32x16 := @ScalarNotU32x16;
  dispatchTable.AndNotU32x16 := @ScalarAndNotU32x16;
  dispatchTable.ShiftLeftU32x16 := @ScalarShiftLeftU32x16;
  dispatchTable.ShiftRightU32x16 := @ScalarShiftRightU32x16;
  dispatchTable.CmpEqU32x16 := @ScalarCmpEqU32x16;
  dispatchTable.CmpLtU32x16 := @ScalarCmpLtU32x16;
  dispatchTable.CmpGtU32x16 := @ScalarCmpGtU32x16;
  dispatchTable.CmpLeU32x16 := @ScalarCmpLeU32x16;
  dispatchTable.CmpGeU32x16 := @ScalarCmpGeU32x16;
  dispatchTable.CmpNeU32x16 := @ScalarCmpNeU32x16;
  dispatchTable.MinU32x16 := @ScalarMinU32x16;
  dispatchTable.MaxU32x16 := @ScalarMaxU32x16;

  // === U64x8 Arithmetic/Bitwise/Shift/Comparison (512-bit) ===
  dispatchTable.AddU64x8 := @ScalarAddU64x8;
  dispatchTable.SubU64x8 := @ScalarSubU64x8;
  dispatchTable.AndU64x8 := @ScalarAndU64x8;
  dispatchTable.OrU64x8 := @ScalarOrU64x8;
  dispatchTable.XorU64x8 := @ScalarXorU64x8;
  dispatchTable.NotU64x8 := @ScalarNotU64x8;
  dispatchTable.ShiftLeftU64x8 := @ScalarShiftLeftU64x8;
  dispatchTable.ShiftRightU64x8 := @ScalarShiftRightU64x8;
  dispatchTable.CmpEqU64x8 := @ScalarCmpEqU64x8;
  dispatchTable.CmpLtU64x8 := @ScalarCmpLtU64x8;
  dispatchTable.CmpGtU64x8 := @ScalarCmpGtU64x8;
  dispatchTable.CmpLeU64x8 := @ScalarCmpLeU64x8;
  dispatchTable.CmpGeU64x8 := @ScalarCmpGeU64x8;
  dispatchTable.CmpNeU64x8 := @ScalarCmpNeU64x8;

  // === I16x32 Arithmetic/Bitwise/Shift/Comparison/MinMax (512-bit) ===
  dispatchTable.AddI16x32 := @ScalarAddI16x32;
  dispatchTable.SubI16x32 := @ScalarSubI16x32;
  dispatchTable.AndI16x32 := @ScalarAndI16x32;
  dispatchTable.OrI16x32 := @ScalarOrI16x32;
  dispatchTable.XorI16x32 := @ScalarXorI16x32;
  dispatchTable.NotI16x32 := @ScalarNotI16x32;
  dispatchTable.AndNotI16x32 := @ScalarAndNotI16x32;
  dispatchTable.ShiftLeftI16x32 := @ScalarShiftLeftI16x32;
  dispatchTable.ShiftRightI16x32 := @ScalarShiftRightI16x32;
  dispatchTable.ShiftRightArithI16x32 := @ScalarShiftRightArithI16x32;
  dispatchTable.CmpEqI16x32 := @ScalarCmpEqI16x32;
  dispatchTable.CmpLtI16x32 := @ScalarCmpLtI16x32;
  dispatchTable.CmpGtI16x32 := @ScalarCmpGtI16x32;
  dispatchTable.MinI16x32 := @ScalarMinI16x32;
  dispatchTable.MaxI16x32 := @ScalarMaxI16x32;

  // === I8x64 Arithmetic/Bitwise/Comparison/MinMax (512-bit) ===
  dispatchTable.AddI8x64 := @ScalarAddI8x64;
  dispatchTable.SubI8x64 := @ScalarSubI8x64;
  dispatchTable.AndI8x64 := @ScalarAndI8x64;
  dispatchTable.OrI8x64 := @ScalarOrI8x64;
  dispatchTable.XorI8x64 := @ScalarXorI8x64;
  dispatchTable.NotI8x64 := @ScalarNotI8x64;
  dispatchTable.AndNotI8x64 := @ScalarAndNotI8x64;
  dispatchTable.CmpEqI8x64 := @ScalarCmpEqI8x64;
  dispatchTable.CmpLtI8x64 := @ScalarCmpLtI8x64;
  dispatchTable.CmpGtI8x64 := @ScalarCmpGtI8x64;
  dispatchTable.MinI8x64 := @ScalarMinI8x64;
  dispatchTable.MaxI8x64 := @ScalarMaxI8x64;

  // === U8x64 Arithmetic/Bitwise/Comparison/MinMax (512-bit) ===
  dispatchTable.AddU8x64 := @ScalarAddU8x64;
  dispatchTable.SubU8x64 := @ScalarSubU8x64;
  dispatchTable.AndU8x64 := @ScalarAndU8x64;
  dispatchTable.OrU8x64 := @ScalarOrU8x64;
  dispatchTable.XorU8x64 := @ScalarXorU8x64;
  dispatchTable.NotU8x64 := @ScalarNotU8x64;
  dispatchTable.CmpEqU8x64 := @ScalarCmpEqU8x64;
  dispatchTable.CmpLtU8x64 := @ScalarCmpLtU8x64;
  dispatchTable.CmpGtU8x64 := @ScalarCmpGtU8x64;
  dispatchTable.MinU8x64 := @ScalarMinU8x64;
  dispatchTable.MaxU8x64 := @ScalarMaxU8x64;

  // === F32x4 Comparison ===
  dispatchTable.CmpEqF32x4 := @ScalarCmpEqF32x4;
  dispatchTable.CmpLtF32x4 := @ScalarCmpLtF32x4;
  dispatchTable.CmpLeF32x4 := @ScalarCmpLeF32x4;
  dispatchTable.CmpGtF32x4 := @ScalarCmpGtF32x4;
  dispatchTable.CmpGeF32x4 := @ScalarCmpGeF32x4;
  dispatchTable.CmpNeF32x4 := @ScalarCmpNeF32x4;

  // F64x2 比较操作
  dispatchTable.CmpEqF64x2 := @ScalarCmpEqF64x2;
  dispatchTable.CmpLtF64x2 := @ScalarCmpLtF64x2;
  dispatchTable.CmpLeF64x2 := @ScalarCmpLeF64x2;
  dispatchTable.CmpGtF64x2 := @ScalarCmpGtF64x2;
  dispatchTable.CmpGeF64x2 := @ScalarCmpGeF64x2;
  dispatchTable.CmpNeF64x2 := @ScalarCmpNeF64x2;

  // === F32x8/F64x4 Comparison (256-bit) ===
  dispatchTable.CmpEqF32x8 := @ScalarCmpEqF32x8;
  dispatchTable.CmpLtF32x8 := @ScalarCmpLtF32x8;
  dispatchTable.CmpLeF32x8 := @ScalarCmpLeF32x8;
  dispatchTable.CmpGtF32x8 := @ScalarCmpGtF32x8;
  dispatchTable.CmpGeF32x8 := @ScalarCmpGeF32x8;
  dispatchTable.CmpNeF32x8 := @ScalarCmpNeF32x8;
  dispatchTable.CmpEqF64x4 := @ScalarCmpEqF64x4;
  dispatchTable.CmpLtF64x4 := @ScalarCmpLtF64x4;
  dispatchTable.CmpLeF64x4 := @ScalarCmpLeF64x4;
  dispatchTable.CmpGtF64x4 := @ScalarCmpGtF64x4;
  dispatchTable.CmpGeF64x4 := @ScalarCmpGeF64x4;
  dispatchTable.CmpNeF64x4 := @ScalarCmpNeF64x4;

  // === F32x16/F64x8 Comparison (512-bit) ===
  dispatchTable.CmpEqF32x16 := @ScalarCmpEqF32x16;
  dispatchTable.CmpLtF32x16 := @ScalarCmpLtF32x16;
  dispatchTable.CmpLeF32x16 := @ScalarCmpLeF32x16;
  dispatchTable.CmpGtF32x16 := @ScalarCmpGtF32x16;
  dispatchTable.CmpGeF32x16 := @ScalarCmpGeF32x16;
  dispatchTable.CmpNeF32x16 := @ScalarCmpNeF32x16;
  dispatchTable.CmpEqF64x8 := @ScalarCmpEqF64x8;
  dispatchTable.CmpLtF64x8 := @ScalarCmpLtF64x8;
  dispatchTable.CmpLeF64x8 := @ScalarCmpLeF64x8;
  dispatchTable.CmpGtF64x8 := @ScalarCmpGtF64x8;
  dispatchTable.CmpGeF64x8 := @ScalarCmpGeF64x8;
  dispatchTable.CmpNeF64x8 := @ScalarCmpNeF64x8;

  // === F32x4 Math ===
  dispatchTable.AbsF32x4 := @ScalarAbsF32x4;
  dispatchTable.SqrtF32x4 := @ScalarSqrtF32x4;
  dispatchTable.MinF32x4 := @ScalarMinF32x4;
  dispatchTable.MaxF32x4 := @ScalarMaxF32x4;

  // === F32x4 Extended Math ===
  dispatchTable.FmaF32x4 := @ScalarFmaF32x4;
  dispatchTable.RcpF32x4 := @ScalarRcpF32x4;
  dispatchTable.RsqrtF32x4 := @ScalarRsqrtF32x4;
  dispatchTable.FloorF32x4 := @ScalarFloorF32x4;
  dispatchTable.CeilF32x4 := @ScalarCeilF32x4;
  dispatchTable.RoundF32x4 := @ScalarRoundF32x4;
  dispatchTable.TruncF32x4 := @ScalarTruncF32x4;
  dispatchTable.ClampF32x4 := @ScalarClampF32x4;

  // === Wide Vector Extended Math ===
  // F64x2
  dispatchTable.FmaF64x2 := @ScalarFmaF64x2;
  dispatchTable.FloorF64x2 := @ScalarFloorF64x2;
  dispatchTable.CeilF64x2 := @ScalarCeilF64x2;
  dispatchTable.RoundF64x2 := @ScalarRoundF64x2;
  dispatchTable.TruncF64x2 := @ScalarTruncF64x2;
  // F32x8
  dispatchTable.FmaF32x8 := @ScalarFmaF32x8;
  dispatchTable.FloorF32x8 := @ScalarFloorF32x8;
  dispatchTable.CeilF32x8 := @ScalarCeilF32x8;
  dispatchTable.RoundF32x8 := @ScalarRoundF32x8;
  dispatchTable.TruncF32x8 := @ScalarTruncF32x8;
  // F64x4
  dispatchTable.FmaF64x4 := @ScalarFmaF64x4;
  dispatchTable.FloorF64x4 := @ScalarFloorF64x4;
  dispatchTable.CeilF64x4 := @ScalarCeilF64x4;
  dispatchTable.RoundF64x4 := @ScalarRoundF64x4;
  dispatchTable.TruncF64x4 := @ScalarTruncF64x4;

  // F32x16 (512-bit)
  dispatchTable.FmaF32x16 := @ScalarFmaF32x16;
  dispatchTable.FloorF32x16 := @ScalarFloorF32x16;
  dispatchTable.CeilF32x16 := @ScalarCeilF32x16;
  dispatchTable.RoundF32x16 := @ScalarRoundF32x16;
  dispatchTable.TruncF32x16 := @ScalarTruncF32x16;

  // F64x8 (512-bit)
  dispatchTable.FmaF64x8 := @ScalarFmaF64x8;
  dispatchTable.FloorF64x8 := @ScalarFloorF64x8;
  dispatchTable.CeilF64x8 := @ScalarCeilF64x8;
  dispatchTable.RoundF64x8 := @ScalarRoundF64x8;
  dispatchTable.TruncF64x8 := @ScalarTruncF64x8;

  // === Wide Vector Math (Abs/Sqrt/Min/Max/Clamp) ===
  // F64x2
  dispatchTable.AbsF64x2 := @ScalarAbsF64x2;
  dispatchTable.SqrtF64x2 := @ScalarSqrtF64x2;
  dispatchTable.MinF64x2 := @ScalarMinF64x2;
  dispatchTable.MaxF64x2 := @ScalarMaxF64x2;
  dispatchTable.ClampF64x2 := @ScalarClampF64x2;
  // F32x8
  dispatchTable.AbsF32x8 := @ScalarAbsF32x8;
  dispatchTable.SqrtF32x8 := @ScalarSqrtF32x8;
  dispatchTable.MinF32x8 := @ScalarMinF32x8;
  dispatchTable.MaxF32x8 := @ScalarMaxF32x8;
  dispatchTable.ClampF32x8 := @ScalarClampF32x8;
  // F64x4
  dispatchTable.AbsF64x4 := @ScalarAbsF64x4;
  dispatchTable.SqrtF64x4 := @ScalarSqrtF64x4;
  dispatchTable.MinF64x4 := @ScalarMinF64x4;
  dispatchTable.MaxF64x4 := @ScalarMaxF64x4;
  dispatchTable.ClampF64x4 := @ScalarClampF64x4;

  // F32x16 (512-bit)
  dispatchTable.AbsF32x16 := @ScalarAbsF32x16;
  dispatchTable.SqrtF32x16 := @ScalarSqrtF32x16;
  dispatchTable.MinF32x16 := @ScalarMinF32x16;
  dispatchTable.MaxF32x16 := @ScalarMaxF32x16;
  dispatchTable.ClampF32x16 := @ScalarClampF32x16;

  // F64x8 (512-bit)
  dispatchTable.AbsF64x8 := @ScalarAbsF64x8;
  dispatchTable.SqrtF64x8 := @ScalarSqrtF64x8;
  dispatchTable.MinF64x8 := @ScalarMinF64x8;
  dispatchTable.MaxF64x8 := @ScalarMaxF64x8;
  dispatchTable.ClampF64x8 := @ScalarClampF64x8;

  // === 3D/4D Vector Math ===
  dispatchTable.DotF32x4 := @ScalarDotF32x4;
  dispatchTable.DotF32x3 := @ScalarDotF32x3;
  dispatchTable.CrossF32x3 := @ScalarCrossF32x3;
  dispatchTable.LengthF32x4 := @ScalarLengthF32x4;
  dispatchTable.LengthF32x3 := @ScalarLengthF32x3;
  dispatchTable.NormalizeF32x4 := @ScalarNormalizeF32x4;
  dispatchTable.NormalizeF32x3 := @ScalarNormalizeF32x3;

  // === FMA-optimized Dot Product ===
  dispatchTable.DotF32x8 := @ScalarDotF32x8;
  dispatchTable.DotF64x2 := @ScalarDotF64x2;
  dispatchTable.DotF64x4 := @ScalarDotF64x4;

  // === F32x4 Reduction ===
  dispatchTable.ReduceAddF32x4 := @ScalarReduceAddF32x4;
  dispatchTable.ReduceMinF32x4 := @ScalarReduceMinF32x4;
  dispatchTable.ReduceMaxF32x4 := @ScalarReduceMaxF32x4;
  dispatchTable.ReduceMulF32x4 := @ScalarReduceMulF32x4;

  // === Wide Vector Reduction ===
  // F64x2
  dispatchTable.ReduceAddF64x2 := @ScalarReduceAddF64x2;
  dispatchTable.ReduceMinF64x2 := @ScalarReduceMinF64x2;
  dispatchTable.ReduceMaxF64x2 := @ScalarReduceMaxF64x2;
  dispatchTable.ReduceMulF64x2 := @ScalarReduceMulF64x2;
  // F32x8
  dispatchTable.ReduceAddF32x8 := @ScalarReduceAddF32x8;
  dispatchTable.ReduceMinF32x8 := @ScalarReduceMinF32x8;
  dispatchTable.ReduceMaxF32x8 := @ScalarReduceMaxF32x8;
  dispatchTable.ReduceMulF32x8 := @ScalarReduceMulF32x8;
  // F64x4
  dispatchTable.ReduceAddF64x4 := @ScalarReduceAddF64x4;
  dispatchTable.ReduceMinF64x4 := @ScalarReduceMinF64x4;
  dispatchTable.ReduceMaxF64x4 := @ScalarReduceMaxF64x4;
  dispatchTable.ReduceMulF64x4 := @ScalarReduceMulF64x4;

  // F32x16 (512-bit)
  dispatchTable.ReduceAddF32x16 := @ScalarReduceAddF32x16;
  dispatchTable.ReduceMinF32x16 := @ScalarReduceMinF32x16;
  dispatchTable.ReduceMaxF32x16 := @ScalarReduceMaxF32x16;
  dispatchTable.ReduceMulF32x16 := @ScalarReduceMulF32x16;

  // F64x8 (512-bit)
  dispatchTable.ReduceAddF64x8 := @ScalarReduceAddF64x8;
  dispatchTable.ReduceMinF64x8 := @ScalarReduceMinF64x8;
  dispatchTable.ReduceMaxF64x8 := @ScalarReduceMaxF64x8;
  dispatchTable.ReduceMulF64x8 := @ScalarReduceMulF64x8;

  // === F32x4 Memory Operations ===
  dispatchTable.LoadF32x4 := @ScalarLoadF32x4;
  dispatchTable.LoadF32x4Aligned := @ScalarLoadF32x4Aligned;
  dispatchTable.StoreF32x4 := @ScalarStoreF32x4;
  dispatchTable.StoreF32x4Aligned := @ScalarStoreF32x4Aligned;

  // === F32x4 Utility Operations ===
  dispatchTable.SplatF32x4 := @ScalarSplatF32x4;
  dispatchTable.ZeroF32x4 := @ScalarZeroF32x4;
  dispatchTable.SelectF32x4 := @ScalarSelectF32x4;
  dispatchTable.ExtractF32x4 := @ScalarExtractF32x4;
  dispatchTable.InsertF32x4 := @ScalarInsertF32x4;

  // === Extract/Insert Lane Operations ===
  // F64x2 (128-bit)
  dispatchTable.ExtractF64x2 := @ScalarExtractF64x2;
  dispatchTable.InsertF64x2 := @ScalarInsertF64x2;
  // I32x4 (128-bit)
  dispatchTable.ExtractI32x4 := @ScalarExtractI32x4;
  dispatchTable.InsertI32x4 := @ScalarInsertI32x4;
  // I64x2 (128-bit)
  dispatchTable.ExtractI64x2 := @ScalarExtractI64x2;
  dispatchTable.InsertI64x2 := @ScalarInsertI64x2;
  // F32x8 (256-bit)
  dispatchTable.ExtractF32x8 := @ScalarExtractF32x8;
  dispatchTable.InsertF32x8 := @ScalarInsertF32x8;
  // F64x4 (256-bit)
  dispatchTable.ExtractF64x4 := @ScalarExtractF64x4;
  dispatchTable.InsertF64x4 := @ScalarInsertF64x4;
  // I32x8 (256-bit)
  dispatchTable.ExtractI32x8 := @ScalarExtractI32x8;
  dispatchTable.InsertI32x8 := @ScalarInsertI32x8;
  // I64x4 (256-bit)
  dispatchTable.ExtractI64x4 := @ScalarExtractI64x4;
  dispatchTable.InsertI64x4 := @ScalarInsertI64x4;
  // F32x16 (512-bit)
  dispatchTable.ExtractF32x16 := @ScalarExtractF32x16;
  dispatchTable.InsertF32x16 := @ScalarInsertF32x16;
  // I32x16 (512-bit)
  dispatchTable.ExtractI32x16 := @ScalarExtractI32x16;
  dispatchTable.InsertI32x16 := @ScalarInsertI32x16;

  // === Wide Vector Load/Store/Splat/Zero ===
  // F64x2
  dispatchTable.LoadF64x2 := @ScalarLoadF64x2;
  dispatchTable.StoreF64x2 := @ScalarStoreF64x2;
  dispatchTable.SplatF64x2 := @ScalarSplatF64x2;
  dispatchTable.ZeroF64x2 := @ScalarZeroF64x2;
  // F32x8
  dispatchTable.LoadF32x8 := @ScalarLoadF32x8;
  dispatchTable.StoreF32x8 := @ScalarStoreF32x8;
  dispatchTable.SplatF32x8 := @ScalarSplatF32x8;
  dispatchTable.ZeroF32x8 := @ScalarZeroF32x8;
  // F64x4
  dispatchTable.LoadF64x4 := @ScalarLoadF64x4;
  dispatchTable.StoreF64x4 := @ScalarStoreF64x4;
  dispatchTable.SplatF64x4 := @ScalarSplatF64x4;
  dispatchTable.ZeroF64x4 := @ScalarZeroF64x4;

  // F32x16 (512-bit)
  dispatchTable.LoadF32x16 := @ScalarLoadF32x16;
  dispatchTable.StoreF32x16 := @ScalarStoreF32x16;
  dispatchTable.SplatF32x16 := @ScalarSplatF32x16;
  dispatchTable.ZeroF32x16 := @ScalarZeroF32x16;

  // F64x8 (512-bit)
  dispatchTable.LoadF64x8 := @ScalarLoadF64x8;
  dispatchTable.StoreF64x8 := @ScalarStoreF64x8;
  dispatchTable.SplatF64x8 := @ScalarSplatF64x8;
  dispatchTable.ZeroF64x8 := @ScalarZeroF64x8;

  // === Facade Functions ===
  dispatchTable.MemEqual := @MemEqual_Scalar;
  dispatchTable.MemFindByte := @MemFindByte_Scalar;
  dispatchTable.MemDiffRange := @MemDiffRange_Scalar;
  dispatchTable.MemCopy := @MemCopy_Scalar;
  dispatchTable.MemSet := @MemSet_Scalar;
  dispatchTable.MemReverse := @MemReverse_Scalar;
  dispatchTable.SumBytes := @SumBytes_Scalar;
  dispatchTable.MinMaxBytes := @MinMaxBytes_Scalar;
  dispatchTable.CountByte := @CountByte_Scalar;
  dispatchTable.Utf8Validate := @Utf8Validate_Scalar;
  dispatchTable.AsciiIEqual := @AsciiIEqual_Scalar;
  dispatchTable.ToLowerAscii := @ToLowerAscii_Scalar;
  dispatchTable.ToUpperAscii := @ToUpperAscii_Scalar;
  dispatchTable.BytesIndexOf := @BytesIndexOf_Scalar;
  dispatchTable.BitsetPopCount := @BitsetPopCount_Scalar;

  // === Saturating Arithmetic ===
  dispatchTable.I8x16SatAdd := @ScalarI8x16SatAdd;
  dispatchTable.I8x16SatSub := @ScalarI8x16SatSub;
  dispatchTable.I16x8SatAdd := @ScalarI16x8SatAdd;
  dispatchTable.I16x8SatSub := @ScalarI16x8SatSub;
  dispatchTable.U8x16SatAdd := @ScalarU8x16SatAdd;
  dispatchTable.U8x16SatSub := @ScalarU8x16SatSub;
  dispatchTable.U16x8SatAdd := @ScalarU16x8SatAdd;
  dispatchTable.U16x8SatSub := @ScalarU16x8SatSub;

  // === Mask 操作 ===
  dispatchTable.Mask2All := @ScalarMask2All;
  dispatchTable.Mask2Any := @ScalarMask2Any;
  dispatchTable.Mask2None := @ScalarMask2None;
  dispatchTable.Mask2PopCount := @ScalarMask2PopCount;
  dispatchTable.Mask2FirstSet := @ScalarMask2FirstSet;
  dispatchTable.Mask4All := @ScalarMask4All;
  dispatchTable.Mask4Any := @ScalarMask4Any;
  dispatchTable.Mask4None := @ScalarMask4None;
  dispatchTable.Mask4PopCount := @ScalarMask4PopCount;
  dispatchTable.Mask4FirstSet := @ScalarMask4FirstSet;
  dispatchTable.Mask8All := @ScalarMask8All;
  dispatchTable.Mask8Any := @ScalarMask8Any;
  dispatchTable.Mask8None := @ScalarMask8None;
  dispatchTable.Mask8PopCount := @ScalarMask8PopCount;
  dispatchTable.Mask8FirstSet := @ScalarMask8FirstSet;
  dispatchTable.Mask16All := @ScalarMask16All;
  dispatchTable.Mask16Any := @ScalarMask16Any;
  dispatchTable.Mask16None := @ScalarMask16None;
  dispatchTable.Mask16PopCount := @ScalarMask16PopCount;
  dispatchTable.Mask16FirstSet := @ScalarMask16FirstSet;

  // === F64x2 Select ===
  dispatchTable.SelectF64x2 := @ScalarSelectF64x2;

  // === 512-bit Select ===
  dispatchTable.SelectF32x16 := @ScalarSelectF32x16;
  dispatchTable.SelectF64x8 := @ScalarSelectF64x8;

  // === 缺失的 Select 操作 ===
  dispatchTable.SelectI32x4 := @ScalarSelectI32x4;
  dispatchTable.SelectF32x8 := @ScalarSelectF32x8;
  dispatchTable.SelectF64x4 := @ScalarSelectF64x4;

  // === Narrow Integer Types (I16x8, I8x16, U32x4, U16x8, U8x16) ===

  // --- I16x8 完整操作 (8×Int16) ---
  dispatchTable.AddI16x8 := @ScalarAddI16x8;
  dispatchTable.SubI16x8 := @ScalarSubI16x8;
  dispatchTable.MulI16x8 := @ScalarMulI16x8;
  dispatchTable.AndI16x8 := @ScalarAndI16x8;
  dispatchTable.OrI16x8 := @ScalarOrI16x8;
  dispatchTable.XorI16x8 := @ScalarXorI16x8;
  dispatchTable.NotI16x8 := @ScalarNotI16x8;
  dispatchTable.AndNotI16x8 := @ScalarAndNotI16x8;
  dispatchTable.ShiftLeftI16x8 := @ScalarShiftLeftI16x8;
  dispatchTable.ShiftRightI16x8 := @ScalarShiftRightI16x8;
  dispatchTable.ShiftRightArithI16x8 := @ScalarShiftRightArithI16x8;
  dispatchTable.CmpEqI16x8 := @ScalarCmpEqI16x8;
  dispatchTable.CmpLtI16x8 := @ScalarCmpLtI16x8;
  dispatchTable.CmpGtI16x8 := @ScalarCmpGtI16x8;
  dispatchTable.CmpLeI16x8 := @ScalarCmpLeI16x8;
  dispatchTable.CmpGeI16x8 := @ScalarCmpGeI16x8;
  dispatchTable.CmpNeI16x8 := @ScalarCmpNeI16x8;
  dispatchTable.MinI16x8 := @ScalarMinI16x8;
  dispatchTable.MaxI16x8 := @ScalarMaxI16x8;

  // --- I8x16 完整操作 (16×Int8) ---
  dispatchTable.AddI8x16 := @ScalarAddI8x16;
  dispatchTable.SubI8x16 := @ScalarSubI8x16;
  dispatchTable.AndI8x16 := @ScalarAndI8x16;
  dispatchTable.OrI8x16 := @ScalarOrI8x16;
  dispatchTable.XorI8x16 := @ScalarXorI8x16;
  dispatchTable.NotI8x16 := @ScalarNotI8x16;
  dispatchTable.AndNotI8x16 := @ScalarAndNotI8x16;
  dispatchTable.CmpEqI8x16 := @ScalarCmpEqI8x16;
  dispatchTable.CmpLtI8x16 := @ScalarCmpLtI8x16;
  dispatchTable.CmpGtI8x16 := @ScalarCmpGtI8x16;
  dispatchTable.CmpLeI8x16 := @ScalarCmpLeI8x16;
  dispatchTable.CmpGeI8x16 := @ScalarCmpGeI8x16;
  dispatchTable.CmpNeI8x16 := @ScalarCmpNeI8x16;
  dispatchTable.MinI8x16 := @ScalarMinI8x16;
  dispatchTable.MaxI8x16 := @ScalarMaxI8x16;

  // --- U32x4 完整操作 (4×UInt32) ---
  dispatchTable.AddU32x4 := @ScalarAddU32x4;
  dispatchTable.SubU32x4 := @ScalarSubU32x4;
  dispatchTable.MulU32x4 := @ScalarMulU32x4;
  dispatchTable.AndU32x4 := @ScalarAndU32x4;
  dispatchTable.OrU32x4 := @ScalarOrU32x4;
  dispatchTable.XorU32x4 := @ScalarXorU32x4;
  dispatchTable.NotU32x4 := @ScalarNotU32x4;
  dispatchTable.AndNotU32x4 := @ScalarAndNotU32x4;
  dispatchTable.ShiftLeftU32x4 := @ScalarShiftLeftU32x4;
  dispatchTable.ShiftRightU32x4 := @ScalarShiftRightU32x4;
  dispatchTable.CmpEqU32x4 := @ScalarCmpEqU32x4;
  dispatchTable.CmpLtU32x4 := @ScalarCmpLtU32x4;
  dispatchTable.CmpGtU32x4 := @ScalarCmpGtU32x4;
  dispatchTable.CmpLeU32x4 := @ScalarCmpLeU32x4;
  dispatchTable.CmpGeU32x4 := @ScalarCmpGeU32x4;
  dispatchTable.MinU32x4 := @ScalarMinU32x4;
  dispatchTable.MaxU32x4 := @ScalarMaxU32x4;

  // --- U16x8 完整操作 (8×UInt16) ---
  dispatchTable.AddU16x8 := @ScalarAddU16x8;
  dispatchTable.SubU16x8 := @ScalarSubU16x8;
  dispatchTable.MulU16x8 := @ScalarMulU16x8;
  dispatchTable.AndU16x8 := @ScalarAndU16x8;
  dispatchTable.OrU16x8 := @ScalarOrU16x8;
  dispatchTable.XorU16x8 := @ScalarXorU16x8;
  dispatchTable.NotU16x8 := @ScalarNotU16x8;
  dispatchTable.AndNotU16x8 := @ScalarAndNotU16x8;
  dispatchTable.ShiftLeftU16x8 := @ScalarShiftLeftU16x8;
  dispatchTable.ShiftRightU16x8 := @ScalarShiftRightU16x8;
  dispatchTable.CmpEqU16x8 := @ScalarCmpEqU16x8;
  dispatchTable.CmpLtU16x8 := @ScalarCmpLtU16x8;
  dispatchTable.CmpGtU16x8 := @ScalarCmpGtU16x8;
  dispatchTable.CmpLeU16x8 := @ScalarCmpLeU16x8;
  dispatchTable.CmpGeU16x8 := @ScalarCmpGeU16x8;
  dispatchTable.CmpNeU16x8 := @ScalarCmpNeU16x8;
  dispatchTable.MinU16x8 := @ScalarMinU16x8;
  dispatchTable.MaxU16x8 := @ScalarMaxU16x8;

  // --- U8x16 完整操作 (16×UInt8) ---
  dispatchTable.AddU8x16 := @ScalarAddU8x16;
  dispatchTable.SubU8x16 := @ScalarSubU8x16;
  dispatchTable.AndU8x16 := @ScalarAndU8x16;
  dispatchTable.OrU8x16 := @ScalarOrU8x16;
  dispatchTable.XorU8x16 := @ScalarXorU8x16;
  dispatchTable.NotU8x16 := @ScalarNotU8x16;
  dispatchTable.AndNotU8x16 := @ScalarAndNotU8x16;
  dispatchTable.CmpEqU8x16 := @ScalarCmpEqU8x16;
  dispatchTable.CmpLtU8x16 := @ScalarCmpLtU8x16;
  dispatchTable.CmpGtU8x16 := @ScalarCmpGtU8x16;
  dispatchTable.CmpLeU8x16 := @ScalarCmpLeU8x16;
  dispatchTable.CmpGeU8x16 := @ScalarCmpGeU8x16;
  dispatchTable.CmpNeU8x16 := @ScalarCmpNeU8x16;
  dispatchTable.MinU8x16 := @ScalarMinU8x16;
  dispatchTable.MaxU8x16 := @ScalarMaxU8x16;

  // Batch array operations
  dispatchTable.ArrayAddF32 := @ScalarArrayAddF32;
  dispatchTable.ArraySubF32 := @ScalarArraySubF32;
  dispatchTable.ArrayMulF32 := @ScalarArrayMulF32;
  dispatchTable.ArrayDivF32 := @ScalarArrayDivF32;
  dispatchTable.ArrayMinF32 := @ScalarArrayMinF32;
  dispatchTable.ArrayMaxF32 := @ScalarArrayMaxF32;
  dispatchTable.ArrayAbsF32 := @ScalarArrayAbsF32;
  dispatchTable.ArrayNegF32 := @ScalarArrayNegF32;
  dispatchTable.ArraySqrtF32 := @ScalarArraySqrtF32;
  dispatchTable.ArrayRcpF32 := @ScalarArrayRcpF32;
  dispatchTable.ArrayRsqrtF32 := @ScalarArrayRsqrtF32;
  dispatchTable.ArrayRcpRefineF32 := @ScalarArrayRcpRefineF32;
  dispatchTable.ArrayRsqrtRefineF32 := @ScalarArrayRsqrtRefineF32;
  dispatchTable.ArrayAddScalarF32 := @ScalarArrayAddScalarF32;
  dispatchTable.ArrayMulScalarF32 := @ScalarArrayMulScalarF32;
  dispatchTable.ArrayClampF32 := @ScalarArrayClampF32;
  dispatchTable.ArrayFmaF32 := @ScalarArrayFmaF32;
  dispatchTable.ArrayAxpyF32 := @ScalarArrayAxpyF32;
  dispatchTable.ReduceSumF32 := @ScalarReduceSumF32;
  dispatchTable.ReduceDotF32 := @ScalarReduceDotF32;
  dispatchTable.ReduceMinF32 := @ScalarReduceMinF32;
  dispatchTable.ReduceMaxF32 := @ScalarReduceMaxF32;

  // F64 batch
  dispatchTable.ArrayAddF64 := @ScalarArrayAddF64;
  dispatchTable.ArraySubF64 := @ScalarArraySubF64;
  dispatchTable.ArrayMulF64 := @ScalarArrayMulF64;
  dispatchTable.ArrayDivF64 := @ScalarArrayDivF64;
  dispatchTable.ReduceSumF64 := @ScalarReduceSumF64;
  dispatchTable.ReduceDotF64 := @ScalarReduceDotF64;
  dispatchTable.ReduceMinF64 := @ScalarReduceMinF64;
  dispatchTable.ReduceMaxF64 := @ScalarReduceMaxF64;
  dispatchTable.ArrayAbsF64 := @ScalarArrayAbsF64;
  dispatchTable.ArrayNegF64 := @ScalarArrayNegF64;
  dispatchTable.ArraySqrtF64 := @ScalarArraySqrtF64;
  dispatchTable.ArrayMulScalarF64 := @ScalarArrayMulScalarF64;
  dispatchTable.ArrayAddScalarF64 := @ScalarArrayAddScalarF64;
  dispatchTable.ArrayClampF64 := @ScalarArrayClampF64;
  dispatchTable.ArrayLinearF64 := @ScalarArrayLinearF64;

  // Transcendental F32
  dispatchTable.ArrayExpF32 := @ScalarArrayExpF32;
  dispatchTable.ArrayLogF32 := @ScalarArrayLogF32;
  dispatchTable.ArrayPowF32 := @ScalarArrayPowF32;
  dispatchTable.ArraySinF32 := @ScalarArraySinF32;
  dispatchTable.ArrayCosF32 := @ScalarArrayCosF32;

  // Integer batch
  dispatchTable.ArrayAddI32 := @ScalarArrayAddI32;
  dispatchTable.ArraySubI32 := @ScalarArraySubI32;
  dispatchTable.ArrayMulI16 := @ScalarArrayMulI16;
  dispatchTable.ArrayPackSatI32toI16 := @ScalarArrayPackSatI32toI16;

  // Type conversion
  dispatchTable.ArrayF32toI32 := @ScalarArrayF32toI32;
  dispatchTable.ArrayI32toF32 := @ScalarArrayI32toF32;

  // Bitwise
  dispatchTable.ArrayAndI32 := @ScalarArrayAndI32;
  dispatchTable.ArrayOrI32 := @ScalarArrayOrI32;
  dispatchTable.ArrayXorI32 := @ScalarArrayXorI32;
  dispatchTable.ArrayShlI32 := @ScalarArrayShlI32;
  dispatchTable.ArrayShrI32 := @ScalarArrayShrI32;

  // Fused
  dispatchTable.ArrayLinearF32 := @ScalarArrayLinearF32;
  dispatchTable.ArrayAbsDiffF32 := @ScalarArrayAbsDiffF32;
  dispatchTable.ArrayReLUF32 := @ScalarArrayReLUF32;
  dispatchTable.ArrayNormF32 := @ScalarArrayNormF32;
  dispatchTable.ArrayLinearReLUF32 := @ScalarArrayLinearReLUF32;
end;

// 修复 允许 tier 后端从 SSE2 继承实现，而非从标量基线开始
function CloneDispatchTable(fromBackend: TSimdBackend; var dispatchTable: TSimdDispatchTable): Boolean;
var
  savedBackend: TSimdBackend;
  savedInfo: TSimdBackendInfo;
begin
  // 保存当前后端信息（调用者可能已经设置）
  savedBackend := dispatchTable.Backend;
  savedInfo := dispatchTable.BackendInfo;

  if g_BackendRegistered[fromBackend] then
  begin
    if GetPublishedBackendDispatchTable(fromBackend) <> nil then
    begin
      // 从源后端复制整个派发表
      dispatchTable := GetPublishedBackendDispatchTable(fromBackend)^;
      Result := True;
    end
    else
    begin
      FillBaseDispatchTable(dispatchTable);
      Result := False;
    end;
  end
  else
  begin
    // 源后端未注册，回退到标量基线
    FillBaseDispatchTable(dispatchTable);
    Result := False;
  end;

  // 恢复后端信息（不复制源后端的信息）
  dispatchTable.Backend := savedBackend;
  dispatchTable.BackendInfo := savedInfo;
end;

// === Initialization ===

initialization
  EnsureDispatchControlPlaneInitialized;

finalization
  FinalizeDispatchPublishedStates;
  SetLength(g_DispatchChangedHooks, 0);
  if g_DispatchControlPlaneInitialized then
  begin
    DoneCriticalSection(g_DispatchHooksLock);
    DoneCriticalSection(g_VectorAsmToggleLock);
    g_DispatchControlPlaneInitialized := False;
  end;

end.
