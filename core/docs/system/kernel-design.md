# System Kernel Design

## 架构总览

system 内核是 nextPas 编译器的**唯一类型来源**。它定义了编译器需要的所有根类型（TObject、TClass、TTypeKind）和运行时契约。

### 双编译器架构

```
nextpas.core.system.pas
├── {$IFDEF FPC}
│   └── fpc.inc              ← FPC 路径：re-export FPC System 类型
└── {$ELSE}
    └── kernel.inc           ← nextPas 路径：完整内核定义
        ├── base.inc         ← 基本类型 (SizeInt, TBytes, Variant, C ABI)
        ├── str.inc          ← 字符串类型 (ShortString, AnsiString, ...)
        ├── intf.inc         ← 接口类型 (IUnknown, TGUID, TInterfaceEntry)
        ├── cls.inc          ← 类类型 (TObject, TClass, VMT)
        ├── rtti.inc         ← RTTI 类型 (TTypeKind, TTypeInfo, TTypeData)
        ├── except.inc       ← 异常类 (Exception, EAbort, ...)
        ├── mem.inc          ← 内存管理 (FreeAndNil, ZeroMem, Supports)
        ├── memmgr.inc       ← 内存管理器接口 (TMemoryManager, GetMemoryManager)
        ├── lifecycle.inc    ← 程序生命周期 (InitModule, FinalizeModule)
        ├── endian.inc       ← 字节序转换 (SwapEndian, BEtoN, LEtoN)
        ├── barrier.inc      ← 内存屏障 (ReadBarrier, WriteBarrier, Prefetch)
        ├── intrinsics.inc   ← 内建函数 (FillByte, IndexChar, CompareChar, MemPos)
        ├── thread.inc       ← 线程类型 (TThread, TRTLCriticalSection, BeginThread)
        ├── io.inc           ← I/O 类型 (Text, File, TFileRec, TTextRec, Read/Write)
        └── comp.inc         ← 编译器内部函数 (fpc_* 系列)
```

### 依赖规则

```
base.inc ← str.inc ← intf.inc ← cls.inc
                                      ↓
                              rtti.inc ← except.inc
                                      ↓
                              mem.inc ← memmgr.inc ← lifecycle.inc
                                      ↓
                              endian.inc ← barrier.inc ← intrinsics.inc
                                      ↓
                              thread.inc ← io.inc ← comp.inc
```

- 只向下依赖，禁止循环依赖
- kernel.inc 有零外部依赖（不 uses 任何 nextpas.core 单元）
- 所有类型在 kernel 内部自足

### 编译器指令

| 指令 | 位置 | 含义 |
|------|------|------|
| `{$compiler_root}` | cls.inc: TObject | 标记编译器根类 |
| `{$compiler_type_kind}` | rtti.inc: TTypeKind | 标记类型种类枚举 |

### VMT 布局

VMT 常量必须与 FPC 布局完全匹配，确保 ABI 兼容：

```
vmtInstanceSize = 0                    ← 实例大小
vmtParent = SizeOf(SizeInt) * 2        ← 父类指针
vmtClassName = SizeOf(SizeInt) * 3     ← 类名指针
...
vmtGetInterfaceStrong = SizeOf(SizeInt) * 27  ← 最后一个槽位
```

### 文件清单

| 文件 | 行数 | 职责 | 状态 |
|------|------|------|------|
| fpc.inc | 72 | FPC 类型 re-export | ✅ 完成 |
| kernel.inc | 35 | nextPas 内核入口 | ✅ 完成 |
| base.inc | 121 | 基本类型 + Variant + TBytes | ✅ 完成 |
| str.inc | 28 | 字符串类型 | ✅ 完成 |
| intf.inc | 63 | 接口类型 | ✅ 完成 |
| cls.inc | 315 | 类类型 + VMT | ✅ 完成 |
| rtti.inc | 151 | RTTI 类型 | ✅ 完成 |
| except.inc | 140 | 异常类 | ✅ 完成 |
| mem.inc | 190 | 内存管理 | ✅ 完成 |
| memmgr.inc | 105 | 内存管理器接口 | ✅ 完成 |
| lifecycle.inc | 32 | 程序生命周期 | ✅ 完成 |
| endian.inc | 281 | 字节序转换 | ✅ 完成 |
| barrier.inc | 46 | 内存屏障 | ✅ 完成 |
| intrinsics.inc | 266 | 内建函数 | ✅ 完成 |
| thread.inc | 215 | 线程类型 | ✅ 完成 |
| io.inc | 259 | I/O 类型 | ✅ 完成 |
| comp.inc | 294 | 编译器内部函数 | ✅ 完成 |
| **总计** | **3391** | **17 个 .inc 文件** | **✅ S8 完成** |

### 门面文件

| 文件 | 行数 | 职责 | 状态 |
|------|------|------|------|
| system.pas | ~200 | 根门面 (re-export 基础类型/常量) | ✅ 完成 |
| typinfo.pas | 103 | RTTI 门面 (PTypeInfo/TTypeKind/GetPropInfo/GetEnumName/GetEnumValue) | ✅ 完成 |
| sysutils.pas | 358 | SysUtils 门面 (40+ 函数) | ✅ 完成 |
| errors.pas | ~80 | 异常分类门面 (38 exception + 18 error category) | ✅ 完成 |

### 与 FPC System 的对应关系

| FPC System 表面 | nextPas 内核 | 说明 |
|-----------------|-------------|------|
| TObject, TClass | cls.inc | 完全对应 |
| TTypeKind, TTypeInfo | rtti.inc | 完全对应 |
| SizeInt, SizeUInt, PtrInt, ... | base.inc | 完全对应 |
| ShortString, AnsiString, ... | str.inc | 完全对应 |
| IUnknown, TGUID, ... | intf.inc | 完全对应 |
| Exception, EAbort, ... | except.inc | 完全对应 |
| GetMem, FreeMem, ... | mem.inc | 完全对应 |
| fpc_* 系列 | comp.inc | 完全对应 |
| InitializeArray, FinalizeArray, ... | rtti.inc | 完全对应 |
| FreeAndNil, ZeroMem, ... | mem.inc | 完全对应 |
| Variant, TVarType, TVarData | base.inc | 完全对应 |
| TBytes, TCharArray | base.inc | 完全对应 |
| TMemoryManager, TMemoryManagerEx | memmgr.inc | 完全对应 |
| InitModule, FinalizeModule | lifecycle.inc | 完全对应 |
| SwapEndian, BEtoN, LEtoN | endian.inc | 完全对应 |
| ReadBarrier, WriteBarrier, Prefetch | barrier.inc | 完全对应 |
| FillByte, IndexChar, CompareChar | intrinsics.inc | 完全对应 |
| TThread, TRTLCriticalSection | thread.inc | 完全对应 |
| Text, File, TFileRec, TTextRec | io.inc | 完全对应 |

### 门面对应关系

| FPC 门面 | nextPas 门面 | 覆盖范围 |
|----------|-------------|----------|
| TypInfo | typinfo.pas | PTypeInfo, TTypeKind, PTypeData, TTypeData, GetPropInfo, GetEnumName, GetEnumValue |
| SysUtils | sysutils.pas | 40+ 函数：数值转换/字符串/日期时间/文件系统/路径/环境变量 |
| System (异常) | errors.pas | 38 exception + 18 error category |

### 当前状态

**S8 Kernel Surface Completeness 全部完成** (2026-07-07):

1. **内核完整性**: 17 个 .inc 子模块覆盖 FPC System 全部表面
2. **门面完整性**: TypInfo (7 symbols) + SysUtils (40+ 函数) + Errors (56 aliases)
3. **测试覆盖**: 126 测试（kernel 92 + facade 19 + typinfo 9 + sysutils 6），0 泄漏
4. **总代码量**: 3391 行内核 + 4 个门面文件

kernel 测试覆盖 (92 tests):
- Swap (6): Word/SmallInt/DWord/LongInt/QWord/Int64
- Endian (30): SwapEndian(6) + HTonN/NToHs(4) + BEtoN/LEtoN/NtoBE/NtoLE for Word/DWord/LongInt/Int64/QWord (20)
- Variant (11): VarType(4) + VarIsNull(2) + VarIsEmpty(2) + VarIsClear(3)
- Intrinsics (8): FillByte/FillDWord/FillQWord(3) + IndexChar/Byte/Word/DWord/QWord(5)
- Compare (4): CompareChar/Byte/Word/DWord
- Memory (12): MoveChar0 + MemPos + StackTop + GetMem/FreeMem + GetMem zero + AllocMem + ReAllocMem + ReAllocMem nil + MemSize + FillMem + CopyMem + CompareMem(2)
- Assigned (3): pointer + object + interface nil
- Thread (4): CriticalSection lifecycle/TryEnter/reentrancy + TRTLCriticalSection size
- Interlocked (5): Increment/Decrement/Exchange/CompareExchange/ExchangeAdd
- IO (1): fmClosed/fmInput/fmOutput/fmInOut constants
- Type sizes (5): Base types + TGUID + TVarData size + TVarData layout + Variant type constants
- SafeFree (2): object + nil

### 下一步

内核定义完成。下一步是编译器集成：
1. 编译器识别 `{$compiler_root}` 指令
2. 编译器从内核读取类型信息
3. 编译器使用内核的 VMT 布局
4. 编译器识别 `{$compiler_type_kind}` 指令

完整路线图见 `goal-tree.md` (S9-S12)。
