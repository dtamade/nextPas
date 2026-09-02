# nextpas.core.crypto 代码契约

**模块路径**：`core/src/nextpas.core.crypto*.pas`
**层级**：L2（依赖 L0–L1 与 hash；**禁止**依赖 tls）
**Owner**：hash / crypto / tls lane
**最后更新**：2026-09-02
**版本**：1.3（新增 §1.1b 六域四件套候选表，对齐 http CONTRACT.md:51-60）

---

## 概要

密码学原语与口令哈希:以 `nextpas.core.crypto` 门面提供哈希 / 密钥派生等原语,含 argon2;依赖 L0–L1 与 hash,不依赖 tls(分层硬约束见后文)。

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
crypto.random              CSPRNG（via platform.random；0 长度合法，负值抛 EArgumentError，见 INV-5）
crypto.constant_time       常量时间原语
crypto.pkcs8 / argon2 / …  密钥与口令派生
```

### 1.1b 业务域拆分与可抽新模块候选表（对齐 http 六域四件套）

> 单一 CONTRACT 已按本节六域兑现/候选四件套拆分指引；执行时仍守：四件套（base/intf/impl/门面）、L0–L3（L2 crypto 只依赖 L0–L1+hash，禁止依赖 tls）、`bytes.ops` 单源复用、热点 `inline` + 零拷贝视图、资源释放（SecureZero/Destroy/heaptrc 0 unfreed）不丢；缺能力先反哺 owner（不绕过边界）。明细以薄域契约为准，主文档聚焦索引-锚点，消双重维护。

| 业务域 | 当前 CONTRACT 锚点 | 抽取后模块（四件套候选/已落地） | Owner / 依赖 | 兑现证据（落地文件 + 约束保持） |
|--------|-------------------|-------------------------------|--------------|--------------------------------|
| **KDF / 口令哈希** | §1.3 argon2 + hmac/hkdf/pbkdf2/bcrypt_pbkdf | `nextpas.core.crypto.kdf`（候选 `kdf.base`/`kdf.intf`/`kdf` 门面 四件套 `base←intf←impl←门面`；聚合 `argon2` + `hkdf` + `pbkdf2` + `bcrypt_pbkdf`） | L2 crypto（依赖 L0–L1 + hash，不触 tls） | 复用 `bytes.ops` 单源（盐/密钥拷贝 `SecureZero` 视图）；热点 `inline`（HKDF expand/Argon2 校验）；`SecureZeroMemory` 释放不丢；详见 `crypto.kdf.md` 候选 |
| **AEAD 对称加密** | §2 INV-1 + aesgcm/aescbc/chacha/tls12record | `nextpas.core.crypto.aead`（候选 `aead.base`/`aead.intf`/`aead` 门面 四件套 `base←intf←impl←门面`；聚合 `aesgcm` + `aescbc` + `chacha20poly1305` + `tls12record`） | L2 crypto | 零拷贝 `TByteSpan` 视图（tag/nonce 16/12 校验不复制）；`inline` GHASH/AES-NI 分支；密钥 `SecureZero`；详 `crypto.aead.md` 候选 |
| **椭圆曲线** | §1.1 x25519/ed25519/ecdsa/p256/p384 | `nextpas.core.crypto.ec`（候选 `ec.base`/`ec.intf`/`ec` 门面 四件套 `base←intf←impl←门面`；聚合 `p256.field/point` + `p384` + `ecdsa` + `x25519` + `ed25519`） | L2 crypto | 复用 `bytes.ops` 单源（标量钳制/点压缩）；热点 `inline` 有限域运算；`SecureZero` 私钥；详 `crypto.ec.md` 候选 |
| **RSA / 大整数** | §1.1 rsa/rsa.ct/bigint/ct.bigint | `nextpas.core.crypto.rsa`（候选 `rsa.base`/`rsa.intf`/`rsa` 门面 四件套 `base←intf←impl←门面`；聚合 `rsa` + `rsa.ct` + `bigint` + `ct.bigint`） | L2 crypto | `ct.bigint` 常量时间路径 `inline`；零拷贝 Montgomery 视图；私钥 `SecureZero`；详 `crypto.rsa.md` 候选 |
| **编码 / ASN.1 / PKCS8** | §1.1 asn1/pkcs8 + x509verify | `nextpas.core.crypto.encoding`（候选 `encoding.base`/`encoding.intf`/`encoding` 门面 四件套 `base←intf←impl←门面`；聚合 `asn1` + `pkcs8` + `x509verify` 薄视图） | L2 crypto（tls.asn1 为 shim 转发） | 复用 `bytes.ops` 单源（DER `TBytes` 视图不复制）；`inline` OID/长度解析；`SecureZero` 解密后清零；详 `crypto.encoding.md` 候选 |
| **随机 / 常量时间** | §1.1 random/constant_time + INV-2/3/5 | `nextpas.core.crypto.secure`（候选 `secure.base`/`secure.intf`/`secure` 门面 四件套 `base←intf←impl←门面`；聚合 `random` + `constant_time` + `ct.bigint` 薄工具） | L2 crypto 依赖 `platform.random`（owner 反哺） | `platform.random` 单源 CSPRNG；`inline` 常量时间 compare/select；`GenerateSecureRandomBytes(0)` 零分配；详 `crypto.secure.md` 候选 |

*抽取纪律*：1) 行为冻结（focused 双绿 + heaptrc 0 unfreed）；2) 不复制 `bytes.ops`，复用单源（盐/标签/点压缩/ DER 视图）；3) 公开面保持 `ECryptoError`/`EArgumentError` 稳定；4) 四件套内 `base←intf←impl←门面` 方向；5) 跨模块先 `Needs Review`。缺能力先反哺 `hash`/`bytes.ops`/`platform.random` 等 owner。

### 1.2 分层硬约束

- **禁止**任何 `nextpas.core.crypto*.pas` 引用 `nextpas.core.tls*`
- 门面 re-export ChaCha 必须来自 `crypto.chacha20poly1305`，不得来自 tls
- `crypto.hash` 必须委派 `nextpas.core.hash.*`，不得自带 Transform 表

门禁：`core/tests/nextpas.core.crypto/test_crypto_layer_contract`

---

### 1.3 argon2（口令哈希）

- **接口**：`Argon2Hash`（原始字节，内嵌 v=19/1.3）、`Argon2HashStr`
  （PHC 编码串：`$argon2id$v=19$m=…,t=…,p=…$b64salt$b64hash`，盐 16B 内部随机）、
  `Argon2Verify`（按 PHC 解析 + 常量时间重算比对）。
- **PHC 参数纪律**：m 单位 KiB（≥8，应用层建议 ≥65536）、t ≥ 1、p ≥ 1、hashLen ≥ 4；
  类型 `atArgon2d`（d）/ `atArgon2i`（i）/ `atArgon2id`（id）。
- **fail-closed**：`Argon2Verify` 对空串/未知类型/非 v=19/参数越界/段数不符/长度不符
  一律返回 False，不抛异常；比对走 `crypto.constant_time`（防时序侧信道）。
- **INV 关联**：盐只走 `crypto.random`（INV-3）；不重新实现摘要（INV-4，H0 走 crypto.hash）。

---

## 2. 不变量

- **[INV-1]** AEAD tag / nonce 长度符合 RFC（AES-GCM tag 16；ChaCha nonce 12）
- **[INV-2]** 密钥材料路径使用 constant-time / secure zero 约定
- **[INV-3]** 随机数只走 `crypto.random` / platform CSPRNG
- **[INV-4]** 与 hash 的边界：摘要算法不在 crypto 内重新实现
- **[INV-5]** `crypto.random` 长度语义：0 长度合法（`GenerateSecureRandomBytes(0)`
  返回空数组 / `SecureRandomBytes` 无操作成功）；负值为编程错误抛
  `EArgumentError`；仅底层 CSPRNG 故障抛 `ECryptoRandomError`（与参数无关，
  调用方据此区分环境故障与参数错误）

---

## 3. 测试（最小）

```bash
make focused FOCUS=core/tests/nextpas.core.crypto/test_crypto_layer_contract
make focused FOCUS=core/tests/nextpas.core.crypto/test_chacha20poly1305
make focused FOCUS=core/tests/nextpas.core.crypto/test_facade
make focused FOCUS=core/tests/nextpas.core.crypto/test_aesgcm
make focused FOCUS=core/tests/nextpas.core.crypto/test_x25519
make focused FOCUS=core/tests/nextpas.core.crypto/test_ed25519
make focused FOCUS=core/tests/nextpas.core.crypto/test_argon2
make focused FOCUS=core/tests/nextpas.core.crypto/test_crypto_random
```

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-17 | 1.3 | crypto.random 长度语义收口：0 长度合法（空数组/无操作成功）、负值抛 EArgumentError（此前一律 ECryptoRandomError）；补 test_crypto_random 边界契约测试 |
| 2026-08-11 | 1.2 | argon2 补 PHC `Argon2HashStr` + `Argon2Verify`（去 EXPERIMENTAL）；rand/encoding/constant-time 归一 |
| 2026-07-20 | 1.1 | ChaCha/ASN.1/random 归属 crypto；禁止 crypto→tls |
| 2026-07-01 | 1.0 | 初始版本 |
| 2026-08-31 | 1.2 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
| 2026-09-02 | 1.3 | 拆分优雅度：补 §1.1b 六域可抽新模块候选表（kdf/aead/ec/rsa/encoding/secure），四件套 base/intf/门面+L2+bytes.ops单源+inline/零拷贝+SecureZero释放不丢，缺能力先反哺 hash/bytes.ops/platform.random，对齐 http 六域抽取表 base/intf/门面+L3+bytes.ops+inline |
