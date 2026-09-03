# nextpas.core.crypto.secure — 随机/常量时间域契约

**模块**：`nextpas.core.crypto.secure.{base,intf,pas}` 聚合 `random` + `constant_time` + `ct.bigint` 薄工具  
**层级**：L2 crypto 依赖 `platform.random` (owner 反哺), 不触 tls  
**四件套**：`secure.base` ← `secure.intf` ← `secure` 门面 ← `random/constant_time/ct.bigint` 实现  
**对应主契约**：`CONTRACT.md` §1.1b 安全行 + §1.1 random/constant_time + INV-2/3/5

## 职责

- CSPRNG `GenerateSecureRandomBytes`/`SecureRandomBytes` (via `platform.random`, 0 长度合法空数组/无操作成功, 负值 `EArgumentError`, 底层故障 `ECryptoRandomError`)
- 常量时间 `TConstantTime.CompareBytes/CompareBuffer/CompareStrings/Select/IsZero` thin forward (防时序侧信道)
- `ct.bigint` 薄工具 `CTEqual/CTLessThan` 聚合

## 性能

- `platform.random` 单源 CSPRNG 薄转发, 0 长度零分配 (`GenerateSecureRandomBytes(0)` 直接 Exit)
- `inline` 常量时间 `Secure_CompareBytes`/`Secure_CTEqual`/`Secure_IsZero` (TByteSpan 视图零拷贝, 单源 `TConstantTime`)
- 单源 `bytes.ops` 视图：`CompareBytes` 长度不等快速路径, 不复制密钥

## 稳定性

- `SecureZeroMemory` / `FillChar` 清零释放不丢 (`TConstantTime.CompareStrings` try/finally 清零临时 `ABytes/BBytes`), heaptrc 0 unfreed
- 0 长度合法路径与负值编程错误区分 (`EArgumentError` vs `ECryptoRandomError`, INV-5)
- 资源：随机缓冲 `GenerateSecureRandomBytes` 失败时清零并缩为 0, 不泄漏

## Owner 边界

- 缺能力先反哺 `platform.random` (单源 CSPRNG) / `bytes.ops` (比较视图单源), 不绕过边界自实现 CSPRNG
