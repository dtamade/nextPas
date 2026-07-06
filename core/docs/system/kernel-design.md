# System Kernel Design

## 概述

`nextpas.core.system` 内核是编译器根类型的唯一事实来源。采用双编译器架构：
- **FPC 下**：`fpc.inc` re-export FPC 的 System 类型
- **nextPas 下**：`kernel.inc` 定义完整内核（TObject, TClass, TTypeKind 等）

## 双编译器架构

```
nextpas.core.system.pas
├── interface
│   ├── uses (nextpas.core.base, nextpas.core.base.utils, nextpas.core.system.errors)
│   ├── {$IFDEF FPC}
│   │   {$I nextpas.core.system.fpc.inc}     ← re-export FPC 类型
│   ├── {$ELSE}
│   │   {$I nextpas.core.system.kernel.inc}  ← nextPas 完整内核
│   ├── {$ENDIF}
│   └── type/const (公共别名)
└── implementation
```

## 文件结构

### fpc.inc（FPC 后端）

re-export FPC 的 System 类型，让其他 nextpas.core 单元可以通过 `nextpas.core.system` 导入：

| 类型 | 来源 |
|------|------|
| TObject, TClass | System.TObject, System.TClass |
| TTypeKind | System.TTypeKind |
| SizeInt, SizeUInt, PtrInt, PtrUInt | System.* |
| ShortString, AnsiString, WideString, UnicodeString | System.* |
| IUnknown, IInterface | System.* |
| TGUID | System.TGUID |
| PVmt, TVmt | System.PVmt, System.TVmt |
| TInterfaceEntry, TInterfaceTable | System.* |
| TMethod | System.TMethod |

### kernel.inc（nextPas 后端）

定义编译器根类型，包含 8 个子模块：

| 子模块 | 职责 |
|--------|------|
| base.inc | 基本类型（SizeInt, TBytes, C ABI 类型） |
| str.inc | 字符串类型（ShortString, AnsiString, WideString, UnicodeString） |
| intf.inc | 接口类型（TGUID, IUnknown, TInterfaceEntry, TMethod） |
| cls.inc | 类类型（VMT 常量, TVmt 记录, TObject, TClass） |
| rtti.inc | RTTI 类型（TTypeKind, TTypeInfo） |
| except.inc | 异常类（Exception, EAbort, EConvertError 等） |
| mem.inc | 内存操作（FreeAndNil, ZeroMem, Supports） |
| comp.inc | 编译器内部函数（fpc_* 系列） |

## 编译器根指令

kernel.inc 中使用两个编译器指令标记关键类型：

### {$compiler_root}

标记 TObject 为编译器根类。编译器从这里读取：
- 类的内存布局
- VMT 结构
- 方法分发机制

```pascal
{$compiler_root}
TObject = class
  // ...
end;
```

### {$compiler_type_kind}

标记 TTypeKind 为编译器类型种类枚举。编译器从这里读取：
- 类型分类（整数、浮点、字符串、类、接口等）
- RTTI 生成规则

```pascal
{$compiler_type_kind}
TTypeKind = (
  tkUnknown, tkInteger, tkChar, ...
);
```

## VMT 布局

VMT 常量必须匹配 FPC 布局，确保 ABI 兼容：

```pascal
const
  vmtInstanceSize = 0;
  vmtParent = SizeOf(SizeInt) * 2;
  vmtClassName = SizeOf(SizeInt) * 3;
  vmtDynamicTable = SizeOf(SizeInt) * 4;
  vmtMethodTable = SizeOf(SizeInt) * 5;
  vmtFieldTable = SizeOf(SizeInt) * 6;
  vmtTypeInfo = SizeOf(SizeInt) * 7;
  vmtInitTable = SizeOf(SizeInt) * 8;
  vmtAutoTable = SizeOf(SizeInt) * 9;
  vmtIntfTable = SizeOf(SizeInt) * 10;
  vmtMsgStrPtr = SizeOf(SizeInt) * 11;
  vmtDestroy = SizeOf(SizeInt) * 12;
  vmtNewInstance = SizeOf(SizeInt) * 13;
  vmtFreeInstance = SizeOf(SizeInt) * 14;
  vmtDefaultHandler = SizeOf(SizeInt) * 15;
  vmtAfterConstruction = SizeOf(SizeInt) * 16;
  vmtBeforeDestruction = SizeOf(SizeInt) * 17;
  vmtDefaultHandlerStr = SizeOf(SizeInt) * 18;
  vmtDispatch = SizeOf(SizeInt) * 19;
  vmtDispatchStr = SizeOf(SizeInt) * 20;
  vmtEquals = SizeOf(SizeInt) * 21;
  vmtGetHashCode = SizeOf(SizeInt) * 22;
  vmtToString = SizeOf(SizeInt) * 23;
  vmtSafeCallException = SizeOf(SizeInt) * 24;
  vmtGetInterface = SizeOf(SizeInt) * 25;
  vmtGetInterfaceWeak = SizeOf(SizeInt) * 26;
  vmtGetInterfaceStrong = SizeOf(SizeInt) * 27;
```

## TObject 实现

TObject 在 kernel.inc 中完整实现，包括：

- Create / Free / Destroy
- ClassType / ClassName / ClassParent / InstanceSize / InheritsFrom
- GetInterface / GetInterfaceEntry / GetInterfaceTable
- Equals / GetHashCode / ToString
- Dispatch / DefaultHandler
- AfterConstruction / BeforeDestruction

## 依赖规则

```
kernel.inc
├── base.inc     ← 无依赖
├── str.inc      ← 依赖 base.inc
├── intf.inc     ← 依赖 base.inc, str.inc
├── cls.inc      ← 依赖 base.inc, str.inc, intf.inc
├── rtti.inc     ← 依赖 base.inc, str.inc
├── except.inc   ← 依赖 base.inc, str.inc, cls.inc
├── mem.inc      ← 依赖 base.inc, cls.inc
└── comp.inc     ← 依赖 base.inc, str.inc
```

## FPC 编译验证

```bash
fpc -Mobjfpc -Sh -Fucore/src core/src/nextpas.core.system.pas
```

## 下一步

编译器收口后：
1. 修改预处理器识别 `{$compiler_root}` 和 `{$compiler_type_kind}` 指令
2. 修改语义分析器从内核读取类型信息
3. 删除编译器中的硬编码类型定义
