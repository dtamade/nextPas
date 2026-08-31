unit nextpas.core.hash.blake2s;

{$mode objfpc}{$H+}

{ nextpas.core.hash.blake2s — RFC 7693 BLAKE2s-256（无密钥）。
  WireGuard Noise_IKpsk2_ChaChaPoly_BLAKE2s 专用哈希，S2 热路径共用。 }

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.hash.intf,
  nextpas.core.hash.util;

const
  BLAKE2S256_DIGEST_SIZE = 32;
  BLAKE2S_BLOCK_SIZE = 64;

type
  TBLAKE2s256Digest = array[0..31] of Byte;

  TBLAKE2s256Hasher = class(TInterfacedObject, IHasher)
  private
    FH: array[0..7] of UInt32;
    FBuf: array[0..63] of Byte;
    FBufLen: SizeUInt;
    FTotalLen: UInt32;
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

function NewBLAKE2s256: IHasher;
function BLAKE2s256Of(const ABuf; ALen: SizeUInt): TBLAKE2s256Digest;

implementation

uses
  nextpas.core.errors;

const
  IV: array[0..7] of UInt32 = (
    UInt32($6A09E667), UInt32($BB67AE85),
    UInt32($3C6EF372), UInt32($A54FF53A),
    UInt32($510E527F), UInt32($9B05688C),
    UInt32($1F83D9AB), UInt32($5BE0CD19)
  );

  SIGMA: array[0..9, 0..15] of Byte = (
    ( 0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15),
    (14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3),
    (11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4),
    ( 7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8),
    ( 9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13),
    ( 2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9),
    (12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11),
    (13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10),
    ( 6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5),
    (10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13,  0)
  );

function Ror32(AX: UInt32; AN: Integer): UInt32; inline;
begin
  Result := (AX shr AN) or (AX shl (32 - AN));
end;

function Load32LE(ASrc: PByte): UInt32; inline;
begin
  Result := UInt32(ASrc[0]) or (UInt32(ASrc[1]) shl 8) or
    (UInt32(ASrc[2]) shl 16) or (UInt32(ASrc[3]) shl 24);
end;

procedure Mix(var V: array of UInt32; AA, AB, AC, AD: Integer; AX, AY: UInt32); inline;
begin
  V[AA] := V[AA] + V[AB] + AX;
  V[AD] := Ror32(V[AD] xor V[AA], 16);
  V[AC] := V[AC] + V[AD];
  V[AB] := Ror32(V[AB] xor V[AC], 12);
  V[AA] := V[AA] + V[AB] + AY;
  V[AD] := Ror32(V[AD] xor V[AA], 8);
  V[AC] := V[AC] + V[AD];
  V[AB] := Ror32(V[AB] xor V[AC], 7);
end;

constructor TBLAKE2s256Hasher.Create;
begin
  inherited Create;
  Reset;
end;

procedure TBLAKE2s256Hasher.Reset;
var LI: Integer;
begin
  for LI := 0 to 7 do FH[LI] := IV[LI];
  FH[0] := FH[0] xor UInt32($01010020);
  FBufLen := 0; FTotalLen := 0;
end;

procedure TBLAKE2s256Hasher.Compress(ABlock: PByte; ALast: Boolean);
var V: array[0..15] of UInt32; M: array[0..15] of UInt32; LI, LR: Integer;
begin
  for LI := 0 to 15 do M[LI] := Load32LE(ABlock + LI * 4);
  for LI := 0 to 7 do begin V[LI] := FH[LI]; V[LI+8] := IV[LI]; end;
  V[12] := V[12] xor FTotalLen;
  if ALast then V[14] := not V[14];
  for LR := 0 to 9 do begin
    Mix(V, 0, 4,  8, 12, M[SIGMA[LR, 0]], M[SIGMA[LR, 1]]);
    Mix(V, 1, 5,  9, 13, M[SIGMA[LR, 2]], M[SIGMA[LR, 3]]);
    Mix(V, 2, 6, 10, 14, M[SIGMA[LR, 4]], M[SIGMA[LR, 5]]);
    Mix(V, 3, 7, 11, 15, M[SIGMA[LR, 6]], M[SIGMA[LR, 7]]);
    Mix(V, 0, 5, 10, 15, M[SIGMA[LR, 8]], M[SIGMA[LR, 9]]);
    Mix(V, 1, 6, 11, 12, M[SIGMA[LR,10]], M[SIGMA[LR,11]]);
    Mix(V, 2, 7,  8, 13, M[SIGMA[LR,12]], M[SIGMA[LR,13]]);
    Mix(V, 3, 4,  9, 14, M[SIGMA[LR,14]], M[SIGMA[LR,15]]);
  end;
  for LI := 0 to 7 do FH[LI] := FH[LI] xor V[LI] xor V[LI+8];
end;

function TBLAKE2s256Hasher.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var LSrc: PByte; LRemaining, LCopy: SizeUInt;
begin
  Result := ACount;
  HashRequireTotalLength(FTotalLen, ACount, 'BLAKE2s256.Write');
  HashRequireBuffer(ABuf, ACount, 'BLAKE2s256.Write');
  LSrc := @ABuf; LRemaining := ACount;
  while LRemaining > 0 do begin
    if FBufLen = BLAKE2S_BLOCK_SIZE then begin Inc(FTotalLen, BLAKE2S_BLOCK_SIZE); Compress(@FBuf[0], False); FBufLen := 0; end;
    LCopy := BLAKE2S_BLOCK_SIZE - FBufLen; if LCopy > LRemaining then LCopy := LRemaining;
    Move(LSrc^, FBuf[FBufLen], LCopy); Inc(FBufLen, LCopy); Inc(LSrc, LCopy); Dec(LRemaining, LCopy);
  end;
end;

procedure TBLAKE2s256Hasher.Sum(out ADst; const ASize: SizeUInt);
var LClone: TBLAKE2s256Hasher; LOutSize: SizeUInt; LDst: PByte; LI: Integer;
begin
  FillChar(ADst, 0, 0); LOutSize := DigestOutputSize(BLAKE2S256_DIGEST_SIZE, ASize);
  if LOutSize = 0 then Exit; HashRequireBuffer(ADst, LOutSize, 'BLAKE2s256.Sum');
  LClone := TBLAKE2s256Hasher.Create; try
    Move(FH[0], LClone.FH[0], SizeOf(FH)); Move(FBuf[0], LClone.FBuf[0], SizeOf(FBuf));
    LClone.FBufLen := FBufLen; LClone.FTotalLen := FTotalLen + UInt32(FBufLen);
    FillChar(LClone.FBuf[FBufLen], SizeOf(FBuf) - FBufLen, 0);
    LClone.Compress(@LClone.FBuf[0], True); LDst := @ADst;
    for LI := 0 to 7 do begin
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI)*4, Byte(LClone.FH[LI]));
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI)*4+1, Byte(LClone.FH[LI] shr 8));
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI)*4+2, Byte(LClone.FH[LI] shr 16));
      WriteDigestByte(LDst, LOutSize, SizeUInt(LI)*4+3, Byte(LClone.FH[LI] shr 24));
    end; finally LClone.Free; end;
end;

function TBLAKE2s256Hasher.SumBytes: TBytes;
begin Result:=nil; SetLength(Result, BLAKE2S256_DIGEST_SIZE); Sum(Result[0], BLAKE2S256_DIGEST_SIZE); end;
function TBLAKE2s256Hasher.DigestSize: SizeUInt; begin Result:=BLAKE2S256_DIGEST_SIZE; end;
function TBLAKE2s256Hasher.BlockSize: SizeUInt; begin Result:=BLAKE2S_BLOCK_SIZE; end;
function TBLAKE2s256Hasher.Clone: IHasher;
var LClone: TBLAKE2s256Hasher;
begin LClone:=TBLAKE2s256Hasher.Create; Move(FH[0], LClone.FH[0], SizeOf(FH)); Move(FBuf[0], LClone.FBuf[0], SizeOf(FBuf)); LClone.FBufLen:=FBufLen; LClone.FTotalLen:=FTotalLen; Result:=LClone; end;
function NewBLAKE2s256: IHasher; begin Result:=TBLAKE2s256Hasher.Create; end;
function BLAKE2s256Of(const ABuf; ALen: SizeUInt): TBLAKE2s256Digest;
var LH: IHasher; begin LH:=NewBLAKE2s256; if ALen>0 then LH.Write(ABuf, ALen); LH.Sum(Result, BLAKE2S256_DIGEST_SIZE); end;
end.
