# nextpas.core.crypto.ec — 椭圆曲线域契约

**模块**：`nextpas.core.crypto.ec.{base,intf,pas}` 聚合 `p256.field/point` + `p384` + `ecdsa` + `x25519` + `ed25519` + `field25519` + `p256ecdh`  
**层级**：L2 crypto（依赖 L0–L1 + hash，不触 tls）  
**四件套**：`ec.base` ← `ec.intf` ← `ec` 门面 ← `p256.field/point + p384 + ecdsa + x25519/ed25519` 实现  
**对应主契约**：`CONTRACT.md` §1.1b EC 行 + §1.1 x25519/ed25519/ecdsa/p256/p384

## 职责

- X25519 ECDH `GenerateX25519KeyPair`/`X25519ComputeSharedSecret` (RFC7748, 标量钳制)
- Ed25519 `Ed25519Sign/Verify` (RFC8032, 32B key 64B sig)
- ECDSA P-256 `TryECDSASignP256SHA256/Verify` (RFC6979 确定性 k)
- P-256 域 `p256.field/point`, P-384 `p384` ECDHE/ECDSA verify, `p256ecdh` 薄转发

## 性能

- 复用 `bytes.ops` 单源：标量钳制/点压缩 `TByteSpan` 零拷贝视图, 不复制私钥
- 热点 `inline` 有限域运算薄转发 (`EC_GenerateX25519KeyPair` inline), 域乘 `field25519` 批处理单源
- 点压缩/解压单次 `Move`, 零拷贝视图校验长度

## 稳定性

- 私钥 `SecureZero` (FillChar 清零 try/finally), heaptrc 0 unfreed
- 非法点/标量长度 fail-closed 返回 False, 不抛异常, 资源释放不丢
- 常量时间标量乘 (Montgomery ladder), 验证路径 variable-time 仅处理公开数据

## Owner 边界

- 缺能力先反哺 `bytes.ops` (点压缩视图单源) / `hash` (SHA512 for Ed25519) / `platform.random` (密钥生成), 不绕边界
