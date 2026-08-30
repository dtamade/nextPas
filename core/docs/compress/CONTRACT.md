# nextpas.core.compress 代码契约

**模块路径**：`core/src/nextpas.core.compress*.pas`（8 个源文件）
**层级**：L2（依赖 L0-L1: base, io）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-30
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| compress.base | TCompressionLevel 枚举 (clNone/clFast/clDefault/clBest) |
| compress.intf | ICompressWriter, IDecompressReader 接口 |
| compress.deflate | Deflate 压缩/解压实现 |
| compress.gzip | Gzip 格式（Deflate + header/trailer） |
| compress.zlib.ffi | zlib FFI 绑定 |
| compress.lz4 | LZ4 压缩/解压 |
| compress.lz4.ffi | LZ4 FFI 绑定 |
| compress.pas | 门面 |

### 1.2 接口

```pascal
ICompressWriter = interface(IWriter)
  procedure Finish;  // flush 并写入尾部
end;

IDecompressReader = interface(IReader)
  // 继承 IReader 的 Read 方法
end;
```

### 1.3 核心函数

| 函数 | 说明 |
|------|------|
| `DeflateWriter(ADst, ALevel): ICompressWriter` | 流式 Deflate 压缩写入 |
| `DeflateReader(ASrc): IDecompressReader` | 流式 Deflate 解压读取 |
| `DeflateReaderWithMaxOutputSize(ASrc, AMax)` | 带大小限制的解压（防 zip bomb） |
| `GzipWriter(ADst, ALevel): ICompressWriter` | Gzip 格式压缩 |
| `GzipReader(ASrc): IDecompressReader` | Gzip 解压 |
| `GzipReaderWithMaxOutputSize(ASrc, AMax)` | 带大小限制的 Gzip 解压 |
| `DeflateCompress(AData): TBytes` | 一次性压缩 |
| `DeflateDecompress(AData): TBytes` | 一次性解压 |
| `RawDeflateCompress(AData, ALevel): TBytes` | RAW DEFLATE (RFC 1951) 一次性压缩；完整终结块，ZIP method=8 载荷用 |
| `RawDeflateDecompress(AData): TBytes` | RAW DEFLATE 一次性解压（默认 256 MB 上限） |
| `RawDeflateDecompressWithMaxOutputSize(AData, AMax): TBytes` | 带大小限制的 RAW DEFLATE 解压 |
| `GzipCompress(AData): TBytes` | 一次性 Gzip 压缩 |
| `GzipDecompress(AData): TBytes` | 一次性 Gzip 解压 |
| `Lz4Compress(AData): TBytes` | LZ4 压缩 |
| `Lz4Decompress(AData): TBytes` | LZ4 解压 |

---

## 2. 不变量

- **[INV-1]** ICompressWriter.Finish 必须在释放前调用（否则数据不完整）
- **[INV-2]** IDecompressReader 遇到格式错误时抛异常
- **[INV-3]** MaxOutputSize 限制防止 zip bomb 攻击
- **[INV-4]** Gzip 格式包含 CRC32 校验和

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 损坏的压缩数据 | EIOError |
| 输出超过 MaxOutputSize | EResourceExhaustedError |
| zlib/LZ4 初始化失败 | EIOError |
| 写入目标失败 | EIOError |

---

## 4. 线程安全

- 流式接口（ICompressWriter/IDecompressReader）：❌ 调用方同步
- 一次性函数（Compress/Decompress）：✅ 纯函数

---

## 5. 内存管理

- 流式接口内部维护压缩状态缓冲区
- Finish/读取完毕后内部缓冲区释放
- 一次性函数返回新的 TBytes，调用方负责释放
- FFI 绑定的外部库内存由调用方管理

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_compress_deflate | Deflate 压缩/解压 |
| test_compress_gzip | Gzip 格式 |
| test_compress_lz4 | LZ4 算法 |
| test_compress_streaming | 流式 API |
| **合计** | **4 个测试目录** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |
