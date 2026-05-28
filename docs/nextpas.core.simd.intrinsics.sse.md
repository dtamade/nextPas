# nextpas.core.simd.intrinsics.sse

> **Disposition**: Active Leaf (via `nextpas.core.simd.intrinsics.x86.sse2`). Not part of the default stable public surface.

SSE (Streaming SIMD Extensions) 指令集支持模块

## 概述

SSE 是 Intel 在 1999 年引入的 128-bit SIMD 指令集，主要用于单精度浮点运算，也包含一些整数操作。

### 特性

- 128-bit 向量寄存器 (xmm0-xmm7/xmm15)
- 单精度浮点运算 (4x32-bit)
- 预取指令
- 流式存储
- 缓存控制

### 兼容性

所有现代 x86/x64 处理器都支持 SSE 指令集。

## 核心类型

### TM128

128-bit 统一向量类型，支持多种数据格式：

```pascal
TM128 = record
  case Integer of
    0: (m128i_u8: array[0..15] of Byte);      // 16个8位无符号整数
    1: (m128i_u16: array[0..7] of Word);      // 8个16位无符号整数
    2: (m128i_u32: array[0..3] of DWord);     // 4个32位无符号整数
    3: (m128i_u64: array[0..1] of QWord);     // 2个64位无符号整数
    4: (m128i_i8: array[0..15] of ShortInt);  // 16个8位有符号整数
    5: (m128i_i16: array[0..7] of SmallInt);  // 8个16位有符号整数
    6: (m128i_i32: array[0..3] of LongInt);   // 4个32位有符号整数
    7: (m128i_i64: array[0..1] of Int64);     // 2个64位有符号整数
    8: (m128_f32: array[0..3] of Single);     // 4个32位单精度浮点数
    9: (m128d_f64: array[0..1] of Double);    // 2个64位双精度浮点数
end;
```

## 功能分类

### 1. Load / Store 操作

- `sse_load_ps` - 从对齐内存加载4个单精度浮点数
- `sse_loadu_ps` - 从未对齐内存加载4个单精度浮点数
- `sse_load_ss` - 加载单个单精度浮点数到低位，高位清零
- `sse_store_ps` - 存储4个单精度浮点数到对齐内存
- `sse_storeu_ps` - 存储4个单精度浮点数到未对齐内存
- `sse_store_ss` - 存储低位单精度浮点数
- `sse_movq` - 加载64位整数到低位，高位清零
- `sse_movq_store` - 存储低64位整数

### 2. Set / Zero 操作

- `sse_setzero_ps` - 将寄存器清零
- `sse_set1_ps` - 将所有4个位置设置为相同值（广播）
- `sse_set_ps` - 设置4个不同的单精度浮点数
- `sse_set_ss` - 设置单个单精度浮点数到低位，高位清零

### 3. 浮点运算

#### 基本运算
- `sse_add_ps` / `sse_add_ss` - 加法
- `sse_sub_ps` / `sse_sub_ss` - 减法
- `sse_mul_ps` / `sse_mul_ss` - 乘法
- `sse_div_ps` / `sse_div_ss` - 除法

#### 数学函数
- `sse_sqrt_ps` / `sse_sqrt_ss` - 平方根
- `sse_rcp_ps` / `sse_rcp_ss` - 近似倒数
- `sse_rsqrt_ps` / `sse_rsqrt_ss` - 近似平方根倒数

#### 最值操作
- `sse_min_ps` / `sse_min_ss` - 最小值
- `sse_max_ps` / `sse_max_ss` - 最大值

### 4. 逻辑操作

- `sse_and_ps` - 按位 AND
- `sse_andn_ps` / `sse_andnot_ps` - 按位 AND NOT
- `sse_or_ps` - 按位 OR
- `sse_xor_ps` - 按位 XOR

### 5. 比较操作

- `sse_cmpeq_ps` / `sse_cmpeq_ss` - 等于比较
- `sse_cmplt_ps` / `sse_cmplt_ss` - 小于比较
- `sse_cmple_ps` / `sse_cmple_ss` - 小于等于比较
- `sse_cmpgt_ps` / `sse_cmpgt_ss` - 大于比较
- `sse_cmpge_ps` / `sse_cmpge_ss` - 大于等于比较
- `sse_cmpord_ps` / `sse_cmpord_ss` - 有序比较（非NaN）
- `sse_cmpunord_ps` / `sse_cmpunord_ss` - 无序比较（NaN）

### 6. 数据重排

- `sse_shuffle_ps` - 洗牌操作，根据立即数重排元素
- `sse_unpckhps` / `sse_unpackhi_ps` - 解包高位元素
- `sse_unpcklps` / `sse_unpacklo_ps` - 解包低位元素

### 7. 数据移动

- `sse_movaps` / `sse_movups` - 移动对齐/未对齐数据
- `sse_movss` - 移动单个标量，其他位清零
- `sse_movhl_ps` / `sse_movehl_ps` - 移动高位到低位
- `sse_movlh_ps` / `sse_movelh_ps` - 移动低位到高位
- `sse_movd` - 从整数加载到XMM寄存器
- `sse_movd_toint` - 从XMM寄存器提取整数

### 8. 缓存控制

- `sse_stream_ps` - 非时态存储（绕过缓存）
- `sse_stream_si64` - 非时态存储64位整数
- `sse_sfence` - 存储栅栏指令

### 9. 杂项

- `sse_getcsr` - 获取MXCSR寄存器状态
- `sse_setcsr` - 设置MXCSR寄存器状态

## 使用示例

### 基本向量运算

```pascal
var
  a, b, result: TM128;
begin
  // 设置两个向量
  a := sse_set_ps(4.0, 3.0, 2.0, 1.0);  // [1.0, 2.0, 3.0, 4.0]
  b := sse_set_ps(8.0, 7.0, 6.0, 5.0);  // [5.0, 6.0, 7.0, 8.0]
  
  // 向量加法
  result := sse_add_ps(a, b);  // [6.0, 8.0, 10.0, 12.0]
  
  // 向量乘法
  result := sse_mul_ps(a, b);  // [5.0, 12.0, 21.0, 32.0]
end;
```

### 内存操作

```pascal
var
  data: array[0..3] of Single;
  vec: TM128;
begin
  // 从内存加载
  data[0] := 1.0; data[1] := 2.0; data[2] := 3.0; data[3] := 4.0;
  vec := sse_load_ps(@data[0]);
  
  // 处理数据
  vec := sse_mul_ps(vec, sse_set1_ps(2.0));  // 乘以2
  
  // 存储回内存
  sse_store_ps(data, vec);
end;
```

### 比较操作

```pascal
var
  a, b, mask: TM128;
begin
  a := sse_set_ps(4.0, 3.0, 2.0, 1.0);
  b := sse_set_ps(3.0, 5.0, 2.0, 3.0);
  
  // 生成比较掩码
  mask := sse_cmpgt_ps(a, b);  // 大于比较
  // mask 包含 [0x00000000, 0x00000000, 0x00000000, 0xFFFFFFFF]
end;
```

## 实现说明

当前实现是纯 Pascal 模拟版本，用于：

1. **跨平台兼容性** - 在不支持 SSE 的平台上提供一致的API
2. **开发和测试** - 便于调试和验证算法正确性
3. **教学目的** - 清晰展示每个指令的语义

在支持 SSE 的平台上，可以通过内联汇编或编译器内置函数来优化性能。

## 测试

模块包含完整的单元测试，覆盖所有公开接口：

```bash
cd tests/nextpas.core.simd.intrinsics.sse
buildOrTest.bat test
```

测试包括：
- 基本功能验证
- 边界条件测试
- NaN 和特殊值处理
- 内存对齐测试

## 性能考虑

1. **内存对齐** - 对齐的内存访问通常更快
2. **批量处理** - 充分利用SIMD并行性
3. **缓存友好** - 合理使用流式存储指令
4. **避免标量回退** - 尽量使用向量版本的指令

## 扩展方向

1. **SSE2/SSE3/SSE4** - 支持更高版本的SSE指令集
2. **AVX/AVX2** - 256位向量支持
3. **ARM NEON** - ARM平台的SIMD支持
4. **自动向量化** - 编译器优化集成
