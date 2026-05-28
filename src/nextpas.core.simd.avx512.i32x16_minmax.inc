// === I32x16 Min/Max Operations ===

function AVX512MinI32x16(const a, b: TVecI32x16): TVecI32x16;
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
    vpminsd zmm0, zmm0, [rcx]   // Signed min
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MaxI32x16(const a, b: TVecI32x16): TVecI32x16;
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
    vpmaxsd zmm0, zmm0, [rcx]   // Signed max
    vmovdqu64 [rax], zmm0
    vzeroupper
  end;
end;

