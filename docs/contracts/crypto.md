# nextpas.core.crypto 代码契约

> 模块路径: `core/src/nextpas.core.crypto.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

密码学模块门面。提供哈希、AEAD、ECC、RSA、KDF 和常量时间比较。

---

## 算法族

| 族 | 算法 | 用途 |
|----|------|------|
| Hash | SHA-256/384/512, MD5 | 摘要 |
| MAC | HMAC-SHA-256/384/512 | 消息认证 |
| KDF | HKDF, Argon2, PBKDF2 | 密钥派生 |
| AEAD | AES-GCM, ChaCha20-Poly1305 | 认证加密 |
| Block | AES-CBC | 块加密 |
| ECC | X25519, Ed25519, ECDSA P-256/P-384 | 密钥交换/签名 |
| RSA | PKCS#1 v1.5, CT ModExp | 加密/签名 |
| Util | constant-time compare, PKCS#8 | 安全工具 |

---

## 前置条件

1. 密钥长度必须匹配算法要求
2. IV/Nonce 不得重复使用（AEAD）
3. 输入数据不得为空（除非明确允许）

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 认证标签验证失败 | raise EInvalidArgument |
| 密钥长度不匹配 | raise EInvalidArgument |
| PKCS#8 解析失败 | raise EParseError |

---

## 线程安全

- 所有加密函数为纯函数，可安全并发调用
- 无共享状态

---

## 依赖关系

- 依赖: base, bytes, encoding, platform.random
- 被依赖: tls, http (HTTPS), websocket (WSS)

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
