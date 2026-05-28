// === F64x4 Reduction Operations (256-bit AVX) ===

function AVX2ReduceAddF64x4(const a: TVecF64x4): Double;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov      rdx, pa
    vmovupd  ymm0, [rdx]
    // 256->128: extract high 128 and add to low 128
    vextractf128 xmm1, ymm0, 1
    vaddpd   xmm0, xmm0, xmm1
    // 128->64: horizontal add
    vhaddpd  xmm0, xmm0, xmm0
    vmovsd   [result], xmm0
    vzeroupper
  end;
end;

function AVX2ReduceMinF64x4(const a: TVecF64x4): Double;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov      rdx, pa
    vmovupd  ymm0, [rdx]
    // 256->128: extract high 128 and min with low 128
    vextractf128 xmm1, ymm0, 1
    vminpd   xmm0, xmm0, xmm1
    // 128->64: shuffle and min
    vshufpd  xmm1, xmm0, xmm0, 1  // swap elements
    vminsd   xmm0, xmm0, xmm1
    vmovsd   [result], xmm0
    vzeroupper
  end;
end;

function AVX2ReduceMaxF64x4(const a: TVecF64x4): Double;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov      rdx, pa
    vmovupd  ymm0, [rdx]
    // 256->128: extract high 128 and max with low 128
    vextractf128 xmm1, ymm0, 1
    vmaxpd   xmm0, xmm0, xmm1
    // 128->64: shuffle and max
    vshufpd  xmm1, xmm0, xmm0, 1
    vmaxsd   xmm0, xmm0, xmm1
    vmovsd   [result], xmm0
    vzeroupper
  end;
end;

function AVX2ReduceMulF64x4(const a: TVecF64x4): Double;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov      rdx, pa
    vmovupd  ymm0, [rdx]
    // 256->128: extract high 128 and mul with low 128
    vextractf128 xmm1, ymm0, 1
    vmulpd   xmm0, xmm0, xmm1
    // 128->64: shuffle and mul
    vshufpd  xmm1, xmm0, xmm0, 1
    vmulsd   xmm0, xmm0, xmm1
    vmovsd   [result], xmm0
    vzeroupper
  end;
end;

