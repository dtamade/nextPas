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

implementation

uses
  nextpas.core.errors,
  nextpas.core.compress,
  nextpas.core.checksum.crc32,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary;

const
  PNG_SIGNATURE: array[0..7] of Byte = (
    $89, $50, $4E, $47, $0D, $0A, $1A, $0A);

procedure PutBe32(ADst: PByte; AValue: LongWord); inline;
begin
  nextpas.core.bytes.binary.WriteUInt32BE(ADst, AValue);
end;

{ 追加 chunk: 长度(4 BE) + 类型(4 ASCII) + 数据 + CRC32(类型+数据) — 单源 via bytes.ops/bytes.binary }
procedure AppendChunk(var ADst: TBytes; const AType: AnsiString;
  const AData: PByte; ADataLen: SizeUInt); inline;
var
  LLenBE: array[0..3] of Byte;
  LCrcBE: array[0..3] of Byte;
  Crc: LongWord;
begin
  nextpas.core.bytes.binary.WriteUInt32BE(@LLenBE[0], LongWord(ADataLen));
  nextpas.core.bytes.ops.BytesAppend(ADst, @LLenBE[0], 4);
  nextpas.core.bytes.ops.BytesAppend(ADst, PByte(@AType[1]), 4);
  if (AData <> nil) and (ADataLen > 0) then
    nextpas.core.bytes.ops.BytesAppend(ADst, AData, ADataLen);
  Crc := Crc32Update(0, PByte(@AType[1]), 4);
  if (AData <> nil) and (ADataLen > 0) then
    Crc := Crc32Update(Crc, AData, ADataLen);
  nextpas.core.bytes.binary.WriteUInt32BE(@LCrcBE[0], Crc);
  nextpas.core.bytes.ops.BytesAppend(ADst, @LCrcBE[0], 4);
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

end.