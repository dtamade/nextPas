# Task Plan: http server expect-continue early 413

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀补
`Expect: 100-continue` 的一个更完整分支：

- declared `Content-Length` 在 headers 阶段已明确超过 `MaxBodySize`
  时，server 必须直接返回 final `413`，而不是误发 `100 Continue`

要求：

- default threaded 与 Linux `epoll` backend 都要拿到 focused live proof
- 先 RED，再做最小生产修复
- 不为了补能力而打破既有 `Expect` positive contract 与 keep-alive 契约

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 `Expect + declared oversize Content-Length`
- [x] 在 `test_http_server` 先加 focused RED tests
- [x] 最小生产修复：headers-stage 直接 short-circuit 到 final `413`
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_server test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `src/nextpas.core.http.impl.h1.pas`
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不扩散到 benchmark / H2/H3 / facade 话题

## Intended outcome

- 如果 `Content-Length` 已声明超限，server 在 headers 完整后立即返回
  final `413 Payload Too Large`
- 不会先发 `100 Continue`
- handler 不会在任何 body byte 到达前被调用
- threaded / epoll 两条路径都通过 focused live proof
- 证据要求：
  - wire 上直接出现 `HTTP/1.1 413 Payload Too Large`
  - wire 上不出现 `HTTP/1.1 100 Continue`
  - `heaptrc` 为 `0 unfreed memory blocks`
