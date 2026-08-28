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
| `base` | L0 | root values/contracts | `nextpas.core.base` | RTL, exception root | focused-runtime — `base.utils` adds `CompareBytesOrdered` + `CompareBytesIgnoreCase/HashFNV1aLower` (`LowerTable` 去分支, nil 守卫) unified for respack/vfs/http |
| `bench` | Support | benchmark helpers | `nextpas.core.bench` | explicit test/bench only | source-contract |
| `bytes` | L1 | byte containers | `nextpas.core.bytes` | L0, documented text/encoding seam | focused-runtime |
| `cbor` | L2 | CBOR format (RFC 8949 deterministic subset) | `nextpas.core.cbor` | L0-L1 | focused-runtime |
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
| `http` | L3 | HTTP framework | `nextpas.core.http` | L0-L2 | focused-runtime partial — static pipeline: conditional 304 (weak ETag), single Range 206/416 + `If-Range` (ETag/date) fallback, `HEAD` header-only without stream open, error paths HEAD-aware; `http.mime` O(1) open-address hash (128 槽, FNV-1a, 1-2 探测) + 零分配切片 (`LookupBySlice` 直哈 `PChar` 段, `HttpMimeFromPath` 去 `Copy`) + L0 `HashFNV1aLower/CompareIgnoreCase` 复用 + `HashMimeNorm` 归一，ETag 委托 `vfs.base VfsETagStrong/FNV` 单源（`http` 包装保持 API 兼容，`Cache-Control` 单源 `CACHE_REVALIDATE`，`Content-Disposition` 单遍 `EscapeDispositionFilename`） |
| `id` | L1 | identifiers | `nextpas.core.id` | L0, platform random | focused-runtime |
| `ini` | L2 | INI format | `nextpas.core.ini` | L0-L1 | focused-runtime |
| `io` | L1 | stream/poller/completion | `nextpas.core.io` | L0, platform | focused-runtime, forced-compile |
| `json` | L2 | JSON format | `nextpas.core.json` | L0-L1 | focused-runtime |
| `lockfree` | L1 | lock-free structures | `nextpas.core.lockfree` | L0 | focused-runtime |
| `log` | L3 | logging framework | `nextpas.core.log` | L0-L2, `log.intf` low-level seam | focused-runtime |
| `mail` | L3 | mail domain: message model / RFC5322 address / MIME bridge (depends on mime) / SMTP client + evented SMTP server | `nextpas.core.mail` | L0-L2 plus mime, net.server seams | focused-runtime |
| `math` | L0 | scalar math | `nextpas.core.math` | RTL, base/errors, explicit platform math seams | focused-runtime |
| `mem` | L0 | allocation/pools | `nextpas.core.mem` | L0 only, allowlisted fs/text/os/path debt | focused-runtime, source-contract |
| `mime` | L2 | MIME format (RFC 2045/2046/2047/2231) | `nextpas.core.mime` | L0-L1 plus text/encoding/time; sibling of multipart (mail superset) | focused-runtime |
| `multipart` | L2 | multipart format | `nextpas.core.multipart` | L0-L1, HTTP grammar only | source-contract |
| `net` | L2 | network facade | `nextpas.core.net` | L0-L1, platform net/io | focused-runtime, source-contract |
| `os` | Support | transitional OS facade | `nextpas.core.os` | explicit compatibility only | source-contract |
| `path` | Support | transitional path facade | `nextpas.core.path` | explicit compatibility only | source-contract |
| `platform` | L0 | host ABI and OS semantics | `nextpas.core.platform` | RTL plus owned host base/ffi only | source-contract, forced-compile, focused-runtime |
| `process` | L2 | process execution | `nextpas.core.process` | L0-L1, platform process/pipe/env | focused-runtime, forced-compile |
| `props` | L3 | app property helpers | `nextpas.core.props` | L0-L2 | focused-runtime |
| `reflect` | Support | reflection experiment | `nextpas.core.reflect` | system/typinfo owner only | source-contract |
| `regex` | L2 | regular expressions | `nextpas.core.regex` | L0-L1, optional simd | focused-runtime |
| `respack` | L2 | resource pack container + embed toolchain (asar/Tauri parity) | `nextpas.core.respack` | L0; dirsource is the single fs IO seam; embed adds fs.glob (match-only) via source-contract exception | focused-runtime ×6, source-contract — writer O(n) hash buckets (`BUCKET_MIN` 256→`BUCKET_MAX` 65536, `TryMulSizeUInt` 溢出安全) + `CompareMem` dedup + `CompareBytesOrdered` 路径排序 (L0 unified, `PathLens` 预计算直通消 `Length` 重复, 插入/快排缓存 `Key/Pivot` 指针) , reader single-pass cached `DecodeWire` (50% saving) + `CompareBytesOrdered` 有序块级比对 + `Search` `Pointer(PChar)` 语义统一, `BaseValidPath` via `base.pathvalid` L0 shared |
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
| `vfs` | L2 | read-only virtual filesystem (memtree/embedded/os/sub + facade) | `nextpas.core.vfs` | L0-L1; os backend is the single fs/path seam; embedded adds respack.reader | focused-runtime, source-contract — embedded `FPaths/FEntries/FETags/FLastMods` parallel cache (O(log n) index, O(1) ETag/Last-Modified, zero `DecodeWire`), `TEmbeddedSlice/TEmbeddedSliceStream` 零拷贝+`SpinLock` 16 槽池化 (10k 163ms, `heaptrc 0`)，`List` 零 `Stat` 直填 `FEntries`，`VfsNameCompare` 直通 `base.utils CompareBytesOrdered` + `VfsETagStrong/FNV` 单源消 `embedded/http` 字面量重复，`HasSubtreePath/IndexOfPath` 共用 `LowerBoundPath` + `CompareBytesOrdered` 显式字节序 + `CompareMem` 前缀，移除 `StartsWithPath` 死代码 |
| `webview` | L3 | desktop app shell over system web engines (WebKitGTK/WebView2/WKWebView backends; unified IPC bridge) | `nextpas.core.webview` | L0-L2 plus json owner; platform.dl | focused-runtime, source-contract |
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
