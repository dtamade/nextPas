# Progress Log: h1 parser keep-alive partial follow-up headers bridge

## Session

- **Scope:** 把 parser 层 `Content-Length` / plain `chunked` / trailer-complete `chunked` 的 keep-alive partial follow-up headers 收成明确 bridge proof。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `keep-alive request-tail contract` -> `h1parser partial follow-up headers bridge`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../.claude/worktrees/*`
  - `../.worktrees/*`
  - `../compiler/tests/*`

## Completed work

- [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  上一刀已经把 security 层的同类 headers bridge 空档补齐，本轮不再重复扩大 security parity。
- [tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr)
  新增三条 focused proofs：
  - `Content-Length` partial follow-up headers can complete later
  - plain `chunked` partial follow-up headers can complete later
  - trailer-complete `chunked` partial follow-up headers can complete later
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已把 `H1 parser` 的 partial follow-up headers 从“focused 覆盖”提升成明确 bridge proof 口径。
- 本轮没有生产代码变更；focused gate 直接 GREEN，说明这是 current truth 收口，而不是修复。

## Verification

- `make -C tests/nextpas.core.http/test_http_h1parser test`
  - `88/88 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀仍应优先真实协议缺口，不要回到大面积 parity 平铺。
- 最自然的后续是继续补：
  - 转去仍未分类完的 malformed/runtime 邻接缺口
  - 或重新审视 request-tail contract 还有没有更高价值的非平铺空档
