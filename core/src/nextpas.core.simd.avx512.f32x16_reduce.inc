// === F32x16 Reduction Operations ===

function AVX512ReduceAddF32x16(const a: TVecF32x16): Single;
var
  pa: Pointer;
begin
  pa := @a;

  asm
    mov     rdx, pa
    vmovups zmm0, [rdx]
    // Extract upper 256 bits and add to lower
    vextractf64x4 ymm1, zmm0, 1
    vaddps  ymm0, ymm0, ymm1
    // Extract upper 128 bits and add to lower
    vextractf128 xmm1, ymm0, 1
    vaddps  xmm0, xmm0, xmm1
    // Horizontal add within 128 bits
    vhaddps xmm0, xmm0, xmm0
    vhaddps xmm0, xmm0, xmm0
    vmovss  Result, xmm0
    vzeroupper
  end;
end;

function AVX512ReduceMinF32x16(const a: TVecF32x16): Single;
var
  pa: Pointer;
begin
  pa := @a;

  asm
    mov     rdx, pa
    vmovups zmm0, [rdx]
    vextractf64x4 ymm1, zmm0, 1
    vminps  ymm0, ymm0, ymm1
    vextractf128 xmm1, ymm0, 1
    vminps  xmm0, xmm0, xmm1
    vshufps xmm1, xmm0, xmm0, $4E  // Swap high/low 64 bits
    vminps  xmm0, xmm0, xmm1
    vshufps xmm1, xmm0, xmm0, $B1  // Swap adjacent pairs
    vminps  xmm0, xmm0, xmm1
    vmovss  Result, xmm0
    vzeroupper
  end;
end;

function AVX512ReduceMaxF32x16(const a: TVecF32x16): Single;
var
  pa: Pointer;
begin
  pa := @a;

  asm
    mov     rdx, pa
    vmovups zmm0, [rdx]
    vextractf64x4 ymm1, zmm0, 1
    vmaxps  ymm0, ymm0, ymm1
    vextractf128 xmm1, ymm0, 1
    vmaxps  xmm0, xmm0, xmm1
    vshufps xmm1, xmm0, xmm0, $4E
    vmaxps  xmm0, xmm0, xmm1
    vshufps xmm1, xmm0, xmm0, $B1
    vmaxps  xmm0, xmm0, xmm1
    vmovss  Result, xmm0
    vzeroupper
  end;
end;

function AVX512ReduceMulF32x16(const a: TVecF32x16): Single;
var
  pa: Pointer;
begin
  pa := @a;

  asm
    mov     rdx, pa
    vmovups zmm0, [rdx]
    vextractf64x4 ymm1, zmm0, 1
    vmulps  ymm0, ymm0, ymm1
    vextractf128 xmm1, ymm0, 1
    vmulps  xmm0, xmm0, xmm1
    vshufps xmm1, xmm0, xmm0, $4E
    vmulps  xmm0, xmm0, xmm1
    vshufps xmm1, xmm0, xmm0, $B1
    vmulps  xmm0, xmm0, xmm1
    vmovss  Result, xmm0
    vzeroupper
  end;
end;

