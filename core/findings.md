# Findings: http live epoll oversize trailer parity

## Scope

- 本轮继续留在 `malformed chunked request security` 主线。
- 目标不是扩大生产逻辑，而是先确认 live `epoll` backend 在 trailer-budget / oversize trailer 这条状态类上，是否与默认 threaded backend 保持同样的 `431 or safe-close` 语义。

## Confirmed truths

### 1. oversize trailer 的 live epoll `431/safe-close` 语义没有漂移

- 新增的 Linux `epoll` live security proof 直接覆盖：
  - oversize trailer -> `431 or safe-close`
  - handler response not written
- 这条直接通过，说明当前 live epoll backend 没有把 trailer-budget 拒绝路径偏成错误的 `200`、handler 落地，或和 threaded 不同的异常行为。

### 2. 本轮没有暴露生产缺口，不需要修 transport / parser

- 本轮 focused suite 全绿，说明当前 parser + H1 transport 的现有拒绝路径已经自然延伸到 epoll live backend。
- 因此这一批保持为 coverage-expansion；没有新增生产代码，也没有引入新的行为分叉。

### 3. 现在 epoll live security 已经有更完整的代表状态类

- 之前 `epoll` 证据主要集中在 keep-alive、pipeline、backpressure、write-timeout 与 hijack。
- 这一轮把 live security parity 往异常 chunk framing 这条 correctness 主线补了一格。
- 当前至少已经有代表性的：
  - malformed `400`
  - unsupported transfer-coding `501`
  - trailer-budget `431 or safe-close`
  三类 live epoll rejection truth。

### 4. 下一步不该继续堆 epoll 状态码副本，而该回到剩余 malformed grammar 边角

- 既然现在代表性的 `400/501/431` 都没有 backend 差异，再继续机械复制更多同型状态码的收益已经明显下降。
- 更值的下一刀，是回到尚未完全收口的 trailer/chunk truncation 相邻子类，继续推进 parser/server/security 三层 correctness 真缺口。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `67/67 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮是 representative live epoll parity，不是把所有 security case 都复制一遍到 epoll backend。
- 目前 `test_http_security` 的 epoll live 仍是代表性覆盖，不是全量 backend 镜像矩阵。
- benchmark 继续后置；当前阶段仍以 correctness 和接口契约收口优先。
