# nextpas.core.io 代码契约

**模块路径**：`core/src/nextpas.core.io*.pas`（24 个源文件）
**层级**：L1（依赖 L0: base, bytes, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-09-02
**版本**：1.2（新增 io.prefix 可复用前缀旁路流：由 vfs.transform 抽取独立，供 io/os/embedded/vfs 复用，Seek-free 零拷贝，bytes.ops 单源 inline，try-finally 不丢）

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| io.base | 基础类型和常量 |
| io.intf | IReader, IWriter, IFlusher 接口定义 |
| io.binary | TBinaryReader, TBinaryWriter 二进制读写 |
| io.buffer | TBufferedReader, TBufferedWriter 缓冲读写 |
| io.collect | 收集器 |
| io.linewriter | ILineWriter, TLineWriter 行写入 |
| io.memory | TBytesStream 内存流 |
| io.pipe | 管道 Pipe |
| io.scanner | IScanner 扫描器 |
| io.util | Copy/CopyN/ReadAll 等工具 |
| io.stream_adapter | ~~Classes 流适配~~（G7 已删除，见 IStream-ectomy） |
| io.poller | 统一轮询器 TPoller |
| io.reactor | io_uring Reactor (Linux) |
| io.reactor.epoll | epoll Reactor (Linux) |
| io.reactor.kqueue | kqueue Reactor (macOS/BSD) |
| io.reactor.iocp | IOCP Reactor (Windows) |
| io.uring | io_uring 底层封装 |
| io.mapped | 内存映射文件 |
| io.mapped.ring_buffer | 环形缓冲区 |
| io.mapped.ring_buffer.sharded | 分片环形缓冲区 |
| io.mapped.slab_pool | slab 内存池 |
| io.async.fileio | 异步文件 IO |
| io.prefix | TPrefixBypassStream 通用前缀旁路流（L1 可复用装饰器，供 io/os/embedded/vfs 复用，Seek-free 零拷贝，bytes.ops 单源，chunked streaming 友好） |
| io.pas | 门面 re-export |

### 1.2 核心接口

```pascal
IReader = interface
  function Read(var ABuffer; ACount: SizeInt): SizeInt;
  function ReadAll: TBytes;
  function ReadLine: string;
  function EOF: Boolean;
end;

IWriter = interface
  function Write(const ABuffer; ACount: SizeInt): SizeInt;
  procedure WriteAll(const AData: TBytes);
  procedure WriteLine(const ALine: string);
end;

ILineWriter = interface(IWriter)
  procedure WriteLines(const ALines: TStringArray);
end;
```

### 1.3 核心类型

```pascal
TBinaryReader = record
  // 小端序读取
end;

TBinaryWriter = record
  // 小端序写入
end;

TBufferedReader = class(TInterfacedObject, IReader, IByteReader, IByteScanner)
  // 缓冲读取
end;
```

---

## 2. 不变量

- TBinaryReader/Writer 使用小端序
- TBufferedReader 默认缓冲区 8KB
- EOF 后 Read 返回 0

---

## 3. 错误处理

- IO 错误抛 `EIOError`
- EOF 不抛异常

---

## 4. 线程安全

- IReader/IWriter 实例非线程安全
- 调用方自行同步

---

## 5. 内存管理

- IReader/IWriter 通过引用计数自动释放
- ReadAll 返回的 TBytes 由调用方负责释放

---

## 6. 测试覆盖

- `test_io`: Binary/Buffer/LineWriter/Mapped/Collect 测试
