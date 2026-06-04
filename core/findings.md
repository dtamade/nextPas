# Findings: HTTP server performance fast path

## Scope

本轮从性能追平目标出发，聚焦 HTTP/1.1 server keep-alive ingress hot path。目标不是做
大范围 runtime 重构，而是先用现有 fast parser 把普通 no-body HTTP/1.1 请求从 llhttp
adapter 分配路径中移出，并保留安全 fallback。

## Confirmed truths

### 1. Parser micro evidence

运行：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

结果显示 fast path 明显快于当前 llhttp adapter：

| workload | llhttp ns/op | fast ns/op |
| --- | ---: | ---: |
| simple GET | 1111.4 | 691.3 |
| 10 headers | 4978.4 | 3753.0 |
| POST 1KB body | 2167.2 | 1442.8 |
| pipeline 10 requests | 9810.0 | 6973.5 |

### 2. Subagent review

Peirce 子代理只读审计结论：

- 最高概率瓶颈不是 llhttp 状态机本体，而是 `TH1Parser` adapter 每个 URL/header/body
  span 的 managed string / TBytes 分配。
- `h1.fast` 已存在，但 server 此前没有使用。
- fast path 接入前必须先修非法同长度 method、Transfer-Encoding 大小写/任意 TE、
  `Content-Length` body 不完整、重复 `Content-Length` 等 fallback 缺口。

### 3. Local server benchmark evidence

本轮前的 50k/4 对照：

- nextPas: `completed=50000`, `ns/op=14736`, `req/s=67857`
- Rust std-only: `completed=50000`, `ns/op=9048`, `req/s=110518`

本轮 fast path 后的 50k/4 对照：

- nextPas: `completed=50000`, `ns/op=12397`, `req/s=80660`
- Go `net/http`: `completed=50000`, `ns/op=53709`, `req/s=18618`
- Rust std-only: `completed=50000`, `ns/op=10067`, `req/s=99324`

同机单次对照下，nextPas 从约 `67.9k req/s` 提升到约 `80.7k req/s`，与 Rust std-only
差距收敛到约 19%。该数字仍是本机单次证据，不是正式排名。

## Remaining gaps / risks

- fast path 当前只命中最保守普通请求；body / Expect / chunked / transfer-coding /
  connection-policy 仍回退 llhttp，后续需要逐步扩大而不是一次性放开。
- 下一个高收益点是减少 `TH1Parser` adapter 与 `THttpHeaders` 的分配：header capacity/count、
  headers-complete 时缓存 Host/Expect/Content-Length/keep-alive 判定。
- Rust 当前仍是 std-only comparator；正式性能路线后续仍需要 Hyper/Tokio 对照和 full-chain workload。
