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

Current truth is Linux focused-runtime plus source-contract tests. Windows
readiness consumer proof remains source/compile truth until real Windows runtime
gates exist.

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

## Current route

1. Closed timeout owner boundary.
2. Submit failure owner boundary.
3. Close/run wake handoff and drain ownership.
4. File read/write lifecycle proof.
5. Real Windows runtime only after source/compile contracts are stable.

Deferred: Windows runtime-ready claims, socket completion publication,
Darwin/Android runtime completion proof, benchmarks, and unrelated facade
rewrites.
