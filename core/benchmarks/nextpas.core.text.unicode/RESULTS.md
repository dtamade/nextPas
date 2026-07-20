# Unicode Benchmark Results (SCORECARD)

## 环境

- **OS**: Linux x86_64
- **CPU**: Intel Xeon E5-2696 v4 @ 2.20GHz (44 cores)
- **FPC**: 3.3.1 (-O2)
- **Go**: `golang.org/x/text` v0.40 + std `strings`
- **日期**: 2026-07-20
- **nextPas tip**: text-unicode perf (CaseFold Latin-1 + MapAscii)

## 测项说明

| 名称 | 含义 |
|------|------|
| `CaseFoldSimple *` | **逐码点**循环 `CaseFoldSimple`（含 UTF-8 迭代） |
| `UTF8CaseFoldSimple *` | **整串** `UTF8CaseFoldSimple`（与 Go `ToUpper`/`ToLower` 更可比） |
| NFC/NFD | 整串规范化 |

## nextPas 实测 (micro, 300k iters)

| 操作 | ns/op | 备注 |
|------|------:|------|
| UTF8CaseFoldSimple ASCII-200 | **447** | ASCII 批处理 MapAscii |
| UTF8CaseFoldSimple BMP-Latin | 2250 | Latin-1 表 + 串构建 |
| NFC ASCII-200 | **83** | IsAsciiString 快路径 |
| NFC BMP-Latin-50 | **4216** | O(1) decomp + buffer reuse |
| NFD BMP-Latin-50 | 3220 | 分解路径 |
| IsAsciiString ASCII-200 | ~53 | 8 字节并行 |

## Go 对照 (go test -bench, 同机)

| 操作 | ns/op |
|------|------:|
| ToUpper ASCII-200 | 2899 |
| ToUpper BMP-Latin-50 | 2440 |
| NFC ASCII-200 | 268 |
| NFC BMP-Latin-50 | 2822 |
| NFD BMP-Latin-50 | 23052 |

## SCORECARD（nextPas / Go，<1 更快）

| 操作 | 比率 | 判定 |
|------|-----:|------|
| 整串 CaseFold/ToUpper ASCII-200 | **0.15×** | nextPas 大幅领先 |
| 整串 CaseFold BMP-Latin | **0.92×** | 持平/略快 |
| NFC ASCII-200 | **0.31×** | nextPas 领先 |
| NFC BMP-Latin | **1.49×** | 改善自 1.81×；目标 1.2× 未完全达到 |
| NFD BMP-Latin | **0.14×** | nextPas 大幅领先 |

### 相对历史 RESULTS.md

旧表将「CaseFoldSimple ASCII-200 ~4043 ns」与 Go ~200 ns 对比，**测项不对齐**（逐码点 vs 整串）。
整串 API 对齐后，ASCII CaseFold **不再落后**。

## 本轮优化（NFC BMP-Latin 热路径 2026-07-20b）

1. `TCodepointBuffer` 预留 + Append 容量检查；Compose `DeleteAt` 用 `Move`
2. `SortCanonicalOrder` 栈上 CCC 缓存（≤256）
3. `BufferToUtf8` 直接 `UTF8Encode`
4. `threadvar GNormBuffer` 复用 capacity
5. BMP 分解 **O(1)**：`DECOMP_KIND_BMP` + `DECOMP_BMP_INDEX`（`normalize_bmp_index.inc`）
6. 拉丁单层分解 Len=2 快路径

## 先前优化

1. `CaseFoldSimple`：U+0000..U+00FF 走 `CASE_FOLD_LATIN1` 直表
2. `MapAsciiString`：指针单遍，减少索引开销
3. Bench 增加 `UTF8CaseFoldSimple` 整串测项

## 正确性门禁

- `test_conformance_case` 全绿
- `test_conformance_normalize` 全绿

## 下一轮候选

- NFC BMP-Latin 分解/组合路径减分配（逼近 Go 1.2× 内）
- CaseFold BMP stage-2 全表（非 Latin-1）
