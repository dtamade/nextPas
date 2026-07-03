# nextpas.core.crypto 代码契约

**模块路径**：`core/src/nextpas.core.crypto*.pas`（33 个源文件）
**层级**：L2（依赖 L0-L1）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

```
crypto.base          ← 基础类型 (TDigest, TKey)
crypto.hash.*        ← 哈希算法 (SHA-256, SHA-512, SHA-1, MD5, BLAKE2, BLAKE3)
crypto.hmac          ← HMAC 消息认证
crypto.aes.*         ← AES 加密 (ECB/CBC/CTR/GCM)
crypto.chacha20      ← ChaCha20-Poly1305 AEAD
crypto.random        ← 密码学安全随机数 (getrandom/CryptGenRandom)
crypto.pbkdf2        ← 密码派生
crypto.constant_time ← 常量时间比较 (防时序攻击)
crypto.pas           ← 门面
```

### 1.2 核心函数

| 领域 | 函数 | 说明 |
|------|------|------|
| 哈希 | SHA256, SHA512, SHA1, MD5, BLAKE2b, BLAKE3 | 单次哈希 |
| HMAC | HMAC_SHA256, HMAC_SHA512 | 密钥哈希 |
| AES | AES_EncryptCBC, AES_DecryptCBC, AES_GCM | AES 加密/解密 |
| AEAD | ChaCha20Poly1305_Encrypt, ChaCha20Poly1305_Decrypt | AEAD |
| 随机 | CryptoRandomBytes(ABuf, ALen) | 密码学随机 |
| 派生 | PBKDF2_HMAC_SHA256 | 密码派生 |
| 安全 | ConstantTimeEqual(A, B, Len) | 常量时间比较 |

---

## 2. 不变量

- **[INV-1]** 所有哈希函数返回固定长度摘要
- **[INV-2]** ConstantTimeEqual 不提前返回（防时序攻击）
- **[INV-3]** AES-GCM tag 长度 = 16 字节
- **[INV-4]** CryptoRandomBytes 使用系统 CSPRNG

---

## 3-6. 概要

- **错误**: 无效密钥长度/nonce 抛 EInvalidArgument
- **线程安全**: 所有函数 ✅（纯函数或使用线程局部状态）
- **内存**: 敏感密钥材料使用后显式清零 (SecureZero)
- **测试**: 24 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
