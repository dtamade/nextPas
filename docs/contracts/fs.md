# nextpas.core.fs 代码契约

> 模块路径: `core/src/nextpas.core.fs.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

文件系统门面。提供文件读写、目录遍历、路径操作和内存映射文件。

---

## 关键接口

```pascal
type
  TFileMode = (fmRead, fmWrite, fmAppend, fmCreate, fmTruncate, fmExclusive, fmSync);
  TFileType = (ftRegular, ftDirectory, ftSymlink, ftCharDevice, ftBlockDevice, ftFifo);
  TFileInfo = record ... end;
  TDirEntry = record ... end;
  IFile = interface ... end;
  IDirIterator = interface ... end;

function FileRead(const APath: string): TBytes;
function FileReadText(const APath: string): string;
procedure FileWrite(const APath: string; const AData: TBytes);
procedure FileWriteText(const APath: string; const AText: string);
function FileExists(const APath: string): Boolean;
function DirExists(const APath: string): Boolean;
function FileSize(const APath: string): Int64;
procedure FileDelete(const APath: string);
procedure DirCreate(const APath: string);
procedure DirDelete(const APath: string);
function DirList(const APath: string): TDirEntryArray;
function DirWalk(const APath: string; AFunc: TWalkFunc): Boolean;
function PathJoin(const A, B: string): string;
function PathDirName(const APath: string): string;
function PathBaseName(const APath: string): string;
function PathExt(const APath: string): string;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 文件不存在 | raise ENotFoundError |
| 权限不足 | raise EPermissionError |
| 路径非法 | raise EInvalidArgument |
| 磁盘满 | raise EIOError |

---

## 线程安全

- 单次操作线程安全（底层 POSIX 调用原子性）
- 多步操作（检查后创建）需外部同步

---

## 依赖关系

- 依赖: base, io, text, platform.fs, platform.path
- 被依赖: config, http.static, tls, process

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
