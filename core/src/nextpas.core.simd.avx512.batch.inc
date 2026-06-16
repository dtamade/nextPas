// ============================================================================
// AVX-512 Batch Array Operations
// 策略: 4x ZMM 展开 (每轮 64 float32 = 256 bytes), pointer bump
// ============================================================================

procedure AVX512ArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
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

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vaddps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vaddps zmm1, zmm1, [rdx + 64]
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vaddps zmm2, zmm2, [rdx + 128]
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vaddps zmm3, zmm3, [rdx + 192]
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rdx, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vaddps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

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

procedure AVX512ArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
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

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vsubps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vsubps zmm1, zmm1, [rdx + 64]
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vsubps zmm2, zmm2, [rdx + 128]
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vsubps zmm3, zmm3, [rdx + 192]
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rdx, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vsubps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

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

procedure AVX512ArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
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

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vmulps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vmulps zmm1, zmm1, [rdx + 64]
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vmulps zmm2, zmm2, [rdx + 128]
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vmulps zmm3, zmm3, [rdx + 192]
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rdx, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vmulps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

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

procedure AVX512ArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
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

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vdivps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vdivps zmm1, zmm1, [rdx + 64]
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vdivps zmm2, zmm2, [rdx + 128]
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vdivps zmm3, zmm3, [rdx + 192]
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rdx, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vdivps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

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

procedure AVX512ArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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
    vpbroadcastd zmm7, xmm7

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]
    vpandd zmm0, zmm0, zmm7
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vpandd xmm0, xmm0, xmm7
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

procedure AVX512ArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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
    vpbroadcastd zmm7, xmm7

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]
    vpxord zmm0, zmm0, zmm7
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vpxord xmm0, xmm0, xmm7
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

procedure AVX512ArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]
    vsqrtps zmm0, zmm0
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

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

// ============================================================================
// AVX-512 ArrayExpF32 — ZMM (16 floats/iter), 7th-order minimax, <2 ULP
// ============================================================================

procedure AVX512ArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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

    vbroadcastss zmm15, [LLog2e]
    vbroadcastss zmm14, [LLn2Hi]
    vbroadcastss zmm13, [LLn2Lo]
    vbroadcastss zmm12, [LP0]
    vbroadcastss zmm11, [LP1]
    vbroadcastss zmm10, [LP2]
    vbroadcastss zmm9, [LP3]
    vbroadcastss zmm8, [LP4]
    vbroadcastss zmm7, [LP5]
    vbroadcastss zmm6, [LP6]
    vbroadcastss zmm5, [LMaxX]
    vbroadcastss zmm4, [LMinX]

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]
    vminps zmm0, zmm0, zmm5
    vmaxps zmm0, zmm0, zmm4

    vmulps zmm1, zmm0, zmm15
    vrndscaleps zmm1, zmm1, $08

    vmulps zmm2, zmm1, zmm14
    vsubps zmm0, zmm0, zmm2
    vmulps zmm2, zmm1, zmm13
    vsubps zmm0, zmm0, zmm2

    vmovaps zmm2, zmm6
    vfmadd213ps zmm2, zmm0, zmm7
    vfmadd213ps zmm2, zmm0, zmm8
    vfmadd213ps zmm2, zmm0, zmm9
    vfmadd213ps zmm2, zmm0, zmm10
    vfmadd213ps zmm2, zmm0, zmm11
    vfmadd213ps zmm2, zmm0, zmm12

    vcvtps2dq zmm1, zmm1
    vpslld zmm1, zmm1, 23
    vpaddd zmm2, zmm2, zmm1

    vmovups [rcx], zmm2
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

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
// AVX-512 ArrayLogF32 — ZMM (16 floats/iter), atanh transform, <4 ULP
// ============================================================================

procedure AVX512ArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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

    vbroadcastss zmm15, [LLn2]
    vbroadcastss zmm14, [LOne]
    vbroadcastss zmm13, [LTwo]
    vbroadcastss zmm12, [LThirdInv]
    vbroadcastss zmm11, [LFifthInv]
    vbroadcastss zmm10, [LSeventhInv]

    mov r9d, $007FFFFF
    vmovd xmm9, r9d
    vpbroadcastd zmm9, xmm9

    mov r9d, $3F000000
    vmovd xmm8, r9d
    vpbroadcastd zmm8, xmm8

    mov r9d, $3F3504F3
    vmovd xmm7, r9d
    vpbroadcastd zmm7, xmm7

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]

    vpsrld zmm1, zmm0, 23
    mov r9d, 126
    vmovd xmm6, r9d
    vpbroadcastd zmm6, xmm6
    vpsubd zmm1, zmm1, zmm6

    vpandd zmm2, zmm0, zmm9
    vpord zmm2, zmm2, zmm8

    vcmpltps k1, zmm2, zmm7
    vaddps zmm3, zmm2, zmm2
    vmovaps zmm2{k1}, zmm3

    mov r9d, 1
    vmovd xmm6, r9d
    vpbroadcastd zmm6, xmm6
    vpsubd zmm1{k1}, zmm1, zmm6

    vsubps zmm3, zmm2, zmm14
    vaddps zmm4, zmm2, zmm14
    vdivps zmm0, zmm3, zmm4

    vmulps zmm2, zmm0, zmm0

    vmovaps zmm3, zmm10
    vfmadd213ps zmm3, zmm2, zmm11
    vfmadd213ps zmm3, zmm2, zmm12
    vfmadd213ps zmm3, zmm2, zmm14
    vmulps zmm3, zmm3, zmm0
    vmulps zmm3, zmm3, zmm13

    vcvtdq2ps zmm1, zmm1
    vfmadd231ps zmm3, zmm1, zmm15

    vmovups [rcx], zmm3
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

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
// AVX-512 Fused Kernels (using native mask instructions)
// ============================================================================

procedure AVX512ArrayLinearF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
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
    vbroadcastss zmm6, [LScale]
    vbroadcastss zmm7, [LBias]

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vfmadd213ps zmm0, zmm6, zmm7
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vfmadd213ps zmm1, zmm6, zmm7
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vfmadd213ps zmm2, zmm6, zmm7
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vfmadd213ps zmm3, zmm6, zmm7
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vfmadd213ps zmm0, zmm6, zmm7
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

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

procedure AVX512ArrayReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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
    vpxord zmm7, zmm7, zmm7   // zero

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]
    vmaxps zmm0, zmm0, zmm7
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

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

procedure AVX512ArrayNormF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single);
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
    vbroadcastss zmm6, [LMean]
    vbroadcastss zmm7, [LInvStd]

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]
    vsubps zmm0, zmm0, zmm6
    vmulps zmm0, zmm0, zmm7
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

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
// AVX-512 ArraySinF32 — ZMM (16 floats/iter), native mask for quadrant select
// ============================================================================

procedure AVX512ArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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

    vbroadcastss zmm15, [L2OverPi]
    vbroadcastss zmm14, [LPiOver2Hi]
    vbroadcastss zmm13, [LPiOver2Mid]
    vbroadcastss zmm12, [LS1]
    vbroadcastss zmm11, [LS2]
    vbroadcastss zmm10, [LS3]
    vbroadcastss zmm9, [LC1]
    vbroadcastss zmm8, [LC2]
    vbroadcastss zmm7, [LC3]
    vbroadcastss zmm6, [LOne]

    // sign mask
    mov r9d, $80000000
    vmovd xmm5, r9d
    vpbroadcastd zmm5, xmm5

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]

    // sign(x) and |x|
    vpandd zmm4, zmm0, zmm5
    vpandnd zmm0, zmm5, zmm0

    // j = round(|x| * 2/pi)
    vmulps zmm1, zmm0, zmm15
    vrndscaleps zmm1, zmm1, $08
    vcvtps2dq zmm3, zmm1

    // Extract masks: j&2 sign, j&1 blend
    vpsrld zmm2, zmm3, 1
    vpslld zmm2, zmm2, 31
    vpxord zmm4, zmm4, zmm2      // combined sign

    vpslld zmm3, zmm3, 31        // blend mask in bit31

    // r = |x| - j*(pi/2)
    vmulps zmm2, zmm1, zmm14
    vsubps zmm0, zmm0, zmm2
    vmulps zmm2, zmm1, zmm13
    vsubps zmm0, zmm0, zmm2

    // r²
    vmulps zmm2, zmm0, zmm0

    // Sin poly
    vmovaps zmm1, zmm10
    vfmadd213ps zmm1, zmm2, zmm11
    vfmadd213ps zmm1, zmm2, zmm12
    vfmadd213ps zmm1, zmm2, zmm6
    vmulps zmm1, zmm1, zmm0

    // Cos poly
    vmovaps zmm0, zmm7
    vfmadd213ps zmm0, zmm2, zmm8
    vfmadd213ps zmm0, zmm2, zmm9
    vmulps zmm0, zmm0, zmm2
    vaddps zmm0, zmm0, zmm6

    // Blend using zmm3 bit31: odd j → cos, even j → sin
    // zmm0 = cos_result, zmm1 = sin_result
    // k1 = j odd (keep cos), k2 = j even (write sin)
    vptestmd k1, zmm3, zmm3      // k1 = lanes where j odd
    knotw k2, k1                  // k2 = lanes where j even
    vmovaps zmm0{k2}, zmm1       // sin where j even, cos stays where j odd

    // Apply sign
    vpxord zmm0, zmm0, zmm4

    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

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

procedure AVX512ArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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

    vbroadcastss zmm15, [L2OverPi]
    vbroadcastss zmm14, [LPiOver2Hi]
    vbroadcastss zmm13, [LPiOver2Mid]
    vbroadcastss zmm12, [LS1]
    vbroadcastss zmm11, [LS2]
    vbroadcastss zmm10, [LS3]
    vbroadcastss zmm9, [LC1]
    vbroadcastss zmm8, [LC2]
    vbroadcastss zmm7, [LC3]
    vbroadcastss zmm6, [LOne]

    mov r9d, $80000000
    vmovd xmm5, r9d
    vpbroadcastd zmm5, xmm5

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]
    vpandnd zmm0, zmm5, zmm0     // |x| (cos is even function)

    vmulps zmm1, zmm0, zmm15
    vrndscaleps zmm1, zmm1, $08
    vcvtps2dq zmm3, zmm1

    // For cos: use j+1
    mov r9d, 1
    vmovd xmm4, r9d
    vpbroadcastd zmm4, xmm4
    vpaddd zmm3, zmm3, zmm4

    // (j+1)&2 sign
    vpsrld zmm2, zmm3, 1
    vpslld zmm4, zmm2, 31        // sign mask

    // (j+1)&1 blend
    vpslld zmm3, zmm3, 31

    // r
    vmulps zmm2, zmm1, zmm14
    vsubps zmm0, zmm0, zmm2
    vmulps zmm2, zmm1, zmm13
    vsubps zmm0, zmm0, zmm2

    vmulps zmm2, zmm0, zmm0

    // Sin poly
    vmovaps zmm1, zmm10
    vfmadd213ps zmm1, zmm2, zmm11
    vfmadd213ps zmm1, zmm2, zmm12
    vfmadd213ps zmm1, zmm2, zmm6
    vmulps zmm1, zmm1, zmm0

    // Cos poly
    vmovaps zmm0, zmm7
    vfmadd213ps zmm0, zmm2, zmm8
    vfmadd213ps zmm0, zmm2, zmm9
    vmulps zmm0, zmm0, zmm2
    vaddps zmm0, zmm0, zmm6

    // Blend
    vptestmd k1, zmm3, zmm3
    knotw k2, k1
    vmovaps zmm0{k2}, zmm1

    // Sign
    vpxord zmm0, zmm0, zmm4

    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

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

procedure AVX512ArrayAbsDiffF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
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

    mov r9d, $7FFFFFFF
    vmovd xmm7, r9d
    vpbroadcastd zmm7, xmm7

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]
    vsubps zmm0, zmm0, [rdx]
    vpandd zmm0, zmm0, zmm7
    vmovups [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

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

procedure AVX512ArrayLinearReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
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
    vbroadcastss zmm6, [LScale]
    vbroadcastss zmm7, [LBias]
    vxorps zmm5, zmm5, zmm5

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vfmadd213ps zmm0, zmm6, zmm7
    vmaxps zmm0, zmm0, zmm5
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vfmadd213ps zmm1, zmm6, zmm7
    vmaxps zmm1, zmm1, zmm5
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vfmadd213ps zmm2, zmm6, zmm7
    vmaxps zmm2, zmm2, zmm5
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vfmadd213ps zmm3, zmm6, zmm7
    vmaxps zmm3, zmm3, zmm5
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail1
    vmovups zmm0, [rax]
    vfmadd213ps zmm0, zmm6, zmm7
    vmaxps zmm0, zmm0, zmm5
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    jmp @tail16

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
// AVX-512 F32 Scalar/Affine Batch Operations (ZMM width)
// ============================================================================

procedure AVX512ArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var
  pS, pD: PSingle;
  LScalar: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LScalar := aScalar;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastss zmm7, [LScalar]

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vaddps zmm0, zmm0, zmm7
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vaddps zmm1, zmm1, zmm7
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vaddps zmm2, zmm2, zmm7
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vaddps zmm3, zmm3, zmm7
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vaddps zmm0, zmm0, zmm7
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

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

procedure AVX512ArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var
  pS, pD: PSingle;
  LScalar: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LScalar := aScalar;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastss zmm7, [LScalar]

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vmulps zmm0, zmm0, zmm7
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vmulps zmm1, zmm1, zmm7
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vmulps zmm2, zmm2, zmm7
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vmulps zmm3, zmm3, zmm7
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vmulps zmm0, zmm0, zmm7
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

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

procedure AVX512ArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
var
  pS, pD: PSingle;
  LMin, LMax: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  LMin := aMin; LMax := aMax;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastss zmm6, [LMin]
    vbroadcastss zmm7, [LMax]

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vmaxps zmm0, zmm0, zmm6
    vminps zmm0, zmm0, zmm7
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vmaxps zmm1, zmm1, zmm6
    vminps zmm1, zmm1, zmm7
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vmaxps zmm2, zmm2, zmm6
    vminps zmm2, zmm2, zmm7
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vmaxps zmm3, zmm3, zmm6
    vminps zmm3, zmm3, zmm7
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vmaxps zmm0, zmm0, zmm6
    vminps zmm0, zmm0, zmm7
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

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

procedure AVX512ArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
var
  pA, pB, pC, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pA := aA; pB := aB; pC := aC; pD := aDst;

  asm
    mov rax, pA
    mov rdx, pB
    mov r9, pC
    mov rcx, pD
    mov r8, aCount

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]
    vmovups zmm1, [rdx]
    vmovups zmm2, [r9]
    vfmadd213ps zmm0, zmm1, zmm2
    vmovups [rcx], zmm0
    add rax, 64
    add rdx, 64
    add r9, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vmovss xmm1, [rdx]
    vmovss xmm2, [r9]
    vfmadd213ss xmm0, xmm1, xmm2
    vmovss [rcx], xmm0
    add rax, 4
    add rdx, 4
    add r9, 4
    add rcx, 4
    dec r8
    jnz @scalar_loop

  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX512ArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
var
  pX, pY, pD: PSingle;
  LAlpha: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pX := aX; pY := aY; pD := aDst;
  LAlpha := aAlpha;

  asm
    mov rax, pX
    mov rdx, pY
    mov rcx, pD
    mov r8, aCount
    vbroadcastss zmm7, [LAlpha]

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rdx]
    vfmadd231ps zmm0, zmm7, [rax]
    vmovups [rcx], zmm0
    vmovups zmm1, [rdx + 64]
    vfmadd231ps zmm1, zmm7, [rax + 64]
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rdx + 128]
    vfmadd231ps zmm2, zmm7, [rax + 128]
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rdx + 192]
    vfmadd231ps zmm3, zmm7, [rax + 192]
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rdx, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rdx]
    vfmadd231ps zmm0, zmm7, [rax]
    vmovups [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rdx]
    vfmadd231ss xmm0, xmm7, [rax]
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
// AVX-512 F32 Reduction Operations (ZMM accumulators)
// ============================================================================

function AVX512ReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single;
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
    vpxord zmm0, zmm0, zmm0
    vpxord zmm1, zmm1, zmm1
    vpxord zmm2, zmm2, zmm2
    vpxord zmm3, zmm3, zmm3

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vaddps zmm0, zmm0, [rax]
    vaddps zmm1, zmm1, [rax + 64]
    vaddps zmm2, zmm2, [rax + 128]
    vaddps zmm3, zmm3, [rax + 192]
    add rax, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @reduce
    vaddps zmm0, zmm0, [rax]
    add rax, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

  @reduce:
    vaddps zmm0, zmm0, zmm1
    vaddps zmm2, zmm2, zmm3
    vaddps zmm0, zmm0, zmm2
    vextractf32x8 ymm1, zmm0, 1
    vaddps ymm0, ymm0, ymm1
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

function AVX512ReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
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
    vpxord zmm0, zmm0, zmm0
    vpxord zmm1, zmm1, zmm1
    vpxord zmm2, zmm2, zmm2
    vpxord zmm3, zmm3, zmm3

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm4, [rax]
    vfmadd231ps zmm0, zmm4, [rdx]
    vmovups zmm5, [rax + 64]
    vfmadd231ps zmm1, zmm5, [rdx + 64]
    vmovups zmm4, [rax + 128]
    vfmadd231ps zmm2, zmm4, [rdx + 128]
    vmovups zmm5, [rax + 192]
    vfmadd231ps zmm3, zmm5, [rdx + 192]
    add rax, 256
    add rdx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @reduce
    vmovups zmm4, [rax]
    vfmadd231ps zmm0, zmm4, [rdx]
    add rax, 64
    add rdx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

  @reduce:
    vaddps zmm0, zmm0, zmm1
    vaddps zmm2, zmm2, zmm3
    vaddps zmm0, zmm0, zmm2
    vextractf32x8 ymm1, zmm0, 1
    vaddps ymm0, ymm0, ymm1
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

function AVX512ReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  pS: PSingle;
  LResult: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc;

  asm
    mov rax, pS
    mov r8, aCount

    vbroadcastss zmm0, [rax]
    vmovaps zmm1, zmm0
    vmovaps zmm2, zmm0
    vmovaps zmm3, zmm0

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vminps zmm0, zmm0, [rax]
    vminps zmm1, zmm1, [rax + 64]
    vminps zmm2, zmm2, [rax + 128]
    vminps zmm3, zmm3, [rax + 192]
    add rax, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @reduce
    vminps zmm0, zmm0, [rax]
    add rax, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

  @reduce:
    vminps zmm0, zmm0, zmm1
    vminps zmm2, zmm2, zmm3
    vminps zmm0, zmm0, zmm2
    vextractf32x8 ymm1, zmm0, 1
    vminps ymm0, ymm0, ymm1
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

function AVX512ReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  pS: PSingle;
  LResult: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc;

  asm
    mov rax, pS
    mov r8, aCount

    vbroadcastss zmm0, [rax]
    vmovaps zmm1, zmm0
    vmovaps zmm2, zmm0
    vmovaps zmm3, zmm0

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmaxps zmm0, zmm0, [rax]
    vmaxps zmm1, zmm1, [rax + 64]
    vmaxps zmm2, zmm2, [rax + 128]
    vmaxps zmm3, zmm3, [rax + 192]
    add rax, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @reduce
    vmaxps zmm0, zmm0, [rax]
    add rax, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

  @reduce:
    vmaxps zmm0, zmm0, zmm1
    vmaxps zmm2, zmm2, zmm3
    vmaxps zmm0, zmm0, zmm2
    vextractf32x8 ymm1, zmm0, 1
    vmaxps ymm0, ymm0, ymm1
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
// AVX-512 F32 Min/Max Array Operations
// ============================================================================

procedure AVX512ArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
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

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vminps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vminps zmm1, zmm1, [rdx + 64]
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vminps zmm2, zmm2, [rdx + 128]
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vminps zmm3, zmm3, [rdx + 192]
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rdx, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vminps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

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

procedure AVX512ArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
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

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vmaxps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vmaxps zmm1, zmm1, [rdx + 64]
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vmaxps zmm2, zmm2, [rdx + 128]
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vmaxps zmm3, zmm3, [rdx + 192]
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rdx, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vmaxps zmm0, zmm0, [rdx]
    vmovups [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

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
// AVX-512 F64 Batch Array Operations (ZMM = 8 doubles/iter)
// ============================================================================

procedure AVX512ArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
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

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovupd zmm0, [rax]
    vaddpd zmm0, zmm0, [rdx]
    vmovupd [rcx], zmm0
    vmovupd zmm1, [rax + 64]
    vaddpd zmm1, zmm1, [rdx + 64]
    vmovupd [rcx + 64], zmm1
    vmovupd zmm2, [rax + 128]
    vaddpd zmm2, zmm2, [rdx + 128]
    vmovupd [rcx + 128], zmm2
    vmovupd zmm3, [rax + 192]
    vaddpd zmm3, zmm3, [rdx + 192]
    vmovupd [rcx + 192], zmm3
    add rax, 256
    add rdx, 256
    add rcx, 256
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovupd zmm0, [rax]
    vaddpd zmm0, zmm0, [rdx]
    vmovupd [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 8
    cmp r8, 8
    jae @tail8

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

procedure AVX512ArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
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

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovupd zmm0, [rax]
    vsubpd zmm0, zmm0, [rdx]
    vmovupd [rcx], zmm0
    vmovupd zmm1, [rax + 64]
    vsubpd zmm1, zmm1, [rdx + 64]
    vmovupd [rcx + 64], zmm1
    vmovupd zmm2, [rax + 128]
    vsubpd zmm2, zmm2, [rdx + 128]
    vmovupd [rcx + 128], zmm2
    vmovupd zmm3, [rax + 192]
    vsubpd zmm3, zmm3, [rdx + 192]
    vmovupd [rcx + 192], zmm3
    add rax, 256
    add rdx, 256
    add rcx, 256
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovupd zmm0, [rax]
    vsubpd zmm0, zmm0, [rdx]
    vmovupd [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 8
    cmp r8, 8
    jae @tail8

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

procedure AVX512ArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
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

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovupd zmm0, [rax]
    vmulpd zmm0, zmm0, [rdx]
    vmovupd [rcx], zmm0
    vmovupd zmm1, [rax + 64]
    vmulpd zmm1, zmm1, [rdx + 64]
    vmovupd [rcx + 64], zmm1
    vmovupd zmm2, [rax + 128]
    vmulpd zmm2, zmm2, [rdx + 128]
    vmovupd [rcx + 128], zmm2
    vmovupd zmm3, [rax + 192]
    vmulpd zmm3, zmm3, [rdx + 192]
    vmovupd [rcx + 192], zmm3
    add rax, 256
    add rdx, 256
    add rcx, 256
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovupd zmm0, [rax]
    vmulpd zmm0, zmm0, [rdx]
    vmovupd [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 8
    cmp r8, 8
    jae @tail8

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

procedure AVX512ArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
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

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovupd zmm0, [rax]
    vdivpd zmm0, zmm0, [rdx]
    vmovupd [rcx], zmm0
    vmovupd zmm1, [rax + 64]
    vdivpd zmm1, zmm1, [rdx + 64]
    vmovupd [rcx + 64], zmm1
    vmovupd zmm2, [rax + 128]
    vdivpd zmm2, zmm2, [rdx + 128]
    vmovupd [rcx + 128], zmm2
    vmovupd zmm3, [rax + 192]
    vdivpd zmm3, zmm3, [rdx + 192]
    vmovupd [rcx + 192], zmm3
    add rax, 256
    add rdx, 256
    add rcx, 256
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @tail_scalar
    vmovupd zmm0, [rax]
    vdivpd zmm0, zmm0, [rdx]
    vmovupd [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 8
    cmp r8, 8
    jae @tail8

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

procedure AVX512ArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);
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
    vpbroadcastq zmm7, xmm7

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovupd zmm0, [rax]
    vpandq zmm0, zmm0, zmm7
    vmovupd [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vpandq xmm0, xmm0, xmm7
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

procedure AVX512ArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt);
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
    vpbroadcastq zmm7, xmm7

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovupd zmm0, [rax]
    vpxorq zmm0, zmm0, zmm7
    vmovupd [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 8
    cmp r8, 8
    jae @loop8

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovsd xmm0, [rax]
    vpxorq xmm0, xmm0, xmm7
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

procedure AVX512ArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
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

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovupd zmm0, [rax]
    vsqrtpd zmm0, zmm0
    vmovupd [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 8
    cmp r8, 8
    jae @loop8

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
// AVX-512 F64 Reduction Operations (ZMM accumulators)
// ============================================================================

function AVX512ReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double;
var
  pS: PDouble;
  LSum: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc;
  LSum := 0;

  asm
    mov rax, pS
    mov r8, aCount
    vpxorq zmm0, zmm0, zmm0
    vpxorq zmm1, zmm1, zmm1
    vpxorq zmm2, zmm2, zmm2
    vpxorq zmm3, zmm3, zmm3

    cmp r8, 32
    jb @tail8

  @loop32:
    vaddpd zmm0, zmm0, [rax]
    vaddpd zmm1, zmm1, [rax + 64]
    vaddpd zmm2, zmm2, [rax + 128]
    vaddpd zmm3, zmm3, [rax + 192]
    add rax, 256
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @reduce
    vaddpd zmm0, zmm0, [rax]
    add rax, 64
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @reduce:
    vaddpd zmm0, zmm0, zmm1
    vaddpd zmm2, zmm2, zmm3
    vaddpd zmm0, zmm0, zmm2
    vextractf64x4 ymm1, zmm0, 1
    vaddpd ymm0, ymm0, ymm1
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

function AVX512ReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
var
  pS1, pS2: PDouble;
  LSum: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS1 := aSrc1; pS2 := aSrc2;
  LSum := 0;

  asm
    mov rax, pS1
    mov rdx, pS2
    mov r8, aCount
    vpxorq zmm0, zmm0, zmm0
    vpxorq zmm1, zmm1, zmm1
    vpxorq zmm2, zmm2, zmm2
    vpxorq zmm3, zmm3, zmm3

    cmp r8, 32
    jb @tail8

  @loop32:
    vmovupd zmm4, [rax]
    vfmadd231pd zmm0, zmm4, [rdx]
    vmovupd zmm5, [rax + 64]
    vfmadd231pd zmm1, zmm5, [rdx + 64]
    vmovupd zmm4, [rax + 128]
    vfmadd231pd zmm2, zmm4, [rdx + 128]
    vmovupd zmm5, [rax + 192]
    vfmadd231pd zmm3, zmm5, [rdx + 192]
    add rax, 256
    add rdx, 256
    sub r8, 32
    cmp r8, 32
    jae @loop32

  @tail8:
    cmp r8, 8
    jb @reduce
    vmovupd zmm4, [rax]
    vfmadd231pd zmm0, zmm4, [rdx]
    add rax, 64
    add rdx, 64
    sub r8, 8
    cmp r8, 8
    jae @tail8

  @reduce:
    vaddpd zmm0, zmm0, zmm1
    vaddpd zmm2, zmm2, zmm3
    vaddpd zmm0, zmm0, zmm2
    vextractf64x4 ymm1, zmm0, 1
    vaddpd ymm0, ymm0, ymm1
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

function AVX512ReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double;
var
  pS: PDouble;
  LResult: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc;

  asm
    mov rax, pS
    mov r8, aCount

    vbroadcastsd zmm0, [rax]
    vmovapd zmm1, zmm0

    cmp r8, 16
    jb @tail8

  @loop16:
    vminpd zmm0, zmm0, [rax]
    vminpd zmm1, zmm1, [rax + 64]
    add rax, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @reduce
    vminpd zmm0, zmm0, [rax]
    add rax, 64
    sub r8, 8

  @reduce:
    vminpd zmm0, zmm0, zmm1
    vextractf64x4 ymm1, zmm0, 1
    vminpd ymm0, ymm0, ymm1
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

function AVX512ReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;
var
  pS: PDouble;
  LResult: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then begin Result := 0; Exit; end;
  pS := aSrc;

  asm
    mov rax, pS
    mov r8, aCount

    vbroadcastsd zmm0, [rax]
    vmovapd zmm1, zmm0

    cmp r8, 16
    jb @tail8

  @loop16:
    vmaxpd zmm0, zmm0, [rax]
    vmaxpd zmm1, zmm1, [rax + 64]
    add rax, 128
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail8:
    cmp r8, 8
    jb @reduce
    vmaxpd zmm0, zmm0, [rax]
    add rax, 64
    sub r8, 8

  @reduce:
    vmaxpd zmm0, zmm0, zmm1
    vextractf64x4 ymm1, zmm0, 1
    vmaxpd ymm0, ymm0, ymm1
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
// AVX-512 F64 Scalar/Affine Operations (ZMM = 8 doubles broadcast)
// ============================================================================

procedure AVX512ArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var pS, pD: PDouble; LScalar: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScalar := aScalar;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastsd zmm7, [LScalar]
    cmp r8, 8
    jb @tail_scalar
  @loop8:
    vmovupd zmm0, [rax]
    vmulpd zmm0, zmm0, zmm7
    vmovupd [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 8
    cmp r8, 8
    jae @loop8
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

procedure AVX512ArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var pS, pD: PDouble; LScalar: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScalar := aScalar;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastsd zmm7, [LScalar]
    cmp r8, 8
    jb @tail_scalar
  @loop8:
    vmovupd zmm0, [rax]
    vaddpd zmm0, zmm0, zmm7
    vmovupd [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 8
    cmp r8, 8
    jae @loop8
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

procedure AVX512ArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
var pS, pD: PDouble; LMin, LMax: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LMin := aMin; LMax := aMax;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastsd zmm6, [LMin]
    vbroadcastsd zmm7, [LMax]
    cmp r8, 8
    jb @tail_scalar
  @loop8:
    vmovupd zmm0, [rax]
    vmaxpd zmm0, zmm0, zmm6
    vminpd zmm0, zmm0, zmm7
    vmovupd [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 8
    cmp r8, 8
    jae @loop8
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

procedure AVX512ArrayLinearF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
var pS, pD: PDouble; LScale, LBias: Double;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst; LScale := aScale; LBias := aBias;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount
    vbroadcastsd zmm6, [LScale]
    vbroadcastsd zmm7, [LBias]

    cmp r8, 8
    jb @tail_scalar

  @loop8:
    vmovupd zmm0, [rax]
    vfmadd213pd zmm0, zmm6, zmm7
    vmovupd [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 8
    cmp r8, 8
    jae @loop8

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

// ============================================================================
// AVX-512 ArrayRcpF32 — vrcp14ps (14-bit precision, no NR needed for most uses)
// ============================================================================

procedure AVX512ArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vrcp14ps zmm0, zmm0
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vrcp14ps zmm1, zmm1
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vrcp14ps zmm2, zmm2
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vrcp14ps zmm3, zmm3
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vrcp14ps zmm0, zmm0
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vrcp14ss xmm0, xmm0, xmm0
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
// AVX-512 ArrayRsqrtF32 — vrsqrt14ps (14-bit precision)
// ============================================================================

procedure AVX512ArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    cmp r8, 64
    jb @tail16

  @loop64:
    prefetcht0 [rax + 256]
    vmovups zmm0, [rax]
    vrsqrt14ps zmm0, zmm0
    vmovups [rcx], zmm0
    vmovups zmm1, [rax + 64]
    vrsqrt14ps zmm1, zmm1
    vmovups [rcx + 64], zmm1
    vmovups zmm2, [rax + 128]
    vrsqrt14ps zmm2, zmm2
    vmovups [rcx + 128], zmm2
    vmovups zmm3, [rax + 192]
    vrsqrt14ps zmm3, zmm3
    vmovups [rcx + 192], zmm3
    add rax, 256
    add rcx, 256
    sub r8, 64
    cmp r8, 64
    jae @loop64

  @tail16:
    cmp r8, 16
    jb @tail_scalar
    vmovups zmm0, [rax]
    vrsqrt14ps zmm0, zmm0
    vmovups [rcx], zmm0
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @tail16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vrsqrt14ss xmm0, xmm0, xmm0
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
// AVX-512 ArrayRcpRefineF32 — vrcp14ps + Newton-Raphson (~23-bit full precision)
// ============================================================================

procedure AVX512ArrayRcpRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
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
    vmovd xmm7, r9d
    vpbroadcastd zmm7, xmm7   // 2.0

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]
    vrcp14ps zmm1, zmm0
    vmulps zmm2, zmm0, zmm1
    vsubps zmm2, zmm7, zmm2
    vmulps zmm1, zmm1, zmm2
    vmovups [rcx], zmm1
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vrcp14ss xmm1, xmm0, xmm0
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
// AVX-512 ArrayRsqrtRefineF32 — vrsqrt14ps + Newton-Raphson (~23-bit)
// ============================================================================

procedure AVX512ArrayRsqrtRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var pS, pD: PSingle;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pS := aSrc; pD := aDst;
  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aCount

    mov r9d, $3F000000
    vmovd xmm6, r9d
    vpbroadcastd zmm6, xmm6   // 0.5
    mov r9d, $40400000
    vmovd xmm7, r9d
    vpbroadcastd zmm7, xmm7   // 3.0

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    vmovups zmm0, [rax]
    vrsqrt14ps zmm1, zmm0
    vmulps zmm2, zmm1, zmm1
    vmulps zmm2, zmm0, zmm2
    vsubps zmm2, zmm7, zmm2
    vmulps zmm1, zmm1, zmm2
    vmulps zmm1, zmm1, zmm6
    vmovups [rcx], zmm1
    add rax, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    vmovss xmm0, [rax]
    vrsqrt14ss xmm1, xmm0, xmm0
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
// AVX-512 ArrayPowF32 — exp(exponent * log(src)), ZMM width
// ============================================================================

procedure AVX512ArrayPowF32(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
var pD: PSingle; LExp: Single;
begin
  {$PUSH}{$Q-}{$R-}
  if aCount = 0 then Exit;
  pD := aDst; LExp := aExponent;

  AVX512ArrayLogF32(aSrc, aDst, aCount);

  asm
    mov rax, pD
    mov r8, aCount
    vbroadcastss zmm15, [LExp]

    cmp r8, 16
    jb @tail

  @loop16:
    vmovups zmm0, [rax]
    vmulps zmm0, zmm0, zmm15
    vmovups [rax], zmm0
    add rax, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

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

  AVX512ArrayExpF32(pD, pD, aCount);
  {$POP}
end;

// === AVX-512 Integer Batch Operations ===

procedure AVX512ArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var
  pA, pB, pC: PInt32;
  n: SizeUInt;
begin
  pA := aSrc1; pB := aSrc2; pC := aDst; n := aCount;
  {$PUSH}{$ASMMODE INTEL}
  asm
    mov rax, pA
    mov rdx, pB
    mov rcx, pC
    mov r8, n

    cmp r8, 16
    jb @tail

  @loop16:
    vmovdqu32 zmm0, [rax]
    vpaddd zmm0, zmm0, [rdx]
    vmovdqu32 [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail:
    test r8, r8
    jz @done
  @scalar:
    mov r9d, [rax]
    add r9d, [rdx]
    mov [rcx], r9d
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar
  @done:
    vzeroupper
  end;
  {$POP}
end;

procedure AVX512ArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var
  pA, pB, pC: PInt32;
  n: SizeUInt;
begin
  pA := aSrc1; pB := aSrc2; pC := aDst; n := aCount;
  {$PUSH}{$ASMMODE INTEL}
  asm
    mov rax, pA
    mov rdx, pB
    mov rcx, pC
    mov r8, n

    cmp r8, 16
    jb @tail

  @loop16:
    vmovdqu32 zmm0, [rax]
    vpsubd zmm0, zmm0, [rdx]
    vmovdqu32 [rcx], zmm0
    add rax, 64
    add rdx, 64
    add rcx, 64
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail:
    test r8, r8
    jz @done
  @scalar:
    mov r9d, [rax]
    sub r9d, [rdx]
    mov [rcx], r9d
    add rax, 4
    add rdx, 4
    add rcx, 4
    dec r8
    jnz @scalar
  @done:
    vzeroupper
  end;
  {$POP}
end;
