# Task Plan: HTTP security chunked raw-wire coverage batch 5

## Goal

继续沿 `HttpServer` correctness/security 路线收口 `test_http_security`，优先补当前
最高价值但仍缺 raw-wire proof 的 chunked 边界：

- chunked ingress `MaxBodySize` 必须在 terminal chunk 前直接 `413`
- oversize trailer 必须仍受 `MaxHeaderSize` 约束并返回 `431` 或安全关闭

## Checklist

- [x] 复核 `test_http_security` 与现有 `test_http_server` 的 chunked/security 缺口。
- [x] 先写 raw-wire RED：terminal chunk 前 `413` 与 oversize trailer `431`/安全关闭。
- [x] 跑 `test_http_security` 验证是否需要生产修复。
- [x] 确认本轮为 coverage-expansion，无需改生产代码。
- [x] 更新覆盖矩阵与控制文件，准备 path-limited 提交。
