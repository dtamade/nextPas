# nextpas.core.fs

L2 文件系统操作模块。提供文件读写、目录操作、路径工具和临时文件管理。

## 快速开始

```pascal
uses nextpas.core.fs;

// 读写文件
var Data := ReadFile('/tmp/hello.txt');
WriteFileText('/tmp/hello.txt', 'Hello, world!');

// 追加一行
AppendFileLine('/tmp/log.txt', 'new entry');

// 原子写入（崩溃安全）
WriteAtomic('/tmp/config.json', ConfigBytes);

// 文件信息
if Exists('/tmp/hello.txt') then
  WriteLn('size: ', FileSize('/tmp/hello.txt'));

// 创建目录
MkdirAll('/tmp/a/b/c');

// 遍历目录
for var Entry in ReadDir('/tmp') do
  WriteLn(Entry.Name);
```

## 架构

facade 模式，`nextpas.core.fs` 聚合子模块：

```
nextpas.core.fs.pas          ← 门面：纯 re-export
nextpas.core.fs.base.pas     ← 类型定义（TFileMode, TFileInfo, TDirEntry 等）
nextpas.core.fs.intf.pas     ← 接口定义（IFile, IDirIterator）
nextpas.core.fs.stream.pas   ← IFile 流实现
nextpas.core.fs.util.pas     ← 文件操作工具（ReadFile, WriteFile, Stat 等）
nextpas.core.fs.dir.pas      ← 目录操作（Mkdir, Remove, Walk 等）
nextpas.core.fs.path.pas     ← 路径操作（Join, Dir, Base, Ext 等）
nextpas.core.fs.errors.pas   ← 文件系统异常
```

## API 入口

### 文件操作

| 函数 | 说明 |
|------|------|
| `Open(APath, AMode)` | 以指定模式打开文件，返回 `IFile` |
| `Create(APath, APerm)` | 创建新文件（已存在则截断），返回 `IFile` |
| `CopyFile(ASrc, ADst)` | 复制文件，返回写入字节数 |
| `TempFile(ADir, APattern)` | 创建临时文件，返回 `IFile` |
| `TempDir(ADir, APattern)` | 创建临时目录，返回路径 |
| `Glob(ADir, APattern)` | 列出匹配 glob 模式的文件 |

### 便利函数

| 函数 | 说明 |
|------|------|
| `ReadFile(APath)` | 读取全部内容为 `TBytes` |
| `ReadFileText(APath)` | 读取全部内容为字符串 |
| `ReadFileLines(APath)` | 读取按行分割为 `TStringArray` |
| `WriteFile(APath, AData)` | 写入字节数组 |
| `WriteFileText(APath, AText)` | 写入字符串 |
| `WriteFileLines(APath, ALines)` | 按行写入，自动追加换行 |
| `AppendFile(APath, AData)` | 追加字节数组 |
| `AppendFileText(APath, AText)` | 追加字符串 |
| `AppendFileLine(APath, ALine)` | 追加一行文本 |
| `WriteAtomic(APath, AData)` | 原子写入（先写临时文件再 rename） |
| `ScanFileLines(APath)` | 返回 `IScanner` 按行扫描 |
| `MapFileLines(APath)` | 返回 `IMappedLines` 内存映射读取 |

### 文件属性

| 函数 | 说明 |
|------|------|
| `Stat(APath)` | 获取文件状态（跟随符号链接） |
| `Lstat(APath)` | 获取文件状态（不跟随符号链接） |
| `Exists(APath)` | 检查路径是否存在 |
| `IsDir(APath)` | 检查是否为目录 |
| `IsFile(APath)` | 检查是否为普通文件 |
| `FileSize(APath)` | 返回文件大小（字节） |
| `Chmod(APath, APerm)` | 设置文件权限 |
| `Truncate(APath, ASize)` | 截断文件 |
| `Symlink(ATarget, ALinkPath)` | 创建符号链接 |
| `Readlink(APath)` | 读取符号链接目标 |

### 目录操作

| 函数 | 说明 |
|------|------|
| `Mkdir(APath, APerm)` | 创建单级目录 |
| `MkdirAll(APath, APerm)` | 递归创建目录（mkdir -p） |
| `Remove(APath)` | 删除文件或空目录 |
| `RemoveAll(APath)` | 递归删除（rm -rf） |
| `Rename(AOld, ANew)` | 重命名/移动 |
| `ReadDir(APath)` | 读取目录内容为 `TDirEntryArray` |
| `OpenDir(APath)` | 返回 `IDirIterator` 迭代器 |
| `Walk(ARoot, AFunc)` | 递归遍历目录树 |

### 路径操作

| 函数 | 说明 |
|------|------|
| `PathJoin(AParts)` | 连接多个路径片段 |
| `PathDir(APath)` | 提取目录部分 |
| `PathBase(APath)` | 提取文件名部分 |
| `PathSplit(APath, ADir, ABase)` | 分离目录和文件名 |
| `PathExt(APath)` | 提取扩展名 |
| `PathClean(APath)` | 规范化路径 |
| `PathAbs(APath)` | 转为绝对路径 |
| `PathIsAbs(APath)` | 判断是否绝对路径 |
| `PathRelative(ABase, ATarget)` | 计算相对路径 |
| `PathEnsureSep(APath)` | 确保末尾有分隔符 |
| `PathTrimSep(APath)` | 去除末尾分隔符 |
| `PathChangeExt(APath, ANewExt)` | 替换扩展名 |
| `PathWithoutExt(APath)` | 去除扩展名 |
| `PathMatch(APattern, AName)` | glob 模式匹配 |

### 工具函数

| 函数 | 说明 |
|------|------|
| `GetCwd` | 获取当前工作目录 |
| `SetCwd(APath)` | 设置当前工作目录 |
| `GetEnv(AName)` | 获取环境变量 |
| `EnvKeys` | 返回所有环境变量名 |
| `GetTempDir` | 获取系统临时目录 |
| `SameFileName(A, B)` | 比较文件名是否相同（平台相关大小写规则） |

## 测试

```bash
make -C core/tests/nextpas.core.fs/test_fs clean test
make -C core/tests/nextpas.core.fs/test_fs_facade clean test
make -C core/tests/nextpas.core.fs/test_fs_glob clean test
make -C core/tests/nextpas.core.fs/test_fs_idir clean test
make -C core/tests/nextpas.core.fs/test_fs_ifile clean test
make -C core/tests/nextpas.core.fs/test_fs_text clean test
```

330 个测试，heaptrc 零泄漏。

### 特殊行为说明

- **ReadFile + /proc**: 支持 `/proc` 等虚拟文件系统（stat 报告 size=0 但实际有内容）
- **ReadFileText 编码**: 自动检测 BOM（UTF-8/UTF-16LE/UTF-16BE）；无 BOM 且非合法 UTF-8 时回退 Latin-1
- **RemoveAll**: 迭代式实现，支持任意深度目录树（不会栈溢出）
- **TempFile**: 统一权限为 0644，无论是否指定目录

## 基准

```bash
make focused FOCUS=core/benchmarks/nextpas.core.fs
```
