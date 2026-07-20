# nextpas.core.http — Release evidence 复现剧本

**Purpose**：在 **Linux amd64** 上 1 小时内复核对标宣称所需的关键数字。
**Authority**：规模门闩定义见 `ROADMAP.md` / `GOAL_TREE.md`；历史表见 `BENCHMARKS.md`。

**Claim (current)**：*Scale-ready (H1 server, Linux epoll)* — same-machine, limited workloads.
**Not claimed**：H1+H2 package scale-ready；H3；跨机榜；Go 同 harness p99（Era E）。

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

## 2. H1 client latency（L1，nextPas 行）

```sh
make -C benchmarks/nextpas.core.http/bench_server build
./build/projects/nextpas.core.http/bench_server/bench_http_server \
  --requests 20000 --threads 4 --workload no_url --backend epoll
```

**读数**：`p50_ns=` / `p99_ns=` / `mean_ns=` / `req/s=`。
**注意**：Go 行 p99 仍在 Era **E1**；此处仅 nextPas。

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

## 4. H2 multiplex scale（S3，evidence only）

```sh
make -C benchmarks/nextpas.core.http/bench_h2_server smoke
# mid（epoll）
./build/projects/nextpas.core.http/bench_h2_server/bench_h2_server \
  --mode multiplex --backend epoll \
  --connections 8 --streams 16 --batches 100
```

**读数**：`stable=1`；`req/s=`（历史 ~2.8–3k，**不是** H1 KPI）。
**不宣称** Scale-ready (H1/H2)。

---

## 5. 正确性 smoke（最小）

```sh
# 从仓库根
make focused FOCUS=core/tests/nextpas.core.http/test_http_server
make focused FOCUS=core/tests/nextpas.core.http/test_http_h2_facade
```

期望：server 全绿；facade 含 **epoll** GET。

---

## 解读纪律

1. 单机单日数字只进 BENCHMARKS 带日期；不写「已全面对标」。
2. H1 RPS 与 H2 mux **不可**直接做比值 KPI。
3. p99 门闩（nextPas ≤ 2× Go）在 **E1–E2** 闭合前，对外只报 RPS scale-ready。
4. 结果异常：先 `make hygiene`、确认 ulimit、确认无其他 heavy 进程，再重跑。
