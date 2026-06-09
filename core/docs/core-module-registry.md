# nextpas.core Module Registry

This registry is the source contract for core module ownership. It records the
top-level module family, not every implementation unit. Sub-unit rules live in
`core/docs/design-conventions.md` and in source-contract gates.

## Truth levels

| Level | Meaning |
| --- | --- |
| `source-contract` | Source/static guards lock the boundary. |
| `forced-compile` | Host-specific compile path is exercised. |
| `focused-runtime` | Focused runtime tests cover the named behavior on a host. |
| `runtime-matrix` | Runtime proof exists across the named host/arch matrix. |
| `draft` | Owner or API is not hardened enough for stronger claims. |

## Registry

| Module | Layer | Owner | Public facade | Allowed dependencies | Truth level |
| --- | --- | --- | --- | --- | --- |
| `args` | L2 | CLI parsing | yes | L0-L1 | focused-runtime |
| `async` | L1 | event loop/runtime | yes | L0 plus approved L1 | source-contract + focused-runtime |
| `atomic` | L0 | atomic primitives | yes | L0 only | focused-runtime |
| `base` | L0 | root types/contracts | yes | `exception`, bootstrap RTL debt | focused-runtime |
| `bench` | tooling | benchmark harness | yes | module consumers | draft |
| `bytes` | L1 | binary buffers | yes | L0 plus encoding/text seam | focused-runtime |
| `collections` | L1 | containers | yes | L0 plus approved L1 | focused-runtime |
| `compress` | L2 | compression formats | yes | L0-L1 | focused-runtime |
| `config` | L3 | configuration framework | yes | L0-L2 | focused-runtime |
| `contracts` | L0 support | assertions/contracts | yes | L0 root | source-contract |
| `cookie` | L2 | HTTP cookie helpers | yes | L0-L1 | focused-runtime |
| `coroutine` | L3 | coroutine scheduler | yes | L0-L2 | focused-runtime |
| `crypto` | L2 | cryptography | yes | L0-L1 plus backend owners | source-contract + focused-runtime |
| `csv` | L2 | CSV parser/writer | yes | L0-L1 | focused-runtime |
| `encoding` | L1 | codecs | yes | L0 plus bytes/text seam | focused-runtime |
| `errors` | L0 | error facade | yes | `exception`, `base` | focused-runtime |
| `event` | L3 | event dispatch | yes | L0-L2 | draft |
| `exception` | L0 root | exception taxonomy | yes | bootstrap RTL | source-contract |
| `fs` | L2 | filesystem | yes | L0-L1; platform owns raw OS truth | focused-runtime |
| `git` | L2 | git/libgit2 backend | yes | L0-L1 plus libgit2 FFI owner | draft |
| `hash` | L2 | hash algorithms | yes | L0-L1 | focused-runtime |
| `http` | L3 | HTTP framework | yes | L0-L2 | focused-runtime |
| `id` | L1 | ID generators | yes | L0-L1 | focused-runtime |
| `ini` | L2 | INI format | yes | L0-L1 | focused-runtime |
| `io` | L1 | stream/poller abstractions | yes | L0 plus approved L1 | focused-runtime |
| `json` | L2 | JSON parser/writer | yes | L0-L1 | focused-runtime |
| `lockfree` | L1 | lock-free structures | yes | L0 plus approved L1 | focused-runtime |
| `log` | L3 | logging runtime | yes | L0-L2; `log.intf` is L0 seam | focused-runtime |
| `math` | L0 | scalar/math contracts | yes | L0 only | focused-runtime |
| `mem` | L0 with debt | allocators/pools | yes | L0 only; explicit debt allowlist | source-contract |
| `multipart` | L2 | multipart format | yes | L0-L1 | focused-runtime |
| `net` | L2 | networking | yes | L0-L1 | focused-runtime |
| `os` | L2 | OS helper namespace | no | L0-L1; platform owns raw OS truth | source-contract |
| `path` | L2 | path helpers | yes | L0-L1 | focused-runtime |
| `platform` | L0 | host ABI and OS semantics | yes | host owner `platform.*.base/ffi`, L0 only | source-contract + focused-runtime |
| `process` | L2 | process management | yes | L0-L1 | focused-runtime |
| `props` | L3 | property helpers | yes | L0-L2 | draft |
| `reflect` | L2 | reflection helpers | yes | L0-L1 | draft |
| `regex` | L2 | regular expressions | yes | L0-L1 | focused-runtime |
| `simd` | L0 accelerator | SIMD and CPU feature seam | yes | L0 only; explicit CPUInfo debt | focused-runtime |
| `sse` | L3 | server-sent events | yes | L0-L2 | draft |
| `stopwatch` | L1 | high-resolution timing | yes | L0-L1 | focused-runtime |
| `sync` | L1 | synchronization | yes | L0 plus approved L1 | focused-runtime |
| `system` | L0 root facade exception | RTL frontier facade | yes | L0 plus explicit text debt | source-contract |
| `template` | L3 | templating | yes | L0-L2 | draft |
| `testing` | L1 | test framework | yes | L0 | focused-runtime |
| `text` | L1 | text/unicode helpers | yes | L0 plus bytes/encoding seam | focused-runtime |
| `thread` | L1 | threads/tasks/channels | yes | L0 plus approved L1 | focused-runtime |
| `time` | L1 | date/time APIs | yes | L0 plus approved L1 | focused-runtime |
| `tls` | L2 | TLS stack/backends | yes | L0-L1 plus explicit backend FFI owners | source-contract + focused-runtime |
| `toml` | L2 | TOML parser/writer | yes | L0-L1 | focused-runtime |
| `tui` | L3 | terminal UI framework | yes | L0-L2 | focused-runtime |
| `validation` | L3 | validation helpers | yes | L0-L2 | draft |
| `websocket` | L3 | websocket framework | yes | L0-L2 | draft |
| `xml` | L2 | XML parser/writer | yes | L0-L1 | focused-runtime |
| `yaml` | L2 | YAML parser/writer | yes | L0-L1 | focused-runtime |

## Gate policy

- L0 boundary gate currently hardens `base`, `errors`, `platform`, `mem`,
  `system`, `atomic`, `math`, and `simd`.
- Raw host units (`Windows`, `BaseUnix`, `Unix`, `DynLibs`, `ctypes`) must appear
  only in owner paths or explicit allowlist entries.
- Any new allowlist entry is a design debt. The landing report must name the
  path, unit/token, reason, and owner route.
