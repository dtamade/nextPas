unit nextpas.core.simd.ssse3;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}
{$asmmode intel}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.backend.priority;

// === SSSE3 Backend Implementation ===
// Provides SIMD-accelerated operations using x86-64 SSSE3 instructions.
// SSSE3 (Supplemental SSE3) adds powerful byte manipulation and integer ops.
//
// Key SSSE3 instructions:
// - PSHUFB: Byte-level shuffle (arbitrary permutation of 16 bytes)
// - PALIGNR: Concatenate and extract aligned bytes
// - PHADDW/D, PHSUBW/D: Horizontal add/sub for integers
// - PABSB/W/D: Absolute value for integers (vectorized)
// - PSIGNB/W/D: Conditional negate based on sign
// - PMADDUBSW: Multiply-add (unsigned/signed byte to word)
// - PMULHRSW: Multiply high with rounding and scaling
//
// Enhanced SSSE3 implementation
// - Inherits from SSE3 via CloneDispatchTable
// - PABSD for integer absolute value (very useful!)
// - PSHUFB for byte-level operations
// - PHADD for faster integer reductions

procedure RegisterSSSE3Backend;

// === SSSE3 Exported Functions ===
// SSSE3 adds direct helpers (PSHUFB, PALIGNR, PABS, PSIGN, PHADD), but the
// representative Min/Max dispatch slots intentionally keep inheriting the
// SSE3/SSE2 chain because SSSE3 does not provide a better override.

// Byte-level shuffle (PSHUFB - extremely powerful)
function SSSE3ShuffleBytes(const a, ctrl: TVecU8x16): TVecU8x16;

// Byte alignment (PALIGNR)
function SSSE3AlignR_0(const a, b: TVecU8x16): TVecU8x16;
function SSSE3AlignR_4(const a, b: TVecU8x16): TVecU8x16;
function SSSE3AlignR_8(const a, b: TVecU8x16): TVecU8x16;
function SSSE3AlignR_12(const a, b: TVecU8x16): TVecU8x16;

// Integer horizontal add/sub
function SSSE3HAddI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSSE3HAddI32x4(const a, b: TVecI32x4): TVecI32x4;
function SSSE3HSubI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSSE3HSubI32x4(const a, b: TVecI32x4): TVecI32x4;
function SSSE3HAddSatI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSSE3HSubSatI16x8(const a, b: TVecI16x8): TVecI16x8;

// Integer absolute value (PABS - no equivalent in SSE2!)
function SSSE3AbsI8x16(const a: TVecI8x16): TVecI8x16;
function SSSE3AbsI16x8(const a: TVecI16x8): TVecI16x8;
function SSSE3AbsI32x4(const a: TVecI32x4): TVecI32x4;

// Conditional negate (PSIGN)
function SSSE3SignI8x16(const a, b: TVecI8x16): TVecI8x16;
function SSSE3SignI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSSE3SignI32x4(const a, b: TVecI32x4): TVecI32x4;

// Multiply-add operations
function SSSE3MAddUBSW(const a: TVecU8x16; const b: TVecI8x16): TVecI16x8;
function SSSE3MulHRS(const a, b: TVecI16x8): TVecI16x8;

implementation

uses
  SysUtils,
  nextpas.core.simd.sse2,
  nextpas.core.simd.sse3,
  nextpas.core.simd.cpuinfo;

// === SSSE3 Byte Shuffle ===
// PSHUFB is one of the most powerful SIMD instructions

// Shuffle bytes according to control mask
// Each byte in 'ctrl' selects which byte from 'a' to output
// If high bit of ctrl[i] is set, output is 0
function SSSE3ShuffleBytes(const a, ctrl: TVecU8x16): TVecU8x16;
begin
  asm
    lea    rax, a
    lea    rdx, ctrl
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pshufb xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

// === SSSE3 Alignment ===

// Concatenate a and b, then extract 16 bytes at byte offset
// Result = (b:a >> (imm8*8)) [lower 128 bits]
// Note: imm8 is compile-time constant in x86, so we provide variants
function SSSE3AlignR_0(const a, b: TVecU8x16): TVecU8x16;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    palignr xmm1, xmm0, 0
    movdqu [result], xmm1
  end;
end;

function SSSE3AlignR_4(const a, b: TVecU8x16): TVecU8x16;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    palignr xmm1, xmm0, 4
    movdqu [result], xmm1
  end;
end;

function SSSE3AlignR_8(const a, b: TVecU8x16): TVecU8x16;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    palignr xmm1, xmm0, 8
    movdqu [result], xmm1
  end;
end;

function SSSE3AlignR_12(const a, b: TVecU8x16): TVecU8x16;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    palignr xmm1, xmm0, 12
    movdqu [result], xmm1
  end;
end;

// === SSSE3 Horizontal Integer Operations ===

// Horizontal add for I16x8: [a0+a1, a2+a3, a4+a5, a6+a7, b0+b1, ...]
function SSSE3HAddI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    phaddw xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

// Horizontal add for I32x4: [a0+a1, a2+a3, b0+b1, b2+b3]
function SSSE3HAddI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    phaddd xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

// Horizontal sub for I16x8
function SSSE3HSubI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    phsubw xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

// Horizontal sub for I32x4
function SSSE3HSubI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    phsubd xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

// Horizontal add with saturation for I16x8
function SSSE3HAddSatI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    phaddsw xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

// Horizontal sub with saturation for I16x8
function SSSE3HSubSatI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    phsubsw xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

// === SSSE3 Absolute Value ===
// SSE2 requires compare+select to compute abs; SSSE3 has direct instructions

function SSSE3AbsI8x16(const a: TVecI8x16): TVecI8x16;
begin
  asm
    lea    rax, a
    movdqu xmm0, [rax]
    pabsb  xmm0, xmm0
    movdqu [result], xmm0
  end;
end;

function SSSE3AbsI16x8(const a: TVecI16x8): TVecI16x8;
begin
  asm
    lea    rax, a
    movdqu xmm0, [rax]
    pabsw  xmm0, xmm0
    movdqu [result], xmm0
  end;
end;

function SSSE3AbsI32x4(const a: TVecI32x4): TVecI32x4;
begin
  asm
    lea    rax, a
    movdqu xmm0, [rax]
    pabsd  xmm0, xmm0
    movdqu [result], xmm0
  end;
end;

// === SSSE3 Conditional Negate ===
// PSIGN: Negate based on sign of second operand

// For each element: if b[i] < 0 then -a[i], if b[i] == 0 then 0, else a[i]
function SSSE3SignI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    psignb xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

function SSSE3SignI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    psignw xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

function SSSE3SignI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    psignd xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

// === SSSE3 Multiply-Add ===

// PMADDUBSW: Multiply unsigned bytes with signed bytes, add pairs with saturation
// a[2i]*b[2i] + a[2i+1]*b[2i+1] (saturated to I16)
function SSSE3MAddUBSW(const a: TVecU8x16; const b: TVecI8x16): TVecI16x8;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pmaddubsw xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

// PMULHRSW: Multiply signed words, shift right 14, round and pack
function SSSE3MulHRS(const a, b: TVecI16x8): TVecI16x8;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pmulhrsw xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

// === SSSE3 Integer Reduction using PHADD ===

function SSSE3ReduceAddI32x4(const a: TVecI32x4): Int32;
begin
  asm
    lea     rax, a
    movdqu  xmm0, [rax]
    phaddd  xmm0, xmm0     // [a0+a1, a2+a3, a0+a1, a2+a3]
    phaddd  xmm0, xmm0     // [sum, sum, sum, sum]
    movd    eax, xmm0
    mov     [result], eax
  end;
end;

function SSSE3ReduceAddI16x8(const a: TVecI16x8): Int32;
var
  tmp: TVecI16x8;
begin
  asm
    lea     rax, a
    movdqu  xmm0, [rax]
    phaddw  xmm0, xmm0     // [a0+a1, a2+a3, a4+a5, a6+a7, ...]
    phaddw  xmm0, xmm0     // [sum0, sum1, sum0, sum1, ...]
    phaddw  xmm0, xmm0     // [total, ...]
    movdqu  [tmp], xmm0
  end;
  Result := tmp.i[0];
end;

// SSSE3 byte-level negate using PABSB + PSIGNB pattern
function SSSE3NegI8x16(const a: TVecI8x16): TVecI8x16;
begin
  asm
    lea    rax, a
    movdqu xmm0, [rax]
    // Create all -1s
    pcmpeqd xmm1, xmm1
    // psignb(a, -1) = -a when sign bit set
    psignb xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

function SSSE3NegI16x8(const a: TVecI16x8): TVecI16x8;
begin
  asm
    lea    rax, a
    movdqu xmm0, [rax]
    pcmpeqd xmm1, xmm1
    psignw xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

function SSSE3NegI32x4(const a: TVecI32x4): TVecI32x4;
begin
  asm
    lea    rax, a
    movdqu xmm0, [rax]
    pcmpeqd xmm1, xmm1
    psignd xmm0, xmm1
    movdqu [result], xmm0
  end;
end;

// Compatibility direct wrappers. SSSE3 has no PMINSB/PMAXSB equivalent;
// SSE4.1 is the first x86 tier with native signed-byte Min/Max.
function SSSE3MinI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := SSE2MinI8x16(a, b);
end;

function SSSE3MaxI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := SSE2MaxI8x16(a, b);
end;

// === Backend Registration ===

{$I nextpas.core.simd.ssse3.register.inc}


end.
