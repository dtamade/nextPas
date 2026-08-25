# nextpas.core.webview 模块设计（2026-08-25）

> 状态：S0 文档阶段（v0.2 深化 + Go/Rust 对标审查完成）。
> 本文是活动计划；稳定契约在 `core/docs/webview/`
> （[README](../webview/README.md) / [CONTRACT](../webview/CONTRACT.md) /
> [BRIDGE_PROTOCOL](../webview/BRIDGE_PROTOCOL.md) / [BACKENDS](../webview/BACKENDS.md) /
> [PARITY-GO-RUST](../webview/PARITY-GO-RUST.md)）。
> 冲突时以 CONTRACT 为准，本文记录切片顺序与治理约定。

## S0 深化记录（2026-08-25 第二轮）

对标 Rust wry/tao/Tauri v2 与 Go Wails 后的修订：

- **修正**：桥协议 id 分配表述自相矛盾（统一为 JS 侧分配，INV-2 同步改写）；
  README 示例代码语法；Eval 补 exactly-one 回调语义（INV-7 新增）。
- **补面**：窗口状态操作（maximize/minimize/restore/focus）、zoom、UA 读写、
  InitScripts、DataDirectory/EphemeralSession（互斥校验）、DPI 只读最小集
  （GetScaleFactor/OnScaleChanged）、Maximized 启动项。
- **立牌**：CONTRACT §6 最小威胁模型（桥主帧 only、远程内容风险）、§9
  Deferred 登记簿（七项各带触发条件，防半成品占位）、PARITY §5 刻意不抄清单。

## 背景

总控决定建立 Tauri/Wails 式桌面应用外壳模块：接口抽象在前、系统浏览器引擎后端
在后。前身项目 `~/projects/fafafa.webview` 评估结论：FFI 资产与桥协议语义可移植，
上层（同步 eval、每后端各一套 IPC、三态 handler 签名、死代码调度器）一律抛弃；
其腐化根源——缺主线程 dispatcher 与统一异步语义——正是本模块 S1-S2 要先打的地基。

环境事实（2026-08-25 探测）：本机有 `libwebkit2gtk-4.1.so.0` 运行库、GTK3 3.24.52、
FPC 3.3.1；无 webkit2gtk dev 包。自声明 ABI + dlopen 路线下，Linux 运行时冒烟
本机即可执行。

## 决策

### D1：L3 家族形态，db 家族为治理模板

`nextpas.core.webview` 是 L3 模块族：门面 + base/intf 契约层 + bridge 协议层 +
按引擎划分的后端子家族（gtk/webview2/wk）+ fake 测试后端 + factory。
依赖方向、注册表时机、source-contract 门禁全部对齐 db 家族先例。
registry 补行随首个源码批次落地（门禁拒绝无 source family 的注册行）：

```
| `webview` | L3 | desktop app shell over system web engines (WebKitGTK/WebView2/WKWebView backends; unified IPC bridge) | yes | L0-L2 plus json owner; platform.dl | draft |
```

### D2：异步语义三条红线（fafafa 反面教材的制度化）

1. eval 一律异步回调，无同步形态、无条件编译出口；
2. 用户回调一律 UI 主线程触发，跨线程只经 `IWebviewDispatcher.Post`；
3. handler 错误走异常 → 桥转 reject，禁止 out 参数三态签名。

### D3：协议唯一，transport 薄

桥协议 v1 的编解码/pending 表/注入脚本只在 `webview.bridge` 存在一份实现；
三个真实后端各自只做"消息通道 ↔ 帧"的搬运。fake 后端也走完整协议栈，
契约测试覆盖的就是生产路径。

### D4：波次

Wave 1 = Linux（gtk）+ fake；Wave 2 = Windows（webview2，移植 fafafa COM 头）；
Wave 3 = macOS（wk，先做 stage0 ObjC 能力 probe）。平台能力差异以语义诚实表
公开（CONTRACT §2.2），不做跨平台假装。

### D5：窗口壳反哺路线（总控确认，2026-08-25）

长期需要独立跨平台窗口模块（含 Android/iOS 的宿主 surface attach 模型），
webview 是第一个 consumer；Tauri 的 tao+wry 分层即此结构。节奏：Wave 1 不新建
模块，窗口壳以内部缝 `webview.gtk.win`（纯函数式、无 webview 概念）实现；
抽取触发条件与流程见 CONTRACT §1.1——第二个 consumer 出现或 Wave 2 落地前，
按受控跨模块 slice 上移为独立 lane。移动端语义（attach ≠ top-level）在窗口
模块立项时作为一等约束，不阻塞 webview 波次。

## 切片计划

| Slice | 内容 | 验证 | 备注 |
|-------|------|------|------|
| **S0**（本批） | 设计文档五件（含 PARITY-GO-RUST）+ 本计划 + 对标审查轮 | 文档评审；不改 src/tests/registry | 文档阶段 |
| S1 | `base`+`intf`+门面骨架+`fake` 后端+契约测试骨架；**registry 补行同批** | focused gate（fake 全接口矩阵：窗口状态机/zoom/UA/scale/Ephemeral 互斥/exactly-one 性质）；source-contract 扩展（INV-4/INV-5） | intf 视为冻结候选起点 |
| S2 | `bridge` 协议 v1 编解码+pending 表+注入脚本常量 | bridge 契约测试 round-trip/坏帧/生命周期；bench_bridge 建立 | json owner 解析 |
| S3 | `gtk.ffi`+`gtk.loader`（探测 4.1→4.0，符号级能力分支） | compile-only 门禁（全 host）；loader 探测单测（真机）；ABI 对照说明 | 取证方式参照 platform FFI import workflow |
| S4 | `gtk.win` 内缝（纯函数式窗口操作）+ `gtk` 后端运行时：窗口壳+导航+Eval 异步回执+scheme+dispatcher | runtime 冒烟（Xvfb）：建窗→eval round-trip→invoke round-trip→zoom/UA 读写→close 幂等；无库环境 SKIP；gtk.win 单元独立契约测试（无 webview 依赖断言） | OnReady/OnNavigation 事件矩阵；eval 结果矩阵逐格断言；内缝为 D5 抽取预备 |
| S5 | `factory` 选择逻辑+Builder+examples（hello/assets/devserver）+文档收口（API reference、语义诚实表复核） | focused gate 全量+hygiene+git diff --check；示例手工验收清单 | registry truth level 复评 |
| W2/W3 | webview2 / wk 波次独立立项 | 各自 probe 先行 | 不混入 Wave 1 lane |

每个 slice 一个可回滚 commit；S1-S5 全部在 `.worktrees/core-webview`
（分支 `codex/core-webview`）推进。

## 验证与 landing 纪律

- focused 入口：`make focused FOCUS=core/tests/nextpas.core.webview/<gate>`。
- landing 前：worktree clean、focused gate 通过、`git diff --check`、
  `make hygiene`；基于最新 main 建 `landing/core-webview-docs-20260825`
  类候选分支做 path-limited cherry-pick，不 raw merge lane。
- runtime 冒烟红点处理：环境缺库属 SKIP 不是 FAIL；`NEXTPAS_WEBVIEW_GTK_REQUIRED=1`
  下缺库才 FAIL（CI 用）。已知红点如实记录，不为变绿改期望。

## 风险登记

| 风险 | 应对 |
|------|------|
| WebKitGTK 4.0/4.1 符号漂移 | loader 以符号存在性探测分支，不做版本字符串猜测；最小函数面冻结后再扩 |
| 老 WebKit run_javascript 无结果回执 | 诚实降级（结果 null），CONTRACT/BACKENDS 已标注；不做 polyfill |
| stage0 对 objcclass 的支持未知 | W3 前 probe；退化路径 objc_msgSend 手工形态已预留 |
| 多 AI 并行活动冲突 | 单一 lane worktree；landing 走候选分支重放；共享文件（registry）改动与源码同批且最小化 |
| 与未来自绘 UI 栈（gpu/font）关系 | webview 定位独立产品线"应用桌面外壳"；两者仅在 examples 层可能相遇，intf 无交叉 |

## 跨模块影响声明

S0 无跨模块改动。S1 起 registry 行新增属于治理动作（与源码同批）。
bridge 对 `nextpas.core.json`、loader 对 `platform.dl` 均为既有 owner 的
正常消费；若消费中发现 owner 缺陷，按 core/AGENTS.md 受控跨模块流程上报，
不在本 lane 内顺手改。
