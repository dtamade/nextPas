# Task Plan: HTTP request transfer-coding contract hardening batch 8

## Goal

继续收紧 `HttpServer` / H1 parser 的 request framing contract，补齐
`Transfer-Encoding` request-side 支持语义，避免 unsupported coding 被误当成
可解码 chunked request 接受，并用 focused proof 锁住：

- `Transfer-Encoding: gzip, chunked` 不再被误接受
- unsupported request transfer-coding -> explicit `501`
- `chunked` 非最终 coding 继续保持 explicit `400`

## Checklist

- [x] 审计 H1 parser / server 对 request `Transfer-Encoding` 的当前实现与测试覆盖。
- [x] 先写 RED，确认 unsupported request transfer-coding 仍会被误接受或误分类。
- [x] 做最小实现：parser 补 unsupported transfer-coding 判定，server 补 `501/400` 分流。
- [x] 跑 changed-surface focused tests 与 heaptrc。
- [x] 更新覆盖矩阵与控制文件。
