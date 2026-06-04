# Findings: http chunk truncation epoll live parity proofs

## Scope

- 本轮继续留在 H1 correctness 主线，继续沿 malformed chunked/trailer truncation 边界收口 epoll live parity。
- 目标不是扩大生产逻辑，而是确认 chunk parser 的各个 EOF 截断终止点在 epoll live backend 上也稳定返回 `400`，而不是只靠 threaded proof 代推。

## Confirmed truths

### 1. chunk truncation 这一整组 epoll raw-wire truth 现在补齐了

- 新增的 security proof 直接覆盖：
  - truncated chunk extension / extension CR
  - truncated chunked request / chunk-size line
  - truncated terminal chunk ending / ending CR
  - truncated terminal chunk extension / extension CR
  - truncated terminal chunk ending after extension / after-extension CR
  - truncated chunk-data ending / chunk-data CR
- 这说明 chunk parser 的这些 EOF 截断终止点在 epoll live backend 上都能稳定走到显式 `400`，不再只靠 threaded 路径外推。

### 2. security 层对 malformed chunked grammar 的 epoll live parity 现在不再只停在少数 representative case

- 此前 `test_http_security` 在 epoll live 路径只有：
  - unsupported transfer-coding
  - invalid chunk size
  - missing chunk-data CRLF
  - trailer truncation 家族
- 这轮之后，chunk-side truncation 这一族也已经基本不再缺 epoll live parity。

### 3. 本轮没有暴露生产缺口，不需要修 transport / parser

- 新增用例直接 GREEN，说明当前 parser + H1 transport 的现有拒绝路径已经自然延伸到 epoll live backend。
- 因此这一批保持为 coverage-expansion；没有新增生产代码，也没有引入新的行为分叉。

### 4. 下一步应重新筛查真正还缺 live parity 的 malformed raw-wire 边界，而不是回头再做 request-tail 机械 parity

- 既然 request-tail 关键 sibling、trailer truncation、chunk truncation 这几大块都已经明显收口，再回头复制已知稳定模式的收益就更低了。
- 更值的下一刀有两个方向：
  - 重新筛查 security 是否还有真正未对齐的 malformed raw-wire boundary
  - 如果 security 只剩机械 parity，就回到更高价值的 correctness 边界

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `106/106 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补的是 chunk truncation 的 epoll live parity 缺口，不是把所有 malformed chunked grammar 都复制一遍到 security。
- 本轮没有形成行为级 RED；暴露出来的是 coverage gap，而不是生产缺陷。
- benchmark 继续后置；当前阶段仍以 correctness 和接口契约收口优先。
