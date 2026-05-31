unit nextpas.core.hash.md5;

{$mode objfpc}{$H+}

{ nextpas.core.hash.md5 — MD5 实现 (RFC 1321)

  注意：MD5 已不安全，仅用于兼容性场景（校验和、遗留协议）。
}

interface

uses
  SysUtils,
  nextpas.core.io.intf,
  nextpas.core.hash.base,
  nextpas.core.hash.intf;

type
  TMD5Hasher = class(TInterfacedObject, IHasher)
  private
    FA, FB, FC, FD: UInt32;
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
    function Clone: IHasher;
  end;

function NewMD5: IHasher;

implementation

function RL(AX: UInt32; AN: Integer): UInt32; inline;
begin
  Result := (AX shl AN) or (AX shr (32 - AN));
end;

const
  SHIFT: array[0..63] of Byte = (
    7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
    5, 9,14,20, 5, 9,14,20, 5, 9,14,20, 5, 9,14,20,
    4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
    6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21
  );
  KT: array[0..63] of UInt32 = (
    $d76aa478, $e8c7b756, $242070db, $c1bdceee,
    $f57c0faf, $4787c62a, $a8304613, $fd469501,
    $698098d8, $8b44f7af, $ffff5bb1, $895cd7be,
    $6b901122, $fd987193, $a679438e, $49b40821,
    $f61e2562, $c040b340, $265e5a51, $e9b6c7aa,
    $d62f105d, $02441453, $d8a1e681, $e7d3fbc8,
    $21e1cde6, $c33707d6, $f4d50d87, $455a14ed,
    $a9e3e905, $fcefa3f8, $676f02d9, $8d2a4c8a,
    $fffa3942, $8771f681, $6d9d6122, $fde5380c,
    $a4beea44, $4bdecfa9, $f6bb4b60, $bebfbc70,
    $289b7ec6, $eaa127fa, $d4ef3085, $04881d05,
    $d9d4d039, $e6db99e5, $1fa27cf8, $c4ac5665,
    $f4292244, $432aff97, $ab9423a7, $fc93a039,
    $655b59c3, $8f0ccc92, $ffeff47d, $85845dd1,
    $6fa87e4f, $fe2ce6e0, $a3014314, $4e0811a1,
    $f7537e82, $bd3af235, $2ad7d2bb, $eb86d391
  );

procedure MD5ProcessBlock(ABlock: PByte; var AA, AB, AC, AD: UInt32);
var
  M: array[0..15] of UInt32;
  A, B, C, D, F: UInt32;
  G, I: Integer;
begin
  for I := 0 to 15 do
    M[I] := UInt32(ABlock[I*4]) or (UInt32(ABlock[I*4+1]) shl 8) or
            (UInt32(ABlock[I*4+2]) shl 16) or (UInt32(ABlock[I*4+3]) shl 24);
  A := AA; B := AB; C := AC; D := AD;

  for I := 0 to 63 do
  begin
    case I div 16 of
      0: begin F := (B and C) or ((not B) and D); G := I; end;
      1: begin F := (D and B) or ((not D) and C); G := (5*I + 1) mod 16; end;
      2: begin F := B xor C xor D;                G := (3*I + 5) mod 16; end;
      3: begin F := C xor (B or (not D));          G := (7*I) mod 16; end;
    end;
    F := F + A + KT[I] + M[G];
    A := D; D := C; C := B;
    B := B + RL(F, SHIFT[I]);
  end;

  Inc(AA, A); Inc(AB, B); Inc(AC, C); Inc(AD, D);
end;

constructor TMD5Hasher.Create;
begin
  inherited Create;
  Reset;
end;

procedure TMD5Hasher.Reset;
begin
  FA := $67452301; FB := $efcdab89;
  FC := $98badcfe; FD := $10325476;
  FBufLen := 0;
  FTotalLen := 0;
end;

function TMD5Hasher.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
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
    LCopy := MD5_BLOCK_SIZE - FBufLen;
    if LCopy > LRemaining then LCopy := LRemaining;
    Move(LSrc^, FBuf[FBufLen], LCopy);
    Inc(FBufLen, LCopy);
    Inc(LSrc, LCopy);
    Dec(LRemaining, LCopy);
    if FBufLen = MD5_BLOCK_SIZE then
    begin
      MD5ProcessBlock(@FBuf[0], FA, FB, FC, FD);
      FBufLen := 0;
    end;
  end;

  while LRemaining >= MD5_BLOCK_SIZE do
  begin
    MD5ProcessBlock(LSrc, FA, FB, FC, FD);
    Inc(LSrc, MD5_BLOCK_SIZE);
    Dec(LRemaining, MD5_BLOCK_SIZE);
  end;

  if LRemaining > 0 then
  begin
    Move(LSrc^, FBuf[0], LRemaining);
    FBufLen := LRemaining;
  end;
end;

procedure TMD5Hasher.Sum(out ADst; const ASize: SizeUInt);
var
  LA, LB, LC, LD: UInt32;
  LBuf: array[0..63] of Byte;
  LBufLen: SizeUInt;
  LTotalBits: UInt64;
  LDst: PByte;
begin
  LA := FA; LB := FB; LC := FC; LD := FD;
  Move(FBuf[0], LBuf[0], FBufLen);
  LBufLen := FBufLen;
  LTotalBits := FTotalLen * 8;

  LBuf[LBufLen] := $80;
  Inc(LBufLen);

  if LBufLen > 56 then
  begin
    while LBufLen < 64 do begin LBuf[LBufLen] := 0; Inc(LBufLen); end;
    MD5ProcessBlock(@LBuf[0], LA, LB, LC, LD);
    LBufLen := 0;
  end;

  while LBufLen < 56 do begin LBuf[LBufLen] := 0; Inc(LBufLen); end;

  LBuf[56] := Byte(LTotalBits);
  LBuf[57] := Byte(LTotalBits shr 8);
  LBuf[58] := Byte(LTotalBits shr 16);
  LBuf[59] := Byte(LTotalBits shr 24);
  LBuf[60] := Byte(LTotalBits shr 32);
  LBuf[61] := Byte(LTotalBits shr 40);
  LBuf[62] := Byte(LTotalBits shr 48);
  LBuf[63] := Byte(LTotalBits shr 56);

  MD5ProcessBlock(@LBuf[0], LA, LB, LC, LD);

  LDst := @ADst;
  LDst[0] := Byte(LA); LDst[1] := Byte(LA shr 8);
  LDst[2] := Byte(LA shr 16); LDst[3] := Byte(LA shr 24);
  LDst[4] := Byte(LB); LDst[5] := Byte(LB shr 8);
  LDst[6] := Byte(LB shr 16); LDst[7] := Byte(LB shr 24);
  LDst[8] := Byte(LC); LDst[9] := Byte(LC shr 8);
  LDst[10] := Byte(LC shr 16); LDst[11] := Byte(LC shr 24);
  LDst[12] := Byte(LD); LDst[13] := Byte(LD shr 8);
  LDst[14] := Byte(LD shr 16); LDst[15] := Byte(LD shr 24);
end;

function TMD5Hasher.SumBytes: TBytes;
begin
  SetLength(Result, MD5_DIGEST_SIZE);
  Sum(Result[0], MD5_DIGEST_SIZE);
end;

function TMD5Hasher.DigestSize: SizeUInt;
begin
  Result := MD5_DIGEST_SIZE;
end;

function TMD5Hasher.BlockSize: SizeUInt;
begin
  Result := MD5_BLOCK_SIZE;
end;

function TMD5Hasher.Clone: IHasher;
var
  LClone: TMD5Hasher;
begin
  LClone := TMD5Hasher.Create;
  LClone.FA := FA; LClone.FB := FB; LClone.FC := FC; LClone.FD := FD;
  Move(FBuf[0], LClone.FBuf[0], SizeOf(FBuf));
  LClone.FBufLen := FBufLen;
  LClone.FTotalLen := FTotalLen;
  Result := LClone;
end;

function NewMD5: IHasher;
begin
  Result := TMD5Hasher.Create;
end;

end.
