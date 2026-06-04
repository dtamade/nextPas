# Findings: http trailer-complete partial-next-line raw-wire bridge proof

## Scope

- 本轮继续留在 H1 correctness 主线，但切到了相邻的 keep-alive request-tail contract。
- 目标不是扩大生产逻辑，而是先确认 trailer-complete chunked request 后跟半截下一请求行时，default threaded 与 live `epoll` backend 都会先完成首请求，并允许补全后的第二请求继续合法完成。

## Confirmed truths

### 1. trailer-complete partial-next-line bridge truth 在 raw-wire security 层补齐了

- 新增的 security proof 直接覆盖：
  - 首个 trailer-complete chunked request 返回 `200 / echo:5`
  - 半截 follow-up request line 后续补全后，第二个 request 继续返回 `200 / ok`
- 这说明当前 transport 不会把半截 follow-up 行过早判成 malformed tail，也不会污染首请求的完成语义。

### 2. 本轮没有暴露生产缺口，不需要修 transport / parser

- 本轮 focused suite 全绿，说明当前 parser + H1 transport 的现有拒绝路径已经自然延伸到 epoll live backend。
- 因此这一批保持为 coverage-expansion；没有新增生产代码，也没有引入新的行为分叉。

### 3. 这轮证明 request-tail bridge truth 也保持了 threaded / epoll 一致性

- 之前 `parser` 和 `server` 已经有这条 bridge truth，但 `security` 层还没有 direct raw-wire proof。
- 这一轮把它补到了 security，并顺手确认 Linux `epoll` live backend 没有把这条 bridge contract 做偏。

### 4. 下一步应继续补 request-tail contract 的剩余 raw-wire 真缺口，或回到 malformed grammar 边角

- 既然现在代表性的 `400/501/431` 和这条 partial-next-line bridge 都没有 backend 差异，再继续机械复制同型 epoll case 的收益已经明显下降。
- 更值的下一刀有两个方向：
  - trailer-complete same-write pipelined next request 的 security raw-wire proof
  - 尚未完全收口的 trailer/chunk truncation 相邻子类

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `69/69 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮是 raw-wire bridge truth 补齐，不是把所有 parser/server request-tail 契约都复制一遍到 security。
- `test_http_security` 里 trailer-complete same-write pipelining 目前仍未直接锁成 raw-wire proof。
- benchmark 继续后置；当前阶段仍以 correctness 和接口契约收口优先。
