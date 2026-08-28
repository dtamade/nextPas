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
{$ENDIF}

end.
