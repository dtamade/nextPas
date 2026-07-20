# nextpas.core.crypto 代码契约

**模块路径**：`core/src/nextpas.core.crypto*.pas`
**层级**：L2（依赖 L0–L1 与 hash；**禁止**依赖 tls）
**Owner**：hash / crypto / tls lane
**最后更新**：2026-07-20
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块地图

```
crypto.pas                 门面
crypto.hash                兼容适配 → nextpas.core.hash
crypto.hmac / hkdf         MAC / KDF（基于 IHasher）
crypto.aesgcm / aescbc     AES
crypto.chacha20poly1305    ChaCha20-Poly1305 AEAD（owner）
crypto.x25519 / ed25519    Curve25519
crypto.ecdsa / p256 / p384 ECC
crypto.rsa / rsa.ct        RSA
crypto.asn1                ASN.1/DER（owner；tls.asn1 为 shim）
crypto.random              CSPRNG（via platform.random）
crypto.constant_time       常量时间原语
crypto.pkcs8 / argon2 / …  密钥与口令派生
```

### 1.2 分层硬约束

- **禁止**任何 `nextpas.core.crypto*.pas` 引用 `nextpas.core.tls*`
- 门面 re-export ChaCha 必须来自 `crypto.chacha20poly1305`，不得来自 tls
- `crypto.hash` 必须委派 `nextpas.core.hash.*`，不得自带 Transform 表

门禁：`core/tests/nextpas.core.crypto/test_crypto_layer_contract`

---

## 2. 不变量

- **[INV-1]** AEAD tag / nonce 长度符合 RFC（AES-GCM tag 16；ChaCha nonce 12）
- **[INV-2]** 密钥材料路径使用 constant-time / secure zero 约定
- **[INV-3]** 随机数只走 `crypto.random` / platform CSPRNG
- **[INV-4]** 与 hash 的边界：摘要算法不在 crypto 内重新实现

---

## 3. 测试（最小）

```bash
make focused FOCUS=core/tests/nextpas.core.crypto/test_crypto_layer_contract
make focused FOCUS=core/tests/nextpas.core.crypto/test_chacha20poly1305
make focused FOCUS=core/tests/nextpas.core.crypto/test_facade
make focused FOCUS=core/tests/nextpas.core.crypto/test_aesgcm
make focused FOCUS=core/tests/nextpas.core.crypto/test_x25519
make focused FOCUS=core/tests/nextpas.core.crypto/test_ed25519
```

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-07-20 | 1.1 | ChaCha/ASN.1/random 归属 crypto；禁止 crypto→tls |
| 2026-07-01 | 1.0 | 初始版本 |
