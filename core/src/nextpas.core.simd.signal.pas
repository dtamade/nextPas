unit nextpas.core.simd.signal;


{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.alloc;

type
  TSimdComplexF32 = record
    Re, Im: Single;
  end;
  PSimdComplexF32 = ^TSimdComplexF32;

  TSimdFftDirection = (sfdForward, sfdInverse);

  TSimdFftPlanF32 = record
  private
    FCount: SizeUInt;
    FNumStages: SizeUInt;
    FTwRe: PSingle;
    FTwIm: PSingle;
    FTwImInv: PSingle;
  public
    class function Create(ACount: SizeUInt): TSimdFftPlanF32; static;
    procedure Free;
    procedure Execute(AData: PSimdComplexF32; ADirection: TSimdFftDirection);
    procedure ExecuteBatch(AData: PSimdComplexF32; ABatchCount: SizeUInt; ADirection: TSimdFftDirection);
    property Count: SizeUInt read FCount;
  end;

procedure FftF32(aData: PSimdComplexF32; aCount: SizeUInt; aDirection: TSimdFftDirection);
procedure FftRadix2F32(aData: PSimdComplexF32; aCount: SizeUInt; aDirection: TSimdFftDirection);
procedure Convolve1DF32(aSignal: PSingle; aSignalCount: SizeUInt;
  aKernel: PSingle; aKernelCount: SizeUInt; aDst: PSingle);

procedure HannWindowF32(aDst: PSingle; aCount: SizeUInt);
procedure HammingWindowF32(aDst: PSingle; aCount: SizeUInt);
procedure BlackmanWindowF32(aDst: PSingle; aCount: SizeUInt);


procedure RealFftF32(aInput: PSingle; aOutput: PSimdComplexF32; aCount: SizeUInt);
procedure FirFilterF32(aSignal: PSingle; aSignalCount: SizeUInt;
  aCoeffs: PSingle; aCoeffCount: SizeUInt; aDst: PSingle);
procedure ResampleLinearF32(aSrc: PSingle; aSrcCount: SizeUInt;
  aDst: PSingle; aDstCount: SizeUInt);
procedure CrossCorrelationF32(aX, aY: PSingle; aCount: SizeUInt;
  aDst: PSingle; aMaxLag: SizeUInt);
procedure AutoCorrelationF32(aX: PSingle; aCount: SizeUInt;
  aDst: PSingle; aMaxLag: SizeUInt);
function EnergyF32(aSrc: PSingle; aCount: SizeUInt): Single;
function RmsF32(aSrc: PSingle; aCount: SizeUInt): Single;
function ZeroCrossingRateF32(aSrc: PSingle; aCount: SizeUInt): Single;
procedure PowerSpectrumF32(aComplex: PSimdComplexF32; aCount: SizeUInt; aDst: PSingle);
procedure MagnitudeSpectrumF32(aComplex: PSimdComplexF32; aCount: SizeUInt; aDst: PSingle);
procedure PowerToDecibelF32(aSrc, aDst: PSingle; aCount: SizeUInt; aRefPower: Single = 1.0);
procedure PreEmphasisF32(aSrc, aDst: PSingle; aCount: SizeUInt; aCoeff: Single = 0.97);

implementation

uses
  nextpas.core.simd.mathutil, nextpas.core.simd;

{$IFDEF SIMD_X86_AVAILABLE}
// Process 4 complex butterflies with SSE2
// AEven points to 4 consecutive complex (8 floats): [Re0,Im0,Re1,Im1,Re2,Im2,Re3,Im3]
// AOdd points to 4 consecutive complex (8 floats)
// ATwRe points to 4 twiddle real parts [TwRe0,TwRe1,TwRe2,TwRe3]
// ATwIm points to 4 twiddle imag parts [TwIm0,TwIm1,TwIm2,TwIm3]
procedure FftButterfly4_SSE2(AEven, AOdd, ATwRe, ATwIm: PSingle); assembler; nostackframe;
asm
  // RDI=AEven, RSI=AOdd, RDX=ATwRe, RCX=ATwIm
  // Process first 2 complex (xmm) then next 2

  // --- Pair 0-1 ---
  // Load twiddle: TwRe[0], TwRe[1] → broadcast to [TwRe0,TwRe0,TwRe1,TwRe1]
  movss xmm4, [rdx]        // TwRe0
  movss xmm5, [rdx+4]      // TwRe1
  unpcklps xmm4, xmm4      // [TwRe0, TwRe0, ?, ?]
  unpcklps xmm5, xmm5      // [TwRe1, TwRe1, ?, ?]
  movlhps xmm4, xmm5       // [TwRe0, TwRe0, TwRe1, TwRe1]

  movss xmm5, [rcx]        // TwIm0
  movss xmm6, [rcx+4]      // TwIm1
  unpcklps xmm5, xmm5      // [TwIm0, TwIm0, ?, ?]
  unpcklps xmm6, xmm6      // [TwIm1, TwIm1, ?, ?]
  movlhps xmm5, xmm6       // [TwIm0, TwIm0, TwIm1, TwIm1]

  // Load odd[0..1]: [OddRe0, OddIm0, OddRe1, OddIm1]
  movups xmm0, [rsi]

  // Compute t = twiddle * odd
  // t_re = odd_re * tw_re - odd_im * tw_im
  // t_im = odd_re * tw_im + odd_im * tw_re
  // Shuffle odd: [Re0, Re0, Re1, Re1]
  movaps xmm1, xmm0
  shufps xmm1, xmm1, 10100000b  // [Re0, Re0, Re1, Re1]
  // Shuffle odd: [Im0, Im0, Im1, Im1]
  movaps xmm2, xmm0
  shufps xmm2, xmm2, 11110101b  // [Im0, Im0, Im1, Im1]

  // xmm1 * xmm4 = [Re*TwRe, Re*TwRe, Re*TwRe, Re*TwRe] (wrong, need interleaved)
  // Actually we want: [Re*TwRe, Re*TwIm, Re*TwRe, Re*TwIm]
  // Let's use a different approach:
  // prod1 = Re_dup * [TwRe, TwIm, TwRe, TwIm] = [Re*TwRe, Re*TwIm, ...]
  // prod2 = Im_dup * [TwIm, TwRe, TwIm, TwRe] = [Im*TwIm, Im*TwRe, ...]
  // result = prod1 +/- prod2 = [Re*TwRe - Im*TwIm, Re*TwIm + Im*TwRe, ...]

  // Build interleaved twiddle: [TwRe0, TwIm0, TwRe1, TwIm1]
  movaps xmm6, xmm4        // [TwRe0, TwRe0, TwRe1, TwRe1]
  unpcklps xmm6, xmm5      // [TwRe0, TwIm0, TwRe0, TwIm0] - wrong
  // Actually unpcklps interleaves low halves: [a0,b0,a1,b1]
  // xmm4 = [TwRe0, TwRe0, TwRe1, TwRe1], xmm5 = [TwIm0, TwIm0, TwIm1, TwIm1]
  // unpcklps xmm4, xmm5 → [TwRe0, TwIm0, TwRe0, TwIm0]
  // That's not what we want either.

  // Simpler approach: build [TwRe0, TwIm0, TwRe1, TwIm1] directly
  movss xmm6, [rdx]        // TwRe0
  movss xmm7, [rcx]        // TwIm0
  unpcklps xmm6, xmm7      // [TwRe0, TwIm0, ?, ?]
  movss xmm7, [rdx+4]      // TwRe1
  movss xmm3, [rcx+4]      // TwIm1
  unpcklps xmm7, xmm3      // [TwRe1, TwIm1, ?, ?]
  movlhps xmm6, xmm7       // [TwRe0, TwIm0, TwRe1, TwIm1] = tw_ri

  // Build swapped: [TwIm0, TwRe0, TwIm1, TwRe1]
  movaps xmm7, xmm6
  shufps xmm7, xmm7, 10110001b  // swap pairs: [TwIm0, TwRe0, TwIm1, TwRe1] = tw_ir

  // prod1 = Re_dup * tw_ri
  mulps xmm1, xmm6         // [Re0*TwRe0, Re0*TwIm0, Re1*TwRe1, Re1*TwIm1]
  // prod2 = Im_dup * tw_ir
  mulps xmm2, xmm7         // [Im0*TwIm0, Im0*TwRe0, Im1*TwIm1, Im1*TwRe1]

  // t = prod1 +/- prod2: [Re*TwRe - Im*TwIm, Re*TwIm + Im*TwRe, ...]
  // Sign pattern: [-, +, -, +]
  // xmm3 = sign mask
  movaps xmm3, xmm1
  subps xmm3, xmm2         // [Re*TwRe-Im*TwIm, Re*TwIm-Im*TwRe, ...]
  addps xmm1, xmm2         // [Re*TwRe+Im*TwIm, Re*TwIm+Im*TwRe, ...]
  // We need: pos 0 from sub, pos 1 from add, pos 2 from sub, pos 3 from add
  // shufps xmm3, xmm1, ... won't work directly
  // Use blend: pick even from sub, odd from add
  // SSE2 doesn't have blendps, use manual: unpcklps/shufps
  // xmm3 = [sub0, sub1, sub2, sub3], xmm1 = [add0, add1, add2, add3]
  // Want: [sub0, add1, sub2, add3]
  // Approach: interleave then pick
  movaps xmm0, xmm3
  shufps xmm0, xmm1, 11011000b  // [sub0, sub2, add1, add3]
  shufps xmm0, xmm0, 11011000b  // [sub0, add1, sub2, add3] ← t for pair 0-1

  // Load even[0..1]
  movups xmm1, [rdi]       // [EvenRe0, EvenIm0, EvenRe1, EvenIm1]

  // even' = even + t
  movaps xmm2, xmm1
  addps xmm2, xmm0
  movups [rdi], xmm2

  // odd' = even - t
  subps xmm1, xmm0
  movups [rsi], xmm1

  // --- Pair 2-3 ---
  movss xmm6, [rdx+8]      // TwRe2
  movss xmm7, [rcx+8]      // TwIm2
  unpcklps xmm6, xmm7      // [TwRe2, TwIm2, ?, ?]
  movss xmm7, [rdx+12]     // TwRe3
  movss xmm3, [rcx+12]     // TwIm3
  unpcklps xmm7, xmm3      // [TwRe3, TwIm3, ?, ?]
  movlhps xmm6, xmm7       // [TwRe2, TwIm2, TwRe3, TwIm3] = tw_ri

  movaps xmm7, xmm6
  shufps xmm7, xmm7, 10110001b  // [TwIm2, TwRe2, TwIm3, TwRe3] = tw_ir

  movups xmm0, [rsi+16]    // odd[2..3]
  movaps xmm1, xmm0
  shufps xmm1, xmm1, 10100000b  // Re_dup
  movaps xmm2, xmm0
  shufps xmm2, xmm2, 11110101b  // Im_dup

  mulps xmm1, xmm6
  mulps xmm2, xmm7

  movaps xmm3, xmm1
  subps xmm3, xmm2
  addps xmm1, xmm2
  movaps xmm0, xmm3
  shufps xmm0, xmm1, 11011000b
  shufps xmm0, xmm0, 11011000b  // t for pair 2-3

  movups xmm1, [rdi+16]    // even[2..3]
  movaps xmm2, xmm1
  addps xmm2, xmm0
  movups [rdi+16], xmm2
  subps xmm1, xmm0
  movups [rsi+16], xmm1
end;

// Process 8 complex butterflies with AVX2
// AEven/AOdd point to 8 consecutive complex (16 floats each)
// ATwRe/ATwIm point to 8 twiddle values
procedure FftButterfly8_AVX2(AEven, AOdd, ATwRe, ATwIm: PSingle); assembler; nostackframe;
asm
  // RDI=AEven, RSI=AOdd, RDX=ATwRe, RCX=ATwIm
  // Process 4 complex per ymm pair (pairs 0-3, then 4-7)

  // --- Pairs 0-3 (first ymm) ---
  // Build interleaved twiddle: [TwRe0,TwIm0,TwRe1,TwIm1,TwRe2,TwIm2,TwRe3,TwIm3]
  vmovss xmm6, [rdx]
  vmovss xmm7, [rcx]
  vunpcklps xmm6, xmm6, xmm7    // [TwRe0,TwIm0,?,?]
  vmovss xmm7, [rdx+4]
  vmovss xmm5, [rcx+4]
  vunpcklps xmm7, xmm7, xmm5    // [TwRe1,TwIm1,?,?]
  vmovlhps xmm6, xmm6, xmm7    // [TwRe0,TwIm0,TwRe1,TwIm1]

  vmovss xmm4, [rdx+8]
  vmovss xmm5, [rcx+8]
  vunpcklps xmm4, xmm4, xmm5
  vmovss xmm5, [rdx+12]
  vmovss xmm3, [rcx+12]
  vunpcklps xmm5, xmm5, xmm3
  vmovlhps xmm4, xmm4, xmm5    // [TwRe2,TwIm2,TwRe3,TwIm3]

  vinsertf128 ymm6, ymm6, xmm4, 1  // ymm6 = tw_ri [TwRe0,TwIm0,...,TwRe3,TwIm3]

  // Swap pairs: [TwIm0,TwRe0,TwIm1,TwRe1,TwIm2,TwRe2,TwIm3,TwRe3]
  vshufps ymm7, ymm6, ymm6, 10110001b  // ymm7 = tw_ir

  // Load odd[0..3]
  vmovups ymm0, [rsi]

  // Re_dup: [Re0,Re0,Re1,Re1,Re2,Re2,Re3,Re3]
  vshufps ymm1, ymm0, ymm0, 10100000b
  // Im_dup: [Im0,Im0,Im1,Im1,Im2,Im2,Im3,Im3]
  vshufps ymm2, ymm0, ymm0, 11110101b

  // prod1 = Re_dup * tw_ri, prod2 = Im_dup * tw_ir
  vmulps ymm1, ymm1, ymm6
  vmulps ymm2, ymm2, ymm7

  // t = [Re*TwRe-Im*TwIm, Re*TwIm+Im*TwRe, ...]
  vsubps ymm3, ymm1, ymm2       // sub all
  vaddps ymm1, ymm1, ymm2       // add all
  // Blend: even from sub, odd from add
  vshufps ymm0, ymm3, ymm1, 11011000b
  vshufps ymm0, ymm0, ymm0, 11011000b  // t for pairs 0-3

  // even' = even + t, odd' = even - t
  vmovups ymm1, [rdi]
  vaddps ymm2, ymm1, ymm0
  vmovups [rdi], ymm2
  vsubps ymm1, ymm1, ymm0
  vmovups [rsi], ymm1

  // --- Pairs 4-7 (second ymm) ---
  vmovss xmm6, [rdx+16]
  vmovss xmm7, [rcx+16]
  vunpcklps xmm6, xmm6, xmm7
  vmovss xmm7, [rdx+20]
  vmovss xmm5, [rcx+20]
  vunpcklps xmm7, xmm7, xmm5
  vmovlhps xmm6, xmm6, xmm7

  vmovss xmm4, [rdx+24]
  vmovss xmm5, [rcx+24]
  vunpcklps xmm4, xmm4, xmm5
  vmovss xmm5, [rdx+28]
  vmovss xmm3, [rcx+28]
  vunpcklps xmm5, xmm5, xmm3
  vmovlhps xmm4, xmm4, xmm5

  vinsertf128 ymm6, ymm6, xmm4, 1
  vshufps ymm7, ymm6, ymm6, 10110001b

  vmovups ymm0, [rsi+32]
  vshufps ymm1, ymm0, ymm0, 10100000b
  vshufps ymm2, ymm0, ymm0, 11110101b
  vmulps ymm1, ymm1, ymm6
  vmulps ymm2, ymm2, ymm7
  vsubps ymm3, ymm1, ymm2
  vaddps ymm1, ymm1, ymm2
  vshufps ymm0, ymm3, ymm1, 11011000b
  vshufps ymm0, ymm0, ymm0, 11011000b

  vmovups ymm1, [rdi+32]
  vaddps ymm2, ymm1, ymm0
  vmovups [rdi+32], ymm2
  vsubps ymm1, ymm1, ymm0
  vmovups [rsi+32], ymm1

  vzeroupper
end;
{$ENDIF}

procedure FftRadix2F32(aData: PSimdComplexF32; aCount: SizeUInt; aDirection: TSimdFftDirection);
var
  i, j, k, m, mh, LStage, LNumStages: SizeUInt;
  LAngle, LWr, LWi, LTr, LTi, LUr, LUi: Single;
  LSign: Single;
  LTemp: TSimdComplexF32;
  LTwRe, LTwIm: PSingle;
  LTwiddleSize: SizeUInt;
  LNumBlocks, LBlock: SizeUInt;
  LPEven, LPOdd: PSingle;
  LTwOfs: SizeUInt;
begin
  if aCount <= 1 then Exit;

  if aDirection = sfdForward then LSign := -1.0 else LSign := 1.0;

  // Bit-reversal permutation
  j := 0;
  for i := 0 to aCount - 2 do
  begin
    if i < j then
    begin
      LTemp := aData[i];
      aData[i] := aData[j];
      aData[j] := LTemp;
    end;
    k := aCount shr 1;
    while (k >= 1) and (k <= j) do
    begin
      j := j - k;
      k := k shr 1;
    end;
    j := j + k;
  end;

  // Count stages
  LNumStages := 0;
  m := aCount;
  while m > 1 do begin Inc(LNumStages); m := m shr 1; end;

  // Precompute twiddle factors for all stages
  LTwiddleSize := aCount;
  LTwRe := PSingle(SimdAlloc(LTwiddleSize * SizeOf(Single)));
  LTwIm := PSingle(SimdAlloc(LTwiddleSize * SizeOf(Single)));

  m := 2;
  k := 0;
  for LStage := 0 to LNumStages - 1 do
  begin
    mh := m shr 1;
    LAngle := LSign * SIMD_PI / mh;
    LWr := SimdCosF32(LAngle);
    LWi := SimdSinF32(LAngle);
    LUr := 1.0;
    LUi := 0.0;
    for j := 0 to mh - 1 do
    begin
      LTwRe[k] := LUr;
      LTwIm[k] := LUi;
      Inc(k);
      LTr := LUr * LWr - LUi * LWi;
      LUi := LUr * LWi + LUi * LWr;
      LUr := LTr;
    end;
    m := m shl 1;
  end;

  // Butterfly passes — block-oriented for cache + SIMD
  // Fused radix-4 first pass (merges stage 0 and 1)
  if LNumStages >= 2 then
  begin
    // Stage 0 (m=2, mh=1): twiddle = 1 (trivial butterfly)
    // Stage 1 (m=4, mh=2): twiddle[0]=1, twiddle[1]= -j (forward) or +j (inverse)
    // Merged: process 4 consecutive elements as one radix-4 butterfly
    i := 0;
    while i < aCount do
    begin
      LTr := aData[i].Re + aData[i+1].Re;
      LTi := aData[i].Im + aData[i+1].Im;
      LUr := aData[i].Re - aData[i+1].Re;
      LUi := aData[i].Im - aData[i+1].Im;
      // After stage 0: even=[LTr,LTi], odd=[LUr,LUi] at positions i,i+1

      LWr := aData[i+2].Re + aData[i+3].Re;
      LWi := aData[i+2].Im + aData[i+3].Im;
      LAngle := aData[i+2].Re - aData[i+3].Re;  // reuse var
      LSign := aData[i+2].Im - aData[i+3].Im;   // reuse var
      // After stage 0: even2=[LWr,LWi], odd2=[LAngle,LSign] at positions i+2,i+3

      // Stage 1: twiddle[0]=1 applied to even2, twiddle[1]=±j applied to odd2
      // For forward (-j): multiply (a+bi) by -j = b - ai
      // For inverse (+j): multiply (a+bi) by +j = -b + ai
      if aDirection = sfdForward then
      begin
        // -j * (LAngle + LSign*i) = LSign - LAngle*i
        aData[i].Re := LTr + LWr;
        aData[i].Im := LTi + LWi;
        aData[i+1].Re := LUr + LSign;
        aData[i+1].Im := LUi - LAngle;
        aData[i+2].Re := LTr - LWr;
        aData[i+2].Im := LTi - LWi;
        aData[i+3].Re := LUr - LSign;
        aData[i+3].Im := LUi + LAngle;
      end
      else
      begin
        // +j * (LAngle + LSign*i) = -LSign + LAngle*i
        aData[i].Re := LTr + LWr;
        aData[i].Im := LTi + LWi;
        aData[i+1].Re := LUr - LSign;
        aData[i+1].Im := LUi + LAngle;
        aData[i+2].Re := LTr - LWr;
        aData[i+2].Im := LTi - LWi;
        aData[i+3].Re := LUr + LSign;
        aData[i+3].Im := LUi - LAngle;
      end;
      Inc(i, 4);
    end;
    // Skip first two stages in main loop
    m := 8;
    LTwOfs := 3; // skip twiddle entries for stage 0 (1 entry) + stage 1 (2 entries)
    LStage := 2;
  end
  else
  begin
    m := 2;
    LTwOfs := 0;
    LStage := 0;
  end;

  while LStage < LNumStages do
  begin
    mh := m shr 1;
    LNumBlocks := aCount div m;

    if mh >= 4 then
    begin
      // Later stages: data within each block is contiguous
      for LBlock := 0 to LNumBlocks - 1 do
      begin
        LPEven := PSingle(@aData[LBlock * m]);
        LPOdd := PSingle(@aData[LBlock * m + mh]);
        j := 0;
        {$IFDEF SIMD_X86_AVAILABLE}
        // AVX2 path: 8 complex butterflies at a time
        while j + 8 <= mh do
        begin
          FftButterfly8_AVX2(
            @LPEven[j * 2], @LPOdd[j * 2],
            @LTwRe[LTwOfs + j], @LTwIm[LTwOfs + j]);
          Inc(j, 8);
        end;
        // SSE2 remainder: 4 complex at a time
        while j + 4 <= mh do
        begin
          FftButterfly4_SSE2(
            @LPEven[j * 2], @LPOdd[j * 2],
            @LTwRe[LTwOfs + j], @LTwIm[LTwOfs + j]);
          Inc(j, 4);
        end;
        {$ENDIF}
        while j < mh do
        begin
          LUr := LTwRe[LTwOfs + j];
          LUi := LTwIm[LTwOfs + j];
          LTr := LUr * LPOdd[j*2] - LUi * LPOdd[j*2+1];
          LTi := LUr * LPOdd[j*2+1] + LUi * LPOdd[j*2];
          LPOdd[j*2]   := LPEven[j*2] - LTr;
          LPOdd[j*2+1] := LPEven[j*2+1] - LTi;
          LPEven[j*2]   := LPEven[j*2] + LTr;
          LPEven[j*2+1] := LPEven[j*2+1] + LTi;
          Inc(j);
        end;
      end;
    end
    else
    begin
      // Early stages (mh=1,2,3): scalar with 4x unroll on scattered butterflies
      for j := 0 to mh - 1 do
      begin
        LUr := LTwRe[LTwOfs + j];
        LUi := LTwIm[LTwOfs + j];
        i := j;
        while i + 3 * m < aCount do
        begin
          // Butterfly 0
          k := i + mh;
          LTr := LUr * aData[k].Re - LUi * aData[k].Im;
          LTi := LUr * aData[k].Im + LUi * aData[k].Re;
          aData[k].Re := aData[i].Re - LTr;
          aData[k].Im := aData[i].Im - LTi;
          aData[i].Re := aData[i].Re + LTr;
          aData[i].Im := aData[i].Im + LTi;
          // Butterfly 1
          k := i + m + mh;
          LTr := LUr * aData[k].Re - LUi * aData[k].Im;
          LTi := LUr * aData[k].Im + LUi * aData[k].Re;
          aData[k].Re := aData[i+m].Re - LTr;
          aData[k].Im := aData[i+m].Im - LTi;
          aData[i+m].Re := aData[i+m].Re + LTr;
          aData[i+m].Im := aData[i+m].Im + LTi;
          // Butterfly 2
          k := i + 2*m + mh;
          LTr := LUr * aData[k].Re - LUi * aData[k].Im;
          LTi := LUr * aData[k].Im + LUi * aData[k].Re;
          aData[k].Re := aData[i+2*m].Re - LTr;
          aData[k].Im := aData[i+2*m].Im - LTi;
          aData[i+2*m].Re := aData[i+2*m].Re + LTr;
          aData[i+2*m].Im := aData[i+2*m].Im + LTi;
          // Butterfly 3
          k := i + 3*m + mh;
          LTr := LUr * aData[k].Re - LUi * aData[k].Im;
          LTi := LUr * aData[k].Im + LUi * aData[k].Re;
          aData[k].Re := aData[i+3*m].Re - LTr;
          aData[k].Im := aData[i+3*m].Im - LTi;
          aData[i+3*m].Re := aData[i+3*m].Re + LTr;
          aData[i+3*m].Im := aData[i+3*m].Im + LTi;
          i := i + 4 * m;
        end;
        while i < aCount do
        begin
          k := i + mh;
          LTr := LUr * aData[k].Re - LUi * aData[k].Im;
          LTi := LUr * aData[k].Im + LUi * aData[k].Re;
          aData[k].Re := aData[i].Re - LTr;
          aData[k].Im := aData[i].Im - LTi;
          aData[i].Re := aData[i].Re + LTr;
          aData[i].Im := aData[i].Im + LTi;
          i := i + m;
        end;
      end;
    end;

    Inc(LTwOfs, mh);
    m := m shl 1;
    Inc(LStage);
  end;

  SimdFree(LTwIm);
  SimdFree(LTwRe);

  // Normalize for inverse
  if aDirection = sfdInverse then
    ArrayMulScalarF32(PSingle(aData), PSingle(aData), aCount * 2, 1.0 / aCount);
end;

// High-level FFT entry point — currently routes to radix-2
// Future: radix-4 for power-of-4 sizes
procedure FftF32(aData: PSimdComplexF32; aCount: SizeUInt; aDirection: TSimdFftDirection);
begin
  FftRadix2F32(aData, aCount, aDirection);
end;

class function TSimdFftPlanF32.Create(ACount: SizeUInt): TSimdFftPlanF32;
var
  m, mh, k, j: SizeUInt;
  LAngle, LWr, LWi, LUr, LUi, LTr: Single;
begin
  Result.FCount := ACount;
  Result.FNumStages := 0;
  m := ACount;
  while m > 1 do begin Inc(Result.FNumStages); m := m shr 1; end;

  Result.FTwRe := PSingle(SimdAlloc(ACount * SizeOf(Single)));
  Result.FTwIm := PSingle(SimdAlloc(ACount * SizeOf(Single)));

  m := 2;
  k := 0;
  for j := 0 to Result.FNumStages - 1 do
  begin
    mh := m shr 1;
    LAngle := -SIMD_PI / mh;
    LWr := SimdCosF32(LAngle);
    LWi := SimdSinF32(LAngle);
    LUr := 1.0;
    LUi := 0.0;
    for mh := 0 to (m shr 1) - 1 do
    begin
      Result.FTwRe[k] := LUr;
      Result.FTwIm[k] := LUi;
      Inc(k);
      LTr := LUr * LWr - LUi * LWi;
      LUi := LUr * LWi + LUi * LWr;
      LUr := LTr;
    end;
    m := m shl 1;
  end;

  // Inverse twiddle = conjugate (negate Im)
  Result.FTwImInv := PSingle(SimdAlloc(ACount * SizeOf(Single)));
  for k := 0 to ACount - 1 do
    Result.FTwImInv[k] := -Result.FTwIm[k];
end;

procedure TSimdFftPlanF32.Free;
begin
  if FTwRe <> nil then SimdFree(FTwRe);
  if FTwIm <> nil then SimdFree(FTwIm);
  if FTwImInv <> nil then SimdFree(FTwImInv);
  FTwRe := nil;
  FTwIm := nil;
  FTwImInv := nil;
  FCount := 0;
end;

procedure TSimdFftPlanF32.Execute(AData: PSimdComplexF32; ADirection: TSimdFftDirection);
var
  i, j, k, m, mh, LStage: SizeUInt;
  LTr, LTi, LUr, LUi, LWr, LWi, LAngle, LSign: Single;
  LTemp: TSimdComplexF32;
  LNumBlocks, LBlock: SizeUInt;
  LPEven, LPOdd: PSingle;
  LTwOfs: SizeUInt;
  LTwIm: PSingle;
begin
  if FCount <= 1 then Exit;
  if ADirection = sfdForward then
  begin
    LSign := -1.0;
    LTwIm := FTwIm;
  end
  else
  begin
    LSign := 1.0;
    LTwIm := FTwImInv;
  end;

  // Bit-reversal
  j := 0;
  for i := 0 to FCount - 2 do
  begin
    if i < j then
    begin
      LTemp := AData[i];
      AData[i] := AData[j];
      AData[j] := LTemp;
    end;
    k := FCount shr 1;
    while (k >= 1) and (k <= j) do
    begin
      j := j - k;
      k := k shr 1;
    end;
    j := j + k;
  end;

  // Fused radix-4 first pass
  if FNumStages >= 2 then
  begin
    i := 0;
    while i < FCount do
    begin
      LTr := AData[i].Re + AData[i+1].Re;
      LTi := AData[i].Im + AData[i+1].Im;
      LUr := AData[i].Re - AData[i+1].Re;
      LUi := AData[i].Im - AData[i+1].Im;
      LWr := AData[i+2].Re + AData[i+3].Re;
      LWi := AData[i+2].Im + AData[i+3].Im;
      LAngle := AData[i+2].Re - AData[i+3].Re;
      LSign := AData[i+2].Im - AData[i+3].Im;

      if ADirection = sfdForward then
      begin
        AData[i].Re := LTr + LWr;   AData[i].Im := LTi + LWi;
        AData[i+1].Re := LUr + LSign; AData[i+1].Im := LUi - LAngle;
        AData[i+2].Re := LTr - LWr;   AData[i+2].Im := LTi - LWi;
        AData[i+3].Re := LUr - LSign; AData[i+3].Im := LUi + LAngle;
      end
      else
      begin
        AData[i].Re := LTr + LWr;   AData[i].Im := LTi + LWi;
        AData[i+1].Re := LUr - LSign; AData[i+1].Im := LUi + LAngle;
        AData[i+2].Re := LTr - LWr;   AData[i+2].Im := LTi - LWi;
        AData[i+3].Re := LUr + LSign; AData[i+3].Im := LUi - LAngle;
      end;
      Inc(i, 4);
    end;
    m := 8;
    LTwOfs := 3;
    LStage := 2;
  end
  else
  begin
    m := 2;
    LTwOfs := 0;
    LStage := 0;
  end;

  // Remaining stages using precomputed twiddle (direction-adjusted at runtime)
  while LStage < FNumStages do
  begin
    mh := m shr 1;
    LNumBlocks := FCount div m;

    if mh >= 4 then
    begin
      for LBlock := 0 to LNumBlocks - 1 do
      begin
        LPEven := PSingle(@AData[LBlock * m]);
        LPOdd := PSingle(@AData[LBlock * m + mh]);
        j := 0;
        {$IFDEF SIMD_X86_AVAILABLE}
        while j + 8 <= mh do
        begin
          FftButterfly8_AVX2(@LPEven[j*2], @LPOdd[j*2],
            @FTwRe[LTwOfs + j], @LTwIm[LTwOfs + j]);
          Inc(j, 8);
        end;
        while j + 4 <= mh do
        begin
          FftButterfly4_SSE2(@LPEven[j*2], @LPOdd[j*2],
            @FTwRe[LTwOfs + j], @LTwIm[LTwOfs + j]);
          Inc(j, 4);
        end;
        {$ENDIF}
        while j < mh do
        begin
          LUr := FTwRe[LTwOfs + j];
          LUi := LTwIm[LTwOfs + j];
          LTr := LUr * LPOdd[j*2] - LUi * LPOdd[j*2+1];
          LTi := LUr * LPOdd[j*2+1] + LUi * LPOdd[j*2];
          LPOdd[j*2]   := LPEven[j*2] - LTr;
          LPOdd[j*2+1] := LPEven[j*2+1] - LTi;
          LPEven[j*2]   := LPEven[j*2] + LTr;
          LPEven[j*2+1] := LPEven[j*2+1] + LTi;
          Inc(j);
        end;
      end;
    end
    else
    begin
      for j := 0 to mh - 1 do
      begin
        LUr := FTwRe[LTwOfs + j];
        LUi := LTwIm[LTwOfs + j];
        i := j;
        while i < FCount do
        begin
          k := i + mh;
          LTr := LUr * AData[k].Re - LUi * AData[k].Im;
          LTi := LUr * AData[k].Im + LUi * AData[k].Re;
          AData[k].Re := AData[i].Re - LTr;
          AData[k].Im := AData[i].Im - LTi;
          AData[i].Re := AData[i].Re + LTr;
          AData[i].Im := AData[i].Im + LTi;
          i := i + m;
        end;
      end;
    end;

    Inc(LTwOfs, mh);
    m := m shl 1;
    Inc(LStage);
  end;

  if ADirection = sfdInverse then
    ArrayMulScalarF32(PSingle(AData), PSingle(AData), FCount * 2, 1.0 / FCount);
end;

procedure TSimdFftPlanF32.ExecuteBatch(AData: PSimdComplexF32; ABatchCount: SizeUInt; ADirection: TSimdFftDirection);
var
  LI: SizeUInt;
begin
  for LI := 0 to ABatchCount - 1 do
    Execute(@AData[LI * FCount], ADirection);
end;

procedure Convolve1DF32(aSignal: PSingle; aSignalCount: SizeUInt;
  aKernel: PSingle; aKernelCount: SizeUInt; aDst: PSingle);
var
  i, j: SizeUInt;
  LSum: Single;
  LHalf: SizeUInt;
begin
  if (aSignalCount = 0) or (aKernelCount = 0) then Exit;
  LHalf := aKernelCount div 2;

  for i := 0 to aSignalCount - 1 do
  begin
    if (i >= LHalf) and (i + aKernelCount - LHalf <= aSignalCount) then
      aDst[i] := ReduceDotF32(@aSignal[i - LHalf], aKernel, aKernelCount)
    else
    begin
      LSum := 0;
      for j := 0 to aKernelCount - 1 do
      begin
        if (i + j >= LHalf) and (i + j - LHalf < aSignalCount) then
          LSum := LSum + aSignal[i + j - LHalf] * aKernel[j];
      end;
      aDst[i] := LSum;
    end;
  end;
end;

procedure HannWindowF32(aDst: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
  LScale: Single;
begin
  if aCount <= 1 then begin if aCount = 1 then aDst[0] := 1.0; Exit; end;
  LScale := SIMD_TWO_PI / (aCount - 1);
  // Fill with indices scaled by 2*pi/(N-1)
  for i := 0 to aCount - 1 do
    aDst[i] := i * LScale;
  // SIMD cos
  ArrayCosF32(aDst, aDst, aCount);
  // dst = 0.5 * (1 - cos) = 0.5 - 0.5*cos = Linear(-0.5, 0.5)
  ArrayLinearF32(aDst, aDst, aCount, -0.5, 0.5);
end;

procedure HammingWindowF32(aDst: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
  LScale: Single;
begin
  if aCount <= 1 then begin if aCount = 1 then aDst[0] := 1.0; Exit; end;
  LScale := SIMD_TWO_PI / (aCount - 1);
  for i := 0 to aCount - 1 do
    aDst[i] := i * LScale;
  ArrayCosF32(aDst, aDst, aCount);
  // dst = 0.54 - 0.46*cos = Linear(-0.46, 0.54)
  ArrayLinearF32(aDst, aDst, aCount, -0.46, 0.54);
end;

procedure BlackmanWindowF32(aDst: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
  LScale: Single;
  LTmp: PSingle;
begin
  if aCount <= 1 then begin if aCount = 1 then aDst[0] := 1.0; Exit; end;
  LScale := SIMD_TWO_PI / (aCount - 1);
  for i := 0 to aCount - 1 do
    aDst[i] := i * LScale;
  LTmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
  ArrayMulScalarF32(aDst, LTmp, aCount, 2.0);
  ArrayCosF32(aDst, aDst, aCount);
  ArrayCosF32(LTmp, LTmp, aCount);
  ArrayLinearF32(aDst, aDst, aCount, -0.5, 0.42);
  ArrayAxpyF32(0.08, LTmp, aDst, aDst, aCount);
  SimdFree(LTmp);
  aDst[0] := 0.0;
  aDst[aCount - 1] := 0.0;
end;


// Real FFT using half-size complex FFT trick:
// Pack N real samples as N/2 complex: z[k] = x[2k] + j*x[2k+1]
// Do N/2 complex FFT, then unpack using symmetry
procedure RealFftF32(aInput: PSingle; aOutput: PSimdComplexF32; aCount: SizeUInt);
var
  LHalf, k: SizeUInt;
  LPacked: PSimdComplexF32;
  LTwR, LTwI, LER, LEI, LOR, LOI: Single;
  LAngle: Single;
begin
  if aCount = 0 then Exit;
  if aCount = 1 then begin aOutput[0].Re := aInput[0]; aOutput[0].Im := 0; Exit; end;

  // Odd count: fall back to naive
  if (aCount and 1) <> 0 then
  begin
    for k := 0 to aCount - 1 do
    begin
      aOutput[k].Re := aInput[k];
      aOutput[k].Im := 0;
    end;
    FftRadix2F32(aOutput, aCount, sfdForward);
    Exit;
  end;

  LHalf := aCount shr 1;

  // Pack: z[k] = x[2k] + j*x[2k+1]
  LPacked := PSimdComplexF32(SimdAlloc(LHalf * SizeOf(TSimdComplexF32)));
  for k := 0 to LHalf - 1 do
  begin
    LPacked[k].Re := aInput[k * 2];
    LPacked[k].Im := aInput[k * 2 + 1];
  end;

  // N/2 complex FFT
  FftRadix2F32(LPacked, LHalf, sfdForward);

  // Unpack: X[k] = 0.5*(Z[k] + Z*[N/2-k]) - 0.5j*W^k*(Z[k] - Z*[N/2-k])
  aOutput[0].Re := LPacked[0].Re + LPacked[0].Im;
  aOutput[0].Im := 0;
  aOutput[LHalf].Re := LPacked[0].Re - LPacked[0].Im;
  aOutput[LHalf].Im := 0;

  for k := 1 to LHalf - 1 do
  begin
    LAngle := -SIMD_PI * k / LHalf;
    LTwR := SimdCosF32(LAngle);
    LTwI := SimdSinF32(LAngle);

    // Even part: 0.5*(Z[k] + Z*[N/2-k])
    LER := 0.5 * (LPacked[k].Re + LPacked[LHalf - k].Re);
    LEI := 0.5 * (LPacked[k].Im - LPacked[LHalf - k].Im);
    // Odd part: 0.5*(Z[k] - Z*[N/2-k])
    LOR := 0.5 * (LPacked[k].Re - LPacked[LHalf - k].Re);
    LOI := 0.5 * (LPacked[k].Im + LPacked[LHalf - k].Im);

    // X[k] = Even - j*W^k * Odd
    // -j*W^k * (LOR + j*LOI) = -j*(LTwR+j*LTwI)*(LOR+j*LOI)
    //   = -j*(LTwR*LOR - LTwI*LOI + j*(LTwR*LOI + LTwI*LOR))
    //   = (LTwR*LOI + LTwI*LOR) - j*(LTwR*LOR - LTwI*LOI)
    aOutput[k].Re := LER + LTwR * LOI + LTwI * LOR;
    aOutput[k].Im := LEI - LTwR * LOR + LTwI * LOI;

    // X[N-k] = conj(X[k]) for real input (but we store N/2+1 points)
    aOutput[aCount - k].Re := LER - LTwR * LOI - LTwI * LOR;
    aOutput[aCount - k].Im := -(LEI - LTwR * LOR + LTwI * LOI);
  end;

  SimdFree(LPacked);
end;

procedure FirFilterF32(aSignal: PSingle; aSignalCount: SizeUInt;
  aCoeffs: PSingle; aCoeffCount: SizeUInt; aDst: PSingle);
var
  i, k: SizeUInt;
  LSum: Single;
  LRevCoeffs: PSingle;
begin
  if (aSignalCount = 0) or (aCoeffCount = 0) then Exit;
  LRevCoeffs := PSingle(SimdAlloc(aCoeffCount * SizeOf(Single)));
  for k := 0 to aCoeffCount - 1 do
    LRevCoeffs[k] := aCoeffs[aCoeffCount - 1 - k];
  for i := 0 to aSignalCount - 1 do
  begin
    if i >= aCoeffCount - 1 then
      aDst[i] := ReduceDotF32(@aSignal[i - aCoeffCount + 1], LRevCoeffs, aCoeffCount)
    else
    begin
      LSum := 0;
      for k := 0 to i do
        LSum := LSum + aSignal[i - k] * aCoeffs[k];
      aDst[i] := LSum;
    end;
  end;
  SimdFree(LRevCoeffs);
end;

procedure ResampleLinearF32(aSrc: PSingle; aSrcCount: SizeUInt;
  aDst: PSingle; aDstCount: SizeUInt);
var
  i: SizeUInt;
  LPos, LFrac: Single;
  LIdx: SizeUInt;
begin
  if (aSrcCount <= 1) or (aDstCount = 0) then Exit;
  if aDstCount = 1 then begin aDst[0] := aSrc[0]; Exit; end;
  for i := 0 to aDstCount - 1 do
  begin
    LPos := i * (aSrcCount - 1) / (aDstCount - 1);
    LIdx := SimdTruncF32(LPos);
    LFrac := LPos - LIdx;
    if LIdx >= aSrcCount - 1 then
      aDst[i] := aSrc[aSrcCount - 1]
    else
      aDst[i] := aSrc[LIdx] * (1 - LFrac) + aSrc[LIdx + 1] * LFrac;
  end;
end;

procedure CrossCorrelationF32(aX, aY: PSingle; aCount: SizeUInt;
  aDst: PSingle; aMaxLag: SizeUInt);
var
  lag, LEffectiveLag: SizeUInt;
begin
  if (aCount = 0) or (aMaxLag = 0) then Exit;
  if aMaxLag > aCount then LEffectiveLag := aCount else LEffectiveLag := aMaxLag;
  for lag := 0 to LEffectiveLag - 1 do
    aDst[lag] := ReduceDotF32(@aX[0], @aY[lag], aCount - lag);
end;

procedure AutoCorrelationF32(aX: PSingle; aCount: SizeUInt;
  aDst: PSingle; aMaxLag: SizeUInt);
begin
  CrossCorrelationF32(aX, aX, aCount, aDst, aMaxLag);
end;

function EnergyF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin
  Result := ReduceDotF32(aSrc, aSrc, aCount);
end;

function RmsF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin
  if aCount = 0 then Exit(0);
  Result := System.Sqrt(EnergyF32(aSrc, aCount) / aCount);
end;

function ZeroCrossingRateF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  i: SizeUInt;
  LCrossings: SizeUInt;
begin
  if aCount <= 1 then Exit(0);
  LCrossings := 0;
  for i := 1 to aCount - 1 do
    if (aSrc[i-1] >= 0) <> (aSrc[i] >= 0) then
      Inc(LCrossings);
  Result := LCrossings / (aCount - 1);
end;

procedure PowerSpectrumF32(aComplex: PSimdComplexF32; aCount: SizeUInt; aDst: PSingle);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aComplex[i].Re * aComplex[i].Re + aComplex[i].Im * aComplex[i].Im;
end;

procedure MagnitudeSpectrumF32(aComplex: PSimdComplexF32; aCount: SizeUInt; aDst: PSingle);
begin
  if aCount = 0 then Exit;
  PowerSpectrumF32(aComplex, aCount, aDst);
  ArraySqrtF32(aDst, aDst, aCount);
end;

procedure PowerToDecibelF32(aSrc, aDst: PSingle; aCount: SizeUInt; aRefPower: Single);
var LScale: Single;
begin
  if aCount = 0 then Exit;
  if aRefPower <= 0 then aRefPower := 1.0;
  ArrayClampF32(aSrc, aDst, aCount, 1e-10, 3.4028235e38);
  ArrayLogF32(aDst, aDst, aCount);
  LScale := 10.0 / SIMD_LN10;
  if aRefPower <> 1.0 then
    ArrayAddScalarF32(aDst, aDst, aCount, -SimdLnF32(aRefPower));
  ArrayMulScalarF32(aDst, aDst, aCount, LScale);
end;

procedure PreEmphasisF32(aSrc, aDst: PSingle; aCount: SizeUInt; aCoeff: Single);
var LTmp: PSingle;
begin
  if aCount = 0 then Exit;
  aDst[0] := aSrc[0];
  if aCount <= 1 then Exit;
  LTmp := PSingle(SimdAlloc((aCount - 1) * SizeOf(Single)));
  ArrayMulScalarF32(aSrc, LTmp, aCount - 1, aCoeff);
  ArraySubF32(@aSrc[1], LTmp, @aDst[1], aCount - 1);
  SimdFree(LTmp);
end;

end.
