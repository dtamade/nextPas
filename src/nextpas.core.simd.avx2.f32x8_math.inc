// === F32x8 Math Operations (256-bit AVX) ===

function AVX2AbsF32x8(const a: TVecF32x8): TVecF32x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  // Generate AbsMask dynamically (PIC-safe): 0x7FFFFFFF for each lane
  asm
    mov      rax, pr
    mov      rdx, pa
    vmovups  ymm0, [rdx]
    vpcmpeqd ymm1, ymm1, ymm1  // all 1s
    vpsrld   ymm1, ymm1, 1     // shift right 1 = 0x7FFFFFFF
    vandps   ymm0, ymm0, ymm1
    vmovups  [rax], ymm0
    vzeroupper
  end;
end;

function AVX2SqrtF32x8(const a: TVecF32x8): TVecF32x8;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  asm
    mov     rax, pr
    mov     rdx, pa
    vmovups ymm0, [rdx]
    vsqrtps ymm0, ymm0
    vmovups [rax], ymm0
    vzeroupper
  end;
end;

function AVX2MinF32x8(const a, b: TVecF32x8): TVecF32x8;
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
    vmovups ymm0, [rdx]
    vminps  ymm0, ymm0, [rcx]
    vmovups [rax], ymm0
    vzeroupper
  end;
end;

function AVX2MaxF32x8(const a, b: TVecF32x8): TVecF32x8;
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
    vmovups ymm0, [rdx]
    vmaxps  ymm0, ymm0, [rcx]
    vmovups [rax], ymm0
    vzeroupper
  end;
end;

function AVX2ClampF32x8(const a, minVal, maxVal: TVecF32x8): TVecF32x8;
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
    vmovups ymm0, [rdx]
    vmaxps  ymm0, ymm0, [rcx]   // clamp to min
    vminps  ymm0, ymm0, [r8]    // clamp to max
    vmovups [rax], ymm0
    vzeroupper
  end;
end;

