# nextpas.core.vfs 代码契约

**模块路径**：`core/src/nextpas.core.vfs*.pas`（13 个源文件：base/intf/errors/memtree/embedded/os/sub/mount/overlay/util + transform/compressed L3单缝装饰器 + 门面）
**层级**：L2 基座（依赖 L0-L1；`os` 单元例外依赖 fs/path；`embedded` 另依赖 respack.reader；`mount/overlay` 纯复合零额外依赖）+ L3 装饰器单缝寄居（`transform/compressed`  via Registry 单缝白名单过渡，L3→L2 仅实现侧单向使用 compress.gzip + bytes.ops 单源，接口层字面量 32MiB 数值对齐 compress.base GZIP_MAX canonical 单源、漂移由 source-contract 锁定，长期聚合为独立 L3 族 nextpas.core.vfs.decorator、L7 到期移除白名单固化 L0-L3 单向依赖，现阶段以单缝+文档正名守层级高级感统一性）
**层级**：L2 基座（依赖 L0-L1；`os` 单元例外依赖 fs/path；`embedded` 另依赖 respack.reader；`mount/overlay` 纯复合零额外依赖）+ L3 装饰器单缝寄居（`transform/compressed`  via Registry 单缝白名单过渡，L3→L2 仅依赖 compress.base GZIP_MAX单源 + bytes.ops 单源，长期随 L3 族聚合拆分，现阶段以单缝+文档正名守层级高级感统一性）
**层级**：L2 基座（依赖 L0-L1；`os` 单元例外依赖 fs/path；`embedded` 另依赖 respack.reader；`mount/overlay` 纯复合零额外依赖）+ L3 装饰器单缝寄居（`transform/compressed`  via Registry 单缝白名单过渡，L3→L2 仅依赖 compress.base GZIP_MAX单源 + bytes.ops 单源，长期聚合为独立 L3 族 nextpas.core.vfs.decorator 到期移除白名单固化跨层依赖，现阶段以单缝+文档正名守层级高级感统一性）
**层级**：L2 基座（依赖 L0-L1；`os` 单元例外依赖 fs/path（单向 allowlist 单缝，cycle-gated）；`embedded` 另依赖 respack.reader（单向 allowlist 单缝，cycle-gated）；`mount/overlay` 纯复合零额外依赖；两处 L2→L2 超出默认 L0-L1 需 source-contract 单向门禁防循环）+ L3 装饰器单缝寄居（`transform/compressed`  via Registry 单缝白名单过渡，L3→L2 仅依赖 compress.base GZIP_MAX单源 + bytes.ops 单源，长期随 L3 族聚合拆分，现阶段以单缝+文档正名守层级高级感统一性）
**Owner**：AI（respack/vfs lane）
**最后更新**：2026-09-02
**版本**：1.7（匠心修复：transform 栈上 2 字节零堆分配 + 泛型路径 32MiB 防 bomb 统一（VFS_DECOMPRESS_MAX_BYTES 单源）+ L7 单缝正名固化，13门闭环保）

---

## 1. 接口契约

### 1.1 模块结构

```
vfs.base      ← TEntryInfo/TStatInfo、ValidPath 工具、常量（ValidPath单源 base.pathvalid；VFS_DECOMPRESS_MAX_BYTES 字面量 32MiB 数值对齐 compress.base GZIP_MAX canonical 单源，base/compressed 双字面量对齐、接口层无 L2→L2，漂移由 source-contract 锁定）
vfs.intf      ← IVfs/IVfsETag/IVfsServeMeta 契约
vfs.errors    ← EVfsError(Op/Path) 及子类（Op∈{'stat','open','list','read','wrap'}）
vfs.memtree   ← 内存不可变树 + Builder（Int64下标防回绕、防御拷贝防悬垂、两段式Freeze）
vfs.embedded  ← respack blob → IVfs（零拷贝切片，EMBEDDED_POOL_SIZE=16 SpinLock池化）
vfs.os        ← nextpas.core.fs → IVfs 适配
vfs.sub       ← 重定根视图包装（Go fs.Sub 对等物）
vfs.mount     ← 挂载复合视图：多IVfs前缀最长匹配聚合（P2完整性，ETag/ServeMeta透传，CaseSensitive一致性）
vfs.overlay   ← 叠加视图：多IVfs同根优先级叠加（游戏 patch>dlc>base 热更模型，List去重合并，ETag/ServeMeta优先透传）
vfs.util      ← 便利函数（VfsStat/List/ReadAll/Walk，Go包级辅助同构）
vfs.transform ← L3单缝通用字节变换装饰器：TVfsTransformFunc/Should/HeaderPred 三谓词注入，单流 4K HeaderPred 单源决策器（Stat/OpenRead 共用，inline+Move 零拷贝复用已读头，命中大文件同一 IStream 补读剩余免二次 OpenRead/二次 4K，Header假时Stat回 FInner.Stat/OpenRead零物化直透），大文件 2 字节栈缓冲零堆分配轻量预判免 4K，泛型路径 32MiB 防 bomb 统一（VFS_DECOMPRESS_MAX_BYTES→GZIP_MAX 单源，输入/输出双阈值限幅防 OOM），压缩/加密共用模板，ETag禁用，try-finally Close 不丢
vfs.compressed← L3解压薄门面（单缝寄居正名，Registry 白名单过渡，L7 聚合拆分为 decorator）：经transform单源决策器承载gzip（VFS_DECOMPRESS_MAX_BYTES 字面量 32MiB 数值对齐 compress.base GZIP_MAX canonical 单源、漂移由 source-contract 锁定 + bytes.ops BytesIsGzip inline 零拷贝单源，daAuto 4K HeaderPred 直接复用 transform.TRANSFORM_HEADER_PEEK 无本地别名，薄门面仅策略，防 bomb 由 transform 统一承载）
vfs.pas       ← 门面 re-export + 便利函数 + ETag/Decompress/Mount/Overlay重导出（IVfsETag/IVfsServeMeta/VFS_DECOMPRESS_MAX_BYTES/daGzip/daAuto + CreateTransformingVfs/CreateMountedVfs/VfsMountEntry/CreateOverlayVfs）
```

### 1.2 核心签名（设计定稿）

| 领域 | 签名 | 说明 |
|------|------|------|
| 装配 | `CreateMemTreeVfs(ATree): IVfs` | Builder Freeze 产物 |
| 装配 | `CreateEmbeddedVfsOwned/Borrowed(AData: PByte; ASize: SizeUInt): IVfs` | 零拷贝后端；Owned 归 VFS 所有（FreeMem）、Borrowed 归调用方（const 段零 Free，防布尔陷阱 double-free） |
| 装配 | `CreateOsVfs(const ARoot: string): IVfs` | 真实目录后端 |
| 视图 | `CreateSubVfs(AFs: IVfs; const ASubRoot: string): IVfs` | 重定根，不改底层实例 |
| 视图 | `CreateMountedVfs(AMounts: array of TVfsMountEntry): IVfs` + `VfsMountEntry(APrefix,AFs)` | 挂载复合视图：多IVfs前缀最长匹配（根'.'兜底），List根去重合并，CaseSensitive一致性推导，ETag/ServeMeta透传 |
| 视图 | `CreateOverlayVfs(AList: array of IVfs): IVfs` | 叠加视图：同根优先级叠加 patch>dlc>base（首命中胜出，List去重合并，ETag优先透传），游戏热更/DLC模型 |
| 装饰 | `CreateTransformingVfs(AInner: IVfs; ATransform: TVfsTransformFunc; AShould: TVfsShouldTransformFunc; AHeaderPred: TVfsHeaderPredicateFunc)` | L3单缝变换装饰器（单源决策器 TryResolveViaHeaderSingleStream）：泛型字节变换（压缩/加密共用模板，三谓词），`Stat` 单流 4K HeaderPred 免大文件全量读+小文件复用 Header 零二次 IO、`OpenRead` HeaderPred假时零物化直透 `FInner.OpenRead`（零拷贝无 materialize），真时单流 Move 复用 4K 头+同流 IReaderAt/Seek 补读剩余（免二次 OpenRead），大文件 2 字节栈缓冲零堆分配预判，泛型路径输入/输出双 32MiB 限幅防 bomb（VFS_DECOMPRESS_MAX_BYTES 单源），ETag禁用，Op/Path完整（'wrap'/'stat'/'open'，`try-finally` Close不丢，`inline` 热路径） |
| 装饰 | `CreateDecompressingVfs(AInner: IVfs; AAlgo: TDecompressAlgo=daAuto): IVfs` | 解压薄门面（L3 单缝寄居正名，Registry 白名单过渡，L7 聚合拆分，经 transform 单源决策器）：`daGzip` 按gzip魔数（bytes.ops inline 零拷贝单源）按需解压，`VFS_DECOMPRESS_MAX_BYTES` 字面量 32MiB 数值对齐 compress.base GZIP_MAX canonical 单源、漂移由 source-contract 锁定，防 bomb 由 transform 统一承载（输入/输出双阈值），`daAuto` 单流 4K 头预判 HeaderPred 直接复用 transform.TRANSFORM_HEADER_PEEK 无本地别名、免 Stat 全量读，ETag禁用 |
| 遍历 | `VfsWalk(AFs: IVfs; const ARoot: string; ACallback): Boolean` | 字典序全树遍历（Go WalkDir 对等物）；回调可置 AStop 中止 |
| 便利 | `VfsStat(AFs; APath): TStatInfo` / `VfsList(AFs; ADir): TEntryArray` | 门面包函数，与 Go 包级辅助同构 |
| 便利 | `VfsReadAllBytes(AFs; APath): TBytes` / `VfsReadAllText(...): string` | 门面函数，非接口方法 |
| ETag | `IVfsETag.TryGetETag` + `VfsETagStrong/VfsETagFNV` + `VFS_DECOMPRESS_MAX_BYTES` | 门面重导出：embedded 预计算 ETag 零分配命中，压缩装饰器 ETag 禁用 |

```pascal
IVfs = interface
  function Exists(const APath: string): Boolean;
  function Stat(const APath: string): TStatInfo;
  function List(const ADirPath: string): TEntryArray;
  function OpenRead(const APath: string): IStream;   // io.intf 词汇
end;
```

---

## 2. 不变量

- **[INV-V1]** v1 只读：任何 IVfs 实现不得提供写/删/改名能力；写入需求归 core.fs
- **[INV-V2]** 发布后的 IVfs 为不可变快照：并发只读 ✅ 安全，无需外部锁；
  构造期可变性收敛在 memtree Builder
- **[INV-V3]** 路径一律先过 ValidPath（Go 语义，`.` 表根）；非法路径统一
  `EVfsInvalidPath`，不做猜测性修正
- **[INV-V4]** 错误携带上下文：所有异常 `Op ∈ {'stat','open','list','read'}` 且
  `Path` = 出错虚拟路径（Go PathError 对等物）
- **[INV-V5]** 错误分类固定：不存在 → `EVfsNotFound`；List 非目录 →
  `EVfsNotADirectory`；目录上 OpenRead / 文件上 List → 对应子类；Exists 任何失败
  返回 False 不抛
- **[INV-V6]** embedded 后端零拷贝：OpenRead 的读取地址必须落在 blob 区间内
  （conformance P8 断言）；接口持后备引用保活，const 段场景由调用方保证生命期
- **[INV-V7]** 三后端语义一致：同一用例集在 memtree/embedded/os 上必须同结果。
  **验证**：`test_vfs_conformance` 属性电池 P1–P8 以同一夹具树跑满
  `{三后端} × {整树, Sub}` 矩阵；`test_vfs_facade` 的树签名用例再以纯门面 API 复证
  （开发态/发布态切换承诺）
- **[INV-V8]** List 结果按路径字节序升序；目录条目由文件路径推导，不要求存储存在
- **[INV-V9]** Sub 视图不改变底层生命期与并发性质；`ASubRoot` 必须是已存在的目录路径
- **[INV-V10]** os 后端大小写敏感性跟随平台并在实例上可查询；embedded/memtree 恒敏感。
  **验证**：conformance 各后端电池末尾的 `CaseSensitive` 断言（posix 下三后端均为 True）
- **[INV-V11]** VfsWalk 确定性：字典序访问、每路径恰好一次、由不可变快照保证无环；
  回调置 AStop 后立即停止且不再进入子树。**验证**：conformance 全序列精确比对 +
  facade gate 早停用例（恰好访问 2 个路径）
- **[INV-V12]** OpenRead 返回的流 SHOULD 同时实现 `io.intf.IReaderAt`（三后端均可
  提供 positioned 读）；consumer 经 Supports 探测，缺省退化 Seek+Read。
  **验证**：conformance P4 内嵌断言——三后端流 QueryInterface(IReaderAt) 成功且
  positioned 读逐字节正确

---

## 3. 错误处理

| 场景 | 异常 | Op |
|------|------|----|
| Stat/OpenRead 未命中 | EVfsNotFound | stat/open |
| List 目标非目录 | EVfsNotADirectory | list |
| 目录上 OpenRead | EVfsIsADirectory | open |
| 文件上 List | EVfsNotADirectory | list |
| 路径非法 | EVfsInvalidPath | 随操作 |
| 已 Close 后使用 | EVfsClosed | 随操作 |
| os 后端底层 IO 错误 | 映射至 fs 错误分类并包成 EVfsError（保 Op/Path） | 随操作 |

全部继承 `EVfsError` ← `nextpas.core.exception.Exception`，不触碰 SysUtils。

---

## 4. 线程安全

- IVfs 实例：并发只读 ✅（INV-V2）
- IStream 实例：❌ 非线程安全，单流单线程；多线程各开各的流
- memtree Builder：❌ 构造期单线程；Freeze 后产物 ✅
- embedded 切片池：SpinLock 16槽并发归还安全；TEmbeddedSliceStream.Destroy 先强 LKeep 保活 Owner 再推导弱 FOwner，TryPushPool 遇 FPoolLock=nil（Owner 析构中）安全回退 Free，无 use-after-free（契约显式）

---

## 5. 内存管理

- List/TEntryArray 每次调用分配返回，调用方持有；List 扇出限界倍增（初值16 Cap≤Hi-Lo）消除大目录 Hi-Lo 预分配与 O(k log k) Sort/Dedup 重分配
- OpenRead 的 IStream 引用计数持后备存储（堆场景）；const 段场景见 INV-V6 生命期规则；切片池归还 LKeep强→LOwner弱时序契约，资源不丢（归还失败即 Free）
- VfsReadAllBytes/Text 单次分配结果
- embedded Owned：最后一个派生接口释放时释放 blob（引用计数托底）；Borrowed 常驻调用方（const 段防 Free）

---

## 6. 性能契约（S3基准 + S6装饰器校准，HeaderPred/零拷贝实测）

| 操作 | 目标 | 证据 |
|------|------|------|
| Exists/Stat（embedded） | 二分查找，无分配 | LowerBoundPath+CompareBytesOrdered直通base.utils，FPaths/Entries平行缓存零DecodeWire，HasSubtreePath SpanStartsWith bytes.ops单源 inline 零拷贝 |
| OpenRead（embedded） | O(1) 切片构造，零内容复制 | TEmbeddedSlice直接落在blob区间，P8地址断言；16槽SpinLock池化10k 163ms 4.9×预算，heaptrc0，FKeep强保活+FOwner弱归还契约显式（LKeep先于LOwner，FPoolLock=nil 安全回退Free） |
| List（embedded） | 有序区间扫描扇出限界，一次扇出数组 | LowerBound+SpanStartsWith单源base模板扇出限界倍增（初值16 Cap≤Hi-Lo，消除 Hi-Lo 全量预分配与 O(k log k) Sort/Dedup），SpanEqual去重零拷贝 inline 热路径；memtree 委托 base.VfsDeriveChildNames 同构单源，base扇出限界同源 |
| OpenRead（os） | 经 fs.Open，句柄级开销 | fs seam唯一 |
| Sub 视图转发 | O(1) 包装，无树复制 | 包装器无树复制 |
| VfsWalk 全树 | O(n) 路径构造主导；零冗余 List 调用 | WalkLevel批量List，字典序确定性 |
| Stat(large非gzip) | 轻量 2 字节栈缓冲零堆分配预判免 4K 分配+全量读 | `TTransformingVfs.TryResolveViaHeaderSingleStream` 单源决策器（大文件先栈上 2 字节轻量 peek + `HeaderShould` bytes.ops inline 非变换直接回 `FInner.Stat` 免 4K 堆分配，小文件复用 Header 零二次 IO，大文件命中同流 IReaderAt/Seek 补读免二次 OpenRead），`TAuto` 亦轻量透传；TargetL 1MiB非gzip Stat ~972ns 零解压，bench_transform `Stat/large-non-gzip/header-peek` 阈值锁定 |
| OpenRead(非gzip) | 轻量 2 字节栈缓冲零物化直透免 VfsReadAllBytes/4K | `TTransformingVfs.OpenRead` 单源决策器 HeaderPred 假时栈上 2 字节 peek 后零物化直透 `FInner.OpenRead`（零拷贝无 `VfsReadAllBytes` materialize，栈缓冲零堆分配 2 字节 peek ~数百 ns，免 4K 分配），命中时 4K 单流复用；bench_transform `Open/large-non-gzip/passthrough` 阈值锁定 |
| OpenRead/Stat(gzip) | 按需GzipTransform，32MiB防bomb统一（transform 承载，泛型/压缩一致），大小文件 Stat/OpenRead 一致 | `GzipDecompressWithMaxOutputSize(VFS_DECOMPRESS_MAX_BYTES 字面量 32MiB 数值对齐 compress.base GZIP_MAX canonical 单源、漂移由 source-contract 锁定 + bytes.ops 单源魔数 inline 零拷贝)` + 泛型 Transform 输入/输出双 32MiB 限幅，`ContentHash=0/ETag` 禁用，HeaderPred真时小文件复用 Header（≤4K）& 大文件栈上 2 字节轻量预判后单流 Move 4K 头+同流补读避免二次全量读（HeaderPred 直接复用 transform.TRANSFORM_HEADER_PEEK 无本地别名），Stat 与 OpenRead 大文件解压后尺寸一致 |

---

## 7. 测试覆盖（P2/S6实测校准，2026-08-31：13门闭环 respack5 + vfs8）

| 测试目录 | 用例数 | 说明 |
|----------|--------|------|
| test_vfs_memtree | 16 | Builder/Freeze/错误语义/`.` 根/IReaderAt（Int64防回绕/防御拷贝/两段式/零双驻留，S6后新增2例） |
| test_vfs_embedded | 8 | 切片/AOwnsBlob 双态生命期/损坏透传/空包/边界窗口（池化16槽SpinLock零分配，S6后新增2例） |
| test_vfs_conformance | 7 | 属性电池 P1–P8+INV-V12 × {3 后端} × {整树, Sub}（一个用例跑满矩阵） |
| test_vfs_facade | 6 | 便利函数 + 开发态/发布态工厂切换 + Walk 早停 + Decompress/ETag 重导出签名 |
| test_vfs_mount | 10 | 挂载+叠加双视图：basic/longest/duplicate/etag/case/notfound/nested + overlay priority/list dedup/etag priority（P2+游戏热更完整性，最长匹配+优先级叠加双模型） |
| test_vfs_transform | 6 | 通用变换装饰器：单源决策器 TryResolveViaHeaderSingleStream（单流 4K + 大文件栈上 2 字节轻量预判零堆分配免 4K + Move 复用 inline 零拷贝，Header假直透/小复用/大同流补读三态，Stat/OpenRead 大文件解压一致性，泛型路径输入/输出双 32MiB 防 bomb），upper/谓词/错误' transform failed' Op/Path/ETag禁用/CaseSensitive（L3 单缝模板，`inline`+`try-finally`不丢） |
| test_vfs_compressed | 7 | 解压薄门面（L3 单缝正名，L7 到期拆分，接口层字面量对齐无 L2→L2）：daAuto/gzip Stat Size/ContentHash 校正/ETag禁用/daGzip 强制失败/空包/大文件栈上 2 字节轻量预判零堆分配+单流 4K 头预判 HeaderPred（字面量 32MiB 数值对齐 compress.base GZIP_MAX canonical 单源 + bytes.ops 魔数 inline 零拷贝单源，直接复用 transform.TRANSFORM_HEADER_PEEK 无本地别名，复用 transform 单源决策器，防 bomb 由 transform 统一承载，Stat/OpenRead 大文件一致） |
| test_vfs_source_contract | 5 | uses 白名单断言（复用 `core/tests/fpc_rtl_uses_scan.inc`，含 transform/compressed 单缝寄居白名单：L3→L2 单缝过渡，L7 到期拆分为 decorator，文档正名+拆分路线） |

合计 8 门（vfs侧含mount10）；respack侧5门（writer/reader/roundtrip/dirsource/embed），合计 **13 门**闭环（respack5+vfs8；另bench_transform 1基准阈值，source-contract并入vfs8）。heaptrc 0 leak为所有gate门禁。

- 原设计的独立 `test_vfs_os` 门折叠进 conformance：os 行为断言在电池里以真实目录
  夹具全覆盖，独立门只会复制夹具（README 测试计划节有记录）
- 全部 gate heaptrc 0 leak 为门禁

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-08-25 | 0.9 | 设计阶段契约草案（随 S0 定稿） | AI |
| 2026-08-25 | 1.0 | S3 落地：三后端+Sub+门面实现；INV-V7/V10/V11/V12 补验证方式；测试表按实测校准；os 门折叠进 conformance 的偏离记录 | AI |
| 2026-08-28 | 1.1 | facade 校准：补 `CreateDecompressingVfs(AAlgo)` 重载与 `IVfsETag/VFS_DECOMPRESS_MAX_BYTES` 重导出；门数 12 闭环 | AI |
| 2026-08-30 | 1.2 | S6装饰器落地：vfs.transform通用模板 + vfs.compressed薄门面（GZIP_MAX单源/4K HeaderPred/单次读取复用/池化复用度/OpPath高级感）；12门补齐（respack5+vfs5+2）+ bench_transform阈值；性能契约添HeaderPred/零二次IO证据 | AI |
| 2026-08-30 | 1.3 | P2挂载复合落地：vfs.mount 前缀最长匹配复合+ETag/ServeMeta透传+CaseSensitive一致性，mount门禁6例，13门闭环 | AI |
| 2026-08-31 | 1.4 | P2叠加落地：vfs.overlay 同根优先级叠加 patch>dlc>base 热更模型，overlay 3例（priority/list dedup/etag），13门闭环 | AI |
| 2026-09-02 | 1.5 | 匠心修复：transform 单流复用+单源决策器（Stat/OpenRead 共用 TryResolveViaHeaderSingleStream，单流 Move 零拷贝 50 行去重，小/大/回退三态 inline+try-finally）+ L3 单缝寄居正名（L3→L2 单缝白名单过渡，长期待 L3 族聚合拆分）+ bytes.ops 单源魔数 + 性能/稳定性证据 | AI |
| 2026-09-02 | 1.6 | 匠心修复：transform 大文件 2 字节轻量预判免 4K（Stat/OpenRead 大文件解压一致性 via 单源，OpenRead 大文件非 gzip 免 4K 分配与单流读）+ L7 单缝正名（L7 到期拆分为 nextpas.core.vfs.decorator 后移除白名单）+ bytes.ops 单源魔数 inline 零拷贝 | AI |
| 2026-09-02 | 1.7 | 匠心修复：transform 栈上 2 字节零堆分配（热点非 gzip 路径栈缓冲免 SetLength(AHeader,2) 堆分配）+ 泛型路径 32MiB 防 bomb 统一（VFS_DECOMPRESS_MAX_BYTES→GZIP_MAX 单源，输入/输出双阈值防 OOM，压缩/非压缩一致）+ L7 单缝寄居文档正名固化（现阶段以单缝+文档正名守层级高级感，L7 到期拆分为 decorator 固化 L0-L3） | AI |
