# nextPas Core Module Registry

This registry is the authority for module layer, owner, public facade, allowed
dependency direction, and current truth level. It records evidence; it is not a
completion claim.

## Truth Levels

| Level | Meaning |
| --- | --- |
| `source-contract` | Source, docs, owner boundary, unsupported behavior, or public surface is locked by a focused contract. |
| `forced-compile` | A non-native host/branch compiles, but no runtime behavior is proven. |
| `focused-runtime` | A focused gate ran behavior on a named host or path. |
| `ci-runtime-matrix` | Runtime proof is repeated in CI across the named host/arch matrix. |

## Registry

| module | layer | owner | public facade | allowed dependencies | truth level |
| --- | --- | --- | --- | --- | --- |
| `args` | L3 | CLI surface | `nextpas.core.args` | L0-L2 | focused-runtime |
| `async` | L1 | async loop/runtime | `nextpas.core.async` | L0 plus `io/time` seams | focused-runtime, forced-compile |
| `atomic` | L0 | atomic primitives | `nextpas.core.atomic` | RTL, base/errors/platform sync only | focused-runtime, source-contract |
| `base` | L0 | root values/contracts | `nextpas.core.base` | RTL, exception root | focused-runtime |
| `bench` | Support | benchmark helpers | `nextpas.core.bench` | explicit test/bench only | source-contract |
| `bytes` | L1 | byte containers | `nextpas.core.bytes` | L0, documented text/encoding seam | focused-runtime |
| `collections` | L1 | data structures | `nextpas.core.collections` | L0 | focused-runtime |
| `compress` | L2 | compression formats | `nextpas.core.compress` | L0-L1, provider FFI | focused-runtime |
| `config` | L3 | config facade | `nextpas.core.config` | L0-L2 formats | focused-runtime |
| `contracts` | L0 | assertion helpers | `nextpas.core.contracts` | base/errors | focused-runtime |
| `cookie` | L2 | cookie grammar | `nextpas.core.cookie` | L0-L1 | source-contract |
| `coroutine` | L3 | coroutine framework | `nextpas.core.coroutine` | L0-L2 | focused-runtime |
| `crypto` | L2 | crypto primitives | `nextpas.core.crypto` | L0-L1, audited provider seams | focused-runtime partial |
| `csv` | L2 | CSV format | `nextpas.core.csv` | L0-L1 | focused-runtime |
| `encoding` | L1 | encoding primitives | `nextpas.core.encoding` | L0, documented bytes/text seam | focused-runtime |
| `errors` | L0 | error taxonomy | `nextpas.core.errors` | RTL exception bridge, base/exception | focused-runtime |
| `event` | L3 | event bus | `nextpas.core.event` | L0-L2 | focused-runtime |
| `exception` | L0 | exception root | `nextpas.core.exception` | RTL only | focused-runtime |
| `fs` | L2 | filesystem facade | `nextpas.core.fs` | L0-L1, platform/files/path | focused-runtime |
| `git` | L2 | git/libgit2 | `nextpas.core.git` | L0-L1, libgit2 FFI allowlist | source-contract |
| `hash` | L2 | hash/digest | `nextpas.core.hash` | L0-L1 | focused-runtime |
| `http` | L3 | HTTP framework | `nextpas.core.http` | L0-L2 | focused-runtime partial |
| `id` | L1 | identifiers | `nextpas.core.id` | L0, platform random | focused-runtime |
| `ini` | L2 | INI format | `nextpas.core.ini` | L0-L1 | focused-runtime |
| `io` | L1 | stream/poller/completion | `nextpas.core.io` | L0, platform | focused-runtime, forced-compile |
| `json` | L2 | JSON format | `nextpas.core.json` | L0-L1 | focused-runtime |
| `lockfree` | L1 | lock-free structures | `nextpas.core.lockfree` | L0 | focused-runtime |
| `log` | L3 | logging framework | `nextpas.core.log` | L0-L2, `log.intf` low-level seam | focused-runtime |
| `math` | L0 | scalar math | `nextpas.core.math` | RTL, base/errors, explicit platform math seams | focused-runtime |
| `mem` | L0 | allocation/pools | `nextpas.core.mem` | L0 only, allowlisted fs/text/os/path debt | focused-runtime, source-contract |
| `multipart` | L2 | multipart format | `nextpas.core.multipart` | L0-L1, HTTP grammar only | source-contract |
| `net` | L2 | network facade | `nextpas.core.net` | L0-L1, platform net/io | focused-runtime, source-contract |
| `os` | Support | transitional OS facade | `nextpas.core.os` | explicit compatibility only | source-contract |
| `path` | Support | transitional path facade | `nextpas.core.path` | explicit compatibility only | source-contract |
| `platform` | L0 | host ABI and OS semantics | `nextpas.core.platform` | RTL plus owned host base/ffi only | source-contract, forced-compile, focused-runtime |
| `process` | L2 | process execution | `nextpas.core.process` | L0-L1, platform process/pipe/env | focused-runtime, forced-compile |
| `props` | L3 | app property helpers | `nextpas.core.props` | L0-L2 | focused-runtime |
| `reflect` | Support | reflection experiment | `nextpas.core.reflect` | system/typinfo owner only | source-contract |
| `regex` | L2 | regular expressions | `nextpas.core.regex` | L0-L1, optional simd | focused-runtime |
| `simd` | L0 | SIMD ABI/backends | `nextpas.core.simd` | L0, platform CPU/file probes, allowlisted host/os probes | focused-runtime, source-contract |
| `sse` | Support | legacy SIMD surface | `nextpas.core.sse` | simd owner only | source-contract |
| `stopwatch` | L1 | timing helper | `nextpas.core.stopwatch` | L0, platform time | focused-runtime |
| `sync` | L1 | synchronization wrappers | `nextpas.core.sync` | L0, platform sync | focused-runtime |
| `system` | L0 | nextPas system facade | `nextpas.core.system` | base/errors/exception plus allowlisted text debt | source-contract, focused-runtime |
| `template` | L3 | templates | `nextpas.core.template` | L0-L2 | source-contract |
| `testing` | L1 | test framework | `nextpas.core.testing` | L0 | focused-runtime |
| `text` | L1 | text/Unicode | `nextpas.core.text` | L0, documented encoding seam | focused-runtime |
| `thread` | L1 | thread abstractions | `nextpas.core.thread` | L0, platform thread/sync | focused-runtime |
| `time` | L1 | duration/date/time | `nextpas.core.time` | L0, platform time | focused-runtime |
| `tls` | L2 | TLS providers/protocol | `nextpas.core.tls` | L0-L1, provider FFI allowlist | source-contract, focused-runtime fragments |
| `toml` | L2 | TOML format | `nextpas.core.toml` | L0-L1 | focused-runtime |
| `tui` | L3 | terminal UI | `nextpas.core.tui` | L0-L2 | focused-runtime partial |
| `validation` | L2 | validation helpers | `nextpas.core.validation` | L0-L1 | focused-runtime |
| `websocket` | L3 | WebSocket | `nextpas.core.websocket` | L0-L2, HTTP/TLS seams | source-contract |
| `xml` | L2 | XML format | `nextpas.core.xml` | L0-L1 | focused-runtime |
| `yaml` | L2 | YAML format | `nextpas.core.yaml` | L0-L1 | focused-runtime |

## Next Architecture Routes

1. TLS master spec: provider ownership, security evidence, dynamic loading, and
   constant-time requirements.
2. System final facade: TypInfo/SysUtils/Classes decisions tied to real compiler
   and core consumers.
3. Mem L0 debt zero: remove or re-home the allowlisted L0 dependency debt.
4. Platform runtime truth matrix: real host runtime evidence stays separate from
   source-contract and forced-compile truth.
