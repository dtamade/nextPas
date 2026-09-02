# nextpas.core.compress 代码契约

**模块路径**：`core/src/nextpas.core.compress*.pas`（11 个源文件，含 `compress.tar` 兼容转发 → 独立 `nextpas.core.tar`）
**层级**：L2（依赖 L0-L1: base, io）
**Owner**：Claude（AI 负责）
**最后更新**：2026-09-02
**版本**：1.3

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
| compress.zstd | Zstd 压缩/解压（libzstd FFI） |
| compress.zstd.ffi | Zstd FFI 绑定 |
| compress.tar | Tar 容器（ustar/pax，已晋升独立 L2 `nextpas.core.tar` 兼容转发，零拷贝视图 `EntryDataSlice/OpenEntryStream` + `bytes.ops` 单源 `Move`） |
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
- **[INV-5] Tar 零拷贝视图**：`TTarReader.EntryDataSlice` 返回原镜像 `PByte` 区间不分配，`OpenEntryStream` 为持有型 `IReader`（`TBytes` 镜像时持有引用防悬垂，外部 `PByte` 时固化拷贝自包含，`Reader` 释放后仍可读）；`EntryData` 为拷贝分流（`bytes.ops SpanClone` 单源，峰值 2× 切片，热路径优先切片 `extract-all 320µs vs extract-slice 236µs 约 -26%`），`CombinePrefixName/pax` 单次 `SetLength+Move` 零拷贝
- **[INV-6] Tar Move 单源**：所有 `PByte/string` `Move` 收敛至 `bytes.ops.CopyMemory/CopyStringToBuffer/SpanClone` 单源（`reader.FieldSlice/CombinePrefixName/TTarSliceReader.Read`、`writer.TarPutHeaderSlice/EmitPaxHeader/MakePaxRecord`、`common.TarPutHeaderString` 等零拷贝 `PByte` 切片一次 `Move`），禁止分散手写 `Move(AValue[1])`
- **[INV-7] Tar inline/外联不变量**：薄转发与小访问器 `inline`（`Default*Options/TarPadToBlock/StringField/CachedField/IsSafeTarEntryName` 等），含循环/分配/SIMD 的 `TarComputeChecksum*/TarHeaderIsZeroOrValid/TarParseNumericField/TarFormatNumericField/TarParsePaxRecords/CombinePrefixName` 体外联（遵 `design-conventions` 真实循环体禁 `inline`，防 I-Cache 复制膨胀）
- **[INV-8] Tar 吞吐不变量**：`core/benchmarks/nextpas.core.tar/bench_tar` 7 项 `TBenchSuite`（`SetMinDuration 300ms/MinSamples 7/Warmup 1`，`ACtx.SetBytes` 换算吞吐，`SaveToJSON` 双路归档 `build/bench-tar.json`，`TAR_BENCH_FULL=1` 追加 `2000×512B`），`allocs` 硬预算 `baseline+2` 且 `bytes/op` 强一致（CI 红），`ns/op>1.5× baseline` 与 `MB/s<0.65×` 软告警；见 `core/docs/tar/CONTRACT.md §6` 与 `BASELINE.json` 单源

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
| test_compress_zstd | Zstd 压缩/解压 |
| test_compress_tar | Tar 容器（经 `compress.tar` 兼容转发，回归 `nextpas.core.tar` 全量） |
| **合计** | **6 个测试目录** |

## 7. 性能门禁（Tar 零拷贝/Move 单源/inline/吞吐）

- **零拷贝证据**：`TTarReader.EntryDataSlice` 零拷贝视图不分配，`OpenEntryStream` 持有型 `IReader`（`FHold:TBytes` 防悬垂）经 `bytes.ops.CopyMemory` 单源 `Move`；`EntryData` 为 `SpanClone` 单源拷贝分流，热路径优先切片（实测 `extract-all 320µs vs extract-slice 236µs 约 -26%`）；`CombinePrefixName` 单次 `SetLength+两Move`，`pax` 单条记录 `StringToBytes` 一次 `Move`，`TarPutHeaderSlice/String` 零拷贝 `PByte` 切片单源
- **Move 单源**：`bytes.ops` 为 `Move` 唯一审计入口（`CopyMemory/CopyStringToBuffer/SpanClone`），`reader/writer/common` 均委托单源，禁止 `Move(AValue[1])` 分散；`builder` 经 `IBytesBuilder` 几何扩容 inline `AppendBytes` 零拷贝 + `Finish ToBytes` 单次分配
- **inline 不变量**：门面与小访问器 `inline`（`Default*Options/TarPadToBlock/StringField/CachedField/IsSafeTarEntryName/TarBuilder`），循环/SIMD/分配体外联（`TarComputeChecksum*/TarHeaderIsZeroOrValid/TarParseNumericField` 等，遵 `design-conventions` 防 I-Cache 膨胀）
- **吞吐门禁**：`bench_tar` 7 项 `TBenchSuite` 口径（见 INV-8），`BASELINE.json` 单源固化，`make -C core/benchmarks/nextpas.core.tar/bench_tar run` 复现，`make regression` 比对 `allocs+2/bytes` 硬门与 `ns/MB/s` 软门；`make -C core/tests/nextpas.core.compress/test_compress_audit test` 为默认落地门（benchmark 编译证明，吞吐证据可选 `benchmark-run`）

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |
| 2026-08-31 | 1.2 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
| 2026-09-02 | 1.3 | 补齐 Tar 契约：1.1 增 `compress.tar/zstd` 行、`§2 INV-5..8` 零拷贝/Move 单源/inline/吞吐不变量、`§7` 性能门禁与 `bench_tar BASELINE` 单源，守四件套与 `bytes.ops` 单源 | core-tar |
