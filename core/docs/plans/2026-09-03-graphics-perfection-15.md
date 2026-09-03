# Graphics 匠心打磨 15 — 性能与稳定性深潜

**目标**：在 14 基础上（ab978732a）深挖性能/稳定性完整性，守 888 命名与 L0-L3，bench/demo 锁死

## 任务 DAG

| id | title | dependencies | 验收 |
|---|---|---|---|
| bench-image-verify | bench_image 1MB 单次固化与 --verify 锁表（512x512 Decode/Encode ns/op+MB/s，800us/MB 门禁） |  | `core/build/.../bench_image --verify` 0，`CONTRACT 0.2.1` 表格一致 |
| simd-raster-batch | simd.raster 批量亲和（FillTrapezoids 64-chunk 复用，RasterCopy/BlendVaried 单源，零 dispatch） |  | `bench_raster` 不回归，`G` 0 |
| effect-boxblur-tile | effect.graph.boxblur 64-tile 并行 + arena 复用 + heaptrc0 |  | `test_effect_graph` Tile64/Big 16M 0 |
| canvas-guard | canvas Save/Restore 栈与 AutoSave RAII 空栈抛 ECanvasError |  | `test_canvas_raster` SaveRestore 0 |
| image-dispatch-stress | image.dispatch 6格式应力（Probe/Detect/Try 不抛 + 16M cap fuzz） | bench-image-verify | `test_image_888_guard` + `test_image_gif` 全绿 |
| gate-verify | 门禁回归（HYGIENE/DIFF/G/I/C/V/DEMO md5 27b73e0d9a765c491bee8c85b367cef2） | simd-raster-batch, effect-boxblur-tile, canvas-guard, image-dispatch-stress | 四门禁全绿 |

> 约束：L2 零 platform.dl，facade 纯 re-export，bytes.ops 单源

## 执行层级
- L1 并行：`bench-image-verify, simd-raster-batch, effect-boxblur-tile, canvas-guard`
- L2 串行：`image-dispatch-stress` 依 `bench-image-verify`，`gate-verify` 依其余四项
