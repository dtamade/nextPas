unit nextpas.core.crypto.pbkdf2;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils,
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
  nextpas.core.crypto.hmac;

function PBKDF2(
  AAlgo: THashAlgorithm;
  const APassword, ASalt: TBytes;
  AIterations, AKeyLen: Integer
): TBytes;
var
  LDigestSize: Integer;
  LBlockCount, LBlock, LIter, I: Integer;
  LInput, LU, LT: TBytes;
  LBlockIdx: array[0..3] of Byte;
  LHmacResult: TBytes;
begin
  LDigestSize := GetDigestSize(AAlgo);
  SetLength(Result, AKeyLen);
  LBlockCount := (AKeyLen + LDigestSize - 1) div LDigestSize;

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

    case AAlgo of
      haSHA256: LHmacResult := HMAC_SHA256(APassword, LInput);
      haSHA384: LHmacResult := HMAC_SHA384(APassword, LInput);
      haSHA1:   LHmacResult := HMAC_SHA1(APassword, LInput);
    else
      LHmacResult := HMAC_SHA256(APassword, LInput);
    end;

    LU := Copy(LHmacResult);
    LT := Copy(LHmacResult);

    for LIter := 2 to AIterations do
    begin
      case AAlgo of
        haSHA256: LHmacResult := HMAC_SHA256(APassword, LU);
        haSHA384: LHmacResult := HMAC_SHA384(APassword, LU);
        haSHA1:   LHmacResult := HMAC_SHA1(APassword, LU);
      else
        LHmacResult := HMAC_SHA256(APassword, LU);
      end;
      LU := LHmacResult;
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
