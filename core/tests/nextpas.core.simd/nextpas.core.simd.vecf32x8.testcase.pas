unit nextpas.core.simd.vecf32x8.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  Math,
  Classes, SysUtils, nextpas.core.math, fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.scalar,
  nextpas.core.simd.ops;

type
  // ✅ TVecF32x8 (256-bit 单精度浮点向量) 完整测试套件 (2026-02-05)
  TTestCase_VecF32x8 = class(TScalarBackendStatefulTestCase)
  published
    // === 算术操作 ===
    procedure Test_VecF32x8_Add;
    procedure Test_VecF32x8_Sub;
    procedure Test_VecF32x8_Mul;
    procedure Test_VecF32x8_Div;
    procedure Test_VecF32x8_Neg;

    // === 数学函数 ===
    procedure Test_VecF32x8_Abs;
    procedure Test_VecF32x8_Sqrt;
    procedure Test_VecF32x8_Min;
    procedure Test_VecF32x8_Max;
    procedure Test_VecF32x8_Clamp;
    procedure Test_VecF32x8_Floor;
    procedure Test_VecF32x8_Ceil;
    procedure Test_VecF32x8_Round;
    procedure Test_VecF32x8_Trunc;
    procedure Test_VecF32x8_Fma;

    // === 比较操作 ===
    procedure Test_VecF32x8_CmpEq;
    procedure Test_VecF32x8_CmpLt;
    procedure Test_VecF32x8_CmpLe;
    procedure Test_VecF32x8_CmpGt;
    procedure Test_VecF32x8_CmpGe;
    procedure Test_VecF32x8_CmpNe;

    // === 规约操作 ===
    procedure Test_VecF32x8_ReduceAdd;
    procedure Test_VecF32x8_ReduceMin;
    procedure Test_VecF32x8_ReduceMax;
    procedure Test_VecF32x8_ReduceMul;

    // === 工具函数 ===
    procedure Test_VecF32x8_Splat;
    procedure Test_VecF32x8_Zero;
    procedure Test_VecF32x8_LoadStore;
    procedure Test_VecF32x8_PublicUtilityFacade_Basic;
    procedure Test_VecF32x8_SizeOf;
    procedure Test_VecF32x8_LoHi;

    // === 特殊值测试 ===
    procedure Test_VecF32x8_SpecialValues_Inf;
    procedure Test_VecF32x8_SpecialValues_NaN;
    procedure Test_VecF32x8_SpecialValues_Zero;
    procedure Test_VecF32x8_SpecialValues_Denorm;

    // === 边界测试 ===
    procedure Test_VecF32x8_Boundary_MaxMin;
    procedure Test_VecF32x8_Boundary_Precision;
  end;

implementation
{ TTestCase_VecF32x8 }

const
  F32x8_TOLERANCE: Single = 1e-5;
  F32x8_RCP_TOLERANCE: Single = 1e-2;  // Rcp/Rsqrt 使用较大容差

// === 算术操作 ===

procedure TTestCase_VecF32x8.Test_VecF32x8_Add;
var
  a, b, c: TVecF32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.f[i] := i * 1.5;
    b.f[i] := i * 2.0 + 1.0;
  end;

  c := VecF32x8Add(a, b);

  for i := 0 to 7 do
    AssertEquals('F32x8 Add [' + IntToStr(i) + ']', a.f[i] + b.f[i], c.f[i], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Sub;
var
  a, b, c: TVecF32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.f[i] := (i + 1) * 10.0;
    b.f[i] := i * 3.0;
  end;

  c := VecF32x8Sub(a, b);

  for i := 0 to 7 do
    AssertEquals('F32x8 Sub [' + IntToStr(i) + ']', a.f[i] - b.f[i], c.f[i], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Mul;
var
  a, b, c: TVecF32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.f[i] := i * 2.0 + 1.0;
    b.f[i] := i * 0.5 + 0.5;
  end;

  c := VecF32x8Mul(a, b);

  for i := 0 to 7 do
    AssertEquals('F32x8 Mul [' + IntToStr(i) + ']', a.f[i] * b.f[i], c.f[i], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Div;
var
  a, b, c: TVecF32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.f[i] := (i + 1) * 12.0;
    b.f[i] := (i + 1) * 3.0;  // 避免除以零
  end;

  c := VecF32x8Div(a, b);

  for i := 0 to 7 do
    AssertEquals('F32x8 Div [' + IntToStr(i) + ']', a.f[i] / b.f[i], c.f[i], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Neg;
var
  a, c: TVecF32x8;
  i: Integer;
begin
  for i := 0 to 7 do
    a.f[i] := (i - 3) * 2.5;  // 包含正数、负数和零

  c := -a;  // 使用运算符重载

  for i := 0 to 7 do
    AssertEquals('F32x8 Neg [' + IntToStr(i) + ']', -a.f[i], c.f[i], F32x8_TOLERANCE);
end;

// === 数学函数 ===

procedure TTestCase_VecF32x8.Test_VecF32x8_Abs;
var
  a, c: TVecF32x8;
  i: Integer;
begin
  a.f[0] := -5.0;
  a.f[1] := 5.0;
  a.f[2] := -0.0;
  a.f[3] := 0.0;
  a.f[4] := -123.456;
  a.f[5] := 123.456;
  a.f[6] := -0.001;
  a.f[7] := 0.001;

  c := VecF32x8Abs(a);

  for i := 0 to 7 do
    AssertEquals('F32x8 Abs [' + IntToStr(i) + ']', Abs(a.f[i]), c.f[i], F32x8_TOLERANCE);

  a.f[0] := -42.5;
  a.f[1] := 42.5;
  a.f[2] := -9999.0;
  a.f[3] := 9999.0;
  a.f[4] := -1.0 / 8.0;
  a.f[5] := 1.0 / 8.0;
  a.f[6] := -2048.75;
  a.f[7] := 2048.75;

  c := VecF32x8Abs(a);

  for i := 0 to 7 do
    AssertEquals('F32x8 Abs alt [' + IntToStr(i) + ']', Abs(a.f[i]), c.f[i], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Sqrt;
var
  a, c: TVecF32x8;
  i: Integer;
begin
  a.f[0] := 0.0;
  a.f[1] := 1.0;
  a.f[2] := 4.0;
  a.f[3] := 9.0;
  a.f[4] := 16.0;
  a.f[5] := 25.0;
  a.f[6] := 100.0;
  a.f[7] := 2.25;

  c := VecF32x8Sqrt(a);

  AssertEquals('F32x8 Sqrt(0)', 0.0, c.f[0], F32x8_TOLERANCE);
  AssertEquals('F32x8 Sqrt(1)', 1.0, c.f[1], F32x8_TOLERANCE);
  AssertEquals('F32x8 Sqrt(4)', 2.0, c.f[2], F32x8_TOLERANCE);
  AssertEquals('F32x8 Sqrt(9)', 3.0, c.f[3], F32x8_TOLERANCE);
  AssertEquals('F32x8 Sqrt(16)', 4.0, c.f[4], F32x8_TOLERANCE);
  AssertEquals('F32x8 Sqrt(25)', 5.0, c.f[5], F32x8_TOLERANCE);
  AssertEquals('F32x8 Sqrt(100)', 10.0, c.f[6], F32x8_TOLERANCE);
  AssertEquals('F32x8 Sqrt(2.25)', 1.5, c.f[7], F32x8_TOLERANCE);

  a.f[0] := 0.25;
  a.f[1] := 0.5;
  a.f[2] := 6.25;
  a.f[3] := 12.25;
  a.f[4] := 49.0;
  a.f[5] := 81.0;
  a.f[6] := 256.0;
  a.f[7] := 10000.0;

  c := VecF32x8Sqrt(a);

  for i := 0 to 7 do
    AssertEquals('F32x8 Sqrt alt [' + IntToStr(i) + ']', Sqrt(a.f[i]), c.f[i], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Min;
var
  a, b, c: TVecF32x8;
  i: Integer;
begin
  a.f[0] := 1.0;  b.f[0] := 2.0;
  a.f[1] := 5.0;  b.f[1] := 3.0;
  a.f[2] := -1.0; b.f[2] := -2.0;
  a.f[3] := -5.0; b.f[3] := -3.0;
  a.f[4] := 0.0;  b.f[4] := 0.0;
  a.f[5] := 100.0; b.f[5] := 50.0;
  a.f[6] := -100.0; b.f[6] := -50.0;
  a.f[7] := 0.5;  b.f[7] := 0.5;

  c := VecF32x8Min(a, b);

  AssertEquals('F32x8 Min [0]', 1.0, c.f[0], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min [1]', 3.0, c.f[1], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min [2]', -2.0, c.f[2], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min [3]', -5.0, c.f[3], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min [4]', 0.0, c.f[4], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min [5]', 50.0, c.f[5], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min [6]', -100.0, c.f[6], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min [7]', 0.5, c.f[7], F32x8_TOLERANCE);

  a.f[0] := -10.0; b.f[0] := -10.0;
  a.f[1] := 8.0; b.f[1] := 9.0;
  a.f[2] := 7.5; b.f[2] := 7.25;
  a.f[3] := -0.25; b.f[3] := 0.25;
  a.f[4] := 1024.0; b.f[4] := -1024.0;
  a.f[5] := 3.1415; b.f[5] := 3.1416;
  a.f[6] := -8.5; b.f[6] := -8.25;
  a.f[7] := 0.0; b.f[7] := -0.0;

  c := VecF32x8Min(a, b);

  AssertEquals('F32x8 Min alt [0]', -10.0, c.f[0], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min alt [1]', 8.0, c.f[1], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min alt [2]', 7.25, c.f[2], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min alt [3]', -0.25, c.f[3], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min alt [4]', -1024.0, c.f[4], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min alt [5]', 3.1415, c.f[5], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min alt [6]', -8.5, c.f[6], F32x8_TOLERANCE);
  AssertEquals('F32x8 Min alt [7]', 0.0, c.f[7], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Max;
var
  a, b, c: TVecF32x8;
begin
  a.f[0] := 1.0;  b.f[0] := 2.0;
  a.f[1] := 5.0;  b.f[1] := 3.0;
  a.f[2] := -1.0; b.f[2] := -2.0;
  a.f[3] := -5.0; b.f[3] := -3.0;
  a.f[4] := 0.0;  b.f[4] := 0.0;
  a.f[5] := 100.0; b.f[5] := 50.0;
  a.f[6] := -100.0; b.f[6] := -50.0;
  a.f[7] := 0.5;  b.f[7] := 0.5;

  c := VecF32x8Max(a, b);

  AssertEquals('F32x8 Max [0]', 2.0, c.f[0], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max [1]', 5.0, c.f[1], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max [2]', -1.0, c.f[2], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max [3]', -3.0, c.f[3], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max [4]', 0.0, c.f[4], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max [5]', 100.0, c.f[5], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max [6]', -50.0, c.f[6], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max [7]', 0.5, c.f[7], F32x8_TOLERANCE);

  a.f[0] := -10.0; b.f[0] := -10.0;
  a.f[1] := 8.0; b.f[1] := 9.0;
  a.f[2] := 7.5; b.f[2] := 7.25;
  a.f[3] := -0.25; b.f[3] := 0.25;
  a.f[4] := 1024.0; b.f[4] := -1024.0;
  a.f[5] := 3.1415; b.f[5] := 3.1416;
  a.f[6] := -8.5; b.f[6] := -8.25;
  a.f[7] := 0.0; b.f[7] := -0.0;

  c := VecF32x8Max(a, b);

  AssertEquals('F32x8 Max alt [0]', -10.0, c.f[0], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max alt [1]', 9.0, c.f[1], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max alt [2]', 7.5, c.f[2], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max alt [3]', 0.25, c.f[3], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max alt [4]', 1024.0, c.f[4], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max alt [5]', 3.1416, c.f[5], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max alt [6]', -8.25, c.f[6], F32x8_TOLERANCE);
  AssertEquals('F32x8 Max alt [7]', 0.0, c.f[7], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Clamp;
var
  a, minV, maxV, c: TVecF32x8;
  dt: PSimdDispatchTable;
begin
  dt := GetDispatchTable;
  AssertTrue('Dispatch table should not be nil', dt <> nil);
  AssertTrue('Dispatch.ClampF32x8 should be assigned', Assigned(dt^.ClampF32x8));

  a.f[0] := -10.0;  // 低于下界
  a.f[1] := 0.0;    // 等于下界
  a.f[2] := 5.0;    // 在范围内
  a.f[3] := 10.0;   // 等于上界
  a.f[4] := 20.0;   // 高于上界
  a.f[5] := -0.001;
  a.f[6] := 10.001;
  a.f[7] := 5.5;

  minV := ScalarSplatF32x8(0.0);
  maxV := ScalarSplatF32x8(10.0);

  c := dt^.ClampF32x8(a, minV, maxV);

  AssertEquals('F32x8 Clamp [-10] -> 0', 0.0, c.f[0], F32x8_TOLERANCE);
  AssertEquals('F32x8 Clamp [0] -> 0', 0.0, c.f[1], F32x8_TOLERANCE);
  AssertEquals('F32x8 Clamp [5] -> 5', 5.0, c.f[2], F32x8_TOLERANCE);
  AssertEquals('F32x8 Clamp [10] -> 10', 10.0, c.f[3], F32x8_TOLERANCE);
  AssertEquals('F32x8 Clamp [20] -> 10', 10.0, c.f[4], F32x8_TOLERANCE);
  AssertEquals('F32x8 Clamp [-0.001] -> 0', 0.0, c.f[5], F32x8_TOLERANCE);
  AssertEquals('F32x8 Clamp [10.001] -> 10', 10.0, c.f[6], F32x8_TOLERANCE);
  AssertEquals('F32x8 Clamp [5.5] -> 5.5', 5.5, c.f[7], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Floor;
var
  a, c: TVecF32x8;
  dt: PSimdDispatchTable;
begin
  dt := GetDispatchTable;
  AssertTrue('Dispatch table should not be nil', dt <> nil);
  AssertTrue('Dispatch.FloorF32x8 should be assigned', Assigned(dt^.FloorF32x8));

  a.f[0] := 2.7;
  a.f[1] := 2.3;
  a.f[2] := -2.3;
  a.f[3] := -2.7;
  a.f[4] := 0.0;
  a.f[5] := 3.0;
  a.f[6] := -3.0;
  a.f[7] := 0.999;

  c := dt^.FloorF32x8(a);

  AssertEquals('F32x8 Floor(2.7)', 2.0, c.f[0], F32x8_TOLERANCE);
  AssertEquals('F32x8 Floor(2.3)', 2.0, c.f[1], F32x8_TOLERANCE);
  AssertEquals('F32x8 Floor(-2.3)', -3.0, c.f[2], F32x8_TOLERANCE);
  AssertEquals('F32x8 Floor(-2.7)', -3.0, c.f[3], F32x8_TOLERANCE);
  AssertEquals('F32x8 Floor(0)', 0.0, c.f[4], F32x8_TOLERANCE);
  AssertEquals('F32x8 Floor(3)', 3.0, c.f[5], F32x8_TOLERANCE);
  AssertEquals('F32x8 Floor(-3)', -3.0, c.f[6], F32x8_TOLERANCE);
  AssertEquals('F32x8 Floor(0.999)', 0.0, c.f[7], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Ceil;
var
  a, c: TVecF32x8;
  dt: PSimdDispatchTable;
begin
  dt := GetDispatchTable;
  AssertTrue('Dispatch table should not be nil', dt <> nil);
  AssertTrue('Dispatch.CeilF32x8 should be assigned', Assigned(dt^.CeilF32x8));

  a.f[0] := 2.1;
  a.f[1] := 2.9;
  a.f[2] := -2.1;
  a.f[3] := -2.9;
  a.f[4] := 0.0;
  a.f[5] := 3.0;
  a.f[6] := -3.0;
  a.f[7] := -0.001;

  c := dt^.CeilF32x8(a);

  AssertEquals('F32x8 Ceil(2.1)', 3.0, c.f[0], F32x8_TOLERANCE);
  AssertEquals('F32x8 Ceil(2.9)', 3.0, c.f[1], F32x8_TOLERANCE);
  AssertEquals('F32x8 Ceil(-2.1)', -2.0, c.f[2], F32x8_TOLERANCE);
  AssertEquals('F32x8 Ceil(-2.9)', -2.0, c.f[3], F32x8_TOLERANCE);
  AssertEquals('F32x8 Ceil(0)', 0.0, c.f[4], F32x8_TOLERANCE);
  AssertEquals('F32x8 Ceil(3)', 3.0, c.f[5], F32x8_TOLERANCE);
  AssertEquals('F32x8 Ceil(-3)', -3.0, c.f[6], F32x8_TOLERANCE);
  AssertEquals('F32x8 Ceil(-0.001)', 0.0, c.f[7], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Round;
var
  a, c: TVecF32x8;
  dt: PSimdDispatchTable;
begin
  dt := GetDispatchTable;
  AssertTrue('Dispatch table should not be nil', dt <> nil);
  AssertTrue('Dispatch.RoundF32x8 should be assigned', Assigned(dt^.RoundF32x8));

  a.f[0] := 2.4;
  a.f[1] := 2.6;
  a.f[2] := -2.4;
  a.f[3] := -2.6;
  a.f[4] := 2.5;   // 银行家舍入或四舍五入
  a.f[5] := 3.5;
  a.f[6] := -2.5;
  a.f[7] := -3.5;

  c := dt^.RoundF32x8(a);

  AssertEquals('F32x8 Round(2.4)', 2.0, c.f[0], F32x8_TOLERANCE);
  AssertEquals('F32x8 Round(2.6)', 3.0, c.f[1], F32x8_TOLERANCE);
  AssertEquals('F32x8 Round(-2.4)', -2.0, c.f[2], F32x8_TOLERANCE);
  AssertEquals('F32x8 Round(-2.6)', -3.0, c.f[3], F32x8_TOLERANCE);
  // 0.5 的舍入行为依赖于实现（银行家舍入或四舍五入）
  // 只检查结果是否为整数
  AssertTrue('F32x8 Round(2.5) should be integer', Abs(c.f[4] - Round(c.f[4])) < F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Trunc;
var
  a, c: TVecF32x8;
  dt: PSimdDispatchTable;
begin
  dt := GetDispatchTable;
  AssertTrue('Dispatch table should not be nil', dt <> nil);
  AssertTrue('Dispatch.TruncF32x8 should be assigned', Assigned(dt^.TruncF32x8));

  a.f[0] := 2.9;
  a.f[1] := 2.1;
  a.f[2] := -2.9;
  a.f[3] := -2.1;
  a.f[4] := 0.0;
  a.f[5] := 5.0;
  a.f[6] := -5.0;
  a.f[7] := 99.99;

  c := dt^.TruncF32x8(a);

  AssertEquals('F32x8 Trunc(2.9)', 2.0, c.f[0], F32x8_TOLERANCE);
  AssertEquals('F32x8 Trunc(2.1)', 2.0, c.f[1], F32x8_TOLERANCE);
  AssertEquals('F32x8 Trunc(-2.9)', -2.0, c.f[2], F32x8_TOLERANCE);
  AssertEquals('F32x8 Trunc(-2.1)', -2.0, c.f[3], F32x8_TOLERANCE);
  AssertEquals('F32x8 Trunc(0)', 0.0, c.f[4], F32x8_TOLERANCE);
  AssertEquals('F32x8 Trunc(5)', 5.0, c.f[5], F32x8_TOLERANCE);
  AssertEquals('F32x8 Trunc(-5)', -5.0, c.f[6], F32x8_TOLERANCE);
  AssertEquals('F32x8 Trunc(99.99)', 99.0, c.f[7], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Fma;
var
  a, b, c, r: TVecF32x8;
  dt: PSimdDispatchTable;
  i: Integer;
begin
  dt := GetDispatchTable;
  AssertTrue('Dispatch table should not be nil', dt <> nil);
  AssertTrue('Dispatch.FmaF32x8 should be assigned', Assigned(dt^.FmaF32x8));

  // FMA: a * b + c
  for i := 0 to 7 do
  begin
    a.f[i] := i + 1.0;      // 1, 2, 3, 4, 5, 6, 7, 8
    b.f[i] := 2.0;          // 2, 2, 2, 2, 2, 2, 2, 2
    c.f[i] := i * 0.5;      // 0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5
  end;

  r := dt^.FmaF32x8(a, b, c);

  for i := 0 to 7 do
    AssertEquals('F32x8 FMA [' + IntToStr(i) + ']', a.f[i] * b.f[i] + c.f[i], r.f[i], F32x8_TOLERANCE);
end;

// === 比较操作 ===

procedure TTestCase_VecF32x8.Test_VecF32x8_CmpEq;
var
  a, b: TVecF32x8;
  mask: TMask8;
begin
  a.f[0] := 1.0; b.f[0] := 1.0;     // 相等
  a.f[1] := 2.0; b.f[1] := 3.0;     // 不等
  a.f[2] := 0.0; b.f[2] := 0.0;     // 零相等
  a.f[3] := -1.0; b.f[3] := -1.0;   // 负数相等
  a.f[4] := 5.0; b.f[4] := 5.001;   // 略有不同
  a.f[5] := -0.0; b.f[5] := 0.0;    // -0 和 +0
  a.f[6] := 100.0; b.f[6] := 100.0;
  a.f[7] := -100.0; b.f[7] := 100.0;

  mask := VecF32x8CmpEq(a, b);

  AssertTrue('F32x8 CmpEq [0]: 1 == 1', (mask and (1 shl 0)) <> 0);
  AssertFalse('F32x8 CmpEq [1]: 2 != 3', (mask and (1 shl 1)) <> 0);
  AssertTrue('F32x8 CmpEq [2]: 0 == 0', (mask and (1 shl 2)) <> 0);
  AssertTrue('F32x8 CmpEq [3]: -1 == -1', (mask and (1 shl 3)) <> 0);
  AssertFalse('F32x8 CmpEq [4]: 5 != 5.001', (mask and (1 shl 4)) <> 0);
  // IEEE 754: -0 == +0
  AssertTrue('F32x8 CmpEq [5]: -0 == +0', (mask and (1 shl 5)) <> 0);
  AssertTrue('F32x8 CmpEq [6]: 100 == 100', (mask and (1 shl 6)) <> 0);
  AssertFalse('F32x8 CmpEq [7]: -100 != 100', (mask and (1 shl 7)) <> 0);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_CmpLt;
var
  a, b: TVecF32x8;
  mask: TMask8;
begin
  a.f[0] := 1.0; b.f[0] := 2.0;     // 1 < 2
  a.f[1] := 3.0; b.f[1] := 2.0;     // 3 > 2
  a.f[2] := 2.0; b.f[2] := 2.0;     // 相等
  a.f[3] := -5.0; b.f[3] := -3.0;   // -5 < -3
  a.f[4] := -3.0; b.f[4] := -5.0;   // -3 > -5
  a.f[5] := 0.0; b.f[5] := 0.001;
  a.f[6] := -0.001; b.f[6] := 0.0;
  a.f[7] := 0.0; b.f[7] := 0.0;

  mask := VecF32x8CmpLt(a, b);

  AssertTrue('F32x8 CmpLt [0]: 1 < 2', (mask and (1 shl 0)) <> 0);
  AssertFalse('F32x8 CmpLt [1]: 3 >= 2', (mask and (1 shl 1)) <> 0);
  AssertFalse('F32x8 CmpLt [2]: 2 >= 2', (mask and (1 shl 2)) <> 0);
  AssertTrue('F32x8 CmpLt [3]: -5 < -3', (mask and (1 shl 3)) <> 0);
  AssertFalse('F32x8 CmpLt [4]: -3 >= -5', (mask and (1 shl 4)) <> 0);
  AssertTrue('F32x8 CmpLt [5]: 0 < 0.001', (mask and (1 shl 5)) <> 0);
  AssertTrue('F32x8 CmpLt [6]: -0.001 < 0', (mask and (1 shl 6)) <> 0);
  AssertFalse('F32x8 CmpLt [7]: 0 >= 0', (mask and (1 shl 7)) <> 0);

  a.f[0] := -10.0; b.f[0] := -9.0;
  a.f[1] := 10.0; b.f[1] := 9.0;
  a.f[2] := 1.0; b.f[2] := 2.0;
  a.f[3] := -1.0; b.f[3] := -1.0;
  a.f[4] := 0.25; b.f[4] := 0.5;
  a.f[5] := -0.25; b.f[5] := -0.5;
  a.f[6] := 100.0; b.f[6] := 100.0;
  a.f[7] := -100.0; b.f[7] := -101.0;

  mask := VecF32x8CmpLt(a, b);

  AssertEquals('F32x8 CmpLt alt mask', 21, Integer(mask));
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_CmpLe;
var
  a, b: TVecF32x8;
  mask: TMask8;
begin
  a.f[0] := 1.0; b.f[0] := 2.0;     // 1 <= 2
  a.f[1] := 3.0; b.f[1] := 2.0;     // 3 > 2
  a.f[2] := 2.0; b.f[2] := 2.0;     // 2 <= 2
  a.f[3] := -5.0; b.f[3] := -3.0;
  a.f[4] := -3.0; b.f[4] := -5.0;
  a.f[5] := 0.0; b.f[5] := 0.0;
  a.f[6] := -1.0; b.f[6] := -1.0;
  a.f[7] := 100.0; b.f[7] := 99.0;

  mask := VecF32x8CmpLe(a, b);

  AssertTrue('F32x8 CmpLe [0]: 1 <= 2', (mask and (1 shl 0)) <> 0);
  AssertFalse('F32x8 CmpLe [1]: 3 > 2', (mask and (1 shl 1)) <> 0);
  AssertTrue('F32x8 CmpLe [2]: 2 <= 2', (mask and (1 shl 2)) <> 0);
  AssertTrue('F32x8 CmpLe [3]: -5 <= -3', (mask and (1 shl 3)) <> 0);
  AssertFalse('F32x8 CmpLe [4]: -3 > -5', (mask and (1 shl 4)) <> 0);
  AssertTrue('F32x8 CmpLe [5]: 0 <= 0', (mask and (1 shl 5)) <> 0);
  AssertTrue('F32x8 CmpLe [6]: -1 <= -1', (mask and (1 shl 6)) <> 0);
  AssertFalse('F32x8 CmpLe [7]: 100 > 99', (mask and (1 shl 7)) <> 0);

  a.f[0] := -10.0; b.f[0] := -10.0;
  a.f[1] := 10.0; b.f[1] := 9.0;
  a.f[2] := 1.0; b.f[2] := 2.0;
  a.f[3] := -1.0; b.f[3] := -1.0;
  a.f[4] := 0.25; b.f[4] := 0.25;
  a.f[5] := -0.25; b.f[5] := -0.5;
  a.f[6] := 100.0; b.f[6] := 100.0;
  a.f[7] := -100.0; b.f[7] := -101.0;

  mask := VecF32x8CmpLe(a, b);

  AssertEquals('F32x8 CmpLe alt mask', 93, Integer(mask));
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_CmpGt;
var
  a, b: TVecF32x8;
  mask: TMask8;
begin
  a.f[0] := 2.0; b.f[0] := 1.0;     // 2 > 1
  a.f[1] := 2.0; b.f[1] := 3.0;     // 2 < 3
  a.f[2] := 2.0; b.f[2] := 2.0;     // 相等
  a.f[3] := -3.0; b.f[3] := -5.0;   // -3 > -5
  a.f[4] := -5.0; b.f[4] := -3.0;   // -5 < -3
  a.f[5] := 0.001; b.f[5] := 0.0;
  a.f[6] := 0.0; b.f[6] := -0.001;
  a.f[7] := 0.0; b.f[7] := 0.0;

  mask := VecF32x8CmpGt(a, b);

  AssertTrue('F32x8 CmpGt [0]: 2 > 1', (mask and (1 shl 0)) <> 0);
  AssertFalse('F32x8 CmpGt [1]: 2 <= 3', (mask and (1 shl 1)) <> 0);
  AssertFalse('F32x8 CmpGt [2]: 2 <= 2', (mask and (1 shl 2)) <> 0);
  AssertTrue('F32x8 CmpGt [3]: -3 > -5', (mask and (1 shl 3)) <> 0);
  AssertFalse('F32x8 CmpGt [4]: -5 <= -3', (mask and (1 shl 4)) <> 0);
  AssertTrue('F32x8 CmpGt [5]: 0.001 > 0', (mask and (1 shl 5)) <> 0);
  AssertTrue('F32x8 CmpGt [6]: 0 > -0.001', (mask and (1 shl 6)) <> 0);
  AssertFalse('F32x8 CmpGt [7]: 0 <= 0', (mask and (1 shl 7)) <> 0);

  a.f[0] := -9.0; b.f[0] := -10.0;
  a.f[1] := 10.0; b.f[1] := 10.0;
  a.f[2] := 3.0; b.f[2] := 2.0;
  a.f[3] := -1.0; b.f[3] := 0.0;
  a.f[4] := 0.75; b.f[4] := 0.5;
  a.f[5] := -0.25; b.f[5] := -0.5;
  a.f[6] := 101.0; b.f[6] := 100.0;
  a.f[7] := -100.0; b.f[7] := -100.0;

  mask := VecF32x8CmpGt(a, b);

  AssertEquals('F32x8 CmpGt alt mask', 117, Integer(mask));
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_CmpGe;
var
  a, b: TVecF32x8;
  mask: TMask8;
begin
  a.f[0] := 2.0; b.f[0] := 1.0;     // 2 >= 1
  a.f[1] := 2.0; b.f[1] := 3.0;     // 2 < 3
  a.f[2] := 2.0; b.f[2] := 2.0;     // 2 >= 2
  a.f[3] := -3.0; b.f[3] := -5.0;
  a.f[4] := -5.0; b.f[4] := -3.0;
  a.f[5] := 0.0; b.f[5] := 0.0;
  a.f[6] := 1.0; b.f[6] := 1.0;
  a.f[7] := 99.0; b.f[7] := 100.0;

  mask := VecF32x8CmpGe(a, b);

  AssertTrue('F32x8 CmpGe [0]: 2 >= 1', (mask and (1 shl 0)) <> 0);
  AssertFalse('F32x8 CmpGe [1]: 2 < 3', (mask and (1 shl 1)) <> 0);
  AssertTrue('F32x8 CmpGe [2]: 2 >= 2', (mask and (1 shl 2)) <> 0);
  AssertTrue('F32x8 CmpGe [3]: -3 >= -5', (mask and (1 shl 3)) <> 0);
  AssertFalse('F32x8 CmpGe [4]: -5 < -3', (mask and (1 shl 4)) <> 0);
  AssertTrue('F32x8 CmpGe [5]: 0 >= 0', (mask and (1 shl 5)) <> 0);
  AssertTrue('F32x8 CmpGe [6]: 1 >= 1', (mask and (1 shl 6)) <> 0);
  AssertFalse('F32x8 CmpGe [7]: 99 < 100', (mask and (1 shl 7)) <> 0);

  a.f[0] := -10.0; b.f[0] := -10.0;
  a.f[1] := 10.0; b.f[1] := 9.0;
  a.f[2] := 3.0; b.f[2] := 2.0;
  a.f[3] := -1.0; b.f[3] := 0.0;
  a.f[4] := 0.5; b.f[4] := 0.5;
  a.f[5] := -0.5; b.f[5] := -0.25;
  a.f[6] := 100.0; b.f[6] := 100.0;
  a.f[7] := -99.0; b.f[7] := -100.0;

  mask := VecF32x8CmpGe(a, b);

  AssertEquals('F32x8 CmpGe alt mask', 215, Integer(mask));
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_CmpNe;
var
  a, b: TVecF32x8;
  mask: TMask8;
begin
  a.f[0] := 1.0; b.f[0] := 2.0;     // 1 != 2
  a.f[1] := 2.0; b.f[1] := 2.0;     // 相等
  a.f[2] := 0.0; b.f[2] := 0.0;     // 相等
  a.f[3] := -1.0; b.f[3] := 1.0;    // 不等
  a.f[4] := 0.0; b.f[4] := -0.0;    // IEEE: +0 == -0
  a.f[5] := 100.0; b.f[5] := 100.001;
  a.f[6] := -50.0; b.f[6] := -50.0;
  a.f[7] := 1.0; b.f[7] := -1.0;

  mask := VecF32x8CmpNe(a, b);

  AssertTrue('F32x8 CmpNe [0]: 1 != 2', (mask and (1 shl 0)) <> 0);
  AssertFalse('F32x8 CmpNe [1]: 2 == 2', (mask and (1 shl 1)) <> 0);
  AssertFalse('F32x8 CmpNe [2]: 0 == 0', (mask and (1 shl 2)) <> 0);
  AssertTrue('F32x8 CmpNe [3]: -1 != 1', (mask and (1 shl 3)) <> 0);
  AssertFalse('F32x8 CmpNe [4]: +0 == -0', (mask and (1 shl 4)) <> 0);
  AssertTrue('F32x8 CmpNe [5]: 100 != 100.001', (mask and (1 shl 5)) <> 0);
  AssertFalse('F32x8 CmpNe [6]: -50 == -50', (mask and (1 shl 6)) <> 0);
  AssertTrue('F32x8 CmpNe [7]: 1 != -1', (mask and (1 shl 7)) <> 0);

  a.f[0] := -10.0; b.f[0] := -10.0;
  a.f[1] := 10.0; b.f[1] := 9.0;
  a.f[2] := 3.0; b.f[2] := 2.0;
  a.f[3] := -1.0; b.f[3] := -1.0;
  a.f[4] := 0.0; b.f[4] := -0.0;
  a.f[5] := -0.5; b.f[5] := -0.5;
  a.f[6] := 100.0; b.f[6] := 101.0;
  a.f[7] := -99.0; b.f[7] := -99.0;

  mask := VecF32x8CmpNe(a, b);

  AssertEquals('F32x8 CmpNe alt mask', 70, Integer(mask));
end;

// === 规约操作 ===

procedure TTestCase_VecF32x8.Test_VecF32x8_ReduceAdd;
var
  a: TVecF32x8;
  sum: Single;
begin
  // 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 = 36
  a.f[0] := 1.0;
  a.f[1] := 2.0;
  a.f[2] := 3.0;
  a.f[3] := 4.0;
  a.f[4] := 5.0;
  a.f[5] := 6.0;
  a.f[6] := 7.0;
  a.f[7] := 8.0;

  sum := VecF32x8ReduceAdd(a);

  AssertEquals('F32x8 ReduceAdd', 36.0, sum, F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_ReduceMin;
var
  a: TVecF32x8;
  minVal: Single;
begin
  a.f[0] := 5.0;
  a.f[1] := -2.0;
  a.f[2] := 8.0;
  a.f[3] := 3.0;
  a.f[4] := -10.0;  // 最小值
  a.f[5] := 6.0;
  a.f[6] := 1.0;
  a.f[7] := 0.0;

  minVal := VecF32x8ReduceMin(a);

  AssertEquals('F32x8 ReduceMin', -10.0, minVal, F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_ReduceMax;
var
  a: TVecF32x8;
  maxVal: Single;
begin
  a.f[0] := 5.0;
  a.f[1] := -2.0;
  a.f[2] := 100.0;  // 最大值
  a.f[3] := 3.0;
  a.f[4] := -10.0;
  a.f[5] := 6.0;
  a.f[6] := 1.0;
  a.f[7] := 0.0;

  maxVal := VecF32x8ReduceMax(a);

  AssertEquals('F32x8 ReduceMax', 100.0, maxVal, F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_ReduceMul;
var
  a: TVecF32x8;
  prod: Single;
begin
  // 1 * 2 * 1 * 2 * 1 * 2 * 1 * 2 = 16
  a.f[0] := 1.0;
  a.f[1] := 2.0;
  a.f[2] := 1.0;
  a.f[3] := 2.0;
  a.f[4] := 1.0;
  a.f[5] := 2.0;
  a.f[6] := 1.0;
  a.f[7] := 2.0;

  prod := VecF32x8ReduceMul(a);

  AssertEquals('F32x8 ReduceMul', 16.0, prod, F32x8_TOLERANCE);
end;

// === 工具函数 ===

procedure TTestCase_VecF32x8.Test_VecF32x8_Splat;
var
  a: TVecF32x8;
  dt: PSimdDispatchTable;
  i: Integer;
begin
  dt := GetDispatchTable;
  AssertTrue('Dispatch table should not be nil', dt <> nil);
  AssertTrue('Dispatch.SplatF32x8 should be assigned', Assigned(dt^.SplatF32x8));

  a := dt^.SplatF32x8(42.5);

  for i := 0 to 7 do
    AssertEquals('F32x8 Splat [' + IntToStr(i) + ']', 42.5, a.f[i], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Zero;
var
  a: TVecF32x8;
  dt: PSimdDispatchTable;
  i: Integer;
begin
  dt := GetDispatchTable;
  AssertTrue('Dispatch table should not be nil', dt <> nil);
  AssertTrue('Dispatch.ZeroF32x8 should be assigned', Assigned(dt^.ZeroF32x8));

  a := dt^.ZeroF32x8();

  for i := 0 to 7 do
    AssertEquals('F32x8 Zero [' + IntToStr(i) + ']', 0.0, a.f[i], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_LoadStore;
var
  src, dst: array[0..7] of Single;
  a: TVecF32x8;
  dt: PSimdDispatchTable;
  i: Integer;
begin
  dt := GetDispatchTable;
  AssertTrue('Dispatch table should not be nil', dt <> nil);
  AssertTrue('Dispatch.LoadF32x8 should be assigned', Assigned(dt^.LoadF32x8));
  AssertTrue('Dispatch.StoreF32x8 should be assigned', Assigned(dt^.StoreF32x8));

  // 初始化源数据
  for i := 0 to 7 do
    src[i] := (i + 1) * 1.5;

  // Load
  a := dt^.LoadF32x8(@src[0]);

  // 验证 Load 结果
  for i := 0 to 7 do
    AssertEquals('F32x8 Load [' + IntToStr(i) + ']', src[i], a.f[i], F32x8_TOLERANCE);

  // Store
  dt^.StoreF32x8(@dst[0], a);

  // 验证 Store 结果
  for i := 0 to 7 do
    AssertEquals('F32x8 Store [' + IntToStr(i) + ']', src[i], dst[i], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_PublicUtilityFacade_Basic;
var
  LVecA, LVecB, LExpectedSelect, LSelected, LInserted: TVecF32x8;
  LMask: TVecU32x8;
  LDot: Single;
  LIndex: Integer;
begin
  for LIndex := 0 to 7 do
  begin
    LVecA.f[LIndex] := (LIndex + 1) * 1.25;
    LVecB.f[LIndex] := (8 - LIndex) * 0.5;
    LMask.u[LIndex] := 0;
  end;
  LMask.u[1] := High(DWord);
  LMask.u[3] := High(DWord);
  LMask.u[5] := High(DWord);
  LMask.u[7] := High(DWord);

  LDot := VecF32x8Dot(LVecA, LVecB);
  AssertEquals('VecF32x8Dot facade', ScalarDotF32x8(LVecA, LVecB), LDot, F32x8_TOLERANCE);

  LExpectedSelect := ScalarSelectF32x8(LMask, LVecA, LVecB);
  LSelected := VecF32x8Select(LMask, LVecA, LVecB);
  for LIndex := 0 to 7 do
    AssertEquals('VecF32x8Select lane ' + IntToStr(LIndex),
      LExpectedSelect.f[LIndex], LSelected.f[LIndex], F32x8_TOLERANCE);

  AssertEquals('VecF32x8Extract lane 3', LVecA.f[3], VecF32x8Extract(LVecA, 3), F32x8_TOLERANCE);
  LInserted := VecF32x8Insert(LVecA, 123.5, 4);
  AssertEquals('VecF32x8Insert lane 4', 123.5, LInserted.f[4], F32x8_TOLERANCE);
  AssertEquals('VecF32x8Insert keep lane 3', LVecA.f[3], LInserted.f[3], F32x8_TOLERANCE);
end;


procedure TTestCase_VecF32x8.Test_VecF32x8_SizeOf;
begin
  AssertEquals('TVecF32x8 should be 32 bytes', 32, SizeOf(TVecF32x8));
  AssertEquals('f32x8 alias should match TVecF32x8', SizeOf(TVecF32x8), SizeOf(f32x8));
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_LoHi;
var
  a: TVecF32x8;
  lo, hi: TVecF32x4;
  i: Integer;
begin
  // 初始化
  for i := 0 to 7 do
    a.f[i] := (i + 1) * 10.0;

  // 访问 lo/hi
  lo := a.lo;
  hi := a.hi;

  // 验证 lo (前 4 个元素)
  for i := 0 to 3 do
    AssertEquals('F32x8 Lo [' + IntToStr(i) + ']', (i + 1) * 10.0, lo.f[i], F32x8_TOLERANCE);

  // 验证 hi (后 4 个元素)
  for i := 0 to 3 do
    AssertEquals('F32x8 Hi [' + IntToStr(i) + ']', (i + 5) * 10.0, hi.f[i], F32x8_TOLERANCE);
end;

// === 特殊值测试 ===

procedure TTestCase_VecF32x8.Test_VecF32x8_SpecialValues_Inf;
var
  a, b, c: TVecF32x8;
  posInf, negInf: Single;
  oldMask: TFPUExceptionMask;
begin
  // 保存并禁用 FPU 异常
  oldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    posInf := 1.0 / 0.0;  // +Infinity
    negInf := -1.0 / 0.0; // -Infinity

    // 初始化带无穷的向量
    a.f[0] := posInf;
    a.f[1] := negInf;
    a.f[2] := 1.0;
    a.f[3] := -1.0;
    a.f[4] := posInf;
    a.f[5] := negInf;
    a.f[6] := 0.0;
    a.f[7] := posInf;

    b.f[0] := 1.0;
    b.f[1] := 1.0;
    b.f[2] := posInf;
    b.f[3] := negInf;
    b.f[4] := posInf;
    b.f[5] := negInf;
    b.f[6] := posInf;
    b.f[7] := negInf;

    // 测试 Inf + x = Inf
    c := VecF32x8Add(a, b);
    AssertTrue('Inf + 1 = Inf', IsInfinite(c.f[0]) and (c.f[0] > 0));
    AssertTrue('-Inf + 1 = -Inf', IsInfinite(c.f[1]) and (c.f[1] < 0));
    AssertTrue('1 + Inf = Inf', IsInfinite(c.f[2]) and (c.f[2] > 0));
    AssertTrue('-1 + -Inf = -Inf', IsInfinite(c.f[3]) and (c.f[3] < 0));

    // 测试 Inf * x
    c := VecF32x8Mul(a, b);
    AssertTrue('Inf * 1 = Inf', IsInfinite(c.f[0]) and (c.f[0] > 0));
    AssertTrue('-Inf * 1 = -Inf', IsInfinite(c.f[1]) and (c.f[1] < 0));
  finally
    // 恢复 FPU 异常掩码
    SetExceptionMask(oldMask);
  end;
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_SpecialValues_NaN;
var
  a, b, c: TVecF32x8;
  nan: Single;
  i: Integer;
begin
  nan := 0.0 / 0.0;  // NaN

  // 初始化带 NaN 的向量
  for i := 0 to 7 do
  begin
    if i mod 2 = 0 then
      a.f[i] := nan
    else
      a.f[i] := i * 1.0;
    b.f[i] := 1.0;
  end;

  // NaN + x = NaN
  c := VecF32x8Add(a, b);
  for i := 0 to 7 do
  begin
    if i mod 2 = 0 then
      AssertTrue('NaN + 1 = NaN [' + IntToStr(i) + ']', IsNan(c.f[i]))
    else
      AssertEquals('Normal add [' + IntToStr(i) + ']', a.f[i] + b.f[i], c.f[i], F32x8_TOLERANCE);
  end;
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_SpecialValues_Zero;
var
  a, b, c: TVecF32x8;
  posZero, negZero: Single;
  mask: TMask8;
begin
  posZero := 0.0;
  negZero := -0.0;

  a.f[0] := posZero;
  a.f[1] := negZero;
  a.f[2] := posZero;
  a.f[3] := negZero;
  a.f[4] := 1.0;
  a.f[5] := -1.0;
  a.f[6] := posZero;
  a.f[7] := negZero;

  b.f[0] := posZero;
  b.f[1] := posZero;
  b.f[2] := negZero;
  b.f[3] := negZero;
  b.f[4] := 0.0;
  b.f[5] := 0.0;
  b.f[6] := 1.0;
  b.f[7] := 1.0;

  // +0 == -0 (IEEE 754)
  mask := VecF32x8CmpEq(a, b);
  AssertTrue('+0 == +0', (mask and (1 shl 0)) <> 0);
  AssertTrue('-0 == +0', (mask and (1 shl 1)) <> 0);
  AssertTrue('+0 == -0', (mask and (1 shl 2)) <> 0);
  AssertTrue('-0 == -0', (mask and (1 shl 3)) <> 0);

  // 零的加法
  c := VecF32x8Add(a, b);
  AssertEquals('0 + 0 = 0', 0.0, c.f[0], F32x8_TOLERANCE);
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_SpecialValues_Denorm;
var
  a, b, c: TVecF32x8;
  denorm: Single;
  i: Integer;
begin
  // 最小的正规化数之下的非规范化数
  denorm := 1.0e-45;  // 接近 Single 最小正值

  a.f[0] := denorm;
  a.f[1] := denorm;
  a.f[2] := denorm;
  a.f[3] := -denorm;
  a.f[4] := denorm;
  a.f[5] := 1.0;
  a.f[6] := denorm;
  a.f[7] := 0.0;

  b.f[0] := denorm;
  b.f[1] := 1.0;
  b.f[2] := -denorm;
  b.f[3] := -denorm;
  b.f[4] := 0.0;
  b.f[5] := denorm;
  b.f[6] := denorm;
  b.f[7] := denorm;

  // 测试非规范化数的算术运算
  c := VecF32x8Add(a, b);
  for i := 0 to 7 do
  begin
    AssertFalse('Denorm add lane ' + IntToStr(i) + ' should not be NaN', IsNan(c.f[i]));
    AssertFalse('Denorm add lane ' + IntToStr(i) + ' should not be infinite', IsInfinite(c.f[i]));
  end;
  // 关键 lane：denorm 与正常值相加应保持正常值（允许极小误差）
  AssertEquals('Denorm add lane1 ~ 1.0', 1.0, c.f[1], F32x8_TOLERANCE);
  AssertEquals('Denorm add lane5 ~ 1.0', 1.0, c.f[5], F32x8_TOLERANCE);

  c := VecF32x8Mul(a, b);
  for i := 0 to 7 do
  begin
    AssertFalse('Denorm mul lane ' + IntToStr(i) + ' should not be NaN', IsNan(c.f[i]));
    AssertFalse('Denorm mul lane ' + IntToStr(i) + ' should not be infinite', IsInfinite(c.f[i]));
  end;
  // 关键 lane：与 0 相乘必须为 0；与 1 相乘应仍是极小值（或因 FTZ 变为 0）
  AssertEquals('Denorm mul lane4 = 0', 0.0, c.f[4], F32x8_TOLERANCE);
  AssertEquals('Denorm mul lane7 = 0', 0.0, c.f[7], F32x8_TOLERANCE);
  AssertTrue('Denorm mul lane5 should stay tiny or flush to zero', Abs(c.f[5]) <= 1.0e-37);
end;

// === 边界测试 ===

procedure TTestCase_VecF32x8.Test_VecF32x8_Boundary_MaxMin;
var
  a, b, c: TVecF32x8;
  maxSingle, minSingle: Single;
  oldMask: TFPUExceptionMask;
begin
  // 保存并禁用 FPU 异常
  oldMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    maxSingle := 3.4028235e+38;  // 接近 MaxSingle
    minSingle := -3.4028235e+38;

    a.f[0] := maxSingle;
    a.f[1] := minSingle;
    a.f[2] := maxSingle;
    a.f[3] := minSingle;
    a.f[4] := 1.0;
    a.f[5] := -1.0;
    a.f[6] := maxSingle / 2;
    a.f[7] := minSingle / 2;

    b.f[0] := 1.0;
    b.f[1] := -1.0;
    b.f[2] := -1.0;
    b.f[3] := 1.0;
    b.f[4] := maxSingle;
    b.f[5] := minSingle;
    b.f[6] := maxSingle / 2;
    b.f[7] := minSingle / 2;

    // 测试大数加法（可能溢出）
    c := VecF32x8Add(a, b);
    // maxSingle + 1.0 仍然是 maxSingle（精度限制）
    AssertTrue('MaxSingle + 1 should be close to MaxSingle', Abs(c.f[0] - maxSingle) < maxSingle * 1e-6);

    // 测试大数乘法
    c := VecF32x8Mul(a, b);
    AssertEquals('MaxSingle * 1 = MaxSingle', maxSingle, c.f[0], maxSingle * 1e-6);
    AssertEquals('MinSingle * -1 = MaxSingle', maxSingle, c.f[1], maxSingle * 1e-6);
  finally
    SetExceptionMask(oldMask);
  end;
end;

procedure TTestCase_VecF32x8.Test_VecF32x8_Boundary_Precision;
var
  a, b, c: TVecF32x8;
  i: Integer;
begin
  // 测试浮点精度边界
  // Single 精度约 7 位有效数字

  a.f[0] := 1.0;
  a.f[1] := 1.0;
  a.f[2] := 1000000.0;
  a.f[3] := 1000000.0;
  a.f[4] := 0.1;
  a.f[5] := 0.1;
  a.f[6] := 0.0000001;
  a.f[7] := 0.0000001;

  b.f[0] := 1e-7;    // 小于精度
  b.f[1] := 1e-6;    // 接近精度边界
  b.f[2] := 1.0;     // 1000000 + 1 可能丢失
  b.f[3] := 100.0;   // 应该保留
  b.f[4] := 0.1;
  b.f[5] := 0.2;
  b.f[6] := 0.0000001;
  b.f[7] := 0.0000002;

  c := VecF32x8Add(a, b);

  // 1.0 + 1e-7 在 Single 精度下可能等于 1.0
  // 1.0 + 1e-6 应该能看到变化
  AssertTrue('Precision test [1]: 1.0 + 1e-6 should differ from 1.0',
             c.f[1] <> 1.0);

  // 0.1 + 0.2 的精度问题
  // 结果应该接近 0.3，但可能不完全等于
  AssertEquals('0.1 + 0.2 should be close to 0.3', 0.3, c.f[5], 1e-6);
end;

initialization
  RegisterTest(TTestCase_VecF32x8);

end.
