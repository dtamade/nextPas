# 2026-08-30 图形框架定版（4+1 家族）

**分支**：`codex/core-graphics`（`.worktrees/core-graphics`，基 `main` 894a57b）
**状态**：S0 文档定版，不涉及 `src/`，可持续多月迭代

## 1. 定版结论

- **L1 单底座**：`nextpas.core.graphics`（`graphics.base` 聚合 `Color/Rect/Mat2D/Path/Stroke/Gradient`），不拆 `color/geometry/bitmap` 三独立模块
- **L2 能力**：`image(扩，含TBitmap)` + `vector` + `canvas(CPU)` + `effect`，只依赖 L0-L1
- **L3 薄桥**：`nextpas.core.gpu.canvas`（Texture/Atlas，复用 `gpu.gl`），不塞进 `canvas`
- **消费者外置**：`directui` 等上层为验证消费者，专业图像能力由本家族支撑（`document` 应用模型落 `packages/`，不进 core）

裁决理由见 `core/docs/graphics/ARCHITECTURE.md §4`。

## 1.1 铁律（S0 冻结）

- **零直引 FPC RTL**：禁止 `uses SysUtils/Classes/Graphics/FPImage/Types`，缺失反哺 `nextpas.core`（`nextpas.core.fs` 管文件、`text.conv` 管转换、`bytes/checksum` 管字节，`image.png` 已示范），`units/<target>/` stub 仅过渡
- **存量抽取**：`examples/tools/benchmarks` 中图形 helper（tiled 缩放/`stb_image` 包装等）S1 前审计迁入 `image/effect/vector`，不在应用私养；抽不动记 `PARITY §暂缺反哺项`
- **超越 Go/Rust**：统一值类型 + 非破坏 `EffectGraph` + 双形态错误 + `nextpas.core.bench` 双指标（锁版本 Go 1.22/tiny-skia 0.11），详见 `ARCHITECTURE §7`/`PARITY`；仅能力支撑，不绑定具体产品形态

## 2. 依赖与分层

```
graphics(L1, base/math, 零 bytes/font) → image/vector/canvas/effect(L2) → gpu.canvas(L3) → window/gpu.gl
                                    ↑ graphics.text 薄层产 GlyphRun → canvas.DrawText（canvas 不直依赖 font L3）
```

符合 `design-conventions.md` 四件套按需、`registry` 单向依赖。

## 3. 文档落点

- `core/docs/graphics/README.md`（入口）
- `core/docs/graphics/CONTRACT.md`（类型/错误/线程/门禁）
- `core/docs/graphics/ARCHITECTURE.md`（依赖图 + gui-framework 交接）
- `core/docs/graphics/ROADMAP.md`（S0→S3 活文档）
- `core/docs/graphics/GOAL_TREE.md`（可勾选目标树）
- `core/docs/graphics/PARITY-go-rust.md`（Go/Rust 对标）

## 4. Registry 预案（S1 才改）

```diff
+| `graphics` | L1 | 值类型底座（Color/Geometry/Path/Mat） | yes | L0 only (`base/math`) | draft |
+| `vector`   | L2 | 矢量内核（路径布尔/描边/细分）        | yes | L0-L1                   | draft |
+| `canvas`   | L2 | 2D 画布（ICanvas+CPU光栅）            | yes | L0-L1                   | draft |
+| `effect`   | L2 | 滤镜图（Blur/Shadow/Hue/LUT）         | yes | L0-L1                   | draft |
 | `image`    | L2 | 图像编解码（已存在，扩展 TBitmap）    | yes | L0-L1                   | focused-runtime → draft 扩展期 |
+| `gpu.canvas`| L3| 位图→Texture/Atlas 桥                  | yes | L0-L2 + gpu.gl/platform.dl | draft |
```

## 5. S0 门禁

- `make hygiene` + `git diff --check` 通过
- `core/docs/graphics/**` 6 文件 + 本计划 1 文件，共 7 文件，无 `src/` 变更

## 6. 后续批次

见 `ROADMAP.md` S1→S3，每批独立 `feat:` 提交，不 raw merge。
