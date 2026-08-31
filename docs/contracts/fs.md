# nextpas.core.fs 代码契约

> 模块路径: `core/src/nextpas.core.fs.*.pas`（9 源文件）
> 层级: L2（依赖 L0-L1）
> 维护者: AI
> 最后更新: 2026-07-20
> 版本: 1.15

详细契约以 `core/docs/fs/CONTRACT.md` 为单源（Single Source）；本文为浅层索引，不重复正文，仅对齐四件套与 L0-L3 分层。

---

## 概述

L2 文件系统门面。提供文件读写、目录遍历、路径操作、Glob 匹配、文件锁与文件监视。所有能力经 `platform.fs / platform.path / platform.watch` 抽象，不直接 `uses` FPC RTL 裸单元（`SysUtils/BaseUnix` 等）；详见 `core/docs/fs/CONTRACT.md` INV-7。

---

## 模块结构（四件套）

```
nextpas.core.fs.base.pas     ← 基础类型（TFileMode, TFileInfo, TDirEntry, TFileLockKind, 权限常量）
nextpas.core.fs.intf.pas     ← 接口定义（IFile, IDirIterator）
nextpas.core.fs.stream.pas   ← IFile 流实现
nextpas.core.fs.path.pas     ← 路径操作（Join/Dir/Base/Ext/Clean/Abs/Match）
nextpas.core.fs.dir.pas      ← 目录操作（Mkdir/Remove/Walk/ReadDir/CopyTree）
nextpas.core.fs.util.pas     ← 文件工具（ReadFile/WriteFile/Stat/Symlink/Chmod/Chtimes/Chown/…）
nextpas.core.fs.glob.pas     ← Glob 匹配（GlobMatch/FsGlob）
nextpas.core.fs.watch.pas    ← 文件监视（Watch/IFsWatcher, 委托 platform.watch）
nextpas.core.fs.errors.pas   ← 异常分类
nextpas.core.fs.pas          ← 门面：纯 re-export + inline 转发
```

依赖方向：`base ← intf ← 实现（stream/util/dir/path/glob/watch） ← 门面`。符合 L0-L3：L2 仅依赖 L0（base/errors/platform）与 L1（bytes/text），不向上依赖。

---

## 单源复用

- 路径算法单源：`nextpas.core.path`；fs 仅转发 `PathJoin2/PathClean/PathMatch` 等，不自实现重复逻辑。
- 字节视图单源：`nextpas.core.bytes.ops`（`SpanEqual/SpanCompare/MemEqual` 零拷贝）；fs 读写路径复用该单源，禁止手写重复循环。
- 通配匹配单源：`fs.glob` 委托 `wildmatch` 语义（`* ? [...] **`），不分散实现。
- 平台能力单源：全部经 `platform.*`（`platform_file_*`/`platform_path_*`/`platform_watch_*`）；禁止直调 `fpOpen/BaseUnix/SysUtils`。

---

## 关键接口（索引）

完整签名与语义见 `core/docs/fs/CONTRACT.md` §1 与 `core/src/nextpas.core.fs.pas`。

| 领域 | 代表函数 | 说明 |
|------|----------|------|
| 路径 | `PathJoin/PathJoin2/PathJoin3/PathDir/PathBase/PathExt/PathClean/PathAbs/PathIsAbs/PathMatch` | 组合/解析/匹配 |
| 文件 | `Open/Create/OpenLocked/ReadFile/ReadFileText/ReadFileLines/WriteFile/WriteFileText/WriteAtomic/CopyFile/CloneFile` | 读写与原子写入 |
| 目录 | `Mkdir/MkdirAll/Remove/RemoveAll/Rename/ReadDir/OpenDir/Walk/CopyTree` | 目录增删遍历 |
| 属性 | `Stat/Lstat/Exists/IsDir/IsFile/IsSymlink/SameFile/FileSize/Chmod/Truncate/Symlink/Readlink/HardLink/Chtimes/Chown` | 元信息与链接 |
| Glob | `GlobMatch/Glob/FsGlob` | 通配匹配 |
| 锁 | `IFile.Lock/TryLock/Unlock, OpenLocked` | 整文件 advisory 锁（R23） |
| 监视 | `Watch/IFsWatcher.Add/AddTree/Remove/Poll` | 文件监视（R25/R29/R32） |
| 位置IO | `IFile.ReadAt/WriteAt` | 不改变 Position 的 pread/pwrite（R34） |
| 兼容壳 | `FileExists/DirectoryExists/ForceDirectories/DeleteFile/GetEnv/Param*` | SysUtils 兼容（lossy） |

---

## 不变量（索引）

以 `core/docs/fs/CONTRACT.md` §2 INV-1..INV-15 为准，浅层仅索引：

- INV-1 空/nil 路径抛 `EArgumentNil`；INV-2 `ReadFileText` 返回完整拷贝；INV-3 `GlobMatch * ? [...]`；INV-4 `MkdirAll` 已存在静默成功；INV-5 `Mkdir/Remove/Rename` 为 procedure（失败抛异常），`ForceDirectories/DeleteFile` 为 Boolean 兼容壳（吞异常类型）；INV-6 `PathJoin/PathDir/PathIsAbs` 别名与裸名语义；INV-7 FPC RTL 隔离；INV-8 `Remove` 对 ENOENT 静默成功；INV-9 `GetEnv/Param*` 为兼容入口；INV-10 `IsSymlink` 不跟随、不存在 False；INV-11 `SameFile` Dev+Ino、不存在抛 `ENotFoundError`；INV-12 `HardLink/Chtimes/Chown` 经 platform、时间纳秒；INV-13 文件锁绑定句柄、关闭释放；INV-14 监视 `Poll/AddTree/Remove/Kind`；INV-15 `ReadAt/WriteAt` 不改 Position。

---

## 错误语义

| 场景 | 异常 |
|------|------|
| 文件不存在 | `ENotFoundError` |
| 权限不足 | `EPermissionError` |
| 磁盘满/内存不足 | `EResourceExhaustedError`（ENOSPC/ENOMEM 映射） |
| 其它 I/O | `EIOError` |
| 路径无效/空 | `EArgumentError`/`EArgumentNil` |

`MkdirAll/Remove` 等 procedure 抛异常；`ForceDirectories/DeleteFile` 返回 Boolean（吞类型，仅 True/False）。

---

## 线程安全

所有函数为纯函数（无共享状态），线程安全；同一文件的并发读写由调用方负责。`IFile` 实例不线程安全，需外部同步。

---

## 内存与资源管理

- `ReadFile/ReadDir` 分配返回内容，调用方持有；无全局缓存。
- `IFile/IDirIterator/IFsWatcher/IScanner/IMappedLines` 为接口，走引用计数；文件句柄与锁随接口释放（`Close`/`Free`）自动释放，OS 回收锁；`try/finally` 或接口作用域保证不泄漏，异常不丢（`OpenLocked` 锁失败先关句柄再抛）。
- `RemoveAll/Walk` 迭代式实现，不栈溢出。

---

## 性能

- 门面全部 `inline` 转发至 `fs.util/dir/path/glob`，零额外调用开销；编译器可内联消除。
- 读写路径零拷贝：`TBytes/string` 与 `PByte+Len` 视图（`TByteSpan`）直通 `platform_file_*` / `bytes.ops.MemEqual`，不做多余拷贝；`WriteAtomic` 先写临时文件再 `rename`（原子性，无半写）。
- 热路径（`GlobMatch/PathMatch/SameFileName`）`inline`；批量目录读取预分配并按需扩容。

---

## 依赖关系

- 依赖: `base, bytes, text.base, platform.fs, platform.path, platform.watch, platform.error`
- 被依赖: `config, http.static, tls, process` 等 L3

---

## 测试覆盖

以 `core/docs/fs/CONTRACT.md` §6 为准；入口：

```bash
make -C core/tests/nextpas.core.fs/test_fs clean test
make -C core/tests/nextpas.core.fs/test_fs_watch clean test
```

9 个测试目录（`test_fs/test_fs_glob/test_fs_facade/test_fs_idir/test_fs_ifile/test_fs_text/test_fs_watch/test_fs_wine/test_fs_watch_wine`），合计约 260+ 用例，`heaptrc 0 leak` 为门禁。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-04 | 1.0 | 初始版本 | AI |
| 2026-07-19 | 1.1-1.10 | 测试口径/INV-5 procedure/Path 别名/FPC RTL 隔离/IsSymlink/SameFile 等 | AI |
| 2026-07-20 | 1.11 | ENOSPC/ENOMEM → EResourceExhaustedError | AI |
| 2026-07-20 | 1.12 | IFile.Lock/TryLock/Unlock + OpenLocked（R23） | AI |
| 2026-07-20 | 1.13 | AddTree 递归监视（R29） | AI |
| 2026-07-20 | 1.14 | ReadAt/WriteAt（R34） | AI |
| 2026-07-20 | 1.15 | M2-W4 Win 支持矩阵 + wine 最小生产集 | AI |
