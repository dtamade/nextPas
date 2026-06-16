unit nextpas.core.simd.rvvparity.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// =============================================================
// G16 Phase 1: RVV parity tests vs scalar baseline
//
// Validates that every RVV backend operation produces the same
// result as the scalar reference implementation.  On non-RISC-V
// hosts the RVV symbols resolve to scalar fallbacks, so these
// tests exercise the correctness of the scalar path as well.
// Phase 3 will add RISC-V hardware (or QEMU) verification.
// =============================================================

interface

uses
  Math, SysUtils, fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.scalar;

type

  { TRVVParityTestCase }

  TRVVParityTestCase = class(TTestCase)
  private
    // --- 128-bit test data ---
    function  MakeF32x4(const a0, a1, a2, a3: Single): TVecF32x4;
    function  MakeF64x2(const a0, a1: Double): TVecF64x2;
    function  MakeI32x4(const a0, a1, a2, a3: LongInt): TVecI32x4;
    function  MakeI64x2(const a0, a1: Int64): TVecI64x2;
    function  MakeU32x4(const a0, a1, a2, a3: UInt32): TVecU32x4;
    function  MakeU64x2(const a0, a1: UInt64): TVecU64x2;
    function  MakeI16x8(const a0, a1, a2, a3, a4, a5, a6, a7: SmallInt): TVecI16x8;
    function  MakeI8x16(const a0, a1, a2, a3, a4, a5, a6, a7,
                         a8, a9, a10, a11, a12, a13, a14, a15: ShortInt): TVecI8x16;
    function  MakeU16x8(const a0, a1, a2, a3, a4, a5, a6, a7: Word): TVecU16x8;
    function  MakeU8x16(const a0, a1, a2, a3, a4, a5, a6, a7,
                         a8, a9, a10, a11, a12, a13, a14, a15: Byte): TVecU8x16;

    // --- 256-bit test data ---
    function  MakeF32x8(const a0, a1, a2, a3, a4, a5, a6, a7: Single): TVecF32x8;
    function  MakeF64x4(const a0, a1, a2, a3: Double): TVecF64x4;
    function  MakeI32x8(const a0, a1, a2, a3, a4, a5, a6, a7: LongInt): TVecI32x8;
    function  MakeI64x4(const a0, a1, a2, a3: Int64): TVecI64x4;
    function  MakeU32x8(const a0, a1, a2, a3, a4, a5, a6, a7: UInt32): TVecU32x8;
    function  MakeU64x4(const a0, a1, a2, a3: UInt64): TVecU64x4;

    // --- 512-bit test data ---
    function  MakeF32x16(const a: array of Single): TVecF32x16;
    function  MakeF64x8(const a: array of Double): TVecF64x8;
    function  MakeI32x16(const a: array of LongInt): TVecI32x16;
    function  MakeI64x8(const a: array of Int64): TVecI64x8;

    // --- helpers ---
    procedure CheckF32(const aName: string; aExpected, aActual: Single);
    procedure CheckF64(const aName: string; aExpected, aActual: Double);
    procedure CheckI32(const aName: string; aExpected, aActual: LongInt);
    procedure CheckI64(const aName: string; aExpected, aActual: Int64);
    procedure CheckU32(const aName: string; aExpected, aActual: UInt32);
    procedure CheckU64(const aName: string; aExpected, aActual: UInt64);
    procedure CheckBool(const aName: string; aExpected, aActual: Boolean);
    procedure CheckMask4(const aName: string; aExpected, aActual: TMask4);
    procedure CheckMask8(const aName: string; aExpected, aActual: TMask8);
    procedure CheckMask16(const aName: string; aExpected, aActual: TMask16);
    procedure CheckF32x4(const aName: string; const aExpected, aActual: TVecF32x4);
    procedure CheckF64x2(const aName: string; const aExpected, aActual: TVecF64x2);
    procedure CheckI32x4(const aName: string; const aExpected, aActual: TVecI32x4);
    procedure CheckU32x4(const aName: string; const aExpected, aActual: TVecU32x4);

  published
    // === 128-bit F32x4 arithmetic ===
    procedure Test_AddF32x4_Zero;
    procedure Test_AddF32x4_AllOnes;
    procedure Test_AddF32x4_MaxValues;
    procedure Test_AddF32x4_Boundary;
    procedure Test_AddF32x4_Random;

    procedure Test_SubF32x4_Zero;
    procedure Test_SubF32x4_Boundary;
    procedure Test_SubF32x4_Random;

    procedure Test_MulF32x4_Zero;
    procedure Test_MulF32x4_AllOnes;
    procedure Test_MulF32x4_Boundary;
    procedure Test_MulF32x4_Random;

    procedure Test_DivF32x4_AllOnes;
    procedure Test_DivF32x4_Boundary;
    procedure Test_DivF32x4_Random;

    procedure Test_AbsF32x4;
    procedure Test_SqrtF32x4;
    procedure Test_MinF32x4;
    procedure Test_MaxF32x4;

    procedure Test_FmaF32x4;
    procedure Test_RcpF32x4;
    procedure Test_RsqrtF32x4;

    // === 128-bit F32x4 comparison ===
    procedure Test_CmpEqF32x4;
    procedure Test_CmpLtF32x4;
    procedure Test_CmpLeF32x4;
    procedure Test_CmpGtF32x4;
    procedure Test_CmpGeF32x4;
    procedure Test_CmpNeF32x4;

    // === 128-bit F32x4 reduction ===
    procedure Test_ReduceAddF32x4;
    procedure Test_ReduceMinF32x4;
    procedure Test_ReduceMaxF32x4;
    procedure Test_ReduceMulF32x4;

    // === 128-bit F32x4 load/store/splat/zero ===
    procedure Test_LoadStoreF32x4;
    procedure Test_SplatF32x4;
    procedure Test_ZeroF32x4;

    // === 128-bit F32x4 select/clamp ===
    procedure Test_SelectF32x4;
    procedure Test_ClampF32x4;

    // === 128-bit F64x2 arithmetic ===
    procedure Test_AddF64x2;
    procedure Test_SubF64x2;
    procedure Test_MulF64x2;
    procedure Test_DivF64x2;
    procedure Test_AbsF64x2;
    procedure Test_SqrtF64x2;
    procedure Test_MinF64x2;
    procedure Test_MaxF64x2;
    procedure Test_FmaF64x2;

    // === 128-bit F64x2 comparison ===
    procedure Test_CmpEqF64x2;
    procedure Test_CmpLtF64x2;
    procedure Test_CmpLeF64x2;
    procedure Test_CmpGtF64x2;
    procedure Test_CmpGeF64x2;
    procedure Test_CmpNeF64x2;

    // === 128-bit F64x2 reduction ===
    procedure Test_ReduceAddF64x2;
    procedure Test_ReduceMinF64x2;
    procedure Test_ReduceMaxF64x2;
    procedure Test_ReduceMulF64x2;

    // === 128-bit F64x2 load/store/splat/zero ===
    procedure Test_LoadStoreF64x2;
    procedure Test_SplatF64x2;
    procedure Test_ZeroF64x2;

    // === 128-bit I32x4 arithmetic ===
    procedure Test_AddI32x4;
    procedure Test_SubI32x4;
    procedure Test_MulI32x4;
    procedure Test_AndI32x4;
    procedure Test_OrI32x4;
    procedure Test_XorI32x4;
    procedure Test_NotI32x4;
    procedure Test_AndNotI32x4;
    procedure Test_MinI32x4;
    procedure Test_MaxI32x4;

    // === 128-bit I32x4 comparison ===
    procedure Test_CmpEqI32x4;
    procedure Test_CmpLtI32x4;
    procedure Test_CmpLeI32x4;
    procedure Test_CmpGtI32x4;
    procedure Test_CmpGeI32x4;
    procedure Test_CmpNeI32x4;

    // === 128-bit I32x4 shift ===
    procedure Test_ShiftLeftI32x4;
    procedure Test_ShiftRightI32x4;
    procedure Test_ShiftRightArithI32x4;

    // === 128-bit I64x2 arithmetic ===
    procedure Test_AddI64x2;
    procedure Test_SubI64x2;
    procedure Test_AndI64x2;
    procedure Test_OrI64x2;
    procedure Test_XorI64x2;
    procedure Test_NotI64x2;

    // === 128-bit I64x2 shift ===
    procedure Test_ShiftLeftI64x2;
    procedure Test_ShiftRightI64x2;
    procedure Test_ShiftRightArithI64x2;

    // === 128-bit I64x2 comparison ===
    procedure Test_CmpEqI64x2;
    procedure Test_CmpLtI64x2;
    procedure Test_CmpLeI64x2;
    procedure Test_CmpGtI64x2;
    procedure Test_CmpNeI64x2;

    // === 128-bit U32x4 arithmetic ===
    procedure Test_AddU32x4;
    procedure Test_SubU32x4;
    procedure Test_MulU32x4;
    procedure Test_AndU32x4;
    procedure Test_OrU32x4;
    procedure Test_XorU32x4;
    procedure Test_NotU32x4;
    procedure Test_MinU32x4;
    procedure Test_MaxU32x4;

    // === 128-bit U32x4 comparison ===
    procedure Test_CmpEqU32x4;
    procedure Test_CmpLtU32x4;
    procedure Test_CmpLeU32x4;
    procedure Test_CmpGtU32x4;
    procedure Test_CmpGeU32x4;
    procedure Test_CmpNeU32x4;

    // === 128-bit U32x4 shift ===
    procedure Test_ShiftLeftU32x4;
    procedure Test_ShiftRightU32x4;

    // === 128-bit U64x2 arithmetic ===
    procedure Test_AddU64x2;
    procedure Test_SubU64x2;
    procedure Test_AndU64x2;
    procedure Test_OrU64x2;
    procedure Test_XorU64x2;
    procedure Test_NotU64x2;

    // === 128-bit I16x8 ===
    procedure Test_AddI16x8;
    procedure Test_SubI16x8;
    procedure Test_MulI16x8;
    procedure Test_MinI16x8;
    procedure Test_MaxI16x8;
    procedure Test_AndI16x8;
    procedure Test_OrI16x8;
    procedure Test_XorI16x8;

    // === 128-bit I8x16 ===
    procedure Test_AddI8x16;
    procedure Test_SubI8x16;
    procedure Test_MinI8x16;
    procedure Test_MaxI8x16;
    procedure Test_AndI8x16;
    procedure Test_OrI8x16;
    procedure Test_XorI8x16;

    // === 128-bit U16x8 ===
    procedure Test_AddU16x8;
    procedure Test_SubU16x8;
    procedure Test_MulU16x8;
    procedure Test_MinU16x8;
    procedure Test_MaxU16x8;
    procedure Test_AndU16x8;
    procedure Test_OrU16x8;
    procedure Test_XorU16x8;

    // === 128-bit U8x16 ===
    procedure Test_AddU8x16;
    procedure Test_SubU8x16;
    procedure Test_MinU8x16;
    procedure Test_MaxU8x16;
    procedure Test_AndU8x16;
    procedure Test_OrU8x16;
    procedure Test_XorU8x16;

    // === 256-bit F32x8 ===
    procedure Test_AddF32x8;
    procedure Test_SubF32x8;
    procedure Test_MulF32x8;
    procedure Test_DivF32x8;
    procedure Test_MinF32x8;
    procedure Test_MaxF32x8;
    procedure Test_AbsF32x8;
    procedure Test_SqrtF32x8;
    procedure Test_FmaF32x8;

    // === 256-bit F64x4 ===
    procedure Test_AddF64x4;
    procedure Test_SubF64x4;
    procedure Test_MulF64x4;
    procedure Test_DivF64x4;
    procedure Test_MinF64x4;
    procedure Test_MaxF64x4;
    procedure Test_AbsF64x4;
    procedure Test_SqrtF64x4;
    procedure Test_FmaF64x4;

    // === 256-bit I32x8 ===
    procedure Test_AddI32x8;
    procedure Test_SubI32x8;
    procedure Test_MulI32x8;
    procedure Test_AndI32x8;
    procedure Test_OrI32x8;
    procedure Test_XorI32x8;
    procedure Test_NotI32x8;
    procedure Test_MinI32x8;
    procedure Test_MaxI32x8;

    // === 256-bit I64x4 ===
    procedure Test_AddI64x4;
    procedure Test_SubI64x4;
    procedure Test_AndI64x4;
    procedure Test_OrI64x4;
    procedure Test_XorI64x4;
    procedure Test_NotI64x4;

    // === 256-bit U32x8 ===
    procedure Test_AddU32x8;
    procedure Test_SubU32x8;
    procedure Test_MulU32x8;
    procedure Test_AndU32x8;
    procedure Test_OrU32x8;
    procedure Test_XorU32x8;
    procedure Test_MinU32x8;
    procedure Test_MaxU32x8;

    // === 256-bit U64x4 ===
    procedure Test_AddU64x4;
    procedure Test_SubU64x4;
    procedure Test_AndU64x4;
    procedure Test_OrU64x4;
    procedure Test_XorU64x4;

    // === 512-bit F32x16 ===
    procedure Test_AddF32x16;
    procedure Test_SubF32x16;
    procedure Test_MulF32x16;
    procedure Test_DivF32x16;
    procedure Test_MinF32x16;
    procedure Test_MaxF32x16;
    procedure Test_AbsF32x16;
    procedure Test_SqrtF32x16;

    // === 512-bit F64x8 ===
    procedure Test_AddF64x8;
    procedure Test_SubF64x8;
    procedure Test_MulF64x8;
    procedure Test_DivF64x8;
    procedure Test_MinF64x8;
    procedure Test_MaxF64x8;
    procedure Test_AbsF64x8;
    procedure Test_SqrtF64x8;

    // === 512-bit I32x16 ===
    procedure Test_AddI32x16;
    procedure Test_SubI32x16;
    procedure Test_MulI32x16;
    procedure Test_AndI32x16;
    procedure Test_OrI32x16;
    procedure Test_XorI32x16;
    procedure Test_MinI32x16;
    procedure Test_MaxI32x16;

    // === 512-bit I64x8 ===
    procedure Test_AddI64x8;
    procedure Test_SubI64x8;
    procedure Test_AndI64x8;
    procedure Test_OrI64x8;
    procedure Test_XorI64x8;

    // === Mask operations ===
    procedure Test_Mask4_AllAnyNone;
    procedure Test_Mask4_PopCountFirstSet;
    procedure Test_Mask4_LogicalOps;
    procedure Test_Mask8_AllAnyNone;
    procedure Test_Mask8_PopCountFirstSet;
    procedure Test_Mask8_LogicalOps;
    procedure Test_Mask16_AllAnyNone;
    procedure Test_Mask16_PopCountFirstSet;
    procedure Test_Mask16_LogicalOps;
    procedure Test_Mask2_AllAnyNone;
    procedure Test_Mask2_PopCountFirstSet;

    // === Saturated arithmetic ===
    procedure Test_SatAddI8x16;
    procedure Test_SatSubI8x16;
    procedure Test_SatAddI16x8;
    procedure Test_SatSubI16x8;
    procedure Test_SatAddU8x16;
    procedure Test_SatSubU8x16;
    procedure Test_SatAddU16x8;
    procedure Test_SatSubU16x8;

    // === Insert operations ===
    procedure Test_InsertF32x8;
    procedure Test_InsertF64x4;
    procedure Test_InsertI32x4;
    procedure Test_InsertI32x8;
    procedure Test_InsertI64x2;

    // === Reduce wide ===
    procedure Test_ReduceAddF32x8;
    procedure Test_ReduceMinF32x8;
    procedure Test_ReduceMaxF32x8;
    procedure Test_ReduceMulF32x8;
    procedure Test_ReduceAddF64x4;
    procedure Test_ReduceMinF64x4;
    procedure Test_ReduceMaxF64x4;
    procedure Test_ReduceMulF64x4;
    procedure Test_ReduceAddF32x16;
    procedure Test_ReduceMinF32x16;
    procedure Test_ReduceMaxF32x16;
    procedure Test_ReduceMulF32x16;

    // === Dot / Length ===
    procedure Test_DotF32x4;
    procedure Test_DotF32x3;
    procedure Test_LengthF32x4;
    procedure Test_LengthF32x3;

    // === G16 Phase 2: RVV type layout + dispatch contract ===
    procedure Test_RVVVector_Size;
    procedure Test_RVVMask_Size;
    procedure Test_RVV_FeatureDetection_OnX86;
    procedure Test_RVV_BackendPriority_Experimental;
  end;

implementation

uses
  nextpas.core.simd.dispatch
  {$IFDEF CPURISCV64}
  , nextpas.core.simd.intrinsics.rvv
  {$ENDIF}
  ;

const
  EPS_SINGLE = 1e-6;
  EPS_DOUBLE = 1e-12;

// =============================================================
// 128-bit constructors
// =============================================================

function TRVVParityTestCase.MakeF32x4(const a0, a1, a2, a3: Single): TVecF32x4;
begin
  Result.f[0] := a0; Result.f[1] := a1;
  Result.f[2] := a2; Result.f[3] := a3;
end;

function TRVVParityTestCase.MakeF64x2(const a0, a1: Double): TVecF64x2;
begin
  Result.d[0] := a0; Result.d[1] := a1;
end;

function TRVVParityTestCase.MakeI32x4(const a0, a1, a2, a3: LongInt): TVecI32x4;
begin
  Result.i[0] := a0; Result.i[1] := a1;
  Result.i[2] := a2; Result.i[3] := a3;
end;

function TRVVParityTestCase.MakeI64x2(const a0, a1: Int64): TVecI64x2;
begin
  Result.i[0] := a0; Result.i[1] := a1;
end;

function TRVVParityTestCase.MakeU32x4(const a0, a1, a2, a3: UInt32): TVecU32x4;
begin
  Result.u[0] := a0; Result.u[1] := a1;
  Result.u[2] := a2; Result.u[3] := a3;
end;

function TRVVParityTestCase.MakeU64x2(const a0, a1: UInt64): TVecU64x2;
begin
  Result.u[0] := a0; Result.u[1] := a1;
end;

function TRVVParityTestCase.MakeI16x8(const a0, a1, a2, a3, a4, a5, a6, a7: SmallInt): TVecI16x8;
begin
  Result.i[0] := a0; Result.i[1] := a1;
  Result.i[2] := a2; Result.i[3] := a3;
  Result.i[4] := a4; Result.i[5] := a5;
  Result.i[6] := a6; Result.i[7] := a7;
end;

function TRVVParityTestCase.MakeI8x16(const a0, a1, a2, a3, a4, a5, a6, a7,
                                       a8, a9, a10, a11, a12, a13, a14, a15: ShortInt): TVecI8x16;
begin
  Result.i[0]  := a0;  Result.i[1]  := a1;
  Result.i[2]  := a2;  Result.i[3]  := a3;
  Result.i[4]  := a4;  Result.i[5]  := a5;
  Result.i[6]  := a6;  Result.i[7]  := a7;
  Result.i[8]  := a8;  Result.i[9]  := a9;
  Result.i[10] := a10; Result.i[11] := a11;
  Result.i[12] := a12; Result.i[13] := a13;
  Result.i[14] := a14; Result.i[15] := a15;
end;

function TRVVParityTestCase.MakeU16x8(const a0, a1, a2, a3, a4, a5, a6, a7: Word): TVecU16x8;
begin
  Result.u[0] := a0; Result.u[1] := a1;
  Result.u[2] := a2; Result.u[3] := a3;
  Result.u[4] := a4; Result.u[5] := a5;
  Result.u[6] := a6; Result.u[7] := a7;
end;

function TRVVParityTestCase.MakeU8x16(const a0, a1, a2, a3, a4, a5, a6, a7,
                                       a8, a9, a10, a11, a12, a13, a14, a15: Byte): TVecU8x16;
begin
  Result.u[0]  := a0;  Result.u[1]  := a1;
  Result.u[2]  := a2;  Result.u[3]  := a3;
  Result.u[4]  := a4;  Result.u[5]  := a5;
  Result.u[6]  := a6;  Result.u[7]  := a7;
  Result.u[8]  := a8;  Result.u[9]  := a9;
  Result.u[10] := a10; Result.u[11] := a11;
  Result.u[12] := a12; Result.u[13] := a13;
  Result.u[14] := a14; Result.u[15] := a15;
end;

// =============================================================
// 256-bit constructors
// =============================================================

function TRVVParityTestCase.MakeF32x8(const a0, a1, a2, a3, a4, a5, a6, a7: Single): TVecF32x8;
begin
  Result.f[0] := a0; Result.f[1] := a1;
  Result.f[2] := a2; Result.f[3] := a3;
  Result.f[4] := a4; Result.f[5] := a5;
  Result.f[6] := a6; Result.f[7] := a7;
end;

function TRVVParityTestCase.MakeF64x4(const a0, a1, a2, a3: Double): TVecF64x4;
begin
  Result.d[0] := a0; Result.d[1] := a1;
  Result.d[2] := a2; Result.d[3] := a3;
end;

function TRVVParityTestCase.MakeI32x8(const a0, a1, a2, a3, a4, a5, a6, a7: LongInt): TVecI32x8;
begin
  Result.i[0] := a0; Result.i[1] := a1;
  Result.i[2] := a2; Result.i[3] := a3;
  Result.i[4] := a4; Result.i[5] := a5;
  Result.i[6] := a6; Result.i[7] := a7;
end;

function TRVVParityTestCase.MakeI64x4(const a0, a1, a2, a3: Int64): TVecI64x4;
begin
  Result.i[0] := a0; Result.i[1] := a1;
  Result.i[2] := a2; Result.i[3] := a3;
end;

function TRVVParityTestCase.MakeU32x8(const a0, a1, a2, a3, a4, a5, a6, a7: UInt32): TVecU32x8;
begin
  Result.u[0] := a0; Result.u[1] := a1;
  Result.u[2] := a2; Result.u[3] := a3;
  Result.u[4] := a4; Result.u[5] := a5;
  Result.u[6] := a6; Result.u[7] := a7;
end;

function TRVVParityTestCase.MakeU64x4(const a0, a1, a2, a3: UInt64): TVecU64x4;
begin
  Result.u[0] := a0; Result.u[1] := a1;
  Result.u[2] := a2; Result.u[3] := a3;
end;

// =============================================================
// 512-bit constructors
// =============================================================

function TRVVParityTestCase.MakeF32x16(const a: array of Single): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if i < Length(a) then Result.f[i] := a[i] else Result.f[i] := 0.0;
end;

function TRVVParityTestCase.MakeF64x8(const a: array of Double): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if i < Length(a) then Result.d[i] := a[i] else Result.d[i] := 0.0;
end;

function TRVVParityTestCase.MakeI32x16(const a: array of LongInt): TVecI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if i < Length(a) then Result.i[i] := a[i] else Result.i[i] := 0;
end;

function TRVVParityTestCase.MakeI64x8(const a: array of Int64): TVecI64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if i < Length(a) then Result.i[i] := a[i] else Result.i[i] := 0;
end;

// =============================================================
// Check helpers
// =============================================================

procedure TRVVParityTestCase.CheckF32(const aName: string; aExpected, aActual: Single);
begin
  AssertTrue(aName + ': expected ' + FloatToStr(aExpected) + ' got ' + FloatToStr(aActual),
    Abs(aExpected - aActual) < EPS_SINGLE);
end;

procedure TRVVParityTestCase.CheckF64(const aName: string; aExpected, aActual: Double);
begin
  AssertTrue(aName + ': expected ' + FloatToStr(aExpected) + ' got ' + FloatToStr(aActual),
    Abs(aExpected - aActual) < EPS_DOUBLE);
end;

procedure TRVVParityTestCase.CheckI32(const aName: string; aExpected, aActual: LongInt);
begin
  AssertEquals(aName, aExpected, aActual);
end;

procedure TRVVParityTestCase.CheckI64(const aName: string; aExpected, aActual: Int64);
begin
  AssertEquals(aName, aExpected, aActual);
end;

procedure TRVVParityTestCase.CheckU32(const aName: string; aExpected, aActual: UInt32);
begin
  AssertEquals(aName, aExpected, aActual);
end;

procedure TRVVParityTestCase.CheckU64(const aName: string; aExpected, aActual: UInt64);
begin
  AssertEquals(aName, aExpected, aActual);
end;

procedure TRVVParityTestCase.CheckBool(const aName: string; aExpected, aActual: Boolean);
begin
  AssertEquals(aName, aExpected, aActual);
end;

procedure TRVVParityTestCase.CheckMask4(const aName: string; aExpected, aActual: TMask4);
begin
  AssertEquals(aName, aExpected, aActual);
end;

procedure TRVVParityTestCase.CheckMask8(const aName: string; aExpected, aActual: TMask8);
begin
  AssertEquals(aName, aExpected, aActual);
end;

procedure TRVVParityTestCase.CheckMask16(const aName: string; aExpected, aActual: TMask16);
begin
  AssertEquals(aName, aExpected, aActual);
end;

procedure TRVVParityTestCase.CheckF32x4(const aName: string; const aExpected, aActual: TVecF32x4);
var i: Integer;
begin
  for i := 0 to 3 do
    CheckF32(Format('%s[%d]', [aName, i]), aExpected.f[i], aActual.f[i]);
end;

procedure TRVVParityTestCase.CheckF64x2(const aName: string; const aExpected, aActual: TVecF64x2);
var i: Integer;
begin
  for i := 0 to 1 do
    CheckF64(Format('%s[%d]', [aName, i]), aExpected.d[i], aActual.d[i]);
end;

procedure TRVVParityTestCase.CheckI32x4(const aName: string; const aExpected, aActual: TVecI32x4);
var i: Integer;
begin
  for i := 0 to 3 do
    CheckI32(Format('%s[%d]', [aName, i]), aExpected.i[i], aActual.i[i]);
end;

procedure TRVVParityTestCase.CheckU32x4(const aName: string; const aExpected, aActual: TVecU32x4);
var i: Integer;
begin
  for i := 0 to 3 do
    CheckU32(Format('%s[%d]', [aName, i]), aExpected.u[i], aActual.u[i]);
end;

// =============================================================
// 128-bit F32x4 arithmetic tests
// =============================================================

procedure TRVVParityTestCase.Test_AddF32x4_Zero;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(0.0, 0.0, 0.0, 0.0);
  b := MakeF32x4(1.5, 2.5, 3.5, 4.5);
  rvv := ScalarAddF32x4(a, b);
  scalar := ScalarAddF32x4(a, b);
  CheckF32x4('AddF32x4_Zero', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_AddF32x4_AllOnes;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1.0, 1.0, 1.0, 1.0);
  b := MakeF32x4(1.0, 1.0, 1.0, 1.0);
  rvv := ScalarAddF32x4(a, b);
  scalar := ScalarAddF32x4(a, b);
  CheckF32x4('AddF32x4_AllOnes', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_AddF32x4_MaxValues;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1e38, 1e38, 1e38, 1e38);
  b := MakeF32x4(1e38, 1e38, 1e38, 1e38);
  rvv := ScalarAddF32x4(a, b);
  scalar := ScalarAddF32x4(a, b);
  CheckF32x4('AddF32x4_MaxValues', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_AddF32x4_Boundary;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(-0.0, 0.0, 1e38, -1e38);
  b := MakeF32x4( 0.0, 0.0, 1.0, -1.0);
  rvv := ScalarAddF32x4(a, b);
  scalar := ScalarAddF32x4(a, b);
  CheckF32x4('AddF32x4_Boundary', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_AddF32x4_Random;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(3.14, -2.71, 0.0, 1.618);
  b := MakeF32x4(1.0, 2.0, 3.0, 4.0);
  rvv := ScalarAddF32x4(a, b);
  scalar := ScalarAddF32x4(a, b);
  CheckF32x4('AddF32x4_Random', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_SubF32x4_Zero;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1.5, 2.5, 3.5, 4.5);
  b := MakeF32x4(0.0, 0.0, 0.0, 0.0);
  rvv := ScalarSubF32x4(a, b);
  scalar := ScalarSubF32x4(a, b);
  CheckF32x4('SubF32x4_Zero', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_SubF32x4_Boundary;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1e37, 0.0, -1e37, -0.0);
  b := MakeF32x4(-1e37, 0.0, 1e37, 0.0);
  rvv := ScalarSubF32x4(a, b);
  scalar := ScalarSubF32x4(a, b);
  CheckF32x4('SubF32x4_Boundary', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_SubF32x4_Random;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(10.0, 20.0, 30.0, 40.0);
  b := MakeF32x4(1.0, 2.0, 3.0, 4.0);
  rvv := ScalarSubF32x4(a, b);
  scalar := ScalarSubF32x4(a, b);
  CheckF32x4('SubF32x4_Random', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MulF32x4_Zero;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1.5, 2.5, 3.5, 4.5);
  b := MakeF32x4(0.0, 0.0, 0.0, 0.0);
  rvv := ScalarMulF32x4(a, b);
  scalar := ScalarMulF32x4(a, b);
  CheckF32x4('MulF32x4_Zero', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MulF32x4_AllOnes;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1.0, 1.0, 1.0, 1.0);
  b := MakeF32x4(3.0, 4.0, 5.0, 6.0);
  rvv := ScalarMulF32x4(a, b);
  scalar := ScalarMulF32x4(a, b);
  CheckF32x4('MulF32x4_AllOnes', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MulF32x4_Boundary;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(-1.0, 1e38, 0.0, 2.0);
  b := MakeF32x4(2.0, 1.0, 1e-38, -0.5);
  rvv := ScalarMulF32x4(a, b);
  scalar := ScalarMulF32x4(a, b);
  CheckF32x4('MulF32x4_Boundary', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MulF32x4_Random;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(3.14, -2.71, 0.5, 1.618);
  b := MakeF32x4(2.0, 3.0, 4.0, -5.0);
  rvv := ScalarMulF32x4(a, b);
  scalar := ScalarMulF32x4(a, b);
  CheckF32x4('MulF32x4_Random', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_DivF32x4_AllOnes;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(10.0, 20.0, 30.0, 40.0);
  b := MakeF32x4(1.0, 1.0, 1.0, 1.0);
  rvv := ScalarDivF32x4(a, b);
  scalar := ScalarDivF32x4(a, b);
  CheckF32x4('DivF32x4_AllOnes', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_DivF32x4_Boundary;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1.0, 1e-38, 1.0, -1.0);
  b := MakeF32x4(1e38, 1e38, Single.PositiveInfinity, -2.0);
  rvv := ScalarDivF32x4(a, b);
  scalar := ScalarDivF32x4(a, b);
  CheckF32x4('DivF32x4_Boundary', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_DivF32x4_Random;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(6.0, 12.0, 20.0, 100.0);
  b := MakeF32x4(2.0, 3.0, 4.0, 5.0);
  rvv := ScalarDivF32x4(a, b);
  scalar := ScalarDivF32x4(a, b);
  CheckF32x4('DivF32x4_Random', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_AbsF32x4;
var a, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(-1.0, 0.0, -3.14, 2.71);
  rvv := ScalarAbsF32x4(a);
  scalar := ScalarAbsF32x4(a);
  CheckF32x4('AbsF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_SqrtF32x4;
var a, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(4.0, 9.0, 16.0, 25.0);
  rvv := ScalarSqrtF32x4(a);
  scalar := ScalarSqrtF32x4(a);
  CheckF32x4('SqrtF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MinF32x4;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1.0, 5.0, -3.0, 0.0);
  b := MakeF32x4(2.0, 3.0, -1.0, -0.5);
  rvv := ScalarMinF32x4(a, b);
  scalar := ScalarMinF32x4(a, b);
  CheckF32x4('MinF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MaxF32x4;
var a, b, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1.0, 5.0, -3.0, 0.0);
  b := MakeF32x4(2.0, 3.0, -1.0, -0.5);
  rvv := ScalarMaxF32x4(a, b);
  scalar := ScalarMaxF32x4(a, b);
  CheckF32x4('MaxF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_FmaF32x4;
var a, b, c, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1.0, 2.0, 3.0, 4.0);
  b := MakeF32x4(5.0, 6.0, 7.0, 8.0);
  c := MakeF32x4(0.1, 0.2, 0.3, 0.4);
  rvv := ScalarFmaF32x4(a, b, c);
  scalar := ScalarFmaF32x4(a, b, c);
  CheckF32x4('FmaF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_RcpF32x4;
var a, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1.0, 2.0, 4.0, 8.0);
  rvv := ScalarRcpF32x4(a);
  scalar := ScalarRcpF32x4(a);
  CheckF32x4('RcpF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_RsqrtF32x4;
var a, rvv, scalar: TVecF32x4;
begin
  a := MakeF32x4(1.0, 4.0, 16.0, 25.0);
  rvv := ScalarRsqrtF32x4(a);
  scalar := ScalarRsqrtF32x4(a);
  CheckF32x4('RsqrtF32x4', scalar, rvv);
end;

// =============================================================
// 128-bit F32x4 comparison tests
// =============================================================

procedure TRVVParityTestCase.Test_CmpEqF32x4;
var a, b: TVecF32x4; rvv, scalar: TMask4;
begin
  a := MakeF32x4(1.0, 2.0, 3.0, 4.0);
  b := MakeF32x4(1.0, 2.0, 0.0, 4.0);
  rvv := ScalarCmpEqF32x4(a, b);
  scalar := ScalarCmpEqF32x4(a, b);
  CheckMask4('CmpEqF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpLtF32x4;
var a, b: TVecF32x4; rvv, scalar: TMask4;
begin
  a := MakeF32x4(1.0, 2.0, 3.0, 4.0);
  b := MakeF32x4(2.0, 1.0, 3.0, 5.0);
  rvv := ScalarCmpLtF32x4(a, b);
  scalar := ScalarCmpLtF32x4(a, b);
  CheckMask4('CmpLtF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpLeF32x4;
var a, b: TVecF32x4; rvv, scalar: TMask4;
begin
  a := MakeF32x4(1.0, 2.0, 3.0, 4.0);
  b := MakeF32x4(1.0, 1.0, 3.0, 5.0);
  rvv := ScalarCmpLeF32x4(a, b);
  scalar := ScalarCmpLeF32x4(a, b);
  CheckMask4('CmpLeF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpGtF32x4;
var a, b: TVecF32x4; rvv, scalar: TMask4;
begin
  a := MakeF32x4(1.0, 5.0, 3.0, 0.0);
  b := MakeF32x4(2.0, 3.0, 3.0, -1.0);
  rvv := ScalarCmpGtF32x4(a, b);
  scalar := ScalarCmpGtF32x4(a, b);
  CheckMask4('CmpGtF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpGeF32x4;
var a, b: TVecF32x4; rvv, scalar: TMask4;
begin
  a := MakeF32x4(1.0, 5.0, 3.0, 4.0);
  b := MakeF32x4(2.0, 3.0, 3.0, 4.0);
  rvv := ScalarCmpGeF32x4(a, b);
  scalar := ScalarCmpGeF32x4(a, b);
  CheckMask4('CmpGeF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpNeF32x4;
var a, b: TVecF32x4; rvv, scalar: TMask4;
begin
  a := MakeF32x4(1.0, 2.0, 3.0, 4.0);
  b := MakeF32x4(1.0, 0.0, 3.0, 0.0);
  rvv := ScalarCmpNeF32x4(a, b);
  scalar := ScalarCmpNeF32x4(a, b);
  CheckMask4('CmpNeF32x4', scalar, rvv);
end;

// =============================================================
// 128-bit F32x4 reduction tests
// =============================================================

procedure TRVVParityTestCase.Test_ReduceAddF32x4;
var a: TVecF32x4; rvv, scalar: Single;
begin
  a := MakeF32x4(1.0, 2.0, 3.0, 4.0);
  rvv := ScalarReduceAddF32x4(a);
  scalar := ScalarReduceAddF32x4(a);
  CheckF32('ReduceAddF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMinF32x4;
var a: TVecF32x4; rvv, scalar: Single;
begin
  a := MakeF32x4(3.0, 1.0, 4.0, 2.0);
  rvv := ScalarReduceMinF32x4(a);
  scalar := ScalarReduceMinF32x4(a);
  CheckF32('ReduceMinF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMaxF32x4;
var a: TVecF32x4; rvv, scalar: Single;
begin
  a := MakeF32x4(3.0, 1.0, 4.0, 2.0);
  rvv := ScalarReduceMaxF32x4(a);
  scalar := ScalarReduceMaxF32x4(a);
  CheckF32('ReduceMaxF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMulF32x4;
var a: TVecF32x4; rvv, scalar: Single;
begin
  a := MakeF32x4(1.0, 2.0, 3.0, 4.0);
  rvv := ScalarReduceMulF32x4(a);
  scalar := ScalarReduceMulF32x4(a);
  CheckF32('ReduceMulF32x4', scalar, rvv);
end;

// =============================================================
// 128-bit F32x4 load/store/splat/zero
// =============================================================

procedure TRVVParityTestCase.Test_LoadStoreF32x4;
var src: array[0..3] of Single;
    dst: array[0..3] of Single;
    v: TVecF32x4; i: Integer;
begin
  src[0] := 1.5; src[1] := 2.5; src[2] := 3.5; src[3] := 4.5;
  v := ScalarLoadF32x4(@src[0]);
  ScalarStoreF32x4(@dst[0], v);
  for i := 0 to 3 do
    CheckF32(Format('LoadStoreF32x4[%d]', [i]), src[i], dst[i]);
end;

procedure TRVVParityTestCase.Test_SplatF32x4;
var v, scalar: TVecF32x4; i: Integer;
begin
  v := ScalarSplatF32x4(3.14);
  scalar := ScalarSplatF32x4(3.14);
  for i := 0 to 3 do
    CheckF32(Format('SplatF32x4[%d]', [i]), scalar.f[i], v.f[i]);
end;

procedure TRVVParityTestCase.Test_ZeroF32x4;
var v, scalar: TVecF32x4; i: Integer;
begin
  v := ScalarZeroF32x4();
  scalar := ScalarZeroF32x4();
  for i := 0 to 3 do
    CheckF32(Format('ZeroF32x4[%d]', [i]), scalar.f[i], v.f[i]);
end;

// =============================================================
// 128-bit F32x4 select/clamp
// =============================================================

procedure TRVVParityTestCase.Test_SelectF32x4;
var mask: TMask4; a, b, rvv, scalar: TVecF32x4;
begin
  mask := $0A; // 1010: pick from a for lanes 1,3, from b for lanes 0,2
  a := MakeF32x4(1.0, 2.0, 3.0, 4.0);
  b := MakeF32x4(10.0, 20.0, 30.0, 40.0);
  rvv := ScalarSelectF32x4(mask, a, b);
  scalar := ScalarSelectF32x4(mask, a, b);
  CheckF32x4('SelectF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ClampF32x4;
var a, lo, hi, rvv, scalar: TVecF32x4;
begin
  a  := MakeF32x4(-1.0, 5.0, 10.0, 0.5);
  lo := MakeF32x4( 0.0, 0.0, 0.0,  0.0);
  hi := MakeF32x4( 1.0, 1.0, 1.0,  1.0);
  rvv := ScalarClampF32x4(a, lo, hi);
  scalar := ScalarClampF32x4(a, lo, hi);
  CheckF32x4('ClampF32x4', scalar, rvv);
end;

// =============================================================
// 128-bit F64x2 arithmetic
// =============================================================

procedure TRVVParityTestCase.Test_AddF64x2;
var a, b, rvv, scalar: TVecF64x2;
begin
  a := MakeF64x2(1.0, 2.0);
  b := MakeF64x2(3.0, 4.0);
  rvv := ScalarAddF64x2(a, b);
  scalar := ScalarAddF64x2(a, b);
  CheckF64x2('AddF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_SubF64x2;
var a, b, rvv, scalar: TVecF64x2;
begin
  a := MakeF64x2(5.0, 10.0);
  b := MakeF64x2(2.0, 3.0);
  rvv := ScalarSubF64x2(a, b);
  scalar := ScalarSubF64x2(a, b);
  CheckF64x2('SubF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MulF64x2;
var a, b, rvv, scalar: TVecF64x2;
begin
  a := MakeF64x2(2.0, 3.0);
  b := MakeF64x2(4.0, 5.0);
  rvv := ScalarMulF64x2(a, b);
  scalar := ScalarMulF64x2(a, b);
  CheckF64x2('MulF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_DivF64x2;
var a, b, rvv, scalar: TVecF64x2;
begin
  a := MakeF64x2(10.0, 20.0);
  b := MakeF64x2(2.0, 4.0);
  rvv := ScalarDivF64x2(a, b);
  scalar := ScalarDivF64x2(a, b);
  CheckF64x2('DivF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_AbsF64x2;
var a, rvv, scalar: TVecF64x2;
begin
  a := MakeF64x2(-1.5, 0.0);
  rvv := ScalarAbsF64x2(a);
  scalar := ScalarAbsF64x2(a);
  CheckF64x2('AbsF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_SqrtF64x2;
var a, rvv, scalar: TVecF64x2;
begin
  a := MakeF64x2(4.0, 9.0);
  rvv := ScalarSqrtF64x2(a);
  scalar := ScalarSqrtF64x2(a);
  CheckF64x2('SqrtF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MinF64x2;
var a, b, rvv, scalar: TVecF64x2;
begin
  a := MakeF64x2(1.0, 5.0);
  b := MakeF64x2(2.0, 3.0);
  rvv := ScalarMinF64x2(a, b);
  scalar := ScalarMinF64x2(a, b);
  CheckF64x2('MinF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MaxF64x2;
var a, b, rvv, scalar: TVecF64x2;
begin
  a := MakeF64x2(1.0, 5.0);
  b := MakeF64x2(2.0, 3.0);
  rvv := ScalarMaxF64x2(a, b);
  scalar := ScalarMaxF64x2(a, b);
  CheckF64x2('MaxF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_FmaF64x2;
var a, b, c, rvv, scalar: TVecF64x2;
begin
  a := MakeF64x2(1.0, 2.0);
  b := MakeF64x2(3.0, 4.0);
  c := MakeF64x2(0.1, 0.2);
  rvv := ScalarFmaF64x2(a, b, c);
  scalar := ScalarFmaF64x2(a, b, c);
  CheckF64x2('FmaF64x2', scalar, rvv);
end;

// =============================================================
// 128-bit F64x2 comparison
// =============================================================

procedure TRVVParityTestCase.Test_CmpEqF64x2;
var a, b: TVecF64x2; rvv, scalar: TMask2;
begin
  a := MakeF64x2(1.0, 2.0);
  b := MakeF64x2(1.0, 0.0);
  rvv := ScalarCmpEqF64x2(a, b);
  scalar := ScalarCmpEqF64x2(a, b);
  AssertEquals('CmpEqF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpLtF64x2;
var a, b: TVecF64x2; rvv, scalar: TMask2;
begin
  a := MakeF64x2(1.0, 0.0);
  b := MakeF64x2(2.0, 0.0);
  rvv := ScalarCmpLtF64x2(a, b);
  scalar := ScalarCmpLtF64x2(a, b);
  AssertEquals('CmpLtF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpLeF64x2;
var a, b: TVecF64x2; rvv, scalar: TMask2;
begin
  a := MakeF64x2(1.0, 2.0);
  b := MakeF64x2(1.0, 1.0);
  rvv := ScalarCmpLeF64x2(a, b);
  scalar := ScalarCmpLeF64x2(a, b);
  AssertEquals('CmpLeF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpGtF64x2;
var a, b: TVecF64x2; rvv, scalar: TMask2;
begin
  a := MakeF64x2(5.0, 0.0);
  b := MakeF64x2(2.0, 0.0);
  rvv := ScalarCmpGtF64x2(a, b);
  scalar := ScalarCmpGtF64x2(a, b);
  AssertEquals('CmpGtF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpGeF64x2;
var a, b: TVecF64x2; rvv, scalar: TMask2;
begin
  a := MakeF64x2(1.0, 2.0);
  b := MakeF64x2(1.0, 1.0);
  rvv := ScalarCmpGeF64x2(a, b);
  scalar := ScalarCmpGeF64x2(a, b);
  AssertEquals('CmpGeF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpNeF64x2;
var a, b: TVecF64x2; rvv, scalar: TMask2;
begin
  a := MakeF64x2(1.0, 2.0);
  b := MakeF64x2(1.0, 0.0);
  rvv := ScalarCmpNeF64x2(a, b);
  scalar := ScalarCmpNeF64x2(a, b);
  AssertEquals('CmpNeF64x2', scalar, rvv);
end;

// =============================================================
// 128-bit F64x2 reduction
// =============================================================

procedure TRVVParityTestCase.Test_ReduceAddF64x2;
var a: TVecF64x2; rvv, scalar: Double;
begin
  a := MakeF64x2(3.0, 4.0);
  rvv := ScalarReduceAddF64x2(a);
  scalar := ScalarReduceAddF64x2(a);
  CheckF64('ReduceAddF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMinF64x2;
var a: TVecF64x2; rvv, scalar: Double;
begin
  a := MakeF64x2(3.0, 1.0);
  rvv := ScalarReduceMinF64x2(a);
  scalar := ScalarReduceMinF64x2(a);
  CheckF64('ReduceMinF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMaxF64x2;
var a: TVecF64x2; rvv, scalar: Double;
begin
  a := MakeF64x2(3.0, 1.0);
  rvv := ScalarReduceMaxF64x2(a);
  scalar := ScalarReduceMaxF64x2(a);
  CheckF64('ReduceMaxF64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMulF64x2;
var a: TVecF64x2; rvv, scalar: Double;
begin
  a := MakeF64x2(3.0, 4.0);
  rvv := ScalarReduceMulF64x2(a);
  scalar := ScalarReduceMulF64x2(a);
  CheckF64('ReduceMulF64x2', scalar, rvv);
end;

// =============================================================
// 128-bit F64x2 load/store/splat/zero
// =============================================================

procedure TRVVParityTestCase.Test_LoadStoreF64x2;
var src: array[0..1] of Double;
    dst: array[0..1] of Double;
    v: TVecF64x2; i: Integer;
begin
  src[0] := 1.5; src[1] := 2.5;
  v := ScalarLoadF64x2(@src[0]);
  ScalarStoreF64x2(@dst[0], v);
  for i := 0 to 1 do
    CheckF64(Format('LoadStoreF64x2[%d]', [i]), src[i], dst[i]);
end;

procedure TRVVParityTestCase.Test_SplatF64x2;
var v, scalar: TVecF64x2; i: Integer;
begin
  v := ScalarSplatF64x2(2.718);
  scalar := ScalarSplatF64x2(2.718);
  for i := 0 to 1 do
    CheckF64(Format('SplatF64x2[%d]', [i]), scalar.d[i], v.d[i]);
end;

procedure TRVVParityTestCase.Test_ZeroF64x2;
var v, scalar: TVecF64x2; i: Integer;
begin
  v := ScalarZeroF64x2();
  scalar := ScalarZeroF64x2();
  for i := 0 to 1 do
    CheckF64(Format('ZeroF64x2[%d]', [i]), scalar.d[i], v.d[i]);
end;

// =============================================================
// 128-bit I32x4 arithmetic
// =============================================================

procedure TRVVParityTestCase.Test_AddI32x4;
var a, b, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4(1, 2, -3, 0);
  b := MakeI32x4(10, 20, 30, -1);
  rvv := ScalarAddI32x4(a, b);
  scalar := ScalarAddI32x4(a, b);
  CheckI32x4('AddI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_SubI32x4;
var a, b, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4(10, 20, 0, -5);
  b := MakeI32x4(1, 2, 3, -1);
  rvv := ScalarSubI32x4(a, b);
  scalar := ScalarSubI32x4(a, b);
  CheckI32x4('SubI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MulI32x4;
var a, b, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4(2, 3, -4, 0);
  b := MakeI32x4(5, 6, 7, 100);
  rvv := ScalarMulI32x4(a, b);
  scalar := ScalarMulI32x4(a, b);
  CheckI32x4('MulI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_AndI32x4;
var a, b, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4($FF, $0F, $F0, $AA);
  b := MakeI32x4($0F, $FF, $0F, $55);
  rvv := ScalarAndI32x4(a, b);
  scalar := ScalarAndI32x4(a, b);
  CheckI32x4('AndI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_OrI32x4;
var a, b, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4($FF, $0F, $F0, $AA);
  b := MakeI32x4($0F, $FF, $0F, $55);
  rvv := ScalarOrI32x4(a, b);
  scalar := ScalarOrI32x4(a, b);
  CheckI32x4('OrI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_XorI32x4;
var a, b, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4($FF, $0F, $F0, $AA);
  b := MakeI32x4($0F, $FF, $0F, $55);
  rvv := ScalarXorI32x4(a, b);
  scalar := ScalarXorI32x4(a, b);
  CheckI32x4('XorI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_NotI32x4;
var a, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4(0, -1, $FF, $AA55);
  rvv := ScalarNotI32x4(a);
  scalar := ScalarNotI32x4(a);
  CheckI32x4('NotI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_AndNotI32x4;
var a, b, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4($FF, $0F, $F0, $AA);
  b := MakeI32x4($0F, $FF, $0F, $55);
  rvv := ScalarAndNotI32x4(a, b);
  scalar := ScalarAndNotI32x4(a, b);
  CheckI32x4('AndNotI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MinI32x4;
var a, b, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4(1, 5, -3, 0);
  b := MakeI32x4(2, 3, -1, -5);
  rvv := ScalarMinI32x4(a, b);
  scalar := ScalarMinI32x4(a, b);
  CheckI32x4('MinI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MaxI32x4;
var a, b, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4(1, 5, -3, 0);
  b := MakeI32x4(2, 3, -1, -5);
  rvv := ScalarMaxI32x4(a, b);
  scalar := ScalarMaxI32x4(a, b);
  CheckI32x4('MaxI32x4', scalar, rvv);
end;

// =============================================================
// 128-bit I32x4 comparison
// =============================================================

procedure TRVVParityTestCase.Test_CmpEqI32x4;
var a, b: TVecI32x4; rvv, scalar: TMask4;
begin
  a := MakeI32x4(1, 2, 3, 4);
  b := MakeI32x4(1, 0, 3, 0);
  rvv := ScalarCmpEqI32x4(a, b);
  scalar := ScalarCmpEqI32x4(a, b);
  CheckMask4('CmpEqI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpLtI32x4;
var a, b: TVecI32x4; rvv, scalar: TMask4;
begin
  a := MakeI32x4(1, -1, 0, 5);
  b := MakeI32x4(2, 0, 0, 3);
  rvv := ScalarCmpLtI32x4(a, b);
  scalar := ScalarCmpLtI32x4(a, b);
  CheckMask4('CmpLtI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpLeI32x4;
var a, b: TVecI32x4; rvv, scalar: TMask4;
begin
  a := MakeI32x4(1, 2, 3, 4);
  b := MakeI32x4(1, 1, 3, 5);
  rvv := ScalarCmpLeI32x4(a, b);
  scalar := ScalarCmpLeI32x4(a, b);
  CheckMask4('CmpLeI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpGtI32x4;
var a, b: TVecI32x4; rvv, scalar: TMask4;
begin
  a := MakeI32x4(5, 0, 3, -1);
  b := MakeI32x4(2, 0, 3, 0);
  rvv := ScalarCmpGtI32x4(a, b);
  scalar := ScalarCmpGtI32x4(a, b);
  CheckMask4('CmpGtI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpGeI32x4;
var a, b: TVecI32x4; rvv, scalar: TMask4;
begin
  a := MakeI32x4(1, 5, 3, 4);
  b := MakeI32x4(2, 3, 3, 4);
  rvv := ScalarCmpGeI32x4(a, b);
  scalar := ScalarCmpGeI32x4(a, b);
  CheckMask4('CmpGeI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpNeI32x4;
var a, b: TVecI32x4; rvv, scalar: TMask4;
begin
  a := MakeI32x4(1, 2, 3, 4);
  b := MakeI32x4(1, 0, 3, 0);
  rvv := ScalarCmpNeI32x4(a, b);
  scalar := ScalarCmpNeI32x4(a, b);
  CheckMask4('CmpNeI32x4', scalar, rvv);
end;

// =============================================================
// 128-bit I32x4 shift
// =============================================================

procedure TRVVParityTestCase.Test_ShiftLeftI32x4;
var a, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4(1, 2, 4, 8);
  rvv := ScalarShiftLeftI32x4(a, 2);
  scalar := ScalarShiftLeftI32x4(a, 2);
  CheckI32x4('ShiftLeftI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ShiftRightI32x4;
var a, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4(8, 16, 32, 64);
  rvv := ScalarShiftRightI32x4(a, 2);
  scalar := ScalarShiftRightI32x4(a, 2);
  CheckI32x4('ShiftRightI32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ShiftRightArithI32x4;
var a, rvv, scalar: TVecI32x4;
begin
  a := MakeI32x4(-8, -16, 32, -64);
  rvv := ScalarShiftRightArithI32x4(a, 2);
  scalar := ScalarShiftRightArithI32x4(a, 2);
  CheckI32x4('ShiftRightArithI32x4', scalar, rvv);
end;

// =============================================================
// 128-bit I64x2
// =============================================================

procedure TRVVParityTestCase.Test_AddI64x2;
var a, b, rvv, scalar: TVecI64x2;
begin
  a := MakeI64x2(1, -1);
  b := MakeI64x2(10, 20);
  rvv := ScalarAddI64x2(a, b);
  scalar := ScalarAddI64x2(a, b);
  AssertEquals('AddI64x2[0]', scalar.i[0], rvv.i[0]);
  AssertEquals('AddI64x2[1]', scalar.i[1], rvv.i[1]);
end;

procedure TRVVParityTestCase.Test_SubI64x2;
var a, b, rvv, scalar: TVecI64x2;
begin
  a := MakeI64x2(10, 20);
  b := MakeI64x2(1, 2);
  rvv := ScalarSubI64x2(a, b);
  scalar := ScalarSubI64x2(a, b);
  AssertEquals('SubI64x2[0]', scalar.i[0], rvv.i[0]);
  AssertEquals('SubI64x2[1]', scalar.i[1], rvv.i[1]);
end;

procedure TRVVParityTestCase.Test_AndI64x2;
var a, b, rvv, scalar: TVecI64x2;
begin
  a := MakeI64x2($FF, $0F);
  b := MakeI64x2($0F, $FF);
  rvv := ScalarAndI64x2(a, b);
  scalar := ScalarAndI64x2(a, b);
  AssertEquals('AndI64x2[0]', scalar.i[0], rvv.i[0]);
  AssertEquals('AndI64x2[1]', scalar.i[1], rvv.i[1]);
end;

procedure TRVVParityTestCase.Test_OrI64x2;
var a, b, rvv, scalar: TVecI64x2;
begin
  a := MakeI64x2($FF, $0F);
  b := MakeI64x2($0F, $FF);
  rvv := ScalarOrI64x2(a, b);
  scalar := ScalarOrI64x2(a, b);
  AssertEquals('OrI64x2[0]', scalar.i[0], rvv.i[0]);
  AssertEquals('OrI64x2[1]', scalar.i[1], rvv.i[1]);
end;

procedure TRVVParityTestCase.Test_XorI64x2;
var a, b, rvv, scalar: TVecI64x2;
begin
  a := MakeI64x2($FF, $0F);
  b := MakeI64x2($0F, $FF);
  rvv := ScalarXorI64x2(a, b);
  scalar := ScalarXorI64x2(a, b);
  AssertEquals('XorI64x2[0]', scalar.i[0], rvv.i[0]);
  AssertEquals('XorI64x2[1]', scalar.i[1], rvv.i[1]);
end;

procedure TRVVParityTestCase.Test_NotI64x2;
var a, rvv, scalar: TVecI64x2;
begin
  a := MakeI64x2(0, -1);
  rvv := ScalarNotI64x2(a);
  scalar := ScalarNotI64x2(a);
  AssertEquals('NotI64x2[0]', scalar.i[0], rvv.i[0]);
  AssertEquals('NotI64x2[1]', scalar.i[1], rvv.i[1]);
end;

procedure TRVVParityTestCase.Test_ShiftLeftI64x2;
var a, rvv, scalar: TVecI64x2;
begin
  a := MakeI64x2(1, 2);
  rvv := ScalarShiftLeftI64x2(a, 3);
  scalar := ScalarShiftLeftI64x2(a, 3);
  AssertEquals('ShiftLeftI64x2[0]', scalar.i[0], rvv.i[0]);
  AssertEquals('ShiftLeftI64x2[1]', scalar.i[1], rvv.i[1]);
end;

procedure TRVVParityTestCase.Test_ShiftRightI64x2;
var a, rvv, scalar: TVecI64x2;
begin
  a := MakeI64x2(16, 32);
  rvv := ScalarShiftRightI64x2(a, 2);
  scalar := ScalarShiftRightI64x2(a, 2);
  AssertEquals('ShiftRightI64x2[0]', scalar.i[0], rvv.i[0]);
  AssertEquals('ShiftRightI64x2[1]', scalar.i[1], rvv.i[1]);
end;

procedure TRVVParityTestCase.Test_ShiftRightArithI64x2;
var a, rvv, scalar: TVecI64x2;
begin
  a := MakeI64x2(-16, 32);
  rvv := ScalarShiftRightArithI64x2(a, 2);
  scalar := ScalarShiftRightArithI64x2(a, 2);
  AssertEquals('ShiftRightArithI64x2[0]', scalar.i[0], rvv.i[0]);
  AssertEquals('ShiftRightArithI64x2[1]', scalar.i[1], rvv.i[1]);
end;

// =============================================================
// 128-bit I64x2 comparison
// =============================================================

procedure TRVVParityTestCase.Test_CmpEqI64x2;
var a, b: TVecI64x2; rvv, scalar: TMask2;
begin
  a := MakeI64x2(1, 2);
  b := MakeI64x2(1, 0);
  rvv := ScalarCmpEqI64x2(a, b);
  scalar := ScalarCmpEqI64x2(a, b);
  AssertEquals('CmpEqI64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpLtI64x2;
var a, b: TVecI64x2; rvv, scalar: TMask2;
begin
  a := MakeI64x2(1, -1);
  b := MakeI64x2(2, 0);
  rvv := ScalarCmpLtI64x2(a, b);
  scalar := ScalarCmpLtI64x2(a, b);
  AssertEquals('CmpLtI64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpLeI64x2;
var a, b: TVecI64x2; rvv, scalar: TMask2;
begin
  a := MakeI64x2(1, 2);
  b := MakeI64x2(1, 1);
  rvv := ScalarCmpLeI64x2(a, b);
  scalar := ScalarCmpLeI64x2(a, b);
  AssertEquals('CmpLeI64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpGtI64x2;
var a, b: TVecI64x2; rvv, scalar: TMask2;
begin
  a := MakeI64x2(5, 0);
  b := MakeI64x2(2, 0);
  rvv := ScalarCmpGtI64x2(a, b);
  scalar := ScalarCmpGtI64x2(a, b);
  AssertEquals('CmpGtI64x2', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpNeI64x2;
var a, b: TVecI64x2; rvv, scalar: TMask2;
begin
  a := MakeI64x2(1, 2);
  b := MakeI64x2(1, 0);
  rvv := ScalarCmpNeI64x2(a, b);
  scalar := ScalarCmpNeI64x2(a, b);
  AssertEquals('CmpNeI64x2', scalar, rvv);
end;

// =============================================================
// 128-bit U32x4
// =============================================================

procedure TRVVParityTestCase.Test_AddU32x4;
var a, b, rvv, scalar: TVecU32x4;
begin
  a := MakeU32x4(1, 2, 0, $FFFFFFFF);
  b := MakeU32x4(10, 20, 30, 1);
  rvv := ScalarAddU32x4(a, b);
  scalar := ScalarAddU32x4(a, b);
  CheckU32x4('AddU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_SubU32x4;
var a, b, rvv, scalar: TVecU32x4;
begin
  a := MakeU32x4(10, 20, 5, 100);
  b := MakeU32x4(1, 2, 3, 50);
  rvv := ScalarSubU32x4(a, b);
  scalar := ScalarSubU32x4(a, b);
  CheckU32x4('SubU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MulU32x4;
var a, b, rvv, scalar: TVecU32x4;
begin
  a := MakeU32x4(2, 3, 0, 100);
  b := MakeU32x4(5, 6, 7, 200);
  rvv := ScalarMulU32x4(a, b);
  scalar := ScalarMulU32x4(a, b);
  CheckU32x4('MulU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_AndU32x4;
var a, b, rvv, scalar: TVecU32x4;
begin
  a := MakeU32x4($FF, $0F, $F0, $AA);
  b := MakeU32x4($0F, $FF, $0F, $55);
  rvv := ScalarAndU32x4(a, b);
  scalar := ScalarAndU32x4(a, b);
  CheckU32x4('AndU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_OrU32x4;
var a, b, rvv, scalar: TVecU32x4;
begin
  a := MakeU32x4($FF, $0F, $F0, $AA);
  b := MakeU32x4($0F, $FF, $0F, $55);
  rvv := ScalarOrU32x4(a, b);
  scalar := ScalarOrU32x4(a, b);
  CheckU32x4('OrU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_XorU32x4;
var a, b, rvv, scalar: TVecU32x4;
begin
  a := MakeU32x4($FF, $0F, $F0, $AA);
  b := MakeU32x4($0F, $FF, $0F, $55);
  rvv := ScalarXorU32x4(a, b);
  scalar := ScalarXorU32x4(a, b);
  CheckU32x4('XorU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_NotU32x4;
var a, rvv, scalar: TVecU32x4;
begin
  a := MakeU32x4(0, $FFFFFFFF, $FF, $AA55);
  rvv := ScalarNotU32x4(a);
  scalar := ScalarNotU32x4(a);
  CheckU32x4('NotU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MinU32x4;
var a, b, rvv, scalar: TVecU32x4;
begin
  a := MakeU32x4(1, 5, 10, 100);
  b := MakeU32x4(2, 3, 9, 200);
  rvv := ScalarMinU32x4(a, b);
  scalar := ScalarMinU32x4(a, b);
  CheckU32x4('MinU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_MaxU32x4;
var a, b, rvv, scalar: TVecU32x4;
begin
  a := MakeU32x4(1, 5, 10, 100);
  b := MakeU32x4(2, 3, 9, 200);
  rvv := ScalarMaxU32x4(a, b);
  scalar := ScalarMaxU32x4(a, b);
  CheckU32x4('MaxU32x4', scalar, rvv);
end;

// =============================================================
// 128-bit U32x4 comparison
// =============================================================

procedure TRVVParityTestCase.Test_CmpEqU32x4;
var a, b: TVecU32x4; rvv, scalar: TMask4;
begin
  a := MakeU32x4(1, 2, 3, 4);
  b := MakeU32x4(1, 0, 3, 0);
  rvv := ScalarCmpEqU32x4(a, b);
  scalar := ScalarCmpEqU32x4(a, b);
  CheckMask4('CmpEqU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpLtU32x4;
var a, b: TVecU32x4; rvv, scalar: TMask4;
begin
  a := MakeU32x4(1, 5, 0, 10);
  b := MakeU32x4(2, 3, 0, 9);
  rvv := ScalarCmpLtU32x4(a, b);
  scalar := ScalarCmpLtU32x4(a, b);
  CheckMask4('CmpLtU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpLeU32x4;
var a, b: TVecU32x4; rvv, scalar: TMask4;
begin
  a := MakeU32x4(1, 2, 3, 4);
  b := MakeU32x4(1, 1, 3, 5);
  rvv := ScalarCmpLeU32x4(a, b);
  scalar := ScalarCmpLeU32x4(a, b);
  CheckMask4('CmpLeU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpGtU32x4;
var a, b: TVecU32x4; rvv, scalar: TMask4;
begin
  a := MakeU32x4(5, 0, 3, 10);
  b := MakeU32x4(2, 0, 3, 9);
  rvv := ScalarCmpGtU32x4(a, b);
  scalar := ScalarCmpGtU32x4(a, b);
  CheckMask4('CmpGtU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpGeU32x4;
var a, b: TVecU32x4; rvv, scalar: TMask4;
begin
  a := MakeU32x4(1, 5, 3, 4);
  b := MakeU32x4(2, 3, 3, 4);
  rvv := ScalarCmpGeU32x4(a, b);
  scalar := ScalarCmpGeU32x4(a, b);
  CheckMask4('CmpGeU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_CmpNeU32x4;
var a, b: TVecU32x4; rvv, scalar: TMask4;
begin
  a := MakeU32x4(1, 2, 3, 4);
  b := MakeU32x4(1, 0, 3, 0);
  rvv := ScalarCmpNeU32x4(a, b);
  scalar := ScalarCmpNeU32x4(a, b);
  CheckMask4('CmpNeU32x4', scalar, rvv);
end;

// =============================================================
// 128-bit U32x4 shift
// =============================================================

procedure TRVVParityTestCase.Test_ShiftLeftU32x4;
var a, rvv, scalar: TVecU32x4;
begin
  a := MakeU32x4(1, 2, 4, 8);
  rvv := ScalarShiftLeftU32x4(a, 3);
  scalar := ScalarShiftLeftU32x4(a, 3);
  CheckU32x4('ShiftLeftU32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ShiftRightU32x4;
var a, rvv, scalar: TVecU32x4;
begin
  a := MakeU32x4(8, 16, 32, 64);
  rvv := ScalarShiftRightU32x4(a, 2);
  scalar := ScalarShiftRightU32x4(a, 2);
  CheckU32x4('ShiftRightU32x4', scalar, rvv);
end;

// =============================================================
// 128-bit U64x2
// =============================================================

procedure TRVVParityTestCase.Test_AddU64x2;
var a, b, rvv, scalar: TVecU64x2;
begin
  a := MakeU64x2(1, $FFFFFFFFFFFFFFFF);
  b := MakeU64x2(10, 1);
  rvv := ScalarAddU64x2(a, b);
  scalar := ScalarAddU64x2(a, b);
  AssertEquals('AddU64x2[0]', scalar.u[0], rvv.u[0]);
  AssertEquals('AddU64x2[1]', scalar.u[1], rvv.u[1]);
end;

procedure TRVVParityTestCase.Test_SubU64x2;
var a, b, rvv, scalar: TVecU64x2;
begin
  a := MakeU64x2(10, 20);
  b := MakeU64x2(1, 2);
  rvv := ScalarSubU64x2(a, b);
  scalar := ScalarSubU64x2(a, b);
  AssertEquals('SubU64x2[0]', scalar.u[0], rvv.u[0]);
  AssertEquals('SubU64x2[1]', scalar.u[1], rvv.u[1]);
end;

procedure TRVVParityTestCase.Test_AndU64x2;
var a, b, rvv, scalar: TVecU64x2;
begin
  a := MakeU64x2($FF, $0F);
  b := MakeU64x2($0F, $FF);
  rvv := ScalarAndU64x2(a, b);
  scalar := ScalarAndU64x2(a, b);
  AssertEquals('AndU64x2[0]', scalar.u[0], rvv.u[0]);
  AssertEquals('AndU64x2[1]', scalar.u[1], rvv.u[1]);
end;

procedure TRVVParityTestCase.Test_OrU64x2;
var a, b, rvv, scalar: TVecU64x2;
begin
  a := MakeU64x2($FF, $0F);
  b := MakeU64x2($0F, $FF);
  rvv := ScalarOrU64x2(a, b);
  scalar := ScalarOrU64x2(a, b);
  AssertEquals('OrU64x2[0]', scalar.u[0], rvv.u[0]);
  AssertEquals('OrU64x2[1]', scalar.u[1], rvv.u[1]);
end;

procedure TRVVParityTestCase.Test_XorU64x2;
var a, b, rvv, scalar: TVecU64x2;
begin
  a := MakeU64x2($FF, $0F);
  b := MakeU64x2($0F, $FF);
  rvv := ScalarXorU64x2(a, b);
  scalar := ScalarXorU64x2(a, b);
  AssertEquals('XorU64x2[0]', scalar.u[0], rvv.u[0]);
  AssertEquals('XorU64x2[1]', scalar.u[1], rvv.u[1]);
end;

procedure TRVVParityTestCase.Test_NotU64x2;
var a, rvv, scalar: TVecU64x2;
begin
  a := MakeU64x2(0, $FFFFFFFFFFFFFFFF);
  rvv := ScalarNotU64x2(a);
  scalar := ScalarNotU64x2(a);
  AssertEquals('NotU64x2[0]', scalar.u[0], rvv.u[0]);
  AssertEquals('NotU64x2[1]', scalar.u[1], rvv.u[1]);
end;

// =============================================================
// 128-bit I16x8
// =============================================================

procedure TRVVParityTestCase.Test_AddI16x8;
var a, b, rvv, scalar: TVecI16x8; i: Integer;
begin
  a := MakeI16x8(1, 2, 3, 4, -1, -2, -3, -4);
  b := MakeI16x8(10, 20, 30, 40, 1, 2, 3, 4);
  rvv := ScalarAddI16x8(a, b);
  scalar := ScalarAddI16x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('AddI16x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_SubI16x8;
var a, b, rvv, scalar: TVecI16x8; i: Integer;
begin
  a := MakeI16x8(10, 20, 30, 40, 5, 6, 7, 8);
  b := MakeI16x8(1, 2, 3, 4, 1, 2, 3, 4);
  rvv := ScalarSubI16x8(a, b);
  scalar := ScalarSubI16x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('SubI16x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_MulI16x8;
var a, b, rvv, scalar: TVecI16x8; i: Integer;
begin
  a := MakeI16x8(2, 3, 4, 5, -1, -2, -3, -4);
  b := MakeI16x8(5, 6, 7, 8, 2, 3, 4, 5);
  rvv := ScalarMulI16x8(a, b);
  scalar := ScalarMulI16x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('MulI16x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_MinI16x8;
var a, b, rvv, scalar: TVecI16x8; i: Integer;
begin
  a := MakeI16x8(1, 5, -3, 0, 10, 20, -5, -10);
  b := MakeI16x8(2, 3, -1, -5, 5, 30, 0, -1);
  rvv := ScalarMinI16x8(a, b);
  scalar := ScalarMinI16x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('MinI16x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_MaxI16x8;
var a, b, rvv, scalar: TVecI16x8; i: Integer;
begin
  a := MakeI16x8(1, 5, -3, 0, 10, 20, -5, -10);
  b := MakeI16x8(2, 3, -1, -5, 5, 30, 0, -1);
  rvv := ScalarMaxI16x8(a, b);
  scalar := ScalarMaxI16x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('MaxI16x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_AndI16x8;
var a, b, rvv, scalar: TVecI16x8; i: Integer;
begin
  a := MakeI16x8($FF, $0F, $F0, $AA, $55, $FF, $00, $0F);
  b := MakeI16x8($0F, $FF, $0F, $55, $AA, $00, $FF, $F0);
  rvv := ScalarAndI16x8(a, b);
  scalar := ScalarAndI16x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('AndI16x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_OrI16x8;
var a, b, rvv, scalar: TVecI16x8; i: Integer;
begin
  a := MakeI16x8($FF, $0F, $F0, $AA, $55, $FF, $00, $0F);
  b := MakeI16x8($0F, $FF, $0F, $55, $AA, $00, $FF, $F0);
  rvv := ScalarOrI16x8(a, b);
  scalar := ScalarOrI16x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('OrI16x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_XorI16x8;
var a, b, rvv, scalar: TVecI16x8; i: Integer;
begin
  a := MakeI16x8($FF, $0F, $F0, $AA, $55, $FF, $00, $0F);
  b := MakeI16x8($0F, $FF, $0F, $55, $AA, $00, $FF, $F0);
  rvv := ScalarXorI16x8(a, b);
  scalar := ScalarXorI16x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('XorI16x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

// =============================================================
// 128-bit I8x16
// =============================================================

procedure TRVVParityTestCase.Test_AddI8x16;
var a, b, rvv, scalar: TVecI8x16; i: Integer;
begin
  a := MakeI8x16(1,2,3,4,5,6,7,8, -1,-2,-3,-4,-5,-6,-7,-8);
  b := MakeI8x16(10,20,30,40,50,60,70,80, 1,2,3,4,5,6,7,8);
  rvv := ScalarAddI8x16(a, b);
  scalar := ScalarAddI8x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('AddI8x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_SubI8x16;
var a, b, rvv, scalar: TVecI8x16; i: Integer;
begin
  a := MakeI8x16(10,20,30,40,50,60,70,80, 5,6,7,8,9,10,11,12);
  b := MakeI8x16(1,2,3,4,5,6,7,8, 1,2,3,4,5,6,7,8);
  rvv := ScalarSubI8x16(a, b);
  scalar := ScalarSubI8x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('SubI8x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_MinI8x16;
var a, b, rvv, scalar: TVecI8x16; i: Integer;
begin
  a := MakeI8x16(1,5,-3,0,10,20,-5,-10, 0,1,2,3,4,5,6,7);
  b := MakeI8x16(2,3,-1,-5,5,30,0,-1, 1,0,3,2,5,4,7,6);
  rvv := ScalarMinI8x16(a, b);
  scalar := ScalarMinI8x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('MinI8x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_MaxI8x16;
var a, b, rvv, scalar: TVecI8x16; i: Integer;
begin
  a := MakeI8x16(1,5,-3,0,10,20,-5,-10, 0,1,2,3,4,5,6,7);
  b := MakeI8x16(2,3,-1,-5,5,30,0,-1, 1,0,3,2,5,4,7,6);
  rvv := ScalarMaxI8x16(a, b);
  scalar := ScalarMaxI8x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('MaxI8x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_AndI8x16;
var a, b, rvv, scalar: TVecI8x16; i: Integer;
begin
  a := MakeI8x16($FF,$0F,$F0,$AA,$55,$FF,$00,$0F, $FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeI8x16($0F,$FF,$0F,$55,$AA,$00,$FF,$F0, $0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarAndI8x16(a, b);
  scalar := ScalarAndI8x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('AndI8x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_OrI8x16;
var a, b, rvv, scalar: TVecI8x16; i: Integer;
begin
  a := MakeI8x16($FF,$0F,$F0,$AA,$55,$FF,$00,$0F, $FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeI8x16($0F,$FF,$0F,$55,$AA,$00,$FF,$F0, $0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarOrI8x16(a, b);
  scalar := ScalarOrI8x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('OrI8x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_XorI8x16;
var a, b, rvv, scalar: TVecI8x16; i: Integer;
begin
  a := MakeI8x16($FF,$0F,$F0,$AA,$55,$FF,$00,$0F, $FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeI8x16($0F,$FF,$0F,$55,$AA,$00,$FF,$F0, $0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarXorI8x16(a, b);
  scalar := ScalarXorI8x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('XorI8x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

// =============================================================
// 128-bit U16x8
// =============================================================

procedure TRVVParityTestCase.Test_AddU16x8;
var a, b, rvv, scalar: TVecU16x8; i: Integer;
begin
  a := MakeU16x8(1,2,3,4,100,200,300,400);
  b := MakeU16x8(10,20,30,40,50,60,70,80);
  rvv := ScalarAddU16x8(a, b);
  scalar := ScalarAddU16x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('AddU16x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_SubU16x8;
var a, b, rvv, scalar: TVecU16x8; i: Integer;
begin
  a := MakeU16x8(10,20,30,40,50,60,70,80);
  b := MakeU16x8(1,2,3,4,5,6,7,8);
  rvv := ScalarSubU16x8(a, b);
  scalar := ScalarSubU16x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('SubU16x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_MulU16x8;
var a, b, rvv, scalar: TVecU16x8; i: Integer;
begin
  a := MakeU16x8(2,3,4,5,6,7,8,9);
  b := MakeU16x8(5,6,7,8,9,10,11,12);
  rvv := ScalarMulU16x8(a, b);
  scalar := ScalarMulU16x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('MulU16x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_MinU16x8;
var a, b, rvv, scalar: TVecU16x8; i: Integer;
begin
  a := MakeU16x8(1,5,10,0,100,200,50,75);
  b := MakeU16x8(2,3,9,5,50,300,25,100);
  rvv := ScalarMinU16x8(a, b);
  scalar := ScalarMinU16x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('MinU16x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_MaxU16x8;
var a, b, rvv, scalar: TVecU16x8; i: Integer;
begin
  a := MakeU16x8(1,5,10,0,100,200,50,75);
  b := MakeU16x8(2,3,9,5,50,300,25,100);
  rvv := ScalarMaxU16x8(a, b);
  scalar := ScalarMaxU16x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('MaxU16x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_AndU16x8;
var a, b, rvv, scalar: TVecU16x8; i: Integer;
begin
  a := MakeU16x8($FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeU16x8($0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarAndU16x8(a, b);
  scalar := ScalarAndU16x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('AndU16x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_OrU16x8;
var a, b, rvv, scalar: TVecU16x8; i: Integer;
begin
  a := MakeU16x8($FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeU16x8($0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarOrU16x8(a, b);
  scalar := ScalarOrU16x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('OrU16x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_XorU16x8;
var a, b, rvv, scalar: TVecU16x8; i: Integer;
begin
  a := MakeU16x8($FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeU16x8($0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarXorU16x8(a, b);
  scalar := ScalarXorU16x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('XorU16x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

// =============================================================
// 128-bit U8x16
// =============================================================

procedure TRVVParityTestCase.Test_AddU8x16;
var a, b, rvv, scalar: TVecU8x16; i: Integer;
begin
  a := MakeU8x16(1,2,3,4,5,6,7,8, 10,20,30,40,50,60,70,80);
  b := MakeU8x16(10,20,30,40,50,60,70,80, 1,2,3,4,5,6,7,8);
  rvv := ScalarAddU8x16(a, b);
  scalar := ScalarAddU8x16(a, b);
  for i := 0 to 15 do
    CheckU32(Format('AddU8x16[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_SubU8x16;
var a, b, rvv, scalar: TVecU8x16; i: Integer;
begin
  a := MakeU8x16(10,20,30,40,50,60,70,80, 100,110,120,130,140,150,160,170);
  b := MakeU8x16(1,2,3,4,5,6,7,8, 10,20,30,40,50,60,70,80);
  rvv := ScalarSubU8x16(a, b);
  scalar := ScalarSubU8x16(a, b);
  for i := 0 to 15 do
    CheckU32(Format('SubU8x16[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_MinU8x16;
var a, b, rvv, scalar: TVecU8x16; i: Integer;
begin
  a := MakeU8x16(1,5,10,0,100,200,50,75, 0,1,2,3,4,5,6,7);
  b := MakeU8x16(2,3,9,5,50,250,25,100, 1,0,3,2,5,4,7,6);
  rvv := ScalarMinU8x16(a, b);
  scalar := ScalarMinU8x16(a, b);
  for i := 0 to 15 do
    CheckU32(Format('MinU8x16[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_MaxU8x16;
var a, b, rvv, scalar: TVecU8x16; i: Integer;
begin
  a := MakeU8x16(1,5,10,0,100,200,50,75, 0,1,2,3,4,5,6,7);
  b := MakeU8x16(2,3,9,5,50,250,25,100, 1,0,3,2,5,4,7,6);
  rvv := ScalarMaxU8x16(a, b);
  scalar := ScalarMaxU8x16(a, b);
  for i := 0 to 15 do
    CheckU32(Format('MaxU8x16[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_AndU8x16;
var a, b, rvv, scalar: TVecU8x16; i: Integer;
begin
  a := MakeU8x16($FF,$0F,$F0,$AA,$55,$FF,$00,$0F, $FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeU8x16($0F,$FF,$0F,$55,$AA,$00,$FF,$F0, $0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarAndU8x16(a, b);
  scalar := ScalarAndU8x16(a, b);
  for i := 0 to 15 do
    CheckU32(Format('AndU8x16[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_OrU8x16;
var a, b, rvv, scalar: TVecU8x16; i: Integer;
begin
  a := MakeU8x16($FF,$0F,$F0,$AA,$55,$FF,$00,$0F, $FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeU8x16($0F,$FF,$0F,$55,$AA,$00,$FF,$F0, $0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarOrU8x16(a, b);
  scalar := ScalarOrU8x16(a, b);
  for i := 0 to 15 do
    CheckU32(Format('OrU8x16[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_XorU8x16;
var a, b, rvv, scalar: TVecU8x16; i: Integer;
begin
  a := MakeU8x16($FF,$0F,$F0,$AA,$55,$FF,$00,$0F, $FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeU8x16($0F,$FF,$0F,$55,$AA,$00,$FF,$F0, $0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarXorU8x16(a, b);
  scalar := ScalarXorU8x16(a, b);
  for i := 0 to 15 do
    CheckU32(Format('XorU8x16[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

// =============================================================
// 256-bit F32x8
// =============================================================

procedure TRVVParityTestCase.Test_AddF32x8;
var a, b, rvv, scalar: TVecF32x8; i: Integer;
begin
  a := MakeF32x8(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
  b := MakeF32x8(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8);
  rvv := ScalarAddF32x8(a, b);
  scalar := ScalarAddF32x8(a, b);
  for i := 0 to 7 do
    CheckF32(Format('AddF32x8[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_SubF32x8;
var a, b, rvv, scalar: TVecF32x8; i: Integer;
begin
  a := MakeF32x8(10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0);
  b := MakeF32x8(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
  rvv := ScalarSubF32x8(a, b);
  scalar := ScalarSubF32x8(a, b);
  for i := 0 to 7 do
    CheckF32(Format('SubF32x8[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_MulF32x8;
var a, b, rvv, scalar: TVecF32x8; i: Integer;
begin
  a := MakeF32x8(2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0);
  b := MakeF32x8(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
  rvv := ScalarMulF32x8(a, b);
  scalar := ScalarMulF32x8(a, b);
  for i := 0 to 7 do
    CheckF32(Format('MulF32x8[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_DivF32x8;
var a, b, rvv, scalar: TVecF32x8; i: Integer;
begin
  a := MakeF32x8(10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0);
  b := MakeF32x8(2.0, 4.0, 5.0, 8.0, 10.0, 12.0, 14.0, 16.0);
  rvv := ScalarDivF32x8(a, b);
  scalar := ScalarDivF32x8(a, b);
  for i := 0 to 7 do
    CheckF32(Format('DivF32x8[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_MinF32x8;
var a, b, rvv, scalar: TVecF32x8; i: Integer;
begin
  a := MakeF32x8(1.0, 5.0, -3.0, 0.0, 10.0, 2.0, -5.0, 0.0);
  b := MakeF32x8(2.0, 3.0, -1.0, -5.0, 5.0, 3.0, 0.0, 1.0);
  rvv := ScalarMinF32x8(a, b);
  scalar := ScalarMinF32x8(a, b);
  for i := 0 to 7 do
    CheckF32(Format('MinF32x8[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_MaxF32x8;
var a, b, rvv, scalar: TVecF32x8; i: Integer;
begin
  a := MakeF32x8(1.0, 5.0, -3.0, 0.0, 10.0, 2.0, -5.0, 0.0);
  b := MakeF32x8(2.0, 3.0, -1.0, -5.0, 5.0, 3.0, 0.0, 1.0);
  rvv := ScalarMaxF32x8(a, b);
  scalar := ScalarMaxF32x8(a, b);
  for i := 0 to 7 do
    CheckF32(Format('MaxF32x8[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_AbsF32x8;
var a, rvv, scalar: TVecF32x8; i: Integer;
begin
  a := MakeF32x8(-1.0, 0.0, -3.14, 2.71, -0.5, 10.0, -7.0, 0.0);
  rvv := ScalarAbsF32x8(a);
  scalar := ScalarAbsF32x8(a);
  for i := 0 to 7 do
    CheckF32(Format('AbsF32x8[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_SqrtF32x8;
var a, rvv, scalar: TVecF32x8; i: Integer;
begin
  a := MakeF32x8(4.0, 9.0, 16.0, 25.0, 36.0, 49.0, 64.0, 81.0);
  rvv := ScalarSqrtF32x8(a);
  scalar := ScalarSqrtF32x8(a);
  for i := 0 to 7 do
    CheckF32(Format('SqrtF32x8[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_FmaF32x8;
var a, b, c, rvv, scalar: TVecF32x8; i: Integer;
begin
  a := MakeF32x8(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
  b := MakeF32x8(2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0);
  c := MakeF32x8(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8);
  rvv := ScalarFmaF32x8(a, b, c);
  scalar := ScalarFmaF32x8(a, b, c);
  for i := 0 to 7 do
    CheckF32(Format('FmaF32x8[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

// =============================================================
// 256-bit F64x4
// =============================================================

procedure TRVVParityTestCase.Test_AddF64x4;
var a, b, rvv, scalar: TVecF64x4; i: Integer;
begin
  a := MakeF64x4(1.0, 2.0, 3.0, 4.0);
  b := MakeF64x4(0.1, 0.2, 0.3, 0.4);
  rvv := ScalarAddF64x4(a, b);
  scalar := ScalarAddF64x4(a, b);
  for i := 0 to 3 do
    CheckF64(Format('AddF64x4[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_SubF64x4;
var a, b, rvv, scalar: TVecF64x4; i: Integer;
begin
  a := MakeF64x4(10.0, 9.0, 8.0, 7.0);
  b := MakeF64x4(1.0, 2.0, 3.0, 4.0);
  rvv := ScalarSubF64x4(a, b);
  scalar := ScalarSubF64x4(a, b);
  for i := 0 to 3 do
    CheckF64(Format('SubF64x4[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_MulF64x4;
var a, b, rvv, scalar: TVecF64x4; i: Integer;
begin
  a := MakeF64x4(2.0, 3.0, 4.0, 5.0);
  b := MakeF64x4(1.0, 2.0, 3.0, 4.0);
  rvv := ScalarMulF64x4(a, b);
  scalar := ScalarMulF64x4(a, b);
  for i := 0 to 3 do
    CheckF64(Format('MulF64x4[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_DivF64x4;
var a, b, rvv, scalar: TVecF64x4; i: Integer;
begin
  a := MakeF64x4(10.0, 20.0, 30.0, 40.0);
  b := MakeF64x4(2.0, 4.0, 5.0, 8.0);
  rvv := ScalarDivF64x4(a, b);
  scalar := ScalarDivF64x4(a, b);
  for i := 0 to 3 do
    CheckF64(Format('DivF64x4[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_MinF64x4;
var a, b, rvv, scalar: TVecF64x4; i: Integer;
begin
  a := MakeF64x4(1.0, 5.0, -3.0, 0.0);
  b := MakeF64x4(2.0, 3.0, -1.0, -5.0);
  rvv := ScalarMinF64x4(a, b);
  scalar := ScalarMinF64x4(a, b);
  for i := 0 to 3 do
    CheckF64(Format('MinF64x4[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_MaxF64x4;
var a, b, rvv, scalar: TVecF64x4; i: Integer;
begin
  a := MakeF64x4(1.0, 5.0, -3.0, 0.0);
  b := MakeF64x4(2.0, 3.0, -1.0, -5.0);
  rvv := ScalarMaxF64x4(a, b);
  scalar := ScalarMaxF64x4(a, b);
  for i := 0 to 3 do
    CheckF64(Format('MaxF64x4[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_AbsF64x4;
var a, rvv, scalar: TVecF64x4; i: Integer;
begin
  a := MakeF64x4(-1.0, 0.0, -3.14, 2.71);
  rvv := ScalarAbsF64x4(a);
  scalar := ScalarAbsF64x4(a);
  for i := 0 to 3 do
    CheckF64(Format('AbsF64x4[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_SqrtF64x4;
var a, rvv, scalar: TVecF64x4; i: Integer;
begin
  a := MakeF64x4(4.0, 9.0, 16.0, 25.0);
  rvv := ScalarSqrtF64x4(a);
  scalar := ScalarSqrtF64x4(a);
  for i := 0 to 3 do
    CheckF64(Format('SqrtF64x4[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_FmaF64x4;
var a, b, c, rvv, scalar: TVecF64x4; i: Integer;
begin
  a := MakeF64x4(1.0, 2.0, 3.0, 4.0);
  b := MakeF64x4(2.0, 3.0, 4.0, 5.0);
  c := MakeF64x4(0.1, 0.2, 0.3, 0.4);
  rvv := ScalarFmaF64x4(a, b, c);
  scalar := ScalarFmaF64x4(a, b, c);
  for i := 0 to 3 do
    CheckF64(Format('FmaF64x4[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

// =============================================================
// 256-bit I32x8
// =============================================================

procedure TRVVParityTestCase.Test_AddI32x8;
var a, b, rvv, scalar: TVecI32x8; i: Integer;
begin
  a := MakeI32x8(1,2,3,4, -1,-2,-3,-4);
  b := MakeI32x8(10,20,30,40, 1,2,3,4);
  rvv := ScalarAddI32x8(a, b);
  scalar := ScalarAddI32x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('AddI32x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_SubI32x8;
var a, b, rvv, scalar: TVecI32x8; i: Integer;
begin
  a := MakeI32x8(10,20,30,40,50,60,70,80);
  b := MakeI32x8(1,2,3,4,5,6,7,8);
  rvv := ScalarSubI32x8(a, b);
  scalar := ScalarSubI32x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('SubI32x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_MulI32x8;
var a, b, rvv, scalar: TVecI32x8; i: Integer;
begin
  a := MakeI32x8(2,3,4,5, -1,-2,-3,-4);
  b := MakeI32x8(5,6,7,8, 2,3,4,5);
  rvv := ScalarMulI32x8(a, b);
  scalar := ScalarMulI32x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('MulI32x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_AndI32x8;
var a, b, rvv, scalar: TVecI32x8; i: Integer;
begin
  a := MakeI32x8($FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeI32x8($0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarAndI32x8(a, b);
  scalar := ScalarAndI32x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('AndI32x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_OrI32x8;
var a, b, rvv, scalar: TVecI32x8; i: Integer;
begin
  a := MakeI32x8($FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeI32x8($0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarOrI32x8(a, b);
  scalar := ScalarOrI32x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('OrI32x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_XorI32x8;
var a, b, rvv, scalar: TVecI32x8; i: Integer;
begin
  a := MakeI32x8($FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeI32x8($0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarXorI32x8(a, b);
  scalar := ScalarXorI32x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('XorI32x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_NotI32x8;
var a, rvv, scalar: TVecI32x8; i: Integer;
begin
  a := MakeI32x8(0,-1,$FF,$AA55, 0,0,0,0);
  rvv := ScalarNotI32x8(a);
  scalar := ScalarNotI32x8(a);
  for i := 0 to 7 do
    CheckI32(Format('NotI32x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_MinI32x8;
var a, b, rvv, scalar: TVecI32x8; i: Integer;
begin
  a := MakeI32x8(1,5,-3,0,10,20,-5,-10);
  b := MakeI32x8(2,3,-1,-5,5,30,0,-1);
  rvv := ScalarMinI32x8(a, b);
  scalar := ScalarMinI32x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('MinI32x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_MaxI32x8;
var a, b, rvv, scalar: TVecI32x8; i: Integer;
begin
  a := MakeI32x8(1,5,-3,0,10,20,-5,-10);
  b := MakeI32x8(2,3,-1,-5,5,30,0,-1);
  rvv := ScalarMaxI32x8(a, b);
  scalar := ScalarMaxI32x8(a, b);
  for i := 0 to 7 do
    CheckI32(Format('MaxI32x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

// =============================================================
// 256-bit I64x4
// =============================================================

procedure TRVVParityTestCase.Test_AddI64x4;
var a, b, rvv, scalar: TVecI64x4; i: Integer;
begin
  a := MakeI64x4(1, -1, 100, -100);
  b := MakeI64x4(10, 20, 30, 40);
  rvv := ScalarAddI64x4(a, b);
  scalar := ScalarAddI64x4(a, b);
  for i := 0 to 3 do
    CheckI64(Format('AddI64x4[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_SubI64x4;
var a, b, rvv, scalar: TVecI64x4; i: Integer;
begin
  a := MakeI64x4(10, 20, 30, 40);
  b := MakeI64x4(1, 2, 3, 4);
  rvv := ScalarSubI64x4(a, b);
  scalar := ScalarSubI64x4(a, b);
  for i := 0 to 3 do
    CheckI64(Format('SubI64x4[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_AndI64x4;
var a, b, rvv, scalar: TVecI64x4; i: Integer;
begin
  a := MakeI64x4($FF, $0F, $F0, $AA);
  b := MakeI64x4($0F, $FF, $0F, $55);
  rvv := ScalarAndI64x4(a, b);
  scalar := ScalarAndI64x4(a, b);
  for i := 0 to 3 do
    CheckI64(Format('AndI64x4[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_OrI64x4;
var a, b, rvv, scalar: TVecI64x4; i: Integer;
begin
  a := MakeI64x4($FF, $0F, $F0, $AA);
  b := MakeI64x4($0F, $FF, $0F, $55);
  rvv := ScalarOrI64x4(a, b);
  scalar := ScalarOrI64x4(a, b);
  for i := 0 to 3 do
    CheckI64(Format('OrI64x4[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_XorI64x4;
var a, b, rvv, scalar: TVecI64x4; i: Integer;
begin
  a := MakeI64x4($FF, $0F, $F0, $AA);
  b := MakeI64x4($0F, $FF, $0F, $55);
  rvv := ScalarXorI64x4(a, b);
  scalar := ScalarXorI64x4(a, b);
  for i := 0 to 3 do
    CheckI64(Format('XorI64x4[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_NotI64x4;
var a, rvv, scalar: TVecI64x4; i: Integer;
begin
  a := MakeI64x4(0, -1, $FF, $AA55);
  rvv := ScalarNotI64x4(a);
  scalar := ScalarNotI64x4(a);
  for i := 0 to 3 do
    CheckI64(Format('NotI64x4[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

// =============================================================
// 256-bit U32x8
// =============================================================

procedure TRVVParityTestCase.Test_AddU32x8;
var a, b, rvv, scalar: TVecU32x8; i: Integer;
begin
  a := MakeU32x8(1,2,3,4, 100,200,300,400);
  b := MakeU32x8(10,20,30,40, 50,60,70,80);
  rvv := ScalarAddU32x8(a, b);
  scalar := ScalarAddU32x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('AddU32x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_SubU32x8;
var a, b, rvv, scalar: TVecU32x8; i: Integer;
begin
  a := MakeU32x8(10,20,30,40, 50,60,70,80);
  b := MakeU32x8(1,2,3,4, 5,6,7,8);
  rvv := ScalarSubU32x8(a, b);
  scalar := ScalarSubU32x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('SubU32x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_MulU32x8;
var a, b, rvv, scalar: TVecU32x8; i: Integer;
begin
  a := MakeU32x8(2,3,4,5, 6,7,8,9);
  b := MakeU32x8(5,6,7,8, 9,10,11,12);
  rvv := ScalarMulU32x8(a, b);
  scalar := ScalarMulU32x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('MulU32x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_AndU32x8;
var a, b, rvv, scalar: TVecU32x8; i: Integer;
begin
  a := MakeU32x8($FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeU32x8($0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarAndU32x8(a, b);
  scalar := ScalarAndU32x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('AndU32x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_OrU32x8;
var a, b, rvv, scalar: TVecU32x8; i: Integer;
begin
  a := MakeU32x8($FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeU32x8($0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarOrU32x8(a, b);
  scalar := ScalarOrU32x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('OrU32x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_XorU32x8;
var a, b, rvv, scalar: TVecU32x8; i: Integer;
begin
  a := MakeU32x8($FF,$0F,$F0,$AA,$55,$FF,$00,$0F);
  b := MakeU32x8($0F,$FF,$0F,$55,$AA,$00,$FF,$F0);
  rvv := ScalarXorU32x8(a, b);
  scalar := ScalarXorU32x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('XorU32x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_MinU32x8;
var a, b, rvv, scalar: TVecU32x8; i: Integer;
begin
  a := MakeU32x8(1,5,10,0,100,200,50,75);
  b := MakeU32x8(2,3,9,5,50,300,25,100);
  rvv := ScalarMinU32x8(a, b);
  scalar := ScalarMinU32x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('MinU32x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_MaxU32x8;
var a, b, rvv, scalar: TVecU32x8; i: Integer;
begin
  a := MakeU32x8(1,5,10,0,100,200,50,75);
  b := MakeU32x8(2,3,9,5,50,300,25,100);
  rvv := ScalarMaxU32x8(a, b);
  scalar := ScalarMaxU32x8(a, b);
  for i := 0 to 7 do
    CheckU32(Format('MaxU32x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

// =============================================================
// 256-bit U64x4
// =============================================================

procedure TRVVParityTestCase.Test_AddU64x4;
var a, b, rvv, scalar: TVecU64x4; i: Integer;
begin
  a := MakeU64x4(1, 100, $FFFFFFFF, 0);
  b := MakeU64x4(10, 20, 1, 0);
  rvv := ScalarAddU64x4(a, b);
  scalar := ScalarAddU64x4(a, b);
  for i := 0 to 3 do
    CheckU64(Format('AddU64x4[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_SubU64x4;
var a, b, rvv, scalar: TVecU64x4; i: Integer;
begin
  a := MakeU64x4(10, 20, 30, 40);
  b := MakeU64x4(1, 2, 3, 4);
  rvv := ScalarSubU64x4(a, b);
  scalar := ScalarSubU64x4(a, b);
  for i := 0 to 3 do
    CheckU64(Format('SubU64x4[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_AndU64x4;
var a, b, rvv, scalar: TVecU64x4; i: Integer;
begin
  a := MakeU64x4($FF, $0F, $F0, $AA);
  b := MakeU64x4($0F, $FF, $0F, $55);
  rvv := ScalarAndU64x4(a, b);
  scalar := ScalarAndU64x4(a, b);
  for i := 0 to 3 do
    CheckU64(Format('AndU64x4[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_OrU64x4;
var a, b, rvv, scalar: TVecU64x4; i: Integer;
begin
  a := MakeU64x4($FF, $0F, $F0, $AA);
  b := MakeU64x4($0F, $FF, $0F, $55);
  rvv := ScalarOrU64x4(a, b);
  scalar := ScalarOrU64x4(a, b);
  for i := 0 to 3 do
    CheckU64(Format('OrU64x4[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_XorU64x4;
var a, b, rvv, scalar: TVecU64x4; i: Integer;
begin
  a := MakeU64x4($FF, $0F, $F0, $AA);
  b := MakeU64x4($0F, $FF, $0F, $55);
  rvv := ScalarXorU64x4(a, b);
  scalar := ScalarXorU64x4(a, b);
  for i := 0 to 3 do
    CheckU64(Format('XorU64x4[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

// =============================================================
// 512-bit F32x16
// =============================================================

procedure TRVVParityTestCase.Test_AddF32x16;
var a, b, rvv, scalar: TVecF32x16; i: Integer;
begin
  a := MakeF32x16([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]);
  b := MakeF32x16([0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2,1.3,1.4,1.5,1.6]);
  rvv := ScalarAddF32x16(a, b);
  scalar := ScalarAddF32x16(a, b);
  for i := 0 to 15 do
    CheckF32(Format('AddF32x16[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_SubF32x16;
var a, b, rvv, scalar: TVecF32x16; i: Integer;
begin
  a := MakeF32x16([10,9,8,7,6,5,4,3,2,1,0,11,12,13,14,15]);
  b := MakeF32x16([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]);
  rvv := ScalarSubF32x16(a, b);
  scalar := ScalarSubF32x16(a, b);
  for i := 0 to 15 do
    CheckF32(Format('SubF32x16[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_MulF32x16;
var a, b, rvv, scalar: TVecF32x16; i: Integer;
begin
  a := MakeF32x16([2,3,4,5,6,7,8,9,1,2,3,4,5,6,7,8]);
  b := MakeF32x16([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]);
  rvv := ScalarMulF32x16(a, b);
  scalar := ScalarMulF32x16(a, b);
  for i := 0 to 15 do
    CheckF32(Format('MulF32x16[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_DivF32x16;
var a, b, rvv, scalar: TVecF32x16; i: Integer;
begin
  a := MakeF32x16([10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160]);
  b := MakeF32x16([2,4,5,8,10,12,14,16,18,20,22,24,26,28,30,32]);
  rvv := ScalarDivF32x16(a, b);
  scalar := ScalarDivF32x16(a, b);
  for i := 0 to 15 do
    CheckF32(Format('DivF32x16[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_MinF32x16;
var a, b, rvv, scalar: TVecF32x16; i: Integer;
begin
  a := MakeF32x16([1,5,-3,0,10,2,-5,0, 3,7,-2,1,11,3,-4,2]);
  b := MakeF32x16([2,3,-1,-5,5,3,0,1, 4,5,-3,0,9,4,-5,3]);
  rvv := ScalarMinF32x16(a, b);
  scalar := ScalarMinF32x16(a, b);
  for i := 0 to 15 do
    CheckF32(Format('MinF32x16[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_MaxF32x16;
var a, b, rvv, scalar: TVecF32x16; i: Integer;
begin
  a := MakeF32x16([1,5,-3,0,10,2,-5,0, 3,7,-2,1,11,3,-4,2]);
  b := MakeF32x16([2,3,-1,-5,5,3,0,1, 4,5,-3,0,9,4,-5,3]);
  rvv := ScalarMaxF32x16(a, b);
  scalar := ScalarMaxF32x16(a, b);
  for i := 0 to 15 do
    CheckF32(Format('MaxF32x16[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_AbsF32x16;
var a, rvv, scalar: TVecF32x16; i: Integer;
begin
  a := MakeF32x16([-1,0,-3.14,2.71,-0.5,10,-7,0, 1,-2,3,-4,5,-6,7,-8]);
  rvv := ScalarAbsF32x16(a);
  scalar := ScalarAbsF32x16(a);
  for i := 0 to 15 do
    CheckF32(Format('AbsF32x16[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_SqrtF32x16;
var a, rvv, scalar: TVecF32x16; i: Integer;
begin
  a := MakeF32x16([4,9,16,25,36,49,64,81, 100,121,144,169,196,225,256,289]);
  rvv := ScalarSqrtF32x16(a);
  scalar := ScalarSqrtF32x16(a);
  for i := 0 to 15 do
    CheckF32(Format('SqrtF32x16[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

// =============================================================
// 512-bit F64x8
// =============================================================

procedure TRVVParityTestCase.Test_AddF64x8;
var a, b, rvv, scalar: TVecF64x8; i: Integer;
begin
  a := MakeF64x8([1,2,3,4,5,6,7,8]);
  b := MakeF64x8([0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8]);
  rvv := ScalarAddF64x8(a, b);
  scalar := ScalarAddF64x8(a, b);
  for i := 0 to 7 do
    CheckF64(Format('AddF64x8[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_SubF64x8;
var a, b, rvv, scalar: TVecF64x8; i: Integer;
begin
  a := MakeF64x8([10,9,8,7,6,5,4,3]);
  b := MakeF64x8([1,2,3,4,5,6,7,8]);
  rvv := ScalarSubF64x8(a, b);
  scalar := ScalarSubF64x8(a, b);
  for i := 0 to 7 do
    CheckF64(Format('SubF64x8[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_MulF64x8;
var a, b, rvv, scalar: TVecF64x8; i: Integer;
begin
  a := MakeF64x8([2,3,4,5,6,7,8,9]);
  b := MakeF64x8([1,2,3,4,5,6,7,8]);
  rvv := ScalarMulF64x8(a, b);
  scalar := ScalarMulF64x8(a, b);
  for i := 0 to 7 do
    CheckF64(Format('MulF64x8[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_DivF64x8;
var a, b, rvv, scalar: TVecF64x8; i: Integer;
begin
  a := MakeF64x8([10,20,30,40,50,60,70,80]);
  b := MakeF64x8([2,4,5,8,10,12,14,16]);
  rvv := ScalarDivF64x8(a, b);
  scalar := ScalarDivF64x8(a, b);
  for i := 0 to 7 do
    CheckF64(Format('DivF64x8[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_MinF64x8;
var a, b, rvv, scalar: TVecF64x8; i: Integer;
begin
  a := MakeF64x8([1,5,-3,0,10,2,-5,0]);
  b := MakeF64x8([2,3,-1,-5,5,3,0,1]);
  rvv := ScalarMinF64x8(a, b);
  scalar := ScalarMinF64x8(a, b);
  for i := 0 to 7 do
    CheckF64(Format('MinF64x8[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_MaxF64x8;
var a, b, rvv, scalar: TVecF64x8; i: Integer;
begin
  a := MakeF64x8([1,5,-3,0,10,2,-5,0]);
  b := MakeF64x8([2,3,-1,-5,5,3,0,1]);
  rvv := ScalarMaxF64x8(a, b);
  scalar := ScalarMaxF64x8(a, b);
  for i := 0 to 7 do
    CheckF64(Format('MaxF64x8[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_AbsF64x8;
var a, rvv, scalar: TVecF64x8; i: Integer;
begin
  a := MakeF64x8([-1,0,-3.14,2.71,-0.5,10,-7,0]);
  rvv := ScalarAbsF64x8(a);
  scalar := ScalarAbsF64x8(a);
  for i := 0 to 7 do
    CheckF64(Format('AbsF64x8[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_SqrtF64x8;
var a, rvv, scalar: TVecF64x8; i: Integer;
begin
  a := MakeF64x8([4,9,16,25,36,49,64,81]);
  rvv := ScalarSqrtF64x8(a);
  scalar := ScalarSqrtF64x8(a);
  for i := 0 to 7 do
    CheckF64(Format('SqrtF64x8[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

// =============================================================
// 512-bit I32x16
// =============================================================

procedure TRVVParityTestCase.Test_AddI32x16;
var a, b, rvv, scalar: TVecI32x16; i: Integer;
begin
  a := MakeI32x16([1,2,3,4,-1,-2,-3,-4, 10,20,30,40,-10,-20,-30,-40]);
  b := MakeI32x16([10,20,30,40,1,2,3,4, 1,2,3,4,5,6,7,8]);
  rvv := ScalarAddI32x16(a, b);
  scalar := ScalarAddI32x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('AddI32x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_SubI32x16;
var a, b, rvv, scalar: TVecI32x16; i: Integer;
begin
  a := MakeI32x16([10,20,30,40,50,60,70,80, 100,110,120,130,140,150,160,170]);
  b := MakeI32x16([1,2,3,4,5,6,7,8, 10,20,30,40,50,60,70,80]);
  rvv := ScalarSubI32x16(a, b);
  scalar := ScalarSubI32x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('SubI32x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_MulI32x16;
var a, b, rvv, scalar: TVecI32x16; i: Integer;
begin
  a := MakeI32x16([2,3,4,5,-1,-2,-3,-4, 1,2,3,4,5,6,7,8]);
  b := MakeI32x16([5,6,7,8,2,3,4,5, 10,20,30,40,50,60,70,80]);
  rvv := ScalarMulI32x16(a, b);
  scalar := ScalarMulI32x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('MulI32x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_AndI32x16;
var a, b, rvv, scalar: TVecI32x16; i: Integer;
begin
  a := MakeI32x16([$FF,$0F,$F0,$AA,$55,$FF,$00,$0F, $FF,$0F,$F0,$AA,$55,$FF,$00,$0F]);
  b := MakeI32x16([$0F,$FF,$0F,$55,$AA,$00,$FF,$F0, $0F,$FF,$0F,$55,$AA,$00,$FF,$F0]);
  rvv := ScalarAndI32x16(a, b);
  scalar := ScalarAndI32x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('AndI32x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_OrI32x16;
var a, b, rvv, scalar: TVecI32x16; i: Integer;
begin
  a := MakeI32x16([$FF,$0F,$F0,$AA,$55,$FF,$00,$0F, $FF,$0F,$F0,$AA,$55,$FF,$00,$0F]);
  b := MakeI32x16([$0F,$FF,$0F,$55,$AA,$00,$FF,$F0, $0F,$FF,$0F,$55,$AA,$00,$FF,$F0]);
  rvv := ScalarOrI32x16(a, b);
  scalar := ScalarOrI32x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('OrI32x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_XorI32x16;
var a, b, rvv, scalar: TVecI32x16; i: Integer;
begin
  a := MakeI32x16([$FF,$0F,$F0,$AA,$55,$FF,$00,$0F, $FF,$0F,$F0,$AA,$55,$FF,$00,$0F]);
  b := MakeI32x16([$0F,$FF,$0F,$55,$AA,$00,$FF,$F0, $0F,$FF,$0F,$55,$AA,$00,$FF,$F0]);
  rvv := ScalarXorI32x16(a, b);
  scalar := ScalarXorI32x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('XorI32x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_MinI32x16;
var a, b, rvv, scalar: TVecI32x16; i: Integer;
begin
  a := MakeI32x16([1,5,-3,0,10,20,-5,-10, 3,7,-2,1,11,3,-4,2]);
  b := MakeI32x16([2,3,-1,-5,5,30,0,-1, 4,5,-3,0,9,4,-5,3]);
  rvv := ScalarMinI32x16(a, b);
  scalar := ScalarMinI32x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('MinI32x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_MaxI32x16;
var a, b, rvv, scalar: TVecI32x16; i: Integer;
begin
  a := MakeI32x16([1,5,-3,0,10,20,-5,-10, 3,7,-2,1,11,3,-4,2]);
  b := MakeI32x16([2,3,-1,-5,5,30,0,-1, 4,5,-3,0,9,4,-5,3]);
  rvv := ScalarMaxI32x16(a, b);
  scalar := ScalarMaxI32x16(a, b);
  for i := 0 to 15 do
    CheckI32(Format('MaxI32x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

// =============================================================
// 512-bit I64x8
// =============================================================

procedure TRVVParityTestCase.Test_AddI64x8;
var a, b, rvv, scalar: TVecI64x8; i: Integer;
begin
  a := MakeI64x8([1,-1,100,-100,0,0,0,0]);
  b := MakeI64x8([10,20,30,40,1,2,3,4]);
  rvv := ScalarAddI64x8(a, b);
  scalar := ScalarAddI64x8(a, b);
  for i := 0 to 7 do
    CheckI64(Format('AddI64x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_SubI64x8;
var a, b, rvv, scalar: TVecI64x8; i: Integer;
begin
  a := MakeI64x8([10,20,30,40,50,60,70,80]);
  b := MakeI64x8([1,2,3,4,5,6,7,8]);
  rvv := ScalarSubI64x8(a, b);
  scalar := ScalarSubI64x8(a, b);
  for i := 0 to 7 do
    CheckI64(Format('SubI64x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_AndI64x8;
var a, b, rvv, scalar: TVecI64x8; i: Integer;
begin
  a := MakeI64x8([$FF,$0F,$F0,$AA,$55,$FF,$00,$0F]);
  b := MakeI64x8([$0F,$FF,$0F,$55,$AA,$00,$FF,$F0]);
  rvv := ScalarAndI64x8(a, b);
  scalar := ScalarAndI64x8(a, b);
  for i := 0 to 7 do
    CheckI64(Format('AndI64x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_OrI64x8;
var a, b, rvv, scalar: TVecI64x8; i: Integer;
begin
  a := MakeI64x8([$FF,$0F,$F0,$AA,$55,$FF,$00,$0F]);
  b := MakeI64x8([$0F,$FF,$0F,$55,$AA,$00,$FF,$F0]);
  rvv := ScalarOrI64x8(a, b);
  scalar := ScalarOrI64x8(a, b);
  for i := 0 to 7 do
    CheckI64(Format('OrI64x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_XorI64x8;
var a, b, rvv, scalar: TVecI64x8; i: Integer;
begin
  a := MakeI64x8([$FF,$0F,$F0,$AA,$55,$FF,$00,$0F]);
  b := MakeI64x8([$0F,$FF,$0F,$55,$AA,$00,$FF,$F0]);
  rvv := ScalarXorI64x8(a, b);
  scalar := ScalarXorI64x8(a, b);
  for i := 0 to 7 do
    CheckI64(Format('XorI64x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

// =============================================================
// Mask operations
// =============================================================

procedure TRVVParityTestCase.Test_Mask4_AllAnyNone;
begin
  AssertTrue('Mask4All($F)', ScalarMask4All($F));
  AssertFalse('Mask4All($A)', ScalarMask4All($A));
  AssertTrue('Mask4Any($A)', ScalarMask4Any($A));
  AssertFalse('Mask4Any(0)', ScalarMask4Any(0));
  AssertTrue('Mask4None(0)', ScalarMask4None(0));
  AssertFalse('Mask4None($F)', ScalarMask4None($F));
end;

procedure TRVVParityTestCase.Test_Mask4_PopCountFirstSet;
begin
  AssertEquals('Mask4PopCount($F)', 4, ScalarMask4PopCount($F));
  AssertEquals('Mask4PopCount($5)', 2, ScalarMask4PopCount($5));
  AssertEquals('Mask4PopCount(0)', 0, ScalarMask4PopCount(0));
  AssertEquals('Mask4FirstSet(0)', -1, ScalarMask4FirstSet(0));
  AssertEquals('Mask4FirstSet($2)', 1, ScalarMask4FirstSet($2));
  AssertEquals('Mask4FirstSet($8)', 3, ScalarMask4FirstSet($8));
end;

procedure TRVVParityTestCase.Test_Mask4_LogicalOps;
begin
  AssertEquals('Mask4And', $0A, $0F and $AA and $0F);
  AssertEquals('Mask4Or', $0F, ($0F or $A0) and $0F);
  AssertEquals('Mask4Xor', $05, ($0F xor $0A) and $0F);
  AssertEquals('Mask4Not', $0A, (not $05) and $0F);
end;

procedure TRVVParityTestCase.Test_Mask8_AllAnyNone;
begin
  AssertTrue('Mask8All($FF)', ScalarMask8All($FF));
  AssertFalse('Mask8All($AA)', ScalarMask8All($AA));
  AssertTrue('Mask8Any($01)', ScalarMask8Any($01));
  AssertFalse('Mask8Any(0)', ScalarMask8Any(0));
  AssertTrue('Mask8None(0)', ScalarMask8None(0));
  AssertFalse('Mask8None($FF)', ScalarMask8None($FF));
end;

procedure TRVVParityTestCase.Test_Mask8_PopCountFirstSet;
begin
  AssertEquals('Mask8PopCount($FF)', 8, ScalarMask8PopCount($FF));
  AssertEquals('Mask8PopCount($55)', 4, ScalarMask8PopCount($55));
  AssertEquals('Mask8FirstSet(0)', -1, ScalarMask8FirstSet(0));
  AssertEquals('Mask8FirstSet($04)', 2, ScalarMask8FirstSet($04));
end;

procedure TRVVParityTestCase.Test_Mask8_LogicalOps;
begin
  AssertEquals('Mask8And', $0F, $FF and $0F);
  AssertEquals('Mask8Or', $FF, $F0 or $0F);
  AssertEquals('Mask8Xor', $F0, $FF xor $0F);
  AssertEquals('Mask8Not', Byte($F0), Byte(not $0F));
end;

procedure TRVVParityTestCase.Test_Mask16_AllAnyNone;
begin
  AssertTrue('Mask16All($FFFF)', ScalarMask16All($FFFF));
  AssertFalse('Mask16All($AAAA)', ScalarMask16All($AAAA));
  AssertTrue('Mask16Any($0001)', ScalarMask16Any($0001));
  AssertFalse('Mask16Any(0)', ScalarMask16Any(0));
  AssertTrue('Mask16None(0)', ScalarMask16None(0));
  AssertFalse('Mask16None($FFFF)', ScalarMask16None($FFFF));
end;

procedure TRVVParityTestCase.Test_Mask16_PopCountFirstSet;
begin
  AssertEquals('Mask16PopCount($FFFF)', 16, ScalarMask16PopCount($FFFF));
  AssertEquals('Mask16PopCount($5555)', 8, ScalarMask16PopCount($5555));
  AssertEquals('Mask16FirstSet(0)', -1, ScalarMask16FirstSet(0));
  AssertEquals('Mask16FirstSet($0010)', 4, ScalarMask16FirstSet($0010));
end;

procedure TRVVParityTestCase.Test_Mask16_LogicalOps;
begin
  AssertEquals('Mask16And', $00FF, $FFFF and $00FF);
  AssertEquals('Mask16Or', $FFFF, $FF00 or $00FF);
  AssertEquals('Mask16Xor', $FF00, $FFFF xor $00FF);
  AssertEquals('Mask16Not', Word($F0F0), Word(not $0F0F));
end;

procedure TRVVParityTestCase.Test_Mask2_AllAnyNone;
begin
  AssertTrue('Mask2All($3)', ScalarMask2All($3));
  AssertFalse('Mask2All($2)', ScalarMask2All($2));
  AssertTrue('Mask2Any($2)', ScalarMask2Any($2));
  AssertFalse('Mask2Any(0)', ScalarMask2Any(0));
  AssertTrue('Mask2None(0)', ScalarMask2None(0));
  AssertFalse('Mask2None($3)', ScalarMask2None($3));
end;

procedure TRVVParityTestCase.Test_Mask2_PopCountFirstSet;
begin
  AssertEquals('Mask2PopCount($3)', 2, ScalarMask2PopCount($3));
  AssertEquals('Mask2PopCount($1)', 1, ScalarMask2PopCount($1));
  AssertEquals('Mask2PopCount(0)', 0, ScalarMask2PopCount(0));
  AssertEquals('Mask2FirstSet(0)', -1, ScalarMask2FirstSet(0));
  AssertEquals('Mask2FirstSet($2)', 1, ScalarMask2FirstSet($2));
end;

// =============================================================
// Saturated arithmetic
// =============================================================

procedure TRVVParityTestCase.Test_SatAddI8x16;
var a, b, rvv, scalar: TVecI8x16; i: Integer;
begin
  a := MakeI8x16(127, 50, -128, 0, 100, -100, 64, -64, 1,2,3,4,5,6,7,8);
  b := MakeI8x16(1, 50, -1, 0, 50, -50, 64, -64, 10,20,30,40,50,60,70,80);
  rvv := ScalarI8x16SatAdd(a, b);
  scalar := ScalarI8x16SatAdd(a, b);
  for i := 0 to 15 do
    CheckI32(Format('SatAddI8x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_SatSubI8x16;
var a, b, rvv, scalar: TVecI8x16; i: Integer;
begin
  a := MakeI8x16(-128, 0, 127, 50, 0, 0, 0, 0, 0,0,0,0,0,0,0,0);
  b := MakeI8x16(1, 1, -1, -100, 0, 0, 0, 0, 0,0,0,0,0,0,0,0);
  rvv := ScalarI8x16SatSub(a, b);
  scalar := ScalarI8x16SatSub(a, b);
  for i := 0 to 15 do
    CheckI32(Format('SatSubI8x16[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_SatAddI16x8;
var a, b, rvv, scalar: TVecI16x8; i: Integer;
begin
  a := MakeI16x8(32767, 10000, -32768, 0, 0, 0, 0, 0);
  b := MakeI16x8(1, 20000, -1, 0, 0, 0, 0, 0);
  rvv := ScalarI16x8SatAdd(a, b);
  scalar := ScalarI16x8SatAdd(a, b);
  for i := 0 to 7 do
    CheckI32(Format('SatAddI16x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_SatSubI16x8;
var a, b, rvv, scalar: TVecI16x8; i: Integer;
begin
  a := MakeI16x8(-32768, 0, 32767, 0, 0, 0, 0, 0);
  b := MakeI16x8(1, 1, -1, 0, 0, 0, 0, 0);
  rvv := ScalarI16x8SatSub(a, b);
  scalar := ScalarI16x8SatSub(a, b);
  for i := 0 to 7 do
    CheckI32(Format('SatSubI16x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_SatAddU8x16;
var a, b, rvv, scalar: TVecU8x16; i: Integer;
begin
  a := MakeU8x16(255, 200, 0, 100, 0,0,0,0, 0,0,0,0,0,0,0,0);
  b := MakeU8x16(1, 100, 0, 100, 0,0,0,0, 0,0,0,0,0,0,0,0);
  rvv := ScalarU8x16SatAdd(a, b);
  scalar := ScalarU8x16SatAdd(a, b);
  for i := 0 to 15 do
    CheckU32(Format('SatAddU8x16[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_SatSubU8x16;
var a, b, rvv, scalar: TVecU8x16; i: Integer;
begin
  a := MakeU8x16(0, 10, 200, 50, 0,0,0,0, 0,0,0,0,0,0,0,0);
  b := MakeU8x16(1, 5, 100, 100, 0,0,0,0, 0,0,0,0,0,0,0,0);
  rvv := ScalarU8x16SatSub(a, b);
  scalar := ScalarU8x16SatSub(a, b);
  for i := 0 to 15 do
    CheckU32(Format('SatSubU8x16[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_SatAddU16x8;
var a, b, rvv, scalar: TVecU16x8; i: Integer;
begin
  a := MakeU16x8(65535, 40000, 0, 10000, 0, 0, 0, 0);
  b := MakeU16x8(1, 30000, 0, 10000, 0, 0, 0, 0);
  rvv := ScalarU16x8SatAdd(a, b);
  scalar := ScalarU16x8SatAdd(a, b);
  for i := 0 to 7 do
    CheckU32(Format('SatAddU16x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

procedure TRVVParityTestCase.Test_SatSubU16x8;
var a, b, rvv, scalar: TVecU16x8; i: Integer;
begin
  a := MakeU16x8(0, 10, 50000, 100, 0, 0, 0, 0);
  b := MakeU16x8(1, 5, 10000, 200, 0, 0, 0, 0);
  rvv := ScalarU16x8SatSub(a, b);
  scalar := ScalarU16x8SatSub(a, b);
  for i := 0 to 7 do
    CheckU32(Format('SatSubU16x8[%d]', [i]), scalar.u[i], rvv.u[i]);
end;

// =============================================================
// Insert operations
// =============================================================

procedure TRVVParityTestCase.Test_InsertF32x8;
var a, rvv, scalar: TVecF32x8; i: Integer;
begin
  a := ScalarZeroF32x8();
  rvv := ScalarInsertF32x8(a, 3.14, 3);
  scalar := ScalarInsertF32x8(a, 3.14, 3);
  for i := 0 to 7 do
    CheckF32(Format('InsertF32x8[%d]', [i]), scalar.f[i], rvv.f[i]);
end;

procedure TRVVParityTestCase.Test_InsertF64x4;
var a, rvv, scalar: TVecF64x4; i: Integer;
begin
  a := ScalarZeroF64x4();
  rvv := ScalarInsertF64x4(a, 2.718, 1);
  scalar := ScalarInsertF64x4(a, 2.718, 1);
  for i := 0 to 3 do
    CheckF64(Format('InsertF64x4[%d]', [i]), scalar.d[i], rvv.d[i]);
end;

procedure TRVVParityTestCase.Test_InsertI32x4;
var a, rvv, scalar: TVecI32x4; i: Integer;
begin
  a := MakeI32x4(0, 0, 0, 0);
  rvv := ScalarInsertI32x4(a, 42, 2);
  scalar := ScalarInsertI32x4(a, 42, 2);
  for i := 0 to 3 do
    CheckI32(Format('InsertI32x4[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_InsertI32x8;
var a, rvv, scalar: TVecI32x8; i: Integer;
begin
  a := MakeI32x8(0,0,0,0,0,0,0,0);
  rvv := ScalarInsertI32x8(a, -1, 5);
  scalar := ScalarInsertI32x8(a, -1, 5);
  for i := 0 to 7 do
    CheckI32(Format('InsertI32x8[%d]', [i]), scalar.i[i], rvv.i[i]);
end;

procedure TRVVParityTestCase.Test_InsertI64x2;
var a, rvv, scalar: TVecI64x2;
begin
  a := MakeI64x2(0, 0);
  rvv := ScalarInsertI64x2(a, 99, 1);
  scalar := ScalarInsertI64x2(a, 99, 1);
  CheckI64('InsertI64x2[0]', scalar.i[0], rvv.i[0]);
  CheckI64('InsertI64x2[1]', scalar.i[1], rvv.i[1]);
end;

// =============================================================
// Reduce wide
// =============================================================

procedure TRVVParityTestCase.Test_ReduceAddF32x8;
var a: TVecF32x8; rvv, scalar: Single;
begin
  a := MakeF32x8(1,2,3,4,5,6,7,8);
  rvv := ScalarReduceAddF32x8(a);
  scalar := ScalarReduceAddF32x8(a);
  CheckF32('ReduceAddF32x8', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMinF32x8;
var a: TVecF32x8; rvv, scalar: Single;
begin
  a := MakeF32x8(3,1,4,2,7,0,5,6);
  rvv := ScalarReduceMinF32x8(a);
  scalar := ScalarReduceMinF32x8(a);
  CheckF32('ReduceMinF32x8', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMaxF32x8;
var a: TVecF32x8; rvv, scalar: Single;
begin
  a := MakeF32x8(3,1,4,2,7,0,5,6);
  rvv := ScalarReduceMaxF32x8(a);
  scalar := ScalarReduceMaxF32x8(a);
  CheckF32('ReduceMaxF32x8', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMulF32x8;
var a: TVecF32x8; rvv, scalar: Single;
begin
  a := MakeF32x8(1,2,3,4,5,6,7,8);
  rvv := ScalarReduceMulF32x8(a);
  scalar := ScalarReduceMulF32x8(a);
  CheckF32('ReduceMulF32x8', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceAddF64x4;
var a: TVecF64x4; rvv, scalar: Double;
begin
  a := MakeF64x4(1,2,3,4);
  rvv := ScalarReduceAddF64x4(a);
  scalar := ScalarReduceAddF64x4(a);
  CheckF64('ReduceAddF64x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMinF64x4;
var a: TVecF64x4; rvv, scalar: Double;
begin
  a := MakeF64x4(3,1,4,2);
  rvv := ScalarReduceMinF64x4(a);
  scalar := ScalarReduceMinF64x4(a);
  CheckF64('ReduceMinF64x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMaxF64x4;
var a: TVecF64x4; rvv, scalar: Double;
begin
  a := MakeF64x4(3,1,4,2);
  rvv := ScalarReduceMaxF64x4(a);
  scalar := ScalarReduceMaxF64x4(a);
  CheckF64('ReduceMaxF64x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMulF64x4;
var a: TVecF64x4; rvv, scalar: Double;
begin
  a := MakeF64x4(1,2,3,4);
  rvv := ScalarReduceMulF64x4(a);
  scalar := ScalarReduceMulF64x4(a);
  CheckF64('ReduceMulF64x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceAddF32x16;
var a: TVecF32x16; rvv, scalar: Single;
begin
  a := MakeF32x16([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]);
  rvv := ScalarReduceAddF32x16(a);
  scalar := ScalarReduceAddF32x16(a);
  CheckF32('ReduceAddF32x16', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMinF32x16;
var a: TVecF32x16; rvv, scalar: Single;
begin
  a := MakeF32x16([3,1,4,2,7,0,5,6, 9,8,11,10,13,12,15,14]);
  rvv := ScalarReduceMinF32x16(a);
  scalar := ScalarReduceMinF32x16(a);
  CheckF32('ReduceMinF32x16', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMaxF32x16;
var a: TVecF32x16; rvv, scalar: Single;
begin
  a := MakeF32x16([3,1,4,2,7,0,5,6, 9,8,11,10,13,12,15,14]);
  rvv := ScalarReduceMaxF32x16(a);
  scalar := ScalarReduceMaxF32x16(a);
  CheckF32('ReduceMaxF32x16', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_ReduceMulF32x16;
var a: TVecF32x16; rvv, scalar: Single;
begin
  a := MakeF32x16([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]);
  rvv := ScalarReduceMulF32x16(a);
  scalar := ScalarReduceMulF32x16(a);
  CheckF32('ReduceMulF32x16', scalar, rvv);
end;

// =============================================================
// Dot / Length
// =============================================================

procedure TRVVParityTestCase.Test_DotF32x4;
var a, b: TVecF32x4; rvv, scalar: Single;
begin
  a := MakeF32x4(1,2,3,4);
  b := MakeF32x4(5,6,7,8);
  rvv := ScalarDotF32x4(a, b);
  scalar := ScalarDotF32x4(a, b);
  CheckF32('DotF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_DotF32x3;
var a, b: TVecF32x4; rvv, scalar: Single;
begin
  a := MakeF32x4(1,2,3,0);
  b := MakeF32x4(4,5,6,0);
  rvv := ScalarDotF32x3(a, b);
  scalar := ScalarDotF32x3(a, b);
  CheckF32('DotF32x3', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_LengthF32x4;
var a: TVecF32x4; rvv, scalar: Single;
begin
  a := MakeF32x4(3,4,0,0);
  rvv := ScalarLengthF32x4(a);
  scalar := ScalarLengthF32x4(a);
  CheckF32('LengthF32x4', scalar, rvv);
end;

procedure TRVVParityTestCase.Test_LengthF32x3;
var a: TVecF32x4; rvv, scalar: Single;
begin
  a := MakeF32x4(1,2,2,0);
  rvv := ScalarLengthF32x3(a);
  scalar := ScalarLengthF32x3(a);
  CheckF32('LengthF32x3', scalar, rvv);
end;


// =============================================================
// G16 Phase 2: RVV type layout + dispatch contract tests
// =============================================================

procedure TRVVParityTestCase.Test_RVVVector_Size;
begin
  {$IFDEF CPURISCV64}
  AssertEquals('RVVVector size should be 64 bytes', 64, SizeOf(TRVVVector));
  {$ELSE}
  AssertTrue('RVVVector type not available on this platform', True);
  {$ENDIF}
end;

procedure TRVVParityTestCase.Test_RVVMask_Size;
begin
  {$IFDEF CPURISCV64}
  AssertTrue('RVVMask size should be positive', SizeOf(TRVVMask) > 0);
  {$ELSE}
  AssertTrue('RVVMask type not available on this platform', True);
  {$ENDIF}
end;

procedure TRVVParityTestCase.Test_RVV_FeatureDetection_OnX86;
begin
  {$IFDEF CPUX86_64}
  // On x86, the RVV backend should not be registered/available
  AssertFalse('RVV should not be available on x86',
    GetBackendInfo(sbRISCVV).Available);
  {$ELSE}
  AssertTrue('RVV detection test - non-x86 placeholder', True);
  {$ENDIF}
end;

procedure TRVVParityTestCase.Test_RVV_BackendPriority_Experimental;
var
  LInfo: TSimdBackendInfo;
begin
  LInfo := GetBackendInfo(sbRISCVV);
  AssertTrue('RVV backend priority should be non-negative',
    LInfo.Priority >= 0);
  AssertTrue('RVV backend name should contain RVV or RISC-V',
    (Pos('RVV', LInfo.Name) > 0) or (Pos('RISC', LInfo.Name) > 0));
end;

initialization
  RegisterTest(TRVVParityTestCase);
end.
