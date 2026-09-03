# nextpas.core.crypto.kdf — KDF/口令哈希域契约

**模块**：`nextpas.core.crypto.kdf.{base,intf,pas}` 聚合 `argon2` + `hkdf` + `pbkdf2` + `bcrypt_pbkdf` + `hmac`  
**层级**：L2 crypto（依赖 L0–L1 + hash，不触 tls）  
**四件套**：`kdf.base` ← `kdf.intf` ← `kdf` 门面 ← `argon2/hkdf/pbkdf2/bcrypt_pbkdf` 实现  
**对应主契约**：`CONTRACT.md` §1.1b KDF 行 + §1.3 argon2 + §2 INV-2/3

## 职责

- HKDF Extract/Expand (RFC5869) `HKDF_Extract_SHA256/Expand_SHA256` 薄转发
- PBKDF2-HMAC-SHA256/SHA1 (RFC6070) `PBKDF2_SHA256` 薄转发
- bcrypt_pbkdf (OpenBSD) `bcrypt_pbkdf` 聚合
- Argon2 `Argon2Hash`/`Argon2HashStr`/`Argon2Verify` (v=19, m KiB≥8建议≥65536, t≥1 p≥1 hashLen≥4) fail-closed, PHC `$argon2id$v=19$...` 解析+常量时间比对

## 性能

- 复用 `bytes.ops` 单源（盐/密钥 `TByteSpan` 视图零拷贝, 不复制密钥材料, 单次 `Move`）
- 热点 `inline` 薄转发：HKDF expand 循环体外联, 但门面 `KDF_HKDF_Expand_SHA256`/`KDF_Argon2Verify` inline 零拷贝视图
- Argon2 校验 `TConstantTime.CompareBytes` 单源, 不泄露时序

## 稳定性

- 盐只走 `crypto.random` / `platform.random` (INV-3), `GenerateSecureRandomBytes(0)` 零分配合法, 负值 `EArgumentError`
- 密钥/盐拷贝后 `SecureZeroMemory` / `FillChar` 清零 (`try/finally`), heaptrc 0 unfreed
- `Argon2Verify` 空串/未知类型/非v19/参数越界/段数不符一律 False 不抛异常 (fail-closed)

## Owner 边界

- 缺能力先反哺 `hash` (摘要不重实现 INV-4) / `bytes.ops` (盐拷贝单源) / `platform.random` (CSPRNG), 不绕过边界
