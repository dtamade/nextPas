# nextpas.core.http Roadmap

**Authority**: 本文件是 HTTP 模块**向前开发**的唯一执行入口。
**Companion**: 北极星见 `GOAL_TREE.md`；契约见 `CONTRACT.md`；证据矩阵见 `API_COVERAGE.md`。
**Updated**: 2026-07-17（Wave X2 landed → **NEXT = X3**）

---

## 北极星（执行时服从）

把 `nextpas.core.http` 做成 **Free Pascal 一流 HTTP 框架**：

| 支柱 | 含义 |
|------|------|
| **完整** | 生产 client/server 主路径诚实可用；缺口落地或明确 Park |
| **高级** | 协议边角与运维面有证据；无假 facade |
| **优雅** | 小接口、同步公开契约、ownership 清楚、零重复工厂 |
| **高性能** | ladder + focused bench 证据驱动；不对标口号 |

**硬约束**

- 只按本文件有序表推进；`archive/` 不是 backlog。
- 不扩 API 只为对标 Go/Rust 清单（见 GOAL_TREE Do-Not-Drift）。
- 跨模块默认：标 **Blocked** 或不在 http 堆 workaround；**Era 6** 起，为 H1/H2/WS 更好可 **受控** 改 `net`/`tls`（及最小 platform），须在本波 Land paths 声明 + 双端 gate。
- 一波 **最多 3 项**；land 后必须回写本文件。
- 改序 / 升格 Inbox / 改 non-goal：先改本文件，再写代码。
- **无 H3 需求**：Era 5 保持 Blocked；禁止空 facade。

---

## Goal Loop（自治执行；不要等用户说「继续」）

```text
LOOP:
  1. 读本文件「当前该做」→ 唯一 NEXT Wave
  2. 若 NEXT = Blocked → 取表中下一个非 Blocked 且非 parked；若全堵 → STOP 报告
  3. 实现（≤3 项）+ focused gate(s) + git diff --check + make hygiene
  4. path-limited land main
     默认 ALLOW 路径：
       core/src/nextpas.core.http*
       core/tests/nextpas.core.http/**
       core/docs/http/**
       examples/nextpas.core.http/**（若本波触及）
       benchmarks/nextpas.core.http/**（若本波触及）
     跨模块：必须在本波「Land paths」声明，且最小必要
  5. 回写：本 Wave → landed；下一可执行行 → NEXT；changelog 一行
  6. 无用户指令时 goto 1（自动续波）

STOP / ASK（才打断用户）:
  - 改 owner boundary / 新公开 API 家族 / 跨 >2 模块且无先例
  - 同一 Wave 连续 3 次 focused 失败
  - Inbox 条目缺 Done when 却被要求实现
  - force-push、破坏性 git、动 main 治理策略

CHECKPOINT（不阻塞续波）:
  - 每 land 一波：一行 Ready（wave / HEAD / gates / next）
  - Era 边界（0→1、1→2…）：可多写三行摘要，仍自动进入下一 Era 首波
```

**自治强度**：满自治。默认连续执行推荐路径，只在 STOP 条件停下。

---

## 现在在哪

| 层 | 状态 |
|----|------|
| G0–G5 模块骨架 | 完成 |
| non-H3 stage-complete | 完成（P1–P5；H3 诚实 blocked） |
| Usability Wave A–F | 完成 landed main |
| Wave G Cookie site | 完成（eTLD+1 + PSL 子集） |
| Wave H Response metadata | 完成（FinalUrl + Version） |
| Wave I Proxy auth | 完成（Basic only freeze；Digest/NTLM Park） |
| Wave J Error Op hygiene | 完成（热点 CreateOp + source-contract + CONTRACT Op 表） |
| Wave K Surface freeze | 完成（工厂白名单已冻；无 deprecated；ARCHITECTURE 对齐） |
| Wave L′ Doc dual-status | 完成（GOAL_TREE/API_COVERAGE/README 无 NEXT Wave 双写） |
| Wave C1 Content-Encoding | 完成（client decode helper + server middleware 契约 + Op=`content_encoding`） |
| Wave C2 Conditional | 完成（If-None-Match/If-Modified-Since helper + ServeFile 304；ParseHttpDate/mtime 秒修复） |
| Wave C3 Range + static | 完成（单段 Range/206/416、`Accept-Ranges`、流式 source-contract） |
| Wave E1 Error taxonomy | 完成（Kind 分类表 + Op 对齐；公开面无裸 EArgumentError；source-contract） |
| Wave E2 Options/decorator | 完成（With* 链语义表；外层胜；Timeout/ConnectTimeout/Production 分界） |
| Wave A1 H2 production edges | 完成（GOAWAY mid-response + 池/多路/流控边角表 + residual 诚实） |
| Wave A2 Client pool | 完成（per-authority MaxPoolSize + idle clear + H1/H2 选择策略 CONTRACT） |
| Wave P1 Profile hotspot | 完成（headers Get/Has fuse；Get miss ~17% 本机 micro） |
| Wave P3 epoll vs threaded | 完成（fullchain Direct/Router 同 workload 本机 snapshot + caveat） |
| Wave P5 G6 closure | 完成（stage performance complete 标准 + GOAL_TREE/BENCHMARKS 对齐） |
| framework-complete (non-H3) | **yes**（Era 0–4）；H3 仍 Blocked / 无产品需求 |
| Wave X0 Excellence open | 完成（Era 6 表 + 推荐路径 + residual 可主动消除声明） |
| Wave X1 WS production contract | 完成（lifecycle 表 + close/cancel Op focused；heaptrc 0） |
| Wave X2 net cancel floor | 完成（waitable socketpair+poll 唤醒；SLA ~20ms；probe-only ~10ms slice） |
| **下一执行点** | **Wave X3** — Client pool idle TTL |

四支柱粗进度（执行中随 Era 更新，非 KPI）：

```text
完整 ~92%   高级 ~82%   优雅 ~86%   性能 ~70%  (Excellence: H1/H2/WS)
```

---

## 已完成（压缩）

| 标记 | 内容 |
|------|------|
| Stage | INV-12 keep-alive；H2 facade live；API 审计；bench 诚实；H3 无假 facade |
| Wave A–B | WS budget/cancel；live dial/cancel；CONTRACT 真相 |
| Wave C | GetJson ensure+decode；429 + delta Retry-After |
| Wave D | HTTPS CONNECT via HTTP proxy |
| Wave E | H1 direct HTTPS；ProxyUrl Basic |
| Wave F | HTTP-date Retry-After；WithTLSContext；Post/Put/PatchJsonDocument |
| Wave G | Cookie eTLD+1 SiteKey；multi-label PSL 子集；拒绝 Domain=public-suffix |
| Wave H | `IHttpResponse.FinalUrl` + `Version` |
| Wave I | Proxy auth 冻结 Basic only；CONNECT 407 诚实错误 |

详细证据：[`archive/`](archive/README.md)、`API_COVERAGE.md`。

---

## 推荐默认执行路径（goal 默认跟这条）

```text
Era 0–4:  landed（framework-complete non-H3）
Era 5:    H3-* Blocked — 跳过（无产品需求；禁止空 facade）
Era 6:    X0 → X1 → X2 → X3 → X4 → X5   （H1/H2/WS 精品 + 跨模块反哺）
```

---

## Era 0 — Close the runway

**目标**：收干净 product depth 与文档双入口，再进入完整度建设。

### Wave J — Error Op hygiene

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | 热点路径补齐 `CreateOp`：client `Send` / redirect / retry / H1 `RoundTrip` 边界；source-contract 锁定 Op 集合或关键名 |
| **Don't** | 全模块 Op-everywhere；改错误分类语义（那是 E1） |
| **Done when** | 上述热点失败路径带稳定 Op；新增/更新 focused 或 source-contract 证明；heaptrc 敏感 gate 仍 `0 unfreed`（若适用） |
| **Gates** | `make focused FOCUS=core/tests/nextpas.core.http/test_http_client`（及本波触及的 H1/contract/source-contract suite） |
| **Land paths** | `core/src/nextpas.core.http*`；相关 tests；`core/docs/http/*` |
| **Next** | Wave K |
| **Evidence** | `test_http_client` 251 passed；`test_http_base` 32 passed；Op 表：`redirect`/`round_trip`/`transport`/`connect`/`cancel`/`ensure`/`download`/`json` |

### Wave K — Surface freeze audit

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | 扫 facade / message 工厂：无残留 deprecated 死面；tests/examples 只走 `THttpRequestBuilder` + 白名单 `NewRequest`/`NewGetRequest`；删无引用死入口 |
| **Don't** | 新公开 API 家族；大范围重命名 |
| **Done when** | 无生产 deprecated 请求工厂；examples/tests 编译路径干净；CONTRACT/README 与源码一致 |
| **Gates** | `test_http_contract` + `test_http_examples`（或本波触及 suite）+ `make hygiene` |
| **Land paths** | http 源/测/文档/examples |
| **Next** | Wave L′ |
| **Evidence** | 白名单仅 `NewRequest(Method,TUrl|string)`+`NewGetRequest`；`NewStreamingRequest`/多参已删除；contract 31p + examples 5p；ARCHITECTURE 去 stale deprecated 叙述 |

### Wave L′ — Doc dual-status kill

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | GOAL_TREE / API_COVERAGE / README 顶部只保留「NEXT → ROADMAP」指针；去掉与 ROADMAP 重复的下一执行点双写；archive 索引不膨胀 |
| **Don't** | 重写历史叙事；把 archive 当 backlog |
| **Done when** | 全局搜「下一执行点」仅 ROADMAP 有权威表；GOAL_TREE Current Position 一行指针 |
| **Gates** | docs-only：`git diff --check`；可选 hygiene |
| **Land paths** | `core/docs/http/**` |
| **Next** | Wave C1 |
| **Evidence** | GOAL_TREE/API_COVERAGE/README 不写具体 NEXT Wave；「下一执行点」仅 ROADMAP |

**Era 0 Done when**：J/K/L′ 均为 landed；全库只有一个 NEXT 权威。 **Met.**

---

## Era 1 — Completeness（完整）

**目标**：生产常见能力「要么有、要么诚实不说有」。

### Wave C1 — Content-Encoding

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | client/server 侧 gzip（优先）编解码契约：middleware 或 content 辅助；自动/显式 decode 写进 CONTRACT；focused 证明 |
| **Don't** | 自研压缩核（优先用已有 core 能力；若无原语则 **最小** 引入或 Blocked 升级底层）；伪装完整浏览器 content 栈；默认 br 除非底层已有 |
| **Done when** | 至少 gzip 请求或响应路径一条生产可用；非法/不支持编码诚实错误；CONTRACT + focused |
| **Gates** | 新或扩展 focused suite + client/server 相关 gate |
| **Land paths** | http 源/测/文档；（若必须）声明的压缩/底层最小路径 |
| **Next** | Wave C2 |
| **Evidence** | server：`CompressionMiddleware`/`DecompressMiddleware`；client：`HttpDecodeContentEncoding` + `HttpReadResponseBody*Decoded`；raw helpers 不自动解；Op=`content_encoding`；`test_http_client` + `test_http_middlewares` |

### Wave C2 — Conditional + cache helpers

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | `ETag` / `If-None-Match` / `If-Modified-Since` 辅助与 304 路径；静态 `ServeFile` 可接条件请求 |
| **Don't** | 完整 HTTP cache 实现、启发式缓存策略框架 |
| **Done when** | 条件请求最小正确面 focused；CONTRACT 有行为表 |
| **Gates** | static + message/client 相关 focused |
| **Next** | Wave C3 |
| **Evidence** | `HttpMakeStrongETag`/`HttpIfNoneMatchMatches`/`HttpNotModifiedSince`/`HttpTryWriteNotModified`；mtime ns→s；ParseHttpDate fix；`test_http_static` 26 |

### Wave C3 — Range + static depth

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | `ServeFile`/`ServeDir`：`Range` / `Accept-Ranges`、大文件流式、越界 416 |
| **Don't** | 变成 CDN/静态站框架；目录列表产品化 |
| **Done when** | Range 单段 focused；大文件不整文件进内存（契约写明） |
| **Gates** | `test_http_static` 扩展 |
| **Next** | Wave E1（推荐路径跳过 C4/C5，除非 Inbox 升格） |
| **Evidence** | 单段/open-ended/suffix 206；越界+multi 416；`Accept-Ranges: bytes`；`CopyFileRange`/`io.Copy` source-contract；CONTRACT 表 |

### Wave C4 — Multipart / stream 收口（非默认；Inbox 升格）

| 字段 | 内容 |
|------|------|
| **Status** | parked until Inbox promote |
| **Do** | 大 body 流式 multipart、response stream 与 CONTRACT ownership 对齐 |
| **Don't** | 第二套 body API |

### Wave C5 — SSE 诚实毕业（非默认；Inbox 升格）

| 字段 | 内容 |
|------|------|
| **Status** | parked until Inbox promote |
| **Do** | SSE 写端 + 超时/cancel 检查点；文档化限制 |
| **Don't** | 伪 realtime 总线 |

**Era 1 Done when**：C1–C3 landed；C4/C5 要么 landed 要么仍明确 parked。 **Met**（C4/C5 parked）。

---

## Era 2 — Elegance（优雅）

**目标**：主路径读起来像一个作者写的。

### Wave E1 — Error taxonomy

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | `hek*` + Op 命名表写入 CONTRACT；公开面禁止裸 `EArgumentError` 漏出；与 Wave J Op 对齐 |
| **Don't** | 无证据大翻异常层次 |
| **Done when** | CONTRACT 有分类表；source-contract 或 focused 锁关键公开路径 |
| **Gates** | contract + client + 本波触及 suite |
| **Next** | Wave E2 |
| **Evidence** | CONTRACT Kind 分类表 + Op 表；`HttpUseRequestArena`→hekArgument；decompress 包装裸 EArgumentError；contract/client source-contract；`test_http_base` CreateOp taxonomy |

### Wave E2 — Options / decorator 一致

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | `With*` 链语义表（覆盖、组合、生产默认 vs 测试默认）；钉死 `Timeout`/`ConnectTimeout`/`Production` 分界 |
| **Don't** | 新 decorator 家族「凑齐对称」 |
| **Done when** | CONTRACT/README 一张表；测试覆盖组合边角至少一组 |
| **Gates** | client + contract |
| **Next** | Wave A1 |
| **Evidence** | CONTRACT With* 表；decorator 外层胜；Production/ConnectTimeout tests；client combo + contract source-contract |

### Wave E3–E5（低优先 / 按需）

| Wave | 主题 | 状态 |
|------|------|------|
| E3 | Message model 精炼（投影路径无重复语义） | parked until demand |
| E4 | Middleware suite 纪律（不膨胀全家桶） | parked until demand |
| E5 | Dual-compiler / facade 卫生扫尾 | parked until demand |

**Era 2 Done when**：E1–E2 landed；新人只读 README+CONTRACT 能走通主路径。 **Met.**

---

## Era 3 — Advanced（高级）

**目标**：H2/运维深度；**默认不碰 H3**。

### Wave A1 — H2 production edges

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | 流控边角、GOAWAY 消费、池与多路表征；**有失败证据或明确缺口再改** |
| **Don't** | 无证据重写 session；开启 server push |
| **Done when** | 选定边角 focused 证明或文档诚实 residual；无假 claim |
| **Gates** | H2 client/session 相关 suites |
| **Next** | Wave A2 |
| **Evidence** | CONTRACT H2 production edges 表；mid-response GOAWAY→hekProtocol focused；IsReusable/ENABLE_PUSH source-contract；session 37 + client 66 |

### Wave A2 — Client pool sophistication

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | 空闲清理、按 authority 池限、H1/H2 选择策略文档化 + 必要代码 |
| **Don't** | 完整服务发现 / LB |
| **Done when** | CONTRACT 有池语义；focused 覆盖至少 idle clear + 上限行为 |
| **Gates** | client + H1/H2 client |
| **Next** | Wave P1 |
| **Evidence** | CONTRACT pool + H1/H2 选择表；MaxPoolSize per-authority（H1/H2）；CloseIdle + client 267 / h2_client 66 |

### Wave A3+（默认 parked）

| Wave | 主题 | 状态 |
|------|------|------|
| A3 | Observability hooks（最小 seam） | parked until demand |
| A4 | H2 CONNECT / WS-over-H2 | parked until real consumer |
| A5 | Trailer / Expect client 扩展 | parked until demand |

**Era 3 Done when**：A1–A2 landed；其余 parked 有一句话理由。

---

## Era 4 — Performance（高性能）

**目标**：G6 收成可复现证据，不是排行榜文案。
**规则**：正确性回归不过 → 性能改动整波回滚。

### Wave P1 — Profile one hotspot

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | 只动一个 L1/L2 热点（parser materialize / header / writer / drain 择一）；前后有 bench 或 micro 证据 |
| **Don't** | 同时改多个热点；为数字加假 API |
| **Done when** | 单热点有前后数据 + 相关 correctness gate 绿 |
| **Gates** | 相关 micro/fullchain + 正确性 suite |
| **Next** | Wave P3 |
| **Evidence** | headers Get/Has 单次 validate+normalize；Get miss 98.5→81.5 ns；`bench_headers` + `test_http_headers` 28；BENCHMARKS P1 节 |

### Wave P3 — epoll vs threaded 表征

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | 同 workload 对照；诚实 caveat 写入 `BENCHMARKS.md` |
| **Don't** | 宣称跨机器排名 |
| **Done when** | BENCHMARKS 有可复现命令 + 一次本地 snapshot 表 |
| **Gates** | bench 脚本可跑；docs 更新 |
| **Next** | Wave P5 |
| **Evidence** | BENCHMARKS P3 节；Direct/Router × threaded/epoll；bench_fullchain 可复现 env |

### Wave P5 — G6 closure criteria

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | 定义并满足「stage performance complete」：ladder 可跑、无假 claim、GOAL_TREE G6 与 BENCHMARKS 对齐 |
| **Don't** | 无限采集 ranking 表 |
| **Done when** | G6 退出「ongoing 无标准」；标准写进 GOAL_TREE + BENCHMARKS |
| **Gates** | docs + 既有 bench smoke |
| **Next** | Era 5 检查；若 H3 仍 Blocked → 模块 goal 可标 **framework-complete (non-H3)** 并 STOP 或转 Inbox |
| **Evidence** | GOAL_TREE G6 stage-closed 表（8 条）；BENCHMARKS P5 入口；P1/P3 证据链；H3 仍 Blocked |

### Wave P2 / P4（夹在路径外，按需）

| Wave | 主题 | 状态 |
|------|------|------|
| P2 | Arena / zero-copy 边界强化 | queued after P1 if evidence says so |
| P4 | Go/Rust comparator refresh | can merge into P3/P5 |

**Era 4 Done when**：P1 + P3 + P5 landed。

---

## Era 5 — Protocol future（H3）

| Wave | 状态 | 解锁条件 |
|------|------|----------|
| H3-0 | **Blocked** | 独立 QUIC 模块有可链 transport |
| H3-1 | queued after unblock | QPACK + frame + client RoundTrip 最小 |
| H3-2 | later | server session + ALPN + registry 统一 |

goal 遇到 H3-*：**标记 Blocked，跳过取下一可做 Wave**；禁止空转实现假 facade。
**产品立场（2026-07-17）**：当前 **无 H3 需求**；Excellence 专注 H1/H2/WS。

---

## Era 6 — Excellence（H1/H2/WS 精品 + 跨模块反哺）

**目标**：在 framework-complete (non-H3) 之上，把 H1/H2 client/server 与 WebSocket 打成 **可对标 Go/Rust 的选定维度胜利**（正确性、可预测性、证据型性能、Pascal 一流 API）——**不是**协议军备 / 清单扩 API。

**跨模块授权**：本时代为消除 http residual，可最小改 `net` / `tls`（及必要 `platform`）；每波 Land paths 声明；双端 focused；Ready 单列 cross-module。

**对标维度（非 API 清单）**：正确性边角可证；Kind/Op/池/超时可预测；同机 harness 性能证据；小接口同步契约。

### Wave X0 — Open Excellence era（docs）

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | 写本 Era 有序表；推荐路径 X0→X5；GOAL_TREE/CONTRACT residual 声明可主动消除；H3 保持 Blocked |
| **Don't** | 改业务代码；开 H3 |
| **Done when** | 全局 NEXT 唯一指向 X1；执行者只读本文件可开工 |
| **Gates** | `git diff --check`；`make hygiene` |
| **Land paths** | `core/docs/http/**` |
| **Next** | Wave X1 |
| **Evidence** | ROADMAP Era 6；GOAL_TREE Excellence 指针；CONTRACT residual 表 |

### Wave X1 — WebSocket 生产契约收口

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | CONTRACT WS 生命周期表（Open/Read-Write/Ping/Close/`IsOpen`/重复 Close/错误 Kind-Op）；生产边角 focused（双向 Close 后读写、cancel→`hekCanceled`、upgrade 所有权）；GOAL_TREE G5 / API_COVERAGE 毕业证据（不扩扩展族） |
| **Don't** | WS-over-H2；permessage-deflate / 子协议全家桶；新 Options 家族 |
| **Done when** | CONTRACT 有生命周期表；`test_http_websocket` + `test_http_websocket_client` 全绿；WS 路径 heaptrc 0 unfreed；文档不再仅写「未证明 helper」 |
| **Gates** | `make focused FOCUS=core/tests/nextpas.core.http/test_http_websocket`；`…/test_http_websocket_client`；`git diff --check`；`make hygiene` |
| **Land paths** | `core/src/nextpas.core.http.websocket.pas`；facade 若触及；`core/tests/nextpas.core.http/test_http_websocket*/**`；`core/docs/http/**` |
| **Next** | Wave X2 |
| **Evidence** | CONTRACT §2.2.3c lifecycle；client 8 pass（含 close lifecycle + cancel Op=`cancel`）；server 38 pass；两边 heaptrc 0 unfreed |

### Wave X2 — net cancel 地板（跨模块）

| 字段 | 内容 |
|------|------|
| **Status** | **landed** |
| **Do** | 降低/替代 `NET_IO_CANCEL_SLICE_MS=50` 轮询；Linux 优先可唤醒阻塞读（poll+eventfd/pipe 或等价）；保持 `INetCancelToken`/`ECancelledError` 语义；CONTRACT 更新；http client + WS cancel 回归 |
| **Don't** | 重写 async runtime；无证据改 epoll server 模型；为 Windows 完美对等拖死主路径（可 Linux 证明 + 其它 OS residual） |
| **Done when** | cancel 唤醒 SLA 有 focused 证据（显著优于 50ms 切片模型或诚实新 residual）；client/WS cancel 绿 |
| **Gates** | net 相关 focused（实现时点名）；`test_http_client`；`test_http_websocket_client`；hygiene；diff --check |
| **Land paths** | `core/src/nextpas.core.net*`（最小）；必要时 `core/src/nextpas.core.platform*`（最小）；`core/tests/nextpas.core.net/**`；http tests/docs |
| **Next** | Wave X3 |
| **Risk** | 并行 lane `core-net-async-io`：改前 worktree audit；冲突则 Needs Review |
| **Evidence** | `NewNetCancelToken` + `INetCancelWaitable`；`platform_socket_poll_or_wake`；TCP WaitIO；HTTP `THttpCancelToken` 组合 waitable；`test_net` 24 pass（wake SLA 20ms）；client 267 / WS client 8；Windows socketpair residual 诚实 |

### Wave X3 — Client pool idle TTL

| 字段 | 内容 |
|------|------|
| **Status** | **NEXT** |
| **Do** | 墙钟 idle TTL（对齐 options / With* 外层胜）；借出/归还淘汰过期 idle；与 per-authority `MaxPoolSize` 一致；focused + CONTRACT pool 表 |
| **Don't** | 全局跨 host 连接上限；主动 HTTP 健康探测（除非另升格） |
| **Done when** | 过期不复用、未过期复用、`CloseIdleConnections` 仍全清 有测；CONTRACT 去掉「无 idle TTL」residual 或改写为可配置 |
| **Gates** | `test_http_client`；`test_http_h2_client`；hygiene；diff --check |
| **Land paths** | http client / H1 / H2 pool 实现 + tests + `core/docs/http/**` |
| **Next** | Wave X4 |

### Wave X4 — TLS OpenSSL residual（跨模块）

| 字段 | 内容 |
|------|------|
| **Status** | queued after X3 |
| **Do** | 收敛 factory/`CreateContext` heaptrc unfreed（owner=tls）；http HTTPS/H2/`tls_real` 回归；缩小 CONTRACT residual claim |
| **Don't** | 换 TLS 后端；在 http 吞泄漏；清无关全库泄漏 |
| **Done when** | client HTTPS 路径 0 unfreed **或** residual 缩到明确子路径 + 证据 |
| **Gates** | tls 相关 focused；`test_http_client`；`test_http_tls_real`（若存在）；hygiene |
| **Land paths** | `core/src/nextpas.core.tls*`（最小）+ tests；http docs residual |
| **Next** | Wave X5 |

### Wave X5 — Comparator + profiled win

| 字段 | 内容 |
|------|------|
| **Status** | queued after X4 |
| **Do** | 刷新 BENCHMARKS / server comparison 本机 snapshot + caveats；profile 一刀可解释优化（可回落 net/tls/http）；对标 Go/Rust 同负载表述 |
| **Don't** | 为数字牺牲正确性；无 profile 乱优化；假 H3 行 |
| **Done when** | BENCHMARKS 有 Excellence 一行证据；正确性 focused 不回退 |
| **Gates** | 相关 bench 可跑；http 核心 focused 抽样；hygiene |
| **Land paths** | benches/docs + 必要 src；跨模块仅当 profile 证明 |
| **Next** | Era 6 Done / STOP 或 Inbox |

**Era 6 Done when**：X0–X5 landed（或 X5 证据充分且剩余诚实 Park）；H3 仍无 facade；四支柱可再评估。

---

## Era X — Explicit non-goals & residuals

| 项 | 立场 |
|----|------|
| server `Default` RW=0 | **Keep**（测试兼容）；生产用 `THttpServerOptions.Production` |
| cancel ~50 ms 切片 | **X2 landed**：waitable token 近即时唤醒；probe-only 退回 ~10ms slice；Windows 无 socketpair 时 residual |
| OpenSSL factory unfreed | **tls residual**；**Era 6 X4** 授权在 tls 收敛；http 不单独清零宣称 |
| pool 无 idle TTL | **当前 residual**；**Era 6 X3** 消除 |
| JSON dual raw vs ensure-string | **Keep** 三层模型 |
| Digest / NTLM / Negotiate proxy auth | **Park**（Wave I） |
| 完整企业代理栈 | **Park** 除非真实 consumer |
| SOCKS proxy | **Park**（更偏 net） |
| Server push | **Non-goal**（ENABLE_PUSH=0） |
| h2c Upgrade | **Park**（cleartext H2 = prior knowledge only） |
| H2 同连接多路 RoundTrip API | **Park**（新公开面；另设计） |
| WS-over-H2 / H2 CONNECT | **Park** until real consumer |
| H3 / QUIC | **Blocked / 无产品需求**；禁止空 facade |
| 为对标而扩 API | **禁止** |

---

## Inbox（未排序；禁止直接做）

规则：

1. 只能追加一行想法（主题 + 为何）。
2. **升格**必须：移入某 Era 有序表 + 写满 Do/Don't/Done when/Gates + 改推荐路径（若插队）。
3. Agent **不得**实现仍停在 Inbox 的条目。

| 想法 | 备注 |
|------|------|
| H2 同连接多路并发 API | 需独立设计 Wave；非默认路径 |
| WS 扩展协商（permessage-deflate 等） | 仅真实 consumer 升格 |
| pool 主动健康探测 | 可在 idle TTL 之后 |

---

## 当前该做（给执行者 / goal）

```text
1. Era 0–4 landed；framework-complete (non-H3) 已立住
2. Era 5 H3-* Blocked — 跳过；无产品需求；禁止空 facade
3. Era 6 NEXT = Wave X3（pool idle TTL）；之后 X4→X5
4. 跨模块仅按本波 Land paths；不要用 archive/ 当 backlog
```

**没有用户指令时：执行 Era 6 推荐路径（X3…），不要空转 H3。**

---

## 与其他文档的关系

| 文档 | 角色 |
|------|------|
| **ROADMAP.md（本文件）** | 向前做什么、顺序、状态、Goal Loop |
| **GOAL_TREE.md** | 为什么做、阶段定义、不漂移；**不**维护日更 backlog |
| **CONTRACT.md** | 对外行为契约 |
| **API_COVERAGE.md** | 证据矩阵 |
| **BENCHMARKS.md** | 性能证据与 caveat |
| **[`archive/`](archive/README.md)** | 已完成波次档案 |

---

## 变更日志

| 日期 | 变更 |
|------|------|
| 2026-07-17 | 初版：合并 stage + Wave A–F；Phase P/Q/R/X；Wave G = NEXT |
| 2026-07-17 | Wave L：历史 docs → `archive/` |
| 2026-07-17 | Wave G landed；Wave H = NEXT |
| 2026-07-17 | Wave H landed；Wave I = NEXT |
| 2026-07-17 | Wave I landed；Wave J = NEXT |
| 2026-07-17 | **完整时代表**：Era 0–5 + X；Goal Loop 满自治；Inbox；每波 Done when/Gates；推荐路径 J→K→L′→C1→C2→C3→E1→E2→A1→A2→P1→P3→P5 |
| 2026-07-17 | Wave J landed：热点 CreateOp（cancel/ensure/connect/transport…）+ source-contract；Wave K = NEXT |
| 2026-07-17 | Wave K landed：surface freeze 审计 + ARCHITECTURE 对齐 + contract 锁无 deprecated |
| 2026-07-17 | Wave L′ landed：doc dual-status kill；Era 0 完成；Wave C1 = NEXT |
| 2026-07-17 | Wave C1 landed：client Content-Encoding decode + CONTRACT；Wave C2 = NEXT |
| 2026-07-17 | Wave C2 landed：条件请求 helper + IMS/ParseHttpDate 修复；Wave C3 = NEXT |
| 2026-07-17 | Wave C3 landed：Range/`Accept-Ranges`/流式契约；Era 1 完成；Wave E1 = NEXT |
| 2026-07-17 | Wave E1 landed：Kind 分类表 + 公开面无裸 EArgumentError + Op source-contract；Wave E2 = NEXT |
| 2026-07-17 | Wave E2 landed：With* 链语义表 + 外层胜 + Timeout/ConnectTimeout/Production；Era 2 完成；Wave A1 = NEXT |
| 2026-07-17 | Wave A1 landed：H2 production edges 表 + mid-response GOAWAY focused；Wave A2 = NEXT |
| 2026-07-17 | Wave A2 landed：per-authority MaxPoolSize + idle clear + H1/H2 选择策略；Era 3 完成；Wave P1 = NEXT |
| 2026-07-17 | Wave P1 landed：headers Get/Has fuse（Get miss ~17% 本机）；BENCHMARKS 前后表；Wave P3 = NEXT |
| 2026-07-17 | Wave P3 landed：fullchain Direct/Router × threaded/epoll 本机 snapshot + caveats；Wave P5 = NEXT |
| 2026-07-17 | Wave P5 landed：G6 stage performance complete；**framework-complete (non-H3)**；H3 Blocked STOP |
| 2026-07-17 | **Era 6 Excellence** 开启（X0）：H1/H2/WS 精品路径 X1→X5；跨模块 net/tls 受控授权；H3 仍无需求；Wave X1 = NEXT |
| 2026-07-17 | Wave X1 landed：WS lifecycle 表 + close/cancel Op focused；Wave X2 = NEXT |
| 2026-07-17 | Wave X2 landed：net waitable cancel（socketpair+poll）+ SLA；Wave X3 = NEXT |
