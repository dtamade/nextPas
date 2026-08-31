# nextpas.core.encoding 代码契约

**模块路径**：`core/src/nextpas.core.encoding*.pas`（6 个源文件）
**层级**：L1（依赖 L0: base）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| encoding.base | TBase64Variant, THexCase 枚举 |
| encoding.base64 | Base64/Base64URL 编码/解码 |
| encoding.hex | 十六进制编码/解码 |
| encoding.varint | 变长整数编码（protobuf 风格） |
| encoding.url | URL 百分号编码/解码 |
| encoding.pas | 门面 |

### 1.2 核心函数

| 函数 | 说明 |
|------|------|
| `Base64Encode(AData): string` | 标准 Base64 编码 |
| `Base64Decode(AEncoded): TBytes` | 标准 Base64 解码 |
| `Base64UrlEncode(AData): string` | URL-safe Base64 编码 |
| `Base64UrlDecode(AEncoded): TBytes` | URL-safe Base64 解码 |
| `HexEncode(AData, ACase): string` | 十六进制编码 |
| `HexDecode(AHex): TBytes` | 十六进制解码 |
| `VarintEncode(AValue): TBytes` | 无符号变长整数编码 |
| `VarintDecode(AData, ABytesRead): UInt64` | 无符号变长整数解码 |
| `SignedVarintEncode(AValue): TBytes` | 有符号 ZigZag 编码 |
| `SignedVarintDecode(AData, ABytesRead): Int64` | 有符号 ZigZag 解码 |
| `UrlEncode(AValue): string` | URL 百分号编码 |
| `UrlDecode(AEncoded): string` | URL 百分号解码 |

---

## 2. 不变量

- **[INV-1]** Base64 编码输出长度 = `⌈4 × (input_len / 3)⌉`
- **[INV-2]** HexEncode 输出长度 = `2 × input_len`
- **[INV-3]** Varint 最大 10 字节（UInt64），SignedVarint 最大 10 字节
- **[INV-4]** UrlEncode 保留 RFC 3986 unreserved 字符不编码
- **[INV-5]** Base64 解码忽略空白字符

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 非法 Base64 字符 | EConvertError |
| 非法十六进制字符 | EConvertError |
| Varint 数据不足 | ABytesRead 返回 0 或实际读取数 |

---

## 4-6. 概要

- **线程安全**: 所有函数 ✅（纯函数，无状态）
- **内存**: 返回新的 TBytes/string，调用方负责释放
- **测试**: 3 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |
| 2026-08-31 | 1.1 | 时效修复：更新最后更新至 2026-08-31 v1.1 并对齐实现 | Claude |
