// === F64x8 Arithmetic Operations (512-bit) ===

function AVX512AddF64x8(const a, b: TVecF64x8): TVecF64x8;
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
    vmovupd zmm0, [rdx]
    vaddpd  zmm0, zmm0, [rcx]
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SubF64x8(const a, b: TVecF64x8): TVecF64x8;
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
    vmovupd zmm0, [rdx]
    vsubpd  zmm0, zmm0, [rcx]
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MulF64x8(const a, b: TVecF64x8): TVecF64x8;
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
    vmovupd zmm0, [rdx]
    vmulpd  zmm0, zmm0, [rcx]
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512DivF64x8(const a, b: TVecF64x8): TVecF64x8;
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
    vmovupd zmm0, [rdx]
    vdivpd  zmm0, zmm0, [rcx]
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

