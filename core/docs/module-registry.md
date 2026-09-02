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
| `ci-runtime-matrix` | Runtime proof is repeated in CI across the named host/arch matrix (durable). Currently **platform-scoped** only: Windows 28-gate `platform-windows-ci-matrix.sh` on `windows-latest` + macOS layer A 10-gate `platform-macos-ci-matrix.sh`. L2/L3 intentionally remain `focused-runtime` (Linux x86_64); host variance is owned by L0 `platform`. |

> **Host matrix separation (design):** `ci-runtime-matrix` (durable CI runtime) and the simulated-host `forced-compile` matrix are intentionally separate. The simulated-host matrix (`core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix`, 5 legs × all 29 `platform.*` facades) proves compile coherence and stays `forced-compile`; it does **not** promote to `ci-runtime-matrix`. The durable `ci-runtime-matrix` is currently **platform-only** (Windows 28 + macOS 10 platform gates, see `core/docs/platform/runtime-truth-matrix.md` and `core/docs/platform/host-capability-matrix.md`). L2/L3 modules (fs, net, http, vfs, crypto, etc.) therefore correctly show `focused-runtime` on Linux x86_64 in the registry — their host variance is delegated to L0 `platform` via layering, not claimed independently. Promoting any L2/L3 to `ci-runtime-matrix` requires explicit consumer + CI ownership and would be recorded here and in `runtime-truth-matrix.md`.

## Registry

| module | layer | owner | public facade | allowed dependencies | truth level |
| --- | --- | --- | --- | --- | --- |
| `args` | L2 | CLI surface | `nextpas.core.args` | L0-L1 | focused-runtime |
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
| `cookie` | L2 | cookie grammar | `nextpas.core.cookie` | L0-L1 | focused-runtime — `test_cookie` 17/17 `heaptrc 0`, `IsValidCookieName/Value` + `Build/Parse` inline, 零拷贝 `TryFindCookie`, `base.utils CompareBytesIgnoreCase` 单源复用 |
| `coroutine` | L3 | coroutine framework | `nextpas.core.coroutine` | L0-L2 | focused-runtime |
| `crypto` | L2 | crypto primitives | `nextpas.core.crypto` | L0-L1, audited provider seams | focused-runtime — `test_crypto` 35/35 + `test_aesgcm/chacha20/ed25519/p256` gates `heaptrc 0`, `bytes.ops` 常量时间 `CompareBytes` 单源, inline 热路径, 零拷贝 |
| `csv` | L2 | CSV format | `nextpas.core.csv` | L0-L1 | focused-runtime |
| `db` | L3 | unified database family (IDbConnection over sqlite/pg/mysql/odbc/redis, backends at db.sqlite/db.pg) | `nextpas.core.db` | L0-L2 | focused-runtime |
| `encoding` | L1 | encoding primitives | `nextpas.core.encoding` | L0, documented bytes/text seam | focused-runtime |
| `errors` | L0 | error taxonomy | `nextpas.core.errors` | RTL exception bridge, base/exception | focused-runtime |
| `event` | L3 | event bus | `nextpas.core.event` | L0-L2 | focused-runtime |
| `exception` | L0 | exception root | `nextpas.core.exception` | RTL only | focused-runtime |
| `fs` | L2 | filesystem facade | `nextpas.core.fs` | L0-L1, platform/files/path | focused-runtime |
| `git` | L2 | git/libgit2 | `nextpas.core.git` | L0-L1, libgit2 FFI allowlist | focused-runtime — `test_git/test_git_bindings/test_git_native` 30+ `heaptrc 0`, `bytes.ops` 零拷贝 patch/diff/blame, inline `TryFind`, 资源 `FreeAndNil/try-finally` 不丢 |
| `hash` | L2 | hash/digest | `nextpas.core.hash` | L0-L1 | focused-runtime |
| `http` | L3 | HTTP framework | `nextpas.core.http` | L0-L2 | focused-runtime — static pipeline: conditional 304 (weak ETag), single Range 206/416 + `If-Range` (ETag/date) fallback, `HEAD` header-only without stream open, error paths HEAD-aware; `http.mime` O(1) open-address hash (128 槽, FNV-1a, 1-2 探测) + 零分配切片 (`LookupBySlice` 直哈 `PChar` 段, `HttpMimeFromPath` 去 `Copy`) + L0 `HashFNV1aLower/CompareIgnoreCase` 复用 + `HashMimeNorm` 归一 + `PChar→@S[1]` 显式化 + `HttpMimeFromExt/FromPath` inline，ETag 委托 `vfs.base VfsETagStrong/FNV` 单源（`http` 包装保持 API 兼容，`Cache-Control` 单源 `CACHE_REVALIDATE`，`Content-Disposition` 单遍 `EscapeDispositionFilename`，`ParseRangeHeader BYTES_PREFIX+TryParseSlice` 零分配，`IsSafePath/TryExtractRequestPath/ExtractFileNameInline/HttpMakeStrongETag` inline（含声明侧 inline），`ServeVfs` nil 守卫 + `IsHeadReq` 复用） `test_http_*` 47 gate `heaptrc 0` |
| `id` | L1 | identifiers | `nextpas.core.id` | L0, platform random | focused-runtime |
| `ini` | L2 | INI format | `nextpas.core.ini` | L0-L1 | focused-runtime |
| `io` | L1 | stream/poller/completion | `nextpas.core.io` | L0, platform | focused-runtime, forced-compile |
| `json` | L2 | JSON format | `nextpas.core.json` | L0-L1 | focused-runtime |
| `js` | L2 | JS execution engine (QuickJS FFI + pure Pascal js888/v8/chakra) | `nextpas.core.js` | L0-L1 plus json/text.view/mem + platform.dl (loader only) | focused-runtime, source-contract — `test_js_base/fake/js888/v8/chakra` 5 gates `heaptrc 0` (`test_js_quickjs_runtime` SKIP/fail-closed when no `libquickjs`), `bytes.ops` 单源 `SpanEqual/Compare` via `text.view` 零拷贝 `TStringView` + `pure.base` 481 行单源, inline 热点 `JsPureFindHostView/JsPureNew*` + `PureHeap` `Move` 零拷贝 (`JsTrimEquals` 零拷贝单遍但按 `design-conventions §2` 去 `inline`：真实 `while/for` 扫描禁内联，避 I-Cache 膨胀), 资源 `try-finally/JsPureClose/FreeAndNil` 不丢 |
| `lockfree` | L1 | lock-free structures | `nextpas.core.lockfree` | L0 | focused-runtime |
| `log` | L3 | logging framework | `nextpas.core.log` | L0-L2, `log.intf` low-level seam | focused-runtime |
| `mail` | L3 | mail domain: message model / RFC5322 address / MIME bridge (depends on mime) / SMTP client + evented SMTP server | `nextpas.core.mail` | L0-L2 plus mime, net.server seams | focused-runtime |
| `math` | L0 | scalar math | `nextpas.core.math` | RTL, base/errors, explicit platform math seams | focused-runtime |
| `mem` | L0 | allocation/pools | `nextpas.core.mem` | L0 only, allowlisted fs/text/os/path debt | focused-runtime, source-contract |
| `mime` | L2 | MIME format (RFC 2045/2046/2047/2231) | `nextpas.core.mime` | L0-L1 plus text/encoding/time; sibling of multipart (mail superset) | focused-runtime |
| `multipart` | L2 | multipart format | `nextpas.core.multipart` | L0-L1, HTTP grammar only | focused-runtime — `test_multipart` 13/13 `heaptrc 0`, `bytes.ops SpanIndexOf/StringToBytes` 单源, inline `TryParse/ExtractBoundary`, 零拷贝 `Move` Body |
| `net` | L2 | network facade | `nextpas.core.net` | L0-L1, platform net/io | focused-runtime, source-contract |
| `os` | Support | transitional OS facade | `nextpas.core.os` | explicit compatibility only | source-contract |
| `path` | Support | transitional path facade | `nextpas.core.path` | explicit compatibility only | source-contract |
| `platform` | L0 | host ABI and OS semantics | `nextpas.core.platform` | RTL plus owned host base/ffi only | source-contract, forced-compile, focused-runtime |
| `process` | L2 | process execution | `nextpas.core.process` | L0-L1, platform process/pipe/env | focused-runtime, forced-compile |
| `props` | L3 | app property helpers | `nextpas.core.props` | L0-L2 | focused-runtime |
| `reflect` | Support | reflection experiment | `nextpas.core.reflect` | system/typinfo owner only | source-contract |
| `regex` | L2 | regular expressions | `nextpas.core.regex` | L0-L1, optional simd | focused-runtime |
| `embed` | L1 | embedding carrier thresholds (typed const <4MiB, EmbedRequireIncSize/ResPackRequireIncSize/EffectiveLimit inline zero-copy, MaxBlobBytes configurable) — independent strategy module extracted from respack.limits (S6); units `nextpas.core.embed.limits` + facade `nextpas.core.embed` (L1, other carriers reusable; `respack.limits` is compatible forwarding) | `nextpas.core.embed` | L0 only (base/exception) | source-contract |
| `respack` | L2 | resource pack container + embed toolchain (asar/Tauri parity) | `nextpas.core.respack` | L0-L1; dirsource is the single fs IO seam (L2→L2 documented, source-contract gated like vfs.os); embed is L1 text.strings/text.char/text.conv single source (GlobMatch via text.strings + IsAlpha/IsAlphaNum via text.char + IntToStr via text.conv; inline + PChar zero-copy view + O(pat×name) dual-tracker, fs.glob thin forward; bytes.ops CompareBytesOrdered single source) + `embed.limits` independent L1 strategy (inline zero-copy EmbedRequireIncSize/EffectiveLimit, MaxBlobBytes configurable, `respack.limits` compatible forwarding) | focused-runtime ×6, source-contract — writer O(n) hash buckets (`BUCKET_MIN` 256→`BUCKET_MAX` 65536, `TryMulSizeUInt` 溢出安全) + `CompareMem` dedup + `CompareBytesOrdered` 路径排序 (L0 unified, `PathLens` 预计算直通消 `Length` 重复, 插入/快排缓存 `Key/Pivot` 指针 + `PChar→@S[1]` 显式化) + 桶追加 2× 预分配 + `BucketCounts` 显式计数（消逐一 `SetLength` 重分配）, reader single-pass cached `DecodeWire` (50% saving) + `CompareBytesOrdered` 有序块级比对 + `Search` `LPtr` 缓存 + `inline` 热路径 + `PChar→@S[1]` 显式化, `BaseValidPath` via `base.pathvalid` L0 shared; embed GlobMatch/IsAlpha/IntToStr via L1 single source (text.strings/text.char/text.conv) with inline zero-copy PChar view |
| `simd` | L0 | SIMD ABI/backends | `nextpas.core.simd` | L0, platform CPU/file probes, allowlisted host/os probes | focused-runtime, source-contract |
| `sse` | Support | legacy SIMD surface | `nextpas.core.sse` | simd owner only | source-contract |
| `stopwatch` | L1 | timing helper | `nextpas.core.stopwatch` | L0, platform time | focused-runtime |
| `sync` | L1 | synchronization wrappers | `nextpas.core.sync` | L0, platform sync | focused-runtime |
| `system` | L0 | nextPas system facade | `nextpas.core.system` | base/errors/exception plus allowlisted text debt | source-contract, focused-runtime |
| `template` | L3 | templates | `nextpas.core.template` | L0-L2 | focused-runtime — `test_template` 80+/80+ `heaptrc 0`, inline `Eval/RenderSegment`, 零拷贝 `Slice`, 资源 `try-finally` 恢复 `ALocalCount/Prefix` 不丢 |
| `testing` | L1 | test framework | `nextpas.core.testing` | L0 | focused-runtime |
| `text` | L1 | text/Unicode | `nextpas.core.text` | L0, documented encoding seam | focused-runtime |
| `thread` | L1 | thread abstractions | `nextpas.core.thread` | L0, platform thread/sync | focused-runtime |
| `time` | L1 | duration/date/time | `nextpas.core.time` | L0, platform time | focused-runtime |
| `tls` | L2 | TLS providers/protocol | `nextpas.core.tls` | L0-L1, provider FFI allowlist | focused-runtime — `test_tls_*` + `test_crypto` 联合门禁 `heaptrc 0`, `bytes.ops` 单源 `SpanCompare/Equal`, inline `TryHandshake`, 零拷贝 record, provider `try-finally` 释放不丢 |
| `toml` | L2 | TOML format | `nextpas.core.toml` | L0-L1 | focused-runtime |
| `tui` | L3 | terminal UI | `nextpas.core.tui` | L0-L2 | focused-runtime — `test_tui_*` 100+ gates `heaptrc 0`, `bytes.ops` 零拷贝 `SpanEqual/Reverse`, inline `Cell/Style`, `platform` 抽象单源 |
| `validation` | L2 | validation helpers | `nextpas.core.validation` | L0-L1 | focused-runtime |
| `vfs` | L2 | read-only virtual filesystem (memtree/embedded/os/sub/mount/overlay/cache + facade + decorator 聚合（transform/compressed L3 单缝装饰器经 decorator 单点收口、门面扇出收敛 13→12）) | `nextpas.core.vfs` | L0-L1; 双缝白名单过渡期超越单缝理想需L7聚合拆分：os 单缝 fs/path L2→L2 保留，embedded second seam respack.reader via bytes.ops 单源 inline 零拷贝 + SpinLock try-finally 资源不丢，L7聚合拆分为 nextpas.core.vfs.* 后端独立族后移除额外白名单固化 L0—L3 单向单缝理想（source-contract gated，line 14）; mount/overlay pure composite zero extra deps; decorator 聚合 transform/compressed: L3 单缝装饰器族经 decorator 单点收口（门面扇出收敛 13→12，Registry 单缝白名单过渡，L7 独立族按需演进后移除白名单，单源决策器单流 4K HeaderPred + 大文件栈上 2 字节轻量预判零堆分配免 4K + GZIP_MAX 32MiB 对齐 canonical（base 为唯一字面量，compressed 经 vfs.base 单源别名复用不再双写，无直接 compress.base 依赖）+ bytes.ops inline 零拷贝单源、4K HeaderPred 统一（impl 私有 4096 单源，接口不暴露，compressed 数值对齐无别名），泛型路径输入/输出双 32MiB 防 bomb 统一） | focused-runtime, source-contract — embedded `FPaths/FEntries/FETags/FLastMods` parallel cache (O(log n) index, O(1) ETag/Last-Modified, zero `DecodeWire`), `TEmbeddedSlice/TEmbeddedSliceStream` 零拷贝+`SpinLock` `EMBEDDED_POOL_SIZE` 64 槽池化 (10k 163ms, `heaptrc 0`，百并发阈值覆盖 inline热路径)，`List` 零 `Stat` 直填 `FEntries`，`VfsNameCompare` 直通 `base.utils CompareBytesOrdered` + `VfsETagStrong/FNV` 单源消 `embedded/http` 字面量重复，`HasSubtreePath/IndexOfPath` 共用 `LowerBoundPath` + `CompareBytesOrdered` 显式字节序 + `CompareMem` 前缀 + `PChar→@S[1]` 显式化 + `LPtr/Llen` 缓存 + `inline` 热路径，`mount` 前缀最长匹配聚合+`overlay` 同根优先级叠加 patch>dlc>base（游戏热更，List去重合并，ETag优先透传）；`transform` L3 单缝通用变换装饰器（`TVfsTransformFunc/TVfsShouldTransformFunc/TVfsHeaderPredicateFunc` 函数注入，单源决策器 TryResolveViaHeaderSingleStream 单流 inline 零拷贝：`Stat` 单流 4K HeaderPred 免大文件全量（非变换回 FInner.Stat，小文件复用 Header 零二次 IO，大文件同流 IReaderAt/Seek 补读免二次 OpenRead，栈上 2 字节零堆分配预判）、`OpenRead` HeaderPred 假时零物化直透 `FInner.OpenRead`（零拷贝无 materialize，栈上 2 字节 peek ~数百 ns）、真时单流 Move 4K 头+同流补读、`TryGetETag` 禁用、`TryGetLastModified` 经 `QueryInterface` 透传，`inline` 热路径+`try-finally` Close 不丢，泛型路径输入/输出双 32MiB 防 bomb 统一；`compressed` 为 `transform` 薄门面（单缝寄居正名，Registry 白名单过渡，L7 聚合拆分）仅保留策略 `VFS_DECOMPRESS_MAX_BYTES` 单源别名复用 vfs.base 32MiB（canonical 寄居 compress.base GZIP_MAX，base 唯一字面量，漂移由 source-contract 别名单源锁定）与 `daAuto/daGzip` + bytes.ops inline 零拷贝单源、4K HeaderPred 统一（impl 私有 4096 单源，接口不暴露，compressed 数值对齐无别名），`STORE` 零拷贝与 32MiB 防 bomb 由 `transform` 统一承载（泛型/压缩一致），`daAuto` 单流 4K 头预判免 Stat 全量读，`bench_transform` 4 项基准固化，合规 `nextpas.core.exception` + `QueryInterface` 无 `SysUtils` 直引） |
| `webview` | L3 | desktop app shell over system web engines (WebKitGTK/WebView2/WKWebView backends; unified IPC bridge) | `nextpas.core.webview` | L0-L2 plus json owner; platform.dl | focused-runtime, source-contract — S37 容量与 Fail-Fast 完整性（`IsValidWebviewSchemeToken` 复用 + Builder `GrowInvokes/GrowReady` 2× + Scheme/几何早筛 + `CONTRACT 1.31`） |
| `websocket` | L3 | WebSocket | `nextpas.core.websocket` | L0-L2, HTTP/TLS seams | focused-runtime — `test_websocket` 17/17 + `test_http_websocket*` 3 gates `heaptrc 0`, `bytes.ops/base64/sha1` 单源, inline `TryDecode/Mask`, 零拷贝 `Payload Move` |
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
   L2/L3 host truth is owned by L0 `platform` until explicit promotion.
