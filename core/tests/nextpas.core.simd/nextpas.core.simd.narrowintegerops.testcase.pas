unit nextpas.core.simd.narrowintegerops.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  Classes, nextpas.core.text.conv, nextpas.core.test, nextpas.core.simd,
  nextpas.core.simd.testcase, nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

type
  // ✅ 窄整数向量完整测试 - I16x8, I8x16, U32x4, U16x8, U8x16
  TTestCase_NarrowIntegerOps = class(TScalarBackendStatefulTestCase)
  published
    // === I16x8 (8×Int16) 测试 ===
    // I16x8 算术测试
    procedure Test_VecI16x8_Add_Basic;
    procedure Test_VecI16x8_Add_Overflow;
    procedure Test_VecI16x8_Sub_Basic;
    procedure Test_VecI16x8_Sub_Underflow;
    procedure Test_VecI16x8_Mul_Basic;
    procedure Test_VecI16x8_Mul_Overflow;

    // I16x8 位运算测试
    procedure Test_VecI16x8_And_Basic;
    procedure Test_VecI16x8_Or_Basic;
    procedure Test_VecI16x8_Xor_Basic;
    procedure Test_VecI16x8_Not_Basic;
    procedure Test_VecI16x8_AndNot_Basic;

    // I16x8 移位测试
    procedure Test_VecI16x8_ShiftLeft_Basic;
    procedure Test_VecI16x8_ShiftLeft_Zero;
    procedure Test_VecI16x8_ShiftLeft_Large;
    procedure Test_VecI16x8_ShiftRight_Basic;
    procedure Test_VecI16x8_ShiftRightArith_Negative;

    // I16x8 比较测试
    procedure Test_VecI16x8_CmpEq_AllSame;
    procedure Test_VecI16x8_CmpEq_Mixed;
    procedure Test_VecI16x8_CmpLt_Basic;
    procedure Test_VecI16x8_CmpLt_Boundary;
    procedure Test_VecI16x8_CmpGt_Basic;
    procedure Test_DispatchI16x8_CmpLe_Basic;
    procedure Test_DispatchI16x8_CmpGe_Basic;
    procedure Test_DispatchI16x8_CmpNe_Basic;

    // I16x8 最小最大测试
    procedure Test_VecI16x8_Min_Basic;
    procedure Test_VecI16x8_Min_Negative;
    procedure Test_VecI16x8_Max_Basic;
    procedure Test_VecI16x8_Max_Negative;

    // === I8x16 (16×Int8) 测试 ===
    // I8x16 算术测试
    procedure Test_VecI8x16_Add_Basic;
    procedure Test_VecI8x16_Add_Overflow;
    procedure Test_VecI8x16_Sub_Basic;
    procedure Test_VecI8x16_Sub_Underflow;

    // I8x16 位运算测试
    procedure Test_VecI8x16_And_Basic;
    procedure Test_VecI8x16_Or_Basic;
    procedure Test_VecI8x16_Xor_Basic;
    procedure Test_VecI8x16_Not_Basic;
    procedure Test_VecI8x16_AndNot_Basic;

    // I8x16 比较测试
    procedure Test_VecI8x16_CmpEq_AllSame;
    procedure Test_VecI8x16_CmpEq_Mixed;
    procedure Test_VecI8x16_CmpLt_Basic;
    procedure Test_VecI8x16_CmpGt_Basic;
    procedure Test_DispatchI8x16_CmpLe_Basic;
    procedure Test_DispatchI8x16_CmpGe_Basic;
    procedure Test_DispatchI8x16_CmpNe_Basic;

    // I8x16 最小最大测试
    procedure Test_VecI8x16_Min_Basic;
    procedure Test_VecI8x16_Max_Basic;

    // === U32x4 (4×UInt32) 测试 ===
    // U32x4 算术测试
    procedure Test_VecU32x4_Add_Basic;
    procedure Test_VecU32x4_Add_Overflow;
    procedure Test_VecU32x4_Sub_Basic;
    procedure Test_VecU32x4_Sub_Underflow;
    procedure Test_VecU32x4_Mul_Basic;
    procedure Test_VecU32x4_Mul_Large;

    // U32x4 位运算测试
    procedure Test_VecU32x4_And_Basic;
    procedure Test_VecU32x4_Or_Basic;
    procedure Test_VecU32x4_Xor_Basic;
    procedure Test_VecU32x4_Not_Basic;
    procedure Test_VecU32x4_AndNot_Basic;

    // U32x4 移位测试
    procedure Test_VecU32x4_ShiftLeft_Basic;
    procedure Test_VecU32x4_ShiftRight_Basic;
    procedure Test_VecU32x4_ShiftRight_HighBit;

    // U32x4 比较测试 (关键: 无符号比较!)
    procedure Test_VecU32x4_CmpEq_Basic;
    procedure Test_VecU32x4_CmpLt_Unsigned;
    procedure Test_VecU32x4_CmpLt_LargeValues;
    procedure Test_VecU32x4_CmpGt_Unsigned;
    procedure Test_VecU32x4_CmpLe_Unsigned;
    procedure Test_VecU32x4_CmpGe_Unsigned;

    // U32x4 最小最大测试
    procedure Test_VecU32x4_Min_Basic;
    procedure Test_VecU32x4_Min_LargeValues;
    procedure Test_VecU32x4_Max_Basic;
    procedure Test_VecU32x4_Max_LargeValues;

    // === U16x8 (8×UInt16) 测试 ===
    // U16x8 算术测试
    procedure Test_VecU16x8_Add_Basic;
    procedure Test_VecU16x8_Add_Overflow;
    procedure Test_VecU16x8_Sub_Basic;
    procedure Test_VecU16x8_Sub_Underflow;

    // U16x8 位运算测试
    procedure Test_VecU16x8_And_Basic;
    procedure Test_VecU16x8_Or_Basic;
    procedure Test_VecU16x8_Xor_Basic;
    procedure Test_VecU16x8_Not_Basic;
    procedure Test_VecU16x8_AndNot_Basic;

    // U16x8 移位测试
    procedure Test_VecU16x8_ShiftLeft_Basic;
    procedure Test_VecU16x8_ShiftRight_Basic;
    procedure Test_VecU16x8_ShiftRight_HighBit;

    // U16x8 比较测试 (关键: 无符号比较!)
    procedure Test_VecU16x8_CmpEq_Basic;
    procedure Test_VecU16x8_CmpLt_Unsigned;
    procedure Test_VecU16x8_CmpLt_Boundary;
    procedure Test_VecU16x8_CmpGt_Unsigned;
    procedure Test_DispatchU16x8_CmpLe_Unsigned;
    procedure Test_DispatchU16x8_CmpGe_Unsigned;
    procedure Test_DispatchU16x8_CmpNe_Basic;

    // U16x8 最小最大测试
    procedure Test_VecU16x8_Min_Basic;
    procedure Test_VecU16x8_Max_Basic;

    // === U8x16 (16×UInt8) 测试 ===
    // U8x16 算术测试
    procedure Test_VecU8x16_Add_Basic;
    procedure Test_VecU8x16_Add_Overflow;
    procedure Test_VecU8x16_Sub_Basic;
    procedure Test_VecU8x16_Sub_Underflow;

    // U8x16 位运算测试
    procedure Test_VecU8x16_And_Basic;
    procedure Test_VecU8x16_Or_Basic;
    procedure Test_VecU8x16_Xor_Basic;
    procedure Test_VecU8x16_Not_Basic;
    procedure Test_VecU8x16_AndNot_Basic;

    // U8x16 比较测试 (关键: 无符号比较!)
    procedure Test_VecU8x16_CmpEq_Basic;
    procedure Test_VecU8x16_CmpLt_Unsigned;
    procedure Test_VecU8x16_CmpLt_Boundary;
    procedure Test_VecU8x16_CmpGt_Unsigned;
    procedure Test_DispatchU8x16_CmpLe_Unsigned;
    procedure Test_DispatchU8x16_CmpGe_Unsigned;
    procedure Test_DispatchU8x16_CmpNe_Basic;

    // U8x16 最小最大测试
    procedure Test_VecU8x16_Min_Basic;
    procedure Test_VecU8x16_Max_Basic;
  end;

implementation

{ TTestCase_NarrowIntegerOps }

// === I16x8 (8×Int16) 测试实现 ===

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Add_Basic;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := 1; a.i[1] := 2; a.i[2] := 3; a.i[3] := 4;
  a.i[4] := 5; a.i[5] := 6; a.i[6] := 7; a.i[7] := 8;
  b.i[0] := 10; b.i[1] := 20; b.i[2] := 30; b.i[3] := 40;
  b.i[4] := 50; b.i[5] := 60; b.i[6] := 70; b.i[7] := 80;

  r := VecI16x8Add(a, b);
  CheckEqual(11, r.i[0], 'I16x8 Add [0]');
  CheckEqual(22, r.i[1], 'I16x8 Add [1]');
  CheckEqual(88, r.i[7], 'I16x8 Add [7]');
end;

{$PUSH}{$R-}{$Q-} // 禁用 Range 和 Overflow 检查用于溢出测试
procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Add_Overflow;
var
  a, b, r: TVecI16x8;
begin
  // 测试正溢出行为
  a.i[0] := 32767; // MaxInt16
  b.i[0] := 1;
  a.i[1] := 32767;
  b.i[1] := 2;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8Add(a, b);
  // Int16 溢出会回绕到负数
  CheckEqual(Int16(-32768), r.i[0], 'I16x8 overflow wraps');
  CheckEqual(Int16(-32767), r.i[1], 'I16x8 overflow wraps');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Sub_Basic;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := 100; b.i[0] := 30;
  a.i[1] := 200; b.i[1] := 50;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8Sub(a, b);
  CheckEqual(70, r.i[0], 'I16x8 Sub [0]');
  CheckEqual(150, r.i[1], 'I16x8 Sub [1]');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Sub_Underflow;
var
  a, b, r: TVecI16x8;
begin
  // 测试负溢出行为
  a.i[0] := -32768; // MinInt16
  b.i[0] := 1;
  a.i[1] := 0; b.i[1] := 0;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8Sub(a, b);
  // Int16 下溢会回绕到正数
  CheckEqual(32767, r.i[0], 'I16x8 underflow wraps');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Mul_Basic;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := 10; b.i[0] := 5;
  a.i[1] := 20; b.i[1] := 3;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8Mul(a, b);
  CheckEqual(50, r.i[0], 'I16x8 Mul [0]');
  CheckEqual(60, r.i[1], 'I16x8 Mul [1]');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Mul_Overflow;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := 1000;
  b.i[0] := 100;
  a.i[1] := 0; b.i[1] := 0;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8Mul(a, b);
  // 1000 * 100 = 100000，超出 Int16 范围，会回绕
  // 100000 mod 65536 - 32768 = 34464 - 32768 = 1696
  CheckEqual(Int16(34464), r.i[0], 'I16x8 Mul overflow wraps');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_And_Basic;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := $00FF;
  b.i[0] := $0F0F;
  a.i[1] := 0; b.i[1] := 0;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8And(a, b);
  CheckEqual($000F, r.i[0], 'I16x8 And [0]');

  a.i[0] := Int16($AAAA); b.i[0] := $0FF0;
  a.i[1] := $1234; b.i[1] := $00FF;

  r := VecI16x8And(a, b);
  CheckEqual(Int16($0AA0), r.i[0], 'I16x8 And alt [0]');
  CheckEqual(Int16($0034), r.i[1], 'I16x8 And alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Or_Basic;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := $00FF;
  b.i[0] := $0F00;
  a.i[1] := 0; b.i[1] := 0;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8Or(a, b);
  CheckEqual($0FFF, r.i[0], 'I16x8 Or [0]');

  a.i[0] := $00F0; b.i[0] := $0F00;
  a.i[1] := $1200; b.i[1] := $0034;

  r := VecI16x8Or(a, b);
  CheckEqual(Int16($0FF0), r.i[0], 'I16x8 Or alt [0]');
  CheckEqual(Int16($1234), r.i[1], 'I16x8 Or alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Xor_Basic;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := Int16($FFFF);
  b.i[0] := $0F0F;
  a.i[1] := 0; b.i[1] := 0;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8Xor(a, b);
  CheckEqual(Int16($F0F0), r.i[0], 'I16x8 Xor [0]');

  a.i[0] := Int16($AAAA); b.i[0] := $0FF0;
  a.i[1] := $1234; b.i[1] := $00FF;

  r := VecI16x8Xor(a, b);
  CheckEqual(Int16($A55A), r.i[0], 'I16x8 Xor alt [0]');
  CheckEqual(Int16($12CB), r.i[1], 'I16x8 Xor alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Not_Basic;
var
  a, r: TVecI16x8;
begin
  a.i[0] := $0F0F;
  a.i[1] := 0;
  a.i[2] := 0;
  a.i[3] := 0;
  a.i[4] := 0;
  a.i[5] := 0;
  a.i[6] := 0;
  a.i[7] := 0;

  r := VecI16x8Not(a);
  CheckEqual(Int16($F0F0), r.i[0], 'I16x8 Not [0]');

  a.i[0] := Int16($AAAA);
  a.i[1] := 0;

  r := VecI16x8Not(a);
  CheckEqual(Int16($5555), r.i[0], 'I16x8 Not alt [0]');
  CheckEqual(Int16($FFFF), r.i[1], 'I16x8 Not alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_AndNot_Basic;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := $0F0F;
  b.i[0] := Int16($FFFF);
  a.i[1] := 0; b.i[1] := 0;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8AndNot(a, b);
  // AndNot(a, b) = (NOT a) AND b (与 PANDN 指令一致)
  // NOT(0x0F0F) = 0xF0F0
  // 0xF0F0 AND 0xFFFF = 0xF0F0
  CheckEqual(Int16($F0F0), r.i[0], 'I16x8 AndNot [0]');

  a.i[0] := $00FF; b.i[0] := $0FF0;
  a.i[1] := $0F0F; b.i[1] := $3333;

  r := VecI16x8AndNot(a, b);
  CheckEqual(Int16($0F00), r.i[0], 'I16x8 AndNot alt [0]');
  CheckEqual(Int16($3030), r.i[1], 'I16x8 AndNot alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_ShiftLeft_Basic;
var
  a, r: TVecI16x8;
begin
  a.i[0] := 1;
  a.i[1] := 2;
  a.i[2] := 0;
  a.i[3] := 0;
  a.i[4] := 0;
  a.i[5] := 0;
  a.i[6] := 0;
  a.i[7] := 0;

  r := VecI16x8ShiftLeft(a, 4);
  CheckEqual(16, r.i[0], 'I16x8 ShiftLeft [0]');
  CheckEqual(32, r.i[1], 'I16x8 ShiftLeft [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_ShiftLeft_Zero;
var
  a, r: TVecI16x8;
begin
  a.i[0] := 100;
  a.i[1] := 0;
  a.i[2] := 0;
  a.i[3] := 0;
  a.i[4] := 0;
  a.i[5] := 0;
  a.i[6] := 0;
  a.i[7] := 0;

  r := VecI16x8ShiftLeft(a, 0);
  CheckEqual(100, r.i[0], 'I16x8 ShiftLeft by 0');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_ShiftLeft_Large;
var
  a, r: TVecI16x8;
begin
  a.i[0] := 1;
  a.i[1] := 0;
  a.i[2] := 0;
  a.i[3] := 0;
  a.i[4] := 0;
  a.i[5] := 0;
  a.i[6] := 0;
  a.i[7] := 0;

  r := VecI16x8ShiftLeft(a, 15);
  CheckEqual(Int16(-32768), r.i[0], 'I16x8 ShiftLeft by 15');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_ShiftRight_Basic;
var
  a, r: TVecI16x8;
begin
  a.i[0] := 256;
  a.i[1] := 512;
  a.i[2] := 0;
  a.i[3] := 0;
  a.i[4] := 0;
  a.i[5] := 0;
  a.i[6] := 0;
  a.i[7] := 0;

  r := VecI16x8ShiftRight(a, 4);
  CheckEqual(16, r.i[0], 'I16x8 ShiftRight [0]');
  CheckEqual(32, r.i[1], 'I16x8 ShiftRight [1]');

  a.i[0] := Int16($8000);
  a.i[1] := Int16($F000);

  r := VecI16x8ShiftRight(a, 4);
  CheckEqual(Int16($0800), r.i[0], 'I16x8 ShiftRight alt [0]');
  CheckEqual(Int16($0F00), r.i[1], 'I16x8 ShiftRight alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_ShiftRightArith_Negative;
var
  a, r: TVecI16x8;
begin
  a.i[0] := -256;
  a.i[1] := 0;
  a.i[2] := 0;
  a.i[3] := 0;
  a.i[4] := 0;
  a.i[5] := 0;
  a.i[6] := 0;
  a.i[7] := 0;

  r := VecI16x8ShiftRightArith(a, 4);
  // 算术右移保留符号位
  CheckEqual(-16, r.i[0], 'I16x8 ShiftRightArith negative');

  a.i[0] := -1024;
  a.i[1] := 256;

  r := VecI16x8ShiftRightArith(a, 5);
  CheckEqual(-32, r.i[0], 'I16x8 ShiftRightArith alt [0]');
  CheckEqual(8, r.i[1], 'I16x8 ShiftRightArith alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_CmpEq_AllSame;
var
  a, b: TVecI16x8;
  m: TMask8;
begin
  a.i[0] := 100; b.i[0] := 100;
  a.i[1] := 200; b.i[1] := 200;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  m := VecI16x8CmpEq(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I16x8 CmpEq [0]');
  CheckTrue((m and (1 shl 1)) <> 0, 'I16x8 CmpEq [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_CmpEq_Mixed;
var
  a, b: TVecI16x8;
  m: TMask8;
begin
  a.i[0] := 100; b.i[0] := 100;
  a.i[1] := 200; b.i[1] := 300;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  m := VecI16x8CmpEq(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I16x8 CmpEq [0] should be true');
  CheckFalse((m and (1 shl 1)) <> 0, 'I16x8 CmpEq [1] should be false');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_CmpLt_Basic;
var
  a, b: TVecI16x8;
  m: TMask8;
begin
  a.i[0] := 10; b.i[0] := 20;
  a.i[1] := 30; b.i[1] := 20;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  m := VecI16x8CmpLt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I16x8 CmpLt [0]: 10 < 20');
  CheckFalse((m and (1 shl 1)) <> 0, 'I16x8 CmpLt [1]: 30 >= 20');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_CmpLt_Boundary;
var
  a, b: TVecI16x8;
  m: TMask8;
begin
  a.i[0] := -32768; b.i[0] := 32767;
  a.i[1] := 0; b.i[1] := -1;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  m := VecI16x8CmpLt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I16x8 CmpLt: MinInt16 < MaxInt16');
  CheckFalse((m and (1 shl 1)) <> 0, 'I16x8 CmpLt: 0 >= -1');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_CmpGt_Basic;
var
  a, b: TVecI16x8;
  m: TMask8;
begin
  a.i[0] := 30; b.i[0] := 20;
  a.i[1] := 10; b.i[1] := 20;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  m := VecI16x8CmpGt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I16x8 CmpGt [0]: 30 > 20');
  CheckFalse((m and (1 shl 1)) <> 0, 'I16x8 CmpGt [1]: 10 <= 20');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchI16x8_CmpLe_Basic;
var
  a, b: TVecI16x8;
  LDispatch: PSimdDispatchTable;
  m: TMask8;
begin
  a.i[0] := 10; b.i[0] := 20;
  a.i[1] := 20; b.i[1] := 20;
  a.i[2] := 30; b.i[2] := 20;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for I16x8 CmpLe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLeI16x8), 'Dispatch CmpLeI16x8 should be assigned');
  m := LDispatch^.CoreVectors.CmpLeI16x8(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I16x8 CmpLe [0]: 10 <= 20');
  CheckTrue((m and (1 shl 1)) <> 0, 'I16x8 CmpLe [1]: 20 <= 20');
  CheckFalse((m and (1 shl 2)) <> 0, 'I16x8 CmpLe [2]: 30 > 20');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchI16x8_CmpGe_Basic;
var
  a, b: TVecI16x8;
  LDispatch: PSimdDispatchTable;
  m: TMask8;
begin
  a.i[0] := 30; b.i[0] := 20;
  a.i[1] := 20; b.i[1] := 20;
  a.i[2] := 10; b.i[2] := 20;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for I16x8 CmpGe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGeI16x8), 'Dispatch CmpGeI16x8 should be assigned');
  m := LDispatch^.CoreVectors.CmpGeI16x8(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I16x8 CmpGe [0]: 30 >= 20');
  CheckTrue((m and (1 shl 1)) <> 0, 'I16x8 CmpGe [1]: 20 >= 20');
  CheckFalse((m and (1 shl 2)) <> 0, 'I16x8 CmpGe [2]: 10 < 20');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchI16x8_CmpNe_Basic;
var
  a, b: TVecI16x8;
  LDispatch: PSimdDispatchTable;
  m: TMask8;
begin
  a.i[0] := 10; b.i[0] := 20;
  a.i[1] := 20; b.i[1] := 20;
  a.i[2] := -1; b.i[2] := 1;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for I16x8 CmpNe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpNeI16x8), 'Dispatch CmpNeI16x8 should be assigned');
  m := LDispatch^.CoreVectors.CmpNeI16x8(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I16x8 CmpNe [0]: 10 <> 20');
  CheckFalse((m and (1 shl 1)) <> 0, 'I16x8 CmpNe [1]: 20 = 20');
  CheckTrue((m and (1 shl 2)) <> 0, 'I16x8 CmpNe [2]: -1 <> 1');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Min_Basic;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := 10; b.i[0] := 20;
  a.i[1] := 30; b.i[1] := 25;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8Min(a, b);
  CheckEqual(10, r.i[0], 'I16x8 Min [0]');
  CheckEqual(25, r.i[1], 'I16x8 Min [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Min_Negative;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := -10; b.i[0] := -20;
  a.i[1] := -5; b.i[1] := 10;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8Min(a, b);
  CheckEqual(-20, r.i[0], 'I16x8 Min [0] negative');
  CheckEqual(-5, r.i[1], 'I16x8 Min [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Max_Basic;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := 10; b.i[0] := 20;
  a.i[1] := 30; b.i[1] := 25;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8Max(a, b);
  CheckEqual(20, r.i[0], 'I16x8 Max [0]');
  CheckEqual(30, r.i[1], 'I16x8 Max [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI16x8_Max_Negative;
var
  a, b, r: TVecI16x8;
begin
  a.i[0] := -10; b.i[0] := -20;
  a.i[1] := -5; b.i[1] := 10;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;

  r := VecI16x8Max(a, b);
  CheckEqual(-10, r.i[0], 'I16x8 Max [0] negative');
  CheckEqual(10, r.i[1], 'I16x8 Max [1]');
end;

// === I8x16 (16×Int8) 测试实现 ===

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_Add_Basic;
var
  a, b, r: TVecI8x16;
begin
  a.i[0] := 10; b.i[0] := 20;
  a.i[1] := 30; b.i[1] := 40;
  a.i[2] := 0; b.i[2] := 0;
  a.i[3] := 0; b.i[3] := 0;
  a.i[4] := 0; b.i[4] := 0;
  a.i[5] := 0; b.i[5] := 0;
  a.i[6] := 0; b.i[6] := 0;
  a.i[7] := 0; b.i[7] := 0;
  a.i[8] := 0; b.i[8] := 0;
  a.i[9] := 0; b.i[9] := 0;
  a.i[10] := 0; b.i[10] := 0;
  a.i[11] := 0; b.i[11] := 0;
  a.i[12] := 0; b.i[12] := 0;
  a.i[13] := 0; b.i[13] := 0;
  a.i[14] := 0; b.i[14] := 0;
  a.i[15] := 0; b.i[15] := 0;

  r := VecI8x16Add(a, b);
  CheckEqual(30, r.i[0], 'I8x16 Add [0]');
  CheckEqual(70, r.i[1], 'I8x16 Add [1]');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_Add_Overflow;
var
  a, b, r: TVecI8x16;
  i: Integer;
begin
  a.i[0] := 127; // MaxInt8
  b.i[0] := 1;
  for i := 1 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  r := VecI8x16Add(a, b);
  // Int8 溢出回绕到负数
  CheckEqual(Int8(-128), r.i[0], 'I8x16 overflow wraps');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_Sub_Basic;
var
  a, b, r: TVecI8x16;
  i: Integer;
begin
  a.i[0] := 50; b.i[0] := 20;
  a.i[1] := 100; b.i[1] := 30;
  for i := 2 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  r := VecI8x16Sub(a, b);
  CheckEqual(30, r.i[0], 'I8x16 Sub [0]');
  CheckEqual(70, r.i[1], 'I8x16 Sub [1]');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_Sub_Underflow;
var
  a, b, r: TVecI8x16;
  i: Integer;
begin
  a.i[0] := -128; // MinInt8
  b.i[0] := 1;
  for i := 1 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  r := VecI8x16Sub(a, b);
  // Int8 下溢回绕到正数
  CheckEqual(127, r.i[0], 'I8x16 underflow wraps');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_And_Basic;
var
  a, b, r: TVecI8x16;
  i: Integer;
begin
  a.i[0] := $0F;
  b.i[0] := $33;
  for i := 1 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  r := VecI8x16And(a, b);
  CheckEqual($03, r.i[0], 'I8x16 And [0]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_Or_Basic;
var
  a, b, r: TVecI8x16;
  i: Integer;
begin
  a.i[0] := $0F;
  b.i[0] := $30;
  for i := 1 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  r := VecI8x16Or(a, b);
  CheckEqual($3F, r.i[0], 'I8x16 Or [0]');

  a.i[0] := $55; b.i[0] := Int8($AA);
  a.i[1] := $0F; b.i[1] := Int8($F0);

  r := VecI8x16Or(a, b);
  CheckEqual(Int8($FF), r.i[0], 'I8x16 Or alt [0]');
  CheckEqual(Int8($FF), r.i[1], 'I8x16 Or alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_Xor_Basic;
var
  a, b, r: TVecI8x16;
  i: Integer;
begin
  a.i[0] := Int8($FF);
  b.i[0] := $0F;
  for i := 1 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  r := VecI8x16Xor(a, b);
  CheckEqual(Int8($F0), r.i[0], 'I8x16 Xor [0]');

  a.i[0] := $55; b.i[0] := Int8($AA);
  a.i[1] := $0F; b.i[1] := Int8($F0);

  r := VecI8x16Xor(a, b);
  CheckEqual(Int8($FF), r.i[0], 'I8x16 Xor alt [0]');
  CheckEqual(Int8($FF), r.i[1], 'I8x16 Xor alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_Not_Basic;
var
  a, r: TVecI8x16;
  i: Integer;
begin
  a.i[0] := $0F;
  for i := 1 to 15 do
    a.i[i] := 0;

  r := VecI8x16Not(a);
  CheckEqual(Int8($F0), r.i[0], 'I8x16 Not [0]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_AndNot_Basic;
var
  a, b, r: TVecI8x16;
  LIndex: Integer;
begin
  a.i[0] := $0F;
  b.i[0] := -1;
  for LIndex := 1 to 15 do
  begin
    a.i[LIndex] := 0;
    b.i[LIndex] := 0;
  end;

  r := VecI8x16AndNot(a, b);
  CheckEqual(Int8($F0), r.i[0], 'I8x16 AndNot [0]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_CmpEq_AllSame;
var
  a, b: TVecI8x16;
  m: TMask16;
  i: Integer;
begin
  a.i[0] := 42; b.i[0] := 42;
  a.i[1] := -10; b.i[1] := -10;
  for i := 2 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  m := VecI8x16CmpEq(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I8x16 CmpEq [0]');
  CheckTrue((m and (1 shl 1)) <> 0, 'I8x16 CmpEq [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_CmpEq_Mixed;
var
  a, b: TVecI8x16;
  m: TMask16;
  i: Integer;
begin
  a.i[0] := 42; b.i[0] := 42;
  a.i[1] := 10; b.i[1] := 20;
  for i := 2 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  m := VecI8x16CmpEq(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I8x16 CmpEq [0] should be true');
  CheckFalse((m and (1 shl 1)) <> 0, 'I8x16 CmpEq [1] should be false');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_CmpLt_Basic;
var
  a, b: TVecI8x16;
  m: TMask16;
  i: Integer;
begin
  a.i[0] := 10; b.i[0] := 20;
  a.i[1] := 30; b.i[1] := 20;
  for i := 2 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  m := VecI8x16CmpLt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I8x16 CmpLt [0]: 10 < 20');
  CheckFalse((m and (1 shl 1)) <> 0, 'I8x16 CmpLt [1]: 30 >= 20');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_CmpGt_Basic;
var
  a, b: TVecI8x16;
  m: TMask16;
  i: Integer;
begin
  a.i[0] := 30; b.i[0] := 20;
  a.i[1] := 10; b.i[1] := 20;
  for i := 2 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  m := VecI8x16CmpGt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I8x16 CmpGt [0]: 30 > 20');
  CheckFalse((m and (1 shl 1)) <> 0, 'I8x16 CmpGt [1]: 10 <= 20');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchI8x16_CmpLe_Basic;
var
  a, b: TVecI8x16;
  LDispatch: PSimdDispatchTable;
  m: TMask16;
  LIndex: Integer;
begin
  a.i[0] := 10; b.i[0] := 20;
  a.i[1] := 20; b.i[1] := 20;
  a.i[2] := 30; b.i[2] := 20;
  for LIndex := 3 to 15 do
  begin
    a.i[LIndex] := 0;
    b.i[LIndex] := 0;
  end;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for I8x16 CmpLe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLeI8x16), 'Dispatch CmpLeI8x16 should be assigned');
  m := LDispatch^.CoreVectors.CmpLeI8x16(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I8x16 CmpLe [0]: 10 <= 20');
  CheckTrue((m and (1 shl 1)) <> 0, 'I8x16 CmpLe [1]: 20 <= 20');
  CheckFalse((m and (1 shl 2)) <> 0, 'I8x16 CmpLe [2]: 30 > 20');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchI8x16_CmpGe_Basic;
var
  a, b: TVecI8x16;
  LDispatch: PSimdDispatchTable;
  m: TMask16;
  LIndex: Integer;
begin
  a.i[0] := 30; b.i[0] := 20;
  a.i[1] := 20; b.i[1] := 20;
  a.i[2] := 10; b.i[2] := 20;
  for LIndex := 3 to 15 do
  begin
    a.i[LIndex] := 0;
    b.i[LIndex] := 0;
  end;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for I8x16 CmpGe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGeI8x16), 'Dispatch CmpGeI8x16 should be assigned');
  m := LDispatch^.CoreVectors.CmpGeI8x16(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I8x16 CmpGe [0]: 30 >= 20');
  CheckTrue((m and (1 shl 1)) <> 0, 'I8x16 CmpGe [1]: 20 >= 20');
  CheckFalse((m and (1 shl 2)) <> 0, 'I8x16 CmpGe [2]: 10 < 20');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchI8x16_CmpNe_Basic;
var
  a, b: TVecI8x16;
  LDispatch: PSimdDispatchTable;
  m: TMask16;
  LIndex: Integer;
begin
  a.i[0] := 10; b.i[0] := 20;
  a.i[1] := 20; b.i[1] := 20;
  a.i[2] := -1; b.i[2] := 1;
  for LIndex := 3 to 15 do
  begin
    a.i[LIndex] := 0;
    b.i[LIndex] := 0;
  end;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for I8x16 CmpNe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpNeI8x16), 'Dispatch CmpNeI8x16 should be assigned');
  m := LDispatch^.CoreVectors.CmpNeI8x16(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'I8x16 CmpNe [0]: 10 <> 20');
  CheckFalse((m and (1 shl 1)) <> 0, 'I8x16 CmpNe [1]: 20 = 20');
  CheckTrue((m and (1 shl 2)) <> 0, 'I8x16 CmpNe [2]: -1 <> 1');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_Min_Basic;
var
  a, b, r: TVecI8x16;
  i: Integer;
begin
  a.i[0] := 10; b.i[0] := 20;
  a.i[1] := 30; b.i[1] := 25;
  for i := 2 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  r := VecI8x16Min(a, b);
  CheckEqual(10, r.i[0], 'I8x16 Min [0]');
  CheckEqual(25, r.i[1], 'I8x16 Min [1]');

  a.i[0] := -10; b.i[0] := -20;
  a.i[1] := 127; b.i[1] := -1;

  r := VecI8x16Min(a, b);
  CheckEqual(-20, r.i[0], 'I8x16 Min alt [0]');
  CheckEqual(-1, r.i[1], 'I8x16 Min alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecI8x16_Max_Basic;
var
  a, b, r: TVecI8x16;
  i: Integer;
begin
  a.i[0] := 10; b.i[0] := 20;
  a.i[1] := 30; b.i[1] := 25;
  for i := 2 to 15 do
  begin
    a.i[i] := 0;
    b.i[i] := 0;
  end;

  r := VecI8x16Max(a, b);
  CheckEqual(20, r.i[0], 'I8x16 Max [0]');
  CheckEqual(30, r.i[1], 'I8x16 Max [1]');

  a.i[0] := -10; b.i[0] := -20;
  a.i[1] := 127; b.i[1] := -1;

  r := VecI8x16Max(a, b);
  CheckEqual(-10, r.i[0], 'I8x16 Max alt [0]');
  CheckEqual(127, r.i[1], 'I8x16 Max alt [1]');
end;

// === U32x4 (4×UInt32) 测试实现 ===

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Add_Basic;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 1000; b.u[1] := 2000;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Add(a, b);
  CheckEqual(UInt32(300), r.u[0], 'U32x4 Add [0]');
  CheckEqual(UInt32(3000), r.u[1], 'U32x4 Add [1]');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Add_Overflow;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := $FFFFFFFF; // MaxUInt32
  b.u[0] := 1;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Add(a, b);
  // UInt32 溢出回绕到 0
  CheckEqual(UInt32(0), r.u[0], 'U32x4 overflow wraps to 0');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Sub_Basic;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := 300; b.u[0] := 100;
  a.u[1] := 5000; b.u[1] := 2000;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Sub(a, b);
  CheckEqual(UInt32(200), r.u[0], 'U32x4 Sub [0]');
  CheckEqual(UInt32(3000), r.u[1], 'U32x4 Sub [1]');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Sub_Underflow;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := 0;
  b.u[0] := 1;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Sub(a, b);
  // UInt32 下溢回绕到 MaxUInt32
  CheckEqual(UInt32($FFFFFFFF), r.u[0], 'U32x4 underflow wraps to max');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Mul_Basic;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := 10; b.u[0] := 20;
  a.u[1] := 100; b.u[1] := 50;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Mul(a, b);
  CheckEqual(UInt32(200), r.u[0], 'U32x4 Mul [0]');
  CheckEqual(UInt32(5000), r.u[1], 'U32x4 Mul [1]');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Mul_Large;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := $10000;
  b.u[0] := $10000;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Mul(a, b);
  // $10000 * $10000 = $100000000 (溢出，取低32位 = 0)
  CheckEqual(UInt32(0), r.u[0], 'U32x4 Mul overflow');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_And_Basic;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := $00FF00FF;
  b.u[0] := $0F0F0F0F;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4And(a, b);
  CheckEqual(UInt32($000F000F), r.u[0], 'U32x4 And [0]');

  a.u[0] := UInt32($FFFF0000);
  b.u[0] := UInt32($0F0F0F0F);
  a.u[1] := UInt32($12345678);
  b.u[1] := UInt32($00FF00FF);

  r := VecU32x4And(a, b);
  CheckEqual(UInt32($0F0F0000), r.u[0], 'U32x4 And alt [0]');
  CheckEqual(UInt32($00340078), r.u[1], 'U32x4 And alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Or_Basic;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := $00FF0000;
  b.u[0] := $000000FF;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Or(a, b);
  CheckEqual(UInt32($00FF00FF), r.u[0], 'U32x4 Or [0]');

  a.u[0] := UInt32($F0F00000);
  b.u[0] := UInt32($0F0F00FF);
  a.u[1] := UInt32($12000000);
  b.u[1] := UInt32($00000034);

  r := VecU32x4Or(a, b);
  CheckEqual(UInt32($FFFF00FF), r.u[0], 'U32x4 Or alt [0]');
  CheckEqual(UInt32($12000034), r.u[1], 'U32x4 Or alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Xor_Basic;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := $FFFFFFFF;
  b.u[0] := $0F0F0F0F;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Xor(a, b);
  CheckEqual(UInt32($F0F0F0F0), r.u[0], 'U32x4 Xor [0]');

  a.u[0] := UInt32($AAAAAAAA);
  b.u[0] := UInt32($0FF00FF0);
  a.u[1] := UInt32($12345678);
  b.u[1] := UInt32($00FF00FF);

  r := VecU32x4Xor(a, b);
  CheckEqual(UInt32($A55AA55A), r.u[0], 'U32x4 Xor alt [0]');
  CheckEqual(UInt32($12CB5687), r.u[1], 'U32x4 Xor alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Not_Basic;
var
  a, r: TVecU32x4;
begin
  a.u[0] := $0F0F0F0F;
  a.u[1] := 0;
  a.u[2] := 0;
  a.u[3] := 0;

  r := VecU32x4Not(a);
  CheckEqual(UInt32($F0F0F0F0), r.u[0], 'U32x4 Not [0]');

  a.u[0] := 0;
  a.u[1] := UInt32($AAAAAAAA);

  r := VecU32x4Not(a);
  CheckEqual(UInt32($FFFFFFFF), r.u[0], 'U32x4 Not alt [0]');
  CheckEqual(UInt32($55555555), r.u[1], 'U32x4 Not alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_AndNot_Basic;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := $0F0F0F0F;
  b.u[0] := $FFFFFFFF;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4AndNot(a, b);
  CheckEqual(UInt32($F0F0F0F0), r.u[0], 'U32x4 AndNot [0]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_ShiftLeft_Basic;
var
  a, r: TVecU32x4;
begin
  a.u[0] := 1;
  a.u[1] := 2;
  a.u[2] := 0;
  a.u[3] := 0;

  r := VecU32x4ShiftLeft(a, 8);
  CheckEqual(UInt32(256), r.u[0], 'U32x4 ShiftLeft [0]');
  CheckEqual(UInt32(512), r.u[1], 'U32x4 ShiftLeft [1]');

  a.u[0] := UInt32($80000000);
  a.u[1] := 3;

  r := VecU32x4ShiftLeft(a, 4);
  CheckEqual(UInt32(0), r.u[0], 'U32x4 ShiftLeft alt [0]');
  CheckEqual(UInt32(48), r.u[1], 'U32x4 ShiftLeft alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_ShiftRight_Basic;
var
  a, r: TVecU32x4;
begin
  a.u[0] := 256;
  a.u[1] := 512;
  a.u[2] := 0;
  a.u[3] := 0;

  r := VecU32x4ShiftRight(a, 4);
  CheckEqual(UInt32(16), r.u[0], 'U32x4 ShiftRight [0]');
  CheckEqual(UInt32(32), r.u[1], 'U32x4 ShiftRight [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_ShiftRight_HighBit;
var
  a, r: TVecU32x4;
begin
  a.u[0] := $80000000;
  a.u[1] := 0;
  a.u[2] := 0;
  a.u[3] := 0;

  r := VecU32x4ShiftRight(a, 1);
  // 逻辑右移不保留符号位
  CheckEqual(UInt32($40000000), r.u[0], 'U32x4 ShiftRight high bit');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_CmpEq_Basic;
var
  a, b: TVecU32x4;
  m: TMask4;
begin
  a.u[0] := 100; b.u[0] := 100;
  a.u[1] := 200; b.u[1] := 300;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  m := VecU32x4CmpEq(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U32x4 CmpEq [0] should be true');
  CheckFalse((m and (1 shl 1)) <> 0, 'U32x4 CmpEq [1] should be false');

  a.u[0] := 1; b.u[0] := 2;
  a.u[1] := UInt32($FFFFFFFF); b.u[1] := UInt32($FFFFFFFF);
  a.u[2] := 42; b.u[2] := 42;
  a.u[3] := 7; b.u[3] := 8;

  m := VecU32x4CmpEq(a, b);
  CheckEqual(6, Integer(m), 'U32x4 CmpEq alt mask');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_CmpLt_Unsigned;
var
  a, b: TVecU32x4;
  m: TMask4;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 300; b.u[1] := 200;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  m := VecU32x4CmpLt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U32x4 CmpLt [0]: 100 < 200');
  CheckFalse((m and (1 shl 1)) <> 0, 'U32x4 CmpLt [1]: 300 >= 200');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_CmpLt_LargeValues;
var
  a, b: TVecU32x4;
  m: TMask4;
begin
  // 关键测试: 无符号比较 0xFFFFFFFF > 0x00000001
  a.u[0] := 1;
  b.u[0] := $FFFFFFFF;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  m := VecU32x4CmpLt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U32x4 CmpLt unsigned: 1 < 0xFFFFFFFF');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_CmpGt_Unsigned;
var
  a, b: TVecU32x4;
  m: TMask4;
begin
  a.u[0] := 300; b.u[0] := 200;
  a.u[1] := 100; b.u[1] := 200;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  m := VecU32x4CmpGt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U32x4 CmpGt [0]: 300 > 200');
  CheckFalse((m and (1 shl 1)) <> 0, 'U32x4 CmpGt [1]: 100 <= 200');

  a.u[0] := UInt32($FFFFFFFF); b.u[0] := 1;
  a.u[1] := 0; b.u[1] := UInt32($FFFFFFFF);
  a.u[2] := 500; b.u[2] := 400;
  a.u[3] := 7; b.u[3] := 7;

  m := VecU32x4CmpGt(a, b);
  CheckEqual(5, Integer(m), 'U32x4 CmpGt alt mask');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_CmpLe_Unsigned;
var
  a, b: TVecU32x4;
  m: TMask4;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := $FFFFFFFF; b.u[1] := $FFFFFFFF;
  a.u[2] := $FFFFFFFF; b.u[2] := 1;
  a.u[3] := 0; b.u[3] := 0;

  m := VecU32x4CmpLe(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U32x4 CmpLe [0]: 100 <= 200');
  CheckTrue((m and (1 shl 1)) <> 0, 'U32x4 CmpLe [1]: MaxUInt32 <= MaxUInt32');
  CheckFalse((m and (1 shl 2)) <> 0, 'U32x4 CmpLe [2]: MaxUInt32 > 1');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_CmpGe_Unsigned;
var
  a, b: TVecU32x4;
  m: TMask4;
begin
  a.u[0] := 300; b.u[0] := 200;
  a.u[1] := $FFFFFFFF; b.u[1] := $FFFFFFFF;
  a.u[2] := 1; b.u[2] := $FFFFFFFF;
  a.u[3] := 0; b.u[3] := 0;

  m := VecU32x4CmpGe(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U32x4 CmpGe [0]: 300 >= 200');
  CheckTrue((m and (1 shl 1)) <> 0, 'U32x4 CmpGe [1]: MaxUInt32 >= MaxUInt32');
  CheckFalse((m and (1 shl 2)) <> 0, 'U32x4 CmpGe [2]: 1 < MaxUInt32');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Min_Basic;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 300; b.u[1] := 250;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Min(a, b);
  CheckEqual(UInt32(100), r.u[0], 'U32x4 Min [0]');
  CheckEqual(UInt32(250), r.u[1], 'U32x4 Min [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Min_LargeValues;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := 1;
  b.u[0] := $FFFFFFFF;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Min(a, b);
  CheckEqual(UInt32(1), r.u[0], 'U32x4 Min unsigned');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Max_Basic;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 300; b.u[1] := 250;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Max(a, b);
  CheckEqual(UInt32(200), r.u[0], 'U32x4 Max [0]');
  CheckEqual(UInt32(300), r.u[1], 'U32x4 Max [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU32x4_Max_LargeValues;
var
  a, b, r: TVecU32x4;
begin
  a.u[0] := 1;
  b.u[0] := $FFFFFFFF;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;

  r := VecU32x4Max(a, b);
  CheckEqual(UInt32($FFFFFFFF), r.u[0], 'U32x4 Max unsigned');
end;

// === U16x8 (8×UInt16) 测试实现 ===

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_Add_Basic;
var
  a, b, r: TVecU16x8;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 1000; b.u[1] := 2000;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  r := VecU16x8Add(a, b);
  CheckEqual(UInt16(300), r.u[0], 'U16x8 Add [0]');
  CheckEqual(UInt16(3000), r.u[1], 'U16x8 Add [1]');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_Add_Overflow;
var
  a, b, r: TVecU16x8;
begin
  a.u[0] := 65535; // MaxUInt16
  b.u[0] := 1;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  r := VecU16x8Add(a, b);
  // UInt16 溢出回绕到 0
  CheckEqual(UInt16(0), r.u[0], 'U16x8 overflow wraps to 0');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_Sub_Basic;
var
  a, b, r: TVecU16x8;
begin
  a.u[0] := 300; b.u[0] := 100;
  a.u[1] := 5000; b.u[1] := 2000;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  r := VecU16x8Sub(a, b);
  CheckEqual(UInt16(200), r.u[0], 'U16x8 Sub [0]');
  CheckEqual(UInt16(3000), r.u[1], 'U16x8 Sub [1]');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_Sub_Underflow;
var
  a, b, r: TVecU16x8;
begin
  a.u[0] := 0;
  b.u[0] := 1;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  r := VecU16x8Sub(a, b);
  // UInt16 下溢回绕到 MaxUInt16
  CheckEqual(UInt16(65535), r.u[0], 'U16x8 underflow wraps to max');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_And_Basic;
var
  a, b, r: TVecU16x8;
begin
  a.u[0] := $00FF;
  b.u[0] := $0F0F;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  r := VecU16x8And(a, b);
  CheckEqual(UInt16($000F), r.u[0], 'U16x8 And [0]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_Or_Basic;
var
  a, b, r: TVecU16x8;
begin
  a.u[0] := $00FF;
  b.u[0] := $0F00;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  r := VecU16x8Or(a, b);
  CheckEqual(UInt16($0FFF), r.u[0], 'U16x8 Or [0]');

  a.u[0] := $00F0; b.u[0] := $0F00;
  a.u[1] := $1234; b.u[1] := $00FF;

  r := VecU16x8Or(a, b);
  CheckEqual(UInt16($0FF0), r.u[0], 'U16x8 Or alt [0]');
  CheckEqual(UInt16($12FF), r.u[1], 'U16x8 Or alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_Xor_Basic;
var
  a, b, r: TVecU16x8;
begin
  a.u[0] := $FFFF;
  b.u[0] := $0F0F;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  r := VecU16x8Xor(a, b);
  CheckEqual(UInt16($F0F0), r.u[0], 'U16x8 Xor [0]');

  a.u[0] := $AAAA; b.u[0] := $0FF0;
  a.u[1] := $1234; b.u[1] := $00FF;

  r := VecU16x8Xor(a, b);
  CheckEqual(UInt16($A55A), r.u[0], 'U16x8 Xor alt [0]');
  CheckEqual(UInt16($12CB), r.u[1], 'U16x8 Xor alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_Not_Basic;
var
  a, r: TVecU16x8;
begin
  a.u[0] := $0F0F;
  a.u[1] := 0;
  a.u[2] := 0;
  a.u[3] := 0;
  a.u[4] := 0;
  a.u[5] := 0;
  a.u[6] := 0;
  a.u[7] := 0;

  r := VecU16x8Not(a);
  CheckEqual(UInt16($F0F0), r.u[0], 'U16x8 Not [0]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_AndNot_Basic;
var
  a, b, r: TVecU16x8;
begin
  a.u[0] := $0F0F;
  b.u[0] := $FFFF;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  r := VecU16x8AndNot(a, b);
  CheckEqual(UInt16($F0F0), r.u[0], 'U16x8 AndNot [0]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_ShiftLeft_Basic;
var
  a, r: TVecU16x8;
begin
  a.u[0] := 1;
  a.u[1] := 2;
  a.u[2] := 0;
  a.u[3] := 0;
  a.u[4] := 0;
  a.u[5] := 0;
  a.u[6] := 0;
  a.u[7] := 0;

  r := VecU16x8ShiftLeft(a, 4);
  CheckEqual(UInt16(16), r.u[0], 'U16x8 ShiftLeft [0]');
  CheckEqual(UInt16(32), r.u[1], 'U16x8 ShiftLeft [1]');

  a.u[0] := $00FF;
  a.u[1] := $8000;

  r := VecU16x8ShiftLeft(a, 4);
  CheckEqual(UInt16($0FF0), r.u[0], 'U16x8 ShiftLeft alt [0]');
  CheckEqual(UInt16(0), r.u[1], 'U16x8 ShiftLeft alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_ShiftRight_Basic;
var
  a, r: TVecU16x8;
begin
  a.u[0] := 256;
  a.u[1] := 512;
  a.u[2] := 0;
  a.u[3] := 0;
  a.u[4] := 0;
  a.u[5] := 0;
  a.u[6] := 0;
  a.u[7] := 0;

  r := VecU16x8ShiftRight(a, 4);
  CheckEqual(UInt16(16), r.u[0], 'U16x8 ShiftRight [0]');
  CheckEqual(UInt16(32), r.u[1], 'U16x8 ShiftRight [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_ShiftRight_HighBit;
var
  a, r: TVecU16x8;
begin
  a.u[0] := $8000;
  a.u[1] := 0;
  a.u[2] := 0;
  a.u[3] := 0;
  a.u[4] := 0;
  a.u[5] := 0;
  a.u[6] := 0;
  a.u[7] := 0;

  r := VecU16x8ShiftRight(a, 1);
  // 逻辑右移不保留符号位
  CheckEqual(UInt16($4000), r.u[0], 'U16x8 ShiftRight high bit');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_CmpEq_Basic;
var
  a, b: TVecU16x8;
  m: TMask8;
begin
  a.u[0] := 100; b.u[0] := 100;
  a.u[1] := 200; b.u[1] := 300;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  m := VecU16x8CmpEq(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U16x8 CmpEq [0] should be true');
  CheckFalse((m and (1 shl 1)) <> 0, 'U16x8 CmpEq [1] should be false');

  a.u[0] := 1; b.u[0] := 2;
  a.u[1] := 65535; b.u[1] := 65535;
  a.u[2] := 42; b.u[2] := 42;
  a.u[3] := 7; b.u[3] := 8;
  a.u[4] := 10; b.u[4] := 20;
  a.u[5] := 30; b.u[5] := 40;
  a.u[6] := 50; b.u[6] := 60;
  a.u[7] := 70; b.u[7] := 80;

  m := VecU16x8CmpEq(a, b);
  CheckEqual(6, Integer(m), 'U16x8 CmpEq alt mask');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_CmpLt_Unsigned;
var
  a, b: TVecU16x8;
  m: TMask8;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 300; b.u[1] := 200;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  m := VecU16x8CmpLt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U16x8 CmpLt [0]: 100 < 200');
  CheckFalse((m and (1 shl 1)) <> 0, 'U16x8 CmpLt [1]: 300 >= 200');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_CmpLt_Boundary;
var
  a, b: TVecU16x8;
  m: TMask8;
begin
  // 关键测试: 无符号比较 0xFFFF > 0x0001
  a.u[0] := 1;
  b.u[0] := 65535;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  m := VecU16x8CmpLt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U16x8 CmpLt unsigned: 1 < 65535');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_CmpGt_Unsigned;
var
  a, b: TVecU16x8;
  m: TMask8;
begin
  a.u[0] := 300; b.u[0] := 200;
  a.u[1] := 100; b.u[1] := 200;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  m := VecU16x8CmpGt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U16x8 CmpGt [0]: 300 > 200');
  CheckFalse((m and (1 shl 1)) <> 0, 'U16x8 CmpGt [1]: 100 <= 200');

  a.u[0] := 65535; b.u[0] := 1;
  a.u[1] := 0; b.u[1] := 0;
  a.u[2] := 123; b.u[2] := 456;
  a.u[3] := 500; b.u[3] := 400;

  m := VecU16x8CmpGt(a, b);
  CheckEqual(9, Integer(m), 'U16x8 CmpGt alt mask');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchU16x8_CmpLe_Unsigned;
var
  a, b: TVecU16x8;
  LDispatch: PSimdDispatchTable;
  m: TMask8;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 65535; b.u[1] := 65535;
  a.u[2] := 65535; b.u[2] := 1;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for U16x8 CmpLe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLeU16x8), 'Dispatch CmpLeU16x8 should be assigned');
  m := LDispatch^.CoreVectors.CmpLeU16x8(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U16x8 CmpLe [0]: 100 <= 200');
  CheckTrue((m and (1 shl 1)) <> 0, 'U16x8 CmpLe [1]: 65535 <= 65535');
  CheckFalse((m and (1 shl 2)) <> 0, 'U16x8 CmpLe [2]: 65535 > 1');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchU16x8_CmpGe_Unsigned;
var
  a, b: TVecU16x8;
  LDispatch: PSimdDispatchTable;
  m: TMask8;
begin
  a.u[0] := 300; b.u[0] := 200;
  a.u[1] := 65535; b.u[1] := 65535;
  a.u[2] := 1; b.u[2] := 65535;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for U16x8 CmpGe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGeU16x8), 'Dispatch CmpGeU16x8 should be assigned');
  m := LDispatch^.CoreVectors.CmpGeU16x8(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U16x8 CmpGe [0]: 300 >= 200');
  CheckTrue((m and (1 shl 1)) <> 0, 'U16x8 CmpGe [1]: 65535 >= 65535');
  CheckFalse((m and (1 shl 2)) <> 0, 'U16x8 CmpGe [2]: 1 < 65535');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchU16x8_CmpNe_Basic;
var
  a, b: TVecU16x8;
  LDispatch: PSimdDispatchTable;
  m: TMask8;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 65535; b.u[1] := 65535;
  a.u[2] := 1; b.u[2] := 65535;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for U16x8 CmpNe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpNeU16x8), 'Dispatch CmpNeU16x8 should be assigned');
  m := LDispatch^.CoreVectors.CmpNeU16x8(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U16x8 CmpNe [0]: 100 <> 200');
  CheckFalse((m and (1 shl 1)) <> 0, 'U16x8 CmpNe [1]: 65535 = 65535');
  CheckTrue((m and (1 shl 2)) <> 0, 'U16x8 CmpNe [2]: 1 <> 65535');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_Min_Basic;
var
  a, b, r: TVecU16x8;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 300; b.u[1] := 250;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  r := VecU16x8Min(a, b);
  CheckEqual(UInt16(100), r.u[0], 'U16x8 Min [0]');
  CheckEqual(UInt16(250), r.u[1], 'U16x8 Min [1]');

  a.u[0] := 0; b.u[0] := 65535;
  a.u[1] := 1024; b.u[1] := 512;

  r := VecU16x8Min(a, b);
  CheckEqual(UInt16(0), r.u[0], 'U16x8 Min alt [0]');
  CheckEqual(UInt16(512), r.u[1], 'U16x8 Min alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU16x8_Max_Basic;
var
  a, b, r: TVecU16x8;
begin
  a.u[0] := 100; b.u[0] := 200;
  a.u[1] := 300; b.u[1] := 250;
  a.u[2] := 0; b.u[2] := 0;
  a.u[3] := 0; b.u[3] := 0;
  a.u[4] := 0; b.u[4] := 0;
  a.u[5] := 0; b.u[5] := 0;
  a.u[6] := 0; b.u[6] := 0;
  a.u[7] := 0; b.u[7] := 0;

  r := VecU16x8Max(a, b);
  CheckEqual(UInt16(200), r.u[0], 'U16x8 Max [0]');
  CheckEqual(UInt16(300), r.u[1], 'U16x8 Max [1]');

  a.u[0] := 0; b.u[0] := 65535;
  a.u[1] := 1024; b.u[1] := 512;

  r := VecU16x8Max(a, b);
  CheckEqual(UInt16(65535), r.u[0], 'U16x8 Max alt [0]');
  CheckEqual(UInt16(1024), r.u[1], 'U16x8 Max alt [1]');
end;

// === U8x16 (16×UInt8) 测试实现 ===

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_Add_Basic;
var
  a, b, r: TVecU8x16;
  i: Integer;
begin
  a.u[0] := 10; b.u[0] := 20;
  a.u[1] := 30; b.u[1] := 40;
  for i := 2 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  r := VecU8x16Add(a, b);
  CheckEqual(Byte(30), r.u[0], 'U8x16 Add [0]');
  CheckEqual(Byte(70), r.u[1], 'U8x16 Add [1]');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_Add_Overflow;
var
  a, b, r: TVecU8x16;
  i: Integer;
begin
  a.u[0] := 255; // MaxUInt8
  b.u[0] := 1;
  for i := 1 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  r := VecU8x16Add(a, b);
  // UInt8 溢出回绕到 0
  CheckEqual(Byte(0), r.u[0], 'U8x16 overflow wraps to 0');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_Sub_Basic;
var
  a, b, r: TVecU8x16;
  i: Integer;
begin
  a.u[0] := 50; b.u[0] := 20;
  a.u[1] := 100; b.u[1] := 30;
  for i := 2 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  r := VecU8x16Sub(a, b);
  CheckEqual(Byte(30), r.u[0], 'U8x16 Sub [0]');
  CheckEqual(Byte(70), r.u[1], 'U8x16 Sub [1]');
end;

{$PUSH}{$R-}{$Q-}
procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_Sub_Underflow;
var
  a, b, r: TVecU8x16;
  i: Integer;
begin
  a.u[0] := 0;
  b.u[0] := 1;
  for i := 1 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  r := VecU8x16Sub(a, b);
  // UInt8 下溢回绕到 MaxUInt8
  CheckEqual(Byte(255), r.u[0], 'U8x16 underflow wraps to max');
end;
{$POP}

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_And_Basic;
var
  a, b, r: TVecU8x16;
  i: Integer;
begin
  a.u[0] := $0F;
  b.u[0] := $33;
  for i := 1 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  r := VecU8x16And(a, b);
  CheckEqual(Byte($03), r.u[0], 'U8x16 And [0]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_Or_Basic;
var
  a, b, r: TVecU8x16;
  i: Integer;
begin
  a.u[0] := $0F;
  b.u[0] := $30;
  for i := 1 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  r := VecU8x16Or(a, b);
  CheckEqual(Byte($3F), r.u[0], 'U8x16 Or [0]');

  a.u[0] := $55; b.u[0] := $AA;
  a.u[1] := $0F; b.u[1] := $F0;

  r := VecU8x16Or(a, b);
  CheckEqual(Byte($FF), r.u[0], 'U8x16 Or alt [0]');
  CheckEqual(Byte($FF), r.u[1], 'U8x16 Or alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_Xor_Basic;
var
  a, b, r: TVecU8x16;
  i: Integer;
begin
  a.u[0] := $FF;
  b.u[0] := $0F;
  for i := 1 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  r := VecU8x16Xor(a, b);
  CheckEqual(Byte($F0), r.u[0], 'U8x16 Xor [0]');

  a.u[0] := $55; b.u[0] := $AA;
  a.u[1] := $0F; b.u[1] := $F0;

  r := VecU8x16Xor(a, b);
  CheckEqual(Byte($FF), r.u[0], 'U8x16 Xor alt [0]');
  CheckEqual(Byte($FF), r.u[1], 'U8x16 Xor alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_Not_Basic;
var
  a, r: TVecU8x16;
  i: Integer;
begin
  a.u[0] := $0F;
  for i := 1 to 15 do
    a.u[i] := 0;

  r := VecU8x16Not(a);
  CheckEqual(Byte($F0), r.u[0], 'U8x16 Not [0]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_AndNot_Basic;
var
  a, b, r: TVecU8x16;
  LIndex: Integer;
begin
  a.u[0] := $0F;
  b.u[0] := $FF;
  for LIndex := 1 to 15 do
  begin
    a.u[LIndex] := 0;
    b.u[LIndex] := 0;
  end;

  r := VecU8x16AndNot(a, b);
  CheckEqual(Byte($F0), r.u[0], 'U8x16 AndNot [0]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_CmpEq_Basic;
var
  a, b: TVecU8x16;
  m: TMask16;
  i: Integer;
begin
  a.u[0] := 42; b.u[0] := 42;
  a.u[1] := 10; b.u[1] := 20;
  for i := 2 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  m := VecU8x16CmpEq(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U8x16 CmpEq [0] should be true');
  CheckFalse((m and (1 shl 1)) <> 0, 'U8x16 CmpEq [1] should be false');

  a.u[0] := 1; b.u[0] := 2;
  a.u[1] := 255; b.u[1] := 255;
  a.u[2] := 42; b.u[2] := 42;
  a.u[3] := 7; b.u[3] := 8;
  for i := 4 to 15 do
  begin
    a.u[i] := i;
    b.u[i] := i + 100;
  end;

  m := VecU8x16CmpEq(a, b);
  CheckEqual(6, Integer(m), 'U8x16 CmpEq alt mask');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_CmpLt_Unsigned;
var
  a, b: TVecU8x16;
  m: TMask16;
  i: Integer;
begin
  a.u[0] := 10; b.u[0] := 20;
  a.u[1] := 30; b.u[1] := 20;
  for i := 2 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  m := VecU8x16CmpLt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U8x16 CmpLt [0]: 10 < 20');
  CheckFalse((m and (1 shl 1)) <> 0, 'U8x16 CmpLt [1]: 30 >= 20');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_CmpLt_Boundary;
var
  a, b: TVecU8x16;
  m: TMask16;
  i: Integer;
begin
  // 关键测试: 无符号比较 0xFF > 0x01
  a.u[0] := 1;
  b.u[0] := 255;
  for i := 1 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  m := VecU8x16CmpLt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U8x16 CmpLt unsigned: 1 < 255');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_CmpGt_Unsigned;
var
  a, b: TVecU8x16;
  m: TMask16;
  i: Integer;
begin
  a.u[0] := 30; b.u[0] := 20;
  a.u[1] := 10; b.u[1] := 20;
  for i := 2 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  m := VecU8x16CmpGt(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U8x16 CmpGt [0]: 30 > 20');
  CheckFalse((m and (1 shl 1)) <> 0, 'U8x16 CmpGt [1]: 10 <= 20');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchU8x16_CmpLe_Unsigned;
var
  a, b: TVecU8x16;
  LDispatch: PSimdDispatchTable;
  m: TMask16;
  LIndex: Integer;
begin
  a.u[0] := 10; b.u[0] := 20;
  a.u[1] := 255; b.u[1] := 255;
  a.u[2] := 255; b.u[2] := 1;
  for LIndex := 3 to 15 do
  begin
    a.u[LIndex] := 0;
    b.u[LIndex] := 0;
  end;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for U8x16 CmpLe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpLeU8x16), 'Dispatch CmpLeU8x16 should be assigned');
  m := LDispatch^.CoreVectors.CmpLeU8x16(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U8x16 CmpLe [0]: 10 <= 20');
  CheckTrue((m and (1 shl 1)) <> 0, 'U8x16 CmpLe [1]: 255 <= 255');
  CheckFalse((m and (1 shl 2)) <> 0, 'U8x16 CmpLe [2]: 255 > 1');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchU8x16_CmpGe_Unsigned;
var
  a, b: TVecU8x16;
  LDispatch: PSimdDispatchTable;
  m: TMask16;
  LIndex: Integer;
begin
  a.u[0] := 30; b.u[0] := 20;
  a.u[1] := 255; b.u[1] := 255;
  a.u[2] := 1; b.u[2] := 255;
  for LIndex := 3 to 15 do
  begin
    a.u[LIndex] := 0;
    b.u[LIndex] := 0;
  end;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for U8x16 CmpGe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpGeU8x16), 'Dispatch CmpGeU8x16 should be assigned');
  m := LDispatch^.CoreVectors.CmpGeU8x16(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U8x16 CmpGe [0]: 30 >= 20');
  CheckTrue((m and (1 shl 1)) <> 0, 'U8x16 CmpGe [1]: 255 >= 255');
  CheckFalse((m and (1 shl 2)) <> 0, 'U8x16 CmpGe [2]: 1 < 255');
end;

procedure TTestCase_NarrowIntegerOps.Test_DispatchU8x16_CmpNe_Basic;
var
  a, b: TVecU8x16;
  LDispatch: PSimdDispatchTable;
  m: TMask16;
  LIndex: Integer;
begin
  a.u[0] := 10; b.u[0] := 20;
  a.u[1] := 255; b.u[1] := 255;
  a.u[2] := 1; b.u[2] := 255;
  for LIndex := 3 to 15 do
  begin
    a.u[LIndex] := 0;
    b.u[LIndex] := 0;
  end;

  LDispatch := GetDispatchTable;
  CheckTrue(Assigned(LDispatch), 'Dispatch table should be assigned for U8x16 CmpNe');
  CheckTrue(Assigned(LDispatch^.CoreVectors.CmpNeU8x16), 'Dispatch CmpNeU8x16 should be assigned');
  m := LDispatch^.CoreVectors.CmpNeU8x16(a, b);
  CheckTrue((m and (1 shl 0)) <> 0, 'U8x16 CmpNe [0]: 10 <> 20');
  CheckFalse((m and (1 shl 1)) <> 0, 'U8x16 CmpNe [1]: 255 = 255');
  CheckTrue((m and (1 shl 2)) <> 0, 'U8x16 CmpNe [2]: 1 <> 255');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_Min_Basic;
var
  a, b, r: TVecU8x16;
  i: Integer;
begin
  a.u[0] := 10; b.u[0] := 20;
  a.u[1] := 30; b.u[1] := 25;
  for i := 2 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  r := VecU8x16Min(a, b);
  CheckEqual(Byte(10), r.u[0], 'U8x16 Min [0]');
  CheckEqual(Byte(25), r.u[1], 'U8x16 Min [1]');

  a.u[0] := 0; b.u[0] := 255;
  a.u[1] := 200; b.u[1] := 199;

  r := VecU8x16Min(a, b);
  CheckEqual(Byte(0), r.u[0], 'U8x16 Min alt [0]');
  CheckEqual(Byte(199), r.u[1], 'U8x16 Min alt [1]');
end;

procedure TTestCase_NarrowIntegerOps.Test_VecU8x16_Max_Basic;
var
  a, b, r: TVecU8x16;
  i: Integer;
begin
  a.u[0] := 10; b.u[0] := 20;
  a.u[1] := 30; b.u[1] := 25;
  for i := 2 to 15 do
  begin
    a.u[i] := 0;
    b.u[i] := 0;
  end;

  r := VecU8x16Max(a, b);
  CheckEqual(Byte(20), r.u[0], 'U8x16 Max [0]');
  CheckEqual(Byte(30), r.u[1], 'U8x16 Max [1]');

  a.u[0] := 0; b.u[0] := 255;
  a.u[1] := 200; b.u[1] := 199;

  r := VecU8x16Max(a, b);
  CheckEqual(Byte(255), r.u[0], 'U8x16 Max alt [0]');
  CheckEqual(Byte(200), r.u[1], 'U8x16 Max alt [1]');
end;



end.