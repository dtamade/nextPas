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
  nextpas.core.base;

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

implementation

uses
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.chacha20poly1305,
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
    AError := Format('Unsupported TLS 1.3 AES-GCM suite: 0x%.4x', [ACipherSuite]);
    Exit(False);
  end;

  if Length(AKey) <> LExpectedKeyLen then
  begin
    AError := Format(
      'Invalid AES-GCM key length for suite 0x%.4x: expected %d bytes, got %d',
      [ACipherSuite, LExpectedKeyLen, Length(AKey)]
    );
    Exit(False);
  end;

  if Length(ANonce) <> 12 then
  begin
    AError := Format('Invalid AES-GCM nonce length: expected 12 bytes, got %d', [Length(ANonce)]);
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
          AError := Format('AES-GCM encryption returned invalid tag length: %d', [Length(LTag)]);
          Exit(False);
        end;

        CombineCipherTextAndTag(LCipherText, LTag, AEncrypted);
        Result := True;
      end;
  else
    begin
      AError := Format('Unsupported TLS 1.3 cipher suite for pure AEAD: 0x%.4x', [ACipherSuite]);
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
      AError := Format('Unsupported TLS 1.3 cipher suite for pure AEAD: 0x%.4x', [ACipherSuite]);
      Result := False;
    end;
  end;
end;

end.
