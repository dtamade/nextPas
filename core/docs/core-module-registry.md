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
| `ci-matrix` | Runtime proof is repeated across the named host/arch CI matrix. |
| `draft` | Owner or API is not hardened enough for stronger claims. |

## Registry

| Module | Layer | Owner | Public facade | Allowed dependencies | Truth level |
| --- | --- | --- | --- | --- | --- |
| `agent` | L3 | AI provider clients (OpenAI-compat/Anthropic) + generic tool loop (`nextpas.core.agent.*`) | yes | L0-L2 plus json/http/async owners | draft |
| `args` | L2 | CLI parsing | yes | L0-L1 | focused-runtime |
| `async` | L1 | event loop/runtime | yes | L0 plus approved L1 | source-contract + focused-runtime |
| `auth` | L3 | JWT/session/authentication token primitives (`nextpas.core.auth.*`, `nextpas.core.jwt`) | yes | L0-L2 plus crypto/hash/encoding owners | focused-runtime |
| `atomic` | L0 | atomic primitives | yes | L0 only | focused-runtime |
| `audio` | L2 | audio subsystem (decode-first): 87 files = 31 core (26冻结 + wav四件套3 + pcm_wav四件套2) + 56 ext 已抽 8 独立L2 (codec.flac/mp3/vorbis/opus 各4件套 + spatial/bus/bank/resource/playlist/event/studio + simd薄封装)；核心仅聚合26真值源，L2→L2禁依赖，扩展独立演进，门面 thin `type`+`inline`零拷贝 | yes | L0-L1 (io/fs owner) plus `bytes.ops` single-source (`Move`/`BytesEnsureCapacity`/`AudioEnsureCapacity` inline零拷贝), `inline`/`EnsureScratch`/`SimdAddF32`零拷贝, `try..finally`/`SetLength(Data,0)` release；bus/codec等扩展不经 audio门面直引 | focused-runtime |
| `audio.bus` | L2 | audio bus/mixer (IAudioBus B:C00000000001 / IAudioBusMixer B:C00000000002, bus.base/intf/impl/pas 四件套, TAudioBus/TAudioBusMixer MPSC快照混音) | `nextpas.core.audio.bus` | L0-L1 plus audio.base/intf core types (TAudioFormat/TAudioBuffer/IRealtimeAudioSource) + `bytes.ops` single-source (`AudioEnsureCapacity` + `BytesZero/BytesCopy` via bytes.ops, 无自写Move), `sync` owner (`IMutex`), `simd` L0 (`SimdAddF32` via audio.simd→simd.cpuinfo 单源8-wide/4-wide/标量回退, `inline`+`vzeroupper`), `base`/`errors` L0；audio根门面不直引bus (L2→L2禁依赖, 受控seam registry登记+gate) | focused-runtime |
| `base` | L0 | root types/contracts | yes | `exception`, bootstrap RTL debt | focused-runtime |
| `bench` | tooling | benchmark harness | yes | L0 + approved L1 tooling deps | focused-runtime |
| `bytes` | L1 | binary buffers | yes | L0 plus encoding/text seam | focused-runtime |
| `embed` | L1 | embedding carrier thresholds (typed const <4MiB, EmbedRequireIncSize/ResPackRequireIncSize/EffectiveLimit inline zero-copy, MaxBlobBytes configurable) — independent strategy module extracted from respack.limits (S6); units live at `nextpas.core.embed.*` plus facade `nextpas.core.embed`; compatible alias `nextpas.core.respack.limits` forwards to `nextpas.core.embed.limits` | yes | L0 only (base/exception) | source-contract |
| `collections` | L1 | containers | yes | L0 plus approved L1 | focused-runtime |
| `compiler` | tooling | compiler mem/arena helpers | yes | L0 mem owners | draft |
| `compress` | L2 | compression formats | yes | L0-L1 plus provider FFI (tar single source 已收敛至 nextpas.core.tar，compress.tar 已删除) | focused-runtime |
| `checksum` | L1 | checksums (CRC-32, FNV-1a 32) | yes | L0 | focused-runtime |
| `config` | L3 | configuration framework | yes | L0-L2 | focused-runtime |
| `contracts` | L0 support | assertions/contracts | yes | L0 root | source-contract |
| `cookie` | L2 | HTTP cookie helpers | yes | L0-L1 | focused-runtime |
| `coroutine` | L3 | coroutine scheduler | yes | L0-L2 | focused-runtime |
| `crypto` | L2 | cryptography | yes | L0-L1 plus backend owners | source-contract + focused-runtime |
| `csv` | L2 | CSV parser/writer | yes | L0-L1 | focused-runtime |
| `db` | L3 | unified database access family: IDbConnection/IDbQuery over 6 backends sqlite/pg/mysql/odbc/redis/dm (`nextpas.core.db.*`; `nextpas.core.db.{sqlite,pg,mysql,odbc,redis,dm}.*` are the L2 backend implementations; 6 generic domains pool/stmtcache/sqlscan/trace/factory/async are independent L3 families (each base/intf/pas three-piece, facade pure re-export, bytes.ops single source, hotspot inline+zero-copy, PoolClear/Close/Destroy full-path release, 寄居债已清, registry whitelist consistent)) | yes | L0-L2 (6 backends are in-family L2 owners) | focused-runtime |
| `db.pool` | L3 | connection pool (TDbPool over any IDbConnection via factory closure, MaxRead/Writer slot, leak detection; `nextpas.core.db.pool.*` independent L3 family, three-piece facade pure re-export) | yes | L0-L2 (base/sync/bytes.ops, no backend FFI, cycle-gated, hotspot inline+zero-copy, PoolClear/Discard/Close/Destroy full-path) | focused-runtime |
| `db.stmtcache` | L3 | statement cache (sqlite LRU + pg `np_db_stmt_*` registry; `nextpas.core.db.stmtcache.*` independent L3 family) | yes | L0-L2 (L3→L2 backend thin, bytes.ops/text.sqlscan single source, inline+zero-copy, Clear/DEALLOCATE ALL full-path) | focused-runtime |
| `db.sqlscan` | L3 thin | SQL lex scan shared engine thin re-export to `text.sqlscan` true source (`nextpas.core.db.sqlscan.*` independent L3 thin, true source L1 `text.sqlscan`, inline zero-alloc forwarding) | yes | L0 (true source L1, bytes.ops/text.builder single source, inline+zero-copy, zero handle, heaptrc 0) | focused-runtime |
| `db.trace` | L3 | observability hook (IDbTraceListener 512 summary; `nextpas.core.db.trace.*` independent L3 family, four backends + pool FlushDiagnostics) | yes | L0-L2 (sync/platform.time, bytes.ops single source, inline zero-cost fast path, lock snapshot outside callback, heaptrc 0) | focused-runtime |
| `db.factory` | L3 | driver factory / Open即池 (IDbDriver registry + DbOpen/DbOpenPool; `nextpas.core.db.factory.*` independent L3 family, builtin side-effect) | yes | L0-L2 (no backend FFI, bytes.ops/text.kv single source, inline lookup, Close/Shutdown full-path) | focused-runtime |
| `db.async` | L3 | async/subscribe (TDbAsyncExecutor + TPgListener + RedisOpenSubscriber; `nextpas.core.db.async.*` + `pg.listen`/`redis.subscribe` independent L3 families, single-worker pump + bounded queue) | yes | L0-L2 (thread.pool/sync/async.cancellation, bytes.ops single source, inline wake, zero-copy TByteSpan/TRespValue, Cancel→RemoveOnCancel/Destroy full-path, PQfreemem/MAX_FRAME_BYTES) | focused-runtime |
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
| `gpu` | L3 | OpenGL loader | yes | L0-L2 plus platform.x11 | draft |
| `hash` | L2 | hash algorithms | yes | L0-L1 | focused-runtime |
| `html` | L2 | HTML text extraction/entity decode | yes | L0-L1 | focused-runtime |
| `http` | L3 | HTTP framework | yes | L0-L2 | focused-runtime |
| `id` | L1 | ID generators | yes | L0-L1 | focused-runtime |
| `effect` | L2 | filter graph (Blur/Shadow/Hue/LUT, serializable, tile parallel) | yes | L0-L1 plus same-layer one-way `image` (TBitmap Stride 64B) | source-contract |
| `image` | L2 | image codec (TBitmap Stride 64B + PNG/JPEG/WebP/BMP, EImageDecodeError, TryImageDecode) | yes | L0-L1 plus `platform.dl` (optional FFI `libjpeg-turbo`/`libwebp` via `image.jpeg.ffi`/`image.webp.ffi`) | source-contract |
| `gpu.canvas` | L3 | bitmap→Texture/Atlas bridge (TAtlas/TAtlasRegion/ScaleFactor, shelf pack, Scale 1..4) | yes | L0-L2 + `gpu.gl`/`platform.dl` | source-contract |
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
| `mem` | L0 with debt | allocators/pools | yes | L0 only; explicit debt allowlist | source-contract |
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
| `respack` | L2 | resource pack container + embed toolchain (asar/Tauri parity, FORMAT v1 40/LE, v1 line format writer/reader/dirsource/embed); units live at `nextpas.core.respack.*` plus facade `nextpas.core.respack` (threshold strategy extracted to independent L1 `nextpas.core.embed.limits`, `respack.limits` is compatible forwarding) | yes | L0-L1; dirsource is the single L2→L2 IO seam (fs + io.mapped mmap zero-copy via mem.memory_map owner, L2→L2 documented, source-contract gated like vfs.os, fs.glob match-only exception); embed is L1 text.strings/text.char/text.conv single source (GlobMatch via text.strings + IsAlpha via text.char + IntToStr via text.conv, inline + PChar zero-copy view + O(pat×name) dual-tracker, fs.glob thin forward; bytes.ops single source inline/zero-copy) + `embed.limits` independent L1 strategy (inline zero-copy EmbedRequireIncSize/EffectiveLimit, MaxBlobBytes configurable, other carriers reusable) | focused-runtime ×6, source-contract — writer O(n) hash buckets (`BUCKET_MIN` 256→`BUCKET_MAX` 65536, `TryMulSizeUInt` 溢出安全) + `CompareMem` dedup + `CompareBytesOrdered` sort (PathLens precompute, Key/Pivot cache + `PChar→@S[1]`), reader single-pass cached `DecodeWire` + `CompareBytesOrdered` block compare + Search LPtr cache, BaseValidPath via `base.pathvalid` L0 shared |
| `sevenz` | L2 | 7z archive read/write (single or multi-folder; LZMA2/BZip2/Deflate write with optional BCJ full-family/Delta prefilter chains and AES-256 password encryption incl. encrypted headers, reader executes Delta/BCJ family/BCJ2 chains and decrypts AES-256 folders/headers; pure Pascal LZMA1/LZMA2 codec with optional liblzma FFI backend) | yes | L0-L1 plus same-layer one-way `crypto`/`hash`/`compress`/`checksum`/`io`/`fs` (fs/io via `platform.lstat` exempt, federation via `sevenz.fs`) | focused-runtime |
| `redis` | L2 backend of `db` | Redis native client (RESP2, no C library; transport over `nextpas.core.net` blocking TCP); units live at `nextpas.core.db.redis.{base,resp,transport,adapter}` plus facade `nextpas.core.db.redis` | yes | L0-L1 plus same-layer one-way `net`/`time`/`sync` | focused-runtime |
| `respack` | L2 | resource pack container + embed toolchain (asar/Tauri parity, FORMAT v1 40/LE, v1 line format writer/reader/dirsource/embed); units live at `nextpas.core.respack.*` plus facade `nextpas.core.respack` (threshold strategy extracted to independent L1 `nextpas.core.embed.limits`, `respack.limits` is compatible forwarding) | yes | L0-L1; dirsource is the single L2→L2 IO seam (fs + io.mapped + path mmap zero-copy via mem.memory_map owner, L2→L2 documented, source-contract gated like vfs.os, fs.glob match-only exception); embed is L1 text.strings GlobMatch single source (inline + PChar zero-copy view + O(pat×name) dual-tracker, fs.glob thin forward; bytes.ops CompareBytesOrdered) + `embed.limits` independent L1 strategy (inline zero-copy EmbedRequireIncSize/EffectiveLimit, MaxBlobBytes configurable, other carriers reusable) | focused-runtime ×6, source-contract — writer O(n) hash buckets (`BUCKET_MIN` 256→`BUCKET_MAX` 65536, `TryMulSizeUInt` 溢出安全) + `CompareMem` dedup + `CompareBytesOrdered` sort (PathLens precompute, Key/Pivot cache + `PChar→@S[1]`), reader single-pass cached `DecodeWire` + `CompareBytesOrdered` block compare + Search LPtr cache, BaseValidPath via `base.pathvalid` L0 shared |
| `sevenz` | L2 | 7z archive read/write (single or multi-folder; LZMA2/BZip2/Deflate write with optional BCJ full-family/Delta prefilter chains and AES-256 password encryption incl. encrypted headers, reader executes Delta/BCJ family/BCJ2 chains and decrypts AES-256 folders/headers; pure Pascal LZMA1/LZMA2 codec with optional liblzma FFI backend) | yes | L0-L1 plus same-layer one-way `crypto`/`hash`/`compress`/`checksum`/`io`/`fs` (fs/io via `platform.lstat` exempt, federation via `sevenz.fs` single L2→L2 seam, source-contract gated like `respack.dirsource`/`vfs.os` — only `sevenz.fs` may reference `fs`/`fs.intf`; compress via `sevenz.coders` single L2→L2 seam (only `sevenz.coders` may reference `compress.intf`/`compress.deflate`/`compress.bzip2`/`compress`, `compress.*` → `sevenz.*` cycle-gated, thin inline forward via `compress.intf`, source-contract gated; `levels`/`writer` encode path reuses `compress.base` pure mapping, not second decode seam), `bytes.ops` single-source inline zero-copy + `try..finally` not lost) | focused-runtime + source-contract (sevenz source-contract) |
| `simd` | L0 accelerator | SIMD and CPU feature seam | yes | L0 only; explicit CPUInfo debt | focused-runtime |
| `sqlite` | L2 backend of `db` | SQLite database (system libsqlite3 FFI); units live at `nextpas.core.db.sqlite.*` (legacy `nextpas.core.sqlite.*` shims deleted in the G2 sweep) | yes | L0-L1 | focused-runtime |
| `sse` | L3 | server-sent events | yes | L0-L2 | draft |
| `stopwatch` | L1 | high-resolution timing | yes | L0-L1 | focused-runtime |
| `sync` | L1 | synchronization | yes | L0 plus approved L1 | focused-runtime |
| `system` | L0 root facade exception | RTL frontier facade | yes | L0 plus explicit text debt | source-contract |
| `template` | L3 | templating | yes | L0-L2 | draft |
| `test` | L1 | test framework | yes | L0 | focused-runtime |
| `text` | L1 | text/unicode helpers | yes | L0 plus bytes/encoding seam | focused-runtime |
| `thread` | L1 | threads/tasks/channels | yes | L0 plus approved L1 | focused-runtime |
| `time` | L1 | date/time APIs | yes | L0 plus approved L1 | focused-runtime |
| `tls` | L2 | TLS stack/backends | yes | L0-L1 plus explicit backend FFI owners | source-contract + focused-runtime |
| `toml` | L2 | TOML parser/writer | yes | L0-L1 | focused-runtime |
| `tui` | L3 | terminal UI framework | yes | L0-L2 | focused-runtime |
| `validation` | L3 | validation helpers | yes | L0-L2 | draft |
| `vfs` | L2 | read-only virtual filesystem (`nextpas.core.vfs.*`, memtree/embedded/os/sub/mount/overlay/cache + decorator 聚合（transform/compressed L3 单缝装饰器经 decorator 单点收口、门面扇出收敛 13→12），15 units（incl. decorator）+ facade) | yes | L0-L1; 后端独立族 `nextpas.core.vfs.*` L7 聚合已收敛至单缝理想（`vfs.os`→`nextpas.core.fs`/`nextpas.core.path` 单缝, `vfs.embedded`→`nextpas.core.respack.reader` 独立, `vfs.mount`/`vfs.overlay` pure composite, `vfs.decorator` L3 单缝; bytes.ops 单源 inline 零拷贝 + striped SpinLock 16 shards 分片发布 10k 首击 16×降争 双重校验 try-finally 资源不丢, L0—L3 单向单缝理想, source-contract gated, 双缝过渡债务已移除）; mount/overlay pure composite; decorator 聚合 transform/compressed: L3 单缝装饰器族经 decorator 单点收口（门面扇出收敛 13→12，Registry 单缝理想已固化无额外白名单（L7 后端独立族落地后移除过渡白名单），单源决策器薄转发分层 LightProbe/HeaderRead/LargeFill 三阶段 inline 单一职责 单流 4K HeaderPred + 大文件栈上 2 字节探针栈零堆 PByte 单源免 4K/TBytes 堆分配 + GZIP_MAX 32MiB canonical 链式单源 alias vfs.base→compress.base 无字面量（source-contract 单源 alias 锁定，非 IReaderAt 2字节小缓冲零堆单 Move 最优）+ bytes.ops inline 零拷贝单源、4K HeaderPred 统一（impl 私有 4096 单源，接口不暴露，compressed 数值对齐无别名），泛型路径输入/输出双 32MiB 限幅防 bomb 并发峰值受控（L7 视压测按需 chunked streaming 进一步收敛，不公开债务），Stat/OpenRead 大文件解压一致性） | source-contract + focused-runtime |
| `vector` | L2 | vector geometry (path boolean/stroke tess Double内核 Single外观, TPoly/TTrapezoid) (`nextpas.core.vector.*`: `vector.path` + `vector.tess`; facade pure re-export, graphics.base L1 single source, bytes.ops零拷贝 inline) | yes | L0-L1 | focused-runtime |
| `vfs` | L2 | read-only virtual filesystem (`nextpas.core.vfs.*`, memtree/embedded/os/backends/sub/mount/overlay/cache/util + decorator 聚合（transform/compressed L3 单缝装饰器经 decorator 单点收口）+ backends 后端族聚合（memtree/embedded/os 经 backends 单缝收口），16 units + facade，门面经 backends+decorator 双族单缝收敛 12→10) | yes | L0-L1; L2→L2 seams whitelisted (source-contract gated, 双缝经 backends 族单缝收口：vfs.backends 聚合 memtree/embedded/os，os→fs/path 与 embedded→respack.reader 双缝仅经 backends 族透出，门面经 backends 单缝收敛 via bytes.ops 单源 inline 零拷贝 + striped SpinLock 16 shards 分片发布 10k 首击 16×降争 双重校验保留 try-finally 资源不丢，已落地 L7 单缝理想); mount/overlay pure composite; decorator 聚合 transform/compressed: L3 单缝装饰器族经 decorator 单点收口（门面扇出收敛 13→12→10，双族收口，Registry 已收口，单源决策器薄转发分层 LightProbe/HeaderRead/LargeFill 三阶段 inline 单一职责 单流 4K HeaderPred + 大文件栈上 2 字节探针栈零堆 PByte 单源免 4K/TBytes 堆分配 + GZIP_MAX 32MiB 对齐 canonical（base 为唯一字面量，compressed 经 vfs.base 单源别名复用不再双写，无直接 compress.base 依赖，非 IReaderAt 2字节小缓冲零堆单 Move 最优）+ bytes.ops inline 零拷贝单源、4K HeaderPred 统一（impl 私有 4096 单源，接口不暴露，compressed 数值对齐无别名），泛型路径输入/输出双 32MiB 限幅防 bomb 并发峰值受控，Stat/OpenRead 大文件解压一致性） | focused-runtime |
| `websocket` | L3 | websocket framework | yes | L0-L2 | draft |
| `webview` | L3 | desktop app shell over system engines (WebKitGTK/WebView2/WKWebView; unified IPC bridge) | yes | L0-L2 plus json owner; platform.dl | focused-runtime |
| `window` | L2 | window shell + surface (nextpas.core.window family; first consumer webview/gpu/directui/game888; 1.0 单源收口含 gtk3 Raw) | yes | L0-L1 plus platform.dl seam, plus one-way L2 `gtk2/gtk3/gtk4/qt5pas/qt` | ci-matrix (Linux 13门 runtime + Win/mac compile-only，残差诚实，见 window/FINAL_ROADMAP F3) |
| `gtk2` | L2 | GTK2 toolkit binding (nextpas.core.gtk2 family; ffi/loader/base; dlopen `libgtk-x11-2.0.so.0`, BindOpt `scale-factor`) | yes | L0-L1 plus platform.dl | draft |
| `gtk3` | L2 | GTK3 toolkit binding (nextpas.core.gtk3 family; ffi/loader/base; dlopen `libgtk-3.so.0`, window shell subset) | yes | L0-L1 plus platform.dl | focused-runtime |
| `gtk4` | L2 | GTK4 toolkit binding (nextpas.core.gtk4 family; ffi/loader/base; dlopen `libgtk-4.so.1`, BindOpt `gtk_window_set_child` etc) | yes | L0-L1 plus platform.dl | draft |
| `qt5pas` | L2 | Qt5Pas toolkit binding (nextpas.core.qt5pas family; ffi/loader; dlopen `libQt5Pas.so.1`, libQt5Widgets window shell subset) | yes | L0-L1 plus platform.dl | draft |
| `qt` | L2 | Qt toolkit binding via self-wrap C shim (nextpas.core.qt family; ffi/loader/base; dlopen `libnextpas-qt.so`, Qt5/6 agnostic, deferred) | yes | L0-L1 plus platform.dl plus vendors/libnextpas-qt | draft |
| `xml` | L2 | XML parser/writer | yes | L0-L1 | focused-runtime |
| `yaml` | L2 | YAML parser/writer | yes | L0-L1 | focused-runtime |
| `archive` | L2 | archive shared helpers (tar/zip walk/sort/symlink/snapshot/zero-copy + pax kv, federated via archive.fs + archive.pax) | yes | L0-L1 plus fs/io via platform.files (tar/zip owned, single seam for fs; pax kv single seam for strict pax) | focused-runtime — ArchivePaxParseRecords zero-copy PByte strict fail-closed供归档族复用 |
| `tar` | L2 | tar container (ustar/pax/GNU, block-aligned, sandboxed, dir pack/extract + fluent builder) | yes | L0-L1 plus L2 federated via `archive.fs` + `archive.pax` single seam family (no direct `fs`; `tar.fs` is the `fs` seam for pack/extract, `tar.builder` is the `IBytesBuilder`/`IWriter` sink seam; shared walk/sort/snapshot/sink/CreateArchiveBuilder plus pax kv strict `ArchivePaxParseRecords`/`TarParsePaxKVRecords` zero-copy, L2 同层显式 one-way) | focused-runtime |
| `zip` | L2 | ZIP archive container (store/deflate, Zip64, streaming, WinZip AES, sequential, builder, dir pack/extract) | yes | L0-L2 (compress/fs/checksum owners) | source-contract + focused-runtime |

Database family: backends are L2 implementations inside the `db` family —
currently `sqlite`, `pg`, `mysql`, `odbc`, `redis` and `dm`, physically under
`nextpas.core.db.<backend>.*`; 6 generic domains `pool/stmtcache/sqlscan/trace/factory/async` are independent L3 families (each base/intf/pas three-piece, 寄居债已清, §1.1.1升格完成). The legacy `nextpas.core.sqlite.*` /
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
- Known elegant debts: `vfs` 已收敛至单缝理想 — L7 聚合拆分为 `nextpas.core.vfs.*` 后端独立族落地，双缝白名单过渡债务已移除（backend-independent families: `vfs.os`→`fs/path` 单缝, `vfs.embedded`→`respack.reader` 独立, `vfs.mount`/`vfs.overlay` pure composite, `vfs.decorator` L3 单点收口 `transform`/`compressed`; bytes.ops single-source inline zero-copy, striped SpinLock 16 shards 分片发布 10k 首击 16×降争 try-finally 资源不丢, L0—L3 单向单缝理想, source-contract gated 持续钉死防回退）; `system.sysutils` 2 L0 allowlist entries (text + bytes) L7 converged 2026-09-03 single source — 5 text sub-units converged to `nextpas.core.text` + `nextpas.core.bytes` single source (bytes.ops single-source TByteSpan view single Move in owner, inline zero-copy, try-finally not lost; stub elegance via `units/<target>/` no IFDEF fork, ~800 lines soft-800 pure aggregation 40+ thin forwards, platform convergence done for file/path/env) — see `core/tests/architecture/source_contracts/architecture_contract_registry.json:139-142`.
