# nextpas.core.crypto.rsa — RSA/大整数域契约

**模块**：`nextpas.core.crypto.rsa.{base,intf,pas}` 聚合 `rsa` + `rsa.ct` + `bigint` + `ct.bigint`  
**层级**：L2 crypto（依赖 L0–L1 + hash，不触 tls）  
**四件套**：`rsa.base` ← `rsa.intf` ← `rsa` 门面 (PKCS1v15 保留) ← `bigint/ct.bigint + rsa.ct` 实现  
**对应主契约**：`CONTRACT.md` §1.1b RSA 行 + §1.1 rsa/rsa.ct/bigint/ct.bigint

## 职责

- RSA PKCS#1 v1.5 `TryRSAES_PKCS1v15_Encode/Encrypt` (Encode 填充 `$00$02` + 非零随机 + `$00` + m) 薄转发保留
- CRT 加速 `rsa.ct` 常量时间路径 `TryBigIntModExp` 聚合
- 大整数 `bigint` Montgomery 模幂 `ModExp` + `TryBigIntModExpFromUnsignedBytes` 薄转发
- 常量时间 `ct.bigint` `CTEqual/CTLessThan/CTSwap` 薄转发

## 性能

- `ct.bigint` 常量时间路径 `inline` 薄转发 (`RSA_CT_Equal` inline), 零拷贝 Montgomery 视图经 `bytes.ops` (`TByteSpan` 不复制模数/指数)
- 单源 `bigint.ModExp`：指数扫描 `QWord` 批处理, 不重复实现
- 密钥材料视图零拷贝, 单次 `Move` 定长

## 稳定性

- 私钥 `SecureZero` (CRT 中间 `dp/dq/p/q/iqmp` FillChar 清零 try/finally), heaptrc 0 unfreed
- 模数过短/消息过长 fail-closed 返回 False + `AError`, 不抛异常 (Try* 语义)
- 随机填充 `SecureRandomBytes` 单源, 0 长度合法负值 `EArgumentError`

## Owner 边界

- 缺能力先反哺 `bytes.ops` (Montgomery 视图单源) / `hash` (MGF 不重实现) / `platform.random`, 不绕边界
