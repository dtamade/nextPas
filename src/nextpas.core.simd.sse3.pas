unit nextpas.core.simd.sse3;

{$mode objfpc}
{$I nextpas.core.settings.inc}
{$asmmode intel}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.backend.priority;

// === SSE3 Backend Implementation ===
// Provides SIMD-accelerated operations using x86-64 SSE3 instructions.
// SSE3 (Prescott New Instructions) adds horizontal operations for faster reductions.
//
// Key SSE3 instructions:
// - HADDPS/HSUBPS: Horizontal add/sub for F32 (faster reductions)
// - HADDPD/HSUBPD: Horizontal add/sub for F64
// - MOVDDUP: Duplicate low F64 to both lanes
// - MOVSLDUP/MOVSHDUP: Duplicate even/odd F32 elements
// - LDDQU: Optimized unaligned load for cache-line crossing
// - ADDSUBPS/ADDSUBPD: Alternating add/sub (useful for complex arithmetic)
//
// Enhanced SSE3 implementation with tier inheritance
// - Inherits from SSE2 via CloneDispatchTable
// - Optimizes: ReduceAddF32x4, ReduceAddF64x2, DotF32x4, LengthF32x4, etc.

procedure RegisterSSE3Backend;

// === SSE3 Exported Functions ===
// These can be used directly for specialized operations

// Horizontal operations (new in SSE3)
function SSE3HAddF32x4(const a, b: TVecF32x4): TVecF32x4;
function SSE3HSubF32x4(const a, b: TVecF32x4): TVecF32x4;
function SSE3HAddF64x2(const a, b: TVecF64x2): TVecF64x2;
function SSE3HSubF64x2(const a, b: TVecF64x2): TVecF64x2;

// Alternating add/sub (useful for complex arithmetic)
function SSE3AddSubF32x4(const a, b: TVecF32x4): TVecF32x4;
function SSE3AddSubF64x2(const a, b: TVecF64x2): TVecF64x2;

// Data movement
function SSE3MovDupF64x2(const a: TVecF64x2): TVecF64x2;
function SSE3MovSLDupF32x4(const a: TVecF32x4): TVecF32x4;
function SSE3MovSHDupF32x4(const a: TVecF32x4): TVecF32x4;

// Reduction operations (optimized with HADD)
function SSE3ReduceAddF32x4(const a: TVecF32x4): Single;
function SSE3ReduceAddF64x2(const a: TVecF64x2): Double;
function SSE3ReduceMulF32x4(const a: TVecF32x4): Single;
function SSE3ReduceMulF64x2(const a: TVecF64x2): Double;

// Dot product (optimized with HADD)
function SSE3DotF32x4(const a, b: TVecF32x4): Single;
function SSE3DotF32x3(const a, b: TVecF32x4): Single;

// Length (optimized with HADD)
function SSE3LengthF32x4(const a: TVecF32x4): Single;
function SSE3LengthF32x3(const a: TVecF32x4): Single;

// Normalize (optimized with HADD)
function SSE3NormalizeF32x4(const a: TVecF32x4): TVecF32x4;
function SSE3NormalizeF32x3(const a: TVecF32x4): TVecF32x4;

implementation

uses
  SysUtils,
  nextpas.core.simd.cpuinfo;

// === SSE3 Horizontal Arithmetic ===
// These operations are the main benefit of SSE3 over SSE2

// Horizontal add: [a0+a1, a2+a3, b0+b1, b2+b3]
function SSE3HAddF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movups xmm0, [rax]
    movups xmm1, [rdx]
    haddps xmm0, xmm1
    movups [result], xmm0
  end;
end;

// Horizontal sub: [a0-a1, a2-a3, b0-b1, b2-b3]
function SSE3HSubF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movups xmm0, [rax]
    movups xmm1, [rdx]
    hsubps xmm0, xmm1
    movups [result], xmm0
  end;
end;

// Horizontal add for F64: [a0+a1, b0+b1]
function SSE3HAddF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    haddpd xmm0, xmm1
    movupd [result], xmm0
  end;
end;

// Horizontal sub for F64: [a0-a1, b0-b1]
function SSE3HSubF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    hsubpd xmm0, xmm1
    movupd [result], xmm0
  end;
end;

// === SSE3 Optimized Reductions ===
// SSE3's HADD makes horizontal reductions more efficient

// Sum all 4 floats using SSE3 horizontal add (faster than SSE2 shuffle method)
function SSE3ReduceAddF32x4(const a: TVecF32x4): Single;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov     rax, pa
    movups  xmm0, [rax]
    haddps  xmm0, xmm0     // [a0+a1, a2+a3, a0+a1, a2+a3]
    haddps  xmm0, xmm0     // [sum, sum, sum, sum]
    movss   [result], xmm0
  end;
end;

// Sum both doubles using SSE3 horizontal add
function SSE3ReduceAddF64x2(const a: TVecF64x2): Double;
begin
  asm
    lea     rax, a
    movupd  xmm0, [rax]
    haddpd  xmm0, xmm0     // [a0+a1, a0+a1]
    movlpd  [result], xmm0
  end;
end;

// Multiply reduction using HADD
function SSE3ReduceMulF32x4(const a: TVecF32x4): Single;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov     rax, pa
    movups  xmm0, [rax]
    // Multiply pairs: [a0*a2, a1*a3, ...]
    movaps  xmm1, xmm0
    shufps  xmm1, xmm0, $B1  // [a1, a0, a3, a2]
    mulps   xmm0, xmm1       // [a0*a1, a0*a1, a2*a3, a2*a3]
    movaps  xmm1, xmm0
    shufps  xmm1, xmm0, $4E  // [a2*a3, a2*a3, a0*a1, a0*a1]
    mulps   xmm0, xmm1       // Final product in all lanes
    movss   [result], xmm0
  end;
end;

// F64x2 multiplication reduction
function SSE3ReduceMulF64x2(const a: TVecF64x2): Double;
begin
  asm
    lea     rax, a
    movupd  xmm0, [rax]
    movapd  xmm1, xmm0
    shufpd  xmm1, xmm0, 1    // [a1, a0]
    mulpd   xmm0, xmm1       // [a0*a1, a0*a1]
    movlpd  [result], xmm0
  end;
end;

// === SSE3 Alternating Operations ===
// Useful for complex number arithmetic

// Alternating add/sub: [a0-b0, a1+b1, a2-b2, a3+b3]
function SSE3AddSubF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movups xmm0, [rax]
    movups xmm1, [rdx]
    addsubps xmm0, xmm1
    movups [result], xmm0
  end;
end;

// Alternating add/sub for F64: [a0-b0, a1+b1]
function SSE3AddSubF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  asm
    lea    rax, a
    lea    rdx, b
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    addsubpd xmm0, xmm1
    movupd [result], xmm0
  end;
end;

// === SSE3 Data Movement ===

// Duplicate low double to both lanes: [a0, a0]
function SSE3MovDupF64x2(const a: TVecF64x2): TVecF64x2;
begin
  asm
    lea    rax, a
    movddup xmm0, [rax]
    movupd [result], xmm0
  end;
end;

// Duplicate even elements: [a0, a0, a2, a2]
function SSE3MovSLDupF32x4(const a: TVecF32x4): TVecF32x4;
begin
  asm
    lea    rax, a
    movsldup xmm0, [rax]
    movups [result], xmm0
  end;
end;

// Duplicate odd elements: [a1, a1, a3, a3]
function SSE3MovSHDupF32x4(const a: TVecF32x4): TVecF32x4;
begin
  asm
    lea    rax, a
    movshdup xmm0, [rax]
    movups [result], xmm0
  end;
end;

// === SSE3 Optimized Dot Product ===
// Using HADD for final reduction

function SSE3DotF32x4(const a, b: TVecF32x4): Single;
var
  pa, pb: Pointer;
begin
  pa := @a;
  pb := @b;
  asm
    mov     rax, pa
    mov     rdx, pb
    movups  xmm0, [rax]
    movups  xmm1, [rdx]
    mulps   xmm0, xmm1      // Element-wise multiply
    haddps  xmm0, xmm0      // [a0*b0+a1*b1, a2*b2+a3*b3, ...]
    haddps  xmm0, xmm0      // [sum, sum, sum, sum]
    movss   [result], xmm0
  end;
end;

function SSE3DotF32x3(const a, b: TVecF32x4): Single;
begin
  // SSE3-safe implementation: mask off W lane, then use HADD reduction.
  asm
    lea     rax, a
    lea     rdx, b
    movups  xmm0, [rax]
    movups  xmm1, [rdx]
    mulps   xmm0, xmm1

    // Zero w by clearing the high 32-bit lane.
    pcmpeqd xmm2, xmm2
    psrldq  xmm2, 4           // Mask: [FF, FF, FF, 00]
    andps   xmm0, xmm2

    haddps  xmm0, xmm0
    haddps  xmm0, xmm0
    movss   [result], xmm0
  end;
end;

// === SSE3 Optimized Length ===

function SSE3LengthWithOptionalZeroW(const a: TVecF32x4; aZeroW: Boolean): Single; inline;
var
  LPA: Pointer;
begin
  LPA := @a;
  if aZeroW then
  begin
    asm
      mov     rax, LPA
      movups  xmm0, [rax]
      pcmpeqd xmm2, xmm2
      psrldq  xmm2, 4
      andps   xmm0, xmm2

      mulps   xmm0, xmm0      // Square each element
      haddps  xmm0, xmm0      // Sum pairs
      haddps  xmm0, xmm0      // Sum all
      sqrtss  xmm0, xmm0      // Square root
      movss   [result], xmm0
    end;
  end
  else
  begin
    asm
      mov     rax, LPA
      movups  xmm0, [rax]
      mulps   xmm0, xmm0      // Square each element
      haddps  xmm0, xmm0      // Sum pairs
      haddps  xmm0, xmm0      // Sum all
      sqrtss  xmm0, xmm0      // Square root
      movss   [result], xmm0
    end;
  end;
end;

function SSE3NormalizeByLength(const a: TVecF32x4; const aLen: Single; aZeroW: Boolean): TVecF32x4; inline;
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
      movups  xmm0, [rax]
      movss   xmm1, aLen
      shufps  xmm1, xmm1, 0
      divps   xmm0, xmm1
      movups  [rcx], xmm0
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

function SSE3LengthF32x4(const a: TVecF32x4): Single;
begin
  Result := SSE3LengthWithOptionalZeroW(a, False);
end;

function SSE3LengthF32x3(const a: TVecF32x4): Single;
begin
  Result := SSE3LengthWithOptionalZeroW(a, True);
end;

// SSE3 Optimized Normalize
function SSE3NormalizeF32x4(const a: TVecF32x4): TVecF32x4;
var
  LLen: Single;
begin
  LLen := SSE3LengthWithOptionalZeroW(a, False);
  Result := SSE3NormalizeByLength(a, LLen, False);
end;

function SSE3NormalizeF32x3(const a: TVecF32x4): TVecF32x4;
var
  LLen: Single;
begin
  LLen := SSE3LengthWithOptionalZeroW(a, True);
  Result := SSE3NormalizeByLength(a, LLen, True);
end;

// === Backend Registration ===

{$I nextpas.core.simd.sse3.register.inc}


end.
