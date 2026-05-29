unit nextpas.core.simd.avx2;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}
{$asmmode intel}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.mask,
  nextpas.core.simd.backend.priority;

// === AVX2 Backend Implementation ===
// Provides SIMD-accelerated operations using x86-64 AVX2 instructions.
// This backend requires AVX2 support (Intel Haswell 2013+, AMD Excavator 2015+).
//
// vzeroupper policy
// ============================================================
// 所有使用 YMM 寄存器的 AVX2 函数必须在返回前调用 vzeroupper。
// 这可以避免从 AVX 代码调用 SSE 代码时的 SSE/AVX 状态转换惩罚。
//
// 惩罚原因:
//   - 当 YMM 寄存器的上半部分不干净时，后续 SSE 指令会触发部分寄存器暂存
//   - 在某些 CPU 上可能导致 70+ 周期的延迟
//
// 正确模式:
//   function AVX2Foo(...): ...;
//   asm
//     vmovups ymm0, [...]
//     ... AVX2 操作 ...
//     vmovups [...], ymm0
//     vzeroupper          // <-- 必须在返回前调用
//   end;
//
// 何时需要 vzeroupper:
//   - 任何使用 256-bit YMM 寄存器的汇编函数
//   - 即使函数返回标量值（因为调用者可能使用 SSE）
//
// 何时不需要:
//   - 仅使用 128-bit XMM 寄存器的函数
//   - 纯 Pascal 函数（无内联汇编）
// ============================================================

// Register the AVX2 backend
procedure RegisterAVX2Backend;

// === AVX2 门面函数声明 ===

// 内存操作函数
function MemEqual_AVX2(a, b: Pointer; len: SizeUInt): LongBool;
function MemFindByte_AVX2(p: Pointer; len: SizeUInt; value: Byte): PtrInt;

// 统计函数
function SumBytes_AVX2(p: Pointer; len: SizeUInt): UInt64;
function CountByte_AVX2(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
procedure MinMaxBytes_AVX2(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
function BitsetPopCount_AVX2(p: Pointer; len: SizeUInt): SizeUInt;
function Utf8Validate_AVX2(p: Pointer; len: SizeUInt): Boolean;
procedure MemReverse_AVX2(p: Pointer; len: SizeUInt);
function AsciiIEqual_AVX2(a, b: Pointer; len: SizeUInt): Boolean;
procedure ToLowerAscii_AVX2(p: Pointer; len: SizeUInt);
procedure ToUpperAscii_AVX2(p: Pointer; len: SizeUInt);
function MemDiffRange_AVX2(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
function BytesIndexOf_AVX2(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;

// 内存操作函数 (使用 FPC 内置函数，已足够快)
procedure MemCopy_AVX2(src, dst: Pointer; len: SizeUInt);
procedure MemSet_AVX2(dst: Pointer; len: SizeUInt; value: Byte);

implementation

uses
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.scalar; // For fallback functions

function AVX2CmpGtI32x4(const a, b: TVecI32x4): TMask4; forward;
function AVX2CmpGtI16x8(const a, b: TVecI16x8): TMask8; forward;
function AVX2CmpGtI8x16(const a, b: TVecI8x16): TMask16; forward;
function AVX2CmpGtU32x4(const a, b: TVecU32x4): TMask4; forward;
function AVX2CmpGtU16x8(const a, b: TVecU16x8): TMask8; forward;
function AVX2CmpGtU8x16(const a, b: TVecU8x16): TMask16; forward;
function AVX2CmpGtU64x2(const a, b: TVecU64x2): TMask2; forward;

// === AVX2 Arithmetic Operations ===
// Note: FPC x86-64 calling convention:
//   - First 6 integer/pointer args: RDI, RSI, RDX, RCX, R8, R9
//   - Float args: XMM0-XMM7
//   - Result pointer for large structs: hidden first arg in RDI
//   - For const record params, pointer is passed

function AVX2AddF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovups xmm0, [rax]
    vaddps xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

function AVX2SubF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovups xmm0, [rax]
    vsubps xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

function AVX2MulF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovups xmm0, [rax]
    vmulps xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

function AVX2DivF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovups xmm0, [rax]
    vdivps xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

function AVX2FmaF32x4(const a, b, c: TVecF32x4): TVecF32x4;
begin
  // 仅当 CPU + OS 均支持 FMA(AVX state) 时，才执行 vfmadd* 指令
  if HasFeature(gfFMA) then
  begin
    asm
      lea      rax, a
      lea      rdx, b
      lea      rcx, c
      vmovups  xmm0, [rcx]          // xmm0 = c
      vmovups  xmm1, [rax]          // xmm1 = a
      vfmadd231ps xmm0, xmm1, [rdx] // xmm0 = a*b + c (fused)
      vmovups  [result], xmm0
    end;
  end
  else
    Result := ScalarFmaF32x4(a, b, c);
end;

function AVX2RcpF32x4(const a: TVecF32x4): TVecF32x4;
begin
  asm
    lea    rax, a
    vmovups xmm0, [rax]
    vrcpps xmm0, xmm0
    vmovups [result], xmm0
  end;
end;

function AVX2RsqrtF32x4(const a: TVecF32x4): TVecF32x4;
begin
  asm
    lea     rax, a
    vmovups xmm0, [rax]
    vrsqrtps xmm0, xmm0
    vmovups [result], xmm0
  end;
end;

function AVX2FloorF32x4(const a: TVecF32x4): TVecF32x4;
begin
  if HasSSE41 then
  begin
    asm
      lea    rax, a
      vmovups xmm0, [rax]
      // roundps xmm0, xmm0, 1  (floor)
      db $66, $0F, $3A, $08, $C0, $01
      vmovups [result], xmm0
    end;
  end
  else
    Result := ScalarFloorF32x4(a);
end;

function AVX2CeilF32x4(const a: TVecF32x4): TVecF32x4;
begin
  if HasSSE41 then
  begin
    asm
      lea    rax, a
      vmovups xmm0, [rax]
      // roundps xmm0, xmm0, 2  (ceil)
      db $66, $0F, $3A, $08, $C0, $02
      vmovups [result], xmm0
    end;
  end
  else
    Result := ScalarCeilF32x4(a);
end;

function AVX2RoundF32x4(const a: TVecF32x4): TVecF32x4;
begin
  if HasSSE41 then
  begin
    asm
      lea    rax, a
      vmovups xmm0, [rax]
      // roundps xmm0, xmm0, 0  (round to nearest even)
      db $66, $0F, $3A, $08, $C0, $00
      vmovups [result], xmm0
    end;
  end
  else
    Result := ScalarRoundF32x4(a);
end;

function AVX2TruncF32x4(const a: TVecF32x4): TVecF32x4;
begin
  if HasSSE41 then
  begin
    asm
      lea    rax, a
      vmovups xmm0, [rax]
      // roundps xmm0, xmm0, 3  (truncate)
      db $66, $0F, $3A, $08, $C0, $03
      vmovups [result], xmm0
    end;
  end
  else
    Result := ScalarTruncF32x4(a);
end;

function AVX2ClampF32x4(const a, minVal, maxVal: TVecF32x4): TVecF32x4;
begin
  // 语义对齐：与 ScalarClampF32x4 相同的计算顺序：
  //   Max(minVal, Min(a, maxVal))
  // 注意：vmin/vmax 在 NaN 场景下是“返回第二操作数”，因此 operand 顺序必须匹配标量实现。
  asm
    lea     rax, a
    lea     rdx, minVal
    lea     rcx, maxVal

    vmovups xmm0, [rax]
    vminps  xmm0, xmm0, [rcx]   // temp = Min(a, maxVal)  (maxVal as 2nd operand)

    vmovups xmm1, [rdx]
    vmaxps  xmm0, xmm1, xmm0    // result = Max(minVal, temp) (temp as 2nd operand)

    vmovups [result], xmm0
  end;
end;

// === Vector Math Functions ===

function AVX2DotF32x4(const a, b: TVecF32x4): Single;
begin
  // Tiny-vector fast path: for 4-lane dot, scalar expression avoids asm call/setup overhead
  // and is consistently faster on current FPC/x86_64 codegen.
  Result := a.f[0] * b.f[0] + a.f[1] * b.f[1] + a.f[2] * b.f[2] + a.f[3] * b.f[3];
end;

function AVX2DotF32x3(const a, b: TVecF32x4): Single;
begin
  asm
    lea      rax, a
    lea      rdx, b
    vmovups  xmm0, [rax]
    vmovups  xmm1, [rdx]
    vmulps   xmm0, xmm0, xmm1

    // Zero w before summing (mask = [FFFFFFFF,FFFFFFFF,FFFFFFFF,00000000])
    vpcmpeqd xmm1, xmm1, xmm1
    vpsrldq  xmm1, xmm1, 4
    vandps   xmm0, xmm0, xmm1

    // Horizontal add
    vshufps  xmm1, xmm0, xmm0, $4E
    vaddps   xmm0, xmm0, xmm1
    vshufps  xmm1, xmm0, xmm0, $B1
    vaddss   xmm0, xmm0, xmm1

    vmovss   [result], xmm0
  end;
end;

// FMA-optimized Dot Product Functions

function AVX2DotF32x8(const a, b: TVecF32x8): Single;
begin
  // Short-vector API hot path: unrolled scalar expression avoids costly horizontal reduction.
  Result :=
    a.f[0] * b.f[0] + a.f[1] * b.f[1] + a.f[2] * b.f[2] + a.f[3] * b.f[3] +
    a.f[4] * b.f[4] + a.f[5] * b.f[5] + a.f[6] * b.f[6] + a.f[7] * b.f[7];
end;

function AVX2DotF64x2(const a, b: TVecF64x2): Double;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovupd xmm0, [rax]      // 加载 a
    vmovupd xmm1, [rdx]      // 加载 b
    vmulpd  xmm0, xmm0, xmm1 // a * b

    // 水平加法: xmm0[1] + xmm0[0]
    vshufpd xmm1, xmm0, xmm0, 1 // 交换两个元素
    addsd   xmm0, xmm1           // 相加

    vmovsd  [result], xmm0
  end;
end;

function AVX2DotF64x4(const a, b: TVecF64x4): Double;
var
  pa, pb: Pointer;
begin
  pa := @a;
  pb := @b;
  asm
    mov    rax, pa
    mov    rdx, pb
    vmovupd ymm0, [rax]      // 加载 a
    vmovupd ymm1, [rdx]      // 加载 b
    vmulpd  ymm0, ymm0, ymm1 // a * b

    // 水平规约
    vhaddpd ymm0, ymm0, ymm0 // [0+1, 0+1, 2+3, 2+3]

    // 将高 128 位和低 128 位相加
    vextractf128 xmm1, ymm0, 1 // 提取高 128 位
    addsd   xmm0, xmm1          // 相加低位标量

    vmovsd  [result], xmm0
    vzeroupper               // 清理 YMM 寄存器状态
  end;
end;


function AVX2CrossF32x3(const a, b: TVecF32x4): TVecF32x4;
begin
  // Cross = (a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x, 0)
  asm
    lea     rax, a
    lea     rdx, b
    vmovups xmm0, [rax]        // a = [x, y, z, w]
    vmovups xmm1, [rdx]        // b = [x, y, z, w]

    // Shuffle a: [y, z, x, w]
    vshufps xmm2, xmm0, xmm0, $C9
    // Shuffle b: [z, x, y, w]
    vshufps xmm3, xmm1, xmm1, $D2
    vmulps  xmm2, xmm2, xmm3

    // Shuffle a: [z, x, y, w]
    vshufps xmm4, xmm0, xmm0, $D2
    // Shuffle b: [y, z, x, w]
    vshufps xmm5, xmm1, xmm1, $C9
    vmulps  xmm4, xmm4, xmm5

    vsubps  xmm2, xmm2, xmm4
    vmovups [result], xmm2
  end;
  Result.f[3] := 0.0; // Ensure w=0
end;

function AVX2LengthWithOptionalZeroW(const a: TVecF32x4; aZeroW: Boolean): Single; inline;
var
  LPA: Pointer;
begin
  LPA := @a;
  if aZeroW then
  begin
    asm
      mov     rax, LPA
      vmovups xmm0, [rax]
      vpcmpeqd xmm1, xmm1, xmm1
      vpsrldq  xmm1, xmm1, 4
      vandps   xmm0, xmm0, xmm1
      vmulps   xmm0, xmm0, xmm0

      // Horizontal add
      vshufps xmm1, xmm0, xmm0, $4E
      vaddps  xmm0, xmm0, xmm1
      vshufps xmm1, xmm0, xmm0, $B1
      vaddss   xmm0, xmm0, xmm1

      vsqrtss xmm0, xmm0, xmm0
      vmovss  [result], xmm0
    end;
  end
  else
  begin
    asm
      mov     rax, LPA
      vmovups xmm0, [rax]
      vmulps  xmm0, xmm0, xmm0

      // Horizontal add
      vshufps xmm1, xmm0, xmm0, $4E
      vaddps  xmm0, xmm0, xmm1
      vshufps xmm1, xmm0, xmm0, $B1
      vaddss  xmm0, xmm0, xmm1

      vsqrtss xmm0, xmm0, xmm0
      vmovss  [result], xmm0
    end;
  end;
end;

function AVX2NormalizeByLength(const a: TVecF32x4; const aLen: Single; aZeroW: Boolean): TVecF32x4; inline;
var
  LPA, LPR: Pointer;
begin
  if aLen > 0.0 then
  begin
    LPA := @a;
    LPR := @Result;
    asm
      mov     rax, LPA
      mov     rcx, LPR
      vmovups xmm0, [rax]
      vmovss  xmm1, aLen
      vshufps xmm1, xmm1, xmm1, 0
      vdivps  xmm0, xmm0, xmm1
      vmovups [rcx], xmm0
    end;
    if aZeroW then
      Result.f[3] := 0.0;
  end
  else
  begin
    Result := a;
    if aZeroW then
      Result.f[3] := 0.0;
  end;
end;

function AVX2LengthF32x4(const a: TVecF32x4): Single;
begin
  Result := AVX2LengthWithOptionalZeroW(a, False);
end;

function AVX2LengthF32x3(const a: TVecF32x4): Single;
begin
  Result := AVX2LengthWithOptionalZeroW(a, True);
end;

function AVX2NormalizeF32x4(const a: TVecF32x4): TVecF32x4;
var
  len: Single;
begin
  len := AVX2LengthWithOptionalZeroW(a, False);
  Result := AVX2NormalizeByLength(a, len, False);
end;

function AVX2NormalizeF32x3(const a: TVecF32x4): TVecF32x4;
var
  len: Single;
begin
  len := AVX2LengthWithOptionalZeroW(a, True);
  Result := AVX2NormalizeByLength(a, len, True);
end;

function AVX2AddF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovupd xmm0, [rax]
    vaddpd xmm0, xmm0, [rdx]
    vmovupd [result], xmm0
  end;
end;

function AVX2SubF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovupd xmm0, [rax]
    vsubpd xmm0, xmm0, [rdx]
    vmovupd [result], xmm0
  end;
end;

function AVX2MulF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovupd xmm0, [rax]
    vmulpd xmm0, xmm0, [rdx]
    vmovupd [result], xmm0
  end;
end;

function AVX2DivF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovupd xmm0, [rax]
    vdivpd xmm0, xmm0, [rdx]
    vmovupd [result], xmm0
  end;
end;

// === F64x2 Math Operations (128-bit) ===

function AVX2AbsF64x2(const a: TVecF64x2): TVecF64x2;
begin
  // Generate AbsMask dynamically (PIC-safe): 0x7FFFFFFFFFFFFFFF
  asm
    lea      rax, a
    vmovupd  xmm0, [rax]
    vpcmpeqd xmm1, xmm1, xmm1  // all 1s
    vpsrlq   xmm1, xmm1, 1     // shift right 1 = 0x7FFFFFFFFFFFFFFF
    vandpd   xmm0, xmm0, xmm1
    vmovupd  [result], xmm0
  end;
end;

function AVX2SqrtF64x2(const a: TVecF64x2): TVecF64x2;
begin
  asm
    lea     rax, a
    vmovupd xmm0, [rax]
    vsqrtpd xmm0, xmm0
    vmovupd [result], xmm0
  end;
end;

function AVX2MinF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovupd xmm0, [rax]
    vminpd  xmm0, xmm0, [rdx]
    vmovupd [result], xmm0
  end;
end;

function AVX2MaxF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovupd xmm0, [rax]
    vmaxpd  xmm0, xmm0, [rdx]
    vmovupd [result], xmm0
  end;
end;

function AVX2ClampF64x2(const a, minVal, maxVal: TVecF64x2): TVecF64x2;
begin
  asm
    lea     rax, a
    lea     rdx, minVal
    lea     rcx, maxVal
    vmovupd xmm0, [rax]
    vmaxpd  xmm0, xmm0, [rdx]   // clamp to min
    vminpd  xmm0, xmm0, [rcx]   // clamp to max
    vmovupd [result], xmm0
  end;
end;

// === F64x2 Reduction Operations (128-bit) ===

function AVX2ReduceAddF64x2(const a: TVecF64x2): Double;
begin
  asm
    lea      rax, a
    vmovupd  xmm0, [rax]
    vhaddpd  xmm0, xmm0, xmm0   // horizontal add
    vmovsd   [result], xmm0
  end;
end;

function AVX2ReduceMinF64x2(const a: TVecF64x2): Double;
begin
  asm
    lea      rax, a
    vmovupd  xmm0, [rax]
    vshufpd  xmm1, xmm0, xmm0, 1  // swap elements
    vminpd   xmm0, xmm0, xmm1
    vmovsd   [result], xmm0
  end;
end;

function AVX2ReduceMaxF64x2(const a: TVecF64x2): Double;
begin
  asm
    lea      rax, a
    vmovupd  xmm0, [rax]
    vshufpd  xmm1, xmm0, xmm0, 1  // swap elements
    vmaxpd   xmm0, xmm0, xmm1
    vmovsd   [result], xmm0
  end;
end;

function AVX2ReduceMulF64x2(const a: TVecF64x2): Double;
begin
  asm
    lea      rax, a
    vmovupd  xmm0, [rax]
    vshufpd  xmm1, xmm0, xmm0, 1  // swap elements
    vmulpd   xmm0, xmm0, xmm1
    vmovsd   [result], xmm0
  end;
end;

// === F64x2 Comparison Operations (128-bit) ===

function AVX2CmpEqF64x2(const a, b: TVecF64x2): TMask2;
var mask: Integer;
begin
  asm
    lea       rax, a
    lea       rdx, b
    vmovupd   xmm0, [rax]
    vcmpeqpd  xmm0, xmm0, [rdx]
    vmovmskpd eax, xmm0
    mov       mask, eax
  end;
  Result := TMask2(mask);
end;

function AVX2CmpLtF64x2(const a, b: TVecF64x2): TMask2;
var mask: Integer;
begin
  asm
    lea       rax, a
    lea       rdx, b
    vmovupd   xmm0, [rax]
    vcmpltpd  xmm0, xmm0, [rdx]
    vmovmskpd eax, xmm0
    mov       mask, eax
  end;
  Result := TMask2(mask);
end;

function AVX2CmpLeF64x2(const a, b: TVecF64x2): TMask2;
var mask: Integer;
begin
  asm
    lea       rax, a
    lea       rdx, b
    vmovupd   xmm0, [rax]
    vcmplepd  xmm0, xmm0, [rdx]
    vmovmskpd eax, xmm0
    mov       mask, eax
  end;
  Result := TMask2(mask);
end;

function AVX2CmpGtF64x2(const a, b: TVecF64x2): TMask2;
var mask: Integer;
begin
  // GT: swap operands and use LT (a > b = b < a)
  asm
    lea       rax, b
    lea       rdx, a
    vmovupd   xmm0, [rax]
    vcmpltpd  xmm0, xmm0, [rdx]
    vmovmskpd eax, xmm0
    mov       mask, eax
  end;
  Result := TMask2(mask);
end;

function AVX2CmpGeF64x2(const a, b: TVecF64x2): TMask2;
var mask: Integer;
begin
  // GE: swap operands and use LE (a >= b = b <= a)
  asm
    lea       rax, b
    lea       rdx, a
    vmovupd   xmm0, [rax]
    vcmplepd  xmm0, xmm0, [rdx]
    vmovmskpd eax, xmm0
    mov       mask, eax
  end;
  Result := TMask2(mask);
end;

function AVX2CmpNeF64x2(const a, b: TVecF64x2): TMask2;
var mask: Integer;
begin
  asm
    lea        rax, a
    lea        rdx, b
    vmovupd    xmm0, [rax]
    vcmpneqpd  xmm0, xmm0, [rdx]
    vmovmskpd  eax, xmm0
    mov        mask, eax
  end;
  Result := TMask2(mask);
end;

// === F64x2 Extended Math Operations (128-bit) ===

function AVX2FmaF64x2(const a, b, c: TVecF64x2): TVecF64x2;
begin
  if HasFeature(gfFMA) then
  begin
    asm
      lea       rax, a
      lea       rdx, b
      lea       rcx, c
      vmovupd   xmm0, [rcx]           // xmm0 = c
      vmovupd   xmm1, [rax]           // xmm1 = a
      vfmadd231pd xmm0, xmm1, [rdx]   // xmm0 = a*b + c (fused)
      vmovupd   [result], xmm0
    end;
  end
  else
    Result := ScalarFmaF64x2(a, b, c);
end;

function AVX2FloorF64x2(const a: TVecF64x2): TVecF64x2;
begin
  if HasSSE41 then
  begin
    asm
      lea      rax, a
      vmovupd  xmm0, [rax]
      vroundpd xmm0, xmm0, 1   // floor = round toward -inf
      vmovupd  [result], xmm0
    end;
  end
  else
    Result := ScalarFloorF64x2(a);
end;

function AVX2CeilF64x2(const a: TVecF64x2): TVecF64x2;
begin
  if HasSSE41 then
  begin
    asm
      lea      rax, a
      vmovupd  xmm0, [rax]
      vroundpd xmm0, xmm0, 2   // ceil = round toward +inf
      vmovupd  [result], xmm0
    end;
  end
  else
    Result := ScalarCeilF64x2(a);
end;

function AVX2RoundF64x2(const a: TVecF64x2): TVecF64x2;
begin
  if HasSSE41 then
  begin
    asm
      lea      rax, a
      vmovupd  xmm0, [rax]
      vroundpd xmm0, xmm0, 0   // round to nearest even
      vmovupd  [result], xmm0
    end;
  end
  else
    Result := ScalarRoundF64x2(a);
end;

function AVX2TruncF64x2(const a: TVecF64x2): TVecF64x2;
begin
  if HasSSE41 then
  begin
    asm
      lea      rax, a
      vmovupd  xmm0, [rax]
      vroundpd xmm0, xmm0, 3   // truncate = round toward zero
      vmovupd  [result], xmm0
    end;
  end
  else
    Result := ScalarTruncF64x2(a);
end;

// === F64x2 Load/Store/Splat/Zero Operations (128-bit) ===

function AVX2LoadF64x2(p: PDouble): TVecF64x2;
begin
  Assert(p <> nil, 'AVX2LoadF64x2: pointer is nil');
  asm
    mov      rax, p
    vmovupd  xmm0, [rax]
    vmovupd  [result], xmm0
  end;
end;

procedure AVX2StoreF64x2(p: PDouble; const a: TVecF64x2);
begin
  Assert(p <> nil, 'AVX2StoreF64x2: pointer is nil');
  asm
    mov      rax, p
    lea      rdx, a
    vmovupd  xmm0, [rdx]
    vmovupd  [rax], xmm0
  end;
end;

function AVX2SplatF64x2(value: Double): TVecF64x2;
var
  LValuePtr: PDouble;
begin
  LValuePtr := @value;
  asm
    mov         rdx, LValuePtr
    vmovddup    xmm0, [rdx]    // load scalar and duplicate to both lanes
    vmovupd     [result], xmm0
  end;
end;

function AVX2ZeroF64x2: TVecF64x2;
begin
  asm
    vxorpd   xmm0, xmm0, xmm0
    vmovupd  [result], xmm0
  end;
end;

// === AVX2 Integer Add/Sub/Shift Shared Kernels ===
// Same-width add/sub/logical-shift produce identical bit patterns across signedness.

procedure AVX2AddDwordVecRaw(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;
  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu xmm0, [rax]
    vpaddd  xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

procedure AVX2SubDwordVecRaw(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;
  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu xmm0, [rax]
    vpsubd  xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

procedure AVX2AddWordVecRaw(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;
  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu xmm0, [rax]
    vpaddw  xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

procedure AVX2SubWordVecRaw(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;
  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu xmm0, [rax]
    vpsubw  xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

procedure AVX2AddByteVecRaw(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;
  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu xmm0, [rax]
    vpaddb  xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

procedure AVX2SubByteVecRaw(const aLeftPtr, aRightPtr, aResultPtr: Pointer);
var
  LLeftPtr, LRightPtr, LResultPtr: Pointer;
begin
  LLeftPtr := aLeftPtr;
  LRightPtr := aRightPtr;
  LResultPtr := aResultPtr;
  asm
    mov     rax, LLeftPtr
    mov     rdx, LRightPtr
    mov     rcx, LResultPtr
    vmovdqu xmm0, [rax]
    vpsubb  xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

procedure AVX2ShiftLeftDwordVecRaw(const aValuePtr, aResultPtr: Pointer; aCount: Integer);
var
  LValuePtr, LResultPtr: Pointer;
  LCount: Integer;
begin
  LValuePtr := aValuePtr;
  LResultPtr := aResultPtr;
  LCount := aCount;

  if (LCount < 0) or (LCount >= 32) then
  begin
    FillChar(PByte(LResultPtr)^, SizeOf(TVecI32x4), 0);
    Exit;
  end;

  asm
    mov     rax, LValuePtr
    mov     rdx, LResultPtr
    vmovdqu xmm0, [rax]
    mov     ecx, LCount
    vmovd   xmm1, ecx
    vpslld  xmm0, xmm0, xmm1
    vmovdqu [rdx], xmm0
  end;
end;

procedure AVX2ShiftRightDwordVecRaw(const aValuePtr, aResultPtr: Pointer; aCount: Integer);
var
  LValuePtr, LResultPtr: Pointer;
  LCount: Integer;
begin
  LValuePtr := aValuePtr;
  LResultPtr := aResultPtr;
  LCount := aCount;

  if (LCount < 0) or (LCount >= 32) then
  begin
    FillChar(PByte(LResultPtr)^, SizeOf(TVecI32x4), 0);
    Exit;
  end;

  asm
    mov     rax, LValuePtr
    mov     rdx, LResultPtr
    vmovdqu xmm0, [rax]
    mov     ecx, LCount
    vmovd   xmm1, ecx
    vpsrld  xmm0, xmm0, xmm1
    vmovdqu [rdx], xmm0
  end;
end;

procedure AVX2ShiftLeftWordVecRaw(const aValuePtr, aResultPtr: Pointer; aCount: Integer);
var
  LValuePtr, LResultPtr: Pointer;
  LCount: Integer;
begin
  LValuePtr := aValuePtr;
  LResultPtr := aResultPtr;
  LCount := aCount;

  if (LCount < 0) or (LCount >= 16) then
  begin
    FillChar(PByte(LResultPtr)^, SizeOf(TVecI16x8), 0);
    Exit;
  end;

  asm
    mov     rax, LValuePtr
    mov     rdx, LResultPtr
    vmovdqu xmm0, [rax]
    mov     ecx, LCount
    vmovd   xmm1, ecx
    vpsllw  xmm0, xmm0, xmm1
    vmovdqu [rdx], xmm0
  end;
end;

procedure AVX2ShiftRightWordVecRaw(const aValuePtr, aResultPtr: Pointer; aCount: Integer);
var
  LValuePtr, LResultPtr: Pointer;
  LCount: Integer;
begin
  LValuePtr := aValuePtr;
  LResultPtr := aResultPtr;
  LCount := aCount;

  if (LCount < 0) or (LCount >= 16) then
  begin
    FillChar(PByte(LResultPtr)^, SizeOf(TVecI16x8), 0);
    Exit;
  end;

  asm
    mov     rax, LValuePtr
    mov     rdx, LResultPtr
    vmovdqu xmm0, [rax]
    mov     ecx, LCount
    vmovd   xmm1, ecx
    vpsrlw  xmm0, xmm0, xmm1
    vmovdqu [rdx], xmm0
  end;
end;

function AVX2AddI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  AVX2AddDwordVecRaw(@a, @b, @Result);
end;

function AVX2SubI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  AVX2SubDwordVecRaw(@a, @b, @Result);
end;

// === AVX2 Integer Multiply Shared Kernels ===
// Low-half vector multiply has the same bit pattern for signed and unsigned lanes.

procedure AVX2MulDwordVecRaw(const aPtr, bPtr, rPtr: Pointer);
var
  pa, pb, pr: Pointer;
begin
  pa := aPtr;
  pb := bPtr;
  pr := rPtr;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    vmovdqu xmm0, [rax]
    vpmulld xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

procedure AVX2MulDwordVecImpl(const a, b: TVecI32x4; out r: TVecI32x4); inline;
begin
  AVX2MulDwordVecRaw(@a, @b, @r);
end;

procedure AVX2MulDwordVecImpl(const a, b: TVecU32x4; out r: TVecU32x4); inline;
begin
  AVX2MulDwordVecRaw(@a, @b, @r);
end;

procedure AVX2MulWordVecRaw(const aPtr, bPtr, rPtr: Pointer);
var
  pa, pb, pr: Pointer;
begin
  pa := aPtr;
  pb := bPtr;
  pr := rPtr;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    vmovdqu xmm0, [rax]
    vpmullw xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

procedure AVX2MulWordVecImpl(const a, b: TVecI16x8; out r: TVecI16x8); inline;
begin
  AVX2MulWordVecRaw(@a, @b, @r);
end;

procedure AVX2MulWordVecImpl(const a, b: TVecU16x8; out r: TVecU16x8); inline;
begin
  AVX2MulWordVecRaw(@a, @b, @r);
end;

function AVX2MulI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  AVX2MulDwordVecImpl(a, b, Result);
end;

procedure AVX2AndVecRaw(const aPtr, bPtr, rPtr: Pointer);
var
  pa, pb, pr: Pointer;
begin
  pa := aPtr;
  pb := bPtr;
  pr := rPtr;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    vmovdqu xmm0, [rax]
    vpand   xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

procedure AVX2OrVecRaw(const aPtr, bPtr, rPtr: Pointer);
var
  pa, pb, pr: Pointer;
begin
  pa := aPtr;
  pb := bPtr;
  pr := rPtr;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    vmovdqu xmm0, [rax]
    vpor    xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

procedure AVX2XorVecRaw(const aPtr, bPtr, rPtr: Pointer);
var
  pa, pb, pr: Pointer;
begin
  pa := aPtr;
  pb := bPtr;
  pr := rPtr;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    vmovdqu xmm0, [rax]
    vpxor   xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

procedure AVX2NotVecRaw(const aPtr, rPtr: Pointer);
var
  pa, pr: Pointer;
begin
  pa := aPtr;
  pr := rPtr;
  asm
    mov      rax, pa
    mov      rcx, pr
    vmovdqu  xmm0, [rax]
    vpcmpeqd xmm1, xmm1, xmm1
    vpxor    xmm0, xmm0, xmm1
    vmovdqu  [rcx], xmm0
  end;
end;

procedure AVX2AndNotVecRaw(const aPtr, bPtr, rPtr: Pointer);
var
  pa, pb, pr: Pointer;
begin
  pa := aPtr;
  pb := bPtr;
  pr := rPtr;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    vmovdqu xmm0, [rax]
    vpandn  xmm0, xmm0, [rdx]
    vmovdqu [rcx], xmm0
  end;
end;

// Eq compare raw helpers shared by signed/unsigned wrappers of the same lane width.
function AVX2CmpEqDwordMaskRaw(const aPtr, bPtr: Pointer): Integer;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := aPtr;
  pb := bPtr;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovdqu  xmm0, [rax]
    vpcmpeqd xmm0, xmm0, [rdx]
    vmovmskps eax, xmm0
    mov      mask, eax
  end;
  Result := mask;
end;

function AVX2CmpEqWordMaskRaw(const aPtr, bPtr: Pointer): Integer;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := aPtr;
  pb := bPtr;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovdqu  xmm0, [rax]
    vpcmpeqw xmm0, xmm0, [rdx]
    vpmovmskb eax, xmm0
    mov      mask, eax
  end;
  Result := mask;
end;

function AVX2CmpEqByteMaskRaw(const aPtr, bPtr: Pointer): Integer;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := aPtr;
  pb := bPtr;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovdqu  xmm0, [rax]
    vpcmpeqb xmm0, xmm0, [rdx]
    vpmovmskb eax, xmm0
    mov      mask, eax
  end;
  Result := mask;
end;

function AVX2CmpEqQwordMaskRaw(const aPtr, bPtr: Pointer): Integer;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := aPtr;
  pb := bPtr;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovdqu  xmm0, [rax]
    vpcmpeqq xmm0, xmm0, [rdx]
    vmovmskpd eax, xmm0
    mov      mask, eax
  end;
  Result := mask;
end;

function AVX2CmpEqDwordMaskRaw256(const aPtr, bPtr: Pointer): Integer;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := aPtr;
  pb := bPtr;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovdqu  ymm0, [rax]
    vpcmpeqd ymm0, ymm0, [rdx]
    vmovmskps eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := mask;
end;

function AVX2CmpEqQwordMaskRaw256(const aPtr, bPtr: Pointer): Integer;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := aPtr;
  pb := bPtr;
  asm
    mov      rax, pa
    mov      rdx, pb
    vmovdqu  ymm0, [rax]
    vpcmpeqq ymm0, ymm0, [rdx]
    vmovmskpd eax, ymm0
    mov      mask, eax
    vzeroupper
  end;
  Result := mask;
end;

// === I32x4 Bitwise Operations (128-bit) ===

function AVX2AndI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  AVX2AndVecRaw(@a, @b, @Result);
end;

function AVX2OrI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  AVX2OrVecRaw(@a, @b, @Result);
end;

function AVX2XorI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  AVX2XorVecRaw(@a, @b, @Result);
end;

function AVX2NotI32x4(const a: TVecI32x4): TVecI32x4;
begin
  AVX2NotVecRaw(@a, @Result);
end;

function AVX2AndNotI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  AVX2AndNotVecRaw(@a, @b, @Result);
end;

// === I32x4 Shift Operations (128-bit) ===

function AVX2ShiftLeftI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
begin
  AVX2ShiftLeftDwordVecRaw(@a, @Result, count);
end;

function AVX2ShiftRightI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
begin
  AVX2ShiftRightDwordVecRaw(@a, @Result, count);
end;

function AVX2ShiftRightArithI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
var
  i: Integer;
begin
  if count < 0 then
  begin
    Result := a;
    Exit;
  end;
  if count >= 32 then
  begin
    // Arithmetic shift >= 32: result is all 0s or all 1s depending on sign
    for i := 0 to 3 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0;
    Exit;
  end;
  asm
    lea     rax, a
    vmovdqu xmm0, [rax]
    mov     ecx, count
    vmovd   xmm1, ecx
    vpsrad  xmm0, xmm0, xmm1   // Arithmetic right shift
    vmovdqu [result], xmm0
  end;
end;

// === I32x4 Comparison Operations (128-bit) ===

function AVX2CmpEqI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := TMask4(AVX2CmpEqDwordMaskRaw(@a, @b));
end;

function AVX2CmpLtI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := AVX2CmpGtI32x4(b, a);
end;

function AVX2CmpGtI32x4(const a, b: TVecI32x4): TMask4;
var mask: Integer;
begin
  asm
    lea       rax, a
    lea       rdx, b
    vmovdqu   xmm0, [rax]
    vpcmpgtd  xmm0, xmm0, [rdx]
    vmovmskps eax, xmm0
    mov       mask, eax
  end;
  Result := TMask4(mask);
end;

function AVX2CmpLeI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor AVX2CmpGtI32x4(a, b));
end;

function AVX2CmpGeI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor AVX2CmpGtI32x4(b, a));
end;

function AVX2CmpNeI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor AVX2CmpEqDwordMaskRaw(@a, @b));
end;

// === I32x4 Min/Max Operations (128-bit) ===

function AVX2MinI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpminsd xmm0, xmm0, [rdx]   // Signed min
    vmovdqu [result], xmm0
  end;
end;

function AVX2MaxI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpmaxsd xmm0, xmm0, [rdx]   // Signed max
    vmovdqu [result], xmm0
  end;
end;

// === I16x8 Arithmetic Operations (128-bit) ===

function AVX2AddI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  AVX2AddWordVecRaw(@a, @b, @Result);
end;

function AVX2SubI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  AVX2SubWordVecRaw(@a, @b, @Result);
end;

function AVX2MulI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  AVX2MulWordVecImpl(a, b, Result);
end;

// === I16x8 Bitwise Operations (128-bit) ===

function AVX2AndI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  AVX2AndVecRaw(@a, @b, @Result);
end;

function AVX2OrI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  AVX2OrVecRaw(@a, @b, @Result);
end;

function AVX2XorI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  AVX2XorVecRaw(@a, @b, @Result);
end;

function AVX2NotI16x8(const a: TVecI16x8): TVecI16x8;
begin
  AVX2NotVecRaw(@a, @Result);
end;

function AVX2AndNotI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  AVX2AndNotVecRaw(@a, @b, @Result);
end;

// === I16x8 Shift Operations (128-bit) ===

function AVX2ShiftLeftI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
begin
  AVX2ShiftLeftWordVecRaw(@a, @Result, count);
end;

function AVX2ShiftRightI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
begin
  AVX2ShiftRightWordVecRaw(@a, @Result, count);
end;

function AVX2ShiftRightArithI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
begin
  asm
    lea     rax, a
    vmovdqu xmm0, [rax]
    mov     eax, count
    vmovd   xmm1, eax
    vpsraw  xmm0, xmm0, xmm1   // Arithmetic right shift
    vmovdqu [result], xmm0
  end;
end;

// === I16x8 Comparison Operations (128-bit) ===

function AVX2CmpEqI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := TMask8(AVX2CmpEqWordMaskRaw(@a, @b));
end;

function AVX2CmpLtI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := AVX2CmpGtI16x8(b, a);
end;

function AVX2CmpGtI16x8(const a, b: TVecI16x8): TMask8;
var mask: Integer;
begin
  asm
    lea      rax, a
    lea      rdx, b
    vmovdqu  xmm0, [rax]
    vpcmpgtw xmm0, xmm0, [rdx]  // a > b
    vpmovmskb eax, xmm0
    mov      mask, eax
  end;
  Result := TMask8(mask);
end;

function AVX2CmpLeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpGtI16x8(a, b));
end;

function AVX2CmpGeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpGtI16x8(b, a));
end;

function AVX2CmpNeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpEqWordMaskRaw(@a, @b));
end;

// === I16x8 Min/Max Operations (128-bit) ===

function AVX2MinI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpminsw xmm0, xmm0, [rdx]   // Signed min
    vmovdqu [result], xmm0
  end;
end;

function AVX2MaxI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpmaxsw xmm0, xmm0, [rdx]   // Signed max
    vmovdqu [result], xmm0
  end;
end;

// === I8x16 Arithmetic Operations (128-bit) ===

function AVX2AddI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  AVX2AddByteVecRaw(@a, @b, @Result);
end;

function AVX2SubI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  AVX2SubByteVecRaw(@a, @b, @Result);
end;

// === I8x16 Bitwise Operations (128-bit) ===

function AVX2AndI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  AVX2AndVecRaw(@a, @b, @Result);
end;

function AVX2OrI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  AVX2OrVecRaw(@a, @b, @Result);
end;

function AVX2XorI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  AVX2XorVecRaw(@a, @b, @Result);
end;

function AVX2NotI8x16(const a: TVecI8x16): TVecI8x16;
begin
  AVX2NotVecRaw(@a, @Result);
end;

function AVX2AndNotI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  AVX2AndNotVecRaw(@a, @b, @Result);
end;

// === I8x16 Comparison Operations (128-bit) ===

function AVX2CmpEqI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := TMask16(AVX2CmpEqByteMaskRaw(@a, @b));
end;

function AVX2CmpLtI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := AVX2CmpGtI8x16(b, a);
end;

function AVX2CmpGtI8x16(const a, b: TVecI8x16): TMask16;
var mask: Integer;
begin
  asm
    lea      rax, a
    lea      rdx, b
    vmovdqu  xmm0, [rax]
    vpcmpgtb xmm0, xmm0, [rdx]  // a > b
    vpmovmskb eax, xmm0
    mov      mask, eax
  end;
  Result := TMask16(mask);
end;

function AVX2CmpLeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor AVX2CmpGtI8x16(a, b));
end;

function AVX2CmpGeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor AVX2CmpGtI8x16(b, a));
end;

function AVX2CmpNeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor AVX2CmpEqByteMaskRaw(@a, @b));
end;

// === I8x16 Min/Max Operations (128-bit) ===

function AVX2MinI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpminsb xmm0, xmm0, [rdx]   // Signed min (AVX2)
    vmovdqu [result], xmm0
  end;
end;

function AVX2MaxI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpmaxsb xmm0, xmm0, [rdx]   // Signed max (AVX2)
    vmovdqu [result], xmm0
  end;
end;

// === U32x4 Arithmetic Operations (128-bit) ===

function AVX2AddU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  AVX2AddDwordVecRaw(@a, @b, @Result);
end;

function AVX2SubU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  AVX2SubDwordVecRaw(@a, @b, @Result);
end;

function AVX2MulU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  AVX2MulDwordVecImpl(a, b, Result);
end;

// === U32x4 Bitwise Operations (128-bit) ===

function AVX2AndU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  AVX2AndVecRaw(@a, @b, @Result);
end;

function AVX2OrU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  AVX2OrVecRaw(@a, @b, @Result);
end;

function AVX2XorU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  AVX2XorVecRaw(@a, @b, @Result);
end;

function AVX2NotU32x4(const a: TVecU32x4): TVecU32x4;
begin
  AVX2NotVecRaw(@a, @Result);
end;

function AVX2AndNotU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  AVX2AndNotVecRaw(@a, @b, @Result);
end;

// === U32x4 Shift Operations (128-bit) ===

function AVX2ShiftLeftU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
begin
  AVX2ShiftLeftDwordVecRaw(@a, @Result, count);
end;

function AVX2ShiftRightU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
begin
  AVX2ShiftRightDwordVecRaw(@a, @Result, count);
end;

// === U32x4 Comparison Operations (128-bit) ===

function AVX2CmpEqU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := TMask4(AVX2CmpEqDwordMaskRaw(@a, @b));
end;

function AVX2CmpLtU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := AVX2CmpGtU32x4(b, a);
end;

function AVX2CmpGtU32x4(const a, b: TVecU32x4): TMask4;
var mask: Integer;
begin
  // Unsigned comparison: flip sign bit and use signed compare
  asm
    lea      rax, a
    lea      rdx, b
    mov      ecx, $80000000
    vmovd    xmm2, ecx
    vpshufd  xmm2, xmm2, 0      // Broadcast sign bit
    vmovdqu  xmm0, [rax]
    vpxor    xmm0, xmm0, xmm2   // Flip sign bit of a
    vmovdqu  xmm1, [rdx]
    vpxor    xmm1, xmm1, xmm2   // Flip sign bit of b
    vpcmpgtd xmm0, xmm0, xmm1   // Signed compare: a > b
    vmovmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function AVX2CmpLeU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor AVX2CmpGtU32x4(a, b));
end;

function AVX2CmpGeU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor AVX2CmpGtU32x4(b, a));
end;

// === U32x4 Min/Max Operations (128-bit) ===

function AVX2MinU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpminud xmm0, xmm0, [rdx]   // Unsigned min (AVX2)
    vmovdqu [result], xmm0
  end;
end;

function AVX2MaxU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpmaxud xmm0, xmm0, [rdx]   // Unsigned max (AVX2)
    vmovdqu [result], xmm0
  end;
end;

// === U16x8 Arithmetic Operations (128-bit) ===

function AVX2AddU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  AVX2AddWordVecRaw(@a, @b, @Result);
end;

function AVX2SubU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  AVX2SubWordVecRaw(@a, @b, @Result);
end;

function AVX2MulU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  AVX2MulWordVecImpl(a, b, Result);
end;

// === U16x8 Bitwise Operations (128-bit) ===

function AVX2AndU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  AVX2AndVecRaw(@a, @b, @Result);
end;

function AVX2OrU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  AVX2OrVecRaw(@a, @b, @Result);
end;

function AVX2XorU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  AVX2XorVecRaw(@a, @b, @Result);
end;

function AVX2NotU16x8(const a: TVecU16x8): TVecU16x8;
begin
  AVX2NotVecRaw(@a, @Result);
end;

function AVX2AndNotU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  AVX2AndNotVecRaw(@a, @b, @Result);
end;

// === U16x8 Shift Operations (128-bit) ===

function AVX2ShiftLeftU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
begin
  AVX2ShiftLeftWordVecRaw(@a, @Result, count);
end;

function AVX2ShiftRightU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
begin
  AVX2ShiftRightWordVecRaw(@a, @Result, count);
end;

// === U16x8 Comparison Operations (128-bit) ===

function AVX2CmpEqU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := TMask8(AVX2CmpEqWordMaskRaw(@a, @b));
end;

function AVX2CmpLtU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := AVX2CmpGtU16x8(b, a);
end;

function AVX2CmpGtU16x8(const a, b: TVecU16x8): TMask8;
var mask: Integer;
begin
  // Unsigned comparison: flip sign bit and use signed compare
  asm
    lea      rax, a
    lea      rdx, b
    mov      ecx, $8000
    vmovd    xmm2, ecx
    vpshuflw xmm2, xmm2, 0
    vpshufhw xmm2, xmm2, 0
    vmovdqu  xmm0, [rax]
    vpxor    xmm0, xmm0, xmm2
    vmovdqu  xmm1, [rdx]
    vpxor    xmm1, xmm1, xmm2
    vpcmpgtw xmm0, xmm0, xmm1   // a > b
    vpmovmskb eax, xmm0
    mov      mask, eax
  end;
  Result := TMask8(mask);
end;

function AVX2CmpLeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpGtU16x8(a, b));
end;

function AVX2CmpGeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpGtU16x8(b, a));
end;

function AVX2CmpNeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpEqWordMaskRaw(@a, @b));
end;

// === U16x8 Min/Max Operations (128-bit) ===

function AVX2MinU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpminuw xmm0, xmm0, [rdx]   // Unsigned min (SSE4.1)
    vmovdqu [result], xmm0
  end;
end;

function AVX2MaxU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpmaxuw xmm0, xmm0, [rdx]   // Unsigned max (SSE4.1)
    vmovdqu [result], xmm0
  end;
end;

// === U8x16 Arithmetic Operations (128-bit) ===

function AVX2AddU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  AVX2AddByteVecRaw(@a, @b, @Result);
end;

function AVX2SubU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  AVX2SubByteVecRaw(@a, @b, @Result);
end;

// === U8x16 Bitwise Operations (128-bit) ===

function AVX2AndU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  AVX2AndVecRaw(@a, @b, @Result);
end;

function AVX2OrU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  AVX2OrVecRaw(@a, @b, @Result);
end;

function AVX2XorU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  AVX2XorVecRaw(@a, @b, @Result);
end;

function AVX2NotU8x16(const a: TVecU8x16): TVecU8x16;
begin
  AVX2NotVecRaw(@a, @Result);
end;

function AVX2AndNotU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  AVX2AndNotVecRaw(@a, @b, @Result);
end;

// === U8x16 Comparison Operations (128-bit) ===

function AVX2CmpEqU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := TMask16(AVX2CmpEqByteMaskRaw(@a, @b));
end;

function AVX2CmpLtU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := AVX2CmpGtU8x16(b, a);
end;

function AVX2CmpGtU8x16(const a, b: TVecU8x16): TMask16;
var mask: Integer;
begin
  // Unsigned comparison: flip sign bit and use signed compare
  asm
    lea      rax, a
    lea      rdx, b
    mov      al, $80
    vmovd    xmm2, eax
    vpbroadcastb xmm2, xmm2
    vmovdqu  xmm0, [rax]
    vpxor    xmm0, xmm0, xmm2
    vmovdqu  xmm1, [rdx]
    vpxor    xmm1, xmm1, xmm2
    vpcmpgtb xmm0, xmm0, xmm1   // a > b
    vpmovmskb eax, xmm0
    mov      mask, eax
  end;
  Result := TMask16(mask);
end;

function AVX2CmpLeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor AVX2CmpGtU8x16(a, b));
end;

function AVX2CmpGeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor AVX2CmpGtU8x16(b, a));
end;

function AVX2CmpNeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor AVX2CmpEqByteMaskRaw(@a, @b));
end;

// === U8x16 Min/Max Operations (128-bit) ===

function AVX2MinU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpminub xmm0, xmm0, [rdx]   // Unsigned min (SSE2)
    vmovdqu [result], xmm0
  end;
end;

function AVX2MaxU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpmaxub xmm0, xmm0, [rdx]   // Unsigned max (SSE2)
    vmovdqu [result], xmm0
  end;
end;

// === AVX2 Comparison Operations ===

function AVX2CmpEqF32x4(const a, b: TVecF32x4): TMask4;
var mask: Integer;
begin
  asm
    lea      rax, a
    lea      rdx, b
    vmovups  xmm0, [rax]
    vcmpeqps xmm0, xmm0, [rdx]
    vmovmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function AVX2CmpLtF32x4(const a, b: TVecF32x4): TMask4;
var mask: Integer;
begin
  asm
    lea      rax, a
    lea      rdx, b
    vmovups  xmm0, [rax]
    vcmpltps xmm0, xmm0, [rdx]
    vmovmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function AVX2CmpLeF32x4(const a, b: TVecF32x4): TMask4;
var mask: Integer;
begin
  asm
    lea      rax, a
    lea      rdx, b
    vmovups  xmm0, [rax]
    vcmpleps xmm0, xmm0, [rdx]
    vmovmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function AVX2CmpGtF32x4(const a, b: TVecF32x4): TMask4;
var mask: Integer;
begin
  // GT: swap operands and use LT
  asm
    lea      rax, b
    lea      rdx, a
    vmovups  xmm0, [rax]
    vcmpltps xmm0, xmm0, [rdx]
    vmovmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function AVX2CmpGeF32x4(const a, b: TVecF32x4): TMask4;
var mask: Integer;
begin
  // GE: swap operands and use LE
  asm
    lea      rax, b
    lea      rdx, a
    vmovups  xmm0, [rax]
    vcmpleps xmm0, xmm0, [rdx]
    vmovmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function AVX2CmpNeF32x4(const a, b: TVecF32x4): TMask4;
var mask: Integer;
begin
  asm
    lea       rax, a
    lea       rdx, b
    vmovups   xmm0, [rax]
    vcmpneqps xmm0, xmm0, [rdx]
    vmovmskps eax, xmm0
    mov       mask, eax
  end;
  Result := TMask4(mask);
end;

// === AVX2 Math Functions ===

function AVX2AbsF32x4(const a: TVecF32x4): TVecF32x4;
begin
  asm
    lea      rax, a
    vmovups  xmm0, [rax]
    vpcmpeqd xmm1, xmm1, xmm1     // all 1s
    vpsrld   xmm1, xmm1, 1        // shift right to get 0x7FFFFFFF
    vandps   xmm0, xmm0, xmm1
    vmovups  [result], xmm0
  end;
end;

function AVX2SqrtF32x4(const a: TVecF32x4): TVecF32x4;
begin
  asm
    lea     rax, a
    vmovups xmm0, [rax]
    vsqrtps xmm0, xmm0
    vmovups [result], xmm0
  end;
end;

function AVX2MinF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovups xmm0, [rax]
    vminps  xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

function AVX2MaxF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovups xmm0, [rax]
    vmaxps  xmm0, xmm0, [rdx]
    vmovups [result], xmm0
  end;
end;

// === AVX2 Reduction Operations ===

function AVX2ReduceAddF32x4(const a: TVecF32x4): Single;
begin
  asm
    lea      rax, a
    vmovups  xmm0, [rax]
    vhaddps  xmm0, xmm0, xmm0     // horizontal add
    vhaddps  xmm0, xmm0, xmm0
    vmovss   [result], xmm0
  end;
end;

function AVX2ReduceMinF32x4(const a: TVecF32x4): Single;
begin
  // 语义对齐：与 ScalarReduceMinF32x4 相同的顺序 fold。
  // 说明：vmin* 在 NaN/相等值/±0 上是“选择第二操作数”的语义，
  // 这会让 reduction 的结果依赖于归约顺序；因此这里按 a0->a1->a2->a3 顺序归约。
  asm
    lea      rax, a
    vmovups  xmm2, [rax]

    // acc := a0
    vmovaps  xmm0, xmm2

    // acc := min(acc, a1)
    vshufps  xmm1, xmm2, xmm2, $55
    vminss   xmm0, xmm0, xmm1

    // acc := min(acc, a2)
    vshufps  xmm1, xmm2, xmm2, $AA
    vminss   xmm0, xmm0, xmm1

    // acc := min(acc, a3)
    vshufps  xmm1, xmm2, xmm2, $FF
    vminss   xmm0, xmm0, xmm1

    vmovss   [result], xmm0
    vzeroupper
  end;
end;

function AVX2ReduceMaxF32x4(const a: TVecF32x4): Single;
begin
  // 语义对齐：与 ScalarReduceMaxF32x4 相同的顺序 fold。
  // 说明：vmax* 在 NaN/相等值/±0 上是“选择第二操作数”的语义，
  // 这会让 reduction 的结果依赖于归约顺序；因此这里按 a0->a1->a2->a3 顺序归约。
  asm
    lea      rax, a
    vmovups  xmm2, [rax]

    // acc := a0
    vmovaps  xmm0, xmm2

    // acc := max(acc, a1)
    vshufps  xmm1, xmm2, xmm2, $55
    vmaxss   xmm0, xmm0, xmm1

    // acc := max(acc, a2)
    vshufps  xmm1, xmm2, xmm2, $AA
    vmaxss   xmm0, xmm0, xmm1

    // acc := max(acc, a3)
    vshufps  xmm1, xmm2, xmm2, $FF
    vmaxss   xmm0, xmm0, xmm1

    vmovss   [result], xmm0
    vzeroupper
  end;
end;

function AVX2ReduceMulF32x4(const a: TVecF32x4): Single;
begin
  asm
    lea      rax, a
    vmovups  xmm0, [rax]
    vshufps  xmm1, xmm0, xmm0, $4E
    vmulps   xmm0, xmm0, xmm1
    vshufps  xmm1, xmm0, xmm0, $B1
    vmulss   xmm0, xmm0, xmm1
    vmovss   [result], xmm0
  end;
end;

// === AVX2 Memory Operations ===

function AVX2LoadF32x4(p: PSingle): TVecF32x4;
begin
  // Safety check: Assert for nil pointer
  Assert(p <> nil, 'AVX2LoadF32x4: pointer is nil');
  asm
    mov     rax, p
    vmovups xmm0, [rax]
    vmovups [result], xmm0
  end;
end;

function AVX2LoadF32x4Aligned(p: PSingle): TVecF32x4;
begin
  // Safety check: Assert for nil pointer and 16-byte alignment
  Assert(p <> nil, 'AVX2LoadF32x4Aligned: pointer is nil');
  {$PUSH}{$WARN 4055 OFF}
  Assert((PtrUInt(p) and $F) = 0, 'AVX2LoadF32x4Aligned: Pointer must be 16-byte aligned');
  {$POP}
  asm
    mov     rax, p
    vmovaps xmm0, [rax]
    vmovups [result], xmm0
  end;
end;

procedure AVX2StoreF32x4(p: PSingle; const a: TVecF32x4);
begin
  // Safety check: Assert for nil pointer
  Assert(p <> nil, 'AVX2StoreF32x4: pointer is nil');
  asm
    mov     rax, p
    lea     rdx, a
    vmovups xmm0, [rdx]
    vmovups [rax], xmm0
  end;
end;

procedure AVX2StoreF32x4Aligned(p: PSingle; const a: TVecF32x4);
begin
  // Safety check: Assert for nil pointer and 16-byte alignment
  Assert(p <> nil, 'AVX2StoreF32x4Aligned: pointer is nil');
  {$PUSH}{$WARN 4055 OFF}
  Assert((PtrUInt(p) and $F) = 0, 'AVX2StoreF32x4Aligned: Pointer must be 16-byte aligned');
  {$POP}
  asm
    mov     rax, p
    lea     rdx, a
    vmovups xmm0, [rdx]
    vmovaps [rax], xmm0
  end;
end;

// === AVX2 Utility Operations ===

function AVX2SplatF32x4(value: Single): TVecF32x4;
begin
  asm
    movss       xmm0, value
    vbroadcastss xmm0, xmm0
    vmovups     [result], xmm0
  end;
end;

function AVX2ZeroF32x4: TVecF32x4;
begin
  asm
    vxorps  xmm0, xmm0, xmm0
    vmovups [result], xmm0
  end;
end;

function AVX2SelectF32x4(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
begin
  Result := ScalarSelectF32x4(mask, a, b);
end;

function AVX2ExtractF32x4(const a: TVecF32x4; index: Integer): Single;
begin
  Result := ScalarExtractF32x4(a, index);
end;

function AVX2InsertF32x4(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;
begin
  Result := ScalarInsertF32x4(a, value, index);
end;

{$I nextpas.core.simd.avx2.f32x8_arith.inc}

{$I nextpas.core.simd.avx2.f32x8_compare.inc}

{$I nextpas.core.simd.avx2.f64x4_compare.inc}

{$I nextpas.core.simd.avx2.f32x8_math.inc}

{$I nextpas.core.simd.avx2.f32x8_reduce.inc}

{$I nextpas.core.simd.avx2.f32x8_ext_math.inc}

{$I nextpas.core.simd.avx2.f32x8_loadstore.inc}

{$I nextpas.core.simd.avx2.f64x4_arith.inc}

{$I nextpas.core.simd.avx2.f64x4_math.inc}

{$I nextpas.core.simd.avx2.f64x4_reduce.inc}

{$I nextpas.core.simd.avx2.f64x4_ext_math.inc}

{$I nextpas.core.simd.avx2.f64x4_loadstore.inc}

{$I nextpas.core.simd.avx2.i32x8_family.inc}

{$I nextpas.core.simd.avx2.facade.inc}

// === Saturating Arithmetic (AVX2 VEX-encoded) ===
// 使用 VEX 编码避免 SSE-AVX 转换惩罚

// I8x16 有符号饱和加法 (VPADDSB)
function AVX2I8x16SatAdd(const a, b: TVecI8x16): TVecI8x16;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovdqu xmm0, [rax]
    vpaddsb xmm0, xmm0, [rdx]
    vmovdqu [result], xmm0
  end;
end;

// I8x16 有符号饱和减法 (VPSUBSB)
function AVX2I8x16SatSub(const a, b: TVecI8x16): TVecI8x16;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovdqu xmm0, [rax]
    vpsubsb xmm0, xmm0, [rdx]
    vmovdqu [result], xmm0
  end;
end;

// I16x8 有符号饱和加法 (VPADDSW)
function AVX2I16x8SatAdd(const a, b: TVecI16x8): TVecI16x8;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovdqu xmm0, [rax]
    vpaddsw xmm0, xmm0, [rdx]
    vmovdqu [result], xmm0
  end;
end;

// I16x8 有符号饱和减法 (VPSUBSW)
function AVX2I16x8SatSub(const a, b: TVecI16x8): TVecI16x8;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovdqu xmm0, [rax]
    vpsubsw xmm0, xmm0, [rdx]
    vmovdqu [result], xmm0
  end;
end;

// U8x16 无符号饱和加法 (VPADDUSB)
function AVX2U8x16SatAdd(const a, b: TVecU8x16): TVecU8x16;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovdqu xmm0, [rax]
    vpaddusb xmm0, xmm0, [rdx]
    vmovdqu [result], xmm0
  end;
end;

// U8x16 无符号饱和减法 (VPSUBUSB)
function AVX2U8x16SatSub(const a, b: TVecU8x16): TVecU8x16;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovdqu xmm0, [rax]
    vpsubusb xmm0, xmm0, [rdx]
    vmovdqu [result], xmm0
  end;
end;

// U16x8 无符号饱和加法 (VPADDUSW)
function AVX2U16x8SatAdd(const a, b: TVecU16x8): TVecU16x8;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovdqu xmm0, [rax]
    vpaddusw xmm0, xmm0, [rdx]
    vmovdqu [result], xmm0
  end;
end;

// U16x8 无符号饱和减法 (VPSUBUSW)
function AVX2U16x8SatSub(const a, b: TVecU16x8): TVecU16x8;
begin
  asm
    lea    rax, a
    lea    rdx, b
    vmovdqu xmm0, [rax]
    vpsubusw xmm0, xmm0, [rdx]
    vmovdqu [result], xmm0
  end;
end;

// === I64x2 Arithmetic and Bitwise Operations (AVX2 VEX-encoded) ===
// 使用 VEX 编码避免 SSE-AVX 转换惩罚

// I64x2 加法 (VPADDQ)
function AVX2AddI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpaddq  xmm0, xmm0, [rdx]
    vmovdqu [result], xmm0
  end;
end;

// I64x2 减法 (VPSUBQ)
function AVX2SubI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  asm
    lea     rax, a
    lea     rdx, b
    vmovdqu xmm0, [rax]
    vpsubq  xmm0, xmm0, [rdx]
    vmovdqu [result], xmm0
  end;
end;

// I64x2 位与 (VPAND)
function AVX2AndI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  AVX2AndVecRaw(@a, @b, @Result);
end;

// I64x2 位或 (VPOR)
function AVX2OrI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  AVX2OrVecRaw(@a, @b, @Result);
end;

// I64x2 位异或 (VPXOR)
function AVX2XorI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  AVX2XorVecRaw(@a, @b, @Result);
end;

// I64x2 位非 (VPXOR with all 1s)
function AVX2NotI64x2(const a: TVecI64x2): TVecI64x2;
begin
  AVX2NotVecRaw(@a, @Result);
end;

// I64x2 相等比较 (VPCMPEQQ - requires AVX2)
function AVX2CmpEqI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := TMask2(AVX2CmpEqQwordMaskRaw(@a, @b));
end;

// I64x2 大于比较 (VPCMPGTQ - requires AVX2)
function AVX2CmpGtI64x2(const a, b: TVecI64x2): TMask2;
var maskVal: Integer;
begin
  asm
    lea rax, a
    lea rdx, b
    vmovdqu  xmm0, [rax]
    vmovdqu  xmm1, [rdx]
    vpcmpgtq xmm0, xmm0, xmm1
    vmovmskpd eax, xmm0
    mov      maskVal, eax
  end;
  Result := TMask2(maskVal);
end;

// I64x2 小于比较 (a < b = b > a)
function AVX2CmpLtI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := AVX2CmpGtI64x2(b, a);
end;

// I64x2 小于等于 (a <= b = NOT(a > b))
function AVX2CmpLeI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := TMask2(MASK2_ALL_SET xor AVX2CmpGtI64x2(a, b));
end;

// I64x2 大于等于 (a >= b = NOT(a < b) = NOT(b > a))
function AVX2CmpGeI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := TMask2(MASK2_ALL_SET xor AVX2CmpGtI64x2(b, a));
end;

// I64x2 不等比较 (a != b = NOT(a == b))
function AVX2CmpNeI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := TMask2(MASK2_ALL_SET xor AVX2CmpEqQwordMaskRaw(@a, @b));
end;

// I64x2 按位与非 (~a & b)
function AVX2AndNotI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  AVX2AndNotVecRaw(@a, @b, @Result);
end;

// I64x2 逻辑左移 (逐 lane)
function AVX2ShiftLeftI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  Result.i[0] := a.i[0] shl count;
  Result.i[1] := a.i[1] shl count;
end;

// I64x2 逻辑右移 (逐 lane)
function AVX2ShiftRightI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  Result.i[0] := Int64(UInt64(a.i[0]) shr count);
  Result.i[1] := Int64(UInt64(a.i[1]) shr count);
end;

// I64x2 算术右移 (逐 lane)
function AVX2ShiftRightArithI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  Result.i[0] := a.i[0] shr count;
  Result.i[1] := a.i[1] shr count;
end;

procedure AVX2SelectI64x2ByMaskRaw(const aPtr, bPtr: Pointer; const mask: TMask2; resultPtr: Pointer); inline;
var
  pa, pb, pr: PInt64;
begin
  pa := aPtr;
  pb := bPtr;
  pr := resultPtr;
  if (mask and 1) <> 0 then pr[0] := pa[0] else pr[0] := pb[0];
  if (mask and 2) <> 0 then pr[1] := pa[1] else pr[1] := pb[1];
end;

function AVX2MinI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  AVX2SelectI64x2ByMaskRaw(@a, @b, AVX2CmpLtI64x2(a, b), @Result);
end;

function AVX2MaxI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  AVX2SelectI64x2ByMaskRaw(@a, @b, AVX2CmpGtI64x2(a, b), @Result);
end;

function AVX2AddU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result.u[0] := a.u[0] + b.u[0];
  Result.u[1] := a.u[1] + b.u[1];
end;

function AVX2SubU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result.u[0] := a.u[0] - b.u[0];
  Result.u[1] := a.u[1] - b.u[1];
end;

function AVX2AndU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  AVX2AndVecRaw(@a, @b, @Result);
end;

function AVX2OrU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  AVX2OrVecRaw(@a, @b, @Result);
end;

function AVX2XorU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  AVX2XorVecRaw(@a, @b, @Result);
end;

function AVX2NotU64x2(const a: TVecU64x2): TVecU64x2;
begin
  AVX2NotVecRaw(@a, @Result);
end;

function AVX2AndNotU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  AVX2AndNotVecRaw(@a, @b, @Result);
end;

function AVX2CmpEqU64x2(const a, b: TVecU64x2): TMask2;
begin
  Result := TMask2(AVX2CmpEqQwordMaskRaw(@a, @b));
end;

function AVX2CmpLtU64x2(const a, b: TVecU64x2): TMask2;
begin
  Result := AVX2CmpGtU64x2(b, a);
end;

function AVX2CmpGtU64x2(const a, b: TVecU64x2): TMask2;
const
  SIGN_MASK: QWord = QWord($8000000000000000);
var
  LAdjustedA, LAdjustedB: TVecI64x2;
begin
  LAdjustedA.i[0] := Int64(a.u[0] xor SIGN_MASK);
  LAdjustedA.i[1] := Int64(a.u[1] xor SIGN_MASK);
  LAdjustedB.i[0] := Int64(b.u[0] xor SIGN_MASK);
  LAdjustedB.i[1] := Int64(b.u[1] xor SIGN_MASK);
  Result := AVX2CmpGtI64x2(LAdjustedA, LAdjustedB);
end;

function AVX2MinU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  AVX2SelectI64x2ByMaskRaw(@a, @b, AVX2CmpLtU64x2(a, b), @Result);
end;

function AVX2MaxU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  AVX2SelectI64x2ByMaskRaw(@a, @b, AVX2CmpGtU64x2(a, b), @Result);
end;

// === I64x4 Operations (native 256-bit AVX2) ===
// 4×Int64 向量操作，使用原生 AVX2 256-bit 指令

// I64x4 加法 (VPADDQ ymm)
function AVX2AddI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  AVX2AddQwordVecRaw256(@a, @b, @Result);
end;

// I64x4 减法 (VPSUBQ ymm)
function AVX2SubI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  AVX2SubQwordVecRaw256(@a, @b, @Result);
end;

// I64x4 位与 (VPAND ymm)
function AVX2AndI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  AVX2AndQwordVecRaw256(@a, @b, @Result);
end;

// I64x4 位或 (VPOR ymm)
function AVX2OrI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  AVX2OrQwordVecRaw256(@a, @b, @Result);
end;

// I64x4 位异或 (VPXOR ymm)
function AVX2XorI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  AVX2XorQwordVecRaw256(@a, @b, @Result);
end;

// I64x4 位非 (VPXOR with all 1s)
function AVX2NotI64x4(const a: TVecI64x4): TVecI64x4;
begin
  AVX2NotQwordVecRaw256(@a, @Result);
end;

// I64x4 位与非 (VPANDN ymm) - (NOT a) AND b
function AVX2AndNotI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  AVX2AndNotQwordVecRaw256(@a, @b, @Result);
end;

// I64x4 Shift Operations

// I64x4 逻辑左移 (VPSLLQ ymm)
function AVX2ShiftLeftI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  AVX2ShiftLeftQwordVecRaw256(@a, @Result, count);
end;

// I64x4 逻辑右移 (VPSRLQ ymm)
function AVX2ShiftRightI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  AVX2ShiftRightQwordVecRaw256(@a, @Result, count);
end;

// I64x4 Comparison Operations

// I64x4 相等比较 (VPCMPEQQ ymm)
function AVX2CmpEqI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := TMask4(AVX2CmpEqQwordMaskRaw256(@a, @b));
end;

// I64x4 大于比较 (VPCMPGTQ ymm)
function AVX2CmpGtI64x4(const a, b: TVecI64x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;

  asm
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu ymm0, [rdx]
    vpcmpgtq ymm0, ymm0, [rcx]
    vmovmskpd eax, ymm0
    mov     mask, eax
    vzeroupper
  end;

  Result := TMask4(mask);
end;

// I64x4 小于比较 (a < b = b > a)
function AVX2CmpLtI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := AVX2CmpGtI64x4(b, a);
end;

// I64x4 小于等于 (a <= b = NOT(a > b))
function AVX2CmpLeI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor AVX2CmpGtI64x4(a, b));
end;

// I64x4 大于等于 (a >= b = NOT(a < b) = NOT(b > a))
function AVX2CmpGeI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor AVX2CmpGtI64x4(b, a));
end;

// I64x4 不等比较 (a != b = NOT(a == b))
function AVX2CmpNeI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor AVX2CmpEqQwordMaskRaw256(@a, @b));
end;

// I64x4 Utility Operations

// I64x4 加载 (从内存加载 4×Int64)
function AVX2LoadI64x4(p: PInt64): TVecI64x4;
var
  pr: Pointer;
begin
  pr := @Result;

  asm
    mov     rax, pr
    mov     rdx, p
    vmovdqu ymm0, [rdx]
    vmovdqu [rax], ymm0
    vzeroupper
  end;
end;

// I64x4 存储 (存储 4×Int64 到内存)
procedure AVX2StoreI64x4(p: PInt64; const a: TVecI64x4);
var
  pa: Pointer;
begin
  pa := @a;

  asm
    mov     rax, p
    mov     rdx, pa
    vmovdqu ymm0, [rdx]
    vmovdqu [rax], ymm0
    vzeroupper
  end;
end;

// I64x4 广播 (将单个值广播到所有通道)
function AVX2SplatI64x4(value: Int64): TVecI64x4;
var
  pr: Pointer;
  LValuePtr: PInt64;
begin
  pr := @Result;
  LValuePtr := @value;

  asm
    mov     rax, pr
    mov     rdx, LValuePtr
    vpbroadcastq ymm0, [rdx]
    vmovdqu [rax], ymm0
    vzeroupper
  end;
end;

// I64x4 零向量
function AVX2ZeroI64x4: TVecI64x4;
var
  pr: Pointer;
begin
  pr := @Result;

  asm
    mov     rax, pr
    vpxor   ymm0, ymm0, ymm0
    vmovdqu [rax], ymm0
    vzeroupper
  end;
end;

// === U32x8 Operations (native 256-bit AVX2) ===
// 8×UInt32 向量操作，使用原生 AVX2 256-bit 指令

// U32x8 加法 (VPADDD ymm) - 与有符号相同
function AVX2AddU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  AVX2AddDwordVecRaw256(@a, @b, @Result);
end;

// U32x8 减法 (VPSUBD ymm) - 与有符号相同
function AVX2SubU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  AVX2SubDwordVecRaw256(@a, @b, @Result);
end;

// U32x8 乘法 (低32位) (VPMULLD ymm)
function AVX2MulU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  AVX2MulDwordVecRaw256(@a, @b, @Result);
end;

// U32x8 位与 (VPAND ymm)
function AVX2AndU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  AVX2AndDwordVecRaw256(@a, @b, @Result);
end;

// U32x8 位或 (VPOR ymm)
function AVX2OrU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  AVX2OrDwordVecRaw256(@a, @b, @Result);
end;

// U32x8 位异或 (VPXOR ymm)
function AVX2XorU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  AVX2XorDwordVecRaw256(@a, @b, @Result);
end;

// U32x8 位非 (VPXOR with all 1s)
function AVX2NotU32x8(const a: TVecU32x8): TVecU32x8;
begin
  AVX2NotDwordVecRaw256(@a, @Result);
end;

// U32x8 位与非 (VPANDN ymm) - (NOT a) AND b
function AVX2AndNotU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  AVX2AndNotDwordVecRaw256(@a, @b, @Result);
end;

// U32x8 逻辑左移 (VPSLLD ymm)
function AVX2ShiftLeftU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
begin
  AVX2ShiftLeftDwordVecRaw256(@a, @Result, count);
end;

// U32x8 逻辑右移 (VPSRLD ymm)
function AVX2ShiftRightU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
begin
  AVX2ShiftRightDwordVecRaw256(@a, @Result, count);
end;

// U32x8 无符号比较操作
// 无符号比较使用符号位翻转技巧: 将 $80000000 XOR 到两个操作数，然后使用有符号比较

// U32x8 相等比较 (无符号与有符号相同)
function AVX2CmpEqU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := TMask8(AVX2CmpEqDwordMaskRaw256(@a, @b));
end;

// U32x8 大于比较 (使用符号位翻转技巧)
function AVX2CmpGtU32x8(const a, b: TVecU32x8): TMask8;
var
  pa, pb: Pointer;
  mask: Integer;
const
  SIGN_BIT: UInt32 = $80000000;
begin
  pa := @a;
  pb := @b;

  // 无符号比较: XOR $80000000 转换为有符号比较
  asm
    mov     rdx, pa
    mov     rcx, pb
    // 创建符号位掩码
    mov     eax, $80000000
    vmovd   xmm2, eax
    vpbroadcastd ymm2, xmm2     // ymm2 = [$80000000, $80000000, ...]
    // 加载并翻转符号位
    vmovdqu ymm0, [rdx]
    vpxor   ymm0, ymm0, ymm2    // a XOR $80000000
    vmovdqu ymm1, [rcx]
    vpxor   ymm1, ymm1, ymm2    // b XOR $80000000
    // 有符号比较
    vpcmpgtd ymm0, ymm0, ymm1
    vmovmskps eax, ymm0
    mov     mask, eax
    vzeroupper
  end;

  Result := TMask8(mask);
end;

// U32x8 小于比较 (a < b = b > a，使用符号位翻转)
function AVX2CmpLtU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := AVX2CmpGtU32x8(b, a);
end;

// U32x8 小于等于 (a <= b = NOT(a > b))
function AVX2CmpLeU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpGtU32x8(a, b));
end;

// U32x8 大于等于 (a >= b = NOT(a < b))
function AVX2CmpGeU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpGtU32x8(b, a));
end;

// U32x8 不等比较 (无符号与有符号相同)
function AVX2CmpNeU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor AVX2CmpEqDwordMaskRaw256(@a, @b));
end;

// U32x8 无符号最小值 (VPMINUD ymm)
function AVX2MinU32x8(const a, b: TVecU32x8): TVecU32x8;
var
  pa, pb, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  pb := @b;

  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu ymm0, [rdx]
    vpminud ymm0, ymm0, [rcx]   // Unsigned min
    vmovdqu [rax], ymm0
    vzeroupper
  end;
end;

// U32x8 无符号最大值 (VPMAXUD ymm)
function AVX2MaxU32x8(const a, b: TVecU32x8): TVecU32x8;
var
  pa, pb, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  pb := @b;

  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    vmovdqu ymm0, [rdx]
    vpmaxud ymm0, ymm0, [rcx]   // Unsigned max
    vmovdqu [rax], ymm0
    vzeroupper
  end;
end;

// === U64x4 Operations (native 256-bit AVX2) ===
// 4×UInt64 向量操作，使用原生 AVX2 256-bit 指令

// U64x4 加法 (VPADDQ ymm) - 与有符号相同
function AVX2AddU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  AVX2AddQwordVecRaw256(@a, @b, @Result);
end;

// U64x4 减法 (VPSUBQ ymm) - 与有符号相同
function AVX2SubU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  AVX2SubQwordVecRaw256(@a, @b, @Result);
end;

// U64x4 位与 (VPAND ymm)
function AVX2AndU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  AVX2AndQwordVecRaw256(@a, @b, @Result);
end;

// U64x4 位或 (VPOR ymm)
function AVX2OrU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  AVX2OrQwordVecRaw256(@a, @b, @Result);
end;

// U64x4 位异或 (VPXOR ymm)
function AVX2XorU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  AVX2XorQwordVecRaw256(@a, @b, @Result);
end;

// U64x4 位非 (VPXOR with all 1s)
function AVX2NotU64x4(const a: TVecU64x4): TVecU64x4;
begin
  AVX2NotQwordVecRaw256(@a, @Result);
end;

// U64x4 逻辑左移 (VPSLLQ ymm)
function AVX2ShiftLeftU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
begin
  AVX2ShiftLeftQwordVecRaw256(@a, @Result, count);
end;

// U64x4 逻辑右移 (VPSRLQ ymm)
function AVX2ShiftRightU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
begin
  AVX2ShiftRightQwordVecRaw256(@a, @Result, count);
end;

// U64x4 无符号比较操作
// 无符号 64-bit 比较使用 $8000000000000000 XOR 技巧

// U64x4 相等比较 (无符号与有符号相同)
function AVX2CmpEqU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := TMask4(AVX2CmpEqQwordMaskRaw256(@a, @b));
end;

// U64x4 大于比较 (使用符号位翻转技巧)
function AVX2CmpGtU64x4(const a, b: TVecU64x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;

  // 无符号比较: XOR $8000000000000000 转换为有符号比较
  asm
    mov     rdx, pa
    mov     rcx, pb
    // 创建符号位掩码 (64-bit)
    mov     rax, $8000000000000000
    vmovq   xmm2, rax
    vpbroadcastq ymm2, xmm2     // ymm2 = [$8000..., $8000..., ...]
    // 加载并翻转符号位
    vmovdqu ymm0, [rdx]
    vpxor   ymm0, ymm0, ymm2    // a XOR $8000...
    vmovdqu ymm1, [rcx]
    vpxor   ymm1, ymm1, ymm2    // b XOR $8000...
    // 有符号比较
    vpcmpgtq ymm0, ymm0, ymm1
    vmovmskpd eax, ymm0
    mov     mask, eax
    vzeroupper
  end;

  Result := TMask4(mask);
end;

// U64x4 小于比较 (a < b = b > a)
function AVX2CmpLtU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := AVX2CmpGtU64x4(b, a);
end;

// U64x4 小于等于 (a <= b = NOT(a > b))
function AVX2CmpLeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor AVX2CmpGtU64x4(a, b));
end;

// U64x4 大于等于 (a >= b = NOT(a < b))
function AVX2CmpGeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor AVX2CmpGtU64x4(b, a));
end;

// U64x4 不等比较 (无符号与有符号相同)
function AVX2CmpNeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor AVX2CmpEqQwordMaskRaw256(@a, @b));
end;

// === F64x4 扩展数学函数 ===

// F64x4 钳位操作 (已存在于 AVX2ClampF64x4，此处添加 RcpF64x4)

// F64x4 倒数近似 (1/x)
// 注意: 没有原生 vrcppd 指令，使用 vdivpd 实现精确倒数
function AVX2RcpF64x4(const a: TVecF64x4): TVecF64x4;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  asm
    mov     rax, pr
    mov     rdx, pa
    // 创建全1.0的向量
    mov     rcx, $3FF0000000000000    // 1.0 in IEEE 754 double
    vmovq   xmm1, rcx
    vpbroadcastq ymm1, xmm1           // ymm1 = [1.0, 1.0, 1.0, 1.0]
    vmovupd ymm0, [rdx]
    vdivpd  ymm0, ymm1, ymm0          // 1.0 / a
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

// === Mask Operations SIMD Implementation (AVX2) ===
// AVX2 CPU 都支持 popcnt 指令（SSE4.2），可以使用原生指令
// 使用 bsf (bit scan forward) 和 popcnt 指令

// --- TMask2 Operations (2 bits) ---
function AVX2Mask2All(mask: TMask2): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 3
  cmp   edi, 3
  sete  al
  {$ELSE}
  and   ecx, 3
  cmp   ecx, 3
  sete  al
  {$ENDIF}
end;

function AVX2Mask2Any(mask: TMask2): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 3
  setne al
  {$ELSE}
  test  ecx, 3
  setne al
  {$ENDIF}
end;

function AVX2Mask2None(mask: TMask2): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 3
  sete  al
  {$ELSE}
  test  ecx, 3
  sete  al
  {$ENDIF}
end;

function AVX2Mask2PopCount(mask: TMask2): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 3
  popcnt eax, edi    // 原生 popcnt 指令
  {$ELSE}
  and   ecx, 3
  popcnt eax, ecx
  {$ENDIF}
end;


// --- TMask4 Operations (4 bits) ---
function AVX2Mask4All(mask: TMask4): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 15
  cmp   edi, 15
  sete  al
  {$ELSE}
  and   ecx, 15
  cmp   ecx, 15
  sete  al
  {$ENDIF}
end;

function AVX2Mask4Any(mask: TMask4): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 15
  setne al
  {$ELSE}
  test  ecx, 15
  setne al
  {$ENDIF}
end;

function AVX2Mask4None(mask: TMask4): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 15
  sete  al
  {$ELSE}
  test  ecx, 15
  sete  al
  {$ENDIF}
end;

function AVX2Mask4PopCount(mask: TMask4): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 15
  popcnt eax, edi
  {$ELSE}
  and   ecx, 15
  popcnt eax, ecx
  {$ENDIF}
end;


// --- TMask8 Operations (8 bits) ---
function AVX2Mask8All(mask: TMask8): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  cmp   dil, $FF
  sete  al
  {$ELSE}
  cmp   cl, $FF
  sete  al
  {$ENDIF}
end;

function AVX2Mask8Any(mask: TMask8): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  dil, dil
  setne al
  {$ELSE}
  test  cl, cl
  setne al
  {$ENDIF}
end;

function AVX2Mask8None(mask: TMask8): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  dil, dil
  sete  al
  {$ELSE}
  test  cl, cl
  sete  al
  {$ENDIF}
end;

function AVX2Mask8PopCount(mask: TMask8): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movzx edi, dil
  popcnt eax, edi
  {$ELSE}
  movzx ecx, cl
  popcnt eax, ecx
  {$ENDIF}
end;


// --- TMask16 Operations (16 bits) ---
function AVX2Mask16All(mask: TMask16): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  cmp   di, $FFFF
  sete  al
  {$ELSE}
  cmp   cx, $FFFF
  sete  al
  {$ENDIF}
end;

function AVX2Mask16Any(mask: TMask16): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  di, di
  setne al
  {$ELSE}
  test  cx, cx
  setne al
  {$ENDIF}
end;

function AVX2Mask16None(mask: TMask16): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  di, di
  sete  al
  {$ELSE}
  test  cx, cx
  sete  al
  {$ENDIF}
end;

function AVX2Mask16PopCount(mask: TMask16): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movzx edi, di
  popcnt eax, edi
  {$ELSE}
  movzx ecx, cx
  popcnt eax, ecx
  {$ENDIF}
end;


// === SelectF64x2 Compatibility Wrapper ===
// 这里仍保留 AVX2 owned slot，但语义直接委托 scalar reference helper。
function AVX2SelectF64x2(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;
begin
  Result := ScalarSelectF64x2(mask, a, b);
end;

// SelectI32x4: 使用 VPAND + VPANDN + VPOR 实现 (AVX)
// Result = (a AND mask) OR (b AND NOT mask)
function AVX2SelectI32x4(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4;
begin
  asm
    lea rax, mask
    lea rdx, a
    lea rcx, b

    vmovdqu xmm2, [rax]      // xmm2 = mask
    vmovdqu xmm0, [rdx]      // xmm0 = a
    vmovdqu xmm1, [rcx]      // xmm1 = b

    // Result = (a AND mask) OR (b AND NOT mask)
    vpand   xmm0, xmm0, xmm2 // xmm0 = a AND mask
    vpandn  xmm2, xmm2, xmm1 // xmm2 = (NOT mask) AND b
    vpor    xmm0, xmm0, xmm2 // xmm0 = combine

    vmovdqu [result], xmm0
    // 不需要 vzeroupper (只使用 XMM 寄存器)
  end;
end;

// SelectF32x8: bitwise blend = (a AND mask) OR (b AND NOT mask)
function AVX2SelectF32x8(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;
var
  pMask, pA, pB, pR: Pointer;
begin
  pMask := @mask;
  pA := @a;
  pB := @b;
  pR := @Result;
  asm
    mov rax, pMask
    mov rdx, pA
    mov rcx, pB
    mov r8, pR

    vmovdqu ymm2, [rax]      // ymm2 = mask
    vmovdqu ymm0, [rdx]      // ymm0 = a
    vmovdqu ymm1, [rcx]      // ymm1 = b

    vpand   ymm0, ymm0, ymm2 // ymm0 = a AND mask
    vpandn  ymm2, ymm2, ymm1 // ymm2 = (NOT mask) AND b
    vpor    ymm0, ymm0, ymm2 // ymm0 = combine

    vmovdqu [r8], ymm0
    vzeroupper
  end;
end;

// SelectF64x4: bitwise blend = (a AND mask) OR (b AND NOT mask)
function AVX2SelectF64x4(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;
var
  pMask, pA, pB, pR: Pointer;
begin
  pMask := @mask;
  pA := @a;
  pB := @b;
  pR := @Result;
  asm
    mov rax, pMask
    mov rdx, pA
    mov rcx, pB
    mov r8, pR

    vmovdqu ymm2, [rax]      // ymm2 = mask
    vmovdqu ymm0, [rdx]      // ymm0 = a
    vmovdqu ymm1, [rcx]      // ymm1 = b

    vpand   ymm0, ymm0, ymm2 // ymm0 = a AND mask
    vpandn  ymm2, ymm2, ymm1 // ymm2 = (NOT mask) AND b
    vpor    ymm0, ymm0, ymm2 // ymm0 = combine

    vmovdqu [r8], ymm0
    vzeroupper
  end;
end;

// ============================================================================
{$I nextpas.core.simd.avx2.wide_emulation.inc}

// === Batch Array Operations (AVX2 256-bit) ===
{$I nextpas.core.simd.avx2.batch.inc}

// === Backend Registration ===

{$I nextpas.core.simd.avx2.register.inc}


end.
