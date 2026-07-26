# nextpas.core.http Roadmap

**Authority**: 本文件是 HTTP 模块**向前开发**的唯一执行入口。
**Companion**: 北极星背景见 `GOAL_TREE.md`；契约见 `CONTRACT.md`；宣称见 `CLAIM.md`；复现见 `REPRO.md`。
**Updated**: 2026-07-26（Era P h2 DoS defense：rapid-reset + control-frame flood + CONTINUATION flood 连接级升级 + HPACK 放大 backstop + doc-truth；P-1..P-5 landed；NEXT=P-band 继续/剩余 h2 DoS 向量评估）
**历史**: Era 0 至 R2 residual 的全部已完成 Wave 详表与旧 changelog 已冻结在
[`archive/2026-07-26-roadmap-history-era0-to-r2.md`](archive/2026-07-26-roadmap-history-era0-to-r2.md)——**不是 backlog**，只作证据检索。

---

## 0. 进场 30 秒（给执行者 / AI）

1. **当前 NEXT = M-band**（Era W2 已收官；候选升格待产品确认，见 §5/§6）。
2. NEXT 被堵？按 §3「反碰壁规则」逐级兜底——**永远有合法的下一步**，STOP 只在兜底链全空时才合法。
3. 已冻结的对外宣称只看 [`CLAIM.md`](CLAIM.md)；不要重复采集已 Met 的规模证据。
4. 硬排除（见 §7）：H3 假 facade、Windows scale 宣称、为对标扩 API。
5. 每 land 一波：回写本文件（wave→landed、NEXT→下一行、changelog 一行）。

---

## 1. 北极星（不变；执行时服从）

把 `nextpas.core.http` 做成**可对标 Go `net/http` / Rust hyper 系的 H1/H2 HTTP 框架**——质量 + 规模双硬指标：

| 支柱 | 含义 | 状态 |
|------|------|------|
| **质量** | 正确性边角、Kind/Op、ownership、生产契约有证据；无假 facade | 达成，维持 |
| **规模** | Linux epoll 下与 Go 同机比值可验收 | **全部 Met**（H1/H2/HTTPS，见 CLAIM.md） |
| **优雅** | 小接口、同步公开契约；不泄漏 reactor | 达成，维持 |
| **诚实** | H3 Blocked、Windows residual 写明；未达标禁止写「已对标」 | 持续执行 |

规模退出线（≥0.8× Go、p99 ≤2×、连接阶梯）已全部 Met 并冻结在 `CLAIM.md`；本文件不再维护数字表。

---

## 2. 当前状态快照（唯一一处；回写时更新）

| 项 | 状态 |
|----|------|
| framework-complete (non-H3) | **yes**（Era 0–4 + Excellence + Residual + Inbox depth，全史见 archive） |
| Scale claims | **H1 / H1+H2 package / HTTPS H1 / HTTPS H2 全 Met**（Linux epoll，冻结于 `CLAIM.md`） |
| 源码结构 | **82** 个 `nextpas.core.http*` 单元；SAFE/R2 remediation + STRUCT 抽取已完成 |
| 测试门禁 | 主 Makefile **PROJECTS = 47** focused suites（heaptrc 敏感套件 0 unfreed） |
| Windows | **W2-3b landed**：`net.server.iocp` completion 驱动 recv/send/deadline-wake 三路齐备——server 自有 GQCS 事件循环（`PollOneWait` 三态），writable waiter 1ms timeout 重试，有限 `WakeDeadline` 经 GQCS-timeout 扫描 + `TryCancelByContext`/`WakePending` 取消唤醒（单路等待不变式保持：recv op 挂起 XOR waiter/sleeper）；生产 H1 session 走完成路径。真机证据：`http.iocp_wire` **6 用例** + 0 unfreed on windows-latest（Core CI run 30196530589；deadline wake 真机 437ms ≈ Wine 445ms，`CancelIoEx` 语义一致）。⚠️ Wine 语义差异：非阻塞 send 单次大 buffer 整块吞下不 WouldBlock，须分块写（真机无此差异，已验证） |
| Multi-OS host | `test_http_threaded_host` + `test_http_iocp_wine`（IOCP wire）+ `test_http_iocp_facade_wine`（**M-1**：产品 `THttpServer`+`tsbIocp` GET/keep-alive 端到端；uses 常驻钉住 full facade Win64 交叉编译——原 TLS 链 FPC internal residual 已消除；Windows host 真用例/其他 host skip 断言）经 `core/scripts/http-host-ci-matrix.sh`（Linux/macOS/Windows/FreeBSD CI，smoke only） |
| H3 | **Blocked**：仓库仅有 `tls.quic.crypto` 原语，无可链 QUIC transport；禁止空 facade |
| **NEXT** | **P-band 继续**——Era P（h2 DoS defense）P-1..P-5 已 landed（rapid-reset + control-frame flood + CONTINUATION flood 连接级升级 + HPACK 放大硬 backstop）；剩余 DoS 向量评估（默认无限并发 `MAX_CONCURRENT_STREAMS=0` / window-update flood / 空 DATA flood）；改方向先改本行 + §11 changelog |

---

## 3. Goal Loop（自治执行；含反碰壁规则）

```text
LOOP:
  1. 读 §2 快照 → 取唯一 NEXT Wave
  2. 实现（一波 ≤3 项）+ focused gate(s) + git diff --check + make hygiene
  3. path-limited land main
       默认 ALLOW 路径：
         core/src/nextpas.core.http*
         core/tests/nextpas.core.http/**
         core/docs/http/**
         examples / benchmarks 下 http 子树（若本波触及）
       跨模块（net/io/platform/tls/mem）：必须在本波「Land paths」声明 + 双端 focused gate
  4. 回写本文件：本 Wave → landed；§2 NEXT → 下一行；changelog 一行
  5. 无用户指令时 goto 1（自动续波）

反碰壁规则（按顺序兜底；禁止在中途自行发明工作）:
  a. NEXT Wave 被堵（缺环境/缺依赖/连续 3 次 focused 失败）
       → 在该 Wave 表里写一行 Blocked 原因，取本 Era 下一个非 Blocked Wave
  b. 本 Era 全堵 → 取 §5 M-band 维护带任一有界项（无需授权）
  c. M-band 也无可做 → 才允许 STOP，输出 Blocked 报告（堵点、已试动作、需谁决策）

STOP / ASK（打断用户）:
  - 改 owner boundary / 新公开 API 家族 / 跨 >2 模块且无先例
  - Inbox 条目缺 Done when 却被要求实现
  - force-push、破坏性 git、动 main 治理策略

CHECKPOINT（不阻塞续波）:
  - 每 land 一波：一行 Ready（wave / HEAD / gates / next）
```

**自治强度**：满自治。默认连续执行推荐路径，只在 STOP/ASK 条件停下。

---

## 4. Era W2 — Windows 生产化 phase-2：IOCP 数据路径【Done 2026-07-26】

**目标**：把 WIN-3 phase-1 留下的诚实缺口补上——`net.server.iocp` 从「AcceptEx + worker handoff」升级为**完成驱动的 per-conn 协议数据路径**，并把验证从 Wine smoke 推进到真 Windows host CI。
**非目标**：Windows scale-ready 宣称（除非 W2-4 评审出证据）；H3；async 公开 API。
**跨模块纪律**：`net.server.iocp` / `io.reactor.iocp` / `platform` 属跨模块——每波 Land paths 声明 + net 侧 focused 双端 gate；与并行 net/async/io lane 冲突时 Needs Review。
**推荐路径**：`W2-1 → W2-2 → W2-3 → W2-4`

### Wave W2-1 — IOCP 完成驱动 recv 数据路径（第一刀）

| 字段 | 内容 |
|------|------|
| **Status** | **landed**（2026-07-26；TDD RED→GREEN；Wine smoke 3 用例绿 + Linux `test_http_server` 136 绿 + 双端 heaptrc 0 unfreed；缺口注释已缩小为写侧/deadline） |
| **Do** | `net.server.iocp` 增加 completion 驱动的 per-conn 读路径（overlapped `WSARecv` → 协议层喂数据），替换读侧 worker handoff；复用 `io.reactor.iocp` 既有完成端口反应器；threaded 回退路径保留 |
| **Don't** | 不动公开 HTTP API；不改 epoll/Linux 路径；不做写侧（W2-2）；不宣称 scale |
| **Done when** | `test_http_iocp_wine` 覆盖 completion-recv 的 HTTP/1.1 GET wire smoke 绿；源码不再有「no completion-driven per-conn protocol path」注释（或注释缩小为写侧）；Linux 回归绿 |
| **Gates** | Win64 交叉编译 + `test_http_iocp_wine`（`scripts/platform-wine-runtime-smoke.sh` 路径）；`make focused FOCUS=core/tests/nextpas.core.http/test_http_server`（Linux 不回退）；`git diff --check`；`make hygiene` |
| **Land paths** | `core/src/nextpas.core.net.server.iocp.pas`；`core/src/nextpas.core.io.reactor.iocp.pas`（最小）；`core/tests/nextpas.core.http/test_http_iocp_wine/**`；`core/docs/http/**` |
| **风险与兜底** | Wine 对 IOCP 完成语义模拟不全 → 记录差异，smoke 降级为可验证子集，真机验证顺延 W2-3；Wine 环境不可用 → 本波 Blocked，跳 W2-3 或 M-band |
| **Next** | Wave W2-2 |

### Wave W2-2 — IOCP send/drain + keep-alive【landed 2026-07-26】

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **实际方案** | 零字节 `WSASend` 探测被否决（MSDN：立即完成，无 backpressure 信号）；改为 reactor `PollOneWait(timeout)` 三态（dispatched/timeout/woken，GQCS timeout = epoll_wait timeout 对等物）+ server 自有事件循环；writable waiter 1ms timeout 重试喂 `[peWritable]`；单路等待不变式（recv op XOR writable waiter）结构性消灭悬垂回调 |
| **Done 证据** | Wine smoke 5 用例绿（keep-alive 两请求 + 16MB backpressure 慢读端到端）；Linux `test_http_server` 136/136；双端 heaptrc 0 unfreed |
| **Wine 语义差异（重要）** | Wine AFD 模拟对非阻塞 send 的**单次大 buffer 整块吞下**（16MB 一次 send 返回全长，不 WouldBlock）；分块（≤64KB）写在 ~2.6MB 处正确 WSAEWOULDBLOCK。任何依赖 backpressure 的 Wine 测试必须分块写；真机语义（部分写）W2-3 验证 |
| **Next** | Wave W2-3 |

### Wave W2-3 — 真 Windows host CI gate

| 字段 | 内容 |
|------|------|
| **Status** | **landed**（2026-07-26；matrix 增 `http.iocp_wire` 行；**真 Windows 证据已回填**：Core CI run 30195741147 `test-windows-runtime` success——`http.iocp_wire` 5 用例 + 0 unfreed（含 16MB backpressure：真机部分写/WouldBlock 语义下 drain 路径完整工作，Wine 整块吞差异在真机不存在）；matrix summary pass=2/2；CLAIM 72/106 行措辞已更新。Linux/macOS/FreeBSD job 失败为先例（早于本 lane，非 HTTP 引起） |
| **Do** | `core/scripts/http-host-ci-matrix.sh` 增 IOCP 行：Windows host 上 `tsbIocp` wire smoke；Wine 与真机差异 residual 写入 CONTRACT/CLAIM |
| **Don't** | 不在 CI 里跑性能 harness（那是候选战役）；不因 CI 排队阻塞 lane（异步等结果） |
| **Done when** | Windows CI 行绿（或差异 residual 诚实记录并给出堵点报告）；CLAIM「Windows scale=No」措辞随证据更新 |
| **Gates** | host CI matrix + docs hygiene |
| **Land paths** | `core/scripts/http-host-ci-matrix.sh`；`core/docs/http/**`；必要最小测试改动 |
| **风险与兜底** | 无可用 Windows runner → 本波 Blocked 报告（需产品决策 runner 资源），转 M-band |
| **Next** | Wave W2-3b |

### Wave W2-3b — IOCP deadline wake（完成路径生产覆盖）

| 字段 | 内容 |
|------|------|
| **Status** | **landed**（2026-07-26；TDD RED→GREEN；RED：有限 deadline 被 guard 拒绝 → worker fallback（GWorkerRunUsed 断言失败）；GREEN：guard 放宽 + `WakeExpiredDeadlines` 扫描 + `ComputeWaitTimeoutMs` deadline 聚合 + `WakePending`/`TryCancelByContext` 取消唤醒 + 纯 sleeper 合法化；Wine 6 用例绿（idle wake 用例 445ms ≈ 400ms deadline + 派发开销，时序精确）+ Linux `test_http_server` 136 绿 + 双端 heaptrc 0 unfreed。**真机复验**：windows-latest `http.iocp_wire` 6/6 + 0 unfreed，deadline wake 437ms（Core CI run 30196530589）。生产 H1 session（恒有限 WakeDeadline）自此走完成路径） |
| **Do** | ①guard 放宽：接受有限 `WakeDeadline`（保留初始兴趣 =[peReadable] 要求）；②`ComputeWaitTimeoutMs` 聚合最近 deadline（min(writable 1ms, deadline remaining)，epoll `ComputePollTimeoutMs` 对等）；③过期唤醒：writable waiter/纯 sleeper 直接喂 `[]`（epoll `HandleExpiredPollTargets` 契约）；recv-parked driver 经 `TryCancelByContext` + `WakePending` 标志——取消完成到达后喂 `[]`（数据竞先则喂 `[peReadable]`），不破坏单路等待不变式 |
| **Don't** | 不动公开 API；不改 epoll 路径；不动 reactor（`TryCancelByContext` 已存在）；不宣称 scale |
| **Done when** | Wine smoke 增 idle deadline wake 用例（有限 deadline session 走完成路径、idle 超时被 wake 关闭、无 worker Run）绿；Linux 回归绿；双端 heaptrc 0 unfreed |
| **Gates** | 同 W2-1/W2-2（Wine smoke + Linux `test_http_server` + diff --check + hygiene） |
| **Land paths** | `core/src/nextpas.core.net.server.iocp.pas`；`core/tests/nextpas.core.http/test_http_iocp_wine/**`；`core/docs/http/**` |
| **风险与兜底** | Wine 对 `CancelIoEx` 模拟不全 → 差异记录，用例降级为可验证子集（真机 CI matrix 行会自动复验）；连续 3 次 focused 失败 → Blocked 记录转 W2-4 |
| **Next** | Wave W2-4 |

### Wave W2-4 — 评审与宣称对齐

| 字段 | 内容 |
|------|------|
| **Status** | **landed**（2026-07-26；CLAIM @72/@106、CONTRACT §residual（multi-OS host 行 + IOCP 行，v3.47）、GOAL_TREE（Era W2 行）三处对齐 IOCP 真实状态；**Windows 性能 harness 维持候选**——Era W2 已完成、windows-latest runner 可用，但共享 CI runner 性能数字噪声大且候选升格需产品确认（§6 规则）；**Windows scale 宣称维持 No**（wire smoke ≠ scale 证据） |
| **Do** | 评审 W2-1..3b 证据：CLAIM/CONTRACT/GOAL_TREE 对齐 IOCP 真实状态；决定「Windows 性能 harness」是否从候选战役升格；Windows scale 宣称维持 No 除非有同机证据 |
| **Don't** | 无证据升宣称 |
| **Done when** | 文档三处一致；下一战役 NEXT 明确（升格或回 M-band/候选评估） |
| **Gates** | docs + `make hygiene` |
| **Next** | Era W2 收官 → NEXT=M-band（候选战役升格待产品确认，见 §6） |

**Era W2 Done when**：W2-1..W2-4 landed（或 Blocked 波有诚实堵点报告 + 产品决策记录）；Windows 宣称与证据一致。

---

## 5. M-band — 维护带（永续兜底；无需授权）

Era 全堵时的合法工作池。**有界、行为冻结、不扩面**。

| 允许项 | 边界 |
|--------|------|
| doc-truth 对齐 | 文档数字/状态与源码、Makefile、CI 漂移的修正 |
| flake / hang 修复 | 既有 focused suite 的稳定性；不删测试、不 skip 掩盖 |
| heaptrc residual 追查 | 缩小或清零已记录 residual；不吞泄漏 |
| 机械抽取 | 单波 ≤2 单元、行为冻结、focused 双绿（h2/h1 大单元继续瘦身） |
| 测试拆分 / PROJECTS 卫生 | 大 suite 拆 focused；Makefile PROJECTS 同步 |
| bench / comparator 刷新 | 只刷新证据与 caveat，不改宣称 |

**M-band 禁止**：新公开 API 家族；H3 任何实现；宣称升级；为对标扩 API。

---

## 6. 候选战役（未升格；升格需产品确认 + 写满 Do/Don't/Done when/Gates）

| 候选 | 内容 | 解锁条件 |
|------|------|----------|
| **DX / Cookbook** | 消费者视角 cookbook + examples 深化（真实 app 场景走通主路径） | 产品确认优先级 |
| **Windows 性能 harness** | 真 Windows 上 IOCP vs Go 同机比值 | Era W2 完成 + Windows runner 资源 |
| **H3 / QUIC** | QPACK + frame + transport | 独立 QUIC 模块有可链 transport（当前无产品需求） |

---

## 7. 硬约束与硬排除

- 只按本文件有序表推进；`archive/` 不是 backlog。
- **不**扩 API 只为对标清单；**不**把 public handler 改成 async 回调。
- **H3 Blocked**：禁止空 facade（仅 `tls.quic.crypto` 原语存在）。
- **Windows scale 宣称 = No**：直到 W2-4 评审出同机证据。
- 正确性 gate 红 → 性能/重构改动整波回滚。
- 跨模块改动：Land paths 声明 + 双端 gate + 与并行 lane 的 worktree audit。
- 一波 **最多 3 项**；land 后必须回写本文件。

---

## 8. Inbox（未排序；禁止直接做）

规则：只能追加一行想法（主题 + 为何）；**升格**必须移入某 Era 有序表并写满四字段；Agent 不得实现仍停在 Inbox 的条目。

| 想法 | 备注 |
|------|------|
| ~~IOCP deadline wake~~ | 已升格为 Wave W2-3b（2026-07-26，会话 goal 授权） |

---

## 9. 命名对照（middleware）

| 名字 | 含义 |
|------|------|
| `http.middleware` unit | 链原语：`HandlerFunc` / `MiddlewareFunc` / `Chain` |
| `http.middleware.*` | 产品中间件：cors / recovery / logger / … |
| `test_http_middleware` | 链原语 suite |
| `test_http_middlewares` | 产品中间件 suite |

---

## 10. 与其他文档的关系

| 文档 | 角色 |
|------|------|
| **ROADMAP.md（本文件）** | 向前做什么、顺序、状态、Goal Loop |
| **[`CLAIM.md`](CLAIM.md)** | 对外可说什么 / 禁止宣称（数字表冻结处） |
| **[`REPRO.md`](REPRO.md)** | 1h 复现剧本 |
| **GOAL_TREE.md** | 为什么做、阶段定义、不漂移；不维护日更 backlog |
| **CONTRACT.md** | 对外行为契约 |
| **API_COVERAGE.md** | 证据矩阵 |
| **BENCHMARKS.md** | 性能证据与 caveat |
| **[`archive/`](archive/README.md)** | 已完成波次档案（含 2026-07-26 全史快照） |

---

## 11. 变更日志

| 日期 | 变更 |
|------|------|
| 2026-07-26 | **Era P-5 landed**（HPACK 放大炸弹硬 backstop，RFC 7541 §10.5）：`FinalizeHeaders` 的 header-list-size 守卫原被 `if FMaxHeaderListSize > 0` 门控，默认 `MAX_HEADER_LIST_SIZE=0`（RFC「不广播显式上限」的有意姿态）→ 守卫关闭 → ~4KB 压缩块经索引引用（对单个大 dynamic-table 条目的重复 1 字节引用）解码成 ~1.26MB 无界物化（放大 ~315×，且默认 `MAX_CONCURRENT_STREAMS=0` 无并发上限）。新增 `H2_HEADER_LIST_HARD_LIMIT=1MB` 绝对上限（与 `H2_WIRE_READ_HARD_LIMIT=16MB` 同型，独立于软 setting）：size 累计移出软门控、无条件强制，超限 → `h2hfrHeaderListTooLarge` → 431（复用既有 431 通道，软限>0 时取 min）。不变式：64KB 压缩块上限使合法请求解码 ≤~64KB，硬 backstop 只在放大时触发、永不误伤。`test_http_h2_stream` 39 passed（+2：攻击 320 索引引用 / no-harm 普通请求，RED→GREEN，no-harm 经过度激进 mutation(=100) 验证）；h2 全家回归全绿（session 43 含 431 soft 路径、client 72、hpack 30、frame 37、types 23）+ 双端 0 unfreed；CONTRACT v3.51 |
| 2026-07-26 | **Era P-4 landed**（CVE-2024-27316 CONTINUATION flood 连接级升级）：既有 stream 层三重边界（`H2_MAX_HEADER_BLOCK_BYTES=64KB` / `H2_MAX_HEADER_FRAGMENTS=512` / `H2_MAX_EMPTY_FRAGMENTS=64`）已防内存 exhaustion，但 session 层 HandleContinuation/HandleHeaders 只把超限 reset 降级为 RST 单流 + 不清 `FPendingContinuationStreamID` → 连接挂起、1:1 RST 放大。新增 `EscalateHeaderBlockFlood` 助手：stream reset code==ENHANCE_YOUR_CALM（经 33 处 `InternalReset` 审计确认为 header-block flood 唯一信号）→ GOAWAY(EYC) + 关闭 + 清 pending；两处 reset 分支共用。+2 测试（攻击 70 空 CONTINUATION → GOAWAY；no-harm 合法 3 分片 → handler 执行，经过度激进 mutation RED-verify）；43 passed / 0 failed / 0 unfreed；h2 全家 + server 回归全绿；CONTRACT v3.50 |
| 2026-07-26 | **Era P-1/P-2/P-3 landed**（h2 DoS defense family）：**P-1 CVE-2023-44487 rapid-reset**——`FRapidResetCount` 计数 + `H2_MAX_RAPID_RESETS=100` → GOAWAY(ENHANCE_YOUR_CALM)，完成路径清零；+2 测试（攻击 201 resets + 不误伤 198 resets 中间穿插1完成）；**P-2 CVE-2019-9512/9515 control-frame flood**——`FControlFrameFloodCount` + `RegisterControlFrameFlood` helper（PING/SETTINGS flood 共用计数器）→ GOAWAY(EYC)，`H2_MAX_CONTROL_FRAME_FLOOD=100`；+2 测试（攻击 150 PINGs + 不误伤 198 PINGs 中间穿插1完成）；41 passed / 0 failed / 0 unfreed；**P-3 doc-truth**——CONTRACT §6 suites 35→47 + DoS stance 四象限表；CONTRACT v3.49 |
| 2026-07-26 | **M-6 landed**（side suites 健康度补查）：主 gate 47 suites 可信后补查 5 个 Linux 正确性类 side suite（smoke / integration / examples / threaded_host / tls_real——不在 PROJECTS 的验证盲区）：**4 绿 + examples 编译失败 1 处**——`DrainPipePair` 7→9 参数（process lane e252064ba 加 `AMaxTotal`/`ALimited` 输出上限，产品侧 child.pas 已适配、http examples 未跟进；与 M-2 同型「API 演进 side suite 未跟进」腐化）；修：传 `AMaxTotal=0`（不限制，保持原轮询收集语义）+ 局部 `LLimited`；修复后 5/5 绿（examples 5 passed + 0 unfreed）。Wine 3 suite 已有 CI 真机证据、bench 2 harness 非正确性 gate，均不在本刀范围 |
| 2026-07-26 | **M-5 landed**（gate 可信度收口）：(1) **首次可信全量绿**——M-4 后全量 47 suites clean test：**1910 passed / 0 failed / 42 heaptrc 报告全 0 unfreed**（此前「全量绿」被 tail 截断读法证伪：M-1 时实为 8 红被掩盖，M-3 时 239/8）；(2) 聚合 Makefile `test` 目标加失败 suite 汇总（`FAILED SUITES: ...` / `ALL 47 SUITES GREEN` 末尾输出）——中段失败不再可能被日志尾部读法静默归因给最后一个 suite；(3) 假绿模式审计：全 http 测试 `except` 吞异常 10 处——security 为唯一假绿点（M-4 已修），其余 9 处为响应收集 helper（断言基于内容、超时自然失败），无假绿风险 |
| 2026-07-26 | **M-4 landed**（M-band 测试债修复）：`test_http_security` 全部停滞族用例超时语义对齐——41a7e1614（6月8日）引入 ReadTimeout/IdleTimeout 分离（Go 风格：ReadTimeout 管请求内读含 body，IdleTimeout 只管 keep-alive 间隙，见 CONTRACT PD-3-1）时 `test_http_server` 跟进但 security 未跟进：8 个 Expect body 停滞用例（threaded+epoll）只设 IdleTimeout=200 → 停滞归 ReadTimeout=30000 管 → 5s 观察窗永不关 → 诚实 helper 如实红；另 10 个非 Expect 停滞用例的 helper 把 client 读超时误判为 server 关闭 → 假绿掩盖同一问题七周。修：18 用例 IdleTimeout→ReadTimeout + helper 改 `ReadUntilClosedOrDeadline` 诚实区分 + 标识符/label idle-timeout→read-timeout；247/247 绿 + 0 unfreed；实现与契约本来就对，纯测试债；CONTRACT v3.49 |
| 2026-07-26 | **M-3 landed + M-1 真机复验闭环**：CI windows job 编译失败根因=core/src 4 单元 22 处 C 风格赋值操作符（`+=`）依赖宿主 fpc.cfg `-Sc`（GHA runner 无此配置；stage0 亦不支持）——`fpc -n` 镜像 RED 复现后机械展开为 `X := X + Y` 并入 design-conventions「可移植语法约束」；main@7a4145ef2。修复后 Core CI run 30200508397 `test-windows-runtime` success：**PASS `http.iocp_facade` 3 用例（真机 windows-latest，M-1 产品 facade over IOCP 端到端真机证据落地）** + threaded_host/iocp_wire 全 PASS + heaptrc 干净；CLAIM @106 真机占位已回填 |
| 2026-07-26 | **M-2 landed**（M-band 测试债修复）：`test_http_https_redirect`「HTTP to HTTPS redirect」用例语义滞后——写于 client 无 HTTPS 年代（期望 EHttpError unsupported scheme），client HTTPS 化后真跟进 redirect 抛 ESSLException 致 unexpected exception；修：捕 ESSLException/EHttpError 二者 + location 从 example.com 改本地回环防外连；6/6 + 0 unfreed；存量债（与 M-1 无关，全量首次曝光） |
| 2026-07-26 | **M-1 landed**（M-band 证据补强）：`test_http_iocp_facade_wine`——产品 `THttpServer`（full facade）+ `Backend=tsbIocp` 端到端 GET + keep-alive 两连发，Wine 3 用例一次绿 + 0 unfreed；探针发现 CONTRACT @333「full facade Win64 交叉触 TLS 链 FPC internal」residual 已不复现——测试 uses 常驻钉住防回归；host matrix 增 `http.iocp_facade` 第三条目；iocp server guard 注释同步 W2-3b 语义；CONTRACT v3.48；NEXT=M-band |
| 2026-07-26 | **W2-4 landed / Era W2 收官**：CLAIM/CONTRACT(v3.47)/GOAL_TREE 三处对齐 IOCP 真实状态（completion recv/send/deadline-wake + 真机证据）；Windows 性能 harness 维持候选（升格需产品确认）；Windows scale 宣称维持 No；NEXT=M-band |
| 2026-07-26 | **W2-3b landed**：IOCP deadline wake（TDD RED→GREEN）——guard 放宽接受有限 `WakeDeadline`；`ComputeWaitTimeoutMs` 聚合最近 deadline（epoll `ComputePollTimeoutMs` 对等）；`WakeExpiredDeadlines` 扫描：sleeper/writable waiter 直接喂 `[]`，recv-parked 经 `TryCancelByContext`+`WakePending` 延迟到取消完成（数据竞先喂 `[peReadable]`）；纯 sleeper 合法化。Wine 6 用例（idle wake 445ms 时序精确）+ Linux 136 双绿、双端 0 unfreed；生产 H1 session 自此走完成路径；NEXT=W2-4 |
| 2026-07-26 | **W2-3 landed（证据回填）**：Core CI run 30195741147 `test-windows-runtime` success——真 Windows host `http.iocp_wire` 5 用例 + 0 unfreed（含 16MB backpressure 真机部分写语义验证；Wine 整块吞差异真机不存在）；CLAIM 72/106 行措辞更新；Linux/macOS/FreeBSD job 失败为先例非 HTTP 引起；Inbox deadline wake 升格 W2-3b；NEXT=W2-3b |
| 2026-07-26 | **W2-3 wiring landed**：host CI matrix 增 `http.iocp_wire` 行（Windows host 真用例 / 其他 host skip 断言）+ truth 措辞对齐 + 测试头/Makefile truth 层级更新；Linux 本地 matrix pass=2/2；Windows CI run 证据待回填；Inbox 增 deadline wake 候选 |
| 2026-07-26 | **W2-2 landed**：IOCP send/drain——reactor `PollOneWait` 三态 + server 自有 GQCS 事件循环 + writable waiter 1ms timeout 重试；keep-alive 两请求 + 16MB backpressure 用例（RED→GREEN）；发现并记录 Wine 大 buffer send 语义差异（整块吞下不 WouldBlock，须分块写）；Wine 5 用例 + Linux 136 双绿、双端 0 unfreed；NEXT=W2-3 |
| 2026-07-26 | **W2-1 landed**：IOCP completion 驱动 recv——零字节 overlapped `WSARecv` readiness 桥 + poll session reactor 线程 `Advance`；守卫外回退 worker handoff；`test_http_iocp_wine` 增 completion-recv 用例（RED→GREEN）；Linux 回归绿；NEXT=W2-2 |
| 2026-07-26 | **路线图重构**：Era 0–R2 全史（原 1220 行）冻结进 `archive/2026-07-26-roadmap-history-era0-to-r2.md`；本文件精简为单一前进入口；新增反碰壁兜底链（Era → M-band → STOP 报告）；重开前进路线 **Era W2 Windows 生产化 phase-2**，NEXT=W2-1（会话授权） |
| 2026-07-26 | （重构前）h2 monolith extract / settings share / cancel-adapter / client helpers / session extract 等 residual 波全部 landed；详见 archive 快照 changelog |
