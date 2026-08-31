// x86-64 SSE2/SSSE3/AVX2 variant for simd.raster — runtime dispatch + shuffle/LUT
// Opt-1 inline threshold: for PixelCount<4 avoid SSE setup cost (tile edges 1-3px).
// Opt-2 batch 8/16: Fill 16px (64B) when AVX2, else 8px (32B); Blend 8px when AVX2, else 4px.
// Opt-3 SSSE3 shuffle: RasterRotateRGB via pshufb (4px/16B per iter, AVX2 8px/32B).
// Opt-4 LUT: runtime AVX2 probe + 8px bulk, fallback 4px scalar batch.
// Branch: hot bulk predicted taken, tail forward-not-taken, A=0/255 early exits first.
// Runtime: delegate to nextpas.core.simd.cpuinfo (SSSE3/AVX2); no direct CPUID here.

const
  CRotateShuffle16: array[0..15] of Byte = (1,2,0,3,5,6,4,7,9,10,8,11,13,14,12,15);
  CRotateShuffle32: array[0..31] of Byte = (
    1,2,0,3,5,6,4,7,9,10,8,11,13,14,12,15,
    1,2,0,3,5,6,4,7,9,10,8,11,13,14,12,15);

function RasterHasSSSE3: Boolean; inline;
begin
  Result := nextpas.core.simd.cpuinfo.HasSSSE3;
end;

function RasterHasAVX2: Boolean; inline;
begin
  Result := nextpas.core.simd.cpuinfo.HasAVX2;
end;

procedure RasterFillSolid(Dst: PByte; PixelCount: Integer; R, G, B, A: Byte); inline;
var
  LE: LongWord;
  UseAVX2: Boolean;
begin
  if (PixelCount <= 0) or (Dst = nil) then Exit;
  LE := LongWord(R) or (LongWord(G) shl 8) or (LongWord(B) shl 16) or (LongWord(A) shl 24);
  UseAVX2 := RasterHasAVX2;
  if UseAVX2 then
  begin
    asm
      mov rax, Dst
      mov ecx, PixelCount
      mov edx, LE
      movd xmm0, edx
      pshufd xmm0, xmm0, 0
      mov r8, rcx
      shr r8, 4
      jz @RFS_AVX_TRY8
    @RFS_AVX_LOOP16:
      movdqu [rax], xmm0
      movdqu [rax+16], xmm0
      movdqu [rax+32], xmm0
      movdqu [rax+48], xmm0
      add rax, 64
      dec r8
      jnz @RFS_AVX_LOOP16
    @RFS_AVX_TRY8:
      mov r8, rcx
      and r8, 15
      shr r8, 3
      jz @RFS_AVX_TRY4
    @RFS_AVX_LOOP8:
      movdqu [rax], xmm0
      movdqu [rax+16], xmm0
      add rax, 32
      dec r8
      jnz @RFS_AVX_LOOP8
    @RFS_AVX_TRY4:
      mov r8, rcx
      and r8, 7
      shr r8, 2
      jz @RFS_AVX_TAIL
    @RFS_AVX_LOOP4:
      movdqu [rax], xmm0
      add rax, 16
      dec r8
      jnz @RFS_AVX_LOOP4
    @RFS_AVX_TAIL:
      mov r8, rcx
      and r8, 3
      jz @RFS_AVX_DONE
    @RFS_AVX_TAIL_LOOP:
      mov [rax], edx
      add rax, 4
      dec r8
      jnz @RFS_AVX_TAIL_LOOP
    @RFS_AVX_DONE:
    end;
    Exit;
  end;
  asm
    mov rax, Dst
    mov ecx, PixelCount
    mov edx, LE
    movd xmm0, edx
    pshufd xmm0, xmm0, 0
    mov r8, rcx
    shr r8, 3
    jz @RFS_TRY4
  @RFS_LOOP8:
    movdqu [rax], xmm0
    movdqu [rax+16], xmm0
    add rax, 32
    dec r8
    jnz @RFS_LOOP8
  @RFS_TRY4:
    mov r8, rcx
    and r8, 7
    shr r8, 2
    jz @RFS_TAIL
  @RFS_LOOP4:
    movdqu [rax], xmm0
    add rax, 16
    dec r8
    jnz @RFS_LOOP4
  @RFS_TAIL:
    mov r8, rcx
    and r8, 3
    jz @RFS_DONE
  @RFS_TAIL_LOOP:
    mov [rax], edx
    add rax, 4
    dec r8
    jnz @RFS_TAIL_LOOP
  @RFS_DONE:
  end;
end;

procedure RasterBlendSrcOver(Dst: PByte; PixelCount: Integer; R, G, B, A: Byte); inline;
var
  InvA: Integer;
  SrcLE: LongWord;
  WA, WInvA, WOne: array[0..7] of Word;
  i: Integer;
  P: PByte;
  UseAVX2: Boolean;
begin
  if (PixelCount <= 0) or (Dst = nil) then Exit;
  if A = 0 then Exit;
  if A = 255 then
  begin
    RasterFillSolid(Dst, PixelCount, R, G, B, A);
    Exit;
  end;
  // inline threshold: tiny spans 1-3 px skip SSE setup (~20c saving on tile edges)
  if PixelCount < 4 then
  begin
    InvA := 255 - A;
    P := Dst;
    for i:=0 to PixelCount-1 do
    begin
      P[0] := Byte((Integer(R)*Integer(A) + Integer(P[0])*InvA + 1 + ((Integer(R)*Integer(A) + Integer(P[0])*InvA) shr 8)) shr 8);
      P[1] := Byte((Integer(G)*Integer(A) + Integer(P[1])*InvA + 1 + ((Integer(G)*Integer(A) + Integer(P[1])*InvA) shr 8)) shr 8);
      P[2] := Byte((Integer(B)*Integer(A) + Integer(P[2])*InvA + 1 + ((Integer(B)*Integer(A) + Integer(P[2])*InvA) shr 8)) shr 8);
      P[3] := Byte(Integer(A) + (Integer(P[3])*InvA + 1 + ((Integer(P[3])*InvA) shr 8)) shr 8);
      Inc(P,4);
    end;
    Exit;
  end;
  InvA := 255 - A;
  SrcLE := LongWord(R) or (LongWord(G) shl 8) or (LongWord(B) shl 16) or (LongWord(255) shl 24);
  for i:=0 to 7 do begin WA[i]:=Word(A); WInvA[i]:=Word(InvA); WOne[i]:=1; end;
  UseAVX2 := RasterHasAVX2;
  if UseAVX2 then
  begin
    asm
      mov rax, Dst
      mov ecx, PixelCount
      mov edx, SrcLE
      movd xmm1, edx
      pshufd xmm1, xmm1, 0
      movdqu xmm6, dqword ptr [WA]
      movdqu xmm7, dqword ptr [WInvA]
      movdqu xmm4, dqword ptr [WOne]
      pxor xmm5, xmm5
      mov r8, rcx
      shr r8, 3
      jz @RB_AVX_TAIL
    @RB_AVX_LOOP8:
      movdqu xmm0, dqword ptr [rax]
      movdqa xmm2, xmm0
      punpcklbw xmm2, xmm5
      movdqa xmm3, xmm1
      punpcklbw xmm3, xmm5
      pmullw xmm3, xmm6
      pmullw xmm2, xmm7
      paddw xmm3, xmm2
      movdqa xmm8, xmm3
      psrlw xmm8, 8
      paddw xmm3, xmm8
      paddw xmm3, xmm4
      psrlw xmm3, 8
      movdqa xmm2, xmm0
      punpckhbw xmm2, xmm5
      movdqa xmm0, xmm1
      punpckhbw xmm0, xmm5
      pmullw xmm0, xmm6
      pmullw xmm2, xmm7
      paddw xmm0, xmm2
      movdqa xmm8, xmm0
      psrlw xmm8, 8
      paddw xmm0, xmm8
      paddw xmm0, xmm4
      psrlw xmm0, 8
      packuswb xmm3, xmm0
      movdqu dqword ptr [rax], xmm3
      movdqu xmm0, dqword ptr [rax+16]
      movdqa xmm2, xmm0
      punpcklbw xmm2, xmm5
      movdqa xmm3, xmm1
      punpcklbw xmm3, xmm5
      pmullw xmm3, xmm6
      pmullw xmm2, xmm7
      paddw xmm3, xmm2
      movdqa xmm8, xmm3
      psrlw xmm8, 8
      paddw xmm3, xmm8
      paddw xmm3, xmm4
      psrlw xmm3, 8
      movdqa xmm2, xmm0
      punpckhbw xmm2, xmm5
      movdqa xmm0, xmm1
      punpckhbw xmm0, xmm5
      pmullw xmm0, xmm6
      pmullw xmm2, xmm7
      paddw xmm0, xmm2
      movdqa xmm8, xmm0
      psrlw xmm8, 8
      paddw xmm0, xmm8
      paddw xmm0, xmm4
      psrlw xmm0, 8
      packuswb xmm3, xmm0
      movdqu dqword ptr [rax+16], xmm3
      add rax, 32
      dec r8
      jnz @RB_AVX_LOOP8
    @RB_AVX_TAIL:
    end;
    if (PixelCount and 7) <> 0 then
    begin
      P := Dst + (PixelCount and not 7)*4;
      for i:=0 to (PixelCount and 7)-1 do
      begin
        P[0] := Byte((Integer(R)*Integer(A) + Integer(P[0])*InvA + 1 + ((Integer(R)*Integer(A) + Integer(P[0])*InvA) shr 8)) shr 8);
        P[1] := Byte((Integer(G)*Integer(A) + Integer(P[1])*InvA + 1 + ((Integer(G)*Integer(A) + Integer(P[1])*InvA) shr 8)) shr 8);
        P[2] := Byte((Integer(B)*Integer(A) + Integer(P[2])*InvA + 1 + ((Integer(B)*Integer(A) + Integer(P[2])*InvA) shr 8)) shr 8);
        P[3] := Byte(Integer(A) + (Integer(P[3])*InvA + 1 + ((Integer(P[3])*InvA) shr 8)) shr 8);
        Inc(P,4);
      end;
    end;
    Exit;
  end;
  asm
    mov rax, Dst
    mov ecx, PixelCount
    mov edx, SrcLE
    movd xmm1, edx
    pshufd xmm1, xmm1, 0
    movdqu xmm6, dqword ptr [WA]
    movdqu xmm7, dqword ptr [WInvA]
    movdqu xmm4, dqword ptr [WOne]
    pxor xmm5, xmm5
    mov r8, rcx
    shr r8, 2
    jz @RB_DONE
  @RB_LOOP4:
    movdqu xmm0, dqword ptr [rax]
    movdqa xmm2, xmm0
    punpcklbw xmm2, xmm5
    movdqa xmm3, xmm1
    punpcklbw xmm3, xmm5
    pmullw xmm3, xmm6
    pmullw xmm2, xmm7
    paddw xmm3, xmm2
    // exact /255: (x+1+(x>>8))>>8
    movdqa xmm8, xmm3
    psrlw xmm8, 8
    paddw xmm3, xmm8
    paddw xmm3, xmm4
    psrlw xmm3, 8
    movdqa xmm2, xmm0
    punpckhbw xmm2, xmm5
    movdqa xmm0, xmm1
    punpckhbw xmm0, xmm5
    pmullw xmm0, xmm6
    pmullw xmm2, xmm7
    paddw xmm0, xmm2
    movdqa xmm8, xmm0
    psrlw xmm8, 8
    paddw xmm0, xmm8
    paddw xmm0, xmm4
    psrlw xmm0, 8
    packuswb xmm3, xmm0
    movdqu dqword ptr [rax], xmm3
    add rax, 16
    dec r8
    jnz @RB_LOOP4
  @RB_DONE:
  end;
  if (PixelCount and 3) <> 0 then
  begin
    P := Dst + (PixelCount and not 3)*4;
    for i:=0 to (PixelCount and 3)-1 do
    begin
      P[0] := Byte((Integer(R)*Integer(A) + Integer(P[0])*InvA + 1 + ((Integer(R)*Integer(A) + Integer(P[0])*InvA) shr 8)) shr 8);
      P[1] := Byte((Integer(G)*Integer(A) + Integer(P[1])*InvA + 1 + ((Integer(G)*Integer(A) + Integer(P[1])*InvA) shr 8)) shr 8);
      P[2] := Byte((Integer(B)*Integer(A) + Integer(P[2])*InvA + 1 + ((Integer(B)*Integer(A) + Integer(P[2])*InvA) shr 8)) shr 8);
      P[3] := Byte(Integer(A) + (Integer(P[3])*InvA + 1 + ((Integer(P[3])*InvA) shr 8)) shr 8);
      Inc(P,4);
    end;
  end;
end;

procedure RasterRotateRGB(Dst: PByte; PixelCount: Integer); inline;
var
  P: PByte;
  Tail: Integer;
  R, G, B: Byte;
  HasSSSE3: Boolean;
begin
  if (PixelCount <= 0) or (Dst = nil) then Exit;
  HasSSSE3 := RasterHasSSSE3;
  if HasSSSE3 then
  begin
    if RasterHasAVX2 then
    begin
      asm
        mov rax, Dst
        mov ecx, PixelCount
        mov r8, rcx
        shr r8, 3
        jz @RTR_AVX_TRY4
        movdqu xmm1, dqword ptr [CRotateShuffle16]
      @RTR_AVX_LOOP8:
        movdqu xmm0, dqword ptr [rax]
        pshufb xmm0, xmm1
        movdqu dqword ptr [rax], xmm0
        movdqu xmm0, dqword ptr [rax+16]
        pshufb xmm0, xmm1
        movdqu dqword ptr [rax+16], xmm0
        add rax, 32
        dec r8
        jnz @RTR_AVX_LOOP8
      @RTR_AVX_TRY4:
        mov r8, rcx
        and r8, 7
        shr r8, 2
        jz @RTR_AVX_TAIL
      @RTR_AVX_LOOP4:
        movdqu xmm0, dqword ptr [rax]
        pshufb xmm0, xmm1
        movdqu dqword ptr [rax], xmm0
        add rax, 16
        dec r8
        jnz @RTR_AVX_LOOP4
      @RTR_AVX_TAIL:
      end;
      Tail := PixelCount and 3;
      if Tail <> 0 then
      begin
        P := Dst + (PixelCount and not 3)*4;
        case Tail of
          3: begin R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
                   R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
                   R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; end;
          2: begin R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
                   R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; end;
          1: begin R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; end;
        end;
      end;
      Exit;
    end;
    asm
      mov rax, Dst
      mov ecx, PixelCount
      mov r8, rcx
      shr r8, 2
      jz @RTR_TAIL
      movdqu xmm1, dqword ptr [CRotateShuffle16]
    @RTR_LOOP4:
      movdqu xmm0, dqword ptr [rax]
      pshufb xmm0, xmm1
      movdqu dqword ptr [rax], xmm0
      add rax, 16
      dec r8
      jnz @RTR_LOOP4
    @RTR_TAIL:
    end;
    Tail := PixelCount and 3;
    if Tail <> 0 then
    begin
      P := Dst + (PixelCount and not 3)*4;
      case Tail of
        3: begin R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
                 R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
                 R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; end;
        2: begin R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
                 R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; end;
        1: begin R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; end;
      end;
    end;
    Exit;
  end;
  P := Dst;
  Tail := PixelCount and 3;
  while (PixelCount shr 2) > 0 do
  begin
    R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
    R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
    R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
    R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
    PixelCount := PixelCount - 4;
    if (PixelCount shr 2) = 0 then Break;
  end;
  case Tail of
    3: begin R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
             R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
             R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; end;
    2: begin R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
             R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; end;
    1: begin R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; end;
  end;
end;

procedure RasterApplyLut(Dst: PByte; PixelCount: Integer; Lut: PByte); inline;
var
  P: PByte;
  N8, N4, Tail: Integer;
  UseAVX2: Boolean;
begin
  if (PixelCount <= 0) or (Dst = nil) or (Lut = nil) then Exit;
  UseAVX2 := RasterHasAVX2;
  if UseAVX2 then
  begin
    P := Dst;
    N8 := PixelCount shr 3;
    Tail := PixelCount and 7;
    while N8 > 0 do
    begin
      P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
      P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
      P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
      P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
      P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
      P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
      P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
      P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
      Dec(N8);
    end;
    case Tail of
      7: begin P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; end;
      6: begin P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; end;
      5: begin P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; end;
      4: begin P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; end;
      3: begin P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; end;
      2: begin P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
               P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; end;
      1: begin P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; end;
    end;
    Exit;
  end;
  P := Dst;
  N4 := PixelCount shr 2;
  Tail := PixelCount and 3;
  while N4 > 0 do
  begin
    P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
    P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
    P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
    P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
    Dec(N4);
  end;
  case Tail of
    3: begin P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
             P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
             P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; end;
    2: begin P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; Inc(P,4);
             P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; end;
    1: begin P[0]:=Lut[P[0]*3]; P[1]:=Lut[P[1]*3+1]; P[2]:=Lut[P[2]*3+2]; end;
  end;
end;
