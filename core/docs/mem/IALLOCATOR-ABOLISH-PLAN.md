# 废除 IAllocator 迁移计划

> **状态**: 已审查 (Codex R1)
> **日期**: 2026-06-29
> **目标**: 废除 `IAllocator` 接口，以 `TMemAllocator` 抽象基类替代，同时将 `DefaultAllocator` 接入 `TGrowingAllocator` 高性能路径。
> **审查**: Codex R1 发现 8 个关键问题，已全部修正。

---

## 一、问题陈述

### 1.1 核心断路

```
DefaultAllocator()
  → TRtlAllocator  (FPC System.GetMem 包装)
    → 绕过了 TLS cache / 62 size class / scavenger / shuffle
```

所有用 `DefaultAllocator` 的模块（40 个文件）得到的只是 FPC `System.GetMem` 的薄包装。`TGrowingAllocator` 的全部高性能实现被架空。

### 1.2 接口签名不兼容

| 方法 | IAllocator 签名 | TGrowingAllocator 签名 |
|------|----------------|----------------------|
| `FreeMem` | `(ADst: Pointer)` | `(APtr: Pointer; ASize: SizeUInt)` |
| `ReallocMem` | `(ADst: Pointer; ASize: SizeUInt)` | `(APtr: Pointer; AOldSize, ANewSize: SizeUInt)` |

`TGrowingAllocator` 需要 caller 传 size 来快速定位 size class——这是 cache-friendly 的正确设计（Go mcache/mimalloc 也这样做）。接口无法表达这个约束。

### 1.3 为什么不能改为 FreeMem(APtr)

| 方案 | 代价 | 判定 |
|------|------|------|
| Block header 存 size | 每分配 +8 字节，cache 污染 | ❌ 不可接受 |
| Global hash table | free 路径多一次 hash lookup | ❌ 不可接受 |
| mmap OS-level 查询 | 不跨平台 | ❌ 不可行 |
| **保留 ASize 参数** | **零开销，caller 已知 size** | **✅ 唯一正确方案** |

---

## 二、方案设计

### 2.1 核心决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 替代物 | **抽象基类 `TMemAllocator`** | 接口签名无法演进；抽象类可混合虚方法和具体方法 |
| FreeMem 签名 | **保留 2 参数** `FreeMem(APtr, ASize)` | 避免 block header 开销，保持 cache-friendly |
| ReallocMem 签名 | **3 参数** `ReallocMem(APtr, AOldSize, ANewSize)` | 同上 |
| DefaultAllocator | **切到 TGrowingAllocator** | 最大收益：40 个文件自动走高性能路径 |
| 过渡策略 | **Phase 0 提供 deprecated 1-参数兼容方法** | 渐进迁移，每个 Phase 独立编译 |

### 2.2 TMemAllocator 定义

```pascal
// nextpas.core.mem.allocator.base.pas（重写）
type
  TMemAllocator = class abstract
  public
    // === 核心分配（abstract，子类必须实现） ===
    function GetMem(ASize: SizeUInt): Pointer; virtual; abstract;
    function ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer; virtual; abstract;
    procedure FreeMem(APtr: Pointer; ASize: SizeUInt); virtual; abstract;

    // === 派生操作（virtual，基类提供默认实现） ===
    function AllocMem(ASize: SizeUInt): Pointer; virtual;
    function MemSize(APtr: Pointer): SizeUInt; virtual;

    // === Batch API（virtual，基类 fallback 为循环调用 GetMem/FreeMem） ===
    function BatchGetMem(ASize: SizeUInt; ACount: Word; ABlocks: PPointer): Word; virtual;
    procedure BatchFreeMem(ASize: SizeUInt; ACount: Word; ABlocks: PPointer); virtual;

    // === 对齐分配（virtual，基类默认 over-allocate 实现） ===
    //   注意：覆盖 AllocAligned 的子类必须同时覆盖 FreeAligned
    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer; virtual;
    procedure FreeAligned(APtr: Pointer); virtual;

    function Traits: TAllocatorTraits; virtual;

    // === 过渡兼容（Phase 0 引入，Phase 6 删除） ===
    //   FreeAligned 保持 1 参数是因为 over-allocate header 存储了原始指针
    //   （与 FreeMem 的 2 参数设计不一致但正确——header 本身就是隐式 "size"）
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; virtual; deprecated 'Use ReallocMem(APtr, AOldSize, ANewSize)';
    procedure FreeMem(ADst: Pointer); virtual; deprecated 'Use FreeMem(APtr, ASize)';
  end;

  // 过渡别名，Phase 6 删除
  IAllocator = TMemAllocator deprecated 'Use TMemAllocator directly';
```

**设计说明**：

| 方法 | 虚类型 | 基类默认实现 |
|------|--------|-------------|
| `GetMem` | abstract | — |
| `ReallocMem(APtr, AOldSize, ANewSize)` | abstract | — |
| `FreeMem(APtr, ASize)` | abstract | — |
| `AllocMem(ASize)` | virtual | 调用 `GetMem` + `FillChar(..., 0)` |
| `MemSize(APtr)` | virtual | 返回 0（TGrowingAllocator 无此能力） |
| `BatchGetMem` | virtual | 循环调用 `GetMem`（TGrowingAllocator override 高性能版本） |
| `BatchFreeMem` | virtual | 循环调用 `FreeMem`（同上） |
| `AllocAligned` | virtual | over-allocate + header（需同步覆盖 `FreeAligned`） |
| `FreeAligned(APtr)` | virtual | 从 header 找回原始指针后 `FreeMem` |

### 2.3 DefaultAllocator 切换

```pascal
// nextpas.core.mem.default.pas（Phase 5 切换）
function DefaultAllocator: TMemAllocator;
begin
  Result := DefaultGrowingAllocator;  // TGrowingAllocator 单例
end;
```

---

## 三、影响面

### 3.1 统计

| 指标 | 数量 |
|------|------|
| 涉及文件总数 | **71** |
| mem 模块内部 | 25 |
| collections 系列 | 30 |
| 数据格式 (xml/json/toml/yaml/ini/csv) | 10 |
| 其他 (bytes.builder / text.builder) | 2 |
| IAllocator 引用总行数 | ~553 |
| FreeMem 调用点 (外部) | 30 |
| ReallocMem 调用点 (外部) | 19 |
| DefaultAllocator 调用点 | 62 |

### 3.2 FreeMem 调用点 size 信息验证

所有调用点**已经知道 size**，迁移无信息丢失：

| 文件 | 当前调用 | 迁移后 size 来源 |
|------|---------|-----------------|
| `element_manager.pas` | `FAllocator.FreeMem(aDst)` | `aElementCount * FElementSize` |
| `arr.pas` | `Allocator.FreeMem(LBuffer)` | `LBufferCapacity * FElementSize` |
| `arr.pas` | `FreeMem(FSwapBufferCache)` | `FElementSizeCache` |
| `bytes.builder.pas` | `FAllocator.FreeMem(FPtr)` | `FCapacity` |
| `text.builder.pas` | `FAllocator.FreeMem(FBuf)` | `FCap` |
| `xml.dom.pas` | `FreeMem(Pointer(FNodes))` | `FNodeCap * SizeOf(TXmlNodeData)` |
| `xml.dom.pas` | `FreeMem(Pointer(FAttributes))` | `FAttrCap * SizeOf(TXmlAttributeData)` |
| `xml.pas` | `FreeMem(Pointer(ASlots)))` | `ASlotCap * SizeOf(TXmlTokenSlot)` |
| `json.parser.pas` | `FAllocator.FreeMem(FNodes)` | `FNodeCap * SizeOf(TJsonNode)` |
| `toml.parser.pas` | （通过 ReallocMem 替换路径） | `FCap * SizeOf(...)` |
| `yaml.parser.pas` | 同上 | 同上 |
| `ini.pas` | `FreeMem(Pointer(ASection.Entries))` | `ASection.Cap * SizeOf(...)` |
| `csv.pas` | 通过 ReallocMem 路径 | 已知 cap |
| `hashmap.swiss.pas` | `FreeMem(ABuffers.Ctrl)` | `LOldGroupCount * 16` |
| `hashmap.swiss.pas` | `FreeMem(ABuffers.Slots)` | `LOldGroupCount * 16 * SlotSize` |
| `hashmap.pas` | `FAllocator.FreeMem(FBuckets)` | `FBucketCount * SizeOf(...)` |
| `linkedhashmap.pas` | `FreeMem(aNode)` | `SizeOf(TLinkedHashNode)` |
| `node.pas` | `FreeMem(LP)` | `SizeOf(Pointer) * count` |

### 3.3 ReallocMem 调用点旧 size 验证

| 文件 | 当前调用 | 旧 size 来源 |
|------|---------|-------------|
| `element_manager.pas` | `ReallocMem(aDst, newSize)` | `aElementCount * FElementSize`（参数已在上下文中） |
| `bytes.builder.pas` | `ReallocMem(FPtr, newCap)` | `FCapacity` |
| `text.builder.pas` | `ReallocMem(FBuf, newCap)` | `FCap` |
| `xml.dom.pas` | `ReallocMem(Pointer(FNodes), newSize)` | `FNodeCap * SizeOf(TXmlNodeData)` |
| `xml.pas` | `ReallocMem(Pointer(ASlots), newSize)` | `ASlotCap * SizeOf(TXmlTokenSlot)` |
| `json.parser.pas` | `ReallocMem(FNodes, newSize)` | `FNodeCap * SizeOf(TJsonNode)` |
| `toml.parser.pas` | `ReallocMem(FOwnedBufs, newSize)` | `FOwnedBufCap * SizeOf(Pointer)` |
| `yaml.parser.pas` | `ReallocMem(Pointer(FNodes), newSize)` | `FNodeCap * SizeOf(...)` |
| `ini.pas` | `ReallocMem(Pointer(FSections), newSize)` | `FSectionCap * SizeOf(...)` |
| `csv.pas` | `ReallocMem(Pointer(ASlots), newSize)` | `ASlotCap * SizeOf(...)` |

---

## 四、迁移阶段

### Phase 修正说明 (Codex R1)

原计划 Phase 2 在调用点迁移前切换 DefaultAllocator，会导致 `DefaultAllocator.FreeMem(ptr)`（1 参数）编译失败。
**修正：Phase 2（DefaultAllocator 切换）推迟到 Phase 5。**

| 原顺序 | 修正后 |
|--------|--------|
| Phase 0: 基础设施 | Phase 0: 基础设施（含 deprecated 兼容方法） |
| Phase 1: mem 内部分配器 | Phase 1: mem 内部分配器 + 附带修复 |
| Phase 2: DefaultAllocator ❌ | Phase 2: collections 迁移 |
| Phase 3: collections | Phase 3: 数据格式迁移 |
| Phase 4: 数据格式 | Phase 4: builder + 其他迁移 |
| Phase 5: builder | **Phase 5: DefaultAllocator 切换** |
| Phase 6: 清理 | Phase 6: 清理 |

Phase 3/4/5 可并行执行（都只依赖 Phase 0）。

---

### Phase 0: 基础设施（1 文件）

**目标**: 定义 `TMemAllocator`，提供 deprecated 兼容方法。

**完整文件清单**:

| 文件 | 变更 |
|------|------|
| `allocator.base.pas` | 重写：`TAllocator` → `TMemAllocator`，添加 3 参数 `ReallocMem`（abstract）、2 参数 `FreeMem`（abstract）、保留 deprecated 2/1 参数兼容方法、`BatchGetMem`/`BatchFreeMem` virtual + 基类 fallback、`AllocMem` virtual + 默认实现。`IAllocator = TMemAllocator deprecated` |

**验证**: 全部现有代码编译通过（deprecated 兼容方法吸收旧调用）。

---

### Phase 1: mem 内部分配器迁移 + 附带修复（~18 文件）

**目标**: 所有分配器实现类继承 `TMemAllocator`；顺手修复已知技术债。

**完整文件清单**:

| 文件 | 变更 |
|------|------|
| `allocator.growing.pas` | `TGrowingAllocator = class(TMemAllocator)`；override `GetMem`/`ReallocMem(3p)`/`FreeMem(2p)`/`BatchGetMem`/`BatchFreeMem`。提取 `FastSizeClassIndex`（**P2 修复**）。`{$IFDEF LINUX}` → `{$IFDEF UNIX}`（**P1 修复**）。添加 Windows `FlsAlloc`/`FlsCallback`（**P1 修复**） |
| `allocator.rtl.pas` | `TRtlAllocator = class(TMemAllocator)`；`FreeMem(APtr, ASize)` 中 ASize 被忽略（回退 `System.FreeMem`） |
| `allocator.callback.pas` | 回调签名更新：`TFreeMemProc = procedure(APtr: Pointer; ASize: SizeUInt)`；`TReallocMemProc = function(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer` |
| `allocator.tracking.pas` | 继承改为 `TMemAllocator`，已跟踪 size 所以天然兼容 |
| `allocator.fallback.pas` | 同上 |
| `allocator.arena.pas` | `FreeMem` no-op（Arena 不支持单块释放），ASize 参数忽略 |
| `allocator.mimalloc.pas` | `FreeMem(APtr, ASize)` 中 ASize 被忽略（mimalloc 自己知道）。全局变量 `_MimallocAllocatorIntf: IAllocator` → `_MimallocAllocator: TMimallocAllocator`（消除 `as IAllocator` 转型） |
| `allocator.mmap.pas` | `FreeMem(APtr, ASize)` 中 ASize 被忽略 |
| `allocator.guard.pas` | 继承改为 `TMemAllocator` |
| `allocator.crt.pas` | `FreeMem(APtr, ASize)` 中 ASize 被忽略（crt_free 自己知道）。全局变量 `_CrtAllocatorIntf` 改为直接对象引用 |
| `pool.allocator.pas` | 继承改为 `TMemAllocator` |
| `pool.memory_pool.pas` | 更新 IAllocator 对齐注释 → TMemAllocator |
| `pool.fixed.growable.pas` | `FAllocator: IAllocator` → `FAllocator: TMemAllocator` |
| `pool.object_pool.pas` | 同上 |
| `pool.fixed_slab.pas` | 同上 |
| `arena.chunked.pas` | `FAllocator: IAllocator` → `FAllocator: TMemAllocator` |
| `arena.local.pas` | 同上 |
| `blockpool.growable.pas` | 同上 |
| `allocator.foundation.pas` | 更新导出类型 |
| `ring_buffer.pas` | `FAllocator: IAllocator` → `FAllocator: TMemAllocator` |

**验证**: mem 模块全量测试通过（45 suites / 573+ tests / 0 failures）。

---

### Phase 2: collections 迁移（~30 文件）

**目标**: 所有 `FAllocator: IAllocator` → `FAllocator: TMemAllocator`，`FreeMem`/`ReallocMem` 调用带 size。

**完整文件清单**:

| 文件 | 关键变更 |
|------|---------|
| `collections.base.pas` | `FAllocator: TMemAllocator`；构造函数参数 `IAllocator` → `TMemAllocator`；`FreeMem`/`ReallocMem` 带 size |
| `collections.intf.pas` | `IAllocator` → `TMemAllocator` in interface declarations |
| `collections.element_manager.intf.pas` | `IAllocator` → `TMemAllocator` in interface |
| `collections.element_manager.pas` | `FreeMem(aDst)` → `FreeMem(aDst, aElementCount * FElementSize)`；`ReallocMem(aDst, new)` → `ReallocMem(aDst, old, new)` |
| `collections.arr.pas` | swap buffer FreeMem 带 size |
| `collections.vec.pas` | 通过 element_manager 间接，自动跟随 |
| `collections.list.pas` | 同上 |
| `collections.deque.pas` | 构造函数参数类型更新 |
| `collections.vecdeque.pas` | 构造函数参数类型更新 |
| `collections.stack.pas` | 构造函数参数类型更新 |
| `collections.hashmap.pas` | `FreeMem(FBuckets)` 带 `FBucketCount * SizeOf(...)` |
| `collections.hashmap.swiss.pas` | Ctrl/Slots FreeMem 带 group count × size |
| `collections.hashmap.swiss.str.pas` | 同上 |
| `collections.hashmap.swiss.i32.pas` | 同上 |
| `collections.hashmap.swiss.i32i32.pas` | 同上 |
| `collections.hashmap.swiss.adapter.pas` | 接口签名更新 |
| `collections.linkedhashmap.pas` | node FreeMem 带 `SizeOf(TLinkedHashNode)` |
| `collections.node.pas` | pointer array FreeMem 带 count × SizeOf(Pointer) |
| `collections.hashset.pas` | 构造函数参数类型更新 |
| `collections.priorityqueue.pas` | 构造函数参数类型更新 |
| `collections.orderedmap.rb.pas` | 构造函数参数类型更新 |
| `collections.treemap.pas` | 构造函数参数类型更新 |
| `collections.tree_set.pas` | 构造函数参数类型更新 |
| `collections.multiset.pas` | 构造函数参数类型更新 |
| `collections.lrucache.pas` | 构造函数参数类型更新 |
| `collections.bitset.pas` | 构造函数参数类型更新（从 Phase 4 提前） |
| `collections.forward_list.pas` | 构造函数参数类型更新（从 Phase 4 提前） |
| `collections.pas` | 门面类型别名 + 所有 `MakeXxx<T>` 工厂函数签名更新（29 个工厂函数，107 处 IAllocator 引用） |

**验证**: collections 全量测试通过。

---

### Phase 3: 数据格式迁移（~12 文件）

**目标**: xml/json/toml/yaml/ini/csv 的 allocator 参数和 FreeMem/ReallocMem 调用迁移。

**完整文件清单**:

| 文件 | 关键变更 |
|------|---------|
| `xml.dom.pas` | `FAllocator: TMemAllocator`；FreeMem 带 cap × SizeOf；ReallocMem 带旧 cap |
| `xml.pas` | 公开 API 参数 `IAllocator` → `TMemAllocator`：`XmlParseWith`/`XmlParseDocWith`/`TryXmlParseWith`/`TryXmlParseDocWith`/`XmlTokenizeWith` |
| `json.pas` | 公开 API 参数 `IAllocator` → `TMemAllocator` |
| `json.parser.pas` | ReallocMem 带旧 cap；FreeMem 带 cap |
| `toml.pas` | 公开 API 参数 `IAllocator` → `TMemAllocator` |
| `toml.parser.pas` | ReallocMem 带旧 cap |
| `yaml.pas` | 公开 API 参数 `IAllocator` → `TMemAllocator` |
| `yaml.parser.pas` | ReallocMem 带旧 cap |
| `yaml.builder.pas` | ReallocMem 带旧 cap（通过 `FDoc.Allocator` 间接依赖） |
| `ini.pas` | FreeMem/ReallocMem 带 cap |
| `csv.pas` | 同上 |

**验证**: 所有格式模块测试通过。

---

### Phase 4: Builder + 其他迁移（~5 文件）

**目标**: 剩余模块迁移。

**完整文件清单**:

| 文件 | 关键变更 |
|------|---------|
| `bytes.builder.pas` | `FAllocator: TMemAllocator`；FreeMem 带 `FCapacity`；ReallocMem 带旧 `FCapacity` |
| `text.builder.pas` | 同上，用 `FCap` |
| `allocator.leak_check.pas` | `TAllocatorTestProc = procedure(AAllocator: TMemAllocator)`；`RunLeakCheck` 参数更新 |
| 其他遗留 | 逐个 grep 验证，无遗漏 |

**验证**: 全量测试通过。

---

### Phase 5: DefaultAllocator 切换（2 文件）

**目标**: `DefaultAllocator` 返回 `TGrowingAllocator`。**此时所有调用点已迁移到 2 参数 FreeMem/3 参数 ReallocMem。**

| 文件 | 变更 |
|------|------|
| `mem.default.pas` | `DefaultAllocator` → `DefaultGrowingAllocator` |
| `mem.pas` | 更新聚合声明 |

**验证**: 全量测试通过。所有 `DefaultAllocator` 调用点自动走 TLS cache 路径。

---

### Phase 6: 清理（~5 文件）

**目标**: 删除旧代码，消除别名。

| 操作 | 说明 |
|------|------|
| 删除 `IAllocator = TMemAllocator` deprecated 别名 | 所有引用已迁移 |
| 删除 deprecated `ReallocMem(ADst, ASize)` 2 参数兼容方法 | 所有调用点已迁移到 3 参数 |
| 删除 deprecated `FreeMem(ADst)` 1 参数兼容方法 | 所有调用点已迁移到 2 参数 |
| 删除 `TAllocator` 旧基类引用 | 已被 `TMemAllocator` 取代 |
| 清理 `allocator.foundation.pas` | 不再 re-export IAllocator |
| 删除 `SizeClassIsScan[]`（**P2 修复**） | 无代码使用，等 GC 实现时按需引入 |
| 更新文档 | ARCHITECTURE.md / README.md / API.md / ROADMAP-v8.md |

---

## 五、附带修复（趁迁移做）

### 5.1 P1: Windows/macOS 线程退出泄漏

**Phase 1 完成**。`allocator.growing.pas`:

- `{$IFDEF LINUX}` → `{$IFDEF UNIX}`（pthread_key_create 在 macOS/Darwin 同样可用）
- Windows 添加 `FlsAlloc` / `FlsCallback` 实现：

```pascal
{$IFDEF MSWINDOWS}
var
  GCacheCleanupIndex: DWORD;

function FlsAlloc(lpCallback: TFlsCallback): DWORD; stdcall; external 'kernel32.dll';
function FlsFree(dwFlsIndex: DWORD): BOOL; stdcall; external 'kernel32.dll';
function FlsSetValue(dwFlsIndex: DWORD; lpFlsData: Pointer): BOOL; stdcall; external 'kernel32.dll';

procedure ThreadExitFls(AData: Pointer); stdcall;
begin
  if (AData <> nil) and (GGrowingAllocator <> nil) then
    ThreadCacheFlushAll(GThreadCache, @FlushToCentral);
end;
{$ENDIF}
```

### 5.2 P2: ReallocMem 优化

**Phase 1 完成**。提取公共的 `FastSizeClassIndex` 内联函数，消除 band 检查重复：

```pascal
function FastSizeClassIndex(ASize: SizeUInt): Int32; inline;
begin
  if ASize <= 256 then
    Result := Int32((ASize + 15) shr 4) - 1
  else if ASize <= 1024 then
    Result := Int32(ASize shr 6) + 14
  else
    Result := SizeClassIndex(ASize);
end;
```

ReallocMem 变为：
```pascal
if FastSizeClassIndex(AOldSize) = FastSizeClassIndex(ANewSize) then
  Exit(APtr);
```

`GetMem`、`FreeMem`、`BatchGetMem`、`BatchFreeMem` 也复用此函数，消除重复的 band 分支。

### 5.3 P2: scan/noscan 清理

**Phase 6 完成**。删除 `SizeClassIsScan[]` 数组及相关函数。当前无代码使用。

---

## 六、风险与缓解

| 风险 | 等级 | 缓解 |
|------|------|------|
| 71 文件一次改完容易出错 | 高 | **分 6 个 Phase，每个 Phase 独立编译验证** |
| **Interface → Class 生命周期变化** | **高** | `IAllocator` 是引用计数的接口。改为 `TMemAllocator` 类后，`FAllocator` 字段不再自动管理生命周期。缓解：`DefaultAllocator` 返回全局单例（生命周期无限）；用户自定义 allocator 由调用方显式管理。Phase 1 消除所有 `_XXXAllocatorIntf: IAllocator` 全局接口变量 |
| `as IAllocator` 转型语义变化 | 中 | Phase 1 消除所有 `Obj as IAllocator` 转型，改为直接对象引用 |
| `TInterfacedObject, IAllocator` 继承链 | 中 | 如果类不再需要接口，可能移除 `TInterfacedObject` 继承。Phase 1 评估每个实现类 |
| `collections.pas` 工厂函数泛型特化 | 中 | 29 个 `MakeXxx<T>` 工厂函数签名变更。外部代码使用这些工厂的也需迁移。`deprecated` 别名减轻影响 |
| FreeMem 传错 size | 中 | `{$IFDEF DEBUG}` 下 `TGrowingAllocator.FreeMem` 内部 assert：`FastSizeClassIndex(ASize)` 与内部 span 的 slot size 匹配 |
| 编译器自举失败 | 低 | compiler 模块不使用 IAllocator，不受影响 |
| 性能回归 | 低 | 抽象类 vtable dispatch 与接口 vtable dispatch 开销相同。基准验证（Phase 5） |

---

## 七、预期收益

| 指标 | 迁移前 (TRtlAllocator) | 迁移后 (TGrowingAllocator) |
|------|----------------------|--------------------------|
| 64B 分配 | ~65ns (FPC GetMem) | **16ns** (TLS cache) |
| 1KB 分配 | ~100ns | **21ns** |
| 多线程争用 | System.GetMem 全局锁 | **TLS 0 争用** |
| OS 内存回收 | ❌ 无 | ✅ Scavenger |
| 碎片率控制 | 无 size class | **62 classes** |

**所有使用 `DefaultAllocator` 的 40 个模块自动获得以上收益，无需修改任何业务代码。**

---

## 八、验收标准

### 编译

- [ ] `IAllocator` 类型不存在（`grep -rn 'IAllocator' core/src/` 返回 0）
- [ ] 无 `as IAllocator` 转型残留
- [ ] 无 `TInterfacedObject, IAllocator` 继承残留
- [ ] 所有 `FreeMem` 调用携带 size 参数
- [ ] 所有 `ReallocMem` 调用携带 old size 参数

### 运行时

- [ ] `DefaultAllocator` 返回 `TGrowingAllocator` 实例
- [ ] `_XXXAllocatorIntf: IAllocator` 全局变量已改为直接对象引用
- [ ] 所有 `collections.pas` 的 `MakeXxx<T>` 工厂函数签名兼容

### 测试

- [ ] mem 模块 45 suites / 573+ tests / 0 failures / 0 leaks
- [ ] collections 全量测试通过
- [ ] 数据格式全量测试通过 (xml/json/toml/yaml/ini/csv)
- [ ] compiler-pass 全量通过
- [ ] `make verify` 全绿

### 性能（基准机器）

- [ ] 64B 分配 ≤ 20ns（DefaultAllocator.GetMem 单线程）
- [ ] 1KB 分配 ≤ 25ns
- [ ] 多线程 4T 0 争用（TLS cache 隔离）
- [ ] 多线程压力测试无泄漏（valgrind 或 leak_check）
- [ ] DEBUG 模式 assert 覆盖所有 FreeMem 调用点

### 文档

- [ ] ARCHITECTURE.md 更新
- [ ] API.md 更新
- [ ] ROADMAP-v8.md 更新
- [ ] README.md 更新
