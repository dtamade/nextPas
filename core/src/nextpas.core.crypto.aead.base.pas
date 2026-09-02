unit nextpas.core.crypto.aead.base;

{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.aead.base — AEAD 对称加密域公共载体 (L2 crypto)
  Owner: crypto. 纯常量/记录, L0-L1+hash, 禁止依赖 tls. }

interface

const
  AEAD_GCM_TAG_SIZE = 16;
  AEAD_GCM_NONCE_SIZE = 12;
  AEAD_GCM_KEY_SIZE_128 = 16;
  AEAD_GCM_KEY_SIZE_256 = 32;
  AEAD_CHACHA_KEY_SIZE = 32;
  AEAD_CHACHA_NONCE_SIZE = 12;
  AEAD_CHACHA_TAG_SIZE = 16;
  AEAD_CBC_BLOCK_SIZE = 16;
  AEAD_TLS12_RECORD_MAX_CIPHER_LEN = 16384 + 2048;

type
  TAeadAlgo = (aeadAES128GCM, aeadAES256GCM, aeadChaCha20Poly1305, aeadAESCBC);

  TAeadParams = record
    Algo: TAeadAlgo;
    KeySize: Integer;
    NonceSize: Integer;
    TagSize: Integer;
    class function GCM128: TAeadParams; static; inline;
    class function GCM256: TAeadParams; static; inline;
    class function ChaCha: TAeadParams; static; inline;
  end;

implementation

class function TAeadParams.GCM128: TAeadParams; static; inline;
begin
  Result.Algo := aeadAES128GCM;
  Result.KeySize := AEAD_GCM_KEY_SIZE_128;
  Result.NonceSize := AEAD_GCM_NONCE_SIZE;
  Result.TagSize := AEAD_GCM_TAG_SIZE;
end;

class function TAeadParams.GCM256: TAeadParams; static; inline;
begin
  Result.Algo := aeadAES256GCM;
  Result.KeySize := AEAD_GCM_KEY_SIZE_256;
  Result.NonceSize := AEAD_GCM_NONCE_SIZE;
  Result.TagSize := AEAD_GCM_TAG_SIZE;
end;

class function TAeadParams.ChaCha: TAeadParams; static; inline;
begin
  Result.Algo := aeadChaCha20Poly1305;
  Result.KeySize := AEAD_CHACHA_KEY_SIZE;
  Result.NonceSize := AEAD_CHACHA_NONCE_SIZE;
  Result.TagSize := AEAD_CHACHA_TAG_SIZE;
end;

end.
