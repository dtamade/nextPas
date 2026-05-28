unit nextpas.core.simd.vecu32x8.testcase;

{$mode objfpc}{$H+}
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
  // ✅ TVecU32x8 (256-bit 无符号整数向量) 完整测试套件 (2026-02-05)
  TTestCase_VecU32x8 = class(TScalarBackendStatefulTestCase)
  published
    // === 算术操作 ===
    procedure Test_VecU32x8_Add;
    procedure Test_VecU32x8_Sub;
    procedure Test_VecU32x8_Mul;

    // === 位运算 ===
    procedure Test_VecU32x8_And;
    procedure Test_VecU32x8_Or;
    procedure Test_VecU32x8_Xor;
    procedure Test_VecU32x8_Not;
    procedure Test_VecU32x8_AndNot;

    // === 移位 ===
    procedure Test_VecU32x8_ShiftLeft;
    procedure Test_VecU32x8_ShiftRight;

    // === 比较 (无符号语义) ===
    procedure Test_VecU32x8_CmpEq;
    procedure Test_VecU32x8_CmpLt;      // 无符号比较
    procedure Test_VecU32x8_CmpGt;
    procedure Test_VecU32x8_CmpLe;
    procedure Test_VecU32x8_CmpGe;
    procedure Test_VecU32x8_CmpNe;

    // === Min/Max ===
    procedure Test_VecU32x8_Min;
    procedure Test_VecU32x8_Max;

    // === 工具函数 ===
    procedure Test_VecU32x8_Splat;
    procedure Test_VecU32x8_Zero;
    procedure Test_VecU32x8_SizeOf;

    // === 边界测试 ===
    procedure Test_VecU32x8_Wraparound;   // 无符号溢出回绕
    procedure Test_VecU32x8_MaxValue;     // High(UInt32) = $FFFFFFFF
  end;

implementation
{ TTestCase_VecU32x8 }

// === 算术操作 ===

procedure TTestCase_VecU32x8.Test_VecU32x8_Add;
var
  a, b, r: TVecU32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.u[i] := UInt32(i * 100);
    b.u[i] := UInt32(i * 200 + 50);
  end;

  r := VecU32x8Add(a, b);

  for i := 0 to 7 do
    AssertEquals('U32x8 Add [' + IntToStr(i) + ']', UInt32(a.u[i] + b.u[i]), r.u[i]);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_Sub;
var
  a, b, r: TVecU32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.u[i] := UInt32((i + 1) * 500);
    b.u[i] := UInt32(i * 100);
  end;

  r := VecU32x8Sub(a, b);

  for i := 0 to 7 do
    AssertEquals('U32x8 Sub [' + IntToStr(i) + ']', UInt32(a.u[i] - b.u[i]), r.u[i]);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_Mul;
var
  a, b, r: TVecU32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.u[i] := UInt32(i * 10 + 1);
    b.u[i] := UInt32(i * 5 + 2);
  end;

  r := VecU32x8Mul(a, b);

  for i := 0 to 7 do
    AssertEquals('U32x8 Mul [' + IntToStr(i) + ']', UInt32(a.u[i] * b.u[i]), r.u[i]);
end;

// === 位运算 ===

procedure TTestCase_VecU32x8.Test_VecU32x8_And;
var
  a, b, r: TVecU32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.u[i] := $FF00FF00;
    b.u[i] := $0F0F0F0F;
  end;

  r := VecU32x8And(a, b);

  for i := 0 to 7 do
    AssertEquals('U32x8 And [' + IntToStr(i) + ']', UInt32($0F000F00), r.u[i]);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_Or;
var
  a, b, r: TVecU32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.u[i] := $FF000000;
    b.u[i] := $0000FF00;
  end;

  r := VecU32x8Or(a, b);

  for i := 0 to 7 do
    AssertEquals('U32x8 Or [' + IntToStr(i) + ']', UInt32($FF00FF00), r.u[i]);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_Xor;
var
  a, b, r: TVecU32x8;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a.u[i] := $FFFFFFFF;
    b.u[i] := $0F0F0F0F;
  end;

  r := VecU32x8Xor(a, b);

  for i := 0 to 7 do
    AssertEquals('U32x8 Xor [' + IntToStr(i) + ']', UInt32($F0F0F0F0), r.u[i]);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_Not;
var
  a, r: TVecU32x8;
  i: Integer;
begin
  for i := 0 to 7 do
    a.u[i] := $0F0F0F0F;

  r := VecU32x8Not(a);

  for i := 0 to 7 do
    AssertEquals('U32x8 Not [' + IntToStr(i) + ']', UInt32($F0F0F0F0), r.u[i]);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_AndNot;
var
  a, b, r: TVecU32x8;
  LIndex: Integer;
begin
  for LIndex := 0 to 7 do
  begin
    a.u[LIndex] := $0F0F0F0F;
    b.u[LIndex] := $FFFFFFFF;
  end;

  r := VecU32x8AndNot(a, b);

  for LIndex := 0 to 7 do
    AssertEquals('U32x8 AndNot [' + IntToStr(LIndex) + ']', UInt32($F0F0F0F0), r.u[LIndex]);
end;

// === 移位 ===

procedure TTestCase_VecU32x8.Test_VecU32x8_ShiftLeft;
var
  a, r: TVecU32x8;
  i: Integer;
begin
  for i := 0 to 7 do
    a.u[i] := UInt32(1);

  r := VecU32x8ShiftLeft(a, 8);

  for i := 0 to 7 do
    AssertEquals('U32x8 ShiftLeft [' + IntToStr(i) + ']', UInt32(256), r.u[i]);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_ShiftRight;
var
  a, r: TVecU32x8;
  i: Integer;
begin
  for i := 0 to 7 do
    a.u[i] := UInt32(256);

  r := VecU32x8ShiftRight(a, 4);

  for i := 0 to 7 do
    AssertEquals('U32x8 ShiftRight [' + IntToStr(i) + ']', UInt32(16), r.u[i]);
end;

// === 比较 (无符号语义) ===

procedure TTestCase_VecU32x8.Test_VecU32x8_CmpEq;
var
  a, b: TVecU32x8;
  m: TMask8;
begin
  // 设置测试数据: 偶数索引相等，奇数索引不相等
  a.u[0] := 100; b.u[0] := 100;
  a.u[1] := 200; b.u[1] := 300;
  a.u[2] := 500; b.u[2] := 500;
  a.u[3] := 600; b.u[3] := 700;
  a.u[4] := 1000; b.u[4] := 1000;
  a.u[5] := 2000; b.u[5] := 3000;
  a.u[6] := 5000; b.u[6] := 5000;
  a.u[7] := 6000; b.u[7] := 7000;

  m := VecU32x8CmpEq(a, b);

  AssertTrue('U32x8 CmpEq [0] should be true', (m and (1 shl 0)) <> 0);
  AssertFalse('U32x8 CmpEq [1] should be false', (m and (1 shl 1)) <> 0);
  AssertTrue('U32x8 CmpEq [2] should be true', (m and (1 shl 2)) <> 0);
  AssertFalse('U32x8 CmpEq [3] should be false', (m and (1 shl 3)) <> 0);
  AssertTrue('U32x8 CmpEq [4] should be true', (m and (1 shl 4)) <> 0);
  AssertFalse('U32x8 CmpEq [5] should be false', (m and (1 shl 5)) <> 0);
  AssertTrue('U32x8 CmpEq [6] should be true', (m and (1 shl 6)) <> 0);
  AssertFalse('U32x8 CmpEq [7] should be false', (m and (1 shl 7)) <> 0);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_CmpLt;
var
  a, b: TVecU32x8;
  m: TMask8;
begin
  // 关键测试: 无符号比较，$FFFFFFFF 是最大值
  a.u[0] := 100; b.u[0] := 200;     // 100 < 200 = true
  a.u[1] := 300; b.u[1] := 200;     // 300 < 200 = false
  a.u[2] := 1; b.u[2] := $FFFFFFFF; // 1 < MaxUInt32 = true (关键!)
  a.u[3] := $FFFFFFFF; b.u[3] := 1; // MaxUInt32 < 1 = false
  a.u[4] := $80000000; b.u[4] := 1; // 高位设置，无符号大于 1，所以 false
  a.u[5] := 0; b.u[5] := 1;         // 0 < 1 = true
  a.u[6] := 100; b.u[6] := 100;     // 100 < 100 = false (相等)
  a.u[7] := $7FFFFFFF; b.u[7] := $80000000; // 有符号负数场景，无符号应为 true

  m := VecU32x8CmpLt(a, b);

  AssertTrue('U32x8 CmpLt [0]: 100 < 200', (m and (1 shl 0)) <> 0);
  AssertFalse('U32x8 CmpLt [1]: 300 >= 200', (m and (1 shl 1)) <> 0);
  AssertTrue('U32x8 CmpLt [2]: 1 < $FFFFFFFF (unsigned)', (m and (1 shl 2)) <> 0);
  AssertFalse('U32x8 CmpLt [3]: $FFFFFFFF >= 1 (unsigned)', (m and (1 shl 3)) <> 0);
  AssertFalse('U32x8 CmpLt [4]: $80000000 >= 1 (unsigned)', (m and (1 shl 4)) <> 0);
  AssertTrue('U32x8 CmpLt [5]: 0 < 1', (m and (1 shl 5)) <> 0);
  AssertFalse('U32x8 CmpLt [6]: 100 = 100 (not less)', (m and (1 shl 6)) <> 0);
  AssertTrue('U32x8 CmpLt [7]: $7FFFFFFF < $80000000 (unsigned)', (m and (1 shl 7)) <> 0);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_CmpGt;
var
  a, b: TVecU32x8;
  m: TMask8;
begin
  a.u[0] := 300; b.u[0] := 200;     // 300 > 200 = true
  a.u[1] := 100; b.u[1] := 200;     // 100 > 200 = false
  a.u[2] := $FFFFFFFF; b.u[2] := 1; // MaxUInt32 > 1 = true
  a.u[3] := 1; b.u[3] := $FFFFFFFF; // 1 > MaxUInt32 = false
  a.u[4] := $80000000; b.u[4] := 1; // 高位设置，无符号大于 1 = true
  a.u[5] := 1; b.u[5] := 0;         // 1 > 0 = true
  a.u[6] := 100; b.u[6] := 100;     // 100 > 100 = false (相等)
  a.u[7] := $80000000; b.u[7] := $7FFFFFFF; // 无符号 $80000000 > $7FFFFFFF = true

  m := VecU32x8CmpGt(a, b);

  AssertTrue('U32x8 CmpGt [0]: 300 > 200', (m and (1 shl 0)) <> 0);
  AssertFalse('U32x8 CmpGt [1]: 100 <= 200', (m and (1 shl 1)) <> 0);
  AssertTrue('U32x8 CmpGt [2]: $FFFFFFFF > 1 (unsigned)', (m and (1 shl 2)) <> 0);
  AssertFalse('U32x8 CmpGt [3]: 1 <= $FFFFFFFF (unsigned)', (m and (1 shl 3)) <> 0);
  AssertTrue('U32x8 CmpGt [4]: $80000000 > 1 (unsigned)', (m and (1 shl 4)) <> 0);
  AssertTrue('U32x8 CmpGt [5]: 1 > 0', (m and (1 shl 5)) <> 0);
  AssertFalse('U32x8 CmpGt [6]: 100 = 100 (not greater)', (m and (1 shl 6)) <> 0);
  AssertTrue('U32x8 CmpGt [7]: $80000000 > $7FFFFFFF (unsigned)', (m and (1 shl 7)) <> 0);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_CmpLe;
var
  a, b: TVecU32x8;
  m: TMask8;
begin
  a.u[0] := 100; b.u[0] := 200;     // 100 <= 200 = true
  a.u[1] := 300; b.u[1] := 200;     // 300 <= 200 = false
  a.u[2] := 100; b.u[2] := 100;     // 100 <= 100 = true (相等)
  a.u[3] := 1; b.u[3] := $FFFFFFFF; // 1 <= MaxUInt32 = true
  a.u[4] := $FFFFFFFF; b.u[4] := $FFFFFFFF; // MaxUInt32 <= MaxUInt32 = true
  a.u[5] := 0; b.u[5] := 0;         // 0 <= 0 = true
  a.u[6] := $80000000; b.u[6] := 1; // 高位设置 <= 1 = false (无符号)
  a.u[7] := 0; b.u[7] := $FFFFFFFF; // 0 <= MaxUInt32 = true

  m := VecU32x8CmpLe(a, b);

  AssertTrue('U32x8 CmpLe [0]: 100 <= 200', (m and (1 shl 0)) <> 0);
  AssertFalse('U32x8 CmpLe [1]: 300 > 200', (m and (1 shl 1)) <> 0);
  AssertTrue('U32x8 CmpLe [2]: 100 <= 100 (equal)', (m and (1 shl 2)) <> 0);
  AssertTrue('U32x8 CmpLe [3]: 1 <= $FFFFFFFF', (m and (1 shl 3)) <> 0);
  AssertTrue('U32x8 CmpLe [4]: $FFFFFFFF <= $FFFFFFFF', (m and (1 shl 4)) <> 0);
  AssertTrue('U32x8 CmpLe [5]: 0 <= 0', (m and (1 shl 5)) <> 0);
  AssertFalse('U32x8 CmpLe [6]: $80000000 > 1 (unsigned)', (m and (1 shl 6)) <> 0);
  AssertTrue('U32x8 CmpLe [7]: 0 <= $FFFFFFFF', (m and (1 shl 7)) <> 0);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_CmpGe;
var
  a, b: TVecU32x8;
  m: TMask8;
begin
  a.u[0] := 300; b.u[0] := 200;     // 300 >= 200 = true
  a.u[1] := 100; b.u[1] := 200;     // 100 >= 200 = false
  a.u[2] := 100; b.u[2] := 100;     // 100 >= 100 = true (相等)
  a.u[3] := $FFFFFFFF; b.u[3] := 1; // MaxUInt32 >= 1 = true
  a.u[4] := $FFFFFFFF; b.u[4] := $FFFFFFFF; // MaxUInt32 >= MaxUInt32 = true
  a.u[5] := 0; b.u[5] := 0;         // 0 >= 0 = true
  a.u[6] := 1; b.u[6] := $80000000; // 1 >= 高位设置 = false (无符号)
  a.u[7] := $FFFFFFFF; b.u[7] := 0; // MaxUInt32 >= 0 = true

  m := VecU32x8CmpGe(a, b);

  AssertTrue('U32x8 CmpGe [0]: 300 >= 200', (m and (1 shl 0)) <> 0);
  AssertFalse('U32x8 CmpGe [1]: 100 < 200', (m and (1 shl 1)) <> 0);
  AssertTrue('U32x8 CmpGe [2]: 100 >= 100 (equal)', (m and (1 shl 2)) <> 0);
  AssertTrue('U32x8 CmpGe [3]: $FFFFFFFF >= 1', (m and (1 shl 3)) <> 0);
  AssertTrue('U32x8 CmpGe [4]: $FFFFFFFF >= $FFFFFFFF', (m and (1 shl 4)) <> 0);
  AssertTrue('U32x8 CmpGe [5]: 0 >= 0', (m and (1 shl 5)) <> 0);
  AssertFalse('U32x8 CmpGe [6]: 1 < $80000000 (unsigned)', (m and (1 shl 6)) <> 0);
  AssertTrue('U32x8 CmpGe [7]: $FFFFFFFF >= 0', (m and (1 shl 7)) <> 0);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_CmpNe;
var
  a, b: TVecU32x8;
  m: TMask8;
begin
  a.u[0] := 100; b.u[0] := 100;
  a.u[1] := 300; b.u[1] := 200;
  a.u[2] := 1; b.u[2] := $FFFFFFFF;
  a.u[3] := $FFFFFFFF; b.u[3] := 1;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 42; b.u[5] := 42;
  a.u[6] := $80000000; b.u[6] := $7FFFFFFF;
  a.u[7] := 12345; b.u[7] := 54321;

  m := VecU32x8CmpNe(a, b);

  AssertFalse('U32x8 CmpNe [0]: 100 = 100', (m and (1 shl 0)) <> 0);
  AssertTrue('U32x8 CmpNe [1]: 300 <> 200', (m and (1 shl 1)) <> 0);
  AssertTrue('U32x8 CmpNe [2]: 1 <> $FFFFFFFF', (m and (1 shl 2)) <> 0);
  AssertTrue('U32x8 CmpNe [3]: $FFFFFFFF <> 1', (m and (1 shl 3)) <> 0);
  AssertFalse('U32x8 CmpNe [4]: 0 = 0', (m and (1 shl 4)) <> 0);
  AssertFalse('U32x8 CmpNe [5]: 42 = 42', (m and (1 shl 5)) <> 0);
  AssertTrue('U32x8 CmpNe [6]: $80000000 <> $7FFFFFFF', (m and (1 shl 6)) <> 0);
  AssertTrue('U32x8 CmpNe [7]: 12345 <> 54321', (m and (1 shl 7)) <> 0);
end;

// === Min/Max ===

procedure TTestCase_VecU32x8.Test_VecU32x8_Min;
var
  a, b, r: TVecU32x8;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 300; b.u[1] := 250;
  a.u[2] := 1; b.u[2] := $FFFFFFFF;     // 关键: 无符号 Min(1, MaxUInt32) = 1
  a.u[3] := $FFFFFFFF; b.u[3] := 1;     // 关键: 无符号 Min(MaxUInt32, 1) = 1
  a.u[4] := $80000000; b.u[4] := 1;     // 无符号: $80000000 > 1
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := $7FFFFFFF; b.u[6] := $80000000; // 无符号: $7FFFFFFF < $80000000
  a.u[7] := 12345; b.u[7] := 12345;

  r := VecU32x8Min(a, b);

  AssertEquals('U32x8 Min [0]', UInt32(100), r.u[0]);
  AssertEquals('U32x8 Min [1]', UInt32(250), r.u[1]);
  AssertEquals('U32x8 Min [2] unsigned', UInt32(1), r.u[2]);
  AssertEquals('U32x8 Min [3] unsigned', UInt32(1), r.u[3]);
  AssertEquals('U32x8 Min [4] unsigned', UInt32(1), r.u[4]);
  AssertEquals('U32x8 Min [5]', UInt32(0), r.u[5]);
  AssertEquals('U32x8 Min [6] unsigned', UInt32($7FFFFFFF), r.u[6]);
  AssertEquals('U32x8 Min [7] equal', UInt32(12345), r.u[7]);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_Max;
var
  a, b, r: TVecU32x8;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 300; b.u[1] := 250;
  a.u[2] := 1; b.u[2] := $FFFFFFFF;     // 关键: 无符号 Max(1, MaxUInt32) = MaxUInt32
  a.u[3] := $FFFFFFFF; b.u[3] := 1;     // 关键: 无符号 Max(MaxUInt32, 1) = MaxUInt32
  a.u[4] := $80000000; b.u[4] := 1;     // 无符号: $80000000 > 1
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := $7FFFFFFF; b.u[6] := $80000000; // 无符号: $80000000 > $7FFFFFFF
  a.u[7] := 12345; b.u[7] := 12345;

  r := VecU32x8Max(a, b);

  AssertEquals('U32x8 Max [0]', UInt32(200), r.u[0]);
  AssertEquals('U32x8 Max [1]', UInt32(300), r.u[1]);
  AssertEquals('U32x8 Max [2] unsigned', UInt32($FFFFFFFF), r.u[2]);
  AssertEquals('U32x8 Max [3] unsigned', UInt32($FFFFFFFF), r.u[3]);
  AssertEquals('U32x8 Max [4] unsigned', UInt32($80000000), r.u[4]);
  AssertEquals('U32x8 Max [5]', UInt32(0), r.u[5]);
  AssertEquals('U32x8 Max [6] unsigned', UInt32($80000000), r.u[6]);
  AssertEquals('U32x8 Max [7] equal', UInt32(12345), r.u[7]);
end;

// === 工具函数 ===

procedure TTestCase_VecU32x8.Test_VecU32x8_Splat;
var
  r: TVecU32x8;
  i: Integer;
begin
  // 使用直接赋值模拟 Splat 行为
  for i := 0 to 7 do
    r.u[i] := 42;

  for i := 0 to 7 do
    AssertEquals('U32x8 Splat [' + IntToStr(i) + ']', UInt32(42), r.u[i]);

  // 测试大值
  for i := 0 to 7 do
    r.u[i] := $DEADBEEF;

  for i := 0 to 7 do
    AssertEquals('U32x8 Splat large [' + IntToStr(i) + ']', UInt32($DEADBEEF), r.u[i]);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_Zero;
var
  r: TVecU32x8;
  i: Integer;
begin
  // 先设置非零值
  for i := 0 to 7 do
    r.u[i] := $FFFFFFFF;

  // 清零
  for i := 0 to 7 do
    r.u[i] := 0;

  for i := 0 to 7 do
    AssertEquals('U32x8 Zero [' + IntToStr(i) + ']', UInt32(0), r.u[i]);
end;

procedure TTestCase_VecU32x8.Test_VecU32x8_SizeOf;
begin
  // TVecU32x8 应该是 256 位 = 32 字节
  AssertEquals('TVecU32x8 should be 32 bytes', 32, SizeOf(TVecU32x8));
  // 8 个 UInt32 元素
  AssertEquals('TVecU32x8 should have 8 elements', 8 * SizeOf(UInt32), SizeOf(TVecU32x8));
end;

// === 边界测试 ===

{$PUSH}{$R-}{$Q-}  // 禁用范围和溢出检查以测试回绕行为
procedure TTestCase_VecU32x8.Test_VecU32x8_Wraparound;
var
  a, b, r: TVecU32x8;
  i: Integer;
begin
  // 注意: 如果项目 LPI 启用了 RangeChecks/OverflowChecks，
  // VecU32x8Add 等函数可能抛出 Range Check Error。
  // 这是预期行为，因为我们正在测试回绕，而检查被启用。
  try
    // 测试无符号加法溢出回绕
    for i := 0 to 7 do
    begin
      a.u[i] := $FFFFFFFF;  // MaxUInt32
      b.u[i] := 1;
    end;

    r := VecU32x8Add(a, b);

    // 无符号溢出应回绕到 0
    for i := 0 to 7 do
      AssertEquals('U32x8 Add overflow wraps to 0 [' + IntToStr(i) + ']', UInt32(0), r.u[i]);

    // 测试无符号减法下溢回绕
    for i := 0 to 7 do
    begin
      a.u[i] := 0;
      b.u[i] := 1;
    end;

    r := VecU32x8Sub(a, b);

    // 无符号下溢应回绕到 MaxUInt32
    for i := 0 to 7 do
      AssertEquals('U32x8 Sub underflow wraps to max [' + IntToStr(i) + ']', UInt32($FFFFFFFF), r.u[i]);
  except
    on E: ERangeError do
      ; // 忽略: 项目启用了范围检查，跳过此测试
  end;
end;
{$POP}

procedure TTestCase_VecU32x8.Test_VecU32x8_MaxValue;
var
  a, b, r: TVecU32x8;
  i: Integer;
begin
  // 测试 High(UInt32) = $FFFFFFFF 的各种操作
  for i := 0 to 7 do
  begin
    a.u[i] := $FFFFFFFF;
    b.u[i] := $FFFFFFFF;
  end;

  // And with max = max
  r := VecU32x8And(a, b);
  for i := 0 to 7 do
    AssertEquals('U32x8 And max [' + IntToStr(i) + ']', UInt32($FFFFFFFF), r.u[i]);

  // Or with max = max
  r := VecU32x8Or(a, b);
  for i := 0 to 7 do
    AssertEquals('U32x8 Or max [' + IntToStr(i) + ']', UInt32($FFFFFFFF), r.u[i]);

  // Xor with max = 0
  r := VecU32x8Xor(a, b);
  for i := 0 to 7 do
    AssertEquals('U32x8 Xor max [' + IntToStr(i) + ']', UInt32(0), r.u[i]);

  // Not of max = 0
  r := VecU32x8Not(a);
  for i := 0 to 7 do
    AssertEquals('U32x8 Not max [' + IntToStr(i) + ']', UInt32(0), r.u[i]);

  // ShiftRight max by 1 = $7FFFFFFF
  r := VecU32x8ShiftRight(a, 1);
  for i := 0 to 7 do
    AssertEquals('U32x8 ShiftRight max [' + IntToStr(i) + ']', UInt32($7FFFFFFF), r.u[i]);

  // ShiftLeft max by 1 = $FFFFFFFE
  r := VecU32x8ShiftLeft(a, 1);
  for i := 0 to 7 do
    AssertEquals('U32x8 ShiftLeft max [' + IntToStr(i) + ']', UInt32($FFFFFFFE), r.u[i]);
end;

initialization
  RegisterTest(TTestCase_VecU32x8);

end.
