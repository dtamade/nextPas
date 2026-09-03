{**
 * nextpas.core.graphics.qoi.qoi888 - QOI 纯 Pascal 编解码（<300行, 零依赖, 复用 bytes.ops/bytes.binary）
 * L2，仅 L0-L1 + graphics.errors，inline + 零拷贝 Move。
 * 格式：qoif + W/BE32 + H/BE32 + channels(1) + colorspace(1) + chunks + 7*0+1
 * 编码：index64( hash r*3+g*5+b*7+a*11 mod64 ) + DIFF/LUMA/RUN/RGB/RGBA
 * 解码：fail-closed，16M 像素上限，TryImageDecode不抛由 dispatch 兜底
 *}
unit nextpas.core.graphics.qoi.qoi888;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function QoiEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
function QoiDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
function QoiProbe(const AData: TBytes): Boolean; inline;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.image.base,
  nextpas.core.image.dispatch;

const
  QOI_MAGIC: array[0..3] of Byte = (Ord('q'), Ord('o'), Ord('i'), Ord('f'));
  QOI_OP_INDEX = $00; // 00xxxxxx
  QOI_OP_DIFF  = $40; // 01xxxxxx
  QOI_OP_LUMA  = $80; // 10xxxxxx
  QOI_OP_RUN   = $C0; // 11xxxxxx
  QOI_OP_RGB   = $FE;
  QOI_OP_RGBA  = $FF;
  QOI_MAX_PIXELS = 16 * 1024 * 1024;
  QOI_HEADER = 14;
  QOI_FOOTER = 8;

function QoiHash(R, G, B, A: Byte): Byte; inline;
begin
  Result := Byte((R * 3 + G * 5 + B * 7 + A * 11) mod 64);
end;

function PackRGBA(R, G, B, A: Byte): LongWord; inline;
begin
  Result := (LongWord(R) shl 24) or (LongWord(G) shl 16) or (LongWord(B) shl 8) or LongWord(A);
end;

procedure UnpackRGBA(V: LongWord; out R, G, B, A: Byte); inline;
begin
  R := Byte(V shr 24); G := Byte(V shr 16); B := Byte(V shr 8); A := Byte(V);
end;

function QoiProbe(const AData: TBytes): Boolean; inline;
begin
  Result := (Length(AData) >= QOI_HEADER + QOI_FOOTER) and
    (AData[0]=QOI_MAGIC[0]) and (AData[1]=QOI_MAGIC[1]) and
    (AData[2]=QOI_MAGIC[2]) and (AData[3]=QOI_MAGIC[3]);
end;

function QoiEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
var
  Index: array[0..63] of LongWord;
  PixelCount: SizeUInt;
  MaxSize: SizeUInt;
  Pos: SizeInt;
  I, Run: Integer;
  Prev, Cur: LongWord;
  Pr, Pg, Pb, Pa, Cr, Cg, Cb, Ca: Byte;
  Vr, Vg, Vb, VgR, VgB: Integer;
  Idx: Byte;
begin
  Result := nil;
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentError.Create('qoi: width/height must be > 0');
  if (AWidth > 16384) or (AHeight > 16384) then
    raise EArgumentError.Create('qoi: width/height exceeds 16384 cap');
  PixelCount := SizeUInt(AWidth) * SizeUInt(AHeight);
  if PixelCount > QOI_MAX_PIXELS then
    raise EArgumentError.Create('qoi: pixel count exceeds 16M cap');
  if SizeUInt(Length(APixels)) <> PixelCount * 4 then
    raise EArgumentError.Create('qoi: pixel buffer length mismatch (RGBA)');
  if PixelCount > High(SizeUInt) div 5 then
    raise EArgumentError.Create('qoi: size overflow');
  MaxSize := QOI_HEADER + PixelCount * 5 + QOI_FOOTER;
  if MaxSize > High(SizeInt) then
    raise EArgumentError.Create('qoi: alloc overflow');
  SetLength(Result, MaxSize);
  // header
  Result[0]:=QOI_MAGIC[0]; Result[1]:=QOI_MAGIC[1]; Result[2]:=QOI_MAGIC[2]; Result[3]:=QOI_MAGIC[3];
  WriteUInt32BE(@Result[4], UInt32(AWidth));
  WriteUInt32BE(@Result[8], UInt32(AHeight));
  Result[12]:=4; Result[13]:=0; // channels 4, sRGB
  Pos := QOI_HEADER;
  for I:=0 to 63 do Index[I]:=0;
  Prev := PackRGBA(0,0,0,255);
  Run := 0;
  for I:=0 to Integer(PixelCount)-1 do
  begin
    Cr:=APixels[I*4]; Cg:=APixels[I*4+1]; Cb:=APixels[I*4+2]; Ca:=APixels[I*4+3];
    Cur := PackRGBA(Cr,Cg,Cb,Ca);
    if Cur = Prev then
    begin
      Inc(Run);
      if (Run = 62) or (I = Integer(PixelCount)-1) then
      begin
        Result[Pos] := Byte(QOI_OP_RUN or (Run-1)); Inc(Pos);
        Run := 0;
      end;
      Continue;
    end;
    if Run > 0 then
    begin
      Result[Pos] := Byte(QOI_OP_RUN or (Run-1)); Inc(Pos);
      Run := 0;
    end;
    Idx := QoiHash(Cr,Cg,Cb,Ca);
    if Index[Idx] = Cur then
    begin
      Result[Pos] := Byte(QOI_OP_INDEX or Idx); Inc(Pos);
    end
    else
    begin
      Index[Idx] := Cur;
      UnpackRGBA(Prev, Pr,Pg,Pb,Pa);
      if Ca = Pa then
      begin
        Vr:=Integer(Cr)-Integer(Pr); Vg:=Integer(Cg)-Integer(Pg); Vb:=Integer(Cb)-Integer(Pb);
        VgR:=Vr-Vg; VgB:=Vb-Vg;
        if (Vr>=-2) and (Vr<=1) and (Vg>=-2) and (Vg<=1) and (Vb>=-2) and (Vb<=1) then
        begin
          Result[Pos] := Byte(QOI_OP_DIFF or ((Vr+2) shl 4) or ((Vg+2) shl 2) or (Vb+2)); Inc(Pos);
        end
        else if (Vg>=-32) and (Vg<=31) and (VgR>=-8) and (VgR<=7) and (VgB>=-8) and (VgB<=7) then
        begin
          Result[Pos] := Byte(QOI_OP_LUMA or (Vg+32)); Inc(Pos);
          Result[Pos] := Byte(((VgR+8) shl 4) or (VgB+8)); Inc(Pos);
        end
        else
        begin
          Result[Pos] := QOI_OP_RGB; Inc(Pos);
          Result[Pos] := Cr; Inc(Pos); Result[Pos] := Cg; Inc(Pos); Result[Pos] := Cb; Inc(Pos);
        end;
      end
      else
      begin
        Result[Pos] := QOI_OP_RGBA; Inc(Pos);
        Result[Pos] := Cr; Inc(Pos); Result[Pos] := Cg; Inc(Pos); Result[Pos] := Cb; Inc(Pos); Result[Pos] := Ca; Inc(Pos);
      end;
    end;
    Prev := Cur;
  end;
  if Run > 0 then
  begin
    Result[Pos] := Byte(QOI_OP_RUN or (Run-1)); Inc(Pos);
  end;
  // footer 7 zeros + 1
  BytesZero(@Result[Pos], 7); Inc(Pos,7);
  Result[Pos]:=1; Inc(Pos);
  SetLength(Result, Pos);
end;

function QoiDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
var
  W,H: LongWord;
  Ch, Cs: Byte;
  PixelCount, OutPos, InPos, InLen: SizeUInt;
  Index: array[0..63] of LongWord;
  Prev, Cur: LongWord;
  Pr,Pg,Pb,Pa, R,G,B,A: Byte;
  B1,B2: Byte;
  Run, I: Integer;
  Vg, Vr, Vb: Integer;
begin
  Result := nil; AWidth:=0; AHeight:=0;
  InLen := SizeUInt(Length(AData));
  if InLen < QOI_HEADER + QOI_FOOTER then
    raise EImageDecodeError.Create('qoi: truncated (need header+footer)');
  if not QoiProbe(AData) then
    raise EImageDecodeError.Create('qoi: bad magic');
  W := ReadUInt32BE(@AData[4]);
  H := ReadUInt32BE(@AData[8]);
  Ch := AData[12]; Cs := AData[13];
  if (W=0) or (H=0) or (W>16384) or (H>16384) then
    raise EImageDecodeError.Create('qoi: width/height out of range');
  if not (Ch in [3,4]) then
    raise EImageDecodeError.Create('qoi: unsupported channels (need 3/4)');
  if Cs > 1 then
    raise EImageDecodeError.Create('qoi: unsupported colorspace');
  PixelCount := SizeUInt(W)*SizeUInt(H);
  if PixelCount > QOI_MAX_PIXELS then
    raise EImageDecodeError.Create('qoi: pixel count exceeds 16M cap');
  if InLen > QOI_HEADER + PixelCount*5 + QOI_FOOTER then
    ; // allow but not error
  // footer check
  if (AData[InLen-8]<>0) or (AData[InLen-7]<>0) or (AData[InLen-6]<>0) or (AData[InLen-5]<>0) or
     (AData[InLen-4]<>0) or (AData[InLen-3]<>0) or (AData[InLen-2]<>0) or (AData[InLen-1]<>1) then
    raise EImageDecodeError.Create('qoi: bad footer');
  SetLength(Result, PixelCount*4);
  for I:=0 to 63 do Index[I]:=0;
  Prev := PackRGBA(0,0,0,255);
  OutPos:=0; InPos:=QOI_HEADER; Run:=0;
  while OutPos < PixelCount do
  begin
    if Run > 0 then
    begin
      Dec(Run);
    end
    else
    begin
      if InPos >= InLen-8 then
        raise EImageDecodeError.Create('qoi: truncated chunk');
      B1 := AData[InPos]; Inc(InPos);
      if B1 = QOI_OP_RGB then
      begin
        if InPos+3 > InLen-8 then raise EImageDecodeError.Create('qoi: truncated RGB');
        R:=AData[InPos]; G:=AData[InPos+1]; B:=AData[InPos+2]; InPos+=3;
        UnpackRGBA(Prev, Pr,Pg,Pb,Pa);
        Cur := PackRGBA(R,G,B,Pa);
      end
      else if B1 = QOI_OP_RGBA then
      begin
        if InPos+4 > InLen-8 then raise EImageDecodeError.Create('qoi: truncated RGBA');
        R:=AData[InPos]; G:=AData[InPos+1]; B:=AData[InPos+2]; A:=AData[InPos+3]; InPos+=4;
        Cur := PackRGBA(R,G,B,A);
      end
      else if (B1 and $C0) = QOI_OP_INDEX then
      begin
        Cur := Index[B1 and $3F];
      end
      else if (B1 and $C0) = QOI_OP_DIFF then
      begin
        UnpackRGBA(Prev, Pr,Pg,Pb,Pa);
        R:=Byte(Integer(Pr) + ((B1 shr 4) and $03) -2);
        G:=Byte(Integer(Pg) + ((B1 shr 2) and $03) -2);
        B:=Byte(Integer(Pb) + (B1 and $03) -2);
        Cur := PackRGBA(R,G,B,Pa);
      end
      else if (B1 and $C0) = QOI_OP_LUMA then
      begin
        if InPos >= InLen-8 then raise EImageDecodeError.Create('qoi: truncated LUMA');
        B2:=AData[InPos]; Inc(InPos);
        UnpackRGBA(Prev, Pr,Pg,Pb,Pa);
        Vg:= (B1 and $3F) -32;
        Vr:= Vg + ((B2 shr 4) and $0F) -8;
        Vb:= Vg + (B2 and $0F) -8;
        R:=Byte(Integer(Pr)+Vr); G:=Byte(Integer(Pg)+Vg); B:=Byte(Integer(Pb)+Vb);
        Cur := PackRGBA(R,G,B,Pa);
      end
      else if (B1 and $C0) = QOI_OP_RUN then
      begin
        Run := (B1 and $3F); // run-1, next loop will emit Run+1 incl current?
        // QOI run stores run-1; we already will output Prev for current iter,
        // so set Run to remaining-1 and fall through to output Prev
        Cur := Prev;
        // Run now holds remaining repeats after this one
      end
      else
        raise EImageDecodeError.Create('qoi: invalid tag');
      Prev := Cur;
      if (B1 and $C0) = QOI_OP_RUN then
      begin
        // already set Prev, will loop with Run>0
      end
      else
      begin
        // update index for non-run (spec: index updated for RGB/RGBA/DIFF/LUMA/INDEX? INDEX not)
        if (B1 and $C0) <> QOI_OP_INDEX then
        begin
          UnpackRGBA(Cur,R,G,B,A);
          Index[QoiHash(R,G,B,A)] := Cur;
        end;
      end;
    end;
    // emit Prev to output
    UnpackRGBA(Prev,R,G,B,A);
    if Ch = 3 then A:=255;
    // Ch 3 original had no alpha, but we always emit RGBA with A=255
    Result[OutPos*4]:=R; Result[OutPos*4+1]:=G; Result[OutPos*4+2]:=B; Result[OutPos*4+3]:=A;
    Inc(OutPos);
    // for RUN: also update index? spec says run does not touch index
  end;
  // ensure we consumed up to footer (allow padding)
  AWidth:=Integer(W); AHeight:=Integer(H);
end;

initialization
  ImageRegisterCodec(ifQoi, @QoiProbe, @QoiDecodeRgba, True);

end.
