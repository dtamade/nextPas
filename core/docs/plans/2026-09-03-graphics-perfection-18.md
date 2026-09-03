# Graphics 匠心打磨 18 — 复用度与高级感深潜

**目标**：在 17 基础上（956fc1325）深挖复用度与高级感，守 888/0.2.1，bench/demo 锁死

## 任务 DAG

| id | title | dependencies | 验收 |
|---|---|---|---|
| reuse-bytes-ops | 复用收口 bytes.ops 单源零拷贝（Move/Span/BytesCopy 全链路单源） |  | `grep -r "Move(" core/src/nextpas.core.graphics.* -c` 0 旁路，`G` 0 |
| reuse-tpath-builder | TPathBuilder 批量单次 Reserve 零拷贝（COW BytesCopy 投影） | reuse-bytes-ops | `test_vector_tess` 0，`Single` 外部 Double 内部 1e-6 |
| canvas-simd-affinity | canvas.raster simd 亲和（Tile16 + pshufd/movdqu 16B 批，InlineVec 直联） | reuse-tpath-builder | `bench_raster` 0，`bench_inline_vs_dispatch` 0.75x |
| tui-bridge | tui 桥 L3 薄层（ICanvas→TUIRender，零平台硬依赖） | canvas-simd-affinity | `tui` demo 海报复用 ICanvas，不引 platform.dl |
| gate-verify | 门禁回归（HYGIENE/DIFF/G/I/C/V/DEMO md5 27b73e0d9a765c491bee8c85b367cef2） | reuse-bytes-ops, canvas-simd-affinity, tui-bridge | 四门禁全绿 |

> 约束：L0 仅 FPC RTL，L1 仅 L0，四件套，owner 边界严格

## 执行层级
- L1 并行：`reuse-bytes-ops`
- L2 串行：`reuse-tpath-builder` 依 `reuse-bytes-ops`，`canvas-simd-affinity` 依 `reuse-tpath-builder`，`tui-bridge` 依 `canvas-simd-affinity`，`gate-verify` 依其余三项
