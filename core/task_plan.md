# Task Plan: keep-alive request-tail contract decision

## Goal

继续停留在 `3/6 H1 正确性加固` 主线，把 keep-alive request-tail
从“current transport truth”提升为明确 contract：当前请求 framing 完成即完成，
剩余 tail bytes 属于下一次 request parse；partial follow-up 可以补全，只有在
conclusive malformed 或 EOF-truncated 时才返回 follow-up `400`。

要求：

- 只动 HTTP 相关控制文件和覆盖文档；除非发现真实缺口，否则不新增测试。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不改生产代码。
- 不跑全量测试；只跑 `test_http_h1parser`、`test_http_server`、`test_http_security`
  三个 focused gate。

## Checklist

- [x] 阅读 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、
  `task_plan.md`、`findings.md`、`progress.md`。
- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 审计 parser / server / security 的 keep-alive request-tail 用例。
- [x] 确认 fixed-length / plain chunked / trailer-complete chunked 三类 framing 都有
  garbage / truncated / partial-complete / valid pipeline 证据。
- [x] 决定把当前 request-tail truth 固定为公开 contract。
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- 明确固定 keep-alive request-tail contract：
  - valid current request 完成后，tail bytes 不污染当前 request。
  - garbage / EOF-truncated follow-up 作为 follow-up `400`。
  - partial follow-up request-line / headers 可以继续补全为合法第二请求。
  - same-write / same-read valid pipeline 继续作为合法行为。
- 保持当前生产代码不变；本轮是契约固定与证据归档。
