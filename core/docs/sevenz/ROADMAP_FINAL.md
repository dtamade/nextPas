# nextpas.core.sevenz 终局路线图 — 163 封版

> L2 标杆的“完美”定义：性能·高级感·复用度·稳定性·完整性 五维同封。

## 当前封版快照（2026-08-28）

- **163 tests** `make -C core/tests/nextpas.core.sevenz/test_sevenz clean test` `heaptrc OK` `warnings 0`
- **hygiene** `scripts/build-hygiene-check.sh = pass` `git diff --check = 0`
- **落地** `main aefae745f` `codex/core-sevenz → origin/main`

## 五维验收

| 维 | 已交付 | 度量 |
|----|--------|------|
| 性能 | `FLowerNames+SortedIdxIgnoreCase/Rev` 零分配；`CompareReversed`；`ExtractIndicesGrouped` 单 folder 单 decode；`TBytesViewStream` 零拷贝 | `FindByPrefix 0 alloc O(log N)` `extract multi 100-130 MB/s` |
| 高级感 | `ExtractAll` + `IgnoreCase` 全族 + `Try*WithError` + `FlushExtractedToFs` | API 一致、for..in、Builder 链式、progress 零开销 |
| 复用度 | `levels/filters/coders/limits` 纯映射表驱动；`sevenz.fs` 去重 | 单 truth，无复制 |
| 稳定性 | `ESevenZLimitError` 炸弹全门；`Move+CRC` 单遍；`LRU 2-entry + ClearCache` | 64MiB/8GiB/1M/64KiB/256KiB 全覆盖 |
| 完整性 | `README + CONTRACT + TEST` 同版，bench + interop 双证 | `scripts/sevenz-interop.sh` p7zip 17.05 双向 |

## 下一完美增量（可选，不阻塞封版）

1. `EntriesByGlobIgnoreCase` 对 `prefix* / *suffix / prefix*suffix` 复用 `IgnoreCase` 索引（现为线性 `MatchesGlobIgnoreCase`）— 收益 `O(N)→O(log N+M)`。
2. `TryExtractByPrefixIgnoreCaseToFs` 补 `Try*` 完整闭环（现已 `TryGlobIgnoreCase`）。
3. `bench_sevenz` 增 `IgnoreCase` 10k 条目压测基线并固化红线。
4. `interop` 增 `BZip2 + IgnoreCase` 混合档的 `7z x` 回放。

以上均为“锦上添花”，当前 163 已满足 L2 封版的全部硬门槛。

## 推广

以本 roadmap 为模板封 `zip / crypto / http`：先冻结 truth object 与炸弹门，再扩能力面，始终 `make hygiene + heaptrc + bench + interop` 四证同行。
