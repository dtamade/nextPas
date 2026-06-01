unit nextpas.core.crypto;

{$mode objfpc}{$H+}

{ nextpas.core.crypto — 密码学模块门面

  uses nextpas.core.crypto 即可访问所有密码学 API：
  - Hash: SHA256/384/512, MD5, HMAC, HKDF
  - AEAD: AES-GCM, ChaCha20-Poly1305
  - Block: AES-CBC
  - ECC: X25519, Ed25519, ECDSA P-256, P-384
  - RSA: PKCS#1 v1.5 Encrypt, CT ModExp
  - KDF: Argon2, PBKDF2
  - Util: constant-time compare, PKCS#8 parse
}

interface

uses
  nextpas.core.crypto.hash,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.hkdf,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.p384,
  nextpas.core.crypto.rsa,
  nextpas.core.crypto.rsa.ct,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.aescbc,
  nextpas.core.crypto.aes.ct64,
  nextpas.core.crypto.pkcs8,
  nextpas.core.crypto.argon2,
  nextpas.core.tls.tls13.chacha20poly1305;

type
  TECPoint = nextpas.core.crypto.ecdsa.TECPoint;

implementation

end.
