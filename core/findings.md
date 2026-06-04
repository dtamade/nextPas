# Findings: http content-length epoll request-tail safety proofs

## Scope

- 本轮继续留在 H1 correctness 主线，但按“同族成批补齐”的节奏收口 `Content-Length` keep-alive request-tail 的 Linux `epoll` security gap。
- 目标不是扩大生产逻辑，而是确认 fixed-length request 完整结束后，epoll live backend 对剩余两类 follow-up malformed tail 也保持稳定的 `200 -> 400` 语义。

## Confirmed truths

### 1. `Content-Length` keep-alive garbage tail 的 epoll raw-wire truth 现在补齐了

- 新增的 security proof 直接覆盖：
  - 首个 `Content-Length` request 返回 `200 / echo:5`
  - body 之后紧跟 garbage tail 时，follow-up malformed request 返回 `400`
- 这说明当前 transport 不会让尾部垃圾污染首个 fixed-length request 的完成语义；epoll live backend 会先交付首个合法响应，再把尾部垃圾作为 follow-up malformed request 收口。

### 2. `Content-Length` keep-alive truncated follow-up request line 的 epoll raw-wire truth 现在也补齐了

- 新增的 security proof 直接覆盖：
  - 首个 `Content-Length` request 返回 `200 / echo:5`
  - follow-up 只到达半截 request line 再 EOF 时返回 `400`
- 这说明 epoll live backend 也遵守同一条 request-tail contract：首请求先完整交付，follow-up 只在 EOF 后被确定为 malformed，并返回后继 `400`。

### 3. `Content-Length` epoll request-tail 这一组 security truth 现在对齐了 parser / server

- `parser`、`server`、`security` 三层现在都已有 `Content-Length` keep-alive request-tail 的成组证据：
  - garbage tail -> follow-up `400`
  - truncated follow-up request line -> follow-up `400`
  - truncated follow-up headers -> follow-up `400`
  - partial follow-up request line can complete later
- 这轮之后，`Content-Length` 这组 epoll request-tail truth 不再只靠单个 representative case 代推。

### 4. 本轮没有暴露生产缺口，不需要修 transport / parser

- 新增用例直接 GREEN，说明当前 parser + H1 transport 的现有拒绝路径已经自然延伸到 epoll live backend。
- 因此这一批保持为 coverage-expansion；没有新增生产代码，也没有引入新的行为分叉。

### 5. 下一步应继续只挑真实缺口，不再机械复制同型 parity

- 既然现在代表性的 `400/501/431`、`Content-Length` / plain chunked / trailer partial-next-line bridge、以及 `Content-Length` / plain chunked / trailer partial follow-up headers、same-write pipelining 都没有 backend 差异，再继续机械复制同型 epoll case 的收益已经明显下降。
- 更值的下一刀有两个方向：
  - 尚未完全收口的 trailer/chunk truncation 相邻子类
  - 重新筛查 security 是否还剩真正未对齐的 request-tail sibling gap，而不是继续复制已知稳定模式

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `78/78 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补的是 `Content-Length` epoll request-tail 的剩余同族缺口，不是把所有 parser/server request-tail 契约都复制一遍到 security。
- 本轮没有形成行为级 RED；暴露出来的是 coverage gap，而不是生产缺陷。
- benchmark 继续后置；当前阶段仍以 correctness 和接口契约收口优先。
