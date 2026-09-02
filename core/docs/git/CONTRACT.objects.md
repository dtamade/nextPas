# nextpas.core.git — 对象层契约（objects）

**模块路径**：`core/src/nextpas.core.git.native.{base,zlib,loose,pack,refs,objmodel,repo,write}.pas` + `nextpas.core.git.native.objects.pas` 唯一门面（`native.pas` 为已折叠空 BC shim 零类型/常量/函数转发 `@deprecated`，对象层唯一门面为 `objects`，消除双重薄网关与 I-Cache 复制，fan-in 收敛至 `objects→owners`）
**层级**：L2（同层单向 `compress/hash/zlib/checksum` 豁免；L0-L1: base, bytes, text, fs, io）
**Owner**：git lane
**不变量域**：对象存储（oid / zlib / loose / pack / refs / objmodel / repo / write）

## 1. 范围与阈值
- 源聚合：8 单元 + 1 门面 shard（`native.objects` <400 行，唯一 inline 零拷贝网关 via `bytes.ops`/`compress`/`checksum`）；`native.pas` <30 行已折叠空 BC shim（零类型/常量/函数转发 `@deprecated`，对象层唯一门面为 `objects`，消除与 objects 的类型/常量双重薄网关与 I-Cache 复制，fan-in 收敛至 objects→owners）；单 shard <800 行软阈，满足 `design-conventions.md §2` 必拆阈。
- 禁止在对象层手写压缩/哈希：zlib 透传 `compress.Deflate*`，Adler-32 单源 `checksum.adler32`，oid 比对单源 `bytes.ops.SpanEqual`（20-byte 权威 `native.base.TGitOid`）。
- 同层单向豁免：`git-native-zlib-l2-exempt` 锚点由 `scripts/git-contract-check.sh` C5 校验，限定 `Deflate*` + `Adler32Update` 单源透传，零手写 deflate/adler 循环与零 `Move` 重复。

## 2. 不变量
- Oid 20-byte 原子：`GitOidIsValidHex/FromHex/ToHex/Same` 单源 `bytes.ops`，`Same` = `SpanEqual(TByteSpan(20),TByteSpan(20))` 零分配；`TGitOid`（`bindings.structs`）已单源化为 20-byte `libgit2.base.git_oid` 别名（33-byte `TGitOid33` 及其桥接已于 Phase7 (2026-09-02) 彻底移除，`grep -R TGitOid33` 零命中，SHA256 泛型候选改经 `bytes.ops` `Len` 参化 `TByteSpan`），新模块一律经 `native.base.TGitOid` / `libgit2.base.git_oid` 20-byte 权威，`scripts/git-contract-check.sh` C5 硬门禁，Phase 7 双轨已彻底清理。
- Loose 路径 `objects/xx/yyyy` SHA-1 寻址，zlib wrapper 经 `DeflateReaderEmbedded` 流边界即停。
- Pack：`.idx v2` fanout 二分，OFS/REF delta 链深度 ≤64，CRC 不校验但 SHA-1 尾校验；`TPackFile.FMapped: IMappedFile` 独占 `PByte+Size` 零拷贝，析构释放（接口计数）。
- Refs：HEAD/loose/packed-refs 去重归并，gitdir 发现经 `EffectiveGitDir` 透 linked worktree。

## 3. 性能契约（inline/零拷贝，复用 bytes.ops 单源）
- `GitOidSame:inline` ≤80 ns/op；`GitOidIsValidHex/FromHex/ToHex` ≤150 ns/op (not inline per red line 2, 40× loop/alloc exceeds I-Cache, HexVal/HexDecode via `encoding.hex` + `bytes.ops` SpanCopy single source)；`GitOidZero:inline` via `bytes.ops` SpanFill single source；`GitKindFromMode:inline` ≤30 ns/op
- `GitZlibAdler32(PByte,Len):inline` 零拷贝（`Adler32Update(PByte,Len)` 单源，`ADLER32_MOD/NMAX` 单源，不自建循环）
- `GitZlibCompress/DecompressPtr: PByte+Len` 零拷贝透传 `compress` owner；`MapDeflateError` 纯 `TDeflateErrorCode` 分发，无 `E.Message` 拼接，热错路径零非定长分配
- 门禁：`bench_git: Oid/*, Kind/*, Zlib/*, Adler32/*` 详见总 CONTRACT §7 的 Go/Rust 同机 A/B 归一双锚。

## 4. 稳定性
- `WriteAtomic` 临时句柄 `try..finally` 原子落盘；`TPackFile` 析构释放 `IMappedFile`；`EIOError→EGitError` 映射，`EGitError` 不丢。
- 基准初始化往返校验 `BytesEqual(GitZlibDecompress(GitZlibCompress(1K)),1K)` 失败 `raise EGitError` 不泄漏（`TBytes` 受控）。

## 5. 与总约关系
- 本域权威：对象层类型/错误/阈值以本文件为准；跨域不变量仍以 `CONTRACT.md` 总索引为准。
- 缺能力先反哺 owner：新哈希/压缩能力归 `checksum/compress`，对象层仅薄转发。
