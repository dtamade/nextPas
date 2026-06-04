# Findings: security request-target over max-header explicit 431

## Scope

- 本轮离开上一刀的 request-tail bridge 模板，改做
  `request-target over MaxHeaderSize` 的 raw-wire security 收紧。
- 目标不是生产修复，而是把 `test_http_security` 里仍停留在 broad
  safe-handling 的 URL/header-budget 分支收成显式 `431` 契约。

## Confirmed truths

### 1. `test_http_server` 早已锁住 request-target over MaxHeaderSize 的 server-layer 主分支

- `test_http_server` 已有 focused proof：
  - 在受控小 `MaxHeaderSize := 256` 下
  - oversized request-target 会直接返回 `HTTP/1.1 431`
  - handler 不会进入
- 因此这刀不是发现新行为，而是把 security 层补到和 server 一致的公开证据密度。

### 2. `test_http_security` 之前还停留在 broad safe-handling current truth

- 之前 security 对“超长 URL / request-line”只断言：
  - `431`
  - `414`
  - `400`
  - `404`
  - `200`
  - 或安全关闭
- 这只能证明 server 安全，不足以证明当前实现已经把
  `request-target over MaxHeaderSize` 收敛到显式 `431`。

### 3. focused gate 直接 GREEN，说明这条 explicit `431` contract 已经成立

- 在 [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增两条 focused proofs：
  - threaded `request-target over MaxHeaderSize -> explicit 431`
  - epoll `request-target over MaxHeaderSize -> explicit 431`
- `make -C tests/nextpas.core.http/test_http_security clean test`
  直接 GREEN，说明当前生产代码已经满足这条契约，本轮不需要生产修复。

### 4. server / security 两层对这个 budget 分支现在重新对齐

- `test_http_server`
  - 锁更窄的 server-layer 语义：显式 `431` 且 handler 不进入
- `test_http_security`
  - 锁 raw-wire 语义：threaded / epoll 都显式返回 `431`
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
    - `130/130 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补掉的是 security 层 request-line / URL budget 的一个高价值小缺口。
- 邻接 still-open 方向仍应保持同样策略：
  - 优先挑还没分类完的 malformed/runtime 边角
  - 不再机械平铺 request-tail parity
- 下一刀更自然的是继续寻找：
  - 仍停留在 broad safe-handling 的 request/header budget 分支
  - 或其他还没被 security 明确锁成 `400/431/501` 的 raw-wire 邻接缺口
