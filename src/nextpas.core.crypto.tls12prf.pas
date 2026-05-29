unit nextpas.core.crypto.tls12prf;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils;

function TLS12PRF_SHA256(
  const ASecret: TBytes;
  const ALabel: string;
  const ASeed: TBytes;
  AOutputLength: Integer
): TBytes;

function TLS12PRF_SHA384(
  const ASecret: TBytes;
  const ALabel: string;
  const ASeed: TBytes;
  AOutputLength: Integer
): TBytes;

implementation

uses
  nextpas.core.crypto.primitives;

function ConcatLabelAndSeed(const ALabel: string; const ASeed: TBytes): TBytes;
var
  LLabelBytes: TBytes;
  LLabelLen, LSeedLen: Integer;
begin
  LLabelBytes := TEncoding.ASCII.GetBytes(ALabel);
  LLabelLen := Length(LLabelBytes);
  LSeedLen := Length(ASeed);
  SetLength(Result, LLabelLen + LSeedLen);
  if LLabelLen > 0 then
    Move(LLabelBytes[0], Result[0], LLabelLen);
  if LSeedLen > 0 then
    Move(ASeed[0], Result[LLabelLen], LSeedLen);
end;

function LocalConcatBytes(const ALeft, ARight: TBytes): TBytes;
var
  LLeftLen, LRightLen: Integer;
begin
  LLeftLen := Length(ALeft);
  LRightLen := Length(ARight);
  SetLength(Result, LLeftLen + LRightLen);
  if LLeftLen > 0 then
    Move(ALeft[0], Result[0], LLeftLen);
  if LRightLen > 0 then
    Move(ARight[0], Result[LLeftLen], LRightLen);
end;

function P_SHA256(const ASecret, ASeed: TBytes; ALength: Integer): TBytes;
var
  A, ANext, HMACResult: TBytes;
  LOffset, LCopyLen: Integer;
begin
  SetLength(Result, ALength);
  A := HMAC_SHA256(ASecret, ASeed);
  LOffset := 0;

  while LOffset < ALength do
  begin
    HMACResult := HMAC_SHA256(ASecret, LocalConcatBytes(A, ASeed));
    LCopyLen := ALength - LOffset;
    if LCopyLen > 32 then
      LCopyLen := 32;
    Move(HMACResult[0], Result[LOffset], LCopyLen);
    Inc(LOffset, LCopyLen);
    ANext := HMAC_SHA256(ASecret, A);
    A := ANext;
  end;
end;

function P_SHA384(const ASecret, ASeed: TBytes; ALength: Integer): TBytes;
var
  A, ANext, HMACResult: TBytes;
  LOffset, LCopyLen: Integer;
begin
  SetLength(Result, ALength);
  A := HMAC_SHA384(ASecret, ASeed);
  LOffset := 0;

  while LOffset < ALength do
  begin
    HMACResult := HMAC_SHA384(ASecret, LocalConcatBytes(A, ASeed));
    LCopyLen := ALength - LOffset;
    if LCopyLen > 48 then
      LCopyLen := 48;
    Move(HMACResult[0], Result[LOffset], LCopyLen);
    Inc(LOffset, LCopyLen);
    ANext := HMAC_SHA384(ASecret, A);
    A := ANext;
  end;
end;

function TLS12PRF_SHA256(
  const ASecret: TBytes;
  const ALabel: string;
  const ASeed: TBytes;
  AOutputLength: Integer
): TBytes;
begin
  Result := P_SHA256(ASecret, ConcatLabelAndSeed(ALabel, ASeed), AOutputLength);
end;

function TLS12PRF_SHA384(
  const ASecret: TBytes;
  const ALabel: string;
  const ASeed: TBytes;
  AOutputLength: Integer
): TBytes;
begin
  Result := P_SHA384(ASecret, ConcatLabelAndSeed(ALabel, ASeed), AOutputLength);
end;

end.
