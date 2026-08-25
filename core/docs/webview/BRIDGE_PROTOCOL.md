# nextpas.core.webview 注入桥协议 v1

**状态**: Design（S0）
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
  `__npwReady` promise 兜底（见 §4）。
- bridge script 文本作为常量存放于 `webview.bridge`（`NPW_BRIDGE_SCRIPT`），
  版本常量 `NPW_BRIDGE_VERSION = 1`。

### 2.1 JS 面（公开给前端代码）

```js
window.__npw = {
  version: 1,
  invoke(cmd, payload)      // payload 任意 JSON 值，缺省 null；返回 Promise<any>
  listen(event, callback)   // 订阅 native→js 事件，返回退订函数
  emit(event, payload)      // js→js 本地广播（不经 native）；可选便利
};
// 内部入口（native 调用，前端业务代码不得触碰）：
window.__npw.__resolve(id, resultJson)
window.__npw.__reject(id, errObj)     // errObj = {code, message}
window.__npw.__emit(event, payloadJson)
```

约定：

- `invoke` 的 payload 与结果都是**任意 JSON 值**（推荐对象）；序列化由 JS 侧
  `JSON.stringify`、native 侧 json owner 完成。
- `listen` 回调收到的 payload 已反序列化为 JS 对象。
- id 为正整数（u53 安全范围内），由 **native 侧分配**？——否：id 由 native 分配用于
  eval 回执；invoke 帧的 id 由 **JS 侧分配**并自增，native 不解释只回显。
  两个方向各自独立编号，互不相干。

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

非法帧（无法解析 / `v≠1` / 缺字段 / `cmd` 空）→ native 忽略并按 §5 计入坏帧
诊断计数；**不对坏帧回 reject**（此时可能连可靠回执通道都没有），
debug 构建下输出诊断日志。

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
bridge script 末尾派发 `__npwReady` resolve。此约定写入 starter 示例，
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

## 7. fake 后端的协议职责

fake 后端**完整走过 bridge**（不是绕开它直呼 handler）：测试用
`FakeDeliverFrame(json)` 模拟页面来帧、`FakeCaptureEval()` 捕获 native 发出的
Eval 文本并断言/手动兑现。这样契约测试覆盖的就是真实协议栈，而不是测试专用旁路。
