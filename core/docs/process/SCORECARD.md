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
| OS | Linux x86_64 |
| 分支 | `process-fs-path-env`（合入前 lane） |
| 工具 | FPC 3.3.1；Wine 可用 |

---

## A. L2 wine-runtime-smoke（2026-07-20 本机）

```bash
make -C core/tests/nextpas.core.process/test_process_wine wine-runtime-smoke
make -C core/tests/nextpas.core.fs/test_fs_wine wine-runtime-smoke
make -C core/tests/nextpas.core.path/test_path_wine wine-runtime-smoke
make -C core/tests/nextpas.core.os.env/test_os_env_wine wine-runtime-smoke
```

| 套件 | 结果 | 说明 |
|------|------|------|
| process | **6 passed** | echo / LookPath / timeout / MaxOutput / Status×2 |
| fs | **2 passed** | Write-Read-Remove / MkdirAll |
| path | **3 passed** | Join-Clean / IsAbs-Volume / ToSlash |
| os.env | **2 passed** | GetEnv / Set-Unset-Expand |

Host `make test` 在非 Windows 上为 skip 分支（1 passed）。

---

## B. fs host-linux（nextpas.core.bench）

```bash
make -C core/benchmarks/nextpas.core.fs/bench_fs run
```

| 项 | Mean | Throughput | CV |
|----|------|------------|-----|
| SeqWrite/64KB | 34.93 µs | 1.75 GB/s | 1.9% |
| SeqRead/64KB | 10.81 µs | 5.65 GB/s | 1.7% |
| FileExists | 1.42 µs | — | 2.5% |
| FileSize | 1.42 µs | — | 2.5% |
| ReadAll/64KB | 130.58 µs | 478.6 MB/s | 1.1% |

### Go 对照（同机，`compare_go`，1MB×20）

```bash
cd core/benchmarks/nextpas.core.fs/bench_fs/compare_go && go run main.go
```

| 项 | 结果 |
|----|------|
| SeqWrite 1MB×20 | ~2080 MB/s |
| SeqRead 1MB×20 | ~402 MB/s |

**注意**：Go 基准块大小/迭代与 Pascal 64KB suite **不可直接除法对比**；仅作量级参考。

---

## C. process host-linux（bench_process）

```bash
make -C core/benchmarks/nextpas.core.process/bench_process run
```

| 项 | n | total | avg |
|----|---|-------|-----|
| LookPath(sh) | 200 | 9 ms | ~46 µs |
| Command(/bin/true).Status | 50 | 59 ms | ~1.2 ms |
| Capture(echo x) | 50 | 597 ms | ~12 ms |

Spawn 路径主导 Status/Capture；LookPath 为纯 PATH 搜索。

---

## 复现清单

1. `git checkout` 对应 commit  
2. wine 四套件（需 `fpc -Twin64` + `wine`）  
3. `bench_fs` + 可选 `compare_go`  
4. `bench_process`  

**不要**把 wine 结果写成「Windows production ready」。
