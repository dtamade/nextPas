# Graphics 匠心打磨 17 — L3 与跨语言对标收口

**目标**：在 16 基础上（8b2a46749）向 L3 与对标完整性收口，守 888/0.2.1，零 pure 回退

## 任务 DAG

| id | title | dependencies | 验收 |
|---|---|---|---|
| gpu-canvas | gpu.canvas L3 薄封装（ICanvas→GPU 批，零平台硬依赖，L3 仅依 L1-L2） |  | `nextpas.core.gpu.canvas.pas` 门面 re-export + `gpu.canvas.impl` 薄层，`make hygiene` 0 |
| bench-parity | 跨语言 bench 对标固化（Go 1.22/tiny-skia 0.11，bench_raster/bench_image 单次 ns/op+MB/s） | gpu-canvas | `benchmarks/COMPARISON.md` 锁表更新，`bench --verify` 0 |
| effect-lut-cache | effect.graph LUT 缓存与 tile64 arena 复用深化 |  | `test_effect_graph` 箱式 1024×1024 r32 线性，heaptrc0 |
| simd-raster-verify | simd.raster x86_64 SSE2 pshufd 批写 16B + scalar 回退双路径验证 | effect-lut-cache | `bench_inline_vs_dispatch` 0.75x ≤0.9x |
| gate-verify | 门禁回归（HYGIENE/DIFF/G/I/C/V/DEMO md5 27b73e0d9a765c491bee8c85b367cef2） | bench-parity, simd-raster-verify | 四门禁全绿，poster golden PASS |

> 约束：L3 仅依 L0-L2，门面纯 re-export，bytes.ops 单源

## 执行层级
- L1 并行：`gpu-canvas, effect-lut-cache`
- L2 串行：`bench-parity` 依 `gpu-canvas`，`simd-raster-verify` 依 `effect-lut-cache`，`gate-verify` 依其余三项
