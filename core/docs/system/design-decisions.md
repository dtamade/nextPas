# nextpas.core.system Design Decisions

本文件记录 system kernel 的关键架构决策。每条决策包含背景、选项、选择和后果，防止未来修改时重复犯错或做出矛盾变更。

## DD-1: 双编译器架构

**日期**: 2026-06
**状态**: 已采纳

### 背景

nextPas 需要同时支持两个编译器：
- FPC（现有编译器，用于 stage0 自举）
- nextPas 编译器（目标自举编译器）

两个编译器对 `System` 单元有不同的期望：FPC 期望标准 FPC System 类型，nextPas 期望自定义内核类型。

### 选项

1. **单一源码 + `{$IFDEF FPC}` 分叉**：在每个类型定义处用条件编译分叉
2. **文件级分叉**：`fpc.inc` 和 `kernel.inc` 两个独立文件，通过 `{$IFDEF FPC}` 选择包含
3. **完全分离**：两套独立的 System 单元

### 选择

**选项 2：文件级分叉**

- `nextpas.core.system.pas` 使用 `{$IFDEF FPC}` / `{$ELSE}` 选择包含
- `fpc.inc`：re-export FPC System 类型（零实现成本）
- `kernel.inc`：定义 nextPas 内核（17 个子模块）

### 后果

- ✅ 两个编译器都能编译同一份源码
- ✅ 内核定义完全独立，不受 FPC 限制
- ✅ FPC 路径零维护成本（只是 re-export）
- ⚠️ 需要确保 `fpc.inc` 和 `kernel.inc` 导出的类型名一致
- ⚠️ 未来移除 FPC 支持时只需删除 `fpc.inc` 和 `{$IFDEF}` 分支

### 相关文件

- `core/src/nextpas.core.system.pas`（门面）
- `core/src/nextpas.core.system.fpc.inc`
- `core/src/nextpas.core.system.kernel.inc`

---

## DD-2: 内核子模块拆分策略

**日期**: 2026-06
**状态**: 已采纳

### 背景

FPC 的 `System` 单元是一个巨大的单文件（~20000 行），包含所有类型和函数。需要决定如何组织 nextPas 内核。

### 选项

1. **单文件**：像 FPC 一样，所有定义在一个文件中
2. **按职责拆分**：每个子模块负责一个功能域
3. **按依赖拆分**：按类型依赖关系拆分

### 选择

**选项 2：按职责拆分**（17 个子模块）

```
base.inc     — 基础类型（SizeInt, TBytes, C ABI, Variant）
str.inc      — 字符串类型（ShortString, AnsiString, WideString, UnicodeString）
intf.inc     — 接口类型（TGUID, IUnknown, TInterfaceEntry）
cls.inc      — 类类型（VMT, TObject, TClass）
rtti.inc     — RTTI 类型（TTypeKind, TTypeInfo, TTypeData）
except.inc   — 异常类（Exception, EAbort, EConvertError, ...）
mem.inc      — 内存操作（ZeroMem, FreeAndNil, Supports）
memmgr.inc   — 内存管理器（TMemoryManager, GetMemoryManager）
lifecycle.inc — 程序生命周期（InitModule, FinalizeModule）
endian.inc   — 字节序转换（SwapEndian, BEtoN, LEtoN）
barrier.inc  — 内存屏障（ReadBarrier, WriteBarrier, Prefetch）
intrinsics.inc — 内存操作内建函数（FillByte, IndexChar, CompareChar）
thread.inc   — 线程类型（TThread, TRTLCriticalSection, BeginThread）
io.inc       — I/O 类型（TFileRec, TTextRec, File, Text）
comp.inc     — 编译器内部函数（fpc_* 系列）
```

### 后果

- ✅ 每个子模块职责单一，易于理解和维护
- ✅ 依赖关系清晰（base ← str ← intf ← cls ← ...）
- ✅ 可以独立测试每个子模块
- ⚠️ 需要管理 include 顺序（依赖关系）
- ⚠️ 子模块间不能循环依赖

### 包含顺序

```pascal
{$I nextpas.core.system.base.inc}      // 1. 基础类型
{$I nextpas.core.system.str.inc}       // 2. 字符串（依赖 base）
{$I nextpas.core.system.intf.inc}      // 3. 接口（依赖 base, str）
{$I nextpas.core.system.cls.inc}       // 4. 类（依赖 base, str, intf）
{$I nextpas.core.system.rtti.inc}      // 5. RTTI（依赖 base, str）
{$I nextpas.core.system.except.inc}    // 6. 异常（依赖 cls）
{$I nextpas.core.system.mem.inc}       // 7. 内存操作（依赖 base）
{$I nextpas.core.system.memmgr.inc}    // 8. 内存管理器（依赖 base）
{$I nextpas.core.system.lifecycle.inc} // 9. 生命周期
{$I nextpas.core.system.endian.inc}    // 10. 字节序（依赖 base）
{$I nextpas.core.system.barrier.inc}   // 11. 屏障
{$I nextpas.core.system.intrinsics.inc}// 12. 内建函数（依赖 base）
{$I nextpas.core.system.thread.inc}    // 13. 线程（依赖 base）
{$I nextpas.core.system.io.inc}        // 14. I/O（依赖 base）
{$I nextpas.core.system.comp.inc}      // 15. 编译器函数（依赖 base, str）
```

---

## DD-3: VMT 布局与 FPC 兼容

**日期**: 2026-06
**状态**: 已采纳

### 背景

对象的虚方法表（VMT）是对象模型的核心。需要决定是否与 FPC 的 VMT 布局兼容。

### 选项

1. **完全兼容 FPC**：使用相同的偏移和布局
2. **自定义布局**：优化布局，不考虑 FPC 兼容
3. **兼容 + 扩展**：兼容 FPC 布局，但可以添加新槽位

### 选择

**选项 1：完全兼容 FPC**

VMT 常量定义：
```pascal
vmtInstanceSize = 0;
vmtParent = SizeOf(SizeInt) * 2;      // 16
vmtClassName = SizeOf(SizeInt) * 3;    // 24
// ... 依此类推，共 28 个槽位
```

### 后果

- ✅ 已编译的 FPC 二进制可以在 nextPas 运行时运行
- ✅ 可以复用 FPC 的 VMT 生成逻辑
- ✅ 减少自举时的兼容性问题
- ⚠️ 不能随意修改 VMT 布局
- ⚠️ 未来扩展需要在 FPC 布局之后添加新槽位

### 稳定性承诺

VMT 布局常量已**冻结**，不得修改偏移值。

---

## DD-4: fpc_* 函数作为编译器内部函数

**日期**: 2026-06
**状态**: 已采纳

### 背景

FPC 使用 `fpc_*` 系列函数作为编译器内部函数（compilerproc），由编译器自动生成调用。需要决定 nextPas 如何处理这些函数。

### 选项

1. **保留 fpc_* 命名**：保持与 FPC 相同的函数名
2. **重新命名**：使用 nextPas 特有的命名（如 `np_*`）
3. **混合方案**：保留 fpc_* 作为内部名，添加 np.system.* 作为语义契约名

### 选择

**选项 3：混合方案**

- `fpc_*` 函数保留为编译器内部函数（compilerproc）
- `np.system.*` 名称作为语义契约（HIR intrinsic 级别）
- 编译器知道两者之间的映射关系

### 后果

- ✅ 编译器可以直接调用 fpc_* 函数（兼容 FPC 代码生成）
- ✅ 语义契约使用清晰的 np.system.* 命名
- ✅ 运行时实现可以自由选择 fpc_* 的实现方式
- ⚠️ 需要维护 fpc_* → np.system.* 的映射表
- ⚠️ fpc_* 函数签名已冻结，不得修改

### 映射示例

| fpc_* 函数 | np.system.* 契约 |
|-----------|----------------|
| `np_ansistr_incr_ref` | `np.system.string_fini` (部分) |
| `np_dynarray_setlength` | `np.system.dynarray_set_length` |
| `np_raise` | `np.system.exception_raise` |
| `np_halt` | `np.system.halt` |

---

## DD-5: Owner Boundary 原则

**日期**: 2026-06
**状态**: 已采纳

### 背景

nextpas.core 框架有很多模块（base, mem, text, fs, platform, ...）。需要决定 system kernel 如何与其他模块协作。

### 选项

1. **system 是总管**：system 包含所有功能
2. **system 是薄门面**：system 只做 re-export，实现由 owner 模块负责
3. **system 有选择地实现**：system 实现一些核心功能，其他委托给 owner

### 选择

**选项 2 + 3 混合：system 是薄门面 + 内核实现**

- **薄门面**：SysUtils、TypInfo、Errors 门面只做 re-export，委托给 owner 模块
- **内核实现**：VMT、fpc_*、TObject、线程、I/O 等核心类型由 system 直接实现

### Owner 边界表

| 功能域 | Owner | System stance |
|--------|-------|---------------|
| 基础类型 | `nextpas.core.base` | re-export 别名 |
| 异常分类 | `nextpas.core.exception` | re-export 别名 |
| 错误分类 | `nextpas.core.errors` | re-export 别名 |
| 内存工具 | `nextpas.core.base.utils` | inline forwarding |
| 文本转换 | `nextpas.core.text.conv` | sysutils facade |
| TypInfo | FPC TypInfo + System | typinfo facade |
| 平台 API | `nextpas.core.platform` | **禁止直接使用** |
| OS 单元 | — | **禁止直接使用** |

### 后果

- ✅ 每个功能有明确的 owner，避免重复实现
- ✅ system 只做必要的事，保持精简
- ✅ owner 模块可以独立演进
- ⚠️ system 不能绕过 owner 直接调用 OS 单元
- ⚠️ 新增功能必须先确定 owner，再决定是否需要 system 门面

### 禁止事项

- ❌ 在 system 中直接使用 `Windows`, `BaseUnix`, `Unix`
- ❌ 在 system 中复制 FPC SysUtils/Classes 杂货箱
- ❌ 绕过 owner 边界调用平台 API

---

## DD-6: TypInfo 最小门面策略

**日期**: 2026-06
**状态**: 已采纳

### 背景

TypInfo（RTTI）是编译器和运行时的关键接口。需要决定 system 提供多少 TypInfo 功能。

### 选项

1. **完整 TypInfo 兼容**：复制 FPC 的所有 TypInfo 功能
2. **最小门面**：只提供编译器和运行时必需的 TypInfo 功能
3. **延迟决策**：先不提供 TypInfo，等需求明确

### 选择

**选项 2：最小门面**

只提供 7 个核心符号：
```pascal
PTypeInfo, TTypeKind, PTypeData, TTypeData
GetPropInfo, GetEnumName, GetEnumValue
```

### 后果

- ✅ 满足当前编译器和运行时的需求
- ✅ 避免过早承诺 TypInfo API
- ✅ 可以按需扩展（有真实消费压力时）
- ⚠️ 不提供 property metadata 或 reflection layout
- ⚠️ 扩展需要 `Needs Review` 流程

### 扩展规则

1. 必须有真实消费压力（不是"未来可能需要"）
2. 必须有 focused API 测试
3. 必须通过 `Needs Review` 流程

---

## DD-7: SysUtils 门面委托策略

**日期**: 2026-06
**状态**: 已采纳

### 背景

FPC 的 SysUtils 包含数百个函数。需要决定 system 提供多少 SysUtils 功能。

### 选项

1. **完整 SysUtils 兼容**：复制 FPC 的所有 SysUtils 功能
2. **按需委托**：只提供消费压力大的函数，委托给 owner 模块
3. **不提供**：完全不提供 SysUtils 兼容

### 选择

**选项 2：按需委托**

提供 40+ 函数，全部委托给 owner 模块：
- 数值转换 → `nextpas.core.text.conv`
- 文件系统 → `nextpas.core.fs`
- 路径操作 → `nextpas.core.path`
- 环境变量 → `nextpas.core.platform`

### 后果

- ✅ 满足现有 core 模块的 SysUtils 需求
- ✅ 不复制实现，避免维护两份代码
- ✅ owner 模块保持功能完整性
- ⚠️ 不提供所有 FPC SysUtils 函数
- ⚠️ 新增函数需要有真实消费压力

### 委托示例

```pascal
function FileExists(const AFileName: string): Boolean;
begin
  Result := nextpas.core.fs.FileExists(AFileName);  // 委托给 fs 模块
end;
```

---

## DD-8: 编译器指令设计

**日期**: 2026-06
**状态**: 已采纳

### 背景

编译器需要知道哪些类型是根类型（TObject）、哪些枚举是类型种类（TTypeKind）。需要一种机制让内核声明这些特殊角色。

### 选项

1. **魔术名称**：编译器通过类型名识别（如 `TObject` 自动成为根类）
2. **注解指令**：使用编译器指令标注（如 `{$compiler_root}`）
3. **配置文件**：外部配置文件指定特殊类型

### 选择

**选项 2：注解指令**

```pascal
{$compiler_root}
TObject = class
  // ...
end;

{$compiler_type_kind}
TTypeKind = (
  // ...
end;
```

### 后果

- ✅ 明确声明，不依赖魔术名称
- ✅ 可以在内核中看到哪些类型是特殊的
- ✅ 编译器可以验证指令的正确使用
- ⚠️ 编译器需要支持这些指令
- ⚠️ 指令使用不当会导致编译错误

### 指令列表

| 指令 | 作用 | 当前使用 |
|------|------|---------|
| `{$compiler_root}` | 标记编译器根类 | `TObject` |
| `{$compiler_type_kind}` | 标记类型种类枚举 | `TTypeKind` |
| `compilerproc` | 标记编译器内部函数 | 119 个 `fpc_*` 函数 |

---

## DD-9: 异常模型选择

**日期**: 2026-06
**状态**: 已采纳

### 背景

异常处理是运行时的关键功能。需要决定使用哪种异常模型。

### 选项

1. **setjmp/longjmp**：C 风格的非本地跳转
2. **Table-based exceptions**：DWARF/SEH 风格的表驱动异常
3. **混合方案**：stage0 用 setjmp/longjmp，未来迁移到 table-based

### 选择

**选项 3：混合方案**

- **stage0**：使用 setjmp/longjmp（实现简单，兼容性好）
- **未来**：迁移到 table-based exceptions（性能更好，零成本异常）

### 后果

- ✅ stage0 可以快速实现异常处理
- ✅ 未来可以无缝迁移到 table-based
- ⚠️ setjmp/longjmp 有性能开销（每次 try 都要保存栈）
- ⚠️ 迁移需要修改编译器和运行时

### 当前状态

- np_setjmp/np_longjmp 已定义（comp.inc）
- np_try_push/np_try_pop 已定义
- 运行时实现待 S10

---

## DD-10: 内存管理器接口设计

**日期**: 2026-06
**状态**: 已采纳

### 背景

nextPas 需要一个可插拔的内存管理器接口，允许用户替换默认分配器。

### 选项

1. **全局函数**：直接调用全局内存函数（GetMem/FreeMem）
2. **接口/记录**：通过 TMemoryManager 记录传递回调
3. **虚方法**：通过虚方法调用内存管理器

### 选择

**选项 2：TMemoryManager 记录**

```pascal
TMemoryManager = record
  NeedLock: Boolean;
  GetMem: TGetMem;
  FreeMem: TFreeMem;
  // ... 其他回调
end;
```

### 后果

- ✅ 与 FPC 的内存管理器接口兼容
- ✅ 可以在运行时切换内存管理器
- ✅ 回调方式性能好（直接函数指针调用）
- ⚠️ 需要全局变量保存当前内存管理器
- ⚠️ 多线程时需要考虑锁（NeedLock 字段）

### 使用方式

```pascal
var
  LMemMgr: TMemoryManager;
begin
  LMemMgr.GetMem := @MyGetMem;
  LMemMgr.FreeMem := @MyFreeMem;
  // ...
  SetMemoryManager(LMemMgr);
end;
```

---

## DD-11: 接口引用计数模型

**日期**: 2026-06
**状态**: 已采纳

### 背景

接口（IUnknown）需要引用计数来管理生命周期。需要决定引用计数的实现方式。

### 选项

1. **编译器自动插入**：编译器自动在赋值和作用域结束时插入 AddRef/Release
2. **手动管理**：程序员手动调用 _AddRef/_Release
3. **混合方案**：接口变量自动管理，原始指针手动管理

### 选择

**选项 1：编译器自动插入**

```pascal
var
  LIntf: IMyInterface;
begin
  LIntf := TMyClass.Create;  // 编译器插入 _AddRef
  // ...
end;  // 编译器插入 _Release
```

### 后果

- ✅ 程序员不需要手动管理接口生命周期
- ✅ 减少内存泄漏和悬挂指针
- ⚠️ 编译器需要正确插入 AddRef/Release
- ⚠️ 循环引用需要程序员自己处理（弱引用）

### 编译器生成的代码

```pascal
// LIntf := TMyClass.Create;
// 编译为：
LIntf := TMyClass.Create;
np_intf_addref(Pointer(LIntf));  // _AddRef

// 作用域结束
// 编译为：
np_intf_release(Pointer(LIntf));   // _Release
LIntf := nil;
```

---

## DD-12: 线程模型选择

**日期**: 2026-06
**状态**: 已采纳

### 背景

线程是现代程序的基本需求。需要决定线程模型的设计。

### 选项

1. **直接映射 OS 线程**：TThread 直接映射到 pthread/Windows Thread
2. **绿色线程**：用户态线程调度
3. **混合方案**：TThread 映射 OS 线程，但提供协程支持

### 选择

**选项 1：直接映射 OS 线程**

```pascal
TThread = class
  FThreadID: TThreadID;
  FHandle: Pointer;
  // ...
end;
```

### 后果

- ✅ 与 FPC 的线程模型兼容
- ✅ 可以利用 OS 的线程调度和多核
- ✅ 实现简单（直接调用 pthread/Windows API）
- ⚠️ 线程创建/销毁有 OS 开销
- ⚠️ 大量线程时需要考虑线程池

### 线程安全保证

- TThread 方法是线程安全的
- TRTLCriticalSection 是线程安全的
- InterlockedIncrement/Decrement 是原子操作
- 全局变量需要程序员自己保护

---

## DD-13: I/O 模型设计

**日期**: 2026-06
**状态**: 已采纳

### 背景

文件 I/O 是基本功能。需要决定 I/O 模型的设计。

### 选项

1. **FPC 兼容**：使用 TFileRec/TTextRec，兼容 FPC 的文件操作
2. **现代流模型**：使用 IStream 接口
3. **混合方案**：保留 FPC 兼容，但提供 IStream 作为高级接口

### 选择

**选项 1 + 3 混合**

- **底层**：TFileRec/TTextRec 兼容 FPC 文件操作
- **高层**：IStream 接口由 `nextpas.core.io` 模块提供

### 后果

- ✅ 已有的 FPC 代码可以无缝迁移
- ✅ 高层代码可以使用现代 IStream 接口
- ⚠️ 需要维护两套 I/O 接口
- ⚠️ TFileRec/TTextRec 是平台相关的

### 分层设计

```
应用层:    IStream (nextpas.core.io)
           ↓
兼容层:    Read/Write/BlockRead/BlockWrite (system)
           ↓
平台层:    platform.io.Read/Write (nextpas.core.platform)
```

---

## DD-14: ABI 稳定性等级

**日期**: 2026-07
**状态**: 已采纳

### 背景

需要明确哪些 ABI 元素是稳定的，哪些可以修改。

### 稳定性等级

| 等级 | 含义 | 修改条件 |
|------|------|---------|
| **冻结** | 不得修改 | 无 |
| **稳定** | 只在大版本修改 | 需要迁移指南 |
| **实验** | 可以修改 | 需要通知 |
| **内部** | 随时修改 | 无需通知 |

### 当前等级

| 区域 | 等级 | 理由 |
|------|------|------|
| VMT 布局常量 | **冻结** | FPC 二进制兼容 |
| fpc_* 签名 | **冻结** | 编译器代码生成依赖 |
| TMemoryManager 回调 | **冻结** | 已有代码依赖 |
| TTypeInfo/TTypeData | **冻结** | RTTI 运行时依赖 |
| TTypeKind 枚举值 | **冻结** | 序列化兼容 |
| np.system.* 契约 | **冻结** | 编译器/运行时契约 |
| 门面函数签名 | **稳定** | 用户代码依赖 |
| 内部实现 | **内部** | 可以自由修改 |

---

## DD-15: 测试策略

**日期**: 2026-06
**状态**: 已采纳

### 背景

需要决定 system kernel 的测试策略。

### 测试类型

1. **源码契约测试**：验证文档存在、token 存在、边界检查
2. **编译测试**：验证 FPC 和 nextPas 都能编译
3. **运行时测试**：验证类型和函数的行为正确
4. **集成测试**：验证与编译器的集成

### 测试套件

```
test_system_facade              — 根门面测试
test_system_source_contracts    — 源码契约边界检查（shell 脚本）
test_system_typinfo_minimal     — TypInfo 最小门面测试
test_system_sysutils_minimal    — SysUtils 最小门面测试
```

### 后果

- ✅ 每个文档变更有对应的测试验证
- ✅ 边界违规会被测试拦截
- ✅ 可以自信地重构
- ⚠️ 源码契约测试是 shell 脚本，维护成本较高
- ⚠️ 需要定期运行测试确保不回归

### 运行测试

```bash
make -C core/tests/nextpas.core.system clean test
```
