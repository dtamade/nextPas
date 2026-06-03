# Findings: HTTP keep-alive tail policy decision

## Decision

- 当前 H1 keep-alive request-tail 行为不再视为“待决定”。
- 结论：把它冻结为 **intentional transport policy**。

## Policy

- 当前请求只要 framing 已完整，就先完整交付给 handler。
- transport 会保留未消费尾字节，交给下一次 parse。
- follow-up 只有在被证明 malformed，或在 EOF / half-close 下确定截断时，才返回 follow-up `400`。
- 不对 partial follow-up line / partial follow-up headers 做更早显式拒绝。

## Rationale

- fixed-length、plain chunked、trailer-complete chunked 三条路径都已经有：
  - garbage-tail proof
  - partial follow-up request-line proof
  - partial follow-up headers proof
  - valid pipelined next-request isolation / completion proof
- 另外 bridge proof 已证明：
  partial follow-up request line 在后续字节补全后可以成为合法第二请求。
- 因而“更早拒绝”会误伤合法分段到达的第二请求，不符合当前 H1 transport buffering 语义。
