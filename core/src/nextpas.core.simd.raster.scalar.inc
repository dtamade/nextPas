// scalar fallback for simd.raster — micro-opt: 32-bit store + 4x unroll, pointer batch
// Opt-1 branch prediction: early exits first (PixelCount<=0 / A=0/255) predicted not-taken for hot opaque/large spans.
// Opt-2 pointer increment batch: use PCardinal (4B store) and bulk 4-pixel unroll, one Inc by 16 per iter.
// Opt-3 batch 4/8: hot FillSolid unrolled 4, Blend unrolled 2, halves loop branches.

procedure RasterFillSolid(Dst: PByte; PixelCount: Integer; R, G, B, A: Byte); inline;
var
  LE: LongWord;
  P32: PLongWord;
  N4, Tail: Integer;
begin
  if (PixelCount <= 0) or (Dst = nil) then Exit;
  LE := LongWord(R) or (LongWord(G) shl 8) or (LongWord(B) shl 16) or (LongWord(A) shl 24);
  P32 := PLongWord(Dst);
  // bulk 4 pixels (16 bytes) per iteration — 75% branch reduction vs per-pixel loop
  N4 := PixelCount shr 2;
  Tail := PixelCount and 3;
  while N4 > 0 do
  begin
    P32[0] := LE;
    P32[1] := LE;
    P32[2] := LE;
    P32[3] := LE;
    Inc(P32, 4);
    Dec(N4);
  end;
  case Tail of
    3: begin P32[0]:=LE; P32[1]:=LE; P32[2]:=LE; end;
    2: begin P32[0]:=LE; P32[1]:=LE; end;
    1: P32[0]:=LE;
  end;
end;

{$IFDEF CPUAARCH64}
var
  GRasterNEONCache: Boolean;
  GRasterNEONInited: Boolean = False;
function RasterHasNEON: Boolean; inline;
begin
  if not GRasterNEONInited then
  begin
    GRasterNEONCache := nextpas.core.simd.cpuinfo.HasNEON;
    GRasterNEONInited := True;
  end;
  Result := GRasterNEONCache;
end;

procedure NeonBlend4Bulk(Dst: PByte; BlockCount: Integer; SrcLE: LongWord; A, InvA: Word); assembler; nostackframe;
asm
  cbz w1, .LNB_done
  dup v1.4s, w2
  dup v6.8h, w3
  dup v7.8h, w4
  movi v15.8h, #1
  mov x5, x0
  mov x6, x1
.LNB_loop:
  ld1 {v0.16b}, [x5]
  ushll v2.8h, v0.8b, #0
  ushll2 v3.8h, v0.16b, #0
  ushll v4.8h, v1.8b, #0
  ushll2 v5.8h, v1.16b, #0
  mul v8.8h, v4.8h, v6.8h
  mla v8.8h, v2.8h, v7.8h
  mul v9.8h, v5.8h, v6.8h
  mla v9.8h, v3.8h, v7.8h
  ushr v10.8h, v8.8h, #8
  add v8.8h, v8.8h, v10.8h
  add v8.8h, v8.8h, v15.8h
  ushr v8.8h, v8.8h, #8
  ushr v10.8h, v9.8h, #8
  add v9.8h, v9.8h, v10.8h
  add v9.8h, v9.8h, v15.8h
  ushr v9.8h, v9.8h, #8
  xtn v0.8b, v8.8h
  xtn2 v0.16b, v9.8h
  st1 {v0.16b}, [x5]
  add x5, x5, #16
  subs x6, x6, #1
  b.ne .LNB_loop
.LNB_done:
  ret
end;
{$ENDIF}

procedure RasterBlendSrcOver(Dst: PByte; PixelCount: Integer; R, G, B, A: Byte); inline;
var
  InvA: Integer;
  P: PByte;
{$IFDEF CPUAARCH64}
  N4, Rem, i: Integer;
  SrcLE: LongWord;
  T: Integer;
{$ELSE}
  N2, Rem: Integer;
  T: Integer;
{$ENDIF}
begin
  if (PixelCount <= 0) or (Dst = nil) then Exit;
  if A = 0 then Exit;
  if A = 255 then
  begin
    RasterFillSolid(Dst, PixelCount, R, G, B, A);
    Exit;
  end;
  InvA := 255 - A;
{$IFDEF CPUAARCH64}
  if RasterHasNEON then
  begin
    SrcLE := LongWord(R) or (LongWord(G) shl 8) or (LongWord(B) shl 16) or (LongWord(255) shl 24);
    N4 := PixelCount shr 2;
    Rem := PixelCount and 3;
    if N4 > 0 then
      NeonBlend4Bulk(Dst, N4, SrcLE, Word(A), Word(InvA));
    if Rem <> 0 then
    begin
      P := Dst + (N4 shl 4);
      for i := 0 to Rem - 1 do
      begin
        T := Integer(R) * Integer(A) + Integer(P[0]) * InvA; P[0] := Byte((T + 1 + (T shr 8)) shr 8);
        T := Integer(G) * Integer(A) + Integer(P[1]) * InvA; P[1] := Byte((T + 1 + (T shr 8)) shr 8);
        T := Integer(B) * Integer(A) + Integer(P[2]) * InvA; P[2] := Byte((T + 1 + (T shr 8)) shr 8);
        T := Integer(P[3]) * InvA; P[3] := Byte(Integer(A) + (T + 1 + (T shr 8)) shr 8);
        Inc(P, 4);
      end;
    end;
    Exit;
  end;
  P := Dst;
  N4 := PixelCount shr 1;
  Rem := PixelCount and 1;
  while N4 > 0 do
  begin
    T := Integer(R) * Integer(A) + Integer(P[0]) * InvA; P[0] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(G) * Integer(A) + Integer(P[1]) * InvA; P[1] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(B) * Integer(A) + Integer(P[2]) * InvA; P[2] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(P[3]) * InvA; P[3] := Byte(Integer(A) + (T + 1 + (T shr 8)) shr 8);
    T := Integer(R) * Integer(A) + Integer(P[4]) * InvA; P[4] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(G) * Integer(A) + Integer(P[5]) * InvA; P[5] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(B) * Integer(A) + Integer(P[6]) * InvA; P[6] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(P[7]) * InvA; P[7] := Byte(Integer(A) + (T + 1 + (T shr 8)) shr 8);
    Inc(P, 8);
    Dec(N4);
  end;
  if Rem <> 0 then
  begin
    T := Integer(R) * Integer(A) + Integer(P[0]) * InvA; P[0] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(G) * Integer(A) + Integer(P[1]) * InvA; P[1] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(B) * Integer(A) + Integer(P[2]) * InvA; P[2] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(P[3]) * InvA; P[3] := Byte(Integer(A) + (T + 1 + (T shr 8)) shr 8);
  end;
{$ELSE}
  P := Dst;
  N2 := PixelCount shr 1;
  Rem := PixelCount and 1;
  while N2 > 0 do
  begin
    T := Integer(R) * Integer(A) + Integer(P[0]) * InvA; P[0] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(G) * Integer(A) + Integer(P[1]) * InvA; P[1] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(B) * Integer(A) + Integer(P[2]) * InvA; P[2] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(P[3]) * InvA; P[3] := Byte(Integer(A) + (T + 1 + (T shr 8)) shr 8);
    T := Integer(R) * Integer(A) + Integer(P[4]) * InvA; P[4] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(G) * Integer(A) + Integer(P[5]) * InvA; P[5] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(B) * Integer(A) + Integer(P[6]) * InvA; P[6] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(P[7]) * InvA; P[7] := Byte(Integer(A) + (T + 1 + (T shr 8)) shr 8);
    Inc(P, 8);
    Dec(N2);
  end;
  if Rem <> 0 then
  begin
    T := Integer(R) * Integer(A) + Integer(P[0]) * InvA; P[0] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(G) * Integer(A) + Integer(P[1]) * InvA; P[1] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(B) * Integer(A) + Integer(P[2]) * InvA; P[2] := Byte((T + 1 + (T shr 8)) shr 8);
    T := Integer(P[3]) * InvA; P[3] := Byte(Integer(A) + (T + 1 + (T shr 8)) shr 8);
  end;
{$ENDIF}
end;

procedure RasterRotateRGB(Dst: PByte; PixelCount: Integer); inline;
var
  P: PByte;
  N4, Tail: Integer;
  R, G, B: Byte;
begin
  if (PixelCount <= 0) or (Dst = nil) then Exit;
  P := Dst;
  N4 := PixelCount shr 2;
  Tail := PixelCount and 3;
  while N4 > 0 do
  begin
    R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
    R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
    R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
    R:=P[0]; G:=P[1]; B:=P[2]; P[0]:=G; P[1]:=B; P[2]:=R; Inc(P,4);
    Dec(N4);
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
  N4, Tail: Integer;
begin
  if (PixelCount <= 0) or (Dst = nil) or (Lut = nil) then Exit;
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
  N: Integer;
  col: LongWord;
  R, G, B, A: Byte;
  invA, Tv: Integer;
begin
  if (PixelCount <= 0) or (Dst = nil) or (Src = nil) then Exit;
  P := Dst; S := Src;
  for N := 0 to PixelCount - 1 do
  begin
    col := S[N];
    R := Byte((col shr 16) and $FF);
    G := Byte((col shr 8) and $FF);
    B := Byte(col and $FF);
    A := Byte((col shr 24) and $FF);
    if A = 0 then Continue;
    if A = 255 then
      PLongWord(P)^ := col
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

procedure RasterPremultiply(Dst: PByte; PixelCount: Integer); inline;
var
  P: PByte;
  N4, Tail: Integer;
  A: Byte;
begin
  if (PixelCount <= 0) or (Dst = nil) then Exit;
  P := Dst;
  N4 := PixelCount shr 2;
  Tail := PixelCount and 3;
  while N4 > 0 do
  begin
    A:=P[3]; if A=0 then begin P[0]:=0; P[1]:=0; P[2]:=0; end else if A<>255 then begin P[0]:=Byte((Integer(P[0])*Integer(A)) div 255); P[1]:=Byte((Integer(P[1])*Integer(A)) div 255); P[2]:=Byte((Integer(P[2])*Integer(A)) div 255); end; Inc(P,4);
    A:=P[3]; if A=0 then begin P[0]:=0; P[1]:=0; P[2]:=0; end else if A<>255 then begin P[0]:=Byte((Integer(P[0])*Integer(A)) div 255); P[1]:=Byte((Integer(P[1])*Integer(A)) div 255); P[2]:=Byte((Integer(P[2])*Integer(A)) div 255); end; Inc(P,4);
    A:=P[3]; if A=0 then begin P[0]:=0; P[1]:=0; P[2]:=0; end else if A<>255 then begin P[0]:=Byte((Integer(P[0])*Integer(A)) div 255); P[1]:=Byte((Integer(P[1])*Integer(A)) div 255); P[2]:=Byte((Integer(P[2])*Integer(A)) div 255); end; Inc(P,4);
    A:=P[3]; if A=0 then begin P[0]:=0; P[1]:=0; P[2]:=0; end else if A<>255 then begin P[0]:=Byte((Integer(P[0])*Integer(A)) div 255); P[1]:=Byte((Integer(P[1])*Integer(A)) div 255); P[2]:=Byte((Integer(P[2])*Integer(A)) div 255); end; Inc(P,4);
    Dec(N4);
  end;
  case Tail of
    3: begin A:=P[3]; if A=0 then begin P[0]:=0; P[1]:=0; P[2]:=0; end else if A<>255 then begin P[0]:=Byte((Integer(P[0])*Integer(A)) div 255); P[1]:=Byte((Integer(P[1])*Integer(A)) div 255); P[2]:=Byte((Integer(P[2])*Integer(A)) div 255); end; Inc(P,4);
             A:=P[3]; if A=0 then begin P[0]:=0; P[1]:=0; P[2]:=0; end else if A<>255 then begin P[0]:=Byte((Integer(P[0])*Integer(A)) div 255); P[1]:=Byte((Integer(P[1])*Integer(A)) div 255); P[2]:=Byte((Integer(P[2])*Integer(A)) div 255); end; Inc(P,4);
             A:=P[3]; if A=0 then begin P[0]:=0; P[1]:=0; P[2]:=0; end else if A<>255 then begin P[0]:=Byte((Integer(P[0])*Integer(A)) div 255); P[1]:=Byte((Integer(P[1])*Integer(A)) div 255); P[2]:=Byte((Integer(P[2])*Integer(A)) div 255); end; end;
    2: begin A:=P[3]; if A=0 then begin P[0]:=0; P[1]:=0; P[2]:=0; end else if A<>255 then begin P[0]:=Byte((Integer(P[0])*Integer(A)) div 255); P[1]:=Byte((Integer(P[1])*Integer(A)) div 255); P[2]:=Byte((Integer(P[2])*Integer(A)) div 255); end; Inc(P,4);
             A:=P[3]; if A=0 then begin P[0]:=0; P[1]:=0; P[2]:=0; end else if A<>255 then begin P[0]:=Byte((Integer(P[0])*Integer(A)) div 255); P[1]:=Byte((Integer(P[1])*Integer(A)) div 255); P[2]:=Byte((Integer(P[2])*Integer(A)) div 255); end; end;
    1: begin A:=P[3]; if A=0 then begin P[0]:=0; P[1]:=0; P[2]:=0; end else if A<>255 then begin P[0]:=Byte((Integer(P[0])*Integer(A)) div 255); P[1]:=Byte((Integer(P[1])*Integer(A)) div 255); P[2]:=Byte((Integer(P[2])*Integer(A)) div 255); end; end;
  end;
end;

procedure RasterUnpremultiply(Dst: PByte; PixelCount: Integer); inline;
var
  P: PByte;
  N4, Tail: Integer;
  A: Byte;
begin
  if (PixelCount <= 0) or (Dst = nil) then Exit;
  P := Dst;
  N4 := PixelCount shr 2;
  Tail := PixelCount and 3;
  while N4 > 0 do
  begin
    A:=P[3]; if (A<>0) and (A<>255) then begin P[0]:=Byte((Integer(P[0])*255) div Integer(A)); P[1]:=Byte((Integer(P[1])*255) div Integer(A)); P[2]:=Byte((Integer(P[2])*255) div Integer(A)); end; Inc(P,4);
    A:=P[3]; if (A<>0) and (A<>255) then begin P[0]:=Byte((Integer(P[0])*255) div Integer(A)); P[1]:=Byte((Integer(P[1])*255) div Integer(A)); P[2]:=Byte((Integer(P[2])*255) div Integer(A)); end; Inc(P,4);
    A:=P[3]; if (A<>0) and (A<>255) then begin P[0]:=Byte((Integer(P[0])*255) div Integer(A)); P[1]:=Byte((Integer(P[1])*255) div Integer(A)); P[2]:=Byte((Integer(P[2])*255) div Integer(A)); end; Inc(P,4);
    A:=P[3]; if (A<>0) and (A<>255) then begin P[0]:=Byte((Integer(P[0])*255) div Integer(A)); P[1]:=Byte((Integer(P[1])*255) div Integer(A)); P[2]:=Byte((Integer(P[2])*255) div Integer(A)); end; Inc(P,4);
    Dec(N4);
  end;
  case Tail of
    3: begin A:=P[3]; if (A<>0) and (A<>255) then begin P[0]:=Byte((Integer(P[0])*255) div Integer(A)); P[1]:=Byte((Integer(P[1])*255) div Integer(A)); P[2]:=Byte((Integer(P[2])*255) div Integer(A)); end; Inc(P,4);
             A:=P[3]; if (A<>0) and (A<>255) then begin P[0]:=Byte((Integer(P[0])*255) div Integer(A)); P[1]:=Byte((Integer(P[1])*255) div Integer(A)); P[2]:=Byte((Integer(P[2])*255) div Integer(A)); end; Inc(P,4);
             A:=P[3]; if (A<>0) and (A<>255) then begin P[0]:=Byte((Integer(P[0])*255) div Integer(A)); P[1]:=Byte((Integer(P[1])*255) div Integer(A)); P[2]:=Byte((Integer(P[2])*255) div Integer(A)); end; end;
    2: begin A:=P[3]; if (A<>0) and (A<>255) then begin P[0]:=Byte((Integer(P[0])*255) div Integer(A)); P[1]:=Byte((Integer(P[1])*255) div Integer(A)); P[2]:=Byte((Integer(P[2])*255) div Integer(A)); end; Inc(P,4);
             A:=P[3]; if (A<>0) and (A<>255) then begin P[0]:=Byte((Integer(P[0])*255) div Integer(A)); P[1]:=Byte((Integer(P[1])*255) div Integer(A)); P[2]:=Byte((Integer(P[2])*255) div Integer(A)); end; end;
    1: begin A:=P[3]; if (A<>0) and (A<>255) then begin P[0]:=Byte((Integer(P[0])*255) div Integer(A)); P[1]:=Byte((Integer(P[1])*255) div Integer(A)); P[2]:=Byte((Integer(P[2])*255) div Integer(A)); end; end;
  end;
end;

procedure RasterBlurNormalizeRow(DstRow: PByte; VSumR, VSumG, VSumB, VSumA: PInteger; CntH: PInteger; CntInv: PCardinal; VC: Integer; VCInv: Cardinal; Width: Integer); inline;
var
  X, Total, N4, Tail: Integer;
  InvTotal: Cardinal;
  qR, qG, qB, qA: Cardinal;
  D: PByte;
begin
  if (Width <= 0) or (DstRow = nil) or (VSumR = nil) or (VSumG = nil) or (VSumB = nil) or (VSumA = nil) then Exit;
  if (CntH = nil) or (CntInv = nil) then Exit;
  if VC <= 0 then
  begin
    FillChar(DstRow^, Width * 4, 0);
    Exit;
  end;
  D := DstRow;
  N4 := Width shr 2;
  Tail := Width and 3;
  X := 0;
  while N4 > 0 do
  begin
    Total := CntH[X] * VC;
    if Total = 0 then begin D[0]:=0; D[1]:=0; D[2]:=0; D[3]:=0; end else
    begin
      InvTotal := Cardinal((QWord(CntInv[X]) * QWord(VCInv)) shr 32);
      if InvTotal = 0 then InvTotal := Cardinal((QWord(1) shl 32) div QWord(Cardinal(Total)));
      qR := Cardinal((QWord(Cardinal(VSumR[X])) * QWord(InvTotal)) shr 32);
      if QWord(qR) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumR[X])) then Dec(qR) else if QWord(qR + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumR[X])) then Inc(qR);
      qG := Cardinal((QWord(Cardinal(VSumG[X])) * QWord(InvTotal)) shr 32);
      if QWord(qG) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumG[X])) then Dec(qG) else if QWord(qG + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumG[X])) then Inc(qG);
      qB := Cardinal((QWord(Cardinal(VSumB[X])) * QWord(InvTotal)) shr 32);
      if QWord(qB) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumB[X])) then Dec(qB) else if QWord(qB + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumB[X])) then Inc(qB);
      qA := Cardinal((QWord(Cardinal(VSumA[X])) * QWord(InvTotal)) shr 32);
      if QWord(qA) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumA[X])) then Dec(qA) else if QWord(qA + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumA[X])) then Inc(qA);
      if qR > 255 then qR := 255; if qG > 255 then qG := 255; if qB > 255 then qB := 255; if qA > 255 then qA := 255;
      D[0] := Byte(qR); D[1] := Byte(qG); D[2] := Byte(qB); D[3] := Byte(qA);
    end;
    Inc(D, 4); Inc(X);
    Total := CntH[X] * VC;
    if Total = 0 then begin D[0]:=0; D[1]:=0; D[2]:=0; D[3]:=0; end else
    begin
      InvTotal := Cardinal((QWord(CntInv[X]) * QWord(VCInv)) shr 32);
      if InvTotal = 0 then InvTotal := Cardinal((QWord(1) shl 32) div QWord(Cardinal(Total)));
      qR := Cardinal((QWord(Cardinal(VSumR[X])) * QWord(InvTotal)) shr 32);
      if QWord(qR) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumR[X])) then Dec(qR) else if QWord(qR + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumR[X])) then Inc(qR);
      qG := Cardinal((QWord(Cardinal(VSumG[X])) * QWord(InvTotal)) shr 32);
      if QWord(qG) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumG[X])) then Dec(qG) else if QWord(qG + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumG[X])) then Inc(qG);
      qB := Cardinal((QWord(Cardinal(VSumB[X])) * QWord(InvTotal)) shr 32);
      if QWord(qB) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumB[X])) then Dec(qB) else if QWord(qB + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumB[X])) then Inc(qB);
      qA := Cardinal((QWord(Cardinal(VSumA[X])) * QWord(InvTotal)) shr 32);
      if QWord(qA) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumA[X])) then Dec(qA) else if QWord(qA + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumA[X])) then Inc(qA);
      if qR > 255 then qR := 255; if qG > 255 then qG := 255; if qB > 255 then qB := 255; if qA > 255 then qA := 255;
      D[0] := Byte(qR); D[1] := Byte(qG); D[2] := Byte(qB); D[3] := Byte(qA);
    end;
    Inc(D, 4); Inc(X);
    Total := CntH[X] * VC;
    if Total = 0 then begin D[0]:=0; D[1]:=0; D[2]:=0; D[3]:=0; end else
    begin
      InvTotal := Cardinal((QWord(CntInv[X]) * QWord(VCInv)) shr 32);
      if InvTotal = 0 then InvTotal := Cardinal((QWord(1) shl 32) div QWord(Cardinal(Total)));
      qR := Cardinal((QWord(Cardinal(VSumR[X])) * QWord(InvTotal)) shr 32);
      if QWord(qR) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumR[X])) then Dec(qR) else if QWord(qR + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumR[X])) then Inc(qR);
      qG := Cardinal((QWord(Cardinal(VSumG[X])) * QWord(InvTotal)) shr 32);
      if QWord(qG) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumG[X])) then Dec(qG) else if QWord(qG + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumG[X])) then Inc(qG);
      qB := Cardinal((QWord(Cardinal(VSumB[X])) * QWord(InvTotal)) shr 32);
      if QWord(qB) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumB[X])) then Dec(qB) else if QWord(qB + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumB[X])) then Inc(qB);
      qA := Cardinal((QWord(Cardinal(VSumA[X])) * QWord(InvTotal)) shr 32);
      if QWord(qA) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumA[X])) then Dec(qA) else if QWord(qA + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumA[X])) then Inc(qA);
      if qR > 255 then qR := 255; if qG > 255 then qG := 255; if qB > 255 then qB := 255; if qA > 255 then qA := 255;
      D[0] := Byte(qR); D[1] := Byte(qG); D[2] := Byte(qB); D[3] := Byte(qA);
    end;
    Inc(D, 4); Inc(X);
    Total := CntH[X] * VC;
    if Total = 0 then begin D[0]:=0; D[1]:=0; D[2]:=0; D[3]:=0; end else
    begin
      InvTotal := Cardinal((QWord(CntInv[X]) * QWord(VCInv)) shr 32);
      if InvTotal = 0 then InvTotal := Cardinal((QWord(1) shl 32) div QWord(Cardinal(Total)));
      qR := Cardinal((QWord(Cardinal(VSumR[X])) * QWord(InvTotal)) shr 32);
      if QWord(qR) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumR[X])) then Dec(qR) else if QWord(qR + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumR[X])) then Inc(qR);
      qG := Cardinal((QWord(Cardinal(VSumG[X])) * QWord(InvTotal)) shr 32);
      if QWord(qG) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumG[X])) then Dec(qG) else if QWord(qG + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumG[X])) then Inc(qG);
      qB := Cardinal((QWord(Cardinal(VSumB[X])) * QWord(InvTotal)) shr 32);
      if QWord(qB) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumB[X])) then Dec(qB) else if QWord(qB + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumB[X])) then Inc(qB);
      qA := Cardinal((QWord(Cardinal(VSumA[X])) * QWord(InvTotal)) shr 32);
      if QWord(qA) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumA[X])) then Dec(qA) else if QWord(qA + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumA[X])) then Inc(qA);
      if qR > 255 then qR := 255; if qG > 255 then qG := 255; if qB > 255 then qB := 255; if qA > 255 then qA := 255;
      D[0] := Byte(qR); D[1] := Byte(qG); D[2] := Byte(qB); D[3] := Byte(qA);
    end;
    Inc(D, 4); Inc(X);
    Dec(N4);
  end;
  for Tail := Tail downto 1 do
  begin
    Total := CntH[X] * VC;
    if Total = 0 then begin D[0]:=0; D[1]:=0; D[2]:=0; D[3]:=0; end else
    begin
      InvTotal := Cardinal((QWord(CntInv[X]) * QWord(VCInv)) shr 32);
      if InvTotal = 0 then InvTotal := Cardinal((QWord(1) shl 32) div QWord(Cardinal(Total)));
      qR := Cardinal((QWord(Cardinal(VSumR[X])) * QWord(InvTotal)) shr 32);
      if QWord(qR) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumR[X])) then Dec(qR) else if QWord(qR + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumR[X])) then Inc(qR);
      qG := Cardinal((QWord(Cardinal(VSumG[X])) * QWord(InvTotal)) shr 32);
      if QWord(qG) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumG[X])) then Dec(qG) else if QWord(qG + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumG[X])) then Inc(qG);
      qB := Cardinal((QWord(Cardinal(VSumB[X])) * QWord(InvTotal)) shr 32);
      if QWord(qB) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumB[X])) then Dec(qB) else if QWord(qB + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumB[X])) then Inc(qB);
      qA := Cardinal((QWord(Cardinal(VSumA[X])) * QWord(InvTotal)) shr 32);
      if QWord(qA) * QWord(Cardinal(Total)) > QWord(Cardinal(VSumA[X])) then Dec(qA) else if QWord(qA + 1) * QWord(Cardinal(Total)) <= QWord(Cardinal(VSumA[X])) then Inc(qA);
      if qR > 255 then qR := 255; if qG > 255 then qG := 255; if qB > 255 then qB := 255; if qA > 255 then qA := 255;
      D[0] := Byte(qR); D[1] := Byte(qG); D[2] := Byte(qB); D[3] := Byte(qA);
    end;
    Inc(D, 4); Inc(X);
  end;
end;
