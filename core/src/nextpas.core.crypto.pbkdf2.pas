unit nextpas.core.crypto.pbkdf2;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.base,
  nextpas.core.hash.base;

function PBKDF2(
  AAlgo: THashAlgorithm;
  const APassword, ASalt: TBytes;
  AIterations, AKeyLen: Integer
): TBytes;

function PBKDF2_SHA256(const APassword, ASalt: TBytes; AIterations, AKeyLen: Integer): TBytes;
function PBKDF2_SHA1(const APassword, ASalt: TBytes; AIterations, AKeyLen: Integer): TBytes;

implementation

uses
  Math,
  nextpas.core.hash.intf,
  nextpas.core.crypto.hmac;

function PBKDF2(
  AAlgo: THashAlgorithm;
  const APassword, ASalt: TBytes;
  AIterations, AKeyLen: Integer
): TBytes;
var
  LDigestSize: Integer;
  LBlockCount, LBlock, LIter, I: Integer;
  LInput: TBytes;
  LBlockIdx: array[0..3] of Byte;
  LU, LT: TBytes;
  LHmac: IHasher;
begin
  LDigestSize := GetDigestSize(AAlgo);
  SetLength(Result, AKeyLen);
  LBlockCount := (AKeyLen + LDigestSize - 1) div LDigestSize;

  if Length(APassword) > 0 then
    LHmac := NewHMAC(AAlgo, APassword[0], Length(APassword))
  else
    LHmac := NewHMAC(AAlgo, LBlockIdx[0], 0);

  SetLength(LU, LDigestSize);
  SetLength(LT, LDigestSize);

  for LBlock := 1 to LBlockCount do
  begin
    LBlockIdx[0] := Byte(LBlock shr 24);
    LBlockIdx[1] := Byte(LBlock shr 16);
    LBlockIdx[2] := Byte(LBlock shr 8);
    LBlockIdx[3] := Byte(LBlock);

    SetLength(LInput, Length(ASalt) + 4);
    if Length(ASalt) > 0 then
      Move(ASalt[0], LInput[0], Length(ASalt));
    Move(LBlockIdx[0], LInput[Length(ASalt)], 4);

    LHmac.Reset;
    LHmac.Write(LInput[0], Length(LInput));
    LHmac.Sum(LU[0], LDigestSize);
    Move(LU[0], LT[0], LDigestSize);

    for LIter := 2 to AIterations do
    begin
      LHmac.Reset;
      LHmac.Write(LU[0], LDigestSize);
      LHmac.Sum(LU[0], LDigestSize);
      for I := 0 to LDigestSize - 1 do
        LT[I] := LT[I] xor LU[I];
    end;

    for I := 0 to Min(LDigestSize, AKeyLen - (LBlock - 1) * LDigestSize) - 1 do
      Result[(LBlock - 1) * LDigestSize + I] := LT[I];
  end;
end;

function PBKDF2_SHA256(const APassword, ASalt: TBytes; AIterations, AKeyLen: Integer): TBytes;
begin
  Result := PBKDF2(haSHA256, APassword, ASalt, AIterations, AKeyLen);
end;

function PBKDF2_SHA1(const APassword, ASalt: TBytes; AIterations, AKeyLen: Integer): TBytes;
begin
  Result := PBKDF2(haSHA1, APassword, ASalt, AIterations, AKeyLen);
end;

end.
