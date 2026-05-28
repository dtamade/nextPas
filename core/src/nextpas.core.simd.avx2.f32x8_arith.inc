// === F32x8 Operations (native 256-bit AVX) ===

function AVX2AddF32x8(const a, b: TVecF32x8): TVecF32x8;
var
  pa, pb, pr: Pointer;
begin
  // 注意：FPC 对 32-byte record 的传参与返回值可能走 hidden pointer 约定。
  // 直接在 asm 中用 [a]/[result] 容易把指针槽当作数据块，导致栈/堆被写坏。
  pr := @Result;
  pa := @a;
  pb := @b;

  asm
    mov     rax, pr
    mov     rdx, pa
    mov     rcx, pb
    vmovups ymm0, [rdx]
    vaddps  ymm0, ymm0, [rcx]
    vmovups [rax], ymm0
    vzeroupper
  end;
end;

function AVX2SubF32x8(const a, b: TVecF32x8): TVecF32x8;
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
    vsubps  ymm0, ymm0, [rcx]
    vmovups [rax], ymm0
    vzeroupper
  end;
end;

function AVX2MulF32x8(const a, b: TVecF32x8): TVecF32x8;
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
    vmulps  ymm0, ymm0, [rcx]
    vmovups [rax], ymm0
    vzeroupper
  end;
end;

function AVX2DivF32x8(const a, b: TVecF32x8): TVecF32x8;
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
    vdivps  ymm0, ymm0, [rcx]
    vmovups [rax], ymm0
    vzeroupper
  end;
end;

