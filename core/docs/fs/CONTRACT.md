# nextpas.core.fs 代码契约

**模块路径**：`core/src/nextpas.core.fs*.pas`（9 个源文件）
**层级**：L2（依赖 L0-L1）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-19
**版本**：1.4

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
| 其他 | Chmod, Truncate, Rename, WriteAtomic | 其他操作 |

---

## 2. 不变量

- **[INV-1]** 所有文件操作在 nil/空路径时抛 EArgumentNil
- **[INV-2]** ReadAllText 返回完整内容的 string 拷贝
- **[INV-3]** GlobMatch 支持 `*`, `?`, `[...]` 模式
- **[INV-4]** CreateDirAll 递归创建，已存在时静默成功
- **[INV-5]** Mkdir/MkdirAll/Remove/RemoveAll/Rename 为 **procedure**：失败抛异常，成功无返回值。`ForceDirectories`/`DeleteFile` 保留 Boolean 兼容壳（内部 try/except）
- **[INV-6]** path 命名：`PathIsAbsolute`≡`PathIsAbs`，`PathNormalize`≡`PathClean`；`PathJoin2(a,b)` 对齐 path 二元 Join
- **[INV-7]** **FPC RTL 隔离 / 编译器无关**：`nextpas.core.fs*` / `path` / `os.env` 源码与本模块测试不得 `uses SysUtils/Classes/BaseUnix/Unix/Windows`；能力经 platform / core 抽象。仅 `nextpas.core.system` 可直接引用 FPC RTL。文档中的「SysUtils 兼容」指 API 形状，不是 `uses SysUtils`。

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 文件不存在 | ENotFoundError |
| 权限不足 | EPermissionError |
| 磁盘满 | EIOError / EResourceExhaustedError |
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

**最后校准：2026-07-19**（suite 通过数以 `make test` 输出为准；与早期 Check 粒度统计不同）。

| 测试目录 | 参考通过数 | 说明 |
|----------|-----------|------|
| test_fs | 110 | 文件读写/目录/路径/符号链接 |
| test_fs_glob | 31 | GlobMatch / FsGlob |
| test_fs_facade | 8 | 门面完整性（MkdirAll/Remove 按 procedure INV-5） |
| test_fs_idir | 7 | IDir 接口 |
| test_fs_ifile | 17 | IFile 接口 |
| test_fs_text | 19 | BOM/UTF-8/UTF-16 |
| **合计** | **6 个测试目录 / 192** | heaptrc 0 leak 为门禁 |

路径命名与 `nextpas.core.path` 对齐说明见 `core/docs/path/README.md`「命名规范」。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-07-19 | 1.1 | 测试数口径校准；INV-5 Boolean 见目录注释 | Claude |
| 2026-07-19 | 1.2 | INV-5 procedure；Path 别名；GetEnv 兼容注释 | Claude |
| 2026-07-19 | 1.3 | 修 test_fs_facade 对 procedure MkdirAll/Remove 的断言；六套件计数校准 | Claude |
| 2026-07-19 | 1.4 | INV-7 FPC RTL 隔离；fs 测试去 SysUtils | Claude |
