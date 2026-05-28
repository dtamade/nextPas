// Historical umbrella — not part of stable surface.
// Use specific intrinsics units (e.g. intrinsics.x86.sse2) directly.
unit nextpas.core.simd.intrinsics;

{$mode objfpc}
{$I nextpas.core.settings.inc}

{
  === nextpas.core.simd.intrinsics ===
  历史 low-level convenience umbrella

  这个模块不是 nextpas.core.simd 的主 façade，也不是 backend control-plane。
  它只提供：
  1. 统一的低层寄存器类型与 helper 声明
  2. 少量 capability helper
  3. 受 guard 约束的 intrinsics 级便捷入口

  不负责：
  - backend registration
  - dispatch table wiring
  - runtime backend selection
  - 把 experimental family 自动提升为默认主线

  Supported ISA families:
  - x86/x64: MMX, SSE, SSE2, SSE3, SSE4.1, SSE4.2, AVX, AVX2, AVX-512, AES, SHA, FMA3
  - ARM: NEON, SVE, SVE2
  - RISC-V: RVV (Vector Extension)
  - LoongArch: LASX

  Usage:
    uses nextpas.core.simd.intrinsics;

    var
      a, b, result: TM128;
    begin
      a := simd_set1_epi32(42);
      b := simd_set1_epi32(24);
      result := simd_add_epi32(a, b);
    end;
}

interface

uses
  nextpas.core.simd.intrinsics.base;

// === 重新导出基础类型 ===
type
  // 128-bit 向量类型
  TM128 = nextpas.core.simd.intrinsics.base.TM128;
  PTM128 = ^TM128;

  // 256-bit 向量类型 (AVX)
  TM256 = nextpas.core.simd.intrinsics.base.TSimd256;
  PTM256 = ^TM256;

  // 512-bit 向量类型 (AVX-512)
  TM512 = nextpas.core.simd.intrinsics.base.TSimd512;
  PTM512 = ^TM512;

// === ISA capability probes ===
function simd_has_mmx: Boolean;
function simd_has_sse: Boolean;
function simd_has_sse2: Boolean;
function simd_has_sse3: Boolean;
function simd_has_sse41: Boolean;
function simd_has_sse42: Boolean;
function simd_has_avx: Boolean;
function simd_has_avx2: Boolean;
function simd_has_avx512f: Boolean;
function simd_has_aes: Boolean;
function simd_has_sha: Boolean;
function simd_has_fma3: Boolean;

// === Baseline SSE2 helpers (the common x64 floor) ===
// Load/Store
function simd_load_si128(const Ptr: Pointer): TM128;
function simd_loadu_si128(const Ptr: Pointer): TM128;
procedure simd_store_si128(var Dest; const Src: TM128);
procedure simd_storeu_si128(var Dest; const Src: TM128);

// Set/Zero
function simd_setzero_si128: TM128;
function simd_set1_epi32(Value: LongInt): TM128;
function simd_set1_epi16(Value: SmallInt): TM128;
function simd_set1_epi8(Value: ShortInt): TM128;

// Arithmetic
function simd_add_epi32(const a, b: TM128): TM128;
function simd_add_epi16(const a, b: TM128): TM128;
function simd_add_epi8(const a, b: TM128): TM128;
function simd_sub_epi32(const a, b: TM128): TM128;
function simd_sub_epi16(const a, b: TM128): TM128;
function simd_sub_epi8(const a, b: TM128): TM128;

// Logical
function simd_and_si128(const a, b: TM128): TM128;
function simd_or_si128(const a, b: TM128): TM128;
function simd_xor_si128(const a, b: TM128): TM128;
function simd_andnot_si128(const a, b: TM128): TM128;

// Compare
function simd_cmpeq_epi32(const a, b: TM128): TM128;
function simd_cmpeq_epi16(const a, b: TM128): TM128;
function simd_cmpeq_epi8(const a, b: TM128): TM128;
function simd_cmpgt_epi32(const a, b: TM128): TM128;
function simd_cmpgt_epi16(const a, b: TM128): TM128;
function simd_cmpgt_epi8(const a, b: TM128): TM128;

// Shift
function simd_slli_epi32(const a: TM128; imm8: Byte): TM128;
function simd_srli_epi32(const a: TM128; imm8: Byte): TM128;
function simd_srai_epi32(const a: TM128; imm8: Byte): TM128;

// === Higher-level helpers with ISA-aware behavior ===
function simd_max_epi8(const a, b: TM128): TM128;   // SSE4.1 优化，SSE2 兼容
function simd_min_epi8(const a, b: TM128): TM128;   // SSE4.1 优化，SSE2 兼容
function simd_max_epi32(const a, b: TM128): TM128;  // SSE4.1 优化，SSE2 兼容
function simd_min_epi32(const a, b: TM128): TM128;  // SSE4.1 优化，SSE2 兼容

// === 浮点运算 ===
function simd_add_ps(const a, b: TM128): TM128;     // single-precision floating-point add
function simd_add_pd(const a, b: TM128): TM128;     // double-precision floating-point add
function simd_mul_ps(const a, b: TM128): TM128;     // single-precision floating-point multiply
function simd_mul_pd(const a, b: TM128): TM128;

implementation

uses
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.base;

// 暂时只提供基础 Pascal 实现，后续会添加具体指令集模块的调用
//
// 指令集检测统一委托给 nextpas.core.simd.cpuinfo：
// - 对于 SSE/AVX 等 x86 特性，使用 TCPUInfo.X86 中的字段
// - 对于需要考虑 OS 支持的特性（如 AVX2/AVX-512），使用 HasAVX2/HasAVX512

// === 指令集检测实现 ===

function simd_has_mmx: Boolean;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  Result := GetCPUInfo.X86.HasMMX;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function simd_has_sse: Boolean;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  Result := GetCPUInfo.X86.HasSSE;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function simd_has_sse2: Boolean;
begin
  // SSE2 is baseline on x86_64; delegate to cpuinfo helper for clarity
  Result := HasSSE2;
end;

function simd_has_sse3: Boolean;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  Result := GetCPUInfo.X86.HasSSE3;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function simd_has_sse41: Boolean;
begin
  Result := HasSSE41;
end;

function simd_has_sse42: Boolean;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  Result := GetCPUInfo.X86.HasSSE42;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function simd_has_avx: Boolean;
var
  LCPUInfo: TCPUInfo;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;
  Result := (LCPUInfo.Arch = caX86) and LCPUInfo.X86.HasAVX and
            (gfSimd256 in LCPUInfo.GenericUsable);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function simd_has_avx2: Boolean;
begin
  // AVX2 requires both hardware support and OS enabling of YMM state
  Result := HasAVX2;
end;

function simd_has_avx512f: Boolean;
begin
  // AVX-512F requires hardware support and OS enabling of ZMM/opmask state
  Result := HasAVX512;
end;

function simd_has_aes: Boolean;
var
  LCPUInfo: TCPUInfo;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;
  Result := (LCPUInfo.Arch = caX86) and LCPUInfo.X86.HasAES and
            (gfAES in LCPUInfo.GenericUsable);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function simd_has_sha: Boolean;
var
  LCPUInfo: TCPUInfo;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;
  Result := (LCPUInfo.Arch = caX86) and LCPUInfo.X86.HasSHA and
            (gfSHA in LCPUInfo.GenericUsable);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function simd_has_fma3: Boolean;
var
  LCPUInfo: TCPUInfo;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LCPUInfo := GetCPUInfo;
  Result := (LCPUInfo.Arch = caX86) and LCPUInfo.X86.HasFMA and
            (gfFMA in LCPUInfo.GenericUsable);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

// === Baseline helper implementations (Pascal first, ISA tuning later) ===
function SIMDLoadTM128(const Ptr: Pointer): TM128; inline;
begin
  Result := PTM128(Ptr)^;
end;

procedure SIMDStoreTM128(var aDest; const aSrc: TM128); inline;
begin
  PTM128(@aDest)^ := aSrc;
end;

procedure SIMDSetTM128I32(var aResult: TM128; const aValue: LongInt); inline;
var
  i: Integer;
begin
  for i := 0 to 3 do
    aResult.m128i_i32[i] := aValue;
end;

procedure SIMDSetTM128I16(var aResult: TM128; const aValue: SmallInt); inline;
var
  i: Integer;
begin
  for i := 0 to 7 do
    aResult.m128i_i16[i] := aValue;
end;

procedure SIMDSetTM128I8(var aResult: TM128; const aValue: ShortInt); inline;
var
  i: Integer;
begin
  for i := 0 to 15 do
    aResult.m128i_i8[i] := aValue;
end;

function simd_load_si128(const Ptr: Pointer): TM128;
begin
  Result := SIMDLoadTM128(Ptr);
end;

function simd_loadu_si128(const Ptr: Pointer): TM128;
begin
  Result := SIMDLoadTM128(Ptr);
end;

procedure simd_store_si128(var Dest; const Src: TM128);
begin
  SIMDStoreTM128(Dest, Src);
end;

procedure simd_storeu_si128(var Dest; const Src: TM128);
begin
  SIMDStoreTM128(Dest, Src);
end;

function simd_setzero_si128: TM128;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

function simd_set1_epi32(Value: LongInt): TM128;
begin
  SIMDSetTM128I32(Result, Value);
end;

function simd_set1_epi16(Value: SmallInt): TM128;
begin
  SIMDSetTM128I16(Result, Value);
end;

function simd_set1_epi8(Value: ShortInt): TM128;
begin
  SIMDSetTM128I8(Result, Value);
end;

function simd_add_epi32(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128i_i32[i] := a.m128i_i32[i] + b.m128i_i32[i];
end;

function simd_add_epi16(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m128i_i16[i] := a.m128i_i16[i] + b.m128i_i16[i];
end;

function simd_add_epi8(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.m128i_i8[i] := a.m128i_i8[i] + b.m128i_i8[i];
end;

function simd_sub_epi32(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128i_i32[i] := a.m128i_i32[i] - b.m128i_i32[i];
end;

function simd_sub_epi16(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.m128i_i16[i] := a.m128i_i16[i] - b.m128i_i16[i];
end;

function simd_sub_epi8(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.m128i_i8[i] := a.m128i_i8[i] - b.m128i_i8[i];
end;

function simd_and_si128(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128i_u32[i] := a.m128i_u32[i] and b.m128i_u32[i];
end;

function simd_or_si128(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128i_u32[i] := a.m128i_u32[i] or b.m128i_u32[i];
end;

function simd_xor_si128(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128i_u32[i] := a.m128i_u32[i] xor b.m128i_u32[i];
end;

function simd_andnot_si128(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128i_u32[i] := (not a.m128i_u32[i]) and b.m128i_u32[i];
end;

function simd_cmpeq_epi32(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.m128i_i32[i] = b.m128i_i32[i] then
      Result.m128i_u32[i] := $FFFFFFFF
    else
      Result.m128i_u32[i] := $00000000;
end;

function simd_cmpeq_epi16(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.m128i_i16[i] = b.m128i_i16[i] then
      Result.m128i_u16[i] := $FFFF
    else
      Result.m128i_u16[i] := $0000;
end;

function simd_cmpeq_epi8(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.m128i_i8[i] = b.m128i_i8[i] then
      Result.m128i_u8[i] := $FF
    else
      Result.m128i_u8[i] := $00;
end;

function simd_cmpgt_epi32(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.m128i_i32[i] > b.m128i_i32[i] then
      Result.m128i_u32[i] := $FFFFFFFF
    else
      Result.m128i_u32[i] := $00000000;
end;

function simd_cmpgt_epi16(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.m128i_i16[i] > b.m128i_i16[i] then
      Result.m128i_u16[i] := $FFFF
    else
      Result.m128i_u16[i] := $0000;
end;

function simd_cmpgt_epi8(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.m128i_i8[i] > b.m128i_i8[i] then
      Result.m128i_u8[i] := $FF
    else
      Result.m128i_u8[i] := $00;
end;

function simd_slli_epi32(const a: TM128; imm8: Byte): TM128;
var
  i: Integer;
begin
  if imm8 >= 32 then
  begin
    FillChar(Result, SizeOf(Result), 0);
  end
  else
  begin
    for i := 0 to 3 do
      Result.m128i_u32[i] := a.m128i_u32[i] shl imm8;
  end;
end;

function simd_srli_epi32(const a: TM128; imm8: Byte): TM128;
var
  i: Integer;
begin
  if imm8 >= 32 then
  begin
    FillChar(Result, SizeOf(Result), 0);
  end
  else
  begin
    for i := 0 to 3 do
      Result.m128i_u32[i] := a.m128i_u32[i] shr imm8;
  end;
end;

function simd_srai_epi32(const a: TM128; imm8: Byte): TM128;
var
  i: Integer;
  shift_count: Byte;
  value: LongInt;
begin
  shift_count := imm8;
  if shift_count >= 32 then
    shift_count := 31; // Arithmetic right shift saturates at 31 bits.
  for i := 0 to 3 do
  begin
    value := a.m128i_i32[i];
    // 手动实现算术右移
    if shift_count = 0 then
      Result.m128i_i32[i] := value
    else if value >= 0 then
      Result.m128i_i32[i] := value shr shift_count
    else
      Result.m128i_i32[i] := (value shr shift_count) or ((-1) shl (32 - shift_count));
  end;
end;

function simd_max_epi8(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.m128i_i8[i] > b.m128i_i8[i] then
      Result.m128i_i8[i] := a.m128i_i8[i]
    else
      Result.m128i_i8[i] := b.m128i_i8[i];
end;

function simd_min_epi8(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.m128i_i8[i] < b.m128i_i8[i] then
      Result.m128i_i8[i] := a.m128i_i8[i]
    else
      Result.m128i_i8[i] := b.m128i_i8[i];
end;

function simd_max_epi32(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.m128i_i32[i] > b.m128i_i32[i] then
      Result.m128i_i32[i] := a.m128i_i32[i]
    else
      Result.m128i_i32[i] := b.m128i_i32[i];
end;

function simd_min_epi32(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.m128i_i32[i] < b.m128i_i32[i] then
      Result.m128i_i32[i] := a.m128i_i32[i]
    else
      Result.m128i_i32[i] := b.m128i_i32[i];
end;

function simd_add_ps(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128_f32[i] := a.m128_f32[i] + b.m128_f32[i];
end;

function simd_add_pd(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.m128d_f64[i] := a.m128d_f64[i] + b.m128d_f64[i];
end;

function simd_mul_ps(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.m128_f32[i] := a.m128_f32[i] * b.m128_f32[i];
end;

function simd_mul_pd(const a, b: TM128): TM128;
var
  i: Integer;
begin
  for i := 0 to 1 do
    Result.m128d_f64[i] := a.m128d_f64[i] * b.m128d_f64[i];
end;

end.

