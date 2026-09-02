unit nextpas.core.crypto.kdf;
{**
 * @desc KDF/口令哈希域门面 (L2 crypto 四件套已落地: kdf.base ← kdf.intf ← kdf 门面 ← argon2/hkdf/pbkdf2/bcrypt_pbkdf 实现)
 *       聚合 nextpas.core.crypto.argon2 + hkdf + pbkdf2 + bcrypt_pbkdf + hmac; L0-L1+hash 不触 tls
 *       性能: 复用 bytes.ops 单源 (盐/密钥 TByteSpan 视图零拷贝), 热点 inline (HKDF expand/Argon2 校验薄转发)
 *       稳定性: SecureZeroMemory 释放不丢 (密钥/盐拷贝后清零, try/finally), heaptrc 0 unfreed
 *       Owner: 缺能力先反哺 hash/bytes.ops/platform.random
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.crypto.kdf.base,
  nextpas.core.crypto.kdf.intf,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.hkdf,
  nextpas.core.crypto.pbkdf2,
  nextpas.core.crypto.bcrypt_pbkdf,
  nextpas.core.crypto.argon2,
  nextpas.core.base;

type
  TKDFParams = nextpas.core.crypto.kdf.base.TKDFParams;
  TKDFAlgo = nextpas.core.crypto.kdf.base.TKDFAlgo;
  IKDFDeriver = nextpas.core.crypto.kdf.intf.IKDFDeriver;

function KDF_HKDF_Extract_SHA256(const ASalt, AIKM: TBytes): TBytes; inline;
function KDF_HKDF_Expand_SHA256(const APRK, AInfo: TBytes; ALength: Integer): TBytes; inline;
function KDF_PBKDF2_SHA256(const APassword, ASalt: TBytes; AIterations, AKeyLen: Integer): TBytes; inline;
function KDF_Argon2Hash(const APassword, ASalt: TBytes; ATimeCost, AMemoryCost, AParallelism, AOutputLen: Integer): TBytes; inline;
function KDF_Argon2HashStr(const APassword: TBytes; AMemoryKiB, ATimeCost, AParallelism, AHashLen: Integer): string; inline;
function KDF_Argon2Verify(const APassword: TBytes; const AEncodedHash: string): Boolean; inline;
function KDF_HMAC_SHA256(const AKey, AData: TBytes): TBytes; inline;

implementation

uses
  nextpas.core.bytes.ops;

function KDF_HKDF_Extract_SHA256(const ASalt, AIKM: TBytes): TBytes; inline;
begin
  { perf: inline thin forward 单源 HKDF, 零拷贝视图经 bytes.ops, SecureZero 由实现侧负责 }
  Result := nextpas.core.crypto.hkdf.HKDF_Extract_SHA256(ASalt, AIKM);
end;

function KDF_HKDF_Expand_SHA256(const APRK, AInfo: TBytes; ALength: Integer): TBytes; inline;
begin
  Result := nextpas.core.crypto.hkdf.HKDF_Expand_SHA256(APRK, AInfo, ALength);
end;

function KDF_PBKDF2_SHA256(const APassword, ASalt: TBytes; AIterations, AKeyLen: Integer): TBytes; inline;
begin
  Result := nextpas.core.crypto.pbkdf2.PBKDF2_SHA256(APassword, ASalt, AIterations, AKeyLen);
end;

function KDF_Argon2Hash(const APassword, ASalt: TBytes; ATimeCost, AMemoryCost, AParallelism, AOutputLen: Integer): TBytes; inline;
begin
  Result := nextpas.core.crypto.argon2.Argon2Hash(APassword, ASalt, ATimeCost, AMemoryCost, AParallelism, AOutputLen);
end;

function KDF_Argon2HashStr(const APassword: TBytes; AMemoryKiB, ATimeCost, AParallelism, AHashLen: Integer): string; inline;
begin
  Result := nextpas.core.crypto.argon2.Argon2HashStr(APassword, AMemoryKiB, ATimeCost, AParallelism, AHashLen);
end;

function KDF_Argon2Verify(const APassword: TBytes; const AEncodedHash: string): Boolean; inline;
begin
  { perf: inline 薄转发, 常量时间比对在 argon2 实现侧 (TConstantTime.CompareBytes), fail-closed }
  Result := nextpas.core.crypto.argon2.Argon2Verify(APassword, AEncodedHash);
end;

function KDF_HMAC_SHA256(const AKey, AData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.crypto.hmac.HMAC_SHA256(AKey, AData);
end;

end.
