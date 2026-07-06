# System Kernel Design

## 架构总览

system 内核是 nextPas 编译器的**唯一类型来源**。它定义了编译器需要的所有根类型（TObject、TClass、TTypeKind）和运行时契约。

### 双编译器架构

```
nextpas.core.system.pas
├── {$IFDEF FPC}
│   └── fpc.inc          ← FPC 路径：re-export FPC System 类型
└── {$ELSE}
    └── kernel.inc       ← nextPas 路径：完整内核定义
        ├── base.inc     ← 基本类型 (SizeInt, TBytes, C ABI)
        ├── str.inc      ← 字符串类型 (ShortString, AnsiString, ...)
        ├── intf.inc     ← 接口类型 (IUnknown, TGUID, TInterfaceEntry)
        ├── cls.inc      ← 类类型 (TObject, TClass, VMT)
        ├── rtti.inc     ← RTTI 类型 (TTypeKind, TTypeInfo, TTypeData)
        ├── except.inc   ← 异常类 (Exception, EAbort, ...)
        ├── mem.inc      ← 内存管理 (GetMem, FreeMem, ...)
        └── comp.inc     ← 编译器内部函数 (fpc_* 系列)
```

### 依赖规则

```
base.inc ← str.inc ← intf.inc ← cls.inc
                                      ↓
                              rtti.inc ← except.inc
                                      ↓
                              mem.inc ← comp.inc
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
| fpc.inc | 68 | FPC 类型 re-export | ✅ 完成 |
| kernel.inc | 25 | nextPas 内核入口 | ✅ 完成 |
| base.inc | 46 | 基本类型 | ✅ 完成 |
| str.inc | 28 | 字符串类型 | ✅ 完成 |
| intf.inc | 63 | 接口类型 | ✅ 完成 |
| cls.inc | 315 | 类类型 + VMT | ✅ 完成 |
| rtti.inc | 151 | RTTI 类型 | ✅ 完成 |
| except.inc | 140 | 异常类 | ✅ 完成 |
| mem.inc | 190 | 内存管理 | ✅ 完成 |
| comp.inc | 294 | 编译器内部函数 | ✅ 完成 |

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

### 下一步

内核定义完成。下一步是编译器集成：
1. 编译器识别 `{$compiler_root}` 指令
2. 编译器从内核读取类型信息
3. 编译器使用内核的 VMT 布局
