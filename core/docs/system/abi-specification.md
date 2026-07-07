# nextpas.core.system ABI Specification

> **版本**: 1.0.0-frozen (2026-07-05)
> **状态**: 冻结 — 所有 ABI 元素已锁定，不接受破坏性变更。

本规范定义 nextPas system kernel 的 Application Binary Interface，是编译器集成（S9）和运行时实现（S10）的**唯一权威输入**。

## 1. 数据模型

### 1.1 基本类型大小（linux-x86_64）

| 类型 | 大小 (bytes) | 对齐 | 备注 |
|------|-------------|------|------|
| `SizeInt` | 8 | 8 | `Int64` alias |
| `SizeUInt` | 8 | 8 | `QWord` alias |
| `PtrInt` | 8 | 8 | `Int64` alias |
| `PtrUInt` | 8 | 8 | `QWord` alias |
| `NativeInt` | 8 | 8 | `Int64` alias |
| `NativeUInt` | 8 | 8 | `QWord` alias |
| `Pointer` | 8 | 8 | 指针宽度 = `SizeOf(SizeInt)` |
| `CInt` | 4 | 4 | `LongInt` alias |
| `CLong` | 8 | 8 | `Int64` on 64-bit |
| `CChar` | 1 | 1 | `AnsiChar` alias |
| `Boolean` | 1 | 1 | |
| `ByteBool` | 1 | 1 | |
| `WordBool` | 2 | 2 | |
| `LongBool` | 4 | 4 | |

### 1.2 字符串类型内存布局

**ShortString** — 值类型，最大 255 字节：
```
offset 0:  Length (1 byte, current length)
offset 1:  Data (up to 255 bytes)
```

**AnsiString** — 引用计数，堆分配：
```
offset -12: CodePage (2 bytes)
offset -10: ElementSize (2 bytes)
offset -8:  RefCount (4 bytes, signed)
offset -4:  Length (4 bytes, signed)
offset  0:  Data (Length bytes)
```

**UnicodeString** — 引用计数，堆分配：
```
offset -12: CodePage (2 bytes, = 65001 for UTF-16)
offset -10: ElementSize (2 bytes, = 2)
offset -8:  RefCount (4 bytes, signed)
offset -4:  Length (4 bytes, signed, in chars)
offset  0:  Data (Length * 2 bytes, UTF-16LE)
```

**WideString** — COM 兼容，无引用计数：
```
offset -4:  Length (4 bytes, signed, in bytes)
offset  0:  Data (Length bytes, UTF-16LE)
```

### 1.3 动态数组内存布局

```
offset -8:  RefCount (4 bytes, signed)
offset -4:  Length (4 bytes, signed, in elements)
offset  0:  Data (Length * ElSize bytes)
```

ElSize 来自 TypeInfo，数组元素对齐 = `SizeOf(Element)`（最大 16，simd 可能扩展）。

### 1.4 Variant 内存布局

`TVarData` 在 FPC x86_64 上是 24 字节 packed record：
```
offset 0:  VType (2 bytes, TVarType = Word)
offset 2:  Reserved1 (2 bytes, alignment/padding)
offset 4:  Reserved2 (4 bytes)
offset 8:  Payload (8 bytes, 类型取决于 VType — VDouble/VCurrency/VDate/VString/VBoolean 等)
offset 16: Reserved3 (8 bytes)
```

注意：FPC 的 `TVarData` 在 x86_64 上是 24 字节（含对齐填充），比 COM VARIANT 的 16 字节大。
kernel.inc 中的 `TVarData` 定义应与 FPC 保持一致（24 字节）。

`VType` 值定义见 `base.inc`：
- `varEmpty`=0, `varNull`=1, `varSmallint`=2, `varInteger`=3
- `varSingle`=4, `varDouble`=5, `varCurrency`=6, `varDate`=7
- `varOleStr`=8, `varDispatch`=9, `varError`=10, `varBoolean`=11
- `varVariant`=12, `varUnknown`=13, `varDecimal`=14
- `varShortInt`=16, `varByte`=17, `varWord`=18, `varLongWord`=19
- `varInt64`=20, `varQWord`=21
- `varString`=$0100, `varAny`=$0101, `varUString`=$0102

### 1.5 TGUID 内存布局

```
offset 0:  D1 (4 bytes, LongWord, little-endian)
offset 4:  D2 (2 bytes, Word, little-endian)
offset 6:  D3 (2 bytes, Word, little-endian)
offset 8:  D4 (8 bytes, raw)
```
总大小：16 字节，对齐 = 4。

## 2. 对象模型 (VMT)

### 2.1 VMT 布局常量

VMT（Virtual Method Table）以负偏移挂在类实例指针的 `PPointer(Instance)^` 处。

| 常量 | 偏移 | 类型 | 语义 |
|------|------|------|------|
| `vmtInstanceSize` | 0 | `SizeInt` | 实例总大小（含 VMT 指针） |
| `vmtParent` | 16 | `Pointer` → `TClass` | 父类指针 |
| `vmtClassName` | 24 | `Pointer` → `PShortString` | 类名字符串指针 |
| `vmtDynamicTable` | 32 | `Pointer` | 动态方法表 |
| `vmtMethodTable` | 40 | `Pointer` | 方法表 |
| `vmtFieldTable` | 48 | `Pointer` | 字段表 |
| `vmtTypeInfo` | 56 | `Pointer` → `PTypeInfo` | RTTI 指针 |
| `vmtInitTable` | 64 | `Pointer` | 初始化表 |
| `vmtAutoTable` | 72 | `Pointer` | 自动表 |
| `vmtIntfTable` | 80 | `Pointer` → `PInterfaceTable` | 接口表 |
| `vmtMsgStrPtr` | 88 | `Pointer` | 消息字符串指针 |
| `vmtDestroy` | 96 | `procedure(Self: TObject)` | 虚方法 Destroy |
| `vmtNewInstance` | 104 | `function(Self: TClass): TObject` | 虚方法 NewInstance |
| `vmtFreeInstance` | 112 | `procedure(Self: TObject)` | 虚方法 FreeInstance |
| `vmtDefaultHandler` | 120 | `procedure(Self: TObject; var Message)` | 虚方法 DefaultHandler |
| `vmtAfterConstruction` | 128 | `procedure(Self: TObject)` | 虚方法 AfterConstruction |
| `vmtBeforeDestruction` | 136 | `procedure(Self: TObject)` | 虚方法 BeforeDestruction |
| `vmtDefaultHandlerStr` | 144 | `procedure(Self: TObject; var Message)` | 虚方法 DefaultHandlerStr |
| `vmtDispatch` | 152 | `procedure(Self: TObject; var Message)` | 虚方法 Dispatch |
| `vmtDispatchStr` | 160 | `procedure(Self: TObject; var Message)` | 虚方法 DispatchStr |
| `vmtEquals` | 168 | `function(Self: TObject; Obj: TObject): Boolean` | 虚方法 Equals |
| `vmtGetHashCode` | 176 | `function(Self: TObject): SizeInt` | 虚方法 GetHashCode |
| `vmtToString` | 184 | `function(Self: TObject): AnsiString` | 虚方法 ToString |
| `vmtSafeCallException` | 192 | `function(...): LongInt` | 虚方法 SafeCallException |
| `vmtGetInterface` | 200 | `function(Self: TObject; const IID: TGUID; out Obj): Boolean` | 虚方法 GetInterface |
| `vmtGetInterfaceWeak` | 208 | `function(...): Boolean` | 虚方法 GetInterfaceWeak |
| `vmtGetInterfaceStrong` | 216 | `function(...): Boolean` | 虚方法 GetInterfaceStrong |

**偏移计算**: `vmtXxx = SizeOf(SizeInt) * N`，其中 N 是序号（0-27）。

### 2.2 实例对象内存布局

```
offset 0:  VMT Pointer (8 bytes) — 指向 VMT 表头
offset 8:  Fields (InstanceSize - 8 bytes) — 实例字段
```

**关键约束**：
- `InstanceSize` 必须 ≥ 8（VMT 指针大小）
- 所有字段按类型对齐，尾部 padding 到最大字段对齐
- 编译器必须在实例创建时设置 `VMT Pointer = @类的 VMT`

### 2.3 虚方法调用约定

```
// obj.Method(args) 编译为：
vmt_ptr := PPointer(obj)^;           // 读取 VMT 指针
fn := PPointer(vmt_ptr + vmtXxx)^;   // 读取虚方法槽
fn(obj, args);                        // Self 是第一个参数（register 调用约定）
```

### 2.4 类继承链遍历

```
// class.InheritsFrom(AClass) 编译为：
c := Self;
while (c <> nil) and (c <> AClass) do
  c := PPointer(Pointer(c) + vmtParent)^;  // 沿 Parent 指针上溯
Result := (c = AClass);
```

## 3. 接口模型

### 3.1 IUnknown VTable 布局

```
offset 0:  QueryInterface — function(Self: Pointer; const IID: TGUID; out Obj): LongInt; stdcall
offset 8:  _AddRef        — function(Self: Pointer): LongInt; stdcall
offset 16: _Release       — function(Self: Pointer): LongInt; stdcall
```

**注意**: 接口方法的 Self 是接口指针（即 `TObject + IOffset`），不是对象指针。

### 3.2 接口表布局

```
TInterfaceTable = record
  EntryCount: SizeInt;              // offset 0
  Entries: array of TInterfaceEntry; // offset 8
end;

TInterfaceEntry = record
  IID: TGUID;         // offset 0, 16 bytes
  VTable: Pointer;    // offset 16, 指向接口 VTable
  IOffset: SizeInt;   // offset 24, 对象内接口偏移
  IsField: Boolean;   // offset 32
end;
```

### 3.3 接口引用计数

- `_AddRef` / `_Release` 由实现类负责
- 赋值时编译器生成 `np_intf_assign`（旧引用 Release，新引用 AddRef）
- 局部变量离开作用域时编译器生成 `np_intf_release`

## 4. 异常模型

### 4.1 异常对象

```
Exception = class
  FMessage: AnsiString;
  // ... 其他字段
end;
```

异常必须是 `Exception` 的子类（`{$compiler_root}` 不要求，但 ABI 约定如此）。

### 4.2 异常处理流程

```
// try
np_try_push(ExceptionRecord)  // 返回 0=首次进入, 非0=从 catch 恢复

// except
np_except_end                 // 清理异常状态

// finally
np_finally_end                // 执行 finally 块

// raise E.Create('msg')
np_raise(E)         // 抛出异常
```

### 4.3 ExceptionRecord 布局

运行时定义，编译器不直接访问字段，只通过 `np_try_push` / `np_try_pop` 操作。

## 5. 内存管理器 ABI

### 5.1 TMemoryManager 回调签名

```
TGetMem        = function(Size: SizeInt): Pointer;
TFreeMem       = function(P: Pointer): SizeInt;
TFreeMemSize   = function(P: Pointer; Size: SizeInt): SizeInt;
TAllocMem      = function(Size: SizeInt): Pointer;
TReAllocMem    = function(P: Pointer; Size: SizeInt): Pointer;
TMemSize       = function(P: Pointer): SizeInt;
```

### 5.2 np_* 内存函数 → 内存管理器映射

| 编译器函数 | 内存管理器回调 | 备注 |
|-----------|--------------|------|
| `np_getmem(Size)` | `GetMem(Size)` | |
| `np_freemem(P)` | `FreeMem(P)` | 返回释放的大小 |
| `np_reallocmem(P, Size)` | `ReAllocMem(P, Size)` | |
| `np_allocmem(Size)` | `AllocMem(Size)` | 零填充 |
| `np_memsize(P)` | `MemSize(P)` | |

### 5.3 对齐内存函数

```
np_getmem_aligned(Size, Align) → Pointer
np_freemem_aligned(P) → SizeInt
```

Align 必须是 2 的幂，≥ `SizeOf(Pointer)`。运行时负责对齐分配。

## 6. 编译器内部函数 (np_*) 完整签名

### 6.1 AnsiString 系列 (23 个)

```pascal
function np_ansistr_incr_ref(S: Pointer): Pointer;
function np_ansistr_decr_ref(S: Pointer): Pointer;
function np_ansistr_assign(Dest, Src: Pointer): Pointer;
function np_ansistr_concat(Dest: Pointer; const S1, S2: AnsiString): Pointer;
function np_ansistr_compare(const S1, S2: AnsiString): SizeInt;
function np_ansistr_compare_equal(const S1, S2: AnsiString): SizeInt;
function np_ansistr_length(S: Pointer): SizeInt;
function np_ansistr_setlength(S: Pointer; NewLen: SizeInt): Pointer;
function np_ansistr_unique(S: Pointer): Pointer;
function np_ansistr_copy(const S: AnsiString; Index, Count: SizeInt): AnsiString;
function np_ansistr_delete(S: Pointer; Index, Count: SizeInt): Pointer;
function np_ansistr_insert(S: Pointer; const Sub: AnsiString; Index: SizeInt): Pointer;
function np_ansistr_pos(const Sub, S: AnsiString): SizeInt;
function np_ansistr_char(S: Pointer; Index: SizeInt): AnsiChar;
function np_ansistr_pchar(S: Pointer): PAnsiChar;
function np_ansistr_to_shortstring(Dest: Pointer; const S: AnsiString): Pointer;
function np_ansistr_from_shortstring(Dest: Pointer; const S: ShortString): Pointer;
function np_ansistr_from_pchar(S: PAnsiChar): AnsiString;
function np_ansistr_from_char(C: AnsiChar): AnsiString;
function np_ansistr_from_widestring(const S: WideString): AnsiString;
function np_ansistr_from_unicodestring(const S: UnicodeString): AnsiString;
function np_ansistr_to_widestring(const S: AnsiString): WideString;
function np_ansistr_to_unicodestring(const S: AnsiString): UnicodeString;
```

### 6.2 WideString 系列 (18 个)

```pascal
function np_widestr_incr_ref(S: Pointer): Pointer;
function np_widestr_decr_ref(S: Pointer): Pointer;
function np_widestr_assign(Dest, Src: Pointer): Pointer;
function np_widestr_concat(Dest: Pointer; const S1, S2: WideString): Pointer;
function np_widestr_compare(const S1, S2: WideString): SizeInt;
function np_widestr_compare_equal(const S1, S2: WideString): SizeInt;
function np_widestr_length(S: Pointer): SizeInt;
function np_widestr_setlength(S: Pointer; NewLen: SizeInt): Pointer;
function np_widestr_unique(S: Pointer): Pointer;
function np_widestr_copy(const S: WideString; Index, Count: SizeInt): WideString;
function np_widestr_delete(S: Pointer; Index, Count: SizeInt): Pointer;
function np_widestr_insert(S: Pointer; const Sub: WideString; Index: SizeInt): Pointer;
function np_widestr_pos(const Sub, S: WideString): SizeInt;
function np_widestr_char(S: Pointer; Index: SizeInt): WideChar;
function np_widestr_pwidechar(S: Pointer): PWideChar;
function np_widestr_to_ansistring(const S: WideString): AnsiString;
function np_widestr_from_ansistring(const S: AnsiString): WideString;
function np_widestr_from_unicodestring(const S: UnicodeString): WideString;
function np_widestr_to_unicodestring(const S: WideString): UnicodeString;
```

### 6.3 UnicodeString 系列 (18 个)

```pascal
function np_unicodestr_incr_ref(S: Pointer): Pointer;
function np_unicodestr_decr_ref(S: Pointer): Pointer;
function np_unicodestr_assign(Dest, Src: Pointer): Pointer;
function np_unicodestr_concat(Dest: Pointer; const S1, S2: UnicodeString): Pointer;
function np_unicodestr_compare(const S1, S2: UnicodeString): SizeInt;
function np_unicodestr_compare_equal(const S1, S2: UnicodeString): SizeInt;
function np_unicodestr_length(S: Pointer): SizeInt;
function np_unicodestr_setlength(S: Pointer; NewLen: SizeInt): Pointer;
function np_unicodestr_unique(S: Pointer): Pointer;
function np_unicodestr_copy(const S: UnicodeString; Index, Count: SizeInt): UnicodeString;
function np_unicodestr_delete(S: Pointer; Index, Count: SizeInt): Pointer;
function np_unicodestr_insert(S: Pointer; const Sub: UnicodeString; Index: SizeInt): Pointer;
function np_unicodestr_pos(const Sub, S: UnicodeString): SizeInt;
function np_unicodestr_char(S: Pointer; Index: SizeInt): WideChar;
function np_unicodestr_pwidechar(S: Pointer): PWideChar;
function np_unicodestr_to_ansistring(const S: UnicodeString): AnsiString;
function np_unicodestr_to_widestring(const S: UnicodeString): WideString;
function np_unicodestr_from_ansistring(const S: AnsiString): UnicodeString;
function np_unicodestr_from_widestring(const S: WideString): UnicodeString;
```

### 6.4 Dynamic Array 系列 (12 个)

```pascal
function np_dynarray_incr_ref(S: Pointer): Pointer;
function np_dynarray_decr_ref(S: Pointer): Pointer;
function np_dynarray_assign(Dest, Src: Pointer): Pointer;
function np_dynarray_length(S: Pointer): SizeInt;
function np_dynarray_setlength(S: Pointer; NewLen: SizeInt; TypeInfo: Pointer): Pointer;
function np_dynarray_unique(S: Pointer): Pointer;
function np_dynarray_copy(const S: Pointer; Index, Count: SizeInt; TypeInfo: Pointer): Pointer;
function np_dynarray_delete(S: Pointer; Index, Count: SizeInt): Pointer;
function np_dynarray_insert(S: Pointer; const Sub: Pointer; Index: SizeInt): Pointer;
function np_dynarray_pos(const Sub, S: Pointer): SizeInt;
function np_dynarray_get(S: Pointer; Index: SizeInt): Pointer;
function np_dynarray_put(S: Pointer; Index: SizeInt; Value: Pointer): Pointer;
```

### 6.5 Variant 系列 (18 个)

```pascal
function np_variant_init(S: Pointer): Pointer;
function np_variant_clear(S: Pointer): Pointer;
function np_variant_assign(Dest, Src: Pointer): Pointer;
function np_variant_copy(Dest, Src: Pointer): Pointer;
function np_variant_cmp(const S1, S2: Variant): SizeInt;
function np_variant_cmp_equal(const S1, S2: Variant): SizeInt;
function np_variant_concat(Dest: Pointer; const S1, S2: Variant): Pointer;
function np_variant_length(S: Pointer): SizeInt;
function np_variant_type(S: Pointer): SizeInt;
function np_variant_is_empty(S: Pointer): Boolean;
function np_variant_is_null(S: Pointer): Boolean;
function np_variant_is_numeric(S: Pointer): Boolean;
function np_variant_is_string(S: Pointer): Boolean;
function np_variant_to_int(const S: Variant): Int64;
function np_variant_to_float(const S: Variant): Double;
function np_variant_to_str(const S: Variant): AnsiString;
function np_variant_from_int(Value: Int64): Variant;
function np_variant_from_float(Value: Double): Variant;
function np_variant_from_str(const Value: AnsiString): Variant;
```

### 6.6 Interface 系列 (10 个)

```pascal
function np_intf_incr_ref(S: Pointer): Pointer;
function np_intf_decr_ref(S: Pointer): Pointer;
function np_intf_assign(Dest, Src: Pointer): Pointer;
function np_intf_copy(Dest, Src: Pointer): Pointer;
function np_intf_clear(S: Pointer): Pointer;
function np_intf_is_nil(S: Pointer): Boolean;
function np_intf_is_equal(const S1, S2: IUnknown): Boolean;
function np_intf_query_interface(S: Pointer; const IID: TGUID; out Obj): LongInt;
function np_intf_addref(S: Pointer): LongInt;
function np_intf_release(S: Pointer): LongInt;
```

### 6.7 Exception 系列 (10 个)

```pascal
function np_setjmp(var S: jmp_buf): LongInt;
procedure np_longjmp(var S: jmp_buf; Value: LongInt);
function np_get_exception_address: Pointer;
function np_get_exception_object: Pointer;
function np_get_exception_class: TClass;
function np_try_push(var S: ExceptionRecord): LongInt;
procedure np_try_pop(S: ExceptionRecord);
procedure np_raise(S: Exception);
procedure np_finally_end;
procedure np_except_end;
```

### 6.8 Memory 系列 (7 个)

```pascal
function np_getmem(Size: SizeInt): Pointer;
function np_freemem(P: Pointer): SizeInt;
function np_reallocmem(P: Pointer; Size: SizeInt): Pointer;
function np_getmem_aligned(Size: SizeInt; Align: SizeInt): Pointer;
function np_freemem_aligned(P: Pointer): SizeInt;
function np_allocmem(Size: SizeInt): Pointer;
function np_memsize(P: Pointer): SizeInt;
```

### 6.9 Halt/Exit 系列 (3 个)

```pascal
procedure np_exit;
procedure np_halt(Code: LongInt);
procedure np_haltproc;
```

**总计: 119 个 np_* 函数**

## 7. np.system.* 运行时契约

这些名称是编译器和运行时之间的**语义契约**，不是直接的函数调用。编译器将它们映射到 HIR intrinsic，LLVM emitter 生成对应的 `@np_*` helper。

| 契约名称 | HIR Intrinsic | LLVM Helper | 语义 |
|----------|--------------|-------------|------|
| `np.system.process_init` | `process_init` | `@np_process_init` | 进程启动初始化 |
| `np.system.process_fini` | `process_fini` | `@np_process_fini` | 进程关闭清理 |
| `np.system.unit_init` | (future) | (future) | 单元初始化 |
| `np.system.unit_fini` | (future) | (future) | 单元终结化 |
| `np.system.halt` | `halt` | syscall | 程序终止 |
| `np.system.object_free` | `object_free` | `@np_object_free_release` | 对象释放 |
| `np.system.object_free.destroy` | `object_free.destroy` | inline | 调用 Destroy |
| `np.system.object_free.cleanup` | `object_free.cleanup` | inline | 调用 CleanupInstance |
| `np.system.object_free.release` | `object_free.release` | `@np_object_free_release` | 调用 FreeInstance |
| `np.system.heap_alloc` | `arr_alloc`/`class_alloc` | `@np_object_alloc` | 堆分配 |
| `np.system.dynarray_set_length` | `dynarray_setlength` | `@np_dynarray_setlength` | 动态数组 SetLength |
| `np.system.dynarray_fini` | `dynarray_fini` | `@np_dynarray_fini` | 动态数组终结化 |
| `np.system.string_fini` | `string_fini` | `@np_string_fini` | 字符串终结化 |
| `np.system.interface_release` | `intf_release` | `@np_intf_release` | 接口引用释放 |
| `np.system.exception_try_push` | `exception_try_push` | `@np_exception_try_push` | 异常 try 入栈 |
| `np.system.exception_try_pop` | `exception_try_pop` | `@np_exception_try_pop` | 异常 try 出栈 |
| `np.system.exception_raise` | `exception_raise` | `@np_exception_raise` | 异常抛出 |
| `np.system.exception_finally_end` | `exception_finally_end` | `@np_exception_finally_end` | finally 结束 |
| `np.system.exception_except_end` | `exception_except_end` | `@np_exception_except_end` | except 结束 |

## 8. 调用约定

### 8.1 默认调用约定

- **register**（默认）: 参数从左到右，前 3 个整数参数用 RDI, RSI, RDX；前 3 个浮点参数用 XMM0, XMM1, XMM2；其余压栈；返回值整数用 RAX，浮点用 XMM0
- **Self 参数**: 对象方法的 Self 是第一个参数（RDI）

### 8.2 特殊调用约定

- **stdcall**: 接口方法（COM 兼容），参数从右到左压栈，调用方清理栈
- **compilerproc**: np_* 系列函数，使用默认 register 约定，但编译器知道这些函数存在

### 8.3 栈对齐

- 进入函数时 RSP 必须 16 字节对齐
- call 指令压入 8 字节返回地址后 RSP 变为 8 字节未对齐
- 函数 prologue 必须调整到 16 字节对齐

## 9. RTTI 布局

### 9.1 TTypeInfo

```
TTypeInfo = record
  Kind: TTypeKind;      // offset 0, 1 byte (enum)
  Name: ShortString;    // offset 1, 1 + Length bytes
end;
```

### 9.2 TTypeData（按 TTypeKind 分支）

**tkInteger / tkChar / tkEnumeration / tkWChar / tkBool**:
```
OrdType: Byte       // offset 0
MinValue: SizeInt   // offset 1 (padded to 8)
MaxValue: SizeInt   // offset 9
// tkEnumeration only:
BaseType: PPTypeInfo // offset 17
NameList: ShortString // offset 25
```

**tkFloat**:
```
FloatType: Byte     // offset 0
```

**tkClass**:
```
ClassType: TClass      // offset 0 (Pointer)
ParentInfo: PPTypeInfo // offset 8
PropCount: SmallInt    // offset 16
UnitName: ShortString  // offset 18
```

**tkInterface**:
```
IntfParent: PPTypeInfo // offset 0
IntfFlags: Byte        // offset 8
IntfGuid: TGUID        // offset 9 (padded to 12?)
IntfUnit: ShortString  // offset 25
```

**tkDynArray**:
```
ElSize: SizeInt     // offset 0
ElType: PPTypeInfo  // offset 8
ElType2: PPTypeInfo // offset 16
VarType: LongInt    // offset 24
DynUnitName: ShortString // offset 28
```

### 9.3 TTypeKind 枚举值

```pascal
TTypeKind = (
  tkUnknown,      // 0
  tkInteger,      // 1
  tkChar,         // 2
  tkEnumeration,  // 3
  tkFloat,        // 4
  tkSet,          // 5
  tkMethod,       // 6
  tkSString,      // 7
  tkLString,      // 8
  tkAString,      // 9
  tkWString,      // 10
  tkVariant,      // 11
  tkArray,        // 12
  tkRecord,       // 13
  tkInterface,    // 14
  tkClass,        // 15
  tkObject,       // 16
  tkWChar,        // 17
  tkBool,         // 18
  tkInt64,        // 19
  tkQWord,        // 20
  tkDynArray,     // 21
  tkInterfaceRaw, // 22
  tkProcVar,      // 23
  tkUString,      // 24
  tkUChar,        // 25
  tkHelper,       // 26
  tkFile,         // 27
  tkClassRef,     // 28
  tkPointer       // 29
);
```

## 10. 编译器指令

### 10.1 `{$compiler_root}`

标记类为编译器根类。编译器必须：
- 将此类识别为所有类的根
- 从内核读取 VMT 布局常量
- 使用此类的 VMT 作为所有类的模板

当前标注：`TObject`（在 `cls.inc` 第 80 行）。

### 10.2 `{$compiler_type_kind}`

标记枚举为类型种类枚举。编译器必须：
- 将此枚举识别为 RTTI 类型种类
- 使用枚举值进行类型推断和类型检查

当前标注：`TTypeKind`（在 `rtti.inc` 第 14 行）。

### 10.3 `compilerproc`

标记函数为编译器内部函数。编译器必须：
- 知道这些函数的存在和签名
- 在需要时生成对这些函数的调用
- 这些函数的实现由运行时提供

当前标注：所有 119 个 `np_*` 函数（在 `comp.inc` 中）。

## 11. 目标平台差异

### 11.1 linux-x86_64

- 指针大小：8 字节
- SizeInt：8 字节（Int64）
- CLong：8 字节（Int64）
- 默认对齐：natural alignment
- 调用约定：System V AMD64 ABI

### 11.2 其他平台（未来）

- windows-x86_64: CLong = 4 字节（LongInt），调用约定：Microsoft x64
- linux-aarch64: 不同的寄存器分配规则
- macOS: 与 linux-x86_64 类似，但有不同的系统调用

## 12. 稳定性承诺

### 12.1 ABI 稳定性等级

| 区域 | 等级 | 承诺 |
|------|------|------|
| VMT 布局常量 | **冻结** | 不改变偏移值 |
| np_* 签名 | **冻结** | 不改变参数类型和顺序 |
| TMemoryManager 回调 | **冻结** | 不改变回调签名 |
| TTypeInfo/TTypeData 布局 | **冻结** | 不改变字段偏移 |
| TTypeKind 枚举值 | **冻结** | 不改变数值，只追加 |
| np.system.* 契约名称 | **冻结** | 不改变语义 |

### 12.2 兼容性保证

- 内核 ABI 与 FPC 7.x System 兼容
- 已编译的 FPC 二进制文件可以在 nextPas 运行时上运行
- nextPas 编译的二进制文件可以在 FPC 运行时上运行（如果只使用兼容子集）

## 13. 变更日志

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0.0-frozen | 2026-07-05 | ABI 冻结：VMT 布局 + np_* 签名 + TMemoryManager + TTypeKind 全部锁定 |
| 0.9.0 | 2026-07-05 | fpc_* → np_* 重命名（142 处），双编译器架构修正 |
| 0.8.0 | 2026-07-05 | 初始 ABI 规范：VMT + 119 函数签名 + 内存布局 + 异常模型 |
