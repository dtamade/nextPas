# nextpas.core.fs 代码契约

**模块路径**：`core/src/nextpas.core.fs*.pas`（9 个源文件）
**层级**：L2（依赖 L0-L1）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

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
| 路径 | Join, ExtractFileName, ExtractExt, ChangeExt, IsAbsolute | 路径组合/解析 |
| 文件 | ReadAllText, ReadAllBytes, WriteAllText, WriteAllBytes | 文件读写 |
| 文件 | CopyFile, DeleteFile, RenameFile, FileExists | 文件操作 |
| 目录 | CreateDir, CreateDirAll, RemoveDir, DirectoryExists | 目录操作 |
| 遍历 | ListDir, ListDirRecursive | 目录遍历 |
| 信息 | FileSize, FileAge, FileIsReadOnly | 文件属性 |
| Glob | GlobMatch, FsGlob | 通配符匹配 |
| 临时 | GetTempDir, CreateTempFile | 临时文件 |

---

## 2. 不变量

- **[INV-1]** 所有文件操作在 nil/空路径时抛 EArgumentNil
- **[INV-2]** ReadAllText 返回完整内容的 string 拷贝
- **[INV-3]** GlobMatch 支持 `*`, `?`, `[...]` 模式
- **[INV-4]** CreateDirAll 递归创建，已存在时静默成功

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

- ReadAllText/ReadAllBytes 分配返回内容，调用方负责释放
- ListDir 返回 TStringArray，调用方负责释放
- 无全局缓存

---

## 6. 测试覆盖

test_fs, test_fs_facade, test_fs_glob, test_fs_idir, test_fs_ifile, test_fs_text

| 测试文件 | 测试数 | 说明 |
|----------|--------|------|
| test_fs | 97 | 文件读写/目录操作/路径/符号链接 |
| test_fs_glob | 31 | GlobMatch 通配符匹配 |
| test_fs_facade | 8 | 门面完整性 |
| test_fs_idir | 7 | IDir 接口 |
| test_fs_ifile | 17 | IFile 接口 |
| test_fs_text | 19 | 文本文件操作（BOM/UTF-8/UTF-16） |
| **合计** | **6 个测试目录** | **179** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
