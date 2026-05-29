unit nextpas.core.crypto;

{$mode objfpc}{$H+}

{ nextpas.core.crypto — 密码学模块门面

  L2 层模块，提供完整的密码学原语：
  - 哈希：SHA-256/384/512, MD5
  - 对称加密：AES-GCM, AES-CBC (含 AES-NI 硬件加速)
  - 流密码：ChaCha20-Poly1305
  - 椭圆曲线：X25519, P-256, P-384, Ed25519
  - 非对称：RSA PKCS#1 v1.5 / PSS
  - 密钥派生：HMAC, HKDF, TLS 1.2 PRF
  - 工具：常量时间比较, 大整数, PKCS#8 解析, Argon2

  安全状态：8 轮独立审查通过，常量时间 Montgomery ladder，
  on-curve 点验证，密钥材料安全擦除。
}

interface

uses
  nextpas.core.crypto.hash,
  nextpas.core.crypto.hmac, nextpas.core.crypto.hkdf,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.p384,
  nextpas.core.crypto.rsa,
  nextpas.core.crypto.bigint,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.aescbc,
  nextpas.core.crypto.pkcs8,
  nextpas.core.crypto.argon2;

{ Re-export core types for convenience }
type
  TSHA256Digest = nextpas.core.crypto.hash.TSHA256Digest;

implementation

end.
