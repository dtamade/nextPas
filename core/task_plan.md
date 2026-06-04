# Task Plan: http trailer-complete partial-next-line raw-wire bridge proof

## Goal

继续留在 H1 correctness 主线，但本轮从纯 malformed status 收口，切到相邻的 keep-alive request-tail contract：

- 在 `test_http_security` 里补 chunked trailer-complete partial follow-up request-line bridge proof
- 锁定“首请求先完成，半截 follow-up 行后续补全后仍能成为合法第二请求”的 raw-wire truth
- 先补 default threaded，再补 Linux `epoll` live variant
- 只有真出现 threaded / epoll 分歧时才做最小生产修复；否则本轮继续保持测试和文档批次

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 在 `test_http_security` 增加 chunked trailer-complete partial follow-up request-line bridge proof：
  - first response -> `200 / echo:5`
  - completed follow-up request -> `200 / ok`
  - Linux `epoll` live variant 保持相同语义
- [x] 跑 focused `make -C tests/nextpas.core.http/test_http_security clean test`
- [x] 判断是否需要生产修复：本轮不需要
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_security/test_http_security.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不改生产代码
- 不跑全量测试

## Intended outcome

- 把 `test_http_security` 从 trailer-complete safe-handling 再往前补一格到 partial-next-line bridge truth
- 用最小 raw-wire live 证据确认这条 bridge contract 在 threaded / epoll backend 上都没有偏移
- 如果直接 GREEN，就把结论固定进文档，避免后续反复猜测 backend 是否有差异
- 下一刀优先看 trailer-complete same-write pipelining raw-wire proof，或继续回到尚未分类完的 malformed trailer/chunk truncation 边角
