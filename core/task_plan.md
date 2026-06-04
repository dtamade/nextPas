# Task Plan: http server expect-continue contract

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀补一条真正属于
`HttpServer` request-side protocol completeness 的缺口：

- `Expect: 100-continue`

要求：

- default threaded 与 Linux `epoll` backend 都要拿到 focused live proof
- 先 RED，再做最小生产修复
- 不为了补能力而打破既有 keep-alive / partial-follow-up bridge 契约

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 `Expect: 100-continue` contract
- [x] 在 `test_http_server` 先加 focused RED tests
- [x] 最小生产修复：threaded / poll-driven parse 路径补 interim `100 Continue`
- [x] 修复首版实现引入的 partial-follow-up regression
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_server test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `src/nextpas.core.http.impl.h1.pas`
  - `src/nextpas.core.http.impl.h1.parser.pas`
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不扩散到 benchmark / H2/H3 / facade 话题

## Intended outcome

- server 在 headers 完整且 body 仍待发送时返回单条 `100 Continue`
- handler 仍能读到完整 body
- threaded / epoll 两条路径都通过 focused live proof
- 证据要求：
  - wire 上先出现 `HTTP/1.1 100 Continue`
  - 后续最终响应仍是业务 `200`
  - `heaptrc` 为 `0 unfreed memory blocks`
