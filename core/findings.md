# Findings: HTTP keep-alive tail policy bridge proof

## What This Batch Proved

- `chunked + trailer + partial follow-up request line` 不是天然 malformed。
- parser 现在有 bridge proof：
  首个 trailer-complete request 先完整结束；同一段半截 follow-up line 在后续字节补全后，可以合法解析成第二个请求。
- server 现在有 bridge proof：
  首个请求的 `200` 会先返回；随后只要客户端补全剩余字节，第二个请求也会继续正常完成。

## Why It Matters

- 这条 bridge proof 直接支撑了当前 transport truth：
  “first request completes, malformed tail becomes follow-up `400`”
- 因为 partial follow-up line 可能只是合法第二请求的分段到达，所以不能简单把这类 tail 提前收紧成更早显式拒绝。

## Batch Result

- 本轮没有发现新的 HTTP 实现缺陷。
- 两条新增 focused tests 首轮 direct GREEN。
- 本轮仍然是 coverage expansion / policy evidence，不是生产修复。
