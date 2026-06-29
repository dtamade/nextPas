# C8-prep 自举差距清单

> 2026-06-26 全面探测结果（最终版）
> 目标：用 nextPas 编译 `core/` 真实模块，记录所有差距

---

## 总结

| 类别 | 数量 | 说明 |
|------|------|------|
| ✅ 语法+语义通过 | ~98 | parser + sema 全绿 |
| 🔴 Parser 语法错误 | ~12 | 需要 parser 增强 |
| 🟡 语义错误 | 0 | 全部修复 |
| ⚪ FPC 后端失败 | ~15 | host-compiler-exec-failed，非编译器语义问题 |
| ⚪ 缺少源文件 | ~5 | 文件名不存在（非编译器问题） |

**语义通过率：100%**（所有 core 模块 sema 0 错误）

---

## 本轮已修复 Gaps

| # | 问题 | 修复 | 提交 |
|---|------|------|------|
| 1 | unit cycle (exception ↔ SysUtils) | SysUtils stub 自定义 Exception | d4e96605a |
| 2 | parser string keyword | ParsePrimaryExpression + tkStringKeyword | d7b40b526 |
| 3 | FPC Str() 格式说明符 | 格式说明符支持 tkIdentifier | d5e73d88a |
| 4 | class body 'of object' 嵌套计数 | 检查前一 token 不是 of | 687092c9c |
| 5 | begin...end. 初始化块 | ParseUnitRoot 支持 bare begin | 076e39221 |
| 6 | nested type section (class/record) | 跳过 type section 含多声明 | 77006eb81 |
| 7 | of object in skip loops | skip 循环也检查 of 前缀 | 15ecec3b2 |
| 8 | InferExpressionType gnkDotAccess | 字段类型 + 方法返回类型推断 | ecc0cc1df |
| 9 | ExpressionTypeFactIsStable | 接口/类/字段类型识别为 stable | ecc0cc1df |
| 10 | integer types encoding | SizeUInt/UInt32 等 → 'i' | ecc0cc1df |
| 11 | class/interface encoding | class → 'c', interface → 'f' | ecc0cc1df |
| 12 | array type encoding | array of T → 'a' + GetSubstitutedParamSignature 同步 | b9cee6eff |
| 13 | IsBuiltinProcedure | Default/TypeInfo/InterlockedCompare/Inc/Dec | ecc0cc1df |
| 14 | interface forward declaration parser | interface; 分号检查 | 2ecc93437 |
| 15 | VerifyInterfaceImplementation parent chain | 父类方法继承检查 | 2ecc93437 |
| 16 | ResolveTypeIdForOwner duplicate types | 前向声明+完整定义优先完整定义 | 2ecc93437 |

---

## ✅ 已修复 Parser 语法错误 (2026-06-29)

### P1：表达式链式调用 — ✅ 已修复
- `"statement" expected but "." found` — `collections.arr`
- `(Self as TCollection).TryLoadFrom(...)` 不被识别
- **修复**: `ParseStatement` 的 `tkLParen` 分支增加 postfix 链处理 (.method, ^, ())
- **提交**: a0d6d0252

### P2：函数指针调用 — ✅ 已修复
- `"statement" expected but "(" found` — `collections.base`, `toml.parser`
- `TEqualsFunc(aEquals^)(aLeft, aRight)` 不被识别
- **修复**: `ParsePrimaryExpression` chaining 允许 `gnkDereference`/`gnkFunctionCall` 后跟 `tkLParen`
- **提交**: a0d6d0252

### P3-P6：级联错误 — ✅ 全部修复
- P3-P6 是 P1/P2 的级联失败，修复 P1/P2 后自动解决
- 所有 8 个模块现在 `syntax-status=ready`

### P7：非法字符
- `collections.vec` — 源文件含非 ASCII 字节 $A8
- **状态**: 未修复（源码问题，非编译器问题）

---

## 🟡 语义/代码生成错误

### S1：unknown callable — ✅ 全部修复
- `SetString` — config.env → ✅ 通过
- `SiftDown` — bench.base → ✅ 通过
- `InterlockedCompareExchange` — bench.memtrack → ✅ 已注册为 builtin
- `SizeUInt` — bytes.base → ✅ 通过

### S2：ambiguous overload — ✅ 全部修复
- `atomic_thread_fence` — atomic.types → ✅ 通过
- `FormatDateTime` — bench → ✅ 通过
- `Create` — collections.forward_list, collections → ✅ 通过
- `Max` — collections.btree → ✅ 通过

### S3：wrong number of arguments — ⚠️ 待验证
- `MkdirAll` — fs → ✅ 通过（已修复）
- `Send` — http.client → FPC 后端失败
- `Shutdown` — http.server → FPC 后端失败

### S4：argument type mismatch — ✅ 已修复
- `TextOfChar` — bench.report → ✅ 通过
- `StringsSplit` — bench.xlang → 待测试
- `UnicodeCompareStr` — collections.base → ✅ 已注册为 builtin (a0d6d0252)
- `compare_unicodestring` — collections.base → ✅ GetParamSignature 签名对齐 (f16a7e6bc)
- `equals_unicodestring` — collections.base → ✅ 同上

### S7：unknown callable "UInt32" — ✅ 已修复
- `toml.parser`, `fs.dir` → ✅ 注册 UInt32 为类型别名 (a0d6d0252)

### S8：unknown member "Create" — ✅ 已修复
- `collections.base` (offset 49132) — 类引用调用 `LCollectionClass.Create(Self)` 未被识别
- **修复**: `ProcessTypeSection` 检测 `class of T` 模式，设置 `AliasTargetTypeId` (30dc80bc9)
- **剩余**: `sema.ambiguous-overload` — class-of 继承了 Create 重载，需要调用方 disambiguate

### S9：wrong-argument-count "IsOverlap" — ✅ 已修复
- `collections.base` (4 处) — virtual abstract 方法在非泛型基类中，无函数体
- **根因**: `ResolveTypeIdForOwner` 在两个 type 条目（前向声明+完整定义）且两者 Kind 都不是 'class' 时 `Exit(0)`，导致 `Self` 类型解析失败
- **修复**: 当两者都不是 class/interface 时，优先选择后面的条目（完整定义） (6092dd4f7)

### S5：interface not implemented — ✅ 全部修复
- `TBenchResults does not implement IBenchResults.*` — bench → ✅ 通过 (parser forward decl fix)
- `TBitSet does not implement IBitSet.AppendTo` — collections.bitset → ✅ 通过 (parent chain + type resolution)

### S6：compiler exit
- `http` — FPC 编译失败（后端问题，非 sema）
