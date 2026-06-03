# Findings: http HEAD explicit Content-Length no-body contract batch

## Current state

- 当前 `HEAD` 是 `e43d99b5` `fix(process): harden path resolution contract`；共享工作树仍然是脏的，
  但本轮 HTTP 未提交改动只落在 `tests/nextpas.core.http/*` 相关文件以及后续最小生产修复上。
- `docs/net/ARCHITECTURE.md` 与
  `docs/plans/2026-06-03-http-server-runtime-foundation.md` 已经把 server runtime
  的长期方向固定到 `nextpas.core.net.server` foundation，本轮不再重开线程 / evented / IOCP 选型。
- `2e95cf64` 已经修掉 server-side `HEAD` raw-wire body 泄漏问题，但当前批次新增的 focused tests
  进一步暴露出 client / response parser 的契约缺口。

## Root causes

- 现有 `TH1ResponseWriter` 已经能在 suppress-body 路径下：
  - 不注入 `Transfer-Encoding: chunked`
  - 不写 chunk trailer
  - 不发 body bytes
- 但 `TH1ClientTransport.ReadResponse` 仍然无条件使用普通 `NewH1ResponseParser`。
- 对 `HEAD 200 OK` 且显式带 `Content-Length: 5`、实际没有 body bytes 的响应，client-side parser
  仍会按普通 fixed-length response 理解，从而要求读取 5 个 body 字节；这会让 focused contract proof
  卡在 parser/client 层，而不是 server/writer 层。

## Design direction for this batch

- 不扩 public HTTP surface，只在 H1 internal seam 补齐 skip-body 语义。
- 利用 llhttp 现成的 `HTTP_HEAD` / `F_SKIPBODY` seam，让 response parser 在 headers 完成后就按
  no-body response 结束。
- `TH1ClientTransport` 按原始 request method 把 `hmHead` 传入 response parser；
  server / writer 保持既有 suppress-body 设计，不做额外分支扩张。

## Fixed design truth

- `NewH1ResponseParser` 现在支持 internal `ASkipBody` overload；`HEAD` response 可在显式
  `Content-Length` 下直接完成，body 仍为空。
- parser `Reset` 会重新应用 skip-body hint，wrapper 层 `ResponseEndsAtEof` /
  `ShouldKeepAlive` 也与这条 no-body 语义保持一致。
- `TH1ClientTransport.ReadResponse` 现在会按 request method 传入 `hmHead`，
  因而保留 `Content-Length` header、返回空 body，并继续维持 keep-alive 可复用语义。
- 本轮没有 public API 变更；收口的是 H1 internal contract 与对应 focused proof。
