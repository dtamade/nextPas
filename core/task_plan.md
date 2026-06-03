# Task Plan: HTTP router head/patch/options convenience methods

## Goal

补齐 router public convenience surface 的下一格：把 `Head/Patch/Options`
从缺失状态提升为 `IHttpRouter` / `THttpRouter` 的正式公开契约。

## Checklist

- [x] 确认共享 checkout 里无关 dirty/untracked 文件范围，本轮只处理 HTTP 相关路径。
- [x] 审计 `IHttpRouter`、`THttpRouter`、README 与 API coverage，确认这三个是当前真实 gap。
- [x] 先写 failing focused tests，证明 `Head/Patch/Options` 当前不可调用。
- [x] 做最小生产改动，把这三个 convenience methods 提升为公开契约。
- [x] 同步 README 与 API coverage。
- [x] 只跑 changed-surface 验证并确认 heaptrc 无泄漏。
- [ ] path-limited commit。
