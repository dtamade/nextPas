# Findings: http chunked epoll request-tail safety proofs

## Scope

- 本轮继续留在 H1 correctness 主线，但按“同族成批补齐”的节奏收口 chunked keep-alive request-tail 的 Linux `epoll` security gap。
- 目标不是扩大生产逻辑，而是确认 chunked request 完整结束后，epoll live backend 对剩余 4 类 follow-up malformed tail 也保持稳定的 `200 -> 400` 语义。

## Confirmed truths

### 1. plain chunked `garbage tail` / `truncated follow-up request line` 的 epoll raw-wire truth 现在补齐了

- 新增的 security proof 直接覆盖：
  - 首个 chunked request 返回 `200 / echo:5`
  - terminal chunk 之后紧跟 garbage tail 时，follow-up malformed request 返回 `400`
  - follow-up 只到达半截 request line 再 EOF 时返回 `400`
- 这说明当前 transport 不会让 chunked request body 之后的尾部垃圾或半截 request line 污染首请求完成语义；epoll live backend 会先交付首个合法响应，再把 follow-up malformed tail 收口为后继 `400`。

### 2. trailer-complete chunked `garbage tail` / `truncated follow-up request line` 的 epoll raw-wire truth 现在也补齐了

- 新增的 security proof 直接覆盖：
  - 首个 trailer-complete chunked request 返回 `200 / echo:5`
  - trailer section 之后紧跟 garbage tail 时，follow-up malformed request 返回 `400`
  - follow-up 只到达半截 request line 再 EOF 时返回 `400`
- 这说明 epoll live backend 在 trailer section 完整结束后，同样遵守同一条 request-tail contract：首请求先完整交付，follow-up 只在已确定 malformed 时返回后继 `400`。

### 3. chunked epoll request-tail 这一组 security truth 现在基本对齐了 parser / server

- `parser`、`server`、`security` 三层现在都已有 plain chunked request-tail 的成组证据：
  - garbage tail -> follow-up `400`
  - truncated follow-up request line -> follow-up `400`
  - truncated follow-up headers -> follow-up `400`
  - partial follow-up request line can complete later
- trailer-complete chunked 在 `security` 层现在也已有：
  - garbage tail -> follow-up `400`
  - truncated follow-up request line -> follow-up `400`
  - truncated follow-up headers -> follow-up `400`
  - partial follow-up request line can complete later
  - same-write pipelined next request
- 这轮之后，chunked 这组 epoll request-tail truth 已经不再只靠个别 representative case 代推。

### 4. 本轮没有暴露生产缺口，不需要修 transport / parser

- 新增用例直接 GREEN，说明当前 parser + H1 transport 的现有拒绝路径已经自然延伸到 epoll live backend。
- 因此这一批保持为 coverage-expansion；没有新增生产代码，也没有引入新的行为分叉。

### 5. 下一步应离开已基本收口的 chunked request-tail，同步回到更真实的 correctness 缺口

- 既然现在代表性的 `400/501/431`、`Content-Length` / plain chunked / trailer request-tail 关键 sibling、以及 same-write pipelining 都没有 backend 差异，再继续机械复制同型 epoll case 的收益已经明显下降。
- 更值的下一刀有两个方向：
  - 尚未完全收口的 trailer/chunk truncation 相邻子类
  - 重新筛查 security 是否还有真正未对齐的 malformed raw-wire boundary，而不是继续复制已知稳定模式

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `82/82 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补的是 chunked epoll request-tail 的剩余同族缺口，不是把所有 parser/server request-tail 契约都复制一遍到 security。
- 本轮没有形成行为级 RED；暴露出来的是 coverage gap，而不是生产缺陷。
- benchmark 继续后置；当前阶段仍以 correctness 和接口契约收口优先。
