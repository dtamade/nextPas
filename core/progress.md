# Progress Log: expect interim-100 truncated trailer separator EOF proof

## Session

- **Scope:** 承接上一刀的 `Expect: 100-continue` trailer field-name EOF
  after-interim coverage，继续补齐 `Expect + Transfer-Encoding: chunked`
  在 interim `100` 已发出后收到 partial trailer separator 并在 EOF 截断时的
  after-interim truth，用 `test_http_security` + `test_http_server`
  双层 focused proof 收口。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side runtime truth` -> `Expect after interim 100 truncated trailer separator EOF`

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

- [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  复用了上一刀的 `shutdown-after-body` after-interim helper，
  新增 2 条 raw-wire focused proofs：
  - threaded `Expect chunked truncated trailer separator EOF rejects after interim 100`
  - epoll `Expect chunked truncated trailer separator EOF rejects after interim 100`
- [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  对称新增 2 条 focused public-contract proofs：
  - threaded `Expect: chunked truncated trailer separator EOF rejects after interim response`
  - epoll `Expect: chunked truncated trailer separator EOF rejects after interim response`
- 这 4 条 tests 直接锁住：
  - interim `100` 先发出
  - partial trailer separator + peer write-half-close 后返回 final `400 Bad Request`
  - 不重复 `100`
  - 不误回 `200`
  - handler 不进入
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步把 `Expect after interim 100 + truncated trailer separator EOF -> final 400`
  纳入 `test_http_server` + `test_http_security` 双层证据。
- 本轮没有生产代码变更；focused gate 直接 GREEN，说明当前生产代码已经自然满足这条契约，这轮仍是 coverage-expansion。

## Verification

- `make -C tests/nextpas.core.http/test_http_security test`
  - `220/220 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server test`
  - `250/250 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀继续优先 request-side runtime / malformed 的真实小缺口。
- 更自然的后续候选：
  - `Expect + chunked + after interim 100 + truncated trailer field line EOF -> final 400`
  - 或 `Expect + chunked + after interim 100 + truncated trailer field CR EOF -> final 400`
- 继续保持单刀推进，不宽铺同型 parity。
