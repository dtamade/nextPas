// ============================================================================
// SSE2 Batch Array Operations
// 策略: 主循环 8x 展开 (每次 32 个 float)，预取优化，标量尾部处理剩余元素
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

    // 大数组路径: 8x 展开 + 预取
    cmp r8, 32
    jb @tail16

  @loop32:
    // 预取下一批数据 (256 字节 ahead)
    prefetchnta [rax + 256]
    prefetchnta [rdx + 256]

    // 第 1 组 (0-3)
    movups xmm0, [rax]
    addps xmm0, [rdx]
    movups [rcx], xmm0

    // 第 2 组 (4-7)
    movups xmm1, [rax + 16]
    addps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1

    // 第 3 组 (8-11)
    movups xmm2, [rax + 32]
    addps xmm2, [rdx + 32]
    movups [rcx + 32], xmm2

    // 第 4 组 (12-15)
    movups xmm3, [rax + 48]
    addps xmm3, [rdx + 48]
    movups [rcx + 48], xmm3

    // 第 5 组 (16-19)
    movups xmm4, [rax + 64]
    addps xmm4, [rdx + 64]
    movups [rcx + 64], xmm4

    // 第 6 组 (20-23)
    movups xmm5, [rax + 80]
    addps xmm5, [rdx + 80]
    movups [rcx + 80], xmm5

    // 第 7 组 (24-27)
    movups xmm6, [rax + 96]
    addps xmm6, [rdx + 96]
    movups [rcx + 96], xmm6

    // 第 8 组 (28-31)
    movups xmm7, [rax + 112]
    addps xmm7, [rdx + 112]
    movups [rcx + 112], xmm7

    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
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

// ============================================================================
// SSE2 Non-Temporal Store Variant
// Use when dst won't be read again soon (e.g., output buffers, transforms)
// Provides ~2x bandwidth for large arrays that exceed L2 cache
// ============================================================================

procedure SSE2ArrayAddF32_NT(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
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

    // NT stores require 16-byte aligned destination
    test rcx, 15
    jnz @unaligned_fallback

    cmp r8, 32
    jb @tail16

  @loop32:
    // 预取下一批数据 (256 字节 ahead)
    prefetchnta [rax + 256]
    prefetchnta [rdx + 256]

    // 第 1 组 (0-3)
    movups xmm0, [rax]
    addps xmm0, [rdx]
    movntps [rcx], xmm0

    // 第 2 组 (4-7)
    movups xmm1, [rax + 16]
    addps xmm1, [rdx + 16]
    movntps [rcx + 16], xmm1

    // 第 3 组 (8-11)
    movups xmm2, [rax + 32]
    addps xmm2, [rdx + 32]
    movntps [rcx + 32], xmm2

    // 第 4 组 (12-15)
    movups xmm3, [rax + 48]
    addps xmm3, [rdx + 48]
    movntps [rcx + 48], xmm3

    // 第 5 组 (16-19)
    movups xmm4, [rax + 64]
    addps xmm4, [rdx + 64]
    movntps [rcx + 64], xmm4

    // 第 6 组 (20-23)
    movups xmm5, [rax + 80]
    addps xmm5, [rdx + 80]
    movntps [rcx + 80], xmm5

    // 第 7 组 (24-27)
    movups xmm6, [rax + 96]
    addps xmm6, [rdx + 96]
    movntps [rcx + 96], xmm6

    // 第 8 组 (28-31)
    movups xmm7, [rax + 112]
    addps xmm7, [rdx + 112]
    movntps [rcx + 112], xmm7

    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
    movups xmm0, [rax]
    addps xmm0, [rdx]
    movntps [rcx], xmm0
    movups xmm1, [rax + 16]
    addps xmm1, [rdx + 16]
    movntps [rcx + 16], xmm1
    movups xmm2, [rax + 32]
    addps xmm2, [rdx + 32]
    movntps [rcx + 32], xmm2
    movups xmm3, [rax + 48]
    addps xmm3, [rdx + 48]
    movntps [rcx + 48], xmm3
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16

  @tail8:
    cmp r8, 8
    jb @tail4
    movups xmm0, [rax]
    addps xmm0, [rdx]
    movntps [rcx], xmm0
    movups xmm1, [rax + 16]
    addps xmm1, [rdx + 16]
    movntps [rcx + 16], xmm1
    add rax, 32
    add rdx, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm0, [rax]
    addps xmm0, [rdx]
    movntps [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4
    jmp @tail_scalar

  @unaligned_fallback:
    // Fallback: use regular stores when dst not 16-byte aligned
    cmp r8, 32
    jb @uf_tail16
  @uf_loop32:
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
    movups xmm4, [rax + 64]
    addps xmm4, [rdx + 64]
    movups [rcx + 64], xmm4
    movups xmm5, [rax + 80]
    addps xmm5, [rdx + 80]
    movups [rcx + 80], xmm5
    movups xmm6, [rax + 96]
    addps xmm6, [rdx + 96]
    movups [rcx + 96], xmm6
    movups xmm7, [rax + 112]
    addps xmm7, [rdx + 112]
    movups [rcx + 112], xmm7
    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @uf_loop32
  @uf_tail16:
    cmp r8, 16
    jb @tail8
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
    sfence  // 确保 NT 写入完成
  end;
  {$POP}
end;

// Smart 选择: 大数据用 NT，小数据用普通
procedure SSE2ArrayAddF32_Smart(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
const
  NT_THRESHOLD = 16384; // 64KB = 16384 floats (exceeds L1 cache)
begin
  if aCount >= NT_THRESHOLD then
    SSE2ArrayAddF32_NT(aSrc1, aSrc2, aDst, aCount)
  else
    SSE2ArrayAddF32(aSrc1, aSrc2, aDst, aCount);
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

    // 大数组路径: 8x 展开 + 预取
    cmp r8, 32
    jb @tail16

  @loop32:
    // 预取下一批数据 (256 字节 ahead)
    prefetchnta [rax + 256]
    prefetchnta [rdx + 256]

    // 第 1 组 (0-3)
    movups xmm0, [rax]
    mulps xmm0, [rdx]
    movups [rcx], xmm0

    // 第 2 组 (4-7)
    movups xmm1, [rax + 16]
    mulps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1

    // 第 3 组 (8-11)
    movups xmm2, [rax + 32]
    mulps xmm2, [rdx + 32]
    movups [rcx + 32], xmm2

    // 第 4 组 (12-15)
    movups xmm3, [rax + 48]
    mulps xmm3, [rdx + 48]
    movups [rcx + 48], xmm3

    // 第 5 组 (16-19)
    movups xmm4, [rax + 64]
    mulps xmm4, [rdx + 64]
    movups [rcx + 64], xmm4

    // 第 6 组 (20-23)
    movups xmm5, [rax + 80]
    mulps xmm5, [rdx + 80]
    movups [rcx + 80], xmm5

    // 第 7 组 (24-27)
    movups xmm6, [rax + 96]
    mulps xmm6, [rdx + 96]
    movups [rcx + 96], xmm6

    // 第 8 组 (28-31)
    movups xmm7, [rax + 112]
    mulps xmm7, [rdx + 112]
    movups [rcx + 112], xmm7

    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
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
    // NaN-safe clamp: detect NaN, replace with min, clamp, blend original NaN back
    // Chunk 0-3
    movups xmm0, [rax]
    movaps xmm4, xmm0           // save original
    movaps xmm5, xmm0
    cmpunordps xmm5, xmm5       // NaN mask (1 where NaN, 0 otherwise)
    movaps xmm3, xmm6
    andps xmm3, xmm5            // min_bound & NaN_mask
    andnps xmm5, xmm0           // ~NaN_mask & input (non-NaN values)
    orps xmm5, xmm3             // safe_input: NaN replaced with min
    minps xmm5, xmm7            // temp = Min(safe_input, maxVal)
    maxps xmm5, xmm6            // result = Max(minVal, temp)
    // blend original NaN back
    movaps xmm3, xmm4
    cmpunordps xmm3, xmm3       // recompute NaN mask from original
    andps xmm4, xmm3            // original & NaN_mask
    andnps xmm3, xmm5           // ~NaN_mask & clamped
    orps xmm4, xmm3
    movups [rcx], xmm4

    movups xmm0, [rax + 16]
    movaps xmm4, xmm0
    movaps xmm5, xmm0
    cmpunordps xmm5, xmm5
    movaps xmm3, xmm6
    andps xmm3, xmm5
    andnps xmm5, xmm0
    orps xmm5, xmm3
    maxps xmm5, xmm6
    minps xmm5, xmm7
    movaps xmm3, xmm4
    cmpunordps xmm3, xmm3
    andps xmm4, xmm3
    andnps xmm3, xmm5
    orps xmm4, xmm3
    movups [rcx + 16], xmm4

    movups xmm0, [rax + 32]
    movaps xmm4, xmm0
    movaps xmm5, xmm0
    cmpunordps xmm5, xmm5
    movaps xmm3, xmm6
    andps xmm3, xmm5
    andnps xmm5, xmm0
    orps xmm5, xmm3
    maxps xmm5, xmm6
    minps xmm5, xmm7
    movaps xmm3, xmm4
    cmpunordps xmm3, xmm3
    andps xmm4, xmm3
    andnps xmm3, xmm5
    orps xmm4, xmm3
    movups [rcx + 32], xmm4

    movups xmm0, [rax + 48]
    movaps xmm4, xmm0
    movaps xmm5, xmm0
    cmpunordps xmm5, xmm5
    movaps xmm3, xmm6
    andps xmm3, xmm5
    andnps xmm5, xmm0
    orps xmm5, xmm3
    maxps xmm5, xmm6
    minps xmm5, xmm7
    movaps xmm3, xmm4
    cmpunordps xmm3, xmm3
    andps xmm4, xmm3
    andnps xmm3, xmm5
    orps xmm4, xmm3
    movups [rcx + 48], xmm4

    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @tail4

    movups xmm0, [rax]
    movaps xmm4, xmm0
    movaps xmm5, xmm0
    cmpunordps xmm5, xmm5
    movaps xmm3, xmm6
    andps xmm3, xmm5
    andnps xmm5, xmm0
    orps xmm5, xmm3
    maxps xmm5, xmm6
    minps xmm5, xmm7
    movaps xmm3, xmm4
    cmpunordps xmm3, xmm3
    andps xmm4, xmm3
    andnps xmm3, xmm5
    orps xmm4, xmm3
    movups [rcx], xmm4

    movups xmm0, [rax + 16]
    movaps xmm4, xmm0
    movaps xmm5, xmm0
    cmpunordps xmm5, xmm5
    movaps xmm3, xmm6
    andps xmm3, xmm5
    andnps xmm5, xmm0
    orps xmm5, xmm3
    maxps xmm5, xmm6
    minps xmm5, xmm7
    movaps xmm3, xmm4
    cmpunordps xmm3, xmm3
    andps xmm4, xmm3
    andnps xmm3, xmm5
    orps xmm4, xmm3
    movups [rcx + 16], xmm4

    add rax, 32
    add rcx, 32
    sub r8, 8

  @tail4:
    cmp r8, 4
    jb @tail_scalar

    movups xmm0, [rax]
    movaps xmm4, xmm0
    movaps xmm5, xmm0
    cmpunordps xmm5, xmm5
    movaps xmm3, xmm6
    andps xmm3, xmm5
    andnps xmm5, xmm0
    orps xmm5, xmm3
    maxps xmm5, xmm6
    minps xmm5, xmm7
    movaps xmm3, xmm4
    cmpunordps xmm3, xmm3
    andps xmm4, xmm3
    andnps xmm3, xmm5
    orps xmm4, xmm3
    movups [rcx], xmm4

    add rax, 16
    add rcx, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movss xmm0, [rax]
    movaps xmm4, xmm0
    movaps xmm5, xmm0
    cmpunordss xmm5, xmm5
    movaps xmm3, xmm6
    andps xmm3, xmm5
    andnps xmm5, xmm0
    orps xmm5, xmm3
    maxss xmm5, xmm6
    minss xmm5, xmm7
    movaps xmm3, xmm4
    cmpunordss xmm3, xmm3
    andps xmm4, xmm3
    andnps xmm3, xmm5
    orps xmm4, xmm3
    movss [rcx], xmm4
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

    // 大数组路径: 8x 展开 + 预取
    cmp r8, 32
    jb @tail16

  @loop32:
    // 预取下一批数据 (256 字节 ahead)
    prefetchnta [rax + 256]
    prefetchnta [rdx + 256]

    // 第 1 组 (0-3)
    movups xmm0, [rax]
    subps xmm0, [rdx]
    movups [rcx], xmm0

    // 第 2 组 (4-7)
    movups xmm1, [rax + 16]
    subps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1

    // 第 3 组 (8-11)
    movups xmm2, [rax + 32]
    subps xmm2, [rdx + 32]
    movups [rcx + 32], xmm2

    // 第 4 组 (12-15)
    movups xmm3, [rax + 48]
    subps xmm3, [rdx + 48]
    movups [rcx + 48], xmm3

    // 第 5 组 (16-19)
    movups xmm4, [rax + 64]
    subps xmm4, [rdx + 64]
    movups [rcx + 64], xmm4

    // 第 6 组 (20-23)
    movups xmm5, [rax + 80]
    subps xmm5, [rdx + 80]
    movups [rcx + 80], xmm5

    // 第 7 组 (24-27)
    movups xmm6, [rax + 96]
    subps xmm6, [rdx + 96]
    movups [rcx + 96], xmm6

    // 第 8 组 (28-31)
    movups xmm7, [rax + 112]
    subps xmm7, [rdx + 112]
    movups [rcx + 112], xmm7

    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
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

    // 大数组路径: 8x 展开 + 预取
    cmp r8, 32
    jb @tail16

  @loop32:
    // 预取下一批数据 (256 字节 ahead)
    prefetchnta [rax + 256]
    prefetchnta [rdx + 256]

    // 第 1 组 (0-3)
    movups xmm0, [rax]
    divps xmm0, [rdx]
    movups [rcx], xmm0

    // 第 2 组 (4-7)
    movups xmm1, [rax + 16]
    divps xmm1, [rdx + 16]
    movups [rcx + 16], xmm1

    // 第 3 组 (8-11)
    movups xmm2, [rax + 32]
    divps xmm2, [rdx + 32]
    movups [rcx + 32], xmm2

    // 第 4 组 (12-15)
    movups xmm3, [rax + 48]
    divps xmm3, [rdx + 48]
    movups [rcx + 48], xmm3

    // 第 5 组 (16-19)
    movups xmm4, [rax + 64]
    divps xmm4, [rdx + 64]
    movups [rcx + 64], xmm4

    // 第 6 组 (20-23)
    movups xmm5, [rax + 80]
    divps xmm5, [rdx + 80]
    movups [rcx + 80], xmm5

    // 第 7 组 (24-27)
    movups xmm6, [rax + 96]
    divps xmm6, [rdx + 96]
    movups [rcx + 96], xmm6

    // 第 8 组 (28-31)
    movups xmm7, [rax + 112]
    divps xmm7, [rdx + 112]
    movups [rcx + 112], xmm7

    add rax, 128
    add rdx, 128
    add rcx, 128
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail16:
    cmp r8, 16
    jb @tail8
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
// SSE2 F64 Extended Batch Array Operations
// 策略: 2x XMM 展开 (每轮 4 double = 32 bytes), 标量尾部
// ============================================================================

procedure SSE2ArrayAxpyF64(aAlpha: Double; aX, aY, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pX, pY, pD: PDouble;
  LAlpha: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pX := aX; pY := aY; pD := aDst; LAlpha := aAlpha; i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pX
      mov    rdx, pY
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      movsd  xmm7, LAlpha
      pshufd xmm7, xmm7, $44

      movupd xmm0, [rax + r8]
      mulpd  xmm0, xmm7
      addpd  xmm0, [rdx + r8]
      movupd [rcx + r8], xmm0

      movupd xmm1, [rax + r8 + 16]
      mulpd  xmm1, xmm7
      addpd  xmm1, [rdx + r8 + 16]
      movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;

  while i < aCount do
  begin
    pD[i] := LAlpha * pX[i] + pY[i];
    Inc(i);
  end;
  {$POP}
end;

procedure SSE2ArrayRcpF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      mov    r9, $3FF0000000000000
      movq   xmm7, r9
      pshufd xmm7, xmm7, $44

      movupd xmm0, [rax + r8]
      divpd  xmm7, xmm0
      movupd [rcx + r8], xmm7

      mov    r9, $3FF0000000000000
      movq   xmm7, r9
      pshufd xmm7, xmm7, $44
      movupd xmm1, [rax + r8 + 16]
      divpd  xmm7, xmm1
      movupd [rcx + r8 + 16], xmm7
    end;
    Inc(i, 4);
  end;

  while i < aCount do
  begin
    pD[i] := 1.0 / pS[i];
    Inc(i);
  end;
  {$POP}
end;

procedure SSE2ArrayRsqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      mov    r9, $3FF0000000000000
      movq   xmm7, r9
      pshufd xmm7, xmm7, $44

      movupd xmm0, [rax + r8]
      sqrtpd xmm0, xmm0
      divpd  xmm7, xmm0
      movupd [rcx + r8], xmm7

      mov    r9, $3FF0000000000000
      movq   xmm7, r9
      pshufd xmm7, xmm7, $44
      movupd xmm1, [rax + r8 + 16]
      sqrtpd xmm1, xmm1
      divpd  xmm7, xmm1
      movupd [rcx + r8 + 16], xmm7
    end;
    Inc(i, 4);
  end;

  while i < aCount do
  begin
    pD[i] := 1.0 / Sqrt(pS[i]);
    Inc(i);
  end;
  {$POP}
end;

procedure SSE2ArrayTanF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  for i := 0 to aCount - 1 do
    pD[i] := Sin(pS[i]) / Cos(pS[i]);
  {$POP}
end;

procedure SSE2ArraySignF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  for i := 0 to aCount - 1 do
  begin
    if pS[i] > 0 then pD[i] := 1.0
    else if pS[i] < 0 then pD[i] := -1.0
    else pD[i] := 0.0;
  end;
  {$POP}
end;

procedure SSE2ArrayFractF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  for i := 0 to aCount - 1 do
    pD[i] := pS[i] - Int(pS[i]);
  {$POP}
end;

procedure SSE2ArrayModF64(aSrc, aDst: PDouble; aCount: SizeUInt; aDivisor: Double);
var
  i: SizeUInt;
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  for i := 0 to aCount - 1 do
    pD[i] := pS[i] - aDivisor * Int(pS[i] / aDivisor);
  {$POP}
end;

procedure SSE2ArrayPowF64(aSrc, aDst: PDouble; aCount: SizeUInt; aExponent: Double);
var
  i: SizeUInt;
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  for i := 0 to aCount - 1 do
    pD[i] := SimdPowerF64(pS[i], aExponent);
  {$POP}
end;

procedure SSE2ArrayLerpF64(aStart, aEnd, aDst: PDouble; aCount: SizeUInt; aT: Double);
var
  i: SizeUInt;
  pS1, pS2, pD: PDouble;
  LT: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aStart; pS2 := aEnd; pD := aDst; LT := aT; i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pS1
      mov    rdx, pS2
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      movsd  xmm7, LT
      pshufd xmm7, xmm7, $44

      movupd xmm0, [rdx + r8]
      subpd  xmm0, [rax + r8]
      mulpd  xmm0, xmm7
      addpd  xmm0, [rax + r8]
      movupd [rcx + r8], xmm0

      movupd xmm1, [rdx + r8 + 16]
      subpd  xmm1, [rax + r8 + 16]
      mulpd  xmm1, xmm7
      addpd  xmm1, [rax + r8 + 16]
      movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;

  while i < aCount do
  begin
    pD[i] := pS1[i] + LT * (pS2[i] - pS1[i]);
    Inc(i);
  end;
  {$POP}
end;

procedure SSE2ArrayReLUF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      xorpd  xmm7, xmm7

      movupd xmm0, [rax + r8]
      maxpd  xmm0, xmm7
      movupd [rcx + r8], xmm0

      movupd xmm1, [rax + r8 + 16]
      maxpd  xmm1, xmm7
      movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;

  while i < aCount do
  begin
    if pS[i] > 0 then pD[i] := pS[i] else pD[i] := 0.0;
    Inc(i);
  end;
  {$POP}
end;

procedure SSE2ArrayAbsDiffF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pS1, pS2, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst; i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pS1
      mov    rdx, pS2
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      mov    r9, $7FFFFFFFFFFFFFFF
      movq   xmm7, r9
      pshufd xmm7, xmm7, $44

      movupd xmm0, [rax + r8]
      subpd  xmm0, [rdx + r8]
      andpd  xmm0, xmm7
      movupd [rcx + r8], xmm0

      movupd xmm1, [rax + r8 + 16]
      subpd  xmm1, [rdx + r8 + 16]
      andpd  xmm1, xmm7
      movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;

  while i < aCount do
  begin
    pD[i] := Abs(pS1[i] - pS2[i]);
    Inc(i);
  end;
  {$POP}
end;

procedure SSE2ArrayNormF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMean, aInvStd: Double);
var
  i: SizeUInt;
  pS, pD: PDouble;
  LMean, LInvStd: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LMean := aMean; LInvStd := aInvStd; i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      movsd  xmm6, LMean
      pshufd xmm6, xmm6, $44
      movsd  xmm7, LInvStd
      pshufd xmm7, xmm7, $44

      movupd xmm0, [rax + r8]
      subpd  xmm0, xmm6
      mulpd  xmm0, xmm7
      movupd [rcx + r8], xmm0

      movupd xmm1, [rax + r8 + 16]
      subpd  xmm1, xmm6
      mulpd  xmm1, xmm7
      movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;

  while i < aCount do
  begin
    pD[i] := (pS[i] - LMean) * LInvStd;
    Inc(i);
  end;
  {$POP}
end;

procedure SSE2ArrayLinearReLUF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
var
  i: SizeUInt;
  pS, pD: PDouble;
  LScale, LBias: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScale := aScale; LBias := aBias; i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3
      movsd  xmm6, LScale
      pshufd xmm6, xmm6, $44
      movsd  xmm7, LBias
      pshufd xmm7, xmm7, $44
      xorpd  xmm5, xmm5

      movupd xmm0, [rax + r8]
      movupd xmm2, xmm0
      mulpd  xmm2, xmm6
      addpd  xmm2, xmm7
      cmpltpd xmm0, xmm5
      andpd  xmm2, xmm0
      movupd [rcx + r8], xmm2

      movupd xmm1, [rax + r8 + 16]
      movupd xmm3, xmm1
      mulpd  xmm3, xmm6
      addpd  xmm3, xmm7
      cmpltpd xmm1, xmm5
      andpd  xmm3, xmm1
      movupd [rcx + r8 + 16], xmm3
    end;
    Inc(i, 4);
  end;

  while i < aCount do
  begin
    if pS[i] < 0 then pD[i] := LScale * pS[i] + LBias else pD[i] := 0.0;
    Inc(i);
  end;
  {$POP}
end;

procedure SSE2ArrayStepF64(aEdge, aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pE, pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pE := aEdge; pS := aSrc; pD := aDst; i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pE
      mov    rdx, pS
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3

      movupd xmm0, [rdx + r8]
      cmpltpd xmm0, [rax + r8]
      movupd [rcx + r8], xmm0

      movupd xmm1, [rdx + r8 + 16]
      cmpltpd xmm1, [rax + r8 + 16]
      movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;

  while i < aCount do
  begin
    if pS[i] < pE[i] then pD[i] := 0.0 else pD[i] := 1.0;
    Inc(i);
  end;
  {$POP}
end;

procedure SSE2ArraySmoothstepF64(aEdge0, aEdge1, aSrc, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pE0, pE1, pS, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pE0 := aEdge0; pE1 := aEdge1; pS := aSrc; pD := aDst;
  for i := 0 to aCount - 1 do
  begin
    if pS[i] <= pE0[i] then pD[i] := 0.0
    else if pS[i] >= pE1[i] then pD[i] := 1.0
    else
    begin
      pD[i] := (pS[i] - pE0[i]) / (pE1[i] - pE0[i]);
      pD[i] := pD[i] * pD[i] * (3.0 - 2.0 * pD[i]);
    end;
  end;
  {$POP}
end;

procedure SSE2ArrayAtan2F64(aY, aX, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pY, pX, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pY := aY; pX := aX; pD := aDst;
  for i := 0 to aCount - 1 do
    pD[i] := ArcTan2(pY[i], pX[i]);
  {$POP}
end;

procedure SSE2ArrayHypotF64(aX, aY, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
  pX, pY, pD: PDouble;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pX := aX; pY := aY; pD := aDst; i := 0;

  while i + 4 <= aCount do
  begin
    asm
      mov    rax, pX
      mov    rdx, pY
      mov    rcx, pD
      mov    r8, i
      shl    r8, 3

      movupd xmm0, [rax + r8]
      mulpd  xmm0, xmm0
      movupd xmm2, [rdx + r8]
      mulpd  xmm2, xmm2
      addpd  xmm0, xmm2
      sqrtpd xmm0, xmm0
      movupd [rcx + r8], xmm0

      movupd xmm1, [rax + r8 + 16]
      mulpd  xmm1, xmm1
      movupd xmm3, [rdx + r8 + 16]
      mulpd  xmm3, xmm3
      addpd  xmm1, xmm3
      sqrtpd xmm1, xmm1
      movupd [rcx + r8 + 16], xmm1
    end;
    Inc(i, 4);
  end;

  while i < aCount do
  begin
    pD[i] := Sqrt(pX[i] * pX[i] + pY[i] * pY[i]);
    Inc(i);
  end;
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

// ============================================================================
// U32 Batch Operations (same as I32 - add/sub/and/or/xor are identical)
// ============================================================================

procedure SSE2ArrayAddU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
var pS1, pS2, pD: PUInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; paddd xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddd xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; paddd xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; paddd xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; paddd xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddd xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail_scalar
    movdqu xmm0, [rax]; paddd xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9d, [rax]; add r9d, [rdx]; mov [rcx], r9d
    add rax, 4; add rdx, 4; add rcx, 4; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArraySubU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
var pS1, pS2, pD: PUInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; psubd xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubd xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; psubd xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; psubd xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; psubd xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubd xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail_scalar
    movdqu xmm0, [rax]; psubd xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9d, [rax]; sub r9d, [rdx]; mov [rcx], r9d
    add rax, 4; add rdx, 4; add rcx, 4; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayMulU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
var pS1, pS2, pD: PUInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 4; jb @tail_scalar
  @loop4:
    // SSE2 没有 pmuludq for 4xU32, 使用标量
    mov r9d, [rax]; imul r9d, [rdx]; mov [rcx], r9d
    mov r9d, [rax + 4]; imul r9d, [rdx + 4]; mov [rcx + 4], r9d
    mov r9d, [rax + 8]; imul r9d, [rdx + 8]; mov [rcx + 8], r9d
    mov r9d, [rax + 12]; imul r9d, [rdx + 12]; mov [rcx + 12], r9d
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4; cmp r8, 4; jae @loop4
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9d, [rax]; imul r9d, [rdx]; mov [rcx], r9d
    add rax, 4; add rdx, 4; add rcx, 4; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAndU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
var pS1, pS2, pD: PUInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pand xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pand xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail_scalar
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9d, [rax]; and r9d, [rdx]; mov [rcx], r9d
    add rax, 4; add rdx, 4; add rcx, 4; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayOrU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
var pS1, pS2, pD: PUInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; por xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; por xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail_scalar
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9d, [rax]; or r9d, [rdx]; mov [rcx], r9d
    add rax, 4; add rdx, 4; add rcx, 4; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayXorU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
var pS1, pS2, pD: PUInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pxor xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pxor xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail_scalar
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9d, [rax]; xor r9d, [rdx]; mov [rcx], r9d
    add rax, 4; add rdx, 4; add rcx, 4; dec r8; jnz @scalar_loop
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

function SSE2ReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;
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
    maxps xmm0, xmm2
    movups xmm3, [rax + 16]
    maxps xmm1, xmm3
    add rax, 32
    sub r8, 8
    jmp @loop8

  @tail4_post:
    maxps xmm0, xmm1

  @tail4:
    cmp r8, 4
    jb @tail_scalar
    movups xmm2, [rax]
    maxps xmm0, xmm2
    add rax, 16
    sub r8, 4

  @tail_scalar:
    test r8, r8
    jz @reduce
  @scalar_loop:
    movss xmm2, [rax]
    maxss xmm0, xmm2
    add rax, 4
    dec r8
    jnz @scalar_loop

  @reduce:
    movhlps xmm1, xmm0
    maxps xmm0, xmm1
    pshufd xmm1, xmm0, $01
    maxss xmm0, xmm1
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

function SSE2ReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;
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
    maxpd xmm0, xmm1
    movupd xmm2, [rax + 16]
    maxpd xmm0, xmm2
    add rax, 32
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail2:
    cmp r8, 2
    jb @tail_scalar
    movupd xmm1, [rax]
    maxpd xmm0, xmm1
    add rax, 16
    sub r8, 2

  @tail_scalar:
    test r8, r8
    jz @reduce
    movsd xmm1, [rax]
    maxsd xmm0, xmm1

  @reduce:
    movhlps xmm1, xmm0
    maxsd xmm0, xmm1
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

    // Detect NaN: unord(x, x) is TRUE iff x is NaN
    movaps xmm4, xmm0
    cmpunordps xmm4, xmm4         // NaN mask (1 where NaN)
    // Detect Inf: abs(x) == 0x7F800000
    pcmpeqd xmm5, xmm5
    psrld xmm5, 1
    movaps xmm3, xmm0
    andps xmm3, xmm5              // abs(x)
    mov r9d, $7F800000
    movd xmm5, r9d
    shufps xmm5, xmm5, 0
    pcmpeqd xmm3, xmm5           // Inf mask (1 where Inf)
    orps xmm4, xmm3               // combined: NaN or Inf

    // Clamp: minss/maxss return second operand for NaN, so NaN→88.7228
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

    // 2^n: xmm1 already has n as int32 from cvtps2dq at line 3880
    pslld xmm1, 23
    paddd xmm2, xmm1

    // Blend: where NaN/Inf, use original (preserves NaN bit pattern)
    movups xmm0, [rax]
    andps xmm0, xmm4           // original where NaN/Inf, 0 elsewhere
    andnps xmm4, xmm2          // result where NOT NaN/Inf, 0 elsewhere
    orps xmm0, xmm4            // combined

    // Fix Exp(-Inf): -Inf should produce 0.0, not -Inf
    // xmm4 still has the Inf+NaN mask (from andnps above, it's the inverted mask)
    // Re-detect: original input sign + Inf mask
    movups xmm2, [rax]         // reload original
    pcmpeqd xmm3, xmm3
    pslld xmm3, 31             // 0x80000000 sign mask
    movaps xmm1, xmm2
    andps xmm1, xmm3           // sign bits
    pcmpeqd xmm3, xmm3
    pslld xmm3, 31             // 0x80000000
    pcmpeqd xmm1, xmm3         // negative mask (1 where negative)
    // xmm4 was destroyed, recompute Inf mask
    // We need the Inf mask. Recompute: abs(x) == 0x7F800000
    pcmpeqd xmm5, xmm5
    psrld xmm5, 1              // 0x7FFFFFFF
    movaps xmm3, xmm2
    andps xmm3, xmm5           // abs(x)
    mov r9d, $7F800000
    movd xmm5, r9d
    shufps xmm5, xmm5, 0
    pcmpeqd xmm3, xmm5         // Inf mask
    andps xmm1, xmm3            // negative AND Inf = -Inf mask
    // Zero out -Inf lanes
    andnps xmm1, xmm0           // clear lanes where -Inf
    movaps xmm0, xmm1

    movups [rcx], xmm0
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
    // Check for NaN: unord(x, x) → NaN mask
    movaps xmm4, xmm0
    cmpunordss xmm4, xmm4         // NaN mask
    // Check for Inf: abs(x) == 0x7F800000
    movaps xmm5, xmm0
    mov r9d, $7FFFFFFF
    movd xmm3, r9d
    andps xmm5, xmm3              // abs(x)
    mov r9d, $7F800000
    movd xmm3, r9d
    pcmpeqd xmm5, xmm3           // Inf mask
    orps xmm4, xmm5               // combined: NaN or Inf
    // Clamp (NaN → 88.7228 via minss/maxss, but we'll blend back)
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
    // Blend: where NaN or Inf, use original value
    movaps xmm3, xmm4
    andps xmm3, [rax]             // original where NaN/Inf
    andnps xmm4, xmm2             // result where not NaN/Inf
    orps xmm4, xmm3
    // Fix Exp(-Inf): -Inf should produce 0.0
    // Check if blended result is -Inf ($FF800000)
    mov r9d, $FF800000
    movd xmm3, r9d
    movss xmm0, xmm4
    movd r9d, xmm0
    cmp r9d, $FF800000
    jne @store_exp
    xorps xmm4, xmm4             // zero out -Inf
  @store_exp:
    movss [rcx], xmm4
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

    // === Fast path: check all elements are positive normal ===
    // Negative check: any sign bit set?
    pcmpeqd xmm5, xmm5
    pslld xmm5, 31
    movaps xmm1, xmm0
    andps xmm1, xmm5
    movmskps r9d, xmm1
    test r9d, r9d
    jnz @loop4_special

    // Zero/NaN/Inf check: abs(x) must be in (0, 0x7F800000)
    pcmpeqd xmm5, xmm5
    psrld xmm5, 1
    movaps xmm1, xmm0
    andps xmm1, xmm5           // abs(x)
    pxor xmm2, xmm2
    cmpps xmm2, xmm1, 4       // abs != 0
    movmskps r9d, xmm2
    cmp r9d, $0F
    jne @loop4_special
    mov r9d, $7F800000
    movd xmm2, r9d
    shufps xmm2, xmm2, 0
    cmpps xmm1, xmm2, 1       // abs < Inf
    movmskps r9d, xmm1
    cmp r9d, $0F
    jne @loop4_special

    // All positive normal → SIMD polynomial
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

    movaps xmm3, xmm2
    subps xmm3, xmm14
    movaps xmm4, xmm2
    addps xmm4, xmm14
    divps xmm3, xmm4
    movaps xmm0, xmm3

    movaps xmm2, xmm0
    mulps xmm2, xmm0

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
    jmp @loop4_advance

  @loop4_special:
    // FPU fallback: handles negative→NaN, zero→-Inf, NaN→NaN, +Inf→+Inf
    sub rsp, 8
    movss xmm0, [rax]
    movss [rsp], xmm0
    fld dword [rsp]
    fldln2
    fxch
    fyl2x
    fstp dword [rsp]
    movss xmm0, [rsp]
    movss [rcx], xmm0
    movss xmm0, [rax+4]
    movss [rsp], xmm0
    fld dword [rsp]
    fldln2
    fxch
    fyl2x
    fstp dword [rsp]
    movss xmm0, [rsp]
    movss [rcx+4], xmm0
    movss xmm0, [rax+8]
    movss [rsp], xmm0
    fld dword [rsp]
    fldln2
    fxch
    fyl2x
    fstp dword [rsp]
    movss xmm0, [rsp]
    movss [rcx+8], xmm0
    movss xmm0, [rax+12]
    movss [rsp], xmm0
    fld dword [rsp]
    fldln2
    fxch
    fyl2x
    fstp dword [rsp]
    movss xmm0, [rsp]
    movss [rcx+12], xmm0
    add rsp, 8

  @loop4_advance:
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

// === New Array* F32 Functions ===

procedure SSE2ArrayTanF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pSin, pCos, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;

  // 使用 threadvar 缓冲区，避免每次堆分配
  EnsureTanScratch(aCount);

  // Compute sin and cos using SIMD
  SSE2ArraySinF32(aSrc, GTanSinBuf, aCount);
  SSE2ArrayCosF32(aSrc, GTanCosBuf, aCount);

  // Divide: tan(x) = sin(x) / cos(x)
  pSin := GTanSinBuf;
  pCos := GTanCosBuf;
  pD := aDst;

  asm
    mov rax, pSin
    mov rdx, pCos
    mov rcx, pD
    mov r8, aCount

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]
    divps xmm0, [rdx]
    movups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

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

procedure SSE2ArraySinCosF32(aSrc, aSinDst, aCosDst: PSingle; aCount: SizeUInt);
begin
  // Compute sin and cos using existing SIMD implementations
  // This is still better than scalar because SSE2ArraySinF32/SSE2ArrayCosF32 use SIMD internally
  if aCount = 0 then Exit;
  SSE2ArraySinF32(aSrc, aSinDst, aCount);
  SSE2ArrayCosF32(aSrc, aCosDst, aCount);
end;

procedure SSE2ArrayLog2F32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
  LScale: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  // log2(x) = ln(x) * log2(e) = ln(x) * 1.4426950408889634
  SSE2ArrayLogF32(aSrc, aDst, aCount);
  LScale := 1.4426950408889634;
  pS := aDst;
  pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movss xmm1, [LScale]
    shufps xmm1, xmm1, 0

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]
    mulps xmm0, xmm1
    movups [rcx], xmm0
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
    mulss xmm0, xmm1
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayLog10F32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  pS, pD: PSingle;
  LScale: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  // log10(x) = ln(x) * log10(e) = ln(x) * 0.4342944819032518
  SSE2ArrayLogF32(aSrc, aDst, aCount);
  LScale := 0.4342944819032518;
  pS := aDst;
  pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movss xmm1, [LScale]
    shufps xmm1, xmm1, 0

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]
    mulps xmm0, xmm1
    movups [rcx], xmm0
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
    mulss xmm0, xmm1
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayCeilF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]
    roundps xmm0, xmm0, 2  // Round up (ceil)
    movups [rcx], xmm0
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
    roundss xmm0, xmm0, 2  // Round up (ceil)
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    sub r8, 1
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayFloorF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]
    roundps xmm0, xmm0, 1  // Round down (floor)
    movups [rcx], xmm0
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
    roundss xmm0, xmm0, 1  // Round down (floor)
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    sub r8, 1
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayRoundF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]
    roundps xmm0, xmm0, 0  // Round to nearest
    movups [rcx], xmm0
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
    roundss xmm0, xmm0, 0  // Round to nearest
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    sub r8, 1
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayTruncF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]
    roundps xmm0, xmm0, 3  // Truncate
    movups [rcx], xmm0
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
    roundss xmm0, xmm0, 3  // Truncate
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    sub r8, 1
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayLerpF32(aStart, aEnd, aDst: PSingle; aCount: SizeUInt; aT: Single);
var pS1, pS2, pD: PSingle; LT: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aStart; pS2 := aEnd; pD := aDst; LT := aT;
  asm
    mov rax, pS1
    mov rbx, pS2
    mov rcx, pD
    mov r8, aCount
    movss xmm7, [LT]
    shufps xmm7, xmm7, 0  // Broadcast t to all lanes

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]    // start
    movups xmm1, [rbx]    // end
    subps xmm1, xmm0      // diff = end - start
    mulps xmm1, xmm7      // diff * t
    addps xmm0, xmm1      // start + diff * t
    movups [rcx], xmm0
    add rax, 16
    add rbx, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done

  @scalar_loop:
    movss xmm0, [rax]     // start
    movss xmm1, [rbx]     // end
    subss xmm1, xmm0      // diff = end - start
    mulss xmm1, xmm7      // diff * t
    addss xmm0, xmm1      // start + diff * t
    movss [rcx], xmm0
    add rax, 4
    add rbx, 4
    add rcx, 4
    sub r8, 1
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

// ============================================================================
// New SSE2 Batch Operations: Atan2, Hypot, Fract, Mod, Sign, Step, Smoothstep
// ============================================================================

procedure SSE2ArrayAtan2F32(aY, aX, aDst: PSingle; aCount: SizeUInt);
begin
  // Delegate to scalar implementation (atan2 is complex to vectorize)
  ScalarArrayAtan2F32(aY, aX, aDst, aCount);
end;

procedure SSE2ArrayHypotF32(aX, aY, aDst: PSingle; aCount: SizeUInt);
var
  pX, pY, pD: PSingle;
  LOne: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pX := aX; pY := aY; pD := aDst;
  LOne := 1.0;

  asm
    mov rax, pX
    mov rdx, pY
    mov rcx, pD
    mov r8, aCount

    // Stable hypot: max*sqrt(1 + (min/max)^2) — avoids overflow
    pcmpeqd xmm6, xmm6
    psrld xmm6, 1           // xmm6 = 0x7FFFFFFF (abs mask)
    movss xmm7, [LOne]
    shufps xmm7, xmm7, 0    // xmm7 = [1, 1, 1, 1]

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]     // x
    movups xmm1, [rdx]     // y
    // abs
    movaps xmm2, xmm0
    andps xmm2, xmm6        // |x|
    movaps xmm3, xmm1
    andps xmm3, xmm6        // |y|
    // max = max(|x|,|y|), min = min(|x|,|y|)
    movaps xmm4, xmm2
    maxps xmm4, xmm3        // max
    minps xmm2, xmm3        // min
    // r = min/max, result = max * sqrt(1 + r*r)
    divps xmm2, xmm4        // r (garbage where max=0)
    mulps xmm2, xmm2        // r*r
    addps xmm2, xmm7        // 1 + r*r
    sqrtps xmm2, xmm2
    mulps xmm2, xmm4        // max * sqrt(1+r*r)
    // zero where max==0
    xorps xmm0, xmm0
    cmpps xmm4, xmm0, 4     // mask: max != 0
    andps xmm2, xmm4
    movups [rcx], xmm2
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done

  @scalar_loop:
    movss xmm0, [rax]
    movss xmm1, [rdx]
    andps xmm0, xmm6
    andps xmm1, xmm6
    movaps xmm2, xmm0
    maxss xmm2, xmm1        // max
    minss xmm0, xmm1        // min
    xorps xmm3, xmm3
    comiss xmm2, xmm3
    je @scalar_zero
    divss xmm0, xmm2
    mulss xmm0, xmm0
    addss xmm0, xmm7
    sqrtss xmm0, xmm0
    mulss xmm0, xmm2
    movss [rcx], xmm0
    jmp @scalar_next
  @scalar_zero:
    movss [rcx], xmm3
  @scalar_next:
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayFractF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]
    roundps xmm1, xmm0, 3  // Truncate
    subps xmm0, xmm1       // fract = x - trunc(x)
    movups [rcx], xmm0
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
    roundss xmm1, xmm0, 3  // Truncate
    subss xmm0, xmm1
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayModF32(aSrc, aDst: PSingle; aCount: SizeUInt; aDivisor: Single);
var
  pS, pD: PSingle;
  LDiv: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LDiv := aDivisor;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movss xmm1, [LDiv]
    shufps xmm1, xmm1, 0

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]
    movaps xmm2, xmm0
    divps xmm2, xmm1       // x / divisor
    roundps xmm2, xmm2, 3  // trunc(x / divisor)
    mulps xmm2, xmm1       // trunc(x / divisor) * divisor
    subps xmm0, xmm2       // x - trunc(x / divisor) * divisor
    movups [rcx], xmm0
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
    movss xmm2, xmm0
    divss xmm2, xmm1
    roundss xmm2, xmm2, 3
    mulss xmm2, xmm1
    subss xmm0, xmm2
    movss [rcx], xmm0
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArraySignF32(aSrc, aDst: PSingle; aCount: SizeUInt);
const
  ONE: Single = 1.0;
  MINUS_ONE: Single = -1.0;
var
  pS, pD: PSingle;
  LOne, LMinusOne: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc;
  pD := aDst;
  LOne := ONE;
  LMinusOne := MINUS_ONE;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    movss xmm2, [LOne]       // 1.0
    shufps xmm2, xmm2, 0    // broadcast to all lanes
    movss xmm3, [LMinusOne]  // -1.0
    shufps xmm3, xmm3, 0    // broadcast to all lanes

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rax]       // load src
    xorps xmm1, xmm1         // 0.0
    movaps xmm4, xmm0        // copy src
    cmpnleps xmm4, xmm1      // src > 0 (NOT src <= 0) => mask in xmm4
    movaps xmm5, xmm0        // copy src
    cmpltps xmm5, xmm1       // src < 0 => mask in xmm5
    andps xmm4, xmm2          // 1.0 where src > 0
    andps xmm5, xmm3          // -1.0 where src < 0
    orps xmm4, xmm5           // combine
    movups [rcx], xmm4
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
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja @positive
    jb @negative
    // zero case
    movss [rcx], xmm1
    jmp @next
  @positive:
    movss [rcx], xmm2
    jmp @next
  @negative:
    movss [rcx], xmm3
  @next:
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayStepF32(aEdge, aSrc, aDst: PSingle; aCount: SizeUInt);
const
  ONE: Single = 1.0;
var
  pE, pS, pD: PSingle;
  LOne: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pE := aEdge;
  pS := aSrc;
  pD := aDst;
  LOne := ONE;

  asm
    mov rax, pS       // src
    mov rdx, pE       // edge
    mov rcx, pD       // dst
    mov r8, aCount
    movss xmm2, [LOne]  // 1.0
    shufps xmm2, xmm2, 0

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movups xmm0, [rdx]       // edge
    movups xmm1, [rax]       // src
    cmpps xmm0, xmm1, 2     // edge <= src (LE), equivalent to src >= edge
    andps xmm0, xmm2         // 1.0 where src >= edge, 0.0 otherwise
    movups [rcx], xmm0
    add rax, 16
    add rdx, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done

  @scalar_loop:
    movss xmm0, [rdx]   // edge
    movss xmm1, [rax]   // src
    cmpps xmm0, xmm1, 2 // edge <= src
    andps xmm0, xmm2
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

procedure SSE2ArraySmoothstepF32(aEdge0, aEdge1, aSrc, aDst: PSingle; aCount: SizeUInt);
const
  THREE: Single = 3.0;
  TWO: Single = 2.0;
  ZERO: Single = 0.0;
  ONE_VAL: Single = 1.0;
var
  pE0, pE1, pS, pD: PSingle;
  LThree, LTwo, LZero, LOne: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pE0 := aEdge0;
  pE1 := aEdge1;
  pS := aSrc;
  pD := aDst;
  LThree := THREE;
  LTwo := TWO;
  LZero := ZERO;
  LOne := ONE_VAL;

  asm
    mov r9, pE0       // edge0
    mov r10, pE1      // edge1
    mov rax, pS       // src
    mov rcx, pD       // dst
    mov r8, aCount
    movss xmm4, [LThree]
    shufps xmm4, xmm4, 0   // 3.0 broadcast
    movss xmm5, [LTwo]
    shufps xmm5, xmm5, 0   // 2.0 broadcast
    movss xmm6, [LZero]
    shufps xmm6, xmm6, 0   // 0.0 broadcast
    movss xmm7, [LOne]
    shufps xmm7, xmm7, 0   // 1.0 broadcast

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    // v = (src - edge0) / (edge1 - edge0)
    movups xmm0, [rax]       // src
    movups xmm1, [r9]        // edge0
    movups xmm2, [r10]       // edge1
    subps xmm0, xmm1         // src - edge0
    subps xmm2, xmm1         // edge1 - edge0
    divps xmm0, xmm2         // (src - edge0) / (edge1 - edge0)

    // clamp v to [0, 1]
    maxps xmm0, xmm6         // v = max(v, 0)
    minps xmm0, xmm7         // v = min(v, 1)

    // t = v * v
    movaps xmm1, xmm0
    mulps xmm1, xmm1         // t = v*v

    // result = t * (3 - 2*v)
    movaps xmm2, xmm4        // 3.0
    movaps xmm3, xmm5        // 2.0
    mulps xmm3, xmm0         // 2*v
    subps xmm2, xmm3         // 3 - 2*v
    mulps xmm1, xmm2         // t * (3 - 2*v)

    movups [rcx], xmm1
    add r9, 16
    add r10, 16
    add rax, 16
    add rcx, 16
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done

  @scalar_loop:
    // v = (src - edge0) / (edge1 - edge0)
    movss xmm0, [rax]
    movss xmm1, [r9]
    movss xmm2, [r10]
    subss xmm0, xmm1
    subss xmm2, xmm1
    divss xmm0, xmm2

    // clamp
    maxps xmm0, xmm6
    minps xmm0, xmm7

    // t = v*v
    movaps xmm1, xmm0
    mulss xmm1, xmm1

    // result = t * (3 - 2*v)
    movaps xmm2, xmm4
    movaps xmm3, xmm5
    mulss xmm3, xmm0
    subss xmm2, xmm3
    mulss xmm1, xmm2

    movss [rcx], xmm1
    add r9, 4
    add r10, 4
    add rax, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

// ============================================================================
// I8 Batch Operations
// ============================================================================

procedure SSE2ArrayAddI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
var pS1, pS2, pD: PInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 64; jb @tail32
  @loop64:
    movdqu xmm0, [rax]; paddb xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddb xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; paddb xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; paddb xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 64; cmp r8, 64; jae @loop64
  @tail32:
    cmp r8, 32; jb @tail16
    movdqu xmm0, [rax]; paddb xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddb xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 32
  @tail16:
    cmp r8, 16; jb @tail_scalar
    movdqu xmm0, [rax]; paddb xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9b, [rax]; add r9b, [rdx]; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArraySubI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
var pS1, pS2, pD: PInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 64; jb @tail32
  @loop64:
    movdqu xmm0, [rax]; psubb xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubb xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; psubb xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; psubb xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 64; cmp r8, 64; jae @loop64
  @tail32:
    cmp r8, 32; jb @tail16
    movdqu xmm0, [rax]; psubb xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubb xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 32
  @tail16:
    cmp r8, 16; jb @tail_scalar
    movdqu xmm0, [rax]; psubb xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9b, [rax]; sub r9b, [rdx]; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayMulI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
var pS1, pS2, pD: PInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail_scalar
  @loop16:
    // SSE2 没有 pmullb for 16xI8, 使用标量
    // 注意：imul 不能直接对 8 位寄存器和内存操作数运算，需要先加载到 32 位寄存器
    movzx r9d, byte [rax]; movzx r10d, byte [rdx]; imul r9d, r10d; mov [rcx], r9b
    movzx r9d, byte [rax + 1]; movzx r10d, byte [rdx + 1]; imul r9d, r10d; mov [rcx + 1], r9b
    movzx r9d, byte [rax + 2]; movzx r10d, byte [rdx + 2]; imul r9d, r10d; mov [rcx + 2], r9b
    movzx r9d, byte [rax + 3]; movzx r10d, byte [rdx + 3]; imul r9d, r10d; mov [rcx + 3], r9b
    movzx r9d, byte [rax + 4]; movzx r10d, byte [rdx + 4]; imul r9d, r10d; mov [rcx + 4], r9b
    movzx r9d, byte [rax + 5]; movzx r10d, byte [rdx + 5]; imul r9d, r10d; mov [rcx + 5], r9b
    movzx r9d, byte [rax + 6]; movzx r10d, byte [rdx + 6]; imul r9d, r10d; mov [rcx + 6], r9b
    movzx r9d, byte [rax + 7]; movzx r10d, byte [rdx + 7]; imul r9d, r10d; mov [rcx + 7], r9b
    movzx r9d, byte [rax + 8]; movzx r10d, byte [rdx + 8]; imul r9d, r10d; mov [rcx + 8], r9b
    movzx r9d, byte [rax + 9]; movzx r10d, byte [rdx + 9]; imul r9d, r10d; mov [rcx + 9], r9b
    movzx r9d, byte [rax + 10]; movzx r10d, byte [rdx + 10]; imul r9d, r10d; mov [rcx + 10], r9b
    movzx r9d, byte [rax + 11]; movzx r10d, byte [rdx + 11]; imul r9d, r10d; mov [rcx + 11], r9b
    movzx r9d, byte [rax + 12]; movzx r10d, byte [rdx + 12]; imul r9d, r10d; mov [rcx + 12], r9b
    movzx r9d, byte [rax + 13]; movzx r10d, byte [rdx + 13]; imul r9d, r10d; mov [rcx + 13], r9b
    movzx r9d, byte [rax + 14]; movzx r10d, byte [rdx + 14]; imul r9d, r10d; mov [rcx + 14], r9b
    movzx r9d, byte [rax + 15]; movzx r10d, byte [rdx + 15]; imul r9d, r10d; mov [rcx + 15], r9b
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16; cmp r8, 16; jae @loop16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    movzx r9d, byte [rax]; movzx r10d, byte [rdx]; imul r9d, r10d; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAndI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
var pS1, pS2, pD: PInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 64; jb @tail32
  @loop64:
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pand xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pand xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 64; cmp r8, 64; jae @loop64
  @tail32:
    cmp r8, 32; jb @tail16
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 32
  @tail16:
    cmp r8, 16; jb @tail_scalar
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9b, [rax]; and r9b, [rdx]; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayOrI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
var pS1, pS2, pD: PInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 64; jb @tail32
  @loop64:
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; por xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; por xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 64; cmp r8, 64; jae @loop64
  @tail32:
    cmp r8, 32; jb @tail16
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 32
  @tail16:
    cmp r8, 16; jb @tail_scalar
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9b, [rax]; or r9b, [rdx]; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayXorI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt);
var pS1, pS2, pD: PInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 64; jb @tail32
  @loop64:
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pxor xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pxor xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 64; cmp r8, 64; jae @loop64
  @tail32:
    cmp r8, 32; jb @tail16
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 32
  @tail16:
    cmp r8, 16; jb @tail_scalar
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9b, [rax]; xor r9b, [rdx]; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

// ============================================================================
// U8 Batch Operations (same as I8 - add/sub/and/or/xor are identical)
// ============================================================================

procedure SSE2ArrayAddU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
var pS1, pS2, pD: PUInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 64; jb @tail32
  @loop64:
    movdqu xmm0, [rax]; paddb xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddb xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; paddb xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; paddb xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 64; cmp r8, 64; jae @loop64
  @tail32:
    cmp r8, 32; jb @tail16
    movdqu xmm0, [rax]; paddb xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddb xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 32
  @tail16:
    cmp r8, 16; jb @tail_scalar
    movdqu xmm0, [rax]; paddb xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9b, [rax]; add r9b, [rdx]; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArraySubU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
var pS1, pS2, pD: PUInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 64; jb @tail32
  @loop64:
    movdqu xmm0, [rax]; psubb xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubb xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; psubb xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; psubb xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 64; cmp r8, 64; jae @loop64
  @tail32:
    cmp r8, 32; jb @tail16
    movdqu xmm0, [rax]; psubb xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubb xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 32
  @tail16:
    cmp r8, 16; jb @tail_scalar
    movdqu xmm0, [rax]; psubb xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9b, [rax]; sub r9b, [rdx]; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayMulU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
var pS1, pS2, pD: PUInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail_scalar
  @loop16:
    // SSE2 没有 pmullb for 16xU8, 使用标量
    // 注意：mul 指令在 x86 中是对 al 寄存器进行操作的，需要使用 movzx + imul
    movzx r9d, byte [rax]; movzx r10d, byte [rdx]; imul r9d, r10d; mov [rcx], r9b
    movzx r9d, byte [rax + 1]; movzx r10d, byte [rdx + 1]; imul r9d, r10d; mov [rcx + 1], r9b
    movzx r9d, byte [rax + 2]; movzx r10d, byte [rdx + 2]; imul r9d, r10d; mov [rcx + 2], r9b
    movzx r9d, byte [rax + 3]; movzx r10d, byte [rdx + 3]; imul r9d, r10d; mov [rcx + 3], r9b
    movzx r9d, byte [rax + 4]; movzx r10d, byte [rdx + 4]; imul r9d, r10d; mov [rcx + 4], r9b
    movzx r9d, byte [rax + 5]; movzx r10d, byte [rdx + 5]; imul r9d, r10d; mov [rcx + 5], r9b
    movzx r9d, byte [rax + 6]; movzx r10d, byte [rdx + 6]; imul r9d, r10d; mov [rcx + 6], r9b
    movzx r9d, byte [rax + 7]; movzx r10d, byte [rdx + 7]; imul r9d, r10d; mov [rcx + 7], r9b
    movzx r9d, byte [rax + 8]; movzx r10d, byte [rdx + 8]; imul r9d, r10d; mov [rcx + 8], r9b
    movzx r9d, byte [rax + 9]; movzx r10d, byte [rdx + 9]; imul r9d, r10d; mov [rcx + 9], r9b
    movzx r9d, byte [rax + 10]; movzx r10d, byte [rdx + 10]; imul r9d, r10d; mov [rcx + 10], r9b
    movzx r9d, byte [rax + 11]; movzx r10d, byte [rdx + 11]; imul r9d, r10d; mov [rcx + 11], r9b
    movzx r9d, byte [rax + 12]; movzx r10d, byte [rdx + 12]; imul r9d, r10d; mov [rcx + 12], r9b
    movzx r9d, byte [rax + 13]; movzx r10d, byte [rdx + 13]; imul r9d, r10d; mov [rcx + 13], r9b
    movzx r9d, byte [rax + 14]; movzx r10d, byte [rdx + 14]; imul r9d, r10d; mov [rcx + 14], r9b
    movzx r9d, byte [rax + 15]; movzx r10d, byte [rdx + 15]; imul r9d, r10d; mov [rcx + 15], r9b
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16; cmp r8, 16; jae @loop16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    movzx r9d, byte [rax]; movzx r10d, byte [rdx]; imul r9d, r10d; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAndU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
var pS1, pS2, pD: PUInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 64; jb @tail32
  @loop64:
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pand xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pand xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 64; cmp r8, 64; jae @loop64
  @tail32:
    cmp r8, 32; jb @tail16
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 32
  @tail16:
    cmp r8, 16; jb @tail_scalar
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9b, [rax]; and r9b, [rdx]; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayOrU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
var pS1, pS2, pD: PUInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 64; jb @tail32
  @loop64:
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; por xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; por xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 64; cmp r8, 64; jae @loop64
  @tail32:
    cmp r8, 32; jb @tail16
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 32
  @tail16:
    cmp r8, 16; jb @tail_scalar
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9b, [rax]; or r9b, [rdx]; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayXorU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt);
var pS1, pS2, pD: PUInt8;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 64; jb @tail32
  @loop64:
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pxor xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pxor xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 64; cmp r8, 64; jae @loop64
  @tail32:
    cmp r8, 32; jb @tail16
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 32
  @tail16:
    cmp r8, 16; jb @tail_scalar
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 16
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9b, [rax]; xor r9b, [rdx]; mov [rcx], r9b
    add rax, 1; add rdx, 1; add rcx, 1; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

// ============================================================================
// I16 Batch Operations
// ============================================================================

procedure SSE2ArrayAddI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
var pS1, pS2, pD: PInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 32; jb @tail16
  @loop32:
    movdqu xmm0, [rax]; paddw xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddw xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; paddw xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; paddw xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 32; cmp r8, 32; jae @loop32
  @tail16:
    cmp r8, 16; jb @tail8
    movdqu xmm0, [rax]; paddw xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddw xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 16
  @tail8:
    cmp r8, 8; jb @tail_scalar
    movdqu xmm0, [rax]; paddw xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 8
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9w, [rax]; add r9w, [rdx]; mov [rcx], r9w
    add rax, 2; add rdx, 2; add rcx, 2; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArraySubI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
var pS1, pS2, pD: PInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 32; jb @tail16
  @loop32:
    movdqu xmm0, [rax]; psubw xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubw xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; psubw xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; psubw xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 32; cmp r8, 32; jae @loop32
  @tail16:
    cmp r8, 16; jb @tail8
    movdqu xmm0, [rax]; psubw xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubw xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 16
  @tail8:
    cmp r8, 8; jb @tail_scalar
    movdqu xmm0, [rax]; psubw xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 8
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9w, [rax]; sub r9w, [rdx]; mov [rcx], r9w
    add rax, 2; add rdx, 2; add rcx, 2; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAndI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
var pS1, pS2, pD: PInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 32; jb @tail16
  @loop32:
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pand xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pand xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 32; cmp r8, 32; jae @loop32
  @tail16:
    cmp r8, 16; jb @tail8
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 16
  @tail8:
    cmp r8, 8; jb @tail_scalar
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 8
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9w, [rax]; and r9w, [rdx]; mov [rcx], r9w
    add rax, 2; add rdx, 2; add rcx, 2; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayOrI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
var pS1, pS2, pD: PInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 32; jb @tail16
  @loop32:
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; por xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; por xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 32; cmp r8, 32; jae @loop32
  @tail16:
    cmp r8, 16; jb @tail8
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 16
  @tail8:
    cmp r8, 8; jb @tail_scalar
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 8
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9w, [rax]; or r9w, [rdx]; mov [rcx], r9w
    add rax, 2; add rdx, 2; add rcx, 2; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayXorI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
var pS1, pS2, pD: PInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 32; jb @tail16
  @loop32:
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pxor xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pxor xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 32; cmp r8, 32; jae @loop32
  @tail16:
    cmp r8, 16; jb @tail8
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 16
  @tail8:
    cmp r8, 8; jb @tail_scalar
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 8
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9w, [rax]; xor r9w, [rdx]; mov [rcx], r9w
    add rax, 2; add rdx, 2; add rcx, 2; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

// ============================================================================
// U16 Batch Operations (same as I16 - add/sub/and/or/xor are identical)
// ============================================================================

procedure SSE2ArrayAddU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
var pS1, pS2, pD: PUInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 32; jb @tail16
  @loop32:
    movdqu xmm0, [rax]; paddw xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddw xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; paddw xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; paddw xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 32; cmp r8, 32; jae @loop32
  @tail16:
    cmp r8, 16; jb @tail8
    movdqu xmm0, [rax]; paddw xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddw xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 16
  @tail8:
    cmp r8, 8; jb @tail_scalar
    movdqu xmm0, [rax]; paddw xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 8
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9w, [rax]; add r9w, [rdx]; mov [rcx], r9w
    add rax, 2; add rdx, 2; add rcx, 2; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArraySubU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
var pS1, pS2, pD: PUInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 32; jb @tail16
  @loop32:
    movdqu xmm0, [rax]; psubw xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubw xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; psubw xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; psubw xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 32; cmp r8, 32; jae @loop32
  @tail16:
    cmp r8, 16; jb @tail8
    movdqu xmm0, [rax]; psubw xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubw xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 16
  @tail8:
    cmp r8, 8; jb @tail_scalar
    movdqu xmm0, [rax]; psubw xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 8
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9w, [rax]; sub r9w, [rdx]; mov [rcx], r9w
    add rax, 2; add rdx, 2; add rcx, 2; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayMulU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
var pS1, pS2, pD: PUInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 8; jb @tail_scalar
  @loop8:
    // SSE2 没有 pmullw for 8xU16, 使用标量
    movzx r9d, word [rax]; movzx r10d, word [rdx]; imul r9d, r10d; mov [rcx], r9w
    movzx r9d, word [rax + 2]; movzx r10d, word [rdx + 2]; imul r9d, r10d; mov [rcx + 2], r9w
    movzx r9d, word [rax + 4]; movzx r10d, word [rdx + 4]; imul r9d, r10d; mov [rcx + 4], r9w
    movzx r9d, word [rax + 6]; movzx r10d, word [rdx + 6]; imul r9d, r10d; mov [rcx + 6], r9w
    movzx r9d, word [rax + 8]; movzx r10d, word [rdx + 8]; imul r9d, r10d; mov [rcx + 8], r9w
    movzx r9d, word [rax + 10]; movzx r10d, word [rdx + 10]; imul r9d, r10d; mov [rcx + 10], r9w
    movzx r9d, word [rax + 12]; movzx r10d, word [rdx + 12]; imul r9d, r10d; mov [rcx + 12], r9w
    movzx r9d, word [rax + 14]; movzx r10d, word [rdx + 14]; imul r9d, r10d; mov [rcx + 14], r9w
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 8; cmp r8, 8; jae @loop8
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    movzx r9d, word [rax]; movzx r10d, word [rdx]; imul r9d, r10d; mov [rcx], r9w
    add rax, 2; add rdx, 2; add rcx, 2; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAndU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
var pS1, pS2, pD: PUInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 32; jb @tail16
  @loop32:
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pand xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pand xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 32; cmp r8, 32; jae @loop32
  @tail16:
    cmp r8, 16; jb @tail8
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 16
  @tail8:
    cmp r8, 8; jb @tail_scalar
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 8
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9w, [rax]; and r9w, [rdx]; mov [rcx], r9w
    add rax, 2; add rdx, 2; add rcx, 2; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayOrU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
var pS1, pS2, pD: PUInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 32; jb @tail16
  @loop32:
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; por xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; por xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 32; cmp r8, 32; jae @loop32
  @tail16:
    cmp r8, 16; jb @tail8
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 16
  @tail8:
    cmp r8, 8; jb @tail_scalar
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 8
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9w, [rax]; or r9w, [rdx]; mov [rcx], r9w
    add rax, 2; add rdx, 2; add rcx, 2; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayXorU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt);
var pS1, pS2, pD: PUInt16;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 32; jb @tail16
  @loop32:
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pxor xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pxor xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 32; cmp r8, 32; jae @loop32
  @tail16:
    cmp r8, 16; jb @tail8
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 16
  @tail8:
    cmp r8, 8; jb @tail_scalar
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 8
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9w, [rax]; xor r9w, [rdx]; mov [rcx], r9w
    add rax, 2; add rdx, 2; add rcx, 2; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

// ============================================================================
// I64 Batch Operations
// ============================================================================

procedure SSE2ArrayAddI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
var pS1, pS2, pD: PInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; paddq xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddq xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; paddq xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; paddq xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; paddq xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddq xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail2
    movdqu xmm0, [rax]; paddq xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail2:
    cmp r8, 2; jb @tail_scalar
    movq xmm0, [rax]; movq xmm1, [rdx]; paddq xmm0, xmm1; movq [rcx], xmm0
    add rax, 8; add rdx, 8; add rcx, 8; sub r8, 2
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; add r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArraySubI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
var pS1, pS2, pD: PInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; psubq xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubq xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; psubq xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; psubq xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; psubq xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubq xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail2
    movdqu xmm0, [rax]; psubq xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail2:
    cmp r8, 2; jb @tail_scalar
    movq xmm0, [rax]; movq xmm1, [rdx]; psubq xmm0, xmm1; movq [rcx], xmm0
    add rax, 8; add rdx, 8; add rcx, 8; sub r8, 2
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; sub r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayMulI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
var pS1, pS2, pD: PInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 4; jb @tail_scalar
  @loop4:
    // SSE2 没有 pmuludq for 4xI64, 使用标量
    mov r9, [rax]; imul r9, [rdx]; mov [rcx], r9
    mov r9, [rax + 8]; imul r9, [rdx + 8]; mov [rcx + 8], r9
    mov r9, [rax + 16]; imul r9, [rdx + 16]; mov [rcx + 16], r9
    mov r9, [rax + 24]; imul r9, [rdx + 24]; mov [rcx + 24], r9
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 4; cmp r8, 4; jae @loop4
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; imul r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAndI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
var pS1, pS2, pD: PInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pand xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pand xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail2
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail2:
    cmp r8, 2; jb @tail_scalar
    movq xmm0, [rax]; movq xmm1, [rdx]; pand xmm0, xmm1; movq [rcx], xmm0
    add rax, 8; add rdx, 8; add rcx, 8; sub r8, 2
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; and r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayOrI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
var pS1, pS2, pD: PInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; por xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; por xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail2
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail2:
    cmp r8, 2; jb @tail_scalar
    movq xmm0, [rax]; movq xmm1, [rdx]; por xmm0, xmm1; movq [rcx], xmm0
    add rax, 8; add rdx, 8; add rcx, 8; sub r8, 2
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; or r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayXorI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt);
var pS1, pS2, pD: PInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pxor xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pxor xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail2
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail2:
    cmp r8, 2; jb @tail_scalar
    movq xmm0, [rax]; movq xmm1, [rdx]; pxor xmm0, xmm1; movq [rcx], xmm0
    add rax, 8; add rdx, 8; add rcx, 8; sub r8, 2
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; xor r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

// ============================================================================
// U64 Batch Operations (same as I64 - add/sub/and/or/xor are identical)
// ============================================================================

procedure SSE2ArrayAddU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
var pS1, pS2, pD: PUInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; paddq xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddq xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; paddq xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; paddq xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; paddq xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; paddq xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail2
    movdqu xmm0, [rax]; paddq xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail2:
    cmp r8, 2; jb @tail_scalar
    movq xmm0, [rax]; movq xmm1, [rdx]; paddq xmm0, xmm1; movq [rcx], xmm0
    add rax, 8; add rdx, 8; add rcx, 8; sub r8, 2
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; add r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArraySubU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
var pS1, pS2, pD: PUInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; psubq xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubq xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; psubq xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; psubq xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; psubq xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; psubq xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail2
    movdqu xmm0, [rax]; psubq xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail2:
    cmp r8, 2; jb @tail_scalar
    movq xmm0, [rax]; movq xmm1, [rdx]; psubq xmm0, xmm1; movq [rcx], xmm0
    add rax, 8; add rdx, 8; add rcx, 8; sub r8, 2
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; sub r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayMulU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
var pS1, pS2, pD: PUInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 4; jb @tail_scalar
  @loop4:
    // SSE2 没有 pmuludq for 4xU64, 使用标量
    // 注意：mul 指令只能对 rax 寄存器操作，使用 imul 替代
    mov r9, [rax]; imul r9, [rdx]; mov [rcx], r9
    mov r9, [rax + 8]; imul r9, [rdx + 8]; mov [rcx + 8], r9
    mov r9, [rax + 16]; imul r9, [rdx + 16]; mov [rcx + 16], r9
    mov r9, [rax + 24]; imul r9, [rdx + 24]; mov [rcx + 24], r9
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 4; cmp r8, 4; jae @loop4
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; imul r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayAndU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
var pS1, pS2, pD: PUInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pand xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pand xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pand xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail2
    movdqu xmm0, [rax]; pand xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail2:
    cmp r8, 2; jb @tail_scalar
    movq xmm0, [rax]; movq xmm1, [rdx]; pand xmm0, xmm1; movq [rcx], xmm0
    add rax, 8; add rdx, 8; add rcx, 8; sub r8, 2
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; and r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayOrU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
var pS1, pS2, pD: PUInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; por xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; por xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; por xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail2
    movdqu xmm0, [rax]; por xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail2:
    cmp r8, 2; jb @tail_scalar
    movq xmm0, [rax]; movq xmm1, [rdx]; por xmm0, xmm1; movq [rcx], xmm0
    add rax, 8; add rdx, 8; add rcx, 8; sub r8, 2
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; or r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;

procedure SSE2ArrayXorU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt);
var pS1, pS2, pD: PUInt64;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS1 := aSrc1; pS2 := aSrc2; pD := aDst;
  asm
    mov rax, pS1; mov rdx, pS2; mov rcx, pD; mov r8, aCount
    cmp r8, 16; jb @tail8
  @loop16:
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    movdqu xmm2, [rax + 32]; pxor xmm2, [rdx + 32]; movdqu [rcx + 32], xmm2
    movdqu xmm3, [rax + 48]; pxor xmm3, [rdx + 48]; movdqu [rcx + 48], xmm3
    add rax, 64; add rdx, 64; add rcx, 64; sub r8, 16; cmp r8, 16; jae @loop16
  @tail8:
    cmp r8, 8; jb @tail4
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    movdqu xmm1, [rax + 16]; pxor xmm1, [rdx + 16]; movdqu [rcx + 16], xmm1
    add rax, 32; add rdx, 32; add rcx, 32; sub r8, 8
  @tail4:
    cmp r8, 4; jb @tail2
    movdqu xmm0, [rax]; pxor xmm0, [rdx]; movdqu [rcx], xmm0
    add rax, 16; add rdx, 16; add rcx, 16; sub r8, 4
  @tail2:
    cmp r8, 2; jb @tail_scalar
    movq xmm0, [rax]; movq xmm1, [rdx]; pxor xmm0, xmm1; movq [rcx], xmm0
    add rax, 8; add rdx, 8; add rcx, 8; sub r8, 2
  @tail_scalar:
    test r8, r8; jz @done
  @scalar_loop:
    mov r9, [rax]; xor r9, [rdx]; mov [rcx], r9
    add rax, 8; add rdx, 8; add rcx, 8; dec r8; jnz @scalar_loop
  @done:
  end;
  {$POP}
end;
