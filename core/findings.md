# Findings: http trailer truncation epoll live parity proofs

## Scope

- 本轮继续留在 H1 correctness 主线，但从 request-tail 切回 malformed chunked/trailer truncation 的 live parity 缺口。
- 目标不是扩大生产逻辑，而是确认 trailer truncation 各个终止点在 epoll live backend 上也稳定返回 `400`，而不是只靠 threaded proof 或单一 representative case 代推。

## Confirmed truths

### 1. trailer truncation 这一整组 epoll raw-wire truth 现在补齐了

- 新增的 security proof 直接覆盖：
  - truncated trailer section / field-name / separator
  - truncated trailer empty-value / empty-value section
  - truncated trailer whitespace / whitespace section
  - truncated trailer field line / field CR / section CR
- 这说明 trailer parser 的这些 EOF 截断终止点在 epoll live backend 上都能稳定走到显式 `400`，不再只靠 threaded 路径或单个 `section CR` case 外推。

### 2. security 层对 trailer truncation 的 epoll live parity 现在不再只有单点证明

- 此前 `test_http_security` 在 epoll live 路径只有：
  - unsupported transfer-coding
  - invalid chunk size
  - missing chunk-data CRLF
  - truncated trailer section CR
- 这轮之后，trailer truncation 这一族已经基本不再缺 epoll live parity。

### 3. 本轮没有暴露生产缺口，不需要修 transport / parser

- 新增用例直接 GREEN，说明当前 parser + H1 transport 的现有拒绝路径已经自然延伸到 epoll live backend。
- 因此这一批保持为 coverage-expansion；没有新增生产代码，也没有引入新的行为分叉。

### 4. 下一步应继续压缩真正还缺 live parity 的 truncation 边界，而不是回头再做 request-tail 机械 parity

- 既然 request-tail 关键 sibling 已经基本收口，而 trailer truncation 这一轮也补平了一大片，再回头复制已知稳定模式的收益就更低了。
- 更值的下一刀有两个方向：
  - chunk-side truncation 的 epoll live parity 是否还缺成组 sibling
  - 重新筛查 security 是否还有真正未对齐的 malformed raw-wire boundary，而不是继续复制已知稳定模式

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `94/94 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补的是 trailer truncation 的 epoll live parity 缺口，不是把所有 malformed chunked grammar 都复制一遍到 security。
- 本轮没有形成行为级 RED；暴露出来的是 coverage gap，而不是生产缺陷。
- benchmark 继续后置；当前阶段仍以 correctness 和接口契约收口优先。
