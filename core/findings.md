# Findings: HTTP request transfer-coding contract hardening batch 8

## Root causes

- `llhttp` 负责 framing 合法性，但现有 adapter 之前没有把
  `Transfer-Encoding: gzip, chunked` 这类“framing 可判 chunked、但 coding
  我们并不会解码”的 request 识别成 unsupported transfer-coding。
- 结果是 parser 会把它误当成普通 chunked request 完成，server 也会把请求错误地交给 handler。
- 与此同时，server 之前把 parser error 一律映射成 `400`，无法把
  unsupported request transfer-coding 与 malformed framing 区分开。

## Fixed design truth

- `TH1Parser` 现在会在 request `Transfer-Encoding` 含有非 `chunked` coding 且
  最终仍以 `chunked` 收尾时，直接标记为
  `pekUnsupportedTransferCoding`，不再把该消息当成成功解析。
- `chunked` 非最终 coding 仍然维持 malformed framing 路径，继续属于 `400`。
- `TH1ServerConnectionState` 现在只把
  `pekUnsupportedTransferCoding` 映射为 `501 Not Implemented`；
  其余 parser error 仍保持 `400 Bad Request`。
- `http.base` 现在正式公开 `HTTP_STATUS_NOT_IMPLEMENTED = 501`，并锁定状态文本
  `Not Implemented`。

## Why this is the right fix

- 这把“会不会被当成可解码请求继续进入 handler”这个 correctness 问题收在 parser
  自身，而不是只在 server 层做脆弱的字符串拦截。
- server 层只负责把 parser 的错误分类映射到 HTTP status，职责边界更干净，
  未来别的 runtime/backend 复用同一 H1 parser 时也能继承这条契约。
- focused parser/security tests 直接证明：`gzip, chunked` 现在被拒绝且返回 `501`，
  `chunked, gzip` 继续返回 `400`，没有把 malformed framing 与 unsupported coding 混掉。
