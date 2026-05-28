unit nextpas.core.simd.intrinsics.base;
// Disposition: STABLE — foundational intrinsics

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

// === SIMD Intrinsics 基础定义模块 ===
// 这个模块包含所有基础类型定义、常量和核心接口
// 不包含具体实现，只有类型和接口声明
// 不使用宏包裹，保持简洁

// === 跨平台向量类型定义 ===
type
  // 128-bit 统一向量类型 (对应 __m128i / __m128 / __m128d)
  TM128 = record
    case Integer of
      0: (m128i_u8: array[0..15] of Byte);
      1: (m128i_u16: array[0..7] of Word);
      2: (m128i_u32: array[0..3] of DWord);
      3: (m128i_u64: array[0..1] of QWord);
      4: (m128i_i8: array[0..15] of ShortInt);
      5: (m128i_i16: array[0..7] of SmallInt);
      6: (m128i_i32: array[0..3] of LongInt);
      7: (m128i_i64: array[0..1] of Int64);
      8: (m128_f32: array[0..3] of Single);
      9: (m128d_f64: array[0..1] of Double);
  end;

  // 兼容性别名
  TSimd128 = TM128;

  // 指针类型
  PTM128 = ^TM128;

  // 256-bit 向量类型
  TM256 = record
    case Integer of
      0: (m256i_u8: array[0..31] of Byte);
      1: (m256i_u16: array[0..15] of Word);
      2: (m256i_u32: array[0..7] of DWord);
      3: (m256i_u64: array[0..3] of QWord);
      4: (m256i_i8: array[0..31] of ShortInt);
      5: (m256i_i16: array[0..15] of SmallInt);
      6: (m256i_i32: array[0..7] of LongInt);
      7: (m256i_i64: array[0..3] of Int64);
      8: (m256_f32: array[0..7] of Single);
      9: (m256_f64: array[0..3] of Double);
      10: (m256_m128: array[0..1] of TM128);  // 可以用两个 128-bit 表示
  end;
  TSimd256 = TM256;
  PTM256 = ^TM256;

  // 512-bit 向量类型 (AVX-512)
  TM512 = record
    case Integer of
      0: (m512i_u8: array[0..63] of Byte);
      1: (m512i_u16: array[0..31] of Word);
      2: (m512i_u32: array[0..15] of DWord);
      3: (m512i_u64: array[0..7] of QWord);
      4: (m512i_i8: array[0..63] of ShortInt);
      5: (m512i_i16: array[0..31] of SmallInt);
      6: (m512i_i32: array[0..15] of LongInt);
      7: (m512i_i64: array[0..7] of Int64);
      8: (m512_f32: array[0..15] of Single);
      9: (m512_f64: array[0..7] of Double);
      10: (m512_m256: array[0..1] of TM256);  // 可以用两个 256-bit 表示
      11: (m512_m128: array[0..3] of TM128);  // 可以用四个 128-bit 表示
  end;
  TSimd512 = TM512;
  PTM512 = ^TM512;

// === x86 特定类型别名 ===
type
  __m128i = TM128;
  __m128 = TM128;
  __m128d = TM128;
  __m256i = TM256;
  __m256 = TM256;
  __m256d = TM256;
  __m512i = TM512;
  __m512 = TM512;
  __m512d = TM512;

// === ARM 特定类型别名 ===
type
  uint8x16_t = TM128;
  uint8x8_t = record
    case Integer of
      0: (u8: array[0..7] of Byte);
      1: (u16: array[0..3] of Word);
      2: (u32: array[0..1] of DWord);
      3: (u64: QWord);
  end;
  uint16x8_t = record
    u16: array[0..7] of Word;
  end;
  uint32x4_t = record
    u32: array[0..3] of DWord;
  end;
  uint64x2_t = record
    u64: array[0..1] of QWord;
  end;

// === 跨平台 Intrinsics 函数指针类型 ===
type
  // 128-bit 操作函数指针
  TSimdLoad128Func = function(p: Pointer): TSimd128;
  TSimdLoadu128Func = function(p: Pointer): TSimd128;
  TSimdStore128Proc = procedure(p: Pointer; a: TSimd128);
  TSimdStoreu128Proc = procedure(p: Pointer; a: TSimd128);
  
  TSimdSet1Epi8Func = function(a: Byte): TSimd128;
  TSimdSetzero128Func = function: TSimd128;
  
  TSimdCmpeqEpi8Func = function(a, b: TSimd128): TSimd128;
  TSimdCmpgtEpi8Func = function(a, b: TSimd128): TSimd128;
  
  TSimdAnd128Func = function(a, b: TSimd128): TSimd128;
  TSimdOr128Func = function(a, b: TSimd128): TSimd128;
  TSimdXor128Func = function(a, b: TSimd128): TSimd128;
  TSimdAndnot128Func = function(a, b: TSimd128): TSimd128;
  
  TSimdAddEpi8Func = function(a, b: TSimd128): TSimd128;
  TSimdSubEpi8Func = function(a, b: TSimd128): TSimd128;
  
  TSimdMovemaskEpi8Func = function(a: TSimd128): Integer;

  // 256-bit 操作函数指针
  TSimdLoad256Func = function(p: Pointer): TSimd256;
  TSimdLoadu256Func = function(p: Pointer): TSimd256;
  TSimdStore256Proc = procedure(p: Pointer; a: TSimd256);
  TSimdStoreu256Proc = procedure(p: Pointer; a: TSimd256);

  TSimdSet1Epi8_256Func = function(a: Byte): TSimd256;
  TSimdSetzero256Func = function: TSimd256;

  TSimdCmpeqEpi8_256Func = function(a, b: TSimd256): TSimd256;
  TSimdMovemaskEpi8_256Func = function(a: TSimd256): Integer;

// === 跨平台 Intrinsics 接口声明 ===
// 这些函数的实现在以下模块中：
// - nextpas.core.simd.intrinsics.scalar (标量实现)
// - 平台特定模块 (SIMD 优化实现)

// 注意：这里只做类型定义，具体的函数实现在其他模块中

// === 常量定义 ===
const
  SIMD_ALIGNMENT_128 = 16;
  SIMD_ALIGNMENT_256 = 32;
  SIMD_ALIGNMENT_512 = 64;

// === 辅助宏和内联函数 ===
{$IFDEF SIMD_AGGRESSIVE_INLINE}
  {$DEFINE SIMD_INLINE := inline;}
{$ELSE}
  {$DEFINE SIMD_INLINE := ;}
{$ENDIF}

implementation

// 这个模块只包含类型定义和接口声明
// 具体实现在以下模块中：
// - nextpas.core.simd.intrinsics.scalar (标量回退实现)
// - nextpas.core.simd.intrinsics.x86.* (x86 SIMD 实现)
// - nextpas.core.simd.intrinsics.arm.* (ARM SIMD 实现)

end.


