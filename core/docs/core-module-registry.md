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
| `audio` | L2 | audio subsystem (decode-first): container codecs WAV/AIFF/FLAC/MP3/Vorbis (+ Ogg probe) + PCM/DSP/device/graph/game/timeline/studio — 78 files (core 26 + ext 52: codec.flac/mp3/vorbis 12 incl. sse/decoder + spatial/bus/bank/resource/playlist/event/studio/simd/pcm.simd), facade thin `type`+`inline` forwarding, `bytes.ops` single-source zero-copy | yes | L0-L2 (io/fs owner) plus `bytes.ops` single-source (`Move`/`BytesEnsureCapacity` reuse, no per-codec duplication), `inline`/`EnsureScratch` zero-copy, `try..finally`/`SetLength(Data,0)` release | focused-runtime |
| `base` | L0 | root types/contracts | yes | `exception`, bootstrap RTL debt | focused-runtime |
| `bench` | tooling | benchmark harness | yes | L0 + approved L1 tooling deps | focused-runtime |
| `bytes` | L1 | binary buffers | yes | L0 plus encoding/text seam | focused-runtime |
| `embed` | L1 | embedding carrier thresholds (typed const <4MiB, EmbedRequireIncSize/ResPackRequireIncSize/EffectiveLimit inline zero-copy, MaxBlobBytes configurable) — independent strategy module extracted from respack.limits (S6); units live at `nextpas.core.embed.*` plus facade `nextpas.core.embed`; compatible alias `nextpas.core.respack.limits` forwards to `nextpas.core.embed.limits` | yes | L0 only (base/exception) | source-contract |
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
| `gpu` | L3 | OpenGL loader | yes | L0-L2 plus platform.x11 | draft |
| `hash` | L2 | hash algorithms | yes | L0-L1 | focused-runtime |
| `html` | L2 | HTML text extraction/entity decode | yes | L0-L1 | focused-runtime |
| `http` | L3 | HTTP framework | yes | L0-L2 | focused-runtime |
| `id` | L1 | ID generators | yes | L0-L1 | focused-runtime |
| `graphics` | L1 | graphics value types (TColor32/TRgba/TBlendMode/TRect/TVec2/TMat2D/TPath/Gradient, Single external, zero heap) | yes | L0 only (`base`, `math`) | source-contract |
| `vector` | L2 | vector kernel (path boolean/stroke/tess, Double inner, EPSILON 1e-6) | yes | L0-L1 | source-contract |
| `canvas` | L2 | 2D canvas (ICanvas + CPU raster, tiled 16x16 + simd) | yes | L0-L1 | source-contract |
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
| `redis` | L2 backend of `db` | Redis native client (RESP2, no C library; transport over `nextpas.core.net` blocking TCP); units live at `nextpas.core.db.redis.{base,resp,transport,adapter}` plus facade `nextpas.core.db.redis` | yes | L0-L1 plus same-layer one-way `net`/`time`/`sync` | focused-runtime |
| `respack` | L2 | resource pack container + embed toolchain (asar/Tauri parity, FORMAT v1 40/LE, v1 line format writer/reader/dirsource/embed); units live at `nextpas.core.respack.*` plus facade `nextpas.core.respack` (threshold strategy extracted to independent L1 `nextpas.core.embed.limits`, `respack.limits` is compatible forwarding) | yes | L0-L1; dirsource is the single L2→L2 IO seam (fs + io.mapped + path mmap zero-copy via mem.memory_map owner, L2→L2 documented, source-contract gated like vfs.os, fs.glob match-only exception); embed is L1 text.strings GlobMatch single source (inline + PChar zero-copy view + O(pat×name) dual-tracker, fs.glob thin forward; bytes.ops CompareBytesOrdered) + `embed.limits` independent L1 strategy (inline zero-copy EmbedRequireIncSize/EffectiveLimit, MaxBlobBytes configurable, other carriers reusable) | focused-runtime ×6, source-contract — writer O(n) hash buckets (`BUCKET_MIN` 256→`BUCKET_MAX` 65536, `TryMulSizeUInt` 溢出安全) + `CompareMem` dedup + `CompareBytesOrdered` sort (PathLens precompute, Key/Pivot cache + `PChar→@S[1]`), reader single-pass cached `DecodeWire` + `CompareBytesOrdered` block compare + Search LPtr cache, BaseValidPath via `base.pathvalid` L0 shared |
| `sevenz` | L2 | 7z archive read/write (single or multi-folder; LZMA2/BZip2/Deflate write with optional BCJ full-family/Delta prefilter chains and AES-256 password encryption incl. encrypted headers, reader executes Delta/BCJ family/BCJ2 chains and decrypts AES-256 folders/headers; pure Pascal LZMA1/LZMA2 codec with optional liblzma FFI backend) | yes | L0-L1 plus same-layer one-way `crypto`/`hash`/`compress`/`checksum`/`io`/`fs` (fs/io via `platform.lstat` exempt, federation via `sevenz.fs` single L2→L2 seam, source-contract gated like `respack.dirsource`/`vfs.os` — only `sevenz.fs` may reference `fs`/`fs.intf`; compress via `sevenz.coders` single L2→L2 seam (only `sevenz.coders` may reference `compress.intf`/`compress.deflate`/`compress.bzip2`/`compress`, `compress.*` → `sevenz.*` cycle-gated, thin inline forward via `compress.intf`, source-contract gated; `levels`/`writer` encode path reuses `compress.base` pure mapping, not second decode seam), `bytes.ops` single-source inline zero-copy + `try..finally` not lost) | focused-runtime + source-contract (sevenz source-contract) |
| `simd` | L0 accelerator | SIMD and CPU feature seam | yes | L0 only; explicit CPUInfo debt | focused-runtime |
| `sqlite` | L2 backend of `db` | SQLite database (system libsqlite3 FFI); units live at `nextpas.core.db.sqlite.*` (legacy `nextpas.core.sqlite.*` shims deleted in the G2 sweep) | yes | L0-L1 | focused-runtime |
| `sse` | L3 | server-sent events | yes | L0-L2 | draft |
| `stopwatch` | L1 | high-resolution timing | yes | L0-L1 | focused-runtime |
| `sync` | L1 | synchronization | yes | L0 plus approved L1 | focused-runtime |
| `system` | L0 root facade exception | RTL frontier facade | yes | L0 plus explicit text/io/path/fs debt | source-contract |
| `template` | L3 | templating | yes | L0-L2 | draft |
| `test` | L1 | test framework | yes | L0 | focused-runtime |
| `text` | L1 | text/unicode helpers | yes | L0 plus bytes/encoding seam | focused-runtime |
| `thread` | L1 | threads/tasks/channels | yes | L0 plus approved L1 | focused-runtime |
| `time` | L1 | date/time APIs | yes | L0 plus approved L1 | focused-runtime |
| `tls` | L2 | TLS stack/backends | yes | L0-L1 plus explicit backend FFI owners | source-contract + focused-runtime |
| `toml` | L2 | TOML parser/writer | yes | L0-L1 | focused-runtime |
| `tui` | L3 | terminal UI framework | yes | L0-L2 | focused-runtime |
| `validation` | L3 | validation helpers | yes | L0-L2 | draft |
| `vfs` | L2 | read-only virtual filesystem (`nextpas.core.vfs.*`, memtree/embedded/os/backends/sub/mount/overlay/cache/util + decorator 聚合（transform/compressed L3 单缝装饰器经 decorator 单点收口）+ backends 后端族聚合（memtree/embedded/os 经 backends 单缝收口），16 units + facade，门面经 backends+decorator 双族单缝收敛 12→10) | yes | L0-L1; L2→L2 seams whitelisted (source-contract gated, 双缝经 backends 族单缝收口：vfs.backends 聚合 memtree/embedded/os，os→fs/path 与 embedded→respack.reader 双缝仅经 backends 族透出，门面经 backends 单缝收敛 via bytes.ops 单源 inline 零拷贝 + striped SpinLock 16 shards 分片发布 10k 首击 16×降争 双重校验保留 try-finally 资源不丢，已落地 L7 单缝理想); mount/overlay pure composite; decorator 聚合 transform/compressed: L3 单缝装饰器族经 decorator 单点收口（门面扇出收敛 13→12→10，双族收口，Registry 已收口，单源决策器薄转发分层 LightProbe/HeaderRead/LargeFill 三阶段 inline 单一职责 单流 4K HeaderPred + 大文件栈上 2 字节探针栈零堆 PByte 单源免 4K/TBytes 堆分配 + GZIP_MAX 32MiB 对齐 canonical（base 为唯一字面量，compressed 经 vfs.base 单源别名复用不再双写，无直接 compress.base 依赖，非 IReaderAt 2字节小缓冲零堆单 Move 最优）+ bytes.ops inline 零拷贝单源、4K HeaderPred 统一（impl 私有 4096 单源，接口不暴露，compressed 数值对齐无别名），泛型路径输入/输出双 32MiB 限幅防 bomb 并发峰值受控，Stat/OpenRead 大文件解压一致性） | focused-runtime |
| `websocket` | L3 | websocket framework | yes | L0-L2 | draft |
| `webview` | L3 | desktop app shell over system engines (WebKitGTK/WebView2/WKWebView; unified IPC bridge) | yes | L0-L2 plus json owner; platform.dl | focused-runtime |
| `window` | L2 | window shell + surface (nextpas.core.window family; first consumer webview/gpu/directui/game888; 1.0 单源收口含 gtk3 Raw) | yes | L0-L1 (incl. diagnostics/text/system.typinfo for enum+diag within L0-L1) plus platform.dl seam, plus one-way L2 `gtk2/gtk3/gtk4/qt5pas/qt` (no L2→L2 window.constraints, window.impl 约束校验本地 inline 零拷贝 O(1) 守 L0-L3 无循环 via bytes.ops 单源) | ci-matrix (Linux 13门 runtime + Win/mac compile-only，残差诚实，见 window/FINAL_ROADMAP F3) |
| `window.live` | L2 shard | window live registry (`nextpas.core.window.live`: `TWindowLiveRegistry`/`TWindowSdlLiveRegistry` + 无锁原子聚合计数) — **家族内特权共享，编译期需 `TWindowFamilyToken`（`window.impl` 单源 inline 零拷贝 IsValid，strict private sentinel）方可构造，不经公共门面 re-export，仅 `window.*` 后端 uses** (owner `window.impl`, scope `window` family, base 仅纯数据类型不承载 sentinel 运行时行为) | no | L0-L1 plus `atomic` + `sync` + `bytes.ops` via `window.impl` | source-contract |
| `window.queue` | L2 shard | window work queue (`nextpas.core.window.queue`: `TWindowQueue` 环形 FIFO 32cap 起步 2×增长 + 锁外 Drain; 已分治 `queue.base/ring/backpressure` 三子 shard 各 <150 行，门面 ~780 行 <800) — **家族内特权共享，编译期需 `TWindowFamilyToken`（`window.impl` 单源 inline 零拷贝 IsValid，strict private sentinel）方可构造，不经公共门面 re-export，仅 `window.*` 后端 uses** (owner `window.impl`, scope `window` family, base 纯数据类型 via `queue.base`, 环形池化 via `queue.ring`, 背压双轨 via `queue.backpressure` 可复用策略) | no | L0-L1 plus `sync` + `bytes.ops` via `window.impl` | source-contract |
| `window.queue.base` | L2 shard | window queue base 子 shard (`nextpas.core.window.queue.base`: `TWindowWorkKind/TWindowWorkItem/TWindowCowCtx` 纯数据类型，仅 `queue` uses) — **家族内特权共享，编译期需 `TWindowFamilyToken` 间接经 `queue` 语义（`window.impl` 单源 inline 零拷贝 IsValid）方可构造，不经公共门面 re-export，仅 `window.queue` uses** (owner `window.impl`, scope `window` family, base 仅纯数据类型，守 `base←impl`) | no | L0-L1 plus `bytes.ops` via `window.impl` | source-contract |
| `window.queue.ring` | L2 shard | window queue ring 子 shard (`nextpas.core.window.queue.ring`: `TQueueRingArena` 64 槽 lock-free LIFO `QueueRingArenaAcquire/Recycle` via `bytes.ops` `ArenaPoolAcquireSlot/RecycleSlot/Finalize` 单源池化通用抽象，阈值收缩 8192，仅 `queue` uses) — **家族内特权共享，编译期需 `TWindowFamilyToken` 间接经 `queue` 语义（`window.impl` 单源 inline 零拷贝 IsValid）方可构造，不经公共门面 re-export，仅 `window.queue` uses** (owner `window.impl`, scope `window` family, 守 `base←impl`, 单源池化 via `bytes.ops` snapshot) | no | L0-L1 plus `atomic` + `bytes.ops` via `window.impl` | source-contract |
| `window.queue.backpressure` | L2 shard | window queue backpressure 子 shard (`nextpas.core.window.queue.backpressure`: `TWindowQueueBackpressure` 双轨 `Cap/Oom` 原子计数 `IncCap/IncOom/Total/CapCount/OomCount` inline 零拷贝 O(1) 可复用策略，仅 `queue` uses) — **家族内特权共享，编译期需 `TWindowFamilyToken` 间接经 `queue` 语义（`window.impl` 单源 inline 零拷贝 IsValid）方可构造，不经公共门面 re-export，仅 `window.queue` uses** (owner `window.impl`, scope `window` family, 守 `base←impl`, 单源 `bytes.ops` 阈值 `WindowQueueRingMax` 16384) | no | L0-L1 plus `atomic` via `window.impl` | source-contract |
| `window.hash` | L2 shard | window hash helper (`nextpas.core.window.hash`: 开放寻址线性探测双哈希 Pointer/U32，负载≤0.5 阈值 0.5 Via WindowGrowCapacity 0→32→2× 幂二单源，掩码探查，删除回填，>1k 重建计数排序桶序 O(n+cap) 单次散列控 16k 集群) — **家族内特权共享，编译期需 `TWindowFamilyToken`（`window.impl` 单源 inline 零拷贝 IsValid，strict private sentinel）方可调用，不经公共门面 re-export，仅 `window.live` uses，禁直调 bytes.ops Bytes*/旁路（source-contract strip_comments 门禁）** (owner `window.impl`, scope `window` family, base 仅纯数据类型) | no | L0-L1 plus `bytes.ops` via `window.impl` | source-contract |
| `window.dispatcher.base` | L2 shard | window dispatcher base (`nextpas.core.window.dispatcher.base`: `TWindowDispatcherBase` + Post 三重载各 inline 零分支直达零拷贝直存变体 wwkRef/wwkMethod/wwkProc（热路径零 case 避调度，冷路径 EnsureQueue 单外联守 I-Cache 防热路径复制膨胀）+ DoWake 虚派隔离) — **家族内特权共享，编译期需 `TWindowFamilyToken`（`window.impl` 单源 inline 零拷贝 IsValid，strict private sentinel）显式 `RequireWindowFamilyToken` 校验方可构造，`Post` 三重载零分支直达零重复，不经公共门面 re-export，仅 `window.*` 后端 uses** (owner `window.impl`, scope `window` family, base 仅纯数据类型) | no | L0-L1 plus `sync` + `bytes.ops` via `window.impl` | source-contract |
| `window.live.arena` | L2 shard | window live arena 子 shard (`nextpas.core.window.live.arena`: `TLiveBuildArena` 8 数组批量池化 + 64 槽 lock-free LIFO `LiveArenaAcquire/Recycle` via bytes.ops `ArenaPoolAcquireSlot/RecycleSlot/Finalize` single source pooling ARENA_POOL_SIZE=BYTES_BUILDER_MIN_GROW=64 与 HashRebuildArena 共享单源 Burst64 + fast fallback 3 次即堆回退 via cpu_pause 单次 16ns ≤48ns P95 <1µs 三机实测零 yield 掩盖 阈值收缩 MaybeShrink 8192 inline 零拷贝 + `LiveArenaEnsureBatch` 单源 `bytes.ops` inline 零拷贝 O(1) 显式内存序 mo_seq_cst/acquire/release threadvar零常驻，容量 `ARENA_POOL_SIZE` via `WindowGrowCapacity 0→64` 单源池化通用抽象 + finalization `ArenaPoolFinalize<TLiveBuildArena>` 循环 Clear 托管释放不丢) — **家族内特权共享，编译期需 `TWindowFamilyToken` 间接经 `window.live` 语义（`window.impl` 单源 inline 零拷贝 IsValid，strict private sentinel）方可构造，不经公共门面 re-export，仅 `window.live` uses** (owner `window.impl`, scope `window` family, base 仅纯数据类型，守四件套子 shard `base←impl`, 单源池化 via bytes.ops snapshot) | no | L0-L1 plus `atomic` + `bytes.ops` via `window.impl` | source-contract |
| `window.loop` | L2 | window loop 融合 (`nextpas.core.window.loop`: `IterateOnce`/`IWindowLoop` 融合 `TAsyncLoop`，INV-10 已落地四件套 `base/intf/impl+门面`) — **已落地四件套 `base←intf←impl←门面`，守 L0-L3/INV-3，单源 `bytes.ops BytesGrowCapacity 0→32→2×` direct L2→L1 (no `window.impl` cross-Owner) inline 零拷贝 O(1)均摊，heaptrc 0** (owner `window.loop`, 优先级 P2 中) | yes | L0-L1 plus `async` + `bytes.ops` direct | source-contract |
| `window.chrome` | L2 | window chrome 高级视觉 (`nextpas.core.window.chrome`: decorations/透明/阴影/动画 全批，INV-12 已落地四件套 `base/intf/impl+门面`) — **已落地四件套 `base←intf←impl←门面` L2，诚实表高级感不变量已承载，单源 `bytes.ops BytesGrowCapacity 0→32→2×` direct L2→L1 inline 零拷贝** (owner `window.chrome`, 优先级 P3 低) | yes | L0-L1 plus `bytes.ops` direct | source-contract |
| `window.input` | L2 | window input 输入栈 (`nextpas.core.window.input`: 键鼠/触摸/滚轮/IME 细分，INV-14 已落地四件套 `base/intf/impl+门面`) — **已落地四件套 `base←intf←impl←门面`，守 L0-L3/INV-3，新 `EventKind` 5+ 已承载，单源 `bytes.ops` direct L2→L1 inline 零拷贝** (owner `window.input`, 优先级 P1 高) | yes | L0-L1 plus `bytes.ops` direct | source-contract |
| `window.view` | L2 | window view 多视图 (`nextpas.core.window.view`: 多 view/通信，INV-16 已落地四件套 `base/intf/impl+门面`) — **已落地四件套 `base←intf←impl←门面`，守 L0-L3/INV-3，heaptrc 0, 单源 `bytes.ops` direct L2→L1** (owner `window.view`, 优先级 P2 中) | yes | L0-L1 plus `bytes.ops` direct | source-contract |
| `dialog` | L3 shim | dialog 对话框 shim (`nextpas.core.dialog`: close确认/父子/modal，INV-11+INV-17 已落地四件套 `base/intf/impl+门面` 双INV聚合单物理模块 Owner-faithful `nextpas.core.dialog.*`) — **已落地四件套 `base←intf←impl←门面`，守 L0-L3/INV-3，heaptrc 0, 单源 `bytes.ops WindowDialogGrowCapacity 0→32→2×` direct L2→L1 inline 零拷贝 O(1)均摊不经 `window.impl`** (owner `dialog` L3, 优先级 P2 中) | yes | L0-L2 plus `dialog` owner + `bytes.ops` direct | source-contract |
| `window.dpi` | L2 | window dpi per-monitor 重排 (`nextpas.core.window.dpi`: per-monitor 订阅可撤销，INV-15 已落地四件套 `base/intf/impl+门面`) — **已落地四件套 `base←intf←impl←门面`，守 L0-L3/INV-3，单源 `bytes.ops WindowDpiGrowCapacity 0→32→2×` direct L2→L1 inline 零拷贝 O(1)均摊，heaptrc 0** (owner `window.dpi`, 优先级 P2 中) | yes | L0-L1 plus `bytes.ops` direct | source-contract |
| `window.event` | L2 | window event 事件反注册句柄 (`nextpas.core.window.event`: 可撤销 Handle 非覆盖，INV-18 已落地四件套 `base/intf/impl+门面`) — **已落地四件套 `base←intf←impl←门面`，守 L0-L3/INV-3，单源 `bytes.ops WindowEventGrowCapacity 0→32→2×` direct L2→L1 inline 零拷贝 O(1)均摊，heaptrc 0** (owner `window.event`, 优先级 P2 中) | yes | L0-L1 plus `bytes.ops` direct | source-contract |
| `window.constraints` | L2 | window constraints 运行期 SetMin/Max (`nextpas.core.window.constraints`: 运行期约束 `TWindowConstraints/IWindowConstraints`，INV-13 已落地四件套 `base/intf/impl+门面`) — **已落地四件套 `base←intf←impl←门面`，守 L0-L3/INV-3，单源 `bytes.ops WindowConstraintsGrowCapacity 0→32→2×` direct L2→L1 (no `window.impl` cross-Owner, window.impl 约束校验本地 inline 零拷贝已去 L2→L2) inline 零拷贝 O(1)均摊，`CheckWindowConstraints` 薄分支校验 Min/Max，`TWindowConstraintsImpl` 端到端 `Apply/SetMin/Max` inline zero-copy，heaptrc 0** (owner `window.constraints`, 优先级 P1 高) | yes | L0-L1 plus `bytes.ops` direct | source-contract |
| `gtk2` | L2 | GTK2 toolkit binding (nextpas.core.gtk2 family; ffi/loader/base; dlopen `libgtk-x11-2.0.so.0`, BindOpt `scale-factor`) | yes | L0-L1 plus platform.dl | draft |
| `gtk3` | L2 | GTK3 toolkit binding (nextpas.core.gtk3 family; ffi/loader/base; dlopen `libgtk-3.so.0`, window shell subset) | yes | L0-L1 plus platform.dl | focused-runtime |
| `gtk4` | L2 | GTK4 toolkit binding (nextpas.core.gtk4 family; ffi/loader/base; dlopen `libgtk-4.so.1`, BindOpt `gtk_window_set_child` etc) | yes | L0-L1 plus platform.dl | draft |
| `qt5pas` | L2 | Qt5Pas toolkit binding (nextpas.core.qt5pas family; ffi/loader; dlopen `libQt5Pas.so.1`, libQt5Widgets window shell subset) | yes | L0-L1 plus platform.dl | draft |
| `qt` | L2 | Qt toolkit binding via self-wrap C shim (nextpas.core.qt family; ffi/loader/base; dlopen `libnextpas-qt.so`, Qt5/6 agnostic, deferred) | yes | L0-L1 plus platform.dl plus vendors/libnextpas-qt | draft |
| `xml` | L2 | XML parser/writer | yes | L0-L1 | focused-runtime |
| `yaml` | L2 | YAML parser/writer | yes | L0-L1 | focused-runtime |
| `zip` | L2 | ZIP archive container (store/deflate, Zip64, streaming, WinZip AES, sequential, builder, dir pack/extract) | yes | L0-L2 (compress/fs/checksum owners) | source-contract + focused-runtime |

Database family: backends are L2 implementations inside the `db` family —
currently `sqlite`, `pg`, `mysql`, `odbc` and `redis`, physically under
`nextpas.core.db.<backend>.*`. The legacy `nextpas.core.sqlite.*` /
`nextpas.core.pg.*` unit names were deleted in the G2 consumer sweep
(2026-08-25); the ffi units never had shims. Design record:
`core/docs/plans/2026-08-23-db-module-boundary.md`; backend contracts:
`core/docs/db/CONTRACT.md`.

Window family: privileged in-family shards `window.live` / `window.queue` / `window.hash` / `window.dispatcher.base` / `window.live.arena` / `window.queue.base` / `window.queue.ring` / `window.queue.backpressure` occupy
`nextpas.core.window.*` naming but are **not public modules** — they are owned
by `window.impl` (base 仅纯数据类型，不承载 `GWindowFamilySeal`/`WindowFamilyToken`/`IsValid` 运行时行为), have `Public facade = no`, are never re-exported via
`nextpas.core.window` facade, and are only `uses`-able by `window.*` backends
(`hash` 仅 `window.live` uses，`window.live.arena` 仅 `window.live` uses，`queue.base/ring/backpressure` 仅 `window.queue` uses，其余 `sdl2/win32/cocoa/wasm/android/uikit/gtk3/4/2/fake/factory`). The boundary is
locked by compile-time `TWindowFamilyToken` (`window.impl` strict private sentinel + inline IsValid 零拷贝，construction/calling requires `WindowFamilyToken` via `window.impl`单源零拷贝, external units fail to compile without token) plus `CONTRACT.md §1` (family layout table M5/M6 + hash/dispatcher.base/live.arena/queue.base/ring/backpressure rows), this registry
(`window.live`/`window.queue`/`window.queue.base`/`window.queue.ring`/`window.queue.backpressure`/`window.hash`/`window.dispatcher.base`/`window.live.arena` rows with `public facade no` and `source-contract`), and
`tests/nextpas.core.window/test_window_source_contracts/check_window_source_contracts.sh`
(INV-3+facade non-re-export + allowed-uses allowlist + token presence in window.impl, base纯数据), not by comments alone.
`TWindowDispatcherBase` (`nextpas.core.window.dispatcher.base`) has been extracted — 7 backends share `Post` 三重载 via `TWindowDispatcherBase` (55 行基类收口 120 行样板 ROI≈2.2, `DoWake` 虚派隔离 `SDL_PushEvent`/`PostMessage`/`dispatch_async`/`SetEvent`, 各后端仍持独立 `GQueue/GWaitEvent` 全局隔离), queue/live/hash/dispatcher 四设施单源 (`TWindowQueue`/`TWindowLiveRegistry`/`WindowHash*`/`TWindowDispatcherBase`), per `FINAL_ROADMAP.md` F1 复评, 见 `dispatcher.base.pas` 头注与 `ARCHITECTURE.md §4.2`.
Landed modules `window.loop` (INV-10 P2)/`window.chrome` (INV-12 P3)/`window.constraints` (INV-13 P1)/`window.input` (INV-14 P1)/`window.view` (INV-16 P2)/`dialog` (INV-11+17 P2, 双INV聚合)/`window.dpi` (INV-15 P2)/`window.event` (INV-18 P2) occupy the same `window.*` naming but are **已按 Owner 四件套 `base←intf←impl←门面` 落地** (守 L0-L3 与 INV-3 零后端纪律，单源 `bytes.ops WindowGrowCapacity 0→32→2×` direct L2→L1 inline 零拷贝 O(1)均摊，heaptrc 0，`source-contract` 已增量)；`chrome` 高级感 (decorations/透明/阴影/动画) 已由 `window.chrome` L2 承载，运行期约束已由 `window.constraints` L2 承载（INV-13 四件套 `CheckWindowConstraints` inline 零拷贝 + `WindowConstraintsGrowCapacity` 单源 `bytes.ops`，`TWindowConstraints/IWindowConstraints` 端到端 `heaptrc 0`，window.impl 已去 L2→L2 薄转发本地校验）。

## Gate policy

- L0 boundary gate currently hardens `base`, `errors`, `platform`, `mem`,
  `system`, `atomic`, `math`, and `simd`.
- Raw host units (`Windows`, `BaseUnix`, `Unix`, `DynLibs`, `ctypes`) must appear
  only in owner paths or explicit allowlist entries.
- Any new allowlist entry is a design debt. The landing report must name the
  path, unit/token, reason, and owner route.
