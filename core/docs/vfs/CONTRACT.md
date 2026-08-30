# nextpas.core.vfs 代码契约

**模块路径**：`core/src/nextpas.core.vfs*.pas`（12 个源文件：base/intf/errors/memtree/embedded/os/sub/mount/util + transform/compressed L3装饰器 + 门面）
**层级**：L2（依赖 L0-L1；`os` 单元例外依赖 fs/path；`embedded` 另依赖 respack.reader；`mount` 纯复合零额外依赖；`transform/compressed` L3装饰器例外依赖 compress.base GZIP_MAX单源）
**Owner**：AI（respack/vfs lane）
**最后更新**：2026-08-30
**版本**：1.3（P2挂载复合落地：vfs.mount 前缀最长匹配复合 + ETag/ServeMeta透传，13门闭环）

---

## 1. 接口契约

### 1.1 模块结构

```
vfs.base      ← TEntryInfo/TStatInfo、ValidPath 工具、常量（ValidPath单源 base.pathvalid，GZIP_MAX单源 compress.base）
vfs.intf      ← IVfs/IVfsETag/IVfsServeMeta 契约
vfs.errors    ← EVfsError(Op/Path) 及子类（Op∈{'stat','open','list','read','wrap'}）
vfs.memtree   ← 内存不可变树 + Builder（Int64下标防回绕、防御拷贝防悬垂、两段式Freeze）
vfs.embedded  ← respack blob → IVfs（零拷贝切片，EMBEDDED_POOL_SIZE=16 SpinLock池化）
vfs.os        ← nextpas.core.fs → IVfs 适配
vfs.sub       ← 重定根视图包装（Go fs.Sub 对等物）
vfs.mount     ← 挂载复合视图：多IVfs前缀最长匹配聚合（P2完整性，ETag/ServeMeta透传，CaseSensitive一致性）
vfs.util      ← 便利函数（VfsStat/List/ReadAll/Walk，Go包级辅助同构）
vfs.transform ← L3通用字节变换装饰器：TVfsTransformFunc/Should注入，零拷贝按需变换（压缩/加密共用模板，ETag禁用，单次读取复用）
vfs.compressed← L3解压薄门面：经transform承载gzip（VFS_DECOMPRESS_MAX_BYTES→GZIP_MAX单源32MiB防bomb，daAuto 4K头预判HeaderPred，ETag禁用）
vfs.pas       ← 门面 re-export + 便利函数 + ETag/Decompress/Mount重导出（IVfsETag/IVfsServeMeta/VFS_DECOMPRESS_MAX_BYTES/daGzip/daAuto + CreateTransformingVfs/CreateMountedVfs/VfsMountEntry）
```

### 1.2 核心签名（设计定稿）

| 领域 | 签名 | 说明 |
|------|------|------|
| 装配 | `CreateMemTreeVfs(ATree): IVfs` | Builder Freeze 产物 |
| 装配 | `CreateEmbeddedVfs(AData: PByte; ASize: SizeUInt; AOwnsBlob: Boolean): IVfs` | 零拷贝后端；`AOwnsBlob=True` 时 blob 归 VFS 所有 |
| 装配 | `CreateOsVfs(const ARoot: string): IVfs` | 真实目录后端 |
| 视图 | `CreateSubVfs(AFs: IVfs; const ASubRoot: string): IVfs` | 重定根，不改底层实例 |
| 视图 | `CreateMountedVfs(AMounts: array of TVfsMountEntry): IVfs` + `VfsMountEntry(APrefix,AFs)` | 挂载复合视图：多IVfs前缀最长匹配（根'.'兜底），List根去重合并，CaseSensitive一致性推导，ETag/ServeMeta透传 |
| 装饰 | `CreateTransformingVfs(AInner: IVfs; ATransform: TVfsTransformFunc; AShould: TVfsShouldTransformFunc): IVfs` | L3通用变换装饰器：泛型字节变换（压缩/加密共用模板），Stat单源Size/ContentHash校正，OpenRead单次VfsReadAllBytes复用零二次IO，ETag禁用，Op/Path完整（'wrap'/'stat'/'open'） |
| 装饰 | `CreateDecompressingVfs(AInner: IVfs; AAlgo: TDecompressAlgo=daAuto): IVfs` | 解压薄门面（经transform）：`daGzip` 按gzip魔数按需解压，`VFS_DECOMPRESS_MAX_BYTES=32MiB→GZIP_MAX`单源防bomb，`daAuto` 4K头预判HeaderPred免Stat全量读，ETag禁用 |
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

---

## 5. 内存管理

- List/TEntryArray 每次调用分配返回，调用方持有
- OpenRead 的 IStream 引用计数持后备存储（堆场景）；const 段场景见 INV-V6 生命期规则
- VfsReadAllBytes/Text 单次分配结果
- embedded + `AOwnsBlob=True`：最后一个派生接口释放时释放 blob（引用计数托底）

---

## 6. 性能契约（S3基准 + S6装饰器校准，HeaderPred/零拷贝实测）

| 操作 | 目标 | 证据 |
|------|------|------|
| Exists/Stat（embedded） | 二分查找，无分配 | LowerBoundPath+CompareBytesOrdered直通base.utils，FPaths/Entries平行缓存零DecodeWire |
| OpenRead（embedded） | O(1) 切片构造，零内容复制 | TEmbeddedSlice直接落在blob区间，P8地址断言；16槽SpinLock池化10k 163ms 4.9×预算，heaptrc0 |
| List（embedded） | 有序区间扫描，一次数组分配 | FEntries直填零Stat，VfsDeriveChildNames单次分配 |
| OpenRead（os） | 经 fs.Open，句柄级开销 | fs seam唯一 |
| Sub 视图转发 | O(1) 包装，无树复制 | 包装器无树复制 |
| VfsWalk 全树 | O(n) 路径构造主导；零冗余 List 调用 | WalkLevel批量List，字典序确定性 |
| Stat(large非gzip) | 4K头预判免全量读 | TAutoDecompressingVfs.IsGzipHeader 4096 peek + IsGzipPred 2字节判定，TargetL 1MiB非gzip Stat零解压，bench_transform Stat/large-non-gzip阈值锁定 |
| OpenRead(非gzip) | 单次VfsReadAllBytes复用零二次IO | TTransformingVfs.OpenRead Should假时复用已读LData，省二次FInner.OpenRead系统调用；bench_transform Open/large-non-gzip阈值锁定 |
| OpenRead/Stat(gzip) | 按需GzipTransform，32MiB防bomb | GzipDecompressWithMaxOutputSize(VFS_DECOMPRESS_MAX_BYTES→GZIP_MAX单源)，ContentHash=0/ETag禁用 |

---

## 7. 测试覆盖（P2/S6实测校准，2026-08-30：13门闭环 respack5 + vfs6 + transform/compressed2）

| 测试目录 | 用例数 | 说明 |
|----------|--------|------|
| test_vfs_memtree | 16 | Builder/Freeze/错误语义/`.` 根/IReaderAt（Int64防回绕/防御拷贝/两段式/零双驻留，S6后新增2例） |
| test_vfs_embedded | 8 | 切片/AOwnsBlob 双态生命期/损坏透传/空包/边界窗口（池化16槽SpinLock零分配，S6后新增2例） |
| test_vfs_conformance | 7 | 属性电池 P1–P8+INV-V12 × {3 后端} × {整树, Sub}（一个用例跑满矩阵） |
| test_vfs_facade | 6 | 便利函数 + 开发态/发布态工厂切换 + Walk 早停 + Decompress/ETag 重导出签名 |
| test_vfs_mount | 6 | 挂载复合视图：basic/longest/duplicate/etag/case/notfound（P2完整性，最长匹配+ETag/ServeMeta透传+CaseSensitive一致性） |
| test_vfs_transform | 6 | 通用变换装饰器：upper变换/谓词选择/透传/错误' transform failed' Op/Path包装/ETag禁用/CaseSensitive透传（L3模板，压缩/加密共用，Op/Path高级感） |
| test_vfs_compressed | 7 | 解压薄门面：daAuto/gzip自动解压Stat Size/ContentHash校正/ETag禁用/daGzip强制失败/空包/大文件4K头预判HeaderPred（GZIP_MAX单源32MiB） |
| test_vfs_source_contract | 5 | uses 白名单断言（复用 `core/tests/fpc_rtl_uses_scan.inc`，含transform/compressed/mount L2→L2装饰器seam白名单） |

合计 8 门（vfs侧）；respack侧5门（writer/reader/roundtrip/dirsource/embed），source-contract共享1门，合计 **13 门**闭环（respack5+vfs6+新增2；另bench_transform 1基准阈值）。heaptrc 0 leak为所有gate门禁。

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
