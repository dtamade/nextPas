# Task Plan: http h1 poll-driven phase2 step4

## Goal

把 `nextpas.core.http` 的 H1 poll-driven runtime 再推进一格：

- 落地 bounded outbound queue / ordered completion 的最小语义
- 允许 untimed poll path 在首个响应未 drain 前先完成一个 buffered follow-up request
- 同时守住既有 timed/backpressure safety contract

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `nextpas.core.http` 相关文件
- [x] 先补 RED：
  - `test_http_server` 新增 raw state-machine proof
  - 证明 active response drain 期间可以有界排队第二个 response
  - 证明第三个 request 必须等 queue slot 释放后才能继续
- [x] GREEN：
  - worker result 改成 completion-applied handoff，不再直接改 reactor-owned response state
  - H1 poll path 落地 active drain + 1 queued response
  - follow-up `400` / `413` / `431` 在 response pending 时也按 wire 顺序排队
  - `WriteTimeout > 0` 的 timed/backpressure path 继续禁止 later pipelined request consumption
- [x] 跑 focused `test_http_server` 与 heaptrc
- [x] 更新 `docs/http/ARCHITECTURE.md`、`docs/http/API_COVERAGE.md`

## Scope

- 这轮只做 H1 poll-driven phase2 的第四格。
- 不改 `nextpas.core.http` public API。
- 不做 benchmark。
- 不跑全量测试。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- untimed H1 poll path 现在具备有界有序的 response queue：
  - `active drain + 1 queued response`
  - 一个 buffered follow-up request 可以在首个响应未 drain 前先完成
  - 第三个 request 只有在 queue slot 释放后才能继续
- follow-up parse error 不会越过前一个合法响应直接写回 socket。
- timed drain / write-timeout contract 继续保持 correctness-first：
  stalled peer 不会导致 later pipelined request 被继续消费。
