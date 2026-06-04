# Findings: http live epoll malformed chunked security parity

## Scope

- 本轮回到 `malformed chunked request security` 主线。
- 目标不是扩大生产逻辑，而是先确认 live `epoll` backend 在代表性 raw-wire malformed chunked 输入上，是否与默认 threaded backend 保持同样的拒绝语义。

## Confirmed truths

### 1. 代表性 malformed chunked raw-wire 语义在 live epoll backend 上没有漂移

- 新增的 Linux `epoll` live security proof 直接覆盖：
  - `Transfer-Encoding: gzip, chunked` -> `501`
  - invalid chunk size -> `400`
  - missing chunk-data CRLF -> `400`
  - truncated trailer section CR EOF -> `400`
- 这四条都直接通过，说明当前 live epoll backend 没有把这些异常 chunk framing 变成“静默关闭”或错误状态码偏移。

### 2. 本轮没有暴露生产缺口，不需要修 transport / parser

- 本轮 focused suite 全绿，说明当前 parser + H1 transport 的现有拒绝路径已经自然延伸到 epoll live backend。
- 因此这一批保持为 coverage-expansion；没有新增生产代码，也没有引入新的行为分叉。

### 3. 现在已经有一组更可信的 backend parity security 基线

- 之前 `epoll` 证据主要集中在 keep-alive、pipeline、backpressure、write-timeout 与 hijack。
- 这一轮把 live security parity 往异常 chunk framing 这条 correctness 主线补了一格。
- 当前至少已经有代表性的：
  - malformed `400`
  - unsupported transfer-coding `501`
  两类 live epoll rejection truth。

### 4. 最值得继续补的不是重复 `400` 平铺，而是状态类仍缺代表的 `431`

- 既然这轮代表性 `400/501` 没有 backend 差异，再继续机械复制更多同型 `400` 的信息增益不高。
- 如果还要沿 live backend parity 再走一刀，更值的是：
  - trailer-budget / oversize trailer 的 `431` 或 safe-close 语义
- 这样可以把 chunked security 的代表状态类从 `400/501` 扩到 `431`，而不是只堆同型 case。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `66/66 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮是 representative live epoll parity，不是把所有 security case 都复制一遍到 epoll backend。
- `test_http_security` 里的 epoll live 目前还没有直接锁住 trailer-budget `431` / safe-close truth。
- benchmark 继续后置；当前阶段仍以 correctness 和接口契约收口优先。
