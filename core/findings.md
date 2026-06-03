# Findings: HTTP server runtime foundation implementation batch 2

## Root cause

- `TTcpThreadedServer` 之前虽然已经支持 handler 接管连接，但仍把
  `AHandler.ServeConn` 直接跑在 detached worker / inline fallback 路径里。
- 一旦 generic `ITcpServerHandler` 抛异常，detached worker 会把异常抛到线程外，
  inline fallback 还会直接逃出 `ListenAndServe`，从而打穿 accept loop。
- 这在 HTTP H1 默认路径里不明显，因为 H1 transport 自己会兜 handler 异常；但
  foundation 本身不能把这种稳定性建立在某个具体 protocol transport 的内部防护上。

## Fixed design truth

- `threaded` runtime 现在通过共享的连接执行路径统一调用 handler。
- 单连接 handler 异常会被 runtime 吞掉，并回落到 `tscoServer` 语义，由 server
  负责关闭该连接。
- 单个连接失败不再影响后续 accept / dispatch；foundation 自身对 generic
  `ITcpServerHandler` 已具备最小稳定性。
- `IHttpServerTransport.ServeConn` 的 ownership 返回类型与常量现在也经由
  `nextpas.core.http.intf` / `nextpas.core.http` 直接 re-export，transport
  implementer 不必额外依赖 `nextpas.core.net.server`。

## Why this is the right fix

- 这是 runtime 层应承担的容错边界，不应依赖上层协议 transport 恰好自己兜底。
- 这样 future `net.server.epoll/kqueue/iocp` 也有明确语义参考：连接级失败只终止
  当前连接，不终止整个 listener runtime。
- facade 自包含后，`IHttpServerTransport` 作为 HTTP public contract 更完整，
  实现者只看 HTTP 模块就能拿到所需类型事实。
