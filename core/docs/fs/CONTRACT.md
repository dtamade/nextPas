# nextpas.core.fs 代码契约

**模块路径**：`core/src/nextpas.core.fs*.pas`（9 个源文件）
**层级**：L2（依赖 L0-L1）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.16

---

## 1. 接口契约

### 1.1 模块结构

```
fs.base          ← 路径类型、TFileEntry 记录、权限常量
fs.path          ← 路径操作（Join/ExtractFileName/ChangeExt...）
fs.dir           ← 目录操作（CreateDir/RemoveDir/GetCurrentDir...）
fs.file          ← 文件操作（ReadAll/WriteAll/Copy/Delete...）
fs.glob          ← GlobMatch 文件名匹配（* ? [...] 模式）
fs.pas           ← 门面 re-export
```

### 1.2 核心函数

| 领域 | 函数 | 说明 |
|------|------|------|
| 路径 | PathJoin, PathDir, PathBase, PathExt, PathIsAbs | 路径组合/解析 |
| 文件 | ReadFile, ReadFileText, ReadFileLines, WriteFile, WriteFileText | 文件读写 |
| 文件 | CopyFile, DeleteFile, RenameFile, Exists | 文件操作 |
| 目录 | Mkdir, MkdirAll, Remove, RemoveAll | 目录操作 |
| 遍历 | ReadDir, OpenDir, Walk | 目录遍历 |
| 信息 | FileSize, Stat, Lstat, IsDir, IsFile | 文件属性 |
| Glob | GlobMatch, FsGlob | 通配符匹配 |
| 临时 | GetTempDir, TempFile | 临时文件 |
| 符号链接 | Symlink, Readlink | 符号链接操作 |
| 文件锁 | IFile.Lock/TryLock/Unlock, OpenLocked | 整文件 advisory（R23） |
| 其他 | Chmod, Truncate, Rename, WriteAtomic | 其他操作 |

---

## 2. 不变量

- **[INV-1]** 所有文件操作在 nil/空路径时抛 EArgumentNil
- **[INV-2]** ReadAllText 返回完整内容的 string 拷贝
- **[INV-3]** GlobMatch 支持 `*`, `?`, `[...]` 模式
- **[INV-4]** CreateDirAll 递归创建，已存在时静默成功
- **[INV-5]** Mkdir/MkdirAll/Remove/RemoveAll/Rename 为 **procedure**：失败抛异常，成功无返回值。`ForceDirectories`/`DeleteFile` 保留 Boolean 兼容壳（内部 try/except，**吞掉异常类型**；要错误分类请用 procedure API）
- **[INV-6]** path 命名：`PathIsAbsolute`≡`PathIsAbs`，`PathNormalize`≡`PathClean`；`PathJoin2(a,b)` 对齐 path 二元 Join。门面 `PathDir`/`PathSplit` 仅对**无分隔符**裸名把 `'.'`→`''`；`./x` 保留 `'.'`；`FsPathDir` 始终 Go **`.`**。**混用风险**：不要假设 `fs.PathJoin` 为二元；裸名目录语义选 path 门面或 `FsPathDir` 须自觉（见 path README 决策树）。
- **[INV-7]** **FPC RTL 隔离 / 编译器无关**：`nextpas.core.fs*` / `path` / `os.env` 源码与本模块测试不得 `uses` 裸 FPC RTL 单元；能力经 platform / core 抽象。仅 `nextpas.core.system` 可直接引用 FPC RTL。文档中的「SysUtils 兼容」指 API 形状，不是 `uses SysUtils`。门禁：`test_fs` 真 uses 扫描（`fpc_rtl_uses_scan.inc`）。
- **[INV-8]** `Remove` 对 ENOENT **静默成功**（对齐 Pascal Erase/DeleteFile；≠ Go `os.Remove`）。
- **[INV-9]** 门面 `GetEnv`/`Param*` 为 **兼容入口**；新代码用 `nextpas.core.os.env` / `args`（见 README）。
- **[INV-10]** `IsSymlink(APath)` / `FsIsSymlink`：不跟随链接；路径不存在返回 False（对齐常见「探测」语义，非抛错）。
- **[INV-11]** `SameFile`/`FsSameFile`：lstat Dev+Ino；路径不存在抛 `ENotFoundError`。
- **[INV-12]** `HardLink`/`Chtimes`/`Chown`：经 `platform_file_link`/`utimens`/`chown`；空路径 `EArgumentError`；Chtimes 时间为 **Unix 纳秒**（与 `Stat.ModTime` 同单位）；`Chown` 跟随 symlink（对齐 Go）；Windows 上 `Chown` 映射为不支持错误。
- **[INV-13]** **文件锁（R23）**：绑定打开中的 `IFile` 句柄；`flkExclusive` 互斥，`flkShared` 可并存且与 exclusive 互斥；`TryLock` 仅「忙」返回 False（`PLATFORM_ERR_AGAIN`/`BUSY` 及 Win 锁占用码）；其它错误 raise；关闭/销毁后 OS 释放锁。Unix 为 **advisory** `flock`；Windows `LockFileEx` 整文件，语义平台相关；**不保证** NFS 可靠。仅经 `platform_file_lock|trylock|unlock`。
- **[INV-14]** **文件监视（R25+R29+R30+R32+U2）**：`Watch`/`IFsWatcher` 经 `platform.watch`；`Poll` 返回 False=无事件/超时，True=有事件；L0 返回码约定 0=空、1=事件。`Add`=单 path 非递归；**`AddTree`**=递归挂载目录树（不跟随 symlink 目录；运行时新建子目录 auto-add）。**`Remove(path)`**：停止对该 path 的监视（对齐 Go fsnotify.Remove；未监视则 no-op）。`TFsWatchEvent.Name` 在 L0 提供 Wd 时为 **base+name 路径**；`Created`/`Deleted`/`Modified`/`IsDir` 为独立布尔（可同时 true）。**`Kind`**（U2）：主动作 `fwkCreated` > `fwkDeleted` > `fwkModified` > `fwkOther`（布尔仍保留）。**R30**：Linux residual 缓冲跨 Poll 不丢批内事件。kqueue `PLATFORM_WATCH_MAX_FDS=256`。Windows：**S2 Poll** 经 RDCW（platform）；Wine 上事件可能 soft residual，truth=wine-runtime-smoke。
- **[INV-15]** **位置 IO（R34）**：`IFile.ReadAt`/`WriteAt` 经 `platform_file_pread`/`pwrite`；**不**改变流 `Position`；EOF 外 ReadAt 返回 0。

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 文件不存在 | ENotFoundError |
| 权限不足 | EPermissionError |
| 磁盘满 / 内存不足 | EResourceExhaustedError（ENOSPC/ENOMEM；Win DISK_FULL/NOT_ENOUGH_MEMORY） |
| 其它 I/O | EIOError |
| 路径无效 | EArgumentError |

---

## 4. 线程安全

所有函数为纯函数（无共享状态），✅ 线程安全。但同一文件的并发读写由调用方负责。

---

## 5. 内存管理

- ReadFile/ReadFileText/ReadFileLines 分配返回内容，调用方负责释放
- ReadDir 返回 TDirEntryArray，调用方负责释放
- 无全局缓存

---

## 6. 测试覆盖

test_fs, test_fs_facade, test_fs_glob, test_fs_idir, test_fs_ifile, test_fs_text

**最后校准：2026-07-20 R29**（suite 通过数以 `make test` 输出为准）。

| 测试目录 | 参考通过数 | 说明 |
|----------|-----------|------|
| test_fs | 158 | R20 HardLink/Chtimes/Chown + R19 错误分类 |
| test_fs_glob | 31 | GlobMatch / FsGlob |
| test_fs_facade | 8 | 门面完整性（MkdirAll/Remove 按 procedure INV-5） |
| test_fs_idir | 7 | IDir 接口 |
| test_fs_ifile | **22** | IFile + R23 Lock/TryLock/OpenLocked |
| test_fs_text | 19 | BOM/UTF-8/UTF-16 |
| test_fs_watch | **13** | R29–R32 AddTree/queue/Remove |
| test_fs_wine | **3** | wine 最小生产集（读写/MkdirAll/OpenLocked） |
| test_fs_watch_wine | **3** | wine watch S2 + soft create-event |
| **合计** | **9 个测试目录** | heaptrc 0 leak 为门禁 |

路径命名与 `nextpas.core.path` 对齐说明见 `core/docs/path/README.md`「命名规范」。

---

## Windows / Unix 支持矩阵（M2-W4）

完整一眼表：[`../process/WIN.md`](../process/WIN.md)。

| 能力 | Linux/Unix | Windows | 失败形态 |
|------|------------|---------|----------|
| Read/Write/MkdirAll/Remove/… | Done | Done（wine 子集） | raise |
| OpenLocked / IFile.Lock | flock | LockFileEx | busy→False / raise |
| ReadAt / WriteAt | Done | Done（L0） | raise |
| Chown | Done | **UNSUPPORTED** | 平台错误映射 |
| Watch Add/Poll | inotify | **RDCW S2** | Wine 事件 soft |
| Watch AddTree 多目录 | Done | Partial（槽位/L0 限） | NOSPC / 文档 |

**原则**：不 silent fail；wine 结果 truth=`wine-runtime-smoke`。

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-07-19 | 1.1 | 测试数口径校准；INV-5 Boolean 见目录注释 | Claude |
| 2026-07-19 | 1.2 | INV-5 procedure；Path 别名；GetEnv 兼容注释 | Claude |
| 2026-07-19 | 1.3 | 修 test_fs_facade 对 procedure MkdirAll/Remove 的断言；六套件计数校准 | Claude |
| 2026-07-19 | 1.4 | INV-7 FPC RTL 隔离；fs 测试去 SysUtils | Claude |
| 2026-07-19 | 1.5 | 真 uses 门禁（test_fs + fpc_rtl_uses_scan.inc） | Claude |
| 2026-07-19 | 1.6 | PathDir 门面对齐 path；Remove ENOENT；Boolean 壳/env 迁移 INV | Claude |
| 2026-07-19 | 1.7 | PathDir 仅裸名压空；`./x` 保留 `.` | Claude |
| 2026-07-19 | 1.8 | IsSymlink；R16 对标 | Claude |
| 2026-07-19 | 1.9 | SameFile；质量测；117 | Claude |
| 2026-07-19 | 1.10 | R17 质量表；133 | Claude |
| 2026-07-20 | 1.11 | R22 ENOSPC/ENOMEM→EResourceExhaustedError | Claude |
| 2026-07-20 | 1.12 | R23 IFile.Lock/TryLock/Unlock + OpenLocked；INV-13 | Claude |
| 2026-07-20 | 1.13 | R29 AddTree 递归监视 + Wd 路径消歧；INV-14；watch 11 | Claude |
| 2026-07-20 | 1.14 | INV-15 ReadAt/WriteAt；R32 Remove | Claude |
| 2026-07-20 | 1.15 | M2-W4 Win 支持矩阵 + wine 最小生产集 | Claude |
| 2026-08-31 | 1.16 | 文档时效刷新：Watch/AddTree同步 | Claude |
