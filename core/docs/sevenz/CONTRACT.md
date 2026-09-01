# nextpas.core.sevenz 契约

**模块**：`nextpas.core.sevenz.*` 26 单元（base/intf/header/coders/filters/levels/limits/aes/bcj.*×8/bcj.utils/bcj2/lzma.rc/decoder/encoder/ffi/reader/writer/fs + 门面）
**层级**：L2，`Allowed L0-L1 plus io/fs/compress/checksum/crypto/hash (L2→L2 exempt via platform lstat)`
**门面**：`nextpas.core.sevenz.pas` re-export `TSevenZEntryKind/Info/ESevenZError/ESevenZLimitError/TSevenZLzmaBackend/CompressionLevel/Filter/LzmaEncoded/Extracted/Enumerator/ISevenZReader/ISevenZWriter` 等
**接口**：`ISevenZReader` 50+ 胖门面为容器刻意聚合（查询/提取/大小写三族+Try*+ToFs联邦），不拆小接口以保 `for..in`/`Count` 一致性，详见 README API 表（设计权衡，非小接口违规）
**真相**：`focused-runtime` 166 用例 + `bench_sevenz` + `README` 单源真相同步（`header IBytesBuilder ToBuilder 单源` / `filters.DeltaApply` 外联 / `reader.Sort` + `EnsureSortedGeneric` / `writer.pathvalid`）

## 不变量
- [INV-7Z1] 单源 limits：`base` 13 阈值（`MAX_HEADER 64MiB/PACK 64MiB/UNPACK 8GiB/FILE_COUNT 1M` 等）经 `limits` 薄封装，reader/writer/header 单源引用
- [INV-7Z2] 炸弹门限：`header>64MiB / pack>64MiB / total>8GiB / unpack>8GiB / name>64KiB / file>1M` 抛 `ESevenZLimitError(ecResourceExhausted)`，其余损坏抛 `ESevenZError(ecParse)`
- [INV-7Z3] LZMA 字典：`CheckWindow Pos-DictStart` 越界即 `EngineError`，`CopyMatch` 校验 `Pos+Len<=OutSize`
- [INV-7Z4] AES：CBC 无填充，`mod16<>0` 抛错，19 轮 SHA256 KDF，IV 16B 随机，错口令由 CRC/解码暴露为 `ecParse`
- [INV-7Z5] 过滤链：`C_MAX_FILTERS=16`，`MethodId/Props/Convert` 表驱动，Delta 零分配 in-place

## 线程与资源
- header `IBytesBuilder ToBuilder` 单源（`SevenZWriteNumberToBuilder/Append*ToBuilder`，`bytes.builder Grow` 均摊，O(n) 替代 `TBytes SetLength` O(n²)）+ reader `2-entry LRU 64MiB` 缓存（大 solid 单 MRU 保留）+ `Sort` 单源 `collections.algorithms.Sort`（`TSevenZSortCtx`）+ `EnsureSortedGeneric` 懒加载，`ReverseStr/LowerBoundGeneric` 外联避热点膨胀，writer `platform.thread` 并行（`IsMultiThread` 门控，`BytesReplicateCopy` 零拷贝，Move 语义去深拷，header/Block 经 `IBytesBuilder` 均摊），`CopyMatch` 倍增 Move，`ValidateEntryName` 复用 `bytes.pathvalid` 单源

## 契约测试
- `make -C core/tests/nextpas.core.sevenz/test_sevenz clean test` 166 用例：UTF/FILETIME/LZMA2往返/BCJ全家/Delta/Deflate-BZip2黄金档/过滤链/AES/炸弹/截断等
- `make -C core/benchmarks/nextpas.core.sevenz/bench_sevenz run` 6/17/42/200/80 MB/s 锚点
