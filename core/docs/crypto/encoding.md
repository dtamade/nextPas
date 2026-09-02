# nextpas.core.crypto.encoding — 编码/ASN.1/PKCS8 域契约

**模块**：`nextpas.core.crypto.encoding.{base,intf,pas}` 聚合 `asn1` + `pkcs8` + `x509verify` 薄视图 (tls.asn1 为 shim)  
**层级**：L2 crypto（依赖 L0–L1 + hash，`tls.asn1` 为 shim 转发，不反向依赖 tls）  
**四件套**：`encoding.base` ← `encoding.intf` ← `encoding` 门面 ← `asn1/pkcs8` 实现  
**对应主契约**：`CONTRACT.md` §1.1b 编码行 + §1.1 asn1/pkcs8 + x509verify

## 职责

- ASN.1/DER `TASN1Reader/Writer` (TLV Tag-Length-Value, OID/整数/位串/序列) 薄转发, `TagToString/OIDToName` 单源
- PKCS#8 `pkcs8` 加密密钥解析 thin forward, 解密后清零
- X.509 `x509verify` 薄视图：`tls.x509verify` 为产品验证, 本域仅提供 DER 视图转发 (tls.asn1 shim 指向本域 `asn1`)

## 性能

- 复用 `bytes.ops` 单源：DER `TBytes`/`TByteSpan` 视图不复制 (`Move` 单次), 长度/OID 解析 `inline` 薄转发 (`Encoding_IsValidOID` inline)
- 单源 `StripLeadingZero` 视图零拷贝, OID 解码批处理, 不额外分配
- 门面 `Encoding_TryParseASN1` inline 零拷贝视图, 失败路径不分配

## 稳定性

- 解密后 `SecureZero` (FillChar 清零 try/finally), DER 缓冲随 `TASN1Node.Destroy` 释放, heaptrc 0 unfreed
- 非法 DER / 未知 OID 格式 fail-closed 返回 False + `AError`, 不抛异常
- 资源：`TASN1Reader` 拥有 `FData` 拷贝, `Destroy` 清零释放

## Owner 边界

- 缺能力先反哺 `bytes.ops` (DER 视图零拷贝) / `text.conv` (OID 编码) / `io` (Stream), `tls.asn1` 仅 shim 转发本域, 不反向依赖 tls
