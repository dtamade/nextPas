# Graphics 匠心打磨 14 — 六维收口（锁 888 命名）

**目标**：在 0.2.1 基线（ff8c72aad）上完成剩余六维债务，守 L0-L3/四件套/owner/hygiene，**纯Pas 后端恒为 `nextpas.core.graphics.<fmt>.<fmt>888` 禁止 `*.pure / image.gif`**，bench/demo md5 不变

## 任务 DAG

| id | title | dependencies | 验收 |
|---|---|---|---|
| fill-modular | canvas.raster.fill 模块化拆分（facade + solid/gradient，零逻辑，四件套，<800行） |  | `fill.pas` 纯 re-export + `fill.solid.pas`/`fill.gradient.pas` 实现，`make hygiene` 0 |
| vec-tess-perf | vector.tess 性能收口（EPSILON 单源、Double 内部、tess 复用） |  | `bench_raster` 不回归，`G/I/C/V` 0 |
| effect-procedural | effect.procedural 反哺复用（Wood/Perlin 批接口，simd 亲和） |  | `test_effect_graph` 0，零 `platform.dl` |
| bitmap-cow | canvas.raster.bitmap COW/EnsureUnique 资源闭环 |  | `heaptrc 0`，`Premultiply/Clone` 隔离 |
| image-888-guard | image 888 命名守卫（禁止 pure 回退，dispatch 6格式注册不变） | fill-modular | `grep -r "\.pure" core/src --include="*.pas"` 0，`image.pas` 仍 `graphics.gif/jpeg/webp/qoi.888` |
| gate-verify | 门禁回归（HYGIENE/DIFF/G/I/C/V/DEMO md5 27b73e0d9a765c491bee8c85b367cef2） | vec-tess-perf, effect-procedural, bitmap-cow, image-888-guard | `make hygiene` pass + `demo_vector_poster` md5 匹配 |

> 约束：`id` 小写短横线，L1 仅 L0、L2 仅 L0-L1，facade 纯 re-export，`pure` 为禁词

## 执行层级
- L1 并行：`fill-modular, vec-tess-perf, effect-procedural, bitmap-cow`
- L2 串行：`image-888-guard` 依 `fill-modular`，`gate-verify` 依其余四项
