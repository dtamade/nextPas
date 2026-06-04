# Findings: http content-length truncated follow-up headers epoll raw-wire proof

## Scope

- 本轮继续留在 H1 correctness 主线，但先做了一次 parser/server/security 矩阵筛查，再沿 keep-alive request-tail contract 推进一步。
- 目标不是扩大生产逻辑，而是确认 `Content-Length` request 结束后，如果同连接上的 follow-up request 只到达半截 headers 再 EOF，live `epoll` backend 也会先交付首个 `200 / echo:5`，再把 follow-up 稳定收口成 `400`。

## Confirmed truths

### 1. `Content-Length` truncated follow-up headers 的 epoll raw-wire truth 现在补齐了

- 新增的 security proof 直接覆盖：
  - 首个 `Content-Length` request 返回 `200 / echo:5`
  - follow-up 半截请求头在 peer half-close 后返回 `400`
- 这说明当前 transport 在 fixed-length request 完整结束后，仍会先稳定完成首请求，再把 follow-up header truncation 作为后继 malformed request 处理；epoll live backend 没有把这条 contract 做偏。

### 2. 本轮没有暴露生产缺口，不需要修 transport / parser

- 新增用例直接 GREEN，说明当前 parser + H1 transport 的现有拒绝路径已经自然延伸到 epoll live backend。
- 因此这一批保持为 coverage-expansion；没有新增生产代码，也没有引入新的行为分叉。

### 3. 这轮把 request-tail 矩阵里一个真实缺口补平了，而不是继续盲目扩面

- `server` 早就有 `Content-Length` truncated follow-up headers 的 threaded + epoll truth，`security` 层此前只有 threaded raw-wire proof。
- 这轮把缺口补到 security 后，三层矩阵在这个状态机位置重新对齐。

### 4. 下一步应继续只挑一格真实缺口，不再机械复制同型 parity

- 既然现在代表性的 `400/501/431`、`Content-Length` / plain chunked / trailer partial-next-line bridge、以及 `Content-Length` / plain chunked / trailer partial follow-up headers、same-write pipelining 都没有 backend 差异，再继续机械复制同型 epoll case 的收益已经明显下降。
- 更值的下一刀有两个方向：
  - 尚未完全收口的 trailer/chunk truncation 相邻子类
  - 剩余 request-tail sibling gap 里，是否还有比 `garbage tail` / `truncated follow-up line` 更值得下沉到 security 的 raw-wire truth

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `76/76 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补的是一个 epoll request-tail bridge 缺口，不是把所有 parser/server request-tail 契约都复制一遍到 security。
- 本轮没有形成行为级 RED；暴露出来的是 coverage gap，而不是生产缺陷。
- benchmark 继续后置；当前阶段仍以 correctness 和接口契约收口优先。
