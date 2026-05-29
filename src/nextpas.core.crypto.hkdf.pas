unit nextpas.core.crypto.hkdf;

{$mode objfpc}{$H+}

{ nextpas.core.crypto.hkdf — HKDF 实现 (RFC 5869)

  基于 nextpas.core.crypto.hmac。
  HKDF-Extract: PRK = HMAC(salt, IKM)
  HKDF-Expand: OKM = T(1) || T(2) || ... 截断到 L 字节
}

interface

uses
  SysUtils,
  nextpas.core.hash.base;

function HKDF_Extract(AAlgo: THashAlgorithm;
  const ASalt; ASaltLen: SizeUInt;
  const AIKM; AIKMLen: SizeUInt;
  out APRK; APRKSize: SizeUInt): Boolean;

function HKDF_Expand(AAlgo: THashAlgorithm;
  const APRK; APRKLen: SizeUInt;
  const AInfo; AInfoLen: SizeUInt;
  out AOKM; AOKMLen: SizeUInt): Boolean;

function HKDF_ExtractBytes(AAlgo: THashAlgorithm;
  const ASalt, AIKM: TBytes): TBytes;

function HKDF_ExpandBytes(AAlgo: THashAlgorithm;
  const APRK, AInfo: TBytes; ALength: SizeUInt): TBytes;

{ 旧接口兼容 }
function HKDF_Extract_SHA256(const ASalt, AIKM: TBytes): TBytes;
function HKDF_Extract_SHA384(const ASalt, AIKM: TBytes): TBytes;
function HKDF_Expand_SHA256(const APRK, AInfo: TBytes; ALength: Integer): TBytes;
function HKDF_Expand_SHA384(const APRK, AInfo: TBytes; ALength: Integer): TBytes;

implementation

uses
  nextpas.core.hash.intf,
  nextpas.core.crypto.hmac;

function HKDF_Extract(AAlgo: THashAlgorithm;
  const ASalt; ASaltLen: SizeUInt;
  const AIKM; AIKMLen: SizeUInt;
  out APRK; APRKSize: SizeUInt): Boolean;
var
  LH: IHasher;
  LZeroSalt: array[0..63] of Byte;
  LDigestSize: SizeUInt;
begin
  Result := False;
  LDigestSize := GetDigestSize(AAlgo);
  if APRKSize < LDigestSize then Exit;

  if ASaltLen > 0 then
    LH := NewHMAC(AAlgo, ASalt, ASaltLen)
  else
  begin
    FillChar(LZeroSalt[0], LDigestSize, 0);
    LH := NewHMAC(AAlgo, LZeroSalt[0], LDigestSize);
  end;

  LH.Write(AIKM, AIKMLen);
  LH.Sum(APRK, LDigestSize);
  Result := True;
end;

function HKDF_Expand(AAlgo: THashAlgorithm;
  const APRK; APRKLen: SizeUInt;
  const AInfo; AInfoLen: SizeUInt;
  out AOKM; AOKMLen: SizeUInt): Boolean;
var
  LH: IHasher;
  LDigestSize: SizeUInt;
  LN, I: Integer;
  LT: array[0..63] of Byte;
  LCounter: Byte;
  LDst: PByte;
  LCopyLen: SizeUInt;
begin
  Result := False;
  LDigestSize := GetDigestSize(AAlgo);

  LN := (AOKMLen + LDigestSize - 1) div LDigestSize;
  if LN > 255 then Exit;

  LDst := @AOKM;
  FillChar(LT[0], SizeOf(LT), 0);

  for I := 1 to LN do
  begin
    LH := NewHMAC(AAlgo, APRK, APRKLen);
    if I > 1 then
      LH.Write(LT[0], LDigestSize);
    if AInfoLen > 0 then
      LH.Write(AInfo, AInfoLen);
    LCounter := Byte(I);
    LH.Write(LCounter, 1);
    LH.Sum(LT[0], LDigestSize);

    LCopyLen := AOKMLen - SizeUInt((I-1)) * LDigestSize;
    if LCopyLen > LDigestSize then LCopyLen := LDigestSize;
    Move(LT[0], LDst^, LCopyLen);
    Inc(LDst, LCopyLen);
  end;

  Result := True;
end;

function HKDF_ExtractBytes(AAlgo: THashAlgorithm;
  const ASalt, AIKM: TBytes): TBytes;
var
  LDigestSize: SizeUInt;
begin
  LDigestSize := GetDigestSize(AAlgo);
  SetLength(Result, LDigestSize);
  if Length(AIKM) > 0 then
  begin
    if Length(ASalt) > 0 then
      HKDF_Extract(AAlgo, ASalt[0], Length(ASalt), AIKM[0], Length(AIKM), Result[0], LDigestSize)
    else
      HKDF_Extract(AAlgo, ASalt, 0, AIKM[0], Length(AIKM), Result[0], LDigestSize);
  end
  else
  begin
    if Length(ASalt) > 0 then
      HKDF_Extract(AAlgo, ASalt[0], Length(ASalt), AIKM, 0, Result[0], LDigestSize)
    else
      HKDF_Extract(AAlgo, ASalt, 0, AIKM, 0, Result[0], LDigestSize);
  end;
end;

function HKDF_ExpandBytes(AAlgo: THashAlgorithm;
  const APRK, AInfo: TBytes; ALength: SizeUInt): TBytes;
begin
  SetLength(Result, ALength);
  if ALength = 0 then Exit;
  if Length(AInfo) > 0 then
    HKDF_Expand(AAlgo, APRK[0], Length(APRK), AInfo[0], Length(AInfo), Result[0], ALength)
  else
    HKDF_Expand(AAlgo, APRK[0], Length(APRK), AInfo, 0, Result[0], ALength);
end;

function HKDF_Extract_SHA256(const ASalt, AIKM: TBytes): TBytes;
begin
  Result := HKDF_ExtractBytes(haSHA256, ASalt, AIKM);
end;

function HKDF_Extract_SHA384(const ASalt, AIKM: TBytes): TBytes;
begin
  Result := HKDF_ExtractBytes(haSHA384, ASalt, AIKM);
end;

function HKDF_Expand_SHA256(const APRK, AInfo: TBytes; ALength: Integer): TBytes;
begin
  Result := HKDF_ExpandBytes(haSHA256, APRK, AInfo, SizeUInt(ALength));
end;

function HKDF_Expand_SHA384(const APRK, AInfo: TBytes; ALength: Integer): TBytes;
begin
  Result := HKDF_ExpandBytes(haSHA384, APRK, AInfo, SizeUInt(ALength));
end;

end.
