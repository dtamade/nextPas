# nextPas Core Module Registry — Deprecated Alias

> **Deprecated.** The canonical L0–L3 registry is `core/docs/core-module-registry.md`.
> This file is retained for backward compatibility and mirrors the canonical table.
> Do not update this file independently; update `core-module-registry.md` and sync
> this mirror if needed. The single source of truth for L0–L3 layer, owner, and
> truth level is `core-module-registry.md` (see `core/docs/design-conventions.md §15`).
> `ci-runtime-matrix` below is the alias of canonical `ci-matrix`.

This registry previously was the authority for module layer, owner, public facade, allowed
dependency direction, and current truth level. It now mirrors the canonical registry
and records evidence; it is not a completion claim.

## Truth Levels

| Level | Meaning |
| --- | --- |
| `source-contract` | Source, docs, owner boundary, unsupported behavior, or public surface is locked by a focused contract. |
| `forced-compile` | A non-native host/branch compiles, but no runtime behavior is proven. Carrier for platform facades: `test_platform_simulated_host_compile_matrix` (5 legs: darwin/android/freebsd/unix via `-dNEXTPAS_FORCE_HOST_*`, windows via `-Twin64 -Px86_64`; all 29 `platform.*` facades) — compile coherence only. |
| `focused-runtime` | A focused gate ran behavior on a named host or path. Today most L1/L2/L3 are Linux x86_64 focused-runtime by design. |
| `ci-runtime-matrix` | Runtime proof is repeated in CI across the named host/arch matrix (durable). Currently **platform-scoped** only: Windows 28-gate `platform-windows-ci-matrix.sh` on `windows-latest` + macOS layer A 10-gate `platform-macos-ci-matrix.sh`. L2/L3 intentionally remain `focused-runtime` (Linux x86_64); host variance is owned by L0 `platform`. Canonical name is `ci-matrix` in `core-module-registry.md`. |

> **Host matrix separation (design):** `ci-runtime-matrix` (durable CI runtime) and the simulated-host `forced-compile` matrix are intentionally separate. The simulated-host matrix (`core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix`, 5 legs × all 29 `platform.*` facades) proves compile coherence and stays `forced-compile`; it does **not** promote to `ci-runtime-matrix`. The durable `ci-runtime-matrix` is currently **platform-only** (Windows 28 + macOS 10 platform gates, see `core/docs/platform/runtime-truth-matrix.md` and `core/docs/platform/host-capability-matrix.md`). L2/L3 modules (fs, net, http, vfs, crypto, etc.) therefore correctly show `focused-runtime` on Linux x86_64 in the registry — their host variance is delegated to L0 `platform` via layering, not claimed independently. Promoting any L2/L3 to `ci-runtime-matrix` requires explicit consumer + CI ownership and would be recorded here and in `runtime-truth-matrix.md`.

## Registry

| module | layer | owner | public facade | allowed dependencies | truth level |
| --- | --- | --- | --- | --- | --- |
| `args` | L2 | CLI surface | `nextpas.core.args` | L0-L1 | focused-runtime |
| `async` | L1 | async loop/runtime | `nextpas.core.async` | L0 plus `io/time` seams | focused-runtime, forced-compile |
| `atomic` | L0 | atomic primitives | `nextpas.core.atomic` | RTL, base/errors/platform sync only | focused-runtime, source-contract |
| `audio` | L2 | audio subsystem (decode-first): 87 files = 31 core (26冻结 + wav四件套3 + pcm_wav四件套2) + 56 ext 已抽8独立L2；核心仅聚合26真值源、L2→L2禁依赖、扩展独立演进、门面 thin `type`+`inline`零拷贝 | `nextpas.core.audio` | L0-L1 (io/fs owner) plus `bytes.ops` single-source (`Move`/`BytesEnsureCapacity`/`AudioEnsureCapacity` inline零拷贝) + `sync` + `simd` L0 (`SimdAddF32` via audio.simd→simd.cpuinfo) ; 扩展 codec/spatial/bus/bank/resource/playlist/event/studio/simd 不经 audio门面直引 (L2→L2禁依赖, 受控seam需登记) | focused-runtime |
| `audio.bus` | L2 | audio bus/mixer (IAudioBus B:C00000000001 / IAudioBusMixer B:C00000000002, bus.base/intf/impl/pas 四件套, TAudioBus/TAudioBusMixer 快照混音, SimdAddF32复用) | `nextpas.core.audio.bus` | L0-L1 plus audio.base/intf core types (TAudioFormat/TAudioBuffer/IRealtimeAudioSource) + `bytes.ops` single-source (`AudioEnsureCapacity`+`BytesZero/BytesCopy`, 无自写Move) + `sync` (`IMutex`) + `simd` L0 (`SimdAddF32` via audio.simd→simd.cpuinfo 单源8-wide/4-wide, inline+vzeroupper) + `base`/`errors` L0 ; audio根门面不直引bus (L2→L2禁依赖, registry+gate) | focused-runtime, source-contract — `test_bus` 8/8 `heaptrc 0`, `EnsureScratch/EnsureSnapshotCapacity` inline几何预分配稳态零堆增长, 两阶段快照零拷贝`SimdAddF32`, `try..finally`释放不丢 |
| `base` | L0 | root values/contracts | `nextpas.core.base` | RTL, exception root | focused-runtime — `base.utils` adds `CompareBytesOrdered` + `CompareBytesIgnoreCase/HashFNV1aLower` (`LowerTable` 去分支, nil 守卫) unified for respack/vfs/http |
| `bench` | Support | benchmark helpers | `nextpas.core.bench` | explicit test/bench only | source-contract |
| `billing` | L3 | wallet/billing domain thin facade over db.wallet single source (`nextpas.core.billing.wallet` → `nextpas.core.db.wallet` single source; wallet_balances/wallet_ledger/redeem_codes over TDbPool; facade pure re-export, `nextpas.core.db.wallet` is owner, bytes.ops single source via owner) | `nextpas.core.billing.wallet` | L0-L2 plus same-layer single-point `billing.wallet` → `db.wallet`/`db.pool` (one-way, cycle-gated, hotspot inline+zero-copy, resource FreeAndNil/try-finally not lost via db.wallet) | draft |
| `bytes` | L1 | byte containers | `nextpas.core.bytes` | L0, documented text/encoding seam | focused-runtime |
| `canvas` | L2 | CPU raster canvas (ICanvas raster, Tile 16x16 + simd inline, tess梯形→整数覆盖) | `nextpas.core.canvas` | L0-L1 plus same-layer one-way `vector`/`image` (single-point `canvas.raster` → `vector.tess`/`vector.path` + `image.base`, cycle-gated, bytes.ops inline/zero-copy) | focused-runtime |
| `cbor` | L2 | CBOR format (RFC 8949 deterministic subset) | `nextpas.core.cbor` | L0-L1 | focused-runtime |
| `collections` | L1 | data structures | `nextpas.core.collections` | L0 | focused-runtime |
| `compress` | L2 | compression formats | `nextpas.core.compress` | L0-L1, provider FFI (tar 单源已收敛至 `nextpas.core.tar`，`compress.tar` 已删除) | focused-runtime — `compress.base GZIP_MAX_DECOMPRESS_BYTES=32MiB` 单源（门面重导出，`vfs.compressed VFS_DECOMPRESS_MAX_BYTES` 已收敛为薄别名/薄门面经 `transform` 承载）；`compress.tar` 已删除（空存根已移除，单源收敛完成） |
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
| `git` | L2 | git/libgit2 | `nextpas.core.git` | L0-L1 plus same-layer one-way `fs`/`compress`/`hash`/`zlib`/`checksum` plus libgit2 FFI owner (`native.zlib → compress + checksum.adler32` 复用 `bytes.ops` 单源、`inline`/零拷贝 `PByte+Len`) | focused-runtime — `test_git/test_git_bindings/test_git_native` 30+ `heaptrc 0`, `bytes.ops` 零拷贝 patch/diff/blame, inline `TryFind`, 资源 `FreeAndNil/try-finally` 不丢 |
| `graphics` | L1 | graphics base types (TColor32/TRect/TMat2D/TPath/TGradient) | `nextpas.core.graphics` | L0 | focused-runtime |
| `hash` | L2 | hash/digest | `nextpas.core.hash` | L0-L1 | focused-runtime |
| `http` | L3 | HTTP framework | `nextpas.core.http` | L0-L2 | focused-runtime — static pipeline: conditional 304 (weak ETag), single Range 206/416 + `If-Range` (ETag/date) fallback, `HEAD` header-only without stream open, error paths HEAD-aware; `http.mime` O(1) open-address hash (128 槽, FNV-1a, 1-2 探测) + 零分配切片 (`LookupBySlice` 直哈 `PChar` 段, `HttpMimeFromPath` 去 `Copy`) + L0 `HashFNV1aLower/CompareIgnoreCase` 复用 + `HashMimeNorm` 归一 + `PChar→@S[1]` 显式化 + `HttpMimeFromExt/FromPath` inline，ETag 委托 `vfs.base VfsETagStrong/FNV` 单源（`http` 包装保持 API 兼容，`Cache-Control` 单源 `CACHE_REVALIDATE`，`Content-Disposition` 单遍 `EscapeDispositionFilename`，`ParseRangeHeader BYTES_PREFIX+TryParseSlice` 零分配，`IsSafePath/TryExtractRequestPath/ExtractFileNameInline/HttpMakeStrongETag` inline（含声明侧 inline），`ServeVfs` nil 守卫 + `IsHeadReq` 复用） `test_http_*` 47 gate `heaptrc 0` |
| `id` | L1 | identifiers | `nextpas.core.id` | L0, platform random | focused-runtime |
| `ini` | L2 | INI format | `nextpas.core.ini` | L0-L1 | focused-runtime |
| `io` | L1 | stream/poller/completion | `nextpas.core.io` | L0, platform | focused-runtime, forced-compile |
| `json` | L2 | JSON format | `nextpas.core.json` | L0-L1 | focused-runtime |
| `js` | L2 | JS execution engine (QuickJS FFI + pure Pascal js888/v8/chakra) | `nextpas.core.js` | L0-L1 plus json/text.view/mem + platform.dl (loader only) | focused-runtime, source-contract — `test_js_base/fake/js888/v8/chakra` 5 gates `heaptrc 0` (`test_js_quickjs_runtime` SKIP/fail-closed when no `libquickjs`), `bytes.ops` 单源 `SpanEqual/Compare` via `text.view` 零拷贝 `TStringView` + `pure.base` 45 行纯类型载体 base零依赖 (wc -l ~45 <800，阈值 800 内，threshold 16 via pure.hash单源, 哨兵5× via js.eval单源), inline 热点 `JsPureFindHostView/JsPureNew*` + `PureHeap` `BytesCopy` 零拷贝 (`JsTrimEquals` 零拷贝单遍但按 `design-conventions §2` 去 `inline`：真实 `while/for` 扫描禁内联，避 I-Cache 膨胀), 资源 `try-finally/FreeAndNil` + `pure` 标准门面(`pure.runtime`~45+`pure.context`~360)组合 `lifecycle.Close`/`hostStateClear`/`valueStateClear` 幂等不丢（`pure.impl` 为兼容薄别名，新代码 uses `pure`） |
| `lockfree` | L1 | lock-free structures | `nextpas.core.lockfree` | L0 | focused-runtime |
| `log` | L3 | logging framework | `nextpas.core.log` | L0-L2, `log.intf` low-level seam | focused-runtime |
| `mail` | L3 | mail domain: message model / RFC5322 address / MIME bridge (depends on mime) / SMTP client + evented SMTP server | `nextpas.core.mail` | L0-L2 plus mime, net.server seams | focused-runtime |
| `math` | L0 | scalar math | `nextpas.core.math` | RTL, base/errors, explicit platform math seams | focused-runtime |
| `mem` | L0 | allocation/pools | `nextpas.core.mem` | L0 only | focused-runtime, source-contract — debt zero closed (check_mem_l0_dependencies.sh KNOWN_DEBT=0; zero fs/text/os/path; bytes.ops via base.utils CompareMem/Move/CompareBytesOrdered inline zero-copy single source, AlignUp/MulHash64 inline; FreeAndNil/try-finally not lost) |
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
| `archive` | L2 | archive shared helpers (tar/zip walk/sort/symlink/snapshot/zero-copy + pax kv, federated via archive.fs + archive.pax) | `nextpas.core.archive.fs` | L0-L1 plus fs/io via platform.files (tar/zip owned, single seam for fs; pax kv single seam for strict pax) | focused-runtime — 几何扩容 `ArchiveEnsureWalkCapacity` 2×/16 + `ArchiveWalkAppend` inline + `ArchiveSortDirEntries` 零拷贝 pivot + `ArchiveEnsureNoSymlinkInPath` 增量前缀 + `ArchiveSnapshotStream` + `ArchiveWriteFileSlice` 零拷贝 PByte + `ArchiveRestoreDeferredDirs` 逆序 + `ArchiveCollectWalk` 单源递归（ReadDir 批量 + 单次 Stat/Entry 非 N+1） + `ArchivePaxParseRecords` zero-copy PByte strict fail-closed供归档族复用 |
| `tar` | L2 | tar container (ustar/pax/GNU, block-aligned, sandboxed) | `nextpas.core.tar` | L0-L2; `tar.fs`+`tar.builder` dual federation via `archive.fs` + `archive.pax` single seam family (`tar.fs` is the `fs` seam for pack/extract, `tar.builder` is the `IBytesBuilder`/`IWriter` sink seam; shared walk/sort/snapshot/sink/CreateArchiveBuilder plus pax kv strict `ArchivePaxParseRecords`/`TarParsePaxKVRecords` zero-copy, L2 同层显式一-way) | focused-runtime, source-contract — `base` 单源 `IsSafeTarEntryName/Validate` + `C_TAR_BLOCK_SIZE=512` + `TarRegular/DirectoryMode` 薄封装 + `TarBuilderCapacityFor` 预扩容 4K 对齐；`common` 单点 `TarPadToBlock/GuardTarEntrySize/GuardTarTotalSize` + base-256 双路径校验和 + pax `TarAppendPaxRecord` builder 零拷贝最优路径单源（`archive.pax ArchivePaxFormatRecord` 单源 `SpanToString` 单次 Move，禁双复制） + `TarParsePaxKVRecords`/`ArchivePaxParseRecords` 通用 pax-kv 严格校验供归档族复用（畸形 `pax: ...` 即抛 `EIOError` 禁回退）；`reader` 零拷贝切片 `EntryDataSlice/OpenEntryStream` + `PByte` 外部内存视图 + `pax x/g` 与 `GNU L/K` 长名单点覆盖 + `MaxEntry/MaxTotal` bomb 守卫 + `heaptrc 0`；`writer` `ustar` `prefix` 自动分割 + `pax x` 长名回退（>100 无切分/`linkpath>100` 前置 `x`，`TarAppendPaxRecord` builder 单源）+ `base-256` 溢出 + `IsSafeTarEntryName` 写端拒入 + 两零块收尾；`fs` `TarPackDirInto/TarExtractToDir` 确定性排序（委托 `ArchiveCollectWalk` 单源） + `deferred dir` 逆序定稿 + `EnsureNoSymlinkInPath` 二次拒绝对称 + `SkipSpecial` 默认跳特殊文件；`builder` `ITarBuilder` 链式薄门面委托 `TTarWriter` + `CreateArchiveBuilder` 直写切片联邦单源 + `TarBuilderCapacityFor` 预扩容 + `TarBuilderWithCapacity` 显式预估总量 + `Destroy SafeFail`（`ExceptObject` 非 nil 时抑制二次异常、StdErr WARN），`compress.tar` 已删除（空存根已移除） |
| `vfs` | L2 | read-only virtual filesystem (memtree/embedded/os/sub/mount/overlay/cache + facade + decorator 聚合（transform/compressed L3 单缝装饰器经 decorator 单点收口、门面扇出收敛 13→12）) | `nextpas.core.vfs` | L0-L1; 双缝白名单过渡期超越单缝理想需L7聚合拆分：os 单缝 fs/path L2→L2 保留，embedded second seam respack.reader via bytes.ops 单源 inline 零拷贝 + SpinLock try-finally 资源不丢，L7聚合拆分为 nextpas.core.vfs.* 后端独立族后移除额外白名单固化 L0—L3 单向单缝理想（source-contract gated，line 14）; mount/overlay pure composite zero extra deps; decorator 聚合 transform/compressed: L3 单缝装饰器族经 decorator 单点收口（门面扇出收敛 13→12，Registry 单缝白名单过渡，L7 独立族按需演进后移除白名单，单源决策器单流 4K HeaderPred + 大文件栈上 2 字节轻量预判零堆分配免 4K + GZIP_MAX 32MiB canonical 链式单源 alias vfs.base→compress.base 无字面量（source-contract 单源 alias 锁定）+ bytes.ops inline 零拷贝单源、4K HeaderPred 统一（impl 私有 4096 单源，接口不暴露，compressed 数值对齐无别名），泛型路径输入/输出双 32MiB 防 bomb 统一） | focused-runtime, source-contract — embedded `FPaths/FEntries/FETags/FLastMods` parallel cache (O(log n) index, O(1) ETag/Last-Modified, zero `DecodeWire`), `TEmbeddedSlice/TEmbeddedSliceStream` 零拷贝+`SpinLock` `EMBEDDED_POOL_SIZE` 64 槽池化 (10k 163ms, `heaptrc 0`，百并发阈值覆盖 inline热路径)，`List` 零 `Stat` 直填 `FEntries`，`VfsNameCompare` 直通 `base.utils CompareBytesOrdered` + `VfsETagStrong/FNV` 单源消 `embedded/http` 字面量重复，`HasSubtreePath/IndexOfPath` 共用 `LowerBoundPath` + `CompareBytesOrdered` 显式字节序 + `CompareMem` 前缀 + `PChar→@S[1]` 显式化 + `LPtr/Llen` 缓存 + `inline` 热路径，`mount` 前缀最长匹配聚合+`overlay` 同根优先级叠加 patch>dlc>base（游戏热更，List去重合并，ETag优先透传）；`transform` L3 单缝通用变换装饰器（`TVfsTransformFunc/TVfsShouldTransformFunc/TVfsHeaderPredicateFunc` 函数注入，单源决策器 TryResolveViaHeaderSingleStream 单流 inline 零拷贝：`Stat` 单流 4K HeaderPred 免大文件全量（非变换回 FInner.Stat，小文件复用 Header 零二次 IO，大文件同流 IReaderAt/Seek 补读免二次 OpenRead，栈上 2 字节零堆分配预判）、`OpenRead` HeaderPred 假时零物化直透 `FInner.OpenRead`（零拷贝无 materialize，栈上 2 字节 peek ~数百 ns）、真时单流 Move 4K 头+同流补读、`TryGetETag` 禁用、`TryGetLastModified` 经 `QueryInterface` 透传，`inline` 热路径+`try-finally` Close 不丢，泛型路径输入/输出双 32MiB 防 bomb 统一；`compressed` 为 `transform` 薄门面（单缝寄居正名，Registry 白名单过渡，L7 聚合拆分）仅保留策略 `VFS_DECOMPRESS_MAX_BYTES` 链式单源 alias vfs.base→compress.base GZIP_MAX 32MiB canonical 无字面量（source-contract 单源 alias 锁定）与 `daAuto/daGzip` + bytes.ops inline 零拷贝单源、4K HeaderPred 统一（impl 私有 4096 单源，接口不暴露，compressed 数值对齐无别名），`STORE` 零拷贝与 32MiB 防 bomb 由 `transform` 统一承载（泛型/压缩一致），`daAuto` 单流 4K 头预判免 Stat 全量读，`bench_transform` 4 项基准固化，合规 `nextpas.core.exception` + `QueryInterface` 无 `SysUtils` 直引） |
| `vfs` | L2 | read-only virtual filesystem (memtree/embedded/os/sub/mount/overlay + facade + transform/compressed L3 单缝装饰器) | `nextpas.core.vfs` | L0-L1; os seam is the single fs/path L2→L2; embedded adds respack.reader; mount/overlay pure composite zero extra deps; transform/compressed: L3 单缝装饰器寄居 L2 家族（Registry 单缝白名单过渡，L7 到期拆分为 nextpas.core.vfs.decorator 独立 L3 族后移除白名单，单源决策器单流 4K HeaderPred + 大文件栈上 2 字节轻量预判零堆分配免 4K + GZIP_MAX 32MiB 对齐 canonical（base 为唯一字面量，compressed 经 vfs.base 单源别名复用不再双写，无直接 compress.base 依赖）+ bytes.ops inline 零拷贝单源、直接复用 transform.TRANSFORM_HEADER_PEEK 无本地别名，泛型路径输入/输出双 32MiB 防 bomb 统一） | focused-runtime, source-contract — embedded `FPaths/FEntries/FETags/FLastMods` parallel cache (O(log n) index, O(1) ETag/Last-Modified, zero `DecodeWire`), `TEmbeddedSlice/TEmbeddedSliceStream` 零拷贝+`SpinLock` `EMBEDDED_POOL_SIZE` 16 槽池化 (10k 163ms, `heaptrc 0`)，`List` 零 `Stat` 直填 `FEntries`，`VfsNameCompare` 直通 `base.utils CompareBytesOrdered` + `VfsETagStrong/FNV` 单源消 `embedded/http` 字面量重复，`HasSubtreePath/IndexOfPath` 共用 `LowerBoundPath` + `CompareBytesOrdered` 显式字节序 + `CompareMem` 前缀 + `PChar→@S[1]` 显式化 + `LPtr/Llen` 缓存 + `inline` 热路径，`mount` 前缀最长匹配聚合+`overlay` 同根优先级叠加 patch>dlc>base（游戏热更，List去重合并，ETag优先透传）；`transform` L3 单缝通用变换装饰器（`TVfsTransformFunc/TVfsShouldTransformFunc/TVfsHeaderPredicateFunc` 函数注入，单源决策器 TryResolveViaHeaderSingleStream 单流 inline 零拷贝：`Stat` 单流 4K HeaderPred 免大文件全量（非变换回 FInner.Stat，小文件复用 Header 零二次 IO，大文件同流 IReaderAt/Seek 补读免二次 OpenRead，栈上 2 字节零堆分配预判）、`OpenRead` HeaderPred 假时零物化直透 `FInner.OpenRead`（零拷贝无 materialize，栈上 2 字节 peek ~数百 ns）、真时单流 Move 4K 头+同流补读、`TryGetETag` 禁用、`TryGetLastModified` 经 `QueryInterface` 透传，`inline` 热路径+`try-finally` Close 不丢，泛型路径输入/输出双 32MiB 防 bomb 统一；`compressed` 为 `transform` 薄门面（单缝寄居正名，Registry 白名单过渡，L7 聚合拆分）仅保留策略 `VFS_DECOMPRESS_MAX_BYTES` 单源别名复用 vfs.base 32MiB（canonical 寄居 compress.base GZIP_MAX，base 唯一字面量，漂移由 source-contract 别名单源锁定）与 `daAuto/daGzip` + bytes.ops inline 零拷贝单源、直接复用 transform.TRANSFORM_HEADER_PEEK 无本地别名，`STORE` 零拷贝与 32MiB 防 bomb 由 `transform` 统一承载（泛型/压缩一致），`daAuto` 单流 4K 头预判免 Stat 全量读，`bench_transform` 4 项基准固化，合规 `nextpas.core.exception` + `QueryInterface` 无 `SysUtils` 直引） |
| `vfs` | L2 | read-only virtual filesystem (memtree/embedded/os/sub/mount/overlay + facade + transform/compressed L3 单缝装饰器) | `nextpas.core.vfs` | L0-L1; os seam is the single fs/path L2→L2; embedded adds respack.reader; mount/overlay pure composite zero extra deps; transform/compressed: L3 单缝装饰器寄居 L2 家族（Registry 单缝白名单过渡，L7 到期拆分为 nextpas.core.vfs.decorator 独立 L3 族后移除白名单，单源决策器单流 4K HeaderPred + 大文件栈上 2 字节轻量预判零堆分配免 4K + GZIP_MAX 32MiB 字面量数值对齐 compress.base canonical 单源、接口层无直接 compress.base 依赖 + bytes.ops inline 零拷贝单源、直接复用 transform.TRANSFORM_HEADER_PEEK 无本地别名，泛型路径输入/输出双 32MiB 防 bomb 统一） | focused-runtime, source-contract — embedded `FPaths/FEntries/FETags/FLastMods` parallel cache (O(log n) index, O(1) ETag/Last-Modified, zero `DecodeWire`), `TEmbeddedSlice/TEmbeddedSliceStream` 零拷贝+`SpinLock` `EMBEDDED_POOL_SIZE` 16 槽池化 (10k 163ms, `heaptrc 0`)，`List` 零 `Stat` 直填 `FEntries`，`VfsNameCompare` 直通 `base.utils CompareBytesOrdered` + `VfsETagStrong/FNV` 单源消 `embedded/http` 字面量重复，`HasSubtreePath/IndexOfPath` 共用 `LowerBoundPath` + `CompareBytesOrdered` 显式字节序 + `CompareMem` 前缀 + `PChar→@S[1]` 显式化 + `LPtr/Llen` 缓存 + `inline` 热路径，`mount` 前缀最长匹配聚合+`overlay` 同根优先级叠加 patch>dlc>base（游戏热更，List去重合并，ETag优先透传）；`transform` L3 单缝通用变换装饰器（`TVfsTransformFunc/TVfsShouldTransformFunc/TVfsHeaderPredicateFunc` 函数注入，单源决策器 TryResolveViaHeaderSingleStream 单流 inline 零拷贝：`Stat` 单流 4K HeaderPred 免大文件全量（非变换回 FInner.Stat，小文件复用 Header 零二次 IO，大文件同流 IReaderAt/Seek 补读免二次 OpenRead，栈上 2 字节零堆分配预判）、`OpenRead` HeaderPred 假时零物化直透 `FInner.OpenRead`（零拷贝无 materialize，栈上 2 字节 peek ~数百 ns）、真时单流 Move 4K 头+同流补读、`TryGetETag` 禁用、`TryGetLastModified` 经 `QueryInterface` 透传，`inline` 热路径+`try-finally` Close 不丢，泛型路径输入/输出双 32MiB 防 bomb 统一；`compressed` 为 `transform` 薄门面（单缝寄居正名，Registry 白名单过渡，L7 聚合拆分）仅保留策略 `VFS_DECOMPRESS_MAX_BYTES` 字面量 32MiB 数值对齐 GZIP_MAX canonical 单源、漂移由 source-contract 锁定与 `daAuto/daGzip` + bytes.ops inline 零拷贝单源、直接复用 transform.TRANSFORM_HEADER_PEEK 无本地别名，`STORE` 零拷贝与 32MiB 防 bomb 由 `transform` 统一承载（泛型/压缩一致），`daAuto` 单流 4K 头预判免 Stat 全量读，`bench_transform` 4 项基准固化，合规 `nextpas.core.exception` + `QueryInterface` 无 `SysUtils` 直引） |
| `vector` | L2 | vector geometry (path boolean/stroke tess) | `nextpas.core.vector` | L0-L1 | focused-runtime |
| `vfs` | L2 | read-only virtual filesystem (memtree/embedded/os/sub/mount/overlay + facade + transform/compressed L3 单缝装饰器) | `nextpas.core.vfs` | L0-L1; os seam single fs/path L2→L2 (one-way, cycle-gated) + embedded adds respack.reader (one-way, cycle-gated) — two L2→L2 allowlist one-way seams beyond default L0-L1, registry+source-contract double-locked; mount/overlay pure composite zero extra deps; transform/compressed: L3 单缝装饰器寄居 L2 家族（Registry 单缝白名单过渡，长期待 L3 族聚合拆分，单源决策器单流 4K HeaderPred + GZIP_MAX 32MiB 单源 via compress.base + bytes.ops 零拷贝） | focused-runtime, source-contract — embedded `FPaths/FEntries/FETags/FLastMods` parallel cache (O(log n) index, O(1) ETag/Last-Modified, zero `DecodeWire`), `TEmbeddedSlice/TEmbeddedSliceStream` 零拷贝+`SpinLock` `EMBEDDED_POOL_SIZE` 16 槽池化 (10k 163ms, `heaptrc 0`)，`List` 零 `Stat` 直填 `FEntries`，`VfsNameCompare` 直通 `base.utils CompareBytesOrdered` + `VfsETagStrong/FNV` 单源消 `embedded/http` 字面量重复，`HasSubtreePath/IndexOfPath` 共用 `LowerBoundPath` + `CompareBytesOrdered` 显式字节序 + `CompareMem` 前缀 + `PChar→@S[1]` 显式化 + `LPtr/Llen` 缓存 + `inline` 热路径，`mount` 前缀最长匹配聚合+`overlay` 同根优先级叠加 patch>dlc>base（游戏热更，List去重合并，ETag优先透传）；`transform` L3 单缝通用变换装饰器（`TVfsTransformFunc/TVfsShouldTransformFunc/TVfsHeaderPredicateFunc` 函数注入，单源决策器 TryResolveViaHeaderSingleStream 单流 inline 零拷贝：`Stat` 单流 4K HeaderPred 免大文件全量（非变换回 FInner.Stat，小文件复用 Header 零二次 IO，大文件同流 IReaderAt/Seek 补读免二次 OpenRead）、`OpenRead` HeaderPred 假时零物化直透 `FInner.OpenRead`（零拷贝无 materialize，4K peek ~972ns）、真时单流 Move 4K 头+同流补读、`TryGetETag` 禁用、`TryGetLastModified` 经 `QueryInterface` 透传，`inline` 热路径+`try-finally` Close 不丢；`compressed` 为 `transform` 薄门面（单缝寄居正名）仅保留策略 `VFS_DECOMPRESS_MAX_BYTES→GZIP_MAX_DECOMPRESS_BYTES` 单源与 `daAuto/daGzip` + bytes.ops 单源魔数，`STORE` 零拷贝与 32MiB 防 bomb 由 `transform` 承载，`daAuto` 单流 4K 头预判免 Stat 全量读，`bench_transform` 4 项基准固化，合规 `nextpas.core.exception` + `QueryInterface` 无 `SysUtils` 直引） |
| `webview` | L3 | desktop app shell over system web engines (WebKitGTK/WebView2/WKWebView backends; unified IPC bridge) | `nextpas.core.webview` | L0-L2 plus json owner; platform.dl | focused-runtime, source-contract — S37 容量与 Fail-Fast 完整性（`IsValidWebviewSchemeToken` 复用 + Builder `GrowInvokes/GrowReady` 2× + Scheme/几何早筛 + `CONTRACT 1.31`） |
| `websocket` | L3 | WebSocket | `nextpas.core.websocket` | L0-L2, HTTP/TLS seams | focused-runtime — `test_websocket` 17/17 + `test_http_websocket*` 3 gates `heaptrc 0`, `bytes.ops/base64/sha1` 单源, inline `TryDecode/Mask`, 零拷贝 `Payload Move` |
| `xml` | L2 | XML format | `nextpas.core.xml` | L0-L1 | focused-runtime |
| `yaml` | L2 | YAML format | `nextpas.core.yaml` | L0-L1 | focused-runtime |
| `agent` | L3 | AI provider clients (OpenAI-compat/Anthropic) + generic tool loop (`nextpas.core.agent.*`) | yes | L0-L2 plus json/http/async owners | draft |
| `args` | L2 | CLI parsing | yes | L0-L1 | focused-runtime |
| `async` | L1 | event loop/runtime | yes | L0 plus approved L1 | source-contract + focused-runtime |
| `auth` | L3 | JWT/session/authentication token primitives (`nextpas.core.auth.*`, `nextpas.core.jwt`) | yes | L0-L2 plus crypto/hash/encoding owners | focused-runtime |
| `atomic` | L0 | atomic primitives | yes | L0 only | focused-runtime |
| `audio` | L2 | PCM WAV container codec | yes | L0-L2 (io/fs owner) | focused-runtime |
| `base` | L0 | root types/contracts | yes | `exception`, bootstrap RTL debt | focused-runtime |
| `bench` | tooling | benchmark harness | yes | L0 + approved L1 tooling deps | focused-runtime |
| `billing` | L3 | wallet/billing domain thin facade over db.wallet single source (`nextpas.core.billing.wallet` → `nextpas.core.db.wallet` single source; wallet_balances/wallet_ledger/redeem_codes over TDbPool; facade pure re-export, `nextpas.core.db.wallet` is owner, bytes.ops single source via owner) | yes | L0-L2 plus same-layer single-point `billing.wallet` → `db.wallet`/`db.pool` (one-way, cycle-gated, hotspot inline+zero-copy, resource FreeAndNil/try-finally not lost via db.wallet) | draft |
| `bytes` | L1 | binary buffers | yes | L0 plus encoding/text seam | focused-runtime |
| `canvas` | L2 | CPU raster canvas (ICanvas raster, Tile 16x16 + simd inline) | yes | L0-L1 plus same-layer one-way `vector`/`image` (single-point `canvas.raster` → `vector.tess`/`vector.path` + `image.base`, cycle-gated) | focused-runtime |
| `collections` | L1 | containers | yes | L0 plus approved L1 | focused-runtime |
| `compiler` | tooling | compiler mem/arena helpers | yes | L0 mem owners | draft |
| `compress` | L2 | compression formats | yes | L0-L1 | focused-runtime |
| `checksum` | L1 | checksums (CRC-32, FNV-1a 32) | yes | L0 | focused-runtime |
| `config` | L3 | configuration framework | yes | L0-L2 | focused-runtime |
| `contracts` | L0 support | assertions/contracts | yes | L0 root | source-contract |
| `cookie` | L2 | HTTP cookie helpers | yes | L0-L1 | focused-runtime |
| `coroutine` | L3 | coroutine scheduler | yes | L0-L2 | focused-runtime |
| `crypto` | L2 | cryptography | yes | L0-L1 plus backend owners | source-contract + focused-runtime |
| `csv` | L2 | CSV parser/writer | yes | L0-L1 | focused-runtime |
| `db` | L3 | unified database access family: IDbConnection/IDbQuery over sqlite+pg backends (`nextpas.core.db.*`; `nextpas.core.db.sqlite.*` and `nextpas.core.db.pg.*` are the L2 backend implementations) | yes | L0-L2 (sqlite/pg owners are in-family) | focused-runtime |
| `deliverability` | L2 | SPF/DKIM/DMARC email authentication | yes | L0-L1 plus crypto/hash/dns owner | focused-runtime |
| `dns` | L2 | DNS record codec + UDP resolver | yes | L0-L1 plus net owner | focused-runtime |
| `diagnostics` | L1 | diagnostic builder (nextpas.core.diagnostics family; text probing) | yes | L0-L1 (text.format/text.utils) | focused-runtime |
| `encoding` | L1 | codecs | yes | L0 plus bytes/text seam | focused-runtime |
| `errors` | L0 | error facade | yes | `exception`, `base` | focused-runtime |
| `event` | L3 | event dispatch | yes | L0-L2 | draft |
| `exception` | L0 root | exception taxonomy | yes | bootstrap RTL | source-contract |
| `font` | L3 | font face/raster/atlas | yes | L0-L2 | draft |
| `format` | L2 support | shared format parse limits | no | L0-L1 | focused-runtime |
| `fs` | L2 | filesystem | yes | L0-L1; platform owns raw OS truth | focused-runtime |
| `geoip` | L2 | IP→country GeoIP lookup | yes | L0-L2 | focused-runtime |
| `git` | L2 | git/libgit2 backend | yes | L0-L1 plus libgit2 FFI owner | draft |
| `graph` | L3 | Microsoft Graph REST mail client (`nextpas.core.graph.*`; transport via injected IHttpClient) | yes | L0-L2 | focused-runtime |
| `graphics` | L1 | graphics base types (TColor32/TRect/TMat2D/TPath/TGradient) | yes | L0 | focused-runtime |
| `gpu` | L3 | OpenGL loader | yes | L0-L2 plus platform.x11 | draft |
| `hash` | L2 | hash algorithms | yes | L0-L1 | focused-runtime |
| `html` | L2 | HTML text extraction/entity decode | yes | L0-L1 | focused-runtime |
| `http` | L3 | HTTP framework | yes | L0-L2 | focused-runtime |
| `id` | L1 | ID generators | yes | L0-L1 | focused-runtime |
| `image` | L2 | image encoding | yes | L0-L2 | focused-runtime |
| `ini` | L2 | INI format | yes | L0-L1 | focused-runtime |
| `io` | L1 | stream/poller abstractions | yes | L0 plus approved L1 | focused-runtime |
| `json` | L2 | JSON parser/writer | yes | L0-L1 | focused-runtime |
| `cbor` | L2 | CBOR RFC 8949 deterministic subset (definite lengths only, Int64 domain) | yes | L0-L1 | focused-runtime |
| `jwt` | L2 | JWT RFC 7519 HS256 sign/verify (`nextpas.core.jwt`; `auth` family standalone unit) | yes | L0-L1 plus crypto/json owners | focused-runtime |
| `js` | L2 | JS execution engine (QuickJS FFI plus pure Pascal backends `nextpas.core.js.*`) | yes | L0-L1 plus json/text/mem owners; platform.dl (loader only) | source-contract + focused-runtime |
| `lockfree` | L1 | lock-free structures | yes | L0 plus approved L1 | focused-runtime |
| `log` | L3 | logging runtime | yes | L0-L2; `log.intf` is L0 seam | focused-runtime |
| `mail` | L3 | mail/SMTP domain | yes | L0-L2 | focused-runtime |
| `math` | L0 | scalar/math contracts | yes | L0 only | focused-runtime |
| `mem` | L0 | allocators/pools | yes | L0 only | source-contract, focused-runtime — debt zero closed (check_mem_l0_dependencies.sh KNOWN_DEBT=0; zero fs/text/os/path; bytes.ops via base.utils inline zero-copy single source; AlignUp/MulHash64 inline, FreeAndNil/try-finally not lost) |
| `mime` | L2 | MIME format layer | yes | L0-L1 | focused-runtime |
| `multipart` | L2 | multipart format | yes | L0-L1 | focused-runtime |
| `net` | L2 | networking | yes | L0-L1 | focused-runtime |
| `numa` | L2 | NUMA topology/alloc | yes | L0-L1; host units debt | draft |
| `oauth` | L3 | OAuth2 authorization-code client + PKCE (RFC 6749 §4.1 / RFC 7636; `nextpas.core.oauth.*`; transport via injected IHttpClient) | yes | L0-L2 | focused-runtime |
| `os` | L2 | OS helper namespace | no | L0-L1; platform owns raw OS truth | source-contract |
| `path` | L2 | path helpers | yes | L0-L1 | focused-runtime |
| `pg` | L2 backend of `db` | PostgreSQL database (libpq FFI, dlopen); units live at `nextpas.core.db.pg.*` (legacy `nextpas.core.pg.*` shims deleted in the G2 sweep) | yes | L0-L1; platform.dl | focused-runtime |
| `platform` | L0 | host ABI and OS semantics | yes | host owner `platform.*.base/ffi`, L0 only | source-contract + focused-runtime |
| `process` | L2 | process management | yes | L0-L1 | focused-runtime |
| `props` | L3 | property helpers | yes | L0-L2 | draft |
| `reflect` | L2 | reflection helpers | yes | L0-L1 | draft |
| `regex` | L2 | regular expressions | yes | L0-L1 | focused-runtime |
| `redis` | L2 backend of `db` | Redis native client (RESP2, no C library; transport over `nextpas.core.net` blocking TCP); units live at `nextpas.core.db.redis.{base,resp,transport,adapter}` plus facade `nextpas.core.db.redis` | yes | L0-L1 plus same-layer one-way `net`/`tls` (single-point `db.redis.transport` → `net.tcp`/`tls.dialer` + `db.redis.adapter` → `net`; `time`/`sync` are L1 downward not L2 seam; `db.redis.base/resp` pure L0/L1; cycle-gated, no reverse `net`/`tls` → `db.redis`; bytes.ops single source inline/zero-copy, resource FreeAndNil/try-finally not lost) | source-contract + focused-runtime |
| `respack` | L2 | resource pack container + embed toolchain (asar/Tauri parity) | yes | L0; dirsource single fs seam; embed adds fs.glob via source-contract exception | focused-runtime + source-contract |
| `sevenz` | L2 | 7z archive read/write (single or multi-folder; LZMA2/BZip2/Deflate write with optional BCJ full-family/Delta prefilter chains and AES-256 password encryption incl. encrypted headers, reader executes Delta/BCJ family/BCJ2 chains and decrypts AES-256 folders/headers; pure Pascal LZMA1/LZMA2 codec with optional liblzma FFI backend) | yes | L0-L1 plus same-layer one-way `crypto`/`hash`/`compress`/`checksum`/`io`/`fs` (fs/io via `platform.lstat` exempt, federation via `sevenz.fs` single L2→L2 seam, source-contract gated — only `sevenz.fs` may reference `fs`/`fs.intf`; compress via `sevenz.coders` single L2→L2 seam (only `sevenz.coders` may reference `compress.intf`/`compress.deflate`/`compress.bzip2`, `compress.*` → `sevenz.*` cycle-gated, thin inline forward)) | focused-runtime + source-contract (sevenz source-contract) |
| `simd` | L0 accelerator | SIMD and CPU feature seam | yes | L0 only; explicit CPUInfo debt | focused-runtime |
| `sqlite` | L2 backend of `db` | SQLite database (system libsqlite3 FFI); units live at `nextpas.core.db.sqlite.*` (legacy `nextpas.core.sqlite.*` shims deleted in the G2 sweep) | yes | L0-L1 | focused-runtime |
| `sse` | L3 | server-sent events | yes | L0-L2 | draft |
| `ssh` | L2 | SSH-2 client protocol stack (`nextpas.core.ssh.*`; pure Pascal, no C lib; sync `net` blocking + async `net.async.tcp` evented, crypto via `crypto`/`hash`, compress via `compress.zlib.ffi`) | yes | L0-L1 plus crypto/hash/compress/io/time/text owners; same-layer allowed peer `net` (single-point `ssh.net`) + `net.async.tcp` (allowed L2 async peer `transport.async`/`session.async`/`proxyjump.async` reuse `transport.core` single source); `compress.zlib.ffi` single-point via `compress` owner; bytes.ops single source inline/zero-copy, zero SysUtils | source-contract + focused-runtime |
| `stopwatch` | L1 | high-resolution timing | yes | L0-L1 | focused-runtime |
| `sync` | L1 | synchronization | yes | L0 plus approved L1 | focused-runtime |
| `system` | L0 root facade exception | RTL frontier facade | yes | L0 plus explicit text debt | source-contract |
| `template` | L3 | templating | yes | L0-L2 | draft |
| `test` | L1 | test framework (`nextpas.core.test`; `testing` is deprecated alias) | yes | L0 | focused-runtime |
| `text` | L1 | text/unicode helpers | yes | L0 plus bytes/encoding seam | focused-runtime |
| `thread` | L1 | threads/tasks/channels | yes | L0 plus approved L1 | focused-runtime |
| `time` | L1 | date/time APIs | yes | L0 plus approved L1 | focused-runtime |
| `tls` | L2 | TLS stack/backends | yes | L0-L1 plus same-layer one-way `crypto`/`hash` plus explicit backend FFI owners | source-contract + focused-runtime |
| `toml` | L2 | TOML parser/writer | yes | L0-L1 | focused-runtime |
| `tui` | L3 | terminal UI framework | yes | L0-L2 | focused-runtime |
| `validation` | L2 | validation helpers | yes | L0-L1 | focused-runtime |
| `vector` | L2 | vector geometry (path boolean/stroke tess) | yes | L0-L1 | focused-runtime |
| `vfs` | L2 | read-only virtual filesystem (memtree/embedded/os/sub/mount/overlay + facade + transform decorator) | yes | L0-L1; os seam single fs/path L2→L2; embedded adds respack.reader; mount/overlay pure composite | focused-runtime + source-contract |
| `webview` | L3 | desktop app shell over system engines (WebKitGTK/WebView2/WKWebView backends; unified IPC bridge) | yes | L0-L2 plus json owner; platform.dl | focused-runtime |
| `websocket` | L3 | WebSocket | yes | L0-L2, HTTP/TLS seams | focused-runtime |
| `xml` | L2 | XML format | yes | L0-L1 | focused-runtime |
| `yaml` | L2 | YAML parser/writer | yes | L0-L1 | focused-runtime |
| `zip` | L2 | ZIP archive container (store/deflate, Zip64, streaming, WinZip AES, sequential, builder, dir pack/extract) | yes | L0-L2 (compress/fs/checksum owners) | source-contract + focused-runtime |
| `window` | L2 | window shell + surface (nextpas.core.window family; first consumer webview/gpu/directui/game888; 1.0 单源收口含 gtk3 Raw) | yes | L0-L1 plus platform.dl seam, plus one-way L2 `gtk2/gtk3/gtk4/qt5pas/qt` | focused-runtime |
| `gtk2` | L2 | GTK2 toolkit binding (nextpas.core.gtk2 family; ffi/loader/base; dlopen `libgtk-x11-2.0.so.0`, BindOpt `scale-factor`) | yes | L0-L1 plus platform.dl | draft |
| `gtk3` | L2 | GTK3 toolkit binding (nextpas.core.gtk3 family; ffi/loader/base; dlopen `libgtk-3.so.0`, window shell subset) | yes | L0-L1 plus platform.dl | focused-runtime |
| `gtk4` | L2 | GTK4 toolkit binding (nextpas.core.gtk4 family; ffi/loader/base; dlopen `libgtk-4.so.1`, BindOpt `gtk_window_set_child` etc) | yes | L0-L1 plus platform.dl | draft |
| `qt5pas` | L2 | Qt5Pas toolkit binding (nextpas.core.qt5pas family; ffi/loader; dlopen `libQt5Pas.so.1`, libQt5Widgets window shell subset) | yes | L0-L1 plus platform.dl | draft |
| `qt` | L2 | Qt toolkit binding via self-wrap C shim (nextpas.core.qt family; ffi/loader/base; dlopen `libnextpas-qt.so`, Qt5/6 agnostic, deferred) | yes | L0-L1 plus platform.dl plus vendors/libnextpas-qt | draft |

Database family: backends are L2 implementations inside the `db` family —
currently `sqlite`, `pg`, `mysql`, `odbc` and `redis`, physically under
`nextpas.core.db.<backend>.*`. The legacy `nextpas.core.sqlite.*` /
`nextpas.core.pg.*` unit names were deleted in the G2 consumer sweep
(2026-08-25); the ffi units never had shims. Design record:
`core/docs/plans/2026-08-23-db-module-boundary.md`; backend contracts:
`core/docs/db/CONTRACT.md`.

## Gate policy

- L0 boundary gate currently hardens `base`, `errors`, `platform`, `mem`,
  `system`, `atomic`, `math`, and `simd`.
- Raw host units (`Windows`, `BaseUnix`, `Unix`, `DynLibs`, `ctypes`) must appear
  only in owner paths or explicit allowlist entries.
- Any new allowlist entry is a design debt. The landing report must name the
  path, unit/token, reason, and owner route.

## Next Architecture Routes

1. TLS master spec: provider ownership, security evidence, dynamic loading, and
   constant-time requirements.
2. System final facade: TypInfo/SysUtils/Classes decisions tied to real compiler
   and core consumers.
3. Mem L0 debt zero: ✅ closed — L0 debt zero (KNOWN_DEBT=0, zero fs/text/os/path; bytes.ops via base.utils inline zero-copy single source, platform seam only; check_mem_l0_dependencies.sh passed) — was: remove or re-home the allowlisted debt.
4. Platform runtime truth matrix: `runtime-truth-matrix.md` is **platform-scoped** by design
   (20 rows); real host runtime (`ci-runtime-matrix` + `focused-runtime`) stays
   separate from `source-contract`/`forced-compile` (simulated-host 5-leg matrix).
   L2/L3 host truth is owned by L0 `platform` until explicit promotion.
