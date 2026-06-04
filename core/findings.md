# Findings: non-101 informational response contract

## Scope

本轮补齐 H1 response-side informational response contract。目标是接近 Go
`net/http` 的主流语义：非 `101` 的 `1xx` 可以作为 interim response 先写出，
但不提交 final response；handler 后续仍可发送 final status 和 body。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_h1writer` 新增
`non-101 informational response allows later final response` 后，首次 focused
gate 失败：

- `28/29 passed, 1 failed`
- failure: `response status must not include a body`
- heaptrc 有 6 个 unfreed blocks，原因是 RED 用例抛异常后提前中断。

这证明旧状态机会把 `103` 当成最终 no-body response 提交，后续 final `200`
与 body 被阻断。

### 2. 最小修复

`TH1ResponseWriter.WriteHeader` 现在对非 `101` 的 `1xx` 走 informational path：

- 写出 status line / 当前 headers / CRLF。
- 不设置 `FHeadersSent`。
- 不设置 `FNoBodyAllowed`。
- 不创建 chunked writer。
- 保留原 final status，等待后续 final `WriteHeader` 或 body write。

`101 Switching Protocols` 不走该 path，仍然是 committed no-body / upgrade-like
边界。

### 3. Public API 补齐

新增 public status carrier：

- `HTTP_STATUS_EARLY_HINTS = 103`
- `HttpStatusText(103) = 'Early Hints'`
- `nextpas.core.http` facade re-export

`test_http_contract` 已直接锁住 facade 常量和 status text。

### 4. Server live proof

`test_http_server` 新增 threaded / Linux `epoll` live proof：

- handler 写 `103 Early Hints`
- 随后写 final `200 OK`
- final response 保持 chunked body framing
- wire order 为 `103 -> 200 -> body`

## Remaining gaps / risks

- 本轮没有扩展更多 1xx 常量；只补当前最有价值的 `103 Early Hints`。
- informational response 会发送当前 header map；这与现有 writer 设计一致。
- 后续若要支持更复杂的 header 生命周期（例如 interim-only headers），需要单独设计，
  不应混进本轮。
