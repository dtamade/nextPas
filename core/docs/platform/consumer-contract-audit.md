# Platform Consumer Contract Audit

This audit splits platform consumer truth into readiness and completion lanes.
It prevents "Windows poller" from hiding unrelated reactor/completion work.

## Readiness lane

Consumers:

- `nextpas.core.net.server.readiness`
- `nextpas.core.net.server.runtime`
- `nextpas.core.io.poller`

Contracts:

- `platform_poller_*` is readiness-only.
- Wake userdata, listener userdata, and session userdata are distinct.
- Empty-interest re-entry is legal.
- Worker completion wakes the reactor; it does not advance the session directly.
- Cleanup order for unregister/remove/close is part of the contract.

### Current readiness truth (2026-07-21)

| Host | Tier | Scope |
|------|------|--------|
| Linux | focused-runtime | platform/io + consumer gates |
| Windows | **ci-matrix** (documented **28** platform gates) + wine **25** secondary | Includes poller/iocp + console; **not** full-host parity |
| macOS | focused-runtime layer A (**9** platform gates) | Fail-closed `platform-macos-ci-matrix.sh` only; whole job is not platform evidence |

Wine is forever `wine-runtime-smoke` and never substitutes for real Windows `ci-matrix`.

## Completion lane

Consumers:

- `nextpas.core.async.loop`
- `nextpas.core.io.reactor.iocp`
- future completion adapters

Contracts:

- Rejected submissions are cleaned by the wrapper.
- Inline callback or queued completion means ownership transferred.
- Unsupported IOCP operations return explicit unsupported/rejected truth and
  must not look like successful pending work.
- Closed loop/reactor submissions fail before new timeout/context ownership is
  created.
- `pbIocp`, `pbUnsupported`, `IsValid`, `Poll`, `Stop`, and async operation
  returns are consumer-visible contract.

Completion depth beyond documented smokes (e.g. AcceptEx/ConnectEx residual)
is owned with **io/net-async**, not as a blanket platform facade claim.

## Console / TUI consumer note

- `nextpas.core.tui` depends on `platform.console` (+ signal for SIGWINCH/SIGTERM on POSIX).
- `platform.console` is on wine secondary matrix (**25**) and promoted Windows
  **`ci-matrix` 28 platform gates** as facade smoke (hard value/sentinel asserts after F-001/F-003).
- **read/write**: success `>=0` bytes, failure **`-1`** (TUI `Result = LLen` remains safe).
- Darwin/FreeBSD: termios path implemented (F-002); macOS matrix lists console as **candidate** only.
- Windows true-console TUI remains tui-lane product work.
- **Cancellation** (F-020): not an L0 platform primitive; net/http/async own cancel tokens.

## Current route

1. Keep readiness/completion split honest.
2. Expand Windows/macOS matrices only with consumer pain + one-gate ladder.
3. Do not promote full-host Windows or macOS parity from wine or partial matrices.
4. No new dual-IO call sites; no process/socket/sync split without a dedicated batch.

Deferred: FreeBSD/Android device runtime, D5 fuzz as truth language, dual-IO sunset,
freetype/x11 move-out (independent lane).
