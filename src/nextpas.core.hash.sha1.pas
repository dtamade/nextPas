unit nextpas.core.hash.sha1;

{$mode objfpc}{$H+}

{ nextpas.core.hash.sha1 — SHA-1 实现 (FIPS 180-4)

  注意：SHA-1 已被 NIST 废弃用于数字签名。仅用于兼容性场景。
}

interface

uses
  SysUtils,
  nextpas.core.io.intf,
  nextpas.core.hash.base,
  nextpas.core.hash.intf;

type
  TSHA1Hasher = class(TInterfacedObject, IHasher)
  private
    FH: array[0..4] of UInt32;
    FBuf: array[0..63] of Byte;
    FBufLen: SizeUInt;
    FTotalLen: UInt64;
  public
    constructor Create;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Sum(out ADst; const ASize: SizeUInt);
    function SumBytes: TBytes;
    procedure Reset;
    function DigestSize: SizeUInt;
    function BlockSize: SizeUInt;
  end;

function NewSHA1: IHasher;

implementation

function RL32(AX: UInt32; AN: Integer): UInt32; inline;
begin
  Result := (AX shl AN) or (AX shr (32 - AN));
end;

procedure SHA1ProcessBlock(ABlock: PByte; var AH: array of UInt32);
var
  W: array[0..79] of UInt32;
  A, B, C, D, E, F, K, Tmp: UInt32;
  I: Integer;
begin
  for I := 0 to 15 do
    W[I] := (UInt32(ABlock[I*4]) shl 24) or (UInt32(ABlock[I*4+1]) shl 16)
          or (UInt32(ABlock[I*4+2]) shl 8) or UInt32(ABlock[I*4+3]);

  for I := 16 to 79 do
    W[I] := RL32(W[I-3] xor W[I-8] xor W[I-14] xor W[I-16], 1);

  A := AH[0]; B := AH[1]; C := AH[2]; D := AH[3]; E := AH[4];

  for I := 0 to 79 do
  begin
    case I div 20 of
      0: begin F := (B and C) or ((not B) and D); K := $5A827999; end;
      1: begin F := B xor C xor D;                K := $6ED9EBA1; end;
      2: begin F := (B and C) or (B and D) or (C and D); K := $8F1BBCDC; end;
      3: begin F := B xor C xor D;                K := $CA62C1D6; end;
    end;
    Tmp := RL32(A, 5) + F + E + K + W[I];
    E := D; D := C; C := RL32(B, 30); B := A; A := Tmp;
  end;

  Inc(AH[0], A); Inc(AH[1], B); Inc(AH[2], C); Inc(AH[3], D); Inc(AH[4], E);
end;

constructor TSHA1Hasher.Create;
begin
  inherited Create;
  Reset;
end;

procedure TSHA1Hasher.Reset;
begin
  FH[0] := $67452301; FH[1] := $EFCDAB89;
  FH[2] := $98BADCFE; FH[3] := $10325476;
  FH[4] := $C3D2E1F0;
  FBufLen := 0;
  FTotalLen := 0;
end;

function TSHA1Hasher.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSrc: PByte;
  LRemaining, LCopy: SizeUInt;
begin
  Result := ACount;
  LSrc := @ABuf;
  LRemaining := ACount;
  Inc(FTotalLen, ACount);

  if FBufLen > 0 then
  begin
    LCopy := SHA1_BLOCK_SIZE - FBufLen;
    if LCopy > LRemaining then LCopy := LRemaining;
    Move(LSrc^, FBuf[FBufLen], LCopy);
    Inc(FBufLen, LCopy); Inc(LSrc, LCopy); Dec(LRemaining, LCopy);
    if FBufLen = SHA1_BLOCK_SIZE then
    begin
      SHA1ProcessBlock(@FBuf[0], FH);
      FBufLen := 0;
    end;
  end;

  while LRemaining >= SHA1_BLOCK_SIZE do
  begin
    SHA1ProcessBlock(LSrc, FH);
    Inc(LSrc, SHA1_BLOCK_SIZE);
    Dec(LRemaining, SHA1_BLOCK_SIZE);
  end;

  if LRemaining > 0 then
  begin
    Move(LSrc^, FBuf[0], LRemaining);
    FBufLen := LRemaining;
  end;
end;

procedure TSHA1Hasher.Sum(out ADst; const ASize: SizeUInt);
var
  LH: array[0..4] of UInt32;
  LBuf: array[0..63] of Byte;
  LBufLen: SizeUInt;
  LTotalBits: UInt64;
  I: Integer;
  LDst: PByte;
begin
  Move(FH[0], LH[0], SizeOf(FH));
  Move(FBuf[0], LBuf[0], FBufLen);
  LBufLen := FBufLen;
  LTotalBits := FTotalLen * 8;

  LBuf[LBufLen] := $80; Inc(LBufLen);

  if LBufLen > 56 then
  begin
    while LBufLen < 64 do begin LBuf[LBufLen] := 0; Inc(LBufLen); end;
    SHA1ProcessBlock(@LBuf[0], LH);
    LBufLen := 0;
  end;

  while LBufLen < 56 do begin LBuf[LBufLen] := 0; Inc(LBufLen); end;

  LBuf[56] := Byte(LTotalBits shr 56); LBuf[57] := Byte(LTotalBits shr 48);
  LBuf[58] := Byte(LTotalBits shr 40); LBuf[59] := Byte(LTotalBits shr 32);
  LBuf[60] := Byte(LTotalBits shr 24); LBuf[61] := Byte(LTotalBits shr 16);
  LBuf[62] := Byte(LTotalBits shr 8);  LBuf[63] := Byte(LTotalBits);

  SHA1ProcessBlock(@LBuf[0], LH);

  LDst := @ADst;
  for I := 0 to 4 do
  begin
    LDst[I*4]   := Byte(LH[I] shr 24);
    LDst[I*4+1] := Byte(LH[I] shr 16);
    LDst[I*4+2] := Byte(LH[I] shr 8);
    LDst[I*4+3] := Byte(LH[I]);
  end;
end;

function TSHA1Hasher.SumBytes: TBytes;
begin
  SetLength(Result, SHA1_DIGEST_SIZE);
  Sum(Result[0], SHA1_DIGEST_SIZE);
end;

function TSHA1Hasher.DigestSize: SizeUInt;
begin
  Result := SHA1_DIGEST_SIZE;
end;

function TSHA1Hasher.BlockSize: SizeUInt;
begin
  Result := SHA1_BLOCK_SIZE;
end;

function NewSHA1: IHasher;
begin
  Result := TSHA1Hasher.Create;
end;

end.
