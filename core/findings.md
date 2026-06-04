# Findings: http server expect-417 error-path coverage

## Scope

- 本轮不是再补一个新协议分支，而是把上一刀刚引入的 `417 Expectation Failed`
  接到既有 error-path 证据链上，避免文档提前说满而测试还没锁住。

## Confirmed truths

### 1. `417` 契约本身已经落地，但 direct-error / queued-follow-up 证据还不完整

- `API_COVERAGE.md` 已经把 `417` 写进：
  - queued follow-up wire-order contract
  - poll-driven standalone direct-error drain
  - timed partial-timeout preserve-status
  - real-socket queued follow-up wire-order
- 但上一轮 focused proof 只锁住了“unsupported `Expect` -> early `417`”本身，
  还没有把这些 downstream error-path 全部接上。

### 2. 现有 generic error-path 已经天然支持 `417`，这轮不需要生产修复

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增一组 focused tests 后，全部直接 GREEN：
  - poll-driven queued follow-up `417`
  - poll-driven standalone direct `417` writable-drain
  - poll-driven standalone direct `417` partial-timeout preserve-status
  - threaded direct error write-timeout / partial-timeout `417`
  - threaded / epoll real-socket queued follow-up `417` wire-order
- 这直接证明当前 generic error-path 并没有把 `417` 当成特殊漏网状态。

因此这轮是 coverage-expansion，不是生产修复。

### 3. 现在 `417` 已经接上完整的 direct-error 证据链

- `417` 现在不只证明“headers-stage early rejection”：
  - queued follow-up `417` 会排在首个 `200` 之后
  - poll-driven standalone direct `417` 会走 reactor-owned writable drain
  - `417` partial-timeout 仍只暴露单一原始 status line
  - real-socket queued follow-up `417` 在线程与 `epoll` 两条 live 路径上都保持 wire order

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `192/192 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮把 `417` 接进 generic error-path 证据链了，但仍未覆盖：
  - `Expect` 组合场景的更广泛 differential characterization
  - 其他可在 headers 阶段直接裁决的 request-side final status
- 下一步仍应优先剩余真实协议缺口，而不是继续做低价值 parity 平铺。
