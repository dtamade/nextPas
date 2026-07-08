unit nextpas.core.simd.linalg.gemm.sse2.blocked;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

{$IFDEF SIMD_X86_AVAILABLE}
uses
  nextpas.core.simd.alloc;

// SSE2-blocked GEMM: C[M,N] = A[M,K] * B[K,N]
// Uses 4×4 F32 microkernel
procedure GemmBlockedF32_SSE2(AA, AB, AC: PSingle;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);

// SSE2-blocked GEMM: C[M,N] = A[M,K] * B[K,N]
// Uses 2×2 F64 microkernel
procedure GemmBlockedF64_SSE2(AA, AB, AC: PDouble;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);
{$ENDIF}

implementation

{$IFDEF SIMD_X86_AVAILABLE}
uses
  nextpas.core.simd,
  nextpas.core.simd.linalg.gemm.sse2;

const
  // SSE2 F32 blocking parameters
  SSE2_MR_F32 = 4;
  SSE2_NR_F32 = 4;
  SSE2_MC_F32 = 64;
  SSE2_KC_F32 = 256;
  SSE2_NC_F32 = 256;

  // SSE2 F64 blocking parameters
  SSE2_MR_F64 = 2;
  SSE2_NR_F64 = 2;
  SSE2_MC_F64 = 32;
  SSE2_KC_F64 = 128;
  SSE2_NC_F64 = 128;

// Pack A panel: MR rows of K contiguous elements
procedure PackPanelA_SSE2_F32(ASrc: PSingle; ADst: PSingle;
  AM, AK, ASrcStride: SizeUInt);
var
  LRow, LR: SizeUInt;
begin
  LRow := 0;
  while LRow + SSE2_MR_F32 <= AM do
  begin
    for LR := 0 to SSE2_MR_F32 - 1 do
      Move(ASrc[(LRow + LR) * ASrcStride], ADst[LR * AK], AK * SizeOf(Single));
    Inc(LRow, SSE2_MR_F32);
    Inc(ADst, SSE2_MR_F32 * AK);
  end;
  if LRow < AM then
  begin
    for LR := 0 to AM - LRow - 1 do
      Move(ASrc[(LRow + LR) * ASrcStride], ADst[LR * AK], AK * SizeOf(Single));
    for LR := AM - LRow to SSE2_MR_F32 - 1 do
      FillChar(ADst[LR * AK], AK * SizeOf(Single), 0);
  end;
end;

// Pack B panel: NR columns from each K row
procedure PackPanelB_SSE2_F32(ASrc: PSingle; ADst: PSingle;
  AK, AN, ASrcStride: SizeUInt);
var
  LCol, LK, LPad: SizeUInt;
  LSrc: PSingle;
begin
  LCol := 0;
  while LCol + SSE2_NR_F32 <= AN do
  begin
    for LK := 0 to AK - 1 do
    begin
      LSrc := @ASrc[LK * ASrcStride + LCol];
      Move(LSrc^, ADst^, SSE2_NR_F32 * SizeOf(Single));
      Inc(ADst, SSE2_NR_F32);
    end;
    Inc(LCol, SSE2_NR_F32);
  end;
  if LCol < AN then
  begin
    LPad := AN - LCol;
    for LK := 0 to AK - 1 do
    begin
      LSrc := @ASrc[LK * ASrcStride + LCol];
      Move(LSrc^, ADst^, LPad * SizeOf(Single));
      FillChar(ADst[LPad], (SSE2_NR_F32 - LPad) * SizeOf(Single), 0);
      Inc(ADst, SSE2_NR_F32);
    end;
  end;
end;

procedure GemmBlockedF32_SSE2(AA, AB, AC: PSingle;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);
var
  LPackedA: PSingle;
  LPackedB: PSingle;
  LCurM, LCurN, LCurK: SizeUInt;
  LBlockM, LBlockN, LBlockK: SizeUInt;
  LMi, LNj, LNj2, LR, LP: SizeUInt;
  LMicroC: PSingle;
  LAStride, LCStride: SizeUInt;
  LBPanelIdx: SizeUInt;
  LSum: Single;
begin
  if (AM = 0) or (AN = 0) or (AK = 0) then Exit;

  LPackedA := PSingle(SimdAlloc(SSE2_MC_F32 * SSE2_KC_F32 * SizeOf(Single)));
  LPackedB := PSingle(SimdAlloc(SSE2_KC_F32 * SSE2_NC_F32 * SizeOf(Single)));

  LCStride := ALdC * SizeOf(Single);

  LCurK := 0;
  while LCurK < AK do
  begin
    LBlockK := AK - LCurK;
    if LBlockK > SSE2_KC_F32 then LBlockK := SSE2_KC_F32;

    LAStride := LBlockK * SizeOf(Single);

    LCurN := 0;
    while LCurN < AN do
    begin
      LBlockN := AN - LCurN;
      if LBlockN > SSE2_NC_F32 then LBlockN := SSE2_NC_F32;

      PackPanelB_SSE2_F32(@AB[LCurK * ALdB + LCurN], LPackedB,
        LBlockK, LBlockN, ALdB);

      LCurM := 0;
      while LCurM < AM do
      begin
        LBlockM := AM - LCurM;
        if LBlockM > SSE2_MC_F32 then LBlockM := SSE2_MC_F32;

        PackPanelA_SSE2_F32(@AA[LCurM * ALdA + LCurK], LPackedA,
          LBlockM, LBlockK, ALdA);

        LMi := 0;
        while LMi + SSE2_MR_F32 <= LBlockM do
        begin
          LNj := 0;
          LBPanelIdx := 0;
          while LNj + SSE2_NR_F32 <= LBlockN do
          begin
            LMicroC := @AC[(LCurM + LMi) * ALdC + LCurN + LNj];
            if LCurK = 0 then
              GemmMicro4x4F32_SSE2_Zero(
                @LPackedA[(LMi div SSE2_MR_F32) * SSE2_MR_F32 * LBlockK],
                @LPackedB[LBPanelIdx],
                LMicroC,
                LBlockK, LAStride, LCStride)
            else
              GemmMicro4x4F32_SSE2(
                @LPackedA[(LMi div SSE2_MR_F32) * SSE2_MR_F32 * LBlockK],
                @LPackedB[LBPanelIdx],
                LMicroC,
                LBlockK, LAStride, LCStride);
            Inc(LNj, SSE2_NR_F32);
            Inc(LBPanelIdx, LBlockK * SSE2_NR_F32);
          end;
          // N remainder
          if LNj < LBlockN then
          begin
            for LR := 0 to SSE2_MR_F32 - 1 do
            begin
              LNj2 := LNj;
              while LNj2 < LBlockN do
              begin
                LSum := 0;
                for LP := 0 to LBlockK - 1 do
                  LSum := LSum + AA[(LCurM + LMi + LR) * ALdA + LCurK + LP] *
                                 AB[(LCurK + LP) * ALdB + LCurN + LNj2];
                if LCurK = 0 then
                  AC[(LCurM + LMi + LR) * ALdC + LCurN + LNj2] := LSum
                else
                  AC[(LCurM + LMi + LR) * ALdC + LCurN + LNj2] :=
                    AC[(LCurM + LMi + LR) * ALdC + LCurN + LNj2] + LSum;
                Inc(LNj2);
              end;
            end;
          end;
          Inc(LMi, SSE2_MR_F32);
        end;
        // M remainder
        while LMi < LBlockM do
        begin
          LNj := 0;
          while LNj < LBlockN do
          begin
            LSum := 0;
            for LP := 0 to LBlockK - 1 do
              LSum := LSum + AA[(LCurM + LMi) * ALdA + LCurK + LP] *
                             AB[(LCurK + LP) * ALdB + LCurN + LNj];
            if LCurK = 0 then
              AC[(LCurM + LMi) * ALdC + LCurN + LNj] := LSum
            else
              AC[(LCurM + LMi) * ALdC + LCurN + LNj] :=
                AC[(LCurM + LMi) * ALdC + LCurN + LNj] + LSum;
            Inc(LNj);
          end;
          Inc(LMi);
        end;

        Inc(LCurM, LBlockM);
      end;
      Inc(LCurN, LBlockN);
    end;
    Inc(LCurK, LBlockK);
  end;

  SimdFree(LPackedB);
  SimdFree(LPackedA);
end;

// Pack A for F64 SSE2: 2 rows of K contiguous doubles
procedure PackPanelA_SSE2_F64(ASrc: PDouble; ADst: PDouble;
  AM, AK, ASrcStride: SizeUInt);
var
  LRow, LR: SizeUInt;
begin
  LRow := 0;
  while LRow + SSE2_MR_F64 <= AM do
  begin
    for LR := 0 to SSE2_MR_F64 - 1 do
      Move(ASrc[(LRow + LR) * ASrcStride], ADst[LR * AK], AK * SizeOf(Double));
    Inc(LRow, SSE2_MR_F64);
    Inc(ADst, SSE2_MR_F64 * AK);
  end;
  if LRow < AM then
  begin
    for LR := 0 to AM - LRow - 1 do
      Move(ASrc[(LRow + LR) * ASrcStride], ADst[LR * AK], AK * SizeOf(Double));
    for LR := AM - LRow to SSE2_MR_F64 - 1 do
      FillChar(ADst[LR * AK], AK * SizeOf(Double), 0);
  end;
end;

// Pack B for F64 SSE2: 2 columns from each K row
procedure PackPanelB_SSE2_F64(ASrc: PDouble; ADst: PDouble;
  AK, AN, ASrcStride: SizeUInt);
var
  LCol, LK, LPad: SizeUInt;
  LSrc: PDouble;
begin
  LCol := 0;
  while LCol + SSE2_NR_F64 <= AN do
  begin
    for LK := 0 to AK - 1 do
    begin
      LSrc := @ASrc[LK * ASrcStride + LCol];
      Move(LSrc^, ADst^, SSE2_NR_F64 * SizeOf(Double));
      Inc(ADst, SSE2_NR_F64);
    end;
    Inc(LCol, SSE2_NR_F64);
  end;
  if LCol < AN then
  begin
    LPad := AN - LCol;
    for LK := 0 to AK - 1 do
    begin
      LSrc := @ASrc[LK * ASrcStride + LCol];
      Move(LSrc^, ADst^, LPad * SizeOf(Double));
      FillChar(ADst[LPad], (SSE2_NR_F64 - LPad) * SizeOf(Double), 0);
      Inc(ADst, SSE2_NR_F64);
    end;
  end;
end;

procedure GemmBlockedF64_SSE2(AA, AB, AC: PDouble;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);
var
  LPackedA: PDouble;
  LPackedB: PDouble;
  LCurM, LCurN, LCurK: SizeUInt;
  LBlockM, LBlockN, LBlockK: SizeUInt;
  LMi, LNj, LR, LP: SizeUInt;
  LMicroC: PDouble;
  LAStride, LCStride: SizeUInt;
  LBPanelIdx: SizeUInt;
  LSum: Double;
  LRemainN, LRemainM: SizeUInt;
begin
  if (AM = 0) or (AN = 0) or (AK = 0) then Exit;

  LPackedA := PDouble(SimdAlloc(SSE2_MC_F64 * SSE2_KC_F64 * SizeOf(Double)));
  LPackedB := PDouble(SimdAlloc(SSE2_KC_F64 * SSE2_NC_F64 * SizeOf(Double)));

  LCStride := ALdC * SizeOf(Double);

  LCurK := 0;
  while LCurK < AK do
  begin
    LBlockK := AK - LCurK;
    if LBlockK > SSE2_KC_F64 then LBlockK := SSE2_KC_F64;

    LAStride := LBlockK * SizeOf(Double);

    LCurN := 0;
    while LCurN < AN do
    begin
      LBlockN := AN - LCurN;
      if LBlockN > SSE2_NC_F64 then LBlockN := SSE2_NC_F64;

      PackPanelB_SSE2_F64(@AB[LCurK * ALdB + LCurN], LPackedB,
        LBlockK, LBlockN, ALdB);

      LCurM := 0;
      while LCurM < AM do
      begin
        LBlockM := AM - LCurM;
        if LBlockM > SSE2_MC_F64 then LBlockM := SSE2_MC_F64;

        PackPanelA_SSE2_F64(@AA[LCurM * ALdA + LCurK], LPackedA,
          LBlockM, LBlockK, ALdA);

        LMi := 0;
        while LMi + SSE2_MR_F64 <= LBlockM do
        begin
          LNj := 0;
          LBPanelIdx := 0;
          while LNj + SSE2_NR_F64 <= LBlockN do
          begin
            LMicroC := @AC[(LCurM + LMi) * ALdC + LCurN + LNj];
            if LCurK = 0 then
              GemmMicro2x2F64_SSE2_Zero(
                @LPackedA[(LMi div SSE2_MR_F64) * SSE2_MR_F64 * LBlockK],
                @LPackedB[LBPanelIdx],
                LMicroC,
                LBlockK, LAStride, LCStride)
            else
              GemmMicro2x2F64_SSE2(
                @LPackedA[(LMi div SSE2_MR_F64) * SSE2_MR_F64 * LBlockK],
                @LPackedB[LBPanelIdx],
                LMicroC,
                LBlockK, LAStride, LCStride);
            Inc(LNj, SSE2_NR_F64);
            Inc(LBPanelIdx, LBlockK * SSE2_NR_F64);
          end;
          // N remainder
          while LNj < LBlockN do
          begin
            LSum := 0;
            for LP := 0 to LBlockK - 1 do
              LSum := LSum + AA[(LCurM + LMi) * ALdA + LCurK + LP] *
                             AB[(LCurK + LP) * ALdB + LCurN + LNj];
            if LCurK = 0 then
              AC[(LCurM + LMi) * ALdC + LCurN + LNj] := LSum
            else
              AC[(LCurM + LMi) * ALdC + LCurN + LNj] :=
                AC[(LCurM + LMi) * ALdC + LCurN + LNj] + LSum;
            Inc(LNj);
          end;
          Inc(LMi, SSE2_MR_F64);
        end;
        // M remainder
        while LMi < LBlockM do
        begin
          LNj := 0;
          while LNj < LBlockN do
          begin
            LSum := 0;
            for LP := 0 to LBlockK - 1 do
              LSum := LSum + AA[(LCurM + LMi) * ALdA + LCurK + LP] *
                             AB[(LCurK + LP) * ALdB + LCurN + LNj];
            if LCurK = 0 then
              AC[(LCurM + LMi) * ALdC + LCurN + LNj] := LSum
            else
              AC[(LCurM + LMi) * ALdC + LCurN + LNj] :=
                AC[(LCurM + LMi) * ALdC + LCurN + LNj] + LSum;
            Inc(LNj);
          end;
          Inc(LMi);
        end;

        Inc(LCurM, LBlockM);
      end;
      Inc(LCurN, LBlockN);
    end;
    Inc(LCurK, LBlockK);
  end;

  SimdFree(LPackedB);
  SimdFree(LPackedA);
end;

{$ENDIF} // SIMD_X86_AVAILABLE

end.
