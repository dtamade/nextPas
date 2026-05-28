// === I32x16 Arithmetic Operations (512-bit) ===

function AVX512AddI32x16(const a, b: TVecI32x16): TVecI32x16;
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
    vmovdqu64 zmm0, [rdx]
    vpaddd  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SubI32x16(const a, b: TVecI32x16): TVecI32x16;
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
    vmovdqu64 zmm0, [rdx]
    vpsubd  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MulI32x16(const a, b: TVecI32x16): TVecI32x16;
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
    vmovdqu64 zmm0, [rdx]
    vpmulld zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

