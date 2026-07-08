unit nextpas.core.simd.ieee754.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  Math, Classes, nextpas.core.text.conv, nextpas.core.math, nextpas.core.test,
  nextpas.core.simd, nextpas.core.simd.testcase,
  nextpas.core.simd.base, nextpas.core.simd.dispatch,
  nextpas.core.simd.scalar, nextpas.core.simd.ops;

type
  TIEEE754MaskedVectorAsmStatefulTestCase = class(TSimdVectorAsmStatefulTestCase)
  protected
    FSavedExceptionMask: TFPUExceptionMask;
    procedure BeforeEach; override;
    procedure AfterEach; override;
  end;

  // ============================================================================
  // IEEE 754 F64 (双精度浮点) 特殊值专项测试
  // ============================================================================
  TTestCase_IEEE754_F64 = class(TIEEE754MaskedVectorAsmStatefulTestCase)
  public
    procedure BeforeEach; override;
  published
    // === Infinity 测试 ===
    procedure Test_F64_PositiveInfinity_Add;      // Inf + x = Inf
    procedure Test_F64_NegativeInfinity_Add;      // -Inf + x = -Inf
    procedure Test_F64_Infinity_Mul;              // Inf * positive = Inf
    procedure Test_F64_Infinity_Div;              // x / Inf = 0
    procedure Test_F64_InfinityMinusInfinity;     // Inf - Inf = NaN

    // === NaN 测试 ===
    procedure Test_F64_NaN_Propagation;           // NaN + x = NaN
    procedure Test_F64_NaN_Comparison;            // NaN 比较总是 false
    procedure Test_F64_NaN_Min;                   // Min(NaN, x) 行为
    procedure Test_F64_NaN_Max;                   // Max(NaN, x) 行为
    procedure Test_F64_ReduceMinMax_SpecialCases; // ReduceMin/Max 的 NaN/零值次序语义

    // === 负零测试 ===
    procedure Test_F64_NegativeZero_Add;          // -0 + 0 = 0
    procedure Test_F64_NegativeZero_Mul;          // -0 * positive = -0
    procedure Test_F64_NegativeZero_Cmp;          // -0 == 0 应为 true

    // === Denormal (次正规数) 测试 ===
    procedure Test_F64_Denormal_Add;              // 次正规数加法
    procedure Test_F64_Denormal_Mul;              // 次正规数乘法（可能下溢到 0）

    // === 溢出/下溢测试 ===
    procedure Test_F64_Overflow;                  // 大数相乘产生 Inf
    procedure Test_F64_Underflow;                 // 小数相乘产生 0 或 denormal
  end;

  // IEEE 754 特殊值边界测试 - 全面覆盖 NaN、Infinity、零值、舍入边界
  TTestCase_IEEE754EdgeCases = class(TIEEE754MaskedVectorAsmStatefulTestCase)
  published
    // === NaN 传播测试 (F32x4) ===
    procedure Test_F32x4_NaN_Add;        // NaN + x = NaN
    procedure Test_F32x4_NaN_Sub;        // NaN - x = NaN
    procedure Test_F32x4_NaN_Mul;        // NaN * x = NaN
    procedure Test_F32x4_NaN_Div;        // NaN / x = NaN
    procedure Test_F32x4_NaN_Min;        // Min(NaN, x) 行为
    procedure Test_F32x4_NaN_Max;        // Max(NaN, x) 行为

    // === Infinity 测试 (F32x4) ===
    procedure Test_F32x4_Inf_Add;        // Inf + x = Inf
    procedure Test_F32x4_Inf_Sub;        // Inf - Inf = NaN
    procedure Test_F32x4_Inf_Mul;        // Inf * 0 = NaN
    procedure Test_F32x4_Inf_Div;        // x / Inf = 0
    procedure Test_F32x4_NegInf;         // -Inf 行为

    // === 零值测试 (F32x4) ===
    procedure Test_F32x4_Zero_Div;       // x / 0 = ±Inf
    procedure Test_F32x4_NegZero;        // -0.0 vs +0.0

    // === 舍入边界测试 (F32x4) ===
    procedure Test_F32x4_Floor_NaN;      // Floor(NaN) = NaN
    procedure Test_F32x4_Ceil_Inf;       // Ceil(Inf) = Inf
    procedure Test_F32x4_Round_LargeValue; // 大数舍入精度
    procedure Test_F32x4_RoundTrunc_NaNInf_Scalar;
    procedure Test_F32x4_RoundTrunc_NaNInf_SSE2;
    procedure Test_Wide_RoundTrunc_NaNInf_Scalar;
    procedure Test_Wide_RoundTrunc_NaNInf_SSE2;

    // === 256-bit 向量特殊值测试 ===
    procedure Test_F32x8_NaN_Propagation;    // F32x8 NaN 传播
    procedure Test_F64x4_Inf_Handling;       // F64x4 Infinity 处理
    procedure Test_F32x8_Mixed_Special;      // 混合正常值和特殊值

    // === 512-bit 向量特殊值测试 (如果支持) ===
    procedure Test_F32x16_NaN_Propagation;   // F32x16 NaN 传播
    procedure Test_F64x8_Inf_Handling;       // F64x8 Infinity 处理
  end;

  // AVX2 路径专项：验证 vector-asm 打开时，Round/Trunc 与 Scalar/SSE2 语义一致
  TTestCase_AVX2RoundTruncIEEE754 = class(TIEEE754MaskedVectorAsmStatefulTestCase)
  published
    procedure Test_AVX2_RoundTrunc_NaNInf_Consistency;
    procedure Test_AVX2_FloorCeil_NaNInf_Consistency;
    procedure Test_AVX2_FloorCeil_PropertyLike_Randomized;
    procedure Test_AVX2_RoundTrunc_PropertyLike_Randomized;
    procedure Test_AVX2_RoundTrunc_SignedZero_Consistency;
  end;

  // non-x86 后端专项：NEON/RISCVV 的异常值语义与 Scalar 对齐
  TTestCase_NonX86IEEE754 = class(TSimdVectorAsmStatefulTestCase)
  published
    procedure Test_NonX86_RoundTruncFloorCeil_NaNInf_IfAvailable;
    procedure Test_NonX86_NarrowF64x2_RoundTruncFloorCeil_Finite_IfAvailable;
    procedure Test_RISCVV_WideClampF32_SpecialCases_IfAvailable;
    procedure Test_RISCVV_DotF64_DirectRegisteredTable_SpecialCases_IfRegistered;
    procedure Test_RISCVV_WideRoundTrunc_DirectRegisteredTable_SignedZeroParity_IfRegistered;
    procedure Test_NonX86_F32_ReduceMinMax_SpecialCases_IfAvailable;
    procedure Test_NonX86_F32_WideMinMax_SpecialCases_IfAvailable;
    procedure Test_NonX86_F64_MinMaxReduce_SpecialCases_IfAvailable;
    procedure Test_NonX86_F64_WideMinMax_SpecialCases_IfAvailable;
    procedure Test_NonX86_Wide_RoundTruncFloorCeil_NaNInf_IfAvailable;
    procedure Test_NonX86_FloorCeil_PropertyLike_FixedSeed_IfAvailable;
    procedure Test_NonX86_RoundTrunc_PropertyLike_FixedSeed_IfAvailable;
  end;

implementation

function BitsFromSingle(const aValue: Single): DWord; inline;
begin
  Move(aValue, Result, SizeOf(Result));
end;

function IsNaNSingle(const aValue: Single): Boolean; inline;
var
  LBits: DWord;
begin
  // Use bit-level IEEE754 NaN detection to avoid FP invalid-op side effects.
  LBits := BitsFromSingle(aValue);
  Result := ((LBits and $7F800000) = $7F800000) and ((LBits and $007FFFFF) <> 0);
end;

function BitsFromDouble(const aValue: Double): QWord; inline;
begin
  Move(aValue, Result, SizeOf(Result));
end;

function IsNaNDouble(const aValue: Double): Boolean; inline;
var
  LBits: QWord;
begin
  LBits := BitsFromDouble(aValue);
  Result := ((LBits and QWord($7FF0000000000000)) = QWord($7FF0000000000000)) and
            ((LBits and QWord($000FFFFFFFFFFFFF)) <> 0);
end;

function IEEE754BackendName(const aBackend: TSimdBackend): string;
begin
  Result := GetBackendInfo(aBackend).Name;
end;

{ TIEEE754MaskedVectorAsmStatefulTestCase }

procedure TIEEE754MaskedVectorAsmStatefulTestCase.BeforeEach;
begin
  inherited BeforeEach;
  FSavedExceptionMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
end;

procedure TIEEE754MaskedVectorAsmStatefulTestCase.AfterEach;
begin
  SetExceptionMask(FSavedExceptionMask);
  inherited AfterEach;
end;

{ TTestCase_IEEE754_F64 - IEEE 754 F64 双精度浮点特殊值专项测试 }

const
  // IEEE 754 F64 特殊值常量
  PosInfF64: Double = 1.0 / 0.0;
  NegInfF64: Double = -1.0 / 0.0;
  NaNF64: Double = 0.0 / 0.0;
  NegZeroF64: Double = -0.0;
  // 最小次正规数: 2^(-1074) ≈ 5e-324
  SmallestDenormalF64: Double = 5e-324;
  // 最小正规数: 2^(-1022) ≈ 2.225e-308
  SmallestNormalF64: Double = 2.2250738585072014e-308;
  // 最大有限数: (2 - 2^(-52)) * 2^1023 ≈ 1.798e+308
  MaxFiniteF64: Double = 1.7976931348623157e+308;

procedure TTestCase_IEEE754_F64.BeforeEach;
begin
  inherited BeforeEach;
  // 强制使用 Scalar 后端以确保测试一致性
  SetActiveBackend(sbScalar);
end;

// === Infinity 测试 ===

procedure TTestCase_IEEE754_F64.Test_F64_PositiveInfinity_Add;
var
  a, b, r: TVecF64x2;
  a4, b4, r4: TVecF64x4;
begin
  // Inf + x = Inf (对于任何有限数 x)
  a.d[0] := PosInfF64;
  a.d[1] := PosInfF64;
  b.d[0] := 1.0;
  b.d[1] := -1000000.0;

  r := ScalarAddF64x2(a, b);
  CheckTrue(IsInfinite(r.d[0]) and (r.d[0] > 0), 'Inf + 1.0 should be Inf');
  CheckTrue(IsInfinite(r.d[1]) and (r.d[1] > 0), 'Inf + (-1000000) should be Inf');

  // 测试 F64x4
  a4.d[0] := PosInfF64; a4.d[1] := PosInfF64; a4.d[2] := PosInfF64; a4.d[3] := PosInfF64;
  b4.d[0] := 0.0; b4.d[1] := 1e308; b4.d[2] := -1e308; b4.d[3] := 42.0;
  r4 := ScalarAddF64x4(a4, b4);
  CheckTrue(IsInfinite(r4.d[0]) and (r4.d[0] > 0), 'F64x4: Inf + 0 should be Inf');
  CheckTrue(IsInfinite(r4.d[1]) and (r4.d[1] > 0), 'F64x4: Inf + 1e308 should be Inf');
  CheckTrue(IsInfinite(r4.d[2]) and (r4.d[2] > 0), 'F64x4: Inf + (-1e308) should be Inf');
  CheckTrue(IsInfinite(r4.d[3]) and (r4.d[3] > 0), 'F64x4: Inf + 42 should be Inf');
end;

procedure TTestCase_IEEE754_F64.Test_F64_NegativeInfinity_Add;
var
  a, b, r: TVecF64x2;
  a4, b4, r4: TVecF64x4;
begin
  // -Inf + x = -Inf (对于任何有限数 x)
  a.d[0] := NegInfF64;
  a.d[1] := NegInfF64;
  b.d[0] := 1.0;
  b.d[1] := 1000000.0;

  r := ScalarAddF64x2(a, b);
  CheckTrue(IsInfinite(r.d[0]) and (r.d[0] < 0), '-Inf + 1.0 should be -Inf');
  CheckTrue(IsInfinite(r.d[1]) and (r.d[1] < 0), '-Inf + 1000000 should be -Inf');

  // 测试 F64x4
  a4.d[0] := NegInfF64; a4.d[1] := NegInfF64; a4.d[2] := NegInfF64; a4.d[3] := NegInfF64;
  b4.d[0] := 0.0; b4.d[1] := MaxFiniteF64; b4.d[2] := -MaxFiniteF64; b4.d[3] := 42.0;
  r4 := ScalarAddF64x4(a4, b4);
  CheckTrue(IsInfinite(r4.d[0]) and (r4.d[0] < 0), 'F64x4: -Inf + 0 should be -Inf');
  CheckTrue(IsInfinite(r4.d[1]) and (r4.d[1] < 0), 'F64x4: -Inf + MaxFinite should be -Inf');
  CheckTrue(IsInfinite(r4.d[2]) and (r4.d[2] < 0), 'F64x4: -Inf + (-MaxFinite) should be -Inf');
  CheckTrue(IsInfinite(r4.d[3]) and (r4.d[3] < 0), 'F64x4: -Inf + 42 should be -Inf');
end;

procedure TTestCase_IEEE754_F64.Test_F64_Infinity_Mul;
var
  a, b, r: TVecF64x2;
begin
  // Inf * positive = Inf
  // Inf * negative = -Inf
  a.d[0] := PosInfF64;
  a.d[1] := PosInfF64;
  b.d[0] := 2.0;
  b.d[1] := -3.0;

  r := ScalarMulF64x2(a, b);
  CheckTrue(IsInfinite(r.d[0]) and (r.d[0] > 0), 'Inf * 2.0 should be +Inf');
  CheckTrue(IsInfinite(r.d[1]) and (r.d[1] < 0), 'Inf * (-3.0) should be -Inf');

  // 测试 -Inf * positive/negative
  a.d[0] := NegInfF64;
  a.d[1] := NegInfF64;
  b.d[0] := 2.0;
  b.d[1] := -3.0;
  r := ScalarMulF64x2(a, b);
  CheckTrue(IsInfinite(r.d[0]) and (r.d[0] < 0), '-Inf * 2.0 should be -Inf');
  CheckTrue(IsInfinite(r.d[1]) and (r.d[1] > 0), '-Inf * (-3.0) should be +Inf');

  // 特殊情况: Inf * 0 = NaN
  a.d[0] := PosInfF64;
  a.d[1] := NegInfF64;
  b.d[0] := 0.0;
  b.d[1] := 0.0;
  r := ScalarMulF64x2(a, b);
  CheckTrue(IsNaN(r.d[0]), 'Inf * 0 should be NaN');
  CheckTrue(IsNaN(r.d[1]), '-Inf * 0 should be NaN');
end;

procedure TTestCase_IEEE754_F64.Test_F64_Infinity_Div;
var
  a, b, r: TVecF64x2;
begin
  // x / Inf = 0 (对于任何有限数 x)
  a.d[0] := 1.0;
  a.d[1] := -1000000.0;
  b.d[0] := PosInfF64;
  b.d[1] := PosInfF64;

  r := ScalarDivF64x2(a, b);
  CheckNear(0.0, r.d[0], 0.0, '1.0 / Inf should be 0');
  CheckNear(0.0, Abs(r.d[1]), 0.0, '-1000000 / Inf should be 0');  // 可能是 -0

  // x / -Inf = -0 或 0 (符号取决于 x 的符号)
  b.d[0] := NegInfF64;
  b.d[1] := NegInfF64;
  a.d[0] := 1.0;
  a.d[1] := -1.0;
  r := ScalarDivF64x2(a, b);
  CheckTrue(r.d[0] = 0.0, '1.0 / -Inf should be 0 (or -0)');
  CheckTrue(r.d[1] = 0.0, '-1.0 / -Inf should be 0 (or +0)');

  // Inf / Inf = NaN
  a.d[0] := PosInfF64;
  a.d[1] := NegInfF64;
  b.d[0] := PosInfF64;
  b.d[1] := NegInfF64;
  r := ScalarDivF64x2(a, b);
  CheckTrue(IsNaN(r.d[0]), 'Inf / Inf should be NaN');
  CheckTrue(IsNaN(r.d[1]), '-Inf / -Inf should be NaN');
end;

procedure TTestCase_IEEE754_F64.Test_F64_InfinityMinusInfinity;
var
  a, b, r: TVecF64x2;
  a4, b4, r4: TVecF64x4;
begin
  // Inf - Inf = NaN
  a.d[0] := PosInfF64;
  a.d[1] := NegInfF64;
  b.d[0] := PosInfF64;
  b.d[1] := NegInfF64;

  r := ScalarSubF64x2(a, b);
  CheckTrue(IsNaN(r.d[0]), 'Inf - Inf should be NaN');
  CheckTrue(IsNaN(r.d[1]), '-Inf - (-Inf) should be NaN');

  // Inf - (-Inf) = Inf (不是 NaN)
  a.d[0] := PosInfF64;
  b.d[0] := NegInfF64;
  r := ScalarSubF64x2(a, b);
  CheckTrue(IsInfinite(r.d[0]) and (r.d[0] > 0), 'Inf - (-Inf) should be +Inf');

  // 测试 F64x4
  a4.d[0] := PosInfF64; a4.d[1] := NegInfF64; a4.d[2] := PosInfF64; a4.d[3] := NegInfF64;
  b4.d[0] := PosInfF64; b4.d[1] := NegInfF64; b4.d[2] := NegInfF64; b4.d[3] := PosInfF64;
  r4 := ScalarSubF64x4(a4, b4);
  CheckTrue(IsNaN(r4.d[0]), 'F64x4: Inf - Inf should be NaN');
  CheckTrue(IsNaN(r4.d[1]), 'F64x4: -Inf - (-Inf) should be NaN');
  CheckTrue(IsInfinite(r4.d[2]) and (r4.d[2] > 0), 'F64x4: Inf - (-Inf) should be +Inf');
  CheckTrue(IsInfinite(r4.d[3]) and (r4.d[3] < 0), 'F64x4: -Inf - Inf should be -Inf');
end;

// === NaN 测试 ===

procedure TTestCase_IEEE754_F64.Test_F64_NaN_Propagation;
var
  a, b, r: TVecF64x2;
  a4, b4, r4: TVecF64x4;
begin
  // NaN + x = NaN (NaN 传播)
  a.d[0] := NaNF64;
  a.d[1] := 1.0;
  b.d[0] := 1.0;
  b.d[1] := NaNF64;

  r := ScalarAddF64x2(a, b);
  CheckTrue(IsNaN(r.d[0]), 'NaN + 1.0 should be NaN');
  CheckTrue(IsNaN(r.d[1]), '1.0 + NaN should be NaN');

  // NaN - x = NaN
  r := ScalarSubF64x2(a, b);
  CheckTrue(IsNaN(r.d[0]), 'NaN - 1.0 should be NaN');

  // NaN * x = NaN
  a.d[0] := NaNF64;
  a.d[1] := NaNF64;
  b.d[0] := 0.0;
  b.d[1] := PosInfF64;
  r := ScalarMulF64x2(a, b);
  CheckTrue(IsNaN(r.d[0]), 'NaN * 0 should be NaN');
  CheckTrue(IsNaN(r.d[1]), 'NaN * Inf should be NaN');

  // NaN / x = NaN
  r := ScalarDivF64x2(a, b);
  CheckTrue(IsNaN(r.d[0]), 'NaN / 0 should be NaN');
  CheckTrue(IsNaN(r.d[1]), 'NaN / Inf should be NaN');

  // 测试 F64x4
  a4.d[0] := NaNF64; a4.d[1] := 1.0; a4.d[2] := NaNF64; a4.d[3] := 42.0;
  b4.d[0] := 1.0; b4.d[1] := NaNF64; b4.d[2] := NaNF64; b4.d[3] := 0.0;
  r4 := ScalarAddF64x4(a4, b4);
  CheckTrue(IsNaN(r4.d[0]), 'F64x4: NaN + 1 should be NaN');
  CheckTrue(IsNaN(r4.d[1]), 'F64x4: 1 + NaN should be NaN');
  CheckTrue(IsNaN(r4.d[2]), 'F64x4: NaN + NaN should be NaN');
  CheckNear(42.0, r4.d[3], 0.0, 'F64x4: 42 + 0 should be 42');
end;

procedure TTestCase_IEEE754_F64.Test_F64_NaN_Comparison;
var
  nanVal: Double;
begin
  // IEEE 754: NaN 与任何值比较（包括自身）都应返回 false
  nanVal := NaNF64;

  // NaN 不等于自身
  CheckFalse(nanVal = nanVal, 'NaN should not equal itself (IEEE 754)');
  CheckTrue(nanVal <> nanVal, 'NaN <> NaN should be true');

  // NaN 与其他值比较
  CheckFalse(nanVal < 0.0, 'NaN < 0 should be false');
  CheckFalse(nanVal > 0.0, 'NaN > 0 should be false');
  CheckFalse(nanVal <= 0.0, 'NaN <= 0 should be false');
  CheckFalse(nanVal >= 0.0, 'NaN >= 0 should be false');
  CheckFalse(nanVal = 0.0, 'NaN = 0 should be false');

  // NaN 与 Inf 比较
  CheckFalse(nanVal < PosInfF64, 'NaN < Inf should be false');
  CheckFalse(nanVal > NegInfF64, 'NaN > -Inf should be false');
  CheckFalse(nanVal = PosInfF64, 'NaN = Inf should be false');
end;

procedure TTestCase_IEEE754_F64.Test_F64_NaN_Min;
var
  a, b, r: TVecF64x2;
begin
  // IEEE 754: Min(NaN, x) 的行为取决于实现
  // 标准行为: 如果任一操作数是 NaN，结果应该是 NaN（或非 NaN 的那个）
  // Pascal/FPC Math.Min 会返回非 NaN 值
  a.d[0] := NaNF64;
  a.d[1] := 5.0;
  b.d[0] := 3.0;
  b.d[1] := NaNF64;

  r := ScalarMinF64x2(a, b);
  // 注意: 不同实现可能有不同行为
  // 这里验证结果不是 NaN 时应该是正确的最小值
  if not IsNaN(r.d[0]) then
    CheckNear(3.0, r.d[0], 0.0, 'Min(NaN, 3.0) if not NaN should be 3.0');
  if not IsNaN(r.d[1]) then
    CheckNear(5.0, r.d[1], 0.0, 'Min(5.0, NaN) if not NaN should be 5.0');
end;

procedure TTestCase_IEEE754_F64.Test_F64_NaN_Max;
var
  a, b, r: TVecF64x2;
begin
  // IEEE 754: Max(NaN, x) 的行为取决于实现
  a.d[0] := NaNF64;
  a.d[1] := 5.0;
  b.d[0] := 3.0;
  b.d[1] := NaNF64;

  r := ScalarMaxF64x2(a, b);
  // 验证结果不是 NaN 时应该是正确的最大值
  if not IsNaN(r.d[0]) then
    CheckNear(3.0, r.d[0], 0.0, 'Max(NaN, 3.0) if not NaN should be 3.0');
  if not IsNaN(r.d[1]) then
    CheckNear(5.0, r.d[1], 0.0, 'Max(5.0, NaN) if not NaN should be 5.0');
end;

procedure TTestCase_IEEE754_F64.Test_F64_ReduceMinMax_SpecialCases;
var
  LInput: TVecF64x2;
  LReduceMin: Double;
  LReduceMax: Double;
begin
  LInput.d[0] := NaNF64;
  LInput.d[1] := 3.0;
  LReduceMin := ScalarReduceMinF64x2(LInput);
  LReduceMax := ScalarReduceMaxF64x2(LInput);
  CheckNear(3.0, LReduceMin, 0.0, 'ReduceMin(NaN, 3.0) should match current scalar truth');
  CheckNear(3.0, LReduceMax, 0.0, 'ReduceMax(NaN, 3.0) should match current scalar truth');

  LInput.d[0] := 3.0;
  LInput.d[1] := NaNF64;
  LReduceMin := ScalarReduceMinF64x2(LInput);
  LReduceMax := ScalarReduceMaxF64x2(LInput);
  CheckTrue(IsNaNDouble(LReduceMin), 'ReduceMin(3.0, NaN) should stay NaN in the current scalar truth');
  CheckTrue(IsNaNDouble(LReduceMax), 'ReduceMax(3.0, NaN) should stay NaN in the current scalar truth');

  LInput.d[0] := 0.0;
  LInput.d[1] := NegZeroF64;
  LReduceMin := ScalarReduceMinF64x2(LInput);
  LReduceMax := ScalarReduceMaxF64x2(LInput);
  CheckTrue(BitsFromDouble(LReduceMin) = BitsFromDouble(NegZeroF64), 'ReduceMin(+0, -0) should preserve the current scalar sign bit');
  CheckTrue(BitsFromDouble(LReduceMax) = BitsFromDouble(NegZeroF64), 'ReduceMax(+0, -0) should preserve the current scalar sign bit');

  LInput.d[0] := NegZeroF64;
  LInput.d[1] := 0.0;
  LReduceMin := ScalarReduceMinF64x2(LInput);
  LReduceMax := ScalarReduceMaxF64x2(LInput);
  CheckTrue(BitsFromDouble(LReduceMin) = BitsFromDouble(0.0), 'ReduceMin(-0, +0) should preserve the current scalar sign bit');
  CheckTrue(BitsFromDouble(LReduceMax) = BitsFromDouble(0.0), 'ReduceMax(-0, +0) should preserve the current scalar sign bit');
end;

// === 负零测试 ===

procedure TTestCase_IEEE754_F64.Test_F64_NegativeZero_Add;
var
  a, b, r: TVecF64x2;
  a4, b4, r4: TVecF64x4;
begin
  // IEEE 754: -0 + 0 = +0
  a.d[0] := NegZeroF64;
  a.d[1] := 0.0;
  b.d[0] := 0.0;
  b.d[1] := NegZeroF64;

  r := ScalarAddF64x2(a, b);
  CheckNear(0.0, r.d[0], 0.0, '-0 + 0 should be 0');
  CheckNear(0.0, r.d[1], 0.0, '0 + (-0) should be 0');

  // -0 + (-0) = -0
  a.d[0] := NegZeroF64;
  b.d[0] := NegZeroF64;
  r := ScalarAddF64x2(a, b);
  CheckNear(0.0, r.d[0], 0.0, '-0 + (-0) should be 0');

  // -0 + x = x (for nonzero x)
  a.d[0] := NegZeroF64;
  b.d[0] := 5.0;
  r := ScalarAddF64x2(a, b);
  CheckNear(5.0, r.d[0], 0.0, '-0 + 5.0 should be 5.0');

  // 测试 F64x4
  a4.d[0] := NegZeroF64; a4.d[1] := 0.0; a4.d[2] := NegZeroF64; a4.d[3] := NegZeroF64;
  b4.d[0] := 0.0; b4.d[1] := NegZeroF64; b4.d[2] := 1.0; b4.d[3] := NegZeroF64;
  r4 := ScalarAddF64x4(a4, b4);
  CheckNear(0.0, r4.d[0], 0.0, 'F64x4: -0 + 0 should be 0');
  CheckNear(0.0, r4.d[1], 0.0, 'F64x4: 0 + (-0) should be 0');
  CheckNear(1.0, r4.d[2], 0.0, 'F64x4: -0 + 1 should be 1');
end;

procedure TTestCase_IEEE754_F64.Test_F64_NegativeZero_Mul;
var
  a, b, r: TVecF64x2;
  negZeroBits, resultBits: UInt64;
begin
  // IEEE 754: -0 * positive = -0
  //           -0 * negative = +0
  a.d[0] := NegZeroF64;
  a.d[1] := NegZeroF64;
  b.d[0] := 5.0;
  b.d[1] := -3.0;

  r := ScalarMulF64x2(a, b);

  // 检查 -0 * positive 的符号位
  // -0.0 的位模式是 0x8000000000000000
  negZeroBits := QWord($8000000000000000);
  Move(r.d[0], resultBits, SizeOf(UInt64));
  CheckNear(0.0, r.d[0], 0.0, '-0 * 5.0 should be -0 (check value is zero)');
  CheckEqual(negZeroBits, resultBits, '-0 * 5.0 should have negative sign bit');

  // -0 * negative = +0
  Move(r.d[1], resultBits, SizeOf(UInt64));
  CheckNear(0.0, r.d[1], 0.0, '-0 * (-3.0) should be +0 (check value is zero)');
  CheckEqual(UInt64(0), resultBits, '-0 * (-3.0) should have positive sign (bits = 0)');
end;

procedure TTestCase_IEEE754_F64.Test_F64_NegativeZero_Cmp;
begin
  // IEEE 754: -0 == +0 应为 true
  CheckTrue(NegZeroF64 = 0.0, '-0 should equal +0');
  CheckFalse(NegZeroF64 <> 0.0, '-0 should not be <> +0');

  // 比较测试
  CheckFalse(NegZeroF64 < 0.0, '-0 < +0 should be false');
  CheckFalse(NegZeroF64 > 0.0, '-0 > +0 should be false');
  CheckTrue(NegZeroF64 <= 0.0, '-0 <= +0 should be true');
  CheckTrue(NegZeroF64 >= 0.0, '-0 >= +0 should be true');
end;

// === Denormal (次正规数) 测试 ===

procedure TTestCase_IEEE754_F64.Test_F64_Denormal_Add;
var
  a, b, r: TVecF64x2;
  a4, b4, r4: TVecF64x4;
begin
  // 次正规数加法测试
  // 两个小次正规数相加
  a.d[0] := SmallestDenormalF64;
  a.d[1] := SmallestDenormalF64 * 2;
  b.d[0] := SmallestDenormalF64;
  b.d[1] := SmallestDenormalF64;

  r := ScalarAddF64x2(a, b);
  // 结果应该仍是次正规数或非常小的正规数
  CheckTrue(r.d[0] > 0, 'Denormal + Denormal should be small positive');
  CheckTrue(r.d[1] > 0, '2*Denormal + Denormal should be small positive');

  // 次正规数 + 正规数 = 正规数（次正规数被吸收）
  a.d[0] := SmallestDenormalF64;
  b.d[0] := 1.0;
  r := ScalarAddF64x2(a, b);
  CheckNear(1.0, r.d[0], 1e-15, 'Denormal + 1.0 should be approximately 1.0');

  // 测试 F64x4
  a4.d[0] := SmallestDenormalF64; a4.d[1] := SmallestDenormalF64 * 10;
  a4.d[2] := SmallestNormalF64; a4.d[3] := SmallestDenormalF64;
  b4.d[0] := SmallestDenormalF64; b4.d[1] := SmallestDenormalF64;
  b4.d[2] := SmallestDenormalF64; b4.d[3] := 0.0;
  r4 := ScalarAddF64x4(a4, b4);
  CheckTrue(r4.d[0] > 0, 'F64x4: Denormal + Denormal should be positive');
  CheckNear(SmallestDenormalF64, r4.d[3], 0.0, 'F64x4: Denormal + 0 should be Denormal');
end;

procedure TTestCase_IEEE754_F64.Test_F64_Denormal_Mul;
var
  a, b, r: TVecF64x2;
begin
  // 次正规数乘法测试
  // 次正规数 * 次正规数 可能下溢到 0
  a.d[0] := SmallestDenormalF64;
  a.d[1] := SmallestDenormalF64;
  b.d[0] := SmallestDenormalF64;
  b.d[1] := 0.5;

  r := ScalarMulF64x2(a, b);
  // Denormal * Denormal 通常下溢到 0
  CheckTrue(r.d[0] >= 0, 'Denormal * Denormal should underflow to 0 or be very small');
  CheckNear(0.0, r.d[0], SmallestDenormalF64, 'Denormal * Denormal should be 0 (underflow)');

  // 次正规数 * 0.5 可能仍是次正规数或下溢到 0
  CheckTrue(r.d[1] >= 0, 'Denormal * 0.5 should be >= 0');

  // 次正规数 * 较大正数 = 正规数或次正规数
  a.d[0] := SmallestDenormalF64;
  b.d[0] := 1e100;
  r := ScalarMulF64x2(a, b);
  CheckTrue(r.d[0] > 0, 'Denormal * 1e100 should be positive');
end;

// === 溢出/下溢测试 ===

procedure TTestCase_IEEE754_F64.Test_F64_Overflow;
var
  a, b, r: TVecF64x2;
  a4, b4, r4: TVecF64x4;
begin
  // 大数相乘产生 Inf（溢出）
  a.d[0] := MaxFiniteF64;
  a.d[1] := 1e200;
  b.d[0] := 2.0;
  b.d[1] := 1e200;

  r := ScalarMulF64x2(a, b);
  CheckTrue(IsInfinite(r.d[0]) and (r.d[0] > 0), 'MaxFinite * 2.0 should overflow to +Inf');
  CheckTrue(IsInfinite(r.d[1]) and (r.d[1] > 0), '1e200 * 1e200 should overflow to +Inf');

  // 负数溢出产生 -Inf
  a.d[0] := -MaxFiniteF64;
  b.d[0] := 2.0;
  r := ScalarMulF64x2(a, b);
  CheckTrue(IsInfinite(r.d[0]) and (r.d[0] < 0), '-MaxFinite * 2.0 should overflow to -Inf');

  // 加法溢出
  a.d[0] := MaxFiniteF64;
  b.d[0] := MaxFiniteF64;
  r := ScalarAddF64x2(a, b);
  CheckTrue(IsInfinite(r.d[0]) and (r.d[0] > 0), 'MaxFinite + MaxFinite should overflow to +Inf');

  // 测试 F64x4
  a4.d[0] := MaxFiniteF64; a4.d[1] := 1e200; a4.d[2] := -1e200; a4.d[3] := MaxFiniteF64;
  b4.d[0] := 2.0; b4.d[1] := 1e200; b4.d[2] := 1e200; b4.d[3] := MaxFiniteF64;
  r4 := ScalarMulF64x4(a4, b4);
  CheckTrue(IsInfinite(r4.d[0]) and (r4.d[0] > 0), 'F64x4: MaxFinite * 2 should be +Inf');
  CheckTrue(IsInfinite(r4.d[1]) and (r4.d[1] > 0), 'F64x4: 1e200 * 1e200 should be +Inf');
  CheckTrue(IsInfinite(r4.d[2]) and (r4.d[2] < 0), 'F64x4: -1e200 * 1e200 should be -Inf');
  CheckTrue(IsInfinite(r4.d[3]) and (r4.d[3] > 0), 'F64x4: MaxFinite * MaxFinite should be +Inf');
end;

procedure TTestCase_IEEE754_F64.Test_F64_Underflow;
var
  a, b, r: TVecF64x2;
  a4, b4, r4: TVecF64x4;
begin
  // 小数相乘产生 0 或 denormal（下溢）
  a.d[0] := SmallestNormalF64;
  a.d[1] := 1e-200;
  b.d[0] := SmallestNormalF64;
  b.d[1] := 1e-200;

  r := ScalarMulF64x2(a, b);
  // SmallestNormal * SmallestNormal 应该下溢到 0 或 denormal
  CheckTrue((r.d[0] = 0.0) or (r.d[0] < SmallestNormalF64), 'SmallestNormal * SmallestNormal should underflow to 0 or denormal');
  CheckTrue((r.d[1] = 0.0) or (r.d[1] < SmallestNormalF64), '1e-200 * 1e-200 should underflow');

  // 除法下溢
  a.d[0] := SmallestNormalF64;
  b.d[0] := 1e308;
  r := ScalarDivF64x2(a, b);
  CheckTrue((r.d[0] = 0.0) or (r.d[0] < SmallestNormalF64), 'SmallestNormal / 1e308 should underflow');

  // 测试 F64x4
  a4.d[0] := SmallestNormalF64; a4.d[1] := 1e-200; a4.d[2] := SmallestDenormalF64; a4.d[3] := 1e-300;
  b4.d[0] := 1e-100; b4.d[1] := 1e-200; b4.d[2] := 0.1; b4.d[3] := 1e-100;
  r4 := ScalarMulF64x4(a4, b4);
  // 验证结果是 0 或非常小的正数
  CheckTrue(r4.d[0] >= 0, 'F64x4: Underflow results should be >= 0');
  CheckTrue(r4.d[1] >= 0, 'F64x4: Underflow results should be >= 0');
  CheckTrue(r4.d[2] >= 0, 'F64x4: Denormal * 0.1 should be >= 0');
  CheckTrue(r4.d[3] >= 0, 'F64x4: 1e-300 * 1e-100 should be >= 0');
end;

{ TTestCase_IEEE754EdgeCases - IEEE 754 特殊值边界测试 }

const
  // F32 特殊值常量
  PosInfF32: Single = 1.0 / 0.0;
  NegInfF32: Single = -1.0 / 0.0;
  NaNF32: Single = 0.0 / 0.0;
  NegZeroF32: Single = -0.0;

// === NaN 传播测试 (F32x4) ===

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_NaN_Add;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // NaN + x = NaN (IEEE 754 规定 NaN 传播)
  a := VecF32x4Splat(NaNF32);
  b := VecF32x4Splat(1.0);

  r := VecF32x4Add(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), 'NaN + 1.0 should be NaN [' + IntToStr(i) + ']');

  // x + NaN = NaN
  a := VecF32x4Splat(2.5);
  b := VecF32x4Splat(NaNF32);
  r := VecF32x4Add(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), '2.5 + NaN should be NaN [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_NaN_Sub;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // NaN - x = NaN
  a := VecF32x4Splat(NaNF32);
  b := VecF32x4Splat(5.0);
  r := VecF32x4Sub(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), 'NaN - 5.0 should be NaN [' + IntToStr(i) + ']');

  // x - NaN = NaN
  a := VecF32x4Splat(10.0);
  b := VecF32x4Splat(NaNF32);
  r := VecF32x4Sub(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), '10.0 - NaN should be NaN [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_NaN_Mul;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // NaN * x = NaN
  a := VecF32x4Splat(NaNF32);
  b := VecF32x4Splat(3.0);
  r := VecF32x4Mul(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), 'NaN * 3.0 should be NaN [' + IntToStr(i) + ']');

  // x * NaN = NaN
  a := VecF32x4Splat(7.0);
  b := VecF32x4Splat(NaNF32);
  r := VecF32x4Mul(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), '7.0 * NaN should be NaN [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_NaN_Div;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // NaN / x = NaN
  a := VecF32x4Splat(NaNF32);
  b := VecF32x4Splat(2.0);
  r := VecF32x4Div(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), 'NaN / 2.0 should be NaN [' + IntToStr(i) + ']');

  // x / NaN = NaN
  a := VecF32x4Splat(8.0);
  b := VecF32x4Splat(NaNF32);
  r := VecF32x4Div(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), '8.0 / NaN should be NaN [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_NaN_Min;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // IEEE 754: Min(NaN, x) 行为取决于实现
  // 大多数实现返回 NaN 或 x，测试确保不崩溃
  a := VecF32x4Splat(NaNF32);
  b := VecF32x4Splat(1.0);

  r := VecF32x4Min(a, b);

  // 验证结果是 NaN 或 1.0（取决于实现）
  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]) or (Abs(r.f[i] - 1.0) < 1e-6), 'Min(NaN, 1.0) should be NaN or 1.0 [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_NaN_Max;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // IEEE 754: Max(NaN, x) 行为取决于实现
  a := VecF32x4Splat(NaNF32);
  b := VecF32x4Splat(5.0);

  r := VecF32x4Max(a, b);

  // 验证结果是 NaN 或 5.0（取决于实现）
  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]) or (Abs(r.f[i] - 5.0) < 1e-6), 'Max(NaN, 5.0) should be NaN or 5.0 [' + IntToStr(i) + ']');
end;

// === Infinity 测试 (F32x4) ===

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_Inf_Add;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // Inf + x = Inf (x 为有限数)
  a := VecF32x4Splat(PosInfF32);
  b := VecF32x4Splat(100.0);
  r := VecF32x4Add(a, b);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.f[i]) and (r.f[i] > 0), 'Inf + 100.0 should be Inf [' + IntToStr(i) + ']');

  // -Inf + x = -Inf
  a := VecF32x4Splat(NegInfF32);
  b := VecF32x4Splat(50.0);
  r := VecF32x4Add(a, b);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.f[i]) and (r.f[i] < 0), '-Inf + 50.0 should be -Inf [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_Inf_Sub;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // Inf - Inf = NaN (未定义操作)
  a := VecF32x4Splat(PosInfF32);
  b := VecF32x4Splat(PosInfF32);
  r := VecF32x4Sub(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), 'Inf - Inf should be NaN [' + IntToStr(i) + ']');

  // -Inf - (-Inf) = NaN
  a := VecF32x4Splat(NegInfF32);
  b := VecF32x4Splat(NegInfF32);
  r := VecF32x4Sub(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), '-Inf - (-Inf) should be NaN [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_Inf_Mul;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // Inf * 0 = NaN (未定义操作)
  a := VecF32x4Splat(PosInfF32);
  b := VecF32x4Splat(0.0);
  r := VecF32x4Mul(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), 'Inf * 0 should be NaN [' + IntToStr(i) + ']');

  // Inf * positive = Inf
  a := VecF32x4Splat(PosInfF32);
  b := VecF32x4Splat(5.0);
  r := VecF32x4Mul(a, b);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.f[i]) and (r.f[i] > 0), 'Inf * 5.0 should be Inf [' + IntToStr(i) + ']');

  // Inf * negative = -Inf
  a := VecF32x4Splat(PosInfF32);
  b := VecF32x4Splat(-3.0);
  r := VecF32x4Mul(a, b);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.f[i]) and (r.f[i] < 0), 'Inf * (-3.0) should be -Inf [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_Inf_Div;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // x / Inf = 0 (有限数除以无穷大)
  a := VecF32x4Splat(100.0);
  b := VecF32x4Splat(PosInfF32);
  r := VecF32x4Div(a, b);

  for i := 0 to 3 do
    CheckNear(0.0, r.f[i], 1e-10, '100.0 / Inf should be 0 [' + IntToStr(i) + ']');

  // Inf / Inf = NaN
  a := VecF32x4Splat(PosInfF32);
  b := VecF32x4Splat(PosInfF32);
  r := VecF32x4Div(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), 'Inf / Inf should be NaN [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_NegInf;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // -Inf + x = -Inf
  a := VecF32x4Splat(NegInfF32);
  b := VecF32x4Splat(1000.0);
  r := VecF32x4Add(a, b);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.f[i]) and (r.f[i] < 0), '-Inf + 1000.0 should be -Inf [' + IntToStr(i) + ']');

  // -Inf * positive = -Inf
  a := VecF32x4Splat(NegInfF32);
  b := VecF32x4Splat(2.0);
  r := VecF32x4Mul(a, b);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.f[i]) and (r.f[i] < 0), '-Inf * 2.0 should be -Inf [' + IntToStr(i) + ']');

  // -Inf * negative = Inf
  a := VecF32x4Splat(NegInfF32);
  b := VecF32x4Splat(-4.0);
  r := VecF32x4Mul(a, b);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.f[i]) and (r.f[i] > 0), '-Inf * (-4.0) should be Inf [' + IntToStr(i) + ']');
end;

// === 零值测试 (F32x4) ===

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_Zero_Div;
var
  a, b, r: TVecF32x4;
  i: Integer;
begin
  // x / 0 = ±Inf (正数除以零)
  a := VecF32x4Splat(1.0);
  b := VecF32x4Splat(0.0);
  r := VecF32x4Div(a, b);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.f[i]) and (r.f[i] > 0), '1.0 / 0 should be +Inf [' + IntToStr(i) + ']');

  // -x / 0 = -Inf (负数除以零)
  a := VecF32x4Splat(-1.0);
  b := VecF32x4Splat(0.0);
  r := VecF32x4Div(a, b);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.f[i]) and (r.f[i] < 0), '(-1.0) / 0 should be -Inf [' + IntToStr(i) + ']');

  // 0 / 0 = NaN
  a := VecF32x4Splat(0.0);
  b := VecF32x4Splat(0.0);
  r := VecF32x4Div(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), '0 / 0 should be NaN [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_NegZero;
var
  a, b, r: TVecF32x4;
  mask: TMask4;
  i: Integer;
begin
  // -0 + 0 = +0 (IEEE 754 规定)
  a := VecF32x4Splat(NegZeroF32);
  b := VecF32x4Splat(0.0);
  r := VecF32x4Add(a, b);

  for i := 0 to 3 do
    CheckNear(0.0, r.f[i], 0.0, '(-0) + 0 should be 0 [' + IntToStr(i) + ']');

  // -0 * positive = -0
  a := VecF32x4Splat(NegZeroF32);
  b := VecF32x4Splat(5.0);
  r := VecF32x4Mul(a, b);

  for i := 0 to 3 do
  begin
    CheckNear(0.0, r.f[i], 0.0, '(-0) * 5.0 should be -0 [' + IntToStr(i) + ']');
    // 验证符号位（通过除法检查）
    CheckTrue(IsInfinite(1.0 / r.f[i]) and ((1.0 / r.f[i]) < 0), 'Result should be -0 (negative zero) [' + IntToStr(i) + ']');
  end;

  // -0 == 0 比较应为 true
  a := VecF32x4Splat(NegZeroF32);
  b := VecF32x4Splat(0.0);
  mask := VecF32x4CmpEq(a, b);

  // 验证掩码表示相等（所有 4 位都设置）
  CheckTrue(mask = MASK4_ALL_SET, '(-0) == 0 should be true (all bits set)');
end;

// === 舍入边界测试 (F32x4) ===

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_Floor_NaN;
var
  a, r: TVecF32x4;
  i: Integer;
begin
  // Floor(NaN) = NaN
  a := VecF32x4Splat(NaNF32);
  r := VecF32x4Floor(a);

  for i := 0 to 3 do
    CheckTrue(IsNaNSingle(r.f[i]), 'Floor(NaN) should be NaN [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_Ceil_Inf;
var
  a, r: TVecF32x4;
  i: Integer;
begin
  // Ceil(Inf) = Inf
  a := VecF32x4Splat(PosInfF32);
  r := VecF32x4Ceil(a);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.f[i]) and (r.f[i] > 0), 'Ceil(Inf) should be Inf [' + IntToStr(i) + ']');

  // Ceil(-Inf) = -Inf
  a := VecF32x4Splat(NegInfF32);
  r := VecF32x4Ceil(a);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.f[i]) and (r.f[i] < 0), 'Ceil(-Inf) should be -Inf [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_Round_LargeValue;
var
  a, r: TVecF32x4;
  i: Integer;
  largeValue: Single;
begin
  // 测试大数舍入（超过 2^23，单精度整数精度限制）
  largeValue := 16777216.0; // 2^24，超过单精度整数精度
  a := VecF32x4Splat(largeValue);
  r := VecF32x4Round(a);

  for i := 0 to 3 do
    CheckNear(largeValue, r.f[i], 0.0, 'Round(large value) should preserve value [' + IntToStr(i) + ']');

  // 测试接近最大有限值的舍入
  largeValue := 3.4e38; // 接近 F32 最大值
  a := VecF32x4Splat(largeValue);
  r := VecF32x4Round(a);

  for i := 0 to 3 do
    CheckTrue(not IsInfinite(r.f[i]), 'Round(max value) should not overflow to Inf [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_RoundTrunc_NaNInf_Scalar;
var
  a, rRound, rTrunc: TVecF32x4;
begin
  SetActiveBackend(sbScalar);
  a.f[0] := NaNF32;
  a.f[1] := PosInfF32;
  a.f[2] := NegInfF32;
  a.f[3] := -1.75;

  rRound := VecF32x4Round(a);
  rTrunc := VecF32x4Trunc(a);

  CheckTrue(IsNaNSingle(rRound.f[0]), 'Scalar Round(NaN) should stay NaN');
  CheckTrue(IsInfinite(rRound.f[1]) and (rRound.f[1] > 0), 'Scalar Round(+Inf) should stay +Inf');
  CheckTrue(IsInfinite(rRound.f[2]) and (rRound.f[2] < 0), 'Scalar Round(-Inf) should stay -Inf');
  CheckNear(-2.0, rRound.f[3], 0.0, 'Scalar Round(-1.75)');

  CheckTrue(IsNaNSingle(rTrunc.f[0]), 'Scalar Trunc(NaN) should stay NaN');
  CheckTrue(IsInfinite(rTrunc.f[1]) and (rTrunc.f[1] > 0), 'Scalar Trunc(+Inf) should stay +Inf');
  CheckTrue(IsInfinite(rTrunc.f[2]) and (rTrunc.f[2] < 0), 'Scalar Trunc(-Inf) should stay -Inf');
  CheckNear(-1.0, rTrunc.f[3], 0.0, 'Scalar Trunc(-1.75)');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x4_RoundTrunc_NaNInf_SSE2;
var
  a, rRound, rTrunc: TVecF32x4;
begin
  if not IsBackendRegistered(sbSSE2) then
    Exit;

  SetVectorAsmEnabled(True);
  SetActiveBackend(sbSSE2);
  a.f[0] := NaNF32;
  a.f[1] := PosInfF32;
  a.f[2] := NegInfF32;
  a.f[3] := -1.75;

  rRound := VecF32x4Round(a);
  rTrunc := VecF32x4Trunc(a);

  CheckTrue(IsNaNSingle(rRound.f[0]), 'SSE2 Round(NaN) should stay NaN');
  CheckTrue(IsInfinite(rRound.f[1]) and (rRound.f[1] > 0), 'SSE2 Round(+Inf) should stay +Inf');
  CheckTrue(IsInfinite(rRound.f[2]) and (rRound.f[2] < 0), 'SSE2 Round(-Inf) should stay -Inf');
  CheckNear(-2.0, rRound.f[3], 0.0, 'SSE2 Round(-1.75)');

  CheckTrue(IsNaNSingle(rTrunc.f[0]), 'SSE2 Trunc(NaN) should stay NaN');
  CheckTrue(IsInfinite(rTrunc.f[1]) and (rTrunc.f[1] > 0), 'SSE2 Trunc(+Inf) should stay +Inf');
  CheckTrue(IsInfinite(rTrunc.f[2]) and (rTrunc.f[2] < 0), 'SSE2 Trunc(-Inf) should stay -Inf');
  CheckNear(-1.0, rTrunc.f[3], 0.0, 'SSE2 Trunc(-1.75)');
end;

procedure TTestCase_IEEE754EdgeCases.Test_Wide_RoundTrunc_NaNInf_Scalar;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;

  LInF32x8, LRoundF32x8, LTruncF32x8: TVecF32x8;
  LInF32x16, LRoundF32x16, LTruncF32x16: TVecF32x16;

  LInF64x2, LRoundF64x2, LTruncF64x2: TVecF64x2;
  LInF64x4, LRoundF64x4, LTruncF64x4: TVecF64x4;
  LInF64x8, LRoundF64x8, LTruncF64x8: TVecF64x8;

  procedure AssertSingleLane(const aPrefix: string; aLane: Integer; const aRound, aTrunc: Single);
  begin
    case (aLane mod 8) of
      0:
      begin
        CheckTrue(IsNaNSingle(aRound), aPrefix + ' Round(NaN)');
        CheckTrue(IsNaNSingle(aTrunc), aPrefix + ' Trunc(NaN)');
      end;
      1:
      begin
        CheckTrue(IsInfinite(aRound) and (aRound > 0), aPrefix + ' Round(+Inf)');
        CheckTrue(IsInfinite(aTrunc) and (aTrunc > 0), aPrefix + ' Trunc(+Inf)');
      end;
      2:
      begin
        CheckTrue(IsInfinite(aRound) and (aRound < 0), aPrefix + ' Round(-Inf)');
        CheckTrue(IsInfinite(aTrunc) and (aTrunc < 0), aPrefix + ' Trunc(-Inf)');
      end;
      3:
      begin
        CheckNear(2.0, aRound, 0.0, aPrefix + ' Round(1.75)');
        CheckNear(1.0, aTrunc, 0.0, aPrefix + ' Trunc(1.75)');
      end;
      4:
      begin
        CheckNear(-2.0, aRound, 0.0, aPrefix + ' Round(-1.75)');
        CheckNear(-1.0, aTrunc, 0.0, aPrefix + ' Trunc(-1.75)');
      end;
      5:
      begin
        CheckNear(0.0, aRound, 0.0, aPrefix + ' Round(0.0)');
        CheckNear(0.0, aTrunc, 0.0, aPrefix + ' Trunc(0.0)');
      end;
      6:
      begin
        CheckNear(123457.0, aRound, 0.0, aPrefix + ' Round(123456.75)');
        CheckNear(123456.0, aTrunc, 0.0, aPrefix + ' Trunc(123456.75)');
      end;
      7:
      begin
        CheckNear(-123457.0, aRound, 0.0, aPrefix + ' Round(-123456.75)');
        CheckNear(-123456.0, aTrunc, 0.0, aPrefix + ' Trunc(-123456.75)');
      end;
    end;
  end;

  procedure AssertDoubleLane(const aPrefix: string; aLane: Integer; const aRound, aTrunc: Double);
  begin
    case (aLane mod 6) of
      0:
      begin
        CheckTrue(IsNaNDouble(aRound), aPrefix + ' Round(NaN)');
        CheckTrue(IsNaNDouble(aTrunc), aPrefix + ' Trunc(NaN)');
      end;
      1:
      begin
        CheckTrue(IsInfinite(aRound) and (aRound > 0), aPrefix + ' Round(+Inf)');
        CheckTrue(IsInfinite(aTrunc) and (aTrunc > 0), aPrefix + ' Trunc(+Inf)');
      end;
      2:
      begin
        CheckTrue(IsInfinite(aRound) and (aRound < 0), aPrefix + ' Round(-Inf)');
        CheckTrue(IsInfinite(aTrunc) and (aTrunc < 0), aPrefix + ' Trunc(-Inf)');
      end;
      3:
      begin
        CheckNear(3.0, aRound, 0.0, aPrefix + ' Round(2.75)');
        CheckNear(2.0, aTrunc, 0.0, aPrefix + ' Trunc(2.75)');
      end;
      4:
      begin
        CheckNear(-3.0, aRound, 0.0, aPrefix + ' Round(-2.75)');
        CheckNear(-2.0, aTrunc, 0.0, aPrefix + ' Trunc(-2.75)');
      end;
      5:
      begin
        CheckNear(1000001.0, aRound, 0.0, aPrefix + ' Round(1000000.75)');
        CheckNear(1000000.0, aTrunc, 0.0, aPrefix + ' Trunc(1000000.75)');
      end;
    end;
  end;

begin
  SetActiveBackend(sbScalar);
  LDispatch := GetDispatchTable;
  CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4), 'Scalar dispatch for wide Round/Trunc should exist');

  for LIndex := 0 to 7 do
  begin
    case (LIndex mod 8) of
      0: LInF32x8.f[LIndex] := NaNF32;
      1: LInF32x8.f[LIndex] := PosInfF32;
      2: LInF32x8.f[LIndex] := NegInfF32;
      3: LInF32x8.f[LIndex] := 1.75;
      4: LInF32x8.f[LIndex] := -1.75;
      5: LInF32x8.f[LIndex] := 0.0;
      6: LInF32x8.f[LIndex] := 123456.75;
    else
      LInF32x8.f[LIndex] := -123456.75;
    end;
  end;

  LRoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
  LTruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
  for LIndex := 0 to 7 do
    AssertSingleLane('Scalar F32x8[' + IntToStr(LIndex) + ']', LIndex, LRoundF32x8.f[LIndex], LTruncF32x8.f[LIndex]);

  for LIndex := 0 to 15 do
    LInF32x16.f[LIndex] := LInF32x8.f[LIndex mod 8];

  LRoundF32x16 := VecF32x16Round(LInF32x16);
  LTruncF32x16 := VecF32x16Trunc(LInF32x16);
  for LIndex := 0 to 15 do
    AssertSingleLane('Scalar F32x16[' + IntToStr(LIndex) + ']', LIndex, LRoundF32x16.f[LIndex], LTruncF32x16.f[LIndex]);

  for LIndex := 0 to 1 do
    case (LIndex mod 6) of
      0: LInF64x2.d[LIndex] := NaNF64;
      1: LInF64x2.d[LIndex] := PosInfF64;
      2: LInF64x2.d[LIndex] := NegInfF64;
      3: LInF64x2.d[LIndex] := 2.75;
      4: LInF64x2.d[LIndex] := -2.75;
    else
      LInF64x2.d[LIndex] := 1000000.75;
    end;

  LRoundF64x2 := VecF64x2Round(LInF64x2);
  LTruncF64x2 := VecF64x2Trunc(LInF64x2);
  for LIndex := 0 to 1 do
    AssertDoubleLane('Scalar F64x2[' + IntToStr(LIndex) + ']', LIndex, LRoundF64x2.d[LIndex], LTruncF64x2.d[LIndex]);

  for LIndex := 0 to 3 do
    case (LIndex mod 6) of
      0: LInF64x4.d[LIndex] := NaNF64;
      1: LInF64x4.d[LIndex] := PosInfF64;
      2: LInF64x4.d[LIndex] := NegInfF64;
      3: LInF64x4.d[LIndex] := 2.75;
      4: LInF64x4.d[LIndex] := -2.75;
    else
      LInF64x4.d[LIndex] := 1000000.75;
    end;

  LRoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
  LTruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
  for LIndex := 0 to 3 do
    AssertDoubleLane('Scalar F64x4[' + IntToStr(LIndex) + ']', LIndex, LRoundF64x4.d[LIndex], LTruncF64x4.d[LIndex]);

  for LIndex := 0 to 7 do
    case (LIndex mod 6) of
      0: LInF64x8.d[LIndex] := NaNF64;
      1: LInF64x8.d[LIndex] := PosInfF64;
      2: LInF64x8.d[LIndex] := NegInfF64;
      3: LInF64x8.d[LIndex] := 2.75;
      4: LInF64x8.d[LIndex] := -2.75;
    else
      LInF64x8.d[LIndex] := 1000000.75;
    end;

  LRoundF64x8 := VecF64x8Round(LInF64x8);
  LTruncF64x8 := VecF64x8Trunc(LInF64x8);
  for LIndex := 0 to 7 do
    AssertDoubleLane('Scalar F64x8[' + IntToStr(LIndex) + ']', LIndex, LRoundF64x8.d[LIndex], LTruncF64x8.d[LIndex]);
end;

procedure TTestCase_IEEE754EdgeCases.Test_Wide_RoundTrunc_NaNInf_SSE2;
var
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;

  LInF32x8, LRoundF32x8, LTruncF32x8: TVecF32x8;
  LInF32x16, LRoundF32x16, LTruncF32x16: TVecF32x16;

  LInF64x2, LRoundF64x2, LTruncF64x2: TVecF64x2;
  LInF64x4, LRoundF64x4, LTruncF64x4: TVecF64x4;
  LInF64x8, LRoundF64x8, LTruncF64x8: TVecF64x8;

  procedure AssertSingleLane(const aPrefix: string; aLane: Integer; const aRound, aTrunc: Single);
  begin
    case (aLane mod 8) of
      0:
      begin
        CheckTrue(IsNaNSingle(aRound), aPrefix + ' Round(NaN)');
        CheckTrue(IsNaNSingle(aTrunc), aPrefix + ' Trunc(NaN)');
      end;
      1:
      begin
        CheckTrue(IsInfinite(aRound) and (aRound > 0), aPrefix + ' Round(+Inf)');
        CheckTrue(IsInfinite(aTrunc) and (aTrunc > 0), aPrefix + ' Trunc(+Inf)');
      end;
      2:
      begin
        CheckTrue(IsInfinite(aRound) and (aRound < 0), aPrefix + ' Round(-Inf)');
        CheckTrue(IsInfinite(aTrunc) and (aTrunc < 0), aPrefix + ' Trunc(-Inf)');
      end;
      3:
      begin
        CheckNear(2.0, aRound, 0.0, aPrefix + ' Round(1.75)');
        CheckNear(1.0, aTrunc, 0.0, aPrefix + ' Trunc(1.75)');
      end;
      4:
      begin
        CheckNear(-2.0, aRound, 0.0, aPrefix + ' Round(-1.75)');
        CheckNear(-1.0, aTrunc, 0.0, aPrefix + ' Trunc(-1.75)');
      end;
      5:
      begin
        CheckNear(0.0, aRound, 0.0, aPrefix + ' Round(0.0)');
        CheckNear(0.0, aTrunc, 0.0, aPrefix + ' Trunc(0.0)');
      end;
      6:
      begin
        CheckNear(123457.0, aRound, 0.0, aPrefix + ' Round(123456.75)');
        CheckNear(123456.0, aTrunc, 0.0, aPrefix + ' Trunc(123456.75)');
      end;
      7:
      begin
        CheckNear(-123457.0, aRound, 0.0, aPrefix + ' Round(-123456.75)');
        CheckNear(-123456.0, aTrunc, 0.0, aPrefix + ' Trunc(-123456.75)');
      end;
    end;
  end;

  procedure AssertDoubleLane(const aPrefix: string; aLane: Integer; const aRound, aTrunc: Double);
  begin
    case (aLane mod 6) of
      0:
      begin
        CheckTrue(IsNaNDouble(aRound), aPrefix + ' Round(NaN)');
        CheckTrue(IsNaNDouble(aTrunc), aPrefix + ' Trunc(NaN)');
      end;
      1:
      begin
        CheckTrue(IsInfinite(aRound) and (aRound > 0), aPrefix + ' Round(+Inf)');
        CheckTrue(IsInfinite(aTrunc) and (aTrunc > 0), aPrefix + ' Trunc(+Inf)');
      end;
      2:
      begin
        CheckTrue(IsInfinite(aRound) and (aRound < 0), aPrefix + ' Round(-Inf)');
        CheckTrue(IsInfinite(aTrunc) and (aTrunc < 0), aPrefix + ' Trunc(-Inf)');
      end;
      3:
      begin
        CheckNear(3.0, aRound, 0.0, aPrefix + ' Round(2.75)');
        CheckNear(2.0, aTrunc, 0.0, aPrefix + ' Trunc(2.75)');
      end;
      4:
      begin
        CheckNear(-3.0, aRound, 0.0, aPrefix + ' Round(-2.75)');
        CheckNear(-2.0, aTrunc, 0.0, aPrefix + ' Trunc(-2.75)');
      end;
      5:
      begin
        CheckNear(1000001.0, aRound, 0.0, aPrefix + ' Round(1000000.75)');
        CheckNear(1000000.0, aTrunc, 0.0, aPrefix + ' Trunc(1000000.75)');
      end;
    end;
  end;

begin
  if not IsBackendRegistered(sbSSE2) then
    Exit;

  SetVectorAsmEnabled(True);
  SetActiveBackend(sbSSE2);
  LDispatch := GetDispatchTable;
  CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4), 'SSE2 dispatch for wide Round/Trunc should exist');

  for LIndex := 0 to 7 do
  begin
    case (LIndex mod 8) of
      0: LInF32x8.f[LIndex] := NaNF32;
      1: LInF32x8.f[LIndex] := PosInfF32;
      2: LInF32x8.f[LIndex] := NegInfF32;
      3: LInF32x8.f[LIndex] := 1.75;
      4: LInF32x8.f[LIndex] := -1.75;
      5: LInF32x8.f[LIndex] := 0.0;
      6: LInF32x8.f[LIndex] := 123456.75;
    else
      LInF32x8.f[LIndex] := -123456.75;
    end;
  end;

  LRoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
  LTruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
  for LIndex := 0 to 7 do
    AssertSingleLane('SSE2 F32x8[' + IntToStr(LIndex) + ']', LIndex, LRoundF32x8.f[LIndex], LTruncF32x8.f[LIndex]);

  for LIndex := 0 to 15 do
    LInF32x16.f[LIndex] := LInF32x8.f[LIndex mod 8];

  LRoundF32x16 := VecF32x16Round(LInF32x16);
  LTruncF32x16 := VecF32x16Trunc(LInF32x16);
  for LIndex := 0 to 15 do
    AssertSingleLane('SSE2 F32x16[' + IntToStr(LIndex) + ']', LIndex, LRoundF32x16.f[LIndex], LTruncF32x16.f[LIndex]);

  for LIndex := 0 to 1 do
    case (LIndex mod 6) of
      0: LInF64x2.d[LIndex] := NaNF64;
      1: LInF64x2.d[LIndex] := PosInfF64;
      2: LInF64x2.d[LIndex] := NegInfF64;
      3: LInF64x2.d[LIndex] := 2.75;
      4: LInF64x2.d[LIndex] := -2.75;
    else
      LInF64x2.d[LIndex] := 1000000.75;
    end;

  LRoundF64x2 := VecF64x2Round(LInF64x2);
  LTruncF64x2 := VecF64x2Trunc(LInF64x2);
  for LIndex := 0 to 1 do
    AssertDoubleLane('SSE2 F64x2[' + IntToStr(LIndex) + ']', LIndex, LRoundF64x2.d[LIndex], LTruncF64x2.d[LIndex]);

  for LIndex := 0 to 3 do
    case (LIndex mod 6) of
      0: LInF64x4.d[LIndex] := NaNF64;
      1: LInF64x4.d[LIndex] := PosInfF64;
      2: LInF64x4.d[LIndex] := NegInfF64;
      3: LInF64x4.d[LIndex] := 2.75;
      4: LInF64x4.d[LIndex] := -2.75;
    else
      LInF64x4.d[LIndex] := 1000000.75;
    end;

  LRoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
  LTruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
  for LIndex := 0 to 3 do
    AssertDoubleLane('SSE2 F64x4[' + IntToStr(LIndex) + ']', LIndex, LRoundF64x4.d[LIndex], LTruncF64x4.d[LIndex]);

  for LIndex := 0 to 7 do
    case (LIndex mod 6) of
      0: LInF64x8.d[LIndex] := NaNF64;
      1: LInF64x8.d[LIndex] := PosInfF64;
      2: LInF64x8.d[LIndex] := NegInfF64;
      3: LInF64x8.d[LIndex] := 2.75;
      4: LInF64x8.d[LIndex] := -2.75;
    else
      LInF64x8.d[LIndex] := 1000000.75;
    end;

  LRoundF64x8 := VecF64x8Round(LInF64x8);
  LTruncF64x8 := VecF64x8Trunc(LInF64x8);
  for LIndex := 0 to 7 do
    AssertDoubleLane('SSE2 F64x8[' + IntToStr(LIndex) + ']', LIndex, LRoundF64x8.d[LIndex], LTruncF64x8.d[LIndex]);
end;

// === 256-bit 向量特殊值测试 ===

procedure TTestCase_IEEE754EdgeCases.Test_F32x8_NaN_Propagation;
var
  a, b, r: TVecF32x8;
  i: Integer;
begin
  // NaN 在 256-bit 向量中的传播
  for i := 0 to 7 do
  begin
    a.f[i] := NaNF32;
    b.f[i] := 1.0;
  end;

  r := VecF32x8Add(a, b);

  for i := 0 to 7 do
    CheckTrue(IsNaNSingle(r.f[i]), 'F32x8: NaN + 1.0 should be NaN [' + IntToStr(i) + ']');

  // 混合 NaN 和正常值
  a.f[0] := 1.0;
  a.f[1] := NaNF32;
  a.f[2] := 2.0;
  a.f[3] := NaNF32;
  a.f[4] := 3.0;
  a.f[5] := NaNF32;
  a.f[6] := 4.0;
  a.f[7] := NaNF32;

  for i := 0 to 7 do
    b.f[i] := 10.0;
  r := VecF32x8Mul(a, b);

  CheckNear(10.0, r.f[0], 1e-6, 'F32x8: 1.0 * 10.0 [0]');
  CheckTrue(IsNaNSingle(r.f[1]), 'F32x8: NaN * 10.0 [1]');
  CheckNear(20.0, r.f[2], 1e-6, 'F32x8: 2.0 * 10.0 [2]');
  CheckTrue(IsNaNSingle(r.f[3]), 'F32x8: NaN * 10.0 [3]');
  CheckNear(30.0, r.f[4], 1e-6, 'F32x8: 3.0 * 10.0 [4]');
  CheckTrue(IsNaNSingle(r.f[5]), 'F32x8: NaN * 10.0 [5]');
  CheckNear(40.0, r.f[6], 1e-6, 'F32x8: 4.0 * 10.0 [6]');
  CheckTrue(IsNaNSingle(r.f[7]), 'F32x8: NaN * 10.0 [7]');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F64x4_Inf_Handling;
var
  a, b, r: TVecF64x4;
  i: Integer;
begin
  // Infinity 在 256-bit 双精度向量中的处理
  for i := 0 to 3 do
  begin
    a.d[i] := PosInfF64;
    b.d[i] := 100.0;
  end;

  r := VecF64x4Add(a, b);

  for i := 0 to 3 do
    CheckTrue(IsInfinite(r.d[i]) and (r.d[i] > 0), 'F64x4: Inf + 100.0 should be Inf [' + IntToStr(i) + ']');

  // Inf - Inf = NaN
  for i := 0 to 3 do
  begin
    a.d[i] := PosInfF64;
    b.d[i] := PosInfF64;
  end;
  r := VecF64x4Sub(a, b);

  for i := 0 to 3 do
    CheckTrue(IsNaNDouble(r.d[i]), 'F64x4: Inf - Inf should be NaN [' + IntToStr(i) + ']');
end;

procedure TTestCase_IEEE754EdgeCases.Test_F32x8_Mixed_Special;
var
  a, b, r: TVecF32x8;
  i: Integer;
begin
  // 混合正常值、NaN、Infinity、零值
  a.f[0] := 1.0;          // 正常值
  a.f[1] := NaNF32;       // NaN
  a.f[2] := PosInfF32;    // +Inf
  a.f[3] := NegInfF32;    // -Inf
  a.f[4] := 0.0;          // +0
  a.f[5] := NegZeroF32;   // -0
  a.f[6] := -5.0;         // 负数
  a.f[7] := 1e-10;        // 小数

  for i := 0 to 7 do
    b.f[i] := 2.0;
  r := VecF32x8Mul(a, b);

  // 验证每个元素的行为
  CheckNear(2.0, r.f[0], 1e-6, '1.0 * 2.0');
  CheckTrue(IsNaNSingle(r.f[1]), 'NaN * 2.0');
  CheckTrue(IsInfinite(r.f[2]) and (r.f[2] > 0), 'Inf * 2.0');
  CheckTrue(IsInfinite(r.f[3]) and (r.f[3] < 0), '-Inf * 2.0');
  CheckNear(0.0, r.f[4], 0.0, '0.0 * 2.0');
  CheckNear(0.0, r.f[5], 0.0, '(-0) * 2.0');
  CheckNear(-10.0, r.f[6], 1e-6, '(-5.0) * 2.0');
  CheckNear(2e-10, r.f[7], 1e-15, '1e-10 * 2.0');
end;

// === 512-bit 向量特殊值测试 ===

procedure TTestCase_IEEE754EdgeCases.Test_F32x16_NaN_Propagation;
var
  a, b, r: TVecF32x16;
  i: Integer;
begin
  // 512-bit 向量中的 NaN 传播测试
  for i := 0 to 15 do
  begin
    a.f[i] := NaNF32;
    b.f[i] := 1.0;
  end;

  r := VecF32x16Add(a, b);

  for i := 0 to 15 do
    CheckTrue(IsNaNSingle(r.f[i]), 'F32x16: NaN + 1.0 should be NaN [' + IntToStr(i) + ']');

  // 测试部分 NaN
  for i := 0 to 15 do
  begin
    if (i mod 2) = 0 then
      a.f[i] := Single(i + 1)
    else
      a.f[i] := NaNF32;
  end;

  for i := 0 to 15 do
    b.f[i] := 10.0;
  r := VecF32x16Mul(a, b);

  for i := 0 to 15 do
  begin
    if (i mod 2) = 0 then
      CheckNear(Single(i + 1) * 10.0, r.f[i], 1e-6, 'F32x16: normal * 10.0 [' + IntToStr(i) + ']')
    else
      CheckTrue(IsNaNSingle(r.f[i]), 'F32x16: NaN * 10.0 [' + IntToStr(i) + ']');
  end;
end;

procedure TTestCase_IEEE754EdgeCases.Test_F64x8_Inf_Handling;
var
  a, b, r: TVecF64x8;
  i: Integer;
begin
  // 512-bit 双精度向量中的 Infinity 处理
  for i := 0 to 7 do
  begin
    a.d[i] := PosInfF64;
    b.d[i] := 1000.0;
  end;

  r := VecF64x8Add(a, b);

  for i := 0 to 7 do
    CheckTrue(IsInfinite(r.d[i]) and (r.d[i] > 0), 'F64x8: Inf + 1000.0 should be Inf [' + IntToStr(i) + ']');

  // Inf * 0 = NaN
  for i := 0 to 7 do
  begin
    a.d[i] := PosInfF64;
    b.d[i] := 0.0;
  end;
  r := VecF64x8Mul(a, b);

  for i := 0 to 7 do
    CheckTrue(IsNaNDouble(r.d[i]), 'F64x8: Inf * 0 should be NaN [' + IntToStr(i) + ']');
end;

{ TTestCase_AVX2RoundTruncIEEE754 }

procedure TTestCase_AVX2RoundTruncIEEE754.Test_AVX2_RoundTrunc_NaNInf_Consistency;
var
  LHaveSSE2: Boolean;
  LIndex: Integer;
  LDispatch: PSimdDispatchTable;

  LInF32x8, LScalarRoundF32x8, LScalarTruncF32x8, LSSE2RoundF32x8, LSSE2TruncF32x8, LAVX2RoundF32x8, LAVX2TruncF32x8: TVecF32x8;
  LInF64x4, LScalarRoundF64x4, LScalarTruncF64x4, LSSE2RoundF64x4, LSSE2TruncF64x4, LAVX2RoundF64x4, LAVX2TruncF64x4: TVecF64x4;
  LInF32x16, LScalarRoundF32x16, LScalarTruncF32x16, LSSE2RoundF32x16, LSSE2TruncF32x16, LAVX2RoundF32x16, LAVX2TruncF32x16: TVecF32x16;
  LInF64x8, LScalarRoundF64x8, LScalarTruncF64x8, LSSE2RoundF64x8, LSSE2TruncF64x8, LAVX2RoundF64x8, LAVX2TruncF64x8: TVecF64x8;

  procedure AssertSingleSemantics(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

begin
  if not IsBackendRegistered(sbAVX2) then
    Exit;

  LHaveSSE2 := IsBackendRegistered(sbSSE2);

  for LIndex := 0 to 7 do
    case (LIndex mod 8) of
      0: LInF32x8.f[LIndex] := NaNF32;
      1: LInF32x8.f[LIndex] := PosInfF32;
      2: LInF32x8.f[LIndex] := NegInfF32;
      3: LInF32x8.f[LIndex] := 1.75;
      4: LInF32x8.f[LIndex] := -1.75;
      5: LInF32x8.f[LIndex] := 0.0;
      6: LInF32x8.f[LIndex] := 123456.75;
    else
      LInF32x8.f[LIndex] := -123456.75;
    end;

  for LIndex := 0 to 3 do
    case (LIndex mod 6) of
      0: LInF64x4.d[LIndex] := NaNF64;
      1: LInF64x4.d[LIndex] := PosInfF64;
      2: LInF64x4.d[LIndex] := NegInfF64;
      3: LInF64x4.d[LIndex] := 2.75;
      4: LInF64x4.d[LIndex] := -2.75;
    else
      LInF64x4.d[LIndex] := 1000000.75;
    end;

  for LIndex := 0 to 15 do
    LInF32x16.f[LIndex] := LInF32x8.f[LIndex mod 8];

  for LIndex := 0 to 7 do
    case (LIndex mod 6) of
      0: LInF64x8.d[LIndex] := NaNF64;
      1: LInF64x8.d[LIndex] := PosInfF64;
      2: LInF64x8.d[LIndex] := NegInfF64;
      3: LInF64x8.d[LIndex] := 2.75;
      4: LInF64x8.d[LIndex] := -2.75;
    else
      LInF64x8.d[LIndex] := 1000000.75;
    end;

  // Scalar baseline
  SetVectorAsmEnabled(False);
  SetActiveBackend(sbScalar);
  LDispatch := GetDispatchTable;
  CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4), 'Scalar dispatch should provide wide Round/Trunc');

  LScalarRoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
  LScalarTruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
  LScalarRoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
  LScalarTruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
  LScalarRoundF32x16 := VecF32x16Round(LInF32x16);
  LScalarTruncF32x16 := VecF32x16Trunc(LInF32x16);
  LScalarRoundF64x8 := VecF64x8Round(LInF64x8);
  LScalarTruncF64x8 := VecF64x8Trunc(LInF64x8);

  // SSE2 reference (if available)
  if LHaveSSE2 then
  begin
    SetVectorAsmEnabled(True);
    SetActiveBackend(sbSSE2);
    LDispatch := GetDispatchTable;
    CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4), 'SSE2 dispatch should provide wide Round/Trunc');

    LSSE2RoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
    LSSE2TruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
    LSSE2RoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
    LSSE2TruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
    LSSE2RoundF32x16 := VecF32x16Round(LInF32x16);
    LSSE2TruncF32x16 := VecF32x16Trunc(LInF32x16);
    LSSE2RoundF64x8 := VecF64x8Round(LInF64x8);
    LSSE2TruncF64x8 := VecF64x8Trunc(LInF64x8);
  end;

  // AVX2 target (vector-asm required)
  SetVectorAsmEnabled(True);
  SetActiveBackend(sbAVX2);
  if GetActiveBackend <> sbAVX2 then
    Exit;

  LDispatch := GetDispatchTable;
  CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4), 'AVX2 dispatch should provide wide Round/Trunc');

  LAVX2RoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
  LAVX2TruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
  LAVX2RoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
  LAVX2TruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
  LAVX2RoundF32x16 := VecF32x16Round(LInF32x16);
  LAVX2TruncF32x16 := VecF32x16Trunc(LInF32x16);
  LAVX2RoundF64x8 := VecF64x8Round(LInF64x8);
  LAVX2TruncF64x8 := VecF64x8Trunc(LInF64x8);

  for LIndex := 0 to 7 do
  begin
    AssertSingleSemantics('AVX2 vs Scalar RoundF32x8[' + IntToStr(LIndex) + ']', LScalarRoundF32x8.f[LIndex], LAVX2RoundF32x8.f[LIndex]);
    AssertSingleSemantics('AVX2 vs Scalar TruncF32x8[' + IntToStr(LIndex) + ']', LScalarTruncF32x8.f[LIndex], LAVX2TruncF32x8.f[LIndex]);
    if LHaveSSE2 then
    begin
      AssertSingleSemantics('AVX2 vs SSE2 RoundF32x8[' + IntToStr(LIndex) + ']', LSSE2RoundF32x8.f[LIndex], LAVX2RoundF32x8.f[LIndex]);
      AssertSingleSemantics('AVX2 vs SSE2 TruncF32x8[' + IntToStr(LIndex) + ']', LSSE2TruncF32x8.f[LIndex], LAVX2TruncF32x8.f[LIndex]);
    end;
  end;

  for LIndex := 0 to 3 do
  begin
    AssertDoubleSemantics('AVX2 vs Scalar RoundF64x4[' + IntToStr(LIndex) + ']', LScalarRoundF64x4.d[LIndex], LAVX2RoundF64x4.d[LIndex]);
    AssertDoubleSemantics('AVX2 vs Scalar TruncF64x4[' + IntToStr(LIndex) + ']', LScalarTruncF64x4.d[LIndex], LAVX2TruncF64x4.d[LIndex]);
    if LHaveSSE2 then
    begin
      AssertDoubleSemantics('AVX2 vs SSE2 RoundF64x4[' + IntToStr(LIndex) + ']', LSSE2RoundF64x4.d[LIndex], LAVX2RoundF64x4.d[LIndex]);
      AssertDoubleSemantics('AVX2 vs SSE2 TruncF64x4[' + IntToStr(LIndex) + ']', LSSE2TruncF64x4.d[LIndex], LAVX2TruncF64x4.d[LIndex]);
    end;
  end;

  for LIndex := 0 to 15 do
  begin
    AssertSingleSemantics('AVX2 vs Scalar RoundF32x16[' + IntToStr(LIndex) + ']', LScalarRoundF32x16.f[LIndex], LAVX2RoundF32x16.f[LIndex]);
    AssertSingleSemantics('AVX2 vs Scalar TruncF32x16[' + IntToStr(LIndex) + ']', LScalarTruncF32x16.f[LIndex], LAVX2TruncF32x16.f[LIndex]);
    if LHaveSSE2 then
    begin
      AssertSingleSemantics('AVX2 vs SSE2 RoundF32x16[' + IntToStr(LIndex) + ']', LSSE2RoundF32x16.f[LIndex], LAVX2RoundF32x16.f[LIndex]);
      AssertSingleSemantics('AVX2 vs SSE2 TruncF32x16[' + IntToStr(LIndex) + ']', LSSE2TruncF32x16.f[LIndex], LAVX2TruncF32x16.f[LIndex]);
    end;
  end;

  for LIndex := 0 to 7 do
  begin
    AssertDoubleSemantics('AVX2 vs Scalar RoundF64x8[' + IntToStr(LIndex) + ']', LScalarRoundF64x8.d[LIndex], LAVX2RoundF64x8.d[LIndex]);
    AssertDoubleSemantics('AVX2 vs Scalar TruncF64x8[' + IntToStr(LIndex) + ']', LScalarTruncF64x8.d[LIndex], LAVX2TruncF64x8.d[LIndex]);
    if LHaveSSE2 then
    begin
      AssertDoubleSemantics('AVX2 vs SSE2 RoundF64x8[' + IntToStr(LIndex) + ']', LSSE2RoundF64x8.d[LIndex], LAVX2RoundF64x8.d[LIndex]);
      AssertDoubleSemantics('AVX2 vs SSE2 TruncF64x8[' + IntToStr(LIndex) + ']', LSSE2TruncF64x8.d[LIndex], LAVX2TruncF64x8.d[LIndex]);
    end;
  end;
end;

procedure TTestCase_AVX2RoundTruncIEEE754.Test_AVX2_FloorCeil_NaNInf_Consistency;
var
  LHaveSSE2: Boolean;
  LIndex: Integer;
  LDispatch: PSimdDispatchTable;

  LInF32x8, LScalarFloorF32x8, LScalarCeilF32x8, LSSE2FloorF32x8, LSSE2CeilF32x8, LAVX2FloorF32x8, LAVX2CeilF32x8: TVecF32x8;
  LInF64x4, LScalarFloorF64x4, LScalarCeilF64x4, LSSE2FloorF64x4, LSSE2CeilF64x4, LAVX2FloorF64x4, LAVX2CeilF64x4: TVecF64x4;
  LInF32x16, LScalarFloorF32x16, LScalarCeilF32x16, LSSE2FloorF32x16, LSSE2CeilF32x16, LAVX2FloorF32x16, LAVX2CeilF32x16: TVecF32x16;
  LInF64x8, LScalarFloorF64x8, LScalarCeilF64x8, LSSE2FloorF64x8, LSSE2CeilF64x8, LAVX2FloorF64x8, LAVX2CeilF64x8: TVecF64x8;

  procedure AssertSingleSemantics(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

begin
  if not IsBackendRegistered(sbAVX2) then
    Exit;

  LHaveSSE2 := IsBackendRegistered(sbSSE2);
  for LIndex := 0 to 7 do
    case (LIndex mod 8) of
      0: LInF32x8.f[LIndex] := NaNF32;
      1: LInF32x8.f[LIndex] := PosInfF32;
      2: LInF32x8.f[LIndex] := NegInfF32;
      3: LInF32x8.f[LIndex] := 1.75;
      4: LInF32x8.f[LIndex] := -1.75;
      5: LInF32x8.f[LIndex] := 0.0;
      6: LInF32x8.f[LIndex] := 123456.75;
    else
      LInF32x8.f[LIndex] := -123456.75;
    end;

  for LIndex := 0 to 3 do
    case (LIndex mod 6) of
      0: LInF64x4.d[LIndex] := NaNF64;
      1: LInF64x4.d[LIndex] := PosInfF64;
      2: LInF64x4.d[LIndex] := NegInfF64;
      3: LInF64x4.d[LIndex] := 2.75;
      4: LInF64x4.d[LIndex] := -2.75;
    else
      LInF64x4.d[LIndex] := 1000000.75;
    end;

  for LIndex := 0 to 15 do
    LInF32x16.f[LIndex] := LInF32x8.f[LIndex mod 8];

  for LIndex := 0 to 7 do
    case (LIndex mod 6) of
      0: LInF64x8.d[LIndex] := NaNF64;
      1: LInF64x8.d[LIndex] := PosInfF64;
      2: LInF64x8.d[LIndex] := NegInfF64;
      3: LInF64x8.d[LIndex] := 2.75;
      4: LInF64x8.d[LIndex] := -2.75;
    else
      LInF64x8.d[LIndex] := 1000000.75;
    end;

  SetVectorAsmEnabled(False);
    SetActiveBackend(sbScalar);
    LDispatch := GetDispatchTable;
    CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.FloorF32x8) and Assigned(LDispatch^.CeilF32x8) and Assigned(LDispatch^.FloorF64x4) and Assigned(LDispatch^.CeilF64x4), 'Scalar dispatch should provide wide Floor/Ceil');

    LScalarFloorF32x8 := LDispatch^.FloorF32x8(LInF32x8);
    LScalarCeilF32x8 := LDispatch^.CeilF32x8(LInF32x8);
    LScalarFloorF64x4 := LDispatch^.FloorF64x4(LInF64x4);
    LScalarCeilF64x4 := LDispatch^.CeilF64x4(LInF64x4);
    LScalarFloorF32x16 := VecF32x16Floor(LInF32x16);
    LScalarCeilF32x16 := VecF32x16Ceil(LInF32x16);
    LScalarFloorF64x8 := VecF64x8Floor(LInF64x8);
    LScalarCeilF64x8 := VecF64x8Ceil(LInF64x8);

    if LHaveSSE2 then
    begin
      SetVectorAsmEnabled(True);
      SetActiveBackend(sbSSE2);
      LDispatch := GetDispatchTable;
      CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.FloorF32x8) and Assigned(LDispatch^.CeilF32x8) and Assigned(LDispatch^.FloorF64x4) and Assigned(LDispatch^.CeilF64x4), 'SSE2 dispatch should provide wide Floor/Ceil');

      LSSE2FloorF32x8 := LDispatch^.FloorF32x8(LInF32x8);
      LSSE2CeilF32x8 := LDispatch^.CeilF32x8(LInF32x8);
      LSSE2FloorF64x4 := LDispatch^.FloorF64x4(LInF64x4);
      LSSE2CeilF64x4 := LDispatch^.CeilF64x4(LInF64x4);
      LSSE2FloorF32x16 := VecF32x16Floor(LInF32x16);
      LSSE2CeilF32x16 := VecF32x16Ceil(LInF32x16);
      LSSE2FloorF64x8 := VecF64x8Floor(LInF64x8);
      LSSE2CeilF64x8 := VecF64x8Ceil(LInF64x8);
    end;

    SetVectorAsmEnabled(True);
    SetActiveBackend(sbAVX2);
    if GetActiveBackend <> sbAVX2 then
      Exit;

    LDispatch := GetDispatchTable;
    CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.FloorF32x8) and Assigned(LDispatch^.CeilF32x8) and Assigned(LDispatch^.FloorF64x4) and Assigned(LDispatch^.CeilF64x4), 'AVX2 dispatch should provide wide Floor/Ceil');

    LAVX2FloorF32x8 := LDispatch^.FloorF32x8(LInF32x8);
    LAVX2CeilF32x8 := LDispatch^.CeilF32x8(LInF32x8);
    LAVX2FloorF64x4 := LDispatch^.FloorF64x4(LInF64x4);
    LAVX2CeilF64x4 := LDispatch^.CeilF64x4(LInF64x4);
    LAVX2FloorF32x16 := VecF32x16Floor(LInF32x16);
    LAVX2CeilF32x16 := VecF32x16Ceil(LInF32x16);
    LAVX2FloorF64x8 := VecF64x8Floor(LInF64x8);
    LAVX2CeilF64x8 := VecF64x8Ceil(LInF64x8);

    for LIndex := 0 to 7 do
    begin
      AssertSingleSemantics('AVX2 vs Scalar FloorF32x8[' + IntToStr(LIndex) + ']', LScalarFloorF32x8.f[LIndex], LAVX2FloorF32x8.f[LIndex]);
      AssertSingleSemantics('AVX2 vs Scalar CeilF32x8[' + IntToStr(LIndex) + ']', LScalarCeilF32x8.f[LIndex], LAVX2CeilF32x8.f[LIndex]);
      if LHaveSSE2 then
      begin
        AssertSingleSemantics('AVX2 vs SSE2 FloorF32x8[' + IntToStr(LIndex) + ']', LSSE2FloorF32x8.f[LIndex], LAVX2FloorF32x8.f[LIndex]);
        AssertSingleSemantics('AVX2 vs SSE2 CeilF32x8[' + IntToStr(LIndex) + ']', LSSE2CeilF32x8.f[LIndex], LAVX2CeilF32x8.f[LIndex]);
      end;
    end;

    for LIndex := 0 to 3 do
    begin
      AssertDoubleSemantics('AVX2 vs Scalar FloorF64x4[' + IntToStr(LIndex) + ']', LScalarFloorF64x4.d[LIndex], LAVX2FloorF64x4.d[LIndex]);
      AssertDoubleSemantics('AVX2 vs Scalar CeilF64x4[' + IntToStr(LIndex) + ']', LScalarCeilF64x4.d[LIndex], LAVX2CeilF64x4.d[LIndex]);
      if LHaveSSE2 then
      begin
        AssertDoubleSemantics('AVX2 vs SSE2 FloorF64x4[' + IntToStr(LIndex) + ']', LSSE2FloorF64x4.d[LIndex], LAVX2FloorF64x4.d[LIndex]);
        AssertDoubleSemantics('AVX2 vs SSE2 CeilF64x4[' + IntToStr(LIndex) + ']', LSSE2CeilF64x4.d[LIndex], LAVX2CeilF64x4.d[LIndex]);
      end;
    end;

    for LIndex := 0 to 15 do
    begin
      AssertSingleSemantics('AVX2 vs Scalar FloorF32x16[' + IntToStr(LIndex) + ']', LScalarFloorF32x16.f[LIndex], LAVX2FloorF32x16.f[LIndex]);
      AssertSingleSemantics('AVX2 vs Scalar CeilF32x16[' + IntToStr(LIndex) + ']', LScalarCeilF32x16.f[LIndex], LAVX2CeilF32x16.f[LIndex]);
      if LHaveSSE2 then
      begin
        AssertSingleSemantics('AVX2 vs SSE2 FloorF32x16[' + IntToStr(LIndex) + ']', LSSE2FloorF32x16.f[LIndex], LAVX2FloorF32x16.f[LIndex]);
        AssertSingleSemantics('AVX2 vs SSE2 CeilF32x16[' + IntToStr(LIndex) + ']', LSSE2CeilF32x16.f[LIndex], LAVX2CeilF32x16.f[LIndex]);
      end;
    end;

    for LIndex := 0 to 7 do
    begin
      AssertDoubleSemantics('AVX2 vs Scalar FloorF64x8[' + IntToStr(LIndex) + ']', LScalarFloorF64x8.d[LIndex], LAVX2FloorF64x8.d[LIndex]);
      AssertDoubleSemantics('AVX2 vs Scalar CeilF64x8[' + IntToStr(LIndex) + ']', LScalarCeilF64x8.d[LIndex], LAVX2CeilF64x8.d[LIndex]);
      if LHaveSSE2 then
      begin
        AssertDoubleSemantics('AVX2 vs SSE2 FloorF64x8[' + IntToStr(LIndex) + ']', LSSE2FloorF64x8.d[LIndex], LAVX2FloorF64x8.d[LIndex]);
        AssertDoubleSemantics('AVX2 vs SSE2 CeilF64x8[' + IntToStr(LIndex) + ']', LSSE2CeilF64x8.d[LIndex], LAVX2CeilF64x8.d[LIndex]);
      end;
    end;
end;

procedure TTestCase_AVX2RoundTruncIEEE754.Test_AVX2_FloorCeil_PropertyLike_Randomized;
const
  SAMPLE_ROUNDS = 128;
var
  LHaveSSE2: Boolean;
  LRound: Integer;
  LIndex: Integer;
  LDispatch: PSimdDispatchTable;
  LSeed: QWord;

  LInF32x8, LScalarFloorF32x8, LScalarCeilF32x8, LSSE2FloorF32x8, LSSE2CeilF32x8, LAVX2FloorF32x8, LAVX2CeilF32x8: TVecF32x8;
  LInF64x4, LScalarFloorF64x4, LScalarCeilF64x4, LSSE2FloorF64x4, LSSE2CeilF64x4, LAVX2FloorF64x4, LAVX2CeilF64x4: TVecF64x4;
  LInF32x16, LScalarFloorF32x16, LScalarCeilF32x16, LSSE2FloorF32x16, LSSE2CeilF32x16, LAVX2FloorF32x16, LAVX2CeilF32x16: TVecF32x16;
  LInF64x8, LScalarFloorF64x8, LScalarCeilF64x8, LSSE2FloorF64x8, LSSE2CeilF64x8, LAVX2FloorF64x8, LAVX2CeilF64x8: TVecF64x8;

  function NextU32: Cardinal; inline;
  begin
    LSeed := LSeed * QWord(6364136223846793005) + QWord(1442695040888963407);
    Result := Cardinal(LSeed shr 32);
  end;

  function NextSingleValue: Single;
  var
    LRaw: Cardinal;
  begin
    LRaw := NextU32;
    case (LRaw and 15) of
      0: Result := 0.0;
      1: Result := -0.0;
      2: Result := 0.5;
      3: Result := -0.5;
      4: Result := 1.0;
      5: Result := -1.0;
      6: Result := 1024.75;
      7: Result := -1024.75;
    else
      Result := (Integer(LRaw and $001FFFFF) - Integer($000FFFFF)) / 64.0;
    end;
  end;

  function NextDoubleValue: Double;
  var
    LRaw: Cardinal;
  begin
    LRaw := NextU32;
    case (LRaw and 15) of
      0: Result := 0.0;
      1: Result := -0.0;
      2: Result := 0.5;
      3: Result := -0.5;
      4: Result := 2.75;
      5: Result := -2.75;
      6: Result := 65536.125;
      7: Result := -65536.125;
    else
      Result := (Int64(LRaw and $003FFFFF) - Int64($001FFFFF)) / 32.0;
    end;
  end;

  procedure AssertSingleSemantics(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertFloorCeilInvariantSingle(const aPrefix: string; const aInput, aFloor, aCeil: Single);
  begin
    if IsNaNSingle(aInput) or IsInfinite(aInput) then
      Exit;
    CheckTrue(aFloor <= aInput + 1e-6, aPrefix + ' floor<=x');
    CheckTrue(aCeil + 1e-6 >= aInput, aPrefix + ' ceil>=x');
    CheckTrue((aCeil - aFloor) <= 1.0 + 1e-6, aPrefix + ' ceil-floor<=1');
    CheckNear(0.0, Frac(aFloor), 0.0, aPrefix + ' floor is integral');
    CheckNear(0.0, Frac(aCeil), 0.0, aPrefix + ' ceil is integral');
  end;

  procedure AssertFloorCeilInvariantDouble(const aPrefix: string; const aInput, aFloor, aCeil: Double);
  begin
    if IsNaNDouble(aInput) or IsInfinite(aInput) then
      Exit;
    CheckTrue(aFloor <= aInput + 1e-12, aPrefix + ' floor<=x');
    CheckTrue(aCeil + 1e-12 >= aInput, aPrefix + ' ceil>=x');
    CheckTrue((aCeil - aFloor) <= 1.0 + 1e-12, aPrefix + ' ceil-floor<=1');
    CheckNear(0.0, Frac(aFloor), 0.0, aPrefix + ' floor is integral');
    CheckNear(0.0, Frac(aCeil), 0.0, aPrefix + ' ceil is integral');
  end;

begin
  if not IsBackendRegistered(sbAVX2) then
    Exit;

  LHaveSSE2 := IsBackendRegistered(sbSSE2);
  LSeed := QWord($A5A55A5A1234FEDC);

  for LRound := 1 to SAMPLE_ROUNDS do
    begin
      for LIndex := 0 to 7 do
        LInF32x8.f[LIndex] := NextSingleValue;
      for LIndex := 0 to 3 do
        LInF64x4.d[LIndex] := NextDoubleValue;
      for LIndex := 0 to 15 do
        LInF32x16.f[LIndex] := NextSingleValue;
      for LIndex := 0 to 7 do
        LInF64x8.d[LIndex] := NextDoubleValue;

      SetVectorAsmEnabled(False);
      SetActiveBackend(sbScalar);
      LDispatch := GetDispatchTable;
      CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.FloorF32x8) and Assigned(LDispatch^.CeilF32x8) and Assigned(LDispatch^.FloorF64x4) and Assigned(LDispatch^.CeilF64x4), 'Scalar dispatch should provide wide Floor/Ceil');

      LScalarFloorF32x8 := LDispatch^.FloorF32x8(LInF32x8);
      LScalarCeilF32x8 := LDispatch^.CeilF32x8(LInF32x8);
      LScalarFloorF64x4 := LDispatch^.FloorF64x4(LInF64x4);
      LScalarCeilF64x4 := LDispatch^.CeilF64x4(LInF64x4);
      LScalarFloorF32x16 := VecF32x16Floor(LInF32x16);
      LScalarCeilF32x16 := VecF32x16Ceil(LInF32x16);
      LScalarFloorF64x8 := VecF64x8Floor(LInF64x8);
      LScalarCeilF64x8 := VecF64x8Ceil(LInF64x8);

      if LHaveSSE2 then
      begin
        SetVectorAsmEnabled(True);
        SetActiveBackend(sbSSE2);
        LDispatch := GetDispatchTable;
        CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.FloorF32x8) and Assigned(LDispatch^.CeilF32x8) and Assigned(LDispatch^.FloorF64x4) and Assigned(LDispatch^.CeilF64x4), 'SSE2 dispatch should provide wide Floor/Ceil');

        LSSE2FloorF32x8 := LDispatch^.FloorF32x8(LInF32x8);
        LSSE2CeilF32x8 := LDispatch^.CeilF32x8(LInF32x8);
        LSSE2FloorF64x4 := LDispatch^.FloorF64x4(LInF64x4);
        LSSE2CeilF64x4 := LDispatch^.CeilF64x4(LInF64x4);
        LSSE2FloorF32x16 := VecF32x16Floor(LInF32x16);
        LSSE2CeilF32x16 := VecF32x16Ceil(LInF32x16);
        LSSE2FloorF64x8 := VecF64x8Floor(LInF64x8);
        LSSE2CeilF64x8 := VecF64x8Ceil(LInF64x8);
      end;

      SetVectorAsmEnabled(True);
      SetActiveBackend(sbAVX2);
      if GetActiveBackend <> sbAVX2 then
        Exit;

      LDispatch := GetDispatchTable;
      CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.FloorF32x8) and Assigned(LDispatch^.CeilF32x8) and Assigned(LDispatch^.FloorF64x4) and Assigned(LDispatch^.CeilF64x4), 'AVX2 dispatch should provide wide Floor/Ceil');

      LAVX2FloorF32x8 := LDispatch^.FloorF32x8(LInF32x8);
      LAVX2CeilF32x8 := LDispatch^.CeilF32x8(LInF32x8);
      LAVX2FloorF64x4 := LDispatch^.FloorF64x4(LInF64x4);
      LAVX2CeilF64x4 := LDispatch^.CeilF64x4(LInF64x4);
      LAVX2FloorF32x16 := VecF32x16Floor(LInF32x16);
      LAVX2CeilF32x16 := VecF32x16Ceil(LInF32x16);
      LAVX2FloorF64x8 := VecF64x8Floor(LInF64x8);
      LAVX2CeilF64x8 := VecF64x8Ceil(LInF64x8);

      for LIndex := 0 to 7 do
      begin
        AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar FloorF32x8[' + IntToStr(LIndex) + ']', LScalarFloorF32x8.f[LIndex], LAVX2FloorF32x8.f[LIndex]);
        AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar CeilF32x8[' + IntToStr(LIndex) + ']', LScalarCeilF32x8.f[LIndex], LAVX2CeilF32x8.f[LIndex]);
        AssertFloorCeilInvariantSingle('Round ' + IntToStr(LRound) + ' F32x8[' + IntToStr(LIndex) + ']', LInF32x8.f[LIndex], LAVX2FloorF32x8.f[LIndex], LAVX2CeilF32x8.f[LIndex]);
        if LHaveSSE2 then
        begin
          AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 FloorF32x8[' + IntToStr(LIndex) + ']', LSSE2FloorF32x8.f[LIndex], LAVX2FloorF32x8.f[LIndex]);
          AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 CeilF32x8[' + IntToStr(LIndex) + ']', LSSE2CeilF32x8.f[LIndex], LAVX2CeilF32x8.f[LIndex]);
        end;
      end;

      for LIndex := 0 to 3 do
      begin
        AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar FloorF64x4[' + IntToStr(LIndex) + ']', LScalarFloorF64x4.d[LIndex], LAVX2FloorF64x4.d[LIndex]);
        AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar CeilF64x4[' + IntToStr(LIndex) + ']', LScalarCeilF64x4.d[LIndex], LAVX2CeilF64x4.d[LIndex]);
        AssertFloorCeilInvariantDouble('Round ' + IntToStr(LRound) + ' F64x4[' + IntToStr(LIndex) + ']', LInF64x4.d[LIndex], LAVX2FloorF64x4.d[LIndex], LAVX2CeilF64x4.d[LIndex]);
        if LHaveSSE2 then
        begin
          AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 FloorF64x4[' + IntToStr(LIndex) + ']', LSSE2FloorF64x4.d[LIndex], LAVX2FloorF64x4.d[LIndex]);
          AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 CeilF64x4[' + IntToStr(LIndex) + ']', LSSE2CeilF64x4.d[LIndex], LAVX2CeilF64x4.d[LIndex]);
        end;
      end;

      for LIndex := 0 to 15 do
      begin
        AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar FloorF32x16[' + IntToStr(LIndex) + ']', LScalarFloorF32x16.f[LIndex], LAVX2FloorF32x16.f[LIndex]);
        AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar CeilF32x16[' + IntToStr(LIndex) + ']', LScalarCeilF32x16.f[LIndex], LAVX2CeilF32x16.f[LIndex]);
        AssertFloorCeilInvariantSingle('Round ' + IntToStr(LRound) + ' F32x16[' + IntToStr(LIndex) + ']', LInF32x16.f[LIndex], LAVX2FloorF32x16.f[LIndex], LAVX2CeilF32x16.f[LIndex]);
        if LHaveSSE2 then
        begin
          AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 FloorF32x16[' + IntToStr(LIndex) + ']', LSSE2FloorF32x16.f[LIndex], LAVX2FloorF32x16.f[LIndex]);
          AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 CeilF32x16[' + IntToStr(LIndex) + ']', LSSE2CeilF32x16.f[LIndex], LAVX2CeilF32x16.f[LIndex]);
        end;
      end;

      for LIndex := 0 to 7 do
      begin
        AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar FloorF64x8[' + IntToStr(LIndex) + ']', LScalarFloorF64x8.d[LIndex], LAVX2FloorF64x8.d[LIndex]);
        AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar CeilF64x8[' + IntToStr(LIndex) + ']', LScalarCeilF64x8.d[LIndex], LAVX2CeilF64x8.d[LIndex]);
        AssertFloorCeilInvariantDouble('Round ' + IntToStr(LRound) + ' F64x8[' + IntToStr(LIndex) + ']', LInF64x8.d[LIndex], LAVX2FloorF64x8.d[LIndex], LAVX2CeilF64x8.d[LIndex]);
        if LHaveSSE2 then
        begin
          AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 FloorF64x8[' + IntToStr(LIndex) + ']', LSSE2FloorF64x8.d[LIndex], LAVX2FloorF64x8.d[LIndex]);
          AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 CeilF64x8[' + IntToStr(LIndex) + ']', LSSE2CeilF64x8.d[LIndex], LAVX2CeilF64x8.d[LIndex]);
        end;
      end;
    end;
end;

procedure TTestCase_AVX2RoundTruncIEEE754.Test_AVX2_RoundTrunc_PropertyLike_Randomized;
const
  SAMPLE_ROUNDS = 128;
var
  LHaveSSE2: Boolean;
  LRound: Integer;
  LIndex: Integer;
  LDispatch: PSimdDispatchTable;
  LSeed: QWord;

  LInF32x8, LScalarRoundF32x8, LScalarTruncF32x8, LSSE2RoundF32x8, LSSE2TruncF32x8, LAVX2RoundF32x8, LAVX2TruncF32x8: TVecF32x8;
  LInF64x4, LScalarRoundF64x4, LScalarTruncF64x4, LSSE2RoundF64x4, LSSE2TruncF64x4, LAVX2RoundF64x4, LAVX2TruncF64x4: TVecF64x4;
  LInF32x16, LScalarRoundF32x16, LScalarTruncF32x16, LSSE2RoundF32x16, LSSE2TruncF32x16, LAVX2RoundF32x16, LAVX2TruncF32x16: TVecF32x16;
  LInF64x8, LScalarRoundF64x8, LScalarTruncF64x8, LSSE2RoundF64x8, LSSE2TruncF64x8, LAVX2RoundF64x8, LAVX2TruncF64x8: TVecF64x8;

  function NextU32: Cardinal; inline;
  begin
    LSeed := LSeed * QWord(6364136223846793005) + QWord(1442695040888963407);
    Result := Cardinal(LSeed shr 32);
  end;

  function NextSingleValue: Single;
  var
    LRaw: Cardinal;
  begin
    LRaw := NextU32;
    case (LRaw and 31) of
      0: Result := NaNF32;
      1: Result := PosInfF32;
      2: Result := NegInfF32;
      3: Result := 0.0;
      4: Result := -0.0;
      5: Result := 0.5;
      6: Result := -0.5;
      7: Result := 1.5;
      8: Result := -1.5;
      9: Result := 2.5;
      10: Result := -2.5;
      11: Result := 1024.75;
      12: Result := -1024.75;
    else
      Result := (Integer(LRaw and $003FFFFF) - Integer($001FFFFF)) / 32.0;
    end;
  end;

  function NextDoubleValue: Double;
  var
    LRaw: Cardinal;
  begin
    LRaw := NextU32;
    case (LRaw and 31) of
      0: Result := NaNF64;
      1: Result := PosInfF64;
      2: Result := NegInfF64;
      3: Result := 0.0;
      4: Result := -0.0;
      5: Result := 0.5;
      6: Result := -0.5;
      7: Result := 1.5;
      8: Result := -1.5;
      9: Result := 2.5;
      10: Result := -2.5;
      11: Result := 65536.125;
      12: Result := -65536.125;
    else
      Result := (Int64(LRaw and $007FFFFF) - Int64($003FFFFF)) / 16.0;
    end;
  end;

  procedure AssertSingleSemantics(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertRoundTruncInvariantSingle(const aPrefix: string; const aInput, aRound, aTrunc: Single);
  begin
    if IsNaNSingle(aInput) or IsInfinite(aInput) then
      Exit;
    CheckNear(0.0, Frac(aRound), 0.0, aPrefix + ' round integral');
    CheckNear(0.0, Frac(aTrunc), 0.0, aPrefix + ' trunc integral');
    CheckTrue(Abs(aRound - aInput) <= 0.500001, aPrefix + ' abs(round-x)<=0.5');
    CheckTrue(Abs(aTrunc) <= Abs(aInput) + 1e-6, aPrefix + ' abs(trunc)<=abs(x)');
    if aInput >= 0 then
    begin
      CheckTrue(aTrunc <= aInput + 1e-6, aPrefix + ' trunc<=x (x>=0)');
      CheckTrue(aTrunc >= -1e-6, aPrefix + ' trunc>=0 (x>=0)');
    end
    else
    begin
      CheckTrue(aTrunc + 1e-6 >= aInput, aPrefix + ' trunc>=x (x<0)');
      CheckTrue(aTrunc <= 1e-6, aPrefix + ' trunc<=0 (x<0)');
    end;
  end;

  procedure AssertRoundTruncInvariantDouble(const aPrefix: string; const aInput, aRound, aTrunc: Double);
  begin
    if IsNaNDouble(aInput) or IsInfinite(aInput) then
      Exit;
    CheckNear(0.0, Frac(aRound), 0.0, aPrefix + ' round integral');
    CheckNear(0.0, Frac(aTrunc), 0.0, aPrefix + ' trunc integral');
    CheckTrue(Abs(aRound - aInput) <= 0.500000000001, aPrefix + ' abs(round-x)<=0.5');
    CheckTrue(Abs(aTrunc) <= Abs(aInput) + 1e-12, aPrefix + ' abs(trunc)<=abs(x)');
    if aInput >= 0 then
    begin
      CheckTrue(aTrunc <= aInput + 1e-12, aPrefix + ' trunc<=x (x>=0)');
      CheckTrue(aTrunc >= -1e-12, aPrefix + ' trunc>=0 (x>=0)');
    end
    else
    begin
      CheckTrue(aTrunc + 1e-12 >= aInput, aPrefix + ' trunc>=x (x<0)');
      CheckTrue(aTrunc <= 1e-12, aPrefix + ' trunc<=0 (x<0)');
    end;
  end;

begin
  if not IsBackendRegistered(sbAVX2) then
    Exit;

  LHaveSSE2 := IsBackendRegistered(sbSSE2);
  LSeed := QWord($7E57A11D23B5C0DE);

  for LRound := 1 to SAMPLE_ROUNDS do
    begin
      for LIndex := 0 to 7 do
        LInF32x8.f[LIndex] := NextSingleValue;
      for LIndex := 0 to 3 do
        LInF64x4.d[LIndex] := NextDoubleValue;
      for LIndex := 0 to 15 do
        LInF32x16.f[LIndex] := NextSingleValue;
      for LIndex := 0 to 7 do
        LInF64x8.d[LIndex] := NextDoubleValue;

      SetVectorAsmEnabled(False);
      SetActiveBackend(sbScalar);
      LDispatch := GetDispatchTable;
      CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4), 'Scalar dispatch should provide wide Round/Trunc');

      LScalarRoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
      LScalarTruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
      LScalarRoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
      LScalarTruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
      LScalarRoundF32x16 := VecF32x16Round(LInF32x16);
      LScalarTruncF32x16 := VecF32x16Trunc(LInF32x16);
      LScalarRoundF64x8 := VecF64x8Round(LInF64x8);
      LScalarTruncF64x8 := VecF64x8Trunc(LInF64x8);

      if LHaveSSE2 then
      begin
        SetVectorAsmEnabled(True);
        SetActiveBackend(sbSSE2);
        LDispatch := GetDispatchTable;
        CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4), 'SSE2 dispatch should provide wide Round/Trunc');

        LSSE2RoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
        LSSE2TruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
        LSSE2RoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
        LSSE2TruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
        LSSE2RoundF32x16 := VecF32x16Round(LInF32x16);
        LSSE2TruncF32x16 := VecF32x16Trunc(LInF32x16);
        LSSE2RoundF64x8 := VecF64x8Round(LInF64x8);
        LSSE2TruncF64x8 := VecF64x8Trunc(LInF64x8);
      end;

      SetVectorAsmEnabled(True);
      SetActiveBackend(sbAVX2);
      if GetActiveBackend <> sbAVX2 then
        Exit;

      LDispatch := GetDispatchTable;
      CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4), 'AVX2 dispatch should provide wide Round/Trunc');

      LAVX2RoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
      LAVX2TruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
      LAVX2RoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
      LAVX2TruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
      LAVX2RoundF32x16 := VecF32x16Round(LInF32x16);
      LAVX2TruncF32x16 := VecF32x16Trunc(LInF32x16);
      LAVX2RoundF64x8 := VecF64x8Round(LInF64x8);
      LAVX2TruncF64x8 := VecF64x8Trunc(LInF64x8);

      for LIndex := 0 to 7 do
      begin
        AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar RoundF32x8[' + IntToStr(LIndex) + ']', LScalarRoundF32x8.f[LIndex], LAVX2RoundF32x8.f[LIndex]);
        AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar TruncF32x8[' + IntToStr(LIndex) + ']', LScalarTruncF32x8.f[LIndex], LAVX2TruncF32x8.f[LIndex]);
        AssertRoundTruncInvariantSingle('Round ' + IntToStr(LRound) + ' F32x8[' + IntToStr(LIndex) + ']', LInF32x8.f[LIndex], LAVX2RoundF32x8.f[LIndex], LAVX2TruncF32x8.f[LIndex]);
        if LHaveSSE2 then
        begin
          AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 RoundF32x8[' + IntToStr(LIndex) + ']', LSSE2RoundF32x8.f[LIndex], LAVX2RoundF32x8.f[LIndex]);
          AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 TruncF32x8[' + IntToStr(LIndex) + ']', LSSE2TruncF32x8.f[LIndex], LAVX2TruncF32x8.f[LIndex]);
        end;
      end;

      for LIndex := 0 to 3 do
      begin
        AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar RoundF64x4[' + IntToStr(LIndex) + ']', LScalarRoundF64x4.d[LIndex], LAVX2RoundF64x4.d[LIndex]);
        AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar TruncF64x4[' + IntToStr(LIndex) + ']', LScalarTruncF64x4.d[LIndex], LAVX2TruncF64x4.d[LIndex]);
        AssertRoundTruncInvariantDouble('Round ' + IntToStr(LRound) + ' F64x4[' + IntToStr(LIndex) + ']', LInF64x4.d[LIndex], LAVX2RoundF64x4.d[LIndex], LAVX2TruncF64x4.d[LIndex]);
        if LHaveSSE2 then
        begin
          AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 RoundF64x4[' + IntToStr(LIndex) + ']', LSSE2RoundF64x4.d[LIndex], LAVX2RoundF64x4.d[LIndex]);
          AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 TruncF64x4[' + IntToStr(LIndex) + ']', LSSE2TruncF64x4.d[LIndex], LAVX2TruncF64x4.d[LIndex]);
        end;
      end;

      for LIndex := 0 to 15 do
      begin
        AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar RoundF32x16[' + IntToStr(LIndex) + ']', LScalarRoundF32x16.f[LIndex], LAVX2RoundF32x16.f[LIndex]);
        AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar TruncF32x16[' + IntToStr(LIndex) + ']', LScalarTruncF32x16.f[LIndex], LAVX2TruncF32x16.f[LIndex]);
        AssertRoundTruncInvariantSingle('Round ' + IntToStr(LRound) + ' F32x16[' + IntToStr(LIndex) + ']', LInF32x16.f[LIndex], LAVX2RoundF32x16.f[LIndex], LAVX2TruncF32x16.f[LIndex]);
        if LHaveSSE2 then
        begin
          AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 RoundF32x16[' + IntToStr(LIndex) + ']', LSSE2RoundF32x16.f[LIndex], LAVX2RoundF32x16.f[LIndex]);
          AssertSingleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 TruncF32x16[' + IntToStr(LIndex) + ']', LSSE2TruncF32x16.f[LIndex], LAVX2TruncF32x16.f[LIndex]);
        end;
      end;

      for LIndex := 0 to 7 do
      begin
        AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar RoundF64x8[' + IntToStr(LIndex) + ']', LScalarRoundF64x8.d[LIndex], LAVX2RoundF64x8.d[LIndex]);
        AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs Scalar TruncF64x8[' + IntToStr(LIndex) + ']', LScalarTruncF64x8.d[LIndex], LAVX2TruncF64x8.d[LIndex]);
        AssertRoundTruncInvariantDouble('Round ' + IntToStr(LRound) + ' F64x8[' + IntToStr(LIndex) + ']', LInF64x8.d[LIndex], LAVX2RoundF64x8.d[LIndex], LAVX2TruncF64x8.d[LIndex]);
        if LHaveSSE2 then
        begin
          AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 RoundF64x8[' + IntToStr(LIndex) + ']', LSSE2RoundF64x8.d[LIndex], LAVX2RoundF64x8.d[LIndex]);
          AssertDoubleSemantics('Round ' + IntToStr(LRound) + ' AVX2 vs SSE2 TruncF64x8[' + IntToStr(LIndex) + ']', LSSE2TruncF64x8.d[LIndex], LAVX2TruncF64x8.d[LIndex]);
        end;
      end;
    end;
end;

procedure TTestCase_AVX2RoundTruncIEEE754.Test_AVX2_RoundTrunc_SignedZero_Consistency;
var
  LHaveSSE2: Boolean;
  LIndex: Integer;
  LDispatch: PSimdDispatchTable;

  LInF32x8, LScalarRoundF32x8, LScalarTruncF32x8, LSSE2RoundF32x8, LSSE2TruncF32x8, LAVX2RoundF32x8, LAVX2TruncF32x8: TVecF32x8;
  LInF64x4, LScalarRoundF64x4, LScalarTruncF64x4, LSSE2RoundF64x4, LSSE2TruncF64x4, LAVX2RoundF64x4, LAVX2TruncF64x4: TVecF64x4;
  LInF32x16, LScalarRoundF32x16, LScalarTruncF32x16, LSSE2RoundF32x16, LSSE2TruncF32x16, LAVX2RoundF32x16, LAVX2TruncF32x16: TVecF32x16;
  LInF64x8, LScalarRoundF64x8, LScalarTruncF64x8, LSSE2RoundF64x8, LSSE2TruncF64x8, LAVX2RoundF64x8, LAVX2TruncF64x8: TVecF64x8;

  procedure AssertSingleSemantics(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertSingleZeroSign(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if (aExpected = 0.0) and (aActual = 0.0) then
      CheckTrue(BitsFromSingle(aExpected) = BitsFromSingle(aActual), aPrefix + ' zero sign bit');
  end;

  procedure AssertDoubleZeroSign(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if (aExpected = 0.0) and (aActual = 0.0) then
      CheckTrue(BitsFromDouble(aExpected) = BitsFromDouble(aActual), aPrefix + ' zero sign bit');
  end;

begin
  if not IsBackendRegistered(sbAVX2) then
    Exit;

  LHaveSSE2 := IsBackendRegistered(sbSSE2);
  LInF32x8.f[0] := 0.0;
  LInF32x8.f[1] := -0.0;
  LInF32x8.f[2] := 0.25;
  LInF32x8.f[3] := -0.25;
  LInF32x8.f[4] := 0.5;
  LInF32x8.f[5] := -0.5;
  LInF32x8.f[6] := 1.0e-30;
  LInF32x8.f[7] := -1.0e-30;

  LInF64x4.d[0] := 0.0;
  LInF64x4.d[1] := -0.0;
  LInF64x4.d[2] := 0.25;
  LInF64x4.d[3] := -0.25;

  for LIndex := 0 to 15 do
    LInF32x16.f[LIndex] := LInF32x8.f[LIndex and 7];
  LInF32x16.f[8] := 1.0e-20;
  LInF32x16.f[9] := -1.0e-20;

  for LIndex := 0 to 7 do
    LInF64x8.d[LIndex] := LInF64x4.d[LIndex and 3];
  LInF64x8.d[4] := 1.0e-100;
  LInF64x8.d[5] := -1.0e-100;

  SetVectorAsmEnabled(False);
    SetActiveBackend(sbScalar);
    LDispatch := GetDispatchTable;
    CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4), 'Scalar dispatch should provide wide Round/Trunc');

    LScalarRoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
    LScalarTruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
    LScalarRoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
    LScalarTruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
    LScalarRoundF32x16 := VecF32x16Round(LInF32x16);
    LScalarTruncF32x16 := VecF32x16Trunc(LInF32x16);
    LScalarRoundF64x8 := VecF64x8Round(LInF64x8);
    LScalarTruncF64x8 := VecF64x8Trunc(LInF64x8);

    if LHaveSSE2 then
    begin
      SetVectorAsmEnabled(True);
      SetActiveBackend(sbSSE2);
      LDispatch := GetDispatchTable;
      CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4), 'SSE2 dispatch should provide wide Round/Trunc');

      LSSE2RoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
      LSSE2TruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
      LSSE2RoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
      LSSE2TruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
      LSSE2RoundF32x16 := VecF32x16Round(LInF32x16);
      LSSE2TruncF32x16 := VecF32x16Trunc(LInF32x16);
      LSSE2RoundF64x8 := VecF64x8Round(LInF64x8);
      LSSE2TruncF64x8 := VecF64x8Trunc(LInF64x8);
    end;

    SetVectorAsmEnabled(True);
    SetActiveBackend(sbAVX2);
    if GetActiveBackend <> sbAVX2 then
      Exit;

    LDispatch := GetDispatchTable;
    CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4), 'AVX2 dispatch should provide wide Round/Trunc');

    LAVX2RoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
    LAVX2TruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
    LAVX2RoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
    LAVX2TruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
    LAVX2RoundF32x16 := VecF32x16Round(LInF32x16);
    LAVX2TruncF32x16 := VecF32x16Trunc(LInF32x16);
    LAVX2RoundF64x8 := VecF64x8Round(LInF64x8);
    LAVX2TruncF64x8 := VecF64x8Trunc(LInF64x8);

    for LIndex := 0 to 7 do
    begin
      AssertSingleSemantics('AVX2 vs Scalar RoundF32x8[' + IntToStr(LIndex) + ']', LScalarRoundF32x8.f[LIndex], LAVX2RoundF32x8.f[LIndex]);
      AssertSingleSemantics('AVX2 vs Scalar TruncF32x8[' + IntToStr(LIndex) + ']', LScalarTruncF32x8.f[LIndex], LAVX2TruncF32x8.f[LIndex]);
      AssertSingleZeroSign('AVX2 vs Scalar RoundF32x8[' + IntToStr(LIndex) + ']', LScalarRoundF32x8.f[LIndex], LAVX2RoundF32x8.f[LIndex]);
      AssertSingleZeroSign('AVX2 vs Scalar TruncF32x8[' + IntToStr(LIndex) + ']', LScalarTruncF32x8.f[LIndex], LAVX2TruncF32x8.f[LIndex]);
      if LHaveSSE2 then
      begin
        AssertSingleSemantics('AVX2 vs SSE2 RoundF32x8[' + IntToStr(LIndex) + ']', LSSE2RoundF32x8.f[LIndex], LAVX2RoundF32x8.f[LIndex]);
        AssertSingleSemantics('AVX2 vs SSE2 TruncF32x8[' + IntToStr(LIndex) + ']', LSSE2TruncF32x8.f[LIndex], LAVX2TruncF32x8.f[LIndex]);
        AssertSingleZeroSign('AVX2 vs SSE2 RoundF32x8[' + IntToStr(LIndex) + ']', LSSE2RoundF32x8.f[LIndex], LAVX2RoundF32x8.f[LIndex]);
        AssertSingleZeroSign('AVX2 vs SSE2 TruncF32x8[' + IntToStr(LIndex) + ']', LSSE2TruncF32x8.f[LIndex], LAVX2TruncF32x8.f[LIndex]);
      end;
    end;

    for LIndex := 0 to 3 do
    begin
      AssertDoubleSemantics('AVX2 vs Scalar RoundF64x4[' + IntToStr(LIndex) + ']', LScalarRoundF64x4.d[LIndex], LAVX2RoundF64x4.d[LIndex]);
      AssertDoubleSemantics('AVX2 vs Scalar TruncF64x4[' + IntToStr(LIndex) + ']', LScalarTruncF64x4.d[LIndex], LAVX2TruncF64x4.d[LIndex]);
      AssertDoubleZeroSign('AVX2 vs Scalar RoundF64x4[' + IntToStr(LIndex) + ']', LScalarRoundF64x4.d[LIndex], LAVX2RoundF64x4.d[LIndex]);
      AssertDoubleZeroSign('AVX2 vs Scalar TruncF64x4[' + IntToStr(LIndex) + ']', LScalarTruncF64x4.d[LIndex], LAVX2TruncF64x4.d[LIndex]);
      if LHaveSSE2 then
      begin
        AssertDoubleSemantics('AVX2 vs SSE2 RoundF64x4[' + IntToStr(LIndex) + ']', LSSE2RoundF64x4.d[LIndex], LAVX2RoundF64x4.d[LIndex]);
        AssertDoubleSemantics('AVX2 vs SSE2 TruncF64x4[' + IntToStr(LIndex) + ']', LSSE2TruncF64x4.d[LIndex], LAVX2TruncF64x4.d[LIndex]);
        AssertDoubleZeroSign('AVX2 vs SSE2 RoundF64x4[' + IntToStr(LIndex) + ']', LSSE2RoundF64x4.d[LIndex], LAVX2RoundF64x4.d[LIndex]);
        AssertDoubleZeroSign('AVX2 vs SSE2 TruncF64x4[' + IntToStr(LIndex) + ']', LSSE2TruncF64x4.d[LIndex], LAVX2TruncF64x4.d[LIndex]);
      end;
    end;

    for LIndex := 0 to 15 do
    begin
      AssertSingleSemantics('AVX2 vs Scalar RoundF32x16[' + IntToStr(LIndex) + ']', LScalarRoundF32x16.f[LIndex], LAVX2RoundF32x16.f[LIndex]);
      AssertSingleSemantics('AVX2 vs Scalar TruncF32x16[' + IntToStr(LIndex) + ']', LScalarTruncF32x16.f[LIndex], LAVX2TruncF32x16.f[LIndex]);
      AssertSingleZeroSign('AVX2 vs Scalar RoundF32x16[' + IntToStr(LIndex) + ']', LScalarRoundF32x16.f[LIndex], LAVX2RoundF32x16.f[LIndex]);
      AssertSingleZeroSign('AVX2 vs Scalar TruncF32x16[' + IntToStr(LIndex) + ']', LScalarTruncF32x16.f[LIndex], LAVX2TruncF32x16.f[LIndex]);
      if LHaveSSE2 then
      begin
        AssertSingleSemantics('AVX2 vs SSE2 RoundF32x16[' + IntToStr(LIndex) + ']', LSSE2RoundF32x16.f[LIndex], LAVX2RoundF32x16.f[LIndex]);
        AssertSingleSemantics('AVX2 vs SSE2 TruncF32x16[' + IntToStr(LIndex) + ']', LSSE2TruncF32x16.f[LIndex], LAVX2TruncF32x16.f[LIndex]);
        AssertSingleZeroSign('AVX2 vs SSE2 RoundF32x16[' + IntToStr(LIndex) + ']', LSSE2RoundF32x16.f[LIndex], LAVX2RoundF32x16.f[LIndex]);
        AssertSingleZeroSign('AVX2 vs SSE2 TruncF32x16[' + IntToStr(LIndex) + ']', LSSE2TruncF32x16.f[LIndex], LAVX2TruncF32x16.f[LIndex]);
      end;
    end;

    for LIndex := 0 to 7 do
    begin
      AssertDoubleSemantics('AVX2 vs Scalar RoundF64x8[' + IntToStr(LIndex) + ']', LScalarRoundF64x8.d[LIndex], LAVX2RoundF64x8.d[LIndex]);
      AssertDoubleSemantics('AVX2 vs Scalar TruncF64x8[' + IntToStr(LIndex) + ']', LScalarTruncF64x8.d[LIndex], LAVX2TruncF64x8.d[LIndex]);
      AssertDoubleZeroSign('AVX2 vs Scalar RoundF64x8[' + IntToStr(LIndex) + ']', LScalarRoundF64x8.d[LIndex], LAVX2RoundF64x8.d[LIndex]);
      AssertDoubleZeroSign('AVX2 vs Scalar TruncF64x8[' + IntToStr(LIndex) + ']', LScalarTruncF64x8.d[LIndex], LAVX2TruncF64x8.d[LIndex]);
      if LHaveSSE2 then
      begin
        AssertDoubleSemantics('AVX2 vs SSE2 RoundF64x8[' + IntToStr(LIndex) + ']', LSSE2RoundF64x8.d[LIndex], LAVX2RoundF64x8.d[LIndex]);
        AssertDoubleSemantics('AVX2 vs SSE2 TruncF64x8[' + IntToStr(LIndex) + ']', LSSE2TruncF64x8.d[LIndex], LAVX2TruncF64x8.d[LIndex]);
        AssertDoubleZeroSign('AVX2 vs SSE2 RoundF64x8[' + IntToStr(LIndex) + ']', LSSE2RoundF64x8.d[LIndex], LAVX2RoundF64x8.d[LIndex]);
        AssertDoubleZeroSign('AVX2 vs SSE2 TruncF64x8[' + IntToStr(LIndex) + ']', LSSE2TruncF64x8.d[LIndex], LAVX2TruncF64x8.d[LIndex]);
      end;
    end;
end;

procedure TTestCase_NonX86IEEE754.Test_NonX86_RoundTruncFloorCeil_NaNInf_IfAvailable;
const
  NON_X86_BACKENDS: array[0..1] of TSimdBackend = (sbNEON, sbRISCVV);
var
  LBackend: TSimdBackend;
  LCheckedBackends: Integer;
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;

  LInF32x4, LExpectedRoundF32x4, LExpectedTruncF32x4, LExpectedFloorF32x4, LExpectedCeilF32x4: TVecF32x4;
  LActualRoundF32x4, LActualTruncF32x4, LActualFloorF32x4, LActualCeilF32x4: TVecF32x4;
  LInF64x2, LExpectedRoundF64x2, LExpectedTruncF64x2, LExpectedFloorF64x2, LExpectedCeilF64x2: TVecF64x2;
  LActualRoundF64x2, LActualTruncF64x2, LActualFloorF64x2, LActualCeilF64x2: TVecF64x2;
  LInSignedZeroF32x4, LExpectedRoundSignedZeroF32x4, LExpectedTruncSignedZeroF32x4: TVecF32x4;
  LActualRoundSignedZeroF32x4, LActualTruncSignedZeroF32x4: TVecF32x4;
  LInSignedZeroF64x2, LExpectedRoundSignedZeroF64x2, LExpectedTruncSignedZeroF64x2: TVecF64x2;
  LActualRoundSignedZeroF64x2, LActualTruncSignedZeroF64x2: TVecF64x2;

  procedure AssertSingleSemantics(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 1e-6, aPrefix);
  end;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 1e-12, aPrefix);
  end;

  procedure AssertSingleZeroSign(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if (aExpected = 0.0) and (aActual = 0.0) then
      CheckTrue(BitsFromSingle(aExpected) = BitsFromSingle(aActual), aPrefix + ' zero sign bit');
  end;

  procedure AssertDoubleZeroSign(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if (aExpected = 0.0) and (aActual = 0.0) then
      CheckTrue(BitsFromDouble(aExpected) = BitsFromDouble(aActual), aPrefix + ' zero sign bit');
  end;
begin
  LCheckedBackends := 0;

  LInF32x4.f[0] := NaNF32;
  LInF32x4.f[1] := PosInfF32;
  LInF32x4.f[2] := NegInfF32;
  LInF32x4.f[3] := -2.75;

  LInF64x2.d[0] := NaNF64;
  LInF64x2.d[1] := PosInfF64;

  LInSignedZeroF32x4.f[0] := 0.0;
  LInSignedZeroF32x4.f[1] := NegZeroF32;
  LInSignedZeroF32x4.f[2] := 0.25;
  LInSignedZeroF32x4.f[3] := -0.25;

  LInSignedZeroF64x2.d[0] := 0.25;
  LInSignedZeroF64x2.d[1] := -0.25;

  for LBackend in NON_X86_BACKENDS do
  begin
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);
    try
      LDispatch := GetDispatchTable;
      CheckNotNil(LDispatch, 'Dispatch table should be available');
      CheckTrue(Assigned(LDispatch^.RoundF32x4) and Assigned(LDispatch^.TruncF32x4) and Assigned(LDispatch^.FloorF32x4) and Assigned(LDispatch^.CeilF32x4), 'Round/Trunc/Floor/Ceil F32x4 should be assigned');
      CheckTrue(Assigned(LDispatch^.RoundF64x2) and Assigned(LDispatch^.TruncF64x2) and Assigned(LDispatch^.FloorF64x2) and Assigned(LDispatch^.CeilF64x2), 'Round/Trunc/Floor/Ceil F64x2 should be assigned');

      SetActiveBackend(sbScalar);
      LDispatch := GetDispatchTable;
      LExpectedRoundF32x4 := LDispatch^.RoundF32x4(LInF32x4);
      LExpectedTruncF32x4 := LDispatch^.TruncF32x4(LInF32x4);
      LExpectedFloorF32x4 := LDispatch^.FloorF32x4(LInF32x4);
      LExpectedCeilF32x4 := LDispatch^.CeilF32x4(LInF32x4);
      LExpectedRoundF64x2 := LDispatch^.RoundF64x2(LInF64x2);
      LExpectedTruncF64x2 := LDispatch^.TruncF64x2(LInF64x2);
      LExpectedFloorF64x2 := LDispatch^.FloorF64x2(LInF64x2);
      LExpectedCeilF64x2 := LDispatch^.CeilF64x2(LInF64x2);
      LExpectedRoundSignedZeroF32x4 := LDispatch^.RoundF32x4(LInSignedZeroF32x4);
      LExpectedTruncSignedZeroF32x4 := LDispatch^.TruncF32x4(LInSignedZeroF32x4);
      LExpectedRoundSignedZeroF64x2 := LDispatch^.RoundF64x2(LInSignedZeroF64x2);
      LExpectedTruncSignedZeroF64x2 := LDispatch^.TruncF64x2(LInSignedZeroF64x2);

      SetActiveBackend(LBackend);
      LDispatch := GetDispatchTable;
      LActualRoundF32x4 := LDispatch^.RoundF32x4(LInF32x4);
      LActualTruncF32x4 := LDispatch^.TruncF32x4(LInF32x4);
      LActualFloorF32x4 := LDispatch^.FloorF32x4(LInF32x4);
      LActualCeilF32x4 := LDispatch^.CeilF32x4(LInF32x4);
      LActualRoundF64x2 := LDispatch^.RoundF64x2(LInF64x2);
      LActualTruncF64x2 := LDispatch^.TruncF64x2(LInF64x2);
      LActualFloorF64x2 := LDispatch^.FloorF64x2(LInF64x2);
      LActualCeilF64x2 := LDispatch^.CeilF64x2(LInF64x2);
      LActualRoundSignedZeroF32x4 := LDispatch^.RoundF32x4(LInSignedZeroF32x4);
      LActualTruncSignedZeroF32x4 := LDispatch^.TruncF32x4(LInSignedZeroF32x4);
      LActualRoundSignedZeroF64x2 := LDispatch^.RoundF64x2(LInSignedZeroF64x2);
      LActualTruncSignedZeroF64x2 := LDispatch^.TruncF64x2(LInSignedZeroF64x2);

      for LIndex := 0 to 3 do
      begin
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' RoundF32x4[' + IntToStr(LIndex) + ']', LExpectedRoundF32x4.f[LIndex], LActualRoundF32x4.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' TruncF32x4[' + IntToStr(LIndex) + ']', LExpectedTruncF32x4.f[LIndex], LActualTruncF32x4.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' FloorF32x4[' + IntToStr(LIndex) + ']', LExpectedFloorF32x4.f[LIndex], LActualFloorF32x4.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' CeilF32x4[' + IntToStr(LIndex) + ']', LExpectedCeilF32x4.f[LIndex], LActualCeilF32x4.f[LIndex]);

        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' SignedZero RoundF32x4[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF32x4.f[LIndex], LActualRoundSignedZeroF32x4.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' SignedZero TruncF32x4[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF32x4.f[LIndex], LActualTruncSignedZeroF32x4.f[LIndex]);
        AssertSingleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero RoundF32x4[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF32x4.f[LIndex], LActualRoundSignedZeroF32x4.f[LIndex]);
        AssertSingleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero TruncF32x4[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF32x4.f[LIndex], LActualTruncSignedZeroF32x4.f[LIndex]);
      end;

      for LIndex := 0 to 1 do
      begin
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' RoundF64x2[' + IntToStr(LIndex) + ']', LExpectedRoundF64x2.d[LIndex], LActualRoundF64x2.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' TruncF64x2[' + IntToStr(LIndex) + ']', LExpectedTruncF64x2.d[LIndex], LActualTruncF64x2.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' FloorF64x2[' + IntToStr(LIndex) + ']', LExpectedFloorF64x2.d[LIndex], LActualFloorF64x2.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' CeilF64x2[' + IntToStr(LIndex) + ']', LExpectedCeilF64x2.d[LIndex], LActualCeilF64x2.d[LIndex]);

        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' SignedZero RoundF64x2[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF64x2.d[LIndex], LActualRoundSignedZeroF64x2.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' SignedZero TruncF64x2[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF64x2.d[LIndex], LActualTruncSignedZeroF64x2.d[LIndex]);
        AssertDoubleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero RoundF64x2[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF64x2.d[LIndex], LActualRoundSignedZeroF64x2.d[LIndex]);
        AssertDoubleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero TruncF64x2[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF64x2.d[LIndex], LActualTruncSignedZeroF64x2.d[LIndex]);
      end;
    finally
      ResetToAutomaticBackend;
    end;
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 backend available on this host (allowed)');
end;

procedure TTestCase_NonX86IEEE754.Test_NonX86_NarrowF64x2_RoundTruncFloorCeil_Finite_IfAvailable;
const
  NON_X86_BACKENDS: array[0..1] of TSimdBackend = (sbNEON, sbRISCVV);
  SAMPLE_CASE_COUNT = 3;
var
  LBackend: TSimdBackend;
  LCheckedBackends: Integer;
  LDispatch: PSimdDispatchTable;
  LCaseIndex: Integer;
  LLaneIndex: Integer;
  LInputs: array[0..SAMPLE_CASE_COUNT - 1] of TVecF64x2;
  LExpectedRound: array[0..SAMPLE_CASE_COUNT - 1] of TVecF64x2;
  LExpectedTrunc: array[0..SAMPLE_CASE_COUNT - 1] of TVecF64x2;
  LExpectedFloor: array[0..SAMPLE_CASE_COUNT - 1] of TVecF64x2;
  LExpectedCeil: array[0..SAMPLE_CASE_COUNT - 1] of TVecF64x2;
  LActualRound: array[0..SAMPLE_CASE_COUNT - 1] of TVecF64x2;
  LActualTrunc: array[0..SAMPLE_CASE_COUNT - 1] of TVecF64x2;
  LActualFloor: array[0..SAMPLE_CASE_COUNT - 1] of TVecF64x2;
  LActualCeil: array[0..SAMPLE_CASE_COUNT - 1] of TVecF64x2;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;
begin
  LCheckedBackends := 0;

  LInputs[0].d[0] := 1.25;
  LInputs[0].d[1] := -1.25;
  LInputs[1].d[0] := 1.75;
  LInputs[1].d[1] := -1.75;
  LInputs[2].d[0] := 2.5;
  LInputs[2].d[1] := -2.5;

  SetVectorAsmEnabled(True);

    for LBackend in NON_X86_BACKENDS do
    begin
      if not IsBackendRegistered(LBackend) then
        Continue;
      if not TrySetActiveBackend(LBackend) then
        Continue;

      Inc(LCheckedBackends);
      try
        LDispatch := GetDispatchTable;
        CheckNotNil(LDispatch, 'Dispatch table should be available');
        CheckTrue(Assigned(LDispatch^.RoundF64x2) and Assigned(LDispatch^.TruncF64x2) and Assigned(LDispatch^.FloorF64x2) and Assigned(LDispatch^.CeilF64x2), 'Round/Trunc/Floor/Ceil F64x2 should be assigned');

        SetActiveBackend(sbScalar);
        LDispatch := GetDispatchTable;
        CheckNotNil(LDispatch, 'Scalar dispatch should be available');
        for LCaseIndex := 0 to SAMPLE_CASE_COUNT - 1 do
        begin
          LExpectedRound[LCaseIndex] := LDispatch^.RoundF64x2(LInputs[LCaseIndex]);
          LExpectedTrunc[LCaseIndex] := LDispatch^.TruncF64x2(LInputs[LCaseIndex]);
          LExpectedFloor[LCaseIndex] := LDispatch^.FloorF64x2(LInputs[LCaseIndex]);
          LExpectedCeil[LCaseIndex] := LDispatch^.CeilF64x2(LInputs[LCaseIndex]);
        end;

        SetActiveBackend(LBackend);
        LDispatch := GetDispatchTable;
        CheckNotNil(LDispatch, 'Non-x86 dispatch should be available');
        for LCaseIndex := 0 to SAMPLE_CASE_COUNT - 1 do
        begin
          LActualRound[LCaseIndex] := LDispatch^.RoundF64x2(LInputs[LCaseIndex]);
          LActualTrunc[LCaseIndex] := LDispatch^.TruncF64x2(LInputs[LCaseIndex]);
          LActualFloor[LCaseIndex] := LDispatch^.FloorF64x2(LInputs[LCaseIndex]);
          LActualCeil[LCaseIndex] := LDispatch^.CeilF64x2(LInputs[LCaseIndex]);
        end;

        for LCaseIndex := 0 to SAMPLE_CASE_COUNT - 1 do
          for LLaneIndex := 0 to 1 do
          begin
            AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Case ' + IntToStr(LCaseIndex) +
              ' RoundF64x2[' + IntToStr(LLaneIndex) + ']', LExpectedRound[LCaseIndex].d[LLaneIndex], LActualRound[LCaseIndex].d[LLaneIndex]);
            AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Case ' + IntToStr(LCaseIndex) +
              ' TruncF64x2[' + IntToStr(LLaneIndex) + ']', LExpectedTrunc[LCaseIndex].d[LLaneIndex], LActualTrunc[LCaseIndex].d[LLaneIndex]);
            AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Case ' + IntToStr(LCaseIndex) +
              ' FloorF64x2[' + IntToStr(LLaneIndex) + ']', LExpectedFloor[LCaseIndex].d[LLaneIndex], LActualFloor[LCaseIndex].d[LLaneIndex]);
            AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Case ' + IntToStr(LCaseIndex) +
              ' CeilF64x2[' + IntToStr(LLaneIndex) + ']', LExpectedCeil[LCaseIndex].d[LLaneIndex], LActualCeil[LCaseIndex].d[LLaneIndex]);
          end;
      finally
        ResetToAutomaticBackend;
      end;
    end;

    if LCheckedBackends = 0 then
      CheckTrue(True, 'No non-x86 backend available on this host (allowed)');
end;

procedure TTestCase_NonX86IEEE754.Test_RISCVV_WideClampF32_SpecialCases_IfAvailable;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LInputF32x8: TVecF32x8;
  LMinValF32x8: TVecF32x8;
  LMaxValF32x8: TVecF32x8;
  LExpectedF32x8: TVecF32x8;
  LActualF32x8: TVecF32x8;
  LInputF32x16: TVecF32x16;
  LMinValF32x16: TVecF32x16;
  LMaxValF32x16: TVecF32x16;
  LExpectedF32x16: TVecF32x16;
  LActualF32x16: TVecF32x16;

  procedure AssertSingleParity(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
    begin
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
      if aExpected = 0.0 then
        CheckTrue(BitsFromSingle(aExpected) = BitsFromSingle(aActual), aPrefix + ' zero sign');
    end;
  end;

  procedure AssertVecParityF32x8(const aLabel: string);
  var
    LLocalLaneIndex: Integer;
  begin
    LExpectedF32x8 := LScalarTable.ClampF32x8(LInputF32x8, LMinValF32x8, LMaxValF32x8);
    LActualF32x8 := LRISCVVTable.ClampF32x8(LInputF32x8, LMinValF32x8, LMaxValF32x8);
    for LLocalLaneIndex := 0 to 7 do
      AssertSingleParity(aLabel + '[' + IntToStr(LLocalLaneIndex) + ']', LExpectedF32x8.f[LLocalLaneIndex], LActualF32x8.f[LLocalLaneIndex]);
  end;

  procedure AssertVecParityF32x16(const aLabel: string);
  var
    LLocalLaneIndex: Integer;
  begin
    LExpectedF32x16 := LScalarTable.ClampF32x16(LInputF32x16, LMinValF32x16, LMaxValF32x16);
    LActualF32x16 := LRISCVVTable.ClampF32x16(LInputF32x16, LMinValF32x16, LMaxValF32x16);
    for LLocalLaneIndex := 0 to 15 do
      AssertSingleParity(aLabel + '[' + IntToStr(LLocalLaneIndex) + ']', LExpectedF32x16.f[LLocalLaneIndex], LActualF32x16.f[LLocalLaneIndex]);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
  begin
    CheckTrue(True, 'RISCVV backend not registered on this host (allowed)');
    Exit;
  end;
  {$ENDIF}

  CheckTrue(Assigned(LRISCVVTable.ClampF32x8) and Assigned(LRISCVVTable.ClampF32x16), 'RISCVV dispatch should provide wide F32 clamp helpers');

  LInputF32x8.f[0] := NaNF32;
  LInputF32x8.f[1] := 3.0;
  LInputF32x8.f[2] := 0.0;
  LInputF32x8.f[3] := NegZeroF32;
  LInputF32x8.f[4] := -5.0;
  LInputF32x8.f[5] := 9.0;
  LInputF32x8.f[6] := 2.5;
  LInputF32x8.f[7] := 10.0;
  LMinValF32x8.f[0] := 0.0;
  LMinValF32x8.f[1] := 1.0;
  LMinValF32x8.f[2] := NegZeroF32;
  LMinValF32x8.f[3] := 0.0;
  LMinValF32x8.f[4] := -4.0;
  LMinValF32x8.f[5] := 0.0;
  LMinValF32x8.f[6] := 2.0;
  LMinValF32x8.f[7] := 8.0;
  LMaxValF32x8.f[0] := 10.0;
  LMaxValF32x8.f[1] := 2.0;
  LMaxValF32x8.f[2] := 0.0;
  LMaxValF32x8.f[3] := 0.0;
  LMaxValF32x8.f[4] := 4.0;
  LMaxValF32x8.f[5] := 8.0;
  LMaxValF32x8.f[6] := 3.0;
  LMaxValF32x8.f[7] := 9.0;
  AssertVecParityF32x8('RISCVV ClampF32x8 NaNLeadingSignedZero');

  LInputF32x8.f[0] := 3.0;
  LInputF32x8.f[1] := NaNF32;
  LInputF32x8.f[2] := NegZeroF32;
  LInputF32x8.f[3] := 0.0;
  LInputF32x8.f[4] := -6.0;
  LInputF32x8.f[5] := 11.0;
  LInputF32x8.f[6] := 2.0;
  LInputF32x8.f[7] := 1.5;
  LMinValF32x8.f[0] := 1.0;
  LMinValF32x8.f[1] := 0.0;
  LMinValF32x8.f[2] := 0.0;
  LMinValF32x8.f[3] := NegZeroF32;
  LMinValF32x8.f[4] := -5.0;
  LMinValF32x8.f[5] := 1.0;
  LMinValF32x8.f[6] := 2.0;
  LMinValF32x8.f[7] := 1.0;
  LMaxValF32x8.f[0] := 2.0;
  LMaxValF32x8.f[1] := 10.0;
  LMaxValF32x8.f[2] := 0.0;
  LMaxValF32x8.f[3] := 0.0;
  LMaxValF32x8.f[4] := 4.0;
  LMaxValF32x8.f[5] := 10.0;
  LMaxValF32x8.f[6] := 2.0;
  LMaxValF32x8.f[7] := 1.0;
  AssertVecParityF32x8('RISCVV ClampF32x8 NaNSecondSignedZero');

  LInputF32x16.f[0] := NaNF32;
  LInputF32x16.f[1] := 3.0;
  LInputF32x16.f[2] := 0.0;
  LInputF32x16.f[3] := NegZeroF32;
  LInputF32x16.f[4] := -5.0;
  LInputF32x16.f[5] := 9.0;
  LInputF32x16.f[6] := 2.5;
  LInputF32x16.f[7] := 10.0;
  LInputF32x16.f[8] := -1.0;
  LInputF32x16.f[9] := 0.25;
  LInputF32x16.f[10] := 7.5;
  LInputF32x16.f[11] := 12.0;
  LInputF32x16.f[12] := 4.0;
  LInputF32x16.f[13] := 6.0;
  LInputF32x16.f[14] := 1.0;
  LInputF32x16.f[15] := 5.0;
  LMinValF32x16.f[0] := 0.0;
  LMinValF32x16.f[1] := 1.0;
  LMinValF32x16.f[2] := NegZeroF32;
  LMinValF32x16.f[3] := 0.0;
  LMinValF32x16.f[4] := -4.0;
  LMinValF32x16.f[5] := 0.0;
  LMinValF32x16.f[6] := 2.0;
  LMinValF32x16.f[7] := 8.0;
  LMinValF32x16.f[8] := -0.5;
  LMinValF32x16.f[9] := 0.0;
  LMinValF32x16.f[10] := 6.0;
  LMinValF32x16.f[11] := 10.0;
  LMinValF32x16.f[12] := 2.0;
  LMinValF32x16.f[13] := 5.0;
  LMinValF32x16.f[14] := 1.0;
  LMinValF32x16.f[15] := 4.0;
  LMaxValF32x16.f[0] := 10.0;
  LMaxValF32x16.f[1] := 2.0;
  LMaxValF32x16.f[2] := 0.0;
  LMaxValF32x16.f[3] := 0.0;
  LMaxValF32x16.f[4] := 4.0;
  LMaxValF32x16.f[5] := 8.0;
  LMaxValF32x16.f[6] := 3.0;
  LMaxValF32x16.f[7] := 9.0;
  LMaxValF32x16.f[8] := 0.0;
  LMaxValF32x16.f[9] := 1.0;
  LMaxValF32x16.f[10] := 7.0;
  LMaxValF32x16.f[11] := 11.0;
  LMaxValF32x16.f[12] := 3.0;
  LMaxValF32x16.f[13] := 5.5;
  LMaxValF32x16.f[14] := 1.0;
  LMaxValF32x16.f[15] := 4.5;
  AssertVecParityF32x16('RISCVV ClampF32x16 NaNLeadingSignedZero');

  LInputF32x16.f[0] := 3.0;
  LInputF32x16.f[1] := NaNF32;
  LInputF32x16.f[2] := NegZeroF32;
  LInputF32x16.f[3] := 0.0;
  LInputF32x16.f[4] := -6.0;
  LInputF32x16.f[5] := 11.0;
  LInputF32x16.f[6] := 2.0;
  LInputF32x16.f[7] := 1.5;
  LInputF32x16.f[8] := -2.0;
  LInputF32x16.f[9] := 2.0;
  LInputF32x16.f[10] := 8.5;
  LInputF32x16.f[11] := 9.5;
  LInputF32x16.f[12] := 4.0;
  LInputF32x16.f[13] := 5.0;
  LInputF32x16.f[14] := 1.0;
  LInputF32x16.f[15] := 3.5;
  LMinValF32x16.f[0] := 1.0;
  LMinValF32x16.f[1] := 0.0;
  LMinValF32x16.f[2] := 0.0;
  LMinValF32x16.f[3] := NegZeroF32;
  LMinValF32x16.f[4] := -5.0;
  LMinValF32x16.f[5] := 1.0;
  LMinValF32x16.f[6] := 2.0;
  LMinValF32x16.f[7] := 1.0;
  LMinValF32x16.f[8] := -1.5;
  LMinValF32x16.f[9] := 1.0;
  LMinValF32x16.f[10] := 7.0;
  LMinValF32x16.f[11] := 9.0;
  LMinValF32x16.f[12] := 4.0;
  LMinValF32x16.f[13] := 5.0;
  LMinValF32x16.f[14] := 1.0;
  LMinValF32x16.f[15] := 4.0;
  LMaxValF32x16.f[0] := 2.0;
  LMaxValF32x16.f[1] := 10.0;
  LMaxValF32x16.f[2] := 0.0;
  LMaxValF32x16.f[3] := 0.0;
  LMaxValF32x16.f[4] := 4.0;
  LMaxValF32x16.f[5] := 10.0;
  LMaxValF32x16.f[6] := 2.0;
  LMaxValF32x16.f[7] := 1.0;
  LMaxValF32x16.f[8] := -0.5;
  LMaxValF32x16.f[9] := 1.5;
  LMaxValF32x16.f[10] := 8.0;
  LMaxValF32x16.f[11] := 9.0;
  LMaxValF32x16.f[12] := 4.0;
  LMaxValF32x16.f[13] := 5.0;
  LMaxValF32x16.f[14] := 1.0;
  LMaxValF32x16.f[15] := 4.0;
  AssertVecParityF32x16('RISCVV ClampF32x16 NaNSecondSignedZero');
end;

procedure TTestCase_NonX86IEEE754.Test_RISCVV_DotF64_DirectRegisteredTable_SpecialCases_IfRegistered;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LA2, LB2: TVecF64x2;
  LA4, LB4: TVecF64x4;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
    begin
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
      if aExpected = 0.0 then
        CheckTrue(BitsFromDouble(aExpected) = BitsFromDouble(aActual), aPrefix + ' zero sign bit');
    end;
  end;

  procedure AssertDotF64x2Case(const aLabel: string; const aA, aB: TVecF64x2);
  var
    LExpected: Double;
    LActual: Double;
  begin
    LExpected := LScalarTable.DotF64x2(aA, aB);
    LActual := LRISCVVTable.DotF64x2(aA, aB);
    AssertDoubleSemantics('RISCVV direct DotF64x2 ' + aLabel, LExpected, LActual);
  end;

  procedure AssertDotF64x4Case(const aLabel: string; const aA, aB: TVecF64x4);
  var
    LExpected: Double;
    LActual: Double;
  begin
    LExpected := LScalarTable.DotF64x4(aA, aB);
    LActual := LRISCVVTable.DotF64x4(aA, aB);
    AssertDoubleSemantics('RISCVV direct DotF64x4 ' + aLabel, LExpected, LActual);
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
  begin
    CheckTrue(True, 'RISCVV backend not registered on this host (allowed)');
    Exit;
  end;
  {$ENDIF}

  CheckTrue(Assigned(LRISCVVTable.DotF64x2) and Assigned(LRISCVVTable.DotF64x4), 'RISCVV registered table should provide DotF64 slots');

  CheckTrue((PtrUInt(LScalarTable.DotF64x2) <> PtrUInt(LRISCVVTable.DotF64x2)) and (PtrUInt(LScalarTable.DotF64x4) <> PtrUInt(LRISCVVTable.DotF64x4)), 'RISCVV DotF64 registered slots should stay backend-owned in the registered table');

  LA2.d[0] := NegZeroF64;
  LA2.d[1] := 2.0;
  LB2.d[0] := 1.0;
  LB2.d[1] := 0.0;
  AssertDotF64x2Case('signed-zero lane', LA2, LB2);

  LA2.d[0] := PosInfF64;
  LA2.d[1] := 1.0;
  LB2.d[0] := 1.0;
  LB2.d[1] := 0.0;
  AssertDotF64x2Case('positive-inf lane', LA2, LB2);

  LA2.d[0] := NaNF64;
  LA2.d[1] := 3.0;
  LB2.d[0] := 1.0;
  LB2.d[1] := 2.0;
  AssertDotF64x2Case('nan lane', LA2, LB2);

  LA4.d[0] := NegZeroF64;
  LA4.d[1] := 0.0;
  LA4.d[2] := 4.0;
  LA4.d[3] := -4.0;
  LB4.d[0] := 1.0;
  LB4.d[1] := 0.0;
  LB4.d[2] := 0.0;
  LB4.d[3] := 0.0;
  AssertDotF64x4Case('signed-zero lane', LA4, LB4);

  LA4.d[0] := PosInfF64;
  LA4.d[1] := 1.0;
  LA4.d[2] := 2.0;
  LA4.d[3] := 3.0;
  LB4.d[0] := 1.0;
  LB4.d[1] := 0.0;
  LB4.d[2] := 0.0;
  LB4.d[3] := 0.0;
  AssertDotF64x4Case('positive-inf lane', LA4, LB4);

  LA4.d[0] := NaNF64;
  LA4.d[1] := 1.0;
  LA4.d[2] := 2.0;
  LA4.d[3] := 3.0;
  LB4.d[0] := 1.0;
  LB4.d[1] := 0.0;
  LB4.d[2] := 0.0;
  LB4.d[3] := 0.0;
  AssertDotF64x4Case('nan lane', LA4, LB4);
end;

procedure TTestCase_NonX86IEEE754.Test_RISCVV_WideRoundTrunc_DirectRegisteredTable_SignedZeroParity_IfRegistered;
var
  LScalarTable: TSimdDispatchTable;
  LRISCVVTable: TSimdDispatchTable;
  LInF32x8: TVecF32x8;
  LExpectedRoundF32x8, LExpectedTruncF32x8, LActualRoundF32x8, LActualTruncF32x8: TVecF32x8;
  LInF64x4: TVecF64x4;
  LExpectedRoundF64x4, LExpectedTruncF64x4, LActualRoundF64x4, LActualTruncF64x4: TVecF64x4;
  LInF32x16: TVecF32x16;
  LExpectedRoundF32x16, LExpectedTruncF32x16, LActualRoundF32x16, LActualTruncF32x16: TVecF32x16;
  LInF64x8: TVecF64x8;
  LExpectedRoundF64x8, LExpectedTruncF64x8, LActualRoundF64x8, LActualTruncF64x8: TVecF64x8;
  LIndex: Integer;

  procedure AssertSingleSemantics(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
    begin
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
      if aExpected = 0.0 then
        CheckTrue(BitsFromSingle(aExpected) = BitsFromSingle(aActual), aPrefix + ' zero sign bit');
    end;
  end;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
    begin
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
      if aExpected = 0.0 then
        CheckTrue(BitsFromDouble(aExpected) = BitsFromDouble(aActual), aPrefix + ' zero sign bit');
    end;
  end;
begin
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbScalar, LScalarTable), 'Scalar dispatch table should be registered');

  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  CheckTrue(TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable), 'RISCVV opt-in test registration should be present');
  {$ELSE}
  if not TryGetRegisteredBackendDispatchTable(sbRISCVV, LRISCVVTable) then
  begin
    CheckTrue(True, 'RISCVV backend not registered on this host (allowed)');
    Exit;
  end;
  {$ENDIF}

  CheckTrue(Assigned(LRISCVVTable.RoundF32x8) and Assigned(LRISCVVTable.TruncF32x8) and Assigned(LRISCVVTable.RoundF64x4) and Assigned(LRISCVVTable.TruncF64x4) and Assigned(LRISCVVTable.RoundF32x16) and Assigned(LRISCVVTable.TruncF32x16) and Assigned(LRISCVVTable.RoundF64x8) and Assigned(LRISCVVTable.TruncF64x8), 'RISCVV registered table should provide wide Round/Trunc');

  CheckTrue((PtrUInt(LScalarTable.RoundF32x8) <> PtrUInt(LRISCVVTable.RoundF32x8)) and (PtrUInt(LScalarTable.TruncF32x8) <> PtrUInt(LRISCVVTable.TruncF32x8)) and (PtrUInt(LScalarTable.RoundF64x4) <> PtrUInt(LRISCVVTable.RoundF64x4)) and (PtrUInt(LScalarTable.TruncF64x4) <> PtrUInt(LRISCVVTable.TruncF64x4)) and (PtrUInt(LScalarTable.RoundF32x16) <> PtrUInt(LRISCVVTable.RoundF32x16)) and (PtrUInt(LScalarTable.TruncF32x16) <> PtrUInt(LRISCVVTable.TruncF32x16)) and (PtrUInt(LScalarTable.RoundF64x8) <> PtrUInt(LRISCVVTable.RoundF64x8)) and (PtrUInt(LScalarTable.TruncF64x8) <> PtrUInt(LRISCVVTable.TruncF64x8)), 'RISCVV wide Round/Trunc should stay backend-owned in the registered table');

  LInF32x8.f[0] := 0.0;
  LInF32x8.f[1] := NegZeroF32;
  LInF32x8.f[2] := NaNF32;
  LInF32x8.f[3] := PosInfF32;
  LInF32x8.f[4] := NegInfF32;
  LInF32x8.f[5] := 0.5;
  LInF32x8.f[6] := -0.5;
  LInF32x8.f[7] := -1.5;

  LInF64x4.d[0] := 0.0;
  LInF64x4.d[1] := NegZeroF64;
  LInF64x4.d[2] := NaNF64;
  LInF64x4.d[3] := NegInfF64;

  for LIndex := 0 to 15 do
    if (LIndex and 1) = 0 then
      LInF32x16.f[LIndex] := 0.0
    else
      LInF32x16.f[LIndex] := NegZeroF32;
  LInF32x16.f[2] := NaNF32;
  LInF32x16.f[3] := PosInfF32;
  LInF32x16.f[4] := NegInfF32;
  LInF32x16.f[5] := 0.5;
  LInF32x16.f[6] := -0.5;
  LInF32x16.f[7] := -1.5;

  for LIndex := 0 to 7 do
    if (LIndex and 1) = 0 then
      LInF64x8.d[LIndex] := 0.0
    else
      LInF64x8.d[LIndex] := NegZeroF64;
  LInF64x8.d[2] := NaNF64;
  LInF64x8.d[3] := PosInfF64;
  LInF64x8.d[4] := NegInfF64;
  LInF64x8.d[5] := 0.5;
  LInF64x8.d[6] := -0.5;
  LInF64x8.d[7] := -1.5;

  LExpectedRoundF32x8 := LScalarTable.RoundF32x8(LInF32x8);
  LExpectedTruncF32x8 := LScalarTable.TruncF32x8(LInF32x8);
  LActualRoundF32x8 := LRISCVVTable.RoundF32x8(LInF32x8);
  LActualTruncF32x8 := LRISCVVTable.TruncF32x8(LInF32x8);

  LExpectedRoundF64x4 := LScalarTable.RoundF64x4(LInF64x4);
  LExpectedTruncF64x4 := LScalarTable.TruncF64x4(LInF64x4);
  LActualRoundF64x4 := LRISCVVTable.RoundF64x4(LInF64x4);
  LActualTruncF64x4 := LRISCVVTable.TruncF64x4(LInF64x4);

  LExpectedRoundF32x16 := LScalarTable.RoundF32x16(LInF32x16);
  LExpectedTruncF32x16 := LScalarTable.TruncF32x16(LInF32x16);
  LActualRoundF32x16 := LRISCVVTable.RoundF32x16(LInF32x16);
  LActualTruncF32x16 := LRISCVVTable.TruncF32x16(LInF32x16);

  LExpectedRoundF64x8 := LScalarTable.RoundF64x8(LInF64x8);
  LExpectedTruncF64x8 := LScalarTable.TruncF64x8(LInF64x8);
  LActualRoundF64x8 := LRISCVVTable.RoundF64x8(LInF64x8);
  LActualTruncF64x8 := LRISCVVTable.TruncF64x8(LInF64x8);

  for LIndex := 0 to 7 do
  begin
    AssertSingleSemantics('RISCVV direct RoundF32x8[' + IntToStr(LIndex) + ']', LExpectedRoundF32x8.f[LIndex], LActualRoundF32x8.f[LIndex]);
    AssertSingleSemantics('RISCVV direct TruncF32x8[' + IntToStr(LIndex) + ']', LExpectedTruncF32x8.f[LIndex], LActualTruncF32x8.f[LIndex]);
  end;

  for LIndex := 0 to 3 do
  begin
    AssertDoubleSemantics('RISCVV direct RoundF64x4[' + IntToStr(LIndex) + ']', LExpectedRoundF64x4.d[LIndex], LActualRoundF64x4.d[LIndex]);
    AssertDoubleSemantics('RISCVV direct TruncF64x4[' + IntToStr(LIndex) + ']', LExpectedTruncF64x4.d[LIndex], LActualTruncF64x4.d[LIndex]);
  end;

  for LIndex := 0 to 15 do
  begin
    AssertSingleSemantics('RISCVV direct RoundF32x16[' + IntToStr(LIndex) + ']', LExpectedRoundF32x16.f[LIndex], LActualRoundF32x16.f[LIndex]);
    AssertSingleSemantics('RISCVV direct TruncF32x16[' + IntToStr(LIndex) + ']', LExpectedTruncF32x16.f[LIndex], LActualTruncF32x16.f[LIndex]);
  end;

  for LIndex := 0 to 7 do
  begin
    AssertDoubleSemantics('RISCVV direct RoundF64x8[' + IntToStr(LIndex) + ']', LExpectedRoundF64x8.d[LIndex], LActualRoundF64x8.d[LIndex]);
    AssertDoubleSemantics('RISCVV direct TruncF64x8[' + IntToStr(LIndex) + ']', LExpectedTruncF64x8.d[LIndex], LActualTruncF64x8.d[LIndex]);
  end;
end;

procedure TTestCase_NonX86IEEE754.Test_NonX86_F32_ReduceMinMax_SpecialCases_IfAvailable;
const
  NON_X86_BACKENDS: array[0..1] of TSimdBackend = (sbNEON, sbRISCVV);
var
  LBackend: TSimdBackend;
  LCheckedBackends: Integer;
  LScalarDispatch: PSimdDispatchTable;
  LBackendDispatch: PSimdDispatchTable;

  LInputF32x4: TVecF32x4;
  LInputF32x8: TVecF32x8;
  LInputF32x16: TVecF32x16;

  procedure AssertSingleParity(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
    begin
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
      if aExpected = 0.0 then
        CheckTrue(BitsFromSingle(aExpected) = BitsFromSingle(aActual), aPrefix + ' zero sign');
    end;
  end;

  procedure AssertReduceParityF32x4(const aLabel: string; const aInput: TVecF32x4);
  begin
    AssertSingleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMinF32x4', LScalarDispatch^.ReduceMinF32x4(aInput), LBackendDispatch^.ReduceMinF32x4(aInput));
    AssertSingleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMaxF32x4', LScalarDispatch^.ReduceMaxF32x4(aInput), LBackendDispatch^.ReduceMaxF32x4(aInput));
  end;

  procedure AssertReduceParityF32x8(const aLabel: string; const aInput: TVecF32x8);
  begin
    AssertSingleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMinF32x8', LScalarDispatch^.ReduceMinF32x8(aInput), LBackendDispatch^.ReduceMinF32x8(aInput));
    AssertSingleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMaxF32x8', LScalarDispatch^.ReduceMaxF32x8(aInput), LBackendDispatch^.ReduceMaxF32x8(aInput));
  end;

  procedure AssertReduceParityF32x16(const aLabel: string; const aInput: TVecF32x16);
  begin
    AssertSingleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMinF32x16', LScalarDispatch^.ReduceMinF32x16(aInput), LBackendDispatch^.ReduceMinF32x16(aInput));
    AssertSingleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMaxF32x16', LScalarDispatch^.ReduceMaxF32x16(aInput), LBackendDispatch^.ReduceMaxF32x16(aInput));
  end;

begin
  LCheckedBackends := 0;
  SetVectorAsmEnabled(True);

  for LBackend in NON_X86_BACKENDS do
  begin
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);
    try
      SetActiveBackend(sbScalar);
      LScalarDispatch := GetDispatchTable;
      CheckNotNil(LScalarDispatch, 'Scalar dispatch should be available');
      CheckTrue(Assigned(LScalarDispatch^.ReduceMinF32x4) and Assigned(LScalarDispatch^.ReduceMaxF32x4) and Assigned(LScalarDispatch^.ReduceMinF32x8) and Assigned(LScalarDispatch^.ReduceMaxF32x8) and Assigned(LScalarDispatch^.ReduceMinF32x16) and Assigned(LScalarDispatch^.ReduceMaxF32x16), 'Scalar dispatch should provide F32 reductions');

      SetActiveBackend(LBackend);
      LBackendDispatch := GetDispatchTable;
      CheckNotNil(LBackendDispatch, 'Non-x86 dispatch should be available');
      CheckTrue(Assigned(LBackendDispatch^.ReduceMinF32x4) and Assigned(LBackendDispatch^.ReduceMaxF32x4) and Assigned(LBackendDispatch^.ReduceMinF32x8) and Assigned(LBackendDispatch^.ReduceMaxF32x8) and Assigned(LBackendDispatch^.ReduceMinF32x16) and Assigned(LBackendDispatch^.ReduceMaxF32x16), 'Non-x86 dispatch should provide F32 reductions');

      LInputF32x4.f[0] := NaNF32;
      LInputF32x4.f[1] := 3.0;
      LInputF32x4.f[2] := 8.0;
      LInputF32x4.f[3] := 9.0;
      AssertReduceParityF32x4('NaNLeading', LInputF32x4);

      LInputF32x4.f[0] := 3.0;
      LInputF32x4.f[1] := NaNF32;
      LInputF32x4.f[2] := 8.0;
      LInputF32x4.f[3] := 9.0;
      AssertReduceParityF32x4('NaNSecond', LInputF32x4);

      LInputF32x4.f[0] := 0.0;
      LInputF32x4.f[1] := -0.0;
      LInputF32x4.f[2] := 4.0;
      LInputF32x4.f[3] := 5.0;
      AssertReduceParityF32x4('SignedZeroPosNeg', LInputF32x4);

      LInputF32x4.f[0] := -0.0;
      LInputF32x4.f[1] := 0.0;
      LInputF32x4.f[2] := 4.0;
      LInputF32x4.f[3] := 5.0;
      AssertReduceParityF32x4('SignedZeroNegPos', LInputF32x4);

      LInputF32x8.f[0] := NaNF32;
      LInputF32x8.f[1] := 3.0;
      LInputF32x8.f[2] := 8.0;
      LInputF32x8.f[3] := 9.0;
      LInputF32x8.f[4] := 12.0;
      LInputF32x8.f[5] := 14.0;
      LInputF32x8.f[6] := 15.0;
      LInputF32x8.f[7] := 18.0;
      AssertReduceParityF32x8('NaNLeading', LInputF32x8);

      LInputF32x8.f[0] := 3.0;
      LInputF32x8.f[1] := NaNF32;
      LInputF32x8.f[2] := 8.0;
      LInputF32x8.f[3] := 9.0;
      LInputF32x8.f[4] := 12.0;
      LInputF32x8.f[5] := 14.0;
      LInputF32x8.f[6] := 15.0;
      LInputF32x8.f[7] := 18.0;
      AssertReduceParityF32x8('NaNSecond', LInputF32x8);

      LInputF32x8.f[0] := 0.0;
      LInputF32x8.f[1] := -0.0;
      LInputF32x8.f[2] := 4.0;
      LInputF32x8.f[3] := 5.0;
      LInputF32x8.f[4] := 6.0;
      LInputF32x8.f[5] := 7.0;
      LInputF32x8.f[6] := 8.0;
      LInputF32x8.f[7] := 9.0;
      AssertReduceParityF32x8('SignedZeroPosNeg', LInputF32x8);

      LInputF32x8.f[0] := -0.0;
      LInputF32x8.f[1] := 0.0;
      LInputF32x8.f[2] := 4.0;
      LInputF32x8.f[3] := 5.0;
      LInputF32x8.f[4] := 6.0;
      LInputF32x8.f[5] := 7.0;
      LInputF32x8.f[6] := 8.0;
      LInputF32x8.f[7] := 9.0;
      AssertReduceParityF32x8('SignedZeroNegPos', LInputF32x8);

      LInputF32x16.f[0] := NaNF32;
      LInputF32x16.f[1] := 3.0;
      LInputF32x16.f[2] := 8.0;
      LInputF32x16.f[3] := 9.0;
      LInputF32x16.f[4] := 12.0;
      LInputF32x16.f[5] := 14.0;
      LInputF32x16.f[6] := 15.0;
      LInputF32x16.f[7] := 18.0;
      LInputF32x16.f[8] := 19.0;
      LInputF32x16.f[9] := 21.0;
      LInputF32x16.f[10] := 22.0;
      LInputF32x16.f[11] := 24.0;
      LInputF32x16.f[12] := 25.0;
      LInputF32x16.f[13] := 27.0;
      LInputF32x16.f[14] := 28.0;
      LInputF32x16.f[15] := 30.0;
      AssertReduceParityF32x16('NaNLeading', LInputF32x16);

      LInputF32x16.f[0] := 3.0;
      LInputF32x16.f[1] := NaNF32;
      LInputF32x16.f[2] := 8.0;
      LInputF32x16.f[3] := 9.0;
      LInputF32x16.f[4] := 12.0;
      LInputF32x16.f[5] := 14.0;
      LInputF32x16.f[6] := 15.0;
      LInputF32x16.f[7] := 18.0;
      LInputF32x16.f[8] := 19.0;
      LInputF32x16.f[9] := 21.0;
      LInputF32x16.f[10] := 22.0;
      LInputF32x16.f[11] := 24.0;
      LInputF32x16.f[12] := 25.0;
      LInputF32x16.f[13] := 27.0;
      LInputF32x16.f[14] := 28.0;
      LInputF32x16.f[15] := 30.0;
      AssertReduceParityF32x16('NaNSecond', LInputF32x16);

      LInputF32x16.f[0] := 0.0;
      LInputF32x16.f[1] := -0.0;
      LInputF32x16.f[2] := 4.0;
      LInputF32x16.f[3] := 5.0;
      LInputF32x16.f[4] := 6.0;
      LInputF32x16.f[5] := 7.0;
      LInputF32x16.f[6] := 8.0;
      LInputF32x16.f[7] := 9.0;
      LInputF32x16.f[8] := 10.0;
      LInputF32x16.f[9] := 11.0;
      LInputF32x16.f[10] := 12.0;
      LInputF32x16.f[11] := 13.0;
      LInputF32x16.f[12] := 14.0;
      LInputF32x16.f[13] := 15.0;
      LInputF32x16.f[14] := 16.0;
      LInputF32x16.f[15] := 17.0;
      AssertReduceParityF32x16('SignedZeroPosNeg', LInputF32x16);

      LInputF32x16.f[0] := -0.0;
      LInputF32x16.f[1] := 0.0;
      LInputF32x16.f[2] := 4.0;
      LInputF32x16.f[3] := 5.0;
      LInputF32x16.f[4] := 6.0;
      LInputF32x16.f[5] := 7.0;
      LInputF32x16.f[6] := 8.0;
      LInputF32x16.f[7] := 9.0;
      LInputF32x16.f[8] := 10.0;
      LInputF32x16.f[9] := 11.0;
      LInputF32x16.f[10] := 12.0;
      LInputF32x16.f[11] := 13.0;
      LInputF32x16.f[12] := 14.0;
      LInputF32x16.f[13] := 15.0;
      LInputF32x16.f[14] := 16.0;
      LInputF32x16.f[15] := 17.0;
      AssertReduceParityF32x16('SignedZeroNegPos', LInputF32x16);
    finally
      ResetToAutomaticBackend;
    end;
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 backend available on this host (allowed)');
end;

procedure TTestCase_NonX86IEEE754.Test_NonX86_F64_MinMaxReduce_SpecialCases_IfAvailable;
const
  NON_X86_BACKENDS: array[0..1] of TSimdBackend = (sbNEON, sbRISCVV);
var
  LBackend: TSimdBackend;
  LCheckedBackends: Integer;
  LScalarDispatch: PSimdDispatchTable;
  LBackendDispatch: PSimdDispatchTable;

  LLeftF64x2, LRightF64x2: TVecF64x2;
  LInputF64x2: TVecF64x2;
  LInputF64x4: TVecF64x4;
  LInputF64x8: TVecF64x8;

  procedure AssertDoubleParity(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
    begin
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
      if aExpected = 0.0 then
        CheckTrue(BitsFromDouble(aExpected) = BitsFromDouble(aActual), aPrefix + ' zero sign');
    end;
  end;

  procedure AssertVecF64x2Parity(
    const aPrefix: string;
    const aExpected, aActual: TVecF64x2);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 1 do
      AssertDoubleParity(aPrefix + '[' + IntToStr(LLaneIndex) + ']', aExpected.d[LLaneIndex], aActual.d[LLaneIndex]);
  end;

  procedure AssertReduceParityF64x2(const aLabel: string; const aInput: TVecF64x2);
  begin
    AssertDoubleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMinF64x2', LScalarDispatch^.ReduceMinF64x2(aInput), LBackendDispatch^.ReduceMinF64x2(aInput));
    AssertDoubleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMaxF64x2', LScalarDispatch^.ReduceMaxF64x2(aInput), LBackendDispatch^.ReduceMaxF64x2(aInput));
  end;

  procedure AssertReduceParityF64x4(const aLabel: string; const aInput: TVecF64x4);
  begin
    AssertDoubleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMinF64x4', LScalarDispatch^.ReduceMinF64x4(aInput), LBackendDispatch^.ReduceMinF64x4(aInput));
    AssertDoubleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMaxF64x4', LScalarDispatch^.ReduceMaxF64x4(aInput), LBackendDispatch^.ReduceMaxF64x4(aInput));
  end;

  procedure AssertReduceParityF64x8(const aLabel: string; const aInput: TVecF64x8);
  begin
    AssertDoubleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMinF64x8', LScalarDispatch^.ReduceMinF64x8(aInput), LBackendDispatch^.ReduceMinF64x8(aInput));
    AssertDoubleParity(IEEE754BackendName(LBackend) + ' ' + aLabel + ' ReduceMaxF64x8', LScalarDispatch^.ReduceMaxF64x8(aInput), LBackendDispatch^.ReduceMaxF64x8(aInput));
  end;

begin
  LCheckedBackends := 0;
  SetVectorAsmEnabled(True);

  for LBackend in NON_X86_BACKENDS do
  begin
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);
    try
      SetActiveBackend(sbScalar);
      LScalarDispatch := GetDispatchTable;
      CheckNotNil(LScalarDispatch, 'Scalar dispatch should be available');
      CheckTrue(Assigned(LScalarDispatch^.MinF64x2) and Assigned(LScalarDispatch^.MaxF64x2) and Assigned(LScalarDispatch^.ReduceMinF64x2) and Assigned(LScalarDispatch^.ReduceMaxF64x2) and Assigned(LScalarDispatch^.ReduceMinF64x4) and Assigned(LScalarDispatch^.ReduceMaxF64x4) and Assigned(LScalarDispatch^.ReduceMinF64x8) and Assigned(LScalarDispatch^.ReduceMaxF64x8), 'Scalar dispatch should provide F64x2/F64x4/F64x8 min/max reductions');

      SetActiveBackend(LBackend);
      LBackendDispatch := GetDispatchTable;
      CheckNotNil(LBackendDispatch, 'Non-x86 dispatch should be available');
      CheckTrue(Assigned(LBackendDispatch^.MinF64x2) and Assigned(LBackendDispatch^.MaxF64x2) and Assigned(LBackendDispatch^.ReduceMinF64x2) and Assigned(LBackendDispatch^.ReduceMaxF64x2) and Assigned(LBackendDispatch^.ReduceMinF64x4) and Assigned(LBackendDispatch^.ReduceMaxF64x4) and Assigned(LBackendDispatch^.ReduceMinF64x8) and Assigned(LBackendDispatch^.ReduceMaxF64x8), 'Non-x86 dispatch should provide F64x2/F64x4/F64x8 min/max reductions');

      LLeftF64x2.d[0] := NaNF64;
      LLeftF64x2.d[1] := 5.0;
      LRightF64x2.d[0] := 3.0;
      LRightF64x2.d[1] := NaNF64;
      AssertVecF64x2Parity(IEEE754BackendName(LBackend) + ' NaN MinF64x2', LScalarDispatch^.MinF64x2(LLeftF64x2, LRightF64x2),
        LBackendDispatch^.MinF64x2(LLeftF64x2, LRightF64x2));
      AssertVecF64x2Parity(IEEE754BackendName(LBackend) + ' NaN MaxF64x2', LScalarDispatch^.MaxF64x2(LLeftF64x2, LRightF64x2),
        LBackendDispatch^.MaxF64x2(LLeftF64x2, LRightF64x2));

      LLeftF64x2.d[0] := 0.0;
      LLeftF64x2.d[1] := NegZeroF64;
      LRightF64x2.d[0] := NegZeroF64;
      LRightF64x2.d[1] := 0.0;
      AssertVecF64x2Parity(IEEE754BackendName(LBackend) + ' SignedZero MinF64x2', LScalarDispatch^.MinF64x2(LLeftF64x2, LRightF64x2),
        LBackendDispatch^.MinF64x2(LLeftF64x2, LRightF64x2));
      AssertVecF64x2Parity(IEEE754BackendName(LBackend) + ' SignedZero MaxF64x2', LScalarDispatch^.MaxF64x2(LLeftF64x2, LRightF64x2),
        LBackendDispatch^.MaxF64x2(LLeftF64x2, LRightF64x2));

      LInputF64x2.d[0] := NaNF64;
      LInputF64x2.d[1] := 3.0;
      AssertReduceParityF64x2('NaNLeading', LInputF64x2);

      LInputF64x2.d[0] := 3.0;
      LInputF64x2.d[1] := NaNF64;
      AssertReduceParityF64x2('NaNTrailing', LInputF64x2);

      LInputF64x2.d[0] := 0.0;
      LInputF64x2.d[1] := NegZeroF64;
      AssertReduceParityF64x2('SignedZeroPosNeg', LInputF64x2);

      LInputF64x2.d[0] := NegZeroF64;
      LInputF64x2.d[1] := 0.0;
      AssertReduceParityF64x2('SignedZeroNegPos', LInputF64x2);

      LInputF64x4.d[0] := NaNF64;
      LInputF64x4.d[1] := 3.0;
      LInputF64x4.d[2] := 8.0;
      LInputF64x4.d[3] := 9.0;
      AssertReduceParityF64x4('NaNLeading', LInputF64x4);

      LInputF64x4.d[0] := 3.0;
      LInputF64x4.d[1] := NaNF64;
      LInputF64x4.d[2] := 8.0;
      LInputF64x4.d[3] := 9.0;
      AssertReduceParityF64x4('NaNSecond', LInputF64x4);

      LInputF64x4.d[0] := 0.0;
      LInputF64x4.d[1] := NegZeroF64;
      LInputF64x4.d[2] := 4.0;
      LInputF64x4.d[3] := 5.0;
      AssertReduceParityF64x4('SignedZeroPosNeg', LInputF64x4);

      LInputF64x4.d[0] := NegZeroF64;
      LInputF64x4.d[1] := 0.0;
      LInputF64x4.d[2] := 4.0;
      LInputF64x4.d[3] := 5.0;
      AssertReduceParityF64x4('SignedZeroNegPos', LInputF64x4);

      LInputF64x8.d[0] := NaNF64;
      LInputF64x8.d[1] := 3.0;
      LInputF64x8.d[2] := 8.0;
      LInputF64x8.d[3] := 9.0;
      LInputF64x8.d[4] := 12.0;
      LInputF64x8.d[5] := 14.0;
      LInputF64x8.d[6] := 15.0;
      LInputF64x8.d[7] := 18.0;
      AssertReduceParityF64x8('NaNLeading', LInputF64x8);

      LInputF64x8.d[0] := 3.0;
      LInputF64x8.d[1] := NaNF64;
      LInputF64x8.d[2] := 8.0;
      LInputF64x8.d[3] := 9.0;
      LInputF64x8.d[4] := 12.0;
      LInputF64x8.d[5] := 14.0;
      LInputF64x8.d[6] := 15.0;
      LInputF64x8.d[7] := 18.0;
      AssertReduceParityF64x8('NaNSecond', LInputF64x8);

      LInputF64x8.d[0] := 0.0;
      LInputF64x8.d[1] := NegZeroF64;
      LInputF64x8.d[2] := 4.0;
      LInputF64x8.d[3] := 5.0;
      LInputF64x8.d[4] := 6.0;
      LInputF64x8.d[5] := 7.0;
      LInputF64x8.d[6] := 8.0;
      LInputF64x8.d[7] := 9.0;
      AssertReduceParityF64x8('SignedZeroPosNeg', LInputF64x8);

      LInputF64x8.d[0] := NegZeroF64;
      LInputF64x8.d[1] := 0.0;
      LInputF64x8.d[2] := 4.0;
      LInputF64x8.d[3] := 5.0;
      LInputF64x8.d[4] := 6.0;
      LInputF64x8.d[5] := 7.0;
      LInputF64x8.d[6] := 8.0;
      LInputF64x8.d[7] := 9.0;
      AssertReduceParityF64x8('SignedZeroNegPos', LInputF64x8);
    finally
      ResetToAutomaticBackend;
    end;
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 backend available on this host (allowed)');
end;

procedure TTestCase_NonX86IEEE754.Test_NonX86_F32_WideMinMax_SpecialCases_IfAvailable;
const
  NON_X86_BACKENDS: array[0..1] of TSimdBackend = (sbNEON, sbRISCVV);
var
  LBackend: TSimdBackend;
  LCheckedBackends: Integer;
  LScalarDispatch: PSimdDispatchTable;
  LBackendDispatch: PSimdDispatchTable;

  LLeftF32x8, LRightF32x8: TVecF32x8;
  LLeftF32x16, LRightF32x16: TVecF32x16;

  procedure AssertSingleParity(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
    begin
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
      if aExpected = 0.0 then
        CheckTrue(BitsFromSingle(aExpected) = BitsFromSingle(aActual), aPrefix + ' zero sign');
    end;
  end;

  procedure AssertVecF32x8Parity(
    const aPrefix: string;
    const aExpected, aActual: TVecF32x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      AssertSingleParity(aPrefix + '[' + IntToStr(LLaneIndex) + ']', aExpected.f[LLaneIndex], aActual.f[LLaneIndex]);
  end;

  procedure AssertVecF32x16Parity(
    const aPrefix: string;
    const aExpected, aActual: TVecF32x16);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 15 do
      AssertSingleParity(aPrefix + '[' + IntToStr(LLaneIndex) + ']', aExpected.f[LLaneIndex], aActual.f[LLaneIndex]);
  end;

begin
  LCheckedBackends := 0;
  SetVectorAsmEnabled(True);

  for LBackend in NON_X86_BACKENDS do
  begin
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);
    try
      SetActiveBackend(sbScalar);
      LScalarDispatch := GetDispatchTable;
      CheckNotNil(LScalarDispatch, 'Scalar dispatch should be available');
      CheckTrue(Assigned(LScalarDispatch^.MinF32x8) and Assigned(LScalarDispatch^.MaxF32x8) and Assigned(LScalarDispatch^.MinF32x16) and Assigned(LScalarDispatch^.MaxF32x16), 'Scalar dispatch should provide wide F32 min/max');

      SetActiveBackend(LBackend);
      LBackendDispatch := GetDispatchTable;
      CheckNotNil(LBackendDispatch, 'Non-x86 dispatch should be available');
      CheckTrue(Assigned(LBackendDispatch^.MinF32x8) and Assigned(LBackendDispatch^.MaxF32x8) and Assigned(LBackendDispatch^.MinF32x16) and Assigned(LBackendDispatch^.MaxF32x16), 'Non-x86 dispatch should provide wide F32 min/max');

      LLeftF32x8.f[0] := NaNF32;
      LLeftF32x8.f[1] := 5.0;
      LLeftF32x8.f[2] := 0.0;
      LLeftF32x8.f[3] := NegZeroF32;
      LLeftF32x8.f[4] := 8.0;
      LLeftF32x8.f[5] := 9.0;
      LLeftF32x8.f[6] := NegZeroF32;
      LLeftF32x8.f[7] := 0.0;
      LRightF32x8.f[0] := 3.0;
      LRightF32x8.f[1] := NaNF32;
      LRightF32x8.f[2] := NegZeroF32;
      LRightF32x8.f[3] := 0.0;
      LRightF32x8.f[4] := NaNF32;
      LRightF32x8.f[5] := 4.0;
      LRightF32x8.f[6] := 0.0;
      LRightF32x8.f[7] := NegZeroF32;
      AssertVecF32x8Parity(IEEE754BackendName(LBackend) + ' Special MinF32x8', LScalarDispatch^.MinF32x8(LLeftF32x8, LRightF32x8),
        LBackendDispatch^.MinF32x8(LLeftF32x8, LRightF32x8));
      AssertVecF32x8Parity(IEEE754BackendName(LBackend) + ' Special MaxF32x8', LScalarDispatch^.MaxF32x8(LLeftF32x8, LRightF32x8),
        LBackendDispatch^.MaxF32x8(LLeftF32x8, LRightF32x8));

      LLeftF32x16.f[0] := NaNF32;
      LLeftF32x16.f[1] := 5.0;
      LLeftF32x16.f[2] := 0.0;
      LLeftF32x16.f[3] := NegZeroF32;
      LLeftF32x16.f[4] := 8.0;
      LLeftF32x16.f[5] := 9.0;
      LLeftF32x16.f[6] := NegZeroF32;
      LLeftF32x16.f[7] := 0.0;
      LLeftF32x16.f[8] := 12.0;
      LLeftF32x16.f[9] := 13.0;
      LLeftF32x16.f[10] := 14.0;
      LLeftF32x16.f[11] := 15.0;
      LLeftF32x16.f[12] := NegZeroF32;
      LLeftF32x16.f[13] := 0.0;
      LLeftF32x16.f[14] := 18.0;
      LLeftF32x16.f[15] := NaNF32;
      LRightF32x16.f[0] := 3.0;
      LRightF32x16.f[1] := NaNF32;
      LRightF32x16.f[2] := NegZeroF32;
      LRightF32x16.f[3] := 0.0;
      LRightF32x16.f[4] := NaNF32;
      LRightF32x16.f[5] := 4.0;
      LRightF32x16.f[6] := 0.0;
      LRightF32x16.f[7] := NegZeroF32;
      LRightF32x16.f[8] := 11.0;
      LRightF32x16.f[9] := 12.0;
      LRightF32x16.f[10] := NaNF32;
      LRightF32x16.f[11] := 16.0;
      LRightF32x16.f[12] := 0.0;
      LRightF32x16.f[13] := NegZeroF32;
      LRightF32x16.f[14] := NaNF32;
      LRightF32x16.f[15] := 17.0;
      AssertVecF32x16Parity(IEEE754BackendName(LBackend) + ' Special MinF32x16', LScalarDispatch^.MinF32x16(LLeftF32x16, LRightF32x16),
        LBackendDispatch^.MinF32x16(LLeftF32x16, LRightF32x16));
      AssertVecF32x16Parity(IEEE754BackendName(LBackend) + ' Special MaxF32x16', LScalarDispatch^.MaxF32x16(LLeftF32x16, LRightF32x16),
        LBackendDispatch^.MaxF32x16(LLeftF32x16, LRightF32x16));
    finally
      ResetToAutomaticBackend;
    end;
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 backend available on this host (allowed)');
end;

procedure TTestCase_NonX86IEEE754.Test_NonX86_F64_WideMinMax_SpecialCases_IfAvailable;
const
  NON_X86_BACKENDS: array[0..1] of TSimdBackend = (sbNEON, sbRISCVV);
var
  LBackend: TSimdBackend;
  LCheckedBackends: Integer;
  LScalarDispatch: PSimdDispatchTable;
  LBackendDispatch: PSimdDispatchTable;

  LLeftF64x4, LRightF64x4: TVecF64x4;
  LLeftF64x8, LRightF64x8: TVecF64x8;

  procedure AssertDoubleParity(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
    begin
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
      if aExpected = 0.0 then
        CheckTrue(BitsFromDouble(aExpected) = BitsFromDouble(aActual), aPrefix + ' zero sign');
    end;
  end;

  procedure AssertVecF64x4Parity(
    const aPrefix: string;
    const aExpected, aActual: TVecF64x4);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 3 do
      AssertDoubleParity(aPrefix + '[' + IntToStr(LLaneIndex) + ']', aExpected.d[LLaneIndex], aActual.d[LLaneIndex]);
  end;

  procedure AssertVecF64x8Parity(
    const aPrefix: string;
    const aExpected, aActual: TVecF64x8);
  var
    LLaneIndex: Integer;
  begin
    for LLaneIndex := 0 to 7 do
      AssertDoubleParity(aPrefix + '[' + IntToStr(LLaneIndex) + ']', aExpected.d[LLaneIndex], aActual.d[LLaneIndex]);
  end;

begin
  LCheckedBackends := 0;
  SetVectorAsmEnabled(True);

  for LBackend in NON_X86_BACKENDS do
  begin
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);
    try
      SetActiveBackend(sbScalar);
      LScalarDispatch := GetDispatchTable;
      CheckNotNil(LScalarDispatch, 'Scalar dispatch should be available');
      CheckTrue(Assigned(LScalarDispatch^.MinF64x4) and Assigned(LScalarDispatch^.MaxF64x4) and Assigned(LScalarDispatch^.MinF64x8) and Assigned(LScalarDispatch^.MaxF64x8), 'Scalar dispatch should provide wide F64 min/max');

      SetActiveBackend(LBackend);
      LBackendDispatch := GetDispatchTable;
      CheckNotNil(LBackendDispatch, 'Non-x86 dispatch should be available');
      CheckTrue(Assigned(LBackendDispatch^.MinF64x4) and Assigned(LBackendDispatch^.MaxF64x4) and Assigned(LBackendDispatch^.MinF64x8) and Assigned(LBackendDispatch^.MaxF64x8), 'Non-x86 dispatch should provide wide F64 min/max');

      LLeftF64x4.d[0] := NaNF64;
      LLeftF64x4.d[1] := 5.0;
      LLeftF64x4.d[2] := 0.0;
      LLeftF64x4.d[3] := NegZeroF64;
      LRightF64x4.d[0] := 3.0;
      LRightF64x4.d[1] := NaNF64;
      LRightF64x4.d[2] := NegZeroF64;
      LRightF64x4.d[3] := 0.0;
      AssertVecF64x4Parity(IEEE754BackendName(LBackend) + ' Special MinF64x4', LScalarDispatch^.MinF64x4(LLeftF64x4, LRightF64x4),
        LBackendDispatch^.MinF64x4(LLeftF64x4, LRightF64x4));
      AssertVecF64x4Parity(IEEE754BackendName(LBackend) + ' Special MaxF64x4', LScalarDispatch^.MaxF64x4(LLeftF64x4, LRightF64x4),
        LBackendDispatch^.MaxF64x4(LLeftF64x4, LRightF64x4));

      LLeftF64x8.d[0] := NaNF64;
      LLeftF64x8.d[1] := 5.0;
      LLeftF64x8.d[2] := 0.0;
      LLeftF64x8.d[3] := NegZeroF64;
      LLeftF64x8.d[4] := 8.0;
      LLeftF64x8.d[5] := 9.0;
      LLeftF64x8.d[6] := NegZeroF64;
      LLeftF64x8.d[7] := 0.0;
      LRightF64x8.d[0] := 3.0;
      LRightF64x8.d[1] := NaNF64;
      LRightF64x8.d[2] := NegZeroF64;
      LRightF64x8.d[3] := 0.0;
      LRightF64x8.d[4] := NaNF64;
      LRightF64x8.d[5] := 4.0;
      LRightF64x8.d[6] := 0.0;
      LRightF64x8.d[7] := NegZeroF64;
      AssertVecF64x8Parity(IEEE754BackendName(LBackend) + ' Special MinF64x8', LScalarDispatch^.MinF64x8(LLeftF64x8, LRightF64x8),
        LBackendDispatch^.MinF64x8(LLeftF64x8, LRightF64x8));
      AssertVecF64x8Parity(IEEE754BackendName(LBackend) + ' Special MaxF64x8', LScalarDispatch^.MaxF64x8(LLeftF64x8, LRightF64x8),
        LBackendDispatch^.MaxF64x8(LLeftF64x8, LRightF64x8));
    finally
      ResetToAutomaticBackend;
    end;
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 backend available on this host (allowed)');
end;

procedure TTestCase_NonX86IEEE754.Test_NonX86_Wide_RoundTruncFloorCeil_NaNInf_IfAvailable;
const
  NON_X86_BACKENDS: array[0..1] of TSimdBackend = (sbNEON, sbRISCVV);
var
  LBackend: TSimdBackend;
  LCheckedBackends: Integer;
  LDispatch: PSimdDispatchTable;
  LIndex: Integer;

  LInF32x8, LExpectedRoundF32x8, LExpectedTruncF32x8, LExpectedFloorF32x8, LExpectedCeilF32x8: TVecF32x8;
  LActualRoundF32x8, LActualTruncF32x8, LActualFloorF32x8, LActualCeilF32x8: TVecF32x8;
  LInF64x4, LExpectedRoundF64x4, LExpectedTruncF64x4, LExpectedFloorF64x4, LExpectedCeilF64x4: TVecF64x4;
  LActualRoundF64x4, LActualTruncF64x4, LActualFloorF64x4, LActualCeilF64x4: TVecF64x4;
  LInF32x16, LExpectedRoundF32x16, LExpectedTruncF32x16, LExpectedFloorF32x16, LExpectedCeilF32x16: TVecF32x16;
  LActualRoundF32x16, LActualTruncF32x16, LActualFloorF32x16, LActualCeilF32x16: TVecF32x16;
  LInF64x8, LExpectedRoundF64x8, LExpectedTruncF64x8, LExpectedFloorF64x8, LExpectedCeilF64x8: TVecF64x8;
  LActualRoundF64x8, LActualTruncF64x8, LActualFloorF64x8, LActualCeilF64x8: TVecF64x8;

  LInSignedZeroF32x8, LExpectedRoundSignedZeroF32x8, LExpectedTruncSignedZeroF32x8: TVecF32x8;
  LActualRoundSignedZeroF32x8, LActualTruncSignedZeroF32x8: TVecF32x8;
  LInSignedZeroF64x4, LExpectedRoundSignedZeroF64x4, LExpectedTruncSignedZeroF64x4: TVecF64x4;
  LActualRoundSignedZeroF64x4, LActualTruncSignedZeroF64x4: TVecF64x4;
  LInSignedZeroF32x16, LExpectedRoundSignedZeroF32x16, LExpectedTruncSignedZeroF32x16: TVecF32x16;
  LActualRoundSignedZeroF32x16, LActualTruncSignedZeroF32x16: TVecF32x16;
  LInSignedZeroF64x8, LExpectedRoundSignedZeroF64x8, LExpectedTruncSignedZeroF64x8: TVecF64x8;
  LActualRoundSignedZeroF64x8, LActualTruncSignedZeroF64x8: TVecF64x8;

  procedure AssertSingleSemantics(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 1e-6, aPrefix);
  end;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 1e-12, aPrefix);
  end;

  procedure AssertSingleZeroSign(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if (aExpected = 0.0) and (aActual = 0.0) then
      CheckTrue(BitsFromSingle(aExpected) = BitsFromSingle(aActual), aPrefix + ' zero sign bit');
  end;

  procedure AssertDoubleZeroSign(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if (aExpected = 0.0) and (aActual = 0.0) then
      CheckTrue(BitsFromDouble(aExpected) = BitsFromDouble(aActual), aPrefix + ' zero sign bit');
  end;
begin
  LCheckedBackends := 0;

  for LIndex := 0 to 7 do
  begin
    case (LIndex mod 6) of
      0: LInF32x8.f[LIndex] := NaNF32;
      1: LInF32x8.f[LIndex] := PosInfF32;
      2: LInF32x8.f[LIndex] := NegInfF32;
      3: LInF32x8.f[LIndex] := -2.75 + LIndex * 0.125;
      4: LInF32x8.f[LIndex] := 2.5 - LIndex * 0.25;
    else
      LInF32x8.f[LIndex] := 0.5 - LIndex * 0.1;
    end;
  end;

  for LIndex := 0 to 3 do
  begin
    case (LIndex mod 4) of
      0: LInF64x4.d[LIndex] := NaNF64;
      1: LInF64x4.d[LIndex] := PosInfF64;
      2: LInF64x4.d[LIndex] := NegInfF64;
    else
      LInF64x4.d[LIndex] := -2.75 + LIndex * 0.75;
    end;
  end;

  for LIndex := 0 to 15 do
  begin
    case (LIndex mod 8) of
      0: LInF32x16.f[LIndex] := NaNF32;
      1: LInF32x16.f[LIndex] := PosInfF32;
      2: LInF32x16.f[LIndex] := NegInfF32;
      3: LInF32x16.f[LIndex] := -3.5 + LIndex * 0.125;
      4: LInF32x16.f[LIndex] := 3.25 - LIndex * 0.2;
    else
      LInF32x16.f[LIndex] := 0.75 - LIndex * 0.07;
    end;
  end;

  for LIndex := 0 to 7 do
  begin
    case (LIndex mod 5) of
      0: LInF64x8.d[LIndex] := NaNF64;
      1: LInF64x8.d[LIndex] := PosInfF64;
      2: LInF64x8.d[LIndex] := NegInfF64;
      3: LInF64x8.d[LIndex] := -4.0 + LIndex * 0.5;
    else
      LInF64x8.d[LIndex] := 1.25 - LIndex * 0.3;
    end;
  end;

  LInSignedZeroF32x8.f[0] := 0.0;
  LInSignedZeroF32x8.f[1] := NegZeroF32;
  LInSignedZeroF32x8.f[2] := 0.25;
  LInSignedZeroF32x8.f[3] := -0.25;
  LInSignedZeroF32x8.f[4] := 0.5;
  LInSignedZeroF32x8.f[5] := -0.5;
  LInSignedZeroF32x8.f[6] := 1.0;
  LInSignedZeroF32x8.f[7] := -1.0;

  LInSignedZeroF64x4.d[0] := 0.0;
  LInSignedZeroF64x4.d[1] := NegZeroF64;
  LInSignedZeroF64x4.d[2] := 0.25;
  LInSignedZeroF64x4.d[3] := -0.25;

  for LIndex := 0 to 15 do
    if (LIndex and 1) = 0 then
      LInSignedZeroF32x16.f[LIndex] := 0.0
    else
      LInSignedZeroF32x16.f[LIndex] := NegZeroF32;
  LInSignedZeroF32x16.f[2] := 0.25;
  LInSignedZeroF32x16.f[3] := -0.25;
  LInSignedZeroF32x16.f[6] := 0.5;
  LInSignedZeroF32x16.f[7] := -0.5;

  for LIndex := 0 to 7 do
    if (LIndex and 1) = 0 then
      LInSignedZeroF64x8.d[LIndex] := 0.0
    else
      LInSignedZeroF64x8.d[LIndex] := NegZeroF64;
  LInSignedZeroF64x8.d[2] := 0.25;
  LInSignedZeroF64x8.d[3] := -0.25;

  for LBackend in NON_X86_BACKENDS do
  begin
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);
    try
      LDispatch := GetDispatchTable;
      CheckNotNil(LDispatch, 'Dispatch table should be available');
      CheckTrue(Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.FloorF32x8) and Assigned(LDispatch^.CeilF32x8), 'Round/Trunc/Floor/Ceil F32x8 should be assigned');
      CheckTrue(Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4) and Assigned(LDispatch^.FloorF64x4) and Assigned(LDispatch^.CeilF64x4), 'Round/Trunc/Floor/Ceil F64x4 should be assigned');
      CheckTrue(Assigned(LDispatch^.RoundF32x16) and Assigned(LDispatch^.TruncF32x16) and Assigned(LDispatch^.FloorF32x16) and Assigned(LDispatch^.CeilF32x16), 'Round/Trunc/Floor/Ceil F32x16 should be assigned');
      CheckTrue(Assigned(LDispatch^.RoundF64x8) and Assigned(LDispatch^.TruncF64x8) and Assigned(LDispatch^.FloorF64x8) and Assigned(LDispatch^.CeilF64x8), 'Round/Trunc/Floor/Ceil F64x8 should be assigned');

      SetActiveBackend(sbScalar);
      LDispatch := GetDispatchTable;
      LExpectedRoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
      LExpectedTruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
      LExpectedFloorF32x8 := LDispatch^.FloorF32x8(LInF32x8);
      LExpectedCeilF32x8 := LDispatch^.CeilF32x8(LInF32x8);
      LExpectedRoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
      LExpectedTruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
      LExpectedFloorF64x4 := LDispatch^.FloorF64x4(LInF64x4);
      LExpectedCeilF64x4 := LDispatch^.CeilF64x4(LInF64x4);
      LExpectedRoundF32x16 := LDispatch^.RoundF32x16(LInF32x16);
      LExpectedTruncF32x16 := LDispatch^.TruncF32x16(LInF32x16);
      LExpectedFloorF32x16 := LDispatch^.FloorF32x16(LInF32x16);
      LExpectedCeilF32x16 := LDispatch^.CeilF32x16(LInF32x16);
      LExpectedRoundF64x8 := LDispatch^.RoundF64x8(LInF64x8);
      LExpectedTruncF64x8 := LDispatch^.TruncF64x8(LInF64x8);
      LExpectedFloorF64x8 := LDispatch^.FloorF64x8(LInF64x8);
      LExpectedCeilF64x8 := LDispatch^.CeilF64x8(LInF64x8);
      LExpectedRoundSignedZeroF32x8 := LDispatch^.RoundF32x8(LInSignedZeroF32x8);
      LExpectedTruncSignedZeroF32x8 := LDispatch^.TruncF32x8(LInSignedZeroF32x8);
      LExpectedRoundSignedZeroF64x4 := LDispatch^.RoundF64x4(LInSignedZeroF64x4);
      LExpectedTruncSignedZeroF64x4 := LDispatch^.TruncF64x4(LInSignedZeroF64x4);
      LExpectedRoundSignedZeroF32x16 := LDispatch^.RoundF32x16(LInSignedZeroF32x16);
      LExpectedTruncSignedZeroF32x16 := LDispatch^.TruncF32x16(LInSignedZeroF32x16);
      LExpectedRoundSignedZeroF64x8 := LDispatch^.RoundF64x8(LInSignedZeroF64x8);
      LExpectedTruncSignedZeroF64x8 := LDispatch^.TruncF64x8(LInSignedZeroF64x8);

      SetActiveBackend(LBackend);
      LDispatch := GetDispatchTable;
      LActualRoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
      LActualTruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
      LActualFloorF32x8 := LDispatch^.FloorF32x8(LInF32x8);
      LActualCeilF32x8 := LDispatch^.CeilF32x8(LInF32x8);
      LActualRoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
      LActualTruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
      LActualFloorF64x4 := LDispatch^.FloorF64x4(LInF64x4);
      LActualCeilF64x4 := LDispatch^.CeilF64x4(LInF64x4);
      LActualRoundF32x16 := LDispatch^.RoundF32x16(LInF32x16);
      LActualTruncF32x16 := LDispatch^.TruncF32x16(LInF32x16);
      LActualFloorF32x16 := LDispatch^.FloorF32x16(LInF32x16);
      LActualCeilF32x16 := LDispatch^.CeilF32x16(LInF32x16);
      LActualRoundF64x8 := LDispatch^.RoundF64x8(LInF64x8);
      LActualTruncF64x8 := LDispatch^.TruncF64x8(LInF64x8);
      LActualFloorF64x8 := LDispatch^.FloorF64x8(LInF64x8);
      LActualCeilF64x8 := LDispatch^.CeilF64x8(LInF64x8);
      LActualRoundSignedZeroF32x8 := LDispatch^.RoundF32x8(LInSignedZeroF32x8);
      LActualTruncSignedZeroF32x8 := LDispatch^.TruncF32x8(LInSignedZeroF32x8);
      LActualRoundSignedZeroF64x4 := LDispatch^.RoundF64x4(LInSignedZeroF64x4);
      LActualTruncSignedZeroF64x4 := LDispatch^.TruncF64x4(LInSignedZeroF64x4);
      LActualRoundSignedZeroF32x16 := LDispatch^.RoundF32x16(LInSignedZeroF32x16);
      LActualTruncSignedZeroF32x16 := LDispatch^.TruncF32x16(LInSignedZeroF32x16);
      LActualRoundSignedZeroF64x8 := LDispatch^.RoundF64x8(LInSignedZeroF64x8);
      LActualTruncSignedZeroF64x8 := LDispatch^.TruncF64x8(LInSignedZeroF64x8);

      for LIndex := 0 to 7 do
      begin
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' RoundF32x8[' + IntToStr(LIndex) + ']', LExpectedRoundF32x8.f[LIndex], LActualRoundF32x8.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' TruncF32x8[' + IntToStr(LIndex) + ']', LExpectedTruncF32x8.f[LIndex], LActualTruncF32x8.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' FloorF32x8[' + IntToStr(LIndex) + ']', LExpectedFloorF32x8.f[LIndex], LActualFloorF32x8.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' CeilF32x8[' + IntToStr(LIndex) + ']', LExpectedCeilF32x8.f[LIndex], LActualCeilF32x8.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' SignedZero RoundF32x8[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF32x8.f[LIndex], LActualRoundSignedZeroF32x8.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' SignedZero TruncF32x8[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF32x8.f[LIndex], LActualTruncSignedZeroF32x8.f[LIndex]);
        AssertSingleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero RoundF32x8[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF32x8.f[LIndex], LActualRoundSignedZeroF32x8.f[LIndex]);
        AssertSingleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero TruncF32x8[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF32x8.f[LIndex], LActualTruncSignedZeroF32x8.f[LIndex]);
      end;

      for LIndex := 0 to 3 do
      begin
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' RoundF64x4[' + IntToStr(LIndex) + ']', LExpectedRoundF64x4.d[LIndex], LActualRoundF64x4.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' TruncF64x4[' + IntToStr(LIndex) + ']', LExpectedTruncF64x4.d[LIndex], LActualTruncF64x4.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' FloorF64x4[' + IntToStr(LIndex) + ']', LExpectedFloorF64x4.d[LIndex], LActualFloorF64x4.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' CeilF64x4[' + IntToStr(LIndex) + ']', LExpectedCeilF64x4.d[LIndex], LActualCeilF64x4.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' SignedZero RoundF64x4[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF64x4.d[LIndex], LActualRoundSignedZeroF64x4.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' SignedZero TruncF64x4[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF64x4.d[LIndex], LActualTruncSignedZeroF64x4.d[LIndex]);
        AssertDoubleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero RoundF64x4[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF64x4.d[LIndex], LActualRoundSignedZeroF64x4.d[LIndex]);
        AssertDoubleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero TruncF64x4[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF64x4.d[LIndex], LActualTruncSignedZeroF64x4.d[LIndex]);
      end;

      for LIndex := 0 to 15 do
      begin
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' RoundF32x16[' + IntToStr(LIndex) + ']', LExpectedRoundF32x16.f[LIndex], LActualRoundF32x16.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' TruncF32x16[' + IntToStr(LIndex) + ']', LExpectedTruncF32x16.f[LIndex], LActualTruncF32x16.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' FloorF32x16[' + IntToStr(LIndex) + ']', LExpectedFloorF32x16.f[LIndex], LActualFloorF32x16.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' CeilF32x16[' + IntToStr(LIndex) + ']', LExpectedCeilF32x16.f[LIndex], LActualCeilF32x16.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' SignedZero RoundF32x16[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF32x16.f[LIndex], LActualRoundSignedZeroF32x16.f[LIndex]);
        AssertSingleSemantics(IEEE754BackendName(LBackend) + ' SignedZero TruncF32x16[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF32x16.f[LIndex], LActualTruncSignedZeroF32x16.f[LIndex]);
        AssertSingleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero RoundF32x16[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF32x16.f[LIndex], LActualRoundSignedZeroF32x16.f[LIndex]);
        AssertSingleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero TruncF32x16[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF32x16.f[LIndex], LActualTruncSignedZeroF32x16.f[LIndex]);
      end;

      for LIndex := 0 to 7 do
      begin
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' RoundF64x8[' + IntToStr(LIndex) + ']', LExpectedRoundF64x8.d[LIndex], LActualRoundF64x8.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' TruncF64x8[' + IntToStr(LIndex) + ']', LExpectedTruncF64x8.d[LIndex], LActualTruncF64x8.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' FloorF64x8[' + IntToStr(LIndex) + ']', LExpectedFloorF64x8.d[LIndex], LActualFloorF64x8.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' CeilF64x8[' + IntToStr(LIndex) + ']', LExpectedCeilF64x8.d[LIndex], LActualCeilF64x8.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' SignedZero RoundF64x8[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF64x8.d[LIndex], LActualRoundSignedZeroF64x8.d[LIndex]);
        AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' SignedZero TruncF64x8[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF64x8.d[LIndex], LActualTruncSignedZeroF64x8.d[LIndex]);
        AssertDoubleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero RoundF64x8[' + IntToStr(LIndex) + ']', LExpectedRoundSignedZeroF64x8.d[LIndex], LActualRoundSignedZeroF64x8.d[LIndex]);
        AssertDoubleZeroSign(IEEE754BackendName(LBackend) + ' SignedZero TruncF64x8[' + IntToStr(LIndex) + ']', LExpectedTruncSignedZeroF64x8.d[LIndex], LActualTruncSignedZeroF64x8.d[LIndex]);
      end;
    finally
      ResetToAutomaticBackend;
    end;
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 backend available on this host (allowed)');
end;

procedure TTestCase_NonX86IEEE754.Test_NonX86_FloorCeil_PropertyLike_FixedSeed_IfAvailable;
const
  NON_X86_BACKENDS: array[0..1] of TSimdBackend = (sbNEON, sbRISCVV);
  SAMPLE_ROUNDS = 64;
var
  LBackend: TSimdBackend;
  LCheckedBackends: Integer;
  LRound: Integer;
  LIndex: Integer;
  LDispatch: PSimdDispatchTable;
  LSeed: QWord;

  LInF32x8, LScalarFloorF32x8, LScalarCeilF32x8, LBackendFloorF32x8, LBackendCeilF32x8: TVecF32x8;
  LInF64x4, LScalarFloorF64x4, LScalarCeilF64x4, LBackendFloorF64x4, LBackendCeilF64x4: TVecF64x4;
  LInF32x16, LScalarFloorF32x16, LScalarCeilF32x16, LBackendFloorF32x16, LBackendCeilF32x16: TVecF32x16;
  LInF64x8, LScalarFloorF64x8, LScalarCeilF64x8, LBackendFloorF64x8, LBackendCeilF64x8: TVecF64x8;

  function NextU32: Cardinal; inline;
  begin
    LSeed := LSeed * QWord(6364136223846793005) + QWord(1442695040888963407);
    Result := Cardinal(LSeed shr 32);
  end;

  function NextSingleValue: Single;
  var
    LRaw: Cardinal;
  begin
    LRaw := NextU32;
    case (LRaw and 31) of
      0: Result := NaNF32;
      1: Result := PosInfF32;
      2: Result := NegInfF32;
      3: Result := 0.0;
      4: Result := -0.0;
      5: Result := 0.5;
      6: Result := -0.5;
      7: Result := 4096.75;
      8: Result := -4096.75;
    else
      Result := (Integer(LRaw and $001FFFFF) - Integer($000FFFFF)) / 128.0;
    end;
  end;

  function NextDoubleValue: Double;
  var
    LRaw: Cardinal;
  begin
    LRaw := NextU32;
    case (LRaw and 31) of
      0: Result := NaNF64;
      1: Result := PosInfF64;
      2: Result := NegInfF64;
      3: Result := 0.0;
      4: Result := -0.0;
      5: Result := 0.5;
      6: Result := -0.5;
      7: Result := 262144.125;
      8: Result := -262144.125;
    else
      Result := (Int64(LRaw and $003FFFFF) - Int64($001FFFFF)) / 64.0;
    end;
  end;

  procedure AssertSingleSemantics(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertFloorCeilInvariantSingle(const aPrefix: string; const aInput, aFloor, aCeil: Single);
  begin
    if IsNaNSingle(aInput) or IsInfinite(aInput) then
      Exit;
    CheckTrue(aFloor <= aInput + 1e-6, aPrefix + ' floor<=x');
    CheckTrue(aCeil + 1e-6 >= aInput, aPrefix + ' ceil>=x');
    CheckTrue((aCeil - aFloor) <= 1.0 + 1e-6, aPrefix + ' ceil-floor<=1');
    CheckNear(0.0, Frac(aFloor), 0.0, aPrefix + ' floor is integral');
    CheckNear(0.0, Frac(aCeil), 0.0, aPrefix + ' ceil is integral');
  end;

  procedure AssertFloorCeilInvariantDouble(const aPrefix: string; const aInput, aFloor, aCeil: Double);
  begin
    if IsNaNDouble(aInput) or IsInfinite(aInput) then
      Exit;
    CheckTrue(aFloor <= aInput + 1e-12, aPrefix + ' floor<=x');
    CheckTrue(aCeil + 1e-12 >= aInput, aPrefix + ' ceil>=x');
    CheckTrue((aCeil - aFloor) <= 1.0 + 1e-12, aPrefix + ' ceil-floor<=1');
    CheckNear(0.0, Frac(aFloor), 0.0, aPrefix + ' floor is integral');
    CheckNear(0.0, Frac(aCeil), 0.0, aPrefix + ' ceil is integral');
  end;
begin
  LCheckedBackends := 0;

  for LBackend in NON_X86_BACKENDS do
  begin
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);
    try
      LSeed := QWord($C0FFEE1234A5B6C7) xor (QWord(Ord(LBackend)) * QWord($9E3779B97F4A7C15));

      for LRound := 1 to SAMPLE_ROUNDS do
      begin
        for LIndex := 0 to 7 do
          LInF32x8.f[LIndex] := NextSingleValue;
        for LIndex := 0 to 3 do
          LInF64x4.d[LIndex] := NextDoubleValue;
        for LIndex := 0 to 15 do
          LInF32x16.f[LIndex] := NextSingleValue;
        for LIndex := 0 to 7 do
          LInF64x8.d[LIndex] := NextDoubleValue;

        SetActiveBackend(sbScalar);
        LDispatch := GetDispatchTable;
        CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.FloorF32x8) and Assigned(LDispatch^.CeilF32x8) and Assigned(LDispatch^.FloorF64x4) and Assigned(LDispatch^.CeilF64x4) and Assigned(LDispatch^.FloorF32x16) and Assigned(LDispatch^.CeilF32x16) and Assigned(LDispatch^.FloorF64x8) and Assigned(LDispatch^.CeilF64x8), 'Scalar dispatch should provide wide Floor/Ceil');

        LScalarFloorF32x8 := LDispatch^.FloorF32x8(LInF32x8);
        LScalarCeilF32x8 := LDispatch^.CeilF32x8(LInF32x8);
        LScalarFloorF64x4 := LDispatch^.FloorF64x4(LInF64x4);
        LScalarCeilF64x4 := LDispatch^.CeilF64x4(LInF64x4);
        LScalarFloorF32x16 := LDispatch^.FloorF32x16(LInF32x16);
        LScalarCeilF32x16 := LDispatch^.CeilF32x16(LInF32x16);
        LScalarFloorF64x8 := LDispatch^.FloorF64x8(LInF64x8);
        LScalarCeilF64x8 := LDispatch^.CeilF64x8(LInF64x8);

        SetActiveBackend(LBackend);
        LDispatch := GetDispatchTable;
        CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.FloorF32x8) and Assigned(LDispatch^.CeilF32x8) and Assigned(LDispatch^.FloorF64x4) and Assigned(LDispatch^.CeilF64x4) and Assigned(LDispatch^.FloorF32x16) and Assigned(LDispatch^.CeilF32x16) and Assigned(LDispatch^.FloorF64x8) and Assigned(LDispatch^.CeilF64x8), 'Non-x86 dispatch should provide wide Floor/Ceil');

        LBackendFloorF32x8 := LDispatch^.FloorF32x8(LInF32x8);
        LBackendCeilF32x8 := LDispatch^.CeilF32x8(LInF32x8);
        LBackendFloorF64x4 := LDispatch^.FloorF64x4(LInF64x4);
        LBackendCeilF64x4 := LDispatch^.CeilF64x4(LInF64x4);
        LBackendFloorF32x16 := LDispatch^.FloorF32x16(LInF32x16);
        LBackendCeilF32x16 := LDispatch^.CeilF32x16(LInF32x16);
        LBackendFloorF64x8 := LDispatch^.FloorF64x8(LInF64x8);
        LBackendCeilF64x8 := LDispatch^.CeilF64x8(LInF64x8);

        for LIndex := 0 to 7 do
        begin
          AssertSingleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' FloorF32x8[' + IntToStr(LIndex) + ']', LScalarFloorF32x8.f[LIndex], LBackendFloorF32x8.f[LIndex]);
          AssertSingleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' CeilF32x8[' + IntToStr(LIndex) + ']', LScalarCeilF32x8.f[LIndex], LBackendCeilF32x8.f[LIndex]);
          AssertFloorCeilInvariantSingle(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' F32x8[' + IntToStr(LIndex) + ']', LInF32x8.f[LIndex], LBackendFloorF32x8.f[LIndex], LBackendCeilF32x8.f[LIndex]);
        end;

        for LIndex := 0 to 3 do
        begin
          AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' FloorF64x4[' + IntToStr(LIndex) + ']', LScalarFloorF64x4.d[LIndex], LBackendFloorF64x4.d[LIndex]);
          AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' CeilF64x4[' + IntToStr(LIndex) + ']', LScalarCeilF64x4.d[LIndex], LBackendCeilF64x4.d[LIndex]);
          AssertFloorCeilInvariantDouble(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' F64x4[' + IntToStr(LIndex) + ']', LInF64x4.d[LIndex], LBackendFloorF64x4.d[LIndex], LBackendCeilF64x4.d[LIndex]);
        end;

        for LIndex := 0 to 15 do
        begin
          AssertSingleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' FloorF32x16[' + IntToStr(LIndex) + ']', LScalarFloorF32x16.f[LIndex], LBackendFloorF32x16.f[LIndex]);
          AssertSingleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' CeilF32x16[' + IntToStr(LIndex) + ']', LScalarCeilF32x16.f[LIndex], LBackendCeilF32x16.f[LIndex]);
          AssertFloorCeilInvariantSingle(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' F32x16[' + IntToStr(LIndex) + ']', LInF32x16.f[LIndex], LBackendFloorF32x16.f[LIndex], LBackendCeilF32x16.f[LIndex]);
        end;

        for LIndex := 0 to 7 do
        begin
          AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' FloorF64x8[' + IntToStr(LIndex) + ']', LScalarFloorF64x8.d[LIndex], LBackendFloorF64x8.d[LIndex]);
          AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' CeilF64x8[' + IntToStr(LIndex) + ']', LScalarCeilF64x8.d[LIndex], LBackendCeilF64x8.d[LIndex]);
          AssertFloorCeilInvariantDouble(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' F64x8[' + IntToStr(LIndex) + ']', LInF64x8.d[LIndex], LBackendFloorF64x8.d[LIndex], LBackendCeilF64x8.d[LIndex]);
        end;
      end;
    finally
      ResetToAutomaticBackend;
    end;
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 backend available on this host (allowed)');
end;

procedure TTestCase_NonX86IEEE754.Test_NonX86_RoundTrunc_PropertyLike_FixedSeed_IfAvailable;
const
  NON_X86_BACKENDS: array[0..1] of TSimdBackend = (sbNEON, sbRISCVV);
  SAMPLE_ROUNDS = 64;
var
  LBackend: TSimdBackend;
  LCheckedBackends: Integer;
  LRound: Integer;
  LIndex: Integer;
  LDispatch: PSimdDispatchTable;
  LSeed: QWord;

  LInF32x8, LScalarRoundF32x8, LScalarTruncF32x8, LBackendRoundF32x8, LBackendTruncF32x8: TVecF32x8;
  LInF64x4, LScalarRoundF64x4, LScalarTruncF64x4, LBackendRoundF64x4, LBackendTruncF64x4: TVecF64x4;
  LInF32x16, LScalarRoundF32x16, LScalarTruncF32x16, LBackendRoundF32x16, LBackendTruncF32x16: TVecF32x16;
  LInF64x8, LScalarRoundF64x8, LScalarTruncF64x8, LBackendRoundF64x8, LBackendTruncF64x8: TVecF64x8;

  function NextU32: Cardinal; inline;
  begin
    LSeed := LSeed * QWord(6364136223846793005) + QWord(1442695040888963407);
    Result := Cardinal(LSeed shr 32);
  end;

  function NextSingleValue: Single;
  var
    LRaw: Cardinal;
  begin
    LRaw := NextU32;
    case (LRaw and 31) of
      0: Result := NaNF32;
      1: Result := PosInfF32;
      2: Result := NegInfF32;
      3: Result := 0.0;
      4: Result := -0.0;
      5: Result := 0.5;
      6: Result := -0.5;
      7: Result := 1.5;
      8: Result := -1.5;
      9: Result := 2.5;
      10: Result := -2.5;
      11: Result := 2048.75;
      12: Result := -2048.75;
    else
      Result := (Integer(LRaw and $003FFFFF) - Integer($001FFFFF)) / 64.0;
    end;
  end;

  function NextDoubleValue: Double;
  var
    LRaw: Cardinal;
  begin
    LRaw := NextU32;
    case (LRaw and 31) of
      0: Result := NaNF64;
      1: Result := PosInfF64;
      2: Result := NegInfF64;
      3: Result := 0.0;
      4: Result := -0.0;
      5: Result := 0.5;
      6: Result := -0.5;
      7: Result := 1.5;
      8: Result := -1.5;
      9: Result := 2.5;
      10: Result := -2.5;
      11: Result := 131072.125;
      12: Result := -131072.125;
    else
      Result := (Int64(LRaw and $007FFFFF) - Int64($003FFFFF)) / 32.0;
    end;
  end;

  procedure AssertSingleSemantics(const aPrefix: string; const aExpected, aActual: Single);
  begin
    if IsNaNSingle(aExpected) then
      CheckTrue(IsNaNSingle(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertDoubleSemantics(const aPrefix: string; const aExpected, aActual: Double);
  begin
    if IsNaNDouble(aExpected) then
      CheckTrue(IsNaNDouble(aActual), aPrefix + ' expected NaN')
    else if IsInfinite(aExpected) then
      CheckTrue(IsInfinite(aActual) and ((aActual > 0) = (aExpected > 0)), aPrefix + ' expected Inf sign')
    else
      CheckNear(aExpected, aActual, 0.0, aPrefix + ' finite compare');
  end;

  procedure AssertRoundTruncInvariantSingle(const aPrefix: string; const aInput, aRound, aTrunc: Single);
  begin
    if IsNaNSingle(aInput) or IsInfinite(aInput) then
      Exit;
    CheckNear(0.0, Frac(aRound), 0.0, aPrefix + ' round integral');
    CheckNear(0.0, Frac(aTrunc), 0.0, aPrefix + ' trunc integral');
    CheckTrue(Abs(aRound - aInput) <= 0.500001, aPrefix + ' abs(round-x)<=0.5');
    CheckTrue(Abs(aTrunc) <= Abs(aInput) + 1e-6, aPrefix + ' abs(trunc)<=abs(x)');
    if aInput >= 0 then
    begin
      CheckTrue(aTrunc <= aInput + 1e-6, aPrefix + ' trunc<=x (x>=0)');
      CheckTrue(aTrunc >= -1e-6, aPrefix + ' trunc>=0 (x>=0)');
    end
    else
    begin
      CheckTrue(aTrunc + 1e-6 >= aInput, aPrefix + ' trunc>=x (x<0)');
      CheckTrue(aTrunc <= 1e-6, aPrefix + ' trunc<=0 (x<0)');
    end;
  end;

  procedure AssertRoundTruncInvariantDouble(const aPrefix: string; const aInput, aRound, aTrunc: Double);
  begin
    if IsNaNDouble(aInput) or IsInfinite(aInput) then
      Exit;
    CheckNear(0.0, Frac(aRound), 0.0, aPrefix + ' round integral');
    CheckNear(0.0, Frac(aTrunc), 0.0, aPrefix + ' trunc integral');
    CheckTrue(Abs(aRound - aInput) <= 0.500000000001, aPrefix + ' abs(round-x)<=0.5');
    CheckTrue(Abs(aTrunc) <= Abs(aInput) + 1e-12, aPrefix + ' abs(trunc)<=abs(x)');
    if aInput >= 0 then
    begin
      CheckTrue(aTrunc <= aInput + 1e-12, aPrefix + ' trunc<=x (x>=0)');
      CheckTrue(aTrunc >= -1e-12, aPrefix + ' trunc>=0 (x>=0)');
    end
    else
    begin
      CheckTrue(aTrunc + 1e-12 >= aInput, aPrefix + ' trunc>=x (x<0)');
      CheckTrue(aTrunc <= 1e-12, aPrefix + ' trunc<=0 (x<0)');
    end;
  end;
begin
  LCheckedBackends := 0;

  for LBackend in NON_X86_BACKENDS do
  begin
    if not IsBackendRegistered(LBackend) then
      Continue;
    if not TrySetActiveBackend(LBackend) then
      Continue;

    Inc(LCheckedBackends);
    try
      LSeed := QWord($5EEDBEEF12345678) xor (QWord(Ord(LBackend)) * QWord($9E3779B97F4A7C15));

      for LRound := 1 to SAMPLE_ROUNDS do
      begin
        for LIndex := 0 to 7 do
          LInF32x8.f[LIndex] := NextSingleValue;
        for LIndex := 0 to 3 do
          LInF64x4.d[LIndex] := NextDoubleValue;
        for LIndex := 0 to 15 do
          LInF32x16.f[LIndex] := NextSingleValue;
        for LIndex := 0 to 7 do
          LInF64x8.d[LIndex] := NextDoubleValue;

        SetActiveBackend(sbScalar);
        LDispatch := GetDispatchTable;
        CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4) and Assigned(LDispatch^.RoundF32x16) and Assigned(LDispatch^.TruncF32x16) and Assigned(LDispatch^.RoundF64x8) and Assigned(LDispatch^.TruncF64x8), 'Scalar dispatch should provide wide Round/Trunc');

        LScalarRoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
        LScalarTruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
        LScalarRoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
        LScalarTruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
        LScalarRoundF32x16 := LDispatch^.RoundF32x16(LInF32x16);
        LScalarTruncF32x16 := LDispatch^.TruncF32x16(LInF32x16);
        LScalarRoundF64x8 := LDispatch^.RoundF64x8(LInF64x8);
        LScalarTruncF64x8 := LDispatch^.TruncF64x8(LInF64x8);

        SetActiveBackend(LBackend);
        LDispatch := GetDispatchTable;
        CheckTrue((LDispatch <> nil) and Assigned(LDispatch^.RoundF32x8) and Assigned(LDispatch^.TruncF32x8) and Assigned(LDispatch^.RoundF64x4) and Assigned(LDispatch^.TruncF64x4) and Assigned(LDispatch^.RoundF32x16) and Assigned(LDispatch^.TruncF32x16) and Assigned(LDispatch^.RoundF64x8) and Assigned(LDispatch^.TruncF64x8), 'Non-x86 dispatch should provide wide Round/Trunc');

        LBackendRoundF32x8 := LDispatch^.RoundF32x8(LInF32x8);
        LBackendTruncF32x8 := LDispatch^.TruncF32x8(LInF32x8);
        LBackendRoundF64x4 := LDispatch^.RoundF64x4(LInF64x4);
        LBackendTruncF64x4 := LDispatch^.TruncF64x4(LInF64x4);
        LBackendRoundF32x16 := LDispatch^.RoundF32x16(LInF32x16);
        LBackendTruncF32x16 := LDispatch^.TruncF32x16(LInF32x16);
        LBackendRoundF64x8 := LDispatch^.RoundF64x8(LInF64x8);
        LBackendTruncF64x8 := LDispatch^.TruncF64x8(LInF64x8);

        for LIndex := 0 to 7 do
        begin
          AssertSingleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' RoundF32x8[' + IntToStr(LIndex) + ']', LScalarRoundF32x8.f[LIndex], LBackendRoundF32x8.f[LIndex]);
          AssertSingleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' TruncF32x8[' + IntToStr(LIndex) + ']', LScalarTruncF32x8.f[LIndex], LBackendTruncF32x8.f[LIndex]);
          AssertRoundTruncInvariantSingle(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' F32x8[' + IntToStr(LIndex) + ']', LInF32x8.f[LIndex], LBackendRoundF32x8.f[LIndex], LBackendTruncF32x8.f[LIndex]);
        end;

        for LIndex := 0 to 3 do
        begin
          AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' RoundF64x4[' + IntToStr(LIndex) + ']', LScalarRoundF64x4.d[LIndex], LBackendRoundF64x4.d[LIndex]);
          AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' TruncF64x4[' + IntToStr(LIndex) + ']', LScalarTruncF64x4.d[LIndex], LBackendTruncF64x4.d[LIndex]);
          AssertRoundTruncInvariantDouble(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' F64x4[' + IntToStr(LIndex) + ']', LInF64x4.d[LIndex], LBackendRoundF64x4.d[LIndex], LBackendTruncF64x4.d[LIndex]);
        end;

        for LIndex := 0 to 15 do
        begin
          AssertSingleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' RoundF32x16[' + IntToStr(LIndex) + ']', LScalarRoundF32x16.f[LIndex], LBackendRoundF32x16.f[LIndex]);
          AssertSingleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' TruncF32x16[' + IntToStr(LIndex) + ']', LScalarTruncF32x16.f[LIndex], LBackendTruncF32x16.f[LIndex]);
          AssertRoundTruncInvariantSingle(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' F32x16[' + IntToStr(LIndex) + ']', LInF32x16.f[LIndex], LBackendRoundF32x16.f[LIndex], LBackendTruncF32x16.f[LIndex]);
        end;

        for LIndex := 0 to 7 do
        begin
          AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' RoundF64x8[' + IntToStr(LIndex) + ']', LScalarRoundF64x8.d[LIndex], LBackendRoundF64x8.d[LIndex]);
          AssertDoubleSemantics(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' TruncF64x8[' + IntToStr(LIndex) + ']', LScalarTruncF64x8.d[LIndex], LBackendTruncF64x8.d[LIndex]);
          AssertRoundTruncInvariantDouble(IEEE754BackendName(LBackend) + ' Round ' + IntToStr(LRound) + ' F64x8[' + IntToStr(LIndex) + ']', LInF64x8.d[LIndex], LBackendRoundF64x8.d[LIndex], LBackendTruncF64x8.d[LIndex]);
        end;
      end;
    finally
      ResetToAutomaticBackend;
    end;
  end;

  if LCheckedBackends = 0 then
    CheckTrue(True, 'No non-x86 backend available on this host (allowed)');
end;


end.