// === F64x4 Operations (native 256-bit AVX) ===

function AVX2AddF64x4(const a, b: TVecF64x4): TVecF64x4;
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
    vmovupd ymm0, [rdx]
    vaddpd  ymm0, ymm0, [rcx]
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

function AVX2SubF64x4(const a, b: TVecF64x4): TVecF64x4;
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
    vmovupd ymm0, [rdx]
    vsubpd  ymm0, ymm0, [rcx]
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

function AVX2MulF64x4(const a, b: TVecF64x4): TVecF64x4;
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
    vmovupd ymm0, [rdx]
    vmulpd  ymm0, ymm0, [rcx]
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

function AVX2DivF64x4(const a, b: TVecF64x4): TVecF64x4;
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
    vmovupd ymm0, [rdx]
    vdivpd  ymm0, ymm0, [rcx]
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

