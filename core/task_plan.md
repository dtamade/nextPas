# Task Plan: http HEAD explicit Content-Length no-body contract batch

## Goal

继续把 `nextpas.core.http` 的 HEAD response contract 收紧到更可证的状态：

- 共享 GET/HEAD handler 即使显式设置 `Content-Length` 并调用 `Write`，wire body 仍必须为空
- client 读取 HEAD response 时必须保留 header、保持空 body、且不能因为 `Content-Length` 误等 body
- 本轮只处理 HTTP changed surface 与控制文件，不碰共享 checkout 里的无关脏文件

## Checklist

- [x] 审计 `docs/design-conventions.md`、HTTP 架构文档、`docs/http/API_COVERAGE.md` 与共享 `git status`，确认 runtime 设计已经固定在 `net.server`，本轮不重开选型。
- [x] 接续已有 RED tests，确认当前批次聚焦 `HEAD + explicit Content-Length + no body` 的 parser/client/server/writer 契约。
- [x] 最小实现：给 H1 response parser 增加 internal skip-body seam，并让 H1 client transport 按 request method 传入。
- [x] 跑 changed-surface focused tests：`test_http_h1parser`、`test_http_h1writer`、`test_http_server`、`test_http_client`，要求 heaptrc `0 unfreed memory blocks`。
- [x] 更新覆盖矩阵与控制文件，最后 path-limited 提交 HTTP 本轮文件。
