# process / fs / path / env — SCORECARD（证据快照）

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

## A. L2 wine-runtime-smoke（R26 加厚）

```bash
make -C core/tests/nextpas.core.process/test_process_wine wine-runtime-smoke
make -C core/tests/nextpas.core.fs/test_fs_wine wine-runtime-smoke
make -C core/tests/nextpas.core.path/test_path_wine wine-runtime-smoke
make -C core/tests/nextpas.core.os.env/test_os_env_wine wine-runtime-smoke
make -C core/tests/nextpas.core.fs/test_fs_watch_wine wine-runtime-smoke
```

| 套件 | 结果 | 说明 |
|------|------|------|
| process | **7 passed** | echo / LookPath / timeout / MaxOutput / Status×2 / Kill |
| fs | **3 passed** | Write-Read-Remove / MkdirAll / OpenLocked |
| path | **4 passed** | Join-Clean / IsAbs-Volume / ToSlash / StripPrefix |
| os.env | **3 passed** | GetEnv / Set-Unset-Expand / Expand brace |
| fs.watch | **1 passed** | create **or** documents UNSUPPORTED (95) under Wine |

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

### Go 对照（`compare_go`，1MB×20）

```bash
cd core/benchmarks/nextpas.core.fs/bench_fs/compare_go && go run main.go
```

| 项 | 结果（量级） |
|----|----------------|
| SeqWrite 1MB×20 | ~2 GB/s |
| SeqRead 1MB×20 | ~0.4 GB/s |

块大小/迭代与 Pascal 不同，**不可直接除法对比**。

---

## C. process host-linux

```bash
make -C core/benchmarks/nextpas.core.process/bench_process run
cd core/benchmarks/nextpas.core.process/bench_process/compare_go && go run main.go
```

### nextpas（2026-07-20 刷新）

| 项 | n | total | avg |
|----|---|-------|-----|
| LookPath(sh) | 200 | 9 ms | ~45 µs |
| Command(/bin/true).Status | 50 | 50 ms | ~1.0 ms |
| Capture(echo x) | 50 | 597 ms | ~12 ms |

### Go 对照（同机）

| 项 | n | avg |
|----|---|-----|
| exec.LookPath(sh) | 200 | ~46 µs |
| exec.Command(true).Run | 50 | ~0.93 ms |
| exec.Command(echo).Output | 50 | ~1.3 ms |

LookPath 与 Status 量级接近 Go。`Capture` 路径更重（管道 drain + 框架），高于 Go `Output` 属预期，非 apple-to-apple。

---

## 复现清单

1. `git checkout` 对应 commit  
2. wine 五套件（需 `fpc -Twin64` + `wine`）  
3. `bench_fs` / `bench_process` + 各自 `compare_go`  

**不要**把 wine 结果写成「Windows production ready」。
