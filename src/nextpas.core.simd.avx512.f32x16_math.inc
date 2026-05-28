// === F32x16 Math Functions ===

function AVX512AbsF32x16(const a: TVecF32x16): TVecF32x16;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  // Abs by clearing sign bit: AND with 0x7FFFFFFF
  asm
    mov     rax, pr
    mov     rdx, pa
    mov     ecx, $7FFFFFFF
    vpbroadcastd zmm1, ecx
    vmovups zmm0, [rdx]
    vpandd  zmm0, zmm0, zmm1
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SqrtF32x16(const a: TVecF32x16): TVecF32x16;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovups zmm0, [rdx]
    vsqrtps zmm0, zmm0
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MinF32x16(const a, b: TVecF32x16): TVecF32x16;
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
    vmovups zmm0, [rdx]
    vminps  zmm0, zmm0, [rcx]
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MaxF32x16(const a, b: TVecF32x16): TVecF32x16;
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
    vmovups zmm0, [rdx]
    vmaxps  zmm0, zmm0, [rcx]
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ClampF32x16(const a, minVal, maxVal: TVecF32x16): TVecF32x16;
var
  pa, pmin, pmax, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  pmin := @minVal;
  pmax := @maxVal;

  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pmin
    mov     r8, pmax
    vmovups zmm0, [rdx]
    vmaxps  zmm0, zmm0, [rcx]    // max(a, minVal)
    vminps  zmm0, zmm0, [r8]     // min(result, maxVal)
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

