# nextpas.core.platform 代码契约

> 模块路径: `core/src/nextpas.core.platform.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

平台抽象层。将操作系统差异（Linux/Darwin/Windows/FreeBSD/Android）封装为统一接口。
所有高层模块通过 platform 访问系统能力，不直接调用 FPC RTL 平台 API。

---

## 模块族

| 子模块 | 职责 | 门面入口 |
|--------|------|---------|
| `platform.base` | 平台检测常量和基础类型 | 直接使用 |
| `platform.time` | 单调时钟/实时时钟/QPC 转换 | `platform_monotonic_ns` |
| `platform.mmap` | 内存映射/mprotect/madvise | `platform_mmap` |
| `platform.memory` | 虚拟内存页面操作 | `platform_page_*` |
| `platform.fs` | 文件系统操作 | `platform_fs_*` |
| `platform.path` | 路径操作 | `platform_path_*` |
| `platform.env` | 环境变量 | `platform_env_*` |
| `platform.error` | 错误码翻译 | `platform_errno_*` |
| `platform.thread` | 线程原语 | `platform_thread_*` |
| `platform.sync` | 互斥/条件变量/信号量 | `platform_mutex_*` |
| `platform.signal` | 信号处理 | `platform_signal_*` |
| `platform.process` | 进程管理 | `platform_process_*` |
| `platform.dl` | 动态库加载 | `platform_dl_*` |
| `platform.pipe` | 管道 | `platform_pipe_*` |
| `platform.io` | 异步 I/O | `platform_io_*` |
| `platform.net`/`platform.socket` | 网络 | `platform_socket_*` |
| `platform.random` | 安全随机 | `platform_random_*` |
| `platform.info` | 系统信息 | `platform_info_*` |
| `platform.console` | 终端控制 | `platform_console_*` |
| `platform.args` | 命令行参数 | `platform_args_*` |
| `platform.watch` | 文件监视 | `platform_watch_*` |
| `platform.pty` | 伪终端 | `platform_pty_*` |
| `platform.which` | 可执行文件查找 | `platform_which_*` |
| `platform.fmt` | 格式化输出 | `platform_fmt_*` |
| `platform.freetype` | FreeType FFI | `platform_ft_*` |

---

## 关键接口

### 时钟 (`platform.time`)

```pascal
function platform_monotonic_ns: TPlatformTimeNanoseconds;
function platform_realtime_ns: TPlatformTimeNanoseconds;
function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds;
function platform_qpc_to_ns(ACounter, AFrequency): TPlatformTimeNanoseconds;
function platform_utc_offset_seconds: Int32;
procedure platform_time_breakdown_utc(ANs, out AResult: TPlatformTimeBreakdown);
```

### 内存映射 (`platform.mmap`)

```pascal
function platform_mmap(ASize, AProt, AFlags): Pointer;
function platform_munmap(APtr, ASize): Boolean;
function platform_mprotect(APtr, ASize, AProt): Boolean;
function platform_madvise(APtr, ASize, AAdvice): Boolean;
```

---

## 前置条件

1. 时钟函数: 无（返回 0 表示不可用）
2. `platform_mmap`: ASize > 0
3. `platform_munmap`: APtr 必须是 mmap 返回的地址
4. 所有平台函数: 调用方负责参数有效性

---

## 后置条件

1. `platform_monotonic_ns`: 永不回退（单调递增）
2. `platform_realtime_ns`: 可能因系统调时跳变
3. `platform_mmap`: 返回 PAGE_SIZE 对齐的地址

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 平台函数失败 | 返回错误码或 nil，不抛异常 |
| 时钟不可用 | 返回 0 |
| mmap 失败 | 返回 nil |

---

## 线程安全

- 所有平台函数线程安全（底层是系统调用）
- 时钟函数可安全并发调用

---

## 依赖关系

- 依赖: FPC RTL（System, BaseUnix, DynLibs 等）
- 被依赖: 几乎所有 core/ 模块

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
