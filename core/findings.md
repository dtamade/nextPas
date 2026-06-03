# Findings: HTTP server correctness hardening batch 3

## Root causes

- `THttpServer.Create` 之前没有像 TCP foundation 一样对 public handler 做 fail-fast
  校验，`nil` handler 会把错误拖到更深层的 runtime 路径。
- `TH1ServerConnectionState.Run` 之前只在 parser 完整结束后才检查
  `MaxBodySize`，意味着 chunked 请求可以先越过阈值、继续占用 worker 并缓冲，
  最后才被 `413` 拒绝。
- `IHttpHijacker` 的“接管后 server 不再插手”语义虽然代码里已有专门异常分支，
  但之前缺少 direct regression proof。

## Fixed design truth

- `THttpServer.Create` / `NewHttpServer` 现在对 `nil` handler 直接抛
  `EArgumentError`，和 `nextpas.core.net.server` foundation 保持一致。
- `TH1` server transport 现在在 parser 读循环中持续检查 `GetBodySize`；
  一旦 chunked/body ingress 越过 `MaxBodySize`，立即写出 `413` 并终止当前请求，
  不再等待 terminal chunk。
- hijack 后如果 handler 再抛异常，server 不会追加 `500`，也不会回收已经移交给
  handler owner 的连接。
- `net.server.threaded` 现在也有 focused proof 证明 `0.0.0.0` 与空地址监听下，
  `Shutdown` 都能稳定 unblock `Accept()`.

## Why this is the right fix

- `nil` handler fail-fast 让 facade contract 与 foundation contract 对齐，避免把 API
  误用降级成运行期深层崩溃。
- `MaxBodySize` 越线即拒绝更符合真实防御语义：限制的是正在接收的 body，而不是
  “完整解析完以后才回头宣告超限”。
- hijack 异常路径 proof 把 ownership contract 从“通常能用”提升为“异常路径也不
  会被 server 重新夺回”，这对 WebSocket / raw socket upgrade 很关键。
