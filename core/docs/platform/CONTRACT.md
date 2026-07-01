# nextpas.core.platform 代码契约

**模块路径**：`core/src/nextpas.core.platform*.pas`（59 个源文件）
**层级**：L0（依赖 FPC RTL）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| platform.base | TPlatformLibrary, 基础类型 |
| platform.error | EPlatformError, 平台错误处理 |
| platform.console | 控制台 I/O |
| platform.env | 环境变量 |
| platform.args | 命令行参数 |
| platform.dl | 动态库加载 |
| platform.io | 文件 I/O |
| platform.socket | 网络 Socket |
| platform.thread | 线程管理 |
| platform.mutex | 互斥锁 |
| platform.rwlock | 读写锁 |
| platform.condvar | 条件变量 |
| platform.semaphore | 信号量 |
| platform.pas | 门面 re-export |

### 1.2 平台支持

| 平台 | 平台文件 | 状态 |
|------|----------|------|
| Linux x86_64 | platform.linux.* | 完成 |
| macOS x86_64 | platform.darwin.* | 完成 |
| Windows x86_64 | platform.windows.* | 完成 |
| Android | platform.android.* | 完成 |

### 1.3 核心 API

```pascal
// 文件 I/O
function PlatformOpen(const APath: string; AFlags: Integer): TPlatformHandle;
function PlatformRead(AHandle: TPlatformHandle; var ABuffer; ACount: SizeInt): SizeInt;
function PlatformWrite(AHandle: TPlatformHandle; const ABuffer; ACount: SizeInt): SizeInt;
procedure PlatformClose(AHandle: TPlatformHandle);

// 网络
function PlatformSocketCreate(AFamily, AType, AProto: Integer): TPlatformHandle;
function PlatformConnect(AHandle: TPlatformHandle; const AAddr: TPlatformAddr): Integer;
function PlatformBind(AHandle: TPlatformHandle; const AAddr: TPlatformAddr): Integer;

// 线程
function PlatformThreadCreate(AProc: TThreadProc; AArg: Pointer): TPlatformHandle;
procedure PlatformThreadJoin(AHandle: TPlatformHandle);
```

---

## 2. 不变量

- TPlatformHandle 无效值为 -1（Unix）或 INVALID_HANDLE_VALUE（Windows）
- Socket 句柄 >= 0（Unix）或 > 0（Windows）
- 文件描述符 0/1/2 保留给 stdin/stdout/stderr

---

## 3. 错误处理

- 所有平台调用失败抛 `EPlatformError`（含 errno/GetLastError）
- `EPlatformError.Code` 为平台错误码

---

## 4. 线程安全

- 平台原语本身线程安全
- mutex/rwlock/condvar/semaphore 遵循 POSIX 语义

---

## 5. 内存管理

- 平台句柄由调用方负责关闭
- mmap 映射由调用方负责 munmap

---

## 6. 测试覆盖

- `test_platform_io`: 文件 I/O 测试
- `test_platform_socket`: Socket 测试
- `test_platform_thread`: 线程/mutex/rwlock/condvar 测试
