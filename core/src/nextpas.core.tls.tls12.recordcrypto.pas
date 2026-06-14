unit nextpas.core.tls.tls12.recordcrypto;

{$mode objfpc}{$H+}{$J-}

interface


function TLS12GCMEncryptRecord(
  const AKey: TBytes;
  const AImplicitNonce: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const APlaintext: TBytes;
  out AEncrypted: TBytes;
  out AError: string
): Boolean;

function TLS12GCMDecryptRecord(
  const AKey: TBytes;
  const AImplicitNonce: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const AEncrypted: TBytes;
  out APlaintext: TBytes;
  out AError: string
): Boolean;

implementation

uses nextpas.core.crypto.aesgcm;

const
  TLS12_VERSION_MAJOR = 3;
  TLS12_VERSION_MINOR = 3;
  GCM_EXPLICIT_NONCE_LEN = 8;
  GCM_TAG_LEN = 16;

function BuildGCMNonce(const AImplicitNonce: TBytes; ASeqNum: UInt64): TBytes;
begin
  SetLength(Result, 12);
  Move(AImplicitNonce[0], Result[0], 4);
  Result[4] := Byte(ASeqNum shr 56);
  Result[5] := Byte(ASeqNum shr 48);
  Result[6] := Byte(ASeqNum shr 40);
  Result[7] := Byte(ASeqNum shr 32);
  Result[8] := Byte(ASeqNum shr 24);
  Result[9] := Byte(ASeqNum shr 16);
  Result[10] := Byte(ASeqNum shr 8);
  Result[11] := Byte(ASeqNum);
end;

function BuildGCMExplicitNonce(ASeqNum: UInt64): TBytes;
begin
  SetLength(Result, GCM_EXPLICIT_NONCE_LEN);
  Result[0] := Byte(ASeqNum shr 56);
  Result[1] := Byte(ASeqNum shr 48);
  Result[2] := Byte(ASeqNum shr 40);
  Result[3] := Byte(ASeqNum shr 32);
  Result[4] := Byte(ASeqNum shr 24);
  Result[5] := Byte(ASeqNum shr 16);
  Result[6] := Byte(ASeqNum shr 8);
  Result[7] := Byte(ASeqNum);
end;

function BuildAAD(ASeqNum: UInt64; AContentType: Byte; APlaintextLen: Integer): TBytes;
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
  Result[9] := TLS12_VERSION_MAJOR;
  Result[10] := TLS12_VERSION_MINOR;
  Result[11] := Byte(APlaintextLen shr 8);
  Result[12] := Byte(APlaintextLen);
end;

function TLS12GCMEncryptRecord(
  const AKey: TBytes;
  const AImplicitNonce: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const APlaintext: TBytes;
  out AEncrypted: TBytes;
  out AError: string
): Boolean;
var
  LNonce, LAAD, LExplicitNonce: TBytes;
  LCiphertext, LTag: TBytes;
  LOutLen: Integer;
begin
  SetLength(AEncrypted, 0);
  AError := '';
  Result := False;

  if Length(AImplicitNonce) <> 4 then
  begin
    AError := 'Implicit nonce must be 4 bytes';
    Exit;
  end;

  LNonce := BuildGCMNonce(AImplicitNonce, ASeqNum);
  LExplicitNonce := BuildGCMExplicitNonce(ASeqNum);
  LAAD := BuildAAD(ASeqNum, AContentType, Length(APlaintext));

  if not PurePascalAESGCMEncrypt(AKey, LNonce, APlaintext, LAAD, LCiphertext, LTag) then
  begin
    AError := 'AES-GCM encryption failed';
    Exit;
  end;

  LOutLen := GCM_EXPLICIT_NONCE_LEN + Length(LCiphertext) + GCM_TAG_LEN;
  SetLength(AEncrypted, LOutLen);
  Move(LExplicitNonce[0], AEncrypted[0], GCM_EXPLICIT_NONCE_LEN);
  if Length(LCiphertext) > 0 then
    Move(LCiphertext[0], AEncrypted[GCM_EXPLICIT_NONCE_LEN], Length(LCiphertext));
  Move(LTag[0], AEncrypted[GCM_EXPLICIT_NONCE_LEN + Length(LCiphertext)], GCM_TAG_LEN);

  Result := True;
end;

function TLS12GCMDecryptRecord(
  const AKey: TBytes;
  const AImplicitNonce: TBytes;
  ASeqNum: UInt64;
  AContentType: Byte;
  const AEncrypted: TBytes;
  out APlaintext: TBytes;
  out AError: string
): Boolean;
var
  LNonce, LAAD: TBytes;
  LCiphertext, LTag: TBytes;
  LCipherLen: Integer;
begin
  SetLength(APlaintext, 0);
  AError := '';
  Result := False;

  if Length(AImplicitNonce) <> 4 then
  begin
    AError := 'Implicit nonce must be 4 bytes';
    Exit;
  end;

  if Length(AEncrypted) < GCM_EXPLICIT_NONCE_LEN + GCM_TAG_LEN then
  begin
    AError := 'Encrypted record too short';
    Exit;
  end;

  SetLength(LNonce, 12);
  Move(AImplicitNonce[0], LNonce[0], 4);
  Move(AEncrypted[0], LNonce[4], GCM_EXPLICIT_NONCE_LEN);

  LCipherLen := Length(AEncrypted) - GCM_EXPLICIT_NONCE_LEN - GCM_TAG_LEN;
  SetLength(LCiphertext, LCipherLen);
  if LCipherLen > 0 then
    Move(AEncrypted[GCM_EXPLICIT_NONCE_LEN], LCiphertext[0], LCipherLen);

  SetLength(LTag, GCM_TAG_LEN);
  Move(AEncrypted[GCM_EXPLICIT_NONCE_LEN + LCipherLen], LTag[0], GCM_TAG_LEN);

  LAAD := BuildAAD(ASeqNum, AContentType, LCipherLen);

  if not PurePascalAESGCMDecrypt(AKey, LNonce, LCiphertext, LTag, LAAD, APlaintext) then
  begin
    AError := 'bad_record_mac';
    Exit;
  end;

  Result := True;
end;

end.
