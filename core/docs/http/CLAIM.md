# nextpas.core.http — What we claim (R1 + HS-2a / C-D-claim / C-H1)

**Authority**: 本文件是**对外/对内宣称**的冻结表述。证据细节见 `BENCHMARKS.md`、`REPRO.md`、`CONTRACT.md`。执行顺序见 `ROADMAP.md`。
**Reviewed**: 2026-07-23（**HS-2a** package Yes + **C-D-claim** HTTPS H2 scale Yes + **C-H1** HTTPS H1 multi-run Met）
**Host class**: Linux amd64，同机 harness；**不是**跨机排行榜。

---

## 1. 维持的宣称（Allowed）

### Scale-ready (H1 server, Linux epoll)

| 门闩 | 状态 | 证据锚点 |
|------|------|----------|
| RPS ≥ **0.80×** Go `net/http`（同 workload） | **Met** | E3 runs=3 median：`no_url` **2.21×**，`response_1k` **2.22×**（`BENCHMARKS` § E3 / Q2-1） |
| p99 ≤ **2×** Go（同 harness 延迟定义） | **Met** | E3 median p99 比值 **0.21× / 0.22×**（`BENCHMARKS` § E3） |
| 连接阶梯 1k / 10k idle keep-alive | **Met** | `bench_conn_ladder` + E3 抽查 `stable=1` |
| 生产深度 soak 0 unfreed | **Met** | `test_http_soak` 5/5，0 unfreed（Q3-1） |
| 错误语义矩阵 | **Met** | `test_http_q3_matrix` timeout/cancel/413/431（Q3-2） |

**允许的一句话**：

> *Scale-ready (H1 server, Linux epoll)* — same-machine official harness, limited workloads, with documented residuals.

### Scale-ready (H1+H2 package, Linux epoll)

| 门闩 | 状态 | 证据锚点 |
|------|------|----------|
| H1 scale-ready 全部门闩 | **Met** | 上表 |
| H2 peer multi-run mid/press ≥ **0.80×** | **Met** | HS-1：mid **1.86×** / press **0.93×**（runs=3；`BENCHMARKS` § H2 KPI） |
| H2 peer KPI 形状冻结 | **Met** | HS-0：mid 8×16×100 / press 16×32×100 |
| 产品明确 Yes | **Yes** | HS-2a（2026-07-23） |

**允许的一句话**：

> *Scale-ready (H1+H2 package, Linux epoll)* — H1 multi-conn + H2c peer multi-run same-machine gates Met; H1 RPS 与 H2 mux **禁止**直接比值；documented residuals.

### Scale-ready (HTTPS H2, Linux epoll)

| 门闩 | 状态 | 证据锚点 |
|------|------|----------|
| HTTPS ALPN h2 peer multi-run mid/press ≥ **0.80×** | **Met** | C-D：mid **2.57×** / press **3.03×**（runs=3） |
| 产品明确 Yes | **Yes** | C-D-claim（2026-07-23） |

**允许的一句话**：

> *Scale-ready (HTTPS H2, Linux epoll)* — same-machine TLS ALPN `h2` peer multi-run (HS-0 shapes), limited workloads.

### Scale-ready (HTTPS H1, Linux epoll)

| 门闩 | 状态 | 证据锚点 |
|------|------|----------|
| RPS ≥ **0.80×** Go HTTPS H1（同 workload） | **Met** | C-H1 runs=3：`no_url` **2.10×**，`response_1k` **2.13×** |
| p99 ≤ **2×** Go | **Met** | C-H1 median p99 **0.15× / 0.17×** |
| 产品路径 H1 HTTPS server | **Met** | C-A `NewH1TlsServerTransport` |
| 产品明确 Yes（开波） | **Yes** | 2026-07-23 全部做 |

**允许的一句话**：

> *Scale-ready (HTTPS H1, Linux epoll)* — same-machine TLS ALPN `http/1.1` keep-alive peer multi-run; official shape 20k×4 `no_url` / `response_1k`.

**复现入口**：`REPRO.md`（1 小时内可复核关键数字）。

---

## 2. 明确不宣称（Forbidden）

| 宣称 | 状态 | 原因 |
|------|------|------|
| H3 ready | **No** | Blocked：仓库仅有 `tls.quic.crypto` 原语，无独立可链 QUIC transport / QPACK / H3 stack；**禁止**空 facade |
| Windows scale-ready | **No** | scale KPI 与 epoll 路径以 Linux 为准；cancel residual 见 CONTRACT |
| Multi-OS HTTP host path | **Smoke only** | `test_http_threaded_host` + `test_http_iocp_wine`（IOCP wire，Windows host 真用例）via `scripts/http-host-ci-matrix.sh`（Linux/macOS/Windows/FreeBSD CI）；**非** scale-ready / **非** full facade TLS |
| Windows Wine path | **Smoke only** | `test_platform_socket_wine` + `test_http_threaded_wine`（threaded HTTP/1.1 wire）；**非** real-Windows / **非** scale-ready / **非** IOCP |
| Cross-machine leaderboard / “已全面对标 Go/Rust” | **No** | 仅同机比值 + 契约诚实 |
| H2 mid RPS ÷ H1 multi-conn RPS 作为 package KPI | **Forbidden forever** | 形状不同；见 `BENCHMARKS` § H2 KPI |

---

## 3. p99 条件（冻结）

1. **定义**：client-observed nearest-rank percentile；nextPas 与 Go 对齐。
2. **门闩**：官方 epoll workload 上，nextPas p99 ≤ **2×** Go p99。
3. **Client 诚实差**：nextPas `header_plus_content_length` vs Go `http_client_body_drain`（见 `BENCHMARKS` § E1）。
4. **失效**：若重跑官方 multi-run 连续 3 日 p99 比值 > 2.0，或 RPS 中位 < 0.80×，则 **收回**对应 scale-ready 直至修复并刷新表。

---

## 4. Residual 清单（必须随宣称出现）

| Residual | 说明 |
|----------|------|
| H1 cleartext scale | **Met** — E3 RPS ~2.2× / p99 ~0.2×；ladder stable |
| H1+H2 package | **Yes (HS-2a)** — HS-0/HS-1 Met + 产品 Yes；**禁止** H1/H2 直接 RPS 比值 |
| HTTPS H2 peer scale | **Yes (C-D-claim)** — mid **2.57×** / press **3.03×**；product Yes |
| HTTPS H1 peer scale | **Yes (C-H1)** — `no_url` **2.10×** / `response_1k` **2.13×**；p99 **0.15× / 0.17×** |
| H2 Go peer harness | **landed** — `compare_h2` + `run_h2_comparison.sh`（HS-1 `--runs`；C-D `--tls`） |
| H1 TLS peer harness | **landed** — `bench_http_server --tls` + `compare_go --tls` + `run_h1_tls_comparison.sh` |
| H2-opt (2026-07-21) | TCP_NODELAY on dial；write coalesce；pool PING grace 1s；bench PingTimeout=0 |
| H2 peer self press/mid≥3× | **Dropped (HS-0)** — 双方高吞吐 CPU-bound |
| H2 TLS ALPN | **H2P-3 Met** — `test_http_h2_tls_alpn` 4/4 0 unfreed |
| HTTPS keep-alive pool | **RH-1 fixed**（`TTlsTcpStream` + `ITcpStreamRuntime`） |
| H1 `THttpServer`+`TLSContext` | **C-A Met** — `NewH1TlsServerTransport` |
| Windows cancel | waitable via TCP-loopback pair（**PD-3-3**）；probe-only only if pair fails；Wine smoke `test_platform_socket_wine` 含 socket_pair 字节唤醒（**非** real-Windows / **非** scale-ready） |
| Multi-OS HTTP host | **R2-5+**：`test_http_threaded_host` + `http-host-ci-matrix.sh` — Default backend=`tsbThreaded` + HTTP/1.1 wire GET on real CI hosts（Linux/macOS/Windows/FreeBSD）；**非** scale-ready |
| Windows HTTP wine | **R2-5 WIN-2**：`test_http_threaded_wine` — same wire under Wine（0 unfreed）；full `nextpas.core.http` facade Win64 cross residual（TLS→`system.sysutils` FPC internal）— cleartext net.threaded path is the verifiable smoke |
| Windows IOCP server | **W2-1..W2-3b landed** — `net.server.iocp` completion 驱动 recv/send/deadline-wake 数据路径（零字节 recv readiness 桥 + server 自有 GQCS 循环 + writable waiter timeout 重试 + 有限 `WakeDeadline` 经 `TryCancelByContext` 取消唤醒；生产 H1 session 走完成路径）；**real-Windows host 证据**：`http.iocp_wire` 5 用例 + heaptrc 0 unfreed（windows-latest via `http-host-ci-matrix.sh`，2026-07-26 run 30195741147）；含 16MB backpressure（真机部分写语义验证）；deadline wake 用例 Wine 绿、真机复验随下次 CI run；**禁止** scale claim（wire smoke ≠ scale） |
| Server `Default` RW | **PD-1B** — Read/Write=**30000**（与 Production 同量级）；长轮询显式 0 |
| Server IdleTimeout vs client IdleTTL | **PD-3-1** — Idle=30s / IdleTTL=90s 对照表见 CONTRACT |
| 长连接 / 大 body | **PD-3-2** residual Met — Q1-4 + 413/backpressure 矩阵已有测；无新增缺口 |
| H3 | Blocked |
| Rust std latency | **S2-b**：`compare_rust` 已发 p50/p99；仍非 scale KPI |
| `test_http_tls_real` | **Met (2026-07-21)** — 5/5 0 unfreed |

---

## 5. R0 决议（历史；维持）

| 问题 | 决议 |
|------|------|
| 是否维持 *Scale-ready (H1 server, Linux epoll)*？ | **Yes — maintain** |
| p99 是否作为 scale-ready 必要条件？ | **Yes**（与 RPS、ladder 并列） |
| 是否升级为 H1+H2 package claim？ | **No**（当时 H2P parked） |
| 是否宣称 HTTPS scale-ready？ | **No** |

**R0 Met (2026-07-20).**

---

## 6. R1 决议（H2P 后；历史）

**触发**：H2P-1..3 landed。当时否决 package / HTTPS scale。**R1 Met (2026-07-21).** 后续由 HS-2a / C-D-claim / C-H1 覆盖升格。

---

## 6.1 E3s 抽检 + H2 KPI draft（2026-07-21）

| 问题 | 决议 |
|------|------|
| E3 门闩是否仍 Met？ | **Yes** |
| 是否因比值从 ~2.2× 落到 ~1.7–2.0× 收回 scale-ready？ | **No** |
| H2 KPI 是否冻结？ | 当时 Draft；**HS-0 已冻结** |

---

## 6.2 HS-0 / HS-1 — H2 Seal（2026-07-21）

| 问题 | 决议 |
|------|------|
| H2 peer KPI 形状是否冻结？ | **Yes (HS-0)** |
| multi-run 证据？ | **HS-1 Met** — mid 1.86× / press 0.93× |
| 是否升 package claim？ | 当时 **No**（缺产品 Yes） |

**HS-0/HS-1 Met (2026-07-21).**

---

## 6.3 C-D — HTTPS H2 peer multi-run（2026-07-23）

| 问题 | 决议 |
|------|------|
| HTTPS ALPN h2 peer harness？ | **Yes** |
| multi-run 证据？ | **Met** — mid **2.57×** / press **3.03×** |
| 当时是否宣称 *Scale-ready (HTTPS H2)*？ | **No** — evidence bar only |

**C-D evidence Met (2026-07-23).** 升格见 §6.5。

---

## 6.4 HS-2a — H1+H2 package claim（2026-07-23）

| 问题 | 决议 |
|------|------|
| 产品明确 Yes？ | **Yes** |
| HS-0/HS-1 multi-run Met？ | **Yes** |
| 是否升 *Scale-ready (H1+H2 package, Linux epoll)*？ | **Yes** |
| H1/H2 直接 RPS 比值？ | **Forbidden forever** |

**Done when (HS-2a)**：CLAIM package Yes + residual/REPRO/BENCHMARKS 对齐。 **Met (2026-07-23).**

---

## 6.5 C-D-claim — Scale-ready (HTTPS H2)（2026-07-23）

| 问题 | 决议 |
|------|------|
| 产品明确 Yes？ | **Yes** |
| C-D multi-run Met？ | **Yes**（2.57× / 3.03×） |
| 是否宣称 *Scale-ready (HTTPS H2, Linux epoll)*？ | **Yes** |

**Done when**：CLAIM + REPRO + BENCHMARKS 对齐。 **Met (2026-07-23).**

---

## 6.6 C-H1 — Scale-ready (HTTPS H1)（2026-07-23）

| 问题 | 决议 |
|------|------|
| HTTPS H1 peer harness？ | **Yes** — `bench_http_server --tls` + `compare_go --tls` + `run_h1_tls_comparison.sh` |
| 官方 shape？ | 20k×4 `no_url` / `response_1k`；epoll；runs≥3；RPS ≥0.80×；p99 ≤2× |
| multi-run 证据？ | **Met** — `no_url` **2.10×** / p99 **0.15×**；`response_1k` **2.13×** / p99 **0.17×** |
| 是否宣称 *Scale-ready (HTTPS H1, Linux epoll)*？ | **Yes** |

**Done when**：harness + multi-run 表 + CLAIM/REPRO/BENCHMARKS。 **Met (2026-07-23).**

---

## 7. 与其他文档

| 文档 | 角色 |
|------|------|
| **CLAIM.md（本文件）** | 对外可说什么 / 不可说什么 |
| **REPRO.md** | 如何在 1h 内复核 |
| **BENCHMARKS.md** | 数字表与日期 |
| **CONTRACT.md** | 行为契约与 residual 细节 |
| **ROADMAP.md** | 下一波执行（当前 NEXT 见该文件 §2 快照） |