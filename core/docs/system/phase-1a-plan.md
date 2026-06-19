# Phase 1a 实施计划: 语言核心改进

> **文档版本**: v2.3 — 2026-06-18
> **状态**: Codex R4 审查修订版 (2 medium 全部修复, 准备进入实施)
> **前置**: Phase 0 自举完成 (`d8e47ce7b`)
> **路线图来源**: `docs/plans/2026-06-18-system-kernel-roadmap.md` Section 3/6/7
> **质量标准**: 虐哭 FPC，拳打 Go，脚踢 Rust

---

## 0. 设计原则

**编译器是 nextpas.core 的消费者** — 编译器不搞特殊，和用户代码一样用 nextpas.core 基础设施。

**已存在的不重做** — atomic/sync/lockfree 模块已完整，P4a 只做增量扩展（TSyncPool）。

**TString 走路线图 24B** — SSO 用显式 Len 字节判别，不靠字节高位猜。

---

## 1. 总览与依赖图

```
TString (24B, SSO+CoW)  ←  独立，不阻塞 RAII
        ↓ 集成
  nextpas.core.text    ←  text 模块 16 suites (256 tests) 必须全绿
        ↓ 依赖
RAII for Records      ←  依赖 TString refcount 协议
        ↓ 依赖
  编译器集成           ←  编译器迁移到 TString，HIR scope exit 插入

P4a (增量)            ←  独立于 TString/RAII，可并行
```

**并行策略**: TString 和 P4a 可并行开发（无依赖）。RAII 在 TString S7.3(CoW) 完成后启动。

---

## 2. P4a: 已有基础设施 + TSyncPool 增量

### 2.1 已存在模块（不重做）

| 路线图规格 | 仓库现状 | 状态 |
|-----------|---------|------|
| S10.1 TAtomic<T> 泛型 | `nextpas.core.atomic.types`: `TAtomicISize`, `TAtomicRefCount`, `TAtomicPtr<T>` | ✅ 完整 |
| memory_order_t | `nextpas.core.atomic.core`: `memory_order_t` 枚举 (moRelaxed..moSeqCst) | ✅ 完整 |
| x86-64 + ARM64 内联 asm | `nextpas.core.atomic.compat`: CAS/Load/Store 原始操作 | ✅ 完整 |
| S10.4a TSpinLock | `nextpas.core.sync.spinlock`: 基于 CAS 的自旋锁 + ILockGuard | ✅ 完整 |
| S10.4a TMutex | `nextpas.core.sync.mutex`: futex(Linux) / CriticalSection(Win) + TFutexMutex | ✅ 完整 |
| S10.4a TRwLock | `nextpas.core.sync.rwlock`: 读写锁 | ✅ 完整 |
| S10.4a TSemaphore | `nextpas.core.sync.semaphore`: 信号量 | ✅ 完整 |
| S10.4a TEvent | `nextpas.core.sync.event`: 事件等待 | ✅ 完整 |
| S10.4a TBarrier | `nextpas.core.sync.barrier`: 栅栏同步 | ✅ 完整 |
| S10.4a TOnce | `nextpas.core.sync.once`: 一次性初始化 | ✅ 完整 |
| S10.4a TWaitGroup | `nextpas.core.sync.waitgroup`: 等待组 | ✅ 完整 |
| TConVar | `nextpas.core.sync.condvar`: 条件变量 | ✅ 完整 |
| lockfree 队列/栈 | `nextpas.core.lockfree.*`: SPSC/MPSC/SPMC/MPMC/SegQueue/Deque/Stack/Channel/EBR/HashMap | ✅ 完整 |

> **所有命名遵循现有规范**: `TAtomicISize` (非 `TAtomicInt`)，`memory_order_t` (snake_case 非 `TMemoryOrder`)，`ILockGuard` (interface `I` 前缀)。

### 2.2 增量工作: TSyncPool

路线图 S10.4a 指定的 `TSyncPool` 是唯一真正缺失的部分。

**设计** (路线图 6.4):

```pascal
// nextpas.core.sync.pool.pas
type
  TSyncPool = record
  private
    FPrivate: PPointer;                   // per-thread 私有缓存 (Create 时一次性 bump 分配 AThreadCount * SizeOf(Pointer))
    FPrivateCount: SizeInt;               // FPrivate 数组长度
    FShared: array of specialize TLockFreeStack<Pointer>;  // per-thread 共享缓存 (Create 时 SetLength 一次, 运行期不 resize)
    FVictim: array of specialize TLockFreeStack<Pointer>;  // epoch 翻转时回收 (Create 时 SetLength 一次, 运行期不 resize)
    FAllocator: IAllocator;               // 对象分配/释放
    FEpoch: TAtomicISize;                 // epoch 计数
    FNewFn: function: Pointer;            // 对象工厂
    procedure VictimFlip;
  public
    constructor Create(AFactory: function: Pointer; AThreadCount: SizeInt);
    // FPrivate: TFixedArena 一次性 bump 分配, raw pointer + count
    // FShared/FVictim: Create 时 SetLength 一次, 运行期只读不写长度
    function Get: Pointer;                // 获取对象 (快路径: FPrivate, 慢路径: FShared→FVictim→new)
    procedure Put(AObj: Pointer);         // 归还对象 (快路径: FPrivate, 慢路径: FShared)
  end;
```

**淘汰策略** (路线图 6.4): 时间驱动 victim flip — 每 N 秒 (默认 1s) 执行 epoch 翻转：
1. FVictim 中的对象释放
2. FShared → FVictim
3. FShared 清空

**依赖**: `nextpas.core.lockfree.stack` + `nextpas.core.atomic.types.TAtomicISize` + `nextpas.core.mem.IAllocator`

**验收标准**:
- [ ] Get/Put 快路径无锁 (< 15ns)
- [ ] victim flip 正确性 (无 double-free, 无泄漏)
- [ ] 多线程并发安全 (TSAN clean)
- [ ] heaptrc 0 leak
- [ ] benchmark: 对标 Go sync.Pool

---

## 3. TString: 路线图 24B 设计

### 3.1 内存布局 (路线图 3.1)

```pascal
// nextpas.core.text.string_types.pas
type
  PStringHeader = ^TStringHeader;
  TStringHeader = record
    RefCount: SizeInt;      // 原子引用计数 (<0 表示字符串 literal, 不可 free)
    Capacity: SizeUInt;     // 堆缓冲区容量 (不含 header)
    Flags: SizeUInt;        // 保留: encoding hints, small-buffer reclaim 等
  end;
  // SizeOf(TStringHeader) = 24 bytes

const
  TStringSSOTag  = 0;     // SSO 路径 tag
  TStringHeapTag = $FF;   // Heap 路径 tag (不可能是合法堆地址低字节)

  TString = record
    case Boolean of
      False: (  // SSO 路径
        SSOTag: Byte;                   // 0 = SSO
        SSOLen: Byte;                   // [0..15], 内联字符串长度
        SSOBuf: array[0..14] of Byte;   // 15 字节内联缓冲区
        _Pad: array[0..6] of Byte;      // 对齐到 24B
      );
      True: (  // Heap 路径
        HeapTag: Byte;                  // $FF = Heap
        _Pad2: array[0..6] of Byte;     // 对齐到 offset 8
        Header: PStringHeader;          // 堆 header 指针 (8-byte aligned)
        HeapLen: SizeUInt;              // 字符串长度
      );
  end;
  // SizeOf(TString) = 24 bytes, 8-byte aligned
```

**SSO 容量**: 15 字节 (比无 tag 方案少 1 字节，实际影响微乎其微——15 字节覆盖绝大多数标识符、路径段、数字串)。

**SSO 判别逻辑** (R1 #3 修复 + R2 M5 强化):

**前提**: nextPas 仅支持 64 位系统 (x86-64 + ARM64)。

```pascal
function IsSSO(const S: TString): Boolean; inline;
begin
  // Tag byte (offset 0) 做所有判别:
  //   SSO 路径: SSOTag = 0
  //   Heap 路径: HeapTag = $FF
  // 完全无歧义——不依赖指针值、不依赖 Len 值、不依赖对齐假设
  Result := S.SSOTag = TStringSSOTag;
end;
```

**为什么用 tag byte 而非 Len 值判别**:
- R1 方案 "byte[15] < 128" 被 UTF-8 多字节序列击穿 (critical #3)
- R2 v2.0 方案 "Len ≤ 16" 在 64 位系统上理论上安全 (用户空间堆地址 ≥ 0x5500...)，但依赖分配器不返回低地址 → 有隐式假设
- v2.1 方案: 显式 tag byte (0 vs $FF) → 零假设、零歧义，代价仅 1 字节 SSO 容量 (16→15)

**判别方案演进**:

| 版本 | 方案 | 问题 |
|------|------|------|
| R1 v1.0 | byte[15] < 128 → SSO | ❌ UTF-8 多字节 continuation bytes ≥ 0x80 → 误判为 Heap |
| R2 v2.0 | 显式 Len [0..16] | ⚠️ 理论上安全 (64位用户空间地址 ≥ 0x5500) 但依赖隐式假设 |
| R3 v2.1 | 显式 Tag byte (0 vs $FF) | ✅ 零假设、零歧义，代价 1 字节 SSO 容量 (16→15) |

### 3.2 核心操作

```pascal
// nextpas.core.text.string_core.pas
procedure StringInit(var S: TString);                              // 零初始化 = 空串
procedure StringFini(var S: TString);                              // SSO: 清零; Heap: decr refcount → free
procedure StringAssign(var ADest: TString; const ASource: TString); // CoW 赋值
procedure StringSetLength(var S: TString; ANewLen: SizeUInt);       // 设置长度
function StringLen(const S: TString): SizeUInt; inline;             // 获取长度
function StringData(const S: TString): PByte; inline;              // 获取数据指针
function StringRefCount(const S: TString): SizeInt; inline;         // 引用计数 (SSO 返回 -1)
```

**CoW 赋值语义** (StringAssign):
1. 如果源是 SSO → 直接 memcpy 24B (无 refcount, 包含 tag + len + buf)
2. 如果源是 Heap →
   a. 旧目标 Heap 且 refcount > 0 → atomic decr, =0 时 free
   b. 新目标 = source 的 Header 指针 + atomic incr

**CoW 写时拷贝**:
- 当需要修改 Heap 路径的字符串时 (如 Append, SetLength)
- 检查 RefCount: =1 → 直接修改; >1 → alloc new + copy + decr old

### 3.3 与 nextpas.core.text 集成策略

**Phase A: 并存 (TString + AnsiString)**

text 模块当前基于 FPC `AnsiString` (16 suites / 256 tests)。TString 集成分三步：

1. **S7.4a: 定义兼容 shim**
   - 提供 `TStringHelper` record helper，实现 text 模块需要的所有接口
   - 提供 `TStringView` → `TString` 转换
   - 提供 `AnsiString` ↔ `TString` 互转 (用于过渡期)

2. **S7.4b: text 模块适配层**
   - `nextpas.core.text.strings` 核心操作适配到 TString
   - `nextpas.core.text.view` 的 TStringView 对应 TString 的 view 语义
   - 保持 16 suites (256 tests) 全绿 (覆盖 builder/char/compare/escape/grapheme/number/scan/strings/unicode x3/utf8/view/width 等子模块)

3. **S7.4c: 编译器迁移**
   - 编译器 AST 的字符串字段从 AnsiString 迁移到 TString
   - LLVM emitter: EmitStringLiteral 改为 SSO 内联 emit
   - string_assign intrinsic 改为 CoW 赋值
   - string_cleanup 改为 CoW refcount decr

**ABI 变更影响** (基于编译器字符串 ABI 审计):

| 当前编译器机制 | 变更类型 | 说明 |
|---------------|----------|------|
| `store_str_lit` intrinsic | 重写 | 字面量 emit 改为 SSO 内联 (≤15B) 或 CoW 堆 |
| `string_release` intrinsic | 重写 | fpc_ansistr_decr_ref → CoW refcount decr |
| `string_owner_clear` intrinsic | 重写 | owned 清理 → CoW decr |
| `hnkStringCleanupRuntime` | 重写 | ad-hoc cleanup → managed record fini |
| 4-alloca 模型 `{ptr,len,owner,alloc_size}` | **全面迁移** | 从 4-tuple 改为 24B variant record |
| ~30 种 `hnk*String*` HIR 节点 | 合并简化 | owned/borrowed 两套 → 单一 TString 节点 |
| borrowed: `{ptr, i64}` LLVM IR | 适配 | → 24B `{i8, [15xi8], [7xi8], ptr, i64}` |
| owned: `{ptr, i64, ptr, i64}` LLVM IR | 适配 | → 24B variant record |

**迁移策略**: 逐步替换，先 SSO 路径 (tag=0, 无 refcount)，再 CoW 路径。

---

## 4. RAII for Records

### 4.1 S11.0: CoW refcount 与 RAII Finalize 协作协议

**核心问题**: RAII finalize 和 CoW refcount decr 的时序关系。

```
场景分析:
1. var L: TString;        → L 初始化为 SSO 空串, scope exit 直接清零 (无 refcount)
2. var L: TString;        → L := GetHeapString(); scope exit → refcount decr
3. var L, M: TString;     → M := L (CoW bump); scope exit: L 先 finalize (decr), M 后 finalize (decr)
4. var R: TRecordWithStr; → R.S := GetStr(); scope exit → R.Finalize → R.S.Finalize → decr
```

**协议**:
- **RAII Finalize = 对 record 中每个 managed field 调用 field 的 Finalize**
- **TString Finalize**: SSO → 清零; Heap → atomic decr, =0 → free header
- **赋值不触发 RAII finalize** — 赋值是操作符语义，不等于 scope exit
- **Move 语义**: StringMove(dest, src) — 转移 ownership，src 置零，不 bump refcount

### 4.2 S11.1: 编译器 managed field 检测

**语义分析变更** (nextpas compiler):

```pascal
// TypeDecl 分析
type
  TManagedFieldFlag = (
    mffString,        // 包含 TString 字段
    mffInterface,     // 包含 interface 字段
    mffDynArray,      // 包含 dynamic array 字段
    mffManagedRecord  // 包含 managed record 字段
  );
  TManagedFieldFlags = set of TManagedFieldFlag;
```

- `TCustomRecordType.HasManagedFields: Boolean` — 遍历所有 field 类型检测
- `TVarDecl.NeedsFinalize: Boolean` — 局部变量含 managed fields 时标记

### 4.3 S11.1b: HIR block-scoped variable registry (前置步骤)

当前编译器**没有 block-level variable registry**。实际的 scope exit 是 semantic analyzer 通过 `FOwnedRuntimeStrVarNames` 扁平数组追踪的，没有按 block 分组。

**需要新增**:
```pascal
// THIRBlock 扩展
THIRBlock = record
  // ... 现有字段 ...
  FManagedVars: array of THIRManagedVar;  // 需要 finalize 的变量列表
end;

THIRManagedVar = record
  VarIndex: SizeInt;           // 变量在 alloca 区的索引
  ManagedKind: TManagedFieldFlag;  // 变量的 managed 类型
  InitMaskBit: SizeInt;        // 部分初始化 bitmap 中的 bit 位置
end;
```

**实现**: 在 `THIRBuilder` 中建立按 block 分组的变量声明追踪机制，替代现有 `FOwnedRuntimeStrVarNames` 扁平数组。使用 `nextpas.core.mem` 的 Arena 分配 `THIRManagedVar` 避免高频路径的动态数组 resize 开销。

### 4.4 S11.2: HIR scope exit 插入

**HIR Builder 变更** (nextpas compiler):

```pascal
// THIRBuilder 在 block exit 时:
procedure THIRBuilder.EmitBlockExit(ABlock: THIRBlock);
var
  LVar: THIRVarDecl;
begin
  // 逆序 finalize (后声明的先 finalize — 匹配栈顺序)
  for i := ABlock.VarCount - 1 downto 0 do
  begin
    LVar := ABlock.Vars[i];
    if LVar.NeedsFinalize then
      EmitManagedRecordFini(LVar);  // → @np_managed_record_fini
  end;
end;
```

**HIR 操作**:
- `hokManagedRecordFini` — 新增 HIR opcode
- 操作数: variable reference
- 语义: 调用变量的 Finalize 方法 (对 record 递归 finalize 所有 managed fields)

### 4.5 S11.3: 异常路径 cleanup

**当前状态**: setjmp/longjmp 异常模型 (Gate 5 PASS)。

**LLVM emission**:
- 正常路径: scope exit → `@np_managed_record_fini`
- 异常路径: landingpad → cleanup block → `@np_managed_record_fini`
- **部分初始化 guard**: 用 bitmap 追踪哪些 fields 已初始化

```pascal
// Cleanup block 伪码:
cleanup:
  %init_mask = load i64, ptr %var.init_mask
  ; 只 finalize 已初始化的字段
  %has_str = and i64 %init_mask, 1  ; bit 0 = string field
  br i1 %has_str, label %finalize_str, label %skip_str
finalize_str:
  call void @np_string_fini(ptr %var.str_field)
  br label %skip_str
skip_str:
  ; ... 其他 managed fields ...
  resume  ; 继续异常传播
```

### 4.6 S11.4: np.system.managed_record_init/fini 实现

```pascal
// nextpas.core.system — 契约 live 化
procedure np_managed_record_init(AMeta: PTypeInfo; ARecord: Pointer);
  // 零初始化所有 managed fields (不分配内存, 只清零)

procedure np_managed_record_fini(AMeta: PTypeInfo; ARecord: Pointer);
  // 逆序 finalize 所有已初始化的 managed fields
  // 利用 RTTI 的 ManagedKinds bitset 判断哪些字段需要 finalize
```

### 4.7 RAII 与 TString 的协作测试矩阵

| 场景 | 预期行为 | 测试用例 |
|------|---------|---------|
| SSO 变量 scope exit | 清零, 无 free | `test_raii_sso_finalize` |
| Heap 变量 scope exit | refcount decr → free | `test_raii_heap_finalize` |
| CoW 赋值 + scope exit | 两次 decr (源和目标各一次) | `test_raii_cow_assign_finalize` |
| 部分初始化 + 异常 | 只 finalize 已初始化字段 | `test_raii_partial_init_exception` |
| 嵌套 managed record | 递归 finalize | `test_raii_nested_record` |
| Move 语义 | 源置零, 目标接管 | `test_raii_move_semantics` |

---

## 5. 里程碑与验收标准

### M1: TString Core (约 2 周)

**交付**:
- `TStringHeader` + `TString` 24B layout 定义
- `StringInit/StringFini/StringLen/StringData`
- SSO 路径 (≤15B inline, memcpy 24B)
- Heap 路径 (alloc/decr/free)
- StringAssign CoW 语义

**验收**:
- [ ] `SizeOf(TString) = 24`
- [ ] 空串零初始化有效
- [ ] SSO (≤15B) 无堆分配 (heaptrc 验证)
- [ ] CoW refcount 正确 (赋值 bump, 修改时 copy)
- [ ] UTF-8 透传 (不转码)
- [ ] heaptrc 0 leak
- [ ] benchmark: SSO vs AnsiString 短串分配

### M2: TString + Text 集成 (约 1 周)

**交付**:
- `TStringHelper` record helper
- `AnsiString` ↔ `TString` 互转 shim
- text 模块适配层 (strings + view)

**验收**:
- [ ] text 模块 16 suites (256 tests) 全绿 (含 test_text_strings/test_text_view/test_text_width 关键子模块)
- [ ] 互转 roundtrip 测试

### M2.5: 编译器字符串 ABI 迁移 (约 3-4 周)

**交付**:
- 阶段 0: ABI 审计报告 (hnk* 节点盘点 + 映射表)
- 阶段 2: HIR 节点合并 (owned/borrowed → 单一 TString)
- 阶段 3: LLVM emitter 迁移 (4-alloca → 24B variant record)

**验收**:
- [ ] 所有 `hnk*String*` 节点迁移完成
- [ ] `FOwnedRuntimeStrVarNames` 替换为 block-scoped 追踪
- [ ] LLVM emitter emit 24B variant record
- [ ] 编译器 pass tests 全绿

### M3: RAII Core (约 2 周)

**交付**:
- S11.0: CoW refcount + RAII 协议文档
- S11.1: 编译器 managed field 检测
- S11.2: HIR scope exit 插入 (hokManagedRecordFini)
- S11.4: np.system.managed_record_fini 实现

**验收**:
- [ ] 含 string 字段的 record 自动 finalize
- [ ] 部分初始化不 double-free
- [ ] 嵌套 managed record 递归 finalize
- [ ] heaptrc 0 leak

### M4: RAII + 异常路径 (约 1 周)

**交付**:
- S11.3: 异常路径 cleanup (landingpad + cleanup block)

**验收**:
- [ ] 异常路径正确清理 (无泄漏)
- [ ] 编译器 pass tests 全绿

### M5: P4a TSyncPool (约 1 周, 与 M1-M4 并行)

**交付**:
- `nextpas.core.sync.pool.TSyncPool`
- 时间驱动 victim flip

**验收**:
- [ ] Get/Put 快路径无锁
- [ ] 多线程并发安全
- [ ] heaptrc 0 leak
- [ ] benchmark: 对标 Go sync.Pool

---

## 6. 编译器迁移路径

### 6.1 当前编译器字符串 ABI (审计结果)

编译器内部字符串使用 **4-alloca 模型**，与 TString 24B variant record **完全不兼容**：

```
当前编译器 LLVM IR 字符串表示:
  borrowed (只读视图): {ptr, i64}                    — 16 bytes
  owned (拥有所有权):  {ptr, i64, owner_ptr, i64}    — 32 bytes

TString 目标:
  variant record: 24 bytes, SSO tag + 15B inline 或 Heap tag + PStringHeader + Len
```

**HIR 层** (~30 种 string-specific `hnk*` 节点):
- `hnkStringLiteral`, `hnkStringConcat`, `hnkStringCompare`
- `hnkStringCleanupRuntime`, `hnkStringOwnerClear`, `hnkStringOwnerSet`
- `hnkStringBorrow`, `hnkStringBorrowFromLiteral`
- `hnkStoreStrLit`, `hnkStrLen`, `hnkStrIndex`
- ... 等

**Scope cleanup**: `FOwnedRuntimeStrVarNames` 扁平数组追踪 owned 变量，ad-hoc `EmitOwnedStringCleanupNodes` 生成 cleanup 代码。没有通用的 managed record 机制。

**LLVM emitter intrinsics**:
- `store_str_lit` — 字面量写入
- `string_release` — 释放引用 (调用 fpc_ansistr_decr_ref)
- `string_owner_clear` — 清除 owner
- `string_owner_set` — 设置 owner

### 6.2 迁移策略

**阶段 0: 编译器 ABI 审计与迁移方案** (M1 同期, 约 1 周)
- 详细盘点所有 `hnk*String*` 节点的语义
- 制定 owned/borrowed → 单一 TString 的映射表
- 确定 LLVM IR 24B record 的 emit 模板

**阶段 1: Runtime 层先行** (M1-M2, 不改编译器)
- 实现 `nextpas.core.text.string_types` / `string_core` / `string_cow`
- 编译器保持使用 `AnsiString`，不改 HIR
- LLVM emitter string intrinsics 保持现状
- **Gate**: TString 运行时所有测试通过 + text 模块 16 suites (256 tests) 全绿 + 编译器 build 管线正常

**阶段 2: HIR 节点迁移** (M3 之后)
- 合并 owned/borrowed 两套节点为单一 TString 节点
- 将 `FOwnedRuntimeStrVarNames` 扁平数组升级为 block-scoped 变量追踪
- `hnkStringCleanupRuntime` → `hokManagedRecordFini` (通用 managed record)
- 从叶子节点开始 (TIdentExpr, TStringLiteral) 向根推进

**阶段 3: LLVM emitter 迁移** (阶段 2 之后)
- `store_str_lit` → SSO 内联 emit (tag=0 + len + 15B buf)
- `string_release`/`string_owner_clear` → CoW refcount decr
- 4-alloca → 24B variant record emit
- Scope cleanup: ad-hoc → managed_record_fini

**阶段 4: 完全切换** (Phase 1b 之前)
- 移除所有 `AnsiString` 使用
- 编译器全部使用 TString
- 验证: 编译器能编译自身 (self-hosting roundtrip)

> **⚠️ 工作量估算**: 阶段 2-3 是编译器内部字符串表示的全面重写，非简单的字段替换。预计需要 3-4 周 (超出 M1-M2 范围)，独立为 M2.5 里程碑。

---

## 7. 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| 24B layout 与 FPC RTL 不兼容 | 编译器过渡期需要 shim | 6.2 阶段 1 提供 shim 层 |
| CoW atomic 操作在赋值密集场景性能差 | 标识符/路径等频繁赋值 | SSO 覆盖 ≤15B 场景; 未来考虑 intern table |
| RAII + setjmp/longjmp cleanup 复杂度 | 异常路径 finalize 不正确 | M4 独立测试异常路径 |
| text 模块 256 tests 适配工作量 | 可能需要修改 text 模块 API | 先 shim 适配，不改 text 内部 |

---

## 8. 与路线图的映射

| 路线图阶段 | Phase 1a 对应 | 状态 |
|-----------|--------------|------|
| S7.1: TString Layout | M1 | 待实现 |
| S7.2: SSO Path | M1 | 待实现 |
| S7.3: CoW Path | M1 | 待实现 |
| S7.4: Text Integration | M2 | 待实现 |
| S10.1: TAtomic<T> | — | ✅ 已存在 |
| S10.4a: sync.Pool | M5 | 待实现 |
| S10.4a: sync.Mutex/SpinLock | — | ✅ 已存在 |
| S11.0: CoW+RAII Protocol | M3 | 待实现 |
| S11.1: Managed Field Detection | M3 | 待实现 |
| S11.1b: HIR Block Registry | M2.5 | 待实现 (前置步骤) |
| S11.2: HIR Scope Exit | M3 | 待实现 |
| S11.3: Exception Cleanup | M4 | 待实现 |
| S11.4: managed_record_init/fini | M3 | 待实现 |

---

## 9. 文件清单 (预估新增)

```
core/src/nextpas.core.text.string_types.pas     ← TString/TStringHeader 定义
core/src/nextpas.core.text.string_core.pas       ← StringInit/Fini/Assign/Len/Data
core/src/nextpas.core.text.string_cow.pas        ← CoW refcount 逻辑
core/src/nextpas.core.text.string_helper.pas     ← TStringHelper record helper
core/src/nextpas.core.sync.pool.pas              ← TSyncPool
core/tests/nextpas.core.text/test_string_layout/ ← SizeOf + SSO + CoW 测试
core/tests/nextpas.core.text/test_string_cow/    ← CoW refcount 测试
core/tests/nextpas.core.sync/test_sync_pool/     ← TSyncPool 测试
core/tests/nextpas.core.system/test_raii_*/      ← RAII 编译器集成测试
```

---

## Codex 审查记录

### R1 (2026-06-18): 3 critical + 7 medium

| # | 级别 | 问题 | 修复 |
|---|------|------|------|
| 1 | 🔴 | P4a 严重重复：规划从零创建 TAtomicInt/TMemoryOrder/TSpinLock/TMutex | ✅ 2.1: 已有模块清单，只做 TSyncPool 增量 |
| 2 | 🔴 | TNPString (16B) 与路线图 TString (24B) 冲突 | ✅ 3.1: 采用路线图 24B 设计 |
| 3 | 🔴 | SSO 判别 bug: UTF-8 多字节 bytes ≥ 0x80 被误判为 heap pointer | ✅ 3.1: 用显式 Len 字节 [0..16] 判别 |
| 4 | 🟡 | text 模块集成策略缺失 | ✅ 3.3: 三阶段集成 (shim → 适配 → 迁移) |
| 5 | 🟡 | CoW 操作规格不足 | ✅ 3.2: StringAssign + CoW 写时拷贝详述 |
| 6 | 🟡 | Heap header Padding 浪费 → Flags | ✅ 3.1: Flags 保留字段 |
| 7 | 🟡 | RAII 太薄，缺少 S11.0-S11.4 细节 | ✅ 4.1-4.5: 完整展开 |
| 8 | 🟡 | 测试数量不匹配 | ✅ M1-M5: 里程碑化验收标准 |
| 9 | 🟡 | 命名不一致 (TMemoryOrder vs memory_order_t) | ✅ 2.1: 遵循现有命名规范 |
| 10 | 🟡 | 编译器迁移路径缺失 | ✅ 6: 三阶段迁移策略 |

### R2 (2026-06-18): 1 critical + 5 medium

| # | 级别 | 问题 | 修复 |
|---|------|------|------|
| C1 | 🔴 | text 模块测试数量 "16 suites (118 tests)" 与事实不符 (R2 误判为 2 suites / 58 tests) | ✅ R3 修正为 "16 suites (256 tests)" (R2 覆盖不完整) |
| M1 | 🟡 | TSyncPool 伪代码缺泛型参数 | ✅ 改为 `specialize TLockFreeStack<Pointer>` |
| M2 | 🟡 | 路线图 TLockFreeQueue 与仓库不一致 | ✅ 计划已用 TLockFreeStack，路线图待修订 |
| M3 | 🟡 | 编译器迁移过度简化，未反映 4-alloca 模型和 ~30 种 hnk 节点 | ✅ 6.1: 详细 ABI 审计; 6.2: 4 阶段迁移; 新增 M2.5 里程碑 |
| M4 | 🟡 | S11.2 HIR scope exit 依赖不存在的 block-level variable registry | ✅ 新增 S11.1b: HIR block-scoped variable registry 前置步骤 |
| M5 | 🟡 | SSO 判别 Len ≤ 16 有隐式假设风险 (64 位堆地址低字节可能 ≤ 16) | ✅ 改用显式 Tag byte (0 vs $FF)，零假设零歧义 |

### R3 (2026-06-18): 1 critical + 3 medium

| # | 级别 | 问题 | 修复 |
|---|------|------|------|
| RC-1 | 🔴 | text 模块测试数量修正不完整: "2 suites (58 tests)" 遗漏 14 个子模块 suite (实测 16 suites / 256 tests) | ✅ 全文修正为 "16 suites (256 tests)"，M2 验收增加关键子模块覆盖 |
| YM-1 | 🟡 | TSyncPool FPrivate dynamic array 并发 resize 不安全 | ✅ 改为固定大小预分配 (Create 时分配, 不使用 SetLength) |
| YM-2 | 🟡 | S11.1b THIRManagedVar dynamic array 高频分配开销 | ✅ 改用 mem Arena 分配 |
| YM-3 | 🟡 | 编译器迁移阶段 1→2 缺乏 gate | ✅ 阶段 1 末增加 gate: TString tests + 16 suites + build 正常 |

### R4 (2026-06-18): 2 medium

| # | 级别 | 问题 | 修复 |
|---|------|------|------|
| M#1 | 🟡 | TSyncPool FPrivate `array of Pointer` 声明与 "固定大小预分配" 注释矛盾 | ✅ FPrivate 改为 PPointer + FPrivateCount (Arena bump 分配) |
| M#2 | 🟡 | 路线图 SSO layout (16B Len+Buf) 与计划 (15B Tag+Len+Buf) 不一致 | ✅ 路线图同步更新为 15B tag-byte 方案 |
