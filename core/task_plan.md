# Task Plan: non-101 informational response contract

## Goal

继续停留在 `3/6 H1 正确性加固` 主线，补齐 H1 response-side informational
response contract：非 `101 Switching Protocols` 的 `1xx` 响应（以
`103 Early Hints` 为代表）应立即写到 wire，但不能提交 final response，
后续仍可发送 final `200 OK` 与 body。

要求：

- 先 RED，再做最小生产修复。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_h1writer`、`test_http_server`、`test_http_contract`
  三个 focused gate。

## Checklist

- [x] 阅读 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、
  `task_plan.md`、`findings.md`、`progress.md`。
- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 审计 `TH1ResponseWriter.WriteHeader` 当前对 `1xx` 的提交语义。
- [x] 在 `test_http_h1writer` 写 RED：`103 Early Hints` 后仍可 final `200` + body。
- [x] 最小修复 writer 状态机：非 `101` informational 不设置 final committed。
- [x] 新增 `HTTP_STATUS_EARLY_HINTS` public constant / status text / facade re-export。
- [x] 补 `test_http_server` threaded / epoll live proof。
- [x] 补 `test_http_contract` facade status constant proof。
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`
- `src/nextpas.core.http.base.pas`
- `src/nextpas.core.http.pas`
- `src/nextpas.core.http.impl.h1.writer.pas`
- `tests/nextpas.core.http/test_http_h1writer/test_http_h1writer.lpr`
- `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
- `tests/nextpas.core.http/test_http_contract/test_http_contract.lpr`

## Intended outcome

- 明确固定 non-`101` informational response contract：
  - `103 Early Hints` 立即写出。
  - 后续 final `200 OK` 仍会写出。
  - final response 仍正常获得 chunked body framing。
  - `101 Switching Protocols` 仍保持 no-body / upgrade 边界。
