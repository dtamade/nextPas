# Task Plan: http h1 poll-driven phase2 step5

## Goal

把 `nextpas.core.http` 的 stalled-peer / write-timeout 契约再收紧一层：

- 补 live backpressure close-observation characterization
- 证明 malformed follow-up 在 timed stalled drain 下也不会漏出 follow-up `400`
- 继续避免把 `WriteTimeout` 冻结成严格 close-time SLA

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `nextpas.core.http` 相关文件
- [x] 审阅现有 real-socket backpressure proof、H1 poll timed drain state、epoll wake 模型
- [x] 先补 RED：
  - `test_http_server` 新增 malformed follow-up backpressure characterization
  - 直接锁定 wire 上没有 follow-up `400`
  - 直接锁定 wire 上只有首个 response status line
- [x] GREEN 判定：
  - 当前实现无需生产修正
  - 这条更细的 live truth 已经成立
- [x] 跑 focused `test_http_server` 与 heaptrc
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`

## Scope

- 这轮只做 stalled-peer / write-timeout characterization。
- 不改 `nextpas.core.http` public API。
- 不做 benchmark。
- 不跑全量测试。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- 当前 live contract 会更精确：
  - backpressure timeout 下连接仍会在放宽观察窗口内关闭
  - 不会继续消费 later pipelined request
  - malformed follow-up 也不会额外漏出 `400`
  - wire 上仍只有首个 response status line
- 同时继续保留：
  - 不冻结严格 `WriteTimeout` close-time SLA
  - 不冻结 handler-return timing
