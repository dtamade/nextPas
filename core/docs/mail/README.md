# nextpas.core.mail

邮件域基础模块。当前承载：RFC 5322 邮件地址模型与校验、邮件消息/附件载体类型、
MIME 编解码（RFC 5322/2045/2046 子集）、SMTP 客户端（RFC 5321）。IMAP/POP3 按批次扩展
（见 `docs/plans/` 与本目录 CONTRACT.md）。

## 使用

```pascal
uses
  nextpas.core.mail;

var
  LAddr: TMailAddress;
begin
  if TMailAddress.TryParse('"Tester" <test@example.com>', LAddr) then
    WriteLn(LAddr.Full);          // test@example.com
  LAddr := TMailAddress.Parse('bad-address');  // 抛 EParseError
end;
```

MIME / SMTP 示例：

```pascal
uses
  nextpas.core.mail, nextpas.core.mail.mime, nextpas.core.mail.smtp;

var
  LMsg: TMailMessage;
  LText, LIssues: TMimeIssueList;
begin
  LMsg := TMailMessage.Create;
  LMsg.From := TMailAddress.Parse('me@example.com');
  LMsg.Subject := 'hi';
  LMsg.BodyText := 'hello';
  WriteLn(MimeSerialize(LMsg));          // 完整 RFC5322/MIME 文本
  MimeTryParse(MimeSerialize(LMsg), LMsg, LIssues);  // round-trip，问题入 LIssues
end;
```

## 模块结构

| 单元 | 层级 | 职责 |
|---|---|---|
| `nextpas.core.mail.base` | — | 载体类型（TMailAddress / TMailAttachment / TMailMessage）+ record 方法实现 |
| `nextpas.core.mail` | — | 门面（re-export，含 `TMailAddressArray`） |
| `nextpas.core.mail.mime` | L2 | MIME 编解码：头/地址/参数解析、base64/QP、multipart 组装与解析、Date 容错解析 |
| `nextpas.core.mail.smtp` | L3 | SMTP 客户端：连接/EHLO/MAIL/RCPT/DATA/QUIT、AUTH、超时与取消、异常 + TryXxx |
| `nextpas.core.mail.imap` / `pop3` | L3 | （规划）IMAP/POP3 客户端 |
| `nextpas.core.mail.address` | — | （视需要）地址解析/校验实现子模块拆分 |

## 校验与编码规则

### 地址（务实 RFC 5321/5322 子集）

| 项 | 规则 |
|---|---|
| 总长 | ≤ 254（RFC 5321） |
| 本地部分 | ≤ 64；dot-atom 子集 `[A-Za-z0-9.+-_]`，点不连续/不首尾 |
| 域名 | 逐 label ≤ 63，总长 ≤ 253；字母数字+连字符，连字符不首尾；支持 `[1.2.3.4]` 字面量 |
| 规范化 | trim + 全小写；支持 `"Display" <addr>` 形式 |

### MIME 编码（nextpas.core.mail.mime）

| 项 | 规则 |
|---|---|
| 行宽 | 编码行 ≤ 76（base64 软换行 CRLF；QP 在 75 内容处断行 + `=`） |
| base64 | 标准字母表；解码容忍空白/坏填充；坏编码报 `miBadEncoding` 并保留原文 |
| quoted-printable | `=XX` 十六进制转义、软换行 `=CRLF`；`=`、不可打印、行尾空格编码 |
| 头序列化 | 值中 CR/LF 一律按注入清洗为空格；超长头按 `CRLF <ws>` 折叠 |
| multipart | 边界 `=_nextpas_<hex>_<seq>`；parse 时容错末边界缺失/截断（`miTruncatedMultipart`） |
| 正文分派 | 首个 text/plain → `BodyText`，首个 text/html → `BodyHtml`，其余 attachment |
| Date | RFC 5322 输出；解析容错：省略星期/时区、2 位年、冒号时区、GMT/UT/UTC/Z、US 军用时区 |

### SMTP（nextpas.core.mail.smtp）

| 项 | 规则 |
|---|---|
| 命令序列 | 问候 2xx → EHLO（失败回退 HELO）→ MAIL → 每收件人 RCPT → DATA（3xx）→ 正文+`.` → 终答 2xx → QUIT |
| 点转义 | 行首 `.` 双写；结束点自带行界 `CRLF . CRLF` |
| 能力 | EHLO 多行解析 → 扩展（小写）/AUTH 机制（大写）/SIZE |
| AUTH | 广播 PLAIN 优先；仅 LOGIN 时走 334 挑战式 |
| 超时/取消 | 连接受拨号超时；单次读写 deadline；`Cancel` 唤醒阻塞读写（`ECancelledError`） |
| 错误 | 服务端拒绝 → `ESmtpRejectedError`；AUTH 失败 → `ESmtpAuthError`；协议违例 → `ESmtpProtocolError`；全部配 TryXxx 对偶 |
| 响应解析 | 3 位码 + 多行（`250-…` 续行，同码 `250 ` 结尾）；2xx/3xx/4xx/5xx 分类 |

> `nextpas.core.validation.TValidator.Email` 仍是最简形式（仅检查 `@` 位置）；
> mail 模块提供严格校验后，后续批次评估让 validator 委托 mail（跨模块改动，另行立项）。

## 测试与基准

| 目录 | 覆盖 |
|---|---|
| `tests/nextpas.core.mail/test_mail_address` | 地址解析/校验契约测试（8 用例） |
| `tests/nextpas.core.mail/test_mail_mime` | MIME 头/编码/multipart/畸形输入/Date（24 用例） |
| `tests/nextpas.core.mail/test_smtp_client` | SMTP 会话、AUTH、错误码、超时/取消（13 用例，本地 mock 服务器） |

基准随后续批次补充（benchmarks/nextpas.core.mail/）。

## 后续批次

- B2：IMAP4（IDLE/FLAGS/UID）——复用 SMTP 的行协议与超时骨架
- B3：POP3（TOP/RETR/DELE）
- B4：S/MIME 与 DKIM 验签（依赖 core.crypto 就绪度）；正文规范化（HTML→text）经 core.html