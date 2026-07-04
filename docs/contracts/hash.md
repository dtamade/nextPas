# nextpas.core.hash 代码契约

> 模块路径: `core/src/nextpas.core.hash.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

哈希模块门面。提供 SHA-256/384/512、SHA-1、MD5、wyhash 和文件哈希。
IHasher 继承 IWriter，可直接与 io 层集成。

---

## 关键接口

```pascal
type
  THashAlgorithm = (haMD5, haSHA1, haSHA256, haSHA384, haSHA512);
  IHasher = interface(IWriter)
    procedure Sum(out ADigest; ASize: Integer);
    procedure Reset;
  end;

function NewMD5: IHasher;
function NewSHA1: IHasher;
function NewSHA256: IHasher;
function NewSHA384: IHasher;
function NewSHA512: IHasher;
function HashFile(const APath: string; AAlgo: THashAlgorithm): TBytes;
```

---

## 前置条件

1. IHasher.Write: AData 有效，ALen >= 0
2. IHasher.Sum: ADigest 缓冲区 >= 算法摘要大小
3. HashFile: 文件存在且可读

---

## 后置条件

1. IHasher.Sum: 填充算法摘要（MD5=16, SHA1=20, SHA256=32, SHA384=48, SHA512=64）
2. IHasher.Reset: 重置为初始状态，可复用
3. HashFile: 返回文件内容的哈希摘要

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 文件不存在 | raise ENotFoundError |
| Sum 缓冲区太小 | raise EInvalidArgument |

---

## 线程安全

- IHasher 实例不线程安全（需外部同步或 per-thread 实例）
- 工厂函数(NewSHA256等)可安全并发调用

---

## 依赖关系

- 依赖: base, io.intf
- 被依赖: crypto, tls, json, 文件校验

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
