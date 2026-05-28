# nextpas.core.simd.intrinsics.neon

> **Disposition**: Experimental Isolated (requires `SIMD_ARM_AVAILABLE`). Not part of the default stable public surface on x86 builds.

ARM NEON SIMD 指令集支持模块

## 概述

NEON 是 ARM 架构的高级 SIMD（Single Instruction Multiple Data）扩展，提供 128-bit 向量运算能力。NEON 在 ARMv7-A、ARMv8-A（AArch32）和 AArch64 处理器上可用。

### 特性

- 128-bit 向量寄存器（AArch64: v0-v31，ARMv7: q0-q15）
- 单精度和双精度浮点运算
- 整数 SIMD 操作（8、16、32、64-bit）
- 饱和算术指令
- 向量加载/存储指令
- 向量置换和重排指令

### 兼容性

- ARMv7-A 处理器（32-bit）
- ARMv8-A 处理器（AArch32 和 AArch64）
- Apple Silicon（M1/M2/M3 系列）
- Qualcomm Snapdragon 处理器
- Samsung Exynos 处理器
- 大多数现代 ARM 移动和嵌入式处理器

## 核心类型

### TNeon128

128-bit 统一向量类型，支持多种数据格式：

```pascal
TNeon128 = packed record
  case Integer of
    0: (u8: array[0..15] of UInt8);       // 16个8位无符号整数
    1: (i8: array[0..15] of Int8);        // 16个8位有符号整数
    2: (u16: array[0..7] of UInt16);      // 8个16位无符号整数
    3: (i16: array[0..7] of Int16);       // 8个16位有符号整数
    4: (u32: array[0..3] of UInt32);      // 4个32位无符号整数
    5: (i32: array[0..3] of Int32);       // 4个32位有符号整数
    6: (u64: array[0..1] of UInt64);      // 2个64位无符号整数
    7: (i64: array[0..1] of Int64);       // 2个64位有符号整数
    8: (f32: array[0..3] of Single);      // 4个32位单精度浮点数
    9: (f64: array[0..1] of Double);      // 2个64位双精度浮点数
end;
```

## 功能分类

### 1. Load / Store 操作

#### 加载操作

```pascal
// 从内存加载 128-bit 向量
function neon_ld1q_u8(p: Pointer): TNeon128;
function neon_ld1q_u16(p: Pointer): TNeon128;
function neon_ld1q_u32(p: Pointer): TNeon128;
function neon_ld1q_u64(p: Pointer): TNeon128;
function neon_ld1q_f32(p: Pointer): TNeon128;
function neon_ld1q_f64(p: Pointer): TNeon128;

// 示例：加载 4 个单精度浮点数
var
  data: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  vec: TNeon128;
begin
  vec := neon_ld1q_f32(@data);
  // vec.f32 = [1.0, 2.0, 3.0, 4.0]
end;
```

#### 存储操作

```pascal
// 将 128-bit 向量存储到内存
procedure neon_st1q_u8(p: Pointer; const v: TNeon128);
procedure neon_st1q_u16(p: Pointer; const v: TNeon128);
procedure neon_st1q_u32(p: Pointer; const v: TNeon128);
procedure neon_st1q_u64(p: Pointer; const v: TNeon128);
procedure neon_st1q_f32(p: Pointer; const v: TNeon128);
procedure neon_st1q_f64(p: Pointer; const v: TNeon128);

// 示例：存储 4 个单精度浮点数
var
  vec: TNeon128;
  data: array[0..3] of Single;
begin
  vec.f32[0] := 1.0;
  vec.f32[1] := 2.0;
  vec.f32[2] := 3.0;
  vec.f32[3] := 4.0;
  neon_st1q_f32(@data, vec);
  // data = [1.0, 2.0, 3.0, 4.0]
end;
```

### 2. 算术操作

#### 整数加法

```pascal
// 8-bit 整数加法（16 个元素）
function neon_addq_u8(const a, b: TNeon128): TNeon128;
function neon_addq_s8(const a, b: TNeon128): TNeon128;

// 16-bit 整数加法（8 个元素）
function neon_addq_u16(const a, b: TNeon128): TNeon128;
function neon_addq_s16(const a, b: TNeon128): TNeon128;

// 32-bit 整数加法（4 个元素）
function neon_addq_u32(const a, b: TNeon128): TNeon128;
function neon_addq_s32(const a, b: TNeon128): TNeon128;

// 64-bit 整数加法（2 个元素）
function neon_addq_u64(const a, b: TNeon128): TNeon128;
function neon_addq_s64(const a, b: TNeon128): TNeon128;

// 示例：32-bit 整数加法
var
  a, b, c: TNeon128;
begin
  a.i32[0] := 1; a.i32[1] := 2; a.i32[2] := 3; a.i32[3] := 4;
  b.i32[0] := 5; b.i32[1] := 6; b.i32[2] := 7; b.i32[3] := 8;
  c := neon_addq_s32(a, b);
  // c.i32 = [6, 8, 10, 12]
end;
```

#### 整数减法

```pascal
// 8-bit 整数减法（16 个元素）
function neon_subq_u8(const a, b: TNeon128): TNeon128;
function neon_subq_s8(const a, b: TNeon128): TNeon128;

// 16-bit 整数减法（8 个元素）
function neon_subq_u16(const a, b: TNeon128): TNeon128;
function neon_subq_s16(const a, b: TNeon128): TNeon128;

// 32-bit 整数减法（4 个元素）
function neon_subq_u32(const a, b: TNeon128): TNeon128;
function neon_subq_s32(const a, b: TNeon128): TNeon128;

// 64-bit 整数减法（2 个元素）
function neon_subq_u64(const a, b: TNeon128): TNeon128;
function neon_subq_s64(const a, b: TNeon128): TNeon128;
```

#### 整数乘法

```pascal
// 16-bit 整数乘法（8 个元素）
function neon_mulq_u16(const a, b: TNeon128): TNeon128;
function neon_mulq_s16(const a, b: TNeon128): TNeon128;

// 32-bit 整数乘法（4 个元素）
function neon_mulq_u32(const a, b: TNeon128): TNeon128;
function neon_mulq_s32(const a, b: TNeon128): TNeon128;

// 示例：32-bit 整数乘法
var
  a, b, c: TNeon128;
begin
  a.i32[0] := 2; a.i32[1] := 3; a.i32[2] := 4; a.i32[3] := 5;
  b.i32[0] := 3; b.i32[1] := 4; b.i32[2] := 5; b.i32[3] := 6;
  c := neon_mulq_s32(a, b);
  // c.i32 = [6, 12, 20, 30]
end;
```

#### 浮点算术

```pascal
// 单精度浮点加法（4 个元素）
function neon_addq_f32(const a, b: TNeon128): TNeon128;

// 单精度浮点减法（4 个元素）
function neon_subq_f32(const a, b: TNeon128): TNeon128;

// 单精度浮点乘法（4 个元素）
function neon_mulq_f32(const a, b: TNeon128): TNeon128;

// 单精度浮点除法（4 个元素）
function neon_divq_f32(const a, b: TNeon128): TNeon128;

// 双精度浮点加法（2 个元素）
function neon_addq_f64(const a, b: TNeon128): TNeon128;

// 双精度浮点减法（2 个元素）
function neon_subq_f64(const a, b: TNeon128): TNeon128;

// 双精度浮点乘法（2 个元素）
function neon_mulq_f64(const a, b: TNeon128): TNeon128;

// 双精度浮点除法（2 个元素）
function neon_divq_f64(const a, b: TNeon128): TNeon128;

// 示例：单精度浮点加法
var
  a, b, c: TNeon128;
begin
  a.f32[0] := 1.0; a.f32[1] := 2.0; a.f32[2] := 3.0; a.f32[3] := 4.0;
  b.f32[0] := 0.5; b.f32[1] := 1.5; b.f32[2] := 2.5; b.f32[3] := 3.5;
  c := neon_addq_f32(a, b);
  // c.f32 = [1.5, 3.5, 5.5, 7.5]
end;
```

### 3. 位运算操作

```pascal
// 按位与（AND）
function neon_andq(const a, b: TNeon128): TNeon128;

// 按位或（OR）
function neon_orrq(const a, b: TNeon128): TNeon128;

// 按位异或（XOR）
function neon_eorq(const a, b: TNeon128): TNeon128;

// 按位取反（NOT）
function neon_mvnq(const a: TNeon128): TNeon128;

// 按位与非（AND NOT）
function neon_bicq(const a, b: TNeon128): TNeon128;

// 示例：按位与操作
var
  a, b, c: TNeon128;
begin
  a.u32[0] := $FFFFFFFF; a.u32[1] := $00000000;
  a.u32[2] := $FFFFFFFF; a.u32[3] := $00000000;
  b.u32[0] := $0F0F0F0F; b.u32[1] := $0F0F0F0F;
  b.u32[2] := $0F0F0F0F; b.u32[3] := $0F0F0F0F;
  c := neon_andq(a, b);
  // c.u32 = [$0F0F0F0F, $00000000, $0F0F0F0F, $00000000]
end;
```

### 4. 移位操作

```pascal
// 逻辑左移
function neon_shlq_n_u8(const a: TNeon128; n: Integer): TNeon128;
function neon_shlq_n_u16(const a: TNeon128; n: Integer): TNeon128;
function neon_shlq_n_u32(const a: TNeon128; n: Integer): TNeon128;
function neon_shlq_n_u64(const a: TNeon128; n: Integer): TNeon128;

// 逻辑右移
function neon_shrq_n_u8(const a: TNeon128; n: Integer): TNeon128;
function neon_shrq_n_u16(const a: TNeon128; n: Integer): TNeon128;
function neon_shrq_n_u32(const a: TNeon128; n: Integer): TNeon128;
function neon_shrq_n_u64(const a: TNeon128; n: Integer): TNeon128;

// 算术右移
function neon_shrq_n_s8(const a: TNeon128; n: Integer): TNeon128;
function neon_shrq_n_s16(const a: TNeon128; n: Integer): TNeon128;
function neon_shrq_n_s32(const a: TNeon128; n: Integer): TNeon128;
function neon_shrq_n_s64(const a: TNeon128; n: Integer): TNeon128;

// 示例：32-bit 逻辑左移
var
  a, b: TNeon128;
begin
  a.u32[0] := 1; a.u32[1] := 2; a.u32[2] := 3; a.u32[3] := 4;
  b := neon_shlq_n_u32(a, 2);
  // b.u32 = [4, 8, 12, 16]
end;
```

### 5. 比较操作

```pascal
// 相等比较
function neon_ceqq_u8(const a, b: TNeon128): TNeon128;
function neon_ceqq_u16(const a, b: TNeon128): TNeon128;
function neon_ceqq_u32(const a, b: TNeon128): TNeon128;
function neon_ceqq_f32(const a, b: TNeon128): TNeon128;
function neon_ceqq_f64(const a, b: TNeon128): TNeon128;

// 大于比较
function neon_cgtq_s8(const a, b: TNeon128): TNeon128;
function neon_cgtq_s16(const a, b: TNeon128): TNeon128;
function neon_cgtq_s32(const a, b: TNeon128): TNeon128;
function neon_cgtq_f32(const a, b: TNeon128): TNeon128;
function neon_cgtq_f64(const a, b: TNeon128): TNeon128;

// 大于等于比较
function neon_cgeq_s8(const a, b: TNeon128): TNeon128;
function neon_cgeq_s16(const a, b: TNeon128): TNeon128;
function neon_cgeq_s32(const a, b: TNeon128): TNeon128;
function neon_cgeq_f32(const a, b: TNeon128): TNeon128;
function neon_cgeq_f64(const a, b: TNeon128): TNeon128;

// 小于比较
function neon_cltq_s8(const a, b: TNeon128): TNeon128;
function neon_cltq_s16(const a, b: TNeon128): TNeon128;
function neon_cltq_s32(const a, b: TNeon128): TNeon128;
function neon_cltq_f32(const a, b: TNeon128): TNeon128;
function neon_cltq_f64(const a, b: TNeon128): TNeon128;

// 小于等于比较
function neon_cleq_s8(const a, b: TNeon128): TNeon128;
function neon_cleq_s16(const a, b: TNeon128): TNeon128;
function neon_cleq_s32(const a, b: TNeon128): TNeon128;
function neon_cleq_f32(const a, b: TNeon128): TNeon128;
function neon_cleq_f64(const a, b: TNeon128): TNeon128;

// 示例：单精度浮点比较
var
  a, b, mask: TNeon128;
begin
  a.f32[0] := 1.0; a.f32[1] := 2.0; a.f32[2] := 3.0; a.f32[3] := 4.0;
  b.f32[0] := 2.0; b.f32[1] := 2.0; b.f32[2] := 1.0; b.f32[3] := 5.0;
  mask := neon_cgtq_f32(a, b);
  // mask.u32 = [0x00000000, 0x00000000, 0xFFFFFFFF, 0x00000000]
end;
```

### 6. 数学函数

```pascal
// 最小值
function neon_minq_u8(const a, b: TNeon128): TNeon128;
function neon_minq_u16(const a, b: TNeon128): TNeon128;
function neon_minq_u32(const a, b: TNeon128): TNeon128;
function neon_minq_s8(const a, b: TNeon128): TNeon128;
function neon_minq_s16(const a, b: TNeon128): TNeon128;
function neon_minq_s32(const a, b: TNeon128): TNeon128;
function neon_minq_f32(const a, b: TNeon128): TNeon128;
function neon_minq_f64(const a, b: TNeon128): TNeon128;

// 最大值
function neon_maxq_u8(const a, b: TNeon128): TNeon128;
function neon_maxq_u16(const a, b: TNeon128): TNeon128;
function neon_maxq_u32(const a, b: TNeon128): TNeon128;
function neon_maxq_s8(const a, b: TNeon128): TNeon128;
function neon_maxq_s16(const a, b: TNeon128): TNeon128;
function neon_maxq_s32(const a, b: TNeon128): TNeon128;
function neon_maxq_f32(const a, b: TNeon128): TNeon128;
function neon_maxq_f64(const a, b: TNeon128): TNeon128;

// 平方根
function neon_sqrtq_f32(const a: TNeon128): TNeon128;
function neon_sqrtq_f64(const a: TNeon128): TNeon128;

// 绝对值
function neon_absq_s8(const a: TNeon128): TNeon128;
function neon_absq_s16(const a: TNeon128): TNeon128;
function neon_absq_s32(const a: TNeon128): TNeon128;
function neon_absq_f32(const a: TNeon128): TNeon128;
function neon_absq_f64(const a: TNeon128): TNeon128;

// 取反
function neon_negq_s8(const a: TNeon128): TNeon128;
function neon_negq_s16(const a: TNeon128): TNeon128;
function neon_negq_s32(const a: TNeon128): TNeon128;
function neon_negq_f32(const a: TNeon128): TNeon128;
function neon_negq_f64(const a: TNeon128): TNeon128;

// 示例：单精度浮点平方根
var
  a, b: TNeon128;
begin
  a.f32[0] := 4.0; a.f32[1] := 9.0; a.f32[2] := 16.0; a.f32[3] := 25.0;
  b := neon_sqrtq_f32(a);
  // b.f32 = [2.0, 3.0, 4.0, 5.0]
end;
```

### 7. 饱和算术

```pascal
// 有符号饱和加法
function neon_qaddq_s8(const a, b: TNeon128): TNeon128;
function neon_qaddq_s16(const a, b: TNeon128): TNeon128;
function neon_qaddq_s32(const a, b: TNeon128): TNeon128;

// 无符号饱和加法
function neon_qaddq_u8(const a, b: TNeon128): TNeon128;
function neon_qaddq_u16(const a, b: TNeon128): TNeon128;
function neon_qaddq_u32(const a, b: TNeon128): TNeon128;

// 有符号饱和减法
function neon_qsubq_s8(const a, b: TNeon128): TNeon128;
function neon_qsubq_s16(const a, b: TNeon128): TNeon128;
function neon_qsubq_s32(const a, b: TNeon128): TNeon128;

// 无符号饱和减法
function neon_qsubq_u8(const a, b: TNeon128): TNeon128;
function neon_qsubq_u16(const a, b: TNeon128): TNeon128;
function neon_qsubq_u32(const a, b: TNeon128): TNeon128;

// 示例：8-bit 无符号饱和加法
var
  a, b, c: TNeon128;
begin
  a.u8[0] := 200; a.u8[1] := 100;
  b.u8[0] := 100; b.u8[1] := 200;
  c := neon_qaddq_u8(a, b);
  // c.u8[0] = 255 (饱和), c.u8[1] = 255 (饱和)
end;
```

### 8. 类型转换

```pascal
// 窄化转换（高位截断）
function neon_movn_u16(const a: TNeon128): TNeon64;  // 16-bit -> 8-bit
function neon_movn_u32(const a: TNeon128): TNeon64;  // 32-bit -> 16-bit
function neon_movn_u64(const a: TNeon128): TNeon64;  // 64-bit -> 32-bit

// 扩展转换（零扩展）
function neon_movl_u8(const a: TNeon64): TNeon128;   // 8-bit -> 16-bit
function neon_movl_u16(const a: TNeon64): TNeon128;  // 16-bit -> 32-bit
function neon_movl_u32(const a: TNeon64): TNeon128;  // 32-bit -> 64-bit

// 浮点转整数
function neon_cvtq_s32_f32(const a: TNeon128): TNeon128;  // f32 -> i32
function neon_cvtq_u32_f32(const a: TNeon128): TNeon128;  // f32 -> u32
function neon_cvtq_s64_f64(const a: TNeon128): TNeon128;  // f64 -> i64
function neon_cvtq_u64_f64(const a: TNeon128): TNeon128;  // f64 -> u64

// 整数转浮点
function neon_cvtq_f32_s32(const a: TNeon128): TNeon128;  // i32 -> f32
function neon_cvtq_f32_u32(const a: TNeon128): TNeon128;  // u32 -> f32
function neon_cvtq_f64_s64(const a: TNeon128): TNeon128;  // i64 -> f64
function neon_cvtq_f64_u64(const a: TNeon128): TNeon128;  // u64 -> f64

// 示例：浮点转整数
var
  a: TNeon128;
  b: TNeon128;
begin
  a.f32[0] := 1.7; a.f32[1] := 2.3; a.f32[2] := 3.9; a.f32[3] := 4.1;
  b := neon_cvtq_s32_f32(a);
  // b.i32 = [1, 2, 3, 4] (向零舍入)
end;
```

### 9. 向量重排

```pascal
// 提取元素
function neon_vgetq_lane_u8(const v: TNeon128; lane: Integer): UInt8;
function neon_vgetq_lane_u16(const v: TNeon128; lane: Integer): UInt16;
function neon_vgetq_lane_u32(const v: TNeon128; lane: Integer): UInt32;
function neon_vgetq_lane_f32(const v: TNeon128; lane: Integer): Single;
function neon_vgetq_lane_f64(const v: TNeon128; lane: Integer): Double;

// 设置元素
function neon_vsetq_lane_u8(value: UInt8; const v: TNeon128; lane: Integer): TNeon128;
function neon_vsetq_lane_u16(value: UInt16; const v: TNeon128; lane: Integer): TNeon128;
function neon_vsetq_lane_u32(value: UInt32; const v: TNeon128; lane: Integer): TNeon128;
function neon_vsetq_lane_f32(value: Single; const v: TNeon128; lane: Integer): TNeon128;
function neon_vsetq_lane_f64(value: Double; const v: TNeon128; lane: Integer): TNeon128;

// 复制元素到所有通道
function neon_vdupq_n_u8(value: UInt8): TNeon128;
function neon_vdupq_n_u16(value: UInt16): TNeon128;
function neon_vdupq_n_u32(value: UInt32): TNeon128;
function neon_vdupq_n_f32(value: Single): TNeon128;
function neon_vdupq_n_f64(value: Double): TNeon128;

// 示例：设置和提取元素
var
  v: TNeon128;
  val: Single;
begin
  v := neon_vdupq_n_f32(0.0);  // 所有元素设为 0.0
  v := neon_vsetq_lane_f32(1.5, v, 2);  // 设置第 3 个元素为 1.5
  val := neon_vgetq_lane_f32(v, 2);  // 提取第 3 个元素
  // val = 1.5
end;
```

## 使用示例

### 示例 1：向量加法

```pascal
uses nextpas.core.simd.intrinsics.neon;

procedure VectorAdd(a, b, result: PSingle; count: Integer);
var
  i: Integer;
  va, vb, vr: TNeon128;
begin
  // 处理 4 个元素一组
  i := 0;
  while i + 3 < count do
  begin
    va := neon_ld1q_f32(@a[i]);
    vb := neon_ld1q_f32(@b[i]);
    vr := neon_addq_f32(va, vb);
    neon_st1q_f32(@result[i], vr);
    Inc(i, 4);
  end;
  
  // 处理剩余元素
  while i < count do
  begin
    result[i] := a[i] + b[i];
    Inc(i);
  end;
end;
```

### 示例 2：点积计算

```pascal
function DotProduct(a, b: PSingle; count: Integer): Single;
var
  i: Integer;
  va, vb, vp, vsum: TNeon128;
  sum: Single;
begin
  vsum := neon_vdupq_n_f32(0.0);
  
  // 处理 4 个元素一组
  i := 0;
  while i + 3 < count do
  begin
    va := neon_ld1q_f32(@a[i]);
    vb := neon_ld1q_f32(@b[i]);
    vp := neon_mulq_f32(va, vb);
    vsum := neon_addq_f32(vsum, vp);
    Inc(i, 4);
  end;
  
  // 水平求和
  sum := vsum.f32[0] + vsum.f32[1] + vsum.f32[2] + vsum.f32[3];
  
  // 处理剩余元素
  while i < count do
  begin
    sum := sum + a[i] * b[i];
    Inc(i);
  end;
  
  Result := sum;
end;
```

### 示例 3：图像处理 - 亮度调整

```pascal
procedure AdjustBrightness(pixels: PByte; count: Integer; delta: Byte);
var
  i: Integer;
  vpixels, vdelta, vresult: TNeon128;
begin
  vdelta := neon_vdupq_n_u8(delta);
  
  // 处理 16 个像素一组
  i := 0;
  while i + 15 < count do
  begin
    vpixels := neon_ld1q_u8(@pixels[i]);
    vresult := neon_qaddq_u8(vpixels, vdelta);  // 饱和加法
    neon_st1q_u8(@pixels[i], vresult);
    Inc(i, 16);
  end;
  
  // 处理剩余像素
  while i < count do
  begin
    if pixels[i] + delta > 255 then
      pixels[i] := 255
    else
      pixels[i] := pixels[i] + delta;
    Inc(i);
  end;
end;
```

### 示例 4：矩阵乘法（4x4）

```pascal
procedure MatrixMultiply4x4(const a, b: array of Single; var result: array of Single);
var
  i, j: Integer;
  row, col0, col1, col2, col3, sum: TNeon128;
begin
  // 加载矩阵 B 的列
  col0 := neon_ld1q_f32(@b[0]);   // B 的第 0 列
  col1 := neon_ld1q_f32(@b[4]);   // B 的第 1 列
  col2 := neon_ld1q_f32(@b[8]);   // B 的第 2 列
  col3 := neon_ld1q_f32(@b[12]);  // B 的第 3 列
  
  // 计算每一行
  for i := 0 to 3 do
  begin
    // 加载矩阵 A 的行
    row := neon_ld1q_f32(@a[i * 4]);
    
    // 计算点积
    sum := neon_vdupq_n_f32(0.0);
    
    // result[i,0] = dot(A[i], B[:,0])
    sum.f32[0] := row.f32[0] * col0.f32[0] + row.f32[1] * col0.f32[1] + 
                  row.f32[2] * col0.f32[2] + row.f32[3] * col0.f32[3];
    
    // result[i,1] = dot(A[i], B[:,1])
    sum.f32[1] := row.f32[0] * col1.f32[0] + row.f32[1] * col1.f32[1] + 
                  row.f32[2] * col1.f32[2] + row.f32[3] * col1.f32[3];
    
    // result[i,2] = dot(A[i], B[:,2])
    sum.f32[2] := row.f32[0] * col2.f32[0] + row.f32[1] * col2.f32[1] + 
                  row.f32[2] * col2.f32[2] + row.f32[3] * col2.f32[3];
    
    // result[i,3] = dot(A[i], B[:,3])
    sum.f32[3] := row.f32[0] * col3.f32[0] + row.f32[1] * col3.f32[1] + 
                  row.f32[2] * col3.f32[2] + row.f32[3] * col3.f32[3];
    
    neon_st1q_f32(@result[i * 4], sum);
  end;
end;
```

## 性能优化技巧

### 1. 内存对齐

NEON 指令对对齐内存访问性能更好：

```pascal
// 使用 16 字节对齐的内存
var
  data: array[0..15] of Single align 16;
  vec: TNeon128;
begin
  vec := neon_ld1q_f32(@data);  // 对齐加载，性能更好
end;
```

### 2. 循环展开

减少循环开销，提高吞吐量：

```pascal
procedure ProcessArray(data: PSingle; count: Integer);
var
  i: Integer;
  v0, v1, v2, v3: TNeon128;
begin
  i := 0;
  // 每次处理 16 个元素（4 个向量）
  while i + 15 < count do
  begin
    v0 := neon_ld1q_f32(@data[i]);
    v1 := neon_ld1q_f32(@data[i + 4]);
    v2 := neon_ld1q_f32(@data[i + 8]);
    v3 := neon_ld1q_f32(@data[i + 12]);
    
    // 处理 v0, v1, v2, v3
    
    neon_st1q_f32(@data[i], v0);
    neon_st1q_f32(@data[i + 4], v1);
    neon_st1q_f32(@data[i + 8], v2);
    neon_st1q_f32(@data[i + 12], v3);
    
    Inc(i, 16);
  end;
  
  // 处理剩余元素
  while i < count do
  begin
    // 标量处理
    Inc(i);
  end;
end;
```

### 3. 避免不必要的类型转换

尽量使用相同类型的操作，避免频繁转换：

```pascal
// ❌ 不好：频繁转换
var
  vi: TNeon128;
  vf: TNeon128;
begin
  vi := neon_ld1q_s32(@intData);
  vf := neon_cvtq_f32_s32(vi);  // 转换
  // ... 处理 ...
  vi := neon_cvtq_s32_f32(vf);  // 再次转换
  neon_st1q_s32(@intData, vi);
end;

// ✅ 好：保持类型一致
var
  vf: TNeon128;
begin
  vf := neon_ld1q_f32(@floatData);
  // ... 处理 ...
  neon_st1q_f32(@floatData, vf);
end;
```

### 4. 使用饱和算术避免溢出检查

```pascal
// ❌ 不好：手动检查溢出
var
  a, b, c: TNeon128;
  i: Integer;
begin
  a := neon_ld1q_u8(@data1);
  b := neon_ld1q_u8(@data2);
  c := neon_addq_u8(a, b);
  
  // 手动检查溢出
  for i := 0 to 15 do
    if c.u8[i] < a.u8[i] then
      c.u8[i] := 255;
end;

// ✅ 好：使用饱和算术
var
  a, b, c: TNeon128;
begin
  a := neon_ld1q_u8(@data1);
  b := neon_ld1q_u8(@data2);
  c := neon_qaddq_u8(a, b);  // 自动饱和
end;
```

## 平台特定注意事项

### AArch64 vs ARMv7

```pascal
{$IFDEF CPUAARCH64}
  // AArch64 有 32 个 128-bit 向量寄存器 (v0-v31)
  // 支持更多的 NEON 指令
{$ELSE}
  // ARMv7 只有 16 个 128-bit 向量寄存器 (q0-q15)
  // 某些高级指令可能不可用
{$ENDIF}
```

### 编译器要求

```pascal
// Free Pascal 3.3.1+ 支持 NEON 内联汇编
{$IF FPC_FULLVERSION >= 30301}
  // 可以使用 NEON 内联汇编
{$ELSE}
  // 需要使用外部 C 对象文件或标量回退
{$ENDIF}
```

## 调试技巧

### 1. 打印向量内容

```pascal
procedure PrintVector(const v: TNeon128; name: string);
var
  i: Integer;
begin
  Write(name, ': [');
  for i := 0 to 3 do
  begin
    Write(v.f32[i]:0:2);
    if i < 3 then Write(', ');
  end;
  WriteLn(']');
end;
```

### 2. 验证结果

```pascal
procedure VerifyResults(const simd, scalar: array of Single; count: Integer);
var
  i: Integer;
  maxDiff: Single;
begin
  maxDiff := 0.0;
  for i := 0 to count - 1 do
  begin
    if Abs(simd[i] - scalar[i]) > maxDiff then
      maxDiff := Abs(simd[i] - scalar[i]);
  end;
  
  if maxDiff > 0.0001 then
    WriteLn('Warning: Max difference = ', maxDiff:0:6);
end;
```

## 常见陷阱

### 1. 未对齐的内存访问

```pascal
// ❌ 可能导致性能下降
var
  data: array[0..15] of Single;  // 可能未对齐
  vec: TNeon128;
begin
  vec := neon_ld1q_f32(@data[1]);  // 未对齐访问
end;

// ✅ 确保对齐
var
  data: array[0..15] of Single align 16;  // 16 字节对齐
  vec: TNeon128;
begin
  vec := neon_ld1q_f32(@data);  // 对齐访问
end;
```

### 2. 忘记处理剩余元素

```pascal
// ❌ 忘记处理剩余元素
procedure ProcessArray(data: PSingle; count: Integer);
var
  i: Integer;
  vec: TNeon128;
begin
  i := 0;
  while i + 3 < count do
  begin
    vec := neon_ld1q_f32(@data[i]);
    // ... 处理 ...
    Inc(i, 4);
  end;
  // 忘记处理 data[i..count-1]
end;

// ✅ 处理剩余元素
procedure ProcessArray(data: PSingle; count: Integer);
var
  i: Integer;
  vec: TNeon128;
begin
  i := 0;
  while i + 3 < count do
  begin
    vec := neon_ld1q_f32(@data[i]);
    // ... 处理 ...
    Inc(i, 4);
  end;
  
  // 处理剩余元素
  while i < count do
  begin
    // 标量处理
    Inc(i);
  end;
end;
```

### 3. 浮点精度问题

```pascal
// NEON 浮点运算可能与标量运算有微小差异
// 使用容差比较而不是精确相等

// ❌ 不好
if simdResult = scalarResult then
  WriteLn('Equal');

// ✅ 好
if Abs(simdResult - scalarResult) < 0.0001 then
  WriteLn('Equal (within tolerance)');
```

## 参考资料

### ARM 官方文档

- [ARM NEON Programmer's Guide](https://developer.arm.com/architectures/instruction-sets/simd-isas/neon)
- [ARM NEON Intrinsics Reference](https://developer.arm.com/architectures/instruction-sets/intrinsics/)
- [Coding for NEON](https://developer.arm.com/documentation/den0018/latest/)

### 性能优化

- [NEON Optimization Guide](https://developer.arm.com/documentation/den0013/latest/)
- [ARM Cortex-A Series Programmer's Guide](https://developer.arm.com/documentation/den0024/latest/)

### Free Pascal 相关

- [FPC AArch64 Wiki](https://wiki.freepascal.org/AArch64)
- [FPC ARM Wiki](https://wiki.freepascal.org/ARM)

## 版本历史

- **v1.0** (2026-02-14): 初始版本，基础 NEON intrinsics 文档

## 贡献指南

1. 遵循项目编码规范
2. 添加相应的单元测试
3. 更新文档
4. 确保跨平台兼容性（AArch64 和 ARMv7）

## 许可证

本文档遵循 MIT 许可证。
