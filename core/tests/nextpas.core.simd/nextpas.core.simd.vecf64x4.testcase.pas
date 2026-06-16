unit nextpas.core.simd.vecf64x4.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  Classes, nextpas.core.text.conv, nextpas.core.math, fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base,
  nextpas.core.simd.utils,
  nextpas.core.simd.scalar,
  nextpas.core.simd.ops;

type
  // ✅ TVecF64x4 (256-bit 双精度浮点向量) 完整测试套件 (2026-02-05)
  TTestCase_VecF64x4 = class(TScalarBackendStatefulTestCase)
  published
    // === 算术操作 ===
    procedure Test_VecF64x4_Add;
    procedure Test_VecF64x4_Sub;
    procedure Test_VecF64x4_Mul;
    procedure Test_VecF64x4_Div;
    procedure Test_VecF64x4_Neg;

    // === 数学函数 ===
    procedure Test_VecF64x4_Abs;
    procedure Test_VecF64x4_Sqrt;
    procedure Test_VecF64x4_Min;
    procedure Test_VecF64x4_Max;
    procedure Test_VecF64x4_Clamp;
    procedure Test_VecF64x4_Floor;
    procedure Test_VecF64x4_Ceil;
    procedure Test_VecF64x4_Round;
    procedure Test_VecF64x4_Trunc;
    procedure Test_VecF64x4_Fma;

    // === 比较操作 ===
    procedure Test_VecF64x4_CmpEq;
    procedure Test_VecF64x4_CmpLt;
    procedure Test_VecF64x4_CmpLe;
    procedure Test_VecF64x4_CmpGt;
    procedure Test_VecF64x4_CmpGe;
    procedure Test_VecF64x4_CmpNe;

    // === 规约操作 ===
    procedure Test_VecF64x4_ReduceAdd;
    procedure Test_VecF64x4_ReduceMin;
    procedure Test_VecF64x4_ReduceMax;
    procedure Test_VecF64x4_ReduceMul;

    // === 工具函数 ===
    procedure Test_VecF64x4_Splat;
    procedure Test_VecF64x4_Zero;
    procedure Test_VecF64x4_LoadStore;
    procedure Test_VecF64x4_PublicUtilityFacade_Basic;
    procedure Test_VecF64x4_SizeOf;
    procedure Test_VecF64x4_LoHi;
  end;

implementation
{ TTestCase_VecF64x4 }

const
  F64_TOLERANCE = 1e-10;  // 双精度浮点容差

// === 算术操作测试 ===

procedure TTestCase_VecF64x4.Test_VecF64x4_Add;
var
  a, b, r: TVecF64x4;
begin
  // 测试基本加法: 1.5 + 2.5 = 4.0 等
  a.d[0] := 1.5; a.d[1] := 2.5; a.d[2] := 3.5; a.d[3] := 4.5;
  b.d[0] := 2.5; b.d[1] := 3.5; b.d[2] := 4.5; b.d[3] := 5.5;
  r := VecF64x4Add(a, b);

  AssertEquals('Add[0] = 1.5 + 2.5', 4.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Add[1] = 2.5 + 3.5', 6.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Add[2] = 3.5 + 4.5', 8.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Add[3] = 4.5 + 5.5', 10.0, r.d[3], F64_TOLERANCE);

  // 测试负数加法
  a.d[0] := -5.0; a.d[1] := 10.0; a.d[2] := -15.0; a.d[3] := 20.0;
  b.d[0] := 3.0;  b.d[1] := -3.0; b.d[2] := 5.0;   b.d[3] := -5.0;
  r := VecF64x4Add(a, b);

  AssertEquals('Add[0] = -5.0 + 3.0', -2.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Add[1] = 10.0 + -3.0', 7.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Add[2] = -15.0 + 5.0', -10.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Add[3] = 20.0 + -5.0', 15.0, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Sub;
var
  a, b, r: TVecF64x4;
begin
  // 测试基本减法
  a.d[0] := 10.0; a.d[1] := 20.0; a.d[2] := 30.0; a.d[3] := 40.0;
  b.d[0] := 3.0;  b.d[1] := 5.0;  b.d[2] := 7.0;  b.d[3] := 9.0;
  r := VecF64x4Sub(a, b);

  AssertEquals('Sub[0] = 10.0 - 3.0', 7.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Sub[1] = 20.0 - 5.0', 15.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Sub[2] = 30.0 - 7.0', 23.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Sub[3] = 40.0 - 9.0', 31.0, r.d[3], F64_TOLERANCE);

  // 测试导致负数结果的减法
  a.d[0] := 5.0; a.d[1] := 5.0; a.d[2] := 5.0; a.d[3] := 5.0;
  b.d[0] := 10.0; b.d[1] := 15.0; b.d[2] := 20.0; b.d[3] := 25.0;
  r := VecF64x4Sub(a, b);

  AssertEquals('Sub[0] = 5.0 - 10.0', -5.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Sub[1] = 5.0 - 15.0', -10.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Sub[2] = 5.0 - 20.0', -15.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Sub[3] = 5.0 - 25.0', -20.0, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Mul;
var
  a, b, r: TVecF64x4;
begin
  // 测试基本乘法
  a.d[0] := 2.0; a.d[1] := 3.0; a.d[2] := 4.0; a.d[3] := 5.0;
  b.d[0] := 3.0; b.d[1] := 4.0; b.d[2] := 5.0; b.d[3] := 6.0;
  r := VecF64x4Mul(a, b);

  AssertEquals('Mul[0] = 2.0 * 3.0', 6.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Mul[1] = 3.0 * 4.0', 12.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Mul[2] = 4.0 * 5.0', 20.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Mul[3] = 5.0 * 6.0', 30.0, r.d[3], F64_TOLERANCE);

  // 测试负数乘法
  a.d[0] := -2.0; a.d[1] := 3.0;  a.d[2] := -4.0; a.d[3] := 5.0;
  b.d[0] := 3.0;  b.d[1] := -4.0; b.d[2] := -5.0; b.d[3] := 6.0;
  r := VecF64x4Mul(a, b);

  AssertEquals('Mul[0] = -2.0 * 3.0', -6.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Mul[1] = 3.0 * -4.0', -12.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Mul[2] = -4.0 * -5.0', 20.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Mul[3] = 5.0 * 6.0', 30.0, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Div;
var
  a, b, r: TVecF64x4;
begin
  // 测试基本除法
  a.d[0] := 12.0; a.d[1] := 24.0; a.d[2] := 36.0; a.d[3] := 48.0;
  b.d[0] := 3.0;  b.d[1] := 4.0;  b.d[2] := 6.0;  b.d[3] := 8.0;
  r := VecF64x4Div(a, b);

  AssertEquals('Div[0] = 12.0 / 3.0', 4.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Div[1] = 24.0 / 4.0', 6.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Div[2] = 36.0 / 6.0', 6.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Div[3] = 48.0 / 8.0', 6.0, r.d[3], F64_TOLERANCE);

  // 测试小数结果
  a.d[0] := 10.0; a.d[1] := 7.0; a.d[2] := 5.0; a.d[3] := 1.0;
  b.d[0] := 4.0;  b.d[1] := 2.0; b.d[2] := 3.0; b.d[3] := 8.0;
  r := VecF64x4Div(a, b);

  AssertEquals('Div[0] = 10.0 / 4.0', 2.5, r.d[0], F64_TOLERANCE);
  AssertEquals('Div[1] = 7.0 / 2.0', 3.5, r.d[1], F64_TOLERANCE);
  AssertEquals('Div[2] = 5.0 / 3.0', Double(5.0)/Double(3.0), r.d[2], F64_TOLERANCE);
  AssertEquals('Div[3] = 1.0 / 8.0', 0.125, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Neg;
var
  a, r: TVecF64x4;
begin
  // 测试取负运算（使用运算符）
  a.d[0] := 5.0;  a.d[1] := -3.0; a.d[2] := 0.0; a.d[3] := -7.5;
  r := -a;  // 使用运算符重载

  AssertEquals('Neg[0] = -5.0', -5.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Neg[1] = -(-3.0)', 3.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Neg[2] = -0.0', 0.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Neg[3] = -(-7.5)', 7.5, r.d[3], F64_TOLERANCE);

  // 测试大数取负
  a.d[0] := 1e15; a.d[1] := -1e15; a.d[2] := 1e-15; a.d[3] := -1e-15;
  r := -a;

  AssertEquals('Neg large positive', -1e15, r.d[0], 1.0);  // 大数需要较大容差
  AssertEquals('Neg large negative', 1e15, r.d[1], 1.0);
  AssertEquals('Neg small positive', -1e-15, r.d[2], F64_TOLERANCE);
  AssertEquals('Neg small negative', 1e-15, r.d[3], F64_TOLERANCE);
end;

// === 数学函数测试 ===

procedure TTestCase_VecF64x4.Test_VecF64x4_Abs;
var
  a, r: TVecF64x4;
begin
  // 测试绝对值
  a.d[0] := -5.0; a.d[1] := 3.0; a.d[2] := -7.5; a.d[3] := 0.0;
  r := VecF64x4Abs(a);

  AssertEquals('Abs(-5.0) = 5.0', 5.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Abs(3.0) = 3.0', 3.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Abs(-7.5) = 7.5', 7.5, r.d[2], F64_TOLERANCE);
  AssertEquals('Abs(0.0) = 0.0', 0.0, r.d[3], F64_TOLERANCE);

  // 测试极值
  a.d[0] := -1e100; a.d[1] := 1e100; a.d[2] := -1e-100; a.d[3] := 1e-100;
  r := VecF64x4Abs(a);

  AssertEquals('Abs(-1e100)', 1e100, r.d[0], 1e90);
  AssertEquals('Abs(1e100)', 1e100, r.d[1], 1e90);
  AssertEquals('Abs(-1e-100)', 1e-100, r.d[2], F64_TOLERANCE);
  AssertEquals('Abs(1e-100)', 1e-100, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Sqrt;
var
  a, r: TVecF64x4;
begin
  // 测试平方根
  a.d[0] := 4.0; a.d[1] := 9.0; a.d[2] := 16.0; a.d[3] := 25.0;
  r := VecF64x4Sqrt(a);

  AssertEquals('Sqrt(4.0) = 2.0', 2.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Sqrt(9.0) = 3.0', 3.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Sqrt(16.0) = 4.0', 4.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Sqrt(25.0) = 5.0', 5.0, r.d[3], F64_TOLERANCE);

  // 测试非整数平方根
  a.d[0] := 2.0; a.d[1] := 3.0; a.d[2] := 0.25; a.d[3] := 1.0;
  r := VecF64x4Sqrt(a);

  AssertEquals('Sqrt(2.0)', System.Sqrt(Double(2.0)), r.d[0], F64_TOLERANCE);
  AssertEquals('Sqrt(3.0)', System.Sqrt(Double(3.0)), r.d[1], F64_TOLERANCE);
  AssertEquals('Sqrt(0.25) = 0.5', 0.5, r.d[2], F64_TOLERANCE);
  AssertEquals('Sqrt(1.0) = 1.0', 1.0, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Min;
var
  a, b, r: TVecF64x4;
begin
  // 测试最小值
  a.d[0] := 5.0;  a.d[1] := 2.0;  a.d[2] := 8.0;  a.d[3] := 1.0;
  b.d[0] := 3.0;  b.d[1] := 7.0;  b.d[2] := 4.0;  b.d[3] := 9.0;
  r := VecF64x4Min(a, b);

  AssertEquals('Min(5.0, 3.0) = 3.0', 3.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Min(2.0, 7.0) = 2.0', 2.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Min(8.0, 4.0) = 4.0', 4.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Min(1.0, 9.0) = 1.0', 1.0, r.d[3], F64_TOLERANCE);

  // 测试负数
  a.d[0] := -5.0; a.d[1] := -2.0; a.d[2] := 3.0;  a.d[3] := -1.0;
  b.d[0] := -3.0; b.d[1] := -7.0; b.d[2] := -4.0; b.d[3] := 0.0;
  r := VecF64x4Min(a, b);

  AssertEquals('Min(-5.0, -3.0) = -5.0', -5.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Min(-2.0, -7.0) = -7.0', -7.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Min(3.0, -4.0) = -4.0', -4.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Min(-1.0, 0.0) = -1.0', -1.0, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Max;
var
  a, b, r: TVecF64x4;
begin
  // 测试最大值
  a.d[0] := 5.0;  a.d[1] := 2.0;  a.d[2] := 8.0;  a.d[3] := 1.0;
  b.d[0] := 3.0;  b.d[1] := 7.0;  b.d[2] := 4.0;  b.d[3] := 9.0;
  r := VecF64x4Max(a, b);

  AssertEquals('Max(5.0, 3.0) = 5.0', 5.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Max(2.0, 7.0) = 7.0', 7.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Max(8.0, 4.0) = 8.0', 8.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Max(1.0, 9.0) = 9.0', 9.0, r.d[3], F64_TOLERANCE);

  // 测试负数
  a.d[0] := -5.0; a.d[1] := -2.0; a.d[2] := 3.0;  a.d[3] := -1.0;
  b.d[0] := -3.0; b.d[1] := -7.0; b.d[2] := -4.0; b.d[3] := 0.0;
  r := VecF64x4Max(a, b);

  AssertEquals('Max(-5.0, -3.0) = -3.0', -3.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Max(-2.0, -7.0) = -2.0', -2.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Max(3.0, -4.0) = 3.0', 3.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Max(-1.0, 0.0) = 0.0', 0.0, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Clamp;
var
  a, minV, maxV, r: TVecF64x4;
begin
  // 测试钳制操作
  a.d[0] := -5.0;   // 低于最小值
  a.d[1] := 5.0;    // 在范围内
  a.d[2] := 15.0;   // 高于最大值
  a.d[3] := 0.0;    // 在范围内（边界）

  minV.d[0] := 0.0; minV.d[1] := 0.0; minV.d[2] := 0.0; minV.d[3] := 0.0;
  maxV.d[0] := 10.0; maxV.d[1] := 10.0; maxV.d[2] := 10.0; maxV.d[3] := 10.0;

  r := ScalarClampF64x4(a, minV, maxV);

  AssertEquals('Clamp(-5.0) to [0,10]', 0.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Clamp(5.0) to [0,10]', 5.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Clamp(15.0) to [0,10]', 10.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Clamp(0.0) to [0,10]', 0.0, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Floor;
var
  a, r: TVecF64x4;
begin
  // Floor: 向负无穷取整
  a.d[0] := 2.7;   // 应为 2.0
  a.d[1] := -2.3;  // 应为 -3.0
  a.d[2] := 3.0;   // 应为 3.0
  a.d[3] := -3.0;  // 应为 -3.0

  r := ScalarFloorF64x4(a);

  AssertEquals('Floor(2.7) = 2.0', 2.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Floor(-2.3) = -3.0', -3.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Floor(3.0) = 3.0', 3.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Floor(-3.0) = -3.0', -3.0, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Ceil;
var
  a, r: TVecF64x4;
begin
  // Ceil: 向正无穷取整
  a.d[0] := 2.3;   // 应为 3.0
  a.d[1] := -2.7;  // 应为 -2.0
  a.d[2] := 3.0;   // 应为 3.0
  a.d[3] := -3.0;  // 应为 -3.0

  r := ScalarCeilF64x4(a);

  AssertEquals('Ceil(2.3) = 3.0', 3.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Ceil(-2.7) = -2.0', -2.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Ceil(3.0) = 3.0', 3.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Ceil(-3.0) = -3.0', -3.0, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Round;
var
  a, r: TVecF64x4;
begin
  // Round: 四舍五入到最近整数
  a.d[0] := 2.4;   // 应为 2.0
  a.d[1] := 2.6;   // 应为 3.0
  a.d[2] := -2.4;  // 应为 -2.0
  a.d[3] := -2.6;  // 应为 -3.0

  r := ScalarRoundF64x4(a);

  AssertEquals('Round(2.4) = 2.0', 2.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Round(2.6) = 3.0', 3.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Round(-2.4) = -2.0', -2.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Round(-2.6) = -3.0', -3.0, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Trunc;
var
  a, r: TVecF64x4;
begin
  // Trunc: 向零取整
  a.d[0] := 2.9;   // 应为 2.0
  a.d[1] := -2.9;  // 应为 -2.0
  a.d[2] := 3.0;   // 应为 3.0
  a.d[3] := -3.0;  // 应为 -3.0

  r := ScalarTruncF64x4(a);

  AssertEquals('Trunc(2.9) = 2.0', 2.0, r.d[0], F64_TOLERANCE);
  AssertEquals('Trunc(-2.9) = -2.0', -2.0, r.d[1], F64_TOLERANCE);
  AssertEquals('Trunc(3.0) = 3.0', 3.0, r.d[2], F64_TOLERANCE);
  AssertEquals('Trunc(-3.0) = -3.0', -3.0, r.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Fma;
var
  a, b, c, r: TVecF64x4;
begin
  // FMA: result = a * b + c
  a.d[0] := 2.0; a.d[1] := 1.5; a.d[2] := 3.0;  a.d[3] := 0.5;
  b.d[0] := 3.0; b.d[1] := 4.0; b.d[2] := 2.0;  b.d[3] := 8.0;
  c.d[0] := 4.0; c.d[1] := 2.0; c.d[2] := 1.0;  c.d[3] := 3.0;

  r := ScalarFmaF64x4(a, b, c);

  AssertEquals('FMA(2.0, 3.0, 4.0) = 10.0', 10.0, r.d[0], F64_TOLERANCE);
  AssertEquals('FMA(1.5, 4.0, 2.0) = 8.0', 8.0, r.d[1], F64_TOLERANCE);
  AssertEquals('FMA(3.0, 2.0, 1.0) = 7.0', 7.0, r.d[2], F64_TOLERANCE);
  AssertEquals('FMA(0.5, 8.0, 3.0) = 7.0', 7.0, r.d[3], F64_TOLERANCE);
end;

// === 比较操作测试 ===

procedure TTestCase_VecF64x4.Test_VecF64x4_CmpEq;
var
  a, b: TVecF64x4;
  mask: TMask4;
begin
  // 测试相等比较
  a.d[0] := 5.0; a.d[1] := 3.0; a.d[2] := 7.0; a.d[3] := 2.0;
  b.d[0] := 5.0; b.d[1] := 4.0; b.d[2] := 7.0; b.d[3] := 3.0;

  mask := VecF64x4CmpEq(a, b);

  AssertTrue('5.0 == 5.0 should be true', (mask and 1) <> 0);
  AssertTrue('3.0 == 4.0 should be false', (mask and 2) = 0);
  AssertTrue('7.0 == 7.0 should be true', (mask and 4) <> 0);
  AssertTrue('2.0 == 3.0 should be false', (mask and 8) = 0);

  a.d[0] := -1.0; a.d[1] := 0.0; a.d[2] := 3.5; a.d[3] := -0.0;
  b.d[0] := -1.0; b.d[1] := 1.0; b.d[2] := 3.0; b.d[3] := 0.0;

  mask := VecF64x4CmpEq(a, b);

  AssertEquals('CmpEq alt mask', 9, Integer(mask));
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_CmpLt;
var
  a, b: TVecF64x4;
  mask: TMask4;
begin
  // 测试小于比较
  a.d[0] := 3.0; a.d[1] := 5.0; a.d[2] := 7.0; a.d[3] := 2.0;
  b.d[0] := 5.0; b.d[1] := 5.0; b.d[2] := 3.0; b.d[3] := 9.0;

  mask := VecF64x4CmpLt(a, b);

  AssertTrue('3.0 < 5.0 should be true', (mask and 1) <> 0);
  AssertTrue('5.0 < 5.0 should be false', (mask and 2) = 0);
  AssertTrue('7.0 < 3.0 should be false', (mask and 4) = 0);
  AssertTrue('2.0 < 9.0 should be true', (mask and 8) <> 0);

  a.d[0] := -2.0; a.d[1] := 4.0; a.d[2] := 0.5; a.d[3] := 9.0;
  b.d[0] := -1.0; b.d[1] := 4.0; b.d[2] := 1.5; b.d[3] := 8.0;

  mask := VecF64x4CmpLt(a, b);

  AssertEquals('CmpLt alt mask', 5, Integer(mask));
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_CmpLe;
var
  a, b: TVecF64x4;
  mask: TMask4;
begin
  // 测试小于等于比较
  a.d[0] := 3.0; a.d[1] := 5.0; a.d[2] := 7.0; a.d[3] := 2.0;
  b.d[0] := 5.0; b.d[1] := 5.0; b.d[2] := 3.0; b.d[3] := 9.0;

  mask := VecF64x4CmpLe(a, b);

  AssertTrue('3.0 <= 5.0 should be true', (mask and 1) <> 0);
  AssertTrue('5.0 <= 5.0 should be true', (mask and 2) <> 0);
  AssertTrue('7.0 <= 3.0 should be false', (mask and 4) = 0);
  AssertTrue('2.0 <= 9.0 should be true', (mask and 8) <> 0);

  a.d[0] := -2.0; a.d[1] := 4.0; a.d[2] := 0.5; a.d[3] := 9.0;
  b.d[0] := -2.0; b.d[1] := 3.0; b.d[2] := 1.5; b.d[3] := 9.0;

  mask := VecF64x4CmpLe(a, b);

  AssertEquals('CmpLe alt mask', 13, Integer(mask));
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_CmpGt;
var
  a, b: TVecF64x4;
  mask: TMask4;
begin
  // 测试大于比较
  a.d[0] := 5.0; a.d[1] := 5.0; a.d[2] := 3.0; a.d[3] := 9.0;
  b.d[0] := 3.0; b.d[1] := 5.0; b.d[2] := 7.0; b.d[3] := 2.0;

  mask := VecF64x4CmpGt(a, b);

  AssertTrue('5.0 > 3.0 should be true', (mask and 1) <> 0);
  AssertTrue('5.0 > 5.0 should be false', (mask and 2) = 0);
  AssertTrue('3.0 > 7.0 should be false', (mask and 4) = 0);
  AssertTrue('9.0 > 2.0 should be true', (mask and 8) <> 0);

  a.d[0] := -1.0; a.d[1] := 5.0; a.d[2] := 2.0; a.d[3] := 8.0;
  b.d[0] := -2.0; b.d[1] := 5.0; b.d[2] := 1.0; b.d[3] := 9.0;

  mask := VecF64x4CmpGt(a, b);

  AssertEquals('CmpGt alt mask', 5, Integer(mask));
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_CmpGe;
var
  a, b: TVecF64x4;
  mask: TMask4;
begin
  // 测试大于等于比较
  a.d[0] := 5.0; a.d[1] := 5.0; a.d[2] := 3.0; a.d[3] := 9.0;
  b.d[0] := 3.0; b.d[1] := 5.0; b.d[2] := 7.0; b.d[3] := 2.0;

  mask := VecF64x4CmpGe(a, b);

  AssertTrue('5.0 >= 3.0 should be true', (mask and 1) <> 0);
  AssertTrue('5.0 >= 5.0 should be true', (mask and 2) <> 0);
  AssertTrue('3.0 >= 7.0 should be false', (mask and 4) = 0);
  AssertTrue('9.0 >= 2.0 should be true', (mask and 8) <> 0);

  a.d[0] := -1.0; a.d[1] := 5.0; a.d[2] := 2.0; a.d[3] := 9.0;
  b.d[0] := -1.0; b.d[1] := 4.0; b.d[2] := 1.0; b.d[3] := 10.0;

  mask := VecF64x4CmpGe(a, b);

  AssertEquals('CmpGe alt mask', 7, Integer(mask));
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_CmpNe;
var
  a, b: TVecF64x4;
  mask: TMask4;
begin
  // 测试不等于比较
  a.d[0] := 5.0; a.d[1] := 3.0; a.d[2] := 7.0; a.d[3] := 2.0;
  b.d[0] := 5.0; b.d[1] := 4.0; b.d[2] := 7.0; b.d[3] := 3.0;

  mask := VecF64x4CmpNe(a, b);

  AssertTrue('5.0 != 5.0 should be false', (mask and 1) = 0);
  AssertTrue('3.0 != 4.0 should be true', (mask and 2) <> 0);
  AssertTrue('7.0 != 7.0 should be false', (mask and 4) = 0);
  AssertTrue('2.0 != 3.0 should be true', (mask and 8) <> 0);

  a.d[0] := -1.0; a.d[1] := 0.0; a.d[2] := 2.0; a.d[3] := 8.0;
  b.d[0] := -1.0; b.d[1] := 1.0; b.d[2] := 3.0; b.d[3] := 8.0;

  mask := VecF64x4CmpNe(a, b);

  AssertEquals('CmpNe alt mask', 6, Integer(mask));
end;

// === 规约操作测试 ===

procedure TTestCase_VecF64x4.Test_VecF64x4_ReduceAdd;
var
  a: TVecF64x4;
  sum: Double;
begin
  // 测试求和规约
  a.d[0] := 1.0; a.d[1] := 2.0; a.d[2] := 3.0; a.d[3] := 4.0;
  sum := VecF64x4ReduceAdd(a);
  AssertEquals('Sum(1,2,3,4) = 10.0', 10.0, sum, F64_TOLERANCE);

  // 测试负数
  a.d[0] := -5.0; a.d[1] := 10.0; a.d[2] := -15.0; a.d[3] := 20.0;
  sum := VecF64x4ReduceAdd(a);
  AssertEquals('Sum(-5,10,-15,20) = 10.0', 10.0, sum, F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_ReduceMin;
var
  a: TVecF64x4;
  minVal: Double;
begin
  // 测试最小值规约
  a.d[0] := 5.0; a.d[1] := 2.0; a.d[2] := 8.0; a.d[3] := 3.0;
  minVal := VecF64x4ReduceMin(a);
  AssertEquals('Min(5,2,8,3) = 2.0', 2.0, minVal, F64_TOLERANCE);

  // 测试负数
  a.d[0] := -5.0; a.d[1] := 10.0; a.d[2] := -15.0; a.d[3] := 20.0;
  minVal := VecF64x4ReduceMin(a);
  AssertEquals('Min(-5,10,-15,20) = -15.0', -15.0, minVal, F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_ReduceMax;
var
  a: TVecF64x4;
  maxVal: Double;
begin
  // 测试最大值规约
  a.d[0] := 5.0; a.d[1] := 2.0; a.d[2] := 8.0; a.d[3] := 3.0;
  maxVal := VecF64x4ReduceMax(a);
  AssertEquals('Max(5,2,8,3) = 8.0', 8.0, maxVal, F64_TOLERANCE);

  // 测试负数
  a.d[0] := -5.0; a.d[1] := 10.0; a.d[2] := -15.0; a.d[3] := 20.0;
  maxVal := VecF64x4ReduceMax(a);
  AssertEquals('Max(-5,10,-15,20) = 20.0', 20.0, maxVal, F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_ReduceMul;
var
  a: TVecF64x4;
  prod: Double;
begin
  // 测试乘积规约
  a.d[0] := 2.0; a.d[1] := 3.0; a.d[2] := 4.0; a.d[3] := 5.0;
  prod := VecF64x4ReduceMul(a);
  AssertEquals('Mul(2,3,4,5) = 120.0', 120.0, prod, F64_TOLERANCE);

  // 测试包含零的乘积
  a.d[0] := 5.0; a.d[1] := 0.0; a.d[2] := 3.0; a.d[3] := 2.0;
  prod := VecF64x4ReduceMul(a);
  AssertEquals('Mul with zero = 0.0', 0.0, prod, F64_TOLERANCE);
end;

// === 工具函数测试 ===

procedure TTestCase_VecF64x4.Test_VecF64x4_Splat;
var
  a: TVecF64x4;
begin
  // 测试 Splat（广播）
  a := ScalarSplatF64x4(42.5);

  AssertEquals('Splat[0] = 42.5', 42.5, a.d[0], F64_TOLERANCE);
  AssertEquals('Splat[1] = 42.5', 42.5, a.d[1], F64_TOLERANCE);
  AssertEquals('Splat[2] = 42.5', 42.5, a.d[2], F64_TOLERANCE);
  AssertEquals('Splat[3] = 42.5', 42.5, a.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_Zero;
var
  a: TVecF64x4;
begin
  // 测试零向量
  a := ScalarZeroF64x4();

  AssertEquals('Zero[0] = 0.0', 0.0, a.d[0], F64_TOLERANCE);
  AssertEquals('Zero[1] = 0.0', 0.0, a.d[1], F64_TOLERANCE);
  AssertEquals('Zero[2] = 0.0', 0.0, a.d[2], F64_TOLERANCE);
  AssertEquals('Zero[3] = 0.0', 0.0, a.d[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_LoadStore;
var
  src, dst: array[0..3] of Double;
  a: TVecF64x4;
begin
  // 测试加载和存储
  src[0] := 1.5; src[1] := 2.5; src[2] := 3.5; src[3] := 4.5;
  dst[0] := 0.0; dst[1] := 0.0; dst[2] := 0.0; dst[3] := 0.0;

  a := ScalarLoadF64x4(@src[0]);
  ScalarStoreF64x4(@dst[0], a);

  AssertEquals('LoadStore[0]', src[0], dst[0], F64_TOLERANCE);
  AssertEquals('LoadStore[1]', src[1], dst[1], F64_TOLERANCE);
  AssertEquals('LoadStore[2]', src[2], dst[2], F64_TOLERANCE);
  AssertEquals('LoadStore[3]', src[3], dst[3], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_PublicUtilityFacade_Basic;
var
  LVecA, LVecB, LExpectedSelect, LSelected, LRcp, LInserted: TVecF64x4;
  LExpectedRcp: TVecF64x4;
  LMask: TVecU64x4;
  LDot: Double;
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
  begin
    LVecA.d[LIndex] := (LIndex + 1) * 2.0;
    LVecB.d[LIndex] := (LIndex - 1.5) * 3.0;
    LMask.u[LIndex] := 0;
  end;
  LMask.u[1] := High(QWord);
  LMask.u[3] := High(QWord);

  LExpectedRcp := ScalarRcpF64x4(LVecA);
  LRcp := VecF64x4Rcp(LVecA);
  for LIndex := 0 to 3 do
    AssertEquals('VecF64x4Rcp lane ' + IntToStr(LIndex),
      LExpectedRcp.d[LIndex], LRcp.d[LIndex], F64_TOLERANCE);

  LDot := VecF64x4Dot(LVecA, LVecB);
  AssertEquals('VecF64x4Dot facade', ScalarDotF64x4(LVecA, LVecB), LDot, F64_TOLERANCE);

  LExpectedSelect := ScalarSelectF64x4(LMask, LVecA, LVecB);
  LSelected := VecF64x4Select(LMask, LVecA, LVecB);
  for LIndex := 0 to 3 do
    AssertEquals('VecF64x4Select lane ' + IntToStr(LIndex),
      LExpectedSelect.d[LIndex], LSelected.d[LIndex], F64_TOLERANCE);

  AssertEquals('VecF64x4Extract lane 2', LVecA.d[2], VecF64x4Extract(LVecA, 2), F64_TOLERANCE);
  LInserted := VecF64x4Insert(LVecA, 777.25, 1);
  AssertEquals('VecF64x4Insert lane 1', 777.25, LInserted.d[1], F64_TOLERANCE);
  AssertEquals('VecF64x4Insert keep lane 2', LVecA.d[2], LInserted.d[2], F64_TOLERANCE);
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_SizeOf;
begin
  // 测试类型大小
  // TVecF64x4 应该是 256 位 = 32 字节 = 4 * 8 字节
  AssertEquals('SizeOf(TVecF64x4) = 32', 32, SizeOf(TVecF64x4));
  AssertEquals('SizeOf(Double) = 8', 8, SizeOf(Double));
end;

procedure TTestCase_VecF64x4.Test_VecF64x4_LoHi;
var
  a: TVecF64x4;
  lo, hi: TVecF64x2;
begin
  // 测试提取高低 128-bit 部分
  a.d[0] := 1.0; a.d[1] := 2.0; a.d[2] := 3.0; a.d[3] := 4.0;

  lo := VecF64x4ExtractLo(a);
  hi := VecF64x4ExtractHi(a);

  // 低 128-bit 包含 d[0] 和 d[1]
  AssertEquals('Lo[0] = 1.0', 1.0, lo.d[0], F64_TOLERANCE);
  AssertEquals('Lo[1] = 2.0', 2.0, lo.d[1], F64_TOLERANCE);

  // 高 128-bit 包含 d[2] 和 d[3]
  AssertEquals('Hi[0] = 3.0', 3.0, hi.d[0], F64_TOLERANCE);
  AssertEquals('Hi[1] = 4.0', 4.0, hi.d[1], F64_TOLERANCE);
end;


initialization
  RegisterTest(TTestCase_VecF64x4);

end.
