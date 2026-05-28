// === F64x8 Math Functions ===

function AVX512AbsF64x8(const a: TVecF64x8): TVecF64x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  // Abs by clearing sign bit: AND with 0x7FFFFFFFFFFFFFFF
  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, $7FFFFFFFFFFFFFFF
    vpbroadcastq zmm1, rcx
    vmovupd zmm0, [rdx]
    vpandq  zmm0, zmm0, zmm1
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512SqrtF64x8(const a: TVecF64x8): TVecF64x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;

  asm
    mov     rax, pr
    mov     rdx, pa
    vmovupd zmm0, [rdx]
    vsqrtpd zmm0, zmm0
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MinF64x8(const a, b: TVecF64x8): TVecF64x8;
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
    vminpd  zmm0, zmm0, [rcx]
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512MaxF64x8(const a, b: TVecF64x8): TVecF64x8;
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
    vmaxpd  zmm0, zmm0, [rcx]
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

function AVX512ClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8;
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
    vmovupd zmm0, [rdx]
    vmaxpd  zmm0, zmm0, [rcx]
    vminpd  zmm0, zmm0, [r8]
    vmovupd [rax], zmm0
    vzeroupper
  end;
end;

