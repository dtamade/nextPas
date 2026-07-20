# nextpas.core.http — What we claim (R1)

**Authority**: 本文件是**对外/对内宣称**的冻结表述。证据细节见 `BENCHMARKS.md`、`REPRO.md`、`CONTRACT.md`。执行顺序见 `ROADMAP.md`。
**Reviewed**: 2026-07-21（**R1** — H2P-1..3 后 claim 评审）
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
| Scale-ready (H1/**H2** package) | **No** | H2 mux mid ~3k / press ~11.5k **evidence only**；形状 ≠ H1 multi-conn KPI；**无** H2 官方 KPI 门闩（≥0.8× 某 peer 等） |
| Scale-ready (HTTPS H1) | **No** | H1 HTTPS 非产品 server 入口（registry TLS→H2）；client smoke ≠ scale |
| Scale-ready (HTTPS H2) | **No** | H2P-3 正确性 e2e（ALPN `h2`）已绿；**无** HTTPS H2 RPS/p99 KPI |
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
| H2 package scale | H2P-1/2 mux 证据；非 scale-ready 包；禁止 H1/H2 直接 RPS 比值 |
| H2 TLS ALPN | **H2P-3 Met** — `test_http_h2_tls_alpn` 4/4 0 unfreed；OpenSSL per-conn ALPN |
| HTTPS keep-alive pool | **RH-1 fixed**（`TTlsTcpStream` + `ITcpStreamRuntime`）；H1 client smoke `accepts=1` for N GETs |
| H1 `THttpServer`+`TLSContext` | registry **仅 H2 TLS**；H1 HTTPS server 非产品入口 |
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

## 7. 与其他文档

| 文档 | 角色 |
|------|------|
| **CLAIM.md（本文件）** | 对外可说什么 / 不可说什么 |
| **REPRO.md** | 如何在 1h 内复核 |
| **BENCHMARKS.md** | 数字表与日期 |
| **CONTRACT.md** | 行为契约与 residual 细节 |
| **ROADMAP.md** | 下一波执行（R1 后默认 **STOP**） |
