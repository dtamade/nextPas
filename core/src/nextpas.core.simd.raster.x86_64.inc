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
  CRasterBlendShuffle: array[0..15] of Byte = (2,1,0,3,6,5,4,7,10,9,8,11,14,13,12,15);
  CRasterAlphaBC: array[0..15] of Byte = (3,3,3,3,7,7,7,7,11,11,11,11,15,15,15,15);
  CWords255: array[0..7] of Word = (255,255,255,255,255,255,255,255);
  CWords1: array[0..7] of Word = (1,1,1,1,1,1,1,1);
  CWordsFFFF: array[0..7] of Word = ($FFFF,$FFFF,$FFFF,$FFFF,$FFFF,$FFFF,$FFFF,$FFFF);
  CMaskAlphaLo: array[0..7] of Word = (0,0,0,$FFFF,0,0,0,$FFFF);
  CMaskAlphaHi: array[0..7] of Word = (0,0,0,$FFFF,0,0,0,$FFFF);

var
  GRasterAVX2Cache: Boolean;
  GRasterAVX2Inited: Boolean = False;
  GRasterSSSE3Cache: Boolean;
  GRasterSSSE3Inited: Boolean = False;

function RasterHasSSSE3: Boolean; inline;
begin
  if not GRasterSSSE3Inited then
  begin
    GRasterSSSE3Cache := nextpas.core.simd.cpuinfo.HasSSSE3;
    GRasterSSSE3Inited := True;
  end;
  Result := GRasterSSSE3Cache;
end;

function RasterHasAVX2: Boolean; inline;
begin
  if not GRasterAVX2Inited then
  begin
    GRasterAVX2Cache := nextpas.core.simd.cpuinfo.HasAVX2;
    GRasterAVX2Inited := True;
  end;
  Result := GRasterAVX2Cache;
end;

procedure RasterFillSolid(Dst: PByte; PixelCount: Integer; R, G, B, A: Byte); inline;
var
  LE: LongWord;
  UseAVX2: Boolean;
begin
  if (PixelCount <= 0) or (Dst = nil) then Exit;
  LE := LongWord(R) or (LongWord(G) shl 8) or (LongWord(B) shl 16) or (LongWord(A) shl 24);
  if PixelCount < 4 then
  begin
    PLongWord(Dst)^ := LE;
    if PixelCount = 1 then Exit;
    PLongWord(Dst + 4)^ := LE;
    if PixelCount = 2 then Exit;
    PLongWord(Dst + 8)^ := LE;
    Exit;
  end;
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
      vzeroupper
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
      vzeroupper
  end;
end;

procedure RasterBlendSrcOver(Dst: PByte; PixelCount: Integer; R, G, B, A: Byte); inline;
var
  InvA: Integer;
  SrcLE: LongWord;
  WA, WInvA, WOne: array[0..7] of Word;
  i: Integer;
  P: PByte;
  Tail: Integer;
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
      vzeroupper
    end;
    Tail := PixelCount and 7;
    if Tail <> 0 then
    begin
      P := Dst + (PixelCount and not 7)*4;
      if Tail >= 4 then
      begin
        asm
          mov rax, P
          mov edx, SrcLE
          movd xmm1, edx
          pshufd xmm1, xmm1, 0
          movdqu xmm6, dqword ptr [WA]
          movdqu xmm7, dqword ptr [WInvA]
          movdqu xmm4, dqword ptr [WOne]
          pxor xmm5, xmm5
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
          vzeroupper
        end;
        Inc(P, 16);
        Dec(Tail, 4);
      end;
      if Tail <> 0 then
        for i:=0 to Tail-1 do
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
      vzeroupper
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
        vzeroupper
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
      vzeroupper
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

procedure RasterCopySpan(Dst: PByte; Src: PLongWord; PixelCount: Integer); inline;
begin
  if (PixelCount <= 0) or (Dst = nil) or (Src = nil) then Exit;
  Move(Src^, Dst^, NativeUInt(PixelCount) * 4);
end;

procedure RasterBlendVaried(Dst: PByte; Src: PLongWord; PixelCount: Integer); inline;
var
  P: PByte;
  S: PLongWord;
  N, Tail: Integer;
  col: LongWord;
  R, G, B, A: Byte;
  invA, Tv: Integer;
begin
  if (PixelCount <= 0) or (Dst = nil) or (Src = nil) then Exit;
  if PixelCount < 4 then
  begin
    P := Dst; S := Src;
    for N := 0 to PixelCount - 1 do
    begin
      col := S[N];
      R := Byte((col shr 16) and $FF);
      G := Byte((col shr 8) and $FF);
      B := Byte(col and $FF);
      A := Byte((col shr 24) and $FF);
      if A = 0 then begin Inc(P,4); Continue; end;
      if A = 255 then PLongWord(P)^ := col
      else
      begin
        invA := 255 - A;
        Tv := Integer(R) * Integer(A) + Integer(P[0]) * invA; P[0] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
        Tv := Integer(G) * Integer(A) + Integer(P[1]) * invA; P[1] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
        Tv := Integer(B) * Integer(A) + Integer(P[2]) * invA; P[2] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
        Tv := Integer(P[3]) * invA; P[3] := Byte(Integer(A) + (Tv + 1 + (Tv shr 8)) shr 8);
      end;
      Inc(P, 4);
    end;
    Exit;
  end;
  if RasterHasSSSE3 then
  begin
    P := Dst; S := Src;
    N := PixelCount shr 2;
    Tail := PixelCount and 3;
    if N > 0 then
    asm
      mov rax, P
      mov rdx, S
      mov ecx, N
      pxor xmm5, xmm5
      movdqu xmm15, dqword ptr [CRasterBlendShuffle]
      movdqu xmm14, dqword ptr [CRasterAlphaBC]
      movdqu xmm13, dqword ptr [CWords255]
      movdqu xmm12, dqword ptr [CWords1]
    @RBV_LOOP4:
      movdqu xmm0, dqword ptr [rax]
      movdqu xmm1, dqword ptr [rdx]
      pshufb xmm1, xmm15
      movdqa xmm2, xmm1
      pshufb xmm2, xmm14
      movdqa xmm3, xmm2
      punpcklbw xmm3, xmm5
      movdqa xmm4, xmm2
      punpckhbw xmm4, xmm5
      movdqa xmm6, xmm13
      psubw xmm6, xmm3
      movdqa xmm7, xmm13
      psubw xmm7, xmm4
      movdqa xmm8, xmm0
      punpcklbw xmm8, xmm5
      movdqa xmm9, xmm1
      punpcklbw xmm9, xmm5
      movdqa xmm10, xmm0
      punpckhbw xmm10, xmm5
      movdqa xmm11, xmm1
      punpckhbw xmm11, xmm5
      movdqa xmm2, xmm9
      pmullw xmm2, xmm3
      movdqa xmm3, xmm8
      pmullw xmm3, xmm6
      paddw xmm2, xmm3
      movdqa xmm3, xmm2
      psrlw xmm3, 8
      paddw xmm2, xmm3
      paddw xmm2, xmm12
      psrlw xmm2, 8
      movdqa xmm3, xmm11
      pmullw xmm3, xmm4
      movdqa xmm4, xmm10
      pmullw xmm4, xmm7
      paddw xmm3, xmm4
      movdqa xmm4, xmm3
      psrlw xmm4, 8
      paddw xmm3, xmm4
      paddw xmm3, xmm12
      psrlw xmm3, 8
      movdqa xmm4, xmm8
      pmullw xmm4, xmm6
      movdqa xmm6, xmm4
      psrlw xmm6, 8
      paddw xmm4, xmm6
      paddw xmm4, xmm12
      psrlw xmm4, 8
      movdqa xmm6, xmm9
      pand xmm6, dqword ptr [CMaskAlphaLo]
      paddw xmm4, xmm6
      pand xmm4, dqword ptr [CMaskAlphaLo]
      movdqa xmm6, dqword ptr [CMaskAlphaLo]
      pxor xmm6, dqword ptr [CWordsFFFF]
      pand xmm2, xmm6
      por xmm2, xmm4
      movdqa xmm4, xmm10
      pmullw xmm4, xmm7
      movdqa xmm6, xmm4
      psrlw xmm6, 8
      paddw xmm4, xmm6
      paddw xmm4, xmm12
      psrlw xmm4, 8
      movdqa xmm6, xmm11
      pand xmm6, dqword ptr [CMaskAlphaHi]
      paddw xmm4, xmm6
      pand xmm4, dqword ptr [CMaskAlphaHi]
      movdqa xmm6, dqword ptr [CMaskAlphaHi]
      pxor xmm6, dqword ptr [CWordsFFFF]
      pand xmm3, xmm6
      por xmm3, xmm4
      packuswb xmm2, xmm3
      movdqu dqword ptr [rax], xmm2
      add rax, 16
      add rdx, 16
      dec ecx
      jnz @RBV_LOOP4
      vzeroupper
    end;
    Inc(P, N * 16);
    Inc(S, N * 4);
    if Tail <> 0 then
    begin
      for N := 0 to Tail - 1 do
      begin
        col := S[N];
        R := Byte((col shr 16) and $FF);
        G := Byte((col shr 8) and $FF);
        B := Byte(col and $FF);
        A := Byte((col shr 24) and $FF);
        if A = 0 then begin Inc(P,4); Continue; end;
        if A = 255 then PLongWord(P)^ := col
        else
        begin
          invA := 255 - A;
          Tv := Integer(R) * Integer(A) + Integer(P[0]) * invA; P[0] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
          Tv := Integer(G) * Integer(A) + Integer(P[1]) * invA; P[1] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
          Tv := Integer(B) * Integer(A) + Integer(P[2]) * invA; P[2] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
          Tv := Integer(P[3]) * invA; P[3] := Byte(Integer(A) + (Tv + 1 + (Tv shr 8)) shr 8);
        end;
        Inc(P, 4);
      end;
    end;
    Exit;
  end;
  P := Dst; S := Src;
  for N := 0 to PixelCount - 1 do
  begin
    col := S[N];
    R := Byte((col shr 16) and $FF);
    G := Byte((col shr 8) and $FF);
    B := Byte(col and $FF);
    A := Byte((col shr 24) and $FF);
    if A = 0 then begin Inc(P,4); Continue; end;
    if A = 255 then PLongWord(P)^ := col
    else
    begin
      invA := 255 - A;
      Tv := Integer(R) * Integer(A) + Integer(P[0]) * invA; P[0] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
      Tv := Integer(G) * Integer(A) + Integer(P[1]) * invA; P[1] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
      Tv := Integer(B) * Integer(A) + Integer(P[2]) * invA; P[2] := Byte((Tv + 1 + (Tv shr 8)) shr 8);
      Tv := Integer(P[3]) * invA; P[3] := Byte(Integer(A) + (Tv + 1 + (Tv shr 8)) shr 8);
    end;
    Inc(P, 4);
  end;
end;
