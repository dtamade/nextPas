# nextpas.core.mime 代码契约 v0.2

**模块路径**：`core/src/nextpas.core.mime*.pas`（base/header/parser/builder/types + 门面）
**层级**：L2（格式层，同 multipart/json/csv；依赖 L0-L1 与 text/encoding/time）
**Owner**：codex/mime-mail-20260816（mailServer888 反哺）
**最后更新**：2026-08-31
**版本**：0.3（正式）

---

## 1. 范围与边界

### 1.1 范围内

- RFC 2045/2046：媒体类型、Content-Type/Content-Disposition 参数、传输编码
  （base64/QP/7bit/8bit/binary）、multipart 消息与部件树。
- RFC 2047：头字段 encoded-word 编解码。
- RFC 2231：参数扩展编码（`name*=charset''percent` 单段与多段首段；多段
  `*N*` 拼接为后续批次）。
- 严格 + 容错双通道解析；树模型序列化（含流式）。

### 1.2 明确不做

| 能力 | 归属 |
|------|------|
| 地址/日期等邮件字段语义 | `nextpas.core.mail`（L3） |
| HTTP form-data 分段 | `nextpas.core.multipart`（L2，分工见 §7） |
| DKIM canonicalization | deliverability 批次 |
| 字符集转码（charset→UTF-8 猜测） | 由调用方 / encoding 层（INV-M7） |

## 2. 公共面

### 2.1 base

- 常量：`MEDIA_*`、`ENC_*`、`PARAM_*`、`DISPOSITION_*`；
  `MIME_DEFAULT_MAX_BYTES`（64MB）/`MIME_DEFAULT_MAX_DEPTH`（32）。
- `TMimeParameter`（Name 小写归一于 2231 展开后）、`TMimeHeader`（Name 保留
  原样、检索大小写不敏感）、`TMimeContentType`、`TMimeContentDisposition`
  （媒体类型/disposition 小写归一）。
- 异常：`EMimeError`（根，继承 EParseError→ENextPasError 体系）、
  `EMimeParseError`、`EMimeEncodeError`、`EMimeLimitError`
  （Category=ecResourceExhausted）。

### 2.1a types（静态资源 Content-Type 猜测，L2 单一事实源）

- O(1) 开放寻址哈希（128 槽，FNV-1a 小写归一，1-2 探测命中 65 项）；零分配切片（PChar 段直哈，无 `Copy`），`MimeTypeFromExt/Path` 全 `inline`。
- 复用 L0 `base.utils HashFNV1aLower/CompareBytesIgnoreCase` 单源（`bytes.ops` 同源），供 L3 `http.mime` 薄门面 `inline` 复用，消除 L3 同层依赖；`webview.mime` 薄门面已于 S107 物理删除（`core/src/nextpas.core.webview.mime.pas` 不再参与家族 glob，单源收敛至 L2 `mime.types` 65 项 O(1) 哈希 128 槽 1-2 探测，LookupBySlice 直哈 PChar 段无 Copy，inline 零拷贝 View 直通，零分配）。

```pascal
function MimeTypeFromExt(const AExt: string): string; inline;
function MimeTypeFromPath(const APath: string): string; inline;
```

### 2.2 header

```pascal
function EncodeHeaderText(const AValue: string; const ACharset: string = 'UTF-8'): string;
function DecodeHeaderText(const AValue: string): string;
function EncodeParameterValue(const AValue: string): string;   // RFC 2231 单值
function DecodeParameterValue(const AValue: string): string;
function UnfoldHeaderValue(const AValue: string): string;
function SanitizeHeaderValue(const AValue: string): string;
function IsAscii(const AValue: string): Boolean;
```

### 2.3 parser

```pascal
function ParseHeaders(const ARaw: string; out AHeaders: TMimeHeaderArray;
  out ABody: string): Boolean;                                   // 严格
function TryParseHeaders(...; out AIssues: TMimeIssueArray): Boolean;  // 容错
function ParseParameters(const AValue: string; out AParams: TMimeParameterArray): Boolean;
function ParseContentType(const AValue: string; out ACT: TMimeContentType): Boolean;
procedure ParseContentDisposition(const AValue: string; out ADisp: TMimeContentDisposition);
function HeaderValue(const AHeaders: TMimeHeaderArray; const AName: string): string;
function DecodeBase64(const AEncoded: string; out AData: TBytes): Boolean;      // 容错原语
function DecodeQuotedPrintable(const AEncoded: string; out AData: TBytes): Boolean;
function DecodeTransferEncoding(const AEncoding: string; const AData: TBytes): TBytes; // 严格
function ParseMessage(const AData: TBytes;
  const AMaxBytes: Int64 = 67108864; const AMaxDepth: Integer = 32): TMimeMessage; // 严格
function TryParseMessage(const AData: TBytes; out AMsg: TMimeMessage;
  out AIssues: TMimeIssueArray): Boolean;                        // 容错
function IsValidBoundary(const ABoundary: string): Boolean;
```

树模型：

```pascal
TMimePart = record
  Headers: TMimeHeaderArray;
  ContentType: string;                    // 小写；缺省 text/plain
  ContentTypeParams: TMimeParameterArray; // 含 boundary；RFC 2231 已解码
  ContentTransferEncoding: string;        // 小写；缺省 7bit
  Disposition: string;                    // '' | attachment | inline
  DispositionParams: TMimeParameterArray;
  Body: TBytes;                           // 传输解码后；multipart/* 为空
  Children: array of TMimePart;
end;
TMimeMessage = record
  Headers: TMimeHeaderArray;              // 顶层头（邮件字段语义归 mail）
  Root: TMimePart;                        // 根部件（实体头继承顶层 content-*）
end;
```

### 2.4 builder

```pascal
function EncodeBase64(const AData: TBytes): string;              // 76 列折行
function EncodeQuotedPrintable(const AData: TBytes): string;
function EncodeTransferEncoding(const AEncoding: string; const AData: TBytes): TBytes; // 严格
function GenerateBoundary: string;                               // 线程安全（原子序列）
function BuildMessage(const AMsg: TMimeMessage): TBytes;
procedure BuildMessageToStream(const AMsg: TMimeMessage; const AWriter: IStream);
```

## 3. 不变量

- **[INV-M1]** 解析确定性：同一输入必得同一输出；严格通道语法违规必须抛
  `EMimeParseError`，不允许宽容吞错产出物化结果（容错通道除外，见 §5）。
- **[INV-M2]** 字段名大小写不敏感：`HeaderValue` 忽略大小写；值行执行 unfold。
- **[INV-M3]** 无界输入防护：`ParseMessage` 默认 64MB / 32 层深度上限，
  超限抛 `EMimeLimitError`；容错通道以 `miTooDeep` 截断。禁止无约束递归。
- **[INV-M4]** RFC 2047：`DecodeHeaderText(EncodeHeaderText(W)) = W`；编码
  按字符边界切段保证 encoded-word ≤75 字符；坏 base64/Q 内容剥壳按原文
  交付、未闭合编码对整体原样保留（宽容，不抛）。
- **[INV-M5]** Build 语义 round-trip：`ParseMessage(BuildMessage(M))` 与 M
  语义等值（部件树/头字段一致；boundary 与传输编码形式允许归一），由测试锁定。
- **[INV-M6]** boundary 遵循 RFC 2046 §5.1.1（≤70 字符、bchars 子集）；
  缺 boundary/非法 boundary 的 multipart 严格通道抛 `EMimeParseError`。
- **[INV-M7]** 参数值 RFC 2231 解码为 UTF-8（charset=UTF-8）；未带 UTF-8
  charset 的 encoded-text 保持原样字节交付，core 不做猜测式转码。

## 4. 线程与内存语义

- 解析/构建/编码函数无共享可变状态（boundary 序列号原子递增）。
- 树与 bytes 所有权归调用方；`BuildMessageToStream` 逐段写 IWriter，
  避免整封消息二次拷贝。

## 5. 容错通道（Try*）

问题经 `TMimeIssueArray` 上报（`miBadEncoding`/`miBadHeader`/
`miTruncatedMultipart`/`miUnknownTransferEncoding`/`miTooDeep`；
`miBadDate`/`miBadAddress` 由 mail 层产生）。供 SMTP 收信等边界入口的
统一捕获；严格契约（抛）由 `Parse*` 承担。二者分离，语义不混淆。

## 6. 测试与证据

- `core/tests/nextpas.core.mime/test_mime_header`（RFC 2047/2231/折叠/注入）。
- `core/tests/nextpas.core.mime/test_mime_message`（树解析/双通道/上限/round-trip）。
- 全部经 common.mk（heaptrc gate）；`make focused` + `HEAPTRC_GATE=1`
  0 unfreed 证据见 lane 验收记录。

## 7. 与 multipart / mail 的关系

- `nextpas.core.multipart`：字节级分段器、HTTP form-data（registry 记
  "HTTP grammar only"）；语法同源，收敛留待后续批次。
- `nextpas.core.mail`（L3）依赖本模块，仅做邮件字段语义与消息模型桥接，
  不重复实现 MIME 语法（INV-A3）。

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-16 | 0.2 | 正式契约：从 mail.mime 抽取独立 L2 模块；新增 RFC 2047/2231、严格+容错双通道、INV-M3 上限、流式构建 |
| 2026-08-31 | 0.3 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |