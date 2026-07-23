# nextpas.core.http — Release evidence 复现剧本

**Purpose**：在 **Linux amd64** 上 1 小时内复核对标宣称所需的关键数字。
**Authority**：规模门闩定义见 `ROADMAP.md` / `GOAL_TREE.md`；历史表见 `BENCHMARKS.md`。

**Claim (current)**：见 [`CLAIM.md`](CLAIM.md) — 允许：
- *Scale-ready (H1 server, Linux epoll)*
- *Scale-ready (H1+H2 package, Linux epoll)*
- *Scale-ready (HTTPS H1, Linux epoll)*
- *Scale-ready (HTTPS H2, Linux epoll)*

**Not claimed**：H3；Windows scale；跨机榜；H1/H2 直接 RPS 比值作 package KPI。

从仓库根目录进入 `core/` 后执行。

---

## 0. 卫生

```sh
make hygiene
git status --short   # 应为 clean（或仅 ignore）
```

---

## 1. H1 multi-conn RPS（官方 KPI · cleartext）

```sh
./benchmarks/nextpas.core.http/run_server_comparison.sh \
  --requests 20000 --threads 4 --workload no_url \
  --nextpas-backend epoll --runs 3 \
  --output build/projects/nextpas.core.http/server_comparison/repro-epoll-no_url-runs3.md
```

**读数**：summary 中 nextPas / Go `median_req/s`；比值 **≥ 0.80** 才维持 scale-ready RPS。
**参考历史**：BENCHMARKS Q2-1 / E3（2026-07-19/20）epoll `no_url` **~2.2×** Go。

次要 body：

```sh
./benchmarks/nextpas.core.http/run_server_comparison.sh \
  --requests 20000 --threads 4 --workload response_1k \
  --nextpas-backend epoll --runs 3 \
  --output build/projects/nextpas.core.http/server_comparison/repro-epoll-response_1k-runs3.md
```

---

## 2. H1 client latency（L1 + Go E1）

```sh
make -C benchmarks/nextpas.core.http/bench_server build
./build/projects/nextpas.core.http/bench_server/bench_http_server \
  --requests 20000 --threads 4 --workload no_url --backend epoll
# same harness + Go p50/p99
./benchmarks/nextpas.core.http/run_server_comparison.sh \
  --requests 20000 --threads 4 --workload no_url --runs 1 \
  --nextpas-backend epoll
```

**读数**：`p50_ns=` / `p99_ns=` / `mean_ns=`；summary 的 `median_p50_ns=` / `median_p99_ns=`。
**门闩（E2）**：nextPas p99 ≤ **2×** Go p99（同 workload / 同机）。

### 2.1 如何读 latency（PD-2）

| 字段 | 含义 |
|------|------|
| `p50_ns` / `p99_ns` / `mean_ns` | **client-observed** nearest-rank percentile（与 Go harness 对齐） |
| `latency_samples=` | 参与分位的样本数（通常 = completed） |
| multi-run `median_*` | 对多次 run 的 p50/p99 **再取中位**（抗单次噪声） |
| p99 ratio | nextPas_p99 / Go_p99；scale-ready 要求 **≤ 2.0** |
| 诚实差 | nextPas `header_plus_content_length` vs Go `http_client_body_drain`（见 BENCHMARKS § E1） |

**不要**：把单次 short sample 当 scale-ready 证据；用 H2 mid RPS ÷ H1 multi-conn RPS；跨机对比。
**要**：官方 shape + runs≥3 时看 summary gate 行；1h 复核走本节 + §1。

---

## 3. 连接阶梯 1k / 10k idle（S1-3）

```sh
make -C benchmarks/nextpas.core.http/bench_conn_ladder build
# harness 默认 raise soft nofile（≤ hard）
./build/projects/nextpas.core.http/bench_conn_ladder/bench_conn_ladder \
  --connections 1000 --hold-ms 2000 --backend epoll --probe 1
./build/projects/nextpas.core.http/bench_conn_ladder/bench_conn_ladder \
  --connections 10000 --hold-ms 2000 --backend epoll --probe 1
```

**读数**：`stable=1`；`open_ok` / `probe_ok`。
**失败模式**：`--raise-nofile 0 --connections 600` 预期 `stable=0`（soft=1024 附近）。

---

## 4. H2 multiplex scale（H2P-1 / S3；package 组成部分）

**规格（H2P-1 冻结；与 H1 分表，禁止直接 RPS 比值）**

| 字段 | 官方 mid | smoke |
|------|----------|-------|
| mode | `multiplex` | `multiplex` |
| backend | `epoll`（Linux）/ `threaded` | either |
| connections | **8** | 4 |
| streams/batch | **16** | 4 |
| batches | **100**（mid）/ **200**（press） | 25 |

```sh
make -C benchmarks/nextpas.core.http/bench_h2_server smoke
# H2P-1 mid（epoll）
./build/projects/nextpas.core.http/bench_h2_server/bench_h2_server \
  --mode multiplex --backend epoll \
  --connections 8 --streams 16 --batches 100
# H2P-2 press sample
./build/projects/nextpas.core.http/bench_h2_server/bench_h2_server \
  --mode multiplex --backend epoll \
  --connections 16 --streams 32 --batches 100
```

**读数**：`stable=1`；`req/s=`；`completed=`（mid ~2.8–3k；press 16×32 ~11k，**不是** H1 KPI）。

### 4.1 H2 peer KPI + Go peer（HS-0 frozen；package 门闩）

见 `BENCHMARKS.md` § **H2 KPI frozen**。

**冻结门闩**：mid 8×16×100 / press 16×32×100；**ratio of medians ≥ 0.80×**（runs≥3）；每 run stable=1。
self press/mid≥3× **已 Dropped**。

```sh
./benchmarks/nextpas.core.http/run_h2_comparison.sh \
  --connections 8 --streams 16 --batches 100 --runs 3 \
  --output build/projects/nextpas.core.http/h2_comparison/hs1-mid-8x16x100-runs3.md
./benchmarks/nextpas.core.http/run_h2_comparison.sh \
  --connections 16 --streams 32 --batches 100 --runs 3 \
  --output build/projects/nextpas.core.http/h2_comparison/hs1-press-16x32x100-runs3.md
```

**读数**：`summary_ratio_nextpas_over_go` 与 `summary_gate_peer_0_80`。
**2026-07-21 HS-1 multi-run (runs=3)**：mid median **1.86× Met**；press median **0.93× Met**。
**package Yes (HS-2a, 2026-07-23)** — multi-run Met + 产品 Yes。

### 4.2 HTTPS ALPN h2 peer（C-D / C-D-claim）

同 HS-0 形状；transport = TLS ALPN `h2`（双方 self-signed）。门闩同 §4.1。

```sh
make -C benchmarks/nextpas.core.http/bench_h2_server smoke-tls
./benchmarks/nextpas.core.http/run_h2_comparison.sh --tls \
  --connections 8 --streams 16 --batches 100 --runs 3 \
  --output build/projects/nextpas.core.http/h2_tls_comparison/cd-mid-8x16x100-runs3.md
./benchmarks/nextpas.core.http/run_h2_comparison.sh --tls \
  --connections 16 --streams 32 --batches 100 --runs 3 \
  --output build/projects/nextpas.core.http/h2_tls_comparison/cd-press-16x32x100-runs3.md
```

**2026-07-23 C-D multi-run (runs=3)**：mid median **2.57× Met**；press median **3.03× Met**。
**Scale-ready (HTTPS H2) Yes (C-D-claim, 2026-07-23)**。

---

## 5. HTTPS H1 peer scale（C-H1）

官方 shape 与 cleartext H1 同构：20k×4 `no_url` / `response_1k`；backend **epoll**；transport TLS ALPN `http/1.1`。
门闩：RPS median ≥ **0.80×**；p99 median ≤ **2×**（runs≥3）。

```sh
make -C benchmarks/nextpas.core.http/bench_server smoke-tls
./benchmarks/nextpas.core.http/run_h1_tls_comparison.sh \
  --requests 20000 --threads 4 --workload no_url --runs 3 \
  --output build/projects/nextpas.core.http/h1_tls_comparison/ch1-no_url-20k4-runs3.md
./benchmarks/nextpas.core.http/run_h1_tls_comparison.sh \
  --requests 20000 --threads 4 --workload response_1k --runs 3 \
  --output build/projects/nextpas.core.http/h1_tls_comparison/ch1-response_1k-20k4-runs3.md
```

**读数**：`summary_ratio_nextpas_over_go` / `summary_p99_ratio_nextpas_over_go` / `summary_gate_*`。
**2026-07-23 C-H1 multi-run (runs=3)**：`no_url` **2.10×** / p99 **0.15× Met**；`response_1k` **2.13×** / p99 **0.17× Met**。
**Scale-ready (HTTPS H1) Yes**。

---

## 6. 正确性 smoke + soak（最小）

```sh
# 从仓库根
make focused FOCUS=core/tests/nextpas.core.http/test_http_server
make focused FOCUS=core/tests/nextpas.core.http/test_http_h2_facade
make focused FOCUS=core/tests/nextpas.core.http/test_http_h2_tls_alpn
# side suite (OpenSSL host env; not in main Makefile PROJECTS):
make focused FOCUS=core/tests/nextpas.core.http/test_http_tls_real
make focused FOCUS=core/tests/nextpas.core.http/test_http_soak
make focused FOCUS=core/tests/nextpas.core.http/test_http_q3_matrix
make focused FOCUS=core/tests/nextpas.core.http/test_http_https_smoke
make focused FOCUS=core/tests/nextpas.core.http/test_http_h1_tls_server
```

期望：server 全绿；facade 含 **epoll** GET；H2 TLS ALPN **4/4** 0 unfreed（H2P-3）；
`test_http_tls_real` **5/5** 0 unfreed（side suite；需本机 OpenSSL）；
soak **5/5**（Linux）0 unfreed；Q3-2 矩阵 **6/6** 0 unfreed；HTTPS smoke **3/3** 0 unfreed；
`test_http_h1_tls_server` 全绿（C-A）。
HTTPS smoke 读数：`server_accepts=1`（RH-1 keep-alive）、`req/s` 通常 ≫ 10、`p50_ns=` / `p99_ns=`。

---

## 解读纪律

1. 单机单日数字只进 BENCHMARKS 带日期；不写「已全面对标」。
2. H1 RPS 与 H2 mux **不可**直接做比值 KPI。
3. p99 门闩（nextPas ≤ 2× Go）E3 / C-H1 multi-run **Met**。
4. 结果异常：先 `make hygiene`、确认 ulimit、确认无其他 heavy 进程，再重跑。
5. 宣称失效条件见 `CLAIM.md` §3。