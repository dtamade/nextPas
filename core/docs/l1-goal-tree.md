# nextPas Core Framework — 目标树

> 最后更新: 2026-06-07 | 本轮证据: atomic 34/34 + adjacent lockfree 37/37, heaptrc 0

## 定位

nextPas Core 是 FreePascal 领域最优秀的框架之一。分三层：
- **L0**: base/errors/platform/mem — OS 底座
- **L1**: bytes/text/encoding/collections/sync/thread/lockfree/async/io/time/id/testing — 基础设施
- **L2**: fs/net/json/toml/yaml/compress/regex/log/encoding/hash/crypto — 领域能力
- **L3**: http/args/process/coroutine/event — 应用层

## L0 模块状态

| 模块 | 职责 | 状态 |
|------|------|------|
| `base` | 核心类型、异常、TByteSpan、契约 | ✅ 完成 |
| `errors` | 异常层级 (ENextPasError 体系) | ✅ 完成 |
| `platform` | OS API 封装 (posix/linux/darwin/windows) | ✅ 完成 (Tier 1 全绿) |
| `mem` | 内存管理 (IAllocator/Pool/Arena/StackPool) | ✅ 完成 |
| `atomic` | 原子操作 (Load/Store/CAS/Fetch*, 全内存序) | ✅ 完成/强化中 (public contract hardening, typed records + 32/64-bit + pointer-sized RMW + refcount zero-state/concurrent-borrow/terminal-race contracts 34 tests) |
| `math` | 数学函数 (Min/Max/Clamp/Abs/Pow/Trig) | ✅ 完成 |
| `simd` | SIMD 抽象 (SSE2/AVX2/NEON, 统一宽度 API) | ✅ 完成 |

## L1 模块状态

| 模块 | 职责 | 状态 |
|------|------|------|
| `bytes` | 字节容器、字节序、Builder | ✅ 完成 (ops+binary+builder, 33 tests, bench) |
| `text` | 字符串操作、Unicode、格式化、conv | ✅ 完成 (base+conv+format+builder, 自实现 Format, 0 SysUtils) |
| `encoding` | 编解码 (base64/hex/url/varint) | ✅ 完成 (23 tests, Codex审查3项修复) |
| `collections` | 20+ 容器 (Vec/HashMap/Deque/BTree/SwissTable/SkipList/LRU/Trie) | ✅ 完成 (422+ tests, SwissTable Get 超越 Rust 7%) |
| `sync` | 同步原语 (Mutex/RWLock/CondVar/WaitGroup/Once/Semaphore/Barrier/SpinLock) | ✅ 完成 (28 tests, Codex审查) |
| `thread` | 线程池/WorkStealing/Channel/Future/Cancel | ✅ 完成 (18 tests, Codex审查) |
| `lockfree` | 无锁 (MPMC/SPSC/MPSC/Stack/Deque) | ✅ 完成/强化中 (37 default + 37 debug + 8 stress, Close wait/timeout wake contract, MPMC single-slot sequence states, managed-type rejection cleanup, stack/deque query contract, tagged-ptr ABA) |
| `async` | 事件循环 (io_uring+epoll双后端, timer heap, timeout) | ✅ 完成 (31 tests, Codex审查5项修复) |
| `io` | 流抽象 (IReader/IWriter/IStream/Buffer/Scanner/Pipe) | ✅ 完成 (46 tests, Go parity) |
| `time` | DateTime/Duration/Deadline/Sleep/Timer/Ticker/Period | ✅ 完成 (Wave 1-5, 49 tests, ISO 8601) |
| `id` | UUID/ULID/Snowflake/NanoID/KSUID/XID/V7 | ✅ 完成 (70 tests) |
| `testing` | TTestRunner 测试框架 | ✅ 完成 |
| `stopwatch` | 高精度计时 | ✅ 完成 (15 tests) |

## L2 模块状态

| 模块 | 职责 | 状态 |
|------|------|------|
| `fs` | 文件系统 (IFile/Walk/Symlink/Atomic) | ✅ 完成 (47 tests, Codex审查10项全修) |
| `net` | 网络 (TCP/UDP/Resolve, deadline) | ✅ 完成 (24 tests, Codex审查) |
| `json` | JSON (parser/builder/reader/writer/marshal) | ✅ 完成 (98 tests, 3-12x fpjson) |
| `toml` | TOML v1.0+v1.1 | ✅ 完成 (291 tests, 6-8x Rust toml-rs) |
| `yaml` | YAML (scanner/parser/builder) | ✅ 完成 (77 tests, 10x Go yaml.v3) |
| `compress` | deflate/gzip/lz4 | ✅ 完成 (26 tests) |
| `regex` | Thompson NFA + DFA, SIMD first-byte | ✅ 完成 (115 tests, Phase 4 API 完整) |
| `log` | 结构化日志 (async, audit, multi-handler) | ✅ 完成 (102 tests) |
| `hash` | WyHash + SHA-256/MD5 | ✅ 完成 |
| `crypto` | P-256 field (ASM multiply, 常量时间) | 🔶 进行中 |

## L3 模块状态

| 模块 | 职责 | 状态 |
|------|------|------|
| `http` | HTTP server/client (radix router, middleware, H1 writer) | 🔶 Phase 1 完成 (88 tests), H1 parser 待实现 |
| `args` | CLI 解析 (TArgParser+TArgApp, 子命令路由) | ✅ 完成 (56 tests) |
| `process` | 子进程 (spawn/pipe/env/wait) | ✅ 完成 (45 tests) |
| `coroutine` | 协程调度器 | ✅ 完成 (10 tests) |
| `event` | 事件总线 (priority dispatch) | ✅ 完成 |
| `props` | 属性系统 | ✅ 完成 (11 tests) |

## 下一步优先级

1. **HTTP Phase 2**: H1 parser (llhttp 翻译) + Server accept loop + Client 连接池
2. **TLS/Crypto**: P-256 完整 ECDH + TLS 1.3 握手
3. **性能基准**: 系统性 benchmark vs Go/Rust/FPC RTL（collections/json/toml/regex/compress）

## 质量门禁

- 100% 接口测试覆盖
- heaptrc 验证 0 内存泄漏
- Codex 独立审查关键模块
- 每轮 git 提交，变更清晰可追溯
- 框架纪律：用自有 API（CopyNonOverlap, IAllocator），不依赖 SysUtils
