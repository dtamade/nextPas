# nextpas.core.simd.intrinsics.avx2

> **Disposition**: Active Leaf. Not part of the default stable public surface.

AVX2 (Advanced Vector Extensions 2) 指令集支持模块

## 概述

AVX2 是 Intel 在 2013 年引入的 256-bit SIMD 指令集扩展，将大部分 SSE 整数指令扩展到 256-bit。这是现代高性能计算中最常用的 SIMD 指令集之一。

### 特性

- 256-bit 向量寄存器 (ymm0-ymm15)
- 256-bit 整数运算（将 SSE2 整数指令扩展到 256-bit）
- 变量移位指令（每个元素可以有不同的移位量）
- 聚集加载指令（从非连续内存地址加载数据）
- 广播指令（将标量值广播到所有向量元素）
- 置换指令（跨 128-bit 边界的数据重排）

### 兼容性

- Intel Haswell (2013) 及更新的处理器
- AMD Excavator (2015) 及更新的处理器
- 大多数现代桌面和服务器处理器均支持

## 核心类型

### TM256

256-bit 统一向量类型，支持多种数据格式：

```pascal
TM256 = record
  case Integer of
    0: (m256i_u8: array[0..31] of Byte);       // 32个8位无符号整数
    1: (m256i_u16: array[0..15] of Word);      // 16个16位无符号整数
    2: (m256i_u32: array[0..7] of DWord);      // 8个32位无符号整数
    3: (m256i_u64: array[0..3] of QWord);      // 4个64位无符号整数
    4: (m256i_i8: array[0..31] of ShortInt);   // 32个8位有符号整数
    5: (m256i_i16: array[0..15] of SmallInt);  // 16个16位有符号整数
    6: (m256i_i32: array[0..7] of LongInt);    // 8个32位有符号整数
    7: (m256i_i64: array[0..3] of Int64);      // 4个64位有符号整数
    8: (m256_f32: array[0..7] of Single);      // 8个32位单精度浮点数
    9: (m256_f64: array[0..3] of Double);      // 4个64位双精度浮点数
   10: (m256_m128: array[0..1] of TM128);      // 2个128-bit向量
end;
```

## 功能分类

### 1. Load / Store 操作

#### avx2_load_si256 - 对齐加载 256-bit 整数

- **指令**: `vmovdqa ymm, m256`
- **Intel Intrinsic**: `_mm256_load_si256`
- **操作**: 从 32 字节对齐的内存地址加载 256-bit 数据

```pascal
function avx2_load_si256(const Ptr: Pointer): TM256;
```

#### avx2_loadu_si256 - 非对齐加载 256-bit 整数

- **指令**: `vmovdqu ymm, m256`
- **Intel Intrinsic**: `_mm256_loadu_si256`
- **操作**: 从任意内存地址加载 256-bit 数据

```pascal
function avx2_loadu_si256(const Ptr: Pointer): TM256;
```

#### avx2_store_si256 - 对齐存储 256-bit 整数

- **指令**: `vmovdqa m256, ymm`
- **Intel Intrinsic**: `_mm256_store_si256`
- **操作**: 将 256-bit 数据存储到 32 字节对齐的内存地址

```pascal
procedure avx2_store_si256(var Dest; const Src: TM256);
```

#### avx2_storeu_si256 - 非对齐存储 256-bit 整数

- **指令**: `vmovdqu m256, ymm`
- **Intel Intrinsic**: `_mm256_storeu_si256`
- **操作**: 将 256-bit 数据存储到任意内存地址

```pascal
procedure avx2_storeu_si256(var Dest; const Src: TM256);
```

### 2. Set / Zero 操作

#### avx2_setzero_si256 - 清零 256-bit 寄存器

- **指令**: `vpxor ymm, ymm, ymm`
- **Intel Intrinsic**: `_mm256_setzero_si256`
- **操作**: 将所有 256 位设置为 0

```pascal
function avx2_setzero_si256: TM256;
```

#### avx2_set1_epi32 - 广播 32-bit 整数

- **指令**: `vpbroadcastd ymm, r32/m32`
- **Intel Intrinsic**: `_mm256_set1_epi32`
- **操作**: 将单个 32-bit 整数广播到所有 8 个位置
- **结果**: `result[i] = Value, i = 0..7`

```pascal
function avx2_set1_epi32(Value: LongInt): TM256;
```

#### avx2_set1_epi16 - 广播 16-bit 整数

- **指令**: `vpbroadcastw ymm, r16/m16`
- **Intel Intrinsic**: `_mm256_set1_epi16`
- **操作**: 将单个 16-bit 整数广播到所有 16 个位置
- **结果**: `result[i] = Value, i = 0..15`

```pascal
function avx2_set1_epi16(Value: SmallInt): TM256;
```

#### avx2_set1_epi8 - 广播 8-bit 整数

- **指令**: `vpbroadcastb ymm, r8/m8`
- **Intel Intrinsic**: `_mm256_set1_epi8`
- **操作**: 将单个 8-bit 整数广播到所有 32 个位置
- **结果**: `result[i] = Value, i = 0..31`

```pascal
function avx2_set1_epi8(Value: ShortInt): TM256;
```

### 3. 整数算术运算

#### 加法操作

##### avx2_add_epi32 - 256-bit 32-bit 整数加法

- **指令**: `vpaddd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_add_epi32`
- **操作**: `result[i] = a[i] + b[i], i = 0..7`

```pascal
function avx2_add_epi32(const a, b: TM256): TM256;
```

##### avx2_add_epi16 - 256-bit 16-bit 整数加法

- **指令**: `vpaddw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_add_epi16`
- **操作**: `result[i] = a[i] + b[i], i = 0..15`

```pascal
function avx2_add_epi16(const a, b: TM256): TM256;
```

##### avx2_add_epi8 - 256-bit 8-bit 整数加法

- **指令**: `vpaddb ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_add_epi8`
- **操作**: `result[i] = a[i] + b[i], i = 0..31`

```pascal
function avx2_add_epi8(const a, b: TM256): TM256;
```

#### 减法操作

##### avx2_sub_epi32 - 256-bit 32-bit 整数减法

- **指令**: `vpsubd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_sub_epi32`
- **操作**: `result[i] = a[i] - b[i], i = 0..7`

```pascal
function avx2_sub_epi32(const a, b: TM256): TM256;
```

##### avx2_sub_epi16 - 256-bit 16-bit 整数减法

- **指令**: `vpsubw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_sub_epi16`
- **操作**: `result[i] = a[i] - b[i], i = 0..15`

```pascal
function avx2_sub_epi16(const a, b: TM256): TM256;
```

##### avx2_sub_epi8 - 256-bit 8-bit 整数减法

- **指令**: `vpsubb ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_sub_epi8`
- **操作**: `result[i] = a[i] - b[i], i = 0..31`

```pascal
function avx2_sub_epi8(const a, b: TM256): TM256;
```

#### 乘法操作

##### avx2_mullo_epi32 - 256-bit 32-bit 整数乘法（低位）

- **指令**: `vpmulld ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_mullo_epi32`
- **操作**: `result[i] = (a[i] * b[i])[31:0], i = 0..7`
- **说明**: 返回乘积的低 32 位

```pascal
function avx2_mullo_epi32(const a, b: TM256): TM256;
```

##### avx2_mullo_epi16 - 256-bit 16-bit 整数乘法（低位）

- **指令**: `vpmullw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_mullo_epi16`
- **操作**: `result[i] = (a[i] * b[i])[15:0], i = 0..15`
- **说明**: 返回乘积的低 16 位

```pascal
function avx2_mullo_epi16(const a, b: TM256): TM256;
```

##### avx2_mulhi_epi16 - 256-bit 16-bit 有符号整数乘法（高位）

- **指令**: `vpmulhw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_mulhi_epi16`
- **操作**: `result[i] = (a[i] * b[i])[31:16], i = 0..15`
- **说明**: 返回有符号乘积的高 16 位

```pascal
function avx2_mulhi_epi16(const a, b: TM256): TM256;
```

##### avx2_mulhi_epu16 - 256-bit 16-bit 无符号整数乘法（高位）

- **指令**: `vpmulhuw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_mulhi_epu16`
- **操作**: `result[i] = (a[i] * b[i])[31:16], i = 0..15`
- **说明**: 返回无符号乘积的高 16 位

```pascal
function avx2_mulhi_epu16(const a, b: TM256): TM256;
```

### 4. 逻辑操作

#### avx2_and_si256 - 按位 AND

- **指令**: `vpand ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_and_si256`
- **操作**: `result = a AND b`

```pascal
function avx2_and_si256(const a, b: TM256): TM256;
```

#### avx2_andnot_si256 - 按位 AND NOT

- **指令**: `vpandn ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_andnot_si256`
- **操作**: `result = (NOT a) AND b`

```pascal
function avx2_andnot_si256(const a, b: TM256): TM256;
```

#### avx2_or_si256 - 按位 OR

- **指令**: `vpor ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_or_si256`
- **操作**: `result = a OR b`

```pascal
function avx2_or_si256(const a, b: TM256): TM256;
```

#### avx2_xor_si256 - 按位 XOR

- **指令**: `vpxor ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_xor_si256`
- **操作**: `result = a XOR b`

```pascal
function avx2_xor_si256(const a, b: TM256): TM256;
```

### 5. 比较操作

#### 等于比较

##### avx2_cmpeq_epi32 - 32-bit 整数等于比较

- **指令**: `vpcmpeqd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_cmpeq_epi32`
- **操作**: `result[i] = (a[i] == b[i]) ? 0xFFFFFFFF : 0x00000000, i = 0..7`

```pascal
function avx2_cmpeq_epi32(const a, b: TM256): TM256;
```

##### avx2_cmpeq_epi16 - 16-bit 整数等于比较

- **指令**: `vpcmpeqw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_cmpeq_epi16`
- **操作**: `result[i] = (a[i] == b[i]) ? 0xFFFF : 0x0000, i = 0..15`

```pascal
function avx2_cmpeq_epi16(const a, b: TM256): TM256;
```

##### avx2_cmpeq_epi8 - 8-bit 整数等于比较

- **指令**: `vpcmpeqb ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_cmpeq_epi8`
- **操作**: `result[i] = (a[i] == b[i]) ? 0xFF : 0x00, i = 0..31`

```pascal
function avx2_cmpeq_epi8(const a, b: TM256): TM256;
```

#### 大于比较

##### avx2_cmpgt_epi32 - 32-bit 有符号整数大于比较

- **指令**: `vpcmpgtd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_cmpgt_epi32`
- **操作**: `result[i] = (a[i] > b[i]) ? 0xFFFFFFFF : 0x00000000, i = 0..7`

```pascal
function avx2_cmpgt_epi32(const a, b: TM256): TM256;
```

##### avx2_cmpgt_epi16 - 16-bit 有符号整数大于比较

- **指令**: `vpcmpgtw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_cmpgt_epi16`
- **操作**: `result[i] = (a[i] > b[i]) ? 0xFFFF : 0x0000, i = 0..15`

```pascal
function avx2_cmpgt_epi16(const a, b: TM256): TM256;
```

##### avx2_cmpgt_epi8 - 8-bit 有符号整数大于比较

- **指令**: `vpcmpgtb ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_cmpgt_epi8`
- **操作**: `result[i] = (a[i] > b[i]) ? 0xFF : 0x00, i = 0..31`

```pascal
function avx2_cmpgt_epi8(const a, b: TM256): TM256;
```

### 6. Min / Max 操作

#### 最大值

##### avx2_max_epi32 - 32-bit 有符号整数最大值

- **指令**: `vpmaxsd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_max_epi32`
- **操作**: `result[i] = max(a[i], b[i]), i = 0..7`

```pascal
function avx2_max_epi32(const a, b: TM256): TM256;
```

##### avx2_max_epi16 - 16-bit 有符号整数最大值

- **指令**: `vpmaxsw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_max_epi16`
- **操作**: `result[i] = max(a[i], b[i]), i = 0..15`

```pascal
function avx2_max_epi16(const a, b: TM256): TM256;
```

##### avx2_max_epi8 - 8-bit 有符号整数最大值

- **指令**: `vpmaxsb ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_max_epi8`
- **操作**: `result[i] = max(a[i], b[i]), i = 0..31`

```pascal
function avx2_max_epi8(const a, b: TM256): TM256;
```

#### 最小值

##### avx2_min_epi32 - 32-bit 有符号整数最小值

- **指令**: `vpminsd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_min_epi32`
- **操作**: `result[i] = min(a[i], b[i]), i = 0..7`

```pascal
function avx2_min_epi32(const a, b: TM256): TM256;
```

##### avx2_min_epi16 - 16-bit 有符号整数最小值

- **指令**: `vpminsw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_min_epi16`
- **操作**: `result[i] = min(a[i], b[i]), i = 0..15`

```pascal
function avx2_min_epi16(const a, b: TM256): TM256;
```

##### avx2_min_epi8 - 8-bit 有符号整数最小值

- **指令**: `vpminsb ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_min_epi8`
- **操作**: `result[i] = min(a[i], b[i]), i = 0..31`

```pascal
function avx2_min_epi8(const a, b: TM256): TM256;
```

### 7. 变量移位操作（AVX2 新特性）

AVX2 引入了变量移位指令，允许每个元素使用不同的移位量。

#### avx2_sllv_epi32 - 变量左移 32-bit

- **指令**: `vpsllvd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_sllv_epi32`
- **操作**: `result[i] = a[i] << count[i], i = 0..7`
- **说明**: 如果 count[i] >= 32，结果为 0

```pascal
function avx2_sllv_epi32(const a, count: TM256): TM256;
```

#### avx2_sllv_epi64 - 变量左移 64-bit

- **指令**: `vpsllvq ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_sllv_epi64`
- **操作**: `result[i] = a[i] << count[i], i = 0..3`
- **说明**: 如果 count[i] >= 64，结果为 0

```pascal
function avx2_sllv_epi64(const a, count: TM256): TM256;
```

#### avx2_srlv_epi32 - 变量逻辑右移 32-bit

- **指令**: `vpsrlvd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_srlv_epi32`
- **操作**: `result[i] = a[i] >> count[i] (逻辑), i = 0..7`
- **说明**: 如果 count[i] >= 32，结果为 0

```pascal
function avx2_srlv_epi32(const a, count: TM256): TM256;
```

#### avx2_srlv_epi64 - 变量逻辑右移 64-bit

- **指令**: `vpsrlvq ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_srlv_epi64`
- **操作**: `result[i] = a[i] >> count[i] (逻辑), i = 0..3`
- **说明**: 如果 count[i] >= 64，结果为 0

```pascal
function avx2_srlv_epi64(const a, count: TM256): TM256;
```

#### avx2_srav_epi32 - 变量算术右移 32-bit

- **指令**: `vpsravd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_srav_epi32`
- **操作**: `result[i] = a[i] >> count[i] (算术), i = 0..7`
- **说明**: 保留符号位；如果 count[i] >= 32，使用 31 作为移位量

```pascal
function avx2_srav_epi32(const a, count: TM256): TM256;
```

### 8. 广播操作（AVX2 新特性）

AVX2 提供了专用的广播指令，比 AVX 的 permute 指令更高效。

#### avx2_broadcastss_ps - 广播单精度浮点数

- **指令**: `vbroadcastss ymm, xmm/m32`
- **Intel Intrinsic**: `_mm256_broadcastss_ps`
- **操作**: 将 a[0] 广播到所有 8 个单精度位置
- **结果**: `result[i] = a[0], i = 0..7`

```pascal
function avx2_broadcastss_ps(const a: TM128): TM256;
```

#### avx2_broadcastsd_pd - 广播双精度浮点数

- **指令**: `vbroadcastsd ymm, xmm/m64`
- **Intel Intrinsic**: `_mm256_broadcastsd_pd`
- **操作**: 将 a[0] 广播到所有 4 个双精度位置
- **结果**: `result[i] = a[0], i = 0..3`

```pascal
function avx2_broadcastsd_pd(const a: TM128): TM256;
```

#### avx2_broadcastsi128_si256 - 广播 128-bit 整数

- **指令**: `vbroadcasti128 ymm, m128`
- **Intel Intrinsic**: `_mm256_broadcastsi128_si256`
- **操作**: 将 128-bit 数据复制到高低两个 128-bit 通道
- **结果**: `result[127:0] = a, result[255:128] = a`

```pascal
function avx2_broadcastsi128_si256(const a: TM128): TM256;
```

### 9. 聚集加载操作（AVX2 新特性）

聚集（Gather）指令允许从非连续的内存地址加载数据。

**实现状态**: 以下函数已提供纯 Pascal 回退实现，语义与 AVX2 intrinsic 保持一致。

#### avx2_gather_epi32 - 聚集加载 32-bit 整数

- **指令**: `vpgatherdd ymm, vm32y, ymm`
- **Intel Intrinsic**: `_mm256_i32gather_epi32`
- **操作**: `result[i] = *(base_addr + vindex[i] * scale), i = 0..7`
- **scale**: 1, 2, 4, 或 8

```pascal
function avx2_gather_epi32(const base_addr: Pointer; const vindex: TM256; scale: Integer): TM256;
```

#### avx2_gather_epi64 - 聚集加载 64-bit 整数

- **指令**: `vpgatherdq ymm, vm32x, ymm`
- **Intel Intrinsic**: `_mm256_i32gather_epi64`
- **操作**: 使用 128-bit 索引加载 4 个 64-bit 整数

```pascal
function avx2_gather_epi64(const base_addr: Pointer; const vindex: TM128; scale: Integer): TM256;
```

#### avx2_gather_ps - 聚集加载单精度浮点数

- **指令**: `vgatherdps ymm, vm32y, ymm`
- **Intel Intrinsic**: `_mm256_i32gather_ps`
- **操作**: 使用 32-bit 索引加载 8 个单精度浮点数

```pascal
function avx2_gather_ps(const base_addr: Pointer; const vindex: TM256; scale: Integer): TM256;
```

#### avx2_gather_pd - 聚集加载双精度浮点数

- **指令**: `vgatherdpd ymm, vm32x, ymm`
- **Intel Intrinsic**: `_mm256_i32gather_pd`
- **操作**: 使用 32-bit 索引加载 4 个双精度浮点数

```pascal
function avx2_gather_pd(const base_addr: Pointer; const vindex: TM128; scale: Integer): TM256;
```

### 10. 打包 / 解包操作

**实现状态**: 以下函数已提供纯 Pascal 回退实现，语义与 AVX2 intrinsic 保持一致。

#### 打包操作

##### avx2_packs_epi32 - 有符号饱和打包 32-bit 到 16-bit

- **指令**: `vpackssdw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_packs_epi32`
- **操作**: 将 8 个 32-bit 有符号整数饱和打包为 16 个 16-bit 有符号整数

```pascal
function avx2_packs_epi32(const a, b: TM256): TM256;
```

##### avx2_packs_epi16 - 有符号饱和打包 16-bit 到 8-bit

- **指令**: `vpacksswb ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_packs_epi16`
- **操作**: 将 16 个 16-bit 有符号整数饱和打包为 32 个 8-bit 有符号整数

```pascal
function avx2_packs_epi16(const a, b: TM256): TM256;
```

##### avx2_packus_epi32 - 无符号饱和打包 32-bit 到 16-bit

- **指令**: `vpackusdw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_packus_epi32`

```pascal
function avx2_packus_epi32(const a, b: TM256): TM256;
```

##### avx2_packus_epi16 - 无符号饱和打包 16-bit 到 8-bit

- **指令**: `vpackuswb ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_packus_epi16`

```pascal
function avx2_packus_epi16(const a, b: TM256): TM256;
```

#### 解包操作

##### avx2_unpackhi_epi32 - 解包高位 32-bit 元素

- **指令**: `vpunpckhdq ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_unpackhi_epi32`

```pascal
function avx2_unpackhi_epi32(const a, b: TM256): TM256;
```

##### avx2_unpackhi_epi16 - 解包高位 16-bit 元素

- **指令**: `vpunpckhwd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_unpackhi_epi16`

```pascal
function avx2_unpackhi_epi16(const a, b: TM256): TM256;
```

##### avx2_unpackhi_epi8 - 解包高位 8-bit 元素

- **指令**: `vpunpckhbw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_unpackhi_epi8`

```pascal
function avx2_unpackhi_epi8(const a, b: TM256): TM256;
```

##### avx2_unpacklo_epi32 - 解包低位 32-bit 元素

- **指令**: `vpunpckldq ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_unpacklo_epi32`

```pascal
function avx2_unpacklo_epi32(const a, b: TM256): TM256;
```

##### avx2_unpacklo_epi16 - 解包低位 16-bit 元素

- **指令**: `vpunpcklwd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_unpacklo_epi16`

```pascal
function avx2_unpacklo_epi16(const a, b: TM256): TM256;
```

##### avx2_unpacklo_epi8 - 解包低位 8-bit 元素

- **指令**: `vpunpcklbw ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_unpacklo_epi8`

```pascal
function avx2_unpacklo_epi8(const a, b: TM256): TM256;
```

### 11. 置换操作（AVX2 新特性）

AVX2 引入了跨 128-bit 边界的置换指令。

**实现状态**: 以下函数已提供纯 Pascal 回退实现，语义与 AVX2 intrinsic 保持一致。

#### avx2_permute4x64_epi64 - 置换 4 个 64-bit 整数

- **指令**: `vpermq ymm, ymm/m256, imm8`
- **Intel Intrinsic**: `_mm256_permute4x64_epi64`
- **操作**: 根据 imm8 重排 4 个 64-bit 元素
- **imm8 编码**: 每 2 位选择一个源元素索引

```pascal
function avx2_permute4x64_epi64(const a: TM256; imm8: Byte): TM256;
```

#### avx2_permute4x64_pd - 置换 4 个双精度浮点数

- **指令**: `vpermpd ymm, ymm/m256, imm8`
- **Intel Intrinsic**: `_mm256_permute4x64_pd`
- **操作**: 根据 imm8 重排 4 个双精度浮点数

```pascal
function avx2_permute4x64_pd(const a: TM256; imm8: Byte): TM256;
```

#### avx2_permutevar8x32_epi32 - 变量置换 8 个 32-bit 整数

- **指令**: `vpermd ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_permutevar8x32_epi32`
- **操作**: 根据索引向量重排 8 个 32-bit 元素

```pascal
function avx2_permutevar8x32_epi32(const a, idx: TM256): TM256;
```

#### avx2_permutevar8x32_ps - 变量置换 8 个单精度浮点数

- **指令**: `vpermps ymm, ymm, ymm/m256`
- **Intel Intrinsic**: `_mm256_permutevar8x32_ps`
- **操作**: 根据索引向量重排 8 个单精度浮点数

```pascal
function avx2_permutevar8x32_ps(const a: TM256; const idx: TM256): TM256;
```

## 使用示例

### 基本整数运算

```pascal
var
  a, b, result: TM256;
begin
  // 设置两个向量
  a := avx2_set1_epi32(10);  // 所有元素设置为 10
  b := avx2_set1_epi32(3);   // 所有元素设置为 3

  // 向量加法
  result := avx2_add_epi32(a, b);  // 所有元素为 13

  // 向量乘法
  result := avx2_mullo_epi32(a, b);  // 所有元素为 30
end;
```

### 内存操作

```pascal
var
  data: array[0..7] of LongInt;
  vec: TM256;
  i: Integer;
begin
  // 初始化数据
  for i := 0 to 7 do
    data[i] := i + 1;

  // 从内存加载
  vec := avx2_loadu_si256(@data[0]);

  // 处理数据（乘以 2）
  vec := avx2_add_epi32(vec, vec);

  // 存储回内存
  avx2_storeu_si256(data, vec);
end;
```

### 变量移位

```pascal
var
  values, shifts, result: TM256;
  i: Integer;
begin
  // 设置要移位的值
  values := avx2_set1_epi32(16);  // 所有元素为 16 (0x10)

  // 设置不同的移位量
  for i := 0 to 7 do
    shifts.m256i_u32[i] := i;  // [0, 1, 2, 3, 4, 5, 6, 7]

  // 变量左移
  result := avx2_sllv_epi32(values, shifts);
  // result = [16, 32, 64, 128, 256, 512, 1024, 2048]
end;
```

### 比较和选择

```pascal
var
  a, b, mask, result: TM256;
begin
  a := avx2_set1_epi32(5);
  b := avx2_set1_epi32(3);

  // 比较 a > b
  mask := avx2_cmpgt_epi32(a, b);  // 全部为 0xFFFFFFFF

  // 使用掩码选择
  result := avx2_and_si256(mask, a);  // 条件为真时保留 a 的值
end;
```

## 实现说明

当前实现是纯 Pascal 模拟版本，用于：

1. **跨平台兼容性** - 在不支持 AVX2 的平台上提供一致的 API
2. **开发和测试** - 便于调试和验证算法正确性
3. **教学目的** - 清晰展示每个指令的语义

聚集加载（`avx2_gather_*`）、打包/解包（`avx2_pack*` / `avx2_unpack*`）和置换（`avx2_permute*`）均已实现为纯 Pascal 版本。

在支持 AVX2 的平台上，仍可进一步通过内联汇编或编译器内置函数做性能优化。

## 回归覆盖（2026-02-07）

当前 `AVX2` 回退实现由 `TTestCase_AVX2IntrinsicsFallback` 提供专项护栏，覆盖以下关键语义：

- **Set/Zero 语义**
  - `avx2_setzero_si256` 多视图一致性（`u64/i32/u8/f64` 全量为 0）
- **Gather 语义**
  - `avx2_gather_epi32/epi64/ps/pd` 基础加载正确性
  - 非法参数防御：`base_addr=nil`、`scale` 非 `1/2/4/8`
  - 负索引路径：`epi32`、`epi64`、`pd` 的回溯读取
- **Pack/Unpack 语义**
  - `packs/packus` 饱和规则（有符号/无符号）
  - 128-bit lane 隔离（极值输入 + 哨兵模式，防跨 lane 串扰）
- **Permute 语义**
  - `permute4x64` 常见重排
  - `permutevar8x32` 索引掩码语义（`idx and 7`）
  - `permute4x64` 的 `imm8=0..255` 全组合验证

推荐回归命令：

```bash
bash tests/nextpas.core.simd/BuildOrTest.sh check
bash tests/nextpas.core.simd/BuildOrTest.sh gate
bash tests/nextpas.core.simd/BuildOrTest.sh test --suite=TTestCase_AVX2IntrinsicsFallback
STOP_ON_FAIL=1 bash tests/run_all_tests.sh nextpas.core.simd nextpas.core.simd.cpuinfo nextpas.core.simd.cpuinfo.x86
```

`cpuinfo`/`cpuinfo.x86` runner 已兼容 `--list-suites`（内部转译为 `consoletestrunner` 的 `--list`），可用于稳定列出 suite 清单。

Windows 证据补充：

- 一键采集：`tests\nextpas.core.simd\collect_windows_b07_evidence.bat`
- Linux 侧校验：`bash tests/nextpas.core.simd/BuildOrTest.sh verify-win-evidence`

在无 Windows 证据日志时，`BuildOrTest.sh gate` 会对证据校验分支输出 `SKIP`，不会阻断主回归门禁。

## 性能考虑

1. **内存对齐** - 32 字节对齐的内存访问通常更快
2. **批量处理** - 充分利用 SIMD 的 8-way 并行性
3. **避免跨通道操作** - 256-bit 寄存器由两个 128-bit 通道组成，跨通道操作可能较慢
4. **缓存友好** - 合理利用预取和流式存储
5. **避免标量回退** - 尽量使用向量版本的指令

## 与 SSE/AVX 的关系

- **SSE**: 128-bit 向量，仅浮点和部分整数
- **AVX**: 256-bit 向量，主要浮点
- **AVX2**: 256-bit 向量，完整整数支持 + 新特性（变量移位、聚集、广播）

AVX2 是 SSE 的超集，大多数 SSE 整数指令在 AVX2 中都有对应的 256-bit 版本。
