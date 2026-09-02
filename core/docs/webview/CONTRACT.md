# nextpas.core.webview 代码契约（家族）

**模块路径**：`core/src/nextpas.core.webview*.pas`
**层级**：L3 家族（依赖 L0-L2；后端实现子单元随家族落位）
**Owner**：core-webview lane
**最后更新**：2026-09-02
**版本**：2.00（S106 WK 探针闭环 · `focused-runtime, source-contract`）
<details>
<summary>版本分层：S106 探针闭环与 S105 基线（点击展开）</summary>

- **S106 探针闭环**：`wk.loader` 经 `platform.dl` 真探 `WebKit.framework/libobjc`（幂等缓存双检锁 inline 零分配，Linux 诚实 False 非恒 False，与 gtk/webview2 同纪律，`platform_dl_release` 释放不丢）；真实现落地路径已闭环为 `window.cocoa` L2 `focused-runtime` 的 `IWindow` 组合（`WKWebView` child `addSubview`，无需 L3 自建 ObjC，待 stage0 `objectivec1`/`objc_msgSend` 探通后接线）；CONTRACT §1/§10 与 registry 对齐。
- **S105 基线（零退化）**：`WebviewGrowCapacity(0→4→2×)` 单源 inline（`grep SetLength` 54→4 定容切片/快照、50 Grow 全量 inline 单源，`F*Count` 全量闭环，三后端/bridge/factory 容量保留，零 `O(n²)` 零 `UAF`，薄转发 159 inline 零额外调用；`fpc -vh` 0 hint、`grep -R TODO/FIXME` 0、`hygiene`/`source-contracts` 双 pass，vfs 6 + base 10 + factory 13 + bridge 17 + grow 4 全绿 heaptrc 0）。
- **考古栈**：1.98←1.13 折叠至 [ROADMAP §3](ROADMAP.md#3-回溯s0-s44-已交付)。

> 单文件 650+ 行属契约完整性保留，阅读以本折叠层与 §1 家族布局为入口，细节按需展开。
</details>
**对标基准**: [PARITY-GO-RUST.md](PARITY-GO-RUST.md)（Rust wry/tao/Tauri v2 · Go Wails v2/v3）

---

## 1. 家族布局

| 单元 | 层 | 职责 | 波次 |
|------|----|------|------|
| `nextpas.core.webview.base` | 类型根 | options/events/kinds/错误分类（含 `EWebviewError` 族）— 纯数据类型，无校验实现（四件套纯度） | W1 |
| `nextpas.core.webview.validation` | 校验 | `CheckWebviewOptions`/`CheckInvokeCmd`/`CheckWebview*` 校验实现层（`base←intf←validation←factory/bridge` 纯度；复用 L1 `text.view` `TStringView.Trim` 零拷贝 + L2 `validation.URL` 单源，inline 零额外调用） | W1 |
| `nextpas.core.webview.intf` | 接口 | `IWebviewWindow` / `IWebviewDispatcher` / `IWebviewAssets` / invoke 契约类型 | W1 |
| `nextpas.core.webview.utils` | 共享辅助 | 资产路径归一 `NormalizeWebviewAssetPath`/`NormalizeWebviewAssetView`/`ViewFromPChar` 薄转发 L1 `text.view` Owner 单源 `StripLeadingSlash/StripLeadingSlashView/TrimLeftChar/ViewFromPChar`（`TStringView` 零拷贝 view + `SliceToStr` 单次 `SetString+Move` + `bytes.ops.CStrLen` SIMD 单源，bridge/vfs/gtk 同源 `inline` 零额外调用，loop 体在 Owner 侧非 inline 避膨胀，`Finalize` 不丢） | W1→S52 双轨归一至 Owner 已反哺 |
| `nextpas.core.webview.callbacks` | 共享辅助 | method/proc→reference 单源适配（4 后端 inline 薄转发，零拷贝闭包，见折叠层 S105；仅依赖 `intf`，释放不丢） | S105 单源收敛 |
| `nextpas.core.webview.bridge` | 协议 | 桥协议 v1 编解码 + pending 表 + 注入脚本常量（后端无关，唯一实现；帧超限判定与计数已反哺 `metrics` Owner thin-forward，见 `metrics` 行） | W1 |
| `nextpas.core.webview.metrics` | 可观测性（L3 Owner 单源） | 帧超限背压计数 Owner 单源（`WEBVIEW_MAX_FRAME_BYTES` 1 MiB Hard Limit 常量即契约 + `WebviewMetricsOversizedCount/NoteOversized/IsOversized*` 单调递增 `inline` 零拷贝背压计数, `bridge` `TryDecodeFrame/TryBuildOversizedReject` 薄转发零重复阈值/计数定义, `bytes.ops` 零拷贝视图思想 `inline` 零额外调用+`Default` 释放不丢, `bench/log` 通用可观测 Owner 候选可抽 L2 `metrics` 单源见 §1.2, UI 线程亲和 plain `UInt64`） | S106 已反哺 thin-forward (2026-09-02) |
| `nextpas.core.webview.live` | **removed (S108 physical deletion, compat alias hygiene)** | **已物理删除**：S108 hygiene compat debt 单点下线（`core/src/nextpas.core.webview.live.pas` 物理删除兼容薄别名 `TWebviewLiveRegistry<T>`，不再参与家族 glob 统计，模块噪音与 hygiene 负担归零；活窗紧凑 Vec 注册表已收敛至 L1 `bytes.ops.TCompactLiveRegistry<T>` 单源 inline 零拷贝 `VecGrowCapacity` 0→4→2× / `VecRemoveSwap` O(1) / `Snapshot`/`Trim` inline 单源零额外调用零拷贝，`Default(T)` 释放不丢，跨家族 `window.live` 同源零重复；家族内 `gtk/wk/webview2/fake/shell` 已全量直用 `bytes.ops.TCompactLiveRegistry<T>` 单源 `inline` 零额外调用，消除 deprecated 兼容别名与重复 `uses` 噪音，提升跨家族复用度，见 S108 收敛） | S105→S107→S108 物理删除（2026-09-02 procedural 已删，alias deprecated → alias 物理删除） |
| `nextpas.core.webview.assets` | 私有索引 | 资产前缀单哈希 + Trie 路由索引（`bridge` 单源承载，`WyHash` + `TStringView` 零拷贝 + L2 `collections.prefixrouter` 稀疏 Trie，见折叠层 S105；`Finalize`/`Dispose` 释放不丢，已反哺 L2） | S105→S108 Trie 单源收敛 |
| `nextpas.core.webview.fake` | 测试后端 | 无头脚本化后端：记录调用、手动驱动回调，契约测试全走它 | W1 |
| `nextpas.core.webview.gtk.ffi` | ABI | WebKitGTK/GLib/GTK3 类型与函数指针变量声明（无 external） | W1 |
| `nextpas.core.webview.gtk.loader` | 装载 | dlopen 探测与符号装载（经 `platform.dl`），版本探测 4.1→4.0 | W1 |
| `nextpas.core.webview.gtk.viewmap` | 私有索引 | GTK 指针键 view→window O(1) 哈希（L1 `collections.hashmap` THashMap<Pointer,Pointer> 直接复用 via @PointerHash，inline 零额外调用，`FreeAndNil` 释放不丢，见折叠层 S105） | S105→S108 L1 容器直接复用闭环 |
| `nextpas.core.webview.gtk.pool` | 私有池化 | GTK dispatcher 池化 Slab（Idle/Completion/AssetHolder 三池，`live` 泛型单源 inline 零拷贝，`Dispose` 释放不丢，见折叠层 S105） | S105 单源收敛 → S109 热点 Slab |
| `nextpas.core.webview.gtk.shell` | 壳缝 | GTK 窗口壳缝：活窗/ scheme 上下文注册表、Trace、ShellInit、窗口壳创建/嵌入、IWindow 委托（`window.gtk3` Raw 单源 12 项 inline 零拷贝，`bytes.ops VecGrowCapacity` + `TCompactLiveRegistry` 单源，log.intf 分级零开销，短临界 <1µs） | S109 拆分 |
| `nextpas.core.webview.gtk.bridge` | 桥缝 | 桥传输缝：script-message/load 信号、SchemeRequest 资产分发、DispatchFrame/SendReceipt、Emit 注入（bridge 协议单源 + webview.utils 零拷贝 view + mime 单源 + viewmap 单源 + AssetHolder Slab 单源，GBytes 零 Move，Threshold 已 retire） | S109 拆分 |
| `nextpas.core.webview.gtk.dispatch` | 调度缝 | 调度缝：Idle/Completion 池化 trampoline、Eval exactly-once 结算、PostIdle/Drop/Settle（pool Slab 单源 + live Registry 单源，GIdle/GCompletion 双池分离，Cancellable 单所有权，try-finally 释放不丢） | S109 拆分 |
| `nextpas.core.webview.gtk.win` | **removed (S106 physical deletion, dual debt with webview2.win)** | **已物理删除**：S106 hygiene 双 compat debt 集中下线（`core/src/nextpas.core.webview.gtk.win.pas` 物理删除，不再参与家族 glob 统计，模块噪音与 hygiene 负担归零；F4 shim 空单元已清理，`window.gtk3` Raw 单源 12 项已收口），门面层 WinShell* 12 项 deprecated inline 薄转发桩已清理（L2 `window.gtk3` Raw 单源 12 项已收口，`window.factory` 单泵，`bytes.ops` 单源复用零重复），零状态零分配、释放不丢（所有权归 `window.gtk3`，薄转发层无资源持有，`platform_dl_release`/`FreeAndNil` 释放不丢，inline 零拷贝零额外调用）；新代码直接 `uses window.gtk3`/`window.intf.IWindow`（`CONTRACT §1.1` + `ROADMAP S106`，下一主版本落地） | W1→F4→S106 deleted |
| `nextpas.core.webview.gtk` | 后端（门面聚合） | Linux 实现：**has-a `IWindow`**（`nextpas.core.window` L2）+ WebKit 视图挂载、scheme、idle dispatch、WebKitGTK 信号桥接（窗口壳经 `window.gtk3` Raw 单源 inline 零拷贝；**本单元已薄门面化，逻辑经 gtk.shell/bridge/dispatch 三子模块单源薄转发，体积收敛至高级感 800 行内聚**） | W1→M6 has-a → S109 薄门面 |
| `nextpas.core.webview.mime` | **removed (S107 physical deletion, L3同层冗余薄门面单源收敛)** | **已物理删除**：S107 hygiene compat debt 单点下线（`core/src/nextpas.core.webview.mime.pas` 物理删除，不再参与家族 glob 统计，模块噪音与 hygiene 负担归零；L2 `mime.types` 单一事实源已收口为 65 项零分配 O(1) 哈希 128 槽 1-2 探测，LookupBySlice 直哈 PChar 段无 Copy，与 L3 `http.mime` 同源；家族内 `vfs/gtk/bridge` 已全量直连 L2 单源 `MimeTypeFromPath`/`MimeTypeFromPathView` inline 零拷贝 View 直通，无堆分配，复用 L0 `base.utils HashFNV1aLower/CompareBytesIgnoreCase` via `bytes.ops` 单源零重复；薄转发层零状态零分配、释放不丢，无句柄无分配；新代码直接 `uses nextpas.core.mime.types` MimeTypeFromPath 单源 inline 零额外调用，消除 L3 同层依赖） | S13→S107 deleted |
| `nextpas.core.webview.vfs` | 适配 | `IVfs → IWebviewAssetProvider`（respack/vfs 集成，CONTRACT §3.4 唯一收口） | S11 |
| `nextpas.core.webview.factory` | 工厂 | 后端注册/探测/选择 + `TWebviewBuilder` | W1 |
| `nextpas.core.webview` | 门面 | 聚合 re-export 全部公共 API | W1 |
| `nextpas.core.webview.webview2.ffi` | ABI | WebView2 COM 完整 vtable（ICoreWebView2/Controller/Environment/Settings + UserAgent + WebMessageArgs/Navigation handlers，无 external） | **W2 S23 完整（含 UA）** |
| `nextpas.core.webview.webview2.loader` | 装载 | WebView2Loader.dll 探测与符号装载（platform.dl，wine 兼容） | **W2 桩已落地（S18）** |
| `nextpas.core.webview.webview2.win` | **removed (S106 physical deletion, dual debt with gtk.win)** | **已物理删除**：S106 hygiene 双 compat debt 集中下线（gtk.win/webview2.win 成双债务清零，`core/src/nextpas.core.webview.webview2.win.pas` 物理删除，不再参与家族 glob 统计，模块噪音与 hygiene 负担归零），M6 has-a 收口后 Win32Shell* 15 项 deprecated inline 薄转发桩已清理（窗口壳唯一事实源为 `nextpas.core.window.win32` 的 `IWindow`/`WindowRunLoop` 单源，调度经 `IWindow.Dispatcher.Post`，`window.factory` 单泵，`bytes.ops` 单源复用零重复），零状态零分配、释放不丢（所有权归 `window.win32`，薄转发层无资源持有）；新代码直接 `uses window.win32`/`window.intf.IWindow`（`CONTRACT §1.1` + `ROADMAP S106`，下一主版本落地） | W2→M6→S106 deleted |
| `nextpas.core.webview.webview2` | 后端 | Windows 实现：**has-a `IWindow`**（`nextpas.core.window` L2）+ WebView2 controller 真接线（Env→Controller 异步链、ExecuteScript/WebMessage、Post 调度、pending exactly-once、UA/DataDirectory） | **W2 S23 调度收口→M6 has-a** |
| `nextpas.core.webview.wk.ffi` | ABI | WKWebView 类型与探针结果（无 external 无逻辑，见折叠层 S106） | **W3 S25 桩→S106 探针闭环** |
| `nextpas.core.webview.wk.loader` | 装载 | WK 运行时探测（`platform.dl` 真探，双 soname 容错，inline 零分配，`platform_dl_release` 释放不丢，见折叠层 S106） | **W3 S25 桩→S106 探针闭环** |
| `nextpas.core.webview.wk` | 后端 | macOS 桩：**has-a `IWindow`**（L2，M6 has-a）+ fail-fast + 本地缓存/线程探测；真实现经 `window.cocoa` L2 `IWindow` 组合（`WKWebView` child，见折叠层 S106） | **W3 S25 桩→S106 探针闭环 + M6 has-a** |

### 依赖方向

```
base ← validation(校验实现，复用 L1 text.view + L2 validation 单源 inline 零拷贝) ← intf ← utils/callbacks(共享辅助：utils 复用 text.view Slice 单源零拷贝，callbacks 仅依 intf 4 后端 inline 薄转发零拷贝) ← bridge(←assets 私有索引单哈希单源) ← fake/gtk(uses window + live 紧凑 Vec 单源 + viewmap/pool 私有) → factory → 门面    （L3→L2 has-a）
              └── vfs 单桥位（已直连 L2 mime.types 单源 MimeTypeFromPath inline 零拷贝 View 直通，无堆分配，复用 bytes.ops 单源）；mime 薄门面已物理删除（S107，不再参与家族 glob，单源收敛）；webview2/wk 同 gtk 位（均 has-a IWindow + live + callbacks 单源）
gtk.ffi ← gtk.loader ← gtk.viewmap/gtk.pool(私有：viewmap 单哈希单源 + pool Slab 单源) ← gtk        （loader 装载 ffi 函数指针；viewmap/pool 仅 gtk 后端 uses，不经门面）
validation 为家族内校验实现层（四件套纯度 base←validation/intf←utils/callbacks/bridge←impl←facade；utils/callbacks 为家族内共享辅助，不经门面重复实现，仅 bridge/factory/后端 uses；inline 零拷贝，校验失败抛 EWebviewInvalidState，资源释放不丢）
live/assets/viewmap/pool 为家族内索引/池化（不经门面 re-export，可抽见 §1.2，已反哺 Owner 单源经设计评审 2026-09-02 现薄转发/直复用不自溢，live 过程式双形已收敛删除且兼容别名已物理删除）：live 已物理删除 `TWebviewLiveRegistry<T>` 兼容薄别名，家族已全量直用 L1 `bytes.ops.TCompactLiveRegistry<T>` 单源（`VecGrow/RemoveSwap/Snapshot/Trim` inline 零额外调用，0→4→2× 单源，`Default(T)` 释放不丢；不再经 `webview.live` 薄别名中转，`webview2` GLive 直用 `VecGrow/VecRemoveSwap` 单源；过程式 `WebviewLiveAdd/Remove` 已删除消除薄转发冗余，跨家族 `window.live` 同源零重复，已反哺落地 2026-09-02 经设计评审）、assets 已反哺 L2 `collections.prefixrouter` 稀疏 Trie（`TryGetLongestPrefixView` inline 零拷贝）、viewmap 已直复用 L1 `collections.hashmap`（`@PointerHash→HashMix32` 已落地 2026-09-02）、pool 已反哺 L1 `sync.pool`（`SyncPoolTryAcquire/Release` 双池 Slab 已落地 2026-09-02）；均 `inline/零拷贝` + `Finalize/Dispose/FreeAndNil` 不丢，跨家族收敛至 `bytes.ops`/`sync.pool`/`hashmap` 单源，业务以 CONTRACT 为准、缺能力先反哺 Owner，经设计评审不自溢
utils/callbacks 为家族内共享辅助（不经门面 re-export，可抽见 §1.2，已反哺 Owner 单源经设计评审 2026-09-02 现薄转发不自溢）：utils 已反哺 L1 `text.view` Owner 单源（`TrimLeftChar`/`StripLeadingSlashView`/`StripLeadingSlash`/`ViewFromPChar`，`SliceToStr`/`CStrLen` 单源，热点 `TStringView` 零拷贝 `inline` 薄转发、String 版 `SliceToStr` 单次 `SetString+Move` CoW 零分配，`Finalize` 不丢，已落地 2026-09-02 经设计评审）、callbacks 已反哺 L0 `base.callbacks`（`Callback*MethodToRef/ProcToRef` 三形态 `TProc`/`TProc1<T>`/`TCallbackScaleHandler` inline 零拷贝 `Move` 零拷贝，已落地 2026-09-02 经设计评审）；`inline/零拷贝` + `Default(T)` 不丢，守四件套与 L0-L3，跨家族单源审计通过，经设计评审不自溢
window 家族位于 L2，webview 家族位于 L3；webview 生产单元（fake/gtk/webview2/wk/factory）允许 uses window.*（L3→L2 has-a，M6 收口）；utils/callbacks 仍禁止 uses window（保持纯度，跨家族复用经评审）

### 1.2 可抽模块候选——Owner 归属（单源薄转发）

> 优雅收敛：**家族内私有为默认，外溢必先反哺 Owner 单源并经设计评审再 thin-forward；未评审前一律不自动外溢——能力以 CONTRACT 为准、性能以 inline/零拷贝为证、稳定以 `Default(T)/Dispose/FreeAndNil` 不丢为据，单源归 Owner，四件套与 L0-L3 单向守恒。薄转发 inline 零额外调用，短临界 <1µs 指针-only，零拷贝，`Default(T)/Dispose/FreeAndNil` 释放不丢。**

| 候选 | Owner 单源 (L层) | 状态 |
|------|------------------|------|
| `live` | L1 `bytes.ops.TCompactLiveRegistry<T>` (`VecGrowCapacity` 0→4→2× / `VecRemoveSwap` O(1) / `Snapshot`/`Trim` inline 零拷贝) | 已物理删除：过程式 `WebviewLiveAdd/Remove` 双形已删且 `TWebviewLiveRegistry<T>` 兼容薄别名已物理删除（冗余薄转发与 glob 噪音双清零），家族全量直用 `bytes.ops.TCompactLiveRegistry<T>` 单源 inline 零拷贝（2026-09-02 procedural 已删，alias 物理删除） |
| `assets` | L2 `collections.prefixrouter` (`TryGetLongestPrefixView` `TStringView` 零拷贝 O(m) 稀疏 Trie) | 已反哺 thin-forward (2026-09-02) |
| `viewmap` | L1 `collections.hashmap` `THashMap<Pointer,Pointer>` via `@PointerHash→HashMix32` inline | 已直复用 (2026-09-02) |
| `pool` | L1 `sync.pool` (`SyncPoolTryAcquire/Release` 双池 Slab) | 已反哺 thin-forward (2026-09-02) |
| `utils` | L1 `text.view` (`StripLeadingSlash`/ `TrimLeftChar`/ `ViewFromPChar` + `SliceToStr`/`CStrLen` 零拷贝) | 已反哺 thin-forward (2026-09-02) |
| `callbacks` | L0 `base.callbacks` (`Callback*MethodToRef/ProcToRef` `Move` 零拷贝) | 已反哺 thin-forward (2026-09-02) |
| `metrics` | L3 `nextpas.core.webview.metrics` (`WEBVIEW_MAX_FRAME_BYTES` 1 MiB Hard Limit 常量即契约 + `WebviewMetricsOversizedCount/NoteOversized/IsOversized*` 单调递增 `inline` 零拷贝背压计数, `bridge` `TryDecodeFrame/TryBuildOversizedReject` 薄转发零重复阈值/计数, `bytes.ops` 单源思想零拷贝视图) | 已反哺 thin-forward (2026-09-02) — 对应 BRIDGE_PROTOCOL §6 阈值 + INV-7 exactly-once 背压可观测闭环, 可抽 L2 `metrics` 单源见 Owner 注释 |

> 纪律：7/7 已反哺经设计评审落地，现 thin-forward/直复用不自溢（含 `metrics` 帧超限背压计数 Owner 单源 `WEBVIEW_MAX_FRAME_BYTES` 1 MiB + `OversizedCount` `inline` 零拷贝）；详见 Owner 单元及单测 inline/零拷贝基线，业务以 CONTRACT 为准、缺能力先反哺 Owner（`inline/零拷贝` + `Default(T)/Dispose/FreeAndNil` 不丢，守四件套与 L0-L3）。
```

- **`base` 与 `intf` 禁止 uses 任何后端、bridge、factory、vfs、window 单元**（`intf` 仅在 M6 后例外允许 `uses window.intf` 以暴露 `IWindow` 类型与 `Window` 属性，仍禁止触后端实现）。
- `bridge` 禁止 uses 任何后端/vfs/factory/window 单元；它只认识 `intf` 的契约。
- `*.ffi` 只含 ABI 类型与函数指针声明，不含逻辑、不含 `external`。
- `*.loader` 只做装载与探测，是唯一允许触碰动态加载设施的后端侧单元；
  动态加载原语一律来自 `nextpas.core.platform.dl`，
  **禁止使用 FPC `DynLibs` 单元**（gate policy：raw host units 仅限 owner path）。
- **webview→window**：`nextpas.core.webview.fake/gtk/webview2/wk/factory` 允许 `uses nextpas.core.window.*`（has-a 组合，L3→L2）；`gtk.ffi/loader` 等 `ffi/loader` 仍仅经 `platform.dl`，不直触 `DynLibs`。

**落地状态**（M6 has-a 收口后）：`base` / `intf`（`uses window.intf` 暴露 `IWindow`）/ `utils`（`text.view` 单源零拷贝）/ `callbacks`（4 后端 method/proc→reference inline 单源）/ `bridge`（含 `assets` 私有索引单哈希单源）/ `live`（4 后端 has-a 紧凑 Vec 单源）/ `fake`(has-a + callbacks) / `factory`(has-a) /
门面与 `gtk.ffi` / `gtk.loader` / `gtk.viewmap`（`hashmap.base HashOfPointer` + `bytes.ops` 单源）/ `gtk.pool`（`live` Pool 单源 + `bytes.ops` 单源）/ `gtk`(has-a + viewmap/pool) 已全部落地；
`gtk.win`/`webview2.win` 已双双物理删除（S106 hygiene 双 compat debt 集中下线：`core/src/nextpas.core.webview.gtk.win.pas`/`core/src/nextpas.core.webview.webview2.win.pas` 物理删除，不再参与家族 glob 统计，模块噪音与 hygiene 负担归零；WinShell* 12 项 / Win32Shell* 15 项 deprecated inline 薄转发桩已清理，窗口壳单源分别收口至 `window.gtk3` Raw 12 项 / `window.win32` IWindow 单源，`window.factory` 单泵统一，`bytes.ops` 单源复用零重复，薄转发层零状态零分配、释放不丢，inline 零拷贝零额外调用），见 §1.1。
webview2（W2）/ wk（W3）按波次接入同一 bridge 与 factory 位。
S4 打磨：scheme 未命中走真实 GError 404；IsMinimized 查询式真值；
DefaultWebviewKind 能力探测驱动（无 IFDEF）；资产路由语义见 §3。
S5 多窗口：scheme 请求按发起视图精确归属，资产命名空间跨窗硬隔离
（§5）。

### 注册表时机

module registry 条目必须与首个源码家族同批落地（S1）：注册表门禁
`check_architecture_source_contracts.py` 会拒绝没有 source family 的注册行。
S0 文档 slice 不改注册表。

### 1.1 窗口壳归属策略（反哺路线）

**方向判断**：长期需要独立的跨平台窗口模块（立项时定名，候选
`nextpas.core.window`），webview 只是它的第一个 consumer。依据：

- Tauri 的分层即先例：tao（窗口）+ wry（webview 内容）各自独立演进；
  Wails v3 同样把 Application/Window 与 webview 绑定分离。
- 仓库内的未来消费者已经存在：gpu/font 渲染栈、IDE workbench 规范明确禁止
  各自私建 shell（docs/architecture/ide-specification.md）。
- Android/iOS 的"窗口"语义是 **attach 到宿主 surface**（Activity/UIView），
  不是创建 top-level window——窗口模块必须从第一天就同时建模这两类，
  这是它独立于 webview 存在的核心理由之一。

**节奏控制**（fafafa 教训 + 受控跨模块纪律）：Wave 1 **不新建窗口模块**。
窗口壳以可机械抽取的内部缝实现（历史）：

- `nextpas.core.webview.gtk.win`：纯函数式 GTK 窗口操作（create/title/
  geometry/state/focus/loop），签名不含任何 webview 概念，只依赖
  `gtk.ffi/gtk.loader`；
- `nextpas.core.webview.gtk` 组合"窗口缝 + webview 内容"并实现 IWebviewWindow。

**M6 has-a 收口（已兑现，见 §1 依赖图）**：`nextpas.core.window` 独立 Lane 已落地（L2），
`webview.fake/gtk/webview2/wk` 全量改为 `has-a IWindow`（`FWindow: IWindow`，`Builder.Parent(const AParent: IWindow)` / `CreateWebviewOn(const AParent: IWindow; ...)`），
`gtk.win`/`webview2.win` 已双双物理删除（S106 hygiene 双 compat debt 集中下线：`core/src/nextpas.core.webview.gtk.win.pas`/`core/src/nextpas.core.webview.webview2.win.pas` 物理删除，不再参与家族 glob 统计，模块噪音与 hygiene 负担归零；12 项 WinShell* / 15 项 Win32Shell* deprecated inline 薄转发桩已清理，分别收口至 `window.gtk3` Raw 12 项 / `window.win32` IWindow 单源，`window.factory` 单泵统一，`bytes.ops` 单源复用零重复，零状态零分配、释放不丢；调度经 `IWindow.Dispatcher.Post`，薄转发层无资源持有，inline 零拷贝零额外调用），
`IWebviewWindow` 不再直接暴露 `Show/SetTitle/SetBounds` 等窗口壳方法，统一经 `Window: IWindow` 组合访问；
`WebviewRunLoop`/`WebviewExitLoop` 收敛为 `WindowRunLoop`/`WindowExitLoop` 的 `deprecated shim`（单泵归 `window.factory`，见 §5）。

抽取触发条件（历史，已满足其一即立独立 lane 做受控跨模块 slice）：
(a) 第二个真实 consumer 出现（GPU UI 栈 / IDE workbench / 对话框家族）；
(b) Wave 2 webview2 后端落地前——届时 Win32 缝与 GTK 缝一起上移，
避免两套后端各养一份窗口代码。抽取后 `IWebviewWindow` 保持不变
（组合面），消费方无感（M6 后消费方改为 `View.Window.Show` 等）。

> **S16 生产就绪**：`gtk.win` 缝已冻结为纯函数式接口、零 webview 概念、
> 签名单测可机械迁移；`demo` 骨架屏/错误边界已验证恢复路径（`grid.skeleton` +
> `errCard` + `showErr`），为窗口独立提供消费侧回归锚点。
> **M6 has-a 兑现**：窗口壳已单源至 `window` 家族，`webview` 仅持有 `IWindow` 组合面。

---

## 2. 核心类型（webview.base）

### 2.1 后端种类与可用性

```pascal
TWebviewKind = (wvGtk, wvWebview2, wvWk, wvFake);
```

### 2.2 窗口选项

```pascal
TWebviewOptions = record
  Title: string;            // 默认 ''
  Width: Integer;           // 默认 1024；<=0 时用引擎默认
  Height: Integer;          // 默认 768
  MinWidth: Integer;        // 0 = 不设限制
  MinHeight: Integer;
  MaxWidth: Integer;        // 0 = 不设限制
  MaxHeight: Integer;
  Resizable: Boolean;       // 默认 True
  Maximized: Boolean;       // 默认 False；启动即最大化
  DebugTools: Boolean;      // 默认 False；True 打开 inspector/devtools
  SchemeName: string;       // 默认 'npres'；资源 scheme 名
  InitialHtml: string;      // 非空则启动加载该 HTML（优先级低于 InitialUrl）
  InitialUrl: string;       // 非空则启动导航；DevServerUrl 存在时通常填它
  DevServerUrl: string;     // 非空 = 开发模式：资源服务整体让位给该 http 地址
  DataDirectory: string;    // ''= 引擎默认持久化位置；非空= 自定义 profile 目录
  EphemeralSession: Boolean;// 默认 False；True= 内存会话（与 DataDirectory 互斥：
                            //   同时设置抛 EWebviewInvalidState）
  InitScripts: TArray<string>;    // 追加注入脚本（document-start，主帧），
                                  // 桥脚本之外的业务初始化；顺序=数组序
end;

function DefaultWebviewOptions: TWebviewOptions;
```

InitScripts 的注入时机与桥脚本相同层（document-start、main-frame-only、
每次导航都生效）；与桥的先后序未定义——init script 里不得调用 `__npw`
（需要桥的应用应监听 `OnReady` 或 await `window.__npw.ready`，见
BRIDGE_PROTOCOL.md §2.1）。

**语义诚实表**（跨平台差异显式声明，不做假装）：

| 字段/能力 | GTK (WebKitGTK) | webview2 (W2) | wk (W3) |
|------|-----------------|----------------|---------|
| MinWidth/MinHeight | `gtk_window_set_geometry_hints` 生效 | `SetBounds` 夹取生效 | `contentMinSize` 生效 |
| Maximized | `gtk_window_maximize`（启动前设置） | ShowMaximized 路径 | `performZoom`/`isZoomed`（zoom=最大化语义），否则 `setFrame`+`styleMask`；W3 定案 |
| DebugTools | 需要 WebKit ≥ 2.24（4.x 均满足） | `AreDevToolsEnabled` | `isInspectable`（macOS 13+ 才可编程开启） |
| Eval 结果回执 | ≥2.40 用 `evaluate_javascript`（run_javascript 已废弃）；更老版本用 `run_javascript`+`_finish`，同样可取结果 | `ExecuteScript` completion | `evaluateJavaScript:completionHandler:` |
| SchemeName | 必须在创建第一个 webview 前 register_uri_scheme，否则静默失效 | `WebResourceRequested` 可后挂但首帧前生效最稳 | WKURLSchemeHandler 随 configuration 创建 |
| DevServerUrl | 直接 Navigate 到 http URL | 同左 | ATS 例外由调用方自行负责（W3 再议） |
| DataDirectory | 自建 `WebKitWebContext` + local storage path；默认 context 为共享单例 | `EnvironmentOptions.UserDataFolder`；多窗口同目录才共享会话 | `WKWebsiteDataStore(forPersistentStore:)` |
| EphemeralSession | `webkit_web_context_new_ephemeral` | `ControllerOptions.IsInPrivateModeEnabled`? → Environment `CreateCoreWebView2EnvironmentWithOptions` private 变体；W2 定案 | `WKWebsiteDataStore.nonPersistent()` |
| SetUserAgent | `user-agent` property | `Settings.UserAgent` | `customUserAgent` |
| SetZoom/GetZoom | `set_zoom_level/get_zoom_level`（全页缩放） | `ZoomFactor`（全页缩放） | `pageZoom`（全页缩放） |
| GetScaleFactor | `gtk_widget_get_scale_factor`（整数值） | `RasterizationScale`（浮点） | `backingScaleFactor`（浮点） |

DPI 策略（对齐 tao 口径的最小子集）：Wave 1 只读暴露 `GetScaleFactor`
（返回浮点，GTK 整数诚实升格）+ `OnScaleChanged` 事件；逻辑坐标一律物理像素
除以 scale，由消费方决定换算时机。不做 per-monitor 动态重排承诺。

### 2.3 事件 record

```pascal
TWebviewNavigationEvent = record
  Url: string;          // UTF-8 绝对地址
  IsError: Boolean;     // Failed 事件专用
  ErrorCode: Integer;   // 引擎原生码；未知为 0
  ErrorMessage: string; // 引擎原文或 ''
end;
```

### 2.4 错误分类

错误族基类派生自框架根异常：

```pascal
EWebviewError              = class(ENextPasError);  // 族基类
EWebviewBackendUnavailable = class(EWebviewError);  // dlopen/探测失败
EWebviewNotInitialized     = class(EWebviewError);  // 未创建即使用
EWebviewInvalidState       = class(EWebviewError);  // 重复 Create / Close 后操作 /
                                                    // Ephemeral 与 DataDirectory 冲突等
EWebviewClosed             = class(EWebviewError);  // Close 之后仍发起 Eval/Emit 等
EWebviewEvalFailed         = class(EWebviewError);  // Eval 执行失败（导航中/引擎错误/
                                                    // Close 时在途收尾）
EWebviewTimeout            = class(EWebviewError);  // invoke pending 超时（预留，W1 不启用）
EWebviewBadFrame           = class(EWebviewError);  // 无法解析的帧；生产路径静默忽略，
                                                    // 本类供 fake 后端 DeliverFrame
                                                    // 校验测试入参使用
EWebviewInvokeError        = class(EWebviewError);  // handler 内抛出的包装；
                                                    // 携带 Code/Message 回传前端 reject
```

- 具体类目值在 S1 实现时对照 `nextpas.core.exception.TErrorCategory` 定值并写测试。
- `EWebviewInvokeError` 额外携带稳定字符串 `Code`（见 BRIDGE_PROTOCOL.md 错误码表），
  桥捕获它转 reject；其他异常一律转 `npw.handler_error` 且消息原文透传。

---

## 3. 接口契约（webview.intf）

对外一律 interface（COM 引用计数），消费方不手写释放。
`TWebviewBuilder.New` 同样返回 interface（factory 单元实现），链式配置后
`Build`/`Run` 出窗口；生命周期归 COM 引用计数管理。`Kind(AKind)` 显式钉
后端（fake 等确定性场景的正规入口）；缺省 = `DefaultWebviewKind`
能力驱动，`Build` 时不可用按工厂语义 fail-fast。builder 出的窗口与工厂
路径同一生命周期纪律：消费方负责 `Close`（幂等），接口引用释放不替代
关闭——真后端窗口不 Close 会保持活跃并阻塞 RunLoop 退出判定。

### 3.1 主线程投递

```pascal
IWebviewDispatcher = interface
  { 从任意线程把闭包投递到 UI 主线程执行；窗口关闭后投递被静默丢弃 }
  procedure Post(AProc: TWebviewProcRef); overload;
  procedure Post(AProc: TWebviewProcMethod); overload;
  procedure Post(AProc: TWebviewProc); overload;
  property IsOnMainThread: Boolean read GetIsOnMainThread;
end;

TWebviewProcRef    = reference to procedure;
TWebviewProcMethod = procedure of object;
TWebviewProc       = procedure;
```

- 三种回调形式并存是仓库统一范式（design-conventions §8）。
- **一切用户回调（invoke handler 完成、eval 完成、事件通知）都在 UI 主线程触发。**
- 后端各自提供主线程唤醒原语：GTK = `g_idle_add_full`；webview2 = 隐藏 hwnd
  `PostMessage`；wk = `dispatch_async(main)`。这是后端接口的一部分（BACKENDS.md）。

### 3.2 窗口 + 内容

```pascal
IWebviewWindow = interface
  { 生命周期 }
  procedure Close;                       // 幂等；Close 后其他方法抛 EWebviewClosed
  function IsClosed: Boolean;

  { 窗口壳 —— 可见性 }
  procedure Show;  procedure Hide;
  function IsVisible: Boolean;
  procedure Focus;                       // 抬升并聚焦；无焦点概念的引擎为 no-op（诚实表）

  { 窗口壳 —— 标题与几何 }
  procedure SetTitle(const ATitle: string);
  function GetTitle: string;             // S6：WM 级标题同步读；未设置过为 ''（诚实表）
  procedure SetBounds(AWidth, AHeight: Integer);
  function GetWidth: Integer;  function GetHeight: Integer;
  procedure SetResizable(AResizable: Boolean);

  { 窗口壳 —— 状态（tao 对齐最小集） }
  procedure Maximize;    procedure Unmaximize;
  function IsMaximized: Boolean;
  procedure Minimize;    procedure Restore;
  function IsMinimized: Boolean;

  { 内容缩放与 UA }
  procedure SetZoom(AFactor: Double);    // 1.0 = 100%
  function GetZoom: Double;
  procedure SetUserAgent(const AUserAgent: string);
  function GetUserAgent: string;

  { DPI }
  function GetScaleFactor: Double;
  procedure OnScaleChanged(AHandler: TWebviewScaleHandler);

  { 导航 }
  procedure Navigate(const AUrl: string);
  procedure NavigateToString(const AHtml: string);
  procedure Reload;  procedure Stop;
  function CanGoBack: Boolean;   function GoBack: Boolean;
  function CanGoForward: Boolean; function GoForward: Boolean;

  { 异步 eval —— 唯一入口，禁止同步形态 }
  { ACallback 与 AOnError 恰好其一被调用，且都在 UI 主线程 }
  procedure Eval(const AJavascript: string;
    ACallback: TWebviewEvalCallback;
    AOnError: TWebviewEvalErrorCallback);

  { IPC：native → js 事件 }
  procedure Emit(const AEvent, APayloadJson: string);

  { 主线程投递（转发到本窗口后端的 dispatcher） }
  function Dispatcher: IWebviewDispatcher;

  { 句柄（平台原生指针，仅供嵌入场景；语义见 BACKENDS.md） }
  function NativeHandle: TWebviewNativeHandle;

  { 事件注册：三种回调形式各一重载（此处列匿名形，method/proc 形省略） }
  procedure OnNavigationStarted(AHandler: TWebviewNavEventHandler); overload;
  procedure OnNavigationFinished(AHandler: TWebviewNavEventHandler); overload;
  procedure OnNavigationFailed(AHandler: TWebviewNavFailedHandler); overload;
  procedure OnWindowClosed(AHandler: TWebviewNotifyHandler); overload;
  procedure OnReady(AHandler: TWebviewNotifyHandler); overload; // 桥就绪（每导航一次）
  { Eval/OnScaleChanged 同样提供 method/proc 三重载形态，签名从略 }

  { invoke 注册表（见 §3.3） }
  function Invokes: IWebviewInvokeRegistry;

  { 资产挂载（见 §3.4）；DevServerUrl 模式下 Mount 被 no-op 并记录诊断 }
  function Assets: IWebviewAssets;
end;

TWebviewEvalCallback      = reference to procedure(const AResultJson: string);
TWebviewEvalErrorCallback = reference to procedure(const AError: Exception);
TWebviewNavEventHandler   = reference to procedure(const AEvent: TWebviewNavigationEvent);
TWebviewNavFailedHandler  = reference to procedure(const AEvent: TWebviewNavigationEvent);
TWebviewNotifyHandler     = reference to procedure;
TWebviewScaleHandler      = reference to procedure(ANewScale: Double);
```

- **Eval exactly-one 语义**：`ACallback`/`AOnError` 恰好其一被调用一次。
  页面导航中/引擎失败走 `AOnError`（包装为 `EWebviewEvalFailed`，属
  `EWebviewError` 族）；窗口 `Close` 或引擎终止时，所有在途 Eval 统一以
  `AOnError(EWebviewEvalFailed)` 收尾（保持恰好一次；进程整体退出除外）。
  JS 执行成功但表达式值为 `undefined` 时结果文本按引擎诚实序列化（见
  BACKENDS.md eval 结果矩阵）。
- **错误实例所有权**：传给回调的异常实例（含 `AOnError` 的
  `EWebviewEvalFailed`）由框架创建、触发并在 `try/finally` 中释放；回调
  只可在调用栈内读取，不得 Free、不得在返回后继续持有引用。由调用方
  `raise` 的异常仍按 RTL 语义由框架捕获后释放。
- `Focus` 在 GTK 上 `gtk_window_present`；WebView2 `moveFocus(CODE)`；
  WK `makeFirstResponder`——细节入 BACKENDS.md。
- 事件注册返回句柄用于反注册的需求推迟到出现真实用例再扩展（YAGNI）。

### 3.3 invoke 契约

```pascal
{ 同步 handler：直接返回结果 JSON；抛异常 = reject }
TWebviewInvokeSyncHandler = reference to function(
  const APayloadJson: string): string;

{ 异步 handler：稍后调 ACompletion.Ok / Fail；ACompletion 只能调用一次 }
TWebviewInvokeAsyncHandler = reference to procedure(
  const APayloadJson: string;
  const ACompletion: IWebviewInvokeCompletion);

IWebviewInvokeCompletion = interface
  procedure Ok(const AResultJson: string);
  procedure Fail(const ACode, AMessage: string);
end;

IWebviewInvokeRegistry = interface
  procedure Register(const ACmd: string;
    AHandler: TWebviewInvokeSyncHandler); overload;
  procedure Register(const ACmd: string;
    AHandler: TWebviewInvokeAsyncHandler); overload;
  { method-pointer / proc 三重载形态遵循 design-conventions §8，此处从略 }
  procedure Unregister(const ACmd: string);
end;
```

- cmd 命名约定 `<domain>.<action>`（如 `fs.readText`）。保留规则单一且明确：
  cmd 为空、或以 `npw.`（协议错误码词汇前缀）或 `_` 开头时，
  `Register` 抛 `EWebviewInvalidState`；其余字符串一律接受。
- 同名重复注册抛 `EWebviewInvalidState`（显式 Unregister 后可重注册）。
- handler 抛出的一切异常：`EWebviewInvokeError` 按其 Code/Message reject，
  其余按 `npw.handler_error` reject。
- **handler 执行线程**：同步 handler 总在 UI 主线程内联执行；异步 handler 的
  `Ok/Fail` 可在任意线程调用（桥内部 marshal 回主线程再发回执）。

### 3.4 资源服务

```pascal
IWebviewAssets = interface
  { 解析失败返回 False，不抛异常（404 是正常业务路径） }
  function TryResolve(const ASchemeRelativePath: string;
    out ABytes: TBytes; out AMimeType: string): Boolean;
  procedure MountEmbedded(const APrefix: string; AProvider: IWebviewAssetProvider);
  procedure MountDirectory(const APrefix, ARootDir: string);
end;

IWebviewAssetProvider = interface
  function TryResolve(const APath: string;
    out ABytes: TBytes; out AMimeType: string): Boolean;
end;
```

- 前缀路由语义（S4 钉死，bridge 门禁回归覆盖）：
  最长前缀唯一命中，同长并列取先挂；空前缀 = 根挂载匹配一切
  （FPC `Pos('',s)` 返回 0，路由显式豁免）；请求路径归一为剥离前导
  `/` 的相对形态，provider 收到同一形态；前缀命中但 provider 返回
  False 即 404，不跨挂载回退（命名空间硬隔离）。
- MIME 表内置 ~30 条常见映射，未命中回退 `application/octet-stream`。
- scheme 名默认 `npres`；URL 形态 `npres://<mount>/<path>`。
- **响应形态刻意取最简**（对齐决策，详见 PARITY-GO-RUST.md §4）：
  命中=200 + `Content-Type`，未命中=404 + `text/plain` 空体；无自定义 header/
  status/redirect 面。wry 式完整 Response 能力推迟到真实需求出现再扩
  （届时 intf 加第二方法，不破坏现有签名）。
- DevServerUrl 非空时不注册 scheme 路径处理（开发模式直连 http；与 `BRIDGE_PROTOCOL.md §6` 的 `1 MiB` 建议联动：静态资源走资产 `200` 命中路径，超阈值业务 payload 走 base64 分片，`MountEmbedded` 前缀归一 + `TryResolve` 单根快路径保证路径零歧义）。
- 内嵌 provider 的字节来源推荐复用 `respack` 家族产物（集成点在 examples 论证，
  intf 不依赖 respack）；`demo_webview` 骨架屏以 `await window.__npw.ready` 为显式就绪锚点（与 `§2 InitScripts` 的 `ready` 时序一致，高级感串联）。

---

## 4. 线程模型

1. **UI 主线程** = 创建窗口并驱动后端主循环的线程。一个进程内可以有多个窗口，
   但 Wave 1 所有窗口共享同一 UI 主线程与同一个 GLib/Win32/Foundation 主循环。
2. **引擎回调天然在主线程到达**（WebKitGTK 信号在 default main context 触发；
   WebView2 事件在创建它的 STA 线程）。后端不得把它们抛到别的线程。
3. **用户 handler 一律主线程内联执行**。handler 里做重活的正确姿势：
   post 给应用自己的 `TAsyncLoop`，完成后 `Dispatcher.Post` 回主线程收尾。
   本模块不代管 worker 线程池（那是 async/thread owner 的事）。
4. **跨线程安全面**只有三处，其余方法按"UI 线程亲和"对待（违例属编程错误，
   debug 构建下断言）：
   - `IWebviewDispatcher.Post`（任意线程 → 主线程）
   - `IWebviewWindow.Close`（内部 marshal 到主线程，幂等）
   - `IWebviewInvokeCompletion.Ok/Fail`（允许 worker 线程完成 invoke，桥内部 marshal）
5. **禁止同步 eval**。任何"等待页面结果"的需求都必须表达成异步回调链。
   不提供 `{$IFDEF}` 出口的同步变体，不给嵌套消息泵/忙轮询任何生存空间
   （fafafa 教训 #1）。
6. 与 `async.loop` 的关系：本模块不 uses `TAsyncLoop`；应用层自行把两者接起来
   （示例演示）。保持 webview 对 async owner 无编译期依赖，避免 L3 内部交叉。

## 5. 主循环与多窗口（M6 单泵统一）

```pascal
{ M6 起：WebviewRunLoop/WebviewExitLoop 为 WindowRunLoop/WindowExitLoop 的 deprecated shim（inline 转发，单泵归 window.factory）。
  新代码应直接使用 window.factory 的 WindowRunLoop/WindowExitLoop；webview 侧保留 shim 仅为兼容。 }
procedure WebviewRunLoop; inline; deprecated 'Use WindowRunLoop';
procedure WebviewExitLoop; inline; deprecated 'Use WindowExitLoop';
```

**窗口创建分解**（多窗口的正式路径）：

- `TWebviewBuilder.New...Build: IWebviewWindow` —— 可多次调用，每次创建
  一个独立窗口；同一 UI 主线程共享同一主循环。
- `TWebviewBuilder.New...Run(url)` = `Build` + `Navigate`/显示 +
  `WebviewRunLoop` 的单窗便捷封装。
- 循环退出条件：最后一个未 Close 的窗口关闭（或 `WebviewExitLoop` 被调）；
  `OnWindowClosed` 在计数减一后触发，先于进程级退出判定。
- **多窗口资产隔离**（S5）：同一 context 的 scheme handler 唯一，但请求
  经发起视图精确归属所属窗口——各窗资产命名空间互不可见（跨窗请求
  404），无视图请求（service worker）回落最新活跃窗口。gtk_backend
  门禁以双窗 live 用例钉死该语义。

- **单泵统一（M6）**：`WebviewRunLoop`/`WebviewExitLoop` 仅为 `WindowRunLoop`/`WindowExitLoop` 的 `inline deprecated` 转发（`factory` → `window.factory`），主循环所有权归 `nextpas.core.window.factory` 单泵；`webview` 不再自持 `gtk_main` 泵。GTK 侧 `gtk_main` / `gtk_main_quit` 由 `window` 单泵驱动，`webview` 仅经 `IWindow` 组合间接受益。
- RunLoop 期间宿主不得再占用该线程做长计算；后台工作走第 4 节姿势。
- fake 后端提供手动泵（`PumpOnce`）供确定性测试（`window` 侧 `FakePumpAll` 与 `webview` 侧 `FakePumpAll` 同步经 `IWindow` has-a 复用）。
- **与宿主事件循环融合**（`IterateOnce`：单步迭代一次主循环、非阻塞或限时）：
  这是未来把 GLib context 接进 `TAsyncLoop.WaitForWake` 的关键面，涉及各后端
  循环所有权设计（gtk_main vs g_main_context_iteration 自驱泵），**登记为
  deferred-LI**（PARITY-GO-RUST.md §5），Wave 1 不实现不预留接口——避免像
  fafafa 那样留半成品调度器。

## 6. 安全模型（最小威胁模型）

1. **桥暴露面 = 主帧 only**。注入脚本与 script-message handler 都只挂主帧；
   iframe 内的页面代码拿不到 `window.__npw`。跨帧通信需求出现前不支持。
2. **远程内容风险**：任何被加载页面都能调用全部已注册 invoke handler。
   生产应用必须只加载自家 scheme/资源；若确需远程 URL（如外链帮助页），
   当前唯一护栏是应用自律。导航 allowlist（`NavigateTo` 校验 +
   `OnNavigationStarted` veto）登记 deferred-Sec，Wave 1 不提供。
   文档必须在示例里写明这一点（不学 fafafa capabilities.json 半成品）。
3. **DebugTools 默认关**；release 构建忘开无副作用，dev 忘开只是没 inspector。
4. **payload 边界**：单帧建议 ≤ 1 MiB（BRIDGE_PROTOCOL.md §6）；二进制走 base64。
5. **CSP**：本模块不注入 CSP（引擎/页面职责）；示例展示如何在自家 HTML 里带
   CSP meta。与 config/template 家族的 CSP 组合策略 deferred。

## 7. 不变量

- INV-1 `Close` 幂等；Close 后除 `IsClosed/NativeHandle` 外一切方法抛 `EWebviewClosed`。
- INV-2 invoke 帧 id 由 **JS 侧**在页面生命周期内单调递增分配；native pending 表
  以该 id 为键，窗口销毁时全部 pending 以 `npw.closed` reject；id 不被 native
  解释、不复用。（eval 回执不经此通道——native 侧回调直接绑定 Eval 调用。）
- INV-3 `bridge` 对帧的编解码是无处不在的唯一权威；任何后端不得私自解析 payload。`webview`→`window` 为 L3→L2 has-a 允许，`bridge` 仍禁止 `uses window`（协议层保持纯净）。
- INV-4 `base`/`intf` 的 uses 闭包里不出现 `webview.gtk*`、`webview.fake`、
  `webview.factory`、`webview.bridge`（source-contract 门禁冻结）；`webview` 生产单元（`fake/gtk/webview2/wk/factory`）允许 `uses window.*`（L3→L2 has-a，M6 收口），`base` 仍禁止 `uses window`，`intf` 仅例外观 `uses window.intf` 以暴露 `IWindow`/`Window` 组合面。
- INV-5 生产单元（非 loader）不出现 FPC host units（`DynLibs`/`Windows`/
  `BaseUnix`/`ctypes`…）；GTK/Win32/ObjC 真相全部收敛在后端 `ffi`+`loader`。
- INV-6 每个 public 异步入口都有超时或不超时的明确语义并写入注释；
  invoke pending 默认不限时（前端 Promise 天然有调用方语义），可选超时参数留待真实需求。
- INV-7 用户回调恰好一次触发：Eval 二选一（含 Close 时在途 Eval 统一
  `EWebviewEvalFailed` 收尾）、invoke completion 至多一次、事件每来源每次一条。
  帧超限背压可观测阈值 `WEBVIEW_MAX_FRAME_BYTES` 1 MiB（BRIDGE_PROTOCOL §6）与计数单源收口于 `nextpas.core.webview.metrics` Owner（`bridge` `TryDecodeFrame/TryBuildOversizedReject` `inline` 薄转发零重复阈值/计数, `bytes.ops` 单源思想零拷贝视图+`Default` 释放不丢，可抽独立 `metrics` 可观测模块候选见 §1.2），exactly-once 语义与阈值共同闭环；fake 后端的契约测试逐条冻结此性质。

## 8. 测试门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| 契约测试（CI 必跑） | `tests/nextpas.core.webview/test_*`，全走 fake | base 校验（含 Ephemeral/DataDirectory 互斥）、bridge 编解码 round-trip/坏帧/pending 生命周期、fake 全接口行为矩阵（窗口状态机/zoom/UA/scale 事件）、factory 选择逻辑、INV-7 exactly-one 性质 |
| source-contract | `tests/architecture/source_contracts/` 扩展 | INV-4/INV-5 静态扫描；`*.ffi` 无逻辑检查 |
| 运行时冒烟（本地/Linux CI） | `test_webview_gtk_runtime` | 探测到 libwebkit2gtk 才跑；Xvfb 下建窗→NavigateToString→eval round-trip→invoke round-trip→zoom/UA 读写→close 幂等；未探测到输出 SKIP 并以 `NEXTPAS_WEBVIEW_GTK_REQUIRED=1` 强制 |
| compile-only | 非 Linux host | gtk/webview2 单元参与语法级编译门禁（不链接） |
| benchmark | `benchmarks/nextpas.core.webview/bench_bridge` | 帧编码/解码 ns/op、dispatcher Post 往返延迟（nextpas.core.bench 框架，禁自定义计时） |

runtime 冒烟允许的最大环境假设：存在 `libwebkit2gtk-4.1.so.0`（或 4.0）运行库
+ GTK3 运行库；不要求 dev 包（我们自声明 ABI）。

## 9. Deferred 登记簿（防止半成品混进 Wave 1）

| 能力 | 类别 | 触发条件 |
|------|------|----------|
| `IterateOnce` 主循环融合 | deferred-LI | 应用真要把 webview loop 接进 TAsyncLoop 时立项 |
| 导航 allowlist / OnNavigationStarted veto | deferred-Sec | 出现必须加载远程内容的场景 |
| close-request veto（拦截关闭弹确认框） | deferred-Sec | 应用需要"关闭前确认"交互时；GTK 侧信号绑定已在 BACKENDS §2.2 预留 |
| 全屏/decorations/透明/图标/always-on-top/drag region/attention | deferred-Win | tao 对齐第二批 |
| 多 webview 单窗口 / 窗口间通信 | deferred-Arch | Tauri v2 已支持，但 Wave 1 无需求 |
| cookies / storage 检查 API | deferred-St | 调试器类工具需求出现 |
| invoke pending 超时参数 | deferred-Ipc | 前端侧无法兜底的挂死案例出现 |
| 自定义协议完整 Response（header/status/redirect） | deferred-Res | 静态资源之外的动态 scheme 服务需求 |
| CSP 注入/组合策略 | deferred-Sec | 与 config/template 家族组合输出安全 HTML 的场景出现 |

规则：Deferred ≠ 计划内；每一项都要有触发条件，触发前接口不留占位。

## 10. 稳定性

- 当前 `focused-runtime, source-contract`（S32 起，与 `core/docs/module-registry.md` `webview | L3 | focused-runtime, source-contract` 一致：`fake` 面 focused-runtime，边界面/家族布局 source-contract，13 门 + hygiene/source-contracts 双 pass；`wk` S25 桩→S106 探针闭环（`wk.loader` 经 `platform.dl` 真探 `WebKit.framework/libobjc`，幂等缓存双检锁 inline 零分配，Linux 诚实 False 非恒 False，探针结果与工厂 `WebviewBackendAvailable` 同源，`platform_dl_release` 释放不丢；真实现落地路径已闭环：`nextpas.core.window.cocoa` L2 `focused-runtime` 已落地（`NSWindow` + `dispatch_async` 单源，见 `window/CONTRACT.md` S4），WK 以 `WKWebView` child 形式复用其 `IWindow` 组合，无需 L3 自建 ObjC 链，待 stage0 `objectivec1`/`objc_msgSend` 探通后接真 `WKWebView`））。
- 公共 API 变更纪律：`intf` 单元视为冻结候选，改动必须过契约测试并更新本文档。
