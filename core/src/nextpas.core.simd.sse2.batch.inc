// ============================================================================
// SSE2 Batch Array Operations
// 策略: 主循环 2x 展开 (每次 8 个 float)，标量尾部处理剩余元素
// ============================================================================

procedure SSE2ArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1;
  pS2 := aSrc2;
  pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    addps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    addps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    addps xmm2, [rdx + 32]
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    addps xmm3, [rdx + 48]
    movups [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    addps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    addps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    addps xmm0, [rdx]
    movups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    addss xmm0, [rdx]
    movss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1;
  pS2 := aSrc2;
  pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    mulps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    mulps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    mulps xmm2, [rdx + 32]
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    mulps xmm3, [rdx + 48]
    movups [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    mulps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    mulps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    mulps xmm0, [rdx]
    movups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    mulss xmm0, [rdx]
    movss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var
  pS, pD: PSingle;
  LScalar: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;
  LScalar := aScalar;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movss xmm7, [LScalar]
    shufps xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    mulps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    mulps xmm1, xmm7
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    mulps xmm2, xmm7
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    mulps xmm3, xmm7
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    mulps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    mulps xmm1, xmm7
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    mulps xmm0, xmm7
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    mulss xmm0, xmm7
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var
  pS, pD: PSingle;
  LScalar: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;
  LScalar := aScalar;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movss xmm7, [LScalar]
    shufps xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    addps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    addps xmm1, xmm7
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    addps xmm2, xmm7
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    addps xmm3, xmm7
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    addps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    addps xmm1, xmm7
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    addps xmm0, xmm7
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    addss xmm0, xmm7
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
var
  pS, pD: PSingle;
  LMin, LMax: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;
  LMin := aMin;
  LMax := aMax;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movss xmm6, [LMin]
    shufps xmm6, xmm6, 0
    movss xmm7, [LMax]
    shufps xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    maxps xmm0, xmm6
    minps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    maxps xmm1, xmm6
    minps xmm1, xmm7
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    maxps xmm2, xmm6
    minps xmm2, xmm7
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    maxps xmm3, xmm6
    minps xmm3, xmm7
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    maxps xmm0, xmm6
    minps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    maxps xmm1, xmm6
    minps xmm1, xmm7
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    maxps xmm0, xmm6
    minps xmm0, xmm7
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    maxss xmm0, xmm6
    minss xmm0, xmm7
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
var
  pA, pB, pC, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pA := aA;
  pB := aB;
  pC := aC;
  pD := aDst;

  asm
    mov rax, pA
    mov rdx, pB
    mov rcx, pC
    mov r9, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    mulps xmm0, [rdx]
    addps xmm0, [rcx]
    movups [r9], xmm0
    movups xmm1, [rax + 16]
    mulps xmm1, [rdx + 16]
    addps xmm1, [rcx + 16]
    movups [r9 + 16], xmm1
    movups xmm2, [rax + 32]
    mulps xmm2, [rdx + 32]
    addps xmm2, [rcx + 32]
    movups [r9 + 32], xmm2
    movups xmm3, [rax + 48]
    mulps xmm3, [rdx + 48]
    addps xmm3, [rcx + 48]
    movups [r9 + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    add r9, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    mulps xmm0, [rdx]
    addps xmm0, [rcx]
    movups [r9], xmm0
    movups xmm1, [rax + 16]
    mulps xmm1, [rdx + 16]
    addps xmm1, [rcx + 16]
    movups [r9 + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    add r9, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    mulps xmm0, [rdx]
    addps xmm0, [rcx]
    movups [r9], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    add r9, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    mulss xmm0, [rdx]
    addss xmm0, [rcx]
    movss [r9], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    add r9, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
var
  pX, pY, pD: PSingle;
  LAlpha: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pX := aX;
  pY := aY;
  pD := aDst;
  LAlpha := aAlpha;

  asm
    mov rax, pX
    mov rdx, pY
    mov rcx, pD
    mov r8, aCount
    movss xmm7, [LAlpha]
    shufps xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    mulps xmm0, xmm7
    addps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    mulps xmm1, xmm7
    addps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    mulps xmm2, xmm7
    addps xmm2, [rdx + 32]
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    mulps xmm3, xmm7
    addps xmm3, [rdx + 48]
    movups [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    mulps xmm0, xmm7
    addps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    mulps xmm1, xmm7
    addps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    mulps xmm0, xmm7
    addps xmm0, [rdx]
    movups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    mulss xmm0, xmm7
    addss xmm0, [rdx]
    movss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

function SSE2ReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  pS: PSingle;
  LResult: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc;
  LResult := 0;

  asm
    mov rax, pS
    mov r8, aCount
    xorps xmm0, xmm0
    xorps xmm1, xmm1
    xorps xmm2, xmm2
    xorps xmm3, xmm3

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm4, [rax]
    addps xmm0, xmm4
    movups xmm5, [rax + 16]
    addps xmm1, xmm5
    movups xmm6, [rax + 32]
    addps xmm2, xmm6
    movups xmm7, [rax + 48]
    addps xmm3, xmm7
    add rax, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm4, [rax]
    addps xmm0, xmm4
    movups xmm5, [rax + 16]
    addps xmm1, xmm5
    add rax, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @reduce
    movups xmm4, [rax]
    addps xmm0, xmm4
    add rax, 16
    sub r8, 4

  @reduce:
    addps xmm0, xmm1
    addps xmm2, xmm3
    addps xmm0, xmm2
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $4E
    addps xmm0, xmm1
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $B1
    addss xmm0, xmm1
    movss LResult, xmm0

    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm1, [rax]
    addss xmm0, xmm1
    movss LResult, xmm0
    add rax, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;

  Result := LResult;
  {$POP}
end;

function SSE2ReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
var
  pS1, pS2: PSingle;
  LResult: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS1 := aSrc1;
  pS2 := aSrc2;
  LResult := 0;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov r8, aCount
    xorps xmm0, xmm0
    xorps xmm1, xmm1
    xorps xmm2, xmm2
    xorps xmm3, xmm3

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm4, [rax]
    mulps xmm4, [rdx]
    addps xmm0, xmm4
    movups xmm5, [rax + 16]
    mulps xmm5, [rdx + 16]
    addps xmm1, xmm5
    movups xmm6, [rax + 32]
    mulps xmm6, [rdx + 32]
    addps xmm2, xmm6
    movups xmm7, [rax + 48]
    mulps xmm7, [rdx + 48]
    addps xmm3, xmm7
    add rax, 64
    add rdx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm4, [rax]
    mulps xmm4, [rdx]
    addps xmm0, xmm4
    movups xmm5, [rax + 16]
    mulps xmm5, [rdx + 16]
    addps xmm1, xmm5
    add rax, 32
    add rdx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @reduce
    movups xmm4, [rax]
    mulps xmm4, [rdx]
    addps xmm0, xmm4
    add rax, 16
    add rdx, 16
    sub r8, 4

  @reduce:
    addps xmm0, xmm1
    addps xmm2, xmm3
    addps xmm0, xmm2
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $4E
    addps xmm0, xmm1
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $B1
    addss xmm0, xmm1
    movss LResult, xmm0

    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm1, [rax]
    mulss xmm1, [rdx]
    addss xmm0, xmm1
    movss LResult, xmm0
    add rax, 4
    add rdx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;

  Result := LResult;
  {$POP}
end;

procedure SSE2ArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1;
  pS2 := aSrc2;
  pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    subps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    subps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    subps xmm2, [rdx + 32]
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    subps xmm3, [rdx + 48]
    movups [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    subps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    subps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    subps xmm0, [rdx]
    movups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    subss xmm0, [rdx]
    movss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1;
  pS2 := aSrc2;
  pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    divps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    divps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    divps xmm2, [rdx + 32]
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    divps xmm3, [rdx + 48]
    movups [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    divps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    divps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    divps xmm0, [rdx]
    movups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    divss xmm0, [rdx]
    movss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    mov r9d, $7FFFFFFF
    movd xmm7, r9d
    pshufd xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    andps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    andps xmm1, xmm7
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    andps xmm2, xmm7
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    andps xmm3, xmm7
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    andps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    andps xmm1, xmm7
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    andps xmm0, xmm7
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    andps xmm0, xmm7
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    mov r9d, $80000000
    movd xmm7, r9d
    pshufd xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    xorps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    xorps xmm1, xmm7
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    xorps xmm2, xmm7
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    xorps xmm3, xmm7
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    xorps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    xorps xmm1, xmm7
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    xorps xmm0, xmm7
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    xorps xmm0, xmm7
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    sqrtps xmm0, xmm0
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    sqrtps xmm1, xmm1
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    sqrtps xmm2, xmm2
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    sqrtps xmm3, xmm3
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    sqrtps xmm0, xmm0
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    sqrtps xmm1, xmm1
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    sqrtps xmm0, xmm0
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    sqrtss xmm0, xmm0
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    mov r9d, $3F800000
    movd xmm7, r9d
    pshufd xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    rcpps xmm0, xmm0
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    rcpps xmm1, xmm1
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    rcpps xmm2, xmm2
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    rcpps xmm3, xmm3
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    rcpps xmm0, xmm0
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    rcpps xmm1, xmm1
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    rcpps xmm0, xmm0
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movaps xmm0, xmm7
    divss xmm0, [rax]
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    mov r9d, $3F800000
    movd xmm7, r9d
    pshufd xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    rsqrtps xmm0, xmm0
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    rsqrtps xmm1, xmm1
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    rsqrtps xmm2, xmm2
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    rsqrtps xmm3, xmm3
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    rsqrtps xmm0, xmm0
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    rsqrtps xmm1, xmm1
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    rsqrtps xmm0, xmm0
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    sqrtss xmm0, xmm0
    movaps xmm1, xmm7
    divss xmm1, xmm0
    movss [rcx], xmm1
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1;
  pS2 := aSrc2;
  pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    minps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    minps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    minps xmm2, [rdx + 32]
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    minps xmm3, [rdx + 48]
    movups [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    minps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    minps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    minps xmm0, [rdx]
    movups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    minss xmm0, [rdx]
    movss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1;
  pS2 := aSrc2;
  pD := aDst;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    maxps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    maxps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    maxps xmm2, [rdx + 32]
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    maxps xmm3, [rdx + 48]
    movups [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    maxps xmm0, [rdx]
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    maxps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    maxps xmm0, [rdx]
    movups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    maxss xmm0, [rdx]
    movss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

// ============================================================================
// SSE2 F64 Batch Array Operations
// 策略: 2x XMM 展开 (每轮 4 double = 32 bytes), 标量尾部
// ============================================================================

procedure SSE2ArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;
  i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      mov    r9, $7FFFFFFFFFFFFFFF
      movq   xmm7, r9
      pshufd xmm7, xmm7, $44
      movupd xmm0, [rax + r8]
      andpd  xmm0, xmm7
      movupd [rcx + r8], xmm0
      movupd xmm1, [rax + r8 + 16]
      andpd  xmm1, xmm7
      movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;

  if i + 2 <= aCount then
  begin
    asm
      mov    rax, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      mov    r9, $7FFFFFFFFFFFFFFF
      movq   xmm7, r9
      pshufd xmm7, xmm7, $44
      movupd xmm0, [rax + r8]
      andpd  xmm0, xmm7
      movupd [rcx + r8], xmm0
    end;
    Inc(i, 2);
  end;

  while i < aCount do
  begin
    PQWord(@pD[i])^ := PQWord(@pS[i])^ and QWord($7FFFFFFFFFFFFFFF);
    Inc(i);
  end;
  {$POP}
end;

procedure SSE2ArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;
  i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      mov    r9, $8000000000000000
      movq   xmm7, r9
      pshufd xmm7, xmm7, $44
      movupd xmm0, [rax + r8]
      xorpd  xmm0, xmm7
      movupd [rcx + r8], xmm0
      movupd xmm1, [rax + r8 + 16]
      xorpd  xmm1, xmm7
      movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;

  if i + 2 <= aCount then
  begin
    asm
      mov    rax, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      mov    r9, $8000000000000000
      movq   xmm7, r9
      pshufd xmm7, xmm7, $44
      movupd xmm0, [rax + r8]
      xorpd  xmm0, xmm7
      movupd [rcx + r8], xmm0
    end;
    Inc(i, 2);
  end;

  while i < aCount do
  begin
    PQWord(@pD[i])^ := PQWord(@pS[i])^ xor QWord($8000000000000000);
    Inc(i);
  end;
  {$POP}
end;

procedure SSE2ArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;
  i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      movupd xmm0, [rax + r8]
      sqrtpd xmm0, xmm0
      movupd [rcx + r8], xmm0
      movupd xmm1, [rax + r8 + 16]
      sqrtpd xmm1, xmm1
      movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;

  if i + 2 <= aCount then
  begin
    asm
      mov    rax, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      movupd xmm0, [rax + r8]
      sqrtpd xmm0, xmm0
      movupd [rcx + r8], xmm0
    end;
    Inc(i, 2);
  end;

  while i < aCount do
  begin
    pD[i] := System.Sqrt(pS[i]);
    Inc(i);
  end;
  {$POP}
end;

// ============================================================================
// SSE2 F64 Batch Array Operations
// 策略: 2x XMM 展开 (每轮 4 double = 32 bytes)
// ============================================================================

procedure SSE2ArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt; pS1, pS2, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst; i := 0;
  while i + 4 <= aCount do begin
    asm
      mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, i; shl r8, 3
      movupd xmm0, [rax + r8]; addpd xmm0, [rdx + r8]; movupd [rcx + r8], xmm0
      movupd xmm1, [rax + r8 + 16]; addpd xmm1, [rdx + r8 + 16]; movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;
  while i < aCount do begin pD[i] := pS1[i] + pS2[i]; Inc(i); end;
  {$POP}
end;

procedure SSE2ArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt; pS1, pS2, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst; i := 0;
  while i + 4 <= aCount do begin
    asm
      mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, i; shl r8, 3
      movupd xmm0, [rax + r8]; subpd xmm0, [rdx + r8]; movupd [rcx + r8], xmm0
      movupd xmm1, [rax + r8 + 16]; subpd xmm1, [rdx + r8 + 16]; movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;
  while i < aCount do begin pD[i] := pS1[i] - pS2[i]; Inc(i); end;
  {$POP}
end;

procedure SSE2ArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt; pS1, pS2, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst; i := 0;
  while i + 4 <= aCount do begin
    asm
      mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, i; shl r8, 3
      movupd xmm0, [rax + r8]; mulpd xmm0, [rdx + r8]; movupd [rcx + r8], xmm0
      movupd xmm1, [rax + r8 + 16]; mulpd xmm1, [rdx + r8 + 16]; movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;
  while i < aCount do begin pD[i] := pS1[i] * pS2[i]; Inc(i); end;
  {$POP}
end;

procedure SSE2ArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt; pS1, pS2, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst; i := 0;
  while i + 4 <= aCount do begin
    asm
      mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, i; shl r8, 3
      movupd xmm0, [rax + r8]; divpd xmm0, [rdx + r8]; movupd [rcx + r8], xmm0
      movupd xmm1, [rax + r8 + 16]; divpd xmm1, [rdx + r8 + 16]; movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;
  while i < aCount do begin pD[i] := pS1[i] / pS2[i]; Inc(i); end;
  {$POP}
end;

// ============================================================================
// SSE2 Integer Batch Array Operations
// paddd (4x I32), psubd, pmullw (8x I16), pand, por, pxor, pslld, psrad
// ============================================================================

procedure SSE2ArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var pS1, pS2, pD: PInt32;
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
    jb @tail8

  @loop16:
    movdqu xmm0, [rax]
    paddd xmm0, [rdx]
    movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]
    paddd xmm1, [rdx + 16]
    movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]
    paddd xmm2, [rdx + 32]
    movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]
    paddd xmm3, [rdx + 48]
    movdqu [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movdqu xmm0, [rax]
    paddd xmm0, [rdx]
    movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]
    paddd xmm1, [rdx + 16]
    movdqu [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movdqu xmm0, [rax]
    paddd xmm0, [rdx]
    movdqu [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

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
  end;
  {$POP}
end;

procedure SSE2ArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var pS1, pS2, pD: PInt32;
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
    jb @tail8

  @loop16:
    movdqu xmm0, [rax]
    psubd xmm0, [rdx]
    movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]
    psubd xmm1, [rdx + 16]
    movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]
    psubd xmm2, [rdx + 32]
    movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]
    psubd xmm3, [rdx + 48]
    movdqu [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movdqu xmm0, [rax]
    psubd xmm0, [rdx]
    movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]
    psubd xmm1, [rdx + 16]
    movdqu [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movdqu xmm0, [rax]
    psubd xmm0, [rdx]
    movdqu [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

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
  end;
  {$POP}
end;

procedure SSE2ArrayMulI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
var i: SizeUInt; pS1, pS2, pD: PInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst; i := 0;
  while i + 8 <= aCount do begin
    asm
      mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, i; shl r8, 1
      movdqu xmm0, [rax + r8]; pmullw xmm0, [rdx + r8]; movdqu [rcx + r8], xmm0
    end;
    Inc(i, 8);
  end;
  while i < aCount do begin pD[i] := Int16(Int32(pS1[i]) * Int32(pS2[i])); Inc(i); end;
  {$POP}
end;

procedure SSE2ArrayAndI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var pS1, pS2, pD: PInt32;
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
    jb @tail8

  @loop16:
    movdqu xmm0, [rax]
    pand xmm0, [rdx]
    movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]
    pand xmm1, [rdx + 16]
    movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]
    pand xmm2, [rdx + 32]
    movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]
    pand xmm3, [rdx + 48]
    movdqu [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movdqu xmm0, [rax]
    pand xmm0, [rdx]
    movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]
    pand xmm1, [rdx + 16]
    movdqu [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movdqu xmm0, [rax]
    pand xmm0, [rdx]
    movdqu [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

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
  end;
  {$POP}
end;

procedure SSE2ArrayOrI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var pS1, pS2, pD: PInt32;
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
    jb @tail8

  @loop16:
    movdqu xmm0, [rax]
    por xmm0, [rdx]
    movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]
    por xmm1, [rdx + 16]
    movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]
    por xmm2, [rdx + 32]
    movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]
    por xmm3, [rdx + 48]
    movdqu [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movdqu xmm0, [rax]
    por xmm0, [rdx]
    movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]
    por xmm1, [rdx + 16]
    movdqu [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movdqu xmm0, [rax]
    por xmm0, [rdx]
    movdqu [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

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
  end;
  {$POP}
end;

procedure SSE2ArrayXorI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var pS1, pS2, pD: PInt32;
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
    jb @tail8

  @loop16:
    movdqu xmm0, [rax]
    pxor xmm0, [rdx]
    movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]
    pxor xmm1, [rdx + 16]
    movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]
    pxor xmm2, [rdx + 32]
    movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]
    pxor xmm3, [rdx + 48]
    movdqu [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movdqu xmm0, [rax]
    pxor xmm0, [rdx]
    movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]
    pxor xmm1, [rdx + 16]
    movdqu [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movdqu xmm0, [rax]
    pxor xmm0, [rdx]
    movdqu [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

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
  end;
  {$POP}
end;

procedure SSE2ArrayShlI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
var pS, pD: PInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rdx, pD
    mov r8, aCount
    mov r10d, aShift
    movd xmm7, r10d

    cmp r8, 16
    jb @tail8

  @loop16:
    movdqu xmm0, [rax]
    pslld xmm0, xmm7
    movdqu [rdx], xmm0
    movdqu xmm1, [rax + 16]
    pslld xmm1, xmm7
    movdqu [rdx + 16], xmm1
    movdqu xmm2, [rax + 32]
    pslld xmm2, xmm7
    movdqu [rdx + 32], xmm2
    movdqu xmm3, [rax + 48]
    pslld xmm3, xmm7
    movdqu [rdx + 48], xmm3
    add rax, 64
    add rdx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movdqu xmm0, [rax]
    pslld xmm0, xmm7
    movdqu [rdx], xmm0
    movdqu xmm1, [rax + 16]
    pslld xmm1, xmm7
    movdqu [rdx + 16], xmm1
    add rax, 32
    add rdx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movdqu xmm0, [rax]
    pslld xmm0, xmm7
    movdqu [rdx], xmm0
    add rax, 16
    add rdx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    mov r9d, [rax]
    mov ecx, r10d
    shl r9d, cl
    mov [rdx], r9d
    add rax, 4
    add rdx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayShrI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
var pS, pD: PInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rdx, pD
    mov r8, aCount
    mov r10d, aShift
    movd xmm7, r10d

    cmp r8, 16
    jb @tail8

  @loop16:
    movdqu xmm0, [rax]
    psrad xmm0, xmm7
    movdqu [rdx], xmm0
    movdqu xmm1, [rax + 16]
    psrad xmm1, xmm7
    movdqu [rdx + 16], xmm1
    movdqu xmm2, [rax + 32]
    psrad xmm2, xmm7
    movdqu [rdx + 32], xmm2
    movdqu xmm3, [rax + 48]
    psrad xmm3, xmm7
    movdqu [rdx + 48], xmm3
    add rax, 64
    add rdx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movdqu xmm0, [rax]
    psrad xmm0, xmm7
    movdqu [rdx], xmm0
    movdqu xmm1, [rax + 16]
    psrad xmm1, xmm7
    movdqu [rdx + 16], xmm1
    add rax, 32
    add rdx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movdqu xmm0, [rax]
    psrad xmm0, xmm7
    movdqu [rdx], xmm0
    add rax, 16
    add rdx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    mov r9d, [rax]
    mov ecx, r10d
    sar r9d, cl
    mov [rdx], r9d
    add rax, 4
    add rdx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

// ============================================================================
// SSE2 Type Conversion
// cvtps2dq (F32→I32), cvtdq2ps (I32→F32)
// ============================================================================

procedure SSE2ArrayF32toI32(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt);
var pS: PSingle; pD: PInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    cvtps2dq xmm0, xmm0
    movdqu [rcx], xmm0
    movups xmm1, [rax + 16]
    cvtps2dq xmm1, xmm1
    movdqu [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    cvtps2dq xmm2, xmm2
    movdqu [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    cvtps2dq xmm3, xmm3
    movdqu [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    cvtps2dq xmm0, xmm0
    movdqu [rcx], xmm0
    movups xmm1, [rax + 16]
    cvtps2dq xmm1, xmm1
    movdqu [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    cvtps2dq xmm0, xmm0
    movdqu [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    cvtss2si r9d, [rax]
    mov [rcx], r9d
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayI32toF32(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt);
var pS: PInt32; pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail8

  @loop16:
    movdqu xmm0, [rax]
    cvtdq2ps xmm0, xmm0
    movups [rcx], xmm0
    movdqu xmm1, [rax + 16]
    cvtdq2ps xmm1, xmm1
    movups [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]
    cvtdq2ps xmm2, xmm2
    movups [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]
    cvtdq2ps xmm3, xmm3
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movdqu xmm0, [rax]
    cvtdq2ps xmm0, xmm0
    movups [rcx], xmm0
    movdqu xmm1, [rax + 16]
    cvtdq2ps xmm1, xmm1
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movdqu xmm0, [rax]
    cvtdq2ps xmm0, xmm0
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    cvtsi2ss xmm0, [rax]
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

// ============================================================================
// SSE2 Reduction Operations (F64/F32)
// 策略: 4 路累加器隐藏延迟, movhlps + addsd/minss 水平归约
// ============================================================================

function SSE2ReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double;
var
  pS: PDouble;
  LResult: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc; LResult := 0;

  asm
    mov rax, pS
    mov r8, aCount
    xorpd xmm0, xmm0
    xorpd xmm1, xmm1
    xorpd xmm2, xmm2
    xorpd xmm3, xmm3

    cmp r8, 8
    jb @tail2

  @loop8:
    movupd xmm4, [rax]
    addpd xmm0, xmm4
    movupd xmm5, [rax + 16]
    addpd xmm1, xmm5
    movupd xmm6, [rax + 32]
    addpd xmm2, xmm6
    movupd xmm7, [rax + 48]
    addpd xmm3, xmm7
    add rax, 64
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail2:
    cmp r8, 2
    jb @tail_scalar
    movupd xmm4, [rax]
    addpd xmm0, xmm4
    add rax, 16
    sub r8, 2
    cmp r8, 2
    jae @tail2

  @tail_scalar:
    test r8, r8
    jz @reduce
    movsd xmm4, [rax]
    addsd xmm0, xmm4

  @reduce:
    addpd xmm0, xmm2
    addpd xmm1, xmm3
    addpd xmm0, xmm1
    movhlps xmm1, xmm0
    addsd xmm0, xmm1
    movlps LResult, xmm0
  end;

  Result := LResult;
  {$POP}
end;

function SSE2ReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  pS: PSingle;
  LResult: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc; LResult := pS[0];

  asm
    mov rax, pS
    mov r8, aCount

    movups xmm0, [rax]
    movaps xmm1, xmm0

    cmp r8, 8
    jb @tail4
    add rax, 16
    sub r8, 4

  @loop8:
    cmp r8, 8
    jb @tail4_post
    movups xmm2, [rax]
    minps xmm0, xmm2
    movups xmm3, [rax + 16]
    minps xmm1, xmm3
    add rax, 32
    sub r8, 8
    jmp @loop8

  @tail4_post:
    minps xmm0, xmm1

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm2, [rax]
    minps xmm0, xmm2
    add rax, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @reduce
  @scalar_loop:
    movss xmm2, [rax]
    minss xmm0, xmm2
    add rax, 4
    dec r8
    jnz @scalar_loop

  @reduce:
    movhlps xmm1, xmm0
    minps xmm0, xmm1
    pshufd xmm1, xmm0, $01
    minss xmm0, xmm1
    movss LResult, xmm0
  end;

  Result := LResult;
  {$POP}
end;

function SSE2ReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
var
  pS1, pS2: PDouble;
  LResult: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS1 := aSrc1; pS2 := aSrc2; LResult := 0;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov r8, aCount
    xorpd xmm0, xmm0
    xorpd xmm1, xmm1
    xorpd xmm2, xmm2
    xorpd xmm3, xmm3

    cmp r8, 8
    jb @tail2

  @loop8:
    movupd xmm4, [rax]
    mulpd xmm4, [rdx]
    addpd xmm0, xmm4
    movupd xmm5, [rax + 16]
    mulpd xmm5, [rdx + 16]
    addpd xmm1, xmm5
    movupd xmm6, [rax + 32]
    mulpd xmm6, [rdx + 32]
    addpd xmm2, xmm6
    movupd xmm7, [rax + 48]
    mulpd xmm7, [rdx + 48]
    addpd xmm3, xmm7
    add rax, 64
    add rdx, 64
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail2:
    cmp r8, 2
    jb @tail_scalar
    movupd xmm4, [rax]
    mulpd xmm4, [rdx]
    addpd xmm0, xmm4
    add rax, 16
    add rdx, 16
    sub r8, 2
    cmp r8, 2
    jae @tail2

  @tail_scalar:
    test r8, r8
    jz @reduce
    movsd xmm4, [rax]
    mulsd xmm4, [rdx]
    addsd xmm0, xmm4

  @reduce:
    addpd xmm0, xmm2
    addpd xmm1, xmm3
    addpd xmm0, xmm1
    movhlps xmm1, xmm0
    addsd xmm0, xmm1
    movlps LResult, xmm0
  end;

  Result := LResult;
  {$POP}
end;

// ============================================================================
// SSE2 PackSatI32toI16 + NR Refine + ReduceMinF64
// ============================================================================

procedure SSE2ArrayPackSatI32toI16(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt);
var pS: PInt32; pD: PInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail8

  @loop16:
    movdqu xmm0, [rax]
    movdqu xmm1, [rax + 16]
    packssdw xmm0, xmm1
    movdqu [rcx], xmm0
    movdqu xmm2, [rax + 32]
    movdqu xmm3, [rax + 48]
    packssdw xmm2, xmm3
    movdqu [rcx + 16], xmm2
    add rax, 64
    add rcx, 32
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movdqu xmm0, [rax]
    movdqu xmm1, [rax + 16]
    packssdw xmm0, xmm1
    movdqu [rcx], xmm0
    add rax, 32
    add rcx, 16
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movdqu xmm0, [rax]
    packssdw xmm0, xmm0
    movq [rcx], xmm0
    add rax, 16
    add rcx, 8
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    mov r9d, [rax]
    cmp r9d, 32767
    jle @check_min
    mov r10d, 32767
    mov [rcx], r10w
    jmp @next_scalar
  @check_min:
    cmp r9d, -32768
    jge @store_value
    mov r10d, -32768
    mov [rcx], r10w
    jmp @next_scalar
  @store_value:
    mov [rcx], r9w
  @next_scalar:
    add rax, 4
    add rcx, 2
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayRcpRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    mov r9d, $40000000
    movd xmm6, r9d
    pshufd xmm6, xmm6, 0
    mov r9d, $3F800000
    movd xmm7, r9d
    pshufd xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    rcpps xmm1, xmm0
    movaps xmm2, xmm6
    movaps xmm3, xmm0
    mulps xmm3, xmm1
    subps xmm2, xmm3
    mulps xmm1, xmm2
    movups [rcx], xmm1

    movups xmm0, [rax + 16]
    rcpps xmm1, xmm0
    movaps xmm2, xmm6
    movaps xmm3, xmm0
    mulps xmm3, xmm1
    subps xmm2, xmm3
    mulps xmm1, xmm2
    movups [rcx + 16], xmm1

    movups xmm0, [rax + 32]
    rcpps xmm1, xmm0
    movaps xmm2, xmm6
    movaps xmm3, xmm0
    mulps xmm3, xmm1
    subps xmm2, xmm3
    mulps xmm1, xmm2
    movups [rcx + 32], xmm1

    movups xmm0, [rax + 48]
    rcpps xmm1, xmm0
    movaps xmm2, xmm6
    movaps xmm3, xmm0
    mulps xmm3, xmm1
    subps xmm2, xmm3
    mulps xmm1, xmm2
    movups [rcx + 48], xmm1

    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    rcpps xmm1, xmm0
    movaps xmm2, xmm6
    movaps xmm3, xmm0
    mulps xmm3, xmm1
    subps xmm2, xmm3
    mulps xmm1, xmm2
    movups [rcx], xmm1
    movups xmm0, [rax + 16]
    rcpps xmm1, xmm0
    movaps xmm2, xmm6
    movaps xmm3, xmm0
    mulps xmm3, xmm1
    subps xmm2, xmm3
    mulps xmm1, xmm2
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    rcpps xmm1, xmm0
    movaps xmm2, xmm6
    movaps xmm3, xmm0
    mulps xmm3, xmm1
    subps xmm2, xmm3
    mulps xmm1, xmm2
    movups [rcx], xmm1
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movaps xmm0, xmm7
    divss xmm0, [rax]
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayRsqrtRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    mov r9d, $3F800000
    movd xmm5, r9d
    pshufd xmm5, xmm5, 0
    mov r9d, $3F000000
    movd xmm6, r9d
    pshufd xmm6, xmm6, 0
    mov r9d, $40400000
    movd xmm7, r9d
    pshufd xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    rsqrtps xmm1, xmm0
    movaps xmm2, xmm1
    mulps xmm2, xmm2
    mulps xmm2, xmm0
    movaps xmm3, xmm7
    subps xmm3, xmm2
    mulps xmm1, xmm3
    mulps xmm1, xmm6
    movups [rcx], xmm1

    movups xmm0, [rax + 16]
    rsqrtps xmm1, xmm0
    movaps xmm2, xmm1
    mulps xmm2, xmm2
    mulps xmm2, xmm0
    movaps xmm3, xmm7
    subps xmm3, xmm2
    mulps xmm1, xmm3
    mulps xmm1, xmm6
    movups [rcx + 16], xmm1

    movups xmm0, [rax + 32]
    rsqrtps xmm1, xmm0
    movaps xmm2, xmm1
    mulps xmm2, xmm2
    mulps xmm2, xmm0
    movaps xmm3, xmm7
    subps xmm3, xmm2
    mulps xmm1, xmm3
    mulps xmm1, xmm6
    movups [rcx + 32], xmm1

    movups xmm0, [rax + 48]
    rsqrtps xmm1, xmm0
    movaps xmm2, xmm1
    mulps xmm2, xmm2
    mulps xmm2, xmm0
    movaps xmm3, xmm7
    subps xmm3, xmm2
    mulps xmm1, xmm3
    mulps xmm1, xmm6
    movups [rcx + 48], xmm1

    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    rsqrtps xmm1, xmm0
    movaps xmm2, xmm1
    mulps xmm2, xmm2
    mulps xmm2, xmm0
    movaps xmm3, xmm7
    subps xmm3, xmm2
    mulps xmm1, xmm3
    mulps xmm1, xmm6
    movups [rcx], xmm1
    movups xmm0, [rax + 16]
    rsqrtps xmm1, xmm0
    movaps xmm2, xmm1
    mulps xmm2, xmm2
    mulps xmm2, xmm0
    movaps xmm3, xmm7
    subps xmm3, xmm2
    mulps xmm1, xmm3
    mulps xmm1, xmm6
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    rsqrtps xmm1, xmm0
    movaps xmm2, xmm1
    mulps xmm2, xmm2
    mulps xmm2, xmm0
    movaps xmm3, xmm7
    subps xmm3, xmm2
    mulps xmm1, xmm3
    mulps xmm1, xmm6
    movups [rcx], xmm1
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    sqrtss xmm0, xmm0
    movaps xmm1, xmm5
    divss xmm1, xmm0
    movss [rcx], xmm1
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

function SSE2ReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double;
var pS: PDouble; LResult: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc;

  asm
    mov rax, pS
    mov r8, aCount

    movupd xmm0, [rax]       // init with first 2 elements (or 1)
    cmp r8, 2
    jb @single_init
    add rax, 16
    sub r8, 2
    jmp @check_loop
  @single_init:
    movsd xmm0, [rax]
    movlhps xmm0, xmm0       // duplicate to both lanes
    add rax, 8
    dec r8

  @check_loop:
    cmp r8, 4
    jb @tail2

  @loop4:
    movupd xmm1, [rax]
    minpd xmm0, xmm1
    movupd xmm2, [rax + 16]
    minpd xmm0, xmm2
    add rax, 32
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail2:
    cmp r8, 2
    jb @tail_scalar
    movupd xmm1, [rax]
    minpd xmm0, xmm1
    add rax, 16
    sub r8, 2

  @tail_scalar:
    test r8, r8
    jz @reduce
    movsd xmm1, [rax]
    minsd xmm0, xmm1

  @reduce:
    movhlps xmm1, xmm0
    minsd xmm0, xmm1
    movlps LResult, xmm0
  end;

  Result := LResult;
  {$POP}
end;

// ============================================================================
// SSE2 Transcendental Functions (no FMA — use mul+add)
// ============================================================================

procedure SSE2ArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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

    movss xmm15, [LLog2e]
    shufps xmm15, xmm15, 0
    movss xmm14, [LLn2Hi]
    shufps xmm14, xmm14, 0
    movss xmm13, [LLn2Lo]
    shufps xmm13, xmm13, 0
    movss xmm12, [LP6]
    shufps xmm12, xmm12, 0
    movss xmm11, [LP5]
    shufps xmm11, xmm11, 0
    movss xmm10, [LP4]
    shufps xmm10, xmm10, 0
    movss xmm9, [LP3]
    shufps xmm9, xmm9, 0
    movss xmm8, [LP2]
    shufps xmm8, xmm8, 0
    movss xmm7, [LMaxX]
    shufps xmm7, xmm7, 0
    movss xmm6, [LMinX]
    shufps xmm6, xmm6, 0

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]
    minps xmm0, xmm7
    maxps xmm0, xmm6

    // n = round(x * log2e)
    movaps xmm1, xmm0
    mulps xmm1, xmm15
    // SSE2 round: cvtps2dq rounds to nearest (MXCSR)
    cvtps2dq xmm1, xmm1
    cvtdq2ps xmm2, xmm1      // n as float

    // r = x - n*ln2
    movaps xmm3, xmm2
    mulps xmm3, xmm14
    subps xmm0, xmm3
    movaps xmm3, xmm2
    mulps xmm3, xmm13
    subps xmm0, xmm3          // r

    // Horner (no FMA): poly = ((((c6*r + c5)*r + c4)*r + c3)*r + c2)*r + c1)*r + c0
    movaps xmm2, xmm12       // c6
    mulps xmm2, xmm0
    addps xmm2, xmm11        // c6*r + c5
    mulps xmm2, xmm0
    addps xmm2, xmm10        // *r + c4
    mulps xmm2, xmm0
    addps xmm2, xmm9         // *r + c3
    mulps xmm2, xmm0
    addps xmm2, xmm8         // *r + c2
    mulps xmm2, xmm0
    // + c1 (1.0)
    movss xmm3, [LP1]
    shufps xmm3, xmm3, 0
    addps xmm2, xmm3
    mulps xmm2, xmm0
    // + c0 (1.0)
    movss xmm3, [LP0]
    shufps xmm3, xmm3, 0
    addps xmm2, xmm3

    // 2^n
    cvtps2dq xmm1, [rax]     // reload... no, we have n in xmm1 already (int)
    // Actually xmm1 still has n as int from cvtps2dq above
    // Wait, we did cvtps2dq xmm1, xmm1 then cvtdq2ps xmm2, xmm1
    // So xmm1 still has n as int32!
    pslld xmm1, 23
    paddd xmm2, xmm1

    movups [rcx], xmm2
    add rax, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    minss xmm0, xmm7
    maxss xmm0, xmm6
    movaps xmm1, xmm0
    mulss xmm1, xmm15
    cvtss2si r9d, xmm1
    cvtsi2ss xmm2, r9d
    movaps xmm3, xmm2
    mulss xmm3, xmm14
    subss xmm0, xmm3
    movaps xmm3, xmm2
    mulss xmm3, xmm13
    subss xmm0, xmm3
    // Horner scalar
    movaps xmm2, xmm12
    mulss xmm2, xmm0
    addss xmm2, xmm11
    mulss xmm2, xmm0
    addss xmm2, xmm10
    mulss xmm2, xmm0
    addss xmm2, xmm9
    mulss xmm2, xmm0
    addss xmm2, xmm8
    mulss xmm2, xmm0
    movss xmm3, [LP1]
    addss xmm2, xmm3
    mulss xmm2, xmm0
    movss xmm3, [LP0]
    addss xmm2, xmm3
    shl r9d, 23
    movd xmm1, r9d
    paddd xmm2, xmm1
    movss [rcx], xmm2
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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
  LThirdInv := 0.333333333333333;
  LFifthInv := 0.2;
  LSeventhInv := 0.142857142857143;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    movss xmm15, [LLn2]
    shufps xmm15, xmm15, 0
    movss xmm14, [LOne]
    shufps xmm14, xmm14, 0
    movss xmm13, [LTwo]
    shufps xmm13, xmm13, 0
    movss xmm12, [LThirdInv]
    shufps xmm12, xmm12, 0
    movss xmm11, [LFifthInv]
    shufps xmm11, xmm11, 0
    movss xmm10, [LSeventhInv]
    shufps xmm10, xmm10, 0

    mov r9d, $007FFFFF
    movd xmm9, r9d
    pshufd xmm9, xmm9, 0
    mov r9d, $3F000000
    movd xmm8, r9d
    pshufd xmm8, xmm8, 0
    mov r9d, $3F3504F3
    movd xmm7, r9d
    pshufd xmm7, xmm7, 0

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]

    movdqa xmm1, xmm0
    psrld xmm1, 23
    mov r9d, 126
    movd xmm6, r9d
    pshufd xmm6, xmm6, 0
    psubd xmm1, xmm6

    movdqa xmm2, xmm0
    pand xmm2, xmm9
    por xmm2, xmm8

    movaps xmm4, xmm2
    cmpltps xmm4, xmm7
    movaps xmm3, xmm2
    addps xmm3, xmm2
    movaps xmm0, xmm4
    andps xmm3, xmm4
    andnps xmm0, xmm2
    orps xmm3, xmm0
    movaps xmm2, xmm3
    psrld xmm4, 31
    psubd xmm1, xmm4

    // f = (m-1)/(m+1)
    movaps xmm3, xmm2
    subps xmm3, xmm14
    movaps xmm4, xmm2
    addps xmm4, xmm14
    divps xmm3, xmm4
    movaps xmm0, xmm3

    // f2
    movaps xmm2, xmm0
    mulps xmm2, xmm0

    // Horner: 1/7*f2 + 1/5
    movaps xmm3, xmm10
    mulps xmm3, xmm2
    addps xmm3, xmm11
    mulps xmm3, xmm2
    addps xmm3, xmm12
    mulps xmm3, xmm2
    addps xmm3, xmm14
    mulps xmm3, xmm0
    mulps xmm3, xmm13

    cvtdq2ps xmm1, xmm1
    movaps xmm4, xmm1
    mulps xmm4, xmm15
    addps xmm3, xmm4

    movups [rcx], xmm3
    add rax, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    sub rsp, 8
    movss xmm0, [rax]
    movss [rsp], xmm0
    fld dword [rsp]
    fldln2
    fxch
    fyl2x
    fstp dword [rsp]
    movss xmm0, [rsp]
    add rsp, 8
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;


procedure SSE2ArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
  L2OverPi, LPiOver2Hi, LPiOver2Mid: Single;
  LS1, LS2, LS3, LC1, LC2, LC3, LOne: Single;
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

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    movss xmm15, [L2OverPi]
    shufps xmm15, xmm15, 0
    movss xmm14, [LPiOver2Hi]
    shufps xmm14, xmm14, 0
    movss xmm13, [LPiOver2Mid]
    shufps xmm13, xmm13, 0
    movss xmm12, [LS1]
    shufps xmm12, xmm12, 0
    movss xmm11, [LS2]
    shufps xmm11, xmm11, 0
    movss xmm10, [LS3]
    shufps xmm10, xmm10, 0
    movss xmm9, [LC1]
    shufps xmm9, xmm9, 0
    movss xmm8, [LC2]
    shufps xmm8, xmm8, 0

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]

    // sign(x) → xmm4
    pcmpeqd xmm7, xmm7
    pslld xmm7, 31              // 0x80000000
    movaps xmm4, xmm0
    andps xmm4, xmm7            // sign(x)
    andnps xmm7, xmm0           // |x|
    movaps xmm0, xmm7

    // j = round(|x| * 2/pi)
    movaps xmm1, xmm0
    mulps xmm1, xmm15
    cvtps2dq xmm5, xmm1         // j_int → xmm5 (preserved!)
    cvtdq2ps xmm1, xmm5         // j_float

    // Extract masks from j_int:
    // j&2 sign: vpsrld+vpslld
    movdqa xmm6, xmm5
    psrld xmm6, 1               // j >> 1
    pslld xmm6, 31              // bit1 → bit31
    xorps xmm4, xmm6            // combined sign

    // j&1 blend mask: pslld
    movdqa xmm3, xmm5
    pslld xmm3, 31              // j bit0 → bit31 (blend mask)

    // r = |x| - j*(pi/2) Cody-Waite
    movaps xmm6, xmm1
    mulps xmm6, xmm14
    subps xmm0, xmm6
    movaps xmm6, xmm1
    mulps xmm6, xmm13
    subps xmm0, xmm6            // r

    // r²
    movaps xmm2, xmm0
    mulps xmm2, xmm2

    // Sin poly: r*(1 + r²*(S1 + r²*(S2 + r²*S3)))
    movaps xmm1, xmm10          // S3
    mulps xmm1, xmm2
    addps xmm1, xmm11           // S3*r² + S2
    mulps xmm1, xmm2
    addps xmm1, xmm12           // *r² + S1
    mulps xmm1, xmm2
    movss xmm6, [LOne]
    shufps xmm6, xmm6, 0
    addps xmm1, xmm6            // *r² + 1
    mulps xmm1, xmm0            // *r → sin_result

    // Cos poly: 1 + r²*(C1 + r²*(C2 + r²*C3))
    movss xmm7, [LC3]
    shufps xmm7, xmm7, 0
    movaps xmm0, xmm7           // C3
    mulps xmm0, xmm2
    addps xmm0, xmm8            // C3*r² + C2
    mulps xmm0, xmm2
    addps xmm0, xmm9            // *r² + C1
    mulps xmm0, xmm2            // *r²
    addps xmm0, xmm6            // + 1 → cos_result

    // Blend: xmm3 bit31=1 where j odd → use cos(xmm0), else sin(xmm1)
    // SSE2 blend: result = (cos & mask) | (sin & ~mask)
    movaps xmm6, xmm3           // copy mask
    andps xmm6, xmm0            // cos where mask
    andnps xmm3, xmm1           // sin where ~mask (xmm3 destroyed)
    orps xmm6, xmm3             // blended result

    // Apply combined sign
    xorps xmm6, xmm4

    movups [rcx], xmm6
    add rax, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    sub rsp, 8
    movss xmm0, [rax]
    movss [rsp], xmm0
    fld dword [rsp]
    fsin
    fstp dword [rsp]
    movss xmm0, [rsp]
    add rsp, 8
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
  L2OverPi, LPiOver2Hi, LPiOver2Mid: Single;
  LS1, LS2, LS3, LC1, LC2, LC3, LOne: Single;
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

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    movss xmm15, [L2OverPi]
    shufps xmm15, xmm15, 0
    movss xmm14, [LPiOver2Hi]
    shufps xmm14, xmm14, 0
    movss xmm13, [LPiOver2Mid]
    shufps xmm13, xmm13, 0
    movss xmm12, [LS1]
    shufps xmm12, xmm12, 0
    movss xmm11, [LS2]
    shufps xmm11, xmm11, 0
    movss xmm10, [LS3]
    shufps xmm10, xmm10, 0
    movss xmm9, [LC1]
    shufps xmm9, xmm9, 0
    movss xmm8, [LC2]
    shufps xmm8, xmm8, 0

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]

    // cos(x) = cos(|x|), sign irrelevant
    pcmpeqd xmm7, xmm7
    pslld xmm7, 31
    andnps xmm7, xmm0
    movaps xmm0, xmm7           // |x|

    // j = round(|x| * 2/pi)
    movaps xmm1, xmm0
    mulps xmm1, xmm15
    cvtps2dq xmm5, xmm1
    cvtdq2ps xmm1, xmm5

    // For cos: use j+1 for quadrant selection
    pcmpeqd xmm6, xmm6
    psrld xmm6, 31              // const 1
    paddd xmm5, xmm6            // j+1

    // (j+1)&2 sign mask
    movdqa xmm4, xmm5
    psrld xmm4, 1
    pslld xmm4, 31              // sign mask

    // (j+1)&1 blend mask
    movdqa xmm3, xmm5
    pslld xmm3, 31

    // r = |x| - j*(pi/2)
    movaps xmm6, xmm1
    mulps xmm6, xmm14
    subps xmm0, xmm6
    movaps xmm6, xmm1
    mulps xmm6, xmm13
    subps xmm0, xmm6

    // r²
    movaps xmm2, xmm0
    mulps xmm2, xmm2

    // Sin poly
    movaps xmm1, xmm10
    mulps xmm1, xmm2
    addps xmm1, xmm11
    mulps xmm1, xmm2
    addps xmm1, xmm12
    mulps xmm1, xmm2
    movss xmm6, [LOne]
    shufps xmm6, xmm6, 0
    addps xmm1, xmm6
    mulps xmm1, xmm0

    // Cos poly
    movss xmm7, [LC3]
    shufps xmm7, xmm7, 0
    movaps xmm0, xmm7
    mulps xmm0, xmm2
    addps xmm0, xmm8
    mulps xmm0, xmm2
    addps xmm0, xmm9
    mulps xmm0, xmm2
    addps xmm0, xmm6

    // Blend
    movaps xmm6, xmm3
    andps xmm6, xmm0
    andnps xmm3, xmm1
    orps xmm6, xmm3

    // Sign
    xorps xmm6, xmm4

    movups [rcx], xmm6
    add rax, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    sub rsp, 8
    movss xmm0, [rax]
    movss [rsp], xmm0
    fld dword [rsp]
    fcos
    fstp dword [rsp]
    movss xmm0, [rsp]
    add rsp, 8
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;


procedure SSE2ArrayPowF32(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
var
  pS, pD: PSingle;
  LExp: Single;
  i: SizeUInt;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LExp := aExponent;
  SSE2ArrayLogF32(pS, pD, aCount);
  // SIMD multiply by exponent
  asm
    mov rax, pD
    mov r8, aCount
    movss xmm7, [LExp]
    shufps xmm7, xmm7, 0
    cmp r8, 4
    jb @tail
  @loop4:
    movups xmm0, [rax]
    mulps xmm0, xmm7
    movups [rax], xmm0
    add rax, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4
  @tail:
    test r8, r8
    jz @done
  @scalar:
    movss xmm0, [rax]
    mulss xmm0, xmm7
    movss [rax], xmm0
    add rax, 4
    dec r8
    jnz @scalar
  @done:
  end;
  SSE2ArrayExpF32(pD, pD, aCount);
  {$POP}
end;

// ============================================================================
// SSE2 Fused Batch Operations
// ============================================================================

procedure SSE2ArrayLinearF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
var pS, pD: PSingle; LScale, LBias: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScale := aScale; LBias := aBias;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movss xmm6, [LScale]
    shufps xmm6, xmm6, 0
    movss xmm7, [LBias]
    shufps xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    mulps xmm0, xmm6
    addps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    mulps xmm1, xmm6
    addps xmm1, xmm7
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    mulps xmm2, xmm6
    addps xmm2, xmm7
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    mulps xmm3, xmm6
    addps xmm3, xmm7
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    mulps xmm0, xmm6
    addps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    mulps xmm1, xmm6
    addps xmm1, xmm7
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    mulps xmm0, xmm6
    addps xmm0, xmm7
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    mulss xmm0, xmm6
    addss xmm0, xmm7
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAbsDiffF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var pS1, pS2, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1
    mov rdx, pS2
    mov rcx, pD
    mov r8, aCount
    mov r9d, $7FFFFFFF
    movd xmm7, r9d
    pshufd xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    subps xmm0, [rdx]
    andps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    subps xmm1, [rdx + 16]
    andps xmm1, xmm7
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    subps xmm2, [rdx + 32]
    andps xmm2, xmm7
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    subps xmm3, [rdx + 48]
    andps xmm3, xmm7
    movups [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    subps xmm0, [rdx]
    andps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    subps xmm1, [rdx + 16]
    andps xmm1, xmm7
    movups [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    subps xmm0, [rdx]
    andps xmm0, xmm7
    movups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    subss xmm0, [rdx]
    andps xmm0, xmm7
    movss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    xorps xmm7, xmm7

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    maxps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    maxps xmm1, xmm7
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    maxps xmm2, xmm7
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    maxps xmm3, xmm7
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    maxps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    maxps xmm1, xmm7
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    maxps xmm0, xmm7
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    maxss xmm0, xmm7
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayNormF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single);
var pS, pD: PSingle; LMean, LInvStd: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LMean := aMean; LInvStd := aInvStd;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movss xmm6, [LMean]
    shufps xmm6, xmm6, 0
    movss xmm7, [LInvStd]
    shufps xmm7, xmm7, 0

    cmp r8, 16
    jb @tail8

  @loop16:
    movups xmm0, [rax]
    subps xmm0, xmm6
    mulps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    subps xmm1, xmm6
    mulps xmm1, xmm7
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    subps xmm2, xmm6
    mulps xmm2, xmm7
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    subps xmm3, xmm6
    mulps xmm3, xmm7
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    subps xmm0, xmm6
    mulps xmm0, xmm7
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    subps xmm1, xmm6
    mulps xmm1, xmm7
    movups [rcx + 16], xmm1
    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    subps xmm0, xmm6
    mulps xmm0, xmm7
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    subss xmm0, xmm6
    mulss xmm0, xmm7
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayLinearReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
var
  pS, pD: PSingle;
  LScale, LBias: Single;
  i: SizeUInt;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LScale := aScale; LBias := aBias;
  i := 0;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movss xmm6, [LScale]
    shufps xmm6, xmm6, 0
    movss xmm7, [LBias]
    shufps xmm7, xmm7, 0
    xorps xmm5, xmm5

    cmp r8, 16
    jb @tail4

  @loop16:
    movups xmm0, [rax]
    mulps xmm0, xmm6
    addps xmm0, xmm7
    maxps xmm0, xmm5
    movups [rcx], xmm0
    movups xmm1, [rax + 16]
    mulps xmm1, xmm6
    addps xmm1, xmm7
    maxps xmm1, xmm5
    movups [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    mulps xmm2, xmm6
    addps xmm2, xmm7
    maxps xmm2, xmm5
    movups [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    mulps xmm3, xmm6
    addps xmm3, xmm7
    maxps xmm3, xmm5
    movups [rcx + 48], xmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail4:
    cmp r8, 4
    jb @tail1
    movups xmm0, [rax]
    mulps xmm0, xmm6
    addps xmm0, xmm7
    maxps xmm0, xmm5
    movups [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 4
    jmp @tail4

  @tail1:
    mov i, r8
  end;

  while i > 0 do
  begin
    pD[aCount - i] := pS[aCount - i] * LScale + LBias;
    if pD[aCount - i] < 0 then pD[aCount - i] := 0;
    Dec(i);
  end;
  {$POP}
end;

// ============================================================================
// SSE2 F64 Scalar/Affine Operations (XMM = 2 doubles/iter)
// ============================================================================

procedure SSE2ArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var pS, pD: PDouble; LScalar: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScalar := aScalar;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movq xmm7, [LScalar]
    unpcklpd xmm7, xmm7

    cmp r8, 2
    jb @tail_scalar

  @loop2:
    movupd xmm0, [rax]
    mulpd xmm0, xmm7
    movupd [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 2
    cmp r8, 2
    jae @loop2

  @tail_scalar:
    test r8, r8
    jz @done
    movsd xmm0, [rax]
    mulsd xmm0, xmm7
    movsd [rcx], xmm0

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var pS, pD: PDouble; LScalar: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScalar := aScalar;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movq xmm7, [LScalar]
    unpcklpd xmm7, xmm7

    cmp r8, 2
    jb @tail_scalar

  @loop2:
    movupd xmm0, [rax]
    addpd xmm0, xmm7
    movupd [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 2
    cmp r8, 2
    jae @loop2

  @tail_scalar:
    test r8, r8
    jz @done
    movsd xmm0, [rax]
    addsd xmm0, xmm7
    movsd [rcx], xmm0

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
var pS, pD: PDouble; LMin, LMax: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LMin := aMin; LMax := aMax;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movq xmm6, [LMin]
    unpcklpd xmm6, xmm6
    movq xmm7, [LMax]
    unpcklpd xmm7, xmm7

    cmp r8, 2
    jb @tail_scalar

  @loop2:
    movupd xmm0, [rax]
    maxpd xmm0, xmm6
    minpd xmm0, xmm7
    movupd [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 2
    cmp r8, 2
    jae @loop2

  @tail_scalar:
    test r8, r8
    jz @done
    movsd xmm0, [rax]
    maxsd xmm0, xmm6
    minsd xmm0, xmm7
    movsd [rcx], xmm0

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayLinearF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
var pS, pD: PDouble; LScale, LBias: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScale := aScale; LBias := aBias;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movq xmm6, [LScale]
    unpcklpd xmm6, xmm6
    movq xmm7, [LBias]
    unpcklpd xmm7, xmm7

    cmp r8, 2
    jb @tail_scalar

  @loop2:
    movupd xmm0, [rax]
    mulpd xmm0, xmm6
    addpd xmm0, xmm7
    movupd [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 2
    cmp r8, 2
    jae @loop2

  @tail_scalar:
    test r8, r8
    jz @done
    movsd xmm0, [rax]
    mulsd xmm0, xmm6
    addsd xmm0, xmm7
    movsd [rcx], xmm0

  @done:
  end;
  {$POP}
end;
