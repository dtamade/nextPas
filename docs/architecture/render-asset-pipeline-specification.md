# nextPas render asset pipeline 规范

用这份规范定义 nextPas 长期 render asset pipeline 的稳定边界。它回答的不是
“以后 shader 要不要先编译”或“icon atlas 先用几个脚本凑出来行不行”，而是
“shader、icon/image、font metadata、theme/effect sidecar assets 应该怎样从 source-facing
asset inputs 进入统一 Pascal GUI stack，才能让 nextPas 的 GUI framework、preview surface、
future IDE 和 cross-target distribution 共享同一条 render asset truth，而不是重新回到
toolkit runtime loader、platform image API、fontconfig 扫描和 UI 私有 post-build script
各管一段的历史结构”。

这份文档和 `gui-framework-specification.md`、`ui-rendering-specification.md`、
`ui-style-theme-specification.md`、`ui-text-layout-specification.md`、
`toolchain-specification.md`、`workspace-specification.md`、
`distribution-layout-specification.md`、`cross-compilation-specification.md`、
`ide-specification.md` 一起工作。前者们分别冻结 GUI 总骨架、rendering control plane、
style/theme control plane、text/layout control plane、工具链控制面、workspace truth、
公开发行布局、host/target 分离与 future IDE workbench；这里冻结 render asset pipeline
本身的正式边界。

## 先看 FPC 真源码已经把 render-side asset 能力分散成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `/home/dtamade/projects/fpc/packages/opengl/src/glext.pp`
  - 直接暴露 `glCreateShader`、`glShaderSource`、`glCompileShader`
  - 还暴露 `glCreateProgram`、`glLinkProgram`、`glGetShaderInfoLog`、
    `glGetProgramInfoLog`
  - 说明 shader source、compile/link lifecycle 和 info log 在 graphics binding 路线上天然会被推向运行时
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gdk-pixbuf/gdk2pixbuf.pas`
  - 直接暴露 `gdk_pixbuf_new_from_file`、`gdk_pixbuf_new_from_file_at_size`、
    `gdk_pixbuf_new_from_file_at_scale`
  - 还暴露 `gdk_pixbuf_animation_new_from_file`、`gdk_pixbuf_animation_get_iter`、
    `gdk_pixbuf_animation_iter_get_delay_time`、`gdk_pixbuf_animation_iter_advance`
  - 说明 image decode、rescale、animation frame timing 和 asset variant selection 都可以被 toolkit runtime 吞掉
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gdk-pixbuf/gdk-pixbuf-loader.inc`
  - 直接暴露 `gdk_pixbuf_loader_new`、`gdk_pixbuf_loader_new_with_type`、
    `gdk_pixbuf_loader_write`
  - 还暴露 `gdk_pixbuf_loader_get_pixbuf`、`gdk_pixbuf_loader_get_animation`、
    `gdk_pixbuf_loader_close`
  - 说明流式 image type detection 与 incremental decode 也是 runtime-local loader boundary
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkimage.inc`
  - 直接暴露 `gtk_image_new_from_file`、`gtk_image_new_from_pixbuf`、
    `gtk_image_new_from_icon_set`
  - 还暴露 `gtk_image_new_from_animation`、`gtk_image_set_from_file`、
    `gtk_image_set_from_animation`
  - 说明 widget surface 很容易直接吞掉 file/image/icon/animation resource loading
- `/home/dtamade/projects/fpc/packages/libfontconfig/src/libfontconfig.pp`
  - 直接暴露 `FcInitLoadConfigAndFonts`、`FcConfigGetFonts`、`FcConfigAppFontAddFile`、
    `FcConfigAppFontAddDir`
  - 还暴露 `FcConfigGetSysRoot`、`FcConfigSetSysRoot`、`FcDirCacheLoad`、
    `FcFreeTypeQuery`
  - 说明 font discovery、app font 注入、cache、sysroot 与 FreeType-facing query 本来就是正式资产边界
- `/home/dtamade/projects/fpc/packages/fcl-pdf/src/fpttf.pp`
  - 直接调用 `loadfontconfiglib('')`、`FcInitLoadConfigAndFonts()`
  - 还直接走 `FcConfigGetFilename`、`FcFontMatch`、`FcPatternGetString`
  - 说明实际应用代码会自己读取 font config、做 font match、解析字体文件落点
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSImage.inc`
  - 直接暴露 `imageNamed:`、`initWithContentsOfFile:`、`TIFFRepresentation`
  - 还暴露 `drawInRect:`、`CGImageForProposedRect:context:hints:`
  - 说明平台 image loading、representation conversion 和 draw-facing selection 天然也会留在宿主 API 里

这些事实组合起来说明：

- FPC 生态里并不是没有 shader、image、font 和 platform image resource 相关能力
- 它的问题是这些能力分散在 OpenGL binding、toolkit image loader、widget file loading、
  fontconfig binding 和平台 image API 里
- 当前源码树没有一份把 render-side asset source、tool invocation、bundle output、
  target/distribution 落点和 runtime consumption 收成统一 Pascal render asset pipeline 的正式架构

nextPas 如果不把这层单独冻结，future controls、preview surface、component gallery、IDE
workbench 和 package UI 很快又会各自长一套 shader build、icon packing、font lookup、
theme image preprocess 和 preview-only asset glue。

## render asset pipeline 必须是独立边界，而不是 rendering 或 toolchain 的一句注脚

`ui-rendering-specification.md` 已经冻结 `DrawPlan`、`RenderGraph`、`SurfaceFrame` 和
`RenderAssetBundle`；`toolchain-specification.md` 已经冻结 `ToolchainBinding` 与
`ToolInvocationPlan`；`workspace-specification.md` 已经冻结 `ArtifactRootSet`。但这些文档都不会替代
“source-facing asset truth 怎样稳定变成 target-aware render bundle”这条正式边界。

nextPas 在这里进一步冻结：

- rendering control plane 继续拥有 draw/submit/present 与 render-side contract
- toolchain control plane 继续拥有 tool discovery、invocation、failure mapping 与 cross binding
- workspace / distribution 继续拥有 artifact root 与公开落点语义
- render asset pipeline 负责把 shader、icon/image、font metadata、theme/effect asset 的
  source-facing truth 变成可验证、可安装、可复用的 render-side compiled input
- runtime、preview、IDE 和 app window 都只能消费同一份 bundle truth，而不是各扫各的资源目录

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| UI package / theme assets / font inputs / shaders    |
+------------------------------------------------------+
                            |
                            v
+------------------------------------------------------+
| RenderAssetSourceSet                                 |
| logical asset family / variants / preprocessing hint |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| ToolchainBinding + ToolInvocationPlan                |
| shader tool / atlas pack / font preprocess / verify  |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| RenderAssetBundle                                    |
| compiled shader pack / atlas / font metadata / maps  |
+---------------------------+--------------------------+
                            |
            +---------------+----------------+
            |                                |
            v                                v
+-----------------------------+  +-----------------------------+
| ArtifactRootSet / lib/share |  | UiRuntime / RenderBackend   |
| install / cache / replay    |  | preview / IDE / app consume |
+-----------------------------+  +-----------------------------+
```

这张图的硬约束是：

- source-facing asset truth 先被声明，再被编译
- `ToolInvocationPlan` 继续只是执行计划，不替代 asset 语义
- `RenderAssetBundle` 是 runtime-facing compiled input，不是 post-build 临时垃圾堆
- preview、IDE 和 app runtime 不能拥有第二套 asset pipeline

## 只新增两个 asset-specific 对象，不复制既有控制面

为了保持边界清楚且不过度膨胀，nextPas 在这条规范里只新增两个 asset-specific 对象：

- `RenderAssetSourceSet`
- `RenderAssetBundle`

其余对象继续直接复用已文档化边界：

- `ToolchainBinding`
- `ToolInvocationPlan`
- `ArtifactRootSet`
- `TargetFacts`

| 对象                   | 负责什么                                                                                                     | 明确不负责什么                                              |
| ---------------------- | ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------- |
| `RenderAssetSourceSet` | 表达 shader source、icon/image family、font input、theme/effect asset 与 preprocessing hints 的 source truth | 不直接找工具，不替代 workspace member graph                 |
| `RenderAssetBundle`    | 表达 target-aware compiled shader pack、atlas、font metadata、lookup table 和 render-side payload            | 不替代 package manifest，不充当 runtime config 或 IDE state |

这里最关键的边界是：

- `RenderAssetSourceSet` 先定义“要产出哪些 render-side 资产”
- `ToolchainBinding + ToolInvocationPlan` 再定义“用谁去产出它们”
- `RenderAssetBundle` 最后定义“runtime 真正消费的是哪份已编译结果”

## `RenderAssetSourceSet` 必须拥有 source-facing 资产真相，而不是一串裸路径

如果 nextPas 想现代、高性能、优雅，就不能把 GUI 资产长期写成“某个 package post-build 脚本顺手扫目录”。

因此 nextPas 冻结：

- `RenderAssetSourceSet` 必须先表达 logical asset family，而不是某个 widget 私有相对路径
- 它至少要能表达 shader source group、icon/image variant、theme/effect input、font input 与 preprocessing hint
- asset identity 应优先稳定到 package / workspace / theme family 级别，而不是运行时临时文件名
- same asset source set 必须能同时服务 app runtime、preview surface、component gallery 与 future IDE
- `RenderAssetSourceSet` 可以由 package/workspace 声明或聚合，但不允许直接变成“边扫目录边编译”

这条规则直接挡住几种坏结构：

- 每个 UI package 各写一份 shader compile shell
- preview pane 自己扫图片目录、IDE shell 再扫一份
- editor 字体输入、theme 图像输入、icon 输入各自藏在不同私有配置里

## `ToolchainBinding` 和 `ToolInvocationPlan` 继续是执行 owner，不被 asset 文档重造一遍

nextPas 不在这里重新发明第二套工具链模型。

因此这条规范明确：

- render asset pipeline 的工具选择继续来自 `TargetFacts + ToolchainBinding`
- shader compiler、atlas generator、font preprocessing helper、theme/image verifier 如果未来存在，
  继续以 `ToolInvocationPlan` 形式被调用
- asset pipeline 不直接拼 shell command，不直接把 host path 逻辑写死在 UI package 里
- cross target asset build 继续复用 host-to-target binding，而不是 UI 体系单独维护第二套平台矩阵

这条规则直接回应 FPC 里图像 loader、fontconfig 与 graphics API binding 各自自带执行前提的现实：
nextPas 不能因为“这是 GUI 资产”就把 tool invocation 重新打散。

## `RenderAssetBundle` 必须是 target-aware compiled input，而不是 runtime 临时缓存

`glShaderSource` / `glCompileShader`、`gdk_pixbuf_loader_write`、`FcFontMatch` 与 `NSImage`
这些事实都说明：如果边界不先冻结，runtime 很容易重新变成 shader compiler、image loader、
font scanner 和 bundle cache builder 的混合体。

因此 nextPas 冻结：

- `RenderAssetBundle` 是 render-side compiled input 的正式 owner
- 它至少要能表达 compiled shader payload、reflection/lookup metadata、atlas page/region mapping、
  font metadata、image/theme/effect sidecar payload 与必要的 integrity/version facts
- bundle identity 必须能解释 target key、asset source revision 与 render-side compatibility，不允许只剩临时文件名
- runtime 可以 lazy-load bundle section，但不应在每次启动时重做 compile/pack/match 热路径
- `RenderBackend` 消费 `RenderAssetBundle`，但不反向拥有 source asset truth

这条规则的意义很直接：

- preview capture、IDE panel、app window 和 offscreen snapshot 可以共用同一条 compiled asset truth
- cross-target build 可以明确回答“这是哪个 target 的 bundle”
- diagnostics、cache 和 replay 可以指向同一份 bundle 证据，而不是一堆瞬时中间文件

## style/theme、text/layout 和 rendering 只消费各自该看的部分

只要进入真实 GUI 系统，theme、text 和 rendering 就一定会与 render asset pipeline 相接。但 nextPas
在这里明确：

- `ThemeAssetSet` 继续拥有 semantic asset family，例如 icon role、theme image family、effect family
- `RenderAssetBundle` 只拥有 render-side compiled payload，不回头定义 semantic theme meaning
- `TextInputSession` 和 `TextLayoutSnapshot` 继续拥有 text truth，render asset pipeline 只处理 render-side
  font metadata、fallback/preprocessed lookup 或等价 sidecar
- `DrawPlan` / `RenderGraph` 继续拥有 frame-facing draw contract，不回头重新扫描原始 asset source

这条边界是为了避免：

- theme system 重新吞掉 bundle build
- text engine 自己长一套 font metadata pipeline
- backend 因为“自己好实现”就偷偷定义另一套 image/font/shader asset contract

## workspace 和发行布局只负责落点，不拥有资产语义本身

`workspace-specification.md` 已经冻结 `ArtifactRootSet`，`distribution-layout-specification.md`
已经冻结 `units/<target>/`、`lib/`、`share/` 的公开角色。render asset pipeline 继续复用这条边界：

- source-facing asset declaration 由 workspace/package truth 承载
- 当前最小 author-facing package manifest skeleton 由 `workspace-file-format-specification.md` 继续冻结，
  package workflow 对这些字段的消费语义由 `package-workflow-specification.md` 继续冻结
- reusable cache、generated sidecar、installed render bundle 由 `ArtifactRootSet` 解释归属
- private target-aware render bundle、compiled shader pack、pipeline metadata 继续落在
  `lib/nextpas/ui/render/` 或等价私有 `lib/` 子树
- shared theme/image/font examples、docs 和非 target-specific content 继续落在
  `share/nextpas/ui/` 或等价共享 `share/` 子树

不允许出现的坏结构是：

- bundle 生成后不知道自己属于 cache、install 还是 source tree
- preview 资产偷偷落进 source root
- IDE 自己缓存一套、CLI build 再装一套、distribution 再拷一套，但三者没有正式关系

## IDE、preview 和 app runtime 不允许拥有第二套 asset pipeline

nextPas 的 IDE 会是这套 GUI framework 的 flagship application，但它不允许把 render asset pipeline
重新私有化。

因此 nextPas 要求：

- IDE preview pane、component gallery、designer surface、workbench chrome 和 app runtime 都必须消费同一类
  `RenderAssetSourceSet -> RenderAssetBundle` 结果
- IDE 不允许长期依赖 preview-only asset scan、workbench-local icon registry、私有 shader cache
  或 webview resource shell
- package UI、controls gallery、preview tooling 和 shipped app 不能各自产生第二份 asset truth

这条规则是为了避免 GUI framework 和 IDE 又重新长成两套 render-side asset system。

## 性能模型必须从第一天进入 render asset pipeline 设计

既然用户目标是现代、高性能、优雅，asset pipeline 规范不能只谈“有没有资源文件”，不谈性能路径。

第一阶段先冻结这些性能方向：

- shader、atlas、font metadata 和 theme/image preprocessing 优先走 build-time 或 cacheable path
- asset change 优先做 source-set-level diff，不优先整目录重扫
- target-neutral source identity 与 target-aware bundle identity 必须分开，避免 cache key 混乱
- runtime bundle access 应优先支持 lazy section load、stable lookup 和 cheap validation
- same source set 产出的 bundle 应能同时服务 preview、IDE 和 app runtime，减少双实现和双缓存

这几条不等于现在就锁死 bundle file format；它们只是保证架构不会天然把 asset hot path 做差。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 先只冻结 render asset pipeline 的对象边界和相邻职责
  - 不承诺当前最小 `nextpas build` 立刻支持 shader tool、font preprocess、theme pack 或 IDE preview bundle
- `stage1`
  - 可以开始实现最小 `RenderAssetSourceSet`
  - 可以开始为最小 `RenderAssetBundle`、icon/image preprocessing、font metadata sidecar 或 offscreen proof path 预留正式入口
  - 但不承诺完整 shader language matrix、designer asset authoring 或 full asset studio
- `stage2`
  - 只有当 rendering、toolchain、workspace、distribution 和 IDE workbench 都稳定后，才值得继续调查 richer
    asset inspector、hot reload、incremental preview bundle rebuild 与更完整的 visual workflow

## 第一阶段非目标

- 不把这份规范写成具体 shader language、binary pack format 或 atlas algorithm 的锁死清单。
- 不让 runtime 成为长期默认的 shader compile、font scan、image pack 热路径。
- 不把每一种 render-side asset family 都拆成独立产品线或私有 CLI。
- 不让 IDE、preview tooling、package hook 或 backend 长出第二套 asset pipeline。
- 不把 Cocoa / GTK / OpenGL / fontconfig 的现成 runtime API 误写成 nextPas 的长期公开资产架构。

第一阶段真正要交付的是：一条把 render-side source inputs、toolchain invocation、compiled bundle、
workspace/distribution 落点与 runtime consumption 接成同一控制线的正式 render asset pipeline 规范。
