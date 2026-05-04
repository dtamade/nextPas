# nextPas UI style/theme 规范

用这份规范定义 nextPas 长期 UI style/theme control plane 的稳定边界。它回答的不是
“以后 theme 文件写成 JSON、CSS-like DSL 还是别的什么格式”，而是“semantic color、typography、
icon、stateful appearance 和 visual asset 应该怎样进入统一 Pascal UI stack，才能让
nextPas 的 GUI framework、editor、future IDE 和 preview surface 共享同一条 visual truth，
而不是重新回到 toolkit style object、palette 常量、platform appearance API 和 IDE 私有皮肤
各管一段的历史结构”。

这份文档和 `gui-framework-specification.md`、`platform-shell-specification.md`、
`ui-runtime-specification.md`、`ui-interaction-specification.md`、
`ui-layout-specification.md`、`ui-motion-specification.md`、
`ui-text-layout-specification.md`、`ui-accessibility-specification.md`、
`ui-rendering-specification.md`、`ide-specification.md`、`toolchain-specification.md`、
`distribution-layout-specification.md` 一起工作。前者们分别冻结 GUI 总骨架、platform shell
宿主边界、runtime control plane、interaction control plane、general layout control plane、
motion control plane、text/layout control plane、accessibility control plane、rendering control plane、
future IDE workbench、toolchain control plane 与公开发行布局；这里冻结 style/theme 本身的正式控制面。

## 先看 FPC 真源码已经把 style / theme / palette / appearance 能力分散成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkstyle.inc`
  - 直接暴露 `gtk_style_get_font`、`gtk_style_set_font`
  - 还暴露 `gtk_style_set_background`、`gtk_style_lookup_icon_set`、`gtk_style_render_icon`
  - 说明 font、background、icon lookup 和 icon render 在 toolkit 里天然被写成 style object 的一部分
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkwidget.inc`
  - widget class 里直接保留 `style_set`
  - 还直接暴露 `gtk_widget_style_get_property`、`gtk_widget_style_get`
  - 说明控件 visual property 查询和 style change callback 在 toolkit 路线上本来就深绑在 widget 生命周期上
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkrc.inc`
  - 直接暴露 `gtk_rc_get_default_files`、`gtk_rc_parse`、`gtk_rc_parse_string`、`gtk_rc_reparse_all`
  - 还暴露 `gtk_rc_style_new`、`gtk_rc_style_copy`、`gtk_rc_get_theme_dir`
  - 说明 theme source、theme parse、theme reload 和 style object allocation 都是真实控制面
- `/home/dtamade/projects/fpc/packages/fv/src/views.inc`
  - 长期把 `CScrollBar`、`CScroller`、`CListViewer`、`CBlueWindow` 这类 palette 常量写进源码
  - `TScrollBar.GetPalette`、`TScroller.GetPalette`、`TListViewer.GetPalette`、`TWindow.GetPalette`
    直接返回这些 palette
  - `TWindow.Init` 还直接 `Palette := wpBlueWindow`
  - 说明 visual palette 在历史 TUI/UI 路线里经常被写成控件局部常量和默认值
- `/home/dtamade/projects/fpc/packages/fv/src/dialogs.inc`
  - 直接写 `CButton`、`CInputLine`、`CDialog` 这类 palette 常量
  - `TDialog.GetPalette`、`TInputLine.GetPalette`、`TButton.GetPalette` 也分别返回局部 palette
  - 说明 dialog / input / button 的 visual truth 同样是分散的 widget-local palette
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSWindow.inc`
  - `NSWindow` 直接实现 `NSAppearanceCustomizationProtocol`
  - 还暴露 `setAppearance`、`appearance`、`effectiveAppearance`
  - 说明平台 appearance 与 effective visual state 是真实宿主事实
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSColorList.inc`
  - 暴露 `colorListNamed`、`setColor:forKey:`、`colorWithKey`
  - 说明 named color list / palette registry 在平台层是真实对象
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSWorkspace.inc`
  - 暴露 `iconForFile`、`iconForFiles`、`iconForFileType`、`setIcon:forFile:options`
  - 说明 icon family 和 appearance-facing asset lookup 也是平台能力的一部分

这些事实组合起来说明：

- FPC 生态里并不是没有 style/theme/palette/appearance 能力
- 它的问题是这些能力分散在 GTK style object、RC parser、Free Vision palette 常量和 Cocoa
  appearance / color / icon API 里
- 当前源码树没有一份把 semantic token、resolved visual state、theme asset family 和
  stateful appearance resolution 收成统一 Pascal style/theme control plane 的正式架构

nextPas 如果不把这层单独冻结，future controls、code editor、project tree、command palette、
preview surface 和 IDE workbench 很快又会各自长一套 palette、icon registry、focus ring 和
dark/light appearance 真相。

## style/theme 必须是 GUI stack 里的独立控制面，而不是 rendering 或 widget state 的附注

`gui-framework-specification.md` 已经冻结 `UiScene`、`UiRuntime`、`RenderBackend`、
`PlatformShell` 四层骨架；`ui-interaction-specification.md` 已经冻结 input/focus/command
control plane；`ui-layout-specification.md` 已经冻结 general layout；`ui-rendering-specification.md`
已经冻结 rendering control plane。但这些文档都不会替代 style/theme 自身的正式边界。

nextPas 在这里进一步冻结：

- `UiScene` 继续拥有 control role、component variant、content kind 和 coarse style intent 的语义入口
- interaction control plane 继续拥有 focus、hover、pressed、selected、disabled、active capture
  这一类 visual-facing state truth
- style/theme control plane 负责把 semantic token、interaction state、platform appearance、
  contrast-facing accessibility preference 和 package-provided visual asset family 收成稳定 visual truth
- motion control plane 继续负责 temporal behavior、transition scheduling 和 reduced-motion adaptation
- layout 继续消费 resolved metric input，text/layout 继续消费 resolved typography input，
  rendering 继续消费 resolved paint / icon / image / effect input
- IDE workbench 不允许因为“先做出来”就长出第二套 palette/theme system

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| Pascal app / IDE workbench / preview surface         |
+------------------------------------------------------+
                            |
                            v
+------------------------------------------------------+
| UiScene                                              |
| role / variant / content kind / style intent         |
+--------------------+-------------------+-------------+
                     |                   |
                     v                   v
         +------------------+  +----------------------+
         | InteractionRouter|  | PlatformShell /      |
         | focus / hover /  |  | accessibility prefs  |
         | pressed / select |  | appearance / contrast|
         +---------+--------+  +----------+-----------+
                   \                   /
                    \                 /
                     v               v
+------------------------------------------------------+
| StyleResolver                                        |
| token lookup / state merge / appearance adaptation   |
+-------------+----------------------+-----------------+
              |                      |
              v                      v
+----------------------+  +----------------------------+
| ThemeSnapshot        |  | ThemeAssetSet              |
| color / type /       |  | icons / images / font      |
| metric / effect refs |  | aliases / appearance sets  |
+------+------+--------+  +-------------+--------------+
       |      |                         |
       v      v                         v
  Layout   TextLayout             RenderAssetBundle
       \      |                         /
        \     |                        /
         +----+-----------------------+
                      |
                      v
            DrawPlan / RenderBackend
```

这张图的硬约束是：

- visual truth 在 `UiScene` 和 layout / text / rendering 之间显式存在
- interaction state 是正式输入，但 interaction 不直接拥有 appearance semantics
- rendering 只消费 resolved style，不反向拥有 theme meaning

## 只冻结四个 style/theme 对象，不把这层膨胀成名词森林

为了保持边界清楚且不过度膨胀，nextPas 在 style/theme 上只冻结四个核心对象：

- `ThemeToken`
- `StyleResolver`
- `ThemeSnapshot`
- `ThemeAssetSet`

| 对象            | 负责什么                                                                                                    | 明确不负责什么                                           |
| --------------- | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| `ThemeToken`    | 表达 semantic visual role，例如 surface、text、border、focus ring、icon、density、typography variant        | 不直接等价平台颜色结构体，不直接持有 GPU resource        |
| `StyleResolver` | 把 token、component role、interaction state、platform appearance 与 accessibility preference 解析成正式样式 | 不直接做 layout，不直接做 draw command                   |
| `ThemeSnapshot` | 表达某次稳定 visual revision 下的 resolved color、typography、metric、effect 与 stateful appearance 结果    | 不自己生成 scene，不替代 `LayoutSnapshot` 或 `DrawPlan`  |
| `ThemeAssetSet` | 表达 icon family、image slice、font alias、appearance variant 与 theme-pack-facing asset family             | 不直接等价 render bundle，不保存第二份 workspace/package |

这里最关键的边界是：

- `ThemeToken` 先定义“这类 UI 要表达什么视觉角色”
- `StyleResolver` 再定义“在当前 state / appearance 下应解析成什么样”
- `ThemeSnapshot` 定义“这一轮 UI revision 的稳定 visual truth 是什么”
- `ThemeAssetSet` 最后定义“哪些 icon / image / font alias family 属于这个 theme”

## `ThemeToken` 必须先是 semantic token，而不是 raw color / raw font 常量

GTK style object、Free Vision palette 常量和 Cocoa `NSColorList` 已经说明：如果不抽 semantic layer，
visual system 很快就会被平台 API 名字和局部 palette 名字绑死。

因此 nextPas 冻结：

- `ThemeToken` 先表达 semantic role，而不是先表达 `RGB` 值、`NSColor`、`GdkColor` 或 palette index
- token 至少要能覆盖 surface、text、border、focus ring、selection highlight、icon role、
  typography role、density role 与 effect / emphasis role
- code editor、tree view、dialog、button、toolbar、command palette、test panel 和 preview surface
  必须建立在同一套 token vocabulary 上
- token 可以分 role / variant / state axis，但不能退化成“哪个控件用哪个平台字段”的别名表

这条规则的意义很直接：

- future dark / light / high-contrast appearance 可以共用一套 semantic token vocabulary
- IDE editor 不需要一套 palette name，普通 controls 又需要另一套 palette name
- theme package 可以替换 visual identity，但不改写 UI control plane 的对象边界

## `StyleResolver` 必须是唯一推荐的 stateful appearance owner

FPC 的历史路线把 `style_set`、`gtk_widget_style_get`、`effectiveAppearance`、`GetPalette`
分散在不同层。nextPas 不允许把这些解析逻辑继续散落在 widget、renderer 和 IDE workbench 里。

因此 nextPas 要求：

- `StyleResolver` 是 semantic token 到 resolved style 的唯一推荐解析 owner
- 它至少要合并 component role、variant、interaction state、platform appearance、
  accessibility preference、workspace-selected theme 与 package-provided theme extension
- hover / pressed / focused / selected / disabled / active 这一类 visual state 必须在这里被统一解释
- `StyleResolver` 可以产生 layout-facing metric diff、text-facing typography diff 和
  rendering-facing paint / asset diff，但不直接代替这些控制面

这条分层直接挡住两种坏结构：

- focus ring / hover tint 由 interaction 自己画，rendering 再偷偷补另一套 pressed state
- IDE workbench 自己维护一套 palette resolver，GUI framework 再维护另一套 control resolver

## `ThemeSnapshot` 必须拥有稳定 visual revision 真相

nextPas 如果想现代、高性能、优雅，就不能让 layout、text、rendering、automation 在同一帧里看到
不同版本的 visual state。

因此 nextPas 冻结：

- `ThemeSnapshot` 是一次稳定 visual revision 的 owner
- 它至少要能表达 resolved color / brush、typography selection、metric role resolution、
  corner / stroke / shadow / opacity 一类 effect choice，以及 stateful appearance 结果
- snapshot identity 应尽量跨小幅 UI 更新保持稳定，避免轻微 hover / focus 变化就把整个 scene 的
  visual truth 全量重建
- layout、text/layout 和 rendering 必须消费同一份 `ThemeSnapshot`，而不是各自再做一轮 token lookup

这条规则能直接提供：

- layout invalidation 的 visual metrics 来源
- text typography / emphasis 的正式来源
- render lowering 的统一 paint / icon / effect 输入

## `ThemeAssetSet` 必须把 theme asset family 单独关住，而不是继续散落在 package 或 renderer 私货里

GTK icon set、Cocoa icon lookup 和历史 palette 常量都说明：一旦 visual asset 没有正式归属，
系统很快就会长出多个 icon registry、多个 image slice 目录和多个 font alias 表。

因此 nextPas 明确：

- `ThemeAssetSet` 负责表达 theme-level icon family、image slice、font alias、appearance variant
  与 theme-pack-facing asset family
- 这些资产先是 semantic theme asset，再进入 render-side compiled form
- `ThemeAssetSet` 和 `RenderAssetBundle` 必须分工清楚：前者拥有 semantic family，后者拥有
  backend-facing compiled payload
- future package-provided theme extension 如果存在，也必须接到 `ThemeAssetSet`，而不是让某个
  control library 私自读目录找资源

这样 people 才能解释一个 icon / image / font alias 到底属于 theme semantics，还是属于 render-side
compiled artifact。

## interaction 和 accessibility 只提供 state / preference 输入，不拥有 appearance semantics

只要 UI 有 hover、focus、pressed、selected、high contrast 或 platform appearance，
style/theme 就一定会和 interaction / accessibility 相接。但 nextPas 在这里明确：

- `InteractionRouter` 和 `FocusPath` 继续拥有 focus、hover、pressed、capture、selection-facing
  interaction truth
- accessibility control plane 继续拥有 assistive-facing state、contrast preference 和 action flow
- `StyleResolver` 消费这些状态与偏好，但 interaction / accessibility 不自己维护第二套 palette
- reduced-motion 一类 temporal preference 继续由 `ui-motion-specification.md` 定义，不回流成
  style/theme 的 scheduling owner
- focus ring、selection highlight、disabled opacity、high-contrast visual adaptation 都必须通过
  `ThemeSnapshot` 统一表现

这条规则的重点是：同一个 focused / selected state，只允许有一条 shared visual interpretation，
而不是 editor、controls、IDE panel 各自上色。

## layout 和 text/layout 可以消费 resolved visual input，但不能反向拥有 theme truth

style/theme 和 layout/text 的关系必须说清楚，否则很快就会重新混成一团。

nextPas 在这里冻结：

- layout control plane 可以消费来自 `ThemeSnapshot` 的 resolved density、padding role、
  border thickness、minimum control metric 等 visual-facing metric input
- 但最终 bounds、viewport、child placement 仍然只属于 `LayoutSnapshot`
- text/layout control plane 可以消费来自 `ThemeSnapshot` 的 typography role、font alias、text emphasis
  和 stateful text appearance
- 但 logical text、style span、paragraph、caret/selection mapping 仍然只属于 text/layout control plane

也就是说：

- theme 可以影响几何输入，但不能替代 layout 几何真相
- theme 可以影响 typography 选择，但不能替代 text content / text layout 真相
- 同一条 resolved style 必须同时服务普通 controls、code editor 和 IDE workbench 文本

## rendering 只消费 resolved style 与 theme asset handoff，不拥有 theme semantics

`ui-rendering-specification.md` 已经冻结 `DrawPlan`、`RenderGraph`、`SurfaceFrame` 和
`RenderAssetBundle`。这里进一步把 style/theme 和 rendering 的边界钉死：

- `DrawPlan` 消费 `ThemeSnapshot` 产生的 resolved paint / effect / icon reference
- `RenderAssetBundle` 消费 `ThemeAssetSet` 提供的 semantic asset family，并把它们编译成
  backend-facing payload
- rendering 不重新解释 semantic token，也不维护第二套 palette / appearance rules
- backend 不允许因为自己好实现，就偷偷定义另一套 focus tint、selection color、editor theme
  或 icon variant 规则

这条规则会直接决定 future GPU-backed UI stack 能不能既现代又不失控。

## IDE 不允许拥有第二套 palette / theme system

nextPas 的 IDE 是这套 GUI framework 的 flagship application，但它不是 style/theme 的例外区。

因此 nextPas 冻结：

- editor、project tree、outline、terminal panel、test view、settings form、command palette、
  package view 和 future designer surface 都必须共用同一套 `ThemeToken -> StyleResolver ->
ThemeSnapshot` 线
- workbench theme selection、density selection 或 appearance preference 如果未来存在，
  也必须进入同一条 style/theme control plane
- IDE 不允许长期依赖私有 CSS bridge、私有 palette 表、私有 icon registry 或 webview theme shell

这条规则是为了避免 GUI framework 和 IDE 又重新长成两套视觉系统。

## 性能模型必须从第一天进入 style/theme 设计

既然用户目标是现代、高性能、优雅，style/theme 规范不能只谈 aesthetic，不谈 performance。

第一阶段先冻结这些性能方向：

- token resolution 优先结构化缓存，不让每次 frame 都做重复字符串查找
- hover / focus / pressed 变化应尽量触发局部 `ThemeSnapshot` diff，而不是整树 visual rebuild
- layout-facing metric 变化与 paint-only 变化应能被区分，避免所有 style change 都升级成全量 layout
  invalidation
- icon / image / font alias family 的预处理优先进入 toolchain 或 build-time，不把昂贵 theme asset
  解析全压到启动和热路径
- platform appearance change、high-contrast change、theme switch 应进入受控 revision，而不是散落成
  一堆 widget-local callback

这几条不等于现在就实现完整 theme engine；它们只是保证架构不会天然把性能做差。

## style/theme 资产必须继续服从 toolchain 与发行布局

style/theme 一旦涉及 token pack、icon family、image slice、font alias metadata 或 appearance variant，
就已经不是“随便放哪都行”的内容。

因此 nextPas 明确：

- public Pascal style/theme units
  - 继续落在 `units/<target>/`
- private theme resolver helper、compiled token pack、style runtime support library
  - 落在 `lib/nextpas/ui/theme/` 或等价私有 `lib/` 子树
- shared themes、icon packs、image slices、font alias metadata、examples、docs
  - 落在 `share/nextpas/ui/themes/` 或等价共享 `share/` 子树
- theme pack compilation、icon preprocessing、appearance variant compilation 如果未来存在，
  继续走统一 `ToolchainBinding`

这条规则和 `distribution-layout-specification.md`、`toolchain-specification.md` 是同一条原则：
visual asset 也必须有正式公开落点和正式生产路径。

## cross target style/theme 仍然不能逃离统一 target truth

只要 theme asset 涉及 target-specific icon pack、font alias、color space、platform appearance bridge
或 compiled support artifact，它就已经进入 target-aware territory。

因此 nextPas 要求：

- style/theme 不单独维护第二套 platform matrix
- 哪些 appearance adapter、theme asset variant 和 helper library 可用于哪个 target，
  继续由 `TargetFacts + ToolchainBinding` 决定
- cross-compiling GUI app、preview tool 或 future IDE shell 时，theme asset 仍按 target key 产出、
  安装和验证
- `host == target` 不能因为 theme 看起来“更上层”就被重新写死

否则 GUI 一到 cross target，又会退回“本机先能看起来差不多”的历史脚本模型。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 先只冻结 style/theme control plane 的对象边界
  - 不承诺当前最小 `nextpas build` 立刻支持完整 theme engine、theme package 或 IDE skinning
- `stage1`
  - 可以开始收敛最小 `ThemeToken` vocabulary、最小 `StyleResolver`、最小 `ThemeSnapshot`
    和最小 `ThemeAssetSet`
  - 也可以开始为 light / dark、focus / hover / pressed 和 editor / control shared visual line
    预留正式入口
  - 但不承诺完整 design system、designer tooling 或 theme marketplace
- `stage2`
  - 只有在 GUI framework、layout、text/layout、rendering、workspace truth 和 IDE workbench 都稳定后，
    richer theme tooling、live theme reload、designer workflow 和 package-distributed theme ecosystem
    才适合进入正式实现波次

这条阶段关系的重点是：先把 visual truth 写对，再决定哪种 theme surface 值得先落实现。

## 第一阶段非目标

- 不在这一阶段锁死具体 theme DSL、文件格式或 package schema
- 不把 GTK RC、Cocoa appearance API、Free Vision palette 常量重新包装成 nextPas 的长期 style
  architecture
- 不让 rendering/backend 反向拥有 semantic theme meaning
- 不让 IDE workbench 长出私有 palette / icon / appearance system
- 不把完整 design system、visual designer、theme marketplace 或 skin ecosystem 写成当前承诺

第一阶段真正要交付的是：一份把 nextPas UI style/theme 明确写成“semantic token +
style resolver + theme snapshot + theme asset set”的正式架构规范。
