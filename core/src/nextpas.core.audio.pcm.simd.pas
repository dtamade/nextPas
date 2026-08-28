unit nextpas.core.audio.pcm.simd;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.base;

{ 4-wide / 8-wide inline helpers — 直连 intrinsics，可在热循环中内联展开
  避免 nextpas.core.simd 派发表的间接调用（LoadSimdFacadeFastPath + 函数指针）
  编译期通过 CPU 宏选择实现，运行期零分支
  Linux x86_64 下以单次汇编内核实现（1 CALL / 4 样本），避免 7 次 intrinsics CALL 开销 }

{ Int32[4] -> F32[4] : V * scale + clamp [-1,1]，写 4 个 Single }
procedure PcmConvertI32x4ToF32Clamped(AIn: PLongInt; AScale: Single; AOut: PSingle); inline;

{ SmallInt[4] -> F32[4] : 同上，含符号扩展 }
procedure PcmConvertS16x4ToF32(AIn: PSmallInt; AScale: Single; AOut: PSingle); inline;

{ Stereo 交错：L[4],R[4] -> F32[8] = L0,R0,L1,R1,L2,R2,L3,R3，每声道 *scale+clamp }
procedure PcmConvertI32x4StereoToF32Interleaved(AInL, AInR: PLongInt; AScale: Single; AOut: PSingle); inline;
procedure PcmConvertS16x4StereoToF32Interleaved(AInL, AInR: PSmallInt; AScale: Single; AOut: PSingle); inline;

{ 块级 1 CALL / N 样本：对标 music888 的标量每采样循环，消除 1024 次 CALL 开销 }
procedure PcmConvertI32BlockToF32Clamped(AIn: PLongInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
procedure PcmConvertS16BlockToF32(AIn: PSmallInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
procedure PcmConvertI32BlockStereoToF32Interleaved(AInL, AInR: PLongInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
procedure PcmConvertS16BlockStereoToF32Interleaved(AInL, AInR: PSmallInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;

implementation

{$IFDEF CPUX86_64}

  {$IFDEF LINUX}
  // Linux System V: 整数指针 rdi/rsi/rdx，浮点标量 xmm0
  // 单核融合：1 CALL 完成 load→cvt→broadcast→mul→clamp→store，避免 7 次 CALL
  const
    VEC_ONE: array[0..3] of Single = (1.0, 1.0, 1.0, 1.0);
    VEC_NEGONE: array[0..3] of Single = (-1.0, -1.0, -1.0, -1.0);

  procedure PcmConvertI32x4ToF32Clamped(AIn: PLongInt; AScale: Single; AOut: PSingle); assembler; nostackframe;
  asm
    movdqu xmm1, [rdi]
    cvtdq2ps xmm1, xmm1
    shufps xmm0, xmm0, 0
    mulps xmm1, xmm0
    movaps xmm2, [rip + VEC_ONE]
    minps xmm1, xmm2
    movaps xmm2, [rip + VEC_NEGONE]
    maxps xmm1, xmm2
    movups [rsi], xmm1
  end;

  procedure PcmConvertS16x4ToF32(AIn: PSmallInt; AScale: Single; AOut: PSingle); assembler; nostackframe;
  asm
    movq xmm1, [rdi]
    movdqa xmm2, xmm1
    psraw xmm2, 15
    punpcklwd xmm1, xmm2
    cvtdq2ps xmm1, xmm1
    shufps xmm0, xmm0, 0
    mulps xmm1, xmm0
    movups [rsi], xmm1
  end;

  procedure PcmConvertI32x4StereoToF32Interleaved(AInL, AInR: PLongInt; AScale: Single; AOut: PSingle); assembler; nostackframe;
  asm
    // rdi=L, rsi=R, xmm0=scale, rdx=out
    movdqu xmm1, [rdi]
    movdqu xmm2, [rsi]
    cvtdq2ps xmm1, xmm1
    cvtdq2ps xmm2, xmm2
    shufps xmm0, xmm0, 0
    mulps xmm1, xmm0
    mulps xmm2, xmm0
    movaps xmm3, [rip + VEC_ONE]
    minps xmm1, xmm3
    minps xmm2, xmm3
    movaps xmm3, [rip + VEC_NEGONE]
    maxps xmm1, xmm3
    maxps xmm2, xmm3
    movaps xmm3, xmm1
    unpcklps xmm1, xmm2
    unpckhps xmm3, xmm2
    movups [rdx], xmm1
    movups [rdx + 16], xmm3
  end;

  procedure PcmConvertS16x4StereoToF32Interleaved(AInL, AInR: PSmallInt; AScale: Single; AOut: PSingle); assembler; nostackframe;
  asm
    // rdi=L, rsi=R, xmm0=scale, rdx=out
    movq xmm1, [rdi]
    movq xmm2, [rsi]
    movdqa xmm3, xmm1
    movdqa xmm4, xmm2
    psraw xmm3, 15
    psraw xmm4, 15
    punpcklwd xmm1, xmm3
    punpcklwd xmm2, xmm4
    cvtdq2ps xmm1, xmm1
    cvtdq2ps xmm2, xmm2
    shufps xmm0, xmm0, 0
    mulps xmm1, xmm0
    mulps xmm2, xmm0
    movaps xmm3, xmm1
    unpcklps xmm1, xmm2
    unpckhps xmm3, xmm2
    movups [rdx], xmm1
    movups [rdx + 16], xmm3
  end;

  procedure PcmConvertI32BlockToF32Clamped(AIn: PLongInt; AScale: Single; AOut: PSingle; AN: LongWord); assembler; nostackframe;
  asm
    test edx, edx
    jz @@Li32b_done
    shufps xmm0, xmm0, 0
    movaps xmm2, [rip + VEC_ONE]
    movaps xmm3, [rip + VEC_NEGONE]
    mov ecx, edx
    shr ecx, 2
    jz @@Li32b_tail
  @@Li32b_loop:
    movdqu xmm1, [rdi]
    cvtdq2ps xmm1, xmm1
    mulps xmm1, xmm0
    minps xmm1, xmm2
    maxps xmm1, xmm3
    movups [rsi], xmm1
    add rdi, 16
    add rsi, 16
    dec ecx
    jnz @@Li32b_loop
  @@Li32b_tail:
    and edx, 3
    jz @@Li32b_done
  @@Li32b_tail_loop:
    mov eax, [rdi]
    cvtsi2ss xmm1, eax
    mulss xmm1, xmm0
    minss xmm1, xmm2
    maxss xmm1, xmm3
    movss [rsi], xmm1
    add rdi, 4
    add rsi, 4
    dec edx
    jnz @@Li32b_tail_loop
  @@Li32b_done:
  end;

  procedure PcmConvertS16BlockToF32(AIn: PSmallInt; AScale: Single; AOut: PSingle; AN: LongWord); assembler; nostackframe;
  asm
    test edx, edx
    jz @@Ls16b_done
    shufps xmm0, xmm0, 0
    mov ecx, edx
    shr ecx, 2
    jz @@Ls16b_tail
  @@Ls16b_loop:
    movq xmm1, [rdi]
    movdqa xmm2, xmm1
    psraw xmm2, 15
    punpcklwd xmm1, xmm2
    cvtdq2ps xmm1, xmm1
    mulps xmm1, xmm0
    movups [rsi], xmm1
    add rdi, 8
    add rsi, 16
    dec ecx
    jnz @@Ls16b_loop
  @@Ls16b_tail:
    and edx, 3
    jz @@Ls16b_done
  @@Ls16b_tail_loop:
    movsx eax, word [rdi]
    cvtsi2ss xmm1, eax
    mulss xmm1, xmm0
    movss [rsi], xmm1
    add rdi, 2
    add rsi, 4
    dec edx
    jnz @@Ls16b_tail_loop
  @@Ls16b_done:
  end;

  procedure PcmConvertI32BlockStereoToF32Interleaved(AInL, AInR: PLongInt; AScale: Single; AOut: PSingle; AN: LongWord); assembler; nostackframe;
  asm
    or ecx, ecx
    jz @@Li32s_done
    shufps xmm0, xmm0, 0
    movaps xmm4, [rip + VEC_ONE]
    movaps xmm5, [rip + VEC_NEGONE]
    mov eax, ecx
    shr eax, 2
    jz @@Li32s_tail
  @@Li32s_loop:
    movdqu xmm1, [rdi]
    movdqu xmm2, [rsi]
    cvtdq2ps xmm1, xmm1
    cvtdq2ps xmm2, xmm2
    mulps xmm1, xmm0
    mulps xmm2, xmm0
    minps xmm1, xmm4
    minps xmm2, xmm4
    maxps xmm1, xmm5
    maxps xmm2, xmm5
    movaps xmm3, xmm1
    unpcklps xmm1, xmm2
    unpckhps xmm3, xmm2
    movups [rdx], xmm1
    movups [rdx + 16], xmm3
    add rdi, 16
    add rsi, 16
    add rdx, 32
    dec eax
    jnz @@Li32s_loop
  @@Li32s_tail:
    and ecx, 3
    jz @@Li32s_done
  @@Li32s_tail_loop:
    mov eax, [rdi]
    cvtsi2ss xmm1, eax
    mulss xmm1, xmm0
    minss xmm1, xmm4
    maxss xmm1, xmm5
    movss [rdx], xmm1
    mov eax, [rsi]
    cvtsi2ss xmm1, eax
    mulss xmm1, xmm0
    minss xmm1, xmm4
    maxss xmm1, xmm5
    movss [rdx + 4], xmm1
    add rdi, 4
    add rsi, 4
    add rdx, 8
    dec ecx
    jnz @@Li32s_tail_loop
  @@Li32s_done:
  end;

  procedure PcmConvertS16BlockStereoToF32Interleaved(AInL, AInR: PSmallInt; AScale: Single; AOut: PSingle; AN: LongWord); assembler; nostackframe;
  asm
    or ecx, ecx
    jz @@Ls16s_done
    shufps xmm0, xmm0, 0
    mov eax, ecx
    shr eax, 2
    jz @@Ls16s_tail
  @@Ls16s_loop:
    movq xmm1, [rdi]
    movq xmm2, [rsi]
    movdqa xmm3, xmm1
    movdqa xmm4, xmm2
    psraw xmm3, 15
    psraw xmm4, 15
    punpcklwd xmm1, xmm3
    punpcklwd xmm2, xmm4
    cvtdq2ps xmm1, xmm1
    cvtdq2ps xmm2, xmm2
    mulps xmm1, xmm0
    mulps xmm2, xmm0
    movaps xmm3, xmm1
    unpcklps xmm1, xmm2
    unpckhps xmm3, xmm2
    movups [rdx], xmm1
    movups [rdx + 16], xmm3
    add rdi, 8
    add rsi, 8
    add rdx, 32
    dec eax
    jnz @@Ls16s_loop
  @@Ls16s_tail:
    and ecx, 3
    jz @@Ls16s_done
  @@Ls16s_tail_loop:
    movsx eax, word [rdi]
    cvtsi2ss xmm1, eax
    mulss xmm1, xmm0
    movss [rdx], xmm1
    movsx eax, word [rsi]
    cvtsi2ss xmm1, eax
    mulss xmm1, xmm0
    movss [rdx + 4], xmm1
    add rdi, 2
    add rsi, 2
    add rdx, 8
    dec ecx
    jnz @@Ls16s_tail_loop
  @@Ls16s_done:
  end;

  {$ELSE}
  // Windows / 非 Linux：回落为 Pascal 直连 intrinsics（仍避免派发表）
  uses
    nextpas.core.simd.intrinsics.sse2,
    nextpas.core.simd.intrinsics.base;

  procedure PcmConvertI32x4ToF32Clamped(AIn: PLongInt; AScale: Single; AOut: PSingle); inline;
  var Vi, Vf, Scale, One, NegOne: TM128;
  begin
    Vi := simd_loadu_si128(AIn);
    Vf := simd_cvtepi32_ps(Vi);
    Scale := simd_set1_ps(AScale);
    Vf := simd_mul_ps(Vf, Scale);
    One := simd_set1_ps(1.0);
    NegOne := simd_set1_ps(-1.0);
    Vf := simd_min_ps(Vf, One);
    Vf := simd_max_ps(Vf, NegOne);
    simd_storeu_ps(AOut^, Vf);
  end;

  procedure PcmConvertS16x4ToF32(AIn: PSmallInt; AScale: Single; AOut: PSingle); inline;
  var Vi, Sign, Lo: TM128; Vf, Scale: TM128;
  begin
    Vi := simd_loadl_epi64(AIn);
    Sign := simd_srai_epi16(Vi, 15);
    Lo := simd_unpacklo_epi16(Vi, Sign);
    Vf := simd_cvtepi32_ps(Lo);
    Scale := simd_set1_ps(AScale);
    Vf := simd_mul_ps(Vf, Scale);
    simd_storeu_ps(AOut^, Vf);
  end;

  procedure PcmConvertI32x4StereoToF32Interleaved(AInL, AInR: PLongInt; AScale: Single; AOut: PSingle); inline;
  var ViL, ViR, VfL, VfR, Scale, One, NegOne, OutLo, OutHi: TM128;
  begin
    ViL := simd_loadu_si128(AInL);
    ViR := simd_loadu_si128(AInR);
    VfL := simd_cvtepi32_ps(ViL);
    VfR := simd_cvtepi32_ps(ViR);
    Scale := simd_set1_ps(AScale);
    VfL := simd_mul_ps(VfL, Scale);
    VfR := simd_mul_ps(VfR, Scale);
    One := simd_set1_ps(1.0);
    NegOne := simd_set1_ps(-1.0);
    VfL := simd_min_ps(VfL, One); VfL := simd_max_ps(VfL, NegOne);
    VfR := simd_min_ps(VfR, One); VfR := simd_max_ps(VfR, NegOne);
    OutLo := simd_unpacklo_ps(VfL, VfR);
    OutHi := simd_unpackhi_ps(VfL, VfR);
    simd_storeu_ps(AOut^, OutLo);
    simd_storeu_ps(Pointer(PtrUInt(AOut) + 16)^, OutHi);
  end;

  procedure PcmConvertS16x4StereoToF32Interleaved(AInL, AInR: PSmallInt; AScale: Single; AOut: PSingle); inline;
  var ViL, ViR, SignL, SignR, LoL, LoR, VfL, VfR, Scale, OutLo, OutHi: TM128;
  begin
    ViL := simd_loadl_epi64(AInL); ViR := simd_loadl_epi64(AInR);
    SignL := simd_srai_epi16(ViL, 15); SignR := simd_srai_epi16(ViR, 15);
    LoL := simd_unpacklo_epi16(ViL, SignL); LoR := simd_unpacklo_epi16(ViR, SignR);
    VfL := simd_cvtepi32_ps(LoL); VfR := simd_cvtepi32_ps(LoR);
    Scale := simd_set1_ps(AScale);
    VfL := simd_mul_ps(VfL, Scale); VfR := simd_mul_ps(VfR, Scale);
    OutLo := simd_unpacklo_ps(VfL, VfR); OutHi := simd_unpackhi_ps(VfL, VfR);
    simd_storeu_ps(AOut^, OutLo);
    simd_storeu_ps(Pointer(PtrUInt(AOut) + 16)^, OutHi);
  end;

  procedure PcmConvertI32BlockToF32Clamped(AIn: PLongInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
  var I: LongWord;
  begin
    I := 0;
    while I + 3 < AN do
    begin
      PcmConvertI32x4ToF32Clamped(PLongInt(PtrUInt(AIn) + I*4), AScale, PSingle(PtrUInt(AOut) + I*4));
      Inc(I, 4);
    end;
    while I < AN do
    begin
      PSingle(PtrUInt(AOut) + I*4)^ := PLongInt(PtrUInt(AIn) + I*4)^ * AScale;
      if PSingle(PtrUInt(AOut) + I*4)^ > 1.0 then PSingle(PtrUInt(AOut) + I*4)^ := 1.0 else if PSingle(PtrUInt(AOut) + I*4)^ < -1.0 then PSingle(PtrUInt(AOut) + I*4)^ := -1.0;
      Inc(I);
    end;
  end;

  procedure PcmConvertS16BlockToF32(AIn: PSmallInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
  var I: LongWord;
  begin
    I := 0;
    while I + 3 < AN do
    begin
      PcmConvertS16x4ToF32(PSmallInt(PtrUInt(AIn) + I*2), AScale, PSingle(PtrUInt(AOut) + I*4));
      Inc(I, 4);
    end;
    while I < AN do
    begin
      PSingle(PtrUInt(AOut) + I*4)^ := SmallInt(PSmallInt(PtrUInt(AIn) + I*2)^) * AScale;
      Inc(I);
    end;
  end;

  procedure PcmConvertI32BlockStereoToF32Interleaved(AInL, AInR: PLongInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
  var I: LongWord;
  begin
    I := 0;
    while I + 3 < AN do
    begin
      PcmConvertI32x4StereoToF32Interleaved(PLongInt(PtrUInt(AInL) + I*4), PLongInt(PtrUInt(AInR) + I*4), AScale, PSingle(PtrUInt(AOut) + I*8));
      Inc(I, 4);
    end;
    while I < AN do
    begin
      PSingle(PtrUInt(AOut) + (I*2)*4)^ := PLongInt(PtrUInt(AInL) + I*4)^ * AScale;
      PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := PLongInt(PtrUInt(AInR) + I*4)^ * AScale;
      if PSingle(PtrUInt(AOut) + (I*2)*4)^ > 1.0 then PSingle(PtrUInt(AOut) + (I*2)*4)^ := 1.0 else if PSingle(PtrUInt(AOut) + (I*2)*4)^ < -1.0 then PSingle(PtrUInt(AOut) + (I*2)*4)^ := -1.0;
      if PSingle(PtrUInt(AOut) + (I*2+1)*4)^ > 1.0 then PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := 1.0 else if PSingle(PtrUInt(AOut) + (I*2+1)*4)^ < -1.0 then PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := -1.0;
      Inc(I);
    end;
  end;

  procedure PcmConvertS16BlockStereoToF32Interleaved(AInL, AInR: PSmallInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
  var I: LongWord;
  begin
    I := 0;
    while I + 3 < AN do
    begin
      PcmConvertS16x4StereoToF32Interleaved(PSmallInt(PtrUInt(AInL) + I*2), PSmallInt(PtrUInt(AInR) + I*2), AScale, PSingle(PtrUInt(AOut) + I*8));
      Inc(I, 4);
    end;
    while I < AN do
    begin
      PSingle(PtrUInt(AOut) + (I*2)*4)^ := SmallInt(PSmallInt(PtrUInt(AInL) + I*2)^) * AScale;
      PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := SmallInt(PSmallInt(PtrUInt(AInR) + I*2)^) * AScale;
      Inc(I);
    end;
  end;
  {$ENDIF}

{$ELSEIF DEFINED(CPUAARCH64)}
uses
  nextpas.core.simd.intrinsics.neon;

procedure PcmConvertI32x4ToF32Clamped(AIn: PLongInt; AScale: Single; AOut: PSingle); inline;
begin
  AOut[0] := AIn[0] * AScale; if AOut[0] > 1.0 then AOut[0] := 1.0 else if AOut[0] < -1.0 then AOut[0] := -1.0;
  AOut[1] := AIn[1] * AScale; if AOut[1] > 1.0 then AOut[1] := 1.0 else if AOut[1] < -1.0 then AOut[1] := -1.0;
  AOut[2] := AIn[2] * AScale; if AOut[2] > 1.0 then AOut[2] := 1.0 else if AOut[2] < -1.0 then AOut[2] := -1.0;
  AOut[3] := AIn[3] * AScale; if AOut[3] > 1.0 then AOut[3] := 1.0 else if AOut[3] < -1.0 then AOut[3] := -1.0;
end;

procedure PcmConvertS16x4ToF32(AIn: PSmallInt; AScale: Single; AOut: PSingle); inline;
begin
  AOut[0] := SmallInt(AIn[0]) * AScale; if AOut[0] > 1.0 then AOut[0] := 1.0 else if AOut[0] < -1.0 then AOut[0] := -1.0;
  AOut[1] := SmallInt(AIn[1]) * AScale; if AOut[1] > 1.0 then AOut[1] := 1.0 else if AOut[1] < -1.0 then AOut[1] := -1.0;
  AOut[2] := SmallInt(AIn[2]) * AScale; if AOut[2] > 1.0 then AOut[2] := 1.0 else if AOut[2] < -1.0 then AOut[2] := -1.0;
  AOut[3] := SmallInt(AIn[3]) * AScale; if AOut[3] > 1.0 then AOut[3] := 1.0 else if AOut[3] < -1.0 then AOut[3] := -1.0;
end;

procedure PcmConvertI32x4StereoToF32Interleaved(AInL, AInR: PLongInt; AScale: Single; AOut: PSingle); inline;
begin
  AOut[0] := AInL[0] * AScale; if AOut[0] > 1.0 then AOut[0] := 1.0 else if AOut[0] < -1.0 then AOut[0] := -1.0;
  AOut[1] := AInR[0] * AScale; if AOut[1] > 1.0 then AOut[1] := 1.0 else if AOut[1] < -1.0 then AOut[1] := -1.0;
  AOut[2] := AInL[1] * AScale; if AOut[2] > 1.0 then AOut[2] := 1.0 else if AOut[2] < -1.0 then AOut[2] := -1.0;
  AOut[3] := AInR[1] * AScale; if AOut[3] > 1.0 then AOut[3] := 1.0 else if AOut[3] < -1.0 then AOut[3] := -1.0;
  AOut[4] := AInL[2] * AScale; if AOut[4] > 1.0 then AOut[4] := 1.0 else if AOut[4] < -1.0 then AOut[4] := -1.0;
  AOut[5] := AInR[2] * AScale; if AOut[5] > 1.0 then AOut[5] := 1.0 else if AOut[5] < -1.0 then AOut[5] := -1.0;
  AOut[6] := AInL[3] * AScale; if AOut[6] > 1.0 then AOut[6] := 1.0 else if AOut[6] < -1.0 then AOut[6] := -1.0;
  AOut[7] := AInR[3] * AScale; if AOut[7] > 1.0 then AOut[7] := 1.0 else if AOut[7] < -1.0 then AOut[7] := -1.0;
end;

procedure PcmConvertS16x4StereoToF32Interleaved(AInL, AInR: PSmallInt; AScale: Single; AOut: PSingle); inline;
begin
  AOut[0] := SmallInt(AInL[0]) * AScale; if AOut[0] > 1.0 then AOut[0] := 1.0 else if AOut[0] < -1.0 then AOut[0] := -1.0;
  AOut[1] := SmallInt(AInR[0]) * AScale; if AOut[1] > 1.0 then AOut[1] := 1.0 else if AOut[1] < -1.0 then AOut[1] := -1.0;
  AOut[2] := SmallInt(AInL[1]) * AScale; if AOut[2] > 1.0 then AOut[2] := 1.0 else if AOut[2] < -1.0 then AOut[2] := -1.0;
  AOut[3] := SmallInt(AInR[1]) * AScale; if AOut[3] > 1.0 then AOut[3] := 1.0 else if AOut[3] < -1.0 then AOut[3] := -1.0;
  AOut[4] := SmallInt(AInL[2]) * AScale; if AOut[4] > 1.0 then AOut[4] := 1.0 else if AOut[4] < -1.0 then AOut[4] := -1.0;
  AOut[5] := SmallInt(AInR[2]) * AScale; if AOut[5] > 1.0 then AOut[5] := 1.0 else if AOut[5] < -1.0 then AOut[5] := -1.0;
  AOut[6] := SmallInt(AInL[3]) * AScale; if AOut[6] > 1.0 then AOut[6] := 1.0 else if AOut[6] < -1.0 then AOut[6] := -1.0;
  AOut[7] := SmallInt(AInR[3]) * AScale; if AOut[7] > 1.0 then AOut[7] := 1.0 else if AOut[7] < -1.0 then AOut[7] := -1.0;
end;

procedure PcmConvertI32BlockToF32Clamped(AIn: PLongInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
var I: LongWord;
begin
  I := 0;
  while I + 3 < AN do
  begin
    PcmConvertI32x4ToF32Clamped(PLongInt(PtrUInt(AIn) + I*4), AScale, PSingle(PtrUInt(AOut) + I*4));
    Inc(I, 4);
  end;
  while I < AN do
  begin
    PSingle(PtrUInt(AOut) + I*4)^ := PLongInt(PtrUInt(AIn) + I*4)^ * AScale;
    if PSingle(PtrUInt(AOut) + I*4)^ > 1.0 then PSingle(PtrUInt(AOut) + I*4)^ := 1.0 else if PSingle(PtrUInt(AOut) + I*4)^ < -1.0 then PSingle(PtrUInt(AOut) + I*4)^ := -1.0;
    Inc(I);
  end;
end;

procedure PcmConvertS16BlockToF32(AIn: PSmallInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
var I: LongWord;
begin
  I := 0;
  while I + 3 < AN do
  begin
    PcmConvertS16x4ToF32(PSmallInt(PtrUInt(AIn) + I*2), AScale, PSingle(PtrUInt(AOut) + I*4));
    Inc(I, 4);
  end;
  while I < AN do
  begin
    PSingle(PtrUInt(AOut) + I*4)^ := SmallInt(PSmallInt(PtrUInt(AIn) + I*2)^) * AScale;
    Inc(I);
  end;
end;

procedure PcmConvertI32BlockStereoToF32Interleaved(AInL, AInR: PLongInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
var I: LongWord;
begin
  I := 0;
  while I + 3 < AN do
  begin
    PcmConvertI32x4StereoToF32Interleaved(PLongInt(PtrUInt(AInL) + I*4), PLongInt(PtrUInt(AInR) + I*4), AScale, PSingle(PtrUInt(AOut) + I*8));
    Inc(I, 4);
  end;
  while I < AN do
  begin
    PSingle(PtrUInt(AOut) + (I*2)*4)^ := PLongInt(PtrUInt(AInL) + I*4)^ * AScale;
    PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := PLongInt(PtrUInt(AInR) + I*4)^ * AScale;
    if PSingle(PtrUInt(AOut) + (I*2)*4)^ > 1.0 then PSingle(PtrUInt(AOut) + (I*2)*4)^ := 1.0 else if PSingle(PtrUInt(AOut) + (I*2)*4)^ < -1.0 then PSingle(PtrUInt(AOut) + (I*2)*4)^ := -1.0;
    if PSingle(PtrUInt(AOut) + (I*2+1)*4)^ > 1.0 then PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := 1.0 else if PSingle(PtrUInt(AOut) + (I*2+1)*4)^ < -1.0 then PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := -1.0;
    Inc(I);
  end;
end;

procedure PcmConvertS16BlockStereoToF32Interleaved(AInL, AInR: PSmallInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
var I: LongWord;
begin
  I := 0;
  while I + 3 < AN do
  begin
    PcmConvertS16x4StereoToF32Interleaved(PSmallInt(PtrUInt(AInL) + I*2), PSmallInt(PtrUInt(AInR) + I*2), AScale, PSingle(PtrUInt(AOut) + I*8));
    Inc(I, 4);
  end;
  while I < AN do
  begin
    PSingle(PtrUInt(AOut) + (I*2)*4)^ := SmallInt(PSmallInt(PtrUInt(AInL) + I*2)^) * AScale;
    PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := SmallInt(PSmallInt(PtrUInt(AInR) + I*2)^) * AScale;
    Inc(I);
  end;
end;
{$ELSE}
procedure PcmConvertI32x4ToF32Clamped(AIn: PLongInt; AScale: Single; AOut: PSingle); inline;
begin
  AOut[0] := AIn[0] * AScale; if AOut[0] > 1.0 then AOut[0] := 1.0 else if AOut[0] < -1.0 then AOut[0] := -1.0;
  AOut[1] := AIn[1] * AScale; if AOut[1] > 1.0 then AOut[1] := 1.0 else if AOut[1] < -1.0 then AOut[1] := -1.0;
  AOut[2] := AIn[2] * AScale; if AOut[2] > 1.0 then AOut[2] := 1.0 else if AOut[2] < -1.0 then AOut[2] := -1.0;
  AOut[3] := AIn[3] * AScale; if AOut[3] > 1.0 then AOut[3] := 1.0 else if AOut[3] < -1.0 then AOut[3] := -1.0;
end;

procedure PcmConvertS16x4ToF32(AIn: PSmallInt; AScale: Single; AOut: PSingle); inline;
begin
  AOut[0] := SmallInt(AIn[0]) * AScale; if AOut[0] > 1.0 then AOut[0] := 1.0 else if AOut[0] < -1.0 then AOut[0] := -1.0;
  AOut[1] := SmallInt(AIn[1]) * AScale; if AOut[1] > 1.0 then AOut[1] := 1.0 else if AOut[1] < -1.0 then AOut[1] := -1.0;
  AOut[2] := SmallInt(AIn[2]) * AScale; if AOut[2] > 1.0 then AOut[2] := 1.0 else if AOut[2] < -1.0 then AOut[2] := -1.0;
  AOut[3] := SmallInt(AIn[3]) * AScale; if AOut[3] > 1.0 then AOut[3] := 1.0 else if AOut[3] < -1.0 then AOut[3] := -1.0;
end;

procedure PcmConvertI32x4StereoToF32Interleaved(AInL, AInR: PLongInt; AScale: Single; AOut: PSingle); inline;
begin
  AOut[0] := AInL[0] * AScale; if AOut[0] > 1.0 then AOut[0] := 1.0 else if AOut[0] < -1.0 then AOut[0] := -1.0;
  AOut[1] := AInR[0] * AScale; if AOut[1] > 1.0 then AOut[1] := 1.0 else if AOut[1] < -1.0 then AOut[1] := -1.0;
  AOut[2] := AInL[1] * AScale; if AOut[2] > 1.0 then AOut[2] := 1.0 else if AOut[2] < -1.0 then AOut[2] := -1.0;
  AOut[3] := AInR[1] * AScale; if AOut[3] > 1.0 then AOut[3] := 1.0 else if AOut[3] < -1.0 then AOut[3] := -1.0;
  AOut[4] := AInL[2] * AScale; if AOut[4] > 1.0 then AOut[4] := 1.0 else if AOut[4] < -1.0 then AOut[4] := -1.0;
  AOut[5] := AInR[2] * AScale; if AOut[5] > 1.0 then AOut[5] := 1.0 else if AOut[5] < -1.0 then AOut[5] := -1.0;
  AOut[6] := AInL[3] * AScale; if AOut[6] > 1.0 then AOut[6] := 1.0 else if AOut[6] < -1.0 then AOut[6] := -1.0;
  AOut[7] := AInR[3] * AScale; if AOut[7] > 1.0 then AOut[7] := 1.0 else if AOut[7] < -1.0 then AOut[7] := -1.0;
end;

procedure PcmConvertS16x4StereoToF32Interleaved(AInL, AInR: PSmallInt; AScale: Single; AOut: PSingle); inline;
begin
  AOut[0] := SmallInt(AInL[0]) * AScale; if AOut[0] > 1.0 then AOut[0] := 1.0 else if AOut[0] < -1.0 then AOut[0] := -1.0;
  AOut[1] := SmallInt(AInR[0]) * AScale; if AOut[1] > 1.0 then AOut[1] := 1.0 else if AOut[1] < -1.0 then AOut[1] := -1.0;
  AOut[2] := SmallInt(AInL[1]) * AScale; if AOut[2] > 1.0 then AOut[2] := 1.0 else if AOut[2] < -1.0 then AOut[2] := -1.0;
  AOut[3] := SmallInt(AInR[1]) * AScale; if AOut[3] > 1.0 then AOut[3] := 1.0 else if AOut[3] < -1.0 then AOut[3] := -1.0;
  AOut[4] := SmallInt(AInL[2]) * AScale; if AOut[4] > 1.0 then AOut[4] := 1.0 else if AOut[4] < -1.0 then AOut[4] := -1.0;
  AOut[5] := SmallInt(AInR[2]) * AScale; if AOut[5] > 1.0 then AOut[5] := 1.0 else if AOut[5] < -1.0 then AOut[5] := -1.0;
  AOut[6] := SmallInt(AInL[3]) * AScale; if AOut[6] > 1.0 then AOut[6] := 1.0 else if AOut[6] < -1.0 then AOut[6] := -1.0;
  AOut[7] := SmallInt(AInR[3]) * AScale; if AOut[7] > 1.0 then AOut[7] := 1.0 else if AOut[7] < -1.0 then AOut[7] := -1.0;
end;

procedure PcmConvertI32BlockToF32Clamped(AIn: PLongInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
var I: LongWord;
begin
  I := 0;
  while I + 3 < AN do
  begin
    PcmConvertI32x4ToF32Clamped(PLongInt(PtrUInt(AIn) + I*4), AScale, PSingle(PtrUInt(AOut) + I*4));
    Inc(I, 4);
  end;
  while I < AN do
  begin
    PSingle(PtrUInt(AOut) + I*4)^ := PLongInt(PtrUInt(AIn) + I*4)^ * AScale;
    if PSingle(PtrUInt(AOut) + I*4)^ > 1.0 then PSingle(PtrUInt(AOut) + I*4)^ := 1.0 else if PSingle(PtrUInt(AOut) + I*4)^ < -1.0 then PSingle(PtrUInt(AOut) + I*4)^ := -1.0;
    Inc(I);
  end;
end;

procedure PcmConvertS16BlockToF32(AIn: PSmallInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
var I: LongWord;
begin
  I := 0;
  while I + 3 < AN do
  begin
    PcmConvertS16x4ToF32(PSmallInt(PtrUInt(AIn) + I*2), AScale, PSingle(PtrUInt(AOut) + I*4));
    Inc(I, 4);
  end;
  while I < AN do
  begin
    PSingle(PtrUInt(AOut) + I*4)^ := SmallInt(PSmallInt(PtrUInt(AIn) + I*2)^) * AScale;
    Inc(I);
  end;
end;

procedure PcmConvertI32BlockStereoToF32Interleaved(AInL, AInR: PLongInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
var I: LongWord;
begin
  I := 0;
  while I + 3 < AN do
  begin
    PcmConvertI32x4StereoToF32Interleaved(PLongInt(PtrUInt(AInL) + I*4), PLongInt(PtrUInt(AInR) + I*4), AScale, PSingle(PtrUInt(AOut) + I*8));
    Inc(I, 4);
  end;
  while I < AN do
  begin
    PSingle(PtrUInt(AOut) + (I*2)*4)^ := PLongInt(PtrUInt(AInL) + I*4)^ * AScale;
    PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := PLongInt(PtrUInt(AInR) + I*4)^ * AScale;
    if PSingle(PtrUInt(AOut) + (I*2)*4)^ > 1.0 then PSingle(PtrUInt(AOut) + (I*2)*4)^ := 1.0 else if PSingle(PtrUInt(AOut) + (I*2)*4)^ < -1.0 then PSingle(PtrUInt(AOut) + (I*2)*4)^ := -1.0;
    if PSingle(PtrUInt(AOut) + (I*2+1)*4)^ > 1.0 then PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := 1.0 else if PSingle(PtrUInt(AOut) + (I*2+1)*4)^ < -1.0 then PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := -1.0;
    Inc(I);
  end;
end;

procedure PcmConvertS16BlockStereoToF32Interleaved(AInL, AInR: PSmallInt; AScale: Single; AOut: PSingle; AN: LongWord); inline;
var I: LongWord;
begin
  I := 0;
  while I + 3 < AN do
  begin
    PcmConvertS16x4StereoToF32Interleaved(PSmallInt(PtrUInt(AInL) + I*2), PSmallInt(PtrUInt(AInR) + I*2), AScale, PSingle(PtrUInt(AOut) + I*8));
    Inc(I, 4);
  end;
  while I < AN do
  begin
    PSingle(PtrUInt(AOut) + (I*2)*4)^ := SmallInt(PSmallInt(PtrUInt(AInL) + I*2)^) * AScale;
    PSingle(PtrUInt(AOut) + (I*2+1)*4)^ := SmallInt(PSmallInt(PtrUInt(AInR) + I*2)^) * AScale;
    Inc(I);
  end;
end;
{$ENDIF}

end.
