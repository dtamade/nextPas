# Findings: oversize trailer max-header explicit 431

## Scope

- 本轮继续 header-budget 邻接缺口，把 chunked oversize trailer over
  `MaxHeaderSize` 从 `431 or safe-close` 收紧成 explicit `431` 契约。
- 目标不是生产修复，而是把 server/security 两层证据补到与普通
  header field / request-target over `MaxHeaderSize` 一致。

## Confirmed truths

### 1. 旧用例只能证明安全处理，不能证明 explicit `431`

- `test_http_server` 旧 oversize trailer 用例只接受：
  - `431`
  - 或连接关闭
- `test_http_security` 旧 oversize trailer 用例同样只接受：
  - `431`
  - 或连接关闭
- 这些断言适合作为历史 safe-handling smoke，但不足以证明当前实现已经在
  trailer 阶段受控小 `MaxHeaderSize` 下稳定返回显式 `431`。

### 2. focused tests 直接 GREEN，说明 explicit `431` contract 已经成立

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  收紧 / 新增两条 focused proofs：
  - threaded `Chunked request oversize trailer uses MaxHeaderSize -> explicit 431`
  - epoll `Chunked request oversize trailer uses MaxHeaderSize -> explicit 431`
  - 同时锁住 handler 不进入
- 在 [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  收紧两条 raw-wire proofs：
  - threaded `Chunked oversize trailer uses MaxHeaderSize -> explicit 431`
  - epoll `Chunked oversize trailer uses MaxHeaderSize -> explicit 431`
- focused gates 都直接 GREEN，说明当前生产代码已经满足这条契约，本轮不需要生产修复。

### 3. server / security 两层对三条 header-budget 分支现在重新对齐

- chunked oversize trailer over `MaxHeaderSize`
  - server：显式 `431` 且 handler 不进入
  - security：threaded / epoll raw-wire 显式 `431`
- 普通 header field over `MaxHeaderSize`
  - 上一刀已同样锁住 server/security 口径
- request-target over `MaxHeaderSize`
  - 上一刀已同样锁住 server/security 口径
- 因此 request-line / header-field / trailer 三个主要 header-budget 分支现在都不再停留在 broad safe-handling。
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `220/220 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_security clean test`
    - `132/132 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补掉的是 trailer-stage header budget 的一个高价值小缺口。
- 邻接 still-open 方向仍应保持同样策略：
  - 优先挑还没分类完的 malformed/runtime 边角
  - 不再机械平铺 request-tail parity
- 下一刀更自然的是继续寻找：
  - 或其他还没被 security 明确锁成 `400/431/501` 的 raw-wire 邻接缺口
  - 或开始转向更高层 HttpServer 文档 / examples / benchmark 前的剩余 API gaps
