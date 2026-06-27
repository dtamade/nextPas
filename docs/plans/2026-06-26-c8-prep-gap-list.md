# C8-prep 自举差距清单

> 2026-06-26 全面探测结果（最终版）
> 目标：用 nextPas 编译 `core/` 真实模块，记录所有差距

---

## 总结

| 类别 | 数量 | 说明 |
|------|------|------|
| ✅ 语法+语义通过 | ~95 | parser + sema 全绿，FPC 后端问题不算 |
| 🔴 Parser 语法错误 | ~12 | 需要 parser 增强 |
| 🟡 语义错误 | 2 | missing-interface-method (bench, bitset) |
| ⚪ FPC 后端失败 | ~15 | host-compiler-exec-failed，非编译器语义问题 |
| ⚪ 缺少源文件 | ~5 | 文件名不存在（非编译器问题） |

**语义通过率：~98%**（100 个模块中仅 2 个有 sema 错误）

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

---

## 🔴 剩余 Parser 语法错误

### P1：表达式链式调用
- `"statement" expected but "." found` — `collections.arr`
- `(Self as TCollection).TryLoadFrom(...)` 不被识别

### P2：函数指针调用
- `"statement" expected but "(" found` — `collections.base`, `toml.parser`
- `TEqualsFunc(aEquals^)(aLeft, aRight)` 不被识别

### P3：statement expected but ";" found
- `collections.hashmap`, `collections.skiplist`

### P4：IMPLEMENTATION expected but BEGIN/END found
- `collections.vecdeque`, `bench.parallel`

### P5：statement expected but END found
- `bench.runner`

### P6：identifier expected but "." found
- `fs.dir` — uses 子句或限定名

### P7：非法字符
- `collections.vec` — 源文件含非 ASCII 字节 $A8

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

### S4：argument type mismatch — ⚠️ 待验证
- `TextOfChar` — bench.report → ✅ 通过
- `StringsSplit` — bench.xlang → 待测试

### S5：interface not implemented — 🔴 未修复
- `TBenchResults does not implement IBenchResults.*` — bench (11 methods)
- `TBitSet does not implement IBitSet.AppendTo` — collections.bitset (15 errors)

### S6：compiler exit
- `http` — FPC 编译失败（后端问题，非 sema）
