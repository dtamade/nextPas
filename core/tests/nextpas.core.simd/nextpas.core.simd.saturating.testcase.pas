unit nextpas.core.simd.saturating.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base;

type
  // ✅ P2: 饱和算术测试 - 验证溢出/下溢边界行为
  TTestCase_SaturatingArithmetic = class(TScalarBackendStatefulTestCase)
  published
    // === 有符号 8 位 (I8x16) 饱和测试 ===
    procedure Test_I8x16SatAdd_Normal;        // 正常加法，无溢出
    procedure Test_I8x16SatAdd_Overflow;      // 溢出到 +127
    procedure Test_I8x16SatSub_Normal;        // 正常减法，无下溢
    procedure Test_I8x16SatSub_Underflow;     // 下溢到 -128
    procedure Test_I8x16Sat_Boundary;         // 边界值测试

    // === 有符号 16 位 (I16x8) 饱和测试 ===
    procedure Test_I16x8SatAdd_Normal;
    procedure Test_I16x8SatAdd_Overflow;
    procedure Test_I16x8SatSub_Normal;
    procedure Test_I16x8SatSub_Underflow;
    procedure Test_I16x8Sat_Boundary;

    // === 无符号 8 位 (U8x16) 饱和测试 ===
    procedure Test_U8x16SatAdd_Normal;
    procedure Test_U8x16SatAdd_Overflow;      // 溢出到 255
    procedure Test_U8x16SatSub_Normal;
    procedure Test_U8x16SatSub_Underflow;     // 下溢到 0
    procedure Test_U8x16Sat_Boundary;

    // === 无符号 16 位 (U16x8) 饱和测试 ===
    procedure Test_U16x8SatAdd_Normal;
    procedure Test_U16x8SatAdd_Overflow;
    procedure Test_U16x8SatSub_Normal;
    procedure Test_U16x8SatSub_Underflow;
    procedure Test_U16x8Sat_Boundary;
  end;

implementation

{ TTestCase_SaturatingArithmetic }

// === I8x16 有符号 8 位饱和算术测试 ===

procedure TTestCase_SaturatingArithmetic.Test_I8x16SatAdd_Normal;
var
  a, b, r: TVecI8x16;
  j: Integer;
begin
  // 正常加法：10 + 20 = 30 (无溢出)
  for j := 0 to 15 do
  begin
    a.i[j] := 10;
    b.i[j] := 20;
  end;
  r := VecI8x16SatAdd(a, b);
  for j := 0 to 15 do
    AssertEquals('I8 normal add element ' + IntToStr(j), 30, r.i[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_I8x16SatAdd_Overflow;
var
  a, b, r: TVecI8x16;
  j: Integer;
begin
  // 溢出测试：100 + 100 应该饱和到 127
  for j := 0 to 15 do
  begin
    a.i[j] := 100;
    b.i[j] := 100;
  end;
  r := VecI8x16SatAdd(a, b);
  for j := 0 to 15 do
    AssertEquals('I8 overflow should saturate to 127', 127, r.i[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_I8x16SatSub_Normal;
var
  a, b, r: TVecI8x16;
  j: Integer;
begin
  // 正常减法：50 - 20 = 30 (无下溢)
  for j := 0 to 15 do
  begin
    a.i[j] := 50;
    b.i[j] := 20;
  end;
  r := VecI8x16SatSub(a, b);
  for j := 0 to 15 do
    AssertEquals('I8 normal sub element ' + IntToStr(j), 30, r.i[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_I8x16SatSub_Underflow;
var
  a, b, r: TVecI8x16;
  j: Integer;
begin
  // 下溢测试：-100 - 100 应该饱和到 -128
  for j := 0 to 15 do
  begin
    a.i[j] := -100;
    b.i[j] := 100;
  end;
  r := VecI8x16SatSub(a, b);
  for j := 0 to 15 do
    AssertEquals('I8 underflow should saturate to -128', -128, r.i[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_I8x16Sat_Boundary;
var
  a, b, r: TVecI8x16;
  j: Integer;
begin
  // 初始化所有元素为 0
  for j := 0 to 15 do
  begin
    a.i[j] := 0;
    b.i[j] := 0;
  end;
  // 边界值测试：127 + 1 = 127 (饱和)
  a.i[0] := 127;  b.i[0] := 1;
  // -128 + 1 = -127 (正常)
  a.i[1] := -128; b.i[1] := 1;
  // 127 + 127 = 127 (饱和)
  a.i[2] := 127;  b.i[2] := 127;

  r := VecI8x16SatAdd(a, b);
  AssertEquals('127 + 1 should saturate to 127', 127, r.i[0]);
  AssertEquals('-128 + 1 should be -127', -127, r.i[1]);
  AssertEquals('127 + 127 should saturate to 127', 127, r.i[2]);
end;

// === I16x8 有符号 16 位饱和算术测试 ===

procedure TTestCase_SaturatingArithmetic.Test_I16x8SatAdd_Normal;
var
  a, b, r: TVecI16x8;
  j: Integer;
begin
  for j := 0 to 7 do
  begin
    a.i[j] := 1000;
    b.i[j] := 2000;
  end;
  r := VecI16x8SatAdd(a, b);
  for j := 0 to 7 do
    AssertEquals('I16 normal add element ' + IntToStr(j), 3000, r.i[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_I16x8SatAdd_Overflow;
var
  a, b, r: TVecI16x8;
  j: Integer;
begin
  // 30000 + 30000 应该饱和到 32767
  for j := 0 to 7 do
  begin
    a.i[j] := 30000;
    b.i[j] := 30000;
  end;
  r := VecI16x8SatAdd(a, b);
  for j := 0 to 7 do
    AssertEquals('I16 overflow should saturate to 32767', 32767, r.i[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_I16x8SatSub_Normal;
var
  a, b, r: TVecI16x8;
  j: Integer;
begin
  for j := 0 to 7 do
  begin
    a.i[j] := 5000;
    b.i[j] := 2000;
  end;
  r := VecI16x8SatSub(a, b);
  for j := 0 to 7 do
    AssertEquals('I16 normal sub element ' + IntToStr(j), 3000, r.i[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_I16x8SatSub_Underflow;
var
  a, b, r: TVecI16x8;
  j: Integer;
begin
  // -30000 - 30000 应该饱和到 -32768
  for j := 0 to 7 do
  begin
    a.i[j] := -30000;
    b.i[j] := 30000;
  end;
  r := VecI16x8SatSub(a, b);
  for j := 0 to 7 do
    AssertEquals('I16 underflow should saturate to -32768', -32768, r.i[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_I16x8Sat_Boundary;
var
  a, b, r: TVecI16x8;
  j: Integer;
begin
  // 初始化所有元素为 0
  for j := 0 to 7 do
  begin
    a.i[j] := 0;
    b.i[j] := 0;
  end;

  a.i[0] := 32767; b.i[0] := 1;
  a.i[1] := -32768; b.i[1] := 1;
  a.i[2] := 32767; b.i[2] := 32767;

  r := VecI16x8SatAdd(a, b);
  AssertEquals('32767 + 1 should saturate to 32767', 32767, r.i[0]);
  AssertEquals('-32768 + 1 should be -32767', -32767, r.i[1]);
  AssertEquals('32767 + 32767 should saturate to 32767', 32767, r.i[2]);
end;

// === U8x16 无符号 8 位饱和算术测试 ===

procedure TTestCase_SaturatingArithmetic.Test_U8x16SatAdd_Normal;
var
  a, b, r: TVecU8x16;
  j: Integer;
begin
  for j := 0 to 15 do
  begin
    a.u[j] := 10;
    b.u[j] := 20;
  end;
  r := VecU8x16SatAdd(a, b);
  for j := 0 to 15 do
    AssertEquals('U8 normal add element ' + IntToStr(j), 30, r.u[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_U8x16SatAdd_Overflow;
var
  a, b, r: TVecU8x16;
  j: Integer;
begin
  // 200 + 200 应该饱和到 255
  for j := 0 to 15 do
  begin
    a.u[j] := 200;
    b.u[j] := 200;
  end;
  r := VecU8x16SatAdd(a, b);
  for j := 0 to 15 do
    AssertEquals('U8 overflow should saturate to 255', 255, r.u[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_U8x16SatSub_Normal;
var
  a, b, r: TVecU8x16;
  j: Integer;
begin
  for j := 0 to 15 do
  begin
    a.u[j] := 50;
    b.u[j] := 20;
  end;
  r := VecU8x16SatSub(a, b);
  for j := 0 to 15 do
    AssertEquals('U8 normal sub element ' + IntToStr(j), 30, r.u[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_U8x16SatSub_Underflow;
var
  a, b, r: TVecU8x16;
  j: Integer;
begin
  // 10 - 100 应该饱和到 0
  for j := 0 to 15 do
  begin
    a.u[j] := 10;
    b.u[j] := 100;
  end;
  r := VecU8x16SatSub(a, b);
  for j := 0 to 15 do
    AssertEquals('U8 underflow should saturate to 0', 0, r.u[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_U8x16Sat_Boundary;
var
  a, b, r: TVecU8x16;
  j: Integer;
begin
  // 初始化所有元素为 0
  for j := 0 to 15 do
  begin
    a.u[j] := 0;
    b.u[j] := 0;
  end;
  // 255 + 1 = 255 (饱和)
  a.u[0] := 255; b.u[0] := 1;
  // 0 + 1 = 1 (正常)
  a.u[1] := 0;   b.u[1] := 1;
  // 255 + 255 = 255 (饱和)
  a.u[2] := 255; b.u[2] := 255;

  r := VecU8x16SatAdd(a, b);
  AssertEquals('255 + 1 should saturate to 255', 255, r.u[0]);
  AssertEquals('0 + 1 should be 1', 1, r.u[1]);
  AssertEquals('255 + 255 should saturate to 255', 255, r.u[2]);

  // 测试减法下溢
  r := VecU8x16SatSub(a, b);
  AssertEquals('255 - 1 should be 254', 254, r.u[0]);
  AssertEquals('0 - 1 should saturate to 0', 0, r.u[1]);
end;

// === U16x8 无符号 16 位饱和算术测试 ===

procedure TTestCase_SaturatingArithmetic.Test_U16x8SatAdd_Normal;
var
  a, b, r: TVecU16x8;
  j: Integer;
begin
  for j := 0 to 7 do
  begin
    a.u[j] := 1000;
    b.u[j] := 2000;
  end;
  r := VecU16x8SatAdd(a, b);
  for j := 0 to 7 do
    AssertEquals('U16 normal add element ' + IntToStr(j), 3000, r.u[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_U16x8SatAdd_Overflow;
var
  a, b, r: TVecU16x8;
  j: Integer;
begin
  // 60000 + 60000 应该饱和到 65535
  for j := 0 to 7 do
  begin
    a.u[j] := 60000;
    b.u[j] := 60000;
  end;
  r := VecU16x8SatAdd(a, b);
  for j := 0 to 7 do
    AssertEquals('U16 overflow should saturate to 65535', 65535, r.u[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_U16x8SatSub_Normal;
var
  a, b, r: TVecU16x8;
  j: Integer;
begin
  for j := 0 to 7 do
  begin
    a.u[j] := 5000;
    b.u[j] := 2000;
  end;
  r := VecU16x8SatSub(a, b);
  for j := 0 to 7 do
    AssertEquals('U16 normal sub element ' + IntToStr(j), 3000, r.u[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_U16x8SatSub_Underflow;
var
  a, b, r: TVecU16x8;
  j: Integer;
begin
  // 100 - 1000 应该饱和到 0
  for j := 0 to 7 do
  begin
    a.u[j] := 100;
    b.u[j] := 1000;
  end;
  r := VecU16x8SatSub(a, b);
  for j := 0 to 7 do
    AssertEquals('U16 underflow should saturate to 0', 0, r.u[j]);
end;

procedure TTestCase_SaturatingArithmetic.Test_U16x8Sat_Boundary;
var
  a, b, r: TVecU16x8;
begin
  a.u[0] := 65535; b.u[0] := 1;
  a.u[1] := 0;     b.u[1] := 1;
  a.u[2] := 65535; b.u[2] := 65535;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  r := VecU16x8SatAdd(a, b);
  AssertEquals('65535 + 1 should saturate to 65535', 65535, r.u[0]);
  AssertEquals('0 + 1 should be 1', 1, r.u[1]);
  AssertEquals('65535 + 65535 should saturate to 65535', 65535, r.u[2]);

  r := VecU16x8SatSub(a, b);
  AssertEquals('65535 - 1 should be 65534', 65534, r.u[0]);
  AssertEquals('0 - 1 should saturate to 0', 0, r.u[1]);
end;

initialization
  RegisterTest(TTestCase_SaturatingArithmetic);

end.
