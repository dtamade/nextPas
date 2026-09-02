# nextpas.core.sevenz 终局路线图 — 166 封版（完美增量收口）

> L2 标杆的“完美”定义：性能·高级感·复用度·稳定性·完整性 五维同封。

## 当前封版快照（2026-09-01）

- **166 tests** `make -C core/tests/nextpas.core.sevenz/test_sevenz clean test` `heaptrc OK` `warnings 0`
- **hygiene** `scripts/build-hygiene-check.sh = pass` `git diff --check = 0`
- **bench** `bench_sevenz` 2k + 10k `IgnoreCase` 基线（`prefix* 129k / *suffix 625 / p*s 649 / exact 1.9M` ops/s, 10k 红线固化）
- **interop** `scripts/sevenz-interop.sh` p7zip 17.05 双向 + `BZip2+IgnoreCase` 200 条目混合档
- **落地** `main e73722e91` 基线 → 本 worktree `sevenz` 完美增量（db6747a01 全量 + bench/interop 闭环）

## 五维验收

| 维 | 已交付 | 度量 |
|----|--------|------|
| 性能 | `FLowerNames+SortedIdxIgnoreCase/Rev` 零分配；`CompareReversed`；`ExtractIndicesGrouped` 单 folder 单 decode；`TBytesViewStream` 零拷贝 | `FindByPrefix 0 alloc O(log N)` `extract multi 100-130 MB/s` |
| 高级感 | `ExtractAll` + `IgnoreCase` 全族 + `Try*WithError` + `FlushExtractedToFs` | API 一致、for..in、Builder 链式、progress 零开销 |
| 复用度 | `levels/filters/coders` 纯映射表驱动（`base` 阈值单源，无 `limits` 第二公共源）；`sevenz.fs` 去重 | 单 truth，无复制 |
| 稳定性 | `ESevenZLimitError` 炸弹全门；`Move+CRC` 单遍；`LRU 2-entry + ClearCache` | 64MiB/8GiB/1M/64KiB/256KiB 全覆盖 |
| 完整性 | `README + CONTRACT + TEST` 同版，bench + interop 双证 | `scripts/sevenz-interop.sh` p7zip 17.05 双向 |

## 已收口的完美增量（2026-09-01）

1. ✅ `EntriesByGlobIgnoreCase` 对 `prefix* / *suffix / prefix*suffix` 复用 `IgnoreCase` 索引（`LowerBoundPrefixIgnoreCase / SuffixIgnoreCase` + `FilterIndicesBySuffixIgnoreCase`）— 收益 `O(N)→O(log N+M)`，2k `prefix* 137k / *suffix 5.2k / p*s 4k / exact 2.4M` ops/s。
2. ✅ `TryExtractByPrefixIgnoreCaseToFs` / `TryExtractBySuffixIgnoreCaseToFs` 补 `Try*` 完整闭环（与 `TryGlobIgnoreCaseToFs` 对齐，复用 `FlushExtractedToFs`）。
3. ✅ `bench_sevenz` 增 `IgnoreCase` 10k 条目压测基线（`BenchGlobIgnoreCase10k`：10k 语料 `prefix* 129k / *suffix 625 / p*s 649 / exact 1.9M` ops/s，红线 `1000/500/300/100k` 固化，bench 可观测）。
4. ✅ `interop` 增 `BZip2 + IgnoreCase` 混合档（`scripts/sevenz-interop.sh` `bzip2-glob`：200 条目 `Pref_*_Suf.TXT` BZip2 压缩，`7z t` + `ExtractByGlobIgnoreCase` 双向验证）。

以上增量已全部落地，166 封版在 `db6747a01` 全量上完成六维闭环。

## 推广

以本 roadmap 为模板封 `zip / crypto / http`：先冻结 truth object 与炸弹门，再扩能力面，始终 `make hygiene + heaptrc + bench + interop` 四证同行。
