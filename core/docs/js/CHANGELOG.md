# nextpas.core.js 变更日志

**格式**：Keep a Changelog + SemVer
**关联**：`CONTRACT §13`（稳定性）

---

## [0.7.0] - 2026-08-30 — 六维硬化 P0 清零

- `CONTRACT` 体积指引 500/800 双阈值、`Close` 幂等、线程 debug/release、SemVer、徽章（`SIXDIM M-1/M-2/S-2/S-3/S-4/L-3`）
- `TESTING` `INV→用例` 映射、`B/op=0` 零分配断言、`fake` 通用复用、`Close` 幂等（`SIXDIM S-1/P-3/R-2/S-3`）
- `DESIGN` 增 mermaid 分层图、中断轮询缓存行对齐、体积预案（`SIXDIM L-1/P-2/M-1/M-2`）
- `BENCHMARKS` 补 p50/p99/warmup/`B/op`、`bench_batch` 实测阈值（`SIXDIM P-1/P-4`）
- `ROADMAP` 补工期/人力列、`webview.fake.js` 归属明示（`SIXDIM C-2/M-4`）
- `ACCEPTANCE` 12→18 份同步、`wc -l` 体积门禁、`INV` 映射回归（`SIXDIM C-3/M-5`）
- `AI_GUIDE` 体积双阈值 + 跨模块协作（`SIXDIM M-1/M-4`）
- `README` 17→18 份、`CHANGELOG` 语义化闭环

## [0.6.0] - 2026-08-30 — 六维硬化

- 增 `SIXDIM_REVIEW.md`（18 项，P0 6 + P1 12）
- 增 `CHANGELOG.md` 本文件
- `DESIGN` 0.5→0.6：批处理阈值实测定、静链/动探权衡、中断轮询量化
- `README` 0.5→0.6：补 `demo_js.lpr` 可拷贝、15→16 份索引

## [0.5.0] - 2026-08-30 — 借鉴与运营

- 增 `GAME888_BORROW.md` / `FAQ.md` / `DECISIONS.md`（6 借鉴 + 4 不借鉴）
- `DESIGN` 反哺批处理/模块加载器

## [0.4.0] - 2026-08-30 — 冻结 12 份

- 增 `REVIEW/ROADMAP/ACCEPTANCE/AI_GUIDE/TESTING/SECURITY/BENCHMARKS`
- `CONTRACT/DESIGN/GOAL_TREE` 0.3→0.4

## [0.3.0] - 2026-08-30 — 生产级骨架

- 7 单元布局、双层值模型、三形态宿主、超时/内存限

## [0.1.0] - 2026-08-30 — 初稿

- 7 单元草图

