# nextpas.core.webview 注入桥协议 v1

**状态**: Live（S2 落地——`nextpas.core.webview.bridge` 为唯一权威实现；
fake 后端已完整走协议栈，gtk/webview2/wk 后端按波次接入同一实现）
**权威实现**: `nextpas.core.webview.bridge`（全后端唯一；后端只是 transport）

---

## 1. 总览

桥 = 一段在文档创建早期注入页面的 JavaScript（bridge script）+ native 侧的
编解码与 pending 管理。目标：

- 前端拿到 `window.__npw.invoke(cmd, payload?) → Promise<result>` 的 Tauri 式心智模型；
- native 拿到统一的帧入口，**不感知引擎差异**（差异被 transport 层吸收）；
- 协议自带版本号，前后端可独立演进。

```
┌── 前端 (页面) ──────────────────────────────┐
│ window.__npw.invoke('ping', {...})          │
│   → 帧 {v,id,cmd,payload}                   │
│   → postMessage 通道（平台 transport）        │
└──────────────┬──────────────────────────────┘
               ▼
┌── transport（各后端薄适配）─────────────────┐
│ GTK:    WebKitUserContentManager            │
│         script-message-handler "npw"        │
│ WebView2: chrome.webview.postMessage        │
│           → WebMessageReceived              │
│ WK:     WKScriptMessageHandler "npw"        │
└──────────────┬──────────────────────────────┘
               ▼
┌── webview.bridge（唯一实现，后端无关）───────┐
│ 解帧 → pending 表/直接分发                    │
│ handler 结果 → __npw.__resolve/__reject     │
│ Emit → __npw.__emit                          │
└──────────────────────────────────────────────┘
```

## 2. 注入时机与 bridge script

- 注入点：document-start 等价能力（GTK：`UserScript` at
  `WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START`，for main frames only；
  WebView2：`AddScriptToExecuteOnDocumentCreated`；WK：`WKUserScript` document-start）。
- **每次导航都会重新注入**；native 在注入完成回调（WebView2）或首次帧到达（GTK/WK）
  处触发 `OnReady`。协议不假设注入与首个 invoke 的先后序——JS 侧用
  `window.__npw.ready` promise 兜底（见 §4）。
- bridge script 文本作为常量存放于 `webview.bridge`（`NPW_BRIDGE_SCRIPT`），
  版本常量 `NPW_BRIDGE_VERSION = 1`。

**生成源与校验门（hygiene 零产物口径显式标注）**
- 单一真值：`core/src/nextpas.core.webview.bridge.js`；生成物：`core/src/nextpas.core.webview.bridge.script.inc`（Pascal 转义，已跟踪提交，意向生成源而非构建产物，`scripts/build-hygiene-check.sh` 仅拦截 `.o/.ppu/.a/.exe/link*.res` 等二进制产物，不视其为违规）。
- 再生成：单引号 `'` → `''` 转义，每行包为 `'...' + '#10 +'`（末行无 ` +`），与 `core/src/nextpas.core.webview.bridge.pas:180 {$I nextpas.core.webview.bridge.script.inc}` 对齐，头部含 `AUTO-GENERATED`/`Source:`/`Regenerate:`/`Verify:`/`Hygiene:` 显式标注。
- 校验门：`bash core/tests/nextpas.core.webview/contracts/check_webview_contracts.sh` 会以 `core/src/nextpas.core.webview.bridge.js` 重生成临时体并 `diff -u` 对比 `.script.inc` 正文（body 行以 `'` 起始），并断言头部含 `AUTO-GENERATED`，与 `design-conventions.md §1` 的 generated vs hand-written 纪律同源。

### 2.1 JS 面（公开给前端代码）

```js
window.__npw = {
  version: 1,
  ready,                    // Promise，注入完成即兑现；业务脚本发首帧前 await 它
  invoke(cmd, payload)      // payload 任意 JSON 值，缺省 null；返回 Promise<any>
  listen(event, callback)   // 订阅 native→js 事件，返回退订函数
  emit(event, payload)      // js→js 本地广播（不经 native）；可选便利
};
// 内部入口（native 调用，前端业务代码不得触碰）：
window.__npw.__resolve(id, resultJson)
window.__npw.__reject(id, errObj)     // errObj = {code, message}
window.__npw.__emit(event, payloadJson)
```

> 就绪信号的唯一权威名是 **`window.__npw.ready`**（不是全局 `__npwReady`）。
> README 示例、CONTRACT §2.2 注记与本节引用同一名字。

约定：

- `invoke` 的 payload 与结果都是**任意 JSON 值**（推荐对象）；序列化由 JS 侧
  `JSON.stringify`、native 侧 json owner 完成。
- `listen` 回调收到的 payload 已反序列化为 JS 对象。
- **id 分配（唯一权威规则）**：invoke 帧 `id` 由 **JS 侧**在页面生命周期内
  单调自增分配（u53 安全范围）；native 不解释、不重排、原样回显。native 侧
  pending 表以该 id 为键。注意区分：native 发起的 `Eval` 调用**不走本协议**——
  它的完成回调直接绑定在 Eval 调用对象上，与帧 id 无关（见 CONTRACT.md §3.2）。

## 3. 帧格式

### 3.1 js → native（invoke 帧）

transport 上传递的是**一个 JSON 文本字符串**：

```json
{"v":1, "id":7, "cmd":"ping", "payload":{"hello":"world"}}
```

| 字段 | 类型 | 必填 | 语义 |
|------|------|------|------|
| `v` | 整数 | 是 | 协议版本，恒为 1 |
| `id` | 正整数 | 是 | JS 侧分配，回执原样携带 |
| `cmd` | 字符串 | 是 | 非空；建议 `<domain>.<action>` 命名 |
| `payload` | 任意 JSON | 否 | 缺省视为 `null` |

非法帧（无法解析 / `v≠1` / 缺字段 / `cmd` 空）→ native 静默忽略；
**不对坏帧回 reject**（此时可能连可靠回执通道都没有）。debug 构建下
bridge 经 `log.intf` 输出诊断行（是否保留计数器属实现细节，不入契约）；
测试侧需要构造非法帧时走 fake 后端 `DeliverFrame`（非法帧入参
抛 `EWebviewBadFrame`，见 CONTRACT §2.4）。

### 3.2 native → js（回执）

通过 `Eval` 执行（即走引擎的脚本执行通道）：

```js
__npw.__resolve(7, {"pong":true})
__npw.__reject(7, {code:"npw.handler_error", message:"boom"})
```

- `resultJson` 是 JSON 文本；resolve 时 JS 侧 `JSON.parse` 后兑现 Promise。
- reject 的 `errObj` 兑现为 rejected Promise，rejection 值为
  `{code, message, payload?}`。
- 回执必须携带与请求相同的 `id`；未知 id 的回执静默丢弃（前端已超时/退订属正常态）。

### 3.3 native → js（事件）

```js
__npw.__emit("tick", "{\"n\":3}")
```

- 无 id、无应答、无顺序保证承诺（transport FIFO 之内的尽力而为）。
- 页面未就绪时 emit 直接丢弃（不排队）；需要可靠送达的场景用 invoke。

## 4. 握手时序（正常路径）

```
native                          page
  │ 创建窗口+注册 scheme/script     │
  │ ◄── 导航开始 ─────────────────  │
  │ ── OnNavigationStarted         │
  │ ◄── document-start 注入生效 ── │
  │ ── OnReady                     │
  │ ◄── {v:1,id:1,cmd:"ping",...} ─│ invoke()
  │ （handler 返回/异常）            │
  │ ── Eval(__npw.__resolve(...)) ►│ Promise 兑现
```

竞态说明：若业务脚本在注入前调用 `invoke`，bridge script 尚不存在会抛 ReferenceError。
为消除该窗口期，业务模板应在 `await window.__npw.ready` 后再发首帧；
bridge script 末尾兑现 `window.__npw.ready`。此约定写入 starter 示例，
协议本身不为它增加帧类型。

## 5. 错误码稳定词汇表

| code | 来源 | 含义 |
|------|------|------|
| `npw.handler_missing` | bridge | cmd 未注册 handler |
| `npw.handler_error` | bridge | handler 抛非 EWebviewInvokeError 异常；message 取 exception.Message 原文 |
| `npw.bad_request` | handler | 业务参数错误（handler 抛 EWebviewInvokeError 且 Code='' 时桥补此默认码） |
| `npw.closed` | bridge | 窗口已关闭，pending 统一失败 |
| `npw.timeout` | bridge | 若启用超时（预留，Wave 1 默认不启用） |
| `npw.eval_failed` | transport | Eval 本身执行失败（页面导航中/崩溃等） |

规则：

- 自定义业务码必须以 `app.` 前缀开头，桥不校验内容但保留原文。
- `EWebviewInvokeError.Code` 为空时桥写默认码 `npw.bad_request`；非空且不在词汇表
  也原样透传（词汇表约束的是桥自身行为，不是业务命名空间）。
- 错误码是跨语言契约，改动=破坏性变更，需升协议版本。

## 6. 序列化边界

- 所有文本 UTF-8；transport 层负责引擎编码差异（WebView2 收到的是 UTF-16，
  在 transport 边界转 UTF-8 再交给 bridge；GTK/WK 原生 UTF-8）。
- 单帧 payload 建议 ≤ 1 MiB；超限行为：bridge 不主动拒绝（引擎通道各有上限），
  但 benchmark 记录大帧退化曲线，示例文档给出分块建议。二进制走 base64
  （encoding owner），Wave 1 不做裸二进制帧。
- JSON 解析一律经 json owner（`nextpas.core.json`）；bridge 内禁止手写字符串扫描。

## 7. 帧作用域（iframe 立场）

- 注入 script 与 message handler **只挂主帧**（GTK：`for_main_frame_only`；
  WebView2：DocumentCreated 注入天然主帧；WK：`forMainFrameOnly:YES`）。
- iframe 内代码没有 `window.__npw`，协议不为跨帧投递提供任何机制。
- 主页面若嵌入第三方 iframe，iframe 无法调用 invoke handler——这是安全特性
  不是缺陷（CONTRACT.md §6.1）。

## 8. fake 后端的协议职责

fake 后端**完整走过 bridge**（不是绕开它直呼 handler）：测试用
`DeliverFrame(json)` 模拟页面来帧（解码校验→按 id 关联回执）、
`CaptureEvalAt(i)` 按序捕获 native 发出的回执 Eval 文本并断言；
driver 面 `DeliverInvoke(cmd,payload)` 保持无帧直呼语义、不产生回执，
两者对照构成协议路径与直呼路径的区分测试。这样契约测试覆盖的就是
真实协议栈，而不是测试专用旁路。

落地注记（S2）：`__resolve/__reject/__emit` 的 JSON 参数一律以
"JSON 文本字符串"嵌入 Eval 脚本、JS 侧 `JSON.parse` 还原——与 §3.2
resolve 语义一致，reject/emit 同构；注入脚本内 transport 探测顺序为
WebKitGTK/WK 的 `window.webkit.messageHandlers.npw` 与 WebView2 的
`window.chrome.webview`，均投递 JSON 字符串化帧。
