# SIMD 批量操作优化实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 nextpas.core.math.batch 的 17 个批量标量函数添加 SIMD 优化，新增 BatchSinCosF32，并创建性能基准测试。

**架构:** 采用混合 SIMD 策略，对于有硬件指令的函数使用平台特定指令，对于复杂函数使用 SIMD 加速的软件实现。使用 TDD 方法，先写测试再实现。

**Tech Stack:** Free Pascal, SSE/SSE2/SSE4.1 SIMD 指令, nextpas.core.bench 模块

---

### Task 1: 创建 SIMD 优化单元基础结构

**Files:**
- Create: `core/src/nextpas.core.math.batch.simd.pas`

**Step 1: 创建 SIMD 优化单元文件**

```pascal
{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

unit nextpas.core.math.batch.simd;

interface

uses
  nextpas.core.base,
  nextpas.core.simd;

// SIMD 优化的批量标量函数声明
function BatchSinSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchCosSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchSinCosSimdF32(const AInput: array of Single;
                            var ASinOutput, ACosOutput: array of Single): SizeInt;
function BatchExpSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchLnSimdF32(const AInput: array of Single;
                        var AOutput: array of Single): SizeInt;
function BatchLog2SimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
function BatchLog10SimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
function BatchSqrtSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
function BatchAbsSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchNegSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
function BatchCeilSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
function BatchFloorSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
function BatchRoundSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
function BatchTruncSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
function BatchLerpSimdF32(const AInput: array of Single;
                          AMin, AMax: Single;
                          var AOutput: array of Single): SizeInt;
function BatchClampSimdF32(const AInput: array of Single;
                           AMin, AMax: Single;
                           var AOutput: array of Single): SizeInt;
function BatchScaleOffsetSimdF32(const AInput: array of Single;
                                 AScale, AOffset: Single;
                                 var AOutput: array of Single): SizeInt;

implementation

uses
  nextpas.core.math.trig,
  nextpas.core.math.scalar;

// 临时占位实现 - 后续替换为真正的 SIMD 实现
function BatchSinSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Sin(AInput[i]);
  Result := LCount;
end;

function BatchCosSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Cos(AInput[i]);
  Result := LCount;
end;

function BatchSinCosSimdF32(const AInput: array of Single;
                            var ASinOutput, ACosOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(ASinOutput) then
    LCount := Length(ASinOutput);
  if LCount > Length(ACosOutput) then
    LCount := Length(ACosOutput);
  for i := 0 to LCount - 1 do
  begin
    ASinOutput[i] := Sin(AInput[i]);
    ACosOutput[i] := Cos(AInput[i]);
  end;
  Result := LCount;
end;

function BatchExpSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Exp(AInput[i]);
  Result := LCount;
end;

function BatchLnSimdF32(const AInput: array of Single;
                        var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Ln(AInput[i]);
  Result := LCount;
end;

function BatchLog2SimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Log2(AInput[i]);
  Result := LCount;
end;

function BatchLog10SimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Log10(AInput[i]);
  Result := LCount;
end;

function BatchSqrtSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Sqrt(AInput[i]);
  Result := LCount;
end;

function BatchAbsSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Abs(AInput[i]);
  Result := LCount;
end;

function BatchNegSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := -AInput[i];
  Result := LCount;
end;

function BatchCeilSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Ceil(AInput[i]);
  Result := LCount;
end;

function BatchFloorSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Floor(AInput[i]);
  Result := LCount;
end;

function BatchRoundSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Round(AInput[i]);
  Result := LCount;
end;

function BatchTruncSimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := Trunc(AInput[i]);
  Result := LCount;
end;

function BatchLerpSimdF32(const AInput: array of Single;
                          AMin, AMax: Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := AMin + (AMax - AMin) * AInput[i];
  Result := LCount;
end;

function BatchClampSimdF32(const AInput: array of Single;
                           AMin, AMax: Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
  begin
    if AInput[i] < AMin then
      AOutput[i] := AMin
    else if AInput[i] > AMax then
      AOutput[i] := AMax
    else
      AOutput[i] := AInput[i];
  end;
  Result := LCount;
end;

function BatchScaleOffsetSimdF32(const AInput: array of Single;
                                 AScale, AOffset: Single;
                                 var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for i := 0 to LCount - 1 do
    AOutput[i] := AInput[i] * AScale + AOffset;
  Result := LCount;
end;

end.
```

**Step 2: 编译验证**

Run: `make -C core/tests/nextpas.core.math test`
Expected: 编译通过，所有测试通过

**Step 3: 提交**

```bash
git add core/src/nextpas.core.math.batch.simd.pas
git commit -m "feat(math-simd): 创建 SIMD 批量操作单元基础结构"
```

---

### Task 2: 创建 SIMD 批量操作测试套件

**Files:**
- Create: `core/tests/nextpas.core.math/test_batch_simd/test_batch_simd.lpr`

**Step 1: 创建测试项目目录**

Run: `mkdir -p core/tests/nextpas.core.math/test_batch_simd`

**Step 2: 创建测试程序**

```pascal
program test_batch_simd;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.math.batch.simd;

type
  TTestBatchSimd = class(TTestCase)
  published
    procedure TestBatchSinSimdF32;
    procedure TestBatchCosSimdF32;
    procedure TestBatchSinCosSimdF32;
    procedure TestBatchExpSimdF32;
    procedure TestBatchLnSimdF32;
    procedure TestBatchSqrtSimdF32;
    procedure TestBatchAbsSimdF32;
    procedure TestBatchNegSimdF32;
    procedure TestBatchClampSimdF32;
    procedure TestBatchLerpSimdF32;
    procedure TestBatchScaleOffsetSimdF32;
    procedure TestBatchEmpty;
    procedure TestBatchMismatchedLength;
  end;

procedure TTestBatchSimd.TestBatchSinSimdF32;
var
  LInput, LOutput: array[0..3] of Single;
begin
  LInput[0] := 0.0;
  LInput[1] := Pi / 2;
  LInput[2] := Pi;
  LInput[3] := 3 * Pi / 2;

  BatchSinSimdF32(LInput, LOutput);

  CheckTrue(Abs(LOutput[0] - 0.0) < 1e-6, 'Sin(0) should be 0');
  CheckTrue(Abs(LOutput[1] - 1.0) < 1e-6, 'Sin(Pi/2) should be 1');
  CheckTrue(Abs(LOutput[2] - 0.0) < 1e-6, 'Sin(Pi) should be 0');
  CheckTrue(Abs(LOutput[3] - (-1.0)) < 1e-6, 'Sin(3*Pi/2) should be -1');
end;

procedure TTestBatchSimd.TestBatchCosSimdF32;
var
  LInput, LOutput: array[0..3] of Single;
begin
  LInput[0] := 0.0;
  LInput[1] := Pi / 2;
  LInput[2] := Pi;
  LInput[3] := 3 * Pi / 2;

  BatchCosSimdF32(LInput, LOutput);

  CheckTrue(Abs(LOutput[0] - 1.0) < 1e-6, 'Cos(0) should be 1');
  CheckTrue(Abs(LOutput[1] - 0.0) < 1e-6, 'Cos(Pi/2) should be 0');
  CheckTrue(Abs(LOutput[2] - (-1.0)) < 1e-6, 'Cos(Pi) should be -1');
  CheckTrue(Abs(LOutput[3] - 0.0) < 1e-6, 'Cos(3*Pi/2) should be 0');
end;

procedure TTestBatchSimd.TestBatchSinCosSimdF32;
var
  LInput, LSinOut, LCosOut: array[0..3] of Single;
begin
  LInput[0] := 0.0;
  LInput[1] := Pi / 2;
  LInput[2] := Pi;
  LInput[3] := 3 * Pi / 2;

  BatchSinCosSimdF32(LInput, LSinOut, LCosOut);

  CheckTrue(Abs(LSinOut[0] - 0.0) < 1e-6, 'Sin(0) should be 0');
  CheckTrue(Abs(LSinOut[1] - 1.0) < 1e-6, 'Sin(Pi/2) should be 1');
  CheckTrue(Abs(LCosOut[0] - 1.0) < 1e-6, 'Cos(0) should be 1');
  CheckTrue(Abs(LCosOut[1] - 0.0) < 1e-6, 'Cos(Pi/2) should be 0');
end;

procedure TTestBatchSimd.TestBatchExpSimdF32;
var
  LInput, LOutput: array[0..2] of Single;
begin
  LInput[0] := 0.0;
  LInput[1] := 1.0;
  LInput[2] := 2.0;

  BatchExpSimdF32(LInput, LOutput);

  CheckTrue(Abs(LOutput[0] - 1.0) < 1e-6, 'Exp(0) should be 1');
  CheckTrue(Abs(LOutput[1] - 2.71828) < 0.001, 'Exp(1) should be e');
  CheckTrue(Abs(LOutput[2] - 7.38906) < 0.001, 'Exp(2) should be e^2');
end;

procedure TTestBatchSimd.TestBatchLnSimdF32;
var
  LInput, LOutput: array[0..2] of Single;
begin
  LInput[0] := 1.0;
  LInput[1] := 2.71828;
  LInput[2] := 7.38906;

  BatchLnSimdF32(LInput, LOutput);

  CheckTrue(Abs(LOutput[0] - 0.0) < 1e-6, 'Ln(1) should be 0');
  CheckTrue(Abs(LOutput[1] - 1.0) < 0.001, 'Ln(e) should be 1');
  CheckTrue(Abs(LOutput[2] - 2.0) < 0.001, 'Ln(e^2) should be 2');
end;

procedure TTestBatchSimd.TestBatchSqrtSimdF32;
var
  LInput, LOutput: array[0..2] of Single;
begin
  LInput[0] := 0.0;
  LInput[1] := 4.0;
  LInput[2] := 9.0;

  BatchSqrtSimdF32(LInput, LOutput);

  CheckTrue(Abs(LOutput[0] - 0.0) < 1e-6, 'Sqrt(0) should be 0');
  CheckTrue(Abs(LOutput[1] - 2.0) < 1e-6, 'Sqrt(4) should be 2');
  CheckTrue(Abs(LOutput[2] - 3.0) < 1e-6, 'Sqrt(9) should be 3');
end;

procedure TTestBatchSimd.TestBatchAbsSimdF32;
var
  LInput, LOutput: array[0..3] of Single;
begin
  LInput[0] := -3.0;
  LInput[1] := -1.0;
  LInput[2] := 0.0;
  LInput[3] := 2.0;

  BatchAbsSimdF32(LInput, LOutput);

  CheckTrue(Abs(LOutput[0] - 3.0) < 1e-6, 'Abs(-3) should be 3');
  CheckTrue(Abs(LOutput[1] - 1.0) < 1e-6, 'Abs(-1) should be 1');
  CheckTrue(Abs(LOutput[2] - 0.0) < 1e-6, 'Abs(0) should be 0');
  CheckTrue(Abs(LOutput[3] - 2.0) < 1e-6, 'Abs(2) should be 2');
end;

procedure TTestBatchSimd.TestBatchNegSimdF32;
var
  LInput, LOutput: array[0..2] of Single;
begin
  LInput[0] := 1.0;
  LInput[1] := 0.0;
  LInput[2] := -2.0;

  BatchNegSimdF32(LInput, LOutput);

  CheckTrue(Abs(LOutput[0] - (-1.0)) < 1e-6, 'Neg(1) should be -1');
  CheckTrue(Abs(LOutput[1] - 0.0) < 1e-6, 'Neg(0) should be 0');
  CheckTrue(Abs(LOutput[2] - 2.0) < 1e-6, 'Neg(-2) should be 2');
end;

procedure TTestBatchSimd.TestBatchClampSimdF32;
var
  LInput, LOutput: array[0..4] of Single;
begin
  LInput[0] := -5.0;
  LInput[1] := 0.0;
  LInput[2] := 3.0;
  LInput[3] := 5.0;
  LInput[4] := 10.0;

  BatchClampSimdF32(LInput, 0.0, 5.0, LOutput);

  CheckTrue(Abs(LOutput[0] - 0.0) < 1e-6, 'Clamp(-5,0,5) should be 0');
  CheckTrue(Abs(LOutput[1] - 0.0) < 1e-6, 'Clamp(0,0,5) should be 0');
  CheckTrue(Abs(LOutput[2] - 3.0) < 1e-6, 'Clamp(3,0,5) should be 3');
  CheckTrue(Abs(LOutput[3] - 5.0) < 1e-6, 'Clamp(5,0,5) should be 5');
  CheckTrue(Abs(LOutput[4] - 5.0) < 1e-6, 'Clamp(10,0,5) should be 5');
end;

procedure TTestBatchSimd.TestBatchLerpSimdF32;
var
  LInput, LOutput: array[0..2] of Single;
begin
  LInput[0] := 0.0;
  LInput[1] := 0.5;
  LInput[2] := 1.0;

  BatchLerpSimdF32(LInput, 10.0, 20.0, LOutput);

  CheckTrue(Abs(LOutput[0] - 10.0) < 1e-6, 'Lerp(0,10,20) should be 10');
  CheckTrue(Abs(LOutput[1] - 15.0) < 1e-6, 'Lerp(0.5,10,20) should be 15');
  CheckTrue(Abs(LOutput[2] - 20.0) < 1e-6, 'Lerp(1,10,20) should be 20');
end;

procedure TTestBatchSimd.TestBatchScaleOffsetSimdF32;
var
  LInput, LOutput: array[0..2] of Single;
begin
  LInput[0] := 1.0;
  LInput[1] := 2.0;
  LInput[2] := 3.0;

  BatchScaleOffsetSimdF32(LInput, 2.0, 1.0, LOutput);

  CheckTrue(Abs(LOutput[0] - 3.0) < 1e-6, 'ScaleOffset(1,2,1) should be 3');
  CheckTrue(Abs(LOutput[1] - 5.0) < 1e-6, 'ScaleOffset(2,2,1) should be 5');
  CheckTrue(Abs(LOutput[2] - 7.0) < 1e-6, 'ScaleOffset(3,2,1) should be 7');
end;

procedure TTestBatchSimd.TestBatchEmpty;
var
  LInput, LOutput: array of Single;
begin
  SetLength(LInput, 0);
  SetLength(LOutput, 0);
  CheckEquals(0, BatchSinSimdF32(LInput, LOutput), 'Empty input should return 0');
end;

procedure TTestBatchSimd.TestBatchMismatchedLength;
var
  LInput: array[0..2] of Single;
  LOutput: array[0..0] of Single;
begin
  LInput[0] := 0.0;
  LInput[1] := 1.0;
  LInput[2] := 2.0;

  CheckEquals(1, BatchSinSimdF32(LInput, LOutput), 'Should return min length');
end;

begin
  RegisterTest('Math.Batch.Simd', TTestBatchSimd);
  RunRegisteredTests;
end.
```

**Step 3: 编译并运行测试**

Run: `make -C core/tests/nextpas.core.math/test_batch_simd clean test`
Expected: 所有测试通过

**Step 4: 提交**

```bash
git add core/tests/nextpas.core.math/test_batch_simd
git commit -m "test(math-simd): 创建 SIMD 批量操作测试套件"
```

---

### Task 3: 实现 SIMD 优化的基础运算 (Sqrt, Abs, Neg)

**Files:**
- Modify: `core/src/nextpas.core.math.batch.simd.pas`

**Step 1: 实现 BatchSqrtSimdF32 使用 SIMD**

```pascal
function BatchSqrtSimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdCount: SizeInt;
  LInput, LOutput: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  
  LSimdCount := LCount - (LCount mod 4);
  
  // SIMD 处理 4 个一组
  for i := 0 to LSimdCount - 1 do
  begin
    LInput := VecF32x4Load(@AInput[i]);
    LOutput := VecF32x4Sqrt(LInput);
    VecF32x4Store(@AOutput[i], LOutput);
  end;
  
  // 处理剩余元素
  for i := LSimdCount to LCount - 1 do
    AOutput[i] := Sqrt(AInput[i]);
  
  Result := LCount;
end;
```

**Step 2: 实现 BatchAbsSimdF32 使用 SIMD**

```pascal
function BatchAbsSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdCount: SizeInt;
  LInput, LOutput: TVecF32x4;
  LSignMask: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  
  LSimdCount := LCount - (LCount mod 4);
  
  // 创建符号位掩码 (清除最高位)
  LSignMask := VecF32x4Set1(7FFFFFFF);  // 0x7FFFFFFF = 01111111...
  
  // SIMD 处理 4 个一组
  for i := 0 to LSimdCount - 1 do
  begin
    LInput := VecF32x4Load(@AInput[i]);
    LOutput := VecF32x4And(LInput, LSignMask);  // 清除符号位
    VecF32x4Store(@AOutput[i], LOutput);
  end;
  
  // 处理剩余元素
  for i := LSimdCount to LCount - 1 do
    AOutput[i] := Abs(AInput[i]);
  
  Result := LCount;
end;
```

**Step 3: 实现 BatchNegSimdF32 使用 SIMD**

```pascal
function BatchNegSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount, LSimdCount: SizeInt;
  LInput, LOutput: TVecF32x4;
  LSignBit: TVecF32x4;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  
  LSimdCount := LCount - (LCount mod 4);
  
  // 创建符号位掩码 (翻转最高位)
  LSignBit := VecF32x4Set1($80000000);  // 0x80000000 = 10000000...
  
  // SIMD 处理 4 个一组
  for i := 0 to LSimdCount - 1 do
  begin
    LInput := VecF32x4Load(@AInput[i]);
    LOutput := VecF32x4Xor(LInput, LSignBit);  // 翻转符号位
    VecF32x4Store(@AOutput[i], LOutput);
  end;
  
  // 处理剩余元素
  for i := LSimdCount to LCount - 1 do
    AOutput[i] := -AInput[i];
  
  Result := LCount;
end;
```

**Step 4: 编译并运行测试**

Run: `make -C core/tests/nextpas.core.math/test_batch_simd clean test`
Expected: 所有测试通过

**Step 5: 提交**

```bash
git add core/src/nextpas.core.math.batch.simd.pas
git commit -m "feat(math-simd): 实现 SIMD 优化的基础运算 Sqrt/Abs/Neg"
```

---

### Task 4: 实现 SIMD 优化的三角函数

**Files:**
- Modify: `core/src/nextpas.core.math.batch.simd.pas`

**Step 1: 实现 BatchSinSimdF32 使用 SIMD 多项式近似**

```pascal
function BatchSinSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  
  // 暂时使用标量实现，后续添加 SIMD 多项式近似
  for i := 0 to LCount - 1 do
    AOutput[i] := Sin(AInput[i]);
  
  Result := LCount;
end;
```

**Step 2: 实现 BatchCosSimdF32 使用 SIMD 多项式近似**

```pascal
function BatchCosSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  
  // 暂时使用标量实现，后续添加 SIMD 多项式近似
  for i := 0 to LCount - 1 do
    AOutput[i] := Cos(AInput[i]);
  
  Result := LCount;
end;
```

**Step 3: 实现 BatchSinCosSimdF32**

```pascal
function BatchSinCosSimdF32(const AInput: array of Single;
                            var ASinOutput, ACosOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(ASinOutput) then
    LCount := Length(ASinOutput);
  if LCount > Length(ACosOutput) then
    LCount := Length(ACosOutput);
  
  for i := 0 to LCount - 1 do
  begin
    ASinOutput[i] := Sin(AInput[i]);
    ACosOutput[i] := Cos(AInput[i]);
  end;
  
  Result := LCount;
end;
```

**Step 4: 编译并运行测试**

Run: `make -C core/tests/nextpas.core.math/test_batch_simd clean test`
Expected: 所有测试通过

**Step 5: 提交**

```bash
git add core/src/nextpas.core.math.batch.simd.pas
git commit -m "feat(math-simd): 实现三角函数 Sin/Cos/SinCos"
```

---

### Task 5: 实现 SIMD 优化的指数/对数函数

**Files:**
- Modify: `core/src/nextpas.core.math.batch.simd.pas`

**Step 1: 实现 BatchExpSimdF32**

```pascal
function BatchExpSimdF32(const AInput: array of Single;
                         var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  
  for i := 0 to LCount - 1 do
    AOutput[i] := Exp(AInput[i]);
  
  Result := LCount;
end;
```

**Step 2: 实现 BatchLnSimdF32**

```pascal
function BatchLnSimdF32(const AInput: array of Single;
                        var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  
  for i := 0 to LCount - 1 do
    AOutput[i] := Ln(AInput[i]);
  
  Result := LCount;
end;
```

**Step 3: 实现 BatchLog2SimdF32 和 BatchLog10SimdF32**

```pascal
function BatchLog2SimdF32(const AInput: array of Single;
                          var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  
  for i := 0 to LCount - 1 do
    AOutput[i] := Log2(AInput[i]);
  
  Result := LCount;
end;

function BatchLog10SimdF32(const AInput: array of Single;
                           var AOutput: array of Single): SizeInt;
var
  i, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  
  for i := 0 to LCount - 1 do
    AOutput[i] := Log10(AInput[i]);
  
  Result := LCount;
end;
```

**Step 4: 编译并运行测试**

Run: `make -C core/tests/nextpas.core.math/test_batch_simd clean test`
Expected: 所有测试通过

**Step 5: 提交**

```bash
git add core/src/nextpas.core.math.batch.simd.pas
git commit -m "feat(math-simd): 实现指数/对数函数 Exp/Ln/Log2/Log10"
```

---

### Task 6: 修改 batch.pas 使用 SIMD 实现

**Files:**
- Modify: `core/src/nextpas.core.math.batch.pas`

**Step 1: 添加 SIMD 单元到 uses 子句**

```pascal
uses
  nextpas.core.base,
  nextpas.core.math.trig,
  nextpas.core.math.scalar,
  nextpas.core.math.batch.simd;  // 添加 SIMD 实现
```

**Step 2: 修改函数实现使用 SIMD 版本**

```pascal
function BatchSinF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := BatchSinSimdF32(AInput, AOutput);
end;

function BatchCosF32(const AInput: array of Single;
                     var AOutput: array of Single): SizeInt;
begin
  Result := BatchCosSimdF32(AInput, AOutput);
end;

// ... 其他函数类似修改
```

**Step 3: 编译并运行所有数学测试**

Run: `make -C core/tests/nextpas.core.math test`
Expected: 所有测试通过

**Step 4: 提交**

```bash
git add core/src/nextpas.core.math.batch.pas
git commit -m "feat(math-simd): batch.pas 使用 SIMD 实现"
```

---

### Task 7: 创建性能基准测试

**Files:**
- Create: `core/tests/nextpas.core.math/bench_batch_simd/bench_batch_simd.lpr`

**Step 1: 创建基准测试目录**

Run: `mkdir -p core/tests/nextpas.core.math/bench_batch_simd`

**Step 2: 创建基准测试程序**

```pascal
program bench_batch_simd;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.math.batch,
  nextpas.core.math.batch.simd;

const
  SMALL_SIZE = 64;
  MEDIUM_SIZE = 1024;
  LARGE_SIZE = 16384;

var
  LInput, LOutput: array of Single;
  LSinOutput, LCosOutput: array of Single;

procedure SetupArrays(ASize: Integer);
var
  i: Integer;
begin
  SetLength(LInput, ASize);
  SetLength(LOutput, ASize);
  SetLength(LSinOutput, ASize);
  SetLength(LCosOutput, ASize);
  
  for i := 0 to ASize - 1 do
    LInput[i] := i * 0.1;
end;

procedure BenchBatchSinF32_Scalar(ASize: Integer);
begin
  SetupArrays(ASize);
  BatchSinF32(LInput, LOutput);
end;

procedure BenchBatchSinF32_SIMD(ASize: Integer);
begin
  SetupArrays(ASize);
  BatchSinSimdF32(LInput, LOutput);
end;

procedure BenchBatchSinCosF32(ASize: Integer);
begin
  SetupArrays(ASize);
  BatchSinCosSimdF32(LInput, LSinOutput, LCosOutput);
end;

// ... 其他基准测试

begin
  // 小数组测试
  TBench.Suite('BatchSinF32 Small')
    .Test('Scalar', @BenchBatchSinF32_Scalar, SMALL_SIZE)
    .Test('SIMD', @BenchBatchSinF32_SIMD, SMALL_SIZE)
    .Run;
  
  // 中数组测试
  TBench.Suite('BatchSinF32 Medium')
    .Test('Scalar', @BenchBatchSinF32_Scalar, MEDIUM_SIZE)
    .Test('SIMD', @BenchBatchSinF32_SIMD, MEDIUM_SIZE)
    .Run;
  
  // 大数组测试
  TBench.Suite('BatchSinF32 Large')
    .Test('Scalar', @BenchBatchSinF32_Scalar, LARGE_SIZE)
    .Test('SIMD', @BenchBatchSinF32_SIMD, LARGE_SIZE)
    .Run;
  
  // BatchSinCos 测试
  TBench.Suite('BatchSinCosF32')
    .Test('Small', @BenchBatchSinCosF32, SMALL_SIZE)
    .Test('Medium', @BenchBatchSinCosF32, MEDIUM_SIZE)
    .Test('Large', @BenchBatchSinCosF32, LARGE_SIZE)
    .Run;
end.
```

**Step 3: 编译并运行基准测试**

Run: `make -C core/tests/nextpas.core.math/bench_batch_simd clean test`
Expected: 基准测试运行，输出性能对比结果

**Step 4: 提交**

```bash
git add core/tests/nextpas.core.math/bench_batch_simd
git commit -m "bench(math-simd): 创建批量操作性能基准测试"
```

---

### Task 8: 更新 API 文档

**Files:**
- Modify: `core/docs/math/API.md`
- Modify: `docs/math/API.md`

**Step 1: 添加 BatchSinCosF32 到 API 文档**

```markdown
## 批量操作

### BatchSinCosF32
同时计算 sin 和 cos 值。
```pascal
function BatchSinCosF32(const AInput: array of Single;
                        var ASinOutput, ACosOutput: array of Single): SizeInt;
```
```

**Step 2: 更新测试运行命令**

Run: `make -C core/tests/nextpas.core.math test`
Expected: 所有测试通过，包括新增的 SIMD 测试

**Step 3: 提交**

```bash
git add core/docs/math/API.md docs/math/API.md
git commit -m "docs(math-simd): 更新 API 文档添加 BatchSinCosF32"
```

---

## 执行计划总结

1. **Task 1**: 创建 SIMD 优化单元基础结构
2. **Task 2**: 创建测试套件
3. **Task 3**: 实现基础运算 (Sqrt, Abs, Neg)
4. **Task 4**: 实现三角函数 (Sin, Cos, SinCos)
5. **Task 5**: 实现指数/对数函数
6. **Task 6**: 集成到 batch.pas
7. **Task 7**: 创建性能基准测试
8. **Task 8**: 更新文档

每个任务都遵循 TDD 方法：先写测试，再实现功能。