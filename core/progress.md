# Progress Log: keep-alive request-tail contract decision

## Session

- **Scope:** 审计 keep-alive request-tail 现有证据，并把 current-truth 提升为明确
  public contract。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side runtime truth`
  -> `keep-alive request-tail contract`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做
  path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../.claude/worktrees/*`
  - `../.worktrees/*`
  - `../compiler/tests/*`

## Completed work

- 已审计 `test_http_h1parser`、`test_http_server`、`test_http_security` 的
  request-tail 用例注册。
- 已确认 fixed-length / plain chunked / trailer-complete chunked 三类 framing 都有
  garbage tail、EOF-truncated follow-up、partial follow-up bridge 与 valid pipeline
  证据。
- 已将 keep-alive request-tail 从 current-truth 提升为明确 contract：
  当前 request framing 完成即完成，tail bytes 属于下一次 request parse。
- 本轮没有生产代码改动，也没有新增重复测试。

## Verification

- `git diff --check -- docs/http/API_COVERAGE.md task_plan.md findings.md progress.md`
  - exit code: `0`
- `make -C tests/nextpas.core.http/test_http_h1parser test`
  - `88/88 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server test`
  - `272/272 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_security test`
  - `242/242 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后，继续 request-side runtime truth 的剩余边界。
- 下一刀候选：回到 still-unclassified malformed / timeout / direct-error 小缺口，
  或开始为后续 server backend 模型设计整理更清晰的 execution contract。
