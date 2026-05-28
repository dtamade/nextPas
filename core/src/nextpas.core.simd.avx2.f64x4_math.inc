// === F64x4 Math Operations (256-bit AVX) ===

function AVX2AbsF64x4(const a: TVecF64x4): TVecF64x4;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  // Generate AbsMask dynamically (PIC-safe): 0x7FFFFFFFFFFFFFFF for each lane
  asm
    mov      rax, pr
    mov      rdx, pa
    vmovupd  ymm0, [rdx]
    vpcmpeqd ymm1, ymm1, ymm1  // all 1s
    vpsrlq   ymm1, ymm1, 1     // shift right 1 = 0x7FFFFFFFFFFFFFFF
    vandpd   ymm0, ymm0, ymm1
    vmovupd  [rax], ymm0
    vzeroupper
  end;
end;

function AVX2SqrtF64x4(const a: TVecF64x4): TVecF64x4;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  asm
    mov     rax, pr
    mov     rdx, pa
    vmovupd ymm0, [rdx]
    vsqrtpd ymm0, ymm0
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

function AVX2MinF64x4(const a, b: TVecF64x4): TVecF64x4;
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
    vminpd  ymm0, ymm0, [rcx]
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

function AVX2MaxF64x4(const a, b: TVecF64x4): TVecF64x4;
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
    vmaxpd  ymm0, ymm0, [rcx]
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

function AVX2ClampF64x4(const a, minVal, maxVal: TVecF64x4): TVecF64x4;
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
    vmovupd ymm0, [rdx]
    vmaxpd  ymm0, ymm0, [rcx]   // clamp to min
    vminpd  ymm0, ymm0, [r8]    // clamp to max
    vmovupd [rax], ymm0
    vzeroupper
  end;
end;

