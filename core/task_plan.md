# Task Plan: HTTP runnable examples and README truth pass

## Goal

为 `nextpas.core.http` 补一批可运行的 examples，并把 `docs/http/README.md`
改成对着真实公开接口说话，避免继续停留在片段式示例与文档幻觉。

## Checklist

- [x] 确认共享 checkout 里无关 dirty/untracked 文件范围，本轮只处理 HTTP 相关路径。
- [x] 复读设计规范、HTTP 控制文件与 coverage 现状。
- [x] 盘点 facade / base / router / client / server 真实公开接口边界。
- [x] 新增 `http_hello_server` example。
- [x] 新增 `http_get_client` example。
- [x] 更新 `docs/http/README.md`，指向可运行 example 并修正文档契约。
- [x] 只做 changed-surface 验证：example 编译 + 最小端到端 smoke。
- [ ] path-limited commit。
