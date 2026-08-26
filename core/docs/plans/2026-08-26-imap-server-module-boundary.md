# IMAP 服务器模块边界设计（批次 3，mailServer888 反哺）

- 日期：2026-08-26
- 状态：决策已定，待 Needs Review 后实施
- 关联：`docs/mail/CONTRACT.md`（v0.2）、
  `core/docs/plans/2026-08-16-smtp-server-module-boundary.md`（家族归属先例）、
  `core/docs/plans/2026-08-16-mime-mail-module-boundary.md`
- 上游：批次 1/2（mime L2 + mail L3 桥接 + smtp server）已 landing；
  消费方 mailServer888 Phase 6a 入口硬门禁

## 1. 问题

批次 3 需在 core 落地 IMAP **服务器**面（RFC 3501 务实子集），供本项目
Phase 6a（:143 收信读取面）消费。约束同批次 2：**事件驱动**，复用
`net.server` 的 poll-driven 会话契约（epoll/kqueue/iocp readiness 路径），
禁止 per-connection-thread；会话热路径零分配目标对齐 D9。

原版基线：`fafafa-mail-server/src/smtp/imap.rs`（3054 行）。其已知缺陷
不得照抄：① 直接耦合 `SqlitePool` + 应用 cache（协议层直捅 SQL）；
② FETCH/SEARCH 全量拉原始行再内存过滤；③ 回复字符串手工拼接无长度
预算；④ 会话吊销依赖进程内 hub 订阅（与连接生命周期交织）。

## 2. 关键决策

### 2.1 归属：IMAP server 归 `mail` 家族（L3）而非独立 `core.imap` 根

- 与批次 2 SMTP server 同判据：mail 家族已是线协议骨架的唯一所有者
  （行分隔/CRLF 纪律/MAX_LINE/能力串构建/`TMailAddress`）；IMAP 复用
  同一底座，拆独立根会制造并行且互不引用的类型。
- registry **不新增行**：既有 `mail` 行（L3，focused-runtime）覆盖；
  `docs/mail/CONTRACT.md` v0.2 → v0.3 增补「IMAP 服务器」范围段，
  并把 §1.2「IMAP/POP3 客户端后续批次」保持不变（客户端不在本批）。
- 结构：新增 `nextpas.core.mail.imap.base`（类型/配置/存储 SPI）+
  `nextpas.core.mail.imap.server`(会话状态机)；`mail.pas` 门面 re-export。
  批次 3 预案中的 `nextpas.core.imap*.pas` 命名按家族归属修正。

### 2.2 事件驱动会话范式：镜像 `nextpas.core.mail.smtp.server`

- 实现 `ITcpServerSession + ITcpServerPollDrivenSession +
  ITcpServerPollDrivenSessionWithDeadline + ISmtpServerSink 式事件下沉`。
- `Run` 显式拒绝（无阻塞降级）；可读喂行解析（含 literal 字节计数态）、
  可写冲刷出站回复队列；读空闲超时经 `WakeDeadline` 由 reactor 唤醒。
- 出站回复队列有界背压（超限失败关闭）；回复组装带长度预算
  （修正原版缺陷③）。
- IDLE：进入 IDLE 后以 `WakeDeadline` 周期性查存储变更版本缝
  （见 2.5），有变化即发未决 EXISTS/FETCH 通知；`DONE` 终止。

### 2.3 协议状态机范围（RFC 3501 务实子集 = 原版行为基线）

命令集（原版 dispatch 全量对齐）：
- 任意态：`CAPABILITY` / `NOOP` / `LOGOUT`（`* BYE`）/ `STARTTLS`
  （探测位：tls 可用 `OK Begin TLS` 交还流、不可用/已激活/状态非法 `BAD`，
  握手本体属 tls 批次）
- 未认证态：`LOGIN`（SASL-IR；明文策略位：tls 不可用时按配置拒，
  对齐原版 `imap_login_allowed`）/ `AUTHENTICATE PLAIN`（回调校验，缺省拒）
- 认证态：`LIST` / `LSUB` / `SELECT` / `EXAMINE`（只读位）/ `STATUS` /
  `APPEND`（literal 正文）/ `CLOSE`
- 选择态：`FETCH` / `SEARCH` / `STORE` / `COPY` / `IDLE`(+`DONE`) 及
  `UID FETCH|SEARCH|STORE|COPY` 变体；未知命令 `BAD`，状态错序 `NO`

状态机：`NotAuthenticated → Authenticated → Selected ⇄ Authenticated → Logout`。
SELECT/EXAMINE 响应固定段：`EXISTS/RECENT 0/[UNSEEN n]/[UIDVALIDITY]/
[UIDNEXT]/FLAGS/PERMANENTFLAGS`（原版逐字语义）；邮箱模型沿用原版：
`INBOX` + 用户地址平铺（`\HasNoChildren`，分隔符 `/`）。

字面量：请求行 `{n}` 与 `{n+}`（LITERAL+）两形态；非 + 形态先发
`+ go ahead` 再收字节。能力串固定 `IMAP4rev1 LITERAL+ SASL-IR IDLE`
（+STARTTLS 探测位条件项），对齐原版 `IMAP_BASE_CAPABILITY`。

### 2.4 存储 SPI：协议层零 SQL（核心超越点，修正原版缺陷①②）

core 不见 SQL/连接池。`nextpas.core.mail.imap.base` 定义：

```pascal
IImapMailboxStore = interface   // 由应用(mailServer888 store 面)实现
  function ListMailboxes(AUserId: string): TImapMailboxList;
  function OpenMailbox(AUserId, AName: string; AReadOnly: Boolean;
    out ABox: TImapMailboxSnapshot): Boolean;   // EXISTS/UNSEEN/UIDNEXT...
  function FetchRows(ABox: TImapMailboxSnapshot; const ASet: TImapSequenceSet):
    TImapMailRowArray;        // uid/flags/size/internaldate/raw 惰性句柄
  function LoadContent(...): TBytes;                  // BODY[] 按需取
  procedure StoreFlags(...);                          // +/-FLAGS \Seen 等
  function Append(...): Int64;  function Copy(...): Boolean;
  function Search(const APred: TImapSearchPred): TInt64Array;  // 谓词下推
  function ChangeVersion(ABox): Int64;                // IDLE 版本缝
end;
```

- 序列集解析/谓词结构定义在 core（协议语法归 core），过滤执行归应用
  （可走 FTS/索引）；原版「全量拉行再内存筛」由应用自行优化，协议层
  不预设低效路径。
- `raw` 以句柄惰性加载：FETCH 不取 BODY 项时不触内容字节。

### 2.5 会话吊销与并发缝（修正原版缺陷④）

- 吊销：`TImapServerConfig.RevocationCheck: IImapRevocationCheck`
  （nil=关闭），每命令分发前调用一次；触发即发 `* BYE` 并关连。
  应用侧接既有会话引擎（mailsrv.auth 会话吊销联动，Phase 6a 出口），
  core 不内建 hub/订阅线程。
- 并发：同一用户多会话可见性靠 `ChangeVersion` 缝轮询；跨会话即时
  push 通知不在本批（原版 notify 匹配逻辑不搬，登记超范围）。

## 3. 文件布局与依赖

| 文件 | 内容 | 依赖 |
|---|---|---|
| `src/nextpas.core.mail.imap.base.pas`（新） | 类型/状态枚举/序列集与谓词解析/配置/存储 SPI/异常族 | base, mail.base(TMailAddress), platform.io.base |
| `src/nextpas.core.mail.imap.server.pas`（新） | 事件驱动会话状态机 + 命令分发 + 响应组装 | imap.base, net.server.intf, time.deadline |
| `src/nextpas.core.mail.pas`（改） | 门面 re-export imap 类型 | 不变 |
| `docs/mail/CONTRACT.md`（改 v0.3） | IMAP 服务器范围段 + INV 扩展 | — |

单元 >800 行拆子模块纪律适用；注释只解释 why。

## 4. 测试与基准策略

- `tests/nextpas.core.mail/test_mail_imap_server/`（nextpas.core.test
  框架，heaptrc 0 leak）：状态表单测（喂字节 → 断言逐条响应行）+
  mock `IImapMailboxStore`（内存夹具）覆盖全命令矩阵正负例 +
  字面量两形态 + UID 变体等价性 + IDLE 版本缝唤醒 + 吊销 BYE +
  背压溢出 + 畸形输入（tag 缺失/序列集越界/literal 超限）。
- 黄金向量回放：原版测试向量（imap.rs 内嵌 assert 期望串）转译入库；
  Phase 6a 出口的 python imapclient 脚本属应用侧验收，不入 core。
- 基准：`benchmarks/nextpas.core.mail/bench_mail_imap_parse/`
  （nextpas.core.bench 框架）——`parse_request_line` 微基准对标原版
  262.89ns（docs/perf/release-baseline.md），容差 ≤2x
  （PLAN Phase 6 出口③）。

## 5. 超出本批

- POP3（后续独立边界决策）；IMAP/POP3 **客户端**。
- STARTTLS 握手本体（tls 批次；本批仅探测位分支）。
- BODYSTRUCTURE 完整树（mime 树接入留缝：FetchRows 句柄预留扩展位）；
  FETCH 部分段 `<partial>` 若原版未支持则一并缓（以行为基线为准，实施时核对）。
- QUOTA：CAPABILITY 不宣告；契约留缝（base 预留扩展枚举位），
  按 FEATURE_MATRIX 口径「待立项」非真实实现。
- CONDSTORE/COMPRESS/SORT/UIDPLUS/EXPUNGE（FEATURE_MATRIX unplanned）。
- 跨会话即时 push 通知、邮箱层级（\HasChildren）。

## 6. 未决（记录）

- `AUTHENTICATE PLAIN` 是否本批：原版仅 LOGIN；若应用 Submission(:587)
  需要 AUTHENTICATE 一致性则随批加（回调缝已在配置位）。
- SEARCH 键集冻结清单（原版 UNSEEN 起步，实施时逐键对齐并留档差异）。
- IDLE 通知粒度（EXISTS-only vs EXISTS+FLAGS 更新）以原版行为为准，
  实施时以黄金向量定案。
