# nextpas.core.base 代码契约

**模块路径**：`core/src/nextpas.core.base*.pas`（3 个源文件：`base.pas` / `base.utils.pas` / `base.pathvalid.pas` 桩，~1100 行）
**层级**：L0（根模块，仅依赖 FPC RTL + `nextpas.core.exception`；`pathvalid` 能力由 L1 `nextpas.core.bytes.pathvalid` 单源实现，本层仅桩转发）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-30
**版本**：1.1

---

## 1. 接口契约

### 1.1 框架标识

```pascal
const
  NEXTPAS_CORE_NAME = 'nextpas.core';
  NEXTPAS_CORE_VERSION = '0.1.0';
```

### 1.2 规范类型别名

```pascal
type
  SizeInt   = {$IFDEF CPU64} Int64 {$ELSE} LongInt {$ENDIF};
  SizeUInt  = {$IFDEF CPU64} UInt64 {$ELSE} LongWord {$ENDIF};
  PtrInt    = {$IFDEF CPU64} Int64 {$ELSE} LongInt {$ENDIF};
  PtrUInt   = {$IFDEF CPU64} UInt64 {$ELSE} LongWord {$ENDIF};
  NativeInt = {$IFDEF CPU64} Int64 {$ELSE} LongInt {$ENDIF};
  NativeUInt= {$IFDEF CPU64} UInt64 {$ELSE} LongWord {$ENDIF};
  TBytes = array of Byte;
  TStringArray = array of string;
  THashCode = UInt32;
```

### 1.3 C ABI 类型

```pascal
type
  cint = LongInt; cuint = LongWord; cshort = SmallInt; cushort = Word;
  clong = LongInt; culong = LongWord; cchar = Char; cschar = ShortInt;
  cuchar = Byte; cfloat = Single; cdouble = Double; cbool = Boolean;
  cint64 = Int64; cuint64 = UInt64; csize_t = SizeUInt;
```

### 1.4 异常层级

```
ENextPasError (nextpas.core.exception)
  ├── EInvariantViolation   (ecInternal)
  ├── EArgumentNil          (ecInvalidArgument)
  ├── EEmptyCollection      (ecInvalidOperation)
  ├── EInvalidArgument      (ecInvalidArgument)
  ├── EInvalidResult        (ecInternal)
  ├── ETimeoutError         (alias to exception.ETimeoutError)
  ├── EInvalidState         (ecInvalidOperation)
  ├── EOutOfRange           (ecInvalidArgument)
  ├── ENotSupported         (ecNotSupported)
  ├── ENotCompatible        (ecInvalidArgument)
  ├── EInvalidOperation     (ecInvalidOperation)
  ├── EOutOfMemoryError     (alias to exception.EOutOfMemoryError)
  ├── EOutOfMemory          (alias to exception.EOutOfMemory)
  └── EOverflow             (ecInvalidArgument)
```

所有具体异常类实现 `Create(const AMessage: string)` + `DefaultCategory`。

### 1.5 泛型回调

```pascal
type
  TProc = reference to procedure;
  generic TProc1<T> = reference to procedure(const A: T);
  generic TProc2<T1, T2> = reference to procedure(const A1: T1; const A2: T2);
  generic TFunc0<TResult> = reference to function: TResult;
  generic TFunc1<T, TResult> = reference to function(const A: T): TResult;
  generic TFunc2<T1, T2, TResult> = reference to function(const A1: T1; const A2: T2): TResult;
  generic TPredicate<T> = reference to function(const A: T): Boolean;
```

### 1.6 泛型工具类型

| 类型 | 用途 | 方法 |
|------|------|------|
| `TPair<TKey, TValue>` | 键值对 record | `Create(AKey, AValue): TPair` (static) |
| `TComparer<T>` | 排序比较器 | `(A, B: T): Int32` |
| `TEqualityCheck<T>` | 相等检查 | `(A, B: T): Boolean` |
| `THasher<T>` | 哈希函数 | `(A: T): THashCode` |
| `TRandomGeneratorFunc` | 随机数回调 | `(ARange: Int64; AData: Pointer): Int64` |

### 1.7 值语义泛型

| 类型 | 用途 | 核心方法 |
|------|------|----------|
| `TNullable<T>` | 可选值 | `Some(AValue)`, `None`, `ValueOr(ADefault)`, `HasValue`, `IsNone` |
| `TOption<T>` | 可选值（Rust 风格） | `Some(AValue)`, `None`, `UnwrapOr(ADefault)`, `IsSome`, `IsNone` |
| `TResult<T, E>` | 结果类型 | `Ok(AValue)`, `Err(AError)`, `UnwrapOr(ADefault)`, `IsOk`, `IsErr` |

**不变量**：
- `TNullable.Value` / `TOption.Unwrap` 无值时抛 `EInvalidState`
- `TResult.Unwrap` 非 OK 时抛 `EInvalidState`
- `TResult.UnwrapErr` 非 Err 时抛 `EInvalidState`

### 1.8 TByteSpan（非拥有字节视图）

```pascal
TByteSpan = record
  Data: PByte;    // 指向外部内存，不拥有
  Len: SizeUInt;
end;
```

| 方法 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `Create(AData, ALen)` | ALen=0 或 AData≠nil | 设置 Data/Len | AData=nil 且 ALen>0 时抛 EArgumentNil |
| `FromBytes(ABytes)` | 无 | Data=@ABytes[0] 或 nil | 不抛异常 |
| `Empty` | 无 | Data=nil, Len=0 | 不抛异常 |
| `Slice(AOffset, ALen)` | Data≠nil, 范围合法 | 子视图 | EArgumentNil / EOutOfRange |
| `GetByte(AIndex)` | Data≠nil, AIndex<Len | 返回字节 | EArgumentNil / EOutOfRange |

### 1.9 契约断言

```pascal
procedure Require(ACondition: Boolean; AMessage: string);    // → EInvalidArgument
procedure Ensure(ACondition: Boolean; AMessage: string);     // → EInvariantViolation
procedure CheckState(ACondition: Boolean; AMessage: string); // → EInvalidState
procedure Unreachable(AMessage: string);                     // → EInvariantViolation
```

### 1.10 哈希函数（FNV-1a）

```pascal
function HashBytes(AData: PByte; ALen: SizeUInt): THashCode;
function HashString(AValue: string): THashCode;
function HashString(AValue: UnicodeString): THashCode; overload;
function HashInteger(AValue: Int64): THashCode;
function HashPointer(AValue: Pointer): THashCode;
```

| 函数 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `HashBytes` | ALen=0 或 AData≠nil | FNV-1a 哈希 | EArgumentNil |
| `HashString` | 无 | FNV-1a 哈希 | 不抛异常 |
| `HashInteger` | 无 | FNV-1a 哈希 | 不抛异常 |
| `HashPointer` | 无 | FNV-1a 哈希 | 不抛异常 |

### 1.11 内存工具（nextpas.core.base.utils；inline/零拷贝，单源复用 `bytes.ops` 语义）

```pascal
procedure FreeAndNil(var AObj);       // 先置 nil 再 Free（防止析构重入）
procedure SafeFree(var AObj); inline; // = FreeAndNil（inline 转发）
procedure ZeroMem(ADst: Pointer; ASize: SizeUInt); inline;
procedure FillMem(ADst: Pointer; ASize: SizeUInt; AValue: Byte); inline;
procedure CopyMem(ADst: Pointer; ASrc: Pointer; ASize: SizeUInt); inline;
function CompareMem(A, B: Pointer; ASize: SizeUInt): Boolean; inline;
function CompareBytesOrdered(A, B: Pointer; ALen, BLen: SizeUInt): Integer; inline;
function CompareBytesIgnoreCase(A, B: Pointer; ALen, BLen: SizeUInt): Integer; inline;
function HashFNV1aLower(A: Pointer; ALen: SizeUInt): UInt32; inline;
procedure ClearOutInterface(out AIntf);
```

| 函数 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `FreeAndNil` | 无 | AObj=nil, 旧对象 Free（先置 nil，资源释放不丢） | 不抛异常 |
| `SafeFree` | 无 | 同 FreeAndNil（inline） | 不抛异常 |
| `ZeroMem` | ASize=0 或 ADst≠nil | 填零 | EArgumentNil |
| `FillMem` | ASize=0 或 ADst≠nil | 填充值 | EArgumentNil |
| `CopyMem` | ASize=0 或 ADst,ASrc≠nil | 复制字节 | EArgumentNil |
| `CompareMem` | ASize=0 时返回 True | 逐字节比较 | 不抛异常 |
| `CompareBytesOrdered` | ALen/BLen=0 或 A,B≠nil | 字典序比较（-1/0/1） | EArgumentNil |
| `CompareBytesIgnoreCase` | ALen/BLen=0 或 A,B≠nil | 大小写不敏感比较（LowerTable） | EArgumentNil |
| `HashFNV1aLower` | ALen=0 或 A≠nil | FNV-1a 小写归一哈希 | EArgumentNil |
| `ClearOutInterface` | 无 | out 接口置 nil（释放旧引用） | 不抛异常 |

### 1.12 SizeUInt 安全算术

```pascal
function TryAddSizeUInt(ALeft, ARight: SizeUInt; var ASum: SizeUInt): Boolean;
function CheckedAddSizeUInt(ALeft, ARight: SizeUInt): SizeUInt;
function TryMulSizeUInt(ALeft, ARight: SizeUInt; var AProduct: SizeUInt): Boolean;
function CheckedMulSizeUInt(ALeft, ARight: SizeUInt): SizeUInt;
procedure CheckSizeRange(AOffset, ALength, ASize: SizeUInt);
```

| 函数 | 溢出行为 |
|------|----------|
| `TryAddSizeUInt` | 返回 False，不修改 ASum |
| `CheckedAddSizeUInt` | 抛 EOverflow |
| `TryMulSizeUInt` | 返回 False，不修改 AProduct |
| `CheckedMulSizeUInt` | 抛 EOverflow |
| `CheckSizeRange` | AOffset+ALength>ASize 时抛 EOutOfRange |

### 1.13 接口查询（inline 转发，失败清零 out 参数，资源释放不丢）

```pascal
procedure ClearOutInterface(out AIntf);
function Supports(AInstance: TObject; AIID: TGuid; out AIntf): Boolean;
function Supports(AInstance: IInterface; AIID: TGuid; out AIntf): Boolean;
```

- AInstance=nil 时返回 False 且 `ClearOutInterface(AIntf)`
- TObject 版本调用 GetInterface，失败清零
- IInterface 版本调用 QueryInterface，检查 S_OK，失败清零

### 1.14 L0 安全字符串/ C 互操作（inline/零拷贝，纯函数）

```pascal
function StrComp(A, B: PAnsiChar): Integer;
function IntToStr(AValue: Int64): string; overload;
function IntToStr(AValue: UInt64): string; overload;
function HexStr(AValue: UInt64; ADigits: Integer = 0): string;
```

| 函数 | 约定 | 异常 |
|------|------|------|
| `StrComp` | nil 安全：同指针→0，nil<非 nil；逐字节 `Ord(Byte)` 差值 | 不抛异常 |
| `IntToStr` | L0 安全实现，无 SysUtils 依赖；负数先取反再十进制 | 不抛异常 |
| `HexStr` | 16 字符大写表，`ADigits` 零填充 | 不抛异常 |

### 1.15 引用计数基类（L0 四件套内聚，替代 FPC TInterfacedObject）

```pascal
TRefCountedObject = class(TObject)
  function QueryInterface(constref Aiid: TGuid; out AObj): LongInt;
  function _AddRef: LongInt;
  function _Release: LongInt;
  procedure AfterConstruction; override;
  procedure BeforeDestruction; override;
  class function NewInstance: TObject; override;
  property RefCount: LongInt;
end;
```

- 布局：`[prelude:16][refcount:8][vmt:8][fields...]`，`FRefCount` 原子增减
- `NewInstance` 置 1，`AfterConstruction` 归零（栈构造路径），`_AddRef/_Release` 互锁计数，`_Release=0` 时 `Destroy`
- `BeforeDestruction` 若仍被持有则 `RunError(204)`，防止悬垂释放

### 1.16 路径校验（L1 单源复用，L0 仅桩转发；inline/零拷贝）

```pascal
function BytesValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;
function BaseValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;
```

- 真实实现位于 `nextpas.core.bytes.pathvalid`（L1），复用 `bytes.ops` 单源与 `text.utf8.UTF8IsValid` 单源（SIMD），零拷贝原串索引
- `nextpas.core.base.pathvalid` 仅桩保留（防 git 路径断裂），禁止在 L0 重实现；符合 L0-L3 单向依赖与四件套 `base ← intf ← 实现 ← 门面`
- 语义：Go `io/fs.ValidPath` 对等（UTF-8、非 rooted、段非空非 `.`/`..`、'\' 视为普通字符；`'.'` 仅 `AAllowRoot=True` 时合法）

---

## 2. 不变量

- **[INV-1]** `SizeInt`/`SizeUInt` 在 64 位平台为 `Int64`/`UInt64`，32 位为 `LongInt`/`LongWord`
- **[INV-2]** `TByteSpan.Data` 是非拥有指针（调用方管理生命周期）；`IsEmpty` 等价 `Len=0`
- **[INV-3]** `TByteSpan.Slice` 返回的子视图不能超出原始 Len；空切片返回 `Empty`
- **[INV-4]** `FreeAndNil`/`SafeFree` 先置 nil 再 Free，防止析构重入，资源释放不丢
- **[INV-5]** `FNV_OFFSET_BASIS_32 = 2166136261`, `FNV_PRIME_32 = 16777619`；`HashFNV1aLower` 经 `LowerTable` 归一后同参
- **[INV-6]** `CheckedAdd/Mul` 在溢出时抛 EOverflow，不返回垃圾值；`Try*` 溢出时不改输出
- **[INV-7]** 所有 hash 函数对空输入返回 `FNV_OFFSET_BASIS_32`
- **[INV-8]** `Supports` 失败必清零 out 接口，`ClearOutInterface` 置 nil，杜绝悬垂引用
- **[INV-9]** `StrComp` nil 安全；`IntToStr/HexStr` 为 L0 纯函数，无堆副作用
- **[INV-10]** `TRefCountedObject` 引用计数原子化，`_Release=0` 释放，`BeforeDestruction` 持有检错
- **[INV-11]** 路径校验单源在 L1 `bytes.pathvalid`，L0 不复刻实现，`BaseValidPath` inline 转发；符合 L0-L3 单向依赖与四件套

---

## 3. 错误处理

### 3.1 异常策略

| 场景 | 异常 |
|------|------|
| nil 指针 + 非零长度 | EArgumentNil |
| 空值访问 (TNullable.Value / TOption.Unwrap / TResult.Unwrap) | EInvalidState |
| 越界访问 (TByteSpan.Slice / GetByte) | EOutOfRange |
| 算术溢出 (CheckedAdd/Mul) | EOverflow |
| 前置条件违反 (Require) | EInvalidArgument |
| 后置条件违反 (Ensure) | EInvariantViolation |
| 不可达代码 (Unreachable) | EInvariantViolation |

### 3.2 Graceful degradation

| 场景 | 策略 |
|------|------|
| CompareMem(0 size) | 返回 True（空比较） |
| CompareMem(nil) | 返回 False |
| CompareBytesOrdered/IgnoreCase(nil, >0) | 抛 EArgumentNil |
| HashBytes(0 size) / HashFNV1aLower(0) | 返回 FNV_OFFSET_BASIS_32 |
| TryAdd/TryMul 溢出 | 返回 False，不修改输出参数 |
| Supports(nil) | 返回 False 且清零 out 接口 |
| StrComp(nil) | 按 nil<非 nil 返回 -1/1，同指针返 0 |

---

## 4. 线程安全

| 类型/函数 | 线程安全 | 说明 |
|-----------|----------|------|
| 类型别名 (SizeInt 等) | ✅ | 编译时常量 |
| 异常类 | ✅ | 每次 Create 新实例 |
| TNullable/TOption/TResult | ✅ | 值类型 record，栈上操作 |
| TByteSpan | ✅ | 非拥有视图，不修改底层数据 |
| Hash 函数 | ✅ | 纯函数，无共享状态 |
| 哈希常量 | ✅ | 编译时常量 (const) |
| Require/Ensure/CheckState | ✅ | 纯函数 |
| FreeAndNil/SafeFree/ClearOutInterface | ❌ | 调用方负责同步（先置 nil 语义保证释放不丢） |
| ZeroMem/FillMem/CopyMem | ❌ | 调用方负责同步 |
| CompareBytesOrdered/IgnoreCase/HashFNV1aLower | ✅ | 纯函数（LowerTable 只读） |
| StrComp/IntToStr/HexStr | ✅ | 纯函数 |
| TRefCountedObject | ❌ | 需外同步；原子计数仅保证计数本身 |
| BytesValidPath/BaseValidPath | ✅ | 纯函数，inline/零拷贝 |

---

## 5. 内存管理

### 5.1 所有权模型

```
TByteSpan: 非拥有视图
  ├── Data 指向外部内存（TBytes、静态 buffer 等）
  ├── 调用方保证 Data 生命周期覆盖 TByteSpan 使用期
  └── TByteSpan 不释放、不 realloc；IsEmpty/Slice/GetByte 零拷贝

泛型 record (TNullable/TOption/TResult/TPair):
  ├── 值语义，栈上拷贝
  ├── 不持有堆分配
  └── 线程退出时无资源泄漏

异常类:
  ├── Create 分配异常对象
  └── raise/except 自动管理生命周期

TRefCountedObject:
  ├── NewInstance→1，AfterConstruction 归零，_AddRef/_Release 原子计数
  └── _Release=0 时 Destroy；BeforeDestruction 持有检错（RunError 204）

路径校验:
  ├── 单源在 L1 bytes.pathvalid，L0 base.pathvalid 仅桩转发（inline）
  └── inline/零拷贝：原串内存直接索引，不落地 Copy
```

### 5.2 Leak-free 保证

- 所有 record 类型为值语义，无堆分配
- TByteSpan 非拥有，不分配/释放内存
- Hash 函数（含 HashFNV1aLower）为纯函数，无副作用
- FreeAndNil/SafeFree 的 nil 先置防止重入泄漏；ClearOutInterface/Supports 失败清零杜绝悬垂
- TRefCountedObject 原子计数+归零释放，BeforeDestruction 防悬垂

---

## 6. 测试覆盖

### 6.1 测试矩阵

| 子系统 | 测试文件 | 测试数 |
|--------|----------|--------|
| 基础类型 + 契约断言 + 哈希 | test_base | ~20 |
| 接口契约边界 | test_base_contract | ~15 |
| Unicode 哈希 | test_base_unicode_hash | ~5 |
| 源契约边界检查 | test_base_utils_source_contracts | shell 脚本 |
| **合计** | **4 个测试目录** | **~40** |

### 6.2 必须覆盖的场景

| 场景 | 测试文件 | 状态 |
|------|----------|------|
| 类型大小正确性 | test_base | ✅ |
| 异常构造 + DefaultCategory | test_base | ✅ |
| TByteSpan 创建/Slice/越界 | test_base_contract | ✅ |
| TByteSpan nil+非零长度 | test_base_contract | ✅ |
| TNullable/TOption/TResult | test_base | ✅ |
| Unwrap 空值异常 | test_base | ✅ |
| Hash 一致性 + 空输入 | test_base | ✅ |
| FreeAndNil nil 安全 | test_base | ✅ |
| ZeroMem/CopyMem nil 检查 | test_base_contract | ✅ |
| CheckedAdd/Mul 溢出 | test_base_contract | ✅ |
| TryAdd/TryMul 边界 | test_base_contract | ✅ |
| CheckSizeRange 越界 | test_base_contract | ✅ |
| Supports nil 安全 | test_base | ✅ |

### 6.3 覆盖率目标

- [x] 公开 API：100% 调用覆盖
- [x] 错误路径：100% 触发覆盖
- [x] 泛型实例化：核心类型覆盖

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本：完整六项契约 | Claude |
| 2026-08-30 | 1.1 | 跟随源码演进：补齐 TRefCountedObject/StrComp/IntToStr/HexStr/ClearOutInterface/CompareBytesOrdered/IgnoreCase/HashFNV1aLower，明确 pathvalid 复用 bytes.ops+text.utf8 单源 inline/零拷贝，同步 L0-L3/四件套与资源释放不丢语义 | Claude |
