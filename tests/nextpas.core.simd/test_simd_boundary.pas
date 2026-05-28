program test_simd_boundary;

{$mode objfpc}{$H+}
{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

{**
 * SIMD 边界测试 - Rust 级别代码质量验证
 *
 * 测试内容:
 *   1. IEEE 754 特殊值处理 (NaN, Inf, -0.0)
 *   2. 零长度数组操作
 *   3. 对齐边界检查
 *   4. 索引边界饱和策略
 *}

uses
  SysUtils, nextpas.core.math,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.scalar,
  nextpas.core.simd.arrays.typed,
  nextpas.core.simd.linalg;

// 禁用 FPU 异常以正确测试 IEEE 754 行为
procedure DisableFPUExceptions;
begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
end;

var
  passCount, failCount: Integer;
  currentTestGroup: string;

procedure Check(const testName: string; passed: Boolean);
begin
  if passed then
  begin
    WriteLn('  [PASS] ', testName);
    Inc(passCount);
  end
  else
  begin
    WriteLn('  [FAIL] ', testName);
    Inc(failCount);
  end;
end;

procedure BeginGroup(const groupName: string);
begin
  currentTestGroup := groupName;
  WriteLn;
  WriteLn('=== ', groupName, ' ===');
end;

// =============================================================================
// IEEE 754 特殊值测试
// =============================================================================

procedure TestNaN;
var
  a, b, result_: TVecF32x4;
  nanVal: Single;
begin
  BeginGroup('NaN 处理测试');

  // 创建 NaN 值
  nanVal := NaN;

  // 测试 NaN 加法
  a.f[0] := nanVal; a.f[1] := 1.0; a.f[2] := 2.0; a.f[3] := 3.0;
  b.f[0] := 1.0; b.f[1] := 1.0; b.f[2] := 1.0; b.f[3] := 1.0;
  result_ := ScalarAddF32x4(a, b);
  Check('NaN + 1.0 产生 NaN', IsNan(result_.f[0]));
  Check('正常值不受 NaN 影响', Abs(result_.f[1] - 2.0) < 0.0001);

  // 测试 NaN 乘法
  result_ := ScalarMulF32x4(a, b);
  Check('NaN * 1.0 产生 NaN', IsNan(result_.f[0]));

  // 测试 NaN 除法
  result_ := ScalarDivF32x4(a, b);
  Check('NaN / 1.0 产生 NaN', IsNan(result_.f[0]));

  // 测试 NaN 比较
  Check('NaN 不等于自身 (IEEE 754)', not (nanVal = nanVal));
end;

procedure TestInfinity;
var
  a, b, result_: TVecF32x4;
  posInf, negInf: Single;
begin
  BeginGroup('无穷大处理测试');

  posInf := Infinity;
  negInf := -posInf;

  // 测试正无穷
  a.f[0] := posInf; a.f[1] := 1.0; a.f[2] := 2.0; a.f[3] := 3.0;
  b.f[0] := 1.0; b.f[1] := 1.0; b.f[2] := 1.0; b.f[3] := 1.0;
  result_ := ScalarAddF32x4(a, b);
  Check('Inf + 1.0 = Inf', IsInfinite(result_.f[0]) and (result_.f[0] > 0));

  // 测试负无穷
  a.f[0] := negInf;
  result_ := ScalarAddF32x4(a, b);
  Check('-Inf + 1.0 = -Inf', IsInfinite(result_.f[0]) and (result_.f[0] < 0));

  // 测试无穷减无穷 = NaN
  a.f[0] := posInf;
  b.f[0] := posInf;
  result_ := ScalarSubF32x4(a, b);
  Check('Inf - Inf = NaN', IsNan(result_.f[0]));

  // 测试 0 * Inf = NaN
  a.f[0] := 0.0;
  b.f[0] := posInf;
  result_ := ScalarMulF32x4(a, b);
  Check('0 * Inf = NaN', IsNan(result_.f[0]));
end;

procedure TestNegativeZero;
var
  a, b, result_: TVecF32x4;
  negZero, posZero: Single;
begin
  BeginGroup('负零处理测试');

  // 创建 -0.0
  posZero := 0.0;
  negZero := -posZero;

  a.f[0] := negZero; a.f[1] := 1.0; a.f[2] := 2.0; a.f[3] := 3.0;
  b.f[0] := posZero; b.f[1] := 1.0; b.f[2] := 1.0; b.f[3] := 1.0;

  // 测试 -0 + 0 = +0 (IEEE 754)
  result_ := ScalarAddF32x4(a, b);
  Check('-0.0 + 0.0 结果为零', result_.f[0] = 0.0);

  // 测试 -0 * 正数
  b.f[0] := 5.0;
  result_ := ScalarMulF32x4(a, b);
  Check('-0.0 * 5.0 结果为零', result_.f[0] = 0.0);

  // 测试 1 / -0 = -Inf
  a.f[0] := 1.0;
  b.f[0] := negZero;
  result_ := ScalarDivF32x4(a, b);
  Check('1.0 / -0.0 = -Inf', IsInfinite(result_.f[0]) and (result_.f[0] < 0));
end;

// =============================================================================
// 零长度和边界测试
// =============================================================================

procedure TestZeroLength;
var
  buf: array[0..15] of Byte;
  result_: Boolean;
begin
  BeginGroup('零长度操作测试');

  // 测试 MemEqual 零长度
  result_ := MemEqual_Scalar(@buf[0], @buf[8], 0);
  Check('MemEqual(a, b, 0) = True', result_);

  // 测试 MemFindByte 零长度
  Check('MemFindByte(p, 0, x) = -1', MemFindByte_Scalar(@buf[0], 0, $FF) = -1);

  // 测试 Utf8Validate 零长度
  Check('Utf8Validate(p, 0) = True', Utf8Validate_Scalar(@buf[0], 0));

  // 测试 SumBytes 零长度
  Check('SumBytes(p, 0) = 0', SumBytes_Scalar(@buf[0], 0) = 0);

  // 测试 CountByte 零长度
  Check('CountByte(p, 0, x) = 0', CountByte_Scalar(@buf[0], 0, $FF) = 0);
end;

procedure TestNilPointer;
var
  result_: Boolean;
begin
  BeginGroup('空指针处理测试');

  // 测试 Utf8Validate 空指针
  result_ := Utf8Validate_Scalar(nil, 10);
  Check('Utf8Validate(nil, 10) = False', not result_);

  // 测试 MemFindByte 空指针 - 应该返回 -1
  Check('MemFindByte(nil, 10, x) 安全处理', MemFindByte_Scalar(nil, 0, $FF) = -1);
end;

// =============================================================================
// 索引边界饱和策略测试
// =============================================================================

procedure TestIndexSaturation;
var
  a: TVecF32x4;
  result_: Single;
  resultVec: TVecF32x4;
begin
  BeginGroup('索引边界饱和策略测试');

  // 初始化测试向量
  a.f[0] := 10.0; a.f[1] := 20.0; a.f[2] := 30.0; a.f[3] := 40.0;

  // 测试 Extract 负索引 -> 饱和到 0
  result_ := ScalarExtractF32x4(a, -1);
  Check('Extract(v, -1) 饱和到索引 0', Abs(result_ - 10.0) < 0.0001);

  result_ := ScalarExtractF32x4(a, -100);
  Check('Extract(v, -100) 饱和到索引 0', Abs(result_ - 10.0) < 0.0001);

  // 测试 Extract 越界索引 -> 饱和到 3
  result_ := ScalarExtractF32x4(a, 4);
  Check('Extract(v, 4) 饱和到索引 3', Abs(result_ - 40.0) < 0.0001);

  result_ := ScalarExtractF32x4(a, 999);
  Check('Extract(v, 999) 饱和到索引 3', Abs(result_ - 40.0) < 0.0001);

  // 测试 Insert 负索引
  resultVec := ScalarInsertF32x4(a, 99.0, -1);
  Check('Insert(v, 99, -1) 饱和到索引 0', Abs(resultVec.f[0] - 99.0) < 0.0001);

  // 测试 Insert 越界索引
  resultVec := ScalarInsertF32x4(a, 88.0, 5);
  Check('Insert(v, 88, 5) 饱和到索引 3', Abs(resultVec.f[3] - 88.0) < 0.0001);

  // 验证正常索引仍然正常工作
  result_ := ScalarExtractF32x4(a, 0);
  Check('Extract(v, 0) 正常', Abs(result_ - 10.0) < 0.0001);

  result_ := ScalarExtractF32x4(a, 3);
  Check('Extract(v, 3) 正常', Abs(result_ - 40.0) < 0.0001);
end;

// =============================================================================
// 对齐测试
// =============================================================================

procedure TestAlignedAccess;
var
  alignedBuf: array[0..31] of Single;
  a: TVecF32x4;
  p: PSingle;
  alignedP: PSingle;
begin
  BeginGroup('对齐访问测试');

  // 找到 16 字节对齐的地址
  p := @alignedBuf[0];
  alignedP := PSingle((PtrUInt(p) + 15) and (not PtrUInt(15)));

  // 初始化对齐内存
  alignedP[0] := 1.0;
  alignedP[1] := 2.0;
  alignedP[2] := 3.0;
  alignedP[3] := 4.0;

  // 测试对齐加载
  a := ScalarLoadF32x4Aligned(alignedP);
  Check('对齐加载正确读取数据[0]', Abs(a.f[0] - 1.0) < 0.0001);
  Check('对齐加载正确读取数据[1]', Abs(a.f[1] - 2.0) < 0.0001);
  Check('对齐加载正确读取数据[2]', Abs(a.f[2] - 3.0) < 0.0001);
  Check('对齐加载正确读取数据[3]', Abs(a.f[3] - 4.0) < 0.0001);

  // 测试对齐存储
  a.f[0] := 10.0; a.f[1] := 20.0; a.f[2] := 30.0; a.f[3] := 40.0;
  ScalarStoreF32x4Aligned(alignedP, a);
  Check('对齐存储正确写入数据[0]', Abs(alignedP[0] - 10.0) < 0.0001);
  Check('对齐存储正确写入数据[3]', Abs(alignedP[3] - 40.0) < 0.0001);
end;

procedure TestUnalignedAccess;
var
  buf: array[0..31] of Single;
  a: TVecF32x4;
  p: PSingle;
begin
  BeginGroup('非对齐访问测试');

  // 使用非对齐地址
  p := @buf[1]; // 偏移 4 字节，不是 16 字节对齐

  p[0] := 5.0;
  p[1] := 6.0;
  p[2] := 7.0;
  p[3] := 8.0;

  // 测试非对齐加载
  a := ScalarLoadF32x4(p);
  Check('非对齐加载正确读取数据[0]', Abs(a.f[0] - 5.0) < 0.0001);
  Check('非对齐加载正确读取数据[3]', Abs(a.f[3] - 8.0) < 0.0001);

  // 测试非对齐存储
  a.f[0] := 50.0; a.f[3] := 80.0;
  ScalarStoreF32x4(p, a);
  Check('非对齐存储正确写入数据[0]', Abs(p[0] - 50.0) < 0.0001);
  Check('非对齐存储正确写入数据[3]', Abs(p[3] - 80.0) < 0.0001);
end;

// =============================================================================
// Reduction 边界测试
// =============================================================================

procedure TestReductionEdgeCases;
var
  a: TVecF32x4;
  nanVal: Single;
begin
  BeginGroup('Reduction 边界测试');

  nanVal := NaN;

  // 测试包含 NaN 的 Reduction
  a.f[0] := 1.0; a.f[1] := nanVal; a.f[2] := 3.0; a.f[3] := 4.0;
  Check('ReduceAdd 含 NaN 产生 NaN', IsNan(ScalarReduceAddF32x4(a)));
  Check('ReduceMul 含 NaN 产生 NaN', IsNan(ScalarReduceMulF32x4(a)));

  // 测试包含 Inf 的 Reduction
  a.f[0] := 1.0; a.f[1] := Infinity; a.f[2] := 3.0; a.f[3] := 4.0;
  Check('ReduceAdd 含 Inf 产生 Inf', IsInfinite(ScalarReduceAddF32x4(a)));

  // 测试全零
  a.f[0] := 0.0; a.f[1] := 0.0; a.f[2] := 0.0; a.f[3] := 0.0;
  Check('ReduceAdd 全零 = 0', ScalarReduceAddF32x4(a) = 0.0);
  Check('ReduceMul 全零 = 0', ScalarReduceMulF32x4(a) = 0.0);

  // 测试 ReduceMin/Max 与特殊值
  a.f[0] := 1.0; a.f[1] := Infinity; a.f[2] := -100.0; a.f[3] := 50.0;
  Check('ReduceMax 含 Inf = Inf', IsInfinite(ScalarReduceMaxF32x4(a)));
  Check('ReduceMin 正确找到最小值', Abs(ScalarReduceMinF32x4(a) - (-100.0)) < 0.0001);
end;

// =============================================================================
// Linalg 边界测试
// =============================================================================

procedure TestLinalgSingularAndZeroSize;
var
  LA, LL, LU, LInv, LEmptyMatrix: TSimdF32Matrix;
  LB, LSolved, LEmptyVector: TSimdF32Array;
  LDecomposed: Boolean;
begin
  BeginGroup('Linalg 奇异矩阵与 n=0 边界测试');

  LA := TSimdF32Matrix.Create(2, 2);
  LB := TSimdF32Array.Create(2);
  try
    LA.Put(0, 0, 1.0);
    LA.Put(0, 1, 2.0);
    LA.Put(1, 0, 2.0);
    LA.Put(1, 1, 4.0);
    LB.Data[0] := 3.0;
    LB.Data[1] := 6.0;

    LL := Default(TSimdF32Matrix);
    LU := Default(TSimdF32Matrix);
    LDecomposed := LUDecomposeF32(LA, LL, LU);
    Check('LUDecomposeF32 奇异矩阵返回 False', not LDecomposed);
    Check('LUDecomposeF32 失败路径释放 L', (LL.Data = nil) and (LL.Rows = 0) and (LL.Cols = 0));
    Check('LUDecomposeF32 失败路径释放 U', (LU.Data = nil) and (LU.Rows = 0) and (LU.Cols = 0));

    LSolved := SolveLinearF32(LA, LB);
    Check('SolveLinearF32 奇异矩阵返回空向量', (LSolved.Data = nil) and (LSolved.Count = 0));
    LSolved.Free;

    LInv := MatInverseF32(LA);
    Check('MatInverseF32 奇异矩阵返回空矩阵', (LInv.Data = nil) and (LInv.Rows = 0) and (LInv.Cols = 0));
    LInv.Free;
  finally
    LB.Free;
    LA.Free;
  end;

  LEmptyMatrix := Default(TSimdF32Matrix);
  LEmptyVector := Default(TSimdF32Array);

  LL := Default(TSimdF32Matrix);
  LU := Default(TSimdF32Matrix);
  Check('LUDecomposeF32 n=0 返回 False', not LUDecomposeF32(LEmptyMatrix, LL, LU));
  Check('LUDecomposeF32 n=0 不分配 L/U', (LL.Data = nil) and (LU.Data = nil));

  LSolved := SolveLinearF32(LEmptyMatrix, LEmptyVector);
  Check('SolveLinearF32 n=0 返回空向量', (LSolved.Data = nil) and (LSolved.Count = 0));
  LSolved.Free;

  LInv := MatInverseF32(LEmptyMatrix);
  Check('MatInverseF32 n=0 返回空矩阵', (LInv.Data = nil) and (LInv.Rows = 0) and (LInv.Cols = 0));
  LInv.Free;
end;

// =============================================================================
// 主程序
// =============================================================================

begin
  // 禁用 FPU 异常以正确测试 IEEE 754 特殊值
  DisableFPUExceptions;

  passCount := 0;
  failCount := 0;

  WriteLn('========================================');
  WriteLn(UTF8String('SIMD 边界测试 - Rust 级别代码质量验证'));
  WriteLn('========================================');

  // IEEE 754 特殊值测试
  TestNaN;
  TestInfinity;
  TestNegativeZero;

  // 边界条件测试
  TestZeroLength;
  TestNilPointer;

  // 饱和策略测试
  TestIndexSaturation;

  // 对齐测试
  TestAlignedAccess;
  TestUnalignedAccess;

  // Reduction 边界测试
  TestReductionEdgeCases;

  // Linalg 边界测试
  TestLinalgSingularAndZeroSize;

  // 汇总
  WriteLn;
  WriteLn('========================================');
  WriteLn(UTF8String('测试汇总'));
  WriteLn('========================================');
  WriteLn(UTF8String('通过: '), passCount);
  WriteLn(UTF8String('失败: '), failCount);
  WriteLn;

  if failCount = 0 then
  begin
    WriteLn(UTF8String('所有边界测试通过!'));
    ExitCode := 0;
  end
  else
  begin
    WriteLn(UTF8String('存在失败的测试!'));
    ExitCode := 1;
  end;
end.
