// === F32x8 Reduction Operations (256-bit AVX) ===

function AVX2ReduceAddF32x8(const a: TVecF32x8): Single;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov      rdx, pa
    vmovups  ymm0, [rdx]
    // 256->128: extract high 128 and add to low 128
    vextractf128 xmm1, ymm0, 1
    vaddps   xmm0, xmm0, xmm1
    // 128->64: horizontal add
    vhaddps  xmm0, xmm0, xmm0
    // 64->32: horizontal add again
    vhaddps  xmm0, xmm0, xmm0
    vmovss   [result], xmm0
    vzeroupper
  end;
end;

function AVX2ReduceMinF32x8(const a: TVecF32x8): Single;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov      rdx, pa
    vmovups  ymm0, [rdx]
    // 256->128: extract high 128 and min with low 128
    vextractf128 xmm1, ymm0, 1
    vminps   xmm0, xmm0, xmm1
    // 128->64: shuffle and min
    vshufps  xmm1, xmm0, xmm0, $4E  // swap high/low 64-bit pairs
    vminps   xmm0, xmm0, xmm1
    // 64->32: shuffle and min
    vshufps  xmm1, xmm0, xmm0, $B1  // swap adjacent 32-bit elements
    vminss   xmm0, xmm0, xmm1
    vmovss   [result], xmm0
    vzeroupper
  end;
end;

function AVX2ReduceMaxF32x8(const a: TVecF32x8): Single;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov      rdx, pa
    vmovups  ymm0, [rdx]
    // 256->128: extract high 128 and max with low 128
    vextractf128 xmm1, ymm0, 1
    vmaxps   xmm0, xmm0, xmm1
    // 128->64: shuffle and max
    vshufps  xmm1, xmm0, xmm0, $4E
    vmaxps   xmm0, xmm0, xmm1
    // 64->32: shuffle and max
    vshufps  xmm1, xmm0, xmm0, $B1
    vmaxss   xmm0, xmm0, xmm1
    vmovss   [result], xmm0
    vzeroupper
  end;
end;

function AVX2ReduceMulF32x8(const a: TVecF32x8): Single;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov      rdx, pa
    vmovups  ymm0, [rdx]
    // 256->128: extract high 128 and mul with low 128
    vextractf128 xmm1, ymm0, 1
    vmulps   xmm0, xmm0, xmm1
    // 128->64: shuffle and mul
    vshufps  xmm1, xmm0, xmm0, $4E
    vmulps   xmm0, xmm0, xmm1
    // 64->32: shuffle and mul
    vshufps  xmm1, xmm0, xmm0, $B1
    vmulss   xmm0, xmm0, xmm1
    vmovss   [result], xmm0
    vzeroupper
  end;
end;

