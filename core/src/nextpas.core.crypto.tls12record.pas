unit nextpas.core.crypto.tls12record;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.errors;

function TLS12CBCEncrypt_SHA256(
  const AEncKey, AMACKey: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const APlaintext: TBytes;
  out AEncrypted: TBytes;
  out AError: string
): Boolean;

function TLS12CBCDecrypt_SHA256(
  const AEncKey, AMACKey: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const AEncrypted: TBytes;
  out APlaintext: TBytes;
  out AError: string
): Boolean;

function TLS12CBCEncrypt_SHA384(
  const AEncKey, AMACKey: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const APlaintext: TBytes;
  out AEncrypted: TBytes;
  out AError: string
): Boolean;

function TLS12CBCDecrypt_SHA384(
  const AEncKey, AMACKey: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const AEncrypted: TBytes;
  out APlaintext: TBytes;
  out AError: string
): Boolean;

implementation

uses
  nextpas.core.crypto.aescbc,
  nextpas.core.crypto.hmac,
  nextpas.core.tls.random;

const
  TLS_VERSION_MAJOR = 3;
  TLS_VERSION_MINOR = 3;
  AES_BLOCK_SIZE = 16;
  UNIFIED_ERROR = 'bad_record_mac';

function BuildMACInput(ASeqNum: UInt64; AContentType: Byte; AFragmentLen: Integer): TBytes;
begin
  SetLength(Result, 13);
  Result[0] := Byte(ASeqNum shr 56);
  Result[1] := Byte(ASeqNum shr 48);
  Result[2] := Byte(ASeqNum shr 40);
  Result[3] := Byte(ASeqNum shr 32);
  Result[4] := Byte(ASeqNum shr 24);
  Result[5] := Byte(ASeqNum shr 16);
  Result[6] := Byte(ASeqNum shr 8);
  Result[7] := Byte(ASeqNum);
  Result[8] := AContentType;
  Result[9] := TLS_VERSION_MAJOR;
  Result[10] := TLS_VERSION_MINOR;
  Result[11] := Byte(AFragmentLen shr 8);
  Result[12] := Byte(AFragmentLen);
end;

function ComputeMAC_SHA256(const AMACKey: TBytes; ASeqNum: UInt64;
  AContentType: Byte; const AFragment: TBytes): TBytes;
var
  LHeader, LInput: TBytes;
  LHeaderLen, LFragLen: Integer;
begin
  LHeader := BuildMACInput(ASeqNum, AContentType, Length(AFragment));
  LHeaderLen := Length(LHeader);
  LFragLen := Length(AFragment);
  SetLength(LInput, LHeaderLen + LFragLen);
  Move(LHeader[0], LInput[0], LHeaderLen);
  if LFragLen > 0 then
    Move(AFragment[0], LInput[LHeaderLen], LFragLen);
  Result := HMAC_SHA256(AMACKey, LInput);
end;

function ComputeMAC_SHA384(const AMACKey: TBytes; ASeqNum: UInt64;
  AContentType: Byte; const AFragment: TBytes): TBytes;
var
  LHeader, LInput: TBytes;
  LHeaderLen, LFragLen: Integer;
begin
  LHeader := BuildMACInput(ASeqNum, AContentType, Length(AFragment));
  LHeaderLen := Length(LHeader);
  LFragLen := Length(AFragment);
  SetLength(LInput, LHeaderLen + LFragLen);
  Move(LHeader[0], LInput[0], LHeaderLen);
  if LFragLen > 0 then
    Move(AFragment[0], LInput[LHeaderLen], LFragLen);
  Result := HMAC_SHA384(AMACKey, LInput);
end;

function AddPadding(const AData: TBytes): TBytes;
var
  LPadLen, LTotalLen, I: Integer;
begin
  LPadLen := AES_BLOCK_SIZE - (Length(AData) mod AES_BLOCK_SIZE);
  if LPadLen = 0 then
    LPadLen := AES_BLOCK_SIZE;
  LTotalLen := Length(AData) + LPadLen;
  SetLength(Result, LTotalLen);
  Move(AData[0], Result[0], Length(AData));
  for I := Length(AData) to LTotalLen - 1 do
    Result[I] := Byte(LPadLen - 1);
end;

function ConstantTimeCheckPadding(const ADecrypted: TBytes; out APadLen: Integer): Byte;
var
  LLen, I: Integer;
  LPadByte: Byte;
  LGood: Byte;
begin
  LLen := Length(ADecrypted);
  if LLen = 0 then
  begin
    APadLen := 0;
    Exit(0);
  end;

  LPadByte := ADecrypted[LLen - 1];
  APadLen := Integer(LPadByte) + 1;

  if APadLen > LLen then
  begin
    APadLen := 0;
    Exit(0);
  end;

  LGood := $FF;
  for I := LLen - APadLen to LLen - 1 do
    LGood := LGood and not (ADecrypted[I] xor LPadByte);

  Result := LGood;
end;

function ConstantTimeCompareMAC(const A, B: TBytes): Byte;
var
  I: Integer;
  Diff: Byte;
begin
  if Length(A) <> Length(B) then
    Exit(0);
  Diff := 0;
  for I := 0 to Length(A) - 1 do
    Diff := Diff or (A[I] xor B[I]);
  if Diff = 0 then
    Result := $FF
  else
    Result := 0;
end;

function DoEncrypt(const AEncKey, AMACKey: TBytes; ASeqNum: UInt64;
  AContentType: Byte; const APlaintext: TBytes; AMACSize: Integer;
  AUseSHA384: Boolean; out AEncrypted: TBytes; out AError: string): Boolean;
var
  LMAC, LIV, LPadded, LPayload, LCipher, LResult: TBytes;
  LPayloadLen, LCipherLen: Integer;
begin
  AError := '';
  SetLength(AEncrypted, 0);
  Result := False;

  if AUseSHA384 then
    LMAC := ComputeMAC_SHA384(AMACKey, ASeqNum, AContentType, APlaintext)
  else
    LMAC := ComputeMAC_SHA256(AMACKey, ASeqNum, AContentType, APlaintext);

  LPayloadLen := Length(APlaintext) + AMACSize;
  SetLength(LPayload, LPayloadLen);
  if Length(APlaintext) > 0 then
    Move(APlaintext[0], LPayload[0], Length(APlaintext));
  Move(LMAC[0], LPayload[Length(APlaintext)], AMACSize);

  LPadded := AddPadding(LPayload);

  SetLength(LIV, AES_BLOCK_SIZE);
  SecureRandomBytes(@LIV[0], AES_BLOCK_SIZE);

  try
    LCipher := AESCBCEncryptNoPadding(AEncKey, LIV, LPadded);
  except
    on E: Exception do
    begin
      AError := UNIFIED_ERROR;
      Exit;
    end;
  end;

  LCipherLen := Length(LCipher);
  SetLength(LResult, AES_BLOCK_SIZE + LCipherLen);
  Move(LIV[0], LResult[0], AES_BLOCK_SIZE);
  Move(LCipher[0], LResult[AES_BLOCK_SIZE], LCipherLen);
  AEncrypted := LResult;

  Result := True;
end;

function DoDecrypt(const AEncKey, AMACKey: TBytes; ASeqNum: UInt64;
  AContentType: Byte; const AEncrypted: TBytes; AMACSize: Integer;
  AUseSHA384: Boolean; out APlaintext: TBytes; out AError: string): Boolean;
var
  LIV, LCiphertext, LDecrypted: TBytes;
  LPadLen: Integer;
  LPadOk, LMACOk, LLenOk: Byte;
  LContentLen: Integer;
  LContent, LReceivedMAC, LComputedMAC: TBytes;
begin
  SetLength(APlaintext, 0);
  AError := '';
  Result := False;

  if Length(AEncrypted) < AES_BLOCK_SIZE * 2 then
  begin
    AError := UNIFIED_ERROR;
    Exit;
  end;

  if (Length(AEncrypted) mod AES_BLOCK_SIZE) <> 0 then
  begin
    AError := UNIFIED_ERROR;
    Exit;
  end;

  SetLength(LIV, AES_BLOCK_SIZE);
  Move(AEncrypted[0], LIV[0], AES_BLOCK_SIZE);

  SetLength(LCiphertext, Length(AEncrypted) - AES_BLOCK_SIZE);
  Move(AEncrypted[AES_BLOCK_SIZE], LCiphertext[0], Length(LCiphertext));

  try
    LDecrypted := AESCBCDecryptNoPadding(AEncKey, LIV, LCiphertext);
  except
    on E: Exception do
    begin
      AError := UNIFIED_ERROR;
      Exit;
    end;
  end;

  LPadOk := ConstantTimeCheckPadding(LDecrypted, LPadLen);

  LContentLen := Length(LDecrypted) - LPadLen - AMACSize;
  if LContentLen < 0 then
    LLenOk := 0
  else
    LLenOk := $FF;

  if LContentLen < 0 then
    LContentLen := 0;

  SetLength(LContent, LContentLen);
  if LContentLen > 0 then
    Move(LDecrypted[0], LContent[0], LContentLen);

  SetLength(LReceivedMAC, AMACSize);
  if (LPadOk = $FF) and (LLenOk = $FF) then
    Move(LDecrypted[LContentLen], LReceivedMAC[0], AMACSize)
  else
    FillChar(LReceivedMAC[0], AMACSize, 0);

  if AUseSHA384 then
    LComputedMAC := ComputeMAC_SHA384(AMACKey, ASeqNum, AContentType, LContent)
  else
    LComputedMAC := ComputeMAC_SHA256(AMACKey, ASeqNum, AContentType, LContent);

  LMACOk := ConstantTimeCompareMAC(LReceivedMAC, LComputedMAC);

  if (LPadOk and LLenOk and LMACOk) = $FF then
  begin
    APlaintext := LContent;
    Result := True;
  end
  else
  begin
    FillChar(LDecrypted[0], Length(LDecrypted), 0);
    AError := UNIFIED_ERROR;
  end;
end;

function TLS12CBCEncrypt_SHA256(
  const AEncKey, AMACKey: TBytes; ASeqNum: UInt64; AContentType: Byte;
  const APlaintext: TBytes; out AEncrypted: TBytes; out AError: string): Boolean;
begin
  Result := DoEncrypt(AEncKey, AMACKey, ASeqNum, AContentType, APlaintext, 32, False, AEncrypted, AError);
end;

function TLS12CBCDecrypt_SHA256(
  const AEncKey, AMACKey: TBytes; ASeqNum: UInt64; AContentType: Byte;
  const AEncrypted: TBytes; out APlaintext: TBytes; out AError: string): Boolean;
begin
  Result := DoDecrypt(AEncKey, AMACKey, ASeqNum, AContentType, AEncrypted, 32, False, APlaintext, AError);
end;

function TLS12CBCEncrypt_SHA384(
  const AEncKey, AMACKey: TBytes; ASeqNum: UInt64; AContentType: Byte;
  const APlaintext: TBytes; out AEncrypted: TBytes; out AError: string): Boolean;
begin
  Result := DoEncrypt(AEncKey, AMACKey, ASeqNum, AContentType, APlaintext, 48, True, AEncrypted, AError);
end;

function TLS12CBCDecrypt_SHA384(
  const AEncKey, AMACKey: TBytes; ASeqNum: UInt64; AContentType: Byte;
  const AEncrypted: TBytes; out APlaintext: TBytes; out AError: string): Boolean;
begin
  Result := DoDecrypt(AEncKey, AMACKey, ASeqNum, AContentType, AEncrypted, 48, True, APlaintext, AError);
end;

end.
