# nextpas.core.vfs 代码契约

**模块路径**：`core/src/nextpas.core.vfs*.pas`（16 源文件：base/intf/errors/memtree/embedded/os/backends/sub/mount/overlay/cache/util + decorator 聚合 + 门面）
**层级**：L2（依赖 L0-L1；L2 双缝过渡白名单——`os→fs/path` 与 `embedded→respack.reader` 双缝并存，source-contract gated，L7 聚合为 `nextpas.core.vfs.backends` 后端独立族后收敛至单缝；`mount/overlay` 纯复合；L3 装饰器经 `vfs.decorator` 单点聚合）
**Owner**：AI（respack/vfs lane）
**最后更新**：2026-09-02
**版本**：1.14（门面经 backends+decorator 双族单缝收敛，扇出 12→10，L7 单缝已落地）

---

## 1. 接口契约

### 1.1 模块结构

```
vfs.base      ← TEntryInfo/TStatInfo、ValidPath、常量（VFS_DECOMPRESS_MAX_BYTES 单源 alias compress.base）
vfs.intf      ← IVfs/IVfsETag/IVfsServeMeta
vfs.errors    ← EVfsError(Op/Path) 及子类
vfs.memtree   ← 内存不可变树 + Builder
vfs.embedded  ← respack blob → IVfs（零拷贝切片，池化）
vfs.os        ← nextpas.core.fs → IVfs 适配（L2→L2 单缝保留）
vfs.backends  ← 三后端聚合：memtree/embedded/os 单缝收口（L2 双缝过渡白名单 → L7 单缝，source-contract gated）
vfs.sub       ← 重定根视图包装
vfs.mount     ← 挂载复合：多 IVfs 前缀最长匹配
vfs.overlay   ← 叠加视图：多 IVfs 同根优先级叠加
vfs.cache     ← 热点 List 缓存单源 helper（SwissTable 16 槽 + RWLock）
vfs.util      ← 便利函数（VfsStat/List/ReadAll/Walk）
vfs.transform ← L3 通用字节变换装饰器（经 decorator 聚合）
vfs.compressed← L3 解压薄门面（经 transform 承载 gzip）
vfs.decorator ← L3 装饰器族聚合：transform+compressed 单点收口
vfs.pas       ← 门面 re-export + 便利函数（经 backends+decorator 双族聚合，扇出 10）
```

*注：性能实现细节（bytes.ops 单源 inline 零拷贝、SpinLock 池化、4K HeaderPred、try-finally）归实现文档与源码注释，契约仅保留接口与不变量。*

### 1.2 核心签名

| 领域 | 签名 | 说明 |
|------|------|------|
| 装配 | `CreateMemTreeVfs(ATree): IVfs` | Builder Freeze 产物 |
| 装配 | `CreateEmbeddedVfsOwned/Borrowed(AData,ASize): IVfs` | 零拷贝后端；Owned/Borrowed 所有权区分 |
| 装配 | `CreateOsVfs(ARoot): IVfs` | 真实目录后端（L2→L2 单缝） |
| 视图 | `CreateSubVfs(AFs,ASubRoot): IVfs` | 重定根 |
| 视图 | `CreateMountedVfs(AMounts): IVfs` | 挂载复合，最长匹配 |
| 视图 | `CreateOverlayVfs(AList): IVfs` | 叠加视图，优先级叠加 |
| 装饰 | `CreateTransformingVfs(AInner,ATransform,AShould,AHeaderPred): IVfs` | L3 通用变换装饰器 |
| 装饰 | `CreateDecompressingVfs(AInner,AAlgo): IVfs` | 解压薄门面（daGzip/daAuto） |
| 遍历 | `VfsWalk(AFs,ARoot,ACallback)` | 字典序全树遍历 |
| 便利 | `VfsStat/VfsList/VfsReadAllBytes/VfsReadAllText` | 门面包函数 |

```pascal
IVfs = interface
  function Exists(const APath: string): Boolean;
  function Stat(const APath: string): TStatInfo;
  function List(const ADirPath: string): TEntryArray;
  function OpenRead(const APath: string): IStream;
end;
```

---

## 2. 不变量

- **[INV-V1]** v1 只读：IVfs 不提供写/删/改名
- **[INV-V2]** 发布后 IVfs 为不可变快照：并发只读安全
- **[INV-V3]** 路径先过 ValidPath（Go 语义，`.` 表根）；非法统一 `EVfsInvalidPath`
- **[INV-V4]** 错误携带 Op/Path 上下文
- **[INV-V5]** 错误分类：不存在→`EVfsNotFound`；List 非目录→`EVfsNotADirectory`；目录 OpenRead→`EVfsIsADirectory`；Exists 失败返回 False
- **[INV-V6]** embedded 零拷贝：OpenRead 地址落在 blob 区间内
- **[INV-V7]** 三后端语义一致：同一用例集在 memtree/embedded/os 同结果（`test_vfs_conformance` P1–P8 矩阵）
- **[INV-V8]** List 按路径字节序升序
- **[INV-V9]** Sub 不改变底层生命期；`ASubRoot` 为已存在目录
- **[INV-V10]** 大小写敏感性可查询；embedded/memtree 恒敏感，os 跟随平台
- **[INV-V11]** VfsWalk 字典序、每路径一次、回调可中止
- **[INV-V12]** OpenRead 返回流 SHOULD 实现 `IReaderAt`

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
| os 底层 IO 错误 | 映射为 EVfsError（保 Op/Path） | 随操作 |

全部继承 `EVfsError ← nextpas.core.exception.Exception`。

---

## 4. 线程安全

- IVfs 实例：并发只读安全
- IStream 实例：非线程安全，单流单线程
- memtree Builder：构造期单线程，Freeze 后只读
- embedded 切片池：SpinLock 64 槽并发安全，归还失败回退 Free，try-finally 不丢

---

## 5. 内存管理

- List 每次调用分配返回，调用方持有
- OpenRead 的 IStream 引用计数保活后备存储
- embedded Owned：末接口释放时释放 blob；Borrowed 归调用方保活

---

## 6. 性能契约（S3 基准 + S6 校准）

| 操作 | 目标 | 证据 |
|------|------|------|
| Exists/Stat（embedded） | 二分查找，无分配 | LowerBound + bytes.ops inline 零拷贝 |
| OpenRead（embedded） | O(1) 切片，零复制 | TEmbeddedSlice 落 blob 区间，池化复用 |
| List（embedded/memtree） | 有序区间扫描 O(k) | VfsEnumerateChildSpans 单源，SwissTable 扇出限界 |
| OpenRead（memtree） | O(1) 防御拷贝 + IReaderAt | Move 零拷贝 |
| OpenRead（os） | 经 fs.Open，句柄开销 | fs 单缝 |
| Sub/Walk | O(1) 包装 / O(n) 遍历 | 无树复制；Walk 批量 List |
| Stat/OpenRead（大文件非 gzip） | 2 字节栈探针免 4K 分配 | HeaderPred 单源决策器，假时直透 |
| Stat/OpenRead（gzip） | 按需解压，32MiB 限幅 | VFS_DECOMPRESS_MAX_BYTES 单源 32MiB，bytes.ops 魔数 |

*实现证据：bytes.ops 单源 inline 零拷贝；热点 inline；try-finally 资源不丢；bench_hotspots/bench_transform 阈值锁定。*

---

## 7. 测试覆盖

| 测试目录 | 用例数 | 说明 |
|----------|--------|------|
| test_vfs_memtree | 16 | Builder/Freeze/错误/`.` 根/IReaderAt |
| test_vfs_embedded | 8 | 切片/双态生命期 |
| test_vfs_conformance | 7 | P1–P8 × {3 后端} × {整树,Sub} |
| test_vfs_facade | 6 | 便利函数 + 切换 |
| test_vfs_mount | 10 | 挂载+叠加双视图 |
| test_vfs_transform | 6 | 通用变换装饰器 |
| test_vfs_compressed | 7 | 解压薄门面 |
| test_vfs_source_contract | 5 | uses 白名单（L2 双缝过渡白名单，L7 聚合为 `vfs.backends` 后收敛单缝 source-contract gated） |

合计 8 门；heaptrc 0 为门禁。`vfs.backends` 已落地为三后端单缝收口；source-contract 固化 `os→fs/path` 与 `embedded→respack.reader` 双缝仅经 backends 族透出，门面经 backends 单缝收敛。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-08-25 | 1.0 | S3 落地：三后端+Sub+门面；INV 补齐 | AI |
| 2026-08-30 | 1.2 | S6 装饰器落地：transform+compressed | AI |
| 2026-09-02 | 1.11 | decorator 族单点聚合收敛门面扇出 | AI |
| 2026-09-02 | 1.12 | 契约精简：规格与实现分离，L2→L2 双缝白名单过渡收敛至 L7 后端独立族单缝理想，移除行话堆砌 | AI |
| 2026-09-02 | 1.13 | 后端独立族落地：`vfs.backends` 聚合三后端单缝收口，L2 双缝过渡白名单 L7 收敛单缝 source-contract gated | AI |
| 2026-09-02 | 1.14 | 门面双族单缝收敛落地：`vfs.pas` 经 backends+decorator 双聚合，扇出 12→10，src 16 闭环补齐 | AI |
