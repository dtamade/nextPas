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

{ ---- k54 (code888 backfeed): PngDecodeRgba ---- }

const
  kSig: array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);

procedure AppendChunk(var AOut: TBytes; const AKind: AnsiString;
  const AData: TBytes);
var
  LBase, I: Integer;
  LCrc: LongWord;
begin
  LBase := Length(AOut);
  SetLength(AOut, LBase + 12 + Length(AData));
  AOut[LBase] := Byte((Length(AData) shr 24) and $FF);
  AOut[LBase + 1] := Byte((Length(AData) shr 16) and $FF);
  AOut[LBase + 2] := Byte((Length(AData) shr 8) and $FF);
  AOut[LBase + 3] := Byte(Length(AData) and $FF);
  for I := 1 to 4 do
    AOut[LBase + 3 + I] := Byte(AKind[I]);
  if Length(AData) > 0 then
    Move(AData[0], AOut[LBase + 8], Length(AData));
  LCrc := Crc32Update(0, @AOut[LBase + 4], 4);
  if Length(AData) > 0 then
    LCrc := Crc32Update(LCrc, @AData[0], Length(AData));
  AOut[LBase + 8 + Length(AData)] := Byte(LCrc shr 24);
  AOut[LBase + 9 + Length(AData)] := Byte(LCrc shr 16);
  AOut[LBase + 10 + Length(AData)] := Byte(LCrc shr 8);
  AOut[LBase + 11 + Length(AData)] := Byte(LCrc);
end;

{ 手工拼 PNG：IHDR(W,H,Depth,Color,Interlace) + IDAT(zlib(Raw)) + IEND。
  ASplitIdat=True 时 IDAT 拆两块（多 IDAT 聚合覆盖） }
function BuildTestPng(AW, AH, ADepth, AColor, AInterlace: Integer;
  const ARaw: TBytes; ASplitIdat: Boolean): TBytes;
var
  LIhdr, LIdat: TBytes;
  I: Integer;
begin
  SetLength(Result, 8);
  for I := 0 to 7 do
    Result[I] := kSig[I];
  SetLength(LIhdr, 13);
  LIhdr[0] := Byte((AW shr 24) and $FF);
  LIhdr[1] := Byte((AW shr 16) and $FF);
  LIhdr[2] := Byte((AW shr 8) and $FF);
  LIhdr[3] := Byte(AW and $FF);
  LIhdr[4] := Byte((AH shr 24) and $FF);
  LIhdr[5] := Byte((AH shr 16) and $FF);
  LIhdr[6] := Byte((AH shr 8) and $FF);
  LIhdr[7] := Byte(AH and $FF);
  LIhdr[8] := Byte(ADepth);
  LIhdr[9] := Byte(AColor);
  LIhdr[10] := 0;
  LIhdr[11] := 0;
  LIhdr[12] := Byte(AInterlace);
  AppendChunk(Result, 'IHDR', LIhdr);
  LIdat := DeflateCompress(ARaw);
  if ASplitIdat then
  begin
    AppendChunk(Result, 'IDAT', Copy(LIdat, 0, Length(LIdat) div 2));
    AppendChunk(Result, 'IDAT', Copy(LIdat, Length(LIdat) div 2,
      Length(LIdat) - Length(LIdat) div 2));
  end
  else
    AppendChunk(Result, 'IDAT', LIdat);
  AppendChunk(Result, 'IEND', nil);
end;

{ 正向滤波（复刻 PNG 规范）：RGBA 原图 → filtered scanlines，
  每行 filter 类型取自 AFilters[y]（bpp=4）。 }
function FilterRgbaRows(const APixels: TBytes; AW, AH: Integer;
  const AFilters: array of Integer): TBytes;
var
  X, Y, C, Bpp, RowLen, FT, ALeft, AUp, AUL, Pred: Integer;

  function RawAt(AX, AY, AC: Integer): Integer;
  begin
    if (AX < 0) or (AY < 0) then
      Result := 0
    else
      Result := APixels[(AY * AW + AX) * 4 + AC];
  end;

  function Paeth(A, B, C: Integer): Integer;
  var
    P, PA, PB, PC: Integer;
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
  Bpp := 4;
  RowLen := AW * Bpp;
  SetLength(Result, (RowLen + 1) * AH);
  for Y := 0 to AH - 1 do
  begin
    FT := AFilters[Y];
    Result[Y * (RowLen + 1)] := Byte(FT);
    for X := 0 to AW - 1 do
      for C := 0 to 3 do
      begin
        ALeft := RawAt(X - 1, Y, C);
        AUp := RawAt(X, Y - 1, C);
        AUL := RawAt(X - 1, Y - 1, C);
        case FT of
          0: Pred := 0;
          1: Pred := ALeft;
          2: Pred := AUp;
          3: Pred := (ALeft + AUp) div 2;
          4: Pred := Paeth(ALeft, AUp, AUL);
        else
          Pred := 0;
        end;
        Result[Y * (RowLen + 1) + 1 + X * 4 + C] :=
          Byte((RawAt(X, Y, C) - Pred) and $FF);
      end;
  end;
end;

procedure TestDecodeRoundTrip;
const
  W = 4;
  H = 3;
var
  Pixels, Png, Dec: TBytes;
  DW, DH, I: Integer;
begin
  SetLength(Pixels, W * H * 4);
  for I := 0 to W * H - 1 do
  begin
    Pixels[I * 4] := Byte((I * 37 + 11) and $FF);
    Pixels[I * 4 + 1] := Byte((I * 53 + 7) and $FF);
    Pixels[I * 4 + 2] := Byte((I * 91 + 200) and $FF);
    Pixels[I * 4 + 3] := Byte(255 - I * 20);
  end;
  Png := PngEncodeRgba(Pixels, W, H);
  Dec := PngDecodeRgba(Png, DW, DH);
  CheckEqual(DW, W, 'decode width');
  CheckEqual(DH, H, 'decode height');
  CheckEqual(Length(Dec), Length(Pixels), 'decode buffer size');
  for I := 0 to Length(Pixels) - 1 do
    CheckEqual(Dec[I], Pixels[I], 'roundtrip byte ' + IntToStr(I));
end;

{ 四行分别用 filter 1/2/3/4（第 0 行 Up/Avg/Paeth 引虚拟全 0 上行），
  解码输出必须还原原图——反滤波五分支全覆盖 }
procedure TestDecodeFilters1234;
const
  W = 5;
  H = 4;
var
  Pixels, Raw, Png, Dec: TBytes;
  Filters: array[0..3] of Integer;
  DW, DH, I: Integer;
begin
  SetLength(Pixels, W * H * 4);
  for I := 0 to W * H - 1 do
  begin
    Pixels[I * 4] := Byte((I * 71) and $FF);
    Pixels[I * 4 + 1] := Byte((I * 29 + 100) and $FF);
    Pixels[I * 4 + 2] := Byte((I * 13 + 3) and $FF);
    Pixels[I * 4 + 3] := $FF;
  end;
  Filters[0] := 1;
  Filters[1] := 2;
  Filters[2] := 3;
  Filters[3] := 4;
  Raw := FilterRgbaRows(Pixels, W, H, Filters);
  Png := BuildTestPng(W, H, 8, 6, 0, Raw, False);
  Dec := PngDecodeRgba(Png, DW, DH);
  CheckEqual(DW, W, 'filters decode width');
  CheckEqual(DH, H, 'filters decode height');
  CheckEqual(Length(Dec), Length(Pixels), 'filters buffer size');
  for I := 0 to Length(Pixels) - 1 do
    CheckEqual(Dec[I], Pixels[I], 'filter byte ' + IntToStr(I));
end;

{ 色型 0（8bit 灰度）与 2（RGB）：灰度 g → (g,g,g,255)；RGB → (+FF alpha) }
procedure TestDecodeGrayAndRgb;
var
  Raw, Png, Dec: TBytes;
  DW, DH: Integer;
begin
  { 灰度 1x2：raw = filter0 行 [10] + filter0 行 [200] }
  SetLength(Raw, 4);
  Raw[0] := 0; Raw[1] := 10;
  Raw[2] := 0; Raw[3] := 200;
  Png := BuildTestPng(1, 2, 8, 0, 0, Raw, False);
  Dec := PngDecodeRgba(Png, DW, DH);
  CheckEqual(DW, 1, 'gray w');
  CheckEqual(DH, 2, 'gray h');
  CheckEqual(Length(Dec), 8, 'gray size');
  CheckEqual(Dec[0], 10, 'gray0 r');
  CheckEqual(Dec[1], 10, 'gray0 g');
  CheckEqual(Dec[2], 10, 'gray0 b');
  CheckEqual(Dec[3], 255, 'gray0 a=255');
  CheckEqual(Dec[4], 200, 'gray1 r');
  CheckEqual(Dec[7], 255, 'gray1 a');
  { RGB 1x2：行 = filter0 + r g b }
  SetLength(Raw, 8);
  Raw[0] := 0; Raw[1] := $11; Raw[2] := $22; Raw[3] := $33;
  Raw[4] := 0; Raw[5] := $AA; Raw[6] := $BB; Raw[7] := $CC;
  Png := BuildTestPng(1, 2, 8, 2, 0, Raw, False);
  Dec := PngDecodeRgba(Png, DW, DH);
  CheckEqual(Length(Dec), 8, 'rgb size');
  CheckEqual(Dec[0], $11, 'rgb0 r');
  CheckEqual(Dec[1], $22, 'rgb0 g');
  CheckEqual(Dec[2], $33, 'rgb0 b');
  CheckEqual(Dec[3], 255, 'rgb0 a=255');
  CheckEqual(Dec[4], $AA, 'rgb1 r');
end;

{ 多 IDAT 聚合 + 拒绝面矩阵 }
procedure ExpectDecodeRaise(const AData: TBytes; AClass: TClass;
  const AMsg: string);
var
  X, Y: Integer;
begin
  try
    PngDecodeRgba(AData, X, Y);
    Check(False, AMsg + ': no raise');
  except
    on E: TObject do
      Check(E.ClassType = AClass, AMsg + ': got ' + E.ClassName);
  end;
end;

procedure TestDecodeMultiIdatAndRejects;
var
  Raw, Png, Dec: TBytes;
  DW, DH: Integer;
begin
  SetLength(Raw, 2);
  Raw[0] := 0; Raw[1] := 128;
  Png := BuildTestPng(1, 1, 8, 0, 0, Raw, True);
  Dec := PngDecodeRgba(Png, DW, DH);
  CheckEqual(Length(Dec), 4, 'multi-idat decode ok');
  CheckEqual(Dec[0], 128, 'multi-idat pixel');

  { 坏签名 }
  Png := BuildTestPng(1, 1, 8, 6, 0, nil, False);
  Png[1] := $50 xor $01;
  ExpectDecodeRaise(Png, EIOError, 'bad signature rejected');
  { 截断（< 8 字节） }
  SetLength(Png, 5);
  ExpectDecodeRaise(Png, EIOError, 'truncated rejected');
  { 位深 16 拒 }
  Png := BuildTestPng(1, 1, 16, 6, 0, nil, False);
  ExpectDecodeRaise(Png, EArgumentError, 'depth 16 rejected');
  { 色型 3（调色板）拒 }
  Png := BuildTestPng(1, 1, 8, 3, 0, nil, False);
  ExpectDecodeRaise(Png, EArgumentError, 'palette rejected');
  { 隔行拒 }
  Png := BuildTestPng(1, 1, 8, 6, 1, nil, False);
  ExpectDecodeRaise(Png, EArgumentError, 'interlace rejected');
  { 宽 0 拒 }
  Png := BuildTestPng(0, 1, 8, 6, 0, nil, False);
  ExpectDecodeRaise(Png, EArgumentError, 'zero width rejected');
  { IHDR CRC 错拒——必须基于完全有效的 PNG（raw 与 color type 一致、
    IDAT 非空），否则解码会在 CRC 之前的其他校验处抛同类错误掩盖本断言
    （k54 辨别②两轮实证：missing-IDAT / size-mismatch 先后掩盖） }
  SetLength(Raw, 5);
  Raw[0] := 0; Raw[1] := $10; Raw[2] := $20; Raw[3] := $30; Raw[4] := $FF;
  Png := BuildTestPng(1, 1, 8, 6, 0, Raw, False);
  Png[29] := Png[29] xor $FF;
  ExpectDecodeRaise(Png, EIOError, 'ihdr crc mismatch rejected');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.image.png');
  T.Test('red 2x2 structure', @TestRed2x2);
  T.Test('gradient 1x3 pixels', @TestGradient1x3);
  T.Test('bad arguments', @TestBadArgs);
  T.Test('decode roundtrip', @TestDecodeRoundTrip);
  T.Test('decode filters 1-4', @TestDecodeFilters1234);
  T.Test('decode gray and rgb', @TestDecodeGrayAndRgb);
  T.Test('decode multi-idat and rejects', @TestDecodeMultiIdatAndRejects);
  if not T.Run then Halt(1);
end.