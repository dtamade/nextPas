# nextpas.core.mail 代码契约 v0.4

**模块路径**：`core/src/nextpas.core.mail*.pas`（base/mime/smtp/imap + 门面）
**层级**：L3（依赖 L0-L2 与 `nextpas.core.mime`）
**Owner**：codex/mime-mail-20260816（mailServer888 反哺）
**最后更新**：2026-08-26
**版本**：0.4（正式；v0.1 客户端草图废弃，见 §6 差异表；0.2→0.3 行为 SMTP
服务器批次，当时仅推进变更记录未改头部版本号，本版一并修正）

---

## 1. 范围与边界

### 1.1 范围内

- RFC 5322 §3.4/§3.6：`TMailAddress`（display-name + local@domain）、
  `TMailMessage` 摊平模型（From/Sender/ReplyTo/ToList/CcList/BccList/
  Subject/DateUtc/MessageId/BodyText/BodyHtml/Attachments）。
- 地址解析（务实 RFC 5321/5322 子集：长度/字符/点规则、`"Name" <addr>`、
  `[1.2.3.4]` 字面量）。
- 邮件特定 MIME 语义：日期容错解析/格式化、地址头、Subject 与 display-name
  的 RFC 2047 编解码接入（语法委托 mime，INV-A3）。
- SMTP 客户端（RFC 5321）：EHLO/HELO 回退、MAIL/RCPT/DATA、AUTH PLAIN/LOGIN、
  超时/取消、TryXxx 对偶（`nextpas.core.mail.smtp`）。
- SMTP 服务器事件驱动会话（RFC 5321 务实子集，`nextpas.core.mail.smtp.server`）：
  HELO/EHLO 能力（PIPELINING/8BITMIME/SIZE/AUTH/ENHANCEDSTATUSCODES）、
  MAIL/RCPT/DATA（点转义、大小上限、收件人上限）、RSET/NOOP/QUIT/HELP/VRFY，
  STARTTLS 探测位、AUTH 注册回调校验（缺省拒）；会话接入 `net.server`
  poll-driven 契约（epoll/kqueue/iocp readiness 路径），出站回复队列有界背压，
  读空闲超时经 WakeDeadline 由 reactor 唤醒。
- IMAP 服务器事件驱动会话（RFC 3501 务实子集 = 原版 imap.rs 行为基线，
  `mail.imap.base` + `mail.imap.server`）：CAPABILITY/NOOP/LOGOUT/
  STARTTLS 探测位/LOGIN/AUTHENTICATE PLAIN/LIST/LSUB/SELECT/EXAMINE/
  STATUS/APPEND(literal)/CLOSE/IDLE(+DONE)/FETCH/SEARCH/STORE/COPY 及
  UID 四变体；literal 收集二进制安全（每命令至多一个）；IDLE 经
  ChangeVersion 缝轮询 + 双截止（总时长/轮询周期）；会话吊销缝每命令
  前查；存储 SPI 零 SQL（IImapMailboxStore 由应用实现）。边界决策见
  plans/2026-08-26-imap-server-module-boundary.md。

### 1.2 明确不做（后续批次）

| 能力 | 归属 |
|------|------|
| IMAP / POP3 客户端 | 后续批次（复用 mime 树 BODYSTRUCTURE 与 smtp 行协议骨架）；POP3 服务器同理 |
| STARTTLS 握手 / SMTPS / DANE | net/tls 与 deliverability 批次（本批仅探测位；IMAP STARTTLS「OK」分支在握手缝就绪前不可达，默认配置走 unavailable） |
| STARTTLS 握手 / SMTPS / DANE | net/tls 与 deliverability 批次（本批仅探测位） |
| MIME 语法本身 | `nextpas.core.mime`（L2，唯一语法所有者） |
| DKIM/SPF/DMARC、DNS | deliverability / net.resolve 批次 |
| 业务表/策略 | 应用层 |

## 2. 公共面（base）

```pascal
TMailAddress = record
  DisplayName: string;   // 已解引号、UTF-8；格式化时按需 RFC 2047 编码
  LocalPart: string;     // 小写归一
  Domain: string;        // 小写归一（纯语法，不做 IDN/DNS，INV-A6）
end;
// class 方法：Parse / TryParse / IsValidAddress / IsValid
TMailAttachment = record
  FileName: string; ContentType: string; ContentId: string; Data: TBytes;
end;
TMailMessage = record
  MessageId: string; From: TMailAddress; ToList/CcList/ReplyToList: array of TMailAddress;
  Subject: string; DateUtc: Int64; BodyText/BodyHtml: string;
  HasAttachments: Boolean; Attachments: array of TMailAttachment;
end;
```

> 摊平模型（BodyText/BodyHtml/Attachments）为网关层共识载体：收信解析后
> 直接落库/展示，发信构建时经 `mail.mime` 桥接为完整 MIME 树（INV-A3）。

## 3. 桥接层（nextpas.core.mail.mime）

- `MimeSerialize(TMailMessage): string`：Subject/display-name 按需 RFC 2047
  编码；附件 filename 经 RFC 2231；头值 CR/LF 注入清洗；multipart
  mixed/alternative 自动组装。
- `MimeTryParse/MimeParse(string)`：MIME 树 → 摊平模型（首个 text/plain →
  BodyText、首个 text/html → BodyHtml、attachment/text 其余 → 附件）；
  RFC 2047 解码 Subject；Date 容错解析并上报 `miBadDate`。
- 兼容面：`MimeParseHeaders/MimeHeaderValue/MimeParseContentType/
  MimeParseParams/MimeBase64*/MimeQuotedPrintable*` 全部保留原名转发
  （行为与 mime 层一致），既有调用方零迁移。

## 4. 异常（INV-A5）

- `EMailError`（根，继承 EParseError→ENextPasError 体系）。
- `EMailAddressError`（地址语法违规，消息携带原始输入）、`EMailHeaderError`、
  `EMailParseError`。网络/协议类异常归 smtp（`ESmtp*`）。

## 5. 不变量

- **[INV-A1]** 地址解析严格遵循 RFC 5321/5322 务实子集；`Parse` 违规抛
  `EMailAddressError`，`TryParse` 返回 False 且不抛；宽容仅限 obs 形态
  （display-name 引号、纯 IP 字面量），不「逐字收下任何东西」。
- **[INV-A2]** 消息构建不强制必选头（From/Date 由调用方策略补齐；桥接层
  不静默补值——`MimeSerialize` 仅序列化已设置字段）。
- **[INV-A3]** MIME 语法唯一所有者是 `nextpas.core.mime`；mail 不重复实现
  头/传输编码/multipart 语法（防双实现漂移）。
- **[INV-A4]** record 值语义 + 浅拷贝；跨线程只读共享安全（无懒初始化内部
  状态）；构建期独占写入由调用方保证。
- **[INV-A5]** 全部失败路径抛 `E*` 异常或 TryXxx 返回 False，绝不静默吞错；
  边界 try 由调用方（HTTP/SMTP 入口）统一捕获。
- **[INV-A6]** 域名字段纯语法，不做 IDN-punycode / DNS 查询（net.resolve 批次）。
- **[INV-A7]** SMTP 服务器会话不提供阻塞降级：`Run` 显式 501，只接
  poll-driven 后端（事件驱动纪律，PLAN D9）；出站回复队列有界（背压超限
  即 msseOverflow 失败关闭），DATA 上限/收件人上限受配置约束（RFC 5321 §4.5.3.1）。
- **[INV-A8]** 服务器收信事件（msseMessage）在 reactor 线程交付，Envelope
  持有 Data 的独立所有权副本；`Envelope.ClientIP` 为对端 IP（连接 RemoteAddr
  读取，reactor 线程，纯文本不做解析），消费方可在回调内直接使用但不执行
  阻塞 I/O；会话销毁/传输终止必发 msseClosed。
- **[INV-A9]** IMAP 服务器会话不提供阻塞降级（同 INV-A7）；出站回复队列
  有界背压（超限 iiseOverflow 失败关闭）；命令行/literal 尺寸受配置约束，
  行超限断开、literal 超限 tagged BAD + 计数丢弃（防失控客户端滞留膨胀）；
  每命令至多一个 literal（务实限制）。
- **[INV-A10]** IMAP 协议层零 SQL：邮箱数据一律经 IImapMailboxStore 注入；
  预期失败用返回值（不存在/越界空集），存储故障抛 EImapTempError → 会话
  统一回「tagged NO Temporary server error」（fail-closed，异常绝不穿透
  reactor）。存储/认证/吊销回调在 reactor 线程同步执行，实现须短、非阻塞
  （池内短事务/WAL；长任务自行卸载——同 ISmtpMailPolicyHook 纪律）。
  读缓冲在冲刷断点处保留压实、绝不丢弃（literal 正文与续行提示同批到达
  时依赖此纪律闭环；同 SMTP 会话 DrainReadable 语义）。
- **[INV-A11]** IMAP 认证 fail-closed：LoginCheck 未注入时 LOGIN/
  AUTHENTICATE 一律 NO Authentication temporarily unavailable；已认证
  会话每命令分发前过 RevocationCheck（irsRevoked → 重置态 + NO
  Authentication required），LOGOUT/CAPABILITY 免检。

## 6. 与 v0.1 差异表（v0.1 = 客户端草图）

| v0.1 元素 | v0.2 处置 |
|---|---|
| `IMailClient`（Connect/Login/Send/...） | 废弃；消息层无网络语义，SMTP 实体化为 `mail.smtp` |
| `IMailMessage` + SetXxx/AddXxx | 废弃；record 值语义 + 函数式桥接 |
| `TMailMessage` 平铺（From/ToList/... + Attachments） | 升级：结构化地址、新增 ReplyTo、DateUtc、MessageId、CID |
| `TMailAttachment` | 保留（网关共识载体；MIME 树内等价于 Content-Disposition 部件） |
| 协议支持表（SMTP/IMAP/POP3 端口） | SMTP 客户端落地；IMAP/POP3 批次 |
| INV-1/2（连接状态机/发送原子性） | 归 smtp |
| INV-3 附件大小 | 服务端限额是应用 policy；语法侧防护在 mime INV-M3 |
| INV-4 地址验证 | 升级保留 → INV-A1 |
| 错误 EConnectionError 等 | 废弃 → EMail*/ESmtp* |

## 7. 测试与证据

- `test_mail_address`（8 用例）、`test_mail_mime`（24 用例）、
  `test_smtp_client`（13 用例，本地 mock 服务器）、`test_mail_smtp_server`
  （9 用例，epoll readiness 后端 + mail.smtp 客户端对跑）；全部经 common.mk
  （heaptrc gate）0 unfreed。
- `test_mail_smtp_server` 覆盖：banner/EHLO 能力/HELO、MAIL/RCPT/DATA 全流程
  与点转义、SIZE/收件人上限、命令顺序与语法错误、VRFY/EXPN/STARTTLS 探测、
  AUTH 未启用与 RequireAuth、QUIT 关闭、读空闲超时、出站背压溢出中止。

## 8. IMAP 对原版基线的偏离表

| 点 | 原版行为 | 本契约行为 | 定性 |
|---|---|---|---|
| BODY.PEEK[] | 子串包含误判含 BODY → 取正文且置 \Seen | token 精确匹配，PEEK 只读不置旗标 | 修正缺陷（超越点） |
| AUTHENTICATE PLAIN | 宣告 AUTH=PLAIN 但命令未实现（BAD Unknown command） | 可用：SASL-IR 与挑战两形态，复用 LoginCheck 缝 | 修正缺陷（超越点） |
| FETCH 词表 | UID/FLAGS/ENVELOPE/BODY[]/RFC822，未知项兜底 FLAGS | 同上全兼容 + RFC822.SIZE/INTERNALDATE/BODY.PEEK[]/RFC822.HEADER 精确输出 | 加量能力（原版合法输入中仅新增项行为变化） |
| 序列集 | FETCH/COPY 支持集合；STORE 仅单序号 | 同口径保持；STORE range → BAD Invalid STORE sequence-set（逐字） | parity 保持 |
| LSUB tagged 文案 | 复用 LIST 处理器，tagged 行恒「LIST completed」 | 保持（怪癖 parity） | parity 保持 |
| UID SEARCH 输出 | uid_mode 参数未用，两模式均输出 UID | 保持 | parity 保持 |
| STARTTLS「OK」分支 | 交还流做 TLS 握手 | 无握手缝：OK 应答后关闭连接（默认配置 TlsAvailable=False 走 unavailable，不可达）；tls 批次接线 | 已披露限制 |
| LOGIN 错误文案 | Invalid credentials / temporarily unavailable 两分 | 三态缝映射 iarInvalid→NO Authentication failed / iarUnavailable→temporarily unavailable | 文案微调（语义等价三分） |

## 9. 测试与证据（IMAP 增量）

- `test_mail_imap_server`：epoll readiness 后端 + 裸行协议客户端 +
  内存 mock 存储/认证/吊销缝；**16 用例全绿，heaptrc 0 unfreed
  （6259 blocks alloc/free 平衡）**。覆盖问候与能力串（TLS 探测位双分支）、
  登录三态与门控、AUTHENTICATE PLAIN（IR/挑战/取消/坏机制）、LIST/LSUB、
  SELECT/EXAMINE 全块黄金向量、STATUS、FETCH 项矩阵（FLAGS/UID/ENVELOPE/
  RFC822.SIZE/BODY[] 置 Seen/BODY.PEEK[] 不置）、SEARCH UNSEEN、STORE
  （置/清/no-op/只读拒/单序号）、COPY（成功/目标缺失/坏序列集）、APPEND
  （续行 literal 与 LITERAL+ 直收、超限拒绝）、IDLE（DONE 循环/变更
  EXISTS 推送/超时 BYE/非 DONE 行 BAD）、吊销中途撤销、未知命令/空行、
  背压溢出中止；heaptrc 0 unfreed。
- `bench_mail_imap_parse`：请求行解析微基准，对标原版
  parse_imap_request_line median 262.89ns（容差 ≤2x，PLAN Phase 6 出口③）。
  **实测 127–186 ns/op**（同负载三跑：144/186/127，-O2，2M iters/跑），
  为基线的 0.48–0.71x，预算内富余。序列集解析（UID 模式、64 升序稀疏
  UID）实测 ~2.3–3.8 µs/op（mask 化 O(N+E)，每命令一次的扇出路径，
  无原版对应项，信息性记录）。

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-07-06 | 0.1 | 客户端草图（IMailClient/IMailMessage/协议表） |
| 2026-08-16 | 0.1→0.2 | 废弃客户端草图；邮件域落地：地址/消息模型/MIME 桥接（依赖 mime）/SMTP 客户端；E* 异常与不变量体系 |
| 2026-08-16 | 0.2→0.3 | 新增 SMTP 服务器事件驱动会话（mail.smtp.server，net.server poll-driven）；边界决策见 plans/2026-08-16-smtp-server-module-boundary.md；INV-A7/A8 |
| 2026-08-26 | 0.3→0.4 | 新增 IMAP 服务器事件驱动会话（mail.imap.base/server，存储 SPI 零 SQL）；边界决策见 plans/2026-08-26-imap-server-module-boundary.md；INV-A9/A10/A11；§8 偏离表；修正头部版本号漂移 |