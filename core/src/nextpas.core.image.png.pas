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
    @raises EArgumentError 数据形态不支持（位深/色型/隔行/宽高 ≤ 0）
    @raises EIOError 签名/结构/CRC/流损坏 *}
function PngDecodeRgba(const AData: TBytes;
  out AWidth, AHeight: Integer): TBytes;

implementation

uses
  nextpas.core.errors,
  nextpas.core.compress,
  nextpas.core.checksum.crc32;

const
  PNG_SIGNATURE: array[0..7] of Byte = (
    $89, $50, $4E, $47, $0D, $0A, $1A, $0A);

procedure PutBe32(ADst: PByte; AValue: LongWord);
begin
  ADst[0] := Byte(AValue shr 24);
  ADst[1] := Byte(AValue shr 16);
  ADst[2] := Byte(AValue shr 8);
  ADst[3] := Byte(AValue);
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
    raise EArgumentError.Create('png: width/height must be > 0');
  PixelLen := SizeUInt(AWidth) * SizeUInt(AHeight) * 4;
  if SizeUInt(Length(APixels)) <> PixelLen then
    raise EArgumentError.Create('png: pixel buffer length mismatch');

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
    raise EIOError.Create('png: truncated (no signature)');
  if (AData[0] <> PNG_SIGNATURE[0]) or (AData[1] <> PNG_SIGNATURE[1]) or
     (AData[2] <> PNG_SIGNATURE[2]) or (AData[3] <> PNG_SIGNATURE[3]) or
     (AData[4] <> PNG_SIGNATURE[4]) or (AData[5] <> PNG_SIGNATURE[5]) or
     (AData[6] <> PNG_SIGNATURE[6]) or (AData[7] <> PNG_SIGNATURE[7]) then
    raise EIOError.Create('png: bad signature');

  { chunk 循环：IHDR 必首、IDAT 聚合、IEND 终止、辅助跳过容忍 }
  LIhdrPos := 0;
  SetLength(LIdat, 0);
  LPos := 8;
  while True do
  begin
    if LPos + 12 > LongWord(Length(AData)) then
      raise EIOError.Create('png: truncated chunk header');
    LLen := Be32(Integer(LPos));
    if LLen > $7FFFFFFF then
      raise EIOError.Create('png: chunk length overflow');
    if LPos + 12 + LLen > LongWord(Length(AData)) then
      raise EIOError.Create('png: truncated chunk data');
    LCrcStored := Be32(Integer(LPos + 8 + Integer(LLen)));
    LCrcCalc := Crc32Update(0, @AData[LPos + 4], 4);
    if LLen > 0 then
      LCrcCalc := Crc32Update(LCrcCalc, @AData[LPos + 8], LLen);
    if LCrcCalc <> LCrcStored then
      raise EIOError.Create('png: chunk crc mismatch');

    if (AData[LPos + 4] = Ord('I')) and (AData[LPos + 5] = Ord('H')) and
       (AData[LPos + 6] = Ord('D')) and (AData[LPos + 7] = Ord('R')) then
    begin
      if LIhdrPos <> 0 then
        raise EIOError.Create('png: duplicate IHDR');
      if LLen <> 13 then
        raise EIOError.Create('png: IHDR length != 13');
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
    raise EIOError.Create('png: missing IHDR');

  { IHDR 解析 + 形态校验（fail-closed：不支持即报错，不静默坏图） }
  AWidth := Integer(Be32(Integer(LIhdrPos + 8)));
  AHeight := Integer(Be32(Integer(LIhdrPos + 12)));
  LDepth := AData[LIhdrPos + 16];
  LColor := AData[LIhdrPos + 17];
  LInterlace := AData[LIhdrPos + 20];
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentError.Create('png: width/height must be > 0');
  if LDepth <> 8 then
    raise EArgumentError.Create('png: unsupported bit depth (need 8)');
  if not (LColor in [0, 2, 6]) then
    raise EArgumentError.Create('png: unsupported color type (need 0/2/6)');
  if LInterlace <> 0 then
    raise EArgumentError.Create('png: interlaced images not supported');

  case LColor of
    0: LBpp := 1;
    2: LBpp := 3;
    else LBpp := 4;
  end;
  RowLen := AWidth * LBpp;

  if Length(LIdat) = 0 then
    raise EIOError.Create('png: missing IDAT');
  LRaw := DeflateDecompress(LIdat);
  if Length(LRaw) <> (RowLen + 1) * AHeight then
    raise EIOError.Create('png: decompressed size mismatch');

  { 反滤波逐行还原 + 转 RGBA 输出 }
  Result := nil;
  SetLength(Result, AWidth * AHeight * 4);
  SetLength(LRow, RowLen);
  SetLength(LPrev, RowLen);
  for Y := 0 to AHeight - 1 do
  begin
    LStride := Y * (RowLen + 1);
    if LRaw[LStride] > 4 then
      raise EIOError.Create('png: invalid filter byte');
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