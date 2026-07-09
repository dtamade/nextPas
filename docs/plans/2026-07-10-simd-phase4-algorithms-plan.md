# Phase 4: 算法库扩展实现计划

**分支**: simd-phase4-algorithms  
**目标**: 扩展 SIMD 算法库，覆盖更多应用场景

---

## 任务清单

### 4.1 信号处理算法

#### 4.1.1 FFT/IFFT
- [ ] 定义 FFT 接口
- [ ] 实现基2 FFT 算法
- [ ] 实现 IFFT
- [ ] 添加 SIMD 优化

#### 4.1.2 卷积
- [ ] 定义卷积接口
- [ ] 实现 1D 卷积
- [ ] 实现 2D 卷积
- [ ] 添加 SIMD 优化

### 4.2 线性代数算法

#### 4.2.1 矩阵乘法
- [ ] 定义矩阵乘法接口
- [ ] 实现 naive 矩阵乘法
- [ ] 实现分块矩阵乘法
- [ ] 添加 SIMD 优化

#### 4.2.2 向量操作
- [ ] 优化向量点积
- [ ] 实现向量范数 (L1/L2/∞)
- [ ] 实现向量归一化

### 4.3 图像处理算法

#### 4.3.1 颜色转换
- [ ] 实现 RGB→YUV 转换
- [ ] 实现 YUV→RGB 转换
- [ ] 添加 SIMD 优化

#### 4.3.2 滤波
- [ ] 实现均值滤波
- [ ] 实现高斯滤波
- [ ] 添加 SIMD 优化

### 4.4 机器学习算法

#### 4.4.1 激活函数
- [ ] 实现 ReLU
- [ ] 实现 Sigmoid
- [ ] 实现 Tanh
- [ ] 添加 SIMD 优化

#### 4.4.2 损失函数
- [ ] 实现 MSE 损失
- [ ] 实现 CrossEntropy 损失
- [ ] 添加 SIMD 优化

---

## 实现顺序

1. **第一步**: 实现 FFT/IFFT
2. **第二步**: 实现卷积
3. **第三步**: 实现矩阵乘法
4. **第四步**: 实现颜色转换
5. **第五步**: 实现激活函数
6. **第六步**: 测试验证

---

## 技术细节

### FFT 实现示例

```pascal
procedure SimdFFT(aInput: PComplex; aOutput: PComplex; aN: SizeUInt);
var
  LHalf: SizeUInt;
  LOdd, LEven: array of Complex;
begin
  if aN <= 1 then
  begin
    aOutput^ := aInput^;
    Exit;
  end;

  LHalf := aN div 2;
  SetLength(LOdd, LHalf);
  SetLength(LEven, LHalf);

  // 分离奇偶
  for i := 0 to LHalf - 1 do
  begin
    LEven[i] := aInput[i * 2];
    LOdd[i] := aInput[i * 2 + 1];
  end;

  // 递归 FFT
  SimdFFT(@LEven[0], @aOutput[0], LHalf);
  SimdFFT(@LOdd[0], @aOutput[LHalf], LHalf);

  // 蝶形运算
  for k := 0 to LHalf - 1 do
  begin
    LTW := Exp(-2 * PI * k / aN * I) * aOutput[k + LHalf];
    aOutput[k] := aOutput[k] + LTW;
    aOutput[k + LHalf] := aOutput[k] - LTW;
  end;
end;
```

### 性能目标

| 算法 | 平台 | 目标性能 |
|------|------|----------|
| FFT (1024) | AVX2 | <1μs |
| GEMM (64x64) | AVX2 | <10μs |
| 2D 卷积 (3x3) | AVX2 | <0.5μs/image |
| ReLU (1M) | AVX2 | <0.1ms |

---

## 验证标准

- [ ] FFT/IFFT 实现并通过测试
- [ ] 卷积实现并通过测试
- [ ] 矩阵乘法实现并通过测试
- [ ] 颜色转换实现并通过测试
- [ ] 激活函数实现并通过测试
- [ ] 所有算法性能达标
- [ ] 所有现有测试通过

---

**创建时间**: 2026-07-10  
**维护者**: dtamade
