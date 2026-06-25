# C8-prep 自举差距清单

> 2026-06-26 全面探测结果（最终版）
> 目标：用 nextPas 编译 `core/` 真实模块，记录所有差距

---

## 总结

| 类别 | 数量 | 说明 |
|------|------|------|
| ✅ 语法+语义通过 | ~83 | parser + sema + codegen 全绿 |
| 🔴 Parser 语法错误 | ~12 | 需要 parser 增强 |
| 🟡 语义/代码生成错误 | ~10 | 缺少 builtins/overload/实现 |
| ⚪ 缺少源文件 | ~5 | 文件名不存在（非编译器问题） |

**通过率：~83%**（100 个模块中 83 个通过）

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

### S1：unknown callable
- `SetString` — config.env
- `SiftDown` — bench.base
- `InterlockedCompareExchange` — bench.memtrack
- `SizeUInt` — bytes.base（当作 callable）

### S2：ambiguous overload
- `atomic_thread_fence` — atomic.types
- `FormatDateTime` — bench
- `Create` — collections.forward_list, collections
- `Max` — collections.btree

### S3：wrong number of arguments
- `MkdirAll` — fs
- `Send` — http.client
- `Shutdown` — http.server

### S4：argument type mismatch
- `TextOfChar` — bench.report
- `StringsSplit` — bench.xlang

### S5：interface not implemented
- `TBitSet does not implement IBitSet.AppendTo` — collections.bitset

### S6：compiler exit
- `http` — FPC 编译失败
