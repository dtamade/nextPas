# nextpas.core.http Roadmap

**Authority**: 本文件是 HTTP 模块**向前开发**的唯一执行入口。
**Companion**: 北极星背景见 `GOAL_TREE.md`；契约见 `CONTRACT.md`；宣称见 `CLAIM.md`；复现见 `REPRO.md`。
**Updated**: 2026-07-26（W2-2 landed：IOCP send/drain + server 自有 GQCS 事件循环；NEXT=W2-3）
**历史**: Era 0 至 R2 residual 的全部已完成 Wave 详表与旧 changelog 已冻结在
[`archive/2026-07-26-roadmap-history-era0-to-r2.md`](archive/2026-07-26-roadmap-history-era0-to-r2.md)——**不是 backlog**，只作证据检索。

---

## 0. 进场 30 秒（给执行者 / AI）

1. **当前 NEXT = Wave W2-3**（Era W2，见 §4）。
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
| Windows | **W2-2 landed**：`net.server.iocp` phase-2 recv + send drain——server 自有 GQCS 事件循环（`PollOneWait` 三态：dispatched/timeout/woken），writable waiter 靠 1ms timeout 重试 re-advance（单路等待不变式：recv op 挂起 XOR writable waiter）；keep-alive 多请求 + 16MB backpressure 用例绿；**deadline wake 未做（守卫外回退 worker）**；证据 `test_http_iocp_wine` 5 用例（Wine smoke，非真机）。⚠️ Wine 语义差异：非阻塞 send 单次大 buffer 被整块吞下不 WouldBlock，分块（≤64KB）写才有真实 backpressure——wire 测试 session 必须分块写 |
| Multi-OS host | `test_http_threaded_host` + `core/scripts/http-host-ci-matrix.sh`（Linux/macOS/Windows/FreeBSD CI，smoke only） |
| H3 | **Blocked**：仓库仅有 `tls.quic.crypto` 原语，无可链 QUIC transport；禁止空 facade |
| **NEXT** | **Wave W2-3**（改方向先改本行 + §4） |

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

## 4. Era W2 — Windows 生产化 phase-2：IOCP 数据路径【NEXT】

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
| **Status** | queued |
| **Do** | `core/scripts/http-host-ci-matrix.sh` 增 IOCP 行：Windows host 上 `tsbIocp` wire smoke；Wine 与真机差异 residual 写入 CONTRACT/CLAIM |
| **Don't** | 不在 CI 里跑性能 harness（那是候选战役）；不因 CI 排队阻塞 lane（异步等结果） |
| **Done when** | Windows CI 行绿（或差异 residual 诚实记录并给出堵点报告）；CLAIM「Windows scale=No」措辞随证据更新 |
| **Gates** | host CI matrix + docs hygiene |
| **Land paths** | `core/scripts/http-host-ci-matrix.sh`；`core/docs/http/**`；必要最小测试改动 |
| **风险与兜底** | 无可用 Windows runner → 本波 Blocked 报告（需产品决策 runner 资源），转 M-band |
| **Next** | Wave W2-4 |

### Wave W2-4 — 评审与宣称对齐

| 字段 | 内容 |
|------|------|
| **Status** | queued |
| **Do** | 评审 W2-1..3 证据：CLAIM/CONTRACT/GOAL_TREE 对齐 IOCP 真实状态；决定「Windows 性能 harness」是否从候选战役升格；Windows scale 宣称维持 No 除非有同机证据 |
| **Don't** | 无证据升宣称 |
| **Done when** | 文档三处一致；下一战役 NEXT 明确（升格或回 M-band/候选评估） |
| **Gates** | docs + `make hygiene` |
| **Next** | 按评审结论回写 §2 NEXT |

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
| （空） | 新想法只追加 |

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
| 2026-07-26 | **W2-2 landed**：IOCP send/drain——reactor `PollOneWait` 三态 + server 自有 GQCS 事件循环 + writable waiter 1ms timeout 重试；keep-alive 两请求 + 16MB backpressure 用例（RED→GREEN）；发现并记录 Wine 大 buffer send 语义差异（整块吞下不 WouldBlock，须分块写）；Wine 5 用例 + Linux 136 双绿、双端 0 unfreed；NEXT=W2-3 |
| 2026-07-26 | **W2-1 landed**：IOCP completion 驱动 recv——零字节 overlapped `WSARecv` readiness 桥 + poll session reactor 线程 `Advance`；守卫外回退 worker handoff；`test_http_iocp_wine` 增 completion-recv 用例（RED→GREEN）；Linux 回归绿；NEXT=W2-2 |
| 2026-07-26 | **路线图重构**：Era 0–R2 全史（原 1220 行）冻结进 `archive/2026-07-26-roadmap-history-era0-to-r2.md`；本文件精简为单一前进入口；新增反碰壁兜底链（Era → M-band → STOP 报告）；重开前进路线 **Era W2 Windows 生产化 phase-2**，NEXT=W2-1（会话授权） |
| 2026-07-26 | （重构前）h2 monolith extract / settings share / cancel-adapter / client helpers / session extract 等 residual 波全部 landed；详见 archive 快照 changelog |
