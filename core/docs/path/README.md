# nextpas.core.path

路径操作兼容 facade，委托给 `nextpas.core.fs.path` 实现。

## 模块定位

- **层级**: L2 facade
- **职责**: 提供 SysUtils 兼容的路径操作函数
- **实现**: 委托给 `nextpas.core.fs.path`（统一实现 owner）

## 命名规范（path vs fs）

| 规范名（推荐） | 别名 / 等价 | 单元 |
|----------------|-------------|------|
| `PathIsAbsolute` | `PathIsAbs`（path / fs 对称） | path / fs |
| `PathNormalize` | `PathClean`（互为别名） | path / fs |
| `PathJoin(a,b)` / `PathJoinN` | fs：`PathJoin2` / `PathJoin(array)` / `PathJoin3` | path / fs |
| `PathBase` | 含扩展名；= `ExtractFileName` | path / fs |
| `PathDir`（门面） | 裸文件名 → **空串**（SysUtils） | path / `fs.PathDir` |
| `FsPathDir`（底层） | 裸文件名 → **`.`**（Go/platform） | `fs.path` only |

- **仅需路径字符串操作**：优先 `uses nextpas.core.path`（`PathJoin` 为二元）。
- **已依赖 fs**：用 `PathJoin([...])` 或 `PathJoin2`；不要假设 fs 的 `PathJoin` 是二元。
- **PathDir 对照**：`path.PathDir` / `fs.PathDir` 对齐 SysUtils（`file.txt` → `''`）；需要 Go 语义时用 `FsPathDir`（`file.txt` → `'.'`）。
- **ExpandFileName / PathAbs**：解析绝对路径时依赖 **当前工作目录**，不是纯字符串函数。
- 新代码不要再发明第三套命名。

## API 入口

### 路径拼接与解析

| 函数 | 说明 |
|------|------|
| `PathJoin(ABase, AChild)` | 连接两个路径片段 |
| `PathJoin3(A, B, C)` | 连接三个路径片段 |
| `PathJoinN(AParts)` | 连接多个路径片段 |
| `PathDir(APath)` | 提取目录部分 |
| `PathBase(APath)` | 提取文件名（含扩展名） |
| `PathSplit(APath, ADir, ABase)` | 拆分目录和文件名 |
| `PathExt(APath)` | 提取扩展名（含 `.`） |
| `PathClean(APath)` | 规范化路径（去除 `..`、`.`、重复分隔符） |
| `PathIsAbsolute(APath)` | 判断是否绝对路径 |
| `PathIsRelative(APath)` | 判断是否相对路径 |
| `PathNormalize(APath)` | 同 `PathClean` |

### SysUtils 兼容函数

| 函数 | 说明 |
|------|------|
| `ExtractFilePath(AFileName)` | 提取目录（末尾含分隔符） |
| `ExtractFileName(AFileName)` | 提取文件名 |
| `ExtractFileExt(AFileName)` | 提取扩展名（含 `.`） |
| `ChangeFileExt(AFileName, AExt)` | 替换扩展名 |

### 路径工具

| 函数 | 说明 |
|------|------|
| `PathWithoutExt(APath)` | 去除扩展名 |
| `PathRelative(AFrom, ATo)` | 计算相对路径 |

## 使用示例

```pascal
uses
  nextpas.core.path;

var
  LDir, LBase, LExt: string;
begin
  { 路径拼接 }
  WriteLn(PathJoin('/home', 'user'));
  // → /home/user
  WriteLn(PathJoinN(['/home', 'user', 'docs', 'file.txt']));
  // → /home/user/docs/file.txt

  { 路径拆分 }
  PathSplit('/home/user/file.txt', LDir, LBase);
  // LDir = '/home/user', LBase = 'file.txt'

  { 扩展名 }
  WriteLn(PathExt('file.tar.gz'));
  // → .gz

  { SysUtils 兼容 }
  WriteLn(ExtractFilePath('/home/user/file.txt'));
  // → /home/user/
end;
```

## 测试

```bash
make -C core/tests/nextpas.core.path/test_path clean test
```

suite 通过数见 `CONTRACT.md`（最后校准以 make test 为准）。
