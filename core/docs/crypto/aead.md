# nextpas.core.crypto.aead — AEAD 对称加密域契约

**模块**：`nextpas.core.crypto.aead.{base,intf,pas}` 聚合 `aesgcm` + `aescbc` + `chacha20poly1305` + `tls12record` (+ `tls12prf` 薄转发)  
**层级**：L2 crypto（依赖 L0–L1 + hash，不触 tls）  
**四件套**：`aead.base` ← `aead.intf` ← `aead` 门面 ← `aesgcm/aescbc/chacha/tls12record` 实现  
**对应主契约**：`CONTRACT.md` §1.1b AEAD 行 + §2 INV-1

## 职责

- AES-GCM `PurePascalAESGCMEncrypt/Decrypt` (tag 16, nonce 12, key 16/32) thin forward, GHASH 分支
- AES-CBC `aescbc` 无填充块加密 thin forward
- ChaCha20-Poly1305 `TryChaCha20Poly1305Encrypt/Decrypt` (RFC8439, key 32 nonce 12 tag 16) thin forward
- TLS1.2 record `tls12record` 聚合, 变体 `AESNIGCM*PtrAAD` 零堆

## 性能

- 零拷贝 `TByteSpan` 视图：tag/nonce 16/12 长度校验不复制, GHASH 聚合表 `BuildGHASHPowerTable` 单源
- `inline` GHASH/AES-NI 分支薄转发 (`AEAD_Seal_AESGCM` inline), PCLMUL 4块聚合 `GHASHUpdatePCLMULAgg` 单源 (bytes.ops 视图)
- 复用 `bytes.ops` 单源：密文/AAAD 搬运单次 `Move`, 不重复实现

## 稳定性

- 密钥 `SecureZero` (FillChar 清零 try/finally), tag 比对 `constant_time` 常量时间 (INV-2)
- 长度越界 fail-closed 返回 False 不抛异常, heaptrc 0 unfreed
- 非法 key/nonce/tag 长度诚实失败, 不静默截断

## Owner 边界

- 缺能力先反哺 `bytes.ops` (密文搬运零拷贝) / `hash` (GHASH 不重实现摘要) / `platform` (AES-NI 探测), 不绕边界
