# Findings: http trailer public contract proof

## Scope

- 本轮从 security/runtime parity 批次切回 public contract 收口。
- 目标不是扩生产行为，而是把当前 chunked trailer 的对外语义直接钉在契约层。

## Confirmed truths

### 1. 当前 trailer 公共契约现在有了 focused public proof

- `test_http_contract` 直接用真实 `THttpServer` + raw chunked request 锁定：
  - handler 能读到解码后的 chunked body
  - `Trailer` 声明头会保留在 `AReq.Headers`
  - 实际 trailer field 不会作为普通 header 暴露

### 2. 这轮没有发现生产缺口

- 新用例在当前实现上直接通过，说明此前 server/security 间接证明的行为和 public facade 视角一致。
- 因此本轮保持为 coverage-expansion，不需要改 parser、transport 或 server 生产代码。

### 3. 这批工作把后续 trailer API 讨论边界收窄了

- 现在已经明确：v1 当前契约不是“读 trailer fields”，而是“保留 declaration header，隐藏 trailer fields”。
- 如果将来要暴露 trailer fields，应该新增显式 public API，而不是让它们悄悄混入普通 headers。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_contract clean test`
  - `28/28 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮锁定的是当前 trailer public contract，不代表 trailer API 设计已经终局。
- 下一步应优先筛查更高价值的 runtime truth / facade helper boundary，而不是回到机械 parity 复制。
