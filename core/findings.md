# Findings: http server options demo smoke

## Scope

- 本轮留在 `nextpas.core.http`。
- 目标不是生产修复，而是给 `http_server_options_demo` 建立 focused runnable
  smoke 证据。

## Confirmed truths

### 1. 当前 malformed chunk / raw-wire security 证据已经足够厚

- parser / server / security 三层对 chunked ingress 的 malformed/truncated
  case 已经有大量 focused proof。
- 再继续堆相邻子类，边际收益已经明显低于补 example smoke。

### 2. `http_server_options_demo` 的高价值契约是“示例真能跑”

- 这个 example 公开展示的不只是 API surface，还包括：
  - `THttpServerOptions.Backend`
  - `WriteTimeout`
  - `MaxHeaderSize`
  - `MaxBodySize`
  - `/health`
  - `/hello/:name`
  - `/echo`
- 如果没有外部进程级 smoke，它仍然只算“编译示例”，不算运行契约。

### 3. 最合适的模式是“外部进程 + 客户端打点”，不是内嵌 server

- `test_config_examples` 适合一次性退出的 example。
- `http_server_options_demo` 是常驻 server，更合适的模式是：
  - 测试内先 `make build`
  - 直接启动 example binary
  - 等待 ready marker
  - 用 `IHttpClient` 打 `/health`、`/hello/world`、`POST /echo`
  - 再验证 oversize body 被 `413` 拒绝

### 4. 本轮不需要生产修复

- 新增 smoke 一次通过，说明当前 example/HTTP 生产路径已经满足这批契约。
- 本轮只新增测试与控制面证据。

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_examples clean test`
  - `2/2 passed`
  - heaptrc: `0 unfreed memory blocks`
- 其中 smoke 已覆盖：
  - example build 成功
  - ready startup marker
  - `/health` 返回 options 文本
  - `/hello/world` 返回 path-param 示例文本
  - `/echo` 返回 body/byte-count
  - oversize body 返回 `413`

## Remaining gaps / risks

- 当前 smoke 只锁 `threaded` backend，没有额外跑 `epoll` CLI 参数分支。
- 这仍然是示例级别的 focused proof，不替代 `test_http_server` 的协议边界覆盖。
- 如果后续 example 再扩公开演示面，应优先在这个 smoke 上增量补证据，而不是把断言散回大而全的集成测试。
