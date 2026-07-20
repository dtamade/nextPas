# nextpas.core.http — Release evidence 复现剧本

**Purpose**：在 **Linux amd64** 上 1 小时内复核对标宣称所需的关键数字。
**Authority**：规模门闩定义见 `ROADMAP.md` / `GOAL_TREE.md`；历史表见 `BENCHMARKS.md`。

**Claim (current)**：*Scale-ready (H1 server, Linux epoll)* — same-machine, limited workloads.
**Authority**：完整允许/禁止表述见 [`CLAIM.md`](CLAIM.md)（**R1** 冻结）。
**Not claimed**：H1+H2 package；HTTPS H1/H2 scale-ready；H3；Windows scale；跨机榜。

从仓库根目录进入 `core/` 后执行。

---

## 0. 卫生

```sh
make hygiene
git status --short   # 应为 clean（或仅 ignore）
```

---

## 1. H1 multi-conn RPS（官方 KPI）

```sh
./benchmarks/nextpas.core.http/run_server_comparison.sh \
  --requests 20000 --threads 4 --workload no_url \
  --nextpas-backend epoll --runs 3 \
  --output build/projects/nextpas.core.http/server_comparison/repro-epoll-no_url-runs3.md
```

**读数**：summary 中 nextPas / Go `median_req/s`；比值 **≥ 0.80** 才维持 scale-ready RPS。
**参考历史**：BENCHMARKS Q2-1（2026-07-19）epoll `no_url` **2.20×** Go。

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

## 4. H2 multiplex scale（H2P-1 / S3，evidence only）

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
**不宣称** Scale-ready (H1/H2)。

---

## 5. 正确性 smoke + soak（最小）

```sh
# 从仓库根
make focused FOCUS=core/tests/nextpas.core.http/test_http_server
make focused FOCUS=core/tests/nextpas.core.http/test_http_h2_facade
make focused FOCUS=core/tests/nextpas.core.http/test_http_h2_tls_alpn
make focused FOCUS=core/tests/nextpas.core.http/test_http_tls_real
make focused FOCUS=core/tests/nextpas.core.http/test_http_soak
make focused FOCUS=core/tests/nextpas.core.http/test_http_q3_matrix
make focused FOCUS=core/tests/nextpas.core.http/test_http_https_smoke
```

期望：server 全绿；facade 含 **epoll** GET；H2 TLS ALPN **4/4** 0 unfreed（H2P-3）；
`test_http_tls_real` **5/5** 0 unfreed（低层 TLS + stream wrapper）；
soak **5/5**（Linux）0 unfreed；Q3-2 矩阵 **6/6** 0 unfreed；HTTPS smoke **3/3** 0 unfreed。
HTTPS smoke 读数：`server_accepts=1`（RH-1 keep-alive）、`req/s` 通常 ≫ 10、`p50_ns=` / `p99_ns=`。
**仍不宣称** HTTPS scale-ready 或 H1/H2 package scale-ready（见 `CLAIM.md`）。

---

## 解读纪律

1. 单机单日数字只进 BENCHMARKS 带日期；不写「已全面对标」。
2. H1 RPS 与 H2 mux **不可**直接做比值 KPI。
3. p99 门闩（nextPas ≤ 2× Go）E3 runs=3 **Met**（历史 0.21×–0.22×）。
4. 结果异常：先 `make hygiene`、确认 ulimit、确认无其他 heavy 进程，再重跑。
