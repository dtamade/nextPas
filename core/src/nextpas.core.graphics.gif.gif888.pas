{**
 * nextpas.core.graphics.gif.gif888 - 纯 Pascal GIF87a/89a 首帧解码（LZW 256色）
 * L2，仅 L0-L1，零 RTL。首帧解码，16M cap，TryImageDecode 不抛。
 * Probe 零拷贝：6 字节 "GIF87a"/"GIF89a"。LZW 自含字典 4096，interlace 还原。
 * 复用 bytes.ops 单源（BytesCopy/BytesZero），bytes.binary LE 读，inline 热路径。
 *}
unit nextpas.core.graphics.gif.gif888;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function GifProbe(const AData: TBytes): Boolean; inline;
function GifDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.mem.base,
  nextpas.core.image.base,
  nextpas.core.image.dispatch;

const
  GIF_MAX_PIXELS = 16 * 1024 * 1024;

function GifProbe(const AData: TBytes): Boolean; inline;
begin
  Result := (Length(AData) >= 6) and
    (AData[0] = Ord('G')) and (AData[1] = Ord('I')) and (AData[2] = Ord('F')) and
    (AData[3] = Ord('8')) and (AData[4] in [Ord('7'), Ord('9')]) and (AData[5] = Ord('a'));
end;

procedure RaiseGif(const AMsg: string);
begin
  raise EImageDecodeError.Create('nextpas.core.graphics.gif.gif888.pas: GifDecodeRgba: ' + AMsg);
end;

// LZW 解缠：AComp 为压缩子块聚合，AMin 为最小码长(2..8)，AExpected 为 iw*ih
procedure LzwDecodeIndices(const AComp: TBytes; AMin: Integer; AExpected: Integer; out AOut: TBytes);
var
  ClearCode, EndCode, NextCode, CodeSize, CodeMask: Integer;
  Datum, Bits, Pos: Integer;
  Prev, Code, Cur, Sp, I, OutPos: Integer;
  FirstChar, FirstPrev: Byte;
  Prefix: array[0..4095] of SmallInt;
  Suffix: array[0..4095] of Byte;
  Stack: array[0..4095] of Byte;
begin
  SetLength(AOut, AExpected);
  if AExpected = 0 then Exit;
  if (AMin < 2) or (AMin > 8) then
    RaiseGif('bad lzw min (need 2..8, got ' + IntToStr(Int64(AMin)) + ')');
  ClearCode := 1 shl AMin;
  EndCode := ClearCode + 1;
  NextCode := EndCode + 1;
  CodeSize := AMin + 1;
  CodeMask := (1 shl CodeSize) - 1;
  for I := 0 to ClearCode - 1 do
  begin
    Prefix[I] := -1;
    Suffix[I] := Byte(I);
  end;
  for I := ClearCode to 4095 do
  begin
    Prefix[I] := -1;
    Suffix[I] := 0;
  end;
  Datum := 0; Bits := 0; Pos := 0;
  Prev := -1; OutPos := 0;
  FirstPrev := 0;
  while OutPos < AExpected do
  begin
    while Bits < CodeSize do
    begin
      if Pos >= Length(AComp) then
        RaiseGif('truncated lzw stream (pos=' + IntToStr(Int64(Pos)) + ' need codeSize=' + IntToStr(Int64(CodeSize)) + ')');
      Datum := Datum or (Integer(AComp[Pos]) shl Bits);
      Inc(Pos);
      Inc(Bits, 8);
    end;
    Code := Datum and CodeMask;
    Datum := Datum shr CodeSize;
    Dec(Bits, CodeSize);

    if Code = ClearCode then
    begin
      NextCode := EndCode + 1;
      CodeSize := AMin + 1;
      CodeMask := (1 shl CodeSize) - 1;
      for I := ClearCode to 4095 do
      begin
        Prefix[I] := -1;
        Suffix[I] := 0;
      end;
      Prev := -1;
      Continue;
    end;
    if Code = EndCode then
      Break;
    if (Code < 0) or (Code >= 4096) then
      RaiseGif('bad lzw code (code=' + IntToStr(Int64(Code)) + ')');

    if Code < NextCode then
    begin
      // existing entry: expand to stack reversed
      Sp := 0;
      Cur := Code;
      while True do
      begin
        if Cur < ClearCode then
        begin
          Stack[Sp] := Byte(Cur);
          Inc(Sp);
          Break;
        end;
        if (Cur < 0) or (Cur >= 4096) then
          RaiseGif('bad prefix chain (code=' + IntToStr(Int64(Code)) + ' cur=' + IntToStr(Int64(Cur)) + ')');
        Stack[Sp] := Suffix[Cur];
        Inc(Sp);
        Cur := Prefix[Cur];
        if Sp >= 4096 then
          RaiseGif('lzw stack overflow');
      end;
      FirstChar := Stack[Sp - 1];
      // emit reversed -> correct order
      for I := Sp - 1 downto 0 do
      begin
        if OutPos >= AExpected then
          RaiseGif('lzw output overflow (expected=' + IntToStr(Int64(AExpected)) + ')');
        AOut[OutPos] := Stack[I];
        Inc(OutPos);
      end;
      if Prev <> -1 then
      begin
        if NextCode < 4096 then
        begin
          Prefix[NextCode] := SmallInt(Prev);
          Suffix[NextCode] := FirstChar;
          Inc(NextCode);
          if (NextCode = (1 shl CodeSize)) and (CodeSize < 12) then
          begin
            Inc(CodeSize);
            CodeMask := (1 shl CodeSize) - 1;
          end;
        end;
      end;
      Prev := Code;
      FirstPrev := FirstChar;
    end
    else if Code = NextCode then
    begin
      if Prev = -1 then
        RaiseGif('lzw KwKwK with no prev (code=' + IntToStr(Int64(Code)) + ')');
      FirstChar := FirstPrev;
      // expand prev
      Sp := 0;
      Cur := Prev;
      while True do
      begin
        if Cur < ClearCode then
        begin
          Stack[Sp] := Byte(Cur);
          Inc(Sp);
          Break;
        end;
        Stack[Sp] := Suffix[Cur];
        Inc(Sp);
        Cur := Prefix[Cur];
        if Sp >= 4096 then
          RaiseGif('lzw stack overflow KwKwK');
      end;
      // emit prev sequence
      for I := Sp - 1 downto 0 do
      begin
        if OutPos >= AExpected then
          RaiseGif('lzw output overflow KwKwK');
        AOut[OutPos] := Stack[I];
        Inc(OutPos);
      end;
      if OutPos >= AExpected then
        RaiseGif('lzw output overflow KwKwK append');
      AOut[OutPos] := FirstChar;
      Inc(OutPos);
      if NextCode < 4096 then
      begin
        Prefix[NextCode] := SmallInt(Prev);
        Suffix[NextCode] := FirstChar;
        Inc(NextCode);
        if (NextCode = (1 shl CodeSize)) and (CodeSize < 12) then
        begin
          Inc(CodeSize);
          CodeMask := (1 shl CodeSize) - 1;
        end;
      end;
      Prev := Code;
      FirstPrev := FirstChar;
    end
    else
      RaiseGif('bad lzw code (code=' + IntToStr(Int64(Code)) + ' next=' + IntToStr(Int64(NextCode)) + ')');

    if OutPos > AExpected then
      RaiseGif('lzw output exceeded (out=' + IntToStr(Int64(OutPos)) + ' expected=' + IntToStr(Int64(AExpected)) + ')');
  end;
  if OutPos <> AExpected then
    RaiseGif('lzw size mismatch (got ' + IntToStr(Int64(OutPos)) + ' expected ' + IntToStr(Int64(AExpected)) + ')');
end;

function GifDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
var
  W, H: Word;
  PackedBg, BgIdx: Byte;
  GctFlag: Boolean;
  GctEntries, GctSize: Integer;
  Pos, Len: Integer;
  GCT: TBytes;
  ActivePal: PByte;
  ActiveCount: Integer;
  LCT: TBytes;
  TransFlag: Boolean;
  TransIdx: Byte;
  // image descriptor
  Left, Top, IW, IH: Word;
  PDesc: Byte;
  HasLCT, Interlace: Boolean;
  LctEntries, LctSize, LzwMin: Integer;
  // comp collect
  Comp: TBytes;
  CompTotal, P2, Sz: Integer;
  Dst: PByte;
  // decode indices
  Indices: TBytes;
  // canvas
  Canvas: TBytes;
  CanvasW, CanvasH: Integer;
  X, Y, Idx, PalOff: Integer;
  R, G, B: Byte;
  Alpha: Byte;
  // interlace map
  Map: array of Integer;
  RowY, SrcRow, DstRow: Integer;
  Tmp: Integer;
begin
  AWidth := 0; AHeight := 0;
  Result := nil;
  Len := Length(AData);
  if Len < 13 then
    RaiseGif('truncated header (len=' + IntToStr(Int64(Len)) + ' need>=13)');
  if not GifProbe(AData) then
    RaiseGif('bad signature (need GIF87a/89a)');
  W := ReadUInt16LE(@AData[6]);
  H := ReadUInt16LE(@AData[8]);
  if (W = 0) or (H = 0) then
    RaiseGif('width/height must be > 0 (w=' + IntToStr(Int64(W)) + ' h=' + IntToStr(Int64(H)) + ')');
  if (Integer(W) > 16384) or (Integer(H) > 16384) then
    RaiseGif('width/height exceeds 16384 cap (w=' + IntToStr(Int64(W)) + ' h=' + IntToStr(Int64(H)) + ')');
  if Int64(W) * Int64(H) > GIF_MAX_PIXELS then
    RaiseGif('image too large (w*h=' + IntToStr(Int64(W)*Int64(H)) + ' limit ' + IntToStr(Int64(GIF_MAX_PIXELS)) + ')');
  PackedBg := AData[10];
  BgIdx := AData[11];
  GctFlag := (PackedBg and $80) <> 0;
  GctSize := 0;
  GctEntries := 0;
  Pos := 13;
  if GctFlag then
  begin
    GctEntries := 1 shl ((PackedBg and 7) + 1);
    GctSize := GctEntries * 3;
    if Pos + GctSize > Len then
      RaiseGif('truncated GCT (need ' + IntToStr(Int64(GctSize)) + ' have ' + IntToStr(Int64(Len - Pos)) + ')');
    SetLength(GCT, GctSize);
    // bytes.ops single source copy
    BytesCopy(@GCT[0], @AData[Pos], SizeUInt(GctSize));
    Inc(Pos, GctSize);
  end
  else
    GCT := nil;

  TransFlag := False;
  TransIdx := 0;
  LCT := nil;
  CanvasW := Integer(W);
  CanvasH := Integer(H);
  Indices := nil;
  Comp := nil;
  IW := 0; IH := 0;
  Left := 0; Top := 0;
  HasLCT := False; Interlace := False;
  ActivePal := nil; ActiveCount := 0;

  // scan blocks until first image
  while Pos < Len do
  begin
    if Pos >= Len then
      RaiseGif('truncated block');
    case AData[Pos] of
      $21: // extension
        begin
          Inc(Pos);
          if Pos >= Len then
            RaiseGif('truncated extension label');
          Tmp := AData[Pos]; // label
          Inc(Pos);
          // sub-blocks loop
          while Pos < Len do
          begin
            if Pos >= Len then
              RaiseGif('truncated extension subblock size');
            Sz := AData[Pos];
            Inc(Pos);
            if Sz = 0 then Break;
            if Pos + Sz > Len then
              RaiseGif('truncated extension data (need ' + IntToStr(Int64(Sz)) + ' have ' + IntToStr(Int64(Len - Pos)) + ')');
            if Tmp = $F9 then
            begin
              // Graphic Control Extension: 4 bytes payload
              if Sz = 4 then
              begin
                TransFlag := (AData[Pos] and 1) <> 0;
                TransIdx := AData[Pos + 3];
              end;
            end;
            Inc(Pos, Sz);
          end;
        end;
      $2C: // image descriptor
        begin
          if Pos + 10 > Len then
            RaiseGif('truncated image descriptor');
          Left := ReadUInt16LE(@AData[Pos + 1]);
          Top := ReadUInt16LE(@AData[Pos + 3]);
          IW := ReadUInt16LE(@AData[Pos + 5]);
          IH := ReadUInt16LE(@AData[Pos + 7]);
          PDesc := AData[Pos + 9];
          HasLCT := (PDesc and $80) <> 0;
          Interlace := (PDesc and $40) <> 0;
          if (IW = 0) or (IH = 0) then
            RaiseGif('image size must be > 0 (iw=' + IntToStr(Int64(IW)) + ' ih=' + IntToStr(Int64(IH)) + ')');
          if HasLCT then
          begin
            LctEntries := 1 shl ((PDesc and 7) + 1);
            LctSize := LctEntries * 3;
          end
          else
          begin
            LctEntries := 0;
            LctSize := 0;
          end;
          if Int64(IW) * Int64(IH) > GIF_MAX_PIXELS then
            RaiseGif('image tile too large (iw*ih=' + IntToStr(Int64(IW)*Int64(IH)) + ')');
          if Integer(Left) + Integer(IW) > CanvasW then
            RaiseGif('image left+width exceeds canvas (left=' + IntToStr(Int64(Left)) + ' iw=' + IntToStr(Int64(IW)) + ' canvasW=' + IntToStr(Int64(CanvasW)) + ')');
          if Integer(Top) + Integer(IH) > CanvasH then
            RaiseGif('image top+height exceeds canvas (top=' + IntToStr(Int64(Top)) + ' ih=' + IntToStr(Int64(IH)) + ' canvasH=' + IntToStr(Int64(CanvasH)) + ')');
          Pos := Pos + 10;
          if HasLCT then
          begin
            if Pos + LctSize > Len then
              RaiseGif('truncated LCT');
            SetLength(LCT, LctSize);
            BytesCopy(@LCT[0], @AData[Pos], SizeUInt(LctSize));
            Inc(Pos, LctSize);
            ActivePal := @LCT[0];
            ActiveCount := LctEntries;
          end
          else
          begin
            if GctFlag then
            begin
              ActivePal := @GCT[0];
              ActiveCount := GctEntries;
            end
            else
              RaiseGif('no palette for image');
          end;
          if Pos >= Len then
            RaiseGif('truncated lzw min');
          LzwMin := AData[Pos];
          Inc(Pos);
          // collect subblocks to Comp
          // first pass to compute total
          P2 := Pos;
          CompTotal := 0;
          while P2 < Len do
          begin
            if P2 >= Len then
              RaiseGif('truncated lzw block size');
            Sz := AData[P2];
            Inc(P2);
            if Sz = 0 then Break;
            if P2 + Sz > Len then
              RaiseGif('truncated lzw data (need ' + IntToStr(Int64(Sz)) + ' have ' + IntToStr(Int64(Len - P2)) + ')');
            Inc(CompTotal, Sz);
            Inc(P2, Sz);
          end;
          if P2 > Len then
            RaiseGif('truncated lzw terminator');
          // check terminator present: last sz must be 0
          // P2 now points after terminator; ensure we saw 0
          // recompute by checking previous byte was 0 (already break condition)
          SetLength(Comp, CompTotal);
          // second pass copy via BytesCopy zero-copy per subblock
          Dst := nil;
          if CompTotal > 0 then Dst := @Comp[0];
          P2 := Pos;
          while P2 < Len do
          begin
            Sz := AData[P2];
            Inc(P2);
            if Sz = 0 then Break;
            if Dst <> nil then
            begin
              BytesCopy(Dst, @AData[P2], SizeUInt(Sz));
              Inc(Dst, Sz);
            end;
            Inc(P2, Sz);
          end;
          Pos := P2;
          // LZW decode to indices
          LzwDecodeIndices(Comp, LzwMin, Integer(IW) * Integer(IH), Indices);
          // build canvas RGBA W*H*4
          SetLength(Canvas, CanvasW * CanvasH * 4);
          // fill with background (or black)
          if GctFlag and (Integer(BgIdx) < GctEntries) then
          begin
            R := GCT[Integer(BgIdx) * 3];
            G := GCT[Integer(BgIdx) * 3 + 1];
            B := GCT[Integer(BgIdx) * 3 + 2];
          end
          else
          begin
            R := 0; G := 0; B := 0;
          end;
          // fill canvas: use Bytes ops single source? simple loop with Move per row not needed; do per-pixel loop
          // inline zero-copy not alloc
          for Y := 0 to CanvasH - 1 do
            for X := 0 to CanvasW - 1 do
            begin
              Idx := (Y * CanvasW + X) * 4;
              Canvas[Idx] := R;
              Canvas[Idx + 1] := G;
              Canvas[Idx + 2] := B;
              Canvas[Idx + 3] := $FF;
            end;
          // blit indices to canvas at (Left,Top) with deinterlace
          if Interlace then
          begin
            SetLength(Map, IH);
            Tmp := 0;
            // pass 1: every 8th row 0
            Y := 0;
            while Y < IH do begin Map[Tmp] := Y; Inc(Tmp); Inc(Y, 8); end;
            Y := 4;
            while Y < IH do begin Map[Tmp] := Y; Inc(Tmp); Inc(Y, 8); end;
            Y := 2;
            while Y < IH do begin Map[Tmp] := Y; Inc(Tmp); Inc(Y, 4); end;
            Y := 1;
            while Y < IH do begin Map[Tmp] := Y; Inc(Tmp); Inc(Y, 2); end;
          end
          else
            Map := nil;
          for SrcRow := 0 to Integer(IH) - 1 do
          begin
            if Interlace then
              RowY := Map[SrcRow]
            else
              RowY := SrcRow;
            DstRow := Integer(Top) + RowY;
            for X := 0 to Integer(IW) - 1 do
            begin
              Idx := SrcRow * Integer(IW) + X;
              if (Idx < 0) or (Idx >= Length(Indices)) then
                RaiseGif('index out of range');
              PalOff := Integer(Indices[Idx]);
              if (PalOff < 0) or (PalOff >= ActiveCount) then
                RaiseGif('palette index out of range (idx=' + IntToStr(Int64(PalOff)) + ' count=' + IntToStr(Int64(ActiveCount)) + ')');
              if TransFlag and (PalOff = Integer(TransIdx)) then
                Alpha := 0
              else
                Alpha := $FF;
              R := ActivePal[PalOff * 3];
              G := ActivePal[PalOff * 3 + 1];
              B := ActivePal[PalOff * 3 + 2];
              Idx := (DstRow * CanvasW + Integer(Left) + X) * 4;
              Canvas[Idx] := R;
              Canvas[Idx + 1] := G;
              Canvas[Idx + 2] := B;
              Canvas[Idx + 3] := Alpha;
            end;
          end;
          AWidth := CanvasW;
          AHeight := CanvasH;
          Result := Canvas;
          Exit;
        end;
      $3B: // trailer
        begin
          RaiseGif('missing image descriptor');
        end;
      else
        RaiseGif('bad block type ' + IntToStr(Int64(AData[Pos])) + ' at ' + IntToStr(Int64(Pos)));
    end;
  end;
  RaiseGif('missing image descriptor');
end;

initialization
  ImageRegisterCodec(ifGif, @GifProbe, @GifDecodeRgba, True);

end.
