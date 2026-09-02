program test_png;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.compress,
  nextpas.core.checksum.crc32,
  nextpas.core.image.png,
  nextpas.core.test;

type
  TChunk = record
    Kind: array[0..3] of AnsiChar;
    Data: TBytes;
  end;

{ 解析 PNG 顶层结构: 返回全部 chunk(按文件顺序), 校验签名与每个 chunk 的 CRC }
procedure ParsePng(const AData: TBytes; out AChunks: array of TChunk;
  out ACount: Integer);
var
  Pos, Len: SizeUInt;
  Crc, Calc: LongWord;
begin
  ACount := 0;
  Check(Length(AData) >= 8, 'png >= 8 bytes');
  Check((AData[0] = $89) and (AData[1] = $50) and (AData[2] = $4E)
    and (AData[3] = $47) and (AData[4] = $0D) and (AData[5] = $0A)
    and (AData[6] = $1A) and (AData[7] = $0A), 'png signature');
  Pos := 8;
  while Pos + 12 <= Length(AData) do
  begin
    Len := (AData[Pos] shl 24) or (AData[Pos + 1] shl 16)
      or (AData[Pos + 2] shl 8) or AData[Pos + 3];
    AChunks[ACount].Kind[0] := AnsiChar(AData[Pos + 4]);
    AChunks[ACount].Kind[1] := AnsiChar(AData[Pos + 5]);
    AChunks[ACount].Kind[2] := AnsiChar(AData[Pos + 6]);
    AChunks[ACount].Kind[3] := AnsiChar(AData[Pos + 7]);
    SetLength(AChunks[ACount].Data, Len);
    if Len > 0 then
      Move(AData[Pos + 8], AChunks[ACount].Data[0], Len);
    Crc := (AData[Pos + 8 + Len] shl 24) or (AData[Pos + 8 + Len + 1] shl 16)
      or (AData[Pos + 8 + Len + 2] shl 8) or AData[Pos + 8 + Len + 3];
    Calc := Crc32Update(0, @AData[Pos + 4], 4);
    Calc := Crc32Update(Calc, @AData[Pos + 8], Len);
    Check(Calc = Crc, 'chunk crc ok: ' + string(AChunks[ACount].Kind));
    Inc(ACount);
    Inc(Pos, 12 + Len);
  end;
  Check(Pos = SizeUInt(Length(AData)), 'png fully consumed');
end;

procedure TestRed2x2;
const
  W = 2;
  H = 2;
var
  Pixels, Png, Raw: TBytes;
  Chunks: array[0..3] of TChunk;
  N: Integer;
  RowLen: SizeUInt;
  X: Integer;
begin
  SetLength(Pixels, W * H * 4);
  for X := 0 to W * H - 1 do
  begin
    Pixels[X * 4] := $FF;
    Pixels[X * 4 + 1] := $00;
    Pixels[X * 4 + 2] := $00;
    Pixels[X * 4 + 3] := $FF;
  end;
  Png := PngEncodeRgba(Pixels, W, H);
  ParsePng(Png, Chunks, N);
  CheckEqual(N, 3, 'three chunks');
  Check(Chunks[0].Kind = 'IHDR', 'first chunk IHDR');
  Check(Chunks[1].Kind = 'IDAT', 'second chunk IDAT');
  Check(Chunks[2].Kind = 'IEND', 'third chunk IEND');
  CheckEqual(Length(Chunks[2].Data), 0, 'IEND empty');
  { IHDR: 宽/高 BE32 + depth 8 + color 6 + comp/filter/interlace 0 }
  CheckEqual(Length(Chunks[0].Data), 13, 'IHDR 13 bytes');
  CheckEqual(Chunks[0].Data[0], 0, 'IHDR W hi');
  CheckEqual(Chunks[0].Data[1], 0, 'IHDR W');
  CheckEqual(Chunks[0].Data[2], 0, 'IHDR W');
  CheckEqual(Chunks[0].Data[3], W, 'IHDR W lo');
  CheckEqual(Chunks[0].Data[4], 0, 'IHDR H hi');
  CheckEqual(Chunks[0].Data[7], H, 'IHDR H lo');
  CheckEqual(Chunks[0].Data[8], 8, 'IHDR depth');
  CheckEqual(Chunks[0].Data[9], 6, 'IHDR color type RGBA');
  CheckEqual(Chunks[0].Data[10], 0, 'IHDR compression');
  CheckEqual(Chunks[0].Data[11], 0, 'IHDR filter');
  CheckEqual(Chunks[0].Data[12], 0, 'IHDR interlace');
  { IDAT: zlib 解回 = 每行 filter 0 + 原像素 }
  Raw := DeflateDecompress(Chunks[1].Data);
  RowLen := W * 4;
  CheckEqual(Length(Raw), SizeUInt((RowLen + 1) * H), 'raw scanline size');
  CheckEqual(Raw[0], 0, 'row0 filter');
  CheckEqual(Raw[RowLen + 1], 0, 'row1 filter');
  for X := 0 to W - 1 do
  begin
    CheckEqual(Raw[1 + X * 4], $FF, 'red R');
    CheckEqual(Raw[1 + X * 4 + 1], $00, 'red G');
    CheckEqual(Raw[1 + X * 4 + 2], $00, 'red B');
    CheckEqual(Raw[1 + X * 4 + 3], $FF, 'red A');
  end;
end;

procedure TestGradient1x3;
const
  W = 1;
  H = 3;
var
  Pixels, Png, Raw: TBytes;
  Chunks: array[0..3] of TChunk;
  N, Y: Integer;
begin
  SetLength(Pixels, W * H * 4);
  for Y := 0 to H - 1 do
  begin
    Pixels[Y * 4] := Byte(Y * 64);
    Pixels[Y * 4 + 1] := $80;
    Pixels[Y * 4 + 2] := Byte($FF - Y * 64);
    Pixels[Y * 4 + 3] := $FF;
  end;
  Png := PngEncodeRgba(Pixels, W, H);
  ParsePng(Png, Chunks, N);
  Raw := DeflateDecompress(Chunks[1].Data);
  CheckEqual(Length(Raw), SizeUInt((W * 4 + 1) * H), 'raw 3 rows');
  for Y := 0 to H - 1 do
  begin
    CheckEqual(Raw[Y * 5], 0, 'row filter zero');
    CheckEqual(Raw[Y * 5 + 1], Byte(Y * 64), 'gradient R');
    CheckEqual(Raw[Y * 5 + 2], $80, 'gradient G');
    CheckEqual(Raw[Y * 5 + 3], Byte($FF - Y * 64), 'gradient B');
    CheckEqual(Raw[Y * 5 + 4], $FF, 'gradient A');
  end;
end;

procedure TestBadArgs;
begin
  CheckRaises(EArgumentError, procedure
    begin
      PngEncodeRgba(nil, 0, 1);
    end, 'width/height must be > 0');
  CheckRaises(EArgumentError, procedure
    begin
      PngEncodeRgba(nil, 1, 0);
    end, 'width/height must be > 0');
  CheckRaises(EArgumentError, procedure
    begin
      PngEncodeRgba(nil, 2, 2);
    end, 'pixel buffer length mismatch');
  CheckRaises(EArgumentError, procedure
    begin
      PngEncodeRgba(TBytes.Create(0, 0, 0), 2, 2);
    end, 'pixel buffer length mismatch');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.image.png');
  T.Test('red 2x2 structure', @TestRed2x2);
  T.Test('gradient 1x3 pixels', @TestGradient1x3);
  T.Test('bad arguments', @TestBadArgs);
  if not T.Run then Halt(1);
end.