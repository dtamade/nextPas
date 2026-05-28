// === F64x8 Reduction Operations ===

function AVX512ReduceAddF64x8(const a: TVecF64x8): Double;
var
  pa: Pointer;
begin
  pa := @a;

  asm
    mov     rdx, pa
    vmovupd zmm0, [rdx]
    vextractf64x4 ymm1, zmm0, 1
    vaddpd  ymm0, ymm0, ymm1
    vextractf128 xmm1, ymm0, 1
    vaddpd  xmm0, xmm0, xmm1
    vhaddpd xmm0, xmm0, xmm0
    vmovsd  Result, xmm0
    vzeroupper
  end;
end;

function AVX512ReduceMinF64x8(const a: TVecF64x8): Double;
var
  pa: Pointer;
begin
  pa := @a;

  asm
    mov     rdx, pa
    vmovupd zmm0, [rdx]
    vextractf64x4 ymm1, zmm0, 1
    vminpd  ymm0, ymm0, ymm1
    vextractf128 xmm1, ymm0, 1
    vminpd  xmm0, xmm0, xmm1
    vshufpd xmm1, xmm0, xmm0, 1
    vminpd  xmm0, xmm0, xmm1
    vmovsd  Result, xmm0
    vzeroupper
  end;
end;

function AVX512ReduceMaxF64x8(const a: TVecF64x8): Double;
var
  pa: Pointer;
begin
  pa := @a;

  asm
    mov     rdx, pa
    vmovupd zmm0, [rdx]
    vextractf64x4 ymm1, zmm0, 1
    vmaxpd  ymm0, ymm0, ymm1
    vextractf128 xmm1, ymm0, 1
    vmaxpd  xmm0, xmm0, xmm1
    vshufpd xmm1, xmm0, xmm0, 1
    vmaxpd  xmm0, xmm0, xmm1
    vmovsd  Result, xmm0
    vzeroupper
  end;
end;

function AVX512ReduceMulF64x8(const a: TVecF64x8): Double;
var
  pa: Pointer;
begin
  pa := @a;

  asm
    mov     rdx, pa
    vmovupd zmm0, [rdx]
    vextractf64x4 ymm1, zmm0, 1
    vmulpd  ymm0, ymm0, ymm1
    vextractf128 xmm1, ymm0, 1
    vmulpd  xmm0, xmm0, xmm1
    vshufpd xmm1, xmm0, xmm0, 1
    vmulpd  xmm0, xmm0, xmm1
    vmovsd  Result, xmm0
    vzeroupper
  end;
end;

