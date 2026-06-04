# Findings: request RemoteAddr direct proof

## Scope

本轮补齐 `IHttpRequest.RemoteAddr` 的 direct unit proof。此前 server live
已经证明 handler 能看到 remote addr，但 `THttpRequest.SetRemoteAddr` 到
`IHttpRequest.RemoteAddr` getter 的基础 contract 只在集成路径中间接覆盖。

## Confirmed truths

### 1. 当前实现已是正确 truth

`THttpRequest` 当前持有 `FRemoteAddr`，并通过：

- `SetRemoteAddr(const AAddr: string)` 写入
- `GetRemoteAddr: string` 读取
- `IHttpRequest.RemoteAddr` property 暴露给使用方

因此这轮不需要生产修复，只补 direct focused proof。

### 2. Focused proof

`test_http_message` 新增 `RemoteAddr default and set`：

- `NewGetRequest('/remote').RemoteAddr` 默认是空字符串。
- 通过 concrete `THttpRequest.SetRemoteAddr('127.0.0.1:54321')` 设置后，
  interface 侧 `IHttpRequest.RemoteAddr` 返回同一值。

这把 `docs/http/API_COVERAGE.md` 中 `IHttpRequest / THttpRequest` 的
RemoteAddr direct next-action 收口。

### 3. Scope boundary

本轮只证明 request object contract，不改变 server runtime 的 remote addr 注入逻辑。

## Remaining gaps / risks

- 如果未来要把 `THttpRequest` concrete type 也经 facade re-export，需要单独做 public
  surface 决策。
- 当前 `RemoteAddr` 仍是字符串 contract；若以后引入 structured peer addr，需要单独设计。
- 这轮不跑 server live gate，因为已有 server integration proof，本轮只补 direct object proof。
