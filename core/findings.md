# Findings: http epoll malformed chunked live parity

## Scope

- 本轮不碰生产逻辑，只回到 raw-wire malformed chunked request security。
- 目标是给 Linux `epoll` backend 补上两条真实 socket 侧缺失证明：
  - `chunked + Connection: close + extra bytes after terminal chunk` -> `400`
  - malformed trailer field -> `400`

## Confirmed truths

### 1. 这两条 malformed chunked contract 之前缺的是 `epoll` live parity，不是 parser/server 基础 truth

- 现有证据已经包括：
  - parser focused proof：terminal chunk close 后 extra bytes 会被拒绝；非法 trailer field 会被拒绝
  - threaded/default server proof：两条请求都返回显式 `400`
  - security `epoll` live parity：此前已覆盖 transfer-coding order、invalid chunk size、missing chunk-data CRLF、chunk/trailer truncation EOF、oversize trailer
- 缺口在于：
  - `epoll` security 还没有直接证明 terminal close 后 garbage tail -> `400`
  - `epoll` security 还没有直接证明 malformed trailer field -> `400`

### 2. 当前实现对这两条 malformed request 在 `epoll` live raw-wire 路径上都已保持显式 `400`

- `test_http_security` 新增 focused proof：
  - `Chunked extra bytes after close -> 400 with epoll backend`
  - `Malformed trailer field -> 400 with epoll backend`
- 两条 case 都直接通过，锁定：
  - Linux `epoll` backend 下真实 socket 请求会返回显式 `HTTP/1.1 400`
  - 这轮不需要生产修复

### 3. 本轮仍是 coverage-expansion，不需要生产修复

- 没有新增实现改动。
- “先 RED” 的结果是新增 case 直接 GREEN，说明本轮问题是 live security proof 缺档，而不是实现缺陷。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
    - `120/120 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮已经把两条最顺手的 malformed chunked `epoll` live parity 缺口补掉，后续不应继续机械复制同型 backend parity。
- 下一步更值的方向应转向：
  - 真正还没分类完的 runtime / malformed 边角
  - 或 `3/6 H1 正确性加固` 的阶段收口条件与后续架构演进接口
