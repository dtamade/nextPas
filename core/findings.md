# Findings: http idle-timeout chunk-size-line characterization

## Scope

- 本轮不碰生产逻辑，只继续收口 `HttpServer` correctness。
- 目标是确认 request-side `IdleTimeout` 是否已经覆盖到
  `partial chunk-size-line stall` 这类真实 chunk framing 中间态。

## Confirmed truths

### 1. request-side timeout contract 之前还缺一个明确的 chunk framing 中间态证据

- 之前 focused / live 证据已经覆盖：
  - first-byte slowloris
  - partial fixed-length body stall
  - partial chunked trailer stall
- 但 `chunk-size-line` 仍是另一类 parser wait state：
  - 请求头已完成
  - chunked body 已进入 framing
  - 还没进入完整 chunk data / trailer

这一态如果没有专门 proof，就还不能说 request-side timeout 已完整扫到主要 chunk ingress 中间态。

### 2. 当前实现对 chunk-size-line stall 的 request-side timeout truth 是成立的

- `test_http_server` 新增 poll-driven seam proof：
  - `H1 poll-driven session times out partial chunk-size line read wait`
- `test_http_security` 新增 live-socket proof：
  - threaded：`Partial chunk-size line idle-timeout closes connection`
  - epoll：`Partial chunk-size line idle-timeout closes connection with epoll backend`

三条新增证据都直接通过，说明当前 runtime 已经把这类 stall 沿用同一条 request-parse deadline 收口。

### 3. 本轮仍是 coverage-expansion，不需要生产修复

- 没有新增服务器实现改动。
- 新测试直接通过，说明已有 runtime 行为与我们要锁定的 contract 一致。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `177/177 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_security test`
    - `117/117 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- request-side timeout 的代表性 parser wait state 现在更完整了，但 correctness 主线还没自然结束。
- 下一步更值的方向仍应二选一：
  - 再挑一个真正还没分类完的 malformed/runtime/security 边角
  - 或判断 `3/6 H1 正确性加固` 是否已经接近收口线，避免继续机械横向补 case
