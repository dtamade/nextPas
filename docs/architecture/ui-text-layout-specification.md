# nextPas UI text layout 规范

用这份规范定义 nextPas 长期 UI text/layout control plane 的稳定边界。它回答的不是
“以后选 Pango、CoreText 还是别的什么库”，而是“文本内容、排版快照、glyph runs、IME/input
session 应该怎样进入统一 Pascal UI stack，才能让 nextPas 的 GUI framework、editor、preview
surface 和 future IDE 共享同一条 text truth，而不是重新回到平台 binding、widget text view、
terminal editor 和 backend 私货各管一段的历史结构”。

这份文档和 `gui-framework-specification.md`、`platform-shell-specification.md`、
`ui-runtime-specification.md`、`ui-interaction-specification.md`、
`ui-layout-specification.md`、`ui-style-theme-specification.md`、
`ui-motion-specification.md`、`ui-rendering-specification.md`、
`ui-accessibility-specification.md`、`ide-specification.md`、`toolchain-specification.md`、
`distribution-layout-specification.md` 一起工作。前者们分别冻结 GUI 总骨架、platform shell
宿主边界、runtime control plane、interaction control plane、general layout control plane、
style/theme control plane、motion control plane、rendering control plane、accessibility control plane、
future IDE workbench、toolchain control plane 与公开发行布局；这里冻结 text/layout 本身的正式控制面。

## 先看 FPC 真源码已经把 text / IME / font / editor 能力分散成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `/home/dtamade/projects/fpc/packages/gtk2/fpmake.pp`
  - `gtk2` package 明确把 `src/pango`、`src/pangocairo`、`src/atk`、`src/gtk+` 都纳入 build
  - 说明 internationalized text、accessibility text surface 与 widget toolkit text stack 都是真实需求
- `/home/dtamade/projects/fpc/packages/gtk2/src/pango/pango.pas`
  - 文件头直接写 `Pango - an open-source framework for the layout and rendering of internationalized text`
  - 说明 text shaping / layout / rendering 的平台库事实存在
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkimcontextsimple.inc`
  - 公开 `TGtkIMContextSimple`、`gtk_im_context_simple_new`、`gtk_im_context_simple_add_table`
  - 说明 IME / compose sequence 已经以 toolkit-private object 暴露
- `/home/dtamade/projects/fpc/packages/gtk2/src/atk/atktext.inc`
  - 暴露 `get_caret_offset`、`get_offset_at_point`、`get_selection`、`set_selection`、
    `get_character_extents`
  - 说明 accessibility text boundary、caret、selection、geometry mapping 也是真实控制面
- `/home/dtamade/projects/fpc/packages/x11/fpmake.pp`
  - `x11` package 同时公开 `fontconfig.pas`、`xft.pas`、`xrender.pp`、`xinput2.pp`
  - 说明 font discovery、text raster、rendering extension 与 input extension 是分散 binding
- `/home/dtamade/projects/fpc/packages/x11/src/xft.pas`
  - 文件头写明 `Description: Xft interface functions`
  - 暴露 `XftDrawStringUtf8` 与 `XftTextExtentsUtf8`
  - 说明 UTF-8 text draw / extents 以平台接口存在，但不是统一 UI text contract
- `/home/dtamade/projects/fpc/packages/x11/src/fontconfig.pas`
  - 暴露 `FC_FAMILY`、`FC_STYLE`、`FC_WEIGHT`、`FC_WIDTH`、`FC_LANG`、`FC_CHARSET`
  - 说明 font family / style / fallback / charset 选择是正式问题
- `/home/dtamade/projects/fpc/packages/cocoaint/fpmake.pp`
  - 直接暴露 `InputMethodKit.pas`
  - 说明 macOS text input / IME 也是平台接口族的一部分
- `/home/dtamade/projects/fpc/packages/cocoaint/src/InputMethodKit.pas`
  - 直接 `{$linkframework InputMethodKit}`
  - 说明 text input system 被当成宿主平台 framework 暴露，而不是统一 Pascal text session
- `/home/dtamade/projects/fpc/packages/fv/fpmake.pp`
  - `Description := 'Free Vision, a portable Turbo Vision clone.'`
  - 还直接包含 `editors.pas`
  - 说明 text UI / terminal editor 是另一条真实产品线
- `/home/dtamade/projects/fpc/packages/fv/src/editors.inc`
  - 同时出现 word wrap、selection、clipboard、cursor、jump-to-line、search/replace
  - 说明 editor text workflow 的需求长期存在，但它建立在 TUI editor 私有逻辑上

这些事实组合起来说明：

- FPC 生态里有 text layout library binding、IME binding、font binding、accessibility text surface、
  terminal editor 和 widget text surface
- 但没有一份把 text content、layout snapshot、glyph run、caret mapping、IME session 和
  render handoff 收成统一 Pascal text control plane 的正式架构
- nextPas 如果不把这层单独冻结，future GUI controls、code editor、preview surface 和 IDE
  很快又会各画各的字、各管各的光标、各自接一套 IME

## text/layout 必须是 GUI stack 里的独立控制面，而不是 scene 或 backend 的注脚

`gui-framework-specification.md` 已经冻结 `UiScene`、`UiRuntime`、`RenderBackend`、
`PlatformShell` 四层骨架；`ui-rendering-specification.md` 已经冻结 `DrawPlan`、`RenderGraph`、
`SurfaceFrame`、`RenderAssetBundle`。但这两份文档都不会替代 text 自身的正式边界。

nextPas 在这里进一步冻结：

- `UiScene` 继续拥有 text node / editor widget 的 UI 语义入口
- text/layout control plane 负责把 logical text、style span、paragraph、caret/selection、
  IME composition 和 line breaking 收成稳定 text truth
- style/theme control plane 继续负责把 semantic text role / appearance 解析成 concrete typography、
  color 和 emphasis input
- motion control plane 继续负责 caret blink、scroll reveal timing 与 text-facing temporal sampling
- rendering 继续消费 text/layout 的结果，而不是重新 shape 一遍文本
- `PlatformShell` 继续负责宿主 IME、clipboard、accessibility bridge 和 native text input glue，
  但不能反向拥有 text semantics

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| Pascal app / code editor / IDE workbench             |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| UiScene text node / editor model                     |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| TextContent                                           |
| logical text / spans / paragraphs / style intent     |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| TextLayoutSnapshot                                   |
| bidi / wrap / caret map / selection geometry         |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| GlyphRun set                                          |
| font refs / cluster map / positioned glyphs          |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| DrawPlan -> RenderGraph -> RenderBackend             |
+------------------------------------------------------+

PlatformShell / OS IME / clipboard
                |
                v
         TextInputSession
                |
                +------> TextContent + TextLayoutSnapshot
```

这张图的硬约束是：

- text truth 在 `UiScene` 和 `DrawPlan` 之间显式存在
- IME / clipboard / selection / caret 不能只留给平台层或 editor 私货
- GUI labels、rich text、code editor 和 accessibility 都要共享同一条 text control line

## 只冻结四个 text 对象，不把 text system 膨胀成名词森林

为了保持边界清楚且不过度膨胀，nextPas 在 text/layout 上只冻结四个核心对象：

- `TextContent`
- `TextLayoutSnapshot`
- `GlyphRun`
- `TextInputSession`

| 对象                 | 负责什么                                                                                          | 明确不负责什么                                       |
| -------------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `TextContent`        | 表达 logical Unicode text、paragraph segmentation、style span、inline object slot 与 edit intent  | 不负责 shaping，不直接做 IME 或 GPU draw             |
| `TextLayoutSnapshot` | 表达 line break、bidi ordering、cluster/caret mapping、selection geometry、viewport-facing layout | 不直接修改 text，不拥有 native input context         |
| `GlyphRun`           | 表达 backend-neutral shaped cluster、font ref、glyph id 与 positioned glyph sequence              | 不拥有 paragraph semantics，不决定 render pass       |
| `TextInputSession`   | 表达 IME composition、selection/caret edit session、clipboard handoff 与 text command mediation   | 不自己做 layout，不直接充当 accessibility tree owner |

这里最关键的边界是：

- text content 先定义“文本是什么”
- layout snapshot 再定义“文本在当前约束下怎样排”
- glyph run 最后定义“当前 frame 要画哪些字形”
- input session 单独定义“宿主输入如何合法改动文本”

## `TextContent` 必须先表达 logical text，而不是先表达 render string

如果 nextPas 的 text system 想现代、优雅，就不能把所有文本都先退化成一段“准备拿去画的字符串”。

因此 nextPas 冻结：

- `TextContent` 以 logical Unicode text 为 owner，而不是以 glyph buffer 为 owner
- paragraph boundary、style span、language/script hint、inline object placeholder 必须先属于 text content
- code editor、label、rich text block、command palette input 都应建立在同一类 content truth 上
- style span 表达的是 semantic text role / variant；concrete font family、font size、font weight、
  text color 和 emphasis 继续由 `ThemeSnapshot` 解析
- static label 可以是轻量 `TextContent`，但不应再额外发明第二套“简单文本 API”

这条规则的意义很直接：

- editor 不需要一套 document truth，controls 又需要另一套 label truth
- style / language / paragraph 变化可以独立触发布局失效
- future diagnostics underline、code lens、inline hint、emoji/object replacement 都有正式落点

## `TextLayoutSnapshot` 必须拥有 line break、bidi、caret 和 hit-testing 真相

现代 text layout 真正容易失控的，不是把字画出来，而是这些映射到底归谁：

- 哪一段先 shape
- 什么时候换行
- bidi / direction 怎么排
- 光标按 grapheme、word、line 移动时该落哪
- selection rectangle 和 offset-at-point 应该怎样解释

nextPas 在这里明确：

- `TextLayoutSnapshot` 是一次稳定 layout 计算的 owner
- 它至少要能表达 paragraph fragment、visual line、cluster boundary、caret stop、
  selection geometry 与 point-to-offset mapping
- `TextLayoutSnapshot` 必须可供 GUI controls、editor 与 accessibility 同时消费
- layout snapshot 应绑定约束条件，例如 width、text scale、style state、viewport 或等价 layout
  revision，而不是悬空存在

这条规则直接回应 `atktext.inc` 里 `get_caret_offset`、`get_offset_at_point`、
`get_character_extents` 这一类事实：caret / geometry mapping 是正式 contract，不是 UI 小细节。

## `GlyphRun` 必须 backend-neutral，而且只能从 layout snapshot 派生

`ui-rendering-specification.md` 已经说明 text shaping/layout 的语义结果应先进入 `UiScene` /
`DrawPlan`。这里进一步冻结：

- `GlyphRun` 从 `TextLayoutSnapshot` 派生，而不是直接从平台 font API 临时拼出来
- glyph run 至少要携带 font ref、glyph id、cluster map、advance/offset、baseline 和 draw order
- `GlyphRun` 是 render-facing object，但仍保持 backend-neutral
- backend 不允许因为自己好实现，就偷偷维护另一套 shaping / fallback / cluster mapping

这样 `DrawPlan` 拿到的是统一的 text draw intent，而不是：

- X11 一套 extents 逻辑
- Cocoa 一套 glyph mapping
- editor renderer 再来一套 monospace 快速路径

## `TextInputSession` 必须把 IME / selection / clipboard / edit command 单独关住

FPC 源码已经证明：

- GTK 路线里有 `IMContext`
- Cocoa 路线里有 `InputMethodKit`
- TUI editor 路线里有 selection / clipboard / cursor 私有逻辑

这正好说明 text input 不可能只靠 raw key event 搞定。

因此 nextPas 冻结：

- `TextInputSession` 是 active editable text surface 的正式输入会话
- 它负责 composition text、commit、cancel、selection mutation、clipboard operation 与
  platform text command mediation
- `PlatformShell` 只提供宿主 IME / clipboard / native text service bridge
- `TextInputSession` 再把这些平台事件合法下沉到 `TextContent` 与 `TextLayoutSnapshot`

这条分层能直接挡住两种坏结构：

- editor 自己接一套 IME，controls 再接一套 IME
- platform shell 直接改 text buffer，绕开 text model 和 layout invalidation

更细的 `HostWindow`、`DisplayTopology`、`DataTransferSession` 和 `SurfaceBinding` 由
`platform-shell-specification.md` 定义。

更细的 `InputEvent`、`FocusPath`、`CommandIntent` 和 `InteractionRouter` 由
`ui-interaction-specification.md` 定义。
更细的 `LayoutNode`、`LayoutConstraint`、`LayoutSnapshot` 和 `LayoutInvalidation` 由
`ui-layout-specification.md` 定义。
更细的 `ThemeToken`、`StyleResolver`、`ThemeSnapshot` 和 `ThemeAssetSet` 由
`ui-style-theme-specification.md` 定义。
更细的 `MotionClock`、`MotionTransition`、`MotionSnapshot` 和 `MotionScheduler` 由
`ui-motion-specification.md` 定义。

## accessibility、editor 和 GUI controls 只能消费同一条 text truth

text 系统如果不统一，最先碎掉的就是 accessibility 和 editor。

nextPas 明确要求：

- accessibility bridge 看到的 text boundary、selection、caret 与 screen geometry，必须来自
  同一份 `TextLayoutSnapshot`
- IDE editor、search box、code action popup、tree filter input、settings form text field
  都应建立在同一套 text objects 上
- GUI label / button / menu item 的“简单文本”不能因此退回另一套 layout truth
- CLI、preview surface、IDE snapshot capture 如果显示文本，也应继续收敛到同一套 text contract

这条规则很关键，因为 code editor 不是一个例外产品，而是 future GUI framework 最重的 text
consumer 之一。

更细的 `AccessibilityNode`、`AccessibilitySnapshot`、`AccessibilityAction` 和
`AccessibilityBridge` 由 `ui-accessibility-specification.md` 定义。

## font discovery、fallback 和 text assets 必须继续服从 render/toolchain/shared layout

`fontconfig.pas`、`xft.pas`、`pango.pas` 这些 FPC 源码事实说明：

- font family / weight / language / charset
- glyph extents
- text draw
- system font discovery

都是真实问题。

nextPas 先冻结这些边界：

- system font discovery 与 native font handle bridge 由 `PlatformShell` 暴露必要能力
- logical font request、fallback policy、script/language-aware selection 应进入 text/layout control plane
- glyph atlas、font metadata、subpixel / raster strategy 继续落在 `ui-rendering-specification.md`
  定义的 rendering control plane
- bundled font preprocessing、fallback table compilation、hyphenation or line-break sidecar data 如果未来存在，
  仍必须进入 `ToolchainBinding + ToolInvocationPlan`

换句话说：

- text 不能吞掉 rendering
- rendering 不能吞掉 text semantics
- toolchain 也不能缺席 text assets

## 发行布局必须给 text 资产和私有支持物留出正式落点

`distribution-layout-specification.md` 已经冻结 `units/<target>/`、`lib/`、`share/` 的公开语义。
UI text/layout 继续服从它：

- public Pascal text/layout API units
  - 落在 `units/<target>/`
- private shaping helper、font fallback metadata、text engine sidecar support library
  - 落在 `lib/nextpas/ui/text/` 或等价私有 `lib/` 子树
- bundled fonts、hyphenation or segmentation data、examples、docs
  - 落在 `share/nextpas/ui/text/` 或等价共享 `share/` 子树

这样 people 才能清楚解释一个文本相关资产到底是公开 API、私有支持物，还是共享内容。

## 性能模型必须从第一天进入 text/layout 设计

text 是 GUI framework 和 IDE 里最热的路径之一，不能先做成“每次全量排版”的系统，再指望后面补救。

第一阶段先冻结这些性能方向：

- `TextContent` 与 `TextLayoutSnapshot` 应支持增量 invalidation，而不是每次小改动都全量 relayout
- viewport-facing editor layout 应允许 fragment / line window 级计算，不把整个大文档强制一次性铺平
- glyph run 应优先复用稳定 cluster / font fallback 结果，不让 backend 每帧重 shape
- caret / hit-testing / selection geometry 应绑定 snapshot revision，避免跨 revision 读到脏结果
- text input session 的 composition 更新只使相关 paragraph / fragment 失效，不强迫整个 scene 重算

这些不是优化建议，而是 future code editor 想保持可用的基础架构前提。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 先只冻结 text/layout control plane 的对象边界
  - 不承诺当前最小 `nextpas build` 已经实现 GUI text control、IME、rich text 或 IDE editor
- `stage1`
  - 可以开始实现最小 `TextContent`、basic `TextLayoutSnapshot`、basic `GlyphRun` 与单行/多行 proof path
  - 也可以开始为 code editor 和 text field 收敛 shared text infrastructure
- `stage2`
  - 只有在 GUI stack、rendering、text/input、workspace truth、language service 都稳定后，
    richer editor UX、advanced text shaping、designer text tooling 才值得进入正式实现波次

## 第一阶段非目标

- 不在这一阶段锁死具体 text engine、shaper 或 platform API 名字
- 不把 GTK/Pango、Xft/Fontconfig、InputMethodKit wrapper 重新包装成 nextPas 的长期 text architecture
- 不让 backend 私自拥有第二套 shaping / caret / hit-testing 逻辑
- 不把 editor text engine 单独做成和 GUI controls 不兼容的私有路线
- 不把 syntax highlighting、semantic tokens、rich text editing、terminal emulation 一次性都写成当前承诺

第一阶段真正要交付的是：一份把 nextPas UI text/layout 明确写成“logical text +
layout snapshot + glyph run + input session”的正式架构规范。
