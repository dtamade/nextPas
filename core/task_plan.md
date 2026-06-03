# Task Plan: HTTP router public convenience methods

## Goal

把 router 现有的 `Get/Post/Put/Delete` convenience methods 从 concrete-only
提升到 `IHttpRouter` 公共契约，让 facade / examples / README 对齐真实可用路径。

## Checklist

- [x] 确认共享 checkout 里无关 dirty/untracked 文件范围，本轮只处理 HTTP 相关路径。
- [x] 盘点 `IHttpRouter`、`THttpRouter`、contract/router tests 与当前文档表述。
- [x] 先写 failing contract proof，证明 `IHttpRouter.Get/Post/Put/Delete` 当前不可调用。
- [x] 做最小生产改动，把 convenience methods 提升到 `IHttpRouter`。
- [x] 同步 example / README / API coverage 文档。
- [x] 只跑 changed-surface 验证并确认 heaptrc 无泄漏。
- [ ] path-limited commit。
