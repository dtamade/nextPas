# nextpas.core.http — What we claim (R1)

**Authority**: 本文件是**对外/对内宣称**的冻结表述。证据细节见 `BENCHMARKS.md`、`REPRO.md`、`CONTRACT.md`。执行顺序见 `ROADMAP.md`。
**Reviewed**: 2026-07-23（**R1** + **HS-0/HS-1** + **C-D** HTTPS H2 peer multi-run Met；package **仍 No**）
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

**复现入口**：`REPRO.md`（1 小时内可复核关键数字）。

---

## 2. 明确不宣称（Forbidden）

| 宣称 | 状态 | 原因 |
|------|------|------|
| Scale-ready (H1/**H2** package) | **No** | Peer KPI **HS-0 冻结** + multi-run mid **1.86×** / press **0.93× Met (HS-1)**；仍缺 **产品 Yes**（HS-2a）；见 `BENCHMARKS` § H2 KPI |
| Scale-ready (HTTPS H1) | **No** | 产品 H1 HTTPS server 已通（C-A）；**无** HTTPS H1 RPS/p99 KPI；client smoke ≠ scale |
| Scale-ready (HTTPS H2) | **No** | C-D peer multi-run mid **2.57×** / press **3.03× Met**（evidence bar）；**缺产品 Yes** 升格宣称 |
| H3 ready | **No** | Blocked on QUIC；禁止空 facade |
| Windows scale-ready | **No** | scale KPI 与 epoll 路径以 Linux 为准；cancel residual 见 CONTRACT |
| Cross-machine leaderboard / “已全面对标 Go/Rust” | **No** | 仅同机比值 + 契约诚实 |

---

## 3. p99 条件（冻结）

1. **定义**：client-observed nearest-rank percentile；nextPas 与 Go 对齐（`run_server_comparison` 透传 `median_p50_ns` / `median_p99_ns`）。
2. **门闩**：官方 epoll workload 上，nextPas p99 ≤ **2×** Go p99（E3 multi-run Met）。
3. **Client 诚实差**：nextPas `header_plus_content_length` vs Go `http_client_body_drain`（见 `BENCHMARKS` § E1）。
4. **失效**：若重跑 E3 连续 3 日 p99 比值 > 2.0，或 RPS 中位 < 0.80×，则 **收回** scale-ready 直至修复并刷新表。

---

## 4. Residual 清单（必须随宣称出现）

| Residual | 说明 |
|----------|------|
| H2 package scale | KPI **HS-0 frozen**；multi-run mid **1.86×** / press **0.93× Met (HS-1)**；**产品 Yes** 仍缺 → package **No** |
| HTTPS H2 peer scale | **C-D Met (2026-07-23)** — mid **2.57×** / press **3.03×**（runs=3）；evidence only；scale-ready **No** |
| E3s 抽检 (2026-07-21) | RPS 1.97×/1.72× Go；p99 0.23×/0.27×；ladder 1k/10k stable=1 — **维持** H1 scale-ready |
| H2 Go peer harness | **landed** — `compare_h2` + `run_h2_comparison.sh`（HS-1 `--runs`；C-D `--tls`） |
| H2-opt (2026-07-21) | TCP_NODELAY on dial；write coalesce；pool PING grace 1s；bench PingTimeout=0 |
| H2 peer self press/mid≥3× | **Dropped (HS-0)** — H2-opt 后双方高吞吐 CPU-bound，自比 ~1.05× 不再作门 |
| H2 TLS ALPN | **H2P-3 Met** — `test_http_h2_tls_alpn` 4/4 0 unfreed；OpenSSL per-conn ALPN |
| HTTPS keep-alive pool | **RH-1 fixed**（`TTlsTcpStream` + `ITcpStreamRuntime`）；H1 client smoke `accepts=1` for N GETs |
| H1 `THttpServer`+`TLSContext` | **C-A Met** — `NewH1TlsServerTransport`；`test_http_h1_tls_server` |
| Windows cancel | probe-only residual（R3） |
| H3 | Blocked |
| Rust std latency | **S2-b**：`compare_rust` 已发 p50/p99（nearest-rank）；仍非 scale KPI |
| `test_http_tls_real` | **Met (2026-07-21)** — 去 `TThread`，`platform_thread`；5/5 0 unfreed；全量 H2+TLS facade 仍见 h2_tls_alpn |

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

## 6. R1 决议（H2P 后；本波）

**触发**：H2P-1（mid 规格/证据）、H2P-2（press 线性）、H2P-3（TLS-ALPN e2e）均 landed。

**抽检（2026-07-21，非 E3 全量）**：

| Gate | 结果 |
|------|------|
| `test_http_h2_tls_alpn` | **4/4** 0 unfreed |
| `test_http_h2_facade` | **5/5** 0 unfreed |
| `test_http_https_smoke` | **3/3** 0 unfreed |

| 问题 | 决议 |
|------|------|
| 是否维持 *Scale-ready (H1 server, Linux epoll)*？ | **Yes — maintain**（E3 表未失效；本波未重跑 E3） |
| 是否升级为 H1+H2 package claim？ | **No** — H2 仅有 mux/evidence + 正确性 e2e；**缺**与 H1 同构的 KPI 门闩与产品升格需求 |
| 是否宣称 HTTPS H1/H2 scale-ready？ | **No** |
| H2 TLS ALPN 是否可写进 residual 为 Met？ | **Yes**（正确性；非 scale） |
| 本模块默认执行态？ | **STOP** — 无新需求、不空转 H3、不假 package scale-ready |

**升 package 的前置（未来；非本波）**：冻结 H2 官方 KPI 定义（同机 peer 或绝对阈值）+ multi-run 表 + REPRO 命令 + 产品明确要求。

**Done when**：本文件 R1 段 + ROADMAP R1 landed + REPRO Claim 行对齐 + 默认 STOP。 **Met (2026-07-21).**

---

## 6.1 E3s 抽检 + H2 KPI draft（2026-07-21）

| 问题 | 决议 |
|------|------|
| E3 门闩是否仍 Met？ | **Yes** — E3s runs=3：RPS ≥0.80×、p99 ≤2×（`BENCHMARKS` § E3） |
| 是否因比值从 ~2.2× 落到 ~1.7–2.0× 收回 scale-ready？ | **No** — 仍远高于 0.80；噪声带内 |
| H2 KPI 是否冻结为宣称门闩？ | **Draft only**（当时）；**HS-0 已冻结为 evidence bar**（仍非 package claim） |
| 是否因此升 package claim？ | **No**（仍缺 multi-run + 产品 Yes） |

---

## 6.2 HS-0 / HS-1 — H2 Seal（2026-07-21）

| 问题 | 决议 |
|------|------|
| H2 peer KPI 形状是否冻结？ | **Yes (HS-0)** — mid 8×16×100 / press 16×32×100；peer **ratio of medians ≥0.80×**（runs≥3）；stable=1 |
| self press/mid ≥3× 是否仍作门？ | **No — Dropped**（H2-opt 后双方 CPU-bound） |
| multi-run 证据？ | **HS-1 Met** — mid median 1.86× / press 0.93×（runs=3，all stable） |
| 是否升 package claim？ | **No** — multi-run Met 后仍须 **产品明确 Yes**（HS-2a） |
| 默认执行态？ | HS-0 → HS-1 → **STOP**（无产品 Yes 不空转 package） |

**Done when (HS-0)**：CLAIM residual + BENCHMARKS/REPRO 门闩一致；package 仍 No。 **Met (2026-07-21).**
**Done when (HS-1)**：`--runs` harness + mid/press multi-run 表；package 仍 No。 **Met (2026-07-21).**

---

## 6.3 C-D — HTTPS H2 peer multi-run（2026-07-23）

| 问题 | 决议 |
|------|------|
| HTTPS ALPN h2 peer harness？ | **Yes** — `bench_h2_server --tls` + `compare_h2 --tls` + `run_h2_comparison.sh --tls` |
| multi-run 证据？ | **Met** — mid median **2.57×** / press **3.03×**（runs=3，all stable） |
| 是否宣称 *Scale-ready (HTTPS H2)*？ | **No** — evidence bar only；须产品 Yes |
| 是否升 H1+H2 package？ | **No** — 仍须 HS-2a 产品 Yes |
| 默认执行态？ | C-D → **STOP** |

**Done when (C-D)**：TLS multi-run 表 + REPRO + residual 对齐；package / HTTPS scale-ready **仍 No**。 **Met (2026-07-23).**

---

## 7. 与其他文档

| 文档 | 角色 |
|------|------|
| **CLAIM.md（本文件）** | 对外可说什么 / 不可说什么 |
| **REPRO.md** | 如何在 1h 内复核 |
| **BENCHMARKS.md** | 数字表与日期 |
| **CONTRACT.md** | 行为契约与 residual 细节 |
| **ROADMAP.md** | 下一波执行（Era HS Done → 默认 **STOP**；升 package 须产品 Yes） |
