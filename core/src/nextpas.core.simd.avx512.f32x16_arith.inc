// === F32x16 Arithmetic Operations (512-bit) ===

function AVX512AddF32x16(const a, b: TVecF32x16): TVecF32x16;
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
    vaddps  zmm0, zmm0, [rcx]
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SubF32x16(const a, b: TVecF32x16): TVecF32x16;
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
    vsubps  zmm0, zmm0, [rcx]
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MulF32x16(const a, b: TVecF32x16): TVecF32x16;
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
    vmulps  zmm0, zmm0, [rcx]
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512DivF32x16(const a, b: TVecF32x16): TVecF32x16;
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
    vdivps  zmm0, zmm0, [rcx]
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

