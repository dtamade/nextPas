{**
 * nextpas.core.image.png - 最小 PNG 编码器（8-bit RGBA/RGB/Gray）
 *
 * 产出标准 PNG 文件字节：签名 + IHDR + IDAT + IEND。
 * 每扫描行前置 filter byte 0（None），IDAT 用 zlib 流（core compress.deflate）。
 * 颜色类型 0(灰度)/2(RGB)/6(RGBA)，位深 8，无隔行。
 * 纯 Pascal 实现，不依赖 FPC RTL，零 SysUtils/Graphics。
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
function PngEncodeRgb(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
function PngEncodeGray(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;

{** k54（code888 反哺）：PNG 文件字节 → RGBA 位图（与编码对称的最小面）。
    支持：位深 8 × color type 0(灰度)/2(RGB)/6(RGBA) × filter 0-4 × 无隔行；
    多 IDAT 聚合；辅助 chunk（gAMA/sRGB 等）跳过容忍；逐 chunk CRC 校验。
    @param AData PNG 文件字节
    @param AWidth 输出位图宽度（> 0）
    @param AHeight 输出位图高度（> 0）
    @return RGBA 缓冲（W * H * 4，灰度/RGB 源 alpha 恒 $FF）
    @raises EImageDecodeError 形态/结构/签名/CRC/解压/滤波失败 *}
function PngDecodeRgba(const AData: TBytes;
  out AWidth, AHeight: Integer): TBytes;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.compress,
  nextpas.core.checksum.crc32,
  nextpas.core.bytes.binary;

const
  PNG_SIGNATURE: array[0..7] of Byte = (
    $89, $50, $4E, $47, $0D, $0A, $1A, $0A);

procedure PutBe32(ADst: PByte; AValue: LongWord); inline;
begin
  WriteUInt32BE(ADst, UInt32(AValue));
end;

{ 追加 chunk: 长度(4 BE) + 类型(4 ASCII) + 数据 + CRC32(类型+数据) }
procedure AppendChunk(var ADst: TBytes; const AType: AnsiString;
  const AData: PByte; ADataLen: SizeUInt);
var
  Base: SizeUInt;
  Crc: LongWord;
begin
  Base := Length(ADst);
  SetLength(ADst, Base + 12 + ADataLen);
  PutBe32(@ADst[Base], LongWord(ADataLen));
  Move(AType[1], ADst[Base + 4], 4);
  if ADataLen > 0 then
    Move(AData^, ADst[Base + 8], ADataLen);
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
    raise EArgumentError.Create('nextpas.core.image.png.pas: PngEncodeRgba width/height must be >0 (W=' + IntToStr(AWidth) + ' H=' + IntToStr(AHeight) + ')');
  PixelLen := SizeUInt(AWidth) * SizeUInt(AHeight) * 4;
  if SizeUInt(Length(APixels)) <> PixelLen then
    raise EArgumentError.Create('nextpas.core.image.png.pas: PngEncodeRgba pixel buffer length mismatch (got ' + IntToStr(Length(APixels)) + ' expected ' + IntToStr(Int64(PixelLen)) + ')');

  Result := nil;
  SetLength(Result, 8);
  Move(PNG_SIGNATURE, Result[0], 8);

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
    Move(APixels[I * RowLen], P[1], RowLen);
    Inc(P, RowLen + 1);
  end;
  Raw := DeflateCompress(Raw);
  AppendChunk(Result, 'IDAT', @Raw[0], Length(Raw));

  { IEND: 空数据 }
  AppendChunk(Result, 'IEND', nil, 0);
end;

function PngEncodeRgb(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
var
  I, RowLen, PixelLen: SizeUInt;
  Raw: TBytes;
  P: PByte;
  Ihdr: array[0..12] of Byte;
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentError.Create('nextpas.core.image.png.pas: PngEncodeRgb width/height must be >0 (W=' + IntToStr(AWidth) + ' H=' + IntToStr(AHeight) + ')');
  PixelLen := SizeUInt(AWidth) * SizeUInt(AHeight) * 3;
  if SizeUInt(Length(APixels)) <> PixelLen then
    raise EArgumentError.Create('nextpas.core.image.png.pas: PngEncodeRgb pixel buffer length mismatch (got ' + IntToStr(Length(APixels)) + ' expected ' + IntToStr(Int64(PixelLen)) + ')');
  Result := nil; SetLength(Result, 8); Move(PNG_SIGNATURE, Result[0], 8);
  FillChar(Ihdr, SizeOf(Ihdr), 0);
  PutBe32(@Ihdr[0], LongWord(AWidth)); PutBe32(@Ihdr[4], LongWord(AHeight));
  Ihdr[8] := 8; Ihdr[9] := 2;
  AppendChunk(Result, 'IHDR', @Ihdr[0], SizeOf(Ihdr));
  RowLen := SizeUInt(AWidth) * 3;
  SetLength(Raw, (RowLen + 1) * SizeUInt(AHeight));
  P := @Raw[0];
  for I := 0 to SizeUInt(AHeight) - 1 do
  begin
    P[0] := 0; Move(APixels[I * RowLen], P[1], RowLen); Inc(P, RowLen + 1);
  end;
  Raw := DeflateCompress(Raw);
  AppendChunk(Result, 'IDAT', @Raw[0], Length(Raw));
  AppendChunk(Result, 'IEND', nil, 0);
end;

function PngEncodeGray(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
var
  I, RowLen, PixelLen: SizeUInt;
  Raw: TBytes;
  P: PByte;
  Ihdr: array[0..12] of Byte;
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentError.Create('nextpas.core.image.png.pas: PngEncodeGray width/height must be >0 (W=' + IntToStr(AWidth) + ' H=' + IntToStr(AHeight) + ')');
  PixelLen := SizeUInt(AWidth) * SizeUInt(AHeight);
  if SizeUInt(Length(APixels)) <> PixelLen then
    raise EArgumentError.Create('nextpas.core.image.png.pas: PngEncodeGray pixel buffer length mismatch (got ' + IntToStr(Length(APixels)) + ' expected ' + IntToStr(Int64(PixelLen)) + ')');
  Result := nil; SetLength(Result, 8); Move(PNG_SIGNATURE, Result[0], 8);
  FillChar(Ihdr, SizeOf(Ihdr), 0);
  PutBe32(@Ihdr[0], LongWord(AWidth)); PutBe32(@Ihdr[4], LongWord(AHeight));
  Ihdr[8] := 8; Ihdr[9] := 0;
  AppendChunk(Result, 'IHDR', @Ihdr[0], SizeOf(Ihdr));
  RowLen := SizeUInt(AWidth);
  SetLength(Raw, (RowLen + 1) * SizeUInt(AHeight));
  P := @Raw[0];
  for I := 0 to SizeUInt(AHeight) - 1 do
  begin
    P[0] := 0; Move(APixels[I * RowLen], P[1], RowLen); Inc(P, RowLen + 1);
  end;
  Raw := DeflateCompress(Raw);
  AppendChunk(Result, 'IDAT', @Raw[0], Length(Raw));
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

  function Be32(AIdx: Integer): LongWord; inline;
  begin
    Result := LongWord(ReadUInt32BE(@AData[AIdx]));
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
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba truncated (no signature, got ' + IntToStr(Length(AData)) + ' expected 8)');
  if (AData[0] <> PNG_SIGNATURE[0]) or (AData[1] <> PNG_SIGNATURE[1]) or
     (AData[2] <> PNG_SIGNATURE[2]) or (AData[3] <> PNG_SIGNATURE[3]) or
     (AData[4] <> PNG_SIGNATURE[4]) or (AData[5] <> PNG_SIGNATURE[5]) or
     (AData[6] <> PNG_SIGNATURE[6]) or (AData[7] <> PNG_SIGNATURE[7]) then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba bad signature');

  { chunk 循环：IHDR 必首、IDAT 聚合、IEND 终止、辅助跳过容忍 }
  LIhdrPos := 0;
  SetLength(LIdat, 0);
  LPos := 8;
  while True do
  begin
    if LPos + 12 > LongWord(Length(AData)) then
      raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba truncated chunk header (pos=' + IntToStr(Int64(LPos)) + ' have ' + IntToStr(Length(AData) - Integer(LPos)) + ' need 12)');
    LLen := Be32(Integer(LPos));
    if LLen > $7FFFFFFF then
      raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba chunk length overflow (len=' + IntToStr(Int64(LLen)) + ' at pos=' + IntToStr(Int64(LPos)) + ')');
    if LPos + 12 + LLen > LongWord(Length(AData)) then
      raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba truncated chunk data (pos=' + IntToStr(Int64(LPos)) + ' len=' + IntToStr(Int64(LLen)) + ' need ' + IntToStr(Int64(LPos + 12 + LLen)) + ' have ' + IntToStr(Length(AData)) + ')');
    LCrcStored := Be32(Integer(LPos + 8 + Integer(LLen)));
    LCrcCalc := Crc32Update(0, @AData[LPos + 4], 4);
    if LLen > 0 then
      LCrcCalc := Crc32Update(LCrcCalc, @AData[LPos + 8], LLen);
    if LCrcCalc <> LCrcStored then
      raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba chunk crc mismatch (type=' + Chr(AData[LPos + 4]) + Chr(AData[LPos + 5]) + Chr(AData[LPos + 6]) + Chr(AData[LPos + 7]) + ' pos=' + IntToStr(Int64(LPos)) + ' expected ' + IntToStr(Int64(LCrcStored)) + ' got ' + IntToStr(Int64(LCrcCalc)) + ')');

    if (AData[LPos + 4] = Ord('I')) and (AData[LPos + 5] = Ord('H')) and
       (AData[LPos + 6] = Ord('D')) and (AData[LPos + 7] = Ord('R')) then
    begin
      if LIhdrPos <> 0 then
        raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba duplicate IHDR (pos=' + IntToStr(Int64(LPos)) + ')');
      if LLen <> 13 then
        raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba IHDR length !=13 (got ' + IntToStr(Int64(LLen)) + ' at pos=' + IntToStr(Int64(LPos)) + ')');
      LIhdrPos := LPos;
    end
    else if (AData[LPos + 4] = Ord('I')) and (AData[LPos + 5] = Ord('D')) and
            (AData[LPos + 6] = Ord('A')) and (AData[LPos + 7] = Ord('T')) then
    begin
      SetLength(LIdat, Length(LIdat) + Integer(LLen));
      if LLen > 0 then
        Move(AData[LPos + 8], LIdat[Length(LIdat) - Integer(LLen)], LLen);
    end
    else if (AData[LPos + 4] = Ord('I')) and (AData[LPos + 5] = Ord('E')) and
            (AData[LPos + 6] = Ord('N')) and (AData[LPos + 7] = Ord('D')) then
      Break;

    Inc(LPos, 12 + LLen);
  end;

  if LIhdrPos = 0 then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba missing IHDR');

  { IHDR 解析 + 形态校验（fail-closed：不支持即报错，不静默坏图） }
  AWidth := Integer(Be32(Integer(LIhdrPos + 8)));
  AHeight := Integer(Be32(Integer(LIhdrPos + 12)));
  LDepth := AData[LIhdrPos + 16];
  LColor := AData[LIhdrPos + 17];
  LInterlace := AData[LIhdrPos + 20];
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba width/height must be >0 (W=' + IntToStr(AWidth) + ' H=' + IntToStr(AHeight) + ')');
  if (AWidth > 16384) or (AHeight > 16384) then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba width/height exceeds 16384 cap (W=' + IntToStr(AWidth) + ' H=' + IntToStr(AHeight) + ')');
  if LDepth <> 8 then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba unsupported bit depth (need 8 got ' + IntToStr(LDepth) + ')');
  if not (LColor in [0, 2, 6]) then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba unsupported color type (need 0/2/6 got ' + IntToStr(LColor) + ')');
  if LInterlace <> 0 then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba interlaced not supported (got ' + IntToStr(LInterlace) + ')');

  case LColor of
    0: LBpp := 1;
    2: LBpp := 3;
    else LBpp := 4;
  end;
  if AWidth > High(Integer) div LBpp then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba width*bpp overflow (W=' + IntToStr(AWidth) + ' bpp=' + IntToStr(LBpp) + ')');
  RowLen := AWidth * LBpp;
  if RowLen >= High(Integer) then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba RowLen+1 overflow (RowLen=' + IntToStr(RowLen) + ')');
  if AHeight > High(Integer) div (RowLen + 1) then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba RowLen*Height overflow (RowLen=' + IntToStr(RowLen) + ' H=' + IntToStr(AHeight) + ' RowLen+1=' + IntToStr(RowLen + 1) + ')');
  if AWidth > High(Integer) div AHeight then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba width*height overflow (W=' + IntToStr(AWidth) + ' H=' + IntToStr(AHeight) + ')');
  if (AWidth * AHeight) > High(Integer) div 4 then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba width*height*4 overflow (W=' + IntToStr(AWidth) + ' H=' + IntToStr(AHeight) + ')');

  if Length(LIdat) = 0 then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba missing IDAT');
  LRaw := DeflateDecompress(LIdat);
  if Length(LRaw) <> (RowLen + 1) * AHeight then
    raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba decompressed size mismatch (expected ' + IntToStr((RowLen + 1) * AHeight) + ' got ' + IntToStr(Length(LRaw)) + ' RowLen=' + IntToStr(RowLen) + ' H=' + IntToStr(AHeight) + ')');

  { 反滤波逐行还原 + 转 RGBA 输出 }
  Result := nil;
  SetLength(Result, AWidth * AHeight * 4);
  SetLength(LRow, RowLen);
  SetLength(LPrev, RowLen);
  for Y := 0 to AHeight - 1 do
  begin
    LStride := Y * (RowLen + 1);
    if LRaw[LStride] > 4 then
      raise EImageDecodeError.Create('nextpas.core.image.png.pas: PngDecodeRgba invalid filter byte (got ' + IntToStr(LRaw[LStride]) + ' at row ' + IntToStr(Y) + ')');
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
        begin
          for C := 0 to 2 do
            Result[(Y * AWidth + X) * 4 + C] := LRow[X * 3 + C];
          Result[(Y * AWidth + X) * 4 + 3] := $FF;
        end;
        else
        for C := 0 to 3 do
          Result[(Y * AWidth + X) * 4 + C] := LRow[X * 4 + C];
      end;
    end;
    Move(LRow[0], LPrev[0], RowLen);
  end;
end;

end.