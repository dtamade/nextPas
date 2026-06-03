# Progress Log: HTTP server runtime architecture freeze batch 4

## Session

- **Scope:** 把 HTTP/TCP server runtime 方案提升为正式架构文档，并对齐 `http/net`
  入口文档。
- **Status:** completed

## Notes

- 新增 `docs/net/ARCHITECTURE.md`，作为 reusable TCP server runtime foundation 的
  正式架构文档。
- `docs/net/README.md` 现在把 `nextpas.core.net.server` 明确为 server runtime seam。
- `docs/http/ARCHITECTURE.md` 现在把 `http.server` 明确为 facade，并把 runtime
  ownership 指向 `nextpas.core.net.server`。
- `docs/plans/2026-06-03-http-server-runtime-foundation.md` 现在保留为决策记录，
  但已指向 canonical architecture 文档。

## Fresh verification

- `prettier --write docs/net/ARCHITECTURE.md docs/net/README.md docs/http/ARCHITECTURE.md docs/plans/2026-06-03-http-server-runtime-foundation.md`
- `git diff --check -- docs/net/ARCHITECTURE.md docs/net/README.md docs/http/ARCHITECTURE.md docs/plans/2026-06-03-http-server-runtime-foundation.md`

- 本批只有文档与控制文件改动，没有生产代码或 public API 变更，因此未重复跑测试套件。
