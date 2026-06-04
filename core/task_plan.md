# Task Plan: http security oversize-trailer backpressure proof

## Goal

继续留在 `3/6 H1 正确性加固` 主线，回到你最初要求的 malformed
chunked raw-wire security 收口。这一刀只补一个独立状态分支：
`chunked oversize trailer -> 431` 的 live backpressure 安全证据。

同时，如果 focused gate 暴露旧测试断言和当前真实语义不一致，要在不改
生产代码的前提下同步校正测试 truth。

要求：

- 优先复用现有 direct-error backpressure helper
- 只补一个有独立价值的 `431` live case，不再机械铺 `400`
- 如果 tests 直接 GREEN，则本轮不改生产代码
- 只跑 `test_http_security` focused gate

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 `oversize trailer 431` live backpressure
- [x] 在 `test_http_security` 补 threaded / epoll focused tests
- [x] focused gate 暴露既有 `Request line too long` 断言与当前 `431` truth 不一致
- [x] 校正旧测试断言，不改生产代码
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_security test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_security/test_http_security.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不扩散到 benchmark / H2/H3 / server 基类重构

## Intended outcome

- `oversize trailer -> 431` 不再只停留在普通 live proof，而是接入
  standalone direct-error backpressure 证据链
- threaded / epoll 两条 live 路径都锁住：
  - 安全关闭
  - 不进入 handler
  - 不追加 synthetic `500`
  - wire 上至多一条原始 status line 前缀
- `Request line too long` 旧测试与当前 `MaxHeaderSize -> 431` truth 对齐
- 证据要求：
  - 新增 `431` backpressure case 直接 GREEN
  - focused security suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
