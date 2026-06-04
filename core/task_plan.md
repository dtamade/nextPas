# Task Plan: http live epoll oversize trailer parity

## Goal

继续留在用户指定的主线：`malformed chunked request security`。

上一轮已经拿到代表性的 epoll live `400/501` parity，这一轮继续补 trailer-budget 这条状态类：

- 在 `test_http_security` 里补 Linux `epoll` backend 的 oversize trailer live proof
- 锁定 `431 or safe-close` 语义与“handler 不落地”的安全边界
- 先用 focused live 测试看 threaded / epoll 是否有分歧
- 只有真出现分歧时才做最小生产修复；否则本轮继续保持测试和文档批次

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 在 `test_http_security` 增加 Linux `epoll` live oversize trailer 用例：
  - oversize trailer -> `431 or safe-close`
  - handler response not written
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

- 把 `test_http_security` 的 epoll live parity 从 `400/501` 再往前补一格到 trailer-budget `431 / safe-close`
- 用最小 live 证据确认 oversize trailer 的 raw-wire security 语义在 epoll backend 上没有偏移
- 如果直接 GREEN，就把结论固定进文档，避免后续反复猜测 backend 是否有差异
- 下一刀不该继续扩同型 epoll status parity，而应回到尚未分类完的 malformed trailer/chunk truncation 边角
