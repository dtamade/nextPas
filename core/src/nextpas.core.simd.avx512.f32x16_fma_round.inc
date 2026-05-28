// === F32x16 FMA and Rounding Operations ===

function AVX512FmaF32x16(const a, b, c: TVecF32x16): TVecF32x16;
var
  pa, pb, pc, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  pb := @b;
  pc := @c;

  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    mov     r8, pc
    vmovups zmm0, [rdx]
    vmovups zmm1, [rcx]
    vmovups zmm2, [r8]
    vfmadd213ps zmm0, zmm1, zmm2   // a*b+c
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512FloorF32x16(const a: TVecF32x16): TVecF32x16;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovups zmm0, [rdx]
    vrndscaleps zmm0, zmm0, 1    // imm8=1: floor (round toward -inf)
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512CeilF32x16(const a: TVecF32x16): TVecF32x16;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovups zmm0, [rdx]
    vrndscaleps zmm0, zmm0, 2    // imm8=2: ceil (round toward +inf)
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512RoundF32x16(const a: TVecF32x16): TVecF32x16;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovups zmm0, [rdx]
    vrndscaleps zmm0, zmm0, 0    // imm8=0: round to nearest even
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

function AVX512TruncF32x16(const a: TVecF32x16): TVecF32x16;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovups zmm0, [rdx]
    vrndscaleps zmm0, zmm0, 3    // imm8=3: truncate (round toward zero)
    vmovups [rax], zmm0
    vzeroupper
  end;
end;

