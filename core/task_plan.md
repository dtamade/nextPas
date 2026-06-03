# Task Plan: HTTP body reader hot-path copy removal

## Goal

收掉 H1 parser/server/client 热路径里 `body string -> bytes -> stream`
这层多余复制，为后续 evented runtime 和更现代的 body streaming seam 打基础。

## Checklist

- [x] 确认共享 checkout 里无关 dirty/untracked 文件范围，本轮只处理 HTTP 相关路径。
- [x] 接上 RED：`test_http_h1parser` 中 `GetBodySize` / `NewBodyReader` 当前缺失。
- [x] 做最小生产改动：parser 直接持有 body bytes，并暴露 body size / body reader。
- [x] 让 H1 server/client 热路径直接消费 parser body reader，去掉额外复制。
- [x] 只跑 changed-surface 验证并确认 heaptrc 无泄漏。
- [x] path-limited commit。
