# nextpas.core.window Roadmap

**Authority**: 本文件是 window 模块**向前开发**的唯一执行入口。
**Companion**: 定位见 [README.md](README.md)；契约见 [CONTRACT.md](CONTRACT.md)；
架构纵深见 [ARCHITECTURE.md](ARCHITECTURE.md)。
**Updated**: 2026-08-27（S1 family 落地；NEXT=S2）

---

## 0. 进场 30 秒

1. **当前 NEXT = S1**（fake + base/intf/factory/门面 + 契约测试门禁 +
   registry 同批进入）。
2. 波次铁律：**契约先行，fake 同批，生产后端逐波**；每波必须能独立
   land 且全门禁绿。
3. 跨模块纪律：S2 触碰 `webview`、S4 与 `webview` Wave 2/3 协同——
   每波 Land paths 显式声明 + 双端 focused gate；冲突时 Needs Review。
4. Deferred 能力不占位（CONTRACT §9）；想做的第一反应是查登记簿，
   没有触发条件就不做。

---

## 1. 北极星

把散落在 `webview.gtk.win` / `gpu.gl` / `game888.graphics.window` 三处的
窗口能力收敛为一个可对标 winit/tao 抽象质量的 L2 窗口家族，
让 gpu/directui/webview/game888 共享同一窗口契约：

| 支柱 | 含义 |
|------|------|
| 复用 | 一个契约四个消费者；新后端只实现一次 |
| 诚实 | NativeHandle/DPI/几何差异全部上诚实表；不支持即抛错不假装 |
| 可测 | fake 是 CI 契约唯一载体；无图形环境全绿 |
| 纪律 | base/intf 零后端依赖；loader 唯一触 platform.dl；Deferred 不占位 |

---

## 2. 当前状态快照（回写处）

| 项 | 状态 |
|----|------|
| Stage | **S1 完成**（2026-08-27）：`window.base/intf/fake/factory/门面` 5 单元 + `test_window_{base,fake,factory,source_contracts}` 4 门禁 + registry 条目同批落地；`make focused` 全绿, `make hygiene` pass |
| 源码 | `core/src/nextpas.core.window.{base,intf,fake,factory}.pas + window.pas`（S1 family 完整） |
| Registry | 已进入：`window` L2 draft（`core/docs/core-module-registry.md` 一行） |
| **NEXT** | **S2**（GTK 后端抽取） |

---

## 3. 分波实施图

### S1 — 契约 + fake 家族（首个 source family）

| 字段 | 内容 |
|------|------|
| **Status** | **done (2026-08-27)** — 5 单元 + 4 门禁 + registry 同批落地；`make focused` 全绿, `source-contract=pass`, `hygiene=pass` |
| **Do** | ①`window.base`（kinds/options/event/句柄别名/错误族 + Check 校验）；②`window.intf`（IWindow/IWindowDispatcher/回调命名类型）；③`window.fake`（注入事件、PumpOnce/PumpAll、状态脚本、假句柄）；④`window.factory`（注册表/TWindowBuilder/RunLoop 对/能力探测）；⑤门面 re-export；⑥契约测试套件（全走 fake）；⑦source-contract 扫描扩展（INV-3/4/5）；⑧registry 条目同批进入 |
| **Don't** | 不建任何生产后端单元（gtk.ffi 也不要）；不做 Deferred 登记簿里任何能力；不动 webview/gpu 任何文件 |
| **Done when** | 契约测试覆盖 CONTRACT §8 首行清单全项且绿；source-contract 门禁含 window 规则且绿；registry 行存在且架构门禁接受；`make hygiene` 干净 |
| **Gates** | `make focused FOCUS=core/tests/nextpas.core.window/<gate>` 全绿；source-contract gate；`git diff --check`；`make hygiene` |
| **Land paths** | `core/src/nextpas.core.window*.pas`；`core/tests/nextpas.core.window/**`；`core/docs/window/**`；`core/docs/core-module-registry.md`（仅 registry 一行）；`tests/architecture/source_contracts/`（window 扫描段） |
| **风险与兜底** | FPC 匿名回调/interface 细节踩坑 → 先落最小接口骨架再扩；factory 探测顺序定案争议 → 按"平台原生 > gtk > sdl2"冻结并在测试钉死 |

### S2 — GTK 后端抽取（受控跨模块 slice）

| 字段 | 内容 |
|------|------|
| **Status** | pending（触发条件已满足：第二个真实 consumer gpu/directui 在途 + 本 lane 立项） |
| **Do** | ①从 `webview.gtk.win` 机械抽取 `window.gtk`（映射表见 ARCHITECTURE §2.1）；②新增 `window.gtk.ffi/.loader`（窗口子集 ABI 自声明，platform.dl 装载）；③事件信号挂接（delete-event/configure/focus/scale，cdecl 回调带 owner 指针）；④`test_window_gtk_runtime` 冒烟（Xvfb 探测式）；⑤dispatcher bench |
| **跨模块说明** | **原因**：抽取是本模块立项的既定反哺路线（webview CONTRACT §1.1），webview 是第一个受益 consumer。**范围**：读 `webview.gtk.win` 作抽取源；不改 webview 生产代码（双份 GTK 缝过渡期共存，去重评估推迟 S4）。**风险**：webview lane 并行演进导致抽取源漂移 → 抽取以 f961037 时点源为基准，漂移部分由 webview owner 自行跟进。**额外验证**：webview 全部既有门禁跑一遍证明 consumer 无感 |
| **Don't** | 不改 `IWebviewWindow` 公共面；不在本波把 webview 切到组合注入（那是独立收口 slice）；不动 webview 的 ffi/loader |
| **Done when** | Xvfb 下冒烟全绿（探测不到则 SKIP 断言成立）；机械搬移 diff 与行为叠加 diff 分离可审；webview 侧门禁全绿；诚实表 gtk 列逐格复核 |
| **Gates** | window 契约测试回归绿；`test_window_gtk_runtime`；webview 主 gate 回归；`git diff --check`；`make hygiene` |
| **Land paths** | `core/src/nextpas.core.window.gtk*.pas`；`core/tests/nextpas.core.window/**`；`core/benchmarks/nextpas.core.window/**`；`core/docs/window/**`；（只读参照）`core/src/nextpas.core.webview.gtk.win.pas` |
| **风险与兜底** | 无显示环境 CI → SKIP 机制 + REQUIRED 开关；GTK 信号回调生命周期竞态 → owner 计数保护沿 webview 语义 |

### S3 — SDL2 后端

| 字段 | 内容 |
|------|------|
| **Status** | pending |
| **Do** | `window.sdl2.ffi/.loader/.sdl2`：SDL_CreateWindow 族、事件泵（SDL_PollEvent → TWindowEvent 映射）、用户事件 dispatcher、WMInfo 句柄化；game888 复用评估文档化 |
| **Don't** | 不做渲染/音频等 SDL 其余子系统；不让 sdl2 后端依赖 gtk 任何单元 |
| **Done when** | fake 契约测试原样过 sdl2 后端的等价用例（有头环境探测式）；诚实表 sdl2 列复核；compile-only 门禁覆盖非 Linux host |
| **Gates** | 同 S1 + `test_window_sdl2_runtime`（探测式）+ compile-only |
| **Land paths** | `core/src/nextpas.core.window.sdl2*.pas`；`core/tests/nextpas.core.window/**`；`core/docs/window/**` |
| **风险与兜底** | SDL2 <2.24 无 display scale → 诚实回退 1.0（诚实表已冻）；CI 无 SDL2 → SKIP + REQUIRED 开关 |

### S4 — Win32 / Cocoa 后端（与 webview Wave 2/3 协同）

| 字段 | 内容 |
|------|------|
| **Status** | pending |
| **Do** | `window.win32.*`（CreateWindowEx + WM_* + message-only dispatcher）、`window.cocoa.*`（NSWindow + dispatch_async）；与 webview Wave 2/3 同步评估 GTK 缝/Win32 缝/Cocoa 缝的去重收口（webview 改组合 IWindow） |
| **跨模块说明** | **原因**：避免两套后端各养一份 Win32/Cocoa 窗口缝（webview §1.1(b) 既定触发）。**范围**：本波内完成 webview→window 组合切换的独立收口 slice。**风险**：webview Wave 2/3 平台环境未启动 → 组合切换以 Linux 侧先行验证，Win/macOS 收口随各自 wave。**额外验证**：webview 双端门禁 + window 新增 runtime 门禁 |
| **Done when** | Windows host compile-only + Wine/真机 smoke（按当时平台能力）；macOS 编译器能力 probe 结论记录（objcclass 或纯 C 形态二选一）；组合切换后 webview 门禁全绿 |
| **Gates** | 各自 host 门禁 + webview 回归 + hygiene |
| **Land paths** | `core/src/nextpas.core.window.{win32,cocoa}*.pas`；webview 组合收口涉及文件（显式列出）；`core/docs/{window,webview}/**` |
| **风险与兜底** | stage0 不支持 objectivec1 modeswitch → BACKENDS §4 预案的纯 C 形态；Windows runner 缺位 → compile-only + Wine 为最低证据线并如实记录 residual |

### S5 — Mobile attach（android / uikit）

| 字段 | 内容 |
|------|------|
| **Status** | pending（前置：platform.android/uikit host ABI 就绪） |
| **Do** | `ParentHandle` attach 路径实装；ANativeWindow/UIWindow 交付与宿主生命周期事件映射；几何只读语义落地 |
| **Don't** | 不做 Activity/UIApplication 托管（宿主模型归 app 层）；不做 top-level 创建伪装 |
| **Done when** | 宿主工程集成 demo 走通 attach→NativeHandle→渲染消费链路；诚实表 mobile 列复核 |
| **Land paths** | `core/src/nextpas.core.window.{android,uikit}*.pas`；`core/docs/window/**` |
| **风险与兜底** | 宿主生命周期事件映射复杂度超预期 → 缩小为最小 attach 面，其余登记 deferred |

### M-band — 维护带（永续兜底）

Era 全堵时的合法工作池：doc-truth 对齐、flake 修复、诚实表复核刷新、
机械抽取收尾、门禁拆分。禁止：新公开 API 家族、Deferred 提前实现、
宣称升级。

---

## 4. 硬约束

- 每波 land 必须回写本文件（Status/NEXT/changelog 一行）。
- 正确性 gate 红 → 该波整波回滚，不带红 landing。
- 跨模块波次必须有原因/范围/风险/额外验证四要素（S2/S4 已示范）。
- registry 只在首个 source family 同批进入，文档先行不抢跑。

---

## 5. 变更日志

| 日期 | 变更 |
|------|------|
| 2026-08-27 | S1 family 落地：5 单元（base/intf/fake/factory/门面）+ 4 门禁（base/fake/factory/source_contracts）+ registry 一行同批落地；INV-3/4/5 扫描 + 句柄/错误/事件契约全绿；NEXT=S2 |
| 2026-08-26 | S0 文档 slice 落地：四件套（README/CONTRACT/ARCHITECTURE/ROADMAP）进 `core/docs/window/`；NEXT=S1 |
