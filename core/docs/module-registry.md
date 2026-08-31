# nextPas Core Module Registry

This registry is the authority for module layer, owner, public facade, allowed
dependency direction, and current truth level. It records evidence; it is not a
completion claim.

## Truth Levels

| Level | Meaning |
| --- | --- |
| `source-contract` | Source, docs, owner boundary, unsupported behavior, or public surface is locked by a focused contract. |
| `forced-compile` | A non-native host/branch compiles, but no runtime behavior is proven. Carrier for platform facades: `test_platform_simulated_host_compile_matrix` (5 legs: darwin/android/freebsd/unix via `-dNEXTPAS_FORCE_HOST_*`, windows via `-Twin64 -Px86_64`; all 29 `platform.*` facades) — compile coherence only. |
| `focused-runtime` | A focused gate ran behavior on a named host or path. Today most L1/L2/L3 are Linux x86_64 focused-runtime by design. |
| `ci-runtime-matrix` | Runtime proof is repeated in CI across the named host/arch matrix (durable). Currently **platform-scoped** only: Windows 28-gate `platform-windows-ci-matrix.sh` on `windows-latest` + macOS layer A 10-gate `platform-macos-ci-matrix.sh`. L2/L3 intentionally remain `focused-runtime` (Linux x86_64); host variance is owned by L0 `platform`. Extensible to L2/L3 via sinking: L2/L3 may add `ci-runtime-matrix` only when they reuse L0 `platform` seams + existing single-sources (`bytes.ops`, `base.utils CompareBytesOrdered/HashFNV1a`, `compress.base` limits) without duplication, keep L0-L3 layering/four-piece, and own a durable CI gate (consumer + job) with inline/zero-copy + resource/异常不丢 evidence; until then `focused-runtime` remains honest. |

> **Host matrix separation (design):** `ci-runtime-matrix` (durable CI runtime) and the simulated-host `forced-compile` matrix are intentionally separate. The simulated-host matrix (`core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix`, 5 legs × all 29 `platform.*` facades) proves compile coherence and stays `forced-compile`; it does **not** promote to `ci-runtime-matrix`. The durable `ci-runtime-matrix` is currently **platform-only** (Windows 28 + macOS 10 platform gates, see `core/docs/platform/runtime-truth-matrix.md` and `core/docs/platform/host-capability-matrix.md`). L2/L3 modules (fs, net, http, vfs, crypto, etc.) therefore correctly show `focused-runtime` on Linux x86_64 in the registry — their host variance is delegated to L0 `platform` via layering, not claimed independently. Promoting any L2/L3 to `ci-runtime-matrix` requires explicit consumer + CI ownership and would be recorded here and in `runtime-truth-matrix.md`. Sinking rule: L2/L3 cross-host proof must sink via L0 `platform` seams (no direct `Windows`/`BaseUnix` FFI, no同层循环), reuse existing single-sources (`bytes.ops`, `base.utils CompareBytesOrdered/HashFNV1aLower`, `compress.base GZIP_MAX`, etc.) without duplication, keep four-piece/L0-L3 layering, and provide durable CI job + inline/zero-copy证据 + `try/finally` 资源释放/异常不丢证据.

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
| `compress` | L2 | compression formats | `nextpas.core.compress` | L0-L1, provider FFI | focused-runtime — `compress.base GZIP_MAX_DECOMPRESS_BYTES=32MiB` 单源（门面重导出，`vfs.compressed VFS_DECOMPRESS_MAX_BYTES` 已收敛为薄别名/薄门面经 `transform` 承载） |
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
| `http` | L3 | HTTP framework | `nextpas.core.http` | L0-L2 | focused-runtime partial — static pipeline: conditional 304 (weak ETag), single Range 206/416 + `If-Range` (ETag/date) fallback, `HEAD` header-only without stream open, error paths HEAD-aware; `http.mime` O(1) open-address hash (128 槽, FNV-1a, 1-2 探测) + 零分配切片 (`LookupBySlice` 直哈 `PChar` 段, `HttpMimeFromPath` 去 `Copy`) + L0 `HashFNV1aLower/CompareIgnoreCase` 复用 + `HashMimeNorm` 归一 + `PChar→@S[1]` 显式化 + `HttpMimeFromExt/FromPath` inline，ETag 委托 `vfs.base VfsETagStrong/FNV` 单源（`http` 包装保持 API 兼容，`Cache-Control` 单源 `CACHE_REVALIDATE`，`Content-Disposition` 单遍 `EscapeDispositionFilename`，`ParseRangeHeader BYTES_PREFIX+TryParseSlice` 零分配，`IsSafePath/TryExtractRequestPath/ExtractFileNameInline/HttpMakeStrongETag` inline（含声明侧 inline），`ServeVfs` nil 守卫 + `IsHeadReq` 复用） |
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
| `respack` | L2 | resource pack container + embed toolchain (asar/Tauri parity) | `nextpas.core.respack` | L0; dirsource is the single fs IO seam; embed adds fs.glob (match-only) via source-contract exception | focused-runtime ×6, source-contract — writer O(n) hash buckets (`BUCKET_MIN` 256→`BUCKET_MAX` 65536, `TryMulSizeUInt` 溢出安全) + `CompareMem` dedup + `CompareBytesOrdered` 路径排序 (L0 unified, `PathLens` 预计算直通消 `Length` 重复, 插入/快排缓存 `Key/Pivot` 指针 + `PChar→@S[1]` 显式化) + 桶追加 2× 预分配 + `BucketCounts` 显式计数（消逐一 `SetLength` 重分配）, reader single-pass cached `DecodeWire` (50% saving) + `CompareBytesOrdered` 有序块级比对 + `Search` `LPtr` 缓存 + `inline` 热路径 + `PChar→@S[1]` 显式化, `BaseValidPath` via `base.pathvalid` L0 shared |
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
| `vfs` | L2 | read-only virtual filesystem (memtree/embedded/os/sub + facade + transform decorator) | `nextpas.core.vfs` | L0-L1; os seam is the single fs/path L2→L2; embedded adds respack.reader; transform/compressed adds compress.base (GZIP_MAX 32MiB 单源) L2→L2 decorator seam | focused-runtime, source-contract — embedded `FPaths/FEntries/FETags/FLastMods` parallel cache (O(log n) index, O(1) ETag/Last-Modified, zero `DecodeWire`), `TEmbeddedSlice/TEmbeddedSliceStream` 零拷贝+`SpinLock` `EMBEDDED_POOL_SIZE` 16 槽池化 (10k 163ms, `heaptrc 0`)，`List` 零 `Stat` 直填 `FEntries`，`VfsNameCompare` 直通 `base.utils CompareBytesOrdered` + `VfsETagStrong/FNV` 单源消 `embedded/http` 字面量重复，`HasSubtreePath/IndexOfPath` 共用 `LowerBoundPath` + `CompareBytesOrdered` 显式字节序 + `CompareMem` 前缀 + `PChar→@S[1]` 显式化 + `LPtr/Llen` 缓存 + `inline` 热路径，移除 `StartsWithPath` 死代码；`transform` 通用字节变换装饰器（`TVfsTransformFunc/TVfsShouldTransformFunc` 函数注入，L3，零拷贝按需变换：`Stat` 单源 `Size/ContentHash` 校正、`OpenRead` 单次 `VfsReadAllBytes` 复用 `LData` 消二次 `FInner.OpenRead` 磁盘 IO（`Should` 假/`Pointer` 未变时 `CreateBytesStreamFrom(LData)` 复用已读缓冲，省一次系统调用）+ `Pointer` 去重、`TryGetETag` 禁用防旧指纹、`TryGetLastModified` 经 `QueryInterface` 透传；`compressed` 为 `transform` 薄门面仅保留策略 `VFS_DECOMPRESS_MAX_BYTES→GZIP_MAX_DECOMPRESS_BYTES` 单源与 `daAuto/daGzip` 语义，`STORE` 零拷贝与 32MiB 防 bomb 由 `transform` 承载，`daAuto` 4K 头部预判避免 `Stat` 全量读取（非 gzip 直接返回内层 `Stat`，省一次 `VfsReadAllBytes`），`bench_transform` 4 项基准固化（`Stat/header-peek 972ns` 等），合规 `nextpas.core.exception` + `QueryInterface` 无 `SysUtils` 直引） |
| `webview` | L3 | desktop app shell over system web engines (WebKitGTK/WebView2/WKWebView backends; unified IPC bridge) | `nextpas.core.webview` | L0-L2 plus json owner; platform.dl | focused-runtime, source-contract — S37 容量与 Fail-Fast 完整性（`IsValidWebviewSchemeToken` 复用 + Builder `GrowInvokes/GrowReady` 2× + Scheme/几何早筛 + `CONTRACT 1.31`） |
| `websocket` | L3 | WebSocket | `nextpas.core.websocket` | L0-L2, HTTP/TLS seams | source-contract |
| `xml` | L2 | XML format | `nextpas.core.xml` | L0-L1 | focused-runtime |
| `yaml` | L2 | YAML format | `nextpas.core.yaml` | L0-L1 | focused-runtime |

## Next Architecture Routes

1. TLS master spec: provider ownership, security evidence, dynamic loading, and
   constant-time requirements.
2. System final facade: TypInfo/SysUtils/Classes decisions tied to real compiler
   and core consumers.
3. Mem L0 debt zero: remove or re-home the allowlisted L0 dependency debt.
4. Platform runtime truth matrix: `runtime-truth-matrix.md` is **platform-scoped** by design
   (20 rows); real host runtime (`ci-runtime-matrix` + `focused-runtime`) stays
   separate from `source-contract`/`forced-compile` (simulated-host 5-leg matrix).
   L2/L3 host truth is owned by L0 `platform` until explicit promotion via
   sinking (L2/L3 `ci-runtime-matrix` requires L0 `platform` seam reuse +
   existing single-source `bytes.ops`/`base.utils`/`compress.base` + durable CI
   gate + inline/zero-copy and `try/finally` evidence; registry +
   `runtime-truth-matrix.md` are the promotion log).
