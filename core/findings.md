# Findings: HTTP security chunked raw-wire coverage batch 5

## Root causes

- `test_http_server` 已经证明了 chunked `MaxBodySize` 的 live limit 语义，以及
  oversize trailer 的 `MaxHeaderSize` 约束；但 `test_http_security` 还缺这两条
  raw-wire safety proof。
- 没有这两条 security-suite 证据时，`HttpServer` 对恶意分段输入的防御语义虽然真实存在，
  但缺少“攻击者视角”下的独立证据层。

## Fixed design truth

- `test_http_security` 现在直接证明：chunked body 一旦跨过 `MaxBodySize`，即使
  terminal chunk 还没到，server 也会先返回 `413`，不会等请求“自然结束”。
- `test_http_security` 现在也直接证明：oversize trailer 仍然走
  `MaxHeaderSize` 防线，结果是 `431` 或安全关闭，而不是落到业务 handler。
- 这两条 proof 这轮直接变绿，说明当前生产代码 truth 已经满足目标，本轮不需要生产修复。

## Why this is the right fix

- security suite 应该验证“攻击流量如何被拒绝”，不只复用普通 server suite 的正确性结论。
- 把 live `413` 与 trailer `431` 补到 raw-wire 层后，chunked ingress 的防御边界更完整。
- 这轮不动生产代码，保持批次聚焦，也符合你要求的 coverage-expansion 节奏。
