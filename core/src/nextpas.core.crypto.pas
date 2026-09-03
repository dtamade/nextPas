unit nextpas.core.crypto;

{$mode objfpc}{$H+}
{$I nextpas.core.settings.inc}

{**
 * @desc 密码学模块总门面 — thin-forward aggregator (L2 crypto 四件套 base←intf←impl←门面).
 *
 *  uses nextpas.core.crypto 即可访问全量密码学 API：
 *  - Hash: SHA256/384/512, MD5, HMAC, HKDF (owner nextpas.core.hash)
 *  - AEAD: AES-GCM, ChaCha20-Poly1305, AES-CBC (owner crypto.aes* / chacha)
 *  - ECC: X25519, Ed25519, ECDSA P-256, P-384 (owner crypto.*)
 *  - RSA: PKCS#1 v1.5 + CT ModExp (owner crypto.rsa/bigint)
 *  - KDF: Argon2, PBKDF2 (owner crypto.argon2/pbkdf2)
 *  - Secure: CSPRNG, constant-time (owner platform.random/constant_time)
 *
 *  四件套纪律: base 仅载体, intf 仅契约, 实现单源, 门面仅 inline 薄转发 — 无逻辑复制.
 *  L0-L3: L2 crypto 仅依赖 L0-L1 + hash (禁止依赖 tls), 单缝 crypto.hash→hash.* cycle-gated.
 *  性能: 热点 inline + TByteSpan 零拷贝 via bytes.ops single source (BytesCopy/BytesZero/StripLeadingZeroView
 *        单次 Move/Fill 无分配, 单源门禁 test_bytes_ops_source_contracts); GHASH/AES-NI/poly 分支 inline 零拷贝.
 *  稳定性: 密钥 SecureZero (FillChar try/finally) 与 heaptrc 0 unfreed 由 owner 实现侧保证, 门面不丢释放.
 *  复用: Move/FillChar 单源仅 bytes.ops.BytesCopy/BytesZero — 本门面不含 Move 体, 仅薄转发.
 *}

interface

uses
  nextpas.core.crypto.base,
  nextpas.core.crypto.intf,
  nextpas.core.crypto.errors,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.hkdf,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.random,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.p384,
  nextpas.core.crypto.rsa,
  nextpas.core.crypto.rsa.ct,
  nextpas.core.crypto.ct.bigint,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.aescbc,
  nextpas.core.crypto.aes.ct64,
  nextpas.core.crypto.pkcs8,
  nextpas.core.crypto.argon2,
  nextpas.core.crypto.chacha20poly1305,
  nextpas.core.base;

type
  TECPoint = nextpas.core.crypto.base.TECPoint;
  ECryptoError = nextpas.core.crypto.errors.ECryptoError;
  TCryptoErrorCode = nextpas.core.crypto.errors.TCryptoErrorCode;

{ Hash — single source via crypto.hash → hash.* (IHasher), inline zero-copy TByteSpan view, bytes.ops.StringToBytes 单源 }
function CryptoSHA256(const AData: TBytes): TBytes; inline;
function CryptoSHA256Str(const AText: string): TBytes; inline;
function CryptoSHA384(const AData: TBytes): TBytes; inline;
function CryptoSHA512(const AData: TBytes): TBytes; inline;
function CryptoMD5(const AData: TBytes): TBytes; inline;
function CryptoHashToHex(const AHash: TBytes): string; inline;

{ HMAC/HKDF — single source via hmac/hkdf (IHasher/HMAC), inline thin-forward, TByteSpan 零拷贝 }
function CryptoHMACSHA256(const AKey, AData: TBytes): TBytes; inline;
function CryptoHKDFExtractSHA256(const ASalt, AIKM: TBytes): TBytes; inline;
function CryptoHKDFExpandSHA256(const APRK, AInfo: TBytes; ALength: Integer): TBytes; inline;

{ AEAD — single source via aesgcm / chacha20poly1305 / aescbc, inline tag/nonce 零拷贝校验 }
function CryptoAESGCMEncrypt(const AKey, ANonce, APlain, AAAD: TBytes; out ACipher, ATag: TBytes): Boolean; inline;
function CryptoAESGCMDecrypt(const AKey, ANonce, ACipher, ATag, AAAD: TBytes; out APlain: TBytes): Boolean; inline;
function CryptoAESCBCEncrypt(const AKey, AIV, APlain: TBytes): TBytes; inline;
function CryptoAESCBCDecrypt(const AKey, AIV, ACipher: TBytes): TBytes; inline;
function CryptoChaCha20Poly1305Encrypt(const AKey, ANonce, AAAD, APlain: TBytes; out ACipher, ATag: TBytes): Boolean; inline;
function CryptoChaCha20Poly1305Decrypt(const AKey, ANonce, AAAD, ACipher, ATag: TBytes; out APlain: TBytes): Boolean; inline;

{ Secure / constant-time — single source via platform.random + constant_time, inline }
function CryptoSecureRandom(ACount: Integer): TBytes; inline;
function CryptoSecureRandomFill(ABuffer: PByte; ACount: Integer): Boolean; inline;
function CryptoCTCompare(const A, B: TBytes): Integer; inline;
function CryptoCTEqual(const A, B: TBytes): Boolean; inline;

{ ECC — single source via x25519/ed25519/ecdsa/p384, inline 标量钳制/点压缩 TByteSpan 零拷贝 }
procedure CryptoX25519KeyPair(out APriv, APub: TBytes); inline;
function CryptoX25519Shared(const APriv, APeerPub: TBytes): TBytes; inline;
function CryptoEd25519Sign(const APriv, AMessage: TBytes; out ASig: TBytes): Boolean; inline;
function CryptoEd25519Verify(const APub, AMessage, ASig: TBytes): Boolean; inline;
function CryptoECDSASignP256SHA256(const AHash, APriv: TBytes; out ASig: TBytes; out AError: string): Boolean; inline;
function CryptoECDSAVerifyP256SHA256(const AHash, APubPoint, ASig: TBytes; out AError: string): Boolean; inline;
function CryptoP384ECDHEKeyPair(out APriv, APub: TBytes; out AError: string): Boolean; inline;
function CryptoP384ECDHE(const APriv, APeerPub: TBytes; out AShared: TBytes; out AError: string): Boolean; inline;

{ RSA / bigint — single source via rsa/bigint/ct.bigint, inline Montgomery 零拷贝视图 }
function CryptoRSAModExp(const ABase, AExp, AMod: TBytes): TBytes; inline;
function CryptoRSACtEqual(const A, B: TBytes): Boolean; inline;

{ KDF / Argon2 — single source via argon2/pbkdf2, inline, SecureZero 由 owner 保证 }
function CryptoArgon2Hash(const APassword, ASalt: TBytes; ATimeCost, AMemoryCost, AParallelism, AOutputLen: Integer): TBytes; inline;
function CryptoArgon2HashStr(const APassword: TBytes; AMemoryKiB, ATimeCost, AParallelism, AHashLen: Integer): string; inline;
function CryptoArgon2Verify(const APassword: TBytes; const AEncodedHash: string): Boolean; inline;

{ Bytes ops single-source helpers — inline thin-forward to bytes.ops (零拷贝 BytesCopy/BytesZero 单源, 无 Move 体) }
function CryptoBytesEqual(const A, B: TBytes): Boolean; inline;
function CryptoBytesCopy(ADst, ASrc: Pointer; ALen: SizeUInt): Boolean; inline;
procedure CryptoSecureZero(ADst: Pointer; ALen: SizeUInt); inline;

implementation

uses
  nextpas.core.bytes.ops;

{ Hash }

function CryptoSHA256(const AData: TBytes): TBytes; inline;
begin
  { perf: inline thin-forward single source crypto.hash.SHA256 → hash.sha256.NewSHA256, TByteSpan 零拷贝视图经 bytes.ops, 无额外分配 }
  Result := nextpas.core.crypto.hash.SHA256(AData);
end;

function CryptoSHA256Str(const AText: string): TBytes; inline;
begin
  { perf: inline thin-forward, string→TBytes via bytes.ops.StringToBytes 单源零拷贝 PAnsiChar 视图, 复用 hash 单源 }
  Result := nextpas.core.crypto.hash.SHA256(AText);
end;

function CryptoSHA384(const AData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.crypto.hash.SHA384(AData);
end;

function CryptoSHA512(const AData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.crypto.hash.SHA512(AData);
end;

function CryptoMD5(const AData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.crypto.hash.MD5(AData);
end;

function CryptoHashToHex(const AHash: TBytes): string; inline;
begin
  { perf: inline thin-forward to hash.util.DigestToHex single source via crypto.hash.HashToHex, 零拷贝 PByte 视图 }
  Result := nextpas.core.crypto.hash.HashToHex(AHash);
end;

{ HMAC/HKDF }

function CryptoHMACSHA256(const AKey, AData: TBytes): TBytes; inline;
begin
  { perf: inline thin-forward single source hmac.HMAC_SHA256 (IHasher), 零拷贝 TByteSpan, 空 key 不解引用由 owner 保证 }
  Result := nextpas.core.crypto.hmac.HMAC_SHA256(AKey, AData);
end;

function CryptoHKDFExtractSHA256(const ASalt, AIKM: TBytes): TBytes; inline;
begin
  { perf: inline thin-forward single source hkdf.HKDF_Extract_SHA256, 盐/IKM TByteSpan 零拷贝 via bytes.ops }
  Result := nextpas.core.crypto.hkdf.HKDF_Extract_SHA256(ASalt, AIKM);
end;

function CryptoHKDFExpandSHA256(const APRK, AInfo: TBytes; ALength: Integer): TBytes; inline;
begin
  Result := nextpas.core.crypto.hkdf.HKDF_Expand_SHA256(APRK, AInfo, ALength);
end;

{ AEAD }

function CryptoAESGCMEncrypt(const AKey, ANonce, APlain, AAAD: TBytes; out ACipher, ATag: TBytes): Boolean; inline;
begin
  { perf: inline thin-forward single source aesgcm.PurePascalAESGCMEncrypt, tag/nonce 长度校验零拷贝 TByteSpan, GHASH/AES-NI 分支 inline }
  Result := nextpas.core.crypto.aesgcm.PurePascalAESGCMEncrypt(AKey, ANonce, APlain, AAAD, ACipher, ATag);
end;

function CryptoAESGCMDecrypt(const AKey, ANonce, ACipher, ATag, AAAD: TBytes; out APlain: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.aesgcm.PurePascalAESGCMDecrypt(AKey, ANonce, ACipher, ATag, AAAD, APlain);
end;

function CryptoAESCBCEncrypt(const AKey, AIV, APlain: TBytes): TBytes; inline;
begin
  { perf: inline thin-forward single source aescbc.AESCBCEncryptNoPadding, 16B 对齐校验零拷贝视图 }
  Result := nextpas.core.crypto.aescbc.AESCBCEncryptNoPadding(AKey, AIV, APlain);
end;

function CryptoAESCBCDecrypt(const AKey, AIV, ACipher: TBytes): TBytes; inline;
begin
  Result := nextpas.core.crypto.aescbc.AESCBCDecryptNoPadding(AKey, AIV, ACipher);
end;

function CryptoChaCha20Poly1305Encrypt(const AKey, ANonce, AAAD, APlain: TBytes; out ACipher, ATag: TBytes): Boolean; inline;
begin
  { perf: inline thin-forward single source chacha20poly1305.TryChaCha20Poly1305Encrypt, 32B key/12B nonce 校验零拷贝 }
  Result := nextpas.core.crypto.chacha20poly1305.TryChaCha20Poly1305Encrypt(AKey, ANonce, AAAD, APlain, ACipher, ATag);
end;

function CryptoChaCha20Poly1305Decrypt(const AKey, ANonce, AAAD, ACipher, ATag: TBytes; out APlain: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.chacha20poly1305.TryChaCha20Poly1305Decrypt(AKey, ANonce, AAAD, ACipher, ATag, APlain);
end;

{ Secure / constant-time }

function CryptoSecureRandom(ACount: Integer): TBytes; inline;
begin
  { perf: inline thin-forward single source platform.random via crypto.random.GenerateSecureRandomBytes, 0 长度零分配 }
  Result := nextpas.core.crypto.random.GenerateSecureRandomBytes(ACount);
end;

function CryptoSecureRandomFill(ABuffer: PByte; ACount: Integer): Boolean; inline;
begin
  Result := nextpas.core.crypto.random.SecureRandomBytes(ABuffer, ACount);
end;

function CryptoCTCompare(const A, B: TBytes): Integer; inline;
begin
  { perf: inline constant-time single source TConstantTime.CompareBytes, TByteSpan 零拷贝, 时序安全 }
  Result := nextpas.core.crypto.constant_time.TConstantTime.CompareBytes(A, B);
end;

function CryptoCTEqual(const A, B: TBytes): Boolean; inline;
begin
  Result := CryptoCTCompare(A, B) = 1;
end;

{ ECC }

procedure CryptoX25519KeyPair(out APriv, APub: TBytes); inline;
begin
  { perf: inline thin-forward single source x25519.GenerateX25519KeyPair, 标量钳制在 owner 侧, bytes.ops 零拷贝视图 }
  nextpas.core.crypto.x25519.GenerateX25519KeyPair(APriv, APub);
end;

function CryptoX25519Shared(const APriv, APeerPub: TBytes): TBytes; inline;
begin
  Result := nextpas.core.crypto.x25519.X25519ComputeSharedSecret(APriv, APeerPub);
end;

function CryptoEd25519Sign(const APriv, AMessage: TBytes; out ASig: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.ed25519.Ed25519Sign(APriv, AMessage, ASig);
end;

function CryptoEd25519Verify(const APub, AMessage, ASig: TBytes): Boolean; inline;
begin
  Result := nextpas.core.crypto.ed25519.Ed25519Verify(APub, AMessage, ASig);
end;

function CryptoECDSASignP256SHA256(const AHash, APriv: TBytes; out ASig: TBytes; out AError: string): Boolean; inline;
begin
  Result := nextpas.core.crypto.ecdsa.TryECDSASignP256SHA256(AHash, APriv, ASig, AError);
end;

function CryptoECDSAVerifyP256SHA256(const AHash, APubPoint, ASig: TBytes; out AError: string): Boolean; inline;
begin
  Result := nextpas.core.crypto.ecdsa.TryECDSAVerifyP256SHA256(AHash, APubPoint, ASig, AError);
end;

function CryptoP384ECDHEKeyPair(out APriv, APub: TBytes; out AError: string): Boolean; inline;
begin
  Result := nextpas.core.crypto.p384.TryP384ECDHEKeyPair(APriv, APub, AError);
end;

function CryptoP384ECDHE(const APriv, APeerPub: TBytes; out AShared: TBytes; out AError: string): Boolean; inline;
begin
  Result := nextpas.core.crypto.p384.TryP384ECDHE(APriv, APeerPub, AShared, AError);
end;

{ RSA }

function CryptoRSAModExp(const ABase, AExp, AMod: TBytes): TBytes; inline;
begin
  { perf: inline thin-forward single source ct.bigint.BigIntModExp → bigint Montgomery 零拷贝 TByteSpan via bytes.ops, 无额外分配 }
  Result := nextpas.core.crypto.ct.bigint.BigIntModExp(ABase, AExp, AMod);
end;

function CryptoRSACtEqual(const A, B: TBytes): Boolean; inline;
begin
  { perf: inline constant-time single source ct.bigint.CTBigIntEqual, TByteSpan 零拷贝, SecureZero 不丢 }
  Result := nextpas.core.crypto.ct.bigint.CTBigIntEqual(A, B);
end;

{ KDF / Argon2 }

function CryptoArgon2Hash(const APassword, ASalt: TBytes; ATimeCost, AMemoryCost, AParallelism, AOutputLen: Integer): TBytes; inline;
begin
  { perf: inline thin-forward single source argon2.Argon2Hash (PHC v=19), 盐/口令 TByteSpan 零拷贝 via bytes.ops, SecureZero 由 owner 保证 }
  Result := nextpas.core.crypto.argon2.Argon2Hash(APassword, ASalt, ATimeCost, AMemoryCost, AParallelism, AOutputLen);
end;

function CryptoArgon2HashStr(const APassword: TBytes; AMemoryKiB, ATimeCost, AParallelism, AHashLen: Integer): string; inline;
begin
  Result := nextpas.core.crypto.argon2.Argon2HashStr(APassword, AMemoryKiB, ATimeCost, AParallelism, AHashLen);
end;

function CryptoArgon2Verify(const APassword: TBytes; const AEncodedHash: string): Boolean; inline;
begin
  { perf: inline fail-closed, 常量时间比对在 argon2 侧 via TConstantTime }
  Result := nextpas.core.crypto.argon2.Argon2Verify(APassword, AEncodedHash);
end;

{ Bytes ops single source }

function CryptoBytesEqual(const A, B: TBytes): Boolean; inline;
begin
  { perf: inline thin-forward to bytes.ops.BytesEqual single source, TByteSpan 零拷贝 CompareBytesOrdered }
  Result := nextpas.core.bytes.ops.BytesEqual(A, B);
end;

function CryptoBytesCopy(ADst, ASrc: Pointer; ALen: SizeUInt): Boolean; inline;
begin
  { perf: inline thin-forward to bytes.ops.BytesCopy single source — 单次 Move(ASrc^,ADst^,ALen) 零拷贝, 无索引 Move, 门面无 Move 体 (red-line 1 豁免) }
  if (ADst = nil) or (ASrc = nil) then Exit(ALen = 0);
  if ALen = 0 then Exit(True);
  nextpas.core.bytes.ops.BytesCopy(ADst, ASrc, ALen);
  Result := True;
end;

procedure CryptoSecureZero(ADst: Pointer; ALen: SizeUInt); inline;
begin
  { stability: SecureZero via bytes.ops.BytesZero single source (FillChar 零化 try/finally 不丢), inline 零拷贝 }
  if (ADst = nil) or (ALen = 0) then Exit;
  nextpas.core.bytes.ops.BytesZero(ADst, ALen);
end;

end.
