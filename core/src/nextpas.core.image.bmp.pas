{**
 * nextpas.core.image.bmp - 纯 Pascal BMP 编解码（BI_RGB，32/24/8-bit）
 * 行序自下而上，行对齐 4 字节。编码固定 32-bit BI_RGB（$AARRGGBB→BGRA，零 SysUtils）。
 * 解码支持 32/24 位 + 8 位灰度；不支持 RLE/位掩码压缩（fail-closed）。
 *}
unit nextpas.core.image.bmp;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function BmpEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
function BmpDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.bytes.binary,
  nextpas.core.mem.base,
  nextpas.core.image.base,
  nextpas.core.image.dispatch;

procedure PutLe16(ABuf: PByte; AVal: Word); inline;
begin
  WriteUInt16LE(ABuf, AVal);
end;

procedure PutLe32(ABuf: PByte; AVal: LongWord); inline;
begin
  WriteUInt32LE(ABuf, UInt32(AVal));
end;

function GetLe16(ABuf: PByte): Word; inline;
begin
  Result := ReadUInt16LE(ABuf);
end;

function GetLe32(ABuf: PByte): LongWord; inline;
begin
  Result := LongWord(ReadUInt32LE(ABuf));
end;

function BmpEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
var
  RowBytesU, FileSizeU: SizeUInt;
  OffBits: LongWord;
  PixelLen: SizeUInt;
  I, J: Integer;
  P: PByte;
begin
  Result := nil;
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentError.Create('bmp: width/height must be > 0');
  if (AWidth > 16384) or (AHeight > 16384) then
    raise EArgumentError.Create('bmp: width/height exceeds 16384 cap');
  PixelLen := SizeUInt(AWidth) * SizeUInt(AHeight) * 4;
  if (AWidth <> 0) and (PixelLen div SizeUInt(AWidth) div 4 <> SizeUInt(AHeight)) then
    raise EArgumentError.Create('bmp: width*height*4 overflow');
  if SizeUInt(Length(APixels)) <> PixelLen then
    raise EArgumentError.Create('bmp: pixel buffer length mismatch (RGBA)');
  RowBytesU := SizeUInt(AWidth) * 4;
  RowBytesU := AlignUp(RowBytesU, 4);
  if RowBytesU = 0 then
    raise EArgumentError.Create('bmp: RowBytes AlignUp overflow');
  if RowBytesU > High(SizeUInt) div SizeUInt(AHeight) then
    raise EArgumentError.Create('bmp: RowBytes*Height overflow');
  FileSizeU := 14 + 40 + RowBytesU * SizeUInt(AHeight);
  if FileSizeU > High(SizeInt) then
    raise EArgumentError.Create('bmp: file size exceeds limit');
  OffBits := 14 + 40;
  SetLength(Result, FileSizeU);
  P := @Result[0];
  // BITMAPFILEHEADER 14B: 'BM' + fileSize + reserved + offBits
  P[0] := Ord('B'); P[1] := Ord('M');
  PutLe32(@P[2], LongWord(FileSizeU));
  PutLe32(@P[6], 0);
  PutLe32(@P[10], OffBits);
  // BITMAPINFOHEADER 40B
  PutLe32(@P[14], 40);
  PutLe32(@P[18], LongWord(AWidth));
  PutLe32(@P[22], LongWord(AHeight));
  PutLe16(@P[26], 1); // planes
  PutLe16(@P[28], 32); // bitCount
  PutLe32(@P[30], 0); // BI_RGB
  PutLe32(@P[34], LongWord(RowBytesU * SizeUInt(AHeight))); // imageSize
  PutLe32(@P[38], 2835); PutLe32(@P[42], 2835); // 72 DPI ppm
  PutLe32(@P[46], 0); PutLe32(@P[50], 0);
  // pixel data bottom-up, BGRA per pixel
  P := @Result[OffBits];
  for I := AHeight - 1 downto 0 do
    for J := 0 to AWidth - 1 do
    begin
      // APixels is RGBA top-down
      P[0] := APixels[(I * AWidth + J) * 4 + 2]; // B
      P[1] := APixels[(I * AWidth + J) * 4 + 1]; // G
      P[2] := APixels[(I * AWidth + J) * 4];     // R
      P[3] := APixels[(I * AWidth + J) * 4 + 3]; // A
      Inc(P, 4);
    end;
end;

function BmpDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
var
  FileSize, OffBits, InfoSize, W, H, Bpp, Comp: LongWord;
  Planes: Word;
  RowPad, SrcRowBytes, X, Y: Integer;
  Src: PByte;
  TopDown: Boolean;
begin
  Result := nil;
  AWidth := 0; AHeight := 0;
  if Length(AData) < 54 then
    raise EImageDecodeError.Create('bmp: truncated header');
  Src := @AData[0];
  if (Src[0] <> Ord('B')) or (Src[1] <> Ord('M')) then
    raise EImageDecodeError.Create('bmp: bad signature');
  FileSize := GetLe32(@Src[2]);
  if FileSize <> LongWord(Length(AData)) then
    // allow mismatch tolerant but warn: we use Length as truth
    ;
  OffBits := GetLe32(@Src[10]);
  InfoSize := GetLe32(@Src[14]);
  if InfoSize < 40 then
    raise EImageDecodeError.Create('bmp: unsupported DIB header');
  W := GetLe32(@Src[18]);
  H := GetLe32(@Src[22]);
  // BMP height signed: negative = top-down
  TopDown := False;
  if LongInt(H) < 0 then
  begin
    TopDown := True;
    H := LongWord(-LongInt(H));
  end;
  if (W = 0) or (H = 0) or (W > 16384) or (H > 16384) then
    raise EImageDecodeError.Create('bmp: width/height out of range');
  if Int64(W) * Int64(H) > 16 * 1024 * 1024 then
    raise EImageDecodeError.Create('bmp: image too large (16M cap) (w=' + IntToStr(Int64(W)) + ' h=' + IntToStr(Int64(H)) + ')');
  Planes := GetLe16(@Src[26]);
  Bpp := GetLe16(@Src[28]);
  Comp := GetLe32(@Src[30]);
  if Planes <> 1 then
    raise EImageDecodeError.Create('bmp: planes != 1');
  if Comp <> 0 then
    raise EImageDecodeError.Create('bmp: compressed BMP not supported (need BI_RGB)');
  if not (Bpp in [8, 24, 32]) then
    raise EImageDecodeError.Create('bmp: unsupported bpp (need 8/24/32)');
  if OffBits >= LongWord(Length(AData)) then
    raise EImageDecodeError.Create('bmp: bad offBits');
  // row stride padded to 4
  if Bpp = 32 then SrcRowBytes := Integer(W) * 4
  else if Bpp = 24 then SrcRowBytes := Integer(W) * 3
  else SrcRowBytes := Integer(W);
  RowPad := (4 - (SrcRowBytes mod 4)) mod 4;
  SrcRowBytes := SrcRowBytes + RowPad;
  if LongWord(SrcRowBytes) * H + OffBits > LongWord(Length(AData)) then
    raise EImageDecodeError.Create('bmp: truncated pixel data');
  AWidth := Integer(W);
  AHeight := Integer(H);
  SetLength(Result, AWidth * AHeight * 4);
  if (Bpp = 8) and (OffBits < 54) then
    raise EImageDecodeError.Create('bmp: bad palette offset');
  for Y := 0 to AHeight - 1 do
  begin
    Src := @AData[OffBits + (AHeight - 1 - Y) * SrcRowBytes];
    if TopDown then
      Src := @AData[OffBits + Y * SrcRowBytes];
    for X := 0 to AWidth - 1 do
    begin
      case Bpp of
        32:
        begin
          Result[(Y * AWidth + X) * 4 + 2] := Src[X * 4 + 0];
          Result[(Y * AWidth + X) * 4 + 1] := Src[X * 4 + 1];
          Result[(Y * AWidth + X) * 4 + 0] := Src[X * 4 + 2];
          Result[(Y * AWidth + X) * 4 + 3] := Src[X * 4 + 3];
        end;
        24:
        begin
          Result[(Y * AWidth + X) * 4 + 2] := Src[X * 3 + 0];
          Result[(Y * AWidth + X) * 4 + 1] := Src[X * 3 + 1];
          Result[(Y * AWidth + X) * 4 + 0] := Src[X * 3 + 2];
          Result[(Y * AWidth + X) * 4 + 3] := $FF;
        end;
        8:
        begin
          if OffBits >= 54 + 1024 then
          begin
            Result[(Y * AWidth + X) * 4 + 2] := AData[54 + Integer(Src[X]) * 4 + 0];
            Result[(Y * AWidth + X) * 4 + 1] := AData[54 + Integer(Src[X]) * 4 + 1];
            Result[(Y * AWidth + X) * 4 + 0] := AData[54 + Integer(Src[X]) * 4 + 2];
            Result[(Y * AWidth + X) * 4 + 3] := $FF;
          end
          else
          begin
            Result[(Y * AWidth + X) * 4] := Src[X];
            Result[(Y * AWidth + X) * 4 + 1] := Src[X];
            Result[(Y * AWidth + X) * 4 + 2] := Src[X];
            Result[(Y * AWidth + X) * 4 + 3] := $FF;
          end;
        end;
      end;
    end;
  end;
end;

function BmpProbe(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) >= 2) and (AData[0] = Ord('B')) and (AData[1] = Ord('M'));
end;

initialization
  ImageRegisterCodec(ifBmp, @BmpProbe, @BmpDecodeRgba, True);

end.
