# mime/mail 模块边界设计（2026-08-16）

> 反哺批次 1（mailServer888 → nextPas）的模块归属决策。
> 已在 `codex/mime-mail-20260816` lane 落地并验证。

## 1. 背景与问题

`nextpas.core.mail.mime`（原 1371 行）承载了邮件 MIME 编解码的全部能力
（base64/QP、头/参数解析、multipart 树、日期容错）。需要回答：

1. MIME 是否应为独立 L2 模块（复用面：HTTP multipart 上传、DKIM
   canonicalization、IMAP BODYSTRUCTURE 都不应依赖「邮件」）；
2. mail（L3）与 mime（L2）的职责边界在哪；
3. 与既有 `nextpas.core.multipart`（L2，HTTP form-data）如何分工。

## 2. 决策

### 2.1 mime 独立为 L2 模块（采纳）

- 依赖方向干净：`mail → mime → L0-L1`；mime 无任何邮件语义。
- 复用面：非邮件消费者可只依赖 mime（http multipart、deliverability 批次）。
- 业界先例：Go `mime`/`mime/multipart`/`net/mail` 分层；Rust `mime` crate。

### 2.2 边界（语法 vs 语义）

| 层 | 拥有者 | 内容 |
|----|--------|------|
| MIME 语法 | `nextpas.core.mime` | 媒体类型/参数（RFC 2231）、头折叠与注入清洗、RFC 2047、传输编码、multipart 树、大小/深度上限 |
| 邮件语义 | `nextpas.core.mail` | TMailMessage/TMailAddress/TMailAttachment、地址头与日期解析、消息模型 ↔ MIME 树桥接、SMTP 客户端 |

不变量（INV-A3）：MIME 语法唯一所有者是 mime；mail 不重复实现语法。

### 2.3 mime 与 multipart 分工

| 模块 | 定位 |
|------|------|
| `nextpas.core.multipart` | 字节级通用分段器（FindBytes），HTTP form-data（registry: "HTTP grammar only"） |
| `nextpas.core.mime` | 邮件 MIME 语法超集：嵌套部件内嵌头、boundary 行首语义与校验、截断容错 |

两者语法同源（RFC 2046 §5.1 行界），未来批次评估收敛（不让 form-data 与
邮件 multipart 出现行为分裂）；收敛前 registry 记录分工。

### 2.4 异常体系（在既有 E* 纪律内）

- 根：`EMimeError`/`EMailError` 均继承 `EParseError`（`ENextPasError` 体系，
  带 Category/Inner 诊断）；既有调用方以 `EParseError` 捕获零迁移。
- mime 子类：`EMimeParseError`/`EMimeEncodeError`/`EMimeLimitError`
  （后者 Category=ecResourceExhausted，INV-M3）。
- mail 子类：`EMailAddressError`/`EMailHeaderError`/`EMailParseError`。

## 3. 文件布局（lane 落地结果）

```
core/src/nextpas.core.mime.pas           门面（re-export + inline 转发）
core/src/nextpas.core.mime.base.pas      常量 + TMimeParameter/TMimeHeader/
                                         TMimeContentType/TMimeContentDisposition + E* 家族
core/src/nextpas.core.mime.header.pas    RFC 2047 encoded-word / RFC 2231 参数 /
                                         unfold / 防注入清洗
core/src/nextpas.core.mime.parser.pas    头/参数/Content-*/传输解码 / multipart 树
                                         严格（抛）+ 容错（issue 列表）双通道
core/src/nextpas.core.mime.builder.pas   base64/QP 编码 / boundary 生成（原子序列）/
                                         BuildMessage / BuildMessageToStream
core/src/nextpas.core.mail.base.pas      TMailAddress/TMailAttachment/TMailMessage + EMail* 家族
core/src/nextpas.core.mail.mime.pas      桥接：TMailMessage ↔ 树 + 日期/地址头语义
                                         （语法全部委托 mime，公开 API 兼容旧名）
core/src/nextpas.core.mail.smtp.pas      SMTP 客户端（保持）
core/src/nextpas.core.mail.pas           门面（保持）
```

## 4. 测试与证据策略

- mail 既有 45 用例（address 8 / mime 24 / smtp 13）行为全绿（重构后验证）。
- mime 新增：`tests/nextpas.core.mime/test_mime_header`（RFC 2047/2231/折叠/注入）
  + `tests/nextpas.core.mime/test_mime_message`（树解析/极限/round-trip）。
- 全部测试经 common.mk（含 heaptrc gate），`make focused` + `HEAPTRC_GATE=1`
  产出 0 unfreed 证据。

## 5. 未决 / 后续

- multipart（form-data）与 mime.multipart 收敛（批次内不跨模块改动）。
- IMAP/POP3 批次复用 mime 树（BODYSTRUCTURE）与 smtp 行协议骨架。
- `validation.Email` 委托 mail 校验（跨模块改动，另行立项，README 已记录）。