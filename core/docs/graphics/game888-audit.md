# game888 图形审计 — 反哺 nextpas.core 匠心清单

> 审计范围：`~/projects/game888/src` 4 份代表（`color_grading/procedural_texture/msdf_generator/font`），只读不搬，`worktree` 内落盘，不脏 `main`。
> 目标：让 `game888` 未来复用 `nextpas.core.graphics` 的 CPU 底座，而非 `core` 照搬 `game888` 的 RHI。
> 六维：模块化/性能/高级感/复用度/稳定性/完整性。

## 审计方法

- `grep -r TBitmap|Texture|Atlas|Path|ICanvas` → 470 `src/*.pas` 中图形 100+，RHI 双后端（`rhi/gl_device + vulkan_device + deferred/gpu_driven`）
- 真读 4 份：零猜测，逐行对照 `core` 已有 `image.png` 纯 Pascal 范例与 `graphics(L1)` 零 RTL 铁律
- 判定：**可抽→core** / **参考→core** / **保留→game888**，每项六维打分

## 1. `procedural_texture.pas` — 可抽（高优）

- **职责**：`TPixelRGBA + TPixelBuffer = array of TPixelRGBA`，`GenCheckerboard/Brick/Noise/GradientV/Metal/Grid/Wood` 7 种 CPU 过程纹理（`SimpleHash` 伪随机，`ClampByte/Lerp`）。
- **依赖**：仅 `nextpas.core.math/trig`，零 `gl`、零 `SysUtils`，零 RTL，完美符合 `core L2` 零依赖。
- **六维**：
  - 模块化 9/10：单职责纯函数，`Size+Color` 入参，`TPixelBuffer` 出参，可直接 `uses`。
  - 性能 7/10：双层 `for X/Y` 未 tiled/simd，`SimpleHash` 可 `simd` 批。
  - 高级感 8/10：`PixelRGBA` 工厂 + `LerpPixel` 流式雏形。
  - 复用度 9/10：`game888` 的 `assets/textures` 16 张贴图可由它程序化生成，`core` 的 `effect`/`image` 正缺。
  - 稳定性 8/10：`ClampByte` 边界完备，`Size<=0` 未抛 `EArgumentError`。
  - 完整性 7/10：缺 `Perlin/ValueNoise` 平滑噪声。
- **结论**：**可抽 → `nextpas.core.graphics.effect.procedural`**（或 `nextpas.core.procedural` L2）。反哺后 `game888` 改 `uses nextpas.core.graphics.effect.procedural`，`GenWood` 等 7 函直接复用；`core` 侧补 `tiled+simd` 与 `Perlin`。

## 2. `msdf_generator.pas` — 参考（中优，慎抽）

- **职责**：`TMSDFShape/Contour/Segment(skLine/skQuadratic)` + `SignedDistToLine/Quadratic(SolveCubicNormed)` + `ColorEdges + GenerateMSDF`（`Range` 映射 `255`）+ `BuildShapeFromOutline(FT_Outline → TMSDFShape)`，经 `platform.dl` `libfreetype.so` 取 `FT_Load_Glyph/Get_Char_Index`。
- **依赖**：`nextpas.core.math/trig + platform.dl + glyph_cache`，FT 结构手写 `FT_FaceRec/GlyphSlotRec`（`CPU64` 条件），`platform_dl_load` 双路径。
- **六维**：
  - 模块化 6/10：`MSDFVec2/Cross/Dot/Sub/Len` 与 `core.graphics` 的 `TVec2` 重名，`TMSDFParams` 与 `TBitmap` 未统一。
  - 性能 8/10：`SolveCubicNormed` 已 `ArcCos` 三根，`GenerateMSDF` 三通道(`ecRed/Green/Blue`) 批距，`Range` 可调。
  - 高级感 7/10：`ecRed..White` 位掩码 `and` 色彩分离有巧思。
  - 复用度 8/10：`core` 的 `graphics.text` 正缺 SDF，`font` 的 `atlas` 可复用。
  - 稳定性 6/10：`FT_Load_Glyph` 未判 `horiAdvance` 溢出，` platform_dl_load` 失败静默 `Exit` 无 `EFontError`。
  - 完整性 8/10：`Cubic` 未支持（仅 `Line/Quadratic`），`BuildShapeFromOutline` 未处理 `FT_CURVE_TAG_CONIC` 隐式点外其余。
- **结论**：**参考 → `core.graphics.text.sdf`**，不整文件搬。抽 `SignedDist* + ColorEdges + GenerateMSDF` 核心（`TVec2` 复用 `core.graphics`），`BuildShapeFromOutline` 的 FT 解析保留 `game888`（`core.font` 已有 `ttface`），避免 `core` 再绑 `libfreetype`。`core` 侧补 `Cubic` + `EFontError`。

## 3. `color_grading.pas` — 保留（不抽）

- **职责**：`TColorGrading` 封装 `TGLShaderProgram + TGLFullscreenQuad + GLuint LutTexture(3D)`，`CG_VS/FS` 内 `adjustTemperature + Brightness/Contrast/Saturation + LUT mix`，`GenerateNeutralLUT(Size*Size*Size*3)` + `Render(ColorTex)` 绑定 `GL_TEXTURE0/1`。
- **依赖**：`gl/glext + gl_mesh_buffer + gl_texture3d_internal + gl_fullscreen_quad`，重 `gl`，无 CPU 回退。
- **六维**：
  - 模块化 5/10：`TColorGrading.Enabled` 与 `core.effect` 的 `EEffectError` 职责重，但 `Render` 强绑 `gl`。
  - 性能 9/10：3D LUT `GL_RGB8` 线性，`mix` 一次，GPU 最优。
  - 高级感 9/10：`CG_FS` `temperature*0.1` 手感细腻。
  - 复用度 4/10：`core` 是 CPU `EffectGraph(Bake)`，`game888` 是 GPU `Render`，不通用。
  - 稳定性 7/10：`FLutTexture=0` 早退完备，`DestroyGLTexture3D` 成对。
  - 完整性 9/10：`Contribution/Brightness/Contrast/Saturation/Temperature` 全量。
- **结论**：**保留 → game888**。`core` 的 `graphics.effect` 保持 CPU `ColorConvert(P3)` + `EffectGraph` 序列化（`CONTRACT` 已补），`game888` 的 `color_grading` 仍走 `rhi`，仅共享 `TColor32/TRgba` 定义（`core.graphics.base`）。

## 4. `font.pas` — 参考（抽度量，不抽渲染）

- **职责**：`TFont(DoLoad/DoUnload/DoRenderText/DoGetTextSize)` 抽象 + `TMockFont`，`MeasureText/MeasureTextWrapped`（`#10/#13` 行拆 + `DoGetTextSize` 逐行 `W/H` + `LastSpace` 回退），`RefCount/AddRef/Release` 手写，`SupportsDirectDraw/DrawDirect` 桩。
- **依赖**：`nextpas.core.errors/base.utils/text.conv/fs + game888.graphics.texture/platform_utils`，`TTexture` 来自 `game888`。
- **六维**：
  - 模块化 7/10：`MeasureTextWrapped` 已 `LastSpace` 智能换行，`DoLoad` `NormalizePath` + `except DoUnload` 完备。
  - 性能 6/10：`MeasureTextWrapped` 内 `Copy` + `DoGetTextSize` 每字符一次，未缓存。
  - 高级感 6/10：`DefaultCharEffect` 工厂，但 `TMockFont` 硬 `Length*FSize div 2` 估算粗糙。
  - 复用度 7/10：`MeasureText` 的行宽/行高逻辑可反哺 `core.graphics.text` 的 `TTextLayout`。
  - 稳定性 8/10：`Load` 的 `try..except DoUnload` + `Unload` `finally` 干净。
  - 完整性 6/10：`TTextMetrics(LineWidths/Ascender)` 已够，未处理 `Grapheme`（`text.unicode`）。
- **结论**：**抽度量 → `core.graphics.text`**。`MeasureText/Wrapped` 的 `LineCount/LineWidths/MaxW` 合并成 `TTextLayout`，`TMockFont` 不抽；`DoRenderText→TTexture` 保留 `game888`（`core` 的 `canvas.DrawGlyphRun` 只收 `GlyphRun`）。

## 总清单（反哺 nextpas.core）

- **S1 可抽（零风险）**：`procedural_texture` 7 函 → `nextpas.core.graphics.effect.procedural` L2（`Checkerboard→Wood`，补 `tiled/simd + Perlin`）
- **S2 参考（慎抽）**：`msdf_generator` 的 `SignedDist* + GenerateMSDF` → `core.graphics.text.sdf`（复用 `TVec2`，补 `Cubic`），`font` 的 `MeasureText` → `TTextLayout`
- **保留（不抽）**：`color_grading` 全类（GPU LUT）、`rhi/*` 全族、`font.DoRenderText` 的 `TTexture` 路径

## 对 CPU/GPU 分离的验证

- `game888` 已验证分离：`procedural_texture/msdf` 纯 CPU（可进 `core` L2），`color_grading/rhi` 纯 GPU（留 `game888`），`core` 的 `canvas.raster + gpu.canvas(TAtlas)` 薄桥正好承接，不乱。
- 下一步：`core` S1 先吃 `procedural`（1 天），`game888` 改 `uses nextpas.core.graphics.effect.procedural` 验证复用，`core` 不碰 `rhi`。

> 落盘：`core/docs/graphics/game888-audit.md`（本文件），`worktree` 内，不进 `main`，`GOAL_TREE S1-00` 已记“存量抽取审计—game888 4份已验”。
