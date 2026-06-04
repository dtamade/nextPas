# Progress Log: http live epoll oversize trailer parity

## Session

- **Scope:** 给 `test_http_security` 补 Linux `epoll` 下 oversize trailer 的 live `431 / safe-close` parity proof。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `raw-wire malformed chunked request security` -> `epoll live trailer-budget parity`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr:1291)
  把 oversize trailer 测试提成了一个窄 helper，复用到不同 backend。
- [test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr:1334)
  现在新增了 Linux `epoll` backend 的 oversize trailer live parity proof：
  - oversize trailer -> `431 or safe-close`
  - handler response not written
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md:18)
  已同步 epoll live trailer-budget parity 结论，并把下一步路线重新收敛到更高信息增益的 malformed trailer/chunk 边角。

## Verification

- `make -C tests/nextpas.core.http/test_http_security clean test`
  - `67/67 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀优先回到仍缺分类的 malformed trailer/chunk truncation 相邻子类
- 除非 live socket 再暴露 backend 分歧，否则不再继续机械复制同型 epoll status parity
