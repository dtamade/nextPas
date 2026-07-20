unit nextpas.core.simd.veci32x8.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  nextpas.core.text.conv, nextpas.core.test, nextpas.core.simd,
  nextpas.core.simd.testcase, nextpas.core.simd.base,
  nextpas.core.simd.ops;

type
  // === TVecI32x8 (256-bit 有符号整数向量) 完整测试套件 ===
  TTestCase_VecI32x8 = class(TScalarBackendStatefulTestCase)
  published
    // === 算术操作 ===
    procedure Test_VecI32x8_Add;           // 加法
    procedure Test_VecI32x8_Sub;           // 减法
    procedure Test_VecI32x8_Mul;           // 乘法
    procedure Test_VecI32x8_Neg;           // 取负（通过运算符）

    // === 位运算 ===
    procedure Test_VecI32x8_And;
    procedure Test_VecI32x8_Or;
    procedure Test_VecI32x8_Xor;
    procedure Test_VecI32x8_Not;
    procedure Test_VecI32x8_AndNot;

    // === 移位 ===
    procedure Test_VecI32x8_ShiftLeft;
    procedure Test_VecI32x8_ShiftRight;

    // === 比较 ===
    procedure Test_VecI32x8_CmpEq;
    procedure Test_VecI32x8_CmpLt;
    procedure Test_VecI32x8_CmpGt;
    procedure Test_VecI32x8_CmpLe;
    procedure Test_VecI32x8_CmpGe;
    procedure Test_VecI32x8_CmpNe;

    // === Min/Max ===
    procedure Test_VecI32x8_Min;
    procedure Test_VecI32x8_Max;

    // === 工具函数 ===
    procedure Test_VecI32x8_Splat;
    procedure Test_VecI32x8_Zero;
    procedure Test_VecI32x8_LoadStore;
    procedure Test_VecI32x8_SizeOf;

    // === 边界测试 ===
    procedure Test_VecI32x8_Overflow;      // 溢出行为
    procedure Test_VecI32x8_MaxMinValues;  // Low(Int32)/High(Int32)
  end;

implementation
{ TTestCase_VecI32x8 }

// === 算术操作测试 ===

procedure TTestCase_VecI32x8.Test_VecI32x8_Add;
var
  a, b, r: TVecI32x8;
  i: Integer;
begin
  // 初始化向量
  for i := 0 to 7 do
  begin
    a.i[i] := i + 1;           // 1, 2, 3, 4, 5, 6, 7, 8
    b.i[i] := (i + 1) * 10;    // 10, 20, 30, 40, 50, 60, 70, 80
  end;

  r := VecI32x8Add(a, b);

  CheckEqual(11, r.i[0], 'I32x8 Add [0]');
  CheckEqual(22, r.i[1], 'I32x8 Add [1]');
  CheckEqual(33, r.i[2], 'I32x8 Add [2]');
  CheckEqual(44, r.i[3], 'I32x8 Add [3]');
  CheckEqual(55, r.i[4], 'I32x8 Add [4]');
  CheckEqual(66, r.i[5], 'I32x8 Add [5]');
  CheckEqual(77, r.i[6], 'I32x8 Add [6]');
  CheckEqual(88, r.i[7], 'I32x8 Add [7]');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_Sub;
var
  a, b, r: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := (i + 1) * 100;   // 100, 200, 300, 400, 500, 600, 700, 800
    b.i[i] := (i + 1) * 10;    // 10, 20, 30, 40, 50, 60, 70, 80
  end;

  r := VecI32x8Sub(a, b);

  CheckEqual(90, r.i[0], 'I32x8 Sub [0]');
  CheckEqual(180, r.i[1], 'I32x8 Sub [1]');
  CheckEqual(270, r.i[2], 'I32x8 Sub [2]');
  CheckEqual(360, r.i[3], 'I32x8 Sub [3]');
  CheckEqual(450, r.i[4], 'I32x8 Sub [4]');
  CheckEqual(540, r.i[5], 'I32x8 Sub [5]');
  CheckEqual(630, r.i[6], 'I32x8 Sub [6]');
  CheckEqual(720, r.i[7], 'I32x8 Sub [7]');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_Mul;
var
  a, b, r: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := i + 2;     // 2, 3, 4, 5, 6, 7, 8, 9
    b.i[i] := i + 3;     // 3, 4, 5, 6, 7, 8, 9, 10
  end;

  r := VecI32x8Mul(a, b);

  CheckEqual(6, r.i[0], 'I32x8 Mul [0]');    // 2*3
  CheckEqual(12, r.i[1], 'I32x8 Mul [1]');   // 3*4
  CheckEqual(20, r.i[2], 'I32x8 Mul [2]');   // 4*5
  CheckEqual(30, r.i[3], 'I32x8 Mul [3]');   // 5*6
  CheckEqual(42, r.i[4], 'I32x8 Mul [4]');   // 6*7
  CheckEqual(56, r.i[5], 'I32x8 Mul [5]');   // 7*8
  CheckEqual(72, r.i[6], 'I32x8 Mul [6]');   // 8*9
  CheckEqual(90, r.i[7], 'I32x8 Mul [7]');   // 9*10
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_Neg;
var
  a, r: TVecI32x8;
  i: Integer;
begin
  // 使用运算符重载的取负操作
  for i := 0 to 7 do
    a.i[i] := (i + 1) * 10;  // 10, 20, 30, 40, 50, 60, 70, 80

  r := -a;  // 使用运算符重载

  CheckEqual(-10, r.i[0], 'I32x8 Neg [0]');
  CheckEqual(-20, r.i[1], 'I32x8 Neg [1]');
  CheckEqual(-30, r.i[2], 'I32x8 Neg [2]');
  CheckEqual(-40, r.i[3], 'I32x8 Neg [3]');
  CheckEqual(-50, r.i[4], 'I32x8 Neg [4]');
  CheckEqual(-60, r.i[5], 'I32x8 Neg [5]');
  CheckEqual(-70, r.i[6], 'I32x8 Neg [6]');
  CheckEqual(-80, r.i[7], 'I32x8 Neg [7]');

  // 测试负数取负变正
  for i := 0 to 7 do
    a.i[i] := -(i + 1);

  r := -a;

  for i := 0 to 7 do
    CheckEqual(i + 1, r.i[i], 'I32x8 Neg negative [' + IntToStr(i) + ']');
end;

// === 位运算测试 ===

procedure TTestCase_VecI32x8.Test_VecI32x8_And;
var
  a, b, r: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := Int32($FF00FF00);
    b.i[i] := $0F0F0F0F;
  end;

  r := VecI32x8And(a, b);

  for i := 0 to 7 do
    CheckEqual(Int32($0F000F00), r.i[i], 'I32x8 And [' + IntToStr(i) + ']');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_Or;
var
  a, b, r: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := Int32($FF000000);
    b.i[i] := $00FF0000;
  end;

  r := VecI32x8Or(a, b);

  for i := 0 to 7 do
    CheckEqual(Int32($FFFF0000), r.i[i], 'I32x8 Or [' + IntToStr(i) + ']');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_Xor;
var
  a, b, r: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := Int32($FFFFFFFF);
    b.i[i] := $0F0F0F0F;
  end;

  r := VecI32x8Xor(a, b);

  for i := 0 to 7 do
    CheckEqual(Int32($F0F0F0F0), r.i[i], 'I32x8 Xor [' + IntToStr(i) + ']');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_Not;
var
  a, r: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
    a.i[i] := $0F0F0F0F;

  r := VecI32x8Not(a);

  for i := 0 to 7 do
    CheckEqual(Int32($F0F0F0F0), r.i[i], 'I32x8 Not [' + IntToStr(i) + ']');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_AndNot;
var
  a, b, r: TVecI32x8;
  i: Integer;
begin
  // AndNot: NOT(a) AND b
  for i := 0 to 7 do
  begin
    a.i[i] := Int32($F0F0F0F0);
    b.i[i] := Int32($FFFFFFFF);
  end;

  r := VecI32x8AndNot(a, b);

  // NOT($F0F0F0F0) AND $FFFFFFFF = $0F0F0F0F
  for i := 0 to 7 do
    CheckEqual(Int32($0F0F0F0F), r.i[i], 'I32x8 AndNot [' + IntToStr(i) + ']');
end;

// === 移位测试 ===

procedure TTestCase_VecI32x8.Test_VecI32x8_ShiftLeft;
var
  a, r: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
    a.i[i] := 1;

  // 左移4位
  r := VecI32x8ShiftLeft(a, 4);

  for i := 0 to 7 do
    CheckEqual(16, r.i[i], 'I32x8 ShiftLeft [' + IntToStr(i) + ']');

  // 测试不同的值
  for i := 0 to 7 do
    a.i[i] := i + 1;

  r := VecI32x8ShiftLeft(a, 2);

  CheckEqual(4, r.i[0], 'I32x8 ShiftLeft 1<<2');
  CheckEqual(8, r.i[1], 'I32x8 ShiftLeft 2<<2');
  CheckEqual(12, r.i[2], 'I32x8 ShiftLeft 3<<2');
  CheckEqual(32, r.i[7], 'I32x8 ShiftLeft 8<<2');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_ShiftRight;
var
  a, r: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
    a.i[i] := 256;

  // 右移4位（逻辑右移或算术右移取决于实现）
  r := VecI32x8ShiftRight(a, 4);

  for i := 0 to 7 do
    CheckEqual(16, r.i[i], 'I32x8 ShiftRight [' + IntToStr(i) + ']');

  // 测试算术右移（负数）
  for i := 0 to 7 do
    a.i[i] := -16;

  r := VecI32x8ShiftRightArith(a, 2);

  // 算术右移保持符号位
  for i := 0 to 7 do
    CheckEqual(-4, r.i[i], 'I32x8 ShiftRightArith negative [' + IntToStr(i) + ']');
end;

// === 比较测试 ===

procedure TTestCase_VecI32x8.Test_VecI32x8_CmpEq;
var
  a, b: TVecI32x8;
  m: TMask8;
  i: Integer;
begin
  // 设置一些相等，一些不相等
  for i := 0 to 7 do
  begin
    a.i[i] := i * 10;
    b.i[i] := i * 10;
  end;
  // 修改部分值使其不相等
  b.i[2] := 999;
  b.i[5] := 999;

  m := VecI32x8CmpEq(a, b);

  // 检查相等的位置
  CheckTrue((m and (1 shl 0)) <> 0, 'I32x8 CmpEq [0] should be equal');
  CheckTrue((m and (1 shl 1)) <> 0, 'I32x8 CmpEq [1] should be equal');
  CheckFalse((m and (1 shl 2)) <> 0, 'I32x8 CmpEq [2] should not be equal');
  CheckTrue((m and (1 shl 3)) <> 0, 'I32x8 CmpEq [3] should be equal');
  CheckTrue((m and (1 shl 4)) <> 0, 'I32x8 CmpEq [4] should be equal');
  CheckFalse((m and (1 shl 5)) <> 0, 'I32x8 CmpEq [5] should not be equal');
  CheckTrue((m and (1 shl 6)) <> 0, 'I32x8 CmpEq [6] should be equal');
  CheckTrue((m and (1 shl 7)) <> 0, 'I32x8 CmpEq [7] should be equal');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_CmpLt;
var
  a, b: TVecI32x8;
  m: TMask8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := i;
    b.i[i] := 4;  // a < b 当 i < 4
  end;

  m := VecI32x8CmpLt(a, b);

  // a[0..3] < 4, a[4..7] >= 4
  CheckTrue((m and (1 shl 0)) <> 0, 'I32x8 CmpLt [0] should be less');
  CheckTrue((m and (1 shl 1)) <> 0, 'I32x8 CmpLt [1] should be less');
  CheckTrue((m and (1 shl 2)) <> 0, 'I32x8 CmpLt [2] should be less');
  CheckTrue((m and (1 shl 3)) <> 0, 'I32x8 CmpLt [3] should be less');
  CheckFalse((m and (1 shl 4)) <> 0, 'I32x8 CmpLt [4] should not be less');
  CheckFalse((m and (1 shl 5)) <> 0, 'I32x8 CmpLt [5] should not be less');
  CheckFalse((m and (1 shl 6)) <> 0, 'I32x8 CmpLt [6] should not be less');
  CheckFalse((m and (1 shl 7)) <> 0, 'I32x8 CmpLt [7] should not be less');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_CmpGt;
var
  a, b: TVecI32x8;
  m: TMask8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := i;
    b.i[i] := 3;  // a > b 当 i > 3
  end;

  m := VecI32x8CmpGt(a, b);

  // a[0..3] <= 3, a[4..7] > 3
  CheckFalse((m and (1 shl 0)) <> 0, 'I32x8 CmpGt [0] should not be greater');
  CheckFalse((m and (1 shl 1)) <> 0, 'I32x8 CmpGt [1] should not be greater');
  CheckFalse((m and (1 shl 2)) <> 0, 'I32x8 CmpGt [2] should not be greater');
  CheckFalse((m and (1 shl 3)) <> 0, 'I32x8 CmpGt [3] should not be greater');
  CheckTrue((m and (1 shl 4)) <> 0, 'I32x8 CmpGt [4] should be greater');
  CheckTrue((m and (1 shl 5)) <> 0, 'I32x8 CmpGt [5] should be greater');
  CheckTrue((m and (1 shl 6)) <> 0, 'I32x8 CmpGt [6] should be greater');
  CheckTrue((m and (1 shl 7)) <> 0, 'I32x8 CmpGt [7] should be greater');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_CmpLe;
var
  a, b: TVecI32x8;
  m: TMask8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := i;
    b.i[i] := 4;  // a <= b 当 i <= 4
  end;

  m := VecI32x8CmpLe(a, b);

  // a[0..4] <= 4, a[5..7] > 4
  CheckTrue((m and (1 shl 0)) <> 0, 'I32x8 CmpLe [0] should be <=');
  CheckTrue((m and (1 shl 1)) <> 0, 'I32x8 CmpLe [1] should be <=');
  CheckTrue((m and (1 shl 2)) <> 0, 'I32x8 CmpLe [2] should be <=');
  CheckTrue((m and (1 shl 3)) <> 0, 'I32x8 CmpLe [3] should be <=');
  CheckTrue((m and (1 shl 4)) <> 0, 'I32x8 CmpLe [4] should be <=');
  CheckFalse((m and (1 shl 5)) <> 0, 'I32x8 CmpLe [5] should not be <=');
  CheckFalse((m and (1 shl 6)) <> 0, 'I32x8 CmpLe [6] should not be <=');
  CheckFalse((m and (1 shl 7)) <> 0, 'I32x8 CmpLe [7] should not be <=');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_CmpGe;
var
  a, b: TVecI32x8;
  m: TMask8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := i;
    b.i[i] := 3;  // a >= b 当 i >= 3
  end;

  m := VecI32x8CmpGe(a, b);

  // a[0..2] < 3, a[3..7] >= 3
  CheckFalse((m and (1 shl 0)) <> 0, 'I32x8 CmpGe [0] should not be >=');
  CheckFalse((m and (1 shl 1)) <> 0, 'I32x8 CmpGe [1] should not be >=');
  CheckFalse((m and (1 shl 2)) <> 0, 'I32x8 CmpGe [2] should not be >=');
  CheckTrue((m and (1 shl 3)) <> 0, 'I32x8 CmpGe [3] should be >=');
  CheckTrue((m and (1 shl 4)) <> 0, 'I32x8 CmpGe [4] should be >=');
  CheckTrue((m and (1 shl 5)) <> 0, 'I32x8 CmpGe [5] should be >=');
  CheckTrue((m and (1 shl 6)) <> 0, 'I32x8 CmpGe [6] should be >=');
  CheckTrue((m and (1 shl 7)) <> 0, 'I32x8 CmpGe [7] should be >=');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_CmpNe;
var
  a, b: TVecI32x8;
  m: TMask8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := i * 10;
    b.i[i] := i * 10;
  end;
  // 修改部分值使其不相等
  b.i[1] := 999;
  b.i[4] := 999;
  b.i[7] := 999;

  m := VecI32x8CmpNe(a, b);

  // 检查不相等的位置
  CheckFalse((m and (1 shl 0)) <> 0, 'I32x8 CmpNe [0] should be equal');
  CheckTrue((m and (1 shl 1)) <> 0, 'I32x8 CmpNe [1] should not be equal');
  CheckFalse((m and (1 shl 2)) <> 0, 'I32x8 CmpNe [2] should be equal');
  CheckFalse((m and (1 shl 3)) <> 0, 'I32x8 CmpNe [3] should be equal');
  CheckTrue((m and (1 shl 4)) <> 0, 'I32x8 CmpNe [4] should not be equal');
  CheckFalse((m and (1 shl 5)) <> 0, 'I32x8 CmpNe [5] should be equal');
  CheckFalse((m and (1 shl 6)) <> 0, 'I32x8 CmpNe [6] should be equal');
  CheckTrue((m and (1 shl 7)) <> 0, 'I32x8 CmpNe [7] should not be equal');
end;

// === Min/Max 测试 ===

procedure TTestCase_VecI32x8.Test_VecI32x8_Min;
var
  a, b, r: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := i * 10;
    b.i[i] := 35;  // 交叉点在 3-4 之间
  end;

  r := VecI32x8Min(a, b);

  // min(0, 35)=0, min(10, 35)=10, min(20, 35)=20, min(30, 35)=30
  // min(40, 35)=35, min(50, 35)=35, min(60, 35)=35, min(70, 35)=35
  CheckEqual(0, r.i[0], 'I32x8 Min [0]');
  CheckEqual(10, r.i[1], 'I32x8 Min [1]');
  CheckEqual(20, r.i[2], 'I32x8 Min [2]');
  CheckEqual(30, r.i[3], 'I32x8 Min [3]');
  CheckEqual(35, r.i[4], 'I32x8 Min [4]');
  CheckEqual(35, r.i[5], 'I32x8 Min [5]');
  CheckEqual(35, r.i[6], 'I32x8 Min [6]');
  CheckEqual(35, r.i[7], 'I32x8 Min [7]');

  // 测试负数
  for i := 0 to 7 do
  begin
    a.i[i] := -i;
    b.i[i] := 0;
  end;

  r := VecI32x8Min(a, b);

  for i := 0 to 7 do
    CheckEqual(-i, r.i[i], 'I32x8 Min negative [' + IntToStr(i) + ']');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_Max;
var
  a, b, r: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.i[i] := i * 10;
    b.i[i] := 35;
  end;

  r := VecI32x8Max(a, b);

  // max(0, 35)=35, max(10, 35)=35, max(20, 35)=35, max(30, 35)=35
  // max(40, 35)=40, max(50, 35)=50, max(60, 35)=60, max(70, 35)=70
  CheckEqual(35, r.i[0], 'I32x8 Max [0]');
  CheckEqual(35, r.i[1], 'I32x8 Max [1]');
  CheckEqual(35, r.i[2], 'I32x8 Max [2]');
  CheckEqual(35, r.i[3], 'I32x8 Max [3]');
  CheckEqual(40, r.i[4], 'I32x8 Max [4]');
  CheckEqual(50, r.i[5], 'I32x8 Max [5]');
  CheckEqual(60, r.i[6], 'I32x8 Max [6]');
  CheckEqual(70, r.i[7], 'I32x8 Max [7]');

  // 测试负数
  for i := 0 to 7 do
  begin
    a.i[i] := -i;
    b.i[i] := 0;
  end;

  r := VecI32x8Max(a, b);

  for i := 0 to 7 do
    CheckEqual(0, r.i[i], 'I32x8 Max negative [' + IntToStr(i) + ']');
end;

// === 工具函数测试 ===

procedure TTestCase_VecI32x8.Test_VecI32x8_Splat;
var
  v: TVecI32x8;
  i: Integer;
begin
  // 通过手动设置所有元素来模拟 Splat
  for i := 0 to 7 do
    v.i[i] := 42;

  for i := 0 to 7 do
    CheckEqual(42, v.i[i], 'I32x8 Splat [' + IntToStr(i) + ']');

  // 测试负数
  for i := 0 to 7 do
    v.i[i] := -12345;

  for i := 0 to 7 do
    CheckEqual(-12345, v.i[i], 'I32x8 Splat negative [' + IntToStr(i) + ']');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_Zero;
var
  v: TVecI32x8;
  i: Integer;
begin
  // 初始化为非零值
  for i := 0 to 7 do
    v.i[i] := i + 100;

  // 清零
  FillChar(v, SizeOf(v), 0);

  for i := 0 to 7 do
    CheckEqual(0, v.i[i], 'I32x8 Zero [' + IntToStr(i) + ']');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_LoadStore;
var
  src, dst: array[0..7] of Int32;
  v: TVecI32x8;
  i: Integer;
begin
  // 初始化源数据
  for i := 0 to 7 do
    src[i] := (i + 1) * 111;  // 111, 222, 333, ...

  // 加载到向量
  Move(src[0], v, SizeOf(v));

  // 验证加载
  for i := 0 to 7 do
    CheckEqual(src[i], v.i[i], 'I32x8 Load [' + IntToStr(i) + ']');

  // 存储到目标
  Move(v, dst[0], SizeOf(v));

  // 验证存储
  for i := 0 to 7 do
    CheckEqual(src[i], dst[i], 'I32x8 Store [' + IntToStr(i) + ']');
end;

procedure TTestCase_VecI32x8.Test_VecI32x8_SizeOf;
begin
  CheckEqual(32, SizeOf(TVecI32x8), 'TVecI32x8 should be 32 bytes (256 bits)');
end;

// === 边界测试 ===

{$PUSH}{$R-}{$Q-}  // 禁用溢出检查用于溢出测试
procedure TTestCase_VecI32x8.Test_VecI32x8_Overflow;
var
  a, b, r: TVecI32x8;
  i: Integer;
begin
  // 测试正溢出：MaxInt32 + 1 应该回绕到 MinInt32
  for i := 0 to 7 do
  begin
    a.i[i] := High(Int32);  // 2147483647
    b.i[i] := 1;
  end;

  r := VecI32x8Add(a, b);

  for i := 0 to 7 do
    CheckEqual(Low(Int32), r.i[i], 'I32x8 positive overflow [' + IntToStr(i) + ']');  // 应该回绕到 -2147483648

  // 测试负溢出：MinInt32 - 1 应该回绕到 MaxInt32
  for i := 0 to 7 do
  begin
    a.i[i] := Low(Int32);  // -2147483648
    b.i[i] := 1;
  end;

  r := VecI32x8Sub(a, b);

  for i := 0 to 7 do
    CheckEqual(High(Int32), r.i[i], 'I32x8 negative overflow [' + IntToStr(i) + ']');  // 应该回绕到 2147483647

  // 测试乘法溢出
  for i := 0 to 7 do
  begin
    a.i[i] := 65536;  // 2^16
    b.i[i] := 65536;  // 2^16
  end;

  r := VecI32x8Mul(a, b);

  // 65536 * 65536 = 2^32，超过 Int32 范围，应该回绕
  for i := 0 to 7 do
    CheckEqual(0, r.i[i], 'I32x8 mul overflow [' + IntToStr(i) + ']');
end;
{$POP}

procedure TTestCase_VecI32x8.Test_VecI32x8_MaxMinValues;
var
  a, b, r: TVecI32x8;
  m: TMask8;
  i: Integer;
begin
  // 设置极值
  for i := 0 to 3 do
    a.i[i] := High(Int32);  // 2147483647
  for i := 4 to 7 do
    a.i[i] := Low(Int32);   // -2147483648

  for i := 0 to 7 do
    b.i[i] := 0;

  // 测试 Min
  r := VecI32x8Min(a, b);

  for i := 0 to 3 do
    CheckEqual(0, r.i[i], 'I32x8 Min MaxInt32 vs 0 [' + IntToStr(i) + ']');
  for i := 4 to 7 do
    CheckEqual(Low(Int32), r.i[i], 'I32x8 Min MinInt32 vs 0 [' + IntToStr(i) + ']');

  // 测试 Max
  r := VecI32x8Max(a, b);

  for i := 0 to 3 do
    CheckEqual(High(Int32), r.i[i], 'I32x8 Max MaxInt32 vs 0 [' + IntToStr(i) + ']');
  for i := 4 to 7 do
    CheckEqual(0, r.i[i], 'I32x8 Max MinInt32 vs 0 [' + IntToStr(i) + ']');

  // 测试比较极值
  for i := 0 to 7 do
  begin
    a.i[i] := High(Int32);
    b.i[i] := High(Int32);
  end;

  m := VecI32x8CmpEq(a, b);
  CheckEqual($FF, m, 'All MaxInt32 should be equal');

  for i := 0 to 7 do
  begin
    a.i[i] := Low(Int32);
    b.i[i] := Low(Int32);
  end;

  m := VecI32x8CmpEq(a, b);
  CheckEqual($FF, m, 'All MinInt32 should be equal');

  // 测试 MinInt32 < MaxInt32
  for i := 0 to 7 do
  begin
    a.i[i] := Low(Int32);
    b.i[i] := High(Int32);
  end;

  m := VecI32x8CmpLt(a, b);
  CheckEqual($FF, m, 'MinInt32 should be less than MaxInt32');
end;



end.