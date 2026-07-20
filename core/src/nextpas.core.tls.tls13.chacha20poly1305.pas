{**
 * Unit: nextpas.core.tls.tls13.chacha20poly1305
 * Purpose: Compatibility shim — implementation lives in crypto.
 *
 * Prefer: nextpas.core.crypto.chacha20poly1305
 *}

unit nextpas.core.tls.tls13.chacha20poly1305;

{$mode ObjFPC}{$H+}
{$WARN 5093 off}

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.chacha20poly1305;

function TryChaCha20Poly1305Encrypt(
  const AKey, ANonce, AAAD, APlaintext: TBytes;
  out ACiphertext, ATag: TBytes
): Boolean; inline;

function TryChaCha20Poly1305Decrypt(
  const AKey, ANonce, AAAD, ACiphertext, ATag: TBytes;
  out APlaintext: TBytes
): Boolean; inline;

function TryChaCha20Poly1305EncryptCombined(
  const AKey, ANonce, AAAD, APlaintext: TBytes;
  out AEncrypted: TBytes
): Boolean; inline;

function TryChaCha20Poly1305DecryptCombined(
  const AKey, ANonce, AAAD, AEncrypted: TBytes;
  out APlaintext: TBytes
): Boolean; inline;

implementation

function TryChaCha20Poly1305Encrypt(
  const AKey, ANonce, AAAD, APlaintext: TBytes;
  out ACiphertext, ATag: TBytes
): Boolean;
begin
  Result := nextpas.core.crypto.chacha20poly1305.TryChaCha20Poly1305Encrypt(
    AKey, ANonce, AAAD, APlaintext, ACiphertext, ATag);
end;

function TryChaCha20Poly1305Decrypt(
  const AKey, ANonce, AAAD, ACiphertext, ATag: TBytes;
  out APlaintext: TBytes
): Boolean;
begin
  Result := nextpas.core.crypto.chacha20poly1305.TryChaCha20Poly1305Decrypt(
    AKey, ANonce, AAAD, ACiphertext, ATag, APlaintext);
end;

function TryChaCha20Poly1305EncryptCombined(
  const AKey, ANonce, AAAD, APlaintext: TBytes;
  out AEncrypted: TBytes
): Boolean;
begin
  Result := nextpas.core.crypto.chacha20poly1305.TryChaCha20Poly1305EncryptCombined(
    AKey, ANonce, AAAD, APlaintext, AEncrypted);
end;

function TryChaCha20Poly1305DecryptCombined(
  const AKey, ANonce, AAAD, AEncrypted: TBytes;
  out APlaintext: TBytes
): Boolean;
begin
  Result := nextpas.core.crypto.chacha20poly1305.TryChaCha20Poly1305DecryptCombined(
    AKey, ANonce, AAAD, AEncrypted, APlaintext);
end;

end.
