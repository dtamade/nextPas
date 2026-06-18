# P5 RTL Self-Hosting Plan

> **北极星**: nextPas 编译器编译自身源码，产出独立可执行的编译器。

## 1. 现状评估

### 1.1 Self-Hosting Readiness Gates (2026-06-18 更新)

| Gate | 描述 | 状态 | 说明 |
|------|------|------|------|
| Gate 0 | system.classes Facade | ⚠️ PARTIAL | stream-core live, file-compat missing |
| Gate 1 | RTTI Shape Consistency | ⚠️ PRE-WORK | 无 TTypeKind 稳定性测试 |
| Gate 2 | Unit Lifecycle Execution | ✅ DONE | Sprint 3: HIR→LLVM global_ctors/dtors |
| Gate 3 | Process Lifecycle Execution | ✅ DONE | Sprint 1: process_init/fini 全链路 |
| Gate 4 | Heap Manager Integration | ✅ DONE | Sprint 4-5: libnprt.a allocator |
| Gate 5 | Exception Unwind | ✅ DONE | setjmp/longjmp 全功能 |

### 1.2 编译器内置函数支持

| 函数 | 状态 | 阻塞级别 |
|------|------|----------|
| Implicit uses System | ✅ 已实现 | — |
| Inc/Dec | ✅ 已实现 | — |
| Ord/Chr | ✅ 已实现 | — |
| Exit/Break/Continue | ✅ 关键字级 | — |
| WriteLn/Write | ✅ 部分(整数/字符串) | 低 |
| SetLength/Length/Copy | ✅ 已实现(字符串/动态数组) | — |
| FillChar/Move | ❌ 未实现 | **P0 高** |
| GetMem/FreeMem/ReallocMem | ❌ 未实现 | **P0 高** |
| Assigned | ❌ 未实现 | P1 中 |
| Low/High (表达式) | ⚠️ 部分 | P1 中 |
| Set ops (Include/Exclude/in) | ⚠️ 部分 | P2 低 |
| TypeInfo | ❌ 未实现 | P2 低 |
| Dispose | ❌ 未实现 | P2 低 |

### 1.3 编译器源码依赖审计 (41 文件)

**System (隐式):** 38 个内置函数 + 所有基础类型
**SysUtils (38 处引用, 35 个函数):**
- 路径操作 (7): ExtractFileDir/FileName/FileExt, ExpandFileName, IncludeTrailingPathDelimiter, ExcludeTrailingPathDelimiter, ChangeFileExt
- 字符串 (7): SameText, Trim, LowerCase, UpperCase, StringReplace, Format, FreeAndNil
- 转换 (4): IntToStr, StrToInt, StrToIntDef, StrToInt64Def
- 文件系统 (8): FileExists, DirectoryExists, ForceDirectories, DeleteFile, FindFirst/FindNext/FindClose, TSearchRec, GetCurrentDir
- 运行时 (3): ParamStr, ParamCount, GetEnvironmentVariable
- 日期时间 (2): Now, FormatDateTime
- 常量 (3): DirectorySeparator, PathDelim, LineEnding

**Classes (6 处引用, 4 类型):**
- TStringList (~30 uses) — 配置/manifest 解析核心
- TFileStream (2 uses) — 文件 I/O
- TInterfacedObject (2 uses) — 接口实现
- TObject (~8 uses) — 基类引用

**Process (2 处引用):**
- TProcess — 进程启动 (np_toolchain_runner, nextpas_command_test)

## 2. 执行计划

### Sprint R1: 编译器内置函数补齐 (3天)

**目标**: 编译器能正确 emit FillChar/Move/GetMem/FreeMem/Assigned 调用

#### R1.1: FillChar/Move → LLVM emit
- HIR: 新增 `hnkFillCharRuntime` / `hnkMoveRuntime` 节点
- Sema: FillChar/Move 从 `IsBuiltinProcedure` 降级为 HIR intrinsic
- LLVM emit: `call void @np_memset(ptr, i8, i64)` / `call void @np_memcpy(ptr, ptr, i64)`
- 测试: `test_fillchar_move_pass.pas`

#### R1.2: GetMem/FreeMem/ReallocMem → LLVM emit
- HIR: 新增 `hnkGetMemRuntime` / `hnkFreeMemRuntime` / `hnkReallocMemRuntime`
- LLVM emit: 声明 `@np_alloc`/`@np_free` 为 external，emit 调用
- 注意: GetMem 返回的指针与 np_alloc 的 header 布局差异需处理
- 测试: `test_getmem_freemem_pass.pas`

#### R1.3: Assigned → LLVM emit
- HIR: Assigned(ptr) 降级为 `icmp ne ptr null`
- LLVM emit: inline comparison, 返回 i1 → zext to i8/boolean
- 测试: `test_assigned_pass.pas`

#### R1.4: Low/High 表达式支持
- Sema: High(arr)/Low(arr) 降级为常量（静态数组）或 Length-1/0（动态数组/字符串）
- LLVM emit: 常量折叠或 Length-based intrinsic
- 测试: `test_low_high_pass.pas`

**Gate: 4 个新测试全绿, 不破坏现有测试**

### Sprint R2: System Unit 实现 (5天)

**目标**: 最小 nextPas-native System.pas，能被编译器隐式加载

#### R2.1: 基础类型声明
- 所有 ordinal 类型: Byte, ShortInt, Word, SmallInt, LongWord, Cardinal, Int64, QWord
- NativeInt, NativeUInt, SizeInt, SizeUInt, PtrInt, PtrUInt
- PChar, PAnsiChar, PByte, PPointer
- 常量: MaxInt, MaxLongint, MaxSmallint, LowBound, HighBound
- 字符串类型布局: ShortString record, AnsiString (ptr+len+owner+alloc_size)
- Variant, Comp, Currency (stub 类型)

#### R2.2: 内存管理 FFI
- `procedure GetMem(var P: Pointer; Size: NativeUInt);` → `@np_alloc`
- `procedure FreeMem(P: Pointer);` → `@np_free`
- `function ReallocMem(P: Pointer; Size: NativeUInt): Pointer;` → `@np_realloc` (需新增)
- `function AllocMem(Size: NativeUInt): Pointer;` → GetMem + FillChar 0

#### R2.3: 内置函数 wrapper
- `function Assigned(P: Pointer): Boolean;` — 编译器内置
- `procedure FillChar(var Dest; Count: NativeUInt; Value: Byte);` — 编译器内置
- `procedure Move(const Source; var Dest; Count: NativeUInt);` — 编译器内置
- `function High(X): LongInt;` / `function Low(X): LongInt;` — 编译器内置

#### R2.4: TObject + Exception 完善
- TObject: ClassType, ClassName, InheritsFrom, InstanceSize (需要最小 RTTI)
- Exception: Message as string (而非 integer code), Create/Destroy
- FreeAndNil 集成

#### R2.5: 测试
- `test_system_types.pas`: 所有类型 SizeOf 正确
- `test_system_memory.pas`: GetMem/FreeMem/ReallocMem 循环无泄漏
- `test_system_object.pas`: TObject 生命周期

**Gate: System.pas 能被 nextPas 编译器隐式加载, 5 个测试全绿**

### Sprint R3: SysUtils 最小子集 (5天)

**目标**: 实现编译器源码实际使用的 35 个 SysUtils 函数

#### R3.1: 路径操作 (7 函数, 纯字符串算法)
- ExtractFileDir, ExtractFileName, ExtractFileExt
- ExpandFileName (getcwd + 拼接)
- IncludeTrailingPathDelimiter, ExcludeTrailingPathDelimiter
- ChangeFileExt
- 常量: DirectorySeparator, PathDelim

#### R3.2: 字符串操作 (7 函数)
- SameText (大小写不敏感比较)
- Trim (去首尾空白)
- LowerCase, UpperCase (ASCII 转换)
- StringReplace (查找替换)
- Format (基础 %s/%d/%f 格式化)
- FreeAndNil (已在 System 中)

#### R3.3: 类型转换 (4 函数)
- IntToStr (已有 intrinsic，需 Pascal wrapper)
- StrToInt, StrToIntDef, StrToInt64Def (字符串→整数解析)

#### R3.4: 文件系统 (8 函数)
- FileExists, DirectoryExists (stat syscall)
- ForceDirectories (mkdir -p)
- DeleteFile (unlink syscall)
- FindFirst/FindNext/FindClose (getdents syscall)
- TSearchRec record type
- GetCurrentDir (getcwd syscall)

#### R3.5: 运行时 + 日期 (5 函数)
- ParamStr, ParamCount (/proc/self/cmdline 解析)
- GetEnvironmentVariable (environ 遍历)
- Now, FormatDateTime (clock_gettime + 格式化)
- LineEnding 常量

#### R3.6: 测试
- 每个函数至少 1 个测试用例
- `test_sysutils_paths.pas`, `test_sysutils_strings.pas`, `test_sysutils_fs.pas`

**Gate: SysUtils.pas 能被 nextPas 编译, 编译器源码中所有 SysUtils 引用可解析**

### Sprint R4: Classes 最小子集 (3天)

**目标**: 实现编译器源码使用的 4 个 Classes 类型

#### R4.1: TStringList
- 基于 `array of string` 内部存储
- LoadFromFile/SaveToFile (文件 I/O)
- Values[Name] (INI 风格键值解析)
- Add/Delete/Insert/Clear/IndexOf
- Count, Strings[] 属性
- Sorted, Duplicates 支持 (编译器可能不需要)

#### R4.2: TFileStream
- 继承关系: TObject → TStream → THandleStream → TFileStream
- Create(Filename, Mode) — open syscall
- Read/Write — read/write syscall
- Seek — lseek syscall
- Destroy — close syscall
- fmCreate, fmOpenRead, fmOpenWrite 常量

#### R4.3: TStream 基类
- 抽象 Read/Write/Seek 方法
- Position, Size 属性

#### R4.4: 测试
- `test_classes_tstringlist.pas`: 创建/添加/查找/保存/加载
- `test_classes_tfilestream.pas`: 创建/读/写/定位/关闭

**Gate: Classes.pas 能被 nextPas 编译, 编译器源码中所有 Classes 引用可解析**

### Sprint R5: 编译器特性补齐 + Self-Hosting 尝试 (5天)

**目标**: 编译器能处理自身源码中的所有语法特性

#### R5.1: Set 操作 emit (如编译器源码需要)
- Include/Exclude → bit set/clear 操作
- in 运算符 → bit test
- Set 构造器 → bitmask 常量

#### R5.2: TypeInfo 基本支持 (如编译器源码需要)
- TypeInfo(T) → 指向类型元数据的指针
- 最小 TTypeKind 枚举

#### R5.3: 编译器源码适配
- 审计编译器源码中所有 FPC-specific 语法/用法
- 转换为 nextPas 兼容写法（如 ShortString → AnsiString）
- 移除不需要的 FPC 单元引用

#### R5.4: Self-Hosting 黄金测试
- `nextpas build tools/stage0/nextpas.pas` → 产出 stage2 编译器
- `stage2 build tests/compiler/pass/hello_pass.pas` → 产出可执行
- `stage2 output == stage0 output`

**Gate: 编译器编译自身成功, 产出的编译器能编译 hello_pass.pas**

## 3. 依赖关系

```
R1 (内置函数) ──→ R2 (System Unit) ──→ R3 (SysUtils) ──→ R5 (Self-Hosting)
                                         └──→ R4 (Classes) ──┘
```

R1 是 R2 的前置（GetMem/FreeMem 是 System.pas 内存管理的基础）。
R2 是 R3/R4 的前置（SysUtils/Classes 依赖 System 类型）。
R3 + R4 是 R5 的前置（编译器源码 uses SysUtils + Classes）。
R5 内部特性补齐可以与 R3/R4 并行。

## 4. 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| 编译器源码有隐藏的 FPC-only 语法 | R5 阻塞 | R5.3 做完整审计 |
| GetMem 与 np_alloc header 布局不兼容 | R1.2/R2.2 内存损坏 | GetMem 返回 payload 起始地址, 包装 header 管理 |
| SysUtils 文件系统函数需要 syscall 实现 | R3.4 工作量大 | 使用 platform 模块已有 syscall 或 FFI extern |
| Format 函数复杂度高 | R3.2 超时 | 先实现 %s/%d/%f, 不支持 %x/%e/%g |
| TStringList 需要完整实现 | R4.1 工作量大 | 只实现编译器用到的子集 |

## 5. 预估总工期

| Sprint | 工期 | 累计 |
|--------|------|------|
| R1: 内置函数 | 3天 | 3天 |
| R2: System Unit | 5天 | 8天 |
| R3: SysUtils | 5天 | 13天 |
| R4: Classes | 3天 | 16天 |
| R5: Self-Hosting | 5天 | 21天 |

**总计: ~21 工作日 (约 4 周)**

## 6. 进度跟踪

### Sprint R1: 编译器内置函数 ✅ (2026-06-18)
- FillChar → @np_memset (新增运行时函数)
- Move → @np_memcpy
- GetMem → @np_alloc
- FreeMem → @np_free
- Assigned → icmp ne ptr null
- 测试: builtins_pass.pas 全绿

### Sprint R2: System Unit ✅ (2026-06-18)
- 所有 ordinal/pointer/string 类型声明
- TObject + TInterfacedObject + Exception 层次
- MaxInt/True/False/PathDelim/LineEnding 常量
- 测试: 3/3 compiler-pass 全绿

### Sprint R3: SysUtils 补齐 ✅ (2026-06-18)
- 新增: IntToStr(Int64)/StrToInt64Def/ExtractFileExt/StringReplace/ParamStr/ParamCount/GetCurrentDir
- FFI: getcwd/argc/argv
- 测试: 10/10 组全绿

### Sprint R4: Classes 扩展 ✅ (2026-06-18)
- TStringList: Insert/IndexOfName/Names/Values/Text/LoadFromStream/AddStrings
- 测试: 10/10 组全绿

### Sprint R5: Self-Hosting 尝试 🔄 (2026-06-18)
**发现 C6-H4 阻塞项：**
- 编译器加载 SysUtils.pas 时，扫描所有过程体，发现 `LowerCase`/`Trim` 等函数的
  owned string 返回值被用于非直接赋值上下文（如比较、拼接），触发 C6-H4 错误
- 根因: `IsOwnedStringReturnFunc` 依赖注册，但非字符串返回函数（如 SameText）中
  使用的 owned string 函数不会被注册
- 修复: `IsSupportedOwnedStringReturnIdentifierTarget` 已补充到赋值检查中
- 剩余: 需要放宽 C6-H4 对单元级代码的扫描策略

**C6-H4 修复 (3 项):**
1. `IsSupportedOwnedStringReturnIdentifierTarget` → 赋值目标变量检查
2. `CheckDeferredOwnedStringReturnConsumers` → 跳过外部单元过程体
3. `AssignmentOwnsStringReturn` → 接受局部变量赋值

**工具链修复:**
- 多单元链接：`AddLogicalObjectInput` 让 ld.bfd 收到所有单元 .o 文件

**StringReplace 修复:**
- bug: else 分支 `UpperOld` 未赋值，替换永不发生
- fix: else 分支给 `SearchOld` 赋值 `OldPattern`

**当前测试状态：** 4/4 compiler-pass 全绿，10/10 smoke 组全绿

**下一步：**
1. ✅ C6-H4 修复完成
2. ✅ sysutils_pass.pas 运行时修复完成
3. 尝试编译器源码编译 (stage0 入口)
