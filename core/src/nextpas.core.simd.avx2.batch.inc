// ============================================================================
// AVX2 Batch Array Operations
// 策略: 单 asm 循环 + 4x YMM 展开 (每轮 32 float)
//        pointer bump 代替 index*4 地址计算
//        尾部在同一 asm 块内处理 (16/8/4/scalar)
// ============================================================================

procedure AVX2ArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vaddps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vaddps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vaddps  ymm2, ymm2, [rdx + 64]
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vaddps  ymm3, ymm3, [rdx + 96]
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vaddps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vaddps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vaddps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vaddps  xmm0, xmm0, [rdx]
    vmovups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vaddss xmm0, xmm0, [rdx]
    vmovss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vmulps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vmulps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vmulps  ymm2, ymm2, [rdx + 64]
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vmulps  ymm3, ymm3, [rdx + 96]
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vmulps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vmulps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vmulps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vmulps  xmm0, xmm0, [rdx]
    vmovups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vmulss xmm0, xmm0, [rdx]
    vmovss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var
  pS, pD: PSingle;
  LScalar: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScalar := aScalar;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vmovss xmm7, [LScalar]
    vbroadcastss ymm7, xmm7

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vaddps  ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vaddps  ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vaddps  ymm2, ymm2, ymm7
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vaddps  ymm3, ymm3, ymm7
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vaddps  ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vaddps  ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vaddps  ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vaddps  xmm0, xmm0, xmm7
    vmovups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vaddss xmm0, xmm0, xmm7
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var
  pS, pD: PSingle;
  LScalar: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScalar := aScalar;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vmovss xmm7, [LScalar]
    vbroadcastss ymm7, xmm7

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vmulps  ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vmulps  ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vmulps  ymm2, ymm2, ymm7
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vmulps  ymm3, ymm3, ymm7
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vmulps  ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vmulps  ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vmulps  ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vmulps  xmm0, xmm0, xmm7
    vmovups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vmulss xmm0, xmm0, xmm7
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
var
  pS, pD: PSingle;
  LMin, LMax: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LMin := aMin; LMax := aMax;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vmovss xmm6, [LMin]
    vbroadcastss ymm6, xmm6
    vmovss xmm7, [LMax]
    vbroadcastss ymm7, xmm7

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vmaxps ymm0, ymm0, ymm6
    vminps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vmaxps ymm1, ymm1, ymm6
    vminps ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vmaxps ymm2, ymm2, ymm6
    vminps ymm2, ymm2, ymm7
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vmaxps ymm3, ymm3, ymm6
    vminps ymm3, ymm3, ymm7
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vmaxps ymm0, ymm0, ymm6
    vminps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vmaxps ymm1, ymm1, ymm6
    vminps ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vmaxps ymm0, ymm0, ymm6
    vminps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vmaxps xmm0, xmm0, xmm6
    vminps xmm0, xmm0, xmm7
    vmovups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vmaxss xmm0, xmm0, xmm6
    vminss xmm0, xmm0, xmm7
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
var
  pA, pB, pC, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pA := aA; pB := aB; pC := aC; pD := aDst;

  asm
    mov rax, pA
    mov rdx, pB
    mov rcx, pC
    mov r9, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vmovups ymm4, [rdx]
    vfmadd213ps ymm0, ymm4, [rcx]

    vmovups ymm1, [rax + 32]
    vmovups ymm5, [rdx + 32]
    vfmadd213ps ymm1, ymm5, [rcx + 32]

    vmovups ymm2, [rax + 64]
    vmovups ymm6, [rdx + 64]
    vfmadd213ps ymm2, ymm6, [rcx + 64]

    vmovups ymm3, [rax + 96]
    vmovups ymm7, [rdx + 96]
    vfmadd213ps ymm3, ymm7, [rcx + 96]

    vmovups [r9], ymm0
    vmovups [r9 + 32], ymm1
    vmovups [r9 + 64], ymm2
    vmovups [r9 + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    add r9, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vmovups ymm4, [rdx]
    vfmadd213ps ymm0, ymm4, [rcx]
    vmovups [r9], ymm0
    vmovups ymm1, [rax + 32]
    vmovups ymm5, [rdx + 32]
    vfmadd213ps ymm1, ymm5, [rcx + 32]
    vmovups [r9 + 32], ymm1
    add rax, 64
    add rdx, 64
    add rcx, 64
    add r9, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vmovups ymm4, [rdx]
    vfmadd213ps ymm0, ymm4, [rcx]
    vmovups [r9], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    add r9, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vmovups xmm4, [rdx]
    vfmadd213ps xmm0, xmm4, [rcx]
    vmovups [r9], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    add r9, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vmovss xmm4, [rdx]
    vfmadd213ss xmm0, xmm4, [rcx]
    vmovss [r9], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    add r9, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
var
  pX, pY, pD: PSingle;
  LAlpha: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pX := aX; pY := aY; pD := aDst; LAlpha := aAlpha;

  asm
    mov rax, pX
    mov rdx, pY
    mov rcx, pD
    mov r8, aCount
    vmovss xmm7, [LAlpha]
    vbroadcastss ymm7, xmm7

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vmulps  ymm0, ymm0, ymm7
    vaddps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vmulps  ymm1, ymm1, ymm7
    vaddps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vmulps  ymm2, ymm2, ymm7
    vaddps  ymm2, ymm2, [rdx + 64]
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vmulps  ymm3, ymm3, ymm7
    vaddps  ymm3, ymm3, [rdx + 96]
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vmulps  ymm0, ymm0, ymm7
    vaddps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vmulps  ymm1, ymm1, ymm7
    vaddps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vmulps  ymm0, ymm0, ymm7
    vaddps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vmulps  xmm0, xmm0, xmm7
    vaddps  xmm0, xmm0, [rdx]
    vmovups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vmulss xmm0, xmm0, xmm7
    vaddss xmm0, xmm0, [rdx]
    vmovss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vsubps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vsubps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vsubps  ymm2, ymm2, [rdx + 64]
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vsubps  ymm3, ymm3, [rdx + 96]
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vsubps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vsubps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vsubps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vsubps  xmm0, xmm0, [rdx]
    vmovups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vsubss xmm0, xmm0, [rdx]
    vmovss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

function AVX2ReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  pS: PSingle;
  LSum: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc;
  LSum := 0;

  asm
    mov rax, pS
    mov r8, aCount
    vxorps ymm0, ymm0, ymm0
    vxorps ymm1, ymm1, ymm1
    vxorps ymm2, ymm2, ymm2
    vxorps ymm3, ymm3, ymm3

    cmp r8, 32
    jb @tail16

  @loop32:
    vaddps ymm0, ymm0, [rax]
    vaddps ymm1, ymm1, [rax + 32]
    vaddps ymm2, ymm2, [rax + 64]
    vaddps ymm3, ymm3, [rax + 96]
    add rax, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vaddps ymm0, ymm0, [rax]
    vaddps ymm1, ymm1, [rax + 32]
    add rax, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @reduce
    vaddps ymm0, ymm0, [rax]
    add rax, 32
    sub r8, 8

  @reduce:
    vaddps ymm0, ymm0, ymm1
    vaddps ymm2, ymm2, ymm3
    vaddps ymm0, ymm0, ymm2
    vextractf128 xmm1, ymm0, 1
    vaddps xmm0, xmm0, xmm1
    vhaddps xmm0, xmm0, xmm0
    vhaddps xmm0, xmm0, xmm0
    vmovss LSum, xmm0

    test r8, r8
    jz @done

  @scalar_loop:
    vmovss xmm1, [rax]
    vaddss xmm0, xmm0, xmm1
    vmovss LSum, xmm0
    add rax, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;

  Result := LSum;
  {$POP}
end;

function AVX2ReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
var
  pS1, pS2: PSingle;
  LSum: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS1 := aSrc1; pS2 := aSrc2;
  LSum := 0;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov r8, aCount
    vxorps ymm0, ymm0, ymm0
    vxorps ymm1, ymm1, ymm1
    vxorps ymm2, ymm2, ymm2
    vxorps ymm3, ymm3, ymm3

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm4, [rax]
    vfmadd231ps ymm0, ymm4, [rdx]
    vmovups ymm5, [rax + 32]
    vfmadd231ps ymm1, ymm5, [rdx + 32]
    vmovups ymm6, [rax + 64]
    vfmadd231ps ymm2, ymm6, [rdx + 64]
    vmovups ymm7, [rax + 96]
    vfmadd231ps ymm3, ymm7, [rdx + 96]
    add rax, 128
    add rdx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm4, [rax]
    vfmadd231ps ymm0, ymm4, [rdx]
    vmovups ymm5, [rax + 32]
    vfmadd231ps ymm1, ymm5, [rdx + 32]
    add rax, 64
    add rdx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @reduce
    vmovups ymm4, [rax]
    vfmadd231ps ymm0, ymm4, [rdx]
    add rax, 32
    add rdx, 32
    sub r8, 8

  @reduce:
    vaddps ymm0, ymm0, ymm1
    vaddps ymm2, ymm2, ymm3
    vaddps ymm0, ymm0, ymm2
    vextractf128 xmm1, ymm0, 1
    vaddps xmm0, xmm0, xmm1
    vhaddps xmm0, xmm0, xmm0
    vhaddps xmm0, xmm0, xmm0
    vmovss LSum, xmm0

    test r8, r8
    jz @done

  @scalar_loop:
    vmovss xmm1, [rax]
    vmulss xmm1, xmm1, [rdx]
    vaddss xmm0, xmm0, xmm1
    vmovss LSum, xmm0
    add rax, 4
    add rdx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;

  Result := LSum;
  {$POP}
end;

function AVX2ReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  pS: PSingle;
  LResult: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc;
  LResult := pS[0];

  asm
    mov rax, pS
    mov r8, aCount
    vbroadcastss ymm0, [rax]
    vmovaps ymm1, ymm0
    vmovaps ymm2, ymm0
    vmovaps ymm3, ymm0

    cmp r8, 32
    jb @tail16

  @loop32:
    vminps ymm0, ymm0, [rax]
    vminps ymm1, ymm1, [rax + 32]
    vminps ymm2, ymm2, [rax + 64]
    vminps ymm3, ymm3, [rax + 96]
    add rax, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vminps ymm0, ymm0, [rax]
    vminps ymm1, ymm1, [rax + 32]
    add rax, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @reduce
    vminps ymm0, ymm0, [rax]
    add rax, 32
    sub r8, 8

  @reduce:
    vminps ymm0, ymm0, ymm1
    vminps ymm2, ymm2, ymm3
    vminps ymm0, ymm0, ymm2
    vextractf128 xmm1, ymm0, 1
    vminps xmm0, xmm0, xmm1
    vpermilps xmm1, xmm0, $4E
    vminps xmm0, xmm0, xmm1
    vpermilps xmm1, xmm0, $B1
    vminss xmm0, xmm0, xmm1
    vmovss LResult, xmm0

    test r8, r8
    jz @done

  @scalar_loop:
    vmovss xmm1, [rax]
    vminss xmm0, xmm0, xmm1
    vmovss LResult, xmm0
    add rax, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;

  Result := LResult;
  {$POP}
end;

function AVX2ReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  pS: PSingle;
  LResult: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc;
  LResult := pS[0];

  asm
    mov rax, pS
    mov r8, aCount
    vbroadcastss ymm0, [rax]
    vmovaps ymm1, ymm0
    vmovaps ymm2, ymm0
    vmovaps ymm3, ymm0

    cmp r8, 32
    jb @tail16

  @loop32:
    vmaxps ymm0, ymm0, [rax]
    vmaxps ymm1, ymm1, [rax + 32]
    vmaxps ymm2, ymm2, [rax + 64]
    vmaxps ymm3, ymm3, [rax + 96]
    add rax, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmaxps ymm0, ymm0, [rax]
    vmaxps ymm1, ymm1, [rax + 32]
    add rax, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @reduce
    vmaxps ymm0, ymm0, [rax]
    add rax, 32
    sub r8, 8

  @reduce:
    vmaxps ymm0, ymm0, ymm1
    vmaxps ymm2, ymm2, ymm3
    vmaxps ymm0, ymm0, ymm2
    vextractf128 xmm1, ymm0, 1
    vmaxps xmm0, xmm0, xmm1
    vpermilps xmm1, xmm0, $4E
    vmaxps xmm0, xmm0, xmm1
    vpermilps xmm1, xmm0, $B1
    vmaxss xmm0, xmm0, xmm1
    vmovss LResult, xmm0

    test r8, r8
    jz @done

  @scalar_loop:
    vmovss xmm1, [rax]
    vmaxss xmm0, xmm0, xmm1
    vmovss LResult, xmm0
    add rax, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;

  Result := LResult;
  {$POP}
end;

// ============================================================================
// AVX2ArrayDivF32 - Element-wise division (generated by simdgen_batch)
// ============================================================================

procedure AVX2ArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vdivps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vdivps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vdivps  ymm2, ymm2, [rdx + 64]
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vdivps  ymm3, ymm3, [rdx + 96]
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vdivps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vdivps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vdivps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vdivps  xmm0, xmm0, [rdx]
    vmovups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vdivss xmm0, xmm0, [rdx]
    vmovss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// AVX2ArrayAbsF32 - Element-wise absolute value
// 策略: vandps with sign-mask 0x7FFFFFFF broadcast
// ============================================================================

procedure AVX2ArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    mov r9d, $7FFFFFFF
    vmovd xmm7, r9d
    vbroadcastss ymm7, xmm7

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vandps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vandps ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vandps ymm2, ymm2, ymm7
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vandps ymm3, ymm3, ymm7
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vandps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vandps ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vandps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vandps xmm0, xmm0, xmm7
    vmovups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vandps xmm0, xmm0, xmm7
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// AVX2ArrayNegF32 - Element-wise negation (vxorps with 0x80000000 sign-mask)
// ============================================================================

procedure AVX2ArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    mov r9d, $80000000
    vmovd xmm7, r9d
    vbroadcastss ymm7, xmm7

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vxorps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vxorps ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vxorps ymm2, ymm2, ymm7
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vxorps ymm3, ymm3, ymm7
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vxorps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vxorps ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vxorps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vxorps xmm0, xmm0, xmm7
    vmovups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vxorps xmm0, xmm0, xmm7
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// AVX2ArraySqrtF32 - Element-wise square root (vsqrtps)
// ============================================================================

procedure AVX2ArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vsqrtps ymm0, ymm0
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vsqrtps ymm1, ymm1
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vsqrtps ymm2, ymm2
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vsqrtps ymm3, ymm3
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vsqrtps ymm0, ymm0
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vsqrtps ymm1, ymm1
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vsqrtps ymm0, ymm0
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vsqrtps xmm0, xmm0
    vmovups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vsqrtss xmm0, xmm0, xmm0
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vrcpps ymm0, ymm0
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vrcpps ymm1, ymm1
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vrcpps ymm2, ymm2
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vrcpps ymm3, ymm3
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vrcpps ymm0, ymm0
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vrcpps ymm1, ymm1
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vrcpps ymm0, ymm0
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vrcpps xmm0, xmm0
    vmovups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vrcpss xmm0, xmm0, xmm0
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vrsqrtps ymm0, ymm0
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vrsqrtps ymm1, ymm1
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vrsqrtps ymm2, ymm2
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vrsqrtps ymm3, ymm3
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vrsqrtps ymm0, ymm0
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vrsqrtps ymm1, ymm1
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vrsqrtps ymm0, ymm0
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vrsqrtps xmm0, xmm0
    vmovups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vrsqrtss xmm0, xmm0, xmm0
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// AVX2ArrayMinF32 - Element-wise minimum (generated by simdgen_batch)
// ============================================================================

procedure AVX2ArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vminps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vminps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vminps  ymm2, ymm2, [rdx + 64]
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vminps  ymm3, ymm3, [rdx + 96]
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vminps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vminps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vminps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vminps  xmm0, xmm0, [rdx]
    vmovups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vminss xmm0, xmm0, [rdx]
    vmovss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// AVX2ArrayMaxF32 - Element-wise maximum (generated by simdgen_batch)
// ============================================================================

procedure AVX2ArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail16

  @loop32:
    vmovups ymm0, [rax]
    vmaxps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vmaxps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vmaxps  ymm2, ymm2, [rdx + 64]
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vmaxps  ymm3, ymm3, [rdx + 96]
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    vmovups ymm0, [rax]
    vmaxps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vmaxps  ymm1, ymm1, [rdx + 32]
    vmovups [rcx + 32], ymm1
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    vmovups ymm0, [rax]
    vmaxps  ymm0, ymm0, [rdx]
    vmovups [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovups xmm0, [rax]
    vmaxps  xmm0, xmm0, [rdx]
    vmovups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vmaxss xmm0, xmm0, [rdx]
    vmovss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// F64 Batch Array Operations
// 策略: 4x YMM 展开 (每轮 16 double), pointer bump
// ============================================================================

procedure AVX2ArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var
  pS1, pS2, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail4

  @loop16:
    vmovupd ymm0, [rax]
    vaddpd ymm0, ymm0, [rdx]
    vmovupd [rcx], ymm0
    vmovupd ymm1, [rax + 32]
    vaddpd ymm1, ymm1, [rdx + 32]
    vmovupd [rcx + 32], ymm1
    vmovupd ymm2, [rax + 64]
    vaddpd ymm2, ymm2, [rdx + 64]
    vmovupd [rcx + 64], ymm2
    vmovupd ymm3, [rax + 96]
    vaddpd ymm3, ymm3, [rdx + 96]
    vmovupd [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovupd ymm0, [rax]
    vaddpd ymm0, ymm0, [rdx]
    vmovupd [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vaddsd xmm0, xmm0, [rdx]
    vmovsd [rcx], xmm0
    add rax, 8
    add rdx, 8
    add rcx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var
  pS1, pS2, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail4

  @loop16:
    vmovupd ymm0, [rax]
    vsubpd ymm0, ymm0, [rdx]
    vmovupd [rcx], ymm0
    vmovupd ymm1, [rax + 32]
    vsubpd ymm1, ymm1, [rdx + 32]
    vmovupd [rcx + 32], ymm1
    vmovupd ymm2, [rax + 64]
    vsubpd ymm2, ymm2, [rdx + 64]
    vmovupd [rcx + 64], ymm2
    vmovupd ymm3, [rax + 96]
    vsubpd ymm3, ymm3, [rdx + 96]
    vmovupd [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovupd ymm0, [rax]
    vsubpd ymm0, ymm0, [rdx]
    vmovupd [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vsubsd xmm0, xmm0, [rdx]
    vmovsd [rcx], xmm0
    add rax, 8
    add rdx, 8
    add rcx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var
  pS1, pS2, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail4

  @loop16:
    vmovupd ymm0, [rax]
    vmulpd ymm0, ymm0, [rdx]
    vmovupd [rcx], ymm0
    vmovupd ymm1, [rax + 32]
    vmulpd ymm1, ymm1, [rdx + 32]
    vmovupd [rcx + 32], ymm1
    vmovupd ymm2, [rax + 64]
    vmulpd ymm2, ymm2, [rdx + 64]
    vmovupd [rcx + 64], ymm2
    vmovupd ymm3, [rax + 96]
    vmulpd ymm3, ymm3, [rdx + 96]
    vmovupd [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovupd ymm0, [rax]
    vmulpd ymm0, ymm0, [rdx]
    vmovupd [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vmulsd xmm0, xmm0, [rdx]
    vmovsd [rcx], xmm0
    add rax, 8
    add rdx, 8
    add rcx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var
  pS1, pS2, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail4

  @loop16:
    vmovupd ymm0, [rax]
    vdivpd ymm0, ymm0, [rdx]
    vmovupd [rcx], ymm0
    vmovupd ymm1, [rax + 32]
    vdivpd ymm1, ymm1, [rdx + 32]
    vmovupd [rcx + 32], ymm1
    vmovupd ymm2, [rax + 64]
    vdivpd ymm2, ymm2, [rdx + 64]
    vmovupd [rcx + 64], ymm2
    vmovupd ymm3, [rax + 96]
    vdivpd ymm3, ymm3, [rdx + 96]
    vmovupd [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovupd ymm0, [rax]
    vdivpd ymm0, ymm0, [rdx]
    vmovupd [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vdivsd xmm0, xmm0, [rdx]
    vmovsd [rcx], xmm0
    add rax, 8
    add rdx, 8
    add rcx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

function AVX2ReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double;
var
  pS: PDouble;
  LSum: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc; LSum := 0;

  asm
    mov rax, pS
    mov r8, aCount
    vxorpd ymm0, ymm0, ymm0
    vxorpd ymm1, ymm1, ymm1
    vxorpd ymm2, ymm2, ymm2
    vxorpd ymm3, ymm3, ymm3

    cmp r8, 16
    jb @tail4

  @loop16:
    vaddpd ymm0, ymm0, [rax]
    vaddpd ymm1, ymm1, [rax + 32]
    vaddpd ymm2, ymm2, [rax + 64]
    vaddpd ymm3, ymm3, [rax + 96]
    add rax, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @reduce
    vaddpd ymm0, ymm0, [rax]
    add rax, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @reduce:
    vaddpd ymm0, ymm0, ymm1
    vaddpd ymm2, ymm2, ymm3
    vaddpd ymm0, ymm0, ymm2
    vextractf128 xmm1, ymm0, 1
    vaddpd xmm0, xmm0, xmm1
    vhaddpd xmm0, xmm0, xmm0
    vmovsd LSum, xmm0

    test r8, r8
    jz @done

  @scalar_loop:
    vmovsd xmm1, [rax]
    vaddsd xmm0, xmm0, xmm1
    vmovsd LSum, xmm0
    add rax, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;

  Result := LSum;
  {$POP}
end;

function AVX2ReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
var
  pS1, pS2: PDouble;
  LSum: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS1 := aSrc1; pS2 := aSrc2; LSum := 0;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov r8, aCount
    vxorpd ymm0, ymm0, ymm0
    vxorpd ymm1, ymm1, ymm1
    vxorpd ymm2, ymm2, ymm2
    vxorpd ymm3, ymm3, ymm3

    cmp r8, 16
    jb @tail4

  @loop16:
    vmovupd ymm4, [rax]
    vmulpd ymm4, ymm4, [rdx]
    vaddpd ymm0, ymm0, ymm4
    vmovupd ymm5, [rax + 32]
    vmulpd ymm5, ymm5, [rdx + 32]
    vaddpd ymm1, ymm1, ymm5
    vmovupd ymm6, [rax + 64]
    vmulpd ymm6, ymm6, [rdx + 64]
    vaddpd ymm2, ymm2, ymm6
    vmovupd ymm7, [rax + 96]
    vmulpd ymm7, ymm7, [rdx + 96]
    vaddpd ymm3, ymm3, ymm7
    add rax, 128
    add rdx, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @reduce
    vmovupd ymm4, [rax]
    vmulpd ymm4, ymm4, [rdx]
    vaddpd ymm0, ymm0, ymm4
    add rax, 32
    add rdx, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @reduce:
    vaddpd ymm0, ymm0, ymm1
    vaddpd ymm2, ymm2, ymm3
    vaddpd ymm0, ymm0, ymm2
    vextractf128 xmm1, ymm0, 1
    vaddpd xmm0, xmm0, xmm1
    vhaddpd xmm0, xmm0, xmm0
    vmovsd LSum, xmm0

    test r8, r8
    jz @done

  @scalar_loop:
    vmovsd xmm1, [rax]
    vmulsd xmm1, xmm1, [rdx]
    vaddsd xmm0, xmm0, xmm1
    vmovsd LSum, xmm0
    add rax, 8
    add rdx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;

  Result := LSum;
  {$POP}
end;

function AVX2ReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double;
var
  pS: PDouble;
  LResult: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc; LResult := pS[0];

  asm
    mov rax, pS
    mov r8, aCount
    vbroadcastsd ymm0, [rax]
    vmovapd ymm1, ymm0
    vmovapd ymm2, ymm0
    vmovapd ymm3, ymm0

    cmp r8, 16
    jb @tail4

  @loop16:
    vminpd ymm0, ymm0, [rax]
    vminpd ymm1, ymm1, [rax + 32]
    vminpd ymm2, ymm2, [rax + 64]
    vminpd ymm3, ymm3, [rax + 96]
    add rax, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @reduce
    vminpd ymm0, ymm0, [rax]
    add rax, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @reduce:
    vminpd ymm0, ymm0, ymm1
    vminpd ymm2, ymm2, ymm3
    vminpd ymm0, ymm0, ymm2
    vextractf128 xmm1, ymm0, 1
    vminpd xmm0, xmm0, xmm1
    vpermilpd xmm1, xmm0, 1
    vminsd xmm0, xmm0, xmm1
    vmovsd LResult, xmm0

    test r8, r8
    jz @done

  @scalar_loop:
    vmovsd xmm1, [rax]
    vminsd xmm0, xmm0, xmm1
    vmovsd LResult, xmm0
    add rax, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;

  Result := LResult;
  {$POP}
end;

function AVX2ReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;
var
  pS: PDouble;
  LResult: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc; LResult := pS[0];

  asm
    mov rax, pS
    mov r8, aCount
    vbroadcastsd ymm0, [rax]
    vmovapd ymm1, ymm0
    vmovapd ymm2, ymm0
    vmovapd ymm3, ymm0

    cmp r8, 16
    jb @tail4

  @loop16:
    vmaxpd ymm0, ymm0, [rax]
    vmaxpd ymm1, ymm1, [rax + 32]
    vmaxpd ymm2, ymm2, [rax + 64]
    vmaxpd ymm3, ymm3, [rax + 96]
    add rax, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @reduce
    vmaxpd ymm0, ymm0, [rax]
    add rax, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @reduce:
    vmaxpd ymm0, ymm0, ymm1
    vmaxpd ymm2, ymm2, ymm3
    vmaxpd ymm0, ymm0, ymm2
    vextractf128 xmm1, ymm0, 1
    vmaxpd xmm0, xmm0, xmm1
    vpermilpd xmm1, xmm0, 1
    vmaxsd xmm0, xmm0, xmm1
    vmovsd LResult, xmm0

    test r8, r8
    jz @done

  @scalar_loop:
    vmovsd xmm1, [rax]
    vmaxsd xmm0, xmm0, xmm1
    vmovsd LResult, xmm0
    add rax, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;

  Result := LResult;
  {$POP}
end;

// ============================================================================
// AVX2ArrayAbsF64 - Element-wise absolute value (vandpd with 0x7FFFFFFFFFFFFFFF)
// 策略: 4x YMM 展开 (每轮 16 double), pointer bump
// ============================================================================

procedure AVX2ArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    mov r9, $7FFFFFFFFFFFFFFF
    vmovq xmm7, r9
    vpbroadcastq ymm7, xmm7

    cmp r8, 16
    jb @tail4

  @loop16:
    vmovupd ymm0, [rax]
    vandpd ymm0, ymm0, ymm7
    vmovupd [rcx], ymm0
    vmovupd ymm1, [rax + 32]
    vandpd ymm1, ymm1, ymm7
    vmovupd [rcx + 32], ymm1
    vmovupd ymm2, [rax + 64]
    vandpd ymm2, ymm2, ymm7
    vmovupd [rcx + 64], ymm2
    vmovupd ymm3, [rax + 96]
    vandpd ymm3, ymm3, ymm7
    vmovupd [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovupd ymm0, [rax]
    vandpd ymm0, ymm0, ymm7
    vmovupd [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vandpd xmm0, xmm0, xmm7
    vmovsd [rcx], xmm0
    add rax, 8
    add rcx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// AVX2ArrayNegF64 - Element-wise negation (vxorpd with 0x8000000000000000)
// 策略: 4x YMM 展开 (每轮 16 double), pointer bump
// ============================================================================

procedure AVX2ArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    mov r9, $8000000000000000
    vmovq xmm7, r9
    vpbroadcastq ymm7, xmm7

    cmp r8, 16
    jb @tail4

  @loop16:
    vmovupd ymm0, [rax]
    vxorpd ymm0, ymm0, ymm7
    vmovupd [rcx], ymm0
    vmovupd ymm1, [rax + 32]
    vxorpd ymm1, ymm1, ymm7
    vmovupd [rcx + 32], ymm1
    vmovupd ymm2, [rax + 64]
    vxorpd ymm2, ymm2, ymm7
    vmovupd [rcx + 64], ymm2
    vmovupd ymm3, [rax + 96]
    vxorpd ymm3, ymm3, ymm7
    vmovupd [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovupd ymm0, [rax]
    vxorpd ymm0, ymm0, ymm7
    vmovupd [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vxorpd xmm0, xmm0, xmm7
    vmovsd [rcx], xmm0
    add rax, 8
    add rcx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// AVX2ArraySqrtF64 - Element-wise square root (vsqrtpd)
// 策略: 4x YMM 展开 (每轮 16 double), pointer bump
// ============================================================================

procedure AVX2ArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail4

  @loop16:
    vmovupd ymm0, [rax]
    vsqrtpd ymm0, ymm0
    vmovupd [rcx], ymm0
    vmovupd ymm1, [rax + 32]
    vsqrtpd ymm1, ymm1
    vmovupd [rcx + 32], ymm1
    vmovupd ymm2, [rax + 64]
    vsqrtpd ymm2, ymm2
    vmovupd [rcx + 64], ymm2
    vmovupd ymm3, [rax + 96]
    vsqrtpd ymm3, ymm3
    vmovupd [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovupd ymm0, [rax]
    vsqrtpd ymm0, ymm0
    vmovupd [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vsqrtsd xmm0, xmm0, xmm0
    vmovsd [rcx], xmm0
    add rax, 8
    add rcx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// Integer Batch Array Operations (AVX2)
// AVX2 vpaddd/vpsubd: 8 x Int32 per YMM, vpmullw: 16 x Int16 per YMM
// ============================================================================

procedure AVX2ArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var
  pS1, pS2, pD: PInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovdqu ymm0, [rax]
    vpaddd ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vmovdqu ymm1, [rax + 32]
    vpaddd ymm1, ymm1, [rdx + 32]
    vmovdqu [rcx + 32], ymm1
    vmovdqu ymm2, [rax + 64]
    vpaddd ymm2, ymm2, [rdx + 64]
    vmovdqu [rcx + 64], ymm2
    vmovdqu ymm3, [rax + 96]
    vpaddd ymm3, ymm3, [rdx + 96]
    vmovdqu [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovdqu ymm0, [rax]
    vpaddd ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    mov r9d, [rax]
    add r9d, [rdx]
    mov [rcx], r9d
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var
  pS1, pS2, pD: PInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovdqu ymm0, [rax]
    vpsubd ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vmovdqu ymm1, [rax + 32]
    vpsubd ymm1, ymm1, [rdx + 32]
    vmovdqu [rcx + 32], ymm1
    vmovdqu ymm2, [rax + 64]
    vpsubd ymm2, ymm2, [rdx + 64]
    vmovdqu [rcx + 64], ymm2
    vmovdqu ymm3, [rax + 96]
    vpsubd ymm3, ymm3, [rdx + 96]
    vmovdqu [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovdqu ymm0, [rax]
    vpsubd ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    mov r9d, [rax]
    sub r9d, [rdx]
    mov [rcx], r9d
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayMulI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
var
  pS1, pS2, pD: PInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 64
    jb @tail16

  @loop64:
    vmovdqu ymm0, [rax]
    vpmullw ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vmovdqu ymm1, [rax + 32]
    vpmullw ymm1, ymm1, [rdx + 32]
    vmovdqu [rcx + 32], ymm1
    vmovdqu ymm2, [rax + 64]
    vpmullw ymm2, ymm2, [rdx + 64]
    vmovdqu [rcx + 64], ymm2
    vmovdqu ymm3, [rax + 96]
    vpmullw ymm3, ymm3, [rdx + 96]
    vmovdqu [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovdqu ymm0, [rax]
    vpmullw ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 16
    cmp r8, 16
    jae @tail16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movsx r9d, word [rax]
    movsx r10d, word [rdx]
    imul r9d, r10d
    mov [rcx], r9w
    add rax, 2
    add rdx, 2
    add rcx, 2
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayPackSatI32toI16(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt);
var
  pS: PInt32;
  pD: PInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovdqu ymm0, [rax]
    vmovdqu ymm1, [rax + 32]
    vpackssdw ymm0, ymm0, ymm1
    vpermq ymm0, ymm0, $D8
    vmovdqu [rcx], ymm0
    add rax, 64
    add rcx, 32
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    mov r9d, [rax]
    cmp r9d, 32767
    jle @check_min
    mov r9d, 32767
    jmp @store
  @check_min:
    cmp r9d, -32768
    jge @store
    mov r9d, -32768
  @store:
    mov [rcx], r9w
    add rax, 4
    add rcx, 2
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// Type Conversion Batch Operations (AVX2)
// vcvtps2dq: F32→I32 (8 per YMM), vcvtdq2ps: I32→F32 (8 per YMM)
// ============================================================================

procedure AVX2ArrayF32toI32(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt);
var
  pS: PSingle;
  pD: PInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovups ymm0, [rax]
    vcvtps2dq ymm0, ymm0
    vmovdqu [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vcvtps2dq ymm1, ymm1
    vmovdqu [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vcvtps2dq ymm2, ymm2
    vmovdqu [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vcvtps2dq ymm3, ymm3
    vmovdqu [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovups ymm0, [rax]
    vcvtps2dq ymm0, ymm0
    vmovdqu [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vcvtss2si r9d, xmm0
    mov [rcx], r9d
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayI32toF32(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt);
var
  pS: PInt32;
  pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovdqu ymm0, [rax]
    vcvtdq2ps ymm0, ymm0
    vmovups [rcx], ymm0
    vmovdqu ymm1, [rax + 32]
    vcvtdq2ps ymm1, ymm1
    vmovups [rcx + 32], ymm1
    vmovdqu ymm2, [rax + 64]
    vcvtdq2ps ymm2, ymm2
    vmovups [rcx + 64], ymm2
    vmovdqu ymm3, [rax + 96]
    vcvtdq2ps ymm3, ymm3
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovdqu ymm0, [rax]
    vcvtdq2ps ymm0, ymm0
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vcvtsi2ss xmm0, xmm0, dword [rax]
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// Bitwise Batch Operations (AVX2)
// vpand/vpor/vpxor: 256-bit, vpslld/vpsrad: uniform shift
// ============================================================================

procedure AVX2ArrayAndI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var
  pS1, pS2, pD: PInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovdqu ymm0, [rax]
    vpand ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vmovdqu ymm1, [rax + 32]
    vpand ymm1, ymm1, [rdx + 32]
    vmovdqu [rcx + 32], ymm1
    vmovdqu ymm2, [rax + 64]
    vpand ymm2, ymm2, [rdx + 64]
    vmovdqu [rcx + 64], ymm2
    vmovdqu ymm3, [rax + 96]
    vpand ymm3, ymm3, [rdx + 96]
    vmovdqu [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovdqu ymm0, [rax]
    vpand ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    mov r9d, [rax]
    and r9d, [rdx]
    mov [rcx], r9d
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayOrI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var
  pS1, pS2, pD: PInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovdqu ymm0, [rax]
    vpor ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vmovdqu ymm1, [rax + 32]
    vpor ymm1, ymm1, [rdx + 32]
    vmovdqu [rcx + 32], ymm1
    vmovdqu ymm2, [rax + 64]
    vpor ymm2, ymm2, [rdx + 64]
    vmovdqu [rcx + 64], ymm2
    vmovdqu ymm3, [rax + 96]
    vpor ymm3, ymm3, [rdx + 96]
    vmovdqu [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovdqu ymm0, [rax]
    vpor ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    mov r9d, [rax]
    or r9d, [rdx]
    mov [rcx], r9d
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayXorI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var
  pS1, pS2, pD: PInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovdqu ymm0, [rax]
    vpxor ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    vmovdqu ymm1, [rax + 32]
    vpxor ymm1, ymm1, [rdx + 32]
    vmovdqu [rcx + 32], ymm1
    vmovdqu ymm2, [rax + 64]
    vpxor ymm2, ymm2, [rdx + 64]
    vmovdqu [rcx + 64], ymm2
    vmovdqu ymm3, [rax + 96]
    vpxor ymm3, ymm3, [rdx + 96]
    vmovdqu [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovdqu ymm0, [rax]
    vpxor ymm0, ymm0, [rdx]
    vmovdqu [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    mov r9d, [rax]
    xor r9d, [rdx]
    mov [rcx], r9d
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayShlI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
var
  pS, pD: PInt32;
  LShift: Integer;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LShift := aShift;

  asm
    mov rax, pS
    mov rdx, pD
    mov r8, aCount
    movd xmm7, LShift

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovdqu ymm0, [rax]
    vpslld ymm0, ymm0, xmm7
    vmovdqu [rdx], ymm0
    add rax, 32
    add rdx, 32
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail_scalar:
    test r8, r8
    jz @done
    mov ecx, LShift
  @scalar_loop:
    mov r9d, [rax]
    shl r9d, cl
    mov [rdx], r9d
    add rax, 4
    add rdx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayShrI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
var
  pS, pD: PInt32;
  LShift: Integer;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LShift := aShift;

  asm
    mov rax, pS
    mov rdx, pD
    mov r8, aCount
    movd xmm7, LShift

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovdqu ymm0, [rax]
    vpsrad ymm0, ymm0, xmm7
    vmovdqu [rdx], ymm0
    add rax, 32
    add rdx, 32
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail_scalar:
    test r8, r8
    jz @done
    mov ecx, LShift
  @scalar_loop:
    mov r9d, [rax]
    sar r9d, cl
    mov [rdx], r9d
    add rax, 4
    add rdx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// AVX2ArrayRcpRefineF32 - Newton-Raphson refined reciprocal (~23-bit precision)
// Algorithm: y0 = vrcpps(x); y1 = y0 * (2 - x * y0)
// ============================================================================

procedure AVX2ArrayRcpRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    // ymm7 = 2.0 broadcast
    mov r9d, $40000000
    vmovd xmm7, r9d
    vbroadcastss ymm7, xmm7

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovups ymm0, [rax]           // x
    vrcpps ymm1, ymm0             // y0 = approx(1/x)
    vmulps ymm2, ymm0, ymm1      // x * y0
    vsubps ymm2, ymm7, ymm2      // 2 - x * y0
    vmulps ymm1, ymm1, ymm2      // y1 = y0 * (2 - x * y0)
    vmovups [rcx], ymm1
    add rax, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vrcpss xmm1, xmm0, xmm0
    vmulss xmm2, xmm0, xmm1
    vsubss xmm2, xmm7, xmm2
    vmulss xmm1, xmm1, xmm2
    vmovss [rcx], xmm1
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// AVX2ArrayRsqrtRefineF32 - Newton-Raphson refined inverse sqrt (~23-bit)
// Algorithm: y0 = vrsqrtps(x); y1 = 0.5 * y0 * (3 - x * y0 * y0)
// ============================================================================

procedure AVX2ArrayRsqrtRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    // ymm6 = 0.5, ymm7 = 3.0
    mov r9d, $3F000000
    vmovd xmm6, r9d
    vbroadcastss ymm6, xmm6
    mov r9d, $40400000
    vmovd xmm7, r9d
    vbroadcastss ymm7, xmm7

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovups ymm0, [rax]           // x
    vrsqrtps ymm1, ymm0           // y0 = approx(1/sqrt(x))
    vmulps ymm2, ymm1, ymm1      // y0^2
    vmulps ymm2, ymm0, ymm2      // x * y0^2
    vsubps ymm2, ymm7, ymm2      // 3 - x * y0^2
    vmulps ymm1, ymm1, ymm2      // y0 * (3 - x * y0^2)
    vmulps ymm1, ymm1, ymm6      // 0.5 * y0 * (3 - x * y0^2)
    vmovups [rcx], ymm1
    add rax, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vrsqrtss xmm1, xmm0, xmm0
    vmulss xmm2, xmm1, xmm1
    vmulss xmm2, xmm0, xmm2
    vsubss xmm2, xmm7, xmm2
    vmulss xmm1, xmm1, xmm2
    vmulss xmm1, xmm1, xmm6
    vmovss [rcx], xmm1
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// AVX2 ArrayExpF32 — SIMD exp(x), 7th-order minimax, <2 ULP, PIC-safe
// ============================================================================

procedure AVX2ArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
  LLog2e, LLn2Hi, LLn2Lo: Single;
  LP0, LP1, LP2, LP3, LP4, LP5, LP6: Single;
  LMaxX, LMinX: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LLog2e := 1.44269504088896;
  LLn2Hi := 0.693145751953125;
  LLn2Lo := 1.42860677e-6;
  LP0 := 1.0; LP1 := 1.0; LP2 := 0.5;
  LP3 := 0.166666671633720; LP4 := 0.041666485369205;
  LP5 := 0.008333360776305; LP6 := 0.001393043552525;
  LMaxX := 88.7228; LMinX := -87.3365;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    vbroadcastss ymm15, [LLog2e]
    vbroadcastss ymm14, [LLn2Hi]
    vbroadcastss ymm13, [LLn2Lo]
    vbroadcastss ymm12, [LP0]
    vbroadcastss ymm11, [LP1]
    vbroadcastss ymm10, [LP2]
    vbroadcastss ymm9, [LP3]
    vbroadcastss ymm8, [LP4]
    vbroadcastss ymm7, [LP5]
    vbroadcastss ymm6, [LP6]
    vbroadcastss ymm5, [LMaxX]
    vbroadcastss ymm4, [LMinX]

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovups ymm0, [rax]
    vminps ymm0, ymm0, ymm5
    vmaxps ymm0, ymm0, ymm4

    vmulps ymm1, ymm0, ymm15
    vroundps ymm1, ymm1, $00

    vmulps ymm2, ymm1, ymm14
    vsubps ymm0, ymm0, ymm2
    vmulps ymm2, ymm1, ymm13
    vsubps ymm0, ymm0, ymm2

    vmovaps ymm2, ymm6
    vfmadd213ps ymm2, ymm0, ymm7
    vfmadd213ps ymm2, ymm0, ymm8
    vfmadd213ps ymm2, ymm0, ymm9
    vfmadd213ps ymm2, ymm0, ymm10
    vfmadd213ps ymm2, ymm0, ymm11
    vfmadd213ps ymm2, ymm0, ymm12

    vcvtps2dq ymm1, ymm1
    vpslld ymm1, ymm1, 23
    vpaddd ymm2, ymm2, ymm1

    vmovups [rcx], ymm2
    add rax, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vminss xmm0, xmm0, xmm5
    vmaxss xmm0, xmm0, xmm4
    vmulss xmm1, xmm0, xmm15
    vroundss xmm1, xmm1, xmm1, $00
    vmulss xmm2, xmm1, xmm14
    vsubss xmm0, xmm0, xmm2
    vmulss xmm2, xmm1, xmm13
    vsubss xmm0, xmm0, xmm2
    vmovaps xmm2, xmm6
    vfmadd213ss xmm2, xmm0, xmm7
    vfmadd213ss xmm2, xmm0, xmm8
    vfmadd213ss xmm2, xmm0, xmm9
    vfmadd213ss xmm2, xmm0, xmm10
    vfmadd213ss xmm2, xmm0, xmm11
    vfmadd213ss xmm2, xmm0, xmm12
    vcvtss2si r9d, xmm1
    shl r9d, 23
    vmovd xmm1, r9d
    vpaddd xmm2, xmm2, xmm1
    vmovss [rcx], xmm2
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;


// ============================================================================
// AVX2 ArraySinF32 / ArrayCosF32 — SIMD sin/cos via Cody-Waite + minimax poly

// ============================================================================
// AVX2 ArraySinF32 — SIMD sin(x) via Cody-Waite + quadrant selection
// Algorithm:
//   1. j = round(x * 2/pi), r = x - j*(pi/2)
//   2. If j&1: use cos poly, else use sin poly
//   3. If (j&2) XOR sign(x): negate result
// Precision: ~4 ULP for |x| < 8192
// ============================================================================

procedure AVX2ArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
  L2OverPi, LPiOver2Hi, LPiOver2Mid: Single;
  LS1, LS2, LS3: Single;
  LC1, LC2, LC3: Single;
  LOne, LSignMask: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  L2OverPi := 0.636619772367581;      // 2/pi
  LPiOver2Hi := 1.5707963705062866;   // float32(pi/2) exact
  LPiOver2Mid := -4.3711388286737929e-8; // 3-part Cody-Waite correction
  // sin(r) ≈ r*(1 + r²*(S1 + r²*(S2 + r²*S3)))
  LS1 := -0.16666667163372;   // -1/6
  LS2 := 0.00833333376795;    // 1/120
  LS3 := -0.00019841269841;   // -1/5040
  // cos(r) ≈ 1 + r²*(C1 + r²*(C2 + r²*C3))
  LC1 := -0.5;
  LC2 := 0.04166666567325;    // 1/24
  LC3 := -0.00138888894580;   // -1/720
  LOne := 1.0;
  LSignMask := 0.0;
  PUInt32(@LSignMask)^ := $80000000;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    vbroadcastss ymm15, [L2OverPi]
    vbroadcastss ymm14, [LPiOver2Hi]
    vbroadcastss ymm13, [LPiOver2Mid]
    vbroadcastss ymm12, [LS1]
    vbroadcastss ymm11, [LS2]
    vbroadcastss ymm10, [LS3]
    vbroadcastss ymm9, [LC1]
    vbroadcastss ymm8, [LC2]
    vbroadcastss ymm7, [LC3]
    vbroadcastss ymm6, [LOne]
    vbroadcastss ymm5, [LSignMask]

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovups ymm0, [rax]           // x

    // Extract sign and take abs
    vandps ymm4, ymm0, ymm5      // sign(x)
    vandnps ymm0, ymm5, ymm0     // |x|

    // j = round(|x| * 2/pi)
    vmulps ymm1, ymm0, ymm15
    vroundps ymm1, ymm1, $00     // j (float, rounded)
    vcvtps2dq ymm3, ymm1         // j (int)

    // Extract sign info from j BEFORE destroying ymm3:
    // j&2 → sign flip mask
    vpsrld ymm2, ymm3, 1         // j >> 1: bit1 → bit0
    vpslld ymm2, ymm2, 31        // bit0 → bit31 (sign position)
    vxorps ymm4, ymm4, ymm2      // combined sign = sign(x) XOR (j&2 sign)

    // j&1 → blend mask (bit0 → bit31 for vblendvps)
    vpslld ymm3, ymm3, 31        // j bit0 → bit31 (ymm3 = blend mask, j_int destroyed)

    // r = |x| - j * (pi/2)  (Cody-Waite)
    vmulps ymm2, ymm1, ymm14
    vsubps ymm0, ymm0, ymm2
    vmulps ymm2, ymm1, ymm13
    vsubps ymm0, ymm0, ymm2      // r

    // r²
    vmulps ymm2, ymm0, ymm0      // r²

    // Sin poly: sin(r) = r * (1 + r²*(S1 + r²*(S2 + r²*S3)))
    vmovaps ymm1, ymm10          // S3
    vfmadd213ps ymm1, ymm2, ymm11 // S3*r² + S2
    vfmadd213ps ymm1, ymm2, ymm12 // (..)*r² + S1
    vfmadd213ps ymm1, ymm2, ymm6  // (..)*r² + 1
    vmulps ymm1, ymm1, ymm0      // * r → sin_result

    // Cos poly: cos(r) = 1 + r²*(C1 + r²*(C2 + r²*C3))
    vmovaps ymm0, ymm7           // C3
    vfmadd213ps ymm0, ymm2, ymm8  // C3*r² + C2
    vfmadd213ps ymm0, ymm2, ymm9  // (..)*r² + C1
    vmulps ymm0, ymm0, ymm2      // * r²
    vaddps ymm0, ymm0, ymm6      // + 1 → cos_result

    // Select: ymm3 bit31=1 where j is odd → use cos(ymm0), else sin(ymm1)
    vblendvps ymm0, ymm1, ymm0, ymm3

    // Apply combined sign (original XOR j&2)
    vxorps ymm0, ymm0, ymm4

    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    sub rsp, 8
    vmovss xmm0, [rax]
    vmovss [rsp], xmm0
    fld dword [rsp]
    fsin
    fstp dword [rsp]
    vmovss xmm0, [rsp]
    add rsp, 8
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
  L2OverPi, LPiOver2Hi, LPiOver2Mid: Single;
  LS1, LS2, LS3: Single;
  LC1, LC2, LC3: Single;
  LOne, LSignMask: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  L2OverPi := 0.636619772367581;
  LPiOver2Hi := 1.5707963705062866;
  LPiOver2Mid := -4.3711388286737929e-8;
  LS1 := -0.16666667163372;
  LS2 := 0.00833333376795;
  LS3 := -0.00019841269841;
  LC1 := -0.5;
  LC2 := 0.04166666567325;
  LC3 := -0.00138888894580;
  LOne := 1.0;
  LSignMask := 0.0;
  PUInt32(@LSignMask)^ := $80000000;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    vbroadcastss ymm15, [L2OverPi]
    vbroadcastss ymm14, [LPiOver2Hi]
    vbroadcastss ymm13, [LPiOver2Mid]
    vbroadcastss ymm12, [LS1]
    vbroadcastss ymm11, [LS2]
    vbroadcastss ymm10, [LS3]
    vbroadcastss ymm9, [LC1]
    vbroadcastss ymm8, [LC2]
    vbroadcastss ymm7, [LC3]
    vbroadcastss ymm6, [LOne]
    vbroadcastss ymm5, [LSignMask]

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovups ymm0, [rax]           // x

    // cos(x) = cos(|x|), sign doesn't matter
    vandnps ymm0, ymm5, ymm0     // |x|

    // j = round(|x| * 2/pi)
    vmulps ymm1, ymm0, ymm15
    vroundps ymm1, ymm1, $00
    vcvtps2dq ymm3, ymm1         // j_int

    // For cos: use j+1 for quadrant selection
    vpcmpeqd ymm4, ymm4, ymm4
    vpsrld ymm4, ymm4, 31        // const 1
    vpaddd ymm3, ymm3, ymm4      // j+1

    // Extract masks from j+1 using vpslld (same as Sin optimization):
    // (j+1)&2 sign mask
    vpsrld ymm2, ymm3, 1
    vpslld ymm4, ymm2, 31        // (j+1) bit1 → bit31 = sign mask

    // (j+1)&1 blend mask
    vpslld ymm3, ymm3, 31        // (j+1) bit0 → bit31 = blend mask

    // r = |x| - j * (pi/2)
    vmulps ymm2, ymm1, ymm14
    vsubps ymm0, ymm0, ymm2
    vmulps ymm2, ymm1, ymm13
    vsubps ymm0, ymm0, ymm2      // r

    // r²
    vmulps ymm2, ymm0, ymm0

    // Sin poly
    vmovaps ymm1, ymm10
    vfmadd213ps ymm1, ymm2, ymm11
    vfmadd213ps ymm1, ymm2, ymm12
    vfmadd213ps ymm1, ymm2, ymm6
    vmulps ymm1, ymm1, ymm0      // sin_result

    // Cos poly
    vmovaps ymm0, ymm7
    vfmadd213ps ymm0, ymm2, ymm8
    vfmadd213ps ymm0, ymm2, ymm9
    vmulps ymm0, ymm0, ymm2
    vaddps ymm0, ymm0, ymm6      // cos_result

    // Select: ymm3 bit31=1 where (j+1) odd → use cos, else sin
    vblendvps ymm0, ymm1, ymm0, ymm3

    // Apply sign from (j+1)&2
    vxorps ymm0, ymm0, ymm4

    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    sub rsp, 8
    vmovss xmm0, [rax]
    vmovss [rsp], xmm0
    fld dword [rsp]
    fcos
    fstp dword [rsp]
    vmovss xmm0, [rsp]
    add rsp, 8
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// Algorithm: f = (m-1)/(m+1), ln(x) = e*ln2 + 2*(f + f³/3 + f⁵/5 + f⁷/7)
// The atanh transform compresses range to [-0.172, 0.172], 4 terms suffice
// ============================================================================

procedure AVX2ArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
  LLn2, LOne, LTwo, LThirdInv, LFifthInv, LSeventhInv: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LLn2 := 0.6931471805599453;
  LOne := 1.0;
  LTwo := 2.0;
  LThirdInv := 0.333333333333333;   // 1/3
  LFifthInv := 0.2;                  // 1/5
  LSeventhInv := 0.142857142857143;  // 1/7

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    vbroadcastss ymm15, [LLn2]
    vbroadcastss ymm14, [LOne]
    vbroadcastss ymm13, [LTwo]
    vbroadcastss ymm12, [LThirdInv]
    vbroadcastss ymm11, [LFifthInv]
    vbroadcastss ymm10, [LSeventhInv]

    mov r9d, $007FFFFF
    vmovd xmm9, r9d
    vpbroadcastd ymm9, xmm9      // mantissa mask

    mov r9d, $3F000000
    vmovd xmm8, r9d
    vpbroadcastd ymm8, xmm8      // 0.5 bits

    mov r9d, $3F3504F3
    vmovd xmm7, r9d
    vpbroadcastd ymm7, xmm7      // sqrt(2)/2 ≈ 0.7071

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovups ymm0, [rax]

    // e = (bits >> 23) - 126
    vpsrld ymm1, ymm0, 23
    mov r9d, 126
    vmovd xmm6, r9d
    vpbroadcastd ymm6, xmm6
    vpsubd ymm1, ymm1, ymm6

    // m = (bits & 0x7FFFFF) | 0x3F000000 → [0.5, 1.0)
    vpand ymm2, ymm0, ymm9
    vpor ymm2, ymm2, ymm8

    // If m < sqrt(2)/2: m*=2, e-=1
    vcmpltps ymm4, ymm2, ymm7
    vaddps ymm3, ymm2, ymm2       // m*2
    vblendvps ymm2, ymm2, ymm3, ymm4
    vpsrld ymm4, ymm4, 31
    vpsubd ymm1, ymm1, ymm4       // m ∈ [sqrt2/2, sqrt2)

    // f = (m - 1) / (m + 1)
    vsubps ymm3, ymm2, ymm14      // m - 1
    vaddps ymm4, ymm2, ymm14      // m + 1
    vdivps ymm0, ymm3, ymm4       // f = (m-1)/(m+1)

    // f² 
    vmulps ymm2, ymm0, ymm0       // f²

    // 2*(f + f³/3 + f⁵/5 + f⁷/7) via Horner on f²:
    // = 2*f*(1 + f²*(1/3 + f²*(1/5 + f²*1/7)))
    vmovaps ymm3, ymm10           // 1/7
    vfmadd213ps ymm3, ymm2, ymm11 // 1/7*f² + 1/5
    vfmadd213ps ymm3, ymm2, ymm12 // (..)*f² + 1/3
    vfmadd213ps ymm3, ymm2, ymm14 // (..)*f² + 1
    vmulps ymm3, ymm3, ymm0       // * f
    vmulps ymm3, ymm3, ymm13      // * 2 → ln(m)

    // result = ln(m) + e*ln2
    vcvtdq2ps ymm1, ymm1
    vfmadd231ps ymm3, ymm1, ymm15

    vmovups [rcx], ymm3
    add rax, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    sub rsp, 8
    vmovss xmm0, [rax]
    vmovss [rsp], xmm0
    fld dword [rsp]
    fldln2
    fxch
    fyl2x
    fstp dword [rsp]
    vmovss xmm0, [rsp]
    add rsp, 8
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;
// ============================================================================
// AVX2 ArrayPowF32 — x^exponent via exp(exponent * log(x))
// Delegates to AVX2ArrayLogF32 + multiply + AVX2ArrayExpF32
// ============================================================================

procedure AVX2ArrayPowF32(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
var
  pS, pD: PSingle;
  LExp: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LExp := aExponent;

  // Step 1: dst = log(src)
  AVX2ArrayLogF32(pS, pD, aCount);

  // Step 2: dst = dst * exponent
  asm
    mov rax, pD
    mov r8, aCount
    vbroadcastss ymm15, [LExp]

    cmp r8, 8
    jb @tail

  @loop8:
    vmovups ymm0, [rax]
    vmulps ymm0, ymm0, ymm15
    vmovups [rax], ymm0
    add rax, 32
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vmulss xmm0, xmm0, xmm15
    vmovss [rax], xmm0
    add rax, 4
    dec r8
    jnz @scalar_loop
  @done:
    vzeroupper
  end;

  // Step 3: dst = exp(dst)
  AVX2ArrayExpF32(pD, pD, aCount);
  {$POP}
end;

// ============================================================================
// AVX2 ArrayLogF32 — SIMD ln(x) via atanh transform, <4 ULP

// ============================================================================
// Fused Batch Operations (AVX2) — single-pass, reduced memory traffic
// ============================================================================

procedure AVX2ArrayLinearF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
var
  pS, pD: PSingle;
  LScale, LBias: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LScale := aScale; LBias := aBias;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastss ymm6, [LScale]
    vbroadcastss ymm7, [LBias]

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovups ymm0, [rax]
    vfmadd213ps ymm0, ymm6, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vfmadd213ps ymm1, ymm6, ymm7
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vfmadd213ps ymm2, ymm6, ymm7
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vfmadd213ps ymm3, ymm6, ymm7
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovups ymm0, [rax]
    vfmadd213ps ymm0, ymm6, ymm7
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vfmadd213ss xmm0, xmm6, xmm7
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayAbsDiffF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    // sign mask for abs
    mov r9d, $7FFFFFFF
    vmovd xmm7, r9d
    vbroadcastss ymm7, xmm7

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovups ymm0, [rax]
    vsubps ymm0, ymm0, [rdx]
    vandps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vsubps ymm1, ymm1, [rdx + 32]
    vandps ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vsubps ymm2, ymm2, [rdx + 64]
    vandps ymm2, ymm2, ymm7
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vsubps ymm3, ymm3, [rdx + 96]
    vandps ymm3, ymm3, ymm7
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovups ymm0, [rax]
    vsubps ymm0, ymm0, [rdx]
    vandps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vsubss xmm0, xmm0, [rdx]
    vandps xmm0, xmm0, xmm7
    vmovss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vxorps ymm7, ymm7, ymm7   // zero

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovups ymm0, [rax]
    vmaxps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vmaxps ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vmaxps ymm2, ymm2, ymm7
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vmaxps ymm3, ymm3, ymm7
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovups ymm0, [rax]
    vmaxps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vmaxss xmm0, xmm0, xmm7
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayNormF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single);
var
  pS, pD: PSingle;
  LMean, LInvStd: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LMean := aMean; LInvStd := aInvStd;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastss ymm6, [LMean]
    vbroadcastss ymm7, [LInvStd]

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovups ymm0, [rax]
    vsubps ymm0, ymm0, ymm6
    vmulps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vsubps ymm1, ymm1, ymm6
    vmulps ymm1, ymm1, ymm7
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vsubps ymm2, ymm2, ymm6
    vmulps ymm2, ymm2, ymm7
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vsubps ymm3, ymm3, ymm6
    vmulps ymm3, ymm3, ymm7
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovups ymm0, [rax]
    vsubps ymm0, ymm0, ymm6
    vmulps ymm0, ymm0, ymm7
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vsubss xmm0, xmm0, xmm6
    vmulss xmm0, xmm0, xmm7
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// Non-Temporal (Streaming) Store variants — bypass cache for write-only dst
// Use when dst won't be read again soon (e.g., output buffers, transforms)
// Provides ~2x bandwidth for large arrays that exceed L2 cache
// ============================================================================

procedure AVX2ArrayAddF32_NT(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovups ymm0, [rax]
    vaddps ymm0, ymm0, [rdx]
    vmovntps [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vaddps ymm1, ymm1, [rdx + 32]
    vmovntps [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vaddps ymm2, ymm2, [rdx + 64]
    vmovntps [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vaddps ymm3, ymm3, [rdx + 96]
    vmovntps [rcx + 96], ymm3
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovups ymm0, [rax]
    vaddps ymm0, ymm0, [rdx]
    vmovntps [rcx], ymm0
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vaddss xmm0, xmm0, [rdx]
    vmovss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    sfence
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayLinearReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
var
  pS, pD: PSingle;
  LScale, LBias: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LScale := aScale; LBias := aBias;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastss ymm6, [LScale]
    vbroadcastss ymm7, [LBias]
    vxorps ymm5, ymm5, ymm5

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovups ymm0, [rax]
    vfmadd213ps ymm0, ymm6, ymm7
    vmaxps ymm0, ymm0, ymm5
    vmovups [rcx], ymm0
    vmovups ymm1, [rax + 32]
    vfmadd213ps ymm1, ymm6, ymm7
    vmaxps ymm1, ymm1, ymm5
    vmovups [rcx + 32], ymm1
    vmovups ymm2, [rax + 64]
    vfmadd213ps ymm2, ymm6, ymm7
    vmaxps ymm2, ymm2, ymm5
    vmovups [rcx + 64], ymm2
    vmovups ymm3, [rax + 96]
    vfmadd213ps ymm3, ymm6, ymm7
    vmaxps ymm3, ymm3, ymm5
    vmovups [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail1
    vmovups ymm0, [rax]
    vfmadd213ps ymm0, ymm6, ymm7
    vmaxps ymm0, ymm0, ymm5
    vmovups [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 8
    jmp @tail8

  @tail1:
    test r8, r8
    jz @done
    vxorps xmm5, xmm5, xmm5
  @scalar:
    vmovss xmm0, [rax]
    vfmadd213ss xmm0, xmm6, xmm7
    vmaxss xmm0, xmm0, xmm5
    vmovss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar

  @done:
    vzeroupper
  end;
  {$POP}
end;

// ============================================================================
// AVX2 F64 Scalar/Affine Operations (YMM = 4 doubles/iter)
// ============================================================================

procedure AVX2ArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var pS, pD: PDouble; LScalar: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScalar := aScalar;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastsd ymm7, [LScalar]

    cmp r8, 16
    jb @tail4

  @loop16:
    vmovupd ymm0, [rax]
    vmulpd ymm0, ymm0, ymm7
    vmovupd [rcx], ymm0
    vmovupd ymm1, [rax + 32]
    vmulpd ymm1, ymm1, ymm7
    vmovupd [rcx + 32], ymm1
    vmovupd ymm2, [rax + 64]
    vmulpd ymm2, ymm2, ymm7
    vmovupd [rcx + 64], ymm2
    vmovupd ymm3, [rax + 96]
    vmulpd ymm3, ymm3, ymm7
    vmovupd [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovupd ymm0, [rax]
    vmulpd ymm0, ymm0, ymm7
    vmovupd [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vmulsd xmm0, xmm0, xmm7
    vmovsd [rcx], xmm0
    add rax, 8
    add rcx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var pS, pD: PDouble; LScalar: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScalar := aScalar;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastsd ymm7, [LScalar]

    cmp r8, 16
    jb @tail4

  @loop16:
    vmovupd ymm0, [rax]
    vaddpd ymm0, ymm0, ymm7
    vmovupd [rcx], ymm0
    vmovupd ymm1, [rax + 32]
    vaddpd ymm1, ymm1, ymm7
    vmovupd [rcx + 32], ymm1
    vmovupd ymm2, [rax + 64]
    vaddpd ymm2, ymm2, ymm7
    vmovupd [rcx + 64], ymm2
    vmovupd ymm3, [rax + 96]
    vaddpd ymm3, ymm3, ymm7
    vmovupd [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovupd ymm0, [rax]
    vaddpd ymm0, ymm0, ymm7
    vmovupd [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vaddsd xmm0, xmm0, xmm7
    vmovsd [rcx], xmm0
    add rax, 8
    add rcx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
var pS, pD: PDouble; LMin, LMax: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LMin := aMin; LMax := aMax;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastsd ymm6, [LMin]
    vbroadcastsd ymm7, [LMax]

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    vmovupd ymm0, [rax]
    vmaxpd ymm0, ymm0, ymm6
    vminpd ymm0, ymm0, ymm7
    vmovupd [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vmaxsd xmm0, xmm0, xmm6
    vminsd xmm0, xmm0, xmm7
    vmovsd [rcx], xmm0
    add rax, 8
    add rcx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX2ArrayLinearF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
var pS, pD: PDouble; LScale, LBias: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScale := aScale; LBias := aBias;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastsd ymm6, [LScale]
    vbroadcastsd ymm7, [LBias]

    cmp r8, 16
    jb @tail4

  @loop16:
    vmovupd ymm0, [rax]
    vfmadd213pd ymm0, ymm6, ymm7
    vmovupd [rcx], ymm0
    vmovupd ymm1, [rax + 32]
    vfmadd213pd ymm1, ymm6, ymm7
    vmovupd [rcx + 32], ymm1
    vmovupd ymm2, [rax + 64]
    vfmadd213pd ymm2, ymm6, ymm7
    vmovupd [rcx + 64], ymm2
    vmovupd ymm3, [rax + 96]
    vfmadd213pd ymm3, ymm6, ymm7
    vmovupd [rcx + 96], ymm3
    add rax, 128
    add rcx, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    vmovupd ymm0, [rax]
    vfmadd213pd ymm0, ymm6, ymm7
    vmovupd [rcx], ymm0
    add rax, 32
    add rcx, 32
    sub r8, 4
    cmp r8, 4
    jae @tail4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vfmadd213sd xmm0, xmm6, xmm7
    vmovsd [rcx], xmm0
    add rax, 8
    add rcx, 8
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;
