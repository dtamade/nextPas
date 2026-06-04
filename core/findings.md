# Findings: router CONNECT / TRACE convenience surface

## Scope

本轮补齐 `IHttpRouter` / `THttpRouter` 的 public convenience surface：
既然 `THttpMethod` 已公开 `hmConnect` / `hmTrace`，router interface 也应提供
对应的 `Connect` / `Trace` 方法，而不是让用户回退到 generic `Handle`。

## Confirmed truths

### 1. RED 证明了接口缺口

`test_http_contract` 在 `IHttpRouter` interface 上调用 `Connect` / `Trace`
后首次 focused gate 编译失败：

- `Identifier idents no member "Connect"`
- `Identifier idents no member "Trace"`

这证明缺口在 public interface surface，而不是测试拼写或实现细节。

### 2. 最小修复

`IHttpRouter` 和 `THttpRouter` 现在都新增：

- `Connect(const APattern: string; const AHandler: THttpHandlerFunc)`
- `Trace(const APattern: string; const AHandler: THttpHandlerFunc)`

两者只转发到 `Handle(hmConnect, ...)` / `Handle(hmTrace, ...)`，没有改变
router 匹配算法、middleware、405 或 server runtime 语义。

### 3. Focused proof

`test_http_contract` 证明：

- 经由 `nextpas.core.http` facade 获得的 `IHttpRouter` interface 可以直接调用
  `Connect` / `Trace`。
- 两个方法能注册并 dispatch 到对应 handler。

`test_http_router` 证明：

- concrete `THttpRouter.Connect` / `Trace` 注册后，可通过 `FindRoute` 在
  `hmConnect` / `hmTrace` 树上找到并执行 handler。

## Remaining gaps / risks

- `CONNECT` 的 tunnel / proxy 语义不是本轮范围；本轮只补 route registration
  surface。
- `TRACE` 是否在生产应用中启用由用户 handler 决定；框架只提供 method dispatch。
- 这轮不跑 server live gate，因为 router dispatch 已在 unit/contract 层直接证明，
  server runtime 不受影响。
