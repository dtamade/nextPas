# Task Plan: http direct-error live safe-close proof

## Goal

继续留在 `3/6 H1 正确性加固` 主线，挑一个比机械 malformed parity 更值的 runtime truth 缺口：

- 不再复制 request-tail / truncation 同型用例
- 把 `standalone direct-error` 的 real-socket 外部语义补到 security
- 聚焦 malformed `400` 与 unsupported transfer-coding `501` 两条 representative path
- 锁定 backpressure 尝试下的 peer-visible contract：单一原始 status-line 前缀或安全关闭，绝不追加 synthetic `500`

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 审核 server/security 当前矩阵，确认 direct-error live safe-close 是更值的缺口
- [x] 在 `test_http_security` 里补最小 socket tuning seam 与 representative live tests
- [x] 跑 focused `make -C tests/nextpas.core.http/test_http_security test`
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

- 在 threaded / epoll 两条 live path 上补齐 representative truth：
  - malformed request direct `400`
  - unsupported transfer-coding direct `501`
- 对外锁定 contract：
  - backpressure 尝试下最终安全关闭
  - wire 上至多一个原始 status line / prefix
  - 不会出现 synthetic `500`
