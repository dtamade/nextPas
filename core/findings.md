# Findings: http trailer-complete same-write pipelining raw-wire proof

## Scope

- 本轮继续留在 H1 correctness 主线，但沿 keep-alive request-tail contract 再往前推进一刀。
- 目标不是扩大生产逻辑，而是先确认 trailer-complete chunked request 与同包下一请求同时到达时，default threaded 与 live `epoll` backend 都会把两个请求稳定拆分，并分别返回各自的 `200` 响应。

## Confirmed truths

### 1. trailer-complete same-write pipelining truth 在 raw-wire security 层补齐了

- 新增的 security proof 直接覆盖：
  - 首个 trailer-complete chunked request 返回 `200 / echo:5`
  - 同包第二个 request 继续返回 `200 / ok`
- 这说明当前 transport 不会让同包第二个 request 污染首请求，也不会在 trailer-complete 边界把后续 request 吃坏。

### 2. 本轮没有暴露生产缺口，不需要修 transport / parser

- 本轮 focused suite 全绿，说明当前 parser + H1 transport 的现有拒绝路径已经自然延伸到 epoll live backend。
- 因此这一批保持为 coverage-expansion；没有新增生产代码，也没有引入新的行为分叉。

### 3. 这轮证明 request-tail same-write pipeline truth 也保持了 threaded / epoll 一致性

- 之前 `server` 已经有这条 same-write pipelining truth，但 `security` 层还没有 direct raw-wire proof。
- 这一轮把它补到了 security，并顺手确认 Linux `epoll` live backend 没有把这条 pipeline contract 做偏。

### 4. 下一步应回到 malformed grammar 边角，或重新筛查 request-tail contract 余下缺口

- 既然现在代表性的 `400/501/431`、partial-next-line bridge、same-write pipelining 都没有 backend 差异，再继续机械复制同型 epoll case 的收益已经明显下降。
- 更值的下一刀有两个方向：
  - 尚未完全收口的 trailer/chunk truncation 相邻子类
  - 重新盘点 request-tail contract 是否还存在没下沉到 security 的 raw-wire truth

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `71/71 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮是 raw-wire same-write pipeline truth 补齐，不是把所有 parser/server request-tail 契约都复制一遍到 security。
- `test_http_security` 里是否还缺 request-tail contract 的别的 bridge truth，需要下一轮再做一次矩阵筛查。
- benchmark 继续后置；当前阶段仍以 correctness 和接口契约收口优先。
