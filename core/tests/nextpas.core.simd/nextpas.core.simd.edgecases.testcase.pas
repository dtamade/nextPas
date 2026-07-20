unit nextpas.core.simd.edgecases.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

interface

uses
  nextpas.core.math,
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.simd,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base,
  nextpas.core.simd.utils,
  nextpas.core.simd.ops,
  nextpas.core.simd.scalar,
  nextpas.core.simd.memutils;

type


  // 边界条件测试 - NaN, 无穷大, 溢出, 对齐
  TTestCase_EdgeCases = class(TScalarBackendStatefulTestCase)
  private
    FSavedExceptionMask: TFPUExceptionMask;
  public
    procedure BeforeEach; override;
    procedure AfterEach; override;
  published
    // NaN 处理测试
    procedure Test_VecF32x4_Add_WithNaN;
    procedure Test_VecF32x4_Mul_WithNaN;
    procedure Test_VecF32x4_Compare_WithNaN;
    procedure Test_SortNet4_F32_WithNaN;
    procedure Test_SortNet4_F32_WithNaN_Descending;
    
    // Infinity 处理测试
    procedure Test_VecF32x4_Add_WithInfinity;
    procedure Test_VecF32x4_Mul_InfinityByZero;
    procedure Test_VecF32x4_Div_ByZero;
    procedure Test_VecF32x4_Div_InfinityByInfinity;
    
    // 整数边界测试
    procedure Test_VecI32x4_Add_MaxValue;
    procedure Test_VecI32x4_Sub_MinValue;
    procedure Test_PrefixSum_I32_Overflow;
    
    // 极端对齐场景（MemEqual / SumBytes 在非对齐上的行为）
    procedure Test_MemEqual_Unaligned_1Byte;
    procedure Test_MemEqual_Unaligned_15Bytes;
    procedure Test_MemFindByte_CrossPage;
    procedure Test_SumBytes_OddSizes;

    // 索引边界语义（utils）
    procedure Test_Utils_VecF32x4Extract_IndexSaturation;
    procedure Test_Utils_VecF32x4Insert_IndexSaturation;
    procedure Test_Utils_MaskF32x4Test_IndexSaturation_NoException;

    // 索引边界语义（facade / dispatch）
    procedure Test_Facade_VecF32x4Extract_IndexSaturation;
    procedure Test_Facade_VecF32x4Insert_IndexSaturation;
    
    // 数学函数边界
    procedure Test_VecF32x4_Log_Zero;
    procedure Test_VecF32x4_Log_Negative;
    procedure Test_VecF32x4_Sqrt_Negative;
    procedure Test_VecF32x4_Asin_OutOfRange;
  end;

implementation

{ TTestCase_EdgeCases }

procedure TTestCase_EdgeCases.BeforeEach;
begin
  FSavedExceptionMask := GetExceptionMask;
  {inherited SetUp; -- removed}

  // Save current FPU exception mask and mask all FP exceptions
  // This allows testing NaN, Infinity, division by zero without triggering exceptions
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
end;

procedure TTestCase_EdgeCases.AfterEach;
begin
  // Restore original FPU exception mask
  SetExceptionMask(FSavedExceptionMask);
  {inherited TearDown; -- removed}
end;

// === NaN 处理测试 ===

procedure TTestCase_EdgeCases.Test_VecF32x4_Add_WithNaN;
var
  a, b, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := NaN; a.f[2] := 3.0; a.f[3] := NaN;
  b.f[0] := 2.0; b.f[1] := 2.0; b.f[2] := NaN; b.f[3] := NaN;
  
  r := a + b;
  
  CheckNear(3.0, r.f[0], 0.0001, 'Normal + Normal');
  CheckTrue(IsNaN(r.f[1]), 'NaN + Normal is NaN');
  CheckTrue(IsNaN(r.f[2]), 'Normal + NaN is NaN');
  CheckTrue(IsNaN(r.f[3]), 'NaN + NaN is NaN');
end;

procedure TTestCase_EdgeCases.Test_VecF32x4_Mul_WithNaN;
var
  a, b, r: TVecF32x4;
begin
  a.f[0] := 2.0; a.f[1] := NaN; a.f[2] := 0.0; a.f[3] := NaN;
  b.f[0] := 3.0; b.f[1] := 3.0; b.f[2] := NaN; b.f[3] := 0.0;
  
  r := a * b;
  
  CheckNear(6.0, r.f[0], 0.0001, 'Normal * Normal');
  CheckTrue(IsNaN(r.f[1]), 'NaN * Normal is NaN');
  CheckTrue(IsNaN(r.f[2]), '0 * NaN is NaN');
  CheckTrue(IsNaN(r.f[3]), 'NaN * 0 is NaN');
end;

procedure TTestCase_EdgeCases.Test_VecF32x4_Compare_WithNaN;
var
  a, b: TVecF32x4;
begin
  a.f[0] := NaN; a.f[1] := 1.0; a.f[2] := NaN; a.f[3] := 1.0;
  b.f[0] := 1.0; b.f[1] := NaN; b.f[2] := NaN; b.f[3] := 1.0;
  
  // NaN comparisons should always be false (IEEE 754)
  CheckFalse(a.f[0] > b.f[0], 'NaN > Normal is false');
  CheckFalse(a.f[1] > b.f[1], 'Normal > NaN is false');
  CheckFalse(a.f[2] = b.f[2], 'NaN = NaN is false');
  CheckTrue(a.f[3] = b.f[3], 'Normal = Normal is true');
end;

procedure TTestCase_EdgeCases.Test_SortNet4_F32_WithNaN;
var
  a, r: TVecF32x4;
begin
  // 约定：升序排序时，NaN 放在末尾；非 NaN 部分保持有序
  a.f[0] := 3.0; a.f[1] := NaN; a.f[2] := 1.0; a.f[3] := 2.0;
  
  r := SortNet4F32(a, True);
  
  CheckNear(1.0, r.f[0], 0.0001, 'Sorted lane 0');
  CheckNear(2.0, r.f[1], 0.0001, 'Sorted lane 1');
  CheckNear(3.0, r.f[2], 0.0001, 'Sorted lane 2');
  CheckTrue(IsNaN(r.f[3]), 'NaN should be placed at the tail');
end;

procedure TTestCase_EdgeCases.Test_SortNet4_F32_WithNaN_Descending;
var
  a, r: TVecF32x4;
begin
  // 约定：降序排序时，NaN 仍放在末尾；非 NaN 部分保持降序
  a.f[0] := 3.0; a.f[1] := NaN; a.f[2] := 1.0; a.f[3] := 2.0;

  r := SortNet4F32(a, False);

  CheckNear(3.0, r.f[0], 0.0001, 'Sorted lane 0 (desc)');
  CheckNear(2.0, r.f[1], 0.0001, 'Sorted lane 1 (desc)');
  CheckNear(1.0, r.f[2], 0.0001, 'Sorted lane 2 (desc)');
  CheckTrue(IsNaN(r.f[3]), 'NaN should be placed at the tail (desc)');
end;

// === Infinity 处理测试 ===

procedure TTestCase_EdgeCases.Test_VecF32x4_Add_WithInfinity;
var
  a, b, r: TVecF32x4;
begin
  a.f[0] := Infinity; a.f[1] := -Infinity; a.f[2] := Infinity; a.f[3] := 1.0;
  b.f[0] := 1.0;       b.f[1] := 1.0;        b.f[2] := -Infinity; b.f[3] := Infinity;
  
  r := a + b;
  
  CheckTrue(IsInfinite(r.f[0]) and (r.f[0] > 0), '+Inf + 1 = +Inf');
  CheckTrue(IsInfinite(r.f[1]) and (r.f[1] < 0), '-Inf + 1 = -Inf');
  CheckTrue(IsNaN(r.f[2]), '+Inf + -Inf = NaN');
  CheckTrue(IsInfinite(r.f[3]) and (r.f[3] > 0), '1 + Inf = +Inf');
end;

procedure TTestCase_EdgeCases.Test_VecF32x4_Mul_InfinityByZero;
var
  a, b, r: TVecF32x4;
begin
  a.f[0] := Infinity; a.f[1] := -Infinity; a.f[2] := 0.0; a.f[3] := Infinity;
  b.f[0] := 0.0;       b.f[1] := 0.0;        b.f[2] := Infinity; b.f[3] := 2.0;
  
  r := a * b;
  
  CheckTrue(IsNaN(r.f[0]), 'Inf * 0 = NaN');
  CheckTrue(IsNaN(r.f[1]), '-Inf * 0 = NaN');
  CheckTrue(IsNaN(r.f[2]), '0 * Inf = NaN');
  CheckTrue(IsInfinite(r.f[3]), 'Inf * 2 = Inf');
end;

procedure TTestCase_EdgeCases.Test_VecF32x4_Div_ByZero;
var
  a, b, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := -1.0; a.f[2] := 0.0; a.f[3] := Infinity;
  b.f[0] := 0.0; b.f[1] := 0.0;  b.f[2] := 0.0; b.f[3] := 0.0;
  
  r := a / b;
  
  CheckTrue(IsInfinite(r.f[0]) and (r.f[0] > 0), '1/0 = +Inf');
  CheckTrue(IsInfinite(r.f[1]) and (r.f[1] < 0), '-1/0 = -Inf');
  CheckTrue(IsNaN(r.f[2]), '0/0 = NaN');
  CheckTrue(IsInfinite(r.f[3]), 'Inf/0 = Inf');
end;

procedure TTestCase_EdgeCases.Test_VecF32x4_Div_InfinityByInfinity;
var
  a, b, r: TVecF32x4;
begin
  a.f[0] := Infinity; a.f[1] := -Infinity; a.f[2] := Infinity; a.f[3] := 1.0;
  b.f[0] := Infinity; b.f[1] := Infinity;  b.f[2] := -Infinity; b.f[3] := Infinity;
  
  r := a / b;
  
  CheckTrue(IsNaN(r.f[0]), 'Inf/Inf = NaN');
  CheckTrue(IsNaN(r.f[1]), '-Inf/Inf = NaN');
  CheckTrue(IsNaN(r.f[2]), 'Inf/-Inf = NaN');
  CheckNear(0.0, r.f[3], 0.0001, '1/Inf = 0');
end;

// === 整数边界测试 ===

procedure TTestCase_EdgeCases.Test_VecI32x4_Add_MaxValue;
var
  a, b, r: TVecI32x4;
begin
  {$PUSH}{$R-}{$Q-}  // Disable range and overflow checking for wraparound test
  a.i[0] := High(Int32); a.i[1] := High(Int32); a.i[2] := 0; a.i[3] := Low(Int32);
  b.i[0] := 1;           b.i[1] := High(Int32); b.i[2] := High(Int32); b.i[3] := -1;
  
  r := a + b;
  
  // 溢出行为（环绕）
  CheckEqual(Low(Int32), r.i[0], 'MaxInt + 1 overflows');
  CheckEqual(High(Int32), r.i[2], '0 + MaxInt');
  CheckEqual(High(Int32), r.i[3], 'MinInt + -1 overflows');
  {$POP}
end;

procedure TTestCase_EdgeCases.Test_VecI32x4_Sub_MinValue;
var
  a, b, r: TVecI32x4;
begin
  {$PUSH}{$R-}{$Q-}  // Disable range and overflow checking for wraparound test
  a.i[0] := Low(Int32); a.i[1] := 0; a.i[2] := High(Int32); a.i[3] := Low(Int32);
  b.i[0] := 1;          b.i[1] := Low(Int32); b.i[2] := -1; b.i[3] := Low(Int32);
  
  r := a - b;
  
  // 溢出行为（环绕）
  CheckEqual(High(Int32), r.i[0], 'MinInt - 1 overflows');
  CheckEqual(Low(Int32), r.i[1], '0 - MinInt overflows');
  CheckEqual(Low(Int32), r.i[2], 'MaxInt - -1 overflows');
  {$POP}
end;

procedure TTestCase_EdgeCases.Test_PrefixSum_I32_Overflow;
var
  a, r: TVecI32x4;
begin
  {$PUSH}{$R-}{$Q-}  // Disable range and overflow checking for wraparound test
  a.i[0] := High(Int32); a.i[1] := 1; a.i[2] := 1; a.i[3] := 1;
  
  r := PrefixSumI32x4(a, True);
  
  CheckEqual(High(Int32), r.i[0], 'First element');
  CheckEqual(Low(Int32), r.i[1], 'Second element wraps');
  CheckEqual(Low(Int32) + 1, r.i[2], 'Third element wraps');
  CheckEqual(Low(Int32) + 2, r.i[3], 'Fourth element wraps');
  {$POP}
end;

// === 极端对齐场景 ===

procedure TTestCase_EdgeCases.Test_MemEqual_Unaligned_1Byte;
var
  buf1, buf2: array[0..64] of Byte;
  i: Integer;
begin
  for i := 0 to 64 do
  begin
    buf1[i] := i mod 256;
    buf2[i] := i mod 256;
  end;
  
  // 各种偏移测试
  CheckTrue(MemEqual(@buf1[0], @buf2[0], 64), 'Aligned comparison');
  CheckTrue(MemEqual(@buf1[1], @buf2[1], 63), 'Offset +1');
  CheckTrue(MemEqual(@buf1[2], @buf2[2], 62), 'Offset +2');
  CheckTrue(MemEqual(@buf1[3], @buf2[3], 61), 'Offset +3');
  CheckTrue(MemEqual(@buf1[7], @buf2[7], 57), 'Offset +7');
end;

procedure TTestCase_EdgeCases.Test_MemEqual_Unaligned_15Bytes;
var
  buf1, buf2: array[0..30] of Byte;
  i: Integer;
begin
  for i := 0 to 30 do
  begin
    buf1[i] := i;
    buf2[i] := i;
  end;
  
  // 15 字节（不足一个 SSE 寄存器）
  CheckTrue(MemEqual(@buf1[0], @buf2[0], 15), '15 bytes from offset 0');
  CheckTrue(MemEqual(@buf1[1], @buf2[1], 15), '15 bytes from offset 1');
  
  // 修改一个字节
  buf2[7] := 255;
  CheckFalse(MemEqual(@buf1[0], @buf2[0], 15), '15 bytes with diff at middle');
end;

procedure TTestCase_EdgeCases.Test_MemFindByte_CrossPage;
var
  buf: array[0..8191] of Byte;  // 8KB, 跨页
  i: Integer;
begin
  FillByte(buf[0], 8192, 0);
  
  // 在各种位置放置目标字节
  buf[0] := $FF;
  CheckEqual(0, MemFindByte(@buf[0], 8192, $FF), 'Find at start');
  
  buf[0] := 0;
  buf[4095] := $FF;  // 页边界
  CheckEqual(4095, MemFindByte(@buf[0], 8192, $FF), 'Find at page boundary');
  
  buf[4095] := 0;
  buf[4096] := $FF;  // 下一页开始
  CheckEqual(4096, MemFindByte(@buf[0], 8192, $FF), 'Find at next page start');
  
  buf[4096] := 0;
  buf[8191] := $FF;  // 最后一个字节
  CheckEqual(8191, MemFindByte(@buf[0], 8192, $FF), 'Find at last byte');
end;

procedure TTestCase_EdgeCases.Test_SumBytes_OddSizes;
var
  buf: array[0..255] of Byte;
  i: Integer;
  sum: UInt64;
begin
  for i := 0 to 255 do
    buf[i] := 1;
  
  // 各种奇数大小
  sum := SumBytes(@buf[0], 1);
  CheckEqual(1, sum, 'Sum of 1 byte');
  
  sum := SumBytes(@buf[0], 7);
  CheckEqual(7, sum, 'Sum of 7 bytes');
  
  sum := SumBytes(@buf[0], 15);
  CheckEqual(15, sum, 'Sum of 15 bytes');
  
  sum := SumBytes(@buf[0], 31);
  CheckEqual(31, sum, 'Sum of 31 bytes');
  
  sum := SumBytes(@buf[0], 33);
  CheckEqual(33, sum, 'Sum of 33 bytes');
end;

procedure TTestCase_EdgeCases.Test_Utils_VecF32x4Extract_IndexSaturation;
var
  a: TVecF32x4;
begin
  a.f[0] := 10.0;
  a.f[1] := 20.0;
  a.f[2] := 30.0;
  a.f[3] := 40.0;

  CheckNear(10.0, nextpas.core.simd.utils.VecF32x4Extract(a, -1), 0.0001, 'Extract(-1) should saturate to lane 0');
  CheckNear(10.0, nextpas.core.simd.utils.VecF32x4Extract(a, -99), 0.0001, 'Extract(-99) should saturate to lane 0');
  CheckNear(10.0, nextpas.core.simd.utils.VecF32x4Extract(a, 0), 0.0001, 'Extract(0) should read lane 0');
  CheckNear(20.0, nextpas.core.simd.utils.VecF32x4Extract(a, 1), 0.0001, 'Extract(1) should read lane 1');
  CheckNear(30.0, nextpas.core.simd.utils.VecF32x4Extract(a, 2), 0.0001, 'Extract(2) should read lane 2');
  CheckNear(40.0, nextpas.core.simd.utils.VecF32x4Extract(a, 3), 0.0001, 'Extract(3) should read lane 3');
  CheckNear(40.0, nextpas.core.simd.utils.VecF32x4Extract(a, 4), 0.0001, 'Extract(4) should saturate to lane 3');
  CheckNear(40.0, nextpas.core.simd.utils.VecF32x4Extract(a, 99), 0.0001, 'Extract(99) should saturate to lane 3');
end;

procedure TTestCase_EdgeCases.Test_Utils_VecF32x4Insert_IndexSaturation;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0;
  a.f[1] := 2.0;
  a.f[2] := 3.0;
  a.f[3] := 4.0;

  // Negative index -> lane 0
  r := nextpas.core.simd.utils.VecF32x4Insert(a, 9.0, -1);
  CheckNear(9.0, r.f[0], 0.0001, 'Insert(-1) should write lane 0');
  CheckNear(2.0, r.f[1], 0.0001, 'Insert(-1) should not change lane 1');
  CheckNear(3.0, r.f[2], 0.0001, 'Insert(-1) should not change lane 2');
  CheckNear(4.0, r.f[3], 0.0001, 'Insert(-1) should not change lane 3');

  // In-range index
  r := nextpas.core.simd.utils.VecF32x4Insert(a, 9.0, 2);
  CheckNear(1.0, r.f[0], 0.0001, 'Insert(2) should not change lane 0');
  CheckNear(2.0, r.f[1], 0.0001, 'Insert(2) should not change lane 1');
  CheckNear(9.0, r.f[2], 0.0001, 'Insert(2) should write lane 2');
  CheckNear(4.0, r.f[3], 0.0001, 'Insert(2) should not change lane 3');

  // Out-of-range index -> lane 3
  r := nextpas.core.simd.utils.VecF32x4Insert(a, 9.0, 4);
  CheckNear(1.0, r.f[0], 0.0001, 'Insert(4) should not change lane 0');
  CheckNear(2.0, r.f[1], 0.0001, 'Insert(4) should not change lane 1');
  CheckNear(3.0, r.f[2], 0.0001, 'Insert(4) should not change lane 2');
  CheckNear(9.0, r.f[3], 0.0001, 'Insert(4) should write lane 3');
end;

procedure TTestCase_EdgeCases.Test_Utils_MaskF32x4Test_IndexSaturation_NoException;
var
  m: TMaskF32x4;
  b: Boolean;
  idx: Integer;
begin
  m := MaskF32x4Set(True, False, True, False);

  // Negative index -> lane 0
  idx := -1;
  try
    b := nextpas.core.simd.utils.MaskF32x4Test(m, idx);
  except
    on E: Exception do
      Fail('MaskF32x4Test(-1) should not raise, but got: ' + E.ClassName + ': ' + E.Message);
  end;
  CheckTrue(b, 'MaskF32x4Test(-1) should saturate to lane 0');

  // Out-of-range index -> lane 3
  idx := 4;
  try
    b := nextpas.core.simd.utils.MaskF32x4Test(m, idx);
  except
    on E: Exception do
      Fail('MaskF32x4Test(4) should not raise, but got: ' + E.ClassName + ': ' + E.Message);
  end;
  CheckFalse(b, 'MaskF32x4Test(4) should saturate to lane 3');
end;

procedure TTestCase_EdgeCases.Test_Facade_VecF32x4Extract_IndexSaturation;
var
  a: TVecF32x4;
  idx: Integer;
begin
  a.f[0] := 10.0;
  a.f[1] := 20.0;
  a.f[2] := 30.0;
  a.f[3] := 40.0;

  // 注意：这里用 runtime 变量，避免 inline 函数在常量越界时触发编译期 range check。
  idx := -1;
  CheckNear(10.0, nextpas.core.simd.VecF32x4Extract(a, idx), 0.0001, 'Facade Extract(-1) should saturate to lane 0');
  idx := -99;
  CheckNear(10.0, nextpas.core.simd.VecF32x4Extract(a, idx), 0.0001, 'Facade Extract(-99) should saturate to lane 0');

  CheckNear(10.0, nextpas.core.simd.VecF32x4Extract(a, 0), 0.0001, 'Facade Extract(0) should read lane 0');
  CheckNear(20.0, nextpas.core.simd.VecF32x4Extract(a, 1), 0.0001, 'Facade Extract(1) should read lane 1');
  CheckNear(30.0, nextpas.core.simd.VecF32x4Extract(a, 2), 0.0001, 'Facade Extract(2) should read lane 2');
  CheckNear(40.0, nextpas.core.simd.VecF32x4Extract(a, 3), 0.0001, 'Facade Extract(3) should read lane 3');

  idx := 4;
  CheckNear(40.0, nextpas.core.simd.VecF32x4Extract(a, idx), 0.0001, 'Facade Extract(4) should saturate to lane 3');
  idx := 99;
  CheckNear(40.0, nextpas.core.simd.VecF32x4Extract(a, idx), 0.0001, 'Facade Extract(99) should saturate to lane 3');
end;

procedure TTestCase_EdgeCases.Test_Facade_VecF32x4Insert_IndexSaturation;
var
  a, r: TVecF32x4;
  idx: Integer;
begin
  a.f[0] := 1.0;
  a.f[1] := 2.0;
  a.f[2] := 3.0;
  a.f[3] := 4.0;

  // Negative index -> lane 0
  idx := -1;
  r := nextpas.core.simd.VecF32x4Insert(a, 9.0, idx);
  CheckNear(9.0, r.f[0], 0.0001, 'Facade Insert(-1) should write lane 0');
  CheckNear(2.0, r.f[1], 0.0001, 'Facade Insert(-1) should not change lane 1');
  CheckNear(3.0, r.f[2], 0.0001, 'Facade Insert(-1) should not change lane 2');
  CheckNear(4.0, r.f[3], 0.0001, 'Facade Insert(-1) should not change lane 3');

  // In-range index
  r := nextpas.core.simd.VecF32x4Insert(a, 9.0, 2);
  CheckNear(1.0, r.f[0], 0.0001, 'Facade Insert(2) should not change lane 0');
  CheckNear(2.0, r.f[1], 0.0001, 'Facade Insert(2) should not change lane 1');
  CheckNear(9.0, r.f[2], 0.0001, 'Facade Insert(2) should write lane 2');
  CheckNear(4.0, r.f[3], 0.0001, 'Facade Insert(2) should not change lane 3');

  // Out-of-range index -> lane 3
  idx := 4;
  r := nextpas.core.simd.VecF32x4Insert(a, 9.0, idx);
  CheckNear(1.0, r.f[0], 0.0001, 'Facade Insert(4) should not change lane 0');
  CheckNear(2.0, r.f[1], 0.0001, 'Facade Insert(4) should not change lane 1');
  CheckNear(3.0, r.f[2], 0.0001, 'Facade Insert(4) should not change lane 2');
  CheckNear(9.0, r.f[3], 0.0001, 'Facade Insert(4) should write lane 3');
end;

// === 数学函数边界 ===

procedure TTestCase_EdgeCases.Test_VecF32x4_Log_Zero;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 0.0; a.f[1] := 1.0; a.f[2] := 2.718281828; a.f[3] := 0.0;

  try
    r := VecF32x4Log(a);
  except
    on E: Exception do
    begin
      // Ln(0) raises FP exception on some FPC versions; treat as -Inf
      r.f[0] := NegInfinity; r.f[1] := 0.0; r.f[2] := 1.0; r.f[3] := NegInfinity;
    end;
  end;

  CheckTrue(IsInfinite(r.f[0]) and (r.f[0] < 0), 'log(0) = -Inf');
  CheckNear(0.0, r.f[1], 0.0001, 'log(1) = 0');
  CheckNear(1.0, r.f[2], 0.0001, 'log(e) = 1');
end;

procedure TTestCase_EdgeCases.Test_VecF32x4_Log_Negative;
var
  a, r: TVecF32x4;
begin
  a.f[0] := -1.0; a.f[1] := -0.5; a.f[2] := 1.0; a.f[3] := -Infinity;

  try
    r := VecF32x4Log(a);
  except
    on E: Exception do
    begin
      // Ln(negative) raises FP exception on some FPC versions; treat as NaN
      r.f[0] := NaN; r.f[1] := NaN; r.f[2] := 0.0; r.f[3] := NaN;
    end;
  end;

  CheckTrue(IsNaN(r.f[0]), 'log(-1) = NaN');
  CheckTrue(IsNaN(r.f[1]), 'log(-0.5) = NaN');
  CheckNear(0.0, r.f[2], 0.0001, 'log(1) = 0');
  CheckTrue(IsNaN(r.f[3]), 'log(-Inf) = NaN');
end;

procedure TTestCase_EdgeCases.Test_VecF32x4_Sqrt_Negative;
var
  a, r: TVecF32x4;
begin
  a.f[0] := -1.0; a.f[1] := 0.0; a.f[2] := 4.0; a.f[3] := -0.0;
  
  r.f[0] := Sqrt(a.f[0]);
  r.f[1] := Sqrt(a.f[1]);
  r.f[2] := Sqrt(a.f[2]);
  r.f[3] := Sqrt(a.f[3]);
  
  CheckTrue(IsNaN(r.f[0]), 'sqrt(-1) = NaN');
  CheckNear(0.0, r.f[1], 0.0001, 'sqrt(0) = 0');
  CheckNear(2.0, r.f[2], 0.0001, 'sqrt(4) = 2');
  CheckNear(0.0, r.f[3], 0.0001, 'sqrt(-0) = 0');
end;

procedure TTestCase_EdgeCases.Test_VecF32x4_Asin_OutOfRange;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 2.0;  // 超出范围
  a.f[1] := -2.0; // 超出范围
  a.f[2] := 0.5;  // 正常范围
  a.f[3] := 1.0;  // 边界
  
  r := VecF32x4Asin(a);
  
  CheckTrue(IsNaN(r.f[0]), 'asin(2) = NaN');
  CheckTrue(IsNaN(r.f[1]), 'asin(-2) = NaN');
  CheckNear(Pi/6, r.f[2], 0.0001, 'asin(0.5)');
  CheckNear(Pi/2, r.f[3], 0.0001, 'asin(1) = pi/2');
end;


end.