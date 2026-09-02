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

procedure RasterBlendSrcOver(Dst: PByte; PixelCount: Integer; R, G, B, A: Byte); inline;
var
  InvA: Integer;
  P: PByte;
  N2, Rem: Integer;
  T: Integer;
begin
  if (PixelCount <= 0) or (Dst = nil) then Exit;
  if A = 0 then Exit;
  if A = 255 then
  begin
    RasterFillSolid(Dst, PixelCount, R, G, B, A);
    Exit;
  end;
  InvA := 255 - A;
  P := Dst;
{$IFDEF CPUAARCH64}
  // NEON branch — AArch64 scalar precise with NEON naming, matches x86 (x+1+(x>>8))>>8
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
{$ELSE}
  // scalar precise (x+1+(x>>8))>>8 matches SSE/AVX exact path
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
