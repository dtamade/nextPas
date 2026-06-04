# Findings: after-interim trailer EOF chain closure audit

## Scope

本轮不新增测试，先审计上一阶段 `Expect: 100-continue` + chunked trailer EOF
after-interim proof 是否已经形成完整邻接链。若已经闭合，就停止同型补证，
把下一刀切到 keep-alive request-tail contract。

## Confirmed truths

### 1. after-interim trailer EOF 邻接链已经闭合

`test_http_security` 与 `test_http_server` 当前都已在 threaded / Linux `epoll`
两条路径注册 after-interim proof，覆盖：

- malformed trailer field
- truncated trailer field-name EOF
- truncated trailer separator EOF
- truncated trailer empty-value CR EOF
- truncated trailer empty-value EOF
- truncated trailer empty-value section CR EOF
- truncated trailer whitespace CR EOF
- truncated trailer whitespace EOF
- truncated trailer whitespace section EOF
- truncated trailer whitespace section CR EOF
- truncated trailer field line EOF
- truncated trailer field CR EOF
- truncated trailer section CR EOF
- truncated trailer section EOF
- oversize trailer -> `431`

这些用例共同锁住：

- `HTTP/1.1 100 Continue` 已经先发出。
- malformed / EOF-truncated trailer 后返回 final `400 Bad Request`，oversize trailer
  返回 final `431 Request Header Fields Too Large`。
- final response 不重复 interim `100`。
- 不误回 final `200`。
- handler 不进入。

### 2. 没有必要继续加同型 trailer EOF 测试

parser / standalone server / security / after-interim server 四层现有覆盖已经把 trailer
EOF grammar 的相邻截断形态串起来。继续追加同型 case 只会增加测试维护成本，
不会提高公开契约可信度。

### 3. 下一条主线应转向 keep-alive request-tail contract

当前文档和测试已经记录的 transport truth 是：

- fixed-length / plain chunked / trailer-complete chunked 请求在当前 request framing
  完成时即完成。
- unread tail bytes 会留给下一次 request parse。
- partial follow-up request-line / headers 可以继续补全为合法第二请求。
- conclusively malformed 或 EOF-truncated follow-up request 会作为 follow-up `400`。

下一批应先判断这些行为哪些需要固定为公开 contract，哪些只是当前 transport
truth；只对缺口补 focused tests。

## Remaining gaps / risks

- 本轮是路线图收口，不是行为修改。
- 没有生产代码或测试代码变更，因此不跑 focused 单元测试；后续一旦改 API / 行为 /
  test surface，仍必须跑对应 focused gate 和 heaptrc。
- keep-alive request-tail contract 需要避免误收紧：如果把“可补全的 partial
  follow-up”过早定义成错误，可能破坏 pipelining / TCP 分段下的合法行为。
