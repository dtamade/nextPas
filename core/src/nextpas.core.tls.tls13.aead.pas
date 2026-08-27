{**
 * Unit: nextpas.core.tls.tls13.aead
 * Purpose: TLS 1.3 记录层 AEAD 套件调度（纯 Pascal）
 *
 * 当前支持：
 * - TLS_CHACHA20_POLY1305_SHA256（纯 Pascal）
 * - TLS_AES_128_GCM_SHA256（纯 Pascal）
 * - TLS_AES_256_GCM_SHA384（纯 Pascal）
 *}

unit nextpas.core.tls.tls13.aead;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.text.format;

function TLS13AEADIsSupported(ACipherSuite: Word): Boolean;
function TLS13AEADTagLength(ACipherSuite: Word): Integer;

function TryTLS13AEADEncrypt(
  ACipherSuite: Word;
  const AKey, ANonce, AAAD, APlaintext: TBytes;
  out AEncrypted: TBytes;
  out AError: string
): Boolean;

function TryTLS13AEADDecrypt(
  ACipherSuite: Word;
  const AKey, ANonce, AAAD, AEncrypted: TBytes;
  out APlaintext: TBytes;
  out AError: string
): Boolean;

function TryTLS13AEADDecryptTo(
  ACipherSuite: Word;
  const AKey, ANonce, AAAD, AEncrypted: TBytes;
  ADest: PByte; ADestCap: Integer;
  out AFragLen: Integer; out AContentType: Byte; out AError: string
): Boolean;

function TryTLS13AEADDecryptToBuf(
  ACipherSuite: Word;
  const AKey, ANonce, AAAD: TBytes;
  AEncrypted: PByte; AEncryptedLen: Integer;
  ADest: PByte; ADestCap: Integer;
  out AFragLen: Integer; out AContentType: Byte; out AError: string
): Boolean;

function TryTLS13AEADEncryptToBuf(
  ACipherSuite: Word;
  const AKey, ANonce, AAAD: TBytes;
  APlain: PByte; APlainLen: Integer;
  ADest: PByte; ADestCap: Integer;
  out AEncryptedLen: Integer; out AError: string): Boolean;

implementation

uses
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.crypto.chacha20poly1305,
  nextpas.core.crypto.aesgcm;

function TLS13AEADTagLength(ACipherSuite: Word): Integer;
begin
  case ACipherSuite of
    TLS13_CIPHER_AES_128_GCM_SHA256,
    TLS13_CIPHER_AES_256_GCM_SHA384,
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256:
      Result := 16;
  else
    Result := 0;
  end;
end;

function RequiredAESKeyLength(ACipherSuite: Word): Integer;
begin
  case ACipherSuite of
    TLS13_CIPHER_AES_128_GCM_SHA256: Result := 16;
    TLS13_CIPHER_AES_256_GCM_SHA384: Result := 32;
  else
    Result := 0;
  end;
end;

function ValidateAESGCMInputs(
  ACipherSuite: Word;
  const AKey, ANonce: TBytes;
  out AError: string
): Boolean;
var
  LExpectedKeyLen: Integer;
begin
  Result := False;
  AError := '';

  LExpectedKeyLen := RequiredAESKeyLength(ACipherSuite);
  if LExpectedKeyLen = 0 then
  begin
    AError := TextFormat('Unsupported TLS 1.3 AES-GCM suite: 0x%.4x', [ACipherSuite]);
    Exit(False);
  end;

  if Length(AKey) <> LExpectedKeyLen then
  begin
    AError := TextFormat(
      'Invalid AES-GCM key length for suite 0x%.4x: expected %d bytes, got %d',
      [ACipherSuite, LExpectedKeyLen, Length(AKey)]
    );
    Exit(False);
  end;

  if Length(ANonce) <> 12 then
  begin
    AError := TextFormat('Invalid AES-GCM nonce length: expected 12 bytes, got %d', [Length(ANonce)]);
    Exit(False);
  end;

  Result := True;
end;

procedure CombineCipherTextAndTag(const ACipherText, ATag: TBytes; out AEncrypted: TBytes);
var
  LCipherLen, LTagLen: Integer;
begin
  LCipherLen := Length(ACipherText);
  LTagLen := Length(ATag);

  SetLength(AEncrypted, LCipherLen + LTagLen);
  if LCipherLen > 0 then
    Move(ACipherText[0], AEncrypted[0], LCipherLen);
  if LTagLen > 0 then
    Move(ATag[0], AEncrypted[LCipherLen], LTagLen);
end;

function SplitCipherTextAndTag(
  const AEncrypted: TBytes;
  out ACipherText, ATag: TBytes
): Boolean;
var
  LCipherLen: Integer;
begin
  Result := False;

  if Length(AEncrypted) < 16 then
  begin
    SetLength(ACipherText, 0);
    SetLength(ATag, 0);
    Exit(False);
  end;

  LCipherLen := Length(AEncrypted) - 16;
  SetLength(ACipherText, LCipherLen);
  SetLength(ATag, 16);

  if LCipherLen > 0 then
    Move(AEncrypted[0], ACipherText[0], LCipherLen);
  Move(AEncrypted[LCipherLen], ATag[0], 16);

  Result := True;
end;

function TLS13AEADIsSupported(ACipherSuite: Word): Boolean;
begin
  case ACipherSuite of
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
    TLS13_CIPHER_AES_128_GCM_SHA256,
    TLS13_CIPHER_AES_256_GCM_SHA384:
      Result := True;
  else
    Result := False;
  end;
end;

function TryTLS13AEADEncrypt(
  ACipherSuite: Word;
  const AKey, ANonce, AAAD, APlaintext: TBytes;
  out AEncrypted: TBytes;
  out AError: string
): Boolean;
var
  LCipherText: TBytes;
  LTag: TBytes;
begin
  SetLength(AEncrypted, 0);
  AError := '';

  case ACipherSuite of
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256:
      begin
        if not TryChaCha20Poly1305EncryptCombined(AKey, ANonce, AAAD, APlaintext, AEncrypted) then
        begin
          AError := 'ChaCha20-Poly1305 encryption failed';
          Exit(False);
        end;
        Result := True;
      end;

    TLS13_CIPHER_AES_128_GCM_SHA256,
    TLS13_CIPHER_AES_256_GCM_SHA384:
      begin
        if not ValidateAESGCMInputs(ACipherSuite, AKey, ANonce, AError) then
          Exit(False);

        if not PurePascalAESGCMEncrypt(AKey, ANonce, APlaintext, AAAD, LCipherText, LTag) then
        begin
          AError := 'AES-GCM encryption failed';
          Exit(False);
        end;

        if Length(LTag) <> 16 then
        begin
          AError := TextFormat('AES-GCM encryption returned invalid tag length: %d', [Length(LTag)]);
          Exit(False);
        end;

        CombineCipherTextAndTag(LCipherText, LTag, AEncrypted);
        Result := True;
      end;
  else
    begin
      AError := TextFormat('Unsupported TLS 1.3 cipher suite for pure AEAD: 0x%.4x', [ACipherSuite]);
      Result := False;
    end;
  end;
end;

function TryTLS13AEADDecrypt(
  ACipherSuite: Word;
  const AKey, ANonce, AAAD, AEncrypted: TBytes;
  out APlaintext: TBytes;
  out AError: string
): Boolean;
var
  LCipherText: TBytes;
  LTag: TBytes;
begin
  SetLength(APlaintext, 0);
  AError := '';

  case ACipherSuite of
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256:
      begin
        if not TryChaCha20Poly1305DecryptCombined(AKey, ANonce, AAAD, AEncrypted, APlaintext) then
        begin
          AError := 'ChaCha20-Poly1305 decryption/authentication failed';
          Exit(False);
        end;
        Result := True;
      end;

    TLS13_CIPHER_AES_128_GCM_SHA256,
    TLS13_CIPHER_AES_256_GCM_SHA384:
      begin
        if not ValidateAESGCMInputs(ACipherSuite, AKey, ANonce, AError) then
          Exit(False);

        if not SplitCipherTextAndTag(AEncrypted, LCipherText, LTag) then
        begin
          AError := 'AES-GCM encrypted payload must include 16-byte authentication tag';
          Exit(False);
        end;

        if not PurePascalAESGCMDecrypt(AKey, ANonce, LCipherText, LTag, AAAD, APlaintext) then
        begin
          AError := 'AES-GCM decryption/authentication failed';
          Exit(False);
        end;

        Result := True;
      end;
  else
    begin
      AError := TextFormat('Unsupported TLS 1.3 cipher suite for pure AEAD: 0x%.4x', [ACipherSuite]);
      Result := False;
    end;
  end;
end;

function TryTLS13AEADDecryptTo(
  ACipherSuite: Word;
  const AKey, ANonce, AAAD, AEncrypted: TBytes;
  ADest: PByte; ADestCap: Integer;
  out AFragLen: Integer; out AContentType: Byte; out AError: string
): Boolean;
var
  LTotalPlain: Integer;
  LTag: TBytes;
  LCipher: TBytes;
  LCipherLen: Integer;
begin
  AFragLen := 0;
  AContentType := 0;
  AError := '';
  Result := False;
  if (ADest = nil) and (ADestCap > 0) then
  begin
    AError := 'AEAD decryptTo: dest nil';
    Exit(False);
  end;
  case ACipherSuite of
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256:
      begin
        if Length(AEncrypted) < 16 then
        begin
          AError := 'ChaCha20-Poly1305 encrypted payload must include 16-byte tag';
          Exit(False);
        end;
        LTotalPlain := Length(AEncrypted) - 16;
        if ADestCap < LTotalPlain then
        begin
          AError := TextFormat('AEAD decryptTo: dest too small (%d < %d)', [ADestCap, LTotalPlain]);
          Exit(False);
        end;
        if not TryChaCha20Poly1305DecryptCombinedTo(AKey, ANonce, AAAD, AEncrypted, ADest, ADestCap) then
        begin
          AError := 'ChaCha20-Poly1305 decryption/authentication failed';
          Exit(False);
        end;
        if not TryParseTLS13InnerPlaintextTo(ADest, LTotalPlain, AFragLen, AContentType) then
        begin
          AError := 'TLS 1.3 inner plaintext invalid (chacha)';
          Exit(False);
        end;
        Result := True;
      end;
    TLS13_CIPHER_AES_128_GCM_SHA256,
    TLS13_CIPHER_AES_256_GCM_SHA384:
      begin
        if not ValidateAESGCMInputs(ACipherSuite, AKey, ANonce, AError) then
          Exit(False);
        if Length(AEncrypted) < 16 then
        begin
          AError := 'AES-GCM encrypted payload must include 16-byte authentication tag';
          Exit(False);
        end;
        LCipherLen := Length(AEncrypted) - 16;
        if ADestCap < LCipherLen then
        begin
          AError := TextFormat('AEAD decryptTo: dest too small (%d < %d)', [ADestCap, LCipherLen]);
          Exit(False);
        end;
        // Split ct/tag inline without full copy for ct? For now allocate small tag + ct slice (one copy).
        // Tag is last 16 bytes
        SetLength(LTag, 16);
        Move(AEncrypted[LCipherLen], LTag[0], 16);
        SetLength(LCipher, LCipherLen);
        if LCipherLen > 0 then
          Move(AEncrypted[0], LCipher[0], LCipherLen);
        if LCipherLen = 0 then
        begin
          if not PurePascalAESGCMDecryptTo(AKey, ANonce, nil, LTag, AAAD, ADest, ADestCap) then
          begin
            AError := 'AES-GCM decryption/authentication failed';
            Exit(False);
          end;
        end
        else
        begin
          if not PurePascalAESGCMDecryptTo(AKey, ANonce, LCipher, LTag, AAAD, ADest, ADestCap) then
          begin
            AError := 'AES-GCM decryption/authentication failed';
            Exit(False);
          end;
        end;
        if not TryParseTLS13InnerPlaintextTo(ADest, LCipherLen, AFragLen, AContentType) then
        begin
          AError := 'TLS 1.3 inner plaintext invalid (aes)';
          Exit(False);
        end;
        Result := True;
      end;
  else
    begin
      AError := TextFormat('Unsupported TLS 1.3 cipher suite for pure AEAD: 0x%.4x', [ACipherSuite]);
      Result := False;
    end;
  end;
end;

function TryTLS13AEADDecryptToBuf(
  ACipherSuite: Word;
  const AKey, ANonce, AAAD: TBytes;
  AEncrypted: PByte; AEncryptedLen: Integer;
  ADest: PByte; ADestCap: Integer;
  out AFragLen: Integer; out AContentType: Byte; out AError: string
): Boolean;
var
  LTotalPlain: Integer;
  LCipherLen: Integer;
  LTagBuf: array[0..15] of Byte;
  LCipher: TBytes;
  LTag: TBytes;
begin
  AFragLen := 0;
  AContentType := 0;
  AError := '';
  Result := False;
  if (AEncrypted = nil) and (AEncryptedLen > 0) then
  begin
    AError := 'AEAD decryptToBuf: encrypted nil';
    Exit(False);
  end;
  if (ADest = nil) and (ADestCap > 0) then
  begin
    AError := 'AEAD decryptToBuf: dest nil';
    Exit(False);
  end;
  case ACipherSuite of
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256:
      begin
        if AEncryptedLen < 16 then
        begin
          AError := 'ChaCha20-Poly1305 encrypted payload must include 16-byte tag';
          Exit(False);
        end;
        LTotalPlain := AEncryptedLen - 16;
        if ADestCap < LTotalPlain then
        begin
          AError := TextFormat('AEAD decryptToBuf: dest too small (%d < %d)', [ADestCap, LTotalPlain]);
          Exit(False);
        end;
        if not TryChaCha20Poly1305DecryptCombinedBuf(AKey, ANonce, AAAD, AEncrypted, AEncryptedLen, ADest, ADestCap) then
        begin
          AError := 'ChaCha20-Poly1305 decryption/authentication failed';
          Exit(False);
        end;
        if not TryParseTLS13InnerPlaintextTo(ADest, LTotalPlain, AFragLen, AContentType) then
        begin
          AError := 'TLS 1.3 inner plaintext invalid (chacha buf)';
          Exit(False);
        end;
        Result := True;
      end;
    TLS13_CIPHER_AES_128_GCM_SHA256,
    TLS13_CIPHER_AES_256_GCM_SHA384:
      begin
        if not ValidateAESGCMInputs(ACipherSuite, AKey, ANonce, AError) then
          Exit(False);
        if AEncryptedLen < 16 then
        begin
          AError := 'AES-GCM encrypted payload must include 16-byte authentication tag';
          Exit(False);
        end;
        LCipherLen := AEncryptedLen - 16;
        if ADestCap < LCipherLen then
        begin
          AError := TextFormat('AEAD decryptToBuf: dest too small (%d < %d)', [ADestCap, LCipherLen]);
          Exit(False);
        end;
        Move((AEncrypted + LCipherLen)^, LTagBuf[0], 16);
        if LCipherLen = 0 then
        begin
          if (Length(AKey) = 16) and (Length(ANonce) = 12) then
          begin
            if not nextpas.core.crypto.aesgcm.AESNIGCMDecryptTo128Ptr(AKey, @ANonce[0], 12, nil, 0, @LTagBuf[0], AAAD, ADest, ADestCap) then
            begin
              AError := 'AES-GCM decryption/authentication failed';
              Exit(False);
            end;
          end
          else if (Length(AKey) = 32) and (Length(ANonce) = 12) then
          begin
            if not nextpas.core.crypto.aesgcm.AESNIGCMDecryptTo256Ptr(AKey, @ANonce[0], 12, nil, 0, @LTagBuf[0], AAAD, ADest, ADestCap) then
            begin
              AError := 'AES-GCM decryption/authentication failed';
              Exit(False);
            end;
          end
          else
          begin
            SetLength(LTag, 16);
            Move(LTagBuf[0], LTag[0], 16);
            if not PurePascalAESGCMDecryptTo(AKey, ANonce, nil, LTag, AAAD, ADest, ADestCap) then
            begin
              AError := 'AES-GCM decryption/authentication failed';
              Exit(False);
            end;
          end;
        end
        else
        begin
          if (Length(AKey) = 16) and (Length(ANonce) = 12) then
          begin
            if not nextpas.core.crypto.aesgcm.AESNIGCMDecryptTo128Ptr(AKey, @ANonce[0], 12, AEncrypted, LCipherLen, @LTagBuf[0], AAAD, ADest, ADestCap) then
            begin
              AError := 'AES-GCM decryption/authentication failed';
              Exit(False);
            end;
          end
          else if (Length(AKey) = 32) and (Length(ANonce) = 12) then
          begin
            if not nextpas.core.crypto.aesgcm.AESNIGCMDecryptTo256Ptr(AKey, @ANonce[0], 12, AEncrypted, LCipherLen, @LTagBuf[0], AAAD, ADest, ADestCap) then
            begin
              AError := 'AES-GCM decryption/authentication failed';
              Exit(False);
            end;
          end
          else
          begin
            // Fallback scalar: need CT as TBytes copy
            SetLength(LTag, 16);
            Move(LTagBuf[0], LTag[0], 16);
            SetLength(LCipher, LCipherLen);
            Move(AEncrypted^, LCipher[0], LCipherLen);
            if not PurePascalAESGCMDecryptTo(AKey, ANonce, LCipher, LTag, AAAD, ADest, ADestCap) then
            begin
              AError := 'AES-GCM decryption/authentication failed';
              Exit(False);
            end;
          end;
        end;
        if not TryParseTLS13InnerPlaintextTo(ADest, LCipherLen, AFragLen, AContentType) then
        begin
          AError := 'TLS 1.3 inner plaintext invalid (aes buf)';
          Exit(False);
        end;
        Result := True;
      end;
  else
    begin
      AError := TextFormat('Unsupported TLS 1.3 cipher suite for pure AEAD: 0x%.4x', [ACipherSuite]);
      Result := False;
    end;
  end;
end;

function TryTLS13AEADEncryptToBuf(
  ACipherSuite: Word;
  const AKey, ANonce, AAAD: TBytes;
  APlain: PByte; APlainLen: Integer;
  ADest: PByte; ADestCap: Integer;
  out AEncryptedLen: Integer; out AError: string): Boolean;
var
  LPlain, LCipher, LTag: TBytes;
begin
  AEncryptedLen := 0;
  AError := '';
  Result := False;
  if (APlain = nil) and (APlainLen > 0) then
  begin
    AError := 'AEAD encryptToBuf: plain nil';
    Exit(False);
  end;
  if (ADest = nil) and (APlainLen + 16 > 0) then
  begin
    AError := 'AEAD encryptToBuf: dest nil';
    Exit(False);
  end;
  if ADestCap < APlainLen + 16 then
  begin
    AError := TextFormat('AEAD encryptToBuf: dest too small (%d < %d)', [ADestCap, APlainLen + 16]);
    Exit(False);
  end;
  case ACipherSuite of
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256:
      begin
        if not TryChaCha20Poly1305EncryptToBuf(AKey, ANonce, AAAD, APlain, APlainLen, ADest, ADestCap) then
        begin
          AError := 'ChaCha20-Poly1305 encryption failed';
          Exit(False);
        end;
        AEncryptedLen := APlainLen + 16;
        Result := True;
      end;
    TLS13_CIPHER_AES_128_GCM_SHA256,
    TLS13_CIPHER_AES_256_GCM_SHA384:
      begin
        if not ValidateAESGCMInputs(ACipherSuite, AKey, ANonce, AError) then
          Exit(False);
        if Length(AKey) = 16 then
        begin
          if not nextpas.core.crypto.aesgcm.AESNIGCMEncryptTo128Ptr(AKey, @ANonce[0], 12, APlain, APlainLen, AAAD, ADest, ADestCap) then
          begin
            AError := 'AES-GCM encryption failed';
            Exit(False);
          end;
        end
        else if Length(AKey) = 32 then
        begin
          if not nextpas.core.crypto.aesgcm.AESNIGCMEncryptTo256Ptr(AKey, @ANonce[0], 12, APlain, APlainLen, AAAD, ADest, ADestCap) then
          begin
            AError := 'AES-GCM encryption failed';
            Exit(False);
          end;
        end
        else
        begin
          // fallback scalar not yet PByte — use TBytes path then copy
          SetLength(LPlain, APlainLen);
          if APlainLen > 0 then Move(APlain^, LPlain[0], APlainLen);
          if not PurePascalAESGCMEncrypt(AKey, ANonce, LPlain, AAAD, LCipher, LTag) then
          begin
            AError := 'AES-GCM encryption failed';
            Exit(False);
          end;
          if Length(LCipher) <> APlainLen then
          begin
            AError := 'AES-GCM encrypt length mismatch';
            Exit(False);
          end;
          Move(LCipher[0], ADest^, APlainLen);
          Move(LTag[0], (ADest + APlainLen)^, 16);
        end;
        AEncryptedLen := APlainLen + 16;
        Result := True;
      end;
  else
    begin
      AError := TextFormat('Unsupported TLS 1.3 cipher suite for pure AEAD: 0x%.4x', [ACipherSuite]);
      Result := False;
    end;
  end;
end;

end.
