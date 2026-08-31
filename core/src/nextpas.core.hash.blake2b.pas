unit nextpas.core.hash.blake2b;

{$mode objfpc}{$H+}

{ nextpas.core.hash.blake2b — RFC 7693 BLAKE2b-256（无密钥）。
  Salamander / hysteria2 外层 UDP 混淆只需要 32 字节摘要。 }

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.hash.intf,
  nextpas.core.hash.util;

const
  BLAKE2B256_DIGEST_SIZE = 32;
  BLAKE2B_BLOCK_SIZE = 128;

type
  TBLAKE2b256Digest = array[0..31] of Byte;

  TBLAKE2b256Hasher = class(TInterfacedObject, IHasher)
  private
    FH: array[0..7] of UInt64;
    FBuf: array[0..127] of Byte;
    FBufLen: SizeUInt;
    FTotalLen: UInt64;
    procedure Compress(ABlock: PByte; ALast: Boolean);
  public
    constructor Create;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Sum(out ADst; const ASize: SizeUInt);
    function SumBytes: TBytes;
    procedure Reset;
    function DigestSize: SizeUInt;
    function BlockSize: SizeUInt;
    function Clone: IHasher;
  end;

function NewBLAKE2b256: IHasher;
function BLAKE2b256Of(const ABuf; ALen: SizeUInt): TBLAKE2b256Digest;

implementation

uses
  nextpas.core.errors;

const
  IV: array[0..7] of UInt64 = (
    UInt64($6A09E667F3BCC908), UInt64($BB67AE8584CAA73B),
    UInt64($3C6EF372FE94F82B), UInt64($A54FF53A5F1D36F1),
    UInt64($510E527FADE682D1), UInt64($9B05688C2B3E6C1F),
    UInt64($1F83D9ABFB41BD6B), UInt64($5BE0CD19137E2179)
  );

  SIGMA: array[0..11, 0..15] of Byte = (
    ( 0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15),
    (14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3),
    (11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4),
    ( 7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8),
    ( 9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13),
    ( 2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9),
    (12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11),
    (13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10),
    ( 6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5),
    (10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13,  0),
    ( 0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15),
    (14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3)
  );

function Ror64(AX: UInt64; AN: Integer): UInt64; inline;
begin
  Result := (AX shr AN) or (AX shl (64 - AN));
end;

function Load64LE(ASrc: PByte): UInt64; inline;
begin
  Result := UInt64(ASrc[0]) or (UInt64(ASrc[1]) shl 8) or
    (UInt64(ASrc[2]) shl 16) or (UInt64(ASrc[3]) shl 24) or
    (UInt64(ASrc[4]) shl 32) or (UInt64(ASrc[5]) shl 40) or
    (UInt64(ASrc[6]) shl 48) or (UInt64(ASrc[7]) shl 56);
end;

procedure Mix(var V: array of UInt64; AA, AB, AC, AD: Integer; AX, AY: UInt64);
begin
  V[AA] := V[AA] + V[AB] + AX;
  V[AD] := Ror64(V[AD] xor V[AA], 32);
  V[AC] := V[AC] + V[AD];
  V[AB] := Ror64(V[AB] xor V[AC], 24);
  V[AA] := V[AA] + V[AB] + AY;
  V[AD] := Ror64(V[AD] xor V[AA], 16);
  V[AC] := V[AC] + V[AD];
  V[AB] := Ror64(V[AB] xor V[AC], 63);
end;

constructor TBLAKE2b256Hasher.Create;
begin
  inherited Create;
  Reset;
end;

procedure TBLAKE2b256Hasher.Reset;
var
  LI: Integer;
begin
  for LI := 0 to 7 do
    FH[LI] := IV[LI];
  FH[0] := FH[0] xor UInt64($01010020);
  FBufLen := 0;
  FTotalLen := 0;
end;

procedure TBLAKE2b256Hasher.Compress(ABlock: PByte; ALast: Boolean);
var
  V: array[0..15] of UInt64;
  M: array[0..15] of UInt64;
  LI, LR: Integer;
begin
  for LI := 0 to 15 do
    M[LI] := Load64LE(ABlock + LI * 8);
  for LI := 0 to 7 do
  begin
    V[LI] := FH[LI];
    V[LI + 8] := IV[LI];
  end;
  V[12] := V[12] xor FTotalLen;
  if ALast then
    V[14] := not V[14];
  for LR := 0 to 11 do
  begin
    Mix(V, 0, 4,  8, 12, M[SIGMA[LR, 0]], M[SIGMA[LR, 1]]);
    Mix(V, 1, 5,  9, 13, M[SIGMA[LR, 2]], M[SIGMA[LR, 3]]);
    Mix(V, 2, 6, 10, 14, M[SIGMA[LR, 4]], M[SIGMA[LR, 5]]);
    Mix(V, 3, 7, 11, 15, M[SIGMA[LR, 6]], M[SIGMA[LR, 7]]);
    Mix(V, 0, 5, 10, 15, M[SIGMA[LR, 8]], M[SIGMA[LR, 9]]);
    Mix(V, 1, 6, 11, 12, M[SIGMA[LR,10]], M[SIGMA[LR,11]]);
    Mix(V, 2, 7,  8, 13, M[SIGMA[LR,12]], M[SIGMA[LR,13]]);
    Mix(V, 3, 4,  9, 14, M[SIGMA[LR,14]], M[SIGMA[LR,15]]);
  end;
  for LI := 0 to 7 do
    FH[LI] := FH[LI] xor V[LI] xor V[LI + 8];
end;

function TBLAKE2b256Hasher.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSrc: PByte;
  LRemaining, LCopy: SizeUInt;
begin
  Result := ACount;
  HashRequireTotalLength(FTotalLen, ACount, 'BLAKE2b256.Write');
  HashRequireBuffer(ABuf, ACount, 'BLAKE2b256.Write');
  LSrc := @ABuf;
  LRemaining := ACount;
  while LRemaining > 0 do
  begin
    if FBufLen = BLAKE2B_BLOCK_SIZE then
    begin
      Inc(FTotalLen, BLAKE2B_BLOCK_SIZE);
      Compress(@FBuf[0], False);
      FBufLen := 0;
    end;
    LCopy := BLAKE2B_BLOCK_SIZE - FBufLen;
    if LCopy > LRemaining then
      LCopy := LRemaining;
    Move(LSrc^, FBuf[FBufLen], LCopy);
    Inc(FBufLen, LCopy);
    Inc(LSrc, LCopy);
    Dec(LRemaining, LCopy);
  end;
end;

procedure TBLAKE2b256Hasher.Sum(out ADst; const ASize: SizeUInt);
var
  LClone: TBLAKE2b256Hasher;
  LOutSize: SizeUInt;
  LDst: PByte;
  LI: Integer;
begin
  FillChar(ADst, 0, 0);
  LOutSize := DigestOutputSize(BLAKE2B256_DIGEST_SIZE, ASize);
  if LOutSize = 0 then
    Exit;
  HashRequireBuffer(ADst, LOutSize, 'BLAKE2b256.Sum');
  LClone := TBLAKE2b256Hasher.Create;
  try
    Move(FH[0], LClone.FH[0], SizeOf(FH));
    Move(FBuf[0], LClone.FBuf[0], SizeOf(FBuf));
    LClone.FBufLen := FBufLen;
    LClone.FTotalLen := FTotalLen + FBufLen;
    FillChar(LClone.FBuf[FBufLen], SizeOf(FBuf) - FBufLen, 0);
    LClone.Compress(@LClone.FBuf[0], True);
    LDst := @ADst;
    for LI := 0 to 3 do
    begin
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI) * 8, Byte(LClone.FH[LI]));
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI) * 8 + 1, Byte(LClone.FH[LI] shr 8));
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI) * 8 + 2, Byte(LClone.FH[LI] shr 16));
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI) * 8 + 3, Byte(LClone.FH[LI] shr 24));
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI) * 8 + 4, Byte(LClone.FH[LI] shr 32));
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI) * 8 + 5, Byte(LClone.FH[LI] shr 40));
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI) * 8 + 6, Byte(LClone.FH[LI] shr 48));
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI) * 8 + 7, Byte(LClone.FH[LI] shr 56));
    end;
  finally
    LClone.Free;
  end;
end;

function TBLAKE2b256Hasher.SumBytes: TBytes;
begin
  Result := nil;
  SetLength(Result, BLAKE2B256_DIGEST_SIZE);
  Sum(Result[0], BLAKE2B256_DIGEST_SIZE);
end;

function TBLAKE2b256Hasher.DigestSize: SizeUInt;
begin
  Result := BLAKE2B256_DIGEST_SIZE;
end;

function TBLAKE2b256Hasher.BlockSize: SizeUInt;
begin
  Result := BLAKE2B_BLOCK_SIZE;
end;

function TBLAKE2b256Hasher.Clone: IHasher;
var
  LClone: TBLAKE2b256Hasher;
begin
  LClone := TBLAKE2b256Hasher.Create;
  Move(FH[0], LClone.FH[0], SizeOf(FH));
  Move(FBuf[0], LClone.FBuf[0], SizeOf(FBuf));
  LClone.FBufLen := FBufLen;
  LClone.FTotalLen := FTotalLen;
  Result := LClone;
end;

function NewBLAKE2b256: IHasher;
begin
  Result := TBLAKE2b256Hasher.Create;
end;

function BLAKE2b256Of(const ABuf; ALen: SizeUInt): TBLAKE2b256Digest;
var
  LH: IHasher;
begin
  LH := NewBLAKE2b256;
  if ALen > 0 then
    LH.Write(ABuf, ALen);
  LH.Sum(Result, BLAKE2B256_DIGEST_SIZE);
end;

end.
