# nextpas.core.simd.intrinsics.avx512

> **Disposition**: Experimental Isolated (requires `SIMD_BACKEND_AVX512` define). Not part of the default stable public surface.

AVX-512 (Advanced Vector Extensions 512) 指令集支持模块

## 概述

AVX-512 是 Intel 在 2016 年引入的 512-bit SIMD 指令集扩展，提供最宽的向量寄存器和强大的掩码操作能力。这是目前最先进的 x86 SIMD 指令集。

### 特性

- 512-bit 向量寄存器 (zmm0-zmm31)
- 掩码寄存器 (k0-k7)
- 掩码操作和条件执行
- 嵌入式舍入控制
- 冲突检测指令
- 更多寄存器（32 个 ZMM 寄存器）

### 兼容性

- Intel Xeon Phi (Knights Landing, 2016)
- Intel Skylake-X 服务器处理器 (2017)
- Intel Ice Lake 及更新的处理器
- AMD Zen 4 及更新的处理器（部分支持）

**注意**: AVX-512 支持因处理器型号而异，不同的 AVX-512 子集需要单独检测。

## AVX-512 子集

AVX-512 由多个子集组成：

| 子集 | 描述 |
|------|------|
| AVX-512F | 基础指令集（Foundation） |
| AVX-512CD | 冲突检测（Conflict Detection） |
| AVX-512BW | 字节和字操作（Byte and Word） |
| AVX-512DQ | 双字和四字操作（Doubleword and Quadword） |
| AVX-512VL | 向量长度扩展（Vector Length） |
| AVX-512IFMA | 整数融合乘加（Integer Fused Multiply-Add） |
| AVX-512VBMI | 向量字节操作（Vector Byte Manipulation） |
| AVX-512VNNI | 向量神经网络指令（Vector Neural Network Instructions） |
| AVX-512BF16 | BFloat16 支持 |

本模块主要实现 AVX-512F 基础指令。

## 核心类型

### TM512

512-bit 统一向量类型，支持多种数据格式：

```pascal
TM512 = record
  case Integer of
    0: (m512i_u8: array[0..63] of Byte);       // 64个8位无符号整数
    1: (m512i_u16: array[0..31] of Word);      // 32个16位无符号整数
    2: (m512i_u32: array[0..15] of DWord);     // 16个32位无符号整数
    3: (m512i_u64: array[0..7] of QWord);      // 8个64位无符号整数
    4: (m512i_i8: array[0..63] of ShortInt);   // 64个8位有符号整数
    5: (m512i_i16: array[0..31] of SmallInt);  // 32个16位有符号整数
    6: (m512i_i32: array[0..15] of LongInt);   // 16个32位有符号整数
    7: (m512i_i64: array[0..7] of Int64);      // 8个64位有符号整数
    8: (m512_f32: array[0..15] of Single);     // 16个32位单精度浮点数
    9: (m512_f64: array[0..7] of Double);      // 8个64位双精度浮点数
   10: (m512_m256: array[0..1] of TM256);      // 2个256-bit向量
   11: (m512_m128: array[0..3] of TM128);      // 4个128-bit向量
end;
```

### 掩码类型

```pascal
// 8-bit 掩码 (用于 64-bit 元素操作)
__mmask8 = UInt8;

// 16-bit 掩码 (用于 32-bit 元素操作)
__mmask16 = UInt16;

// 32-bit 掩码 (用于 16-bit 元素操作，AVX-512BW)
__mmask32 = UInt32;

// 64-bit 掩码 (用于 8-bit 元素操作，AVX-512BW)
__mmask64 = UInt64;
```

## 掩码寄存器 (k0-k7)

AVX-512 引入了 8 个掩码寄存器，用于条件执行和写掩码。

### 掩码寄存器特性

| 寄存器 | 说明 |
|--------|------|
| k0 | 特殊：始终视为全 1，不能用作写掩码 |
| k1-k7 | 通用掩码寄存器，可用于写掩码和谓词 |

### 掩码操作类型

1. **写掩码（Merging Mask）**: 掩码位为 0 时保留目标寄存器原值
2. **零掩码（Zeroing Mask）**: 掩码位为 0 时将目标元素清零

## 功能分类

### 1. Load / Store 操作

#### avx512_load_ps512 - 对齐加载 512-bit 单精度

- **指令**: `vmovaps zmm, m512`
- **Intel Intrinsic**: `_mm512_load_ps`
- **操作**: 从 64 字节对齐的内存地址加载 512-bit 数据

```pascal
function avx512_load_ps512(const Ptr: Pointer): TM512;
```

#### avx512_loadu_ps512 - 非对齐加载 512-bit 单精度

- **指令**: `vmovups zmm, m512`
- **Intel Intrinsic**: `_mm512_loadu_ps`
- **操作**: 从任意内存地址加载 512-bit 数据

```pascal
function avx512_loadu_ps512(const Ptr: Pointer): TM512;
```

#### avx512_store_ps512 - 对齐存储 512-bit 单精度

- **指令**: `vmovaps m512, zmm`
- **Intel Intrinsic**: `_mm512_store_ps`
- **操作**: 将 512-bit 数据存储到 64 字节对齐的内存地址

```pascal
procedure avx512_store_ps512(var Dest; const Src: TM512);
```

#### avx512_storeu_ps512 - 非对齐存储 512-bit 单精度

- **指令**: `vmovups m512, zmm`
- **Intel Intrinsic**: `_mm512_storeu_ps`
- **操作**: 将 512-bit 数据存储到任意内存地址

```pascal
procedure avx512_storeu_ps512(var Dest; const Src: TM512);
```

### 2. Set / Zero 操作

#### avx512_setzero_ps512 - 清零 512-bit 寄存器

- **指令**: `vpxorq zmm, zmm, zmm`
- **Intel Intrinsic**: `_mm512_setzero_ps`
- **操作**: 将所有 512 位设置为 0

```pascal
function avx512_setzero_ps512: TM512;
```

#### avx512_set1_ps512 - 广播单精度浮点数

- **指令**: `vbroadcastss zmm, r32/m32`
- **Intel Intrinsic**: `_mm512_set1_ps`
- **操作**: 将单个单精度浮点数广播到所有 16 个位置
- **结果**: `result[i] = Value, i = 0..15`

```pascal
function avx512_set1_ps512(Value: Single): TM512;
```

### 3. 浮点算术运算

#### avx512_add_ps512 - 512-bit 单精度加法

- **指令**: `vaddps zmm, zmm, zmm/m512`
- **Intel Intrinsic**: `_mm512_add_ps`
- **操作**: `result[i] = a[i] + b[i], i = 0..15`

```pascal
function avx512_add_ps512(const a, b: TM512): TM512;
```

#### avx512_sub_ps512 - 512-bit 单精度减法

- **指令**: `vsubps zmm, zmm, zmm/m512`
- **Intel Intrinsic**: `_mm512_sub_ps`
- **操作**: `result[i] = a[i] - b[i], i = 0..15`

```pascal
function avx512_sub_ps512(const a, b: TM512): TM512;
```

#### avx512_mul_ps512 - 512-bit 单精度乘法

- **指令**: `vmulps zmm, zmm, zmm/m512`
- **Intel Intrinsic**: `_mm512_mul_ps`
- **操作**: `result[i] = a[i] * b[i], i = 0..15`

```pascal
function avx512_mul_ps512(const a, b: TM512): TM512;
```

#### avx512_div_ps512 - 512-bit 单精度除法

- **指令**: `vdivps zmm, zmm, zmm/m512`
- **Intel Intrinsic**: `_mm512_div_ps`
- **操作**: `result[i] = a[i] / b[i], i = 0..15`

```pascal
function avx512_div_ps512(const a, b: TM512): TM512;
```

### 4. 掩码操作（AVX-512 核心特性）

AVX-512 的掩码操作是其最重要的新特性，允许对向量元素进行条件处理。

#### avx512_mask_add_ps512 - 带掩码的加法（合并模式）

- **指令**: `vaddps zmm {k1}, zmm, zmm/m512`
- **Intel Intrinsic**: `_mm512_mask_add_ps`
- **操作**:
  ```
  for i in 0..15:
    if mask[i] == 1:
      result[i] = a[i] + b[i]
    else:
      result[i] = src[i]  // 保留原值
  ```

```pascal
function avx512_mask_add_ps512(const src, a, b: TM512; mask: UInt16): TM512;
```

**参数**:
- `src`: 当掩码位为 0 时使用的源值
- `a`, `b`: 加法操作数
- `mask`: 16-bit 掩码，每位控制一个元素

#### avx512_maskz_add_ps512 - 带掩码的加法（零掩码模式）

- **指令**: `vaddps zmm {k1}{z}, zmm, zmm/m512`
- **Intel Intrinsic**: `_mm512_maskz_add_ps`
- **操作**:
  ```
  for i in 0..15:
    if mask[i] == 1:
      result[i] = a[i] + b[i]
    else:
      result[i] = 0.0  // 清零
  ```

```pascal
function avx512_maskz_add_ps512(const a, b: TM512; mask: UInt16): TM512;
```

**参数**:
- `a`, `b`: 加法操作数
- `mask`: 16-bit 掩码，每位控制一个元素

## 掩码操作详解

### 掩码模式对比

| 模式 | 函数后缀 | 掩码位 = 0 的行为 | 使用场景 |
|------|----------|-------------------|----------|
| 无掩码 | (无) | N/A | 普通操作 |
| 合并掩码 | `_mask_` | 保留 src 值 | 条件更新 |
| 零掩码 | `_maskz_` | 清零 | 条件计算 |

### 掩码编码

对于单精度浮点（16 个元素），使用 16-bit 掩码：

```
mask = 0b1010_1010_1010_1010
         │ │ │ │ │ │ │ │
         │ │ │ │ │ │ │ └─ element[0]: 不处理
         │ │ │ │ │ │ └─── element[1]: 处理
         │ │ │ │ │ └───── element[2]: 不处理
         │ │ │ │ └─────── element[3]: 处理
         ... (继续)
```

## 常见 AVX-512 指令参考

以下是 AVX-512 中常见指令的参考，虽然部分尚未在本模块中实现。

### 浮点运算

| 指令 | 操作 | Intel Intrinsic |
|------|------|-----------------|
| `vaddps zmm` | 16x 单精度加法 | `_mm512_add_ps` |
| `vaddpd zmm` | 8x 双精度加法 | `_mm512_add_pd` |
| `vsubps zmm` | 16x 单精度减法 | `_mm512_sub_ps` |
| `vmulps zmm` | 16x 单精度乘法 | `_mm512_mul_ps` |
| `vdivps zmm` | 16x 单精度除法 | `_mm512_div_ps` |
| `vsqrtps zmm` | 16x 单精度平方根 | `_mm512_sqrt_ps` |
| `vfmadd132ps` | 融合乘加 a*c+b | `_mm512_fmadd_ps` |
| `vfmadd213ps` | 融合乘加 b*a+c | `_mm512_fmadd_ps` |
| `vfmadd231ps` | 融合乘加 c*b+a | `_mm512_fmadd_ps` |

### 整数运算 (AVX-512F)

| 指令 | 操作 | Intel Intrinsic |
|------|------|-----------------|
| `vpaddd zmm` | 16x 32-bit 整数加法 | `_mm512_add_epi32` |
| `vpaddq zmm` | 8x 64-bit 整数加法 | `_mm512_add_epi64` |
| `vpsubd zmm` | 16x 32-bit 整数减法 | `_mm512_sub_epi32` |
| `vpmulld zmm` | 16x 32-bit 整数乘法 | `_mm512_mullo_epi32` |
| `vpandd zmm` | 16x 32-bit 按位 AND | `_mm512_and_epi32` |
| `vpord zmm` | 16x 32-bit 按位 OR | `_mm512_or_epi32` |
| `vpxord zmm` | 16x 32-bit 按位 XOR | `_mm512_xor_epi32` |

### 比较操作

| 指令 | 操作 | Intel Intrinsic |
|------|------|-----------------|
| `vcmpps zmm, imm8` | 16x 单精度比较 | `_mm512_cmp_ps_mask` |
| `vpcmpeqd zmm` | 16x 32-bit 等于比较 | `_mm512_cmpeq_epi32_mask` |
| `vpcmpgtd zmm` | 16x 32-bit 大于比较 | `_mm512_cmpgt_epi32_mask` |

### 比较操作的 imm8 值

用于 `vcmpps` / `vcmppd` 指令：

| imm8 | 名称 | 描述 |
|------|------|------|
| 0 | EQ_OQ | 等于（有序，安静） |
| 1 | LT_OS | 小于（有序，信号） |
| 2 | LE_OS | 小于等于（有序，信号） |
| 4 | NEQ_UQ | 不等于（无序，安静） |
| 5 | NLT_US | 不小于（无序，信号） |
| 6 | NLE_US | 不小于等于（无序，信号） |
| 8 | EQ_UQ | 等于（无序，安静） |
| 9 | NGE_US | 不大于等于（无序，信号） |
| 10 | NGT_US | 不大于（无序，信号） |
| 13 | GE_OS | 大于等于（有序，信号） |
| 14 | GT_OS | 大于（有序，信号） |
| 17 | EQ_OS | 等于（有序，信号） |
| 21 | LT_OQ | 小于（有序，安静） |
| 22 | LE_OQ | 小于等于（有序，安静） |
| 25 | UNORD_S | 无序（信号） |
| 26 | NEQ_US | 不等于（无序，信号） |
| 29 | GE_OQ | 大于等于（有序，安静） |
| 30 | GT_OQ | 大于（有序，安静） |

### 掩码操作指令

| 指令 | 操作 | 描述 |
|------|------|------|
| `kandw k, k, k` | k = k AND k | 掩码按位 AND |
| `korw k, k, k` | k = k OR k | 掩码按位 OR |
| `kxorw k, k, k` | k = k XOR k | 掩码按位 XOR |
| `knotw k, k` | k = NOT k | 掩码按位 NOT |
| `kortestw k, k` | 测试掩码 | 设置 ZF/CF 标志 |
| `ktestw k, k` | 测试掩码位 | 设置 ZF/CF 标志 |
| `kmovw k, r/m` | 移动掩码 | 在 k 寄存器和通用寄存器间移动 |

### 数据重排

| 指令 | 操作 | Intel Intrinsic |
|------|------|-----------------|
| `vpermps zmm` | 置换单精度 | `_mm512_permutexvar_ps` |
| `vpermd zmm` | 置换 32-bit 整数 | `_mm512_permutexvar_epi32` |
| `vpermq zmm` | 置换 64-bit 整数 | `_mm512_permutexvar_epi64` |
| `vshufps zmm` | 混洗单精度 | `_mm512_shuffle_ps` |
| `valignq zmm` | 对齐 64-bit 元素 | `_mm512_alignr_epi64` |

### 广播指令

| 指令 | 操作 | Intel Intrinsic |
|------|------|-----------------|
| `vbroadcastss zmm` | 广播单精度 | `_mm512_broadcastss_ps` |
| `vbroadcastsd zmm` | 广播双精度 | `_mm512_broadcastsd_pd` |
| `vpbroadcastd zmm` | 广播 32-bit 整数 | `_mm512_broadcastd_epi32` |
| `vpbroadcastq zmm` | 广播 64-bit 整数 | `_mm512_broadcastq_epi64` |

## 使用示例

### 基本向量运算

```pascal
var
  a, b, result: TM512;
begin
  // 设置两个向量
  a := avx512_set1_ps512(10.0);  // 所有元素设置为 10.0
  b := avx512_set1_ps512(3.0);   // 所有元素设置为 3.0

  // 向量加法
  result := avx512_add_ps512(a, b);  // 所有元素为 13.0

  // 向量乘法
  result := avx512_mul_ps512(a, b);  // 所有元素为 30.0
end;
```

### 内存操作

```pascal
var
  data: array[0..15] of Single;
  vec: TM512;
  i: Integer;
begin
  // 初始化数据
  for i := 0 to 15 do
    data[i] := i + 1;

  // 从内存加载
  vec := avx512_loadu_ps512(@data[0]);

  // 处理数据（乘以 2）
  vec := avx512_add_ps512(vec, vec);

  // 存储回内存
  avx512_storeu_ps512(data, vec);
end;
```

### 掩码操作（合并模式）

```pascal
var
  src, a, b, result: TM512;
  mask: UInt16;
begin
  // 设置源值和操作数
  src := avx512_set1_ps512(0.0);   // 默认值
  a := avx512_set1_ps512(10.0);
  b := avx512_set1_ps512(5.0);

  // 只计算偶数索引的元素
  mask := $5555;  // 0101_0101_0101_0101 (偶数位为1)

  // 带掩码的加法
  result := avx512_mask_add_ps512(src, a, b, mask);
  // result[0] = 15.0 (计算)
  // result[1] = 0.0  (保留src)
  // result[2] = 15.0 (计算)
  // result[3] = 0.0  (保留src)
  // ...
end;
```

### 掩码操作（零掩码模式）

```pascal
var
  a, b, result: TM512;
  mask: UInt16;
begin
  a := avx512_set1_ps512(10.0);
  b := avx512_set1_ps512(5.0);

  // 只计算前8个元素
  mask := $00FF;  // 低8位为1

  // 带零掩码的加法
  result := avx512_maskz_add_ps512(a, b, mask);
  // result[0..7] = 15.0 (计算)
  // result[8..15] = 0.0 (清零)
end;
```

### 条件处理示例

```pascal
var
  values, threshold, result, src: TM512;
  mask: UInt16;
  i: Integer;
begin
  // 初始化数据
  for i := 0 to 15 do
    values.m512_f32[i] := i - 8;  // [-8, -7, ..., 6, 7]

  threshold := avx512_set1_ps512(0.0);
  src := avx512_setzero_ps512();

  // 创建掩码：values > 0
  mask := 0;
  for i := 0 to 15 do
    if values.m512_f32[i] > 0 then
      mask := mask or (1 shl i);

  // 只对正数进行处理
  result := avx512_mask_add_ps512(src, values, values, mask);
  // 正数元素翻倍，其他为0
end;
```

## 实现说明

当前实现是纯 Pascal 模拟版本，用于：

1. **跨平台兼容性** - 在不支持 AVX-512 的平台上提供一致的 API
2. **开发和测试** - 便于调试和验证算法正确性
3. **教学目的** - 清晰展示每个指令的语义

已实现的功能：
- 基本加载/存储操作
- Set/Zero 操作
- 浮点算术运算（加减乘除）
- 掩码操作（合并模式和零掩码模式）

在支持 AVX-512 的平台上，可以通过内联汇编或编译器内置函数来优化性能。

## 性能考虑

1. **内存对齐** - 64 字节对齐的内存访问通常更快
2. **批量处理** - 充分利用 SIMD 的 16-way 并行性
3. **掩码操作** - 比分支更高效的条件处理
4. **频率降档** - 某些处理器在使用 AVX-512 时会降低时钟频率
5. **热路径考虑** - 在频繁调用的代码中注意 AVX-512 的热效应

### AVX-512 频率影响

在某些 Intel 处理器上，使用 AVX-512 指令可能导致 CPU 降频：

| 指令类型 | 频率影响 |
|----------|----------|
| 标量/128-bit | 无影响 |
| AVX/AVX2 (256-bit) | 轻微降频 |
| AVX-512 轻量级 | 中等降频 |
| AVX-512 重量级 | 显著降频 |

建议在性能关键的应用中进行基准测试，以确定 AVX-512 是否带来净收益。

## 与 SSE/AVX/AVX2 的关系

| 指令集 | 向量宽度 | 寄存器数量 | 掩码寄存器 |
|--------|----------|------------|------------|
| SSE | 128-bit | 8/16 (xmm) | 无 |
| AVX | 256-bit | 16 (ymm) | 无 |
| AVX2 | 256-bit | 16 (ymm) | 无 |
| AVX-512 | 512-bit | 32 (zmm) | 8 (k0-k7) |

AVX-512 是 AVX2 的超集，大多数 AVX2 指令在 AVX-512 中都有对应的 512-bit 版本，并增加了掩码操作能力。

## 检测 AVX-512 支持

在使用 AVX-512 指令前，应检测处理器支持：

```pascal
// 伪代码 - 实际实现需要使用 CPUID 指令
function HasAVX512F: Boolean;
begin
  // 检查 CPUID.(EAX=7, ECX=0):EBX.AVX512F[bit 16]
end;

function HasAVX512DQ: Boolean;
begin
  // 检查 CPUID.(EAX=7, ECX=0):EBX.AVX512DQ[bit 17]
end;

function HasAVX512BW: Boolean;
begin
  // 检查 CPUID.(EAX=7, ECX=0):EBX.AVX512BW[bit 30]
end;

function HasAVX512VL: Boolean;
begin
  // 检查 CPUID.(EAX=7, ECX=0):EBX.AVX512VL[bit 31]
end;
```

## 扩展方向

1. **整数运算** - 添加 32-bit/64-bit 整数算术指令
2. **比较操作** - 添加各种比较指令并返回掩码
3. **置换操作** - 添加数据重排指令
4. **融合乘加** - 添加 FMA 指令支持
5. **AVX-512BW** - 添加字节和字级别的操作
6. **AVX-512VL** - 添加 128-bit 和 256-bit 掩码版本
