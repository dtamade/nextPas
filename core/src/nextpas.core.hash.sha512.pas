unit nextpas.core.hash.sha512;

{$mode objfpc}{$H+}

{ nextpas.core.hash.sha512 — SHA-512 / SHA-384 实现 (FIPS 180-4)

  SHA-384 是 SHA-512 的截断变体（不同 IV，输出前 48 字节）。
  共享同一个 64-bit 压缩引擎。
}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash.util;

type
  TSHA512Hasher = class(TInterfacedObject, IHasher)
  private
    FH: array[0..7] of UInt64;
    FBuf: array[0..127] of Byte;
    FBufLen: SizeUInt;
    FTotalLen: UInt64;
    FIs384: Boolean;
    procedure ProcessBlock(ABlock: PByte);
  public
    constructor Create(AIs384: Boolean = False);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Sum(out ADst; const ASize: SizeUInt);
    function SumBytes: TBytes;
    procedure Reset;
    function DigestSize: SizeUInt;
    function BlockSize: SizeUInt;
    function Clone: IHasher;
  end;

function NewSHA512: IHasher;
function NewSHA384: IHasher;

implementation

const
  K: array[0..79] of UInt64 = (
    UInt64($428a2f98d728ae22), UInt64($7137449123ef65cd), UInt64($b5c0fbcfec4d3b2f), UInt64($e9b5dba58189dbbc),
    UInt64($3956c25bf348b538), UInt64($59f111f1b605d019), UInt64($923f82a4af194f9b), UInt64($ab1c5ed5da6d8118),
    UInt64($d807aa98a3030242), UInt64($12835b0145706fbe), UInt64($243185be4ee4b28c), UInt64($550c7dc3d5ffb4e2),
    UInt64($72be5d74f27b896f), UInt64($80deb1fe3b1696b1), UInt64($9bdc06a725c71235), UInt64($c19bf174cf692694),
    UInt64($e49b69c19ef14ad2), UInt64($efbe4786384f25e3), UInt64($0fc19dc68b8cd5b5), UInt64($240ca1cc77ac9c65),
    UInt64($2de92c6f592b0275), UInt64($4a7484aa6ea6e483), UInt64($5cb0a9dcbd41fbd4), UInt64($76f988da831153b5),
    UInt64($983e5152ee66dfab), UInt64($a831c66d2db43210), UInt64($b00327c898fb213f), UInt64($bf597fc7beef0ee4),
    UInt64($c6e00bf33da88fc2), UInt64($d5a79147930aa725), UInt64($06ca6351e003826f), UInt64($142929670a0e6e70),
    UInt64($27b70a8546d22ffc), UInt64($2e1b21385c26c926), UInt64($4d2c6dfc5ac42aed), UInt64($53380d139d95b3df),
    UInt64($650a73548baf63de), UInt64($766a0abb3c77b2a8), UInt64($81c2c92e47edaee6), UInt64($92722c851482353b),
    UInt64($a2bfe8a14cf10364), UInt64($a81a664bbc423001), UInt64($c24b8b70d0f89791), UInt64($c76c51a30654be30),
    UInt64($d192e819d6ef5218), UInt64($d69906245565a910), UInt64($f40e35855771202a), UInt64($106aa07032bbd1b8),
    UInt64($19a4c116b8d2d0c8), UInt64($1e376c085141ab53), UInt64($2748774cdf8eeb99), UInt64($34b0bcb5e19b48a8),
    UInt64($391c0cb3c5c95a63), UInt64($4ed8aa4ae3418acb), UInt64($5b9cca4f7763e373), UInt64($682e6ff3d6b2b8a3),
    UInt64($748f82ee5defb2fc), UInt64($78a5636f43172f60), UInt64($84c87814a1f0ab72), UInt64($8cc702081a6439ec),
    UInt64($90befffa23631e28), UInt64($a4506cebde82bde9), UInt64($bef9a3f7b2c67915), UInt64($c67178f2e372532b),
    UInt64($ca273eceea26619c), UInt64($d186b8c721c0c207), UInt64($eada7dd6cde0eb1e), UInt64($f57d4f7fee6ed178),
    UInt64($06f067aa72176fba), UInt64($0a637dc5a2c898a6), UInt64($113f9804bef90dae), UInt64($1b710b35131c471b),
    UInt64($28db77f523047d84), UInt64($32caab7b40c72493), UInt64($3c9ebe0a15c9bebc), UInt64($431d67c49c100d4c),
    UInt64($4cc5d4becb3e42b6), UInt64($597f299cfc657e2a), UInt64($5fcb6fab3ad6faec), UInt64($6c44198c4a475817)
  );

function RR64(AX: UInt64; AN: Integer): UInt64; inline;
begin
  Result := (AX shr AN) or (AX shl (64 - AN));
end;

{ The x86-64 asm fast paths are written for the SysV AMD64 register
  convention (rdi/rsi/rdx/rcx as first args), which is invalid on
  Windows x64 (rcx/rdx/r8/r9). Fall back to the portable Pascal
  implementation there. }
{$IFDEF CPUX86_64}
  {$IFNDEF WINDOWS}
    {$DEFINE HASH_X64_ASM}
  {$ENDIF}
{$ENDIF}

{$IFDEF HASH_X64_ASM}
{$I nextpas.core.hash.sha512.x64.inc}
{$ENDIF}

procedure ProcessBlockLocal512(ABlock: PByte; var AH: array of UInt64);
var
  W: array[0..79] of UInt64;
  A, B, C, D, E, F, G, H: UInt64;
  T1, T2: UInt64;
  I: Integer;
begin
  {$IFDEF HASH_X64_ASM}
  ProcessBlockX64_512(ABlock, AH);
  Exit;
  {$ENDIF}
  for I := 0 to 15 do
    W[I] := (UInt64(ABlock[I*8]) shl 56) or (UInt64(ABlock[I*8+1]) shl 48)
          or (UInt64(ABlock[I*8+2]) shl 40) or (UInt64(ABlock[I*8+3]) shl 32)
          or (UInt64(ABlock[I*8+4]) shl 24) or (UInt64(ABlock[I*8+5]) shl 16)
          or (UInt64(ABlock[I*8+6]) shl 8) or UInt64(ABlock[I*8+7]);

  for I := 16 to 79 do
    W[I] := (RR64(W[I-2],19) xor RR64(W[I-2],61) xor (W[I-2] shr 6))
           + W[I-7]
           + (RR64(W[I-15],1) xor RR64(W[I-15],8) xor (W[I-15] shr 7))
           + W[I-16];

  A := AH[0]; B := AH[1]; C := AH[2]; D := AH[3];
  E := AH[4]; F := AH[5]; G := AH[6]; H := AH[7];

  for I := 0 to 79 do
  begin
    T1 := H + (RR64(E,14) xor RR64(E,18) xor RR64(E,41))
        + ((E and F) xor ((not E) and G)) + K[I] + W[I];
    T2 := (RR64(A,28) xor RR64(A,34) xor RR64(A,39))
        + ((A and B) xor (A and C) xor (B and C));
    H := G; G := F; F := E; E := D + T1;
    D := C; C := B; B := A; A := T1 + T2;
  end;

  Inc(AH[0], A); Inc(AH[1], B); Inc(AH[2], C); Inc(AH[3], D);
  Inc(AH[4], E); Inc(AH[5], F); Inc(AH[6], G); Inc(AH[7], H);
end;

constructor TSHA512Hasher.Create(AIs384: Boolean);
begin
  inherited Create;
  FIs384 := AIs384;
  Reset;
end;

procedure TSHA512Hasher.Reset;
begin
  if FIs384 then
  begin
    FH[0] := UInt64($cbbb9d5dc1059ed8); FH[1] := UInt64($629a292a367cd507);
    FH[2] := UInt64($9159015a3070dd17); FH[3] := UInt64($152fecd8f70e5939);
    FH[4] := UInt64($67332667ffc00b31); FH[5] := UInt64($8eb44a8768581511);
    FH[6] := UInt64($db0c2e0d64f98fa7); FH[7] := UInt64($47b5481dbefa4fa4);
  end
  else
  begin
    FH[0] := UInt64($6a09e667f3bcc908); FH[1] := UInt64($bb67ae8584caa73b);
    FH[2] := UInt64($3c6ef372fe94f82b); FH[3] := UInt64($a54ff53a5f1d36f1);
    FH[4] := UInt64($510e527fade682d1); FH[5] := UInt64($9b05688c2b3e6c1f);
    FH[6] := UInt64($1f83d9abfb41bd6b); FH[7] := UInt64($5be0cd19137e2179);
  end;
  FBufLen := 0;
  FTotalLen := 0;
end;

procedure TSHA512Hasher.ProcessBlock(ABlock: PByte);
begin
  ProcessBlockLocal512(ABlock, FH);
end;

function TSHA512Hasher.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSrc: PByte;
  LRemaining, LCopy: SizeUInt;
begin
  Result := ACount;
  if FIs384 then
  begin
    HashRequireTotalLength(FTotalLen, ACount, 'SHA384.Write');
    HashRequireBuffer(ABuf, ACount, 'SHA384.Write');
  end
  else
  begin
    HashRequireTotalLength(FTotalLen, ACount, 'SHA512.Write');
    HashRequireBuffer(ABuf, ACount, 'SHA512.Write');
  end;
  LSrc := @ABuf;
  LRemaining := ACount;
  Inc(FTotalLen, ACount);

  if FBufLen > 0 then
  begin
    LCopy := SHA512_BLOCK_SIZE - FBufLen;
    if LCopy > LRemaining then LCopy := LRemaining;
    Move(LSrc^, FBuf[FBufLen], LCopy);
    Inc(FBufLen, LCopy);
    Inc(LSrc, LCopy);
    Dec(LRemaining, LCopy);
    if FBufLen = SHA512_BLOCK_SIZE then
    begin
      ProcessBlock(@FBuf[0]);
      FBufLen := 0;
    end;
  end;

  while LRemaining >= SHA512_BLOCK_SIZE do
  begin
    ProcessBlock(LSrc);
    Inc(LSrc, SHA512_BLOCK_SIZE);
    Dec(LRemaining, SHA512_BLOCK_SIZE);
  end;

  if LRemaining > 0 then
  begin
    Move(LSrc^, FBuf[0], LRemaining);
    FBufLen := LRemaining;
  end;
end;

procedure TSHA512Hasher.Sum(out ADst; const ASize: SizeUInt);
var
  LH: array[0..7] of UInt64;
  LBuf: array[0..127] of Byte;
  LBufLen: SizeUInt;
  LTotalBits: UInt64;
  I: Integer;
  LDst: PByte;
  LDigestSize: SizeUInt;
  LOutSize: SizeUInt;
begin
  FillChar(ADst, 0, 0);
  LDigestSize := SHA512_DIGEST_SIZE;
  if FIs384 then
    LDigestSize := SHA384_DIGEST_SIZE;
  LOutSize := DigestOutputSize(LDigestSize, ASize);
  if LOutSize = 0 then Exit;
  if FIs384 then
    HashRequireBuffer(ADst, LOutSize, 'SHA384.Sum')
  else
    HashRequireBuffer(ADst, LOutSize, 'SHA512.Sum');

  Move(FH[0], LH[0], SizeOf(FH));
  Move(FBuf[0], LBuf[0], FBufLen);
  LBufLen := FBufLen;
  LTotalBits := FTotalLen * 8;

  LBuf[LBufLen] := $80;
  Inc(LBufLen);

  if LBufLen > 112 then
  begin
    while LBufLen < 128 do begin LBuf[LBufLen] := 0; Inc(LBufLen); end;
    ProcessBlockLocal512(@LBuf[0], LH);
    LBufLen := 0;
  end;

  while LBufLen < 120 do begin LBuf[LBufLen] := 0; Inc(LBufLen); end;

  // 128-bit length field: bytes 112-119 are zero (from padding above),
  // bytes 120-127 hold the total bit count in big-endian.
  // This works because messages < 2^64 bits have zero high 64 bits.
  LBuf[120] := Byte(LTotalBits shr 56);
  LBuf[121] := Byte(LTotalBits shr 48);
  LBuf[122] := Byte(LTotalBits shr 40);
  LBuf[123] := Byte(LTotalBits shr 32);
  LBuf[124] := Byte(LTotalBits shr 24);
  LBuf[125] := Byte(LTotalBits shr 16);
  LBuf[126] := Byte(LTotalBits shr 8);
  LBuf[127] := Byte(LTotalBits);

  ProcessBlockLocal512(@LBuf[0], LH);

  LDst := @ADst;
  for I := 0 to (LDigestSize div 8) - 1 do
  begin
    WriteDigestByte(LDst, LOutSize, SizeUInt(I) * 8, Byte(LH[I] shr 56));
    WriteDigestByte(LDst, LOutSize, SizeUInt(I) * 8 + 1, Byte(LH[I] shr 48));
    WriteDigestByte(LDst, LOutSize, SizeUInt(I) * 8 + 2, Byte(LH[I] shr 40));
    WriteDigestByte(LDst, LOutSize, SizeUInt(I) * 8 + 3, Byte(LH[I] shr 32));
    WriteDigestByte(LDst, LOutSize, SizeUInt(I) * 8 + 4, Byte(LH[I] shr 24));
    WriteDigestByte(LDst, LOutSize, SizeUInt(I) * 8 + 5, Byte(LH[I] shr 16));
    WriteDigestByte(LDst, LOutSize, SizeUInt(I) * 8 + 6, Byte(LH[I] shr 8));
    WriteDigestByte(LDst, LOutSize, SizeUInt(I) * 8 + 7, Byte(LH[I]));
  end;
end;

function TSHA512Hasher.SumBytes: TBytes;
begin
  Result := nil;
  SetLength(Result, DigestSize);
  Sum(Result[0], DigestSize);
end;

function TSHA512Hasher.DigestSize: SizeUInt;
begin
  if FIs384 then Result := SHA384_DIGEST_SIZE
  else Result := SHA512_DIGEST_SIZE;
end;

function TSHA512Hasher.BlockSize: SizeUInt;
begin
  Result := SHA512_BLOCK_SIZE;
end;

function TSHA512Hasher.Clone: IHasher;
var
  LClone: TSHA512Hasher;
begin
  LClone := TSHA512Hasher.Create(FIs384);
  Move(FH[0], LClone.FH[0], SizeOf(FH));
  Move(FBuf[0], LClone.FBuf[0], SizeOf(FBuf));
  LClone.FBufLen := FBufLen;
  LClone.FTotalLen := FTotalLen;
  Result := LClone;
end;

function NewSHA512: IHasher;
begin
  Result := TSHA512Hasher.Create(False);
end;

function NewSHA384: IHasher;
begin
  Result := TSHA512Hasher.Create(True);
end;

end.
