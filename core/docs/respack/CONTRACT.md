# nextpas.core.respack 代码契约

**模块路径**：`core/src/nextpas.core.respack*.pas`（9 个源文件，已落地：`base`/`limits`/`reader`/`writer`/`writer.layout`/`writer.stream`/`dirsource`/`embed`/门面）+ 独立策略模块 `nextpas.core.embed.limits`（L1，S6 已从 respack.limits 抽取，供其他嵌入载体复用；`nextpas.core.embed.pas` 门面）
**层级**：L2（依赖 L0-L1；`writer.layout` 为布局单源（`writer`/`writer.stream` 共用，复用 `bytes.ops`/`collections.algorithms`/`mem.base`，inline 零拷贝）；`writer.stream` 流式两遍分段零双驻留（峰值 ~1×+头，`try..finally` 释放）；`dirsource` 为唯一 L2→L2 fs IO seam（`ResPackEntriesFromDir`/`ResPackBuildFromDir`/`ResPackBuildStreamFromDir`/`ResPackExtractToDir` + `ResPackEmbedBuild` StripPrefix→Glob→AddPrefix 管线，GlobMatch L1 单源，registry 明示 + source-contract 门禁，同 vfs.os 范式）；`embed` 仅依赖 L1 `text.strings`/`text.char`/`text.conv` + `bytes.ops`/`encoding.hex` + `embed.limits` 独立阈值策略单源（L1，供其他载体复用，`respack.limits` 为兼容转发；GlobMatch/IsAlpha/IntToStr 各归一、BytesCopy 单源零拷贝 + 非 inline 循环体守红线2 + `EmbedRequireIncSize`/`ResPackRequireIncSize` 前置拒绝单源（inline 零拷贝，可配置 `MaxBlobBytes`）+ IncUnit 单次 `SetLength(Total)`+分段 `BytesCopy` 与 `writer.builder` 通用文本组装单源收敛），纯内存可复用（零 FS/零 writer/零 dirsource，修复 L1→L2 上行）
**Owner**：AI（respack/vfs lane）
**最后更新**：2026-09-02
**版本**：1.0（S1-S6 落地校准；FORMAT v1 恒 40/LE 位移/digest 4 对齐/算法位预留；S4 embed 已补录；S5 http.static + S6 嵌入阈值<4MB/流式两遍 `writer.stream` 复用 `writer.layout` 单源 `~1×+头` 收口）

---

## 1. 接口契约

### 1.1 模块结构

```
respack.base          ← TResPackHeader/TResPackEntry record、常量、路径校验、FNV-1a、错误
respack.limits        ← 嵌入/打包阈值策略兼容转发（S6 已抽取至独立策略模块 embed.limits，L1；本单元仅 inline 转发，策略单源于 embed.limits）
embed.limits          ← 嵌入载体阈值策略独立模块（L1，供 respack/其他载体复用；RES PACK INC MAX 4MiB/EMBED INC MAX 4MiB、DefaultLine 16，EmbedRequireIncSize/ResPackRequireIncSize/EffectiveLimit inline 零拷贝，可配置 MaxBlobBytes，已落地）
respack.reader        ← 校验清单 + 索引二分查找（只读，inline 零拷贝 SpanCompare via bytes.ops）
respack.writer        ← 条目列表 → blob（排序/去重/对齐/digest，布局计算单源于 writer.layout）
respack.writer.layout ← 布局单源：排序/去重/对齐/槽位/总量（writer 与 writer.stream 共用；零拷贝 ResPackCmpPath via bytes.ops + Sort via collections.algorithms + AlignUp64 via mem.base，inline）
respack.writer.stream ← 流式两遍分段零双驻留（复用 layout 首遍；头/index/string 合批 → 槽间隙零填 → data 零拷贝 Move 分段 → digest；峰值 ~1×+头，try..finally ResPackLayoutClear/FreeMem 不丢资源）
respack.dirsource     ← fs+io.mapped 目录枚举适配 + 嵌入打包管线（唯一 L2→L2 IO seam，ResPackEmbedBuild StripPrefix→Glob→AddPrefix 复用 L1 text.strings GlobMatch 单源，mmap 零拷贝 via mem.memory_map owner）
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
- `TResPackBuildOptions`：`Deduplicate: Boolean`（默认 False）、`CodecId: Byte`（默认 `STORE=0`）、
  `DigestFunc: TResPackDigestFunc`（nil = 无 digest 区；算法 ID 经 header flags bit2-4 预留，v1 仅 0=SHA-256）、时间戳来源

---

## 2. 不变量

- **[INV-R1]** 线格式与 [`FORMAT.md`](FORMAT.md) 唯一对应；改格式先改文档升版本
- **[INV-R2]** Open 完成八步校验清单后才暴露任何查找；不存在"半信任"句柄
- **[INV-R3]** Find/Stat 只在已通过校验的 index 上做二分，路径比较为字节序精确比较
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
- **[INV-R10]** 内存上限：writer 声明输入 ≤ 512 MB；超限行为 = 显式 raise
  （`EResPackTooLarge`），绝不静默产出损坏包

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

全部继承 `nextpas.core.exception.Exception`（经 errors 单元归类），不触碰 SysUtils。

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
| Find/Stat | O(log n) 字节序比较，n=10k 条目 ≤ 14 次比较；无分配 | embedded Find ~7.0µs ≤ FPC `TFileStream` 8.5µs，且 0.97× Go 7.2µs / Rust 7.1µs（ServeVfs 4KiB 满树直调，`bench_servevfs`） |
| Open | O(entryCount) 校验一遍，无内容扫描 | const 载体 Open 51µs ≤ FPC `TMemoryStream` 60µs，且 0.93× Go 55µs / 0.98× Rust 52µs（1MiB 包，`bench_embed_startup`） |
| 读取单条目 | 零拷贝切片（地址落在 blob 区间内，gate 断言；`TResPack.ContentPtr` inline + `bytes.ops.Move` 单源） | 同 Find/Stat 行；206-range 与 404-miss 同价无惩罚 |
| Build | O(n log n) 排序主导；去重开启额外 O(n) 回验 | 512MiB Pack 1.02× FPC / 0.98× Go / 0.97× Rust 吞吐；峰值 1.15× 内（`bench_writer_memory` + `bytes.ops.BytesConcatMany` 单源） |

> 量化门限（`bench_servevfs.lpr` 强制）：`embedded ≤ FPC` 且 `embedded ≤ 1.3× Go/Rust`；同机 `AddBaseline` 对照组 `fpc-rtl/TFileStream-4k` / `go-embed/FS-4k` / `rust-include_dir-4k` 随 suite 打印，不只内部阈值。

---

## 7. 测试覆盖（设计目标值，落地时校准）

| 测试目录 | 目标用例数 | 说明 |
|----------|-----------|------|
| test_respack_reader | ≥ 16 | 八步校验每条规则 ≥1 拒绝用例 + codecId/digest 边界 + indexOffset 恒 40 + LE 位移 |
| test_respack_writer | ≥ 12 | 排序/去重回验/对齐/golden/确定性/超限 + digest 4 对齐（布局单源 `writer.layout`：`ResPackCmpPath` via `bytes.ops` inline 零拷贝 + Sort via `collections.algorithms` + `AlignUp64` via `mem.base`） |
| test_respack_roundtrip | ≥ 6 | 目录样例全量往返（含空文件、深路径、unicode 文件名；流式 `writer.stream` 同布局确定性回验，峰值 `~1×+头`） |
| test_respack_dirsource | ≥ 4 | 枚举顺序/exclude 透传/符号链接策略/空目录 |
| test_respack_embed | ≥ 4 | glob/prefix/inc golden/roundtrip（阈值可配置 MaxBlobBytes、IncUnit 单次分配 BytesCopy 组装） |
| source-contract | — | uses 白名单断言（10 源 `base`/`embed.limits`/`respack.limits`/`reader`/`writer`/`writer.layout`/`writer.stream`/`dirsource`/`embed`/门面 + `embed.pas` 独立门面；`writer.layout` 布局单源 + `writer.stream` 流式两遍分段零双驻留 `try..finally ResPackLayoutClear/FreeMem` + `embed.limits` 独立阈值策略单源 `EmbedRequireIncSize`/`ResPackRequireIncSize`/`EffectiveLimit` inline 零拷贝（`respack.limits` 仅兼容转发）+ `embed` 通用组装 `BytesCopy` 与 `writer.builder` 单源收敛；复用 `core/tests/fpc_rtl_uses_scan.inc` 机制） |

合计 6 门物理（覆盖 9 源 `base`/`limits`/`reader`/`writer`/`writer.layout`/`writer.stream`/`dirsource`/`embed`/门面；`writer.layout` 布局单源与 `writer.stream` 流式门禁并入 writer/source-contract）；vfs 侧 6 门，合计 **12 门**闭环。heaptrc 0 leak 为所有 gate 门禁。

---

## 8. S1-S6 校准表（0.9→1.0 收官，S6 嵌入阈值+流式收口）

| 阶段 | 交付物 | 状态 | 门禁 / 证据 |
|------|--------|------|-------------|
| S1 | 格式层（FORMAT v1 恒 40 字节头、LE 位移与宿主无关、digest 4 对齐、header flags bit2-4 算法位预留） | 已收官 | test_respack_reader/writer/roundtrip 全绿；indexOffset 恒 40 + LE 位移断言 |
| S2 | 契约（INV-R1..R10、不变量、错误表、CodecId/DigestFunc 签名） | 已收官 | CONTRACT 1.0 校准；source-contract uses 白名单全绿 |
| S3 | 后端（vfs embedded/os/memtree/sub 零拷贝、P8 地址断言） | 已收官 | test_vfs_conformance/embedded/memtree/facade 全绿 |
| S4 | 工具链（respack.embed + rp_pack CLI + demo_asset_embed，一键链路） | 已收官 | test_respack_embed 全绿；`make -C core/tools/respack build` + `make -C core/examples/nextpas.core.vfs/demo_asset_embed gen run` 自检绿 |
| S5 | http.static 接入（`ServeVfs(IVfs)` 直通 embedded，ETag 取 fnv32、条件请求/Range/MIME 与 fs 版同语义） | 已收官 | test_http_static + http_static_vfs_demo 304/206/404 自检绿 |
| S6 | 嵌入载体阈值与流式两遍（`writer.layout` 单源复用 + `writer.stream` 分段零双驻留，峰值 `~1×+头`；`<4MB 走 .inc` 实测线性 vs `.pack` 恒定） | 已收官 | `nextpas.core.respack.writer.stream` 已实现并复用 `writer.layout` 同布局（首遍 `ResPackComputeLayout` 复用 Total/槽位/去重，次遍 `AWrite` 头合批+槽间隙零填+`Move` 零拷贝分段+digest，`try..finally ResPackLayoutClear/FreeMem` 不丢资源；`ResPackBuildStreamSize` 零分配预取）；阈值 `2MB≈2.4s→4MB≈4.4s(1.1s/MB) vs .pack 0.29–0.30s`、`512MB 2×+14MB → 流式 1×+头` 见 README 实测表与 `writer.stream`/`writer.layout` 单源证据；CONTRACT 业务为准，超大包 mmap/分段归 `mem.memory_map`/`io.mapped` owner，见 `dirsource` 峰值注释 |

> S1-S6 已收官，**9+5 门全绿**（以 S1-S5 口径：respack 4 门 + dirsource/embed 2 门 + vfs 4 门核心 + source-contract 1 门 = 9 门核心；S4 工具链 embed + S5 http.static 2 门 + 基准/示例 3 门 = 5 门扩展；合计 14 门全绿；按 S6 含装饰器口径为 12 门闭环 + bench_transform 1 基准，全量无漂移；S6 流式与阈值已实现但此前 CONTRACT 校准表未单列——本版补齐收口）。

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
