# Task Plan: http live epoll malformed chunked security parity

## Goal

回到用户指定的主线：`malformed chunked request security`。

这一轮不再继续扩 synthetic timeout，而是直接做一刀 live backend parity：

- 在 `test_http_security` 里补 Linux `epoll` backend 的 raw-wire malformed chunked 代表性用例
- 优先覆盖 `400` / `501` 两类真实拒绝语义
- 先用 focused live 测试看是否出现 threaded / epoll 分歧
- 只有真出现分歧时才做最小生产修复；否则本轮保持测试和文档批次

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 在 `test_http_security` 增加 Linux `epoll` live parity 用例：
  - unsupported transfer-coding before chunked -> `501`
  - invalid chunk size -> `400`
  - missing chunk-data CRLF -> `400`
  - truncated trailer section CR EOF -> `400`
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

- 把 `test_http_security` 从“默认 threaded live security”往前补一格，锁住代表性 epoll live malformed chunked parity
- 用最小 live 证据确认这些 raw-wire security 语义在 epoll backend 上没有偏移
- 如果直接 GREEN，就把结论固定进文档，避免后续反复猜测 backend 是否有差异
- 下一刀如果还留在 live parity，应优先去补仍缺状态类代表的 `431` / safe-close trailer-budget truth，而不是无止境平铺所有已有 `400`
