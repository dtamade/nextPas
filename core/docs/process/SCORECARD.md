# process / fs / path / env — SCORECARD（证据快照）

> **Host Essential Done** + **M2 Windows usable（wine）Done** + **M3 host-windows min-set CI gate Done**  
> （见 [ROADMAP.md](./ROADMAP.md) · [WIN.md](./WIN.md)）。

**truth 标签**

| 标签 | 含义 |
|------|------|
| `host-linux` | 本机 Linux 跑的数字；非 CI 矩阵 |
| `wine-runtime-smoke` | Win64 交叉编译 + Wine；**≠** 真 Windows host |
| `host-windows` | 真 Windows runner 上 native `make test`（GHA `windows-latest`） |

本表是**单机/CI 快照**，用于复现命令与量级对照，不宣称全面胜 Go。

---

## 环境（本快照）

| 项 | 值 |
|----|-----|
| 日期 | 2026-07-20（M3） |
| OS | Linux x86_64（host-linux / wine）；GHA windows-latest（host-windows） |
| 工具 | FPC 3.3.1；Wine 可用；GHA FPC trunk win64 |

---

## A. L2 wine 最小生产集（M2-W4）

一键：

```bash
bash core/tests/run_l2_wine_min_set.sh
```

| 套件 | 结果 | 说明 |
|------|------|------|
| process | **11 passed** | Capture；KillTree(Job)；ExtraFd/Cred fail-closed |
| fs | **3 passed** | Write-Read-Remove / MkdirAll / OpenLocked |
| path | **4 passed** | Join-Clean / IsAbs-Volume / ToSlash / StripPrefix |
| os.env | **3 passed** | GetEnv / Set-Unset-Expand / Expand brace |
| fs.watch | **3 passed** | create/close + poll timeout + create-event soft |
| **合计** | **24 passed** | truth=`wine-runtime-smoke` |

Host `make test` 在非 Windows 上为 skip 分支（1 passed）。

**Windows 备注**：`WaitGraceful` 依赖 SIGTERM，Wine/Win 上 signal 有限；证据用 `Kill`。Watch create-event 在部分 Wine 上 soft residual。

---

## A2. L2 host-windows 最小生产集（M3）

```bash
# Windows host / GHA (cwd core/ OK)
bash core/scripts/l2-windows-ci-matrix.sh
```

| 套件 | 目标 | truth |
|------|------|-------|
| 同上 5 目录 | native `make clean test` | **`host-windows`** |

CI：`.github/workflows/core-ci.yml` job `test-windows-runtime` step  
`L2 process/fs/path/env Windows min-set (host-windows)`。

**范围**：仅 min-set 5 门；**不是**全量 Host L2。数字以 GHA 绿为准（本地无 Windows 时本表只登记门禁，不伪造 pass 数）。

---

## B. fs host-linux（nextpas.core.bench）

```bash
make -C core/benchmarks/nextpas.core.fs/bench_fs run
```

| 项 | Mean | Throughput | CV |
|----|------|------------|-----|
| SeqWrite/64KB | ~35 µs | ~1.75 GB/s | ~2% |
| SeqRead/64KB | ~11 µs | ~5.65 GB/s | ~2% |
| FileExists | ~1.4 µs | — | ~2.5% |
| FileSize | ~1.4 µs | — | ~2.5% |
| ReadAll/64KB | ~131 µs | ~480 MB/s | ~1% |

### 同方法对照（R34，create/write/close 循环）

```bash
make -C core/benchmarks/nextpas.core.fs/bench_fs run   # 末尾 aligned 段
cd core/benchmarks/nextpas.core.fs/bench_fs/compare_go && go run main.go
```

| 方法 | nextpas | Go | 备注 |
|------|---------|-----|------|
| SeqWrite 64KB×200 | ~1.6 GB/s | ~1.7 GB/s | ~持平 |
| SeqRead 64KB×200 | ~5.6 GB/s | ~0.56 GB/s | nextpas 更高（page cache 路径） |
| SeqWrite 1MB×20 | ~1.8 GB/s | ~2.1 GB/s | ~0.85× Go |
| SeqRead 1MB×20 | ~8.0 GB/s | ~0.39 GB/s | nextpas 更高（同上；非网络） |

**truth**：同机、同 open/write/close 循环；Read 差异受 OS page cache 与 `io.ReadAll` vs 分块 Read 影响，**不**单独宣称全面 I/O 胜 Go。

---

## C. process host-linux

```bash
make -C core/benchmarks/nextpas.core.process/bench_process run
cd core/benchmarks/nextpas.core.process/bench_process/compare_go && go run main.go
```

### nextpas（2026-07-20 R33 复测）

| 项 | n | total | avg |
|----|---|-------|-----|
| LookPath(sh) | 200 | 8 ms | ~41 µs |
| Command(/bin/true).Status | 50 | 49 ms | **~1.0 ms** |
| Capture(echo x) | 50 | 81 ms | **~1.6 ms** |
| Output(echo x) dual-pipe | 50 | 84 ms | **~1.7 ms** |

### Go 对照（同机）

| 项 | n | avg |
|----|---|-----|
| exec.LookPath(sh) | 200 | ~44 µs |
| exec.Command(true).Run | 50 | ~0.88 ms |
| exec.Command(echo).Output | 50 | ~1.3 ms |

R33：Wait/WaitGraceful 超时·Cancel 轮询起步 **100µs**（与 WaitWithOutput/Destroy 一致）；wine×5 复跑全绿。  
LookPath 持平；Status ~**1.15×**；Capture/dual-pipe ~**1.25–1.3×** Go。

---

## 复现清单

1. `git checkout` 对应 commit  
2. `bash core/tests/run_l2_wine_min_set.sh`（需 `fpc -Twin64` + `wine`）  
3. Windows：`bash core/scripts/l2-windows-ci-matrix.sh` 或等 GHA `test-windows-runtime`  
4. `bench_fs` / `bench_process` + 各自 `compare_go`  

**不要**把 wine 结果写成 `host-windows`；**不要**把 min-set 写成全量 Windows production ready。
