// === I64x8 Arithmetic Operations (512-bit) ===

function AVX512AddI64x8(const a, b: TVecI64x8): TVecI64x8;
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
    vpaddq  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SubI64x8(const a, b: TVecI64x8): TVecI64x8;
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
    vpsubq  zmm0, zmm0, [rcx]
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

