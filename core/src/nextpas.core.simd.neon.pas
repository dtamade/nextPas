unit nextpas.core.simd.neon;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{
  === nextpas.core.simd.neon ===
  ARM NEON SIMD Backend Implementation

  This provides NEON-optimized implementations for ARM processors.
  NEON is available on ARMv7-A, ARMv8-A (AArch32), and AArch64 processors.

  Features:
  - 128-bit vector registers (v0-v31 on AArch64, q0-q15 on ARMv7)
  - Single and double precision floating-point
  - Integer SIMD operations (8, 16, 32, 64-bit)

  AArch64 Calling Convention (AAPCS64):
  - Arguments: x0-x7 (integer/pointer), v0-v7 (SIMD/FP)
  - Return: x0 (integer), v0 (SIMD/FP)
  - Callee-saved: x19-x28, v8-v15 (lower 64 bits only)
  - For struct returns, pointer passed in x8

  === COMPILER REQUIREMENTS ===

  FPC 3.2.2 Limitation:
  FPC 3.2.2 does NOT support AArch64 NEON inline assembly. Any use of
  vector register syntax like "v0.4s" or "v1.16b" causes an Internal
  Compiler Error (ICE). This is a fundamental compiler limitation, not
  a code pattern issue.

  Minimum FPC Version: 3.3.1 (trunk) for NEON inline assembly support.

  Workarounds for FPC 3.2.2 users:
  1. Upgrade to FPC 3.3.1 or later (recommended)
  2. Wait for FPC 3.2.4 release (currently in RC stage)
  3. Use external pre-compiled .o files with C NEON intrinsics
     (see: github.com/neurolabusc/FPCintrinsics for example approach)
  4. Use scalar backend (default behavior - no NEON registered)

  Note: FPC does not provide NEON intrinsics like C compilers do.
  Users must write inline assembly or link external C object files.

  Reference:
  - FPC Wiki: wiki.freepascal.org/AArch64
  - ARM NEON syntax: "add v0.4s, v1.4s, v2.4s" (AArch64 style)
}

interface

uses
  nextpas.core.simd.backend.priority,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

// Register the NEON backend
procedure RegisterNEONBackend;

// === NEON Facade Functions ===

// Memory operations
function MemEqual_NEON(a, b: Pointer; len: SizeUInt): LongBool;
function MemFindByte_NEON(p: Pointer; len: SizeUInt; value: Byte): PtrInt;

// Statistics functions
function SumBytes_NEON(p: Pointer; len: SizeUInt): UInt64;
procedure MinMaxBytes_NEON(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
function CountByte_NEON(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;

// Text processing functions
function AsciiIEqual_NEON(a, b: Pointer; len: SizeUInt): Boolean;
procedure ToLowerAscii_NEON(p: Pointer; len: SizeUInt);
procedure ToUpperAscii_NEON(p: Pointer; len: SizeUInt);

// Search functions
function BitsetPopCount_NEON(p: Pointer; byteLen: SizeUInt): SizeUInt;

implementation

uses
  nextpas.core.simd.mathutil,
  nextpas.core.simd.scalar;

// === NEON Vector Type ===
{$IFDEF CPUAARCH64}
type
  TNeon128 = packed record
    case Integer of
      0: (u8: array[0..15] of UInt8);
      1: (i8: array[0..15] of Int8);
      2: (u16: array[0..7] of UInt16);
      3: (i16: array[0..7] of Int16);
      4: (u32: array[0..3] of UInt32);
      5: (i32: array[0..3] of Int32);
      6: (u64: array[0..1] of UInt64);
      7: (i64: array[0..1] of Int64);
      8: (f32: array[0..3] of Single);
      9: (f64: array[0..1] of Double);
  end;
  PNeon128 = ^TNeon128;
{$ENDIF}

// ============================================================================
// === AArch64 NEON Assembly Implementations ===
// ============================================================================
// FPC 3.2.2 does NOT support AArch64 NEON inline assembly (ICE on any vN.xS syntax).
// NEON ASM requires FPC >= 3.3.1.
// Default policy: keep inline asm OFF unless explicitly opted in, because
// cross-compiler syntax support is still unstable across toolchains.
// Opt-in define: NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM
// Per-backend gate: NEXTPAS_SIMD_ENABLE_NEON_ASM
// Compiler capability gate: NEXTPAS_SIMD_NEON_ASM_COMPILER_READY
// Global emergency switch: SIMD_VECTOR_ASM_DISABLED
{$IFDEF CPUAARCH64}
  {$IFDEF FPC}
    {$IF FPC_FULLVERSION >= 030301}
      {$IFNDEF SIMD_VECTOR_ASM_DISABLED}
        {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM}
          {$IFDEF NEXTPAS_SIMD_ENABLE_NEON_ASM}
            {$IFDEF NEXTPAS_SIMD_NEON_ASM_COMPILER_READY}
              {$DEFINE NEXTPAS_SIMD_NEON_ASM_ENABLED}
            {$ENDIF}
          {$ENDIF}
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

{$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

// === F32x4 Arithmetic Operations ===

function NEONAddF32x4(const a, b: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  // ABI (FPC AArch64):
  // - 16-byte records are passed by value in GPRs.
  // - a: x0..x1, b: x2..x3, return: x0..x1.
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fadd  v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONSubF32x4(const a, b: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fsub  v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONMulF32x4(const a, b: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fmul  v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONDivF32x4(const a, b: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fdiv  v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === F64x2 Arithmetic Operations ===

function NEONAddF64x2(const a, b: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  // a: x0..x1, b: x2..x3
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fadd  v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONSubF64x2(const a, b: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fsub  v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONMulF64x2(const a, b: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fmul  v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONDivF64x2(const a, b: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fdiv  v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === F64x2 Math Functions ===

function NEONAbsF64x2(const a: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  // a: x0..x1, return: x0..x1
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fabs  v0.2d, v0.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONSqrtF64x2(const a: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fsqrt v0.2d, v0.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONMinF64x2(const a, b: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  // a: x0..x1, b: x2..x3
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fmin  v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONMaxF64x2(const a, b: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fmax  v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONFloorF64x2(const a: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  frintm v0.2d, v0.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONCeilF64x2(const a: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  frintp v0.2d, v0.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONRoundF64x2(const a: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  frintn v0.2d, v0.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONTruncF64x2(const a: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  frintz v0.2d, v0.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONFmaF64x2(const a, b, c: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  // a: x0..x1, b: x2..x3, c: x4..x5
  // Result = a * b + c
  fmov  d0, x0
  fmov  d3, x1
  ins   v0.d[1], v3.d[0]

  fmov  d1, x2
  fmov  d3, x3
  ins   v1.d[1], v3.d[0]

  fmov  d2, x4
  fmov  d3, x5
  ins   v2.d[1], v3.d[0]

  fmla  v2.2d, v0.2d, v1.2d  // v2 = a*b + c

  umov  x0, v2.d[0]
  umov  x1, v2.d[1]
end;

function NEONClampF64x2(const a, minVal, maxVal: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  // a: x0..x1, minVal: x2..x3, maxVal: x4..x5
  fmov  d0, x0
  fmov  d3, x1
  ins   v0.d[1], v3.d[0]

  fmov  d1, x2
  fmov  d3, x3
  ins   v1.d[1], v3.d[0]

  fmov  d2, x4
  fmov  d3, x5
  ins   v2.d[1], v3.d[0]

  fmax  v0.2d, v0.2d, v1.2d
  fmin  v0.2d, v0.2d, v2.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === F64x2 Comparison Operations ===

function NEONCmpEqF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  // a: x0..x1, b: x2..x3
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  fcmeq v0.2d, v0.2d, v1.2d

  // Extract sign bits to build 2-bit mask
  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63

  orr   w0, w2, w3, lsl #1
end;

function NEONCmpLtF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  // a < b  <=>  b > a
  fcmgt v0.2d, v1.2d, v0.2d

  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63

  orr   w0, w2, w3, lsl #1
end;

function NEONCmpLeF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  // a <= b  <=>  b >= a
  fcmge v0.2d, v1.2d, v0.2d

  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63

  orr   w0, w2, w3, lsl #1
end;

function NEONCmpGtF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  fcmgt v0.2d, v0.2d, v1.2d

  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63

  orr   w0, w2, w3, lsl #1
end;

function NEONCmpGeF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  fcmge v0.2d, v0.2d, v1.2d

  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63

  orr   w0, w2, w3, lsl #1
end;

function NEONCmpNeF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d4, x1
  ins   v0.d[1], v4.d[0]

  fmov  d1, x2
  fmov  d4, x3
  ins   v1.d[1], v4.d[0]

  fcmeq v0.2d, v0.2d, v1.2d
  mvn   v0.16b, v0.16b

  umov  x2, v0.d[0]
  lsr   x2, x2, #63
  umov  x3, v0.d[1]
  lsr   x3, x3, #63

  orr   w0, w2, w3, lsl #1
end;

// === F64x2 Memory Operations ===

function NEONLoadF64x2(p: PDouble): TVecF64x2; assembler; nostackframe;
asm
  // p in x0, return in x0..x1
  ldr   q0, [x0]
  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

procedure NEONStoreF64x2(p: PDouble; const a: TVecF64x2); assembler; nostackframe;
asm
  // p: x0, a: x1..x2
  fmov  d0, x1
  fmov  d1, x2
  ins   v0.d[1], v1.d[0]
  str   q0, [x0]
end;

// === F64x2 Utility Operations ===

function NEONSplatF64x2(value: Double): TVecF64x2; assembler; nostackframe;
asm
  // value in d0; return replicated lanes in x0/x1
  fmov  x0, d0
  fmov  x1, d0
end;

function NEONZeroF64x2: TVecF64x2; assembler; nostackframe;
asm
  mov   x0, xzr
  mov   x1, xzr
end;

function NEONExtractF64x2(const a: TVecF64x2; index: Integer): Double; assembler; nostackframe;
asm
  // ABI: a in x0..x1, index in w2
  fmov  d0, x0
  fmov  d1, x1

  // Clamp index to [0..1] (saturating semantics)
  cmp   w2, #0
  b.le  .Lext_d_0
  // index >= 1
  fmov  d0, d1
  ret

.Lext_d_0:
  // index <= 0, d0 already holds correct value
end;

function NEONInsertF64x2(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2; assembler; nostackframe;
asm
  // ABI: a in x0..x1, value in d0, index in w2, return x0..x1
  fmov  d1, x0
  fmov  d2, x1
  ins   v1.d[1], v2.d[0]

  // Clamp index to [0..1]
  cmp   w2, #0
  b.le  .Lins_d_0
  // index >= 1
  ins   v1.d[1], v0.d[0]
  b     .Lins_d_done
.Lins_d_0:
  ins   v1.d[0], v0.d[0]
.Lins_d_done:
  umov  x0, v1.d[0]
  umov  x1, v1.d[1]
end;

function NEONSelectF64x2(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2; assembler; nostackframe;
asm
  // ABI: mask in w0, a: x1..x2, b: x3..x4, return: x0..x1
  fmov  d0, x1
  fmov  d4, x2
  ins   v0.d[1], v4.d[0]

  fmov  d1, x3
  fmov  d4, x4
  ins   v1.d[1], v4.d[0]

  // Expand 2-bit mask to 128-bit mask
  movi  v2.2d, #0
  movi  v3.16b, #0xff

  // Bit 0
  tst   w0, #1
  b.eq  .Lbit0_zero_d
  ins   v2.d[0], v3.d[0]
.Lbit0_zero_d:

  // Bit 1
  tst   w0, #2
  b.eq  .Lbit1_zero_d
  ins   v2.d[1], v3.d[0]
.Lbit1_zero_d:

  // Bit select: result = (a AND mask) OR (b AND NOT mask)
  bsl   v2.16b, v0.16b, v1.16b

  umov  x0, v2.d[0]
  umov  x1, v2.d[1]
end;

// === F64x2 Reduction Operations ===

function NEONReduceAddF64x2(const a: TVecF64x2): Double; assembler; nostackframe;
asm
  // a: x0..x1
  fmov  d0, x0
  fmov  d1, x1
  fadd  d0, d0, d1
end;

function NEONReduceMinF64x2(const a: TVecF64x2): Double; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d1, x1
  fmin  d0, d0, d1
end;

function NEONReduceMaxF64x2(const a: TVecF64x2): Double; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d1, x1
  fmax  d0, d0, d1
end;

function NEONReduceMulF64x2(const a: TVecF64x2): Double; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d1, x1
  fmul  d0, d0, d1
end;

// === I32x4 Arithmetic Operations ===

function NEONAddI32x4(const a, b: TVecI32x4): TVecI32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  add   v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONSubI32x4(const a, b: TVecI32x4): TVecI32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  sub   v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONMulI32x4(const a, b: TVecI32x4): TVecI32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  mul   v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === I32x4 Shift Operations ===

function NEONShiftLeftI32x4(const a: TVecI32x4; count: Integer): TVecI32x4; assembler; nostackframe;
asm
  // a: x0..x1, count: w2
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  // NEON 使用向量左移：dup shift count 到所有通道，然后使用 shl
  dup   v1.4s, w2
  ushl   v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftRightI32x4(const a: TVecI32x4; count: Integer): TVecI32x4; assembler; nostackframe;
asm
  // 逻辑右移（无符号）
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  // 右移需要负的 shift count
  neg   w2, w2
  dup   v1.4s, w2
  ushl   v0.4s, v0.4s, v1.4s  // 使用 shl 配合负数 = 逻辑右移

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftRightArithI32x4(const a: TVecI32x4; count: Integer): TVecI32x4; assembler; nostackframe;
asm
  // 算术右移（保留符号位）
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  // 使用 sshr 进行算术右移
  dup   v1.4s, w2
  neg   v1.4s, v1.4s         // 取反移位量
  sshl  v0.4s, v0.4s, v1.4s  // 有符号移位

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftLeftU32x4(const a: TVecU32x4; count: Integer): TVecU32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  dup   v1.4s, w2
  ushl   v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftRightU32x4(const a: TVecU32x4; count: Integer): TVecU32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  neg   w2, w2
  dup   v1.4s, w2
  ushl   v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === I32x4 Bitwise Operations ===

function NEONAndI32x4(const a, b: TVecI32x4): TVecI32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  and   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONOrI32x4(const a, b: TVecI32x4): TVecI32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  orr   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONXorI32x4(const a, b: TVecI32x4): TVecI32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  eor   v0.16b, v0.16b, v1.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONNotI32x4(const a: TVecI32x4): TVecI32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  mvn   v0.16b, v0.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONAndNotI32x4(const a, b: TVecI32x4): TVecI32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  bic   v0.16b, v1.16b, v0.16b

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === I64x2 Shift Operations ===
// Keep the raw NEON lane shifts in *Asm helpers and let the public wrappers
// preserve the published invalid-count fallback semantics.

function NEONShiftLeftI64x2(const a: TVecI64x2; count: Integer): TVecI64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  // ushl v?.2d consumes 64-bit lane counts; normalize the public Integer input
  // before duplicating it into the shift vector.
  mov   w2, w2
  dup   v1.2d, x2
  ushl   v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftRightI64x2Asm(const a: TVecI64x2; count: Integer): TVecI64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  neg   w2, w2
  sxtw  x2, w2               // 符号扩展到 64 位
  dup   v1.2d, x2
  ushl   v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftRightI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  if (count < 0) or (count >= 64) then
    Exit(ScalarShiftRightI64x2(a, count));
  Result := NEONShiftRightI64x2Asm(a, count);
end;

function NEONShiftRightArithI64x2Asm(const a: TVecI64x2; count: Integer): TVecI64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  neg   w2, w2
  sxtw  x2, w2
  dup   v1.2d, x2
  sshl  v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftRightArithI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  if (count < 0) or (count >= 64) then
    Exit(ScalarShiftRightArithI64x2(a, count));
  Result := NEONShiftRightArithI64x2Asm(a, count);
end;

function NEONShiftLeftU64x2(const a: TVecU64x2; count: Integer): TVecU64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  mov   w2, w2
  dup   v1.2d, x2
  ushl   v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftRightU64x2Asm(const a: TVecU64x2; count: Integer): TVecU64x2; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  neg   w2, w2
  sxtw  x2, w2
  dup   v1.2d, x2
  ushl   v0.2d, v0.2d, v1.2d

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftRightU64x2(const a: TVecU64x2; count: Integer): TVecU64x2;
begin
  if (count < 0) or (count >= 64) then
  begin
    Result.u[0] := 0;
    Result.u[1] := 0;
    Exit;
  end;
  Result := NEONShiftRightU64x2Asm(a, count);
end;

// === I16x8 Shift Operations ===

function NEONShiftLeftI16x8(const a: TVecI16x8; count: Integer): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  dup   v1.8h, w2
  ushl   v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftRightI16x8(const a: TVecI16x8; count: Integer): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  neg   w2, w2
  dup   v1.8h, w2
  ushl   v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftRightArithI16x8(const a: TVecI16x8; count: Integer): TVecI16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  neg   w2, w2
  dup   v1.8h, w2
  sshl  v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftLeftU16x8(const a: TVecU16x8; count: Integer): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  dup   v1.8h, w2
  ushl   v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONShiftRightU16x8(const a: TVecU16x8; count: Integer): TVecU16x8; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  neg   w2, w2
  dup   v1.8h, w2
  ushl   v0.8h, v0.8h, v1.8h

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === F32x8 (2x 128-bit operations) ===

function NEONAddF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]       // Load a.lo and a.hi
  ldp   q2, q3, [x1]       // Load b.lo and b.hi
  fadd  v0.4s, v0.4s, v2.4s
  fadd  v1.4s, v1.4s, v3.4s
  stp   q0, q1, [x8]       // Store result
end;

function NEONSubF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  fsub  v0.4s, v0.4s, v2.4s
  fsub  v1.4s, v1.4s, v3.4s
  stp   q0, q1, [x8]
end;

function NEONMulF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  fmul  v0.4s, v0.4s, v2.4s
  fmul  v1.4s, v1.4s, v3.4s
  stp   q0, q1, [x8]
end;

function NEONDivF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  fdiv  v0.4s, v0.4s, v2.4s
  fdiv  v1.4s, v1.4s, v3.4s
  stp   q0, q1, [x8]
end;

// === F32x8 Math Functions (256-bit = 2x128-bit NEON) ===

function NEONAbsF32x8(const a: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  // ABI: a: pointer in x0, return: pointer in x8
  ldp   q0, q1, [x0]       // Load a.lo and a.hi
  fabs  v0.4s, v0.4s       // Abs lo
  fabs  v1.4s, v1.4s       // Abs hi
  stp   q0, q1, [x8]       // Store result
end;

function NEONSqrtF32x8(const a: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  fsqrt v0.4s, v0.4s
  fsqrt v1.4s, v1.4s
  stp   q0, q1, [x8]
end;

function NEONMinF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]       // Load a
  ldp   q2, q3, [x1]       // Load b
  fmin  v0.4s, v0.4s, v2.4s
  fmin  v1.4s, v1.4s, v3.4s
  stp   q0, q1, [x8]
end;

function NEONMaxF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  fmax  v0.4s, v0.4s, v2.4s
  fmax  v1.4s, v1.4s, v3.4s
  stp   q0, q1, [x8]
end;

function NEONFloorF32x8(const a: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  frintm v0.4s, v0.4s
  frintm v1.4s, v1.4s
  stp   q0, q1, [x8]
end;

function NEONCeilF32x8(const a: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  frintp v0.4s, v0.4s
  frintp v1.4s, v1.4s
  stp   q0, q1, [x8]
end;

function NEONRoundF32x8(const a: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  frintn v0.4s, v0.4s
  frintn v1.4s, v1.4s
  stp   q0, q1, [x8]
end;

function NEONTruncF32x8(const a: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  frintz v0.4s, v0.4s
  frintz v1.4s, v1.4s
  stp   q0, q1, [x8]
end;

function NEONFmaF32x8(const a, b, c: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  // Result = a + b * c
  ldp   q0, q1, [x0]       // Load a
  ldp   q2, q3, [x1]       // Load b
  ldp   q4, q5, [x2]       // Load c
  fmla  v0.4s, v2.4s, v4.4s  // a.lo += b.lo * c.lo
  fmla  v1.4s, v3.4s, v5.4s  // a.hi += b.hi * c.hi
  stp   q0, q1, [x8]
end;

function NEONClampF32x8(const a, minVal, maxVal: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]       // Load a
  ldp   q2, q3, [x1]       // Load minVal
  ldp   q4, q5, [x2]       // Load maxVal
  fmax  v0.4s, v0.4s, v2.4s  // max(a.lo, minVal.lo)
  fmax  v1.4s, v1.4s, v3.4s  // max(a.hi, minVal.hi)
  fmin  v0.4s, v0.4s, v4.4s  // min(result.lo, maxVal.lo)
  fmin  v1.4s, v1.4s, v5.4s  // min(result.hi, maxVal.hi)
  stp   q0, q1, [x8]
end;

// === F64x4 Arithmetic Operations (256-bit = 2x128-bit NEON) ===

function NEONAddF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  // ABI: a: pointer in x0, b: pointer in x1, return: pointer in x8
  ldp   q0, q1, [x0]       // Load a.lo and a.hi (each 2xf64)
  ldp   q2, q3, [x1]       // Load b.lo and b.hi
  fadd  v0.2d, v0.2d, v2.2d
  fadd  v1.2d, v1.2d, v3.2d
  stp   q0, q1, [x8]       // Store result
end;

function NEONSubF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  fsub  v0.2d, v0.2d, v2.2d
  fsub  v1.2d, v1.2d, v3.2d
  stp   q0, q1, [x8]
end;

function NEONMulF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  fmul  v0.2d, v0.2d, v2.2d
  fmul  v1.2d, v1.2d, v3.2d
  stp   q0, q1, [x8]
end;

function NEONDivF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  fdiv  v0.2d, v0.2d, v2.2d
  fdiv  v1.2d, v1.2d, v3.2d
  stp   q0, q1, [x8]
end;

function NEONMinF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  fmin  v0.2d, v0.2d, v2.2d
  fmin  v1.2d, v1.2d, v3.2d
  stp   q0, q1, [x8]
end;

function NEONMaxF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  fmax  v0.2d, v0.2d, v2.2d
  fmax  v1.2d, v1.2d, v3.2d
  stp   q0, q1, [x8]
end;

function NEONAbsF64x4(const a: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  fabs  v0.2d, v0.2d
  fabs  v1.2d, v1.2d
  stp   q0, q1, [x8]
end;

function NEONSqrtF64x4(const a: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  fsqrt v0.2d, v0.2d
  fsqrt v1.2d, v1.2d
  stp   q0, q1, [x8]
end;

function NEONFloorF64x4(const a: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  frintm v0.2d, v0.2d
  frintm v1.2d, v1.2d
  stp   q0, q1, [x8]
end;

function NEONCeilF64x4(const a: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  frintp v0.2d, v0.2d
  frintp v1.2d, v1.2d
  stp   q0, q1, [x8]
end;

function NEONRoundF64x4(const a: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  frintn v0.2d, v0.2d
  frintn v1.2d, v1.2d
  stp   q0, q1, [x8]
end;

function NEONTruncF64x4(const a: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  frintz v0.2d, v0.2d
  frintz v1.2d, v1.2d
  stp   q0, q1, [x8]
end;

function NEONFmaF64x4(const a, b, c: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  // Result = a + b * c
  ldp   q0, q1, [x0]       // Load a
  ldp   q2, q3, [x1]       // Load b
  ldp   q4, q5, [x2]       // Load c
  fmla  v0.2d, v2.2d, v4.2d  // a.lo += b.lo * c.lo
  fmla  v1.2d, v3.2d, v5.2d  // a.hi += b.hi * c.hi
  stp   q0, q1, [x8]
end;

function NEONClampF64x4(const a, minVal, maxVal: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]       // Load a
  ldp   q2, q3, [x1]       // Load minVal
  ldp   q4, q5, [x2]       // Load maxVal
  fmax  v0.2d, v0.2d, v2.2d  // max(a.lo, minVal.lo)
  fmax  v1.2d, v1.2d, v3.2d  // max(a.hi, minVal.hi)
  fmin  v0.2d, v0.2d, v4.2d  // min(result.lo, maxVal.lo)
  fmin  v1.2d, v1.2d, v5.2d  // min(result.hi, maxVal.hi)
  stp   q0, q1, [x8]
end;

// === I32x8 Arithmetic Operations (256-bit = 2x128-bit NEON) ===
// Integer SIMD operations must wrap on overflow (hardware semantics).

function NEONAddI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  // ABI: a: pointer in x0, b: pointer in x1, return: pointer in x8
  ldp   q0, q1, [x0]       // Load a.lo and a.hi (each 4xi32)
  ldp   q2, q3, [x1]       // Load b.lo and b.hi
  add   v0.4s, v0.4s, v2.4s
  add   v1.4s, v1.4s, v3.4s
  stp   q0, q1, [x8]       // Store result
end;

function NEONSubI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  sub   v0.4s, v0.4s, v2.4s
  sub   v1.4s, v1.4s, v3.4s
  stp   q0, q1, [x8]
end;

function NEONMulI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  mul   v0.4s, v0.4s, v2.4s
  mul   v1.4s, v1.4s, v3.4s
  stp   q0, q1, [x8]
end;

// === I32x8 Bitwise Operations (256-bit = 2x128-bit NEON) ===

function NEONAndI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  and   v0.16b, v0.16b, v2.16b
  and   v1.16b, v1.16b, v3.16b
  stp   q0, q1, [x8]
end;

function NEONOrI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  orr   v0.16b, v0.16b, v2.16b
  orr   v1.16b, v1.16b, v3.16b
  stp   q0, q1, [x8]
end;

function NEONXorI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  eor   v0.16b, v0.16b, v2.16b
  eor   v1.16b, v1.16b, v3.16b
  stp   q0, q1, [x8]
end;

function NEONNotI32x8(const a: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  mvn   v0.16b, v0.16b
  mvn   v1.16b, v1.16b
  stp   q0, q1, [x8]
end;

function NEONAndNotI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  bic   v0.16b, v2.16b, v0.16b
  bic   v1.16b, v3.16b, v1.16b
  stp   q0, q1, [x8]
end;

// === I32x8 Shift Operations (256-bit = 2x128-bit NEON) ===
// Contract split:
// - *Asm helpers are raw NEON lane shifts and expect a validated shift count.
// - Public entrypoints preserve the published scalar fallback semantics for
//   negative / out-of-range counts before forwarding to the raw helper.

function NEONShiftLeftI32x8Asm(const a: TVecI32x8; count: Integer): TVecI32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  dup   v2.4s, w1
  ushl   v0.4s, v0.4s, v2.4s
  ushl   v1.4s, v1.4s, v2.4s
  stp   q0, q1, [x8]
end;

function NEONShiftLeftI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  if (count < 0) or (count >= 32) then
    Exit(ScalarShiftLeftI32x8(a, count));
  Result := NEONShiftLeftI32x8Asm(a, count);
end;

function NEONShiftRightI32x8Asm(const a: TVecI32x8; count: Integer): TVecI32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  neg   w1, w1
  dup   v2.4s, w1
  ushl   v0.4s, v0.4s, v2.4s
  ushl   v1.4s, v1.4s, v2.4s
  stp   q0, q1, [x8]
end;

function NEONShiftRightI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  if (count < 0) or (count >= 32) then
    Exit(ScalarShiftRightI32x8(a, count));
  Result := NEONShiftRightI32x8Asm(a, count);
end;

function NEONShiftRightArithI32x8Asm(const a: TVecI32x8; count: Integer): TVecI32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  neg   w1, w1
  dup   v2.4s, w1
  sshl  v0.4s, v0.4s, v2.4s
  sshl  v1.4s, v1.4s, v2.4s
  stp   q0, q1, [x8]
end;

function NEONShiftRightArithI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  if (count < 0) or (count >= 32) then
    Exit(ScalarShiftRightArithI32x8(a, count));
  Result := NEONShiftRightArithI32x8Asm(a, count);
end;

function NEONShiftLeftU32x8(const a: TVecU32x8; count: Integer): TVecU32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  dup   v2.4s, w1
  ushl   v0.4s, v0.4s, v2.4s
  ushl   v1.4s, v1.4s, v2.4s
  stp   q0, q1, [x8]
end;

function NEONShiftRightU32x8(const a: TVecU32x8; count: Integer): TVecU32x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  neg   w1, w1
  dup   v2.4s, w1
  ushl   v0.4s, v0.4s, v2.4s
  ushl   v1.4s, v1.4s, v2.4s
  stp   q0, q1, [x8]
end;

// === I64x4 Shift Operations (256-bit = 2x128-bit NEON) ===
// Same wrapper boundary as I32x8: public functions own the scalar-range
// contract, while *Asm helpers stay as direct NEON lane operations.

function NEONShiftLeftI64x4Asm(const a: TVecI64x4; count: Integer): TVecI64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  // ushl v?.2d consumes 64-bit lane counts; keep the public Integer count
  // zero-extended before duplicating it into the NEON shift vector.
  mov   w1, w1
  dup   v2.2d, x1
  ushl   v0.2d, v0.2d, v2.2d
  ushl   v1.2d, v1.2d, v2.2d
  stp   q0, q1, [x8]
end;

function NEONShiftLeftI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  if (count < 0) or (count >= 64) then
    Exit(ScalarShiftLeftI64x4(a, count));
  Result := NEONShiftLeftI64x4Asm(a, count);
end;

function NEONShiftRightI64x4Asm(const a: TVecI64x4; count: Integer): TVecI64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  neg   w1, w1
  sxtw  x1, w1
  dup   v2.2d, x1
  ushl   v0.2d, v0.2d, v2.2d
  ushl   v1.2d, v1.2d, v2.2d
  stp   q0, q1, [x8]
end;

function NEONShiftRightI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  if (count < 0) or (count >= 64) then
    Exit(ScalarShiftRightI64x4(a, count));
  Result := NEONShiftRightI64x4Asm(a, count);
end;

function NEONShiftRightArithI64x4Asm(const a: TVecI64x4; count: Integer): TVecI64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  neg   w1, w1
  sxtw  x1, w1
  dup   v2.2d, x1
  sshl  v0.2d, v0.2d, v2.2d
  sshl  v1.2d, v1.2d, v2.2d
  stp   q0, q1, [x8]
end;

function NEONShiftRightArithI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  if (count < 0) or (count >= 64) then
    Exit(ScalarShiftRightArithI64x4(a, count));
  Result := NEONShiftRightArithI64x4Asm(a, count);
end;

function NEONShiftLeftU64x4(const a: TVecU64x4; count: Integer): TVecU64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  mov   w1, w1
  dup   v2.2d, x1
  ushl   v0.2d, v0.2d, v2.2d
  ushl   v1.2d, v1.2d, v2.2d
  stp   q0, q1, [x8]
end;

function NEONShiftRightU64x4Asm(const a: TVecU64x4; count: Integer): TVecU64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  neg   w1, w1
  sxtw  x1, w1
  dup   v2.2d, x1
  ushl   v0.2d, v0.2d, v2.2d
  ushl   v1.2d, v1.2d, v2.2d
  stp   q0, q1, [x8]
end;

function NEONShiftRightU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
begin
  if (count < 0) or (count >= 64) then
    Exit(ScalarShiftRightU64x4(a, count));
  Result := NEONShiftRightU64x4Asm(a, count);
end;

// === I64x4 Bitwise Operations (256-bit = 2x128-bit NEON) ===

function NEONAndI64x4(const a, b: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  and   v0.16b, v0.16b, v2.16b
  and   v1.16b, v1.16b, v3.16b
  stp   q0, q1, [x8]
end;

function NEONOrI64x4(const a, b: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  orr   v0.16b, v0.16b, v2.16b
  orr   v1.16b, v1.16b, v3.16b
  stp   q0, q1, [x8]
end;

function NEONXorI64x4(const a, b: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  eor   v0.16b, v0.16b, v2.16b
  eor   v1.16b, v1.16b, v3.16b
  stp   q0, q1, [x8]
end;

function NEONNotI64x4(const a: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  mvn   v0.16b, v0.16b
  mvn   v1.16b, v1.16b
  stp   q0, q1, [x8]
end;

function NEONAndNotI64x4(const a, b: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x1]
  bic   v0.16b, v2.16b, v0.16b
  bic   v1.16b, v3.16b, v1.16b
  stp   q0, q1, [x8]
end;

// === F32x16 Math Functions (512-bit = 4x128-bit NEON) ===

function NEONAbsF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]        // Load a[0..7]
  ldp   q2, q3, [x0, #32]   // Load a[8..15]
  fabs  v0.4s, v0.4s
  fabs  v1.4s, v1.4s
  fabs  v2.4s, v2.4s
  fabs  v3.4s, v3.4s
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONSqrtF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  fsqrt v0.4s, v0.4s
  fsqrt v1.4s, v1.4s
  fsqrt v2.4s, v2.4s
  fsqrt v3.4s, v3.4s
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONFloorF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  frintm v0.4s, v0.4s
  frintm v1.4s, v1.4s
  frintm v2.4s, v2.4s
  frintm v3.4s, v3.4s
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONCeilF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  frintp v0.4s, v0.4s
  frintp v1.4s, v1.4s
  frintp v2.4s, v2.4s
  frintp v3.4s, v3.4s
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONRoundF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  frintn v0.4s, v0.4s
  frintn v1.4s, v1.4s
  frintn v2.4s, v2.4s
  frintn v3.4s, v3.4s
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONTruncF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  frintz v0.4s, v0.4s
  frintz v1.4s, v1.4s
  frintz v2.4s, v2.4s
  frintz v3.4s, v3.4s
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONFmaF32x16(const a, b, c: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  // Result = a + b * c
  ldp   q0, q1, [x0]        // Load a[0..7]
  ldp   q2, q3, [x0, #32]   // Load a[8..15]
  ldp   q4, q5, [x1]        // Load b[0..7]
  ldp   q6, q7, [x1, #32]   // Load b[8..15]
  ldp   q16, q17, [x2]      // Load c[0..7]
  ldp   q18, q19, [x2, #32] // Load c[8..15]
  fmla  v0.4s, v4.4s, v16.4s
  fmla  v1.4s, v5.4s, v17.4s
  fmla  v2.4s, v6.4s, v18.4s
  fmla  v3.4s, v7.4s, v19.4s
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONClampF32x16(const a, minVal, maxVal: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]        // Load a[0..7]
  ldp   q2, q3, [x0, #32]   // Load a[8..15]
  ldp   q4, q5, [x1]        // Load minVal[0..7]
  ldp   q6, q7, [x1, #32]   // Load minVal[8..15]
  ldp   q16, q17, [x2]      // Load maxVal[0..7]
  ldp   q18, q19, [x2, #32] // Load maxVal[8..15]
  fmax  v0.4s, v0.4s, v4.4s
  fmax  v1.4s, v1.4s, v5.4s
  fmax  v2.4s, v2.4s, v6.4s
  fmax  v3.4s, v3.4s, v7.4s
  fmin  v0.4s, v0.4s, v16.4s
  fmin  v1.4s, v1.4s, v17.4s
  fmin  v2.4s, v2.4s, v18.4s
  fmin  v3.4s, v3.4s, v19.4s
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

// === F64x8 Math Functions (512-bit = 4x128-bit NEON) ===

function NEONAbsF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]        // Load a[0..3]
  ldp   q2, q3, [x0, #32]   // Load a[4..7]
  fabs  v0.2d, v0.2d
  fabs  v1.2d, v1.2d
  fabs  v2.2d, v2.2d
  fabs  v3.2d, v3.2d
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONSqrtF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  fsqrt v0.2d, v0.2d
  fsqrt v1.2d, v1.2d
  fsqrt v2.2d, v2.2d
  fsqrt v3.2d, v3.2d
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONFloorF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  frintm v0.2d, v0.2d
  frintm v1.2d, v1.2d
  frintm v2.2d, v2.2d
  frintm v3.2d, v3.2d
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONCeilF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  frintp v0.2d, v0.2d
  frintp v1.2d, v1.2d
  frintp v2.2d, v2.2d
  frintp v3.2d, v3.2d
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONRoundF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  frintn v0.2d, v0.2d
  frintn v1.2d, v1.2d
  frintn v2.2d, v2.2d
  frintn v3.2d, v3.2d
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONTruncF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  frintz v0.2d, v0.2d
  frintz v1.2d, v1.2d
  frintz v2.2d, v2.2d
  frintz v3.2d, v3.2d
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONFmaF64x8(const a, b, c: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  // Result = a + b * c
  ldp   q0, q1, [x0]        // Load a[0..3]
  ldp   q2, q3, [x0, #32]   // Load a[4..7]
  ldp   q4, q5, [x1]        // Load b[0..3]
  ldp   q6, q7, [x1, #32]   // Load b[4..7]
  ldp   q16, q17, [x2]      // Load c[0..3]
  ldp   q18, q19, [x2, #32] // Load c[4..7]
  fmla  v0.2d, v4.2d, v16.2d
  fmla  v1.2d, v5.2d, v17.2d
  fmla  v2.2d, v6.2d, v18.2d
  fmla  v3.2d, v7.2d, v19.2d
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]        // Load a[0..3]
  ldp   q2, q3, [x0, #32]   // Load a[4..7]
  ldp   q4, q5, [x1]        // Load minVal[0..3]
  ldp   q6, q7, [x1, #32]   // Load minVal[4..7]
  ldp   q16, q17, [x2]      // Load maxVal[0..3]
  ldp   q18, q19, [x2, #32] // Load maxVal[4..7]
  fmax  v0.2d, v0.2d, v4.2d
  fmax  v1.2d, v1.2d, v5.2d
  fmax  v2.2d, v2.2d, v6.2d
  fmax  v3.2d, v3.2d, v7.2d
  fmin  v0.2d, v0.2d, v16.2d
  fmin  v1.2d, v1.2d, v17.2d
  fmin  v2.2d, v2.2d, v18.2d
  fmin  v3.2d, v3.2d, v19.2d
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

// === I32x16 Shift Operations (512-bit = 4x128-bit NEON) ===
// I32x16 = {lo, hi: TVecI32x8}, 每个 I32x8 = {lo, hi: TVecI32x4}
// Public wrappers keep the published scalar fallback semantics; *Asm helpers
// only perform the already-range-checked raw NEON lane work across 4 q regs.

function NEONShiftLeftI32x16Asm(const a: TVecI32x16; count: Integer): TVecI32x16; assembler; nostackframe;
asm
  // a: pointer in x0, count: w1, return: pointer in x8
  ldp   q0, q1, [x0]        // 加载 a.lo (2x128-bit)
  ldp   q2, q3, [x0, #32]   // 加载 a.hi (2x128-bit)
  dup   v4.4s, w1           // 复制移位量
  ushl   v0.4s, v0.4s, v4.4s
  ushl   v1.4s, v1.4s, v4.4s
  ushl   v2.4s, v2.4s, v4.4s
  ushl   v3.4s, v3.4s, v4.4s
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONShiftLeftI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  if (count < 0) or (count >= 32) then
    Exit(ScalarShiftLeftI32x16(a, count));
  Result := NEONShiftLeftI32x16Asm(a, count);
end;

function NEONShiftRightI32x16Asm(const a: TVecI32x16; count: Integer): TVecI32x16; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  neg   w1, w1
  dup   v4.4s, w1
  ushl   v0.4s, v0.4s, v4.4s
  ushl   v1.4s, v1.4s, v4.4s
  ushl   v2.4s, v2.4s, v4.4s
  ushl   v3.4s, v3.4s, v4.4s
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONShiftRightI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  if (count < 0) or (count >= 32) then
    Exit(ScalarShiftRightI32x16(a, count));
  Result := NEONShiftRightI32x16Asm(a, count);
end;

function NEONShiftRightArithI32x16Asm(const a: TVecI32x16; count: Integer): TVecI32x16; assembler; nostackframe;
asm
  ldp   q0, q1, [x0]
  ldp   q2, q3, [x0, #32]
  neg   w1, w1
  dup   v4.4s, w1
  sshl  v0.4s, v0.4s, v4.4s
  sshl  v1.4s, v1.4s, v4.4s
  sshl  v2.4s, v2.4s, v4.4s
  sshl  v3.4s, v3.4s, v4.4s
  stp   q0, q1, [x8]
  stp   q2, q3, [x8, #32]
end;

function NEONShiftRightArithI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  if (count < 0) or (count >= 32) then
    Exit(ScalarShiftRightArithI32x16(a, count));
  Result := NEONShiftRightArithI32x16Asm(a, count);
end;

// === Math Functions ===

function NEONAbsF32x4(const a: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  // a: x0..x1, return: x0..x1
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fabs  v0.4s, v0.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONSqrtF32x4(const a: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fsqrt v0.4s, v0.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONMinF32x4(const a, b: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  // a: x0..x1, b: x2..x3
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fmin  v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONMaxF32x4(const a, b: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmov  d1, x2
  fmov  d2, x3
  ins   v1.d[1], v2.d[0]

  fmax  v0.4s, v0.4s, v1.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === Extended Math Functions ===

function NEONFmaF32x4(const a, b, c: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  // a: x0..x1, b: x2..x3, c: x4..x5
  fmov  d0, x0
  fmov  d3, x1
  ins   v0.d[1], v3.d[0]

  fmov  d1, x2
  fmov  d3, x3
  ins   v1.d[1], v3.d[0]

  fmov  d2, x4
  fmov  d3, x5
  ins   v2.d[1], v3.d[0]

  fmla  v2.4s, v0.4s, v1.4s  // v2 = a*b + c

  umov  x0, v2.d[0]
  umov  x1, v2.d[1]
end;

function NEONRcpF32x4(const a: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  frecpe v0.4s, v0.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONRsqrtF32x4(const a: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  frsqrte v0.4s, v0.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === Rounding Operations ===

function NEONFloorF32x4(const a: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  frintm v0.4s, v0.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONCeilF32x4(const a: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  frintp v0.4s, v0.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONRoundF32x4(const a: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  frintn v0.4s, v0.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONTruncF32x4(const a: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  frintz v0.4s, v0.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONClampF32x4(const a, minVal, maxVal: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  // a: x0..x1, minVal: x2..x3, maxVal: x4..x5
  fmov  d0, x0
  fmov  d3, x1
  ins   v0.d[1], v3.d[0]

  fmov  d1, x2
  fmov  d3, x3
  ins   v1.d[1], v3.d[0]

  fmov  d2, x4
  fmov  d3, x5
  ins   v2.d[1], v3.d[0]

  fmax  v0.4s, v0.4s, v1.4s
  fmin  v0.4s, v0.4s, v2.4s

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === Vector Math Operations ===

function NEONDotF32x4(const a, b: TVecF32x4): Single; assembler; nostackframe;
asm
  // a: x0..x1, b: x2..x3
  fmov  d0, x0
  fmov  d3, x1
  ins   v0.d[1], v3.d[0]

  fmov  d1, x2
  fmov  d3, x3
  ins   v1.d[1], v3.d[0]

  fmul  v0.4s, v0.4s, v1.4s
  // Horizontal sum (avoid faddp)
  ext   v2.16b, v0.16b, v0.16b, #8
  fadd  v0.4s, v0.4s, v2.4s
  ext   v2.16b, v0.16b, v0.16b, #4
  fadd  v0.4s, v0.4s, v2.4s
  // Result in s0 (v0.s[0])
end;

function NEONDotF32x3(const a, b: TVecF32x4): Single; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d3, x1
  ins   v0.d[1], v3.d[0]

  fmov  d1, x2
  fmov  d3, x3
  ins   v1.d[1], v3.d[0]

  fmul  v0.4s, v0.4s, v1.4s
  mov   v0.s[3], wzr          // Zero the w component
  // Horizontal sum (avoid faddp)
  ext   v2.16b, v0.16b, v0.16b, #8
  fadd  v0.4s, v0.4s, v2.4s
  ext   v2.16b, v0.16b, v0.16b, #4
  fadd  v0.4s, v0.4s, v2.4s
  // Result in s0 (v0.s[0])
end;


function NEONCrossF32x3(const a, b: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  // a: x0..x1, b: x2..x3, return: x0..x1
  fmov  d0, x0
  fmov  d5, x1
  ins   v0.d[1], v5.d[0]

  fmov  d1, x2
  fmov  d5, x3
  ins   v1.d[1], v5.d[0]

  // Cross product: (a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x, 0)
  // Shuffle a: [y, z, x, w] = 1,2,0,3
  mov   v2.s[0], v0.s[1]      // a.y
  mov   v2.s[1], v0.s[2]      // a.z
  mov   v2.s[2], v0.s[0]      // a.x
  mov   v2.s[3], v0.s[3]      // a.w

  // Shuffle b: [z, x, y, w] = 2,0,1,3
  mov   v3.s[0], v1.s[2]      // b.z
  mov   v3.s[1], v1.s[0]      // b.x
  mov   v3.s[2], v1.s[1]      // b.y
  mov   v3.s[3], v1.s[3]      // b.w

  fmul  v4.4s, v2.4s, v3.4s   // [a.y*b.z, a.z*b.x, a.x*b.y, ...]

  // Shuffle a: [z, x, y, w] = 2,0,1,3
  mov   v2.s[0], v0.s[2]      // a.z
  mov   v2.s[1], v0.s[0]      // a.x
  mov   v2.s[2], v0.s[1]      // a.y

  // Shuffle b: [y, z, x, w] = 1,2,0,3
  mov   v3.s[0], v1.s[1]      // b.y
  mov   v3.s[1], v1.s[2]      // b.z
  mov   v3.s[2], v1.s[0]      // b.x

  fmul  v2.4s, v2.4s, v3.4s   // [a.z*b.y, a.x*b.z, a.y*b.x, ...]
  fsub  v0.4s, v4.4s, v2.4s

  mov   v0.s[3], wzr

  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONLengthF32x4(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  // a: x0..x1
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  fmul  v0.4s, v0.4s, v0.4s
  // Horizontal sum (avoid faddp)
  ext   v1.16b, v0.16b, v0.16b, #8
  fadd  v0.4s, v0.4s, v1.4s
  ext   v1.16b, v0.16b, v0.16b, #4
  fadd  v0.4s, v0.4s, v1.4s
  fsqrt s0, s0
end;

function NEONLengthF32x3(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d2, x1
  ins   v0.d[1], v2.d[0]

  mov   v0.s[3], wzr
  fmul  v0.4s, v0.4s, v0.4s
  // Horizontal sum (avoid faddp)
  ext   v1.16b, v0.16b, v0.16b, #8
  fadd  v0.4s, v0.4s, v1.4s
  ext   v1.16b, v0.16b, v0.16b, #4
  fadd  v0.4s, v0.4s, v1.4s
  fsqrt s0, s0
end;

function NEONNormalizeF32x4(const a: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  // a: x0..x1
  fmov  d0, x0
  fmov  d3, x1
  ins   v0.d[1], v3.d[0]

  fmul  v1.4s, v0.4s, v0.4s        // squares
  // Sum squares (avoid faddp)
  ext   v2.16b, v1.16b, v1.16b, #8
  fadd  v1.4s, v1.4s, v2.4s
  ext   v2.16b, v1.16b, v1.16b, #4
  fadd  v1.4s, v1.4s, v2.4s
  fsqrt s1, s1

  // if length == 0, return original
  fmov  s2, wzr
  fcmp  s1, s2
  b.eq  .Lret_norm4

  // invLen = 1.0 / length
  movz  w3, #0x3f80, lsl #16
  fmov  s2, w3
  fdiv  s1, s2, s1

  // broadcast invLen
  fmov  w3, s1
  dup   v1.4s, w3

  fmul  v0.4s, v0.4s, v1.4s

.Lret_norm4:
  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

function NEONNormalizeF32x3(const a: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  fmov  d0, x0
  fmov  d3, x1
  ins   v0.d[1], v3.d[0]

  mov   v0.s[3], wzr               // w=0 for calc and result

  fmul  v1.4s, v0.4s, v0.4s
  // Sum squares (avoid faddp)
  ext   v2.16b, v1.16b, v1.16b, #8
  fadd  v1.4s, v1.4s, v2.4s
  ext   v2.16b, v1.16b, v1.16b, #4
  fadd  v1.4s, v1.4s, v2.4s
  fsqrt s1, s1

  fmov  s2, wzr
  fcmp  s1, s2
  b.eq  .Lret_norm3

  movz  w3, #0x3f80, lsl #16
  fmov  s2, w3
  fdiv  s1, s2, s1

  fmov  w3, s1
  dup   v1.4s, w3
  fmul  v0.4s, v0.4s, v1.4s

.Lret_norm3:
  umov  x0, v0.d[0]
  umov  x1, v0.d[1]
end;

// === Selection Operation ===

function NEONSelectF32x4(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
var
  LIndex: Integer;
begin
  // Keep explicit per-lane mask semantics here instead of aliasing a scalar
  // helper, so asm-enabled builds do not mis-advertise this slot as a
  // backend-owned NEON implementation while still preserving the API contract.
  for LIndex := 0 to 3 do
    if (mask and (1 shl LIndex)) <> 0 then
      Result.f[LIndex] := a.f[LIndex]
    else
      Result.f[LIndex] := b.f[LIndex];
end;

function NEONInsertF32x4(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4; assembler; nostackframe;
asm
  // ABI: a in x0..x1, value in s0 (v0.s[0]), index in w2, return x0..x1
  fmov  d1, x0
  fmov  d3, x1
  ins   v1.d[1], v3.d[0]

  // Clamp index to [0..3] (saturating semantics)
  cmp   w2, #0
  b.ge  .Lins_clamp_hi_check
  mov   w2, #0
  b     .Lins_clamp_done
.Lins_clamp_hi_check:
  cmp   w2, #3
  b.le  .Lins_clamp_done
  mov   w2, #3
.Lins_clamp_done:

  cbz   w2, .Lins0
  cmp   w2, #1
  b.eq  .Lins1
  cmp   w2, #2
  b.eq  .Lins2
  // index = 3
  ins   v1.s[3], v0.s[0]
  b     .Lins_done

.Lins0:
  ins   v1.s[0], v0.s[0]
  b     .Lins_done
.Lins1:
  ins   v1.s[1], v0.s[0]
  b     .Lins_done
.Lins2:
  ins   v1.s[2], v0.s[0]

.Lins_done:
  umov  x0, v1.d[0]
  umov  x1, v1.d[1]
end;

{$I nextpas.core.simd.neon.reduce.inc}

{$I nextpas.core.simd.neon.memory.inc}

{$I nextpas.core.simd.neon.utility.inc}

{$I nextpas.core.simd.neon.compare.inc}

{$I nextpas.core.simd.neon.facade_asm.inc}

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

{$I nextpas.core.simd.neon.scalar_fallback.inc}

{$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
{$I nextpas.core.simd.neon.shared_utility.inc}
{$ENDIF}
{$I nextpas.core.simd.neon.scalar.autowrap.inc}

{$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
{$I nextpas.core.simd.neon.shared_wide_memory_asm.inc}
{$ENDIF}

{$I nextpas.core.simd.neon.facade_platform.inc}

{$I nextpas.core.simd.neon.dot.inc}

// === Backend Registration ===

{$I nextpas.core.simd.neon.register.inc}


end.
