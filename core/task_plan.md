# Task Plan: HTTP server runtime foundation planning

## Goal

把 HTTP server runtime 的方向冻结到仓库文档里，明确后续从
`nextpas.core.net.server` 通用基座推进，而不是继续让 `http.server`
私有化线程/事件模型。

## Checklist

- [x] 确认共享 checkout 里无关 dirty/untracked 文件范围，本轮只处理 HTTP 相关路径。
- [x] 研究 Go / Tokio-Hyper / libuv 的主流 server/runtime 范式并做选型。
- [x] 结合当前 `http/net/io` 源码现状做可行性判断。
- [x] 把固定架构方案与分阶段计划落到仓库文档。
- [x] path-limited commit。
