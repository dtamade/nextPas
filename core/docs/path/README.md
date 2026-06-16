# nextpas.core.path

路径操作兼容 facade，委托给 `nextpas.core.fs.path` 实现。

## 模块定位

- **层级**: L2 facade
- **职责**: 提供 SysUtils 兼容的路径操作函数
- **实现**: 委托给 `nextpas.core.fs.path`（统一实现 owner）

## API 入口

### 路径拼接与解析

| 函数 | 说明 |
|------|------|
| `PathJoin(Aparts)` | 拼接路径段 |
| `PathDir(APath)` | 提取目录部分 |
| `PathBase(APath)` | 提取文件名（不含扩展名） |
| `PathSplit(APath, ADir, ABase)` | 拆分目录和文件名 |
| `PathExt(APath)` | 提取扩展名（含 `.`） |
| `PathClean(APath)` | 规范化路径（去除 `..`、`.`、重复分隔符） |
| `PathIsAbs(APath)` | 判断是否绝对路径 |
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
  WriteLn(PathJoin(['/home', 'user', 'file.txt']));
  // → /home/user/file.txt

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
