# SIMD 高性能计算 API (G7-G10)

## GEMM — 矩阵乘法

### GemmBlockedF32

```pascal
procedure GemmBlockedF32(AA, AB, AC: PSingle;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);
```

计算 `C[M,N] = A[M,K] * B[K,N]`，使用 6×16 AVX2+FMA 微内核 + 三层 cache tiling。

- **AA**: A 矩阵指针，行优先 [M, K]
- **AB**: B 矩阵指针，行优先 [K, N]
- **AC**: C 矩阵指针，行优先 [M, N]（输出，无需预清零）
- **ALdA/ALdB/ALdC**: 各矩阵的行步长（元素数）
- 峰值性能: ~35 GFLOPS (单核 AVX2+FMA)

### GemmBlockedF64

```pascal
procedure GemmBlockedF64(AA, AB, AC: PDouble;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);
```

F64 版本，4×8 AVX2 微内核。

### GemmParallelF32

```pascal
procedure GemmParallelF32(AA, AB, AC: PSingle;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt; ANumThreads: SizeUInt = 0);
```

多线程 GEMM，M 维度并行分割。`ANumThreads=0` 自动检测 CPU 数。

---

## FFT — 快速傅里叶变换

### TSimdFftPlanF32

```pascal
var Plan := TSimdFftPlanF32.Create(1024);
Plan.Execute(Data, sfdForward);   // 正变换
Plan.Execute(Data, sfdInverse);   // 逆变换
Plan.ExecuteBatch(Data, 8, sfdForward);  // 8 个缓冲区批量
Plan.Free;
```

预计算 twiddle factor，多次调用无额外分配。峰值 2.8 GFLOPS。

### FftRadix2F32

```pascal
procedure FftRadix2F32(AData: PSimdComplexF32; ACount: SizeUInt;
  ADirection: TSimdFftDirection);
```

一次性 FFT（每次调用重新计算 twiddle）。ACount 必须是 2 的幂。

### RealFftF32

```pascal
procedure RealFftF32(AInput: PSingle; AOutput: PSimdComplexF32; ACount: SizeUInt);
```

实数 FFT，使用 half-size trick（N/2 复数 FFT + unpack）。输出 N+1 个复数点。

---

## 量化推理

### QuantizeSymmetricF32ToI8

```pascal
procedure QuantizeSymmetricF32ToI8(ASrc: PSingle; ADst: PInt8;
  ACount: SizeUInt; out AScale: Single);
```

对称量化：`scale = absmax / 127`，`q = round(x / scale)`。

### GemmQuantizedI8_PackedB

```pascal
procedure GemmQuantizedI8_PackedB(AA: PInt8; AB: PInt8; AC: PSingle;
  AM, AN, AK: SizeUInt; AScaleA, AScaleB: Single);
```

INT8 GEMM，B 为 [N, K] 行优先布局。使用 SSE2 `pmovsxbw` + `pmaddwd` 加速。
输出 `C[i,j] = sum(A[i,k] * B[j,k]) * scaleA * scaleB`。
