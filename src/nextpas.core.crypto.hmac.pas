unit nextpas.core.crypto.hmac;

{$mode objfpc}{$H+}

{ nextpas.core.crypto.hmac — HMAC 实现 (RFC 2104)

  基于 nextpas.core.hash.IHasher 接口。
  Sum 语义：不改变内部状态（可多次调用，继续 Write 后再 Sum 得到不同结果）。
}

interface

uses
  SysUtils,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash;

function NewHMAC(AAlgo: THashAlgorithm; const AKey; AKeyLen: SizeUInt): IHasher;

function HmacSHA256(const AKey, AData: TBytes): TSHA256Digest;
function HmacSHA384(const AKey, AData: TBytes): TSHA384Digest;
function HmacSHA512(const AKey, AData: TBytes): TSHA512Digest;

{ TBytes 返回版本（兼容旧消费者，后续逐步淘汰） }
function HMAC_SHA256(const AKey, AData: TBytes): TBytes;
function HMAC_SHA384(const AKey, AData: TBytes): TBytes;
function HMAC_SHA1(const AKey, AData: TBytes): TBytes;

implementation

type
  THMACHasher = class(TInterfacedObject, IHasher)
  private
    FAlgo: THashAlgorithm;
    FInner: IHasher;
    FBlockSize: SizeUInt;
    FDigestSize: SizeUInt;
    FOPad: array[0..127] of Byte;
  public
    constructor Create(AAlgo: THashAlgorithm; const AKey; AKeyLen: SizeUInt);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Sum(out ADst; const ASize: SizeUInt);
    function SumBytes: TBytes;
    procedure Reset;
    function DigestSize: SizeUInt;
    function BlockSize: SizeUInt;
  end;

constructor THMACHasher.Create(AAlgo: THashAlgorithm; const AKey; AKeyLen: SizeUInt);
var
  LKeyBlock: array[0..127] of Byte;
  LIPad: array[0..127] of Byte;
  LTmpHash: IHasher;
  LDigest: array[0..63] of Byte;
  I: SizeUInt;
begin
  inherited Create;
  FAlgo := AAlgo;
  FBlockSize := GetBlockSize(AAlgo);
  FDigestSize := GetDigestSize(AAlgo);
  FInner := nextpas.core.hash.NewHasher(AAlgo);

  FillChar(LKeyBlock[0], SizeOf(LKeyBlock), 0);

  if AKeyLen > FBlockSize then
  begin
    LTmpHash := nextpas.core.hash.NewHasher(AAlgo);
    LTmpHash.Write(AKey, AKeyLen);
    LTmpHash.Sum(LDigest[0], FDigestSize);
    Move(LDigest[0], LKeyBlock[0], FDigestSize);
    FillChar(LDigest[0], SizeOf(LDigest), 0);
  end
  else if AKeyLen > 0 then
    Move(AKey, LKeyBlock[0], AKeyLen);

  for I := 0 to FBlockSize - 1 do
  begin
    LIPad[I] := LKeyBlock[I] xor $36;
    FOPad[I] := LKeyBlock[I] xor $5C;
  end;

  FInner.Reset;
  FInner.Write(LIPad[0], FBlockSize);

  FillChar(LKeyBlock[0], SizeOf(LKeyBlock), 0);
  FillChar(LIPad[0], SizeOf(LIPad), 0);
end;

function THMACHasher.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FInner.Write(ABuf, ACount);
end;

procedure THMACHasher.Sum(out ADst; const ASize: SizeUInt);
var
  LInnerDigest: array[0..63] of Byte;
  LOuter: IHasher;
begin
  FInner.Sum(LInnerDigest[0], FDigestSize);

  LOuter := nextpas.core.hash.NewHasher(FAlgo);
  LOuter.Write(FOPad[0], FBlockSize);
  LOuter.Write(LInnerDigest[0], FDigestSize);
  LOuter.Sum(ADst, ASize);

  FillChar(LInnerDigest[0], SizeOf(LInnerDigest), 0);
end;

function THMACHasher.SumBytes: TBytes;
begin
  SetLength(Result, FDigestSize);
  Sum(Result[0], FDigestSize);
end;

procedure THMACHasher.Reset;
var
  LIPad: array[0..127] of Byte;
  I: SizeUInt;
begin
  for I := 0 to FBlockSize - 1 do
    LIPad[I] := FOPad[I] xor $5C xor $36;
  FInner.Reset;
  FInner.Write(LIPad[0], FBlockSize);
  FillChar(LIPad[0], SizeOf(LIPad), 0);
end;

function THMACHasher.DigestSize: SizeUInt;
begin
  Result := FDigestSize;
end;

function THMACHasher.BlockSize: SizeUInt;
begin
  Result := FBlockSize;
end;

function NewHMAC(AAlgo: THashAlgorithm; const AKey; AKeyLen: SizeUInt): IHasher;
begin
  Result := THMACHasher.Create(AAlgo, AKey, AKeyLen);
end;

function HmacSHA256(const AKey, AData: TBytes): TSHA256Digest;
var LH: IHasher;
begin
  if Length(AKey) > 0 then
    LH := NewHMAC(haSHA256, AKey[0], Length(AKey))
  else
    LH := NewHMAC(haSHA256, AKey, 0);
  if Length(AData) > 0 then
    LH.Write(AData[0], Length(AData));
  LH.Sum(Result, SHA256_DIGEST_SIZE);
end;

function HmacSHA384(const AKey, AData: TBytes): TSHA384Digest;
var LH: IHasher;
begin
  if Length(AKey) > 0 then
    LH := NewHMAC(haSHA384, AKey[0], Length(AKey))
  else
    LH := NewHMAC(haSHA384, AKey, 0);
  if Length(AData) > 0 then
    LH.Write(AData[0], Length(AData));
  LH.Sum(Result, SHA384_DIGEST_SIZE);
end;

function HmacSHA512(const AKey, AData: TBytes): TSHA512Digest;
var LH: IHasher;
begin
  if Length(AKey) > 0 then
    LH := NewHMAC(haSHA512, AKey[0], Length(AKey))
  else
    LH := NewHMAC(haSHA512, AKey, 0);
  if Length(AData) > 0 then
    LH.Write(AData[0], Length(AData));
  LH.Sum(Result, SHA512_DIGEST_SIZE);
end;

function HMAC_SHA256(const AKey, AData: TBytes): TBytes;
var LD: TSHA256Digest;
begin
  LD := HmacSHA256(AKey, AData);
  SetLength(Result, SHA256_DIGEST_SIZE);
  Move(LD[0], Result[0], SHA256_DIGEST_SIZE);
end;

function HMAC_SHA384(const AKey, AData: TBytes): TBytes;
var LD: TSHA384Digest;
begin
  LD := HmacSHA384(AKey, AData);
  SetLength(Result, SHA384_DIGEST_SIZE);
  Move(LD[0], Result[0], SHA384_DIGEST_SIZE);
end;

function HMAC_SHA1(const AKey, AData: TBytes): TBytes;
var LH: IHasher;
begin
  if Length(AKey) > 0 then
    LH := NewHMAC(haSHA1, AKey[0], Length(AKey))
  else
    LH := NewHMAC(haSHA1, AKey, 0);
  if Length(AData) > 0 then
    LH.Write(AData[0], Length(AData));
  SetLength(Result, SHA1_DIGEST_SIZE);
  LH.Sum(Result[0], SHA1_DIGEST_SIZE);
end;

end.
