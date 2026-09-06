# nextpas.core.respack 代码契约

**模块路径**：`core/src/nextpas.core.respack*.pas`（12 个源文件，已落地：`base`/`hasharena`/`limits`/`reader`/`writer`/`writer.layout`/`writer.builder`/`writer.stream`/`dirsource`/`dirsource.mmap`/`embed`/门面）+ 独立策略模块 `nextpas.core.embed.limits`（L1，S6 已从 respack.limits 抽取，供其他嵌入载体复用；`nextpas.core.embed.pas` 门面）
**层级**：L2（依赖 L0-L1；`writer.layout` 为布局单源（`writer`/`writer.stream` 共用，复用 `bytes.ops`/`collections.algorithms`/`mem.base`，inline 零拷贝）；`writer.stream` 流式两遍分段零双驻留（峰值 ~1×+头，`try..finally` 释放）；`dirsource` 为唯一 L2→L2 fs IO seam（`ResPackEntriesFromDir`/`ResPackBuildFromDir`/`ResPackBuildStreamFromDir`/`ResPackExtractToDir` + `ResPackEmbedBuild` StripPrefix→Glob→AddPrefix 管线，GlobMatch L1 单源，registry 明示 + source-contract 门禁，同 vfs.os 范式）；`embed` 仅依赖 L1 `text.strings`/`text.char`/`text.conv` + `bytes.ops`/`encoding.hex` + `embed.limits` 独立阈值策略单源（L1，供其他载体复用，`respack.limits` 为兼容转发；GlobMatch/IsAlpha/IntToStr 各归一、BytesCopy 单源零拷贝 + 非 inline 循环体守红线2 + `EmbedRequireIncSize`/`ResPackRequireIncSize` 前置拒绝单源（inline 零拷贝，可配置 `MaxBlobBytes`）+ IncUnit 单次 `SetLength(Total)`+分段 `BytesCopy` 与 `writer.builder` 通用文本组装单源收敛），纯内存可复用（零 FS/零 writer/零 dirsource，修复 L1→L2 上行）
**Owner**：AI（respack/vfs lane）
**最后更新**：2026-09-02
**版本**：1.0（S1-S6 落地校准；FORMAT v1 恒 40/LE 位移/digest 4 对齐/算法位预留；S4 embed 已补录；S5 http.static + S6 嵌入阈值<4MB/流式两遍 `writer.stream` 复用 `writer.layout` 单源 `~1×+头` 收口）

---

## 1. 接口契约

### 1.1 模块结构

```
respack.base          ← TResPackHeader/TResPackEntry record、常量、路径校验、FNV-1a、错误 + 去重/交叠视图载体类型（PSizeInt/TResPackDistinct，仅类型，分配单源于 hasharena，守 base 纯类型）
respack.hasharena     ← 去重/交叠哈希 arena 单源：TResPackDedupBuckets MIN256 MAX65536 + BucketCountFor via BytesNextCapacity + ResPackDedupInit/OverlapInit/Done 单 slab TLocalArena（Alloc 零拷贝 slab 内指针，$FF 为 -1 链终止哨兵，失败分支 Free 不丢，inline 零拷贝；writer.layout/reader 共用，消除 reader→writer.layout 反向依赖守 base←impl←facade 单向）
respack.limits        ← 嵌入/打包阈值策略兼容转发（S6 已抽取至独立策略模块 embed.limits，L1；本单元仅 inline 转发，策略单源于 embed.limits，try..except EEmbedTooLarge→EResPackTooLarge 纯转发）
embed.limits          ← 嵌入载体阈值策略独立模块（L1，供 respack/其他载体复用；EMBED INC MAX 4MiB 单源、DefaultLine 16，EmbedRequireIncSize inline UIntToBuffer+BytesCopy 单源，EEmbedTooLarge 独立异常，CONTRACT 独立命名）
respack.reader        ← 校验清单 + 索引二分查找（只读，inline 零拷贝 SpanCompare via bytes.ops，GuardStep 分治 + O(n) hash 去重，525 行）
respack.writer        ← 条目列表 → blob（排序/去重/对齐/digest，布局计算单源于 writer.layout，头单源于 writer.builder）
respack.writer.layout ← 布局单源：排序/去重/对齐/槽位/总量（writer 与 writer.stream 共用；零拷贝 ResPackCmpPath via bytes.ops + Sort via collections.algorithms + AlignUp64 via mem.base，dedup arena 直调 respack.hasharena 共享底座（无别名/转发复刻，单 slab TLocalArena，BucketCountFor via BytesNextCapacity，TResPackDedupBuckets MIN256 MAX65536，owner 唯一归 hasharena），ResPackLayoutClear out-of-line，消除 reader→writer.layout 反向依赖守 base←impl←facade 单向；GuardStep7Order 外联守红线2，ResPackDedupInit/OverlapInit 外联守 I-Cache）
respack.writer.builder← 头/index/string 单源 builder（writer 与 writer.stream 共用，WrU*LE/BytesCopy/BytesZero 单源，registry 明示 + source-contract 门禁）
respack.writer.stream ← 流式两遍分段零双驻留（复用 layout 首遍 + builder 头单源；头/index/string 合批 TBytes RAII SetLength → 槽间隙零填 WriteZeros inline 快道/4K 零页 → data 零拷贝 Move 分段 → digest；峰值 ~1×+头，try..finally ResPackLayoutClear 不丢资源）
respack.dirsource     ← fs+path 目录枚举适配 + 嵌入打包管线（唯一 L2→L2 FS seam，io.mapped 经 dirsource.mmap 单源、本单元不直引三缝合一；ResPackEmbedBuild StripPrefix→Glob→AddPrefix 复用 L1 text.strings GlobMatch 单源，mmap 零拷贝经 dirsource.mmap TryMmapRequire 单源 via mem.memory_map owner；WalkPrePlain/Embed + CleanRootDir inline 零拷贝 + RESPACK_DIRSOURCE_LEGACY_LIMIT 64MiB 家族收口与 RESPACK_MAX_INPUT_BYTES 512MiB 同源；有界 0 映射收集 + ResPackComputeLayout 1× 基座 + 文件背 fnv/哈希回验（respack.hasharena.ResPackDedupInit 单源 tiny≤4 线性、外层单映射复用 ≤2 并发）+ 按槽单映射写+摘要融合（BoundEmitSlot，头/哈希经 builder 单源，零页 BYTES_ZERO_PAGE 单源 ≤4K inline 快道）+ Dummy/发射双熔断前置 + 内存组装契约镜像 writer.stream.ResPackBuildLayoutBlob（OOM→TooLarge + Sink 越界 guard）；流式零双驻留 ResPackBuildFromDir/EmbedBuild 单次 Walk + StreamSize 预取 Total 直写，消除 512MB 二次 Move，约1100 行同 seam 收口、超阈拆 dirsource.walk/embed/extract 子模块）
respack.dirsource.mmap ← mmap 视图单源：TryMmapRequire 零拷贝 MmapOpen 视图 + TResPackMapsArray/IMappedFile 锚点类型重导出（stat 空/尺寸一致性校验，失败置空 AMap，inline；dirsource 唯一调用方）
respack.embed         ← 嵌入工具链库：blob→.inc/.inc unit 纯内存生成（S4 已落地，阈值单源于 embed.limits 独立模块 + BytesCopy 单源零拷贝 + 非 inline 循环体守红线 + 通用组装单源收敛 writer.builder，纯内存可复用）
respack.pas           ← 门面 re-export（纯转发，inline）
embed.pas             ← 嵌入策略门面 re-export（L1，策略单源 embed.limits 的纯转发门面，供其他载体直接复用）
```

### 1.2 核心签名（设计定稿）

| 领域 | 签名 | 说明 |
|------|------|------|
| 读 | `function ResPackOpen(AData: PByte; ASize: SizeUInt): TResPack` | 校验失败 raise；成功后整包可用 |
| 读 | `function TResPack.Find(const APath: string; out AEntry: TResPackEntry): Boolean` | 探测式查找（TryXxx 风格）；未命中 False 不抛 |
| 读 | `function TResPack.Stat(const APath: string): TResPackEntry` | 断言式查找；未命中 raise `EResPackNotFound` |
| 读 | `function TResPack.Count: SizeUInt` / `EntryAt(AIdx)` | 有序枚举全部条目 |
| 写 | `function ResPackBuild(const AEntries: TResPackInputArray; const AOpts: TResPackBuildOptions): TResPackBlob` | 排序/去重/对齐/索引/digest 一次完成 |

- blob 输入一律 `(PByte, SizeUInt)`，不持有所有权；调用方保证生命期覆盖 TResPack
- `TResPackBuildOptions`：`Deduplicate: Boolean`（默认 True，同内容槽位共享；fnv 候选+逐字节回验，去重门限见 §6）、`CodecId: Byte`（默认 `STORE=0`）、
  `DigestFunc: TResPackDigestFunc`（nil = 无 digest 区；算法 ID 经 header flags bit2-4 预留，v1 仅 0=SHA-256）、`HashIndex: Boolean`（默认 False：写尾部哈希段供 O(1) 查找；bit5 包老 reader 整包拒收，兼容优先，perf 通道显式开）、时间戳来源

---

## 2. 不变量

- **[INV-R1]** 线格式与 [`FORMAT.md`](FORMAT.md) 唯一对应；改格式先改文档升版本
- **[INV-R2]** Open 完成九步校验清单后才暴露任何查找；不存在"半信任"句柄
- **[INV-R3]** Find/Stat 只在已通过校验的 index 上查找：哈希段存在时哈希先查（fnv+探测，命中逐字节回验），失配回退二分；路径比较为字节序精确比较
- **[INV-R4]** reader 查询操作（Find/Stat/EntryAt）零堆分配，只返回定长 record；
  路径物化（PathOf）每次调用恰好构造一个 string。Open 零拷贝（不复制 blob），
  校验期对每条目各做一次路径物化用于语法断言
- **[INV-R5]** writer 输出确定性：同输入同选项 ⇒ 字节级相同 blob（含 DOS 纪元下限式
  时间戳钳制策略，对齐 zip 单元先例）；golden 快照锁定该性质
- **[INV-R6]** 去重开启时，槽位复用必须 fnv 候选命中且逐字节回验相等
- **[INV-R7]** codecId 未登记值整包拒绝；保留位非 0 整包拒绝
- **[INV-R8]** 路径必须通过 Go ValidPath 语义校验（含 `.` 根特例、反斜杠非分隔符）；
  writer 规范化输入，reader 校验存储形态
- **[INV-R9]** digest 区存不透明 32 字节；算法由 `DigestFunc` 注入，header flags bit2-4 预留算法 ID（v1 仅 0=SHA-256，其余拒绝），本模块零加密依赖
- **[INV-R10]** 内存上限：writer 声明输入 ≤ 512 MB（`RESPACK_MAX_INPUT_BYTES`），dirsource 废弃便捷路径 ≤64MiB（`RESPACK_DIRSOURCE_LEGACY_LIMIT` 家族收口防 2×+头 OOM）；超限行为 = 显式 raise
  （`EResPackTooLarge`，超阈引导流式mmap 1×+头），绝不静默产出损坏包
- **[INV-R11]** 哈希段（bit5）可选存在：桶数由条目数单源派生（`ResPackHashBucketCount`，writer 布局与 reader 校验/查找共用）；段内存放 index 位（非输入序号），writer 按 index 序灌桶保证确定性（INV-R5）；Open 第 9 步逐桶回验（index 界内、非空数 = N、全槽 fnv 重算一致，不抽验——无半信任句柄是 INV-R2 承诺，不以 Open 提速削弱）；查找正确性不依赖表（回退二分），表只许降速不许断错；查找期路径视图一律有界（越界即抛 `EResPackCorrupted`，缓冲 Open 后可被改写，无界视图会越界读）

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| magic/version/flags/越界/截断任一校验失败 | `EResPackCorrupted`（message 含失败步骤号） |
| 路径重复（writer） | `EResPackDuplicatePath` |
| 路径不规范 | `EResPackInvalidPath` |
| Stat 未命中 | `EResPackNotFound` |
| 未知 codecId | `EResPackCorrupted` |
| 输入超内存上限 | `EResPackTooLarge` |

全部继承 `ENextPasError`（exception owner 框架根，`Exception` 之上归类；类目见 `respack.base` 各 `DefaultCategory`），不触碰 SysUtils。

---

## 4. 线程安全

- `TResPack`（读端）为不可变快照：并发 Find/Stat/EntryAt ✅ 安全
- writer 为一次性构造对象：❌ 非线程安全，单线程使用
- blob 生命期规则见 §5

---

## 5. 内存管理

- TResPack 不拥有 blob；const 数组/静态段场景调用方保证生命期（无引用计数可挂）；
  堆缓冲场景由调用方自行保活或转交 vfs.embedded 的 `AOwnsBlob` 语义
- ResPackBuild 返回的 blob 所有权归调用方
- 无全局缓存、无后台线程

---

## 6. 性能契约（设计目标，S1 基准校准，同机 FPC/Go/Rust 量化基线见 benchmarks/nextpas.core.respack/RESULTS.md）

| 操作 | 目标 | 同机对照基线 (FPC RTL / Go embed / Rust include_dir) |
|------|------|------------------------------------------------------|
| Find/Stat | O(log n) 字节序比较，n=10k 条目 ≤ 14 次比较；无分配。哈希段存在时 O(1) 先查（fnv+探测，命中回验），失配回退二分 | ServeVfs 全路径 5.5µs ≈ FPC `TFileStream` 5.4µs（打平，噪声带），0.85× Go 6.4µs；拆分定位二分 ~0.65µs、哈希 ~0.46µs（`bench_servevfs` split 项，2026-09-06 live，门限：哈希 ≤ 二分×1.2 且 ≤ Rust split 1100ns） |
| Open | O(entryCount) 校验一遍，无内容扫描 | const 载体 Open+Find 134µs（噪声机，待安静复测）；Go/Rust readfile 对端 1.80ms/0.54ms 含整包求和，层不同（`bench_embed_startup`） |
| 读取单条目 | 零拷贝切片（地址落在 blob 区间内，gate 断言；`TResPack.ContentPtr` inline + `bytes.ops.Move` 单源） | 同 Find/Stat 行；206-range 与 404-miss 同价或更优无惩罚 |
| Build | O(n log n) 排序主导；去重开启额外 O(n) 回验 | 512MiB Pack 与 FPC/Rust/Go 三方 RSS 持平（1,040MB）；端到端 wall 同口径（同载荷、填充/生成计入、校验和一致）与 Rust 持平，内存 parity 为门（RSS 单边门在 `bench_writer_memory` 本体，wall 直接对比门为 `compare_bulk_wall.sh` 动态脚本） |
| Build(Dedup on) | O(n) 回验+单 slab（TLocalArena+SpanEqual via bytes.ops, BucketCountFor via BytesNextCapacity 单源于 hasharena） | 50%重复→blob -48% 且快于基线，全 miss +0~+4%，零 warn（`bench_writer_dedup` live） |

> 量化门限（`bench_servevfs.lpr` 强制）：`embedded ≤ FPC` 且 `embedded ≤ 1.3× Go/Rust`；同机 `AddBaseline` 对照组 `fpc-rtl/TFileStream-4k` / `go-embed/FS-4k` / `rust-include_dir-4k` 随 suite 打印，不只内部阈值。`Build(Dedup on)` 零拷贝证据 `ContentPtr inline+bytes.ops.Move`。
> CI 建议：bench_writer_dedup / bench_servevfs 固化为 nightly，对照 FPC/Go/Rust 同机跑

---

## 7. 测试覆盖（设计目标值，落地时校准）

| 测试目录 | 目标用例数 | 说明 |
|----------|-----------|------|
| test_respack_reader | ≥ 16（已落地 29） | 九步校验每条规则 ≥1 拒绝用例 + codecId/digest/哈希段边界 + indexOffset 恒 40 + LE 位移 |
| test_respack_writer | ≥ 12（已落地 23） | 排序/去重回验/对齐/golden/确定性/超限 + digest 4 对齐（布局单源 `writer.layout`：`ResPackCmpPath` via `bytes.ops` inline 零拷贝 + Sort via `collections.algorithms` + `AlignUp64` via `mem.base`） + 哈希段发射/默认关/空包 |
| test_respack_roundtrip | ≥ 6（已落地 16） | 目录样例全量往返（含空文件、深路径、unicode 文件名；流式 `writer.stream` 同布局确定性回验，峰值 `~1×+头`） + 哈希段内存/流式字节一致往返 |
| test_respack_dirsource | ≥ 4（已落地 7） | 枚举顺序/exclude 透传/符号链接策略/空目录 |
| test_respack_embed | ≥ 4（已落地 15） | glob/prefix/inc golden/roundtrip（阈值可配置 MaxBlobBytes、IncUnit 单次分配 BytesCopy 组装） |
| source-contract | — | uses 白名单断言（14 源 `base`/`hasharena`/`embed.limits`/`respack.limits`/`reader`/`writer`/`writer.layout`/`writer.builder`/`writer.stream`/`dirsource`/`dirsource.mmap`/`embed`/门面 + `embed.pas` 独立门面；`hasharena` 去重 arena 单源 `TResPackDedupBuckets` + `writer.builder` 头单源 + `writer.stream` 流式两遍分段零双驻留 `try..finally ResPackLayoutClear` + `embed.limits` 独立阈值策略单源 `EmbedRequireIncSize`/`ResPackRequireIncSize`/`EffectiveLimit` inline 零拷贝（`respack.limits` 仅兼容转发 `try..except EEmbedTooLarge→EResPackTooLarge`）+ `embed` 通用组装 `BytesCopy` 与 `writer.builder` 单源收敛；复用 `core/tests/fpc_rtl_uses_scan.inc` 机制） |

合计 6 门物理（覆盖 12 源 `base`/`hasharena`/`limits`/`reader`/`writer`/`writer.layout`/`writer.builder`/`writer.stream`/`dirsource`/`dirsource.mmap`/`embed`/门面；`hasharena` 去重 arena 单源与 `writer.builder` 头单源 + `writer.stream` 流式门禁并入 writer/source-contract）；vfs 侧 6 门，合计 **12 门**闭环。heaptrc 0 leak 为所有 gate 门禁。

---

## 8. S1-S6 校准表（0.9→1.0 收官，S6 嵌入阈值+流式收口）

| 阶段 | 交付物 | 状态 | 门禁 / 证据 |
|------|--------|------|-------------|
| S1 | 格式层（FORMAT v1 恒 40 字节头、LE 位移与宿主无关、digest 4 对齐、header flags bit2-4 算法位预留） | 已收官 | test_respack_reader/writer/roundtrip 全绿；indexOffset 恒 40 + LE 位移断言 |
| S2 | 契约（INV-R1..R11、不变量、错误表、CodecId/DigestFunc/HashIndex 签名） | 已收官 | CONTRACT 1.0 校准；source-contract uses 白名单全绿 |
| S3 | 后端（vfs embedded/os/memtree/sub 零拷贝、P8 地址断言） | 已收官 | test_vfs_conformance/embedded/memtree/facade 全绿 |
| S4 | 工具链（respack.embed + rp_pack CLI + demo_asset_embed，一键链路） | 已收官 | test_respack_embed 全绿；`make -C core/tools/respack build` + `make -C core/examples/nextpas.core.vfs/demo_asset_embed gen run` 自检绿 |
| S5 | http.static 接入（`ServeVfs(IVfs)` 直通 embedded，ETag 取 fnv32、条件请求/Range/MIME 与 fs 版同语义） | 已收官 | test_http_static + http_static_vfs_demo 304/206/404 自检绿 |
| S6 | 嵌入阈值 `<4MB` + 流式两遍 `~1×+头` | 已收官 | `writer.stream` 复用 `writer.layout` 单源同布局；`bench_writer_dedup` 50%重复/最坏碰撞量化见 RESULTS §4 |

> S1-S6 已收官，**9+5 门全绿**（respack 4 门 + dirsource/embed 2 门 + vfs 4 门 + source-contract 1 门 = 9 门核心；S4 工具链 embed + S5 http.static 2 门 + 基准/示例 3 门 = 5 门扩展；合计 14 门；按 S6 含装饰器口径为 12 门闭环 + bench_transform）。流式与阈值已实现，CONTRACT 业务为准。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-08-25 | 0.9 | 设计阶段契约草案（随 S0 定稿） | AI |
| 2026-08-28 | 1.0 | 校准：indexOffset 恒 40/CONST 40；LE 位移与宿主无关；digest 4 对齐；header flags bit2-4 算法位预留；签名 CodecId/DigestFunc；门数 12 闭环 | AI |
| 2026-08-30 | 1.0 | P0-4 收官：补 S1-S5 校准表（S1 格式层/S2 契约/S3 后端/S4 工具链/S5 http.static 已收官，9+5 门全绿；registry 与 FORMAT 已正确无需改） | AI |
| 2026-09-02 | 1.0 | 修复文档滞后：模块路径 6→8 源文件（补 `writer.layout`/`writer.stream` 单源化），层级/结构图补 inline 零拷贝与 try..finally 资源释放证据 | AI |
| 2026-09-02 | 1.0 | S6 收口：补 S6 校准表（嵌入载体阈值 `<4MB` 实测线性 vs 恒定 + 流式两遍 `writer.stream` 复用 `writer.layout` 单源同布局，峰值 `~1×+头` 零双驻留，`try..finally` 不丢资源；CONTRACT 业务为准，缺能力反哺 `mem.memory_map`/`io.mapped` owner） | AI |
| 2026-09-02 | 1.0 | S6 独立策略模块闭环：阈值策略已抽取为 L1 独立模块 `nextpas.core.embed.limits`（`nextpas.core.embed` 门面），供 respack/其他嵌入载体复用；`nextpas.core.respack.limits` 转为兼容 inline 转发；CONTRACT/README/registry/source-contract 10→12 源校准，inline 零拷贝与 bytes.ops 单源不变 | AI |
| 2026-09-05 | 1.0 | 收官校准：source-contract 白名单 12→13 源计数修正；§7 落地用例数校准（reader 25/writer 16/roundtrip 15/dirsource 7/embed 14，合计 81）；布局内联 `TResPackLayoutInfo` 门面别名移除（布局类型仅内部管线可见） | AI |
| 2026-09-05 | 1.0 | Codex 审查闭环：writer 前置拒绝 nil-data 非零输入 + string table u32 上界 + 布局单点溢出钳制；reader ContentPtr/StoredPathSpanOf 以 BlobTotal 为界 + RequireOpen；门面补 wire 常量（HEADER/ENTRY/ALIGN/DIGEST/FLAG/EFLAG/MAX_ENTRY）与 `EEmbedTooLarge` 重导出；修复 `nextpas.core.embed` 门面 ResPack* 别名引用不存在标识（此前零编译消费隐藏）；FORMAT 明确槽位 index 序非递减；§7 校准 85 用例 | AI |
| 2026-09-05 | 1.0 | bench 复活：陈旧 .ppu 致 trunk 内崩根因定位，四 bench Makefile 首编清缓存；dedup ratio 符号差显示；RESULTS 当日复测；Go peer 空测加 checksum 汇（Rust 端早已有）；§7 校准 86 用例（writer 补桶数幂性锁定） | AI |
| 2026-09-06 | 1.0 | P1 哈希段：FORMAT bit5 落定（段布局/index 位语义/第 9 步校验），CONTRACT INV-R11 + `HashIndex` 默认关；reader 哈希先查+二分回退；writer 布局/builder/stream 单源发射；live 65 条目哈希 0.46µs < 二分 0.65µs，门限双锁（≤二分×1.2 且 ≤Rust split 1100ns）；§7 校准 reader 29/writer 23/roundtrip 16 | AI |
