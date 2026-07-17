# nextpas.core.http Roadmap

**Authority**: 本文件是 HTTP 模块**向前开发**的唯一执行入口。
**Companion**: 北极星见 `GOAL_TREE.md`；契约见 `CONTRACT.md`；证据矩阵见 `API_COVERAGE.md`。
**Updated**: 2026-07-17（Wave J Error Op hygiene landed）

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
- 跨模块问题标 **Blocked**，不在 http 堆 workaround。
- 一波 **最多 3 项**；land 后必须回写本文件。
- 改序 / 升格 Inbox / 改 non-goal：先改本文件，再写代码。

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
| **下一执行点** | **Era 0 / Wave L′ — Doc dual-status kill** |

四支柱粗进度（执行中随 Era 更新，非 KPI）：

```text
完整 ~80%   高级 ~60%   优雅 ~70%   性能 ~50%
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
Era 0:  J → K → L′
Era 1:  C1 → C2 → C3   （C4/C5 仅 Inbox 升格后）
Era 2:  E1 → E2
Era 3:  A1 → A2         （A3+ 默认 parked / 低优先）
Era 4:  P1 → P3 → P5
Era 5:  H3-* Blocked until QUIC — 跳过，不空转
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
| **Status** | **NEXT** |
| **Do** | GOAL_TREE / API_COVERAGE / README 顶部只保留「NEXT → ROADMAP Wave X」指针；去掉与 ROADMAP 重复的下一执行点双写；archive 索引不膨胀 |
| **Don't** | 重写历史叙事；把 archive 当 backlog |
| **Done when** | 全局搜「下一执行点」仅 ROADMAP 有权威表；GOAL_TREE Current Position 一行指针 |
| **Gates** | docs-only：`git diff --check`；可选 hygiene |
| **Land paths** | `core/docs/http/**` |
| **Next** | Wave C1 |

**Era 0 Done when**：J/K/L′ 均为 landed；全库只有一个 NEXT 权威。

---

## Era 1 — Completeness（完整）

**目标**：生产常见能力「要么有、要么诚实不说有」。

### Wave C1 — Content-Encoding

| 字段 | 内容 |
|------|------|
| **Status** | queued |
| **Do** | client/server 侧 gzip（优先）编解码契约：middleware 或 content 辅助；自动/显式 decode 写进 CONTRACT；focused 证明 |
| **Don't** | 自研压缩核（优先用已有 core 能力；若无原语则 **最小** 引入或 Blocked 升级底层）；伪装完整浏览器 content 栈；默认 br 除非底层已有 |
| **Done when** | 至少 gzip 请求或响应路径一条生产可用；非法/不支持编码诚实错误；CONTRACT + focused |
| **Gates** | 新或扩展 focused suite + client/server 相关 gate |
| **Land paths** | http 源/测/文档；（若必须）声明的压缩/底层最小路径 |
| **Next** | Wave C2 |

### Wave C2 — Conditional + cache helpers

| 字段 | 内容 |
|------|------|
| **Status** | queued |
| **Do** | `ETag` / `If-None-Match` / `If-Modified-Since` 辅助与 304 路径；静态 `ServeFile` 可接条件请求 |
| **Don't** | 完整 HTTP cache 实现、启发式缓存策略框架 |
| **Done when** | 条件请求最小正确面 focused；CONTRACT 有行为表 |
| **Gates** | static + message/client 相关 focused |
| **Next** | Wave C3 |

### Wave C3 — Range + static depth

| 字段 | 内容 |
|------|------|
| **Status** | queued |
| **Do** | `ServeFile`/`ServeDir`：`Range` / `Accept-Ranges`、大文件流式、越界 416 |
| **Don't** | 变成 CDN/静态站框架；目录列表产品化 |
| **Done when** | Range 单段 focused；大文件不整文件进内存（契约写明） |
| **Gates** | `test_http_static` 扩展 |
| **Next** | Wave E1（推荐路径跳过 C4/C5，除非 Inbox 升格） |

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

**Era 1 Done when**：C1–C3 landed；C4/C5 要么 landed 要么仍明确 parked。

---

## Era 2 — Elegance（优雅）

**目标**：主路径读起来像一个作者写的。

### Wave E1 — Error taxonomy

| 字段 | 内容 |
|------|------|
| **Status** | queued |
| **Do** | `hek*` + Op 命名表写入 CONTRACT；公开面禁止裸 `EArgumentError` 漏出；与 Wave J Op 对齐 |
| **Don't** | 无证据大翻异常层次 |
| **Done when** | CONTRACT 有分类表；source-contract 或 focused 锁关键公开路径 |
| **Gates** | contract + client + 本波触及 suite |
| **Next** | Wave E2 |

### Wave E2 — Options / decorator 一致

| 字段 | 内容 |
|------|------|
| **Status** | queued |
| **Do** | `With*` 链语义表（覆盖、组合、生产默认 vs 测试默认）；钉死 `Timeout`/`ConnectTimeout`/`Production` 分界 |
| **Don't** | 新 decorator 家族「凑齐对称」 |
| **Done when** | CONTRACT/README 一张表；测试覆盖组合边角至少一组 |
| **Gates** | client + contract |
| **Next** | Wave A1 |

### Wave E3–E5（低优先 / 按需）

| Wave | 主题 | 状态 |
|------|------|------|
| E3 | Message model 精炼（投影路径无重复语义） | parked until demand |
| E4 | Middleware suite 纪律（不膨胀全家桶） | parked until demand |
| E5 | Dual-compiler / facade 卫生扫尾 | parked until demand |

**Era 2 Done when**：E1–E2 landed；新人只读 README+CONTRACT 能走通主路径。

---

## Era 3 — Advanced（高级）

**目标**：H2/运维深度；**默认不碰 H3**。

### Wave A1 — H2 production edges

| 字段 | 内容 |
|------|------|
| **Status** | queued |
| **Do** | 流控边角、GOAWAY 消费、池与多路表征；**有失败证据或明确缺口再改** |
| **Don't** | 无证据重写 session；开启 server push |
| **Done when** | 选定边角 focused 证明或文档诚实 residual；无假 claim |
| **Gates** | H2 client/session 相关 suites |
| **Next** | Wave A2 |

### Wave A2 — Client pool sophistication

| 字段 | 内容 |
|------|------|
| **Status** | queued |
| **Do** | 空闲清理、按 authority 池限、H1/H2 选择策略文档化 + 必要代码 |
| **Don't** | 完整服务发现 / LB |
| **Done when** | CONTRACT 有池语义；focused 覆盖至少 idle clear + 上限行为 |
| **Gates** | client + H1/H2 client |
| **Next** | Wave P1 |

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
| **Status** | queued |
| **Do** | 只动一个 L1/L2 热点（parser materialize / header / writer / drain 择一）；前后有 bench 或 micro 证据 |
| **Don't** | 同时改多个热点；为数字加假 API |
| **Done when** | 单热点有前后数据 + 相关 correctness gate 绿 |
| **Gates** | 相关 micro/fullchain + 正确性 suite |
| **Next** | Wave P3 |

### Wave P3 — epoll vs threaded 表征

| 字段 | 内容 |
|------|------|
| **Status** | queued |
| **Do** | 同 workload 对照；诚实 caveat 写入 `BENCHMARKS.md` |
| **Don't** | 宣称跨机器排名 |
| **Done when** | BENCHMARKS 有可复现命令 + 一次本地 snapshot 表 |
| **Gates** | bench 脚本可跑；docs 更新 |
| **Next** | Wave P5 |

### Wave P5 — G6 closure criteria

| 字段 | 内容 |
|------|------|
| **Status** | queued |
| **Do** | 定义并满足「stage performance complete」：ladder 可跑、无假 claim、GOAL_TREE G6 与 BENCHMARKS 对齐 |
| **Don't** | 无限采集 ranking 表 |
| **Done when** | G6 退出「ongoing 无标准」；标准写进 GOAL_TREE + BENCHMARKS |
| **Gates** | docs + 既有 bench smoke |
| **Next** | Era 5 检查；若 H3 仍 Blocked → 模块 goal 可标 **framework-complete (non-H3)** 并 STOP 或转 Inbox |

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

---

## Era X — Explicit non-goals & residuals

| 项 | 立场 |
|----|------|
| server `Default` RW=0 | **Keep**（测试兼容）；生产用 `THttpServerOptions.Production` |
| cancel ~50 ms 切片 | **Residual-honest**（非 OS 硬中断） |
| OpenSSL factory unfreed | **跨模块 residual**；http 不单独清零宣称 |
| JSON dual raw vs ensure-string | **Keep** 三层模型 |
| Digest / NTLM / Negotiate proxy auth | **Park**（Wave I） |
| 完整企业代理栈 | **Park** 除非真实 consumer |
| SOCKS proxy | **Park**（更偏 net） |
| Server push | **Non-goal**（ENABLE_PUSH=0） |
| h2c Upgrade | **Park**（cleartext H2 = prior knowledge only） |
| 为对标而扩 API | **禁止** |

---

## Inbox（未排序；禁止直接做）

规则：

1. 只能追加一行想法（主题 + 为何）。
2. **升格**必须：移入某 Era 有序表 + 写满 Do/Don't/Done when/Gates + 改推荐路径（若插队）。
3. Agent **不得**实现仍停在 Inbox 的条目。

| 想法 | 备注 |
|------|------|
| （空） | 有想法往这里加 |

---

## 当前该做（给执行者 / goal）

```text
1. 打开本文件确认 Wave L′ 仍是 NEXT
2. GOAL_TREE / API_COVERAGE / README 只保留 NEXT → ROADMAP 指针
3. docs-only diff --check；可选 hygiene
4. path-limited land main
5. 本文件：Wave L′ → landed；Wave C1 → NEXT；changelog 一行
6. 自动续波
```

**没有用户指令时：默认执行 Wave L′，然后自动续波。**

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
