unit nextpas.core.simd.linalg.gemm;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.alloc;

const
  GEMM_MR = 6;
  GEMM_NR = 16;
  GEMM_MC = 72;
  GEMM_KC = 512;
  GEMM_NC = 4096;

  GEMM_MR_F64 = 4;
  GEMM_NR_F64 = 8;
  GEMM_MC_F64 = 64;
  GEMM_KC_F64 = 256;

procedure GemmMicro6x16F32(AA, AB, AC: PSingle;
  AK, AAStride, ACStride: SizeUInt);

procedure GemmMicro6x16F32_Zero(AA, AB, AC: PSingle;
  AK, AAStride, ACStride: SizeUInt);

procedure PackPanelA_MR6(ASrc: PSingle; ADst: PSingle;
  AM, AK, ASrcStride: SizeUInt);

procedure PackPanelB_NR16(ASrc: PSingle; ADst: PSingle;
  AK, AN, ASrcStride: SizeUInt);

procedure GemmBlockedF32(AA, AB, AC: PSingle;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);

// C[M,N] = A[M,K] * B^T[N,K] — B stored as [N, K] row-major
procedure GemmBlockedTransBF32(AA, AB, AC: PSingle;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);

// F64 GEMM: C[M,N] = A[M,K] * B[K,N]
procedure GemmBlockedF64(AA, AB, AC: PDouble;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);

implementation

uses
  nextpas.core.simd;

// === 6x16 AVX2+FMA microkernel ===
// C[6,16] += A[6,K] * B_packed[K,16]
// RDI=A, RSI=B_packed, RDX=C, RCX=K, R8=A_stride(bytes), R9=C_stride(bytes)
procedure GemmMicro6x16F32(AA, AB, AC: PSingle;
  AK, AAStride, ACStride: SizeUInt); assembler; nostackframe;
asm
  // Load existing C[6,16] into accumulators
  mov rax, rdx            // save C ptr
  vmovups ymm0, [rdx]
  vmovups ymm1, [rdx + 32]
  add rdx, r9
  vmovups ymm2, [rdx]
  vmovups ymm3, [rdx + 32]
  add rdx, r9
  vmovups ymm4, [rdx]
  vmovups ymm5, [rdx + 32]
  add rdx, r9
  vmovups ymm6, [rdx]
  vmovups ymm7, [rdx + 32]
  add rdx, r9
  vmovups ymm8, [rdx]
  vmovups ymm9, [rdx + 32]
  add rdx, r9
  vmovups ymm10, [rdx]
  vmovups ymm11, [rdx + 32]

  mov rdx, rax            // restore C ptr

  mov rax, rdi            // A_row0
  lea r10, [rdi + r8]
  lea r11, [r10 + r8]
  push rbx
  lea rbx, [r11 + r8]
  push r12
  lea r12, [rbx + r8]
  push r13
  lea r13, [r12 + r8]
  push r14
  push r15

  test rcx, rcx
  jz @store

  mov r14, rcx
  shr r14, 1
  jz @k_tail

@k_loop:
  vmovups ymm12, [rsi]
  vmovups ymm13, [rsi + 32]

  vbroadcastss ymm14, dword [rax]
  vfmadd231ps ymm0, ymm14, ymm12
  vfmadd231ps ymm1, ymm14, ymm13

  vbroadcastss ymm14, dword [r10]
  vfmadd231ps ymm2, ymm14, ymm12
  vfmadd231ps ymm3, ymm14, ymm13

  vbroadcastss ymm14, dword [r11]
  vfmadd231ps ymm4, ymm14, ymm12
  vfmadd231ps ymm5, ymm14, ymm13

  vbroadcastss ymm14, dword [rbx]
  vfmadd231ps ymm6, ymm14, ymm12
  vfmadd231ps ymm7, ymm14, ymm13

  vbroadcastss ymm14, dword [r12]
  vfmadd231ps ymm8, ymm14, ymm12
  vfmadd231ps ymm9, ymm14, ymm13

  vbroadcastss ymm14, dword [r13]
  vfmadd231ps ymm10, ymm14, ymm12
  vfmadd231ps ymm11, ymm14, ymm13

  vmovups ymm12, [rsi + 64]
  vmovups ymm13, [rsi + 96]

  vbroadcastss ymm14, dword [rax + 4]
  vfmadd231ps ymm0, ymm14, ymm12
  vfmadd231ps ymm1, ymm14, ymm13

  vbroadcastss ymm14, dword [r10 + 4]
  vfmadd231ps ymm2, ymm14, ymm12
  vfmadd231ps ymm3, ymm14, ymm13

  vbroadcastss ymm14, dword [r11 + 4]
  vfmadd231ps ymm4, ymm14, ymm12
  vfmadd231ps ymm5, ymm14, ymm13

  vbroadcastss ymm14, dword [rbx + 4]
  vfmadd231ps ymm6, ymm14, ymm12
  vfmadd231ps ymm7, ymm14, ymm13

  vbroadcastss ymm14, dword [r12 + 4]
  vfmadd231ps ymm8, ymm14, ymm12
  vfmadd231ps ymm9, ymm14, ymm13

  vbroadcastss ymm14, dword [r13 + 4]
  vfmadd231ps ymm10, ymm14, ymm12
  vfmadd231ps ymm11, ymm14, ymm13

  add rax, 8
  add r10, 8
  add r11, 8
  add rbx, 8
  add r12, 8
  add r13, 8
  add rsi, 128

  dec r14
  jnz @k_loop

@k_tail:
  test rcx, 1
  jz @store

  vmovups ymm12, [rsi]
  vmovups ymm13, [rsi + 32]

  vbroadcastss ymm14, dword [rax]
  vfmadd231ps ymm0, ymm14, ymm12
  vfmadd231ps ymm1, ymm14, ymm13

  vbroadcastss ymm14, dword [r10]
  vfmadd231ps ymm2, ymm14, ymm12
  vfmadd231ps ymm3, ymm14, ymm13

  vbroadcastss ymm14, dword [r11]
  vfmadd231ps ymm4, ymm14, ymm12
  vfmadd231ps ymm5, ymm14, ymm13

  vbroadcastss ymm14, dword [rbx]
  vfmadd231ps ymm6, ymm14, ymm12
  vfmadd231ps ymm7, ymm14, ymm13

  vbroadcastss ymm14, dword [r12]
  vfmadd231ps ymm8, ymm14, ymm12
  vfmadd231ps ymm9, ymm14, ymm13

  vbroadcastss ymm14, dword [r13]
  vfmadd231ps ymm10, ymm14, ymm12
  vfmadd231ps ymm11, ymm14, ymm13

@store:
  vmovups [rdx], ymm0
  vmovups [rdx + 32], ymm1
  add rdx, r9
  vmovups [rdx], ymm2
  vmovups [rdx + 32], ymm3
  add rdx, r9
  vmovups [rdx], ymm4
  vmovups [rdx + 32], ymm5
  add rdx, r9
  vmovups [rdx], ymm6
  vmovups [rdx + 32], ymm7
  add rdx, r9
  vmovups [rdx], ymm8
  vmovups [rdx + 32], ymm9
  add rdx, r9
  vmovups [rdx], ymm10
  vmovups [rdx + 32], ymm11

  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  vzeroupper
end;

// Zero-init version: C[6,16] = A[6,K] * B_packed[K,16] (no load of C)
procedure GemmMicro6x16F32_Zero(AA, AB, AC: PSingle;
  AK, AAStride, ACStride: SizeUInt); assembler; nostackframe;
asm
  vxorps ymm0, ymm0, ymm0
  vxorps ymm1, ymm1, ymm1
  vxorps ymm2, ymm2, ymm2
  vxorps ymm3, ymm3, ymm3
  vxorps ymm4, ymm4, ymm4
  vxorps ymm5, ymm5, ymm5
  vxorps ymm6, ymm6, ymm6
  vxorps ymm7, ymm7, ymm7
  vxorps ymm8, ymm8, ymm8
  vxorps ymm9, ymm9, ymm9
  vxorps ymm10, ymm10, ymm10
  vxorps ymm11, ymm11, ymm11

  mov rax, rdi
  lea r10, [rdi + r8]
  lea r11, [r10 + r8]
  push rbx
  lea rbx, [r11 + r8]
  push r12
  lea r12, [rbx + r8]
  push r13
  lea r13, [r12 + r8]
  push r14
  push r15

  test rcx, rcx
  jz @store_z

  // K loop with 2x unroll
  mov r14, rcx
  shr r14, 1              // r14 = K/2
  jz @k_tail_z           // if K < 2, go to tail

@k_loop_z:
  // --- K iteration 0 ---
  vmovups ymm12, [rsi]
  vmovups ymm13, [rsi + 32]

  vbroadcastss ymm14, dword [rax]
  vfmadd231ps ymm0, ymm14, ymm12
  vfmadd231ps ymm1, ymm14, ymm13

  vbroadcastss ymm14, dword [r10]
  vfmadd231ps ymm2, ymm14, ymm12
  vfmadd231ps ymm3, ymm14, ymm13

  vbroadcastss ymm14, dword [r11]
  vfmadd231ps ymm4, ymm14, ymm12
  vfmadd231ps ymm5, ymm14, ymm13

  vbroadcastss ymm14, dword [rbx]
  vfmadd231ps ymm6, ymm14, ymm12
  vfmadd231ps ymm7, ymm14, ymm13

  vbroadcastss ymm14, dword [r12]
  vfmadd231ps ymm8, ymm14, ymm12
  vfmadd231ps ymm9, ymm14, ymm13

  vbroadcastss ymm14, dword [r13]
  vfmadd231ps ymm10, ymm14, ymm12
  vfmadd231ps ymm11, ymm14, ymm13

  // --- K iteration 1 ---
  vmovups ymm12, [rsi + 64]
  vmovups ymm13, [rsi + 96]

  vbroadcastss ymm14, dword [rax + 4]
  vfmadd231ps ymm0, ymm14, ymm12
  vfmadd231ps ymm1, ymm14, ymm13

  vbroadcastss ymm14, dword [r10 + 4]
  vfmadd231ps ymm2, ymm14, ymm12
  vfmadd231ps ymm3, ymm14, ymm13

  vbroadcastss ymm14, dword [r11 + 4]
  vfmadd231ps ymm4, ymm14, ymm12
  vfmadd231ps ymm5, ymm14, ymm13

  vbroadcastss ymm14, dword [rbx + 4]
  vfmadd231ps ymm6, ymm14, ymm12
  vfmadd231ps ymm7, ymm14, ymm13

  vbroadcastss ymm14, dword [r12 + 4]
  vfmadd231ps ymm8, ymm14, ymm12
  vfmadd231ps ymm9, ymm14, ymm13

  vbroadcastss ymm14, dword [r13 + 4]
  vfmadd231ps ymm10, ymm14, ymm12
  vfmadd231ps ymm11, ymm14, ymm13

  add rax, 8
  add r10, 8
  add r11, 8
  add rbx, 8
  add r12, 8
  add r13, 8
  add rsi, 128

  dec r14
  jnz @k_loop_z

@k_tail_z:
  test rcx, 1
  jz @store_z

  // Handle odd K
  vmovups ymm12, [rsi]
  vmovups ymm13, [rsi + 32]

  vbroadcastss ymm14, dword [rax]
  vfmadd231ps ymm0, ymm14, ymm12
  vfmadd231ps ymm1, ymm14, ymm13

  vbroadcastss ymm14, dword [r10]
  vfmadd231ps ymm2, ymm14, ymm12
  vfmadd231ps ymm3, ymm14, ymm13

  vbroadcastss ymm14, dword [r11]
  vfmadd231ps ymm4, ymm14, ymm12
  vfmadd231ps ymm5, ymm14, ymm13

  vbroadcastss ymm14, dword [rbx]
  vfmadd231ps ymm6, ymm14, ymm12
  vfmadd231ps ymm7, ymm14, ymm13

  vbroadcastss ymm14, dword [r12]
  vfmadd231ps ymm8, ymm14, ymm12
  vfmadd231ps ymm9, ymm14, ymm13

  vbroadcastss ymm14, dword [r13]
  vfmadd231ps ymm10, ymm14, ymm12
  vfmadd231ps ymm11, ymm14, ymm13

@store_z:
  vmovups [rdx], ymm0
  vmovups [rdx + 32], ymm1
  add rdx, r9
  vmovups [rdx], ymm2
  vmovups [rdx + 32], ymm3
  add rdx, r9
  vmovups [rdx], ymm4
  vmovups [rdx + 32], ymm5
  add rdx, r9
  vmovups [rdx], ymm6
  vmovups [rdx + 32], ymm7
  add rdx, r9
  vmovups [rdx], ymm8
  vmovups [rdx + 32], ymm9
  add rdx, r9
  vmovups [rdx], ymm10
  vmovups [rdx + 32], ymm11

  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  vzeroupper
end;

procedure PackPanelA_MR6(ASrc: PSingle; ADst: PSingle;
  AM, AK, ASrcStride: SizeUInt);
var
  LRow, LR: SizeUInt;
begin
  LRow := 0;
  while LRow + GEMM_MR <= AM do
  begin
    for LR := 0 to GEMM_MR - 1 do
      Move(ASrc[(LRow + LR) * ASrcStride], ADst[LR * AK], AK * SizeOf(Single));
    Inc(LRow, GEMM_MR);
    Inc(ADst, GEMM_MR * AK);
  end;
  if LRow < AM then
  begin
    for LR := 0 to AM - LRow - 1 do
      Move(ASrc[(LRow + LR) * ASrcStride], ADst[LR * AK], AK * SizeOf(Single));
    for LR := AM - LRow to GEMM_MR - 1 do
      FillChar(ADst[LR * AK], AK * SizeOf(Single), 0);
  end;
end;

procedure PackPanelB_NR16(ASrc: PSingle; ADst: PSingle;
  AK, AN, ASrcStride: SizeUInt);
var
  LCol, LK: SizeUInt;
  LPad: SizeUInt;
  LSrc: PSingle;
begin
  LCol := 0;
  while LCol + GEMM_NR <= AN do
  begin
    for LK := 0 to AK - 1 do
    begin
      LSrc := @ASrc[LK * ASrcStride + LCol];
      Move(LSrc^, ADst^, GEMM_NR * SizeOf(Single));
      Inc(ADst, GEMM_NR);
    end;
    Inc(LCol, GEMM_NR);
  end;
  if LCol < AN then
  begin
    LPad := AN - LCol;
    for LK := 0 to AK - 1 do
    begin
      LSrc := @ASrc[LK * ASrcStride + LCol];
      Move(LSrc^, ADst^, LPad * SizeOf(Single));
      FillChar(ADst[LPad], (GEMM_NR - LPad) * SizeOf(Single), 0);
      Inc(ADst, GEMM_NR);
    end;
  end;
end;

procedure GemmBlockedF32(AA, AB, AC: PSingle;
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

  LPackedA := PSingle(SimdAlloc(GEMM_MC * GEMM_KC * SizeOf(Single)));
  LPackedB := PSingle(SimdAlloc(GEMM_KC * GEMM_NC * SizeOf(Single)));

  LCStride := ALdC * SizeOf(Single);

  LCurK := 0;
  while LCurK < AK do
  begin
    LBlockK := AK - LCurK;
    if LBlockK > GEMM_KC then LBlockK := GEMM_KC;

    LAStride := LBlockK * SizeOf(Single);

    LCurN := 0;
    while LCurN < AN do
    begin
      LBlockN := AN - LCurN;
      if LBlockN > GEMM_NC then LBlockN := GEMM_NC;

      PackPanelB_NR16(@AB[LCurK * ALdB + LCurN], LPackedB,
        LBlockK, LBlockN, ALdB);

      LCurM := 0;
      while LCurM < AM do
      begin
        LBlockM := AM - LCurM;
        if LBlockM > GEMM_MC then LBlockM := GEMM_MC;

        PackPanelA_MR6(@AA[LCurM * ALdA + LCurK], LPackedA,
          LBlockM, LBlockK, ALdA);

        LMi := 0;
        while LMi + GEMM_MR <= LBlockM do
        begin
          LNj := 0;
          LBPanelIdx := 0;
          while LNj + GEMM_NR <= LBlockN do
          begin
            LMicroC := @AC[(LCurM + LMi) * ALdC + LCurN + LNj];
            if LCurK = 0 then
              GemmMicro6x16F32_Zero(
                @LPackedA[(LMi div GEMM_MR) * GEMM_MR * LBlockK],
                @LPackedB[LBPanelIdx],
                LMicroC,
                LBlockK, LAStride, LCStride)
            else
              GemmMicro6x16F32(
                @LPackedA[(LMi div GEMM_MR) * GEMM_MR * LBlockK],
                @LPackedB[LBPanelIdx],
                LMicroC,
                LBlockK, LAStride, LCStride);
            Inc(LNj, GEMM_NR);
            Inc(LBPanelIdx, LBlockK * GEMM_NR);
          end;
          // N remainder: scalar loop over all MR rows
          if LNj < LBlockN then
          begin
            for LR := 0 to GEMM_MR - 1 do
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
          Inc(LMi, GEMM_MR);
        end;
        // M remainder: scalar loop
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

// Pack B from transposed layout: B stored as [N, K] row-major
// Output: [K, NR] panels for microkernel consumption
procedure PackPanelB_NR16_TransB(ASrc: PSingle; ADst: PSingle;
  AK, AN, ASrcStride: SizeUInt);
var
  LCol, LK, LPad, LR: SizeUInt;
begin
  LCol := 0;
  while LCol + GEMM_NR <= AN do
  begin
    for LK := 0 to AK - 1 do
    begin
      ADst[0]  := ASrc[(LCol + 0)  * ASrcStride + LK];
      ADst[1]  := ASrc[(LCol + 1)  * ASrcStride + LK];
      ADst[2]  := ASrc[(LCol + 2)  * ASrcStride + LK];
      ADst[3]  := ASrc[(LCol + 3)  * ASrcStride + LK];
      ADst[4]  := ASrc[(LCol + 4)  * ASrcStride + LK];
      ADst[5]  := ASrc[(LCol + 5)  * ASrcStride + LK];
      ADst[6]  := ASrc[(LCol + 6)  * ASrcStride + LK];
      ADst[7]  := ASrc[(LCol + 7)  * ASrcStride + LK];
      ADst[8]  := ASrc[(LCol + 8)  * ASrcStride + LK];
      ADst[9]  := ASrc[(LCol + 9)  * ASrcStride + LK];
      ADst[10] := ASrc[(LCol + 10) * ASrcStride + LK];
      ADst[11] := ASrc[(LCol + 11) * ASrcStride + LK];
      ADst[12] := ASrc[(LCol + 12) * ASrcStride + LK];
      ADst[13] := ASrc[(LCol + 13) * ASrcStride + LK];
      ADst[14] := ASrc[(LCol + 14) * ASrcStride + LK];
      ADst[15] := ASrc[(LCol + 15) * ASrcStride + LK];
      Inc(ADst, GEMM_NR);
    end;
    Inc(LCol, GEMM_NR);
  end;
  if LCol < AN then
  begin
    LPad := AN - LCol;
    for LK := 0 to AK - 1 do
    begin
      FillChar(ADst^, GEMM_NR * SizeOf(Single), 0);
      for LR := 0 to LPad - 1 do
        ADst[LR] := ASrc[(LCol + LR) * ASrcStride + LK];
      Inc(ADst, GEMM_NR);
    end;
  end;
end;

procedure GemmBlockedTransBF32(AA, AB, AC: PSingle;
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

  LPackedA := PSingle(SimdAlloc(GEMM_MC * GEMM_KC * SizeOf(Single)));
  LPackedB := PSingle(SimdAlloc(GEMM_KC * GEMM_NC * SizeOf(Single)));

  LCStride := ALdC * SizeOf(Single);

  LCurK := 0;
  while LCurK < AK do
  begin
    LBlockK := AK - LCurK;
    if LBlockK > GEMM_KC then LBlockK := GEMM_KC;

    LAStride := LBlockK * SizeOf(Single);

    LCurN := 0;
    while LCurN < AN do
    begin
      LBlockN := AN - LCurN;
      if LBlockN > GEMM_NC then LBlockN := GEMM_NC;

      // B is [N, K] row-major; pack column slice [LCurN..+LBlockN, LCurK..+LBlockK]
      PackPanelB_NR16_TransB(@AB[LCurN * ALdB + LCurK], LPackedB,
        LBlockK, LBlockN, ALdB);

      LCurM := 0;
      while LCurM < AM do
      begin
        LBlockM := AM - LCurM;
        if LBlockM > GEMM_MC then LBlockM := GEMM_MC;

        PackPanelA_MR6(@AA[LCurM * ALdA + LCurK], LPackedA,
          LBlockM, LBlockK, ALdA);

        LMi := 0;
        while LMi + GEMM_MR <= LBlockM do
        begin
          LNj := 0;
          LBPanelIdx := 0;
          while LNj + GEMM_NR <= LBlockN do
          begin
            LMicroC := @AC[(LCurM + LMi) * ALdC + LCurN + LNj];
            if LCurK = 0 then
              GemmMicro6x16F32_Zero(
                @LPackedA[(LMi div GEMM_MR) * GEMM_MR * LBlockK],
                @LPackedB[LBPanelIdx],
                LMicroC,
                LBlockK, LAStride, LCStride)
            else
              GemmMicro6x16F32(
                @LPackedA[(LMi div GEMM_MR) * GEMM_MR * LBlockK],
              @LPackedB[LBPanelIdx],
              LMicroC,
              LBlockK, LAStride, LCStride);
            Inc(LNj, GEMM_NR);
            Inc(LBPanelIdx, LBlockK * GEMM_NR);
          end;
          if LNj < LBlockN then
          begin
            for LR := 0 to GEMM_MR - 1 do
            begin
              LNj2 := LNj;
              while LNj2 < LBlockN do
              begin
                LSum := ReduceDotF32(@AA[(LCurM + LMi + LR) * ALdA + LCurK],
                             @AB[(LCurN + LNj2) * ALdB + LCurK], LBlockK);
                if LCurK = 0 then
                  AC[(LCurM + LMi + LR) * ALdC + LCurN + LNj2] := LSum
                else
                  AC[(LCurM + LMi + LR) * ALdC + LCurN + LNj2] :=
                    AC[(LCurM + LMi + LR) * ALdC + LCurN + LNj2] + LSum;
                Inc(LNj2);
              end;
            end;
          end;
          Inc(LMi, GEMM_MR);
        end;
        while LMi < LBlockM do
        begin
          LNj := 0;
          while LNj < LBlockN do
          begin
            LSum := ReduceDotF32(@AA[(LCurM + LMi) * ALdA + LCurK],
                         @AB[(LCurN + LNj) * ALdB + LCurK], LBlockK);
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

// === F64 GEMM ===

// 4x8 AVX2 microkernel for F64: C[4,8] += A[4,K] * B_packed[K,8]
procedure GemmMicro4x8F64_Zero(AA, AB, AC: PDouble;
  AK, AAStride, ACStride: SizeUInt); assembler; nostackframe;
asm
  // RDI=A, RSI=B_packed, RDX=C, RCX=K, R8=A_stride(bytes), R9=C_stride(bytes)
  vxorpd ymm0, ymm0, ymm0
  vxorpd ymm1, ymm1, ymm1
  vxorpd ymm2, ymm2, ymm2
  vxorpd ymm3, ymm3, ymm3
  vxorpd ymm4, ymm4, ymm4
  vxorpd ymm5, ymm5, ymm5
  vxorpd ymm6, ymm6, ymm6
  vxorpd ymm7, ymm7, ymm7

  mov rax, rdi
  lea r10, [rdi + r8]
  lea r11, [r10 + r8]
  push rbx
  lea rbx, [r11 + r8]

  test rcx, rcx
  jz @store_f64

@k_loop_f64:
  vmovupd ymm8, [rsi]
  vmovupd ymm9, [rsi + 32]

  vbroadcastsd ymm10, qword [rax]
  vfmadd231pd ymm0, ymm10, ymm8
  vfmadd231pd ymm1, ymm10, ymm9

  vbroadcastsd ymm10, qword [r10]
  vfmadd231pd ymm2, ymm10, ymm8
  vfmadd231pd ymm3, ymm10, ymm9

  vbroadcastsd ymm10, qword [r11]
  vfmadd231pd ymm4, ymm10, ymm8
  vfmadd231pd ymm5, ymm10, ymm9

  vbroadcastsd ymm10, qword [rbx]
  vfmadd231pd ymm6, ymm10, ymm8
  vfmadd231pd ymm7, ymm10, ymm9

  add rax, 8
  add r10, 8
  add r11, 8
  add rbx, 8
  add rsi, 64

  dec rcx
  jnz @k_loop_f64

@store_f64:
  vmovupd [rdx], ymm0
  vmovupd [rdx + 32], ymm1
  add rdx, r9
  vmovupd [rdx], ymm2
  vmovupd [rdx + 32], ymm3
  add rdx, r9
  vmovupd [rdx], ymm4
  vmovupd [rdx + 32], ymm5
  add rdx, r9
  vmovupd [rdx], ymm6
  vmovupd [rdx + 32], ymm7

  pop rbx
  vzeroupper
end;

procedure GemmMicro4x8F64_Acc(AA, AB, AC: PDouble;
  AK, AAStride, ACStride: SizeUInt); assembler; nostackframe;
asm
  mov rax, rdx
  vmovupd ymm0, [rdx]
  vmovupd ymm1, [rdx + 32]
  add rdx, r9
  vmovupd ymm2, [rdx]
  vmovupd ymm3, [rdx + 32]
  add rdx, r9
  vmovupd ymm4, [rdx]
  vmovupd ymm5, [rdx + 32]
  add rdx, r9
  vmovupd ymm6, [rdx]
  vmovupd ymm7, [rdx + 32]
  mov rdx, rax

  mov rax, rdi
  lea r10, [rdi + r8]
  lea r11, [r10 + r8]
  push rbx
  lea rbx, [r11 + r8]

  test rcx, rcx
  jz @store_f64a

@k_loop_f64a:
  vmovupd ymm8, [rsi]
  vmovupd ymm9, [rsi + 32]

  vbroadcastsd ymm10, qword [rax]
  vfmadd231pd ymm0, ymm10, ymm8
  vfmadd231pd ymm1, ymm10, ymm9

  vbroadcastsd ymm10, qword [r10]
  vfmadd231pd ymm2, ymm10, ymm8
  vfmadd231pd ymm3, ymm10, ymm9

  vbroadcastsd ymm10, qword [r11]
  vfmadd231pd ymm4, ymm10, ymm8
  vfmadd231pd ymm5, ymm10, ymm9

  vbroadcastsd ymm10, qword [rbx]
  vfmadd231pd ymm6, ymm10, ymm8
  vfmadd231pd ymm7, ymm10, ymm9

  add rax, 8
  add r10, 8
  add r11, 8
  add rbx, 8
  add rsi, 64

  dec rcx
  jnz @k_loop_f64a

@store_f64a:
  vmovupd [rdx], ymm0
  vmovupd [rdx + 32], ymm1
  add rdx, r9
  vmovupd [rdx], ymm2
  vmovupd [rdx + 32], ymm3
  add rdx, r9
  vmovupd [rdx], ymm4
  vmovupd [rdx + 32], ymm5
  add rdx, r9
  vmovupd [rdx], ymm6
  vmovupd [rdx + 32], ymm7

  pop rbx
  vzeroupper
end;

procedure GemmBlockedF64(AA, AB, AC: PDouble;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);
var
  LPackedA: PDouble;
  LPackedB: PDouble;
  LCurM, LCurN, LCurK: SizeUInt;
  LBlockM, LBlockN, LBlockK: SizeUInt;
  LMi, LNj, LNj2, LR, LP: SizeUInt;
  LMicroC: PDouble;
  LAStride, LCStride: SizeUInt;
  LBPanelIdx: SizeUInt;
  LSum: Double;
  LCol, LK: SizeUInt;
  LSrc: PDouble;
begin
  if (AM = 0) or (AN = 0) or (AK = 0) then Exit;

  LPackedA := PDouble(SimdAlloc(GEMM_MC_F64 * GEMM_KC_F64 * SizeOf(Double)));
  LPackedB := PDouble(SimdAlloc(GEMM_KC_F64 * GEMM_NC * SizeOf(Double)));

  LCStride := ALdC * SizeOf(Double);

  LCurK := 0;
  while LCurK < AK do
  begin
    LBlockK := AK - LCurK;
    if LBlockK > GEMM_KC_F64 then LBlockK := GEMM_KC_F64;

    LAStride := LBlockK * SizeOf(Double);

    LCurN := 0;
    while LCurN < AN do
    begin
      LBlockN := AN - LCurN;
      if LBlockN > GEMM_NC then LBlockN := GEMM_NC;

      // PackB: B[K,N] row-major → [K, NR_F64] panels
      LCol := 0;
      while LCol + GEMM_NR_F64 <= LBlockN do
      begin
        for LK := 0 to LBlockK - 1 do
        begin
          LSrc := @AA[0]; // dummy, use AB below
          Move(AB[(LCurK + LK) * ALdB + LCurN + LCol],
               LPackedB[(LCol div GEMM_NR_F64) * LBlockK * GEMM_NR_F64 + LK * GEMM_NR_F64],
               GEMM_NR_F64 * SizeOf(Double));
        end;
        Inc(LCol, GEMM_NR_F64);
      end;

      LCurM := 0;
      while LCurM < AM do
      begin
        LBlockM := AM - LCurM;
        if LBlockM > GEMM_MC_F64 then LBlockM := GEMM_MC_F64;

        // PackA: MR_F64 rows of K contiguous
        LMi := 0;
        while LMi + GEMM_MR_F64 <= LBlockM do
        begin
          for LR := 0 to GEMM_MR_F64 - 1 do
            Move(AA[(LCurM + LMi + LR) * ALdA + LCurK],
                 LPackedA[(LMi div GEMM_MR_F64) * GEMM_MR_F64 * LBlockK + LR * LBlockK],
                 LBlockK * SizeOf(Double));
          Inc(LMi, GEMM_MR_F64);
        end;

        // Microkernel calls
        LMi := 0;
        while LMi + GEMM_MR_F64 <= LBlockM do
        begin
          LNj := 0;
          LBPanelIdx := 0;
          while LNj + GEMM_NR_F64 <= LBlockN do
          begin
            LMicroC := @AC[(LCurM + LMi) * ALdC + LCurN + LNj];
            if LCurK = 0 then
              GemmMicro4x8F64_Zero(
                @LPackedA[(LMi div GEMM_MR_F64) * GEMM_MR_F64 * LBlockK],
                @LPackedB[LBPanelIdx],
                LMicroC, LBlockK, LAStride, LCStride)
            else
              GemmMicro4x8F64_Acc(
                @LPackedA[(LMi div GEMM_MR_F64) * GEMM_MR_F64 * LBlockK],
                @LPackedB[LBPanelIdx],
                LMicroC, LBlockK, LAStride, LCStride);
            Inc(LNj, GEMM_NR_F64);
            Inc(LBPanelIdx, LBlockK * GEMM_NR_F64);
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
          Inc(LMi, GEMM_MR_F64);
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

end.
