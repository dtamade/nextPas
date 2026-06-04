# Findings: header field over max-header explicit 431

## Scope

- 本轮继续 header-budget 邻接缺口，把普通 header field over
  `MaxHeaderSize` 从 broad safe-handling 收紧成 explicit `431` 契约。
- 目标不是生产修复，而是把 server/security 两层证据补到与上一刀
  `request-target over MaxHeaderSize` 一致。

## Confirmed truths

### 1. 旧用例只能证明安全处理，不能证明 explicit `431`

- `test_http_server` 旧 `MaxHeaderSize enforcement` 只接受：
  - `431`
  - 或连接关闭
- `test_http_security` 旧 `Oversized header >8KB` 更宽，只要求：
  - `431`
  - `400`
  - `200`
  - 或连接关闭
- 这些断言适合作为历史 safe-handling smoke，但不足以证明当前实现已经在
  受控小 `MaxHeaderSize` 下稳定返回显式 `431`。

### 2. focused tests 直接 GREEN，说明 explicit `431` contract 已经成立

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增两条 focused proofs：
  - threaded `Header field over MaxHeaderSize -> explicit 431`
  - epoll `Header field over MaxHeaderSize -> explicit 431`
  - 同时锁住 handler 不进入
- 在 [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增两条 raw-wire proofs：
  - threaded `Header field over MaxHeaderSize -> explicit 431`
  - epoll `Header field over MaxHeaderSize -> explicit 431`
- focused gates 都直接 GREEN，说明当前生产代码已经满足这条契约，本轮不需要生产修复。

### 3. server / security 两层对 header-budget 分支现在重新对齐

- 普通 header field over `MaxHeaderSize`
  - server：显式 `431` 且 handler 不进入
  - security：threaded / epoll raw-wire 显式 `431`
- request-target over `MaxHeaderSize`
  - 上一刀已同样锁住 server/security 口径
- 因此 request-line / header-field 两个主要 header-budget 分支现在都不再停留在 broad safe-handling。
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `219/219 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_security clean test`
    - `132/132 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补掉的是普通 header-field budget 的一个高价值小缺口。
- 邻接 still-open 方向仍应保持同样策略：
  - 优先挑还没分类完的 malformed/runtime 边角
  - 不再机械平铺 request-tail parity
- 下一刀更自然的是继续寻找：
  - oversize trailer `431 or safe-close` 是否需要继续收紧
  - 或其他还没被 security 明确锁成 `400/431/501` 的 raw-wire 邻接缺口
