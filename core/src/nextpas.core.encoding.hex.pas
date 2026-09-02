unit nextpas.core.encoding.hex;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.encoding.base;

function HexEncode(const AData: TBytes; const ACase: THexCase = hcLower): string;
function HexDecode(const AHex: string): TBytes;
function HexVal(C: Char): Integer; inline;
function UuidHexToBytes(const AUUIDHex: string): TBytes;
{ respack.embed 单源复用：上层 $XX 发射 inline 零拷贝直通此表，不再手写 HEX 常量 }
function HexNibbleUpper(const ANibble: Byte): Char; inline;
procedure HexEncodeByteUpper(const AByte: Byte; const ADst: PChar); inline;
{ 批量向量化：上层 respack.embed $XX / $XX, 发射 4-wide 展开，外联守红线2、HEX_UPPER 单源零拷贝直通，单次大块写入，避免逐字节调用开销 }
procedure HexEncodeDollarBulkUpper(const ASrc: PByte; const ACount: SizeUInt; const ADst: PByte);
procedure HexEncodeDollarCommaBulkUpper(const ASrc: PByte; const ACount: SizeUInt; const ADst: PByte);
{ 批量向量化：上层 respack.embed $XX / $XX, 发射 4-wide 展开，inline 零拷贝直通 HEX_UPPER 单源，单次大块写入，避免逐字节调用开销 }
procedure HexEncodeDollarBulkUpper(const ASrc: PByte; const ACount: SizeUInt; const ADst: PByte); inline;
procedure HexEncodeDollarCommaBulkUpper(const ASrc: PByte; const ACount: SizeUInt; const ADst: PByte); inline;

implementation

const
  HEX_LOWER: array[0..15] of Char = '0123456789abcdef';
  HEX_UPPER: array[0..15] of Char = '0123456789ABCDEF';

var
  HEX_DECODE_TABLE: array[0..255] of ShortInt;
  HexDecodeTableInitialized: Boolean = False;

procedure InitHexDecodeTable;
var i: Integer;
begin
  if HexDecodeTableInitialized then Exit;
  { $FF 作为 byte 填充值，按 ShortInt 读出即 -1（非 hex 字符哨兵） }
  FillChar(HEX_DECODE_TABLE, SizeOf(HEX_DECODE_TABLE), $FF);
  for i := 0 to 9 do
  begin
    HEX_DECODE_TABLE[Ord('0') + i] := i;
  end;
  for i := 0 to 5 do
  begin
    HEX_DECODE_TABLE[Ord('a') + i] := 10 + i;
    HEX_DECODE_TABLE[Ord('A') + i] := 10 + i;
  end;
  HexDecodeTableInitialized := True;
end;

function HexEncode(const AData: TBytes; const ACase: THexCase): string;
var
  LI, LLen: Integer;
  LP: PByte;
  LD: PChar;
  LTable: PChar;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit('');

  SetLength(Result, LLen * 2);
  LP := @AData[0];
  LD := @Result[1];

  case Ord(ACase) of
    Ord(hcLower): LTable := @HEX_LOWER[0];
    Ord(hcUpper): LTable := @HEX_UPPER[0];
  else
    raise EConvertError.Create('Invalid hex case');
  end;

  LI := 0;
  while LI + 4 <= LLen do
  begin
    LD[0] := LTable[LP[LI] shr 4];
    LD[1] := LTable[LP[LI] and $0F];
    LD[2] := LTable[LP[LI+1] shr 4];
    LD[3] := LTable[LP[LI+1] and $0F];
    LD[4] := LTable[LP[LI+2] shr 4];
    LD[5] := LTable[LP[LI+2] and $0F];
    LD[6] := LTable[LP[LI+3] shr 4];
    LD[7] := LTable[LP[LI+3] and $0F];
    Inc(LI, 4);
    Inc(LD, 8);
  end;
  while LI < LLen do
  begin
    LD[0] := LTable[LP[LI] shr 4];
    LD[1] := LTable[LP[LI] and $0F];
    Inc(LI);
    Inc(LD, 2);
  end;
end;

function HexCharToNibble(const ACh: Char): Byte; inline;
begin
  case ACh of
    '0'..'9': Result := Ord(ACh) - Ord('0');
    'a'..'f': Result := Ord(ACh) - Ord('a') + 10;
    'A'..'F': Result := Ord(ACh) - Ord('A') + 10;
  else
    raise EConvertError.CreateFmt('Invalid hex character: %s', [ACh]);
  end;
end;

function HexDecode(const AHex: string): TBytes;
var
  LLen, LI: Integer;
  LP: PByte;
  LD: PByte;
  LHi, LLo: ShortInt;
begin
  Result := nil;
  LLen := Length(AHex);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  if (LLen mod 2) <> 0 then
    raise EConvertError.Create('Hex string must have even length');

  InitHexDecodeTable;
  SetLength(Result, LLen div 2);
  LP := PByte(@AHex[1]);
  LD := @Result[0];

  LI := 0;
  while LI + 8 <= LLen do
  begin
    LHi := HEX_DECODE_TABLE[LP[LI]]; LLo := HEX_DECODE_TABLE[LP[LI+1]];
    if (LHi or LLo) < 0 then raise EConvertError.Create('Invalid hex character');
    LD^ := Byte(LHi shl 4) or Byte(LLo); Inc(LD);

    LHi := HEX_DECODE_TABLE[LP[LI+2]]; LLo := HEX_DECODE_TABLE[LP[LI+3]];
    if (LHi or LLo) < 0 then raise EConvertError.Create('Invalid hex character');
    LD^ := Byte(LHi shl 4) or Byte(LLo); Inc(LD);

    LHi := HEX_DECODE_TABLE[LP[LI+4]]; LLo := HEX_DECODE_TABLE[LP[LI+5]];
    if (LHi or LLo) < 0 then raise EConvertError.Create('Invalid hex character');
    LD^ := Byte(LHi shl 4) or Byte(LLo); Inc(LD);

    LHi := HEX_DECODE_TABLE[LP[LI+6]]; LLo := HEX_DECODE_TABLE[LP[LI+7]];
    if (LHi or LLo) < 0 then raise EConvertError.Create('Invalid hex character');
    LD^ := Byte(LHi shl 4) or Byte(LLo); Inc(LD);

    Inc(LI, 8);
  end;
  while LI + 2 <= LLen do
  begin
    LHi := HEX_DECODE_TABLE[LP[LI]]; LLo := HEX_DECODE_TABLE[LP[LI+1]];
    if (LHi or LLo) < 0 then raise EConvertError.Create('Invalid hex character');
    LD^ := Byte(LHi shl 4) or Byte(LLo); Inc(LD);
    Inc(LI, 2);
  end;
end;

function HexVal(C: Char): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function HexNibbleUpper(const ANibble: Byte): Char; inline;
begin
  Result := HEX_UPPER[ANibble and $0F];
end;

procedure HexEncodeByteUpper(const AByte: Byte; const ADst: PChar); inline;
begin
  ADst[0] := HEX_UPPER[AByte shr 4];
  ADst[1] := HEX_UPPER[AByte and $0F];
end;

procedure HexEncodeDollarBulkUpper(const ASrc: PByte; const ACount: SizeUInt; const ADst: PByte);
var I: SizeUInt; S: PByte; D: PByte;
begin
  { 外联守 design-conventions §2 红线2：循环体不 inline，避 embed 热点 I-Cache 复制膨胀；内层 HEX_UPPER 单源零拷贝 }
procedure HexEncodeDollarBulkUpper(const ASrc: PByte; const ACount: SizeUInt; const ADst: PByte); inline;
var I: SizeUInt; S: PByte; D: PByte;
begin
  if ACount = 0 then Exit;
  S := ASrc; D := ADst; I := 0;
  while I + 4 <= ACount do
  begin
    D[0] := Byte('$'); D[1] := Byte(HEX_UPPER[S[0] shr 4]); D[2] := Byte(HEX_UPPER[S[0] and $0F]);
    D[3] := Byte('$'); D[4] := Byte(HEX_UPPER[S[1] shr 4]); D[5] := Byte(HEX_UPPER[S[1] and $0F]);
    D[6] := Byte('$'); D[7] := Byte(HEX_UPPER[S[2] shr 4]); D[8] := Byte(HEX_UPPER[S[2] and $0F]);
    D[9] := Byte('$'); D[10] := Byte(HEX_UPPER[S[3] shr 4]); D[11] := Byte(HEX_UPPER[S[3] and $0F]);
    Inc(S, 4); Inc(D, 12); Inc(I, 4);
  end;
  while I < ACount do
  begin
    D[0] := Byte('$'); D[1] := Byte(HEX_UPPER[S^ shr 4]); D[2] := Byte(HEX_UPPER[S^ and $0F]);
    Inc(S); Inc(D, 3); Inc(I);
  end;
end;

procedure HexEncodeDollarCommaBulkUpper(const ASrc: PByte; const ACount: SizeUInt; const ADst: PByte);
var I: SizeUInt; S: PByte; D: PByte;
begin
  { 外联守 design-conventions §2 红线2：循环体不 inline，避 embed 热点 I-Cache 复制膨胀；内层 HEX_UPPER 单源零拷贝 }
procedure HexEncodeDollarCommaBulkUpper(const ASrc: PByte; const ACount: SizeUInt; const ADst: PByte); inline;
var I: SizeUInt; S: PByte; D: PByte;
begin
  if ACount = 0 then Exit;
  S := ASrc; D := ADst; I := 0;
  while I + 4 <= ACount do
  begin
    D[0] := Byte('$'); D[1] := Byte(HEX_UPPER[S[0] shr 4]); D[2] := Byte(HEX_UPPER[S[0] and $0F]); D[3] := Byte(',');
    D[4] := Byte('$'); D[5] := Byte(HEX_UPPER[S[1] shr 4]); D[6] := Byte(HEX_UPPER[S[1] and $0F]); D[7] := Byte(',');
    D[8] := Byte('$'); D[9] := Byte(HEX_UPPER[S[2] shr 4]); D[10] := Byte(HEX_UPPER[S[2] and $0F]); D[11] := Byte(',');
    D[12] := Byte('$'); D[13] := Byte(HEX_UPPER[S[3] shr 4]); D[14] := Byte(HEX_UPPER[S[3] and $0F]); D[15] := Byte(',');
    Inc(S, 4); Inc(D, 16); Inc(I, 4);
  end;
  while I < ACount do
  begin
    D[0] := Byte('$'); D[1] := Byte(HEX_UPPER[S^ shr 4]); D[2] := Byte(HEX_UPPER[S^ and $0F]); D[3] := Byte(',');
    Inc(S); Inc(D, 4); Inc(I);
  end;
end;

function UuidHexToBytes(const AUUIDHex: string): TBytes;
var LRaw: array[0..15] of Byte;
  LP, LI, LNib: Integer;
begin
  Result := nil;
  if Length(AUUIDHex) = 0 then Exit;
  FillChar(LRaw[0], SizeOf(LRaw), 0);
  LP := 0;
  for LI := 1 to Length(AUUIDHex) do
  begin
    if AUUIDHex[LI] = '-' then Continue;
    LNib := HexVal(AUUIDHex[LI]);
    if LNib < 0 then Exit;
    if Odd(LP) then
      LRaw[LP shr 1] := (LRaw[LP shr 1] shl 4) or Byte(LNib)
    else
      LRaw[LP shr 1] := Byte(LNib);
    Inc(LP);
  end;
  if LP <> 32 then Exit;
  SetLength(Result, 16);
  Move(LRaw[0], Result[0], 16);
end;

initialization
  InitHexDecodeTable;

end.
