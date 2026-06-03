# Progress Log: http h1 outbound production/drain split

## Session

- **Scope:** 给 `nextpas.core.http` 的 H1 server runtime 补上
  response production / socket drain split，
  为 future poll-driven H1 铺 internal outbound seam，
  但本轮不直接迁 session runtime。
- **Status:** ready-to-commit

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- H1 现在已经不再把 handler output 直接写到 socket；
  当前 connection state 会先收集响应，再统一 drain。
- real-socket stalled-peer/backpressure 的 focused proof 仍然成立，
  但 handler-return timing 不再被当成 public contract。

## Completed work

- 审阅并确认当前缺口：
  - malformed chunked ingress 这一侧已足够强
  - 当前关键缺口已经转到 H1 outbound path
  - 这批不需要扩 public HTTP API
- 先承接 RED：
  - `test_http_h1writer` 先证明 outbound buffer seam 缺失
  - `test_http_server` 暴露 real-socket backpressure 与旧 direct-write timing 断言冲突
- 在 `src/nextpas.core.http.impl.h1.outbound.pas` 落地：
  - `IH1OutboundBuffer`
  - `DrainAllTo`
  - `TryDrainTo`
  - pending / reset helper
- 在 `src/nextpas.core.http.impl.h1.pas` 落地：
  - 移除 per-connection socket buffered writer 常驻字段
  - 改为 per-response outbound buffer + buffered response writer
  - handler 返回后统一 flush + drain
  - committed response exception 路径保留 best-effort flush/drain
- 在 focused tests 落地 / 校正：
  - `tests/nextpas.core.http/test_http_h1writer`
    - short writer drain-all
    - would-block resumable drain
  - `tests/nextpas.core.http/test_http_server`
    - real-socket backpressure proof 改为锁 safe-close / no-follow-up-consume，
      不再锁 direct-write 时代的 handler-return timing
- 在文档落地：
  - `docs/http/ARCHITECTURE.md`
  - `docs/http/API_COVERAGE.md`

## Verification

- `make -C tests/nextpas.core.http/test_http_h1writer clean test`
  - `26/26 passed`
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `112/112 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- 直接进入 H1 outbound path 的剩余硬骨头：
  - 给 outbound queue 加容量治理，不再长期停在 whole-response buffering
  - 把 `TryDrainTo` 接进真实 runtime
  - 让 `TH1ServerConnectionState` 真正迁到 poll-driven session path
