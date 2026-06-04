# Findings: http security keep-alive partial follow-up headers raw-wire bridge

## Scope

- 本轮继续 keep-alive request-tail contract refinement，不扩散成更大的
  malformed 输入矩阵，只把 `Content-Length` 与 plain `chunked` 两条
  partial follow-up headers 从 half-close safe-handling 收成更具体的
  security/raw-wire bridge proof。

## Confirmed truths

### 1. `test_http_security` 先前只锁到 half-close safe-handling，还缺 “headers 可补全” 的 raw-wire bridge

- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  之前对 `test_http_security` 只锁到：
  - `Content-Length` 首请求先完成，peer half-close 后半截 follow-up headers 作为 `400`
  - plain `chunked` 首请求先完成，peer half-close 后半截 follow-up headers 作为 `400`
- 这对 safe-handling 足够，但还不能证明 live/raw-wire 路径不会过早把“仍可补全”的
  follow-up headers 误判成 malformed。

### 2. 现有实现已经允许 `Content-Length` 与 plain `chunked` request 完成后保留未决 follow-up header bytes

- 与现有 server/security 的 `partial follow-up request-line can complete later`
  bridge proof 相邻的行为表明：
  - 当前请求 framing 一旦结束，尾部字节会被留给 follow-up parse
  - 问题不在“会不会保留 tail”，而在“header 已开始但未终止时，后续补字节是否还能继续”
- `Content-Length` 与 plain `chunked` 没有 trailer 隔离约束，正好适合合并成一刀收掉。

### 3. focused gate 直接 GREEN，说明这条 raw-wire bridge contract 已成立

- 在 [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增四条 raw-wire bridge proofs：
  - `Content-Length` threaded / epoll：首个 `200 / echo:5` 先返回，补齐 follow-up headers 后第二个 `200 / ok`
  - plain `chunked` threaded / epoll：首个 `200 / echo:5` 先返回，补齐 follow-up headers 后第二个 `200 / ok`
- focused gate 直接 GREEN，说明当前生产代码已经满足这条 bridge 契约，本轮不需要生产修复。

### 4. keep-alive request-tail 的 headers bridge 现在在 security 层三支都齐了

- 已有 direct live truth：
- `test_http_security`
  - `Content-Length` partial follow-up request-line / headers can complete later
  - plain `chunked` partial follow-up request-line / headers can complete later
  - trailer-complete chunked partial follow-up request-line / headers can complete later
  - 对应的 peer half-close / truncated follow-up headers 仍都落到 `400`
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security test`
    - `128/128 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补齐了 keep-alive request-tail 三条主分支里 remaining 的 headers bridge 空档。
- 邻接 still-open 收口方向仍包括：
  - 继续挑仍未分类完的 malformed/runtime 边角，而不是机械平铺 parity
- 如果继续沿 raw-wire / server 契约同一条线推进，下一刀更自然的是离开这组 parity case，转去仍未分类完的 runtime / malformed 邻接缺口。
- 下一刀仍应继续 keep-alive request-tail contract，而不是回去铺 `Expect` 矩阵或 benchmark。
