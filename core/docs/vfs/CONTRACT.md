# nextpas.core.vfs 代码契约

**模块路径**：`core/src/nextpas.core.vfs*.pas`（8 个源文件，规划）
**层级**：L2（依赖 L0-L1；`os` 单元例外依赖 fs/path；`embedded` 另依赖 respack.reader）
**Owner**：AI（respack/vfs lane）
**最后更新**：2026-08-25
**版本**：0.9（设计阶段草案；S3 落地时升 1.0 并按实现校准）

---

## 1. 接口契约

### 1.1 模块结构

```
vfs.base      ← TEntryInfo/TStatInfo、ValidPath 工具、常量
vfs.intf      ← IVfs 契约
vfs.errors    ← EVfsError(Op/Path) 及子类
vfs.memtree   ← 内存不可变树 + Builder
vfs.embedded  ← respack blob → IVfs（零拷贝切片）
vfs.os        ← nextpas.core.fs → IVfs 适配
vfs.sub       ← 重定根视图包装（Go fs.Sub 对等物）
vfs.pas       ← 门面 re-export + 便利函数
```

### 1.2 核心签名（设计定稿）

| 领域 | 签名 | 说明 |
|------|------|------|
| 装配 | `CreateMemTreeVfs(ATree): IVfs` | Builder Freeze 产物 |
| 装配 | `CreateEmbeddedVfs(APack: TResPack; AOwnsBlob: Boolean): IVfs` | 零拷贝后端 |
| 装配 | `CreateOsVfs(const ARoot: string): IVfs` | 真实目录后端 |
| 视图 | `CreateSubVfs(AFs: IVfs; const ASubRoot: string): IVfs` | 重定根，不改底层实例 |
| 便利 | `VfsReadAllBytes(AFs; APath): TBytes` / `VfsReadAllText(...): string` | 门面函数，非接口方法 |

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
- **[INV-V7]** 三后端语义一致：同一用例集在 memtree/embedded/os 上必须同结果
  （test_vfs_conformance 强制）
- **[INV-V8]** List 结果按路径字节序升序；目录条目由文件路径推导，不要求存储存在
- **[INV-V9]** Sub 视图不改变底层生命期与并发性质；`ASubRoot` 必须是已存在的目录路径
- **[INV-V10]** os 后端大小写敏感性跟随平台并在实例上可查询；embedded/memtree 恒敏感

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

## 6. 性能契约（设计目标，S3 基准校准）

| 操作 | 目标 |
|------|------|
| Exists/Stat（embedded） | 二分查找，无分配 |
| OpenRead（embedded） | O(1) 切片构造，零内容复制 |
| List（embedded） | 有序区间扫描，一次数组分配 |
| OpenRead（os） | 经 fs.Open，句柄级开销 |
| Sub 视图转发 | O(1) 包装，无树复制 |

---

## 7. 测试覆盖（设计目标值，落地时校准）

| 测试目录 | 目标用例数 | 说明 |
|----------|-----------|------|
| test_vfs_memtree | ≥ 10 | Builder/Freeze/错误语义/`.` 根 |
| test_vfs_embedded | ≥ 10 | 切片/AOwnsBlob/生命期/地址断言 |
| test_vfs_os | ≥ 8 | 边界转换/平台大小写/错误映射 |
| test_vfs_conformance | ≥ 40 | fstest 属性电池 P1–P8 × {3 后端} × {整树, Sub} |
| test_vfs_facade | ≥ 6 | 便利函数 + 开发态/发布态工厂切换 |
| test_vfs_source_contracts | — | uses 白名单断言（复用 `core/tests/fpc_rtl_uses_scan.inc`） |

heaptrc 0 leak 为所有 gate 门禁。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-08-25 | 0.9 | 设计阶段契约草案（随 S0 定稿） | AI |
