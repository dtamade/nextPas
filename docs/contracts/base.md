# nextpas.core.base 代码契约

> 模块路径: `core/src/nextpas.core.base.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

框架根模块。定义所有模块共享的基础类型、异常层次、泛型工具类型、设计契约断言和哈希函数。
只依赖 `nextpas.core.exception`，是整个 core/ 的最底层。

---

## 接口签名

### 框架标识

```pascal
const
  NEXTPAS_CORE_NAME = 'nextpas.core';
  NEXTPAS_CORE_VERSION = '1.0.0';
  MAX_SIZE_INT = High(SizeInt);
  MAX_SIZE_UINT = High(SizeUInt);
  MIN_SIZE_INT = Low(SizeInt);
  SIZE_PTR = SizeOf(Pointer);
```

### 平台整数类型

```pascal
type
  SizeInt, SizeUInt, PtrInt, PtrUInt, NativeInt, NativeUInt;
```

64 位平台为 Int64/UInt64，32 位平台为 LongInt/LongWord。

### 基础集合类型

```pascal
type
  TBytes = array of Byte;
  TStringArray = array of string;
```

### C ABI 类型

```pascal
type
  cint, cuint, cshort, cushort, clong, culong,
  cchar, cschar, cuchar, cfloat, cdouble, cbool,
  cint64, cuint64, csize_t;
```

与 C ABI 对齐的类型定义。`csize_t = SizeUInt`。

### 异常层次

所有框架异常继承自 `ECore` (= `ENextPasError`)。

| 异常类 | TErrorCategory | 语义 |
|--------|----------------|------|
| `EInvariantViolation` | ecInternal | 不变量违反 |
| `EArgumentNil` | ecInvalidArgument | nil 参数 |
| `EInvalidArgument` | ecInvalidArgument | 非法参数 |
| `EInvalidResult` | ecInternal | 非法返回值 |
| `EEmptyCollection` | ecInvalidOperation | 空集合操作 |
| `EInvalidState` | ecInvalidOperation | 非法状态 |
| `EOutOfRange` | ecInvalidArgument | 越界访问 |
| `ENotSupported` | ecNotSupported | 不支持的操作 |
| `ENotCompatible` | ecInvalidArgument | 不兼容的参数 |
| `EInvalidOperation` | ecInvalidOperation | 非法操作 |
| `EOverflow` | ecInvalidArgument | 溢出 |
| `EOutOfMemoryError` | (inherited) | OOM |
| `ETimeoutError` | (inherited) | 超时 |

### 泛型回调类型

```pascal
type
  TProc = reference to procedure;
  TProc1<T> = reference to procedure(const A: T);
  TProc2<T1, T2> = reference to procedure(const A1: T1; const A2: T2);
  TFunc0<TResult> = reference to function: TResult;
  TFunc1<T, TResult> = reference to function(const A: T): TResult;
  TFunc2<T1, T2, TResult> = reference to function(const A1: T1; const A2: T2): TResult;
  TPredicate<T> = reference to function(const A: T): Boolean;
```

### 泛型工具类型

```pascal
type
  TPair<TKey, TValue> = record
    class function Create(AKey, AValue): TPair; static; inline;
  end;

  TComparer<T> = reference to function(const A, B: T): Int32;
  TEqualityCheck<T> = reference to function(const A, B: T): Boolean;
  THasher<T> = reference to function(const A: T): THashCode;
```

### 泛型值语义

```pascal
type
  TNullable<T> = record
    class function Some(AValue: T): TNullable; static;
    class function None: TNullable; static;
    function ValueOr(ADefault: T): T; inline;
    property HasValue: Boolean;
    property IsNone: Boolean;
    property Value: T;  // 无值时 raise EInvalidState
  end;

  TOption<T> = record
    class function Some(AValue: T): TOption; static;
    class function None: TOption; static;
    function UnwrapOr(ADefault: T): T; inline;
    property IsSome: Boolean;
    property IsNone: Boolean;
    property Unwrap: T;  // 无值时 raise EInvalidState
  end;

  TResult<T, E> = record
    class function Ok(AValue: T): TResult; static;
    class function Err(AError: E): TResult; static;
    function UnwrapOr(ADefault: T): T; inline;
    property IsOk: Boolean;
    property IsErr: Boolean;
    property Unwrap: T;      // 非 Ok 时 raise EInvalidState
    property UnwrapErr: E;   // 非 Err 时 raise EInvalidState
  end;
```

### TByteSpan (非拥有字节视图)

```pascal
type
  TByteSpan = record
    Data: PByte;
    Len: SizeUInt;
    class function Create(AData: PByte; ALen: SizeUInt): TByteSpan; static;
    class function FromBytes(ABytes: TBytes): TByteSpan; static;
    class function Empty: TByteSpan; static;
    function IsEmpty: Boolean; inline;
    function Slice(AOffset, ALength: SizeUInt): TByteSpan;
    function GetByte(AIndex: SizeUInt): Byte; inline;
    property Items[AIndex]: Byte; default;
  end;
```

### 设计契约断言

```pascal
procedure Require(ACondition: Boolean; AMessage = 'precondition violated');
procedure Ensure(ACondition: Boolean; AMessage = 'postcondition violated');
procedure CheckState(ACondition: Boolean; AMessage = 'invalid state');
procedure Unreachable(AMessage = 'unreachable code reached');
```

### 哈希函数 (FNV-1a)

```pascal
function HashBytes(AData: PByte; ALen: SizeUInt): THashCode;
function HashString(AValue: string): THashCode;
function HashString(AValue: UnicodeString): THashCode; overload;
function HashInteger(AValue: Int64): THashCode;
function HashPointer(AValue: Pointer): THashCode;
```

### C 互操作

```pascal
function StrComp(A, B: PAnsiChar): Integer;
```

---

## 前置条件

1. `TByteSpan.Create(AData, ALen)`: ALen > 0 时 AData 必须非 nil
2. `TByteSpan.Slice`: offset + length <= span length
3. `TByteSpan.GetByte`: index < Len
4. `HashBytes`: ALen > 0 时 AData 必须非 nil
5. `Require`: ACondition 为 true（否则 raise EInvalidArgument）
6. `Ensure`: ACondition 为 true（否则 raise EInvariantViolation）
7. `CheckState`: ACondition 为 true（否则 raise EInvalidState）

---

## 后置条件

1. `TNullable.Value`: HasValue 为 true 时返回存储值
2. `TOption.Unwrap`: IsSome 为 true 时返回存储值
3. `TResult.Unwrap`: IsOk 为 true 时返回存储值
4. `TResult.UnwrapErr`: IsErr 为 true 时返回错误值
5. `HashBytes`: 返回 FNV-1a 32 位哈希
6. `StrComp(A, B)`: A = B 时返回 0; A = nil 返回 -1; B = nil 返回 1; 否则按字典序

---

## 错误语义

| 场景 | 行为 |
|------|------|
| TByteSpan.Create(len>0, nil) | raise EArgumentNil |
| TByteSpan.Slice 越界 | raise EOutOfRange |
| TByteSpan.GetByte 越界 | raise EOutOfRange |
| HashBytes(len>0, nil) | raise EArgumentNil |
| TNullable.Value 无值 | raise EInvalidState |
| TOption.Unwrap 无值 | raise EInvalidState |
| TResult.Unwrap 非 Ok | raise EInvalidState |
| TResult.UnwrapErr 非 Err | raise EInvalidState |
| Require(false) | raise EInvalidArgument |
| Ensure(false) | raise EInvariantViolation |
| CheckState(false) | raise EInvalidState |
| Unreachable | raise EInvariantViolation |

---

## 线程安全

- 所有类型为值类型(record)，无线程安全问题
- 泛型回调类型为引用类型，但无共享状态
- 哈希函数为纯函数，可安全并发调用
- StrComp 为纯函数，可安全并发调用

---

## 内存管理

- TBytes 为动态数组，引用计数自动管理
- TByteSpan 为非拥有视图，不分配/释放内存
- TNullable/TOption/TResult 为值类型 record，栈分配
- TPair 为值类型 record，栈分配

---

## 测试覆盖

### 测试套件

| 套件 | 路径 | 范围 |
|------|------|------|
| test_base | `core/tests/nextpas.core.base/test_base/` | 核心类型和函数 |
| test_base_contract | `core/tests/nextpas.core.base/test_base_contract/` | 契约断言 |
| test_base_unicode_hash | `core/tests/nextpas.core.base/test_base_unicode_hash/` | Unicode 哈希 |
| test_base_utils_source_contracts | `core/tests/nextpas.core.base/test_base_utils_source_contracts/` | 工具函数源契约 |

---

## 依赖关系

- 依赖: `nextpas.core.exception`
- 被依赖: 几乎所有 core/ 模块

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
