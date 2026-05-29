# nextPas L1 基础设施模块 — 目标树

## 定位

L1 是框架的基础设施层，只依赖 L0（base/errors/platform/mem）。
为 L2（fs/net/crypto/json 等）和 L3（http/websocket/tui 等）提供通用能力。

## 模块清单与状态

| 模块 | 职责 | 状态 |
|------|------|------|
| `bytes` | 字节容器、字节序、Builder | ✅ 完成 (ops+binary+builder, 33 tests, bench) |
| `text` | 字符串操作、Unicode、格式化 | ✅ 完成 (base+conv+format, 35 tests, 0 SysUtils) |
| `encoding` | 编解码 (base64/hex/url/varint) | ✅ 已有 |
| `collections` | 容器 (Vec/HashMap/Deque/Set/List/LRU) | ✅ 已有 |
| `sync` | 同步原语 (Mutex/RWLock/Atomic/WaitGroup/Once/Semaphore/Barrier/Event) | ✅ 完成 (28 tests, 3轮Codex审查) |
| `thread` | 线程池、Channel、Future、CancellationToken | ✅ 完成 (18 tests, 3轮Codex审查) |
| `lockfree` | 无锁数据结构 (MPMC Channel/SPSC Queue) | ⬜ 待建 |
| `async` | 事件循环、Reactor、异步运行时 | ⬜ 待建 |
| `io` | 流抽象 (Reader/Writer/Buffer/Scanner/Pipe) | ✅ 完成 (Go parity, 46 tests, bench, Scanner) |
| `time` | DateTime/Duration/Timer/Stopwatch | 🔶 Wave 1-2 done, Wave 3-5 待做 |
| `id` | UUID/ULID/Snowflake/NanoID | ✅ 已有 (15 tests) |
| `testing` | 测试框架 | ✅ 已有 (TTestRunner) |

## L2 模块状态

| 模块 | 职责 | 状态 |
|------|------|------|
| `fs` | 文件系统 (IFile/IDirIterator/Path/Symlink/Walk) | ✅ 完成 (35 tests, bench, Codex审查10项全修) |
| `net` | 网络 (TCP/UDP/Resolve, ITcpStream extends IStream) | ✅ 完成 (7 tests, Codex审查修复, 跨平台) |

### T1: 基础字符串操作 ✅
- [x] Trim/Split/Join/Replace/Case/Pad/Repeat/IndexOf
- [x] UTF-8 Length/CodePointAt
- [x] 21 tests

### T2: 数字转换 (text.conv) ✅
- [x] IntToStr/UIntToStr/IntToHex
- [x] TryStrToInt/TryStrToInt32/TryStrToUInt64/StrToInt
- [x] FloatToStr/TryStrToFloat
- [x] TextOfChar
- [x] 9 tests

### T3: 格式化引擎 (text.format) ✅
- [x] TextFormat: %d/%u/%x/%X/%s/%f, 宽度/精度, %%
- [x] 5 tests

### T4: 门面补全 + SysUtils 消除
- [ ] text.pas re-export conv + format 全部 API
- [ ] text.pas 用 TextOfChar 替换 StringOfChar，去掉 SysUtils

### T5: text.builder (高性能字符串构建)
- [ ] IStringBuilder interface
- [ ] Append/AppendChar/AppendInt/AppendLine/ToString
- [ ] 基于 IAllocator raw memory

## 下一步优先级

1. **T4**: text 门面补全 + 去 SysUtils（收尾当前模块）
2. **time Wave 3-5**: Timezone/Timer/Period（依赖 text.format）
3. **io**: IReader/IWriter/IStream 流抽象（bytes/text 的下游消费者）
4. **sync**: Mutex/RWLock/Condvar（platform.sync 的 L1 封装）

## 质量门禁

- 100% 接口测试覆盖
- heaptrc 验证 0 内存泄漏
- 每轮 /codex 复盘
- 每轮 git 提交
