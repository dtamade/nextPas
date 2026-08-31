# nextpas.core.webview 完整路线图

**模块路径**：`core/src/nextpas.core.webview*.pas`  
**层级**：L3 家族（依赖 L0-L2；`platform.dl` + `json` owner）  
**Owner**：core-webview lane  
**最后更新**：2026-08-30  
**当前版本**：**1.90**（S97 跨平台文档冻结）
**当前状态**：**Production Ready · focused-runtime · 冻结**（`core-module-registry` 已 `focused-runtime`，13 gates 全绿 heaptrc 0，hygiene/source-contracts 双 pass，bench S27→S95→S97 无回归，三平台 `linux GTK / windows WebView2 wine / macOS WK 桩` 诚实）  
**对标基准**：[PARITY-GO-RUST.md](PARITY-GO-RUST.md)（Rust wry/tao/Tauri v2 · Go Wails v2/v3）  
**稳定契约**：[CONTRACT.md](CONTRACT.md)（权威）· [README.md](README.md)（消费面）· [BRIDGE_PROTOCOL.md](BRIDGE_PROTOCOL.md)（v1 帧）· [BACKENDS.md](BACKENDS.md)（能力诚实表）

> **本文定位**：唯一前瞻路线图（living roadmap）。`core/docs/plans/2026-08-25-webview-module.md` 已归档至 S5，S6-S44 回溯与 S45+ 排期以本文为准；冲突时以 `CONTRACT.md` 为准。

---

## 1. 执行摘要

`nextpas.core.webview` 为 Tauri/Wails 式桌面应用外壳：系统自带浏览器引擎 + 原生窗口壳 + 统一 IPC 桥。Wave 1（Linux gtk + fake）已 **Production Ready**；Wave 2（Windows WebView2）已 **真 controller 可交互（wine）**；Wave 3（macOS WK）为 **桩冻结**，Darwin 真实现待编译器 ObjC 探通。S36-S44 完成“零重复 + 全 inline”匠心收口，已具备独立窗口模块抽取条件。

**下一阶段核心命题**：在不破坏 `IWebviewWindow 13 方法面` 冻结的前提下，完成 **窗口独立** 与 **W3 真实现**，并将 `CONTRACT §9` 的 7 项 deferred 按“真实用例触发”逐步转正。

---

## 2. 现状快照（1.90）

| 维度 | 事实 |
|------|------|
| **类型冻结** | `TWebviewKind` 4 值穷尽 · `TWebviewOptions` 4 不变量（Ephemeral/DataDir 互斥、尺寸非负、max≥min、scheme 小写 token）· `EWebviewError` 8 类目（ecNotFound/ecIO/ecParse/ecInternal）· `IWebviewWindow` 13 方法 composition 冻结（S31） |
| **后端矩阵** | `fake` 全平台（测试）· `gtk` Linux WebKitGTK 4.1→4.0 dlopen 自声明 ABI · `webview2` Windows COM 真链（Env→Controller、WebMessage、ExecuteScript、WM_SIZE、DPI 真值、Post 调度，wine 可交互）· `wk` macOS 桩（恒 False，Darwin 预留） |
| **复用收口** | `base` 7 校验 helper 全 `inline`：`IsValidWebviewSchemeToken` / `CheckWebviewSize/Min/Max/Session/InitScript/EventName/DevServerUrl` / `CheckInvokeCmd`；`WebviewGrowCapacity(0→4→2×)` 全家族 inline 单源；`NormalizeWebviewAssetPath` 5 处复用；`http.mime` 65 项单源（S52-S97） |
| **门禁** | 13 gates 全绿 `heaptrc 0`（`base 10 + factory 13 + bridge 17 + vfs 6 + wk 3` 等）· `hygiene`/`source-contracts` 双 pass · `fpc -vh` 0 hint · `factory` 0 warnings（2 处 exhaustive 以 `{$WARNINGS OFF}` 抑制） |
| **性能基线** | `bench_vfs` 过滤均值 1.22 GB/s（SmallHit 681ns / Fallback 894ns / Miss 217ns / 1M 800µs）· `bench_bridge` TryDecode 4.18µs / Resolve 622ns / Reject 2.37µs / Emit 1.06µs（S27 基线 → S95→S97 无回归，哈希/零拷/池化零额外分配） |
| **文档** | `CONTRACT 1.90` · `README 1.90` · `ROADMAP 1.90` · `BRIDGE v1` · `BACKENDS` 能力诚实表 · `PARITY` 不抄清单 |

---

## 3. 回溯：S0-S44 已交付

| 区间 | 关键交付 | 治理锚点 |
|------|----------|----------|
| **S0** | 五件设计（CONTRACT/BRIDGE/BACKENDS/PARITY/plan）+ 对标审查 | 文档阶段 |
| **S1-S5** | `base/intf/fake/bridge` + `gtk.ffi/loader/win/gtk` + `factory/Builder/examples` + `registry draft→focused-runtime` | Wave 1 闭环，Xvfb 冒烟 |
| **S6-S10** | `GetTitle`、三会话 live、`DataDirectory` 修复、`demo`、`DevServerUrl`/`Initial*`、Builder 三形态、`respack` 三形态 | 多窗隔离、资产惰性 |
| **S11-S15** | `vfs` 适配器、`bench_vfs`、高级感/性能三轴、MIME 共享 `webview.mime` 65 项、`bench_bridge`、`demo` 骨架/错误边界 | 零 Delete、65 项回退 |
| **S16-S20** | Production Ready、respack 高级感对齐、W2 桩/loader/wine、Win32 真窗口、DPI/Minimize | wine 可交互 |
| **S21-S25** | 真 controller（Env→Controller/Eval/桥）、导航事件、调度稳定、门禁 bench、W3 WK 桩三件套 | 13 门全绿 |
| **S26-S30** | 终极封版（hints/Closed 守卫）、bench 刷新、警告洁净、主循环 4 后端、静态审计 | 冻结复核 |
| **S31-S35** | 类型冻结、注册表冻结、零负载抛光、零开销（Builder 去重+VFS 零 Delete）、`__npw` 早筛 | 零 TODO |
| **S36-S44** | **匠心收口**：S36 13 链路 inline·S37 Token 复用+倍增+早筛·S38 InitScripts 倍增·S39 几何三·S40 会话/脚本二·S41 GrowCapacity·S42 审计·S43 全校验 inline·S44 Builder 全 inline | **零重复 + 全 inline** |

> 完整版本链见 `CONTRACT.md` `版本 1.38` 承接段（1.37←1.36←...←1.6）。

---

## 4. 前瞻：S45+ 排期（触发式，不预埋占位）

### 4.1 S45 — 窗口独立 lane（`nextpas.core.window`）

**触发**：满足其一即立项 — (a) 第二个真实 consumer 出现（gpu/font/IDE workbench）或 (b) W2 真实现前必须收敛窗口代码。  
**范围**：`webview.gtk.win` + `webview2.win` 纯函数式缝上移为 `window.gtk` / `window.win32` / `window.cocoa`（零 webview 概念），`IWebviewWindow` 保持组合面（消费方无感）。含 `GetScaleFactor` 浮点诚实、`WM_DPICHANGED`/`OnScaleChanged` 一等约束、Android/iOS `attach` 模型预留。  
**验证**：`window` 独立契约测试（无 webview 依赖）+ `webview` 双窗 live 回归 + `gpu` 最小 consumer 冒烟。  
**退出**：`window` 单元 `focused-runtime`，`webview` 删除 `gtk.win`/`webview2.win` 内缝，仅保留组合。

### 4.2 S46 — W3 真实现（Darwin）

**触发**：`stage0` 对 `objcclass`/`objc_msgSend` 探通（`compiler` lane 给出能力位）。  
**范围**：`wk.ffi` 真类型 + `wk.loader` 动态探测（WebKit.framework）+ `wk` 真 `WKWebView`（`WKWebsiteDataStore` 私有/持久、`customUserAgent`、`pageZoom`、`backingScaleFactor`、`WKScriptMessageHandler` 桥、`evaluateJavaScript`），`IsOnMainThread` 真线程（`NSThread isMainThread`），`WkLiveWindowCount` 真 `NSRunLoop`。  
**验证**：Darwin 真机建窗→`npres` 资产→`invoke` round-trip→`Eval`→`Close` 幂等；Linux 仍桩 false。  
**退出**：`DefaultWebviewKind` 在 Darwin 优先 `wk`，`BACKENDS.md` 能力表补真值。

### 4.3 S47 — 主循环融合（`IterateOnce`）

**触发**：应用真要把 `WebviewRunLoop` 接进 `TAsyncLoop`（`async` owner 提出）。  
**范围**：`g_main_context_iteration` 自驱泵（替代 `gtk_main` 阻塞）、Win32 `MsgWaitForMultipleObjects` 融合、Wk `NSRunLoop` 限时迭代；`WebviewIterateOnce(timeout)` 非阻塞面（deferred-LI 转正）。  
**验证**：`async` 侧 `WaitForWake` 集成冒烟 + `fake` 确定性泵。  
**退出**：`CONTRACT §5` 循环所有权章节更新，`TAsyncLoop` 无编译期依赖保持。

### 4.4 S48 — 导航 allowlist / veto（安全）

**触发**：出现必须加载远程内容的场景（外链帮助页、OAuth 回调）。  
**范围**：`NavigateTo` 校验 + `OnNavigationStarting` veto（`allow/block`）、`OnNavigationFailed` 已有，补 `OnNavigationStarting` 可拦截面（deferred-Sec 转正）。  
**验证**：远程 URL 默认 block、allowlist 命中放行。  
**退出**：`CONTRACT §6` 威胁模型更新，示例明示 `npres` 生产、`https` 受控。

### 4.5 S49 — 窗口能力第二批（deferred-Win）

**触发**：`tao` 对齐真实用例（全屏、decorations、透明、图标、always-on-top、drag region、attention）。  
**范围**：按需逐项加 `IWebviewWindow` 方法（不预埋），每项独立 slice。  
**验证**：对应平台诚实表 + 单测。  
**退出**：`IWebviewWindow` 13→N 渐进，保持 `CONTRACT` 版本递增。

### 4.6 S51 — 性能与文档终局

**触发**：S45-S49 任一落地后。  
**范围**：`bench_vfs`/`bench_bridge` 过滤均值重测（`nextpas.core.bench`）、`README` 徽标刷新、`PARITY` 再对标。  
**验证**：`bench` 无回归、`hygiene`/`source-contracts` 双 pass。  
**退出**：`CONTRACT 1.50` 冻结。

---

## 5. Deferred 转正优先级（CONTRACT §9 映射）

| 能力 | 类别 | 转正优先级 | 依赖 |
|------|------|------------|------|
| `IterateOnce` | LI | P1（S47） | `window` 独立、`async` |
| allowlist/veto | Sec | P1（S48） | 远程内容用例 |
| close-request veto | Sec | P2 | 确认框用例 |
| 全屏/decorations/透明/图标/always-on-top/drag/attention | Win | P2（S49） | `tao` 用例 |
| 多 webview 单窗口 / 窗口间通信 | Arch | P3 | Tauri v2 用例 |
| cookies/storage API | St | P3 | 调试器用例 |
| pending 超时参数 | Ipc | P3 | 挂死用例 |
| 自定义 Response（header/status/redirect） | Res | P3 | 动态 scheme 用例 |
| CSP 组合 | Sec | P3 | `config` 联动 |

> 规则：无真实用例不转正；转正前接口不预埋（防 fafafa 半成品）。

---

## 6. 依赖与风险

| 依赖 | 说明 | 缓解 |
|------|------|------|
| `platform.dl` | 唯一动态加载原语，`DynLibs` 禁用 | `loader` 单元唯一触点，门禁扫描 |
| `stage0 objcclass` | W3 真实现前提 | W3 前 probe，失败则 `wk` 保持桩，文档诚实 |
| `window` 独立 | 影响 `webview.gtk/win` 两缝 | 受控跨模块 slice，`IWebviewWindow` 组合面不变 |
| `async` 融合 | `IterateOnce` 需循环所有权重构 | 小步：先 `window`，后 `IterateOnce`，`TAsyncLoop` 无编译依赖 |

---

## 7. 里程碑与退出标准

- **M1（S45）**：`window` 独立 `focused-runtime`，`webview` 双窗 live 回归绿。
- **M2（S46）**：Darwin 真 `WKWebView` 可交互，`DefaultWebviewKind` 在 Darwin 优先 `wk`。
- **M3（S47-S48）**：`IterateOnce` + `allowlist` 转正，`async` 集成冒烟绿。
- **M4（S51）**：`CONTRACT 1.50` 冻结，bench 无回归，`README` 对齐。

每个里程碑一个可回滚 commit，`worktree clean` + `focused gate` + `hygiene` + `git diff --check` 后经 `landing/*` 候选分支 `cherry-pick` 入 `main`（不 raw merge lane）。

---

## 8. 治理

- **权威层级**：`CONTRACT.md` > `ROADMAP.md` > `2026-08-25-webview-module.md`（已归档）。
- **Worktree 纪律**：`core-webview` lane 单 worktree，`main` 仅总控 landing。
- **门禁**：`test_webview_*` 13+10+6+3 全绿 `heaptrc 0`；`hygiene`；`source-contracts`（INV-4/INV-5）。
- **Bench**：`bench_vfs`/`bench_bridge` 过滤均值，`nextpas.core.bench` 框架，禁自定义计时。

---

## 9. 变更记录

- 2026-08-28 1.38：S44 收口，本文初版（承接 S0-S44，S45+ 前瞻定版）。
- 2026-08-25 1.0：`2026-08-25-webview-module.md` S0-S5 初版（已归档）。
