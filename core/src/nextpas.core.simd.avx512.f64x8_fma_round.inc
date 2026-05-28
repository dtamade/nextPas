// === F64x8 FMA and Rounding Operations ===

function AVX512FmaF64x8(const a, b, c: TVecF64x8): TVecF64x8;
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
    vmovupd zmm0, [rdx]
    vmovupd zmm1, [rcx]
    vmovupd zmm2, [r8]
    vfmadd213pd zmm0, zmm1, zmm2
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512FloorF64x8(const a: TVecF64x8): TVecF64x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovupd zmm0, [rdx]
    vrndscalepd zmm0, zmm0, 1
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512CeilF64x8(const a: TVecF64x8): TVecF64x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovupd zmm0, [rdx]
    vrndscalepd zmm0, zmm0, 2
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512RoundF64x8(const a: TVecF64x8): TVecF64x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovupd zmm0, [rdx]
    vrndscalepd zmm0, zmm0, 0
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512TruncF64x8(const a: TVecF64x8): TVecF64x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovupd zmm0, [rdx]
    vrndscalepd zmm0, zmm0, 3
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

