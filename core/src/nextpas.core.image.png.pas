{**
 * nextpas.core.image.png - 最小 PNG 编码器（8-bit RGBA）
 *
 * 产出标准 PNG 文件字节：签名 + IHDR + IDAT + IEND。
 * 每扫描行前置 filter byte 0（None），IDAT 用 zlib 流（core compress.deflate）。
 * 颜色类型 6（RGBA），位深 8，无隔行。
 * 纯 Pascal 实现，不依赖 FPC RTL。
 *}

unit nextpas.core.image.png;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{** @desc RGBA 位图 → PNG 文件字节
    @param APixels 像素缓冲，长度必须 = AWidth * AHeight * 4（行序自上而下，每像素 R,G,B,A）
    @param AWidth  位图宽度（> 0）
    @param AHeight 位图高度（> 0）
    @return PNG 文件字节（可直接写盘）
    @raises EArgumentError 宽度/高度 ≤ 0 或缓冲长度与尺寸不符 *}
function PngEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;

{** k54（code888 反哺）：PNG 文件字节 → RGBA 位图（与编码对称的最小面）。
    支持：位深 8 × color type 0(灰度)/2(RGB)/6(RGBA) × filter 0-4 × 无隔行；
    多 IDAT 聚合；辅助 chunk（gAMA/sRGB 等）跳过容忍；逐 chunk CRC 校验。
    @param AData PNG 文件字节
    @param AWidth 输出位图宽度（> 0）
    @param AHeight 输出位图高度（> 0）
    @return RGBA 缓冲（W * H * 4，灰度/RGB 源 alpha 恒 $FF）
    @raises EImageDecodeError 数据形态不支持/截断/CRC/流损坏 *}
function PngDecodeRgba(const AData: TBytes;
  out AWidth, AHeight: Integer): TBytes;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.compress,
  nextpas.core.checksum.crc32,
  nextpas.core.bytes.ops,
  nextpas.core.image.base,
  nextpas.core.image.dispatch;

const
  PNG_SIGNATURE: array[0..7] of Byte = (
    $89, $50, $4E, $47, $0D, $0A, $1A, $0A);

procedure PutBe32(ADst: PByte; AValue: LongWord); inline;
begin
  ADst[0] := Byte(AValue shr 24);
  ADst[1] := Byte(AValue shr 16);
  ADst[2] := Byte(AValue shr 8);
  ADst[3] := Byte(AValue);
end;

{ 追加 chunk: 长度(4 BE) + 类型(4 ASCII) + 数据 + CRC32(类型+数据) — BytesCopy 单源 inline 零拷贝 }
procedure AppendChunk(var ADst: TBytes; const AType: AnsiString;
  const AData: PByte; ADataLen: SizeUInt); inline;
var
  Base: SizeUInt;
  Crc: LongWord;
begin
  Base := Length(ADst);
  SetLength(ADst, Base + 12 + ADataLen);
  PutBe32(@ADst[Base], LongWord(ADataLen));
  BytesCopy(@ADst[Base + 4], @AType[1], 4);
  if ADataLen > 0 then
    BytesCopy(@ADst[Base + 8], AData, SizeUInt(ADataLen));
  Crc := Crc32Update(0, @ADst[Base + 4], 4);
  Crc := Crc32Update(Crc, AData, ADataLen);
  PutBe32(@ADst[Base + 8 + ADataLen], Crc);
end;

function PngEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
var
  I, RowLen, PixelLen: SizeUInt;
  Raw: TBytes;
  P: PByte;
  Ihdr: array[0..12] of Byte;
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentError.Create('nextpas.core.image.png.pas: PngEncodeRgba: width/height must be > 0 (width=' + IntToStr(Int64(AWidth)) + ' height=' + IntToStr(Int64(AHeight)) + ')');
  PixelLen := SizeUInt(AWidth) * SizeUInt(AHeight) * 4;
  if SizeUInt(Length(APixels)) <> PixelLen then
    raise EArgumentError.Create('nextpas.core.image.png.pas: PngEncodeRgba: pixel buffer length mismatch (length=' + IntToStr(Int64(Length(APixels))) + ' expected=' + IntToStr(Int64(PixelLen)) + ' width=' + IntToStr(Int64(AWidth)) + ' height=' + IntToStr(Int64(AHeight)) + ')');

  Result := nil;
  SetLength(Result, 8);
  BytesCopy(@Result[0], @PNG_SIGNATURE[0], 8);

  { IHDR: 宽/高 BE32 + 位深 8 + 颜色类型 6(RGBA) + 压缩 0 + 滤波 0 + 隔行 0 }
  FillChar(Ihdr, SizeOf(Ihdr), 0);
  PutBe32(@Ihdr[0], LongWord(AWidth));
  PutBe32(@Ihdr[4], LongWord(AHeight));
  Ihdr[8] := 8;
  Ihdr[9] := 6;
  AppendChunk(Result, 'IHDR', @Ihdr[0], SizeOf(Ihdr));

  { 扫描线: 每行前置 filter 0, 后接 W*4 字节 RGBA, 整体 zlib 压缩为 IDAT }
  RowLen := SizeUInt(AWidth) * 4;
  SetLength(Raw, (RowLen + 1) * SizeUInt(AHeight));
  P := @Raw[0];
  for I := 0 to SizeUInt(AHeight) - 1 do
  begin
    P[0] := 0;
    BytesCopy(@P[1], @APixels[I * RowLen], SizeUInt(RowLen));
    Inc(P, RowLen + 1);
  end;
  Raw := DeflateCompress(Raw);
  AppendChunk(Result, 'IDAT', @Raw[0], Length(Raw));

  { IEND: 空数据 }
  AppendChunk(Result, 'IEND', nil, 0);
end;

function PngDecodeRgba(const AData: TBytes;
  out AWidth, AHeight: Integer): TBytes;
var
  LPos, LLen, LCrcStored, LCrcCalc: LongWord;
  LIhdrPos: LongWord;
  LDepth, LColor, LInterlace: Integer;
  LBpp, RowLen, X, Y, C: Integer;
  LIdat: TBytes;
  LRaw, LPrev, LRow: TBytes;
  LA, B, Cc, P, PA, PB, PC, LPred, LStride: Integer;

  function Be32(AIdx: Integer): LongWord;
  begin
    Result := (LongWord(AData[AIdx]) shl 24) or
      (LongWord(AData[AIdx + 1]) shl 16) or
      (LongWord(AData[AIdx + 2]) shl 8) or
      LongWord(AData[AIdx + 3]);
  end;

  function Paeth(A, B, C: Integer): Integer;
  begin
    P := A + B - C;
    PA := Abs(P - A);
    PB := Abs(P - B);
    PC := Abs(P - C);
    if (PA <= PB) and (PA <= PC) then
      Exit(A);
    if PB <= PC then
      Exit(B);
    Result := C;
  end;

begin
  AWidth := 0;
  AHeight := 0;
  if Length(AData) < 8 then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: truncated (no signature) (length=' + IntToStr(Int64(Length(AData))) + ' expected>=8)');
  if (AData[0] <> PNG_SIGNATURE[0]) or (AData[1] <> PNG_SIGNATURE[1]) or
     (AData[2] <> PNG_SIGNATURE[2]) or (AData[3] <> PNG_SIGNATURE[3]) or
     (AData[4] <> PNG_SIGNATURE[4]) or (AData[5] <> PNG_SIGNATURE[5]) or
     (AData[6] <> PNG_SIGNATURE[6]) or (AData[7] <> PNG_SIGNATURE[7]) then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: bad signature (byte0=' + IntToStr(Int64(AData[0])) + ' expected=' + IntToStr(Int64(PNG_SIGNATURE[0])) + ')');

  { chunk 循环：IHDR 必首、IDAT 聚合、IEND 终止、辅助跳过容忍 }
  LIhdrPos := 0;
  SetLength(LIdat, 0);
  LPos := 8;
  while True do
  begin
    if LPos + 12 > LongWord(Length(AData)) then
      raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: truncated chunk header (pos=' + IntToStr(Int64(LPos)) + ' length=' + IntToStr(Int64(Length(AData))) + ' need>=12)');
    LLen := Be32(Integer(LPos));
    if LLen > $7FFFFFFF then
      raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: chunk length overflow (len=' + IntToStr(Int64(LLen)) + ' pos=' + IntToStr(Int64(LPos)) + ')');
    if LPos + 12 + LLen > LongWord(Length(AData)) then
      raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: truncated chunk data (pos=' + IntToStr(Int64(LPos)) + ' len=' + IntToStr(Int64(LLen)) + ' total=' + IntToStr(Int64(Length(AData))) + ')');
    LCrcStored := Be32(Integer(LPos + 8 + Integer(LLen)));
    LCrcCalc := Crc32Update(0, @AData[LPos + 4], 4);
    if LLen > 0 then
      LCrcCalc := Crc32Update(LCrcCalc, @AData[LPos + 8], LLen);
    if LCrcCalc <> LCrcStored then
      raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: chunk crc mismatch (pos=' + IntToStr(Int64(LPos)) + ' len=' + IntToStr(Int64(LLen)) + ' calc=' + IntToStr(Int64(LCrcCalc)) + ' stored=' + IntToStr(Int64(LCrcStored)) + ')');

    if (AData[LPos + 4] = Ord('I')) and (AData[LPos + 5] = Ord('H')) and
       (AData[LPos + 6] = Ord('D')) and (AData[LPos + 7] = Ord('R')) then
    begin
      if LIhdrPos <> 0 then
        raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: duplicate IHDR (pos=' + IntToStr(Int64(LPos)) + ' prev=' + IntToStr(Int64(LIhdrPos)) + ')');
      if LLen <> 13 then
        raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: IHDR length != 13 (len=' + IntToStr(Int64(LLen)) + ' pos=' + IntToStr(Int64(LPos)) + ')');
      LIhdrPos := LPos;
    end
    else if (AData[LPos + 4] = Ord('I')) and (AData[LPos + 5] = Ord('D')) and
            (AData[LPos + 6] = Ord('A')) and (AData[LPos + 7] = Ord('T')) then
    begin
      SetLength(LIdat, Length(LIdat) + Integer(LLen));
      if LLen > 0 then
        BytesCopy(@LIdat[Length(LIdat) - Integer(LLen)], @AData[LPos + 8], SizeUInt(LLen));
    end
    else if (AData[LPos + 4] = Ord('I')) and (AData[LPos + 5] = Ord('E')) and
            (AData[LPos + 6] = Ord('N')) and (AData[LPos + 7] = Ord('D')) then
      Break;

    Inc(LPos, 12 + LLen);
  end;

  if LIhdrPos = 0 then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: missing IHDR');

  { IHDR 解析 + 形态校验（fail-closed：不支持即报错，不静默坏图） }
  AWidth := Integer(Be32(Integer(LIhdrPos + 8)));
  AHeight := Integer(Be32(Integer(LIhdrPos + 12)));
  LDepth := AData[LIhdrPos + 16];
  LColor := AData[LIhdrPos + 17];
  LInterlace := AData[LIhdrPos + 20];
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: width/height must be > 0 (width=' + IntToStr(Int64(AWidth)) + ' height=' + IntToStr(Int64(AHeight)) + ')');
  if (AWidth > 16384) or (AHeight > 16384) then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: width/height exceeds 16384 cap (width=' + IntToStr(Int64(AWidth)) + ' height=' + IntToStr(Int64(AHeight)) + ')');
  if Int64(AWidth) * Int64(AHeight) > 16 * 1024 * 1024 then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: image too large (16M cap) (w=' + IntToStr(Int64(AWidth)) + ' h=' + IntToStr(Int64(AHeight)) + ')');
  if LDepth <> 8 then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: unsupported bit depth (need 8) (depth=' + IntToStr(Int64(LDepth)) + ')');
  if not (LColor in [0, 2, 6]) then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: unsupported color type (need 0/2/6) (colorType=' + IntToStr(Int64(LColor)) + ')');
  if LInterlace <> 0 then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: interlaced images not supported (interlace=' + IntToStr(Int64(LInterlace)) + ')');

  case LColor of
    0: LBpp := 1;
    2: LBpp := 3;
    else LBpp := 4;
  end;
  RowLen := AWidth * LBpp;

  if Length(LIdat) = 0 then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: missing IDAT');
  LRaw := DeflateDecompress(LIdat);
  if Length(LRaw) <> (RowLen + 1) * AHeight then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: decompressed size mismatch (length=' + IntToStr(Int64(Length(LRaw))) + ' expected=' + IntToStr(Int64((RowLen + 1) * AHeight)) + ' rowLen=' + IntToStr(Int64(RowLen)) + ' height=' + IntToStr(Int64(AHeight)) + ')');

  { 反滤波逐行还原 + 转 RGBA 输出 }
  SetLength(Result, AWidth * AHeight * 4);
  SetLength(LRow, RowLen);
  SetLength(LPrev, RowLen);
  for Y := 0 to AHeight - 1 do
  begin
    LStride := Y * (RowLen + 1);
    if LRaw[LStride] > 4 then
      raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba: invalid filter byte (filter=' + IntToStr(Int64(LRaw[LStride])) + ' y=' + IntToStr(Int64(Y)) + ' expected 0..4)');
    for X := 0 to RowLen - 1 do
    begin
      LA := 0;
      if X >= LBpp then
        LA := LRow[X - LBpp];
      B := LPrev[X];
      Cc := 0;
      if X >= LBpp then
        Cc := LPrev[X - LBpp];
      case LRaw[LStride] of
        0: LPred := 0;
        1: LPred := LA;
        2: LPred := B;
        3: LPred := (LA + B) div 2;
        else LPred := Paeth(LA, B, Cc);
      end;
      LRow[X] := Byte((LRaw[LStride + 1 + X] + LPred) and $FF);
    end;
    for X := 0 to AWidth - 1 do
    begin
      case LColor of
        0:
        begin
          C := LRow[X];
          Result[(Y * AWidth + X) * 4] := Byte(C);
          Result[(Y * AWidth + X) * 4 + 1] := Byte(C);
          Result[(Y * AWidth + X) * 4 + 2] := Byte(C);
          Result[(Y * AWidth + X) * 4 + 3] := $FF;
        end;
        2:
        for C := 0 to 2 do
          Result[(Y * AWidth + X) * 4 + C] := LRow[X * 3 + C];
        else
        for C := 0 to 3 do
          Result[(Y * AWidth + X) * 4 + C] := LRow[X * 4 + C];
      end;
    end;
    BytesCopy(@LPrev[0], @LRow[0], SizeUInt(RowLen));
  end;
end;

function PngProbe(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) >= 8) and
    (AData[0] = PNG_SIGNATURE[0]) and (AData[1] = PNG_SIGNATURE[1]) and
    (AData[2] = PNG_SIGNATURE[2]) and (AData[3] = PNG_SIGNATURE[3]) and
    (AData[4] = PNG_SIGNATURE[4]) and (AData[5] = PNG_SIGNATURE[5]) and
    (AData[6] = PNG_SIGNATURE[6]) and (AData[7] = PNG_SIGNATURE[7]);
end;

initialization
  ImageRegisterCodec(ifPng, @PngProbe, @PngDecodeRgba, True);

end.
