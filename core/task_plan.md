# Task Plan: HTTP server runtime architecture freeze batch 4

## Goal

把已经讨论过的 HTTP / TCP server runtime 方向固定为正式文档，避免未来继续围绕
“HTTP server 是否只能线程驱动”反复讨论，并为后续 `epoll` / `kqueue` / `IOCP`
backend 演进建立权威入口。

- 新增 `docs/net/ARCHITECTURE.md` 作为 server runtime foundation 的正式架构文档
- 让 `docs/net/README.md`、`docs/http/ARCHITECTURE.md` 对齐新的 canonical design
- 给原始 plan 文档加 canonical 指针，避免双份真相漂移

## Checklist

- [x] 复核现有 `net.server` / `http.server` / H1 connection-state 的源码边界。
- [x] 把 mixed model 固化为正式文档：public Go-like，internal Tokio/Hyper-like，
  backend strategy libuv-like。
- [x] 明确 `nextpas.core.net.server` 是 runtime foundation owner，HTTP 只负责协议层。
- [x] 同步 `docs/net` 与 `docs/http` 的文档入口，避免继续把 runtime 方案放在临时
  `docs/plans` 里。
- [x] 跑文档 diff hygiene 与格式化，确认没有额外脏改动混入。
