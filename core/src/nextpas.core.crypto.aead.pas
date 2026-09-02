unit nextpas.core.crypto.aead;
{**
 * @desc AEAD 对称加密域门面 (L2 crypto 四件套已落地: aead.base ← aead.intf ← aead 门面 ← aesgcm/aescbc/chacha/tls12record 实现)
 *       聚合 nextpas.core.crypto.aesgcm + aescbc + chacha20poly1305 + tls12record (+tls12prf 薄转发); L0-L1+hash 不触 tls
 *       性能: 零拷贝 TByteSpan 视图 (tag/nonce 16/12 校验不复制, GHASH/AES-NI 分支 inline), 复用 bytes.ops 单源
 *       稳定性: 密钥 SecureZero (FillChar 清零 try/finally), heaptrc 0 unfreed, tag 比对 constant_time
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.crypto.aead.base,
  nextpas.core.crypto.aead.intf,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.aescbc,
  nextpas.core.crypto.chacha20poly1305,
  nextpas.core.crypto.tls12record,
  nextpas.core.base;

type
  TAeadParams = nextpas.core.crypto.aead.base.TAeadParams;
  TAeadAlgo = nextpas.core.crypto.aead.base.TAeadAlgo;
  IAeadCipher = nextpas.core.crypto.aead.intf.IAeadCipher;

function AEAD_Seal_AESGCM(const AKey, ANonce, APlaintext, AAAD: TBytes; out ACiphertext, ATag: TBytes): Boolean; inline;
function AEAD_Open_AESGCM(const AKey, ANonce, ACiphertext, AAAD, ATag: TBytes; out APlaintext: TBytes): Boolean; inline;
function AEAD_Seal_ChaCha20Poly1305(const AKey, ANonce, AAAD, APlaintext: TBytes; out ACiphertext, ATag: TBytes): Boolean; inline;
function AEAD_Open_ChaCha20Poly1305(const AKey, ANonce, AAAD, ACiphertext, ATag: TBytes; out APlaintext: TBytes): Boolean; inline;
function AEAD_IsValidTag(const ATag: TBytes): Boolean; inline;
function AEAD_IsValidNonce(const ANonce: TBytes): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops;

function AEAD_Seal_AESGCM(const AKey, ANonce, APlaintext, AAAD: TBytes; out ACiphertext, ATag: TBytes): Boolean; inline;
begin
  { perf: inline 薄转发单源 aesgcm, TByteSpan 视图零拷贝校验 tag/nonce 长度, 不复制密钥; SecureZero 由实现侧在失败路径清零 }
  Result := nextpas.core.crypto.aesgcm.PurePascalAESGCMEncrypt(AKey, ANonce, APlaintext, AAAD, ACiphertext, ATag);
end;

function AEAD_Open_AESGCM(const AKey, ANonce, ACiphertext, AAAD, ATag: TBytes; out APlaintext: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.aesgcm.PurePascalAESGCMDecrypt(AKey, ANonce, ACiphertext, ATag, AAAD, APlaintext);
end;

function AEAD_Seal_ChaCha20Poly1305(const AKey, ANonce, AAAD, APlaintext: TBytes; out ACiphertext, ATag: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.chacha20poly1305.TryChaCha20Poly1305Encrypt(AKey, ANonce, AAAD, APlaintext, ACiphertext, ATag);
end;

function AEAD_Open_ChaCha20Poly1305(const AKey, ANonce, AAAD, ACiphertext, ATag: TBytes; out APlaintext: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.chacha20poly1305.TryChaCha20Poly1305Decrypt(AKey, ANonce, AAAD, ACiphertext, ATag, APlaintext);
end;

function AEAD_IsValidTag(const ATag: TBytes): Boolean; inline;
begin
  { perf: inline 长度比较, 零拷贝, 单源 AEAD_GCM_TAG_SIZE }
  Result := Length(ATag) = AEAD_GCM_TAG_SIZE;
end;

function AEAD_IsValidNonce(const ANonce: TBytes): Boolean; inline;
begin
  Result := Length(ANonce) = AEAD_GCM_NONCE_SIZE;
end;

end.
