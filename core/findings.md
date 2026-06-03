# Findings: HTTP no-body response contract hardening batch 9

## Root causes

- `TH1ResponseWriter.WriteHeader` 之前的默认逻辑只看
  `Content-Length` / `Transfer-Encoding` 是否预设，没有区分
  `1xx` / `204` / `304` 这类本就不允许带 body 的响应状态。
- 结果是 `204` / `304` 之前会被错误地自动注入
  `Transfer-Encoding: chunked`，`Flush` 也会沿着 chunked finalization
  路径写出 terminal chunk。
- 同时 writer 之前没有显式阻止 no-body status 后继续 `Write` body，
  使得无 body 响应的 contract 只能靠调用方自觉遵守。

## Fixed design truth

- `TH1ResponseWriter` 现在用统一谓词
  `ResponseMustNotHaveBody` 识别 `1xx` / `204` / `304` no-body status。
- `WriteHeader` 现在不会再为 no-body status 自动补
  `Transfer-Encoding: chunked`。
- `Write` 现在会在 no-body status 下直接抛出
  `EHttpError('response status must not include a body')`，不允许继续写 body。
- `test_http_h1writer` 现在直接锁定：
  `204/304` 不注入 chunked，`204` 后续 body write 会被拒绝。
- `test_http_server` 现在直接锁定：
  `204/304` raw-wire 响应都不带 `transfer-encoding: chunked`、不带强制
  `content-length`、也不带 chunk trailer。

## Why this is the right fix

- contract 被收在 writer 状态机本身，而不是在 server 层零散地特殊判断，
  这样 future runtime/backend 复用同一个 H1 writer 时也会继承这条语义。
- 这修的是协议正确性，不是输出风格细节：`204/304` 带 chunked framing
  本身就是错误的 response contract。
- focused writer + server proof 现在同时覆盖 helper 层和 raw-wire 层，
  不会只停留在某个内部实现细节上。
- 当前共享谓词已经包含 `1xx`，但 `1xx` raw-wire focused proof 仍未补，
  所以这批只冻结 `204/304` 已证实的契约，不夸大未测范围。
