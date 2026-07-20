# process / fs / path / env — SCORECARD（证据快照）

> **Host Essential Done**（见 [ROADMAP.md](./ROADMAP.md)）。本表可复现数字；Win 终局见 ROADMAP M2。

**truth 标签**

| 标签 | 含义 |
|------|------|
| `host-linux` | 本机 Linux 跑的数字；非 CI 矩阵 |
| `wine-runtime-smoke` | Win64 交叉编译 + Wine；**≠ 真 Windows host** |

本表是**单机快照**，用于复现命令与量级对照，不宣称全面胜 Go。

---

## 环境（本快照）

| 项 | 值 |
|----|-----|
| 日期 | 2026-07-20 |
| OS | Linux x86_64 (Debian) |
| 工具 | FPC 3.3.1；Wine 可用 |

---

## A. L2 wine-runtime-smoke（R33 复跑）

```bash
make -C core/tests/nextpas.core.process/test_process_wine wine-runtime-smoke
make -C core/tests/nextpas.core.fs/test_fs_wine wine-runtime-smoke
make -C core/tests/nextpas.core.path/test_path_wine wine-runtime-smoke
make -C core/tests/nextpas.core.os.env/test_os_env_wine wine-runtime-smoke
make -C core/tests/nextpas.core.fs/test_fs_watch_wine wine-runtime-smoke
```

| 套件 | 结果 | 说明 |
|------|------|------|
| process | **8 passed** | + Capture echo (R34)；timeout / MaxOutput / Status / Kill |
| fs | **3 passed** | Write-Read-Remove / MkdirAll / OpenLocked |
| path | **4 passed** | Join-Clean / IsAbs-Volume / ToSlash / StripPrefix |
| os.env | **3 passed** | GetEnv / Set-Unset-Expand / Expand brace |
| fs.watch | **3 passed** | create/close + poll timeout + create-event soft (M2-W1 S2) |

Host `make test` 在非 Windows 上为 skip 分支（1 passed）。

**Windows 备注**：`WaitGraceful` 依赖 SIGTERM，Wine/Win 上 signal 有限；证据用 `Kill`。`platform.watch` 在部分 Wine 构建为 UNSUPPORTED，套件接受该结果。

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
2. wine 五套件（需 `fpc -Twin64` + `wine`）  
3. `bench_fs` / `bench_process` + 各自 `compare_go`  

**不要**把 wine 结果写成「Windows production ready」。
