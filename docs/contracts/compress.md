# nextpas.core.compress 代码契约

> 模块路径: `core/src/nextpas.core.compress.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

压缩门面。提供 Gzip、Deflate、LZ4、Zlib 压缩/解压。与 io 层集成。

---

## 关键接口

```pascal
type
  TCompressionLevel = (clFast, clDefault, clBest);
  ICompressWriter = interface(IWriter) ... end;
  IDecompressReader = interface(IReader) ... end;

function DeflateWriter(ADst: IWriter; ALevel: TCompressionLevel = clDefault): ICompressWriter;
function GzipWriter(ADst: IWriter; ALevel: TCompressionLevel = clDefault): ICompressWriter;
function Lz4Writer(ADst: IWriter): ICompressWriter;
function DeflateReader(ASrc: IReader): IDecompressReader;
function GzipReader(ASrc: IReader): IDecompressReader;
function Lz4Reader(ASrc: IReader): IDecompressReader;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 数据格式错误 | raise EInvalidArgument |
| 校验失败 | raise EInvalidArgument |

---

## 线程安全

- 流式压缩器不线程安全（per-stream）
- 工厂函数可安全并发调用

---

## 依赖关系

- 依赖: base, io.intf
- 被依赖: http (gzip encoding), fs (归档)

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
