# Task Plan: HTTP keep-alive tail policy decision

## Goal

把 keep-alive request-tail 从“待决定 gap”收口成明确的 H1 transport policy：

- 当前请求一旦 framing 完整，就先完整交付；
- 未消费尾字节保留给下一次 parse；
- follow-up 只有在被证明 malformed 或 EOF-truncated 后才返回 follow-up `400`；
- partial follow-up line 可能只是合法第二请求的分段到达，不能过早拒绝。

## Checklist

- [x] 确认只处理 HTTP 目标路径。
- [x] 根据既有 garbage-tail / partial-follow-up / valid pipelined / bridge proof 收口 policy。
- [x] 最小更新 `API_COVERAGE.md` 与控制文件。
- [ ] path-limited commit。

## Result

- keep-alive request-tail policy 已在控制面明确冻结为 intentional transport behavior。
