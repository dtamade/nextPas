# nextpas.core.http — What we claim (R0)

**Authority**: 本文件是**对外/对内宣称**的冻结表述。证据细节见 `BENCHMARKS.md`、`REPRO.md`、`CONTRACT.md`。执行顺序见 `ROADMAP.md`。
**Reviewed**: 2026-07-20（Parity Plus Era G/E/Q3 后 **R0**）
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
| Scale-ready (H1/**H2** package) | **No** | H2 mux ~3k req/s evidence only；形状 ≠ H1 multi-conn KPI |
| Scale-ready (HTTPS H1) | **No** | Q3-3 smoke：`accepts≈reqs` 每请求 TLS dial；pool 复用未证 |
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
| H2 package scale | 有 S3 mux 证据；非 scale-ready 包 |
| HTTPS keep-alive pool | Q3-3 smoke 未证明 reuse；正确性单次绿 |
| H1 `THttpServer`+`TLSContext` | registry **仅 H2 TLS**；H1 HTTPS server 非产品入口 |
| Windows cancel | probe-only residual（R3） |
| H3 | Blocked |
| Rust std latency | comparison 行仍可无 p50/p99 |

---

## 5. R0 决议

| 问题 | 决议 |
|------|------|
| 是否维持 *Scale-ready (H1 server, Linux epoll)*？ | **Yes — maintain** |
| p99 是否作为 scale-ready 必要条件？ | **Yes**（与 RPS、ladder 并列） |
| 是否升级为 H1+H2 package claim？ | **No**（需 H2P + 需求） |
| 是否宣称 HTTPS scale-ready？ | **No** |
| Parity Plus 是否 STOP？ | **Yes** — 无新需求时 STOP；H2P parked |

**Done when**：本文件 + ROADMAP R0 landed；REPRO Claim 行与本文件一致。 **Met (2026-07-20).**

---

## 6. 与其他文档

| 文档 | 角色 |
|------|------|
| **CLAIM.md（本文件）** | 对外可说什么 / 不可说什么 |
| **REPRO.md** | 如何在 1h 内复核 |
| **BENCHMARKS.md** | 数字表与日期 |
| **CONTRACT.md** | 行为契约与 residual 细节 |
| **ROADMAP.md** | 下一波执行（R0 后默认 STOP） |
