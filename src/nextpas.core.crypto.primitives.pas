{**
 * Unit: nextpas.core.crypto.primitives
 * Purpose: TLS 1.3 所需基础密码学原语（纯 Pascal）
 *
 * 当前提供：
 * - HMAC-SHA256 / HMAC-SHA384
 * - HKDF-Extract/Expand (SHA256/SHA384)
 * - TLS 1.3 HKDF-Expand-Label (SHA256/SHA384)
 *}

unit nextpas.core.crypto.primitives;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils,
  nextpas.core.tls.errors;

function HMAC_SHA256(const AKey, AData: TBytes): TBytes;
function HMAC_SHA384(const AKey, AData: TBytes): TBytes;

function HKDF_Extract_SHA256(const ASalt, AIKM: TBytes): TBytes;
function HKDF_Extract_SHA384(const ASalt, AIKM: TBytes): TBytes;

function HKDF_Expand_SHA256(const APRK, AInfo: TBytes; ALength: Integer): TBytes;
function HKDF_Expand_SHA384(const APRK, AInfo: TBytes; ALength: Integer): TBytes;

function TLS13_HKDF_Expand_Label_SHA256(
  const ASecret: TBytes;
  const ALabel: string;
  const AContext: TBytes;
  ALength: Integer
): TBytes;

function TLS13_HKDF_Expand_Label_SHA384(
  const ASecret: TBytes;
  const ALabel: string;
  const AContext: TBytes;
  ALength: Integer
): TBytes;

implementation

uses
  nextpas.core.crypto.hash,
  nextpas.core.tls.tls13.wire;

const
  SHA256_DIGEST_SIZE = 32;
  SHA256_BLOCK_SIZE = 64;

  SHA384_DIGEST_SIZE = 48;
  SHA384_BLOCK_SIZE = 128;

function CopyBytes(const AData: TBytes): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[0], Length(AData));
end;

function ConcatBytes(const ALeft, ARight: TBytes): TBytes;
var
  LLeftLen, LRightLen: Integer;
begin
  LLeftLen := Length(ALeft);
  LRightLen := Length(ARight);
  Result := nil;
  SetLength(Result, LLeftLen + LRightLen);

  if LLeftLen > 0 then
    Move(ALeft[0], Result[0], LLeftLen);
  if LRightLen > 0 then
    Move(ARight[0], Result[LLeftLen], LRightLen);
end;

function BuildTLS13HKDFLabel(const ALabel: string; const AContext: TBytes; ALength: Integer): TBytes;
var
  LFullLabel: AnsiString;
  LLabelBytes: TBytes;
  LLabelLen, LContextLen: Integer;
  I: Integer;
begin
  if ALength < 0 then
    RaiseInvalidParameter('TLS13ExpandLabelLength');

  LFullLabel := AnsiString('tls13 ' + ALabel);
  LLabelLen := Length(LFullLabel);
  LContextLen := Length(AContext);

  if LLabelLen > 255 then
    RaiseInvalidParameter('TLS13ExpandLabelText');
  if LContextLen > 255 then
    RaiseInvalidParameter('TLS13ExpandLabelContext');

  SetLength(LLabelBytes, LLabelLen);
  for I := 1 to LLabelLen do
    LLabelBytes[I - 1] := Byte(LFullLabel[I]);

  Result := nil;
  AppendUInt16(Result, Word(ALength));
  AppendByte(Result, Byte(LLabelLen));
  AppendBytes(Result, LLabelBytes);
  AppendByte(Result, Byte(LContextLen));
  AppendBytes(Result, AContext);
end;

function HMAC_SHA256(const AKey, AData: TBytes): TBytes;
var
  LKey: TBytes;
  LIpad, LOpad: TBytes;
  LInnerInput, LInnerHash, LOuterInput: TBytes;
  I: Integer;
begin
  LKey := CopyBytes(AKey);

  if Length(LKey) > SHA256_BLOCK_SIZE then
    LKey := SHA256(LKey);

  SetLength(LIpad, SHA256_BLOCK_SIZE);
  SetLength(LOpad, SHA256_BLOCK_SIZE);

  FillChar(LIpad[0], SHA256_BLOCK_SIZE, $36);
  FillChar(LOpad[0], SHA256_BLOCK_SIZE, $5C);

  for I := 0 to Length(LKey) - 1 do
  begin
    LIpad[I] := LIpad[I] xor LKey[I];
    LOpad[I] := LOpad[I] xor LKey[I];
  end;

  LInnerInput := ConcatBytes(LIpad, AData);
  LInnerHash := SHA256(LInnerInput);

  LOuterInput := ConcatBytes(LOpad, LInnerHash);
  Result := SHA256(LOuterInput);
end;

function HMAC_SHA384(const AKey, AData: TBytes): TBytes;
var
  LKey: TBytes;
  LIpad, LOpad: TBytes;
  LInnerInput, LInnerHash, LOuterInput: TBytes;
  I: Integer;
begin
  LKey := CopyBytes(AKey);

  if Length(LKey) > SHA384_BLOCK_SIZE then
    LKey := SHA384(LKey);

  SetLength(LIpad, SHA384_BLOCK_SIZE);
  SetLength(LOpad, SHA384_BLOCK_SIZE);

  FillChar(LIpad[0], SHA384_BLOCK_SIZE, $36);
  FillChar(LOpad[0], SHA384_BLOCK_SIZE, $5C);

  for I := 0 to Length(LKey) - 1 do
  begin
    LIpad[I] := LIpad[I] xor LKey[I];
    LOpad[I] := LOpad[I] xor LKey[I];
  end;

  LInnerInput := ConcatBytes(LIpad, AData);
  LInnerHash := SHA384(LInnerInput);

  LOuterInput := ConcatBytes(LOpad, LInnerHash);
  Result := SHA384(LOuterInput);
end;

function HKDF_Extract_SHA256(const ASalt, AIKM: TBytes): TBytes;
var
  LSalt: TBytes;
begin
  if Length(ASalt) = 0 then
  begin
    SetLength(LSalt, SHA256_DIGEST_SIZE);
    FillChar(LSalt[0], SHA256_DIGEST_SIZE, 0);
  end
  else
    LSalt := CopyBytes(ASalt);

  Result := HMAC_SHA256(LSalt, AIKM);
end;

function HKDF_Extract_SHA384(const ASalt, AIKM: TBytes): TBytes;
var
  LSalt: TBytes;
begin
  if Length(ASalt) = 0 then
  begin
    SetLength(LSalt, SHA384_DIGEST_SIZE);
    FillChar(LSalt[0], SHA384_DIGEST_SIZE, 0);
  end
  else
    LSalt := CopyBytes(ASalt);

  Result := HMAC_SHA384(LSalt, AIKM);
end;

function HKDF_Expand_SHA256(const APRK, AInfo: TBytes; ALength: Integer): TBytes;
var
  LN, I: Integer;
  LT, LPreviousT, LInput, LTemp: TBytes;
  LOffset, LCopyLen: Integer;
begin
  Result := nil;

  if ALength < 0 then
    RaiseInvalidParameter('HKDFExpandLength');

  if ALength = 0 then
    Exit;

  if Length(APRK) < SHA256_DIGEST_SIZE then
    RaiseInvalidParameter('HKDFExpandPRK');

  LN := (ALength + SHA256_DIGEST_SIZE - 1) div SHA256_DIGEST_SIZE;
  if LN > 255 then
    RaiseInvalidParameter('HKDFExpandLengthTooLarge');

  SetLength(Result, ALength);
  SetLength(LPreviousT, 0);
  LOffset := 0;

  for I := 1 to LN do
  begin
    LInput := ConcatBytes(LPreviousT, AInfo);
    SetLength(LTemp, 1);
    LTemp[0] := Byte(I);
    LInput := ConcatBytes(LInput, LTemp);

    LT := HMAC_SHA256(APRK, LInput);

    LCopyLen := SHA256_DIGEST_SIZE;
    if (LOffset + LCopyLen) > ALength then
      LCopyLen := ALength - LOffset;

    Move(LT[0], Result[LOffset], LCopyLen);
    Inc(LOffset, LCopyLen);

    LPreviousT := LT;
  end;
end;

function HKDF_Expand_SHA384(const APRK, AInfo: TBytes; ALength: Integer): TBytes;
var
  LN, I: Integer;
  LT, LPreviousT, LInput, LTemp: TBytes;
  LOffset, LCopyLen: Integer;
begin
  Result := nil;

  if ALength < 0 then
    RaiseInvalidParameter('HKDFExpandLength');

  if ALength = 0 then
    Exit;

  if Length(APRK) < SHA384_DIGEST_SIZE then
    RaiseInvalidParameter('HKDFExpandPRK');

  LN := (ALength + SHA384_DIGEST_SIZE - 1) div SHA384_DIGEST_SIZE;
  if LN > 255 then
    RaiseInvalidParameter('HKDFExpandLengthTooLarge');

  SetLength(Result, ALength);
  SetLength(LPreviousT, 0);
  LOffset := 0;

  for I := 1 to LN do
  begin
    LInput := ConcatBytes(LPreviousT, AInfo);
    SetLength(LTemp, 1);
    LTemp[0] := Byte(I);
    LInput := ConcatBytes(LInput, LTemp);

    LT := HMAC_SHA384(APRK, LInput);

    LCopyLen := SHA384_DIGEST_SIZE;
    if (LOffset + LCopyLen) > ALength then
      LCopyLen := ALength - LOffset;

    Move(LT[0], Result[LOffset], LCopyLen);
    Inc(LOffset, LCopyLen);

    LPreviousT := LT;
  end;
end;

function TLS13_HKDF_Expand_Label_SHA256(
  const ASecret: TBytes;
  const ALabel: string;
  const AContext: TBytes;
  ALength: Integer
): TBytes;
var
  LHkdfLabel: TBytes;
begin
  LHkdfLabel := BuildTLS13HKDFLabel(ALabel, AContext, ALength);
  Result := HKDF_Expand_SHA256(ASecret, LHkdfLabel, ALength);
end;

function TLS13_HKDF_Expand_Label_SHA384(
  const ASecret: TBytes;
  const ALabel: string;
  const AContext: TBytes;
  ALength: Integer
): TBytes;
var
  LHkdfLabel: TBytes;
begin
  LHkdfLabel := BuildTLS13HKDFLabel(ALabel, AContext, ALength);
  Result := HKDF_Expand_SHA384(ASecret, LHkdfLabel, ALength);
end;

end.
