# nextpas.core.sevenz 契约

**模块**：`nextpas.core.sevenz.*` 26 单元（base/intf/header/coders/filters/levels/limits/aes/bcj.*×8/bcj.utils/bcj2/lzma.rc/decoder/encoder/ffi/reader/writer/fs + 门面）
**层级**：L2，`Allowed L0-L1 plus io/fs/compress/checksum/crypto/hash (L2→L2 exempt via platform lstat)`
**门面**：`nextpas.core.sevenz.pas` re-export `TSevenZEntryKind/Info/ESevenZError/ESevenZLimitError/TSevenZLzmaBackend/CompressionLevel/Filter/LzmaEncoded/Extracted/Enumerator/ISevenZReader/ISevenZWriter` 等
**接口**：`ISevenZReader` 50+ 胖门面为容器刻意聚合（查询/提取/大小写三族+Try*+ToFs联邦），不拆小接口以保 `for..in`/`Count` 一致性，详见 README API 表（设计权衡，非小接口违规）
**真相**：`focused-runtime` 171 用例 + `bench_sevenz` + `README` 单源真相同步（`header IBytesBuilder ToBuilder 单源 + CRC 预计数两遍单分配` + `FEntries/LFolders 几何扩容 + writer SpanClone 单源` / `filters.DeltaApply` 外联 / `reader.Sort` + `EnsureSortedGeneric` / `writer.pathvalid` + `writer 炸弹早期/纯↔FFI/pack+name/截断五探针`）

## 不变量
- [INV-7Z1] 单源 limits：`base` 13 阈值（`MAX_HEADER 64MiB/PACK 64MiB/UNPACK 8GiB/FILE_COUNT 1M` 等）经 `limits` 薄封装，reader/writer/header 单源引用
- [INV-7Z2] 炸弹门限：`header>64MiB / pack>64MiB / total>8GiB / unpack>8GiB / name>64KiB / file>1M` 抛 `ESevenZLimitError(ecResourceExhausted)`（reader 解析期 + writer `BuildArchive`/`ValidateEntryName` 分配前双端对等校验，`FCount/totalUnpack/totalPack/folderCount/packStreams/name` 六维，复用 `base` 单源防漂移），其余损坏抛 `ESevenZError(ecParse)`
- [INV-7Z3] LZMA 字典：`CheckWindow Pos-DictStart` 越界即 `EngineError`，`CopyMatch` 校验 `Pos+Len<=OutSize`
- [INV-7Z4] AES：CBC 无填充，`mod16<>0` 抛错，19 轮 SHA256 KDF，IV 16B 随机，错口令由 CRC/解码暴露为 `ecParse`
- [INV-7Z5] 过滤链：`C_MAX_FILTERS=16`，`MethodId/Props/Convert` 表驱动，Delta 零分配 in-place

## 线程与资源
- header `IBytesBuilder ToBuilder` 单源（`SevenZWriteNumberToBuilder/Append*ToBuilder`，`bytes.builder Grow` 均摊，O(n) 替代 `TBytes SetLength` O(n²)；FilesInfo/外层均按载荷预估 `CreateBytesBuilder(N)` 近零 Grow；`ParseSubStreamsInfo` CRC 收集两遍计数单分配 O(n²)→O(n)，1M 子流规模）+ `FEntries/LFolders` 几何扩容（`FCount/文件夹计数 + BytesNextCapacity` 单源 `BYTES_BUILDER_MIN_GROW×2` 均摊，条目表与文件夹表均 O(n²)→O(n)）+ `AddFile` 单源 `SpanClone`（`TByteSpan.FromBytes` 零拷视图）+ reader `2-entry LRU 64MiB` 缓存（大 solid 单 MRU 保留）+ `Sort` 单源 `collections.algorithms.Sort`（`TSevenZSortCtx`）+ `EnsureSortedGeneric` 懒加载，`ReverseStr/LowerBoundGeneric` 外联避热点膨胀，writer `platform.thread` 并行（`IsMultiThread` 门控，`BytesReplicateCopy` 零拷贝，Move 语义去深拷，header/Block 经 `IBytesBuilder` 均摊），`CopyMatch` 倍增 Move，`ValidateEntryName` 复用 `bytes.pathvalid` 单源 + `name>64KiB` 早期限

## 契约测试
- `make -C core/tests/nextpas.core.sevenz/test_sevenz clean test` 171 用例：UTF/FILETIME/LZMA2往返/BCJ全家/Delta/Deflate-BZip2黄金档/过滤链/AES/炸弹/截断/五探针（writer 炸弹早期 viaReader / 纯↔FFI 一致性 / pack>64MiB / name>64KiB / 截断归档）等
- `make -C core/benchmarks/nextpas.core.sevenz/bench_sevenz run` 6/17/42/200/80 MB/s 锚点，含 Filter+Copy+AES 多形态容器探针（copy+bcj / copy+bcj+pw / copy+bcj+pw multi，红线 50/1/0.5 MB/s create、500 MB/s extract）+ glob 10k 四红线（1000/500/300/100k ops/s）+ lzma/bcj/delta 基线（bytes.ops 单源）

**Bench Redlines**（1MiB 语料，`ffi=yes`）：`lzma encode pure ≥4 / decode pure ≥10 / decode ffi ≥30 / bcj ≥200 / delta ≥50 MB/s`；`container copy+bcj create ≥50 / copy+bcj+pw ≥1.0 / copy+bcj+pw multi ≥0.5 / extract ≥500 MB/s`；`glob 10k prefix* ≥1000 / *suffix ≥500 / p*s ≥300 / exact ≥100k ops/s`（`WARN` 即阈值固化，实测 6.8/18.3/49.7/276/88/123/3.5/1.0/1142 与 140k/612/653/1.89M 远高阈值）
