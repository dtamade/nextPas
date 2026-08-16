# SMTP 服务器模块边界设计（批次 2，mailServer888 反哺）

- 日期：2026-08-16
- 状态：决策已定，待 Needs Review 后实施
- 关联：`docs/mail/CONTRACT.md`（v0.2）、`core/docs/plans/2026-08-16-mime-mail-module-boundary.md`
- 上游：批次 1（mime L2 + mail L3 桥接）已 landing（`f9062d43e`）

## 1. 问题

批次 2 需在 core 落地 SMTP **服务器**面（RFC 5321 会话状态机 + 命令执行），
供本项目 Phase 2（:25 收信）与 Phase 6（:587 Submission）消费。必须遵循重 IO
约束（PLAN D9）：**事件驱动**，复用 `net.server` 的 poll-driven 会话契约
（epoll/kqueue/iocp readiness 路径），不搞 per-connection-thread。

## 2. 关键决策

### 2.1 归属：SMTP server 归 `mail` 家族（L3）而非独立 `core.smtp` 根

- `mail.smtp` 客户端已在批次 1 landing（L3）。服务器与客户端共享同一套线上
  协议词汇：`TSmtpReply`（多行结构）、`TSmtpCapabilities`、行分隔/折行、
  `ESmtp*` 异常族、`MAX_SMTP_LINE`。
- 若设独立 `nextpas.core.smtp` 根会制造**并行且互不引用**的 reply/capabilities/
  异常类型，wire 语法分叉，违背「代码复用与架构优雅第一」。
- 一致性：IMAP/POP3（后续批次）若做，同理作为 mail 家族子模块（或按各自
  边界决策）；本文件纪录 mail 家族是 SMTP 的 L3 归属。
- 结构：`nextpas.core.mail.smtp`（既有客户端）+ 新增
  `nextpas.core.mail.smtp.server`（服务器事件驱动会话，**新单元**）。
  `mail.pas` 门面 re-export。

### 2.2 事件驱动会话范式：对齐 `net.server.ws.session`

服务器会话镜像 WS 会话的接线模型（`TNetWsFrameSession`）：
- 实现 `ITcpServerSession + ITcpServerPollDrivenSession +
  ITcpServerPollDrivenSessionWithDeadline + IFooSmtpServerSink`。
- `Run` 显式 501（事件驱动后端接入，不提供阻塞降级）。
- `PollEvents/Advance/WithDeadline` 由 reactor 调；可读喂行解析、可写冲刷
  出站回复队列；读空闲超时经 `WakeDeadline` 由 reactor 唤醒。
- 出站回复队列有界（背压）：超限即失败关闭。
- 线程约束：应用（收信/Submission 业务）经 sink 回调由 reactor 线程触发；
  业务往内送数据须经 context.WorkerHandoff 在 reactor 线程交付。

### 2.3 协议状态机范围（RFC 5321 务实子集）

会话命令集：
- `HELO/EHLO`（EHLO 能力列表：PIPELINING、8BITMIME、SIZE、AUTH PLAIN/LOGIN、
  STARTTLS 探测位、ENHANCEDSTATUSCODES）
- `MAIL FROM:<addr>`（可选 `SIZE=`）/ `RCPT TO:<addr>` / `DATA`（点转义、
  大小上限）/ `RSET` / `NOOP` / `QUIT` / `VRFY`（502 拒绝）
- `STARTTLS`（探测位 + 501/454 拒，握手属后续 TLS 批次）
- `AUTH PLAIN/LOGIN`（回调 sink 校验；实现为选项位，未启用则 503）
- `HELP`（214）/ `EXPN`（502）/ 未知命令（500）

状态机：`Banner → [Command 循环] → DATA 收集 → 消息事件 → Command 循环`。
每个命令后固定一条（或多行）回复；错误不与连接分离（RFC 5321 §4.3.2 容错）。

### 2.4 数据与事件类型

```pascal
TMailSmtpEnvelope = record
  From: TMailAddress;            // 已解析；MAIL FROM 可空（<> 弹回）
  Recipients: array of TMailAddress;
  Data: TBytes;                  // DATA 收集后的原始字节（含 CRLF，未点转义）
  Size: Int64;
end;

TMailSmtpServerEvent = (msseMessage, msseTimeout, msseOverflow, msseClosed);

ISmtpServerSink = interface   // 由应用（本项目 Phase 2）实现
  procedure OnServerEvent(const AEvent: TMailSmtpServerEvent;
    const AEnvelope: TMailSmtpEnvelope);   // msseMessage 时 Envelope 有效
end;
```

### 2.5 配置

```pascal
TMailSmtpServerConfig = record
  Domain: string;                // EHLO/HELO banner 域名；'' → hostname
  MaxMessageSize: Int64;         // DATA 上限；0 → 不限（默认 64MiB 对齐 mime）
  IdleTimeout: TDuration;        // 读空闲超时；<=0 不限
  OutboundQueueLimit: SizeUInt;  // 回复队列上限；0 → 默认 64KiB（对齐 ws）
  RequireAuth: Boolean;          // AUTH 后仍需 MAIL（Submission 语义，默认 False）
  class function Default: TMailSmtpServerConfig; static;
end;
```

## 3. 文件布局与依赖

| 文件 | 内容 | 依赖 |
|---|---|---|
| `src/nextpas.core.mail.smtp.server.pas`（新） | 服务器会话 + 事件/配置/sink | base, errors, net.server.intf, platform.io.base, time.deadline, mail.base, mail.smtp(共享类型) |
| `src/nextpas.core.mail.smtp.pas`（改） | re-export `ESmtp*`/`TSmtpReply` 供 server 复用（如已公开则无需） | 不变 |
| `src/nextpas.core.mail.pas`（改） | 门面 re-export server 类型 | 不变 |

解析细节（地址/能力/大小）复用既有 `mail.smtp` 已有原语或在本单元私有实现，
避免引第三方。

## 4. 测试策略

- `tests/nextpas.core.mail/test_mail_smtp_server/`：状态表单测（直接推进会话：
  喂命令字节 → 检查回复与事件）+ server×client 对跑
  （`mail.smtp` 客户端 ↔ 事件驱动服务器，threaded 后端可跑事件驱动会话，
  epoll 后端反正真测试）。heaptrc 0 leak。
- 覆盖：banner/EHLO 能力/HELO 回退/MAIL SIZE 拒绝/RCPT 拒绝/DATA 点转义与
  大小上限/RSET/NOOP/QUIT/未知命令/多收件人/超时/背压溢出。

## 5. 超出本批

- STARTTLS 握手、AUTH 具体凭证校验、PIPELINING 命令批处理加速、
  `SMTPS` 直连、DANE —— 各自依赖 net/tls / crypto / deliverability 批次。
- 服务器端 IMAP/POP3 状态机（mail 家族后续）。
- `enhancedstatuscodes` 仅作 EHLO 能力位，不完全实现 RFC 2034 全程。

## 6. 未决（记录）

- AUTH 校验回调签名（PLAIN 一次性 vs LOGIN 挑战步进）待与 deliverability 批次
  对齐；本批以「注册回调 + 缺省拒」交付。
- `ITcpServerSessionContext.WorkerHandoff` 在内送业务数据的使用示例待
  `net.server.ws` 升级文档后补。
