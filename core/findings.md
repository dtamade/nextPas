# Findings: h1 parser keep-alive partial follow-up headers bridge

## Scope

- 本轮继续 keep-alive request-tail contract refinement，不扩散成更大的
  malformed 输入矩阵，只把 parser 层还没显式锁住的
  `partial follow-up headers can complete later` bridge truth 收口。

## Confirmed truths

### 1. parser 层先前只有“首请求不被污染 + Finish 后报错”，还缺 “headers 可补全” 的 bridge proof

- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  之前对 `H1 parser` 只锁到：
  - `Content-Length` / plain `chunked` / trailer-complete `chunked` 的 partial follow-up headers 不会污染首请求
  - 如果只有这半截 headers 就 `Finish`，parser 会报错
- 这能证明“当前请求不会被污染”，但还不能直接证明“后续补齐这些 headers 后第二请求能合法完成”。

### 2. server/security 已经证明 transport truth，parser 需要补底层对应真值

- `test_http_server` / `test_http_security` 现在都已证明：
  - `Content-Length` / plain `chunked` / trailer-complete `chunked`
  - 在 follow-up partial headers 后续补齐时，第二请求都能继续完成
- 因此 parser 层缺的不是行为实现，而是更底层的 focused proof。

### 3. focused gate 直接 GREEN，说明这条 parser bridge contract 已成立

- 在 [tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr)
  新增三条 bridge proofs：
  - `Content-Length` partial follow-up headers can complete later
  - plain `chunked` partial follow-up headers can complete later
  - trailer-complete `chunked` partial follow-up headers can complete later
- focused gate 直接 GREEN，说明当前生产代码已经满足这条 bridge 契约，本轮不需要生产修复。

### 4. parser / server / security 三层对这组三支 headers bridge 现在重新对齐

- 已有 direct live truth：
- `test_http_h1parser`
  - `Content-Length` / plain `chunked` / trailer-complete `chunked`
    的 partial follow-up headers 都能在补齐后完成第二请求
- `test_http_server` / `test_http_security`
  - 同三条分支都已有更上层的 live/raw-wire bridge truth
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_h1parser test`
    - `88/88 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补齐了 parser 层 keep-alive request-tail 三条主分支里 remaining 的 headers bridge 空档。
- 邻接 still-open 收口方向仍包括：
  - 继续挑仍未分类完的 malformed/runtime 边角，而不是机械平铺 parity
- 如果继续沿 request-tail / malformed 主线推进，下一刀更自然的是转去仍未分类完的 runtime / malformed 邻接缺口，而不是继续复制同型 bridge。
- 下一刀仍应继续 keep-alive request-tail contract，而不是回去铺 `Expect` 矩阵或 benchmark。
